# Releasing

Тег вида `<скрипт>-v<версия>`:

```bash
git tag lane-pull-v1.0.5
git push origin lane-pull-v1.0.5
```

`release.yml` находит скрипт в `catalog.json` по префиксу тега, создает релиз с телом из
`CHANGELOG.md` и `CHANGELOG.en.md` этого скрипта и прикладывает `scripts/<скрипт>/<файл>`.

MusicUI собирается вручную: exe и архив к релизу `musicui-v*` прикладываются руками, workflow
создает только сам релиз с описанием. Собрать exe локально:

```bash
cd musicui-app
pip install -r requirements.txt
python tools/build.py
```

`readme.yml` после релиза, раз в сутки и по кнопке пересчитывает загрузки и переписывает таблицы
версий в README скриптов и на страницах GitBook.

Описания скриптов и пути страниц лежат в `catalog.json`. Генераторы: `pages.py` — README и
страницы GitBook, `stats.py` — загрузки и график, `website.py` — статический сайт в `docs/`,
`release_notes.py` — тело релиза.
