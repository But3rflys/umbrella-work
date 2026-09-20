# Lane Pull

выпул вражеской волны крипом с Доминатора / pull the enemy wave with your Dominator creep

<!-- releases:start -->
Скачать: [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.3/lane_pull.lua) — `lane-pull-v1.0.3`, 2026-09-20

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`lane-pull-v1.0.3`](https://github.com/But3rflys/umbrella-work/releases/tag/lane-pull-v1.0.3) | 2026-09-20 | [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.3/lane_pull.lua) | 0 |

[Все релизы](https://github.com/But3rflys/umbrella-work/releases?q=lane-pull&expanded=true)
<!-- releases:end -->

## Что умеет

По клавише подконтрольный крип уходит за вражеской волной и ведет ее к герою.

- три режима выбора волны: к герою, к нашему крипу, у курсора
- сам выбирает место встречи: перед вышкой, за вышкой или ближе к герою
- не берет волну, которая вот-вот сойдется с нашими крипами
- обходит нейтральные лагеря и вражеских героев
- ждет волну в деревьях, меняет укрытие, если его увидели
- работает на миде через реку и на хайграунде
- отмена по HP, по второму нажатию и при герое вплотную
- панель статуса и отладочный оверлей

## Установка

1. Скачай `lane_pull.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой `Scripts` в меню чита и включи скрипт.

Язык меню берется из языка чита, скрипт понимает русский и английский.

## Что нового

**update v1.0.3**

- **сам выбирает место.** новый режим: уводит крипа за вражескую вышку - так волна не успевает дойти до наших. ближе берет, только если точно успевает. старые режимы на месте
- **не пулит в наш вейв.** не берет волну, которая вот-вот сойдется с нашими крипами, и ждет следующую
- **обход лагерей.** ведет пачку мимо кемпов, чтобы она не сагрила нейтралов
- **хайграунд.** если бьют только дальники, больше не стоит афк
- **пачка целее.** на хг крипы больше не теряются
- **мид.** больше не теряется у реки и не бегает туда-сюда
- **оптимизация.** код стал чище и легче: меньше лишних пересчетов на каждом тике

---

# Lane Pull (English)

## What it does

One key and your dominated creep goes for the enemy wave and drags it to you.

- three ways to pick a wave: closest to you, to your creep, or by cursor
- picks the catch spot itself: in front of their tower, behind it, or closer to you
- skips a wave that is about to meet your own creeps
- walks around neutral camps and enemy heroes
- waits in the trees, changes cover once spotted
- works on mid across the river and on the high ground
- aborts on low HP, on a second key press, and when a hero gets close
- status bar and a debug overlay

## Install

1. Download `lane_pull.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open `Scripts` in the cheat menu and turn it on.

The menu follows your cheat language; the script speaks Russian and English.

## Changelog

**update v1.0.3**

- **picks the spot itself.** new mode: takes the creep behind the enemy tower, so the wave never reaches ours. it only catches closer when it surely makes it. the old modes are still there
- **no pulling into our wave.** skips a wave that is about to meet our own creeps and waits for the next one
- **camps avoided.** leads the pack past the neutral camps so it does not aggro them
- **high ground.** no longer stands afk when only the ranged creeps are hitting
- **the pack stays whole.** creeps no longer get lost on the high ground
- **mid.** no longer loses itself at the river or walks back and forth
- **optimization.** cleaner and lighter code: fewer recalculations every tick

