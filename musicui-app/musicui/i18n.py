from __future__ import annotations

import os

_LANG = None


def _detect() -> str:
    forced = os.environ.get("MUSICUI_LANG")
    if forced:
        code = forced.strip().lower()[:2]
        if code in _STRINGS:
            return code

    try:
        import ctypes

        lang_id = ctypes.windll.kernel32.GetUserDefaultUILanguage()
        if (lang_id & 0xFF) == 0x19:
            return "ru"
        return "en"
    except Exception:
        pass

    for var in ("LANG", "LC_ALL", "LANGUAGE"):
        value = os.environ.get(var)
        if value and value.strip().lower().startswith("ru"):
            return "ru"
    return "en"


def set_lang(code: str | None) -> str:
    global _LANG
    if code:
        code = str(code).strip().lower()[:2]
        if code in _STRINGS:
            _LANG = code
            return _LANG
    _LANG = _detect()
    return _LANG


def lang() -> str:
    global _LANG
    if _LANG is None:
        _LANG = _detect()
    return _LANG


def t(key: str, **kwargs) -> str:
    table = _STRINGS.get(lang()) or _STRINGS["en"]
    text = table.get(key)
    if text is None:
        text = _STRINGS["en"].get(key, key)
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError, ValueError):
            return text
    return text


_SPOTIFY_GUIDE_EN = """
Spotify keys - a one-time thing, about five minutes

You need a Premium account: without it the Web API won't return the track
position, and «Spotify» mode won't be any better than the system one.

1. developer.spotify.com/dashboard - sign in with your Spotify account
   and click Create app.

2. Fill in the form:

     App name          anything, e.g. Dynamic Island
     App description   anything, e.g. overlay with lyrics
     Website           can be left empty
     Redirect URI      {redirect}
                       paste it and click Add next to the field - if the
                       line is missing from the list, login won't work later

   Exactly 127.0.0.1, not localhost: Spotify won't accept localhost.

   Which API/SDKs are you planning to use - tick Web API, nothing else
   is needed. Below, agree to the Developer Terms of Service and hit Save.

3. On the app page open Settings. At the top - Client ID, copy it.
   Below it the View client secret link - open it and copy the secret.

4. Paste both values here. An empty line cancels.

The keys go into {secrets} next to the server. This is access to your
account: don't upload the file or show it to anyone.
"""

_SPOTIFY_GUIDE_RU = """
Ключи Spotify - делается один раз, минут пять

Нужен аккаунт с Premium: без него Web API не отдаёт позицию трека, и режим
«Spotify» ничем не будет лучше системного.

1. developer.spotify.com/dashboard - войди своим аккаунтом Spotify
   и нажми Create app.

2. Заполни форму:

     App name          любое, например Dynamic Island
     App description   любое, например оверлей с лирикой
     Website           можно не заполнять
     Redirect URI      {redirect}
                       вставь и нажми Add рядом с полем - если строки
                       нет в списке, вход потом не сработает

   Именно 127.0.0.1, а не localhost: localhost спотик не принимает.

   Which API/SDKs are you planning to use - галочка Web API, остальное
   не нужно. Ниже согласись с Developer Terms of Service и жми Save.

3. На странице приложения открой Settings. Сверху Client ID - копируй.
   Под ним ссылка View client secret - открой и копируй secret.

4. Вставь оба значения здесь. Пустая строка - отмена.

Ключи лягут в {secrets} рядом с сервером. Это доступ к твоему
аккаунту: файл не выкладывай и никому не показывай.
"""

_AUTOSTART_GUIDE_EN = """
{h}Autostart with Dota 2{r}
{d}---------------------{r}

One line in the launch options - and MusicUI comes up together with the game
and shuts down when you leave it.

{here}

    {a}{line}{r}
{hint}
{h}Where to paste it{r}

  1. Open Steam and go to {h}Library{r}.
  2. Right-click {h}Dota 2{r} and pick {h}Properties...{r}
  3. On the {h}General{r} tab, at the bottom - the {h}Launch Options{r} field.
  4. Put the cursor at the very start of the field and press Ctrl+V.
     Don't erase other options - they just stay after the line.

     before:  -novid -high
     after:   {d}<the line>{r} -novid -high

{h}Important{r}

  {w}*{r} The line always goes first. Don't touch %command% inside it.
  {w}*{r} Launch options are stored per Steam account. Logged into another
    account - paste the line there once more.
  {w}*{r} Moved the MusicUI folder - the line is outdated, get a new one:
    {cmd} --autostart

That's it. Launch Dota as usual - no need to come back here.
"""

_AUTOSTART_GUIDE_RU = """
{h}Автозапуск вместе с Dota 2{r}
{d}--------------------------{r}

Одна строка в параметрах запуска - и MusicUI сам поднимется вместе с игрой,
а когда выйдешь из Доты, выключится.

{here}

    {a}{line}{r}
{hint}
{h}Куда вставить{r}

  1. Открой Steam и перейди в {h}Библиотеку{r}.
  2. Правой кнопкой по {h}Dota 2{r} - {h}Свойства...{r}
  3. Во вкладке {h}Общие{r} внизу поле {h}Параметры запуска{r}.
  4. Поставь курсор в самое начало поля и нажми Ctrl+V.
     Остальные параметры не стирай - они просто остаются после строки.

     было:    -novid -high
     стало:   {d}<строка>{r} -novid -high

{h}Важно{r}

  {w}*{r} Строка всегда идёт первой. %command% внутри неё не трогай.
  {w}*{r} Параметры запуска у каждого аккаунта Steam свои. Зашёл с другого
    аккаунта - вставь строку туда заново.
  {w}*{r} Переместил папку с MusicUI - строка устарела, возьми новую:
    {cmd} --autostart

Всё. Дальше запускай Доту как обычно - сюда возвращаться не нужно.
"""

_STRINGS = {
    "en": {
        "menu.header": "MusicUI // music overlay",
        "menu.keys": "  k  Spotify keys: {label} - {verb}",
        "menu.prompt": "mode [{n}]: ",
        "menu.bad": "enter a mode number or k for Spotify keys",
        "keys.status.env": "environment variables",
        "keys.status.none": "not set",
        "keys.setup": "set up",
        "keys.replace": "replace",
        "mode.spotify.title": "Spotify",
        "mode.spotify.hint": "exact position and seeking / needs Premium and keys",
        "mode.system.title": "System",
        "mode.system.hint": "any Windows player / no keys or Premium",
        "mode.unknown": "Unknown mode {raw}. Available: {names}",
        "mode.last": "mode: {title} (same as last time)",
        "player.spotify.fail": "Spotify unavailable: {exc}",
        "player.spotify.fallback": "switching to «{title}»",
        "player.system.fail": "System media session unavailable: {exc}",
        "player.mediakeys": "only the equalizer and media keys will work - no track name",
        "spotify.guide": _SPOTIFY_GUIDE_EN,
        "spotify.badkey": "  does not look like {label}: expected 32 chars 0-9 and a-f",
        "spotify.writefail": "  could not write {name}: {exc}",
        "spotify.done": "  done, keys saved to {name}",
        "spotify.browser1": "  on the first launch of «Spotify» mode a browser will open -",
        "spotify.browser2": "  allow access there once.",
        "spotify.need": "\n«Spotify» mode needs app keys, and there are none yet.",
        "common.cancelled": "  cancelled",
        "autostart.guide": _AUTOSTART_GUIDE_EN,
        "autostart.here_clip": "The line - already on your clipboard:",
        "autostart.here": "The line:",
        "autostart.hint": "\n    if you see squares or garbage instead of letters - no worries,\n    the clipboard has the correct line, just paste it into Steam.\n",
        "autostart.pybuild": "this is the line for the python launch; build the exe - python tools/build.py - and take the new one.",
        "autostart.quiet1": "\nok, I won't remind you again",
        "autostart.quiet2": "the line for Dota, when you need it: {cmd} --autostart",
        "server.stopped": "server stopped",
        "server.notrunning": "server not responding - looks like it isn't running",
        "server.game.spawnfail": "could not start the game: {exc}",
        "server.game.nostart": "game did not start - check the line in the Dota 2 launch options",
        "server.game.up": "game is up, pid {pid}",
        "server.steam.launch": "launching from Steam: {line}",
        "server.already.waiting": "MusicUI already listens on {port} - just waiting for the game",
        "server.island.up": "island up, mode {title}, port {port}",
        "server.island.fail": "island failed to start: {exc} - the game keeps running",
        "server.game.closed": "game closed",
        "server.shutwithgame": "shut down with the game",
        "server.already.running": "MusicUI is already running at http://{host}:{port} - a second instance isn't needed",
        "server.stophint": "stop it: {cmd} --stop",
        "server.loghint": "log: {path}",
        "server.mode": "\nmode: {title}",
        "server.url": "MusicUI: http://{host}:{port}",
        "server.stopwin": "stop from another window: {cmd} --stop",
        "server.ctrlc": "Ctrl+C to exit.",
        "server.stopping": "\nstopping...",
        "selftest.header": "MusicUI // self-test",
        "selftest.mode": "mode          : {title}",
        "selftest.source": "source        : {value}",
        "selftest.log": "log           : {value}",
        "selftest.sessions": "audio sessions: {value}",
        "selftest.perproc": "per-process   : {value}",
        "selftest.mix": "mix (fallback): {value}",
        "selftest.fft": "numpy/FFT     : {value}",
        "selftest.volume": "volume        : {app} {level}",
        "selftest.noplayer": "player not found",
        "selftest.snapshot": "\naudio sessions right now:",
        "selftest.bars": "\nbars (Ctrl+C to exit). Check: music moves them, talking doesn't.\n",
        "selftest.notrack": "no track",
        "common.yes": "yes",
        "common.no": "no",
        "crash.log": "it's all in the log: {where}",
        "config.secrets.broken": "{path} is corrupted: {exc}",
        "config.keys.missing": "Spotify keys are not set",
        "src.spotipy.missing": "spotipy is not installed: pip install -r requirements.txt",
        "src.system.missing": "no access to the system media session: pip install -r requirements.txt",
    },
    "ru": {
        "menu.header": "MusicUI // музыкальный оверлей",
        "menu.keys": "  k  ключи Spotify: {label} - {verb}",
        "menu.prompt": "режим [{n}]: ",
        "menu.bad": "нужен номер режима или k - ключи Spotify",
        "keys.status.env": "переменные окружения",
        "keys.status.none": "не настроены",
        "keys.setup": "настроить",
        "keys.replace": "заменить",
        "mode.spotify.title": "Spotify",
        "mode.spotify.hint": "точная позиция и перемотка / нужен Premium и ключи",
        "mode.system.title": "Системный",
        "mode.system.hint": "любой плеер Windows / без ключей и Premium",
        "mode.unknown": "Неизвестный режим {raw}. Доступны: {names}",
        "mode.last": "режим: {title} (как в прошлый раз)",
        "player.spotify.fail": "Spotify недоступен: {exc}",
        "player.spotify.fallback": "переключаюсь на «{title}»",
        "player.system.fail": "Системная медиасессия недоступна: {exc}",
        "player.mediakeys": "останутся только эквалайзер и медиаклавиши - без названия трека",
        "spotify.guide": _SPOTIFY_GUIDE_RU,
        "spotify.badkey": "  не похоже на {label}: ждём 32 символа 0-9 и a-f",
        "spotify.writefail": "  не смог записать {name}: {exc}",
        "spotify.done": "  готово, ключи в {name}",
        "spotify.browser1": "  при первом запуске режима «Spotify» откроется браузер -",
        "spotify.browser2": "  там нужно один раз разрешить доступ.",
        "spotify.need": "\nРежиму «Spotify» нужны ключи приложения, а их ещё нет.",
        "common.cancelled": "  отменено",
        "autostart.guide": _AUTOSTART_GUIDE_RU,
        "autostart.here_clip": "Строка - уже в буфере обмена:",
        "autostart.here": "Строка:",
        "autostart.hint": "\n    если вместо букв квадратики или кракозябры - не страшно,\n    в буфере строка правильная, просто вставь её в Steam.\n",
        "autostart.pybuild": "это строка для запуска через python; собери exe - python tools/build.py - и возьми новую.",
        "autostart.quiet1": "\nладно, больше не напомню",
        "autostart.quiet2": "строка для Доты, когда понадобится: {cmd} --autostart",
        "server.stopped": "сервер остановлен",
        "server.notrunning": "сервер не отвечает - похоже, он и не запущен",
        "server.game.spawnfail": "не удалось запустить игру: {exc}",
        "server.game.nostart": "игра не запустилась - проверь строку в параметрах запуска Dota 2",
        "server.game.up": "игра пошла, pid {pid}",
        "server.steam.launch": "запуск из Steam: {line}",
        "server.already.waiting": "MusicUI уже слушает {port} - просто жду игру",
        "server.island.up": "островок поднят, режим {title}, порт {port}",
        "server.island.fail": "островок не поднялся: {exc} - игра работает дальше",
        "server.game.closed": "игра закрылась",
        "server.shutwithgame": "выключился вместе с игрой",
        "server.already.running": "MusicUI уже работает на http://{host}:{port} - второй экземпляр не нужен",
        "server.stophint": "остановить его: {cmd} --stop",
        "server.loghint": "лог: {path}",
        "server.mode": "\nрежим: {title}",
        "server.url": "MusicUI: http://{host}:{port}",
        "server.stopwin": "выключить из другого окна: {cmd} --stop",
        "server.ctrlc": "Ctrl+C для выхода.",
        "server.stopping": "\nостановка...",
        "selftest.header": "MusicUI // самопроверка",
        "selftest.mode": "режим         : {title}",
        "selftest.source": "источник      : {value}",
        "selftest.log": "лог           : {value}",
        "selftest.sessions": "аудиосессии   : {value}",
        "selftest.perproc": "per-process   : {value}",
        "selftest.mix": "микс (фолбэк) : {value}",
        "selftest.fft": "numpy/FFT     : {value}",
        "selftest.volume": "громкость     : {app} {level}",
        "selftest.noplayer": "плеер не найден",
        "selftest.snapshot": "\nаудиосессии сейчас:",
        "selftest.bars": "\nполосы (Ctrl+C для выхода). Проверь: музыка двигает, разговор - нет.\n",
        "selftest.notrack": "нет трека",
        "common.yes": "да",
        "common.no": "нет",
        "crash.log": "всё это лежит в логе: {where}",
        "config.secrets.broken": "{path} повреждён: {exc}",
        "config.keys.missing": "ключи Spotify не настроены",
        "src.spotipy.missing": "Не установлен spotipy: pip install -r requirements.txt",
        "src.system.missing": "Нет доступа к системной медиасессии: pip install -r requirements.txt",
    },
}
