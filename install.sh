#!/usr/bin/env bash
# Installer für Hyprland + Ambxst Dotfiles
# Nutzung: ./install.sh   (nicht als root ausführen, sudo wird bei Bedarf gefragt)

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

log()  { printf '\e[1;32m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==>\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Bitte NICHT als root ausführen. sudo wird nur wo nötig verwendet."
command -v pacman >/dev/null || die "pacman nicht gefunden – ist das wirklich Arch?"

# ---------------------------------------------------------------------------
# 1. Pakete installieren
# ---------------------------------------------------------------------------
if [[ -f "$DOTFILES/pkglist.txt" ]]; then
    log "Installiere offizielle Pakete aus pkglist.txt ..."
    sudo pacman -S --needed --noconfirm - < "$DOTFILES/pkglist.txt"
fi

if [[ -f "$DOTFILES/pkglist-aur.txt" && -s "$DOTFILES/pkglist-aur.txt" ]]; then
    if ! command -v yay >/dev/null; then
        warn "yay nicht gefunden – installiere yay aus dem AUR ..."
        sudo pacman -S --needed --noconfirm git base-devel
        tmp=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmp/yay"
        (cd "$tmp/yay" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    log "Installiere AUR-Pakete aus pkglist-aur.txt ..."
    yay -S --needed --noconfirm - < "$DOTFILES/pkglist-aur.txt"
fi

# ---------------------------------------------------------------------------
# 2. Symlinks setzen
# ---------------------------------------------------------------------------
link() {
    local src="$1" dst="$2"
    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            return 0
        fi
        mkdir -p "$BACKUP_DIR$(dirname "$dst")"
        mv "$dst" "$BACKUP_DIR$(dirname "$dst")/"
        warn "Backup: $dst -> $BACKUP_DIR"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    log "Link: $dst -> $src"
}

log "Setze Symlinks nach ~/.config/ ..."
for dir in hypr ambxst kitty rofi gtk-3.0 gtk-4.0 MangoHud; do
    [[ -d "$DOTFILES/.config/$dir" ]] && link "$DOTFILES/.config/$dir" "$HOME/.config/$dir"
done

log "Setze Symlink für ~/.local/share/ambxst ..."
mkdir -p "$HOME/.local/share/ambxst"
for f in "$DOTFILES"/.local/share/ambxst/*; do
    [[ -e "$f" ]] || continue
    link "$f" "$HOME/.local/share/ambxst/$(basename "$f")"
done

log "Setze Symlink für ~/.bashrc ..."
link "$DOTFILES/home/.bashrc" "$HOME/.bashrc"

# ---------------------------------------------------------------------------
# 3. Wallpaper
# ---------------------------------------------------------------------------
log "Kopiere Wallpapers nach ~/Pictures/Wallpapers/ ..."
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$DOTFILES"/wallpapers/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Ambxst installieren
# ---------------------------------------------------------------------------
if ! command -v ambxst >/dev/null; then
    log "Installiere Ambxst ..."
    curl -L get.axeni.de/ambxst | sh
fi

if command -v ambxst >/dev/null; then
    log "Richte Ambxst für Hyprland ein ..."
    ambxst install hyprland || warn "ambxst install hyprland fehlgeschlagen – manuell prüfen"
fi

# ---------------------------------------------------------------------------
# 5. SDDM Theme (SilentSDDM) konfigurieren
# ---------------------------------------------------------------------------
log "Konfiguriere SDDM mit SilentSDDM Theme ..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/silent-theme.conf > /dev/null << 'EOF'
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
EOF

# ---------------------------------------------------------------------------
# 6. rEFInd Boot Manager + Theme installieren, GRUB entfernen
# ---------------------------------------------------------------------------
log "Installiere rEFInd Boot Manager ..."
sudo refind-install

# Kernel-Parameter für rEFInd generieren
log "Generiere rEFInd Kernel-Konfiguration ..."
sudo mkrlconf

log "Installiere rEFInd Theme ..."
tmp=$(mktemp -d)
git clone --depth=1 https://github.com/phamhuulocforwork/refind-theme.git "$tmp/refind-theme"
sudo mkdir -p /boot/EFI/refind/refind-theme
sudo cp -r "$tmp/refind-theme/fonts" "$tmp/refind-theme/icons" \
           "$tmp/refind-theme/background.png" "$tmp/refind-theme/selection_big.png" \
           "$tmp/refind-theme/selection_small.png" "$tmp/refind-theme/theme.conf" \
           /boot/EFI/refind/refind-theme/
rm -rf "$tmp"

# Theme in refind.conf einbinden
if ! grep -q 'refind-theme/theme.conf' /boot/EFI/refind/refind.conf 2>/dev/null; then
    echo '' | sudo tee -a /boot/EFI/refind/refind.conf > /dev/null
    echo 'include refind-theme/theme.conf' | sudo tee -a /boot/EFI/refind/refind.conf > /dev/null
fi

# GRUB entfernen
log "Entferne GRUB (rEFInd übernimmt) ..."
sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable 2>/dev/null || true
sudo efibootmgr -v 2>/dev/null | grep -i grub | grep -oP 'Boot\K[0-9A-Fa-f]{4}' | while read entry; do
    sudo efibootmgr -b "$entry" -B 2>/dev/null || true
done
sudo rm -rf /boot/grub
sudo rm -rf /boot/EFI/GRUB
sudo pacman -Rns --noconfirm grub 2>/dev/null || true

log "rEFInd ist jetzt der Boot Manager. Windows wird automatisch erkannt."

# ---------------------------------------------------------------------------
# 7. Services / Fertig
# ---------------------------------------------------------------------------
log "Aktiviere SDDM und NetworkManager (falls nötig) ..."
sudo systemctl enable sddm.service NetworkManager.service 2>/dev/null || true

log "Fertig!"
log "Backup (falls angelegt): $BACKUP_DIR"
log "Nächste Schritte: Ab- und wieder anmelden, in SDDM 'Hyprland' als Session wählen."
