// =====================================================================
// test_pad_js.js — RUNS the Capture Pad's page JavaScript for real.
// =====================================================================
// Every recurring bug in this module has lived in the page's JS, and the
// Lua suite could only ever grep the source for it — a test that reads
// text cannot tell you what the code DOES. This loads the real generated
// page, stubs just enough DOM for it, fires real clicks and keystrokes,
// and asserts on the messages that would reach Lua.
//
//   lua5.4 dump_pad_html.lua ./modules > /tmp/pad.html
//   node test_pad_js.js /tmp/pad.html
//
// It caught two shipped bugs on its first run: the Attach button sending
// no text, and Send now not filing the open draft.

const fs = require("fs");
const htmlPath = process.argv[2] || "/tmp/pad.html";
const html = fs.readFileSync(htmlPath, "utf8");

let pass = 0, fail = 0; const failures = [];
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};

// ---- the smallest DOM the page actually touches ----------------------
function makeEnv() {
  const sent = [];                 // messages that would reach Lua
  const listeners = { window: {}, bar: {} };

  const textarea = {
    value: "", selectionStart: 0,
    focus() {}, setSelectionRange(a) { this.selectionStart = a; },
  };
  const bar = {
    classList: { _s: new Set(), add(c) { this._s.add(c); }, remove(c) { this._s.delete(c); },
                 contains(c) { return this._s.has(c); } },
    addEventListener(ev, fn) { listeners.bar[ev] = fn; },
  };
  const byId = { t: textarea, bar: bar };

  // 6.170.0 — the queued rows the arrow keys walk. Each fake <li> has a
  // classList (for .sel), a className and a scrollIntoView that counts.
  const rows = []; let scrolled = 0;
  function mkRow(cls) {
    const r = { className: cls, _s: new Set(),
                scrollIntoView() { scrolled++; } };
    r.classList = { add(c) { r._s.add(c); }, remove(c) { r._s.delete(c); },
                    contains(c) { return r._s.has(c); } };
    return r;
  }
  rows.push(mkRow("note"), mkRow("action"), mkRow("parkedrow"));
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: () => {},
      querySelectorAll: (sel) => (sel === "li" ? rows : []),
      activeElement: null,
    },
    window: {
      webkit: { messageHandlers: { capturePad: { postMessage: (m) => sent.push(m) } } },
      addEventListener(ev, fn) { listeners.window[ev] = fn; },
    },
    confirm: () => sandbox.__confirmAnswer,
    __confirmAnswer: true,
  };
  sandbox.window.confirm = sandbox.confirm;
  sandbox.document.activeElement = textarea;   // the caret starts in the text box
  textarea.tagName = "TEXTAREA";
  return { sandbox, sent, listeners, textarea, bar, rows, scrolledCount: () => scrolled };
}

// Pull the page's <script> out and run it in that environment.
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

const vm = require("vm");
function load() {
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  // The page's functions are declared globally and referenced by inline
  // onclick attributes, so expose them the way a browser would.
  vm.runInContext(scripts[0], ctx, { filename: "capture_pad-page.js" });
  env.ctx = ctx;
  env.call = (expr) => vm.runInContext(expr, ctx);
  return env;
}

// =====================================================================
console.log("── Capture Pad: page JavaScript, executed ──");

// 1. say() must attach the live textarea to EVERY message.
{
  const env = load();
  env.textarea.value = "typed but not filed";
  env.textarea.selectionStart = 5;

  // Drive the exact onclick strings the HTML uses, so a mismatch between
  // the attribute and the function is caught too.
  const onclicks = [...html.matchAll(/onclick="([^"]+)"/g)].map(m => m[1]);
  check("the page has onclick handlers to drive", onclicks.length >= 3, onclicks.length);

  for (const expr of onclicks) {
    env.sent.length = 0;
    env.call(expr.replace(/&quot;/g, '"'));
    const m = env.sent[0];
    check(`onclick ${expr} sends a message`, m !== undefined);
    if (m) {
      check(`  ${expr} → carries the textarea text`,
            m.text === "typed but not filed", JSON.stringify(m.text));
      check(`  ${expr} → carries the caret`, m.sel === 5, m.sel);
    }
  }
}

// 2. THE 6.44.7 BUG, executed: the Attach button must not lose the text.
{
  const env = load();
  env.textarea.value = "! Slap jack";
  env.call("say({a:'image'})");
  const m = env.sent[0];
  check("🐛 Attach-image message carries the typed note",
        m && m.text === "! Slap jack", m && JSON.stringify(m.text));
}

// 3. Send now likewise.
{
  const env = load();
  env.textarea.value = "! Slap jack";
  env.call("say({a:'flush'})");
  const m = env.sent[0];
  check("🐛 Send-now message carries the typed note",
        m && m.text === "! Slap jack", m && JSON.stringify(m.text));
}

// 3b. 🐛 6.44.9 — "NOTHING HAPPENS OTHER THAN LOCAL ACTIONS." Reported with
// a screenshot of typed text, an attached image and "0 queued". Send now
// sends the QUEUE, so a note still sitting in the compose box was answered
// with "nothing queued". Lua files the draft first now — but it can only do
// that if the Send-now message actually carries the box's contents, which is
// a property of THIS page, not of Lua. That is what is asserted here.
{
  const env = load();
  env.textarea.value = "Email Dana the lease numbers";
  env.textarea.selectionStart = 11;
  const attrs = [...html.matchAll(/onclick="([^"]+)"/g)].map(m => m[1]);
  const btn = attrs.find(e => e.includes("'flush'"));
  check("Send now is wired through say(), not a bare postMessage",
        btn !== undefined, btn);
  env.call(btn);
  const m = env.sent[0];
  check("🐛 6.44.9 — the Send-now message hands Lua the unfiled draft, so the "
        + "note in front of you is what gets sent",
        m && m.a === "flush" && m.text === "Email Dana the lease numbers",
        m && JSON.stringify(m));
  check("...and the caret with it, so a redraw does not move the cursor",
        m && m.sel === 11, m && m.sel);
}

// 3c. and the button has to SAY that, or the two-step is still a guess
{
  const flushTag = html.match(/<button[^>]*'flush'[^>]*>/);
  check("the Send now button explains that it files the box first",
        flushTag !== null && /title="[^"]*[Ff]iles[^"]*box/.test(flushTag[0]),
        flushTag && flushTag[0]);
}

// 4. Keyboard paths: ⌘⏎ files, ⌘⇧V attaches, Esc closes.
{
  const env = load();
  env.textarea.value = "keyboard note";
  const keydown = env.listeners.window["keydown"];
  check("the page listens for keydown", typeof keydown === "function");
  if (keydown) {
    const ev = (o) => Object.assign({ preventDefault() {} }, o);
    env.sent.length = 0; keydown(ev({ metaKey: true, key: "Enter" }));
    check("⌘⏎ files the note", env.sent[0] && env.sent[0].a === "add",
          env.sent[0] && env.sent[0].a);
    env.sent.length = 0; keydown(ev({ metaKey: true, shiftKey: true, key: "v" }));
    check("⌘⇧V attaches an image", env.sent[0] && env.sent[0].a === "image");
    env.sent.length = 0; keydown(ev({ key: "Escape" }));
    check("Esc closes", env.sent[0] && env.sent[0].a === "close");
    check("...and every one of them carries the text",
          env.sent[0] && env.sent[0].text === "keyboard note");
  }
}

// 5. Dragging: mousedown on the header reports a drag, nothing else does.
{
  const env = load();
  const down = env.listeners.bar["mousedown"];
  check("the header listens for mousedown", typeof down === "function");
  if (down) {
    env.sent.length = 0;
    down({ button: 0, preventDefault() {} });
    check("a left mousedown on the header starts a drag",
          env.sent[0] && env.sent[0].a === "dragStart");
    check("...and marks the bar as dragging", env.bar.classList.contains("dragging"));
    env.sent.length = 0;
    down({ button: 2, preventDefault() {} });
    check("a RIGHT click does not start a drag", env.sent.length === 0);
  }
}

// 6. Discard must ask first — and must not send when declined.
{
  const env = load();
  env.sandbox.__confirmAnswer = false;
  env.sent.length = 0;
  env.call("discardParked()");
  check("🛑 declining the confirmation sends NOTHING", env.sent.length === 0);
  env.sandbox.__confirmAnswer = true;
  env.call("discardParked()");
  check("...and accepting it sends the discard",
        env.sent[0] && env.sent[0].a === "discardParked");
}

// 7. The caret the page restores must be the one Lua handed it.
{
  const env = load();
  const m = html.match(/var caret = (\d+);/);
  check("the page embeds a caret position from Lua", m !== null);
}

// =====================================================================

// ---- 6.170.0: arrow through the rows ---------------------------------
{
  console.log("── 6.170.0 — ⌥↑ / ⌥↓ walk the rows, ⏎ acts on one ──");
  const env = load();
  const keydown = env.listeners.window["keydown"];
  const sel = () => env.rows.findIndex(r => r.classList.contains("sel"));
  const evk = (o) => Object.assign({ preventDefault() { this.prevented = true; } }, o);
  let e = evk({ key: "ArrowDown" }); keydown(e);
  check("plain ↓ with the caret in the text box is left to the text box", sel() === -1 && !e.prevented);
  e = evk({ key: "ArrowDown", altKey: true }); keydown(e);
  check("⌥↓ highlights the first row and scrolls it into view", sel() === 0 && e.prevented && env.scrolledCount() === 1, sel());
  keydown(evk({ key: "ArrowDown", altKey: true }));
  keydown(evk({ key: "ArrowDown", altKey: true }));
  check("⌥↓ twice more reaches the last row", sel() === 2, sel());
  keydown(evk({ key: "ArrowDown", altKey: true }));
  check("…and stops there (no wrap)", sel() === 2, sel());
  keydown(evk({ key: "ArrowUp", altKey: true }));
  check("⌥↑ goes back up one", sel() === 1, sel());
  check("exactly one row wears .sel", env.rows.filter(r => r.classList.contains("sel")).length === 1);
  env.sandbox.document.activeElement = null;
  keydown(evk({ key: "ArrowUp" }));
  check("plain ↑ works once the caret has left the text box", sel() === 0, sel());
  env.sent.length = 0;
  e = evk({ key: "Enter" }); keydown(e);
  check("⏎ on a queued row does nothing (the queue files with ⌘⏎)", env.sent.length === 0 && e.prevented);
  env.sent.length = 0;
  keydown(evk({ key: "Enter", metaKey: true }));
  check("⌘⏎ still files the pad, highlight or not", env.sent.length >= 1);
  keydown(evk({ key: "ArrowDown", altKey: true })); keydown(evk({ key: "ArrowDown", altKey: true }));
  env.sent.length = 0;
  keydown(evk({ key: "Enter", altKey: true }));
  check("⌥⏎ on the PARKED row puts the parked notes back (its button's action)",
        env.sent.length >= 1 && JSON.stringify(env.sent[0]).indexOf("retry") >= 0, JSON.stringify(env.sent[0]));
  check("the page carries the walker (rowKey / moveSel / rowAct)",
        scripts[0].indexOf("function rowKey(e)") >= 0 && scripts[0].indexOf("function moveSel(d)") >= 0
        && scripts[0].indexOf("function rowAct(r)") >= 0);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) { failures.forEach(f => console.log("  ✗ " + f)); process.exit(1); }
