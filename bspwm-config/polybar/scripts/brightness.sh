#!/usr/bin/env bash

while true; do
  pct=$(brightnessctl i 2>/dev/null | grep -oP '\d+%' | tr -d '%')
  pct=${pct:-0}

  if [ "$pct" -le 25 ]; then
    icon="󰃝"
  elif [ "$pct" -le 50 ]; then
    icon="󰃞"
  elif [ "$pct" -le 75 ]; then
    icon="󰃟"
  else
    icon="󰃠"
  fi

  echo "$icon $pct%"
  sleep 0.1
done