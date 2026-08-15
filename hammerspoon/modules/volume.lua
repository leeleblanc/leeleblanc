-- =====================================================================
-- MODULE: VOLUME (⇪, ⇪. ⇪⇧, ⇪⇧.) — per-app volume, honestly labelled
-- =====================================================================
-- LL: "Control the volume on individual apps, how can I?"
--
-- 🚨 READ THIS FIRST, BECAUSE THE HONEST ANSWER IS THE FEATURE. macOS HAS
-- NO PER-APP OUTPUT VOLUME THAT LUA CAN REACH. CoreAudio volume is a
-- property of a DEVICE, not a process: every app's audio is mixed by
-- coreaudiod into one stream before it ever reaches the output, and
-- hs.audiodevice only ever touches the device.
--
-- ⚠️ CORRECTED IN 6.79.1, because the first version of this comment said
-- something that is no longer true and LL would have made a decision on
-- it. It said per-app mixing "means being an audio driver". That WAS the
-- only way — BackgroundMusic and SoundSource both install one — but since
-- macOS 14.2 there is a driverless route: CORE AUDIO PROCESS TAPS.
--     CATapDescription(stereoMixdownOfProcesses:) + muteBehavior
--     .mutedWhenTapped + isPrivate, AudioHardwareCreateProcessTap(),
--     then AudioHardwareCreateAggregateDevice() with the tap in its list
--     and an IO proc that multiplies the samples by your gain.
-- Intercept the process, mute its normal output, re-render with gain,
-- send it wherever you like. That is a real mixer, it needs only the
-- System Audio Recording permission — no kext, no admin, no install — and
-- it is why LL's Vorssaint can push one app past 100% while routing
-- another to a different device. See Sources/Vorssaint/Services/Audio/
-- AppVolumeMixer.swift in vorssaint/vorssaint-utils; it is GPL 3 and
-- readable.
--
-- 🚧 AND HAMMERSPOON CANNOT DO IT. There is no binding for
-- AudioHardwareCreateProcessTap in any hs.* extension, and none of this
-- is reachable from Lua — it would take a native helper. So this module
-- does the two things that ARE possible from here, and the point of the
-- paragraph above is that you should use Vorssaint if you want the real
-- thing. This is the zero-install approximation, not a rival.
--
-- So this module does the two things that ARE possible without installing
-- anything, and it never lets you confuse them:
--
--   🎯 APP    — for apps that expose their own volume, this is the real
--               thing. Music and Spotify are scriptable: their own mixer
--               moves, nothing else on the Mac changes, and two apps can
--               sit at different levels at the same time.
--   🌐 SYSTEM — for everything else, the SYSTEM volume is moved and the
--               level is REMEMBERED for that app. Switch to Slack and it
--               drops to your Slack level; switch to Safari and it goes
--               back up. It is one volume being driven for you, not a
--               mixer, and it approximates badly when two apps are
--               audible at once.
--
-- ⚠️ AND IT SAYS WHICH ONE IT JUST DID, every single time, in the alert.
-- A tool that sometimes moves one app and sometimes moves your whole Mac
-- and looks identical doing both is worse than no tool: you would learn
-- to distrust it and stop using it. The 🎯/🌐 in the alert is not
-- decoration, it is the entire safety story.
--
-- ⏱ NOTHING HERE BLOCKS THE MAIN THREAD. AppleScript is spoken through
-- hs.task, never hs.osascript — 6.75.0's whole pass was about synchronous
-- calls freezing the keyboard, and a volume key is exactly the sort of
-- thing you press repeatedly and fast.
--
-- 🔒 WE NEVER READ AN APP'S VOLUME BACK, only write absolute values from
-- a level we remember. Reading would mean an async round trip before
-- every keypress, and a volume key that answers in 200ms is a volume key
-- you press four times by mistake. The cost is honest and small: change
-- Spotify's volume inside Spotify and we are out of step until your next
-- ⇪. — which sets an absolute value and puts us back in step.

local M = {
    name  = "Volume",
    order = 13.45,        -- between the screen veil and the numpad layer
    cheatsheet = {
        title = "🔊 VOLUME (⇪, ⇪. — per-app, remembered)",
        entries = {
            { "⇪.",      "Volume UP for the app in front" },
            { "⇪,",      "Volume DOWN for the app in front" },
            { "⇪⇧,",     "Mute / unmute" },
            { "⇪⇧.",     "Panel: every app's level, and the output device" },
            { "🎯 app",   "Music & Spotify move their OWN volume — real per-app" },
            { "🌐 system", "Everything else moves the SYSTEM volume, remembered" },
            { "follow",  "Switching apps restores that app's level automatically" },
            { "real mixing", "Vorssaint — free, driverless, per-app since macOS 14.2" },
        },
    },
}

-- ✏️ EDIT THESE ---------------------------------------------------------
M.config = {
    step = 5,               -- percentage points per press

    -- Apps that move their OWN volume. The value is the AppleScript
    -- property to set, on a 0–100 scale. Anything not listed here falls
    -- back to the system volume, which is not a failure — it is the only
    -- thing macOS offers.
    --
    -- ⚠️ ADD ONE ONLY IF YOU HAVE CHECKED IT. An app that is not
    -- scriptable answers with an error we can only report, and a
    -- misspelled name is an app that silently never matches. The two
    -- here are verified; VLC is deliberately absent because its
    -- `audio volume` runs 0–512, not 0–100, and a scale mismatch would
    -- make ⇪. look broken rather than wrong.
    scriptable = {
        ["Music"]   = "sound volume",
        ["Spotify"] = "sound volume",
    },

    -- Levels are remembered per app. This is the level a NEW app starts
    -- at, i.e. whatever the system is already doing — we never yank the
    -- volume on an app we have never been told about.
    followFrontmost = true,  -- restore an app's level when you switch to it
    alertSeconds    = 1.2,
}

function M.setup(core)
    local vol = {}
    vol.config = M.config
    vol.levels = {}          -- appName -> 0..100
    vol.file   = (core.logsDir or "") .. "/volume-" .. (core.hostTag or "mac") .. ".json"

    -- ---- the two mechanisms, kept apart ------------------------------
    local function scriptedProperty(app)
        return app and vol.config.scriptable[app] or nil
    end

    -- 🌐 SYSTEM. Every call pcall'd and every result checked: on a Mac
    -- with no output device — booting with headphones half-in, a display
    -- that has gone to sleep, the hostile world the suite runs — these
    -- return nil rather than a device, and a nil here must cost the
    -- keypress, not the module.
    local function outputDevice()
        local ok, dev = pcall(function()
            return hs.audiodevice and hs.audiodevice.defaultOutputDevice()
        end)
        return (ok and dev) or nil
    end

    function vol.systemLevel()
        local dev = outputDevice()
        if not dev then return nil end
        local ok, v = pcall(function() return dev:outputVolume() end)
        return (ok and type(v) == "number") and math.floor(v + 0.5) or nil
    end

    function vol.setSystem(level)
        local dev = outputDevice()
        if not dev then return false, "no output device" end
        local ok, err = pcall(function() dev:setOutputVolume(level) end)
        if not ok then return false, tostring(err) end
        -- Raising the volume on a muted device does nothing audible, and
        -- "I pressed volume up eight times and heard nothing" is a bug
        -- report, so unmuting is part of turning it up.
        if level > 0 then pcall(function() dev:setOutputMuted(false) end) end
        return true
    end

    -- 🎯 APP. hs.task, never hs.osascript: this runs on a keypress you
    -- hold down, and a synchronous AppleScript to a busy app is the
    -- beachball 6.75.0 spent a whole pass removing. `with timeout of 3`
    -- as well, because an app that has stopped answering Apple events
    -- would otherwise inherit AppleScript's 120-second default.
    function vol.setApp(app, level, onDone)
        local prop = scriptedProperty(app)
        if not prop then return false end
        local script = ('with timeout of 3 seconds\n'
            .. 'tell application "%s" to set %s to %d\n'
            .. 'end timeout'):format(app, prop, level)
        local ok = pcall(function()
            vol.task = hs.task.new("/usr/bin/osascript", function(code, _, stderr)
                if code ~= 0 then
                    -- Reported, not swallowed: a scriptable app that
                    -- refuses is the one case where the 🎯 label would
                    -- otherwise be a lie about something that did not
                    -- happen.
                    print("🔊 " .. tostring(app) .. " refused a volume change (exit "
                          .. tostring(code) .. "): "
                          .. tostring(stderr or ""):gsub("%s+$", ""))
                    if _G.notices then
                        pcall(_G.notices.record, "volume", tostring(app),
                              "refused a volume change — falling back to system")
                    end
                end
                if onDone then pcall(onDone, code == 0) end
            end, { "-e", script })
            vol.task:start()
        end)
        return ok
    end

    -- ---- persistence -------------------------------------------------
    function vol.load()
        local f = io.open(vol.file, "r")
        if not f then return end
        local body = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, body)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if type(k) == "string" and type(v) == "number" then
                    vol.levels[k] = math.max(0, math.min(100, math.floor(v)))
                end
            end
        end
    end

    function vol.save()
        local ok, body = pcall(hs.json.encode, vol.levels)
        if not ok then return end
        local f = io.open(vol.file, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("volume file " .. vol.file) end
            return
        end
        f:write(body); f:close()
    end

    -- ---- what is in front, and what that means ------------------------
    function vol.frontApp()
        local ok, app = pcall(function()
            local a = hs.application.frontmostApplication()
            return a and a:name() or nil
        end)
        return (ok and app) or nil
    end

    -- The one function that decides everything, so there is one place to
    -- read when the answer surprises you.
    function vol.levelFor(app)
        if vol.levels[app] then return vol.levels[app] end
        if scriptedProperty(app) then return 100 end   -- app mixers start open
        return vol.systemLevel() or 50
    end

    function vol.apply(app, level, say)
        level = math.max(0, math.min(100, math.floor(level + 0.5)))
        vol.levels[app] = level
        vol.save()

        local scripted = scriptedProperty(app) ~= nil
        if scripted then
            vol.setApp(app, level)
            if say then vol.say("🎯 " .. app .. "  " .. level .. "%", true) end
            return true, "app"
        end

        local ok, err = vol.setSystem(level)
        if not ok then
            -- 🚨 NOT SILENT. A volume key that does nothing and says
            -- nothing is indistinguishable from a volume key you pressed
            -- wrong, and this is the branch where the Mac genuinely has
            -- nowhere to send audio.
            vol.say("🔇 No output device — volume unchanged", true)
            print("🔊 Volume: no usable output device (" .. tostring(err) .. ")")
            if _G.notices then
                pcall(_G.notices.record, "volume", "output device", tostring(err))
            end
            return false, "none"
        end
        if say then vol.say("🌐 " .. app .. "  " .. level .. "%", true) end
        return true, "system"
    end

    function vol.say(text, transient)
        pcall(function()
            hs.alert.closeAll(0)
            hs.alert.show(text, vol.config.alertSeconds)
        end)
    end

    function vol.nudge(delta)
        local app = vol.frontApp()
        if not app then
            vol.say("🔇 Nothing is frontmost — volume unchanged", true)
            return
        end
        vol.apply(app, vol.levelFor(app) + delta, true)
    end

    function vol.toggleMute()
        local dev = outputDevice()
        if not dev then
            vol.say("🔇 No output device", true)
            return
        end
        local ok, muted = pcall(function() return dev:outputMuted() end)
        local target = not (ok and muted)
        local set = pcall(function() dev:setOutputMuted(target) end)
        if not set then
            vol.say("🔇 This device cannot be muted", true)
            return
        end
        -- ⚠️ MUTE IS ALWAYS SYSTEM-WIDE, and the label says so even for a
        -- scriptable app, because muting is the one place where the two
        -- mechanisms do NOT line up: Spotify's own volume is untouched.
        vol.say(target and "🌐 Muted (whole Mac)" or "🌐 Unmuted", true)
    end

    -- ---- the panel ---------------------------------------------------
    function vol.panel()
        local rows = {}
        local front = vol.frontApp()
        local sys = vol.systemLevel()
        rows[#rows + 1] = {
            text = "🌐 System volume — " .. tostring(sys or "?") .. "%",
            subText = "The one real slider macOS gives us. Everything not "
                      .. "listed as 🎯 rides this.",
            kind = "system",
        }
        local names = {}
        for app in pairs(vol.levels) do names[#names + 1] = app end
        table.sort(names)
        for _, app in ipairs(names) do
            local scripted = scriptedProperty(app) ~= nil
            rows[#rows + 1] = {
                text = (scripted and "🎯 " or "🌐 ") .. app .. "  "
                       .. tostring(vol.levels[app]) .. "%"
                       .. (app == front and "   ← in front" or ""),
                subText = scripted
                    and "Its own mixer. Independent of everything else."
                    or "Remembered system level — applied when you switch to it.",
                kind = "app", app = app,
            }
        end
        if #names == 0 then
            rows[#rows + 1] = {
                text = "No app levels remembered yet",
                subText = "Press ⇪. or ⇪, while an app is in front and it "
                          .. "will appear here.",
                kind = "none",
            }
        end

        local ch = hs.chooser.new(function(choice)
            if not choice then return end
            if choice.kind == "app" and choice.app then
                -- Selecting an app APPLIES its level, which is also the
                -- only way to try one without switching windows.
                vol.apply(choice.app, vol.levels[choice.app] or 50, true)
            end
        end)
        ch:choices(rows)
        ch:placeholderText("Volume — 🎯 the app's own mixer · 🌐 the system's")
        _G.choosers = _G.choosers or {}
        _G.choosers.volume = ch
        if core.showPopup then core.showPopup(ch) else ch:show() end
    end

    -- ---- follow the frontmost app -------------------------------------
    -- 🚨 ONLY FOR APPS WE ALREADY KNOW. An app with no remembered level is
    -- left completely alone — the volume you set by hand stays where you
    -- put it. A module that reset the system volume every time you
    -- switched windows would be unusable, and "helpful" is not a defence.
    function vol.onActivated(appName)
        if not vol.config.followFrontmost then return end
        local level = vol.levels[appName]
        if not level then return end
        if scriptedProperty(appName) then
            vol.setApp(appName, level)     -- its own mixer; no alert
        else
            vol.setSystem(level)
        end
    end

    vol.load()

    -- HELD in _G: an unreferenced watcher is collected, and a collected
    -- watcher never fires — which would remove the follow behaviour with
    -- nothing to say it had gone.
    local okW = pcall(function()
        _G.volumeWatcher = hs.application.watcher.new(function(appName, event)
            if event ~= hs.application.watcher.activated then return end
            local ok, err = pcall(vol.onActivated, appName)
            if not ok then
                print("🔊 Volume: follow-frontmost failed for "
                      .. tostring(appName) .. " — " .. tostring(err))
            end
        end)
        _G.volumeWatcher:start()
    end)
    if not okW then
        print("⚠️ 🔊 Volume: the app watcher could not start — levels are "
              .. "still remembered and ⇪. / ⇪, still work, but they will "
              .. "not follow you between apps.")
    end

    core.hyperAddShortcut({}, ".", function() vol.nudge(vol.config.step) end,
        "volume up", nil, function() vol.nudge(vol.config.step) end)
    core.hyperAddShortcut({}, ",", function() vol.nudge(-vol.config.step) end,
        "volume down", nil, function() vol.nudge(-vol.config.step) end)
    core.hyperAddShortcut({ "shift" }, ",", function() vol.toggleMute() end,
        "mute toggle")
    core.hyperAddShortcut({ "shift" }, ".", function() vol.panel() end,
        "volume panel")

    core.provide("volume.set", function(app, level) return vol.apply(app, level, false) end)
    core.provide("volume.get", function(app) return vol.levelFor(app) end)
    core.provide("volume.system", function() return vol.systemLevel() end)

    _G.appVolume = vol
    M.vol = vol
    return vol
end

return M
