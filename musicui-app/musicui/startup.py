from __future__ import annotations

import sys

from musicui import config, i18n, logbook
from musicui import spotify_setup

_SETUP_KEYS = frozenset({"k", "к"})

_journal = logbook.get("start")


def _match(raw: str) -> str | None:
    if not raw:
        return None

    if raw.isdigit():
        index = int(raw) - 1
        if 0 <= index < len(config.MODES):
            return config.MODES[index]
        return None

    for name in config.MODES:
        if name.startswith(raw) or config.mode_title(name).lower().startswith(raw):
            return name
    return None


def parse_mode(raw: str) -> str:
    mode = _match(raw.strip().lower())
    if mode is None:
        names = ", ".join(config.MODES)
        _journal.error(f"unknown mode {raw!r}, available: {names}")
        print(i18n.t("mode.unknown", raw=repr(raw), names=names))
        sys.exit(2)
    return mode


def _status_label(status: str) -> str:
    if status == "env":
        return i18n.t("keys.status.env")
    if status == "file":
        return config.SECRETS_FILE.name
    return i18n.t("keys.status.none")


def _menu(numbers: dict[str, int]) -> None:
    width = max(len(config.mode_title(name)) for name in config.MODES)
    status = config.credentials_status()
    label = _status_label(status)
    verb = i18n.t("keys.setup") if status == "none" else i18n.t("keys.replace")

    print("\n" + i18n.t("menu.header") + "\n")
    for name in config.MODES:
        print(f"  {numbers[name]}  {config.mode_title(name).ljust(width)}   {config.mode_hint(name)}")
    print("\n" + i18n.t("menu.keys", label=label, verb=verb) + "\n")


def choose_mode() -> str:
    default = config.read_last_mode() or config.MODES[0]

    if not sys.stdin or not sys.stdin.isatty():
        _journal.debug(f"no console, using the last mode: {default}")
        print(i18n.t("mode.last", title=config.mode_title(default)))
        return default

    numbers = {name: i for i, name in enumerate(config.MODES, 1)}
    prompt = i18n.t("menu.prompt", n=numbers[default])
    _menu(numbers)

    while True:
        try:
            raw = input(prompt).strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            return default

        if not raw:
            return default
        if raw in _SETUP_KEYS:
            spotify_setup.wizard()
            _menu(numbers)
            continue
        mode = _match(raw)
        if mode is not None:
            return mode
        print(i18n.t("menu.bad"))


def build_player(mode: str):
    if mode == config.MODE_SPOTIFY:
        try:
            spotify_setup.ensure()
            client_id, client_secret = config.load_credentials()
            from musicui.sources.spotify_player import SpotifyPlayer

            return SpotifyPlayer(client_id, client_secret), mode, "spotify", None
        except Exception as exc:
            _journal.warning(f"Spotify unavailable: {exc}", exc_info=True)
            print(i18n.t("player.spotify.fail", exc=exc))
            print(i18n.t("player.spotify.fallback", title=config.mode_title(config.FALLBACK_MODE)) + "\n")
            mode = config.FALLBACK_MODE

    try:
        from musicui.sources.system_player import SystemPlayer

        return SystemPlayer(), mode, "system", None
    except Exception as exc:
        _journal.error(f"system media session unavailable: {exc}", exc_info=True)
        print(i18n.t("player.system.fail", exc=exc))
        print(i18n.t("player.mediakeys"))
        return None, mode, "mediakeys", str(exc)
