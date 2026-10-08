---
icon: list-ol
---

# Draft Helper

Подсказки на драфте и сборка предметов: окно с героями под каждый ход, шанс на победу по драфту и сборка под твою роль против их пиков.

<!-- versions:start -->
**Скачать:** [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.13/draft_helper.lua) — `draft-helper-v2.0.0-beta.13`, 2026-10-08

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`draft-helper-v2.0.0-beta.13`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.13) | 2026-10-08 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.13/draft_helper.lua) | 0 |
| [`draft-helper-v2.0.0-beta.12`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.12) | 2026-10-08 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.12/draft_helper.lua) | 44 |
| [`draft-helper-v2.0.0-beta.11`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.11) | 2026-10-07 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.11/draft_helper.lua) | 136 |
| [`draft-helper-v2.0.0-beta.9`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.9) | 2026-10-07 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.9/draft_helper.lua) | 29 |
| [`draft-helper-v2.0.0-beta.8`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.8) | 2026-10-07 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.8/draft_helper.lua) | 2 |
| [`draft-helper-v2.0.0-beta.7`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.7) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.7/draft_helper.lua) | 3 |
| [`draft-helper-v2.0.0-beta.6`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.6) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.6/draft_helper.lua) | 3 |
| [`draft-helper-v2.0.0-beta.5`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.5) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.5/draft_helper.lua) | 6 |
| [`draft-helper-v2.0.0-beta.4`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.4) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.4/draft_helper.lua) | 8 |
| [`draft-helper-v2.0.0-beta.3`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.3) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.3/draft_helper.lua) | 7 |
| [`draft-helper-v2.0.0-beta.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.2) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.2/draft_helper.lua) | 2 |

</details>
<!-- versions:end -->

## Как работает

**Драфт.** Окно открывается на выборе героев в Captains Mode и All Pick. На каждый ход скрипт показывает список героев: что пикнуть, что забанить, что могут взять враги. Под героем видно, против кого и с кем он хорош. Сверху висит шанс на победу по текущему драфту. Список можно сузить до позиции, а в настройках выбрать, подбирать героя на игру или на линию против соперников по лейну.

**Статистика.** Данные берутся с OpenDota и обновляются раз в сутки: 200 тысяч рейтинговых матчей на каждый ранг (все, Легенда+, Властелин+, Божество+) и матчи Captains Mode за последние 90 дней. Скрипт сам скачивает их с GitHub.

**Сборка.** После драфта для каждого героя нашей команды есть сборка под его роль по играм 7000+ MMR: стартовый закуп, ранняя игра, середина и поздняя. Ниже идут ответы на их драфт: скади против лечения, нуллифаер против сейвов, дасты против невидимости. Таблица «Кто кого» показывает, на сколько процентов каждый наш герой меняет шанс против каждого вражеского.

**Панель в игре.** Рядом с магазином открывается маленькая панель сборки. ЛКМ закрепляет предмет в квикбае, Shift + ЛКМ заменяет квикбай, ПКМ покупает. Роль переключается в шапке панели, за шапку же панель перетаскивается.

**Тренировка.** Вне матча можно прогнать тренировочный драфт в Captains Mode или All Pick: за врага ходит скрипт по своим подсказкам или ты сам.

{% hint style="info" %}
В «Мой пул героев» можно отметить своих героев: они поднимаются выше в подсказках или остаются в списке только они.
{% endhint %}

## Установка

1. Скачай `draft_helper.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Scripts > Draft Helper** и включи **Включить**.
4. Назначь клавишу **Открыть окно**: без неё окно не открыть.
