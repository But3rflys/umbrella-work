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
POS_MATCHES = 6000
GAP = 1.1
CALLS_MAX = 1900
D2PT = "https://dota2protracker.com/hero/"
D2PT_GAP = 3
D2PT_EVERY = 3 * 86400
D2PT_MATCHES = 100
D2PT_FINAL = 0.01

REC = struct.Struct("<QI10sBB")

MATCH_COLS = "match_id m, start_time s, radiant_team r, dire_team d, radiant_win w, avg_rank_tier t"

POS_SQL = (
    "with m as (select match_id from matches order by match_id desc limit %d), "
    "p as (select pm.match_id, pm.hero_id h, pm.player_slot < 128 t, coalesce(pm.lane_role, 4) l, pm.gold_per_min g "
    "from player_matches pm join m using (match_id) where pm.gold_per_min is not null), "
    "c as (select *, row_number() over (partition by match_id, t, l order by g desc) lr from p), "
    "d as (select *, case when l in (1, 2, 3) and lr = 1 then l end core from c), "
    "e as (select *, row_number() over (partition by match_id, t, (core is null) order by g desc) sr from d) "
    "select h, coalesce(core, case when sr = 1 then 4 else 5 end) pos, count(*) n from e group by 1, 2"
) % POS_MATCHES

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


def heroes():
    data = get(API + "heroes")
    pos = {}
    for row in explorer(POS_SQL):
        pos.setdefault(int(row["h"]), [0] * 5)[int(row["pos"]) - 1] += int(row["n"])
    out = []
    for h in data:
        if not isinstance(h, dict) or not h.get("id") or not str(h.get("name", "")).startswith("npc_dota_hero_"):
            continue
        counts = pos.get(h["id"], [0] * 5)
        total = sum(counts)
        shares = [round(c * 100 / total) for c in counts] if total else [0] * 5
        out.append({"id": h["id"], "name": h["name"][14:], "attr": h.get("primary_attr") or "all", "pos": shares})
    if len(out) < 100:
        raise RuntimeError("bad heroes list")
    out.sort(key=lambda x: x["id"])
    write("heroes.json", json.dumps(out, separators=(",", ":")))
    log("heroes: %d", len(out))


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
    if prev.get("src") == "d2pt" and prev.get("min") == D2PT_MATCHES and time.time() - prev.get("time", 0) < D2PT_EVERY and (OUT / "stats/items.txt").exists():
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
    rows, seen, pages, heroes, patch = [], set(), 0, 0, ""
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
        main = int(str(node.get("position")).replace("pos ", ""))
        stats = {x.get("position"): x.get("matches") or 0 for x in node.get("heroStats") or []}
        for pos in range(1, 6):
            n = stats.get("pos %d" % pos, 0)
            if pos == main or n < D2PT_MATCHES:
                continue
            try:
                extra = d2pt_rows(hid, d2pt_page(info["displayName"], pos)[1]["data"], seen)
            except Exception as e:
                log("items: %s pos %d skipped: %s", info.get("displayName"), pos, e)
                continue
            if extra:
                pages += 1
                rows += extra
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
    return pages


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

    done = step("counters", counters)
    if done:
        sets["counters"] = dict(done, time=now)

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
