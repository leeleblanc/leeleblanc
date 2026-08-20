-- =====================================================================
-- MODULE: EDITOR PICKER (right ⌥⌥, or ⇪⇧Z) — every text surface this
-- config owns
-- =====================================================================
-- LL: "Right now a double-click of the cmd+cmd key pressed quickly.
-- Could I bring up all my editor windows up and then let me select the
-- one I need to copy from or edit from?"
--
-- Tap the right ⌥ twice, quickly, touching nothing else. A picker opens
-- listing every editor this config owns — the Capture Pad, the Note Pad,
-- the OCR text store, clipboard history, window pins, the screenshot
-- editor — with how much is in each one. ⏎ opens the one you chose (or
-- brings it to the front if it is already up). ⌥⏎ copies its text WITHOUT
-- opening anything, which is the "copy from" half of the ask.
--
--        right ⌥⌥   the picker
--        ⇪⇧Z        the same picker, for when the tap is unavailable
--        ⏎          open it / bring it forward
--        ⌥⏎         copy its text and stay where you are
--
-- ---- ✋ WHY A SIDE AT ALL, AND WHY ⌥ (6.121.0, settled in 6.122.0) ----
-- LL: "Right now I use the cmd+cmd so technically it's a conflict with
-- Hammerspoon. Can I use left cmd twice for Alfred and right cmd for
-- Hammerspoon?"
--
-- A flagsChanged event carries the KEYCODE of the modifier that changed,
-- and left and right are two different keys on every one of them:
--
--        left ⌘  55        right ⌘  54
--        left ⌥  58        right ⌥  61
--        left ⌃  59        right ⌃  62
--        left ⇧  56        right ⇧  60
--
-- So the tap can be told to care about ONE key, and it is. ep.tapSide =
-- "right" means a left-hand tap is not merely ignored, it CANCELS any
-- sequence in flight, so reaching for another program's double tap can
-- never leave half a gesture armed here.
--
-- 🚨 WHAT 6.121.0 COULD NOT ANSWER, AND DID NOT PRETEND TO. Splitting ⌘
-- needs BOTH programs to distinguish the sides, and whether Alfred does
-- is Alfred's business — unreadable from in here. So the modifier was
-- made a setting alongside the side, and LL settled it the better way:
--
--        Alfred      → right ⌃⌃
--        this picker → right ⌥⌥
--
-- Two keys neither program has to share. Nothing now depends on the one
-- fact this file could not check.
--
-- ⚠️ AND THE SIDE IS ONLY HONOURED WHEN IT CAN BE READ. A flagsChanged
-- event with no readable keycode cannot be attributed to a side, and this
-- refuses it rather than guessing — the guess would be the conflict
-- coming back. Refused presses are COUNTED, and _G.editorPickerReport()
-- prints the count, so a Mac where that reading does not work says so out
-- loud instead of quietly losing the gesture. See ep.sideUnknownLimit.
--
-- ⌨️ AND ⇪⇧Z IS THE LAST FREE LETTER, not a mnemonic. ⇪E was the obvious
-- one and §0.4's migration map has held it since long before this module
-- existed (it edits a custom cheat sheet entry) — the hotkey sentry said
-- so on the first run of the suite, which is the whole reason that sentry
-- is there. Z is what was left. The gesture you are meant to learn is the
-- double tap; this key is the handrail for the days it is not running.
--
-- ---- 🚨 WHY THE TAP WATCHES keyDown AS WELL AS THE MODIFIERS ---------
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
-- 🚨 AND THE SIDE CHECK DOES NOT REPLACE THIS. Somebody who copies and
-- pastes with the right ⌘ produces right-⌘C then right-⌘V, which passes
-- the side check perfectly. Narrowing the gesture to one key narrows WHO
-- may start it; it says nothing about what happened in the middle.
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
    -- 🗂 THE FIRST TWO ROWS AND THE TITLE ARE REWRITTEN BY setup(), because
    -- the gesture is a setting now and a cheat sheet that says ⌘⌘ while the
    -- tap is watching right ⌥⌥ is worse than no cheat sheet at all. These
    -- are the defaults, and they are what shows if setup never runs.
    cheatsheet = {
        title = "🗂 EDITOR PICKER (right ⌥⌥ — every editor at once)",
        entries = {
            { "right ⌥⌥", "Tap it twice, touching nothing else — the picker opens" },
            { "⇪⇧Z", "The same picker, when the double tap is unavailable" },
            { "⏎",   "Open it — or bring it forward if it is already up" },
            { "⌥⏎",  "Copy that editor's text and leave everything closed" },
            { "lists", "Capture Pad · Note Pad · OCR text · clipboard · pins" },
            { "sorted", "Open windows first, then whatever has something in it" },
            { "never", "⌘C then ⌘V does NOT open it — see the header" },
            { "left ⌥⌥", "Not this one — the left ⌥ is free. See ep.tapSide" },
            { "check", "_G.editorPickerReport() — the roster and the tap's health" },
        },
    },
}

function M.setup(core)
    local ep = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ep.enabled     = true    -- false = no tap, no key, nothing bound
    ep.tapEnabled  = true    -- false = ⇪⇧Z only; the tap is never created
    ep.key         = "z"     -- ⇪⇧Z, the tap-free way in (see the header)
    ep.keyMods     = { "shift" }
    -- 🎹 WHICH MODIFIER, AND WHICH ONE OF IT:
    --   tapMod  "cmd" · "alt" · "ctrl" · "shift"
    --   tapSide "right" · "left" · "either"
    --
    -- ✋ 6.122.0 — THE ARGUMENT WITH ALFRED IS OVER, AND NOT BY SPLITTING
    -- ⌘ AFTER ALL. 6.121.0 offered LL the right ⌘ with left ⌘ left to
    -- Alfred; what he did instead was better than what was offered:
    --        Alfred      → right ⌃⌃
    --        this picker → right ⌥⌥
    -- Two keys neither program has to share, so nothing depends any more
    -- on whether Alfred can tell its ⌘ keys apart — which was the one
    -- thing 6.121.0 could not find out from in here. The side machinery
    -- still earns its place: it is what makes right ⌥⌥ mean the RIGHT ⌥,
    -- leaving the left one free for whatever comes next.
    --
    -- "cmd" + "either" is the 6.116.0 behaviour, one line away.
    ep.tapMod      = "alt"
    ep.tapSide     = "right"
    -- ⏱ Two windows, and they are different questions. maxHold is "was
    -- that ⌘ a TAP or a HOLD" — a modifier you are holding down to use is
    -- down for as long as you are reading the menu. tapGap is "were those
    -- two taps one gesture". Both are deliberately tight: every
    -- millisecond of slack here is a millisecond in which a real ⌘ chord
    -- can be mistaken for half of a gesture.
    ep.maxHold     = 0.35    -- a tap is ⌘ down and up inside this
    ep.tapGap      = 0.35    -- and the second tap lands inside this
    ep.failLimit   = 5       -- consecutive callback throws before standing down
    -- How many presses may go unattributed to a side before this says so in
    -- the Console. Once, not every time: a line per keypress is a scroll.
    ep.sideUnknownLimit = 12
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("editors", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("editors", m) end end

    -- =================================================================
    -- 🎹 WHICH PHYSICAL KEY
    -- =================================================================
    -- The numbers are the documented macOS keycodes and they have not
    -- moved in twenty years, but they are the FALLBACK and not the
    -- source: hs.keycodes is the thing that knows, and a hard-coded
    -- constant that drifts is a gesture that dies quietly. Same shape as
    -- core/hyper_key.lua's F18 lookup, for the same reason.
    ep.MOD_KEYS = {
        cmd   = { glyph = "⌘", left = "cmd",   right = "rightcmd",   codes = { 55, 54 } },
        alt   = { glyph = "⌥", left = "alt",   right = "rightalt",   codes = { 58, 61 } },
        ctrl  = { glyph = "⌃", left = "ctrl",  right = "rightctrl",  codes = { 59, 62 } },
        shift = { glyph = "⇧", left = "shift", right = "rightshift", codes = { 56, 60 } },
    }
    ep.ALL_MODS = { "cmd", "alt", "ctrl", "shift" }

    function ep.modSpec()
        return ep.MOD_KEYS[ep.tapMod] or ep.MOD_KEYS.cmd
    end

    -- Resolved once at setup and again whenever tapMod changes, because a
    -- per-machine profile may set tapMod AFTER this file has run.
    function ep.resolveCodes()
        local spec = ep.modSpec()
        local left, right = spec.codes[1], spec.codes[2]
        pcall(function()
            local map = hs.keycodes and hs.keycodes.map
            if type(map) ~= "table" then return end
            if type(map[spec.left])  == "number" then left  = map[spec.left]  end
            if type(map[spec.right]) == "number" then right = map[spec.right] end
        end)
        -- ⚠️ A KEYBOARD MAP THAT GIVES BOTH SIDES THE SAME NUMBER cannot
        -- tell them apart, and pretending otherwise would silently refuse
        -- every press. Say so and stop asking.
        if left == right then
            warn("this keyboard reports one keycode for both "
                 .. ep.tapMod .. " keys — the side setting cannot apply")
            ep.sideReadable = false
        else
            ep.sideReadable = true
        end
        ep.leftCode, ep.rightCode = left, right
        ep.codesFor = ep.tapMod
        return left, right
    end

    -- nil means "this event does not name a side" — NOT "either side".
    function ep.sideOf(keyCode)
        if ep.codesFor ~= ep.tapMod then ep.resolveCodes() end
        if type(keyCode) ~= "number" then return nil end
        if keyCode == ep.leftCode  then return "left"  end
        if keyCode == ep.rightCode then return "right" end
        return nil
    end

    -- The only place the setting is interpreted. Anything other than
    -- "left" or "right" means the side does not matter, which is what
    -- makes a typo in a profile fail open rather than kill the gesture.
    function ep.sideOK(side)
        if ep.tapSide ~= "left" and ep.tapSide ~= "right" then return true end
        if not ep.sideReadable then return true end
        return side == ep.tapSide
    end

    -- What to CALL the gesture, everywhere it is named. One function so
    -- the cheat sheet, the report and the Console can never disagree.
    function ep.gesture()
        local g = ep.modSpec().glyph
        g = g .. g
        if ep.tapSide == "left"  then return "left "  .. g end
        if ep.tapSide == "right" then return "right " .. g end
        return g
    end

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
    --   · IT NEVER LOOKS AT WHICH KEY YOU TYPED. The keyDown branch reads
    --     no keycode and no characters. It records THAT a key happened,
    --     and that is the whole of its interest in your typing. The
    --     keycode it DOES read belongs to flagsChanged events only, where
    --     the "key" is ⌘ or ⌥ and nothing you could be writing with.
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
    ep.sidesSeen   = { left = 0, right = 0 }
    ep.sideUnknown = 0        -- presses this session that named no side
    ep.saidUnknown = false    -- the Console line is printed once, not per key
    local modDownAt, dirty, lastTapAt = nil, false, 0

    -- Exposed so the tests can drive the state machine without an event
    -- tap, and so ⇪⇧D can reset it after a machine wakes up confused.
    function ep.resetTapState()
        modDownAt, dirty, lastTapAt = nil, false, 0
    end

    -- Every modifier that is NOT the one this gesture is made of. Read
    -- from the setting rather than written out, so switching tapMod to
    -- "alt" does not leave ⌥ counting as an intruder in its own gesture.
    local function otherFlags(flags)
        for _, m in ipairs(ep.ALL_MODS) do
            if m ~= ep.tapMod and flags[m] == true then return true end
        end
        return flags.fn == true
    end

    -- The state machine, called with a plain flags table, a wall clock and
    -- the keycode of the modifier that changed (nil when unknown).
    -- Returns true on the frame that completes a double tap.
    function ep.onFlags(flags, now, keyCode)
        flags = flags or {}
        local down    = flags[ep.tapMod] == true
        local others  = otherFlags(flags)
        if down and modDownAt == nil then
            modDownAt = now
            dirty     = others          -- ⌘ arriving alongside ⇧ is not a tap
            -- 🚨 THE SIDE IS DECIDED ON THE WAY DOWN, and a wrong-side key
            -- does not merely fail to count — it dirties the press, which
            -- clears any half-made sequence on the release below. Tapping
            -- left ⌘ twice for Alfred therefore cannot leave this armed.
            local side = ep.sideOf(keyCode)
            if side then
                ep.sidesSeen[side] = (ep.sidesSeen[side] or 0) + 1
            elseif ep.tapSide == "left" or ep.tapSide == "right" then
                ep.noteUnknownSide()
            end
            if not ep.sideOK(side) then dirty = true end
        elseif down and modDownAt ~= nil then
            if others then dirty = true end   -- ⇧ joined a held ⌘
        elseif not down and modDownAt ~= nil then
            local held = now - modDownAt
            modDownAt = nil
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

    -- A side setting this Mac cannot honour is a gesture that has quietly
    -- stopped working, and the one thing worse than that is not being
    -- told. Counted always; said once, at the limit.
    function ep.noteUnknownSide()
        ep.sideUnknown = ep.sideUnknown + 1
        if ep.saidUnknown or ep.sideUnknown < ep.sideUnknownLimit then return end
        ep.saidUnknown = true
        print("🗂 Editor picker: " .. ep.sideUnknown .. " " .. ep.tapMod
              .. " presses could not be attributed to a left or right key, "
              .. "so " .. ep.gesture() .. " is being refused. Set "
              .. "_G.editorPicker.tapSide = \"either\" to take the side out "
              .. "of it. ⇪⇧Z opens the picker meanwhile.")
        if _G.notices then
            pcall(_G.notices.record, "runtime", "editor picker",
                  ep.gesture() .. " refused — no side on the keycode")
        end
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
        -- 🚨 pcall, AND NOT BECAUSE getKeyCode IS EXOTIC. It is the one
        -- call in this callback that a stubbed, replayed or synthesised
        -- event may simply not carry, and a throw here would be a throw
        -- inside a keyboard tap. nil is a perfectly good answer: it means
        -- "no side", which ep.sideOK already knows what to do with.
        local code = nil
        pcall(function() code = ev:getKeyCode() end)
        if ep.onFlags(flags, hs.timer.secondsSinceEpoch(), code) then
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
            print("🗂 Editor picker: the " .. ep.gesture() .. " watcher threw "
                  .. ep.failLimit .. " times in a row and has been "
                  .. "switched off. ⇪⇧Z still opens the picker. "
                  .. "Last error: " .. tostring(err))
            if _G.notices then
                pcall(_G.notices.record, "runtime", "editor picker",
                      ep.gesture() .. " watcher disabled after repeated failures")
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
            warn("could not create the " .. ep.gesture()
                 .. " watcher — ⇪⇧Z still works")
            return false
        end
        ep.tap = tap
        local okStart = pcall(function() tap:start() end)
        ep.tapRunning = okStart and true or false
        if not okStart then
            warn("the " .. ep.gesture() .. " watcher would not start — ⇪⇧Z still works")
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
        L[#L + 1] = string.format("   gesture    : %s  (tapMod = %s, tapSide = %s)",
            ep.gesture(), tostring(ep.tapMod), tostring(ep.tapSide))
        L[#L + 1] = string.format("   watcher    : %s%s",
            ep.tapRunning and "running" or "NOT running",
            ep.tapEnabled and "" or " (tapEnabled = false)")
        L[#L + 1] = string.format("   fired      : %d time%s this session",
            ep.fires, ep.fires == 1 and "" or "s")
        L[#L + 1] = string.format("   fallback   : ⇪%s%s",
            (ep.keyMods and ep.keyMods[1] == "shift") and "⇧" or "",
            ep.key:upper())
        -- 🚨 THE THREE NUMBERS THAT SAY WHETHER THE SPLIT IS WORKING, and
        -- the reason this report exists at all now. Nought on the side you
        -- chose means the gesture cannot fire, and this is the only place
        -- that would ever tell you why.
        L[#L + 1] = string.format("   keys seen  : left %d · right %d · no side %d",
            ep.sidesSeen.left or 0, ep.sidesSeen.right or 0, ep.sideUnknown)
        if not ep.sideReadable then
            L[#L + 1] = "   ⚠️ this keyboard reports one keycode for both keys —"
            L[#L + 1] = "      the side is being ignored and either key fires it"
        elseif (ep.tapSide == "left" or ep.tapSide == "right")
               and (ep.sidesSeen[ep.tapSide] or 0) == 0 then
            L[#L + 1] = "   ⚠️ the " .. ep.tapSide .. " " .. ep.modSpec().glyph
                        .. " has not been pressed once this session."
            L[#L + 1] = "      Either you have not used it yet, or this keyboard"
            L[#L + 1] = "      has no " .. ep.tapSide .. " one — try tapSide = \"either\"."
        end
        if ep.sideUnknown > 0 then
            L[#L + 1] = string.format(
                "   ⚠️ %d press%s named no side and %s refused.",
                ep.sideUnknown, ep.sideUnknown == 1 and "" or "es",
                ep.sideUnknown == 1 and "was" or "were")
        end
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
    ep.resolveCodes()

    -- 🗂 THE SHEET IS TOLD WHAT THE TAP ACTUALLY WATCHES, because a cheat
    -- sheet that says ⌘⌘ while the tap watches right ⌥⌥ is worse than no
    -- cheat sheet: it is a wrong answer given confidently.
    --
    -- ⚠️ CALLED TWICE, AND THE SECOND TIME IS THE ONE THAT MATTERS ON A
    -- MACHINE WITH A PROFILE. init.lua applies profile overrides to
    -- M.config AFTER setup() returns and harvests M.cheatsheet a few lines
    -- later, so a profile that sets tapSide would leave rows written here
    -- describing the gesture it replaced. warm() runs after both and calls
    -- this again — and by then the sheet holds THE SAME entries table by
    -- reference, so the rows update in place. The title does not: it was
    -- copied as a string. Hence the second half of this function, which
    -- goes and corrects the harvested group's title as well.
    function ep.describe()
        local glyph = ep.modSpec().glyph
        M.cheatsheet.title = "🗂 EDITOR PICKER (" .. ep.gesture()
                             .. " — every editor at once)"
        M.cheatsheet.entries[1] = { ep.gesture(),
            "Tap it twice, touching nothing else — the picker opens" }
        if ep.tapSide == "left" or ep.tapSide == "right" then
            local otherSide = (ep.tapSide == "right") and "left" or "right"
            M.cheatsheet.entries[8] = { otherSide .. " " .. glyph .. glyph,
                "Not this one — yours to give to Alfred. See ep.tapSide" }
        else
            M.cheatsheet.entries[8] = { "either side", "Both " .. ep.tapMod
                .. " keys fire it — ep.tapSide = \"right\" narrows it" }
        end
        for _, g in ipairs(_G.moduleCheatsheets or {}) do
            if type(g) == "table" and g.source == M.name then
                g.title = M.cheatsheet.title
            end
        end
    end
    ep.describe()

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
    if not ep then return end
    -- Re-read the settings a profile may have changed since setup: the
    -- keycodes for a new tapMod, and every place the gesture is named.
    pcall(ep.resolveCodes)
    pcall(ep.describe)
    if ep.enabled and ep.tapEnabled then ep.startTap() end
end

return M
