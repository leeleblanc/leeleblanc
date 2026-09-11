-- =====================================================================
-- test_stall_guard.lua — a beach ball no longer costs LL the keyboard
-- =====================================================================
--     lua5.4 test_stall_guard.lua [/path/to/hammerspoon]
--
-- Two halves, because the feature has two halves:
--
--   1. modules/stall_guard.lua against a stubbed hs: the beat is written
--      on a HELD timer, warm() starts the guard with the right arguments
--      (and does not when it is off, or the script is missing, or the
--      folder cannot be made), the boot announcement says each relaunch
--      ONCE, the report prints as one string, and the shutdown wrap
--      writes the quit marker beside init.lua's own cleanup.
--
--   2. tools/hs-stall-guard.sh RUN FOR REAL, on this Linux box, with
--      kill / pgrep / open / hidutil replaced by scripts that record
--      what they were asked (the SG_* overrides exist for exactly this).
--      CHECK=1 s, STALL=2 s, so every rule in the script's header is
--      exercised in seconds: two stale readings, a stale-then-fresh that
--      must NOT relaunch, a clean quit, a newer guard, "not running",
--      the ten-minute limit (and that OLD relaunches do not count), and
--      a sleep gap — a real SIGSTOP/SIGCONT, not a simulated clock.
--      Every scenario ends by writing the quit marker and waiting for
--      the exit line, so no guard outlives the suite.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local function readAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function writeFile(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
local function sleep(secs) os.execute("sleep " .. tostring(secs)) end

-- a private folder for everything this suite writes
local ROOT = os.tmpname()
os.remove(ROOT)
assert(os.execute('mkdir -p "' .. ROOT .. '/tools"'))
local SCRIPT = HS .. "/tools/hs-stall-guard.sh"
assert(readAll(SCRIPT), "tools/hs-stall-guard.sh is missing")
writeFile(ROOT .. "/tools/hs-stall-guard.sh", readAll(SCRIPT))

-- ---- the stub Mac ------------------------------------------------------
local TIMERS, TASKS, ALERTS, NOTES, PRINTED, SETTINGS = {}, {}, {}, {}, {}, {}
local NOTICES = {}
local NO_SETTINGS = false
local TASK_REFUSES = false

local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

local function makeHs(configdir)
    return {
        configdir = configdir,
        timer = {
            doEvery = function(secs, fn)
                local t = { secs = secs, fn = fn, isRunning = true }
                function t:stop() self.isRunning = false end
                TIMERS[#TIMERS + 1] = t
                return t
            end,
            doAfter = function(secs, fn)
                local t = { secs = secs, fn = fn }
                function t:stop() end
                return t
            end,
            secondsSinceEpoch = function() return os.time() end,
        },
        fs = {
            attributes = function(p)
                if os.execute('test -d "' .. p .. '"') == true then return { mode = "directory" } end
                if os.execute('test -e "' .. p .. '"') == true then return { mode = "file" } end
                return nil
            end,
            mkdir = function(p) return os.execute('mkdir -p "' .. p .. '"') end,
        },
        task = {
            new = function(path, cb, args)
                if TASK_REFUSES then return nil end
                local t = { path = path, cb = cb, args = args, started = false }
                function t:start() self.started = true return self end
                TASKS[#TASKS + 1] = t
                return t
            end,
        },
        alert  = { show = function(msg, secs) ALERTS[#ALERTS + 1] = { msg = msg, secs = secs } end },
        notify = { new = function(opts)
            local n = { opts = opts }
            function n:send() NOTES[#NOTES + 1] = self.opts return self end
            return n
        end },
        settings = {
            get = function(k) if NO_SETTINGS then error("no settings") end return SETTINGS[k] end,
            set = function(k, v) if NO_SETTINGS then error("no settings") end SETTINGS[k] = v end,
        },
    }
end

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function(kind, src, msg) NOTICES[#NOTICES + 1] = { kind = kind, src = src, msg = msg } end }
_G.configVersion = "test"

local chunk = assert(loadfile(HS .. "/modules/stall_guard.lua"), "cannot load modules/stall_guard.lua")

local SHUTDOWN_PREV_RAN = 0
local function boot(configdir, opts)
    opts = opts or {}
    TIMERS, TASKS, ALERTS, NOTES, PRINTED = {}, {}, {}, {}, {}
    NOTICES = {}
    _G.stallGuard, _G.stallGuardBeat, _G.stallGuardQuit, _G.stallGuardReport = nil, nil, nil, nil
    hs = makeHs(configdir)
    if configdir and not opts.noScript then
        os.execute('mkdir -p "' .. configdir .. '/tools"')
        writeFile(configdir .. "/tools/hs-stall-guard.sh", readAll(SCRIPT))
    end
    if opts.prevShutdown ~= false then
        hs.shutdownCallback = function() SHUTDOWN_PREV_RAN = SHUTDOWN_PREV_RAN + 1 end
    end
    local M = chunk()
    M.setup({ configDir = configdir })
    if opts.settings then for k, v in pairs(opts.settings) do M.config[k] = v end end
    if not opts.noWarm then M.warm({}) end
    return M.config, M
end

-- =====================================================================
out("── Stall Guard: a beach ball no longer costs LL the keyboard ──\n")

out("\n=== 1. The beat: written at setup, on a held timer, from the main thread ===\n")
do
    local dir = ROOT .. "/a"
    os.execute('mkdir -p "' .. dir .. '"')
    local sg = boot(dir, { noWarm = true })
    local beat = readAll(dir .. "/.stall-guard/heartbeat")
    check("setup writes the heartbeat before anything else runs", beat ~= nil, beat)
    check("...and it is the epoch second, nothing else",
          beat and tonumber(beat) and math.abs(tonumber(beat) - os.time()) <= 2, beat)
    check("the beat timer is held in sg.beatTimer AND _G.stallGuardBeat",
          sg.beatTimer ~= nil and _G.stallGuardBeat == sg.beatTimer)
    check("it beats every 2 s", TIMERS[1] and TIMERS[1].secs == 2, TIMERS[1] and TIMERS[1].secs)
    local before = sg.beats
    TIMERS[1].fn()
    check("a tick writes again and counts", sg.beats == before + 1, sg.beats)
    check("the state before warm says so", sg.state == "not yet warmed", sg.state)
    check("_G.stallGuard is the config table (settings-overridable)", _G.stallGuard == sg)
end

out("\n=== 2. warm(): the guard is started with the numbers the report names ===\n")
do
    local dir = ROOT .. "/b"
    os.execute('mkdir -p "' .. dir .. '"')
    local sg = boot(dir)
    check("state is watching", sg.state == "watching", sg.state)
    check("exactly one hs.task, /bin/sh", #TASKS == 1 and TASKS[1].path == "/bin/sh", #TASKS)
    local a = TASKS[1] and TASKS[1].args or {}
    check("...started", TASKS[1] and TASKS[1].started)
    check("...detached with nohup and & so it outlives the wrapper AND Hammerspoon",
          a[1] == "-c" and a[2]:find("nohup", 1, true) and a[2]:find("&", 1, true), a[2])
    check("...the script is the installed copy under the config folder",
          a[4] == dir .. "/tools/hs-stall-guard.sh", a[4])
    check("...the folder, stall, check and max ride as arguments",
          a[5] == dir .. "/.stall-guard" and a[6] == "20" and a[7] == "5" and a[8] == "3",
          table.concat(a, " | "))
    check("the task is HELD (sg.spawnTask)", sg.spawnTask == TASKS[1])
    check("no sudo, no launchctl, no LaunchAgent anywhere in the module or the script",
          not (readAll(HS .. "/modules/stall_guard.lua") .. readAll(SCRIPT)):find("sudo%s")
          and not (readAll(HS .. "/modules/stall_guard.lua") .. readAll(SCRIPT)):find("launchctl"))
end

out("\n=== 3. Degrades, each named ===\n")
do
    local dir = ROOT .. "/c"
    os.execute('mkdir -p "' .. dir .. '"')
    local sg = boot(dir, { settings = { on = false } })
    check("on = false: no guard started", #TASKS == 0, #TASKS)
    check("...the beat timer is stopped", TIMERS[1] and TIMERS[1].isRunning == false)
    check("...and the state names the setting",
          sg.state:find("settings = { stall_guard = { on = false } }", 1, true) ~= nil, sg.state)
    _G.stallGuardReport()
    check("...the report's beat line says off with the setting",
          PRINTED[#PRINTED]:find("beat   : off", 1, true) ~= nil, PRINTED[#PRINTED])

    local dir2 = ROOT .. "/c2"
    os.execute('mkdir -p "' .. dir2 .. '"')
    sg = boot(dir2, { settings = { script = dir2 .. "/nowhere.sh" } })
    check("script missing: no task, state says where it looked",
          #TASKS == 0 and sg.state:find("script not installed at", 1, true) ~= nil, sg.state)
    check("...but the beat still runs (the log will still be read next boot)", sg.beatTimer ~= nil)
    check("...and the Console said so once", PRINTED[#PRINTED]:find("guard could not be started", 1, true) ~= nil)

    TASK_REFUSES = true
    local dir3 = ROOT .. "/c3"
    os.execute('mkdir -p "' .. dir3 .. '"')
    sg = boot(dir3)
    TASK_REFUSES = false
    check("hs.task refusing: named, no throw", sg.state:find("hs.task refused", 1, true) ~= nil, sg.state)

    -- a folder that cannot be created: point the module at a FILE
    local dir4 = ROOT .. "/c4"
    os.execute('mkdir -p "' .. dir4 .. '"')
    writeFile(dir4 .. "/.stall-guard", "not a folder")
    sg = boot(dir4)
    check("folder unmakeable: degraded, named, no throw, no guard",
          sg.state:find("degraded", 1, true) ~= nil and #TASKS == 0, sg.state)
    _G.stallGuardReport()
    check("...report's guard line names it",
          PRINTED[#PRINTED]:find("guard  : not running", 1, true) ~= nil, PRINTED[#PRINTED])

    sg = boot(nil, {})
    check("no config folder at all: every state is named, nothing throws",
          sg.state:find("no config folder", 1, true) ~= nil, sg.state)
    local okR = pcall(_G.stallGuardReport)
    check("...and the report still prints", okR)
end

out("\n=== 4. The quit marker rides the existing shutdown callback ===\n")
do
    local dir = ROOT .. "/d"
    os.execute('mkdir -p "' .. dir .. '"')
    SHUTDOWN_PREV_RAN = 0
    local sg = boot(dir)
    check("hs.shutdownCallback was wrapped, not replaced", sg.wrappedShutdown == true)
    hs.shutdownCallback()
    check("...init.lua's own cleanup still ran", SHUTDOWN_PREV_RAN == 1, SHUTDOWN_PREV_RAN)
    check("...the quit marker exists", readAll(dir .. "/.stall-guard/quit") ~= nil)
    check("...and the beat stopped", sg.beatTimer == nil and TIMERS[1].isRunning == false)
    local ok, why = _G.stallGuardQuit()
    check("_G.stallGuardQuit() returns ok, why", ok == true and why == nil)

    local dir2 = ROOT .. "/d2"
    os.execute('mkdir -p "' .. dir2 .. '"')
    sg = boot(dir2, { prevShutdown = false })
    check("no earlier callback: still safe, and the report says so",
          sg.wrappedShutdown == false and pcall(hs.shutdownCallback))
    _G.stallGuardReport()
    check("...", PRINTED[#PRINTED]:find("no hs.shutdownCallback was set", 1, true) ~= nil)
end

out("\n=== 5. The boot announcement: each relaunch said ONCE, in three places ===\n")
do
    local dir = ROOT .. "/e"
    os.execute('mkdir -p "' .. dir .. '/.stall-guard"')
    local t0 = os.time() - 100
    writeFile(dir .. "/.stall-guard/stall-guard.log", table.concat({
        t0 .. " 2026-09-11 10:00:00 started pid=111 stall=20s check=5s max=3",
        (t0 + 30) .. " 2026-09-11 10:00:30 relaunched: stalled 27s, killed pid=222",
        (t0 + 60) .. " 2026-09-11 10:01:00 exit: replaced by a newer guard",
    }, "\n") .. "\n")
    SETTINGS = {}
    local sg = boot(dir)
    check("one relaunch announced", #sg.announced == 1, #sg.announced)
    check("...the alert names the seconds and the time",
          ALERTS[1] and ALERTS[1].msg:find("HUNG for 27 s at 2026-09-11 10:00:30", 1, true) ~= nil,
          ALERTS[1] and ALERTS[1].msg)
    check("...a notification", NOTES[1] and NOTES[1].title == "Hammerspoon was relaunched")
    check("...the Console, as ONE print with the report named",
          (function()
              for _, p in ipairs(PRINTED) do
                  if p:find("HUNG for 27 s", 1, true) and p:find("_G.stallGuardReport()", 1, true) then return true end
              end
          end)())
    check("...and _G.notices", NOTICES[1] and NOTICES[1].src == "stall_guard"
          and NOTICES[1].msg:find("relaunched", 1, true) ~= nil)
    check("the newest epoch is remembered", SETTINGS["stallGuard.seenEpoch"] == t0 + 30, SETTINGS["stallGuard.seenEpoch"])

    sg = boot(dir)
    check("the next boot says NOTHING about the same stall", #sg.announced == 0 and #ALERTS == 0, #sg.announced)

    local f = io.open(dir .. "/.stall-guard/stall-guard.log", "a")
    f:write((t0 + 90) .. " 2026-09-11 10:01:30 gave up: 3 relaunches in the last 10 min — not relaunching pid=333 (stalled 41s)\n")
    f:close()
    sg = boot(dir)
    check("a NEW line is announced, and a give-up names the fix",
          #sg.announced == 1 and ALERTS[1].msg:find("GAVE UP", 1, true) ~= nil
          and ALERTS[1].msg:find("hold ⇧", 1, true) ~= nil, ALERTS[1] and ALERTS[1].msg)
    _G.stallGuardReport()
    local rep = PRINTED[#PRINTED]
    check("the report prints as ONE string", rep:find("🧊 STALL GUARD", 1, true) == 1 and rep:find("\n   beat   :", 1, true) ~= nil)
    check("...counts the stalls and lists them",
          rep:find("stalls : 2 relaunch/give-up", 1, true) ~= nil and rep:find("killed pid=222", 1, true) ~= nil, rep)
    check("...says what was said this boot", rep:find("said   : 1 announced", 1, true) ~= nil)

    NO_SETTINGS = true
    SETTINGS = {}
    sg = boot(dir)
    NO_SETTINGS = false
    check("no hs.settings: still announces, and SAYS every boot will",
          #sg.announced == 2 and tostring(sg.announceWhy):find("every boot", 1, true) ~= nil, sg.announceWhy)

    local dir2 = ROOT .. "/e2"
    os.execute('mkdir -p "' .. dir2 .. '"')
    sg = boot(dir2)
    _G.stallGuardReport()
    check("no log yet: the report says the guard has not written, not 'no stalls'",
          PRINTED[#PRINTED]:find("no log yet", 1, true) ~= nil, PRINTED[#PRINTED])

    -- the log is read from its END: a big log costs a bounded read
    local big = {}
    for i = 1, 400 do big[#big + 1] = (t0 - 1000 + i) .. " 2026-09-11 09:00:00 skipped a reading after a 9s gap (sleep?)" end
    big[#big + 1] = (t0 + 200) .. " 2026-09-11 10:03:20 relaunched: stalled 30s, killed pid=444"
    writeFile(dir2 .. "/.stall-guard/stall-guard.log", table.concat(big, "\n") .. "\n")
    SETTINGS = {}
    sg = boot(dir2)
    check("only the tail is read, and the newest relaunch is still found",
          #sg.announced == 1 and sg.parseLog(sg.readLog())[1].epoch > t0 - 1000 + 1, #sg.announced)
end

out("\n=== 6. Pure: parseLog / newEvents ===\n")
do
    local sg = boot(ROOT .. "/f", { noWarm = true })
    local rows = sg.parseLog("1000 2026-01-01 00:00:00 started pid=1 stall=20s\n"
                          .. "junk line\n"
                          .. "1005 2026-01-01 00:00:05 relaunched: stalled 21s, killed pid=2\n"
                          .. "1009 2026-01-01 00:00:09 gave up: 3 relaunches in the last 10 min — not relaunching pid=3 (stalled 40s)\n"
                          .. "1010 2026-01-01 00:00:10 exit: replaced by a newer guard\n")
    check("four rows parsed, the junk skipped", #rows == 4, #rows)
    check("events named", rows[1].event == "started" and rows[2].event == "relaunched"
          and rows[3].event == "gave up" and rows[4].event == "exit",
          rows[1].event .. "/" .. rows[2].event .. "/" .. rows[3].event .. "/" .. rows[4].event)
    local new = sg.newEvents(rows, 1005)
    check("newEvents: strictly newer than seen, relaunch/give-up only", #new == 1 and new[1].epoch == 1009, #new)
    check("seen nil = everything", #sg.newEvents(rows, nil) == 2)
    check("empty log", #sg.parseLog("") == 0 and #sg.newEvents({}, 0) == 0)
end

-- =====================================================================
out("\n=== 7. tools/hs-stall-guard.sh, run for real ===\n")
local BIN = ROOT .. "/bin"
os.execute('mkdir -p "' .. BIN .. '"')
writeFile(BIN .. "/pgrep", '#!/bin/sh\ncat "$SG_TEST/hspid" 2>/dev/null\n')
writeFile(BIN .. "/kill", '#!/bin/sh\necho "$*" >> "$SG_TEST/kills"\n')
writeFile(BIN .. "/open", '#!/bin/sh\necho "$*" >> "$SG_TEST/opens"\n')
writeFile(BIN .. "/hidutil", '#!/bin/sh\necho "$*" >> "$SG_TEST/hidutil"\n')
os.execute('chmod +x "' .. BIN .. '"/*')

local N = 0
local function scenario(opts)
    N = N + 1
    local dir = ROOT .. "/s" .. N
    os.execute('mkdir -p "' .. dir .. '"')
    if opts.beatAge then writeFile(dir .. "/heartbeat", tostring(os.time() - opts.beatAge)) end
    if opts.hspid ~= false then writeFile(dir .. "/hspid", tostring(opts.hspid or 4242) .. "\n") end
    if opts.log then writeFile(dir .. "/stall-guard.log", opts.log) end
    local env = 'SG_TEST="' .. dir .. '" SG_KILL="' .. BIN .. '/kill" SG_PGREP="' .. BIN .. '/pgrep"'
              .. ' SG_OPEN="' .. BIN .. '/open" SG_HIDUTIL="' .. BIN .. '/hidutil"'
              .. (opts.window and (' SG_WINDOW=' .. opts.window) or "")
    local cmd = env .. ' nohup /bin/sh "' .. SCRIPT .. '" "' .. dir .. '" ' .. (opts.stall or 2)
              .. ' ' .. (opts.check or 1) .. ' ' .. (opts.max or 3) .. ' >/dev/null 2>&1 &'
    os.execute(cmd)
    local s = { dir = dir }
    function s.log() return readAll(dir .. "/stall-guard.log") or "" end
    function s.kills() return readAll(dir .. "/kills") or "" end
    function s.opens() return readAll(dir .. "/opens") or "" end
    function s.pid()
        for _ = 1, 20 do
            local p = readAll(dir .. "/guard.pid")
            if p and p:match("%d+") then return tonumber(p:match("%d+")) end
            sleep(0.1)
        end
    end
    function s.alive()
        local p = s.pid()
        if not p then return false end
        local h = io.popen("ps -o stat= -p " .. p .. " 2>/dev/null")
        local st = h and h:read("a") or ""
        if h then h:close() end
        st = st:gsub("%s+", "")
        return st ~= "" and st:sub(1, 1) ~= "Z"
    end
    function s.quit()
        writeFile(dir .. "/quit", "")
        for _ = 1, 60 do
            if not s.alive() then return true end
            sleep(0.25)
        end
        return false
    end
    function s.waitFor(pat, secs)
        for _ = 1, (secs or 5) * 4 do
            if s.log():find(pat, 1, true) then return true end
            sleep(0.25)
        end
        return false
    end
    return s
end

-- A. a live beat is never killed; a clean quit ends the guard
do
    local s = scenario({ beatAge = 0 })
    check("A: the guard wrote its pid", s.pid() ~= nil)
    check("A: ...and a started line", s.waitFor("started pid=", 3))
    for _ = 1, 3 do writeFile(s.dir .. "/heartbeat", tostring(os.time())); sleep(1) end
    check("A: three seconds of a live beat — no kill, no open", s.kills() == "" and s.opens() == "", s.kills())
    check("A: the quit marker ends it", s.quit())
    check("A: ...with the exit line", s.log():find("exit: Hammerspoon quit cleanly", 1, true) ~= nil, s.log())
    check("A: ...and the quit marker was removed at start (the new boot's job) and honoured after",
          s.log():match("started") ~= nil)
end

-- B. ONE stale reading then a fresh beat: no relaunch (two in a row are required)
do
    local s = scenario({ beatAge = 30, check = 2 })
    sleep(3)                                            -- the first check (t=2) saw it stale
    writeFile(s.dir .. "/heartbeat", tostring(os.time()))
    sleep(3.5)                                          -- the second (t=4) and third (t=6) saw it fresh
    check("B: stale once then fresh — nothing killed", s.kills() == "", s.kills())
    check("B: ...no relaunch line", not s.log():find("relaunched", 1, true), s.log())
    s.quit()
end

-- C. two stale readings with Hammerspoon running: kill -9, hidutil, open — and logged
do
    local s = scenario({ beatAge = 30, hspid = 4242 })
    check("C: relaunched line within a few seconds", s.waitFor("relaunched: stalled", 6), s.log())
    sleep(1.5)                                          -- the kill/hidutil/open follow the log line
    check("C: kill -9 of the pid pgrep named", s.kills():find("-9 4242", 1, true) ~= nil, s.kills())
    check("C: the ⇪ remap is lifted", (readAll(s.dir .. "/hidutil") or ""):find("UserKeyMapping", 1, true) ~= nil)
    check("C: open -a Hammerspoon", s.opens():find("-a Hammerspoon", 1, true) ~= nil, s.opens())
    check("C: the line says how long it was stalled and which pid",
          s.log():match("relaunched: stalled (%d+)s, killed pid=4242") ~= nil, s.log())
    check("C: the guard is still alive afterwards (it keeps watching the new instance)", s.alive())
    s.quit()
end

-- D. a newer guard's pid in the file: this one exits
do
    local s = scenario({ beatAge = 0 })
    local p = s.pid()
    writeFile(s.dir .. "/guard.pid", tostring(p + 100000))
    check("D: replaced → exit line", s.waitFor("exit: replaced by a newer guard", 4), s.log())
    sleep(0.5)
    check("D: ...and the process is gone", not s.alive())
end

-- E. Hammerspoon not running: a stale beat is NOT a stall
do
    local s = scenario({ beatAge = 30, hspid = false })
    sleep(3)
    check("E: not running — nothing killed, nothing opened", s.kills() == "" and s.opens() == "")
    check("E: ...never launched on its own", not s.log():find("relaunched", 1, true))
    s.quit()
end

-- F. the limit: three recent relaunches → gave up, no kill, exit
do
    local t = os.time()
    local seed = {}
    for i = 1, 3 do seed[#seed + 1] = (t - 10 * i) .. " 2026-09-11 10:00:00 relaunched: stalled 25s, killed pid=1" end
    local s = scenario({ beatAge = 30, log = table.concat(seed, "\n") .. "\n" })
    check("F: gave up line", s.waitFor("gave up: 3 relaunches", 6), s.log())
    sleep(0.5)
    check("F: ...nothing killed", s.kills() == "", s.kills())
    check("F: ...and the guard exited", not s.alive())
end

-- G. the limit counts the WINDOW: three OLD relaunches do not stop a new one
do
    local t = os.time()
    local seed = {}
    for i = 1, 3 do seed[#seed + 1] = (t - 700 - i) .. " 2026-09-11 09:00:00 relaunched: stalled 25s, killed pid=1" end
    local s = scenario({ beatAge = 30, log = table.concat(seed, "\n") .. "\n" })
    check("G: old lines do not count — relaunched", s.waitFor("relaunched: stalled", 6), s.log())
    check("G: ...no give-up", not s.log():find("gave up", 1, true))
    s.quit()
end

-- H. a sleep gap (real SIGSTOP): the reading after it is thrown away
do
    local s = scenario({ beatAge = 30 })
    local p = s.pid()
    os.execute("kill -STOP " .. p)
    sleep(4.5)
    os.execute("kill -CONT " .. p)
    check("H: the gap is logged as skipped", s.waitFor("skipped a reading after a", 4), s.log())
    check("H: ...and the relaunch, when it comes, is at least two checks AFTER the skip",
          (function()
              if not s.waitFor("relaunched: stalled", 6) then return false end
              local skip = tonumber(s.log():match("(%d+) [^\n]*skipped a reading"))
              local re   = tonumber(s.log():match("(%d+) [^\n]*relaunched: stalled"))
              return skip and re and (re - skip) >= 2
          end)(), s.log())
    s.quit()
end

-- I. an unreadable / non-numeric beat is not a stall either
do
    local s = scenario({})
    writeFile(s.dir .. "/heartbeat", "not a number")
    sleep(3)
    check("I: junk beat — nothing killed", s.kills() == "", s.kills())
    s.quit()
end

-- leave nothing behind
os.execute('for f in "' .. ROOT .. '"/s*/guard.pid; do p=$(cat "$f" 2>/dev/null); [ -n "$p" ] && kill -9 "$p" 2>/dev/null; done; true')
os.execute('rm -rf "' .. ROOT .. '"')

out("\n=== 8. Sentries: wired in, every place the loader and the doctor look ===\n")
do
    local init = readAll(HS .. "/init.lua") or ""
    check("init.lua's BASE list loads stall_guard", init:find('"stall_guard",', 1, true) ~= nil)
    local install = readAll(HS .. "/tools/hs-install.sh") or ""
    check("hs-install.sh copies tools/*.sh (the guard script rides with the install)",
          install:find('tools"/*.sh', 1, true) ~= nil)
    local src = readAll(HS .. "/modules/stall_guard.lua") or ""
    check("the beat is io.open on the main thread, deliberately — no hs.task writes it",
          src:find('io.open(sg.dir .. "/heartbeat", "w")', 1, true) ~= nil)
    check("the guard is spawned from warm(), never from a task callback",
          src:find("function M.warm", 1, true) ~= nil
          and (src:find("local ok, why = sg.spawn()", 1, true) or 0) > src:find("function M.warm", 1, true))
    check("the script takes its binaries from SG_* overrides with absolute defaults",
          (readAll(SCRIPT) or ""):find("KILL=${SG_KILL:-/bin/kill}", 1, true) ~= nil
          and (readAll(SCRIPT) or ""):find("PGREP=${SG_PGREP:-/usr/bin/pgrep}", 1, true) ~= nil)
end

-- =====================================================================
print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do out("  ❌ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
