import json
import os
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
REPO = CATALOG["repo"]
NL = chr(10)


def find(tag):
    for script in CATALOG["scripts"]:
        if tag.startswith(script["tag"] + "-v"):
            return script
    return None


def body(script, tag):
    folder = BASE / "scripts" / script["id"]
    version = tag[len(script["tag"]) + 1:]
    out = ["## %s %s" % (script["title"], version), ""]

    ru = folder / "CHANGELOG.md"
    en = folder / "CHANGELOG.en.md"
    if ru.exists():
        out += ["### Что нового", "", ru.read_text(encoding="utf-8").strip(), ""]
    if en.exists():
        out += ["### What's new", "", en.read_text(encoding="utf-8").strip(), ""]
    if not ru.exists() and not en.exists():
        out += [script["ru"]["tagline"], "", script["en"]["tagline"], ""]

    out += [
        "---",
        "",
        "Описание и все версии: https://github.com/%s/tree/main/scripts/%s"
        % (REPO, script["id"]),
    ]
    return NL.join(out) + NL


def main():
    tag = sys.argv[1]
    script = find(tag)
    out = os.environ.get("GITHUB_OUTPUT")
    lines = []
    if script:
        (BASE / "body.md").write_text(body(script, tag), encoding="utf-8", newline=NL)
        path = ""
        if script["kind"] == "lua":
            path = "scripts/%s/%s" % (script["id"], script["file"])
        lines += ["found=true", "path=%s" % path, "title=%s" % script["title"],
                  "version=%s" % tag[len(script["tag"]) + 1:]]
        print("release %s%s" % (tag, (" with " + path) if path else " without files"))
    else:
        lines += ["found=false"]
        print("no script in catalog.json matches tag %s" % tag)
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(NL.join(lines) + NL)


if __name__ == "__main__":
    main()
