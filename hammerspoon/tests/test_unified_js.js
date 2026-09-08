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
  const listeners = { q: {}, list: {}, bar: {}, window: {}, document: {} };
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
      // 6.193.0 — the page now listens for the ⇪ (F18) keyUp here.
      addEventListener: (ev, fn) => { listeners.document[ev] = fn; },
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
  env.keyup = (k, code) =>
    env.listeners.document.keyup({ key: k, keyCode: code });
  env.key = (k, meta, alt) =>
    env.listeners.window.keydown({ key: k, metaKey: meta === true, altKey: alt === true,
                                   preventDefault() {} });
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

// =====================================================================
// 6. 🖼 6.187.0 — ⌥⏎ OPENS the file. A 40 px thumbnail tells you WHICH
// picture a row is; it does not tell you what is in it.
// =====================================================================
{
  const env = load();
  env.key("Enter", false, true);
  check("⌥⏎ asks Lua to OPEN the row, not to copy it",
        env.sent[0] && env.sent[0].a === "open", JSON.stringify(env.sent[0]));
  const env2 = load();
  env2.key("Enter", true, false);
  check("⌘⏎ still copies the PATH — ⌥ did not steal it",
        env2.sent[0] && env2.sent[0].a === "path", JSON.stringify(env2.sent[0]));
  const env3 = load();
  env3.key("Enter", false, false);
  check("…and a plain ⏎ still picks", env3.sent[0] && env3.sent[0].a === "pick");
  const env4 = load();
  env4.key("Enter", true, true);
  check("⌘⌥⏎ opens rather than doing both — one keypress, one verb",
        env4.sent[0] && env4.sent[0].a === "open", JSON.stringify(env4.sent[0]));
  const env5 = load();
  env5.listeners.list.click({
    target: { getAttribute: (k) => (k === "data-id" ? "3" : null) },
    metaKey: false, altKey: true,
  });
  check("⌥-click opens too — the mouse and the keyboard agree",
        env5.sent[0] && env5.sent[0].a === "open" && env5.sent[0].id === 3,
        JSON.stringify(env5.sent[0]));
  const env6 = load();
  check("the row hint tells you both extra keys exist",
        env6.call("rowHtml({id:1,tag:'images',icon:'\u{1F5BC}',src:'Images',t:'a.png',s:'',h:'',p:1}, 0)")
            .indexOf("\u2325\u23ce open") >= 0,
        env6.call("rowHtml({id:1,tag:'images',icon:'x',src:'Images',t:'a.png',s:'',h:'',p:1}, 0)"));
}

// ⌨️ 6.193.0 — THE ⇪ RELEASE HANDSHAKE. LL: "For some reasons Unified
// Search is stuck on the screen sometimes", with the matching Console
// line "⇪ released by the watchdog — held 8s … no F18 keyUp". Every
// other text panel here has forwarded that keyup since 6.165.1; this
// page did not, so the hold sat latched and the panel felt stuck.
{
  const env = load();
  env.keyup("F18", 79);
  check("the page tells Lua when it sees the ⇪ (F18) keyUp itself",
        env.sent.length === 1 && env.sent[0].a === "f18up",
        JSON.stringify(env.sent));
  // 🚨 It must be the F18 keyup ONLY. Reporting a release on every keyup
  // would end the hold while LL is still holding it — the opposite bug,
  // and a much quieter one.
  const env2 = load();
  env2.keyup("a", 0); env2.keyup("Escape", 53); env2.keyup("Shift", 56);
  check("...and ONLY for that key — an ordinary keyup is not a release",
        env2.sent.length === 0, JSON.stringify(env2.sent));
  // Some keyboards report the key by name, some only by code; both are
  // the same physical release.
  const env3 = load();
  env3.keyup("Unidentified", 79);
  check("...recognised by keyCode as well as by name", env3.sent.length === 1);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) {
  console.log("FAILURES:");
  for (const f of failures) console.log("   ❌ " + f);
  process.exit(1);
}
