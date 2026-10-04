---
icon: chess
---

# Draft Helper

Помощник драфта: кого пикнуть и кого забанить по контрпикам и синергии, готовая сборка против вражеского пика и панель сборки в игре.

<!-- versions:start -->
**Скачать:** [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.5.0/draft_helper.lua) — `draft-helper-v1.5.0`, 2026-10-02

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`draft-helper-v1.5.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.5.0) | 2026-10-02 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.5.0/draft_helper.lua) | 147 |
| [`draft-helper-v1.4.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.2) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.2/draft_helper.lua) | 5 |
| [`draft-helper-v1.4.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.1) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.1/draft_helper.lua) | 1 |
| [`draft-helper-v1.4.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.0) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.0/draft_helper.lua) | 65 |
| [`draft-helper-v1.2.8`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.8) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.8/draft_helper.lua) | 112 |
| [`draft-helper-v1.2.7`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.7) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.7/draft_helper.lua) | 57 |
| [`draft-helper-v1.2.6`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.6) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.6/draft_helper.lua) | 24 |
| [`draft-helper-v1.2.5`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.5) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.5/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.4`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.4) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.4/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.3`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.3) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.3/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.2) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.2/draft_helper.lua) | 4 |
| [`draft-helper-v1.2.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.1) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.1/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.0) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.0/draft_helper.lua) | 2 |
| [`draft-helper-v1.1.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.1.1) | 2026-09-29 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.1.1/draft_helper.lua) | 2 |
| [`draft-helper-v1.1.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.1.0) | 2026-09-29 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.1.0/draft_helper.lua) | 1 |

</details>
<!-- versions:end -->

## Окно драфта

Открывается клавишей или само на выборе героев. Показывает пики и баны обеих команд и советует, кого пикнуть и кого забанить. Советы строятся на контрпиках к врагам и синергии с союзниками по статистике OpenDota: рейтинговые матчи выбранного ранга или Captains Mode.

* **По очереди** для Captains Mode: все 24 хода по порядку.
* **Свободный** для алл пика, турбо и рейтинга: пики и баны подтягиваются сами.
* Позиции от 1 до 5 у своей команды и фильтр по позиции.
* Шанс победы по драфту.

## Итог драфта

Когда все герои выбраны, появляется таблица «кто кого» и сборка предметов для выбранного героя. Сборка берётся из про-матчей героя на его позиции и подстраивается под вражеский пик. Позицию можно переключить кнопками под сборкой.

## Панель сборки в игре

Показывает следующий предмет, сколько золота не хватает и очередь покупок. Если враг купил Butterfly, Ghost Scepter и подобное, панель предложит предмет, который против этого поможет. Три вида на выбор: Полоса, Список, Плашка. Клик по предмету добавляет его в квикбай.

{% hint style="info" %}
Все настройки внутри окна, под шестерёнкой в заголовке. Когда выходит новая версия, в заголовке окна появляется кнопка «Обновить».
{% endhint %}

## Установка

1. Скачай `draft_helper.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Scripts > Draft Helper**, включи скрипт и назначь клавишу **Открыть окно**.
