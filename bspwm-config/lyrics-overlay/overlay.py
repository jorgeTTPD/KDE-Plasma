#!/usr/bin/env python3
import json
import re
import signal
import subprocess
import threading
import urllib.parse
import urllib.request

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib  # noqa: E402

BG = "rgba(0, 0, 0, 0.80)"
ACCENT = "#89b4fa"
FG = "#cdd6f4"
DIM = "#9399b2"
FONT = "JetBrainsMono Nerd Font"
WIN_W = 760
BOTTOM_MARGIN = 60
METADATA_EVERY = 8

CSS = f"""
window {{
    background-color: {BG};
    border-radius: 10px;
    border: 1px solid rgba(58, 58, 58, 0.85);
}}
box {{ padding: 14px 24px; }}
.prev, .next {{ color: {DIM}; font-family: "{FONT}"; font-size: 12px; }}
.current {{ color: {FG}; font-family: "{FONT}"; font-size: 16px; font-weight: bold; }}
"""

TAG_RE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
WORD_TAG_RE = re.compile(r"<(\d+):(\d+(?:\.\d+)?)>")
HEADERS = {"User-Agent": "lyrics-overlay/1.0 (bspwm; +https://lrclib.net)"}


def run(cmd):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=4
        ).stdout.strip()
    except Exception:
        return ""


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def parse_lrc(text):
    lines = []
    for raw in text.splitlines():
        m = TAG_RE.match(raw)
        if not m:
            continue
        start = int(m.group(1)) * 60 + float(m.group(2))
        body = raw[m.end() :]
        matches = list(WORD_TAG_RE.finditer(body))
        if matches:
            words = []
            for i, wm in enumerate(matches):
                seg_start = int(wm.group(1)) * 60 + float(wm.group(2))
                end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
                seg = body[wm.end() : end]
                if seg:
                    words.append((seg_start, seg))
            lines.append((start, "".join(w[1] for w in words).strip(), words))
        else:
            lines.append((start, body.strip(), None))
    lines.sort(key=lambda x: x[0])
    return lines


def http_json(url):
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=8) as resp:
        return json.load(resp)


def fetch_lyrics(title, artist, album, duration):
    params = urllib.parse.urlencode(
        {
            "track_name": title,
            "artist_name": artist,
            "album_name": album,
        }
    )
    urls = []
    if duration:
        urls.append(f"https://lrclib.net/api/get?{params}&duration={duration}")
    urls.append(f"https://lrclib.net/api/search?{params}")
    urls.append("https://lrclib.net/api/search?q=" + urllib.parse.quote(title))
    for url in urls:
        try:
            data = http_json(url)
        except Exception:
            continue
        results = data if isinstance(data, list) else [data]
        for res in results:
            synced = res.get("syncedLyrics") if isinstance(res, dict) else None
            if synced:
                lines = parse_lrc(synced)
                if lines:
                    return lines
    return None


def active_player():
    best = ""
    prio = -1
    for player in run(["playerctl", "-l"]).splitlines():
        status = run(["playerctl", "-p", player, "status"])
        if status == "Playing":
            p = 3
        elif status == "Paused":
            p = 2
        elif run(["playerctl", "-p", player, "metadata", "title"]):
            p = 1
        else:
            p = 0
        if p > prio:
            prio = p
            best = player
    return best


class Overlay(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        self.set_type_hint(Gdk.WindowTypeHint.NOTIFICATION)
        self.set_wmclass("lyrics-overlay", "lyrics-overlay")
        self.set_role("lyrics-overlay")
        self.set_title("lyrics-overlay")
        self.connect("delete-event", lambda *_: Gtk.main_quit())

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.set_visual(visual)
        self.set_app_paintable(True)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_size_request(WIN_W, -1)
        self.prev = Gtk.Label()
        self.cur = Gtk.Label()
        self.nxt = Gtk.Label()
        for widget, cls in (
            (self.prev, "prev"),
            (self.cur, "current"),
            (self.nxt, "next"),
        ):
            widget.get_style_context().add_class(cls)
            widget.set_justify(Gtk.Justification.CENTER)
            widget.set_line_wrap(True)
            widget.set_max_width_chars(64)
            box.pack_start(widget, False, False, 0)
        self.add(box)

        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.connect("button-press-event", self.on_press)

        self.player = ""
        self.lines = None
        self.cache = {}
        self.loading = False
        self.prev_title = None
        self.message = ""
        self.fetch_id = 0
        self.tick_count = 0
        self.user_moved = False
        self.last_size = (0, 0)

        self.connect("size-allocate", self.on_allocate)
        GLib.timeout_add(120, self.tick)
        self.show_all()

    def on_press(self, _widget, event):
        if event.button == 1:
            self.user_moved = True
            self.begin_move_drag(
                event.button, int(event.x_root), int(event.y_root), event.time
            )
            return True
        return False

    def set_lines(self, prev, cur, nxt):
        self.prev.set_text(prev)
        self.cur.set_text(cur)
        self.nxt.set_text(nxt)

    def _load(self, fetch_id, key, title, artist, album, duration):
        lines = fetch_lyrics(title, artist, album, duration)
        GLib.idle_add(self._loaded, fetch_id, key, lines)

    def _loaded(self, fetch_id, key, lines):
        if lines:
            self.cache[key] = lines
        if fetch_id == self.fetch_id:
            self.lines = lines
            self.loading = False
        return False

    def on_allocate(self, _widget, alloc):
        if self.user_moved or (alloc.width, alloc.height) == self.last_size:
            return False
        self.last_size = (alloc.width, alloc.height)
        screen = self.get_screen()
        x = (screen.get_width() - alloc.width) // 2
        y = screen.get_height() - alloc.height - BOTTOM_MARGIN
        self.move(max(0, x), max(0, y))
        return False

    def refresh_track(self):
        player = active_player()
        self.player = player
        if not player:
            self.prev_title = None
            self.lines = None
            self.loading = False
            self.message = "♪  Nada reproduciendo"
            return
        title = run(["playerctl", "-p", player, "metadata", "title"])
        if not title:
            self.prev_title = None
            self.lines = None
            self.loading = False
            self.message = "♪  Nada reproduciendo"
            return
        if title == self.prev_title:
            return
        artist = run(["playerctl", "-p", player, "metadata", "artist"])
        album = run(["playerctl", "-p", player, "metadata", "album"])
        self.prev_title = title
        self.message = ""
        key = (title, artist, album)
        if key in self.cache:
            self.lines = self.cache[key]
        else:
            self.lines = None
            self.loading = True
            length = run(["playerctl", "-p", player, "metadata", "mpris:length"])
            duration = int(int(length) // 1000000) if length.isdigit() else 0
            self.fetch_id += 1
            threading.Thread(
                target=self._load,
                args=(self.fetch_id, key, title, artist, album, duration),
                daemon=True,
            ).start()

    def render(self):
        if not self.player:
            self.set_lines("", self.message or "♪", "")
        elif not self.lines:
            self.set_lines(
                "", "Buscando letra…" if self.loading else "Sin letra sincronizada", ""
            )
        else:
            position_raw = run(["playerctl", "-p", self.player, "position"])
            try:
                position = float(position_raw)
            except ValueError:
                position = 0.0
            index = -1
            for i, (start, _text, _words) in enumerate(self.lines):
                if start <= position:
                    index = i
                else:
                    break
            if index < 0:
                self.set_lines("", "♪", self.lines[0][1])
            else:
                start, text, words = self.lines[index]
                if words:
                    sung = "".join(w[1] for w in words if position >= w[0])
                    rest = "".join(w[1] for w in words if position < w[0])
                elif text:
                    end = (
                        self.lines[index + 1][0]
                        if index + 1 < len(self.lines)
                        else start + 4
                    )
                    frac = max(
                        0.0, min(1.0, (position - start) / max(end - start, 0.001))
                    )
                    cut = int(round(len(text) * frac))
                    sung, rest = text[:cut], text[cut:]
                else:
                    sung, rest = "", ""
                if text:
                    self.cur.set_markup(
                        f"<span foreground='{ACCENT}'>{esc(sung)}</span>"
                        f"<span foreground='{FG}'>{esc(rest)}</span>"
                    )
                else:
                    self.cur.set_markup(f"<span foreground='{ACCENT}'>♪</span>")
                self.prev.set_text(self.lines[index - 1][1] if index - 1 >= 0 else "")
                self.nxt.set_text(
                    self.lines[index + 1][1] if index + 1 < len(self.lines) else ""
                )

    def tick(self):
        self.tick_count += 1
        if self.tick_count % METADATA_EVERY == 1:
            self.refresh_track()
        self.render()
        return True


def main():
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, Gtk.main_quit)
    Overlay()
    Gtk.main()


if __name__ == "__main__":
    main()
