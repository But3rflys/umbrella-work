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
QUICK = os.environ.get("DRAFT_DATA_QUICK") == "1"
RULES_ONLY = os.environ.get("DRAFT_DATA_RULES_ONLY") == "1"
RULES = Path(__file__).resolve().parents[1] / "scripts" / "draft_helper" / "rules.json"
API = "https://api.opendota.com/api/"
HEADERS = {"User-Agent": "umbrella-work/draft-data", "Accept": "application/json"}

RANKS = [70] if QUICK else [0, 60, 70, 75]
VOLUMES = [2000, 4000] if QUICK else [50000, 100000, 200000]
PAGE = 2000
PAGE_CM = 500
PAGE_MIN = 100
CM_WINDOW = 4000000
CM_DAYS = 60
CM_MAX = 40000
CM_WINDOWS_MAX = 3 if QUICK else 200
BUYS_MATCHES = [6000, 3000, 1500]
BUYS_PATCHES = 3
BUYS_WANT = 40
BUYS_CAP = 1500
BUYS_OLD = ("p", "i", "n", "w", "t", "s", "m", "g", "gw")
VS_PAGE = 800
VS_PAGES = 2 if QUICK else 10
VS_PRIOR = 10
VS_EXP_MIN = 6
VS_OBS_MIN = 12
VS_LIFT_MIN = 1.4
VS_KEEP = 8
VS_COST = 1000
VS_SQL = (
    "with m as (select match_id from matches where match_id < %d and match_id in (select match_id from player_matches "
    "where purchase_log is not null) order by match_id desc limit %d) "
    "select pm.match_id m, (pm.player_slot<128)::int r, pm.hero_id h, coalesce(pm.gold_per_min,0) g, "
    "(select string_agg(distinct v->>'key', '.') from unnest(pm.purchase_log) v where v->>'key' in (%s)) i "
    "from player_matches pm join m using(match_id)"
)
PRO_MATCHES = 6000
CONTEST_MATCHES = 2000
GAP = 1.2
CALLS_MAX = 1800
REC = struct.Struct("<QI10sBB")

BUYS_SQL = (
    "with prk as (select patch, row_number() over (order by min(match_id) desc) k from match_patch group by "
    "patch), p0 as (select pm.match_id, pm.player_slot<128 r, pm.purchase_log, ((pm.player_slot<128) = "
    "m.radiant_win) won, m.duration dur, m.radiant_gold_adv adv, m.leagueid lg, pm.additional_units au, "
    "array[pm.item_0,pm.item_1,pm.item_2,pm.item_3,pm.item_4,pm.item_5,pm.backpack_0,pm.backpack_1,pm.backpack_2] "
    "fin from player_matches pm join matches m using(match_id) where pm.hero_id=%d and pm.purchase_log is not "
    "null and pm.leaver_status = 0 and m.duration >= 900 order by pm.match_id desc limit %d), p1 as (select p0.*, "
    "prk.k, case lt.tier when 'premium' then 3 when 'professional' then 2 else 1 end w0 from p0 join match_patch "
    "mp using(match_id) join prk using(patch) left join leagues lt on lt.leagueid = p0.lg where prk.k <= %d), tm "
    "as (select pm.match_id, pm.hero_id, coalesce(pm.lane_role,4) l, pm.gold_per_min gp from player_matches pm "
    "join p1 on p1.match_id=pm.match_id and (pm.player_slot<128)=p1.r where pm.gold_per_min is not null), c as "
    "(select *, row_number() over (partition by match_id, l order by gp desc) lr from tm), d as (select *, case "
    "when l in (1,2,3) and lr=1 then l end core from c), e as (select *, row_number() over (partition by "
    "match_id, (core is null) order by gp desc) sr from d), q0 as (select e.match_id, coalesce(core, case when "
    "sr=1 then 4 else 5 end) pos, p1.k from e join p1 using(match_id) where hero_id=%d), cum as (select pos, k, "
    "sum(count(*)) over (partition by pos order by k) cg from q0 group by pos, k), lim as (select pos, "
    "coalesce(min(k) filter (where cg >= %d), max(k)) kmax from cum group by pos), q1 as (select q0.match_id, "
    "q0.pos, row_number() over (partition by q0.pos order by q0.match_id desc) rn from q0 join lim using(pos) "
    "where q0.k <= lim.kmax), q as (select q1.match_id, q1.pos, p1.w0::float8 * count(*) over (partition by "
    "q1.pos) / sum(p1.w0) over (partition by q1.pos) wt from q1 join p1 using(match_id) where q1.rn <= %d), p as "
    "(select p1.* from p1 join q using(match_id)), x as (select p.match_id, q.pos, q.wt, p.won, v->>'key' i, "
    "(v->>'time')::int t, coalesce((case when p.r then 1 else -1 end) * p.adv[least(coalesce(array_length(p.adv, "
    "1), 1), greatest(1, (v->>'time')::int / 60 + 1))], 0) ga from p join q using(match_id), "
    "unnest(p.purchase_log) v), f as (select match_id, pos, wt, won, i, min(t) t, sum(case when t<=0 then 1 else "
    "0 end) s, (array_agg(ga order by t))[1] ga from x group by 1,2,3,4,5), kk as (select distinct p.match_id, "
    "q.pos, q.wt, p.dur, unnest(p.fin) it from p join q using(match_id)), ku as (select distinct p.match_id, "
    "q.pos, q.wt, (u->>x)::int it from p join q using(match_id), unnest(p.au) u, "
    "unnest(array['item_0','item_1','item_2','item_3','item_4','item_5','backpack_0','backpack_1','backpack_2']) "
    "x where p.au is not null), g as (select q.pos, sum(q.wt) g, sum(case when p.won then q.wt else 0 end) gw, "
    "sum(case when p.dur >= 2400 then q.wt else 0 end) g40, sum(case when p.dur >= 2400 and p.won then q.wt else "
    "0 end) gw40 from q join p using(match_id) group by q.pos), bm as (select q.pos, mm.m, sum(case when (case "
    "when p.r then 1 else -1 end) * p.adv[mm.m + 1] <= -2000 then q.wt else 0 end) nb, sum(case when (case when "
    "p.r then 1 else -1 end) * p.adv[mm.m + 1] <= -2000 and p.won then q.wt else 0 end) wb from q join p "
    "using(match_id) cross join unnest(array[5,10,15,20,25,30,35,40,45,50]) mm(m) where array_length(p.adv, 1) > "
    "mm.m group by q.pos, mm.m), a as (select f.pos p, i, sum(f.wt) n, sum(case when won then f.wt else 0 end) w, "
    "percentile_cont(0.5) within group (order by t)::int t, sum(s * f.wt) s, sum(case when s>0 then f.wt else 0 "
    "end) m, sum(f.wt / (1 + "
    "exp(-(array[0.6,0.59,0.384,0.294,0.277,0.264,0.233,0.193,0.173,0.147,0.119,0.105,0.088])[least(13, "
    "greatest(1, round(f.t / 300.0)::int + 1))] * f.ga / 1000.0))) x from f join g using(pos) group by f.pos, i "
    "having sum(f.wt) >= greatest(2, max(g.g) * 0.03)), b as (select a.p, a.i, sum(f.wt) filter (where f.t <= "
    "a.t) ne, sum(f.wt) filter (where f.t <= a.t and f.won) we, sum(f.wt) filter (where f.ga <= -2000) nb, "
    "sum(f.wt) filter (where f.ga <= -2000 and f.won) wb from a join f on f.pos = a.p and f.i = a.i group by 1, "
    "2), fk as (select kk.pos, kk.it, sum(kk.wt) n from kk join items on items.id = kk.it where items.cost >= "
    "2000 and items.recipe = 0 group by 1, 2), fp as (select fk.* from fk join g using(pos) where fk.n >= g.g * "
    "0.08), kp as (select k1.pos, k1.it i1, k2.it i2, sum(k1.wt) nab from kk k1 join kk k2 on k2.match_id = "
    "k1.match_id and k2.pos = k1.pos and k1.it < k2.it group by 1, 2, 3) select a.p, a.i, round(a.n) n, "
    "round(a.w) w, a.t, round(a.s) s, round(a.m) m, round(g.g) g, round(g.gw) gw, round(b.ne) ne, round(b.we) we, "
    "round(b.nb) nb, round(b.wb) wb, round(a.x::numeric, 1) x from a join b on b.p = a.p and b.i = a.i join g on "
    "g.pos = a.p union all select kk.pos, '#' || it, round(sum(kk.wt)), null, null, null, null, round(max(g.g)), "
    "round(max(g.gw)), null, null, null, null, null from kk join g using(pos) where it > 0 group by kk.pos, it "
    "having sum(kk.wt) >= greatest(2, max(g.g) * 0.03) union all select ku.pos, '&' || it, round(sum(ku.wt)), "
    "null, null, null, null, round(max(g.g)), round(max(g.gw)), null, null, null, null, null from ku join g "
    "using(pos) where it > 0 group by ku.pos, it having sum(ku.wt) >= greatest(2, max(g.g) * 0.03) union all "
    "select kk.pos, '%%' || it, round(sum(kk.wt)), null, null, null, null, round(max(g.g40)), round(max(g.gw40)), "
    "null, null, null, null, null from kk join g using(pos) where it > 0 and kk.dur >= 2400 group by kk.pos, it "
    "having sum(kk.wt) >= greatest(2, max(g.g40) * 0.05) union all select bm.pos, '!' || bm.m, round(bm.nb), "
    "round(bm.wb), null, null, null, round(g.g), round(g.gw), null, null, null, null, null from bm join g "
    "using(pos) where bm.nb > 0 union all select a.pos, '=' || a.it || '.' || b.it, 1, null, null, null, null, "
    "round(g.g), round(g.gw), null, null, null, null, null from fp a join fp b on b.pos = a.pos and a.it < b.it "
    "join g on g.pos = a.pos left join kp on kp.pos = a.pos and kp.i1 = a.it and kp.i2 = b.it where a.n * b.n >= "
    "5 * g.g and coalesce(kp.nab, 0) * g.g < 0.4 * a.n * b.n union all select lim.pos, '@' || prk.patch, "
    "lim.kmax, null, null, null, null, round(max(g.g)), round(max(g.gw)), null, null, null, null, null from lim "
    "join prk on prk.k = lim.kmax join g using(pos) group by lim.pos, prk.patch, lim.kmax"
)

POS_SQL = (
    "with m as (select match_id from matches order by match_id desc limit %d), "
    "p as (select pm.match_id, pm.hero_id h, pm.player_slot<128 t, coalesce(pm.lane_role,4) l, pm.gold_per_min g "
    "from player_matches pm join m using(match_id) where pm.gold_per_min is not null), "
    "c as (select *, row_number() over (partition by match_id, t, l order by g desc) lr from p), "
    "d as (select *, case when l in (1,2,3) and lr=1 then l end core from c), "
    "e as (select *, row_number() over (partition by match_id, t, (core is null) order by g desc) sr from d) "
    "select h, coalesce(core, case when sr=1 then 4 else 5 end) pos, count(*) n from e group by 1,2"
) % PRO_MATCHES

CONTEST_SQL = (
    "with m as (select match_id from matches where game_mode=2 order by match_id desc limit %d) "
    "select hero_id h, count(*) c, (select count(*) from m) n from picks_bans join m using(match_id) group by 1"
) % CONTEST_MATCHES

calls = 0


def log(msg, *args):
    print(msg % args if args else msg, flush=True)


def get(url, timeout=150):
    global calls
    if calls >= CALLS_MAX:
        raise RuntimeError("call budget spent")
    last = None
    for attempt in range(6):
        time.sleep(GAP)
        calls += 1
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            last = "http %d" % e.code
            if e.code == 400:
                try:
                    err = json.loads(e.read()).get("err")
                except Exception:
                    err = None
                raise RuntimeError("explorer: %s" % str(err)[:160] if err else last)
            if e.code == 429:
                time.sleep(40 * (attempt + 1))
                continue
            if e.code >= 500:
                time.sleep(10 * (attempt + 1))
                continue
            raise RuntimeError(last)
        except Exception as e:
            last = type(e).__name__
            time.sleep(10 * (attempt + 1))
    raise RuntimeError("no answer (%s)" % last)


def explorer(sql):
    data = json.loads(get(API + "explorer?sql=" + urllib.parse.quote(sql)))
    if data.get("err"):
        raise RuntimeError("explorer: %s" % str(data["err"])[:160])
    return data.get("rows") or []


def buys_rows(h):
    for i, limit in enumerate(BUYS_MATCHES):
        try:
            rows = explorer(BUYS_SQL % (h, limit, BUYS_PATCHES, h, BUYS_WANT, BUYS_CAP))
        except RuntimeError as e:
            if "timeout" in str(e).lower() and i + 1 < len(BUYS_MATCHES):
                log("  build %d: timeout at %d matches, retry smaller", h, limit)
                continue
            raise
        return [{k: v for k, v in r.items() if v is not None} for r in rows]
    raise RuntimeError("no rows")


def rec_id(rec):
    return struct.unpack_from("<Q", rec)[0]


def rec_time(rec):
    return struct.unpack_from("<I", rec, 8)[0]


def rec_tier(rec):
    return rec[23]


def to_rec(row):
    m, r, d, w = row.get("m"), row.get("r"), row.get("d"), row.get("w")
    if m is None or not isinstance(r, list) or not isinstance(d, list) or w not in (True, False):
        return None
    ids = r + d
    if len(ids) != 10 or any(not isinstance(x, int) or x < 1 or x > 255 for x in ids):
        return None
    return REC.pack(int(m), int(row.get("s") or 0), bytes(ids), 1 if w else 0, max(0, min(255, int(row.get("t") or 0))))


def matches_sql(source, rank, above, below, page):
    where = ["game_mode=2" if source == 1 else "lobby_type=7"]
    if rank > 0:
        where.append("avg_rank_tier>=%d" % rank)
    if above is not None:
        where.append("match_id>%d" % above)
    if below is not None:
        where.append("match_id<%d" % below)
    return ("select match_id m, radiant_team r, dire_team d, radiant_win w, avg_rank_tier t, start_time s "
            "from public_matches where %s order by match_id desc limit %d") % (" and ".join(where), page)


class Pager:
    def __init__(self, page):
        self.page = page

    def rows(self, source, rank, above, below):
        while True:
            try:
                return explorer(matches_sql(source, rank, above, below, self.page))
            except RuntimeError as e:
                if "timeout" in str(e).lower() and self.page > PAGE_MIN:
                    self.page = max(PAGE_MIN, self.page // 2)
                    log("  timeout, page %d", self.page)
                    continue
                raise


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


def update_ranked(rank, recs):
    target = max(VOLUMES)
    pager = Pager(PAGE)
    top = rec_id(recs[0]) if recs else None
    newer, cursor = [], None
    while True:
        rows = pager.rows(0, rank, top, cursor)
        newer += [x for x in map(to_rec, rows) if x]
        ids = [int(r["m"]) for r in rows if r.get("m") is not None]
        if len(rows) < pager.page or not ids or len(newer) >= target:
            break
        cursor = min(ids)
    merged = (newer + recs)[:target]
    cursor = rec_id(merged[-1]) if merged else None
    while len(merged) < target:
        rows = pager.rows(0, rank, None, cursor)
        merged += [x for x in map(to_rec, rows) if x]
        ids = [int(r["m"]) for r in rows if r.get("m") is not None]
        if len(rows) < pager.page or not ids:
            break
        cursor = min(ids)
    log("  rank %d: %d new, %d total", rank, len(newer), len(merged[:target]))
    return merged[:target]


def update_cm(recs, newest_id, floor_id):
    cutoff = int(time.time()) - CM_DAYS * 86400
    top = rec_id(recs[0]) if recs else None
    found, hi, width, windows, reached = [], newest_id + 1, CM_WINDOW, 0, None
    while windows < CM_WINDOWS_MAX:
        lo = hi - width
        stop = False
        if top is not None and lo <= top:
            lo, stop = top, True
        cursor, oldest = hi, None
        try:
            while True:
                rows = explorer(matches_sql(1, 0, lo, cursor, PAGE_CM))
                found += [x for x in map(to_rec, rows) if x]
                times = [int(r["s"]) for r in rows if r.get("s")]
                if times:
                    oldest = min(times + ([oldest] if oldest else []))
                ids = [int(r["m"]) for r in rows if r.get("m") is not None]
                if len(rows) < PAGE_CM or not ids:
                    break
                cursor = min(ids)
        except RuntimeError as e:
            if "timeout" not in str(e).lower():
                if top is not None:
                    raise
                log("  cm stopped early: %s", e)
                break
            if width > 250000:
                width //= 2
                log("  cm timeout, window %d", width)
                continue
            log("  cm window below %d skipped after timeouts", hi)
        windows += 1
        if oldest:
            reached = min(reached or oldest, oldest)
        if windows % 10 == 0:
            log("  cm: %d windows, %d found, back to %s", windows, len(found),
                time.strftime("%Y-%m-%d", time.gmtime(reached)) if reached else "?")
        if stop or (oldest and oldest < cutoff) or lo <= floor_id:
            break
        hi = lo + 1
    merged = found + recs
    seen, out = set(), []
    for rec in merged:
        i = rec_id(rec)
        if i not in seen and rec_time(rec) >= cutoff:
            seen.add(i)
            out.append(rec)
    out.sort(key=rec_id, reverse=True)
    log("  cm: %d new, %d total in %d windows", len(found), len(out), windows)
    return out


def stats_texts(recs, cuts):
    bg, bw = [0] * 256, [0] * 256
    vg, vw, sg, sw = {}, {}, {}, {}
    out, want = {}, sorted(set(min(c, len(recs)) for c in cuts))
    for n, rec in enumerate(recs, 1):
        h = rec[12:22]
        rad = rec[22] == 1
        for j in range(10):
            a = h[j]
            bg[a] += 1
            if (j < 5) == rad:
                bw[a] += 1
        for j in range(5):
            a = h[j]
            for l in range(5, 10):
                c = h[l]
                if a < c:
                    key, won = a * 256 + c, rad
                else:
                    key, won = c * 256 + a, not rad
                vg[key] = vg.get(key, 0) + 1
                if won:
                    vw[key] = vw.get(key, 0) + 1
        for t in (0, 5):
            won = (t == 0) == rad
            for j in range(4):
                a = h[t + j]
                for l in range(j + 1, 5):
                    c = h[t + l]
                    key = a * 256 + c if a < c else c * 256 + a
                    sg[key] = sg.get(key, 0) + 1
                    if won:
                        sw[key] = sw.get(key, 0) + 1
        if n in want:
            lines = ["n %d" % n]
            lines += ["b %d %d %d" % (a, bg[a], bw[a]) for a in range(256) if bg[a]]
            lines += ["v %d %d %d" % (k, vg[k], vw.get(k, 0)) for k in sorted(vg)]
            lines += ["s %d %d %d" % (k, sg[k], sw.get(k, 0)) for k in sorted(sg)]
            out[n] = "\n".join(lines) + "\n"
    if not recs:
        out[0] = "n 0\n"
    return {c: out[min(c, len(recs))] for c in cuts}


def write(name, text):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def step(manifest, key, fn):
    try:
        fn()
        manifest[key] = int(time.time())
        log("%s: ok (%d calls)", key, calls)
    except Exception as e:
        log("%s: failed, kept old: %s", key, e)


def vs_rows(names):
    inlist = ",".join("'%s'" % n for n in names)
    top = int(explorer("select max(match_id) m from matches")[0]["m"]) + 1
    rows = []
    for _ in range(VS_PAGES):
        part = explorer(VS_SQL % (top, VS_PAGE, inlist))
        if not part:
            break
        rows += part
        top = min(int(r["m"]) for r in part)
    return rows


def vs_compute(rows):
    matches = {}
    for r in rows:
        matches.setdefault(r["m"], []).append(r)
    players = []
    for ps in matches.values():
        if len(ps) != 10:
            continue
        for side in (0, 1):
            team = sorted([p for p in ps if p["r"] == side], key=lambda p: -(p["g"] or 0))
            foes = [p["h"] for p in ps if p["r"] != side]
            for k, p in enumerate(team):
                its = set((p["i"] or "").split(".")) - {""}
                players.append((p["h"], "c" if k < 3 else "s", its, foes))
    games, buys = {}, {}
    for h, c, its, _ in players:
        games[(h, c)] = games.get((h, c), 0) + 1
        for i in its:
            buys[(h, c, i)] = buys.get((h, c, i), 0) + 1
    rates = {}
    for (h, c, i), n in buys.items():
        rates.setdefault((h, c), {})[i] = n / games[(h, c)]
    obs, exp = {}, {}
    for h, c, its, foes in players:
        rate = rates.get((h, c), {})
        for e in foes:
            for i, rt in rate.items():
                exp[(e, c, i)] = exp.get((e, c, i), 0) + rt
            for i in its:
                obs[(e, c, i)] = obs.get((e, c, i), 0) + 1
    found = {}
    for (e, c, i), x in exp.items():
        o = obs.get((e, c, i), 0)
        lift = (o + VS_PRIOR) / (x + VS_PRIOR)
        if x >= VS_EXP_MIN and o >= VS_OBS_MIN and lift >= VS_LIFT_MIN:
            found.setdefault(e, {}).setdefault(c, []).append((lift, i))
    out = {}
    for e, by in found.items():
        out[str(e)] = {c: {i: round(l, 2) for l, i in sorted(lst, reverse=True)[:VS_KEEP]} for c, lst in by.items()}
    return out, len(matches)


def copy_rules(manifest):
    if not RULES.exists():
        log("rules: no file")
        return
    try:
        text = RULES.read_text(encoding="utf-8")
        rules = json.loads(text)
        if rules.get("v") != 1:
            raise RuntimeError("bad version")
    except Exception as e:
        log("rules: broken, kept old: %s", e)
        return
    vs_path = OUT / "vs.json"
    if vs_path.exists():
        try:
            rules["vs"] = json.loads(vs_path.read_text(encoding="utf-8"))
            text = json.dumps(rules, ensure_ascii=False, separators=(",", ":"))
        except Exception as e:
            log("rules: vs skipped: %s", e)
    dst = OUT / "rules.json"
    if dst.exists() and dst.read_text(encoding="utf-8") == text and "rules" in manifest:
        log("rules: unchanged")
        return
    write("rules.json", text)
    manifest["rules"] = int(time.time())
    log("rules: updated")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    mpath = OUT / "manifest.json"
    manifest = json.loads(mpath.read_text(encoding="utf-8")) if mpath.exists() else {}
    manifest.setdefault("sets", {})
    manifest["v"] = 1
    copy_rules(manifest)
    if RULES_ONLY:
        mpath.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8", newline="\n")
        log("rules only, done")
        return

    heroes = []

    def do_heroes():
        data = json.loads(get(API + "heroes"))
        keep = ("id", "name", "localized_name", "primary_attr", "attack_type", "roles")
        heroes[:] = [{k: h.get(k) for k in keep} for h in data if isinstance(h, dict) and h.get("id")]
        if len(heroes) < 100:
            raise RuntimeError("bad heroes list")
        write("heroes.json", json.dumps(heroes, ensure_ascii=False, separators=(",", ":")))

    def do_items():
        data = json.loads(get(API + "constants/items"))
        recipes = {name[7:]: int(it["id"]) for name, it in data.items()
                   if name.startswith("recipe_") and isinstance(it, dict) and it.get("id") is not None}
        items = []
        for name, it in data.items():
            if name.startswith("recipe") or not isinstance(it, dict) or it.get("id") is None:
                continue
            parts = [p for p in (it.get("components") or []) if isinstance(p, str)]
            item = {"id": int(it["id"]), "n": name, "d": it.get("dname") or name, "c": int(it.get("cost") or 0),
                    "m": 1 if it.get("created") else 0, "p": ",".join(parts)}
            if name in recipes:
                item["r"] = recipes[name]
            items.append(item)
        if len(items) < 100:
            raise RuntimeError("bad items list")
        items.sort(key=lambda x: x["id"])
        write("items.json", json.dumps(items, ensure_ascii=False, separators=(",", ":")))

    def do_pro():
        pro = {"pos": explorer(POS_SQL), "contest": explorer(CONTEST_SQL)}
        if len(pro["pos"]) < 100 or len(pro["contest"]) < 50:
            raise RuntimeError("bad pro data")
        write("pro.json", json.dumps(pro, separators=(",", ":")))

    def do_builds():
        ids = [h["id"] for h in heroes] if heroes else [h["id"] for h in json.loads((OUT / "heroes.json").read_text())]
        if QUICK:
            ids = ids[:3]
        ok = 0
        for h in ids:
            try:
                rows = buys_rows(h)
                write("builds2/%d.json" % h, json.dumps(rows, separators=(",", ":")))
                old = [{k: r.get(k) for k in BUYS_OLD} for r in rows if str(r.get("i", ""))[:1] not in "%!=@"]
                write("builds/%d.json" % h, json.dumps(old, separators=(",", ":")))
                ok += 1
            except Exception as e:
                log("  build %d failed: %s", h, e)
        log("  builds: %d of %d", ok, len(ids))
        if ok < len(ids) * 0.8:
            raise RuntimeError("too many build failures")
        manifest["builds2"] = int(time.time())

    step(manifest, "heroes", do_heroes)
    step(manifest, "items", do_items)
    step(manifest, "pro", do_pro)
    step(manifest, "builds", do_builds)

    def do_vs():
        items = json.loads((OUT / "items.json").read_text(encoding="utf-8"))
        names = sorted(i["n"] for i in items if i.get("m") == 1 and int(i.get("c") or 0) >= VS_COST)
        out, n = vs_compute(vs_rows(names))
        if n < (VS_PAGE if QUICK else VS_PAGE * 5):
            raise RuntimeError("too few matches: %d" % n)
        write("vs.json", json.dumps(out, separators=(",", ":"), sort_keys=True))
        log("  vs: %d matches, %d heroes", n, len(out))

    step(manifest, "vs", do_vs)
    copy_rules(manifest)

    newest = None
    rate = None
    for rank in RANKS:
        name = "0_%d.bin.gz" % rank
        try:
            recs = update_ranked(rank, load_raw(name))
        except Exception as e:
            log("rank %d: failed, kept old: %s", rank, e)
            continue
        save_raw(name, recs)
        if recs:
            first, last = recs[0], recs[-1]
            newest = max(newest or 0, rec_id(first))
            if rank == 0 and rec_time(first) > rec_time(last):
                rate = (rec_id(first) - rec_id(last)) / (rec_time(first) - rec_time(last))
        now = int(time.time())
        for vol, text in stats_texts(recs, VOLUMES).items():
            write("stats/0_%d_%d.txt" % (rank, vol), text)
            manifest["sets"]["0:%d:%d" % (rank, vol)] = {"n": min(vol, len(recs)), "time": now,
                                                         "oldest": rec_time(recs[min(vol, len(recs)) - 1]) if recs else 0}
        log("rank %d: stats written (%d calls)", rank, calls)

    try:
        if newest is None:
            newest = int(explorer("select match_id m from public_matches order by match_id desc limit 1")[0]["m"])
        floor_id = int(newest - (rate or 30) * CM_DAYS * 86400 * 1.2)
        cm = update_cm(load_raw("1_0.bin.gz"), newest, floor_id)
        save_raw("1_0.bin.gz", cm)
        now = int(time.time())
        for rank in RANKS:
            recs = [r for r in cm if rec_tier(r) >= rank][:CM_MAX]
            text = stats_texts(recs, [CM_MAX])[CM_MAX]
            write("stats/1_%d_%d.txt" % (rank, CM_MAX), text)
            manifest["sets"]["1:%d:%d" % (rank, CM_MAX)] = {"n": len(recs), "time": now,
                                                          "oldest": rec_time(recs[-1]) if recs else 0}
        log("cm: stats written (%d calls)", calls)
    except Exception as e:
        log("cm: failed, kept old: %s", e)

    manifest["time"] = int(time.time())
    mpath.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8", newline="\n")
    log("done, %d calls", calls)


if __name__ == "__main__":
    main()
