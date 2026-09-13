-- =====================================================================
-- test_net_watch.lua — 🌐 who's talking, to whom, and why
-- =====================================================================
--     lua5.4 test_net_watch.lua [/path/to/hammerspoon]
--
-- Executes modules/net_watch.lua against a stubbed hs and drives the
-- REAL functions: the lsof -F parser (full command names, listeners,
-- UDP), the private-range rules, per-app aggregation, the what/why
-- rule table WITH its honest "unrecognized" fallback, both report
-- shapes, the serial reverse-DNS queue, the lsof deadline, and the
-- picker's copy paths. No socket is opened and no process is spawned.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local ALERTS, TASKS, TIMERS, CLIP = {}, {}, {}, nil
local HOTKEYS, CHOOSERS = {}, {}
local NOW = 1000

hs = {
    alert = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
    pasteboard = {
        setContents = function(s) CLIP = tostring(s); return true end,
    },
    timer = {
        secondsSinceEpoch = function() NOW = NOW + 0.05; return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, argv)
            local t = { bin = bin, cb = cb, argv = argv,
                        started = false, dead = false }
            function t:start() self.started = true; return self end
            function t:terminate() self.dead = true; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, rows = nil, shown = 0, visible = false }
            function c:choices(t) self.rows = t; return self end
            function c:placeholderText(p) self.placeholder = p; return self end
            function c:query(q) self.q = q; return self end
            function c:searchSubText() return self end
            function c:width() return self end
            function c:show() self.shown = self.shown + 1; self.visible = true; return self end
            function c:isVisible() return self.visible end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
    application = {
        -- pid 733 is a Chrome helper whose GUI identity is known
        applicationForPID = function(pid)
            if pid == 733 then
                return { name = function() return "Google Chrome" end }
            end
            return nil
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local core = {
    hostTag = "TestMac",
    provide = function() end,
    showPopup = function(ch) ch:show() end,
    hyperAddShortcut = function(mods, key, fn, label)
        HOTKEYS[#HOTKEYS + 1] = { mods = mods, key = key, fn = fn, label = label }
    end,
}

local chunk = assert(loadfile(HS .. "/modules/net_watch.lua"),
                     "cannot load modules/net_watch.lua")
local function boot()
    ALERTS, TASKS, TIMERS, CLIP = {}, {}, {}, nil
    HOTKEYS, CHOOSERS = {}, {}
    local M = chunk()
    M.setup(core)
    return _G.netWatch, M
end

-- lsof -FpcnPT, the real shape: p/c per process, P/n/T per network
-- file, and tags the parser must IGNORE (f = fd) mixed in.
local LSOF = table.concat({
    "p612",
    "cMicrosoft AutoUpdate",
    "f45",
    "PTCP",
    "n192.168.1.7:52311->52.108.8.11:443",
    "TST=ESTABLISHED",
    "f46",
    "PTCP",
    "n192.168.1.7:52312->23.201.4.9:443",
    "TST=ESTABLISHED",
    "p733",
    "cGoogle Chrome Helper (Renderer)",
    "PUDP",
    "n192.168.1.7:56000->142.250.72.14:443",
    "p801",
    "cZzyzxDaemon",
    "PTCP",
    "n*:8770",
    "TST=LISTEN",
    "PTCP",
    "n192.168.1.7:60000->10.0.0.9:445",
    "TST=ESTABLISHED",
}, "\n")

-- =====================================================================
out("── Net Watch: who's talking, to whom, and why ──\n")

out("\n=== 1. The module contract ===\n")
local nw, M = boot()
check("name, order and family are declared",
      M.name == "Net Watch" and M.order == 14.07 and M.family == "config")
check("the cheat sheet group announces ⇪⇧6",
      M.cheatsheet and M.cheatsheet.title:find("⇪⇧6", 1, true) ~= nil)
check("⇪⇧6 is claimed through the hyper registry",
      #HOTKEYS == 1 and HOTKEYS[1].key == "6"
      and HOTKEYS[1].mods[1] == "shift", HOTKEYS[1] and HOTKEYS[1].key)
check("the binaries are named constants the review can see",
      nw.LSOF == "/usr/sbin/lsof" and nw.DSCACHEUTIL == "/usr/bin/dscacheutil")

out("\n=== 1b. The wire-up is real, not remembered ===\n")
local function readAll(p)
    local f = io.open(p, "r"); if not f then return "" end
    local s = f:read("*a"); f:close(); return s
end
check("init.lua's BASE list loads this module", (function()
    local base = readAll(HS .. "/init.lua"):match("local BASE = {(.-)\n}") or ""
    return base:find('"net_watch"', 1, true) ~= nil
end)())
check("⇪space's run map joins ⇪⇧6 to netwatch.show", (function()
    local uni = readAll(HS .. "/modules/unified_search.lua")
    return uni:find('%["⇪⇧6"%]%s*=%s*"netwatch%.show"') ~= nil
end)())
check("the gate runs this very suite", (function()
    return readAll(HS .. "/tools/run-tests.sh"):find("test_net_watch", 1, true) ~= nil
end)())

out("\n=== 2. The lsof -F parser ===\n")
local conns = nw.parse(LSOF)
check("five network files parsed, fd lines ignored", #conns == 5, #conns)
check("full command names survive — spaces and all",
      conns[1].cmd == "Microsoft AutoUpdate"
      and conns[3].cmd == "Google Chrome Helper (Renderer)", conns[1].cmd)
check("a peer line splits into local and remote",
      conns[1].remote == "52.108.8.11:443"
      and conns[1].localEnd == "192.168.1.7:52311")
check("...and carries its TCP state", conns[1].state == "ESTABLISHED")
check("UDP has no state and that is fine",
      conns[3].proto == "UDP" and conns[3].state == nil)
check("a listener has NO remote", conns[4].remote == nil
      and conns[4].localEnd == "*:8770")
check("garbage in, empty out — never a throw", (function()
    local ok, r = pcall(nw.parse, nil)
    -- the garbage must not START with a real field tag: a leading "n"
    -- IS the name tag, and tolerating a stray name row is the parser
    -- being lenient, not wrong
    local ok2, r2 = pcall(nw.parse, "### lsof printed a warning banner")
    return ok and #r == 0 and ok2 and #r2 == 0
end)())

out("\n=== 3. Addresses ===\n")
check("v4 with port", nw.ipOf("52.108.8.11:443") == "52.108.8.11")
check("v6 in brackets", nw.ipOf("[2620:149:a44::4]:443") == "2620:149:a44::4")
check("private: 10/8, 172.16/12, 192.168/16, loopback, link-local",
      nw.isPrivate("10.1.2.3") and nw.isPrivate("172.16.0.1")
      and nw.isPrivate("172.31.255.1") and nw.isPrivate("192.168.1.7")
      and nw.isPrivate("127.0.0.1") and nw.isPrivate("169.254.1.1")
      and nw.isPrivate("fe80::1"))
check("public stays public — 8.8.8.8, 172.15.x, 172.32.x",
      not nw.isPrivate("8.8.8.8") and not nw.isPrivate("172.15.0.1")
      and not nw.isPrivate("172.32.0.1"))

out("\n=== 4. Aggregation ===\n")
local apps = nw.aggregate(conns)
check("three apps", #apps == 3, #apps)
check("the busiest talker sorts first",
      apps[1].name == "Microsoft AutoUpdate" and #apps[1].conns == 2,
      apps[1].name)
check("a known pid takes its GUI name — the helper reads as Chrome", (function()
    for _, a in ipairs(apps) do
        if a.name == "Google Chrome" then return true end
    end
    return false
end)())
check("a listener is counted, not shown as a connection", (function()
    for _, a in ipairs(apps) do
        if a.name == "ZzyzxDaemon" then
            return a.listeners == 1 and #a.conns == 1
        end
    end
    return false
end)())

out("\n=== 5. What and why — with an honest fallback ===\n")
nw.conns, nw.apps = conns, apps
local what, why, known = nw.explain(apps[1])
check("Microsoft AutoUpdate is a KNOWN story",
      known and what:find("AutoUpdate", 1, true) ~= nil
      and why:find("update", 1, true) ~= nil, what)
local zz
for _, a in ipairs(apps) do if a.name == "ZzyzxDaemon" then zz = a end end
local w2, y2, k2 = nw.explain(zz)
check("an unknown name says UNRECOGNIZED — never a confident guess",
      k2 == false and w2:find("unrecognized", 1, true) ~= nil, w2)
check("...and the why says how to judge it instead",
      y2:find("remote ends", 1, true) ~= nil, y2)
check("a domain rule fires off the RESOLVED name", (function()
    nw.dns["23.201.4.9"] = "a23-201-4-9.deploy.static.akamaitechnologies.com"
    local fake = { name = "helperx", conns = {
        { remote = "23.201.4.9:443", proto = "TCP" } }, pids = {}, listeners = 0 }
    local w3, _, k3 = nw.explain(fake)
    nw.dns["23.201.4.9"] = nil
    return k3 and w3:find("Akamai", 1, true) ~= nil, w3
end)())

out("\n=== 6. The reports ===\n")
nw.dns["52.108.8.11"] = "mobile.events.data.microsoft.com"
nw.scanAt = os.time()
local rep = nw.appReport(apps[1])
check("one app's report: name, count, what, why",
      rep:find("Microsoft AutoUpdate", 1, true) and rep:find("what :", 1, true)
      and rep:find("why  :", 1, true) and rep:find("2 connections", 1, true), rep)
check("...each path with protocol, both ends and state",
      rep:find("TCP 192.168.1.7:52311 → 52.108.8.11:443 (ESTABLISHED)", 1, true) ~= nil,
      rep)
check("...and the resolved name under its path",
      rep:find("52.108.8.11 resolves to mobile.events.data.microsoft.com", 1, true) ~= nil)
check("a private remote is 'local network', not a DNS story", (function()
    local r = nw.appReport(zz)
    return r:find("local network", 1, true) ~= nil, r
end)())
local full = nw.fullReport()
check("the full report opens with the host and the honesty line",
      full:find("TestMac", 1, true) ~= nil
      and full:find("root's daemons need admin", 1, true) ~= nil)
check("...and carries every app", full:find("ZzyzxDaemon", 1, true) ~= nil
      and full:find("Google Chrome", 1, true) ~= nil)

out("\n=== 7. Reverse DNS, one at a time ===\n")
nw, M = boot()
nw.conns = nw.parse(LSOF)
nw.apps  = nw.aggregate(nw.conns)
nw.queueDns()
check("exactly ONE dscacheutil runs at a time", #TASKS == 1
      and TASKS[1].bin == "/usr/bin/dscacheutil", #TASKS)
check("...asked the documented way", table.concat(TASKS[1].argv, " ")
      == "-q host -a ip_address 52.108.8.11", table.concat(TASKS[1].argv, " "))
check("private remotes were never queued", (function()
    for _, t in ipairs(TASKS) do
        for _, a in ipairs(t.argv) do
            if tostring(a):match("^10%.") or tostring(a):match("^192%.168%.") then
                return false, a
            end
        end
    end
    return true
end)())
TASKS[1].cb(0, "name: mobile.events.data.microsoft.com\n", "")
check("the answer lands in the cache",
      nw.dns["52.108.8.11"] == "mobile.events.data.microsoft.com")
check("...and the queue moves to the next IP", #TASKS >= 2, #TASKS)
TASKS[#TASKS].cb(0, "", "")   -- no PTR record
check("no answer is remembered as false, not retried",
      nw.dns["23.201.4.9"] == false or nw.dns["142.250.72.14"] == false)

out("\n=== 8. The snapshot and its deadline ===\n")
nw, M = boot()
nw.scan()
local lt = TASKS[1]
check("lsof runs with field output and full command names",
      lt.bin == "/usr/sbin/lsof"
      and table.concat(lt.argv, " ") == "-i -n -P -w +c 0 -FpcnPT",
      table.concat(lt.argv, " "))
check("a deadline is armed beside it",
      #TIMERS == 1 and TIMERS[1].secs == nw.lsofTimeout)
check("a second press while one runs is refused, not stacked",
      nw.scan() == false)
TIMERS[1].fn()
check("the deadline kills a hung lsof and says so",
      lt.dead and nw.lastErr ~= nil
      and (ALERTS[#ALERTS] or ""):find("stopped", 1, true) ~= nil, nw.lastErr)
check("...and the next press may run again", nw.scan() == true)
local lt2 = TASKS[#TASKS]
check("lsof exit 1 WITH output is a partial answer, not a failure", (function()
    lt2.cb(1, LSOF, "some process refused")
    return nw.lastErr == nil and #nw.apps == 3, nw.lastErr
end)())

out("\n=== 9. The picker: ⌘1 everything, ⏎ one app ===\n")
nw, M = boot()
nw.show()
TASKS[1].cb(0, LSOF, "")
local ch = CHOOSERS[1]
check("the chooser opened once the snapshot returned",
      ch ~= nil and ch.shown == 1)
check("row 1 — the chooser's native ⌘1 — is copy-everything",
      ch.rows[1].act == "all"
      and ch.rows[1].text:find("FULL", 1, true) ~= nil, ch.rows[1].text)
check("one row per app follows, busiest first",
      #ch.rows == 4 and ch.rows[2].idx == 1
      and ch.rows[2].text:find("Microsoft AutoUpdate", 1, true) ~= nil,
      #ch.rows)
check("the row's subtitle carries its explanation",
      ch.rows[4].subText:find("unrecognized", 1, true) ~= nil
      or ch.rows[3].subText:find("unrecognized", 1, true) ~= nil)
ch.cb(ch.rows[1])
check("⌘1 copies the FULL report to the clipboard",
      CLIP ~= nil and CLIP:find("WHO'S TALKING", 1, true) ~= nil
      and (ALERTS[#ALERTS] or ""):find("copied", 1, true) ~= nil)
ch.cb(ch.rows[2])
check("⏎ on an app copies THAT app's report only",
      CLIP:find("Microsoft AutoUpdate", 1, true) ~= nil
      and CLIP:find("WHO'S TALKING", 1, true) == nil, CLIP and CLIP:sub(1, 60))

out("\n=== 10. BREAK the honesty on purpose ===\n")
local src = readAll(HS .. "/modules/net_watch.lua")

-- BREAK A — the unrecognized fallback. Replace it with "first rule
-- wins regardless" and an unknown daemon confidently claims to be
-- Microsoft AutoUpdate. The fallback IS the feature: a wrong "why"
-- teaches you to trust wrong answers about your own network.
do
    local broken = src:gsub(
        'return "unrecognized — the paths below show exactly where it connects",%s*\n'
        .. '%s*"no rule matches this name; judge it by its remote ends", false',
        'return nw.known[1].what, nw.known[1].why, true')
    check("BREAK A really edited the source", broken ~= src)
    local okL, bChunk = pcall(load, broken, "broken-netwatch-A")
    check("...and still compiles", okL and bChunk ~= nil)
    if okL and bChunk then
        local bM = bChunk()
        bM.setup(core)
        local bnw = _G.netWatch
        local fake = { name = "ZzyzxDaemon", conns = {}, pids = {}, listeners = 0 }
        local wB, _, kB = bnw.explain(fake)
        check("without the fallback, an unknown daemon wears AutoUpdate's "
              .. "story — the confident lie the intact module refuses",
              kB == true and wB:find("AutoUpdate", 1, true) ~= nil, wB)
    end
end

-- BREAK B — the private-range guard. Without it your printer and your
-- router get queued for public reverse-DNS and labeled by whatever
-- comes back.
do
    local broken = src:gsub('or ip:match%("%^192%%%.168%%%."%) then return true end',
                            'then return true end')
    check("BREAK B really edited the source", broken ~= src)
    local okL, bChunk = pcall(load, broken, "broken-netwatch-B")
    check("...and still compiles", okL and bChunk ~= nil)
    if okL and bChunk then
        local bM = bChunk()
        bM.setup(core)
        check("without the guard, 192.168.1.7 reads as public",
              _G.netWatch.isPrivate("192.168.1.7") == false)
    end
end

-- rebuild the real module so nothing broken outlives this section
boot()

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
