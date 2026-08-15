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

function makeEnv() {
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
    getBoundingClientRect: () => ({ left: 0, top: 0, width: W, height: H }),
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
  };
  return { sandbox, sent, listeners, cv, ov, band, tin, buttons, store, cvCalls, ovCalls };
}

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
check("the page carries exactly one script block", scripts.length === 1, scripts.length);

const vm = require("vm");
function load() {
  const env = makeEnv();
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
console.log(`\n${pass} passed, ${fail} failed`);
for (const f of failures) console.log("    ❌ " + f);
process.exit(fail === 0 ? 0 : 1);
