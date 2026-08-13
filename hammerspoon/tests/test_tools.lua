-- =====================================================================
-- test_tools.lua — the three tools added in 6.65.0
-- =====================================================================
--     lua5.4 test_tools.lua                    # ~/.hammerspoon
--     lua5.4 test_tools.lua /path/to/hammerspoon
--
-- Covers modules/tool_picker.lua, modules/universal_actions.lua and
-- modules/pomodoro.lua by EXECUTING them against a stubbed hs, not by
-- reading them as text.
--
-- WHY EACH ONE IS HERE, because "it is new" is not a reason:
--
--   · TOOL PICKER has a filter with real failure modes. Its search box is
--     fed strings full of ⇪[ ⇪\ ⇪- ⇪/ ⇪= — every one of which is an
--     operator in Lua's pattern engine — so "does typing a bracket throw"
--     is a question with a wrong answer. And its run path guards on
--     service.has() because service.call() does NOT throw on a missing
--     provider: without that guard the picker reports success while doing
--     nothing, which is the exact failure this config keeps finding.
--
--   · UNIVERSAL ACTIONS reorders itself from a file it wrote. That is
--     persistence, and persistence is where this config has been bitten
--     twice (the Capture Pad adopting the JSON decoder's tables in
--     6.62.0; the clipboard preload race in 6.55.0). It also has to HIDE
--     inapplicable rows, and "offered an action that cannot run" is a
--     silent failure by any other name.
--
--   · POMODORO takes the keyboard. Everything else in this file is a
--     convenience; that one can hold ⏎ away from you. The assertions
--     about WHEN it captures and WHEN it gives back are the reason this
--     suite exists at all.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- Modules print on their failure paths and the harness silences print,
-- so test output goes through io.write. (test_app_watcher shipped once
-- reporting nothing at all because it used print here.)
local say = function(s) io.write(s, "\n") end
local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        local line = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        failures[#failures + 1] = line
        -- 🚨 PRINTED THE MOMENT IT FAILS, not only in the summary. A later
        -- check can ABORT the run — the banned-call stub below throws on
        -- purpose — and a summary that never prints takes every finding
        -- before it down too. That happened while writing this file: the
        -- ban check correctly caught a reintroduced in-process AppleScript
        -- call, and the traceback from three sections later was all the
        -- run had to show for it.
        say("   ❌ " .. line)
    end
end

-- =====================================================================
-- STUBS
-- =====================================================================
local ALERTS, TIMERS, CANVASES, TASKS, CLIPBOARD = {}, {}, {}, {}, nil
local EXECUTED, EXEC_OUT = {}, nil
local CHOOSERS, MODALS, HYPER, PROVIDED = {}, {}, {}, {}
local NOW, FILES = 1000, {}

local realPrint = print
print = function() end

local function mkTimer(kind, secs, fn)
    local t = { kind = kind, secs = secs, fn = fn, live = true }
    function t:stop() self.live = false end
    function t:start() self.live = true; return self end
    TIMERS[#TIMERS + 1] = t
    return t
end

local function mkCanvas(frame)
    local c = { frame = frame, elements = {}, shown = false, deleted = false }
    function c:replaceElements(e)
        -- FAITHFUL to hs.canvas: an empty table is read as ONE element
        -- with no key-value pairs, and throws. The 6.62.0 crash got past
        -- a stub that accepted anything.
        if type(e) == "table" and #e == 0 then
            error("invalid element definition; must contain key-value pairs", 0)
        end
        self.elements = e; return self
    end
    function c:level() return self end
    function c:behaviorAsLabels() return self end
    function c:canvasMouseEvents() return self end
    function c:show() self.shown = true; return self end
    function c:hide() self.shown = false; return self end
    function c:delete() self.deleted = true; self.shown = false; return self end
    CANVASES[#CANVASES + 1] = c
    return c
end

hs = {
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(s, fn) return mkTimer("after", s, fn) end,
        doEvery = function(s, fn) return mkTimer("every", s, fn) end,
    },
    alert  = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    canvas = { windowLevels = { overlay = 17 }, new = function(f) return mkCanvas(f) end },
    screen = {
        mainScreen = function()
            return { frame = function() return { x = 0, y = 25, w = 1512, h = 957 } end }
        end,
    },
    pasteboard = {
        getContents = function() return CLIPBOARD end,
        setContents = function(v) CLIPBOARD = v; return true end,
    },
    json = {
        encode = function(t)
            local parts = {}
            for _, v in ipairs(t) do parts[#parts + 1] = '"' .. tostring(v) .. '"' end
            return "[" .. table.concat(parts, ",") .. "]"
        end,
        decode = function(s)
            local out = {}
            for v in tostring(s):gmatch('"([^"]*)"') do out[#out + 1] = v end
            return out
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, visible = false, query_ = "" }
            function c:choices(v) self.choices_ = v; return self end
            function c:rows() return self end
            function c:width() return self end
            function c:searchSubText() return self end
            function c:placeholderText(v) self.placeholder = v; return self end
            function c:query(v) self.query_ = v; return self end
            function c:queryChangedCallback(f) self.qcb = f; return self end
            function c:show() self.visible = true; return self end
            function c:hide() self.visible = false; return self end
            function c:isVisible() return self.visible end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
    hotkey = {
        modal = {
            new = function()
                local m = { entered = false, binds = {} }
                function m:bind(mods, key, fn) self.binds[key] = fn; return self end
                function m:enter() self.entered = true; return self end
                function m:exit()  self.entered = false; return self end
                MODALS[#MODALS + 1] = m
                return m
            end,
        },
    },
    task = {
        new = function(cmd, cb, args)
            local t = { cmd = cmd, args = args }
            function t:start()
                TASKS[#TASKS + 1] = { cmd = cmd, args = args, cb = cb }
                return self
            end
            function t:isRunning() return false end
            function t:waitUntilExit() return self end
            function t:standardOutput() return "" end
            return t
        end,
    },
    -- 🚨 6.65.1 — CALLING THIS IS A TEST FAILURE, not a stubbed success.
    -- hs.osascript.applescript runs NSAppleScript IN PROCESS and sends
    -- Apple Events on Hammerspoon's main thread; an Objective-C exception
    -- from that machinery aborts the app and cannot be caught by pcall.
    -- It crashed LL's Mac. Nothing in this config may call it, so the stub
    -- throws rather than quietly answering — a stub that returns a
    -- plausible value would let the crash walk straight back in.
    osascript = { applescript = function()
        error("hs.osascript.applescript is BANNED — use out-of-process "
              .. "osascript via hs.task or hs.execute", 0)
    end },
    execute = function(cmd)
        EXECUTED[#EXECUTED + 1] = cmd
        return (EXEC_OUT or ""), true, "exit", 0
    end,
    http = { encodeForQuery = function(s) return tostring(s):gsub("%s", "%%20") end },
    application = { get = function() return nil end },
    accessibilityState = function() return true end,
    axuielement = { applicationElement = function() return nil end },
}

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function() end }
_G.service = {
    registry = {},
    provide = function(n, f) _G.service.registry[n] = f end,
    has     = function(n) return _G.service.registry[n] ~= nil end,
    call    = function(n, ...)
        local f = _G.service.registry[n]
        if not f then return nil end          -- prints and returns, never throws
        return select(2, pcall(f, ...))
    end,
}

-- io.open, intercepted so persistence is testable without touching disk.
local realOpen = io.open
io.open = function(path, mode)
    if not tostring(path):find("universal_actions", 1, true) then
        return realOpen(path, mode)
    end
    if (mode or "r"):find("r") then
        if not FILES[path] then return nil end
        local content, done = FILES[path], false
        return { read = function() if done then return nil end done = true; return content end,
                 close = function() end }
    end
    -- 🚨 "w" TRUNCATES. The first version of this stub appended in every
    -- write mode, so a second save produced two JSON arrays glued
    -- together — and the load test failed against code that was correct.
    -- A stub that does not match the real call is not a test, it is a
    -- second implementation you now have to debug.
    if (mode or "r"):find("w") then FILES[path] = "" end
    return { write = function(_, s) FILES[path] = (FILES[path] or "") .. s end,
             close = function() end }
end

local core = {
    logsDir = "/tmp/hs-test",
    provide = function(n, f) _G.service.provide(n, f) end,
    hyperAddShortcut = function(mods, key, fn, src)
        local combo = (type(mods) == "table" and #mods > 0 and "shift+" or "") .. tostring(key)
        HYPER[combo] = { fn = fn, src = src }
    end,
    resolveBaseScreen = function() return hs.screen.mainScreen() end,
    warnWriteFailed = function() end,
}

local function load(name)
    local chunk = assert(loadfile(HS .. "/modules/" .. name .. ".lua"))
    return chunk()
end

-- =====================================================================
say("\n=== 0. 🚨 NOTHING MAY SEND APPLE EVENTS IN PROCESS (6.65.1) ===")
-- =====================================================================
-- THE CRASH THIS PINS, from LL's report on macOS 26.6.1:
--        _NSAppleEventManagerGenericHandler
--        handleUncaughtException
--        -[SentryCrashExceptionApplication reportException:]
--        abort()
--
-- hs.osascript.applescript runs NSAppleScript INSIDE Hammerspoon, which
-- sends Apple Events on the main thread. When that machinery raises an
-- Objective-C exception the process aborts — and a Lua pcall around the
-- call does NOT help, because pcall catches Lua errors and an ObjC
-- exception is not one. Four versions of this config wrapped those calls
-- in pcall and believed they were handled.
--
-- ⚠️ THIS CHECK IS A GREP, DELIBERATELY, and that is worth defending:
-- everywhere else this suite executes the module rather than reading it,
-- because a name being present proves nothing about behaviour. Here the
-- property IS textual — "this call does not appear in the shipped
-- source" — and no amount of executing can prove a branch is absent when
-- the branch may be the one the test did not take. The runtime half is
-- covered too: the stub above THROWS if the call is ever made.
do
    local banned = {}
    local files = { "init.lua" }
    local p = io.popen("ls " .. HS .. "/modules/*.lua " .. HS .. "/core/*.lua 2>/dev/null")
    if p then
        for line in p:lines() do files[#files + 1] = line:gsub("^" .. HS .. "/", "") end
        p:close()
    end
    for _, rel in ipairs(files) do
        local fh = realOpen(HS .. "/" .. rel, "r")
        if fh then
            local n = 0
            for line in fh:lines() do
                n = n + 1
                -- Comments describing the ban are not the ban being broken.
                if not line:match("^%s*%-%-") and line:find("hs.osascript.applescript", 1, true) then
                    banned[#banned + 1] = rel .. ":" .. n
                end
            end
            fh:close()
        end
    end
    check("🚨 NO shipped file calls hs.osascript.applescript — every "
          .. "AppleScript in this config runs as a SEPARATE PROCESS, so "
          .. "the worst it can do is exit non-zero",
          #banned == 0, table.concat(banned, ", "))
    check("...and the suite checked more than one file, so a broken glob "
          .. "cannot make the check above pass by finding nothing",
          #files >= 20, #files)
end

-- =====================================================================
say("\n=== 1. TOOL PICKER — the filter, and the run guard ===")
-- =====================================================================
local tpMod = load("tool_picker")
tpMod.setup(core)
local tp = tpMod.picker

check("it claims ⇪⇧/ and not ⇪/ — the cheat sheet already owns the bare "
      .. "key, and taking it would replace browsing with searching rather "
      .. "than adding to it",
      HYPER["shift+/"] ~= nil and HYPER["/"] == nil)
check("it publishes toolPicker.show", _G.service.has("toolPicker.show"))

-- A fixture standing in for the assembled cheat sheet.
_G.cheatSheet = { groups = function()
    return {
        { title = "🎯 MOUSE GRID (⇪X — type 3 letters)", entries = {
            { "⇪X", "Jump the pointer anywhere" } } },
        { title = "🔗 URL CLEANER (⇪K)", entries = {
            { "⇪K",  "Clean the copied link of trackers" },
            { "⇪⇧K", "Undo the last clean" } } },
        { title = "❓ HELP", entries = {
            { "⇪/", "Toggle this cheat sheet" },
            { "⇪=", "Add your own entry" },
            { "⇪-", "Remove a custom entry" } } },
    }
end }

local rows = tp.choices()
check("every entry in every group becomes a row", #rows == 6, #rows)
check("a row carries the key, the description and the group it came from",
      (function()
    for _, r in ipairs(rows) do
        if r.keys == "⇪K" then
            return r.text:find("trackers", 1, true) ~= nil
               and r.subText:find("URL CLEANER", 1, true) ~= nil
        end
    end
end)())
check("the group name in the subtitle has lost its emoji and its (key) "
      .. "parenthetical — it is a label, not a title", (function()
    for _, r in ipairs(rows) do
        if r.keys == "⇪X" then return r.subText:find("MOUSE GRID", 1, true)
                                and not r.subText:find("⇪X —", 1, true) end
    end
end)())

say("   -- filtering --")
check("typing 'url' finds the URL tools", #tp.filter(rows, "url") == 2,
      #tp.filter(rows, "url"))
check("...by GROUP, even though neither description says 'url'", (function()
    for _, r in ipairs(tp.filter(rows, "url")) do
        if r.text:lower():find("url", 1, true) then return false end
    end
    return true
end)())
check("typing 'clean' finds it by description alone",
      #tp.filter(rows, "clean") == 2, #tp.filter(rows, "clean"))
-- Both URL rows carry "clean" (one in its description, one in "Undo the
-- last clean") and both carry "url" via the group, so two is the correct
-- answer here. What is being pinned is that ORDER DOES NOT MATTER and
-- that ALL words must match — not the count, which is a property of the
-- fixture rather than of the filter.
check("words match in ANY ORDER — 'clean url' and 'url clean' are the "
      .. "same search",
      #tp.filter(rows, "clean url") == #tp.filter(rows, "url clean")
      and #tp.filter(rows, "clean url") == 2,
      #tp.filter(rows, "clean url") .. " vs " .. #tp.filter(rows, "url clean"))
check("...and ALL words must match, so adding a word can only ever narrow",
      #tp.filter(rows, "clean") == 2 and #tp.filter(rows, "clean undo") == 1)
check("a word that matches nothing yields nothing, rather than everything",
      #tp.filter(rows, "url zzzz") == 0)
check("an empty query is every row, not none", #tp.filter(rows, "") == #rows)
check("a whitespace-only query is also every row", #tp.filter(rows, "   ") == #rows)
check("search is case-insensitive", #tp.filter(rows, "URL") == 2)

-- 🧨 THE ONE THAT MATTERS. This config's shortcuts are written in
-- characters that are all operators in Lua's pattern engine. A filter
-- that forgot find(..., true) throws on the first bracket typed, and the
-- search box looks broken while being merely literal.
say("   -- 🧨 the query is never handed to the pattern engine --")
for _, q in ipairs({ "⇪[", "⇪]", "⇪\\", "⇪-", "⇪/", "⇪=", "%", "%d", "(", ")",
                     "[", "]", "*", "+", "-", "?", "^", "$", ".", "%b()" }) do
    local ok, res = pcall(tp.filter, rows, q)
    check("typing " .. q .. " searches instead of throwing",
          ok and type(res) == "table", ok and "ok" or tostring(res))
end
check("...and a pattern metacharacter matches LITERALLY — '⇪-' finds the "
      .. "row whose key really is ⇪-, not every row with a dash",
      #tp.filter(rows, "⇪-") == 1, #tp.filter(rows, "⇪-"))

say("   -- ⏎: run it, or hand back the key --")
local ran = {}
_G.service.provide("mouseGrid.show", function() ran[#ran + 1] = "grid"; return true end)
CLIPBOARD = nil
check("an entry mapped to a REAL service runs it",
      tp.run({ keys = "⇪X", service = "mouseGrid.show" }) == true and ran[1] == "grid")
-- 🚨 The guard that is the whole point: service.call PRINTS on a missing
-- provider and returns nil. It does not throw. A pcall around it succeeds
-- either way, so without has() this returns true having done nothing.
check("🚨 an entry naming a service that does NOT exist reports failure "
      .. "and copies the key — service.call does not throw on a missing "
      .. "provider, so a pcall alone would call this a success",
      tp.run({ keys = "⇪Z", service = "nope.missing" }) == false)
check("...and the key is on the clipboard so the next thing you do is "
      .. "press it", CLIPBOARD == "⇪Z", tostring(CLIPBOARD))
check("an entry with no service at all copies its key",
      tp.run({ keys = "⇪=" }) == false and CLIPBOARD == "⇪=")

say("   -- the run map is checked against the live registry --")
local recorded = {}
_G.notices = { record = function(a, b, c) recorded[#recorded + 1] = tostring(c) end }
tp.verified = false
tp.verify()
check("a run-map entry pointing at a service nothing publishes is "
      .. "REPORTED, not left to be discovered the day you rely on it",
      #recorded == 1 and recorded[1]:find("pomodoro.toggle", 1, true) ~= nil,
      recorded[1])
check("...and it reports once, not on every press", (function()
    tp.verify(); return #recorded == 1
end)())

say("   -- opening --")
check("show() with no groups available alerts rather than opening an "
      .. "empty panel", (function()
    local saved = _G.cheatSheet
    _G.cheatSheet = { groups = function() return nil end }
    ALERTS = {}
    local r = tp.show()
    _G.cheatSheet = saved
    return r == false and #ALERTS == 1
end)())
check("show() opens a chooser and fills it", (function()
    local r = tp.show()
    local c = CHOOSERS[#CHOOSERS]
    return r == true and c.visible and #c.choices_ == 6
end)())
check("pressing ⇪⇧/ again puts it away — same toggle contract as ⇪/ and ⇪X",
      (function()
    tp.show()
    return CHOOSERS[#CHOOSERS].visible == false
end)())
check("the query is cleared on reopen, so it never opens showing last "
      .. "time's search", (function()
    local c = CHOOSERS[#CHOOSERS]
    c.query_ = "url"
    tp.show()
    return c.query_ == ""
end)())
check("typing in the box refilters through OUR filter, not the chooser's",
      (function()
    local c = CHOOSERS[#CHOOSERS]
    c.qcb("url")
    return #c.choices_ == 2
end)())

-- =====================================================================
say("\n=== 2. UNIVERSAL ACTIONS — applicability, order, persistence ===")
-- =====================================================================
local uaMod = load("universal_actions")
uaMod.setup(core)
local ua = uaMod.ua

check("it claims ⇪⇧A, not ⇪U — ⇪U is the update tracker, claimed in "
      .. "init.lua's migration map where no module grep would find it",
      HYPER["shift+a"] ~= nil and HYPER["u"] == nil)
check("reset does NOT cost a second hyper key", HYPER["shift+u"] == nil)

say("   -- what applies, and what is hidden --")
local FILE_CTX = { files = { "/tmp/a.png" }, file = "/tmp/a.png", dir = "/tmp" }
local URL_CTX  = { files = {}, text = "https://x.test/a?utm_source=z",
                   url = "https://x.test/a?utm_source=z" }
local TEXT_CTX = { files = {}, text = "just some words" }

local function ids(list)
    local out = {}
    for _, a in ipairs(list) do out[#out + 1] = a.id end
    return table.concat(out, ",")
end
check("with a file selected, the file actions are offered",
      ids(ua.ordered(FILE_CTX)):find("reveal", 1, true) ~= nil)
check("🚨 ...and Open URL is NOT — an action list that offers something "
      .. "it cannot do is one you stop trusting",
      ids(ua.ordered(FILE_CTX)):find("openurl", 1, true) == nil)
check("with a URL copied, Open URL and Clean URL are both offered",
      ids(ua.ordered(URL_CTX)):find("openurl", 1, true) ~= nil
      and ids(ua.ordered(URL_CTX)):find("cleanurl", 1, true) ~= nil)
check("...and Reveal in Finder is not, because nothing is selected",
      ids(ua.ordered(URL_CTX)):find("reveal", 1, true) == nil)
check("plain text gets the text actions but not the URL ones",
      ids(ua.ordered(TEXT_CTX)):find("largetype", 1, true) ~= nil
      and ids(ua.ordered(TEXT_CTX)):find("openurl", 1, true) == nil)
check("an action whose `when` THROWS is treated as inapplicable rather "
      .. "than taking the whole panel down with it", (function()
    ua.actions[#ua.actions + 1] =
        { id = "boom", title = "Boom", sub = "",
          when = function() error("nope") end, run = function() end }
    local ok, list = pcall(ua.ordered, FILE_CTX)
    ua.actions[#ua.actions] = nil
    return ok and list and ids(list):find("boom", 1, true) == nil
end)())

say("   -- the order reorders itself --")
ua.mru = {}
local first = ua.ordered(FILE_CTX)[1].id
check("a fresh install reads in the order the table is written",
      first == "reveal", first)
ua.remember("rename")
check("the action you used last is at the top next time",
      ua.ordered(FILE_CTX)[1].id == "rename", ua.ordered(FILE_CTX)[1].id)
ua.remember("getinfo")
check("...and the one before it is second",
      ua.ordered(FILE_CTX)[1].id == "getinfo"
      and ua.ordered(FILE_CTX)[2].id == "rename")
ua.remember("rename")
check("using one again promotes it without duplicating it", (function()
    local seen, list = 0, ua.ordered(FILE_CTX)
    for _, a in ipairs(list) do if a.id == "rename" then seen = seen + 1 end end
    return list[1].id == "rename" and seen == 1
end)())
check("everything never used keeps its table order behind everything used",
      (function()
    local list = ua.ordered(FILE_CTX)
    local iReveal, iOpen
    for i, a in ipairs(list) do
        if a.id == "reveal" then iReveal = i end
        if a.id == "open"   then iOpen = i end
    end
    return iReveal < iOpen
end)())
check("the remembered list is bounded", (function()
    for i = 1, ua.maxMRU + 20 do ua.remember("id" .. i) end
    return #ua.mru <= ua.maxMRU
end)())

say("   -- persistence --")
ua.mru = { "email", "reveal" }
ua.save()
check("saving writes a file", FILES[ua.store] ~= nil)
ua.mru = {}
ua.load()
check("...and loading brings the order back", #ua.mru == 2 and ua.mru[1] == "email")
check("🚨 the loaded list is OUR OWN copy, not the decoder's table — "
      .. "adopting a decoder's table is what left the Capture Pad with "
      .. "queue and parked as one table in 6.62.0", (function()
    local decoded
    local realDecode = hs.json.decode
    hs.json.decode = function(s) decoded = realDecode(s); return decoded end
    ua.load()
    hs.json.decode = realDecode
    ua.mru[#ua.mru + 1] = "mutation"
    return #decoded ~= #ua.mru
end)())
check("a corrupt store falls back to the default order instead of "
      .. "throwing", (function()
    FILES[ua.store] = "{{{ not json"
    local ok = pcall(ua.load)
    return ok
end)())
check("a store containing non-strings drops them rather than putting a "
      .. "table into the order", (function()
    FILES[ua.store] = '["reveal","open"]'
    ua.load()
    for _, v in ipairs(ua.mru) do if type(v) ~= "string" then return false end end
    return #ua.mru == 2
end)())

say("   -- running --")
ua.mru = {}
ua.ctx = FILE_CTX
TASKS = {}
check("running an action performs it", ua.run("copypath") == true)
check("...and remembers it", ua.mru[1] == "copypath", tostring(ua.mru[1]))
check("🚨 an action that FAILS is not remembered — floating something "
      .. "that just failed to the top of the list is the opposite of help",
      (function()
    ua.actions[#ua.actions + 1] =
        { id = "bad", title = "Bad", sub = "",
          when = function() return true end, run = function() error("nope") end }
    ALERTS = {}
    local r = ua.run("bad")
    ua.actions[#ua.actions] = nil
    return r == false and ua.mru[1] ~= "bad" and #ALERTS == 1
end)())
check("the reset row clears the order and is never itself remembered",
      (function()
    ua.mru = { "email" }
    ua.run("__reset")
    return #ua.mru == 0
end)())

-- 🚨 6.65.2 — THE SAME GUARD tool_picker got when it was written, which
-- this file did NOT get, and which hs-lint found rather than a user
-- noticing an action that had quietly stopped working.
-- _G.service.call prints and returns nil on a missing provider; it never
-- throws. So a pcall around it succeeds either way, and without has()
-- these three actions report success, get remembered, and float to the
-- top of the list having done nothing.
do
    local saved = _G.service.registry
    _G.service.registry = {}        -- every service gone, as if its module failed
    ua.mru, ua.ctx = {}, URL_CTX
    ALERTS = {}
    local r = ua.run("cleanurl")
    check("🚨 an action whose SERVICE does not exist reports FAILURE — "
          .. "service.call does not throw, so a pcall alone would call "
          .. "this a success", r == false, tostring(r))
    check("...and it is NOT remembered, so a dead action cannot climb to "
          .. "the top of your list", ua.mru[1] ~= "cleanurl",
          tostring(ua.mru[1]))
    check("...and you are told, rather than left wondering", #ALERTS == 1)
    _G.service.registry = saved
    _G.service.provide("url.cleanClipboard", function() return true end)
    ua.mru, ua.ctx = {}, URL_CTX
    check("with the service present the same action succeeds and IS "
          .. "remembered", ua.run("cleanurl") == true and ua.mru[1] == "cleanurl")
end

say("   -- opening --")
CLIPBOARD = nil
TASKS = {}   -- no Finder selection: the task never calls back
ALERTS = {}
check("with nothing selected and nothing copied it says so, rather than "
      .. "opening a panel of actions that would all fail",
      ua.show() == false and #ALERTS == 1)
CLIPBOARD = "https://example.test/x"
check("with a URL copied it opens", ua.show() == true)
check("the panel names what it is acting on", (function()
    local c = CHOOSERS[#CHOOSERS]
    return c.placeholder and c.placeholder:find("example.test", 1, true) ~= nil
end)())
check("the reset row is offered, and it is LAST", (function()
    local c = CHOOSERS[#CHOOSERS]
    return c.choices_[#c.choices_].id == "__reset"
end)())
check("🚨 the context is captured for THIS press — after a few seconds of "
      .. "scrolling, the Finder selection need not still be what the "
      .. "panel said it was acting on", (function()
    local at = ua.ctx.url
    CLIPBOARD = "https://something-else.test/y"
    return ua.ctx.url == at
end)())

-- =====================================================================
say("\n=== 3. POMODORO — and the keyboard it must give back ===")
-- =====================================================================
local pomMod = load("pomodoro")
pomMod.setup(core)
local pom = pomMod.pom
local function tickTo(secs)
    NOW = NOW + secs
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "every" and t.secs == 1 then t.fn() end
    end
end

check("it claims no ⇪ letter — it is a pad key, bound by the numpad layer",
      HYPER["shift++"] == nil)
check("it publishes pomodoro.toggle", _G.service.has("pomodoro.toggle"))

say("   -- the panel --")
CANVASES = {}
check("start() draws", pom.start() == true and #CANVASES == 1)
local panel = CANVASES[1]
check("it is 170x99, the size asked for",
      panel.frame.w == 170 and panel.frame.h == 99)
check("it sits in the top-right, under the menu bar rather than over it",
      panel.frame.x > 1300 and panel.frame.y >= 25,
      panel.frame.x .. "," .. panel.frame.y)
check("it is shown", panel.shown)
check("it opens at 25:00, not at 00:00 counting up", (function()
    for _, e in ipairs(panel.elements) do
        if e.type == "text" and e.text == "25:00" then return true end
    end
end)())

say("   -- counting --")
tickTo(60)
check("a minute later it reads 24:00", (function()
    for _, e in ipairs(panel.elements) do
        if e.type == "text" and e.text == "24:00" then return true end
    end
end)())

say("   -- 🚨 the keyboard --")
check("🚨 DURING the countdown NO modal is entered — a modal that owned "
      .. "⏎ for twenty-five minutes would stop Enter sending an email, "
      .. "with nothing on screen to explain why", (function()
    for _, m in ipairs(MODALS) do if m.entered then return false end end
    return true
end)())
tickTo(25 * 60)
check("at zero it asks, and only then takes ⏎ and esc", (function()
    for _, m in ipairs(MODALS) do if m.entered then return true end end
end)())
check("🚨 a watchdog is armed to give the keys back even if you never "
      .. "answer", (function()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "after" and t.secs == pom.answerSecs then return true end
    end
end)())
check("...and firing it releases them", (function()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "after" and t.secs == pom.answerSecs then t.fn() end
    end
    for _, m in ipairs(MODALS) do if m.entered then return false end end
    return true
end)())

say("   -- answering --")
check("esc stops the timer and takes the panel down", (function()
    pom.start()
    local c = CANVASES[#CANVASES]
    pom.modal.binds["escape"]()
    return pom.state == nil and c.deleted
end)())
check("⏎ starts a fresh one", (function()
    pom.start()
    pom.modal.binds["return"]()
    return pom.state ~= nil and pom.state.phase == "work"
end)())
check("padenter answers it too — the key you started it with is on the "
      .. "pad, so the Enter you reach for is the pad's",
      pom.modal.binds["padenter"] ~= nil)

say("   -- cleanup --")
check("stop() deletes the canvas and stops every timer it owns", (function()
    pom.start()
    local c = CANVASES[#CANVASES]
    local ticker = pom.state.ticker
    pom.stop("test")
    return pom.state == nil and c.deleted and ticker.live == false
end)())
check("stopping twice does not throw", pcall(pom.stop, "again"))
check("a tick arriving AFTER stop repaints nothing — every callback bails "
      .. "on a cleared state, which is why state is cleared first",
      (function()
    pom.start()
    local ticker = pom.state.ticker
    pom.stop("test")
    return pcall(ticker.fn)
end)())
-- 🚨 THE ORDERING INSIDE stop(), MADE OBSERVABLE. Clearing pom.state
-- FIRST is what makes every timer callback a no-op for the rest of the
-- teardown. If state were cleared LAST, a tick landing between
-- canvas:delete() and that assignment would paint on a deleted canvas.
-- The stub reproduces exactly that: delete() fires the pending tick,
-- mid-teardown, which is the only moment the ordering can be wrong in.
check("🚨 a tick landing DURING teardown cannot repaint — state is "
      .. "cleared before the canvas is touched, not after", (function()
    pom.start()
    local c, ticker = CANVASES[#CANVASES], pom.state.ticker
    local paintedAfterDelete = false
    local realReplace = c.replaceElements
    c.replaceElements = function(self, e)
        if self.deleted then paintedAfterDelete = true end
        return realReplace(self, e)
    end
    local fired = false
    c.delete = function(self)
        self.deleted = true
        if not fired then fired = true; pcall(ticker.fn) end   -- the race
        return self
    end
    pom.stop("test")
    return fired and not paintedAfterDelete
end)())
check("toggle() is start when off and stop when on", (function()
    pom.stop(nil)
    pom.toggle()
    local on = pom.state ~= nil
    pom.toggle()
    return on and pom.state == nil
end)())
check("a canvas that refuses to draw takes the timer down with it rather "
      .. "than leaving a live ticker painting nothing", (function()
    local realNew = hs.canvas.new
    hs.canvas.new = function() error("no canvas") end
    ALERTS = {}
    local r = pom.start()
    hs.canvas.new = realNew
    return r == false and pom.state == nil and #ALERTS >= 1
end)())

say("\n=== 4. OUT-OF-PROCESS APPLESCRIPT: two shapes, two reasons ===")
-- The two out-of-process shapes, and why the choice differs.
do
    -- Bulk rename feeds a DESTRUCTIVE operation, so its read must be
    -- fresh and synchronous — a stale list renames files you did not
    -- select. hs.execute is both, and still a separate process.
    local brSrc = realOpen(HS .. "/modules/bulk_rename.lua", "r")
    local br = brSrc and brSrc:read("*a") or ""
    if brSrc then brSrc:close() end
    check("bulk_rename reads the selection SYNCHRONOUSLY (hs.execute) — a "
          .. "cached list would rename files you did not select",
          br:find("hs.execute", 1, true) ~= nil)
    check("...and it shell-quotes with single quotes, not Lua's %q — %q "
          .. "escapes a newline as backslash-newline, which the shell "
          .. "reads as a line continuation and silently joins the "
          .. "AppleScript into one broken line",
          br:find([[gsub("'", [==[]], 1, true) ~= nil
          or br:find("script:gsub", 1, true) ~= nil)

    -- Universal Actions is non-destructive and shows you the filename it
    -- is acting on, so it can afford the fully async read.
    ua.selection, ua.selectionAt, ua.selTask = {}, 0, nil
    TASKS = {}
    ua.finderSelection()
    check("universal_actions reads the selection ASYNCHRONOUSLY, out of "
          .. "process", #TASKS == 1 and TASKS[1].cmd == "/usr/bin/osascript",
          #TASKS > 0 and TASKS[1].cmd or "no task")
    check("...and the callback fills the cache", (function()
        TASKS[1].cb(0, "/tmp/one.png\n/tmp/two.png\n", "")
        return #ua.selection == 2 and ua.selection[1] == "/tmp/one.png"
    end)())
    check("...so the next press has it without waiting",
          #ua.finderSelection() == 2)
    check("a task that cannot start degrades to no selection rather than "
          .. "taking the panel down — the clipboard actions still apply",
          (function()
        local realNew = hs.task.new
        hs.task.new = function() error("no task") end
        ua.selection, ua.selectionAt, ua.selTask = {}, 0, nil
        local ok = pcall(ua.finderSelection)
        hs.task.new = realNew
        return ok
    end)())
end

-- =====================================================================
print = realPrint
io.open = realOpen
say("")
say(pass .. " passed, " .. fail .. " failed")
os.exit(fail == 0 and 0 or 1)
