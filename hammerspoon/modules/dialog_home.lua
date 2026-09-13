-- =====================================================================
-- MODULE: DIALOG HOME (automatic) — dialogs land at YOUR spot
-- =====================================================================
-- LL, with a screenshot of Finder's "A folder named 'core' already
-- exists in this location. Do you want to replace it…" dialog:
--
--      "Can we capture this kind of window and make it appear in the
--       same place, on my primary monitor?"
--
-- THAT dialog is the one this config makes LL meet on every single
-- release — install the zip, drag the folders into ~/.hammerspoon, and
-- Finder asks about `core` and `modules` in a box that appears wherever
-- Finder feels like putting it. macOS gives you no say: alerts and
-- dialogs open where the app decides, usually centred on whatever screen
-- the app's window is on, sometimes somewhere stranger. On two monitors
-- that means hunting for the question before you can answer it.
--
-- So: THIS KIND of window — role AXWindow with subrole AXDialog or
-- AXSystemDialog (the accessibility API's own word for "this is a
-- dialog"), plus modally-flagged standard windows — is moved the moment
-- it appears, to ONE remembered spot. The spot starts as "centred, a
-- little high, on the PRIMARY monitor" (the one macOS gives the menu
-- bar — System Settings → Displays), and the CAPTURE half of LL's
-- sentence is literal: drag any dialog somewhere better and that
-- becomes the spot, persisted across reloads. The next dialog appears
-- there. The same place, every time.
--
-- ⚖️ HOW IT WATCHES, AND WHY NOT THE OBVIOUS WAY. The textbook answer
-- is hs.window.filter, and that module is BANNED from this config with
-- break-tested sentries: it subscribes to every window of every app at
-- start-up and froze this exact Mac for 44 seconds once (see
-- modules/window_switcher.lua's header — the beachball that started the
-- rule). This module instead runs ONE Accessibility observer on the
-- FRONTMOST app only, re-attached as you switch apps — the same shape
-- copy_on_select has used since 6.55.0. Event-driven, no polling, no
-- keyboard taps, nothing the 6.131–6.137 lag hunts would recognise.
--
-- 🚨 THE HONEST LIMIT OF THAT CHOICE: a dialog that pops in a
-- BACKGROUND app is not seen at the moment it appears — there is no
-- observer on that app. It is caught the moment you ACTIVATE the app to
-- deal with it: attach() sweeps that one app's windows for a dialog
-- already on screen and places it then. Since a dialog is a question
-- and you must bring its app forward to answer it, the practical
-- difference is one beat, not a missed window.
--
-- 🚨 AND THE LIMIT UNDERNEATH EVERYTHING: some processes never accept
-- an Accessibility watcher (Electron shells, some of Apple's own newer
-- panels — copy_on_select's 6.66.5 finding), and a few dialogs refuse
-- to be moved at all. Both are RECORDED, once per app, and _G.dialogs()
-- names them — a dialog that stayed put should have an answer on file,
-- not a shrug. Sheets (the panels glued to a window's title bar) are
-- deliberately never touched: they belong to their window, not to a
-- spot.

local M = {
    name   = "Dialog Home",
    order  = 6.8,
    family = "windows",
    cheatsheet = {
        title = "🎯 DIALOG HOME (automatic — dialogs land at your spot)",
        entries = {
            { "auto",     "Dialogs (Replace? Save? Delete?) open at ONE spot on the PRIMARY monitor" },
            { "capture",  "Drag any dialog somewhere better — that spot becomes the new home" },
            { "default",  "Centred, a little high, on the primary screen — until you drag one" },
            { "scope",    "Frontmost app; a background app's dialog is placed when you switch to it" },
            { "sheets",   "Panels glued to a window's title bar are never touched" },
            { "_G.dialogs()", "Console: the spot, the last dialog seen, and who refused" },
            { "reset",    "_G.dialogHome.reset() forgets the captured spot" },
            { "off",      "dh.enabled = false in modules/dialog_home.lua's EDIT HERE" },
        },
    },
}

function M.setup(core)
    local dh = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    dh.enabled     = true
    -- Which subroles count as "this kind of window". These are the
    -- accessibility API's own labels; _G.dialogs() shows the subrole of
    -- the last window created, so if a dialog slips through you can read
    -- its label there and add it here.
    dh.subroles    = { AXDialog = true, AXSystemDialog = true }
    -- A standard window that declares itself MODAL is a dialog in a
    -- window's clothing (some apps build their alerts that way).
    dh.alsoModal   = true
    dh.xFrac       = 0.50    -- where on the home screen: 0.5 = centred
    dh.yFrac       = 0.35    -- a little above centre, where macOS puts alerts
    -- A "dialog" bigger than this fraction of the home screen in either
    -- direction is not something to fling around — left alone.
    dh.maxFrac     = 0.60
    dh.landTol     = 8       -- px — closer than this counts as "landed"
    dh.settleDelay = 0.15    -- seconds before verifying a move landed
    dh.suppressSecs = 1.0    -- our own move must not read as your drag
    dh.captureDebounce = 0.8 -- a drag has stopped when it is quiet this long
    dh.sweepOnActivate = true  -- catch a background app's waiting dialog
    dh.sweepDelay  = 0.25    -- a beat after activation, off the switch animation
    dh.slowSweepMs = 250     -- a sweep slower than this is named in the console
    -- ⚠️ A SAFETY LIMIT, NOT A TUNING KNOB (copy_on_select's rule, kept
    -- verbatim): every Accessibility question crosses a process boundary
    -- and can hang, and raising this raises how long one wedged app can
    -- hold your keyboard.
    dh.axTimeout   = 0.10
    -- ----------------------------------------------------------------------

    local SETTINGS_KEY = "dialogHome.pos"

    local function say(m)  if _G.diag then _G.diag.say("dialogHome", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("dialogHome", m) end end

    -- The timeout goes on BEFORE anything is asked — the ordering is the
    -- whole protection (menubar_items 6.47.0, copy_on_select since 6.55).
    local function withTimeout(el)
        if not el then return nil end
        pcall(function() el:setTimeout(dh.axTimeout) end)
        return el
    end
    local function now()
        local ok, t = pcall(hs.timer.secondsSinceEpoch)
        return ok and t or 0
    end

    -- Reading and moving other apps' windows is exactly what
    -- Accessibility gates. Without it, start nothing — same stand-down
    -- as Window Return and Window Pin.
    local axOK = false
    pcall(function() axOK = hs.accessibilityState() == true end)

    dh.pos          = nil    -- the captured spot; nil = the computed default
    dh.last         = nil    -- the last dialog seen, for _G.dialogs()
    dh.refused      = {}     -- apps that would not take a watcher (once each)
    dh.suppressUntil = 0     -- our own moves are not captures
    dh.pending      = nil    -- a drag in progress, waiting for the debounce
    dh.appWatcher   = nil    -- HELD: unreferenced watchers are collected
    dh.observer     = nil    -- the one AX observer, frontmost app only
    dh.verifyTimer  = nil    -- HELD, all of them: a collected timer never
    dh.captureTimer = nil    --   fires, which here means a move that is
    dh.sweepTimer   = nil    --   never verified and a drag never captured
    dh.lastSweep    = nil    -- { app, ms, windows } of the latest sweep

    -- ---- the remembered spot ---------------------------------------------
    -- 🚨 VALIDATED ON THE WAY BACK IN — the same rule the cheat sheet's
    -- position and win_pin's notes follow. hs.settings is a plist on
    -- disk: it can hand back a string, a NaN, or half a table, and a
    -- position is two finite numbers or it is not a position.
    local function validPos(p)
        if type(p) ~= "table" then return nil end
        local x, y = tonumber(p.x), tonumber(p.y)
        if not x or not y then return nil end
        if x ~= x or y ~= y then return nil end            -- NaN
        if math.abs(x) > 100000 or math.abs(y) > 100000 then return nil end
        return { x = x, y = y }
    end

    function dh.save(p)
        local ok = validPos(p)
        if not ok then return false end
        local wrote = pcall(function() hs.settings.set(SETTINGS_KEY, ok) end)
        return wrote and true or false
    end

    function dh.load()
        local saved
        pcall(function() saved = hs.settings.get(SETTINGS_KEY) end)
        return validPos(saved)
    end

    function dh.reset()
        dh.pos = nil
        pcall(function() hs.settings.set(SETTINGS_KEY, nil) end)
        pcall(function()
            hs.alert.show("🎯 Dialog spot forgotten — back to centred on the primary monitor")
        end)
        return true
    end

    dh.pos = dh.load()

    -- ---- which screen, which spot ----------------------------------------
    -- The PRIMARY screen: the one with the menu bar, which is what "my
    -- primary monitor" means in System Settings → Displays. mainScreen()
    -- is the screen with keyboard focus — a different thing, and exactly
    -- the follow-you-around behaviour being replaced.
    function dh.homeScreen()
        local scr
        pcall(function() scr = hs.screen.primaryScreen() end)
        if scr then return scr end
        pcall(function() scr = hs.screen.mainScreen() end)
        return scr
    end

    function dh.homeFrame()
        local scr = dh.homeScreen()
        if not scr then return nil end
        local f
        pcall(function() f = scr:frame() end)
        return f
    end

    -- Where a w×h dialog goes. The captured spot wins; the default is
    -- computed FRESH from the primary screen every time, so unplugging
    -- or rearranging monitors never strands the default. A captured spot
    -- is clamped to a real screen (init.lua's rule for every remembered
    -- position: a spot outlives the display it was set on).
    function dh.spot(w, h)
        if dh.pos then
            local p = dh.pos
            if _G.clampToScreen then
                local c = _G.clampToScreen({ x = p.x, y = p.y }, w, h)
                if c and c.x then return { x = c.x, y = c.y }, "captured" end
            end
            return { x = p.x, y = p.y }, "captured"
        end
        local f = dh.homeFrame()
        if not f then return nil, "no screen" end
        return { x = f.x + (f.w - (w or 0)) * dh.xFrac,
                 y = f.y + (f.h - (h or 0)) * dh.yFrac }, "default"
    end

    -- ---- what counts as "this kind of window" ----------------------------
    -- Decided on already-read facts, so the suite can drive the rule
    -- without an accessibility API in the room.
    function dh.isDialogKind(d)
        if type(d) ~= "table" then return false end
        if d.role ~= "AXWindow" then return false end      -- sheets are AXSheet
        if dh.subroles[d.subrole or ""] then return true end
        if dh.alsoModal and d.subrole == "AXStandardWindow" and d.modal == true then
            return true
        end
        return false
    end

    -- The facts, each behind its own pcall — an element can die between
    -- any two questions and one corpse must not cost the placement.
    function dh.describe(el)
        withTimeout(el)
        local d = {}
        local function attr(name)
            local v
            pcall(function() v = el:attributeValue(name) end)
            return v
        end
        d.role    = attr("AXRole")
        d.subrole = attr("AXSubrole")
        if dh.alsoModal and d.subrole == "AXStandardWindow" then
            d.modal = attr("AXModal") == true
        end
        d.title   = attr("AXTitle")
        local p, s = attr("AXPosition"), attr("AXSize")
        if type(p) == "table" and tonumber(p.x) then
            d.x, d.y = tonumber(p.x), tonumber(p.y)
        end
        if type(s) == "table" and tonumber(s.w) then
            d.w, d.h = tonumber(s.w), tonumber(s.h)
        end
        return d
    end

    -- ---- placing one -----------------------------------------------------
    local function setPosition(el, x, y)
        withTimeout(el)
        -- Every programmatic move opens the suppression window FIRST, so
        -- the AXWindowMoved it causes can never read as a drag of yours.
        dh.suppressUntil = now() + dh.suppressSecs
        local ok = pcall(function()
            el:setAttributeValue("AXPosition",
                { x = math.floor(x + 0.5), y = math.floor(y + 0.5) })
        end)
        return ok
    end

    -- Move it, then VERIFY the move landed (the VLC lesson, 6.123.0: a
    -- setFrame that silently does nothing looks identical to success
    -- unless you look again). One retry, then the refusal goes on file.
    function dh.place(el, appName, why)
        if not dh.enabled then return false, "off" end
        local d = dh.describe(el)
        dh.last = { app = appName, title = d.title, role = d.role,
                    subrole = d.subrole, when = os.date("%H:%M:%S"),
                    why = why, outcome = "not a dialog" }
        if not dh.isDialogKind(d) then return false, "not a dialog" end
        if not (d.w and d.h) then
            dh.last.outcome = "size unreadable — left alone"
            return false, "no size"
        end
        local f = dh.homeFrame()
        if f and (d.w > f.w * dh.maxFrac or d.h > f.h * dh.maxFrac) then
            dh.last.outcome = "too big to be a dialog — left alone"
            return false, "too big"
        end
        local target, kind = dh.spot(d.w, d.h)
        if not target then
            dh.last.outcome = "no screen to place it on"
            return false, "no screen"
        end
        if d.x and math.abs(d.x - target.x) <= dh.landTol
           and math.abs(d.y - target.y) <= dh.landTol then
            dh.last.outcome = "already at the spot"
            return true, "already there"
        end
        if not setPosition(el, target.x, target.y) then
            dh.last.outcome = "refused the move"
            warn((appName or "?") .. ": a dialog refused AXPosition")
            return false, "refused"
        end
        dh.last.outcome = "moved to the " .. kind .. " spot"
        say(string.format("%s dialog → %d,%d (%s, %s)", appName or "?",
                          target.x, target.y, kind, why or "?"))

        -- The verification, a beat later. HELD, or it never fires.
        if dh.verifyTimer then pcall(function() dh.verifyTimer:stop() end) end
        pcall(function()
            dh.verifyTimer = hs.timer.doAfter(dh.settleDelay, function()
                local d2 = dh.describe(el)
                if not d2.x then return end        -- it closed; fine
                if math.abs(d2.x - target.x) <= dh.landTol
                   and math.abs(d2.y - target.y) <= dh.landTol then return end
                -- Once more — some dialogs are re-centred by their app a
                -- moment after appearing. Twice refused is an answer.
                if setPosition(el, target.x, target.y) then
                    dh.retried = (dh.retried or 0) + 1
                else
                    dh.last.outcome = "moved, then it moved back and refused"
                    warn((appName or "?") .. ": a dialog would not stay put")
                end
            end)
        end)
        return true, "moved"
    end

    -- ---- the capture: your drag becomes the spot -------------------------
    -- AXWindowMoved fires for every step of a drag AND for our own
    -- setAttributeValue. The suppression window filters us out; the
    -- debounce waits for the drag to stop before anything is kept, so
    -- one drag is one capture, not two hundred.
    function dh.onMoved(el, appName)
        if not dh.enabled then return false end
        if now() < dh.suppressUntil then return false end
        local d = dh.describe(el)
        if not dh.isDialogKind(d) then return false end
        if not d.x then return false end
        dh.pending = { x = d.x, y = d.y }
        if dh.captureTimer then pcall(function() dh.captureTimer:stop() end) end
        pcall(function()
            dh.captureTimer = hs.timer.doAfter(dh.captureDebounce, function()
                local p = validPos(dh.pending)
                dh.pending = nil
                if not p then return end
                dh.pos = p
                dh.save(p)
                say(string.format("spot captured from %s: %d,%d",
                                  appName or "?", p.x, p.y))
                pcall(function()
                    hs.alert.show("🎯 Dialogs will open here now — _G.dialogHome.reset() undoes it")
                end)
            end)
        end)
        return true
    end

    -- ---- the watcher: one observer, frontmost app only -------------------
    local function stopObserver()
        if dh.observer then
            pcall(function() dh.observer:stop() end)
            dh.observer = nil
        end
        if dh.sweepTimer then pcall(function() dh.sweepTimer:stop() end) end
    end

    -- A background app's dialog was invisible to us until now (the ⚖️
    -- trade in the header). One app, one AXWindows read, one subrole
    -- question per window before anything heavier — and measured, so a
    -- slow app gets named instead of guessed at (Window Return's rule).
    function dh.sweep(axApp, appName)
        local t0
        pcall(function() t0 = hs.timer.absoluteTime() end)
        withTimeout(axApp)
        local wins
        pcall(function() wins = axApp:attributeValue("AXWindows") end)
        local n = 0
        for _, w in ipairs(type(wins) == "table" and wins or {}) do
            n = n + 1
            withTimeout(w)
            local sub
            pcall(function() sub = w:attributeValue("AXSubrole") end)
            local interesting = dh.subroles[sub or ""]
            if not interesting and dh.alsoModal and sub == "AXStandardWindow" then
                local modal
                pcall(function() modal = w:attributeValue("AXModal") end)
                interesting = modal == true
            end
            if interesting then dh.place(w, appName, "found on switch") end
        end
        local ms
        pcall(function() ms = (hs.timer.absoluteTime() - t0) / 1e6 end)
        dh.lastSweep = { app = appName, ms = ms, windows = n }
        if ms and ms > dh.slowSweepMs then
            warn(string.format("%s took %dms to list %d windows", appName or "?", ms, n))
        end
    end

    function dh.attach(app)
        stopObserver()
        if not (dh.enabled and app) then return false end
        local name, pid, bundle
        pcall(function() name   = app:name() end)
        pcall(function() pid    = app:pid() end)
        pcall(function() bundle = app:bundleID() end)
        -- Never our own windows: the pads and pickers place themselves
        -- (§1.5), and a module that yanks them to a "home" would be
        -- fighting the popupOffset system from inside the same config.
        if not pid or bundle == "org.hammerspoon.Hammerspoon" then return false end

        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then return false end
        withTimeout(axApp)

        local okObs, obs = pcall(hs.axuielement.observer.new, pid)
        if not (okObs and obs) then return false end
        local okWatch = pcall(function()
            obs:callback(function(_, el, notif)
                local ok, err = pcall(function()
                    if notif == "AXWindowCreated" then
                        dh.place(el, name, "appeared")
                    elseif notif == "AXWindowMoved" then
                        dh.onMoved(el, name)
                    end
                end)
                if not ok then warn("observer callback: " .. tostring(err)) end
            end)
            obs:addWatcher(axApp, "AXWindowCreated")
            obs:start()
        end)
        if not okWatch then
            -- Once per app per session, never per activation — repeating
            -- a fixed fact turns a real finding into wallpaper
            -- (copy_on_select, 6.66.5).
            if name and not dh.refused[name] then
                dh.refused[name] = true
                print("🎯 Dialog Home: " .. name .. " didn't accept an "
                      .. "Accessibility watcher (said once per app per session)")
            end
            return false
        end
        -- The capture wants AXWindowMoved too, but an app that refuses
        -- it should not lose PLACEMENT over it — dialogs still land,
        -- drags in that app just aren't captured.
        pcall(function() obs:addWatcher(axApp, "AXWindowMoved") end)
        dh.observer = obs

        if dh.sweepOnActivate then
            -- A beat later, off the app-switch animation. HELD.
            pcall(function()
                dh.sweepTimer = hs.timer.doAfter(dh.sweepDelay, function()
                    dh.sweep(axApp, name)
                end)
            end)
        end
        return true
    end

    -- ---- console ---------------------------------------------------------
    function dh.status()
        local out = { "🎯 Dialog Home — dialogs land at one spot" }
        if not dh.enabled then
            out[#out + 1] = "  OFF (dh.enabled = false)"
            return table.concat(out, "\n")
        end
        if not axOK then
            out[#out + 1] = "  OFF — macOS Accessibility is not granted; no"
            out[#out + 1] = "  window can be read or moved. _G.capabilityReport() has the detail."
            return table.concat(out, "\n")
        end
        local f = dh.homeFrame()
        out[#out + 1] = "  home screen: " .. (f and string.format(
            "primary, %dx%d at %d,%d", f.w, f.h, f.x, f.y) or "none found")
        if dh.pos then
            out[#out + 1] = string.format(
                "  the spot: %d,%d — CAPTURED from a drag; _G.dialogHome.reset() forgets it",
                dh.pos.x, dh.pos.y)
        else
            out[#out + 1] = "  the spot: centred, a little high, on the primary screen (default)"
        end
        if dh.last then
            out[#out + 1] = string.format(
                "  last window seen: %s [%s] %q at %s — %s",
                tostring(dh.last.app), tostring(dh.last.subrole),
                tostring(dh.last.title or ""), tostring(dh.last.when),
                tostring(dh.last.outcome))
            out[#out + 1] = "  (not a dialog you expected to move? its subrole is"
            out[#out + 1] = "   right there — add it to dh.subroles in the EDIT HERE)"
        else
            out[#out + 1] = "  no dialog seen yet this session"
        end
        local refusedNames = {}
        for n in pairs(dh.refused) do refusedNames[#refusedNames + 1] = n end
        table.sort(refusedNames)
        if #refusedNames > 0 then
            out[#out + 1] = "  apps refusing a watcher: " .. table.concat(refusedNames, ", ")
        end
        return table.concat(out, "\n")
    end

    -- ---- wiring -----------------------------------------------------------
    if not dh.enabled then
        _G.dialogHome = dh
        M.config = dh
        return
    end

    if not axOK then
        -- Stand down completely, and say what that costs — the same
        -- honesty Window Return and Window Pin practise.
        _G.dialogs = function() print(dh.status()) end
        if _G.notices then
            _G.notices.record("dialogHome", "Accessibility off",
                              "dialogs cannot be moved to the spot")
        end
        say("Accessibility is off — nothing started")
        _G.dialogHome = dh
        M.config = dh
        return
    end

    local okW, w = pcall(hs.application.watcher.new, function(_, eventType, app)
        if eventType == hs.application.watcher.activated then
            local ok, err = pcall(dh.attach, app)
            if not ok then warn("attach: " .. tostring(err)) end
        end
    end)
    if okW and w then
        dh.appWatcher = w
        pcall(function() w:start() end)
    else
        warn("hs.application.watcher failed — dialogs will not be placed")
    end

    -- Whatever is frontmost RIGHT NOW, not just the next switch.
    pcall(function()
        local app = hs.application.frontmostApplication()
        if app then dh.attach(app) end
    end)

    _G.dialogHome = dh
    _G.dialogs    = function() print(dh.status()) end
    M.config      = dh
end

return M
