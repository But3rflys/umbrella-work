---
icon: code
---

# umbrella-lua

Скилл для Claude Code и Codex: агент пишет и правит Lua-скрипты Umbrella по общим правилам. Меню собирается по одному эталону, локализация en/ru встроена в каждый скрипт.

<!-- versions:start -->
**Скачать:** [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.3/umbrella-lua.zip) — `umbrella-lua-v1.0.3`, 2026-09-24

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`umbrella-lua-v1.0.3`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.3) | 2026-09-24 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.3/umbrella-lua.zip) | 12 |
| [`umbrella-lua-v1.0.2`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.2) | 2026-09-24 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.2/umbrella-lua.zip) | 1 |
| [`umbrella-lua-v1.0.1`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.1) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.1/umbrella-lua.zip) | 21 |
| [`umbrella-lua-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.0) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.0/umbrella-lua.zip) | 7 |

</details>
<!-- versions:end -->

## Что умеет

* пишет новые скрипты с меню по эталону и встроенным qLocalizer;
* переводит чужой скрипт на правила: плоские ключи без точек, словари en и ru, обертка меню;
* проверяет синтаксис так же, как Lua 5.4, и сверяет вызовы со справочником Umbrella API;
* берет имена способностей, время каста и их значения из данных игры, а не по памяти;
* показывает ошибки скрипта из `debug.log` после перезагрузки скриптов.

## Установка

1. Скачай `umbrella-lua.zip` из последнего релиза и распакуй.
2. Положи папку `umbrella-lua` в `%USERPROFILE%\.claude\skills\` (Claude Code) или в `%USERPROFILE%\.agents\skills\` (Codex).
3. Перезапусти агента.

{% hint style="info" %}
Нужны Windows 10 или 11. Python и Lua не требуются: утилита `luatool.exe` работает на встроенном .NET Framework 4.
{% endhint %}

## Как пользоваться

Попроси агента написать или поправить скрипт Umbrella, скилл включится сам. Явный вызов: `/umbrella-lua` в Claude Code, `$umbrella-lua` в Codex. Удобнее всего открывать агента в папке `scripts` чита: тогда он сразу работает с твоими скриптами.

## Обновление

Раз в день `luatool.exe` проверяет релизы на GitHub. Когда выходит новая версия, агент сообщает об этом и дает ссылку. Для обновления замени папку `umbrella-lua` целиком. Отключить проверку можно переменной окружения `UMBRELLA_LUA_NO_UPDATE=1`.

`luatool.exe` собирается на GitHub Actions из исходников, они лежат [в репозитории](https://github.com/But3rflys/umbrella-work/tree/main/skill) вместе с описанием сборки.

<!-- changelog:start -->
## Что нового

**update v1.0.3**

* **данные игры.** новая команда `luatool data`: способности, предметы, герои и юниты прямо из файлов игры. имена, время каста, кулдауны и спецзначения агент берет оттуда, а не по памяти
* **имена.** check сверяет имена способностей, предметов, героев и ключи спецзначений с данными игры и при опечатке подсказывает правильное
* **лог.** `check --log` кроме ошибок показывает строки самого скрипта и картинки, которые не загрузились
<!-- changelog:end -->
