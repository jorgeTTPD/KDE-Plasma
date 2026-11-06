#!/bin/bash
# Menú de sistema (Super+S) — bspwm + rofi + dunst
# Sin sudo -> se ejecuta por detrás en una sesión tmux (sin ventana).
# Con sudo -> abre una terminal urxvt (panel flotante a la izquierda).
set -u

SCRIPTS="$HOME/.config/scripts"
RASI="$HOME/.config/rofi/sysmenu.rasi"
LOGDIR="$HOME/.cache/sysmenu"
LOG="$LOGDIR/last.log"
RECORD="$SCRIPTS/record.sh"
mkdir -p "$LOGDIR"
rm -f "$LOGDIR"/run_*.sh 2>/dev/null

# ---------------------------------------------------------------- helpers ----
# Operaciones CON sudo: terminal normal que se cierra sola al terminar.
run_term() {
    local title="$1" cmds="$2"
    local term="urxvt"
    command -v urxvtc >/dev/null 2>&1 && pgrep -x urxvtd >/dev/null 2>&1 && term="urxvtc"
    export PATH="$HOME/.local/bin:$PATH"
    "$term" -title "$title" -e bash -c "$cmds" &
    disown 2>/dev/null
}

# Operaciones SIN sudo: se ejecutan por detrás en tmux y notifican al terminar.
bg() {
    local title="$1" cmds="$2"
    local script="$LOGDIR/run_$$_$(date +%s%N).sh"
    cat > "$script" <<SYS_EOF
#!/bin/bash
{
echo "== $(date '+%F %T') PATH=$PATH"
$cmds
} >"$LOG" 2>&1
rc=\$?
if [ \$rc -eq 0 ]; then
    notify-send "$title" "✅ Completado" 2>/dev/null
else
    notify-send -u critical "$title" "❌ Falló (ver $LOG)" 2>/dev/null
fi
rm -f "$script"
SYS_EOF
    chmod +x "$script"
    notify-send -u low "⏳ $title" "En segundo plano (tmux)…" 2>/dev/null
    # El servidor tmux no hereda nuestro entorno: pasamos DISPLAY/PATH (y el socket de bspwm).
    local -a tenv=(-e "DISPLAY=${DISPLAY:-:0}" -e "PATH=$PATH")
    [ -n "${BSPWM_SOCKET:-}" ] && tenv+=(-e "BSPWM_SOCKET=$BSPWM_SOCKET")
    if ! { command -v tmux >/dev/null 2>&1 \
           && tmux new-session -d -s "sysmenu_$$_$(date +%s%N)" "${tenv[@]}" "$script" 2>/dev/null; }; then
        bash "$script" >/dev/null 2>&1 &
    fi
    disown 2>/dev/null
}

human()      { du -sh "$1" 2>/dev/null | cut -f1; }

rec_label() {
    if [ "$("$RECORD" status 2>/dev/null)" = "recording" ]; then
        echo "⏹  Detener grabación de pantalla"
    else
        echo "⏺  Iniciar grabación de pantalla"
    fi
}

# ------------------------------------------------------------------ menú ----
orphan_count="$(pacman -Qtdq 2>/dev/null | wc -l)"
pacache="$(human /var/cache/pacman/pkg)"
[ -z "$pacache" ] && pacache="?"

options=(
    "󰚰  Actualizar sistema"
    "󰃢  Limpieza profunda de pacman ($pacache)"
    "󰃢  Limpiar caché de usuario (~/.cache)"
    "󰅺  Limpiar journal de systemd"
    "󰅺  Eliminar paquetes huérfanos ($orphan_count)"
    "󰖟  Actualizar mirrors (reflector)"
    "󰑓  Reiniciar Polybar"
    "󰜉  Recargar WM (bspwm)"
    "$(rec_label)"
)

selected="$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -theme "$RASI" -selected-row 0)"

[ -z "$selected" ] && exit 0

# -------------------------------------------------------------- acciones ----
case "$selected" in

    # ---- requieren sudo: terminal urxvt visible ----
    *"Actualizar sistema"*)
        run_term "Actualizar sistema" 'yay -Syu'
        ;;

    *"Limpieza profunda de pacman"*)
        run_term "Limpieza profunda de pacman" \
            'echo "Antes: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"; \
             sudo paccache -rk1; sudo paccache -ruk0; \
             sudo rm -f /var/cache/pacman/pkg/*.part; \
             sudo rm -rf /var/cache/pacman/pkg/download-*; \
             rm -rf "$HOME/.cache/yay"; \
             echo; echo "Después: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"'
        ;;

    *"Limpiar journal"*)
        run_term "Journal de systemd" 'sudo journalctl --vacuum-size=100M'
        ;;

    *"Eliminar paquetes huérfanos"*)
        run_term "Paquetes huérfanos" \
            'o=$(pacman -Qtdq); \
             if [ -z "$o" ]; then echo "No hay paquetes huérfanos."; exit 0; fi; \
             echo "Huérfanos encontrados:"; echo "$o"; echo; \
             sudo pacman -Rns $o'
        ;;

    *"Actualizar mirrors"*)
        run_term "Mirrors (reflector)" \
            'sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak 2>/dev/null; \
             sudo reflector --latest 30 --sort rate --protocol https \
                 --save /etc/pacman.d/mirrorlist'
        ;;

    # ---- sin sudo: por detrás en tmux ----
    *"Limpiar caché de usuario"*)
        CACHE="$HOME/.cache"
        safe=(thumbnails fontconfig pip npm uv go-build copilot JetBrains zen
              BraveSoftware mozilla mpv nvim SpotiFLAC systemsettings kioexec
              kpackage-knshandler kdedefaults matplotlib google-chrome)
        targets=""
        for d in "${safe[@]}"; do
            [ -e "$CACHE/$d" ] && targets="$targets $CACHE/$d"
        done
        if [ -z "$targets" ]; then
            notify-send "Caché de usuario" "Nada que limpiar" 2>/dev/null
        else
            bg "Caché de usuario" \
                "echo \"Antes: \$(du -sh $CACHE | cut -f1)\"; \
                 rm -rf $targets; \
                 echo \"Después: \$(du -sh $CACHE | cut -f1)\""
        fi
        ;;

    *"Reiniciar Polybar"*)
        bg "Reiniciar Polybar" 'timeout 8 "$HOME/.config/polybar/launch.sh" || true; sleep 1'
        ;;

    *"Recargar WM"*)
        # solo reinicia el WM (bspwm wm -r); no toca sxhkd/picom/polybar/dunst
        bg "Recargar WM (bspwm)" \
            'bspc wm -r; sleep 1'
        ;;

    # ---- grabación: submenu con/sin micro ----
    *"grabación de pantalla"*)
        if [ "$("$RECORD" status 2>/dev/null)" = "recording" ]; then
            "$RECORD" stop
        else
            rec_opts=(
                "🎙️  Con micro (sistema+micro)"
                "🔈  Sin micro (solo sistema)"
                "🎤  Solo micro"
                "🔇  Sin audio"
            )
            rec_choice="$(printf '%s\n' "${rec_opts[@]}" | rofi -dmenu -i -theme "$RASI" -p "Grabar")"
            [ -z "$rec_choice" ] && exit 0
            case "$rec_choice" in
                *"Con micro"*) "$RECORD" start full ;;
                *"Sin micro"*) "$RECORD" start sistema ;;
                *"Solo micro"*) "$RECORD" start micro ;;
                *"Sin audio"*) "$RECORD" start silencio ;;
            esac
        fi
        ;;

    *)
        exit 0
        ;;
esac
