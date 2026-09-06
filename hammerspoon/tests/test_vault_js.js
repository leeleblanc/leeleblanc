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
  const byId = { t, q, hdr, ac, rows, links, cv, gbtn, mode, foot, chips, outline, unl, unlh, hint, sbtn, kbtn };
  const docListeners = {};
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
      querySelectorAll: (sel) => { if (!cached || cached.html !== rows.innerHTML) cached = { html: rows.innerHTML, rows: rowsFromHtml() }; return cached.rows; },
      activeElement: t,
    },
    window: { webkit: { messageHandlers: { vault: { postMessage: (m) => sent.push(m) } } },
              addEventListener() {}, devicePixelRatio: 1 },
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
  return { sandbox, sent, t, q, ac, rows, docListeners, byId, liRows, click, mode, foot, chips, outline, unl, unlh, hint, kbtn };
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

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
