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
--   • A KEYBOARD WITHOUT A NUMBER PAD. See the next block — that answer
--     used to be "the bindings sit there doing nothing", and 6.114.0
--     stopped accepting it.
--
-- ---------------------------------------------------------------------
-- 💻 6.114.0 — LAYER 4: ⇪⇧ + THE NUMBER ROW, FOR A KEYBOARD WITH NO PAD
-- ---------------------------------------------------------------------
-- LL, undocked: "Sometimes I will not have an external keyboard on my
-- work MacBook, well and my home, and sometimes I will not."
--
-- The old answer was that the pad bindings cost nothing when the pad is
-- absent and come back the moment it returns. That is true, and it is
-- not an answer: it means a documented chunk of this config is simply
-- NOT THERE half the week, and nothing on screen says so. ⇪ itself is
-- safe on a laptop — Caps Lock is on every MacBook and the hidutil
-- remap is per-user, not per-device — so the hole was never the hyper
-- key. It was these seventeen window keys and three capture keys.
--
-- Taking inventory made the fix small. MOST of the pad already had a
-- laptop route: ⇪pad1≈⇪J, ⇪pad3≈⇪⇧J, ⇪pad4≈⇪\, ⇪⇧pad4/6≈⇪←/⇪→,
-- ⇪⇧pad0≈⇪↑, ⇪⇧pad./padclear≈⇪↓, ⇪⇧pad//pad*≈⇪[/⇪]. What had NO route
-- at all was the Quick Append Pad (note_pad binds no letter — the pad
-- was its only key) and nine window placements: the four quarters, top
-- and bottom half, centre 70%, centre-without-resizing, grow, shrink.
--
-- So: the SAME DIGITS, one row up. ⇪⇧7 does what ⇪⇧pad7 does. There is
-- no second map to learn and no second table to keep in step — both
-- layers call the same numpad.run() over the same numpad.zones.
--
--   ⚠️ THE MNEMONIC IS HONESTLY WEAKER AND THE FILE SAYS SO. The pad's
--   3×3 block IS the screen; the number row is a straight line, so the
--   spatial claim would be a lie up here. What survives is the digit:
--   whatever ⇪⇧pad7 does, ⇪⇧7 does. That is a real mnemonic and it is
--   the only one being claimed.
--
--   ⚠️ 0 IS NOT HERE. ⇪⇧0 is the mini calendar, and stealing a live key
--   to complete a pattern is how you get two features fighting over one
--   press. Maximise is ⇪↑, which works on every keyboard already.
--
--   ⚠️ AUTO-DETECTING THE KEYBOARD AND SWAPPING LAYERS WAS CONSIDERED
--   AND REJECTED. hs.usb.watcher could tell us the pad had arrived, and
--   a config where one key does different things depending on what is
--   plugged in is a config you hesitate before pressing. Both layers are
--   always live; the pad is just the faster path to the same nine zones.
--
-- ✏️ The table is numpad.rowActions, next to the other two.
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
-- 🗂 6.101.0 — TWO GROUPS, NOT ONE, because this module is genuinely two
-- tools sharing a keyboard: ⇪ + pad CAPTURES text, ⇪⇧ + pad MOVES
-- WINDOWS. On the family-grouped cheat sheet, filing all twenty-four rows
-- under either band would be a lie about half of them — so the module
-- registers a group in each. The loader accepts a LIST here for exactly
-- this case; everything else still ships one table.
local M = {
    name  = "Numpad Layer",
    order = 13.5,
    cheatsheet = {
        {
        family = "capture",
        title = "🔢 NUMPAD — ⇪ pad, THE CAPTURE ROW (⌘⇧ pad is all free)",
        entries = {
            -- 🔤 6.114.0 — THE SPACE CAME OUT OF EVERY KEY CELL. These read
            -- "⇪ pad1" until now, while quick_append and note_pad spelled the
            -- SAME keys "⇪pad1"; ⇪space lists one row per key cell, so one
            -- shortcut appeared twice under two spellings and the run map
            -- could only ever reach one of them. One key, one spelling.
            { "⇪pad1",      "Clipboard → log.txt as a Log note, instantly" },
            { "⇪pad2",      "The Quick Append Pad — * idea · + log · ! task · ? note" },
            { "⇪pad3",      "Clipboard → pick Logs or Ideas (the ⇪⇧J picker)" },
            { "⇪pad4",      "Split the two most recent windows (same as ⇪\\)" },
            { "⇪pad*",      "The pad, pre-typed with * — an Idea" },
            { "⇪pad-",      "The pad, pre-typed with + — a Log" },
            { "no pad?",     "⇪2 opens the pad · every row here runs from ⇪space" },
            { "⇪ pad rest",  "🆓 free — pad0 5 6 7 8 9 . / enter clear, yours to assign" },
            { "⌘⇧ pad ALL",  "🆓 all free — a REAL modifier, works outside ⇪ too" },
            { "how",         "Add padN = \"some.service\" in numpad_layer.lua —" },
            { "",            "numpad.actions (⇪) or numpad.cmdShiftActions (⌘⇧)" },
            { "first",       "_G.padProbe() — which pad keys this Mac can send" },
            { "⇪ vs ⌘⇧",     "⇪ is ours (Caps Lock remapped). ⌘⇧ is real macOS —" },
            { "",            "so a ⌘⇧pad shortcut also works in Raycast, KM, etc." },
            { "if dead",    "Accessibility → Pointer Control → Mouse Keys steals the pad" },
        },
        },
        {
        family = "windows",
        title = "🔢 NUMPAD — ⇪⇧ pad, THE WINDOW MAP (the pad IS the screen)",
        entries = {
            { "⇪⇧ pad7 8 9", "Top-left quarter · top half · top-right quarter" },
            { "⇪⇧ pad4 5 6", "Left half · centre 70% · right half" },
            { "⇪⇧ pad1 2 3", "Bottom-left qtr · bottom half · bottom-right qtr" },
            { "⇪⇧ pad0",     "Maximise (the widest key does the widest thing)" },
            { "⇪⇧ pad.",     "Put the window back where it was" },
            { "⇪⇧ pad+ / -", "Grow / shrink around the centre" },
            { "⇪⇧ pad/ *",   "Previous monitor / next monitor" },
            { "⇪⇧ padenter", "Centre without resizing" },
            { "why",         "The pad sends its OWN key codes — pad7 ≠ 7, both free" },
            { "no pad?",     "The same nine zones live on ⇪⇧ + the NUMBER ROW" },
            { "if dead",    "Accessibility → Pointer Control → Mouse Keys steals the pad" },
        },
        },
        {
        family = "windows",
        title = "💻 NO NUMBER PAD — ⇪⇧ + THE NUMBER ROW, the same nine zones",
        entries = {
            { "⇪⇧7 8 9",  "Top-left quarter · top half · top-right quarter" },
            { "⇪⇧5",      "Centre 70%" },
            { "⇪⇧1 2 3",  "Bottom-left qtr · bottom half · bottom-right qtr" },
            { "⇪⇧,",      "Shrink around the centre  (think <)" },
            { "⇪⇧.",      "Grow around the centre    (think >)" },
            { "⇪⇧⏎",      "Centre without resizing (⇪⇧padenter on a full board)" },
            { "same digit", "⇪⇧7 does what ⇪⇧pad7 does. The digit IS the map" },
            { "halves",   "⇪← and ⇪→ — which is why 4 and 6 are not here" },
            { "maximise", "⇪↑ — and ⇪⇧0 is the mini calendar, so 0 is not either" },
            { "put back", "⇪↓ — one memory now, shared with ⇪← ⇪→ ⇪↑" },
            { "monitors", "⇪[ and ⇪] — no pad needed for those either" },
            { "why a row", "A row is not a 3×3 block, so the SHAPE mnemonic is" },
            { "",          "gone and the DIGIT one is kept. Same numbers, flat" },
        },
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
    --      bottom row (1 2 3) — clipboard and capture
    -- 🧹 6.66.0 CLEARED the whole layer: every entry was a second way to
    -- press a key you already had, and ten keys spent on duplicates were
    -- ten keys unavailable for anything new.
    -- ✍️ 6.99.0 CLAIMS SIX, ON REQUEST — and none is a duplicate this
    -- time; each is a NEW capture path that exists nowhere else on the
    -- keyboard (pad4's split is the one echo, kept deliberately: ⇪\ still
    -- works, the pad key is just easier to find):
    --      pad1  clipboard → log.txt as a Log note, no questions
    --      pad2  the Quick Append Pad — one box, lines routed by prefix
    --      pad3  clipboard → the pick-a-file chooser (Logs or Ideas)
    --      pad4  split the two most recent windows side-by-side
    --      pad*  the pad pre-typed with "* " (an Idea)
    --      pad-  the pad pre-typed with "+ " (a Log)
    -- The rest of the layer stays free: pad0 pad5–pad9 pad. pad/
    -- padenter padclear.
    --
    -- ✏️ TO CLAIM ONE: add `padN = "some.service"` here and reload. The
    -- value may be a published service name, a zone name, or a function.
    -- Whatever you add is checked against the live service registry by
    -- tests/test_integration.lua, so a typo fails the build rather than
    -- your fingertips.
    --
    -- 🚨 AND BEFORE YOU PICK A KEY, RUN _G.padProbe(). Not every pad key
    -- exists on every macOS build and keyboard layout, and a key macOS has
    -- no code for is SKIPPED here rather than bound — correctly, since
    -- binding nil takes the whole layer down. The cost of that correctness
    -- is that the key simply does nothing and only a console line says so.
    -- That is exactly how ⇪pad+ came to be documented, tested, shipped and
    -- dead on LL's Mac. padProbe() prints every pad key and whether this
    -- Mac can actually send it. (pad* and pad- below have codes on LL's
    -- Mac — pad+ is the one his keyboard cannot send, which is why the
    -- note keys avoid it.)
    numpad.actions = {
        pad1     = "notes.appendClipboard",   -- quick_append: clipboard → Log
        pad2     = "notes.openPad",           -- note_pad: the Quick Append Pad
        pad3     = "notes.pickTarget",        -- quick_append: Logs or Ideas
        pad4     = "windows.splitTwo",        -- window_arranger
        ["pad*"] = "notes.typeIdeas",         -- note_pad, pre-typed "* "
        ["pad-"] = "notes.typeLog",           -- note_pad, pre-typed "+ "
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

    -- ---- LAYER 4: ⇪⇧ + NUMBER ROW → THE SAME ZONES, NO PAD (6.114.0) ----
    -- The laptop layer. Full reasoning in the 💻 block at the top of the
    -- file; the short version is that a MacBook with no external keyboard
    -- had no route at all to nine of these zones, and "the bindings are
    -- still correct when you plug the pad back in" is not a route.
    --
    -- 🚨 THE VALUES ARE THE SAME STRINGS AS numpad.shiftActions, NOT A
    -- COPY OF ITS LOGIC. Both layers hand their string to numpad.run(),
    -- which owns the geometry — so there is exactly one definition of
    -- "top-left quarter" and the two layers cannot drift apart. A test
    -- asserts digit-for-digit agreement, because a table that LOOKS like
    -- a mirror is not a mirror.
    --
    -- ⚠️ THREE DIGITS ARE DELIBERATELY ABSENT, and every one of them is
    -- absent because the zone ALREADY HAS a laptop key that is better:
    --      0  maximise      → ⇪↑   (and ⇪⇧0 is the mini calendar)
    --      4  left half     → ⇪←   (and ⇪⇧4 is the Screenshots panel)
    --      6  right half    → ⇪→
    -- 🚨 THE ⇪⇧4 COLLISION WAS FOUND BY THE NEW SENTRY IN
    -- tests/test_integration.lua, ON ITS FIRST RUN, in this very table. It
    -- was written into the draft of this layer because ⇪⇧1–9 LOOKED free
    -- — a grep for shifted digits finds mini_calendar's ⇪⇧0 and nothing
    -- else, because screenshots.lua spells its key `shots.key = "4"` and
    -- the grep never saw it. That is the whole argument for a sentry over
    -- a careful read: the careful read had already happened.
    --
    -- Completing the 3×3 pattern would have meant taking ⇪⇧4 off the
    -- Screenshots panel to duplicate a key (⇪←) that works on every
    -- keyboard already. A documented hole beats a stolen key.
    -- ⚠️ prevScreen/nextScreen have no entry either, for the same reason:
    -- ⇪[ and ⇪] already do it and need no pad.
    numpad.rowActions = {
        ["7"] = "topLeft",    ["8"] = "topHalf",    ["9"] = "topRight",
                              ["5"] = "centre",
        ["1"] = "bottomLeft", ["2"] = "bottomHalf", ["3"] = "bottomRight",
        -- The three that are NOT digits on the pad either. < and > carry
        -- the shrink/grow mnemonic on their own, and Return is the exact
        -- same key as padenter one keyboard over.
        [","]      = "shrink",
        ["."]      = "grow",
        ["return"] = "centreOnly",
    }
    -- ⇧ is the modifier for both window layers, deliberately: the 6.50.0
    -- rule is "⇪ is tools, ⇪⇧ is windows", and a laptop layer that broke
    -- that rule to save one modifier would cost more than it saved.
    numpad.rowMods = { "shift" }

    -- ---- LAYER 3: ⌘⇧ + pad → FREE, AND NOT ON THE HYPER KEY (6.70.0) ----
    -- LL: "We set-up my number pad to work with Hammerspoon key presses.
    -- Therefore, if i press cmd+shift+{number pad 3} it should be
    -- assignable."
    --
    -- ⇪pad has been free and assignable since 6.66.0, so the CAPABILITY
    -- was already there — but only behind Caps Lock. This layer is the
    -- same thing on ⌘⇧, which matters for a reason worth writing down:
    -- ⇪ IS THIS CONFIG'S OWN INVENTION. Caps Lock is remapped to F18 by
    -- hidutil and turned into a modal by §3.12, and none of that exists
    -- outside Hammerspoon. ⌘⇧ is a REAL modifier combination that macOS,
    -- Keyboard Maestro, Raycast and every other app already understand —
    -- so a ⌘⇧pad shortcut keeps working in places a ⇪ one cannot reach,
    -- and can be handed to something other than this config later.
    --
    -- 🚨 IT IS BOUND WITH hs.hotkey.bind, NOT hyperAddShortcut. The two
    -- layers above go through the hyper modal, which only exists while
    -- Caps Lock is held. A ⌘⇧ combination is an ordinary global hotkey
    -- and has to be registered as one, through the §0.3 collision sentry
    -- like every other global binding — so a clash with anything added
    -- later is announced at boot instead of silently killing one of them.
    --
    -- Values are SERVICE NAMES, resolved against the live registry at
    -- press time, exactly like the two layers above:
    --      numpad.cmdShiftActions = { pad3 = "focus.toggle" }
    numpad.cmdShiftActions = {
        -- 🆓 EVERY ⌘⇧ + pad KEY IS FREE, yours to assign.
    }
    numpad.cmdShiftMods = { "cmd", "shift" }

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
        -- 🔗 6.114.0 — WRITE THROUGH TO THE SHARED MEMORY as well, so ⇪↓
        -- can put back a window this layer moved. Until now these two
        -- tables did not know about each other: ⇪⇧pad7 then ⇪↓ answered
        -- "No prior position remembered for this window", about a window
        -- it had just watched move. has() first because service.call does
        -- NOT throw on a missing provider — it prints — and a keypress
        -- that logs a warning on a Mac where window_arranger is switched
        -- off is noise, not news.
        if _G.service and _G.service.has
           and _G.service.has("windows.rememberFrame") then
            pcall(_G.service.call, "windows.rememberFrame", win)
        end
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
        -- Own table first, then the shared one (6.114.0). The fallback is
        -- not belt-and-braces: numpad.prior is capped at 40 and the window
        -- you want back may have aged out of it while the shared memory,
        -- capped higher and written by ⇪← ⇪→ ⇪↑ as well, still has it.
        local f = okId and id and (numpad.prior[id]
                                   or (_G.windowPriorFrames or {})[id])
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
        -- The LAPTOP layer (6.114.0) — ⇪⇧ + the number row, same zones.
        -- The nil-key guard is kept even though "7" and "," exist on every
        -- keyboard macOS supports: the guard is what makes adding a key
        -- here safe, and dropping it "because these ones are fine" is how
        -- the next addition takes the layer down.
        for key, what in pairs(numpad.rowActions or {}) do
            if hs.keycodes.map[key] ~= nil then
                core.hyperAddShortcut(numpad.rowMods, key,
                                      function() numpad.run(what) end,
                                      "numpad row " .. key)
                table.insert(numpad.bound, "⇧row " .. key)
            else
                table.insert(numpad.skipped, "⇧row " .. key)
            end
        end
        -- The ⌘⇧ layer (6.70.0). Same nil-key guard as the other two, and
        -- the same reason: a key this macOS has no code for must be
        -- skipped and REPORTED, not bound as nil.
        for key, what in pairs(numpad.cmdShiftActions or {}) do
            if hs.keycodes.map[key] ~= nil then
                hs.hotkey.bind(numpad.cmdShiftMods, key,
                               function() numpad.run(what) end)
                table.insert(numpad.bound, "⌘⇧" .. key)
            else
                table.insert(numpad.skipped, "⌘⇧" .. key)
            end
        end
        table.sort(numpad.bound)
        table.sort(numpad.skipped)
        -- 🚨 6.66.0 — A SKIPPED KEY IS NOW REPORTED, NOT WHISPERED.
        -- This used to be a bare print(). ⇪pad+ was assigned to the
        -- pomodoro in 6.65.0, documented in the cheat sheet, covered by a
        -- test — and on LL's Mac hs.keycodes.map["pad+"] is nil, so it was
        -- silently skipped and the key did nothing. The console said so,
        -- once, at boot, in a window nobody had open. That is precisely the
        -- silent failure rule 7 exists to forbid, in a module that already
        -- knew the answer and kept it to itself.
        if #numpad.skipped > 0 then
            local msg = table.concat(numpad.skipped, ", ")
            print("🔢 Numpad layer: this macOS has no key code for " .. msg
                  .. " — those are NOT bound. Run _G.padProbe() for the full map.")
            if _G.notices then
                _G.notices.record("numpad", "keys this Mac cannot send",
                    msg .. " — assigned but not bound. _G.padProbe() for detail")
            end
        end
        _G.diag.say("numpad", #numpad.bound .. " number-pad keys bound to ⇪")
        return #numpad.bound
    end

    if not numpad.enabled then
        -- The loader reads M.cheatsheet AFTER setup() returns, so rewriting
        -- it here is what puts the parked banner on the sheet. 6.101.0 —
        -- it is a LIST of groups now, and BOTH must say so: a sheet where
        -- the capture row admits it is parked while the window map still
        -- advertises live keys is worse than either alone.
        for _, g in ipairs(M.cheatsheet) do
            g.title = "🅿️ " .. g.title:gsub("^🔢 ", "")
                      .. " — PARKED (a plan, not live shortcuts)"
            table.insert(g.entries, 1, {
                "status", "NOTHING IS BOUND — every ⇪ + pad key is still free",
            })
            table.insert(g.entries, 2, {
                "to use it", "numpad.enabled = true in modules/numpad_layer.lua, then reload",
            })
        end
        _G.diag.say("numpad", "parked — no keys bound, layout kept for reference")
        _G.numpadLayer = numpad
        M.numpad = numpad
        M.config = numpad
        return
    end

    numpad.bindAll()

    -- =====================================================================
    -- _G.padProbe() — WHICH PAD KEYS DOES *THIS* MAC ACTUALLY HAVE?
    -- =====================================================================
    -- 🚨 WRITTEN BECAUSE ⇪pad+ SHIPPED DEAD. It was assigned, documented,
    -- listed on the cheat sheet and covered by a test — and on LL's Mac
    -- hs.keycodes.map["pad+"] is nil, so it was skipped at bind time and
    -- the key did nothing at all. Every layer of the process agreed it
    -- worked; the only thing that disagreed was the keyboard.
    --
    -- Run this BEFORE assigning a pad key, not after wondering why it does
    -- nothing. It prints, for every pad key this config knows about:
    --      the name · the key code macOS reports · what we bound to it
    -- A key with no code cannot be used on this Mac, full stop — that is
    -- macOS's keyboard layout talking, not Hammerspoon.
    function _G.padProbe()
        local names = { "pad0","pad1","pad2","pad3","pad4","pad5","pad6",
                        "pad7","pad8","pad9","pad.","pad+","pad-","pad*",
                        "pad/","pad=","padenter","padclear" }
        local out = {
            "════════════════════════════════════════════════════════",
            " NUMBER PAD PROBE   " .. os.date("%Y-%m-%d %H:%M"),
            " 'no code' = this Mac's keyboard layout cannot send it.",
            "════════════════════════════════════════════════════════",
            string.format("   %-10s %-9s %-22s %s", "KEY", "CODE", "⇪ DOES", "⇪⇧ DOES"),
        }
        local usable, dead = 0, {}
        for _, n in ipairs(names) do
            local code = hs.keycodes.map[n]
            local a = numpad.actions[n]
            local b = (numpad.shiftActions or {})[n]
            if code then usable = usable + 1 else dead[#dead + 1] = n end
            out[#out + 1] = string.format("   %-10s %-9s %-22s %s",
                n, code and tostring(code) or "no code",
                type(a) == "string" and a or (a and "(function)" or "—"),
                type(b) == "string" and b or (b and "(function)" or "—"))
        end
        out[#out + 1] = ""
        out[#out + 1] = string.format("   %d of %d pad keys exist on this Mac", usable, #names)
        -- 💻 6.114.0 — THE LAPTOP ANSWER, PRINTED BY THE TOOL YOU RUN WHEN
        -- THE PAD IS NOT WORKING. Someone reading this output has just
        -- discovered their pad keys do nothing; telling them the same nine
        -- zones are one row up is the single most useful line here.
        out[#out + 1] = ""
        out[#out + 1] = "   💻 NO PAD? The same zones are on ⇪⇧ + the NUMBER ROW:"
        local rowKeys = { "1","2","3","4","5","6","7","8","9",",",".","return" }
        for _, n in ipairs(rowKeys) do
            local what = (numpad.rowActions or {})[n]
            if what then
                out[#out + 1] = string.format("   %-10s %-9s %s",
                    "⇪⇧" .. n, hs.keycodes.map[n] and tostring(hs.keycodes.map[n])
                                or "no code", tostring(what))
            end
        end
        out[#out + 1] = "   ⇪2 opens the Quick Append Pad · ⇪↑ maximise · ⇪↓ put back"
        if #dead > 0 then
            out[#out + 1] = "   ❌ UNUSABLE HERE: " .. table.concat(dead, ", ")
            out[#out + 1] = "      Assigning any of those is assigning a key that"
            out[#out + 1] = "      cannot be pressed. Pick from the ones with a code."
        end
        out[#out + 1] = ""
        out[#out + 1] = "   ⚠️ If EVERY key says 'no code', or they all have codes"
        out[#out + 1] = "      and still do nothing, check System Settings →"
        out[#out + 1] = "      Accessibility → Pointer Control → Mouse Keys. When"
        out[#out + 1] = "      that is on, macOS eats the whole number pad and no"
        out[#out + 1] = "      application ever sees those keys."
        out[#out + 1] = "════════════════════════════════════════════════════════"
        local text = table.concat(out, "\n")
        print(text)
        pcall(function() hs.pasteboard.setContents(text) end)
        hs.alert.show("🔢 Pad probe copied — paste it back", 3)
        return text
    end

    core.provide("numpad.probe", function() return _G.padProbe() end)

    _G.numpadLayer = numpad
    M.numpad = numpad
    M.config = numpad
end

return M
