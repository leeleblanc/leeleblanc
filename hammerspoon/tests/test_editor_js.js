// =====================================================================
// test_editor_js.js — RUNS the Screenshot Editor's blur for real.
// =====================================================================
// The blur is the module's whole reason to exist, and it lives entirely
// in the page's JavaScript — the Lua suite can only grep for it. This
// loads the real generated page, gives it a canvas whose ImageData is
// backed by a real pixel buffer, and drives actual drags, undos and
// saves through the actual handlers.
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

function makeEnv() {
  const sent = [];
  const store = new Uint8ClampedArray(W * H * 4);
  const listeners = { window: {}, cv: {} };
  const cv = {
    width: W, height: H,
    getContext: () => makeCtx(store),
    toDataURL: () => "data:image/png;base64,RENDERED",
    getBoundingClientRect: () => ({ left: 0, top: 0, width: W, height: H }),
    addEventListener: (ev, fn) => { listeners.cv[ev] = fn; },
  };
  const band = { style: {} };
  const sandbox = {
    document: { getElementById: (id) => (id === "cv" ? cv : id === "band" ? band : null) },
    window: {
      webkit: { messageHandlers: { shotEditor: { postMessage: (m) => sent.push(m) } } },
      addEventListener: (ev, fn) => { listeners.window[ev] = fn; },
    },
    Image: function () { return { set src(v) {}, onload: null }; },
  };
  return { sandbox, sent, listeners, cv, band, store };
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
// 2. drag → blur → undo, through the real handlers
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
  env.listeners.cv.mousedown(mouse(12, 8));
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
  env.listeners.cv.mousedown(mouse(5, 5));
  env.listeners.window.mouseup(mouse(6, 6));
  env.listeners.window.keydown(key({ metaKey: true, key: "z" }));
  let still = true;
  for (let i = 0; i < env.store.length; i++)
    if (env.store[i] !== before[i]) { still = false; break; }
  check("a tiny accidental drag is a no-op (and cannot be 'undone')", still);
}

// =====================================================================
// 3. the messages that reach Lua
// =====================================================================
{
  const env = load();
  env.listeners.window.keydown(key({ metaKey: true, key: "Enter" }));
  check("⌘⏎ sends the rendered png to Lua", env.sent.length === 1
        && env.sent[0].a === "save"
        && env.sent[0].data === "data:image/png;base64,RENDERED",
        JSON.stringify(env.sent[0]));

  env.sent.length = 0;
  env.listeners.window.keydown(key({ key: "Escape" }));
  check("esc sends cancel", env.sent[0] && env.sent[0].a === "cancel");

  // the toolbar buttons drive the same paths — via their real onclicks
  const onclicks = [...html.matchAll(/onclick="([^"]+)"/g)].map((m) => m[1]);
  check("the toolbar has onclick handlers to drive", onclicks.length >= 3, onclicks.length);
  env.sent.length = 0;
  for (const expr of onclicks) env.call(expr.replace(/&quot;/g, '"').replace(/&amp;/g, "&"));
  const acts = env.sent.map((m) => m.a).sort().join(",");
  check("…and between them they save and cancel", acts.indexOf("save") >= 0
        && acts.indexOf("cancel") >= 0, acts);
}

// =====================================================================
console.log(`\n${pass} passed, ${fail} failed`);
for (const f of failures) console.log("    ❌ " + f);
process.exit(fail === 0 ? 0 : 1);
