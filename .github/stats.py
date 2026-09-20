import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chart

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
DATA = GH / "stats" / "stats.jsonl"
README = BASE / "README.md"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
REPO = CATALOG["repo"]
LEGACY = ["But3rflys/Lane-Pull", "But3rflys/DSSpot", "But3rflys/MusicUI"]
NL = chr(10)


def api(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print("skip %s: %d" % (url, e.code))
        return []


def owner_of(script):
    keys = [script["id"], script["tag"], script["title"].lower().replace(" ", "")]
    return [k.lower() for k in keys]


def match(name, tag):
    text = (name + " " + tag).lower().replace("-", "_")
    for script in CATALOG["scripts"]:
        for key in owner_of(script):
            if key.replace("-", "_") in text:
                return script["id"]
    return None


def fetch():
    rows = []
    for repo in [REPO] + LEGACY:
        for rel in api("https://api.github.com/repos/%s/releases?per_page=100" % repo):
            if rel.get("draft"):
                continue
            for a in rel.get("assets", []):
                rows.append({
                    "repo": repo,
                    "tag": rel["tag_name"],
                    "file": a["name"],
                    "script": match(a["name"], rel["tag_name"]),
                    "date": (rel.get("published_at") or "")[:10],
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
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(NL.join(lines) + NL, encoding="utf-8", newline=NL)
    return [json.loads(l) for l in lines]


def draw(history):
    tail = history[-30:]
    days = [h["date"][5:] for h in tail]
    totals = [h["total"] for h in tail]
    for theme in ("light", "dark"):
        (DATA.parent / ("stats-%s.svg" % theme)).write_text(
            chart.build(days, totals, theme), encoding="utf-8", newline=NL)
    return ('<picture>' + NL
            + '  <source media="(prefers-color-scheme: dark)" srcset=".github/stats/stats-dark.svg">' + NL
            + '  <img alt="Downloads over time" src=".github/stats/stats-light.svg" width="840">' + NL
            + '</picture>')


def table(rows):
    by_script = {}
    for r in rows:
        if r["script"]:
            by_script.setdefault(r["script"], []).append(r)
    out = ["| script | downloads | latest |", "| --- | --- | --- |"]
    for script in CATALOG["scripts"]:
        items = by_script.get(script["id"], [])
        if not items:
            continue
        total = sum(i["downloads"] for i in items)
        last = max(items, key=lambda i: i["date"])
        out.append("| [%s](scripts/%s) | %d | `%s` |"
                   % (script["title"], script["id"], total, last["tag"]))
    return NL.join(out)


def render(history, rows):
    day = history[-1]["date"]
    block = NL.join([
        table(rows), "", draw(history), "",
        "%s" % day,
    ])
    text = README.read_text(encoding="utf-8")
    start, end = "<!-- stats:start -->", "<!-- stats:end -->"
    new = start + NL + block + NL + end
    if start in text and end in text:
        text = re.sub(re.escape(start) + ".*?" + re.escape(end), lambda m: new, text, flags=re.S)
    else:
        text = text.rstrip() + NL * 2 + new + NL
    README.write_text(text, encoding="utf-8", newline=NL)


def main():
    rows = fetch()
    history = append(rows)
    render(history, rows)
    print(history[-1]["date"], "total:", history[-1]["total"], "| days:", len(history))


if __name__ == "__main__":
    main()
