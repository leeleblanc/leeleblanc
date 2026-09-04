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
--        ⇪⇧3        on / off — REMEMBERED across reloads since 6.161.0
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
-- ---- 🚨 6.160.2 — THE FIRST DAY HUNG THE MAC -------------------------
-- LL: "I couldn't type. Hammerspoon was locking up my Mac and any tool I
-- would bring up would not go away until I quit Hammerspoon." 6.160.0
-- read the focused window through hs.window inside the AX callback —
-- calls with NO timeout, on Hammerspoon's main thread, fired for every
-- step of every window move. One app slow to answer Accessibility (a
-- Chrome with a 1 GB tab, VLC mid-frame) and Hammerspoon waits for it;
-- while it waits nothing else runs: no Esc for the picker on screen, no
-- keystrokes through the taps ("tap was disabled by macOS" is that).
-- Now:
--   · Every AX read goes through hs.axuielement with a timeout
--     (mf.axTimeout) — the same withTimeout discipline Dialog Home uses.
--     A slow app costs at most that long, then the jump is skipped.
--   · The AX callback does NO work: it notes the reason and hands off to
--     a zero-delay timer (held), so the notification returns at once.
--     Moves are coalesced — a drag's hundred notifications are one.
--   · A watchdog: a jump that takes longer than mf.slowMs, mf.slowStrikes
--     times, turns the feature OFF for the session, on screen and in the
--     Console, rather than letting it happen a third time.
--   · It starts OFF. ⇪⇧3 turns it on when you want it; a profile can
--     start it on with settings = { mouseFollows = { active = true } }.
--
-- ---- 🔁 6.161.0 — "MOUSEFOCUS NO LONGER WORKS" -------------------------
-- LL, the day after it worked. Three things could make it look dead, and
-- each one is closed here:
--   · It started OFF at EVERY reload (6.160.2): an update, a ⌘R, a
--     reboot — and the pointer stopped following until ⇪⇧3 was pressed
--     again. Now ⇪⇧3 is REMEMBERED (hs.settings, mf.SETTINGS_KEY): turned
--     on once, it is on at the next boot; turned off, it stays off. A
--     profile's settings = { mouseFollows = { active = true } } still
--     wins over the memory, as every profile override does.
--   · The watchdog turned it off for the WHOLE session after two slow
--     jumps — any two, a morning apart — and the one alert was easy to
--     miss. Now a strike is forgotten after mf.slowWindow seconds, and
--     standing down is a REST (mf.slowRest): it comes back on its own,
--     says so, and ⇪⇧3 wakes it sooner. Every read has carried a timeout
--     since 6.160.2, so the worst a rest prevents is a stutter, never a
--     hang — a permanent off was more caution than the risk deserved.
--   · With Accessibility off it bound NO key at all, so ⇪⇧3 did nothing,
--     silently. The key is bound regardless now; without Accessibility
--     the press says where to grant it.
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
            { "⇪⇧3",   "On / off — remembered across reloads (6.161.0)" },
            { "safe",   "Every window read has a timeout; a slow app never hangs you" },
            { "rests",  "Two slow jumps in a minute: it rests 5 min, then returns by itself" },
            { "check",  "_G.mouseFollowsReport() — last jump, why it stood still" },
        },
    },
}

function M.setup(core)
    local mf = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    mf.enabled      = true           -- the module loads at all
    mf.active       = false          -- the boot default; the MEMORY (either
                                     -- way) and a profile override sit on top
    mf.remember     = true           -- 6.161.0: ⇪⇧3's last setting survives a
                                     -- reload (hs.settings)
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
    -- ⏱ How long one Accessibility question may take (seconds). Past it
    -- the answer is "no jump", never "wait".
    mf.axTimeout    = 0.15
    -- 🐕 A jump slower than this, this many times, turns the feature off
    -- for the session — a Mac that hangs is worse than a pointer that
    -- stays put.
    mf.slowMs       = 250
    mf.slowStrikes  = 2
    mf.slowWindow   = 60             -- 6.161.0: seconds a strike is remembered
    mf.slowRest     = 300            -- 6.161.0: seconds it rests after standing
                                     -- down, then returns on its own
    -- ----------------------------------------------------------------------

    mf.OWN_BUNDLE   = "org.hammerspoon.Hammerspoon"
    mf.SETTINGS_KEY = "mouseFollows.active"   -- hs.settings: true/false, the memory
    mf.warps      = 0
    mf.skipped    = 0
    mf.last       = nil      -- { app, title, x, y, why, when }
    mf.lastSkip   = nil      -- why the last candidate stood still
    mf.lastCentre = nil      -- { x, y } of the last warp, for the dedupe
    mf.observer   = nil      -- the ONE live AX observer
    mf.appWatcher = nil      -- HELD
    mf.refused    = {}       -- apps that would not take an observer (said once)
    mf.currentApp = nil
    mf.pending    = nil      -- HELD: the zero-delay hand-off timer
    mf.pendingWhy = nil
    mf.slowHits   = 0        -- strikes inside the last mf.slowWindow seconds
    mf.strikes    = {}       -- os.time() of each strike still counted
    mf.lastMs     = nil      -- how long the last jump took
    mf.stoodDown  = nil      -- why the watchdog stood it down, if it did
    mf.restUntil  = nil      -- os.time() the rest ends, while resting
    mf.restTimer  = nil      -- HELD: the timer that ends the rest
    mf.lastRest   = nil      -- the last rest's reason, once it is over
    mf.remembered = nil      -- what hs.settings held at boot (true/false/nil)

    local function say(m)  if _G.diag then _G.diag.say("mousefollows", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("mousefollows", m) end end

    local function axOK()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    -- ---- the memory (6.161.0) --------------------------------------------
    -- hs.settings lives outside the config: it survives a reload, an
    -- update, a reboot — and is never synced, so the two Macs remember
    -- separately. Every call is pcall'd: a Mac that will not store it
    -- simply starts at the boot default.
    function mf.save(on)
        if not mf.remember then
            -- A profile that turned the memory off lands AFTER setup (the
            -- "apply settings" block), so a value already stored must not
            -- keep winning every boot: the first press wipes it.
            local cleared = pcall(function() hs.settings.clear(mf.SETTINGS_KEY) end)
            if not cleared then pcall(function() hs.settings.set(mf.SETTINGS_KEY, nil) end) end
            return false
        end
        local ok = pcall(function() hs.settings.set(mf.SETTINGS_KEY, on and true or false) end)
        return ok
    end

    function mf.recall()
        if not mf.remember then return nil end
        local saved
        pcall(function() saved = hs.settings.get(mf.SETTINGS_KEY) end)
        if saved ~= true and saved ~= false then return nil end
        mf.remembered = saved
        return saved
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
    -- The focused window of the FRONT app, its frame, and its centre —
    -- through hs.axuielement WITH A TIMEOUT on every question. hs.window
    -- asks the same questions with none, and a question with no timeout
    -- is a hang waiting for a slow app (6.160.2).
    local function withTimeout(el)
        pcall(function() el:setTimeout(mf.axTimeout) end)
        return el
    end

    function mf.target()
        local app
        pcall(function() app = hs.application.frontmostApplication() end)
        if not app then return nil, "no front app" end
        if mf.isOwn(app) then return nil, "own window" end
        local name = appName(app)
        if mf.skipApps[name] then return nil, "skipped app: " .. name end
        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then return nil, "no AX element for " .. name end
        withTimeout(axApp)
        local win
        pcall(function() win = axApp:attributeValue("AXFocusedWindow") end)
        if not win then return nil, "no focused window in " .. name end
        withTimeout(win)
        local pos, size, title
        pcall(function() pos   = win:attributeValue("AXPosition") end)
        pcall(function() size  = win:attributeValue("AXSize") end)
        pcall(function() title = win:attributeValue("AXTitle") end)
        if not (type(pos) == "table" and type(size) == "table"
                and pos.x and pos.y and size.w and size.h
                and size.w > 0 and size.h > 0) then
            return nil, "no frame for the focused window (slow or silent app)"
        end
        return { x = pos.x + size.w / 2, y = pos.y + size.h / 2,
                 app = name, title = tostring(title or "") }
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
    local function nowMs()
        local t
        pcall(function() t = hs.timer.absoluteTime() / 1e6 end)
        return t
    end

    function mf.warp(why)
        if not (mf.enabled and mf.active) then
            mf.lastSkip = "off"; return false
        end
        local t0 = nowMs()
        local did = mf.warpNow(why)
        local t1 = nowMs()
        if t0 and t1 then
            mf.lastMs = t1 - t0
            if mf.lastMs > mf.slowMs then mf.strike() end
        end
        return did
    end

    -- ---- the watchdog (6.161.0: strikes expire, standing down is a rest) --
    function mf.strike()
        local now, keep = os.time(), {}
        for _, at in ipairs(mf.strikes) do
            if now - at <= mf.slowWindow then keep[#keep + 1] = at end
        end
        keep[#keep + 1] = now
        mf.strikes, mf.slowHits = keep, #keep
        warn(string.format("a jump took %dms (strike %d of %d within %ds)",
             math.floor(mf.lastMs or 0), mf.slowHits, mf.slowStrikes, mf.slowWindow))
        if mf.slowHits >= mf.slowStrikes then mf.rest() end
    end

    function mf.rest()
        mf.active = false
        mf.strikes, mf.slowHits = {}, 0
        mf.restUntil = os.time() + mf.slowRest
        local mins = math.max(1, math.floor(mf.slowRest / 60 + 0.5))
        mf.stoodDown = string.format("%d jumps over %dms — resting %d minute%s "
                                     .. "(⇪⇧3 wakes it sooner)",
                                     mf.slowStrikes, mf.slowMs, mins, mins == 1 and "" or "s")
        hs.alert.show(string.format("🖱 Mouse follows focus is resting — an app was "
                                    .. "slow to answer. Back in %d min; ⇪⇧3 wakes it now.", mins))
        warn(mf.stoodDown)
        if _G.notices then
            _G.notices.record("mouseFollows", "resting", mf.stoodDown)
        end
        if mf.restTimer then pcall(function() mf.restTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, mf.slowRest, function()
            mf.restTimer = nil
            mf.wake()
        end)
        mf.restTimer = (ok and t) or nil
    end

    -- The rest ends: on its own (the timer), or early, by ⇪⇧3.
    function mf.wake()
        if mf.restTimer then
            pcall(function() mf.restTimer:stop() end)
            mf.restTimer = nil
        end
        if not mf.restUntil then return false end
        mf.restUntil = nil
        mf.active = true
        mf.lastRest, mf.stoodDown = mf.stoodDown, nil
        hs.alert.show("🖱 Mouse follows focus is back ON after its rest")
        say("rested — on again")
        return true
    end

    function mf.warpNow(why)
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

    -- The hand-off. One timer at a time: a drag's hundred AXWindowMoved
    -- notifications become one jump; a focus change outranks a move.
    function mf.schedule(why)
        if not (mf.enabled and mf.active) then return false end
        if mf.pending then
            if why == "focus" then mf.pendingWhy = "focus" end
            return true
        end
        mf.pendingWhy = why
        local ok, t = pcall(hs.timer.doAfter, 0, function()
            local w = mf.pendingWhy or why
            mf.pending, mf.pendingWhy = nil, nil
            local okW, err = pcall(mf.warp, w)
            if not okW then warn("jump: " .. tostring(err)) end
        end)
        if ok and t then mf.pending = t ; return true end
        return false
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
                -- NO work here (6.160.2): note why, return at once
                if notif == "AXFocusedWindowChanged" then
                    mf.schedule("focus")
                elseif notif == "AXWindowMoved" and mf.followMoves then
                    mf.schedule("moved")
                end
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
        mf.schedule("activated")     -- off the watcher's thread of events, too
    end

    -- ---- ⇪⇧3 -------------------------------------------------------------
    function mf.toggle()
        if not axOK() then
            hs.alert.show("🖱 Mouse follows focus needs Accessibility — System "
                          .. "Settings › Privacy & Security › Accessibility › Hammerspoon", 5)
            return false
        end
        -- A press during a rest is "wake up now", whichever way it lands:
        -- the rest is over either way, and the timer must not turn it back
        -- on later against an explicit off.
        if mf.restTimer then
            pcall(function() mf.restTimer:stop() end)
            mf.restTimer = nil
        end
        if mf.restUntil then mf.lastRest, mf.stoodDown = mf.stoodDown, nil end
        mf.restUntil = nil
        -- ON in name only — remembered (or a profile) ON while Accessibility
        -- was off at boot, so nothing is watching. The grant has arrived
        -- (we are past the check above): this press STARTS it and stays
        -- ON; flipping to off here would also overwrite the memory.
        if mf.active and not mf.appWatcher then
            if mf.start() then
                hs.alert.show("🖱 Mouse follows focus: ON — watching now")
                say("started by ⇪⇧3 — Accessibility arrived after boot")
                mf.warp("focus")
                return true
            end
        end
        mf.active = not mf.active
        mf.save(mf.active)
        -- Accessibility granted AFTER boot (the press → alert → grant →
        -- press again path this module invites): nothing is watching yet,
        -- so start the watcher now rather than waiting for a reload.
        if mf.active and not mf.appWatcher then mf.start() end
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
                                              or (mf.active and not mf.appWatcher)
                                                 and "ON in name only — nothing is watching (Accessibility was off at boot; ⇪⇧3 starts it once granted)"
                                              or mf.active and "ON"
                                              or mf.restUntil and ("resting until "
                                                  .. os.date("%H:%M:%S", mf.restUntil)
                                                  .. " — ⇪⇧3 wakes it now")
                                              or "off — ⇪⇧3 turns it on")
        L[#L + 1] = "   remembered    : " .. (not mf.remember and "no (mf.remember = false)"
                                              or mf.remembered == true and "ON at boot (hs.settings)"
                                              or mf.remembered == false and "off at boot (hs.settings)"
                                              or "nothing yet — ⇪⇧3 once and it sticks")
        L[#L + 1] = "   follows moves : " .. (mf.followMoves and "yes (rule 2)" or "no")
        L[#L + 1] = string.format("   AX timeout    : %dms per question · watchdog %dms × %d in %ds, rests %ds",
                                  math.floor(mf.axTimeout * 1000 + 0.5), mf.slowMs, mf.slowStrikes,
                                  mf.slowWindow, mf.slowRest)
        if mf.lastMs then
            L[#L + 1] = string.format("   last jump took: %dms · slow strikes %d",
                                      math.floor(mf.lastMs), mf.slowHits)
        end
        if mf.stoodDown then
            L[#L + 1] = "   stood down    : " .. mf.stoodDown
        elseif mf.lastRest then
            L[#L + 1] = "   last rest     : " .. mf.lastRest .. " — over"
        end
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

    -- ---- the watcher ------------------------------------------------------
    -- Whatever is frontmost RIGHT NOW gets its observer; no jump at boot —
    -- a reload must not move your pointer. Called at boot, and from ⇪⇧3
    -- when Accessibility arrived after boot (6.161.0).
    function mf.start()
        if mf.appWatcher then return true end
        if not axOK() then return false end
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
            return false
        end
        pcall(function()
            local app = hs.application.frontmostApplication()
            if app then mf.attach(app) end
        end)
        return true
    end

    core.provide("mouseFollows.toggle", function() return mf.toggle() end)
    core.provide("mouseFollows.warp",   function(why) return mf.warp(why or "focus") end)
    core.provide("mouseFollows.report", function() return _G.mouseFollowsReport() end)
    _G.mouseFollows = mf
    M.mf     = mf
    M.config = mf

    if not mf.enabled then return end

    -- ⇪⇧3 is bound BEFORE the Accessibility check (6.161.0): with the
    -- grant missing the press explains itself instead of doing nothing.
    core.hyperAddShortcut(mf.keyMods, mf.key, function() mf.toggle() end,
                          "mouse follows focus")

    -- The memory (6.161.0): what ⇪⇧3 last chose, if it was ever pressed —
    -- either way, on or off, over the boot default. Read before the
    -- Accessibility check: it is a plain read, and the report should
    -- know it whatever the grant says.
    local saved = mf.recall()
    if saved ~= nil then
        mf.active = saved
        say(saved and "on at boot — remembered from the last ⇪⇧3"
                   or "off at boot — remembered from the last ⇪⇧3")
    end

    if not axOK() then
        if _G.notices then
            _G.notices.record("mouseFollows", "Accessibility off",
                              "the pointer cannot follow focus")
        end
        warn("Accessibility is off — nothing started (⇪⇧3 says where to grant it)")
        return
    end

    mf.start()
end

return M
