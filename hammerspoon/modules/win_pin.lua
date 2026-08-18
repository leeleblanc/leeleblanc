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
--   ⇪⇧U on a window with no note   → prompts, pins what you type
--   ⇪⇧U on a window that HAS one   → prompts pre-filled, edits it
--   ⇪⇧U, then clear the box, OK    → removes that window's note
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
            { "clear", "Empty the box and OK — that window's note is removed" },
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
    wp.maxChars     = 400       -- a longer note is refused rather than drawn off-screen
    -- Hide a note unless its app is frontmost. Leave this ON: the canvas
    -- floats above every window, so a note left visible while its window
    -- sits behind another app looks pinned to the WRONG one.
    wp.onlyWhenAppFocused = true
    wp.followFast   = 0.05      -- seconds between checks while a note is VISIBLE
    wp.followIdle   = 0.5       -- …and while every note is hidden (see ⚖️ 1)
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
        c[2] = {
            type      = "text",
            text      = text,
            textFont  = wp.fontName,
            textSize  = wp.fontSize,
            textColor = st.fg,
            frame     = { x = 0, y = 0, w = 100, h = 100 },
        }

        local w, h = 220, 60
        pcall(function()
            local size = c:minimumTextSize(2, text)
            if size and size.w and size.h then
                w = math.ceil(size.w) + wp.padding * 2
                h = math.ceil(size.h) + wp.padding * 2
            end
        end)

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
        return { x = x, y = y, w = w, h = h }
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

    -- ⇪⇧U. One key, three outcomes — see the header.
    function wp.pin()
        if not wp.enabled then return false end
        if not axOK then
            hs.alert.show("📌 Window Pin needs Accessibility — see _G.capabilityReport()", 4)
            return false
        end
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

        local existing = wp.pins[winId]
        local okDlg, button, input = pcall(hs.dialog.textPrompt,
            existing and "Edit this window's note" or "Pin a note to this window",
            "It follows this window only. Clear the box to remove it. Newlines are fine.",
            existing and existing.text or "",
            "OK", "Cancel")
        if not okDlg then
            warn("hs.dialog.textPrompt failed")
            hs.alert.show("📌 Window Pin: the prompt would not open — see the Console")
            return false
        end
        if button ~= "OK" then return false end

        if input == nil or input == "" then
            if wp.remove(winId, true) then hs.alert.show("📌 Note removed")
            else hs.alert.show("📌 Nothing to remove on this window") end
            return true
        end

        local result = wp.set(input, winId)
        if result:find("bound to window", 1, true) then
            local label
            pcall(function()
                local t = win:title()
                label = (t and t ~= "") and t:sub(1, 24)
                        or (win:application() and win:application():name())
            end)
            hs.alert.show("📌 Pinned to " .. (label or "this window"))
            return true
        end
        hs.alert.show(result, 3)
        return false
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
