import json
import os
import re
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


def manifest_path(script):
    path = BASE / "scripts" / script["id"] / "version.json"
    return path if path.exists() else None


def check_version(script, version):
    text = (BASE / "scripts" / script["id"] / script["file"]).read_text(encoding="utf-8")
    m = re.search(r'VERSION = "([^"]+)"', text)
    if not m or m.group(1) != version:
        raise SystemExit("%s has VERSION %s, tag says %s"
                         % (script["file"], m.group(1) if m else "none", version))


def write_manifest(script, tag, sha):
    version = tag[len(script["tag"]) + 2:]
    data = {
        "version": version,
        "url": "https://raw.githubusercontent.com/%s/%s/scripts/%s/%s"
               % (REPO, sha, script["id"], script["file"]),
        "release": "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, script["file"]),
    }
    path = manifest_path(script)
    path.write_text(json.dumps(data, indent=2) + NL, encoding="utf-8", newline=NL)
    print("%s -> %s" % (path.relative_to(BASE).as_posix(), version))


def main():
    tag = sys.argv[1]
    script = find(tag)
    if script and len(sys.argv) > 3 and sys.argv[2] == "--manifest":
        write_manifest(script, tag, sys.argv[3])
        return
    out = os.environ.get("GITHUB_OUTPUT")
    lines = []
    if script:
        (BASE / "body.md").write_text(body(script, tag), encoding="utf-8", newline=NL)
        if manifest_path(script):
            check_version(script, tag[len(script["tag"]) + 2:])
            lines += ["manifest=%s" % script["id"].replace("_", " ")]
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
