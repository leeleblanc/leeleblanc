-- =====================================================================
-- MODULE: FOCUS MODE (⇪F) — the Mac gets out of the way when you join
-- =====================================================================
-- When a meeting starts: the mic goes muted, the camera is turned off
-- ONLY if it is provably on, notifications go quiet, and every app that
-- is not the meeting gets dimmed. When the meeting ends, every one of
-- those is put back — and only the ones this module actually changed.
--
-- ⇪F toggles it by hand. ⇪⇧F prints what it detected and what it did.
--
-- ---------------------------------------------------------------------
-- 🚨 THE FAILURE THAT MATTERS HERE IS "MIC LEFT MUTED AFTER THE MEETING"
-- ---------------------------------------------------------------------
-- Every other bug in this file is cosmetic. That one makes you inaudible
-- in the NEXT call, and you will not find out until someone tells you.
-- So the design is built around restoring, not around detecting:
--
--   · PRIOR STATE IS RECORDED BEFORE ANY CHANGE, and restore replays
--     only what was recorded. If the mic was already muted when the
--     meeting started, leaving is a no-op — this module will not unmute
--     a mic it did not mute.
--   · A WATCHDOG runs even when detection has failed. If focus is
--     engaged and no meeting app has had a meeting window for
--     fm.watchdogSecs, it disengages on its own.
--   · DISENGAGING IS UNCONDITIONAL AND IDEMPOTENT. Every step is
--     pcall'd separately, so one failing step cannot strand the rest —
--     the old shape of this bug is a canvas error skipping the unmute.
--   · ⇪F ALWAYS DISENGAGES when engaged, whatever detection thinks.
--     That is the manual override, and it is why the toggle exists.
--
-- ---------------------------------------------------------------------
-- ⚠️ WHAT THIS CANNOT DO, STATED PLAINLY
-- ---------------------------------------------------------------------
--   · IT CANNOT DISABLE YOUR CAMERA. macOS has no API for one process
--     to revoke another's camera access. What it can do is drive the
--     meeting app's OWN camera control — and it only does that when it
--     can first READ that the camera is on, by inspecting the app's menu
--     bar. Firing ⌘⇧V blindly is a coin flip that turns the camera ON
--     half the time, which is worse than doing nothing. See camOff().
--   · IT CANNOT READ NEW OUTLOOK'S CALENDAR. Classic Outlook had
--     AppleScript; the rewritten Outlook largely dropped it. Rather than
--     ship something that works on one build and silently fails on the
--     next, calendar detection here reads the REMINDER WINDOW — which is
--     what you actually see when a meeting is about to start, and which
--     works on both builds. See scanOutlookReminder().
--   · IT CANNOT MUTE SLACK SPECIFICALLY without a Slack token. What
--     silences Slack reliably is a macOS Focus, which silences
--     everything — and that is what "disable notifications during a
--     meeting" means in practice. See quietOn().
--
-- ---------------------------------------------------------------------
-- ⚠️ AND IT MUST NOT FREEZE THE KEYBOARD
-- ---------------------------------------------------------------------
-- This module reads other apps' Accessibility trees, which is a
-- SYNCHRONOUS call into a possibly-wedged app — the exact thing that
-- froze ⌥Tab in 6.33.0 and that menubar_items was built to avoid in
-- 6.47.0. Same rule applies and is applied the same way: every element
-- gets an explicit timeout BEFORE it is asked anything, and the whole
-- scan is time-boxed. Shortcuts run through hs.task, never hs.execute,
-- so a hung `shortcuts` binary cannot take the main thread with it.

local M = {
    name  = "Focus Mode",
    -- 🚨 14.0, NOT 13.10. In Lua 13.10 == 13.1, and 13.1 is Capture Pad —
    -- so the "next number after 13.9" that a human reaches for is a
    -- silent tie, and a tie makes the cheat sheet's running order depend
    -- on table iteration. The integration suite caught exactly this.
    order = 14.0,
    cheatsheet = {
        title = "🎯 FOCUS MODE (⇪F — the Mac steps back when you join)",
        entries = {
            { "⇪F",    "Toggle focus by hand — always disengages if engaged" },
            { "⇪⇧F",   "What it detected, what it changed, what it will restore" },
            { "auto",  "Engages on a Zoom/Teams meeting window, or an Outlook" },
            { "",      "reminder carrying a join link" },
            { "does",  "Mutes mic · camera off IF provably on · Focus on · dims" },
            { "",      "every app that is not the meeting" },
            { "safe",  "Restores ONLY what it changed. Watchdog disengages if" },
            { "",      "detection dies, so the mic never stays muted." },
            { "can't", "Cannot revoke camera access — no macOS API. It drives" },
            { "",      "the meeting app's own control, and only when readable." },
        },
    },
}

function M.setup(core)
    local fm = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    fm.enabled       = true
    fm.key           = "f"        -- ⇪F toggle · ⇪⇧F report
    fm.auto          = true       -- false = ⇪F only, no detection at all
    fm.pollSecs      = 4          -- how often detection looks
    fm.watchdogSecs  = 90         -- engaged with no meeting seen this long → leave
    fm.axTimeout     = 0.10       -- 🚨 per-app Accessibility timeout. Freeze guard.
    fm.scanBudget    = 1.0        -- hard stop for one detection sweep, seconds

    fm.doMuteMic     = true
    fm.doCameraOff   = true       -- only ever acts when the state is READABLE
    fm.doQuiet       = true       -- macOS Focus via a Shortcut, see below
    fm.doDim         = true

    -- The Shortcut that turns your Focus on and off. Create two Shortcuts
    -- in the Shortcuts app (Set Focus → Do Not Disturb → On / Off) and put
    -- their exact names here. Leave either empty to skip that half.
    -- This is the only reliable way to drive Focus from a script: there is
    -- no public API, and the old `defaults write … doNotDisturb` trick has
    -- not worked since Monterey.
    fm.focusOnShortcut  = "Meeting Focus On"
    fm.focusOffShortcut = "Meeting Focus Off"

    fm.dimAlpha      = 0.55       -- how hard non-critical apps are dimmed
    fm.dimWhite      = 0.00       -- 0 = black. 1 = white-out, if you prefer

    -- Never dimmed. The meeting app is added automatically; these are the
    -- ones you still want fully legible while the meeting runs.
    fm.criticalApps  = {
        ["zoom.us"] = true, ["Microsoft Teams"] = true,
        ["Microsoft Teams (work or school)"] = true, ["MSTeams"] = true,
        ["Microsoft Outlook"] = true, ["Notes"] = true, ["Hammerspoon"] = true,
    }

    -- 🚨 HOW A MEETING IS RECOGNISED. windowPatterns are Lua patterns
    -- matched against WINDOW TITLES — an app merely being open is not a
    -- meeting, and matching on the app alone would engage focus every time
    -- Zoom sat idle in the dock. The menu paths are how camera state is
    -- READ rather than guessed; an app with no readable menu simply gets
    -- no camera action, which is the honest outcome.
    fm.meetingApps = {
        ["zoom.us"] = {
            windowPatterns = { "^Zoom Meeting", "^Zoom Webinar" },
            camOn  = { "Meeting", "Stop Video" },   -- present ⇒ camera is ON
            camOff = { "Meeting", "Start Video" },  -- present ⇒ camera is OFF
        },
        ["Microsoft Teams"] = {
            windowPatterns = { "Meeting", "Call with", "| Microsoft Teams$" },
            -- Teams exposes no reliable camera menu item. Deliberately no
            -- camOn/camOff: the system mic mute still applies, and the
            -- camera is left alone rather than blind-toggled.
        },
        ["Microsoft Teams (work or school)"] = {
            windowPatterns = { "Meeting", "Call with" },
        },
    }

    -- Join links that mark an Outlook reminder as a real meeting.
    fm.joinLinkPatterns = {
        "zoom%.us/j/", "zoom%.us/w/", "teams%.microsoft%.com/l/meetup%-join",
        "teams%.live%.com/meet", "meet%.google%.com/",
    }
    -- ----------------------------------------------------------------------

    fm.engaged      = false
    fm.prior        = nil     -- what we changed, and what it was before
    fm.lastSeenAt   = 0       -- last time a meeting was positively detected
    fm.lastReason   = "—"
    fm.canvases     = {}      -- screen id -> hs.canvas. HELD: an unreferenced
                              -- canvas is collected and the dim vanishes.
    fm.timer        = nil     -- HELD: an unreferenced hs.timer is collected.
    fm.appWatcher   = nil     -- HELD: likewise.
    fm.warnedQuiet  = false
    fm.log          = {}      -- last few transitions, for ⇪⇧F

    local function say(m)  if _G.diag then _G.diag.say("focus", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("focus", m) end end
    local function now()   return hs.timer.secondsSinceEpoch() end

    local function note(m)
        fm.log[#fm.log + 1] = os.date("%H:%M:%S ") .. m
        while #fm.log > 12 do table.remove(fm.log, 1) end
        say(m)
    end

    -- ---- reading Accessibility, defensively ------------------------------
    local function attr(el, name)
        if not el then return nil end
        local ok, v = pcall(function() return el:attributeValue(name) end)
        if ok then return v end
        return nil
    end

    -- ⚠️ THE TIMEOUT IS SET BEFORE THE ELEMENT IS ASKED ANYTHING. Same rule
    -- as menubar_items.lua, same reason: this is the line between a wedged
    -- app and a frozen keyboard, and it only works if it comes first.
    local function appElement(app)
        local ok, el = pcall(hs.axuielement.applicationElement, app)
        if not ok or not el then return nil end
        pcall(function() el:setTimeout(fm.axTimeout) end)
        return el
    end

    -- ---- detection: is a meeting happening? -------------------------------
    -- Returns appObject, reason  — or nil.
    function fm.detectMeetingWindow()
        local t0 = now()
        local okApps, apps = pcall(hs.application.runningApplications)
        if not okApps or not apps then return nil end
        for _, app in ipairs(apps) do
            -- Budget checked EVERY iteration, not at the end. A partial
            -- sweep is strictly better than holding the keyboard.
            if now() - t0 > fm.scanBudget then
                warn("detection budget exhausted")
                return nil
            end
            local name = "?"
            pcall(function() name = app:name() or "?" end)
            local spec = fm.meetingApps[name]
            if spec then
                local okW, wins = pcall(function() return app:allWindows() end)
                for _, w in ipairs((okW and wins) or {}) do
                    local title = ""
                    pcall(function() title = w:title() or "" end)
                    for _, pat in ipairs(spec.windowPatterns or {}) do
                        if title ~= "" and title:find(pat) then
                            return app, name .. ": " .. title
                        end
                    end
                end
            end
        end
        return nil
    end

    -- The Outlook reminder popup. This is the signal the calendar cannot
    -- give us reliably any more, and it is arguably the better one: a
    -- reminder carrying a join link means a meeting is about to start,
    -- which is exactly when you want the Mac to settle down.
    function fm.scanOutlookReminder()
        local app = hs.application.get("Microsoft Outlook")
        if not app then return nil end
        local el = appElement(app)
        if not el then return nil end
        local t0 = now()
        for _, win in ipairs(attr(el, "AXWindows") or {}) do
            if now() - t0 > fm.scanBudget then return nil end
            local title = tostring(attr(win, "AXTitle") or "")
            if title:lower():find("reminder") then
                -- Walk one level of children looking for a join link. One
                -- level is deliberate: a full recursive walk of an Outlook
                -- window is exactly the unbounded synchronous traversal
                -- this file exists to avoid.
                local blob = title
                for _, kid in ipairs(attr(win, "AXChildren") or {}) do
                    if now() - t0 > fm.scanBudget then break end
                    blob = blob .. " " .. tostring(attr(kid, "AXValue") or "")
                                 .. " " .. tostring(attr(kid, "AXTitle") or "")
                                 .. " " .. tostring(attr(kid, "AXURL")   or "")
                end
                for _, pat in ipairs(fm.joinLinkPatterns) do
                    if blob:lower():find(pat) then
                        return "Outlook reminder with a join link"
                    end
                end
            end
        end
        return nil
    end

    -- ---- the individual actions ------------------------------------------
    -- Each returns what it changed, so restore can be exact.

    function fm.micMute()
        local dev = nil
        pcall(function() dev = hs.audiodevice.defaultInputDevice() end)
        if not dev then return nil end
        local wasMuted, wasVol
        pcall(function() wasMuted = dev:inputMuted() end)
        pcall(function() wasVol   = dev:inputVolume() end)
        -- Already muted ⇒ record nothing. This single line is what stops
        -- the module ever unmuting a mic the user muted themselves.
        if wasMuted == true then return nil end
        local ok = false
        pcall(function() ok = dev:setInputMuted(true) end)
        if ok ~= true then
            -- Some interfaces report no mute control at all. Volume 0 is
            -- the fallback, and it is recorded separately so restore puts
            -- the exact previous level back rather than guessing 100.
            if type(wasVol) == "number" then
                pcall(function() dev:setInputVolume(0) end)
                return { kind = "vol", vol = wasVol }
            end
            return nil
        end
        return { kind = "mute" }
    end

    function fm.micRestore(rec)
        if not rec then return end
        local dev = nil
        pcall(function() dev = hs.audiodevice.defaultInputDevice() end)
        if not dev then return end
        if rec.kind == "mute" then
            pcall(function() dev:setInputMuted(false) end)
        elseif rec.kind == "vol" then
            pcall(function() dev:setInputVolume(rec.vol) end)
        end
    end

    -- 🚨 THE CAMERA, AND WHY THIS LOOKS OVERBUILT.
    -- There is no API to turn another app's camera off. The meeting app's
    -- own menu is the only thing that both READS and SETS the state, and
    -- reading first is the entire point: if "Stop Video" exists the camera
    -- is on, so clicking it turns the camera off — deterministically. If
    -- only "Start Video" exists the camera is already off and we do
    -- NOTHING. A blind ⌘⇧V would have turned it on.
    function fm.camOff(app, spec)
        if not (app and spec and spec.camOn) then return nil end
        local item = nil
        pcall(function() item = app:findMenuItem(spec.camOn) end)
        if not item then return nil end          -- camera already off, or unreadable
        local ok = false
        pcall(function() ok = app:selectMenuItem(spec.camOn) end)
        if ok then return { app = app, path = spec.camOff } end
        return nil
    end

    function fm.camRestore(rec)
        if not (rec and rec.app and rec.path) then return end
        -- Symmetrically: only restore if the app now offers "Start Video",
        -- i.e. the camera is still off. If the user turned it back on
        -- mid-meeting, leave their choice alone.
        local item = nil
        pcall(function() item = rec.app:findMenuItem(rec.path) end)
        if item then pcall(function() rec.app:selectMenuItem(rec.path) end) end
    end

    -- macOS Focus, via Shortcuts. Run through hs.task — NOT hs.execute —
    -- because hs.execute blocks the main thread, and the main thread is
    -- your keyboard. A `shortcuts` binary that hangs must cost nothing.
    local function runShortcut(name)
        if not name or name == "" then return false end
        local ok = pcall(function()
            hs.task.new("/usr/bin/shortcuts", nil, { "run", name }):start()
        end)
        return ok
    end

    function fm.quietOn()
        if fm.focusOnShortcut == "" and fm.focusOffShortcut == "" then
            if not fm.warnedQuiet then
                fm.warnedQuiet = true
                print("🎯 Focus Mode: no Shortcut names set, so notifications "
                      .. "are NOT being silenced. Create two Shortcuts (Set "
                      .. "Focus → On / Off) and put their names in "
                      .. "fm.focusOnShortcut / fm.focusOffShortcut.")
            end
            return nil
        end
        if runShortcut(fm.focusOnShortcut) then return { on = true } end
        return nil
    end

    function fm.quietRestore(rec)
        if rec and rec.on then runShortcut(fm.focusOffShortcut) end
    end

    -- ---- dimming ---------------------------------------------------------
    -- A translucent sheet per screen, with a HOLE punched over every
    -- critical window. The hole is a second element drawn with
    -- compositeRule "clear", which erases what the first element painted —
    -- that is how you dim everything EXCEPT something, with one canvas.
    function fm.dimOn(meetingAppName)
        fm.dimOff()
        if not fm.doDim then return nil end
        local critical = {}
        for k, v in pairs(fm.criticalApps) do critical[k] = v end
        if meetingAppName then critical[meetingAppName] = true end

        -- Collect the frames that must stay legible, before drawing.
        local holes = {}
        local okWins, wins = pcall(hs.window.orderedWindows)
        for _, w in ipairs((okWins and wins) or {}) do
            local ok, appName = pcall(function() return w:application():name() end)
            if ok and appName and critical[appName] then
                local okF, f = pcall(function() return w:frame() end)
                if okF and f then holes[#holes + 1] = f end
            end
        end

        for _, scr in ipairs(hs.screen.allScreens() or {}) do
            local okF, sf = pcall(function() return scr:fullFrame() end)
            if okF and sf then
                local okNew, c = pcall(hs.canvas.new, sf)
                if okNew and c then
                    local elems = { {
                        type = "rectangle", action = "fill",
                        fillColor = { white = fm.dimWhite, alpha = fm.dimAlpha },
                        frame = { x = 0, y = 0, w = sf.w, h = sf.h },
                    } }
                    for _, h in ipairs(holes) do
                        -- Canvas coordinates are relative to the canvas, so
                        -- the window frame is translated onto this screen.
                        elems[#elems + 1] = {
                            type = "rectangle", action = "fill",
                            fillColor = { white = 1, alpha = 1 },
                            compositeRule = "clear",
                            frame = { x = h.x - sf.x, y = h.y - sf.y,
                                      w = h.w, h = h.h },
                        }
                    end
                    pcall(function() c:replaceElements(elems) end)
                    local lvl = (hs.canvas.windowLevels or {}).overlay
                    pcall(function() c:level(lvl) end)
                    pcall(function()
                        c:behaviorAsLabels({ "canJoinAllSpaces", "stationary" })
                    end)
                    -- 🚨 CLICKS MUST PASS THROUGH. Without this the dim
                    -- becomes a sheet of glass over the whole Mac and the
                    -- meeting is the only thing you can use — which is not
                    -- "dimmed", it is "disabled".
                    pcall(function() c:canvasMouseEvents(false, false, false, false) end)
                    pcall(function() c:show() end)
                    fm.canvases[scr:id() or (#fm.canvases + 1)] = c
                end
            end
        end
        return { on = true }
    end

    function fm.dimOff()
        for id, c in pairs(fm.canvases) do
            pcall(function() c:delete() end)
            fm.canvases[id] = nil
        end
        fm.canvases = {}
    end

    -- ---- engage / disengage ----------------------------------------------
    function fm.engage(reason, app, appName)
        if fm.engaged then return end
        fm.engaged = true
        fm.lastReason = reason or "manual"
        fm.lastSeenAt = now()
        local spec = appName and fm.meetingApps[appName] or nil
        fm.prior = {
            mic   = fm.doMuteMic   and fm.micMute() or nil,
            cam   = fm.doCameraOff and fm.camOff(app, spec) or nil,
            quiet = fm.doQuiet     and fm.quietOn() or nil,
            dim   = fm.doDim       and fm.dimOn(appName) or nil,
        }
        local did = {}
        if fm.prior.mic   then did[#did + 1] = "mic muted"    end
        if fm.prior.cam   then did[#did + 1] = "camera off"   end
        if fm.prior.quiet then did[#did + 1] = "Focus on"     end
        if fm.prior.dim   then did[#did + 1] = "dimmed"       end
        note("engaged (" .. fm.lastReason .. ") — "
             .. (#did > 0 and table.concat(did, ", ") or "nothing to change"))
        hs.alert.show("🎯 Focus Mode\n" ..
            (#did > 0 and table.concat(did, " · ") or "already quiet"), 2)
    end

    -- 🚨 EVERY STEP IS INDEPENDENTLY pcall'd. The bug this prevents: an
    -- error in the dim teardown returning early and skipping the unmute,
    -- leaving the mic dead with no sign anything went wrong.
    function fm.disengage(why)
        if not fm.engaged then return end
        local p = fm.prior or {}
        pcall(function() fm.micRestore(p.mic)     end)
        pcall(function() fm.camRestore(p.cam)     end)
        pcall(function() fm.quietRestore(p.quiet) end)
        pcall(function() fm.dimOff()              end)
        fm.engaged, fm.prior = false, nil
        note("disengaged (" .. tostring(why or "manual") .. ")")
        hs.alert.show("🎯 Focus Mode off — everything restored", 1.5)
    end

    function fm.toggle()
        -- Deliberately asymmetric: engaging by hand needs no meeting, and
        -- disengaging by hand ignores detection entirely. ⇪F is the
        -- override, so it must never argue with you.
        if fm.engaged then fm.disengage("manual ⇪F")
        else fm.engage("manual ⇪F", hs.application.frontmostApplication(),
                       (function()
                           local n
                           pcall(function()
                               n = hs.application.frontmostApplication():name()
                           end)
                           return n
                       end)())
        end
    end

    -- ---- the detection tick ----------------------------------------------
    function fm.tick()
        if not fm.auto then return end
        local ok, err = pcall(function()
            local app, reason = fm.detectMeetingWindow()
            if app then
                fm.lastSeenAt = now()
                if not fm.engaged then
                    local n
                    pcall(function() n = app:name() end)
                    fm.engage(reason, app, n)
                end
                return
            end
            if not fm.engaged then
                local r = fm.scanOutlookReminder()
                if r then fm.engage(r, nil, nil) end
                return
            end
            -- Engaged, and no meeting window found. Give it the watchdog
            -- window before leaving: Zoom retitles its window during
            -- screen share, and a single missed poll must not drop focus.
            if now() - fm.lastSeenAt > fm.watchdogSecs then
                fm.disengage("watchdog: no meeting window for "
                             .. fm.watchdogSecs .. "s")
            end
        end)
        if not ok then warn("tick failed: " .. tostring(err)) end
    end

    -- ---- the report -------------------------------------------------------
    function _G.focusReport()
        local L = { string.format("🎯 FOCUS MODE on %s — %s",
                    tostring(core.hostTag), fm.engaged and "ENGAGED" or "idle") }
        L[#L + 1] = "   auto detection : " .. (fm.auto and "on" or "OFF")
        L[#L + 1] = "   last reason    : " .. tostring(fm.lastReason)
        if fm.engaged then
            local p = fm.prior or {}
            L[#L + 1] = "   will restore   : "
                .. (p.mic and "mic " or "") .. (p.cam and "camera " or "")
                .. (p.quiet and "Focus " or "") .. (p.dim and "dim" or "")
            L[#L + 1] = string.format("   watchdog in    : %.0fs",
                        math.max(0, fm.watchdogSecs - (now() - fm.lastSeenAt)))
        end
        local dev = nil
        pcall(function() dev = hs.audiodevice.defaultInputDevice() end)
        if dev then
            local m
            pcall(function() m = dev:inputMuted() end)
            L[#L + 1] = "   mic right now  : " .. (m == true and "MUTED" or "live")
        end
        if fm.focusOnShortcut == "" then
            L[#L + 1] = "   ⚠️ no Focus Shortcut set — notifications are NOT silenced"
        end
        L[#L + 1] = "   recent:"
        for _, l in ipairs(fm.log) do L[#L + 1] = "     " .. l end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- ---- wiring -----------------------------------------------------------
    if fm.enabled then
        core.hyperAddShortcut({}, fm.key, fm.toggle, "focus mode")
        core.hyperAddShortcut({ "shift" }, fm.key, function()
            local r = _G.focusReport()
            if r then
                pcall(function() hs.pasteboard.setContents(r) end)
                hs.alert.show("🎯 Focus report printed and copied", 2)
            end
        end, "focus mode report")
    end

    core.provide("focus.engage",    function(r) return fm.engage(r or "service") end)
    core.provide("focus.disengage", function()  return fm.disengage("service")   end)
    core.provide("focus.engaged",   function()  return fm.engaged                end)
    core.provide("focus.report",    function()  return _G.focusReport()          end)

    -- Detection starts in warm(), not setup(): a running-app sweep on the
    -- boot path is exactly the kind of expensive work the two-phase loader
    -- exists to keep off it.
    M.warm = function()
        if not (fm.enabled and fm.auto) then return end
        fm.timer = hs.timer.doEvery(fm.pollSecs, fm.tick)
        -- The app watcher makes joining feel instant; the poll is what
        -- makes LEAVING reliable. Both are needed — an app watcher never
        -- fires for "the meeting window changed title".
        local okW, w = pcall(hs.application.watcher.new, function(name, event)
            if event == hs.application.watcher.launched
               or event == hs.application.watcher.activated then
                if fm.meetingApps[name] then hs.timer.doAfter(1.0, fm.tick) end
            elseif event == hs.application.watcher.terminated then
                if fm.meetingApps[name] and fm.engaged then
                    fm.disengage("meeting app quit")
                end
            end
        end)
        if okW and w then fm.appWatcher = w; pcall(function() w:start() end) end
        say("detection armed, polling every " .. fm.pollSecs .. "s")
    end

    _G.focusMode = fm
    M.fm     = fm
    M.config = fm
end

return M
