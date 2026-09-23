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

Описания скриптов лежат в `catalog.json`. Генераторы: `pages.py` — README скриптов и страницы
GitBook, `stats.py` — загрузки и график, `release_notes.py` — тело релиза.

## Что обновляется само

`readme.yml` после релиза, раз в сутки и по кнопке запускает `pages.py` и `stats.py`. Они
переписывают в обоих пространствах GitBook два блока на каждой странице скрипта:

- `<!-- versions:start -->` — ссылка на свежий файл и таблица всех версий с загрузками
- `<!-- changelog:start -->` — текст из `CHANGELOG.md` (русский) и `CHANGELOG.en.md` (английский)

Страницы ищутся по имени файла в любой папке `gitbook/ru` и `gitbook/en`, поэтому переименование
групп в GitBook ничего не ломает. Все остальное на страницах правится руками — хоть в репозитории,
хоть прямо в GitBook.

## Скилл umbrella-lua

Тег `umbrella-lua-v<версия>`. Версия должна совпадать с `skill/src/luatool/AssemblyInfo.cs` и со
строкой `Версия **x.y.z**` в `skill/README.md`, иначе `skill.yml` остановится.

`skill.yml` собирает `luatool.exe` на Windows из `skill/src`, упаковывает папку `skill/umbrella-lua`
в `umbrella-lua.zip`, создает релиз и запускает `readme.yml`. Текст «Что нового» берется из
`skill/CHANGELOG.md`, если он есть. Загрузки скилла идут в общий график, но не в таблицу скриптов:
скилл описан в `catalog.json` отдельно от `scripts`. Таблица версий с загрузками стоит в
`skill/README.md`, ее переписывает `pages.py`.
