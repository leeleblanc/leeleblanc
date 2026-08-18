-- =====================================================================
-- MODULE: APP WATCHER (was §3.7) — alert when a watched app closes
-- =====================================================================
-- Watches the apps listed below. When one of them quits (or crashes),
-- a popup appears front-and-center with two options:
--   🚀 Spawn — relaunch the app
--   🛑 End   — acknowledge and leave it closed
-- An audible ping repeats every few seconds until you respond — by
-- pressing a button, or dismissing with Escape. 6.16.21: NO auto-
-- dismiss anymore — if you're away when an app quits, a popup that
-- gives up after 30s means you'd never find out. It now stays on
-- screen (and keeps gently pinging) indefinitely until you actually
-- respond, however long that takes.
-- Dismissing with Esc posts a macOS notification — "{app} closed" —
-- so you still have a record even if you didn't take an action.
-- Requires notifications to be allowed for Hammerspoon in System
-- Settings → Notifications, or the notification silently won't
-- appear (a fallback on-screen alert covers that case).
--
-- ✏️ EDIT THIS LIST — exact app names, as shown in the menu bar next
-- to the  when the app is frontmost (or as they appear in your
-- Activity tracker rows). Case-sensitive.

-- Moved out of init.lua in 6.38.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "App Watcher",
    order = 1,
    family = "auto",
    summary = "Notices apps starting and quitting, for the trackers",
    cheatsheet = {
        title = "👁 APP MONITOR (automatic)",
        entries = {
            { "Enter", "Spawn (relaunch) or End" },
            { "Esc", "Dismiss (stays open otherwise, no timeout) → posts notification" }
        },
    },
}

function M.setup(core)
    local appMonitorWatchedApps = {
    		"1Password",
    		"Alfred",
    		"Bartender",
    		"CotEditor",
    		"Ghostty",
    		"Google Chrome",
    		"IINA",
    		"OneDrive",
    		"Microsoft Defender",
    		"Microsoft Excel",
    		"Microsoft PowerPoint",
    		"Microsoft Word",
    		"Microsoft Outlook",
    		"Microsoft Teams",
    		"Microsoft Excel",
    		"NordVPN",
    		"Rectangle",
    		"Shottr",
    		"Sublime",
    		"Transmission",
    }
    -- 6.16.21: no more auto-dismiss — if you're away when an app quits, a
    -- popup that gives up after 30s means you'd never know. It now stays
    -- up, pinging gently, until you actually respond (a button, or Esc).
    -- TO CHANGE THE SOUNDS: edit the list below, save, reload (⇪R). That is
    -- the whole edit — this one list drives BOTH the first alert and every
    -- ping after it, so they can never drift apart.
    -- Valid names are the built-in macOS sounds in /System/Library/Sounds:
    --   gentlest → Tink · Purr · Pop · Frog
    --   middle   → Ping · Bottle · Blow · Morse · Funk
    --   loudest  → Glass · Hero · Sosumi · Basso · Submarine
    -- ⚠️ CASE-SENSITIVE. A name that does not exist is SKIPPED rather than
    --    erroring — so one typo costs you that one sound and the rest of
    --    the sequence carries on.
    -- ✅ 6.61.0: AND YOU ARE NOW TOLD. A name that will not resolve is
    --    reported through the notice ledger a couple of seconds after
    --    login, naming the exact spelling that failed; if NONE of them
    --    resolve you get an on-screen alert, because a silent popup
    --    cannot draw you to itself. You no longer have to guess from
    --    "hm, that was quieter than I expected".
    --
    -- 6.60.0 — A DIFFERENT SOUND ON EVERY PING. Each ping takes the next
    -- entry and WRAPS at the end, so at one-second intervals this is ten
    -- seconds of varied alert that then starts over. It restarts rather
    -- than falling silent on purpose: the popup waits indefinitely (see
    -- 6.16.21 above), and a sequence that ends would quietly reintroduce
    -- the exact "you were away, so you never found out" failure that the
    -- no-auto-dismiss design exists to prevent.
    -- Ordered loudest-first so the opening seconds are the ones most
    -- likely to reach you from another room.
    local appMonitorSounds = {
        "Hero", "Glass", "Sosumi", "Submarine", "Basso",
        "Ping", "Funk", "Morse", "Bottle", "Blow",
    }
    local appMonitorPingInterval   = 0.5     -- seconds between pings while waiting

    local appMonitorQueue   = {}   -- apps waiting their turn if several close at once
    local appMonitorCurrent = nil  -- app the popup is currently asking about
    local appMonitorPing    = nil  -- repeating sound timer
    local appMonitorResolved = nil -- cached sound objects (see below)

    -- 6.61.0 — RESOLVE THE SOUND NAMES, AND SAY SO WHEN THEY ARE WRONG.
    --
    -- Until now a misspelled name was invisible: hs.sound.getByName
    -- returns nil, the nil-check skipped it, and you got a quieter (or
    -- entirely silent) popup with nothing anywhere explaining why. That is
    -- precisely the silent failure the notice ledger exists to abolish,
    -- and this module predated it.
    --
    -- Resolved ONCE and cached: getByName goes out to the system, and
    -- calling it inside a one-second timer that may run for hours would be
    -- thousands of lookups for an answer that cannot change. Called from
    -- warm() so the report lands a couple of seconds after login — you
    -- find out that the sound list is broken BEFORE the night an app
    -- crashes, not during it — and from the popup as a fallback, so the
    -- sound still works even if warm() never ran.
    local function appMonitorResolveSounds()
        if appMonitorResolved then return appMonitorResolved end

        local sounds, missing = {}, {}
        for _, soundName in ipairs(appMonitorSounds) do
            local resolved = nil
            pcall(function() resolved = hs.sound.getByName(soundName) end)
            if resolved then sounds[#sounds + 1] = resolved
            else missing[#missing + 1] = soundName end
        end
        appMonitorResolved = sounds

        -- Report through the ledger, never by throwing: this runs on the
        -- popup path, and an App Monitor that crashes while telling you a
        -- sound name is wrong is worse than the wrong sound.
        -- The `key` makes it once-an-hour rather than once-per-app-close;
        -- a bad name is a config mistake, not news that improves on
        -- repetition.
        if #missing > 0 then
            pcall(function()
                local names = table.concat(missing, ", ")
                if not _G.notices then return end
                if #sounds == 0 then
                    -- Total silence. This is the case that used to leave
                    -- you with a mute popup and no explanation at all, so
                    -- it gets an alert rather than a ledger line: nothing
                    -- else is going to make a sound to draw you to it.
                    _G.notices.tell("App Monitor has no sound",
                        "None of these resolved: " .. names ..
                        ". The popup will still appear, silently. Check the "
                        .. "spelling in modules/app_watcher.lua.",
                        { key = "appmonitor.sounds.none", every = 3600 })
                else
                    _G.notices.record("config", "app_watcher",
                        "sound name(s) not found, skipped: " .. names ..
                        " (" .. #sounds .. " of " .. #appMonitorSounds ..
                        " still play)")
                end
            end)
        end

        return sounds
    end

    local function appMonitorStopTimers()
        if appMonitorPing then appMonitorPing:stop(); appMonitorPing = nil end
    end

    local function appMonitorNotify(appName)
        local ok = pcall(function()
            hs.notify.new(nil, { title = "App Monitor", informativeText = appName .. " closed" }):send()
        end)
        -- If notifications are blocked/unavailable, at least flash an alert
        if not ok then hs.alert.show("ℹ️ " .. appName .. " closed") end
    end

    local appMonitorShowNext  -- forward declaration (finish + showNext call each other)

    -- Resolves the current popup exactly once, no matter which path ends it
    -- (button, Escape, or timeout) — appMonitorCurrent doubles as the guard.
    local function appMonitorFinish(choice)
        local appName = appMonitorCurrent
        if not appName then return end
        appMonitorCurrent = nil
        appMonitorStopTimers()

        if choice and choice.action == "spawn" then
            -- 6.16.1 FIX: launchOrFocus(name) silently failed for apps
            -- whose real /Applications bundle is versioned on disk (Alfred
            -- ships as "Alfred 5.app", Bartender as "Bartender 5.app" —
            -- same mismatch already found in the App Update Tracker, §3.10).
            -- Resolve the real bundle path first and hand it straight to
            -- `open -a`, which doesn't care about the name mismatch;
            -- launchOrFocus stays as a fallback for anything not found.
            local path = _G.findAppBundle and _G.findAppBundle(appName)
            if path then
                hs.task.new("/usr/bin/open", nil, { "-a", path }):start()
            else
                hs.application.launchOrFocus(appName)
            end
            hs.alert.show("🚀 Relaunching " .. appName)
        elseif choice and choice.action == "end" then
            -- acknowledged; leave it closed, no notification
        else
            -- Esc — the only other way this resolves now (no more timeout)
            appMonitorNotify(appName)
        end

        appMonitorShowNext()  -- anything else queued up?
    end

    _G.appMonitorChooser = hs.chooser.new(function(choice)
        appMonitorFinish(choice)
    end)
    -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it before the cheat sheet
    _G.choosers = _G.choosers or {}
    _G.choosers.appMonitor = _G.appMonitorChooser
    _G.appMonitorChooser:rows(2)

    -- White text on black background. bgDark gives the chooser macOS's
    -- dark panel (near-black, slightly translucent — choosers don't accept
    -- an arbitrary flat background color); fgColor/subTextColor set the
    -- main and secondary text to white. pcall-guarded in case a future
    -- Hammerspoon version renames these.
    pcall(function()
        _G.appMonitorChooser:bgDark(true)
        _G.appMonitorChooser:fgColor({ white = 1.0 })
        _G.appMonitorChooser:subTextColor({ white = 0.85 })
    end)

    appMonitorShowNext = function()
        if appMonitorCurrent then return end            -- one at a time
        local nextApp = table.remove(appMonitorQueue, 1)
        if not nextApp then return end
        appMonitorCurrent = nextApp

        _G.appMonitorChooser:placeholderText("⚠️  " .. nextApp .. " just closed — Spawn, End, or Esc to dismiss")
        _G.appMonitorChooser:choices({
            { text = "🚀 Spawn", subText = "Relaunch " .. nextApp,            action = "spawn" },
            { text = "🛑 End",   subText = "Acknowledge — leave it closed",   action = "end"   },
        })

        -- Front and center: chooser panels float above normal windows by
        -- nature; we center it on the frontmost app's screen. (Deliberately
        -- NOT registered in _G.choosers — it's an alert, not a picker, so
        -- popup nudging shouldn't drag it around.)
        local screen = core.resolveBaseScreen()
        local f = screen:frame()
        local pct = 40
        local okW, w = pcall(function() return _G.appMonitorChooser:width() end)
        if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
        local width = f.w * (pct / 100)
        _G.appMonitorChooser:show(hs.geometry.point(f.x + (f.w - width) / 2, f.y + f.h * 0.35))

        -- Audible ping now, then again every appMonitorPingInterval seconds
        -- INDEFINITELY — no auto-dismiss anymore, so this keeps sounding
        -- until you actually respond, even if that's hours later. Stopped
        -- only by appMonitorStopTimers (called from appMonitorFinish, which
        -- only runs on a button press or Esc).
        --
        local sounds = appMonitorResolveSounds()

        if #sounds > 0 then
            -- Modulo, so the sequence wraps forever instead of running out.
            -- Each tick uses a DIFFERENT sound object, which also means a
            -- ping never cuts off the one before it the way replaying a
            -- single object at short intervals would.
            local nextSound = 0
            local function ping()
                nextSound = (nextSound % #sounds) + 1
                pcall(function() sounds[nextSound]:play() end)
            end
            ping()
            appMonitorPing = hs.timer.doEvery(appMonitorPingInterval, ping)
        end
    end

    -- KNOWN GOTCHA this guards against: for `terminated` events, the
    -- watcher's appName parameter is often NIL — the app is already gone
    -- when the event arrives, so macOS can't always supply its name. So
    -- instead of trusting the event's name, we keep our own running/
    -- not-running map of the watched apps and RE-SCAN it whenever any
    -- termination fires: whichever watched app just vanished is the one
    -- that closed. The short delay lets the system settle so
    -- hs.application.get() reliably reports the app as gone.
    local appMonitorRunning = {}

    -- 6.16.22 BEACHBALL FIX: this used to call hs.application.get(name)
    -- once PER watched app — 20 separate name lookups. Console evidence
    -- pinned an 11-second main-thread freeze to exactly that loop: the
    -- gap opened on hs.application's own "alternate names / Spotlight
    -- support" line, which is its NAME-RESOLUTION path announcing itself,
    -- and closed 11s later. (6.16.8's 0.1s deferral moved this off the
    -- config-LOAD path — which is why "-- Done." prints instantly — but
    -- hs.timer.doAfter still runs on the MAIN thread, so the UI froze
    -- 0.1s after the reload "finished" instead of during it.)
    -- Now: ONE bulk enumeration (hs.application.runningApplications())
    -- plus a pure-Lua name match. Same answer, one native call instead of
    -- twenty name resolutions. Falls back to the old per-name lookup only
    -- if the enumeration comes back empty, so behavior is never worse.
    local function appMonitorScan(fireOnClose)
        local running = {}
        local okList, apps = pcall(hs.application.runningApplications)
        if okList and apps and #apps > 0 then
            for _, a in ipairs(apps) do
                local okName, n = pcall(function() return a:name() end)
                if okName and n then running[n] = true end
            end
        else
            for _, w in ipairs(appMonitorWatchedApps) do
                running[w] = (hs.application.get(w) ~= nil)
            end
        end

        for _, w in ipairs(appMonitorWatchedApps) do
            local isRunning = (running[w] == true)
            if fireOnClose and appMonitorRunning[w] and not isRunning then
                table.insert(appMonitorQueue, w)
                appMonitorShowNext()
            end
            appMonitorRunning[w] = isRunning
        end
    end

    -- 6.16.8: appMonitorScan's baseline is the FIRST thing in this file to
    -- touch hs.application — and on this Mac that first touch alone costs
    -- several seconds (confirmed with timed boot checkpoints; ruled out
    -- both Microsoft Defender's file scanning and a Gatekeeper network
    -- check as the cause — the delay is identical in Airplane Mode). We
    -- can't make Hammerspoon's own module load faster, but we CAN keep it
    -- off the critical boot path: deferring it means the other 32 hotkeys
    -- are live and the reload itself completes instantly, and App
    -- Monitor's own protection comes online a few seconds later instead of
    -- blocking everything else.
    -- 6.16.18 FIX: this whole feature silently never fired for ANY app
    -- (Teams, Ghostty, Sublime all confirmed) — root cause was neither
    -- `hs.timer.doAfter` call here stored its return value anywhere.
    -- Unstored hs.timer objects are a real, documented Hammerspoon gotcha:
    -- with nothing left referencing them, Lua's garbage collector can (and
    -- evidently did) silently collect the timer before its delay elapsed,
    -- canceling it with no error. Both now held in _G. so they can't be
    -- collected before they fire.
    -- 6.16.20 FIX: Console evidence (both Ghostty and Microsoft Teams,
    -- reproduced twice) showed hs.application.get(name) STILL reporting
    -- the app as running even 0.3s after its own "terminated" event fired
    -- — the re-scan-via-get() approach is unreliable/stale on this Mac, not
    -- just slow. The watcher itself hands us the correct appName directly
    -- on every terminated event in this Console log, so trust THAT instead
    -- of re-querying: no re-scan, no waiting, no dependency on get() ever
    -- catching up. Falls back to a re-scan only in the rare case appName
    -- is nil (matches the original 6.11.3 concern, kept as a safety net).
    _G.appMonitorRescanTimers = {}   -- one-shot timers in flight; each removes itself once it fires
    _G.appMonitorBootTimer = hs.timer.doAfter(0.1, function()
        appMonitorScan(false)  -- baseline: which watched apps are running now
        _G.appMonitorWatcher = hs.application.watcher.new(function(appName, eventType)
            if eventType == hs.application.watcher.terminated then
                if appName then
                    local watched = false
                    for _, w in ipairs(appMonitorWatchedApps) do
                        if w == appName then watched = true; break end
                    end
                    if watched and appMonitorRunning[appName] then
                        appMonitorRunning[appName] = false
                        table.insert(appMonitorQueue, appName)
                        appMonitorShowNext()
                    end
                else
                    local rt
                    rt = hs.timer.doAfter(0.3, function()
                        appMonitorScan(true)
                        for i, t in ipairs(_G.appMonitorRescanTimers) do
                            if t == rt then table.remove(_G.appMonitorRescanTimers, i); break end
                        end
                    end)
                    table.insert(_G.appMonitorRescanTimers, rt)
                end
            elseif eventType == hs.application.watcher.launched then
                appMonitorScan(false)  -- keep the running map current
            end
        end)
        _G.appMonitorWatcher:start()
    end)

    -- Runs a couple of seconds after boot, off the load path (see §1.12's
    -- two-phase notes). The only job is to resolve the sound names early
    -- so a broken list is reported at LOGIN rather than discovered on the
    -- night an app actually crashes — which is the whole point of the
    -- ledger: you should not have to go and check, and you should not
    -- learn about it at the moment you needed it to work.
    -- Cheap enough to belong here: ten lookups, once, never repeated.
    M.warm = function()
        pcall(appMonitorResolveSounds)
    end
end

return M
