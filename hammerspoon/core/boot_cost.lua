-- =====================================================================
-- core/boot_cost.lua — where the boot time actually goes, 6.178.0
-- =====================================================================
-- LL, after the 6.177.0 zip came in at 2.1 MB: "have we reviewed the
-- code for size?" The honest answer was that nobody had MEASURED it.
-- Every module's load time was already recorded (rec.ms, and rec.warmMs
-- for the second phase) — but it only ever showed one line at a time
-- under bootVerbose, and nothing added it up or ranked it. So the size
-- conversation had no numbers in it, and a decision to trim would have
-- been taste rather than evidence.
--
-- This file turns the numbers that already exist into a ranking, and
-- says nothing at all when the boot was fast. Same philosophy as
-- boot_report.lua beside it: quiet when healthy, loud when not.
--
-- IT MEASURES, IT NEVER CHANGES ANYTHING. Nothing here loads a module,
-- unloads one, defers one, or decides what should run. It reads
-- _G.moduleStatus after the fact. The worst it can do on a Mac where
-- something is missing is print less.
--
-- Size is read with hs.fs.attributes on the CONFIG folder only — never
-- OneDrive, never a note, never anything that could be a placeholder
-- (those block the main thread on read; see the vault's rule).
-- =====================================================================

return function(core)
    core = type(core) == "table" and core or {}

    local cost = {
        slowModuleMs = 150,    -- one module over this is worth a line
        slowTotalMs  = 1500,   -- the whole load phase over this is worth a line
        topN         = 3,      -- how many are named in the one-line warning
        dir          = core.moduleDir or _G.moduleDir,
        -- 6.179.0 — one CSV row per boot, so "is it getting slower?" is a
        -- question with an answer. Appended, never rewritten: an append
        -- cannot shrink a file, so this store needs no write ledger.
        history      = true,
        historyAfter = 4.0,    -- seconds — after the warm phase, so its ms count
        historyShow  = 10,     -- boots the report compares this one against
        historyTail  = 16384,  -- bytes read off the END of the file — never the whole of it
        historyBig   = 512000, -- past this the report says the file has grown
        driftFactor  = 2.0,    -- this boot over N× the usual is worth saying
        hostTag      = core.hostTag or _G.hostTag or "Mac",
        logsDir      = core.logsDir,
    }
    if cost.logsDir and cost.logsDir ~= "" then
        cost.historyFile = cost.logsDir .. "/boot_cost-" .. tostring(cost.hostTag) .. ".csv"
    end
    _G.bootCost = cost

    -- Every number in one place, so the report and the boot line can
    -- never disagree about what they measured.
    local function gather()
        local rows, totalLoad, totalWarm, warmed, sized = {}, 0, 0, 0, 0
        for _, r in ipairs(_G.moduleStatus or {}) do
            local ms   = tonumber(r.ms) or 0
            local wms  = tonumber(r.warmMs) or 0
            local bytes = nil
            if cost.dir and type(hs) == "table" and type(hs.fs) == "table"
               and type(hs.fs.attributes) == "function" then
                local ok, a = pcall(hs.fs.attributes, r.path or (cost.dir .. "/" .. tostring(r.name) .. ".lua"))
                if ok and type(a) == "table" and tonumber(a.size) then
                    bytes = tonumber(a.size)
                    sized = sized + 1
                end
            end
            rows[#rows + 1] = { name = r.name, ms = ms, warmMs = wms, bytes = bytes,
                                ok = r.ok == true, warmed = r.warmed }
            totalLoad = totalLoad + ms
            totalWarm = totalWarm + wms
            if r.warmMs then warmed = warmed + 1 end
        end
        table.sort(rows, function(a, b)
            if a.ms == b.ms then return tostring(a.name) < tostring(b.name) end
            return a.ms > b.ms
        end)
        return { rows = rows, totalLoad = totalLoad, totalWarm = totalWarm,
                 warmed = warmed, sized = sized, count = #rows }
    end
    cost.gather = gather

    local function kb(bytes)
        if not bytes then return "     ?" end
        return string.format("%5.0fK", bytes / 1024)
    end

    -- The full table, newest-first by cost. Printed on demand only.
    function _G.bootCostReport()
        local g = gather()
        print("⏱  BOOT COST — where the load time went")
        if g.count == 0 then
            print("   no module timings this session (nothing loaded, or an older init.lua)")
            return 0
        end
        print(string.format("   %d modules · %.0f ms to load%s",
              g.count, g.totalLoad,
              g.warmed > 0 and string.format(" · %.0f ms more warming %d of them",
                                             g.totalWarm, g.warmed) or ""))
        if g.sized == 0 then
            print("   (file sizes unavailable here — timings only)")
        end
        print("   ── slowest first ──────────────────────────────────")
        for _, r in ipairs(g.rows) do
            print(string.format("   %6.0f ms  %s  %-22s%s%s",
                  r.ms, kb(r.bytes), tostring(r.name),
                  r.warmMs > 0 and string.format("  +%.0f ms warm", r.warmMs) or "",
                  (not r.ok) and "  ⚠️ FAILED" or ""))
        end
        local rows = cost.readHistory(cost.historyShow)
        local usual, n = cost.usualMs(rows)
        if not cost.historyFile then
            print("   history: off — no Logs folder on this Mac")
        elseif cost.lastRecordErr then
            print("   history: NOT being written — " .. tostring(cost.lastRecordErr))
            print("   file    : " .. cost.historyFile .. "  (nothing has landed there)")
        elseif n == 0 then
            print("   history: " .. cost.historyFile .. "  (nothing to compare yet — this may be the first boot)")
        else
            print(string.format("   history: %d recent boots · usually %.0f ms · this one %.0f ms%s",
                  n, usual, g.totalLoad,
                  usual > 0 and g.totalLoad > usual * cost.driftFactor and "  ⚠️ slower than usual" or ""))
            local last = rows[#rows]
            if last then
                print("   last row: " .. tostring(last.when) .. " · " .. tostring(last.version)
                      .. " · slowest was " .. tostring(last.slowest))
            end
            local big = nil
            if type(hs) == "table" and type(hs.fs) == "table" and type(hs.fs.attributes) == "function" then
                local okA, a = pcall(hs.fs.attributes, cost.historyFile)
                if okA and type(a) == "table" and tonumber(a.size) then big = tonumber(a.size) end
            end
            print("   file    : " .. cost.historyFile .. "  (Excel opens it)"
                  .. (big and string.format("  %.0f KB", big / 1024) or "")
                  .. ((big and big > cost.historyBig)
                      and " — it has grown; delete it and it starts again" or ""))
        end
        print("   Size and speed are NOT the same thing: a big file full of"
              .. " comments parses fast, a small one that talks to macOS at")
        print("   setup does not. Trim on the milliseconds, never on the"
              .. " kilobytes. A slow module is a candidate for warm(),")
        print("   which runs after the boot instead of inside it — or for"
              .. " leaving out of a profile that does not need it.")
        return g.count
    end

    -- ---- the history: one row per boot -----------------------------------
    -- Never read at boot and never written on the main thread's critical
    -- path: the row goes out on a held timer AFTER the warm phase, and
    -- the file is only read when LL asks for the report.
    -- The reader below is a plain pattern, not an RFC 4180 parser, so the
    -- WRITER must never emit anything it cannot read back: a quote, a
    -- newline or a comma inside a value would make the row unparseable
    -- and the row would then vanish from the history in silence. Module
    -- and profile names are ours, so flattening them costs nothing.
    local function csvField(s)
        s = tostring(s or ""):gsub('[\r\n]', " "):gsub('"', "'"):gsub(",", ";")
        return '"' .. s .. '"'
    end
    -- Same contract for the numbers: the reader accepts digits only, and a
    -- clock stepped backwards by NTP during the load phase (login is
    -- exactly when macOS does that) can make a duration negative.
    local function csvNum(n)
        n = tonumber(n)
        if not n or n ~= n or n == math.huge or n == -math.huge or n < 0 then n = 0 end
        return string.format("%.0f", n)
    end

    function cost.record()
        cost.lastRecordErr = nil
        local function no(why)
            cost.lastRecordErr = why
            return false, why
        end
        if cost.history == false then return no("history is off") end
        if not cost.historyFile then return no("no Logs folder — history off") end
        local g = gather()
        if g.count == 0 then return no("nothing measured") end
        local worst = g.rows[1] or {}
        local f, why = io.open(cost.historyFile, "a")
        if not f then return no(tostring(why or "cannot append")) end
        -- Does this file already have its header? Ask the HANDLE first —
        -- a file opened for append reports its own size, and that answer
        -- needs no hs.fs at all. (6.179.0 review: deciding this from
        -- hs.fs alone meant a Mac without it wrote the header on every
        -- boot — "header once" was true only where hs.fs existed.)
        local size = nil
        pcall(function() size = f:seek("end") end)
        local hasHeader
        if type(size) == "number" then
            hasHeader = size > 0
        elseif type(hs) == "table" and type(hs.fs) == "table" and type(hs.fs.attributes) == "function" then
            local okA, a = pcall(hs.fs.attributes, cost.historyFile)
            hasHeader = okA and type(a) == "table"
        else
            hasHeader = cost.wroteHeader == true    -- no way to ask: at most one per session
        end
        if not hasHeader then
            f:write("when,version,profile,modules,loadMs,warmMs,slowest,slowestMs,epoch\n")
            cost.wroteHeader = true
        end
        local row = table.concat({
            csvField(os.date("%Y-%m-%d %H:%M:%S")),
            csvField(_G.configVersion or "?"),
            csvField(_G.moduleProfileName or "?"),
            csvNum(g.count),
            csvNum(g.totalLoad),
            csvNum(g.totalWarm),
            csvField(worst.name or "?"),
            csvNum(worst.ms or 0),
            csvNum(os.time()),
        }, ",")
        f:write(row .. "\n")
        f:close()
        cost.recorded = true
        return true
    end

    -- The last N rows, oldest first. Returns {} for every failure — a
    -- history that cannot be read costs the comparison, never the boot.
    function cost.readHistory(n)
        if not cost.historyFile then return {} end
        n = tonumber(n) or 10
        local f = io.open(cost.historyFile, "r")
        if not f then return {} end
        -- 🚨 THE TAIL, NEVER THE WHOLE FILE. This store is append-only and
        -- has no cap: one row per boot, and every reload is a boot. Reading
        -- it whole would cost more every month it exists, on the main
        -- thread, forever — the exact shape of fault this module was built
        -- to catch. So: seek to the end, take the last historyTail bytes,
        -- and drop the first (probably partial) line. Bounded work no
        -- matter how long LL keeps the file.
        local blob
        local okS = pcall(function()
            local size = f:seek("end") or 0
            local from = math.max(0, size - (tonumber(cost.historyTail) or 16384))
            f:seek("set", from)
            blob = f:read("a")
            if from > 0 and blob then blob = blob:match("\n(.*)$") or "" end
        end)
        if not okS then
            local okR, whole = pcall(function() return f:read("a") end)
            blob = okR and whole or nil
        end
        pcall(function() f:close() end)
        if type(blob) ~= "string" then return {} end
        -- A ring while scanning: table.remove(rows, 1) on a long file is
        -- O(N²), which is the same mistake in a different costume.
        local ring, at, full = {}, 0, false
        for line in blob:gmatch("[^\r\n]+") do
            local when, ver, prof, mods, load, warm, slow, slowMs =
                line:match('^"([^"]*)","([^"]*)","([^"]*)",(%d+),(%d+),(%d+),"([^"]*)",(%d+)')
            if when then
                at = at % n + 1
                if at == 1 and #ring == n then full = true end
                ring[at] = { when = when, version = ver, profile = prof,
                             modules = tonumber(mods), loadMs = tonumber(load),
                             warmMs = tonumber(warm), slowest = slow,
                             slowestMs = tonumber(slowMs) }
                if #ring < n then full = false end
            end
        end
        local rows = {}
        if #ring == 0 then return rows end
        local start = (#ring == n and full) and at or 0
        for i = 1, #ring do rows[i] = ring[(start + i - 1) % #ring + 1] end
        return rows
    end

    -- The middle of the recent boots — a median, not a mean, so one
    -- pathological boot does not move the line everything is judged by.
    function cost.usualMs(rows)
        rows = rows or cost.readHistory(cost.historyShow)
        local ms = {}
        for _, r in ipairs(rows) do if r.loadMs then ms[#ms + 1] = r.loadMs end end
        if #ms == 0 then return nil, 0 end
        table.sort(ms)
        local mid = math.floor((#ms + 1) / 2)
        return ms[mid], #ms
    end

    -- The boot line: SILENT on a fast boot. A slow one names the total
    -- and the worst few, because a number you only see when you go
    -- looking is a number nobody looks at.
    function cost.line()
        local g = gather()
        if g.count == 0 then return nil end
        local worst = g.rows[1]
        if g.totalLoad < cost.slowTotalMs and (not worst or worst.ms < cost.slowModuleMs) then
            return nil
        end
        local names = {}
        for i = 1, math.min(cost.topN, #g.rows) do
            names[#names + 1] = string.format("%s %.0fms", g.rows[i].name, g.rows[i].ms)
        end
        return string.format("⏱  Boot cost: %.0f ms across %d modules — slowest: %s."
                             .. "  _G.bootCostReport() ranks them all.",
                             g.totalLoad, g.count, table.concat(names, ", "))
    end

    -- 6.179.0 — "slower than usual" is a SEPARATE line, and deliberately
    -- not part of the one above: it has to read the history file, and
    -- nothing in this config reads a file in OneDrive on the boot path
    -- (a dehydrated placeholder blocks the main thread on read — the
    -- rule the vault is built around). So it runs with the history
    -- write, seconds later, off the boot entirely — and it compares
    -- against the rows written BEFORE this boot, never including itself.
    function cost.driftLine(rows)
        local g = gather()
        if g.count == 0 then return nil end
        local usual, n = cost.usualMs(rows)
        if not (n >= 3 and usual and usual > 0) then return nil end
        if g.totalLoad <= usual * cost.driftFactor then return nil end
        return string.format("⏱  Boot cost: %.0f ms — this Mac usually takes %.0f."
                             .. "  _G.bootCostReport() ranks the modules.",
                             g.totalLoad, usual)
    end

    -- Printed a turn later, like every other boot line that reads a
    -- value the profile can override — and never if there is nothing
    -- worth saying.
    local okT, t = pcall(hs.timer.doAfter, 0.1, function()
        local ok, line = pcall(cost.line)
        if ok and line then print(line) end
    end)
    _G.bootCostTimer = okT and t or nil
    if not okT then
        local ok, line = pcall(cost.line)
        if ok and line then print(line) end
    end

    -- The history row goes out after the warm phase, on a held timer, so
    -- it carries the warm milliseconds and costs the boot nothing.
    if cost.history ~= false and cost.historyFile then
        -- KNOWN LIMIT, stated rather than hidden: this step does a 16 KB
        -- tail read and a ~90-byte append against a file in OneDrive, on
        -- the main thread, four seconds after the boot. That is off the
        -- boot path and bounded, and the file is one this config writes
        -- on every boot (so it is the last thing OneDrive would
        -- dehydrate) — but it is not nothing. If a post-boot stall is
        -- ever traced here, the move is to do the read and the append in
        -- an hs.task, not to touch the boot line.
        local function historyStep()
            -- read FIRST (the rows before this boot), say it, then append
            local okD, line = pcall(cost.driftLine, cost.readHistory(cost.historyShow))
            if okD and line then print(line) end
            -- pcall returns true, false, "reason" when record() DECLINES —
            -- reading only the first two makes a refusal look like a
            -- success, which is how a report comes to state something
            -- untrue. Both are read, and the reason is kept for the report.
            local ok, wrote, why = pcall(cost.record)
            if not ok then
                cost.lastRecordErr = tostring(wrote)
            end
            if (not ok or not wrote) and _G.diag and _G.diag.warn then
                pcall(_G.diag.warn, "bootCost", tostring(cost.lastRecordErr or why or "not written"))
            end
        end
        local okH, th = pcall(hs.timer.doAfter, cost.historyAfter, historyStep)
        _G.bootCostHistoryTimer = okH and th or nil
        if not okH then pcall(historyStep) end     -- no timer here: do it now or never
    end

    return cost
end
