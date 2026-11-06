#!/usr/bin/env bash

while true; do
  track=$(playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo "")
  if [ -n "$track" ]; then
    printf '󰎈 %.28s\n' "$track"
  else
    echo "󰎈 Sin música"
  fi
  sleep 2
done