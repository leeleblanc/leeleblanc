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
  const timeouts = [];       // 6.370.0: the deferred full-screen probe
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
      // 🔬 6.354.0 — `src` IS REFLECTED, as a real DOM reflects it. The
      // page sets the stage with `v.src = …` (a property) and clears it
      // with removeAttribute('src'); a stub that kept those in two
      // different places would answer null for a video that is playing,
      // which puts the whole bytes door out of the gate's reach.
      get src() { return this.attrs.src === undefined ? "" : this.attrs.src; },
      set src(v) { this.attrs.src = String(v); },
      setAttribute(a, v) { this.attrs[a] = v; },
      getAttribute(a) { return a in this.attrs ? this.attrs[a] : null; },
      removeAttribute(a) { delete this.attrs[a]; },
      // 🔬 6.365.0 — currentTime IS A SETTER, not just a getter. 6.239.0
      // learned this the expensive way on the Jug Player: a getter-only
      // stub lets every seek "succeed" while moving nothing, so the whole
      // feature is invisible to the gate (and it was the THIRD time a
      // getter-only stub had hidden one). `duration` defaults to 0 — the
      // honest state of a film macOS has not measured yet — so the branch
      // that refuses a FORWARD seek is the default rather than the
      // exception, and a test has to opt INTO a known length.
      _ct: 0, _seeks: 0, duration: 0,
      get currentTime() { return this._ct; },
      set currentTime(v) { this._ct = Number(v); this._seeks++; },
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
  // 📦 6.354.0 — THE BLOB STORE, MODELLED RATHER THAN WAVED AT. The
  // bytes door's whole claim is that the film that reaches the window is
  // the film on the disk, in order — so the stub has to KEEP the bytes,
  // in order, or the check that proves it is a check about nothing
  // (6.290.0). A vm context gets V8's built-ins but none of Node's
  // globals, so atob, Blob and URL have to be here at all.
  const blobs = [];
  const urls  = {};
  let urlSeq  = 0;
  const bytesOf = (part) => {
    if (part && part.__blob) return part.bytes;
    if (part instanceof Uint8Array) return Array.from(part);
    if (typeof part === "string") {
      return Array.from(part, (c) => c.charCodeAt(0) & 255);
    }
    return [];
  };
  function Blob(parts, opts) {
    const bytes = [];
    for (const p of (parts || [])) bytes.push(...bytesOf(p));
    this.__blob = true;
    this.bytes = bytes;
    this.size = bytes.length;
    this.type = (opts && opts.type) || "";
    blobs.push(this);
  }
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      addEventListener: (ev, fn) => { listeners.document[ev] = fn; },
      // 🔬 6.290.0 — A REAL DOCUMENT ALWAYS HAS A BODY, and 6.370.0's
      // cinema mode reads its className. A harness without one is
      // gentler than WebKit and the whole mode is unreachable from the
      // gate, which is how a stub comes to certify a bug.
      body: { className: "" },
      fullscreenElement: null,
      webkitFullscreenElement: null,
      exitFullscreen() { this.fullscreenElement = null; },
    },
    // the older webkit full-screen form answers nothing, so the page
    // asks a beat later whether it took — the beat is collected rather
    // than slept through.
    setTimeout: (fn, ms) => { timeouts.push({ fn, ms }); return timeouts.length; },
    Date,
    webkit: { messageHandlers: { mugPlayer: { postMessage: (m) => sent.push(m) } } },
    Uint8Array,
    Blob,
    // 🔬 a real decode: a stub that answered the input unchanged would
    // make a scrambled film unreachable from the gate.
    atob: (b64) => {
      const buf = Buffer.from(String(b64), "base64");
      if (buf.toString("base64").replace(/=+$/, "")
          !== String(b64).replace(/=+$/, "")) {
        throw new Error("InvalidCharacterError");
      }
      let o = "";
      for (const b of buf) o += String.fromCharCode(b);
      return o;
    },
    URL: {
      createObjectURL: (b) => {
        urlSeq += 1;
        const u = "blob:mug/" + urlSeq;
        urls[u] = b;
        return u;
      },
      revokeObjectURL: (u) => { delete urls[u]; },
    },
  };
  return { sandbox, sent, listeners, byId, texts, scrolledCount: () => scrolled,
           rowObjs, blobs, urls, liveURLs: () => Object.keys(urls),
           timeouts, fireTimeouts: () => { const t = timeouts.splice(0);
                                           t.forEach((x) => x.fn()); return t.length; } };
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
  // 🚚 The window's own drop door (6.352.0). `prevented` is the fact that
  // decides everything: preventDefault() is what makes this window ACCEPT
  // a drag, and accepting it takes the drag away from the canvas catcher
  // underneath — so a handler that claims without reading is worse than
  // no handler at all.
  env.drag = (name, o) => {
    const ev = Object.assign(
      { target: env.sandbox.document, relatedTarget: null,
        prevented: false, preventDefault() { this.prevented = true; } },
      o || {});
    const fn = env.listeners.document[name];
    if (fn) fn(ev);
    return ev;
  };
  env.fileDrop = (uri, names) => env.drag("drop", {
    dataTransfer: {
      getData: (t) => (t === "text/uri-list" ? (uri || "") : ""),
      files: (names || []).map((n) => ({ name: n })),
    },
  });
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
  // 🚨 THIS CHECK ASSERTED THE OPPOSITE UNTIL 6.365.0, and it was green
  // the whole time the feature was missing: "← → are left to the film —
  // the page does not swallow them". That was TRUE and the belief under
  // it was wrong. WebKit seeks with those keys only while the <video>
  // ELEMENT has keyboard focus, and in this window the DOCUMENT has it —
  // which is how space and ↑↓ work at all. So the arrows reached nothing,
  // and the only way to skip was the mouse. The page claims them now, and
  // prevents the default so a focused film cannot seek a SECOND time on
  // the same press.
  env.sent.length = 0;
  const vv = env.byId.v;
  vv.duration = 600; vv._ct = 100; vv._seeks = 0;
  let prevented = false;
  env.listeners.document.keydown({ key: "ArrowRight", metaKey: false,
                                   preventDefault() { prevented = true; } });
  check("⏪ → seeks FORWARD by the config's step", vv.currentTime === 115,
        vv.currentTime);
  check("🚨 …and prevents the default, so a focused film cannot seek twice",
        prevented === true);
  check("…and tells Lua, so the report can count it",
        env.sent.length === 1 && at(env, 0).a === "seek", JSON.stringify(env.sent));
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

// =====================================================================
// 9. THE WINDOW'S OWN DROP (6.352.0) — the door this page never had
// =====================================================================
// 🚚 The Jug Player has had both doors since 6.233.0 — the canvas catcher
// underneath AND the page's own handler — and this page was built with
// only the catcher. A canvas macOS refuses to put on screen then costs
// the whole feature, which is "I can't drag and drop a file on it".
{
  const env = load();
  check("the page registers its own dragover/dragleave/drop handlers",
        !!env.listeners.document.dragover && !!env.listeners.document.dragleave
        && !!env.listeners.document.drop);

  env.sent.length = 0;
  const over = env.drag("dragover");
  check("dragover CLAIMS the drag, or this window is skipped by it",
        over.prevented === true);
  check("…and the veil is shown while it is over the window",
        env.byId.drop.style.display === "flex");
  env.drag("dragleave");
  check("dragleave hides the veil", env.byId.drop.style.display === "none");

  env.sent.length = 0;
  const ev = env.fileDrop(
    "file:///F/Simon%20%26%20Garfunkel.mp4\nfile:///F/Two.mp4\n",
    ["Simon & Garfunkel.mp4", "Two.mp4"]);
  check("a drop claims the event", ev.prevented === true);
  check("…and hides the veil", env.byId.drop.style.display === "none");
  // 🚨 THE CHECK THAT MATTERS MOST. In THIS page 'drop' is the ⌫ key,
  // which REMOVES a film from the queue — so naming the file drop 'drop'
  // would make dropping films onto the window DELETE one instead. The
  // name is the whole safety of it (6.272.0's ✕-before-the-row, in a
  // message name).
  check("the file drop is sent as 'filedrop', NEVER as 'drop'",
        at(env, 0).a === "filedrop", JSON.stringify(env.sent));
  check("…and it carries the drag's text/uri-list verbatim",
        (at(env, 0).uri || "").indexOf("file:///F/Simon%20%26%20Garfunkel.mp4") === 0,
        JSON.stringify(at(env, 0).uri));
  check("…and exactly one message was sent", env.sent.length === 1);
}
{
  // 🔎 A DROP WITH NO uri-list IS NAMED, NEVER SWALLOWED (6.231.0):
  // dataTransfer.files hands a page NAMES only — never a path — so the
  // names are what the message can honestly report, and Lua says so.
  const env = load();
  env.sent.length = 0;
  env.fileDrop("", ["Robin Hood.mp4"]);
  check("a drop with no file URLs still reports what it saw",
        at(env, 0).a === "filedrop" && at(env, 0).uri === ""
        && (at(env, 0).names || [])[0] === "Robin Hood.mp4",
        JSON.stringify(env.sent));
}
{
  // 🚨 THE FIXTURE THAT BITES, and it is the only input where claiming
  // and standing down must differ (6.230.0). With no uri-list reader in
  // Lua the page MUST NOT claim the drag: an unconditional
  // preventDefault() would take every drop away from the catcher
  // underneath and then do nothing with it — strictly worse than the one
  // door this release is fixing. `pd` is read at EVENT time, so the
  // suite moves it the way a Mac without the Jug Player would.
  const env = load();
  env.call("S.pd=false;");
  env.sent.length = 0;
  const over = env.drag("dragover");
  check("with no reader, dragover does NOT claim the drag",
        over.prevented === false);
  const ev = env.fileDrop("file:///F/One.mp4\n", ["One.mp4"]);
  check("…and the drop is left to the catcher underneath",
        ev.prevented === false);
  check("…and the page sends nothing at all",
        env.sent.length === 0, JSON.stringify(env.sent));
}

// =====================================================================
// 10. THE BYTES THROUGH THE WINDOW (6.354.0)
// =====================================================================
// Both file:// doors are refused on his Mac, so the third one carries no
// URL at all: Lua reads the film in chunks and pushes them here. These
// checks prove the one thing that claim rests on — the film that reaches
// the window is the film on the disk, in order.
{
  const env = load();
  const FILM = "ABCDEFGHIJ";          // ten distinguishable bytes
  const b64 = (s) => Buffer.from(s, "binary").toString("base64");
  env.call("blobStart(" + FILM.length + ",7);");
  check("blobStart says what is happening, with a percentage",
        env.byId.msg.textContent.indexOf("reading the film") !== -1
        && env.byId.msg.style.display === "flex",
        env.byId.msg.textContent);
  check("…and it clears whatever the stage was showing first",
        env.byId.v.getAttribute("src") === null
        && env.byId.v.getAttribute("data-src") === null);

  // three chunks, in order, as Lua pushes them
  env.call("blobChunk('" + b64("ABCD") + "');");
  check("the progress line climbs with the bytes",
        env.byId.msg.textContent.indexOf("40%") !== -1,
        env.byId.msg.textContent);
  env.call("blobChunk('" + b64("EFGH") + "');");
  env.call("blobChunk('" + b64("IJ") + "');");
  check("nothing is posted back while a read is going well",
        env.sent.length === 0, JSON.stringify(env.sent));

  env.call("blobEnd();");
  const src = env.byId.v.getAttribute("src");
  check("blobEnd puts an object URL on the video", /^blob:/.test(String(src)),
        String(src));
  check("…and the stage stops saying it is reading",
        env.byId.msg.style.display === "none");
  check("…and it plays without being asked twice",
        env.byId.v.plays === 1 && env.byId.v.loads > 0,
        env.byId.v.plays + "/" + env.byId.v.loads);
  // 📦 THE CHECK THE WHOLE DOOR RESTS ON.
  const got = env.urls[src];
  const text = got ? got.bytes.map((b) => String.fromCharCode(b)).join("") : "";
  check("EVERY BYTE IS THERE, IN ORDER, as the film on the disk",
        text === FILM, text);
  check("…and the Blob is typed as a film, or WebKit will not play it",
        got && got.type === "video/mp4", got && got.type);

  // 🚨 THE GUARD THIS RELEASE NEEDED MOST: door 3 carries no `src`, so
  // every redraw after the film is playing would have torn it down —
  // a selection move, a new history row, anything.
  env.draw(ROWS.replace(/src:"[^"]*"/, 'src:""'));
  check("a redraw does NOT tear the playing film down",
        env.byId.v.getAttribute("src") === src,
        String(env.byId.v.getAttribute("src")));
  check("…and the object URL is still live",
        env.liveURLs().indexOf(src) !== -1);

  // 📦 …but a URL door taking over DOES drop it, or the old film plays
  // on under the new one and an object URL leaks.
  env.draw(ROWS.replace(/src:"[^"]*"/, 'src:"file:///F/next.mp4"'));
  check("a URL door taking over revokes the object URL",
        env.liveURLs().indexOf(src) === -1, env.liveURLs().join(","));
  check("…and the stage is showing the new film",
        env.byId.v.getAttribute("src") === "file:///F/next.mp4");
}

// ---- a chunk that cannot be decoded -----------------------------------
{
  const env = load();
  env.call("blobStart(10,7);");
  env.call("blobChunk('!!! not base64 !!!');");
  check("a chunk the window cannot decode is REPORTED, not swallowed",
        env.sent.some((m) => m.a === "blobfail"), JSON.stringify(env.sent));
  check("…carrying the page's own words, so Lua can say what happened",
        (env.sent.find((m) => m.a === "blobfail") || {}).why !== undefined);
  check("…and the generation, so a late one cannot speak for this film",
        (env.sent.find((m) => m.a === "blobfail") || {}).gen === 7);
  // and the half-read is abandoned rather than finished with a hole in it
  env.sent.length = 0;
  env.call("blobEnd();");
  check("…and blobEnd after a failed chunk assembles NOTHING",
        /^blob:/.test(String(env.byId.v.getAttribute("src"))) === false,
        String(env.byId.v.getAttribute("src")));
}

// ---- a push with no read in flight ------------------------------------
{
  const env = load();
  env.call("blobChunk('QUJD');");
  env.call("blobEnd();");
  // the page has already drawn the payload's own src by now, so the fact
  // that bites is that NO BLOB appeared — not that the stage is empty.
  check("a chunk with no read in flight is ignored, and nothing throws",
        env.sent.length === 0
        && /^blob:/.test(String(env.byId.v.getAttribute("src"))) === false
        && env.liveURLs().length === 0,
        JSON.stringify(env.sent) + " " + env.byId.v.getAttribute("src"));
}

// ---- a second film, read while the first is playing -------------------
{
  const env = load();
  const b64 = (s) => Buffer.from(s, "binary").toString("base64");
  env.call("blobStart(3,1);");
  env.call("blobChunk('" + b64("AAA") + "');");
  env.call("blobEnd();");
  const first = env.byId.v.getAttribute("src");
  env.call("blobStart(3,2);");
  check("starting a second read revokes the first film's URL",
        env.liveURLs().indexOf(first) === -1, env.liveURLs().join(","));
  check("…and clears the stage rather than leaving the old film up",
        env.byId.v.getAttribute("src") === null);
  env.call("blobChunk('" + b64("BBB") + "');");
  env.call("blobEnd();");
  const second = env.byId.v.getAttribute("src");
  const got = env.urls[second];
  check("…and the second film is the second film",
        got && got.bytes.map((b) => String.fromCharCode(b)).join("") === "BBB",
        got && got.bytes.join(","));
}

// =====================================================================
// ⏪ ← → SEEK — 6.365.0
// =====================================================================
// LL: "instead of having to mouse over the window and then press the 15
// second forward button and then 15 second back button."
{
  const env = load();
  const v = env.byId.v;
  const press = (key, o) => {
    env.sent.length = 0;
    env.listeners.document.keydown(Object.assign(
      { key, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false,
        preventDefault() {} }, o || {}));
  };

  v.duration = 600; v._ct = 300;
  press("ArrowLeft");
  check("⏪ ← seeks BACK by the step", v.currentTime === 285, v.currentTime);
  press("ArrowRight", { shiftKey: true });
  check("⏪ ⇧→ uses the BIG step", v.currentTime === 345, v.currentTime);
  press("ArrowLeft", { shiftKey: true });
  check("⏪ ⇧← does too", v.currentTime === 285, v.currentTime);

  // 📐 THE NUMBERS COME FROM THE PAYLOAD, not from the page. Moving S
  // and requiring the key to follow is what proves it — asserting the
  // shipped 15 passes happily with the value typed in twice (6.239.0).
  env.call("S.sk=7");
  v._ct = 100;
  press("ArrowRight");
  check("📐 the step is read from the payload, so moving the config moves the key",
        v.currentTime === 107, v.currentTime);
  env.call("S.sk=15");

  // 🚨 NEVER PAST EITHER END.
  v._ct = 5;
  press("ArrowLeft");
  check("🚨 ← at the start parks at 0, never below it", v.currentTime === 0,
        v.currentTime);
  v._ct = 595;
  press("ArrowRight");
  check("🚨 → at the end parks at the end, never past it", v.currentTime === 600,
        v.currentTime);

  // 🚨 THE FIXTURE THAT BITES, and it is the whole reason the door
  // answers WHY (6.239.0): a duration of 0 means macOS has NOT measured
  // the film, not that it is zero seconds long. Seeking FORWARD into a
  // length nobody knows lands in silence with no way back — so ← must
  // still work there and → must not. Every other input agrees.
  v.duration = 0; v._ct = 40; v._seeks = 0;
  press("ArrowRight");
  check("🚨 → is REFUSED on a film with no length yet, and nothing moves",
        v._seeks === 0 && v.currentTime === 40, v.currentTime + "/" + v._seeks);
  check("…and it SAYS why rather than doing nothing",
        env.sent.length === 1 && at(env, 0).ok === false
        && String(at(env, 0).why).indexOf("no length yet") !== -1,
        JSON.stringify(env.sent));
  press("ArrowLeft");
  check("🚨 …but ← still works there — back is always safe",
        v.currentTime === 25 && at(env, 0).ok === true, v.currentTime);

  // NaN is the other face of the same state, and a plain `dur <= 0`
  // test reads it as a number (NaN <= 0 is false), so it has its own row.
  v.duration = NaN; v._ct = 40; v._seeks = 0;
  press("ArrowRight");
  check("🚨 a duration of NaN is treated as unmeasured too, not as a number",
        v._seeks === 0 && env.sent.length === 1 && at(env, 0).ok === false,
        JSON.stringify(env.sent));

  // 🚨 AND Infinity IS THE THIRD FACE OF "unmeasured", which the sweep
  // had to ask for (6.273.0: the line `isFinite(dur) && dur > 0` could
  // not be killed by any other input, so the finding was the missing
  // CHECK). A plain `dur > 0` test reads NaN correctly by luck and reads
  // Infinity as a perfectly good LENGTH — and this module plays a BLOB
  // (6.354.0), which is exactly the source that reports Infinity while
  // the bytes are still being assembled. Seeking into it would clamp
  // against infinity, which clamps nothing.
  v.duration = Infinity; v._ct = 40; v._seeks = 0;
  press("ArrowRight");
  check("🚨 a duration of Infinity is unmeasured too — a blob says that while it loads",
        v._seeks === 0 && env.sent.length === 1 && at(env, 0).ok === false,
        JSON.stringify(env.sent));
  press("ArrowLeft");
  check("…and ← still works there, as it does for NaN and 0",
        v.currentTime === 25, v.currentTime);

  // the message carries what the report prints
  v.duration = 600; v._ct = 100;
  press("ArrowRight");
  const m = at(env, 0);
  check("⏪ the seek message carries where it landed and the length",
        m.at === 115 && m.dur === 600, JSON.stringify(m));

  // ⌘→ belongs to the app, not to us
  v._ct = 100;
  press("ArrowRight", { metaKey: true });
  check("⌘→ is not our →", v.currentTime === 100 && env.sent.length === 0,
        v.currentTime);
}

// =====================================================================
// 🎬 6.370.0 — ⌃⌘F ASKS THE FILM, AND THE CHROME FADES
// =====================================================================
// LL: "Mug player should fade out of sight the window borders and the
// playlist when in fullscreen mode. … ⌃⌘F is to make the FILM full
// screen." Whether a WKWebView will ALLOW element full screen is not
// knowable from Lua — hs.webview never sets the WKPreferences key and
// the macOS default is off — so the page ASKS and reports which
// happened. New ground gets a probe, never a fix built on a belief
// (6.233.0).
{
  // 🔬 A SYNCHRONOUS THENABLE, deliberately: the branch under test is
  // `pr && pr.then`, and driving it with a real promise would make the
  // whole section async for no gain in what it proves.
  const thenable = (ok) => ({
    then(f) { if (ok) f(); return { catch(g) { if (!ok) g(new Error("refused")); } }; },
  });

  let env = load();
  let asked = 0;
  env.byId.v.requestFullscreen = () => { asked += 1; return thenable(true); };
  env.key("f", { metaKey: true, ctrlKey: true });
  check("🖥 ⌃⌘F asks the FILM for full screen, not the window", asked === 1, asked);
  check("…and a WebKit that TAKES it is reported as 'film'",
        env.sent.some((m) => m.a === "fill" && m.mode === "film"),
        JSON.stringify(env.sent));
  check("…and nothing asks Lua to resize the window underneath it",
        !env.sent.some((m) => m.a === "fill" && m.mode === "window"));

  // 🚨 THE FIXTURE THAT MATTERS, because it is the one his Mac is most
  // likely to be: WebKit refuses, and the window must fill instead.
  env = load();
  env.byId.v.requestFullscreen = () => thenable(false);
  env.key("f", { metaKey: true, ctrlKey: true });
  const ref = env.sent.find((m) => m.a === "fill");
  check("🚨 a WebKit that REFUSES falls back to filling the window",
        ref && ref.mode === "window", JSON.stringify(env.sent));
  check("…and says WHY, so the report can name it rather than guess",
        ref && typeof ref.why === "string" && ref.why.length > 5, ref && ref.why);

  // a WebKit with no element full screen at all
  env = load();
  delete env.byId.v.requestFullscreen;
  env.key("f", { metaKey: true, ctrlKey: true });
  const none = env.sent.find((m) => m.a === "fill");
  check("a WebKit with no element full screen at all says so and fills",
        none && none.mode === "window"
        && /no element full screen/.test(none.why || ""), JSON.stringify(none));

  // the older form answers NOTHING, so the page asks a beat later
  env = load();
  env.byId.v.requestFullscreen = () => undefined;
  env.key("f", { metaKey: true, ctrlKey: true });
  check("the older webkit form is not guessed about on the spot",
        env.sent.length === 0 && env.timeouts.length === 1, env.sent.length);
  env.sandbox.document.fullscreenElement = env.byId.v;
  env.fireTimeouts();
  check("…and once the beat has passed it reports what really happened",
        env.sent.some((m) => m.a === "fill" && m.mode === "film"),
        JSON.stringify(env.sent));

  // and out again
  env = load();
  env.sandbox.document.fullscreenElement = env.byId.v;
  env.key("f", { metaKey: true, ctrlKey: true });
  check("⌃⌘F while the film IS full screen takes it back out",
        env.sent.some((m) => m.a === "fill" && m.mode === "film-out"),
        JSON.stringify(env.sent));

  // 🎬 CINEMA — Lua owns the flag and pushes it; the page reflects it
  env = load();
  env.call("cinema(true);");
  check("🎬 cinema fades the chrome by a class on the body",
        env.sandbox.document.body.className === "cinema",
        env.sandbox.document.body.className);
  // 🚨 ESC LEAVES THE MODE BEFORE IT CLOSES THE WINDOW. A mode you can
  // only leave with the key that put you in is a mode you can get stuck
  // in, and Esc closing the window from inside it loses the film.
  env.key("Escape");
  const esc = env.sent.find((m) => m.a === "fill" || m.a === "close");
  check("🚨 Esc in cinema leaves the MODE, it does not close the window",
        esc && esc.a === "fill", JSON.stringify(env.sent));
  env.call("cinema(false);");
  env.sent.length = 0;
  env.key("Escape");
  check("…and out of cinema Esc closes the window as it always did",
        env.sent.some((m) => m.a === "close"), JSON.stringify(env.sent));
  // and while the FILM is full screen WebKit keeps Esc (6.318.0)
  env.sandbox.document.fullscreenElement = env.byId.v;
  env.sent.length = 0;
  env.key("Escape");
  check("…and WebKit still owns Esc while the film is full screen",
        env.sent.length === 0, JSON.stringify(env.sent));
}

// =====================================================================
// ⏮ 6.370.0 — WHERE HE LEFT IT
// =====================================================================
// LL: "When I hide it and bring it back it reloads and doesn't remember
// the Time, place or position the movie was at when it was playing — I
// have jump and find place the last place it was playing at."
{
  let env = load();
  const v = env.byId.v;

  // 📍 the position is reported, and THROTTLED: timeupdate fires about
  // four times a second and each message is a hop onto the main thread.
  v.duration = 3600; v._ct = 120;
  env.video("timeupdate");
  const first = env.sent.filter((m) => m.a === "at");
  check("📍 the page reports where the film is", first.length === 1,
        JSON.stringify(env.sent));
  check("…with the length beside it, which the resume decision needs",
        first[0].t === 120 && first[0].dur === 3600, JSON.stringify(first[0]));
  v._ct = 121;
  env.video("timeupdate");
  check("📍 …and a second one a moment later is THROTTLED, not sent",
        env.sent.filter((m) => m.a === "at").length === 1,
        JSON.stringify(env.sent));
  // …but a PAUSE always reports, because that is the place he stopped at
  v._ct = 200;
  env.video("pause");
  const atP = env.sent.filter((m) => m.a === "at");
  check("📍 a PAUSE reports at once — that is the place he stopped at",
        atP.length === 2 && atP[1].t === 200, JSON.stringify(atP));

  // ⏮ the duration is its own message, because a blob says Infinity
  // while it is still assembling (6.365.0) and Lua cannot decide on it
  env = load();
  env.byId.v.duration = Infinity;
  env.video("durationchange");
  check("⏮ an Infinity duration is NOT reported — nothing can be decided on it",
        !env.sent.some((m) => m.a === "dur"), JSON.stringify(env.sent));
  env.byId.v.duration = 6486;
  env.video("durationchange");
  const dm = env.sent.find((m) => m.a === "dur");
  check("⏮ …and once it is a real number it is", dm && dm.d === 6486,
        JSON.stringify(env.sent));

  // and Lua pushes the place back
  env = load();
  env.byId.v.duration = 6486;
  env.call("resumeTo(2537);");
  check("⏮ resumeTo moves the film to where he left it",
        env.byId.v.currentTime === 2537, env.byId.v.currentTime);
  check("…and refuses a place that is not a number, rather than throwing",
        env.call("resumeTo('later');") === false
        && env.byId.v.currentTime === 2537, env.byId.v.currentTime);
}

console.log(`── test_mug_js: ${pass} passed, ${fail} failed`);
for (const f of failures) console.log("   ❌ " + f);
process.exit(fail === 0 ? 0 : 1);
