---
icon: layer-group
---

# Auto Stack

Автостак за Kunkka: в нужную секунду каждой минуты скрипт сам кидает Torrent по кемпу, чтобы крипы были в воздухе в момент спавна.

<!-- versions:start -->
**Скачать:** [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) — `auto-stack-v1.0.0`, 2026-09-27

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`auto-stack-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.0.0) | 2026-09-27 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) | 0 |

</details>
<!-- versions:end -->

## Как работает

Секунда каста подобрана под каждый кемп карты, скрипт учитывает пинг и выбирает точку торрента так, чтобы задеть всех крипов в кемпе. Можно стакать самому скрипту или по клавише: ближайший кемп или кемп под курсором. Над кемпами висят кольца, клик по кольцу включает и выключает кемп. Над выбранным кемпом видно отсчет до каста, а после минуты — стакнулось или нет и почему.

{% hint style="warning" %}
Стак не пройдет, если в кемпе стоит герой или чужой юнит, или если торрент задел не всех крипов.
{% endhint %}

## Установка

1. Скачай `auto_stack.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Heroes → Kunkka** и включи **Авто-стак**.
