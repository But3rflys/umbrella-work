import gzip
import json
import os
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

    newest = None
    for rank in RANKS:
        recs = step("ap %d" % rank, lambda: update_ranked(rank))
        if recs:
            newest = max(newest or 0, rec_id(recs[0]))
            write("stats/ap_%d.txt" % rank, stats(recs))
            sets["ap_%d" % rank] = dict(describe(recs), time=now)

    def cm():
        top = newest or int(explorer("select max(match_id) m from public_matches")[0]["m"])
        return update_cm(top)

    recs = step("cm", cm)
    if recs is not None:
        for rank in RANKS:
            part = [r for r in recs if rec_tier(r) >= rank]
            write("stats/cm_%d.txt" % rank, stats(part))
            sets["cm_%d" % rank] = dict(describe(part), time=now)

    manifest["time"] = now
    path.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8", newline="\n")
    log("done, %d calls", calls)


if __name__ == "__main__":
    main()
