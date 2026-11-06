#!/bin/bash
# Grabadora de pantalla (X11 / bspwm) basada en ffmpeg.
# Uso:  record.sh [toggle|start|stop|status] [modo]
#       modo: auto|full|sistema|micro|silencio (solo para start/toggle)
#       toggle por defecto. Devuelve "recording" o "idle" en status.
set -u

# Notificaciones vía dunst (dunstify) con ID reemplazable: la de "detenida"
# reemplaza a la de "iniciada" en vez de acumularse. Fallback a notify-send.
NOTIF_ID=997711
notify() {  # notify <urgencia> <icono> <título> <cuerpo> [timeout_ms]
    local to=()
    [ -n "${5:-}" ] && to=(-t "$5")
    if command -v dunstify >/dev/null 2>&1; then
        dunstify -r "$NOTIF_ID" -a "Grabadora" -u "$1" -i "$2" "${to[@]}" "$3" "$4" 2>/dev/null
    else
        notify-send -u "$1" -i "$2" "${to[@]}" "$3" "$4" 2>/dev/null
    fi
}

if ! command -v ffmpeg >/dev/null 2>&1; then
    notify critical dialog-warning "Grabación" "ffmpeg no está instalado"
    echo "ffmpeg no encontrado" >&2
    exit 1
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNTIME_DIR/screenrec-ffmpeg.pid"
STARTFILE="$RUNTIME_DIR/screenrec-start"
TIMERPID="$RUNTIME_DIR/screenrec-notify.pid"
LOGFILE="$RUNTIME_DIR/screenrec-ffmpeg.log"

OUTDIR="$(xdg-user-dir VIDEOS 2>/dev/null)"
[ -z "$OUTDIR" ] && OUTDIR="$HOME/Vídeos"
mkdir -p "$OUTDIR"

FPS=30
CRF=23
PRESET="ultrafast"

is_recording() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
}

build_input() {
    local disp="${DISPLAY:-:0}"
    # ffmpeg espera pantalla:  :0.0
    case "$disp" in
        *.*) ;;
        *)   disp="$disp.0" ;;
    esac
    printf '%s' "$disp"
}

fmt_elapsed() {  # fmt_elapsed <segundos> -> MM:SS o HH:MM:SS
    local s="${1:-0}" h m
    h=$((s / 3600)); m=$(((s % 3600) / 60)); s=$((s % 60))
    if [ "$h" -gt 0 ]; then
        printf '%02d:%02d:%02d' "$h" "$m" "$s"
    else
        printf '%02d:%02d' "$m" "$s"
    fi
}

kill_timer() {
    local tpid
    tpid="$(cat "$TIMERPID" 2>/dev/null)"
    [ -n "$tpid" ] && kill "$tpid" 2>/dev/null
    rm -f "$TIMERPID"
}

timer_loop() {  # timer_loop <basename> <inicio_epoch> <audio_desc>
    local base="$1" t0="$2" desc="$3" now el
    while true; do
        now="$(date +%s)"
        el=$((now - t0))
        [ "$el" -lt 0 ] && el=0
        notify normal media-record "● REC ($desc)" "$base
$(fmt_elapsed "$el")" 0
        sleep 1
    done
}

start() {
    local mode="${1:-auto}"
    local res file disp sink sys_src mic def_suspended
    res="$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}')"
    [ -z "$res" ] && res="1366x768"

    file="$OUTDIR/$(date +%Y%m%d).mp4"
    if [ -e "$file" ]; then
        local n=1
        while [ -e "$OUTDIR/$(date +%Y%m%d)_$n.mp4" ]; do n=$((n + 1)); done
        file="$OUTDIR/$(date +%Y%m%d)_$n.mp4"
    fi
    disp="$(build_input)"

    local -a args=(
        -hide_banner -loglevel warning -y
        -f x11grab -framerate "$FPS" -video_size "$res" -i "$disp"
    )

    # Audio del sistema (monitor del sink por defecto en PipeWire/PulseAudio)
    sink="$(pactl get-default-sink 2>/dev/null)"
    sys_src=""
    if [ -n "$sink" ] && pactl list short sources 2>/dev/null | grep -qF "${sink}.monitor"; then
        sys_src="${sink}.monitor"
    fi

    # Micro real: ignora monitores (tu default-source actual es un .monitor)
    mic="$(pactl get-default-source 2>/dev/null)"
    case "$mic" in
        ""|*.monitor|*MeetMusic*|*MeetMicMix*) mic="" ;;
    esac
    if [ -z "$mic" ] || ! pactl list short sources 2>/dev/null | grep -qF "$mic"; then
        mic=""
    elif [ "$(pactl list short sources 2>/dev/null | awk -v m="$mic" '$2==m {print $NF}')" != "RUNNING" ]; then
        def_suspended="$mic"; mic=""
    fi
    if [ -z "$mic" ]; then
        mic="$(pactl list short sources 2>/dev/null | awk '$2 ~ /pci-0000_03_00\.6\.analog-stereo$/ && $2 ~ /^alsa_input/ {print $2; exit}')"
        [ -z "$mic" ] && mic="$(pactl list short sources 2>/dev/null | awk '$NF == "RUNNING" && $2 ~ /^alsa_input/ && $2 !~ /mono-fallback/ {print $2; exit}')"
        [ -z "$mic" ] && mic="$(pactl list short sources 2>/dev/null | awk '$NF == "RUNNING" && $2 ~ /^alsa_input/ {print $2; exit}')"
        [ -z "$mic" ] && mic="${def_suspended:-}"
        [ -z "$mic" ] && mic="$(pactl list short sources 2>/dev/null | awk '$2 ~ /^alsa_input/ && $2 !~ /mono-fallback/ {print $2; exit}')"
        [ -z "$mic" ] && mic="$(pactl list short sources 2>/dev/null | awk '$2 ~ /^alsa_input/ {print $2; exit}')"
    fi

    # Filtro por modo pedido por el usuario (Super+S -> submenu)
    case "$mode" in
        sistema|sin-micro|sinmicro) mic="" ;;
        micro|solo-micro|solomicro) sys_src="" ;;
        silencio|mudo|silente|sin-audio|sinaudio) sys_src=""; mic="" ;;
        full|con-micro|conmicro|ambos) ;;
        auto|* ) ;;
    esac

    if [ -n "$sys_src" ]; then
        args+=(-thread_queue_size 1024 -f pulse -i "$sys_src")
    fi
    if [ -n "$mic" ]; then
        args+=(-thread_queue_size 1024 -f pulse -i "$mic")
    fi

    args+=(-c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p)

    local audio_desc="sin audio"
    local den_sys="highpass=f=120,afftdn=nf=-25:nr=12,afftdn=nf=-30:nr=6"
    local den_mic="highpass=f=120,afftdn=nf=-25:nr=12,afftdn=nf=-30:nr=6"
    if [ -n "$sys_src" ] && [ -n "$mic" ]; then
        args+=(-filter_complex "[1:a]${den_sys}[sys];[2:a]${den_mic}[mic];[sys][mic]amix=inputs=2:duration=longest:dropout_transition=2:normalize=0,alimiter=limit=0.95[a]" -map 0:v -map "[a]" -c:a aac -b:a 160k -ac 2)
        audio_desc="sistema+micro"
    elif [ -n "$sys_src" ] || [ -n "$mic" ]; then
        args+=(-map 0:v -map 1:a -af "${den_mic},alimiter=limit=0.95" -c:a aac -b:a 160k -ac 2)
        [ -n "$mic" ] && audio_desc="solo micro" || audio_desc="solo sistema"
    else
        args+=(-map 0:v)
    fi

    args+=(-movflags +faststart "$file")
    { echo "sys_src=$sys_src"; echo "mic=$mic"; echo "desc=$audio_desc"; } >"$LOGFILE"
    ffmpeg "${args[@]}" >>"$LOGFILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    disown 2>/dev/null

    sleep 1
    if is_recording; then
        # -t 0: queda fija como indicador REC y la de "detenida" la reemplaza
        # Formato 3 filas: título / archivo / contador
        local t0 base
        t0="$(date +%s)"
        echo "$t0" > "$STARTFILE"
        base="$(basename "$file")"
        kill_timer
        notify normal media-record "● REC ($audio_desc)" "$base
00:00" 0
        timer_loop "$base" "$t0" "$audio_desc" &
        echo "$!" > "$TIMERPID"
        disown 2>/dev/null
        printf '%s' "$file"
    else
        rm -f "$PIDFILE" "$STARTFILE"
        notify critical dialog-warning "Grabación" "No se pudo iniciar. Ver $LOGFILE"
        return 1
    fi
}

stop() {
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null)"
    [ -z "$pid" ] && return 0

    # SIGINT permite que ffmpeg cierre el archivo correctamente
    kill -INT "$pid" 2>/dev/null
    local i
    for i in $(seq 1 100); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null
    local t0 now el dur="00:00"
    if [ -f "$STARTFILE" ]; then
        t0="$(cat "$STARTFILE" 2>/dev/null)"
        now="$(date +%s)"
        if [ -n "$t0" ] && [ "$now" -ge "$t0" ] 2>/dev/null; then
            el=$((now - t0))
            dur="$(fmt_elapsed "$el")"
        fi
    fi
    kill_timer
    rm -f "$PIDFILE" "$STARTFILE"

    notify normal media-playback-stop "Grabación detenida" "Video guardado en $(basename "$OUTDIR") · $dur"
}

case "${1:-toggle}" in
    start)
        is_recording || start "${2:-auto}"
        ;;
    stop)
        is_recording && stop
        ;;
    toggle)
        if is_recording; then stop; else start "${2:-auto}"; fi
        ;;
    status)
        if is_recording; then echo "recording"; else echo "idle"; fi
        ;;
    *)
        echo "Uso: $0 [toggle|start|stop|status] [auto|full|sistema|micro|silencio]" >&2
        exit 2
        ;;
esac
