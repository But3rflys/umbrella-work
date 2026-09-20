import datetime
import json
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chart

REPOS = ["But3rflys/Lane-Pull", "But3rflys/DSSpot", "But3rflys/MusicUI"]
BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "stats.jsonl"
README = BASE / "README.md"
NL = chr(10)


def fetch():
    rows = []
    for repo in REPOS:
        url = "https://api.github.com/repos/%s/releases?per_page=100" % repo
        with urllib.request.urlopen(url) as r:
            for rel in json.load(r):
                for a in rel["assets"]:
                    rows.append({
                        "repo": repo,
                        "tag": rel["tag_name"],
                        "file": a["name"],
                        "downloads": a["download_count"],
                    })
    return rows


def append(rows):
    day = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%d")
    total = sum(r["downloads"] for r in rows)
    lines = []
    if DATA.exists():
        lines = [l for l in DATA.read_text(encoding="utf-8").splitlines() if l.strip()]
        lines = [l for l in lines if json.loads(l)["date"] != day]
    lines.append(json.dumps({"date": day, "total": total, "assets": rows}, ensure_ascii=False))
    DATA.write_text(NL.join(lines) + NL, encoding="utf-8", newline=NL)
    return [json.loads(l) for l in lines]


def draw(history):
    tail = history[-30:]
    days = [h["date"][5:] for h in tail]
    totals = [h["total"] for h in tail]
    for theme in ("light", "dark"):
        (BASE / ("stats-%s.svg" % theme)).write_text(
            chart.build(days, totals, theme), encoding="utf-8", newline=NL)
    return ('<picture>' + NL
            + '  <source media="(prefers-color-scheme: dark)" srcset="stats-dark.svg">' + NL
            + '  <img alt="Загрузки по дням" src="stats-light.svg" width="840">' + NL
            + '</picture>')


def table(rows):
    by_repo = {}
    for r in rows:
        by_repo.setdefault(r["repo"], []).append(r)
    out = ["| репозиторий | загрузок | последний релиз |", "| --- | --- | --- |"]
    for repo in REPOS:
        items = by_repo.get(repo, [])
        if not items:
            continue
        total = sum(i["downloads"] for i in items)
        last = items[0]
        out.append("| [%s](https://github.com/%s) | %d | `%s` — %d |"
                   % (repo.split("/")[1], repo, total, last["tag"], last["downloads"]))
    return NL.join(out)


def render(history, rows):
    day = history[-1]["date"]
    block = NL.join([table(rows), "", draw(history), "", "_обновлено %s, считаются только файлы из релизов_" % day])
    text = README.read_text(encoding="utf-8")
    start, end = "<!-- stats:start -->", "<!-- stats:end -->"
    new = start + NL + block + NL + end
    if start in text and end in text:
        text = re.sub(re.escape(start) + ".*?" + re.escape(end), lambda m: new, text, flags=re.S)
    else:
        text = text.rstrip() + NL * 2 + "## Загрузки" + NL * 2 + new + NL
    README.write_text(text, encoding="utf-8", newline=NL)


def main():
    rows = fetch()
    history = append(rows)
    render(history, rows)
    print(history[-1]["date"], "total:", history[-1]["total"], "| days:", len(history))


if __name__ == "__main__":
    main()
