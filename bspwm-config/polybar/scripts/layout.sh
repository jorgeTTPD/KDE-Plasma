#!/usr/bin/env bash
while true; do
    layout=$(bspc query -T -d focused | jq -r '.layout' 2>/dev/null || echo "tiled")
    case "$layout" in
        "tiled") echo "" ;;
        "monocle") echo "" ;;
        *) echo "" ;;
    esac
    sleep 0.5
done