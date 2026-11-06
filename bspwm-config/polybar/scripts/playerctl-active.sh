#!/usr/bin/env bash

# Ejecuta playerctl contra el jugador activo (el que reproduzca o esté pausado)
if ! command -v playerctl &>/dev/null; then
    exit 1
fi

PLAYER=""
for p in $(playerctl -l 2>/dev/null); do
    s="$(playerctl -p "$p" status 2>/dev/null)"
    if [ "$s" = "Playing" ]; then
        PLAYER="$p"
        break
    elif [ "$s" = "Paused" ] && [ -z "$PLAYER" ]; then
        PLAYER="$p"
    fi
done

if [ -z "$PLAYER" ]; then
    exit 1
fi

exec playerctl -p "$PLAYER" "$@"