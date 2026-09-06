// =====================================================================
// test_vault_js.js — RUNS the Vault page's JavaScript for real.
// =====================================================================
//   lua5.4 dump_vault_html.lua ./modules > /tmp/vault.html
//   node test_vault_js.js /tmp/vault.html
// The [[ autocomplete, the link under the caret, the note filter, the
// row walker, ⌘ keys and the graph data all live in the page.

const fs = require("fs");
const html = fs.readFileSync(process.argv[2] || "/tmp/vault.html", "utf8");
let pass = 0, fail = 0;
const check = (label, cond, extra) => {
  if (cond) pass++; else { fail++; console.log("   ❌ " + label + (extra !== undefined ? "  — " + extra : "")); }
};

function el(tag) {
  const e = { tagName: tag, value: "", innerHTML: "", style: {}, children: [], _cls: new Set(), listeners: {}, selectionStart: 0, selectionEnd: 0,
    addEventListener(ev, fn) { this.listeners[ev] = fn; },
    focus() {}, select() {}, setSelectionRange(a, b) { this.selectionStart = a; this.selectionEnd = b; },
    getAttribute(n) { return this.attrs ? this.attrs[n] : null; }, scrollIntoView() {},
    getContext() { return null; }, getBoundingClientRect() { return { left: 0, top: 0 }; } };
  e.classList = { add: (c) => e._cls.add(c), remove: (c) => e._cls.delete(c), contains: (c) => e._cls.has(c) };
  e.className = "";
  return e;
}
function makeEnv() {
  const sent = [];
  const t = el("TEXTAREA"), q = el("INPUT"), hdr = el("HEADER"), ac = el("DIV"), rows = el("UL"), links = el("DIV"), cv = el("CANVAS"), gbtn = el("BUTTON");
  const byId = { t, q, hdr, ac, rows, links, cv, gbtn };
  const docListeners = {};
  // rows are re-rendered from innerHTML; expose them as fake <li>s
  function rowsFromHtml() {
    const out = [];
    for (const m of rows.innerHTML.matchAll(/<li class="([^"]*)" data-name="([^"]*)"/g)) {
      const r = el("LI"); r.attrs = { "data-name": m[2].replace(/&quot;/g, '"') }; r.className = m[1]; out.push(r);
    }
    return out;
  }
  let cached = null;
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: (ev, fn) => { docListeners[ev] = fn; },
      querySelectorAll: (sel) => { if (!cached || cached.html !== rows.innerHTML) cached = { html: rows.innerHTML, rows: rowsFromHtml() }; return cached.rows; },
      activeElement: t,
    },
    window: { webkit: { messageHandlers: { vault: { postMessage: (m) => sent.push(m) } } },
              addEventListener() {}, devicePixelRatio: 1 },
    requestAnimationFrame() {}, Math, String, Array,
  };
  return { sandbox, sent, t, q, ac, rows, docListeners, byId };
}
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);
const vm = require("vm");
function load() {
  const env = makeEnv();
  // the textarea starts with the note's text, as the browser would
  const ta = html.match(/<textarea[^>]*>([\s\S]*?)<\/textarea>/);
  env.t.value = ta ? ta[1].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&") : "";
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "vault-page.js" });
  env.call = (expr) => vm.runInContext(expr, ctx);
  env.key = (k, o) => env.docListeners.keydown(Object.assign({ key: k, metaKey: false, altKey: false, ctrlKey: false, shiftKey: false, preventDefault() {} }, o || {}));
  env.type = (text, caret) => { env.t.value = text; env.t.selectionStart = env.t.selectionEnd = caret == null ? text.length : caret; env.t.listeners.input({}); };
  return env;
}
console.log("── Vault: page JavaScript, executed ──");

// 1. data and the note list
{
  const env = load();
  check("four notes reached the page", env.call("NOTES.length") === 4);
  check("the open note is Alpha", env.call("CUR") === "Alpha.md");
  check("the list draws every note, the open one marked", env.rows.innerHTML.includes('class="note cur" data-name="Alpha"') && env.rows.innerHTML.includes('data-name="Long Name Here"'));
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
  check("[[ alone lists every note (up to 8)", env.ac.style.display === "block" && (env.ac.innerHTML.match(/<div/g) || []).length === 4);
  env.key("ArrowDown"); env.key("ArrowDown"); env.key("Tab");
  check("↓↓ Tab picks the third name", env.t.value === "x [[Gamma]]", env.t.value);
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
// 6. the row walker: ⌥↓ from the text, plain ↓ from the filter, ⏎ opens
{
  const env = load();
  env.sent.length = 0;
  env.key("ArrowDown");
  check("plain ↓ inside the text does not move the highlight", env.call("SEL") === -1);
  env.key("ArrowDown", { altKey: true });
  check("⌥↓ highlights the first row", env.call("SEL") === 0);
  env.key("Enter", { altKey: true });
  check("⌥⏎ opens the highlighted note", env.sent.some((m) => m.a === "open" && m.name === "Alpha"), JSON.stringify(env.sent));
  env.sandbox.document.activeElement = env.q;
  env.key("ArrowDown"); env.key("ArrowDown");
  check("plain ↓ from the filter box walks on", env.call("SEL") === 2);
  env.sent.length = 0; env.key("Enter");
  check("⏎ from the filter opens the highlighted row (Gamma)", env.sent[0] && env.sent[0].a === "open" && env.sent[0].name === "Gamma", JSON.stringify(env.sent[0]));
}
// 7. graph data
{
  const env = load();
  const g = env.call("GRAPH");
  check("graph nodes: 4 notes + 1 ghost (Delta)", g.nodes.length === 5 && g.nodes.some((n) => n.ghost && n.n === "Delta"));
  check("graph edges: Alpha→Beta, Gamma→Alpha, Gamma→Delta", g.edges.length === 3);
  check("the page forwards F18 keyup and has the drag header", scripts[0].includes("a:'f18up'") && scripts[0].includes("a:'dragStart'"));
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
