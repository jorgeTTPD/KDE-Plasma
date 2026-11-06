#!/usr/bin/env python3
"""Traduce la letra cacheada al idioma destino (defecto: es).
Uso: lyrics-translate.py <cachedir> <key> [tl]
Lee <key>.tsv o <key>.plain, escribe <key>.<tl>.tsv / .<tl>.plain.
Cadena: Google gtx (batch) -> MyMemory (linea a linea).
Cache por linea en ~/.cache/lyrics/trans-cache/<tl>.json para no repetir
requests y acumular progreso entre intentos.
Si no se logra traducir todo, NO escribe el fichero destino (exit 1) para
que el siguiente refresh de rofi reintente sin dejar basura cacheada.
Omite secciones [Verse], lineas vacias y simbolos (se copian tal cual).
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# venv con Argos offline (si existe): motor prioritario, sin red ni cuotas.
_VENV_PKGS = os.path.expanduser(
    "~/.local/share/lyrics-trans/venv/lib/python3.14/site-packages"
)
if os.path.isdir(_VENV_PKGS) and _VENV_PKGS not in sys.path:
    sys.path.insert(0, _VENV_PKGS)

SECTION_RE = re.compile(r"^\[.+\]$")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) lyrics-rofi-trans/1.0"}


def cache_path(tl):
    base = os.path.expanduser("~/.cache/lyrics/trans-cache")
    os.makedirs(base, exist_ok=True)
    return os.path.join(base, f"{tl}.json")


def load_line_cache(tl):
    try:
        with open(cache_path(tl), encoding="utf-8") as fh:
            d = json.load(fh)
            return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def save_line_cache(tl, d):
    try:
        tmp = cache_path(tl) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(d, fh, ensure_ascii=False)
        os.replace(tmp, cache_path(tl))
    except OSError:
        pass


def sleep_backoff(e, attempt):
    wait = 5 * (attempt + 1)
    try:
        ra = e.headers.get("Retry-After")
        if ra and str(ra).strip().isdigit():
            wait = max(wait, int(ra))
    except Exception:
        pass
    time.sleep(wait)


def gtx_translate(texts, tl="es", sl="auto"):
    if not texts:
        return []
    qs = "&".join("q=" + urllib.parse.quote(t, safe="") for t in texts)
    url = (
        "https://translate.googleapis.com/translate_a/single"
        f"?client=gtx&sl={sl}&tl={tl}&dt=t&{qs}"
    )
    last = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.load(resp)
            out = []
            for block in data[0]:
                out.append(block[0] or "")
            if len(out) < len(texts):
                out += [""] * (len(texts) - len(out))
            return out[: len(texts)]
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 500, 502, 503):
                sleep_backoff(e, attempt)
                continue
            raise
    raise last or RuntimeError("gtx-failed")


def mymemory_translate(text, tl="es"):
    q = urllib.parse.quote(text, safe="")
    url = f"https://api.mymemory.translated.net/get?q={q}&langpair=en|{tl}"
    last = None
    for attempt in range(2):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.load(resp)
            t = (data.get("responseData", {}) or {}).get("translatedText", "")
            if not t or "QUERY LENGTH LIMIT" in t.upper():
                raise RuntimeError("mymemory-limit:" + t[:60])
            if t.strip().lower() == text.strip().lower() and len(text) > 12:
                raise RuntimeError("mymemory-echo")
            return t
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 500, 502, 503):
                sleep_backoff(e, attempt)
                continue
            raise
        except RuntimeError:
            raise
    raise last or RuntimeError("mymemory-failed")


_ARGOS = None


def argos_translate_list(texts, tl="es"):
    """Motor offline (venv). Lanza RuntimeError si no hay modelo."""
    global _ARGOS
    if _ARGOS is None:
        from argostranslate import translate as at

        langs = at.get_installed_languages()
        src = next((l for l in langs if l.code == "en"), None)
        dst = next((l for l in langs if l.code == tl), None)
        if not src or not dst:
            raise RuntimeError("argos-model-missing")
        _ARGOS = src.get_translation(dst)
    return [_ARGOS.translate(t) for t in texts]


def translate_missing(texts, tl, line_cache):
    """Traduce solo los no cacheados. Devuelve dict texto->traduccion."""
    uniq = []
    for t in texts:
        if t not in line_cache and t not in uniq:
            uniq.append(t)
    # 1) Argos offline: gratis, sin cuota. Si falla, se sigue online.
    rest = list(uniq)
    if rest:
        try:
            for src, dst in zip(rest, argos_translate_list(rest, tl)):
                if dst:
                    line_cache[src] = dst
            rest = [t for t in rest if t not in line_cache]
            save_line_cache(tl, line_cache)
        except Exception as e:
            print(f"argos-skip: {e}", file=sys.stderr)
    # 2) Online: gtx en batch, fallback MyMemory linea a linea.
    for s in range(0, len(rest), 5):
        chunk = rest[s : s + 5]
        try:
            tr = gtx_translate(chunk, tl)
            for src, dst in zip(chunk, tr):
                if dst:
                    line_cache[src] = dst
                time.sleep(0.1)
        except Exception:
            for src in chunk:
                try:
                    dst = mymemory_translate(src, tl)
                    line_cache[src] = dst
                except Exception:
                    pass
                time.sleep(1.0)
        time.sleep(0.5)
    save_line_cache(tl, line_cache)
    return {t: line_cache[t] for t in texts if t in line_cache}


def needs_translation(line):
    s = line.strip()
    if not s:
        return False
    if SECTION_RE.match(s):
        return False
    if re.fullmatch(r"[♪♫·\W_]+", s):
        return False
    return True


def main():
    if len(sys.argv) < 3:
        print("uso: lyrics-translate.py <cachedir> <key> [tl]", file=sys.stderr)
        sys.exit(2)
    cdir, key = sys.argv[1], sys.argv[2]
    tl = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("LYRICS_TL", "es")
    src_tsv = os.path.join(cdir, f"{key}.tsv")
    src_plain = os.path.join(cdir, f"{key}.plain")
    dst_tsv = os.path.join(cdir, f"{key}.{tl}.tsv")
    dst_plain = os.path.join(cdir, f"{key}.{tl}.plain")
    if os.path.isfile(dst_tsv) or os.path.isfile(dst_plain):
        print("cached")
        return
    line_cache = load_line_cache(tl)
    if os.path.isfile(src_tsv):
        rows = []
        with open(src_tsv, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                ln = ln.rstrip("\n")
                if not ln:
                    continue
                if "\t" in ln:
                    t, body = ln.split("\t", 1)
                else:
                    t, body = "0.00", ln
                try:
                    float(t)
                except ValueError:
                    continue
                rows.append((t, body))
        if not rows:
            print("empty")
            return
        wanted = [b for _, b in rows if needs_translation(b)]
        got = translate_missing(wanted, tl, line_cache)
        missing = [w for w in wanted if w not in got]
        if missing:
            print(f"pending:{len(missing)}/{len(wanted)}")
            sys.exit(1)
        with open(dst_tsv, "w", encoding="utf-8") as fh:
            for t, body in rows:
                fh.write(f"{t}\t{got.get(body, body)}\n")
        print(f"translated:{len(wanted)}")
    elif os.path.isfile(src_plain):
        with open(src_plain, encoding="utf-8", errors="replace") as fh:
            lines = [ln.rstrip("\n") for ln in fh]
        wanted = [b for b in lines if needs_translation(b)]
        got = translate_missing(wanted, tl, line_cache)
        missing = [w for w in wanted if w not in got]
        if missing:
            print(f"pending:{len(missing)}/{len(wanted)}")
            sys.exit(1)
        with open(dst_plain, "w", encoding="utf-8") as fh:
            for body in lines:
                fh.write(f"{got.get(body, body)}\n")
        print(f"translated:{len(wanted)}")
    else:
        print("no-source")
        sys.exit(1)


main()
