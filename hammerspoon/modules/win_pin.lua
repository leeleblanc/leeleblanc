-- =====================================================================
-- MODULE: WINDOW PIN (⇪⇧U) — a note stuck to ONE window, following it
-- =====================================================================
-- LL brought in Blackman99/WinPin.spoon and asked whether it was worth
-- adding. Verdict: yes, the idea is worth adding — a small label glued
-- to a specific window survives every "which of these six terminals was
-- the one on staging" moment, and nothing else in this config does it.
-- The Spoon itself is adapted rather than dropped in, for the reasons
-- in the ⚖️ block below.
--
-- ORIGINAL: WinPin.spoon, Dongsheng Zhao, MIT licence
--           https://github.com/Blackman99/WinPin.spoon
-- The window-following approach, the per-window keying, and the
-- dead/stale distinction are the original author's and are kept.
--
-- ⚖️ WHAT CHANGED COMING IN, AND WHY EACH:
--   1. THE FOLLOW TIMER IS ADAPTIVE. The Spoon polls window geometry
--      every 0.03s for as long as ANY note exists — 33 wake-ups a
--      second, forever, including while every note is hidden behind
--      another app. That is the config's single biggest battery rule
--      broken in one line. Here the tick runs fast only while a note is
--      actually ON SCREEN and drops to wp.followIdle otherwise, so a
--      pinned window you are not looking at costs two wake-ups a second
--      instead of thirty-three.
--   2. CANVASES GO UP THROUGH _G.showCanvasSafely. A bare canvas:show()
--      can throw when another app's popup is mid-transition (the 6.56.0
--      NSRemoteView collision), and this one shows inside a LOOP — one
--      throw would abandon every note after it. See init.lua §1.
--   3. COLOURS COME FROM ui_style. The Spoon hardcodes its own dark
--      panel; this config has one card style and eleven windows already
--      wearing it.
--   4. ACCESSIBILITY IS A GATE, NOT A CRASH. Reading window frames is
--      exactly what AX gates. Without it this starts nothing and says
--      so, like Window Return and App Peek.
--   5. hs.settings VALUES ARE VALIDATED ON THE WAY BACK IN. The Spoon
--      trusts whatever it reads; a half-written settings blob would
--      build canvases from nil text.
--
-- 🔑 WHY ⇪⇧U: it was the last unclaimed ⇪⇧ letter in the config. There
-- is no ⇪⇧ letter left after this one — the next tool needs a symbol
-- key, a numpad key, or a row inside an existing picker.
--
-- ONE KEY, THREE OUTCOMES, because there is no second key to spend:
--   ⇪⇧U on a window with no note   → opens the editor, pins what you type
--   ⇪⇧U on a window that HAS one   → opens it pre-filled, edits it
--   ⇪⇧U, then empty the box, ⌘⏎    → removes that window's note
--
-- ✍️ 6.112.0 — THE BOX IS A WINDOW, NOT AN ALERT. LL: "that box is way
-- too small", with two screenshots of the same ~25 visible characters
-- scrolling out of a one-line field. It WAS hs.dialog.textPrompt, whose
-- NSTextField cannot be resized, cannot scroll and cannot take a Return
-- — so the prompt's own promise that "newlines are fine" was impossible
-- to act on. It is now the Capture Pad's window: multi-line, monospace
-- at the note's own wrap width, a live character count against the
-- limit that would otherwise refuse the pin only AFTER you typed it,
-- ⌘⏎ to pin, Esc to cancel, draggable by its header. A Mac without
-- hs.webview still gets the small prompt — same meaning, smaller box.
--
-- 📐 AND THE NOTE ITSELF NOW WRAPS. See wp.maxWidth: an unwrapped note
-- grew wider than the screen and was drawn off the edge of it, which is
-- what "I added one and I can't see it" turned out to be.
-- Everything rarer lives in the Console: _G.pins() prints the ledger,
-- and it names the calls for removing, moving and pruning notes.
--
-- 📑 TABS COME FREE and it is worth knowing why: apps that expose each
-- tab as its own accessibility window — Ghostty, iTerm, most terminals
-- — give every tab a distinct stable window id, so a note follows the
-- TAB. Apps that do not (Chrome, Safari: one window, many tabs) get one
-- note for the whole window, which is the honest limit, not a bug.
--
-- 🚨 A NOTE IS NEVER AUTO-DELETED. When a window id stops resolving,
-- that is either "the tab went to the background" or "it closed", and
-- NOTHING in the accessibility API separates the two (the original
-- author's finding, verified here). Deleting on the wrong guess throws
-- away text a person typed. So a note whose window is missing hides and
-- waits: _G.pins() lists it, wp.prune() removes the ones whose whole
-- APPLICATION exited, and wp.rebind() moves one onto the window in
-- front of you when a reopened tab came back with a new id.

local M = {
    name   = "Window Pin",
    order  = 6.7,
    family = "windows",
    cheatsheet = {
        title = "📌 WINDOW PIN (⇪⇧U — a note stuck to one window)",
        entries = {
            { "⇪⇧U",  "Pin a note to the window in front — again to edit it" },
            { "⌘⏎",   "Pin it · Esc cancels · drag the box by its header" },
            { "clear", "Empty the box (or Remove note) — that window's note goes" },
            { "wrap",  "Long notes wrap into a block and stay on screen" },
            { "follow", "The note tracks the window as it moves, and hides with it" },
            { "tabs",  "Terminal tabs each keep their OWN note (Ghostty, iTerm)" },
            { "_G.pins()", "Console: every note, where it is, and what to call next" },
        },
    },
}

function M.setup(core)
    local wp = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    wp.enabled      = true
    wp.key          = "u"       -- ⇪⇧U — the last free ⇪⇧ letter
    wp.anchor       = "topRight"  -- topLeft · topRight · bottomLeft · bottomRight
    wp.offsetX      = 12        -- inset from that corner, points
    wp.offsetY      = 44        -- ⬅ clears a title bar; lower it for chrome-less apps
    wp.fontName     = "Menlo"
    wp.fontSize     = 13
    wp.padding      = 10
    wp.maxChars     = 400       -- a longer note is refused (see 📐 below)
    -- 📐 6.112.0 — THE NOTE IS A BLOCK, NOT A STRIP. Until now the canvas
    -- was sized to whatever one unwrapped line of text measured, so its
    -- width grew forever with the note: past roughly 110 characters on an
    -- 800pt window the topRight anchor pushed it clean off the LEFT edge
    -- of the screen and the note became invisible. maxChars = 400 could
    -- not save it — 400 characters is 3,140pt wide, which is off-screen
    -- on every display sold. The note now wraps at maxWidth and the final
    -- frame is clamped to a real screen, so a note can be badly placed
    -- but never invisible.
    wp.maxWidth     = 360       -- widest the note may draw; text wraps to fit
    -- Hide a note unless its app is frontmost. Leave this ON: the canvas
    -- floats above every window, so a note left visible while its window
    -- sits behind another app looks pinned to the WRONG one.
    wp.onlyWhenAppFocused = true
    wp.followFast   = 0.05      -- seconds between checks while a note is VISIBLE
    wp.followIdle   = 0.5       -- …and while every note is hidden (see ⚖️ 1)
    -- ✍️ 6.112.0 — THE EDITOR. hs.dialog.textPrompt is a fixed-size NSAlert
    -- with a ONE-LINE NSTextField: it cannot be resized, cannot scroll, and
    -- cannot accept a newline (Return presses the default button). LL sent
    -- two screenshots of the same 25 visible characters and said "that box
    -- is way too small" — correctly, and it was never going to be fixable
    -- while it was that control. This is the Capture Pad's window instead.
    wp.editorW      = 560
    wp.editorH      = 340
    wp.editorFont   = 15        -- the BOX's size; the note still draws at fontSize
    wp.nonActivating = true     -- type without dragging Hammerspoon forward
    -- ----------------------------------------------------------------------

    local SETTINGS_KEY = "winPin.notes"

    local function say(m)  if _G.diag then _G.diag.say("winPin", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("winPin", m) end end

    -- Reading another app's window frames is what Accessibility gates.
    -- Without it there is nothing to follow, so nothing starts.
    local axOK = false
    pcall(function() axOK = hs.accessibilityState() == true end)

    -- pins[windowId] = { text, canvas, lastFrame, appPid, appName, title }
    -- ONE CANVAS PER PIN, not one shared canvas: two windows of the same
    -- app can be on screen at once and a single canvas can only ever be
    -- in one place. (The original author's reasoning, kept verbatim in
    -- spirit — it is right.)
    wp.pins  = {}
    wp.timer = nil       -- HELD: an unreferenced hs.timer is collected,
    wp.rate  = nil       -- and a collected timer never fires.

    -- ---- the card ---------------------------------------------------------
    -- Shared card colours, with the literal fallback every ui_style
    -- consumer in this config carries: a module must still draw if
    -- ui_style failed to load.
    local function style()
        local s = _G.uiStyle
        return {
            bg     = (s and s.bg)     or { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 },
            fg     = (s and s.fg)     or { white = 1.00, alpha = 0.97 },
            stroke = (s and s.stroke) or { white = 1.00, alpha = 0.18 },
            radius = (s and s.radius) or 12,
        }
    end

    -- ---- wrapping (6.112.0) ----------------------------------------------
    -- Bytes are not characters, and a note can hold anything you typed.
    -- Wrapping by BYTES would work — it only ever wraps early, so it can
    -- never widen the note — but "early" on accented or emoji text means
    -- absurdly narrow, so measure properly and fall back to bytes only
    -- when the string is not valid UTF-8 at all.
    local function ulen(s)
        return (utf8 and utf8.len and utf8.len(s)) or #s
    end
    local function usub(s, i, j)
        if not (utf8 and utf8.offset and utf8.len(s)) then return s:sub(i, j) end
        local from = utf8.offset(s, i)
        if not from then return "" end
        local to = utf8.offset(s, j + 1)
        return s:sub(from, to and (to - 1) or #s)
    end

    -- How many characters fit across the note. Menlo's advance is 602/1000
    -- of the em, and the font is monospace, so this is exact for the
    -- shipped font. A proportional wp.fontName makes it an ESTIMATE — which
    -- is why the width cap and the screen clamp below are the real
    -- guarantees, and this is only what makes the wrap look right.
    function wp.wrapCols()
        local inner = (wp.maxWidth or 360) - wp.padding * 2
        return math.max(8, math.floor(inner / ((wp.fontSize or 13) * 0.602)))
    end

    -- 📑 THE NEWLINES YOU TYPED ARE KEPT. The prompt has promised "newlines
    -- are fine" since 6.104.0 and, in a one-line NSTextField, you could not
    -- type one — the editor of 6.112.0 is the other half of making that
    -- sentence true.
    function wp.wrapText(text, cols)
        cols = math.max(8, math.floor(cols or wp.wrapCols()))
        local out = {}
        for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
            if line:match("^%s*$") then
                out[#out + 1] = ""
            else
                local cur = ""
                local function flushLong()
                    -- One word longer than the whole line is BROKEN rather
                    -- than allowed to widen the note past its cap. A URL is
                    -- the ordinary case, not a corner one.
                    while ulen(cur) > cols do
                        out[#out + 1] = usub(cur, 1, cols)
                        cur = usub(cur, cols + 1, ulen(cur))
                    end
                end
                for word in line:gmatch("%S+") do
                    if cur == "" then cur = word
                    elseif ulen(cur) + 1 + ulen(word) <= cols then
                        cur = cur .. " " .. word
                    else
                        out[#out + 1] = cur ; cur = word
                    end
                    flushLong()
                end
                if cur ~= "" then out[#out + 1] = cur end
            end
        end
        return table.concat(out, "\n")
    end

    -- Build at a placeholder size, ask the canvas how much room the text
    -- actually needs, then shrink to fit.
    -- 🚨 minimumTextSize, NOT hs.drawing.getTextDrawingSize: the latter is
    -- deprecated AND takes a flat style table, so handing it a
    -- styledtext-shaped { font = { name =, size = } } silently measures at
    -- 27pt and every note comes out twice the size it should be.
    function wp.buildCanvas(text)
        local st = style()
        local c
        local okNew = pcall(function()
            c = hs.canvas.new({ x = 0, y = 0, w = 100, h = 100 })
        end)
        if not (okNew and c) then
            warn("hs.canvas.new failed — no note can be drawn")
            return nil
        end

        c[1] = {
            type             = "rectangle",
            action           = "strokeAndFill",
            fillColor        = st.bg,
            strokeColor      = st.stroke,
            strokeWidth      = 1,
            roundedRectRadii = { xRadius = st.radius, yRadius = st.radius },
        }
        -- What gets DRAWN is the wrapped form; p.text keeps what you typed.
        local shown = wp.wrapText(text)
        c[2] = {
            type      = "text",
            text      = shown,
            textFont  = wp.fontName,
            textSize  = wp.fontSize,
            textColor = st.fg,
            frame     = { x = 0, y = 0, w = 100, h = 100 },
        }

        local w, h = 220, 60
        pcall(function()
            local size = c:minimumTextSize(2, shown)
            if size and size.w and size.h then
                w = math.ceil(size.w) + wp.padding * 2
                h = math.ceil(size.h) + wp.padding * 2
            end
        end)
        -- 🚨 THE CAP IS NOT A SUGGESTION. Wrapping should already have kept
        -- the width down, but a proportional font, a measurement quirk or a
        -- single unbreakable glyph run must not be able to produce a
        -- mile-wide canvas — that is the bug this whole section exists for.
        w = math.min(w, wp.maxWidth or 360)

        pcall(function()
            c:frame({ x = 0, y = 0, w = w, h = h })
            c[2].frame = { x = wp.padding, y = wp.padding,
                           w = w - wp.padding * 2, h = h - wp.padding * 2 }
            c:level("overlay")
            -- Clicking a note must not pull focus to Hammerspoon, and the
            -- click belongs to the window underneath. Both matter more here
            -- than usual: Window Move runs an event tap that consumes
            -- clicks it believes are ours, and a note that swallowed clicks
            -- would make the window under it feel broken.
            c:clickActivating(false)
            c:canvasMouseEvents(false, false, false, false)
        end)
        return c
    end

    function wp.overlayFrame(winFrame, w, h)
        local x, y
        if wp.anchor == "topLeft" then
            x, y = winFrame.x + wp.offsetX, winFrame.y + wp.offsetY
        elseif wp.anchor == "bottomLeft" then
            x, y = winFrame.x + wp.offsetX, winFrame.y + winFrame.h - h - wp.offsetY
        elseif wp.anchor == "bottomRight" then
            x, y = winFrame.x + winFrame.w - w - wp.offsetX,
                   winFrame.y + winFrame.h - h - wp.offsetY
        else -- topRight, the default
            x, y = winFrame.x + winFrame.w - w - wp.offsetX, winFrame.y + wp.offsetY
        end
        -- 🚨 CLAMPED LAST, ALWAYS. A note anchored to a corner of a window
        -- that is itself near a screen edge — or a note wider than its own
        -- window — lands outside the display, and an invisible note reads
        -- as "the pin did nothing" with no way to tell the difference.
        -- Better badly placed and visible than perfectly placed and gone.
        local f = { x = x, y = y, w = w, h = h }
        if _G.clampToScreen then
            local p = _G.clampToScreen({ x = f.x, y = f.y }, f.w, f.h)
            if p and p.x and p.y then f.x, f.y = p.x, p.y end
        end
        return f
    end

    -- Is this window actually the one you are looking at? A background
    -- tab cannot be looked up at all, so anything reaching here is the
    -- active tab; what this guards is a same-app window sitting BEHIND
    -- another window of that app.
    function wp.isShowing(win)
        local ok, vis = pcall(function()
            if win:isMinimized() then return false end
            local app = win:application()
            if not app then return false end
            if wp.onlyWhenAppFocused and not app:isFrontmost() then return false end
            local focused = app:focusedWindow()
            if focused and focused:id() ~= win:id() then return false end
            return true
        end)
        return ok and vis == true
    end

    -- ---- persistence ------------------------------------------------------
    function wp.save()
        local plain = {}
        for winId, p in pairs(wp.pins) do
            plain[tostring(winId)] = { text = p.text, appPid = p.appPid,
                                       appName = p.appName, title = p.title }
        end
        pcall(function() hs.settings.set(SETTINGS_KEY, plain) end)
    end

    -- ---- the follow tick --------------------------------------------------
    -- Returns how many notes are on screen, so the caller can decide the
    -- next interval — and so the test can assert it without a clock.
    function wp.tick()
        local visible = 0
        for _, p in pairs(wp.pins) do
            local win
            pcall(function() win = hs.window.get(p.id) end)

            if not win then
                -- Backgrounded tab or closed window — indistinguishable
                -- here. Hide, never delete: the text is the user's, and a
                -- stranded note costs nothing while a deleted one is gone.
                pcall(function() if p.canvas then p.canvas:hide() end end)
                p.lastFrame = nil
            elseif not wp.isShowing(win) then
                pcall(function() if p.canvas then p.canvas:hide() end end)
                -- Drop the cached position: the window may have moved
                -- while it was hidden, and a stale lastFrame would let the
                -- next show land the note where the window used to be.
                p.lastFrame = nil
            elseif p.canvas then
                pcall(function()
                    local wf   = win:frame()
                    local size = p.canvas:frame()
                    local want = wp.overlayFrame(wf, size.w, size.h)
                    local last = p.lastFrame
                    -- Only touch the canvas when the position really changed.
                    if not last or last.x ~= want.x or last.y ~= want.y then
                        p.canvas:frame(want)
                        p.lastFrame = want
                    end
                end)
                if _G.showCanvasSafely then _G.showCanvasSafely(p.canvas, "window pin")
                else pcall(function() p.canvas:show() end) end
                visible = visible + 1
            end
        end
        wp.retime(visible)
        return visible
    end

    -- ⚖️ 1 in the header, implemented: fast only while something is on
    -- screen. The timer is swapped rather than left running, because the
    -- cost being avoided IS the wake-up.
    function wp.retime(visible)
        if not next(wp.pins) then
            if wp.timer then pcall(function() wp.timer:stop() end) end
            wp.timer, wp.rate = nil, nil
            return
        end
        local want = (visible and visible > 0) and wp.followFast or wp.followIdle
        if wp.timer and wp.rate == want then return end
        if wp.timer then pcall(function() wp.timer:stop() end) end
        wp.rate  = want
        wp.timer = hs.timer.doEvery(want, function() pcall(wp.tick) end)
    end

    -- ---- public API -------------------------------------------------------
    -- Attach text to a window without prompting. Console-callable, and
    -- the single place a pin is created — wp.pin() is only the prompt.
    function wp.set(text, winId)
        if not axOK then return "📌 Window Pin: Accessibility is off" end
        -- 🚨 NAMED ID MEANS NAMED ID. The original reads
        --     winId and hs.window.get(winId) or hs.window.focusedWindow()
        -- which looks like "that window, else the focused one" and is
        -- actually "that window, and if it has GONE, silently pin to
        -- whatever is in front instead". rebind() calls this with an id,
        -- so that path could move a note onto the wrong window and report
        -- success. Asked for an id, answer about that id.
        local win
        pcall(function()
            if winId then win = hs.window.get(winId)
            else            win = hs.window.focusedWindow() end
        end)
        if not win then return "📌 Window Pin: no window" end
        if type(text) ~= "string" or text == "" then
            return "📌 Window Pin: empty text"
        end
        if #text > wp.maxChars then
            return string.format("📌 Window Pin: %d characters — over the %d limit",
                                 #text, wp.maxChars)
        end

        local id, app, title
        pcall(function()
            id, app, title = win:id(), win:application(), win:title()
        end)
        if not id then return "📌 Window Pin: that window has no id" end

        local old = wp.pins[id]
        if old and old.canvas then pcall(function() old.canvas:delete() end) end
        wp.pins[id] = {
            id      = id,
            text    = text,
            canvas  = wp.buildCanvas(text),
            appPid  = app and app:pid() or nil,
            appName = app and app:name() or nil,
            title   = title,
        }
        wp.save()
        wp.tick()
        say("pinned to window " .. tostring(id))
        return "📌 Window Pin: bound to window " .. tostring(id)
    end

    function wp.remove(winId, quiet)
        local p = wp.pins[winId]
        if not p then return false end
        if p.canvas then pcall(function() p.canvas:delete() end) end
        wp.pins[winId] = nil
        wp.save()
        wp.retime(0)
        if not quiet then hs.alert.show("📌 Note removed") end
        return true
    end

    -- ---- ✍️ the editor (6.112.0) ------------------------------------------
    -- One place decides what a finished edit MEANS, so the big editor and
    -- the small fallback below cannot drift into disagreeing about it.
    -- Empty still removes — that contract predates the window and the cheat
    -- sheet still teaches it.
    function wp.applyEdit(winId, text, label)
        text = tostring(text or "")
        if text:gsub("%s+", "") == "" then
            if wp.remove(winId, true) then hs.alert.show("📌 Note removed")
            else hs.alert.show("📌 Nothing to remove on this window") end
            return true
        end
        local result = wp.set(text, winId)
        if result:find("bound to window", 1, true) then
            hs.alert.show("📌 Pinned to " .. (label or "this window"))
            return true
        end
        hs.alert.show(result, 3)      -- over maxChars, or the window went away
        return false
    end

    -- Read back and verified, never assumed — AppKit silently drops style
    -- bits it will not honour. Same shape as the Capture Pad's; the
    -- arithmetic rather than 5.3's `&` because this runs on whatever Lua
    -- the installed Hammerspoon was built with.
    function wp.applyNonActivating(view)
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
            if not pcall(function() view:windowStyle(cur + bit) end) then
                return false, "the window style was rejected"
            end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then
            return false, "the window style could not be read back"
        end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    local function esc(s)
        return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
                                 :gsub(">", "&gt;"):gsub('"', "&quot;"))
    end

    -- 🚨 THE BOX IS MONOSPACE AT THE NOTE'S OWN WRAP WIDTH. What you see
    -- wrapping in the editor is what the note will do on screen — the
    -- whole complaint was not being able to see what you were typing.
    function wp.editorHtml(opts)
        local st = style()
        return table.concat({
[[<meta charset="utf-8"><style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:14px; background:#141418; color:#e8e8ec; }
  header { padding:12px 18px 8px; border-bottom:1px solid #2a2a32;
           cursor:grab; user-select:none; -webkit-user-select:none; }
  header:active, header.dragging { cursor:grabbing; }
  h1 { font-size:15px; margin:0 0 2px; font-weight:600; }
  .grip { color:#4a4a56; margin-right:8px; letter-spacing:2px; }
  .sub { color:#8a8a96; font-size:12px; }
  #wrap { padding:12px 18px 14px; }
  /* Longhand font rules on purpose — the shorthand+keyword mix is the
     invalid combination WebKit drops whole (the 6.44.1 textarea bug). */
  textarea { width:100%; box-sizing:border-box; resize:none;
             background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
             border-radius:8px; padding:11px;
             font-family:Menlo,ui-monospace,monospace;
             line-height:1.45; }
  textarea:focus { outline:none; border-color:#4a7fe0; }
  .bar { margin-top:11px; display:flex; gap:9px; align-items:center; }
  .count { color:#8a8a96; font-size:12px; margin-right:auto;
           font-variant-numeric:tabular-nums; }
  .count.over { color:#ff8f8f; font-weight:600; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:7px 13px; font-size:13px; cursor:pointer; }
  button:hover { filter:brightness(1.18); }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  button.rm { background:#4a2530; border-color:#6b3542; }
  button:disabled { opacity:.45; cursor:default; }
</style>
<header id="hdr"><h1><span class="grip">⠿</span>]],
            esc(opts.title),
[[</h1><div class="sub">]], esc(opts.sub), [[</div></header>
<div id="wrap">
  <textarea id="t" rows="]], tostring(opts.rows or 8),
            [[" spellcheck="false" placeholder="Type the note. Newlines are fine.">]],
            esc(opts.text), [[</textarea>
  <div class="bar">
    <span class="count" id="c"></span>]],
            opts.hasNote
              and [[<button type="button" class="rm" onclick="say({a:'remove'})">Remove note</button>]]
              or  "",
[[    <button type="button" onclick="say({a:'cancel'})">Cancel (Esc)</button>
    <button type="button" class="go" id="ok" onclick="save()">Pin it (⌘⏎)</button>
  </div>
</div>
<script>
  var MAX = ]], tostring(opts.maxChars or 400), [[;
  var COLS = ]], tostring(opts.cols or 43), [[;
  var t = document.getElementById('t'), c = document.getElementById('c'),
      ok = document.getElementById('ok');
  function say(m) {
    try { webkit.messageHandlers.winPin.postMessage(m); } catch (e) {}
  }
  /* The count is the point of the box: maxChars REFUSES the pin, and
     finding that out from an alert after typing 400 characters is the
     worst possible time to learn it. */
  function tally() {
    var n = Array.from(t.value).length;
    c.textContent = n + ' / ' + MAX + ' characters';
    c.className = n > MAX ? 'count over' : 'count';
    ok.disabled = n > MAX;
  }
  function save() {
    if (Array.from(t.value).length > MAX) return;
    say({ a: 'save', text: t.value });
  }
  t.addEventListener('input', tally);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { say({ a: 'cancel' }); return; }
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); save(); }
  });
  /* The header is the title bar: hs.webview windows are borderless, and a
     WKWebView loses the mouse the moment the pointer leaves it, so the
     drag is finished on the Lua side. */
  document.getElementById('hdr').addEventListener('mousedown', function () {
    say({ a: 'drag' });
  });
  t.style.fontSize = ']], tostring(opts.font or 15), [[px';
  /* Sized so the box is exactly as wide as the note wraps. */
  t.setAttribute('cols', COLS);
  t.focus();
  t.setSelectionRange(t.value.length, t.value.length);
  tally();
</script>]],
        })
    end

    -- ---- dragging the editor by its header --------------------------------
    -- A WKWebView loses the mouse the moment the pointer leaves it, so the
    -- page only says "a drag started" and the move is driven from here.
    -- Same shape as the Capture Pad's and the Quick Append Pad's; there is
    -- no shared helper to call, and a header wearing a ⠿ grip that did
    -- nothing would be worse than a header without one.
    local function mousePosition()
        local fns = {}
        if hs.mouse then
            if type(hs.mouse.absolutePosition) == "function" then
                fns[#fns + 1] = hs.mouse.absolutePosition
            end
            if type(hs.mouse.getAbsolutePosition) == "function" then
                fns[#fns + 1] = hs.mouse.getAbsolutePosition
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

    function wp.endDrag()
        if wp.dragTimer then pcall(function() wp.dragTimer:stop() end) end
        wp.dragTimer, wp.dragOffset = nil, nil
    end

    function wp.beginDrag()
        if not wp.editorView then return false end
        local okF, f = pcall(function() return wp.editorView:frame() end)
        if not (okF and type(f) == "table") then return false end
        local m = mousePosition()
        if not m then return false end
        wp.endDrag()                    -- BEFORE the offset: endDrag clears it
        wp.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        local okT = pcall(function()
            wp.dragTimer = hs.timer.doEvery(0.016, function()
                if not (wp.editorView and wp.dragOffset) then wp.endDrag() return end
                if not leftButtonDown() then wp.endDrag() return end
                local p = mousePosition()
                if not p then wp.endDrag() return end
                pcall(function()
                    local cur = wp.editorView:frame()
                    wp.editorView:frame({ x = p.x - wp.dragOffset.x,
                                          y = p.y - wp.dragOffset.y,
                                          w = cur.w, h = cur.h })
                end)
            end)
        end)
        if not (okT and wp.dragTimer) then wp.endDrag() return false end
        return true
    end

    function wp.closeEditor()
        wp.endDrag()
        if wp.editorView then
            pcall(function() wp.editorView:delete() end)
        end
        wp.editorView, wp.editorUc, wp.editorFor = nil, nil, nil
    end

    -- A Mac with no webview must still be able to pin. Smaller box, same
    -- meaning — wp.applyEdit decides both.
    local function promptFallback(winId, existing, label)
        local okDlg, button, input = pcall(hs.dialog.textPrompt,
            existing and "Edit this window's note" or "Pin a note to this window",
            "It follows this window only. Clear the box to remove it.",
            existing or "", "OK", "Cancel")
        if not okDlg then
            warn("hs.dialog.textPrompt failed")
            hs.alert.show("📌 Window Pin: the prompt would not open — see the Console")
            return false
        end
        if button ~= "OK" then return false end
        return wp.applyEdit(winId, input, label)
    end

    function wp.openEditor(winId, existing, label)
        if not (hs.webview and hs.webview.usercontent) then
            return promptFallback(winId, existing, label)
        end
        wp.closeEditor()                       -- never two at once

        -- Opened over the window it belongs to, not the middle of the main
        -- screen: on three monitors "where did the box go" is a real cost.
        local rect
        pcall(function()
            local win = hs.window.get(winId)
            local wf  = win and win:frame()
            local sf  = win and win:screen() and win:screen():frame()
            local w, h = wp.editorW, wp.editorH
            if wf then
                rect = { x = wf.x + (wf.w - w) / 2, y = wf.y + (wf.h - h) / 2,
                         w = w, h = h }
            elseif sf then
                rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2,
                         w = w, h = h }
            end
            if rect and _G.clampToScreen then
                local p = _G.clampToScreen({ x = rect.x, y = rect.y }, w, h)
                if p then rect.x, rect.y = p.x, p.y end
            end
        end)
        rect = rect or { x = 200, y = 200, w = wp.editorW, h = wp.editorH }

        local okUc, uc = pcall(hs.webview.usercontent.new, "winPin")
        if not (okUc and uc) then return promptFallback(winId, existing, label) end
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(wp.handleMessage, msg and msg.body)
                if not ok then
                    print("📌 Window Pin: message handler — " .. tostring(err))
                end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then return promptFallback(winId, existing, label) end
        wp.editorUc, wp.editorView, wp.editorFor = uc, view, { id = winId, label = label }

        pcall(function() view:windowTitle("Window Pin") end)
        -- allowTextEntry sets canBecomeKeyWindow — without it the box draws
        -- perfectly and swallows every keystroke.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        if wp.nonActivating then
            -- 🚨 THIS ONE EARNS ITS KEEP HERE. wp.isShowing() hides a note
            -- unless its app is frontmost, so an editor that dragged
            -- Hammerspoon forward would pin the note and then hide it —
            -- which is exactly the "did that work?" this version is fixing.
            local okNA, why = wp.applyNonActivating(view)
            if not okNA then
                print("📌 Window Pin: non-activating panel unavailable — "
                      .. tostring(why) .. "; the note may not appear until you "
                      .. "click back into the window.")
            end
        end
        pcall(function()
            view:html(wp.editorHtml({
                title    = existing and "Edit this window's note"
                                    or "Pin a note to this window",
                sub      = "It follows " .. (label or "this window")
                           .. " only  ·  empty the box to remove it",
                text     = existing or "",
                hasNote  = existing ~= nil and existing ~= "",
                maxChars = wp.maxChars,
                cols     = wp.wrapCols(),
                font     = wp.editorFont,
                rows     = 8,
            }))
        end)
        pcall(function() view:show() end)
        pcall(function() view:bringToFront(true) end)
        say("editor opened for window " .. tostring(winId))
        return true
    end

    function wp.handleMessage(body)
        if type(body) ~= "table" then return end
        local target = wp.editorFor
        if body.a == "drag" then pcall(wp.beginDrag) return end
        if body.a == "cancel" then wp.closeEditor() return end
        if not target then return end
        if body.a == "remove" then
            wp.closeEditor()
            wp.applyEdit(target.id, "", target.label)
            return
        end
        if body.a == "save" then
            wp.closeEditor()
            wp.applyEdit(target.id, body.text, target.label)
        end
    end

    -- ⇪⇧U. One key, three outcomes — see the header.
    function wp.pin()
        if not wp.enabled then return false end
        if not axOK then
            hs.alert.show("📌 Window Pin needs Accessibility — see _G.capabilityReport()", 4)
            return false
        end
        -- Already open on this key? Treat ⇪⇧U as a toggle rather than
        -- stacking a second box over the first.
        if wp.editorView then wp.closeEditor() return true end
        local win
        pcall(function() win = hs.window.focusedWindow() end)
        if not win then
            hs.alert.show("📌 Window Pin: no window is focused")
            return false
        end
        local winId
        pcall(function() winId = win:id() end)
        if not winId then
            hs.alert.show("📌 Window Pin: that window has no id to pin to")
            return false
        end

        -- 🚨 THE ID AND THE LABEL ARE TAKEN NOW, while the window is still
        -- the focused one. The editor may take focus (on a Hammerspoon with
        -- no nonactivating mask), and wp.set is given the id either way, so
        -- the note can never land on whatever ended up in front instead.
        local label
        pcall(function()
            local t = win:title()
            label = (t and t ~= "") and t:sub(1, 24)
                    or (win:application() and win:application():name())
        end)
        local existing = wp.pins[winId]
        return wp.openEditor(winId, existing and existing.text or nil, label)
    end

    -- Split "no window found" into its two meanings, because they need
    -- opposite handling:
    --   dead  — the owning APPLICATION exited, so the note can never apply
    --   stale — the app is alive but the window will not resolve. Could be
    --           a background tab (comes back) or a closed one (never does)
    function wp.classify()
        local dead, stale = {}, {}
        for winId, p in pairs(wp.pins) do
            local win
            pcall(function() win = hs.window.get(winId) end)
            if not win then
                local alive = false
                pcall(function()
                    alive = p.appPid ~= nil
                            and hs.application.applicationForPID(p.appPid) ~= nil
                end)
                table.insert(alive and stale or dead, { id = winId, pin = p })
            end
        end
        return dead, stale
    end

    -- Move a note from a window that no longer resolves onto the window in
    -- front of you. Closing and reopening a tab gives it a NEW id, which
    -- strands the old note; this reattaches the text instead of making you
    -- retype it. With no argument it only picks automatically when exactly
    -- one note is definitely dead — anything stale is listed rather than
    -- chosen, because a stale note may belong to a tab that is coming back.
    function wp.rebind(fromWinId)
        local win
        pcall(function() win = hs.window.focusedWindow() end)
        if not win then return "📌 Window Pin: no focused window" end

        local dead, stale = wp.classify()
        local src
        if fromWinId then
            for _, o in ipairs(dead)  do if o.id == fromWinId then src = o end end
            for _, o in ipairs(stale) do if o.id == fromWinId then src = o end end
            if not src then
                return "📌 Window Pin: id " .. tostring(fromWinId)
                       .. " is not a movable note"
            end
        elseif #dead == 1 and #stale == 0 then
            src = dead[1]
        else
            local lines = { "📌 Window Pin — pick an id to move here"
                            .. " (stale ones may just be background tabs):" }
            for _, o in ipairs(dead) do
                lines[#lines + 1] = string.format("  _G.winPin.rebind(%d)  -- dead   %s",
                    o.id, o.pin.text:gsub("\n", "\\n"):sub(1, 24))
            end
            for _, o in ipairs(stale) do
                lines[#lines + 1] = string.format("  _G.winPin.rebind(%d)  -- stale  %s",
                    o.id, o.pin.text:gsub("\n", "\\n"):sub(1, 24))
            end
            if #lines == 1 then return "📌 Window Pin: nothing to move" end
            return table.concat(lines, "\n")
        end

        local text = src.pin.text
        wp.remove(src.id, true)
        return wp.set(text)
    end

    -- Drop notes whose APPLICATION exited. Notes whose window merely will
    -- not resolve are kept — that is also what a backgrounded tab is.
    function wp.prune()
        local dead, stale = wp.classify()
        for _, o in ipairs(dead) do wp.remove(o.id, true) end
        return string.format(
            "📌 Window Pin: removed %d (application gone); kept %d not resolvable right now",
            #dead, #stale)
    end

    function wp.unpinAll()
        local n = 0
        for winId in pairs(wp.pins) do
            if wp.remove(winId, true) then n = n + 1 end
        end
        hs.alert.show(n > 0 and ("📌 Removed " .. n .. " notes")
                             or "📌 Nothing to remove")
        return n
    end

    -- One line per note: id, app, text, and whether it is on screen right
    -- now. Start here when a note is not where you expect it — every
    -- answer this module can give is in this output, including the calls.
    function wp.status()
        if not next(wp.pins) then
            return "📌 Window Pin: no notes. ⇪⇧U pins one to the window in front."
        end
        local out = {}
        for winId, p in pairs(wp.pins) do
            local win
            pcall(function() win = hs.window.get(winId) end)
            out[#out + 1] = string.format(
                "  id=%s [%s] %q — window %s, showing %s",
                tostring(winId), tostring(p.appName or "?"),
                (p.text or ""):gsub("\n", "\\n"):sub(1, 30),
                win and "present" or "not found (background tab or closed)",
                win and tostring(wp.isShowing(win)) or "false")
        end
        table.sort(out)
        table.insert(out, 1, "📌 Window Pin — " .. #out .. " note(s):")
        out[#out + 1] = "  _G.winPin.rebind()   move a stranded note onto this window"
        out[#out + 1] = "  _G.winPin.prune()    forget notes whose app has quit"
        out[#out + 1] = "  _G.winPin.unpinAll() remove every note"
        return table.concat(out, "\n")
    end

    -- ---- restore ----------------------------------------------------------
    -- Notes whose window is gone stay LOADED but hidden, so their text
    -- survives a reload until you rebind or prune them.
    function wp.restore()
        local saved
        pcall(function() saved = hs.settings.get(SETTINGS_KEY) end)
        if type(saved) ~= "table" then return 0 end
        local n = 0
        for idStr, rec in pairs(saved) do
            local winId = tonumber(idStr)
            -- Validated on the way in: a half-written blob must not reach
            -- buildCanvas as a nil text and take setup() down with it.
            if winId and type(rec) == "table"
               and type(rec.text) == "string" and rec.text ~= "" then
                wp.pins[winId] = {
                    id      = winId,
                    text    = rec.text,
                    appPid  = tonumber(rec.appPid),
                    appName = type(rec.appName) == "string" and rec.appName or nil,
                    title   = type(rec.title)   == "string" and rec.title   or nil,
                    canvas  = wp.buildCanvas(rec.text),
                }
                n = n + 1
            end
        end
        wp.restored = n
        return n
    end

    -- ---- wiring -----------------------------------------------------------
    if not wp.enabled then
        _G.winPin = wp
        M.config  = wp
        return
    end

    if not axOK then
        -- Stand down completely, and say what it costs. capabilities.lua
        -- already reports the gate; this makes the key honest instead of
        -- silent.
        core.hyperAddShortcut({ "shift" }, wp.key, function()
            hs.alert.show("📌 Window Pin is off — Accessibility is not granted", 4)
        end, "window pin (Accessibility off)")
        _G.pins = function()
            print("📌 Window Pin: off — macOS Accessibility is not granted to "
                  .. "Hammerspoon, so no window's position can be read. "
                  .. "_G.capabilityReport() has the detail.")
        end
        if _G.notices then
            _G.notices.record("winPin", "Accessibility off",
                              "notes cannot follow windows")
        end
        say("Accessibility is off — nothing started")
        _G.winPin = wp
        M.config  = wp
        return
    end

    local restored = wp.restore()
    if restored > 0 then wp.tick() end

    core.hyperAddShortcut({ "shift" }, wp.key, function() wp.pin() end, "window pin")

    core.provide("winPin.pin",      function() return wp.pin() end)
    core.provide("winPin.unpinAll", function() return wp.unpinAll() end)

    _G.winPin = wp
    _G.pins   = function() print(wp.status()) end
    M.config  = wp

    if restored > 0 then say(string.format("%d note(s) restored", restored)) end
end

return M
