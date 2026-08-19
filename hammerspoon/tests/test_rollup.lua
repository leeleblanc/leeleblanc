-- =====================================================================
-- test_rollup.lua — 📊 the 16:01 daily card. 6.105.0
-- =====================================================================
--     lua5.4 test_rollup.lua [/path/to/hammerspoon]
--
-- The rollup's whole claim is that it STORES NOTHING and derives every
-- line from a service another module already provides. So this suite
-- checks the claim rather than the drawing:
--
--   R1  every section comes from a service, and a MISSING service reads
--       differently from an empty one. "You did no work today" and "the
--       module that counts your work did not load" must never look the
--       same, because one of them is a fact about you and the other is a
--       fact about the config.
--   R2  an empty day draws NOTHING on the timer and something honest on
--       demand — a card that says "nothing to report" is a card you learn
--       to dismiss unread, and then you dismiss the one that mattered.
--   R3  the card cannot take the keyboard. It is a canvas, not a chooser,
--       and clickActivating(false) is the reason the whole module is
--       built this way.
--   R4  showing it twice does not leave the first fade timer running to
--       hide the second card early.
--   R5  nothing it does writes a file.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        io.write("   ❌ " .. failures[#failures] .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a Mac in tables --------------------------------------------------
local printed, WRITES = {}, {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function printedHas(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return true end end
end

-- 🚨 io.open IS WATCHED, NOT STUBBED AWAY. R5's claim is that this module
-- writes nothing; the only way to check that is to notice if it tries.
local realopen = io.open
io.open = function(path, mode)
    if mode and mode:find("[wa]") then
        WRITES[#WRITES + 1] = path
        return { write = function() end, close = function() end }
    end
    return nil
end

local CANVASES, TIMERS, SHOWN = {}, {}, {}
local canvasFails = false

local function newCanvas(frame)
    if canvasFails then error("hs.canvas.new refused") end
    local c = {
        frameSet = frame, deleted = false, level = nil,
        clickActivating = nil, mouseEvents = nil, mouseCB = nil,
    }
    setmetatable(c, { __index = function(_, k) return rawget(c, k) end })
    function c:frame(f) if f then self.frameSet = f end return self.frameSet end
    function c:delete() self.deleted = true end
    function c:show() SHOWN[#SHOWN + 1] = self end
    function c:level(l) self.levelSet = l end
    function c:clickActivating(v) self.clickActivatingSet = v end
    function c:canvasMouseEvents(a, b, d, e) self.mouseEvents = { a, b, d, e } end
    function c:mouseCallback(f) self.mouseCB = f end
    function c:minimumTextSize(_, text)
        local lines = 1
        for _ in tostring(text):gmatch("\n") do lines = lines + 1 end
        return { w = 300, h = lines * 15 }
    end
    CANVASES[#CANVASES + 1] = c
    return c
end

local NOW = os.time({ year = 2026, month = 8, day = 19, hour = 16, min = 1 })
hs = {
    canvas = { new = newCanvas },
    screen = { primaryScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1600, h = 1000 } end }
    end },
    timer = {
        doAt = function(at, rep, fn)
            local t = { at = at, rep = rep, fn = fn, stopped = false,
                        stop = function(self) self.stopped = true end }
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAfter = function(secs, fn)
            local t = { after = secs, fn = fn, stopped = false,
                        stop = function(self) self.stopped = true end }
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    alert = { show = function() end },
}

_G.diag = { say = function() end, warn = function() end }

-- The registry, for real: has() before call() is the contract the module
-- claims to follow, so the stub answers honestly about what exists.
local PROVIDERS = {}
_G.service = {
    has  = function(n) return PROVIDERS[n] ~= nil end,
    call = function(n, ...) return PROVIDERS[n](...) end,
}
local SAFE_SHOWN = 0
_G.showCanvasSafely = function(c) SAFE_SHOWN = SAFE_SHOWN + 1 SHOWN[#SHOWN + 1] = c end

local CORE = {
    formatDuration = function(s)
        if s < 60 then return s .. "s" end
        local m = math.floor(s / 60)
        if m < 60 then return m .. "m" end
        return math.floor(m / 60) .. "h " .. (m % 60) .. "m"
    end,
    provide = function(n, fn) PROVIDERS[n] = fn end,
}

local TODAY = os.date("%Y-%m-%d", NOW)

local function fullDay()
    PROVIDERS["activity.dayTotals"] = function()
        return { date = TODAY, total = 7200, apps = {
            { name = "Microsoft Word", seconds = 3600 },
            { name = "Google Chrome",  seconds = 2400 },
            { name = "Slack",          seconds = 1200 },
        } }
    end
    PROVIDERS["activity.docs"] = function()
        return {
            { date = TODAY, file = "Report Q3.docx", secs = 3600 },
            { date = TODAY, file = "Budget.xlsx",    secs = 900  },
            { date = "2026-08-14", file = "Old.docx", secs = 60  },
        }
    end
    PROVIDERS["notes.today"] = function()
        return {
            { at = TODAY .. " 09:12", kind = "Logs",  text = "kicked off the migration" },
            { at = TODAY .. " 14:40", kind = "Ideas", text = "fold the snippets into one table" },
        }
    end
end

-- =====================================================================
out("── test_rollup (config at " .. HS .. ")\n")

local M = dofile(HS .. "/modules/daily_rollup.lua")
out("\n=== R0. The module contract ===\n")
check("it is a table with name, order and setup",
      type(M) == "table" and M.name and M.order and type(M.setup) == "function")
check("it declares a family and a cheat sheet",
      M.family == "time" and M.cheatsheet and M.cheatsheet.title
      and #M.cheatsheet.entries > 0)
check("...and its order does not collide with the Menu Bar module's 13.9",
      M.order ~= 13.9, M.order)

fullDay()
M.setup(CORE)
local roll = _G.dailyRollup
check("setup published the module table", type(roll) == "table")
check("...and armed ONE daily timer at its configured time",
      #TIMERS == 1 and TIMERS[1].at == "16:01" and TIMERS[1].rep == "1d",
      #TIMERS .. " timer(s)")
check("...held in a global, so it cannot be collected before it fires",
      _G.dailyRollupTimer == TIMERS[1])
check("_G.rollup() is reachable from the Console",
      type(_G.rollup) == "function")

-- =====================================================================
out("\n=== R1. Every line is derived — and a missing store SAYS SO ===\n")
local text, anything = roll.text()
check("the day's total appears", text:find("2h", 1, true) ~= nil, text)
check("the top apps appear, biggest first",
      text:find("Microsoft Word") < text:find("Google Chrome"), text)
check("today's documents appear", text:find("Report Q3.docx", 1, true) ~= nil)
check("🚨 and YESTERDAY's do not — this is a card about today",
      text:find("Old.docx", 1, true) == nil, text)
check("the notes are counted by kind",
      text:find("1 Ideas", 1, true) and text:find("1 Logs", 1, true), text)
check("...and the most recent one is quoted",
      text:find("fold the snippets", 1, true) ~= nil)
check("the day is not empty", anything == true)

-- The distinction the whole design turns on.
PROVIDERS["activity.dayTotals"] = nil
local missingText, missingAnything = roll.text()
check("a MISSING store says it is not answering",
      missingText:find("not answering", 1, true) ~= nil, missingText)
check("...and is NOT treated as an empty day, because it is not one",
      missingAnything == true)

fullDay()
PROVIDERS["activity.dayTotals"] = function()
    return { date = TODAY, total = 0, apps = {} }
end
local zeroText = roll.text()
check("a store that answers ZERO reads as nothing tracked, not as broken",
      zeroText:find("nothing tracked", 1, true) ~= nil
      and zeroText:find("not answering", 1, true) == nil, zeroText)

-- A provider that throws is a third case again: it exists, and it failed.
PROVIDERS["activity.docs"] = function() error("the CSV is a directory") end
local throwText = roll.text()
check("a provider that THROWS is caught and reported, not crashed through",
      throwText:find("not answering", 1, true) ~= nil, throwText)

-- =====================================================================
out("\n=== R2. An empty day is silent on the timer, honest on demand ===\n")
PROVIDERS["activity.dayTotals"] = function()
    return { date = TODAY, total = 0, apps = {} }
end
PROVIDERS["activity.docs"]  = function() return {} end
PROVIDERS["notes.today"]    = function() return {} end

local _, emptyAnything = roll.gather()
check("gather() reports the day as empty", emptyAnything == false)

CANVASES, SHOWN, SAFE_SHOWN = {}, {}, 0
check("the 16:01 fire draws NOTHING on an empty day", roll.fire() == false)
check("...and really drew nothing", #CANVASES == 0 and #SHOWN == 0)

check("_G.rollup() on the same empty day DOES draw", roll.show() == true)
check("...and says so in plain words",
      (roll.text()):find("A quiet one", 1, true) ~= nil, roll.text())

-- =====================================================================
out("\n=== R3. It cannot take the keyboard ===\n")
fullDay()
roll.hide()
CANVASES, SHOWN, SAFE_SHOWN = {}, {}, 0
check("show() draws a card", roll.show() == true and #CANVASES == 1)
local card = CANVASES[1]
check("🚨 clickActivating(false) — typing carries on in the app you were in",
      card.clickActivatingSet == false, tostring(card.clickActivatingSet))
check("it accepts a click so it can be dismissed early",
      card.mouseEvents and card.mouseEvents[1] == true)
check("...and that click hides it",
      (function() card.mouseCB() return roll.card == nil and card.deleted end)())
check("it went up through showCanvasSafely, not a bare :show()",
      SAFE_SHOWN == 1, SAFE_SHOWN)
check("it sits at the overlay level", card.levelSet == "overlay")
check("...anchored top-right of the screen it was drawn on",
      (function()
         roll.show()
         local f = CANVASES[#CANVASES].frameSet
         -- screen is 1600 wide at x=0, so the right edge of the card sits
         -- offsetX in from the right edge of the screen
         return f.x == 1600 - roll.width - roll.offsetX
                and f.y == roll.offsetY
       end)(), CANVASES[#CANVASES] and CANVASES[#CANVASES].frameSet.x)

check("a canvas that cannot be created is reported, not swallowed",
      (function()
         roll.hide()
         canvasFails, printed = true, {}
         local ok = roll.show()
         canvasFails = false
         -- the numbers still exist, so they go somewhere
         return ok == false and printedHas("TIME")
       end)(), table.concat(printed, " | "):sub(1, 80))

-- =====================================================================
out("\n=== R4. Two cards in a row do not fight over one fade timer ===\n")
roll.hide()
TIMERS = {}
roll.show()
local firstFade = TIMERS[1]
check("showing once arms one fade timer",
      #TIMERS == 1 and firstFade.after == roll.holdSecs, #TIMERS)
roll.show()
check("🚨 showing again STOPS the first one, so it cannot hide the second",
      firstFade.stopped == true and #TIMERS == 2)
check("...and the second fade timer is live", TIMERS[2].stopped == false)
TIMERS[2].fn()
check("when it fires, the card goes", roll.card == nil)

-- =====================================================================
out("\n=== R5. It stores nothing ===\n")
check("not one file was opened for writing in any of the above",
      #WRITES == 0, table.concat(WRITES, ", "))

-- =====================================================================
io.open = realopen
out(string.format("\n── test_rollup: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, x in ipairs(failures) do out("   ❌ " .. x .. "\n") end
    os.exit(1)
end
os.exit(0)
