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
-- ⇪ + pad7 puts the front window in the top-left QUARTER. ⇪ + pad4 puts
-- it in the left HALF. ⇪ + pad5 centres it. There is nothing to
-- remember: you are pointing at where you want the window, with a key
-- that is already in that shape. The remaining keys follow the same
-- logic — 0 is the widest key so it maximises, and the arithmetic keys
-- do arithmetic on the size.
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
-- ✏️ To use the pad for something OTHER than windows, edit numpad.actions
-- at the top of setup(): a value may be a zone name, a function, or the
-- name of a published service ("activity.renderChoices" and friends).

local M = {
    name  = "Numpad Layer",
    order = 13.5,
    cheatsheet = {
        title = "🔢 NUMPAD LAYER (⇪ + number pad — window is where the key is)",
        entries = {
            { "⇪ pad7 8 9", "Top-left quarter · top half · top-right quarter" },
            { "⇪ pad4 5 6", "Left half · centre 70% · right half" },
            { "⇪ pad1 2 3", "Bottom-left quarter · bottom half · bottom-right quarter" },
            { "⇪ pad0",     "Maximise (the widest key does the widest thing)" },
            { "⇪ pad.",     "Put it back where it was" },
            { "⇪ pad+ / -", "Grow / shrink around the centre" },
            { "⇪ pad/ *",   "Previous monitor / next monitor" },
            { "⇪ padenter", "Centre without resizing" },
            { "why",        "The pad sends its OWN key codes — pad7 ≠ 7, both are free" },
            { "if dead",    "Accessibility → Pointer Control → Mouse Keys steals the pad" },
        },
    },
}

function M.setup(core)
    local numpad = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    numpad.enabled  = true
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

    numpad.actions = {
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

    -- ---- bind ------------------------------------------------------------
    -- Only keys macOS actually knows are bound. hs.keycodes.map returns nil
    -- for a name this build of macOS has no code for, and binding a nil key
    -- is an error that would take the rest of the layer down with it.
    numpad.bound, numpad.skipped = {}, {}
    for key, what in pairs(numpad.actions) do
        if hs.keycodes.map[key] ~= nil then
            core.hyperAddShortcut({}, key, function() numpad.run(what) end,
                                  "numpad " .. key)
            table.insert(numpad.bound, key)
        else
            table.insert(numpad.skipped, key)
        end
    end
    table.sort(numpad.bound)
    table.sort(numpad.skipped)
    if #numpad.skipped > 0 then
        print("🔢 Numpad layer: this macOS has no key code for " ..
              table.concat(numpad.skipped, ", ") .. " — those are not bound")
    end
    _G.diag.say("numpad", #numpad.bound .. " number-pad keys bound to ⇪")

    _G.numpadLayer = numpad
    M.numpad = numpad
    M.config = numpad
end

return M
