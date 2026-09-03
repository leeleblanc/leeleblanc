-- =====================================================================
-- test_tools.lua — the three tools added in 6.65.0
-- =====================================================================
--     lua5.4 test_tools.lua                    # ~/.hammerspoon
--     lua5.4 test_tools.lua /path/to/hammerspoon
--
-- Covers modules/universal_actions.lua and
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
-- 🚨 CAPTURED, NOT DISCARDED (6.70.0). A module that reports a problem
-- through print() is making a promise this suite could not check while
-- the stub threw everything away — and "it says so" is half of rule 7.
PRINTED = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

local function mkTimer(kind, secs, fn)
    local t = { kind = kind, secs = secs, fn = fn, live = true }
    function t:stop() self.live = false end
    function t:start() self.live = true; return self end
    TIMERS[#TIMERS + 1] = t
    return t
end

local function mkCanvas(frame)
    -- 6.152.0 — the frame doubles as a METHOD: real hs.canvas answers
    -- :frame() with its rect, and the pomodoro's hover poll calls it.
    -- A callable table keeps every older `panel.frame.w` check working.
    frame = setmetatable(frame, { __call = function(self) return self end })
    local c = { frame = frame, elements = {}, shown = false, deleted = false }
    function c:alpha(a) if a ~= nil then self.alpha_ = a end return self.alpha_ or 1 end
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

MOUSE = { x = 0, y = 0 }   -- the pomodoro hover poll reads this
hs = {
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(s, fn) return mkTimer("after", s, fn) end,
        doEvery = function(s, fn) return mkTimer("every", s, fn) end,
        doAt = function(t, rep, fn)
            local tm = mkTimer("at", t, fn) ; tm.rep = rep ; return tm
        end,
    },
    mouse = { absolutePosition = function() return MOUSE end },
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

-- 🖐 6.67.0 — the drag helpers live in init.lua and reach panels as
-- globals. Stubbed here so the WIRING is testable: does the pomodoro
-- register for dragging, and does it reopen where you dropped it.
local DRAGGABLE = {}
_G.makeCanvasDraggable = function(canvas, label, onDrop)
    DRAGGABLE[#DRAGGABLE + 1] = { canvas = canvas, label = label, onDrop = onDrop }
    return true
end
_G.clampToScreen = function(pt, w, h)
    return { x = math.max(0, math.min(pt.x, 1512 - (w or 0))),
             y = math.max(0, math.min(pt.y, 982 - (h or 0))) }
end
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
-- 1. TOOL PICKER — RETIRED IN 6.104.0
-- =====================================================================
-- modules/tool_picker.lua is gone: ⇪⇧/ now opens Unified Search on the
-- "@tool " tag, and the tools are one source in the one search box.
-- Its coverage moved WITH it — tests/test_unified.lua §2b drives the same
-- contract against the surviving code: every cheat sheet entry becomes a
-- row, the run map is checked against both tables it joins, ⏎ runs a real
-- service and copies the key when it cannot. The Lua-pattern hazard those
-- tests guarded (⇪[ ⇪\\ ⇪- typed into a filter) cannot arise there at all:
-- that panel filters in JavaScript with indexOf, which is literal by
-- construction rather than by remembering a fourth argument.
say("\n=== 1. TOOL PICKER — retired, see test_unified.lua §2b ===")

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
check("📏 6.152.0 — 20% bigger, from one knob: 170×132 × pom.scale",
      panel.frame.w == math.floor(170 * pom.scale + 0.5)
      and panel.frame.h == math.floor(132 * pom.scale + 0.5)
      and pom.scale >= 1.2,
      panel.frame.w .. "x" .. panel.frame.h)
check("...and the type scales WITH the card — big box, big clock",
      (function()
    for _, e in ipairs(panel.elements) do
        if e.type == "text" and e.text == "25:00" then
            return e.textSize == math.floor(40 * pom.scale + 0.5), e.textSize
        end
    end
end)())
check("it sits in the top-right, under the menu bar rather than over it",
      panel.frame.x + panel.frame.w > 1490 and panel.frame.y >= 25,
      panel.frame.x .. "," .. panel.frame.y)
check("it is shown", panel.shown)
check("it opens at 25:00, not at 00:00 counting up", (function()
    for _, e in ipairs(panel.elements) do
        if e.type == "text" and e.text == "25:00" then return true end
    end
end)())

say("   -- 🕰 6.94.0: the wall clock and the workday, under the countdown --")
-- LL: "below the countdown clock, can we also display the regular time
-- and date and how many hours are left in the day if I'm working from
-- 7:30 to 4:30 ... I don't take lunch."
do
    local function findText(pat)
        for _, e in ipairs(panel.elements) do
            if e.type == "text" and tostring(e.text):match(pat) then return e end
        end
    end
    local clockEl = findText("^%d+:%d%d [AP]M · ")
    check("the panel carries a time · date line under the countdown",
          clockEl ~= nil)
    check("...positioned BELOW the big clock, not over it",
          clockEl ~= nil and clockEl.frame.y > 80, clockEl and clockEl.frame.y)
    check("...and a workday line", findText("workday") ~= nil
          or findText("no workday") ~= nil)

    -- The formats, driven with KNOWN local epochs rather than NOW: the
    -- workday is a local-clock fact, so the fixtures are built with
    -- os.time{} which is also local.
    local wed  = { year = 2026, month = 8, day = 12 }   -- a Wednesday
    local function at(h, m, s)
        return os.time({ year = wed.year, month = wed.month, day = wed.day,
                         hour = h, min = m, sec = s or 0 })
    end
    check("midday Wednesday: 4h 30m of the 7:30–4:30 day left — nine hours "
          .. "total, NO lunch subtracted, exactly as specified",
          pom.workLine(at(12, 0)) == "workday: 4h 30m left",
          pom.workLine(at(12, 0)))
    check("one minute in: 8h 59m", pom.workLine(at(7, 31)) == "workday: 8h 59m left",
          pom.workLine(at(7, 31)))
    check("under an hour left drops the hours part",
          pom.workLine(at(16, 0)) == "workday: 30m left", pom.workLine(at(16, 0)))
    check("🚨 4:29:30 says 1m left — the minutes CEIL, so the line can "
          .. "never read '0m left' while the day is not done",
          pom.workLine(at(16, 29, 30)) == "workday: 1m left",
          pom.workLine(at(16, 29, 30)))
    check("4:30 exactly: done", pom.workLine(at(16, 30)) == "workday: done ✅",
          pom.workLine(at(16, 30)))
    check("before 7:30 it says when the day STARTS — a constant '9h 00m' "
          .. "reads like a stuck countdown",
          pom.workLine(at(6, 45)) == "workday starts 7:30",
          pom.workLine(at(6, 45)))
    local sat = os.time({ year = 2026, month = 8, day = 15, hour = 12, min = 0 })
    check("Saturday is not a workday", pom.workLine(sat) == "no workday today",
          pom.workLine(sat))
    check("...unless weekendsOff is turned off", (function()
        pom.weekendsOff = false
        local line = pom.workLine(sat)
        pom.weekendsOff = true
        return line == "workday: 4h 30m left", line
    end)())
    check("✏️ the hours are EDITABLE, not baked in — workdayEnd '17:00' "
          .. "moves the countdown", (function()
        pom.workdayEnd = "17:00"
        local line = pom.workLine(at(12, 0))
        pom.workdayEnd = "16:30"
        return line == "workday: 5h 00m left", line
    end)())
    check("clockLine reads 12-hour with AM/PM and the date",
          pom.clockLine(at(14, 5)) == "2:05 PM · Wed Aug 12",
          pom.clockLine(at(14, 5)))
    check("...midnight is 12 AM, noon is 12 PM — the %12 edge",
          pom.clockLine(at(0, 10)):match("^12:10 AM") ~= nil
          and pom.clockLine(at(12, 10)):match("^12:10 PM") ~= nil)
    check("🚨 a FRACTIONAL epoch does not throw — secondsSinceEpoch "
          .. "returns floats on a real Mac, and os.date refuses them; the "
          .. "6.70.0 lesson is that a throw here is swallowed by paint() "
          .. "and the panel just quietly stops",
          pcall(pom.clockLine, at(9, 0) + 0.73)
          and pcall(pom.workLine, at(9, 0) + 0.73))
    check("a mis-edited workdayEnd falls back instead of breaking the "
          .. "panel", (function()
        pom.workdayEnd = "garbage"
        local line = pom.workLine(at(12, 0))
        pom.workdayEnd = "16:30"
        return line == "workday: 4h 30m left", line
    end)())
end

say("   -- 🖐 dragging --")
do
    local reg = DRAGGABLE[#DRAGGABLE] or {}
    check("the timer registers itself as draggable — LL: 'Great pop-up. "
          .. "But I can't drag the window.'", reg.label == "pomodoro",
          tostring(reg.label))
    check("...and hands over an onDrop, without which it would snap back "
          .. "to the corner every time it redraws",
          type(reg.onDrop) == "function")
    if reg.onDrop then reg.onDrop({ x = 300, y = 400, w = 170, h = 99 }) end
    check("dropping it remembers the position",
          pom.pos and pom.pos.x == 300, pom.pos and pom.pos.x)
    CANVASES = {}
    pom.start()
    local moved = CANVASES[#CANVASES]
    check("...and the next start opens THERE rather than the top-right",
          moved and moved.frame.x == 300 and moved.frame.y == 400,
          moved and (moved.frame.x .. "," .. moved.frame.y))
    pom.pos = { x = 99999, y = 99999 }
    CANVASES = {}
    pom.start()
    local clamped = CANVASES[#CANVASES]
    check("🚨 an off-screen remembered position is CLAMPED back — a "
          .. "position outlives the display it was set on, and restoring "
          .. "a panel off-screen leaves no way to reach it",
          clamped and clamped.frame.x < 1512,
          clamped and clamped.frame.x)
    -- 🚨 HAND THE NEXT SECTION A LIVE CANVAS. This block restarted the
    -- timer several times, so the `panel` captured above now points at a
    -- deleted canvas that nothing paints. The counting checks below read
    -- it, and would fail against perfectly correct code — a stale fixture
    -- reporting a bug that is not there.
    pom.pos = nil
    pom.stop("test"); pom.start()
    panel = CANVASES[#CANVASES]
end

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
-- =====================================================================
say("   -- 👻 6.152.0: faint until it matters, solid under the mouse --")
-- LL: "make the timer go from 30% transparency to 90% ... the last five
-- minutes" and "if I move the mouse pointer on to it, bring it
-- immediately to 90% and then if I move off of it, back to 30%".
pom.logFile = os.tmpname()
os.remove(pom.logFile)          -- logEvent recreates it, header first
CANVASES, TIMERS = {}, {}
NOW = 10000
pom.start()
local card = CANVASES[#CANVASES]
check("the card opens FAINT — pom.alphaIdle, whole-window alpha",
      card.alpha_ == pom.alphaIdle, card.alpha_)
check("a hover poll is running at pom.hoverSecs — and ONLY while the "
      .. "card is up", (function()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "every" and t.secs == pom.hoverSecs then return true end
    end
end)())
tickTo((pom.workMins - pom.alertMins) * 60 - 60)
check("mid-countdown it stays faint", card.alpha_ == pom.alphaIdle, card.alpha_)
tickTo(61)
check("👻 the last five minutes turn it SOLID — pom.alphaAlert",
      card.alpha_ == pom.alphaAlert, card.alpha_)
pom.stop("test")

CANVASES, TIMERS = {}, {}
NOW = 20000
pom.start()
card = CANVASES[#CANVASES]
MOUSE = { x = card.frame.x + 5, y = card.frame.y + 5 }
pom.checkHover()
check("mouse ON the card: solid, in one poll tick — 'immediately'",
      card.alpha_ == pom.alphaAlert, card.alpha_)
MOUSE = { x = 1, y = 1 }
pom.checkHover()
check("mouse off: faint again", card.alpha_ == pom.alphaIdle, card.alpha_)
check("the flash is always solid — an alert nobody can see is no alert",
      (function()
    pom.state.flasher = true            -- stand-in: mid-flash
    local a = pom.targetAlpha()
    pom.state.flasher = nil
    return a == pom.alphaAlert
end)())
pom.stop("test")
check("stop() takes the hover poll down with everything else", (function()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "every" and t.secs == pom.hoverSecs then return false end
    end
    return true
end)())

say("   -- 📒 6.152.0: the log, and the 4:30 tally --")
CANVASES, TIMERS, MODALS = {}, {}, {}
NOW = 30000
pom.start()                              -- row: started
NOW = NOW + pom.workMins * 60 + 1
for _, t in ipairs(TIMERS) do
    if t.live and t.kind == "every" and t.secs == 1 then t.fn() end
end                                      -- work phase ends → row: completed
do
    local f = io.open(pom.logFile, "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    check("the file begins with the promised columns: date,time,event,detail",
          content:find("^date,time,event,detail\n") ~= nil, content:sub(1, 30))
    check("every launch writes a `started` row, stamped to the second",
          content:find("\n%d%d%d%d%-%d%d%-%d%d,%d%d:%d%d:%d%d,started,") ~= nil)
    check("🍅 finishing the 25 minutes writes `completed` — the moment a "
          .. "pomodoro counts", content:find(",completed,") ~= nil)
end
pom.stop("test")
local todayReal = os.date("%Y-%m-%d")
local counts = pom.dayCounts(todayReal)
check("dayCounts reads the rows back", counts.started >= 1
      and counts.completed >= 1, counts.started .. "/" .. counts.completed)
check("weekLines closes with the week total",
      (function()
    local L = pom.weekLines(os.time())
    return L[#L] and L[#L]:find("week total:", 1, true) ~= nil
end)())
check("the daily tally timer is armed AT workdayEnd, repeating daily",
      (function()
    for _, t in ipairs(TIMERS) do
        if t.kind == "at" and t.secs == pom.workdayEnd and t.rep == "1d" then
            return true
        end
    end
    -- armed at setup time, before this section reset TIMERS — re-arm to
    -- prove the shape rather than pass on absence
    pomMod.setup(core)
    pom = pomMod.pom
    pom.logFile = os.tmpname()
    for _, t in ipairs(TIMERS) do
        if t.kind == "at" and t.secs == pom.workdayEnd and t.rep == "1d" then
            return true
        end
    end
end)())
check("the tally announces the day's completed count", (function()
    ALERTS = {}
    local off = pom.weekendsOff
    pom.weekendsOff = false             -- the guard is not under test here
    NOW = os.time()                     -- so the tally reads today's rows
    local msg = pom.endOfDay()
    pom.weekendsOff = off
    return msg and msg:find("Today:", 1, true) ~= nil
           and ALERTS[1] and ALERTS[1]:find("pomodoro", 1, true) ~= nil, msg
end)())
check("_G.pomodoroReport names the file and today's tally", (function()
    local r = _G.pomodoroReport()
    return r:find(pom.logFile, 1, true) ~= nil
           and r:find("today:", 1, true) ~= nil
end)())
check("it publishes pomodoro.report", _G.service.has("pomodoro.report"))
os.remove(pom.logFile)
NOW = 40000

-- =====================================================================
say("   -- 🧟 6.70.0: THE PANEL THAT WOULD NOT GO AWAY --")
-- LL, with a screenshot of a panel reading "DONE ⏎ / esc":
--     "is stuck on screen or I'm not hitting the escape key right. But
--      escape works for other Hammerspoon items."
-- They were hitting it right. The answer watchdog called releaseKeys(),
-- which exits the modal and clears `asking` — and LEAVES THE PANEL UP.
-- Twenty seconds after the cycle finished, esc was no longer bound to
-- anything and the panel was furniture. The old check below this one
-- asserted the KEYBOARD came back and never asked about the SCREEN.
local function fireAfter(secs)
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "after" and t.secs == secs then t.fn() end
    end
end
local function runFlash()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "every" and t.secs == pom.flashSecs then
            for _ = 1, pom.flashCount * 2 + 1 do
                if t.live then t.fn() end
            end
        end
    end
end

pom.stop(nil)
CANVASES, TIMERS, MODALS = {}, {}, {}
pom.start()
local doneCanvas = CANVASES[#CANVASES]
tickTo(25 * 60)                     -- work phase ends
runFlash()                          -- "STAND UP" flash → break starts
tickTo(5 * 60)                      -- break ends
runFlash()                          -- "DONE" flash → paints ⏎ / esc
check("the cycle reaches DONE with the panel still up and asking",
      pom.state ~= nil and pom.state.asking == true and not doneCanvas.deleted,
      pom.state and tostring(pom.state.asking))
fireAfter(pom.answerSecs)           -- ...and you never answer
check("🚨 THE PANEL CLOSES ITSELF when the answer window expires. It used "
      .. "to release ⏎ and esc and leave the window on screen with NOTHING "
      .. "bound to it — the only way out was ⇪⇧P or the Console",
      pom.state == nil, pom.state and tostring(pom.state.phase))
check("...and the canvas is really gone, not just the state cleared",
      doneCanvas.deleted == true)

say("   -- and the same expiry MID-cycle must not close it --")
pom.stop(nil)
CANVASES, TIMERS, MODALS = {}, {}, {}
pom.start()
local midCanvas = CANVASES[#CANVASES]
tickTo(25 * 60)
runFlash()                          -- work→break: the flash starts the break
check("the break is running", pom.state ~= nil and pom.state.phase == "break",
      pom.state and pom.state.phase)
fireAfter(pom.answerSecs)
check("🚨 EXPIRING THE WORK→BREAK QUESTION DOES **NOT** CLOSE IT. The "
      .. "break is already counting; closing there would end your cycle "
      .. "because you looked away for twenty seconds",
      pom.state ~= nil and not midCanvas.deleted,
      pom.state and pom.state.phase)

say("   -- 🧟 the class fix: a panel with nothing driving it --")
-- Fixing the one path is necessary and not sufficient. The panel is a
-- window only this module can close, so EVERY future path that forgets
-- has the same symptom. The ticker asks once a second whether the panel
-- is still alive, and closes it if it is not.
pom.stop(nil)
CANVASES, TIMERS, MODALS, PRINTED = {}, {}, {}, {}
pom.start()
local zombie = CANVASES[#CANVASES]
-- Strand it by hand, the way a future bug would: no countdown, no flash,
-- no question. Nothing in the module does this today — that is the point.
pom.state.endsAt = math.huge
pom.state.flasher = nil
pom.state.asking = false
tickTo(1)
check("one second of being stranded is not yet a bug — a legitimate pause "
      .. "between phases must never trip this",
      pom.state ~= nil and not zombie.deleted)
tickTo(pom.zombieSecs + 2)
check("🧟 A PANEL ON SCREEN WITH NOTHING DRIVING IT CLOSES ITSELF, "
      .. "whatever path stranded it", pom.state == nil and zombie.deleted,
      pom.state and tostring(pom.state.phase))
check("🚨 AND IT SAYS SO. A panel that quietly tidies itself away teaches "
      .. "nobody anything — this is a bug report, not housekeeping",
      (function()
        for _, l in ipairs(PRINTED or {}) do
            if tostring(l):find("nothing driving it", 1, true) then return true end
        end
      end)(), table.concat(PRINTED or {}, " | "):sub(1, 120))

say("   -- ∞ the clock that threw once a second, silently --")
-- tick() sets endsAt = math.huge so phaseEnded fires exactly once. Once
-- anything reached mmss() with that value, string.format("%02d", inf)
-- raised "number has no integer representation" — inside paint()'s
-- pcall, so it was swallowed. Sixty times a minute, forever, unseen.
pom.stop(nil)
CANVASES, TIMERS, MODALS, PRINTED = {}, {}, {}, {}
pom.start()
pom.state.endsAt = math.huge
pom.state.asking = true            -- alive, so the zombie check stays out
local threw = false
local okTick = pcall(function()
    for _, t in ipairs(TIMERS) do
        if t.live and t.kind == "every" and t.secs == 1 then t.fn() end
    end
end)
check("🚨 THE CLOCK SURVIVES AN INFINITE endsAt rather than throwing into "
      .. "a pcall nobody reads", okTick == true and pom.state ~= nil)
check("...and it draws SOMETHING honest rather than freezing on the last "
      .. "good paint", (function()
    local c = CANVASES[#CANVASES]
    for _, e in ipairs(c.elements or {}) do
        if e.type == "text" and tostring(e.text):find("%-%-:%-%-") then return true end
    end
end)(), (function()
    local c = CANVASES[#CANVASES]
    local t = {}
    for _, e in ipairs(c.elements or {}) do
        if e.type == "text" then t[#t + 1] = tostring(e.text) end
    end
    return table.concat(t, " ")
end)())
pom.stop(nil)

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
