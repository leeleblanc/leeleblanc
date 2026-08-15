-- =====================================================================
-- MODULE: SCREENSHOT EDITOR — blur boxes, text boxes, arrows
-- =====================================================================
-- Opens a screenshot in a window with THREE TOOLS (buttons, or B/T/A):
--
--   ▦ BLUR   drag a rectangle — it is blurred in place, destructively,
--            for names/emails/tokens that must not travel.
--   🅣 TEXT   click, type, ⏎ — a label in white text with a white
--            outline box (6.88.0, LL's spec). Drag it to move it;
--            double-click to re-edit the words.
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
    cheatsheet = {
        title = "🖌 SCREENSHOT EDITOR (blur · text · arrows — via ⇪⇧4)",
        entries = {
            { "open",  "⇪⇧4 menu captures open it · ⌥⏎ on a history row" },
            { "B T A", "tools: Blur box · Text box · Arrow (buttons too)" },
            { "text",  "click, type, ⏎ — white text, white outline box" },
            { "move",  "drag text/arrows around · arrow ENDS stretch + rotate" },
            { "⌫",     "delete the selected note · double-click text re-edits" },
            { "⌘Z",    "undo anything: blur, add, move, edit, delete" },
            { "⌘⏎",   "save “… (edited).png” + clipboard · ⌘⇧⏎ small JPEG" },
            { "esc",   "close without saving — the original is never touched" },
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
    function ed.buildHtml(dataURI)
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
</style>
<header>
  <h1 id="grip" style="cursor:grab" title="drag to move">🖌 Edit</h1>
  <button id="tool-blur" class="tool on" onclick="setTool('blur')" title="B">▦ Blur</button>
  <button id="tool-text" class="tool" onclick="setTool('text')" title="T">🅣 Text</button>
  <button id="tool-arrow" class="tool" onclick="setTool('arrow')" title="A">➤ Arrow</button>
  <button onclick="undoLast()" title="⌘Z">↩︎ Undo</button>
  <button class="go" onclick="saveIt('png')" title="⌘⏎">Save &amp; copy&nbsp;&nbsp;⌘⏎</button>
  <button onclick="saveIt('jpg')" title="⌘⇧⏎">Small JPEG</button>
  <button onclick="say({a:'cancel'})" title="esc">Cancel</button>
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
  var JPEGQ = ]] .. tostring(ed.jpegQuality) .. [[;

  function say(m){ window.webkit.messageHandlers.shotEditor.postMessage(m || {}); }

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
  var notes = [];      // {kind:'text',x,y,text,size} | {kind:'arrow',x1,y1,x2,y2}
  var sel = null;      // the selected note, if any
  var undoStack = [];  // {op:'blur'|'add'|'del'|'set', ...} — one stack for all

  // annotation sizes scale with the IMAGE, not the window — a Retina
  // screenshot gets text you can read once pasted at full size
  function tsize(){ return Math.max(16, Math.round(cv.width / 42)); }
  function lwidth(){ return Math.max(4, Math.round(cv.width / 260)); }
  function handleR(){ return Math.max(10, lwidth() * 2.5); }

  function pushUndo(u){
    undoStack.push(u);
    if (undoStack.length > MAXUNDO) undoStack.shift();
  }

  function setTool(t){
    tool = t;
    var names = ['blur', 'text', 'arrow'], i, b;
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
  function noteBox(n){
    if (n.kind === 'arrow'){
      return { x: Math.min(n.x1, n.x2), y: Math.min(n.y1, n.y2),
               w: Math.abs(n.x2 - n.x1), h: Math.abs(n.y2 - n.y1) };
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
    if (n.kind === 'arrow'){
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
      if (n.kind === 'arrow' && g.arc){
        g.fillStyle = 'rgba(116,168,255,0.95)';
        g.beginPath(); g.arc(n.x1, n.y1, handleR() * 0.6, 0, 6.2832); g.fill();
        g.beginPath(); g.arc(n.x2, n.y2, handleR() * 0.6, 0, 6.2832); g.fill();
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
      if (n.kind === 'arrow'){
        if (distPt(p.x, p.y, n.x1, n.y1) <= handleR()) return { note: n, part: 'p1' };
        if (distPt(p.x, p.y, n.x2, n.y2) <= handleR()) return { note: n, part: 'p2' };
        if (segDist(p, n) <= handleR()) return { note: n, part: 'move' };
      } else {
        var b = noteBox(n);
        if (p.x >= b.x && p.x <= b.x + b.w && p.y >= b.y && p.y <= b.y + b.h)
          return { note: n, part: 'move' };
      }
    }
    return null;
  }
  function snapNote(n){
    return n.kind === 'arrow' ? { x1: n.x1, y1: n.y1, x2: n.x2, y2: n.y2 }
                              : { x: n.x, y: n.y };
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
    };
    img.src = ']] .. dataURI .. [[';

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
        drag = { mode: hit.part === 'move' ? 'move' : 'end', note: hit.note,
                 part: hit.part, sx: p.x, sy: p.y, before: snapNote(hit.note) };
        redraw();
        return;
      }
      if (tool === 'text'){ sel = null; redraw(); startText(null, p); return; }
      if (tool === 'arrow'){
        var n = { kind: 'arrow', x1: p.x, y1: p.y, x2: p.x, y2: p.y };
        notes.push(n); sel = n;
        drag = { mode: 'end', note: n, part: 'p2', fresh: true };
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
      if (drag.mode === 'move'){
        var dx = p.x - drag.sx, dy = p.y - drag.sy;
        if (n.kind === 'arrow'){
          n.x1 = drag.before.x1 + dx; n.y1 = drag.before.y1 + dy;
          n.x2 = drag.before.x2 + dx; n.y2 = drag.before.y2 + dy;
        } else { n.x = drag.before.x + dx; n.y = drag.before.y + dy; }
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
        if (distPt(n.x1, n.y1, n.x2, n.y2) < 6){
          notes.splice(notes.indexOf(n), 1);   // a click, not an arrow
          if (sel === n) sel = null;
        } else pushUndo({ op: 'add', note: n });
      } else {
        var changed = false, k;
        for (k in d.before){ if (d.before[k] !== n[k]){ changed = true; break; } }
        if (changed) pushUndo({ op: 'set', note: n, before: d.before });
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
      if (e.key === 'Escape') { e.preventDefault(); say({a:'cancel'}); }
      else if (e.metaKey && e.key === 'Enter') {
        e.preventDefault(); saveIt(e.shiftKey ? 'jpg' : 'png');
      }
      else if (e.metaKey && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault(); undoLast();
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
      }
    });
  }
</script>
]]
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
            local copied = false
            pcall(function()
                local img = hs.image.imageFromPath(outPath)
                if img then copied = hs.pasteboard.writeObjects(img) and true end
            end)
            pcall(function()
                hs.alert.show(copied and "🖌 Saved (edited) · on the clipboard"
                                      or "🖌 Saved (edited) — clipboard copy failed", 2.5)
            end)
            say("saved " .. (outPath:match("[^/]+$") or outPath))
            ed.close()
        elseif body.a == "cancel" then
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
        pcall(function() view:html(ed.buildHtml("data:image/png;base64," .. b64)) end)
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

    _G.screenshotEditor = ed
    M.editor = ed
    M.config = ed
end

return M
