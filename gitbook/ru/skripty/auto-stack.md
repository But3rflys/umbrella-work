---
icon: layer-group
---

# Auto Stack

Автостак за Kunkka и Invoker: в нужную секунду каждой минуты скрипт сам кидает Torrent или Tornado по кемпу, и крипы оказываются выше кемпа в момент спавна.

<!-- versions:start -->
**Скачать:** [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) — `auto-stack-v1.1.0`, 2026-09-28

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`auto-stack-v1.1.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.1.0) | 2026-09-28 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) | 0 |
| [`auto-stack-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.0.0) | 2026-09-27 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) | 12 |

</details>
<!-- versions:end -->

## Как работает

**Kunkka.** Секунда каста подобрана под каждый кемп карты, скрипт учитывает пинг и ставит Torrent так, чтобы задеть всех крипов в кемпе.

**Invoker.** Торнадо качает крипов вверх-вниз, поэтому скрипт считает момент, когда все задетые крипы окажутся выше кемпа. Дальность и время в воздухе берутся по уровню Quas и Wex. Если включить **Создавать торнадо**, скрипт сам соберет его перед броском.

Стакать можно самому скрипту или по клавише: ближайший кемп или кемп под курсором. Над кемпами висят кольца, клик по кольцу включает и выключает кемп. Над выбранным кемпом видно отсчет до каста, а после минуты пишет, стакнулось или нет и почему.

{% hint style="warning" %}
Стак не пройдет, если в кемпе стоит герой или чужой юнит, или если задеты не все крипы.
{% endhint %}

## Установка

1. Скачай `auto_stack.lua` из последнего релиза.
2. Положи файл в папку `scripts` рядом с читом.
3. Открой **Heroes > Kunkka** или **Heroes > Invoker** и включи **Авто-стак**.

<!-- changelog:start -->
## Что нового

**update v1.1.0**

* **инвокер.** стак кемпов торнадо, по желанию сам создаёт торнадо перед броском
* **запуск.** у некоторых пользователей скрипт не запускался, исправлено
<!-- changelog:end -->
