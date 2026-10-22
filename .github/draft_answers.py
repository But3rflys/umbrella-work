"""Контр-предметы для draft_helper: landmark-логистика по про-матчам текущего патча (OpenDota).

python3 draft_answers.py DATA_DIR CACHE_DIR
Покупки докачиваются по неделям, кэш в CACHE_DIR/raw_<patch>.jsonl. Результат: DATA_DIR/stats/answers.txt
и запись sets.answers в DATA_DIR/manifest.json.

Для каждого целевого предмета T берём минуту L (20-й перцентиль покупок T). Строки: игроки, чья игра
длилась >= L+10 и кто не купил T до L. Исход: купил T после L. Признаки: свободный член на героя и тир
(кор/саппорт), вражеские герои, вражеские предметы, купленные до L. Все признаки в одной модели, поэтому
эффекты в клиенте складываются в логитах, а не перемножаются.
"""
import json, sys, time, urllib.parse, urllib.request
from collections import Counter, defaultdict
from pathlib import Path
import numpy as np

API = "https://api.opendota.com/api/"
DATA, CACHE = Path(sys.argv[1]), Path(sys.argv[2])
WEEK = 7 * 86400
T0 = time.time()
SQL = (
    "select pm.match_id m, ma.start_time t, pm.player_slot s, pm.hero_id h, pm.gold_per_min g, ma.duration d, "
    "(select string_agg((x->>'key') || ':' || (x->>'time'), ' ') from unnest(pm.purchase_log) x) p "
    "from matches ma join player_matches pm using (match_id) "
    "where ma.start_time >= %d and ma.start_time < %d and pm.purchase_log is not null"
)


def log(msg, *args):
    print(time.strftime("%H:%M:%S"), msg % args if args else msg, flush=True)


def get(url):
    last = None
    for a in range(6):
        time.sleep(1.2)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "umbrella-work/draft-answers"}), timeout=180) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(15 * (a + 1))
    raise RuntimeError("no answer: %s" % last)


patch = get(API + "constants/patch")[-1]
start = int(time.mktime(time.strptime(patch["date"][:19], "%Y-%m-%dT%H:%M:%S"))) - time.timezone
CACHE.mkdir(parents=True, exist_ok=True)
raw = CACHE / ("raw_%s.jsonl" % patch["name"])
for old in CACHE.glob("raw_*.jsonl"):
    if old != raw:
        old.unlink()
rows = [json.loads(l) for l in raw.open(encoding="utf-8")] if raw.exists() else []
lo = max([r["t"] for r in rows if r.get("t")] or [start])
lo = max(start, lo - 2 * 86400)
rows = [r for r in rows if r.get("t", 0) < lo]
now = int(time.time())
while lo < now:
    part = get(API + "explorer?sql=" + urllib.parse.quote(SQL % (lo, min(lo + WEEK, now)))).get("rows") or []
    rows += part
    log("week %s: %d rows", time.strftime("%Y-%m-%d", time.gmtime(lo)), len(part))
    lo += WEEK
with raw.open("w", encoding="utf-8") as f:
    for r in rows:
        f.write(json.dumps(r, separators=(",", ":")) + "\n")
log("patch %s, %d rows cached", patch["name"], len(rows))

CONSUMABLE_TARGETS = ("dust", "ward_sentry", "gem")
MIN_BUYERS = 300
TARGET_COST = 1000
FEATURE_COST = 1400
FEATURE_N = 100
LAMBDA = 4.0
Z_MIN = 3.0
B_MIN = 0.35
B_MIN_ITEM = 0.6

consts = get(API + "constants/items")
cost = {k: int(v.get("cost") or 0) for k, v in consts.items() if isinstance(v, dict)}
parents = defaultdict(set)
for k, v in consts.items():
    if isinstance(v, dict):
        for c in v.get("components") or []:
            parents[c].add(k)

# --- игроки
by_match = defaultdict(list)
for r in rows:
    if r.get("p") and r.get("g") is not None and r.get("d"):
        by_match[r["m"]].append(r)
players = []
for ps in by_match.values():
    if len(ps) != 10:
        continue
    teams = [sorted([p for p in ps if (p["s"] < 128) == side], key=lambda p: -p["g"]) for side in (True, False)]
    if any(len(t) != 5 for t in teams):
        continue
    buys = {}
    for t in teams:
        for p in t:
            first = {}
            for tok in p["p"].split(" "):
                k, _, s = tok.rpartition(":")
                if k and k not in first:
                    first[k] = int(s)
            buys[id(p)] = first
    for t, other in ((teams[0], teams[1]), (teams[1], teams[0])):
        for k, p in enumerate(t):
            players.append({
                "h": p["h"], "tier": 0 if k < 3 else 1, "d": p["d"], "b": buys[id(p)],
                "en": [q["h"] for q in other], "eb": [buys[id(q)] for q in other],
            })
log("players %d", len(players))

heroes = sorted({p["h"] for p in players})
hidx = {h: i for i, h in enumerate(heroes)}
H = len(heroes)

buyers = Counter()
times = defaultdict(list)
for p in players:
    for k, s in p["b"].items():
        buyers[k] += 1
        times[k].append(s)


def mostly_component(k):
    # компонент, который в большинстве случаев доводят до одного из родителей
    if not parents.get(k):
        return False
    n = up = 0
    for p in players:
        s = p["b"].get(k)
        if s is None:
            continue
        n += 1
        if any(p["b"].get(par, -1) > s for par in parents[k]):
            up += 1
    return n > 0 and up / n >= 0.6


targets = [k for k, n in buyers.items() if n >= MIN_BUYERS and cost.get(k, 0) >= TARGET_COST and not k.startswith("recipe")]
targets = [k for k in targets if not mostly_component(k)] + [k for k in CONSUMABLE_TARGETS if buyers[k] >= MIN_BUYERS]
feat_items = [k for k, n in buyers.most_common() if cost.get(k, 0) >= FEATURE_COST and not k.startswith("recipe")][:FEATURE_N]
fidx = {k: i for i, k in enumerate(feat_items)}
log("targets %d, enemy item features %d", len(targets), len(feat_items))

# базовые доли по герою и тиру (для расходников, которых нет в D2PT)
base_n, base_c = Counter(), Counter()
for p in players:
    key = (p["h"], p["tier"])
    base_n[key] += 1
    for k in CONSUMABLE_TARGETS:
        if k in p["b"]:
            base_c[key + (k,)] += 1


def hess(X, W, pen):
    return ((X * W[:, None].astype(np.float32)).T @ X).astype(np.float64) + np.diag(pen)


def fit(X, y, grp, nG, pen):
    # логистика со свободным членом на группу (герой x тир), группы — смещение, не столбцы
    n_g = np.bincount(grp, minlength=nG) + 2.0
    a = np.log((np.bincount(grp, weights=y, minlength=nG) + 1.0) / (n_g - np.bincount(grp, weights=y, minlength=nG) - 1.0 + 1e-9) + 1e-9)
    w = np.zeros(X.shape[1])
    for _ in range(12):
        z = a[grp] + X @ w
        mu = 1 / (1 + np.exp(-z))
        g = (X.T @ (mu - y).astype(np.float32)).astype(np.float64) + pen * w
        step = np.linalg.solve(hess(X, mu * (1 - mu), pen), g)
        w -= step
        z = a[grp] + X @ w
        mu = 1 / (1 + np.exp(-z))
        a -= np.bincount(grp, weights=mu - y, minlength=nG) / (np.bincount(grp, weights=mu * (1 - mu), minlength=nG) + 0.1)
        if np.max(np.abs(step)) < 1e-4:
            break
    z = a[grp] + X @ w
    mu = 1 / (1 + np.exp(-z))
    se = np.sqrt(np.clip(np.diag(np.linalg.inv(hess(X, mu * (1 - mu), pen))), 1e-12, None))
    return w, se


lines_e, lines_x, lines_l = [], [], []
P = len(players)
F = len(feat_items)
INF = 10 ** 9
fe = np.array([hidx[p["h"]] * 2 + p["tier"] for p in players])
EN = np.array([[hidx[e] for e in p["en"]] for p in players])
ET = np.full((P, F), INF, dtype=np.int64)
for i, p in enumerate(players):
    for eb in p["eb"]:
        for k, s in eb.items():
            j = fidx.get(k)
            if j is not None and s < ET[i, j]:
                ET[i, j] = s
dur = np.array([p["d"] for p in players])
t0 = time.time()
for T in targets:
    L = max(3 * 60, int(np.percentile(times[T], 20)))
    myT = np.array([p["b"].get(T, INF) for p in players])
    sel = np.where((dur >= L + 600) & (myT >= L))[0]
    if len(sel) < 2000:
        continue
    n = len(sel)
    X = np.zeros((n, H + F), dtype=np.float32)
    for c in range(5):
        X[np.arange(n), EN[sel, c]] = 1
    X[:, H:] = ET[sel] < L
    y = (myT[sel] < INF).astype(np.float64)
    cnt = X.sum(0)
    keep = cnt >= 20
    w, se = fit(X[:, keep], y, fe[sel], 2 * H, np.full(int(keep.sum()), LAMBDA))
    full_w = np.zeros(H + F); full_se = np.ones(H + F)
    full_w[keep], full_se[keep] = w, se
    ne = nx = 0
    for j in range(H + F):
        b, z = full_w[j], full_w[j] / full_se[j]
        if b >= B_MIN and z >= Z_MIN and cnt[j] >= 50:
            if j < H:
                lines_e.append("e %s %d %d" % (T, heroes[j], round(b * 1000))); ne += 1
            else:
                if b >= B_MIN_ITEM:
                    lines_x.append("x %s %s %d" % (T, feat_items[j - H], round(b * 1000))); nx += 1
    lines_l.append("l %s %d" % (T, L // 60))
    log("%-24s L=%2d rows=%6d buy=%.3f heroes+%d items+%d", T, L // 60, n, y.mean(), ne, nx)

out = ["n %d" % len(players)]
for (h, tier), n in sorted(base_n.items()):
    if n >= 30:
        for k in CONSUMABLE_TARGETS:
            out.append("p %d %d %s %d" % (h, tier + 1, k, round(1000 * base_c[(h, tier, k)] / n)))
out += lines_l + lines_e + lines_x
out.insert(1, "v %s" % patch["name"])
(DATA / "stats").mkdir(parents=True, exist_ok=True)
(DATA / "stats" / "answers.txt").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
mpath = DATA / "manifest.json"
manifest = json.loads(mpath.read_text(encoding="utf-8")) if mpath.exists() else {"v": 1, "sets": {}}
manifest.setdefault("sets", {})["answers"] = {"n": len(players), "patch": patch["name"], "time": int(time.time())}
mpath.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8", newline="\n")
log("answers: %s, %d player-games, %d lines, %.0fs", patch["name"], len(players), len(out), time.time() - T0)
