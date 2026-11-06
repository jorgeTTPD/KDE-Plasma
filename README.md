# KDE-Plasma / bspwm

Dotfiles y backup de mis entornos en Arch Linux: **KDE Plasma 6** (`kde-config/`) y el stack **bspwm** sobre X11 (`bspwm-config/`).

## Instalación (KDE Plasma)

```bash
git clone https://github.com/jorgeTTPD/KDE-Plasma
cd KDE-Plasma
./install.sh
```

Copia `kde-config/` a `~/.config/`. Cierra sesión e inicia Plasma para aplicar.

## Paquetes

Las listas de paquetes están en `paquetes/`:

```bash
# Repos oficiales
sudo pacman -S - < paquetes/oficiales.txt

# AUR (yay u otro helper)
yay -S - < paquetes/aur.txt
```

## Estructura

```
kde-config/       # config de KDE (kdeglobals, kwinrc, plasmarc, plasmashellrc, plasma/)
bspwm-config/     # stack bspwm sobre X11 (ver abajo)
paquetes/         # listas de paquetes (oficiales.txt, aur.txt)
install.sh        # instalador (KDE)
```

## Stack bspwm (`bspwm-config/`)

- `bspwm/bspwmrc` — arranque del entorno (daemons, reglas, monitor, gaps)
- `sxhkd/sxhkdrc` — atajos de teclado
- `polybar/` — barra (`config.ini` + `config-soundbar.ini`, `scripts/`)
- `picom/picom.conf` — compositor (blur dual_kawase, esquinas redondeadas, animaciones vía `picom-git`)
- `dunst/dunstrc` — notificaciones
- `rofi/` — launchers y menús (copia autocontenida del rofi de ML4W; `.genius.token` NO incluido, ver abajo)
- `scripts/` — scripts de `~/.config/scripts` (menús, wallpaper, battery, etc.)
- `lyrics-overlay/` — overlay karaoke de letras
- `libinput-gestures.conf`, `Xresources` (URxvt)

### Restaurar el stack bspwm

```bash
cp -a bspwm-config/bspwm bspwm-config/sxhkd bspwm-config/polybar \
      bspwm-config/picom bspwm-config/dunst bspwm-config/rofi \
      bspwm-config/scripts bspwm-config/lyrics-overlay ~/.config/
cp bspwm-config/libinput-gestures.conf ~/.config/
cp bspwm-config/Xresources ~/.Xresources
chmod +x ~/.config/bspwm/bspwmrc ~/.config/scripts/*.sh ~/.config/polybar/launch.sh
```

### Notas

- **`.genius.token`** (letras con la API de Genius) nunca se commitea: `bspwm-config/rofi/lyrics/lyrics-fetch.py` lo espera en `~/.config/rofi/lyrics/.genius.token`. Créalo con `echo TU_TOKEN > ~/.config/rofi/lyrics/.genius.token` (permiso 600).
- **`greenclip`** no es un paquete: es un binario propio en `~/.local/bin/greenclip`.
- **`rofi`** originalmente era un symlink a `~/.mydotfiles/com.ml4w.dotfiles.stable/.config/rofi`; aquí va una copia autocontenida (sin `.genius.token`, sin `.git` de `nowplaying`, sin caches).
- **`bspwm-config/polybar/scripts/music-scroll.sh`** limpia caracteres de 4 bytes que la fuente no soporta (p. ej. alfanuméricos matemáticos de Spotify) para no spamear warnings de polybar.
- picom va como `picom-git` del AUR: es el que trae animaciones nativas.

## Colores

Catppuccin Mocha:
- Fondo: `#1e1e2e`
- Texto: `#cdd6f4`
- Acento: `#89b4fa`
- Superficie: `#313244`
- Inactivo: `#6c7086`
