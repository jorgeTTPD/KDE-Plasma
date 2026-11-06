#!/usr/bin/env bash

killall -q polybar yad

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

polybar mi_barra 2>&1 | tee -a /tmp/polybar.log & disown

echo "Polybar lanzada..."
