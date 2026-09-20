from __future__ import annotations

import sys

from musicui import config, i18n, logbook

_journal = logbook.get("keys")

_KEY_LEN = 32
_HEX = set("0123456789abcdef")


def guide() -> str:
    return i18n.t("spotify.guide", redirect=config.REDIRECT_URI, secrets=config.SECRETS_FILE.name)


def _clean(raw: str) -> str:
    return raw.strip().strip("\"'")


def _looks_like_key(value: str) -> bool:
    return len(value) == _KEY_LEN and set(value.lower()) <= _HEX


def _ask(label: str) -> str | None:
    while True:
        try:
            value = _clean(input(f"  {label}: "))
        except (EOFError, KeyboardInterrupt):
            print()
            return None
        if not value:
            return None
        if _looks_like_key(value):
            return value
        print(i18n.t("spotify.badkey", label=label))


def wizard() -> bool:
    if not sys.stdin or not sys.stdin.isatty():
        _journal.warning("cannot ask for keys: no console")
        return False

    print(guide())

    client_id = _ask("Client ID")
    if client_id is None:
        print(i18n.t("common.cancelled") + "\n")
        return False

    client_secret = _ask("Client secret")
    if client_secret is None:
        print(i18n.t("common.cancelled") + "\n")
        return False

    try:
        config.save_credentials(client_id, client_secret)
    except OSError as exc:
        _journal.error(f"could not write {config.SECRETS_FILE.name}: {exc}")
        print("\n" + i18n.t("spotify.writefail", name=config.SECRETS_FILE.name, exc=exc) + "\n")
        return False

    _journal.info(f"keys written to {config.SECRETS_FILE.name}")
    print("\n" + i18n.t("spotify.done", name=config.SECRETS_FILE.name))
    print(i18n.t("spotify.browser1"))
    print(i18n.t("spotify.browser2") + "\n")
    return True


def ensure() -> bool:
    try:
        config.load_credentials()
        _journal.debug(f"keys in place: {config.SECRETS_FILE.name if config.SECRETS_FILE.exists() else 'env'}")
        return True
    except RuntimeError:
        pass

    _journal.info("no keys, starting the setup wizard")
    print(i18n.t("spotify.need"))
    return wizard()
