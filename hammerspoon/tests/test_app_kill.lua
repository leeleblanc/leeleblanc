-- =====================================================================
-- test_app_kill.lua — ⇪⇧; lists processes and ends the right one
-- =====================================================================
--     lua5.4 test_app_kill.lua [/path/to/hammerspoon]
--
-- Executes modules/app_kill.lua against a stubbed hs.
--
-- TWO SECTIONS HAVE TEETH:
--
--   §2 THE TWO-ps JOIN. `comm` and `args` both contain spaces, so asking
--      for both in one ps row leaves no separator a pattern can find:
--      /Applications/Some App.app/Contents/MacOS/Some App has nothing in
--      it to split on. Two calls, each anchored to end-of-line, joined on
--      pid. The fixture deliberately contains a path with spaces, so a
--      single-call implementation fails here rather than mangling the
--      name of every app you actually want to quit.
--
--   §4 THE REFUSALS ARE ABSOLUTE. kill -9 on WindowServer logs you out,
--      every app, no save prompt. The refusal must hold under ⌥ as well,
--      because ⌥ is the "I mean it" modifier and this is the one place
--      where meaning it is not enough.
--
--   §9 THE TIERS (6.159.0). LL: "identifies anything running, that I
--      can kill, but that will not crash my MacBook." The fixture holds
--      one of everything the rail must tell apart: root's daemons, a
--      user-owned loginwindow, Finder and Dock, cfprefsd and tccd, an
--      Apple app in /System/Applications, a Homebrew daemon and a bare
--      /usr/bin command — and each is pinned to its tier by value.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local EXECUTED = {}       -- every hs.execute command, in order
local ALERTS   = {}
local NOW      = 1000
local CHOOSERS = {}
local SHOWS    = 0
local MODS     = {}
local KILLED   = {}       -- every app:kill()
local SELF_PID = 4242

-- ps -Ao pid=,uid=,user=,%cpu=,rss=,comm=   — note the path WITH SPACES
-- on Chrome, and the comma decimal separator on Ghostty, which some
-- locales emit. 6.159.0 added uid and user in front, and one row of
-- everything the tier rail has to tell apart.
local PS_COMM = [[
  501  501 lee            12.5  180224 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
  777    0 root            0.0    2048 /usr/libexec/kernel_task
  888  501 lee             3.2   65536 /Applications/Some App.app/Contents/MacOS/Some App
  999  501 lee             1,5   40960 /Applications/Ghostty.app/Contents/MacOS/ghostty
    1    0 root            0.1    1024 /sbin/launchd
  123   88 _windowserver  55.0  900000 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
 4242  501 lee             2.0   50000 /Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon
  200  501 lee             0.2   30000 /System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow
  300  501 lee             0.4   90000 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
  301  501 lee             0.3   70000 /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock
  310  501 lee             0.0    5000 /usr/sbin/cfprefsd
  311  501 lee             0.0    6000 /System/Library/PrivateFrameworks/TCC.framework/Support/tccd
  320    0 root            9.0  120000 /System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores
  330  501 lee             0.1    8000 /opt/homebrew/opt/syncthing/bin/syncthing
  331  501 lee             0.0    3000 /usr/bin/caffeinate
  340  501 lee             0.5   40000 /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
  202  202 _coreaudiod     1.0   20000 /usr/sbin/coreaudiod
]]
local PS_ARGS = [[
  501 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --type=renderer --lang=en
  777 kernel_task
  888 /Applications/Some App.app/Contents/MacOS/Some App
  999 ghostty
    1 /sbin/launchd
  123 /System/.../WindowServer -daemon
 4242 /Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon
  200 /System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow console
  300 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
  301 /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock
  310 /usr/sbin/cfprefsd agent
  311 /System/Library/PrivateFrameworks/TCC.framework/Support/tccd
  330 /opt/homebrew/opt/syncthing/bin/syncthing serve --no-browser
  331 caffeinate -di
  340 /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
  202 /usr/sbin/coreaudiod
]]
local PROCS = 17

local GUI_PIDS = { [501] = "Google Chrome", [888] = "Some App", [999] = "Ghostty",
                   [200] = "loginwindow", [300] = "Finder", [301] = "Dock",
                   [340] = "Terminal" }

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    execute = function(cmd)
        EXECUTED[#EXECUTED + 1] = cmd
        if cmd:find("comm=", 1, true) then return PS_COMM end
        if cmd:find("args=", 1, true) then return PS_ARGS end
        return ""
    end,
    processInfo = { processID = SELF_PID },
    timer = { secondsSinceEpoch = function() return NOW end },
    eventtap = { checkKeyboardModifiers = function() return MODS end },
    application = {
        runningApplications = function()
            local out2 = {}
            for pid, name in pairs(GUI_PIDS) do
                out2[#out2 + 1] = {
                    pid  = function() return pid end,
                    name = function() return name end,
                }
            end
            return out2
        end,
        applicationForPID = function(pid)
            if not GUI_PIDS[pid] then return nil end
            return { kill = function() KILLED[#KILLED + 1] = pid end }
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "", query_ = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/app_kill.lua"))
local M = chunk()
M.setup(CORE)
local ak = _G.appKill

local function reset()
    EXECUTED, ALERTS, KILLED = {}, {}, {}
    MODS = {}
    ak.cache, ak.quitAt, ak.ended, ak.lastNote = nil, {}, {}, nil
end

local function rowNamed(rows, name)
    for _, r in ipairs(rows) do if r.name == name then return r end end
    return nil
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "App Kill")
check("it declares a family", M.family == "config")
check("⇪⇧; is bound", BOUND["shift+;"] ~= nil)
check("the binding is attributed to this module",
      BOUND["shift+;"] and BOUND["shift+;"].src == "app kill")
check("it publishes _G.appKill", type(ak) == "table")
check("two services are published",
      PROVIDED["kill.show"] and PROVIDED["kill.report"])
check("the cheat sheet key cell is exactly ⇪⇧;", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪⇧;" then return true end
    end
    return false
end)())

-- =====================================================================
out("\n=== 2. 🚨 THE TWO-ps JOIN, INCLUDING PATHS WITH SPACES ===\n")
-- =====================================================================
local by = ak.parse(PS_COMM, PS_ARGS)
check("every process was parsed", (function()
    local n = 0 ; for _ in pairs(by) do n = n + 1 end ; return n
end)() == PROCS, (function()
    local n = 0 ; for _ in pairs(by) do n = n + 1 end ; return n
end)())
check("6.159.0 — the owner is read too: uid and user, in front of the "
      .. "columns that hold spaces", by[123] and by[123].uid == 88
      and by[123].user == "_windowserver" and by[501].uid == 501
      and by[501].user == "lee", by[123] and by[123].user)

-- 🚨 The reason there are two ps calls at all. A single call ending in
-- both comm and args has no separator between them that a pattern can
-- find, and "Google Chrome" becomes "Google" with "Chrome" in the CPU
-- column. This check fails the moment somebody merges them.
check("a path WITH SPACES keeps its whole name",
      by[501] and by[501].name == "Google Chrome", by[501] and by[501].name)
check("…and its whole path", by[501]
      and by[501].path == "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      by[501] and by[501].path)
check("a second spaced path too",
      by[888] and by[888].name == "Some App", by[888] and by[888].name)
check("CPU is read as a number", by[501] and by[501].cpu == 12.5, by[501] and by[501].cpu)
check("RSS is read as a number", by[501] and by[501].rss == 180224)
-- 🚨 Some locales report %CPU with a comma. LL's own Ruby matched
-- [\.|\,] for exactly this; tonumber does not.
check("🚨 a COMMA decimal separator parses as a number, not nil",
      by[999] and by[999].cpu == 1.5, by[999] and by[999].cpu)
check("the command line is joined on from the second ps",
      by[501] and by[501].args
      and by[501].args:find("--type=renderer", 1, true) ~= nil,
      by[501] and by[501].args)
check("…and a process the second ps did not mention still parses",
      by[123] ~= nil)

-- =====================================================================
out("\n=== 3. GUI apps first, then the hottest ===\n")
-- =====================================================================
reset()
local rows = ak.scan(true)
check("the scan returns every process", #rows == PROCS, #rows)
check("a GUI app is marked as one", rowNamed(rows, "Google Chrome").gui == true)
check("…and a daemon is not", rowNamed(rows, "launchd").gui ~= true)
-- 6.159.0: the tiers order the list (§9); inside the tier you can end,
-- the old promise holds — GUI apps first, hottest first.
check("GUI apps you can end come first — that is what you opened this for",
      (function()
    local seenNonGui = false
    for _, r in ipairs(rows) do
        if r.tier ~= "yours" then break end
        if not r.gui then seenNonGui = true
        elseif seenNonGui then return false end
    end
    return true
end)())
check("…and inside the GUI block, hottest first",
      rows[1].name == "Google Chrome", rows[1].name)
check("…and inside the rest of each tier too, hottest first", (function()
    local last = {}
    for _, r in ipairs(rows) do
        if not r.gui then
            if last[r.tier] and r.cpu > last[r.tier] then return false, r.name end
            last[r.tier] = r.cpu
        end
    end
    return true
end)())
check("the GUI name comes from hs.application, not the executable",
      rowNamed(rows, "Ghostty") ~= nil and rowNamed(rows, "ghostty") == nil)
check("the scan was timed", ak.scanMs ~= nil)

-- =====================================================================
out("\n=== 4. 🚨 THE REFUSALS HOLD, INCLUDING UNDER ⌥ ===\n")
-- =====================================================================
-- 6.159.0 widened the list: the four names, plus everything the tier
-- rail locks — loginwindow is YOURS by owner and still refused; cfprefsd
-- and tccd are yours and part of macOS; mds_stores and coreaudiod are
-- root's.
for _, name in ipairs({ "launchd", "kernel_task", "WindowServer", "loginwindow",
                        "cfprefsd", "tccd", "mds_stores", "coreaudiod" }) do
    reset()
    local rows2 = ak.scan(true)
    local r = rowNamed(rows2, name)
    check(name .. " is present in the list at all — it is not hidden", r ~= nil)
    if r then
        check(name .. " has a refusal reason", ak.refusalFor(r) ~= nil)
        check(name .. " cannot be quit", ak.endIt(r, false) == false)
        -- 🚨 ⌥ is the "I mean it" modifier. This is the one place where
        -- meaning it is not enough.
        check("🚨 " .. name .. " cannot be FORCED either",
              ak.endIt(r, true) == false)
        check("…and no kill reached the shell", (function()
            for _, c in ipairs(EXECUTED) do
                if c:find("kill", 1, true) then return false end
            end
            return true
        end)(), table.concat(EXECUTED, " | "))
        check("…and the refusal explains itself on screen",
              ALERTS[1] and ALERTS[1]:find("refused", 1, true) ~= nil, ALERTS[1])
    end
end

reset()
local rowsSelf = ak.scan(true)
local me = rowNamed(rowsSelf, "Hammerspoon")
check("Hammerspoon refuses to quit itself", me and ak.endIt(me, true) == false)
check("…because you would lose ⇪ with no sign it worked",
      me and ak.refusalFor(me):find("no sign it worked", 1, true) ~= nil,
      me and ak.refusalFor(me))

-- =====================================================================
out("\n=== 5. quit is polite, ⌥ is not ===\n")
-- =====================================================================
reset()
local rows3 = ak.scan(true)
local chrome = rowNamed(rows3, "Google Chrome")
check("a polite quit on a GUI app goes through hs.application",
      ak.endIt(chrome, false) == true and #KILLED == 1 and KILLED[1] == 501,
      #KILLED)
check("…and NOT through kill -9", (function()
    for _, c in ipairs(EXECUTED) do
        if c:find("-9", 1, true) then return false end
    end
    return true
end)(), table.concat(EXECUTED, " | "))
check("…the time it was asked is remembered", ak.quitAt[501] ~= nil)
check("…it is recorded in the session log", #ak.ended == 1
      and ak.ended[1].how == "asked to quit", ak.ended[1] and ak.ended[1].how)
check("…and the cached list is dropped, because it is stale now",
      ak.cache == nil)

reset()
rows3 = ak.scan(true)
chrome = rowNamed(rows3, "Google Chrome")
check("a FORCE is kill -9", ak.endIt(chrome, true) == true and (function()
    for _, c in ipairs(EXECUTED) do
        if c:find("/bin/kill %-9 501") then return true end
    end
    return false
end)(), table.concat(EXECUTED, " | "))
check("…and does NOT ask the app nicely first", #KILLED == 0, #KILLED)
check("…recorded as forced", ak.ended[1] and ak.ended[1].how == "forced")

reset()
rows3 = ak.scan(true)
local ws = rowNamed(rows3, "launchd")   -- a non-GUI, non-refused case
local daemon = rowNamed(rows3, "Some App")
check("a non-GUI process is signalled with plain kill", (function()
    -- kernel_task/launchd/WindowServer are all refused, so use the one
    -- daemon-shaped row that is not: force it and check the command.
    ak.endIt(daemon, true)
    for _, c in ipairs(EXECUTED) do
        if c:find("/bin/kill %-9 888") then return true end
    end
    return false
end)(), table.concat(EXECUTED, " | "))

-- =====================================================================
out("\n=== 6. picking a process that ignored the quit forces it ===\n")
-- =====================================================================
reset()
ak.show()
local c = CHOOSERS[#CHOOSERS]
check("the panel opened with every process", #c.choices_ == PROCS, #c.choices_)

local chromeIdx
for i, r in ipairs(ak.rows) do if r.name == "Google Chrome" then chromeIdx = i end end
MODS = {}
c.cb({ idx = chromeIdx })
check("the first pick asks politely", #KILLED == 1, #KILLED)

-- Same process, still running, inside the window: this time it is forced.
ak.rows = ak.scan(true)
for i, r in ipairs(ak.rows) do if r.name == "Google Chrome" then chromeIdx = i end end
EXECUTED = {}
c.cb({ idx = chromeIdx })
check("🚨 the second pick FORCES it", (function()
    for _, cmd in ipairs(EXECUTED) do
        if cmd:find("/bin/kill %-9 501") then return true end
    end
    return false
end)(), table.concat(EXECUTED, " | "))

-- …but not forever. Past forceWindow it is a polite quit again.
reset()
ak.quitAt[501] = NOW - (ak.forceWindow + 5)
ak.rows = ak.scan(true)
for i, r in ipairs(ak.rows) do if r.name == "Google Chrome" then chromeIdx = i end end
c.cb({ idx = chromeIdx })
check("…but an OLD quit does not silently arm a force",
      #KILLED == 1 and (function()
          for _, cmd in ipairs(EXECUTED) do
              if cmd:find("-9", 1, true) then return false end
          end
          return true
      end)(), table.concat(EXECUTED, " | "))

-- ⌥ held at pick time forces on the first press.
reset()
ak.show()
c = CHOOSERS[#CHOOSERS]
for i, r in ipairs(ak.rows) do if r.name == "Google Chrome" then chromeIdx = i end end
MODS = { alt = true }
EXECUTED = {}
c.cb({ idx = chromeIdx })
check("⌥ at pick time forces on the FIRST press", (function()
    for _, cmd in ipairs(EXECUTED) do
        if cmd:find("/bin/kill %-9 501") then return true end
    end
    return false
end)(), table.concat(EXECUTED, " | "))
MODS = {}

-- =====================================================================
out("\n=== 7. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
reset()
ak.show()
c = CHOOSERS[#CHOOSERS]
check("every row value is a string, number or boolean", (function()
    for _, ch in ipairs(c.choices_) do
        for k, v in pairs(ch) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false, k .. " is a " .. t
            end
        end
    end
    return true
end)())
check("…and every payload resolves to a real process", (function()
    for _, ch in ipairs(c.choices_) do
        if ak.rows[ch.idx] == nil then return false end
    end
    return true
end)())
-- The command line rides in the subtitle so typing "renderer" filters on
-- it — the replacement for the Ruby version's process:arg syntax.
check("🚨 the full command line is in the subtitle, so ‘renderer’ filters",
      (function()
    for _, ch in ipairs(c.choices_) do
        if ch.subText:find("renderer", 1, true) then return true end
    end
    return false
end)())
check("…and so are CPU, memory and pid", (function()
    for _, ch in ipairs(c.choices_) do
        if ch.text:find("Google Chrome", 1, true) then
            return ch.subText:find("CPU", 1, true)
               and ch.subText:find("MB", 1, true)
               and ch.subText:find("pid 501", 1, true)
        end
    end
    return false
end)())

-- =====================================================================
out("\n=== 8. the report tells the truth ===\n")
-- =====================================================================
reset()
local rows4 = ak.scan(true)
ak.endIt(rowNamed(rows4, "Google Chrome"), true)
local rep = _G.killReport()
check("the report names the module", rep:find("APP KILL", 1, true) ~= nil)
check("…and what it ended", rep:find("Google Chrome", 1, true) ~= nil, rep)
check("…and how", rep:find("forced", 1, true) ~= nil, rep)
reset()
rep = _G.killReport()
check("…and says plainly when nothing was ended",
      rep:find("nothing this session", 1, true) ~= nil, rep)

-- =====================================================================
out("\n=== 9. 🔒 6.159.0 — THE TIERS: yours, relaunches, locked ===\n")
-- =====================================================================
-- LL: "a 'Kill an app' tool that identifies anything running, that I can
-- kill, but that will not crash my MacBook." Owner and path decide, and
-- every kind of process in the fixture is pinned to its tier BY VALUE.
reset()
local tiers = ak.scan(true)
local function tierOf(name)
    local r = rowNamed(tiers, name)
    return r and r.tier, r and r.why
end
check("who I am is read off Hammerspoon's OWN row in the same ps — uid 501",
      ak.myUid == 501, ak.myUid)
check("an app in /Applications is YOURS", tierOf("Google Chrome") == "yours")
check("🚨 an Apple app in /System/Applications is YOURS too — Terminal is "
      .. "an app, not a system agent", tierOf("Terminal") == "yours",
      tierOf("Terminal"))
check("a Homebrew daemon is yours", tierOf("syncthing") == "yours")
check("a bare /usr/bin command you started is yours",
      tierOf("caffeinate") == "yours", tierOf("caffeinate"))
check("Finder RELAUNCHES", tierOf("Finder") == "relaunch", tierOf("Finder"))
check("…so does the Dock", tierOf("Dock") == "relaunch")
check("…and the reason says launchd brings it back",
      (select(2, tierOf("Finder")) or ""):find("launchd", 1, true) ~= nil,
      select(2, tierOf("Finder")))
check("🚨 loginwindow is YOURS BY OWNER and still LOCKED — the name wins",
      tierOf("loginwindow") == "locked", tierOf("loginwindow"))
check("🚨 cfprefsd — yours, /usr/sbin — is locked, with the path in the reason",
      tierOf("cfprefsd") == "locked"
      and (select(2, tierOf("cfprefsd")) or ""):find("/usr/sbin/", 1, true) ~= nil,
      select(2, tierOf("cfprefsd")))
check("tccd — yours, /System/Library — is locked",
      tierOf("tccd") == "locked", tierOf("tccd"))
check("🚨 root's mds_stores is locked because of WHO owns it, and the reason "
      .. "names the user and the no-admin rule",
      tierOf("mds_stores") == "locked"
      and (select(2, tierOf("mds_stores")) or ""):find("runs as root", 1, true) ~= nil
      and (select(2, tierOf("mds_stores")) or ""):find("admin", 1, true) ~= nil,
      select(2, tierOf("mds_stores")))
check("…and _coreaudiod's coreaudiod likewise",
      tierOf("coreaudiod") == "locked"
      and (select(2, tierOf("coreaudiod")) or ""):find("_coreaudiod", 1, true) ~= nil,
      select(2, tierOf("coreaudiod")))
check("WindowServer keeps its own, older reason", tierOf("WindowServer") == "locked"
      and (select(2, tierOf("WindowServer")) or ""):find("logs you out", 1, true) ~= nil)
check("Hammerspoon itself is locked", tierOf("Hammerspoon") == "locked")

check("🚨 THE LIST IS ORDERED yours → relaunch → locked, so what you can end "
      .. "is at the top and what you cannot is at the bottom", (function()
    local rank, last = { yours = 1, relaunch = 2, locked = 3 }, 0
    for _, r in ipairs(tiers) do
        local k = rank[r.tier] or 9
        if k < last then return false, r.name .. " (" .. tostring(r.tier) .. ")" end
        last = k
    end
    return true
end)())
check("…and every row HAS a tier — nothing slips through unclassified",
      (function()
    for _, r in ipairs(tiers) do
        if r.tier ~= "yours" and r.tier ~= "relaunch" and r.tier ~= "locked" then
            return false, r.name
        end
    end
    return true
end)())

-- a 🔁 row is offered, both ways
reset()
tiers = ak.scan(true)
local finder = rowNamed(tiers, "Finder")
check("Finder can be asked to quit — through hs.application, it is a GUI app",
      ak.endIt(finder, false) == true and KILLED[#KILLED] == 300, KILLED[#KILLED])
reset()
tiers = ak.scan(true)
finder = rowNamed(tiers, "Finder")
check("…and forced", ak.endIt(finder, true) == true and (function()
    for _, cmd in ipairs(EXECUTED) do
        if cmd:find("/bin/kill %-9 300") then return true end
    end
    return false
end)(), table.concat(EXECUTED, " | "))

-- the rows wear their tier
reset()
ak.show()
local cc = CHOOSERS[#CHOOSERS]
local function choiceFor(name)
    for _, ch in ipairs(cc.choices_) do
        if ch.text:find(name, 1, true) then return ch end
    end
    return nil
end
check("a 🔒 row wears the lock", choiceFor("loginwindow").text:sub(1, #"🔒") == "🔒",
      choiceFor("loginwindow").text)
check("…and LEADS with the reason, before the numbers",
      choiceFor("cfprefsd").subText:find("^🔒 part of macOS") ~= nil,
      choiceFor("cfprefsd").subText)
check("a 🔁 row wears the arrows and says it relaunches",
      choiceFor("Dock").text:sub(1, #"🔁") == "🔁"
      and choiceFor("Dock").subText:find("relaunches by itself", 1, true) ~= nil,
      choiceFor("Dock").subText)
check("a GUI app of yours wears 🖥, a daemon of yours ⚙️",
      choiceFor("Google Chrome").text:sub(1, #"🖥") == "🖥"
      and choiceFor("caffeinate").text:sub(1, #"⚙️") == "⚙️",
      choiceFor("caffeinate").text)
check("the placeholder counts each tier", cc.placeholder:find("6 you can end", 1, true) ~= nil
      and cc.placeholder:find("2 relaunch", 1, true) ~= nil
      and cc.placeholder:find("9 locked", 1, true) ~= nil, cc.placeholder)
check("…and the report says the same, and who you are",
      (function()
          local rep2 = _G.killReport()
          return rep2:find("6 yours · 2 relaunch · 9 locked", 1, true) ~= nil
             and rep2:find("uid 501", 1, true) ~= nil, rep2
      end)())

-- 🚨 the fallback: Hammerspoon's own row missing from ps
reset()
local realGetenv = os.getenv
os.getenv = function(k) if k == "USER" then return "lee" end return realGetenv(k) end
hs.processInfo.processID = 999999
tiers = ak.scan(true)
check("with no row of its own, the login name decides — and Chrome is still yours",
      ak.myUid == nil and tierOf("Google Chrome") == "yours", tierOf("Google Chrome"))
check("…and root's rows are still locked", tierOf("mds_stores") == "locked")
os.getenv = realGetenv
hs.processInfo.processID = SELF_PID
reset()

-- =====================================================================
out(("\n── test_app_kill: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
