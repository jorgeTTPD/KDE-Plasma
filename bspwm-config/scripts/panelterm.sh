#!/bin/bash
# Abre una terminal urxvt flotante pegada al lateral izquierdo (modo "panel")
# y ejecuta un comando mostrando su salida. Pensado para operaciones con sudo.
# Uso: panelterm.sh "<Título>" "<comandos bash>"
set -u

TITLE="${1:-Sistema}"
CMDS="${2:-}"
if [ -z "$CMDS" ]; then
    echo "Uso: $0 <titulo> <comandos>" >&2
    exit 2
fi

INSTANCE="sysmenu-term"

# Prefiere urxvtc (rápido, usa el daemon) si urxvtd está corriendo; si no, urxvt.
if command -v urxvtc >/dev/null 2>&1 && pgrep -x urxvtd >/dev/null 2>&1; then
    TERM_BIN="urxvtc"
elif command -v urxvt >/dev/null 2>&1; then
    TERM_BIN="urxvt"
else
    notify-send -u critical "Sistema" "urxvt no encontrado" 2>/dev/null
    echo "urxvt no encontrado" >&2
    exit 1
fi

# urxvtc/-name no lee el perfil: garantizamos el PATH de usuario
export PATH="$HOME/.local/bin:$PATH"

# --- tamaño del panel según la resolución actual ---
W=1366; H=768
if command -v xrandr >/dev/null 2>&1; then
    res="$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}')"
    if [ -n "$res" ]; then W="${res%x*}"; H="${res#*x}"; fi
fi
case "${W}${H}" in ""|*[!0-9]*) W=1366; H=768 ;; esac
PW=$(( W * 42 / 100 ))
[ "$PW" -lt 430 ] && PW=430
PH=$(( H - 40 ))

# --- regla bspwm: flotante, sticky y anclada a la izquierda ---
# urxvt reporta WM_CLASS = "sysmenu-term", "URxvt"  =>  clase URxvt, instancia sysmenu-term.
if command -v bspc >/dev/null 2>&1; then
    if ! bspc rule -l 2>/dev/null | grep -q ":${INSTANCE}:"; then
        bspc rule -a "URxvt:${INSTANCE}" state=floating sticky=on \
            rectangle="${PW}x${PH}+4+30" focus=on 2>/dev/null
    fi
fi

notify-send -u low "$TITLE" "Abriendo terminal…" 2>/dev/null

export PANEL_TITLE="$TITLE"
export PANEL_CMD="$CMDS"

exec "$TERM_BIN" -name "$INSTANCE" -title "$TITLE" -e bash -c '
    printf "\n\033[1;36m── %s ──\033[0m\n\n" "$PANEL_TITLE"
    eval "$PANEL_CMD"
    rc=$?
    printf "\n\033[2m── fin (código %s) · pulsa una tecla para cerrar ──\033[0m\n" "$rc"
    read -n1 -r
' 2>/dev/null
