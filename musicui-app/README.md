# MusicUI

Music overlay for Dota 2: track, cover, equalizer and lyrics on top of the game.
Оверлей плеера для Dota 2: трек, обложка, эквалайзер и текст песни поверх игры.

## Install (EN)

1. [Download](https://github.com/But3rflys/umbrella-work/releases?q=musicui&expanded=true) the latest release.
2. Unzip it anywhere.
3. Put `MusicUI.lua` into your cheat's `..\scripts\` folder.
4. Run `MusicUI.exe` and follow the prompts.

The console language follows your Windows language. Force it with `MusicUI.exe --lang en`.

## Установка (RU)

1. [Скачать](https://github.com/But3rflys/umbrella-work/releases?q=musicui&expanded=true) последнюю версию.
2. Распаковать в любое место.
3. Закинуть `MusicUI.lua` в папку `..\scripts\` твоего чита.
4. Запустить `MusicUI.exe` и следовать подсказкам.

Язык консоли берется из языка Windows. Принудительно: `MusicUI.exe --lang ru`.

## Build

```bash
pip install -r requirements.txt pyinstaller
python tools/build.py
```

`dist/MusicUI.exe` собирается тем же способом, что и в workflow `release-musicui`.
