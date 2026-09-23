from __future__ import annotations

import os
import sys

ATTACH_PARENT = -1
CP_UTF8 = 65001
ENABLE_VT = 0x0004

_COLORS: bool | None = None


def _kernel32():
    try:
        import ctypes

        return ctypes.WinDLL("kernel32", use_last_error=True)
    except Exception:
        return None


def _devnull(mode: str):
    try:
        return open(os.devnull, mode, encoding="utf-8")
    except OSError:
        return None


def _usable(stream) -> bool:
    if stream is None:
        return False
    try:
        stream.fileno()
    except Exception:
        return False
    return True


def ensure_stdio() -> None:
    if getattr(sys, "stdin", None) is None:
        sys.stdin = _devnull("r")
    for name in ("stdout", "stderr"):
        if getattr(sys, name, None) is None:
            setattr(sys, name, _devnull("w"))


def attach(title: str = "MusicUI") -> bool:
    kernel32 = _kernel32()
    if kernel32 is None or kernel32.GetConsoleWindow():
        return False
    if _usable(sys.stdout) and _usable(sys.stdin):
        return False

    if not kernel32.AttachConsole(ATTACH_PARENT) and not kernel32.AllocConsole():
        return False

    try:
        if not _usable(sys.stdin):
            sys.stdin = open("CONIN$", "r", encoding="utf-8", errors="replace")
        for name in ("stdout", "stderr"):
            if not _usable(getattr(sys, name, None)):
                setattr(sys, name, open("CONOUT$", "w", encoding="utf-8",
                                        errors="replace", buffering=1))
    except OSError:
        ensure_stdio()
        return False

    _utf8(kernel32)
    try:
        kernel32.SetConsoleTitleW(title)
    except Exception:
        pass
    return True


def _utf8(kernel32) -> None:
    try:
        before = kernel32.GetConsoleOutputCP(), kernel32.GetConsoleCP()
        if before == (CP_UTF8, CP_UTF8):
            return
        kernel32.SetConsoleOutputCP(CP_UTF8)
        kernel32.SetConsoleCP(CP_UTF8)
    except Exception:
        return

    import atexit

    def restore() -> None:
        try:
            kernel32.SetConsoleOutputCP(before[0])
            kernel32.SetConsoleCP(before[1])
        except Exception:
            pass

    atexit.register(restore)


def colors() -> bool:
    global _COLORS
    if _COLORS is None:
        _COLORS = _enable_vt()
    return _COLORS


def _enable_vt() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    stream = getattr(sys, "stdout", None)
    try:
        if stream is None or not stream.isatty():
            return False
        import ctypes
        import msvcrt

        kernel32 = _kernel32()
        if kernel32 is None:
            return False
        handle = msvcrt.get_osfhandle(stream.fileno())
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(ctypes.c_void_p(handle), ctypes.byref(mode)):
            return False
        if mode.value & ENABLE_VT:
            return True
        return bool(kernel32.SetConsoleMode(ctypes.c_void_p(handle), mode.value | ENABLE_VT))
    except Exception:
        return False


def crash(exc: BaseException) -> None:
    import traceback

    from musicui import i18n, logbook

    print("".join(traceback.format_exception(exc)), file=sys.stderr)
    where = logbook.crash(exc)
    if where is not None:
        print(i18n.t("crash.log", where=where), file=sys.stderr)
