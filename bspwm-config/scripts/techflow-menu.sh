#!/bin/bash
# Menú del proyecto Tech-Flow (Super+Q) — run / tests / build / nvim / git
set -u

# Kill any existing rofi to prevent "Rofi already running" issues
pkill -9 -x rofi 2>/dev/null || true
sleep 0.5

PROJ="$HOME/Documentos/Tech-Flow"
RASI="$HOME/.config/rofi/sysmenu.rasi"
LOGDIR="$HOME/.cache/techflow"
LOG="$LOGDIR/last.log"
mkdir -p "$LOGDIR"

# Opciones del menú
options=(
    "▶  Ejecutar app"
    "🧪  Tests (mvn test)"
    "📦  Build (mvn clean package)"
    "⚡  Compilar (mvn compile)"
    "📝  Abrir en nvim"
    "📂  Abrir carpeta"
    "🧹  Limpiar (mvn clean)"
    "🌟  Fresh (st)"
    "🌿  Commit git"
    "☁️  Subir a GitHub"
    "⬇️  Actualizar main"
)

selected="$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -theme "$RASI" -selected-row 0 \
    -theme-str 'mainbox {children: ["listview"];}' \
    -theme-str 'listview {lines: 11;}')"

[ -z "$selected" ] && exit 0

# Acciones por selección
case "$selected" in
    *"Ejecutar app"*)
        exec st -t "Tech-Flow" -e bash -c "cd \"$PROJ\" && java -cp target/classes Main"
        ;;

    *"Tests"*)
        exec st -t "Tech-Flow — Tests" -e "$HOME/.config/scripts/techflow-tests.sh"
        ;;

    *"Build"*)
        exec st -t "Tech-Flow — Build" -e bash -c "cd \"$PROJ\" && mvn clean package 2>&1 | tee \"$LOG\" | grep -E '(BUILD|ERROR)' || true; echo '---'; tail -6 \"$LOG\"; read -r _"
        ;;

    *"Compilar"*)
        exec st -t "Tech-Flow — Compilar" -e bash -c "cd \"$PROJ\" && mvn -q compile 2>&1 | tee \"$LOG\"; echo '---'; tail -3 \"$LOG\"; read -r _"
        ;;

    *"Abrir en nvim"*)
        exec st -t "Tech-Flow — nvim" -e bash -c "cd \"$PROJ\" && exec nvim ."
        ;;

    *"Abrir carpeta"*)
        xdg-open "$PROJ" &
        ;;

    *"Limpiar"*)
        exec st -t "Tech-Flow — Limpiar" -e bash -c "cd \"$PROJ\" && mvn -q clean"
        ;;
    *"Fresh (st)"*)
        setsid st -t "Tech-Flow — Fresh" -e bash -c "cd \"$PROJ\" && fresh"
        ;;

    *"Commit git"*)
        msg="$(rofi -dmenu -theme "$RASI" -p "Commit" \
            -theme-str 'mainbox {children: ["inputbar"];}' \
            -theme-str 'entry {placeholder: "Mensaje del commit";}')"
        [ -z "$msg" ] && exit 0
        export PROJ MSG="$msg"
        exec st -t "Tech-Flow — Commit" -e bash -c 'cd "$PROJ" && git add -A && git commit -m "$MSG"; echo; git log --oneline -3; echo; read -r _'
        ;;

    *"Subir a GitHub"*)
        export PROJ
        exec st -t "Tech-Flow — Push" -e bash -c 'cd "$PROJ" && git push -u origin HEAD; echo; git status -sb | head -3; echo; read -r _'
        ;;

    *"Actualizar main"*)
        export PROJ
        exec st -t "Tech-Flow — Pull main" -e bash -c 'cd "$PROJ" || exit 1; git fetch origin --prune; br="$(git rev-parse --abbrev-ref HEAD)"; if [ "$br" = "main" ]; then git pull --ff-only origin main; else echo "Estás en la rama $br, no en main: no se ha tocado nada."; echo "Pendiente en origin/main:"; git log --oneline HEAD..origin/main | head -5; fi; echo; read -r _'
        ;;

    *)
        exit 0
        ;;
esac