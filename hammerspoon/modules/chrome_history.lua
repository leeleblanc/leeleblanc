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
-- keyboard. `-json` output rather than delimited, because page titles
-- contain every delimiter anyone has ever chosen. Entries younger than
-- 90 days and not hidden (Chrome's own flag for redirect noise), one
-- row per page, newest first.
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
            { "⇪⇧Y",     "Re-read Chrome now and re-save the CSV, with a count" },
            { "file",    "chrome_history-<Mac>.csv in the Logs folder — Excel opens it" },
            { "@web",    "The same pages inside ⇪space — there ⏎ copies the URL" },
            { "console", "_G.chromeHistoryReport() — per profile, span, file, timings" },
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
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("chrome", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("chrome", m) end end

    chrome.entries   = {}     -- { url, title, visits, ts, when, profile, hay, titleLen }
    chrome.status    = "off"
    chrome.loadedAt  = 0
    chrome.exporting = false
    chrome.lastMs    = nil

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
    local SCRIPT = [[
sq="$1"; tmp="$2"; cutoff="$3"; limit="$4"; shift 4
n=0
while [ "$#" -ge 2 ]; do
  lbl="$1"; db="$2"; shift 2
  n=$((n+1))
  cp -f "$db" "$tmp/hs-chrome-$n.db" 2>/dev/null || continue
  cp -f "$db-wal" "$tmp/hs-chrome-$n.db-wal" 2>/dev/null
  cp -f "$db-shm" "$tmp/hs-chrome-$n.db-shm" 2>/dev/null
  printf '##PROFILE## %s\n' "$lbl"
  "$sq" -json "$tmp/hs-chrome-$n.db" "SELECT url, title, visit_count AS visits, CAST(last_visit_time/1000000 - 11644473600 AS INTEGER) AS ts FROM urls WHERE last_visit_time > $cutoff AND hidden = 0 ORDER BY last_visit_time DESC LIMIT $limit;"
  printf '\n'
  rm -f "$tmp/hs-chrome-$n.db" "$tmp/hs-chrome-$n.db-wal" "$tmp/hs-chrome-$n.db-shm"
done
]]

    -- stdout → entries. Each profile's block is a JSON array under its
    -- ##PROFILE## marker; a profile whose block will not parse costs that
    -- profile a warning, never the export.
    function chrome.parse(out)
        local entries, label, buf = {}, nil, {}
        local function flush()
            local raw = table.concat(buf, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
            buf = {}
            if not label or raw == "" then return end
            local okDec, rows = pcall(function() return hs.json.decode(raw) end)
            if not (okDec and type(rows) == "table") then
                warn("the " .. label .. " block did not parse as JSON")
                return
            end
            for _, r in ipairs(rows) do
                if type(r) == "table" and type(r.url) == "string" and r.url ~= "" then
                    entries[#entries + 1] = finish({
                        url = r.url, title = r.title, visits = r.visits,
                        ts = r.ts, profile = label,
                    })
                end
            end
        end
        for line in (tostring(out or "") .. "\n"):gmatch("(.-)\n") do
            local l = line:match("^##PROFILE## (.+)$")
            if l then flush(); label = l else buf[#buf + 1] = line end
        end
        flush()
        table.sort(entries, function(a, b) return a.ts > b.ts end)
        return entries
    end

    -- ---- the file --------------------------------------------------------
    local function csvField(s)
        s = tostring(s or "")
        if s:find('[",\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
        return s
    end

    function chrome.writeCsv(entries)
        local f = io.open(chrome.csvFile, "w")
        if not f then
            warn("could not write " .. chrome.csvFile)
            if core.warnWriteFailed then core.warnWriteFailed("chrome_history csv") end
            return false
        end
        f:write("date,time,title,url,visits,profile\n")
        for _, e in ipairs(entries) do
            f:write(os.date("%Y-%m-%d", e.ts), ",", os.date("%H:%M", e.ts), ",",
                    csvField(e.title), ",", csvField(e.url), ",",
                    tostring(e.visits), ",", csvField(e.profile), "\n")
        end
        f:close()
        return true
    end

    -- Read LAST SESSION'S save back, so ⇪Y answers seconds after login
    -- while the fresh export runs behind it. ts is rebuilt from the date
    -- and time columns — approximate to the minute, which is all the
    -- ranking needs.
    function chrome.loadCsv()
        local f = io.open(chrome.csvFile, "r")
        if not f then return 0 end
        local entries, first = {}, true
        for line in f:lines() do
            if first then
                first = false          -- the header row
            else
                local c = core.splitCSVLine and core.splitCSVLine(line)
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
            end
        end
        f:close()
        table.sort(entries, function(a, b) return a.ts > b.ts end)
        chrome.entries = entries
        return #entries
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
        local okNew, t = pcall(function()
            return hs.task.new("/bin/sh", function(code, sout, serr)
                chrome.exporting = false
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
                local entries = chrome.parse(sout)
                chrome.entries  = entries
                chrome.loadedAt = epoch()
                chrome.writeCsv(entries)
                chrome.status = string.format("%d pages · %d profile%s · %.0fms",
                                              #entries, #dbs,
                                              #dbs == 1 and "" or "s",
                                              chrome.lastMs)
                say("exported " .. chrome.status)
                if andThen then andThen(true, #entries) end
            end, args)
        end)
        if not (okNew and t) then
            chrome.status = "export failed (hs.task unavailable)"
            warn(chrome.status)
            return false
        end
        chrome.task = t     -- held: an unreferenced task is collected mid-run
        chrome.exporting = true
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            chrome.exporting = false
            chrome.status = "export failed (sh would not start)"
            warn(chrome.status)
            return false
        end
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
    function chrome.open(url)
        local ok = false
        pcall(function() ok = hs.urlevent.openURLWithBundle(url, chrome.openWith) end)
        if not ok then pcall(function() ok = hs.urlevent.openURL(url) end) end
        if not ok then
            pcall(function() hs.alert.show("🕘 could not open " .. url:sub(1, 60)) end)
            warn("neither Chrome nor the default browser took " .. url:sub(1, 90))
        end
        return ok
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
                pcall(function()
                    hs.alert.show("🕘 Reading Chrome history — press ⇪Y again in a moment")
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
                if pick and pick.url then chrome.open(pick.url) end
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
            chrome.chooser:placeholderText(#chrome.entries
                .. " pages, 90 days — type fragments, ⏎ reopens")
            chrome.chooser:query("")
            chrome.chooser:choices(choicesFor(chrome.search("")))
            chrome.chooser:show()
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
    function chrome.report()
        local lines = {}
        local function outLine(s) lines[#lines + 1] = s; print(s) end
        outLine("🕘 Chrome history — " .. tostring(chrome.status))
        outLine("   file: " .. chrome.csvFile)
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
        if #order == 0 then outLine("   (no entries loaded)") end
        return table.concat(lines, "\n")
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
        local had = 0
        pcall(function() had = chrome.loadCsv() end)
        if had > 0 then
            chrome.loadedAt = 0    -- data, but stale by definition
            chrome.status = had .. " pages (last save; refreshing)"
        end
        chrome.export()
    end

    _G.chromeHistory       = chrome
    _G.chromeHistoryReport = function() return chrome.report() end
    M.chrome = chrome
    M.config = chrome
end

return M
