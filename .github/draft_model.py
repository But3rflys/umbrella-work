import numpy as np

REC = np.dtype([("m", "<u8"), ("t", "<u4"), ("h", "u1", 10), ("w", "u1"), ("r", "u1")])
IU = [(i, j) for i in range(5) for j in range(i + 1, 5)]
II = np.array([i for i, _ in IU])
JJ = np.array([j for _, j in IU])
DELTA_GRID = [(1e-2, 1e-1, 1e-1), (3e-2, 3e-1, 3e-1)]
GRID = [(1e-5, lv, ls) for lv in (2e-3, 3e-3, 5e-3, 1e-2, 2e-2) for ls in (3e-3, 5e-3, 1e-2, 3e-2)]


def sig(x):
    return 1 / (1 + np.exp(-x))


def array(recs):
    a = np.frombuffer(b"".join(recs), dtype=REC)
    return a[np.argsort(a["t"], kind="stable")]


class Prior:
    def __init__(self, text):
        self.c, self.b = 0.0, np.zeros(256)
        self.s, self.v = np.zeros((256, 256)), np.zeros((256, 256))
        for line in text.splitlines():
            p = line.split()
            if not p:
                continue
            if p[0] == "c":
                self.c = int(p[1]) / 10000
            elif p[0] == "b":
                self.b[int(p[1])] = int(p[2]) / 10000
            elif p[0] == "s":
                x = int(p[3]) / 10000
                self.s[int(p[1]), int(p[2])] = self.s[int(p[2]), int(p[1])] = x
            elif p[0] == "v":
                x = int(p[3]) / 10000
                self.v[int(p[1]), int(p[2])], self.v[int(p[2]), int(p[1])] = x, -x

    def z(self, a):
        h = a["h"].astype(np.int64)
        R, D = h[:, :5], h[:, 5:]
        z = self.c + self.b[R].sum(1) - self.b[D].sum(1)
        z += self.s[R[:, II], R[:, JJ]].sum(1) - self.s[D[:, II], D[:, JJ]].sum(1)
        z += self.v[R[:, :, None], D[:, None, :]].reshape(len(a), 25).sum(1)
        return z


class Feats:
    def __init__(self, a, idx, n, prior=None):
        h = idx[a["h"].astype(np.int64)]
        self.R, self.D, self.N = h[:, :5], h[:, 5:], n
        self.y = (a["w"] == 1).astype(float)
        self.vrd = (self.R[:, :, None] * n + self.D[:, None, :]).reshape(len(a), 25)
        self.vdr = (self.D[:, None, :] * n + self.R[:, :, None]).reshape(len(a), 25)
        self.sR = np.minimum(self.R[:, II], self.R[:, JJ]) * n + np.maximum(self.R[:, II], self.R[:, JJ])
        self.sD = np.minimum(self.D[:, II], self.D[:, JJ]) * n + np.maximum(self.D[:, II], self.D[:, JJ])
        self.off = prior.z(a) if prior else 0

    def z(self, P):
        b, V, S, c = P
        return (self.off + c[0] + b[self.R].sum(1) - b[self.D].sum(1) + V[self.vrd].sum(1) - V[self.vdr].sum(1)
                + S[self.sR].sum(1) - S[self.sD].sum(1))


def bc(idx, w, n):
    return np.bincount(idx.ravel(), weights=w.ravel(), minlength=n)


def train(f, l2, it=600, lr=0.05, tol=1e-7):
    N = f.N
    P = [np.zeros(N), np.zeros(N * N), np.zeros(N * N), np.zeros(1)]
    lb, lv, ls = l2
    m = [np.zeros_like(p) for p in P]
    v = [np.zeros_like(p) for p in P]
    W = len(f.y)
    prev = None
    for t in range(1, it + 1):
        p = sig(f.z(P))
        g = (p - f.y) / W
        g5, g25, g10 = (np.repeat(g[:, None], k, 1) for k in (5, 25, 10))
        grads = (bc(f.R, g5, N) - bc(f.D, g5, N) + lb * P[0],
                 bc(f.vrd, g25, N * N) - bc(f.vdr, g25, N * N) + lv * P[1],
                 bc(f.sR, g10, N * N) - bc(f.sD, g10, N * N) + ls * P[2],
                 np.array([g.sum()]))
        for k, gr in enumerate(grads):
            m[k] = 0.9 * m[k] + 0.1 * gr
            v[k] = 0.999 * v[k] + 0.001 * gr * gr
            P[k] -= lr * (m[k] / (1 - 0.9 ** t)) / (np.sqrt(v[k] / (1 - 0.999 ** t)) + 1e-8)
        if t % 25 == 0:
            pc = np.clip(p, 1e-9, 1 - 1e-9)
            loss = -np.mean(f.y * np.log(pc) + (1 - f.y) * np.log(1 - pc)) \
                + 0.5 * (lb * (P[0] ** 2).sum() + lv * (P[1] ** 2).sum() + ls * (P[2] ** 2).sum())
            if prev is not None and prev - loss < tol:
                break
            prev = loss
    return P


def quality(z, y):
    p = np.clip(sig(z), 1e-9, 1 - 1e-9)
    ll = -np.mean(y * np.log(p) + (1 - y) * np.log(1 - p))
    order = np.argsort(p)
    r = np.empty(len(p))
    r[order] = np.arange(len(p))
    pos = y == 1
    auc = (r[pos].sum() - pos.sum() * (pos.sum() - 1) / 2) / (pos.sum() * (~pos).sum())
    return ll, auc


def fit(recs, log, prior=None):
    a = array(recs)
    prior = Prior(prior) if prior else None
    ids = np.unique(a["h"])
    idx = np.zeros(256, dtype=np.int64)
    idx[ids] = np.arange(len(ids))
    N = len(ids)
    c1, c2 = int(len(a) * 0.7), int(len(a) * 0.85)
    ftr, fva, fte = (Feats(x, idx, N, prior) for x in (a[:c1], a[c1:c2], a[c2:]))
    best = None
    for l2 in (DELTA_GRID if prior else GRID):
        ll, _ = quality(fva.z(train(ftr, l2)), fva.y)
        if best is None or ll < best[0]:
            best = (ll, l2)
    l2 = best[1]
    ll, auc = quality(fte.z(train(Feats(a[:c2], idx, N, prior), l2)), fte.y)
    log("model: n %d, prior %s, l2 %s, test logloss %.5f auc %.4f", len(a), prior is not None, l2, ll, auc)
    b, V, S, c = train(Feats(a, idx, N, prior), l2)
    V, S = V.reshape(N, N), S.reshape(N, N)
    if prior:
        c = c + prior.c
        b = b + prior.b[ids]
        S = S + prior.s[np.ix_(ids, ids)]
        V = V + np.where(np.arange(N)[:, None] < np.arange(N)[None, :], prior.v[np.ix_(ids, ids)], 0)
    lines = ["n %d" % len(a), "q %.5f %.4f" % (ll, auc), "c %d" % round(c[0] * 10000)]
    lines += ["b %d %d" % (ids[i], round(b[i] * 10000)) for i in range(N)]
    for i in range(N):
        for j in range(i + 1, N):
            if abs(S[i, j]) >= 0.0005:
                lines.append("s %d %d %d" % (ids[i], ids[j], round(S[i, j] * 10000)))
            x = V[i, j] - V[j, i]
            if abs(x) >= 0.0005:
                lines.append("v %d %d %d" % (ids[i], ids[j], round(x * 10000)))
    return "\n".join(lines) + "\n"
