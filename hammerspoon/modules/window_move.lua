-- =====================================================================
-- MODULE: WINDOW MOVE (6.89.0) — hold ⌘ and drag ANY panel this config
-- draws; the pickers included
-- =====================================================================
-- LL: "I need every window movable, I should be able to click and hold
-- then move the mouse cursor to move the window."
--
-- WHAT "EVERY WINDOW" ACTUALLY IS HERE, because they are three different
-- kinds of thing with three different amounts of cooperation available:
--
--   1. WEBVIEWS AND CANVASES — the Capture Pad, the screenshot editor,
--      Unified Search, the mini calendar, the pomodoro card, the key
--      caster. These are OURS: we can read their frame and set it. Any
--      module lists its panel in _G.movablePanels and this module makes
--      ⌘-click-hold-drag move it. Panels that are pure DISPLAY (no
--      clicks mean anything on them) also set plain = true and then a
--      BARE click-hold drags them, exactly as asked. Panels you click
--      IN — the calendar's buttons, the editor's canvas, the pad's text
--      box — keep the bare click for themselves; ⌘ is what says "the
--      window, not the thing in it". (The pad header and the editor /
--      search toolbars still drag with a bare click-hold — a header is
--      safe by construction.)
--
--   2. THE PICKERS (hs.chooser) — clipboard history, ⇪⇧4, ⇪H, every
--      Asana list. macOS builds these and exposes NO window handle: no
--      frame getter, no setter. What DOES exist is chooser:show(point),
--      which re-anchors the visible panel — so while one is open, a
--      ⌘-drag STARTING ON the panel moves it live, and where you drop it
--      is committed to §1.5's popupOffset. That is deliberate: it is the
--      same offset the ⇪⇧-arrow nudge writes, so a dragged picker STAYS
--      where you put it for the next one, and ⌃⌥⌘R still means "back to
--      automatic". Since there is no frame getter either, the grab area
--      is COMPUTED (top-left is recorded by every showPopup; width and
--      row count come from the chooser itself) with a small margin — a
--      ⌘-click clearly outside a picker still belongs to your app.
--      6.102.0: the SEARCH BAND across the top drags with a BARE
--      click-hold as well — it is the picker's header, and the header
--      rule ("safe by construction") already shipped for the pad and
--      the editor. The band is the one strip of a picker where a bare
--      click did nothing you will miss; the rows below still need ⌘,
--      because a bare click on a row means "pick this one".
--
--   3. FULL-SCREEN OVERLAYS — the cheat sheet, the mouse grid, the
--      screen veil. Moving a window that covers the screen means
--      nothing; they are left alone on purpose.
--
-- 🚨 6.127.0 — THE PICKERS IN GROUP 2 WERE NOT ALL REACHABLE, and the
-- reason is worth keeping because it is a shape that will come back.
-- _G.lastPopupPlacement is ONE global record, and it said only "a picker
-- opened here" — not WHICH. Fourteen modules opened their picker with a
-- bare chooser:show(), which records nothing at all, so the record still
-- described whichever picker had last gone through core.showPopup. The
-- box below was computed at those departed coordinates, the ⌘-click on
-- the picker actually in front of you fell outside it, and the drag was
-- DECLINED — for ⇪; ⇪, ⇪. ⇪D ⇪Y ⇪⇧; ⇪⇧' ⇪⇧. and more.
--
-- Two things changed. Every picker now goes through core.showPopup (a
-- sentry in test_integration fails if a new one does not), and the record
-- names its chooser, so a record for somebody else reads as NO record —
-- which drops through to the jump-to-hand grab that always worked.
--
-- ⚠️ AND THE DECLINE IS SILENT BY DESIGN, which is why this went unseen.
-- A mouse tap cannot announce that it refused a click; the click belongs
-- to whatever app is underneath, and a tap that talks about other
-- people's clicks is a tap you turn off. _G.windowMoveReport() is the
-- answer instead: it prints the box, the record, who it belongs to, and
-- the last click it judged, with its coordinates.
--
-- 🚨 6.128.0 — AND IT STILL DID NOT MOVE. LL: "I clicked and dragged and
-- nothing happened." 6.127.0 was a real bug really fixed, but it was not
-- the only way to get nothing, because TWO separate computations had to
-- be right before a ⌘-drag was allowed to start:
--
--   1. IS A PICKER OPEN — answered only by hs.chooser.globalCallback. If
--      that willOpen never arrived, the entire picker branch was skipped
--      and ⌘ did nothing at all. Now the callback is a HINT and
--      chooser:isVisible() is the ground truth, with the placement
--      record as a second source. See wm.currentChooser().
--
--   2. IS THE CLICK INSIDE THE BOX — and the box is a GUESS: a recorded
--      top-left, a width the picker may decline to give, an assumed
--      44 px row. Every error in it presented as "this one cannot be
--      moved". ⌘-drag no longer asks. A visible picker plus ⌘ moves it.
--      The box now decides ONE thing only: where the bare-click search
--      band is, where being wrong costs a click nobody wanted anyway.
--
-- The lesson worth keeping: a feature gated on a computed value fails
-- exactly like a feature that is missing. Gate on something the OS will
-- state, or do not gate.
--
-- 🚨 THE DRAG IS DRIVEN FROM LUA, NOT FROM EVENTS, copied deliberately
-- from the Capture Pad's 6.44.2 drag: a drag tracked by mouse-move
-- events dies the moment events stop arriving (and for a WKWebView they
-- stop at the window edge). A 60 Hz timer polling the REAL mouse
-- position and the REAL button state survives any speed of hand, and a
-- release outside the window still ends the drag.
--
-- ⚠️ THE TAP CONSUMES A CLICK ONLY WHEN IT TAKES THE DRAG. Consuming is
-- load-bearing for the pickers: an unconsumed click outside a chooser's
-- text field makes macOS close the chooser — the panel would vanish in
-- your hand. And NOT consuming everything else is load-bearing for the
-- rest of the Mac: a mouse tap that eats clicks when it errors has
-- taken your mouse away. Same stand-down contract as the hyper tap:
-- five consecutive callback errors and this module retires itself,
-- loudly, leaving the mouse untouched.

local M = {
    name  = "Window Move",
    order = 6.5,
    family = "windows",
    cheatsheet = {
        title = "🪟 WINDOW MOVE (⌘-drag — every panel, pickers included)",
        entries = {
            { "⌘ drag", "Hold ⌘, click and hold ON any panel or picker, move the mouse" },
            { "always", "⌘-drag moves an OPEN PICKER from anywhere — even off it" },
            { "band",   "A PICKER drags by its search band — bare click-hold, no ⌘" },
            { "drag",   "Display-only panels (pomodoro, key caster) need no ⌘ — just grab" },
            { "sticks", "A dragged PICKER position is kept for the next picker you open" },
            { "⌃⌥⌘R",   "Back to automatic placement (same reset as the ⇪⇧-arrow nudge)" },
            { "headers","The pad / editor / search bars drag with a bare click-hold too" },
            { "check",  "_G.windowMoveReport() — why a panel refused to be grabbed" },
        },
    },
}

function M.setup(core)
    local wm = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    wm.enabled     = true
    wm.tickSecs    = 0.016   -- drag follow rate; 0.016 ≈ 60 Hz, like the pad
    wm.chooserPad  = 24      -- grab margin (px) around a picker's computed box
    wm.chooserRowH = 44      -- a chooser row is ~44 px; used only to SIZE the
                             -- grab area, never to draw anything
    wm.chooserHeadH = 56     -- the search band across a picker's top; a BARE
                             -- click-hold there drags (6.102.0) — same rule
                             -- as the pad header, so keep it TIGHT: too tall
                             -- and bare clicks on the first row start drags
    -- ----------------------------------------------------------------------

    local function warn(m) if _G.diag then _G.diag.warn("windowMove", m) end end
    local function say(m)  if _G.diag then _G.diag.say("windowMove", m)  end end

    -- The shared registry. Created with `or` ON PURPOSE: modules register
    -- by inserting into this table directly, so nobody depends on load
    -- order — whoever gets here first creates it.
    --   { name  = "capture pad",
    --     frame = function() return rect-or-nil end,   -- nil = not visible
    --     move  = function(x, y) ... end,
    --     plain = false }                               -- true = no ⌘ needed
    _G.movablePanels = _G.movablePanels or {}

    -- ---- mouse truth, verbatim from the Capture Pad ----------------------
    local function mousePosition()
        local fns = {}
        if type(hs.mouse.absolutePosition) == "function" then
            table.insert(fns, hs.mouse.absolutePosition)
        end
        if type(hs.mouse.getAbsolutePosition) == "function" then
            table.insert(fns, hs.mouse.getAbsolutePosition)
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

    -- ---- the one drag engine ---------------------------------------------
    -- moveFn(x, y) is called with the panel's new TOP-LEFT on every tick;
    -- endFn (optional) runs once when the button is released. One drag at
    -- a time — starting a new one tears the old one down first.
    function wm.endDrag()
        if wm.dragTimer then
            pcall(function() wm.dragTimer:stop() end)
            wm.dragTimer = nil
        end
        local fin = wm.dragEnd
        wm.dragEnd = nil
        if fin then pcall(fin) end
    end

    function wm.beginDrag(startTopLeft, moveFn, endFn)
        local m = mousePosition()
        if not m then
            print("🪟 Window Move: cannot read the mouse position — drag unavailable")
            return false
        end
        wm.endDrag()
        -- Grab offset held constant for the whole drag, so the panel moves
        -- WITH the pointer instead of jumping its corner to it.
        local off = { x = m.x - startTopLeft.x, y = m.y - startTopLeft.y }
        wm.dragEnd = endFn
        -- HELD in wm.dragTimer — an unreferenced hs.timer is collected, and
        -- a collected timer never fires. Same rule as every timer here.
        wm.dragTimer = hs.timer.doEvery(wm.tickSecs, function()
            if not leftButtonDown() then wm.endDrag() return end
            local p = mousePosition()
            if not p then wm.endDrag() return end
            pcall(moveFn, p.x - off.x, p.y - off.y)
        end)
        return true
    end

    -- Public hook for the webview HEADERS (pad-style "drag here" bars):
    -- the page's JS reports mousedown-on-header, Lua drives the drag.
    --   _G.beginPanelDrag("unified search")
    function _G.beginPanelDrag(name)
        for _, e in ipairs(_G.movablePanels) do
            if e.name == name then
                local okF, f = pcall(e.frame)
                if okF and type(f) == "table" and f.x then
                    return wm.beginDrag(f, e.move)
                end
                return false
            end
        end
        return false
    end

    -- ---- which picker is open right now -----------------------------------
    -- hs.chooser.globalCallback fires for EVERY chooser in the config —
    -- module ones included — so nothing has to register. Chained, not
    -- replaced: if anything else ever claims it, both still run.
    wm.openChooser = nil
    local prevGlobal = hs.chooser and hs.chooser.globalCallback
    pcall(function()
        hs.chooser.globalCallback = function(ch, state)
            if state == "willOpen" then wm.openChooser = ch
            elseif state == "didClose" and wm.openChooser == ch then
                wm.openChooser = nil
            end
            if type(prevGlobal) == "function" then pcall(prevGlobal, ch, state) end
        end
    end)

    -- ---- which picker is on screen, asked properly ------------------------
    -- 🚨 6.128.0 — THE CALLBACK ABOVE WAS THE ONLY ANSWER WE HAD, and
    -- everything below it — the box, the band, the ⌘-drag — is skipped
    -- entirely when it says "none". One missed willOpen therefore reads
    -- exactly like a picker that cannot be moved, and leaves no trace of
    -- why. macOS will answer hs.chooser:isVisible() directly (§1.5's
    -- nudge has asked it since 6.30), so the callback is now a HINT that
    -- gets CHECKED, and the placement record — which names its chooser
    -- since 6.127.0 — is the fallback when the hint is missing.
    --
    -- The two directions are deliberately NOT symmetrical. The callback
    -- already told us this picker opened, so it is trusted unless
    -- isVisible() explicitly says otherwise (a build without the getter
    -- must not lose the drag). A chooser reached from the RECORD has no
    -- such statement behind it — a record outlives its picker by design —
    -- so it is promoted only on an explicit yes.
    local function saysVisible(ch)
        if ch == nil then return nil end
        local ok, v = pcall(function() return ch:isVisible() end)
        if not ok or type(v) ~= "boolean" then return nil end
        return v
    end

    -- Why currentChooser() answered as it did, in words, for the report.
    wm.chooserWhy = "nothing asked yet"

    function wm.currentChooser()
        if wm.openChooser ~= nil and saysVisible(wm.openChooser) ~= false then
            wm.chooserWhy = "the willOpen callback" ..
                (saysVisible(wm.openChooser) == true and ", confirmed visible"
                 or " (isVisible unavailable — trusted)")
            return wm.openChooser
        end
        local placed = _G.lastPopupPlacement
        if placed and saysVisible(placed.chooser) == true then
            wm.chooserWhy = "the placement record's picker, confirmed visible"
                            .. " — the willOpen callback never fired"
            return placed.chooser
        end
        for _, c in pairs(_G.choosers or {}) do
            if saysVisible(c) == true then
                wm.chooserWhy = "found visible in _G.choosers — neither the "
                                .. "callback nor the record knew about it"
                return c
            end
        end
        wm.chooserWhy = "no picker is visible"
        return nil
    end

    -- The picker's box, COMPUTED: top-left from §1.5's record, width and
    -- visible rows asked of the chooser itself, both pcall'd because both
    -- getters vary across Hammerspoon builds. Deliberately generous — the
    -- cost of a margin too wide is a ⌘-click near a picker starting a
    -- drag; the cost of one too narrow is "movable" feeling broken.
    -- Why the box came out nil or wrong, in words — read by the report so
    -- "I cannot move this one" is answerable without guessing.
    wm.boxWhy = "nothing open"
    -- true only when the picker itself gave its width. A box built from
    -- the 40% default is a GUESS, and the report must not print a guess
    -- as though it were measured — that is how 6.127.0's report sent us
    -- looking at numbers no click was ever judged against.
    wm.boxMeasured = false

    function wm.chooserBox(ch)
        ch = ch or wm.currentChooser()
        wm.boxMeasured = false
        local placed = _G.lastPopupPlacement
        if not (placed and placed.point) then
            wm.boxWhy = "no placement on record — the picker was shown "
                        .. "without core.showPopup"
            return nil
        end
        -- 🚨 A RECORD FOR A DIFFERENT PICKER IS WORSE THAN NO RECORD, and
        -- this is the bug that made whole modules undraggable (6.127.0).
        -- The record is global and the box is computed from it, so a picker
        -- that opened without showPopup left the LAST picker's coordinates
        -- standing. The ⌘-click on the picker actually on screen then fell
        -- outside that box and was DECLINED — while the code below is
        -- written to fall back to a jump-to-hand grab whenever there is no
        -- box at all. Refusing to trust a mismatched record puts those
        -- pickers back on the working path.
        if placed.chooser ~= nil and ch ~= nil and placed.chooser ~= ch then
            wm.boxWhy = "the placement on record belongs to a different "
                        .. "picker — ⌘-drag grabs by hand instead"
            return nil
        end
        wm.boxWhy = "computed from the placement on record"
        local w, rows = nil, 10
        pcall(function()
            local pct = ch:width()
            local sf  = placed.screen and placed.screen:frame()
            if type(pct) == "number" and pct > 0 and pct <= 100 and sf then
                w = sf.w * (pct / 100)
                wm.boxMeasured = true
            end
        end)
        if not w then
            local sf
            pcall(function() sf = placed.screen and placed.screen:frame() end)
            w = (sf and sf.w or 1440) * 0.4
            wm.boxWhy = wm.boxWhy .. ", width ASSUMED at 40% (the picker "
                        .. "did not answer)"
        end
        pcall(function()
            local r = ch:rows()
            if type(r) == "number" and r > 0 then rows = r end
        end)
        local pad = wm.chooserPad
        return { x = placed.point.x - pad,
                 y = placed.point.y - pad,
                 w = w + pad * 2,
                 h = rows * wm.chooserRowH + wm.chooserHeadH + pad * 2 }
    end

    function wm.dragChooser(ch)
        -- Only THIS picker's record may seed the grab (6.128.0). ⌘-drag
        -- now starts without consulting the box, so a record belonging to
        -- a picker that closed hours ago would otherwise teleport this one
        -- to those coordinates the instant you grabbed it. Mismatched or
        -- missing, the answer is the same and it is a good one: grab it by
        -- where the hand already is.
        local placed = _G.lastPopupPlacement
        local base = placed and placed.point
                     and (placed.chooser == nil or placed.chooser == ch)
                     and placed.point or nil
        local m = mousePosition()
        if not m then return false end
        -- No record (a chooser shown without showPopup): grab it by where
        -- the hand is — the panel's title area jumps to the pointer.
        base = base and { x = base.x, y = base.y }
                or  { x = m.x - 160, y = m.y - 16 }
        local land = { x = base.x, y = base.y }
        local started = wm.beginDrag(base, function(x, y)
            land.x, land.y = x, y
            -- show(point) re-anchors a VISIBLE chooser; hide+show (what the
            -- ⇪⇧-arrow nudge does) would flicker at 60 Hz.
            pcall(function() ch:show({ x = x, y = y }) end)
        end, function()
            -- Where it was dropped becomes the standing offset, so the NEXT
            -- picker opens there too — one position system, shared with the
            -- nudge keys, reset by the same ⌃⌥⌘R.
            _G.popupOffset.x = _G.popupOffset.x + (land.x - base.x)
            _G.popupOffset.y = _G.popupOffset.y + (land.y - base.y)
            local rec = _G.lastPopupPlacement
            if rec and rec.point
               and (rec.chooser == nil or rec.chooser == ch) then
                rec.point = { x = land.x, y = land.y }
            end
            -- The Task Creator's mirror and the dashboard legend ride their
            -- picker — same calls the nudge path makes.
            if _G.taskMirrorSync  then pcall(_G.taskMirrorSync)  end
            if _G.asanaLegendSync then pcall(_G.asanaLegendSync) end
        end)
        return started
    end

    -- ---- the tap -----------------------------------------------------------
    local function contains(f, p)
        return p.x >= f.x and p.x <= f.x + f.w
           and p.y >= f.y and p.y <= f.y + f.h
    end

    function wm.onMouseDown(ev)
        local p
        pcall(function() p = ev:location() end)
        if not (p and p.x) then return false end
        local f = {}
        pcall(function() f = ev:getFlags() or {} end)
        -- ⌥⌃⇧ variants stay with the apps; only bare-⌘ (or bare-nothing on
        -- a plain panel) reads as "move the window".
        if f.alt or f.ctrl or f.shift then return false end

        for _, e in ipairs(_G.movablePanels) do
            local okF, fr = pcall(e.frame)
            if okF and type(fr) == "table" and fr.x and contains(fr, p)
               and (f.cmd or e.plain) then
                return wm.beginDrag(fr, e.move)
            end
        end

        local ch = wm.currentChooser()
        -- EVERY click that could plausibly have meant "move this picker"
        -- is written down (6.128.0) — one slot, overwritten, read by the
        -- report. "I clicked and dragged and nothing happened" had no
        -- answer at all before this: 6.127.0 recorded only DECLINED
        -- ⌘-clicks, so the two commonest ways to get nothing — a bare
        -- click below the search band, and a picker the module never saw
        -- — both left the record empty and the report showing "none".
        -- Skipped for a plain click with no picker up, because that is
        -- just somebody using their Mac.
        local function note(cmd, box, strip, outcome)
            if not (ch or cmd) then return end
            wm.lastPickerClick = { x = p.x, y = p.y, cmd = cmd == true,
                                   picker = ch ~= nil, why = wm.chooserWhy,
                                   box = box, strip = strip,
                                   outcome = outcome, when = os.date("%H:%M:%S") }
        end

        if ch then
            local box = wm.chooserBox(ch)
            if f.cmd then
                -- 🚨 6.128.0 — ⌘-DRAG NO LONGER ASKS THE BOX AT ALL, and
                -- that is the whole point. The box is COMPUTED, from a
                -- recorded top-left plus an assumed row height — so every
                -- way it can be wrong (a width the picker would not give,
                -- a placement macOS did not honour, a row height off by a
                -- few pixels) came out as "this picker cannot be moved",
                -- silently. The module already held that a jump-to-hand
                -- grab beats an immovable picker when there is NO box;
                -- there is no honest reason to be stricter when the box
                -- is merely a guess. A visible picker plus ⌘ now means
                -- move it, full stop.
                --
                -- The cost, accepted knowingly: a ⌘-click that lands
                -- OUTSIDE an open picker starts a drag instead of going
                -- to the app underneath. It is a rare gesture while a
                -- picker holds the keyboard, Esc puts the picker away
                -- first, and dropping it where it started costs nothing.
                note(true, box, nil, "⌘-drag taken")
                return wm.dragChooser(ch)
            elseif box then
                -- 6.102.0 — LL's original spec, finally honoured for the
                -- pickers: "click and hold then move". The SEARCH BAND is
                -- the picker's header, and a header is safe by construction
                -- (the same rule the pad and the editor shipped with). Kept
                -- TIGHT — the box's pad margin is stripped — because a bare
                -- click consumed by mistake belongs to somebody's app. The
                -- known cost, accepted: the mouse no longer places the text
                -- caret in the query field. Type, ⌫, or ⌘A there instead —
                -- it is a filter box holding one or two words.
                local strip = { x = box.x + wm.chooserPad,
                                y = box.y + wm.chooserPad,
                                w = box.w - wm.chooserPad * 2,
                                h = wm.chooserHeadH }
                if contains(strip, p) then
                    note(false, box, strip, "search-band drag taken")
                    return wm.dragChooser(ch)
                end
                note(false, box, strip,
                     "bare click OUTSIDE the search band — nothing taken; "
                     .. "⌘-drag moves a picker from anywhere on it")
            else
                note(false, nil, nil,
                     "bare click, but there is no box to find the search "
                     .. "band with (" .. tostring(wm.boxWhy) .. ") — ⌘-drag "
                     .. "moves it from anywhere")
            end
        else
            note(f.cmd == true, nil, nil,
                 "no picker visible and no panel under the pointer")
        end
        return false
    end

    -- Same guard contract as the hyper tap: every left-click on this Mac
    -- passes through here, so an error must cost THIS feature, never the
    -- click — and five in a row cost the feature permanently.
    wm.tapFailures = 0
    local MAX_FAILURES = 5
    local function tapCallback(ev)
        local ok, took = pcall(wm.onMouseDown, ev)
        if ok then
            wm.tapFailures = 0
            return took == true
        end
        wm.tapFailures = wm.tapFailures + 1
        print("🪟 Window Move tap error (" .. wm.tapFailures .. "/"
              .. MAX_FAILURES .. "): " .. tostring(took))
        if wm.tapFailures >= MAX_FAILURES then
            pcall(function() wm.tap:stop() end)
            print("🪟 Window Move STOPPED after " .. MAX_FAILURES
                  .. " consecutive errors — panels are no longer draggable; "
                  .. "everything else about them still works")
            if _G.notices then
                pcall(_G.notices.record, "runtime", "window_move",
                      "tap stopped after " .. MAX_FAILURES .. " errors")
            end
        end
        return false   -- never consume a click on the failure path
    end

    if wm.enabled then
        local okTap, tapErr = pcall(function()
            wm.tap = hs.eventtap.new(
                { hs.eventtap.event.types.leftMouseDown }, tapCallback)
            wm.tap:start()
        end)
        if okTap and wm.tap then
            say("mouse tap up — panels are draggable")
        else
            wm.tap = nil
            print("🪟 Window Move: mouse tap unavailable ("
                  .. tostring(tapErr) .. ") — drag is off, nudge keys still work")
        end
    end

    -- ---- the report ------------------------------------------------------
    -- 🚨 THIS MODULE WAS THE ONLY ONE IN THE CONFIG WITHOUT ONE, and it is
    -- the one that fails SILENTLY BY DESIGN: a declined ⌘-click cannot make
    -- a noise, because the click belongs to whatever app is underneath. So
    -- "I can't move this one" had no answer anywhere — not in the Console,
    -- not on screen. Everything the decision is made from is printed here.
    function _G.windowMoveReport()
        local L = {}
        local function line(s) L[#L + 1] = s end
        line("")
        line("🪟 WINDOW MOVE")
        line("   enabled    : " .. tostring(wm.enabled))
        line("   tap        : " .. (wm.tap and "up" or "NOT RUNNING — nothing drags")
             .. "  (errors " .. tostring(wm.tapFailures) .. "/5)")
        line("   panels     : " .. tostring(#(_G.movablePanels or {}))
             .. " registered (webviews and canvases)")
        for _, e in ipairs(_G.movablePanels or {}) do
            local okF, f = pcall(e.frame)
            line(("      %-16s %s%s"):format(tostring(e.name),
                 (okF and type(f) == "table" and f.x)
                     and ("open at %d,%d %dx%d"):format(f.x, f.y, f.w, f.h)
                     or  "not open",
                 e.plain and "   (bare click drags)" or ""))
        end

        -- 🚨 THIS REPORT IS READ WITH NO PICKER OPEN — always. A chooser
        -- holds the keyboard, so reaching the Console means closing it
        -- first. 6.127.0's version printed the LIVE box and the LIVE
        -- picker anyway, which by then were a 40%-width guess and "no",
        -- and I read those numbers as though a click had been judged
        -- against them. Everything live is now labelled as live, and the
        -- click record below is what actually answers the question.
        local ch = wm.currentChooser()
        line("   picker open: " .. (ch and "yes" or "no")
             .. "   (" .. tostring(wm.chooserWhy) .. ")")
        local placed = _G.lastPopupPlacement
        if placed and placed.point then
            local whose = "   (its picker is not on screen — expected with "
                          .. "the Console in front)"
            if placed.chooser == nil then
                whose = "   ⚠️ no chooser named — pre-6.127.0 caller"
            elseif ch ~= nil then
                whose = (placed.chooser == ch) and "   (this picker)"
                        or "   ⚠️ ANOTHER picker's — this one was shown "
                           .. "without core.showPopup"
            end
            line(("   placement  : %d,%d%s"):format(placed.point.x,
                                                    placed.point.y, whose))
        else
            line("   placement  : none on record")
        end
        local box = wm.chooserBox(ch)
        line("   grab box   : " .. (box
             and (("%d,%d %dx%d"):format(box.x, box.y, box.w, box.h)
                  .. (ch and "" or "   — computed NOW, with nothing open")
                  .. (wm.boxMeasured and "" or "   ⚠️ width is a guess"))
             or  "none"))
        line("   why        : " .. tostring(wm.boxWhy))
        if box then
            line(("   band strip : %d,%d %dx%d  (bare click-hold drags here)")
                 :format(box.x + wm.chooserPad, box.y + wm.chooserPad,
                         box.w - wm.chooserPad * 2, wm.chooserHeadH))
        elseif ch then
            line("   band strip : none — with no box the SEARCH BAND cannot be")
            line("                found, so ⌘-drag is the only way to move this one")
        end
        if wm.lastPickerClick then
            local d = wm.lastPickerClick
            line(("   last click : %s at %d,%d at %s")
                 :format(d.cmd and "⌘-click" or "bare click", d.x, d.y, d.when))
            line("                picker seen: " .. (d.picker and "yes" or "NO")
                 .. "  (" .. tostring(d.why) .. ")")
            if d.box then
                line(("                box then  : %d,%d %dx%d"):format(
                     d.box.x, d.box.y, d.box.w, d.box.h))
            end
            if d.strip then
                line(("                band then : %d,%d %dx%d"):format(
                     d.strip.x, d.strip.y, d.strip.w, d.strip.h))
            end
            line("                outcome   : " .. tostring(d.outcome))
        else
            line("   last click : nothing yet — no ⌘-click, and no click at all")
            line("                while a picker was up")
        end
        line("   drag now   : " .. (wm.dragTimer and "IN PROGRESS" or "idle"))
        line("")
        line("   ⌘-drag anywhere on a panel or picker · a picker's SEARCH BAND")
        line("   drags with a bare click-hold · ⌃⌥⌘R resets picker placement")
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    core.provide("windowMove.report", function() return _G.windowMoveReport() end)
    core.provide("windowMove.drag", function(name) return _G.beginPanelDrag(name) end)

    _G.windowMove = wm
    M.wm     = wm
    M.config = wm
end

return M
