---
icon: bullseye
---

# DS Spot Block

Блок спота Вакуумом за Dark Seer: скрипт рисует лагеря, радиус Вакуума и точку каста, а по клавише сам подходит и кастует.

<!-- versions:start -->
**Скачать:** [ds_spot_block.lua](https://github.com/But3rflys/umbrella-work/releases/download/ds-spot-block-v1.0.1/ds_spot_block.lua) — `ds-spot-block-v1.0.1`, 2026-09-20

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`ds-spot-block-v1.0.1`](https://github.com/But3rflys/umbrella-work/releases/tag/ds-spot-block-v1.0.1) | 2026-09-20 | [ds_spot_block.lua](https://github.com/But3rflys/umbrella-work/releases/download/ds-spot-block-v1.0.1/ds_spot_block.lua) | 0 |

</details>
<!-- versions:end -->

## Как работает

Скрипт показывает ближайшие кемпы и все, что нужно для блока: радиус Вакуума, точку каста и место, где должен стоять герой. По клавише герой подходит на нужную дистанцию и кастует, когда выполнено условие по крипам. Работает только когда крипы лагеря видны.

## Настройки

Меню чита: **Heroes → Dark Seer → Spot Block**.

### Каст

<table><thead><tr><th width="230">Параметр</th><th>Описание</th></tr></thead><tbody><tr><td><code>Включить</code></td><td>Включает и выключает скрипт.</td></tr><tr><td><code>Клавиша</code></td><td>Подход и каст по нажатию. Работает, только если крипы видны.</td></tr><tr><td><code>Условие</code></td><td>Когда кастовать: все крипы, сильнейший, любой крип или без условия.</td></tr><tr><td><code>Авто-подход</code></td><td>Герой сам идет к точке каста, если стоит слишком далеко.</td></tr><tr><td><code>Дистанция подхода</code></td><td>С какого расстояния начинать подход перед кастом.</td></tr><tr><td><code>Агр крипов</code></td><td>Агрит крипов лагеря по клавише.</td></tr></tbody></table>

### Вид

<table><thead><tr><th width="230">Параметр</th><th>Описание</th></tr></thead><tbody><tr><td><code>Значки над кемпами</code></td><td>Иконки лагерей на карте. Настраиваются размер значка и высота над кемпом.</td></tr><tr><td><code>Радиус Vacuum</code></td><td>Круг радиуса способности вокруг точки каста.</td></tr><tr><td><code>Точка каста</code></td><td>Куда именно уйдет Вакуум.</td></tr><tr><td><code>Кольца на крипах</code></td><td>Подсветка крипов, которые попадут в Вакуум.</td></tr><tr><td><code>Позиция героя</code></td><td>Место, где должен стоять герой для блока.</td></tr><tr><td><code>Видно с расстояния</code></td><td>С какого расстояния рисовать разметку лагеря.</td></tr><tr><td><code>Свечение полоски</code></td><td>Подсветка полоски здоровья у нужных крипов.</td></tr></tbody></table>

## Установка

1. Скачай `ds_spot_block.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Heroes → Dark Seer → Spot Block** и включи скрипт.
