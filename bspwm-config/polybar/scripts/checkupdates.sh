#!/usr/bin/env bash
if command -v checkupdates &>/dev/null; then
    updates=$(checkupdates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo " $updates"
    fi
fi