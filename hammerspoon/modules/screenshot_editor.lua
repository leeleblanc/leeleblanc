-- =====================================================================
-- MODULE: SCREENSHOT EDITOR — blur boxes, text boxes, arrows
-- =====================================================================
-- Opens a screenshot in a window with THREE TOOLS (buttons, or B/T/A):
--
--   ▦ BLUR   drag a rectangle — it is blurred in place, destructively,
--            for names/emails/tokens that must not travel.
--   🅣 TEXT   click, type, ⏎ — a label in white text with a white
--            outline box (6.88.0, LL's spec). Drag it to move it. To
--            EDIT the words: click it with the Text tool (6.207.0 —
--            a click, not a drag), double-click it with any tool, or
--            select it and press ⏎.
--   ➤ ARROW  drag one out. Drag either END to stretch AND rotate it —
--            the head follows the second endpoint; drag the shaft to
--            move the whole arrow.
--
-- Text and arrows stay LIVE OBJECTS until you save — movable, editable,
-- deletable (⌫ removes the selected one) — and only get painted into
-- the pixels at save time. ⌘Z undoes anything: blurs, adds, moves,
-- edits, deletes, newest first. ⌘⏎ (or the button) saves the result
-- AND puts it on the clipboard; ⌘⇧⏎ saves a SMALL JPEG instead (same
-- sips-style shrink the panel's ⌃⏎ does, done in-page); Esc throws the
-- edits away. The original file is never touched: the result is
-- written NEXT TO it as "… (edited).png" (or ".jpg").
--
-- No hotkey of its own. It is reached from the Screenshots module:
-- the ⇪⇧4 panel opens it after a menu capture, and ⌥⏎ on any history
-- row opens that screenshot for editing. (Service: screenshotEditor.open)
--
-- ---------------------------------------------------------------------
-- HOW THE BLUR ACTUALLY HAPPENS, because Hammerspoon cannot do it
-- ---------------------------------------------------------------------
-- hs.image has no filters — no blur, nothing. But a WKWebView has a
-- full <canvas>, and a canvas gives pixel arrays. So the image travels
-- INTO the page as a data: URI (a WKWebView loaded from an html string
-- has no file access — the Capture Pad learned that in 6.44.x), the
-- blur is a ~40-line box blur written right in the page (three passes
-- ≈ gaussian; ctx.filter would be the built-in way but Safari's canvas
-- support for it is too new to lean on), and the finished PNG travels
-- BACK as a data: URI through the message bridge. A Retina screenshot
-- makes both trips as a multi-megabyte string; that is the cost of the
-- only pixel pipeline available, and it is a beat, not a stall.
--
-- The blur core is a PURE function (boxBlurRGBA) on a flat RGBA array,
-- on purpose: tests/test_editor_js.js executes the real page script in
-- node and drives synthetic pixels through it — the same "run the JS,
-- don't grep it" rule the Capture Pad's suite enforces.
-- =====================================================================

local M = {
    name  = "Screenshot Editor",
    order = 23.5,
    family = "screen",
    cheatsheet = {
        title = "🖌 SCREENSHOT EDITOR (blur · text · arrows — ⇪⇧1)",
        entries = {
            { "open",  "⇪⇧1 opens the newest shot · ⇪⇧5 menu captures too · ⌥⏎ on a history row" },
            { "B T A", "tools: Blur box · Text box · Arrow (buttons too)" },
            { "L O H C", "6.212.0: Line · Oval · Highlighter (translucent yellow box) · Counter (①②③ — a numbered badge per click, ⌘Z takes the last back)" },
            { "text",  "click, type, ⏎ — white text, white outline box · click an EXISTING box (Text tool) to edit its words, or ⏎ on a selected one" },
            { "move",  "drag text/arrows around · arrow ENDS stretch + rotate · a selected text box has a corner dot — drag it to make the text bigger or smaller (⌘Z undoes it)" },
            { "⌫",     "delete the selected note · double-click text re-edits" },
            { "⌘Z",    "undo anything: blur, add, move, edit, delete" },
            { "⌘⏎",   "save “… (edited).png” + clipboard · ⌘⇧⏎ small JPEG" },
            { "esc",   "close without saving — the original is never touched, and the blurs, text and arrows are kept: reopen the SAME shot and they are back" },
        },
    },
}

function M.setup(core)
    local ed = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ed.enabled    = true
    ed.blurRadius = 12     -- box-blur radius in image pixels (Retina = 2x)
    ed.blurPasses = 3      -- 3 box passes ≈ gaussian
    ed.maxUndo    = 20
    ed.jpegQuality = 0.7   -- ⌘⇧⏎ "small JPEG" quality, 0–1
    -- 6.188.0 — LL: the text boxes are hard to grab. A handle was sized in
    -- IMAGE pixels, and the canvas is displayed SCALED DOWN to fit the
    -- window — so on a 4K screenshot in a 1,000 pt window a 35 px handle
    -- was a 9 px target. This is the radius LL's mouse actually sees, in
    -- SCREEN points, and it is converted into image space at hit time.
    ed.handlePx   = 12
    -- 6.189.0 — LL: "I hit escape 2 times and all my screenshot work
    -- wasn't saved as I accidentally hit escape." On the way out the page
    -- hands its state back and it is held HERE, in memory, in ONE slot.
    -- `cv` carries the base image with the blurs BAKED IN and the text /
    -- arrows live on the OVERLAY canvas, so image + notes is the whole of
    -- the work and neither half is drawn twice on the way back in.
    -- ONE slot on purpose — LL: "If I do a second screenshot though, it
    -- will overwrite the prior image, and that's fine."
    ed.keepOnClose = true
    ed.keepMaxBytes = 40 * 1024 * 1024   -- a 4K PNG data URI, with room
    ed.keepMaxNoteBytes = 256 * 1024
    ed.kept = nil    -- { path, img, notes } — never written to disk, never
                     -- survives a reload; this is a safety net, not a store
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("shotEditor", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("shotEditor", m) end end

    -- ---- files -----------------------------------------------------------
    function ed.editedPathFor(path, ext)
        ext = ext or "png"
        local stem = path:gsub("%.%w+$", "")
        local candidate = stem .. " (edited)." .. ext
        local exists
        pcall(function() exists = hs.fs.attributes(candidate, "size") end)
        if not exists then return candidate end
        for n = 2, 99 do
            local p = stem .. (" (edited %d)."):format(n) .. ext
            local e
            pcall(function() e = hs.fs.attributes(p, "size") end)
            if not e then return p end
        end
        return candidate
    end

    local function readFileBase64(path)
        local f = io.open(path, "rb")
        if not f then return nil end
        local bytes = f:read("*a")
        f:close()
        if not bytes or #bytes == 0 then return nil end
        local b64
        pcall(function() b64 = hs.base64.encode(bytes) end)
        -- hs.base64.encode line-wraps its output; a data: URI must be one
        -- unbroken run or WKWebView drops the image without a word.
        if b64 then b64 = b64:gsub("%s+", "") end
        return b64
    end

    -- ---- the page --------------------------------------------------------
    -- Three tools now live here. The BLUR is destructive on the canvas
    -- pixels (undo snapshots them); TEXT and ARROWS are live objects on
    -- an OVERLAY canvas — movable and editable until save, when they are
    -- painted into the pixels once. One undo stack covers all of it.
    -- `keep` is ed.kept when it matches the image being opened, else nil.
    -- Both halves are made safe for injection here, NOT in the page: the
    -- image is refused unless it is a plain base64 PNG data URI (no
    -- quotes, no angle brackets can survive that test) and the notes ride
    -- as base64 so a note containing a quote or a </script> is inert.
    function ed.buildHtml(dataURI, keep)
        local keepImg, keepNotes = "", ""
        if type(keep) == "table" then
            local img = tostring(keep.img or "")
            if img:match("^data:image/png;base64,[A-Za-z0-9+/=]+$") then
                keepImg = img
            end
            local nb
            pcall(function() nb = hs.base64.encode(tostring(keep.notes or "")) end)
            keepNotes = (nb or ""):gsub("%s+", "")
        end
        -- 🎨 6.90.0 — shared card colors (ui_style.lua), cascade-last.
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""
        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:14px; background:#141418; color:#e8e8ec; overflow:hidden; }
  header { padding:8px 12px; display:flex; gap:8px; align-items:center;
           border-bottom:1px solid #2a2a32; user-select:none; -webkit-user-select:none;
           flex-wrap:wrap; }
  h1 { font-size:15px; margin:0 4px 0 0; font-weight:600; }
  .hint { color:#8a8a96; font-size:12px; margin-left:auto; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:6px 12px; font-size:13px; cursor:pointer; }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  button.tool.on { background:#3d3d52; border-color:#7aa0e8; }
  button:hover { filter:brightness(1.18); }
  #stage { position:relative; display:flex; justify-content:center;
           align-items:flex-start; padding:12px; height:calc(100vh - 54px);
           box-sizing:border-box; overflow:auto; }
  #wrap { position:relative; display:inline-block; }
  #cv { display:block; max-width:calc(100vw - 24px); max-height:calc(100vh - 78px);
        box-shadow:0 4px 24px rgba(0,0,0,.5); }
  /* the overlay rides EXACTLY on the displayed canvas — annotations are
     drawn here so they stay movable until save */
  #ov { position:absolute; left:0; top:0; width:100%; height:100%;
        cursor:crosshair; }
  #tin { position:absolute; display:none; z-index:5; min-width:120px;
         background:rgba(20,20,26,.92); color:#fff; border:2px solid #fff;
         border-radius:4px; font-size:15px; padding:4px 8px; outline:none; }
  /* fixed, not absolute: the drag math works in viewport coordinates
     (getBoundingClientRect), and position:fixed is the box that lives
     in exactly that coordinate space */
  #band { position:fixed; border:2px dashed #4a7fe0;
          background:rgba(74,127,224,.15); pointer-events:none; display:none; }
  ]] .. themeCss .. [[
</style>
<header>
  <h1 id="grip" style="cursor:grab" title="drag to move">🖌 Edit</h1>
  <button id="tool-blur" class="tool on" onclick="setTool('blur')" title="B">▦ Blur</button>
  <button id="tool-text" class="tool" onclick="setTool('text')" title="T">🅣 Text</button>
  <button id="tool-arrow" class="tool" onclick="setTool('arrow')" title="A">➤ Arrow</button>
  <button id="tool-line" class="tool" onclick="setTool('line')" title="L">／ Line</button>
  <button id="tool-oval" class="tool" onclick="setTool('oval')" title="O">◯ Oval</button>
  <button id="tool-hl" class="tool" onclick="setTool('hl')" title="H">🖍 Highlight</button>
  <button id="tool-count" class="tool" onclick="setTool('count')" title="C">① Counter</button>
  <button onclick="undoLast()" title="⌘Z">↩︎ Undo</button>
  <button class="go" onclick="saveIt('png')" title="⌘⏎">Save &amp; copy&nbsp;&nbsp;⌘⏎</button>
  <button onclick="saveIt('jpg')" title="⌘⇧⏎">Small JPEG</button>
  <button onclick="stashAndCancel()" title="esc">Cancel</button>
  <span class="hint">saved as “… (edited)” next to the original · ⌫ deletes a note</span>
</header>
<div id="stage">
  <div id="wrap">
    <canvas id="cv"></canvas>
    <canvas id="ov"></canvas>
    <input id="tin" spellcheck="false" placeholder="type, then ⏎">
  </div>
  <div id="band"></div>
</div>
<script>
  var RADIUS = ]] .. tostring(math.floor(ed.blurRadius)) .. [[;
  var PASSES = ]] .. tostring(math.floor(ed.blurPasses)) .. [[;
  var MAXUNDO = ]] .. tostring(math.floor(ed.maxUndo)) .. [[;
  var HANDLEPX = ]] .. tostring(math.floor(tonumber(ed.handlePx) or 12)) .. [[;
  // 6.189.0 — the work carried back in from the last Esc on THIS image.
  // Empty on a first open, and a bad stash must restore nothing rather
  // than break the editor.
  var RESTOREIMG   = ']] .. keepImg .. [[';
  var RESTORENOTES = ']] .. keepNotes .. [[';
  var JPEGQ = ]] .. tostring(ed.jpegQuality) .. [[;

  function say(m){ window.webkit.messageHandlers.shotEditor.postMessage(m || {}); }
  // Leaving is the only moment the work can be handed back, so an
  // in-progress text box is committed first and every read is guarded —
  // a failure here must still CLOSE the editor, just with nothing kept.
  function stashAndCancel(){
    var img = '', nj = '[]';
    try { commitText(); } catch (e) {}
    try { if (cv && cv.toDataURL) img = cv.toDataURL('image/png'); } catch (e) { img = ''; }
    try { nj = JSON.stringify(notes); } catch (e) { nj = '[]'; }
    say({ a: 'cancel', img: img, notes: nj });
  }

  // 6.89.0 — the title is the drag handle (same pattern as the Capture
  // Pad: JS only REPORTS the grab; Lua polls the real mouse, so the drag
  // survives the pointer outrunning the window). Guarded: the node
  // harness's stub DOM has no #grip.
  var grip = document.getElementById('grip');
  if (grip && grip.addEventListener){
    grip.addEventListener('mousedown', function(ev){
      if (ev && ev.preventDefault) ev.preventDefault();
      say({ a: 'dragStart' });
    });
  }

  // ---- THE BLUR CORE — pure, and tested by node against synthetic
  // pixels (tests/test_editor_js.js). px = flat RGBA Uint8ClampedArray.
  function blurLine(px, tmp, start, step, count, radius){
    var win = radius * 2 + 1, r = 0, g = 0, b = 0, a = 0, i, o, t;
    for (i = -radius; i <= radius; i++){
      o = (start + Math.min(count - 1, Math.max(0, i)) * step) * 4;
      r += px[o]; g += px[o+1]; b += px[o+2]; a += px[o+3];
    }
    for (i = 0; i < count; i++){
      t = i * 4;
      tmp[t] = r / win; tmp[t+1] = g / win; tmp[t+2] = b / win; tmp[t+3] = a / win;
      var ao = (start + Math.min(count - 1, i + radius + 1) * step) * 4;
      var so = (start + Math.max(0, i - radius) * step) * 4;
      r += px[ao] - px[so]; g += px[ao+1] - px[so+1];
      b += px[ao+2] - px[so+2]; a += px[ao+3] - px[so+3];
    }
    for (i = 0; i < count; i++){
      o = (start + i * step) * 4; t = i * 4;
      px[o] = tmp[t]; px[o+1] = tmp[t+1]; px[o+2] = tmp[t+2]; px[o+3] = tmp[t+3];
    }
  }
  function boxBlurRGBA(px, w, h, radius, passes){
    if (w < 1 || h < 1 || radius < 1) return;
    var tmp = new Float32Array(Math.max(w, h) * 4), p, x, y;
    for (p = 0; p < passes; p++){
      for (y = 0; y < h; y++) blurLine(px, tmp, y * w, 1, w, radius);
      for (x = 0; x < w; x++) blurLine(px, tmp, x, w, h, radius);
    }
  }

  // ---- wiring (guarded so the node harness can load this script with
  // only a stub DOM and drive the pure core directly) ----
  var cv = document.getElementById('cv');
  var ctx = cv && cv.getContext ? cv.getContext('2d') : null;
  var ov = document.getElementById('ov');
  var octx = ov && ov.getContext ? ov.getContext('2d') : null;
  var band = document.getElementById('band');
  var tin = document.getElementById('tin');

  var tool = 'blur';
  var notes = [];      // {kind:'text',x,y,text,size} | {kind:'arrow'|'line',x1,y1,x2,y2}
                       // | {kind:'oval'|'hl',x,y,w,h} | {kind:'count',x,y,n}   (6.212.0)
  if (RESTORENOTES) {
    try {
      var _b = atob(RESTORENOTES), _a = new Uint8Array(_b.length), _i;
      for (_i = 0; _i < _b.length; _i++) _a[_i] = _b.charCodeAt(_i);
      var _n = JSON.parse(new TextDecoder('utf-8').decode(_a));
      if (_n && _n.length) notes = _n;
    } catch (e) { }   // a stash it cannot read leaves notes empty
  }
  var sel = null;      // the selected note, if any
  var undoStack = [];  // {op:'blur'|'add'|'del'|'set', ...} — one stack for all

  // annotation sizes scale with the IMAGE, not the window — a Retina
  // screenshot gets text you can read once pasted at full size
  function tsize(){ return Math.max(16, Math.round(cv.width / 42)); }
  function lwidth(){ return Math.max(4, Math.round(cv.width / 260)); }
  // 6.188.0 — IMAGE pixels per SCREEN pixel. The canvas is displayed at
  // whatever width fits the window, so on a 4K shot this is around 4:
  // every hit target measured in image pixels is a QUARTER of that on
  // screen. Anything the mouse has to hit goes through here.
  function viewScale(){
    if (!cv || !cv.getBoundingClientRect) return 1;
    var r = cv.getBoundingClientRect();
    if (!r || !r.width) return 1;               // before layout, or hidden
    return cv.width / r.width;
  }
  // the grab radius: never smaller than HANDLEPX points of real screen,
  // and never smaller than the line it belongs to
  function handleR(){
    return Math.max(10, lwidth() * 2.5, HANDLEPX * viewScale());
  }
  // …and never BIGGER than the thing it belongs to. A radius that swallows
  // its own note is the opposite bug and just as real: a short arrow whose
  // two ends are one target, or a small label that can only ever be
  // resized because the corner handle covers the whole box.
  function handleRFor(n){
    var r = handleR();
    if (n.kind === 'arrow' || n.kind === 'line'){
      var len = distPt(n.x1, n.y1, n.x2, n.y2);
      return Math.max(4, Math.min(r, len * 0.35));
    }
    var b = noteBox(n);
    return Math.max(4, Math.min(r, Math.min(b.w, b.h) * 0.45));
  }

  function pushUndo(u){
    undoStack.push(u);
    if (undoStack.length > MAXUNDO) undoStack.shift();
  }

  function setTool(t){
    tool = t;
    var names = ['blur', 'text', 'arrow', 'line', 'oval', 'hl', 'count'], i, b;
    for (i = 0; i < names.length; i++){
      b = document.getElementById('tool-' + names[i]);
      if (b) b.className = 'tool' + (names[i] === t ? ' on' : '');
    }
  }

  function applyBlur(rx, ry, rw, rh){
    rx = Math.max(0, Math.round(rx)); ry = Math.max(0, Math.round(ry));
    rw = Math.min(cv.width - rx, Math.round(rw));
    rh = Math.min(cv.height - ry, Math.round(rh));
    if (rw < 2 || rh < 2) return false;
    pushUndo({ op: 'blur', x: rx, y: ry, w: rw, h: rh,
               data: ctx.getImageData(rx, ry, rw, rh) });
    var patch = ctx.getImageData(rx, ry, rw, rh);
    boxBlurRGBA(patch.data, rw, rh, RADIUS, PASSES);
    ctx.putImageData(patch, rx, ry);
    return true;
  }

  function undoLast(){
    if (!ctx) return;
    commitText();
    var u = undoStack.pop();
    if (!u) return;
    if (u.op === 'blur') ctx.putImageData(u.data, u.x, u.y);
    else if (u.op === 'add'){
      var i = notes.indexOf(u.note);
      if (i >= 0) notes.splice(i, 1);
      if (sel === u.note) sel = null;
    }
    else if (u.op === 'del') notes.splice(Math.min(u.index, notes.length), 0, u.note);
    else if (u.op === 'set'){ for (var k in u.before) u.note[k] = u.before[k]; }
    redraw();
  }

  // ---- annotations: geometry, drawing, hit-testing ----
  function setFont(g, n){
    g.font = n.size + 'px -apple-system, BlinkMacSystemFont, sans-serif';
  }
  // 6.212.0 — the counter badge's radius scales with the image like the
  // text does, so a "①" pasted at full size is readable
  function countR(){ return Math.max(12, Math.round(tsize() * 0.9)); }
  function nextCount(){
    var m = 0;
    for (var i = 0; i < notes.length; i++)
      if (notes[i].kind === 'count' && notes[i].n > m) m = notes[i].n;
    return m + 1;   // one past the HIGHEST, so a deleted ② never comes back as a second ③
  }
  function noteBox(n){
    if (n.kind === 'arrow' || n.kind === 'line'){
      return { x: Math.min(n.x1, n.x2), y: Math.min(n.y1, n.y2),
               w: Math.abs(n.x2 - n.x1), h: Math.abs(n.y2 - n.y1) };
    }
    if (n.kind === 'oval' || n.kind === 'hl') return { x: n.x, y: n.y, w: n.w, h: n.h };
    if (n.kind === 'count'){
      var cr = countR();
      return { x: n.x - cr, y: n.y - cr, w: cr * 2, h: cr * 2 };
    }
    var g = octx || ctx, w = (n.text || ' ').length * n.size * 0.6;
    if (g && g.measureText){
      setFont(g, n);
      var m = g.measureText(n.text || ' ');
      if (m && m.width) w = m.width;
    }
    var pad = Math.round(n.size * 0.5);
    return { x: n.x - pad, y: n.y - n.size - pad, w: w + pad * 2, h: n.size + pad * 2 };
  }
  // LL's spec, verbatim: "white text and white outline". A soft dark
  // shadow under both keeps white readable on a white screenshot.
  function drawNote(g, n, isSel){
    g.save();
    g.shadowColor = 'rgba(0,0,0,0.55)';
    g.shadowBlur = Math.max(3, lwidth());
    g.strokeStyle = '#ffffff'; g.fillStyle = '#ffffff';
    if (n.kind === 'line'){
      // 6.212.0 — an arrow without its head
      g.lineWidth = lwidth(); g.lineCap = 'round';
      g.beginPath(); g.moveTo(n.x1, n.y1); g.lineTo(n.x2, n.y2); g.stroke();
    } else if (n.kind === 'oval'){
      // 6.212.0 — a white ring around the thing; ellipse where the
      // canvas has it, a circle of the longer side where it does not
      g.lineWidth = lwidth();
      g.beginPath();
      var cx = n.x + n.w / 2, cy = n.y + n.h / 2;
      if (g.ellipse) g.ellipse(cx, cy, Math.max(1, n.w / 2), Math.max(1, n.h / 2), 0, 0, 6.2832);
      else g.arc(cx, cy, Math.max(1, Math.max(n.w, n.h) / 2), 0, 6.2832);
      g.stroke();
    } else if (n.kind === 'hl'){
      // 6.212.0 — a translucent yellow box, NO shadow (a shadow under a
      // translucent fill reads as a smudge)
      g.shadowBlur = 0; g.shadowColor = 'rgba(0,0,0,0)';
      g.fillStyle = 'rgba(255,230,0,0.38)';
      g.fillRect(n.x, n.y, n.w, n.h);
    } else if (n.kind === 'count'){
      // 6.212.0 — a white disc with the number in dark ink
      var cr = countR();
      g.beginPath(); g.arc(n.x, n.y, cr, 0, 6.2832); g.fill();
      g.shadowBlur = 0;
      g.fillStyle = '#1b2a4a';
      g.font = Math.round(cr * 1.2) + 'px -apple-system, BlinkMacSystemFont, sans-serif';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(String(n.n), n.x, n.y);
    } else if (n.kind === 'arrow'){
      var dx = n.x2 - n.x1, dy = n.y2 - n.y1;
      var len = Math.sqrt(dx * dx + dy * dy) || 1;
      var ux = dx / len, uy = dy / len;
      var hl = Math.max(10, lwidth() * 3);           // arrowhead length
      var bx = n.x2 - ux * hl, by = n.y2 - uy * hl;  // head base
      g.lineWidth = lwidth(); g.lineCap = 'round';
      g.beginPath(); g.moveTo(n.x1, n.y1); g.lineTo(bx, by); g.stroke();
      g.beginPath();
      g.moveTo(n.x2, n.y2);
      g.lineTo(bx - uy * hl * 0.5, by + ux * hl * 0.5);
      g.lineTo(bx + uy * hl * 0.5, by - ux * hl * 0.5);
      g.closePath(); g.fill();
    } else {
      setFont(g, n);
      g.textBaseline = 'alphabetic';
      var b = noteBox(n);
      g.lineWidth = Math.max(2, Math.round(n.size / 8));
      g.strokeRect(b.x, b.y, b.w, b.h);
      g.fillText(n.text || '', n.x, n.y);
    }
    if (isSel){
      var bb = noteBox(n);
      g.shadowBlur = 0;
      g.strokeStyle = 'rgba(116,168,255,0.95)'; g.lineWidth = 1;
      if (g.setLineDash) g.setLineDash([4, 3]);
      g.strokeRect(bb.x - 4, bb.y - 4, bb.w + 8, bb.h + 8);
      if (g.setLineDash) g.setLineDash([]);
      // 6.188.0 — DRAWN THE SIZE THEY ARE HIT. They used to be drawn at
      // 0.6× the grab radius, which teaches the eye to aim at a dot
      // smaller than the target and reads as "it did not take".
      if (g.arc){
        g.fillStyle = 'rgba(116,168,255,0.95)';
        g.strokeStyle = 'rgba(10,14,26,0.85)';
        g.lineWidth = Math.max(1, handleR() * 0.12);
        var hr = handleRFor(n);
        var dot = function(x, y){
          g.beginPath(); g.arc(x, y, hr, 0, 6.2832); g.fill(); g.stroke();
        };
        if (n.kind === 'arrow' || n.kind === 'line'){ dot(n.x1, n.y1); dot(n.x2, n.y2); }
        else if (n.kind !== 'count'){ dot(bb.x + bb.w, bb.y + bb.h); }   // the resize corner (text, oval, highlight)
      }
    }
    g.restore();
  }
  function redraw(){
    if (!octx) return;
    octx.clearRect(0, 0, ov.width, ov.height);
    for (var i = 0; i < notes.length; i++) drawNote(octx, notes[i], notes[i] === sel);
  }

  function distPt(ax, ay, bx, by){
    var dx = ax - bx, dy = ay - by;
    return Math.sqrt(dx * dx + dy * dy);
  }
  function segDist(p, n){
    var dx = n.x2 - n.x1, dy = n.y2 - n.y1;
    var ll = dx * dx + dy * dy;
    if (ll < 1) return distPt(p.x, p.y, n.x1, n.y1);
    var t = ((p.x - n.x1) * dx + (p.y - n.y1) * dy) / ll;
    t = Math.max(0, Math.min(1, t));
    return distPt(p.x, p.y, n.x1 + t * dx, n.y1 + t * dy);
  }
  // topmost first: later notes sit on top, so scan backwards. Arrow
  // ENDPOINTS win over the shaft — grabbing an end stretches/rotates.
  function hitAt(p){
    for (var i = notes.length - 1; i >= 0; i--){
      var n = notes[i];
      if (n.kind === 'count'){
        // 6.212.0 — the badge moves as a whole; no handle to resize
        if (distPt(p.x, p.y, n.x, n.y) <= countR() + handleR() * 0.5) return { note: n, part: 'move' };
        continue;
      }
      if (n.kind === 'arrow' || n.kind === 'line'){
        var hr = handleRFor(n);
        if (distPt(p.x, p.y, n.x1, n.y1) <= hr) return { note: n, part: 'p1' };
        if (distPt(p.x, p.y, n.x2, n.y2) <= hr) return { note: n, part: 'p2' };
        if (segDist(p, n) <= handleR()) return { note: n, part: 'move' };
      } else {
        var b = noteBox(n);
        // 6.188.0 — the SIZE handle, bottom-right, checked before the box
        // so a small note is still resizable rather than only movable
        if (distPt(p.x, p.y, b.x + b.w, b.y + b.h) <= handleRFor(n))
          return { note: n, part: 'size' };
        // …and the box itself is grown to the handle radius, so a one-word
        // label on a 4K shot is a target rather than a dare
        var pad = handleR() * 0.5;
        if (p.x >= b.x - pad && p.x <= b.x + b.w + pad
            && p.y >= b.y - pad && p.y <= b.y + b.h + pad)
          return { note: n, part: 'move' };
      }
    }
    return null;
  }
  function snapNote(n){
    // 6.188.0 — `size` rides along for a text note, so ⌘Z undoes a resize
    // through the same generic 'set' op a move already used
    // 6.212.0 — every numeric field, whatever the kind: x/y/size for
    // text, the two ends of an arrow or line, x/y/w/h of an oval or a
    // highlight, x/y/n of a counter
    var o = {}, k;
    for (k in n) if (typeof n[k] === 'number') o[k] = n[k];
    return o;
  }

  // ---- the floating text input ----
  var editingNote = null, pendingPt = null;
  function textOpen(){ return tin && tin.style.display === 'block'; }
  function startText(note, p){
    commitText();
    editingNote = note || null;
    pendingPt = note ? null : p;
    var at = note ? { x: note.x, y: note.y - tsize() } : p;
    var r = cv.getBoundingClientRect();
    tin.style.left = Math.round(at.x * (r.width / cv.width)) + 'px';
    tin.style.top  = Math.round(at.y * (r.height / cv.height)) + 'px';
    tin.value = note ? (note.text || '') : '';
    tin.style.display = 'block';
    if (tin.focus) tin.focus();
  }
  function commitText(){
    if (!textOpen()) return;
    tin.style.display = 'none';
    var v = (tin.value || '').replace(/^\s+|\s+$/g, '');
    if (editingNote){
      if (v === ''){
        var i = notes.indexOf(editingNote);
        if (i >= 0){ pushUndo({ op: 'del', note: editingNote, index: i }); notes.splice(i, 1); }
        if (sel === editingNote) sel = null;
      } else if (v !== editingNote.text){
        pushUndo({ op: 'set', note: editingNote, before: { text: editingNote.text } });
        editingNote.text = v;
      }
    } else if (v !== '' && pendingPt){
      var n = { kind: 'text', x: pendingPt.x, y: pendingPt.y, text: v, size: tsize() };
      notes.push(n); sel = n;
      pushUndo({ op: 'add', note: n });
    }
    editingNote = null; pendingPt = null;
    redraw();
  }
  function cancelText(){
    if (!textOpen()) return;
    tin.style.display = 'none';
    editingNote = null; pendingPt = null;
  }

  // save: paint the notes into the pixels ONCE, render, then put the
  // clean pixels straight back — the notes stay editable if Lua ever
  // refuses the save and the editor stays open
  function saveIt(fmt){
    if (!ctx) return;
    commitText();
    var keep = ctx.getImageData(0, 0, cv.width, cv.height);
    for (var i = 0; i < notes.length; i++) drawNote(ctx, notes[i], false);
    var url = fmt === 'jpg' ? cv.toDataURL('image/jpeg', JPEGQ)
                            : cv.toDataURL('image/png');
    ctx.putImageData(keep, 0, 0);
    say({ a: 'save', data: url, ext: fmt === 'jpg' ? 'jpg' : 'png' });
  }

  if (ctx) {
    var img = new Image();
    img.onload = function(){
      cv.width = img.naturalWidth; cv.height = img.naturalHeight;
      if (ov){ ov.width = cv.width; ov.height = cv.height; }
      ctx.drawImage(img, 0, 0);
      redraw();            // 6.189.0 — restored notes, if any
    };
    img.src = RESTOREIMG || ']] .. dataURI .. [[';

    // displayed size ≠ pixel size (CSS scales the canvas to fit), so
    // every mouse point is mapped through the live scale factor
    var drag = null, sx = 0, sy = 0;
    function toCanvas(e){
      var r = cv.getBoundingClientRect();
      return { x: (e.clientX - r.left) * (cv.width  / r.width),
               y: (e.clientY - r.top)  * (cv.height / r.height) };
    }
    var surface = ov || cv;   // the overlay sits on top and gets the mouse
    surface.addEventListener('mousedown', function(e){
      if (e.button !== 0) return;
      e.preventDefault();
      if (textOpen()){ commitText(); return; }   // click-away commits
      var p = toCanvas(e);
      var hit = hitAt(p);
      if (hit){
        sel = hit.note;
        drag = { mode: (hit.part === 'move' || hit.part === 'size') ? hit.part : 'end',
                 note: hit.note, part: hit.part, sx: p.x, sy: p.y,
                 before: snapNote(hit.note),
                 // 6.207.0 — LL: "I can't edit an existing text box. If I
                 // click on the text box, a new one is created instead."
                 // With the Text tool a CLICK on a text box (press and
                 // release without moving) opens it for editing; a drag
                 // still moves it. Decided on mouseup, where the two can be
                 // told apart. Screen coordinates, so a 4K shot in a small
                 // window does not turn a steady hand into a "drag".
                 clickEdit: (tool === 'text' && hit.note.kind === 'text'),
                 cx: e.clientX, cy: e.clientY, moved: false };
        redraw();
        return;
      }
      if (tool === 'text'){ sel = null; redraw(); startText(null, p); return; }
      if (tool === 'arrow' || tool === 'line'){
        var n = { kind: tool, x1: p.x, y1: p.y, x2: p.x, y2: p.y };
        notes.push(n); sel = n;
        drag = { mode: 'end', note: n, part: 'p2', fresh: true };
        redraw();
        return;
      }
      // 6.212.0 — a box drawn from the press to the release, in any
      // direction: the corner drag normalises x/y/w/h as it goes
      if (tool === 'oval' || tool === 'hl'){
        var nb = { kind: tool, x: p.x, y: p.y, w: 0, h: 0 };
        notes.push(nb); sel = nb;
        drag = { mode: 'corner', note: nb, fresh: true, ox: p.x, oy: p.y };
        redraw();
        return;
      }
      // 6.212.0 — one click, one badge, the next number
      if (tool === 'count'){
        var nc = { kind: 'count', x: p.x, y: p.y, n: nextCount() };
        notes.push(nc); sel = nc;
        pushUndo({ op: 'add', note: nc });
        redraw();
        return;
      }
      if (sel){ sel = null; redraw(); }
      drag = { mode: 'band' }; sx = p.x; sy = p.y;
      band.style.display = 'block';
    });
    window.addEventListener('mousemove', function(e){
      if (!drag) return;
      if (drag.mode === 'band'){
        var r = cv.getBoundingClientRect();
        // the band is drawn in SCREEN space, anchor to pointer
        var ax = sx * (r.width / cv.width) + r.left;
        var ay = sy * (r.height / cv.height) + r.top;
        band.style.left   = Math.min(ax, e.clientX) + 'px';
        band.style.top    = Math.min(ay, e.clientY) + 'px';
        band.style.width  = Math.abs(e.clientX - ax) + 'px';
        band.style.height = Math.abs(e.clientY - ay) + 'px';
        return;
      }
      var p = toCanvas(e), n = drag.note;
      if (Math.abs(e.clientX - drag.cx) > 3 || Math.abs(e.clientY - drag.cy) > 3) drag.moved = true;
      // a click that wobbles a pixel is still a click: nothing moves until
      // the hand has really moved, so the words open instead of shifting
      if (drag.clickEdit && !drag.moved) return;
      if (drag.mode === 'move'){
        var dx = p.x - drag.sx, dy = p.y - drag.sy;
        if (n.kind === 'arrow'){
          n.x1 = drag.before.x1 + dx; n.y1 = drag.before.y1 + dy;
          n.x2 = drag.before.x2 + dx; n.y2 = drag.before.y2 + dy;
        } else { n.x = drag.before.x + dx; n.y = drag.before.y + dy; }
      } else if (drag.mode === 'corner'){
        n.x = Math.min(drag.ox, p.x); n.y = Math.min(drag.oy, p.y);
        n.w = Math.abs(p.x - drag.ox); n.h = Math.abs(p.y - drag.oy);
      } else if (drag.mode === 'size'){
        if (n.kind === 'oval' || n.kind === 'hl'){
          // 6.212.0 — the bottom-right corner follows the pointer; the
          // top-left stays put
          n.w = Math.max(4, Math.round(drag.before.w + (p.x - drag.sx)));
          n.h = Math.max(4, Math.round(drag.before.h + (p.y - drag.sy)));
        } else {
          // 6.188.0 — drag the corner away from the note to grow it. The
          // anchor (n.x, n.y) does not move, so the text grows where it is
          // rather than wandering off under the pointer.
          var d2 = ((p.x - drag.sx) + (p.y - drag.sy)) / 2;
          n.size = Math.max(10, Math.min(600, Math.round(drag.before.size + d2)));
        }
      } else {   // 'end' — one endpoint follows the mouse: stretch + rotate
        if (drag.part === 'p1'){ n.x1 = p.x; n.y1 = p.y; }
        else { n.x2 = p.x; n.y2 = p.y; }
      }
      redraw();
    });
    window.addEventListener('mouseup', function(e){
      if (!drag) return;
      var d = drag; drag = null;
      if (d.mode === 'band'){
        band.style.display = 'none';
        var p = toCanvas(e);
        applyBlur(Math.min(sx, p.x), Math.min(sy, p.y),
                  Math.abs(p.x - sx), Math.abs(p.y - sy));
        return;
      }
      var n = d.note;
      if (d.fresh){
        var tiny = (n.kind === 'oval' || n.kind === 'hl') ? (n.w < 4 || n.h < 4)
                                                          : distPt(n.x1, n.y1, n.x2, n.y2) < 6;
        if (tiny){
          notes.splice(notes.indexOf(n), 1);   // a click, not a shape
          if (sel === n) sel = null;
        } else pushUndo({ op: 'add', note: n });
      } else {
        var changed = false, k;
        for (k in d.before){ if (d.before[k] !== n[k]){ changed = true; break; } }
        if (changed) pushUndo({ op: 'set', note: n, before: d.before });
        // 6.207.0 — a click, not a drag, on a text box with the Text tool:
        // open the words for editing right here
        if (d.clickEdit && !d.moved && !changed){ redraw(); startText(n); return; }
      }
      redraw();
    });
    surface.addEventListener('dblclick', function(e){
      e.preventDefault();
      var hit = hitAt(toCanvas(e));
      if (hit && hit.note.kind === 'text'){ sel = hit.note; startText(hit.note); }
    });

    if (tin && tin.addEventListener) tin.addEventListener('keydown', function(e){
      if (e.stopPropagation) e.stopPropagation();
      if (e.key === 'Enter'){ e.preventDefault(); commitText(); }
      else if (e.key === 'Escape'){ e.preventDefault(); cancelText(); }
    });

    window.addEventListener('keydown', function(e){
      if (textOpen()) return;   // the input's own handler owns the keys
      if (e.key === 'Escape') { e.preventDefault(); stashAndCancel(); }
      else if (e.metaKey && e.key === 'Enter') {
        e.preventDefault(); saveIt(e.shiftKey ? 'jpg' : 'png');
      }
      else if (e.metaKey && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault(); undoLast();
      }
      // 6.207.0 — ⏎ on a selected text box edits it (⌘⏎ is still save)
      else if (e.key === 'Enter' && !e.metaKey && sel && sel.kind === 'text') {
        e.preventDefault(); startText(sel);
      }
      else if ((e.key === 'Backspace' || e.key === 'Delete') && sel) {
        e.preventDefault();
        var i = notes.indexOf(sel);
        if (i >= 0){ pushUndo({ op: 'del', note: sel, index: i }); notes.splice(i, 1); }
        sel = null; redraw();
      }
      else if (!e.metaKey && !e.ctrlKey && !e.altKey) {
        if (e.key === 'b' || e.key === 'B') setTool('blur');
        else if (e.key === 't' || e.key === 'T') setTool('text');
        else if (e.key === 'a' || e.key === 'A') setTool('arrow');
        else if (e.key === 'l' || e.key === 'L') setTool('line');
        else if (e.key === 'o' || e.key === 'O') setTool('oval');
        else if (e.key === 'h' || e.key === 'H') setTool('hl');
        else if (e.key === 'c' || e.key === 'C') setTool('count');
      }
    });
  }
</script>
]]
    end

    -- ---- keeping the work across a close ---------------------------------
    -- Returns ok, why — it never throws and it never half-fills the slot:
    -- anything refused leaves ed.kept nil, so a later open restores the
    -- FILE rather than a fragment of an old session.
    function ed.rememberWork(path, img, notesJson)
        ed.kept = nil
        if not ed.keepOnClose then return false, "keeping is switched off" end
        if type(path) ~= "string" or path == "" then return false, "no image path" end
        img       = (type(img) == "string") and img or ""
        notesJson = (type(notesJson) == "string") and notesJson or ""
        -- The pattern is the whole of the safety check for the injection
        -- in buildHtml as well — keep the two in step.
        if not img:match("^data:image/png;base64,[A-Za-z0-9+/=]+$") then
            return false, "the page sent no usable image"
        end
        if #img > (tonumber(ed.keepMaxBytes) or 0) then
            return false, "the image is larger than the keep budget"
        end
        -- Notes are the cheap half and the blurs are already in the image,
        -- so an oversized notes payload costs the annotations, never the
        -- whole rescue.
        if notesJson == "" or #notesJson > (tonumber(ed.keepMaxNoteBytes) or 0) then
            notesJson = "[]"
        end
        ed.kept = { path = path, img = img, notes = notesJson }
        return true
    end

    -- ---- messages from the page ------------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        if body.a == "save" then
            local data = tostring(body.data or "")
            -- png from ⌘⏎, jpeg from the "Small JPEG" path (6.88.0) —
            -- anything else is a malformed payload, refused before write
            local mime, b64 = data:match("^data:image/(%w+);base64,(.+)$")
            if not b64 or (mime ~= "png" and mime ~= "jpeg") then
                pcall(function() hs.alert.show("🖌 Save failed — bad image data", 3) end)
                warn("save message without a png/jpeg data URI")
                return
            end
            local ext = (mime == "jpeg") and "jpg" or "png"
            local bytes
            pcall(function() bytes = hs.base64.decode(b64) end)
            if not bytes or #bytes == 0 then
                pcall(function() hs.alert.show("🖌 Save failed — could not decode", 3) end)
                return
            end
            local outPath = ed.editedPathFor(ed.currentPath or ("screenshot." .. ext),
                                             ext)
            local f = io.open(outPath, "wb")
            if not f then
                pcall(function() hs.alert.show("🖌 Could not write " .. outPath, 4) end)
                return
            end
            f:write(bytes)
            f:close()
            -- 6.170.3: the copy runs off the main thread (screenshots'
            -- osascript task) when that module is here; the old sync
            -- decode + writeObjects stays as the fallback.
            local function tell(copied)
                pcall(function()
                    hs.alert.show(copied and "🖌 Saved (edited) · on the clipboard"
                                          or "🖌 Saved (edited) — clipboard copy failed", 2.5)
                end)
            end
            if core.has and core.has("screenshots.copyToPasteboard") then
                core.call("screenshots.copyToPasteboard", outPath, tell)
            else
                local copied = false
                pcall(function()
                    local img = hs.image.imageFromPath(outPath)
                    if img then copied = hs.pasteboard.writeObjects(img) and true end
                end)
                tell(copied)
            end
            say("saved " .. (outPath:match("[^/]+$") or outPath))
            ed.kept = nil   -- saved work is not lost work; a slot left
                            -- standing here would restore a STALE state
                            -- over the next open of the same shot
            ed.close()
        elseif body.a == "cancel" then
            local okKeep, whyKeep = ed.rememberWork(ed.currentPath, body.img,
                                                    body.notes)
            say(okKeep and "work kept for the next open of this shot"
                       or ("nothing kept — " .. tostring(whyKeep)))
            ed.close()
        elseif body.a == "dragStart" then
            -- 6.89.0 — the title-bar grab; Window Move drives the drag
            if _G.beginPanelDrag then _G.beginPanelDrag("screenshot editor") end
        end
    end

    -- ---- window ----------------------------------------------------------
    function ed.close()
        if ed.webview then
            pcall(function() ed.webview:delete() end)
            ed.webview = nil
        end
        ed.uc, ed.currentPath = nil, nil
    end

    function ed.open(path)
        if type(path) ~= "string" or path == "" then return false end
        ed.close()
        if not (hs.webview and hs.webview.usercontent) then
            pcall(function() hs.alert.show("🖌 Editor needs WKWebView — not available", 3) end)
            return false
        end
        local b64 = readFileBase64(path)
        if not b64 then
            pcall(function() hs.alert.show("🖌 Could not read " .. path, 3) end)
            return false
        end

        -- size the window to the image, capped to the screen
        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or (hs.screen and hs.screen.mainScreen and hs.screen.mainScreen())
        local sf = { x = 0, y = 0, w = 1440, h = 900 }
        pcall(function() if screen then sf = screen:frame() end end)
        local imgW, imgH = 900, 600
        pcall(function()
            local img = hs.image.imageFromPath(path)
            local sz = img and img:size()
            if sz and sz.w > 0 then imgW, imgH = sz.w, sz.h end
        end)
        local maxW, maxH = sf.w * 0.85, sf.h * 0.85
        local scale = math.min(1, maxW / imgW, (maxH - 60) / imgH)
        local w = math.max(720, math.floor(imgW * scale) + 28)
        local h = math.max(320, math.floor(imgH * scale) + 82)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2,
                       w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "shotEditor")
        if not (okUc and uc) then return false end
        ed.uc = uc    -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then warn("message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then ed.uc = nil return false end
        ed.webview, ed.currentPath = view, path
        pcall(function() view:windowTitle("Blur — " .. (path:match("[^/]+$") or path)) end)
        pcall(function() view:allowTextEntry(true) end)   -- ⌘Z/⌘⏎ need key status
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        -- The slot is keyed by path, so a different screenshot simply does
        -- not match and opens clean — no clearing, no staleness.
        local keep = (ed.kept and ed.kept.path == path) and ed.kept or nil
        pcall(function()
            view:html(ed.buildHtml("data:image/png;base64," .. b64, keep))
        end)
        if keep then
            pcall(function()
                hs.alert.show("🖌 Your last edits on this shot are back", 2)
            end)
            say("restored the work kept from the last close")
        end
        pcall(function() view:show() end)
        pcall(function() view:bringToFront(true) end)
        say("editing " .. (path:match("[^/]+$") or path))
        return true
    end

    -- ---- wiring ----------------------------------------------------------
    core.provide("screenshotEditor.open", function(p) return ed.open(p) end)

    -- 6.89.0 — listed for Window Move: ⌘-drag anywhere on the editor moves
    -- it (a bare drag would fight the drawing tools), and the title grip
    -- above gives the bare-click drag where it is safe.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "screenshot editor",
        frame = function() return ed.webview and ed.webview:frame() end,
        move  = function(x, y)
            local f = ed.webview and ed.webview:frame()
            if f then ed.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    -- 🗂 6.116.0 — listed for the ⌘⌘ editor picker, and DELIBERATELY WITH
    -- NO `show`. This editor edits an image you have to have taken first;
    -- there is no cold-open of it, so the row exists to bring an editor
    -- that is already up back to the front — which is exactly the case
    -- where it is hardest to find, buried under whatever you took a
    -- screenshot OF. With the window closed the row says so and does
    -- nothing, which is honest; a `show` that opened an empty editor
    -- would not be.
    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "Screenshot Editor",
        key   = "⇪⇧1",
        what  = "only listed while one is open",
        order = 60,
        view  = function() return ed.webview end,
    })

    -- ⎋ 6.93.0 — in the escape router, so the cheat sheet closes AFTER the
    -- editor (its page keeps first claim on Esc for cancelling a text box).
    if _G.claimEscape then
        _G.claimEscape("shoteditor", nil,
            function() return ed.webview ~= nil end,
            function() ed.close() end)
    end

    _G.screenshotEditor = ed
    M.editor = ed
    M.config = ed
end

return M
