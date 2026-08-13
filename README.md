# KDE-Plasma

Dotfiles y backup de mi entorno **KDE Plasma 6** en Arch Linux: configuración global,
KWin, temas de escritorio, plasmoids y la lista de paquetes instalados.

## Instalación

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
paquetes/         # listas de paquetes (oficiales.txt, aur.txt)
install.sh        # instalador
```

## Colores

Catppuccin Mocha:
- Fondo: `#1e1e2e`
- Texto: `#cdd6f4`
- Acento: `#89b4fa`
- Superficie: `#313244`
- Inactivo: `#6c7086`