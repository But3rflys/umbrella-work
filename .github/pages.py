import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
REPO = CATALOG["repo"]
NL = chr(10)

START, END = "<!-- releases:start -->", "<!-- releases:end -->"
CAT_RU_START, CAT_RU_END = "<!-- scripts:ru:start -->", "<!-- scripts:ru:end -->"
DOC_START, DOC_END = "<!-- versions:start -->", "<!-- versions:end -->"
LOG_START, LOG_END = "<!-- changelog:start -->", "<!-- changelog:end -->"
CAT_EN_START, CAT_EN_END = "<!-- scripts:en:start -->", "<!-- scripts:en:end -->"

INSTALL = {
    "lua": {
        "ru": ["Скачай `%(file)s` из последнего релиза.",
               "Положи файл в папку `scripts` рядом с читом.",
               "Открой `Scripts` в меню чита и включи скрипт."],
        "en": ["Download `%(file)s` from the latest release.",
               "Put the file into the `scripts` folder next to your cheat.",
               "Open `Scripts` in the cheat menu and turn it on."],
    },
    "app": {
        "ru": ["Скачай `%(file)s` из последнего релиза и распакуй.",
               "Положи `MusicUI.lua` в папку `scripts` рядом с читом.",
               "Запусти `MusicUI.exe` и следуй подсказкам в консоли."],
        "en": ["Download `%(file)s` from the latest release and unzip it.",
               "Put `MusicUI.lua` into the `scripts` folder next to your cheat.",
               "Run `MusicUI.exe` and follow the prompts in the console."],
    },
}


def api(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print("releases unavailable: %d" % e.code)
        return []


def releases():
    return [r for r in api("https://api.github.com/repos/%s/releases?per_page=100" % REPO)
            if not r.get("draft")]


def for_script(script, rels):
    prefix = script["tag"] + "-v"
    mine = [r for r in rels if r["tag_name"].startswith(prefix)]
    mine.sort(key=lambda r: r.get("published_at") or "", reverse=True)
    return mine


def asset_of(rel, script):
    wanted = script["file"].lower()
    for a in rel.get("assets", []):
        if a["name"].lower() == wanted:
            return a
    assets = rel.get("assets", [])
    return assets[0] if assets else None


def all_link(script):
    return "https://github.com/%s/releases?q=%s&expanded=true" % (REPO, script["tag"])


def releases_block(script, mine):
    out = []
    if not mine:
        out.append("Релизов пока нет. No releases yet.")
        out.append("")
        out.append("[Релизы на GitHub](%s)" % all_link(script))
        return NL.join(out)

    top = mine[0]
    a = asset_of(top, script)
    day = (top.get("published_at") or "")[:10]
    if a:
        out.append("Скачать: [%s](%s) — `%s`, %s"
                   % (a["name"], a["browser_download_url"], top["tag_name"], day))
        out.append("")

    out.append("| версия | дата | файл | загрузок |")
    out.append("| --- | --- | --- | --- |")
    for r in mine:
        a = asset_of(r, script)
        link = "[%s](%s)" % (a["name"], a["browser_download_url"]) if a else "—"
        count = a["download_count"] if a else 0
        out.append("| [`%s`](%s) | %s | %s | %d |"
                   % (r["tag_name"], r["html_url"], (r.get("published_at") or "")[:10], link, count))
    out.append("")
    out.append("[Все релизы](%s)" % all_link(script))
    return NL.join(out)


def changelog(script, lang):
    folder = BASE / "scripts" / script["id"]
    names = ["CHANGELOG.en.md", "CHANGELOG.md"] if lang == "en" else ["CHANGELOG.md"]
    for name in names:
        path = folder / name
        if path.exists():
            return path.read_text(encoding="utf-8").strip()
    return None


def section(script, lang, mine):
    t = script[lang]
    ru = lang == "ru"
    out = ["## %s" % ("Что умеет" if ru else "What it does"), "", t["about"], ""]
    out += ["- " + f for f in t["features"]]
    out += ["", "## %s" % ("Установка" if ru else "Install"), ""]
    steps = INSTALL[script["kind"]][lang]
    out += ["%d. %s" % (i + 1, s % {"file": script["file"]}) for i, s in enumerate(steps)]
    out += [""]
    out += ["Язык меню берется из языка чита, скрипт понимает русский и английский."
            if ru else
            "The menu follows your cheat language; the script speaks Russian and English."]
    text = changelog(script, lang)
    if mine and text:
        out += ["", "## %s" % ("Что нового" if ru else "Changelog"), "", text]
    return NL.join(out)


def build_readme(script, rels):
    mine = for_script(script, rels)
    parts = [
        "# %s" % script["title"],
        "",
        "%s / %s" % (script["ru"]["tagline"], script["en"]["tagline"]),
        "",
        START,
        releases_block(script, mine),
        END,
        "",
        section(script, "ru", mine),
        "",
        "---",
        "",
        "# %s (English)" % script["title"],
        "",
        section(script, "en", mine),
        "",
    ]
    path = BASE / "scripts" / script["id"] / "README.md"
    path.write_text(NL.join(parts) + NL, encoding="utf-8", newline=NL)
    return len(mine)


def gitbook_block(script, mine, lang):
    ru = lang == "ru"
    if not mine:
        return NL.join(["Релизов пока нет." if ru else "No releases yet.", "",
                        "[%s](%s)" % ("Релизы на GitHub" if ru else "Releases on GitHub",
                                      all_link(script))])

    top = mine[0]
    a = asset_of(top, script)
    day = (top.get("published_at") or "")[:10]
    out = []
    if a:
        out += ["**%s** [%s](%s) — `%s`, %s"
                % ("Скачать:" if ru else "Download:", a["name"], a["browser_download_url"],
                   top["tag_name"], day), ""]
    out += ["<details>", "", "<summary>%s</summary>" % ("Все версии" if ru else "All versions"), "",
            "| %s | %s | %s | %s |" % (("Версия", "Дата", "Файл", "Загрузок") if ru
                                       else ("Version", "Date", "File", "Downloads")),
            "| --- | --- | --- | --- |"]
    for r in mine:
        a = asset_of(r, script)
        link = "[%s](%s)" % (a["name"], a["browser_download_url"]) if a else "—"
        count = a["download_count"] if a else 0
        out.append("| [`%s`](%s) | %s | %s | %d |"
                   % (r["tag_name"], r["html_url"], (r.get("published_at") or "")[:10], link, count))
    out += ["", "</details>"]
    return NL.join(out)


def changelog_block(script, lang):
    text = changelog(script, lang)
    if not text:
        return ""
    lines = ["## %s" % ("Что нового" if lang == "ru" else "Changelog"), ""]
    for line in text.splitlines():
        lines.append("* " + line[2:] if line.startswith("- ") else line)
    return NL.join(lines)


def update_gitbook(script, mine):
    name = script["tag"] + ".md"
    for folder, lang in (("gitbook/ru", "ru"), ("gitbook/en", "en")):
        root = BASE / folder
        if not root.exists():
            continue
        pages = [p for p in sorted(root.rglob(name)) if DOC_START in p.read_text(encoding="utf-8")]
        if not pages:
            print("  no page %s in %s" % (name, folder))
            continue
        for path in pages:
            patch(path, DOC_START, DOC_END, gitbook_block(script, mine, lang))
            if LOG_START in path.read_text(encoding="utf-8"):
                patch(path, LOG_START, LOG_END, changelog_block(script, lang))
            print("  %s" % path.relative_to(BASE).as_posix())


def catalog_list(lang):
    out = []
    for script in CATALOG["scripts"]:
        out.append("- [%s](scripts/%s) — %s"
                   % (script["title"], script["id"], script[lang]["tagline"]))
    return NL.join(out)


def patch(path, start, end, block):
    text = path.read_text(encoding="utf-8")
    new = start + NL + block + NL + end
    if start in text and end in text:
        text = re.sub(re.escape(start) + ".*?" + re.escape(end), lambda m: new, text, flags=re.S)
    else:
        text = text.rstrip() + NL * 2 + new + NL
    path.write_text(text, encoding="utf-8", newline=NL)


def update_skill(rels):
    skill = CATALOG.get("skill")
    if not skill:
        return
    path = BASE / skill["folder"] / "README.md"
    if not path.exists():
        return
    mine = for_script(skill, rels)
    patch(path, START, END, releases_block(skill, mine))
    print("%-20s releases: %d" % (skill["id"], len(mine)))


def main():
    rels = releases()
    for script in CATALOG["scripts"]:
        n = build_readme(script, rels)
        update_gitbook(script, for_script(script, rels))
        print("%-20s releases: %d" % (script["id"], n))
    update_skill(rels)
    readme = BASE / "README.md"
    patch(readme, CAT_RU_START, CAT_RU_END, catalog_list("ru"))
    patch(readme, CAT_EN_START, CAT_EN_END, catalog_list("en"))


if __name__ == "__main__":
    main()
