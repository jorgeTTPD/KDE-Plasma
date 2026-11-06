#!/usr/bin/env bash
if command -v bluetoothctl &>/dev/null; then
    devices=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
    if [ "$devices" -gt 0 ]; then
        echo ""
    fi
fi