#!/usr/bin/env bash
# Arch-Linux Base-Install (UEFI, GRUB, ext4 auf LUKS, /dev/sda)
# Auszuführen vom Arch-Live-ISO. Rechnet mit Internetverbindung.
#
# WARNUNG: Dieses Script partitioniert /dev/sda KOMPLETT neu. Alle Daten auf
#          /dev/sda werden gelöscht. Nur auf frischer Hardware/VM ausführen.
#
# Layout:
#   /dev/sda1  512M  EFI (FAT32)          -> /boot
#   /dev/sda2  rest  LUKS -> ext4         -> /
#
# Phasen:
#   Phase 1 (vom Live-ISO, als root):   ./arch-install.sh
#   Phase 2 (im chroot, automatisch):   wird von Phase 1 aufgerufen
#
# Zielbenutzer: Ops / Passwort: 1234 / LUKS-Passphrase: 1234

set -euo pipefail

TARGET_USER="Ops"
TARGET_PASS="1234"
LUKS_PASS="1234"
HOSTNAME="Arch"
DISK="/dev/sda"
CRYPT_NAME="cryptroot"

# ---------------------------------------------------------------------------
# Phase 2: wird innerhalb von arch-chroot ausgeführt
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--chroot" ]]; then
    ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime
    hwclock --systohc

    sed -i 's/#de_CH.UTF-8 UTF-8/de_CH.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=de_CH.UTF-8"       > /etc/locale.conf
    echo "KEYMAP=de_CH-latin1"    > /etc/vconsole.conf
    echo "$HOSTNAME"              > /etc/hostname

    useradd -m -G wheel -s /bin/bash --badname "$TARGET_USER"
    echo "${TARGET_USER}:${TARGET_PASS}" | chpasswd
    echo "root:${TARGET_PASS}"           | chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # mkinitcpio: encrypt-Hook vor filesystems einfügen
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
    mkinitcpio -P

    # GRUB: Kernel-Parameter für LUKS setzen
    CRYPT_UUID=$(blkid -s UUID -o value "${DISK}2")
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${CRYPT_UUID}:${CRYPT_NAME} root=/dev/mapper/${CRYPT_NAME}\"|" /etc/default/grub

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    systemctl enable NetworkManager
    exit 0
fi

# ---------------------------------------------------------------------------
# Phase 1: vom Arch-Live-ISO aus
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || { echo "Als root vom Live-ISO ausführen." >&2; exit 1; }

loadkeys de_CH-latin1

# Partitionierung: GPT, 1=EFI 512M, 2=Root rest
sfdisk --wipe=always "$DISK" <<EOF
label: gpt
,512M,U
,,L
EOF

mkfs.fat -F 32 "${DISK}1"

# LUKS auf /dev/sda2
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode "${DISK}2" -
echo -n "$LUKS_PASS" | cryptsetup open "${DISK}2" "$CRYPT_NAME" -

mkfs.ext4 -F "/dev/mapper/${CRYPT_NAME}"

mount "/dev/mapper/${CRYPT_NAME}" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

pacstrap -K /mnt base linux linux-firmware nano networkmanager sudo grub efibootmgr cryptsetup
genfstab -U /mnt >> /mnt/etc/fstab

# Script in neues System kopieren und Phase 2 im chroot starten
install -m 0755 "$0" /mnt/root/arch-install.sh
arch-chroot /mnt /root/arch-install.sh --chroot
rm -f /mnt/root/arch-install.sh

echo
echo "Base-Install fertig. 'umount -R /mnt && cryptsetup close ${CRYPT_NAME} && reboot'"
echo "Beim Boot LUKS-Passphrase '${LUKS_PASS}' eingeben, danach als ${TARGET_USER} einloggen."
