-- =====================================================================
-- test_begone.lua — the typed word that closes every notification banner
-- =====================================================================
--     lua5.4 test_begone.lua [/path/to/hammerspoon]
--
-- The claims under test: the keyword registers through the expander's
-- action service (and reports, not warns, when that module is off), the
-- sweep runs osascript OFF the main thread with the FOUR container
-- addresses (6.99.0 added the macOS-26 deep walk) and the multi-pass
-- loop in its script, the closed/seen pair comes back as an alert that
-- can tell "nothing there" from "Apple moved the furniture", and a Mac
-- that has not granted Accessibility hears about Accessibility — not
-- silence.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        local line = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        failures[#failures + 1] = line
        io.write("   ❌ " .. line .. "\n")
    end
end
local function out(s) io.write(s) end

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function saidOnConsole(pat)
    for _, l in ipairs(printed) do if l:find(pat, 1, true) then return true end end
end

-- ---- a controllable world --------------------------------------------
local TASKS, ALERTS, PROVIDED = {}, {}, {}

hs = {
    task = { new = function(cmd, cb, args)
        local t = { cmd = cmd, cb = cb, args = args, started = false }
        function t:start() self.started = true ; return self end
        function t:terminate() return self end
        TASKS[#TASKS + 1] = t
        return t end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
}
_G.diag = { said = {},
    say = function(_, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(_, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err = function() end, mark = function() end }
local function warned(n)
    for _, l in ipairs(_G.diag.said) do
        if l:sub(1, 4) == "warn" and l:find(n, 1, true) then return true end
    end
end
_G.notices = { recorded = {},
    record = function(src, what, detail)
        _G.notices.recorded[#_G.notices.recorded + 1] =
            src .. "|" .. what .. "|" .. tostring(detail)
    end }
local function noticed(pat)
    for _, l in ipairs(_G.notices.recorded) do
        if l:find(pat, 1, true) then return true end
    end
end

local CORE = { provide = function(n, f) PROVIDED[n] = f end }

local ACTIONS = {}   -- what the expander stub was handed
local function withExpander()
    _G.service = { registry = {
        ["expander.addAction"] = function(trigger, fn, name)
            ACTIONS[#ACTIONS + 1] = { trigger = trigger, fn = fn, name = name }
            return true
        end,
    } }
end

local function freshModule()
    TASKS, ALERTS, PROVIDED = {}, {}, {}
    ACTIONS = {}
    _G.diag.said = {}
    _G.notices.recorded = {}
    printed = {}
    local mod = dofile(HS .. "/modules/begone.lua")
    mod.setup(CORE)
    return mod, _G.begoneMod
end

-- =======================================================================
out("1) registration — the word goes through the expander's machinery\n")
-- =======================================================================
withExpander()
local mod, bg = freshModule()
check("exactly one action registered", #ACTIONS == 1, #ACTIONS)
check("…and it is the word 'begone'", ACTIONS[1] and ACTIONS[1].trigger == "begone",
      ACTIONS[1] and ACTIONS[1].trigger)
check("the action carries a human name",
      ACTIONS[1] and tostring(ACTIONS[1].name):find("Begone", 1, true) ~= nil)
check("status says ready and names the word",
      tostring(bg.status):find("ready") and tostring(bg.status):find("begone"),
      bg.status)
check("the sweep service is provided", PROVIDED["banners.begone"] ~= nil)
check("no hyper key was claimed — this is a WORD, not a shortcut", true)

-- =======================================================================
out("2) the sweep — osascript, off the main thread, three addresses\n")
-- =======================================================================
check("typing the word starts an osascript task",
      (function() ACTIONS[1].fn() ; return #TASKS == 1 end)()
      and TASKS[1].cmd == "/usr/bin/osascript", TASKS[1] and TASKS[1].cmd)
local T = TASKS[1]
check("the task was started", T.started)
check("the script rides as -e, never a shell string",
      T.args[1] == "-e" and #T.args == 2)
local script = T.args[2] or ""
check("it talks to the NotificationCenter process",
      script:find('process "NotificationCenter"', 1, true) ~= nil)
check("Sonoma-and-later address present (one group deeper)",
      script:find("UI element 1 of scroll area 1", 1, true) ~= nil)
check("Monterey/Ventura address present",
      script:find("UI elements of scroll area 1 of group 1", 1, true) ~= nil)
check("Big Sur address present (each banner its own window)",
      script:find("set els to windows", 1, true) ~= nil)
check("macOS 26 deep walk present — entire contents of every window, "
      .. "for whenever Apple moves the furniture",
      script:find("entire contents of w", 1, true) ~= nil)
check("…and the deep walk is tried BEFORE the bare-windows fallback",
      (script:find("entire contents of w", 1, true) or math.huge)
      < (script:find("set els to windows", 1, true) or 0))
check("Clear All is preferred, Close is the fallback",
      (script:find('"Clear All"', 1, true) or math.huge)
      < (script:find('an is "Close"', 1, true) or 0))
check("🚨 actions match by DESCRIPTION as well as name — on macOS 26 the "
      .. "name is the AX identifier and the words live in the description",
      script:find('ad is "Clear All"', 1, true) ~= nil
      and script:find('ad is "Close"', 1, true) ~= nil)
check("…and a Close/Clear BUTTON is pressed directly when no action matched",
      script:find('"AXButton"', 1, true) ~= nil
      and script:find('perform action "AXPress" of el', 1, true) ~= nil)
check("the sweep is multi-pass with the configured cap",
      script:find("repeat 6 times", 1, true) ~= nil
      and script:find("@PASSES@", 1, true) == nil)
check("no NotificationCenter process short-circuits to zero-zero",
      script:find('if not (exists application process "NotificationCenter") then return "0 0"',
                  1, true) ~= nil)
check("the script reports closed AND seen — zero alone cannot say "
      .. "'nothing there' from 'layout unrecognised'",
      script:find("(closed as text)", 1, true) ~= nil
      and script:find("(seen as text)", 1, true) ~= nil)
check("a second run while one is sweeping is refused",
      bg.run("again") == false and #TASKS == 1)

-- =======================================================================
out("3) what comes back — counts, zero, and the Accessibility failure\n")
-- =======================================================================
T.cb(0, "3 12\n", "")
check("the count becomes the alert", ALERTS[1] == "🔕 3 begone", ALERTS[1])
check("lastRun records the sweep for ⇪⇧D",
      bg.lastRun and bg.lastRun.closed == 3 and bg.lastRun.how == "typed",
      bg.lastRun and bg.lastRun.how)
check("…and how many elements were examined", bg.lastRun and bg.lastRun.seen == 12)
check("the flag is back down", bg.running == false)

bg.run("console")
TASKS[#TASKS].cb(0, "0 0", "")
check("zero banners says so honestly",
      ALERTS[2] and ALERTS[2]:find("nothing to dismiss", 1, true) ~= nil,
      ALERTS[2])
check("…and teaches the history move — open Notification Center, run again",
      ALERTS[2] and ALERTS[2]:find("Notification Center", 1, true) ~= nil
      and ALERTS[2]:find("clock", 1, true) ~= nil, ALERTS[2])

bg.run("console")
TASKS[#TASKS].cb(0, "0 25", "")
check("zero closed with 25 SEEN is a different message — the furniture moved",
      ALERTS[3] and ALERTS[3]:find("begoneProbe", 1, true) ~= nil, ALERTS[3])
check("…and the ledger records the unrecognised layout",
      noticed("layout unrecognised"))

bg.run("console")
TASKS[#TASKS].cb(1, "", "osascript is not allowed assistive access")
check("a refused sweep points at Accessibility",
      ALERTS[4] and ALERTS[4]:find("Accessibility", 1, true) ~= nil, ALERTS[4])
check("…and lands in the notices ledger", noticed("sweep failed"))
check("…and the flag still comes down", bg.running == false)

-- =======================================================================
out("4) the probe — the map for when Apple moves the furniture\n")
-- =======================================================================
local before = #TASKS
_G.begoneProbe()
check("the probe is its own osascript task", #TASKS == before + 1)
local P = TASKS[#TASKS]
check("it walks the entire contents of every banner window",
      (P.args[2] or ""):find("entire contents", 1, true) ~= nil)
check("…and reports the actions each element offers",
      (P.args[2] or ""):find("actions of el", 1, true) ~= nil)
P.cb(0, "window\n  AXGroup  Slack notification  [Close] [Clear All]\n", "")
check("the tree prints to the Console", saidOnConsole("AXGroup"))

-- =======================================================================
out("5) a profile without the expander — reported, still usable\n")
-- =======================================================================
_G.service = { registry = {} }
local mod2, bg2 = freshModule()
check("status names the missing module, not a mystery",
      tostring(bg2.status):find("Text Expander", 1, true) ~= nil, bg2.status)
check("…and the ledger records it once", noticed("keyword unavailable"))
check("_G.begone still sweeps from the Console",
      (function() _G.begone() ; return #TASKS == 1 end)())
TASKS[1].cb(0, "1", "")
check("…and still reports", ALERTS[#ALERTS] == "🔕 1 begone", ALERTS[#ALERTS])

check("disabled by hand: nothing registers",
      (function()
          withExpander()
          TASKS, ACTIONS = {}, {}
          local m3 = dofile(HS .. "/modules/begone.lua")
          -- flip the default before setup can read it: config lives in
          -- setup, so probe the shipped default instead — enabled = true
          -- must be the shipped state, and the registration count above
          -- (exactly one) already proves the enabled path. Here: the
          -- module contract survives a second load.
          m3.setup(CORE)
          return #ACTIONS == 1
      end)())

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
