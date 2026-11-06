#!/bin/bash
set -u
WALL_DIR="$HOME/Imágenes/FondoPantalla"
CACHE_DIR="$HOME/.cache/wallpaper-thumbs"
RASI="$HOME/.config/rofi/wallpaper-strip.rasi"
PID_FILE="/tmp/wallpaper-video.pid"
STATE_FILE="$HOME/.cache/current-wallpaper"

mkdir -p "$CACHE_DIR"

if [ ! -d "$WALL_DIR" ]; then
    notify-send "Wallpapers" "No existe $WALL_DIR" 2>/dev/null || echo "No existe $WALL_DIR" >&2
    exit 1
fi

LIST="$(mktemp)"
QUEUE="$(mktemp)"
trap 'rm -f "$LIST" "$QUEUE"' EXIT

find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z > "$LIST"

[ -s "$LIST" ] || exit 1

current=""
if ! { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }; then
    current="$(grep -o "'[^']*'" "$HOME/.fehbg" 2>/dev/null | tr -d "'" | head -1)"
    if [ -z "$current" ] || [ ! -f "$current" ]; then
        if [ -f "$STATE_FILE" ]; then
            read -r current < "$STATE_FILE" 2>/dev/null || current=""
        fi
    fi
fi
idx=0
if [ -n "$current" ]; then
    current_name="${current##*/}"
    i=0
    while IFS= read -r -d '' p; do
        if [ "${p##*/}" = "$current_name" ]; then
            idx=$i
            break
        fi
        i=$((i + 1))
    done < "$LIST"
fi

sel="$(
while IFS= read -r -d '' p; do
    n="${p##*/}"
    t="$CACHE_DIR/$n"
    m="$CACHE_DIR/.$n.meta"
    icon="$p"
    if [ -f "$t" ] && [ -f "$m" ]; then
        read -r old < "$m"
        if [ "$(stat -c '%s %Y' "$p")" = "$old" ]; then
            icon="$t"
        else
            printf '%s\0' "$p" >> "$QUEUE"
        fi
    else
        printf '%s\0' "$p" >> "$QUEUE"
    fi
    printf '%s\0icon\x1f%s\n' "$n" "$icon"
done < "$LIST" | rofi -dmenu -i -p "Fondo" -theme "$RASI" -show-icons -selected-row "$idx" \
    -kb-move-char-back "" -kb-move-char-forward "" \
    -kb-row-up "" -kb-row-down "" \
    -kb-row-left "" -kb-row-right "" \
    -kb-element-prev "Left" -kb-element-next "Right" \
    -kb-page-prev "Up" -kb-page-next "Down" \
    -kb-accept-entry "Return,KP_Enter" -kb-cancel "Escape")"

if [ -s "$QUEUE" ]; then
    (
    while IFS= read -r -d '' p; do
        n="${p##*/}"
        if magick "$p" -resize 160x160^ -gravity center -extent 160x160 "$CACHE_DIR/$n" 2>/dev/null; then
            stat -c '%s %Y' "$p" > "$CACHE_DIR/.$n.meta"
        fi
    done < "$QUEUE"
    rm -f "$QUEUE"
    ) &
else
    rm -f "$QUEUE"
fi

[ -z "${sel:-}" ] && exit 0

target="$WALL_DIR/$sel"
if [ ! -f "$target" ]; then
    notify-send "Wallpapers" "No se pudo poner: $sel" 2>/dev/null || echo "No se pudo poner: $sel" >&2
    exit 1
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
fi

feh --bg-fill "$target" && echo "$target" > "$STATE_FILE"
