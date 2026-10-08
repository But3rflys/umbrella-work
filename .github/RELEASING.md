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
версий в README скриптов.

Описания скриптов лежат в `catalog.json`. Генераторы: `pages.py` — README скриптов, `stats.py` —
загрузки и график, `release_notes.py` — тело релиза, `site.py` — сайт.

## Сайт

https://but3rflys.github.io/umbrella-work/

`site.yml` собирает сайт из `site/index.html` через `site.py` и выкладывает на GitHub Pages: после
каждого `readme.yml`, при изменении сайта, `catalog.json`, статистики, превью или ченджлогов и по
кнопке. Описания берутся из `catalog.json`, версии и загрузки из `.github/stats/stats.jsonl`,
«Что нового» из `CHANGELOG.md` и `CHANGELOG.en.md`, превью из `.github/previews/<id>.png`.

## Скилл umbrella-lua

Перед релизом:

1. Номер версии в `skill/src/luatool/AssemblyInfo.cs` (`AssemblyVersion` и `AssemblyFileVersion`)
   и в строке `Версия **x.y.z**` в `skill/README.md`.
2. `skill/CHANGELOG.md` и `skill/CHANGELOG.en.md`: только эта версия, формат как у скриптов.
3. Коммит, потом тег `umbrella-lua-v<версия>`:

```bash
git tag umbrella-lua-v1.0.2
git push origin umbrella-lua-v1.0.2
```

`skill.yml` собирает `luatool.exe` на Windows из `skill/src` и останавливается, если версия в exe или
в `skill/README.md` не совпадает с тегом. Потом упаковывает папку `skill/umbrella-lua` в
`umbrella-lua.zip`, создает релиз с телом из обоих ченджлогов и запускает `readme.yml`.

Загрузки скилла идут в общий график, но не в таблицу скриптов: скилл описан в `catalog.json` отдельно
от `scripts`. `pages.py` сам переписывает блоки `<!-- releases:start -->` в `skill/README.md`. Руками его не трогать.
