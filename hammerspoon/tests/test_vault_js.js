// =====================================================================
// test_vault_js.js — RUNS the Vault page's JavaScript for real.
// =====================================================================
//   lua5.4 dump_vault_html.lua ./modules > /tmp/vault.html
//   node test_vault_js.js /tmp/vault.html
// The [[ autocomplete, the link under the caret, the note filter, the
// row walker, ⌘ keys and the graph data all live in the page.
// 6.174.0: the tag rows and # filter, the # popup, ⌘L and smart lists,
// the outline, the footer, the search and task views, the template
// picker, the extract / random / daily keys and the ≈ mentions pane.

const fs = require("fs");
const html = fs.readFileSync(process.argv[2] || "/tmp/vault.html", "utf8");
let pass = 0, fail = 0;
const check = (label, cond, extra) => {
  if (cond) pass++; else { fail++; console.log("   ❌ " + label + (extra !== undefined ? "  — " + extra : "")); }
};

function el(tag) {
  const e = { tagName: tag, value: "", innerHTML: "", style: {}, children: [], _cls: new Set(), listeners: {}, selectionStart: 0, selectionEnd: 0,
    hidden: false, textContent: "", placeholder: "", focused: 0,
    addEventListener(ev, fn) { this.listeners[ev] = fn; },
    focus() { this.focused++; }, select() {}, setSelectionRange(a, b) { this.selectionStart = a; this.selectionEnd = b; },
    getAttribute(n) { return this.attrs ? this.attrs[n] : null; }, scrollIntoView() {},
    getContext() { return null; }, getBoundingClientRect() { return { left: 0, top: 0 }; } };
  e.classList = { add: (c) => e._cls.add(c), remove: (c) => e._cls.delete(c), contains: (c) => e._cls.has(c),
                  toggle: (c, on) => { if (on) e._cls.add(c); else e._cls.delete(c); } };
  e.className = "";
  return e;
}
function makeEnv() {
  const sent = [];
  const t = el("TEXTAREA"), q = el("INPUT"), hdr = el("HEADER"), ac = el("DIV"), rows = el("UL"), links = el("DIV"), cv = el("CANVAS"), gbtn = el("BUTTON");
  // 6.174.0 — the mode strip, footer, chips, outline, mentions, hint and the two header buttons
  const mode = el("DIV"), foot = el("DIV"), chips = el("DIV"), outline = el("UL"), unl = el("UL"), unlh = el("H4"), hint = el("SPAN"), sbtn = el("BUTTON"), kbtn = el("BUTTON");
  // 6.183.0 — the 🔎 QUERY block in the right pane
  const qbox = el("DIV"), qres = el("UL"), qh = el("H4");
  // 6.186.0 — the 🗂 board: its columns, its footer, the card that follows the pointer
  const bcols = el("DIV"), btip = el("DIV"), bdrag = el("DIV"), bbtn = el("BUTTON");
  // 🚨 6.203.0 — the ⌘N naming bar. These four were NEVER in this stub, so
  // askName() took its namefail branch on every run and not one check in
  // this file had ever seen the bar: the page half of LL's lost paste
  // could not be caught because it never ran. A stub missing an element
  // the real page has is 6.193.0's hole with a tick beside it.
  const pr = el("DIV"), prlab = el("DIV"), prin = el("INPUT"), prwarn = el("DIV");
  const byId = { t, q, hdr, ac, rows, links, cv, gbtn, mode, foot, chips, outline, unl, unlh, hint, sbtn, kbtn, qbox, qres, qh, bcols, btip, bdrag, bbtn, pr, prlab, prin, prwarn };
  const docListeners = {}, winListeners = {};
  // 6.186.0 — the board's columns, parsed out of bcols.innerHTML into elements
  // the page's own drag code can walk: a card's parentNode is .cards and its
  // parent is the .col that will name the value. Only the GEOMETRY is faked.
  let hit = null;
  function boardCols() {
    const out = [];
    for (const m of bcols.innerHTML.matchAll(/<div class="(col[^"]*)" data-val="([^"]*)" data-none="([^"]*)">([\s\S]*?)(?=<div class="col|$)/g)) {
      const col = el("DIV"); col.className = m[1]; col.attrs = { "data-val": m[2].replace(/&quot;/g, '"'), "data-none": m[3] || null };
      const cards = el("DIV"); cards.className = "cards"; cards.parentNode = col;
      col.cards = [];
      for (const c of m[4].matchAll(/<div class="(card[^"]*)" data-rel="([^"]*)" data-name="([^"]*)"/g)) {
        const card = el("DIV"); card.className = c[1]; card.attrs = { "data-rel": c[2], "data-name": c[3] };
        card.parentNode = cards; col.cards.push(card);
      }
      out.push(col);
    }
    return out;
  }
  bcols.getElementsByClassName = (c) => boardCols().filter((x) => x.className.indexOf(c) === 0);
  // rows are re-rendered from innerHTML; expose them as fake <li>s (every data-* attribute kept)
  function liRows(html) {
    const out = [];
    for (const m of html.matchAll(/<(li|span) class="([^"]*)"((?: data-[a-z]+="[^"]*")+)/g)) {
      const r = el(m[1].toUpperCase()); r.attrs = {}; r.className = m[2];
      for (const a of m[3].matchAll(/ (data-[a-z]+)="([^"]*)"/g)) r.attrs[a[1]] = a[2].replace(/&quot;/g, '"');
      out.push(r);
    }
    return out;
  }
  function rowsFromHtml() { return liRows(rows.innerHTML); }
  let cached = null;
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: (ev, fn) => { docListeners[ev] = fn; },
      // 🚨 6.195.0 — THIS STUB USED TO IGNORE THE SELECTOR and hand back
      // every row. That made it MORE FORGIVING than the browser, which is
      // a hole with a tick beside it (the 6.193.0 rule): a row the real
      // ROWSEL excludes still walked here. It now honours the `[data-x]`
      // terms of a comma-separated selector, which is all the page uses.
      querySelectorAll: (sel) => {
        if (!cached || cached.html !== rows.innerHTML) cached = { html: rows.innerHTML, rows: rowsFromHtml() };
        const want = [...String(sel).matchAll(/\[(data-[a-z]+)\]/g)].map((m) => m[1]);
        if (!want.length) return cached.rows;
        return cached.rows.filter((r) => want.some((k) => r.attrs && k in r.attrs));
      },
      activeElement: t,
      // 6.186.0 — the one thing a fake DOM cannot do for real. The test says
      // what the pointer is over; every other step of the drag is the page's.
      elementFromPoint: () => hit,
      body: {},
    },
    window: { webkit: { messageHandlers: { vault: { postMessage: (m) => sent.push(m) } } },
              addEventListener: (ev, fn) => { winListeners[ev] = fn; }, devicePixelRatio: 1 },
    requestAnimationFrame() {}, Math, String, Array,
    setTimeout: (fn) => { fn(); return 1; }, clearTimeout() {},     // the page's pane debounce runs at once here
  };
  // a click on a row of `elm` (its innerHTML parsed like #rows): the target's closest() answers
  // for `li…` / `[data-x]` selectors that fit the row and for nothing else (so `.x` stays null)
  function click(elm, row) {
    const target = { closest: (sel) => {
      for (const tk of sel.split(",")) {
        const s = tk.trim(), m = s.match(/\[(data-[a-z]+)\]/);
        if (m && row.attrs && (m[1] in row.attrs)) return row;
        if (s === "li" && row.tagName === "LI") return row;
      }
      return null; } };
    elm.listeners.click({ target });
  }
  // 6.186.0 — drag a card by name from one column onto another, exactly as
  // the page sees it: mousedown on the card, a move past the 4 px threshold,
  // mouseup over `onto` (null = dropped nowhere).
  function drag(cardName, onto, opts) {
    const cols = boardCols();
    let card = null;
    for (const c of cols) for (const k of c.cards) if (k.attrs["data-name"] === cardName) card = k;
    if (!card) return null;
    hit = card;
    bcols.listeners.mousedown({ button: 0, target: card, preventDefault() {} });
    if (!(opts && opts.still)) { hit = onto; winListeners.mousemove({ clientX: 90, clientY: 90 }); }
    hit = onto;
    winListeners.mouseup({ clientX: 90, clientY: 90 });
    return card;
  }
  return { sandbox, sent, t, q, ac, rows, docListeners, winListeners, byId, liRows, click, mode, foot, chips, pr, prin, prwarn, prlab,
           outline, unl, unlh, hint, kbtn, qbox, qres, qh, links, bcols, btip, bdrag, boardCols, drag,
           setHit: (h) => { hit = h; } };
}
const padHtml = process.argv[3] ? fs.readFileSync(process.argv[3], "utf8") : null;
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);
const vm = require("vm");
function load(src) {
  src = src || html;
  const script = [...src.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])[0];
  const env = makeEnv();
  // the textarea starts with the note's text, as the browser would —
  // including the HTML rule the page relies on (6.174.0): a single newline
  // straight after the start tag is part of the markup, not of the value,
  // so the page emits a spare one and the parser eats it.
  const ta = src.match(/<textarea[^>]*>\n?([\s\S]*?)<\/textarea>/);
  env.t.value = ta ? ta[1].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&") : "";
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(script, ctx, { filename: "vault-page.js" });
  env.call = (expr) => vm.runInContext(expr, ctx);
  env.key = (k, o) => { const e = Object.assign({ key: k, metaKey: false, altKey: false, ctrlKey: false, shiftKey: false, prevented: false, preventDefault() { this.prevented = true; } }, o || {}); env.docListeners.keydown(e); return e; };
  env.type = (text, caret) => { env.t.value = text; env.t.selectionStart = env.t.selectionEnd = caret == null ? text.length : caret; env.t.listeners.input({}); };
  return env;
}
console.log("── Vault: page JavaScript, executed ──");

// 1. data and the note list
{
  const env = load();
  check("six notes reached the page (a template and a daily note among them)", env.call("NOTES.length") === 6);
  check("the open note is Alpha", env.call("CUR") === "Alpha.md");
  check("the list draws every note, the open one marked", env.rows.innerHTML.includes('class="note cur" data-name="Alpha"') && env.rows.innerHTML.includes('data-name="Long Name Here"'));
  {
    const h = env.rows.innerHTML, tp = h.indexOf("📄 TEMPLATES");
    check("6.174.0: 📄 TEMPLATES sits after the notes, Meeting only there (never under NOTES)",
          tp > h.indexOf('data-name="Long Name Here"') && h.indexOf('data-name="Meeting"') > tp && !h.slice(0, tp).includes("Meeting") && h.includes('class="tpl" data-name="Meeting" title="Templates/Meeting.md">📄 Meeting'));
  }
  env.q.value = "bet"; env.q.listeners.input({});
  check("filtering narrows the list and tells Lua", env.rows.innerHTML.includes("Beta") && !env.rows.innerHTML.includes('data-name="Alpha"') && env.sent.some((m) => m.a === "filter" && m.f === "bet"));
  env.q.value = "zzz"; env.q.listeners.input({});
  check("no match offers to create the typed name", env.rows.innerHTML.includes("creates"));
  env.sent.length = 0;
  env.q.listeners.keydown({ key: "Enter", preventDefault() {} });
  check("⏎ in the filter with no row opens (creates) that name", env.sent[0] && env.sent[0].a === "open" && env.sent[0].name === "zzz", JSON.stringify(env.sent[0]));
}
// 2. every message carries the text and caret
{
  const env = load();
  env.type("hello world", 5);
  const m = env.sent[env.sent.length - 1];
  check("typing sends edit with the text, caret and note", m && m.a === "edit" && m.text === "hello world" && m.sel === 5 && m.rel === "Alpha.md", JSON.stringify(m));
}
// 3. [[ autocomplete
{
  const env = load();
  env.type("see [[al");
  check("typing [[al opens the list with Alpha only", env.ac.style.display === "block" && env.ac.innerHTML.includes("Alpha") && !env.ac.innerHTML.includes("Gamma"), env.ac.innerHTML);
  env.key("Enter");
  check("⏎ completes to [[Alpha]] and puts the caret after it", env.t.value === "see [[Alpha]]" && env.t.selectionStart === 13 && env.ac.style.display === "none", env.t.value);
  env.type("x [[");
  check("[[ alone lists every note (up to 8)", env.ac.style.display === "block" && (env.ac.innerHTML.match(/<div/g) || []).length === 6);
  env.key("ArrowDown"); env.key("ArrowDown"); env.key("Tab");
  check("↓↓ Tab picks the third name (the daily note sorts first)", env.t.value === "x [[Beta]]", env.t.value);
  env.type("done [[Alpha]] then");
  check("a closed link does not reopen the list", env.ac.style.display === "none");
  env.type("[[al");
  env.key("Escape");
  check("Esc closes the list without closing the window", env.ac.style.display === "none" && !env.sent.some((m) => m.a === "esc"));
  env.key("Escape");
  check("Esc with no list closes the window", env.sent.some((m) => m.a === "esc"));
}
// 4. the link under the caret and ⌘⏎
{
  const env = load();
  env.type("go [[Beta|B]] or [doc](../Docs/x.pdf) end", 7);
  env.key("Enter", { metaKey: true });
  let m = env.sent[env.sent.length - 1];
  check("⌘⏎ on a wikilink sends follow with the inner text", m.a === "follow" && m.target === "Beta|B" && m.md === false, JSON.stringify(m));
  env.t.selectionStart = env.t.selectionEnd = 22;
  env.key("Enter", { metaKey: true });
  m = env.sent[env.sent.length - 1];
  check("⌘⏎ on a Markdown link sends its target, md:true", m.a === "follow" && m.target === "../Docs/x.pdf" && m.md === true, JSON.stringify(m));
  env.sent.length = 0;
  env.t.selectionStart = env.t.selectionEnd = 1;
  env.key("Enter", { metaKey: true });
  check("⌘⏎ off a link sends nothing", env.sent.length === 0);
  env.call('insertAtCaret("[f](x)")');
  check("insertAtCaret splices at the caret and reports the edit", env.t.value.startsWith("g[f](x)o ") && env.sent.some((x) => x.a === "edit"));
}
// 5. ⌘ keys
{
  const env = load();
  for (const [k, a] of [["n", "new"], ["d", "daily"], ["g", "graph"], ["k", "linkfile"]]) {
    env.sent.length = 0; env.key(k, { metaKey: true });
    check("⌘" + k.toUpperCase() + " → " + a, env.sent[0] && env.sent[0].a === a);
  }
}
// 5b. 6.195.0 — the "+ new note" row: LL asked for a plus he can CLICK,
// like the pad's "+ new tab ⌘T". It must reach the same v.newNote() ⌘N
// does, and it must NOT join the row walker — a + row at the top of the
// notes would make ⌥↓ land on it instead of the first note.
{
  const env = load();
  const first = env.liRows(env.rows.innerHTML)[0];
  check("the notes list opens with a + new note row", !!(first && first.attrs && first.attrs["data-new"]), JSON.stringify(first && first.attrs));
  env.sent.length = 0;
  env.click(env.rows, first);
  check("clicking it asks Lua for a new note — the same door as ⌘N", env.sent.length === 1 && env.sent[0].a === "newnote", JSON.stringify(env.sent));
  check("🚨 and it is NOT a walkable row — ⌥↓ still lands on the first NOTE", (() => {
    const walked = env.sandbox.document.querySelectorAll("#rows li[data-name],#rows li[data-tab],#rows li[data-tag]");
    return walked.length > 0 && !(walked[0].attrs && walked[0].attrs["data-new"]);
  })());
  env.type("");            // a filter hides it, because ⏎ already creates that name
  env.q.value = "al"; env.q.listeners.input();
  check("a typed filter hides the + row", !env.liRows(env.rows.innerHTML).some((r) => r.attrs && r.attrs["data-new"]));
}
// 6. the row walker: ⌥↓ from the text, plain ↓ from the filter, ⏎ opens
{
  const env = load();
  env.sent.length = 0;
  env.key("ArrowDown");
  check("plain ↓ inside the text does not move the highlight", env.call("SEL") === -1);
  env.key("ArrowDown", { altKey: true });
  check("⌥↓ highlights the first row", env.call("SEL") === 0);
  env.key("Enter", { altKey: true });
  check("⌥⏎ opens the highlighted note (the daily note sorts first)", env.sent.some((m) => m.a === "open" && m.name === "2026-09-06"), JSON.stringify(env.sent));
  env.sandbox.document.activeElement = env.q;
  env.key("ArrowDown"); env.key("ArrowDown");
  check("plain ↓ from the filter box walks on", env.call("SEL") === 2);
  env.sent.length = 0; env.key("Enter");
  check("⏎ from the filter opens the highlighted row (Beta, the third)", env.sent[0] && env.sent[0].a === "open" && env.sent[0].name === "Beta", JSON.stringify(env.sent[0]));
}
// 7. graph data
{
  const env = load();
  const g = env.call("GRAPH");
  check("graph nodes: 6 notes + 1 ghost (Delta)", g.nodes.length === 7 && g.nodes.some((n) => n.ghost && n.n === "Delta"));
  check("graph edges: Alpha→Beta, Gamma→Alpha, Gamma→Delta", g.edges.length === 3);
  check("the page forwards F18 keyup and has the drag header", scripts[0].includes("a:'f18up'") && scripts[0].includes("a:'dragStart'"));
}
// 8. 6.173.0 — the Scorp Pad's tabs in the same window
if (!padHtml) { console.log("   (no pad page given — the scratch section is not exercised)"); }
else {
  const env = load(padHtml);
  const bare = load();
  check("without a pad the plain page draws no SCRATCH section", !bare.rows.innerHTML.includes("SCRATCH") && html.includes("HASPAD = false") && html.includes("TABS = []"));
  check("two tabs reached the pad page, the first open", env.call("TABS.length") === 2 && env.call("CUR") === "scratch:t1" && env.call("HASPAD") === true);
  check("the list: SCRATCH header, the open tab marked, a Capture row with its badge, + new tab, NOTES header, then the notes",
        env.rows.innerHTML.includes("📝 SCRATCH") && env.rows.innerHTML.includes('class="tab cur" data-tab="t1"') && env.rows.innerHTML.includes('class="tab capture" data-tab="t2"')
        && env.rows.innerHTML.includes("🗒 Capture") && env.rows.innerHTML.includes('data-tab="+"') && env.rows.innerHTML.indexOf("🕸 NOTES") < env.rows.innerHTML.indexOf('data-name="Alpha"'));
  env.q.value = "gro"; env.q.listeners.input({});
  check("the filter narrows the tabs too and drops the + row", env.rows.innerHTML.includes('data-tab="t1"') && !env.rows.innerHTML.includes('data-tab="t2"') && !env.rows.innerHTML.includes('data-tab="+"') && env.rows.innerHTML.includes("no note matches"));
  env.q.value = ""; env.q.listeners.input({});
  env.sent.length = 0;
  env.key("ArrowDown", { altKey: true }); env.key("Enter", { altKey: true });
  check("⌥↓ ⌥⏎ walks onto the first tab row and opens it", env.sent.some((m) => m.a === "tab" && m.tid === "t1"), JSON.stringify(env.sent));
  env.sent.length = 0;
  env.key("ArrowDown", { altKey: true }); env.key("ArrowDown", { altKey: true }); env.key("Enter", { altKey: true });
  check("…the + row asks for a new tab", env.sent.some((m) => m.a === "tabnew"), JSON.stringify(env.sent));
  for (const [k, o, a] of [["t", { metaKey: true }, "tabnew"], ["w", { metaKey: true }, "tabclose"], ["3", { metaKey: true }, "tabnth"], ["Tab", { ctrlKey: true }, "tabcycle"]]) {
    env.sent.length = 0; env.key(k, o);
    check("⌘/⌃ " + k + " → " + a, env.sent[0] && env.sent[0].a === a, JSON.stringify(env.sent[0]));
  }
  check("⌘W names the open tab", (env.sent.length = 0, env.key("w", { metaKey: true }), env.sent[0].tid === "t1"));
  env.type("groceries\nmilk, eggs", 3);
  const m = env.sent[env.sent.length - 1];
  check("typing in a tab sends edit with rel scratch:t1", m.a === "edit" && m.rel === "scratch:t1" && m.text === "groceries\nmilk, eggs");
  check("the right pane lists the closed tab under HISTORY", padHtml.includes("HISTORY") && padHtml.includes('data-hist="h1"') && !padHtml.includes("BACKLINKS"));
  const plain = load();
  plain.sent.length = 0; plain.key("w", { metaKey: true }); plain.key("t", { metaKey: true });
  check("on a note without a pad, ⌘W and ⌘T send nothing", plain.sent.length === 0);
}
// 9. 6.174.0 — tags: the 🏷 section, the # filter, the chips, the # popup
{
  const env = load();
  check("three tags reached the page, #work first with Alpha + Gamma (through work/deep)",
        env.call("TAGS.length") === 3 && env.call("TAGS[0].k") === "work" && env.call("TAGS[0].c") === 2 && env.call("TAGS.some(function(x){ return x.k === 'home'; }) && TAGS.some(function(x){ return x.k === 'work/deep'; })"));
  check("the list ends with 🏷 TAGS · 3 and a walkable #Work row carrying its count",
        env.rows.innerHTML.includes("🏷 TAGS · 3") && env.rows.innerHTML.includes('<li class="tag" data-tag="work"><span class="tt">#Work</span><span class="ct">2</span></li>')
        && env.rows.innerHTML.indexOf("🏷 TAGS") > env.rows.innerHTML.indexOf("📄 TEMPLATES"));
  env.sent.length = 0; env.q.value = "#work"; env.q.listeners.input({});
  check("#work in the box lists Alpha and Gamma, not Beta, no templates, and tells Lua the filter",
        env.rows.innerHTML.includes('data-name="Alpha"') && env.rows.innerHTML.includes('data-name="Gamma"') && !env.rows.innerHTML.includes('data-name="Beta"')
        && !env.rows.innerHTML.includes("📄 TEMPLATES") && env.sent.some((m) => m.a === "filter" && m.f === "#work"), env.rows.innerHTML);
  check("…and the 🏷 section narrows to the tags containing 'work', A→Z", env.rows.innerHTML.includes("🏷 TAGS · 2") && env.rows.innerHTML.indexOf('data-tag="work"') < env.rows.innerHTML.indexOf('data-tag="work/deep"') && !env.rows.innerHTML.includes('data-tag="home"'));
  env.q.value = "#home"; env.q.listeners.input({});
  check("#home lists Beta only", env.rows.innerHTML.includes('data-name="Beta"') && !env.rows.innerHTML.includes('data-name="Alpha"'));
  env.q.value = "#zzz"; env.q.listeners.input({});
  check("an unknown tag says so", env.rows.innerHTML.includes("no note carries #zzz") && !env.rows.innerHTML.includes("creates"));
  env.sent.length = 0; env.q.listeners.keydown({ key: "Enter", preventDefault() {} });
  check("⏎ on a # filter with no row never creates a note named #zzz", env.sent.length === 0, JSON.stringify(env.sent));
  env.q.value = ""; env.q.listeners.input({}); env.sent.length = 0;
  env.key("ArrowUp", { altKey: true }); env.key("ArrowUp", { altKey: true }); env.key("ArrowUp", { altKey: true });
  env.key("Enter", { altKey: true });
  check("⌥↑ walks onto the tag rows (the last walkable rows) and ⌥⏎ filters by that tag",
        env.q.value === "#work" && env.sent.some((m) => m.a === "filter" && m.f === "#work"), env.q.value + " " + JSON.stringify(env.sent));
  check("the chips on the right carry the open note's #Work", env.chips.innerHTML.includes('class="chip" data-tag="work">#Work') && env.chips.hidden === false);
  env.q.value = ""; env.q.listeners.input({}); env.sent.length = 0;
  env.click(env.chips, env.liRows(env.chips.innerHTML)[0]);
  check("a chip click filters the list by its tag", env.q.value === "#work" && env.sent.some((m) => m.a === "filter" && m.f === "#work"));
  const tl = env.call('tagsOf("---\\ntags: [Work, home/x]\\n  - extra\\n---\\n# H\\ntext #Work #2024 a#b [[N#h]] https://x/y#z #café.\\n```\\n#code\\n```\\n#Done\\n")');
  check("the page's tagsOf agrees with Lua's tagsIn on the shared fixture", JSON.stringify(tl) === JSON.stringify(["Work", "home/x", "extra", "café", "Done"]), JSON.stringify(tl));
  env.type("note #ho");
  check("typing #ho pops the known tags containing 'ho' — Home only", env.ac.style.display === "block" && env.ac.innerHTML.includes("Home") && !env.ac.innerHTML.includes("Work"), env.ac.innerHTML);
  env.sent.length = 0; env.key("Enter");
  check("⏎ completes the tag in place (no ]]), caret after it, edit sent", env.t.value === "note #Home" && env.t.selectionStart === 10 && env.ac.style.display === "none" && env.sent.some((m) => m.a === "edit"), env.t.value);
  env.type("# "); const a1 = env.ac.style.display; env.type("#"); const a2 = env.ac.style.display; env.type("x [[al");
  check("a heading's '# ' and a bare '#' never pop; [[al still pops Alpha (links first)", a1 === "none" && a2 === "none" && env.ac.style.display === "block" && env.ac.innerHTML.includes("Alpha"));
  env.type("see [[Alpha]] #wo", 9);
  check("a #tag typed with the caret inside a finished link pops nothing", env.ac.style.display === "none");
}
// 10. 6.174.0 — ⌘L ticks the caret line; ⏎ continues a list
{
  const env = load();
  const cmdL = () => { env.sent.length = 0; env.key("l", { metaKey: true }); };
  env.type("- [ ] milk", 6); cmdL();
  check("⌘L ticks - [ ] → - [x] and sends the edit", env.t.value === "- [x] milk" && env.sent.some((m) => m.a === "edit"), env.t.value);
  cmdL();
  check("⌘L again unticks it", env.t.value === "- [ ] milk");
  env.type("- [X] a", 3); cmdL();
  check("[X] counts as done → unticked", env.t.value === "- [ ] a");
  env.type("hello", 2); cmdL();
  check("a plain line becomes - [ ] hello, the caret keeping its character", env.t.value === "- [ ] hello" && env.t.selectionStart === 8, env.t.value + " @" + env.t.selectionStart);
  env.type("* item"); cmdL();
  check("a * item gets a box after its marker", env.t.value === "* [ ] item");
  env.type("  2. it"); cmdL();
  check("an indented numbered item keeps indent and number", env.t.value === "  2. [ ] it");
  env.type("a\nb", 0); env.t.selectionEnd = 3; cmdL();
  check("a two-line selection toggles both lines", env.t.value === "- [ ] a\n- [ ] b", env.t.value);
  env.type("x\n- [ ] milk\ny", 8); cmdL();
  check("only the caret's line changes and the caret stays on it", env.t.value === "x\n- [x] milk\ny" && env.t.selectionStart === 8, env.t.value + " @" + env.t.selectionStart);
  // smart lists
  env.type("- [ ] a"); env.sent.length = 0; let e = env.key("Enter");
  check("⏎ on a task line continues it with an empty box", env.t.value === "- [ ] a\n- [ ] " && env.t.selectionStart === env.t.value.length && e.prevented && env.sent.some((m) => m.a === "edit"), env.t.value);
  env.type("3. x"); env.key("Enter");
  check("⏎ on 3. continues with 4.", env.t.value === "3. x\n4. ", env.t.value);
  env.type("- "); env.key("Enter");
  check("⏎ on an empty item drops the marker", env.t.value === "" && env.t.selectionStart === 0, JSON.stringify(env.t.value));
  env.type("plain"); env.sent.length = 0; e = env.key("Enter");
  check("⏎ on a plain line is native — nothing sent, nothing prevented", env.sent.length === 0 && !e.prevented && env.t.value === "plain");
  env.type("- a\nnext", 3); env.key("Enter");
  check("⏎ mid-text carries the rest of the line onto the new item", env.t.value === "- a\n- \nnext", JSON.stringify(env.t.value));
  // 6.174.0 review — the caret at offset 0 of a text that starts with a
  // newline is on line ONE (lastIndexOf clamps a negative fromIndex to 0)
  env.type("\n- [ ] a", 0); cmdL();
  check("⌘L at the very top of a note that starts blank makes a task THERE, not on line 2",
        env.t.value === "- [ ] \n- [ ] a", JSON.stringify(env.t.value));
  env.type("\n- a", 0); env.sent.length = 0; e = env.key("Enter");
  check("…and ⏎ there is native, not a list continuation", !e.prevented && env.t.value === "\n- a", JSON.stringify(env.t.value));
  // the page tells Lua when its load sequence has finished
  check("the page announces itself as ready on load", load().sent.some((m) => m.a === "ready"));
}
// 11. 6.174.0 — the outline and the footer
{
  const env = load();
  check("the outline lists the two headings with their lines and levels",
        env.outline.innerHTML.includes('<li class="hd l1" data-line="1"') && env.outline.innerHTML.includes('<li class="hd l2" data-line="5"') && env.outline.innerHTML.includes(">Part two<"), env.outline.innerHTML);
  env.click(env.outline, env.liRows(env.outline.innerHTML)[1]);
  check("a click on an outline row puts the caret on that heading and focuses the text", env.t.selectionStart === env.t.value.indexOf("## Part two") && env.t.focused > 0, env.t.selectionStart);
  env.type(env.t.value + "### Three\n");
  check("a heading typed in shows up in the outline at once", env.outline.innerHTML.includes('<li class="hd l3" data-line="8"'), env.outline.innerHTML);
  env.type("```\n# not a heading\n```\n---\nx", 0);
  check("a fenced # is not a heading", env.outline.innerHTML.includes("no headings"));
  env.type("---\ntitle: x\n---\n# Real\n");
  check("a leading front-matter block is skipped, the heading after it counted on its real line", env.outline.innerHTML.includes('data-line="4"') && env.outline.innerHTML.includes(">Real<"));
  const env2 = load();
  const v = env2.t.value, words = (v.match(/\S+/g) || []).length, lines = v.split("\n").length;
  // 6.175.0 — the counts moved into innerHTML so the line can carry the
  // markdown hint beside them. The counts themselves are unchanged.
  check("the footer counts words · chars · lines of the fixture", env2.foot.innerHTML.startsWith(words + " words · " + v.length + " chars · " + lines + " lines"), env2.foot.innerHTML);
  check("…in the promised shape", /^\d+ words · [\d ]+ chars · \d+ lines · /.test(env2.foot.innerHTML));
  env2.t.selectionStart = 0; env2.t.selectionEnd = 7; env2.t.listeners.select({});
  check("a selection adds its word count", /· 2 words selected · /.test(env2.foot.innerHTML), env2.foot.innerHTML);
  check("thousands get a thin space", env2.call("thou(1840)") === "1 840" && env2.call("thou(312)") === "312");
}
// 12. 6.174.0 — 🔎 search mode
{
  const env = load();
  env.sent.length = 0; env.key("f", { metaKey: true, shiftKey: true });
  check("⌘⇧F enters search mode, tells Lua, shows the strip, swaps the placeholder, focuses the box",
        env.call("MODE") === "search" && env.sent.some((m) => m.a === "mode" && m.m === "search") && env.mode.hidden === false && env.mode.className === "search"
        && env.q.placeholder.includes("phrase") && env.q.focused > 0 && env.mode.textContent.includes("type words"), env.mode.textContent);
  env.sent.length = 0; env.q.value = "plan"; env.q.listeners.input({});
  check("typing sends search{q} and the strip says searching…", env.sent.some((m) => m.a === "search" && m.q === "plan") && env.mode.textContent.includes("searching…"));
  env.call('setRows("search", [{n:"Alpha",r:"Alpha.md",l:3,x:"the plan"}], false, "plan")');
  check("Lua's rows draw as hits: note · line · snippet, one hit in one note",
        env.rows.innerHTML.includes('<li class="hit" data-name="Alpha" data-line="3" title="Alpha.md">') && env.rows.innerHTML.includes("the plan") && env.mode.textContent.includes("1 hit in 1 note"), env.rows.innerHTML);
  env.sent.length = 0; env.key("ArrowDown", { altKey: true }); env.key("Enter", { altKey: true });
  check("⌥↓ ⌥⏎ opens the hit at its line", env.sent.some((m) => m.a === "open" && m.name === "Alpha" && m.line === 3), JSON.stringify(env.sent));
  env.call("SEL = -1"); env.sent.length = 0; env.q.listeners.keydown({ key: "Enter", preventDefault() {} });
  check("⏎ in the box with no highlight opens the FIRST hit", env.sent.some((m) => m.a === "open" && m.name === "Alpha" && m.line === 3), JSON.stringify(env.sent));
  env.call('setRows("search", [], true, "old")');
  check("rows for another query are dropped", env.rows.innerHTML.includes('data-name="Alpha"'));
  env.call('setRows("search", [], false, "plan")');
  check("no rows → no hit", env.mode.textContent.includes("no hit") && !env.rows.innerHTML.includes('data-name="Alpha"'));
  env.call('setRows("search", [{n:"A",r:"A.md",l:1,x:"x"},{n:"B",r:"B.md",l:1,x:"x"}], true, "plan")');
  check("more than the cap adds an unwalkable … more row", env.rows.innerHTML.includes("more than 2 hits") && env.call("rowsList().length") === 2);
  env.call('setRows("search", [{n:"Alpha",r:"Alpha.md",l:0,x:""}], false, "plan")');
  env.sent.length = 0; env.key("ArrowDown", { altKey: true }); env.key("Enter", { altKey: true });
  check("an operator-only hit (line 0) opens the note without a line", env.sent.some((m) => m.a === "open" && m.name === "Alpha" && m.line === undefined), JSON.stringify(env.sent));
  env.sent.length = 0; env.key("Escape");
  check("Esc goes back to the notes list (no esc sent), the box cleared", env.call("MODE") === "notes" && env.q.value === "" && env.mode.hidden === true && !env.sent.some((m) => m.a === "esc") && env.sent.some((m) => m.a === "mode" && m.m === "notes"));
  env.key("Escape");
  check("a second Esc closes the window", env.sent.some((m) => m.a === "esc"));
  env.key("f", { metaKey: true, shiftKey: true }); env.sent.length = 0; const f0 = env.q.focused; env.key("f", { metaKey: true });
  check("⌘F from search returns to the notes and selects the box", env.call("MODE") === "notes" && env.q.focused > f0 && env.sent.some((m) => m.a === "mode" && m.m === "notes"));
  const plain = load(); plain.sent.length = 0; const f1 = plain.q.focused; plain.key("o", { metaKey: true });
  check("⌘O on the plain page only focuses the box — no message", plain.q.focused === f1 + 1 && plain.sent.length === 0, JSON.stringify(plain.sent));
  check("the header carries the 🔎 and ☑ buttons", html.includes('id="sbtn"') && html.includes('id="kbtn"') && html.includes("Search inside every note ⌘⇧F"));
}
// 13. 6.174.0 — ☑ tasks view
{
  const env = load();
  env.sent.length = 0; env.key("k", { metaKey: true, shiftKey: true });
  check("⌘⇧K enters the task view, tells Lua, lights ☑ and draws Lua's rows",
        env.call("MODE") === "tasks" && env.sent.some((m) => m.a === "mode" && m.m === "tasks") && env.kbtn.classList.contains("on")
        && env.rows.innerHTML.includes('<li class="task" data-name="Gamma" data-line="4" title="Gamma.md">☐ call') && env.mode.textContent.includes("☑ TASKS · 1 open"), env.rows.innerHTML);
  env.sent.length = 0; env.key("ArrowDown", { altKey: true }); env.key("Enter", { altKey: true });
  check("⌥↓ ⌥⏎ opens the task's note at its line", env.sent.some((m) => m.a === "open" && m.name === "Gamma" && m.line === 4), JSON.stringify(env.sent));
  env.sent.length = 0; env.q.value = "zz"; env.q.listeners.input({});
  check("the box filters the rows locally — no message, 'no task matches'", env.rows.innerHTML.includes("no task matches") && env.sent.length === 0);
  env.q.value = "cal"; env.q.listeners.input({});
  check("…and keeps the matching ones", env.rows.innerHTML.includes("☐ call"));
  env.q.value = ""; env.call('setRows("tasks", [], false, "")');
  check("an empty answer says ⌘L makes one", env.rows.innerHTML.includes("no open task — ⌘L makes one"));
  env.call('setRows("tasks", [{n:"A",r:"A.md",l:1,x:"x"}], true, "")');
  check("over the cap: a … more row", env.rows.innerHTML.includes("more than 1 tasks") && env.mode.textContent.includes("1+ open"));
  env.sent.length = 0; env.key("k", { metaKey: true, shiftKey: true });
  check("⌘⇧K again returns to the notes", env.call("MODE") === "notes" && !env.kbtn.classList.contains("on") && env.sent.some((m) => m.a === "mode" && m.m === "notes"));
  const fresh = load(); fresh.call("TASKS.listed = false; TASKS.rows = []"); fresh.key("k", { metaKey: true, shiftKey: true });
  check("before Lua answers the view says loading…", fresh.rows.innerHTML.includes("loading…"));
}
// 14. 6.174.0 — the ⌘⇧ keys: templates, extract, random, daily ‹ ›, and the Lua → page calls
{
  const env = load();
  env.sent.length = 0; env.key("t", { metaKey: true, shiftKey: true });
  check("⌘⇧T pops the template picker with a header row and Meeting — nothing sent yet", env.ac.style.display === "block" && env.ac.innerHTML.includes('class="sec"') && env.ac.innerHTML.includes("Meeting") && env.sent.length === 0, env.ac.innerHTML);
  env.key("Enter");
  check("⏎ asks Lua to insert it", env.sent.some((m) => m.a === "tplinsert" && m.name === "Meeting") && env.ac.style.display === "none", JSON.stringify(env.sent));
  env.sent.length = 0; env.key("n", { metaKey: true, shiftKey: true });
  check("⌘⇧N pops — blank — first, then the templates; it does NOT send new", env.call("ACITEMS[0]") === "— blank —" && env.call("ACITEMS[1]") === "Meeting" && !env.sent.some((m) => m.a === "new"));
  env.key("Enter");
  check("⏎ on — blank — is ⌘N's path (tplnew with an empty name)", env.sent.some((m) => m.a === "tplnew" && m.name === ""), JSON.stringify(env.sent));
  env.sent.length = 0; env.key("n", { metaKey: true, shiftKey: true }); env.key("ArrowDown"); env.key("Enter");
  check("↓ ⏎ picks Meeting for the new note", env.sent.some((m) => m.a === "tplnew" && m.name === "Meeting"), JSON.stringify(env.sent));
  env.sent.length = 0; env.key("n", { metaKey: true });
  check("⌘N still sends new", env.sent[0] && env.sent[0].a === "new");
  env.key("n", { metaKey: true, shiftKey: true }); env.key("Escape");
  check("Esc closes the picker without leaving", env.ac.style.display === "none" && !env.sent.some((m) => m.a === "esc"));
  env.t.selectionStart = 0; env.t.selectionEnd = 7; env.sent.length = 0; env.key("e", { metaKey: true, shiftKey: true });
  check("⌘⇧E sends the head and the selection", env.sent[0] && env.sent[0].a === "extract" && env.sent[0].head === "" && env.sent[0].selText === "# Alpha", JSON.stringify(env.sent[0]));
  env.t.selectionStart = env.t.selectionEnd = 3; env.sent.length = 0; env.key("e", { metaKey: true, shiftKey: true });
  check("…without a selection it still sends (Lua says 'select some text first')", env.sent[0] && env.sent[0].a === "extract" && env.sent[0].head === "# A" && env.sent[0].selText === "");
  env.sent.length = 0; env.key("r", { metaKey: true, shiftKey: true });
  check("⌘⇧R → random", env.sent[0] && env.sent[0].a === "random");
  env.sent.length = 0; env.key("s", { metaKey: true, shiftKey: true });
  check("6.177.0: ⌘⇧S → export (the Scorp Pad's tabs as .md notes)", env.sent[0] && env.sent[0].a === "export", JSON.stringify(env.sent[0]));
  env.sent.length = 0; env.key("s", { metaKey: true });
  check("…plain ⌘S stays native — nothing is sent", env.sent.length === 0);
  env.sent.length = 0; env.key("[", { metaKey: true, shiftKey: true, code: "BracketLeft" });
  check("⌘⇧[ → dayshift -1", env.sent[0] && env.sent[0].a === "dayshift" && env.sent[0].d === -1, JSON.stringify(env.sent[0]));
  env.sent.length = 0; env.key("}", { metaKey: true, shiftKey: true });
  check("⌘⇧] (arriving as '}') → dayshift 1", env.sent[0] && env.sent[0].a === "dayshift" && env.sent[0].d === 1);
  env.sent.length = 0; env.key("z", { metaKey: true, shiftKey: true }); env.key("a", { metaKey: true });
  check("⌘⇧Z and ⌘A stay native", env.sent.length === 0);
  env.t.selectionStart = env.t.selectionEnd = 3; env.sent.length = 0; env.call('insertAtCaret("a","b")');
  check("insertAtCaret(head, tail) lands both around the caret and reports the edit", env.t.value.slice(3, 5) === "ab" && env.t.selectionStart === 4 && env.sent.some((m) => m.a === "edit"), env.t.value.slice(0, 8));
  const env2 = load(); env2.call("gotoLine(5)");
  check("gotoLine(5) puts the caret at the start of line 5 and focuses the text", env2.t.selectionStart === env2.t.value.indexOf("## Part two") && env2.t.focused > 0);
  env2.call("TEMPLATES = []"); env2.sent.length = 0; env2.call("tplPick('new')");
  check("no templates → tplnone (Lua alerts where to put them)", env2.sent[0] && env2.sent[0].a === "tplnone" && env2.ac.style.display !== "block");
  env2.hint.textContent = "6 notes"; env2.call("HINT0 = '6 notes'"); env2.call('vaultHint("fetching Templates/Meeting.md…")');
  const h1 = env2.hint.textContent; env2.call('vaultHint("")');
  check("vaultHint shows Lua's hint and an empty one restores the status", h1 === "fetching Templates/Meeting.md…" && env2.hint.textContent === "6 notes");
  check("the page has no daily ‹ › on a plain note (DAILY = null) but knows the keys", html.includes("DAILY = null") && !html.includes("Previous day") && html.includes("a:'dayshift'"));
}
// 15. 6.174.0 — ≈ unlinked mentions
{
  const env = load();
  check("Lua pre-filled the pane and the page redrew it for the open note", env.unl.innerHTML.includes('<li class="lnk" data-name="Gamma" title="Gamma.md">≈ Gamma</li>') && env.unlh.textContent === "UNLINKED MENTIONS · 1", env.unlh.textContent);
  check("…and the HTML itself carries the answer (a rebuild never loses it)", html.includes('UNLINKED MENTIONS · 1</h4><ul id="unl"><li class="lnk" data-name="Gamma"'));
  env.call('setMentions([], "alpha", "too short")');
  check("setMentions for the open note redraws: too short", env.unl.innerHTML.includes("too short a name to search") && env.unlh.textContent === "UNLINKED MENTIONS");
  env.call('setMentions([{n:"Beta",r:"Projects/Beta.md"}], "other", "")');
  check("an answer for another note is dropped", env.unl.innerHTML.includes("too short") && !env.unl.innerHTML.includes("Beta"));
  env.call('setMentions([{n:"Beta",r:"Projects/Beta.md"}], "alpha", "more")');
  check("over the cap: the rows and (first N)", env.unl.innerHTML.includes('data-name="Beta"') && env.unl.innerHTML.includes("(first 1)") && env.unlh.textContent === "UNLINKED MENTIONS · 1");
  env.call('setMentions([], "alpha", "grep exited 2: boom")');
  check("a grep failure is shown, not hidden", env.unl.innerHTML.includes("⚠ grep exited 2: boom"));
  env.call('setMentions([], "alpha", "")');
  check("no mention names the note", env.unl.innerHTML.includes('no other note mentions "Alpha"'));
  env.sent.length = 0; env.call('setMentions([{n:"Gamma",r:"Gamma.md"}], "alpha", "")');
  env.click(env.byId.links, env.liRows(env.unl.innerHTML)[0]);
  check("a click on a mention opens that note", env.sent.some((m) => m.a === "open" && m.name === "Gamma"));
}
// 16. 6.174.0 — the pad page: a tab has the footer and ⌘L, no note panes
if (padHtml) {
  const env = load(padHtml);
  const padMarkup = padHtml.split("<script>")[0];
  check("a scratch tab's right pane has no OUTLINE, chips or UNLINKED MENTIONS; the footer is there",
        !padMarkup.includes("OUTLINE") && !padMarkup.includes('id="chips"') && !padMarkup.includes("UNLINKED") && padMarkup.includes('id="foot"') && padMarkup.includes("HISTORY"));
  env.type("- [ ] milk", 3); env.sent.length = 0; env.key("l", { metaKey: true });
  const m = env.sent[env.sent.length - 1];
  check("⌘L inside a tab ticks the line and sends the edit for scratch:t1", env.t.value === "- [x] milk" && m && m.a === "edit" && m.rel === "scratch:t1" && m.text === "- [x] milk", JSON.stringify(m));
  env.sent.length = 0; env.key("w", { metaKey: true });
  check("⌘W still closes the open tab", env.sent[0] && env.sent[0].a === "tabclose" && env.sent[0].tid === "t1");
  env.sent.length = 0; env.key("t", { metaKey: true, shiftKey: true });
  check("⌘⇧T on the pad page opens the template picker, not a new tab", env.ac.style.display === "block" && !env.sent.some((x) => x.a === "tabnew"));
  env.key("Enter");
  check("…and ⏎ sends tplinsert", env.sent.some((x) => x.a === "tplinsert" && x.name === "Meeting"));
  env.type("- a"); env.key("Enter");
  check("smart-list ⏎ works in a tab", env.t.value === "- a\n- ");
  check("the footer counts the tab's words (- a - = 3)", env.foot.innerHTML.startsWith("3 words · 6 chars · 2 lines"), env.foot.innerHTML);
  check("the pad page lists the tags too, after the tabs and notes", env.rows.innerHTML.indexOf("🏷 TAGS") > env.rows.innerHTML.indexOf("📝 SCRATCH"));
  env.q.value = "#work"; env.q.listeners.input({});
  check("a # filter hides the scratch tabs and templates, keeps the tagged notes", !env.rows.innerHTML.includes('data-tab="t1"') && env.rows.innerHTML.includes('data-name="Alpha"') && !env.rows.innerHTML.includes("📄 TEMPLATES"));
}
// =====================================================================
// 18. 6.175.0 — THE MARKDOWN TEACHER
// =====================================================================
// LL: "I don't write markdown. Are there tool tips or autocompletes that
// will teach and help me." So the syntax is never something LL has to
// remember — and the checks here are about TEACHING as much as typing:
// a button's tooltip must name the characters it types, and the / menu's
// rows must carry the raw markdown beside the plain-English name.
{
  const env = load();
  // ---- the bar, and its tooltips ----
  const bar = html.slice(html.indexOf('id="fmt"'), html.indexOf('<textarea'));
  check("the format bar is on the page, above the text", bar.includes("wrapSel('**')") && bar.includes("blockAt('# ')"));
  check("every button carries a tooltip — a bar that does not explain "
        + "itself is a bar LL still cannot read",
        (bar.match(/<button/g) || []).length === (bar.match(/title="/g) || []).length);
  check("…and the tooltips show the SYNTAX, not just the name",
        bar.includes("**stars**") && bar.includes("# ") && bar.includes("`back ticks`"));

  // ---- ⌘B / ⌘I / ⌘E wrap, and unwrap again ----
  env.type("make me bold", 12);
  env.t.selectionStart = 8; env.t.selectionEnd = 12;
  env.key("b", { metaKey: true });
  check("⌘B wraps the selection in stars", env.t.value === "make me **bold**", env.t.value);
  check("…and leaves the WORD selected, not the stars, so ⌘I can follow",
        env.t.value.slice(env.t.selectionStart, env.t.selectionEnd) === "bold");
  env.key("b", { metaKey: true });
  check("⌘B again takes the bold off — the same key both ways", env.t.value === "make me bold", env.t.value);
  env.t.selectionStart = env.t.selectionEnd = 4;
  env.key("i", { metaKey: true });
  check("⌘I with nothing selected types the pair…", env.t.value === "make** me bold", env.t.value);
  check("…and leaves the caret BETWEEN them, ready to type the word",
        env.t.selectionStart === 5 && env.t.selectionEnd === 5, env.t.selectionStart);
  const env3 = load();
  env3.type("plain", 5);
  env3.t.selectionStart = 0; env3.t.selectionEnd = 5;
  env3.key("e", { metaKey: true });
  check("⌘E is code, in back ticks", env3.t.value === "`plain`", env3.t.value);

  // ---- the block buttons ----
  const e2 = load();
  e2.type("a heading", 3);
  e2.call("blockAt('# ')");
  check("H1 puts # at the START of the line, wherever the caret was", e2.t.value === "# a heading", e2.t.value);
  e2.call("blockAt('# ')");
  check("…and pressing it again takes it off", e2.t.value === "a heading", e2.t.value);
  e2.call("blockAt('> ')"); e2.call("blockAt('- ')");
  check("a line that already has a block marker SWAPS rather than stacking "
        + "— \"# > - hello\" is nobody's intention", e2.t.value === "- a heading", e2.t.value);
  const e3 = load();
  e3.type("one\ntwo\nthree", 0);
  e3.t.selectionStart = 0; e3.t.selectionEnd = 9;
  e3.call("blockAt('- ')");
  check("a selection gets the marker on EVERY line", e3.t.value === "- one\n- two\n- three", e3.t.value);

  // ---- the / menu ----
  const e4 = load();
  e4.type("", 0);
  e4.type("/");
  check("\"/\" on an empty line opens the block menu", e4.ac.style.display === "block");
  check("…and every row shows the plain-English name AND the markdown it types",
        e4.ac.innerHTML.includes("Heading 1") && e4.ac.innerHTML.includes('class="md"')
        && e4.ac.innerHTML.includes("- [ ] "), e4.ac.innerHTML);
  e4.key("Enter");
  check("⏎ takes the / away and applies the block — no stray slash left",
        e4.t.value === "# ", e4.t.value);
  const e5 = load();
  e5.type("");
  e5.type("/task");
  check("typing after the / filters the list by NAME, not by syntax",
        e5.ac.style.display === "block" && e5.ac.innerHTML.includes("Task"));
  e5.key("Enter");
  check("…and the task block lands clean", e5.t.value === "- [ ] ", e5.t.value);
  const e6 = load();
  e6.type("2026/09/06 and/or a/b", 21);
  check("a slash inside a DATE or a path opens nothing — a menu over "
        + "ordinary typing is a menu LL turns off", e6.ac.style.display !== "block");
  const e7 = load();
  e7.type("- [ ] milk\n/", 12);
  check("…but a / on a new empty line under a list still opens it", e7.ac.style.display === "block");

  // ---- the footer names the line you are on ----
  const e8 = load();
  const hint = (line) => e8.call("mdHint(" + JSON.stringify(line) + ")");
  check("the footer explains a heading", hint("## Plans") === "Heading 2 — the ## does that");
  check("…an unticked task, and says how to tick it", /^Task — ⌘L ticks it/.test(hint("- [ ] milk")));
  check("…a ticked one differently", /unticks/.test(hint("- [x] milk")));
  check("…a bullet, a number and a quote",
        /Bullet list/.test(hint("- milk")) && /Numbered list/.test(hint("1. milk")) && /Quote/.test(hint("> said")));
  check("…a tag, and where it goes", /🏷 TAGS list/.test(hint("bought milk #shopping")));
  check("…a link, and how to open it", /⌘⏎ opens it/.test(hint("see [[Alpha]]")));
  check("…bold and italic", /Bold/.test(hint("a **word** here")) && /Italic/.test(hint("a *word* here")));
  check("a plain line says nothing rather than inventing something", hint("just some words") === "");
  e8.type("## Plans", 8);
  check("and it is actually IN the footer, beside the counts",
        e8.foot.innerHTML.includes("Heading 2") && e8.foot.innerHTML.includes("words ·"), e8.foot.innerHTML);
  e8.type("just some words", 4);
  check("with nothing to explain it points at the / menu instead of going blank",
        e8.foot.innerHTML.includes("/ for a list of blocks"), e8.foot.innerHTML);
}

// ---- 6.183.0 — 🔎 live queries: a ```dataview block lists notes in the pane ----
{
  const Q = (body) => {
    const e = load();
    e.type("# Alpha\n\n```dataview\n" + body + "\n```\n");
    return e;
  };
  const names = (e) => e.liRows(e.qres.innerHTML).map((r) => r.attrs["data-name"]);

  const e1 = Q("LIST FROM #work");
  check("FROM #work lists Alpha and Gamma — a nested #work/deep counts under #work",
        names(e1).join(",") === "Alpha,Gamma", e1.qres.innerHTML);
  check("…and NOT Beta, which is tagged #home", !names(e1).includes("Beta"));
  check("…the pane block is shown and headed with the count",
        e1.qbox.hidden === false && e1.qh.textContent === "🔎 QUERY · 2", e1.qh.textContent);
  check("…and the header row says the query it ran, so the answer is never anonymous",
        e1.qres.innerHTML.includes("LIST FROM #work · 2"), e1.qres.innerHTML);

  check('FROM "Projects" matches on the FOLDER, not the name',
        names(Q('LIST FROM "Projects"')).join(",") === "Beta");
  check("a folder term never matches a note whose PATH merely starts with those letters",
        names(Q('LIST FROM "Project"')).length === 0);

  check("FROM [[Alpha]] lists what links TO Alpha — Gamma does, Alpha itself does not",
        names(Q("LIST FROM [[Alpha]]")).join(",") === "Gamma");

  check("- negates a term: FROM -#work drops Alpha and Gamma",
        names(Q("LIST FROM -#work")).join(",") === "2026-09-06,Beta,Long Name Here");

  check("AND is both: FROM #work AND [[Alpha]] is Gamma alone",
        names(Q("LIST FROM #work AND [[Alpha]]")).join(",") === "Gamma");
  check("OR is either: FROM #home OR #work is all three tagged notes",
        names(Q("LIST FROM #home OR #work")).join(",") === "Alpha,Beta,Gamma");
  check("AND binds tighter than OR, as it does in Dataview — Alpha is out",
        names(Q("LIST FROM #home OR #work AND [[Alpha]]")).join(",") === "Beta,Gamma");

  check("a query with no FROM lists every note — but never a TEMPLATE, which is a stencil",
        names(Q("LIST")).join(",") === "2026-09-06,Alpha,Beta,Gamma,Long Name Here");
  check("SORT name DESC turns it round",
        names(Q("LIST\nSORT name DESC")).join(",") === "Long Name Here,Gamma,Beta,Alpha,2026-09-06");
  check("SORT path sorts by where the note lives, not what it is called",
        names(Q("LIST\nSORT path")).join(",") === "Alpha,2026-09-06,Gamma,Long Name Here,Beta");

  const e2 = Q("LIST\nLIMIT 2");
  check("LIMIT caps the rows", names(e2).join(",") === "2026-09-06,Alpha");
  check("…and says how many it did not show, rather than pretending that is all",
        e2.qres.innerHTML.includes("first 2 of 5"), e2.qres.innerHTML);

  // IT DEGRADES, IT NEVER BREAKS — a clause it cannot READ is named, the rest runs
  const e3 = Q("LIST FROM #work\nWHERE rating >< 3\nSORT name");
  check("a clause it cannot read is NAMED in the pane…",
        e3.qres.innerHTML.includes("ignored: WHERE rating >&lt; 3"), e3.qres.innerHTML);
  check("…and the query still runs — a bad WHERE never costs you the whole list",
        names(e3).join(",") === "Alpha,Gamma");

  // dataviewjs is a plug-in that runs JavaScript. This never does.
  const e5 = load();
  e5.type("```dataviewjs\ndv.list(dv.pages())\n```\n");
  check("a ```dataviewjs block is refused by name and NOT executed",
        e5.qres.innerHTML.includes("is JavaScript — never run here") && names(e5).length === 0, e5.qres.innerHTML);

  // a look-alike inside ordinary code is text, not a query
  const e6 = load();
  e6.type("```\n```dataview\nLIST FROM #work\n```\n");
  check("a query-looking line inside a PLAIN code fence is left alone",
        e6.qbox.hidden === true && names(e6).length === 0, e6.qres.innerHTML);

  // the pane keeps out of the way of every note that has no query
  const e7 = load();
  e7.type("# Alpha\n\njust some words #work\n");
  check("a note without a query block shows no 🔎 QUERY section at all", e7.qbox.hidden === true);

  // 🚨 the promise: the answer is drawn beside the note, NEVER written into it
  const e8 = Q("LIST FROM #work");
  check("running a query does not touch the note's text",
        e8.t.value === "# Alpha\n\n```dataview\nLIST FROM #work\n```\n", JSON.stringify(e8.t.value));
  check("…and asks Lua for nothing — no read, no grep, no write",
        e8.sent.every((m) => m.a === "edit" || m.a === "ready"), JSON.stringify(e8.sent.map((m) => m.a)));

  // a result row opens that note, like a backlink does
  const e9 = Q("LIST FROM #work");
  e9.sent.length = 0;
  e9.click(e9.byId.links, e9.liRows(e9.qres.innerHTML)[0]);
  check("clicking a result opens that note", e9.sent[0] && e9.sent[0].a === "open" && e9.sent[0].name === "Alpha", JSON.stringify(e9.sent[0]));

  // the / menu writes the block, so the grammar never has to be typed
  const e10 = load();
  e10.type("/", 1);
  check("the / menu offers the query block", e10.ac.innerHTML.includes("live list of notes"), e10.ac.innerHTML);
  const e11 = load();
  e11.call("blockApply({kind:'query'})");
  check("choosing it types a WORKING query with the caret on the tag",
        e11.t.value.includes("```dataview\nLIST FROM #") && e11.t.value.includes("SORT name"), JSON.stringify(e11.t.value));
  const hint2 = (line) => e11.call("mdHint(" + JSON.stringify(line) + ")");
  check("the footer names a query fence rather than calling it a code block",
        /🔎 QUERY/.test(hint2("```dataview")), hint2("```dataview"));
  check("…and names the FROM line's vocabulary", /AND \/ OR/.test(hint2("LIST FROM #work")));
}

// ---- 6.185.0 — WHERE, TABLE columns and SORT over the FRONT MATTER ----
// The dump gives Alpha {status: reading, rating: 5, genre: "focus, craft"},
// Beta {status: done, rating: 3} and Gamma {status: reading} — Beta is
// #home, Alpha and Gamma are #work.
{
  const Q = (body) => { const e = load(); e.type("# Alpha\n\n```dataview\n" + body + "\n```\n"); return e; };
  const names = (e) => e.liRows(e.qres.innerHTML).map((r) => r.attrs["data-name"]);

  check("the fields reached the page at all", (() => { const e = load();
        return JSON.stringify(e.call("NOTES[1].f")) === '{"genre":"focus, craft","rating":"5","status":"reading"}'; })());

  check('WHERE status = "reading" keeps the two that are',
        names(Q('LIST\nWHERE status = "reading"')).join(",") === "Alpha,Gamma");
  check("quotes are optional — WHERE status = done reads the same",
        names(Q("LIST\nWHERE status = done")).join(",") === "Beta");
  // rating is 5, 3 and 10 — and "10" > "3" is FALSE as text, TRUE as a
  // number. Only one of those answers is right, which is what makes this
  // check able to fail when the numeric branch is removed.
  check("a comparison is NUMERIC when both sides are numbers, so 10 beats 3",
        names(Q("LIST\nWHERE rating > 3")).join(",") === "Alpha,Long Name Here");
  check("…and >= includes the boundary, which > must not",
        names(Q("LIST\nWHERE rating >= 3")).join(",") === "Alpha,Beta,Long Name Here");
  check("a bare field means HAS that field, not an error",
        names(Q("LIST\nWHERE rating")).join(",") === "Alpha,Beta,Long Name Here");
  check("! negates it: the notes with no rating at all",
        names(Q("LIST\nWHERE !rating")).join(",") === "2026-09-06,Gamma");
  // a field a note has not got is MISSING, not empty — an empty string
  // would sort and compare below everything and quietly join every result
  check("a note without the field never satisfies a <, > or = comparison",
        names(Q('LIST\nWHERE status < "z"')).join(",") === "Alpha,Beta,Gamma");
  // != is a COMPARISON, not a negation — the ! must not be eaten by the
  // negation stripper. And a note with no status at all is "not reading",
  // which is what makes `WHERE status != "done"` mean what LL expects.
  check("!= compares rather than negating, and a note without the field counts as not-equal",
        names(Q('LIST\nWHERE status != "reading"')).join(",") === "2026-09-06,Beta,Long Name Here");
  check("contains() looks inside a value, so a list field works too",
        names(Q('LIST\nWHERE contains(genre, "craft")')).join(",") === "Alpha");

  check("AND is both conditions",
        names(Q('LIST\nWHERE status = "reading" AND rating > 3')).join(",") === "Alpha");
  check("OR is either, and AND still binds tighter",
        names(Q('LIST\nWHERE status = "done" OR status = "reading" AND rating > 3')).join(",") === "Alpha,Beta");
  check("two WHERE lines are ANDed, as Dataview does",
        names(Q('LIST\nWHERE status = "reading"\nWHERE rating > 3')).join(",") === "Alpha");
  check("WHERE composes with FROM rather than replacing it",
        names(Q('LIST FROM #work\nWHERE rating > 3')).join(",") === "Alpha");

  // the file itself is askable, the way Dataview's file.* is
  check("file.folder asks where the note LIVES",
        names(Q('LIST\nWHERE file.folder = "Projects"')).join(",") === "Beta");
  check("file.name asks what it is CALLED",
        names(Q('LIST\nWHERE contains(file.name, "amma")')).join(",") === "Gamma");
  check("tags is readable as a field even though it is not stored as one",
        names(Q('LIST\nWHERE contains(tags, "work")')).join(",") === "Alpha,Gamma");

  // SORT over a field
  check("SORT rating orders by the NUMBER (3, 5, 10 — not 10, 3, 5), missing last",
        names(Q("LIST\nSORT rating")).join(",") === "Beta,Alpha,Long Name Here,2026-09-06,Gamma");
  check("…and DESC turns the ones that HAVE it round without floating the ones that do not",
        names(Q("LIST\nSORT rating DESC")).slice(0, 3).join(",") === "Long Name Here,Alpha,Beta");

  // TABLE columns
  const t1 = Q("TABLE status, rating FROM #work");
  check("TABLE lists the notes and shows the columns under each name",
        names(t1).join(",") === "Alpha,Gamma"
        && t1.qres.innerHTML.includes('<span class="qcols">status: reading · rating: 5</span>'), t1.qres.innerHTML);
  check("…a note missing a column simply omits it rather than printing a blank",
        t1.qres.innerHTML.includes(">Gamma<span class=\"qcols\">status: reading</span>"), t1.qres.innerHTML);
  check('TABLE field AS Label renames the column',
        Q('TABLE status AS Where FROM #work').qres.innerHTML.includes("Where: reading"));
  check("a column it cannot read is NAMED and the other columns still show",
        (() => { const e = Q('TABLE status, upper(rating) FROM #work');
                 return e.qres.innerHTML.includes("the column &quot;upper(rating)&quot;") && e.qres.innerHTML.includes("status: reading"); })());

  // still no reading, no writing, no messages — the 6.183.0 promise holds
  const e9 = Q('TABLE status FROM #work\nWHERE rating > 3\nSORT status');
  check("a WHERE query still touches nothing and asks Lua for nothing",
        e9.t.value.includes("WHERE rating > 3") && e9.sent.every((m) => m.a === "edit" || m.a === "ready"),
        JSON.stringify(e9.sent.map((m) => m.a)));

  // and the grammar is still never typed
  const e10 = load();
  e10.call("blockApply({kind:'queryw'})");
  check("the / menu's second query row writes a WORKING filtered query",
        /```dataview\nTABLE status FROM #/.test(e10.t.value) && e10.t.value.includes('WHERE status != "done"'),
        JSON.stringify(e10.t.value));
  const hint3 = (line) => e10.call("mdHint(" + JSON.stringify(line) + ")");
  check("the footer names a WHERE line and what can go in it",
        /contains\(field, "x"\)/.test(hint3('WHERE status = "reading"')), hint3('WHERE status = "reading"'));
  check("…and a SORT line", /front-matter field/.test(hint3("SORT rating DESC")));
}

// =====================================================================
// 6.186.0 — 🗂 THE BOARD. Columns ARE the values of one front-matter
// field; cards are the notes. And this is the one view that WRITES: the
// checks below hold it to exactly one message, naming exactly one note,
// one field and one value — and to sending nothing at all when the drag
// did not land anywhere.
// =====================================================================
{
  const B = (src) => {
    const e = load();
    if (src != null) { e.t.value = src; e.t.selectionStart = e.t.selectionEnd = 0; }
    e.sent.length = 0;
    e.call("drawBoard()");
    return e;
  };
  const K = (body) => "```kanban\n" + body + "\n```\n";
  const colNames = (e) => e.boardCols().map((c) => c.attrs["data-val"]);
  // an absent column is an EMPTY list, never null: a check must FAIL on a
  // missing column, not throw and take the rest of the section with it
  const cardsIn = (e, val) => {
    for (const c of e.boardCols()) if (c.attrs["data-val"] === val) return c.cards.map((k) => k.attrs["data-name"]);
    return [];
  };

  const RAN = pass + fail;
  try {
  // ---- the columns -------------------------------------------------------
  {
    const e = B(K("BY status"));
    check("6.186.0: the columns are the values of the field, commonest first",
          colNames(e).slice(0, 2).join("|") === "reading|done", JSON.stringify(colNames(e)));
    check("…and 'no status' is LAST — missing is missing, never a value",
          colNames(e)[colNames(e).length - 1] === "no status", JSON.stringify(colNames(e)));
    check("every card is in ITS column, not merely on the board",
          cardsIn(e, "reading").sort().join("|") === "Alpha|Gamma" && cardsIn(e, "done").join("|") === "Beta",
          JSON.stringify([cardsIn(e, "reading"), cardsIn(e, "done")]));
    check("a note without the field is a card in the last column, not dropped",
          cardsIn(e, "no status").includes("Long Name Here"), JSON.stringify(cardsIn(e, "no status")));
    check("a template is never a card", !JSON.stringify(colNames(e).concat(e.bcols.innerHTML)).includes("Meeting"));
    check("each card carries the note's REL — that is what Lua rewrites",
          e.bcols.innerHTML.includes('data-rel="Projects/Beta.md" data-name="Beta"'));
    check("the footer counts the cards and names the field", /5 cards · grouped by status/.test(e.btip.innerHTML), e.btip.innerHTML);
  }
  {
    const e = B(K("BY rating"));
    check("BY names any field — the columns become the ratings",
          colNames(e).slice(0, 3).sort().join("|") === "10|3|5", JSON.stringify(colNames(e)));
  }
  {
    const e = B(K("BY status\nCOLUMNS todo, doing, done"));
    const n = colNames(e);
    check("COLUMNS fixes the order, EMPTY ones included — there is somewhere to drag to on day one",
          n[0] === "todo" && n[1] === "doing" && n[2] === "done" && cardsIn(e, "todo").length === 0,
          JSON.stringify(n));
    check("a value COLUMNS does not name still gets a column — nothing vanishes quietly",
          n.includes("reading") && cardsIn(e, "reading").length === 2, JSON.stringify(n));
  }
  {
    const e = B(K("BY status\nFROM #work\nWHERE rating > 3"));
    check("FROM and WHERE narrow the board exactly as they narrow a query",
          cardsIn(e, "reading").join("|") === "Alpha" && !JSON.stringify(colNames(e)).includes("done"),
          JSON.stringify([colNames(e), cardsIn(e, "reading")]));
  }
  {
    const e = B(K("BY status\nWOBBLE 3"));
    check("a clause it cannot read is NAMED under the board and the board still draws",
          e.btip.innerHTML.includes("ignored: WOBBLE 3") && cardsIn(e, "reading").length === 2, e.btip.innerHTML);
  }
  {
    const e = B("# just a note\n\nnothing to see\n");
    check("a note with no ```kanban block still gets a board, and is TOLD why",
          e.btip.innerHTML.includes("no ```kanban block") && cardsIn(e, "reading").length === 2, e.btip.innerHTML);
  }
  {
    const e = B(K("BY status"));
    check("the query pane does not report a ```kanban block as an unsupported query",
          !e.qres.innerHTML.includes("kanban") && e.qbox.hidden === true, e.qres.innerHTML);
  }

  // ---- the drag: the one place the vault writes --------------------------
  {
    const e = B(K("BY status\nCOLUMNS todo, doing, done"));
    const target = e.boardCols().find((c) => c.attrs["data-val"] === "done");
    e.sent.length = 0;
    e.drag("Alpha", target);
    check("dragging a card sends ONE move, naming the note, the field and the column",
          e.sent.length === 1 && e.sent[0].a === "kmove" && e.sent[0].rel === "Alpha.md"
          && e.sent[0].field === "status" && e.sent[0].value === "done", JSON.stringify(e.sent));
    check("the page wrote nothing into the note — the board draws beside it, as the query does",
          !e.t.value.includes("done\n```") === false ? e.t.value === K("BY status\nCOLUMNS todo, doing, done") : true,
          JSON.stringify(e.t.value));
  }
  {
    const e = B(K("BY status"));
    const none = e.boardCols().find((c) => c.attrs["data-none"] === "1");
    e.sent.length = 0;
    e.drag("Alpha", none);
    check("dropping a card in the 'no status' column CLEARS the field (an empty value)",
          e.sent.length === 1 && e.sent[0].a === "kmove" && e.sent[0].value === "", JSON.stringify(e.sent));
  }
  {
    const e = B(K("BY status"));
    e.sent.length = 0;
    e.drag("Alpha", null, { still: true });
    check("a press that never moved is a CLICK — it opens the note and moves nothing",
          e.sent.length === 1 && e.sent[0].a === "open" && e.sent[0].name === "Alpha", JSON.stringify(e.sent));
  }
  {
    const e = B(K("BY status"));
    e.sent.length = 0;
    e.drag("Alpha", null);
    check("a card dropped on nothing writes nothing and says nothing",
          e.sent.filter((m) => m.a === "kmove").length === 0, JSON.stringify(e.sent));
  }
  {
    const e = B(K("BY status"));
    const own = e.boardCols().find((c) => c.attrs["data-val"] === "reading");
    e.sent.length = 0;
    e.drag("Alpha", own);
    check("a card dropped back in its OWN column writes nothing — no rewrite for no change",
          e.sent.filter((m) => m.a === "kmove").length === 0, JSON.stringify(e.sent));
  }
  {
    const e = B(K("BY status"));
    const more = e.boardCols().find((c) => c.className.indexOf("more") >= 0);
    check("the folded '… N more' column is not a real column to drop on", more === undefined);
  }

  // ---- the way in, and the way it is taught ------------------------------
  {
    const e = load();
    const k = e.key("b", { metaKey: true, shiftKey: true });
    check("⌘⇧B asks Lua for the board", k.prevented && e.sent.some((m) => m.a === "board"), JSON.stringify(e.sent));
  }
  {
    const e = load();
    e.call("blockApply({kind:'board'})");
    check("the / menu writes a WORKING board block, columns and all",
          /```kanban\nBY status\nFROM #/.test(e.t.value) && e.t.value.includes("COLUMNS todo, doing, done"),
          JSON.stringify(e.t.value));
    const h = (line) => e.call("mdHint(" + JSON.stringify(line) + ")");
    check("the footer names a kanban fence", /⌘⇧B/.test(h("```kanban")), h("```kanban"));
    check("…a BY line", /front-matter field/.test(h("BY status")), h("BY status"));
    check("…and a COLUMNS line", /order/.test(h("COLUMNS todo, doing")), h("COLUMNS todo, doing"));
    check("a sentence that merely starts with 'by' is not called a board clause",
          h("by the way this is prose") !== h("BY status"), h("by the way this is prose"));
  }
  } catch (err) {
    // 6.186.0 — without this a throw here would DELETE the checks after it
    // and the run would still say "0 failed". Silence is the failure mode
    // this whole file exists to avoid.
    check("the board section ran to the end", false, (err && err.message) || err);
  }
  check("…and every board check actually ran", pass + fail - RAN >= 27, pass + fail - RAN);
}

// 6.203.0 — the ⌘N naming bar: ⏎ no longer closes it, and a refusal is
// drawn UNDER the field LL is typing in. He pasted a whole block in here,
// the write failed on a path macOS cannot hold, and the only message was
// an hs.alert drawn BEHIND this window: "I enter a title and … I don't
// see that anything was created."
{
  // 6.186.0's rule, and this section earned it: a throw in here would
  // DELETE the checks after it while the run still said "0 failed". One
  // mutation (the name travelling as `text` again) threw on m.name.length
  // before the guard went in.
  const RAN0 = pass + fail;
  try {
  const env = load();
  env.call("askName('new','Name of the note:','')");
  check("6.203.0 — the bar opens: labelled, focused, and carrying no refusal",
        env.pr.style.display === "block" && env.prlab.textContent === "Name of the note:"
        && env.prin.focused > 0 && env.prwarn.style.display === "none", env.pr.style.display);
  env.prin.value = "Collect" + "x".repeat(3000);
  env.sent.length = 0;
  env.key("Enter");
  check("🚨 6.203.0 — ⏎ sends the name and does NOT close the bar. Lua decides;\n"
        + "        the text stays in the box because it is the only copy of the paste",
        env.sent.some((m) => m.a === "named" && m.kind === "new" && (m.name || "").length === 3007)
        && env.pr.style.display === "block" && env.prin.value.length === 3007,
        env.pr.style.display + " / " + env.prin.value.length);
  {
    const m = env.sent.find((x) => x.a === "named");
    check("🚨🚨 6.203.0 — THE NAME TRAVELS AS `name`, NEVER `text`. say() stamps the\n"
          + "        open note onto m.text on EVERY message, so for thirteen releases ⌘N\n"
          + "        handed Lua the whole note body as the file name and the name LL\n"
          + "        typed was never used at all. With no note open it sent \"\" and did\n"
          + "        nothing: \"I enter a title and I don't see that anything was created\"",
          m && m.name === env.prin.value && m.text === env.t.value && m.name !== m.text,
          m && JSON.stringify({ name: (m.name || "").slice(0, 12), text: (m.text || "").slice(0, 12) }));
  }
  env.call("prSay('that name is 3007 characters long — a file name holds 248.')");
  check("🚨 …and Lua's refusal is DRAWN under the field, with the paste still in it",
        env.prwarn.style.display === "block" && env.prwarn.textContent.includes("248")
        && env.prin.value.length === 3007, env.prwarn.textContent);
  const focusWas = env.prin.focused;
  env.call("prSay('again')");
  check("…and the caret goes back to the field, so ⏎ works on the fixed name",
        env.prin.focused > focusWas, env.prin.focused);
  env.call("askName('new','Name of the note:','')");
  check("a fresh bar never wears the last refusal",
        env.prwarn.style.display === "none" && env.prwarn.textContent === "");
  env.call("prSay('stuck')");
  env.key("Escape");
  check("esc still closes the bar, and takes the refusal with it",
        env.pr.style.display === "none" && env.prwarn.textContent === "");
  } catch (err) {
    check("the naming-bar section ran to the end", false, (err && err.message) || err);
  }
  check("…and every naming-bar check actually ran", pass + fail - RAN0 >= 7, pass + fail - RAN0);
}

// 🚨 6.203.0 — THE SENTRY. say() owns `text`, `sel` and `rel` on every
// message; a caller that sets one has it silently replaced, and that is
// how BOTH ⌘N and the board's drag were wrong with nothing to see. No
// say({…}) may ever name one of the three again.
{
  const src = scripts[0] || "";
  check("the page source was actually read (a source check over \"\" passes for free)",
        src.length > 5000, src.length);
  const bad = [...src.matchAll(/say\(\{[^}]*\}\)/g)]
        .map((m) => m[0]).filter((c) => /[{,]\s*(text|sel|rel)\s*:/.test(c));
  check("🚨 6.203.0 — no say({…}) sets text:, sel: or rel: — those are say's own,\n"
        + "        and a value handed over under one of those names never arrives",
        src.length > 5000 && bad.length === 0, bad.join(" | "));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
