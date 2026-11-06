#!/usr/bin/env bash

export PATH="$HOME/.local/bin:$PATH"

dir="$HOME/Pictures"
mkdir -p "$dir"

if [ -n "$WAYLAND_DISPLAY" ]; then
    MODE="wayland"
else
    MODE="x11"
fi

options() {
    select="✂"
    window="☐"
    screen="⊞"
    delay="⏱"
    options="$select\n$window\n$screen\n$delay"
}

setFilename() {
    filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
    filepath="$dir/$filename"
}

copy_clipboard() {
    if [ "$MODE" = "wayland" ]; then
        wl-copy -t image/png < "$filepath"
    else
        xclip -selection clipboard -t image/png < "$filepath"
    fi
}

check_case() {
    case $chosen in
        $select)
            setFilename
            if [ "$MODE" = "wayland" ]; then
                grim -g "$(slurp -d)" "$filepath"
            else
                scrot -s "$filepath"
            fi
            ;;
        $window)
            setFilename
            if [ "$MODE" = "wayland" ]; then
                geom=$(mmsg get focusing-client | jq -r '"\(.x),\(.y) \(.width)x\(.height)"')
                grim -g "$geom" "$filepath"
            else
                scrot -u "$filepath"
            fi
            ;;
        $screen)
            setFilename
            if [ "$MODE" = "wayland" ]; then
                grim "$filepath"
            else
                scrot "$filepath"
            fi
            ;;
        $delay)
            setFilename
            if [ "$MODE" = "wayland" ]; then
                sleep 5
                grim "$filepath"
            else
                scrot -d 5 "$filepath"
            fi
            ;;
    esac
    [ -f "$filepath" ] && copy_clipboard
    notify-send "Screenshot" "Lista para pegar (Ctrl+V)"
}

path=$(dirname "$0")
source $path/base.sh

title='Screenshot'
icon=''
icon_menu='vertical.rasi'

case $1 in
    --status) pass ;;
    *) main_menu ;;
esac
