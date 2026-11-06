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

# Limpiar emojis y secuencias sin glifos en la fuente. Los alfanumericos
# matematicos (p. ej. sans-serif bold italic de Spotify) se transliteran a ASCII
clean() {
    python3 -c '
import sys, unicodedata
out = []
for ch in sys.stdin.read():
    try:
        name = unicodedata.name(ch)
    except ValueError:
        name = ""
    if name.startswith("MATHEMATICAL"):
        parts = name.split()
        tok = parts[-1]
        if tok.isdigit():
            out.append(tok); continue
        letters = [p for p in parts if len(p) == 1 and p.isalpha()]
        if letters:
            base = letters[-1]
            out.append(base.lower() if "SMALL" in parts else base.upper()); continue
        out.append(ch); continue
    o = ord(ch)
    if o == 0x200D or 0x2600 <= o <= 0x27BF or 0x2B00 <= o <= 0x2BFF or 0x1F000 <= o <= 0x1FAFF or 0xFE00 <= o <= 0xFE0F:
        continue
    out.append(ch)
sys.stdout.write(" ".join("".join(out).split()))
' 2>/dev/null || cat
}
title="$(printf '%s' "$title" | clean | sed 's/^ *\| *$//g')"
artist="$(printf '%s' "$artist" | clean | sed 's/^ *\| *$//g')"

if [ "$STATUS" = "Paused" ]; then
    echo " ${artist}${artist:+ - }${title}"
else
    echo " ${artist}${artist:+ - }${title}"
fi