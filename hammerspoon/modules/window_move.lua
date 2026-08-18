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
--
--   3. FULL-SCREEN OVERLAYS — the cheat sheet, the mouse grid, the
--      screen veil. Moving a window that covers the screen means
--      nothing; they are left alone on purpose.
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
            { "drag",   "Display-only panels (pomodoro, key caster) need no ⌘ — just grab" },
            { "sticks", "A dragged PICKER position is kept for the next picker you open" },
            { "⌃⌥⌘R",   "Back to automatic placement (same reset as the ⇪⇧-arrow nudge)" },
            { "headers","The pad / editor / search bars drag with a bare click-hold too" },
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

    -- The picker's box, COMPUTED: top-left from §1.5's record, width and
    -- visible rows asked of the chooser itself, both pcall'd because both
    -- getters vary across Hammerspoon builds. Deliberately generous — the
    -- cost of a margin too wide is a ⌘-click near a picker starting a
    -- drag; the cost of one too narrow is "movable" feeling broken.
    function wm.chooserBox()
        local placed = _G.lastPopupPlacement
        if not (placed and placed.point) then return nil end
        local w, rows = nil, 10
        pcall(function()
            local pct = wm.openChooser:width()
            local sf  = placed.screen and placed.screen:frame()
            if type(pct) == "number" and pct > 0 and pct <= 100 and sf then
                w = sf.w * (pct / 100)
            end
        end)
        if not w then
            local sf
            pcall(function() sf = placed.screen and placed.screen:frame() end)
            w = (sf and sf.w or 1440) * 0.4
        end
        pcall(function()
            local r = wm.openChooser:rows()
            if type(r) == "number" and r > 0 then rows = r end
        end)
        local pad = wm.chooserPad
        return { x = placed.point.x - pad,
                 y = placed.point.y - pad,
                 w = w + pad * 2,
                 h = rows * wm.chooserRowH + 56 + pad * 2 }
    end

    function wm.dragChooser(ch)
        local base = (_G.lastPopupPlacement and _G.lastPopupPlacement.point)
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
            if _G.lastPopupPlacement and _G.lastPopupPlacement.point then
                _G.lastPopupPlacement.point = { x = land.x, y = land.y }
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

        if f.cmd and wm.openChooser then
            local box = wm.chooserBox()
            -- No box on record still grabs: better a jump-to-hand than a
            -- picker that cannot be moved at all.
            if (not box) or contains(box, p) then
                return wm.dragChooser(wm.openChooser)
            end
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

    core.provide("windowMove.drag", function(name) return _G.beginPanelDrag(name) end)

    _G.windowMove = wm
    M.wm     = wm
    M.config = wm
end

return M
