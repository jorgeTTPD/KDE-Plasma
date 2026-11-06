#!/usr/bin/env bash

killall yad lyric_win.py 2>/dev/null
nohup ~/.config/polybar/scripts/lyric_win.py > /dev/null 2>&1 &

