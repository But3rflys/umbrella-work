# umbrella-work

Lua-скрипты для Umbrella и приложение MusicUI.

<!-- scripts:ru:start -->
- [Lane Pull](scripts/lane_pull) — выпул вражеской волны крипом с Доминатора
- [DS Spot Block](scripts/ds_spot_block) — блок спота Вакуумом за Dark Seer
- [Custom Background](scripts/custom_background) — свои картинки на фоне меню
- [MusicUI](scripts/musicui) — оверлей плеера: трек, обложка, эквалайзер, текст
<!-- scripts:ru:end -->

В папке скрипта лежит его README: описание, установка и список всех версий со ссылками на файлы.

## Установка

Скрипт: скачай `.lua` из релиза, положи в папку `scripts` рядом с читом, включи в меню `Scripts`.
MusicUI: распакуй архив, `MusicUI.lua` в `scripts`, запусти `MusicUI.exe`.

Язык меню берется из языка чита, скрипты понимают русский и английский.

## Релизы

Тег вида `<скрипт>-v<версия>`:

```bash
git tag lane-pull-v1.0.4
git push origin lane-pull-v1.0.4
```

Workflow прикладывает к релизу `scripts/<скрипт>/<файл>`, тело берет из `CHANGELOG.md` и
`CHANGELOG.en.md` этого скрипта. MusicUI собирается отдельно по тегу `musicui-v*`: exe через
PyInstaller, в релиз уходит zip с exe, оверлеем и README.

Ссылки, которые не меняются от версии к версии:

- скрипт — `github.com/But3rflys/umbrella-work/tree/main/scripts/lane_pull`
- его релизы — `github.com/But3rflys/umbrella-work/releases?q=lane-pull&expanded=true`

## Что где

```
scripts/       скрипты, у каждого своя папка с README и CHANGELOG
musicui-app/   исходники MusicUI.exe на Python
lib/           сторонние библиотеки
dev/           отладочные скрипты, в релизы не идут
.github/       workflow-ы, генераторы README и статистика загрузок
```

## Спасибо

`lib/qlocalizer.lua` — библиотека qLocalization, автор qfun (qfun_g9s).

---

# English

Lua scripts for Umbrella and the MusicUI app.

<!-- scripts:en:start -->
- [Lane Pull](scripts/lane_pull) — pull the enemy wave with your Dominator creep
- [DS Spot Block](scripts/ds_spot_block) — Vacuum spot block for Dark Seer
- [Custom Background](scripts/custom_background) — your own pictures behind the menu
- [MusicUI](scripts/musicui) — player overlay: track, cover, equalizer, lyrics
<!-- scripts:en:end -->

Each script folder has its own README: what it does, how to install it, and every version with
direct file links.

## Install

Script: download the `.lua` from a release, drop it into the `scripts` folder next to your cheat,
turn it on under `Scripts`.
MusicUI: unzip the archive, put `MusicUI.lua` into `scripts`, run `MusicUI.exe`.

The menu follows your cheat language; the scripts speak Russian and English.

## Releases

Tags look like `<script>-v<version>`:

```bash
git tag lane-pull-v1.0.4
git push origin lane-pull-v1.0.4
```

The workflow attaches `scripts/<script>/<file>` and takes the release notes from that script's
`CHANGELOG.md` and `CHANGELOG.en.md`. MusicUI is built separately from a `musicui-v*` tag.

Links that stay the same across versions:

- the script — `github.com/But3rflys/umbrella-work/tree/main/scripts/lane_pull`
- its releases — `github.com/But3rflys/umbrella-work/releases?q=lane-pull&expanded=true`

## Credits

`lib/qlocalizer.lua` is the qLocalization library by qfun (qfun_g9s).

## Downloads

<!-- stats:start -->
| script | downloads | latest |
| --- | --- | --- |
| [Lane Pull](scripts/lane_pull) | 103 | `beta-v1.0.3` |
| [DS Spot Block](scripts/ds_spot_block) | 22 | `v1.0.1` |
| [MusicUI](scripts/musicui) | 310 | `v1.0.7` |

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/stats/stats-dark.svg">
  <img alt="Downloads over time" src=".github/stats/stats-light.svg" width="840">
</picture>

2026-09-20
<!-- stats:end -->
