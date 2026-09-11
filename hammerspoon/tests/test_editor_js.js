// =====================================================================
// test_editor_js.js — RUNS the Screenshot Editor's page code for real.
// =====================================================================
// The blur, the text boxes and the arrows all live entirely in the
// page's JavaScript — the Lua suite can only grep for them. This loads
// the real generated page, gives it canvases whose ImageData is backed
// by a real pixel buffer (cv) and a draw-call recorder (ov), and drives
// actual drags, clicks, keystrokes, undos and saves through the actual
// handlers.
//
//   lua5.4 dump_editor_html.lua ./modules > /tmp/editor.html
//   node test_editor_js.js /tmp/editor.html

const fs = require("fs");
const htmlPath = process.argv[2] || "/tmp/editor.html";
const html = fs.readFileSync(htmlPath, "utf8");

let pass = 0, fail = 0; const failures = [];
const check = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; failures.push(label + (extra !== undefined ? `  — ${extra}` : "")); }
};

// ---- a canvas whose pixels are REAL ----------------------------------
const W = 40, H = 30;
function makeCtx(store) {
  return {
    drawImage() {},
    getImageData(x, y, rw, rh) {
      const data = new Uint8ClampedArray(rw * rh * 4);
      for (let j = 0; j < rh; j++)
        for (let i = 0; i < rw; i++)
          for (let k = 0; k < 4; k++)
            data[(j * rw + i) * 4 + k] = store[((y + j) * W + (x + i)) * 4 + k];
      return { data, width: rw, height: rh };
    },
    putImageData(im, x, y) {
      for (let j = 0; j < im.height; j++)
        for (let i = 0; i < im.width; i++)
          for (let k = 0; k < 4; k++)
            store[((y + j) * W + (x + i)) * 4 + k] = im.data[(j * im.width + i) * 4 + k];
    },
  };
}

// the vector-drawing surface: no pixels, but every call is RECORDED so
// the suite can assert what was drawn, with what style, in what color.
function drawStubs(base, calls) {
  const rec = (name) => function (...a) { calls.push([name, ...a]); };
  base.clearRect = rec("clearRect");
  base.save = rec("save"); base.restore = rec("restore");
  base.beginPath = rec("beginPath"); base.closePath = rec("closePath");
  base.moveTo = rec("moveTo"); base.lineTo = rec("lineTo");
  base.arc = rec("arc"); base.setLineDash = function () {};
  base.stroke = function () { calls.push(["stroke", this.strokeStyle]); };
  base.fill = function () { calls.push(["fill", this.fillStyle]); };
  base.strokeRect = function (x, y, w, h) {
    calls.push(["strokeRect", x, y, w, h, this.strokeStyle]);
  };
  base.fillText = function (t, x, y) {
    calls.push(["fillText", t, x, y, this.fillStyle]);
  };
  base.measureText = (t) => ({ width: String(t).length * 8 });
  return base;
}

// 6.188.0 — the canvas is DISPLAYED at whatever width fits the window, and
// until 6.188.0 every hit target was measured in image pixels regardless.
// `shownW` lets a test put a big image in a small window, which is the only
// way to see that bug at all: at 1:1 it does not exist.
function makeEnv(shownW) {
  const sent = [];
  const store = new Uint8ClampedArray(W * H * 4);
  const cvCalls = [], ovCalls = [];
  const listeners = { window: {}, ov: {}, tin: {} };
  const cvCtx = drawStubs(makeCtx(store), cvCalls);
  const ovCtx = drawStubs({ getImageData() {}, putImageData() {} }, ovCalls);
  const cv = {
    width: W, height: H,
    getContext: () => cvCtx,
    toDataURL: (fmt) => (fmt === "image/jpeg" ? "data:image/jpeg;base64,RENDERED"
                                              : "data:image/png;base64,RENDERED"),
    getBoundingClientRect: () => ({ left: 0, top: 0, width: shownW || W,
                                   height: (shownW || W) * (H / W) }),
    addEventListener: () => {},
  };
  const ov = {
    width: W, height: H,
    getContext: () => ovCtx,
    addEventListener: (ev, fn) => { listeners.ov[ev] = fn; },
  };
  const band = { style: {} };
  const tin = {
    style: { display: "none" }, value: "",
    focus() { this.focused = true; },
    addEventListener: (ev, fn) => { listeners.tin[ev] = fn; },
  };
  const buttons = {
    "tool-blur": { className: "tool on" },
    "tool-text": { className: "tool" },
    "tool-arrow": { className: "tool" },
  };
  const byId = { cv, ov, band, tin };
  const sandbox = {
    document: { getElementById: (id) => byId[id] || buttons[id] || null },
    window: {
      webkit: { messageHandlers: { shotEditor: { postMessage: (m) => sent.push(m) } } },
      addEventListener: (ev, fn) => { listeners.window[ev] = fn; },
    },
    Image: function () { return { set src(v) {}, onload: null }; },
    // 6.189.0 — the restore path decodes its notes here
    atob: (b) => Buffer.from(b, "base64").toString("binary"),
    TextDecoder,
  };
  return { sandbox, sent, listeners, cv, ov, band, tin, buttons, store, cvCalls, ovCalls };
}

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

const vm = require("vm");
function load(shownW) {
  const env = makeEnv(shownW);
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext(scripts[0], ctx, { filename: "screenshot_editor-page.js" });
  env.ctx = ctx;
  env.call = (expr) => vm.runInContext(expr, ctx);
  return env;
}

const key = (opts) => Object.assign({ preventDefault() {} }, opts);
const mouse = (x, y, button) => ({ clientX: x, clientY: y, button: button || 0,
                                   preventDefault() {} });

console.log("── Screenshot Editor: page JavaScript, executed ──");

// =====================================================================
// 1. the blur core, on synthetic pixels
// =====================================================================
{
  const env = load();
  // a uniform gray patch must come out EXACTLY as it went in — a blur
  // that shifts flat color is leaking energy at the edges
  const flat = new Uint8ClampedArray(16 * 16 * 4).fill(128);
  env.ctx.flat = flat;
  env.call("boxBlurRGBA(flat, 16, 16, 3, 3)");
  let intact = true;
  for (let i = 0; i < flat.length; i++) if (flat[i] !== 128) { intact = false; break; }
  check("flat color survives the blur untouched (edge handling is right)", intact);

  // one white pixel on black must SPREAD: center darker, neighbor lit
  const spot = new Uint8ClampedArray(15 * 15 * 4);
  for (let i = 0; i < spot.length; i += 4) spot[i + 3] = 255;
  const c = (7 * 15 + 7) * 4;
  spot[c] = spot[c + 1] = spot[c + 2] = 255;
  env.ctx.spot = spot;
  env.call("boxBlurRGBA(spot, 15, 15, 2, 3)");
  const n = (7 * 15 + 8) * 4;
  check("a lone bright pixel spreads into its neighbors",
        spot[c] < 255 && spot[c] > 0 && spot[n] > 0,
        `center=${spot[c]} neighbor=${spot[n]}`);
  check("…and alpha is preserved", spot[c + 3] === 255, spot[c + 3]);

  // radius 0 must be a strict no-op
  const noop = new Uint8ClampedArray(8 * 8 * 4);
  noop[0] = 200;
  env.ctx.noop = noop;
  env.call("boxBlurRGBA(noop, 8, 8, 0, 3)");
  check("radius 0 is a strict no-op", noop[0] === 200);
}

// =====================================================================
// 2. drag → blur → undo, through the real handlers (the Blur tool)
// =====================================================================
{
  const env = load();
  // paint a hard two-tone image: left half white, right half black
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const o = (y * W + x) * 4;
      const v = x < W / 2 ? 255 : 0;
      env.store[o] = env.store[o + 1] = env.store[o + 2] = v;
      env.store[o + 3] = 255;
    }
  const before = env.store.slice();

  // drag a box across the boundary — real mousedown/mousemove/mouseup
  // (the mouse lands on the OVERLAY canvas now; blur is the default tool)
  env.listeners.ov.mousedown(mouse(12, 8));
  env.listeners.window.mousemove(mouse(28, 22));
  check("the band is visible mid-drag", env.band.style.display === "block");
  env.listeners.window.mouseup(mouse(28, 22));
  check("…and hidden after release", env.band.style.display === "none");

  const bi = (15 * W + 19) * 4;     // inside the box, at the color boundary
  check("pixels INSIDE the box changed (the boundary got soft)",
        env.store[bi] !== before[bi], env.store[bi]);
  const oi = (2 * W + 2) * 4;       // far outside the box
  check("pixels OUTSIDE the box did not", env.store[oi] === before[oi]);

  // ⌘Z through the real keydown handler restores the exact bytes
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  let restored = true;
  for (let i = 0; i < env.store.length; i++)
    if (env.store[i] !== before[i]) { restored = false; break; }
  check("⌘Z restores the image byte-for-byte", restored);

  // a sub-2px drag must not push an undo entry or touch pixels
  env.listeners.ov.mousedown(mouse(5, 5));
  env.listeners.window.mouseup(mouse(6, 6));
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  let still = true;
  for (let i = 0; i < env.store.length; i++)
    if (env.store[i] !== before[i]) { still = false; break; }
  check("a tiny accidental drag is a no-op (and cannot be 'undone')", still);
}

// =====================================================================
// 3. the Text tool — click, type, ⏎; move; re-edit (6.88.0)
// =====================================================================
{
  const env = load();
  env.call("setTool('text')");
  check("the Text tool button lights up",
        env.buttons["tool-text"].className.indexOf("on") >= 0,
        env.buttons["tool-text"].className);
  env.listeners.ov.mousedown(mouse(10, 20));
  check("clicking an empty spot opens the floating input",
        env.tin.style.display === "block");
  env.tin.value = "Hello";
  env.listeners.tin.keydown(key({ key: "Enter" }));
  check("⏎ commits a text note with the typed words",
        env.call("notes.length") === 1 && env.call("notes[0].kind") === "text"
        && env.call("notes[0].text") === "Hello");
  check("…drawn as WHITE text (LL's spec)",
        env.ovCalls.some((c) => c[0] === "fillText" && c[1] === "Hello"
                                && c[4] === "#ffffff"));
  check("…inside a WHITE outline box",
        env.ovCalls.some((c) => c[0] === "strokeRect" && c[5] === "#ffffff"));

  // grab it and drag it somewhere else
  env.listeners.ov.mousedown(mouse(11, 18));       // inside its box
  env.listeners.window.mousemove(mouse(23, 27));   // +12, +9
  env.listeners.window.mouseup(mouse(23, 27));
  check("dragging a text note MOVES it",
        env.call("notes[0].x") === 22 && env.call("notes[0].y") === 29,
        env.call("notes[0].x") + "," + env.call("notes[0].y"));
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("⌘Z puts it back where it was",
        env.call("notes[0].x") === 10 && env.call("notes[0].y") === 20);

  // double-click re-opens the words for editing
  env.listeners.ov.dblclick(mouse(11, 18));
  check("double-click re-opens the words, pre-filled",
        env.tin.style.display === "block" && env.tin.value === "Hello");
  env.tin.value = "Renamed";
  env.listeners.tin.keydown(key({ key: "Enter" }));
  check("…and ⏎ applies the edit", env.call("notes[0].text") === "Renamed");
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("…undoably", env.call("notes[0].text") === "Hello");

  // Escape while typing closes the INPUT, never the editor
  env.sent.length = 0;
  env.listeners.ov.mousedown(mouse(35, 29));       // empty spot → new input
  env.listeners.tin.keydown(key({ key: "Escape" }));
  check("Esc while typing closes the input, not the editor",
        env.tin.style.display === "none" && env.sent.length === 0
        && env.call("notes.length") === 1);
}

// =====================================================================
// 3b. 6.207.0 — LL: "I can't edit an existing text box. If I click on
// the text box, a new one is created instead." Editing is reachable
// three ways now, and each is driven here: a CLICK on the box with the
// Text tool, a double-click with any tool, and ⏎ on a selected box. A
// drag with the Text tool still moves it.
// =====================================================================
{
  const env = load();
  env.call("setTool('text')");
  env.listeners.ov.mousedown(mouse(10, 20));
  env.tin.value = "Hello";
  env.listeners.tin.keydown(key({ key: "Enter" }));
  check("(fixture) one text note, input closed",
        env.call("notes.length") === 1 && env.tin.style.display === "none");

  // a CLICK on the existing box with the Text tool: press, release, no move
  env.listeners.ov.mousedown(mouse(11, 18));
  env.listeners.window.mouseup(mouse(11, 18));
  check("🚨 a click on an existing text box with the Text tool opens ITS words,"
        + " pre-filled — not a new box",
        env.tin.style.display === "block" && env.tin.value === "Hello"
        && env.call("notes.length") === 1,
        env.tin.style.display + " / " + env.tin.value + " / " + env.call("notes.length"));
  env.tin.value = "Edited";
  env.listeners.tin.keydown(key({ key: "Enter" }));
  check("…and ⏎ applies the edit to THAT note", env.call("notes[0].text") === "Edited"
        && env.call("notes.length") === 1, env.call("JSON.stringify(notes)"));

  // a DRAG with the Text tool still moves it and opens nothing
  env.listeners.ov.mousedown(mouse(11, 18));
  env.listeners.window.mousemove(mouse(23, 27));
  env.listeners.window.mouseup(mouse(23, 27));
  check("a drag on the box with the Text tool still MOVES it, and opens no input",
        env.call("notes[0].x") === 22 && env.tin.style.display === "none",
        env.call("notes[0].x") + " / " + env.tin.style.display);
  check("…undoably", (env.listeners.window.keydown(key({ metaKey: true, key: "z" })),
        env.call("notes[0].x") === 10));

  // a steady hand: a 2-pixel wobble is a click, not a drag
  env.listeners.ov.mousedown(mouse(11, 18));
  env.listeners.window.mousemove(mouse(12, 19));
  env.listeners.window.mouseup(mouse(12, 19));
  check("a one-pixel wobble during the click is still a click — it opens the words",
        env.tin.style.display === "block" && env.tin.value === "Edited");
  env.listeners.tin.keydown(key({ key: "Escape" }));

  // with the BLUR tool a click only selects — the words are not opened
  env.call("setTool('blur')");
  env.listeners.ov.mousedown(mouse(11, 18));
  env.listeners.window.mouseup(mouse(11, 18));
  check("with another tool a click on the box SELECTS it and opens nothing",
        env.call("sel === notes[0]") && env.tin.style.display === "none");
  // …and ⏎ on the selected box edits it, from the keyboard
  env.listeners.window.keydown(key({ key: "Enter" }));
  check("🚨 ⏎ on a selected text box opens its words",
        env.tin.style.display === "block" && env.tin.value === "Edited",
        env.tin.style.display + " / " + env.tin.value);
  env.listeners.tin.keydown(key({ key: "Escape" }));
  // ⌘⏎ is still the save, never an edit
  env.sent.length = 0;
  env.listeners.window.keydown(key({ metaKey: true, key: "Enter" }));
  check("…while ⌘⏎ with a box selected is still SAVE",
        env.sent.length === 1 && env.sent[0].a === "save" && env.tin.style.display === "none");
  // and ⏎ with nothing selected does nothing
  env.call("sel = null");
  env.listeners.window.keydown(key({ key: "Enter" }));
  check("⏎ with nothing selected opens nothing", env.tin.style.display === "none");

  // a click on EMPTY space with the Text tool still starts a NEW box
  // (the fixture note's box covers most of a 40×30 canvas — clear it)
  env.call("setTool('text'); notes.length = 0; sel = null;");
  env.listeners.ov.mousedown(mouse(36, 28));
  check("a click on empty space with the Text tool still starts a new box",
        env.tin.style.display === "block" && env.tin.value === "");
  env.listeners.tin.keydown(key({ key: "Escape" }));
}

// =====================================================================
// 4. the Arrow tool — draw, stretch+rotate by an end, move, delete
// =====================================================================
{
  const env = load();
  env.call("setTool('arrow')");
  env.listeners.ov.mousedown(mouse(5, 5));
  env.listeners.window.mousemove(mouse(30, 25));
  env.listeners.window.mouseup(mouse(30, 25));
  check("dragging draws an arrow from press to release",
        env.call("notes.length") === 1 && env.call("notes[0].kind") === "arrow"
        && env.call("notes[0].x1") === 5 && env.call("notes[0].y1") === 5
        && env.call("notes[0].x2") === 30 && env.call("notes[0].y2") === 25);
  check("…with a white filled HEAD at the tip",
        env.ovCalls.some((c) => c[0] === "fill" && c[1] === "#ffffff"));

  // grab the tip: one drag stretches AND rotates
  env.listeners.ov.mousedown(mouse(30, 25));
  env.listeners.window.mousemove(mouse(38, 3));
  env.listeners.window.mouseup(mouse(38, 3));
  check("dragging an END stretches/rotates — the tip follows, the tail stays",
        env.call("notes[0].x2") === 38 && env.call("notes[0].y2") === 3
        && env.call("notes[0].x1") === 5 && env.call("notes[0].y1") === 5);

  // grab the shaft: the whole arrow moves
  env.listeners.ov.mousedown(mouse(21, 4));        // on the line, far from ends
  env.listeners.window.mousemove(mouse(26, 14));   // +5, +10
  env.listeners.window.mouseup(mouse(26, 14));
  check("dragging the SHAFT moves the whole arrow",
        env.call("notes[0].x1") === 10 && env.call("notes[0].y1") === 15
        && env.call("notes[0].x2") === 43 && env.call("notes[0].y2") === 13,
        env.call("notes[0].x1") + "," + env.call("notes[0].y1"));

  // the undo stack peels those back newest-first
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("⌘Z undoes the move", env.call("notes[0].x1") === 5);
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("⌘Z again undoes the stretch", env.call("notes[0].x2") === 30);
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("⌘Z a third time removes the arrow entirely",
        env.call("notes.length") === 0);

  // a click without a drag is not an arrow
  env.listeners.ov.mousedown(mouse(9, 9));
  env.listeners.window.mouseup(mouse(10, 10));
  check("a click without a drag leaves no arrow", env.call("notes.length") === 0);

  // ⌫ deletes the selected note, undoably
  env.listeners.ov.mousedown(mouse(5, 5));
  env.listeners.window.mousemove(mouse(30, 25));
  env.listeners.window.mouseup(mouse(30, 25));
  env.listeners.window.keydown(key({ key: "Backspace" }));
  check("⌫ deletes the selected note", env.call("notes.length") === 0);
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  check("…and ⌘Z brings it back", env.call("notes.length") === 1);
}

// =====================================================================
// 5. the messages that reach Lua — png, jpeg, cancel, buttons
// =====================================================================
{
  const env = load();
  // put a text note on so the save has something to composite
  env.call("setTool('text')");
  env.listeners.ov.mousedown(mouse(10, 20));
  env.tin.value = "Note";
  env.listeners.tin.keydown(key({ key: "Enter" }));

  const beforeSave = env.store.slice();
  env.cvCalls.length = 0;
  env.listeners.window.keydown(key({ metaKey: true, key: "Enter" }));
  check("⌘⏎ paints the notes INTO the saved pixels",
        env.cvCalls.some((c) => c[0] === "fillText" && c[1] === "Note"));
  check("…and sends the rendered png with ext png", env.sent.length === 1
        && env.sent[0].a === "save" && env.sent[0].ext === "png"
        && env.sent[0].data === "data:image/png;base64,RENDERED",
        JSON.stringify(env.sent[0]));
  let clean = true;
  for (let i = 0; i < env.store.length; i++)
    if (env.store[i] !== beforeSave[i]) { clean = false; break; }
  check("…then puts the CLEAN pixels back — notes stay live after save", clean);

  env.sent.length = 0;
  env.listeners.window.keydown(key({ metaKey: true, shiftKey: true, key: "Enter" }));
  check("⌘⇧⏎ sends a small JPEG instead", env.sent[0]
        && env.sent[0].ext === "jpg"
        && env.sent[0].data === "data:image/jpeg;base64,RENDERED",
        JSON.stringify(env.sent[0]));

  env.sent.length = 0;
  env.listeners.window.keydown(key({ key: "Escape" }));
  check("esc sends cancel", env.sent[0] && env.sent[0].a === "cancel");

  // the toolbar buttons drive the same paths — via their real onclicks
  const onclicks = [...html.matchAll(/onclick="([^"]+)"/g)].map((m) => m[1]);
  check("the toolbar has onclick handlers to drive", onclicks.length >= 7, onclicks.length);
  env.sent.length = 0;
  for (const expr of onclicks) env.call(expr.replace(/&quot;/g, '"').replace(/&amp;/g, "&"));
  const acts = env.sent.map((m) => m.a).sort().join(",");
  const exts = env.sent.filter((m) => m.a === "save").map((m) => m.ext).sort().join(",");
  check("…and between them they save (both formats) and cancel",
        acts.indexOf("save") >= 0 && acts.indexOf("cancel") >= 0
        && exts === "jpg,png", acts + " / " + exts);
}

// =====================================================================
// 6.188.0 — LL: the text box handles are hard to grab. They were sized in
// IMAGE pixels while the mouse works in SCREEN pixels, and the canvas is
// displayed scaled DOWN to fit the window — so the bigger the screenshot,
// the smaller the target. Every check below runs the image at 4:1, which
// is roughly a 4K shot in a 1,000 pt window; at 1:1 the bug is invisible,
// which is exactly why it survived this long.
{
  const SHOWN = W / 4;                       // 4 image pixels per screen pixel

  const e1 = load();                         // 1:1
  const e4 = load(SHOWN);                    // 4:1
  const r1 = e1.call("handleR()"), r4 = e4.call("handleR()");
  check("the grab radius GROWS with the display scale — it is a screen target",
        r4 > r1 * 3, r1 + " → " + r4);
  check("…and at 1:1 the floor is the screen radius, so it never drops below it",
        r1 >= e1.call("HANDLEPX"), r1 + " vs " + e1.call("HANDLEPX"));
  check("the scale is read live and survives a canvas with no layout yet",
        e1.call("viewScale()") === 1 && e4.call("viewScale()") === 4,
        e1.call("viewScale()") + " / " + e4.call("viewScale()"));

  // a small text note in a scaled-down window: the thing LL could not grab
  const mk = (env) => {
    env.call("notes.push({kind:'text', text:'Hi', x:20, y:20, size:12}); sel=null;");
    return env.call("noteBox(notes[0])");
  };
  {
    const env = load(SHOWN);
    const b = mk(env);
    // a point just OUTSIDE the glyph box — where a hand aiming at a small
    // label in a scaled window actually lands
    const px = b.x + b.w + 2, py = b.y + b.h + 2;
    const hit = env.call(`hitAt({x:${px}, y:${py}})`);
    check("a click just outside a small text box still finds it",
          hit !== null, JSON.stringify(hit));
    // and specifically the SIDE of the box, nowhere near the corner handle:
    // this is the near-miss that used to do nothing at all
    const near = env.call(`hitAt({x:${b.x - 3}, y:${b.y + b.h / 2}})`);
    check("…including a near-miss down the SIDE, which is a move not a resize",
          near && near.part === "move", JSON.stringify(near));
    const far = env.call(`hitAt({x:${b.x - 500}, y:${b.y + b.h / 2}})`);
    check("…but a real miss is still a miss — the box did not become the canvas",
          far === null, JSON.stringify(far));
  }
  {
    const env = load(SHOWN);
    const b = mk(env);
    const hit = env.call(`hitAt({x:${b.x + b.w}, y:${b.y + b.h}})`);
    check("the bottom-right corner is a SIZE handle, not just more box",
          hit && hit.part === "size", JSON.stringify(hit));
    const inside = env.call(`hitAt({x:${b.x + 1}, y:${b.y + 1}})`);
    check("…and the box itself still MOVES, so resizing did not eat the drag",
          inside && inside.part === "move", JSON.stringify(inside));
  }
  {
    // drag the corner: the text grows, the anchor does not move, ⌘Z undoes it
    const env = load(SHOWN);
    const b = mk(env);
    // a synthesised event carries SCREEN coordinates; toCanvas scales them
    // back up, so an image point must be divided by the scale on the way in
    const S = (v) => v / 4;
    env.listeners.ov.mousedown(mouse(S(b.x + b.w), S(b.y + b.h)));
    env.listeners.window.mousemove(mouse(S(b.x + b.w) + 10, S(b.y + b.h) + 10));
    env.listeners.window.mouseup(mouse(S(b.x + b.w) + 10, S(b.y + b.h) + 10));
    check("dragging the corner makes the text BIGGER",
          env.call("notes[0].size") > 12, env.call("notes[0].size"));
    check("…and the note stays where it was put",
          env.call("notes[0].x") === 20 && env.call("notes[0].y") === 20,
          env.call("notes[0].x") + "," + env.call("notes[0].y"));
    env.call("undoLast()");
    check("…and ⌘Z puts the size back — a resize is undoable like a move",
          env.call("notes[0].size") === 12, env.call("notes[0].size"));
  }
  {
    // shrinking, and the floor: a note can never be dragged out of existence
    const env = load(SHOWN);
    const b = mk(env);
    const S2 = (v) => v / 4;
    env.listeners.ov.mousedown(mouse(S2(b.x + b.w), S2(b.y + b.h)));
    env.listeners.window.mousemove(mouse(S2(b.x + b.w) - 4000, S2(b.y + b.h) - 4000));
    env.listeners.window.mouseup(mouse(S2(b.x + b.w) - 4000, S2(b.y + b.h) - 4000));
    check("dragging the corner inwards shrinks it, but never past a floor",
          env.call("notes[0].size") >= 10, env.call("notes[0].size"));
  }
  {
    // an ARROW keeps its endpoints — the same radius change must not make
    // the two ends of a short arrow indistinguishable
    const env = load(SHOWN);
    env.call("notes.push({kind:'arrow', x1:5, y1:5, x2:35, y2:25}); sel=null;");
    const h1 = env.call("hitAt({x:5, y:5})"), h2 = env.call("hitAt({x:35, y:25})");
    check("an arrow's two ends are still told apart at the bigger radius",
          h1 && h1.part === "p1" && h2 && h2.part === "p2",
          JSON.stringify([h1, h2]));
  }
}

// =====================================================================
// 9. the work leaves with an Esc and comes back (6.189.0)
// =====================================================================
// LL lost a screenshot's annotations to an accidental Esc. The page has
// to hand its state OUT on the way through the door, and take it back in
// on the way through the next one.
{
  const env = load();
  env.call("applyBlur(4, 4, 10, 8);");
  env.call("notes.push({kind:'text', x:3, y:9, text:'kept', size:20});");
  env.call("stashAndCancel();");
  const msg = env.sent[env.sent.length - 1];
  check("Esc posts a cancel", msg && msg.a === "cancel", JSON.stringify(msg));
  check("…carrying the canvas — that is where the BLURS live, baked in",
        msg && typeof msg.img === "string"
        && /^data:image\/png;base64,/.test(msg.img), msg && msg.img);
  check("…and the notes beside it, as JSON",
        msg && JSON.parse(msg.notes).length === 1
        && JSON.parse(msg.notes)[0].text === "kept", msg && msg.notes);

  // 🚨 the two halves must not overlap: the notes live on the OVERLAY, so
  // the canvas handed back must NOT already have them painted in, or a
  // restore draws every annotation twice.
  const painted = env.cvCalls.some((c) => c[0] === "fillText");
  check("🚨 the notes are NOT painted into the canvas that is handed back",
        !painted);
}

{
  // a stash that cannot be read must restore nothing rather than break
  // the editor — the page comes up empty and usable either way
  const broken = html
    .replace("var RESTORENOTES = ''", "var RESTORENOTES = 'not base64 at all!!'");
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  let threw = false;
  try {
    vm.runInContext([...broken.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1], ctx);
  } catch (e) { threw = true; }
  check("an unreadable stash never breaks the page", !threw);
  check("…and leaves no notes behind",
        !threw && vm.runInContext("notes.length", ctx) === 0);
}

{
  // and the real thing: a stash the page CAN read comes back as notes
  const kept = JSON.stringify([{ kind: "text", x: 2, y: 3, text: "back", size: 18 }]);
  const good = html.replace("var RESTORENOTES = ''",
    "var RESTORENOTES = '" + Buffer.from(kept, "utf8").toString("base64") + "'");
  const env = makeEnv();
  const ctx = vm.createContext(env.sandbox);
  vm.runInContext([...good.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1], ctx);
  check("a kept note is back in the page on the next open",
        vm.runInContext("notes.length", ctx) === 1
        && vm.runInContext("notes[0].text", ctx) === "back",
        vm.runInContext("JSON.stringify(notes)", ctx));
}

console.log(`\n${pass} passed, ${fail} failed`);
for (const f of failures) console.log("    ❌ " + f);
process.exit(fail === 0 ? 0 : 1);
