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
-- So nothing is ever NAMED to AppleScript unless it is already running,
-- and that check happens in LUA before osascript is started at all. It
-- used to be the script's first line — `tell application "System
-- Events" to set name of every process` — which meant an Apple Event
-- to a THIRD app, with its own Automation grant and its own launch,
-- before a single tab could be read. 6.439.0 moved it: Hammerspoon
-- already knows every running app and the list costs nothing. This is
-- the same hazard the pause key in power_tools has, guarded the same
-- way, and it is worth stating twice because it is invisible until it
-- happens to you.
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
    repeat with b in argv
        set bn to b as text
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

    -- 🗂 6.439.0 — WHICH BROWSERS ARE RUNNING IS DECIDED IN LUA NOW.
    -- The script's first line was
    --     tell application "System Events" to set name of every process
    -- which is an Apple Event to a THIRD app, needing its own Automation
    -- grant and its own launch, before a single tab is read — and
    -- System Events is a faceless background app that may have to start
    -- first. Hammerspoon already knows every running app, for free, from
    -- a list it asks for elsewhere. One fewer permission, one fewer app
    -- in the chain, and the answer arrives before osascript is even
    -- started.
    -- PURE given the app list, so the whole rule is proven with no Mac.
    function ts.runningFrom(names, want)
        local live, out = {}, {}
        for _, n in ipairs(names or {}) do live[n] = true end
        for _, b in ipairs(want or {}) do
            if live[b] then out[#out + 1] = b end
        end
        return out
    end

    function ts.runningBrowsers()
        local names = {}
        local ok = pcall(function()
            for _, a in ipairs(hs.application.runningApplications() or {}) do
                local n
                pcall(function() n = a:name() end)
                if n then names[#names + 1] = n end
            end
        end)
        -- 🔎 AN EMPTY LIST IS A REFUSAL, NOT AN EMPTY MAC (6.196.1).
        -- `runningApplications()` can never legitimately come back empty
        -- — Hammerspoon is itself one of them — so a zero-length answer
        -- is macOS declining, and the two must not read alike. Falling
        -- back to "ask every browser" costs a few osascript runs that
        -- find nothing; reporting "no browser is running" when macOS
        -- simply would not say is the answer that sends him looking in
        -- the wrong place. The report counts the fallback and SAYS the
        -- rows were asked blind rather than measured.
        if not ok or #names == 0 then
            ts.listRefused = (ts.listRefused or 0) + 1
            return ts.browsers(), false
        end
        return ts.runningFrom(names, ts.browsers()), true
    end

    -- 🗂 6.439.0 — ONE osascript PER BROWSER, SO A SLOW ONE IS NAMED
    -- RATHER THAN COSTING THE REST. LL, 2026-11-14: "Chrome tab scan
    -- fails. Not sure what you mean but fix please."
    --
    -- 🔎 AND HIS SCREENSHOT CHANGED THE DIAGNOSIS. This file's own note
    -- said the next step was to check Automation — and his System
    -- Settings pane shows Hammerspoon with Finder, Calendar, System
    -- Events, Google Chrome, Outlook and VLC all switched ON. So the
    -- grant is there, which leaves `osascript exited 15` as what it
    -- literally is: SIGTERM, from OUR OWN six-second kill below. The
    -- script was not refused. It was still working when we shot it.
    --
    -- 🚨 AND THE OLD SHAPE COULD NOT SAY WHICH BROWSER. All of them went
    -- into ONE osascript under ONE budget, so a browser with two hundred
    -- tabs — each `URL of t` is an Apple Event round trip — spent the
    -- whole six seconds and every other browser was killed with it,
    -- reported as "No browser answered" and blamed on a permission
    -- prompt that had been granted years ago. A message that names the
    -- wrong cause is worse than none: it is 6.430.0's "Already clean" in
    -- another module.
    --
    -- Each browser now gets its own task, its own slot (6.196.1 — one
    -- slot for several tasks is the use-after-free), its own budget and
    -- its own row in the report. The picker opens when they have all
    -- answered or the last one has run out of time.
    function ts.scan(done)
        if ts.pending then return false end
        local want, listOK = ts.runningBrowsers()
        ts.lastListOK = listOK
        ts.lastBrowsers = want
        if #want == 0 then
            -- 🔎 "No browser is RUNNING" and "no browser ANSWERED" are
            -- opposite facts and only the second is a fault. The old
            -- code could only ever say the second.
            -- 🚨 EVERY RECORD OF THE LAST SCAN GOES, not just the counts.
            -- Leaving `lastLegs` behind made the report describe the
            -- PREVIOUS scan's browsers as though they were this one's —
            -- 6.352.0's exact finding: a stale field read as a live one,
            -- in the report whose whole job is saying what just happened.
            ts.lastCounts, ts.lastWhy = {}, "no browser is running"
            ts.lastLegs, ts.lastMs    = {}, 0
            note("no browser is running — nothing to scan")
            pcall(done, {})
            return false
        end

        local t0    = hs.timer.secondsSinceEpoch()
        local rows  = {}
        local left  = #want
        local legs  = {}
        ts.scanTasks  = ts.scanTasks  or {}
        ts.scanTimers = ts.scanTimers or {}
        ts.pending    = true

        local finished = false
        local function maybeDone()
            if finished or left > 0 then return end
            finished    = true
            ts.pending  = false
            ts.lastMs   = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
            ts.scans    = ts.scans + 1
            ts.lastLegs = legs
            -- 🚨 THE ROWS ARE SORTED BEFORE ANYBODY SEES THEM, and this is
            -- a hazard the parallel scan INTRODUCED rather than one it
            -- found: with one osascript the order was the script's, and
            -- with four the rows arrive in whatever order the browsers
            -- happen to answer. That is a picker whose rows move between
            -- presses — and ⌘1–⌘9 name a POSITION, so a row that moves
            -- is a jump to the wrong tab. Sorted by the browser order
            -- this module already declares, then window, then tab.
            local rank = {}
            for i, b in ipairs(ts.browsers()) do rank[b] = i end
            table.sort(rows, function(a, c)
                local ra, rc = rank[a.browser] or 99, rank[c.browser] or 99
                if ra ~= rc then return ra < rc end
                if a.win ~= c.win then return a.win < c.win end
                return a.tab < c.tab
            end)
            local counts = {}
            for _, r in ipairs(rows) do
                counts[r.browser] = (counts[r.browser] or 0) + 1
            end
            ts.lastCounts = counts
            -- 📋 THE MESSAGE NAMES WHICH BROWSER, AND WHICH OF FOUR THINGS
            -- HAPPENED TO IT. Four, not two: it answered with tabs · it
            -- answered with none · it exited non-zero and said why · it
            -- never answered at all. Only the last two are faults, and
            -- they want different fixes.
            local bad = {}
            for _, b in ipairs(want) do
                local g = legs[b]
                if g and g.state == "timeout" then
                    bad[#bad + 1] = b .. " did not answer in " .. ts.scanTimeout .. "s"
                elseif g and g.state == "error" then
                    bad[#bad + 1] = b .. " exited " .. tostring(g.exit)
                                    .. (g.err and (": " .. g.err) or "")
                end
            end
            if #bad > 0 then
                ts.lastWhy = table.concat(bad, " · ")
                note(ts.lastWhy)
                if #rows == 0 then
                    hs.alert.show("🗂 " .. ts.lastWhy
                        .. "\n_G.tabReport() says what each browser did.", 5)
                end
            else
                ts.lastWhy = nil
            end
            pcall(done, rows)
        end

        for _, b in ipairs(want) do
            local b0 = hs.timer.secondsSinceEpoch()
            local t
            local function settle(state, extra)
                if legs[b] then return end          -- answered once, one way
                legs[b] = extra or {}
                legs[b].state = state
                legs[b].ms = math.floor((hs.timer.secondsSinceEpoch() - b0) * 1000)
                if ts.scanTimers[b] then
                    pcall(function() ts.scanTimers[b]:stop() end)
                    ts.scanTimers[b] = nil
                end
                ts.scanTasks[b] = nil
                left = left - 1
                maybeDone()
            end
            local okNew = pcall(function()
                t = hs.task.new("/usr/bin/osascript", function(code, out, err)
                    local got = ts.parse(out)
                    for _, r in ipairs(got) do rows[#rows + 1] = r end
                    if code ~= 0 and #got == 0 then
                        settle("error", { exit = code,
                            err = tostring(err):gsub("%s+", " "):sub(1, 120) })
                    else
                        settle("ok", { tabs = #got })
                    end
                end, { "-e", ts.scanScript, b })
            end)
            if not (okNew and t) then
                settle("error", { exit = -1, err = "osascript would not start" })
            else
                ts.scanTasks[b] = t
                -- 🛡 THE BELT IS ARMED BEFORE THE ASK (6.246.0) — a
                -- :start() that itself blocks has no belt otherwise.
                ts.scanTimers[b] = hs.timer.doAfter(ts.scanTimeout, function()
                    ts.scanTimers[b] = nil
                    local task = ts.scanTasks[b]
                    if task then pcall(function() task:terminate() end) end
                    settle("timeout")
                end)
                -- 🔬 :start() REFUSES BY RETURNING FALSE (6.304.0) — it does
                -- not throw, so the pcall above succeeds either way and a
                -- refusal used to leave the scan waiting on its belt.
                local started = false
                pcall(function() started = t:start() ~= false end)
                if not started then
                    settle("error", { exit = -1, err = "macOS refused to run osascript" })
                end
            end
        end
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
                -- 👁 6.157.0 — the pane: the whole title and the WHOLE url
                rawText = r.title .. "\n" .. r.url,
                head    = "🗂 " .. r.browser
                          .. (r.win and r.tab and ("  ·  window " .. r.win .. ", tab " .. r.tab) or ""),
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
                -- 👁 6.157.0 — the preview pane goes down with the picker
                pcall(function()
                    ts.chooser:hideCallback(function()
                        if core.call then pcall(core.call, "preview.suspend") end
                    end)
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
            if core.call then pcall(core.call, "preview.open", ts.chooser) end
        end)
    end

    -- ---- the report ------------------------------------------------------
    function _G.tabReport(asText)
        local L = { "🗂 TAB SEARCH" }
        L[#L + 1] = "   scans   : " .. ts.scans .. " (last took " .. ts.lastMs .. "ms)"
        L[#L + 1] = "   jumps   : " .. ts.jumps
        -- 🗂 6.439.0 — ONE ROW PER BROWSER, WITH WHAT HAPPENED TO IT.
        -- This printed a tab count per browser that answered and, when
        -- none did, one sentence blaming Automation — which is what sent
        -- LL to a System Settings pane where every grant was already on.
        -- Four outcomes now, because they want different fixes: it
        -- answered with tabs · it answered with none · it exited non-zero
        -- and said why · it never answered at all. A browser that was
        -- not even ASKED is its own row too, so "I have Chrome open and
        -- it is not in the list" is answerable.
        local legs = ts.lastLegs or {}
        local asked = {}
        for _, b in ipairs(ts.lastBrowsers or {}) do asked[b] = true end
        local any = false
        for _, b in ipairs(ts.browsers()) do
            local n, g = ts.lastCounts[b], legs[b]
            if n or g then
                any = true
                local state
                if g and g.state == "timeout" then
                    state = ("⚠️ did not answer in %ss"):format(ts.scanTimeout)
                elseif g and g.state == "error" then
                    state = ("⚠️ exited %s%s"):format(tostring(g.exit),
                             g.err and (" — " .. g.err) or "")
                elseif (n or 0) > 0 then
                    state = ("✅ %d tab(s)"):format(n)
                else
                    state = "✅ running, no tabs open"
                end
                L[#L + 1] = ("      %-24s %s%s"):format(b, state,
                            g and g.ms and ("  · " .. g.ms .. " ms") or "")
            elseif not asked[b] then
                L[#L + 1] = ("      %-24s ⏳ not running, so never named"):format(b)
            end
        end
        if not any then
            L[#L + 1] = "   browsers: no browser was running when the scan ran — which"
            L[#L + 1] = "             is not the same as none ANSWERING, and only the"
            L[#L + 1] = "             second is a fault."
        end
        -- 🔎 WHERE THE RUNNING LIST CAME FROM. A refused app list falls
        -- back to asking every browser, which costs a few osascript runs
        -- that find nothing — harmless, and worth saying, because then
        -- the rows above are "asked blind" rather than "measured".
        if ts.lastListOK == false then
            L[#L + 1] = "   ⚠️ macOS would not list the running apps, so every browser"
            L[#L + 1] = "      was asked blind (" .. (ts.listRefused or 0) .. " time(s) this session)"
        end
        if ts.lastNote then L[#L + 1] = "   last problem: " .. ts.lastNote end
        local s = table.concat(L, "\n")
        if asText then return s end
        print(s)
    end

    if ts.enabled then
        core.hyperAddShortcut(ts.keyMods, ts.key, function() ts.show() end,
                              "tab search")
    end
    core.provide("tabs.show",   function() return ts.show() end)
    core.provide("tabs.report", function() return _G.tabReport(true) end)

    _G.tabSearch = ts
    M.ts     = ts
    M.config = ts
end

return M
