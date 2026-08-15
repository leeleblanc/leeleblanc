// =====================================================================
// test_unified_js.js — RUNS Unified Search's page code for real.
// =====================================================================
// The filtering, the @tags, the keyboard and the bridge messages all
// live in the page's JavaScript — the Lua suite can only grep for them.
// This loads the real generated page (dump_unified_html.lua), gives it a
// stub DOM, and drives actual typing, arrows, Enter/⌘Enter/Escape,
// clicks and the header grab through the actual handlers.
//
//   lua5.4 dump_unified_html.lua ./modules > /tmp/unified.html
//   node test_unified_js.js /tmp/unified.html

const fs = require("fs");
const htmlPath = process.argv[2] || "/tmp/unified.html";
const html = fs.readFileSync(htmlPath, "utf8");

let pass = 0, fail = 0; const failures = [];
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};

function makeEnv() {
  const sent = [];
  const listeners = { q: {}, list: {}, bar: {}, window: {} };
  const q = {
    value: "", focused: false,
    focus() { this.focused = true; },
    addEventListener: (ev, fn) => { listeners.q[ev] = fn; },
  };
  const list = {
    innerHTML: "",
    addEventListener: (ev, fn) => { listeners.list[ev] = fn; },
  };
  const count = { textContent: "" };
  const barClasses = [];
  const bar = {
    addEventListener: (ev, fn) => { listeners.bar[ev] = fn; },
    classList: {
      add: (c) => barClasses.push("+" + c),
      remove: (c) => barClasses.push("-" + c),
    },
  };
  const byId = { q, list, count, bar };
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      querySelector: () => null,
    },
    window: { addEventListener: (ev, fn) => { listeners.window[ev] = fn; } },
    webkit: { messageHandlers: { unifiedSearch: { postMessage: (m) => sent.push(m) } } },
    parseInt,
  };
  return { sandbox, sent, listeners, q, list, count, bar, barClasses };
}

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

const vm = require("vm");
function load() {
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "unified_search-page.js" });
  env.ctx = ctx;
  env.call = (expr) => vm.runInContext(expr, ctx);
  env.type = (s) => { env.q.value = s; env.listeners.q.input({}); };
  env.key = (k, meta) =>
    env.listeners.window.keydown({ key: k, metaKey: meta === true, preventDefault() {} });
  return env;
}

console.log("── Unified Search: page JavaScript, executed ──");

// =====================================================================
// 1. the data made it into the page
// =====================================================================
{
  const env = load();
  check("nine rows across five stores", env.call("ROWS.length") === 9,
        env.call("ROWS.length"));
  check("sources carry their counts",
        env.call("SRCS.filter(function(s){return s.n>0}).length") === 5);
  check("screenshot rows carry a thumbnail data URI",
        env.call("ROWS.filter(function(r){return r.img}).length") === 2);
}

// =====================================================================
// 2. nothing typed — the grouped view
// =====================================================================
{
  const env = load();
  check("every non-empty store gets a section header",
        (env.list.innerHTML.match(/class="sec"/g) || []).length === 5,
        env.list.innerHTML.slice(0, 120));
  check("…named and counted", env.list.innerHTML.indexOf("Clipboard — 3") !== -1);
  check("the count line says what is indexed",
        env.count.textContent.indexOf("9 items indexed") === 0,
        env.count.textContent);
  check("thumbnails render at panel size",
        env.list.innerHTML.indexOf('<img class="th" src="data:image') !== -1);
  check("the search field took focus", env.q.focused === true);
  check("a copied <script> renders as text, never as markup",
        env.list.innerHTML.indexOf("<script>alert") === -1
        && env.list.innerHTML.indexOf("&lt;script&gt;") !== -1);
}

// =====================================================================
// 3. typing filters — every word must match, @tags pin a source
// =====================================================================
{
  const env = load();
  env.type("receipt");
  check("one word narrows to every store that mentions it",
        env.call("visible.length") === 5
        && env.list.innerHTML.indexOf('class="sec"') === -1,
        env.call("visible.length"));
  check("…and the count line reports it",
        env.count.textContent.indexOf("5 matches") === 0, env.count.textContent);
  env.type("receipt cafe");
  check("every word must match — two words, one row",
        env.call("visible.length") === 1);
  env.type("receipt zzz");
  check("no match explains itself instead of going blank",
        env.call("visible.length") === 0
        && env.list.innerHTML.indexOf("Nothing matches") !== -1);
  env.type("@shots receipt");
  check("an @tag pins the source", env.call("visible.length") === 1
        && env.call("ROWS.filter(function(r){return r.id===visible[0]})[0].tag") === "shots");
  env.type("@cmd");
  check("…any source", env.call("visible.length") === 2);
  env.type("");
  check("backspace to empty brings the grouped view back",
        env.list.innerHTML.indexOf('class="sec"') !== -1);
  env.call("CAP = 2");
  env.type("receipt");
  check("past the cap the page says how much more there is",
        env.call("visible.length") === 2
        && env.list.innerHTML.indexOf("and 3 more") !== -1,
        env.list.innerHTML.slice(-160));
}

// =====================================================================
// 4. the keyboard — arrows, ⏎ copies, ⌘⏎ path, Esc closes
// =====================================================================
{
  const env = load();
  env.type("receipt");
  check("selection starts at the top", env.call("sel") === 0);
  env.key("ArrowDown");
  env.key("ArrowDown");
  check("arrows walk the list", env.call("sel") === 2);
  check("…and the selected row is marked",
        env.list.innerHTML.indexOf('class="row sel"') !== -1);
  env.key("ArrowUp");
  check("…both ways", env.call("sel") === 1);
  for (let i = 0; i < 9; i++) env.key("ArrowDown");
  check("…and never off the end", env.call("sel") === 4);
  env.key("Enter");
  check("⏎ sends pick with the SELECTED row's id",
        env.sent.length === 1 && env.sent[0].a === "pick"
        && env.sent[0].id === env.call("visible[sel]"),
        JSON.stringify(env.sent[0]));
  env.key("Enter", true);
  check("⌘⏎ asks for the path instead",
        env.sent[1] && env.sent[1].a === "path");
  env.key("Escape");
  check("Esc says close", env.sent[2] && env.sent[2].a === "close");
}

// =====================================================================
// 5. the mouse — row clicks and the header grab
// =====================================================================
{
  const env = load();
  env.type("receipt");
  env.listeners.list.click({
    target: { getAttribute: (k) => (k === "data-id" ? "5" : null) },
    metaKey: false,
  });
  check("clicking a row picks it by id",
        env.sent[0] && env.sent[0].a === "pick" && env.sent[0].id === 5,
        JSON.stringify(env.sent[0]));
  env.listeners.list.click({
    target: {
      getAttribute: () => null,
      parentNode: { getAttribute: (k) => (k === "data-id" ? "7" : null) },
    },
    metaKey: true,
  });
  check("…through child elements, ⌘-click = path",
        env.sent[1] && env.sent[1].a === "path" && env.sent[1].id === 7);
  env.listeners.bar.mousedown({ preventDefault() {} });
  check("grabbing the header reports dragStart to Lua",
        env.sent[2] && env.sent[2].a === "dragStart");
  check("…and shows the grabbing cursor", env.barClasses[0] === "+dragging");
  env.listeners.window.mouseup({});
  check("…released on mouse up", env.barClasses[1] === "-dragging");
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) {
  console.log("FAILURES:");
  for (const f of failures) console.log("   ❌ " + f);
  process.exit(1);
}
