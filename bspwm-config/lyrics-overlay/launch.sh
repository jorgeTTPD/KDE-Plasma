#!/bin/bash
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lyrics-overlay.pid"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    exit 0
fi

bspc rule -a lyrics-overlay state=floating layer=above 2>/dev/null || true
python3 "$HOME/.config/lyrics-overlay/overlay.py" &
echo $! > "$PIDFILE"
