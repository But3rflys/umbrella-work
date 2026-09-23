---
name: umbrella-lua
description: Пишет и правит Lua-скрипты для Umbrella (Dota 2) по общим правилам. Меню собирается по эталону, локализация qLocalizer (en и ru) обязательна, под рукой сжатый справочник Umbrella API v2. Use when the user asks to write, fix or extend an Umbrella script or a Dota 2 Lua script for Umbrella, build or restyle its menu, add localization, or asks how an Umbrella API call works (Menu, NPC, Entity, Render, Enum, callbacks).
---

# Скрипты Umbrella

Umbrella исполняет Lua 5.4. Скрипт это файл `.lua` в папке `%cheat_dir%/scripts`. Он возвращает таблицу колбэков. Папка Umbrella у каждого пользователя своя. Если в текущей рабочей папке лежат его скрипты, работай в ней, иначе спроси путь. Не угадывай путь и не вписывай абсолютные пути в код.

Ниже `<skill>` означает папку этого скилла. Вся механика делается утилитой `<skill>/scripts/luatool.exe`: она работает в любой Windows 10/11 без Python и Lua. Вызов из Bash или PowerShell одинаковый: `& "<skill>/scripts/luatool.exe" <команда> "<файл>"` (в Bash без `&`). Если кириллица в выводе превратилась в кракозябры, в PowerShell перед вызовом выполни `[Console]::OutputEncoding = [Text.Encoding]::UTF8`.

## Порядок работы

1. Новый скрипт: `luatool.exe new "<scripts>/<имя>.lua" --title "<Имя в меню>" --prefix <2-3 буквы>`. В файле уже встроен qLocalizer и меню по эталону. `--title` и `--prefix` можно не указывать, тогда они берутся из имени файла.
2. Чужой или старый скрипт: `luatool.exe migrate "<файл>" --prefix <2-3 буквы>`. Утилита встраивает qLocalizer, разворачивает ключи с точками в плоские и меняет их по всему коду, включая собираемые через `..`. Она выносит текст меню в словарь, убирает ручной `Wrap` и ставит `WrapLibrary(Menu)`. Повторный запуск ничего не меняет. Логику скрипта не трогай. Разбери отчет:
   - `NEED`: допиши переводы на этот язык;
   - `MANUAL`: реши вручную;
   - `DYNAMIC`: ключ собирается в коде, проверь его.
3. Первые ~318 строк файла занимает библиотека qLocalizer, их не читай и не меняй. Утилита печатает строку, с которой начинается код скрипта (`BODY starts at line`): читай файл начиная с нее.
4. Сигнатуры бери только из `references/api/`, не по памяти. У Umbrella свой API: он не совпадает ни с серверным Lua API Valve, ни с API других читов. Функции игры вызываются через модуль: `NPC.GetMana(npc)`, `Entity.GetAbsOrigin(unit)`, `Ability.CastPosition(ability, pos)`. Запись `npc:GetMana()` не работает. Через двоеточие вызываются только методы объектов меню и `Vector`, `Vec2`, `Angle`, `Color`.
5. После каждой правки: `luatool.exe check "<файл>"`. Синтаксис проверяется точно как в Lua 5.4, включая лимит в 200 локальных. Кроме того, проверка сверяется со справочником и ловит:
   - несуществующие функции и значения `Enum` (с подсказкой похожего имени);
   - неверное число аргументов;
   - опечатки в названиях колбэков;
   - неизвестные методы меню;
   - ключи без перевода и точки в именах пунктов;
   - пункты, созданные мимо обертки перевода;
   - длинные тире.
   Все `WARN` исправь. `INFO` только для сведения.
6. Тестирует пользователь в игре. Моки, симуляции и тестовые прогоны не пиши. Когда пользователь перезагрузил скрипты и что-то не работает, запусти `luatool.exe check "<файл>" --log`: команда покажет ошибки этого скрипта из `%cheat_dir%/debug.log` после последней перезагрузки. Правки строй по его наблюдениям из игры.
7. Если утилита напечатала строку `UPDATE:`, в конце ответа один раз скажи пользователю, что вышла новая версия скилла, и дай ссылку из этой строки.

## Обязательные правила

- Локализация есть в каждом скрипте: qLocalizer встроен в файл, меню создается через `UI = localization.WrapLibrary(Menu)`, весь видимый текст задается ключами, словари `en` и `ru`. Подробно в `references/localization.md`.
- В именах пунктов, групп, вкладок и в ключах нет точек, только `_`. Umbrella считает точку разделителем пути в `gui.json`, и после перезахода настройки сбрасываются.
- Меню собирается по эталону из `references/menu.md`: две колонки групп, глиф FontAwesome у каждого пункта, подсказки, второстепенное в шестеренке (`widget:Gear(key)`), зависимые пункты гаснут через `:Disabled`.
- Текст и внешний вид по `references/style.md`: подсказки в 1-2 строки, отрисовка без украшательств.
- Код без поясняющих комментариев, объяснения даются в ответе.
- В главном блоке файла Lua допускает не больше 200 локальных. Состояние держи в таблицах (`ui`, `state`, `K`), меню и отрисовку оборачивай в `do ... end`.
- `OnUpdate` (логика) и `OnDraw` (отрисовка) работают только в матче. То, что нужно и в главном меню, делай в `OnFrame` (отрисовка) и `OnUpdateEx` (логика).
- Тяжелую логику ограничивай интервалом по `GameRules.GetGameTime()`.
- Отладочный лог пиши через `Log.Write("[Имя] ...")` только под переключателем отладки и только при смене состояния, не каждый кадр. `print` и `Log.Write` сами превращают таблицы в текст.
- Юнитам отдавай нативный приказ (`NPC.MoveTo`, каст, атака), путь движок строит сам. Не проверяй путь заранее через `GridNav.BuildPath`/`IsTraversableFromTo`: они дают ложное «пути нет». У любого цикла приказов должен быть выход.

## Справочник API

`references/api/<Модуль>.md`: полная документация Umbrella API v2 без разметки. Строка на функцию с типами и значениями по умолчанию, под ней описание, пояснения к параметрам и примеры. Сначала ищи имя функции поиском по этой папке (Grep, rg или Select-String). Файл целиком читай, только когда нужен обзор модуля. `Enums.md` большой, в нем ищи только поиском по `Enum.<Имя>`.

| Тема | Файлы |
| --- | --- |
| Стартовый гайд и два полных примера скриптов из документации | Guide |
| Колбэки скрипта и их данные | Callbacks |
| Меню, виджеты, шестеренки | Menu (на частые случаи хватит `references/menu.md`) |
| Юниты и герои | NPC, Entity, Hero, Heroes, NPCs, Entities, Player, Players |
| Способности, предметы, модификаторы | Ability, Item, Modifier, Abilities, Modifiers |
| Отрисовка | Render (основной), Renderer (старый), Particle, MiniMap, Panorama, UIPanel |
| Игра и ввод | Engine, GameRules, GlobalVars, Input, GridNav, World, FogOfWar, ConVar, Event |
| Математика и цвет | Vector, Vec2, Angle, Vertex, Color |
| Объекты карты | Camps, Camp, Towers, Tower, Trees, Tree, TempTrees, Runes, Rune, Couriers, Courier, PhysicalItems, PhysicalItem, LinearProjectiles, CustomEntities |
| Отдельные предметы | Bottle, PowerTreads, Vambrace, TierToken, DrunkenBrawler |
| Утилиты | Config, Log, Logger, Localizer, GameLocalizer, Humanizer, StringBuilder, Chronos, table |
| Сеть | HTTP, Chat, Steam, NetChannel, GameCoordinator, Protobuf |

## Где поведение расходится с документацией

- `Render.PolyLine` замыкает контур: последняя точка соединяется с первой. Для открытой кривой либо держи концы на одной высоте, либо выведи последние точки за `Render.PushClip`.
- `Config.Write*` пишет не в `configs/*.ini`, как сказано в документации, а в `%cheat_dir%/db.json` под ключом `"<config>.<key>"`. Настройки меню лежат в `%cheat_dir%/gui.json`.
- `Log.Write` и `print` пишут в `%cheat_dir%/debug.log`. Туда же попадают ошибки Lua (`[Lua Error]`) и перезагрузки (`Reload ScriptSystem`).
- Combo сохраняет выбор текстом, MultiSelect хранит галочки по `id`. Подробности в `references/localization.md`.
- `GridNav.IsTraversable` не видит деревья. Проверяй их через `Trees.InRadius(pos, r, true)` и `TempTrees.InRadius(pos, r)`.
- `Render.SetGlobalAlpha` при затухании делает `Render.Blur` черным, поэтому альфу задавай каждому элементу. `Render.Shadow` рисует прямоугольную тень.
- Картинки из игры лежат по путям `panorama/images/<папка>/<имя>_png.vtex_c`. Иконка способности не всегда называется как способность. Маленькие иконки героев: `panorama/images/heroes/icons/<NPC.GetUnitName(hero)>_png.vtex_c`. Если в пути не уверен, поставь глиф FontAwesome или спроси пользователя.
