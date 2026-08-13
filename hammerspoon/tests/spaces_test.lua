-- =====================================================================
-- Desktop / Space mover (§X.3) — offline test suite
-- =====================================================================
-- Runs X.3 out of init.lua under a mock Hammerspoon. No Hammerspoon,
-- no macOS, no private APIs touched.
--
--     cd hammerspoon && lua5.4 tests/spaces_test.lua
--
-- This block drives hs.spaces, which wraps PRIVATE CoreGraphics calls.
-- That makes the FAILURE paths the important thing to test: the feature
-- is expected to break on some macOS/Hammerspoon combinations, and the
-- whole design promise is that it says so instead of doing nothing.
-- Most of the checks below are therefore about what happens when the
-- move does NOT work.
--
-- Exit status is 0 only if every check passes.
-- =====================================================================

ALERTS, PRINTS, HYPER = {}, {}, {}
local realprint = print
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  PRINTS[#PRINTS+1] = table.concat(p, " ")
end

-- ---------- mock window / screen ----------
local SCREEN = { id = "screen-1" }
local WIN
local function newWin(opts)
  opts = opts or {}
  return {
    _fullscreen = opts.fullscreen or false,
    _focused = 0,
    screen = function() return SCREEN end,
    focus = function(self) self._focused = self._focused + 1 end,
    isFullScreen = function(self) return self._fullscreen end,
  }
end

-- ---------- mock hs ----------
TIMERS = {}
hs = {
  alert = { show = function(m) ALERTS[#ALERTS+1] = tostring(m) end },
  timer = { doAfter = function(d, f) TIMERS[#TIMERS+1] = { d = d, f = f } end },
}
local function drainTimers()
  local q = TIMERS
  TIMERS = {}
  for _, t in ipairs(q) do t.f() end
end

-- ---------- upvalues X.3 borrows from the rest of init.lua ----------
REMEMBERED = 0
function focusedStandardWindow() return WIN end
function rememberFrame() REMEMBERED = REMEMBERED + 1 end
function guardNotFullScreen(win)
  if win:isFullScreen() then
    hs.alert.show("🪟 Full screen — exit first")
    return false
  end
  return true
end
_G.hyperAddShortcut = function(mods, key, fn, source)
  HYPER[#HYPER+1] = { mods = mods, key = key, fn = fn, source = source }
end

-- ---------- spaces mock, reconfigurable per test ----------
SP = {}
local function setSpaces(cfg)
  SP = cfg
  if cfg.absent then hs.spaces = nil; return end
  hs.spaces = {
    focusedSpace      = function() return cfg.focused end,
    spacesForScreen   = function()
      if cfg.screenThrows then error("boom") end
      return cfg.list
    end,
    spaceType         = cfg.noSpaceType and nil
                        or function(id) return (cfg.types or {})[id] or "user" end,
    moveWindowToSpace = function(w, id)
      if cfg.moveFails then error("move failed") end
      cfg.movedTo = id; return true
    end,
    gotoSpace         = function(id) cfg.wentTo = id; return true end,
  }
end

-- ---------- pull X.3 straight out of init.lua ----------
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local initPath = os.getenv("SP_INIT") or (here .. "/../init.lua")
local fh = assert(io.open(initPath, "r"), "cannot open " .. initPath)
local full = fh:read("*a"); fh:close()

local banner = full:find("X%.3 SEND A WINDOW TO ANOTHER DESKTOP")
assert(banner, "could not find the X.3 banner")
local s = full:find("%(function%(%)", banner)
local e = full:find("end%)%(%) %-%- X%.3 desktop/space mover", banner)
assert(s and e, "could not delimit the X.3 block")
local section = full:sub(s, e + #"end)() -- X.3 desktop/space mover")

local function loadBlock()
  ALERTS, PRINTS, HYPER = {}, {}, {}
  TIMERS = {}                   -- each move schedules one; don't let them pile up
  REMEMBERED = 0
  _G.spaceMoveAvailable = nil   -- clear the probe cache between loads
  assert(load(section, "@spaces-section"))()
end

-- ---------- tests ----------
local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1
  else fail = fail + 1
    realprint("  FAIL: " .. name .. (extra and ("  [" .. tostring(extra) .. "]") or "")) end
end
local function lastAlert() return ALERTS[#ALERTS] end
local function alertsMatch(sub)
  for _, a in ipairs(ALERTS) do
    if a:lower():find(sub:lower(), 1, true) then return true end
  end
  return false
end
local function fire(key)
  for _, h in ipairs(HYPER) do if h.key == key then h.fn(); return end end
  error("no binding for " .. key)
end

realprint("== bindings ==")
setSpaces({ focused = 1, list = { 1, 2, 3 } })
loadBlock()
check("two shortcuts registered", #HYPER == 2, #HYPER)
check("both on the shift tier", (function()
  for _, h in ipairs(HYPER) do
    if not (h.mods and h.mods[1] == "shift") then return false end
  end
  return true
end)())
check("] and [ are the keys", (function()
  local k = {}
  for _, h in ipairs(HYPER) do k[h.key] = true end
  return k["["] and k["]"]
end)())
check("bare brackets untouched (monitor keys keep them)", (function()
  for _, h in ipairs(HYPER) do
    if h.mods and #h.mods == 0 then return false end
  end
  return true
end)())

realprint("== moving forward and back, with wrap ==")
WIN = newWin()
setSpaces({ focused = 1, list = { 1, 2, 3 } }); loadBlock()
fire("]")
check("next moves to space 2", SP.movedTo == 2, SP.movedTo)
check("and follows the window there", SP.wentTo == 2, SP.wentTo)
check("frame remembered before the move", REMEMBERED > 0)
check("alert names the position", alertsMatch("Desktop 2 of 3"), lastAlert())

setSpaces({ focused = 3, list = { 1, 2, 3 } }); loadBlock()
fire("]")
check("next wraps 3 -> 1", SP.movedTo == 1, SP.movedTo)

setSpaces({ focused = 1, list = { 1, 2, 3 } }); loadBlock()
fire("[")
check("prev wraps 1 -> 3", SP.movedTo == 3, SP.movedTo)

setSpaces({ focused = 2, list = { 1, 2, 3 } }); loadBlock()
fire("[")
check("prev moves 2 -> 1", SP.movedTo == 1, SP.movedTo)

realprint("== focus is deferred past the Mission Control animation ==")
WIN = newWin()
setSpaces({ focused = 1, list = { 1, 2 } }); loadBlock()
fire("]")
check("focus not called synchronously", WIN._focused == 0, WIN._focused)
check("a timer was scheduled", #TIMERS == 1, #TIMERS)
check("delay is the animation, not zero", TIMERS[1] and TIMERS[1].d > 0.2, TIMERS[1] and TIMERS[1].d)
drainTimers()
check("focus lands after the delay", WIN._focused == 1, WIN._focused)

realprint("== full-screen spaces are excluded from the ordering ==")
-- Space 2 is a full-screen app. Counting it would make ] land on a
-- space no window can be moved into.
WIN = newWin()
setSpaces({ focused = 1, list = { 1, 2, 3 }, types = { [2] = "fullscreen" } })
loadBlock()
fire("]")
check("skips the full-screen space", SP.movedTo == 3, SP.movedTo)
check("count excludes it", alertsMatch("of 2"), lastAlert())

realprint("== builds with no spaceType still work ==")
WIN = newWin()
setSpaces({ focused = 1, list = { 1, 2 }, noSpaceType = true }); loadBlock()
fire("]")
check("nil spaceType treated as a real desktop", SP.movedTo == 2, SP.movedTo)

realprint("== every failure path speaks up ==")
-- This is the point of the suite. Each of these used to be, or could
-- easily have been, a silent return.

WIN = newWin()
setSpaces({ absent = true }); loadBlock()
fire("]")
check("no hs.spaces -> alert", alertsMatch("no Spaces support"), lastAlert())
check("no hs.spaces -> console line", #PRINTS > 0)
check("no hs.spaces -> did not crash", true)

WIN = newWin({ fullscreen = true })
setSpaces({ focused = 1, list = { 1, 2 } }); loadBlock()
fire("]")
check("full-screen window refused", alertsMatch("Full screen"), lastAlert())
check("full-screen window never moved", SP.movedTo == nil, SP.movedTo)

WIN = nil
setSpaces({ focused = 1, list = { 1, 2 } }); loadBlock()
fire("]")
check("no focused window -> alert", alertsMatch("No window in focus"), lastAlert())

WIN = newWin()
setSpaces({ focused = 1, list = { 1 } }); loadBlock()
fire("]")
check("single desktop -> alert", alertsMatch("Only one desktop"), lastAlert())
check("single desktop -> no move attempted", SP.movedTo == nil, SP.movedTo)

WIN = newWin()
setSpaces({ focused = 99, list = { 1, 2 } }); loadBlock()
fire("]")
check("unknown current space -> alert", alertsMatch("Can't tell which desktop"), lastAlert())
check("unknown current space -> console explains", (function()
  for _, p in ipairs(PRINTS) do
    if p:find("not in this screen", 1, true) then return true end
  end
  return false
end)())

WIN = newWin()
setSpaces({ focused = 1, list = { 1, 2 }, moveFails = true }); loadBlock()
fire("]")
check("move failure -> alert names the permission", alertsMatch("Accessibility"), lastAlert())
check("move failure -> did not follow to the space", SP.wentTo == nil, SP.wentTo)

WIN = newWin()
setSpaces({ focused = 1, list = {}, screenThrows = true }); loadBlock()
fire("]")
check("spacesForScreen throwing is survivable", alertsMatch("Only one desktop"), lastAlert())

realprint("== probe is cached, not re-run per press ==")
WIN = newWin()
local probes = 0
setSpaces({ focused = 1, list = { 1, 2 } }); loadBlock()
local realFocused = hs.spaces.focusedSpace
hs.spaces.focusedSpace = function() probes = probes + 1; return 1 end
fire("]"); fire("]"); fire("]")
check("three presses all worked", probes == 3, probes)
check("availability cached after first probe", _G.spaceMoveAvailable == true)
hs.spaces.focusedSpace = realFocused

realprint("")
realprint(string.format("PASS %d   FAIL %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
