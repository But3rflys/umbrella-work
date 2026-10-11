import gzip
import json
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "data")
API = "https://api.opendota.com/api/"
HEADERS = {"User-Agent": "umbrella-work/draft-data", "Accept": "application/json"}
QUICK = os.environ.get("DRAFT_DATA_QUICK") == "1"

RANKS = (0, 50, 60, 70)
TARGET = 4000 if QUICK else 200000
PAGE = 2000
PAGE_MIN = 250
CM_DAYS = 90
CM_PAGE = 500
CM_WINDOW = 4000000
CM_WINDOW_MIN = 250000
CM_WINDOWS = 3 if QUICK else 400
GAP = 1.1
CALLS_MAX = 1900
D2PT = "https://dota2protracker.com/hero/"
D2PT_GAP = 3
D2PT_EVERY = 3 * 86400
D2PT_MATCHES = 100
D2PT_FINAL = 0.01

REC = struct.Struct("<QI10sBB")

MATCH_COLS = "match_id m, start_time s, radiant_team r, dire_team d, radiant_win w, avg_rank_tier t"


calls = 0


def log(msg, *args):
    print(msg % args if args else msg, flush=True)


class Timeout(Exception):
    pass


def get(url):
    global calls
    last = None
    for attempt in range(6):
        if calls >= CALLS_MAX:
            raise RuntimeError("call budget spent")
        time.sleep(GAP)
        calls += 1
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=150) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            last = "http %d" % e.code
            if e.code == 400:
                try:
                    err = str(json.loads(e.read()).get("err"))
                except Exception:
                    err = last
                if "timeout" in err.lower():
                    raise Timeout(err)
                raise RuntimeError("explorer: " + err[:160])
            if e.code == 429 or e.code >= 500:
                time.sleep(20 * (attempt + 1))
                continue
            raise RuntimeError(last)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            last = type(e).__name__
            time.sleep(10 * (attempt + 1))
    raise RuntimeError("no answer: %s" % last)


def explorer(sql):
    data = get(API + "explorer?sql=" + urllib.parse.quote(sql))
    if data.get("err"):
        raise RuntimeError("explorer: %s" % str(data["err"])[:160])
    return data.get("rows") or []


def pack(row):
    r, d, w = row.get("r"), row.get("d"), row.get("w")
    if not isinstance(r, list) or not isinstance(d, list) or w not in (True, False):
        return None
    ids = r + d
    if len(ids) != 10 or len(set(ids)) != 10 or not all(isinstance(x, int) and 0 < x < 256 for x in ids):
        return None
    tier = max(0, min(255, int(row.get("t") or 0)))
    return REC.pack(int(row["m"]), int(row.get("s") or 0), bytes(ids), 1 if w else 0, tier)


def rec_id(rec):
    return REC.unpack(rec)[0]


def rec_time(rec):
    return REC.unpack(rec)[1]


def rec_tier(rec):
    return REC.unpack(rec)[4]


def load_raw(name):
    path = OUT / "raw" / name
    if not path.exists():
        return []
    blob = gzip.decompress(path.read_bytes())
    return [blob[i:i + REC.size] for i in range(0, len(blob) - REC.size + 1, REC.size)]


def save_raw(name, recs):
    path = OUT / "raw" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gzip.compress(b"".join(recs), 6))


def write(name, text):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def ranked_page(rank, above, below, size):
    where = ["lobby_type = 7", "game_mode = 22"]
    if rank:
        where.append("avg_rank_tier >= %d" % rank)
    if above is not None:
        where.append("match_id > %d" % above)
    if below is not None:
        where.append("match_id < %d" % below)
    return explorer("select %s from public_matches where %s order by match_id desc limit %d"
                    % (MATCH_COLS, " and ".join(where), size))


def ranked_fetch(rank, above, below, limit):
    out, size = [], PAGE
    while len(out) < limit:
        try:
            rows = ranked_page(rank, above, below, size)
        except Timeout:
            if size <= PAGE_MIN:
                raise
            size //= 2
            continue
        out += [x for x in map(pack, rows) if x]
        if len(rows) < size:
            break
        below = min(int(r["m"]) for r in rows)
    return out


def update_ranked(rank):
    name = "ap_%d.bin.gz" % rank
    old = load_raw(name)
    top = rec_id(old[0]) if old else None
    new = ranked_fetch(rank, top, None, TARGET)
    recs = (new + old)[:TARGET]
    if len(recs) < TARGET:
        recs += ranked_fetch(rank, None, rec_id(recs[-1]) if recs else None, TARGET - len(recs))
    recs = recs[:TARGET]
    if len(recs) < TARGET:
        raise RuntimeError("only %d matches" % len(recs))
    save_raw(name, recs)
    log("ap %d: %d matches, %d new", rank, len(recs), len(new))
    return recs


def cm_window(lo, hi):
    out, below = [], hi + 1
    while True:
        rows = explorer("select %s from public_matches where game_mode = 2 and match_id > %d and match_id < %d "
                        "order by match_id desc limit %d" % (MATCH_COLS, lo, below, CM_PAGE))
        out += [x for x in map(pack, rows) if x]
        if len(rows) < CM_PAGE:
            return out
        below = min(int(r["m"]) for r in rows)


def update_cm(newest):
    old = load_raw("cm.bin.gz")
    top = rec_id(old[0]) if old else 0
    cutoff = int(time.time()) - CM_DAYS * 86400
    found, hi, width = [], newest, CM_WINDOW
    for _ in range(CM_WINDOWS):
        lo = max(hi - width, top)
        try:
            part = cm_window(lo, hi)
        except Timeout:
            if width <= CM_WINDOW_MIN:
                raise
            width //= 2
            continue
        found += part
        if lo <= top or (part and rec_time(part[-1]) < cutoff) or len(found) >= TARGET:
            break
        hi = lo
    seen, recs = set(), []
    for rec in sorted(found + old, key=rec_id, reverse=True):
        i = rec_id(rec)
        if i not in seen and rec_time(rec) >= cutoff:
            seen.add(i)
            recs.append(rec)
    recs = recs[:TARGET]
    save_raw("cm.bin.gz", recs)
    log("cm: %d matches, %d found", len(recs), len(found))
    return recs


def stats(recs):
    games, wins, same, vs = {}, {}, {}, {}
    for rec in recs:
        _, _, ids, radiant_win, _ = REC.unpack(rec)
        teams = (ids[:5], ids[5:])
        for side, team in enumerate(teams):
            won = (side == 0) == (radiant_win == 1)
            for i, a in enumerate(team):
                games[a] = games.get(a, 0) + 1
                wins[a] = wins.get(a, 0) + won
                for b in team[i + 1:]:
                    key = (a, b) if a < b else (b, a)
                    g, w = same.get(key, (0, 0))
                    same[key] = (g + 1, w + won)
        for a in teams[0]:
            for b in teams[1]:
                key, a_won = ((a, b), radiant_win == 1) if a < b else ((b, a), radiant_win == 0)
                g, w = vs.get(key, (0, 0))
                vs[key] = (g + 1, w + a_won)
    lines = ["n %d" % len(recs)]
    lines += ["h %d %d %d" % (h, games[h], wins[h]) for h in sorted(games)]
    lines += ["s %d %d %d %d" % (a, b, g, w) for (a, b), (g, w) in sorted(same.items())]
    lines += ["v %d %d %d %d" % (a, b, g, w) for (a, b), (g, w) in sorted(vs.items())]
    return "\n".join(lines) + "\n"


def describe(recs):
    return {"n": len(recs), "from": rec_time(recs[-1]) if recs else 0, "to": rec_time(recs[0]) if recs else 0}


def d2pt_roles():
    path = OUT / "stats" / "items.txt"
    full, pages = {}, {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            p = line.split()
            if p and p[0] == "r" and len(p) == 7:
                full[int(p[1])] = [int(x) for x in p[2:]]
            elif p and p[0] == "h" and len(p) == 6:
                pages.setdefault(int(p[1]), [0] * 5)[int(p[2]) - 1] = int(p[5])
    pages.update(full)
    return pages


def heroes():
    data = get(API + "heroes")
    roles = d2pt_roles()
    out = []
    for h in data:
        if not isinstance(h, dict) or not h.get("id") or not str(h.get("name", "")).startswith("npc_dota_hero_"):
            continue
        out.append({"id": h["id"], "name": h["name"][14:], "attr": h.get("primary_attr") or "all", "pos": roles.get(h["id"], [0] * 5)})
    if len(out) < 100:
        raise RuntimeError("bad heroes list")
    out.sort(key=lambda x: x["id"])
    write("heroes.json", json.dumps(out, separators=(",", ":")))
    log("heroes: %d, roles for %d", len(out), sum(1 for h in out if any(h["pos"])))


class JsLiteral:
    NUM = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
    KEY = re.compile(r"[A-Za-z_$0-9][\w$]*")
    LITS = (("true", True), ("false", False), ("null", None), ("void 0", None), ("undefined", None),
            ("NaN", None), ("-Infinity", None), ("Infinity", None))
    ESC = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f"}

    def __init__(self, s, i=0):
        self.s, self.i = s, i

    def ws(self):
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def value(self):
        self.ws()
        s, i = self.s, self.i
        c = s[i]
        if c == "{":
            return self.obj()
        if c == "[":
            return self.arr()
        if c in "\"'":
            return self.string()
        m = self.NUM.match(s, i)
        if m:
            self.i = m.end()
            t = m.group()
            return float(t) if any(x in t for x in ".eE") else int(t)
        for lit, v in self.LITS:
            if s.startswith(lit, i):
                self.i = i + len(lit)
                return v
        raise ValueError("bad value at %d" % i)

    def string(self):
        s, q, j, out = self.s, self.s[self.i], self.i + 1, []
        while s[j] != q:
            if s[j] == "\\":
                n = s[j + 1]
                if n == "u":
                    out.append(chr(int(s[j + 2:j + 6], 16)))
                    j += 6
                    continue
                out.append(self.ESC.get(n, n))
                j += 2
                continue
            out.append(s[j])
            j += 1
        self.i = j + 1
        return "".join(out)

    def key(self):
        self.ws()
        if self.s[self.i] in "\"'":
            return self.string()
        m = self.KEY.match(self.s, self.i)
        self.i = m.end()
        return m.group()

    def obj(self):
        self.i += 1
        out = {}
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                return out
            k = self.key()
            self.ws()
            if self.s[self.i] != ":":
                raise ValueError("expected : at %d" % self.i)
            self.i += 1
            out[k] = self.value()
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1

    def arr(self):
        self.i += 1
        out = []
        while True:
            self.ws()
            if self.s[self.i] == "]":
                self.i += 1
                return out
            out.append(self.value())
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1


def d2pt_page(name, pos=None):
    url = D2PT + urllib.parse.quote_plus(name) + "?section=builds" + ("&position=pos+%d" % pos if pos else "")
    last = None
    for attempt in range(4):
        time.sleep(D2PT_GAP)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": HEADERS["User-Agent"]}), timeout=90) as r:
                html = r.read().decode("utf-8")
            i = html.find("kit.start(app, element, {")
            if i < 0:
                raise RuntimeError("no page data")
            return JsLiteral(html, html.find("data:", i) + 5).value()
        except urllib.error.HTTPError as e:
            last = "http %d" % e.code
            if e.code == 429 or e.code >= 500:
                time.sleep(30 * (attempt + 1))
                continue
            raise RuntimeError("%s for %s" % (last, url))
        except (urllib.error.URLError, TimeoutError) as e:
            last = type(e).__name__
            time.sleep(10 * (attempt + 1))
    raise RuntimeError("no answer: %s" % last)


def d2pt_rows(hid, node, seen):
    pos = int(str(node.get("position") or "0").replace("pos ", "") or 0)
    builds = [b for b in node.get("buildData") or [] if isinstance(b, dict) and b.get("build_data")]
    if not pos or not builds:
        return []
    bd = min(builds, key=lambda b: b.get("build_id", 99))["build_data"]
    stats = {x.get("position"): x.get("matches") or 0 for x in node.get("heroStats") or []}
    total = stats.get("all") or 0
    share = round(100 * stats.get("pos %d" % pos, 0) / total) if total else 0
    rows = ["h %d %d %d %d %d" % (hid, pos, bd.get("num_matches") or 0, round((bd.get("win_rate") or 0) * 1000), share)]
    for opt in (bd.get("starting_items_new") or [])[:2]:
        ids = [int(x) for x in opt[0]]
        seen.update(ids)
        rows.append("s %d %d %d %s" % (hid, pos, opt[1].get("count") or 0, ",".join(map(str, ids))))
    for key, tag in (("anchor_items", "c"), ("items_mid_late", "m")):
        for x in bd.get(key) or []:
            i = int(x["raw_item_id"])
            seen.add(i)
            rows.append("%s %d %d %d %d %d %d" % (tag, hid, pos, i, round(x.get("pr", 0) * 1000),
                                                round(x.get("avg_minute", 0) * 10), round((x.get("win_rate") or 0) * 1000)))
    path = bd.get("anchor_build") or []
    if path and isinstance(path[0], list):
        stats_ai = bd.get("anchor_item_stats") or {}
        mins = {int(x["raw_item_id"]): x.get("avg_minute", 0) for x in (bd.get("anchor_items") or []) + (bd.get("items_mid_late") or [])}
        for i in path[0]:
            i = int(i)
            seen.add(i)
            m = (stats_ai.get(str(i)) or {}).get("avg_minute")
            rows.append("b %d %d %d %d" % (hid, pos, i, round((m if m is not None else mins.get(i, 0)) * 10)))
    for x in bd.get("sixslot") or []:
        if x.get("pick_rate", 0) >= D2PT_FINAL:
            i = int(x["item_id"])
            seen.add(i)
            rows.append("f %d %d %d %d" % (hid, pos, i, round(x["pick_rate"] * 1000)))
    return rows


def items():
    path = OUT / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    prev = (manifest.get("sets") or {}).get("items") or {}
    if prev.get("src") == "d2pt" and prev.get("min") == D2PT_MATCHES and time.time() - prev.get("time", 0) < D2PT_EVERY and (OUT / "stats/items.txt").exists() and (OUT / "stats/build.txt").exists():
        log("items: fresh, skipped")
        return None
    consts = get(API + "constants/items")
    game = {int(v["id"]): (k, int(v.get("cost") or 0)) for k, v in consts.items() if isinstance(v, dict) and v.get("id")}
    parents = {}
    for v in consts.values():
        if isinstance(v, dict) and v.get("id"):
            for c in v.get("components") or []:
                parents.setdefault(c, set()).add(int(v["id"]))
    ours = {h["id"] for h in json.loads((OUT / "heroes.json").read_text(encoding="utf-8"))}
    first = d2pt_page("Anti-Mage")
    common = first[0]["data"]
    mapping, names = common.get("itemsMapping") or {}, common.get("heroesMapping") or {}
    ctx = build_ctx(consts)
    rows, seen, pages, heroes, patch, full = [], set(), 0, 0, "", []
    for hid_s, info in sorted(names.items(), key=lambda x: int(x[0])):
        hid = int(hid_s)
        if hid not in ours:
            continue
        try:
            node = first[1]["data"] if hid == 1 else d2pt_page(info["displayName"])[1]["data"]
        except Exception as e:
            log("items: %s skipped: %s", info.get("displayName"), e)
            continue
        part = d2pt_rows(hid, node, seen)
        if not part:
            continue
        pages += 1
        heroes += 1
        patch = node.get("patchversion") or patch
        rows += part
        full += build_rows(hid, node, ctx)
        main = int(str(node.get("position")).replace("pos ", ""))
        stats = {x.get("position"): x.get("matches") or 0 for x in node.get("heroStats") or []}
        total = sum(stats.get("pos %d" % p, 0) for p in range(1, 6))
        if total:
            line = "r %d %s" % (hid, " ".join(str(round(100 * stats.get("pos %d" % p, 0) / total)) for p in range(1, 6)))
            rows.append(line)
            full.append(line)
        for pos in range(1, 6):
            n = stats.get("pos %d" % pos, 0)
            if pos == main or n < D2PT_MATCHES:
                continue
            try:
                node = d2pt_page(info["displayName"], pos)[1]["data"]
            except Exception as e:
                log("items: %s pos %d skipped: %s", info.get("displayName"), pos, e)
                continue
            extra = d2pt_rows(hid, node, seen)
            if extra:
                pages += 1
                rows += extra
                full += build_rows(hid, node, ctx)
    if heroes < 100:
        raise RuntimeError("d2pt builds for %d heroes only" % heroes)
    lines = ["n %d" % pages, "v %s" % patch]
    by_name = {}
    for i in sorted(seen):
        m = mapping.get(str(i)) or {}
        name, cost = game.get(i, (m.get("shortName") or str(m.get("name") or "").replace("item_", ""), int(m.get("price") or 0)))
        if name:
            by_name[name] = i
            lines.append("i %d %s %d" % (i, name, cost))
    for name, i in sorted(by_name.items(), key=lambda x: x[1]):
        up = sorted(p for p in parents.get(name, ()) if p in seen)
        if up:
            lines.append("u %d %s" % (i, " ".join(map(str, up))))
    write("stats/items.txt", "\n".join(lines + rows) + "\n")
    log("items: d2pt %s, %d heroes, %d pages, %d rows", patch, heroes, pages, len(rows))
    write("stats/build.txt", "\n".join(["n %d" % pages, "v %s" % patch] + build_items(ctx, full) + full) + "\n")
    log("build: %d rows", len(full))
    return pages


BUILD_PATH = 0.3
BUILD_FIN = 0.1
BUILD_FIN_TOP = 9
BUILD_LATE_FOLLOW = 100
BUILD_FOLD = 5
BUILD_LEVEL = 0.07
BUILD_POOL = 0.01
BUILD_VAR_SHARE = 20
BUILD_VAR_GAMES = 300
BUILD_NOSLOT = {"aghanims_shard"}
BUILD_LEVELS = re.compile(r"^(dagon|travel_boots)(_\d)?$")
BUILD_EXTRA = ("ultimate_scepter_2",)


def build_ctx(consts):
    ctx = {"name": {}, "id": {}, "cost": {}, "parents": {}, "cons": set()}
    for k, v in consts.items():
        if not isinstance(v, dict) or not v.get("id"):
            continue
        i = int(v["id"])
        ctx["name"][i], ctx["id"][k], ctx["cost"][k] = k, i, int(v.get("cost") or 0)
        if v.get("qual") == "consumable":
            ctx["cons"].add(k)
        for c in v.get("components") or []:
            ctx["parents"].setdefault(c, set()).add(k)
    ctx["cons"] -= {"aghanims_shard", "moon_shard", "bottle"}
    return ctx


def build_ups(ctx, name):
    out = set()
    for p in ctx["parents"].get(name, ()):
        if p not in out:
            out |= {p} | build_ups(ctx, p)
    return out


def build_base(name):
    m = BUILD_LEVELS.match(name)
    return m.group(1) if m else name


def build_path(bd, ctx):
    names, cons = ctx["name"], ctx["cons"]
    info, ais = {}, {}

    def put(i, pr, minute):
        name = names.get(int(i))
        if not name or name in cons:
            return
        e = info.setdefault(name, {"pr": 0.0, "min": None})
        e["pr"] = max(e["pr"], pr)
        if minute is not None and e["min"] is None:
            e["min"] = minute

    for x in (bd.get("anchor_items") or []) + (bd.get("items_mid_late") or []):
        put(x["raw_item_id"], x.get("pr") or 0, x.get("avg_minute"))
    for k, v in (bd.get("anchor_item_stats") or {}).items():
        name = names.get(int(k))
        if not name:
            continue
        ais[name] = (v.get("pr") or 0) / 100
        if name in info:
            if info[name]["min"] is None:
                info[name]["min"] = v.get("avg_minute")
        else:
            put(k, 0.0, v.get("avg_minute"))
    six = {names.get(x["item_id"]): x["pick_rate"] for x in bd.get("sixslot") or [] if names.get(x["item_id"])}
    late = {k: {names.get(i) for i in v} for k, v in (bd.get("anchor_lategame_inventories") or {}).items()}
    fin = dict(six)
    for name, e in info.items():
        key = ais.get(name, 0)
        if name not in six and name not in BUILD_NOSLOT and not (build_ups(ctx, name) & set(six)):
            fin[name] = max(e["pr"], key) * (0.5 * (name in late.get("45+", ())) + 0.5 * (name in late.get("55+", ())))

    top = {}
    for name, e in info.items():
        b = build_base(name)
        if b != name or BUILD_LEVELS.match(name):
            if (e["pr"] >= BUILD_LEVEL or name == b) and (b not in top or name > top[b]):
                top[b] = name

    cand = {}

    def add(name):
        if not name or name not in info or info[name]["min"] is None:
            return
        b = build_base(name)
        key = top.get(b, name)
        if key in cand:
            return
        same = [x for x in info if build_base(x) == b and info[x]["min"] is not None]
        cand[key] = {
            "name": key,
            "min": min(info[x]["min"] for x in same),
            "pr": max(info[x]["pr"] for x in same),
            "fin": min(1.0, sum(fin.get(x, 0) for x in same)),
        }

    endgame = late.get("45+", set()) | late.get("55+", set())
    anchor = [names.get(int(i)) for i in (bd.get("anchor_build") or [[]])[0]]
    for name in anchor:
        if name in info and (max(info[name]["pr"], ais.get(name, 0)) >= BUILD_PATH or name in endgame):
            add(name)
    for name, f in sorted(fin.items(), key=lambda kv: -kv[1])[:BUILD_FIN_TOP]:
        if f >= BUILD_FIN:
            add(name)
    for name in ("ultimate_scepter", "aghanims_shard"):
        if name in info and info[name]["pr"] >= BUILD_PATH:
            add(name)
    for e in list(cand.values()):
        ups = build_ups(ctx, e["name"])
        if ups and not any(u in cand for u in ups):
            best = max((u for u in ups if u in info and info[u]["min"] is not None and info[u]["min"] > e["min"] and info[u]["pr"] >= 0.5 * e["pr"]),
                       key=lambda u: info[u]["pr"], default=None)
            if best:
                add(best)
    path = sorted(cand.values(), key=lambda e: e["min"])
    out = []
    for e in path:
        ups = build_ups(ctx, e["name"])
        later = [u["min"] for u in path if u is not e and u["name"] in ups and u["min"] >= e["min"]]
        if later and min(later) - e["min"] <= BUILD_FOLD:
            continue
        out.append(e)
    return out, info, fin


def build_rows(hid, node, ctx):
    pos = int(str(node.get("position") or "0").replace("pos ", "") or 0)
    builds = sorted((b for b in node.get("buildData") or [] if isinstance(b, dict) and b.get("build_data")), key=lambda b: b.get("build_id", 99))
    if not pos or not builds:
        return []
    stats = {x.get("position"): x.get("matches") or 0 for x in node.get("heroStats") or []}
    total = stats.get("all") or 0
    share = round(100 * stats.get("pos %d" % pos, 0) / total) if total else 0
    ids, rows, var = ctx["id"], [], 0
    for b in builds:
        if var and (b.get("pick_rate", 0) < BUILD_VAR_SHARE or (b.get("num_matches") or 0) < BUILD_VAR_GAMES):
            continue
        bd = b["build_data"]
        path, info, fin = build_path(bd, ctx)
        if not path:
            continue
        key = "%d %d %d" % (hid, pos, var)
        rows.append("h %s %d %d %d %d" % (key, b.get("num_matches") or 0, round((bd.get("win_rate") or 0) * 1000), share, round(b.get("pick_rate") or 0)))
        for opt in (bd.get("starting_items_new") or [])[:1]:
            rows.append("s %s %d %s" % (key, opt[1].get("count") or 0, ",".join(str(int(x)) for x in opt[0])))
        for e in path:
            rows.append("b %s %d %d %d %d" % (key, ids[e["name"]], round(e["min"] * 10), round(e["fin"] * 1000), round(e["pr"] * 1000)))
        late = {k: [ctx["name"].get(i) for i in v] for k, v in (bd.get("anchor_lategame_inventories") or {}).items()}
        anchor = {ctx["name"].get(int(i)) for i in (bd.get("anchor_build") or [[]])[0]}
        follow = max((x.get("purchases") or 0 for x in (bd.get("anchor_item_stats") or {}).values()), default=0)
        for name in [] if follow < BUILD_LATE_FOLLOW else sorted({n for n in late.get("55+", []) if n and n in ids and n not in ctx["cons"] and n not in BUILD_NOSLOT}):
            rows.append("l %s %d %d" % (key, ids[name], 1 if name in anchor or name in late.get("45+", []) else 0))
        for name, e in sorted(info.items()):
            if e["pr"] >= BUILD_POOL and e["min"] is not None:
                rows.append("a %s %d %d %d %d" % (key, ids[name], round(e["pr"] * 1000), round(e["min"] * 10), round(min(1.0, fin.get(name, 0)) * 1000)))
        var += 1
    return rows


def build_items(ctx, rows):
    used = {int(p[4]) for p in (r.split() for r in rows) if p[0] in ("a", "b", "l")}
    for r in rows:
        p = r.split()
        if p[0] == "s":
            used |= {int(x) for x in p[5].split(",")}
    used |= {ctx["id"][n] for n in BUILD_EXTRA if n in ctx["id"]}
    names = {ctx["name"][i] for i in used if i in ctx["name"]}
    out = ["i %d %s %d" % (i, ctx["name"][i], ctx["cost"][ctx["name"][i]]) for i in sorted(used) if i in ctx["name"]]
    for i in sorted(used):
        name = ctx["name"].get(i)
        up = sorted(ctx["id"][p] for p in ctx["parents"].get(name, ()) if p in names)
        if up:
            out.append("u %d %s" % (i, " ".join(map(str, up))))
    return out


COUNTERS_EVERY = 3 * 86400
COUNTERS_WINDOW = 10 * 86400
COUNTERS_ITEMS = ("dust", "ward_sentry", "gem")
COUNTERS_SQL = (
    "select pm.match_id m, pm.hero_id h, pm.player_slot s, pm.gold_per_min g, m.duration d, "
    "(select string_agg(distinct x->>'key', ' ') from unnest(pm.purchase_log) x) i "
    "from matches m join player_matches pm using (match_id) where m.start_time >= %d and m.start_time < %d"
)


BEAR_SQL = (
    "select pm.item_0 a, pm.item_1 b, pm.item_2 c, pm.item_3 d, pm.item_4 e, pm.item_5 f, "
    "pm.backpack_0 g, pm.backpack_1 h, pm.backpack_2 i, pm.additional_units u "
    "from player_matches pm join matches m using (match_id) where pm.hero_id = 80 and m.start_time >= %d"
)
BEAR_SLOTS = ("item_0", "item_1", "item_2", "item_3", "item_4", "item_5", "backpack_0", "backpack_1", "backpack_2")


def bear_items(start):
    names = get(API + "constants/item_ids")
    hero, bear = {}, {}
    for r in explorer(BEAR_SQL % start):
        units = [u for u in (r.get("u") or []) if u.get("unitname") == "spirit_bear"]
        if not units:
            continue
        for k in "abcdefghi":
            if r.get(k):
                hero[r[k]] = hero.get(r[k], 0) + 1
        for k in BEAR_SLOTS:
            i = units[0].get(k)
            if i:
                bear[i] = bear.get(i, 0) + 1
    lines = []
    for i in sorted(set(hero) | set(bear)):
        total = hero.get(i, 0) + bear.get(i, 0)
        name = names.get(str(i))
        if name and total >= 10:
            lines.append("k %s %d" % (name, round(1000 * bear.get(i, 0) / total)))
    return lines


def counters():
    path = OUT / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    prev = (manifest.get("sets") or {}).get("counters") or {}
    patches = get(API + "constants/patch")
    patch = patches[-1]
    start = int(time.mktime(time.strptime(patch["date"][:19], "%Y-%m-%dT%H:%M:%S")))
    if prev.get("patch") == patch["name"] and time.time() - prev.get("time", 0) < COUNTERS_EVERY and (OUT / "stats/counters.txt").exists():
        log("counters: fresh, skipped")
        return None
    rows, lo, now = [], start, int(time.time())
    while lo < now:
        rows += explorer(COUNTERS_SQL % (lo, lo + COUNTERS_WINDOW))
        lo += COUNTERS_WINDOW
    by_match = {}
    for r in rows:
        if r.get("i") and r.get("g") is not None:
            by_match.setdefault(r["m"], []).append(r)
    games = []
    for ps in by_match.values():
        if len(ps) != 10:
            continue
        teams = [sorted([p for p in ps if (p["s"] < 128) == side], key=lambda p: -p["g"]) for side in (True, False)]
        if any(len(t) != 5 for t in teams):
            continue
        for t, other in ((teams[0], teams[1]), (teams[1], teams[0])):
            for k, p in enumerate(t):
                minutes = p["d"] / 60
                games.append({
                    "h": p["h"], "core": k < 3, "set": set(p["i"].split()),
                    "db": 0 if minutes < 28 else (1 if minutes < 36 else (2 if minutes < 44 else 3)),
                    "en": [q["h"] for q in other],
                })
    strat_n, strat_c = {}, {}
    for p in games:
        key = (p["h"], p["core"], p["db"])
        strat_n[key] = strat_n.get(key, 0) + 1
        c = strat_c.setdefault(key, {})
        for it in p["set"]:
            c[it] = c.get(it, 0) + 1
    obs, exp = {}, {}
    for p in games:
        key = (p["h"], p["core"], p["db"])
        n = strat_n[key]
        if n < 2:
            continue
        for it, c in strat_c[key].items():
            pr = (c - (it in p["set"])) / (n - 1)
            for o in p["en"]:
                exp[(it, o)] = exp.get((it, o), 0) + pr
        for it in p["set"]:
            for o in p["en"]:
                obs[(it, o)] = obs.get((it, o), 0) + 1
    lines = ["n %d" % len(games), "v %s" % patch["name"]]
    base_n, base_c = {}, {}
    for p in games:
        key = (p["h"], 1 if p["core"] else 2)
        base_n[key] = base_n.get(key, 0) + 1
        for it in COUNTERS_ITEMS:
            if it in p["set"]:
                base_c[key + (it,)] = base_c.get(key + (it,), 0) + 1
    for key, n in sorted(base_n.items()):
        if n >= 30:
            for it in COUNTERS_ITEMS:
                lines.append("p %d %d %s %d" % (key[0], key[1], it, round(1000 * base_c.get(key + (it,), 0) / n)))
    for (it, o), e in sorted(exp.items()):
        ob = obs.get((it, o), 0)
        if e < 3 and ob < 3:
            continue
        lift = (ob + 10) / (e + 10)
        z = (ob - e) / (e + 1) ** 0.5
        if z >= 4 and ob >= 20 and lift >= 1.3:
            lines.append("e %s %d %d" % (it, o, round(lift * 100)))
    lines += bear_items(start)
    write("stats/counters.txt", "\n".join(lines) + "\n")
    log("counters: %s, %d player-games, %d lines", patch["name"], len(games), len(lines))
    return {"n": len(games), "patch": patch["name"]}


ANSWERS_EVERY = 3 * 86400
ANSWERS_WINDOW = 7 * 86400
ANSWERS_STEP = 300
ANSWERS_MAX = 75 * 60
ANSWERS_MAJOR = 1800
ANSWERS_MIN_COST = 1000
ANSWERS_MIN_BUYS = 100
ANSWERS_KEPT = 0.25
ANSWERS_LAM = 4.0
ANSWERS_DOM = 0.7
ANSWERS_MINE = (1, 2, 3, 4, 5, 6)
ANSWERS_RICH = (2, 4, 6, 9, 12, 15, 19, 24)
ANSWERS_LIFT = 1.4
ANSWERS_Z_HERO = 4.0
ANSWERS_Z_ITEM = 5.0
ANSWERS_OBS = 20
ANSWERS_FINAL = 0.03
ANSWERS_FINAL_GAMES = 30
ANSWERS_FINAL_LONG = 40 * 60
ANSWERS_COMPAT = 0.2
ANSWERS_COMPAT_EXP = 10
ANSWERS_SIT_LIFT = 1.3
ANSWERS_SIT_Z = 3.0
ANSWERS_CONS = ("dust", "ward_sentry", "gem")
ANSWERS_SQL = (
    "select pm.match_id m, pm.hero_id h, pm.player_slot s, pm.gold_per_min g, m.duration d, "
    "pm.item_0 i0, pm.item_1 i1, pm.item_2 i2, pm.item_3 i3, pm.item_4 i4, pm.item_5 i5, pm.backpack_0 b0, pm.backpack_1 b1, pm.backpack_2 b2, "
    "(select string_agg((x->>'key') || ':' || (x->>'time'), ' ') from unnest(pm.purchase_log) x) p "
    "from matches m join player_matches pm using (match_id) where m.start_time >= %d and m.start_time < %d"
)
ANSWERS_SLOTS = ("i0", "i1", "i2", "i3", "i4", "i5", "b0", "b1", "b2")


def answers():
    import calendar
    import numpy as np
    path = OUT / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    prev = (manifest.get("sets") or {}).get("answers") or {}
    patch = get(API + "constants/patch")[-1]
    if prev.get("patch") == patch["name"] and time.time() - prev.get("time", 0) < ANSWERS_EVERY and (OUT / "stats/answers.txt").exists():
        log("answers: fresh, skipped")
        return None
    start = calendar.timegm(time.strptime(patch["date"][:19], "%Y-%m-%dT%H:%M:%S"))
    consts = get(API + "constants/items")
    cost = {k: int(v.get("cost") or 0) for k, v in consts.items() if isinstance(v, dict)}
    by_id = {int(v["id"]): k for k, v in consts.items() if isinstance(v, dict) and v.get("id")}
    cons = {k for k, v in consts.items() if isinstance(v, dict) and v.get("qual") == "consumable"} - {"gem"}

    by_match, lo, now = {}, start, int(time.time())
    while lo < now:
        for r in explorer(ANSWERS_SQL % (lo, lo + ANSWERS_WINDOW)):
            if r.get("p"):
                by_match.setdefault(r["m"], []).append(r)
        lo += ANSWERS_WINDOW
    players = []
    for ps in by_match.values():
        if len(ps) != 10:
            continue
        for p in ps:
            buys = []
            for t in p["p"].split():
                k, _, s = t.rpartition(":")
                buys.append((int(s), k))
            buys.sort()
            p["b"], p["r"] = buys, p["s"] < 128
        for p in ps:
            players.append((p, [q for q in ps if q["r"] != p["r"]]))
    if len(players) < 20000:
        raise RuntimeError("too few pro players: %d" % len(players))

    bought, kept = {}, {}
    for p, _ in players:
        fin = {by_id.get(p.get(k) or 0) for k in ANSWERS_SLOTS}
        for k in {k for _, k in p["b"]}:
            bought[k] = bought.get(k, 0) + 1
            kept[k] = kept.get(k, 0) + (k in fin)

    def big(k):
        return k not in cons and not k.startswith("recipe") and cost.get(k, 0) >= ANSWERS_MIN_COST and bought[k] >= ANSWERS_MIN_BUYS

    complete = {k for k in bought if big(k) and kept[k] / bought[k] >= ANSWERS_KEPT}
    targets = sorted(complete | {k for k in ANSWERS_CONS if k in bought})
    parents = {}
    for k, v in consts.items():
        if isinstance(v, dict):
            for c in v.get("components") or []:
                parents.setdefault(c, set()).add(k)
    then = {}
    for p, _ in players:
        for i, (_, k) in enumerate(p["b"]):
            if k in parents and k not in complete:
                nxt = next((k2 for _, k2 in p["b"][i + 1:] if k2 in parents[k]), None)
                then.setdefault(k, {})[nxt] = then.setdefault(k, {}).get(nxt, 0) + 1
    dom = {}
    for k, c in then.items():
        total = sum(c.values())
        top = max((x for x in c if x is not None), key=lambda x: c[x], default=None)
        if top in complete and total >= ANSWERS_MIN_BUYS and c[top] / total >= ANSWERS_DOM:
            dom[k] = top
    expo = sorted(complete)
    heroes = sorted({p["h"] for p, _ in players})
    ti = {k: i for i, k in enumerate(targets)}
    xs = [("i", k) for k in expo] + [("h", h) for h in heroes]
    xi = {k: i for i, k in enumerate(xs)}
    nx = len(xs)

    def bucket(n, cuts):
        return next((i for i, c in enumerate(cuts) if n < c), len(cuts))

    sid, S, own, ev, ex = {}, [], ([0], []), ([0], []), ([0], [])
    for p, en in players:
        first = {}
        for t, k in p["b"]:
            if k in ti and k not in first:
                first[k] = t
        mine = [t for t, k in p["b"] if cost.get(k, 0) >= ANSWERS_MAJOR]
        theirs = sorted((t, k) for q in en for t, k in q["b"])
        rich = [t for t, k in theirs if cost.get(k, 0) >= ANSWERS_MAJOR]
        seen = {}
        for t, k in theirs:
            k = k if k in complete else dom.get(k)
            if k:
                seen.setdefault(k, t)
        hx = [xi[("h", q["h"])] for q in en]
        L = 0
        while L + ANSWERS_STEP <= min(p["d"], ANSWERS_MAX):
            key = (L // ANSWERS_STEP, p["h"], bucket(sum(t < L for t in mine), ANSWERS_MINE), bucket(sum(t < L for t in rich), ANSWERS_RICH))
            S.append(sid.setdefault(key, len(sid)))
            for (ptr, idx), vals in ((own, [ti[k] for k, t in first.items() if t < L]),
                                     (ev, [ti[k] for k, t in first.items() if L <= t < L + ANSWERS_STEP]),
                                     (ex, hx + [xi[("i", k)] for k, t in seen.items() if t < L and ("i", k) in xi])):
                idx += vals
                ptr.append(len(idx))
            L += ANSWERS_STEP
    S = np.array(S)
    n, ns = len(S), len(sid)

    def rows_of(pair):
        return np.repeat(np.arange(n), np.diff(np.array(pair[0]))), np.array(pair[1], dtype=np.int64)

    own_r, own_t = rows_of(own)
    ev_r, ev_t = rows_of(ev)
    ex_r, ex_x = rows_of(ex)
    del own, ev, ex
    log("answers: %d players, %d records, %d strata, %d targets, %d exposures", len(players), n, ns, len(targets), nx)

    lines = ["n %d" % len(players), "v %s" % patch["name"]] + ["d %s %s" % kv for kv in sorted(dom.items())]
    for j, name in enumerate(targets):
        risk = np.ones(n, bool)
        risk[own_r[own_t == j]] = False
        y = np.zeros(n)
        y[ev_r[ev_t == j]] = 1
        y *= risk
        R = np.bincount(S, weights=risk, minlength=ns)
        E = np.bincount(S, weights=y, minlength=ns)
        base = np.where(risk & (R[S] >= 2), (E[S] - y) / np.maximum(R[S] - 1, 1), 0.0)
        live = base > 0
        keep = np.nonzero(live)[0]
        remap = -np.ones(n, np.int64)
        remap[keep] = np.arange(len(keep))
        sel = remap[ex_r] >= 0
        rr, xx = remap[ex_r[sel]], ex_x[sel]
        m_n, yv, lp = len(keep), y[keep], np.log(base[keep])

        def xv(v):
            return np.bincount(rr, weights=v[xx], minlength=m_n)

        def xtv(v):
            return np.bincount(xx, weights=v[rr], minlength=nx)

        obs = xtv(yv)
        beta = np.zeros(nx)
        m = np.exp(lp)
        ll = np.sum(yv * lp - m)
        g_prev = z_prev = d_prev = None
        for _ in range(300):
            g = obs - xtv(m) - ANSWERS_LAM * beta
            z = g / (xtv(m) + ANSWERS_LAM)
            d = z
            if d_prev is not None:
                d = z + max(0.0, (z @ (g - g_prev)) / max(z_prev @ g_prev, 1e-12)) * d_prev
                if d @ g <= 0:
                    d = z
            xd, t = xv(d), 0.0
            for _ in range(8):
                mt = m * np.exp(t * xd)
                f1 = np.sum((yv - mt) * xd) - ANSWERS_LAM * (beta + t * d) @ d
                f2 = -np.sum(mt * xd * xd) - ANSWERS_LAM * d @ d
                t -= f1 / f2
                if abs(f1 / f2) < 1e-6:
                    break
            beta = beta + t * d
            eta = lp + xv(beta)
            m = np.exp(eta)
            new = np.sum(yv * eta - m) - ANSWERS_LAM / 2 * beta @ beta
            g_prev, z_prev, d_prev = g, z, d
            if abs(new - ll) < 1e-9 * max(1.0, abs(ll)):
                break
            ll = new
        zs = beta * np.sqrt(xtv(m) + ANSWERS_LAM)
        lift = np.exp(beta)
        sig = np.where((lift >= ANSWERS_SIT_LIFT) & (zs >= ANSWERS_SIT_Z), beta, 0.0)
        lines.append("s %s %d" % (name, round(1000 * np.sum(yv * (1 - np.exp(-xv(sig)))) / max(np.sum(yv), 1))))
        for i in np.nonzero((lift >= ANSWERS_LIFT) & (obs >= ANSWERS_OBS))[0]:
            kind, x = xs[i]
            if zs[i] >= (ANSWERS_Z_HERO if kind == "h" else ANSWERS_Z_ITEM):
                lines.append("%s %s %s %d" % ("e" if kind == "h" else "x", name, x, round(lift[i] * 100)))

    base_n, base_c = {}, {}
    for ps in by_match.values():
        if len(ps) != 10:
            continue
        for side in (True, False):
            team = sorted((q for q in ps if q["r"] == side), key=lambda q: -(q.get("g") or 0))
            for k, q in enumerate(team):
                key = (q["h"], 1 if k < 3 else 2)
                base_n[key] = base_n.get(key, 0) + 1
                have = {b for _, b in q["b"]}
                for it in ANSWERS_CONS:
                    if it in have:
                        base_c[key + (it,)] = base_c.get(key + (it,), 0) + 1
    for key, cnt in sorted(base_n.items()):
        if cnt >= 30:
            for it in ANSWERS_CONS:
                lines.append("p %d %d %s %d" % (key[0], key[1], it, round(1000 * base_c.get(key + (it,), 0) / cnt)))
    lines += answers_compat(by_match, complete)
    lines += answers_finals(by_match, by_id, cons)
    lines += bear_items(start)
    write("stats/answers.txt", "\n".join(lines) + "\n")
    log("answers: %s, %d lines", patch["name"], len(lines))
    return {"n": len(players), "patch": patch["name"]}


def answers_finals(by_match, by_id, cons):
    games, have = {}, {}
    for ps in by_match.values():
        if len(ps) != 10:
            continue
        for side in (True, False):
            team = sorted((q for q in ps if q["r"] == side), key=lambda q: -(q.get("g") or 0))
            for k, q in enumerate(team):
                if (q.get("d") or 0) < ANSWERS_FINAL_LONG:
                    continue
                key = (q["h"], 1 if k < 3 else 2)
                games[key] = games.get(key, 0) + 1
                for name in {by_id.get(q.get(slot) or 0) for slot in ANSWERS_SLOTS}:
                    if name and name not in cons and not name.startswith("recipe"):
                        have[key + (name,)] = have.get(key + (name,), 0) + 1
    lines = []
    for key, n in sorted(games.items()):
        if n < ANSWERS_FINAL_GAMES:
            continue
        lines.append("g %d %d %d" % (key[0], key[1], n))
        for (h, t, name), c in sorted(have.items()):
            if (h, t) == key and c / n >= ANSWERS_FINAL:
                lines.append("f %d %d %s %d" % (h, t, name, round(1000 * c / n)))
    return lines


def answers_compat(by_match, items):
    lines = []
    for tier in (1, 2):
        sets = []
        for ps in by_match.values():
            if len(ps) != 10:
                continue
            for side in (True, False):
                team = sorted((q for q in ps if q["r"] == side), key=lambda q: -(q.get("g") or 0))
                for k, q in enumerate(team):
                    if (1 if k < 3 else 2) == tier:
                        sets.append(sorted({b for _, b in q["b"] if b in items}))
        n = len(sets)
        one, two = {}, {}
        for s in sets:
            for i, a in enumerate(s):
                one[a] = one.get(a, 0) + 1
                for b in s[i + 1:]:
                    two[(a, b)] = two.get((a, b), 0) + 1
        names = sorted(one)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                exp = one[a] * one[b] / n
                lift = (two.get((a, b), 0) + 1) / (exp + 1)
                if exp >= ANSWERS_COMPAT_EXP and lift <= ANSWERS_COMPAT:
                    lines.append("c %d %s %s %d" % (tier, a, b, round(lift * 100)))
    return lines


def model(key, recs, prior=None):
    import draft_model
    if len(recs) < 5000:
        raise RuntimeError("too few matches: %d" % len(recs))
    base = None
    if prior:
        path = OUT / "stats" / ("model_%s.txt" % prior)
        base = path.read_text(encoding="utf-8") if path.exists() else None
    write("stats/model_%s.txt" % key, draft_model.fit(recs, log, base))
    return True


def step(key, fn):
    try:
        result = fn()
        log("%s: ok, %d calls", key, calls)
        return result
    except Exception as e:
        log("%s: failed, kept old: %s", key, e)
        return None


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    manifest["v"] = 1
    sets = manifest.setdefault("sets", {})
    now = int(time.time())

    step("heroes", heroes)
    if not (OUT / "heroes.json").exists():
        raise SystemExit("no heroes list")

    done = step("items", items)
    if done:
        sets["items"] = {"n": done, "time": now, "src": "d2pt", "min": D2PT_MATCHES}
        sets["build"] = {"n": done, "time": now}
        step("roles", heroes)

    done = step("counters", counters)
    if done:
        sets["counters"] = dict(done, time=now)

    done = step("answers", answers)
    if done:
        sets["answers"] = dict(done, time=now)

    newest = None
    for rank in RANKS:
        recs = step("ap %d" % rank, lambda: update_ranked(rank))
        if recs:
            newest = max(newest or 0, rec_id(recs[0]))
            write("stats/ap_%d.txt" % rank, stats(recs))
            sets["ap_%d" % rank] = dict(describe(recs), time=now)
            if step("model ap %d" % rank, lambda: model("ap_%d" % rank, recs)):
                sets["model_ap_%d" % rank] = {"n": len(recs), "time": now}

    def cm():
        top = newest or int(explorer("select max(match_id) m from public_matches")[0]["m"])
        return update_cm(top)

    recs = step("cm", cm)
    if recs is not None:
        for rank in RANKS:
            part = [r for r in recs if rec_tier(r) >= rank]
            write("stats/cm_%d.txt" % rank, stats(part))
            sets["cm_%d" % rank] = dict(describe(part), time=now)
            if step("model cm %d" % rank, lambda: model("cm_%d" % rank, part, "ap_%d" % rank)):
                sets["model_cm_%d" % rank] = {"n": len(part), "time": now}

    manifest["time"] = now
    path.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8", newline="\n")
    log("done, %d calls", calls)


if __name__ == "__main__":
    main()
