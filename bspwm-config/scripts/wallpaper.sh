#!/bin/bash

WALLPAPER_DIR="$HOME/Imágenes/FondoPantalla"
VIDEO_DIR="$HOME/Vídeos/FondoAnimado"
PID_FILE="/tmp/wallpaper-video.pid"
STATE_FILE="$HOME/.cache/current-wallpaper"

random_wallpaper() {
    wall="$(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | shuf -n 1)"
    [ -n "${wall:-}" ] || return 1
    feh --bg-fill "$wall" && echo "$wall" > "$STATE_FILE"
}

video_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

kill_video() {
    if video_running; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    fi
}

start_random_video() {
    kill_video
    video=$(find "$VIDEO_DIR" -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.gif' \) 2>/dev/null | shuf -n 1)
    if [ -n "$video" ]; then
        geo=$(xrandr | grep '*' | head -1 | awk '{print $1}')
        w=${geo%x*}
        h=${geo#*x}
        ffplay -x "$w" -y "$((h - 28))" -left 0 -top 28 -loop 0 -an -vf "scale=$w:-2,crop=$w:$((h-28))" "$video" >/dev/null 2>&1 &
        pid=$!
        echo $pid > "$PID_FILE"
        sleep 1
        wid=$(xdotool search --all --pid "$pid" 2>/dev/null | tail -1)
        [ -n "$wid" ] && xprop -id "$wid" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DESKTOP
    fi
}

case "${1:-}" in
    daemon)
        while true; do
            if ! video_running; then
                random_wallpaper
            fi
            sleep 600
        done
        ;;
    toggle)
        if video_running; then
            kill_video
            random_wallpaper
        else
            start_random_video
        fi
        ;;
    next)
        if video_running; then
            start_random_video
        else
            random_wallpaper
        fi
        ;;
    *)
        random_wallpaper
        ;;
esac
