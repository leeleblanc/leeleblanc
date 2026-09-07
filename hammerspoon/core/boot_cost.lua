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
    }
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
        print("   Size and speed are NOT the same thing: a big file full of"
              .. " comments parses fast, a small one that talks to macOS at")
        print("   setup does not. Trim on the milliseconds, never on the"
              .. " kilobytes. A slow module is a candidate for warm(),")
        print("   which runs after the boot instead of inside it — or for"
              .. " leaving out of a profile that does not need it.")
        return g.count
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

    return cost
end
