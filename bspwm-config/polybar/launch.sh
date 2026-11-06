#!/usr/bin/env bash

LOG_DIR="$HOME/.local/state/polybar"
mkdir -p "$LOG_DIR"

killall -q polybar yad

while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

polybar mi_barra 2>&1 | tee -a "$LOG_DIR/polybar.log" & disown

echo "Polybar lanzada… (log: $LOG_DIR/polybar.log)"
