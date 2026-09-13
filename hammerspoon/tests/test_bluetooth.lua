-- =====================================================================
-- test_bluetooth.lua — 6.216.0: ⇪⇧7 lists paired devices and ⏎ flips one
-- =====================================================================
--     lua5.4 test_bluetooth.lua [/path/to/hammerspoon]
--
-- Executes modules/bluetooth.lua against a stubbed hs. The parsers are
-- pure and are run against blueutil's and system_profiler's REAL line
-- shapes; the tasks are asserted by their argument arrays (no shell);
-- the degrade door is a stub that records what went through it; and
-- the no-blueutil path (the work Mac) is a first-class section, not a
-- footnote.
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
    local f = io.open(path, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

-- ---- the stub Mac ------------------------------------------------------
local NOW = 1000
local FILES = {}                       -- path → true when it "exists"
local TASKS, TIMERS, ALERTS, PRINTED, DEGRADED, CHOOSERS = {}, {}, {}, {}, {}, {}
local SHOWPOPUPS, PASTE, PASTE_OK, TASK_THROWS = 0, nil, true, false
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end
hs = {
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    fs = { attributes = function(p) if FILES[p] then return { mode = "file" } end return nil end },
    alert = { show = function(msg, secs) ALERTS[#ALERTS + 1] = msg end },
    task = {
        new = function(bin, cb, args)
            if TASK_THROWS then error("no task today") end
            local t = { bin = bin, cb = cb, args = args, started = false, terminated = false }
            function t:start() self.started = true; return self end
            function t:terminate() self.terminated = true; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "", shows = 0 }
            function c:choices(x) self.choices_ = x; return self end
            function c:placeholderText(x) self.placeholder = x; return self end
            function c:query(x) return self end
            function c:show() self.shows = self.shows + 1; return self end
            function c:width() return self end
            function c:searchSubText() return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
    pasteboard = { setContents = function(s) if PASTE_OK then PASTE = s end return PASTE_OK end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
    showPopup = function(c) SHOWPOPUPS = SHOWPOPUPS + 1; c.shows = c.shows + 1 end,
    degrade = function(tool, why) DEGRADED[#DEGRADED + 1] = tool .. ": " .. why; return false, why end,
}

local chunk = assert(loadfile(HS .. "/modules/bluetooth.lua"))
local M = chunk()
M.setup(CORE)
local bt = _G.bluetooth
local BLUEUTIL = "/opt/homebrew/bin/blueutil"

local function reset()
    TASKS, TIMERS, ALERTS, PRINTED, DEGRADED = {}, {}, {}, {}, {}
    SHOWPOPUPS, PASTE, PASTE_OK, TASK_THROWS = 0, nil, true, false
    bt.tasks, bt.timers, bt.running = {}, {}, nil
    bt.devices, bt.listedAt, bt.listedVia, bt.listWhy = {}, nil, nil, nil
    bt.lastAction, bt.lastNote, bt.degrades, bt.runs, bt.lastMs = nil, nil, 0, 0, nil
    bt.blueutil, bt.on = nil, true
end
local function press() return BOUND["shift+7"].fn() end
local function lastTask() return TASKS[#TASKS] end
local function has(list, needle)
    for _, s in ipairs(list) do if tostring(s):find(needle, 1, true) then return true end end
    return false
end
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local BLUEUTIL_OUT = table.concat({
    'address: 94-16-25-aa-bb-cc, connected (master, -49 dBm), not favourite, paired, name: "AirPods Pro", recent access date: 2026-09-12 17:01:02 +0000',
    'address: 5c-e9-1e-aa-bb-cc, not connected, not favourite, paired, name: "Magic Keyboard, Lee", recent access date: 2026-09-11 09:00:00 +0000',
    'address: f0-99-b6-11-22-33, not connected, not favourite, paired, name: "", recent access date: -',
}, "\n")
local PROFILER_NEW = [[
Bluetooth:

      Bluetooth Controller:
          Address: 00:11:22:33:44:55
          State: On
          Chipset: BCM_4388
      Connected:
          AirPods Pro:
              Address: 94:16:25:AA:BB:CC
              Vendor ID: 0x004C
              Minor Type: Headphones
      Not Connected:
          Magic Keyboard:
              Address: 5C:E9:1E:AA:BB:CC
              Vendor ID: 0x004C
          Bose QC35:
              Address: 04:52:C7:00:11:22
]]
local PROFILER_OLD = [[
Bluetooth:

      Apple Bluetooth Software Version: 8.0.5d7
      Devices (Paired, Configured, etc.):
          AirPods Pro:
              Address: 94-16-25-AA-BB-CC
              Major Type: Audio
              Connected: Yes
          Magic Keyboard:
              Address: 5C-E9-1E-AA-BB-CC
              Connected: No
]]

-- =====================================================================
out("1) the module and its key\n")
check("name / order / family", M.name == "Bluetooth" and M.order == 14.08 and M.family == "config")
check("⇪⇧7 is the key (mods shift, key 7)", BOUND["shift+7"] ~= nil and BOUND["shift+7"].src == "bluetooth")
check("the cheat sheet's key column names ⇪⇧7", M.cheatsheet.entries[1][1] == "⇪⇧7")
check("services: bluetooth.show / bluetooth.report", PROVIDED["bluetooth.show"] ~= nil and PROVIDED["bluetooth.report"] ~= nil)
do
    local hints = readAll(HS .. "/modules/shortcut_hints.lua") or ""
    check("hint.groups files shift+7 under This Mac (or the card never draws)",
          hints:find('%["shift%+7"%]%s*=%s*"This Mac"') ~= nil)
end

-- =====================================================================
out("2) the parsers are pure and read the real shapes\n")
do
    local list, why = bt.parseBlueutil(BLUEUTIL_OUT)
    check("blueutil: three paired devices, no why", #list == 3 and why == nil, why)
    check("blueutil: name and address are read", list[1].name == "AirPods Pro" and list[1].addr == "94-16-25-aa-bb-cc")
    check("blueutil: a name holding a comma survives (quoted field)", list[2].name == "Magic Keyboard, Lee")
    check("blueutil: 'connected (master, -49 dBm)' is connected", list[1].connected == true)
    -- MUTATION: a parser that asks line:find("connected") reads this row as connected
    check("blueutil: 'not connected' is NOT connected — the substring trap", list[2].connected == false and list[3].connected == false)
    check("blueutil: an empty name falls back to the address", list[3].name == "f0-99-b6-11-22-33")
    local none, whyNone = bt.parseBlueutil("")
    check("blueutil: nothing listed → empty list and a why", #none == 0 and whyNone ~= nil)
    local junk = bt.parseBlueutil("Error: Bluetooth is off\nusage: blueutil ...")
    check("blueutil: prose without an address is no device", #junk == 0)
    check("blueutil: nil is tolerated", #(bt.parseBlueutil(nil)) == 0)
end
do
    local list, why = bt.parseProfiler(PROFILER_NEW)
    check("profiler (Monterey+): three devices, none the controller", #list == 3 and why == nil, #list)
    check("profiler: Connected section → connected, with its Address",
          list[1].name == "AirPods Pro" and list[1].connected == true and list[1].addr == "94:16:25:AA:BB:CC")
    check("profiler: Not Connected section → not connected", list[2].name == "Magic Keyboard" and list[2].connected == false)
    check("profiler: the last device of a section is read too", list[3].name == "Bose QC35" and list[3].addr == "04:52:C7:00:11:22")
    local old = bt.parseProfiler(PROFILER_OLD)
    check("profiler (Catalina): 'Connected: Yes/No' inside a device decides",
          #old == 2 and old[1].connected == true and old[2].connected == false and old[2].addr == "5C-E9-1E-AA-BB-CC", #old)
    local none, whyNone = bt.parseProfiler("Bluetooth:\n\n      Bluetooth Controller:\n          State: Off\n")
    check("profiler: a controller with no devices → empty and a why", #none == 0 and whyNone ~= nil)
    check("profiler: nil is tolerated", #(bt.parseProfiler(nil)) == 0)
end

-- =====================================================================
out("3) with blueutil: ⇪⇧7 lists, the picker opens, ⏎ flips a device\n")
reset(); FILES[BLUEUTIL] = true
press()
check("the press resolves the binary at PRESS time", bt.bin == BLUEUTIL)
check("one task: blueutil --paired, an argument array, started",
      #TASKS == 1 and lastTask().bin == BLUEUTIL and same(lastTask().args, { "--paired" }) and lastTask().started)
check("it is held in its own slot with a killer timer", bt.tasks.list == lastTask() and bt.timers.list ~= nil and bt.timers.list.secs == bt.listSecs)
check("nothing degraded — blueutil is there", #DEGRADED == 0)
press()
check("a second press while listing is refused, no second task", #TASKS == 1 and has(ALERTS, "still running"))
lastTask().cb(0, BLUEUTIL_OUT, "")
check("the callback clears the slot, stops the timer, counts the run",
      bt.tasks.list == nil and bt.running == nil and TIMERS[1].stopped and bt.runs == 1)
check("the devices are kept, dated, and say which engine listed them",
      #bt.devices == 3 and bt.listedVia == "blueutil" and bt.listedAt ~= nil)
check("the picker opened through core.showPopup, never a bare :show()", SHOWPOPUPS == 1 and #CHOOSERS == 1 and CHOOSERS[1].shows == 1)
check("Esc can find it: _G.choosers.bluetooth", _G.choosers.bluetooth == CHOOSERS[1])
local rows = CHOOSERS[1].choices_
check("three rows, 🟢 for connected and ⚪ for not, each a toggle with its address",
      #rows == 3 and rows[1].text == "🟢 AirPods Pro" and rows[2].text == "⚪ Magic Keyboard, Lee"
      and rows[1].act == "toggle" and rows[2].addr == "5c-e9-1e-aa-bb-cc")
check("row values are scalars", type(rows[1].addr) == "string" and type(rows[1].act) == "string")
check("the placeholder says what ⏎ does", CHOOSERS[1].placeholder:find("connects or disconnects", 1, true) ~= nil)
-- ⏎ on the keyboard (not connected) → connect
CHOOSERS[1].cb(rows[2])
check("⏎ on a ⚪ row runs blueutil --connect ADDR in the act slot",
      #TASKS == 2 and lastTask().bin == BLUEUTIL and same(lastTask().args, { "--connect", "5c-e9-1e-aa-bb-cc" })
      and bt.tasks.act == lastTask() and bt.timers.act.secs == bt.actSecs)
check("…and says so at once", has(ALERTS, "Connecting Magic Keyboard, Lee"))
lastTask().cb(0, "", "")
check("exit 0 → the device reads connected and the alert says so",
      bt.devices[2].connected == true and has(ALERTS, "Connected — Magic Keyboard, Lee") and #DEGRADED == 0)
check("lastAction records it", bt.lastAction and bt.lastAction.what == "connect" and bt.lastAction.code == 0)
-- ⏎ on AirPods (connected) → disconnect
CHOOSERS[1].cb(rows[1])
check("⏎ on a 🟢 row runs --disconnect", same(lastTask().args, { "--disconnect", "94-16-25-aa-bb-cc" }))
lastTask().cb(1, "", "Failed to disconnect\n")
check("exit 1 → the door: the action, the exit code and blueutil's own words",
      has(DEGRADED, "Bluetooth: disconnect AirPods Pro failed — blueutil exit 1: Failed to disconnect"), DEGRADED[1])
check("…and the device's state is NOT flipped on a failure", bt.devices[1].connected == true)
-- a stale row
CHOOSERS[1].cb({ act = "toggle", addr = "no-such" })
check("a row whose device is gone is refused through the door, no task", has(DEGRADED, "no longer in the list") and #TASKS == 3)
CHOOSERS[1].cb(nil)
check("Esc on the picker is a cancel, nothing runs", #TASKS == 3)

-- =====================================================================
out("4) bounded: the killer timer terminates and says so\n")
reset(); FILES[BLUEUTIL] = true
press()
local t = lastTask()
bt.timers.list.fn()
check("the timer terminates the task, frees the slot and degrades with the seconds",
      t.terminated and bt.tasks.list == nil and bt.running == nil and has(DEGRADED, "did not finish within " .. bt.listSecs .. " s"))
press()
check("a fresh press after a timeout is not 'still running'", #TASKS == 2 and not has(ALERTS, "still running"))

-- =====================================================================
out("5) the list itself can fail, and the empty list is said\n")
reset(); FILES[BLUEUTIL] = true
press(); lastTask().cb(1, "", "Bluetooth is off\n")
check("a non-zero list exit goes through the door, named", has(DEGRADED, "could not list devices — blueutil exit 1: Bluetooth is off"))
check("no picker opened on a failed list", SHOWPOPUPS == 0 and bt.listWhy ~= nil)
reset(); FILES[BLUEUTIL] = true
press(); lastTask().cb(0, "", "")
check("exit 0 with no devices → an alert, no picker, no door", has(ALERTS, "No paired Bluetooth devices") and SHOWPOPUPS == 0 and #DEGRADED == 0)
reset(); FILES[BLUEUTIL] = true; TASK_THROWS = true
press()
check("hs.task.new throwing → the door, and nothing is left 'running'", has(DEGRADED, "could not start " .. BLUEUTIL) and bt.running == nil)

-- =====================================================================
out("6) WITHOUT blueutil — the work Mac — it still lists and still helps\n")
reset(); FILES[BLUEUTIL] = nil
press()
check("the absence goes through the door once, naming the install",
      #DEGRADED == 1 and DEGRADED[1]:find("blueutil not installed (brew install blueutil)", 1, true) ~= nil, DEGRADED[1])
check("the list runs system_profiler SPBluetoothDataType instead",
      lastTask().bin == bt.PROFILER and same(lastTask().args, { "SPBluetoothDataType" }))
lastTask().cb(0, PROFILER_NEW, "")
check("the devices come from the profiler", #bt.devices == 3 and bt.listedVia == "system_profiler")
local rows2 = CHOOSERS[1].choices_
check("the first row copies the install command; device rows open System Settings",
      rows2[1].act == "install" and rows2[2].act == "open" and rows2[2].text == "🟢 AirPods Pro"
      and rows2[2].subText:find("System Settings", 1, true) ~= nil)
check("the placeholder says ⏎ opens System Settings", CHOOSERS[1].placeholder:find("opens System Settings", 1, true) ~= nil)
CHOOSERS[1].cb(rows2[1])
check("⏎ on the install row puts the command on the clipboard and says so", PASTE == bt.BREW and has(ALERTS, "Copied: brew install blueutil"))
PASTE_OK = false; PASTE = nil
CHOOSERS[1].cb(rows2[1])
check("a refused pasteboard write (false, not a throw) goes through the door", has(DEGRADED, "could not put"))
CHOOSERS[1].cb(rows2[2])
check("⏎ on a device runs /usr/bin/open on the Bluetooth pane, in its own slot",
      lastTask().bin == bt.OPEN and same(lastTask().args, { bt.SETTINGS_URL }) and bt.tasks.open == lastTask())
local nBefore = #DEGRADED
lastTask().cb(0, "", "")
check("open exit 0 → nothing more said", #DEGRADED == nBefore)
CHOOSERS[1].cb(rows2[3]); lastTask().cb(1, "", "LSOpenURLsWithRole() failed\n")
check("open exit 1 → the door names it", has(DEGRADED, "System Settings did not open — open exit 1: LSOpenURLsWithRole() failed"))
local okT, whyT = bt.toggle({ name = "X", addr = "1", connected = false })
check("toggle without blueutil is refused through the door, no task", okT == false and has(DEGRADED, "cannot connect without blueutil"))

-- =====================================================================
out("7) settings: a pinned path, and off\n")
reset(); FILES[BLUEUTIL] = true
bt.blueutil = "/nowhere/blueutil"
press()
check("a settings pin that is not a file is named, and the candidates are NOT tried behind it",
      bt.bin == nil and bt.binWhy == "settings pin /nowhere/blueutil is not a file" and lastTask().bin == bt.PROFILER)
reset(); FILES["/custom/blueutil"] = true; bt.blueutil = "/custom/blueutil"
press()
check("a settings pin that exists wins", bt.bin == "/custom/blueutil" and lastTask().bin == "/custom/blueutil")
reset(); bt.on = false
local okOff, whyOff = press()
check("on = false: an alert, no task, false + why", okOff == false and whyOff == "off" and #TASKS == 0 and has(ALERTS, "off in settings"))

-- =====================================================================
out("8) the report is ONE string with three engine states\n")
reset(); FILES[BLUEUTIL] = true
local r = _G.bluetoothReport()
check("printed once, returned", #PRINTED == 1 and PRINTED[1] == r)
check("engine: installed path", r:find("engine  : " .. BLUEUTIL, 1, true) ~= nil)
check("devices: not listed yet", r:find("not listed yet", 1, true) ~= nil)
check("last: none", r:find("no connect or disconnect", 1, true) ~= nil)
press(); lastTask().cb(0, BLUEUTIL_OUT, ""); CHOOSERS[1].cb(CHOOSERS[1].choices_[2]); lastTask().cb(0, "", "")
r = _G.bluetoothReport()
check("devices: listed, via, with each row", r:find("devices : 3 via blueutil", 1, true) ~= nil and r:find("🟢 AirPods Pro", 1, true) ~= nil)
check("last: the action and ok", r:find("last    : connect Magic Keyboard, Lee", 1, true) ~= nil and r:find("— ok", 1, true) ~= nil)
reset(); FILES[BLUEUTIL] = nil
r = _G.bluetoothReport()
check("engine: not installed reads differently and names the install", r:find("blueutil not installed — listing via system_profiler", 1, true) ~= nil)
reset(); bt.blueutil = "/nowhere/blueutil"
r = _G.bluetoothReport()
check("engine: a bad pin is a ⚠️ state of its own", r:find("engine  : ⚠️ settings pin /nowhere/blueutil is not a file", 1, true) ~= nil)
reset(); FILES[BLUEUTIL] = true
press(); lastTask().cb(1, "", "off\n")
r = _G.bluetoothReport()
check("devices: a failed list is a ⚠️ line, not 'not listed yet'", r:find("devices : ⚠️ list failed", 1, true) ~= nil)

-- =====================================================================
out("9) without the door the taker prints itself; source sentries\n")
do
    local M2 = assert(loadfile(HS .. "/modules/bluetooth.lua"))()
    M2.setup({ hyperAddShortcut = function() end, provide = function() end })
    local b2 = _G.bluetooth
    PRINTED = {}
    local okF, whyF = b2.degrade("no door here")
    check("no core.degrade → a ⚠️ Console line and false, why", okF == false and whyF == "no door here" and has(PRINTED, "⚠️ Bluetooth: no door here"))
    _G.bluetooth = bt; M.setup(CORE); bt = _G.bluetooth
end
do
    local src = readAll(HS .. "/modules/bluetooth.lua") or ""
    check("SOURCE: the picker goes through core.showPopup", src:find("core.showPopup(bt.chooser)", 1, true) ~= nil)
    check("SOURCE: three task slots, each its own (6.196.1)",
          src:find('bt.run("list"', 1, true) and src:find('bt.run("act"', 1, true) and src:find('bt.run("open"', 1, true))
    check("SOURCE: no shell anywhere — argument arrays only",
          not src:find("os.execute", 1, true) and not src:find("io.popen", 1, true)
          and not src:find("hs.execute", 1, true) and not src:find("/bin/sh", 1, true))
    check("SOURCE: the door is core.degrade(\"Bluetooth\", …)", src:find('core.degrade("Bluetooth", why)', 1, true) ~= nil)
    check("SOURCE: hs.window.filter is not used", not src:find("hs.window.filter", 1, true))
end

-- =====================================================================
realPrint(string.format("\n%d passed, %d failed", pass, fail))
for _, f in ipairs(failures) do realPrint("  ✗ " .. f) end
os.exit(fail == 0 and 0 or 1)
