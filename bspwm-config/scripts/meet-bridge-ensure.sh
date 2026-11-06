#!/bin/bash
# Cuidador del puente Meet (MeetMusic/MeetMicMix).
# Vive mientras exista ~/.cache/meet-bridge-want. Cada 5s:
#   - recrea el puente si falta el sink o la source
#   - mantiene cmus ruteado a MeetMusic
set -u
WANT="$HOME/.cache/meet-bridge-want"
STATE="$HOME/.cache/audiomenu_bridge"
PIDF="$HOME/.cache/meet-bridge.pid"
SINK="MeetMusic"
SRC="MeetMicMix"
echo $$ > "$PIDF"

alive() {
    pactl list short sinks 2>/dev/null | grep -q "[[:space:]]$SINK[[:space:]]" &&
    pactl list short sources 2>/dev/null | grep -q "[[:space:]]$SRC[[:space:]]"
}

build() {
    local def_sink def_src real_mic id1 id2 id3 id4
    def_sink="$(pactl get-default-sink 2>/dev/null)"
    def_src="$(pactl get-default-source 2>/dev/null)"
    [ -z "${def_sink:-}" ] && return 1
    real_mic=""
    case "${def_src:-}" in
        ""|*.monitor|*MeetMusic*|*MeetMicMix*) ;;
        *) pactl list short sources 2>/dev/null | grep -qF "$def_src" && real_mic="$def_src" ;;
    esac
    [ -z "$real_mic" ] && real_mic="$(pactl list short sources 2>/dev/null | awk '$2 ~ /^alsa_input/ {print $2; exit}')"
    [ -z "$real_mic" ] && return 1
    id1="$(pactl load-module module-null-sink sink_name="$SINK" sink_properties=device.description="$SINK" 2>/dev/null)" || return 1
    sleep 0.3
    id2="$(pactl load-module module-remap-source master="$SINK.monitor" source_name="$SRC" source_properties=device.description="$SRC" 2>/dev/null)"
    id3="$(pactl load-module module-loopback source="$real_mic" sink="$SINK" latency_msec=20 2>/dev/null)"
    id4="$(pactl load-module module-loopback source="$SINK.monitor" sink="$def_sink" latency_msec=20 2>/dev/null)"
    printf '%s\n' "$id1" "$id2" "$id3" "$id4" > "$STATE"
    pactl set-sink-volume "$SINK" 100% 2>/dev/null
    pactl set-sink-mute "$SINK" 0 2>/dev/null
}

route_cmus() {
    local i
    for i in $(pactl list sink-inputs 2>/dev/null | awk '/^Sink Input #/{id=$3} /application.name = "C\* Music Player"/{print id}' | tr -d '#'); do
        pactl move-sink-input "$i" "$SINK" 2>/dev/null
    done
}

while true; do
    if [ -f "$WANT" ]; then
        alive || build
        route_cmus
    fi
    sleep 5
done
