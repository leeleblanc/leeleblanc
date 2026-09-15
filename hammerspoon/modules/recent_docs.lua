-- =====================================================================
-- MODULE: RECENT DOCUMENTS (⇪I) — the nine you just had open, then
-- everything else you actually work on. 6.93.0
-- =====================================================================
-- LL: "find recent documents that I've opened … populate the first nine
-- documents that have been opened recently, and then after that …
-- start showing other documents … search in multiple ways by file name
-- by date by file extension … leave out files that I don't actively
-- use … I have thousands of plists and I don't want those to turn up."
-- And: "if it's a file type I recently opened, it should display file
-- types like the file type I just opened. So I won't always know what
-- file types I'm going to be working on. And, you know how I have the
-- file watcher … I'm also watching renamed files. Could we integrate
-- that here."
--
-- 🔍 THE "OPENED" SIGNAL IS SPOTLIGHT'S kMDItemLastUsedDate, and that
-- choice IS the plist answer: macOS stamps it only when an app opens a
-- file FOR YOU (LaunchServices), never when a background write touches
-- it. The thousands of system-churned plists have no such stamp; the
-- one you genuinely opened while working in Outlook does. No blocklist
-- to maintain — the OS already recorded intent.
--
-- 🎓 TYPES TEACH THEMSELVES, under one rule that makes floods
-- structurally impossible:
--   · SEED types (the Office set + txt/lua/csv…) also show files that
--     were merely MODIFIED — a spreadsheet someone just sent appears
--     before you've opened it.
--   · Any OTHER extension joins the moment you open ONE file of it —
--     but a learned type only ever lists files that carry an
--     opened-by-you stamp. One opened plist never unleashes the rest.
--   Learned types persist per-machine in <logs>/recent_doc_types-….csv;
--   _G.recentDocsReport() shows them, _G.recentDocs.unlearn("ext") ends one.
--
-- 📁 THE FILE TRACKER REMEMBERS WHAT A FILE USED TO BE CALLED — Spotlight
-- only knows what it's called now. ⇪F's in-memory log (falling back to
-- its CSV) becomes: invisible search ALIASES (type the old name, find
-- the renamed file), a story line on the row ("was Budget draft.xlsx"),
-- and activity for ranking — a file you just renamed in Finder floats
-- up even though you never "opened" it. Loose coupling on purpose: this
-- module reads the tracker's data, never calls into it; tracker off
-- means no aliases and the report says so.
--
-- 🖼 The panel is the ⇪space webview style (rows need story lines and a
-- typed search — a chooser can do neither), with BOTH house drags (bare
-- drag on the header, ⌘-drag anywhere) and the pomodoro's 6.67.0 rule:
-- A REMEMBERED POSITION WINS — drag it once, it reopens there, unless
-- that screen is gone, in which case it re-centers.
--
-- 🐚 mdfind/mdls run out of process (hs.task, /bin/sh) with every path
-- and query as a POSITIONAL argument — nothing is interpolated into the
-- script, which is what keeps "$time.now(…)" and spaced paths safe.

local M = {
    name  = "Recent Documents",
    order = 11.5,
    family = "files",
    cheatsheet = {
        title = "📂 RECENT DOCUMENTS (⇪I)",
        entries = {
            { "⇪I",     "The 9 last-opened documents, then every type you work in" },
            { "⌘1–⌘9",  "Open a numbered recent directly" },
            { "type",   "Search name · folder · date · extension — @tag pins a type · old names still match (⇪F renames)" },
            { "⏎",      "OPEN the document (⌘⏎ reveal in Finder · ⌥⏎ copy path)" },
            { "⇪⇧I",    "Re-scan now + what's been learned" },
            { "drag",   "Header moves it — and it REOPENS where you left it" },
            { "Esc",    "Close (the cheat sheet always closes after it)" },
        },
    },
}

function M.setup(core)
    local rd = {}
    local home = core.homeDir or os.getenv("HOME") or "~"

    -- ✏️ EDIT HERE ---------------------------------------------------------
    rd.enabled   = true
    rd.key       = "i"       -- ⇪I panel · ⇪⇧I re-scan + report
    rd.days      = 30        -- how far back "recently opened" reaches
    rd.seedDays  = 14        -- merely-MODIFIED window, seed types only
    rd.cap       = 400       -- most files fetched per scan, per query
    rd.staleSecs = 600       -- opening the panel re-scans past this age
    rd.shelfSize = 9         -- the numbered recents ("first nine")
    rd.width, rd.height = 840, 700
    rd.pageCap   = 60
    rd.groupCap  = 8
    rd.learnedCap = 24       -- most learned types kept (newest survive)
    rd.mdfind    = "/usr/bin/mdfind"
    rd.mdls      = "/usr/bin/mdls"     -- named in the script below
    rd.sh        = "/bin/sh"
    rd.openBin   = "/usr/bin/open"     -- ⌘⏎ reveal (-R)
    rd.csvFile   = core.logsDir .. "/recent_docs-" .. core.hostTag .. ".csv"
    rd.typesFile = core.logsDir .. "/recent_doc_types-" .. core.hostTag .. ".csv"
    -- 💾 6.154.0 — BOTH FILES ARE REWRITTEN WHOLE ON EVERY SAVE (a scan
    -- replaces the cache; the learned-types list is re-sorted and
    -- capped), so they SHRINK whenever a document ages out of the window.
    -- The write ledger would otherwise call a smaller cache a truncation
    -- — it did, in LL's Console ("recent_docs-…csv has SHRUNK — 49.7 KB
    -- at boot, 48.8 KB now"). Told here, by the module that knows.
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[rd.csvFile]   = "the ⇪I cache — rewritten after every Spotlight scan"
    _G.rewrittenFiles[rd.typesFile] = "the ⇪I learned-types list — rewritten on every learn"
    -- SEED groups: shown even merely-modified. csv sits with Excel;
    -- txt/lua are LL's 6.93.0 additions — everything else is learned.
    rd.groups = {
        { tag = "word",  icon = "📝", label = "Word",
          exts = { "docx", "doc", "dotx", "rtf" } },
        { tag = "excel", icon = "📊", label = "Excel",
          exts = { "xlsx", "xls", "xlsm", "csv" } },
        { tag = "ppt",   icon = "📽", label = "PowerPoint",
          exts = { "pptx", "ppt" } },
        { tag = "pdf",   icon = "📕", label = "PDF", exts = { "pdf" } },
        { tag = "img",   icon = "🖼", label = "Images",
          exts = { "png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp" } },
        { tag = "mail",  icon = "✉️", label = "Mail files", exts = { "msg", "eml" } },
        { tag = "txt",   icon = "✏️", label = "Text & code",
          exts = { "txt", "md", "lua" } },
    }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("recentDocs", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("recentDocs", m) end end

    rd.extTag = {}
    for _, g in ipairs(rd.groups) do
        for _, x in ipairs(g.exts) do rd.extTag[x] = g.tag end
    end

    rd.entries, rd.byPath = {}, {}
    rd.learned  = {}         -- ext -> { first, last, example }
    rd.loadedAt = 0          -- epoch of the last completed scan
    rd.pos      = nil        -- 🖐 where you dragged it — a remembered
                             -- position WINS (the pomodoro's 6.67.0 rule)

    local function epoch()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        -- floored: these reach os.date, which refuses a fractional float
        return math.floor(ok and t or os.time())
    end

    -- mdls prints UTC ("… +0000"); os.time reads tables as LOCAL, so the
    -- zone gap is measured once and subtracted. isdst is left to libc —
    -- worst case is the same ±1h every clock-change week, ordering intact.
    local function utcGap()
        local t = os.time()
        return os.difftime(os.time(os.date("!*t", t)), t)
    end
    rd.utcGap = utcGap()

    function rd.parseDate(s)
        if type(s) ~= "string" then return nil end
        local y, mo, d, h, mi, sec =
            s:match("(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)")
        if not y then return nil end
        local t = os.time{ year = tonumber(y), month = tonumber(mo),
                           day = tonumber(d), hour = tonumber(h),
                           min = tonumber(mi), sec = tonumber(sec) }
        return t and math.floor(t - rd.utcGap) or nil
    end

    local function prettyDir(dir)
        if dir:sub(1, #home) == home then return "~" .. dir:sub(#home + 1) end
        return dir
    end

    -- ---- learned types: load / save / learn -------------------------------
    local csvSplit = core.splitCSVLine or function(l)
        local out = {}
        for f in tostring(l):gmatch("[^,]+") do out[#out + 1] = f end
        return out
    end
    local function csvField(s)
        s = tostring(s or "")
        if s:find('[",\n]') then return '"' .. s:gsub('"', '""') .. '"' end
        return s
    end

    function rd.loadTypes()
        local f = io.open(rd.typesFile, "r")
        if not f then return end
        local first = true
        for line in f:read("*a"):gmatch("[^\r\n]+") do
            if not (first and line:match("^ext,")) then
                local c = csvSplit(line)
                if c[1] and tonumber(c[3]) then
                    rd.learned[c[1]:lower()] = {
                        first = tonumber(c[2]) or tonumber(c[3]),
                        last = tonumber(c[3]), example = c[4] or "" }
                end
            end
            first = false
        end
        f:close()
    end

    function rd.saveTypes()
        local order = {}
        for ext, l in pairs(rd.learned) do order[#order + 1] = { ext, l } end
        table.sort(order, function(a, b) return a[2].last > b[2].last end)
        while #order > rd.learnedCap do
            rd.learned[order[#order][1]] = nil
            order[#order] = nil
        end
        local f = io.open(rd.typesFile, "w")
        if not f then warn("could not write " .. rd.typesFile) return end
        f:write("ext,first_epoch,last_epoch,example\n")
        for _, o in ipairs(order) do
            f:write(o[1] .. "," .. tostring(o[2].first) .. ","
                .. tostring(o[2].last) .. "," .. csvField(o[2].example) .. "\n")
        end
        f:close()
    end

    function rd.unlearn(ext)
        ext = tostring(ext or ""):lower():gsub("^%.", "")
        if not rd.learned[ext] then return false end
        rd.learned[ext] = nil
        rd.saveTypes()
        say("unlearned ." .. ext)
        return true
    end

    -- ---- the ⇪F tracker, read where it already lives -----------------------
    -- Walked OLDEST→NEWEST so rename chains carry: A→B then B→C leaves C
    -- holding aliases {A, B}. "Moved out" drops the mapping — the file
    -- left the watched world and a stale alias is worse than none.
    local function expandPretty(p)
        if type(p) ~= "string" or p == "" or p:find("^%(") then return nil end
        if p:sub(1, 1) == "~" then return home .. p:sub(2) end
        if p:sub(1, 1) ~= "/" then return nil end
        return p
    end

    function rd.trackerIndex()
        local log = _G.fileTrackerLog
        if type(log) ~= "table" then return {}, false end
        local map = {}
        for _, e in ipairs(log) do
            local ev, oldP, newP = e.event, nil, nil
            if ev == "Renamed" then
                local d = expandPretty(e.presentLoc)
                if d then oldP, newP = d .. "/" .. e.fileName,
                                       d .. "/" .. e.newName end
            elseif ev == "Moved" then
                local od, nd = expandPretty(e.presentLoc), expandPretty(e.movedLoc)
                if od and nd then oldP, newP = od .. "/" .. e.fileName,
                                               nd .. "/" .. e.fileName end
            elseif ev == "Renamed+Moved" then
                local od, nd = expandPretty(e.presentLoc), expandPretty(e.movedLoc)
                if od and nd then oldP, newP = od .. "/" .. e.fileName,
                                               nd .. "/" .. e.newName end
            elseif ev == "Moved in" then
                local nd = expandPretty(e.movedLoc)
                if nd then newP = nd .. "/" .. e.fileName end
            elseif ev == "Created" or ev == "Copied" then
                local nd = expandPretty(e.presentLoc)
                if nd then newP = nd .. "/" .. e.fileName end
            elseif ev == "Moved out" then
                local od = expandPretty(e.presentLoc)
                if od then map[od .. "/" .. e.fileName] = nil end
            end
            if newP then
                local rec = (oldP and map[oldP]) or { aliases = {} }
                if oldP then map[oldP] = nil end
                local oldBase = oldP and oldP:match("[^/]+$")
                local newBase = newP:match("[^/]+$")
                if oldBase and oldBase ~= newBase then
                    local dup = false
                    for _, a in ipairs(rec.aliases) do
                        if a == oldBase then dup = true break end
                    end
                    if not dup then rec.aliases[#rec.aliases + 1] = oldBase end
                end
                rec.ts, rec.event, rec.stamp = e.epoch, ev, e.timestamp
                if ev == "Moved" or ev == "Renamed+Moved" then
                    rec.from = e.presentLoc
                end
                map[newP] = rec
            end
        end
        return map, true
    end

    local function storyFor(rec)
        if not rec then return nil end
        local bits = {}
        if #rec.aliases > 0 then
            bits[#bits + 1] = "was " .. table.concat(rec.aliases, ", ")
        end
        if rec.from and rec.from ~= ""
           and (rec.event == "Moved" or rec.event == "Renamed+Moved") then
            bits[#bits + 1] = "from " .. rec.from
        end
        if #bits == 0 then return nil end
        return table.concat(bits, " · ")
               .. (rec.stamp and rec.stamp ~= "" and (" (" .. rec.stamp .. ")") or "")
    end

    -- ---- entries ----------------------------------------------------------
    local function extOf(path)
        local e = path:match("%.(%w+)$")
        return e and e:lower() or nil
    end

    function rd.finish(e)
        e.name = e.path:match("[^/]+$") or e.path
        e.ext  = extOf(e.path)
        e.dir  = prettyDir(e.path:match("^(.*)/[^/]+$") or "")
        local seedTag = e.ext and rd.extTag[e.ext]
        e.tag  = seedTag or e.ext          -- learned types wear their extension
        -- 🎓 THE RULE: seed types count a bare modification as activity;
        -- learned types count only opens and deliberate ⇪F events.
        e.act  = math.max(e.used or 0, seedTag and (e.mod or 0) or 0,
                          e.trackerTs or 0)
        local when
        if e.used then
            when = "opened " .. os.date("%b %d %H:%M", e.used)
        elseif e.trackerTs and not e.mod then
            when = (e.trackerEvent or "tracked") .. " "
                   .. os.date("%b %d %H:%M", e.trackerTs)
        elseif e.mod then
            when = "changed " .. os.date("%b %d %H:%M", e.mod)
        end
        e.sub = (when or "") .. " · " .. e.dir
                .. (e.story and (" · " .. e.story) or "")
        e.hay = (e.name .. " " .. (e.alias or "") .. " " .. e.dir .. " "
                 .. (e.ext or "") .. " @" .. (e.tag or "") .. " "
                 .. os.date("%Y-%m-%d %b %d", e.act > 0 and e.act or epoch())
                ):lower()
        return e
    end

    local function admit(e)
        local x = extOf(e.path)
        if not x then return false end                -- extensionless: not a doc
        if e.path:find("%.app/") or e.path:find("/node_modules/") then
            return false
        end
        local seed = rd.extTag[x] ~= nil
        -- 🎓 learned/unknown types must be OPENED (or deliberately
        -- renamed/moved under ⇪F) — this line is the anti-flood rule.
        if not seed and not e.used and not e.trackerTs then return false end
        return true
    end

    -- ---- the scan ---------------------------------------------------------
    -- One /bin/sh run, everything positional: $1 home, $2 cap, $3 the
    -- opened-files query, $4 the seed-types-modified query. Each hit is
    -- printed as MARK<TAB>path<TAB>lastUsed<TAB>modified — mdls -raw
    -- separates the two attributes with a NUL, tr turns it into the tab.
    local SCRIPT = [[
hm="$1"; cap="$2"; usedq="$3"; modq="$4"
scan() {
  mark="$1"; qq="$2"
  /usr/bin/mdfind -onlyin "$hm" "$qq" 2>/dev/null | head -n "$cap" | \
  while IFS= read -r f; do
    case "$f" in */.*) continue ;; esac
    [ -f "$f" ] || continue
    printf '%s\t%s\t' "$mark" "$f"
    /usr/bin/mdls -name kMDItemLastUsedDate -name kMDItemContentModificationDate \
      -raw -nullMarker '-' "$f" 2>/dev/null | tr '\0' '\t'
    printf '\n'
  done
}
scan U "$usedq"
scan M "$modq"
]]

    function rd.queries()
        local usedq = "kMDItemLastUsedDate >= $time.now(-"
                      .. tostring(rd.days * 86400) .. ")"
        local parts = {}
        for _, g in ipairs(rd.groups) do
            for _, x in ipairs(g.exts) do
                parts[#parts + 1] = 'kMDItemFSName = "*.' .. x .. '"c'
            end
        end
        local modq = "kMDItemContentModificationDate >= $time.now(-"
                     .. tostring(rd.seedDays * 86400) .. ") && ("
                     .. table.concat(parts, " || ") .. ")"
        return usedq, modq
    end

    function rd.parse(out)
        local byPath, list = {}, {}
        for line in tostring(out or ""):gmatch("[^\r\n]+") do
            local mark, path, u, m2 =
                line:match("^([UM])\t([^\t]+)\t([^\t]*)\t?([^\t]*)")
            if mark and path then
                local e = byPath[path]
                if not e then
                    e = { path = path }
                    byPath[path] = e
                    list[#list + 1] = e
                end
                local used, mod = rd.parseDate(u), rd.parseDate(m2)
                if mark == "U" then
                    e.used = used or e.used
                    e.mod  = mod or e.mod
                else
                    e.mod  = mod or e.mod
                    e.used = e.used or used
                end
            end
        end
        return list, byPath
    end

    -- Everything after the subprocess: tracker join, learning, admit,
    -- finish, shelf numbering. Pure enough that the tests call it with
    -- fabricated lists and no hs at all.
    function rd.assemble(list, byPath)
        local map, trackerOn = rd.trackerIndex()
        local now = epoch()
        local windowFrom = now - rd.days * 86400
        -- deliberate ⇪F activity becomes rows of its own, bounded hard:
        -- hand actions only, known types only, file must still exist.
        local checked = 0
        for path, rec in pairs(map) do
            if not byPath[path] and rec.ts and rec.ts >= windowFrom
               and (rec.event == "Renamed" or rec.event == "Moved"
                    or rec.event == "Renamed+Moved" or rec.event == "Moved in")
               and checked < 60 then
                local x = extOf(path)
                if x and (rd.extTag[x] or rd.learned[x]) then
                    checked = checked + 1
                    local exists
                    pcall(function()
                        local a = hs.fs.attributes(path)
                        exists = a and a.mode == "file"
                    end)
                    if exists then
                        local e = { path = path }
                        byPath[path] = e
                        list[#list + 1] = e
                    end
                end
            end
        end
        for _, e in ipairs(list) do
            local rec = map[e.path]
            if rec then
                e.trackerTs = rec.ts
                e.trackerEvent = (rec.event or ""):lower()
                e.alias = (#rec.aliases > 0) and table.concat(rec.aliases, " ")
                          or nil
                e.story = storyFor(rec)
            end
        end
        -- 🎓 learn: every opened extension outside the seeds joins now
        local learnedNew = false
        for _, e in ipairs(list) do
            local x = extOf(e.path)
            if x and e.used and not rd.extTag[x] then
                local l = rd.learned[x]
                if not l then
                    rd.learned[x] = { first = e.used, last = e.used,
                                      example = e.path:match("[^/]+$") }
                    learnedNew = true
                elseif e.used > l.last then
                    l.last = e.used
                    l.example = e.path:match("[^/]+$")
                    learnedNew = true
                end
            end
        end
        local kept = {}
        for _, e in ipairs(list) do
            if admit(e) then kept[#kept + 1] = rd.finish(e) end
        end
        table.sort(kept, function(a, b)
            if a.act ~= b.act then return a.act > b.act end
            return a.path < b.path
        end)
        -- the shelf: first nine by OPENED time, strictly
        local opened = {}
        for _, e in ipairs(kept) do
            e.shelf = nil
            if e.used then opened[#opened + 1] = e end
        end
        table.sort(opened, function(a, b)
            if a.used ~= b.used then return a.used > b.used end
            return a.path < b.path
        end)
        for i = 1, math.min(rd.shelfSize, #opened) do opened[i].shelf = i end
        rd.entries, rd.byPath = kept, byPath
        rd.trackerOn = trackerOn
        if learnedNew then pcall(rd.saveTypes) end
        return kept
    end

    -- ---- the CSV cache: instant boot data, refreshed in the background ----
    function rd.saveCsv()
        local f = io.open(rd.csvFile, "w")
        if not f then warn("could not write " .. rd.csvFile) return end
        f:write("path,used_epoch,mod_epoch\n")
        for _, e in ipairs(rd.entries) do
            f:write(csvField(e.path) .. "," .. tostring(e.used or "") .. ","
                .. tostring(e.mod or "") .. "\n")
        end
        f:close()
    end

    function rd.loadCsv()
        local f = io.open(rd.csvFile, "r")
        if not f then return end
        local list, byPath, first = {}, {}, true
        for line in f:read("*a"):gmatch("[^\r\n]+") do
            if not (first and line:match("^path,")) then
                local c = csvSplit(line)
                if c[1] and c[1] ~= "" and not byPath[c[1]] then
                    local e = { path = c[1], used = tonumber(c[2]),
                                mod = tonumber(c[3]) }
                    byPath[e.path] = e
                    list[#list + 1] = e
                end
            end
            first = false
        end
        f:close()
        rd.assemble(list, byPath)
        rd.loadedAt = 0          -- cache is yesterday's truth: stale by definition
    end

    function rd.refresh(how)
        if rd.running then return false end
        rd.ecoDeferred = false   -- any real scan satisfies a deferred boot scan
        local usedq, modq = rd.queries()
        local ok = pcall(function()
            local t = hs.task.new(rd.sh, function(code, sout, serr)
                rd.running = false
                if code ~= 0 then
                    warn("scan failed (" .. tostring(code) .. "): "
                         .. tostring(serr))
                    if how == "manual" then
                        pcall(function()
                            hs.alert.show("📂 Recent Documents could not scan — "
                                          .. "is Spotlight on? ⇪⇧I retries")
                        end)
                    end
                    return
                end
                local list, byPath = rd.parse(sout)
                rd.assemble(list, byPath)
                rd.loadedAt = epoch()
                pcall(rd.saveCsv)
                say(#rd.entries .. " documents from the scan")
                if how == "manual" then
                    pcall(function()
                        hs.alert.show("📂 " .. #rd.entries .. " recent documents — "
                                      .. "fresh scan done")
                    end)
                end
            end, { "-c", SCRIPT, "hs-recent-docs", home,
                   tostring(rd.cap), usedq, modq })
            rd.task = t             -- HELD: an unreferenced task is GC'd mid-run
            t:start()
        end)
        if not ok then
            warn("hs.task unavailable — Spotlight scan skipped")
            return false
        end
        rd.running = true
        return true
    end

    -- Spotlight off entirely (mdfind exits 0 with nothing): the CSV cache
    -- still serves, and a slow evening walk of ~/Desktop + ~/Documents +
    -- ~/Downloads by mtime is better than an empty panel.
    function rd.fallbackWalk()
        local found = {}
        local cutoff = os.time() - rd.seedDays * 86400
        for _, base in ipairs({ home .. "/Desktop", home .. "/Documents",
                                home .. "/Downloads" }) do
            pcall(function()
                local iter, dirObj = hs.fs.dir(base)
                if not iter then return end
                for name in iter, dirObj do
                    if not name:match("^%.") then
                        local p = base .. "/" .. name
                        local a = hs.fs.attributes(p)
                        if a and a.mode == "file" and a.modification
                           and a.modification >= cutoff then
                            found[#found + 1] = { path = p, mod = a.modification }
                        end
                    end
                end
            end)
        end
        if #found > 0 then
            local byPath = {}
            for _, e in ipairs(found) do byPath[e.path] = e end
            rd.assemble(found, byPath)
            say(#rd.entries .. " documents from the fallback walk")
        end
        return #found
    end

    -- ---- sections (for the page) ------------------------------------------
    function rd.sections()
        local out, counts = {}, {}
        for _, e in ipairs(rd.entries) do
            if not e.shelf then
                counts[e.tag] = (counts[e.tag] or 0) + 1
            end
        end
        for _, g in ipairs(rd.groups) do
            if (counts[g.tag] or 0) > 0 then
                out[#out + 1] = { tag = g.tag, icon = g.icon,
                                  label = g.label, n = counts[g.tag] }
            end
        end
        local learnedOrder = {}
        for ext, l in pairs(rd.learned) do
            if (counts[ext] or 0) > 0 then
                learnedOrder[#learnedOrder + 1] = { ext = ext, last = l.last }
            end
        end
        table.sort(learnedOrder, function(a, b) return a.last > b.last end)
        for _, lo in ipairs(learnedOrder) do
            out[#out + 1] = { tag = lo.ext, icon = "📂",
                              label = "." .. lo.ext .. " (learned)",
                              n = counts[lo.ext] }
        end
        return out
    end

    -- ---- the page ---------------------------------------------------------
    local function jstr(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
             :gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("\t", "\\t")
             :gsub("</", "<\\/")
        s = s:gsub("%c", function(ch)
            return string.format("\\u%04x", ch:byte())
        end)
        return '"' .. s .. '"'
    end

    function rd.rowsJson()
        local parts = {}
        for i, e in ipairs(rd.entries) do
            e.id = i
            local icon = "📄"
            for _, g in ipairs(rd.groups) do
                if g.tag == e.tag then icon = g.icon break end
            end
            if not rd.extTag[e.ext or ""] then icon = "📂" end
            parts[#parts + 1] = "{\"id\":" .. i
                .. ",\"tag\":" .. jstr(e.tag or "")
                .. ",\"icon\":" .. jstr(icon)
                .. ",\"n\":" .. tostring(e.shelf or 0)
                .. ",\"t\":" .. jstr(e.name)
                .. ",\"s\":" .. jstr(e.sub)
                .. ",\"h\":" .. jstr(e.hay)
                .. "}"
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    function rd.sectionsJson()
        local parts = {}
        for _, s in ipairs(rd.sections()) do
            parts[#parts + 1] = "{\"tag\":" .. jstr(s.tag)
                .. ",\"icon\":" .. jstr(s.icon)
                .. ",\"label\":" .. jstr(s.label)
                .. ",\"n\":" .. tostring(s.n) .. "}"
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    function rd.buildHtml()
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""
        return [[<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;height:100%;overflow:hidden}
  body{background:#101018;color:#e9e9f2;
       font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       -webkit-user-select:none;user-select:none}
  #bar{display:flex;justify-content:space-between;align-items:center;
       padding:10px 14px;background:#15151f;cursor:grab}
  #bar.dragging{cursor:grabbing;background:#1b1b26}
  #bar .ttl{font-weight:600;font-size:15px}
  #bar .hint{color:#8a8aa2;font-size:12px}
  #q{display:block;width:calc(100% - 28px);margin:10px 14px 6px;
     padding:12px 14px;font-size:19px;background:#1b1b28;color:#fff;
     border:1px solid #34344a;border-radius:8px;outline:none;
     -webkit-user-select:text;user-select:text}
  #count{padding:0 16px 6px;color:#8a8aa2;font-size:12px;min-height:15px}
  #list{position:absolute;top:124px;bottom:0;left:0;right:0;overflow-y:auto}
  .sec{padding:12px 16px 4px;color:#9db4ff;font-size:13px;font-weight:700;
       letter-spacing:.4px}
  .sec .tag{color:#8a8aa2;font-weight:400}
  .row{display:flex;gap:12px;align-items:center;padding:10px 16px;
       border-bottom:1px solid #1c1c29;cursor:pointer}
  .row.sel{background:#232338;box-shadow:inset 3px 0 0 #7a9bff}
  .num{flex:none;width:26px;height:26px;border-radius:7px;background:#2a2a44;
       color:#b9c8ff;font-size:14px;font-weight:700;display:flex;
       align-items:center;justify-content:center}
  .mid{min-width:0;flex:1}
  .t{font-size:19px;line-height:1.3;max-height:2.6em;overflow:hidden;
     word-break:break-word}
  .s{font-size:14px;color:#9a9ab2;margin-top:3px}
  .story{color:#c9a86a}
  .more{padding:12px 16px;color:#8a8aa2;font-size:13px}
  ]] .. themeCss .. [[
</style></head><body>
<div id="bar"><span class="ttl">📂 Recent Documents</span>
<span class="hint">drag here · ⏎ open · ⌘⏎ reveal · ⌥⏎ path · ⌘1–9 · Esc</span></div>
<input id="q" placeholder="Search recent documents — name, folder, date, extension · a @tag pins one type">
<div id="count"></div>
<div id="list"></div>
<script>
var ROWS = ]] .. rd.rowsJson() .. [[;
var SECS = ]] .. rd.sectionsJson() .. [[;
var CAP = ]] .. tostring(rd.pageCap) .. [[;
var GROUP = ]] .. tostring(rd.groupCap) .. [[;
var SHELF = ]] .. tostring(rd.shelfSize) .. [[;

function say(m){ try { webkit.messageHandlers.recentDocs.postMessage(m); }
                 catch (e) {} }
function el(id){ return document.getElementById(id); }
var q = el('q'), list = el('list'), count = el('count');
var byId = {}, shelfIds = [];
for (var i = 0; i < ROWS.length; i++) {
  byId[ROWS[i].id] = ROWS[i];
  if (ROWS[i].n) shelfIds[ROWS[i].n - 1] = ROWS[i].id;
}

function esc(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;')
    .replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function tokens(s){
  var out = [], parts = String(s || '').toLowerCase().split(/\s+/);
  for (var i = 0; i < parts.length; i++) if (parts[i]) out.push(parts[i]);
  return out;
}
// A word matches as a substring, or — the ⇪Y habit — as a character
// sequence ("bgt" still finds Budget.xlsx).
function seqRe(w){
  var p = '';
  for (var i = 0; i < w.length; i++)
    p += w[i].replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + (i < w.length - 1 ? '[^]*?' : '');
  try { return new RegExp(p); } catch (e) { return null; }
}
function matches(row, toks){
  for (var i = 0; i < toks.length; i++){
    if (row.h.indexOf(toks[i]) === -1){
      var re = seqRe(toks[i]);
      if (!re || !re.test(row.h)) return false;
    }
  }
  return true;
}

var visible = [], sel = 0, total = 0;

function rowHtml(row, visIndex){
  var cls = 'row' + (visIndex === sel ? ' sel' : '');
  var h = '<div class="' + cls + '" data-id="' + row.id + '">';
  if (row.n) h += '<div class="num">' + row.n + '</div>';
  var s = esc(row.s).replace(/ · (was [^·]*)/, ' · <span class="story">$1</span>');
  h += '<div class="mid"><div class="t">' + esc(row.t) + '</div>' +
       '<div class="s">' + row.icon + ' ' + s + '</div></div>';
  return h + '</div>';
}

function rebuild(){
  var toks = tokens(q.value);
  visible = []; total = 0;
  var html = '';
  if (!toks.length) {
    var anyShelf = false;
    for (var i = 0; i < ROWS.length; i++) if (ROWS[i].n) anyShelf = true;
    if (anyShelf) {
      html += '<div class="sec">① Recently opened — ⌘1…⌘' + SHELF +
              ' opens directly</div>';
      for (var n = 1; n <= SHELF; n++) {
        var id = shelfIds[n - 1];
        if (id == null) continue;
        html += rowHtml(byId[id], visible.length);
        visible.push(id);
      }
    }
    for (var s = 0; s < SECS.length; s++) {
      if (!SECS[s].n) continue;
      html += '<div class="sec">' + SECS[s].icon + ' ' + esc(SECS[s].label) +
              ' — ' + SECS[s].n + ' <span class="tag">@' + esc(SECS[s].tag) +
              '</span></div>';
      var shown = 0;
      for (var j = 0; j < ROWS.length && shown < GROUP; j++) {
        if (ROWS[j].tag !== SECS[s].tag || ROWS[j].n) continue;
        html += rowHtml(ROWS[j], visible.length);
        visible.push(ROWS[j].id);
        shown++;
      }
      total += SECS[s].n;
    }
    if (!ROWS.length)
      html += '<div class="more">Nothing yet — the first Spotlight scan is ' +
              'still running, or Spotlight is off (⇪⇧I re-scans)</div>';
  } else {
    for (var k = 0; k < ROWS.length; k++) {
      if (!matches(ROWS[k], toks)) continue;
      total++;
      if (visible.length < CAP) {
        html += rowHtml(ROWS[k], visible.length);
        visible.push(ROWS[k].id);
      }
    }
    if (total > visible.length)
      html += '<div class="more">…and ' + (total - visible.length) +
              ' more — keep typing to narrow</div>';
    if (!total)
      html += '<div class="more">Nothing matches "' + esc(q.value) +
              '" — old names count too, if ⇪F saw the rename</div>';
  }
  list.innerHTML = html;
  count.textContent = toks.length
    ? (total + ' match' + (total === 1 ? '' : 'es'))
    : (ROWS.length + ' documents — the nine newest opened, then every type you use');
}

function render(){ rebuild(); var n = document.querySelector('.row.sel');
                   if (n && n.scrollIntoView) n.scrollIntoView({block:'nearest'}); }
function move(d){
  if (!visible.length) return;
  sel = Math.max(0, Math.min(visible.length - 1, sel + d));
  render();
}
function act(id, ev){
  if (id == null) return;
  var a = (ev && ev.metaKey) ? 'reveal' : ((ev && ev.altKey) ? 'path' : 'open');
  say({ a: a, id: id });
}

q.addEventListener('input', function(){ sel = 0; rebuild(); });
window.addEventListener('keydown', function(ev){
  if (ev.metaKey && ev.key >= '1' && ev.key <= '9') {
    var id = shelfIds[Number(ev.key) - 1];
    if (id != null) { if (ev.preventDefault) ev.preventDefault();
                      say({ a: 'open', id: id }); }
  }
  else if (ev.key === 'ArrowDown') { if (ev.preventDefault) ev.preventDefault(); move(1); }
  else if (ev.key === 'ArrowUp') { if (ev.preventDefault) ev.preventDefault(); move(-1); }
  else if (ev.key === 'Enter') {
    if (ev.preventDefault) ev.preventDefault();
    act(visible[sel], ev);
  }
  else if (ev.key === 'Escape') { say({ a: 'close' }); }
});
list.addEventListener('click', function(ev){
  var n = ev.target;
  while (n && n !== list && !(n.getAttribute && n.getAttribute('data-id')))
    n = n.parentNode;
  if (n && n !== list && n.getAttribute)
    act(parseInt(n.getAttribute('data-id'), 10), ev);
});
var bar = el('bar');
bar.addEventListener('mousedown', function(ev){
  if (ev.preventDefault) ev.preventDefault();
  bar.classList.add('dragging');
  say({ a: 'dragStart' });
});
window.addEventListener('mouseup', function(){
  bar.classList.remove('dragging');
});
rebuild();
if (q.focus) q.focus();
</script></body></html>]]
    end

    -- ---- the Lua side of the bridge ---------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        local a = body.a
        if a == "close" then rd.hide() return end
        if a == "dragStart" then
            if _G.beginPanelDrag then _G.beginPanelDrag("recent documents")
            else print("📂 Recent Documents: window_move is off — the header cannot drag") end
            return
        end
        local e = rd.entries and rd.entries[tonumber(body.id or 0)]
        if not (e and e.path) then return end
        if a == "open" then
            local opened
            pcall(function() opened = hs.open(e.path) end)
            if opened == false then
                pcall(function()
                    hs.alert.show("⚠️ Could not open " .. e.name
                                  .. " — moved or deleted?")
                end)
            end
            rd.hide()
        elseif a == "reveal" then
            pcall(function()
                local t = hs.task.new(rd.openBin, nil, { "-R", e.path })
                rd.revealTask = t
                t:start()
            end)
            rd.hide()
        elseif a == "path" then
            pcall(function() hs.pasteboard.setContents(e.path) end)
            pcall(function() hs.alert.show("📋 Path copied — " .. e.name) end)
            rd.hide()
        end
    end

    -- ---- show / hide ------------------------------------------------------
    function rd.hide()
        if rd.webview then
            pcall(function() rd.webview:delete() end)
            rd.webview = nil
        end
        rd.uc = nil
    end

    local function posStillOnScreen(pos)
        local onIt = false
        pcall(function()
            for _, s in ipairs(hs.screen.allScreens() or {}) do
                local f = s:frame()
                if pos.x >= f.x - 40 and pos.x < f.x + f.w - 60
                   and pos.y >= f.y and pos.y < f.y + f.h - 60 then
                    onIt = true
                end
            end
        end)
        return onIt
    end

    function rd.show()
        rd.hide()
        if rd.loadedAt == 0 or (epoch() - rd.loadedAt) > rd.staleSecs then
            rd.refresh()          -- panel shows the cache NOW, scan lands later
        end
        local scr
        pcall(function() scr = hs.screen.mainScreen() end)
        local sf = scr and scr:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(rd.width,  sf.w - 60)
        local h = math.min(rd.height, sf.h - 80)
        local rect = { x = sf.x + (sf.w - w) / 2,
                       y = sf.y + (sf.h - h) / 2.6, w = w, h = h }
        -- 🖐 A REMEMBERED POSITION WINS — unless its screen was unplugged,
        -- in which case opening off-screen would be worse than forgetting.
        if rd.pos and posStillOnScreen(rd.pos) then
            rect.x, rect.y = rd.pos.x, rd.pos.y
        end
        local okUc, uc = pcall(hs.webview.usercontent.new, "recentDocs")
        if not (okUc and uc) then
            pcall(function()
                hs.alert.show("📂 Recent Documents could not open its window")
            end)
            return false
        end
        rd.uc = uc                -- HELD: collect this and the bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then
                    print("📂 Recent Documents: message handler — " .. tostring(err))
                end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            rd.uc = nil
            pcall(function()
                hs.alert.show("📂 Recent Documents could not open its window")
            end)
            return false
        end
        rd.webview = view
        pcall(function() view:windowTitle("Recent Documents") end)
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        if _G.capturePad and _G.capturePad.applyNonActivating then
            pcall(_G.capturePad.applyNonActivating, view)
        end
        pcall(function() view:html(rd.buildHtml()) end)
        pcall(function() view:show() end)
        pcall(function() view:bringToFront(true) end)
        say(#rd.entries .. " rows shown")
        return true
    end

    function rd.toggle()
        if rd.webview then rd.hide() else rd.show() end
    end

    -- ---- wiring -----------------------------------------------------------
    if rd.enabled then
        core.hyperAddShortcut({}, rd.key, function() rd.toggle() end,
                              "recent documents")
        core.hyperAddShortcut({ "shift" }, rd.key, function()
            if rd.refresh("manual") then
                pcall(function() hs.alert.show("📂 Re-scanning now…") end)
            end
        end, "recent documents — re-scan")
    end

    -- Draggable like everything else — and move() is also where the
    -- remembered position is written down, so BOTH grips remember.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "recent documents",
        frame = function() return rd.webview and rd.webview:frame() end,
        move  = function(x, y)
            local f = rd.webview and rd.webview:frame()
            if f then rd.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
            rd.pos = { x = x, y = y }
        end,
    })

    -- ⎋ 6.93.0 — IN THE ROUTER FROM BIRTH: the cheat sheet closes last,
    -- and this panel is one of the things it closes after.
    if _G.claimEscape then
        _G.claimEscape("recentdocs", nil,
            function() return rd.webview ~= nil end,
            function() rd.hide() end)
    end

    -- warm: read back yesterday's CSV so the first ⇪I is instant, then
    -- start a real scan in the background.
    -- 🔋 6.144.0 — UNLESS THE MAC IS ON BATTERY. The Spotlight sweep is
    -- the single most expensive periodic thing this config does, and at
    -- boot its only job is freshening a cache that already serves. On
    -- battery the boot scan waits: the CSV answers ⇪I exactly as it does
    -- in the first seconds of every boot, opening the panel still scans
    -- when the cache is stale (that is you asking, not the background),
    -- ⇪⇧I still forces one, and the deferred scan runs by itself the
    -- moment the cord is back — unless a user-initiated scan already
    -- satisfied it (rd.refresh clears the deferral flag).
    rd.ecoHold, rd.ecoDeferred = false, false
    M.warm = function()
        pcall(rd.loadTypes)
        pcall(rd.loadCsv)
        if rd.ecoHold then
            rd.ecoDeferred = true
            return
        end
        if not rd.refresh() then pcall(rd.fallbackWalk) end
    end

    if _G.eco then
        _G.eco.register("recent docs boot scan", {
            hold = function(on)
                rd.ecoHold = on and true or false
                if not on and rd.ecoDeferred then
                    rd.ecoDeferred = false
                    if not rd.refresh() then pcall(rd.fallbackWalk) end
                end
            end,
        })
    end

    function _G.recentDocsReport()
        local lines = {
            "📂 Recent Documents",
            "   entries : " .. #rd.entries
                .. (rd.loadedAt > 0
                    and ("  (scanned " .. os.date("%H:%M", rd.loadedAt) .. ")")
                    or "  (cache only — no scan finished yet)"),
            "   tracker : " .. (rd.trackerOn
                and "⇪F log joined — old names are searchable"
                or "not running — old-name search unavailable"),
            "   cache   : " .. rd.csvFile,
        }
        local learned = {}
        for ext, l in pairs(rd.learned) do
            learned[#learned + 1] = { ext = ext, l = l }
        end
        table.sort(learned, function(a, b) return a.l.last > b.l.last end)
        if #learned == 0 then
            lines[#lines + 1] = "   learned : none yet — open any file type and it joins"
        else
            lines[#lines + 1] = "   learned : (unlearn with _G.recentDocs.unlearn(\"ext\"))"
            for _, o in ipairs(learned) do
                lines[#lines + 1] = "     ." .. o.ext .. "  since "
                    .. os.date("%b %d", o.l.first) .. " — e.g. " .. (o.l.example or "")
            end
        end
        local out = table.concat(lines, "\n")
        print(out)
        return out
    end

    _G.recentDocs = rd
    M.rd     = rd
    M.config = rd
end

return M
