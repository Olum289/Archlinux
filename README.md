# Dotfiles – Hyprland + Ambxst (Arch Linux)

Mein persönliches Setup: Hyprland mit Ambxst-Shell, daneben bestehendes KDE Plasma,
SDDM als Login-Manager.

## Inhalt

```
.config/
  hypr/         # Hyprland, hyprpaper, hypridle, hyprlock
  ambxst/       # Ambxst Shell Config (bar, dock, theme, ...)
  kitty/        # Terminal
  rofi/         # App-Launcher (ambxst-dark.rasi)
  gtk-3.0/      # GTK3 Theme
  gtk-4.0/      # GTK4 Theme
  MangoHud/     # Gaming-Overlay
.local/share/ambxst/   # axctl.toml, hyprland-Ambxst-Bridge
home/.bashrc
wallpapers/            # forest-dark.jpg
pkglist.txt            # offizielle Pakete (pacman)
pkglist-aur.txt        # AUR-Pakete (yay)
install.sh
```

Bewusst **nicht** im Repo: Ambxst-Datenbanken (`keys.db`, `clipboard.db`),
Chat-Verlauf und Clipboard-Daten aus `~/.local/share/ambxst/`.

## Installation auf einem frischen Arch-System

Voraussetzungen:
- Arch Linux, Benutzer in Gruppe `wheel` mit `sudo`
- Internetverbindung
- KDE Plasma optional (bleibt erhalten, falls bereits installiert)

```bash
git clone <REPO-URL> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Das Script:
1. Installiert alle Pakete aus `pkglist.txt` (pacman) und `pkglist-aur.txt` (yay,
   wird bei Bedarf selbst gebaut).
2. Legt Backups vorhandener Configs unter `~/.dotfiles-backup-<timestamp>/` ab.
3. Verlinkt alle Configs per Symlink nach `~/.config/`, `~/.local/share/ambxst/`
   und `~/.bashrc`.
4. Kopiert Wallpapers nach `~/Pictures/Wallpapers/`.
5. Installiert Ambxst via `curl -L get.axeni.de/ambxst | sh` und führt
   `ambxst install hyprland` aus.
6. Aktiviert `sddm` und `NetworkManager`.

Danach ab- und wieder anmelden und in SDDM die Session **Hyprland** wählen.
KDE Plasma bleibt als Alternative erhalten.

## Wichtige Tastenkürzel (Hyprland)

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

## Hinweise

- **Tastaturlayout:** CH (Schweizerdeutsch), in `hypr/hyprland.conf` gesetzt.
- **Locale/Zeitzone:** `de_CH.UTF-8`, `Europe/Zurich` — nicht Teil der Dotfiles,
  auf einem neuen System separat setzen (`localectl`, `timedatectl`).
- **Wallpaper-Pfad:** `hyprpaper.conf` erwartet das Wallpaper unter
  `~/Pictures/Wallpapers/forest-dark.jpg` – `install.sh` legt es dort an.
- **Ambxst-Geheimnisse:** `keys.db` aus `~/.local/share/ambxst/` wird beim
  ersten Start neu erzeugt.

## Update

```bash
cd ~/dotfiles
git pull
# Neue Configs greifen sofort, da verlinkt. Pakete ggf. nachziehen:
sudo pacman -S --needed - < pkglist.txt
```
