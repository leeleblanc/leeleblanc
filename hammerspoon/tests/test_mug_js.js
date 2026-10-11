// =====================================================================
// test_mug_js.js — RUNS the 🎬 Mug Player's page code for real.
// =====================================================================
// Everything a person actually touches lives in the page's JavaScript:
// the drawing, the ✕, the row click, ↑↓ / ⏎ / ⌫ / space / ⌘1–9 / ⌘O,
// and the <video> element's own load/error/ended reporting — which is
// the whole door mechanism this release rests on. The Lua suite proves
// what PLAYS and what is KEPT; it can only grep for any of this.
//
//   lua5.4 dump_mug_html.lua ./modules /tmp/mug-rows.json > /tmp/mug.html
//   node test_mug_js.js /tmp/mug.html /tmp/mug-rows.json
//
// 🚚 AND THE PAYLOAD IS THE REAL ONE (6.203.0): the rows drawn here are
// `vid.rowsJson()`'s own output over a queue of names a film folder is
// really allowed to hold.

const fs = require("fs");
const vm = require("vm");
const htmlPath = process.argv[2] || "/tmp/mug.html";
const rowsPath = process.argv[3] || "/tmp/mug-rows.json";
const html = fs.readFileSync(htmlPath, "utf8");
const ROWS = fs.readFileSync(rowsPath, "utf8");

let pass = 0, fail = 0; const failures = [];
// 🧪 Every message is read through this: a mutation that stops one being
// posted must FAIL the check that wanted it, not throw on `undefined.a`
// and take every check after it with the run still saying "0 failed"
// (6.186.0).
const at = (env, n) => env.sent[n] || {};
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};

// 🔎 The payload is a JS OBJECT LITERAL, not strict JSON — rowsJson()
// writes unquoted keys, exactly as the Jug Player's does, because its
// only reader is `draw(...)` inside the page. So the suite evaluates it
// the way the page does rather than JSON.parse-ing it, and asserts it
// really is loadable: a payload the page cannot read is an empty card
// over a film that is still playing (6.231.1).
const rowsObj = () => vm.runInNewContext("(" + ROWS + ")");
check("the real rowsJson() payload is loadable by the page",
      (() => { try { return typeof rowsObj() === "object"; }
               catch (e) { return false; } })());

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

// ---- a DOM faithful enough to catch what matters ---------------------
// 🧪 The deck is rebuilt as an innerHTML string and then WALKED with
// querySelectorAll to fill each name with textContent — so a stub whose
// querySelectorAll answered nothing would let every name check pass
// over an empty walk. It parses the rows the page really wrote.
function makeEnv() {
  const sent = [];
  const listeners = { document: {}, el: {} };
  const texts = {};          // "k:i" → the textContent written into that row
  let scrolled = 0;

  const rowObjs = (deckHTML) => {
    const out = [];
    const re = /<div class="([^"]*)" data-k="([^"]*)" data-i="(\d+)">([\s\S]*?)<\/div>/g;
    let m;
    while ((m = re.exec(deckHTML)) !== null) {
      const cls = m[1], k = m[2], i = m[3];
      const row = {
        className: cls,
        getAttribute: (a) => (a === "data-k" ? k : a === "data-i" ? i : null),
        querySelector: (sel) => (sel === ".nm"
          ? { set textContent(v) { texts[k + ":" + i] = v; },
              get textContent() { return texts[k + ":" + i]; } }
          : null),
      };
      out.push(row);
    }
    return out;
  };

  const mk = (id) => {
    const node = {
      id, _html: "", textContent: "", className: "",
      style: {}, attrs: {}, loads: 0, paused: true, plays: 0, pauses: 0,
      get innerHTML() { return this._html; },
      set innerHTML(v) { this._html = v; },
      setAttribute(a, v) { this.attrs[a] = v; },
      getAttribute(a) { return a in this.attrs ? this.attrs[a] : null; },
      removeAttribute(a) { delete this.attrs[a]; },
      load() { this.loads++; },
      play() { this.plays++; this.paused = false; },
      pause() { this.pauses++; this.paused = true; },
      addEventListener: (ev, fn) => { listeners.el[id + ":" + ev] = fn; },
      querySelectorAll(sel) {
        return sel.indexOf("[data-k]") !== -1 ? rowObjs(this._html) : [];
      },
      querySelector(sel) {
        if (sel === ".row.on") {
          return this._html.indexOf('class="row on') !== -1
            ? { scrollIntoView: () => { scrolled++; } } : null;
        }
        return null;
      },
    };
    return node;
  };
  const byId = {};
  for (const id of ["head", "brand", "now", "stage", "v", "msg", "drop", "deck"]) {
    byId[id] = mk(id);
  }
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: (ev, fn) => { listeners.document[ev] = fn; },
    },
    webkit: { messageHandlers: { mugPlayer: { postMessage: (m) => sent.push(m) } } },
  };
  return { sandbox, sent, listeners, byId, texts, scrolledCount: () => scrolled,
           rowObjs };
}

function load() {
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "video_player-page.js" });
  // 🪟 What the page says AS IT LOADS is its own fact (6.238.0's 'ready'
  // handshake) and is kept apart, so every check below measures what an
  // INTERACTION sent.
  env.loadSent = env.sent.slice();
  env.sent.length = 0;
  env.call = (e) => vm.runInContext(e, ctx);
  env.draw = (json) => vm.runInContext("draw(" + json + ");", ctx);
  env.key = (k, o) => env.listeners.document.keydown(
    Object.assign({ key: k, metaKey: false, preventDefault() {} }, o || {}));
  env.deckClick = (target) =>
    (env.listeners.el["deck:click"] || (() => {}))({ target });
  env.headDown = (o) => (env.listeners.el["head:mousedown"] || (() => {}))(
    Object.assign({ button: 0, metaKey: false }, o || {}));
  env.video = (ev) => (env.listeners.el["v:" + ev] || (() => {}))({});
  return env;
}

// a click target that behaves like a real one: closest() walks up
const targetRow = (k, i, onX) => ({
  closest: (sel) => {
    if (sel === "[data-x]") return onX ? {} : null;
    if (sel === ".row[data-k]") {
      return { getAttribute: (a) => (a === "data-k" ? k : a === "data-i" ? String(i) : null) };
    }
    return null;
  },
});

console.log("── Mug Player: page JavaScript, executed ──");

// =====================================================================
// 1. the page announces itself LAST
// =====================================================================
{
  const env = load();
  // 6.238.0 — a push into a page WebKit has not parsed goes nowhere, so
  // the page says when it exists. Sent any earlier it promises something
  // that is not there yet, which is why it must be the LAST thing.
  check("the page says 'ready' as it loads",
        env.loadSent.some((m) => m.a === "ready"), JSON.stringify(env.loadSent));
  check("…and it is the LAST thing it says",
        env.loadSent[env.loadSent.length - 1].a === "ready");
}

// =====================================================================
// 2. the REAL payload, drawn — and the names that can break a page
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  const D = env.byId.deck.innerHTML;
  check("every queued film is drawn",
        (D.match(/class="row/g) || []).length >= 4,
        (D.match(/class="row/g) || []).length);
  // 🔤 THE ROWS THIS SUITE EXISTS FOR. Names go in with textContent, so
  // no name can become markup — and the check reads the text that was
  // actually written, not the HTML around it.
  const names = Object.values(env.texts);
  check("an ampersand in a film name survives as an ampersand",
        names.some((n) => n === "Simon & Garfunkel"), JSON.stringify(names));
  check("angle brackets and a quote are TEXT, never markup",
        names.some((n) => n === '<Live> at the "Apollo"')
        && D.indexOf("<Live>") === -1, D.slice(0, 160));
  check("an apostrophe, a percent and a hash all survive",
        names.some((n) => n === "Don't Look Up 50% #2"), JSON.stringify(names));
  check("the history row is drawn too, with its own name",
        names.some((n) => n === "Old & Grey"));
  check("…and a history row carries a ✕", D.indexOf('data-x="1"') !== -1);
  check("a queue row does NOT carry a ✕ — ⌫ is its only removal",
        (D.match(/data-x="1"/g) || []).length === 1,
        (D.match(/data-x="1"/g) || []).length);
  check("the header names the brand and the film",
        env.byId.brand.textContent === "Mug Player"
        && env.byId.now.textContent.length > 0,
        env.byId.brand.textContent + " | " + env.byId.now.textContent);
  check("the highlighted row is scrolled into view", env.scrolledCount() >= 1);
}

// =====================================================================
// 3. the <video> src — the door mechanism, from the page's side
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  const v = env.byId.v;
  check("the film's src was set from the payload", (v.src || "").length > 0, v.src);
  check("…and it was load()ed", v.loads >= 1, v.loads);
  const loadsBefore = v.loads;
  // 🚨 A REDRAW THAT CHANGES NOTHING MUST NOT RESTART THE FILM. Setting
  // src unconditionally would reload it on every cursor move, which is
  // the film jumping back to 0:00 whenever he presses ↓.
  env.draw(ROWS);
  check("🚨 a redraw with the SAME src does not reload the film",
        v.loads === loadsBefore, v.loads + " vs " + loadsBefore);
  // and a new film does
  const other = rowsObj();
  other.src = "file:///F/Another.mp4";
  env.draw(JSON.stringify(other));
  check("…but a NEW src does reload", v.loads === loadsBefore + 1);
}
{
  const env = load();
  env.draw(ROWS);
  env.sent.length = 0;
  env.video("loadeddata");
  check("a film that loads reports WHICH door carried it",
        at(env, 0).a === "srcok" && typeof at(env, 0).d === "number",
        JSON.stringify(env.sent));
  check("…and it carries the generation, so a late answer can be refused",
        typeof at(env, 0).gen === "number");
  env.sent.length = 0;
  env.video("error");
  check("a film that fails reports the door that failed",
        at(env, 0).a === "srcfail" && typeof at(env, 0).d === "number");
  env.sent.length = 0;
  env.video("ended");
  check("a film that ends says so, with its generation",
        at(env, 0).a === "ended" && typeof at(env, 0).gen === "number");
}
{
  const env = load();
  // an empty payload must not leave a stale film on the stage
  env.draw('{q:[],h:[],ix:0,sl:"queue",sr:1,src:"",how:"",door:1,gen:0,name:"",brand:"Mug Player"}');
  check("with nothing queued the deck says what to do",
        env.byId.deck.innerHTML.indexOf("drop .mp4 films") !== -1);
  check("…and the header says nothing is playing",
        env.byId.now.textContent === "nothing playing", env.byId.now.textContent);
}

// =====================================================================
// 4. the deck's clicks — and the ✕ rule
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  env.sent.length = 0;
  env.deckClick(targetRow("q", 2, false));
  check("a click on a queue row plays it",
        at(env, 0).a === "play" && at(env, 0).k === "q" && at(env, 0).i === 2,
        JSON.stringify(env.sent));
  env.sent.length = 0;
  // 🚨 6.272.0 — THE ✕ IS ASKED BEFORE THE ROW IT SITS INSIDE. The two
  // share one handler, so testing the row first PLAYS the film on its
  // way to forgetting it. The check asserts exactly ONE message, and
  // that it is the forget.
  env.deckClick(targetRow("h", 1, true));
  check("🚨 the ✕ FORGETS and does not play — exactly one message",
        env.sent.length === 1 && at(env, 0).a === "forget",
        JSON.stringify(env.sent));
  env.sent.length = 0;
  env.deckClick({ closest: () => null });
  check("a click on empty deck space does nothing at all",
        env.sent.length === 0, JSON.stringify(env.sent));
}

// =====================================================================
// 5. the keyboard
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  env.sent.length = 0;
  env.key("ArrowDown");
  check("↓ walks the cursor", at(env, 0).a === "sel" && at(env, 0).d === 1);
  env.sent.length = 0;
  env.key("ArrowUp");
  check("↑ walks it back", at(env, 0).a === "sel" && at(env, 0).d === -1);
  env.sent.length = 0;
  env.key("Enter");
  check("⏎ plays the highlighted row", at(env, 0).a === "enter");
  env.sent.length = 0;
  env.key("Backspace");
  check("⌫ removes it", at(env, 0).a === "drop");
  env.sent.length = 0;
  env.key("3", { metaKey: true });
  check("⌘3 plays the third film",
        at(env, 0).a === "play" && at(env, 0).k === "q" && at(env, 0).i === 3);
  env.sent.length = 0;
  env.key("o", { metaKey: true });
  check("⌘O asks for the film to be opened outside",
        at(env, 0).a === "external");
  // space is OURS everywhere in the window, so it works whether the
  // keyboard is on the deck or on the film.
  env.sent.length = 0;
  const v = env.byId.v;
  v.paused = true;
  env.key(" ");
  check("space plays a paused film", v.plays === 1 && env.sent.length === 0);
  env.key(" ");
  check("…and pauses a playing one", v.pauses === 1);
  // 🚨 ← and → are the FILM's own keys: WebKit seeks with them and ⇧
  // seeks further. The page must not swallow them, or the native
  // controls this release exists to keep lose half their behaviour.
  env.sent.length = 0;
  let prevented = false;
  env.listeners.document.keydown({ key: "ArrowRight", metaKey: false,
                                   preventDefault() { prevented = true; } });
  check("🚨 ← → are left to the film — the page does not swallow them",
        prevented === false && env.sent.length === 0);
  // a modifier that is not ⌘ must not be read as a bare key
  env.sent.length = 0;
  env.key("ArrowDown", { metaKey: true });
  check("⌘↓ is not our ↓", env.sent.length === 0, JSON.stringify(env.sent));
}

// =====================================================================
// 6. the grips and the drop veil
// =====================================================================
{
  const env = load();
  env.sent.length = 0;
  env.headDown();
  check("a bare press on the title strip begins a window drag",
        at(env, 0).a === "dragStart");
  env.sent.length = 0;
  // ⌘-drag belongs to window_move's own tap, which CONSUMES the click —
  // so the page must not also claim it (6.221.0).
  env.headDown({ metaKey: true });
  check("⌘-press on the strip is NOT ours — window_move owns that click",
        env.sent.length === 0, JSON.stringify(env.sent));
  env.sent.length = 0;
  env.headDown({ button: 2 });
  check("a right-click on the strip does not drag the window",
        env.sent.length === 0);
  env.call("dropShow(true)");
  check("the drop veil can be shown", env.byId.drop.style.display === "flex");
  env.call("dropShow(false)");
  check("…and hidden again", env.byId.drop.style.display === "none");
}

// =====================================================================
// 7. the failure message
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  env.call('fail("every way in was refused")');
  check("a failure message is shown over the stage",
        env.byId.msg.style.display === "flex"
        && env.byId.msg.textContent.indexOf("refused") !== -1);
  // 🚨 AND THE FILM IS HIDDEN BEHIND IT, or he reads an error over a
  // black rectangle that still looks like a player.
  check("…and the empty <video> is hidden behind it",
        env.byId.v.style.visibility === "hidden");
  // A later film that DOES load must clear it, or the message outlives
  // the failure it describes.
  const other = rowsObj();
  other.src = "file:///F/Works.mp4";
  env.draw(JSON.stringify(other));
  check("a film that loads afterwards clears the message",
        env.byId.msg.style.display === "none"
        && env.byId.v.style.visibility === "visible");
}

// ── the payload reaches the glass ─────────────────────────────────────
// 🚨 THE CHECK 6.344.0 DID NOT HAVE, and it is drawn from HIS screenshot
// rather than from a theory: the deck showed "1" and "2" with no names,
// the header read "nothing playing" over a queued film, the brand was
// missing and the stage was a black rectangle. Every one of those is a
// string that arrived EMPTY. The page was innocent; the payload was not
// — so the page suite now asserts that what it draws is not blank.
{
  const env = load();
  const want = rowsObj();
  check("the deck draws the film's NAME, not just its row number",
        env.texts["q:1"] === want.q[0].t && (env.texts["q:1"] || "").length > 0,
        JSON.stringify(env.texts["q:1"]));
  check("every queue row has a name",
        want.q.every((r, n) => (env.texts["q:" + (n + 1)] || "").length > 0));
  check("every history row has a name",
        want.h.every((r, n) => (env.texts["h:" + (n + 1)] || "").length > 0));
  check("the header names the film, never 'nothing playing'",
        env.byId.now.textContent === want.name
        && env.byId.now.textContent !== "nothing playing");
  check("the brand is drawn", env.byId.brand.textContent === want.brand
        && env.byId.brand.textContent.length > 0);
  // The black rectangle itself: a <video> with no source.
  check("the <video> is GIVEN a source", (env.byId.v.src || "").length > 0,
        String(env.byId.v.src));
  check("…and it was asked to load it", env.byId.v.loads > 0);
}

// ── ⎋ closes the window, and WebKit keeps it in full screen ───────────
{
  const env = load();
  env.key("Escape");
  check("Escape asks Lua to close the window",
        at(env, 0).a === "close", JSON.stringify(env.sent));
  check("…and it is the only thing that press sent", env.sent.length === 1);
}
{
  // 🪟 A FILM IN FULL SCREEN OWNS ESC. Taking it here would leave him
  // inside a full-screen film with no way out — a native control this
  // tool promised and must not quietly remove (6.318.0).
  const env = load();
  env.sandbox.document.fullscreenElement = { tag: "video" };
  env.key("Escape");
  check("Escape in full screen is WebKit's, and the page sends nothing",
        env.sent.length === 0, JSON.stringify(env.sent));
}

console.log(`── test_mug_js: ${pass} passed, ${fail} failed`);
for (const f of failures) console.log("   ❌ " + f);
process.exit(fail === 0 ? 0 : 1);
