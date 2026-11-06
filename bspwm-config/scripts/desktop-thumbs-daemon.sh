#!/bin/bash
set -u
CACHE_DIR="$HOME/.cache/desktop-thumbs"
MIN_GAP=5
LAST=0

mkdir -p "$CACHE_DIR"

capture() {
    now="$(date +%s)"
    [ $((now - LAST)) -lt "$MIN_GAP" ] && return 0
    LAST="$now"
    sleep 0.5
    d="$(bspc query -D -d focused --names)"
    full="$(mktemp -u --suffix=.png)"
    if scrot -z "$full" 2>/dev/null; then
        magick "$full" -resize 240x240^ -gravity center -extent 240x240 "$CACHE_DIR/$d.png" 2>/dev/null
    fi
    rm -f "$full"
}

capture

bspc subscribe desktop_focus node_add node_remove node_transfer | while read -r line; do
    case "$line" in
        desktop_focus*|node_add*|node_remove*|node_transfer*) capture ;;
    esac
done
