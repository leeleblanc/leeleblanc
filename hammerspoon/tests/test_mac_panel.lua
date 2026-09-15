-- =====================================================================
-- test_mac_panel.lua — ⇪7 draws the card, with numbers that are right
-- =====================================================================
--     lua5.4 test_mac_panel.lua [/path/to/hammerspoon]
--
-- Executes modules/mac_panel.lua against a stubbed hs.
--
-- TWO SECTIONS HAVE TEETH:
--
--   §2 THE DISK FIGURE. `df -k` reports KILOBYTES and says so in its own
--      name. hs.fs.freeSpace's unit has differed between Hammerspoon
--      versions, and no value it can return distinguishes the two — 400
--      GB in bytes and 400 GB in kilobytes are both plausible readings
--      of a real Mac. A wrong answer here is off by 1024 in the
--      direction that makes you delete things you did not need to.
--
--   §4 IT DRAWS BEFORE IT KNOWS EVERYTHING. system_profiler takes one to
--      three SECONDS. A panel that waits for it is a panel that takes
--      three seconds to appear, which is a panel you stop pressing.

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
local EXECUTED = {}
local TASKS    = {}
local TIMERS   = {}
local EVERY    = {}
local ALERTS   = {}
local CANVASES = {}
local CLIP     = nil
local CANVAS_FAILS = false

local SYSCTL = {
    ["machdep.cpu.brand_string"] = "Apple M2 Pro",
    ["hw.model"]                 = "Mac14,9",
    ["hw.ncpu"]                  = "12",
    ["hw.memsize"]               = tostring(32 * 1024 * 1024 * 1024),
    ["kern.boottime"]            = "{ sec = 1000000, usec = 0 } Mon Nov 10 09:00:00 2025",
    ["kern.hostname"]            = "lees-mac",
}
local DF = "Filesystem 1024-blocks      Used  Avail Capacity  iused ifree %iused  Mounted on\n"
        .. "/dev/disk3s1s1 971350180 21000000 412000000    35%  500000 4000000    2%   /\n"

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(s) CLIP = s end },
    execute = function(cmd)
        EXECUTED[#EXECUTED + 1] = cmd
        local name = cmd:match("sysctl %-n (%S+)")
        if name then return (SYSCTL[name] or "") .. "\n" end
        if cmd:find("df -k", 1, true) then return DF end
        if cmd:find("productVersion", 1, true) then return "26.1\n" end
        if cmd:find("buildVersion", 1, true) then return "25B74\n" end
        return ""
    end,
    host = { localizedName = function() return "Lee’s MacBook Pro" end },
    battery = {
        percentage      = function() return 87 end,
        healthCondition = function() return nil end,
        cycles          = function() return 214 end,
        isCharging      = function() return false end,
    },
    network = {
        primaryInterfaces = function() return "en0" end,
        interfaceDetails  = function()
            return { IPv4 = { Addresses = { "192.168.1.44" } } }
        end,
    },
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1920, h = 1080 } end }
    end },
    canvas = {
        windowLevels = { overlay = 102 },
        new = function(frame)
            if CANVAS_FAILS then error("no canvas") end
            local c = { frame = frame, elements = nil, level_ = nil,
                        behaviors = nil, shown = 0, deleted = false }
            function c:replaceElements(e) self.elements = e ; return self end
            function c:level(n) self.level_ = n ; return self end
            function c:behaviorAsLabels(b) self.behaviors = b ; return self end
            function c:show() self.shown = self.shown + 1 ; return self end
            function c:delete() self.deleted = true ; return self end
            CANVASES[#CANVASES + 1] = c
            return c
        end,
    },
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            EVERY[#EVERY + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args,
                        started = false, terminated = false }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.panelLevels = { cheatsheet = 0, macpanel = 1, pomodoro = 3 }
function _G.panelLevel(name) return 102 + (_G.panelLevels[name] or 0) end
local DRAGGABLE = {}
_G.makeCanvasDraggable = function(c, name) DRAGGABLE[#DRAGGABLE + 1] = name end
local SHOWN_SAFELY = 0
_G.showCanvasSafely = function(c) SHOWN_SAFELY = SHOWN_SAFELY + 1
                                  c:show() ; return true end

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
    resolveBaseScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1920, h = 1080 } end }
    end,
}

local chunk = assert(loadfile(HS .. "/modules/mac_panel.lua"))
local M = chunk()
M.setup(CORE)
local mp = _G.macPanel

local function reset()
    EXECUTED, TASKS, TIMERS, EVERY, ALERTS = {}, {}, {}, {}, {}
    mp.close()
    mp.slow = { model = nil, serial = nil }
    mp.slowTask, mp.lastNote = nil, nil
end

local function rowValue(rows, key)
    for _, r in ipairs(rows) do if r[1] == key then return r[2] end end
    return nil
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Mac Panel")
check("it declares a family", M.family == "config")
check("⇪7 is bound", BOUND["+7"] ~= nil)
check("the binding is attributed to this module",
      BOUND["+7"] and BOUND["+7"].src == "mac panel")
check("it publishes _G.macPanel", type(mp) == "table")
check("two services are published",
      PROVIDED["mac.toggle"] and PROVIDED["mac.report"])
check("the cheat sheet key cell is exactly ⇪7", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪7" then return true end
    end
    return false
end)())

-- =====================================================================
out("\n=== 2. 🚨 THE DISK FIGURE, IN THE UNIT df SAYS IT IS ===\n")
-- =====================================================================
-- 412000000 blocks of 1024 bytes = 412,000,000 KB = 392.9 GB.
-- Reading it as bytes would say "393 MB free" and send you deleting
-- things; multiplying an already-byte figure would say "393 TB".
check("🚨 df's 1024-blocks become BYTES", mp.parseDF(DF) == 412000000 * 1024,
      mp.parseDF(DF))
check("…which renders as the right order of magnitude",
      mp.freeSpace():find("GB", 1, true) ~= nil, mp.freeSpace())
-- 412,000,000 KB is 392.9 GB. Reading df's blocks as BYTES would say
-- "393 MB free"; multiplying an already-byte figure would say "393 TB".
-- Pinning the number is what distinguishes the three.
check("…and it is 392.9 GB — not 393 MB, and not 393 TB",
      mp.freeSpace() == "392.9 GB free", mp.freeSpace())
check("the header line is skipped, not parsed as a row",
      mp.parseDF("Filesystem 1024-blocks Used Avail Capacity\n") == nil)
check("garbage parses to nil rather than a number",
      mp.parseDF("no output at all") == nil)
check("nil parses to nil, not a throw", mp.parseDF(nil) == nil)

check("bytes render sensibly at each scale", (function()
    return mp.humanBytes(512) == "512 B"
       and mp.humanBytes(5 * 1024 * 1024):find("MB", 1, true)
       and mp.humanBytes(5 * 1024 ^ 3):find("GB", 1, true)
       and mp.humanBytes(5 * 1024 ^ 4):find("TB", 1, true)
end)())

-- =====================================================================
out("\n=== 3. the other numbers ===\n")
-- =====================================================================
-- kern.boottime prints "{ sec = N, usec = 0 } <a human date>". Only sec
-- is parsed: the human tail is formatted differently across macOS
-- versions and is not worth depending on.
check("uptime is read from the sec field",
      mp.uptimeFrom("{ sec = 1000, usec = 0 } Mon", 1000 + 3600 * 2 + 60 * 5)
      == "2h 5m",
      mp.uptimeFrom("{ sec = 1000, usec = 0 } Mon", 1000 + 3600 * 2 + 60 * 5))
check("…with days when there are days",
      mp.uptimeFrom("{ sec = 0, usec = 0 }", 86400 * 3 + 3600 * 4 + 60)
      == "3d 4h 1m",
      mp.uptimeFrom("{ sec = 0, usec = 0 }", 86400 * 3 + 3600 * 4 + 60))
check("…and minutes alone when that is all there is",
      mp.uptimeFrom("{ sec = 0, usec = 0 }", 300) == "5m")
check("a boottime it cannot parse is nil, not a wrong number",
      mp.uptimeFrom("something else", 1000) == nil)
check("a clock that went backwards is nil rather than negative",
      mp.uptimeFrom("{ sec = 5000, usec = 0 }", 1000) == nil)

reset()
local rows = mp.rows()
check("the chip comes from sysctl", rowValue(rows, "Chip") == "Apple M2 Pro",
      rowValue(rows, "Chip"))
check("memory is the INSTALLED RAM, in GB",
      rowValue(rows, "Memory"):find("32.0 GB", 1, true) ~= nil,
      rowValue(rows, "Memory"))
check("…with the core count beside it",
      rowValue(rows, "Memory"):find("12 cores", 1, true) ~= nil,
      rowValue(rows, "Memory"))
check("macOS carries its build number",
      rowValue(rows, "macOS") == "macOS 26.1  (25B74)", rowValue(rows, "macOS"))
-- healthCondition() returns nil when the battery is FINE, which reads
-- backwards. "Normal" is the honest rendering of "nothing to report".
check("🚨 a battery with nothing to report reads Normal, not blank",
      rowValue(rows, "Battery"):find("Normal", 1, true) ~= nil,
      rowValue(rows, "Battery"))
check("…with the percentage and the cycle count",
      rowValue(rows, "Battery"):find("87%", 1, true)
      and rowValue(rows, "Battery"):find("214 cycles", 1, true))
-- The first interface is usually lo0. A panel that confidently shows
-- 127.0.0.1 is worse than one that shows nothing.
check("🚨 the IP is the PRIMARY interface's, and names the interface",
      rowValue(rows, "Network") == "192.168.1.44   ·   en0",
      rowValue(rows, "Network"))

-- =====================================================================
out("\n=== 4. 🚨 IT DRAWS BEFORE IT KNOWS EVERYTHING ===\n")
-- =====================================================================
reset()
check("the model shows the kernel's answer IMMEDIATELY, not “reading…”",
      rowValue(mp.rows(), "Model") == "Mac14,9", rowValue(mp.rows(), "Model"))
check("…while the serial, which has no instant source, says reading",
      (function()
    mp.slowTask = { fake = true }     -- pretend the child is in flight
    local v = rowValue(mp.rows(), "Serial")
    mp.slowTask = nil
    return v == "reading…"
end)())
-- 🚨 "reading…" and "—" are DIFFERENT on purpose: the first will change,
-- the second will not, and showing one for the other leaves you waiting
-- for a number that is never coming.
check("🚨 …and once nothing is in flight it reads —, not reading…",
      rowValue(mp.rows(), "Serial") == "—", rowValue(mp.rows(), "Serial"))

reset()
check("⇪7 opens the card", mp.toggle() == true)
local c = CANVASES[#CANVASES]
check("a canvas was created", c ~= nil)
check("🚨 …and it was DRAWN on the keypress, not after the slow read",
      c.elements ~= nil and #c.elements > 2, c.elements and #c.elements)
check("…and shown through showCanvasSafely, never a bare :show()",
      SHOWN_SAFELY >= 1, SHOWN_SAFELY)
-- 🪟 Two panels at one level stack by whichever was shown last, which
-- makes "is it in front?" depend on the order you pressed the keys.
check("🚨 its level comes from _G.panelLevel, ABOVE the cheat sheet",
      c.level_ == 103, c.level_)
check("🚨 …and BELOW the pomodoro, which outranks everything",
      c.level_ < _G.panelLevel("pomodoro"), c.level_)
-- Without fullScreenAuxiliary a canvas cannot draw over a full-screen
-- app AT ALL, and the symptom is "the shortcut did nothing".
check("🚨 fullScreenAuxiliary is set, not just canJoinAllSpaces", (function()
    for _, b in ipairs(c.behaviors or {}) do
        if b == "fullScreenAuxiliary" then return true end
    end
    return false
end)(), table.concat(c.behaviors or {}, ","))
check("it is draggable", DRAGGABLE[#DRAGGABLE] == "macpanel")
check("a refresh ticker was started for the live values", #EVERY >= 1, #EVERY)

-- The slow read, arriving after the panel is already up.
local slow = nil
for _, t in ipairs(TASKS) do if t.bin == "/bin/sh" then slow = t end end
check("the slow facts are read out of process", slow ~= nil)
check("…asking system_profiler for the marketing name", slow
      and slow.args[2]:find("system_profiler", 1, true) ~= nil)
check("…and ioreg for the serial", slow
      and slow.args[2]:find("IOPlatformSerialNumber", 1, true) ~= nil)
slow.cb(0, "      Model Name: MacBook Pro\n      Model Identifier: Mac14,9\n"
        .. "      Chip: Apple M2 Pro\n"
        .. "    \"IOPlatformSerialNumber\" = \"C02ABCDEFGHI\"\n")
check("🚨 when they land, the card REDRAWS with them", (function()
    local r = mp.rows()
    return rowValue(r, "Serial") == "C02ABCDEFGHI"
end)(), rowValue(mp.rows(), "Serial"))
check("…and the model becomes the name on the box",
      rowValue(mp.rows(), "Model"):find("MacBook Pro", 1, true) ~= nil,
      rowValue(mp.rows(), "Model"))
check("…keeping the identifier beside it",
      rowValue(mp.rows(), "Model"):find("Mac14,9", 1, true) ~= nil,
      rowValue(mp.rows(), "Model"))

-- A system_profiler that never answers must not leave the card stuck.
reset()
mp.toggle()
local slowTimer = TIMERS[#TIMERS]
check("a deadline was armed for the slow read", slowTimer ~= nil)
if slowTimer then slowTimer.fn() end
check("…and it terminates the child rather than leaking it", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/bin/sh" then return t.terminated == true end
    end
    return false
end)())
check("…the card is still up, with — where the answer would have been",
      mp.canvas ~= nil and rowValue(mp.rows(), "Serial") == "—",
      rowValue(mp.rows(), "Serial"))

-- =====================================================================
out("\n=== 5. it toggles, and cleans up after itself ===\n")
-- =====================================================================
reset()
mp.toggle()
local open1 = mp.canvas
check("the first press opens", open1 ~= nil)
mp.toggle()
check("the second press closes", mp.canvas == nil)
check("…deleting the canvas rather than hiding it", open1.deleted == true)
check("…and stopping the refresh ticker", (function()
    for _, t in ipairs(EVERY) do if not t.stopped then return false end end
    return true
end)())
mp.toggle()
check("…and a third press opens a fresh one", mp.canvas ~= nil)
check("closing twice is harmless", mp.close() and mp.close())

reset()
CANVAS_FAILS = true
check("a canvas that cannot be made is a named refusal, not a throw",
      mp.toggle() == false)
check("…said on screen", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("could not open", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])
CANVAS_FAILS = false

-- =====================================================================
out("\n=== 6. the report tells the truth, and copies itself ===\n")
-- =====================================================================
reset()
CLIP = nil
local rep = _G.macReport()
check("the report names the module", rep:find("THIS MAC", 1, true) ~= nil)
check("…carries every row the card does", (function()
    for _, key in ipairs({ "Model", "Chip", "Memory", "macOS", "Serial",
                           "Uptime", "Disk", "Battery", "Network" }) do
        if not rep:find(key, 1, true) then return false, key end
    end
    return true
end)())
-- The card cannot be selected, so the report is the route to pasting
-- this into a support ticket. Copying it is the whole point.
check("🚨 …and it is on the clipboard, which is why you ran it",
      CLIP == rep, CLIP and #CLIP)

-- =====================================================================
out(("\n── test_mac_panel: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
