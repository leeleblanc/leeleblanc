-- =====================================================================
-- MODULE: NOTE PAD (⇪pad2 · ⇪pad* · ⇪pad-) — a Capture-Pad-style window
--                                             for notes that go to FILES
-- =====================================================================
-- LL: "On open, use a window like 'Capture Pad'." So this IS that window
-- — the same dark card, the same drag header, the same ⌘⏎ — but where
-- the Capture Pad queues notes for ASANA, this one writes them straight
-- into the Quick Append text files (and their notes.csv index) and
-- closes. Three doors in:
--
--      ⇪pad2   the CLIPBOARD, opened for editing first — read what you
--              copied, fix it, THEN file it. The confirmation shows
--              exactly what was written, same as every quick append.
--      ⇪pad*   an empty pad aimed at Ideas & Scratch
--      ⇪pad-   an empty pad aimed at Logs
--
-- The target row across the top is live: ⌘1/⌘2/⌘3 (or a click) re-aims
-- the note without losing a character of it. ⌘⇧C copies the edited text
-- back to the clipboard — the "edit and copy" half of the request — and
-- says how much it copied. Esc closes; an open draft survives in
-- np.draft, not in the window, so closing loses nothing.
--
-- WHY A SEPARATE MODULE AND NOT MORE quick_append. quick_append's whole
-- identity is "nothing opens, nothing takes focus" — the fast path. An
-- editor window is the deliberate path. Keeping them apart keeps both
-- honest: this file knows nothing about io.open, it hands finished text
-- to the published notes.append service and relays THAT verdict; a Mac
-- whose profile drops quick_append gets a pad that says so instead of a
-- pad that half-works.
--
-- THE WINDOW RULES ARE ALL INHERITED FROM THE CAPTURE PAD, deliberately:
-- non-activating panel (typing must not drag Hammerspoon forward),
-- canJoinAllSpaces + fullScreenAuxiliary (must appear over full-screen
-- apps), allowTextEntry (a webview swallows keystrokes without it), the
-- Lua-driven header drag (a WKWebView loses the mouse the moment the
-- pointer leaves it), and say() attaching the live textarea to EVERY
-- message (the 6.44.7 lesson: a button that forgets the text wipes the
-- draft). Where those notes are load-bearing they are repeated at the
-- code; the full histories live in capture_pad.lua.

local M = {
    name  = "Note Pad",
    order = 13.35,       -- between Quick Append (13.3), whose files it
                         -- writes, and the numpad layer (13.5) that keys it
    cheatsheet = {
        title = "🗒 NOTE PAD (⇪pad2 — edit the clipboard, then file it)",
        entries = {
            { "⇪pad2", "Clipboard opens in the pad — edit it, ⌘⏎ files it" },
            { "⇪pad*", "Empty pad → Ideas & Scratch" },
            { "⇪pad-", "Empty pad → Logs" },
            { "⌘1 2 3", "Re-aim the note at another file — the text stays put" },
            { "⌘⏎",    "File it — appends to the target file + one notes.csv row" },
            { "⌘⇧C",   "Copy the edited text back to the clipboard" },
            { "drag",   "The header moves the pad · ⌘-drag anywhere works too" },
            { "Esc",    "Close (the draft is kept until the pad next opens)" },
        },
    },
}

function M.setup(core)
    local np = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    np.enabled       = true
    np.width, np.height = 640, 360
    np.focusOnOpen   = true    -- take the keyboard on open, so typing starts
    np.nonActivating = true    -- ask for the panel that types WITHOUT
                               -- pulling Hammerspoon's other windows forward
    -- ----------------------------------------------------------------------

    np.draft      = ""      -- survives close/reopen, lives here not in the DOM
    np.draftCaret = 0
    np.target     = nil     -- the target NAME currently aimed at (nil = default)
    np.webview    = nil     -- HELD
    np.uc         = nil     -- HELD: the JS→Lua message port

    local function say(m) if _G.diag then _G.diag.say("notePad", m) end end

    local function escapeHtml(s)
        return (tostring(s or "")
            :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            :gsub('"', "&quot;"))
    end

    -- The targets belong to Quick Append; this pad only points at them.
    -- Read LIVE on every call, not captured at setup: a machine profile
    -- rewrites quickAppend.targets after setup runs, and a pad holding
    -- yesterday's table would file notes into files that no longer exist.
    local function targets()
        local qa = _G.quickAppend
        if qa and type(qa.targets) == "table" and #qa.targets > 0 then
            return qa.targets, qa.targets[qa.defaultTarget or 1] or qa.targets[1]
        end
        return nil, nil
    end

    local function targetOrDefault()
        local list, default = targets()
        if not list then return nil end
        for _, t in ipairs(list) do
            if t.name == np.target then return t end
        end
        return default
    end

    -- ---- filing ----------------------------------------------------------
    -- All writing goes through the PUBLISHED service, never io.open here:
    -- the verdict (and the alert text, with its line count and preview —
    -- the confirmation LL asked for) belongs to quick_append, and this
    -- module must not grow a second, slightly different writer.
    function np.fileIt(text)
        text = tostring(text or "")
        local t = targetOrDefault()
        if not t then
            pcall(function()
                hs.alert.show("🗒 Note Pad: Quick Append is not loaded on "
                              .. "this Mac — nowhere to file the note")
            end)
            return false
        end
        if not (_G.service and _G.service.has and _G.service.has("notes.append")) then
            pcall(function()
                hs.alert.show("🗒 Note Pad: the notes.append service is missing")
            end)
            return false
        end
        local ok, msg = _G.service.call("notes.append", text, t.name)
        if ok then
            np.draft, np.draftCaret = "", 0
            np.hide()
            pcall(function() hs.alert.show(msg, 2) end)
            say("filed to " .. t.name)
        else
            -- The pad STAYS OPEN on a failure — closing it would throw
            -- away the one copy of a note that just failed to save.
            pcall(function() hs.alert.show("⚠️ " .. tostring(msg), 5) end)
        end
        return ok == true
    end

    function np.copyBack(text)
        text = tostring(text or "")
        local ok = pcall(function() hs.pasteboard.setContents(text) end)
        pcall(function()
            hs.alert.show(ok and ("📋 copied — " .. #text .. " chars")
                             or  "⚠️ the clipboard refused the text")
        end)
        return ok
    end

    -- ---- the page --------------------------------------------------------
    local function buildHtml()
        local list, _ = targets()
        local aimed = targetOrDefault()
        -- The name reaches the page twice: as VISIBLE TEXT (HTML-escaped)
        -- and inside a single-quoted JS string in an onclick attribute —
        -- which needs JS escaping FIRST, then HTML escaping, because the
        -- attribute parser decodes entities before JS ever runs.
        local function jsName(s)
            return escapeHtml((tostring(s):gsub("\\", "\\\\"):gsub("'", "\\'")))
        end
        local rows = {}
        for i, t in ipairs(list or {}) do
            local on = aimed and t.name == aimed.name
            table.insert(rows, string.format(
                '<button type="button" class="tgt%s" onclick="aim(\'%s\')">%s'
                .. '<span class="kk">⌘%d</span></button>',
                on and " on" or "", jsName(t.name), escapeHtml(t.name), i))
        end
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""
        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:15px; line-height:1.5; background:#141418; color:#e8e8ec; }
  /* The header IS the title bar — hs.webview windows are borderless. */
  header { padding:12px 18px 8px; display:flex; justify-content:space-between;
           align-items:baseline; border-bottom:1px solid #2a2a32;
           cursor:grab; user-select:none; -webkit-user-select:none; }
  header:active { cursor:grabbing; }
  header.dragging { cursor:grabbing; background:#1b1b22; }
  h1 { font-size:16px; margin:0; font-weight:600; }
  .grip { color:#4a4a56; margin-right:8px; letter-spacing:2px; }
  .hint { color:#8a8a96; font-size:13px; }
  #wrap { padding:12px 18px 16px; }
  #tgts { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:10px; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:7px 13px; font-size:14px; cursor:pointer; }
  button:hover { filter:brightness(1.18); }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  .tgt .kk { margin-left:8px; font-size:10px; color:#8a8a96; }
  .tgt.on { background:#2f5d3a; border-color:#3f7d4e; color:#d9f2e0; }
  .tgt.on .kk { color:#9de8b0; }
  /* Longhand font rules on purpose — the shorthand+keyword mix is the
     invalid combination WebKit drops whole (the 6.44.1 textarea bug). */
  textarea { width:100%; box-sizing:border-box; height:150px; resize:vertical;
             background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
             border-radius:8px; padding:12px;
             font-family:-apple-system,BlinkMacSystemFont,sans-serif;
             font-size:16px; line-height:1.5; }
  textarea:focus { outline:none; border-color:#4a7fe0; }
  textarea::placeholder { color:#5c5c68; }
  .bar { margin-top:12px; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
  ]] .. themeCss .. [[
</style>
<header id="bar">
  <h1><span class="grip">⠿</span>🗒 Note Pad</h1>
  <span class="hint">drag here · ⌘⏎ file · ⌘⇧C copy · ⎋ close</span>
</header>
<div id="wrap">
  <div id="tgts">]] .. table.concat(rows) .. [[</div>
  <textarea id="t" placeholder="Type a note — or this is your clipboard, edit away."
            autofocus>]] .. escapeHtml(np.draft) .. [[</textarea>
  <div class="bar">
    <button class="go" onclick="fileIt()">File it &nbsp;⌘⏎</button>
    <button onclick="say({a:'copy'})">Copy &nbsp;⌘⇧C</button>
    <span class="hint">appends to the highlighted file + one row in notes.csv</span>
  </div>
</div>
<script>
  var t = document.getElementById('t');
  // say() attaches the live textarea to EVERY message — the 6.44.7
  // Capture Pad lesson. A button that sends without the text makes Lua
  // keep a stale draft, and the next redraw wipes what was typed.
  function say(m){
    m = m || {};
    m.text = t.value;
    m.sel  = t.selectionStart;
    window.webkit.messageHandlers.notePad.postMessage(m);
  }
  function fileIt(){ say({a:'file'}); }
  function aim(name){ say({a:'aim', target:name}); }
  var bar = document.getElementById('bar');
  bar.addEventListener('mousedown', function(e){
    if (e.button !== 0) return;
    e.preventDefault();
    bar.classList.add('dragging');
    say({a:'dragStart'});
  });
  window.addEventListener('mouseup', function(){ bar.classList.remove('dragging'); });
  var names = ]] .. (function()
        local out = {}
        for _, t in ipairs(list or {}) do
            table.insert(out, '"' .. tostring(t.name)
                :gsub("\\", "\\\\"):gsub('"', '\\"') .. '"')
        end
        return "[" .. table.concat(out, ",") .. "]"
    end)() .. [[;
  window.addEventListener('keydown', function(e){
    if (e.metaKey && e.key === 'Enter') { e.preventDefault(); fileIt(); }
    else if (e.metaKey && e.shiftKey && (e.key === 'c' || e.key === 'C')) {
      e.preventDefault(); say({a:'copy'});
    }
    else if (e.metaKey && e.key >= '1' && e.key <= '9') {
      var i = parseInt(e.key, 10) - 1;
      if (i < names.length) { e.preventDefault(); aim(names[i]); }
    }
    else if (e.key === 'Escape') { e.preventDefault(); say({a:'close'}); }
  });
  // Caret restored in JS, not Lua: selectionStart counts UTF-16 units,
  // Lua's # counts bytes — they disagree the moment an emoji appears.
  var caret = ]] .. tostring(math.floor(np.draftCaret or 0)) .. [[;
  if (caret < 0 || caret > t.value.length) caret = t.value.length;
  t.focus(); t.setSelectionRange(caret, caret);
</script>
]]
    end

    function np.render()
        if not np.webview then return end
        pcall(function() np.webview:html(buildHtml()) end)
    end

    local function handleMessage(body)
        if type(body) ~= "table" then return end
        if body.text ~= nil then np.draft = tostring(body.text) end
        if body.sel  ~= nil then np.draftCaret = tonumber(body.sel) or 0 end

        if body.a == "file" then
            np.fileIt(body.text or np.draft)
        elseif body.a == "copy" then
            np.copyBack(body.text or np.draft)
        elseif body.a == "aim" then
            np.target = tostring(body.target or "")
            np.render()   -- the draft rode in on this message; nothing is lost
        elseif body.a == "dragStart" then
            np.beginDrag()
        elseif body.a == "close" then
            np.hide()
        end
    end

    -- ---- dragging --------------------------------------------------------
    -- Lua polls the real mouse; JS mousemove dies the moment the pointer
    -- outruns the window. Same machinery as the Capture Pad, same reason.
    local function mousePosition()
        local fns = {}
        if type(hs.mouse) == "table" then
            if type(hs.mouse.absolutePosition) == "function" then
                table.insert(fns, hs.mouse.absolutePosition)
            end
            if type(hs.mouse.getAbsolutePosition) == "function" then
                table.insert(fns, hs.mouse.getAbsolutePosition)
            end
        end
        for _, fn in ipairs(fns) do
            local ok, p = pcall(fn)
            if ok and type(p) == "table" and p.x and p.y then return p end
        end
        return nil
    end

    local function leftButtonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        return btns.left == true or btns[1] == true
    end

    function np.endDrag()
        if np.dragTimer then
            pcall(function() np.dragTimer:stop() end)
            np.dragTimer = nil
        end
        np.dragOffset = nil
    end

    function np.beginDrag()
        if not np.webview then return end
        local okF, f = pcall(function() return np.webview:frame() end)
        if not (okF and type(f) == "table") then return end
        local m = mousePosition()
        if not m then return end
        np.endDrag()   -- BEFORE the offset is set — endDrag clears it
        np.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        np.dragTimer = hs.timer.doEvery(0.016, function()
            if not (np.webview and np.dragOffset) then np.endDrag() return end
            if not leftButtonDown() then np.endDrag() return end
            local p = mousePosition()
            if not p then np.endDrag() return end
            pcall(function()
                local cur = np.webview:frame()
                np.webview:frame({
                    x = p.x - np.dragOffset.x, y = p.y - np.dragOffset.y,
                    w = cur.w, h = cur.h,
                })
            end)
        end)
    end

    -- ---- the window ------------------------------------------------------
    -- Read back and verified, never assumed — AppKit silently drops style
    -- bits it will not honour. The full story is at Capture Pad's
    -- applyNonActivating; the arithmetic (not 5.3's `&`) is because this
    -- file runs on whatever Lua the installed Hammerspoon was built with.
    function np.applyNonActivating(view)
        if not view then return false, "there is no window" end
        local masks = hs.webview and hs.webview.windowMasks
        local bit   = type(masks) == "table" and masks.nonactivating or nil
        if type(bit) ~= "number" or bit < 1 then
            return false, "this Hammerspoon has no nonactivating window mask"
        end
        local function isSet(v) return (math.floor(v / bit) % 2) == 1 end
        local okGet, cur = pcall(function() return view:windowStyle() end)
        if not (okGet and type(cur) == "number") then
            return false, "the window style could not be read"
        end
        if not isSet(cur) then
            local okSet = pcall(function() view:windowStyle(cur + bit) end)
            if not okSet then return false, "the window style was rejected" end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then
            return false, "the window style could not be read back"
        end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    function np.hide()
        np.endDrag()
        if np.webview then
            pcall(function() np.webview:delete() end)
            np.webview = nil
        end
    end

    -- No webview must not mean no note: the plain text box files to the
    -- same service, it just cannot re-aim or copy back.
    local function promptFallback()
        local t = targetOrDefault()
        if not t then
            pcall(function()
                hs.alert.show("🗒 Note Pad: Quick Append is not loaded — "
                              .. "nowhere to file a note")
            end)
            return
        end
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Note Pad",
            "This is appended to " .. t.name .. " (and one row in notes.csv).",
            np.draft or "", "File it", "Cancel")
        if not okP or button ~= "File it" then return end
        np.fileIt(typed)
    end

    -- opts.text   = prefill (nil keeps the surviving draft)
    -- opts.target = target NAME to aim at (nil keeps the last aim)
    function np.show(opts)
        if not np.enabled then return end
        opts = opts or {}
        if opts.text   ~= nil then np.draft, np.draftCaret = tostring(opts.text), #tostring(opts.text) end
        if opts.target ~= nil then np.target = tostring(opts.target) end
        if np.webview then np.hide() end   -- reopen fresh, re-aimed
        if not (hs.webview and hs.webview.usercontent) then
            promptFallback()
            return
        end

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(np.width, sf.w - 40)
        local h = math.min(np.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3, w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "notePad")
        if not (okUc and uc) then promptFallback() return end
        np.uc = uc     -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("🗒 Note Pad: message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            np.uc = nil
            promptFallback()
            return
        end
        np.webview = view
        pcall(function() view:windowTitle("Note Pad") end)
        -- allowTextEntry sets canBecomeKeyWindow — without it the pad
        -- draws perfectly and swallows every keystroke.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        -- Level is z-order WITHIN a Space; whether the pad may appear over
        -- a full-screen app is collection behaviour, a different axis.
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        np.nonActivatingApplied, np.nonActivatingWhy = false, "not requested"
        if np.nonActivating then
            np.nonActivatingApplied, np.nonActivatingWhy = np.applyNonActivating(view)
            if not np.nonActivatingApplied then
                print("🗒 Note Pad: non-activating panel unavailable — "
                      .. tostring(np.nonActivatingWhy)
                      .. "; opening the pad will bring Hammerspoon forward.")
            end
        end
        np.render()
        pcall(function() view:show() end)
        if np.focusOnOpen then
            pcall(function() view:bringToFront(true) end)
        end
        say("pad opened, aimed at "
            .. ((targetOrDefault() or {}).name or "nothing"))
    end

    -- ---- the three doors in ---------------------------------------------
    -- ⇪pad2: the clipboard, opened for EDITING. An empty clipboard still
    -- opens the pad — you pressed the key to write something — it just
    -- says why the box is empty instead of leaving you to wonder.
    function np.editClipboard()
        local text
        pcall(function() text = hs.pasteboard.getContents() end)
        if text == nil or text == "" then
            pcall(function()
                hs.alert.show("🗒 The clipboard holds no text — starting blank")
            end)
            text = ""
        end
        np.show({ text = text })
        return true
    end

    core.provide("notes.editClipboard", function() return np.editClipboard() end)
    core.provide("notes.typeIdeas", function()
        np.show({ target = "Ideas & Scratch" })
        return true
    end)
    core.provide("notes.typeLog", function()
        np.show({ target = "Logs" })
        return true
    end)
    core.provide("notePad.show", function(opts) np.show(opts) return true end)

    -- ⌘-drag anywhere on the pad, via the shared drag layer.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "note pad",
        frame = function() return np.webview and np.webview:frame() end,
        move  = function(x, y)
            local f = np.webview and np.webview:frame()
            if f then np.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    -- ⎋ in the escape router, so the cheat sheet closes AFTER the pad.
    -- Safe to claim: the draft lives in np.draft, not the window.
    if _G.claimEscape then
        _G.claimEscape("notepad", nil,
            function() return np.webview ~= nil end,
            function() np.hide() end)
    end

    _G.notePad = np
    M.np     = np
    M.config = np
end

return M
