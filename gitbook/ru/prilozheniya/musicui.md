---
icon: music
---

# MusicUI

Оверлей плеера в игре: трек, обложка, эквалайзер и текст песни. Состоит из двух частей — Lua-оверлея и приложения `MusicUI.exe`.

{% hint style="danger" %}
Скрипт не совместим с Яндекс Браузером.
{% endhint %}

<!-- versions:start -->
**Скачать:** [MusicUI.rar](https://github.com/But3rflys/umbrella-work/releases/download/musicui-v1.0.8/MusicUI.rar) — `musicui-v1.0.8`, 2026-09-23

<details>

<summary>Все версии</summary>

| Версия | Дата | Файл | Загрузок |
| --- | --- | --- | --- |
| [`musicui-v1.0.8`](https://github.com/But3rflys/umbrella-work/releases/tag/musicui-v1.0.8) | 2026-09-23 | [MusicUI.rar](https://github.com/But3rflys/umbrella-work/releases/download/musicui-v1.0.8/MusicUI.rar) | 0 |
| [`musicui-v1.0.7`](https://github.com/But3rflys/umbrella-work/releases/tag/musicui-v1.0.7) | 2026-09-20 | [MusicUI.rar](https://github.com/But3rflys/umbrella-work/releases/download/musicui-v1.0.7/MusicUI.rar) | 203 |

</details>
<!-- versions:end -->

## Как работает

Приложение читает, что играет в Spotify или системном плеере Windows, и отдает данные оверлею. Оверлей рисует в игре карточку трека с обложкой и прогрессом, эквалайзер по реальному звуку и текст песни с прокруткой. Воспроизведением можно управлять прямо из оверлея.

{% hint style="warning" %}
Без запущенного `MusicUI.exe` оверлей пустой: данные о треке берутся из приложения.
{% endhint %}

## Установка

1. Скачай архив из последнего релиза и распакуй в любое место.
2. Положи `MusicUI.lua` в папку `scripts` рядом с читом.
3. Запусти `MusicUI.exe` и следуй подсказкам в консоли.
4. Открой **Scripts** в меню чита и включи оверлей.

Язык консоли берется из языка Windows. Принудительно: `MusicUI.exe --lang ru` или `--lang en`.

## Источники звука

<table><thead><tr><th width="230">Источник</th><th>Что дает</th></tr></thead><tbody><tr><td>Spotify</td><td>Трек, исполнитель, обложка, прогресс, управление воспроизведением.</td></tr><tr><td>Системный плеер Windows</td><td>То же самое для любого плеера, который сообщает о себе Windows.</td></tr></tbody></table>

<!-- changelog:start -->
<!-- changelog:end -->
