#!/usr/bin/env bash
# instalador de dotfiles KDE Plasma — copia la config a ~/.config
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Instalando dotfiles KDE Plasma..."

if [ -d "$DIR/kde-config" ]; then
    cp -r "$DIR/kde-config"/. "$HOME/.config"/
    echo "  ✓ ~/.config (kdeglobals, kwinrc, plasmarc, plasmashellrc, plasma…) "
fi

echo "✅ Listo. Cierra sesión e inicia en Plasma para aplicar."

echo
echo "Paquetes necesarios:"
echo "  oficiales → sudo pacman -S - < paquetes/oficiales.txt"
echo "  AUR       → yay -S - < paquetes/aur.txt"