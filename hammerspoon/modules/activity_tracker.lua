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
--
-- 📄 6.104.0 — THE DOCUMENT WATCHER WAS MERGED IN HERE AND DELETED.
-- ⇪⇧W (the documents you worked in) and ⇪⇧E (edit or delete one) now
-- live at the bottom of this file, DERIVED from the sessions above
-- instead of recorded a second time by a second 5-second timer into a
-- second CSV. The full reasoning, and what the merge costs, is in the
-- ⚰️ block down there rather than repeated here.

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Activity Tracker",
    order = 4,
    family = "time",
    cheatsheet = {
        title = "📊 ACTIVITY TRACKER",
        entries = {
            { "⇪0", "Open — today's totals" },
            { "type: week", "This week's totals" },
            { "type: month", "Top apps & documents this month" },
            { "type: anything", "Search all saved history" },
            { "Enter", "Copy row to clipboard" },
            { "⇪⇧W", "DOCUMENTS you worked in — name · time · day, searchable" },
            { "☑️ row", "Copy several: pick rows with Enter, then copy together" },
            { "⇪⇧E", "Edit or delete a document entry (clear the name = delete)" },
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
            -- ⚡ 6.44.4 — THE SEARCH STRING IS BUILT ONCE PER ENTRY, NOT ONCE
            -- PER KEYSTROKE. This loop runs from queryChangedCallback, so it
            -- fires on EVERY character you type, over the whole retained
            -- history — 120 days of raw sessions, one row per window focus
            -- change. Rebuilding "app .. title" and lowercasing it every
            -- time measured 18ms per keystroke at 10,000 rows and 78ms at
            -- 40,000: typing lag you can feel, on the main thread.
            -- Caching it on the entry is ~18x faster and costs one extra
            -- string per row. The field is prefixed with _ and every writer
            -- in this file lists its columns explicitly, so it never reaches
            -- the CSV.
            local matchTotals = {}
            for _, e in ipairs(_G.activityLog) do
                local haystack = e._hay
                if not haystack then
                    haystack = (e.app .. " " .. (e.title or "")):lower()
                    e._hay = haystack
                end
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
    --
    -- 📊 6.105.0 — THE 16:00 POPUP IS OFF BY DEFAULT. It opened a chooser
    -- that takes the keyboard, one minute before the Quick Append Pad's
    -- 16:01 review opens another one. Two panels a minute apart, both
    -- arriving mid-sentence, is how a useful summary becomes a thing you
    -- dismiss without reading. modules/daily_rollup.lua now shows the same
    -- numbers on a card that takes no focus at all, and folds the
    -- documents and notes in beside them.
    --
    -- Nothing was deleted: set this true for the old behaviour, and the
    -- report is on ⇪space's 🔧 rows and _G.activityDailyReport() either
    -- way.
    --
    -- 🚨 THE ASSIGNMENT STAYS ON ONE LINE. test_diagnostics greps every
    -- shipped file for a line that STARTS with hs.timer.do — a timer
    -- created and thrown away, which is collected and then never fires.
    -- Wrapping this at the `=` put `hs.timer.doAt(` at the head of its own
    -- line and tripped that check, which was right to complain: it cannot
    -- tell my line break from the bug it is looking for.
    local activityDailyReportPopup = false
    if activityDailyReportPopup then
        _G.activityDailyReportTimer = hs.timer.doAt(activityDailyReportTime, "1d", showDailyActivityReport)
    end
    _G.activityWeeklyReportTimer = hs.timer.doAt(activityWeeklyReportTime, "1d", function()
        local wd = tonumber(os.date("%w"))
        if wd == activityWeeklyReportWeekday or wd == 5 then   -- 5 = Friday
            showWeeklyActivityReport()
        end
    end)
    -- Published for the hotkey handlers still living in init.lua. Before
    -- this, that code called renderActivityChoices() directly — a name
    -- that left with this module, turning ⇪0 into a nil-global crash the
    -- moment it was pressed.
    core.provide("activity.renderChoices", renderActivityChoices)

    -- 📊 6.105.0 — the numbers, without the panel. daily_rollup reads this
    -- rather than _G.activityLog directly: the log's shape is this
    -- module's business, and a second module walking it is a second place
    -- that has to be right about what a session record looks like.
    core.provide("activity.dayTotals", function(dateStr)
        dateStr = dateStr or todayStr()
        local list  = appTotalsInRange(dateStr, dateStr)
        local total = 0
        for _, e in ipairs(list) do total = total + e.seconds end
        return { date = dateStr, total = total, apps = list }
    end)
    core.provide("activity.dailyReport", function()
        showDailyActivityReport()
        return true
    end)
    _G.activityDailyReport = showDailyActivityReport

    -- =====================================================================
    -- 📄 DOCUMENTS — ⇪⇧W the list · ⇪⇧E edit or delete   (6.104.0)
    -- =====================================================================
    -- ⚰️ THIS REPLACES modules/document_watcher.lua, WHICH IS DELETED.
    -- Both modules polled the frontmost window every 5 seconds and both
    -- accumulated time from it — one into activity_history.csv keyed by
    -- app+title, one into doc_wather.csv keyed by a filename pulled out of
    -- that same title. Two timers, two CSVs, two sets of rounding, one
    -- signal. When they disagreed there was no way to say which was right.
    --
    -- 🔑 WHY THIS FILE IS THE SURVIVOR: it stores strictly MORE. A window
    -- title contains the filename; a filename does not contain the title.
    -- So the documents view is DERIVED here rather than recorded twice —
    -- the two can no longer disagree, because there is only one of them.
    --
    -- ⚖️ WHAT THE MERGE COSTS, stated plainly:
    --   • doc_wather.csv stops being written. It is not deleted — old rows
    --     stay readable in Numbers, and ⇪space still reads the file if it
    --     is there. Nothing new lands in it.
    --   • Its rows do not migrate. They are one-per-document-per-day
    --     totals; these are sessions. Adding them would double-count every
    --     day both modules ran, which is worse than a clean cut-over.
    --   • Deleting a document here removes its SESSIONS, so that time also
    --     leaves the app totals. That is the honest meaning of "this
    --     should not have been recorded", and the prompt says so before
    --     you confirm.
    --
    -- Its own function so this section gets a fresh Lua local budget —
    -- setup() above is already near the 200-local ceiling (see the note at
    -- activityIdleThreshold). Same shape document_watcher used.
    ;(function()

    local docMaxRows = 500      -- rows the pickers show at once

    -- Window titles look like "Report.docx — Word", "notes.md - Sublime",
    -- "Untitled.txt — Edited". Take the part before the separator and insist
    -- it looks like a real filename. Anything else is dumped: a wrong entry
    -- is worse than a missing one in a log you are going to trust.
    -- (Ported unchanged from document_watcher — it was the good part.)
    local docSeparators = { " — ", " – ", " - " }

    local function docFileFromTitle(title, appName)
        if type(title) ~= "string" then return nil end
        local head = title
        for _, sep in ipairs(docSeparators) do
            local cut = head:find(sep, 1, true)
            if cut then head = head:sub(1, cut - 1) end
        end
        head = head:gsub("^%s+", ""):gsub("%s+$", "")
        if head == "" then return nil end
        if appName and head == appName then return nil end
        -- Must end in a plausible extension.
        local base, ext = head:match("^(.+)%.([%a%d]+)$")
        if not base or not ext then return nil end
        if #ext < 1 or #ext > 6 then return nil end
        if base:match("^%s*$") then return nil end
        return head
    end

    -- One row per document per day, newest day first, longest first inside
    -- a day — the shape ⇪⇧W has always had, now computed from the sessions
    -- instead of kept alongside them.
    local function docRows()
        local index, order = {}, {}
        for _, e in ipairs(_G.activityLog or {}) do
            local file = docFileFromTitle(e.title, e.app)
            if file then
                local key = e.date .. "|" .. file
                local row = index[key]
                if not row then
                    row = { date = e.date, file = file, app = e.app, secs = 0, key = key }
                    index[key] = row
                    order[#order + 1] = row
                end
                row.secs = row.secs + (tonumber(e.seconds) or 0)
            end
        end
        table.sort(order, function(a, b)
            if a.date ~= b.date then return a.date > b.date end
            if a.secs ~= b.secs then return a.secs > b.secs end
            return a.file < b.file
        end)
        return order
    end

    local function docRowText(r)
        return r.file .. "   ·   " .. core.formatDuration(r.secs)
    end

    -- Every session that feeds one document row. The join is recomputed
    -- rather than stored, so an edit can never act on a stale index.
    local function docSessionsFor(row)
        local hits = {}
        for i, e in ipairs(_G.activityLog or {}) do
            if e.date == row.date and docFileFromTitle(e.title, e.app) == row.file then
                hits[#hits + 1] = i
            end
        end
        return hits
    end

    local function docFindRow(key)
        for _, r in ipairs(docRows()) do
            if r.key == key then return r end
        end
        return nil
    end

    -- ---- the list (⇪⇧W) --------------------------------------------------
    -- ☑️ Select mode, same as it always was: hs.chooser is single-select
    -- with no modifier reporting, so Enter TAGS rows and one action row
    -- copies them together. Supported API, same outcome.
    local docSelect, docTagged = false, {}

    local function docCount(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    local function docTodayTally(rows)
        -- os.date() with no time argument reads the WALL CLOCK, while every
        -- row is stamped from os.time(). The same thing on a real Mac right
        -- up until they aren't — across midnight, or under a test clock —
        -- and then "documents today" silently reports zero. Same source for
        -- both, always.
        local today, count, secs = os.date("%Y-%m-%d", os.time()), 0, 0
        for _, r in ipairs(rows) do
            if r.date == today then count = count + 1; secs = secs + r.secs end
        end
        return count, secs
    end

    local function docCopyRows(rows)
        local lines = {}
        for _, r in ipairs(rows) do
            lines[#lines + 1] = r.date .. "  " .. r.file .. "  "
                                .. core.formatDuration(r.secs)
        end
        hs.pasteboard.setContents(table.concat(lines, "\n"))
        hs.alert.show("📋 Copied " .. #lines .. " row"
                      .. ((#lines == 1) and "" or "s"))
    end

    local function renderDocList(query)
        local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
        local rows, choices = docRows(), {}
        local n, secs = docTodayTally(rows)
        table.insert(choices, {
            text    = "📄 " .. n .. " document" .. ((n == 1) and "" or "s")
                      .. " today   ·   " .. core.formatDuration(secs),
            subText = "Derived from the sessions this tracker already records"
                      .. " — ⇪⇧E edits or deletes one",
        })
        if docSelect then
            local picked = docCount(docTagged)
            table.insert(choices, {
                text    = (picked == 0) and "☑️ Nothing picked yet"
                          or ("📋 Copy the " .. picked .. " row"
                              .. ((picked == 1) and "" or "s") .. " I picked"),
                subText = (picked == 0)
                          and "Go down the list and press Enter on the ones you want"
                          or "Press Enter HERE to copy them all",
                action  = "copytagged",
            })
            table.insert(choices, { text = "✖️ Never mind — go back",
                                    subText = "Forget the picks",
                                    action = "selectoff" })
        else
            table.insert(choices, { text = "☑️ Copy several at once…",
                                    subText = "Pick rows one at a time, then copy them together",
                                    action = "selecton" })
        end
        local shown = 0
        for _, r in ipairs(rows) do
            local hay = (r.file .. " " .. r.date .. " " .. (r.app or "")):lower()
            if q == "" or hay:find(q, 1, true) then
                local picked = docTagged[r.key]
                table.insert(choices, {
                    text    = (picked and "✓ " or "") .. docRowText(r),
                    subText = r.date .. "  ·  " .. (r.app or "?")
                              .. (docSelect
                                  and (picked and "  ·  PICKED — Enter unpicks it"
                                              or "  ·  Enter adds it to the copy list")
                                  or "  ·  Enter copies this row"),
                    action  = "row", key = r.key,
                })
                shown = shown + 1
                if shown >= docMaxRows then break end
            end
        end
        if shown == 0 then
            table.insert(choices, { text = "No documents match",
                                    subText = "Titles only count when they look like a filename" })
        end
        _G.choosers.activityDocs:choices(choices)
    end

    _G.choosers.activityDocs = hs.chooser.new(function(c)
        if not (c and c.action) then return end
        local function reopen()
            renderDocList(""); _G.choosers.activityDocs:query("")
            core.showPopup(_G.choosers.activityDocs)
        end
        if c.action == "selecton"  then docSelect, docTagged = true,  {} reopen() return end
        if c.action == "selectoff" then docSelect, docTagged = false, {} reopen() return end
        if c.action == "copytagged" then
            local picked = {}
            for _, r in ipairs(docRows()) do
                if docTagged[r.key] then picked[#picked + 1] = r end
            end
            docSelect, docTagged = false, {}
            if #picked > 0 then docCopyRows(picked)
            else hs.alert.show("Nothing picked — press Enter on the rows you want first") end
            return
        end
        if c.action ~= "row" or not c.key then return end
        if docSelect then
            docTagged[c.key] = (not docTagged[c.key]) or nil
            reopen(); return
        end
        local row = docFindRow(c.key)
        if row then docCopyRows({ row }) end
    end)
    _G.choosers.activityDocs:placeholderText("Documents you worked in — search name, date or app")
    _G.choosers.activityDocs:queryChangedCallback(function(q)
        pcall(renderDocList, q)
    end)

    -- ---- edit / delete (⇪⇧E) ---------------------------------------------
    local docEditSelect, docEditTagged = false, {}

    local function renderDocEdit(query)
        local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
        local rows, choices = docRows(), {}
        if #rows == 0 then
            -- An empty log gets no action rows — there is nothing to pick.
        elseif docEditSelect then
            local picked = docCount(docEditTagged)
            table.insert(choices, {
                text    = (picked == 0) and "☑️ Nothing picked yet"
                          or ("🗑 Delete the " .. picked .. " entr"
                              .. ((picked == 1) and "y" or "ies") .. " I picked"),
                subText = (picked == 0)
                          and "Go down the list and press Enter on the ones to delete"
                          or "Press Enter HERE to delete them all — their time leaves the app totals too",
                action  = "deletetagged",
            })
            table.insert(choices, { text = "✖️ Never mind — go back",
                                    subText = "Forget the picks and return to one-at-a-time editing",
                                    action = "editselectoff" })
        else
            table.insert(choices, { text = "☑️ Delete several at once…",
                                    subText = "Pick rows one at a time, then delete them together",
                                    action = "editselecton" })
        end
        local shown = 0
        for _, r in ipairs(rows) do
            local hay = (r.file .. " " .. r.date):lower()
            if q == "" or hay:find(q, 1, true) then
                local picked = docEditTagged[r.key]
                local hint
                if not docEditSelect then hint = "Enter to rename or delete"
                elseif picked then hint = "PICKED — Enter unpicks it"
                else hint = "Enter adds this to the delete list" end
                table.insert(choices, {
                    text    = (picked and "✓ " or "✏️ ") .. docRowText(r),
                    subText = r.date .. "  ·  " .. hint,
                    action  = "edit", key = r.key,
                })
                shown = shown + 1
                if shown >= docMaxRows then break end
            end
        end
        if shown == 0 then
            table.insert(choices, { text = "Nothing to edit", subText = "No matching rows" })
        end
        _G.choosers.activityDocsEdit:choices(choices)
    end

    -- Delete every session behind one document row, newest index first so
    -- the earlier indices stay valid while removing.
    local function docDelete(row)
        local hits = docSessionsFor(row)
        for i = #hits, 1, -1 do table.remove(_G.activityLog, hits[i]) end
        return #hits
    end

    _G.choosers.activityDocsEdit = hs.chooser.new(function(c)
        if not (c and c.action) then return end
        local function reopen()
            renderDocEdit(""); _G.choosers.activityDocsEdit:query("")
            core.showPopup(_G.choosers.activityDocsEdit)
        end
        if c.action == "editselecton"  then docEditSelect, docEditTagged = true,  {} reopen() return end
        if c.action == "editselectoff" then docEditSelect, docEditTagged = false, {} reopen() return end
        if c.action == "deletetagged" then
            local picked = {}
            for _, r in ipairs(docRows()) do
                if docEditTagged[r.key] then picked[#picked + 1] = r end
            end
            docEditSelect, docEditTagged = false, {}
            local removed = 0
            for _, r in ipairs(picked) do removed = removed + docDelete(r) end
            if removed > 0 then
                if not rewriteActivityLog(_G.activityLog) then
                    hs.alert.show("⚠️ Could not write activity_history.csv — the deletion "
                                  .. "will come back on reload", 6)
                else
                    hs.alert.show("🗑 Deleted " .. #picked .. " document entr"
                                  .. ((#picked == 1) and "y" or "ies")
                                  .. " (" .. removed .. " sessions)")
                end
            else
                hs.alert.show("Nothing picked — press Enter on the rows you want first")
            end
            return
        end
        if c.action ~= "edit" or not c.key then return end
        local row = docFindRow(c.key)
        if not row then return end
        if docEditSelect then
            docEditTagged[c.key] = (not docEditTagged[c.key]) or nil
            reopen(); return
        end

        local hits = docSessionsFor(row)
        local button, text = hs.dialog.textPrompt(
            "Edit document entry",
            "File name for this entry.\nClear the field and press OK to DELETE it — "
                .. "that removes its " .. #hits .. " session"
                .. ((#hits == 1) and "" or "s")
                .. ", so the time leaves the app totals too.\n\n"
                .. row.date .. "  ·  " .. (row.app or "?") .. "  ·  "
                .. core.formatDuration(row.secs),
            row.file, "OK", "Cancel")
        if button ~= "OK" then return end
        text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            local removed = docDelete(row)
            if rewriteActivityLog(_G.activityLog) then
                hs.alert.show("🗑 Deleted " .. row.file .. " (" .. removed .. " sessions)")
            else
                hs.alert.show("⚠️ Could not write activity_history.csv", 6)
            end
        elseif text ~= row.file then
            -- The filename IS the title for these rows once the app suffix
            -- is stripped, so writing the new name straight into the title
            -- is what makes it come back as the new name.
            for _, i in ipairs(hits) do _G.activityLog[i].title = text end
            if rewriteActivityLog(_G.activityLog) then
                hs.alert.show("✏️ Renamed to " .. text)
            else
                hs.alert.show("⚠️ Could not write activity_history.csv", 6)
            end
        end
    end)
    _G.choosers.activityDocsEdit:placeholderText("Edit or delete a document entry")
    _G.choosers.activityDocsEdit:queryChangedCallback(function(q)
        pcall(renderDocEdit, q)
    end)

    -- ---- wiring ----------------------------------------------------------
    core.hyperAddShortcut({ "shift" }, "w", function()
        docSelect, docTagged = false, {}
        renderDocList(""); _G.choosers.activityDocs:query("")
        core.showPopup(_G.choosers.activityDocs)
    end, "activity — documents")

    core.hyperAddShortcut({ "shift" }, "e", function()
        docEditSelect, docEditTagged = false, {}
        renderDocEdit(""); _G.choosers.activityDocsEdit:query("")
        core.showPopup(_G.choosers.activityDocsEdit)
    end, "activity — document edit")

    core.provide("activity.docs",     function() return docRows() end)
    core.provide("activity.docList",  function() renderDocList("") end)

    -- Exposed for the suite, which drives the real renderers and the real
    -- delete path rather than a copy of them.
    _G.activityDocsForTest      = docRows
    _G.activityDocFileForTest   = docFileFromTitle
    _G.activityRenderDocsForTest = function(q)
        renderDocList(q); return _G.choosers.activityDocs.lastChoices
    end
    _G.activityRenderDocEditForTest = function(q)
        renderDocEdit(q); return _G.choosers.activityDocsEdit.lastChoices
    end
    _G.activityDocSelectForTest  = function(on) docSelect = on and true or false end
    _G.activityDocTaggedForTest  = function() return docTagged end
    _G.activityDocEditSelectForTest = function(on) docEditSelect = on and true or false end
    _G.activityDocEditTaggedForTest = function() return docEditTagged end
    _G.activityDocDeleteForTest  = function(key)
        local r = docFindRow(key)
        if not r then return 0 end
        local n = docDelete(r)
        rewriteActivityLog(_G.activityLog)
        return n
    end

    end)()
end

return M
