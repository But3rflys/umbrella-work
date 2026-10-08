import hashlib
import json
import re
import shutil
from collections import Counter
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
OUT = BASE / "_site"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
ROWS = [json.loads(line) for line in (GH / "stats" / "stats.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
LEGACY_FILE = GH / "stats" / "legacy.json"
LEGACY = json.loads(LEGACY_FILE.read_text(encoding="utf-8")) if LEGACY_FILE.exists() else {}

SKILL_TEXT = {
    "ru": {
        "tagline": "скилл для Claude Code и Codex: пишет Lua-скрипты Umbrella",
        "about": "Пишет и правит Lua-скрипты Umbrella по общим правилам. Меню по одному эталону и встроенная локализация en/ru.",
        "features": ["меню по одному эталону", "локализация en/ru из коробки", "проверка кода через luatool.exe", "работает без Python и Lua"],
    },
    "en": {
        "tagline": "Claude Code and Codex skill for Umbrella Lua scripts",
        "about": "Writes and edits Umbrella Lua scripts by shared rules, with one reference menu layout and en/ru localization built in.",
        "features": ["one reference menu layout", "en/ru localization built in", "code checks via luatool.exe", "no Python or Lua needed"],
    },
}


def version_key(version):
    return [(0, int(p)) if p.isdigit() else (-1, p) for p in re.split(r"[.\-]", version)]


def read(path):
    return path.read_text(encoding="utf-8") if path.exists() else ""


def owner(asset):
    return asset.get("script") or CATALOG["skill"]["id"]


def series():
    seen = {}
    out = []
    for row in ROWS:
        for a in row["assets"]:
            seen[(a["tag"], a["file"])] = (owner(a), a["downloads"])
        counts = Counter(LEGACY)
        for key, (script_id, downloads) in seen.items():
            counts[script_id] += downloads
        out.append([row["date"], sum(counts.values()), dict(counts)])
    return out


SERIES = series()


def entry(script, folder, kind):
    prefix = script["tag"] + "-v"
    assets = [a for a in ROWS[-1]["assets"] if a["tag"].startswith(prefix)]
    versions = [{"v": a["tag"][len(prefix):], "date": a["date"], "dl": a["downloads"], "file": a.get("file") or script["file"]} for a in assets]
    versions.sort(key=lambda v: version_key(v["v"]), reverse=True)
    preview = GH / "previews" / (script["id"] + ".png")
    return {
        "id": script["id"],
        "title": script["title"],
        "kind": kind,
        "file": versions[0]["file"] if versions else script["file"],
        "total": SERIES[-1][2].get(script["id"], 0),
        "tag": script["tag"],
        "folder": folder,
        "ru": script.get("ru") or SKILL_TEXT["ru"],
        "en": script.get("en") or SKILL_TEXT["en"],
        "preview": preview.exists(),
        "versions": versions,
        "changelog": {
            "ru": read(BASE / folder / "CHANGELOG.md"),
            "en": read(BASE / folder / "CHANGELOG.en.md") or read(BASE / folder / "CHANGELOG.md"),
        },
    }


def main():
    items = [entry(s, "scripts/" + s["id"], s["kind"]) for s in CATALOG["scripts"]]
    skill = CATALOG["skill"]
    items.append(entry(skill, skill["folder"], "skill"))
    items = [i for i in items if i["versions"]]
    data = "window.DATA=" + json.dumps({"repo": CATALOG["repo"], "items": items, "series": SERIES}, ensure_ascii=False)

    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "previews").mkdir(parents=True)
    (OUT / "data.js").write_text(data, encoding="utf-8")
    for item in items:
        if item["preview"]:
            shutil.copy(GH / "previews" / (item["id"] + ".png"), OUT / "previews")
    stamp = hashlib.sha1(data.encode("utf-8")).hexdigest()[:10]
    html = (BASE / "site" / "index.html").read_text(encoding="utf-8").replace("data.js", "data.js?v=" + stamp)
    (OUT / "index.html").write_text(html, encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    print("site: %d items, %d days" % (len(items), len(ROWS)))


main()
