-- =====================================================================
-- core/diagnostics.lua — §1.11, lifted out of init.lua in 6.44.11
-- =====================================================================
-- A CORE FILE, NOT A MODULE. modules/ is loaded by the module loader in
-- §1.12, which runs LAST and which itself logs through _G.diag — so
-- diagnostics cannot be one of those without the loader depending on
-- something it has not loaded yet. This file is dofile'd by init.lua at
-- exactly the point §1.11 used to sit, so nothing about the boot order
-- changed; only the 287 lines moved.
--
-- It takes the three values it used to read as upvalues from init.lua.
-- All three are assigned before this point and never reassigned after,
-- so passing them by value is equivalent to the closure it replaces.
--
-- If this file is missing or raises, init.lua keeps the NO-OP diag
-- stand-in it installed earlier and boots anyway — degraded, loudly, but
-- not dead. That is deliberate: everything in the config calls _G.diag.
-- =====================================================================

return function(core)
    local logsDir      = core.logsDir
    local hostTag      = core.hostTag
    local asanaEnabled = core.asanaEnabled

    -- =====================================================================
    -- 1.11 DIAGNOSTICS — ⇪⇧D writes the report I need to debug anything
    -- =====================================================================
    -- THE PROBLEM THIS SOLVES. When something misbehaves, the Console shows
    -- what Hammerspoon chose to log, which is rarely what actually matters.
    -- The ⌥Tab freeze was only diagnosable because two unrelated lines
    -- happened to bracket it. This section makes that luck unnecessary.
    --
    -- ⇪⇧D builds a full report — versions, boot timings, screens, hotkey
    -- counts, feature states, file paths with their write status, a LIVE
    -- window-enumeration timing, the last errors, and the last 25 internal
    -- events — then does three things with it: prints it to the Console,
    -- copies it to your clipboard, and writes it to
    --   <logsDir>/diagnostics-<machine>.txt
    -- Paste it into chat and I have the whole picture in one message
    -- instead of asking you six questions.
    --
    -- TWO LEVELS, deliberately:
    --   • THE TRAIL is always recorded (a 200-entry ring buffer in memory,
    --     no I/O, no Console noise). So the report can show what happened
    --     just before a problem even though verbose mode was off at the
    --     time — which is the normal case, because nobody runs verbose
    --     until after something breaks.
    --   • VERBOSE also PRINTS each of those events live. Turn it on without
    --     reloading by typing this in the Hammerspoon Console:
    --         _G.diag.verbose = true
    --     Turn it off the same way with false. Nothing persists it: a
    --     reload always comes back quiet.
    --
    -- ERRORS ARE CAPTURED EVEN WHEN NOBODY IS WATCHING. hs.uncaughtErrorHandler
    -- is set below, so a Lua error thrown inside an async callback — an HTTP
    -- reply, a timer, a watcher, all the places a pcall in the calling
    -- function cannot reach — lands in the report with a timestamp instead
    -- of scrolling past in the Console.
    _G.diagBootStart = _G.diagBootStart or hs.timer.secondsSinceEpoch()

    -- Extends the no-op stub declared at the top of the file rather than
    -- replacing it, so anything already recorded survives.
    _G.diag.verbose   = false   -- live-toggle in the Console: _G.diag.verbose = true
    _G.diag.trail     = _G.diag.trail  or {}   -- ring buffer of recent events
    _G.diag.errors    = _G.diag.errors or {}   -- ring buffer of errors, newest last
    _G.diag.marks     = _G.diag.marks  or {}   -- boot timings, in order
    _G.diag.maxTrail  = 200
    _G.diag.maxErrors = 30

    function _G.diag.stamp()
        return os.date("%H:%M:%S")
    end

    -- Record an event. Always stored, printed only in verbose mode.
    function _G.diag.say(tag, msg)
        local line = string.format("%s [%s] %s", _G.diag.stamp(), tostring(tag), tostring(msg))
        local t = _G.diag.trail
        t[#t + 1] = line
        while #t > _G.diag.maxTrail do table.remove(t, 1) end
        if _G.diag.verbose then print("🔍 " .. line) end
    end

    -- Record AND always print: for things worth seeing without verbose on.
    function _G.diag.warn(tag, msg)
        _G.diag.say(tag, msg)
        print("⚠️ " .. tostring(tag) .. ": " .. tostring(msg))
    end

    function _G.diag.err(err)
        local line = string.format("%s %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(err))
        local e = _G.diag.errors
        e[#e + 1] = line
        while #e > _G.diag.maxErrors do table.remove(e, 1) end
        _G.diag.say("error", tostring(err))
    end

    -- Boot timings. Called at the end of the heavy sections; the report
    -- prints them in order so a slow start says WHICH part was slow.
    function _G.diag.mark(name)
        local at = hs.timer.secondsSinceEpoch() - (_G.diagBootStart or 0)
        table.insert(_G.diag.marks, { name = name, at = at })
        _G.diag.say("boot", string.format("%s at %.3fs", name, at))
    end

    -- A Lua error in an async callback (HTTP reply, timer, watcher) cannot
    -- be caught by a pcall in the function that scheduled it. This is the
    -- only place it can be seen at all.
    hs.uncaughtErrorHandler = function(err)
        _G.diag.err(err)
        print("💥 UNCAUGHT: " .. tostring(err))
        pcall(function() hs.alert.show("💥 Hammerspoon error — ⇪⇧D for the report") end)
    end

    -- Decode JSON that came off the network WITHOUT throwing. hs.json.decode
    -- raises on malformed input, and every caller in this file is an async
    -- HTTP callback, so a throw there escapes to the handler above and the
    -- operation dies with an unhelpful message. A corporate proxy or captive
    -- portal answering HTTP 200 with an HTML login page is exactly that
    -- case, and it is far likelier on a work network than a broken API.
    function _G.safeJson(body, tag)
        if type(body) ~= "string" or body == "" then
            _G.diag.warn(tag or "json", "empty response body")
            return nil
        end
        local ok, data = pcall(hs.json.decode, body)
        if not ok then
            _G.diag.warn(tag or "json",
                "response was not JSON (" .. #body .. " bytes, starts: "
                .. body:sub(1, 60):gsub("%s+", " ") .. ")")
            return nil
        end
        return data
    end

    -- ---- the report -----------------------------------------------------
    function _G.diag.fileInfo(path)
        if not path then return "not configured" end
        local attrs = hs.fs.attributes(path)
        if not attrs then return path .. "  (MISSING)" end
        local writable = "read-only?"
        if attrs.mode == "directory" then
            local probe = path .. "/.hs-write-probe"
            local f = io.open(probe, "w")
            if f then f:close(); os.remove(probe); writable = "writable" end
            return string.format("%s  (dir, %s)", path, writable)
        end
        local f = io.open(path, "a")
        if f then f:close(); writable = "writable" end
        return string.format("%s  (%d bytes, %s)", path, attrs.size or 0, writable)
    end

    function _G.diag.report()
        local L = {}
        local function add(fmt, ...)
            local ok, s = pcall(string.format, fmt, ...)
            table.insert(L, ok and s or fmt)
        end

        add("🩺 HAMMERSPOON DIAGNOSTIC REPORT — %s", os.date("%Y-%m-%d %H:%M:%S"))
        add("   config version : %s", tostring(_G.configVersion or "?"))
        pcall(function()
            add("   Hammerspoon    : %s", tostring(hs.processInfo.version))
        end)
        pcall(function()
            add("   macOS          : %s", hs.host.operatingSystemVersionString())
        end)
        add("   machine        : %s", tostring(hostTag))
        add("   accessibility  : %s", hs.accessibilityState() and "granted" or "NOT GRANTED")
        add("   lua memory     : %.0f KB", collectgarbage("count"))
        add("   verbose mode   : %s", _G.diag.verbose and "ON" or "off  (_G.diag.verbose = true)")

        add("")
        add("── BOOT ──────────────────────────────────────────────")
        if #_G.diag.marks == 0 then
            add("   (no marks recorded)")
        else
            for _, m in ipairs(_G.diag.marks) do add("   %-28s %6.3fs", m.name, m.at) end
        end

        add("")
        add("── SCREENS ───────────────────────────────────────────")
        pcall(function()
            for _, s in ipairs(hs.screen.allScreens()) do
                local f = s:frame()
                add("   %-24s %dx%d at (%d,%d)", s:name() or "?", f.w, f.h, f.x, f.y)
            end
        end)

        add("")
        add("── HOTKEYS ───────────────────────────────────────────")
        add("   global bound   : %s   conflicts: %s",
            tostring(_G.hotkeyBoundCount), tostring(_G.hotkeyConflictCount))
        add("   hyper          : %s shortcuts + %s forwarded, %s conflicts",
            tostring(_G.hyperShortcutCount or 0), tostring(_G.hyperForwardCount or 0),
            tostring(_G.hyperConflictCount or 0))

        add("")
        add("── FEATURES ──────────────────────────────────────────")
        add("   Asana          : %s", asanaEnabled and "on" or "off")
        add("   Autocorrect    : %s", tostring(_G.autocorrectStatus or "?"))
        add("   Autocorrect tap: %s", (function()
            if not _G.autocorrectTap then return "not created" end
            local ok, on = pcall(function() return _G.autocorrectTap:isEnabled() end)
            return (ok and on) and "running" or "STOPPED (macOS may have disabled it)"
        end)())
        add("   Cheat sheet    : %s", _G.cheatSheetState and "open" or "closed")
        -- The switcher is a MODULE now, so "not loaded" is a real state the
        -- report has to be able to say out loud.
        local at = _G.altTab
        add("   ⌥Tab switcher  : %s", at and string.format(
            "%s · minimised:%s · cap:%s · session:%s",
            at.enabled and "on" or "OFF", tostring(at.includeMinimized),
            tostring(at.maxWindows), at.session and "OPEN" or "idle")
            or "module not loaded")

        add("")
        add("── SERVICES (published by modules) ───────────────────")
        do
            local names = {}
            for k in pairs((_G.service or {}).registry or {}) do table.insert(names, k) end
            table.sort(names)
            add("   %s", #names > 0 and table.concat(names, ", ") or "(none)")
        end

        add("")
        add("── MODULES ───────────────────────────────────────────")
        add("   folder         : %s", tostring(_G.moduleDir))
        if not _G.moduleStatus or #_G.moduleStatus == 0 then
            add("   (none listed)")
        else
            for _, rec in ipairs(_G.moduleStatus) do
                add("   %-18s %-7s %5.0fms%s", rec.name,
                    rec.ok and "loaded" or "FAILED", rec.ms,
                    rec.ok and "" or ("   — " .. tostring(rec.err)))
            end
        end

        add("")
        add("── LIVE PROBE (measured right now) ───────────────────")
        -- This is the measurement that mattered for the ⌥Tab freeze: how
        -- long this Mac actually takes to enumerate its windows.
        pcall(function()
            local t0 = hs.timer.secondsSinceEpoch()
            local wins = hs.window.orderedWindows() or {}
            local dt = hs.timer.secondsSinceEpoch() - t0
            add("   orderedWindows : %d windows in %.3fs%s", #wins, dt,
                dt > 0.35 and "   ⚠️ SLOW" or "")
        end)
        pcall(function()
            local app = hs.application.frontmostApplication()
            add("   frontmost app  : %s", app and app:name() or "?")
        end)

        add("")
        add("── PATHS ─────────────────────────────────────────────")
        add("   logs dir       : %s", _G.diag.fileInfo(logsDir))
        add("   backup dir     : %s", _G.diag.fileInfo(backupDir))
        pcall(function()
            add("   custom cuts    : %s", _G.diag.fileInfo(logsDir .. "/custom_shortcuts.json"))
            add("   autocorrect    : %s", _G.diag.fileInfo(logsDir .. "/autocorrect.csv"))
            add("   changelog      : %s", _G.diag.fileInfo(logsDir .. "/changelog.csv"))
        end)

        add("")
        add("── ERRORS (%d) ───────────────────────────────────────", #_G.diag.errors)
        if #_G.diag.errors == 0 then
            add("   none recorded since load")
        else
            for _, e in ipairs(_G.diag.errors) do add("   %s", e) end
        end

        add("")
        add("── LAST 25 EVENTS ────────────────────────────────────")
        local t, from = _G.diag.trail, math.max(1, #_G.diag.trail - 24)
        if #t == 0 then
            add("   (nothing recorded yet)")
        else
            for i = from, #t do add("   %s", t[i]) end
        end
        add("")
        add("── END OF REPORT ─────────────────────────────────────")
        return table.concat(L, "\n")
    end

    -- ⇪⇧D — print it, copy it, save it. Three routes because the one you
    -- need is never the one that is working.
    function _G.diag.show()
        local ok, text = pcall(_G.diag.report)
        if not ok then
            print("🩺 Diagnostics failed to build: " .. tostring(text))
            hs.alert.show("🩺 Diagnostics failed — see Console")
            return
        end
        print("\n" .. text .. "\n")
        pcall(function() hs.pasteboard.setContents(text) end)

        local saved = false
        pcall(function()
            local path = logsDir .. "/diagnostics-" .. tostring(hostTag) .. ".txt"
            local f = io.open(path, "w")
            if f then f:write(text); f:close(); saved = true
                print("🩺 Diagnostic report → " .. path)
            end
        end)
        hs.alert.show(saved and "🩺 Report copied to clipboard + saved to Logs"
                            or "🩺 Report copied to clipboard (file write failed)")
    end

    hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "D", _G.diag.show)

    _G.diag.mark("§1.11 diagnostics ready")

end
