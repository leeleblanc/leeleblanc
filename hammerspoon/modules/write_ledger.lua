-- =====================================================================
-- MODULE: WRITE LEDGER (_G.saved) — proof that your logs are saving
-- =====================================================================
-- LL: "How do I know all my logs and other tracking files/editing files
-- like OCR edits are actually saving? Should we build in a Hammerspoon
-- console that captures if it does, but not floor the console like
-- messages in the past?"
--
--        _G.saved()   the whole ledger, in the Console
--        ⇪⇧D          a WHAT IS SAVING block inside the diagnostic report
--        by itself    a quiet check every 30 minutes that prints NOTHING
--                     unless something is actually wrong
--
-- ---- 🚨 WHY IT WATCHES THE FILES INSTEAD OF THE WRITES ---------------
-- The obvious build logs every write as it happens: wrap io.write, count
-- the bytes, print a line. It answers the wrong question, and it answered
-- it wrong on this very Mac in 6.115.0.
--
-- What actually happened there: THREE FILES SHARED A NAME AND TWO OF
-- THEM WERE FROZEN. adoptLegacyFile copied the old activity_history.csv
-- forward and left the original sitting in ~/.hammerspoon forever,
-- unmarked, beside the live machine-tagged one. Every write succeeded.
-- Every write went to the right file. A write-logger would have printed
-- a happy line each time — and LL would still have been looking at a
-- file that had not changed since July, because the file he opened was
-- not the file being written.
--
-- So this reads the DISK, which is the thing the question is actually
-- about. Size, modification time, row count, and how much each has
-- grown since this config booted. A log that is saving grows; one that
-- is not, does not; and no amount of instrumentation on the write path
-- can tell you which file you are looking at.
--
-- ---- AND IT DOES NOT FLOOD THE CONSOLE ------------------------------
-- The scheduled check prints on exactly three conditions:
--        · a file that was there at boot has DISAPPEARED
--        · a file has SHRUNK
--        · two files look like the same log and the twin is stale
-- and each of those is said ONCE per session, not once per check. On a
-- healthy Mac this module is completely silent for the whole session,
-- which is the point: a check you have learned to scroll past is not a
-- check. Everything else waits until you ask for it.
--
-- ---- THE ROUND TRIP -------------------------------------------------
-- The report also writes a probe file into the Logs folder, reads it
-- back, compares it and deletes it — because "the folder exists" and
-- "the folder will accept a write right now" are different claims, and
-- the second one is what fails when OneDrive has gone offline or made
-- the folder online-only. That is the failure this config's
-- warnWriteFailed alert was built for; this proves the state before
-- anything has to fail.
-- =====================================================================

local M = {
    name  = "Write Ledger",
    order = 13.36,
    family = "config",
    cheatsheet = {
        title = "💾 WRITE LEDGER (is it actually saving?)",
        entries = {
            { "_G.saved()", "Every log file: size, rows, when last written" },
            { "in ⇪⇧D",   "The same block, inside the diagnostic report" },
            { "grown",    "How much each file has grown since this boot" },
            { "probe",    "Writes and re-reads a test file — proves the folder takes writes" },
            { "twins",    "Warns when two files look like the same log (one is frozen)" },
            { "quiet",    "Checks itself every 30 min and says NOTHING unless wrong" },
        },
    },
}

function M.setup(core)
    local wl = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    wl.enabled      = true
    wl.checkEvery   = 1800      -- seconds between quiet background checks
    wl.rowCountMax  = 4 * 1024 * 1024   -- don't count rows in files bigger than this
    wl.staleDays    = 7         -- a same-named twin untouched this long is called out
    wl.exts         = { csv = true, json = true, log = true, txt = true }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("saved", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("saved", m) end end

    wl.baseline = nil       -- path -> { size, mtime }, taken at warm()
    wl.bootAt   = nil
    wl.said     = {}        -- what the quiet check has already reported once
    wl.checks   = 0
    wl.timer    = nil       -- HELD: an unreferenced hs.timer is collected

    -- ---- where to look ----------------------------------------------------
    -- The Logs folder is scanned rather than a list of filenames being kept
    -- here. A list would be a second place to update every time a module
    -- learns to write something, and the first symptom of forgetting would
    -- be this report claiming everything is fine.
    function wl.dirs()
        local d = {}
        if core.logsDir then
            d[#d + 1] = core.logsDir
            d[#d + 1] = core.logsDir .. "/Terminal+Ghostty"
        end
        d[#d + 1] = hs.configdir
        return d
    end

    -- ---- 🗄 A RETIRED COPY IS NOT A LIVE LOG ------------------------------
    -- Two suffixes in this config mean "this file was deliberately taken
    -- out of service and kept anyway":
    --        .superseded        6.115.0's adoption rename
    --        .before-iso-dates  the CSV migration's pre-flight backup
    -- They are LISTED, because "which of these three files am I looking
    -- at" is the question that started this module — but they are never
    -- compared for staleness, because being frozen is their whole job.
    function wl.isRetired(name)
        return name:find("%.superseded$") ~= nil
            or name:find("%.before%-") ~= nil
    end

    -- ---- one directory, no recursion beyond what dirs() names -------------
    -- 🚨 hs.fs.dir RETURNS TWO VALUES and the iterator needs the second one.
    -- Getting this wrong is what stopped every snippet loading in 6.69.0.
    local function scanDir(dir, into)
        local okIter, iter, dirObj = pcall(hs.fs.dir, dir)
        if not okIter or not iter then return end
        for entry in iter, dirObj do
            if entry ~= "." and entry ~= ".." then
                local ext     = entry:match("%.([%w]+)$")
                local retired = wl.isRetired(entry)
                if retired or (ext and wl.exts[ext:lower()]) then
                    local full = dir .. "/" .. entry
                    local a = hs.fs.attributes(full)
                    if a and a.mode ~= "directory" then
                        into[#into + 1] = {
                            path    = full,
                            name    = entry,
                            dir     = dir,
                            size    = a.size or 0,
                            mtime   = a.modification or 0,
                            retired = retired,
                        }
                    end
                end
            end
        end
    end

    function wl.scan()
        local files = {}
        for _, d in ipairs(wl.dirs()) do scanDir(d, files) end
        table.sort(files, function(a, b) return a.path < b.path end)
        return files
    end

    -- ---- rows, cheaply and only when asked --------------------------------
    -- Counting rows means reading the file, so it happens in the on-demand
    -- report and never on the timer, and never at all past rowCountMax. A
    -- diagnostic that costs a megabyte of disk every half hour is a
    -- diagnostic that becomes the problem.
    function wl.rows(path, size)
        if size > wl.rowCountMax then return nil end
        local f = io.open(path, "rb")
        if not f then return nil end
        local n, chunk = 0, nil
        repeat
            chunk = f:read(64 * 1024)
            if chunk then
                for _ in chunk:gmatch("\n") do n = n + 1 end
            end
        until not chunk
        f:close()
        return n
    end

    -- ---- 👯 twins: two files that look like the same log ------------------
    -- The 6.115.0 bug in one function. activity_history.csv and
    -- activity_history-Lees-MacBook-Air.csv are the same log under two
    -- names, and only one of them is being written. Stripping the machine
    -- tag and the extension gives an identity both share.
    --
    -- Retired copies are EXCLUDED: 6.115.0 renames adopted originals to
    -- .superseded precisely so they stop looking like live logs, and
    -- re-flagging them here would make the fix look like the bug it fixed.
    --
    -- 🚨 ONLY *THIS* MAC'S TAG IS STRIPPED, and that is not a detail. The
    -- Logs folder is in OneDrive, so the WORK Mac's
    -- activity_history-Lees-Work-MacBook.csv sits right next to the home
    -- Mac's — and it is supposed to be untouched for days at a time,
    -- because nobody is using that Mac today. A rule that stripped any
    -- machine tag would make the two look like one log with a frozen
    -- twin and cry wolf every session on a config whose whole premise is
    -- two Macs sharing a folder. Another machine's file keeps its full
    -- identity, so it never groups with this machine's, so it is never
    -- called stale.
    function wl.identity(name)
        local base = name
        base = base:gsub("%.superseded$", "")
        base = base:gsub("%.before%-[%w%.%-]+$", "")
        base = base:gsub("%.[%w]+$", "")
        -- The tag is escaped: hostTag comes from the machine name and a
        -- literal "-" is a quantifier in a Lua pattern.
        local tag = tostring(core.hostTag or "Mac"):gsub("(%W)", "%%%1")
        base = base:gsub("%-" .. tag .. "$", "")
        return base
    end

    function wl.twins(files)
        local byId, out = {}, {}
        for _, f in ipairs(files) do
            if not f.retired then
                local id = wl.identity(f.name)
                byId[id] = byId[id] or {}
                table.insert(byId[id], f)
            end
        end
        for id, group in pairs(byId) do
            if #group > 1 then
                table.sort(group, function(a, b) return a.mtime > b.mtime end)
                local live = group[1]
                for i = 2, #group do
                    local ageDays = (live.mtime - group[i].mtime) / 86400
                    if ageDays >= wl.staleDays then
                        out[#out + 1] = { id = id, live = live, stale = group[i],
                                          days = ageDays }
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end

    -- ---- 🔁 the round trip -------------------------------------------------
    -- "The folder exists" and "the folder will take a write right now" are
    -- different claims, and only the second one is the question.
    function wl.probe()
        local dir = core.logsDir
        if not dir then return false, "no Logs folder is configured" end
        local path = dir .. "/.hs-write-probe"
        local want = "hammerspoon write probe " .. tostring(os.time())
        local t0 = hs.timer.secondsSinceEpoch()
        local f = io.open(path, "w")
        if not f then return false, "the folder would not open a file for writing" end
        local okW = pcall(function() f:write(want) end)
        pcall(function() f:close() end)
        if not okW then
            pcall(os.remove, path)
            return false, "the file opened but would not take the bytes"
        end
        local r = io.open(path, "rb")
        if not r then
            pcall(os.remove, path)
            return false, "the file was written but could not be read back"
        end
        local got = r:read("*a")
        r:close()
        pcall(os.remove, path)
        if got ~= want then
            return false, "what came back was not what went in"
        end
        return true, string.format("%.0fms", (hs.timer.secondsSinceEpoch() - t0) * 1000)
    end

    -- ---- formatting -------------------------------------------------------
    local function human(bytes)
        if bytes >= 1024 * 1024 then
            return string.format("%.1f MB", bytes / 1024 / 1024)
        elseif bytes >= 1024 then
            return string.format("%.1f KB", bytes / 1024)
        end
        return string.format("%d B", bytes)
    end

    local function ago(when, now)
        if not when or when <= 0 then return "never" end
        local d = math.max(0, (now or os.time()) - when)
        if d < 90 then return "just now" end
        if d < 3600 then return math.floor(d / 60) .. " minutes ago" end
        if d < 86400 then return math.floor(d / 3600) .. " hours ago" end
        return math.floor(d / 86400) .. " days ago"
    end

    -- ---- the baseline ------------------------------------------------------
    function wl.takeBaseline()
        local map = {}
        for _, f in ipairs(wl.scan()) do
            map[f.path] = { size = f.size, mtime = f.mtime }
        end
        wl.baseline = map
        wl.bootAt   = os.time()
        say("baseline taken over " .. tostring(#wl.scan()) .. " files")
        return map
    end

    -- ---- 🔇 the quiet check -------------------------------------------------
    -- Returns the list of problems it found. Prints each one ONCE per
    -- session: a warning you have learned to scroll past is not a warning.
    function wl.check(announce)
        wl.checks = wl.checks + 1
        local files, byPath, problems = wl.scan(), {}, {}
        for _, f in ipairs(files) do byPath[f.path] = f end

        for path, was in pairs(wl.baseline or {}) do
            local now = byPath[path]
            if not now then
                problems[#problems + 1] = {
                    key = "gone:" .. path,
                    text = "💾 " .. path .. " was here at boot and is GONE now.",
                }
            elseif now.size < was.size then
                problems[#problems + 1] = {
                    key = "shrank:" .. path,
                    text = string.format(
                        "💾 %s has SHRUNK — %s at boot, %s now. That is either a "
                        .. "rotation or a truncation, and only one of them is fine.",
                        path, human(was.size), human(now.size)),
                }
            end
        end

        for _, t in ipairs(wl.twins(files)) do
            problems[#problems + 1] = {
                key = "twin:" .. t.stale.path,
                text = string.format(
                    "💾 TWO FILES LOOK LIKE THE SAME LOG. %s last changed %d days "
                    .. "before %s. The one you open may not be the one being "
                    .. "written — run _G.saved() for both.",
                    t.stale.path, math.floor(t.days), t.live.name),
            }
        end

        if announce ~= false then
            for _, p in ipairs(problems) do
                if not wl.said[p.key] then
                    wl.said[p.key] = true
                    print(p.text)
                    if _G.notices then
                        pcall(_G.notices.record, "runtime", "write ledger", p.text)
                    end
                end
            end
        end
        return problems
    end

    -- ---- 💾 the report ------------------------------------------------------
    function wl.report()
        local now   = os.time()
        local files = wl.scan()
        local L = { string.format("💾 WHAT IS ACTUALLY SAVING — %s",
                                  tostring(core.hostTag)) }
        L[#L + 1] = "   Logs folder : " .. tostring(core.logsDir or "not configured")
        local okProbe, note = wl.probe()
        L[#L + 1] = "   round trip  : " .. (okProbe
            and ("✅ wrote and read a probe file back in " .. note)
            or  ("❌ " .. tostring(note)))
        if wl.bootAt then
            L[#L + 1] = string.format("   baseline    : taken %s, %d file%s",
                ago(wl.bootAt, now), wl.baseline and (function()
                    local n = 0 ; for _ in pairs(wl.baseline) do n = n + 1 end ; return n
                end)() or 0,
                (wl.baseline and next(wl.baseline)) and "s" or "")
        else
            L[#L + 1] = "   baseline    : not taken yet (the module warms 2s after boot)"
        end

        local failures = {}
        for label, n in pairs(_G.writeFailures or {}) do
            failures[#failures + 1] = label .. " ×" .. n
        end
        if #failures > 0 then
            table.sort(failures)
            L[#L + 1] = "   ❌ WRITE FAILURES THIS SESSION: " .. table.concat(failures, ", ")
        end

        local live, retired = {}, {}
        for _, f in ipairs(files) do
            if f.retired then retired[#retired + 1] = f else live[#live + 1] = f end
        end

        L[#L + 1] = ""
        L[#L + 1] = string.format("   %-42s %10s %8s  %-16s %s",
                                  "FILE", "SIZE", "ROWS", "LAST WRITTEN", "SINCE BOOT")
        local changed = 0
        for _, f in ipairs(live) do
            local rows = wl.rows(f.path, f.size)
            local was  = (wl.baseline or {})[f.path]
            local since
            if not was then
                since = "NEW this session"
                changed = changed + 1
            elseif f.size > was.size then
                since = "+" .. human(f.size - was.size)
                changed = changed + 1
            elseif f.size < was.size then
                since = "-" .. human(was.size - f.size) .. " ⚠️"
                changed = changed + 1
            else
                since = "unchanged"
            end
            local shortName = f.name
            if f.dir ~= core.logsDir then
                shortName = (f.dir:match("[^/]+$") or "?") .. "/" .. f.name
            end
            L[#L + 1] = string.format("   %-42s %10s %8s  %-16s %s",
                shortName:sub(1, 42), human(f.size),
                rows and tostring(rows) or "—",
                ago(f.mtime, now), since)
        end
        if #live == 0 then
            L[#L + 1] = "   (no log files found — is the Logs folder reachable?)"
        end

        -- 🗄 Listed, but under their own heading and never measured for
        -- staleness. These are the files that made "which one am I
        -- looking at?" a real question in the first place; seeing them
        -- named, with the word RETIRED next to them, is the answer.
        if #retired > 0 then
            L[#L + 1] = ""
            L[#L + 1] = "   RETIRED COPIES — kept on purpose, never written to:"
            for _, f in ipairs(retired) do
                L[#L + 1] = string.format("   %-42s %10s  last written %s",
                    f.name:sub(1, 42), human(f.size), ago(f.mtime, now))
            end
        end

        L[#L + 1] = ""
        local problems = wl.check(false)
        if #problems == 0 then
            L[#L + 1] = string.format(
                "   ✅ %d live file%s, %d changed since boot. Nothing missing, "
                .. "nothing shrunk, no duplicate logs.",
                #live, #live == 1 and "" or "s", changed)
        else
            for _, p in ipairs(problems) do
                L[#L + 1] = "   " .. p.text:gsub("^💾 ", "⚠️ ")
            end
        end
        return table.concat(L, "\n")
    end

    -- The name you would actually type. Short on purpose: this is the
    -- answer to a question asked in a hurry.
    function _G.saved()
        local ok, text = pcall(wl.report)
        if not ok then
            print("💾 Write ledger failed: " .. tostring(text))
            return nil
        end
        print(text)
        return text
    end

    -- What ⇪⇧D's report calls. Same text, no printing — diagnostics does
    -- its own printing, clipboard copy and file write.
    function _G.writeLedgerReport()
        local ok, text = pcall(wl.report)
        return ok and text or ("💾 WRITE LEDGER\n   report failed: " .. tostring(text))
    end

    core.provide("writeLedger.report", function() return wl.report() end)
    core.provide("writeLedger.check",  function() return wl.check(true) end)
    core.provide("writeLedger.scan",   function() return wl.scan()  end)

    _G.writeLedger = wl
    M.wl     = wl
    M.config = wl
end

-- ⏱ THE BASELINE AND THE TIMER BOTH BELONG TO warm(). Scanning the Logs
-- folder means touching OneDrive, which on a cold boot is the slowest
-- thing this config can ask for — and it is not needed until something
-- has had time to be written.
M.warm = function()
    local wl = _G.writeLedger
    if not (wl and wl.enabled) then return end
    wl.takeBaseline()
    -- The first check is deliberately NOT run here: at warm() nothing has
    -- changed since the baseline it just took, so it could only ever
    -- report on a twin — and it will, half an hour from now, by which
    -- point the Console is not still scrolling with boot lines.
    wl.timer = hs.timer.doEvery(wl.checkEvery, function()
        pcall(wl.check, true)
    end)
end

return M
