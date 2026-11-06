#!/usr/bin/env bash
# Flashpoint estatico: tarjeta centrada foto + cita (Super+Y). Esc cierra.
set -u
RASI="$HOME/.config/rofi/flashpoint/flashpoint.rasi"
QUOTE="Let the past die. Kill it, if you have to. That's the only way to become what you were meant to be."

[ -f "$RASI" ] || exit 1

printf 'Flashpoint\n' | rofi \
  -dmenu -i \
  -p "" \
  -mesg "<i>“${QUOTE}”</i>" \
  -markup \
  -no-custom \
  -theme "$RASI" \
  -display-dmenu "Flashpoint" >/dev/null
