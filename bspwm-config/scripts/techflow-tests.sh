#!/bin/bash
# Tech-Flow — runner de tests con salida bonita (gum)
# Uso:
#   techflow-tests.sh            corre todos los tests
#   techflow-tests.sh -l         elige una clase con gum choose
#   techflow-tests.sh -c Clase   corre solo esa clase
#   techflow-tests.sh -r         al terminar genera el informe PDF en ~/Descargas
set -u

PROJ="$HOME/Documentos/Tech-Flow"
CACHE="$HOME/.cache/techflow"
mkdir -p "$CACHE"

GREEN=$'\033[38;2;166;227;161m'
RED=$'\033[38;2;243;139;168m'
BLUE=$'\033[38;2;137;180;250m'
MUTED=$'\033[38;2;108;112;134m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

CLASS=""
PICK=0
REPORT=0

while [ $# -gt 0 ]; do
    case "$1" in
        -l|--list) PICK=1 ;;
        -r|--report) REPORT=1 ;;
        -c|--class) shift; CLASS="${1:-}" ;;
        -h|--help)
            sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) CLASS="$1" ;;
    esac
    shift
done

use_gum() { [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v gum >/dev/null 2>&1; }

# Deja la ventana de st abierta para poder leer los resultados
pausar() {
    if [ -t 0 ] && [ -z "${NO_PAUSE:-}" ]; then
        printf '\n'
        read -rp "  Enter para cerrar… " _
    fi
}

list_classes() {
    find "$PROJ/src/test/java" -name '*Test.java' -type f 2>/dev/null \
        | sed 's|.*/src/test/java/||; s|\.java$||; s|/|.|g' \
        | sort
}

[ -d "$PROJ" ] || { printf '%s✘ No existe %s%s\n' "$RED" "$PROJ" "$RESET"; exit 1; }

if [ "$PICK" -eq 1 ]; then
    mapfile -t classes < <(list_classes)
    [ ${#classes[@]} -eq 0 ] && { printf '%s✘ No se encontraron tests en src/test/java%s\n' "$RED" "$RESET"; exit 1; }

    if use_gum; then
        choice="$(printf '%s\n' "★ Todos (${#classes[@]} clases)" "${classes[@]}" \
            | gum choose --height 16 --header "Tech-Flow · ¿qué tests corro?" --cursor "❯ ")" || choice=""
    else
        choice="$(printf '%s\n' "★ Todos (${#classes[@]} clases)" "${classes[@]}" \
            | fzf --height 16 --prompt "Tests> " --reverse)" || choice=""
    fi
    [ -z "${choice:-}" ] && exit 0
    case "$choice" in
        "★ Todos"*) CLASS="" ;;
        *) CLASS="$choice" ;;
    esac
fi

cd "$PROJ" || exit 1

BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '???????')"
LOG="$CACHE/tests-$(date +%F_%H%M%S).log"
ROWS="$CACHE/rows.csv"

if use_gum; then
    gum style --border double --border-foreground "#89b4fa" --padding "0 2" --bold \
        "Tech-Flow · Tests"
    printf '%s  rama %s · %s · %s%s\n\n' "$MUTED" "$BR" "$SHA" \
        "${CLASS:-todas las clases}" "$RESET"
else
    printf '%s═══ Tech-Flow · Tests ═══%s\n' "$BOLD" "$RESET"
    printf '%s  rama %s · %s · %s%s\n\n' "$MUTED" "$BR" "$SHA" \
        "${CLASS:-todas las clases}" "$RESET"
fi

# Reportes viejos fuera: si no, una corrida por clase mostraría resultados anteriores
rm -rf target/surefire-reports

export PROJ LOG CLASS

if use_gum; then
    gum spin --spinner dot --title "Ejecutando mvn test…" -- sh -c '
        if [ -n "$CLASS" ]; then
            mvn -B -ntp test -Dtest="$CLASS" > "$LOG" 2>&1
        else
            mvn -B -ntp test > "$LOG" 2>&1
        fi'
else
    printf '%s▶ mvn test %s%s\n' "$BLUE" "${CLASS:+(-Dtest=$CLASS)}" "$RESET"
    if [ -n "$CLASS" ]; then
        mvn -B -ntp test -Dtest="$CLASS" > "$LOG" 2>&1
    else
        mvn -B -ntp test > "$LOG" 2>&1
    fi
fi
MVN=$?

TOTAL=""
FAILS=0
SKIPS=0
ELAPSED="0.00"
CLASSES=0

read -r TOTAL FAILS SKIPS ELAPSED CLASSES < <(python3 - "$ROWS" <<'PY'
import glob
import os
import sys
import xml.etree.ElementTree as ET

proj = os.environ["PROJ"]
flt = os.environ.get("CLASS", "").strip()
rows, details = [], []
total = fails = skips = 0
ttime = 0.0

for p in sorted(glob.glob(os.path.join(proj, "target/surefire-reports/TEST-*.xml"))):
    try:
        root = ET.parse(p).getroot()
    except Exception:
        continue
    name = root.get("name") or os.path.basename(p)[5:-4]
    if flt and not (name == flt or name.endswith("." + flt)):
        continue
    t = int(root.get("tests") or 0)
    f = int(root.get("failures") or 0)
    e = int(root.get("errors") or 0)
    s = int(root.get("skipped") or 0)
    tm = float(root.get("time") or 0)
    bad = f + e
    rows.append((name, t, t - bad - s, bad, s, tm))
    total += t
    fails += bad
    skips += s
    ttime += tm
    for tc in root.iter("testcase"):
        for tag in ("failure", "error"):
            el = tc.find(tag)
            if el is None:
                continue
            msg = (el.get("message") or (el.text or "").strip() or "")
            msg = " ".join(msg.split())
            details.append((name, tc.get("name") or "?", msg[:160]))

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("Clase,Tests,OK,Fallos,Skip,Tiempo\n")
    for name, t, ok, bad, s, tm in rows:
        mark = "✘" if bad else "✔"
        fh.write(f"{mark} {name},{t},{ok},{bad},{s},{tm:.2f}s\n")

with open(sys.argv[1] + ".details", "w", encoding="utf-8") as fh:
    for name, tc, msg in details:
        fh.write(f"{name} › {tc}\t{msg}\n")

print(f"{total} {fails} {skips} {ttime:.2f} {len(rows)}")
PY
)

if [ -z "$TOTAL" ] || [ "$TOTAL" = "0" ]; then
    printf '\n%s✘ mvn test no dejó reportes (¿error de compilación?)%s\n\n' "$RED" "$RESET"
    tail -n 25 "$LOG"
    printf '\n%s  log completo: %s%s\n' "$MUTED" "$LOG" "$RESET"
    pausar
    exit 1
fi

if use_gum; then
    gum table --print -b rounded -s , -f "$ROWS" 2>/dev/null || column -t -s , "$ROWS"
else
    column -t -s , "$ROWS"
fi

if [ "$FAILS" -gt 0 ] && [ -s "$ROWS.details" ]; then
    printf '\n'
    while IFS=$'\t' read -r where msg; do
        printf '  %s✘ %s%s\n' "$RED" "$where" "$RESET"
        [ -n "$msg" ] && printf '    %s%s%s\n' "$MUTED" "$msg" "$RESET"
    done < "$ROWS.details"
fi

printf '\n'
if [ "$FAILS" -eq 0 ]; then
    LINE="✔ $TOTAL tests · $CLASSES clase(s) · ${ELAPSED}s"
    if use_gum; then
        gum style --border rounded --border-foreground "#a6e3a1" --padding "0 2" \
            --foreground "#a6e3a1" "$LINE"
    else
        printf '%s%s%s\n' "$GREEN" "$LINE" "$RESET"
    fi
else
    LINE="✘ $FAILS fallo(s) de $TOTAL tests · ${ELAPSED}s"
    if use_gum; then
        gum style --border rounded --border-foreground "#f38ba8" --padding "0 2" \
            --foreground "#f38ba8" "$LINE"
    else
        printf '%s%s%s\n' "$RED" "$LINE" "$RESET"
    fi
fi

printf '%s  log: %s%s\n' "$MUTED" "$LOG" "$RESET"

if [ "$REPORT" -eq 1 ]; then
    printf '\n'
    "$HOME/.config/scripts/techflow-tests-report.sh" || true
fi

pausar

[ "$MVN" -eq 0 ] && [ "$FAILS" -eq 0 ] && exit 0
exit 1
