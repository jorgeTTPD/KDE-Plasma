#!/usr/bin/env python3

import asyncio
import curses
import json
import signal
import threading
import websockets

WS_URL = "ws://127.0.0.1:23560/poll"

# Catppuccin Mocha
COLOR_BG = 0
COLOR_MAuve = 1  # #cba6f7 - artista/titulo
COLOR_BLUE = 2  # #89b4fa - letra
COLOR_OVERLAY = 3  # #6c7086 - album/esperando
COLOR_GREEN = 4  # #a6e3a1 - estado
COLOR_TRACK_BG = 5  # mauve on dark
COLOR_LYRIC_BG = 6  # blue on dark


class SharedState:
    def __init__(self):
        self._lock = threading.Lock()
        self.artist = ""
        self.title = ""
        self.album = ""
        self.lyric = ""
        self.playing = False

    def update(self, artist, title, album, lyric, playing):
        with self._lock:
            self.artist = artist
            self.title = title
            self.album = album
            self.lyric = lyric
            self.playing = playing

    def get(self):
        with self._lock:
            return self.artist, self.title, self.album, self.lyric, self.playing


state = SharedState()


async def ws_loop():
    while True:
        try:
            async with websockets.connect(WS_URL, open_timeout=1) as ws:
                while True:
                    await ws.send(json.dumps({}))
                    msg = await asyncio.wait_for(ws.recv(), timeout=2)
                    data = json.loads(msg)
                    status = data.get("playback_status", "")
                    track = data.get("track", {})
                    lyrics = data.get("lyrics") or {}
                    current_line = lyrics.get("current_lyric", "")
                    
                    playing = status == "playing" and bool(current_line)
                    state.update(
                        artist=track.get("artist", ""),
                        title=track.get("title", ""),
                        album=track.get("album", ""),
                        lyric=current_line if playing else "",
                        playing=playing,
                    )
                    await asyncio.sleep(0.3)
        except asyncio.CancelledError:
            break
        except Exception:
            state.update("", "", "", "", False)
            await asyncio.sleep(2)


def wrap_text(text, max_width):
    if not text or max_width <= 0:
        return [""]
    if len(text) <= max_width:
        return [text]
    words = text.split()
    lines = []
    current = ""
    for word in words:
        if current and len(current) + 1 + len(word) > max_width:
            lines.append(current)
            current = word
        else:
            current = f"{current} {word}".strip() if current else word
    if current:
        lines.append(current)
    return lines if lines else [""]


def draw_rounded_box(stdscr, y, x, width, height, color_pair):
    if height < 2 or width < 4:
        return
    max_y, max_x = stdscr.getmaxyx()

    top = "╭" + "─" * (width - 2) + "╮"
    bot = "╰" + "─" * (width - 2) + "╯"

    try:
        stdscr.addnstr(y, x, top, width)
    except curses.error:
        pass

    for i in range(1, height - 1):
        try:
            stdscr.addnstr(y + i, x, "│", 1)
            stdscr.addnstr(y + i, x + 1, " " * (width - 2), width - 2)
            stdscr.addnstr(y + i, x + width - 1, "│", 1)
        except curses.error:
            pass

    try:
        stdscr.addnstr(y + height - 1, x, bot, width)
    except curses.error:
        pass


def draw_centered(stdscr, y, x_start, width, text):
    if not text:
        return
    text_w = min(len(text), width - 4)
    truncated = text[:text_w]
    offset = (width - text_w) // 2
    try:
        stdscr.addnstr(
            y, x_start + offset, truncated, text_w
        )
    except curses.error:
        pass


def draw(stdscr):
    stdscr.erase()
    max_y, max_x = stdscr.getmaxyx()

    artist, title, album, lyric, playing = state.get()

    box_w = max_x - 2
    if box_w < 10:
        box_w = max_x
    box_x = max((max_x - box_w) // 2, 0)

    if playing:
        track_str = f"♪ {artist} — {title}" if artist else f"♪ {title}"
        album_str = album if album else ""

        track_lines = wrap_text(track_str, box_w - 4)
        album_lines = wrap_text(album_str, box_w - 4) if album_str else []
        track_h = 2 + len(track_lines) + len(album_lines)

        draw_rounded_box(stdscr, 0, box_x, box_w, track_h, COLOR_MAuve)

        for i, line in enumerate(track_lines):
            draw_centered(stdscr, 1 + i, box_x, box_w, line)

        for i, line in enumerate(album_lines):
            draw_centered(
                stdscr, 1 + len(track_lines) + i, box_x, box_w, line
            )

        lyric_lines = wrap_text(lyric, box_w - 4)
        lyric_h = max(3, 2 + len(lyric_lines))

        draw_rounded_box(stdscr, track_h, box_x, box_w, lyric_h, COLOR_BLUE)

        for i, line in enumerate(lyric_lines):
            draw_centered(stdscr, track_h + 1 + i, box_x, box_w, line)
    else:
        no_music = "♪ Esperando reproducción..."
        draw_rounded_box(stdscr, 0, box_x, box_w, 3, COLOR_OVERLAY)

        draw_centered(stdscr, 1, box_x, box_w, no_music)

    stdscr.refresh()


def main(stdscr):
    curses.curs_set(0)
    stdscr.nodelay(True)
    stdscr.timeout(100)

    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(COLOR_MAuve, 0xCB, -1)
    curses.init_pair(COLOR_BLUE, 0x89, -1)
    curses.init_pair(COLOR_OVERLAY, 0x6C, -1)
    curses.init_pair(COLOR_GREEN, 0xA6, -1)

    loop = asyncio.new_event_loop()
    ws_task = loop.create_task(ws_loop())

    def handle_resize(signum, frame):
        stdscr.clear()
        draw(stdscr)

    signal.signal(signal.SIGWINCH, handle_resize)

    def run_loop():
        asyncio.set_event_loop(loop)
        loop.run_forever()

    ws_thread = threading.Thread(target=run_loop, daemon=True)
    ws_thread.start()

    try:
        while True:
            draw(stdscr)
            key = stdscr.getch()
            if key == 3:
                break
    except KeyboardInterrupt:
        pass
    finally:
        ws_task.cancel()
        loop.call_soon_threadsafe(loop.stop)
        ws_thread.join(timeout=1)


if __name__ == "__main__":
    curses.wrapper(main)