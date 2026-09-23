from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from musicui import config, console, i18n, logbook

_journal = logbook.get("autostart")

_PALETTE = {
    "h": "\x1b[1m",
    "a": "\x1b[96m",
    "d": "\x1b[90m",
    "w": "\x1b[93m",
    "r": "\x1b[0m",
}

RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
VALUE_NAME = "MusicUI"

DONE = "steam"
QUIET = "skip"

_OFF = frozenset({"off", "выкл", "0", "no", "нет", "не", "quiet", "хватит"})


def launcher() -> str:
    return "MusicUI.exe" if getattr(sys, "frozen", False) else "python -m musicui"


def steam_line() -> str:
    exe = Path(sys.executable).resolve()
    if getattr(sys, "frozen", False):
        return f'"{exe}" --launch %command%'
    entry = Path(config.BASE_DIR) / "musicui" / "__main__.py"
    return f'"{exe}" "{entry}" --launch %command%'


def to_clipboard(line: str) -> bool:
    try:
        subprocess.run(
            ["clip"],
            input=line.encode("mbcs", "replace"),
            check=True,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        return True
    except Exception:
        return False


def _drop_old_run_key() -> None:
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
            winreg.DeleteValue(key, VALUE_NAME)
    except (ImportError, OSError):
        pass


def show() -> None:
    line = steam_line()
    _drop_old_run_key()
    copied = to_clipboard(line)
    _journal.info(f"showed the Dota launch line, clipboard: {'yes' if copied else 'no'}")
    _journal.debug(line)

    paint = _PALETTE if console.colors() else dict.fromkeys(_PALETTE, "")
    hint = i18n.t("autostart.hint") if copied else ""
    print(i18n.t(
        "autostart.guide",
        line=line,
        cmd=launcher(),
        here=i18n.t("autostart.here_clip") if copied else i18n.t("autostart.here"),
        hint=f"{paint['d']}{hint}{paint['r']}" if hint else "",
        **paint,
    ))
    if not getattr(sys, "frozen", False):
        print(i18n.t("autostart.pybuild"))


def _quiet() -> None:
    _drop_old_run_key()
    config.write_autostart_choice(QUIET)
    _journal.info("autostart reminder turned off")
    print(i18n.t("autostart.quiet1"))
    print(i18n.t("autostart.quiet2", cmd=launcher()))


def ask() -> None:
    if config.read_autostart_choice() in (DONE, QUIET):
        return
    show()


def handle(raw: str | None) -> None:
    if (raw or "").strip().lower() in _OFF:
        _quiet()
        return
    show()
