import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
FOLDER = BASE / "scripts" / "draft_helper"
SCRIPT = FOLDER / "draft_helper.lua"
MANIFEST = FOLDER / "version.json"
REPO = json.loads((BASE / ".github" / "catalog.json").read_text(encoding="utf-8"))["repo"]
PREFIX = "draft-helper-v"
NL = chr(10)
NOTE_MAX = 60
NOTE_LINES = 4


def version_of(tag):
    if not tag.startswith(PREFIX):
        sys.exit("tag %s is not a draft helper tag" % tag)
    return tag[len(PREFIX):]


def bump(tag):
    version = version_of(tag)
    text = SCRIPT.read_bytes().decode("utf-8")
    new, count = re.subn(r'(\n\tVERSION = ")[^"]+(",)', lambda m: m.group(1) + version + m.group(2), text, count=1)
    if count != 1:
        sys.exit("VERSION line not found in %s" % SCRIPT.name)
    SCRIPT.write_bytes(new.encode("utf-8"))
    print("draft_helper.lua version %s" % version)


def short(line):
    line = line.strip()
    if len(line) <= NOTE_MAX:
        return line
    cut = max(line.rfind(", ", 0, NOTE_MAX), line.rfind(": ", 0, NOTE_MAX))
    return line[:cut] if cut > 20 else line[:NOTE_MAX].rsplit(" ", 1)[0]


def notes(name):
    path = FOLDER / name
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*-\s*(?:\*\*[^*]+\*\*\s*)?(.+)$", line)
        if m:
            text = short(m.group(1))
            out.append(text[:1].upper() + text[1:])
        if len(out) >= NOTE_LINES:
            break
    return out


def manifest(tag, sha):
    version = version_of(tag)
    data = {
        "version": version,
        "url": "https://raw.githubusercontent.com/%s/%s/scripts/draft_helper/draft_helper.lua" % (REPO, sha),
        "notes": {"ru": notes("CHANGELOG.md"), "en": notes("CHANGELOG.en.md")},
    }
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + NL, encoding="utf-8", newline=NL)
    print("version.json %s -> %s" % (version, data["url"]))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "bump":
        bump(sys.argv[2])
    elif len(sys.argv) >= 4 and sys.argv[1] == "manifest":
        manifest(sys.argv[2], sys.argv[3])
    else:
        sys.exit("usage: draft_helper.py bump <tag> | manifest <tag> <sha>")


if __name__ == "__main__":
    main()
