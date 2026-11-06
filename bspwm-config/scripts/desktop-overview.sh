#!/bin/bash
set -u
CACHE_DIR="$HOME/.cache/desktop-thumbs"
RASI="$HOME/.config/rofi/desktop-strip.rasi"

mkdir -p "$CACHE_DIR"

capture_visible() {
    d="$1"
    full="$(mktemp -u --suffix=.png)"
    if scrot -z "$full" 2>/dev/null; then
        magick "$full" -resize 240x240^ -gravity center -extent 240x240 "$CACHE_DIR/$d.png" 2>/dev/null
    fi
    rm -f "$full"
}

if [ "${1:-}" = "refresh" ]; then
    back_desk="$(bspc query -D -d focused --names)"
    back_node="$(bspc query -N -n focused 2>/dev/null || true)"
    for d in $(bspc query -D --names); do
        bspc desktop -f "$d"
        sleep 0.2
        capture_visible "$d"
        printf '%s' "$(bspc query -N -d "$d" 2>/dev/null | tr '\n' ',')" > "$CACHE_DIR/.$d.sig"
    done
    bspc desktop -f "$back_desk"
    [ -n "$back_node" ] && bspc node -f "$back_node" 2>/dev/null
    md5sum "$HOME/.fehbg" 2>/dev/null | cut -d' ' -f1 > "$CACHE_DIR/.wallpaper.hash"
    exit 0
fi

cur_desk="$(bspc query -D -d focused --names)"
sig="$(bspc query -N -d "$cur_desk" 2>/dev/null | tr '\n' ',')"
wall="$(md5sum "$HOME/.fehbg" 2>/dev/null | cut -d' ' -f1)"
oldsig=""
oldwall=""
[ -f "$CACHE_DIR/.$cur_desk.sig" ] && read -r oldsig < "$CACHE_DIR/.$cur_desk.sig"
[ -f "$CACHE_DIR/.wallpaper.hash" ] && read -r oldwall < "$CACHE_DIR/.wallpaper.hash"
if [ "$sig" != "$oldsig" ] || [ "$wall" != "$oldwall" ] || [ ! -f "$CACHE_DIR/$cur_desk.png" ]; then
    capture_visible "$cur_desk"
    printf '%s' "$sig" > "$CACHE_DIR/.$cur_desk.sig"
    printf '%s' "$wall" > "$CACHE_DIR/.wallpaper.hash"
fi

sel="$(
for d in $(bspc query -D --names); do
    nodes="$(bspc query -N -d "$d" 2>/dev/null)"
    if [ -z "$nodes" ]; then
        icon="desktop"
    else
        fnode="$(bspc query -N -d "$d" -n focused 2>/dev/null)"
        icon="desktop"
        if [ -n "$fnode" ] && printf '%s' "$nodes" | grep -qw "$fnode"; then
            cls="$(xprop -id "$fnode" WM_CLASS 2>/dev/null | grep -oP '"\K[^"]+' | tail -1 | tr '[:upper:]' '[:lower:]')"
            [ -n "$cls" ] && icon="$cls"
        fi
    fi
    [ -f "$CACHE_DIR/$d.png" ] && icon="$CACHE_DIR/$d.png"
    printf '%s\0icon\x1f%s\n' "$d" "$icon"
done | rofi -dmenu -i -p "Escritorio" -theme "$RASI" -show-icons \
    -kb-move-char-back "" -kb-move-char-forward "" \
    -kb-row-up "" -kb-row-down "" \
    -kb-row-left "Left" -kb-row-right "Right" \
    -kb-accept-entry "Return,KP_Enter" -kb-cancel "Escape")"

[ -z "${sel:-}" ] && exit 0

bspc desktop -f "$sel"
