#!/usr/bin/env bash
# Installer für Hyprland + Ambxst Dotfiles
# Nutzung:
#   als root:  ./install.sh        -> legt User 'ops' (Passwort '1234') an
#                                     und führt sich danach als 'ops' erneut aus
#   als user:  ./install.sh        -> installiert Pakete, setzt Symlinks, Ambxst

set -euo pipefail

TARGET_USER="ops"
TARGET_PASS="1234"

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\e[1;32m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==>\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

command -v pacman >/dev/null || die "pacman nicht gefunden – ist das wirklich Arch?"

# ---------------------------------------------------------------------------
# 0. Wenn als root gestartet: Zielbenutzer anlegen und Script als ihm erneut starten
# ---------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    log "Root-Modus: lege Benutzer '$TARGET_USER' an (falls nicht vorhanden)"
    if ! id "$TARGET_USER" >/dev/null 2>&1; then
        useradd -m -G wheel -s /bin/bash "$TARGET_USER"
    fi
    echo "${TARGET_USER}:${TARGET_PASS}" | chpasswd
    # wheel-Gruppe bekommt sudo (Arch-Standard, aber sicherstellen)
    if [[ ! -f /etc/sudoers.d/10-wheel ]]; then
        echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
        chmod 440 /etc/sudoers.d/10-wheel
    fi
    # Repo in Home des Zielbenutzers spiegeln, damit Symlinks dauerhaft stimmen
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    if [[ "$DOTFILES" != "$TARGET_HOME/dotfiles" ]]; then
        log "Kopiere Dotfiles nach $TARGET_HOME/dotfiles"
        rm -rf "$TARGET_HOME/dotfiles"
        cp -a "$DOTFILES" "$TARGET_HOME/dotfiles"
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/dotfiles"
    fi
    log "Starte Script erneut als '$TARGET_USER'"
    exec runuser -l "$TARGET_USER" -c "bash '$TARGET_HOME/dotfiles/install.sh'"
fi

BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

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
# 5. Services / Fertig
# ---------------------------------------------------------------------------
log "Aktiviere SDDM und NetworkManager (falls nötig) ..."
sudo systemctl enable sddm.service NetworkManager.service 2>/dev/null || true

log "Fertig!"
log "Backup (falls angelegt): $BACKUP_DIR"
log "Nächste Schritte: Ab- und wieder anmelden, in SDDM 'Hyprland' als Session wählen."
