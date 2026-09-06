-- =====================================================================
-- MODULE: OPEN DOCUMENTS — remembers what Word, Excel, PowerPoint (and
--         friends) have open, so a forced quit can be undone (6.169.0)
-- =====================================================================
-- LL, from the Gemini thread: "My apps often close out on my work Mac
-- because IT requires those apps to be updated the minute a new release
-- comes … I would like to add to my app monitor a relaunch capability"
-- — with the documents that were open coming back too.
--
-- The App Monitor (app_watcher) already relaunches a quit app (🚀 Spawn).
-- What nothing in this config knew was WHICH DOCUMENTS the app had open
-- when IT pulled it down. This module keeps that memory, and the quit
-- panel reads it: "📂 Spawn with 3 documents", one "📄 Reopen X" row per
-- document. Nothing else changes in app_watcher.
--
-- ---- HOW IT KNOWS -----------------------------------------------------
-- Every document window on macOS carries AXDocument — the file URL of
-- what it shows. A SAMPLE is: the front app's window list (AXWindows),
-- then AXDocument for each, at most dm.maxWindows of them. Every read is
-- an hs.axuielement read WITH A TIMEOUT (dm.axTimeout) — the 6.160.2
-- rule: never hs.window, never an untimed AX read, never work inside an
-- AX callback. A sample runs on a HELD timer, dm.settle seconds after an
-- app in dm.apps comes to the front (hs.application.watcher), and again
-- every dm.every seconds while such an app is in front. That is the whole
-- cost: a handful of timed reads a minute, only for the apps listed.
--
-- The result replaces that app's list whole (the window list is the
-- truth). Two files in the Logs folder:
--   · open_documents-<Mac>.json — the current memory, so a reload (or a
--     Hammerspoon update) does not forget what Word had open.
--   · open_documents-<Mac>.csv  — one row per change, appended:
--       timestamp,app,event,path,epoch   (event: opened | closed | quit)
--     The master log (6.169.0) reads this; ⇪space could too.
--
-- When the app QUITS, its last list is kept as dm.lastOpen[app] (with
-- the time) — that is what the quit panel offers. Reopen = `open -a
-- <App> <doc>` in an hs.task, which brings the app up with the document,
-- exactly as a double-click in Finder would.
--
-- ---- WHAT IT NEVER DOES -----------------------------------------------
--   · Never polls an app that is not in front, never polls one not in
--     dm.apps, never reads more than dm.maxWindows windows.
--   · A slow sample (over dm.slowMs) twice within dm.slowWindow seconds
--     RESTS it for dm.slowRest seconds (the mouse_follows watchdog, same
--     shape) — a slow Word costs a stutter, never a hang.
--   · No Accessibility: it stands down and says so in the report.
--   · Never opens a document by itself — only from the quit panel, or
--     _G.docMemoryReopen("Microsoft Word").
-- =====================================================================

local M = {
    name  = "Open Documents",
    order = 7.8,
    family = "files",
    cheatsheet = {
        title = "📄 OPEN DOCUMENTS (app quit → get them back)",
        entries = {
            { "what",   "Remembers which documents Word / Excel / PowerPoint / Preview … have open" },
            { "quit",   "The App Monitor's quit panel offers 📂 Spawn with N documents + 📄 Reopen rows" },
            { "how",    "Timed Accessibility reads, only for the front app, only apps in dm.apps" },
            { "files",  "open_documents-<Mac>.json (memory) + .csv (opened/closed/quit, for the master log)" },
            { "check",  "_G.docMemoryReport() — what each app has open, the last sample, any rest" },
        },
    },
}

local function num(v, default)
    local n = tonumber(v)
    if n and n >= 0 then return n end
    return default
end

function M.setup(core)
    local dm = {}
    local function say(m)  if _G.diag then _G.diag.say("docmemory", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("docmemory", m) end end

    local host = core.hostTag or "Mac"
    local logs = core.logsDir or "."

    -- ✏️ EDIT HERE ---------------------------------------------------------
    dm.enabled    = true
    -- The apps whose documents are remembered — by the name macOS gives.
    dm.apps = {
        ["Microsoft Word"] = true, ["Microsoft Excel"] = true, ["Microsoft PowerPoint"] = true,
        ["Preview"] = true, ["TextEdit"] = true, ["Pages"] = true, ["Numbers"] = true,
        ["Keynote"] = true, ["Acrobat"] = true, ["Adobe Acrobat"] = true,
    }
    dm.settle     = 0.5       -- seconds after an app comes to the front
    dm.every      = 60        -- re-sample the front app this often
    dm.maxWindows = 8         -- windows read per sample, at most
    dm.axTimeout  = 0.15      -- seconds one Accessibility question may take
    dm.slowMs     = 250       -- a sample slower than this is a strike
    dm.slowStrikes = 2
    dm.slowWindow = 60
    dm.slowRest   = 300
    dm.keepQuit   = 7 * 86400 -- seconds a quit app's list is worth offering
    dm.jsonFile   = logs .. "/open_documents-" .. host .. ".json"
    dm.csvFile    = logs .. "/open_documents-" .. host .. ".csv"
    -- ----------------------------------------------------------------------

    dm.HEADER    = "timestamp,app,event,path,epoch"
    dm.open      = {}     -- app → { [path] = { title, seen } }
    dm.lastOpen  = {}     -- app → { at = epoch, docs = { {path,title}, … } } after a quit
    dm.samples   = 0
    dm.lastMs    = nil
    dm.last      = nil    -- { app, n, when, ms }
    dm.strikes   = {}
    dm.restUntil = nil
    dm.stoodDown = nil
    dm.appWatcher = nil   -- HELD
    dm.sampleTimer = nil  -- HELD: the settle hand-off
    dm.everyTimer  = nil  -- HELD: the periodic sample
    dm.restTimer   = nil  -- HELD
    dm.openTasks   = {}   -- HELD: `open` tasks, trimmed
    dm.frontApp    = nil  -- name of the app in front, when it is one of ours

    local function axOK()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    local function nowMs()
        local t
        pcall(function() t = hs.timer.absoluteTime() / 1e6 end)
        return t
    end

    local function appName(app)
        local n
        if app then pcall(function() n = app:name() end) end
        return n
    end

    local function withTimeout(el)
        pcall(function() el:setTimeout(num(dm.axTimeout, 0.15)) end)
        return el
    end

    -- file:///Users/lee/My%20Doc.docx → /Users/lee/My Doc.docx
    function dm.pathFromUrl(url)
        local s = tostring(url or "")
        if s == "" then return nil end
        s = s:gsub("^file://localhost", ""):gsub("^file://", "")
        s = s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        if s:sub(1, 1) ~= "/" then return nil end
        return s
    end

    local function q(v)
        if core.csvQuote then return core.csvQuote(v) end
        return '"' .. tostring(v or ""):gsub('"', '""') .. '"'
    end

    -- ---- the files --------------------------------------------------------
    function dm.appendEvent(app, event, path)
        local ok, err = pcall(function()
            local f = io.open(dm.csvFile, "a")
            if not f then error("cannot open " .. dm.csvFile) end
            local ok2, size = pcall(function() return f:seek("end") end)
            if ok2 and size == 0 then f:write(dm.HEADER, "\n") end
            local now = os.time()
            f:write(os.date("%Y-%m-%d %H:%M:%S", now), ",", q(app), ",", event, ",", q(path), ",",
                    tostring(now), "\n")
            f:close()
        end)
        if not ok then warn("csv: " .. tostring(err)) end
        return ok
    end

    function dm.save()
        local ok, err = pcall(function()
            local body = hs.json.encode({ open = dm.open, lastOpen = dm.lastOpen }, true)
            local f = io.open(dm.jsonFile, "w")
            if not f then error("cannot write " .. dm.jsonFile) end
            f:write(body); f:close()
        end)
        if not ok then warn("save: " .. tostring(err)) end
        return ok
    end

    function dm.load()
        local ok, err = pcall(function()
            local f = io.open(dm.jsonFile, "r")
            if not f then return end
            local body = f:read("a"); f:close()
            local okD, data = pcall(hs.json.decode, body)
            if not okD then error("unreadable memory file") end
            if type(data) ~= "table" then return end
            if type(data.open) == "table" then dm.open = data.open end
            if type(data.lastOpen) == "table" then dm.lastOpen = data.lastOpen end
        end)
        if not ok then warn("load: " .. tostring(err)) end
        return ok
    end

    -- ---- one sample -------------------------------------------------------
    -- Reads the front app's document windows. Returns { [path] = {title} }
    -- or nil, why. Every AX read is timed; a window without AXDocument is
    -- simply not a document window (a dialog, a palette).
    function dm.read(app)
        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then return nil, "no AX element" end
        withTimeout(axApp)
        local wins
        pcall(function() wins = axApp:attributeValue("AXWindows") end)
        if type(wins) ~= "table" then return nil, "no window list (slow or silent app)" end
        local docs, n = {}, 0
        for i, w in ipairs(wins) do
            if i > num(dm.maxWindows, 8) then break end
            withTimeout(w)
            local url, title
            pcall(function() url = w:attributeValue("AXDocument") end)
            local path = dm.pathFromUrl(url)
            if path then
                pcall(function() title = w:attributeValue("AXTitle") end)
                docs[path] = { title = tostring(title or path:match("[^/]+$") or path) }
                n = n + 1
            end
        end
        return docs, n
    end

    function dm.diff(app, docs)
        local before = dm.open[app] or {}
        local changed = false
        for path in pairs(docs) do
            if not before[path] then dm.appendEvent(app, "opened", path); changed = true end
        end
        for path in pairs(before) do
            if not docs[path] then dm.appendEvent(app, "closed", path); changed = true end
        end
        local now = os.time()
        for path, d in pairs(docs) do d.seen = now end
        dm.open[app] = docs
        if changed then dm.save() end
        return changed
    end

    -- The watchdog — the mouse_follows shape: strikes expire, a rest ends.
    function dm.strike()
        local now, keep = os.time(), {}
        for _, at in ipairs(dm.strikes) do
            if now - at <= num(dm.slowWindow, 60) then keep[#keep + 1] = at end
        end
        keep[#keep + 1] = now
        dm.strikes = keep
        warn(string.format("a sample took %dms (strike %d of %d)", math.floor(dm.lastMs or 0),
                           #keep, num(dm.slowStrikes, 2)))
        if #keep >= num(dm.slowStrikes, 2) then dm.rest() end
    end

    function dm.rest()
        dm.strikes = {}
        dm.restUntil = os.time() + num(dm.slowRest, 300)
        dm.stoodDown = string.format("slow samples — resting until %s", os.date("%H:%M:%S", dm.restUntil))
        warn(dm.stoodDown)
        if _G.notices then _G.notices.record("docMemory", "resting", dm.stoodDown) end
        if dm.restTimer then pcall(function() dm.restTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, num(dm.slowRest, 300), function()
            dm.restTimer = nil
            dm.restUntil, dm.stoodDown = nil, nil
            say("rested — sampling again")
        end)
        dm.restTimer = (ok and t) or nil
    end

    function dm.sample(why)
        if not dm.enabled then return false, "off" end
        if dm.restUntil then
            if os.time() < dm.restUntil then return false, "resting" end
            dm.restUntil, dm.stoodDown = nil, nil
        end
        if not axOK() then return false, "no Accessibility" end
        local app
        pcall(function() app = hs.application.frontmostApplication() end)
        local name = appName(app)
        if not (name and dm.apps[name]) then return false, "front app not watched" end
        local t0 = nowMs()
        local docs, n = dm.read(app)
        local t1 = nowMs()
        if t0 and t1 then
            dm.lastMs = t1 - t0
            if dm.lastMs > num(dm.slowMs, 250) then dm.strike() end
        end
        if not docs then
            dm.last = { app = name, n = 0, when = os.date("%H:%M:%S"), ms = dm.lastMs, why = tostring(n) }
            return false, n
        end
        dm.samples = dm.samples + 1
        dm.last = { app = name, n = n, when = os.date("%H:%M:%S"), ms = dm.lastMs, why = why }
        dm.diff(name, docs)
        return true, n
    end

    -- ---- hand-offs: never work in a watcher callback -----------------------
    function dm.scheduleSample(why)
        if dm.sampleTimer then return true end
        local ok, t = pcall(hs.timer.doAfter, num(dm.settle, 0.5), function()
            dm.sampleTimer = nil
            local okS, err = pcall(dm.sample, why)
            if not okS then warn("sample: " .. tostring(err)) end
        end)
        if ok and t then dm.sampleTimer = t; return true end
        return false
    end

    function dm.onQuit(name)
        local docs = dm.open[name]
        if not docs then return false end
        local list = {}
        for path, d in pairs(docs) do list[#list + 1] = { path = path, title = d.title or path } end
        table.sort(list, function(a, b) return a.path < b.path end)
        dm.open[name] = nil
        if #list > 0 then
            dm.lastOpen[name] = { at = os.time(), docs = list }
            for _, d in ipairs(list) do dm.appendEvent(name, "quit", d.path) end
            say(string.format("%s quit with %d document%s open — remembered", name, #list, #list == 1 and "" or "s"))
        end
        dm.save()
        return #list > 0
    end

    -- ---- what the quit panel asks ------------------------------------------
    -- docs.openFor(app) → { {path, title}, … } — what it had open when it
    -- quit (or has open now), newest memory first; {} when nothing.
    function dm.openFor(name)
        local now = os.time()
        local cur = dm.open[name]
        if cur and next(cur) then
            local list = {}
            for path, d in pairs(cur) do list[#list + 1] = { path = path, title = d.title or path } end
            table.sort(list, function(a, b) return a.path < b.path end)
            return list
        end
        local last = dm.lastOpen[name]
        if last and type(last.docs) == "table" and (now - (tonumber(last.at) or 0)) <= num(dm.keepQuit, 7 * 86400) then
            return last.docs
        end
        return {}
    end

    -- docs.reopen(app, paths | nil) → opens the app with those documents
    -- (all remembered ones when paths is nil). `open -a App doc…`.
    function dm.reopen(name, paths)
        if not paths then
            paths = {}
            for _, d in ipairs(dm.openFor(name)) do paths[#paths + 1] = d.path end
        elseif type(paths) == "string" then
            paths = { paths }
        end
        if #paths == 0 then return false, "nothing remembered for " .. tostring(name) end
        local bundle = _G.findAppBundle and _G.findAppBundle(name)
        local args = { "-a", bundle or name }
        for _, p in ipairs(paths) do args[#args + 1] = p end
        local ok, task = pcall(hs.task.new, "/usr/bin/open", function(code, _, serr)
            if code ~= 0 then warn("open exited " .. tostring(code) .. ": " .. tostring(serr)) end
        end, args)
        if not (ok and task) then return false, "hs.task: " .. tostring(task) end
        local started = false
        pcall(function() started = task:start() end)
        if not started then return false, "open would not start" end
        dm.openTasks[#dm.openTasks + 1] = task
        while #dm.openTasks > 8 do table.remove(dm.openTasks, 1) end
        say(string.format("reopening %d document%s in %s", #paths, #paths == 1 and "" or "s", name))
        return true, #paths
    end

    -- ---- report -----------------------------------------------------------
    function _G.docMemoryReport()
        local L = { "📄 OPEN DOCUMENTS" }
        L[#L + 1] = "   accessibility : " .. (axOK() and "granted" or "OFF — no window can be read")
        L[#L + 1] = "   state         : " .. (not dm.enabled and "off (dm.enabled = false)"
                                              or dm.restUntil and dm.stoodDown
                                              or dm.appWatcher and "watching" or "not started")
        local names = {}
        for n in pairs(dm.apps) do names[#names + 1] = n end
        table.sort(names)
        L[#L + 1] = "   apps          : " .. table.concat(names, ", ")
        L[#L + 1] = string.format("   sampling      : %.1fs after an app comes up, every %ds in front · %d windows max · %dms per read",
                                  num(dm.settle, 0.5), num(dm.every, 60), num(dm.maxWindows, 8),
                                  math.floor(num(dm.axTimeout, 0.15) * 1000 + 0.5))
        if dm.last then
            L[#L + 1] = string.format("   last sample   : %s · %s · %d document%s · %s", dm.last.when, dm.last.app,
                                      dm.last.n, dm.last.n == 1 and "" or "s",
                                      dm.last.ms and string.format("%dms", math.floor(dm.last.ms)) or "?")
                        .. (dm.last.why and (" · " .. tostring(dm.last.why)) or "")
        else
            L[#L + 1] = "   last sample   : none yet"
        end
        local any = false
        for app, docs in pairs(dm.open) do
            local n = 0
            for _ in pairs(docs) do n = n + 1 end
            if n > 0 then
                any = true
                L[#L + 1] = string.format("   open now      : %s — %d", app, n)
                for path in pairs(docs) do L[#L + 1] = "      " .. path end
            end
        end
        if not any then L[#L + 1] = "   open now      : nothing remembered" end
        for app, last in pairs(dm.lastOpen) do
            L[#L + 1] = string.format("   quit          : %s at %s with %d — the quit panel offers them",
                                      app, os.date("%H:%M:%S", tonumber(last.at) or 0),
                                      type(last.docs) == "table" and #last.docs or 0)
        end
        L[#L + 1] = "   files         : " .. dm.jsonFile .. " · " .. dm.csvFile
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    function _G.docMemorySample() return dm.sample("_G.docMemorySample()") end
    function _G.docMemoryReopen(name, paths) return dm.reopen(name, paths) end

    core.provide("docs.openFor", function(name) return dm.openFor(name) end)
    core.provide("docs.reopen",  function(name, paths) return dm.reopen(name, paths) end)
    core.provide("docs.quit",    function(name) return dm.onQuit(name) end)
    core.provide("docs.sample",  function(why) return dm.sample(why or "service") end)
    core.provide("docs.report",  function() return _G.docMemoryReport() end)
    _G.docMemory = dm
    M.dm = dm
    M.config = dm

    if not dm.enabled then return end
    dm.load()

    if not axOK() then
        if _G.notices then
            _G.notices.record("docMemory", "Accessibility off", "open documents cannot be read")
        end
        warn("Accessibility is off — nothing sampled (the memory on disk still serves the quit panel)")
        return
    end

    local okW, w = pcall(hs.application.watcher.new, function(name, eventType, app)
        -- NO work here: note and hand off
        if eventType == hs.application.watcher.activated then
            local n = name or appName(app)
            if n and dm.apps[n] then dm.frontApp = n; dm.scheduleSample("activated")
            else dm.frontApp = nil end
        elseif eventType == hs.application.watcher.terminated then
            local n = name or appName(app)
            if n and dm.apps[n] then
                if dm.frontApp == n then dm.frontApp = nil end
                pcall(dm.onQuit, n)
            end
        end
    end)
    if okW and w then
        dm.appWatcher = w
        pcall(function() w:start() end)
    else
        warn("hs.application.watcher failed — documents will not be sampled")
        return
    end

    local okE, et = pcall(hs.timer.doEvery, num(dm.every, 60), function()
        if dm.frontApp then dm.scheduleSample("periodic") end
    end)
    if okE and et then dm.everyTimer = et end

    -- whatever is in front at boot
    pcall(function()
        local n = appName(hs.application.frontmostApplication())
        if n and dm.apps[n] then dm.frontApp = n; dm.scheduleSample("boot") end
    end)
end

return M
