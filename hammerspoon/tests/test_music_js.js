// =====================================================================
// test_music_js.js — RUNS the 🎵 Music Player's page code for real.
// =====================================================================
// Everything a person actually touches on that card lives in the page's
// JavaScript: the drawing, the drop, ↑↓ / ⏎ / space / ⌘1–9, and the ⇪
// handshake. The Lua suite (93 checks) proves what PLAYS; it can only
// grep for any of this. So this loads the real generated page
// (dump_music_html.lua), gives it a stub DOM, and drives the actual
// handlers.
//
//   lua5.4 dump_music_html.lua ./modules /tmp/music-rows.json > /tmp/music.html
//   node test_music_js.js /tmp/music.html /tmp/music-rows.json
//
// 🚚 AND THE PAYLOAD IS THE REAL ONE. 6.203.0's rule — a harness that
// hand-builds the message the page receives cannot see a bug in the
// sending — so the rows drawn here are `mp.rowsJson()`'s own output over
// a queue of names a music folder is really allowed to hold.

const fs = require("fs");
const vm = require("vm");
const htmlPath = process.argv[2] || "/tmp/music.html";
const rowsPath = process.argv[3] || "/tmp/music-rows.json";
const html = fs.readFileSync(htmlPath, "utf8");
const ROWS = fs.readFileSync(rowsPath, "utf8");

let pass = 0, fail = 0; const failures = [];
// 🧪 EVERY MESSAGE IS READ THROUGH THIS. A mutation that stops one being
// posted must fail the check that wanted it — not throw on `undefined.a`
// and take every check after it with the run still saying "0 failed"
// (6.186.0, and 6.231.0's own suite paid it).
const at = (env, n) => env.sent[n] || {};
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

function makeEnv() {
  const sent = [];
  const listeners = { document: {}, el: {} };
  const dropClasses = [];
  const classes = {};
  const mk = (id) => {
    classes[id] = [];
    return {
      id, innerHTML: "", textContent: "", className: "",
      style: {},
      classList: {
        add: (c) => { classes[id].push("+" + c);
                      if (id === "drop") dropClasses.push("+" + c); },
        remove: (c) => { classes[id].push("-" + c);
                         if (id === "drop") dropClasses.push("-" + c); },
      },
      addEventListener: (ev, fn) => { listeners.el[id + ":" + ev] = fn; },
    };
  };
  const byId = {};
  for (const id of ["list", "play", "rep", "now", "sub", "fill",
                    "prev", "next", "clr", "drop", "hd"]) byId[id] = mk(id);
  let scrolled = 0;
  const sandbox = {
    document: {
      getElementById: (id) => byId[id] || null,
      // the highlighted row is scrolled into view; a DOM with no such row
      // must not be what proves the call happened
      querySelector: (sel) =>
        (sel === ".row.sel" && byId.list.innerHTML.indexOf("row sel") !== -1)
          ? { scrollIntoView: () => { scrolled++; } } : null,
      addEventListener: (ev, fn) => { listeners.document[ev] = fn; },
    },
    webkit: { messageHandlers: { musicPlayer: { postMessage: (m) => sent.push(m) } } },
  };
  return { sandbox, sent, listeners, byId, dropClasses, classes,
           scrolledCount: () => scrolled };
}

function load() {
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "music_player-page.js" });
  // 🪟 What the page says AS IT LOADS is its own fact (6.238.0's 'ready'
  // handshake) and is kept apart, so every check below still measures what
  // an INTERACTION sent rather than counting from one message further on.
  env.loadSent = env.sent.slice();
  env.sent.length = 0;
  env.call = (expr) => vm.runInContext(expr, ctx);
  env.draw = (json) => vm.runInContext("draw(" + json + ");", ctx);
  env.click = (id) => (env.listeners.el[id + ":click"] || (() => {}))({});
  env.key = (k, o) => env.listeners.document.keydown(
    Object.assign({ key: k, metaKey: false, altKey: false,
                    preventDefault() {} }, o || {}));
  env.keyup = (k, code) => env.listeners.document.keyup({ key: k, keyCode: code });
  env.drop = (data, names) => env.listeners.document.drop({
    preventDefault() {},
    dataTransfer: {
      getData: (t) => { if (data && t in data) return data[t];
                        if (data && data.THROW) throw new Error("no"); return ""; },
      files: (names || []).map((n) => ({ name: n })),
    },
  });
  return env;
}

console.log("── Music player: page JavaScript, executed ──");

// =====================================================================
// 1. an empty card
// =====================================================================
{
  const env = load();
  check("an empty queue says what to do with the card",
        env.byId.list.innerHTML.indexOf("drop files on this card") !== -1,
        env.byId.list.innerHTML);
  check("…and the header says nothing is playing",
        env.byId.now.textContent === "nothing playing", env.byId.now.textContent);
  check("…and the sub-line asks for music",
        env.byId.sub.textContent === "drop music here", env.byId.sub.textContent);
  check("repeat starts off", env.byId.rep.className === "", env.byId.rep.className);
}

// =====================================================================
// 2. the REAL payload, drawn — and the names that can break markup
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  const L = env.byId.list.innerHTML;
  check("all three tracks are drawn", (L.match(/class="row/g) || []).length >= 3,
        (L.match(/class="row/g) || []).length);

  // 🔤 THE ROW THIS SUITE EXISTS FOR. A file may be called anything, and
  // every name here is written with innerHTML.
  check("an ampersand in a track name survives as an ampersand",
        L.indexOf("Simon &amp; Garfunkel") !== -1, L.slice(0, 200));
  check("angle brackets in a name are TEXT, never markup",
        L.indexOf("&lt;Live&gt;") !== -1 && L.indexOf("<Live>") === -1);
  check("a quote in a name is escaped too", L.indexOf("&quot;Bootleg&quot;") !== -1);
  check("the refusal reason is escaped as well",
        L.indexOf("&lt;b&gt;.ogg&lt;/b&gt;") !== -1 && L.indexOf("<b>.ogg") === -1);
  check("the history name is escaped as well",
        (L.match(/Simon &amp; Garfunkel/g) || []).length === 2,
        (L.match(/Simon &amp; Garfunkel/g) || []).length);

  // 👁 …AND THE ESCAPING STAYED OUT OF LUA, which is why it is done here:
  // the header writes the SAME string with textContent, where an entity
  // would be read out literally.
  check("the header shows the real ampersand, not an entity",
        env.byId.now.textContent === "Simon & Garfunkel - The Sound of Silence",
        env.byId.now.textContent);

  check("the playing track is marked", L.indexOf("row cur") !== -1 ||
        L.indexOf("cur") !== -1);
  check("the highlighted row is the one Lua sent (sel 2)",
        L.indexOf('row sel" data-i="2"') !== -1 ||
        L.indexOf('class="row sel" data-i="2"') !== -1, L.slice(0, 400));
  check("…and it is scrolled into view", env.scrolledCount() === 1);
  check("a track that cannot play says so in its row",
        L.indexOf("does not play through") !== -1);
  check("the play button shows pause while playing",
        env.byId.play.innerHTML.indexOf("&#10073;") === 0, env.byId.play.innerHTML);
  check("repeat-all is armed", env.byId.rep.className === "armed");
  check("the sub-line counts the queue",
        env.byId.sub.textContent.indexOf("3 tracks") === 0, env.byId.sub.textContent);
  check("a history section is drawn", L.indexOf("history") !== -1);
  check("the refused line is drawn as a row", L.indexOf("&#9888;") !== -1);
}

{
  const env = load();
  // 📄 THE PAGE'S CONTRACT IS WIDER THAN TODAY'S CALLERS: everything Lua
  // sends is drawn as TEXT. `bad` is written by this module and is three
  // fixed sentences today, so no realistic queue can prove its escaping —
  // this check holds the CONTRACT rather than a live bug, and it bites the
  // moment the escaping is taken off.
  env.draw(JSON.stringify({
    rows: [{ i: 1, n: "ok", cur: true, bad: "macOS refused <this> & that" }],
    hist: [], sel: 1, mode: "off", playing: false, refused: [],
  }));
  check("a reason carrying markup is drawn as text too",
        env.byId.list.innerHTML.indexOf("&lt;this&gt; &amp; that") !== -1 &&
        env.byId.list.innerHTML.indexOf("<this>") === -1,
        env.byId.list.innerHTML);
}

// =====================================================================
// 3. a payload missing its fields must not wedge the card
// =====================================================================
// 🔔 `rowsJson` answers with a stripped payload when a name cannot be
// encoded. A page that read `S.rows.length` off that threw, and the card
// then never redrew again for the rest of the session — with the music
// still playing and nothing anywhere to see.
{
  const env = load();
  let threw = false;
  try { env.draw("{}"); } catch (e) { threw = true; }
  check("a payload with no rows at all does not throw", threw === false);
  check("…and the card still draws the empty line",
        env.byId.list.innerHTML.indexOf("drop files on this card") !== -1);
  env.draw(ROWS);
  check("…and the NEXT real payload still draws",
        env.byId.list.innerHTML.indexOf("Simon &amp; Garfunkel") !== -1);
  check("…with the queue count back", env.byId.sub.textContent.indexOf("3 tracks") === 0);
}
{
  const env = load();
  env.draw(ROWS);
  env.call("draw();");            // a bare redraw keeps what it had
  check("draw() with no argument keeps the rows it was given",
        env.byId.list.innerHTML.indexOf("Simon &amp; Garfunkel") !== -1);
}

// =====================================================================
// 4. the drop — where every path comes from
// =====================================================================
{
  const env = load();
  env.drop({ "text/uri-list": "file:///m/a.mp3\nfile:///m/b.mp3" }, ["a.mp3", "b.mp3"]);
  const m = env.sent[env.sent.length - 1] || {};
  check("a drop posts the uri-list, not the file objects", m.a === "drop");
  check("…carrying both URLs", String(m.uri).indexOf("file:///m/b.mp3") !== -1, m.uri);
  check("…and the names beside them, for the message when there is no path",
        (m.names || []).length === 2 && (m.names || [])[0] === "a.mp3");
}
{
  const env = load();
  env.drop({ "text/plain": "file:///m/only.mp3" }, []);
  check("a drop with no uri-list falls back to text/plain",
        at(env, 0).uri === "file:///m/only.mp3", at(env, 0).uri);
}
{
  const env = load();
  env.drop({}, ["Song.mp3"]);
  check("a drop carrying neither still reports, with the names it saw",
        at(env, 0).a === "drop" && at(env, 0).uri === "" &&
        (at(env, 0).names || [])[0] === "Song.mp3");
}
{
  const env = load();
  let threw = false;
  try { env.drop({ THROW: true }, []); } catch (e) { threw = true; }
  check("a dataTransfer that refuses to be read does not throw", threw === false);
  check("…and the drop is still reported", at(env, 0).a === "drop");
}
{
  const env = load();
  env.listeners.document.dragover({ preventDefault() {} });
  check("dragging over the card shows the drop target",
        env.dropClasses[env.dropClasses.length - 1] === "+show", env.dropClasses);
  env.drop({ "text/uri-list": "file:///m/a.mp3" }, []);
  check("…and dropping hides it again",
        env.dropClasses[env.dropClasses.length - 1] === "-show", env.dropClasses);
}

// =====================================================================
// 5. the keyboard
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  env.key("3", { metaKey: true });
  check("⌘3 plays the third track",
        at(env, 0).a === "pick" && at(env, 0).i === 3, JSON.stringify(env.sent[0]));
  env.key("ArrowDown");
  check("↓ walks the queue down", at(env, 1).a === "sel" && at(env, 1).d === 1);
  env.key("ArrowUp", { altKey: true });
  check("⌥↑ walks it up too", at(env, 2).a === "sel" && at(env, 2).d === -1);
  env.key("Enter");
  check("⏎ plays the HIGHLIGHTED row, which is the one Lua sent",
        at(env, 3).a === "pick" && at(env, 3).i === 2, JSON.stringify(env.sent[3]));
  env.key(" ");
  check("space is play / pause", at(env, 4).a === "play");
  env.key("Backspace");
  check("⌫ takes the highlighted track out",
        at(env, 5).a === "remove" && at(env, 5).i === 2);
  env.key("Delete");
  check("…and so does Delete", at(env, 6).a === "remove");
  env.key("Escape");
  check("Esc closes the card", at(env, 7).a === "esc");
  const n = env.sent.length;
  env.key("a");
  env.key("0", { metaKey: true });
  check("a letter and ⌘0 are not shortcuts here", env.sent.length === n,
        JSON.stringify(env.sent.slice(n)));
}

// =====================================================================
// 6. the ⇪ handshake — and only F18
// =====================================================================
// 🚨 6.165.1 / 6.193.0: the page forwards the F18 keyUp so the hold ends
// with the card open. Reporting EVERY keyup ends the hold while LL is
// still holding it.
{
  const env = load();
  env.keyup("F18");
  check("the F18 keyup is forwarded", at(env, 0).a === "f18");
  env.keyup("x", 88);
  check("…and nothing else is", env.sent.length === 1,
        JSON.stringify(env.sent));
  env.keyup("Unidentified", 79);
  check("…the keyCode is honoured too, for a WebKit that does not name it",
        env.sent.length === 2 && at(env, 1).a === "f18");
}

// =====================================================================
// 7. the buttons and the rows
// =====================================================================
{
  const env = load();
  env.click("prev");  env.click("next"); env.click("play");
  env.click("rep");   env.click("clr");
  check("every control posts its own action",
        env.sent.map((m) => m.a).join(",") === "prev,next,play,repeat,clear",
        env.sent.map((m) => m.a).join(","));
}
{
  const env = load();
  env.draw(ROWS);
  const row = (attrs) => ({ target: { closest: () => ({
    getAttribute: (k) => (k in attrs ? attrs[k] : null) }) } });
  env.listeners.el["list:click"](row({ "data-i": "2" }));
  check("clicking a track plays it",
        at(env, 0).a === "pick" && at(env, 0).i === 2);
  env.listeners.el["list:click"](row({ "data-h": "0" }));
  check("clicking a history line plays it again",
        at(env, 1).a === "hist" && at(env, 1).h === 0);
  env.listeners.el["list:click"]({ target: { closest: () => null } });
  check("clicking the empty part of the list does nothing",
        env.sent.length === 2);
}

// =====================================================================
// 8. the title strip is the grip
// =====================================================================
// 🪟 6.232.0. A page cannot move the window it is drawn in, so the strip
// reports the press and Lua does the moving. A bare press — no modifier —
// because a header is safe by construction: there is nothing on it a
// click could have meant instead.
{
  // 🧪 THE LAST DECLARATION IN THE RULE WINS, so a string search for
  // "cursor:grab" passes with `cursor:default` written after it — the
  // mutation that proved it is why this reads the rule instead.
  const rule = (html.match(/(^|\})\s*header\s*\{([^}]*)\}/) || [])[2] || "";
  const cursors = rule.match(/cursor\s*:\s*([a-z-]+)/g) || [];
  check("the title strip's pointer says it can be grabbed",
        cursors.length > 0 &&
        cursors[cursors.length - 1].replace(/\s/g, "") === "cursor:grab",
        JSON.stringify(cursors));
}
{
  const env = load();
  env.draw(ROWS);
  const md = env.listeners.el["hd:mousedown"];
  check("the title strip listens for a press at all", typeof md === "function");
  let prevented = false;
  (md || (() => {}))({ preventDefault: () => { prevented = true; } });
  check("a press on the strip asks Lua to pick the window up",
        at(env, 0).a === "dragStart", JSON.stringify(env.sent[0]));
  check("…with no modifier held — it is a bare drag", env.sent.length === 1);
  check("…and the page keeps the event, so nothing else acts on it",
        prevented === true);
  check("…and the pointer says it is being dragged",
        (env.classes.hd || []).indexOf("+dragging") !== -1,
        JSON.stringify(env.classes.hd));
  (env.listeners.document.mouseup || (() => {}))({});
  check("…until the button comes up", 
        (env.classes.hd || []).indexOf("-dragging") !== -1);
}
{
  const env = load();
  env.draw(ROWS);
  const row = (attrs) => ({ target: { closest: () => ({
    getAttribute: (k) => (k in attrs ? attrs[k] : null) }) } });
  env.listeners.el["list:click"](row({ "data-i": "2" }));
  check("🚨 a press on a ROW still picks the track — the grip is the strip, "
        + "never the whole card",
        at(env, 0).a === "pick" && at(env, 0).i === 2,
        JSON.stringify(env.sent[0]));
}

// =====================================================================
// 9. the clock
// =====================================================================
{
  const env = load();
  env.draw(ROWS);
  env.call("clock('0:12 / 3:40', 5.5);");
  check("the elapsed line replaces the count while a track plays",
        env.byId.sub.textContent === "0:12 / 3:40  ·  repeat all",
        env.byId.sub.textContent);
  check("the progress bar is a percentage",
        env.byId.fill.style.width === "5.5%", env.byId.fill.style.width);
}
{
  const env = load();
  env.call("clock('0:12', 0);");
  check("a clock tick with an empty queue leaves the invitation alone",
        env.byId.sub.textContent === "drop music here", env.byId.sub.textContent);
}

// ---- 🪟 the page tells Lua it exists ---------------------------------
// 6.238.0. LL's card came up "nothing playing · QUEUE EMPTY" over music
// that was playing: view:html() returns before WebKit has parsed the
// document, so the draw pushed on the next line went nowhere and the
// page drew its own empty default. The page ASKS now, as its last act.
{
  const env = load();
  const msgs = env.loadSent.filter((m) => m && m.a === "ready");
  check("🪟 the page posts 'ready' when its script has run",
        msgs.length === 1, JSON.stringify(env.loadSent));
  check("...and it is the LAST thing it sends while loading — sent any "
        + "earlier it would promise something that is not there yet",
        env.loadSent.length > 0
        && env.loadSent[env.loadSent.length - 1].a === "ready",
        JSON.stringify(env.loadSent));
  check("...and nothing else is posted at load — a card that talks while "
        + "it draws would fire an action nobody asked for",
        env.loadSent.length === 1, JSON.stringify(env.loadSent));
}

// ---- ⏪ ← → seek ------------------------------------------------------
{
  const env = load();
  env.key("ArrowRight");
  check("⏪ → asks Lua to seek forward by the step",
        at(env, 0).a === "seek" && at(env, 0).d === 5,
        JSON.stringify(env.sent[0]));
  env.key("ArrowLeft");
  check("⏪ ← seeks back by the same step",
        at(env, 1).a === "seek" && at(env, 1).d === -5,
        JSON.stringify(env.sent[1]));
  env.key("ArrowRight", { shiftKey: true });
  check("⇧→ is the bigger step", at(env, 2).d === 30,
        JSON.stringify(env.sent[2]));
  env.key("ArrowLeft", { shiftKey: true });
  check("⇧← too, and negative", at(env, 3).d === -30,
        JSON.stringify(env.sent[3]));
  // 🚨 ↑↓ must NOT have become a seek — they walk the list, and the two
  // pairs live one line apart in the same handler.
  const n = env.sent.length;
  env.key("ArrowDown");
  check("🚨 ↓ still walks the list — it did not become a seek",
        at(env, n).a === "sel" && at(env, n).d === 1,
        JSON.stringify(env.sent[n]));
}

// =====================================================================
if (fail > 0) {
  console.log("FAILURES:");
  for (const f of failures) console.log("  ❌ " + f);
}
console.log(`── test_music_js: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
