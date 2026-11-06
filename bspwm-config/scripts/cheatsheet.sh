#!/bin/bash
# Cheat sheet de keybindings para bspwm
# Se muestra con super+shift+c

cat << 'EOF' | rofi -dmenu -p "⌨ Keybindings" -config ~/.config/rofi/cheatsheet.rasi -selected-row 0 -no-select
  super + Return         → Terminal (urxvt)
  super + d              → App Launcher (rofi drun)
  super + p              → Música local (~/Music)
  super + o              → Now playing (MPRIS)
  super + shift + q      → Cerrar ventana
  super + arrows         → Mover foco
  super + 1-5            → Cambiar escritorio
  super + shift + 1-5    → Mover ventana a escritorio
  super + m              → Alternar monocle
  super + f              → Pantalla completa
  super + Escape         → Power Menu
  super + v              → Clipboard history (greenclip)
  super + w              → Wallpaper aleatorio
  super + l              → Bloquear pantalla
  super + shift + c      → Este cheat sheet
  Print                  → Screenshot
  XF86Audio              → Volumen / música
  XF86MonBrightness      → Brillo
EOF
