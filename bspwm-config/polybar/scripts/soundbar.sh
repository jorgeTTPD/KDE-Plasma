#!/usr/bin/env bash
set -u
FIFO="/tmp/soundbar.fifo"
LOCK="/tmp/soundbar.lock"
BIN="/home/jorge/.cargo/bin/soundbar"
ERRLOG="/tmp/soundbar-errors.log"

exec 9>"$LOCK"
flock 9 || exit 0

rm -f /tmp/soundbar.pid

[ -p "$FIFO" ] || { rm -f "$FIFO"; mkfifo "$FIFO"; }

writer_pid() {
    pgrep -f "^$BIN --bars 8$" 2>/dev/null | head -n 1
}

start_writer() {
    pkill -f "^$BIN --bars 8$" 2>/dev/null
    sleep 0.2
    "$BIN" --bars 8 > "$FIFO" 2>>"$ERRLOG" &
}

render() {
    bars=" ▂▃▄▅▆▇█"
    output=""
    IFS=';' read -ra values <<< "$1"
    for v in "${values[@]}"; do
        if [ "$v" -ge 0 ] 2>/dev/null && [ "$v" -le 7 ] 2>/dev/null; then
            output+="${bars:$v:1}"
        else
            output+=" "
        fi
    done
    printf '%s\n' "$output"
}

while true; do
    [ -n "$(writer_pid)" ] || start_writer
    exec 8<"$FIFO"
    while true; do
        if read -r -t 5 -u 8 line; then
            render "$line"
        elif [ -n "$(writer_pid)" ]; then
            continue
        else
            break
        fi
    done
    exec 8<&-
done
