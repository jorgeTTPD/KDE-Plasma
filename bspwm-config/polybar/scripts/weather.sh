#!/usr/bin/env bash
CACHE=~/.cache/weather
CACHE_TTL=1800

if [ -f "$CACHE" ]; then
    last_mod=$(stat -c %Y "$CACHE" 2>/dev/null)
    now=$(date +%s)
    age=$((now - last_mod))
    if [ "$age" -lt "$CACHE_TTL" ]; then
        cat "$CACHE"
        exit 0
    fi
fi

weather=$(curl -s "wttr.in/?format=%C+%t" 2>/dev/null)
if [ -n "$weather" ]; then
    echo "$weather" > "$CACHE"
    echo "$weather"
fi