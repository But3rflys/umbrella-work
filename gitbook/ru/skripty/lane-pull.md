---
icon: route
---

# Lane Pull

Крип с Доминатора по нажатию клавиши забирает вражескую волну и ведет ее к герою.

<!-- versions:start -->
**Скачать:** [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.4/lane_pull.lua) — `lane-pull-v1.0.4`, 2026-09-20

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`lane-pull-v1.0.4`](https://github.com/But3rflys/umbrella-work/releases/tag/lane-pull-v1.0.4) | 2026-09-20 | [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.4/lane_pull.lua) | 98 |
| [`lane-pull-v1.0.3`](https://github.com/But3rflys/umbrella-work/releases/tag/lane-pull-v1.0.3) | 2026-09-20 | [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.3/lane_pull.lua) | 7 |

</details>
<!-- versions:end -->

## Как работает

Первое нажатие клавиши запускает выпул, второе отменяет. Крип идет к волне, цепляет ее и ведет к герою: сам выбирает место встречи, обходит нейтральные лагеря и вражеских героев, ждет волну в деревьях. Если волна в тумане, он ждет ее по таймеру спавна.

Пулить умеют крипы с Доминатора и похожих предметов — кем именно, отмечается в меню. Между двумя подходящими выбирается здоровый: раненый остается дома.

{% hint style="warning" %}
Если враг подошел вплотную или у крипа упало здоровье ниже порога, выпул отменяется и крип возвращается к герою.
{% endhint %}

## Установка

1. Скачай `lane_pull.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Scripts** в меню чита и включи скрипт.

<!-- changelog:start -->
## Что нового

**update v1.0.4**

* **выпул пачки.** улучшена логика выпула пачки
<!-- changelog:end -->
