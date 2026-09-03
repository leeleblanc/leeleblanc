-- =====================================================================
-- MODULE: MOUSE FOLLOWS FOCUS (⇪⇧3 toggles) — the pointer goes where focus goes
-- =====================================================================
-- LL, 6.160.0: "Set the mouse pointer to the center of the focused window
-- whenever focus changes. Additionally, if focused window moves when no
-- mouse buttons are pressed, set the mouse pointer to the new center.
-- This is intended to work with other utilities which warp the focused
-- window."
--
-- That is MouseFollowsFocus.spoon's contract, and this is it rebuilt on
-- this config's own plumbing — because the Spoon does it with
-- hs.window.filter, which is BANNED here (the 44-second beachball; the
-- sentries in test_features enforce it). Two rules, nothing else:
--
--   1. FOCUS CHANGES  → pointer to the centre of the newly focused window.
--      An app switch (hs.application.watcher), and a window switch inside
--      the same app (the AXFocusedWindowChanged notification — ⌘` cycling,
--      a click on another window, a new window opening in front).
--   2. THE FOCUSED WINDOW MOVES with no mouse button held → pointer to
--      its new centre. That is the "other utilities which warp the
--      focused window" half: ⇪← ⇪→ ⇪↑ from the numpad layer, a window
--      thrown to the other monitor, Window Return putting things back.
--      A window YOU are dragging is skipped by that same rule — a button
--      is down — so the pointer never fights your hand.
--
--        ⇪⇧3        on / off (starts ON; a profile can start it off)
--
-- ---- HOW IT WATCHES ----------------------------------------------------
-- The same shape Dialog Home uses (6.143.0): an hs.application.watcher
-- for the app switch, and ONE hs.axuielement.observer on the frontmost
-- app for what happens inside it — AXFocusedWindowChanged and
-- AXWindowMoved. The previous app's observer is stopped when the next
-- attaches, so there is never more than one alive. Nothing polls.
--
-- AXWindowMoved arrives for ANY window of the front app, and for every
-- step of a drag, so the handler does two cheap things before anything
-- moves: it asks hs.eventtap.checkMouseButtons (a button down = your
-- drag = stand still), and it reads the FOCUSED window's frame — a
-- non-focused window moving does not change that frame, so nothing
-- happens. A warp to the same centre the pointer was last sent to is a
-- no-op too (mf.dedupePx): the AX notifications for one real move can
-- arrive twice, and the second must not read as a second jump.
--
-- ---- WHAT IT NEVER DOES -----------------------------------------------
--   · Never warps while a mouse button is down. Ever. Not on focus
--     change either — a click that focuses a window IS a button down at
--     the moment AX reports it, and yanking the pointer out from under a
--     mousedown is how a drag starts on the wrong thing.
--   · Never warps to its own windows (the pads, the pickers, the sheet):
--     they place themselves, and a pointer landing in a chooser would
--     hover-select a row (the preview pane follows the mouse, 6.154.0).
--   · Never warps while the config is paused (⇪⇧1, _G.hsPaused) — the
--     pause means "stop acting on my behalf", and this acts.
--   · Never uses hs.window.filter, hs.window.orderedWindows, or a timer
--     that polls. The pointer moves through hs.mouse.absolutePosition
--     only — no setAbsolutePosition fallback (see mouse_grid: it is a
--     deprecated shim around the same call).
--
-- No Accessibility, no feature: window frames cannot be read without it.
-- It stands down and says so, the way Dialog Home and Window Pin do.
-- =====================================================================

local M = {
    name  = "Mouse Follows Focus",
    order = 7.75,
    family = "windows",
    cheatsheet = {
        title = "🖱 MOUSE FOLLOWS FOCUS (⇪⇧3)",
        entries = {
            { "focus",  "Pointer jumps to the centre of the window that took focus" },
            { "moves",  "…and follows the focused window when something warps it" },
            { "not",    "While a mouse button is down — your drag is yours" },
            { "⇪⇧3",   "On / off for this session (starts on)" },
            { "check",  "_G.mouseFollowsReport() — last jump, why it stood still" },
        },
    },
}

function M.setup(core)
    local mf = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    mf.enabled      = true           -- the module loads at all
    mf.active       = true           -- following ON at boot; ⇪⇧3 flips it
    mf.key          = "3"            -- ⇪⇧3
    mf.keyMods      = { "shift" }
    mf.followMoves  = true           -- rule 2: follow a warped window
    -- A warp to within this many pixels of the last one is the same warp
    -- (AX can report one move twice). Also: the pointer already at the
    -- centre stays put — no visible twitch.
    mf.dedupePx     = 2
    -- Apps whose windows are never followed, by name. Empty on purpose:
    -- the two built-in exclusions (our own windows; a button held) cover
    -- what matters, and a name list is yours to grow if a specific app
    -- misbehaves — a screen-sharing viewer, say.
    mf.skipApps     = {}
    -- ----------------------------------------------------------------------

    mf.OWN_BUNDLE = "org.hammerspoon.Hammerspoon"
    mf.warps      = 0
    mf.skipped    = 0
    mf.last       = nil      -- { app, title, x, y, why, when }
    mf.lastSkip   = nil      -- why the last candidate stood still
    mf.lastCentre = nil      -- { x, y } of the last warp, for the dedupe
    mf.observer   = nil      -- the ONE live AX observer
    mf.appWatcher = nil      -- HELD
    mf.refused    = {}       -- apps that would not take an observer (said once)
    mf.currentApp = nil

    local function say(m)  if _G.diag then _G.diag.say("mousefollows", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("mousefollows", m) end end

    local function axOK()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    -- ---- the two guards ---------------------------------------------------
    function mf.buttonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        for _, v in pairs(btns) do
            if v == true then return true end
        end
        return false
    end

    function mf.isOwn(app)
        if not app then return false end
        local bundle
        pcall(function() bundle = app:bundleID() end)
        return bundle == mf.OWN_BUNDLE
    end

    local function appName(app)
        local n
        if app then pcall(function() n = app:name() end) end
        return n or "?"
    end

    -- ---- where to ---------------------------------------------------------
    -- The focused window of the FRONT app, its frame, and its centre.
    -- Read through hs.window (which is AX underneath) rather than the
    -- observer's element: the element that arrives with AXWindowMoved is
    -- whichever window moved, and the rule is about the focused one.
    function mf.target()
        local app
        pcall(function() app = hs.application.frontmostApplication() end)
        if not app then return nil, "no front app" end
        if mf.isOwn(app) then return nil, "own window" end
        local name = appName(app)
        if mf.skipApps[name] then return nil, "skipped app: " .. name end
        local win
        pcall(function() win = app:focusedWindow() end)
        if not win then return nil, "no focused window in " .. name end
        local f
        pcall(function() f = win:frame() end)
        if not (f and f.w and f.h and f.w > 0 and f.h > 0) then
            return nil, "no frame for the focused window"
        end
        local title
        pcall(function() title = win:title() end)
        return { x = f.x + f.w / 2, y = f.y + f.h / 2,
                 app = name, title = title or "" }
    end

    function mf.pointer()
        local ok, p = pcall(hs.mouse.absolutePosition)
        if ok and type(p) == "table" and p.x and p.y then return p end
        return nil
    end

    local function near(a, b)
        return a and b and math.abs(a.x - b.x) <= mf.dedupePx
                       and math.abs(a.y - b.y) <= mf.dedupePx
    end

    -- ---- the warp ---------------------------------------------------------
    -- why: "focus" | "moved" | "activated" — recorded, and only that.
    function mf.warp(why)
        if not (mf.enabled and mf.active) then
            mf.lastSkip = "off"; return false
        end
        if _G.hsPaused then
            mf.lastSkip = "paused (⇪⇧1)"; mf.skipped = mf.skipped + 1
            return false
        end
        if mf.buttonDown() then
            mf.lastSkip = "a mouse button is down"; mf.skipped = mf.skipped + 1
            return false
        end
        local t, reason = mf.target()
        if not t then
            mf.lastSkip = reason; mf.skipped = mf.skipped + 1
            return false
        end
        local here = mf.pointer()
        if near(t, here) or (why == "moved" and near(t, mf.lastCentre)) then
            mf.lastSkip = "already there"
            return false
        end
        local ok, err = pcall(function() hs.mouse.absolutePosition({ x = t.x, y = t.y }) end)
        if not ok then
            mf.lastSkip = "could not move the pointer"
            warn("could not move the pointer: " .. tostring(err))
            return false
        end
        mf.warps = mf.warps + 1
        mf.lastCentre = { x = t.x, y = t.y }
        mf.lastSkip = nil
        mf.last = { app = t.app, title = t.title, x = t.x, y = t.y, why = why,
                    when = os.date("%H:%M:%S") }
        say(string.format("%s → %s %q at %d,%d", why, t.app, t.title,
                          math.floor(t.x), math.floor(t.y)))
        return true
    end

    -- ---- watching the front app -------------------------------------------
    local function stopObserver()
        if mf.observer then
            pcall(function() mf.observer:stop() end)
            mf.observer = nil
        end
    end

    function mf.attach(app)
        stopObserver()
        mf.currentApp = nil
        if not (mf.enabled and app) then return false end
        local pid, name = nil, appName(app)
        pcall(function() pid = app:pid() end)
        if not pid or mf.isOwn(app) then return false end
        mf.currentApp = name

        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then return false end
        local okObs, obs = pcall(hs.axuielement.observer.new, pid)
        if not (okObs and obs) then return false end
        local okWatch = pcall(function()
            obs:callback(function(_, _, notif)
                local ok, err = pcall(function()
                    if notif == "AXFocusedWindowChanged" then
                        mf.warp("focus")
                    elseif notif == "AXWindowMoved" and mf.followMoves then
                        mf.warp("moved")
                    end
                end)
                if not ok then warn("observer callback: " .. tostring(err)) end
            end)
            obs:addWatcher(axApp, "AXFocusedWindowChanged")
            obs:start()
        end)
        if not okWatch then
            if not mf.refused[name] then
                mf.refused[name] = true
                print("🖱 Mouse Follows Focus: " .. name .. " didn't accept an "
                      .. "Accessibility watcher (said once per app per session)")
            end
            return false
        end
        -- Moves are the second rule; an app that refuses that watcher
        -- keeps the first.
        pcall(function() obs:addWatcher(axApp, "AXWindowMoved") end)
        mf.observer = obs
        return true
    end

    function mf.onActivated(app)
        local ok, err = pcall(mf.attach, app)
        if not ok then warn("attach: " .. tostring(err)) end
        mf.warp("activated")
    end

    -- ---- ⇪⇧3 -------------------------------------------------------------
    function mf.toggle()
        mf.active = not mf.active
        hs.alert.show(mf.active and "🖱 Mouse follows focus: ON"
                                or  "🖱 Mouse follows focus: off")
        say(mf.active and "on" or "off")
        if mf.active then mf.warp("focus") end
        return mf.active
    end

    -- ---- 🩺 report --------------------------------------------------------
    function _G.mouseFollowsReport()
        local L = { "🖱 MOUSE FOLLOWS FOCUS (⇪⇧3)" }
        L[#L + 1] = "   accessibility : " .. (axOK() and "granted"
                                              or "OFF — no window frame can be read")
        L[#L + 1] = "   state         : " .. (not mf.enabled and "disabled (mf.enabled = false)"
                                              or mf.active and "ON" or "off — ⇪⇧3 turns it on")
        L[#L + 1] = "   follows moves : " .. (mf.followMoves and "yes (rule 2)" or "no")
        L[#L + 1] = "   watching      : " .. (mf.currentApp or "nothing yet")
                    .. (mf.observer and "" or " (no observer)")
        L[#L + 1] = string.format("   jumped        : %d time%s · stood still %d",
                                  mf.warps, mf.warps == 1 and "" or "s", mf.skipped)
        if mf.last then
            L[#L + 1] = string.format("   last          : %s → %s %q at %d,%d (%s)",
                mf.last.why, mf.last.app, mf.last.title,
                math.floor(mf.last.x), math.floor(mf.last.y), mf.last.when)
        else
            L[#L + 1] = "   last          : never — nothing has jumped yet"
        end
        if mf.lastSkip then
            L[#L + 1] = "   stood still   : " .. mf.lastSkip
        end
        local names = {}
        for n in pairs(mf.refused) do names[#names + 1] = n end
        table.sort(names)
        if #names > 0 then
            L[#L + 1] = "   refused       : " .. table.concat(names, ", ")
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    core.provide("mouseFollows.toggle", function() return mf.toggle() end)
    core.provide("mouseFollows.warp",   function(why) return mf.warp(why or "focus") end)
    core.provide("mouseFollows.report", function() return _G.mouseFollowsReport() end)
    _G.mouseFollows = mf
    M.mf     = mf
    M.config = mf

    if not mf.enabled then return end
    if not axOK() then
        if _G.notices then
            _G.notices.record("mouseFollows", "Accessibility off",
                              "the pointer cannot follow focus")
        end
        warn("Accessibility is off — nothing started")
        return
    end

    core.hyperAddShortcut(mf.keyMods, mf.key, function() mf.toggle() end,
                          "mouse follows focus")

    local okW, w = pcall(hs.application.watcher.new, function(_, eventType, app)
        if eventType == hs.application.watcher.activated then
            mf.onActivated(app)
        end
    end)
    if okW and w then
        mf.appWatcher = w
        pcall(function() w:start() end)
    else
        warn("hs.application.watcher failed — focus will not be followed")
    end

    -- Whatever is frontmost RIGHT NOW gets its observer; no jump at boot —
    -- a reload must not move your pointer.
    pcall(function()
        local app = hs.application.frontmostApplication()
        if app then mf.attach(app) end
    end)
end

return M
