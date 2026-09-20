# umbrella-work

Lua-скрипты для Umbrella и приложение MusicUI

## Скрипты

| скрипт | файл | описание |
| --- | --- | --- |
| `scripts/lane_pull/lane_pull.lua` | `lane_pull.lua` | выпул вражеской волны подконтрольным крипом |
| `scripts/ds_spot_block/ds_spot_block.lua` | `ds_spot_block.lua` | блок спота |
| `scripts/custom_background/custom_background.lua` | `custom_background.lua` | кастомный фон меню |
| `scripts/musicui/MusicUI.lua` | `MusicUI.lua` | оверлей плеера, Lua-часть |
| `musicui-app` | `MusicUI.exe` | бэкенд MusicUI на Python |
| `dev/` | — | отладочные скрипты, не релизятся |

`lib/qlocalizer.lua` — сторонняя библиотека qLocalization, автор qfun (qfun_g9s).

## Релиз

```bash
git tag lane-pull-v1.0.4
git push --tags
```

Тег вида `<имя-скрипта>-v<версия>` создаёт релиз: к нему прикладывается
`scripts/<имя>/<имя>.lua`, тело берётся из `scripts/<имя>/CHANGELOG.md`.
Если у скрипта есть папка `assets`, она уедет в релиз отдельным zip. Дефис в имени тега соответствует подчёркиванию в папке:
`ds-spot-block-v1.0.2` → `scripts/ds_spot_block`.

MusicUI собирается отдельно по тегу `musicui-v1.0.8`: exe через PyInstaller, в релиз уходит
zip с exe, оверлеем и README.

## Статистика загрузок

GitHub считает загрузки только у файлов, приложенных к релизу. Число суммарное, без разбивки
по дням, поэтому `.github/workflows/stats.yml` раз в сутки дописывает срез в `stats.jsonl`.

```bash
gh api repos/OWNER/REPO/releases --jq '.[].assets[] | "\(.name) \(.download_count)"'
```

## Загрузки

<!-- stats:start -->
| репозиторий | загрузок | последний релиз |
| --- | --- | --- |
| [Lane-Pull](https://github.com/But3rflys/Lane-Pull) | 98 | `beta-v1.0.3` — 13 |
| [DSSpot](https://github.com/But3rflys/DSSpot) | 21 | `v1.0.1` — 14 |
| [MusicUI](https://github.com/But3rflys/MusicUI) | 308 | `v1.0.7` — 20 |

```mermaid
xychart-beta
    title "Загрузки, всего"
    x-axis ["09-20"]
    y-axis "шт" 417 --> 437
    line [427]
```

_обновлено 2026-09-20, считаются только файлы из релизов_
<!-- stats:end -->
