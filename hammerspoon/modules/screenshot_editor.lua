-- =====================================================================
-- MODULE: SCREENSHOT EDITOR — drag a box, the box gets blurred
-- =====================================================================
-- Opens a screenshot in a window; every rectangle you DRAG with the
-- mouse is blurred in place — names, emails, tokens, whatever should
-- not travel with the image. ⌘Z un-blurs the last box, ⌘⏎ (or the
-- button) saves the result AND puts it on the clipboard, Esc throws
-- the edits away. The original file is never touched: the result is
-- written NEXT TO it as "… (edited).png".
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
        title = "🖌 SCREENSHOT EDITOR (blur boxes — no key; via ⇪⇧4)",
        entries = {
            { "open",  "⇪⇧4 menu captures open it · ⌥⏎ on a history row" },
            { "drag",  "draw a box — the box is blurred in place" },
            { "⌘Z",    "un-blur the last box" },
            { "⌘⏎",   "save as “… (edited).png” AND copy to clipboard" },
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
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("shotEditor", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("shotEditor", m) end end

    -- ---- files -----------------------------------------------------------
    function ed.editedPathFor(path)
        local stem = path:gsub("%.%w+$", "")
        local candidate = stem .. " (edited).png"
        local exists
        pcall(function() exists = hs.fs.attributes(candidate, "size") end)
        if not exists then return candidate end
        for n = 2, 99 do
            local p = stem .. (" (edited %d).png"):format(n)
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
    function ed.buildHtml(dataURI)
        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:14px; background:#141418; color:#e8e8ec; overflow:hidden; }
  header { padding:10px 16px; display:flex; gap:12px; align-items:center;
           border-bottom:1px solid #2a2a32; user-select:none; -webkit-user-select:none; }
  h1 { font-size:15px; margin:0; font-weight:600; flex:1; }
  .hint { color:#8a8a96; font-size:12px; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:6px 12px; font-size:13px; cursor:pointer; }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  button:hover { filter:brightness(1.18); }
  #stage { position:relative; display:flex; justify-content:center;
           align-items:flex-start; padding:12px; height:calc(100vh - 54px);
           box-sizing:border-box; overflow:auto; }
  #cv { max-width:100%; max-height:100%; cursor:crosshair;
        box-shadow:0 4px 24px rgba(0,0,0,.5); }
  /* fixed, not absolute: the drag math works in viewport coordinates
     (getBoundingClientRect), and position:fixed is the box that lives
     in exactly that coordinate space */
  #band { position:fixed; border:2px dashed #4a7fe0;
          background:rgba(74,127,224,.15); pointer-events:none; display:none; }
</style>
<header>
  <h1>🖌 Blur — drag a box over anything private</h1>
  <button onclick="undoBox()" title="⌘Z">↩︎ Undo</button>
  <button class="go" onclick="saveIt()" title="⌘⏎">Save &amp; copy&nbsp;&nbsp;⌘⏎</button>
  <button onclick="say({a:'cancel'})" title="esc">Cancel</button>
  <span class="hint">saved as “… (edited).png” — the original stays</span>
</header>
<div id="stage">
  <canvas id="cv"></canvas>
  <div id="band"></div>
</div>
<script>
  var RADIUS = ]] .. tostring(math.floor(ed.blurRadius)) .. [[;
  var PASSES = ]] .. tostring(math.floor(ed.blurPasses)) .. [[;
  var MAXUNDO = ]] .. tostring(math.floor(ed.maxUndo)) .. [[;

  function say(m){ window.webkit.messageHandlers.shotEditor.postMessage(m || {}); }

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
  var band = document.getElementById('band');
  var undoStack = [];

  function applyBlur(rx, ry, rw, rh){
    rx = Math.max(0, Math.round(rx)); ry = Math.max(0, Math.round(ry));
    rw = Math.min(cv.width - rx, Math.round(rw));
    rh = Math.min(cv.height - ry, Math.round(rh));
    if (rw < 2 || rh < 2) return false;
    undoStack.push({ x: rx, y: ry, w: rw, h: rh,
                     data: ctx.getImageData(rx, ry, rw, rh) });
    if (undoStack.length > MAXUNDO) undoStack.shift();
    var patch = ctx.getImageData(rx, ry, rw, rh);
    boxBlurRGBA(patch.data, rw, rh, RADIUS, PASSES);
    ctx.putImageData(patch, rx, ry);
    return true;
  }
  function undoBox(){
    var u = undoStack.pop();
    if (u) ctx.putImageData(u.data, u.x, u.y);
  }
  function saveIt(){
    say({ a: 'save', data: cv.toDataURL('image/png') });
  }

  if (ctx) {
    var img = new Image();
    img.onload = function(){
      cv.width = img.naturalWidth; cv.height = img.naturalHeight;
      ctx.drawImage(img, 0, 0);
    };
    img.src = ']] .. dataURI .. [[';

    // displayed size ≠ pixel size (CSS scales the canvas to fit), so
    // every mouse point is mapped through the live scale factor
    var dragging = false, sx = 0, sy = 0;
    function toCanvas(e){
      var r = cv.getBoundingClientRect();
      return { x: (e.clientX - r.left) * (cv.width  / r.width),
               y: (e.clientY - r.top)  * (cv.height / r.height) };
    }
    cv.addEventListener('mousedown', function(e){
      if (e.button !== 0) return;
      e.preventDefault();
      var p = toCanvas(e); dragging = true; sx = p.x; sy = p.y;
      band.style.display = 'block';
    });
    window.addEventListener('mousemove', function(e){
      if (!dragging) return;
      var r = cv.getBoundingClientRect();
      // the band is drawn in SCREEN space, from the anchor to the pointer
      var ax = sx * (r.width / cv.width) + r.left;
      var ay = sy * (r.height / cv.height) + r.top;
      band.style.left   = Math.min(ax, e.clientX) + 'px';
      band.style.top    = Math.min(ay, e.clientY) + 'px';
      band.style.width  = Math.abs(e.clientX - ax) + 'px';
      band.style.height = Math.abs(e.clientY - ay) + 'px';
    });
    window.addEventListener('mouseup', function(e){
      if (!dragging) return;
      dragging = false; band.style.display = 'none';
      var p = toCanvas(e);
      applyBlur(Math.min(sx, p.x), Math.min(sy, p.y),
                Math.abs(p.x - sx), Math.abs(p.y - sy));
    });
    window.addEventListener('keydown', function(e){
      if (e.key === 'Escape') { e.preventDefault(); say({a:'cancel'}); }
      else if (e.metaKey && e.key === 'Enter') { e.preventDefault(); saveIt(); }
      else if (e.metaKey && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault(); undoBox();
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
            local b64 = data:match("^data:image/png;base64,(.+)$")
            if not b64 then
                pcall(function() hs.alert.show("🖌 Save failed — bad image data", 3) end)
                warn("save message without a png data URI")
                return
            end
            local bytes
            pcall(function() bytes = hs.base64.decode(b64) end)
            if not bytes or #bytes == 0 then
                pcall(function() hs.alert.show("🖌 Save failed — could not decode", 3) end)
                return
            end
            local outPath = ed.editedPathFor(ed.currentPath or "screenshot.png")
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
        local w = math.max(520, math.floor(imgW * scale) + 28)
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

    _G.screenshotEditor = ed
    M.editor = ed
    M.config = ed
end

return M
