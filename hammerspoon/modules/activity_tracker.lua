-- =====================================================================
-- MODULE: ACTIVITY TRACKER (was 3.6) — persistent, searchable, day/week/month views
-- =====================================================================
-- Tracks time per app AND per document/window (approximated by window
-- title, since macOS has no universal "which file is open" API that
-- works the same across every app — window title is the closest thing
-- that generalizes: a browser tab's title, a text editor's filename, a
-- PDF viewer's document name, etc). This also means switching tabs or
-- documents WITHIN the same still-frontmost app gets tracked, not just
-- switches between different apps, which the old version couldn't do.
--
-- Persists to disk as CSV in your OneDrive Logs folder so it survives
-- Hammerspoon restarts/reloads AND syncs to OneDrive — the original
-- version was purely in-memory and reset every reload. CSV also means
-- you can open it directly in Numbers/Excel.
-- ⚠️ CloudStorage paths depend on OneDrive running; if OneDrive is
-- quit or the Logs folder is set to online-only, writes can fail.
-- Keep that folder "Always keep on this device" — since 6.10.0 a
-- failed write warns on screen instead of losing data silently.
--
-- ⌘⌥⇧0 opens it:
--   • empty box     → today's per-app totals
--   • type "week"   → this calendar week's per-app totals
--   • type "month"  → this month's top apps AND top documents/windows
--   • type anything else → searches app names & window titles across
--     ALL saved history (not just today)
--   • selecting any row copies its name + time to the clipboard
--
-- AUTOMATIC REPORTS (times/day editable below):
--   • Daily at 4:00 PM — today's apps ranked most→least, in minutes
--   • Monday at 7:30 AM — recap of the last 7 days, same ranking
--
-- Sessions are detected by POLLING every activityPollInterval seconds,
-- so a switch can take up to that long to be noticed, and only
-- recorded if they last at least activityMinSessionSeconds (filters
-- out quick accidental switches — same idea as the old 10s threshold).

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Activity Tracker",
    order = 4,
    cheatsheet = {
        title = "📊 ACTIVITY TRACKER",
        entries = {
            { "⇪0", "Open — today's totals" },
            { "type: week", "This week's totals" },
            { "type: month", "Top apps & documents this month" },
            { "type: anything", "Search all saved history" },
            { "Enter", "Copy row to clipboard" },
            { "auto 4:00 PM", "Daily report pops up" },
            { "auto Mon 7:30 AM", "Weekly recap pops up" }
        },
    },
}

function M.setup(core)
    local activityHistoryFile      = core.logsDir .. "/activity_history-" .. core.hostTag .. ".csv"
    core.adoptLegacyFile(activityHistoryFile, core.logsDir .. "/activity_history.csv")
    local activityOldCSVFile       = hs.configdir .. "/activity_history.csv"   -- pre-OneDrive location, migrated once below
    local activityOldJSONFile      = hs.configdir .. "/activity_history.json"  -- pre-CSV format, migrated once below
    local activityMinSessionSeconds = 10   -- ignore anything shorter than this
    local activityPollInterval      = 5    -- seconds between checks
    local activityRetentionDays     = 120  -- ~4 months of raw sessions kept on disk
    local activityWeekStartsSunday  = true -- false = weeks start Monday instead
    -- 6.16.5: frontmost-app time isn't ACTUAL use — leaving VLC or Sublime
    -- frontmost while away from the keyboard (movie playing, stepped out)
    -- kept the clock running for hours. The poller below now stops the
    -- clock after 300s (5 min) of no mouse/keyboard input (hs.host.idleTime),
    -- crediting time only up to when idling actually began, not up to now.
    -- (Inlined, not a local, to stay under Lua's 200-local ceiling — search
    -- "activityIdleThreshold" below to change the 5-min value.)
    -- HONEST LIMIT: reading without touching input for this long also stops
    -- the clock — raise the value if that's too aggressive for you.

    -- 6.11.3: only REAL applications are tracked — currentAppAndTitle below
    -- checks hs.application:kind() == 1 (the same "regular Dock app" test
    -- windowKeys.appJump already uses), so background/system processes like
    -- loginwindow (the lock screen) and ScreenSaverEngine are never recorded
    -- as "the app you were using". This is self-updating: install a new
    -- real app tomorrow and it's tracked automatically, no list to maintain.
    -- ✏️ To exclude a REAL app by name anyway, add it here (exact name, as
    -- it appears in this tracker's own rows):
    local activityIgnoredApps = {
        -- "Hammerspoon",
    }



    local function activityFileExists()
        local f = io.open(activityHistoryFile, "r")
        if f then f:close(); return true end
        return false
    end

    local function loadActivityCSV(path)
        local f = io.open(path, "r")
        if not f then return {} end
        local content = f:read("*a"); f:close()
        local log, isFirstLine = {}, true
        for line in content:gmatch("([^\r\n]+)") do
            if isFirstLine and line:match("^date,app,title,seconds") then
                -- skip header row
            else
                local fields = core.splitCSVLine(line)
                local seconds = tonumber(fields[4])
                if fields[1] and fields[2] and fields[3] and seconds then
                    table.insert(log, { date = fields[1], app = fields[2], title = fields[3], seconds = seconds })
                end
            end
            isFirstLine = false
        end
        return log
    end

    -- One-time upgrade path, tried only when the OneDrive CSV doesn't
    -- exist yet: first the CSV from when this lived in ~/.hammerspoon,
    -- then the even older JSON format — so nothing already recorded is
    -- lost, whichever version you were on.
    local function migrateOldDataIfAny()
        local fromCSV = loadActivityCSV(activityOldCSVFile)
        if #fromCSV > 0 then return fromCSV end

        local f = io.open(activityOldJSONFile, "r")
        if not f then return {} end
        local content = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, content)
        if ok and type(data) == "table" then return data end
        return {}
    end

    -- Writes the WHOLE file from scratch, including the header — used at
    -- boot (after pruning) and for the one-time migration/first-run case.
    -- Ongoing writes during normal use append instead (see below).
    -- Returns false if the file couldn't be opened (e.g. OneDrive folder
    -- unavailable) so boot can warn you instead of failing silently.
    local function rewriteActivityLog(log)
        local f = io.open(activityHistoryFile, "w")
        if not f then return false end
        f:write("date,app,title,seconds\n")
        for _, e in ipairs(log) do
            f:write(e.date .. "," .. core.csvQuote(e.app) .. "," .. core.csvQuote(e.title) .. "," .. e.seconds .. "\n")
        end
        f:close()
        return true
    end

    -- Fast path for normal operation: append one row rather than rewriting
    -- the whole growing file on every session close.
    local function appendActivityRow(entry)
        local f = io.open(activityHistoryFile, "a")
        if f then
            f:write(entry.date .. "," .. core.csvQuote(entry.app) .. "," .. core.csvQuote(entry.title) .. "," .. entry.seconds .. "\n")
            f:close()
        else
            core.warnWriteFailed("activity history")
        end
    end

    local function pruneActivityLog(log)
        local cutoff = os.date("%Y-%m-%d", os.time() - (activityRetentionDays * 86400))
        local pruned = {}
        for _, entry in ipairs(log) do
            if type(entry.date) == "string" and entry.date >= cutoff then
                table.insert(pruned, entry)
            end
        end
        return pruned
    end

    -- 6.11.3: one-time cleanup for rows recorded BEFORE kind-1 filtering
    -- existed — loginwindow (the lock screen process) and ScreenSaverEngine
    -- aren't real apps and never should have been logged. Runs once at
    -- boot, alongside the retention prune below; harmless (a no-op) once
    -- your CSV is already clean.
    local activityJunkApps = { loginwindow = true, ScreenSaverEngine = true }
    local function purgeJunkApps(log)
        local kept = {}
        for _, entry in ipairs(log) do
            if not activityJunkApps[entry.app] then
                table.insert(kept, entry)
            end
        end
        return kept
    end

    -- Boot: load existing OneDrive CSV data (or migrate from the old
    -- ~/.hammerspoon files if this is the first run since upgrading),
    -- purge known junk rows and prune anything past the retention window,
    -- and rewrite the file (with header) if it's brand new or cleanup
    -- removed something.
    local _existedBefore = activityFileExists()
    local _loaded = _existedBefore and loadActivityCSV(activityHistoryFile) or migrateOldDataIfAny()
    local _purged = purgeJunkApps(_loaded)
    local _pruned = pruneActivityLog(_purged)
    _G.activityLog = _pruned
    if not _existedBefore or #_pruned ~= #_loaded then
        if not rewriteActivityLog(_pruned) then
            hs.alert.show("⚠️ Can't write activity_history.csv — is the OneDrive Logs folder available?", 6)
        end
    end

    -- The session currently being tracked (app + window title + when it
    -- started). Closed out and recorded whenever the poller notices either
    -- one has changed.
    _G.activitySession = { app = nil, title = nil, startTime = nil }

    -- Best-effort read of "what's frontmost right now, and what does its
    -- focused window's title bar say". Wrapped defensively since a window
    -- can vanish between calls, or an app can have no accessible window.
    -- 6.11.3: only regular Dock apps (kind 1) are tracked — the frontmost
    -- "app" during a locked screen is loginwindow, a background system
    -- process, not something you were using; ScreenSaverEngine is the
    -- same story. Filtering by kind is self-updating (a real app installed
    -- tomorrow is tracked automatically) instead of a hardcoded app list.
    local function currentAppAndTitle()
        local ok, app = pcall(hs.application.frontmostApplication)
        if not ok or not app then return nil, nil end

        local okK, kind = pcall(function() return app:kind() end)
        if not okK or kind ~= 1 then return nil, nil end

        local ok2, name = pcall(function() return app:name() end)
        if not ok2 or not name then return nil, nil end

        for _, ignored in ipairs(activityIgnoredApps) do
            if name == ignored then return nil, nil end
        end

        local title = nil
        local ok3, win = pcall(function() return app:focusedWindow() end)
        if ok3 and win then
            local ok4, t = pcall(function() return win:title() end)
            if ok4 and type(t) == "string" and #t > 0 then title = t end
        end

        return name, title
    end

    local function closeActivitySession(endTime)
        local s = _G.activitySession
        if not (s.app and s.startTime) then return end

        endTime = endTime or os.time()
        local duration = endTime - s.startTime
        if duration >= activityMinSessionSeconds then
            local entry = {
                date    = os.date("%Y-%m-%d", s.startTime),
                app     = s.app,
                title   = s.title or "",
                seconds = duration,
            }
            table.insert(_G.activityLog, entry)
            appendActivityRow(entry)
        end
    end

    _G.activityPoller = hs.timer.doEvery(activityPollInterval, function()
        local okIdle, idle = pcall(hs.host.idleTime)
        if okIdle and idle and idle >= 300 then   -- activityIdleThreshold: 5 min away = stop the clock
            if _G.activitySession.app then
                -- credit only up to when idling actually began, not up to now
                closeActivitySession(os.time() - idle)
                _G.activitySession = { app = nil, title = nil, startTime = nil }
            end
            return
        end

        local appName, title = currentAppAndTitle()
        if not appName then return end  -- couldn't tell, or frontmost isn't a real app; leave current session running

        local s = _G.activitySession
        if s.app ~= appName or s.title ~= title then
            closeActivitySession()
            _G.activitySession = { app = appName, title = title, startTime = os.time() }
        end
    end)

    -- 6.11.3: THE 30-HOUR BUG — a session left open when the Mac sleeps or
    -- the screen locks keeps its original startTime; Hammerspoon's own
    -- timers pause during sleep, but wall-clock time doesn't, so on wake
    -- closeActivitySession() computed end-minus-start across the ENTIRE
    -- locked/asleep span (lock Friday 5 PM, return Monday 8 AM → the app
    -- that was frontmost at lock time "used" for ~63 hours). Fixed at the
    -- source: closing the session the INSTANT the screen locks or the
    -- system sleeps, so its duration stops at the real moment of lock, not
    -- at the next poll after you're back. The poller opens a fresh session
    -- for whatever's actually frontmost as soon as polling resumes.
    local activityLockWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.screensDidLock
           or event == hs.caffeinate.watcher.systemWillSleep then
            closeActivitySession()
            _G.activitySession = { app = nil, title = nil, startTime = nil }
        end
    end)
    activityLockWatcher:start()

    -- ---- date-range helpers ---------------------------------------------

    local function todayStr()
        return os.date("%Y-%m-%d")
    end

    local function weekStartStr()
        local t = os.date("*t")  -- t.wday: 1=Sunday ... 7=Saturday
        local offsetDays
        if activityWeekStartsSunday then
            offsetDays = t.wday - 1
        else
            offsetDays = (t.wday == 1) and 6 or (t.wday - 2)
        end
        return os.date("%Y-%m-%d", os.time() - offsetDays * 86400)
    end

    local function monthStartStr()
        local t = os.date("*t")
        return string.format("%04d-%02d-01", t.year, t.month)
    end

    -- ---- aggregation ------------------------------------------------------

    local function sortedDescending(totalsTable)
        local list = {}
        for name, seconds in pairs(totalsTable) do
            table.insert(list, { name = name, seconds = seconds })
        end
        table.sort(list, function(a, b) return a.seconds > b.seconds end)
        return list
    end

    -- Per-app totals for [startStr, endStr] inclusive. Date strings compare
    -- correctly with plain >= / <= since they're zero-padded YYYY-MM-DD.
    local function appTotalsInRange(startStr, endStr)
        local totals = {}
        for _, e in ipairs(_G.activityLog) do
            if e.date >= startStr and e.date <= endStr then
                totals[e.app] = (totals[e.app] or 0) + e.seconds
            end
        end
        return sortedDescending(totals)
    end

    -- Per-app AND per-(app + window title) totals for a range — the
    -- "documents" view is really "distinct window titles", the closest
    -- proxy for a document that generalizes across arbitrary apps.
    local function appAndTitleTotalsInRange(startStr, endStr)
        local appTotals, titleTotals = {}, {}
        for _, e in ipairs(_G.activityLog) do
            if e.date >= startStr and e.date <= endStr then
                appTotals[e.app] = (appTotals[e.app] or 0) + e.seconds
                if e.title and e.title ~= "" then
                    local key = e.app .. " — " .. e.title
                    titleTotals[key] = (titleTotals[key] or 0) + e.seconds
                end
            end
        end
        return sortedDescending(appTotals), sortedDescending(titleTotals)
    end

    local function grandTotal(list)
        local total = 0
        for _, e in ipairs(list) do total = total + e.seconds end
        return total
    end

    -- ---- chooser ------------------------------------------------------------

    -- Selecting any row copies "name — time" to the clipboard
    _G.choosers.appTracker = hs.chooser.new(function(choice)
        if choice and choice.text then
            local copied = choice.text
            if choice.subText and choice.subText ~= "" then
                copied = copied .. " — " .. choice.subText
            end
            hs.pasteboard.setContents(copied)
            hs.alert.show("📋 Copied")
        end
    end)
    _G.choosers.appTracker:placeholderText("Today's activity — or type 'week' / 'month' / search…")

    local function renderActivityChoices(query)
        local q = (query or ""):match("^%s*(.-)%s*$")
        local qLower = q:lower()
        local choices = {}

        if qLower == "week" then
            local list = appTotalsInRange(weekStartStr(), todayStr())
            table.insert(choices, {
                text    = "📆 THIS WEEK — " .. core.formatDuration(grandTotal(list)) .. " total",
                subText = "Clear the box for today, or type 'month' for other views",
            })
            for _, e in ipairs(list) do
                table.insert(choices, { text = e.name, subText = core.formatDuration(e.seconds) })
            end

        elseif qLower == "month" then
            local appList, titleList = appAndTitleTotalsInRange(monthStartStr(), todayStr())
            table.insert(choices, { text = "🗓 THIS MONTH — TOP APPS", subText = "" })
            for i = 1, math.min(8, #appList) do
                table.insert(choices, { text = appList[i].name, subText = core.formatDuration(appList[i].seconds) })
            end
            table.insert(choices, { text = "📄 THIS MONTH — TOP DOCUMENTS / WINDOWS", subText = "" })
            if #titleList == 0 then
                table.insert(choices, { text = "(no window titles recorded yet)", subText = "" })
            end
            for i = 1, math.min(8, #titleList) do
                table.insert(choices, { text = titleList[i].name, subText = core.formatDuration(titleList[i].seconds) })
            end

        elseif qLower == "" then
            local list = appTotalsInRange(todayStr(), todayStr())
            table.insert(choices, {
                text    = "📅 TODAY — " .. core.formatDuration(grandTotal(list)) .. " total",
                subText = "Type 'week' or 'month' for other views, or search an app/doc name",
            })
            if #list == 0 then
                table.insert(choices, { text = "No activity recorded yet today", subText = "" })
            end
            for _, e in ipairs(list) do
                table.insert(choices, { text = e.name, subText = core.formatDuration(e.seconds) })
            end

        else
            -- Search: app name or window title, across ALL saved history
            local matchTotals = {}
            for _, e in ipairs(_G.activityLog) do
                local haystack = (e.app .. " " .. (e.title or "")):lower()
                if haystack:find(qLower, 1, true) then
                    local key = e.app .. ((e.title and e.title ~= "") and (" — " .. e.title) or "")
                    matchTotals[key] = (matchTotals[key] or 0) + e.seconds
                end
            end
            local list = sortedDescending(matchTotals)
            if #list == 0 then
                table.insert(choices, { text = "No matches for \"" .. q .. "\"", subText = "Searches app names & window titles, all-time" })
            else
                table.insert(choices, { text = "🔎 Matches for \"" .. q .. "\" — all time", subText = "" })
                for _, e in ipairs(list) do
                    table.insert(choices, { text = e.name, subText = core.formatDuration(e.seconds) })
                end
            end
        end

        _G.choosers.appTracker:choices(choices)
    end

    _G.choosers.appTracker:queryChangedCallback(function(query)
        local ok, err = pcall(renderActivityChoices, query)
        if not ok then
            print("🚨 Activity chooser render error: " .. tostring(err))
            _G.choosers.appTracker:choices({
                { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
            })
        end
    end)

    -- ---- scheduled reports ------------------------------------------------
    -- Daily at activityDailyReportTime: today's apps ranked most→least used,
    -- shown in minutes. Weekly on activityWeeklyReportWeekday at
    -- activityWeeklyReportTime: the same ranking for the LAST 7 full days
    -- (i.e. the 7 days ending yesterday — so Monday's report covers Mon–Sun
    -- of last week and doesn't mix in the fresh morning's activity).
    -- Reports appear as a popup you can search & copy rows from, exactly
    -- like the ⌘⌥⇧0 tracker. Note: like any popup here, it takes keyboard
    -- focus when it appears — it will interrupt typing at report time.
    local activityDailyReportTime     = "16:00"  -- 4:00 PM, 24h format
    local activityWeeklyReportTime    = "07:30"  -- 7:30 AM, 24h format
    local activityWeeklyReportWeekday = 1        -- 0=Sun 1=Mon 2=Tue … 6=Sat
                                                  -- (also fires Fri=5, see timer below)

    local function minutesLabel(seconds)
        local mins = math.floor(seconds / 60 + 0.5)
        if mins < 1 then return "under 1 min" end
        return mins .. " min"
    end

    -- Report chooser: registered in _G.choosers so it follows the frontmost
    -- app's screen and participates in nudging; selecting a row copies it.
    _G.choosers.activityReport = hs.chooser.new(function(choice)
        if choice and choice.text then
            local copied = choice.text
            if choice.subText and choice.subText ~= "" then
                copied = copied .. " — " .. choice.subText
            end
            hs.pasteboard.setContents(copied)
            hs.alert.show("📋 Copied")
        end
    end)
    _G.choosers.activityReport:placeholderText("Activity report — Esc to close, Enter copies a row")
    -- 6.16.6 REVERT: hideOnLostFocus is not a real hs.chooser method — it
    -- doesn't exist in the actual API, only in a bad assumption of mine, and
    -- calling it crashed the ENTIRE config on load ("attempt to call a nil
    -- value"). hs.chooser has no supported way to suppress click-away
    -- dismissal. Escape already closes it via the normal completion
    -- callback (choice == nil), which was the one part of the ask this
    -- popup could actually guarantee.

    local function showActivityReport(titleText, startStr, endStr)
        local list = appTotalsInRange(startStr, endStr)
        local choices = {}
        table.insert(choices, {
            text    = titleText .. " — " .. core.formatDuration(grandTotal(list)) .. " total",
            subText = (startStr == endStr) and startStr or (startStr .. " → " .. endStr),
        })
        if #list == 0 then
            table.insert(choices, { text = "No activity recorded in this period", subText = "" })
        end
        for i, e in ipairs(list) do
            table.insert(choices, { text = i .. ". " .. e.name, subText = minutesLabel(e.seconds) })
        end
        _G.choosers.activityReport:choices(choices)
        _G.choosers.activityReport:rows(math.min(#choices, 12))
        core.showPopup(_G.choosers.activityReport)
    end

    local function showDailyActivityReport()
        showActivityReport("📊 DAILY REPORT", todayStr(), todayStr())
    end

    local function showWeeklyActivityReport()
        local endStr   = os.date("%Y-%m-%d", os.time() - 86400)       -- yesterday
        local startStr = os.date("%Y-%m-%d", os.time() - 7 * 86400)   -- 7 days back
        showActivityReport("🗓 WEEKLY RECAP", startStr, endStr)
    end

    -- hs.timer.doAt(time, "1d", fn) fires at that clock time every day.
    -- Held in _G so Lua garbage collection can't silently kill them.
    _G.activityDailyReportTimer = hs.timer.doAt(activityDailyReportTime, "1d", showDailyActivityReport)
    _G.activityWeeklyReportTimer = hs.timer.doAt(activityWeeklyReportTime, "1d", function()
        local wd = tonumber(os.date("%w"))
        if wd == activityWeeklyReportWeekday or wd == 5 then   -- 5 = Friday
            showWeeklyActivityReport()
        end
    end)
end

return M
