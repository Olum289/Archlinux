# Dotfiles – Arch Linux + Hyprland + Ambxst

Komplettes Setup in zwei Stufen, portierbar auf ein frisches System:

1. **`arch-install.sh`** – Arch Base-Install vom Live-ISO aus (UEFI, GRUB, LUKS2
   auf Root, ext4, User `Ops`).
2. **`install.sh`** – Dotfiles, Pakete, Hyprland-Config, Ambxst, Wallpaper –
   nach dem ersten Login als `Ops` auszuführen.

## Repo-Inhalt

```
arch-install.sh            # Phase 0: Base-Install vom Arch-Live-ISO
install.sh                 # Phase 1: Dotfiles + Hyprland + Ambxst als User
pkglist.txt                # offizielle Pakete (pacman)
pkglist-aur.txt            # AUR-Pakete (yay)
README.md
.gitignore
wallpapers/
  forest-dark.jpg          # Hyprpaper-Wallpaper
home/
  .bashrc
.config/
  hypr/                    # hyprland.conf, hyprpaper.conf, hypridle.conf, hyprlock.conf
  ambxst/                  # Ambxst Shell: bar, dock, theme, notch, lockscreen, presets, ...
  kitty/                   # Terminal: kitty.conf, current-theme.conf
  rofi/                    # config.rasi, ambxst-dark.rasi
  gtk-3.0/                 # settings.ini, gtk.css
  gtk-4.0/                 # settings.ini, gtk.css
  MangoHud/                # MangoHud.conf
.local/share/ambxst/
  axctl.toml               # Ambxst Control-Config
  hyprland.conf            # Hyprland↔Ambxst Bridge
```

**Bewusst NICHT im Repo** (in `.gitignore`): `~/.local/share/ambxst/keys.db`,
`clipboard.db`, `clipboard-data/`, `chats/` – Runtime-State und Secrets.

---

## Phase 0 – Arch Base-Install (`arch-install.sh`)

### Voraussetzungen
- Arch-Live-ISO gebootet, UEFI-Modus, Internet via `iwctl`/Ethernet.
- Zielgerät ist **`/dev/sda`** und wird **komplett gelöscht**.

### Aufruf
```bash
# Im Arch-Live-ISO als root:
curl -LO https://raw.githubusercontent.com/Olum289/Archlinux/main/arch-install.sh
chmod +x arch-install.sh
./arch-install.sh
```

### Was passiert (Phase 1, vom Live-ISO)
1. `loadkeys de_CH-latin1` – Schweizerdeutsches Keyboard.
2. `sfdisk` partitioniert `/dev/sda` GPT:
   - `sda1` 512 MiB, Typ `U` (EFI System) – wird FAT32, gemountet auf `/boot`.
   - `sda2` Rest, Typ `L` (Linux filesystem) – LUKS2-Container.
3. `mkfs.fat -F 32 /dev/sda1`.
4. **LUKS2** auf `/dev/sda2`: `cryptsetup luksFormat --type luks2 --batch-mode --key-file=-`
   mit Passphrase `1234`, dann `cryptsetup open` als `cryptroot`.
5. `mkfs.ext4 /dev/mapper/cryptroot`.
6. Mount: `/dev/mapper/cryptroot` → `/mnt`, `/dev/sda1` → `/mnt/boot`.
7. `pacstrap -K /mnt base linux linux-firmware nano networkmanager sudo grub efibootmgr cryptsetup`.
8. `genfstab -U /mnt >> /mnt/etc/fstab`.
9. Script kopiert sich selbst nach `/mnt/root/arch-install.sh` und `arch-chroot /mnt /root/arch-install.sh --chroot`.

### Was passiert (Phase 2, im chroot)
1. Zeitzone `Europe/Zurich`, `hwclock --systohc`.
2. Locale `de_CH.UTF-8`, `KEYMAP=de_CH-latin1`, Hostname `Arch`.
3. `useradd -m -G wheel -s /bin/bash --badname Ops`, Passwort `1234`.
   Root-Passwort ebenfalls `1234`. `%wheel ALL=(ALL:ALL) ALL` aktiviert.
4. **`/etc/mkinitcpio.conf`** HOOKS:
   ```
   HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
   ```
   (`keyboard` vor `encrypt` für Passphrase-Prompt, `encrypt` zwischen `block` und `filesystems`.)
   Danach `mkinitcpio -P`.
5. **`/etc/default/grub`** `GRUB_CMDLINE_LINUX` wird gesetzt auf:
   ```
   cryptdevice=UUID=<sda2-UUID>:cryptroot root=/dev/mapper/cryptroot
   ```
   UUID wird per `blkid -s UUID -o value /dev/sda2` ermittelt.
   `GRUB_ENABLE_CRYPTODISK=y` ist **nicht** nötig, weil `/boot` auf der
   unverschlüsselten EFI-FAT32-Partition liegt.
6. `grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB`
   + `grub-mkconfig -o /boot/grub/grub.cfg`.
7. `systemctl enable NetworkManager`.

### Reboot
```bash
umount -R /mnt
cryptsetup close cryptroot
reboot
```
Beim Boot fragt das initramfs nach der LUKS-Passphrase (`1234`), danach Login
als `Ops` / `1234`.

### Zugangsdaten nach Phase 0
| Gegenstand | Wert |
|---|---|
| LUKS-Passphrase | `1234` |
| Root-Passwort | `1234` |
| User / Passwort | `Ops` / `1234` |
| Hostname | `Arch` |
| Locale | `de_CH.UTF-8` |
| Keymap (TTY) | `de_CH-latin1` |

> **Sicherheitshinweis:** `1234` ist ein Testpasswort. Vor Produktivnutzung mit
> `cryptsetup luksChangeKey /dev/sda2`, `passwd Ops` und `passwd` (root) ändern.

---

## Phase 1 – Dotfiles & Hyprland (`install.sh`)

### Voraussetzungen
- Frisch installiertes Arch (z. B. via `arch-install.sh`), User `Ops` ist eingeloggt
  und in `wheel` mit `sudo`.
- Internetverbindung.

### Aufruf
```bash
git clone https://github.com/Olum289/Archlinux.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Was passiert
1. **Pakete:** `sudo pacman -S --needed --noconfirm - < pkglist.txt`.
2. **AUR:** Wenn `pkglist-aur.txt` nicht leer und `yay` fehlt → yay wird aus
   dem AUR gebaut (`git clone aur/yay`, `makepkg -si`). Danach
   `yay -S --needed --noconfirm - < pkglist-aur.txt`.
3. **Symlinks** (mit Backup vorhandener Dateien nach
   `~/.dotfiles-backup-<timestamp>/`):
   - `~/dotfiles/.config/{hypr,ambxst,kitty,rofi,gtk-3.0,gtk-4.0,MangoHud}`
     → `~/.config/…`
   - `~/dotfiles/.local/share/ambxst/*` → `~/.local/share/ambxst/…`
   - `~/dotfiles/home/.bashrc` → `~/.bashrc`
4. **Wallpaper:** `wallpapers/*` → `~/Pictures/Wallpapers/`
   (hyprpaper erwartet `~/Pictures/Wallpapers/forest-dark.jpg`).
5. **Ambxst:** `curl -L get.axeni.de/ambxst | sh`, dann `ambxst install hyprland`.
6. **Services:** `sudo systemctl enable sddm.service NetworkManager.service`.

Nach Ab-/Anmeldung in SDDM Session **Hyprland** wählen.

---

## Tastenkürzel (Hyprland)

| Taste | Aktion |
|---|---|
| `Super+Return` | Kitty |
| `Super+Q` | Fenster schliessen |
| `Super+D` | Rofi App-Launcher |
| `Super+E` | Dolphin |
| `Super+F` | Vollbild |
| `Super+V` | Floating toggle |
| `Super+1..9` | Workspace wechseln |
| `Super+Shift+1..9` | Fenster auf Workspace verschieben |
| `Super+Pfeile` | Fokus bewegen |
| `Super+Shift+Pfeile` | Fenster bewegen |
| `Print` | Flameshot Screenshot |

---

## Update

```bash
cd ~/dotfiles
git pull
sudo pacman -S --needed - < pkglist.txt   # falls neue Pakete dazukamen
```
Configs greifen sofort (Symlinks).

## Troubleshooting

- **Boot hängt bei LUKS-Prompt:** Keymap im initramfs ist US. Passphrase
  `1234` hat keine Sonderzeichen – sollte auf CH/US identisch tippbar sein.
  Für CH-Keymap im initramfs `keymap`-Hook vor `encrypt` setzen (ist im Script
  bereits so) und `KEYMAP=de_CH-latin1` in `/etc/vconsole.conf` (macht das
  Script ebenfalls).
- **GRUB findet Root nicht:** `cryptdevice=UUID=` vergleichen mit
  `blkid /dev/sda2` im Recovery.
- **`ambxst`-Command fehlt:** Installer nochmal laufen lassen –
  `curl -L get.axeni.de/ambxst | sh` braucht Internet und `curl`.
