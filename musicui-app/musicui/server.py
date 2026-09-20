from __future__ import annotations

import json
import logging
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from musicui import autostart
from musicui import config
from musicui import console
from musicui import i18n
from musicui import logbook
from musicui import procwatch
from musicui import startup
from musicui.audio.equalizer import Equalizer
from musicui.core.controls import Controls
from musicui.core.poller import Poller
from musicui.core.state import StateStore

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

_journal = logbook.get("server")
_requests = logbook.get("http")
_widget = logbook.get("widget")


def _already_running(port: int) -> bool:
    with socket.socket() as probe:
        probe.settimeout(0.35)
        return probe.connect_ex((config.HOST, port)) == 0


def _log(shown: str, logged: str, level: int = logging.INFO, trace: bool = False) -> None:
    print(f"{time.strftime('%H:%M:%S')} {shown}")
    _journal.log(level, logged, exc_info=trace)


def _spawn(command: list[str]):
    try:
        return subprocess.Popen(command)
    except OSError as exc:
        _log(i18n.t("server.game.spawnfail", exc=exc),
             f"could not start the game: {exc}", logging.ERROR)
        return None


def _wait_for(process) -> None:
    if process is None:
        return
    try:
        process.wait()
    except KeyboardInterrupt:
        pass


def _wait_game_gone() -> None:
    if not procwatch.available():
        _journal.debug("process list unavailable, not tracking the game")
        return
    gone_at = None
    while not _quit.is_set():
        if procwatch.running(config.GAME_APPS):
            if gone_at is not None:
                _journal.debug("game is back in the process list, keep waiting")
            gone_at = None
        else:
            gone_at = gone_at or time.monotonic()
            if time.monotonic() - gone_at >= config.WATCH_GRACE:
                _journal.debug(f"game gone for {config.WATCH_GRACE:.0f}s, letting go")
                return
        _quit.wait(config.WATCH_POLL)


def stop_running(port: int) -> None:
    request = urllib.request.Request(f"http://{config.HOST}:{port}/quit", data=b"", method="POST")
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            response.read()
        print(i18n.t("server.stopped"))
    except OSError:
        print(i18n.t("server.notrunning"))


_quit = threading.Event()


def _force_exit(delay: float = 3.0) -> None:
    def burn():
        time.sleep(delay)
        try:
            sys.stdout.flush()
        except Exception:
            pass
        _journal.debug(f"graceful exit missed {delay:.0f}s, killing the process")
        logbook.farewell()
        os._exit(0)

    threading.Thread(target=burn, name="di-exit", daemon=True).start()


class Island:
    def __init__(self, mode: str):
        self.store = StateStore()

        player, self.mode, backend, self.player_error = startup.build_player(mode)
        self.player = player
        self.store.set_mode(self.mode)
        self.store.set_player_backend(backend, self.player_error)

        self.poller = Poller(self.player, self.store)
        self.equalizer = Equalizer(self.store)
        self.controls = Controls(self.player, self.store,
                                 wake_poller=self.poller.wake, audio=self.equalizer)

        _journal.info(f"mode {self.mode}, backend {backend}"
                      + (f", hiccup: {self.player_error}" if self.player_error else ""))

    def start(self):
        self.poller.start()
        self.equalizer.start()
        _journal.debug("poller and audio threads up")

    def stop(self):
        _journal.debug("stopping threads")
        self.poller.stop()
        self.equalizer.stop()
        stop = getattr(self.player, "stop", None)
        if stop:
            stop()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    island: Island = None
    idle: StateStore = None
    mode: str = None
    httpd: ThreadingHTTPServer = None
    server_version = "MusicUI/1.0"

    HOT = frozenset({"/tick", "/t", "/state", "/", "/s", "/art"})
    QUIET = frozenset({"/log"})
    HITS_EVERY = 30.0

    hits: dict[str, int] = {}
    hits_at = 0.0
    hits_lock = threading.Lock()

    def log_message(self, *_args):
        pass

    def log_error(self, fmt: str, *args):
        _requests.warning(f"{self.address_string()}: {fmt % args if args else fmt}")

    def _reply(self, body: bytes, content_type: str, status: int):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _send(self, payload: dict, status: int = 200):
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self._reply(body, "application/json; charset=utf-8", status)

    def _send_text(self, text: str, status: int = 200):
        self._reply(text.encode("ascii", errors="ignore"), "text/plain; charset=ascii", status)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(parsed.query).items()}
        self._route(parsed.path, query)

    def do_POST(self):
        parsed = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(parsed.query).items()}
        try:
            length = int(self.headers.get("Content-Length") or 0)
            if length > 0:
                raw = self.rfile.read(length).decode("utf-8", "replace")
                body = json.loads(raw)
                if isinstance(body, dict):
                    query.update(body)
        except (ValueError, OSError):
            pass
        self._route(parsed.path, query)

    @classmethod
    def _idle_store(cls) -> StateStore:
        if cls.idle is None:
            store = StateStore()
            store.set_mode(cls.mode or config.MODES[0])
            store.set_player_backend("idle", None)
            cls.idle = store
        return cls.idle

    @classmethod
    def _tally(cls, path: str) -> None:
        with cls.hits_lock:
            cls.hits[path] = cls.hits.get(path, 0) + 1
            now = time.monotonic()
            if not cls.hits_at:
                cls.hits_at = now
                return
            if now - cls.hits_at < cls.HITS_EVERY:
                return
            span = now - cls.hits_at
            counted, cls.hits, cls.hits_at = cls.hits, {}, now

        summary = ", ".join(f"{name} ×{count}" for name, count in sorted(counted.items()))
        _requests.debug(f"polls over {span:.0f}s: {summary}")

    def _route(self, path: str, query: dict):
        if path in self.HOT:
            self._tally(path)
        elif path not in self.QUIET:
            extra = " ".join(f"{key}={value}" for key, value in query.items())
            _requests.info(f"{self.command} {path}" + (f" {extra}" if extra else ""))

        try:
            self._dispatch(path, query)
        except Exception:
            _requests.exception(f"{self.command} {path} failed")
            try:
                self._send({"ok": False, "error": "server error"}, status=500)
            except Exception:
                pass

    def _dispatch(self, path: str, query: dict):
        island = Handler.island
        store = island.store if island is not None else Handler._idle_store()

        if path in ("/tick", "/t"):
            self._send(store.snapshot_tick())

        elif path in ("/state", "/", "/s"):
            self._send(store.snapshot_state())

        elif path == "/control":
            if island is None:
                self._send({"ok": False, "error": "idle"})
                return
            action = str(query.get("action") or "")
            self._send(island.controls.dispatch(action, query.get("value")))

        elif path == "/config":
            if island is None:
                self._send({"ok": False, "error": "idle"})
                return
            bands = query.get("bands")
            island.equalizer.configure(
                bands=int(bands) if bands not in (None, "") else None,
                music_only=config.truthy(query.get("music_only")),
                allow_unknown=config.truthy(query.get("allow_unknown")),
            )
            enabled = config.truthy(query.get("equalizer"))
            if enabled is not None:
                island.equalizer.enabled = enabled
            self._send({"ok": True})

        elif path == "/art":
            art = store.cover_b64()
            self._send_text(art or "", status=200 if art else 404)

        elif path == "/log":
            text = str(query.get("text") or "").strip()[:400]
            if text:
                _widget.log(logbook.level(query.get("level")), text)
            self._send({"ok": bool(text)})

        elif path == "/quit":
            if self.command != "POST":
                self._send({"ok": False, "error": "post only"}, status=405)
                return
            _journal.info("/quit received, shutting down")
            self._send({"ok": True})
            _quit.set()
            if Handler.httpd is not None:
                threading.Thread(target=Handler.httpd.shutdown, daemon=True).start()

        elif path == "/health":
            if island is None:
                self._send({"ok": True, "idle": True, "mode": Handler.mode,
                            "log": str(logbook.path() or "")})
                return
            self._send({
                "ok": True,
                "mode": island.mode,
                "log": str(logbook.path() or ""),
                "player": island.store.player_backend(),
                "player_app": getattr(island.player, "source_app", None),
                "player_error": island.player_error,
                "audio": island.equalizer.diagnostics(),
            })

        else:
            self._send({"ok": False, "error": "not found"}, status=404)


_BLOCKS = " ▁▂▃▄▅▆▇█"

def _bar(value: float) -> str:
    index = int(min(1.0, max(0.0, value)) * (len(_BLOCKS) - 1))
    return _BLOCKS[index]


def selftest(island: Island, seconds: float = 20.0):
    yes, no = i18n.t("common.yes"), i18n.t("common.no")

    print(i18n.t("selftest.header"))
    print(i18n.t("selftest.mode", title=config.mode_title(island.mode)))
    print(i18n.t("selftest.source", value="ok" if island.player else island.player_error))
    print(i18n.t("selftest.log", value=logbook.path() or no))

    island.start()
    time.sleep(2.0)

    diag = island.equalizer.diagnostics()
    print(i18n.t("selftest.sessions",
                 value="ok" if diag["sessions_available"] else diag["sessions_error"]))
    print(i18n.t("selftest.perproc",
                 value=(yes if diag["process_loopback"]
                        else no + " - " + str(diag["process_error"]))))
    print(i18n.t("selftest.mix",
                 value=(yes if diag["device_loopback"]
                        else no + " - " + str(diag["device_error"]))))
    print(i18n.t("selftest.fft", value=yes if diag["fft"] else no))

    volume = island.equalizer.volume()
    level = "-" if volume["level"] is None else f"{volume['level']:.2f}"
    print(i18n.t("selftest.volume",
                 app=volume["app"] or i18n.t("selftest.noplayer"), level=level))

    print(i18n.t("selftest.snapshot"))
    for session in sorted(diag["snapshot"]["sessions"], key=lambda s: -s["peak"]):
        print(f"  {session['kind']:8} {session['name']:24} pid {session['pid']:<7} peak {session['peak']:.4f}")

    print(i18n.t("selftest.bars"))
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        tick = island.store.snapshot_tick()
        state = island.store.snapshot_state()
        bars = "".join(_bar(b) for b in tick["bands"])
        track = state["track"]
        title = f"{track['artist']} — {track['title']}" if track else i18n.t("selftest.notrack")
        note = state.get("audio_note") or ""
        print(f"\r[{bars}] {tick['band_source']:8} {'play' if tick['playing'] else 'stop'} "
              f"{tick['pos']:6.1f}s  {title[:38]:38} {note[:44]:44}", end="", flush=True)
        time.sleep(1 / 15)
    print()


def launch_with_game(port: int, launch: list[str], verbose: bool) -> None:
    owner = not _already_running(port)
    if owner:
        logbook.setup(verbose)

    line = subprocess.list2cmdline(launch)
    _log(i18n.t("server.steam.launch", line=line), f"launching from Steam: {line}")
    game = _spawn(launch)
    if game is None:
        _log(i18n.t("server.game.nostart"),
             "game did not start - check the Dota 2 launch options")
        return
    _log(i18n.t("server.game.up", pid=game.pid), f"game is up, pid {game.pid}")
    config.write_autostart_choice(autostart.DONE)

    island = None
    httpd = None

    if not owner:
        _log(i18n.t("server.already.waiting", port=port),
             f"MusicUI already listens on {port} - just waiting for the game")
    else:
        try:
            mode = config.read_last_mode() or config.FALLBACK_MODE
            island = Island(mode)
            config.write_last_mode(island.mode)
            Handler.island = island
            Handler.mode = island.mode
            island.start()
            httpd = ThreadingHTTPServer((config.HOST, port), Handler)
            httpd.daemon_threads = True
            Handler.httpd = httpd
            threading.Thread(target=httpd.serve_forever, name="di-http", daemon=True).start()
            _log(i18n.t("server.island.up", title=config.mode_title(island.mode), port=port),
                 f"island up, mode {island.mode}, port {port}")
        except Exception as exc:
            Handler.island = None
            _log(i18n.t("server.island.fail", exc=repr(exc)),
                 f"island failed to start: {exc!r} - the game keeps running",
                 logging.ERROR, trace=True)

    _wait_for(game)
    _log(i18n.t("server.game.closed"), "game closed")
    _wait_game_gone()
    _force_exit()
    Handler.island = None
    if httpd is not None:
        httpd.shutdown()
        try:
            httpd.server_close()
        except OSError:
            pass
    if island is not None:
        island.stop()
    _log(i18n.t("server.shutwithgame"), "shut down with the game")


def main():
    args = sys.argv[1:]

    launch: list[str] = []
    if "--launch" in args:
        index = args.index("--launch")
        launch, args = args[index + 1:], args[:index]

    forced_lang = None
    if "--lang" in args:
        li = args.index("--lang")
        forced_lang = args[li + 1] if li + 1 < len(args) else None
        del args[li:li + 2]
    i18n.set_lang(forced_lang)

    if not launch and "--auto" not in args:
        console.attach()
    console.ensure_stdio()

    verbose = "--verbose" in args or "-v" in args
    port = config.PORT
    if "--port" in args:
        port = int(args[args.index("--port") + 1])

    if "--autostart" in args:
        index = args.index("--autostart") + 1
        autostart.handle(args[index] if index < len(args) else None)
        return

    if "--stop" in args:
        stop_running(port)
        return

    if launch:
        launch_with_game(port, launch, verbose)
        return

    if _already_running(port):
        print(i18n.t("server.already.running", host=config.HOST, port=port))
        print(i18n.t("server.stophint", cmd=autostart.launcher()))
        return

    journal = logbook.setup(verbose)
    _journal.info(f"port {port}, args: {' '.join(args) or 'none'}")
    if journal is not None:
        print(i18n.t("server.loghint", path=journal))

    if "--mode" in args:
        mode = startup.parse_mode(args[args.index("--mode") + 1])
    elif "--auto" in args:
        mode = config.read_last_mode() or config.MODES[0]
        print(i18n.t("mode.last", title=config.mode_title(mode)))
    else:
        mode = startup.choose_mode()
        autostart.ask()

    island = Island(mode)
    config.write_last_mode(island.mode)
    Handler.island = island

    if "--selftest" in args:
        try:
            selftest(island)
        except KeyboardInterrupt:
            print()
        finally:
            island.stop()
        return

    island.start()
    httpd = ThreadingHTTPServer((config.HOST, port), Handler)
    httpd.daemon_threads = True
    Handler.httpd = httpd

    print(i18n.t("server.mode", title=config.mode_title(island.mode)))
    print(i18n.t("server.url", host=config.HOST, port=port))
    _journal.info(f"listening on http://{config.HOST}:{port}")

    print(i18n.t("server.stopwin", cmd=autostart.launcher()))
    print(i18n.t("server.ctrlc"))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        _journal.info("Ctrl+C, stopping")
        print(i18n.t("server.stopping"))
    finally:
        _force_exit()
        httpd.shutdown()
        try:
            httpd.server_close()
        except OSError:
            pass
        island.stop()
