-- =====================================================================
-- MODULE: TAB SEARCH (⇪⇧') — every open tab, from anywhere
-- =====================================================================
-- LL: "Can we search my current open tabs and then jump to that tab,
-- from another application or on the desktop, in a folder? Essentially
-- anywhere but the app can I do this."
--
-- Yes — that is the whole point of it being on ⇪. Press ⇪⇧' in Finder,
-- in Word, on the desktop, in a Ghostty window, type three letters of
-- the page's title, press ⏎, and that tab is in front of you. The
-- browser does not need to be frontmost and does not need to be visible.
--
--        ⇪⇧'        every open tab in every running browser
--
-- 🌐 EVERY BROWSER THAT IS RUNNING, not just the default one. Chrome,
-- Safari, Edge, Brave and Arc are all asked, and each row says which
-- browser it came from — so two copies of the same documentation page in
-- two browsers are two distinguishable rows rather than one confusing
-- one. Add another Chromium browser to ts.chromium and it works
-- immediately; they share Chrome's AppleScript dictionary.
--
-- ---------------------------------------------------------------------
-- 🚨 IT ONLY ASKS BROWSERS THAT ARE ALREADY RUNNING, AND THAT IS NOT
-- POLITENESS
-- ---------------------------------------------------------------------
-- Naming an application in AppleScript LAUNCHES it. A scan that says
-- `tell application "Safari" to get every tab` on a Mac where Safari is
-- closed OPENS SAFARI — so a keystroke meant to find a tab you already
-- have would start a browser you did not want, every time, and the list
-- would then contain that browser's blank new tab.
--
-- So the script asks System Events for the running process list FIRST
-- and skips anything not in it. This is the same hazard the pause key in
-- power_tools has, guarded the same way, and it is worth stating twice
-- because it is invisible until it happens to you.
--
-- ---------------------------------------------------------------------
-- 🚨 WHY THE SCRIPT RUNS IN A CHILD PROCESS
-- ---------------------------------------------------------------------
-- An AppleScript error raised inside Hammerspoon's own Apple Event
-- handler is an Objective-C exception. It unwinds straight past pcall —
-- Lua's pcall catches Lua errors, and this is not one — to the uncaught
-- handler, which kills the app. /usr/bin/osascript is the same
-- AppleScript in a separate process: if it throws, hangs, or dies, a
-- child process dies and we get an exit code. universal_actions.lua
-- documents this at length, and it learned it from a crash.
--
-- ---------------------------------------------------------------------
-- ⚠️ WINDOW AND TAB NUMBERS ARE POSITIONS, AND POSITIONS MOVE
-- ---------------------------------------------------------------------
-- A browser tab has no stable identifier AppleScript can address; you
-- reach it as "tab 4 of window 2", which is where it happens to be
-- sitting right now. Drag a tab, close one, or open a window between the
-- scan and the jump and those numbers point somewhere else.
--
-- The defence is that the list is NEVER CACHED — every press rescans, so
-- the numbers are milliseconds old — and the jump VERIFIES: it compares
-- the tab's URL against the one that was picked, and says so rather than
-- silently leaving you on the wrong page. That check costs one extra
-- AppleScript line and is the difference between "it took me to the
-- wrong tab" and "it told me the tab had moved".
--
-- ---------------------------------------------------------------------
-- 🔐 IT NEEDS AUTOMATION PERMISSION, PER BROWSER
-- ---------------------------------------------------------------------
-- The first time this asks Chrome for its tabs, macOS shows the
-- "Hammerspoon wants to control Google Chrome" dialog. Say yes once per
-- browser. If you say no, that browser contributes no rows and the
-- report says which one and why — rather than the list quietly being
-- short. ⇪, "automation" opens the pane where that is changed.
-- =====================================================================

local M = {
    name  = "Tab Search",
    order = 13.99,
    family = "find",
    cheatsheet = {
        title = "🗂 TAB SEARCH (⇪⇧' — every open tab, from anywhere)",
        entries = {
            { "⇪⇧'",    "Every tab in every running browser — ⏎ jumps to it" },
            { "where",  "From ANY app: Finder, Word, the desktop, a terminal" },
            { "which",  "Each row names its browser — two copies stay two rows" },
            { "search", "Titles AND URLs, so “github” finds it either way" },
            { "needs",  "Automation permission, once per browser (⇪, “automation”)" },
            { "check",  "_G.tabReport() — which browsers answered, and how many" },
        },
    },
}

function M.setup(core)
    local ts = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ts.enabled   = true
    ts.key       = "'"            -- ⇪⇧'  (⇪' pauses media)
    ts.keyMods   = { "shift" }
    -- Every Chromium browser shares Chrome's AppleScript dictionary, so
    -- adding one here is the whole job. Safari is separate below because
    -- its dictionary genuinely differs (current tab, name, not title).
    ts.chromium  = { "Google Chrome", "Microsoft Edge", "Brave Browser",
                     "Arc", "Vivaldi", "Chromium", "Google Chrome Canary" }
    ts.webkit    = { "Safari", "Safari Technology Preview" }
    ts.scanTimeout = 6.0          -- seconds before the scan is abandoned
    ts.titleChars  = 90           -- title length shown in a row
    ts.urlChars    = 70           -- URL length shown in a row
    -- ----------------------------------------------------------------------

    ts.rows       = {}            -- index -> { browser, win, tab, url, title }
    ts.chooser    = nil           -- HELD: an unreferenced hs.chooser is collected
    ts.scanTask, ts.jumpTask = nil, nil   -- HELD
    ts.scanTimer  = nil           -- HELD
    ts.pending    = false
    ts.lastCounts = {}            -- browser -> how many tabs it reported
    ts.lastMs, ts.scans, ts.jumps = 0, 0, 0
    ts.lastNote   = nil

    local function say(m)  if _G.diag then _G.diag.say("tabSearch", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("tabSearch", m) end end
    local function note(m) ts.lastNote = m ; warn(m) end

    -- ---- the scan --------------------------------------------------------
    -- 🚨 THE RUNNING CHECK IS THE FIRST THING THE SCRIPT DOES. See the
    -- header: without it this key launches every browser you own.
    --
    -- ⚠️ `using terms from application "Google Chrome"` is what makes the
    -- dynamic `tell application bn` work at all. AppleScript resolves an
    -- application's vocabulary at COMPILE time, and a tell whose target is
    -- a variable has no vocabulary to resolve — so `tabs`, `title` and
    -- `active tab index` are unknown words and the script fails to
    -- compile. The using-terms block lends it Chrome's dictionary, which
    -- every Chromium browser answers to.
    --
    -- 🚨 6.152.0 — AND THE SAFARI BRANCH NEEDED THE SAME LOAN, AND NEVER
    -- HAD IT. Without `using terms from application "Safari"`, the bare
    -- word `tab` in `tab ti of window wi` parses as AppleScript's built-in
    -- tab CHARACTER constant, and the `ti` after it is "Expected end of
    -- line but found identifier" — a COMPILE error at character ~577,
    -- which kills the WHOLE script before any browser is asked. So every
    -- single press exited 1 and the alert blamed Automation permission,
    -- which was never the problem. Straight off LL's ⛔ errors section:
    -- "osascript exited 1: 577:579: syntax error". The jump script had
    -- the identical flaw (`current tab` / `tab ti`). Both branches now
    -- borrow Safari's dictionary, which is installed on every Mac.
    --
    -- Each window is wrapped in its own try: a browser with one window
    -- that refuses to describe itself must cost that window, not the
    -- browser, and certainly not the other browsers after it.
    ts.SEP = "\31"    -- ASCII unit separator: cannot occur in a title or URL

    ts.scanScript = [[
on run argv
    set sep to character id 31
    set out to ""
    tell application "System Events" to set runningNames to name of every process
    repeat with b in argv
        set bn to b as text
        if runningNames contains bn then
            if bn starts with "Safari" then
                using terms from application "Safari"
                    try
                        tell application bn
                            repeat with wi from 1 to (count of windows)
                                try
                                    repeat with ti from 1 to (count of tabs of window wi)
                                        set t to tab ti of window wi
                                        set out to out & bn & sep & wi & sep & ti & sep & (URL of t) & sep & (name of t) & linefeed
                                    end repeat
                                end try
                            end repeat
                        end tell
                    end try
                end using terms from
            else
                using terms from application "Google Chrome"
                    try
                        tell application bn
                            repeat with wi from 1 to (count of windows)
                                try
                                    repeat with ti from 1 to (count of tabs of window wi)
                                        set t to tab ti of window wi
                                        set out to out & bn & sep & wi & sep & ti & sep & (URL of t) & sep & (title of t) & linefeed
                                    end repeat
                                end try
                            end repeat
                        end tell
                    end try
                end using terms from
            end if
        end if
    end repeat
    return out
end run]]

    -- One line per tab: browser ␟ window ␟ tab ␟ url ␟ title.
    -- A line that does not have all five fields is DROPPED rather than
    -- half-read: a row whose window number is missing would jump
    -- somewhere arbitrary, and there is no safe default for "which
    -- window".
    function ts.parse(out)
        local rows, counts = {}, {}
        for line in tostring(out or ""):gmatch("[^\r\n]+") do
            local f = {}
            for field in (line .. ts.SEP):gmatch("([^" .. ts.SEP .. "]*)" .. ts.SEP) do
                f[#f + 1] = field
            end
            local browser, win, tab, url, title = f[1], tonumber(f[2]),
                                                  tonumber(f[3]), f[4], f[5]
            if browser and browser ~= "" and win and tab and url then
                rows[#rows + 1] = {
                    browser = browser, win = win, tab = tab,
                    url = url, title = (title ~= "" and title) or url,
                }
                counts[browser] = (counts[browser] or 0) + 1
            end
        end
        return rows, counts
    end

    function ts.browsers()
        local all = {}
        for _, b in ipairs(ts.webkit)   do all[#all + 1] = b end
        for _, b in ipairs(ts.chromium) do all[#all + 1] = b end
        return all
    end

    function ts.scan(done)
        if ts.pending then return false end
        local t0 = hs.timer.secondsSinceEpoch()
        local args = { "-e", ts.scanScript }
        for _, b in ipairs(ts.browsers()) do args[#args + 1] = b end
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(code, out, err)
                ts.pending = false
                ts.scanTask = nil
                if ts.scanTimer then
                    pcall(function() ts.scanTimer:stop() end)
                    ts.scanTimer = nil
                end
                ts.lastMs = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
                ts.scans  = ts.scans + 1
                local rows, counts = ts.parse(out)
                ts.lastCounts = counts
                if #rows == 0 and code ~= 0 then
                    note("osascript exited " .. tostring(code) .. ": "
                         .. tostring(err):gsub("%s+", " "):sub(1, 160))
                end
                pcall(done, rows)
            end, args)
        end)
        if not (okNew and t) then
            note("could not start osascript — no tabs can be read")
            pcall(done, {})
            return false
        end
        ts.pending  = true
        ts.scanTask = t
        pcall(function() t:start() end)
        ts.scanTimer = hs.timer.doAfter(ts.scanTimeout, function()
            ts.scanTimer = nil
            if not ts.pending then return end
            ts.pending = false
            pcall(function() t:terminate() end)
            ts.scanTask = nil
            note("no browser answered within " .. ts.scanTimeout .. "s")
            if _G.notices then
                _G.notices.record("tabSearch", "tab scan timed out", ts.lastNote)
            end
            hs.alert.show("🗂 No browser answered in " .. ts.scanTimeout
                .. "s.\nIf this is the first run, check for an Automation prompt.", 5)
        end)
        return true
    end

    -- ---- the jump --------------------------------------------------------
    -- 🚨 IT VERIFIES BEFORE IT REPORTS. Window and tab numbers are
    -- positions, and a tab dragged between the scan and the jump moves
    -- them. The script returns the URL of whatever it actually landed on
    -- and Lua compares it, so "the tab moved" is something you are told
    -- rather than something you discover by reading the wrong page.
    ts.jumpScript = [[
on run argv
    set bn to item 1 of argv
    set wi to (item 2 of argv) as integer
    set ti to (item 3 of argv) as integer
    if bn starts with "Safari" then
        using terms from application "Safari"
            tell application bn
                set current tab of window wi to tab ti of window wi
                set index of window wi to 1
                activate
                return URL of current tab of window wi
            end tell
        end using terms from
    else
        using terms from application "Google Chrome"
            tell application bn
                set active tab index of window wi to ti
                set index of window wi to 1
                activate
                return URL of active tab of window wi
            end tell
        end using terms from
    end if
end run]]

    function ts.jump(row)
        if not row then return false end
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(code, out, err)
                ts.jumpTask = nil
                local landed = tostring(out or ""):match("^%s*(.-)%s*$")
                if code ~= 0 or landed == "" then
                    note("could not reach " .. row.browser .. " window "
                         .. row.win .. " tab " .. row.tab .. ": "
                         .. tostring(err):gsub("%s+", " "):sub(1, 160))
                    hs.alert.show("🗂 " .. row.browser
                        .. " would not switch to that tab", 3.5)
                    return
                end
                -- 🚨 THE COUNT COMES AFTER THE VERIFY, not before it. The
                -- first draft incremented here and then checked, which
                -- made _G.tabReport() count a jump that landed on the
                -- WRONG PAGE as a successful jump — a report that agrees
                -- with you about a thing that did not happen is worse
                -- than no report. The suite asserts the order.
                if landed ~= row.url then
                    note("landed on " .. landed .. " instead of " .. row.url)
                    hs.alert.show("🗂 That tab moved — you are on\n"
                        .. landed:sub(1, 70)
                        .. "\nPress ⇪⇧' again for a fresh list", 5)
                    return
                end
                ts.jumps = ts.jumps + 1
                say("jumped to " .. row.browser .. " " .. row.url)
            end, { "-e", ts.jumpScript, row.browser,
                   tostring(row.win), tostring(row.tab) })
        end)
        if not (okNew and t) then
            note("could not start osascript for the jump")
            hs.alert.show("🗂 Could not switch tabs", 3)
            return false
        end
        ts.jumpTask = t
        pcall(function() t:start() end)
        return true
    end

    -- ---- the picker ------------------------------------------------------
    -- ⚠️ The row carries an INTEGER index into ts.rows. Every value in a
    -- chooser row crosses into Objective-C, a nested table does not
    -- survive, and LuaSkin discards the WHOLE list and logs rather than
    -- throwing — an empty panel with nothing to catch. Same rule as ⇪⇧T's
    -- snippets (6.109.0).
    function ts.choices(rows)
        local out = {}
        for i, r in ipairs(rows) do
            local title = r.title
            if #title > ts.titleChars then title = title:sub(1, ts.titleChars - 1) .. "…" end
            local url = r.url:gsub("^https?://", "")
            if #url > ts.urlChars then url = url:sub(1, ts.urlChars - 1) .. "…" end
            out[#out + 1] = {
                text    = title,
                subText = r.browser .. "   ·   " .. url,
                idx     = i,
            }
        end
        return out
    end

    function ts.show()
        if not ts.enabled then return end
        -- 🚨 NEVER CACHED. See the header: the numbers in each row are
        -- positions, and a list from ten seconds ago describes a browser
        -- that has moved on.
        ts.scan(function(rows)
            ts.rows = rows
            if #rows == 0 then
                hs.alert.show("🗂 No open tabs found.\nNo browser is running, "
                    .. "or none has granted Automation yet.", 4)
                return
            end
            if not ts.chooser then
                ts.chooser = hs.chooser.new(function(pick)
                    if not pick then return end
                    ts.jump(ts.rows[pick.idx])
                end)
                -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
                _G.choosers = _G.choosers or {}
                _G.choosers.tabSearch = ts.chooser
                pcall(function()
                    ts.chooser:searchSubText(true)
                    ts.chooser:width(45)
                end)
            end
            local names = {}
            for b, n in pairs(ts.lastCounts) do
                names[#names + 1] = b .. " " .. n
            end
            table.sort(names)
            ts.chooser:choices(ts.choices(rows))
            ts.chooser:placeholderText(#rows .. " tabs — "
                .. table.concat(names, "  ·  "))
            ts.chooser:query("")
            -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
            -- LAST picker's coordinates standing in _G.lastPopupPlacement,
            -- and window_move computes its grab box from that record. It
            -- could not be dragged at all until 6.127.0.
            if core.showPopup then core.showPopup(ts.chooser)
            else ts.chooser:show() end
        end)
    end

    -- ---- the report ------------------------------------------------------
    function _G.tabReport()
        local L = { "🗂 TAB SEARCH" }
        L[#L + 1] = "   scans   : " .. ts.scans .. " (last took " .. ts.lastMs .. "ms)"
        L[#L + 1] = "   jumps   : " .. ts.jumps
        local any = false
        for b, n in pairs(ts.lastCounts) do
            any = true
            L[#L + 1] = ("      %-24s %d tabs"):format(b, n)
        end
        if not any then
            L[#L + 1] = "   browsers: none answered — is one running, and has it"
            L[#L + 1] = "             granted Automation? (⇪, then “automation”)"
        end
        L[#L + 1] = "   asked   : " .. table.concat(ts.browsers(), ", ")
        if ts.lastNote then L[#L + 1] = "   last problem: " .. ts.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if ts.enabled then
        core.hyperAddShortcut(ts.keyMods, ts.key, function() ts.show() end,
                              "tab search")
    end
    core.provide("tabs.show",   function() return ts.show() end)
    core.provide("tabs.report", function() return _G.tabReport() end)

    _G.tabSearch = ts
    M.ts     = ts
    M.config = ts
end

return M
