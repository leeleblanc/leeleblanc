// =====================================================================
// test_scratch_js.js — RUNS 📝 Hamsidian tabs' page code for real.
// =====================================================================
// Six pages this config draws had a suite and this one did not — and it
// is the page holding his writing: a tab strip, a HISTORY strip of every
// tab he has closed, a filter box and the shared row walker. 6.231.0's
// rule, unpaid here until now: A PAGE THIS CONFIG DRAWS IS A PAGE THE
// GATE RUNS.
//
//   lua5.4 dump_scratch_html.lua ./modules > /tmp/scratch.html
//   node test_scratch_js.js /tmp/scratch.html
//
// 🚨 THE REASON IT COULD NOT WAIT is 6.364.0's ✕. ONE click handler
// serves the ✕ and the row it sits inside, so a version that asks them
// in the wrong order RESTORES the tab it was told to forget — which is
// 6.272.0's defect exactly, where the music card PLAYED the track it was
// removing. Grepping the source for both strings passes with the order
// wrong. Firing a real click on a real ✕ does not.

const fs = require("fs");
const vm = require("vm");
const htmlPath = process.argv[2] || "/tmp/scratch.html";
const html = fs.readFileSync(htmlPath, "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);

let pass = 0, fail = 0; const failures = [];
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};
// 🧪 Read every message through these, never `sent[0].a` directly: a
// mutation that stops one being posted must FAIL the check that wanted
// it, not throw on `undefined.a` and take every check after it with the
// run still printing "0 failed" (6.186.0).
const actOf = (m) => (m && typeof m === "object" && m.a) || "";
const ridOf = (m) => (m && typeof m === "object" && m.rid) || "";

// ---- the smallest DOM this page actually touches ---------------------
// Elements carry a parent and a className so `closest` can walk up the
// way the real one does — which is the whole mechanism under test.
function mkEl(tag, cls, attrs, parent) {
  const el = {
    tagName: tag, className: cls || "", _attrs: attrs || {}, parent: parent || null,
    children: [], innerHTML: "", textContent: "", value: "", style: {},
    getAttribute(n) { return n in this._attrs ? this._attrs[n] : null; },
    setAttribute(n, v) { this._attrs[n] = v; },
    focus() {}, select() {}, scrollIntoView() {},
    addEventListener(ev, fn) { this._on = this._on || {}; this._on[ev] = fn; },
  };
  el.classList = {
    add: (c) => { if (!el.className.split(" ").includes(c)) el.className = (el.className + " " + c).trim(); },
    remove: (c) => { el.className = el.className.split(" ").filter((x) => x && x !== c).join(" "); },
    contains: (c) => el.className.split(" ").includes(c),
  };
  // A faithful-enough `closest`: ".row" matches a class, "[data-x]"
  // matches the presence of that attribute, and it walks UP including
  // the element itself — exactly as the DOM's does.
  el.closest = function (sel) {
    let n = this;
    while (n) {
      if (sel.startsWith(".") && n.className.split(" ").includes(sel.slice(1))) return n;
      if (sel.startsWith("[") && sel.endsWith("]")
          && n.getAttribute(sel.slice(1, -1)) !== null) return n;
      if (sel.startsWith("#") && n._attrs.id === sel.slice(1)) return n;
      n = n.parent;
    }
    return null;
  };
  if (parent) parent.children.push(el);
  return el;
}

function makeEnv() {
  const sent = [];
  const listeners = { document: {}, el: {} };
  // Every id the page really touches — read out of the generated HTML
  // rather than guessed, because a missing one throws at load and takes
  // the whole suite with it.
  const ids = ["t", "q", "rows", "cnt", "tabs", "pin", "send", "close", "hist", "bar"];
  const byId = {};
  for (const id of ids) {
    byId[id] = mkEl(id === "t" ? "TEXTAREA" : (id === "q" ? "INPUT" : "DIV"), "", { id });
    byId[id].addEventListener = function (ev, fn) { listeners.el[id + ":" + ev] = fn; };
  }
  byId.t.value = "a draft I am typing";
  byId.t.selectionStart = 0;
  byId.t.setSelectionRange = function (a) { this.selectionStart = a; };
  // The rows the walker queries. They are rebuilt from the page's own
  // `draw()` output after every redraw, so what the walker sees is what
  // the page really wrote rather than a fixture.
  let rowEls = [];
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: (ev, fn) => { listeners.document[ev] = fn; },
      querySelectorAll: (sel) => (sel === "#rows .row" ? rowEls : []),
      activeElement: byId.t,
    },
    window: {
      webkit: { messageHandlers: { scratchPad: { postMessage: (m) => sent.push(m) } } },
      addEventListener: () => {},
    },
  };
  sandbox.webkit = sandbox.window.webkit;
  return { sandbox, sent, listeners, byId,
           setRowEls: (r) => { rowEls = r; }, getRowEls: () => rowEls };
}

// Re-reads the rows the page just drew into #rows.innerHTML and builds
// real elements for them, so a click lands on something the page made.
function syncRows(env) {
  const h = env.byId.rows.innerHTML || "";
  const out = [];
  const re = /<div class="row([^"]*)" data-id="([^"]*)">([\s\S]*?)<\/div>/g;
  let m;
  while ((m = re.exec(h)) !== null) {
    const row = mkEl("DIV", ("row" + m[1]).trim(), { "data-id": m[2] });
    // the spans inside, so a click can land on the title OR on the ✕
    const body = m[3];
    mkEl("SPAN", "w", {}, row);
    mkEl("SPAN", "t", {}, row);
    mkEl("SPAN", "p", {}, row);
    if (body.indexOf('data-x="1"') !== -1) mkEl("SPAN", "x", { "data-x": "1" }, row);
    out.push(row);
  }
  env.setRowEls(out);
  return out;
}

function load() {
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "scratch_pad-page.js" });
  env.loadSent = env.sent.slice();
  env.sent.length = 0;
  env.call = (expr) => vm.runInContext(expr, ctx);
  env.key = (k, o) => (env.listeners.document.keydown || (() => {}))(
    Object.assign({ key: k, metaKey: false, ctrlKey: false, altKey: false,
                    shiftKey: false, preventDefault() {} }, o || {}));
  env.clickRows = (target) =>
    (env.listeners.el["rows:click"] || (() => {}))({ target, preventDefault() {} });
  env.filter = (text) => {
    env.byId.q.value = text;
    (env.listeners.el["q:input"] || (() => {}))({});
    syncRows(env);
  };
  syncRows(env);
  return env;
}

console.log("── Hamsidian tabs: page JavaScript, executed ──");

// =====================================================================
// 1. the history strip draws, and draws safely
// =====================================================================
{
  const env = load();
  const rows = env.getRowEls();
  check("the three closed tabs are drawn as rows", rows.length === 3, rows.length);
  const h = env.byId.rows.innerHTML;
  // 6.231.1's lesson in a second page: a title is a NAME and a name may
  // hold anything. An unescaped & or < swallows the rest of the row.
  check("a title with an ampersand is escaped, not swallowed",
        h.indexOf("Simon &amp; Garfunkel") !== -1, h.slice(0, 120));
  check("a title with angle brackets draws as text, never as markup",
        h.indexOf("&lt;b&gt;bold&lt;/b&gt;") !== -1 && h.indexOf("<b>bold</b>") === -1);
  check("the count line names how many of how many", env.byId.cnt.textContent === "3 / 3",
        env.byId.cnt.textContent);
}

// =====================================================================
// 2. 🚨 THE ✕ IS ASKED BEFORE THE ROW — 6.364.0's whole reason
// =====================================================================
{
  const env = load();
  const row = env.getRowEls()[1];                       // the middle one
  const x = row.children.find((c) => c.className === "x");
  check("every history row carries a ✕", !!x);
  env.sent.length = 0;
  env.clickRows(x);
  // EXACTLY ONE message, and it is the forget. A handler that tests the
  // row first sends 'restore' — the tab reopens and nothing is forgotten.
  check("🚨 clicking the ✕ sends EXACTLY ONE message", env.sent.length === 1, env.sent.length);
  check("🚨 …and it is 'forget', never 'restore'", actOf(env.sent[0]) === "forget",
        actOf(env.sent[0]));
  check("…naming the row that was clicked, by id",
        ridOf(env.sent[0]) === "h-tag", ridOf(env.sent[0]));
}

// =====================================================================
// 3. clicking the ROW still restores it — the ✕ must not cost that
// =====================================================================
{
  const env = load();
  const row = env.getRowEls()[0];
  const title = row.children.find((c) => c.className === "t");
  env.sent.length = 0;
  env.clickRows(title);
  check("clicking a row's title still restores that tab",
        env.sent.length === 1 && actOf(env.sent[0]) === "restore", actOf(env.sent[0]));
  check("…and names the row it was on", ridOf(env.sent[0]) === "h-amp", ridOf(env.sent[0]));
}

// =====================================================================
// 4. the page drops the row itself — the undo stack survives (6.323.0)
// =====================================================================
{
  const env = load();
  const row = env.getRowEls()[2];
  const x = row.children.find((c) => c.className === "x");
  env.clickRows(x);
  check("🪟 the page removes the row from its OWN list and redraws",
        env.byId.rows.innerHTML.indexOf("h-plain") === -1,
        env.byId.rows.innerHTML.slice(0, 80));
  check("…and the other two are still drawn — it dropped one, not the list",
        env.byId.rows.innerHTML.indexOf("h-amp") !== -1
        && env.byId.rows.innerHTML.indexOf("h-tag") !== -1);
  check("…and the count follows", env.byId.cnt.textContent === "2 / 2",
        env.byId.cnt.textContent);
}

// =====================================================================
// 5. ⌥⌫ forgets the highlighted row — and a BARE ⌫ never does
// =====================================================================
{
  const env = load();
  env.key("ArrowDown", { altKey: true });              // highlight the first row
  env.sent.length = 0;
  env.key("Backspace", { altKey: true });
  check("⌥⌫ on the highlighted row sends a forget",
        env.sent.length === 1 && actOf(env.sent[0]) === "forget", actOf(env.sent[0]));
  check("…for the row the highlight was on", ridOf(env.sent[0]) === "h-amp",
        ridOf(env.sent[0]));

  // 🚨 THE FIXTURE THAT BITES. `inText()` only knows about the TEXTAREA,
  // so a bare Backspace guarded by it would still fire while the caret is
  // in the FILTER box — eating a character he meant to delete. The ⌥ is
  // what makes the key unambiguous, and this is the input where the two
  // implementations must differ.
  const env2 = load();
  env2.key("ArrowDown", { altKey: true });
  env2.sent.length = 0;
  env2.key("Backspace");                                // no ⌥
  check("🚨 a BARE Backspace forgets nothing", env2.sent.length === 0,
        JSON.stringify(env2.sent));

  const env3 = load();
  env3.sent.length = 0;
  env3.key("Backspace", { altKey: true });              // nothing highlighted
  check("⌥⌫ with no row highlighted does nothing and does not throw",
        env3.sent.length === 0, JSON.stringify(env3.sent));
}

// =====================================================================
// 6. the walker still walks, and ⏎ still restores
// =====================================================================
{
  const env = load();
  env.key("ArrowDown", { altKey: true });
  env.key("ArrowDown", { altKey: true });
  env.sent.length = 0;
  env.key("Enter", { altKey: true });
  check("⌥⏎ on the highlighted row restores it, as it always did",
        env.sent.length === 1 && actOf(env.sent[0]) === "restore", actOf(env.sent[0]));
  check("…and it is the SECOND row, so the arrows really moved",
        ridOf(env.sent[0]) === "h-tag", ridOf(env.sent[0]));
}

// =====================================================================
// 7. the filter still filters, and the ✕ works on a FILTERED row
// =====================================================================
{
  const env = load();
  env.filter("ordinary");
  check("the filter narrows the strip to the matching row",
        env.getRowEls().length === 1, env.getRowEls().length);
  const row = env.getRowEls()[0];
  const x = row.children.find((c) => c.className === "x");
  env.sent.length = 0;
  env.clickRows(x);
  // 🚨 BY ID, NEVER BY ROW NUMBER (6.186.0 · 6.272.0). Under a filter the
  // visible row 1 is the store's row 3, so an index forgets the wrong tab
  // — and this is the fixture where the two must differ.
  check("🚨 the ✕ on a FILTERED row forgets that row, not the first one",
        ridOf(env.sent[0]) === "h-plain", ridOf(env.sent[0]));
}

// =====================================================================
// 8. the tab strip's own ✕ is a CLOSE, not a forget
// =====================================================================
{
  const env = load();
  const tabsHtml = env.byId.tabs.innerHTML;
  // the tab strip is written by Lua into the page, so read the page text
  check("the open tabs are drawn with their own ✕",
        html.indexOf('class="x" title="Close ⌘W"') !== -1);
  // and the two handlers are different ones — a shared name here would
  // make closing a tab forget a closed one, or the reverse
  check("the tab strip and the history strip have separate click handlers",
        !!env.listeners.el["tabs:click"] && !!env.listeners.el["rows:click"]);
}

console.log(`${pass} passed, ${fail} failed`);
if (fail) { for (const f of failures) console.log("   ❌ " + f); process.exit(1); }
