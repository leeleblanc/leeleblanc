-- =====================================================================
-- MODULE: EDITOR PICKER (⌘⌘, or ⇪⇧Z) — every text surface this config owns
-- =====================================================================
-- LL: "Right now a double-click of the cmd+cmd key pressed quickly.
-- Could I bring up all my editor windows up and then let me select the
-- one I need to copy from or edit from?"
--
-- Tap ⌘ twice, quickly, touching nothing else. A picker opens listing
-- every editor this config owns — the Capture Pad, the Note Pad, the OCR
-- text store, clipboard history, window pins, the screenshot editor —
-- with how much is in each one. ⏎ opens the one you chose (or brings it
-- to the front if it is already up). ⌥⏎ copies its text WITHOUT opening
-- anything, which is the "copy from" half of the ask.
--
--        ⌘⌘         the picker
--        ⇪⇧Z        the same picker, for when the tap is unavailable
--        ⏎          open it / bring it forward
--        ⌥⏎         copy its text and stay where you are
--
-- ⌨️ AND ⇪⇧Z IS THE LAST FREE LETTER, not a mnemonic. ⇪E was the obvious
-- one and §0.4's migration map has held it since long before this module
-- existed (it edits a custom cheat sheet entry) — the hotkey sentry said
-- so on the first run of the suite, which is the whole reason that sentry
-- is there. Z is what was left. The gesture you are meant to learn is
-- ⌘⌘; this key is the handrail for the days the tap is not running.
--
-- ---- 🚨 WHY ⌘⌘ NEEDS TO WATCH keyDown AS WELL AS THE MODIFIERS -------
-- The obvious build watches flagsChanged only: ⌘ goes down, ⌘ comes up,
-- twice inside a third of a second, fire. It is wrong, and wrong in the
-- most common keystroke sequence there is.
--
--        ⌘C then ⌘V     cmd↓ · c · cmd↑ · cmd↓ · v · cmd↑
--        ⌘ tapped twice cmd↓ ·   · cmd↑ · cmd↓ ·   · cmd↑
--
-- A flagsChanged-only tap CANNOT SEE THE MIDDLE COLUMN. Those two rows
-- are byte-identical to it, so copy-then-paste — which everybody does
-- forty times a day — would open a picker over whatever you were doing.
-- Timing does not separate them either: copy-paste is fast, on purpose.
--
-- So this tap subscribes to keyDown too, and the entire keyDown branch
-- is two assignments and a `return false`. That makes it the FOURTH
-- global keyboard tap in this config (autocorrect, the text expander,
-- the Key Caster) and it is held to every rule the other three follow —
-- see the 🛟 block at the tap itself.
--
-- ⚠️ AND IT IS NOT ALLOWED TO BE THE ONLY WAY IN. An event tap needs
-- Accessibility, and macOS switches taps off when it feels like it. ⇪⇧Z
-- opens the same picker through the ordinary hotkey path, so the feature
-- survives the tap being dead — and ⇪⇧D says which of the two you have.
--
-- ---- WHAT COUNTS AS AN EDITOR ---------------------------------------
-- Whatever registers itself. Modules insert into _G.editors the same way
-- they insert into _G.movablePanels, so this file holds no list of other
-- modules and a module that is not loaded contributes no dead row:
--
--     _G.editors = _G.editors or {}
--     table.insert(_G.editors, {
--         name  = "Capture Pad",
--         key   = "⇪N",
--         what  = "notes waiting for the 4 PM send",
--         order = 20,
--         view  = function() return pad.webview end,   -- nil = not open
--         show  = function() pad.show() end,           -- open it
--         size  = function() return #(pad.draft or "") end,
--         text  = function() return pad.draft end,     -- what ⌥⏎ copies
--     })
--
-- 🚨 `view` AND `show` ARE TWO FIELDS BECAUSE show() TOGGLES. pad.show()
-- and np.show() CLOSE an open pad — which is right for their own key and
-- exactly wrong here: picking "Capture Pad" out of a list of editors, to
-- go and read it, must never be the keystroke that files it. So the
-- picker asks `view` first and brings that window forward; `show` is
-- only ever called on a surface that is not currently up.
-- =====================================================================

local M = {
    name  = "Editor Picker",
    order = 13.34,
    family = "text",
    cheatsheet = {
        title = "🗂 EDITOR PICKER (⌘⌘ — every editor at once)",
        entries = {
            { "⌘⌘",  "Tap ⌘ twice, touching nothing else — the picker opens" },
            { "⇪⇧Z", "The same picker, when the ⌘⌘ tap is unavailable" },
            { "⏎",   "Open it — or bring it forward if it is already up" },
            { "⌥⏎",  "Copy that editor's text and leave everything closed" },
            { "lists", "Capture Pad · Note Pad · OCR text · clipboard · pins" },
            { "sorted", "Open windows first, then whatever has something in it" },
            { "never", "⌘C then ⌘V does NOT open it — see the header" },
            { "check", "_G.editorPickerReport() — the roster and the tap's health" },
        },
    },
}

function M.setup(core)
    local ep = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ep.enabled     = true    -- false = no tap, no key, nothing bound
    ep.tapEnabled  = true    -- false = ⇪⇧Z only; the ⌘⌘ tap is never created
    ep.key         = "z"     -- ⇪⇧Z, the tap-free way in (see the header)
    ep.keyMods     = { "shift" }
    -- ⏱ Two windows, and they are different questions. maxHold is "was
    -- that ⌘ a TAP or a HOLD" — a modifier you are holding down to use is
    -- down for as long as you are reading the menu. tapGap is "were those
    -- two taps one gesture". Both are deliberately tight: every
    -- millisecond of slack here is a millisecond in which a real ⌘ chord
    -- can be mistaken for half of a gesture.
    ep.maxHold     = 0.35    -- a tap is ⌘ down and up inside this
    ep.tapGap      = 0.35    -- and the second tap lands inside this
    ep.failLimit   = 5       -- consecutive callback throws before standing down
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("editors", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("editors", m) end end

    -- The registry. Created with `or` on purpose — modules insert into it
    -- directly, so nothing here depends on load order and this module can
    -- load before or after any of them.
    _G.editors = _G.editors or {}

    -- =================================================================
    -- 🗂 THE ROSTER
    -- =================================================================
    -- Every field except `name` is optional, and every one of them is
    -- called inside a pcall: a registration written by a module that is
    -- half-loaded, or whose window was deleted underneath it, must cost
    -- one greyed row and not the whole picker.
    local function callField(e, field, default)
        local fn = e[field]
        if type(fn) ~= "function" then return default end
        local ok, v = pcall(fn)
        if not ok then return default end
        return v
    end

    -- One editor's live state, with every question already answered.
    local function stateOf(e)
        local view = callField(e, "view", nil)
        local size = callField(e, "size", nil)
        if type(size) ~= "number" then size = nil end
        return {
            entry = e,
            name  = tostring(e.name or "?"),
            key   = tostring(e.key or ""),
            what  = tostring(e.what or ""),
            unit  = tostring(e.unit or "characters"),
            order = tonumber(e.order) or 500,
            open  = view ~= nil,
            size  = size,
        }
    end

    -- 🔢 THE SORT IS THE FEATURE. A picker that always lists the same six
    -- rows in the same order is a menu; this one puts what you are most
    -- likely to have meant at the top. Open windows first (you were just
    -- in one of them), then anything holding text, then the empty ones,
    -- and only inside each band does the module's declared order decide.
    local function rank(s)
        if s.open then return 0 end
        if (s.size or 0) > 0 then return 1 end
        return 2
    end

    function ep.states()
        local out = {}
        for _, e in ipairs(_G.editors or {}) do
            if type(e) == "table" and e.name then out[#out + 1] = stateOf(e) end
        end
        table.sort(out, function(a, b)
            local ra, rb = rank(a), rank(b)
            if ra ~= rb then return ra < rb end
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)
        return out
    end

    local function plural(n, unit)
        if n == 1 and unit:sub(-1) == "s" then unit = unit:sub(1, -2) end
        return string.format("%d %s", n, unit)
    end

    function ep.rows()
        local rows = {}
        for _, s in ipairs(ep.states()) do
            local bits = {}
            if s.key ~= "" then bits[#bits + 1] = s.key end
            if s.open then bits[#bits + 1] = "OPEN NOW" end
            if s.size == nil then
                -- No size function is not the same as an empty editor, and
                -- saying "empty" for it would be a small lie about somebody
                -- else's data. It says nothing instead.
            elseif s.size > 0 then
                bits[#bits + 1] = plural(s.size, s.unit)
            else
                bits[#bits + 1] = "empty"
            end
            if s.what ~= "" then bits[#bits + 1] = s.what end
            rows[#rows + 1] = {
                text    = (s.open and "● " or "") .. s.name,
                subText = table.concat(bits, " · "),
                edName  = s.name,
            }
        end
        if #rows == 0 then
            rows[1] = { text = "No editors registered",
                        subText = "Nothing inserted into _G.editors — "
                                  .. "see _G.editorPickerReport()" }
        end
        return rows
    end

    -- =================================================================
    -- 🎬 ACTING ON A ROW
    -- =================================================================
    local function entryNamed(name)
        for _, e in ipairs(_G.editors or {}) do
            if type(e) == "table" and tostring(e.name or "") == name then return e end
        end
        return nil
    end

    -- Bring an open webview to the front. hs.webview windows are ordinary
    -- NSWindows underneath, but only some builds expose hswindow(), so
    -- both routes are tried and neither is required.
    local function front(view)
        pcall(function() view:bringToFront(true) end)
        pcall(function()
            local w = view:hswindow()
            if w then w:focus() end
        end)
    end

    -- ⏎ — open it, or bring it forward. Never show() an open surface: for
    -- the two pads that is the keystroke that FILES the draft.
    function ep.open(name)
        local e = entryNamed(name)
        if not e then return false end
        local view = callField(e, "view", nil)
        if view ~= nil then
            front(view)
            say("brought " .. name .. " forward")
            return true
        end
        if type(e.show) ~= "function" then
            hs.alert.show("🗂 " .. name .. " has no way to open")
            return false
        end
        local ok, err = pcall(e.show)
        if not ok then
            warn(name .. " would not open: " .. tostring(err))
            hs.alert.show("🗂 " .. name .. " would not open — see the Console")
            return false
        end
        say("opened " .. name)
        return true
    end

    -- ⌥⏎ — the "copy from" half. Nothing opens, nothing closes, and an
    -- editor with no text function says so rather than silently copying
    -- an empty string over whatever you already had on the clipboard.
    function ep.copy(name)
        local e = entryNamed(name)
        if not e then return false end
        if type(e.text) ~= "function" then
            hs.alert.show("🗂 " .. name .. " has no text to copy")
            return false
        end
        local ok, txt = pcall(e.text)
        if not ok or type(txt) ~= "string" or txt == "" then
            hs.alert.show("🗂 " .. name .. " is empty — clipboard untouched")
            return false
        end
        local okSet = pcall(function() return hs.pasteboard.setContents(txt) end)
        if not okSet then
            warn("could not put " .. name .. " on the clipboard")
            hs.alert.show("🗂 Could not reach the clipboard")
            return false
        end
        hs.alert.show(string.format("📋 Copied %s — %d characters", name, #txt))
        say("copied " .. name .. " (" .. #txt .. " chars)")
        return true
    end

    -- =================================================================
    -- 🗂 THE PICKER
    -- =================================================================
    function ep.show()
        if not ep.chooser then
            ep.chooser = hs.chooser.new(function(pick)
                if not pick or not pick.edName then return end
                -- The modifiers are read HERE rather than remembered from
                -- a keystroke: the chooser owns the keyboard while it is
                -- up, and this callback runs on the press that dismissed
                -- it, so this is the only moment ⌥ can honestly be read.
                local mods = {}
                pcall(function() mods = hs.eventtap.checkKeyboardModifiers() or {} end)
                if mods.alt then return ep.copy(pick.edName) end
                return ep.open(pick.edName)
            end)
            -- ⎋ 6.116.0 — filed in _G.choosers so the router closes it
            -- before the cheat sheet, like every other picker here.
            _G.choosers = _G.choosers or {}
            _G.choosers.editorPicker = ep.chooser
            pcall(function()
                ep.chooser:searchSubText(true)
                ep.chooser:width(32)
            end)
        end
        ep.chooser:choices(ep.rows())
        ep.chooser:placeholderText("Your editors — ⏎ opens, ⌥⏎ copies")
        if core.showPopup then core.showPopup(ep.chooser) else ep.chooser:show() end
        return true
    end

    -- =================================================================
    -- ⌘⌘ THE DOUBLE TAP
    -- =================================================================
    -- 🛟 THE SAME FOUR RULES THE OTHER THREE TAPS FOLLOW:
    --
    --   · IT NEVER CONSUMES A KEYSTROKE. There is exactly one `return`
    --     in the callback and it returns false. Everything else runs
    --     inside a pcall above it, so a throw cannot reach the return —
    --     which matters more here than anywhere else in this config,
    --     because this tap sees keyDown and a tap that ate keyDown would
    --     take the keyboard away entirely.
    --   · IT NEVER LOOKS AT WHICH KEY. The keyDown branch reads no
    --     keycode and no characters. It records THAT a key happened, and
    --     that is the whole of its interest in your typing.
    --   · IT STANDS DOWN FOR THE SHARED INJECTION GUARD, so the
    --     expander's and autocorrect's synthetic keys — and §3.12's boot
    --     self-test, which posts four of them — cannot assemble a
    --     gesture you did not make.
    --   · IT DISABLES ITSELF RATHER THAN DEGRADING YOUR KEYBOARD.
    --     failLimit consecutive throws and it stops and reports, and ⇪⇧Z
    --     still works, because the feature never depended on it.
    ep.tapFailures = 0
    ep.tapRunning  = false
    ep.fires       = 0
    local cmdDownAt, dirty, lastTapAt = nil, false, 0

    -- Exposed so the tests can drive the state machine without an event
    -- tap, and so ⇪⇧D can reset it after a machine wakes up confused.
    function ep.resetTapState()
        cmdDownAt, dirty, lastTapAt = nil, false, 0
    end

    -- The state machine, called with a plain flags table and a wall clock.
    -- Returns true on the frame that completes a double tap.
    function ep.onFlags(flags, now)
        flags = flags or {}
        local cmd     = flags.cmd == true
        local others  = (flags.shift or flags.alt or flags.ctrl or flags.fn) == true
        if cmd and cmdDownAt == nil then
            cmdDownAt = now
            dirty     = others          -- ⌘ arriving alongside ⇧ is not a tap
        elseif cmd and cmdDownAt ~= nil then
            if others then dirty = true end   -- ⇧ joined a held ⌘
        elseif not cmd and cmdDownAt ~= nil then
            local held = now - cmdDownAt
            cmdDownAt = nil
            if dirty or others or held > ep.maxHold then
                -- Not a tap, and it also breaks any sequence in progress:
                -- ⌘-tap then ⌘X must not leave half a gesture armed for
                -- the next ⌘-tap a minute later.
                lastTapAt = 0
                dirty = false
                return false
            end
            dirty = false
            if lastTapAt > 0 and (now - lastTapAt) <= ep.tapGap then
                lastTapAt = 0
                return true
            end
            lastTapAt = now
        end
        return false
    end

    -- Any real key press means the ⌘ around it was a chord, not a tap —
    -- and it cancels a sequence already half-made.
    function ep.onKeyDown()
        dirty     = true
        lastTapAt = 0
    end

    function ep.fire()
        ep.fires = ep.fires + 1
        ep.show()
    end

    -- The body of the tap, kept OUT of the callback so the callback is
    -- nothing but `pcall(onEvent, ev)` and a `return false`. That is the
    -- shape the Key Caster, autocorrect and the expander all use, and the
    -- one hs-lint's eventtap-callback-unguarded rule recognises.
    local function onEvent(ev)
        -- Synthetic keys are not gestures. Checked FIRST, before any state
        -- is touched, so an injection cannot even cancel a sequence — it is
        -- simply not there.
        if _G.typingInjection and _G.typingInjection() then return end
        -- ⇪ is F18 plus a synthetic ⌘⇧⌃⌥ chord (§3.12). `others` already
        -- rejects it, but saying so here means a change to the hyper
        -- implementation cannot quietly make ⇪ look like a bare ⌘ tap.
        if _G.hyperActive then ep.resetTapState() return end
        local t = ev:getType()
        if t == hs.eventtap.event.types.keyDown then
            ep.onKeyDown()
            return
        end
        local flags = ev:getFlags() or {}
        if ep.onFlags(flags, hs.timer.secondsSinceEpoch()) then
            ep.fire()
        end
    end

    -- 🚨 EVERY PATH RETURNS false. This tap watches; it never consumes —
    -- and it sees keyDown, so a path that returned true would take the
    -- keyboard away entirely rather than break one feature.
    function ep.handler(ev)
        local ok, err = pcall(onEvent, ev)
        if ok then
            ep.tapFailures = 0
            return false
        end
        ep.tapFailures = ep.tapFailures + 1
        if ep.tapFailures >= ep.failLimit then
            ep.stopTap()
            print("🗂 Editor picker: the ⌘⌘ watcher threw "
                  .. ep.failLimit .. " times in a row and has been "
                  .. "switched off. ⇪⇧Z still opens the picker. "
                  .. "Last error: " .. tostring(err))
            if _G.notices then
                pcall(_G.notices.record, "runtime", "editor picker",
                      "⌘⌘ watcher disabled after repeated failures")
            end
        end
        return false
    end

    function ep.startTap()
        if not (ep.enabled and ep.tapEnabled) then return false end
        local okNew, tap = pcall(hs.eventtap.new, {
            hs.eventtap.event.types.keyDown,
            hs.eventtap.event.types.flagsChanged,
        }, function(ev) return ep.handler(ev) end)
        if not (okNew and tap) then
            warn("could not create the ⌘⌘ watcher — ⇪⇧Z still works")
            return false
        end
        ep.tap = tap
        local okStart = pcall(function() tap:start() end)
        ep.tapRunning = okStart and true or false
        if not okStart then
            warn("the ⌘⌘ watcher would not start — ⇪⇧Z still works")
        end
        return ep.tapRunning
    end

    function ep.stopTap()
        if ep.tap then pcall(function() ep.tap:stop() end) end
        ep.tapRunning = false
        ep.resetTapState()
    end

    -- =================================================================
    -- 🩺 REPORT
    -- =================================================================
    function _G.editorPickerReport()
        local L = { "🗂 EDITOR PICKER" }
        L[#L + 1] = string.format("   ⌘⌘ watcher : %s%s",
            ep.tapRunning and "running" or "NOT running",
            ep.tapEnabled and "" or " (tapEnabled = false)")
        L[#L + 1] = string.format("   fired      : %d time%s this session",
            ep.fires, ep.fires == 1 and "" or "s")
        L[#L + 1] = string.format("   fallback   : ⇪%s%s",
            (ep.keyMods and ep.keyMods[1] == "shift") and "⇧" or "",
            ep.key:upper())
        local states = ep.states()
        L[#L + 1] = string.format("   registered : %d editor%s",
            #states, #states == 1 and "" or "s")
        for _, s in ipairs(states) do
            L[#L + 1] = string.format("   %-18s %-10s %s",
                s.name,
                s.key ~= "" and s.key or "—",
                s.open and "OPEN" or (s.size and (s.size .. " " .. s.unit) or "—"))
        end
        if #states == 0 then
            L[#L + 1] = "   Nothing registered. A module registers by inserting"
            L[#L + 1] = "   into _G.editors — see the header of this module."
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- =================================================================
    -- 🔌 WIRING
    -- =================================================================
    if ep.enabled then
        core.hyperAddShortcut(ep.keyMods, ep.key, function() ep.show() end,
                              "editor picker")
    end
    core.provide("editors.show",   function() return ep.show()   end)
    core.provide("editors.list",   function() return ep.states() end)
    core.provide("editors.report", function() return _G.editorPickerReport() end)

    _G.editorPicker = ep
    M.picker = ep
    M.config = ep
end

-- The tap belongs to the warm phase, not the boot path: creating an event
-- tap is the one thing here that can make macOS put up a permission
-- dialog, and a dialog during boot is a dialog on top of a config that
-- has not finished loading.
M.warm = function()
    local ep = _G.editorPicker
    if ep and ep.enabled and ep.tapEnabled then ep.startTap() end
end

return M
