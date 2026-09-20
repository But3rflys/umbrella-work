import html
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
OUT = BASE / "site"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
REPO = CATALOG["repo"]
SITE = CATALOG["site"]
NL = chr(10)
NBSP = " "

FONTS = ("https://fonts.googleapis.com/css2?family=Geist+Mono:wght@400;500"
         "&family=Geist:wght@400;450;500;600&display=swap")
FA = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css"
FAVICON = ("data:image/svg+xml,"
           "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Crect width='32' height='32' fill='%230a0a0b'/%3E"
           "%3Crect x='7' y='7' width='18' height='18' fill='none' stroke='%23ededef' "
           "stroke-width='2'/%3E%3C/svg%3E")

CSS = """
:root{
  --bg:#0a0a0b;--sur:#0f0f11;--sur-2:#141417;--line:#1d1d21;--line-2:#2b2b31;
  --fg:#ededef;--fg-2:#a1a1aa;--fg-3:#71717a;--inv:#0a0a0b;
  --sans:"Geist",system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;
  --mono:"Geist Mono",ui-monospace,SFMono-Regular,Consolas,monospace;
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.6 var(--sans);
  -webkit-font-smoothing:antialiased;touch-action:manipulation;
  -webkit-tap-highlight-color:rgba(237,237,239,.12);overflow-x:hidden}
.wrap{max-width:820px;margin:0 auto;padding:0 24px}
a{color:inherit;text-decoration:none}
p{margin:0 0 14px;max-width:62ch}
:focus-visible{outline:2px solid var(--fg);outline-offset:2px}
.skip{position:absolute;left:-9999px;top:0;background:var(--fg);color:var(--inv);
  padding:10px 14px;font:500 13px var(--mono);z-index:20}
.skip:focus{left:24px;top:12px}
.mono{font-family:var(--mono);font-variant-numeric:tabular-nums}

.top{display:flex;align-items:center;justify-content:space-between;gap:16px;
  padding:20px 0;border-bottom:1px solid var(--line)}
.crumbs{font:400 13px var(--mono);color:var(--fg-3);min-width:0;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.crumbs a{color:var(--fg-2)}
.crumbs a:hover{color:var(--fg)}
.crumbs .sep{padding:0 7px;color:var(--line-2)}
.crumbs .here{color:var(--fg)}
.tools{display:flex;align-items:center;gap:14px;flex:none}
.lang{display:flex;align-items:center;font:400 12px var(--mono);color:var(--fg-3)}
.lang button{border:0;background:none;color:var(--fg-3);font:inherit;padding:4px 5px;
  cursor:pointer;touch-action:manipulation}
.lang button:hover{color:var(--fg-2)}
.lang button[aria-pressed="true"]{color:var(--fg)}
.lang .div{color:var(--line-2);padding:0 2px}
.gh{font:400 12px var(--mono);color:var(--fg-3)}
.gh:hover{color:var(--fg)}

.intro{padding:64px 0 40px}
h1{font-size:clamp(34px,7vw,52px);font-weight:600;line-height:1.02;letter-spacing:-.035em;
  margin:0 0 14px;text-wrap:balance}
.page-head{display:flex;align-items:center;gap:14px;margin:0 0 14px}
.page-head h1{margin:0;font-size:clamp(28px,5.5vw,40px)}
.tagline{color:var(--fg-2);font-size:17px;margin:0;max-width:58ch;text-wrap:pretty}

.sec{margin:56px 0 0}
.sec-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px;
  padding-bottom:10px;border-bottom:1px solid var(--line);margin-bottom:22px}
h2{font:500 11px/1 var(--mono);letter-spacing:.14em;text-transform:uppercase;
  color:var(--fg-3);margin:0}
h3{font-size:15px;font-weight:500;margin:22px 0 6px}
.sec-note{font:400 11px var(--mono);color:var(--fg-3)}

table{width:100%;border-collapse:collapse}
caption{text-align:left;font:500 11px/1 var(--mono);letter-spacing:.14em;
  text-transform:uppercase;color:var(--fg-3);padding-bottom:10px}
th{font:400 11px/1 var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--fg-3);
  text-align:left;padding:0 14px 9px 0;border-bottom:1px solid var(--line);font-weight:400}
td{padding:14px 14px 14px 0;border-bottom:1px solid var(--line);vertical-align:middle}
th:last-child,td:last-child{padding-right:0;text-align:right}
tbody tr:hover{background:var(--sur)}
.idx{width:34px;color:var(--fg-3);font:400 12px var(--mono);font-variant-numeric:tabular-nums}
.who{min-width:0}
.who-line{display:flex;align-items:center;gap:11px;min-width:0}
.who a{font-weight:500}
tbody tr:hover .who a{text-decoration:underline;text-underline-offset:3px;
  text-decoration-thickness:1px}
.who .desc{display:block;color:var(--fg-3);font-size:13px;margin-top:3px;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.num,.tag,.when{font:400 12.5px var(--mono);color:var(--fg-2);
  font-variant-numeric:tabular-nums;white-space:nowrap}
.when,.muted{color:var(--fg-3)}
td a.file{color:var(--fg-2);text-decoration:underline;text-underline-offset:3px;
  text-decoration-color:var(--line-2)}
td a.file:hover{color:var(--fg);text-decoration-color:var(--fg)}

.ico{flex:none;display:grid;place-items:center;width:20px;height:20px;
  color:var(--fg-3);font-size:14px}
.ico img{display:block;width:20px;height:20px}
.page-head .ico{width:30px;height:30px;font-size:21px}
.page-head .ico img{width:30px;height:30px}

.grab{display:flex;flex-wrap:wrap;align-items:center;gap:10px 18px;margin:26px 0 0}
.get{display:inline-flex;align-items:center;gap:10px;background:var(--fg);color:var(--inv);
  font:500 13px var(--mono);padding:11px 16px;border:1px solid var(--fg)}
.get:hover{background:#fff;border-color:#fff}
.get .fa-solid{font-size:11px}
.stamp{font:400 12.5px var(--mono);color:var(--fg-3);font-variant-numeric:tabular-nums}
.stamp b{font-weight:500;color:var(--fg-2)}
.more{font:400 12.5px var(--mono);color:var(--fg-3)}
.more:hover{color:var(--fg);text-decoration:underline;text-underline-offset:3px}

.list{list-style:none;padding:0;margin:0;counter-reset:n;
  border-top:1px solid var(--line)}
.list li{counter-increment:n;display:grid;grid-template-columns:34px 1fr;gap:14px;
  padding:11px 0;border-bottom:1px solid var(--line)}
.list li::before{content:counter(n,decimal-leading-zero);color:var(--fg-3);
  font:400 12px var(--mono);font-variant-numeric:tabular-nums;padding-top:2px}
.steps{list-style:none;padding:0;margin:0;counter-reset:s}
.steps li{counter-increment:s;display:grid;grid-template-columns:34px 1fr;gap:14px;margin:10px 0}
.steps li::before{content:counter(s,decimal-leading-zero);color:var(--fg-3);
  font:400 12px var(--mono);font-variant-numeric:tabular-nums;padding-top:2px}
.body ul{list-style:none;padding:0;margin:0 0 14px}
.body ul li{position:relative;padding-left:17px;margin:5px 0}
.body ul li::before{content:"";position:absolute;left:0;top:11px;width:7px;height:1px;
  background:var(--fg-3)}
code{font:400 12.5px var(--mono);color:var(--fg);background:var(--sur-2);padding:2px 6px}
b{font-weight:500;color:var(--fg)}

.chart{margin:0;border:1px solid var(--line);background:var(--sur)}
.chart img{display:block;width:100%;height:auto}
figcaption{font:400 12px var(--mono);color:var(--fg-3);padding:10px 14px;
  border-top:1px solid var(--line);font-variant-numeric:tabular-nums}

footer{margin-top:72px;padding:22px 0 44px;border-top:1px solid var(--line);
  display:flex;gap:20px;flex-wrap:wrap;font:400 12px var(--mono);color:var(--fg-3)}
footer a:hover{color:var(--fg)}

.no-fa .fa-solid{display:none}
body[data-lang="ru"] [data-l="en"],body[data-lang="en"] [data-l="ru"]{display:none}

@media (max-width:680px){
  .intro{padding:44px 0 30px}
  .hide-sm{display:none}
  .who .desc{white-space:normal}
  td,th{padding-right:10px}
}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
"""

JS = """
(function(){
  var saved=null;
  try{saved=localStorage.getItem('uw-lang')}catch(e){}
  var lang=saved||((navigator.languages&&navigator.languages[0]||navigator.language||'en')
    .slice(0,2)==='ru'?'ru':'en');
  var buttons=document.querySelectorAll('.lang button');
  function set(v){
    document.body.dataset.lang=v;
    document.documentElement.lang=v;
    try{localStorage.setItem('uw-lang',v)}catch(e){}
    for(var i=0;i<buttons.length;i++)
      buttons[i].setAttribute('aria-pressed',String(buttons[i].dataset.set===v));
  }
  for(var i=0;i<buttons.length;i++)
    buttons[i].addEventListener('click',function(e){set(e.currentTarget.dataset.set)});
  set(lang);
  if(document.fonts&&document.fonts.ready){
    document.fonts.ready.then(function(){
      if(!document.fonts.check('900 14px "Font Awesome 6 Free"'))
        document.documentElement.classList.add('no-fa');
    });
  }
})();
"""

INSTALL = {
    "lua": {
        "ru": ["Скачай <code>%(file)s</code> из последнего релиза.",
               "Положи файл в папку <code>scripts</code> рядом с читом.",
               "Открой <b>Scripts</b> в меню чита и включи скрипт."],
        "en": ["Download <code>%(file)s</code> from the latest release.",
               "Put the file into the <code>scripts</code> folder next to your cheat.",
               "Open <b>Scripts</b> in the cheat menu and turn it on."],
    },
    "app": {
        "ru": ["Скачай <code>%(file)s</code> из последнего релиза и распакуй.",
               "Положи <code>MusicUI.lua</code> в папку <code>scripts</code> рядом с читом.",
               "Запусти <code>MusicUI.exe</code> и следуй подсказкам в консоли."],
        "en": ["Download <code>%(file)s</code> from the latest release and unzip it.",
               "Put <code>MusicUI.lua</code> into the <code>scripts</code> folder next to your cheat.",
               "Run <code>MusicUI.exe</code> and follow the prompts in the console."],
    },
}

WORDS = {
    "script": ("скрипт", "Script"),
    "version": ("версия", "Version"),
    "updated": ("обновлен", "Updated"),
    "downloads": ("загрузок", "Downloads"),
    "date": ("дата", "Date"),
    "file": ("файл", "File"),
    "features": ("Что умеет", "What It Does"),
    "install": ("Установка", "Install"),
    "versions": ("Версии", "Versions"),
    "changelog": ("Что нового", "Changelog"),
    "stats": ("Загрузки", "Downloads"),
    "none": ("нет релизов", "no releases"),
    "all": ("все релизы", "All Releases"),
    "skip": ("К содержимому", "Skip to content"),
}


def api(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print("releases unavailable: %d" % e.code)
        return []


def bi(key):
    ru, en = WORDS[key]
    return '<span data-l="ru">%s</span><span data-l="en">%s</span>' % (ru, en)


def pair(ru, en):
    return '<span data-l="ru">%s</span><span data-l="en">%s</span>' % (ru, en)


def glyph(code):
    return '<i class="fa-solid" aria-hidden="true">&#x%s;</i>' % code


def script_icon(script, size):
    value = script.get("icon", "")
    if value.startswith("img:"):
        return ('<span class="ico"><img src="%s" width="%d" height="%d" alt="" loading="lazy">'
                "</span>" % (value[4:], size, size))
    if value.startswith("fa:"):
        return '<span class="ico">%s</span>' % glyph(value[3:])
    return '<span class="ico"></span>'


def stamp(day):
    return '<time datetime="%s">%s</time>' % (day, day)


def md(text):
    out, buf, mode = [], [], None

    def inline(s):
        s = html.escape(s)
        s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
        s = re.sub(r"`(.+?)`", r'<code translate="no">\1</code>', s)
        s = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', s)
        return s

    def flush():
        if mode == "ul" and buf:
            out.append("<ul>" + "".join("<li>%s</li>" % b for b in buf) + "</ul>")
        elif mode == "p" and buf:
            out.append("<p>%s</p>" % " ".join(buf))
        del buf[:]

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            flush()
            mode = None
        elif line.startswith("- "):
            if mode != "ul":
                flush()
                mode = "ul"
            buf.append(inline(line[2:]))
        elif line.startswith("#"):
            flush()
            mode = None
            out.append("<h3>%s</h3>" % inline(line.lstrip("# ")))
        else:
            if mode != "p":
                flush()
                mode = "p"
            buf.append(inline(line))
    flush()
    return "".join(out)


def shell(title, description, url, crumb, body, depth):
    up = "../" * depth
    crumbs = ['<a href="%sindex.html" translate="no">umbrella-work</a>' % up]
    if crumb:
        crumbs.append('<span class="sep">/</span><span class="here">%s</span>' % html.escape(crumb))
    return NL.join([
        "<!doctype html>",
        '<html lang="en">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        "<title>%s</title>" % html.escape(title),
        '<meta name="description" content="%s">' % html.escape(description),
        '<meta name="color-scheme" content="dark">',
        '<meta name="theme-color" content="#0a0a0b">',
        '<meta property="og:type" content="website">',
        '<meta property="og:title" content="%s">' % html.escape(title),
        '<meta property="og:description" content="%s">' % html.escape(description),
        '<meta property="og:url" content="%s">' % html.escape(url),
        '<link rel="icon" href="%s">' % FAVICON,
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="preconnect" href="https://cdnjs.cloudflare.com" crossorigin>',
        '<link rel="stylesheet" href="%s">' % FONTS,
        '<link rel="stylesheet" href="%s">' % FA,
        "<style>%s</style>" % CSS,
        "</head>",
        '<body data-lang="en">',
        '<a class="skip" href="#main">%s</a>' % bi("skip"),
        '<div class="wrap">',
        '<header class="top">',
        '<nav class="crumbs" aria-label="breadcrumb">%s</nav>' % "".join(crumbs),
        '<div class="tools">',
        '<div class="lang" role="group" aria-label="Language">'
        '<button type="button" data-set="ru" aria-pressed="false">RU</button>'
        '<span class="div" aria-hidden="true">/</span>'
        '<button type="button" data-set="en" aria-pressed="true">EN</button></div>',
        '<a class="gh" href="https://github.com/%s" translate="no">GitHub</a>' % REPO,
        "</div>",
        "</header>",
        '<main id="main">',
        body,
        "</main>",
        "<footer>",
        '<a href="https://github.com/%s" translate="no">github.com/%s</a>' % (REPO, REPO),
        '<a href="https://github.com/%s/releases" translate="no">releases</a>' % REPO,
        "</footer>",
        "</div>",
        "<script>%s</script>" % JS,
        "</body>",
        "</html>",
        "",
    ])


def for_script(script, rels):
    prefix = script["tag"] + "-v"
    mine = [r for r in rels if r["tag_name"].startswith(prefix) and not r.get("draft")]
    mine.sort(key=lambda r: r.get("published_at") or "", reverse=True)
    return mine


def asset_of(rel, script):
    wanted = script["file"].lower()
    for a in rel.get("assets", []):
        if a["name"].lower() == wanted:
            return a
    for a in rel.get("assets", []):
        if a["name"].lower().endswith((".lua", ".zip")):
            return a
    return None


def short_tag(script, tag):
    prefix = script["tag"] + "-"
    return tag[len(prefix):] if tag.startswith(prefix) else tag


def all_link(script):
    return "https://github.com/%s/releases?q=%s&amp;expanded=true" % (REPO, script["tag"])


def page(script, rels):
    mine = for_script(script, rels)
    o = ['<div class="intro">']
    o.append('<div class="page-head">%s<h1>%s</h1></div>'
             % (script_icon(script, 30), html.escape(script["title"])))
    o.append('<p class="tagline">%s</p>'
             % pair(html.escape(script["ru"]["tagline"]), html.escape(script["en"]["tagline"])))

    grab = []
    if mine:
        top = mine[0]
        a = asset_of(top, script)
        day = (top.get("published_at") or "")[:10]
        if a:
            grab.append('<a class="get" href="%s" download>%s <span translate="no">%s</span></a>'
                        % (a["browser_download_url"], glyph("f019"), html.escape(a["name"])))
            grab.append('<span class="stamp"><b translate="no">%s</b>%s· %s ·%s%d%sdownloads'
                        "</span>"
                        % (html.escape(short_tag(script, top["tag_name"])), NBSP, stamp(day),
                           NBSP, a["download_count"], NBSP))
    else:
        grab.append('<span class="stamp">%s</span>'
                    % pair("Релизов пока нет.", "No releases yet."))
    grab.append('<a class="more" href="%s">%s →</a>' % (all_link(script), bi("all")))
    o.append('<div class="grab">%s</div>' % "".join(grab))
    o.append("</div>")

    for lang in ("ru", "en"):
        t = script[lang]
        head = WORDS["features"][0 if lang == "ru" else 1]
        steps_head = WORDS["install"][0 if lang == "ru" else 1]
        block = ['<section class="sec"><div class="sec-head"><h2>%s</h2></div>' % head,
                 '<div class="body"><p>%s</p></div>' % html.escape(t["about"]),
                 '<ul class="list">%s</ul>'
                 % "".join("<li><span>%s</span></li>" % html.escape(f) for f in t["features"]),
                 "</section>",
                 '<section class="sec"><div class="sec-head"><h2>%s</h2></div>' % steps_head,
                 '<ol class="steps">%s</ol>'
                 % "".join("<li><span>%s</span></li>" % (s % {"file": html.escape(script["file"])})
                           for s in INSTALL[script["kind"]][lang]),
                 "</section>"]
        o.append('<div data-l="%s">%s</div>' % (lang, "".join(block)))

    if mine:
        rows = []
        for r in mine:
            a = asset_of(r, script)
            file_cell = ('<a class="file" href="%s" download translate="no">%s</a>'
                         % (a["browser_download_url"], html.escape(a["name"])) if a else "—")
            count = a["download_count"] if a else 0
            rows.append('<tr><td class="tag"><a href="%s" translate="no">%s</a></td>'
                        '<td class="when">%s</td><td class="mono">%s</td>'
                        '<td class="num">%d</td></tr>'
                        % (r["html_url"], html.escape(r["tag_name"]),
                           stamp((r.get("published_at") or "")[:10]), file_cell, count))
        o.append('<section class="sec"><div class="sec-head"><h2>%s</h2>'
                 '<span class="sec-note" translate="no">%s</span></div>'
                 % (bi("versions"), html.escape(script["tag"] + "-v*")))
        o.append("<table><thead><tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead>"
                 "<tbody>%s</tbody></table></section>"
                 % (bi("version"), bi("date"), bi("file"), bi("downloads"), "".join(rows)))

        folder = BASE / "scripts" / script["id"]
        ru = folder / "CHANGELOG.md"
        en = folder / "CHANGELOG.en.md"
        if not en.exists():
            en = ru
        if ru.exists():
            o.append('<section class="sec"><div class="sec-head"><h2>%s</h2></div>' % bi("changelog"))
            o.append('<div class="body"><div data-l="ru">%s</div><div data-l="en">%s</div></div>'
                     "</section>"
                     % (md(ru.read_text(encoding="utf-8")), md(en.read_text(encoding="utf-8"))))

    description = "%s · %s" % (script["ru"]["tagline"], script["en"]["tagline"])
    return shell("%s — umbrella-work" % script["title"], description,
                 "%s/%s/" % (SITE, script["tag"]), script["title"], "".join(o), 1)


def index(rels):
    o = ['<div class="intro">']
    o.append('<h1 translate="no">umbrella-work</h1>')
    o.append('<p class="tagline">%s</p>'
             % pair("Скрипты для Umbrella и приложение MusicUI. Открой скрипт, чтобы "
                    "прочитать описание и забрать любую версию.",
                    "Scripts for Umbrella and the MusicUI app. Open one to read what it does "
                    "and grab any version."))
    o.append("</div>")

    rows = []
    for position, script in enumerate(CATALOG["scripts"], start=1):
        mine = for_script(script, rels)
        if mine:
            top = mine[0]
            a = asset_of(top, script)
            version = '<span translate="no">%s</span>' % html.escape(short_tag(script, top["tag_name"]))
            day = stamp((top.get("published_at") or "")[:10])
            count = str(a["download_count"]) if a else "0"
        else:
            version = bi("none")
            day = "—"
            count = "—"
        rows.append('<tr><td class="idx">%02d</td><td class="who"><span class="who-line">%s'
                    '<a href="%s/">%s</a></span><span class="desc">%s</span></td>'
                    '<td class="tag">%s</td><td class="when hide-sm">%s</td>'
                    '<td class="num hide-sm">%s</td></tr>'
                    % (position, script_icon(script, 20), script["tag"],
                       html.escape(script["title"]),
                       pair(html.escape(script["ru"]["tagline"]),
                            html.escape(script["en"]["tagline"])),
                       version, day, count))

    o.append('<section class="sec" style="margin-top:8px">'
             "<table><thead><tr>"
             '<th class="idx"></th><th>%s</th><th>%s</th><th class="hide-sm">%s</th>'
             '<th class="hide-sm">%s</th></tr></thead><tbody>%s</tbody></table></section>'
             % (bi("script"), bi("version"), bi("updated"), bi("downloads"), "".join(rows)))

    data = GH / "stats" / "stats.jsonl"
    if data.exists():
        lines = [l for l in data.read_text(encoding="utf-8").splitlines() if l.strip()]
        if lines:
            last = json.loads(lines[-1])
            o.append('<section class="sec"><div class="sec-head"><h2>%s</h2>'
                     '<span class="sec-note">%s</span></div>'
                     % (bi("stats"),
                        pair("срез от %s" % last["date"], "snapshot from %s" % last["date"])))
            o.append('<figure class="chart">'
                     '<img src="stats-dark.svg" width="840" height="260" alt="%s">'
                     "<figcaption>%s</figcaption></figure></section>"
                     % (html.escape("Downloads over time"),
                        pair("всего%s%d" % (NBSP, last["total"]),
                             "%d%sin total" % (last["total"], NBSP))))

    return shell("umbrella-work — scripts for Umbrella",
                 "Scripts for Umbrella and the MusicUI app · "
                 "Скрипты для Umbrella и приложение MusicUI", SITE + "/", "", "".join(o), 0)


def main():
    rels = api("https://api.github.com/repos/%s/releases?per_page=100" % REPO)
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    (OUT / "index.html").write_text(index(rels), encoding="utf-8", newline=NL)
    for theme in ("light", "dark"):
        src = GH / "stats" / ("stats-%s.svg" % theme)
        if src.exists():
            shutil.copyfile(src, OUT / src.name)
    for script in CATALOG["scripts"]:
        d = OUT / script["tag"]
        d.mkdir(parents=True, exist_ok=True)
        (d / "index.html").write_text(page(script, rels), encoding="utf-8", newline=NL)
        print("%-20s -> site/%s/" % (script["id"], script["tag"]))


if __name__ == "__main__":
    main()
