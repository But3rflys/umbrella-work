# Releasing

Тег вида `<скрипт>-v<версия>`:

```bash
git tag lane-pull-v1.0.4
git push origin lane-pull-v1.0.4
```

`release.yml` находит скрипт в `catalog.json` по префиксу тега, прикладывает к релизу
`scripts/<скрипт>/<файл>`, тело берет из `CHANGELOG.md` и `CHANGELOG.en.md` этого скрипта.

MusicUI собирается по тегу `musicui-v*` в `release-musicui.yml`: exe через PyInstaller, в релиз
уходит zip с exe, оверлеем и README.

`readme.yml` после релиза, раз в сутки и по кнопке пересчитывает загрузки и переписывает таблицы
версий в README скриптов.

Описания скриптов и иконки лежат в `catalog.json`. Генераторы: `pages.py` — README,
`stats.py` — загрузки и график, `website.py` — статический сайт, `release_notes.py` — тело релиза.
