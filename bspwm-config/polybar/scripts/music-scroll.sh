#!/usr/bin/env bash

if ! command -v playerctl &>/dev/null; then
    exit 0
fi

# Elegir el jugador activo: primero el que esté reproduciendo, si no el pausado
PLAYER=""
STATUS=""
for p in $(playerctl -l 2>/dev/null); do
    s="$(playerctl -p "$p" status 2>/dev/null)"
    if [ "$s" = "Playing" ]; then
        PLAYER="$p"
        STATUS="Playing"
        break
    elif [ "$s" = "Paused" ] && [ -z "$PLAYER" ]; then
        PLAYER="$p"
        STATUS="Paused"
    fi
done

[ -n "$PLAYER" ] || exit 0

artist="$(playerctl -p "$PLAYER" metadata artist 2>/dev/null)"
title="$(playerctl -p "$PLAYER" metadata title 2>/dev/null)"

[ -n "$title" ] || exit 0
[ -n "$artist" ] || artist=""

# Limpiar emojis y secuencias de 4 bytes que la fuente no soporta
clean() {
    perl -CSD -pe 's/[\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{1F000}-\x{1FAFF}\x{FE00}-\x{FE0F}\x{200D}]//g; s/\s+/ /g' 2>/dev/null
}
title="$(printf '%s' "$title" | clean | sed 's/^ *\| *$//g')"
artist="$(printf '%s' "$artist" | clean | sed 's/^ *\| *$//g')"

if [ "$STATUS" = "Paused" ]; then
    echo " ${artist}${artist:+ - }${title}"
else
    echo " ${artist}${artist:+ - }${title}"
fi