-- =====================================================================
-- MODULE: MOUSE GRID (⇪X) — type three letters, the pointer goes there
-- =====================================================================
-- ⇪X lays a labelled grid over every display. Every cell carries a
-- three-letter code ("agl"). Type it and the pointer jumps to that cell's
-- centre. Then either click with the trackpad, or stay on the keyboard:
-- SPACE clicks, arrows nudge, ⎋ backs out.
--
-- ⇪⇧X is the same thing that clicks for you the moment you finish typing.
-- ⌃⌥⌘⇧X is the panic key — see SAFETY below.
--
-- ---------------------------------------------------------------------
-- WHAT THIS IS, AND THE THING IT DELIBERATELY IS NOT
-- ---------------------------------------------------------------------
-- This is a COORDINATE tool. It divides screen area into cells and moves
-- the pointer. It knows nothing about what is underneath, which is
-- exactly why it never fails: it works over video, PDFs, a Photoshop
-- canvas, a remote desktop session, a game, a screen-shared window — any
-- pixel is reachable.
--
-- The other family of tool (Vimac, Homerow, Scoot's element mode) walks
-- the ACCESSIBILITY TREE, finds real buttons and links, and labels only
-- those. It is more precise where it works, and it is what "like tabbing
-- onto a button" literally means. It was not built here, on purpose:
--
--   · it returns nothing in Electron apps, nothing in Java apps, and
--     nothing in anything that draws its own controls
--   · a full AX walk of a large window costs 100–500ms, every invocation
--   · it needs Accessibility, which a managed Mac can withhold — and
--     this module has to work on the work MacBook
--
-- So the FEEL of "tab onto it, press space" is provided instead, without
-- the fragility: after the jump the pointer stays live (see LANDED MODE)
-- so SPACE activates whatever it is sitting on. If the grid ever proves
-- too coarse for real targets, element detection can be added later as a
-- second stage sharing this same key handling. It should not be merged
-- into this one — the two have opposite failure modes.
--
-- ---------------------------------------------------------------------
-- 🚨 SAFETY — THE REAL RISK IN THIS FILE
-- ---------------------------------------------------------------------
-- A full-screen overlay that captures keystrokes is the most dangerous
-- thing in this config. Get the state machine wrong and the Mac is
-- unusable until Hammerspoon is force-quit. Four defences, each of which
-- works when the other three have failed:
--
--   1. ONE INVARIANT, ONE EXIT. `grid.state ~= nil` ⟺ a modal is entered
--      ⟺ a canvas is visible. Every path out goes through grid.hide(),
--      which is idempotent and pcalls each teardown step separately, so
--      one failing step cannot strand the others.
--   2. WATCHDOG. An overlay that outlives its keypress tears itself down
--      (grid.timeoutSecs). Nothing here can sit on your screen forever.
--   3. PANIC KEY. ⌃⌥⌘⇧X is a PLAIN global chord, not a ⇪ shortcut —
--      because if ⇪ itself is what broke, a ⇪ panic key is no panic key.
--      Same reasoning as Screen Veil's ⌃⌥⌘⇧G.
--   4. UNBOUND KEYS PASS THROUGH. Only the alphabet plus a handful of
--      control keys are claimed. ⌘Q, ⌘Tab and ⌃F2 keep working while the
--      grid is up. This is a deliberate refusal to capture everything:
--      an overlay you can always ⌘Q out of cannot lock you out.
--
-- And LANDED MODE is never invisible. Whenever keys are being captured
-- there is something on screen saying so — the grid itself, or the
-- crosshair badge. A keyboard-eating mode with no visual is the hazard;
-- the badge is not decoration.
--
-- ---------------------------------------------------------------------
-- HOW MANY CELLS YOU GET — the arithmetic, because it is not obvious
-- ---------------------------------------------------------------------
-- Labels are FIXED length, which a grid requires: uniform cells cannot
-- carry a prefix-free variable-length code. So capacity is exactly
--
--        #alphabet ^ labelLength
--
-- Default: 9 home-row keys, 3 deep = 729 cells, and your fingers never
-- leave asdfghjkl. On one 1512×982 display that is ~34×21 cells of about
-- 45pt — near Apple's own 44pt minimum control size, so most targets are
-- a straight hit.
--
-- ⚠️ TWO OR MORE DISPLAYS SPLIT THAT 729. Two screens gives roughly
-- 85pt cells, which is coarser than many buttons — the arrow-key nudge in
-- landed mode exists for exactly that. If you run multiple displays and
-- want the fine grid back, buy capacity by widening the alphabet:
--
--        "asdfghjkl"          9  ->    729 cells
--        "asdfghjklzxcvbnm"  16  ->  4,096 cells   (adds the bottom row)
--        "asdfghjkl", len 4   9  ->  6,561 cells   (home row, 4 keystrokes)
--
-- `_G.mouseGridReport()` prints what this Mac actually resolved to —
-- per screen, cols × rows and the real cell size in points. Run it once
-- on each machine; it is the fastest way to see whether the grid is fine
-- enough for the way you work.
--
-- ---------------------------------------------------------------------
-- WHY IT IS FAST — and it has to be, or you will not use it
-- ---------------------------------------------------------------------
-- 729 cells is ~1,500 canvas elements. Rebuilding that on every press
-- would put a visible stall between the keystroke and the grid, which is
-- the difference between a tool you reach for and one you forget. So:
--
--   · GRID LINES AND SCRIM are one canvas per screen, built ONCE for a
--     given display layout and cached forever after. ~50 elements.
--   · LABELS are a SECOND canvas, and the only thing rebuilt. The full
--     unfiltered element table is cached too, so even the first draw is
--     a table reuse rather than a build, from the second invocation on.
--   · FILTERING SHRINKS IT. Type one letter and 729 candidates become
--     81; another and 81 become 9. Every redraw after the first is
--     cheaper than the one before it.
--   · The cache is keyed on the display layout and invalidated by a
--     screen watcher, so plugging in a monitor rebuilds rather than
--     drawing yesterday's grid over today's screens.
--
-- Timings go to the diagnostic trail on every show; `_G.diag.verbose =
-- true` puts them in the Console.
--
-- ⚠️ ACCESSIBILITY: MOVING AND CLICKING ARE NOT THE SAME PERMISSION.
-- Warping the pointer needs nothing at all, so the JUMP always works,
-- on any Mac, granted or not. Synthesising a CLICK goes through
-- hs.eventtap, which macOS gates behind Accessibility. Without it the
-- grid still jumps and SPACE reports why it could not click, rather than
-- doing nothing and looking broken.

local M = {
    name  = "Mouse Grid",
    order = 13.6,
    cheatsheet = {
        title = "🎯 MOUSE GRID (⇪X — type 3 letters, the pointer goes there)",
        entries = {
            { "⇪X",       "Overlay the labelled grid on every display" },
            { "⇪⇧X",      "Same, but click the moment you finish typing" },
            { "asdfghjkl","Type a cell's 3 letters — the pointer jumps there" },
            { "⌫",        "Undo one letter while typing" },
            { "⎋",        "Cancel — the pointer does not move" },
            { "-- after it lands --", "" },
            { "space",    "Left click · ⇧space right click · 2 double click" },
            { "↑↓←→",     "Nudge 8pt · with ⇧ nudge 1pt for a tight target" },
            { "⎋",        "Done — leave the pointer where it is" },
            { "⇪⇧L",      "Find the pointer — flashes a ring around it" },
            { "⌃⌥⌘⇧X",   "PANIC — tear the overlay down whatever state it is in" },
            { "check it", "_G.mouseGridReport() — cell size on THIS Mac" },
        },
    },
}

function M.setup(core)
    local grid = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    grid.enabled     = true
    grid.key         = "x"          -- ⇪X. ⇪⇧X is the click-on-arrival twin.
    -- 🖱 6.66.0 — THE POINTER RING GETS A REAL KEY AT LAST. grid.locate()
    -- has existed since 6.45.0 and was bound to nothing on the argument
    -- that macOS shake-to-grow already covers it. 6.65.0 put it on ⇪pad*,
    -- and 6.66.0 cleared the pad layer — so it lands on a letter, which is
    -- also the only kind of key that cannot turn out to be missing from
    -- this keyboard (see _G.padProbe and the ⇪pad+ story).
    grid.locateKey   = "l"          -- ⇪⇧L — L for locate

    -- Capacity is alphabet^labelLength — see the arithmetic block above.
    -- These two are ONE decision, not two: changing either changes how
    -- many cells exist and therefore how precise the grid is.
    grid.alphabet    = "asdfghjkl"  -- home row only; never leave it
    grid.labelLength = 3

    -- 🎨 The look you asked for. Read as COVERAGE and BRIGHTNESS, which is
    -- the only reading that works: a 30% *opaque* grey would hide the very
    -- thing you are aiming at.
    --   scrim = black at 30% alpha  ("a 30% shade of grey")
    --   lines = 80% white           ("lines are 80% grey")
    grid.scrimWhite  = 0.00
    grid.scrimAlpha  = 0.30
    grid.lineWhite   = 0.80
    grid.lineAlpha   = 0.55
    grid.lineWidth   = 1.0

    -- 🔠 6.65.0 — LABEL SIZE IS NOW A FLOOR PLUS A FIT, not one number.
    -- 12pt was chosen when the only question was "does it fit". The
    -- question that actually matters is "can you read it at a glance from
    -- normal sitting distance", and 12 loses that on a 4K panel where a
    -- cell is physically small. labelSize is the MINIMUM; labelFitFrac
    -- lets a label grow to fill its box on a coarse grid, and the whole
    -- thing is clamped by width so a 3-character label can never spill
    -- out of a narrow cell (see fittedLabelSize below).
    grid.labelSize    = 14      -- floor, in points. Never smaller than this.
    grid.labelFitFrac = 0.55    -- of cell HEIGHT, when there is room for more
    grid.labelMaxSize = 34      -- ceiling, so a 2-column grid isn't absurd
    grid.labelWhite  = 1.00
    grid.labelAlpha  = 0.95

    -- 🟡 6.65.0 — THE MATCH HIGHLIGHT. Once you type a letter, the cells
    -- that are still reachable get a thick yellow box and everything else
    -- gets out of the way (see redraw() — the lattice itself is dropped on
    -- the first keystroke, so what is left on screen is only what you can
    -- still choose). Before this the survivors were distinguished purely
    -- by "the other labels went away", which is a difference you have to
    -- look for rather than one that arrives on its own.
    grid.matchStroke  = { red = 1.00, green = 0.84, blue = 0.00 }  -- amber
    grid.matchWidth   = 3.0     -- border thickness, in points
    grid.matchFill    = { red = 1.00, green = 0.84, blue = 0.00, alpha = 0.13 }
    grid.matchRadius  = 4       -- rounded corners; 0 for square
    -- Drop the grid lines once typing starts, so the survivors stand alone
    -- on the scrim. false keeps the full lattice up the whole time.
    grid.dropLattice  = true

    -- After the jump, stay live so SPACE can click (the "tab onto it"
    -- feel). false = jump and get out of the way immediately.
    grid.landedMode  = true
    grid.nudgeStep   = 8            -- arrows, in points
    grid.nudgeFine   = 1            -- ⇧ + arrows

    -- 🚨 Watchdogs. Neither of these is a nicety.
    grid.timeoutSecs = 12           -- overlay up, nothing typed
    grid.landedSecs  = 8            -- landed badge up, nothing pressed

    -- "screenSaver" draws ABOVE the menu bar, which is required: at
    -- "overlay" the top ~25pt of the grid hides behind it and menu-bar
    -- items become unreachable. The cost is that it also covers
    -- hs.alert, so every error path below hides the grid BEFORE it
    -- alerts. Change this only if something pokes through.
    grid.windowLevel = "screenSaver"
    -- ----------------------------------------------------------------------

    -- ---- state -----------------------------------------------------------
    -- 🚨 THE INVARIANT: state ~= nil  ⟺  a modal is entered  ⟺  a canvas
    -- is visible. Nothing may break this. grid.hide() is the only way out
    -- and it restores all three together.
    grid.state    = nil
    grid.cache    = nil    -- geometry + canvases, keyed on the screen layout
    grid.watchdog = nil    -- HELD: an unreferenced hs.timer is collected and
                           -- silently never fires. That lesson cost 6.33.0 a
                           -- warm-up, and here it would cost the watchdog.
    grid.screenWatch = nil -- HELD for the same reason
    grid.cross    = nil    -- the landed-mode badge canvas

    -- 🐛 A FLAT LIST OF WHAT IS ON SCREEN, KEPT DELIBERATELY SEPARATE FROM
    -- grid.cache. The first version of hide() walked `grid.cache.screens or
    -- {}` to put the overlay away, and the test suite caught what that
    -- means: when the thing that broke IS the cache, `or {}` makes the
    -- teardown a no-op. The modal exited, the state cleared, and the sheet
    -- stayed on screen at screenSaver level over everything.
    --
    -- Teardown must never depend on the structure that just failed. So
    -- every canvas made visible is recorded here, and hide() walks THIS.
    grid.shown = {}

    local function showCanvas(c)
        if not c then return end
        -- 🚨 6.66.3 — THROUGH showCanvasSafely, NOT A BARE :show().
        -- From LL's Console, on a hotkey press while Safari's URL-completion
        -- popup was on screen:
        --   NSInternalInconsistencyException: '<NSRemoteView …
        --   SPCompletionListServiceViewController> notified of <HSCanvasWindow>
        --   but expected (null)' in -[NSRemoteView containingWindowWillOrderOnScreen:]
        -- AppKit asserts when our window is ordered on screen while ANOTHER
        -- process's remote view is mid-transition. It is a timing collision, not
        -- a permanent state, which is why the shared helper retries once a run
        -- loop turn later and only then reports. A bare :show() throws, abandons
        -- the rest of the open sequence, and leaves a half-ordered ghost.
        if _G.showCanvasSafely then
            _G.showCanvasSafely(c, "mouse grid")
        else
            pcall(function() c:show() end)
        end
        grid.shown[#grid.shown + 1] = c
    end

    -- Idempotent, and each canvas is pcall'd on its own: one throwing must
    -- not leave the rest of them up.
    local function hideAllShown()
        for _, c in ipairs(grid.shown) do
            pcall(function() c:hide() end)
        end
        grid.shown = {}
    end

    local function say(msg) if _G.diag then _G.diag.say("mouseGrid", msg) end end
    local function warn(msg) if _G.diag then _G.diag.warn("mouseGrid", msg) end end

    -- =====================================================================
    -- LABELS
    -- =====================================================================
    -- Index -> label, plain base-N in the alphabet. Row-major assignment
    -- means the FIRST letter always selects a contiguous horizontal band,
    -- so typing it lights up a block you can see rather than a scatter.
    -- ⚠️ ONLY KEYS THIS KEYBOARD CAN ACTUALLY SEND. hs.hotkey's getKeycode
    -- RAISES on a name your keymap has no code for — it does not return nil
    -- — so one exotic character in grid.alphabet would take the whole
    -- module down at setup(). Numpad Layer learned the same lesson against
    -- the same API; this is the same guard.
    --
    -- Filtering HERE rather than at bind time is deliberate: the alphabet
    -- feeds the geometry as well, so a letter you cannot type would
    -- otherwise label cells you can never reach.
    local warnedKeys = false
    local function alphabetChars()
        local t, dropped = {}, {}
        local map = (hs.keycodes and hs.keycodes.map) or nil
        for ch in tostring(grid.alphabet):gmatch(".") do
            local c = ch:lower()
            -- No keycodes table at all (a test harness) means take it as
            -- given rather than silently returning an empty alphabet.
            if map == nil or map[c] ~= nil then t[#t + 1] = c
            else dropped[#dropped + 1] = c end
        end
        if #dropped > 0 and not warnedKeys then
            warnedKeys = true
            print("🎯 Mouse Grid: this keyboard layout has no key code for "
                  .. table.concat(dropped, ", ") .. " — dropped from the alphabet")
            warn("dropped unusable alphabet keys: " .. table.concat(dropped, ", "))
        end
        return t
    end

    local function labelFor(index, chars)
        local n, out = #chars, {}
        for place = grid.labelLength, 1, -1 do
            local digit = math.floor(index / (n ^ (place - 1))) % n
            out[#out + 1] = chars[digit + 1]
        end
        return table.concat(out)
    end

    -- =====================================================================
    -- GEOMETRY
    -- =====================================================================
    -- fullFrame(), NOT frame(). frame() excludes the menu bar and the Dock,
    -- and a pointer tool that cannot reach the menu bar or the Dock has
    -- given away two of the places you most want to click.
    -- ⚠️ NO "%d" ON SCREEN GEOMETRY, ANYWHERE. In Lua 5.4
    -- string.format("%d", x) RAISES "number has no integer representation"
    -- for any float that is not exactly integral, and a scaled display's
    -- frame is not something this module controls. A cache key only has to
    -- be stable and unique, so tostring() is both safer and sufficient.
    local function layoutKey()
        local parts = {}
        local okAll, screens = pcall(hs.screen.allScreens)
        if not (okAll and screens) then return "no-screens" end
        for _, s in ipairs(screens) do
            local okF, f = pcall(function() return s:fullFrame() end)
            local okI, id = pcall(function() return s:id() end)
            if okF and type(f) == "table" then
                parts[#parts + 1] = table.concat({ tostring(okI and id or "?"),
                    tostring(f.x), tostring(f.y), tostring(f.w), tostring(f.h) }, ",")
            end
        end
        parts[#parts + 1] = string.format("|%s^%d|%.2f|%.2f|%.2f",
            grid.alphabet, grid.labelLength, grid.scrimAlpha, grid.lineAlpha, grid.labelSize)
        return table.concat(parts, ";")
    end

    -- Split the label space across displays BY AREA, then pick the
    -- cols×rows that lands closest to square cells for that display's
    -- aspect. Doing it by area rather than per-screen-equally is what
    -- stops a 27" monitor getting the same 200 cells as a laptop panel.
    -- 🚨 ONE EXPRESSION DOES TWO JOBS, AND IT STOPS A HANG.
    --
    -- `math.max(1, math.min(cols, share))` is not defensive padding:
    --
    --   · CORRECTNESS. cols <= share means cols*rows <= share, so every
    --     cell gets a label. Without it an extreme aspect ratio on a small
    --     share produces more cells than there are labels, and the surplus
    --     is a region of your screen you can never reach. The fuzzer finds
    --     this within ~50 layouts once the clamp is gone.
    --
    --   · NO HANG. A display reporting height 0 — one disconnecting
    --     between allScreens() and fullFrame(), a virtual display, some
    --     screen-sharing sessions — makes w/h infinite, and
    --     math.floor(math.huge) is math.huge in Lua. `cols` becomes inf
    --     and the loop below becomes `for c = 0, inf`: Hammerspoon spins
    --     forever, with no error and no recovery but a force-quit. A hang
    --     is strictly worse than a crash, because a crash tells you what
    --     happened. share is bounded by capacity, and min()/max() collapse
    --     BOTH inf and NaN into [1, share], so the loop is always finite.
    --
    -- ⚠️ An earlier version had a separate `if cols ~= cols or cols ==
    -- math.huge` line above this. It was deleted, not because it was
    -- wrong, but because it was UNREACHABLE: the clamp already handles
    -- both cases, so nothing could ever test that line. Untested code that
    -- looks like a safety net is worse than no code — the next reader
    -- trusts it.
    local function planScreen(frame, share)
        if share < 1 then share = 1 end
        local cols = math.floor(math.sqrt(share * frame.w / frame.h) + 0.5)
        cols = math.max(1, math.min(cols, share))
        local rows = math.max(1, math.floor(share / cols))
        return cols, rows
    end

    -- A frame we can actually divide. Anything else is skipped and named,
    -- because a display quietly missing from the grid is a region of screen
    -- you cannot reach and no clue as to why.
    local function usableFrame(f)
        if type(f) ~= "table" then return false end
        for _, v in ipairs({ f.x, f.y, f.w, f.h }) do
            if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
                return false
            end
        end
        return f.w > 0 and f.h > 0
    end

    local function buildGeometry()
        local t0     = hs.timer.secondsSinceEpoch()
        local chars  = alphabetChars()
        -- ⚠️ THE PARENTHESES ARE LOAD-BEARING. In Lua `^` binds TIGHTER than
        -- the unary `#`, so `#chars ^ n` parses as `#(chars ^ n)` and tries
        -- to exponentiate a table. Same family of precedence trap that
        -- crashed capabilities.lua's word-wrap in 6.44.13 — clever
        -- one-liners in arithmetic buy nothing and cost a crash.
        local capacity = (#chars) ^ grid.labelLength
        local screens  = hs.screen.allScreens()

        -- Sanity-filter FIRST. Every number below is divided by or looped
        -- over, so one bad frame reaching planScreen is the hang described
        -- there. A skipped display is named rather than silently absent.
        local usable, totalArea, skipped = {}, 0, 0
        for _, s in ipairs(screens) do
            local okF, f = pcall(function() return s:fullFrame() end)
            if okF and usableFrame(f) then
                usable[#usable + 1] = f
                totalArea = totalArea + (f.w * f.h)
            else
                skipped = skipped + 1
            end
        end
        if skipped > 0 then
            warn(skipped .. " display(s) reported an unusable frame and were "
                 .. "left out of the grid")
        end
        if #usable == 0 or totalArea <= 0 then
            return nil, "no display reported a usable frame"
        end

        local plan, index, truncated = {}, 0, 0
        for _, f in ipairs(usable) do
            local share = math.floor(capacity * (f.w * f.h) / totalArea)
            local cols, rows = planScreen(f, share)
            local cw, ch = f.w / cols, f.h / rows

            local cells = {}
            for r = 0, rows - 1 do
                for c = 0, cols - 1 do
                    if index >= capacity then
                        -- Reported, never silent. A silently truncated grid
                        -- means a corner of a screen you can never reach and
                        -- no clue as to why.
                        truncated = truncated + 1
                    else
                        cells[#cells + 1] = {
                            label = labelFor(index, chars),
                            -- canvas-relative, for drawing
                            rx = c * cw, ry = r * ch, rw = cw, rh = ch,
                            -- absolute screen coords, for the pointer
                            ax = f.x + c * cw + cw / 2,
                            ay = f.y + r * ch + ch / 2,
                        }
                        index = index + 1
                    end
                end
            end
            plan[#plan + 1] = {
                frame = f, cols = cols, rows = rows,
                cellW = cw, cellH = ch, cells = cells,
            }
        end

        local ms = (hs.timer.secondsSinceEpoch() - t0) * 1000
        if truncated > 0 then
            warn(string.format("%d cells had no label left (capacity %d) — "
                .. "widen grid.alphabet or raise grid.labelLength", truncated, capacity))
        end
        say(string.format("geometry: %d screens, %d cells of %d capacity, %.1fms",
            #plan, index, capacity, ms))
        return { screens = plan, used = index, capacity = capacity,
                 truncated = truncated, chars = chars }
    end

    -- =====================================================================
    -- DRAWING
    -- =====================================================================
    -- The scrim and the lines never change for a given layout, so they are
    -- built once and then only shown/hidden. Lines are drawn as segments
    -- (2 points, stroked) rather than thin rectangles so strokeWidth means
    -- exactly what it says at any scale factor.
    local function gridElements(p)
        local els = {
            { type = "rectangle", action = "fill",
              fillColor = { white = grid.scrimWhite, alpha = grid.scrimAlpha },
              frame = { x = 0, y = 0, w = p.frame.w, h = p.frame.h } },
        }
        local stroke = { white = grid.lineWhite, alpha = grid.lineAlpha }
        for c = 1, p.cols - 1 do
            local x = c * p.cellW
            els[#els + 1] = { type = "segments", action = "stroke",
                strokeColor = stroke, strokeWidth = grid.lineWidth,
                coordinates = { { x = x, y = 0 }, { x = x, y = p.frame.h } } }
        end
        for r = 1, p.rows - 1 do
            local y = r * p.cellH
            els[#els + 1] = { type = "segments", action = "stroke",
                strokeColor = stroke, strokeWidth = grid.lineWidth,
                coordinates = { { x = 0, y = y }, { x = p.frame.w, y = y } } }
        end
        return els
    end

    -- One text element per visible cell. `typedLen` chars are dropped from
    -- the front of every label: once you have typed "a", every remaining
    -- candidate starts with "a", so repeating it is noise — showing only
    -- what is left to type is both clearer and progressively cheaper to
    -- draw, which is the whole performance story on the next redraw.
    -- 🚨 6.62.0 — NEVER HAND hs.canvas AN EMPTY ELEMENT LIST.
    -- Reported from LL's Console, four times in one session:
    --   canvas.lua:382: bad argument #1 to 'assignElement'
    --   (invalid element definition; must contain key-value pairs)
    --
    -- replaceElements(...) packs its varargs and only unwraps the
    -- single-table form when that table is NON-EMPTY:
    --     if elementList.n == 1 and #elementList[1] ~= 0 then ...
    -- so replaceElements({}) does not mean "draw nothing". It means "draw
    -- this one element", the element being `{}` — which has no key-value
    -- pairs, so it throws.
    --
    -- WHERE IT BIT: typeChar filters cells by the typed prefix and then
    -- redraws EVERY screen. With two displays the matches for a letter
    -- can all live on one of them, leaving the other with zero elements.
    -- typeChar's own `n == 0` guard does not catch it, because n counts
    -- matches ACROSS ALL SCREENS — it is non-zero while an individual
    -- screen has none. And because typeChar runs inside a pcall, the
    -- throw did not just log: it HID THE GRID. Typing the first letter
    -- made the grid vanish.
    --
    -- An element with action = "skip" is a valid definition that draws
    -- nothing, which is exactly "this screen has no candidates". Built
    -- fresh each call rather than shared, so no canvas can ever hold a
    -- reference to a table another canvas might be handed.
    local function setElements(canvas, els)
        if not canvas then return end
        if type(els) ~= "table" or #els == 0 then
            els = { { type = "rectangle", action = "skip" } }
        end
        canvas:replaceElements(els)
    end

    -- 🔠 6.65.0 — HOW BIG THE LABEL ACTUALLY GETS.
    -- Two constraints, and the SMALLER of them wins, then the floor is
    -- applied last so a genuinely tiny cell still gets legible text even
    -- if that means the glyphs touch the cell edges:
    --   · HEIGHT — labelFitFrac of the cell, so text sits in its box.
    --   · WIDTH  — the remaining characters have to fit across the cell.
    --     0.62 is the measured average advance of this config's alphabet
    --     (home row, no wide glyphs) as a fraction of point size; it is
    --     the same constant §mouseGridReport already uses to warn about
    --     cells too narrow to label, so the two agree by construction.
    -- `chars` is how many characters are still to be typed, NOT the full
    -- label: after "a" the cell shows two characters and may therefore
    -- use a larger size than it could have at three.
    local function fittedLabelSize(p, chars)
        chars = math.max(1, chars or grid.labelLength)
        local byHeight = p.cellH * grid.labelFitFrac
        local byWidth  = (p.cellW * 0.92) / (chars * 0.62)
        local size     = math.min(byHeight, byWidth, grid.labelMaxSize)
        return math.max(grid.labelSize, size)
    end

    -- The label canvas carries BOTH the amber match boxes and the text,
    -- boxes first so the text paints on top of them. One list, one
    -- replaceElements — two canvases would mean two draws per keystroke
    -- and a way for them to disagree about which cells still match.
    local function labelElements(p, typedLen, matches)
        local els  = {}
        local size = fittedLabelSize(p, grid.labelLength - typedLen)
        local pad  = math.max(0, (p.cellH - size * 1.25) / 2)
        for _, cell in ipairs(p.cells) do
            if matches == nil or matches[cell.label] then
                -- Highlight only while narrowing. With nothing typed every
                -- cell matches, and boxing all of them is not a highlight,
                -- it is a second lattice on top of the first.
                if matches ~= nil then
                    els[#els + 1] = {
                        type = "rectangle", action = "strokeAndFill",
                        strokeColor = { red   = grid.matchStroke.red,
                                        green = grid.matchStroke.green,
                                        blue  = grid.matchStroke.blue, alpha = 1.0 },
                        fillColor   = grid.matchFill,
                        strokeWidth = grid.matchWidth,
                        roundedRectRadii = { xRadius = grid.matchRadius,
                                             yRadius = grid.matchRadius },
                        -- Inset by half the stroke so the border sits
                        -- INSIDE the cell. Drawn on the boundary, adjacent
                        -- survivors share a doubled line and read as one
                        -- wide box rather than two separate targets.
                        frame = { x = cell.rx + grid.matchWidth / 2,
                                  y = cell.ry + grid.matchWidth / 2,
                                  w = math.max(1, cell.rw - grid.matchWidth),
                                  h = math.max(1, p.cellH - grid.matchWidth) },
                    }
                end
                els[#els + 1] = {
                    type = "text",
                    text = cell.label:sub(typedLen + 1),
                    textSize  = size,
                    textColor = { white = grid.labelWhite, alpha = grid.labelAlpha },
                    textAlignment = "center",
                    frame = { x = cell.rx, y = cell.ry + pad,
                              w = cell.rw, h = p.cellH - pad },
                }
            end
        end
        return els
    end

    -- Build (or reuse) every canvas for the current layout.
    local function ensureCache()
        local key = layoutKey()
        if grid.cache and grid.cache.key == key then return grid.cache end

        if grid.cache then
            for _, s in ipairs(grid.cache.screens or {}) do
                pcall(function() if s.gridCanvas then s.gridCanvas:delete() end end)
                pcall(function() if s.labelCanvas then s.labelCanvas:delete() end end)
            end
        end

        local geo, err = buildGeometry()
        if not geo then return nil, err end

        local t0 = hs.timer.secondsSinceEpoch()
        local level = (hs.canvas.windowLevels or {})[grid.windowLevel]
                      or (hs.canvas.windowLevels or {}).overlay
        for _, p in ipairs(geo.screens) do
            local gc = hs.canvas.new(p.frame)
            local lc = hs.canvas.new(p.frame)
            if not (gc and lc) then
                return nil, "hs.canvas.new returned nil — cannot draw the overlay"
            end
            setElements(gc, gridElements(p))
            for _, c in ipairs({ gc, lc }) do
                pcall(function() c:level(level) end)
                pcall(function()
                    c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
                end)
            end
            p.gridCanvas  = gc
            p.labelCanvas = lc
            -- The unfiltered label table is the expensive one; cached so
            -- that from the second invocation on, showing the grid is a
            -- table reuse rather than a build.
            p.fullLabels  = labelElements(p, 0, nil)
        end

        say(string.format("canvases built: %.1fms (level %s)",
            (hs.timer.secondsSinceEpoch() - t0) * 1000, grid.windowLevel))
        grid.cache = { key = key, screens = geo.screens, used = geo.used,
                       capacity = geo.capacity, truncated = geo.truncated,
                       chars = geo.chars }
        return grid.cache
    end

    -- =====================================================================
    -- THE LANDED BADGE — the visual proof that keys are being captured
    -- =====================================================================
    local function showCrosshair(px, py)
        local W, H = 232, 78
        local scr  = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
        local sf   = scr and scr:fullFrame() or { x = 0, y = 0, w = 1440, h = 900 }
        -- Clamped into the display, then the rings are drawn wherever the
        -- point ended up INSIDE that box — so the badge stays on screen at
        -- an edge without the crosshair drifting off the actual target.
        local cx = math.max(sf.x, math.min(px - W / 2, sf.x + sf.w - W))
        local cy = math.max(sf.y, math.min(py - 26,    sf.y + sf.h - H))
        local rx, ry = px - cx, py - cy

        pcall(function() if grid.cross then grid.cross:delete() end end)
        grid.cross = nil
        local c = hs.canvas.new({ x = cx, y = cy, w = W, h = H })
        -- 🚨 RETURNS FALSE, AND THE CALLER MUST ACT ON IT. The old cross has
        -- already been destroyed by this point, so carrying on would leave
        -- landed mode capturing the keyboard with NOTHING on screen saying
        -- so — the precise hazard the whole design forbids.
        if not c then return false end
        local ink = { white = 1.0, alpha = 0.95 }
        c:replaceElements({
            { type = "circle", action = "stroke", strokeColor = ink, strokeWidth = 2,
              center = { x = rx, y = ry }, radius = 13 },
            { type = "circle", action = "fill", fillColor = { white = 1.0, alpha = 0.9 },
              center = { x = rx, y = ry }, radius = 2 },
            { type = "segments", action = "stroke", strokeColor = ink, strokeWidth = 1.5,
              coordinates = { { x = rx - 22, y = ry }, { x = rx - 17, y = ry } } },
            { type = "segments", action = "stroke", strokeColor = ink, strokeWidth = 1.5,
              coordinates = { { x = rx + 17, y = ry }, { x = rx + 22, y = ry } } },
            { type = "segments", action = "stroke", strokeColor = ink, strokeWidth = 1.5,
              coordinates = { { x = rx, y = ry - 22 }, { x = rx, y = ry - 17 } } },
            { type = "segments", action = "stroke", strokeColor = ink, strokeWidth = 1.5,
              coordinates = { { x = rx, y = ry + 17 }, { x = rx, y = ry + 22 } } },
            { type = "rectangle", action = "fill",
              fillColor = { white = 0.0, alpha = 0.72 }, roundedRectRadii = { xRadius = 5, yRadius = 5 },
              frame = { x = 8, y = H - 24, w = W - 16, h = 18 } },
            { type = "text", text = "space click · ↑↓←→ nudge · ⎋ done",
              textSize = 11, textColor = { white = 1.0, alpha = 0.95 },
              textAlignment = "center",
              frame = { x = 8, y = H - 23, w = W - 16, h = 17 } },
        })
        pcall(function()
            c:level((hs.canvas.windowLevels or {})[grid.windowLevel]
                    or (hs.canvas.windowLevels or {}).overlay)
        end)
        pcall(function() c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        c:show()
        grid.cross = c
        return true
    end

    -- =====================================================================
    -- TEARDOWN — the single exit. Everything else calls this.
    -- =====================================================================
    -- 🚨 Idempotent, and every step is pcall'd SEPARATELY on purpose: if
    -- hiding one canvas throws, the modal must still exit and the rest
    -- must still come down. A shared pcall would let one failure strand
    -- the overlay, which is precisely the lock-out this guards against.
    function grid.hide(reason)
        if grid.watchdog then
            pcall(function() grid.watchdog:stop() end)
            grid.watchdog = nil
        end
        hideAllShown()
        pcall(function() if grid.cross then grid.cross:delete() end end)
        grid.cross = nil
        pcall(function() if grid.pickModal then grid.pickModal:exit() end end)
        pcall(function() if grid.landModal then grid.landModal:exit() end end)
        if grid.state then
            say("closed (" .. tostring(reason or "done") .. ")")
            grid.state = nil
        end
    end

    local function armWatchdog(secs, why)
        if grid.watchdog then pcall(function() grid.watchdog:stop() end) end
        grid.watchdog = hs.timer.doAfter(secs, function()
            warn("watchdog fired after " .. secs .. "s — " .. why)
            grid.hide("watchdog")
        end)
    end

    -- =====================================================================
    -- CLICKING
    -- =====================================================================
    -- Moving the pointer needs no permission; clicking does. Kept apart so
    -- the failure is specific: on a Mac without Accessibility the jump
    -- still works and only the click reports why.
    local function axAvailable()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    local function clickAt(point, kind)
        if not axAvailable() then
            grid.hide("click refused")
            hs.alert.show("🎯 Pointer moved. macOS will not let Hammerspoon "
                .. "click without Accessibility —\nSystem Settings → Privacy & "
                .. "Security → Accessibility. Trackpad click still works.")
            warn("click requested with Accessibility off")
            return false
        end
        local ok, err = pcall(function()
            if kind == "right" then
                hs.eventtap.rightClick(point)
            elseif kind == "double" then
                -- A real double click is ONE property, not two fast clicks:
                -- without clickState = 2 most apps see two singles and you
                -- get two selections instead of an open. Falls back to two
                -- clicks if this build has no such property.
                local e  = hs.eventtap.event
                local okd = pcall(function()
                    for _, t in ipairs({ e.types.leftMouseDown, e.types.leftMouseUp,
                                         e.types.leftMouseDown, e.types.leftMouseUp }) do
                        e.newMouseEvent(t, point)
                         :setProperty(e.properties.mouseEventClickState, 2)
                         :post()
                    end
                end)
                if not okd then
                    hs.eventtap.leftClick(point); hs.eventtap.leftClick(point)
                end
            else
                hs.eventtap.leftClick(point)
            end
        end)
        if not ok then
            grid.hide("click failed")
            hs.alert.show("🎯 Could not click — see the Console")
            warn("click failed: " .. tostring(err))
            return false
        end
        say(kind .. " click at " .. math.floor(point.x) .. "," .. math.floor(point.y))
        return true
    end

    local function movePointer(point)
        -- ⚠️ NO setAbsolutePosition FALLBACK. It looks like a safety net and
        -- is not one: in Hammerspoon's source setAbsolutePosition is a
        -- deprecated shim whose entire body calls absolutePosition and
        -- prints a deprecation notice. Retrying through it would re-run the
        -- call that just failed and spam the Console for the privilege.
        local ok, err = pcall(function() hs.mouse.absolutePosition(point) end)
        if not ok then warn("could not move the pointer: " .. tostring(err)) end
        return ok
    end

    -- =====================================================================
    -- LANDED MODE
    -- =====================================================================
    local function enterLanded(point)
        hideAllShown()
        pcall(function() grid.pickModal:exit() end)
        local okEnter = pcall(function() grid.landModal:enter() end)
        if not okEnter then
            -- Could not take the keyboard, so do not pretend to have it:
            -- the pointer has already moved, which is most of the value.
            grid.hide("could not enter landed mode")
            warn("landModal:enter() failed — pointer moved, keys not captured")
            return
        end
        grid.state = { phase = "landed", point = point }
        if not showCrosshair(point.x, point.y) then
            grid.hide("no badge could be drawn")
            warn("landed badge could not be drawn — refusing to capture keys "
                 .. "invisibly; the pointer has still moved")
            return
        end
        armWatchdog(grid.landedSecs, "landed badge left open")
        say("landed at " .. math.floor(point.x) .. "," .. math.floor(point.y))
    end

    local function nudge(dx, dy)
        local s = grid.state
        if not (s and s.phase == "landed") then return end
        local p = { x = s.point.x + dx, y = s.point.y + dy }
        s.point = p
        movePointer(p)
        if not showCrosshair(p.x, p.y) then
            grid.hide("badge lost during nudge")
            warn("badge could not be redrawn mid-nudge — refusing to capture "
                 .. "keys invisibly")
            return
        end
        armWatchdog(grid.landedSecs, "landed badge left open")
    end

    local function landedClick(kind)
        local s = grid.state
        if not (s and s.phase == "landed") then return end
        local point = s.point
        -- Hide FIRST. The badge sits at screenSaver level, directly over
        -- the thing being clicked, and a menu opening underneath an
        -- overlay is a confusing half-second. It also means the alert in
        -- clickAt() is visible rather than covered.
        grid.hide("clicked")
        clickAt(point, kind)
    end

    -- =====================================================================
    -- TYPING
    -- =====================================================================
    -- 🟡 6.65.0 — "the other boxes fall away". The lattice is one scrim
    -- plus (cols-1)+(rows-1) line segments; dropping the segments and
    -- keeping the scrim leaves the survivors' amber boxes alone on a dark
    -- field. That is ONE element to draw, not one per discarded cell, so
    -- the more the grid narrows the CHEAPER this gets — the opposite of
    -- greying out each loser individually.
    local function scrimOnly(p)
        return { { type = "rectangle", action = "fill",
                   fillColor = { white = grid.scrimWhite, alpha = grid.scrimAlpha },
                   frame = { x = 0, y = 0, w = p.frame.w, h = p.frame.h } } }
    end

    local function redraw()
        local s = grid.state
        if not (s and s.phase == "pick") then return end
        local t0, shown = hs.timer.secondsSinceEpoch(), 0
        -- Tracked so the lattice is rebuilt exactly once when you
        -- backspace all the way out, rather than on every keystroke.
        local bare = grid.dropLattice and #s.typed > 0
        for _, p in ipairs(grid.cache.screens) do
            if bare ~= s.latticeDropped then
                setElements(p.gridCanvas, bare and scrimOnly(p) or gridElements(p))
            end
            if #s.typed == 0 then
                setElements(p.labelCanvas, p.fullLabels)
                shown = shown + #p.fullLabels
            else
                local els = labelElements(p, #s.typed, s.matches)
                setElements(p.labelCanvas, els)
                shown = shown + #els
            end
        end
        s.latticeDropped = bare
        say(string.format("typed '%s' -> %d candidates, redraw %.1fms",
            s.typed, shown, (hs.timer.secondsSinceEpoch() - t0) * 1000))
    end

    local function cellFor(label)
        for _, p in ipairs(grid.cache.screens) do
            for _, c in ipairs(p.cells) do
                if c.label == label then return c end
            end
        end
        return nil
    end

    function grid.typeChar(ch)
        local s = grid.state
        if not (s and s.phase == "pick") then return end

        local nextTyped = s.typed .. ch
        local matches, n = {}, 0
        for _, p in ipairs(grid.cache.screens) do
            for _, c in ipairs(p.cells) do
                if c.label:sub(1, #nextTyped) == nextTyped then
                    matches[c.label] = true; n = n + 1
                end
            end
        end

        -- With a full grid every prefix has candidates, so this is a
        -- can't-happen — which is exactly why it is handled rather than
        -- assumed away. A dead end rejects the keystroke and leaves you
        -- where you were, instead of stranding you in a grid with nothing
        -- selectable and no idea why.
        if n == 0 then
            hs.alert.show("🎯 no cell '" .. nextTyped .. "'")
            warn("dead-end prefix '" .. nextTyped .. "' rejected")
            return
        end

        s.typed, s.matches = nextTyped, matches
        armWatchdog(grid.timeoutSecs, "grid left open mid-type")

        if #s.typed >= grid.labelLength then
            local cell = cellFor(s.typed)
            if not cell then
                grid.hide("lost cell")
                warn("matched '" .. s.typed .. "' but no cell carried it")
                return
            end
            local point = { x = cell.ax, y = cell.ay }
            movePointer(point)
            if s.clickOnArrival then
                grid.hide("jumped + clicked")
                clickAt(point, "left")
            elseif grid.landedMode then
                enterLanded(point)
            else
                grid.hide("jumped")
            end
            return
        end
        redraw()
    end

    function grid.backspace()
        local s = grid.state
        if not (s and s.phase == "pick") then return end
        if #s.typed == 0 then grid.hide("backspaced out") return end
        s.typed = s.typed:sub(1, #s.typed - 1)
        local matches = {}
        if #s.typed > 0 then
            for _, p in ipairs(grid.cache.screens) do
                for _, c in ipairs(p.cells) do
                    if c.label:sub(1, #s.typed) == s.typed then matches[c.label] = true end
                end
            end
        end
        s.matches = matches
        armWatchdog(grid.timeoutSecs, "grid left open mid-type")
        redraw()
    end

    -- =====================================================================
    -- SHOW
    -- =====================================================================
    function grid.show(clickOnArrival)
        if not grid.enabled then return false end
        -- Pressing the trigger while it is already up means "put it away".
        if grid.state then grid.hide("toggled off") return false end

        local t0 = hs.timer.secondsSinceEpoch()
        local cache, err = ensureCache()
        if not cache then
            hs.alert.show("🎯 Mouse Grid could not draw — see the Console")
            warn("show failed: " .. tostring(err))
            return false
        end

        -- 🚨 STATE FIRST, THEN THE SCREEN, THEN THE KEYBOARD — and if
        -- either of the last two fails, hide() undoes all three. Setting
        -- state last would mean a throw halfway through left canvases up
        -- that grid.hide() did not yet believe existed.
        grid.state = { phase = "pick", typed = "", matches = nil,
                       clickOnArrival = clickOnArrival == true }

        local okDraw, drawErr = pcall(function()
            for _, p in ipairs(cache.screens) do
                -- 🚨 6.65.0 — THE LATTICE IS RESTORED HERE, NOT ASSUMED.
                -- The canvases are CACHED across hide/show, and redraw()
                -- strips the grid lines the moment you type (dropLattice).
                -- Without this line the next ⇪X would open a grid that
                -- still had no lines in it — a stale canvas that looks
                -- like a rendering bug and is really just last session's
                -- final frame.
                setElements(p.gridCanvas, gridElements(p))
                setElements(p.labelCanvas, p.fullLabels)
                showCanvas(p.gridCanvas)
                showCanvas(p.labelCanvas)
            end
        end)
        if not okDraw then
            grid.hide("draw failed")
            hs.alert.show("🎯 Mouse Grid could not draw — see the Console")
            warn("draw failed: " .. tostring(drawErr))
            return false
        end

        -- Taking the keyboard is the step that can strand you, so its
        -- failure is handled rather than assumed away: no modal means the
        -- overlay comes straight back down instead of sitting there
        -- swallowing nothing and answering nothing.
        if not pcall(function() grid.pickModal:enter() end) then
            grid.hide("could not take the keyboard")
            hs.alert.show("🎯 Mouse Grid could not capture the keyboard")
            warn("pickModal:enter() failed")
            return false
        end
        armWatchdog(grid.timeoutSecs, "grid left open with nothing typed")

        say(string.format("shown: %d cells across %d screens in %.1fms%s",
            cache.used, #cache.screens,
            (hs.timer.secondsSinceEpoch() - t0) * 1000,
            clickOnArrival and " (clicks on arrival)" or ""))
        return true
    end

    -- =====================================================================
    -- REPORT — run this once per Mac
    -- =====================================================================
    -- Answers the only question that decides whether this tool is usable
    -- on a given machine: how big is a cell here, really.
    function _G.mouseGridReport()
        local cache, err = ensureCache()
        if not cache then
            print("🎯 Mouse Grid: " .. tostring(err))
            return
        end
        local out = {
            "🎯 MOUSE GRID on " .. tostring(core.hostTag),
            string.format("   alphabet %q ^ %d = %d labels; %d cells in use",
                grid.alphabet, grid.labelLength, cache.capacity, cache.used),
        }
        for i, p in ipairs(cache.screens) do
            out[#out + 1] = string.format(
                "   screen %d  %.0fx%.0f px   %d x %d cells   cell = %.0f x %.0f pt",
                i, p.frame.w, p.frame.h, p.cols, p.rows, p.cellW, p.cellH)
            -- 44pt is Apple's own minimum control size. Below it, most
            -- targets are a straight hit; above it, expect to nudge.
            if p.cellW > 60 or p.cellH > 60 then
                out[#out + 1] = "              ⚠️  coarser than most buttons — "
                    .. "arrow-nudge after landing, or widen grid.alphabet"
            end
            -- The opposite failure, and easier to cause than the first: a
            -- big alphabet makes cells too small for their own label, and
            -- overlapping text is a grid you cannot read at all.
            if p.cellW < grid.labelSize * grid.labelLength * 0.62 then
                out[#out + 1] = "              ⚠️  cells are narrower than "
                    .. "their labels — text will overlap. Lower "
                    .. "grid.labelSize or shorten grid.alphabet"
            end
        end
        if cache.truncated > 0 then
            out[#out + 1] = string.format(
                "   ❌ %d cells have NO label and are unreachable — widen "
                .. "grid.alphabet or raise grid.labelLength", cache.truncated)
        end
        out[#out + 1] = "   clicking: " .. (axAvailable()
            and "✅ Accessibility granted"
            or  "⚪️ Accessibility OFF — the jump works, space-to-click does not")
        print(table.concat(out, "\n"))
        return table.concat(out, "\n")
    end

    -- =====================================================================
    -- KEYS
    -- =====================================================================
    -- 🚨 TWO MODALS, NOT ONE, and this is not tidiness. hs.hotkey.modal has
    -- no unbind: once "a" is bound to typeChar it is bound forever. A
    -- single modal would therefore keep eating the alphabet in landed mode,
    -- where those keys must reach the app underneath. Two modals, and never
    -- both entered — grid.hide() exits both regardless of which was live.
    grid.pickModal = hs.hotkey.modal.new()
    grid.landModal = hs.hotkey.modal.new()

    for _, ch in ipairs(alphabetChars()) do
        grid.pickModal:bind({}, ch, function()
            -- Wrapped: a throw inside a modal binding would otherwise leave
            -- the overlay up with its state half-changed. Any error tears
            -- the whole thing down rather than leaving it on your screen.
            local ok, err = pcall(grid.typeChar, ch)
            if not ok then grid.hide("error"); warn("typeChar: " .. tostring(err)) end
        end)
    end
    -- ⎋ 6.78.0 — CLAIMED at the top of the order: the grid is drawn at
    -- screenSaver level, above literally everything, so Esc belongs to it
    -- while it is up. See core/coexist.lua.
    if _G.claimEscape then
        _G.claimEscape("mousegrid", nil,
            function() return grid.state ~= nil end,
            function() grid.hide("escape") end)
    end

    grid.pickModal:bind({}, "escape", function() grid.hide("escape") end)
    grid.pickModal:bind({}, "delete", function()
        local ok, err = pcall(grid.backspace)
        if not ok then grid.hide("error"); warn("backspace: " .. tostring(err)) end
    end)

    grid.landModal:bind({}, "escape", function() grid.hide("escape") end)
    grid.landModal:bind({}, "space",  function() landedClick("left")   end)
    grid.landModal:bind({}, "return", function() landedClick("left")   end)
    grid.landModal:bind({ "shift" }, "space", function() landedClick("right") end)
    -- ⚠️ NOT a letter, on purpose. Landed mode must capture NO alphabet key,
    -- so everything you type still reaches the app you just landed on. "d
    -- for double" would have cost that rule for one mnemonic; "2" for two
    -- clicks is as memorable and keeps the rule absolute and testable.
    grid.landModal:bind({}, "2",      function() landedClick("double") end)
    local dirs = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
    for key, d in pairs(dirs) do
        grid.landModal:bind({}, key, function()
            nudge(d[1] * grid.nudgeStep, d[2] * grid.nudgeStep)
        end)
        grid.landModal:bind({ "shift" }, key, function()
            nudge(d[1] * grid.nudgeFine, d[2] * grid.nudgeFine)
        end)
    end

    if grid.enabled then
        core.hyperAddShortcut({}, grid.key, function() grid.show(false) end, "mouse grid")
        core.hyperAddShortcut({ "shift" }, grid.locateKey,
                              function() grid.locate() end, "find the pointer")
        core.hyperAddShortcut({ "shift" }, grid.key, function() grid.show(true) end,
                              "mouse grid (click on arrival)")
    end

    -- 🚨 THE PANIC KEY IS A PLAIN CHORD, NOT A ⇪ SHORTCUT. If ⇪ itself is
    -- what failed — the remap refused, the hyper modal stuck — then a ⇪
    -- panic key cannot be pressed. Bound directly, same as Screen Veil's.
    hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "X", function()
        grid.hide("panic key")
        hs.alert.show("🎯 Mouse Grid: overlay cleared")
    end)

    -- A display change invalidates every cached frame. HELD, or it is
    -- collected and the grid quietly keeps drawing yesterday's layout.
    grid.screenWatch = hs.screen.watcher.new(function()
        grid.hide("displays changed")
        if grid.cache then
            for _, p in ipairs(grid.cache.screens or {}) do
                pcall(function() p.gridCanvas:delete() end)
                pcall(function() p.labelCanvas:delete() end)
            end
        end
        grid.cache = nil
        say("display layout changed — geometry cache dropped")
    end)
    pcall(function() grid.screenWatch:start() end)

    -- Said once, at boot, rather than discovered the first time SPACE does
    -- nothing. The jump works either way; only the click is gated.
    if not axAvailable() then
        print("🎯 Mouse Grid: Accessibility is OFF — ⇪X still moves the pointer, "
              .. "but space-to-click cannot work until it is granted.")
    end

    -- =====================================================================
    -- WHERE IS THE POINTER? — the MouseCircle Spoon, done natively
    -- =====================================================================
    -- Flashes a ring at the pointer so you can find it on a wide or
    -- multi-monitor desktop. This is what the MouseCircle Spoon does; it
    -- is ~20 lines, so it lives here rather than pulling in SpoonInstall
    -- and a second loading system alongside the module loader.
    --
    -- 🅿️ DELIBERATELY BOUND TO NO KEY. macOS's own shake-to-grow already
    -- does this, and doubling it up is clutter. It is published as a
    -- service so you can put it on a free pad key the day you want it —
    -- ⇪pad+ and friends are unclaimed for exactly this.
    --       numpad.actions["pad+"] = "mouseGrid.locate"
    grid.locateColor  = { red = 0.4, green = 0.2, blue = 0.6 }  -- rebeccapurple
    grid.locateRadius = 60
    grid.locateSecs   = 0.6
    grid.locateCanvas = nil   -- HELD: an unreferenced canvas is collected
    grid.locateTimer  = nil   -- HELD: so is an unreferenced timer

    function grid.locate()
        -- Idempotent: a second press replaces the first ring rather than
        -- stacking canvases that each delete themselves on their own
        -- schedule, which is how this kind of thing leaks.
        if grid.locateTimer  then pcall(function() grid.locateTimer:stop() end) end
        if grid.locateCanvas then pcall(function() grid.locateCanvas:delete() end) end
        grid.locateCanvas, grid.locateTimer = nil, nil

        local okPos, pos = pcall(hs.mouse.absolutePosition)
        if not (okPos and pos) then return false end
        local r = grid.locateRadius
        local okNew, c = pcall(hs.canvas.new,
                               { x = pos.x - r, y = pos.y - r, w = r * 2, h = r * 2 })
        if not (okNew and c) then return false end
        pcall(function()
            c:replaceElements({ {
                type = "circle", action = "stroke",
                strokeColor = { red = grid.locateColor.red,
                                green = grid.locateColor.green,
                                blue = grid.locateColor.blue, alpha = 0.9 },
                strokeWidth = 5,
                center = { x = r, y = r }, radius = r - 4,
            } })
            -- 🚨 6.66.0 — MATCH THE GRID'S OWN LEVEL AND BEHAVIOUR.
            -- This ring was the odd one out: "overlay" level and
            -- "stationary" behaviour, while the grid itself uses
            -- screenSaver + fullScreenAuxiliary. The consequences were both
            -- real and both invisible until you hit them:
            --   · at "overlay" the ring hides behind the menu bar, so a
            --     pointer parked near the top of the screen was not found
            --     by the tool whose entire job is finding it;
            --   · WITHOUT fullScreenAuxiliary a canvas cannot draw over a
            --     FULL-SCREEN app at all — which is exactly when a pointer
            --     goes missing, because there is no window furniture left
            --     to locate it against.
            -- "stationary" only means "do not move me when Spaces change";
            -- it says nothing about full-screen, and it is not what was
            -- wanted here.
            c:level((hs.canvas.windowLevels or {}).screenSaver)
            c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
            -- 🚨 CLICK-THROUGH. Without this the ring is a disc of glass
            -- over whatever you were about to click, for half a second —
            -- which is precisely when you are reaching for something.
            c:canvasMouseEvents(false, false, false, false)
        end)
        -- Same protection as every other canvas here — see showCanvas above.
        if _G.showCanvasSafely then _G.showCanvasSafely(c, "pointer ring")
        else pcall(function() c:show() end) end
        grid.locateCanvas = c
        grid.locateTimer = hs.timer.doAfter(grid.locateSecs, function()
            pcall(function() c:delete() end)
            if grid.locateCanvas == c then grid.locateCanvas = nil end
        end)
        return true
    end

    core.provide("mouseGrid.show",   function() return grid.show(false) end)
    core.provide("mouseGrid.hide",   function() return grid.hide("service") end)
    core.provide("mouseGrid.locate", function() return grid.locate()      end)
    core.provide("mouseGrid.report", function() return _G.mouseGridReport() end)

    _G.mouseGrid = grid
    M.grid   = grid
    M.config = grid   -- so a machine profile can retune it per Mac
end

return M
