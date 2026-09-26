# umbrella-lua

Скилл для Claude Code и Codex: пишет и правит Lua-скрипты Umbrella (Dota 2) по общим правилам. Каждый скрипт выходит с меню по одному эталону и со встроенной локализацией en/ru.

Версия **1.0.3**

<!-- releases:start -->
Скачать: [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.3/umbrella-lua.zip) — `umbrella-lua-v1.0.3`, 2026-09-24

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`umbrella-lua-v1.0.3`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.3) | 2026-09-24 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.3/umbrella-lua.zip) | 46 |
| [`umbrella-lua-v1.0.2`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.2) | 2026-09-24 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.2/umbrella-lua.zip) | 1 |
| [`umbrella-lua-v1.0.1`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.1) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.1/umbrella-lua.zip) | 22 |
| [`umbrella-lua-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.0) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.0/umbrella-lua.zip) | 7 |

[Все релизы](https://github.com/But3rflys/umbrella-work/releases?q=umbrella-lua&expanded=true)
<!-- releases:end -->

## Установка

1. Скачай `umbrella-lua.zip` из последнего релиза и распакуй.
2. Положи папку `umbrella-lua`:
   - Claude Code: в `%USERPROFILE%\.claude\skills\`, явный вызов `/umbrella-lua`;
   - Codex: в `%USERPROFILE%\.agents\skills\`, явный вызов `$umbrella-lua`.
3. Перезапусти агента. Скилл включается сам, когда просишь написать или поправить скрипт Umbrella.

Для обновления замени папку `umbrella-lua` целиком. Ничего доставлять не нужно: `luatool.exe` работает на .NET Framework 4, который встроен в Windows 10 и 11. Python и Lua не требуются.

## Обновления

Раз в день `luatool.exe` запрашивает у GitHub список релизов этого репозитория. Если вышла новая версия, он пишет строку `UPDATE:`, и агент передает ее тебе. Больше утилита никуда ничего не отправляет. Отключить проверку можно переменной окружения `UMBRELLA_LUA_NO_UPDATE=1`.

## Состав

- `SKILL.md`: порядок работы и правила.
- `references/menu.md`, `localization.md`, `style.md`: эталон меню, локализация, стиль текста и отрисовки.
- `references/game-data.md`: где лежат данные игры и как их читать.
- `references/api/`: полный справочник Umbrella API v2 без разметки, по файлу на модуль. Его же использует проверка вызовов.
- `scripts/luatool.exe`: разбор Lua 5.4 и все операции скилла.
  - `new`: новый скрипт из шаблона.
  - `migrate`: перевод чужого скрипта на правила.
  - `check`: проверка синтаксиса, локализации, меню, вызовов API, необъявленных имен и имен способностей и предметов по данным игры.
  - `check --against <старый файл>`: какие имена в меню пропали, у них сбросятся настройки и бинды.
  - `check --log`: из `debug.log` ошибки скрипта, его собственные строки и ненайденные картинки.
  - `data`: способности, предметы, герои и юниты из `%cheat_dir%/assets/data`.
  - `version`: версия скилла.

Внутри утилиты вшита библиотека qLocalization (автор qfun).

## Исходники

`src/luatool` — исходники `luatool.exe` на C# 5. Exe в релизе собирается из них на GitHub Actions. Собрать самому можно встроенным в Windows компилятором:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1
```

---

# umbrella-lua (English)

A Claude Code and Codex skill that writes and fixes Lua scripts for Umbrella (Dota 2). Every script gets the same menu layout and built-in en/ru localization.

Install: download `umbrella-lua.zip` from the latest release, unzip it and put the `umbrella-lua` folder into `%USERPROFILE%\.claude\skills\` (Claude Code) or `%USERPROFILE%\.agents\skills\` (Codex), then restart the agent. To update, replace the whole folder.

Once a day `luatool.exe` asks GitHub for this repository's releases and prints an `UPDATE:` line when a newer version is out. It sends nothing else. Set `UMBRELLA_LUA_NO_UPDATE=1` to turn the check off.
