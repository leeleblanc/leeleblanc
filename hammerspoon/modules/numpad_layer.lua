-- =====================================================================
-- MODULE: NUMPAD LAYER (⇪ + number pad) — a whole extra keyboard's worth
-- =====================================================================
-- SHORT ANSWER TO "are the number pad keys a separate key path?": YES.
-- The number pad sends its OWN key codes, completely distinct from the
-- number row. On this Mac:
--
--        number row 1  = key code 18      number pad 1  = key code 83
--        number row 2  = key code 19      number pad 2  = key code 84
--        number row 3  = key code 20      number pad 3  = key code 85
--        …                                …
--        number row 0  = key code 29      number pad 0  = key code 82
--
-- Hammerspoon names them "pad0".."pad9", plus "pad.", "pad+", "pad-",
-- "pad*", "pad/", "pad=", "padenter" and "padclear". They go through
-- hs.hotkey exactly like any other key, so ⇪ + pad7 and ⇪ + 7 are two
-- different shortcuts that can do two different things. You can check
-- any of this yourself in the Hammerspoon Console:
--        hs.keycodes.map["pad7"]   -->  89
--        hs.keycodes.map["7"]      -->  26
--
-- ---------------------------------------------------------------------
-- AND THE HARDER HALF: MAKING THEM MEMORABLE
-- ---------------------------------------------------------------------
-- Ten shortcuts you have to memorise is ten shortcuts you will not use.
-- So this layer is not a list — it is a MAP. The number pad is a 3×3
-- grid, your screen is a 3×3 grid, and each key does what its own
-- position on the keyboard looks like:
--
--        ┌─────┬─────┬─────┐          ┌─────┬─────┬─────┐
--        │  7  │  8  │  9  │          │ top │ top │ top │
--        ├─────┼─────┼─────┤          │ left│ half│right│
--        │  4  │  5  │  6  │   ────►  ├─────┼─────┼─────┤
--        ├─────┼─────┼─────┤          │left │centre│right│
--        │  1  │  2  │  3  │          ├─────┼─────┼─────┤
--        └─────┴─────┴─────┘          │ bot │ bot │ bot │
--                                     │ left│ half│right│
--                                     └─────┴─────┴─────┘
--
-- ⇪⇧ + pad7 puts the front window in the top-left QUARTER. ⇪⇧ + pad4
-- puts it in the left HALF. ⇪⇧ + pad5 centres it. There is nothing to
-- remember: you are pointing at where you want the window, with a key
-- that is already in that shape. The remaining keys follow the same
-- logic — 0 is the widest key so it maximises, and the arithmetic keys
-- do arithmetic on the size.
--
-- 🔀 WHICH LAYER IS WHICH, AND WHY (changed in 6.50.0):
--        ⇪  + pad  →  TOOLS    focus, rename, grid, menu bar, links
--        ⇪⇧ + pad  →  WINDOWS  the 3×3 map drawn above
-- 6.49.0 had these the other way round, on the argument that the window
-- map deserved the easier layer because it needs no memory. That was the
-- wrong trade: the layer you press twenty times a day should be the one
-- without the extra modifier, and that is the tools. The window map is
-- just as memorable one modifier up — its mnemonic is spatial, not
-- positional-on-the-keyboard, so nothing about it degrades.
--
-- ⚠️ TWO THINGS THAT WILL STOP THIS WORKING, both outside Hammerspoon:
--   • ACCESSIBILITY → POINTER CONTROL → MOUSE KEYS. When that is on,
--     macOS eats the whole number pad to drive the cursor and no app
--     ever sees those keys. If ⇪ + pad5 does nothing, check there first.
--   • A KEYBOARD WITHOUT A NUMBER PAD. A laptop or a Magic Keyboard
--     with no pad simply never sends these codes, so the bindings sit
--     there doing nothing. They cost nothing and they are still correct
--     the moment you plug the full-size keyboard back in — which is why
--     this module is safe to load on both Macs.
--
-- ✏️ To change what a pad key does, edit numpad.actions (the ⇪ layer) or
-- numpad.shiftActions (the ⇪⇧ layer) at the top of setup(). A value may
-- be a zone name, a function, or the name of a published service.
--
-- ✅ LIVE SINCE 6.49.0. This layer shipped PARKED from 6.44.0 so it would
-- claim nothing you had not asked for. It is now switched on, on two
-- layers — see the 🔀 note above for which is which.
--    To park it again:  numpad.enabled = false  (a few lines down), reload.
-- ⚠️ A MACHINE PROFILE CANNOT switch it on or off. Profile settings are
-- applied AFTER setup() runs, and binding happens during setup — so the
-- override would land too late to claim any keys. This one is the file
-- switch.

-- hs-lint: allow service-call-unchecked — every value in numpad.actions
-- and numpad.shiftActions is resolved against the LIVE service registry by
-- tests/test_integration.lua, which is the only suite that loads all
-- thirty modules together and can therefore resolve them at all. A typo
-- here fails the build rather than failing silently at your fingertips,
-- which is a stronger guarantee than a runtime has() check would give.
local M = {
    name  = "Numpad Layer",
    order = 13.5,
    cheatsheet = {
        title = "🔢 NUMPAD LAYER (⇪ pad = tools · ⇪⇧ pad = windows)",
        entries = {
            { "⇪ pad7 8 9",  "Focus mode toggle · focus report · health report" },
            { "⇪ pad4 5 6",  "Bulk rename · mouse grid · menu bar items" },
            { "⇪ pad1 2 3",  "Clean copied link · flush Capture Pad · copy today" },
            { "⇪ pad0",      "Run the health check now" },
            { "⇪ pad.",      "Undo the last rename" },
            { "⇪ pad+",      "Pomodoro — 25 on, 5 off (press again to close)" },
            { "⇪ pad*",      "Find the pointer — flashes a ring around it" },
            { "free",        "⇪ pad - / enter clear are unclaimed, for later" },
            { "—",           "———— hold shift for windows ————" },
            { "⇪⇧ pad7 8 9", "Top-left quarter · top half · top-right quarter" },
            { "⇪⇧ pad4 5 6", "Left half · centre 70% · right half" },
            { "⇪⇧ pad1 2 3", "Bottom-left qtr · bottom half · bottom-right qtr" },
            { "⇪⇧ pad0",     "Maximise (the widest key does the widest thing)" },
            { "⇪⇧ pad.",     "Put the window back where it was" },
            { "⇪⇧ pad+ / -", "Grow / shrink around the centre" },
            { "⇪⇧ pad/ *",   "Previous monitor / next monitor" },
            { "⇪⇧ padenter", "Centre without resizing" },
            { "why",         "The pad sends its OWN key codes — pad7 ≠ 7, both free" },
            { "if dead",    "Accessibility → Pointer Control → Mouse Keys steals the pad" },
        },
    },
}

function M.setup(core)
    local numpad = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    -- 🅿️ false = PARKED. The layout below is documented in the cheat sheet
    -- for when you want it, but NO key is bound and every ⇪ + pad
    -- combination stays free. Flip this to true and reload to make it live.
    numpad.enabled  = true     -- 6.49.0: LIVE. Was parked; see the header.
    numpad.animate  = 0        -- seconds; 0 = snap. Anything else feels laggy.
    numpad.centreW  = 0.70     -- pad5 / padenter width as a fraction of screen
    numpad.centreH  = 0.80
    numpad.stepFrac = 0.06     -- how much pad+ / pad- change each press
    numpad.minFrac  = 0.20     -- never shrink a window below this much screen
    numpad.margin   = 0        -- gap around each zone, in points
    -- ----------------------------------------------------------------------

    -- Each zone is a fraction of the screen's usable frame: x, y, w, h.
    -- Reading them in a 3×3 block is deliberate — the table has the same
    -- shape as the keys it serves, so a wrong number is visible rather than
    -- something you have to work out.
    numpad.zones = {
        topLeft     = { 0,    0,    0.5,  0.5  },
        topHalf     = { 0,    0,    1.0,  0.5  },
        topRight    = { 0.5,  0,    0.5,  0.5  },
        leftHalf    = { 0,    0,    0.5,  1.0  },
        centre      = nil,   -- computed from centreW/centreH below
        rightHalf   = { 0.5,  0,    0.5,  1.0  },
        bottomLeft  = { 0,    0.5,  0.5,  0.5  },
        bottomHalf  = { 0,    0.5,  1.0,  0.5  },
        bottomRight = { 0.5,  0.5,  0.5,  0.5  },
        full        = { 0,    0,    1.0,  1.0  },
    }

    -- ---- LAYER 1: ⇪ + pad → TOOLS (the primary layer) -------------------
    -- 6.50.0 PUT TOOLS HERE, on the plain hyper key, because this is the
    -- layer you actually reach for. It was the other way round in 6.49.0.
    --
    -- ⚠️ EVERY VALUE HERE IS A PUBLISHED SERVICE NAME, not a function.
    -- That is deliberate: this file then knows nothing about focus mode
    -- or renaming, and a pad key whose module is switched off on this Mac
    -- prints "no provider" instead of erroring. You can use a function
    -- value too — see numpad.run. A typo in a name binds a key that
    -- silently does nothing, which is why test_integration.lua resolves
    -- every one of these against the real service registry.
    --
    -- Grouped by ROW, because unlike the window layer there is no spatial
    -- truth to appeal to and pretending otherwise is a mnemonic that lies:
    --      top row    (7 8 9) — meetings and machine health
    --      middle row (4 5 6) — the three pickers
    --      bottom row (1 2 3) — clipboard and capture
    numpad.actions = {
        pad7 = "focus.toggle",       -- join a meeting / leave it
        pad8 = "focus.report",       -- what focus changed, and what it restores
        pad9 = "health.report",      -- the tool-health report
        pad4 = "rename.show",        -- rename the Finder selection
        pad5 = "mouseGrid.show",     -- centre key, and the grid is a pointer
        pad6 = "menuBar.show",       -- menu bar icons by name
        pad1 = "url.cleanClipboard", -- strip trackers from the copied link
        pad2 = "capturePad.flush",   -- send the pad to Asana now
        pad3 = "calendar.copyToday", -- today's date to the clipboard
        pad0 = "health.check",       -- run the health scan right now
        ["pad."] = "rename.undo",    -- the echo: ⇪pad. undoes a rename,
                                     -- ⇪⇧pad. undoes a window move
        -- 6.65.0 — the arithmetic keys start earning their keep. Both are
        -- on THIS layer rather than ⇪⇧ because both are tools, and the
        -- 6.50.0 split is the whole reason this layer exists: ⇪pad is what
        -- you do, ⇪⇧pad is where the window goes. A pomodoro on the window
        -- layer would be the first thing there that is not a window.
        ["pad+"] = "pomodoro.toggle",  -- 25 on, 5 off; press again to close
        ["pad*"] = "mouseGrid.locate", -- flash a ring at the pointer.
                                       -- The asterisk IS the mnemonic: it
                                       -- is the only key on the pad shaped
                                       -- like the thing it draws.
        -- 🆓 STILL FREE ON THIS LAYER:  pad-  pad/  padenter  padclear
    }

    -- ---- LAYER 2: ⇪⇧ + pad → WINDOWS ------------------------------------
    -- The pad keys are their own key codes, and a modifier makes them
    -- their own shortcuts again — ⇪pad7 and ⇪⇧pad7 are two distinct
    -- combinations. That is what lets one small pad carry both maps
    -- without costing a single letter on the main keyboard.
    --
    -- The window map keeps its shape: THE KEY'S POSITION IS THE WINDOW'S
    -- POSITION. pad7 is the top-left quarter because 7 is the top-left
    -- key. Nothing to memorise, just point at where you want it.
    --
    --        ┌─────┬─────┬─────┐
    --        │  7  │  8  │  9  │   quarter · half · quarter
    --        ├─────┼─────┼─────┤
    --        │  4  │  5  │  6  │   left half · centre · right half
    --        ├─────┼─────┼─────┤
    --        │  1  │  2  │  3  │   quarter · half · quarter
    --        └─────┴─────┴─────┘
    numpad.shiftActions = {
        pad7 = "topLeft",    pad8 = "topHalf",    pad9 = "topRight",
        pad4 = "leftHalf",   pad5 = "centre",     pad6 = "rightHalf",
        pad1 = "bottomLeft", pad2 = "bottomHalf", pad3 = "bottomRight",
        pad0 = "full",
        ["pad."]  = "restore",
        ["pad+"]  = "grow",
        ["pad-"]  = "shrink",
        ["pad/"]  = "prevScreen",
        ["pad*"]  = "nextScreen",
        padenter  = "centreOnly",
        padclear  = "restore",
    }

    -- Bounded on purpose: one entry per window id, and windows come and go
    -- all day. Without the cap this is a slow leak that nothing ever
    -- notices, which is the worst kind.
    numpad.prior = {}
    numpad.priorOrder = {}
    numpad.maxPrior = 40

    local function remember(win)
        local okId, id = pcall(function() return win:id() end)
        if not (okId and id) then return end
        local okF, f = pcall(function() return win:frame() end)
        if not okF then return end
        if numpad.prior[id] == nil then
            table.insert(numpad.priorOrder, id)
            if #numpad.priorOrder > numpad.maxPrior then
                local oldest = table.remove(numpad.priorOrder, 1)
                numpad.prior[oldest] = nil
            end
        end
        numpad.prior[id] = f
    end

    local function frontWindow()
        local okW, w = pcall(hs.window.focusedWindow)
        if not (okW and w) then
            hs.alert.show("🔢 No focused window")
            return nil
        end
        return w
    end

    local function place(win, frac)
        local scr = win:screen()
        if not scr then return end
        local sf = scr:frame()     -- frame, not fullFrame: leave the menu
                                   -- bar and the Dock alone
        local m = numpad.margin
        local f = {
            x = sf.x + sf.w * frac[1] + m,
            y = sf.y + sf.h * frac[2] + m,
            w = sf.w * frac[3] - m * 2,
            h = sf.h * frac[4] - m * 2,
        }
        remember(win)
        pcall(function() win:setFrame(f, numpad.animate) end)
    end

    local function centreFrac()
        local w = math.max(0.2, math.min(1.0, numpad.centreW))
        local h = math.max(0.2, math.min(1.0, numpad.centreH))
        return { (1 - w) / 2, (1 - h) / 2, w, h }
    end

    -- Grow and shrink work on the CURRENT frame and keep the centre where
    -- it is, which is what makes repeated presses feel like a zoom rather
    -- than a drift toward one corner.
    local function resizeBy(win, delta)
        local scr = win:screen()
        if not scr then return end
        local sf, f = scr:frame(), win:frame()
        local cx, cy = f.x + f.w / 2, f.y + f.h / 2
        local nw = f.w + sf.w * delta
        local nh = f.h + sf.h * delta
        nw = math.max(sf.w * numpad.minFrac, math.min(sf.w, nw))
        nh = math.max(sf.h * numpad.minFrac, math.min(sf.h, nh))
        remember(win)
        local nf = { x = cx - nw / 2, y = cy - nh / 2, w = nw, h = nh }
        -- Keep it on the screen it is on: a grow near an edge would
        -- otherwise push half the window off the side.
        if nf.x < sf.x then nf.x = sf.x end
        if nf.y < sf.y then nf.y = sf.y end
        if nf.x + nf.w > sf.x + sf.w then nf.x = sf.x + sf.w - nf.w end
        if nf.y + nf.h > sf.y + sf.h then nf.y = sf.y + sf.h - nf.h end
        pcall(function() win:setFrame(nf, numpad.animate) end)
    end

    local function toScreen(win, dir)
        local scr = win:screen()
        if not scr then return end
        local target = (dir > 0) and scr:next() or scr:previous()
        if not target or target:id() == scr:id() then
            hs.alert.show("🔢 Only one display")
            return
        end
        remember(win)
        pcall(function() win:moveToScreen(target, false, true, numpad.animate) end)
    end

    local function restore(win)
        local okId, id = pcall(function() return win:id() end)
        local f = okId and id and numpad.prior[id]
        if not f then
            hs.alert.show("🔢 No earlier size remembered for this window")
            return
        end
        pcall(function() win:setFrame(f, numpad.animate) end)
    end

    -- One entry point, so every key takes the same path and a new action is
    -- one table entry rather than another binding.
    function numpad.run(what)
        if not numpad.enabled then return end
        if type(what) == "function" then pcall(what) return end
        if type(what) ~= "string" then return end

        if what == "centre" or what == "centreOnly" then
            local win = frontWindow(); if not win then return end
            if what == "centre" then
                place(win, centreFrac())
            else
                local sf, f = win:screen():frame(), win:frame()
                remember(win)
                pcall(function()
                    win:setFrame({ x = sf.x + (sf.w - f.w) / 2,
                                   y = sf.y + (sf.h - f.h) / 2,
                                   w = f.w, h = f.h }, numpad.animate)
                end)
            end
            return
        end
        if what == "grow" or what == "shrink" then
            local win = frontWindow(); if not win then return end
            resizeBy(win, what == "grow" and numpad.stepFrac or -numpad.stepFrac)
            return
        end
        if what == "nextScreen" or what == "prevScreen" then
            local win = frontWindow(); if not win then return end
            toScreen(win, what == "nextScreen" and 1 or -1)
            return
        end
        if what == "restore" then
            local win = frontWindow(); if not win then return end
            restore(win)
            return
        end

        local zone = numpad.zones[what]
        if zone then
            local win = frontWindow(); if not win then return end
            place(win, zone)
            return
        end

        -- Anything else is treated as a published service name, so a pad key
        -- can drive another module without this file knowing anything about
        -- it. A missing provider prints which module is absent; it does not
        -- crash the keypress.
        _G.service.call(what)
    end

    -- ---- bind (or don't) -------------------------------------------------
    -- 🅿️ PARKED BY DEFAULT. numpad.enabled = false means this file is a
    -- DESIGN kept on the shelf, not a set of live shortcuts: nothing is
    -- bound, and every ⇪ + pad key stays completely free for whatever you
    -- decide later. The plan still shows up in the cheat sheet, marked as
    -- parked, so it is somewhere you will actually find it again — which
    -- is the whole point of writing it down.
    --
    -- Not binding is a REAL difference, not a cosmetic one: a disabled
    -- run() that still claimed the keys would swallow every ⇪ + pad press
    -- and do nothing with it, which looks identical to a broken keyboard.
    numpad.bound, numpad.skipped = {}, {}

    -- The binding loop lives in its own function purely so there is ONE
    -- place that claims keys, and so a test can exercise the live path
    -- without editing the file. ⚠️ Calling this from the Console after boot
    -- is NOT the supported way to switch the layer on: §3.12 finalises the
    -- hyper modal once, near the end of init.lua, and a shortcut added
    -- after that may never reach it. The supported route is the one-line
    -- switch above plus a reload.
    function numpad.bindAll()
        if #numpad.bound > 0 then return #numpad.bound end   -- idempotent
        -- Only keys macOS actually knows are bound. hs.keycodes.map returns
        -- nil for a name this build has no code for, and binding a nil key
        -- is an error that would take the rest of the layer down with it.
        for key, what in pairs(numpad.actions) do
            if hs.keycodes.map[key] ~= nil then
                core.hyperAddShortcut({}, key, function() numpad.run(what) end,
                                      "numpad " .. key)
                table.insert(numpad.bound, key)
            else
                table.insert(numpad.skipped, key)
            end
        end
        -- The shifted layer. Same nil-key guard, for the same reason: a
        -- keyboard whose macOS build has no code for padclear must skip
        -- that key rather than take the whole layer down with it.
        for key, what in pairs(numpad.shiftActions or {}) do
            if hs.keycodes.map[key] ~= nil then
                core.hyperAddShortcut({ "shift" }, key,
                                      function() numpad.run(what) end,
                                      "numpad shift " .. key)
                table.insert(numpad.bound, "⇧" .. key)
            else
                table.insert(numpad.skipped, "⇧" .. key)
            end
        end
        table.sort(numpad.bound)
        table.sort(numpad.skipped)
        if #numpad.skipped > 0 then
            print("🔢 Numpad layer: this macOS has no key code for " ..
                  table.concat(numpad.skipped, ", ") .. " — those are not bound")
        end
        _G.diag.say("numpad", #numpad.bound .. " number-pad keys bound to ⇪")
        return #numpad.bound
    end

    if not numpad.enabled then
        -- The loader reads M.cheatsheet AFTER setup() returns, so rewriting
        -- it here is what puts the parked banner on the sheet.
        M.cheatsheet.title = "🅿️ NUMPAD LAYER — PARKED (a plan, not live shortcuts)"
        table.insert(M.cheatsheet.entries, 1, {
            "status", "NOTHING IS BOUND — every ⇪ + pad key is still free",
        })
        table.insert(M.cheatsheet.entries, 2, {
            "to use it", "numpad.enabled = true in modules/numpad_layer.lua, then reload",
        })
        _G.diag.say("numpad", "parked — no keys bound, layout kept for reference")
        _G.numpadLayer = numpad
        M.numpad = numpad
        M.config = numpad
        return
    end

    numpad.bindAll()

    _G.numpadLayer = numpad
    M.numpad = numpad
    M.config = numpad
end

return M
