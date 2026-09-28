# Auto Stack

автостак кемпов за Кунку и Инвокера / camp stacking for Kunkka and Invoker

<!-- releases:start -->
Скачать: [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) — `auto-stack-v1.1.0`, 2026-09-28

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`auto-stack-v1.1.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.1.0) | 2026-09-28 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) | 0 |
| [`auto-stack-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.0.0) | 2026-09-27 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) | 12 |

[Все релизы](https://github.com/But3rflys/umbrella-work/releases?q=auto-stack&expanded=true)
<!-- releases:end -->

## Что умеет

Кунка кидает Torrent, Инвокер кидает Tornado по кемпу в нужную секунду каждой минуты.

- Кунка: секунда каста подобрана под каждый кемп карты, с поправкой на пинг
- Инвокер: считает, когда торнадо поднимет крипов выше кемпа, по уровню Quas и Wex и пингу
- бросок выбирается так, чтобы задеть всех крипов в кемпе
- за Инвокера может сам создать торнадо перед броском
- четыре режима: сам, сам с клавишей вкл/выкл, по клавише ближайший кемп или кемп под курсором
- кольца над кемпами, клик включает и выключает кемп
- статус над кемпом: отсчет до каста, КД, мана, итог стака и причина, если не вышло

## Установка

1. Скачай `auto_stack.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой `Scripts` в меню чита и включи скрипт.

Язык меню берется из языка чита, скрипт понимает русский и английский.

## Что нового

**update v1.1.0**

- **инвокер.** стак кемпов торнадо, по желанию сам создаёт торнадо перед броском
- **ошибка при запуске.** скрипт больше не падает, если другой скрипт подменил Config

---

# Auto Stack (English)

## What it does

Kunkka throws Torrent, Invoker throws Tornado on a camp at the right second of every minute.

- Kunkka: the cast second is tuned for every camp on the map, with ping compensation
- Invoker: works out when Tornado lifts the creeps above the camp, from Quas, Wex and ping
- the throw is aimed to hit every creep in the camp
- as Invoker it can invoke Tornado right before the throw
- four modes: automatic, automatic with an on/off key, key on the nearest camp or the camp under the cursor
- rings over the camps, click one to turn that camp on or off
- status over the camp: countdown, cooldown, mana, stack result and why it failed

## Install

1. Download `auto_stack.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open `Scripts` in the cheat menu and turn it on.

The menu follows your cheat language; the script speaks Russian and English.

## Changelog

**update v1.1.0**

- **invoker.** stacks camps with tornado, can invoke it right before the throw
- **startup error.** the script no longer crashes when another script replaces Config

