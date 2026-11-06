#!/bin/bash
set -u
TERM="urxvt"

sel="$({
    printf '%s\0icon\x1f%s\n' "opencode" "utilities-terminal"
    printf '%s\0icon\x1f%s\n' "agy" "google"
    printf '%s\0icon\x1f%s\n' "crush" "utilities-terminal"
    printf '%s\0icon\x1f%s\n' "goose" "utilities-terminal"
    printf '%s\0icon\x1f%s\n' "aider" "utilities-terminal"
    printf '%s\0icon\x1f%s\n' "copilot" "github"
    printf '%s\0icon\x1f%s\n' "aichat" "utilities-terminal"
    printf '%s\0icon\x1f%s\n' "freebuff" "utilities-terminal"
} | rofi -dmenu -i -p "Agente" -show-icons \
    -theme-str 'window {width: 380px; location: southeast; anchor: southeast; x-offset: -16px; y-offset: -16px;}' \
    -theme-str 'listview {lines: 8;}' \
    -theme-str 'mainbox {children: ["listview"];}')"

[ -z "${sel:-}" ] && exit 0

case "$sel" in
    opencode) exec "$TERM" -e /home/jorge/.opencode/bin/opencode ;;
    agy) exec "$TERM" -e agy ;;
    crush) exec "$TERM" -e crush ;;
    goose) exec "$TERM" -e goose ;;
    aider) exec "$TERM" -e aider --model openrouter/qwen/qwen3-coder:free ;;
    copilot) exec "$TERM" -e copilot ;;
    aichat) exec "$TERM" -e aichat ;;
    freebuff) exec "$TERM" -e /home/jorge/.npm-global/bin/freebuff ;;
esac
