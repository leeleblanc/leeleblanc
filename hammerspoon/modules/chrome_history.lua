-- =====================================================================
-- MODULE: CHROME HISTORY (⇪Y) — 90 days of browsing, saved and searched
-- =====================================================================
-- LL: "Chrome history saver with a powerful fuzzy search control over
-- the Chrome history. Saves 90 days of history in the best file format
-- to retrieve the most relevant data. Is searchable in the unified
-- clipboard."
--
-- Chrome deletes history older than 90 days, silently and by design,
-- and it keeps what remains locked inside a SQLite database no other
-- tool reads. This module gets the data OUT while it exists:
--
--   ⇪Y     fuzzy-search everything — type fragments, in any order,
--          matching the title or the URL; ⏎ reopens the page in Chrome
--   ⇪⇧Y    re-read Chrome right now and re-save the file, with a count
--   saved  chrome_history-<Mac>.csv in the Logs folder — CSV because
--          this config's answer to "best format" has been the same
--          since image_text.csv: a file Excel opens by double-click,
--          greppable, diffable, and readable in twenty years
--   @web   the same pages inside ⇪space (the unified picker), where
--          ⏎ copies the URL — search "that article about pandas" next
--          to your clipboard and notes, because memory does not file
--          things by which tool held them
--
-- EVERY PROFILE, BOTH MACS. Chrome keeps one History database per
-- profile (Default, Profile 1, …); all of them are read and every row
-- says which profile it came from. A Mac with no Chrome contributes
-- nothing and complains once in its status line — the same one-config-
-- two-Macs posture as ⇪D.
--
-- HOW THE READ WORKS, precisely because it is the delicate part:
-- Chrome holds its History database open and LOCKED, so it is never
-- queried in place — each one is copied to the temp folder first (with
-- its -wal/-shm companions when present) and the copy is queried with
-- /usr/bin/sqlite3, which ships with macOS. That runs as an hs.task,
-- OFF the main thread: a 100 MB history file must never freeze the
-- keyboard. JSON output rather than delimited, because page titles
-- contain every delimiter anyone has ever chosen — and 6.152.0: the
-- JSON goes to a FILE per profile, never through the task's stdout
-- pipe, because a pipe that is only read at exit deadlocks on the first
-- 64 KB (the "hung at: querying" kills — see the note at SCRIPT).
-- 6.152.1: ONE JSON OBJECT PER LINE (json_object per row), not one
-- giant array, and every ingest runs in TIME-BUDGETED SLICES — see the
-- note at runSliced for the beachball this closed the day 6.152.0
-- shipped. Entries younger than 90 days and not hidden (Chrome's own
-- flag for redirect noise), one row per page, newest first.
--
-- FRESHNESS: the export re-runs when what is loaded is older than
-- chrome.staleSecs, and ⇪⇧Y forces it. On boot, warm() reads BACK the
-- CSV it saved last time — so ⇪Y works seconds after login, on
-- yesterday's data, while the fresh export lands behind it. No
-- pathwatcher here on purpose: Chrome writes History on practically
-- every page view, and a watcher would re-export all day long.
--
-- THE FUZZY MATCH. hs.chooser's built-in filter is substring-only, so
-- this module filters for itself (queryChangedCallback, the ⇪F/⇪V
-- pattern): every space-separated word must match — as a substring
-- first, and failing that as an in-order character sequence ("gml"
-- finds gmail). Ranking: tighter matches beat scattered ones, a hit in
-- the title beats one in the URL, and recency breaks ties — which is
-- what "the most relevant data" means when you are looking for the
-- page from this morning. The sequence fallback runs as a Lua string
-- pattern ("g.-m.-l"), so even the fuzzy pass is C-speed.

local M = {
    name  = "Chrome History",
    order = 12.5,
    family = "find",     -- the history shelf: files 10 · docs 11 · commands
                      -- 12 · the web 12.5
    cheatsheet = {
        title = "🕘 CHROME HISTORY (⇪Y — 90 days, every profile)",
        entries = {
            { "⇪Y",      "Fuzzy-search 90 days of Chrome history — ⏎ reopens the page" },
            { "type",    "Words in any order, title or URL · char sequences too — gml finds gmail" },
            { "⌘⏎",     "COPY the page's URL to the clipboard instead of opening it" },
            { "⌥⏎",     "Open in the OTHER browser (Safari · chrome.altBrowser)" },
            { "⇪⇧Y",     "Re-read Chrome now and re-save the CSV, with a count" },
            { "file",    "chrome_history-<Mac>.csv in the Logs folder — Excel opens it" },
            { "@web",    "The same pages inside ⇪space — there ⏎ copies the URL" },
            { "not working?", "_G.chromeHistoryReport() — ends in ✅ or a numbered" },
            { "",        "list of what to fix · also copies itself to the clipboard" },
        },
    },
}

function M.setup(core)
    local chrome = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    chrome.enabled   = true
    chrome.key       = "y"        -- ⇪Y search · ⇪⇧Y refresh ("historY")
    chrome.days      = 90         -- how far back the export reaches
    chrome.maxRows   = 20000      -- per profile, newest first
    chrome.staleSecs = 6 * 3600   -- ⇪Y quietly re-exports past this age
    chrome.showRows  = 40         -- results the picker holds per keystroke
    local home = core.homeDir or os.getenv("HOME") or "~"
    chrome.chromeDir = home .. "/Library/Application Support/Google/Chrome"
    chrome.extraDbs  = {}         -- e.g. { { label = "Brave", path = home ..
                                  --   "/Library/…/Brave-Browser/Default/History" } }
    chrome.sqlite    = "/usr/bin/sqlite3"
    chrome.csvFile   = (core.logsDir or ".") .. "/chrome_history-"
                       .. tostring(core.hostTag or "Mac") .. ".csv"
    chrome.openWith  = "com.google.Chrome"   -- ⏎ opens here; falls back to default
    -- 6.153.0 — LL: "But I might want to copy it and open it in another
    -- browser." ⌥⏎ opens the pick here instead of Chrome; ⌘⏎ copies the
    -- URL and opens nothing. The placeholder names this app off its
    -- bundle id, so changing it updates the hint too.
    chrome.altBrowser = "com.apple.Safari"
    -- 🚨 6.147.0 — THE EXPORT GETS A DEADLINE. On LL's Air the export
    -- hung and `exporting` stayed true for the whole session, so every
    -- ⇪Y press answered "press again in a moment" — forever, and
    -- nothing ever said the export was stuck. A killed hang that SAYS
    -- SO beats a polite alert that never stops being wrong. 6.152.1
    -- raised the deadline from 45s: "a healthy export measures in
    -- single-digit seconds" was a guess made while the pipe deadlock
    -- kept any export from ever finishing — the first run that actually
    -- completed took ~29s on the Air (copying each profile's History
    -- database is the bulk of it), and the work Mac will be slower. The
    -- deadline now exists only for the genuine never-coming-back hang.
    chrome.exportTimeout = 120    -- seconds before a running export is killed
    -- 🚨 6.152.1 — THE INGEST BUDGET: how long one main-thread slice of
    -- parsing or CSV-writing may run before yielding to the event loop.
    -- See runSliced below for the beachball this number exists for.
    chrome.sliceBudget = 0.04     -- seconds of main thread per slice
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("chrome", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("chrome", m) end end

    chrome.entries   = {}     -- { url, title, visits, ts, when, profile, hay, titleLen }
    chrome.status    = "off"
    chrome.loadedAt  = 0
    chrome.exporting = false
    chrome.exportedAt = nil   -- when the running export started (for the alert)
    chrome.watchdog  = nil    -- HELD: the deadline timer on a running export
    chrome.progressPath = nil -- the export's flight-recorder file (6.148.0)
    chrome.lastMs    = nil
    chrome.pumpTimer = nil    -- HELD: a sliced ingest's parked continuation (6.152.1)
    chrome.lastIngest = nil   -- { rows, turns, secs } of the last sliced parse

    local function epoch()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        if ok and type(t) == "number" then return t end
        return os.time()
    end

    -- Everything downstream — the picker, @web, the CSV — assumes one
    -- uniform entry shape, built here and nowhere else.
    local function finish(e)
        e.title    = tostring(e.title or ""):gsub("%c", " ")
        e.visits   = tonumber(e.visits) or 0
        e.ts       = tonumber(e.ts) or 0
        e.when     = os.date("%Y-%m-%d %H:%M", e.ts)
        e.titleLen = #e.title
        e.hay      = (e.title .. " " .. e.url):lower()
        return e
    end

    -- ---- finding the databases -------------------------------------------
    function chrome.findDbs()
        local dbs = {}
        local function addIf(label, path)
            local attr
            pcall(function() attr = hs.fs.attributes(path) end)
            if attr and attr.mode == "file" then
                dbs[#dbs + 1] = { label = label, path = path }
            end
        end
        local names = {}
        pcall(function()
            -- hs.fs.dir returns TWO values — see the 🚨 in the expander.
            local iter, dirObj = hs.fs.dir(chrome.chromeDir)
            for name in iter, dirObj do
                if name == "Default" or name:match("^Profile %d") then
                    names[#names + 1] = name
                end
            end
        end)
        table.sort(names)
        for _, n in ipairs(names) do
            addIf(n, chrome.chromeDir .. "/" .. n .. "/History")
        end
        for _, x in ipairs(chrome.extraDbs or {}) do
            if type(x) == "table" and x.path then
                addIf(x.label or x.path, x.path)
            end
        end
        return dbs
    end

    -- ---- the export ------------------------------------------------------
    -- One /bin/sh, everything by POSITIONAL ARGUMENT — profile names and
    -- "Application Support" both contain spaces, and passing them as $4,
    -- $5… means no quoting ever has to be right. Chrome timestamps are
    -- microseconds since 1601 (the Windows epoch); the query converts.
    --
    -- 🚨 6.148.0 — THE FLIGHT RECORDER. The 6.147.0 watchdog killed two
    -- hung exports on LL's Air and could say nothing but "it hung":
    -- stdout only reaches Lua when the task EXITS, so a killed run is a
    -- run whose evidence died with it. The script now writes one line to
    -- a progress file BEFORE each step; the watchdog reads that file's
    -- last line and names the step the run died in.
    --
    -- 🚨 6.152.0 — AND THAT SENTENCE ("stdout only reaches Lua when the
    -- task EXITS") WAS THE HANG ITSELF. The recorder proved every killed
    -- run died at "querying Default" — and the reason is mechanical, not
    -- a slow query: sqlite3 was writing megabytes of JSON (20,000 rows a
    -- profile) into a pipe whose 64 KB buffer nothing drains until the
    -- task exits. The buffer fills, sqlite3 BLOCKS on write, the task
    -- therefore never exits, and the watchdog kills it at 45s — every
    -- single run, which is exactly what LL's Console showed. A pipe you
    -- only read at exit deadlocks the moment a child writes more than one
    -- buffer of it.
    --
    -- So the DATA never touches the pipe any more: each profile's JSON is
    -- redirected to its own file and stdout carries only two tiny marker
    -- lines per profile — the label, then the file that holds its rows —
    -- which fit in the buffer a thousand times over. Lua reads the files
    -- back in ingest() and deletes them. Same reasoning as the progress
    -- file, finally applied to the payload too.
    --
    -- 🚨 6.152.1 — AND THE ROWS ARE ONE JSON OBJECT PER LINE, not one
    -- array: json_object() per row means the Lua side can decode any
    -- number of rows a slice at a time, where a single 20,000-row array
    -- is one indivisible hs.json.decode — an unbudgetable main-thread
    -- bite. (sqlite3's JSON functions ship built in on macOS.)
    local SCRIPT = [[
sq="$1"; tmp="$2"; cutoff="$3"; limit="$4"; shift 4
pf="$tmp/hs-chrome-progress.txt"
: > "$pf"
n=0
while [ "$#" -ge 2 ]; do
  lbl="$1"; db="$2"; shift 2
  n=$((n+1))
  printf 'copying %s\n' "$lbl" >> "$pf"
  cp -f "$db" "$tmp/hs-chrome-$n.db" 2>/dev/null || continue
  cp -f "$db-wal" "$tmp/hs-chrome-$n.db-wal" 2>/dev/null
  cp -f "$db-shm" "$tmp/hs-chrome-$n.db-shm" 2>/dev/null
  printf 'querying %s\n' "$lbl" >> "$pf"
  "$sq" "$tmp/hs-chrome-$n.db" "SELECT json_object('url', url, 'title', title, 'visits', visit_count, 'ts', CAST(last_visit_time/1000000 - 11644473600 AS INTEGER)) FROM urls WHERE last_visit_time > $cutoff AND hidden = 0 ORDER BY last_visit_time DESC LIMIT $limit;" > "$tmp/hs-chrome-$n.json" 2>/dev/null
  printf '##PROFILE## %s\n' "$lbl"
  printf '##FILE## %s\n' "$tmp/hs-chrome-$n.json"
  rm -f "$tmp/hs-chrome-$n.db" "$tmp/hs-chrome-$n.db-wal" "$tmp/hs-chrome-$n.db-shm"
done
printf 'finished cleanly\n' >> "$pf"
]]

    -- The last line the export managed to log — nil when no progress file
    -- exists (an export that has never run, or a Mac whose tmp was wiped).
    -- After a kill this is the step the run died in; after a healthy run
    -- it reads "finished cleanly".
    function chrome.lastProgress()
        local last
        pcall(function()
            local f = io.open(chrome.progressPath or "", "r")
            if not f then return end
            for line in f:lines() do
                if line:match("%S") then last = line end
            end
            f:close()
        end)
        return last
    end

    -- ---- the file's quoting ----------------------------------------------
    local function csvField(s)
        s = tostring(s or "")
        if s:find('[",\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
        return s
    end

    -- ---- the sliced ingest -----------------------------------------------
    -- 🚨 6.152.1 — THE BEACHBALL 6.152.0 SHIPPED. The pipe fix freed the
    -- data, and the freed data then froze the Mac: the completion
    -- callback decoded megabytes of JSON, built 20,000+ entry tables,
    -- sorted them and wrote the whole CSV — in ONE main-thread pass.
    -- LL's Console showed the receipts ~30 seconds after every boot (the
    -- export completing): "Autocorrect tap was disabled by macOS", "Text
    -- expander tap was disabled by macOS" — macOS kills event taps when
    -- a process stops servicing events, and that same stall is what the
    -- cursor shows as a beachball. Before 6.152.0 this code path had
    -- simply never run with real data: every export died in the pipe
    -- first, so its cost was invisible until the day the fix landed.
    --
    -- So ingestion now runs in TIME-BUDGETED SLICES — the ⌥Tab sweep's
    -- budget idea applied to parsing: do at most sliceBudget seconds of
    -- work, park a doAfter(0) continuation, let keystrokes through,
    -- continue. Small exports still finish inside one slice (the tests
    -- rely on that synchronous path); only work that actually takes time
    -- gets cut. One run at a time: a newer ingest (⇪⇧Y mid-parse)
    -- supersedes the old one, which simply never installs its entries.
    local ingestSeq = 0
    local function runSliced(work)
        ingestSeq = ingestSeq + 1
        local seq = ingestSeq
        local function turn()
            if seq ~= ingestSeq then return end  -- superseded: a newer run owns the data
            local ok, more = pcall(work, epoch() + (chrome.sliceBudget or 0.04))
            if not ok then
                warn("ingest failed — " .. tostring(more))
                return
            end
            if more then
                local okT, t = pcall(hs.timer.doAfter, 0, turn)
                if okT and t then
                    chrome.pumpTimer = t   -- held: unreferenced timers are collected
                else
                    return turn()          -- no timers to park on: finish inline,
                end                        -- never drop data (a proper tail call)
            end
        end
        turn()
    end

    -- stdout → entries → CSV, a slice at a time. stdout carries only
    -- MARKERS (6.152.0) — a ##PROFILE## line naming the profile, then a
    -- ##FILE## line naming the file that holds its rows, one JSON object
    -- per line (6.152.1). Each file is read back, decoded row by row,
    -- and DELETED here; a row that will not parse costs a counted
    -- warning, never the export. An empty file is a profile with nothing
    -- in the 90-day window — sqlite3 prints nothing for zero rows — and
    -- is not worth a warning. done(n) fires after the CSV is on disk.
    function chrome.ingest(out, done)
        local files, label = {}, nil
        for line in (tostring(out or "") .. "\n"):gmatch("(.-)\n") do
            local l = line:match("^##PROFILE## (.+)$")
            local p = line:match("^##FILE## (.+)$")
            if l then label = l
            elseif p and label then
                files[#files + 1] = { label = label, path = p }
            end
        end
        -- a superseded run may have left its half-written CSV open
        if chrome._csvOpen then pcall(function() chrome._csvOpen:close() end) end
        chrome._csvOpen = nil
        local entries = {}
        local fi, lines, li, bad = 0, nil, 1, 0
        local installed, csv, ci, csvDone = false, nil, 0, false
        local turns, t0 = 0, epoch()
        runSliced(function(deadline)
            turns = turns + 1
            while true do
                if lines then
                    -- rows of files[fi]. The budget is checked every 250
                    -- rows: often enough that a slice stays a few ms, rare
                    -- enough that the check costs nothing (and that the
                    -- test suite's stub clock never trips it on a small
                    -- feed — small ingests MUST complete synchronously).
                    while li <= #lines do
                        local ln = lines[li] ; li = li + 1
                        if ln:match("%S") then
                            local okD, row = pcall(function() return hs.json.decode(ln) end)
                            if okD and type(row) == "table"
                               and type(row.url) == "string" and row.url ~= "" then
                                entries[#entries + 1] = finish({
                                    url = row.url, title = row.title,
                                    visits = row.visits, ts = row.ts,
                                    profile = files[fi].label,
                                })
                            else bad = bad + 1 end
                        end
                        if li % 250 == 0 and epoch() > deadline then return true end
                    end
                    if bad > 0 then
                        warn(bad .. " of the " .. files[fi].label
                             .. " rows did not parse as JSON")
                    end
                    lines = nil
                elseif fi < #files then
                    fi = fi + 1
                    local raw
                    local f = io.open(files[fi].path, "r")
                    if f then raw = f:read("*a") ; f:close() end
                    pcall(os.remove, files[fi].path)
                    lines, li, bad = {}, 1, 0
                    for ln in (tostring(raw or "") .. "\n"):gmatch("(.-)\n") do
                        lines[#lines + 1] = ln
                    end
                    if epoch() > deadline then return true end
                elseif not installed then
                    table.sort(entries, function(a, b) return a.ts > b.ts end)
                    chrome.entries  = entries
                    chrome.loadedAt = epoch()
                    installed = true
                    -- entries are live from here: ⇪Y works while the CSV
                    -- below is still being written out behind it
                elseif not csvDone then
                    if not csv then
                        csv = io.open(chrome.csvFile, "w")
                        if not csv then
                            warn("could not write " .. chrome.csvFile)
                            if core.warnWriteFailed then
                                core.warnWriteFailed("chrome_history csv")
                            end
                            csvDone = true
                        else
                            chrome._csvOpen = csv
                            csv:write("date,time,title,url,visits,profile\n")
                        end
                    else
                        -- date and time come from e.when ("%Y-%m-%d %H:%M",
                        -- built once in finish) — the old writeCsv called
                        -- os.date twice MORE per row, 40,000 strftimes a run
                        while ci < #entries do
                            ci = ci + 1
                            local e = entries[ci]
                            csv:write(e.when:sub(1, 10), ",", e.when:sub(12, 16), ",",
                                      csvField(e.title), ",", csvField(e.url), ",",
                                      tostring(e.visits), ",", csvField(e.profile), "\n")
                            if ci % 250 == 0 and epoch() > deadline then return true end
                        end
                        csv:close()
                        chrome._csvOpen = nil
                        csvDone = true
                    end
                else
                    chrome.lastIngest = { rows = #entries, turns = turns,
                                          secs = epoch() - t0 }
                    if done then done(#entries) end
                    return nil
                end
            end
        end)
    end

    -- Read LAST SESSION'S save back, so ⇪Y answers seconds after login
    -- while the fresh export runs behind it. ts is rebuilt from the date
    -- and time columns — approximate to the minute, which is all the
    -- ranking needs. 6.152.1: sliced like the ingest — once an export
    -- has succeeded this CSV is 20,000+ rows, and warm() runs this two
    -- seconds after every boot. done(n) fires when the entries are
    -- installed; loadedAt is deliberately NOT stamped here (the caller
    -- decides how stale a last-session save is).
    function chrome.loadCsv(done)
        local f = io.open(chrome.csvFile, "r")
        if not f then
            if done then done(0) end
            return
        end
        local rows = {}
        for line in f:lines() do rows[#rows + 1] = line end
        f:close()
        local entries, i = {}, 1        -- rows[1] is the header
        runSliced(function(deadline)
            while i < #rows do
                i = i + 1
                local c = core.splitCSVLine and core.splitCSVLine(rows[i])
                if type(c) == "table" and c[4] and c[4] ~= "" then
                    local y, mo, d = tostring(c[1] or ""):match("(%d+)-(%d+)-(%d+)")
                    local h, mi = tostring(c[2] or ""):match("(%d+):(%d+)")
                    local ts = 0
                    if y and h then
                        pcall(function()
                            ts = os.time({ year = tonumber(y), month = tonumber(mo),
                                           day = tonumber(d), hour = tonumber(h),
                                           min = tonumber(mi) }) or 0
                        end)
                    end
                    entries[#entries + 1] = finish({
                        url = c[4], title = c[3], visits = c[5],
                        ts = ts, profile = c[6] or "?",
                    })
                end
                if i % 250 == 0 and epoch() > deadline then return true end
            end
            table.sort(entries, function(a, b) return a.ts > b.ts end)
            chrome.entries = entries
            if done then done(#entries) end
            return nil
        end)
    end

    function chrome.export(andThen)
        if chrome.exporting then return false end
        local dbs = chrome.findDbs()
        if #dbs == 0 then
            chrome.status = "no Chrome history on this Mac"
            say(chrome.status)
            if andThen then andThen(false, 0) end
            return false
        end
        local tmp = "/tmp"
        pcall(function()
            local t = hs.fs.temporaryDirectory()
            if type(t) == "string" and t ~= "" then tmp = t:gsub("/$", "") end
        end)
        -- Where the script's `pf` lands — the Lua side computes the same
        -- path so the watchdog and the report can read it back.
        chrome.progressPath = tmp .. "/hs-chrome-progress.txt"
        local cutoff = (math.floor(epoch()) - chrome.days * 86400
                        + 11644473600) * 1000000
        local args = { "-c", SCRIPT, "hs-chrome-history", chrome.sqlite, tmp,
                       string.format("%.0f", cutoff),
                       tostring(chrome.maxRows) }
        for _, d in ipairs(dbs) do
            args[#args + 1] = d.label
            args[#args + 1] = d.path
        end
        local t0 = epoch()
        -- 🚨 6.148.0 — PER-RUN, not module state, on purpose: the killed
        -- task's exit can land after a FRESH export has already started,
        -- and a shared flag would make that late exit swallow the new
        -- run's completion (or its `exporting` flag).
        local killedByWatchdog = false
        local okNew, t = pcall(function()
            return hs.task.new("/bin/sh", function(code, sout, serr)
                -- 🚨 6.148.0 — A KILLED RUN EXITS TOO. terminate() makes sh
                -- exit 15, which lands HERE a moment after the watchdog
                -- wrote the honest status (which step it died in) — and the
                -- generic branch below then overwrote it with "export
                -- failed (sh exited 15)". LL's console showed exactly that
                -- pair of lines. The kill's own exit is not a second
                -- failure to report, and it must not touch module state a
                -- newer run may own by now.
                if killedByWatchdog then
                    if andThen then andThen(false, 0) end
                    return
                end
                chrome.exporting = false
                if chrome.watchdog then
                    pcall(function() chrome.watchdog:stop() end)
                    chrome.watchdog = nil
                end
                chrome.lastMs = (epoch() - t0) * 1000
                if code ~= 0 then
                    chrome.status = "export failed (sh exited " .. tostring(code) .. ")"
                    warn(chrome.status .. " — " .. tostring(serr):sub(1, 120))
                    if _G.notices then
                        _G.notices.record("chrome", "export failed",
                                          tostring(serr):sub(1, 200))
                    end
                    if andThen then andThen(false, 0) end
                    return
                end
                -- 6.152.1 — SLICED: the old one-pass parse+CSV froze the
                -- Mac right here, the first time an export ever succeeded
                chrome.ingest(sout, function(n)
                    chrome.status = string.format("%d pages · %d profile%s · %.0fms",
                                                  n, #dbs,
                                                  #dbs == 1 and "" or "s",
                                                  chrome.lastMs)
                    say("exported " .. chrome.status)
                    if andThen then andThen(true, n) end
                end)
            end, args)
        end)
        if not (okNew and t) then
            chrome.status = "export failed (hs.task unavailable)"
            warn(chrome.status)
            return false
        end
        chrome.task = t     -- held: an unreferenced task is collected mid-run
        chrome.exporting = true
        chrome.exportedAt = epoch()
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            chrome.exporting = false
            chrome.status = "export failed (sh would not start)"
            warn(chrome.status)
            return false
        end
        -- 🚨 6.147.0 — the deadline. Without it, a hung sh left
        -- `exporting` true for the rest of the session and ⇪Y said
        -- "press again in a moment" until reboot. The completion
        -- callback above stops this timer on every normal exit; the
        -- timer fires ONLY on the hang it exists for.
        if chrome.watchdog then pcall(function() chrome.watchdog:stop() end) end
        local okDog, dog = pcall(hs.timer.doAfter, chrome.exportTimeout, function()
            chrome.watchdog = nil
            if not chrome.exporting then return end
            chrome.exporting = false
            killedByWatchdog = true
            pcall(function() t:terminate() end)
            -- The flight recorder names the step the run died in — the
            -- one fact 6.147.0's kill could not give.
            local stuck = chrome.lastProgress()
            local at = stuck and (" — it hung at: " .. stuck)
                       or " — it hung before writing any progress"
            chrome.status = "export KILLED after " .. chrome.exportTimeout
                            .. "s" .. at
                            .. ". _G.chromeHistoryReport() has the details"
            warn(chrome.status)
            if _G.notices then
                _G.notices.record("chrome", "export hung and was killed",
                    "ran past " .. chrome.exportTimeout .. "s and was "
                    .. "terminated" .. at
                    .. " — run _G.chromeHistoryReport()")
            end
            pcall(function()
                hs.alert.show("🕘 Chrome export hung and was stopped after "
                              .. chrome.exportTimeout .. "s"
                              .. (stuck and ("\nIt died at: " .. stuck) or "")
                              .. "\n_G.chromeHistoryReport() explains.", 5)
            end)
        end)
        chrome.watchdog = okDog and dog or nil
        return true
    end

    -- ---- the fuzzy match -------------------------------------------------
    -- Two passes per word, both C-speed: plain find first, then the word's
    -- characters as an in-order pattern ("gml" → "g.-m.-l"). Score favors
    -- tight over scattered, title over URL, and the caller adds recency.
    local function seqPattern(word)
        local parts = {}
        for i = 1, #word do
            parts[#parts + 1] = word:sub(i, i):gsub("(%W)", "%%%1")
        end
        return table.concat(parts, ".-")
    end

    function chrome.score(e, words, patterns)
        local total = 0
        for i = 1, #words do
            local w = words[i]
            local s, epos = e.hay:find(w, 1, true)
            if s then
                total = total + 100
            else
                pcall(function() s, epos = e.hay:find(patterns[i]) end)
                if not s then return nil end
                -- tighter sequences score higher: exact-adjacent ≈ 60,
                -- scattered across the whole line approaches zero
                total = total + math.max(60 - ((epos - s + 1) - #w), 5)
            end
            if s <= e.titleLen then total = total + 15 end
        end
        return total
    end

    function chrome.search(query)
        local words, patterns = {}, {}
        for w in tostring(query or ""):lower():gmatch("%S+") do
            words[#words + 1] = w
            patterns[#patterns + 1] = seqPattern(w)
        end
        local out = {}
        if #words == 0 then
            for i = 1, math.min(#chrome.entries, chrome.showRows) do
                out[#out + 1] = chrome.entries[i]
            end
            return out
        end
        local scored = {}
        for idx, e in ipairs(chrome.entries) do
            local s = chrome.score(e, words, patterns)
            -- idx breaks ties: entries are newest-first, so equal scores
            -- surface this morning's page above last month's
            if s then scored[#scored + 1] = { s = s, idx = idx, e = e } end
        end
        table.sort(scored, function(a, b)
            if a.s ~= b.s then return a.s > b.s end
            return a.idx < b.idx
        end)
        for i = 1, math.min(#scored, chrome.showRows) do
            out[#out + 1] = scored[i].e
        end
        return out
    end

    -- ---- opening ---------------------------------------------------------
    function chrome.open(url, bundle)
        local ok = false
        pcall(function()
            ok = hs.urlevent.openURLWithBundle(url, bundle or chrome.openWith)
        end)
        if not ok then pcall(function() ok = hs.urlevent.openURL(url) end) end
        if not ok then
            pcall(function() hs.alert.show("🕘 could not open " .. url:sub(1, 60)) end)
            warn("neither the browser nor the default took " .. url:sub(1, 90))
        end
        return ok
    end

    -- 6.153.0 — ⏎ IS NO LONGER THE ONLY VERB. The pick reads whatever
    -- modifiers are held at the moment you press ⏎ (or click): ⌘ copies
    -- the URL to the clipboard and opens nothing, ⌥ opens it in
    -- chrome.altBrowser, bare ⏎ opens it in Chrome as always.
    -- hs.chooser has no per-row action API — modifiers-at-pick is the
    -- standard Hammerspoon answer, and the read degrades to "bare" on a
    -- build without hs.eventtap. Returns the verb so the test suite and
    -- ⇪⇧D can see which path fired.
    function chrome.pick(url)
        local mods = {}
        pcall(function() mods = hs.eventtap.checkKeyboardModifiers() or {} end)
        if mods.cmd then
            pcall(function() hs.pasteboard.setContents(url) end)
            pcall(function() hs.alert.show("🕘 copied — " .. url:sub(1, 60)) end)
            say("copied " .. url:sub(1, 90))
            return "copied"
        end
        if mods.alt then
            chrome.open(url, chrome.altBrowser)
            return "alt"
        end
        chrome.open(url)
        return "opened"
    end

    -- ---- the picker ------------------------------------------------------
    local function choicesFor(list)
        local rows = {}
        for _, e in ipairs(list) do
            rows[#rows + 1] = {
                text    = (e.title ~= "" and e.title or e.url):sub(1, 120),
                subText = e.when .. "  ·  " .. e.profile .. "  ·  "
                          .. e.url:sub(1, 90),
                url     = e.url,
            }
        end
        return rows
    end

    function chrome.show()
        if #chrome.entries == 0 then
            if chrome.exporting then
                -- 6.147.0 — the alert now carries the elapsed time, so a
                -- healthy two-second export and a hang about to be killed
                -- read differently even before the watchdog speaks.
                local secs = math.floor(epoch() - (chrome.exportedAt or epoch()))
                pcall(function()
                    hs.alert.show("🕘 Reading Chrome history (" .. secs
                                  .. "s in) — press ⇪Y again in a moment")
                end)
            else
                pcall(function()
                    hs.alert.show("🕘 No Chrome history — " .. tostring(chrome.status))
                end)
                chrome.export()
            end
            return false
        end
        -- quietly refresh stale data; the picker opens on what is loaded
        if not chrome.exporting
           and (epoch() - chrome.loadedAt) > chrome.staleSecs then
            chrome.export()
        end
        if not chrome.chooser then
            local okC, c = pcall(hs.chooser.new, function(pick)
                if pick and pick.url then chrome.pick(pick.url) end
            end)
            if not (okC and c) then
                warn("hs.chooser unavailable")
                return false
            end
            chrome.chooser = c
            -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.chromeHistory = c
            pcall(function()
                c:rows(12)
                c:width(48)
                c:searchSubText(false)   -- we filter for ourselves below
                c:queryChangedCallback(function(query)
                    pcall(function()
                        chrome.chooser:choices(choicesFor(chrome.search(query)))
                    end)
                end)
            end)
        end
        pcall(function()
            local altName = tostring(chrome.altBrowser or ""):match("[^.]+$")
                            or "other"
            chrome.chooser:placeholderText(#chrome.entries
                .. " pages, 90 days — ⏎ opens · ⌥⏎ " .. altName
                .. " · ⌘⏎ copies")
            chrome.chooser:query("")
            chrome.chooser:choices(choicesFor(chrome.search("")))
            -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
            -- LAST picker's coordinates standing in _G.lastPopupPlacement,
            -- and window_move computes its grab box from that record. It
            -- could not be dragged at all until 6.127.0.
            if core.showPopup then core.showPopup(chrome.chooser)
            else chrome.chooser:show() end
        end)
        return true
    end

    function chrome.refresh()
        pcall(function() hs.alert.show("🕘 Reading Chrome history…") end)
        chrome.export(function(ok, n)
            pcall(function()
                hs.alert.show(ok
                    and ("🕘 " .. n .. " pages saved → "
                         .. (chrome.csvFile:match("[^/]+$") or chrome.csvFile))
                    or  ("🕘 export failed — " .. tostring(chrome.status)))
            end)
        end)
    end

    -- ---- the report ------------------------------------------------------
    -- 🚨 THIS ANSWERS "IS ⇪Y WORKING?", NOT "WHAT DID IT LOAD". 6.106.0.
    -- LL: "Chrome fuzzy history might not be working, how can I tell?" —
    -- and the honest answer was that you could not, from here. The old
    -- report printed the status line and a per-profile table, which is
    -- useful once things work and says nothing at all when they do not: an
    -- empty list looks identical whether sqlite3 is missing, Chrome has
    -- never run on this Mac, Full Disk Access is not granted, or you
    -- genuinely have no history in the window.
    --
    -- Every one of those is a different fix, so every one gets its own
    -- line, and the whole thing ends in a verdict rather than leaving you
    -- to infer one. The cheat sheet has promised "per profile, span, file,
    -- timings" since 6.92.0; the timings were never actually printed.
    function chrome.report()
        local lines = {}
        local function outLine(s) lines[#lines + 1] = s; print(s) end
        local problems = {}

        local function ageWords(secs)
            if secs < 90 then return string.format("%ds ago", math.floor(secs)) end
            if secs < 5400 then return string.format("%dm ago", math.floor(secs / 60)) end
            if secs < 172800 then return string.format("%.1fh ago", secs / 3600) end
            return string.format("%.1f days ago", secs / 86400)
        end

        outLine("🕘 CHROME HISTORY (⇪Y) — " .. tostring(chrome.status))

        -- 1. the two things that must exist before anything can work
        local sqlOk
        pcall(function()
            local a = hs.fs.attributes(chrome.sqlite)
            sqlOk = a and a.mode == "file" or false
        end)
        if sqlOk then
            outLine("   ✅ sqlite3   " .. chrome.sqlite)
        else
            outLine("   ❌ sqlite3   NOT at " .. chrome.sqlite)
            problems[#problems + 1] =
                "sqlite3 is missing — it ships with macOS, so this is unusual; "
                .. "set chrome.sqlite to wherever yours lives"
        end

        local dirOk
        pcall(function()
            local a = hs.fs.attributes(chrome.chromeDir)
            dirOk = a and a.mode == "directory" or false
        end)
        if dirOk then
            outLine("   ✅ Chrome    " .. chrome.chromeDir)
        else
            outLine("   ❌ Chrome    no folder at " .. chrome.chromeDir)
            problems[#problems + 1] =
                "Chrome's support folder is not there — either Chrome has never "
                .. "run as this user, or it is installed somewhere else"
        end

        -- 2. the profiles it can actually see RIGHT NOW, not at boot
        local dbs = {}
        pcall(function() dbs = chrome.findDbs() or {} end)
        if #dbs > 0 then
            outLine(string.format("   ✅ profiles  %d History database%s readable",
                                  #dbs, #dbs == 1 and "" or "s"))
            for _, d in ipairs(dbs) do
                local sz = 0
                pcall(function()
                    local a = hs.fs.attributes(d.path)
                    sz = (a and a.size) or 0
                end)
                outLine(string.format("        %-12s %s KB", d.label,
                                      math.floor(sz / 1024)))
            end
        elseif dirOk then
            outLine("   ❌ profiles  none found under " .. chrome.chromeDir)
            -- 🚨 THE LIKELIEST CAUSE, AND IT IS NOT OBVIOUS. Chrome's
            -- History file sits in a location macOS puts behind Full Disk
            -- Access. Without it hs.fs.attributes answers nil for a file
            -- that is plainly there, and every symptom looks like "no
            -- history" rather than "not allowed to look".
            problems[#problems + 1] =
                "no readable profile — if Chrome IS installed and you have "
                .. "browsed, this is almost always Full Disk Access: System "
                .. "Settings → Privacy & Security → Full Disk Access → add "
                .. "Hammerspoon, then reload"
        end

        -- 3. the saved CSV: is there one, how big, how old
        local size, mtime
        pcall(function()
            local a = hs.fs.attributes(chrome.csvFile)
            if a then size, mtime = a.size, a.modification end
        end)
        outLine("   file: " .. chrome.csvFile)
        if size then
            outLine(string.format("        %d KB, written %s",
                                  math.floor(size / 1024),
                                  mtime and ageWords(os.time() - mtime) or "at an unknown time"))
        else
            outLine("        (not written yet)")
            problems[#problems + 1] =
                "the CSV has never been written — press ⇪⇧Y to force an export "
                .. "and watch this report again"
        end

        -- 4. timings, which the cheat sheet has promised all along
        if chrome.lastMs then
            outLine(string.format("   last export: %.0fms", chrome.lastMs))
        else
            outLine("   last export: not run yet this session")
        end
        -- 6.152.1 — the sliced ingest's receipt: how many rows, cut into
        -- how many main-thread slices. One slice = a small export; many
        -- slices = the keyboard was being let through, working as built.
        if chrome.lastIngest then
            outLine(string.format("   last parse:  %d rows in %d slice%s, %.0fms total",
                                  chrome.lastIngest.rows, chrome.lastIngest.turns,
                                  chrome.lastIngest.turns == 1 and "" or "s",
                                  chrome.lastIngest.secs * 1000))
        end
        -- 6.148.0 — the flight recorder's last word. "finished cleanly"
        -- after a healthy run; after a kill, the step the run died in —
        -- which is the line to paste when ⇪Y hangs.
        local prog = chrome.lastProgress()
        if prog then
            outLine("   progress:    " .. prog
                    .. (prog == "finished cleanly" and ""
                        or "  ← where the killed run stopped"))
        end
        if chrome.loadedAt and chrome.loadedAt > 0 then
            outLine("   loaded:      " .. ageWords(epoch() - chrome.loadedAt)
                    .. string.format("  (goes stale after %.0fh)",
                                     chrome.staleSecs / 3600))
        end
        if chrome.exporting then
            outLine("   ⏳ an export is running right now — re-run this in a moment")
        end

        -- 5. what is in memory, per profile
        local per, order = {}, {}
        for _, e in ipairs(chrome.entries) do
            if not per[e.profile] then
                per[e.profile] = { n = 0, oldest = e.ts, newest = e.ts }
                order[#order + 1] = e.profile
            end
            local p = per[e.profile]
            p.n = p.n + 1
            if e.ts < p.oldest then p.oldest = e.ts end
            if e.ts > p.newest then p.newest = e.ts end
        end
        table.sort(order)
        for _, name in ipairs(order) do
            local p = per[name]
            outLine(string.format("   %-12s %6d pages   %s → %s", name, p.n,
                                  os.date("%Y-%m-%d", p.oldest),
                                  os.date("%Y-%m-%d", p.newest)))
        end
        if #order == 0 then
            outLine("   (no entries loaded)")
            if #problems == 0 then
                problems[#problems + 1] =
                    "everything above looks right but nothing loaded — press ⇪⇧Y "
                    .. "to re-read Chrome now, and check the Console for a "
                    .. "chrome export line"
            end
        end

        -- 6. a live search, so the answer covers the part you actually
        --    press. Counting rows for a common substring proves the index
        --    and the matcher work, not just that the file parsed.
        if #chrome.entries > 0 then
            local hits = 0
            pcall(function() hits = #(chrome.search("http") or {}) end)
            outLine(string.format("   search test: 'http' matches %d row%s",
                                  hits, hits == 1 and "" or "s"))
            if hits == 0 then
                problems[#problems + 1] =
                    "rows are loaded but a search for 'http' matched none — that "
                    .. "is the matcher, not the data; send this report back"
            end
        end

        -- 7. the verdict, in words
        outLine("")
        if #problems == 0 then
            outLine("   ✅ WORKING. ⇪Y should open with " .. #chrome.entries
                    .. " pages to search.")
        else
            outLine("   ⚠️ " .. #problems .. " thing"
                    .. (#problems == 1 and "" or "s") .. " to fix:")
            for i, p in ipairs(problems) do
                outLine("      " .. i .. ". " .. p)
            end
        end

        local text = table.concat(lines, "\n")
        pcall(function() hs.pasteboard.setContents(text) end)
        return text
    end

    -- ---- wiring ----------------------------------------------------------
    if chrome.enabled then
        core.hyperAddShortcut({}, chrome.key, function() chrome.show() end,
                              "chrome history")
        core.hyperAddShortcut({ "shift" }, chrome.key,
                              function() chrome.refresh() end,
                              "chrome history refresh")
    end

    core.provide("chromeHistory.show",   function() return chrome.show()   end)
    core.provide("chromeHistory.search", function(q) return chrome.search(q) end)
    core.provide("chromeHistory.export", function() return chrome.export() end)

    M.warm = function()
        -- loadCsv is sliced (6.152.1); the export starts from its
        -- completion so the two never interleave on chrome.entries
        chrome.loadCsv(function(had)
            if had > 0 then
                chrome.loadedAt = 0    -- data, but stale by definition
                chrome.status = had .. " pages (last save; refreshing)"
            end
            chrome.export()
        end)
    end

    _G.chromeHistory       = chrome
    _G.chromeHistoryReport = function() return chrome.report() end
    M.chrome = chrome
    M.config = chrome
end

return M
