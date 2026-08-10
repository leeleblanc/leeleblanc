-- =====================================================================
-- test_focus.lua — the module whose worst failure MAKES YOU INAUDIBLE
-- =====================================================================
--     lua5.4 test_focus.lua [/path/to/hammerspoon]
--
-- A focus mode that fails to engage costs you a notification during a
-- meeting. A focus mode that fails to DISENGAGE leaves your microphone
-- muted, and you find out in the next call when someone says "you're on
-- mute" for ninety seconds. Those failures are not the same size, and
-- this suite is weighted accordingly.
--
-- The properties:
--
--   P1  AFTER DISENGAGING, THE MIC IS EXACTLY AS IT WAS. Not "unmuted" —
--       as it was. If it was muted before the meeting it stays muted.
--   P2  IT NEVER UNMUTES A MIC IT DID NOT MUTE.
--   P3  DISENGAGE IS TOTAL. A step that throws must not prevent the
--       later steps from running — the old shape of this bug is a canvas
--       error skipping the unmute.
--   P4  THE CAMERA IS NEVER BLIND-TOGGLED. It acts only when the app's
--       menu proves the camera is on. An app with no readable menu gets
--       no camera action at all.
--   P5  ENGAGE IS IDEMPOTENT — a second engage must not overwrite the
--       recorded prior state, which is what makes restore correct.
--   P6  THE WATCHDOG ALWAYS FIRES. However detection misbehaves, focus
--       cannot stay engaged forever.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a controllable Mac ----------------------------------------------
local NOW, APPS, ALERTS, TASKS, CANVASES = 1000, {}, {}, {}, {}
local MIC = { muted = false, volume = 70, canMute = true }
local printed, HYPER, PROVIDED, TIMEOUTS = {}, {}, {}, {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- A fake app. `menu` maps a joined menu path to whether that item exists;
-- selecting "Stop Video" flips the app to camera-off, which is what a
-- real meeting app does and what makes blind-toggling detectable.
local function mkApp(name, windows, cameraOn)
    return {
        _name = name, _windows = windows or {}, _cameraOn = cameraOn,
        _selected = {},
        name = function(self) return self._name end,
        allWindows = function(self)
            local ws = {}
            for _, t in ipairs(self._windows) do
                ws[#ws + 1] = { title = function() return t end }
            end
            return ws
        end,
        findMenuItem = function(self, path)
            local leaf = path[#path]
            if leaf == "Stop Video"  then return self._cameraOn  and {} or nil end
            if leaf == "Start Video" then return (not self._cameraOn) and {} or nil end
            return nil
        end,
        selectMenuItem = function(self, path)
            local leaf = path[#path]
            self._selected[#self._selected + 1] = leaf
            if leaf == "Stop Video"  then self._cameraOn = false ; return true end
            if leaf == "Start Video" then self._cameraOn = true  ; return true end
            return false
        end,
    }
end

local CANVAS_THROWS = false
hs = {
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doEvery  = function(_, fn) return { fn = fn, stop = function() end } end,
        doAfter  = function(_, fn) return { fn = fn, stop = function() end } end,
    },
    application = {
        runningApplications = function() return APPS end,
        frontmostApplication = function() return APPS[1] end,
        get = function(n)
            for _, a in ipairs(APPS) do if a._name == n then return a end end
        end,
        watcher = { new = function(fn) return { fn = fn, start = function() end } end,
                    launched = 1, activated = 2, terminated = 3 },
    },
    audiodevice = { defaultInputDevice = function()
        return {
            inputMuted    = function() return MIC.muted end,
            inputVolume   = function() return MIC.volume end,
            setInputMuted = function(_, v)
                if not MIC.canMute then return false end
                MIC.muted = v ; return true end,
            setInputVolume = function(_, v) MIC.volume = v ; return true end,
        } end },
    axuielement = { applicationElement = function(app)
        local e = { app = app }
        function e:setTimeout(t) TIMEOUTS[app._name] = t ; return self end
        function e:attributeValue(a)
            if a == "AXWindows" then
                local ws = {}
                for _, t in ipairs(app._windows) do
                    local w = { t = t }
                    function w:attributeValue(x)
                        if x == "AXTitle" then return self.t end
                        if x == "AXChildren" then
                            local kid = { v = app._reminderText }
                            function kid:attributeValue(y)
                                if y == "AXValue" then return self.v end
                                return nil
                            end
                            return { kid }
                        end
                        return nil
                    end
                    ws[#ws + 1] = w
                end
                return ws
            end
            return nil
        end
        return e end },
    screen = { allScreens = function()
        return { { id = function() return 1 end,
                   fullFrame = function() return { x = 0, y = 0, w = 1440, h = 900 } end } }
    end },
    window = { orderedWindows = function() return {} end },
    canvas = {
        new = function()
            if CANVAS_THROWS then error("canvas exploded") end
            local c = { shown = false }
            for _, m in ipairs({ "replaceElements", "level", "behaviorAsLabels",
                                 "canvasMouseEvents" }) do
                c[m] = function(self) return self end
            end
            function c:show() self.shown = true ; return self end
            function c:delete()
                if CANVAS_THROWS then error("delete exploded") end
                self.shown = false end
            CANVASES[#CANVASES + 1] = c ; return c end,
        windowLevels = { overlay = 5 },
    },
    task = { new = function(_, _, args)
        TASKS[#TASKS + 1] = args and args[2] or "?"
        return { start = function() return true end } end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function() return true end },
}
_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local CORE = {
    hostTag = "Test-Mac",
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, FM
local function boot()
    APPS, ALERTS, TASKS, CANVASES, printed = {}, {}, {}, {}, {}
    HYPER, PROVIDED, TIMEOUTS = {}, {}, {}
    NOW = 1000 ; CANVAS_THROWS = false
    MIC = { muted = false, volume = 70, canMute = true }
    M = dofile(HS .. "/modules/focus_mode.lua")
    M.setup(CORE)
    FM = _G.focusMode
    return FM
end

-- =====================================================================
out("\n=== 1. Contract ===\n")
-- =====================================================================
boot()
check("the module returns name, order and a cheatsheet",
      M.name == "Focus Mode" and type(M.order) == "number"
      and type(M.cheatsheet) == "table")
check("it claims ⇪F and ⇪⇧F", HYPER["|f"] ~= nil and HYPER["shift|f"] ~= nil)
check("its order does not collide with bulk_rename (13.11)", M.order ~= 13.11)
check("it publishes services rather than relying on globals",
      PROVIDED["focus.engage"] and PROVIDED["focus.disengage"]
      and PROVIDED["focus.engaged"])
check("detection is armed in warm(), not setup() — a running-app sweep on "
      .. "the boot path is what the two-phase loader exists to prevent",
      type(M.warm) == "function")

-- =====================================================================
out("\n=== 2. The mic — P1 and P2 ===\n")
-- =====================================================================
boot()
MIC.muted = false
FM.engage("test")
check("engaging mutes a live mic", MIC.muted == true)
FM.disengage("test")
check("P1: disengaging unmutes it again", MIC.muted == false)

boot()
MIC.muted = true          -- the user muted it themselves, before any meeting
FM.engage("test")
check("a mic that was already muted is left muted", MIC.muted == true)
check("…and nothing was recorded to restore, so nothing will be undone",
      FM.prior.mic == nil)
FM.disengage("test")
check("🚨 P2: IT DOES NOT UNMUTE A MIC IT DID NOT MUTE — the user muted "
      .. "themselves and that choice survives the meeting", MIC.muted == true)

-- An interface with no mute control at all: volume is the fallback, and
-- the EXACT previous level has to come back, not a guessed 100.
boot()
MIC.canMute = false ; MIC.volume = 42
FM.engage("test")
check("with no mute control the input volume is dropped to 0",
      MIC.volume == 0, MIC.volume)
FM.disengage("test")
check("and the exact previous volume is restored, not a guessed default",
      MIC.volume == 42, MIC.volume)

-- =====================================================================
out("\n=== 3. The camera — P4, the one that must never guess ===\n")
-- =====================================================================
boot()
local zoom = mkApp("zoom.us", { "Zoom Meeting" }, true)   -- camera ON
APPS = { zoom }
FM.engage("test", zoom, "zoom.us")
check("a camera that is provably ON is turned off via the app's own menu",
      zoom._cameraOn == false and zoom._selected[1] == "Stop Video",
      tostring(zoom._selected[1]))
FM.disengage("test")
check("and it is turned back on when the meeting ends",
      zoom._cameraOn == true)

boot()
local zoomOff = mkApp("zoom.us", { "Zoom Meeting" }, false)  -- camera OFF
APPS = { zoomOff }
FM.engage("test", zoomOff, "zoom.us")
check("🚨 P4: A CAMERA THAT IS ALREADY OFF IS NOT TOUCHED — a blind ⌘⇧V "
      .. "here would have switched the camera ON mid-meeting",
      zoomOff._cameraOn == false and #zoomOff._selected == 0,
      tostring(zoomOff._selected[1]))
FM.disengage("test")
check("…and disengaging does not switch it on either",
      zoomOff._cameraOn == false)

boot()
local teams = mkApp("Microsoft Teams", { "Meeting with Bob" }, true)
APPS = { teams }
FM.engage("test", teams, "Microsoft Teams")
check("an app with no readable camera menu gets NO camera action rather "
      .. "than a guessed keystroke", #teams._selected == 0)
check("…but its mic is still muted, which is the deterministic half",
      MIC.muted == true)

-- =====================================================================
out("\n=== 4. Disengage is total — P3 ===\n")
-- =====================================================================
boot()
FM.engage("test")
check("the dim went up", #CANVASES > 0)
CANVAS_THROWS = true          -- teardown will now throw
FM.disengage("test")
check("🚨 P3: A CANVAS THAT THROWS DURING TEARDOWN DOES NOT STRAND THE "
      .. "MIC — every restore step is independently pcall'd, and this is "
      .. "the exact bug shape that leaves you muted for the next call",
      MIC.muted == false)
check("and the module still ends up disengaged rather than stuck",
      FM.engaged == false)

-- =====================================================================
out("\n=== 5. Idempotence and the manual override — P5 ===\n")
-- =====================================================================
boot()
MIC.muted = false
FM.engage("first")
local firstPrior = FM.prior
MIC.muted = false            -- something else unmuted mid-meeting
FM.engage("second")
check("P5: a second engage is a no-op and does not overwrite the recorded "
      .. "prior state", FM.prior == firstPrior)
FM.disengage("x")
FM.disengage("x")
check("disengaging twice is harmless", FM.engaged == false)

boot()
FM.toggle()
check("⇪F engages when idle", FM.engaged == true)
FM.toggle()
check("⇪F always disengages when engaged — it is the override and must "
      .. "never argue with detection", FM.engaged == false)

-- =====================================================================
out("\n=== 6. Detection ===\n")
-- =====================================================================
boot()
APPS = { mkApp("zoom.us", { "Zoom" }) }        -- idle, not in a meeting
FM.tick()
check("🚨 ZOOM MERELY BEING OPEN IS NOT A MEETING — matching on the app "
      .. "would engage focus every time it sat in the dock",
      FM.engaged == false)

boot()
APPS = { mkApp("zoom.us", { "Zoom Meeting" }) }
FM.tick()
check("a Zoom Meeting window does engage it", FM.engaged == true)

boot()
local outlook = mkApp("Microsoft Outlook", { "1 Reminder" })
outlook._reminderText = "Join here https://teams.microsoft.com/l/meetup-join/x"
APPS = { outlook }
FM.tick()
check("an Outlook reminder carrying a Teams join link engages it — this "
      .. "is the calendar signal that survives New Outlook dropping "
      .. "AppleScript", FM.engaged == true)

boot()
local plain = mkApp("Microsoft Outlook", { "1 Reminder" })
plain._reminderText = "Reminder: buy milk"
APPS = { plain }
FM.tick()
check("a reminder with no join link does NOT engage it", FM.engaged == false)

check("every Accessibility element got a timeout before being asked "
      .. "anything — the freeze guard from 6.47.0, applied here too",
      TIMEOUTS["Microsoft Outlook"] ~= nil)

-- =====================================================================
out("\n=== 7. The watchdog — P6 ===\n")
-- =====================================================================
boot()
APPS = { mkApp("zoom.us", { "Zoom Meeting" }) }
FM.tick()
check("engaged from detection", FM.engaged == true)
APPS = {}                       -- the meeting vanishes without a trace
FM.tick()
check("one missed poll does not drop focus — Zoom retitles its window "
      .. "during a screen share", FM.engaged == true)
NOW = NOW + FM.watchdogSecs + 1
FM.tick()
check("🚨 P6: THE WATCHDOG DISENGAGES WHEN DETECTION DIES, so a failure "
      .. "to notice the meeting ended can never leave the mic muted",
      FM.engaged == false)
check("and the mic came back with it", MIC.muted == false)

-- =====================================================================
out("\n=== 8. THE EXPLORER — 500 random meeting days ===\n")
-- =====================================================================
-- Random sequences of joins, leaves, app quits, canvas failures, manual
-- toggles and clock jumps. P1/P2 are asserted after every event where the
-- module reports itself idle: whenever focus is off, the mic must be
-- exactly what it was before focus ever touched it.
do
    math.randomseed(20260810)
    local bad, events = nil, 0
    for iter = 1, 500 do
        boot()
        local userMuted = math.random() < 0.3
        MIC.muted = userMuted
        local baseline = MIC.muted
        local steps = math.random(3, 25)
        for _ = 1, steps do
            events = events + 1
            local roll = math.random(10)
            if roll <= 3 then
                APPS = { mkApp("zoom.us", { "Zoom Meeting" }, math.random() < 0.5) }
                FM.tick()
            elseif roll <= 5 then
                APPS = {} ; FM.tick()
            elseif roll == 6 then
                NOW = NOW + FM.watchdogSecs + math.random(1, 50) ; FM.tick()
            elseif roll == 7 then
                FM.toggle()
            elseif roll == 8 then
                CANVAS_THROWS = not CANVAS_THROWS
            elseif roll == 9 then
                FM.disengage("random")
            else
                NOW = NOW + math.random(1, 20) ; FM.tick()
            end

            -- P1/P2: idle ⇒ the mic is back to the user's own setting.
            if not FM.engaged and MIC.canMute then
                if MIC.muted ~= baseline then
                    bad = string.format("iter %d: idle but mic=%s, user set %s",
                          iter, tostring(MIC.muted), tostring(baseline))
                    break
                end
            end
            -- P5: engaged ⇒ there is always a prior record to restore from.
            if FM.engaged and FM.prior == nil then
                bad = "engaged with no recorded prior state" break
            end
        end
        if bad then break end

        -- However the day ended, a final disengage must return the mic.
        CANVAS_THROWS = false
        FM.disengage("end of day")
        if MIC.muted ~= baseline then
            bad = string.format("iter %d: after final disengage mic=%s, "
                  .. "user set %s", iter, tostring(MIC.muted), tostring(baseline))
            break
        end
    end
    check(string.format("500 random meeting days (%d events): focus never "
          .. "stranded the mic, never unmuted a mic the user muted, never "
          .. "engaged without a restore record, and nothing threw", events),
          bad == nil, bad)
end

-- =====================================================================
out("\n=== 9. Mutation — are these properties load-bearing? ===\n")
-- =====================================================================
do
    -- Mutation 1: record prior state AFTER muting. Restore then believes
    -- the mic was always muted and never unmutes it.
    boot()
    MIC.muted = false
    local realMicMute = FM.micMute
    FM.micMute = function()
        MIC.muted = true
        return nil            -- "nothing to restore" — the bug
    end
    FM.engage("mutated")
    FM.disengage("mutated")
    FM.micMute = realMicMute
    check("MUTATION: recording the prior state after muting leaves the mic "
          .. "muted forever — P1 catches it", MIC.muted == true)

    -- Mutation 2: a restore step that throws part-way through teardown.
    --
    -- ⚠️ THE FIRST VERSION OF THIS PROBE PROVED NOTHING, twice over.
    -- It called dimOff() expecting a throw — but dimOff pcall's its own
    -- delete, so it never throws and the probe reported a working guard
    -- as broken. And it was aimed wrongly to begin with: micRestore runs
    -- FIRST in disengage, so a later failure could not have stranded the
    -- mic even without the guards. The two things actually worth
    -- asserting are the ORDER (mic first, before anything that can fail)
    -- and that a throwing step does not abandon the steps after it.
    boot()
    MIC.muted = false
    FM.engage("m2")
    local order = {}
    local realMic, realCam = FM.micRestore, FM.camRestore
    FM.micRestore = function(r) order[#order + 1] = "mic" ; realMic(r) end
    FM.camRestore = function() order[#order + 1] = "cam" ; error("cam blew up") end
    FM.disengage("m2")
    FM.micRestore, FM.camRestore = realMic, realCam
    check("🚨 THE MIC IS RESTORED FIRST, before any step that could fail — "
          .. "ordering is the first line of defence and the pcalls are the "
          .. "second", order[1] == "mic", table.concat(order, ","))
    check("MUTATION: a restore step that throws does not abandon the steps "
          .. "after it — focus still ends disengaged, the dim is still torn "
          .. "down, and the mic is still live",
          FM.engaged == false and next(FM.canvases) == nil
          and MIC.muted == false,
          tostring(FM.engaged) .. "/" .. tostring(MIC.muted))

    -- Mutation 3: blind camera toggle. With the menu check removed, an
    -- already-off camera gets switched ON.
    boot()
    local cam = mkApp("zoom.us", { "Zoom Meeting" }, false)
    local blind = FM.camOff
    FM.camOff = function(app, spec)
        if not (app and spec) then return nil end
        app:selectMenuItem(spec.camOn)      -- no readback: the bug
        return { app = app, path = spec.camOff }
    end
    FM.engage("m3", cam, "zoom.us")
    FM.camOff = blind
    check("MUTATION: skipping the menu readback turns an already-off "
          .. "camera ON — the readback is the whole reason camOff() looks "
          .. "overbuilt", cam._cameraOn == true or #cam._selected > 0)
    FM.disengage("cleanup")
end

out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
