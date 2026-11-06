#!/bin/bash
# Genera el informe LaTeX de los tests de Tech-Flow a partir de surefire.
# Uso:
#   techflow-tests-report.sh               genera .tex + .pdf en ~/Descargas
#   techflow-tests-report.sh --tex-only    solo el .tex
#   techflow-tests-report.sh --open        abre el PDF al terminar
set -u

PROJ="$HOME/Documentos/Tech-Flow"
OUTDIR="$HOME/Descargas"
BASE="informe-tests-techflow"
TEX_ONLY=0
OPEN_PDF=0

while [ $# -gt 0 ]; do
    case "$1" in
        --out) shift; OUTDIR="${1:-$OUTDIR}" ;;
        --tex-only) TEX_ONLY=1 ;;
        --open) OPEN_PDF=1 ;;
        -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; exit 2 ;;
    esac
    shift
done

[ -d "$PROJ" ] || { echo "No existe $PROJ" >&2; exit 1; }
[ -d "$OUTDIR" ] || { echo "No existe el directorio $OUTDIR" >&2; exit 1; }

mkdir -p "$OUTDIR"
TEX="$OUTDIR/$BASE.tex"
PDF="$OUTDIR/$BASE.pdf"

cd "$PROJ" || exit 1

BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '???????')"
FECHA="$(date +%d/%m/%Y)"

python3 - "$TEX" "$PROJ" "$BR" "$SHA" "$FECHA" <<'PY'
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

tex_path, proj, branch, sha, fecha = sys.argv[1:6]


def esc(s):
    if s is None:
        s = ""
    s = s.replace("\\", r"\textbackslash{}")
    for a, b in (("&", r"\&"), ("%", r"\%"), ("$", r"\$"), ("#", r"\#"),
                 ("_", r"\_"), ("{", r"\{"), ("}", r"\}"),
                 ("~", r"\textasciitilde{}"), ("^", r"\textasciicircum{}")):
        s = s.replace(a, b)
    return s


def collapse(s, limit):
    s = " ".join((s or "").split())
    if len(s) > limit:
        s = s[:limit].rstrip() + "..."
    return s


def display_name(cls, test):
    src = os.path.join(proj, "src/test/java", cls.replace(".", "/") + ".java")
    try:
        with open(src, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return "", ""
    for i, line in enumerate(lines):
        if f"void {test}(" in line:
            name = ""
            for j in range(max(0, i - 6), i):
                if "@DisplayName" in lines[j]:
                    frag = lines[j].split("(", 1)[-1].rsplit(")", 1)[0].strip()
                    name = frag.strip('"')
            return name, f"{os.path.basename(src)}:{i + 1}"
    return "", ""


rows, failures = [], []
total = bad_total = 0
ttime = 0.0

for p in sorted(glob.glob(os.path.join(proj, "target/surefire-reports/TEST-*.xml"))):
    try:
        root = ET.parse(p).getroot()
    except Exception:
        continue
    cls = root.get("name") or os.path.basename(p)[5:-4]
    t = int(root.get("tests") or 0)
    f = int(root.get("failures") or 0)
    e = int(root.get("errors") or 0)
    s = int(root.get("skipped") or 0)
    tm = float(root.get("time") or 0)
    total += t
    bad_total += f + e
    ttime += tm

    for tc in root.iter("testcase"):
        for tag in ("failure", "error"):
            el = tc.find(tag)
            if el is None:
                continue
            name = tc.get("name") or "?"
            msg = (el.get("message") or (el.text or "").strip() or "")
            lines = [ln.strip() for ln in msg.splitlines() if ln.strip()]
            first = lines[0] if lines else ""

            esperado = ""
            if first.startswith("La salida no contiene:"):
                esperado = first.split(":", 1)[1].strip()

            datos_cliente = bool(re.search(r"\bci\b", esperado, re.I)) or \
                "telefono" in esperado.lower()

            display, loc = display_name(cls, name)
            descripcion = display or name

            if datos_cliente:
                cuerpo = (
                    "La prueba comprueba que el dato se rechace con el mensaje "
                    "«" + esperado + "». Falla porque en la terminal el menú "
                    "del cajero cambió de numeración —la opción 2 es ahora "
                    "«Importar orden CSV/TXT»— y la secuencia de teclas ya no "
                    "llega a la validación; en la GUI no existen campos de CI "
                    "ni de teléfono, así que el criterio nunca se evalúa.")
            elif "FACTURA" in esperado.upper():
                cuerpo = (
                    "La prueba comprueba que al confirmar la venta se emita la "
                    "factura («" + esperado + "») y que el stock baje en una "
                    "unidad. Falla porque en la terminal la secuencia de teclas "
                    "no llega a confirmar la venta; en la GUI el stock se "
                    "descuenta bien, pero la factura solo se imprime en consola "
                    "y no se guarda en ningún archivo.")
            else:
                cuerpo = collapse(first, 240) or "La prueba no pasó."

            failures.append({
                "cls": cls, "test": name, "display": display, "loc": loc,
                "cuerpo": cuerpo,
            })

failures.sort(key=lambda x: (x["cls"], x["test"]))

out = []
w = out.append
w(r"\documentclass[11pt,a4paper]{article}")
w(r"\usepackage[utf8]{inputenc}")
w(r"\usepackage[T1]{fontenc}")
w(r"\usepackage[spanish]{babel}")
w(r"\usepackage[margin=1.7cm,top=1.4cm,bottom=1.4cm]{geometry}")
w(r"\usepackage{xcolor}")
w(r"\usepackage{enumitem}")
w(r"\usepackage{parskip}")
w(r"\usepackage[hidelinks]{hyperref}")
w(r"\definecolor{tfblue}{HTML}{1F3A93}")
w(r"\definecolor{tfgray}{HTML}{5F6368}")
w(r"\definecolor{tfred}{HTML}{B00020}")
w(r"\pagestyle{empty}")
w(r"\begin{document}")
w("")
w(r"\begin{minipage}[b]{0.5\textwidth}")
w(r"  {\Large\bfseries\underline{TECH-FLOW}}")
w(r"\end{minipage}%")
w(r"\begin{minipage}[b]{0.5\textwidth}")
w(r"  \raggedleft{\Large\bfseries TESTING}")
w(r"\end{minipage}")
w("")
w(r"\vspace{2pt}")
w(r"{\color{tfblue}\hrule height 1.2pt}")
w(r"\vspace{5pt}")
w(r"{\small\color{tfgray} Informe de pruebas \textbullet{} " + esc(fecha) +
  r" \textbullet{} rama \texttt{" + esc(branch) + r"} \textbullet{} " +
  r"\texttt{" + esc(sha) + r"}}")
w("")
n_cls = len(glob.glob(os.path.join(proj, "target/surefire-reports/TEST-*.xml")))
resumen = (r"{\large\bfseries " + str(total) + r" pruebas \textbullet{} " +
           str(n_cls) + r" clases \textbullet{} " +
           (r"\textcolor{tfred}{" + str(bad_total) + r" fallos}}" if bad_total
            else r"\textcolor{tfblue}{sin fallos}}"))
w(resumen)
w("")

if not failures:
    w(r"\vspace{4pt}")
    w(r"{\color{tfblue}\bfseries Todas las pruebas pasaron.}")
else:
    w(r"\vspace{6pt}")
    w(r"{\bfseries\color{tfblue} FALLOS}\par")
    w(r"\vspace{2pt}")
    for idx, f in enumerate(failures, 1):
        w(r"\vspace{5pt}")
        w(r"{\bfseries " + str(idx) + r".} \texttt{" + esc(f["cls"]) +
          r"} \textbullet{} \texttt{" + esc(f["test"]) + r"}" +
          (r"\hfill{\small\color{tfgray}\texttt{" + esc(f["loc"]) + r"}}\par"
           if f["loc"] else r"\par"))
        w(r"{\small " + esc(f["cuerpo"]) + r"}\par")

w("")
w(r"\end{document}")

with open(tex_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out) + "\n")
PY

echo "→ $TEX"

if [ "$TEX_ONLY" -eq 1 ]; then
    exit 0
fi

command -v latexmk >/dev/null 2>&1 || { echo "Falta latexmk (TinyTeX)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$TEX" "$TMP/$BASE.tex"
if ! (cd "$TMP" && latexmk -pdf -interaction=nonstopmode -halt-on-error "$BASE.tex" >compile.log 2>&1); then
    echo "✘ La compilación LaTeX falló:" >&2
    tail -n 20 "$TMP/compile.log" >&2
    exit 1
fi
cp "$TMP/$BASE.pdf" "$PDF"
echo "→ $PDF"

[ "$OPEN_PDF" -eq 1 ] && xdg-open "$PDF" >/dev/null 2>&1 &
exit 0
