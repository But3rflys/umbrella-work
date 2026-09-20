const REPO = "But3rflys/umbrella-work";
const CACHE_KEY = "uw-releases";
const CACHE_TTL = 10 * 60 * 1000;
const numbers = new Intl.NumberFormat("en-US");

/* язык */

function initLanguage() {
  const buttons = document.querySelectorAll(".lang button");
  let saved = null;
  try {
    saved = localStorage.getItem("uw-lang");
  } catch (e) {
    saved = null;
  }
  const guess = (navigator.languages?.[0] || navigator.language || "en").slice(0, 2);

  function apply(lang) {
    document.documentElement.dataset.lang = lang;
    document.documentElement.lang = lang;
    try {
      localStorage.setItem("uw-lang", lang);
    } catch (e) {
      /* приватный режим */
    }
    buttons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.set === lang)));
    document.dispatchEvent(new CustomEvent("langchange", { detail: lang }));
  }

  buttons.forEach((b) => b.addEventListener("click", () => apply(b.dataset.set)));
  apply(saved || (guess === "ru" ? "ru" : "en"));
}

function currentLang() {
  return document.documentElement.dataset.lang === "ru" ? "ru" : "en";
}

function localText(node) {
  const lang = currentLang();
  const slot = node.querySelector(`[data-l="${lang}"]`);
  return (slot || node).textContent.trim();
}

/* иконки */

function hideMissingIcons() {
  if (!document.fonts?.ready) return;
  document.fonts.ready.then(() => {
    if (!document.fonts.check('900 14px "Font Awesome 6 Free"')) {
      document.documentElement.classList.add("no-fa");
    }
  });
}

/* поиск по сайдбару */

function initSearch() {
  const input = document.querySelector("#search");
  if (!input) return;
  const items = [...document.querySelectorAll(".side .item")];
  const empty = document.querySelector(".side .empty");

  function filter() {
    const q = input.value.trim().toLowerCase();
    let shown = 0;
    items.forEach((item) => {
      const hit = !q || item.textContent.toLowerCase().includes(q);
      item.hidden = !hit;
      if (hit) shown += 1;
    });
    document.querySelectorAll(".side h2").forEach((head) => {
      const list = head.nextElementSibling;
      head.hidden = list ? [...list.querySelectorAll(".item")].every((i) => i.hidden) : false;
    });
    if (empty) empty.hidden = shown > 0;
  }

  input.addEventListener("input", filter);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      input.value = "";
      filter();
      input.blur();
    }
    if (e.key === "Enter") {
      const first = items.find((i) => !i.hidden);
      if (first) window.location.href = first.href;
    }
  });
  document.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
      e.preventDefault();
      input.focus();
      input.select();
    }
  });
}

/* оглавление страницы */

function initToc() {
  const toc = document.querySelector(".toc nav");
  const content = document.querySelector(".content");
  if (!toc || !content) return;

  let observer = null;

  function build() {
    const heads = [...content.querySelectorAll("h2[id], h3[id]")].filter(
      (h) => h.offsetParent !== null
    );
    if (!heads.length) {
      toc.replaceChildren();
      return;
    }

    const list = document.createElement("ul");
    for (const head of heads) {
      const li = document.createElement("li");
      if (head.tagName === "H3") li.className = "sub";
      const a = document.createElement("a");
      a.href = `#${head.id}`;
      a.textContent = localText(head);
      a.dataset.for = head.id;
      li.append(a);
      list.append(li);
    }
    toc.replaceChildren(list);

    observer?.disconnect();
    const links = new Map([...toc.querySelectorAll("a")].map((a) => [a.dataset.for, a]));
    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          links.forEach((a) => a.classList.remove("active"));
          links.get(entry.target.id)?.classList.add("active");
        }
      },
      { rootMargin: "-80px 0px -70% 0px", threshold: 0 }
    );
    heads.forEach((h) => observer.observe(h));
  }

  build();
  document.addEventListener("langchange", build);
  document.addEventListener("contentchange", build);
}

/* релизы */

function readCache() {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    const { at, data } = JSON.parse(raw);
    return Date.now() - at < CACHE_TTL ? data : null;
  } catch (e) {
    return null;
  }
}

function writeCache(data) {
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), data }));
  } catch (e) {
    /* хранилище недоступно */
  }
}

async function loadReleases() {
  const cached = readCache();
  if (cached) return cached;

  const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`, {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!res.ok) throw new Error(`GitHub API ${res.status}`);

  const data = (await res.json())
    .filter((r) => !r.draft)
    .map((r) => ({
      tag: r.tag_name,
      url: r.html_url,
      date: (r.published_at || "").slice(0, 10),
      assets: r.assets.map((a) => ({
        name: a.name,
        url: a.browser_download_url,
        downloads: a.download_count,
      })),
    }));
  writeCache(data);
  return data;
}

const releasesFor = (tag, all) =>
  all.filter((r) => r.tag.startsWith(`${tag}-v`)).sort((a, b) => (a.date < b.date ? 1 : -1));

const pickAsset = (release, wanted) =>
  release.assets.find((a) => a.name.toLowerCase() === (wanted || "").toLowerCase()) ||
  release.assets[0] ||
  null;

const shortVersion = (tag, prefix) =>
  tag.startsWith(`${prefix}-`) ? tag.slice(prefix.length + 1) : tag;

const totalOf = (list) =>
  list.reduce((sum, r) => sum + r.assets.reduce((s, a) => s + a.downloads, 0), 0);

function timeCell(date) {
  const time = document.createElement("time");
  time.dateTime = date;
  time.textContent = date;
  return time;
}

function fillSidebar(link, all) {
  const slot = link.querySelector(".ver");
  if (!slot) return;
  const mine = releasesFor(link.dataset.side, all);
  slot.textContent = mine.length ? shortVersion(mine[0].tag, link.dataset.side) : "—";
}

function fillRow(row, all) {
  const tag = row.dataset.row;
  const mine = releasesFor(tag, all);
  const set = (field, value) => {
    const cell = row.querySelector(`[data-field="${field}"]`);
    if (cell) cell.textContent = value;
  };

  if (!mine.length) {
    set("version", "—");
    set("date", "—");
    set("downloads", "—");
    return;
  }

  set("version", shortVersion(mine[0].tag, tag));
  set("downloads", numbers.format(totalOf(mine)));
  row.querySelector('[data-field="date"]')?.replaceChildren(timeCell(mine[0].date));
}

function fillRelease(panel, all) {
  const tag = panel.dataset.script;
  const mine = releasesFor(tag, all);
  const pending = panel.querySelector('[data-field="pending"]');
  if (!mine.length) {
    if (pending) pending.textContent = "—";
    return;
  }

  const top = mine[0];
  const asset = pickAsset(top, panel.dataset.file);
  const button = panel.querySelector('[data-field="download"]');
  if (asset && button) {
    button.href = asset.url;
    const label = button.querySelector('[data-field="filename"]');
    if (label) label.textContent = asset.name;
    button.hidden = false;
  }

  const meta = panel.querySelector('[data-field="meta"]');
  if (meta) {
    meta.querySelector('[data-field="version"]').textContent = shortVersion(top.tag, tag);
    meta.querySelector('[data-field="date"]').replaceChildren(timeCell(top.date));
    meta.querySelector('[data-field="downloads"]').textContent = numbers.format(totalOf(mine));
    meta.hidden = false;
  }
  if (pending) pending.hidden = true;
}

function fillVersions(section, all) {
  const mine = releasesFor(section.dataset.versions, all);
  const body = section.querySelector("tbody");
  if (!body) return;
  if (!mine.length) {
    section.hidden = true;
    return;
  }

  const rows = mine.map((release) => {
    const asset = pickAsset(release, section.dataset.file);
    const tr = document.createElement("tr");

    const tag = document.createElement("td");
    const link = document.createElement("a");
    link.className = "link";
    link.href = release.url;
    link.setAttribute("translate", "no");
    const code = document.createElement("code");
    code.textContent = release.tag;
    link.append(code);
    tag.append(link);

    const date = document.createElement("td");
    date.className = "when";
    date.append(timeCell(release.date));

    const file = document.createElement("td");
    if (asset) {
      const fileLink = document.createElement("a");
      fileLink.className = "link";
      fileLink.href = asset.url;
      fileLink.textContent = asset.name;
      fileLink.setAttribute("download", "");
      fileLink.setAttribute("translate", "no");
      file.append(fileLink);
    } else {
      file.textContent = "—";
    }

    const count = document.createElement("td");
    count.className = "num";
    count.textContent = numbers.format(asset ? asset.downloads : 0);

    tr.append(tag, date, file, count);
    return tr;
  });

  body.replaceChildren(...rows);
  section.hidden = false;
}

async function hydrate() {
  const sides = document.querySelectorAll("[data-side]");
  const rows = document.querySelectorAll("[data-row]");
  const panels = document.querySelectorAll(".release[data-script]");
  const versions = document.querySelectorAll("[data-versions]");

  try {
    const all = await loadReleases();
    sides.forEach((link) => fillSidebar(link, all));
    rows.forEach((row) => fillRow(row, all));
    panels.forEach((panel) => fillRelease(panel, all));
    versions.forEach((section) => fillVersions(section, all));
    document.dispatchEvent(new CustomEvent("contentchange"));
  } catch (e) {
    document.querySelectorAll("[data-field]").forEach((el) => {
      if (el.textContent.trim() === "…") el.textContent = "—";
    });
    console.warn("releases unavailable:", e.message);
  }
}

initLanguage();
hideMissingIcons();
initSearch();
initToc();
hydrate();
