-- =====================================================================
-- MODULE: MASTER LOG — one chronological file from every store, and a
--         full-text index of it (6.169.0)
-- =====================================================================
-- LL, from the Gemini thread: "all these log files should be merged into
-- one long file to rule them all" — and then "maintain local log files
-- and have periodic sync into the database", with full-text search.
--
-- What already existed, and is NOT duplicated here: every store keeps
-- writing exactly as before (the file tracker's CSV, the activity log,
-- Chrome's archive, the OCR text, the clipboard, the app-update rows,
-- 6.169.0's open-documents CSV), and ⇪space still reads them live. This
-- module only READS them, and produces two things:
--
--   1. master_log-<Mac>.csv in the Logs folder — every store's rows in
--      ONE fixed layout, newest first:
--        timestamp,source,app,action,text,path,epoch
--      Excel opens it; ⇪space can be told about it later without a
--      second search UI. Rebuilt whole every ml.every seconds (and by
--      _G.masterLogBuild()), sliced under ml.sliceBudget per event-loop
--      turn so a 100k-row rebuild never stalls the keyboard (the 6.152.1
--      lesson). Registered with the write ledger: it is rewritten whole
--      by design, and a shrink is reported once, not hidden.
--   2. master_log.db — an SQLite FTS5 index of that CSV, built by the
--      SAME /usr/bin/sqlite3 the Chrome archive uses (hs.task, never on
--      the main thread), kept in ~/Library/Application Support (a live
--      database inside a syncing OneDrive folder is how databases
--      corrupt — the CSV is the synced record, the .db is per-Mac and
--      rebuildable). _G.masterLogSearch("budget q3") prints the newest
--      hits; masterLog.search(q, limit, fn) is the service for a picker.
--
-- ---- WHAT IT NEVER DOES -----------------------------------------------
--   · Never writes to any store it reads.
--   · Never runs sqlite3 on the main thread, never blocks on it, never
--     runs two builds at once (ml.building is the guard).
--   · No sqlite3 on this Mac, or no FTS5 in it: the CSV still builds,
--     the report says "index: unavailable — <why>", nothing else changes.
--   · Never touches secret.lua, applock.json or the snippets — the
--     source list is explicit (ml.sources), not "every file in Logs".
-- =====================================================================

local M = {
    name  = "Master Log",
    order = 9.6,
    family = "find",
    cheatsheet = {
        title = "🗂 MASTER LOG",
        entries = {
            { "file",   "master_log-<Mac>.csv in Logs — every store, one layout, newest first" },
            { "when",   "Rebuilt every 15 min in slices; _G.masterLogBuild() does it now" },
            { "index",  "SQLite FTS5 in ~/Library/Application Support — _G.masterLogSearch(\"words\")" },
            { "never",  "Reads the stores, never writes them; the .db never lives in OneDrive" },
            { "check",  "_G.masterLogReport() — rows per source, last build, index state" },
        },
    },
}

local function num(v, default)
    local n = tonumber(v)
    if n and n >= 0 then return n end
    return default
end

function M.setup(core)
    local ml = {}
    local function say(m)  if _G.diag then _G.diag.say("masterlog", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("masterlog", m) end end

    local host = core.hostTag or "Mac"
    local logs = core.logsDir or "."

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ml.enabled     = true
    ml.every       = 900          -- seconds between rebuilds
    ml.first       = 120          -- seconds after boot for the first one
    ml.days        = 180          -- rows older than this are left out
    ml.maxRows     = 200000       -- newest N survive
    ml.sliceBudget = 0.04         -- seconds of main thread per slice
    ml.index       = true         -- build the FTS5 index after the CSV
    ml.file        = logs .. "/master_log-" .. host .. ".csv"
    ml.dbPath      = (os.getenv("HOME") or ".") ..
                     "/Library/Application Support/Hammerspoon/master_log.db"
    -- The stores. kind = how the file is read; app/action/text/path say
    -- which column of THAT store lands in which column of the master log.
    ml.sources = {
        { name = "files",     file = logs .. "/file_changes-" .. host .. ".csv",
          kind = "csv", ts = 1, epoch = 7, action = 6, text = 2, path = 4, app = "Finder" },
        { name = "activity",  file = logs .. "/activity_history-" .. host .. ".csv",
          kind = "csv", ts = 1, app = 2, text = 3, path = 5, action = "active" },
        { name = "chrome",    file = logs .. "/chrome_history-" .. host .. ".csv",
          kind = "csv", ts = 1, time = 2, text = 3, path = 4, app = "Google Chrome", action = "visited" },
        -- 6.187.0 — column 3 is the image the words were read from, when
        -- the reader knew it. It is quote-aware here already, so an older
        -- two-column row simply has no path — mapping it is the whole wiring.
        { name = "ocr",       file = logs .. "/image_text-" .. host .. ".csv",
          kind = "csv", ts = 1, text = 2, path = 3, app = "Screenshots", action = "read" },
        { name = "updates",   file = logs .. "/app_updates-" .. host .. ".csv",
          kind = "csv", ts = 1, app = 2, text = 4, action = 5 },
        { name = "documents", file = logs .. "/open_documents-" .. host .. ".csv",
          kind = "csv", ts = 1, app = 2, action = 3, path = 4, text = 4, epoch = 5 },
        { name = "clipboard", file = logs .. "/clipboard_history-" .. host .. ".json",
          kind = "clipboard", app = "Clipboard", action = "copied" },
    }
    -- ----------------------------------------------------------------------

    ml.SQLITE   = "/usr/bin/sqlite3"
    ml.HEADER   = "timestamp,source,app,action,text,path,epoch"
    ml.building = false
    ml.rows     = nil        -- the last build's rows, newest first
    ml.counts   = {}         -- rows per source, last build
    ml.last     = nil        -- { when, rows, secs, slices, reason }
    ml.lastErr  = nil
    ml.indexState = "not built yet"
    ml.indexTask  = nil      -- HELD
    ml.searchTask = nil      -- HELD
    ml.timer      = nil      -- HELD: the periodic rebuild
    ml.firstTimer = nil      -- HELD
    ml.sliceTimer = nil      -- HELD: the next slice
    ml.builds     = 0

    -- ---- small helpers ----------------------------------------------------
    local function epochNow()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        if ok and type(t) == "number" then return t end
        return os.time()
    end

    local function q(v) return core.csvQuote and core.csvQuote(v) or ('"' .. tostring(v or ""):gsub('"', '""') .. '"') end

    local function split(line)
        if core.splitCSVLine then
            local ok, c = pcall(core.splitCSVLine, line)
            if ok and type(c) == "table" then return c end
        end
        local c = {}
        for f in (line .. ","):gmatch("([^,]*),") do c[#c + 1] = f end
        return c
    end

    -- "2026-09-05 08:20:12", "2026-09-05" + "08:20", "Sep 05 08:20" → epoch
    function ml.toEpoch(ts, time)
        ts = tostring(ts or "")
        local y, mo, d = ts:match("(%d%d%d%d)-(%d%d)-(%d%d)")
        local h, mi, s = (ts .. " " .. tostring(time or "")):match("(%d+):(%d+):?(%d*)")
        if not y then
            local mon, dd = ts:match("^(%a%a%a) (%d+)")
            if mon then
                local months = { Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12 }
                mo, d, y = months[mon], dd, os.date("%Y")
            end
        end
        if not (y and mo and d) then return nil end
        local ok, t = pcall(os.time, { year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                                       hour = tonumber(h) or 0, min = tonumber(mi) or 0,
                                       sec = tonumber(s) or 0 })
        return ok and t or nil
    end

    local function readAll(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local s = f:read("a"); f:close()
        return s
    end

    -- ---- one row from one store -------------------------------------------
    local function pick(src, c, key)
        local k = src[key]
        if type(k) == "number" then return c[k] or "" end
        return k or ""
    end

    function ml.rowFromCsv(src, line)
        local c = split(line)
        if #c < 2 then return nil end
        local ts = pick(src, c, "ts")
        local epoch = tonumber(pick(src, c, "epoch")) or ml.toEpoch(ts, src.time and c[src.time])
        if not epoch then return nil end
        return { epoch = math.floor(epoch), timestamp = os.date("%Y-%m-%d %H:%M:%S", math.floor(epoch)),
                 source = src.name, app = pick(src, c, "app"), action = pick(src, c, "action"),
                 text = pick(src, c, "text"), path = pick(src, c, "path") }
    end

    -- ---- the build, sliced ------------------------------------------------
    -- A build is a list of steps, each given a deadline; a step returns
    -- true while it has more to do. Between steps the event loop runs.
    function ml.build(reason)
        if not ml.enabled then return false end
        if ml.building then say("build already running — " .. tostring(reason)); return false end
        ml.building = true
        ml.lastErr = nil
        local t0 = epochNow()
        local rows, counts, slices = {}, {}, 0
        local cutoff = t0 - num(ml.days, 180) * 86400
        local steps = {}

        for _, src in ipairs(ml.sources) do
            local lines, i = nil, 1
            steps[#steps + 1] = function(deadline)
                if not lines then
                    local body = readAll(src.file)
                    if not body then counts[src.name] = 0; return false end
                    if src.kind == "clipboard" then
                        local ok, data = pcall(hs.json.decode, body)
                        lines = {}
                        if ok and type(data) == "table" then
                            for _, e in ipairs(data) do
                                if type(e) == "table" and e.text then lines[#lines + 1] = e end
                            end
                        end
                    else
                        lines = {}
                        for l in body:gmatch("[^\r\n]+") do lines[#lines + 1] = l end
                        i = 2   -- skip the header
                    end
                    counts[src.name] = 0
                    return true
                end
                while i <= #lines do
                    local e = lines[i]; i = i + 1
                    local r
                    if src.kind == "clipboard" then
                        local ep = ml.toEpoch(e.date)
                        if ep then
                            local text = tostring(e.text or "")
                            r = { epoch = ep, timestamp = os.date("%Y-%m-%d %H:%M:%S", ep),
                                  source = src.name, app = src.app, action = src.action,
                                  text = text:sub(1, 400), path = "" }
                        end
                    else
                        local ok, rr = pcall(ml.rowFromCsv, src, e)
                        if ok then r = rr end
                    end
                    if r and r.epoch >= cutoff then
                        rows[#rows + 1] = r
                        counts[src.name] = counts[src.name] + 1
                    end
                    if epochNow() > deadline then return true end
                end
                return false
            end
        end

        steps[#steps + 1] = function()
            table.sort(rows, function(a, b) return a.epoch > b.epoch end)
            local max = num(ml.maxRows, 200000)
            while #rows > max do rows[#rows] = nil end
            return false
        end

        steps[#steps + 1] = function()
            local out = { ml.HEADER }
            for _, r in ipairs(rows) do
                out[#out + 1] = table.concat({ r.timestamp, r.source, q(r.app), q(r.action),
                                               q(r.text), q(r.path), tostring(r.epoch) }, ",")
            end
            _G.rewrittenFiles = _G.rewrittenFiles or {}
            _G.rewrittenFiles[ml.file] = "master log — rebuilt whole from the stores"
            local f, err = io.open(ml.file, "w")
            if not f then
                ml.lastErr = "cannot write " .. ml.file .. ": " .. tostring(err)
                if core.warnWriteFailed then pcall(core.warnWriteFailed, "master log") end
                return false
            end
            f:write(table.concat(out, "\n"), "\n"); f:close()
            return false
        end

        local si = 1
        local function finish()
            ml.building = false
            ml.rows, ml.counts, ml.builds = rows, counts, ml.builds + 1
            ml.last = { when = os.date("%H:%M:%S"), rows = #rows, secs = epochNow() - t0,
                        slices = slices, reason = tostring(reason or "timer") }
            say(string.format("built %d rows in %d slices (%.2fs) — %s", #rows, slices,
                              ml.last.secs, ml.last.reason))
            if ml.lastErr then warn(ml.lastErr) return end
            ml.buildIndex()
        end
        local function slice()
            slices = slices + 1
            local deadline = epochNow() + num(ml.sliceBudget, 0.04)
            while si <= #steps do
                local ok, more = pcall(steps[si], deadline)
                if not ok then
                    ml.lastErr = "step " .. si .. ": " .. tostring(more)
                    si = si + 1
                elseif more then
                    break
                else
                    si = si + 1
                end
                if epochNow() > deadline then break end
            end
            if si > #steps then finish(); return end
            local okT, t = pcall(hs.timer.doAfter, 0, slice)
            if okT and t then ml.sliceTimer = t
            else ml.lastErr = "could not schedule the next slice"; finish() end
        end
        slice()
        return true
    end

    -- ---- the FTS5 index (sqlite3 in an hs.task) ----------------------------
    function ml.sqliteOK()
        local ok, attr = pcall(function() return hs.fs.attributes(ml.SQLITE) end)
        return ok and attr ~= nil
    end

    function ml.buildIndex()
        if not ml.index then ml.indexState = "off (ml.index = false)"; return false end
        if not ml.sqliteOK() then ml.indexState = "unavailable — no " .. ml.SQLITE; return false end
        local dir = ml.dbPath:match("^(.*)/[^/]+$")
        if dir then pcall(function() hs.fs.mkdir(dir) end) end
        local args = {
            "-batch", ml.dbPath,
            "CREATE VIRTUAL TABLE IF NOT EXISTS log USING fts5(timestamp, source, app, action, text, path, epoch UNINDEXED);",
            "DELETE FROM log;",
            ".mode csv",
            '.import --skip 1 "' .. ml.file:gsub('"', '""') .. '" log',
        }
        local ok, task = pcall(hs.task.new, ml.SQLITE, function(code, _, serr)
            ml.indexTask = nil
            if code == 0 then
                ml.indexState = "built " .. os.date("%H:%M:%S") .. " — " .. ml.dbPath
                say("index " .. ml.indexState)
            else
                ml.indexState = "failed (exit " .. tostring(code) .. "): " .. tostring(serr or ""):gsub("%s+$", "")
                warn("index " .. ml.indexState)
            end
        end, args)
        if not (ok and task) then ml.indexState = "unavailable — hs.task: " .. tostring(task); return false end
        local started = false
        pcall(function() started = task:start() end)
        if not started then ml.indexState = "unavailable — sqlite3 would not start"; return false end
        ml.indexTask = task
        ml.indexState = "building…"
        return true
    end

    -- FTS5 query from words: each word quoted (so "budget q3" is two
    -- phrases), a trailing * on the last one so typing matches prefixes.
    function ml.ftsQuery(text)
        local parts = {}
        for w in tostring(text or ""):gmatch("%S+") do
            parts[#parts + 1] = '"' .. w:gsub('"', '""') .. '"'
        end
        if #parts == 0 then return nil end
        parts[#parts] = parts[#parts] .. "*"
        return table.concat(parts, " ")
    end

    -- search(q, limit, fn) → fn(rows | nil, err). Rows are master-log
    -- tables, newest first. Always asynchronous, never on the main thread.
    function ml.search(text, limit, fn)
        fn = fn or function() end
        local fts = ml.ftsQuery(text)
        if not fts then fn(nil, "nothing to search for"); return false end
        if not ml.sqliteOK() then fn(nil, "no " .. ml.SQLITE); return false end
        local sql = string.format(
            "SELECT timestamp, source, app, action, text, path, epoch FROM log WHERE log MATCH '%s' ORDER BY epoch DESC LIMIT %d;",
            (fts:gsub("'", "''")), math.floor(num(limit, 40)))
        local ok, task = pcall(hs.task.new, ml.SQLITE, function(code, sout, serr)
            ml.searchTask = nil
            if code ~= 0 then fn(nil, (tostring(serr or ""):gsub("%s+$", ""))); return end
            local rows = {}
            local okJ, data = pcall(function() return hs.json.decode(sout) end)
            if okJ and type(data) == "table" then rows = data
            elseif tostring(sout or ""):match("%S") then fn(nil, "unreadable reply"); return end
            fn(rows, nil)
        end, { "-batch", "-json", ml.dbPath, sql })
        if not (ok and task) then fn(nil, "hs.task: " .. tostring(task)); return false end
        local started = false
        pcall(function() started = task:start() end)
        if not started then fn(nil, "sqlite3 would not start"); return false end
        ml.searchTask = task
        return true
    end

    -- ---- report ---------------------------------------------------------
    function _G.masterLogReport()
        local L = { "🗂 MASTER LOG" }
        L[#L + 1] = "   file          : " .. ml.file
        L[#L + 1] = string.format("   rebuilds      : every %ds (first %ds after boot) · %d day window · %d rows max · %s",
                                  num(ml.every, 900), num(ml.first, 120), num(ml.days, 180),
                                  num(ml.maxRows, 200000), ml.enabled and "on" or "off")
        if ml.last then
            L[#L + 1] = string.format("   last build    : %s · %d rows · %d slices · %.2fs · %s",
                                      ml.last.when, ml.last.rows, ml.last.slices, ml.last.secs, ml.last.reason)
            for _, src in ipairs(ml.sources) do
                L[#L + 1] = string.format("      %-10s : %s", src.name,
                                          ml.counts[src.name] and tostring(ml.counts[src.name]) or "not read")
            end
        else
            L[#L + 1] = "   last build    : none yet" .. (ml.building and " (building)" or "")
        end
        if ml.lastErr then L[#L + 1] = "   ⚠️ last error : " .. ml.lastErr end
        L[#L + 1] = "   index         : " .. ml.indexState
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    function _G.masterLogBuild() return ml.build("_G.masterLogBuild()") end

    function _G.masterLogSearch(text, limit)
        return ml.search(text, limit or 20, function(rows, err)
            if not rows then print("🗂 master log: " .. tostring(err)); return end
            print(string.format("🗂 master log — %d hit%s for %q", #rows, #rows == 1 and "" or "s", tostring(text)))
            for _, r in ipairs(rows) do
                print(string.format("   %s  %-10s %-16s %-8s %s%s", r.timestamp or "", r.source or "",
                                    r.app or "", r.action or "", tostring(r.text or ""):sub(1, 80),
                                    (r.path and r.path ~= "") and ("  ·  " .. r.path) or ""))
            end
        end)
    end

    core.provide("masterLog.build",  function(why) return ml.build(why or "service") end)
    core.provide("masterLog.search", function(text, limit, fn) return ml.search(text, limit, fn) end)
    core.provide("masterLog.rows",   function() return ml.rows or {} end)
    core.provide("masterLog.report", function() return _G.masterLogReport() end)
    _G.masterLog = ml
    M.ml = ml
    M.config = ml

    if not ml.enabled then return end

    -- Timers are read AFTER the profile override lands: the first build
    -- waits ml.first seconds, and the periodic one is armed then.
    local okF, ft = pcall(hs.timer.doAfter, num(ml.first, 120), function()
        ml.firstTimer = nil
        if not ml.enabled then return end
        ml.build("first build after boot")
        local okE, et = pcall(hs.timer.doEvery, num(ml.every, 900), function()
            if ml.enabled then ml.build("timer") end
        end)
        if okE and et then ml.timer = et else warn("periodic rebuild not armed: " .. tostring(et)) end
    end)
    if okF and ft then ml.firstTimer = ft else warn("first build not armed: " .. tostring(ft)) end
end

return M
