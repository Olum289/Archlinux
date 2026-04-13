# Dotfiles – Arch Linux + Hyprland + Ambxst

Komplettes Setup in zwei Stufen, portierbar auf ein frisches System:

1. **`archinstall`** mit `user_configuration.json` + `user_credentials.json` – Arch Base-Install vom Live-ISO.
2. **`install.sh`** – Dotfiles, Pakete, Hyprland-Config, Ambxst, rEFInd, SilentSDDM – nach dem ersten Login als `ops` auszuführen.

## Repo-Inhalt

```
user_configuration.json    # archinstall Config (Locale, Timezone, Bootloader etc.)
user_credentials.json      # archinstall Credentials (User ops)
install.sh                 # Phase 1: Dotfiles + Hyprland + Ambxst + rEFInd als User
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

## Phase 0 – Arch Base-Install (archinstall)

### Voraussetzungen

* Arch-Live-ISO gebootet, UEFI-Modus, Internet via `iwctl`/Ethernet.

### Aufruf

```bash
curl -L -o /root/user_configuration.json https://raw.githubusercontent.com/Olum289/Archlinux/main/user_configuration.json
curl -L -o /root/user_credentials.json https://raw.githubusercontent.com/Olum289/Archlinux/main/user_credentials.json
archinstall --config /root/user_configuration.json --creds /root/user_credentials.json
```

### Was archinstall konfiguriert

| Einstellung       | Wert              |
|-------------------|-------------------|
| Sprache           | English (en_US)   |
| Keyboard          | de_CH-latin1      |
| Timezone          | Europe/Zurich     |
| Hostname          | Arch              |
| Audio             | PipeWire          |
| Bootloader        | GRUB (wird später durch rEFInd ersetzt) |
| Netzwerk          | NetworkManager    |
| Swap              | Ja                |
| User / Passwort   | `ops` / `1234`    |

> **Disk und Dateisystem** (z.B. ext4) werden interaktiv ausgewählt – so funktioniert es auf jeder Hardware.

### Nach archinstall

1. VM herunterfahren / ISO entfernen.
2. System booten, als `ops` einloggen.

---

## Phase 1 – Dotfiles & Hyprland (`install.sh`)

### Voraussetzungen

* Frisch installiertes Arch (via archinstall), User `ops` ist eingeloggt mit `sudo`.
* Internetverbindung.

### Aufruf

```bash
git clone https://github.com/Olum289/Archlinux.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

### Was passiert

1. **Pakete:** `sudo pacman -S --needed --noconfirm - < pkglist.txt`
2. **AUR:** Wenn `yay` fehlt → wird aus dem AUR gebaut. Danach `yay -S --needed --noconfirm - < pkglist-aur.txt`.
3. **Symlinks** (mit Backup vorhandener Dateien nach `~/.dotfiles-backup-<timestamp>/`):
   * `~/dotfiles/.config/{hypr,ambxst,kitty,rofi,gtk-3.0,gtk-4.0,MangoHud}` → `~/.config/…`
   * `~/dotfiles/.local/share/ambxst/*` → `~/.local/share/ambxst/…`
   * `~/dotfiles/home/.bashrc` → `~/.bashrc`
4. **Wallpaper:** `wallpapers/*` → `~/Pictures/Wallpapers/`
5. **Ambxst:** `curl -L get.axeni.de/ambxst | sh`, dann `ambxst install hyprland`.
6. **SilentSDDM:** Konfiguriert SDDM mit dem SilentSDDM-Theme.
7. **rEFInd:** Installiert rEFInd als Boot Manager mit dem [Rich Black Theme](https://github.com/phamhuulocforwork/refind-theme), entfernt GRUB.
8. **Services:** `sudo systemctl enable sddm.service NetworkManager.service`

### Boot-Reihenfolge nach der Installation

```
rEFInd (Boot Manager) → SDDM (SilentSDDM Login) → Hyprland
```

rEFInd erkennt Windows und Linux automatisch – kein manuelles Konfigurieren nötig.

---

## Tastenkürzel (Hyprland)

| Taste                  | Aktion                         |
|------------------------|--------------------------------|
| `Super+Return`         | Kitty                          |
| `Super+Q`              | Fenster schliessen             |
| `Super+D`              | Rofi App-Launcher              |
| `Super+E`              | Dolphin                        |
| `Super+F`              | Vollbild                       |
| `Super+V`              | Floating toggle                |
| `Super+1..9`           | Workspace wechseln             |
| `Super+Shift+1..9`     | Fenster auf Workspace verschieben |
| `Super+Pfeile`         | Fokus bewegen                  |
| `Super+Shift+Pfeile`   | Fenster bewegen                |
| `Print`                | Flameshot Screenshot           |

---

## Update

```bash
cd ~/dotfiles
git pull
sudo pacman -S --needed - < pkglist.txt
```

Configs greifen sofort (Symlinks).

## Troubleshooting

* **Hyprland crasht beim Login (schwarzer Bildschirm):** Wahrscheinlich fehlt
  GPU-Beschleunigung.
* **rEFInd zeigt kein Windows:** Windows-EFI-Partition muss sichtbar sein.
  rEFInd erkennt Windows automatisch über `/EFI/Microsoft/Boot/bootmgfw.efi`.
* **`ambxst`-Command fehlt:** Installer nochmal laufen lassen –
  `curl -L get.axeni.de/ambxst | sh` braucht Internet und `curl`.
* **SDDM sieht hässlich aus:** Prüfen ob `sddm-silent-theme` installiert ist
  und `/etc/sddm.conf.d/silent-theme.conf` existiert.

## Sicherheitshinweis

`1234` ist ein Testpasswort. Vor Produktivnutzung ändern:

```bash
passwd ops
sudo passwd
```
