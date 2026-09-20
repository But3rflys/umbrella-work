NL = chr(10)

THEMES = {
    "light": {
        "surface": "#ffffff",
        "text": "#141412",
        "muted": "#5c5b55",
        "grid": "#ebeae6",
        "axis": "#d7d6d1",
        "series": "#141412",
        "fill": "#141412",
        "fill_opacity": "0.05",
    },
    "dark": {
        "surface": "#0a0a0a",
        "text": "#e9e9ea",
        "muted": "#7d7d85",
        "grid": "#1a1a1c",
        "axis": "#2a2a2d",
        "series": "#e9e9ea",
        "fill": "#e9e9ea",
        "fill_opacity": "0.05",
    },
}

W, H = 840, 280
PAD_L, PAD_R, PAD_T, PAD_B = 56, 26, 62, 38
FONT = "ui-sans-serif, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif"


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def nice_bounds(values):
    lo, hi = min(values), max(values)
    if lo == hi:
        pad = max(5, int(abs(hi) * 0.05) or 5)
        lo, hi = lo - pad, hi + pad
    else:
        span = hi - lo
        lo, hi = lo - span * 0.15, hi + span * 0.15
    lo = max(0, lo)
    step = 10 ** max(0, len(str(int(hi - lo))) - 2)
    lo = int(lo // step * step)
    hi = int(-(-hi // step) * step)
    return lo, hi


def ticks(lo, hi, count=4):
    step = (hi - lo) / count
    return [int(round(lo + step * i)) for i in range(count + 1)]


def build(days, totals, theme_name):
    t = THEMES[theme_name]
    lo, hi = nice_bounds(totals)
    plot_w = W - PAD_L - PAD_R
    plot_h = H - PAD_T - PAD_B
    n = len(totals)

    def px(i):
        if n == 1:
            return PAD_L + plot_w / 2
        return PAD_L + plot_w * i / (n - 1)

    def py(v):
        return PAD_T + plot_h * (1 - (v - lo) / (hi - lo))

    o = []
    o.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-label="%s">'
             % (W, H, W, H, esc("Downloads: %d" % totals[-1])))
    o.append('<rect width="%d" height="%d" fill="%s"/>' % (W, H, t["surface"]))
    o.append('<text x="%d" y="34" font-family="%s" font-size="15" font-weight="600" fill="%s">%s</text>'
             % (PAD_L - 30, FONT, t["text"], esc("Загрузки, всего")))

    for v in ticks(lo, hi):
        y = py(v)
        o.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="1"/>'
                 % (PAD_L, y, W - PAD_R, y, t["grid"]))
        o.append('<text x="%d" y="%.1f" text-anchor="end" font-family="%s" font-size="11" fill="%s">%d</text>'
                 % (PAD_L - 10, y + 4, FONT, t["muted"], v))

    o.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="1"/>'
             % (PAD_L, py(lo), W - PAD_R, py(lo), t["axis"]))

    pts = [(px(i), py(v)) for i, v in enumerate(totals)]
    if n > 1:
        area = "M %.1f %.1f " % (pts[0][0], py(lo))
        area += " ".join("L %.1f %.1f" % p for p in pts)
        area += " L %.1f %.1f Z" % (pts[-1][0], py(lo))
        o.append('<path d="%s" fill="%s" fill-opacity="%s"/>' % (area, t["fill"], t["fill_opacity"]))
        line = " ".join("%.1f,%.1f" % p for p in pts)
        o.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>'
                 % (line, t["series"]))

    lx, ly = pts[-1]
    o.append('<circle cx="%.1f" cy="%.1f" r="4.5" fill="%s" stroke="%s" stroke-width="2"/>'
             % (lx, ly, t["series"], t["surface"]))
    anchor = "end" if lx > W - PAD_R - 60 else "middle"
    o.append('<text x="%.1f" y="%.1f" text-anchor="%s" font-family="%s" font-size="13" font-weight="600" fill="%s">%d</text>'
             % (lx, ly - 14, anchor, FONT, t["text"], totals[-1]))

    show = set([0, n - 1])
    if n > 4:
        show |= {int(round(i * (n - 1) / 4)) for i in range(5)}
    for i, d in enumerate(days):
        if i in show:
            o.append('<text x="%.1f" y="%d" text-anchor="middle" font-family="%s" font-size="11" fill="%s">%s</text>'
                     % (px(i), H - PAD_B + 24, FONT, t["muted"], esc(d)))

    o.append("</svg>")
    return NL.join(o) + NL
