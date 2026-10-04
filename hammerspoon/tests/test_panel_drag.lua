-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- THE PANEL DRAG ENGINE — one exit, and it always tells the caller
-- =====================================================================
-- 🚨 WHY THIS SUITE HAD TO EXIST, and what it found on its first run.
-- _G.makeCanvasDraggable has dragged four panels since 6.67.0 — the
-- cheat sheet, the key caster, the pomodoro and the Mac panel — and NO
-- suite had ever loaded it. That is how the following survived two
-- reports from LL, eleven releases apart, in the same words both times:
-- "Seems like a drag kills the sheet functionality" (6.138.0), and
-- "just because I can launch the cheat sheet doesn't mean it is
-- functional" (6.306.0).
--
-- The engine had FOUR exits and called onDrop from exactly ONE of them:
--
--   the tap's leftMouseUp .............. called onDrop  ✅
--   the canvas's own mouseUp ........... silent        ❌
--   the 20-second watchdog ............. silent        ❌
--   superseded by the next drag ........ silent        ❌
--
-- and onDrop is what moves the cheat sheet's WHEEL HIT BOX (6.138.0's
-- entire fix) and saves the panel's position. The panel has already been
-- moved by the time any exit runs, so a silent exit leaves a panel that
-- is physically somewhere new with every record of it still pointing at
-- the old spot: scrolling dead over the sheet, still swallowed over the
-- bare desk it used to cover, and the next open back in the wrong place.
--
-- 🖥 AND THE SILENT EXITS ARE REACHABLE. The tap returns false on
-- purpose — it observes, it never swallows — so macOS sees the drag too
-- and reads a three-finger one as a swipe between Spaces. A Space switch
-- is exactly the transition macOS switches event taps off across, so the
-- mouseUp never arrives and the watchdog takes it, silently. Both halves
-- of LL's report — "I am jumped to another desktop" and "it is not
-- functional" — are that one mechanism.
--
-- 🧊 6.222.0 SOLVED THIS ALREADY, FOR A PAGE: "a drag ends when the
-- button comes up, WHEREVER that happens — listen for the release, and
-- ALSO treat moving with nothing held as the release." It was written
-- for the screenshot editor's own JS and never asked of this engine.
-- 6.305.0's rule, one release later: a rule written about one caller is
-- not a rule until every caller has been asked.
-- =====================================================================

local PASS, FAIL = 0, 0
local function check(what, cond, got)
  if cond then PASS = PASS + 1
  else FAIL = FAIL + 1
    print("   ✗ " .. what .. (got and ("\n       got: " .. tostring(got)) or ""))
  end
end

-- ---------------------------------------------------------------------
-- The stubs. A stub answers what the real provider answers, refusals
-- included (6.193.0/6.290.0) — so the tap here can be made to REFUSE,
-- and checkMouseButtons can be made to lie in both directions.
-- ---------------------------------------------------------------------
local TAPS, TIMERS, PRINTED = {}, {}, {}
local MOUSE       = { x = 0, y = 0 }
local BUTTONS     = { left = true }
local TAP_REFUSES = false

local T = { leftMouseDragged = 6, leftMouseUp = 2, mouseMoved = 5 }

local function mkTimer(secs, fn)
  local t = { secs = secs, fn = fn, live = true }
  function t:stop() self.live = false; return self end
  table.insert(TIMERS, t); return t
end

-- A canvas that REMEMBERS where it was put, the way a real one does —
-- a getter-only topLeft would let every "it moved" check pass while
-- moving nothing (6.227.0/6.239.0/6.247.0: the getter-only stub has
-- hidden a whole feature four times in this project).
local function mkCanvas(x, y, w, h)
  local c = { f = { x = x, y = y, w = w, h = h }, mouseEvents = nil, cb = nil }
  function c:frame() return { x = self.f.x, y = self.f.y,
                              w = self.f.w, h = self.f.h } end
  function c:topLeft(p) self.f.x, self.f.y = p.x, p.y end
  function c:canvasMouseEvents(a, b, cc, d) self.mouseEvents = { a, b, cc, d } end
  function c:mouseCallback(fn) self.cb = fn end
  return c
end

hs = {
  eventtap = {
    event = { types = T },
    checkMouseButtons = function() return BUTTONS end,
    new = function(types, fn)
      if TAP_REFUSES then error("macOS refused the tap", 0) end
      local tap = { types = types, fn = fn, on = false }
      function tap:start() self.on = true; return self end
      function tap:stop()  self.on = false; return self end
      table.insert(TAPS, tap); return tap
    end,
  },
  timer  = { doAfter = function(s, fn) return mkTimer(s, fn) end,
             doEvery = function(s, fn) return mkTimer(s, fn) end,
             -- a FLOAT, as macOS answers — an INTEGER here is a stub gentler
             -- than the provider, which cost 23 checks in 6.282.0
             secondsSinceEpoch = function() return 1000.5 end },
  mouse  = { absolutePosition = function() return { x = MOUSE.x, y = MOUSE.y } end },
  canvas = { new = function(r) return mkCanvas(r.x, r.y, r.w, r.h) end },
  alert  = { show = function() end },
  screen = { allScreens = function() return {} end },
  settings = { get = function() end, set = function() end },
  hotkey = { bind = function() return { enable = function() end,
                                        disable = function() end } end },
  pasteboard = { getContents = function() return "" end,
                 setContents = function() return true end,
                 changeCount = function() return 1 end },
  fnutils = { each = function(t, f) for _, v in ipairs(t) do f(v) end end },
  inspect = tostring,
}

local realPrint = print
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  PRINTED[#PRINTED + 1] = table.concat(parts, "\t")
end

-- ---------------------------------------------------------------------
-- Load the engine the way init.lua does: core/coexist.lua returns a
-- function and init.lua calls it with a core table.
-- ---------------------------------------------------------------------
local chunk, loadErr = loadfile(HS .. "/core/coexist.lua")
print = realPrint
if not chunk then
  print("✗ cannot load core/coexist.lua: " .. tostring(loadErr))
  os.exit(1)
end
-- The restore is OUTSIDE the pcall: a throw in setup used to leave print
-- swallowed for the whole run, so the suite exited saying nothing at all
-- — a suite that cannot report its own failure to start (6.186.0).
local realPrint2 = print
print = function() end
local okRun, runErr = pcall(function() chunk()({}) end)
print = realPrint2
if not okRun then
  print("✗ core/coexist.lua threw on setup: " .. tostring(runErr))
  os.exit(1)
end

check("core/coexist.lua publishes the drag engine it was given in 6.306.0",
      type(_G.makeCanvasDraggable) == "function", type(_G.makeCanvasDraggable))
check("and its report, so the engine can be ASKED — it had none, which is "
      .. "why this took two reports and a source read to find",
      type(_G.dragReport) == "function", type(_G.dragReport))

-- ---------------------------------------------------------------------
-- A drag harness: arm a panel, press, move, and then end the drag by
-- whichever of the four exits the check is about.
-- ---------------------------------------------------------------------
local function arm()
  TAPS, TIMERS = {}, {}
  _G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil
  _G.dragDelivered, _G.dragNoFrame, _G.dragLastEnd = 0, 0, nil
  local drops = {}
  local cv = mkCanvas(100, 100, 400, 300)
  local ok = _G.makeCanvasDraggable(cv, "test panel",
                                    function(f) drops[#drops + 1] = f end)
  return cv, drops, ok
end

local function press(cv, x, y)
  MOUSE.x, MOUSE.y = x, y
  BUTTONS = { left = true }
  cv.cb(cv, "mouseDown")
end

local function moveTo(x, y)
  MOUSE.x, MOUSE.y = x, y
  local tap = TAPS[#TAPS]
  if tap then tap.fn({ getType = function() return T.leftMouseDragged end }) end
end

local function fire(type_)
  local tap = TAPS[#TAPS]
  if tap then tap.fn({ getType = function() return type_ end }) end
end

-- =====================================================================
-- §1 — the exit that always worked, so the rest has something to match
-- =====================================================================
print("§1 the mouseUp the tap sees")
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(250, 220)
  check("the panel follows the pointer",
        cv.f.x == 200 and cv.f.y == 170, cv.f.x .. "," .. cv.f.y)
  fire(T.leftMouseUp)
  check("onDrop is delivered once", #drops == 1, #drops)
  check("and it carries WHERE THE PANEL ENDED, not where it started",
        drops[1] and drops[1].x == 200 and drops[1].y == 170,
        drops[1] and (drops[1].x .. "," .. drops[1].y))
  check("the tap is stopped", _G.dragTap == nil)
  check("the watchdog is stopped",
        TIMERS[1] and TIMERS[1].live == false)
end

-- =====================================================================
-- §2 — THE THREE SILENT EXITS. Each of these delivered NOTHING before
--      6.306.0, and each leaves a panel that has already moved.
-- =====================================================================
print("§2 the exits that used to say nothing")
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(300, 300)
  -- The pointer is still over the panel when the button comes up, so the
  -- canvas's OWN mouseUp fires. It used to tear the drag down silently.
  cv.cb(cv, "mouseUp")
  check("🚨 a mouseUp ON THE PANEL delivers onDrop — it used to be silent, "
        .. "and this is the commonest ending of all: a careful drag that "
        .. "finishes with the pointer still on the thing being dragged",
        #drops == 1, #drops)
  check("with the moved frame",
        drops[1] and drops[1].x == 250 and drops[1].y == 250,
        drops[1] and (drops[1].x .. "," .. drops[1].y))
end
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(400, 500)
  -- macOS switched Spaces mid-drag; the mouseUp went somewhere else and
  -- the 20-second watchdog is the only thing left to end this.
  local guard = TIMERS[1]
  check("the watchdog was armed BEFORE the tap (6.246.0's ordering)",
        guard ~= nil and guard.secs == _G.dragMaxSecs,
        guard and guard.secs)
  guard.fn()
  check("🚨 the WATCHDOG delivers onDrop — this is the desktop-jump case, "
        .. "where the mouseUp never arrives at all",
        #drops == 1, #drops)
  check("with the moved frame, read at the exit rather than at the press",
        drops[1] and drops[1].x == 350 and drops[1].y == 450,
        drops[1] and (drops[1].x .. "," .. drops[1].y))
end
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(200, 200)
  -- A second press without a release: the engine supersedes the old drag.
  press(cv, 200, 200)
  check("🚨 being SUPERSEDED by the next drag delivers the old one's onDrop",
        #drops == 1, #drops)
end

-- =====================================================================
-- §3 — 6.222.0's RULE, FINALLY ASKED OF THIS ENGINE
-- =====================================================================
print("§3 moving with nothing held IS the release")
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(260, 260)
  -- macOS sends leftMouseDragged while the button is held and mouseMoved
  -- when it is not, so a mouseMoved arriving mid-drag IS the release.
  BUTTONS = {}
  fire(T.mouseMoved)
  check("🚨 a mouseMoved with no button held ends the drag and delivers — "
        .. "the rule 6.222.0 wrote for the editor's page, now asked of the "
        .. "engine that drags four panels",
        #drops == 1, #drops)
  check("and it stops the tap rather than leaving a global mouse tap "
        .. "running for the rest of the watchdog's 20 seconds",
        _G.dragTap == nil)
end
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(260, 260)
  -- checkMouseButtons is a VETO ONLY: believed when it says "still down",
  -- never when it says "released". window_move 6.156.0 paid for trusting
  -- it the other way, where a consumed press reads as released on the
  -- first tick and kills a drag before it moves anything.
  BUTTONS = { left = true }
  fire(T.mouseMoved)
  check("a mouseMoved while the button really IS down does NOT end the drag",
        #drops == 0, #drops)
  check("and the drag is still live", _G.dragging ~= nil)
  fire(T.leftMouseUp)
  check("so the real release still ends it", #drops == 1, #drops)
end
do
  -- A Mac whose checkMouseButtons throws must not strand a drag: a reader
  -- that cannot answer is treated as "the button is not down", which ends
  -- the drag and delivers — the safe direction (the other one is the bug
  -- being fixed).
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(260, 260)
  local realCheck = hs.eventtap.checkMouseButtons
  hs.eventtap.checkMouseButtons = function() error("no Accessibility", 0) end
  fire(T.mouseMoved)
  hs.eventtap.checkMouseButtons = realCheck
  check("a checkMouseButtons that THROWS ends the drag rather than "
        .. "stranding it (it degrades, it never breaks)", #drops == 1, #drops)
end

-- =====================================================================
-- §4 — EXACTLY ONCE. Two exits can race; the caller is told one time.
-- =====================================================================
print("§4 one door, once")
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(300, 300)
  local guard = TIMERS[1]
  fire(T.leftMouseUp)          -- the tap wins the race
  cv.cb(cv, "mouseUp")         -- the canvas's callback arrives too
  pcall(function() guard.fn() end)  -- and a watchdog that was not stopped
  check("🚨 onDrop is delivered EXACTLY ONCE across three overlapping "
        .. "exits — a second delivery would write a stale frame over a "
        .. "good one (6.299.0)", #drops == 1, #drops)
  check("the engine counts what it delivered", _G.dragDelivered == 1,
        _G.dragDelivered)
end

-- =====================================================================
-- §5 — the degrades, which must not be silent
-- =====================================================================
print("§5 refusals are counted, never swallowed")
do
  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(300, 300)
  -- A canvas that cannot answer its own frame: the panel moved and there
  -- is nothing to record. "Never told" and "told wrongly" are different
  -- faults (6.196.1), so this is counted apart rather than passed off.
  cv.frame = function() error("canvas is gone", 0) end
  fire(T.leftMouseUp)
  check("a canvas that cannot answer its frame delivers NOTHING rather "
        .. "than a wrong position", #drops == 0, #drops)
  check("and it is COUNTED, so the report can say so",
        _G.dragNoFrame == 1, _G.dragNoFrame)
  check("the drag is still torn down — a dead canvas must not leave a "
        .. "global mouse tap running", _G.dragTap == nil)
end
do
  TAP_REFUSES = true
  local cv, drops, ok = arm()
  press(cv, 150, 150)
  TAP_REFUSES = false
  check("a Mac that REFUSES the drag tap tears the attempt down rather "
        .. "than leaving a watchdog armed over nothing (6.265.0 — MISSING "
        .. "is not REFUSING)", _G.dragging == nil)
  check("and the watchdog it armed first is stopped",
        TIMERS[1] and TIMERS[1].live == false)
end
do
  check("a nil canvas is refused, not thrown at",
        _G.makeCanvasDraggable(nil, "nothing", function() end) == false)
end

-- =====================================================================
-- §6 — the report, measured against the HEALTHY case first (6.269.0)
-- =====================================================================
print("§6 the report")
do
  _G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil
  _G.dragDelivered, _G.dragNoFrame, _G.dragLastEnd = 0, 0, nil
  PRINTED = {}
  local p = print; print = function(s) PRINTED[#PRINTED + 1] = tostring(s) end
  _G.dragReport()
  print = p
  local txt = table.concat(PRINTED, "\n")
  check("a fresh session says nothing has been dragged, and carries no ⚠️",
        txt:find("no panel has been dragged", 1, true)
        and not txt:find("⚠️", 1, true), txt)

  local cv, drops = arm()
  press(cv, 150, 150)
  moveTo(300, 300)
  fire(T.leftMouseUp)
  PRINTED = {}
  p = print; print = function(s) PRINTED[#PRINTED + 1] = tostring(s) end
  _G.dragReport()
  print = p
  txt = table.concat(PRINTED, "\n")
  check("after a drag it names the panel and how the drag ENDED — which "
        .. "is the whole question this release turned on",
        txt:find("test panel", 1, true) and txt:find("mouseUp", 1, true), txt)
  check("and it does NOT warn on a healthy drag (6.269.0 — a new "
        .. "instrument's first duty is to be silent when nothing is wrong)",
        not txt:find("⚠️", 1, true), txt)
end

-- =====================================================================
-- §7 — source sentries: the class, not the instance
-- =====================================================================
print("§7 sentries")
do
  local f = io.open(HS .. "/core/coexist.lua")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  -- Comments are stripped, because the ones here deliberately quote the
  -- very shape they forbid (6.262.0).
  local code = src:gsub("\n%s*%-%-[^\n]*", "\n")

  check("onDrop is called from ONE place — the moment a second call site "
        .. "appears, an exit can be added that forgets",
        select(2, code:gsub("pcall%(d%.onDrop", "")) == 1,
        select(2, code:gsub("pcall%(d%.onDrop", "")))
  check("and that place is inside dragStop, so every exit reaches it "
        .. "without the exit having to know the caller",
        code:find("function dragStop", 1, true)
        and code:find("pcall%(d%.onDrop") > code:find("function dragStop", 1, true))
  check("exactly-once is STRUCTURAL: the drag is captured and the global "
        .. "nil'd before onDrop runs, so a later exit reads nil and returns "
        .. "— no flag to go stale (6.199.0 removed the one written here)",
        code:find("local d = _G.dragging", 1, true) ~= nil
        and not code:find("d.delivered = true", 1, true))
  check("the tap still OBSERVES and never swallows: the button is the "
        .. "person's, and swallowing it would cost every app below",
        code:find("return false", 1, true) ~= nil)

  local ini = io.open(HS .. "/init.lua")
  local isrc = ini and ini:read("*a") or ""
  if ini then ini:close() end
  local icode = isrc:gsub("\n%s*%-%-[^\n]*", "\n")
  check("init.lua no longer defines the engine — it moved here in 6.306.0 "
        .. "and two copies is how one stops matching the other (6.231.0)",
        not icode:find("function _G.makeCanvasDraggable", 1, true))
end

-- =====================================================================
-- 📋 6.325.0 — THE CLIPBOARD DOOR LIVES HERE TOO
-- =====================================================================
-- This file answers "two features want the same resource, who gets
-- it?", and the PASTEBOARD is one of them — the borrow guard and the
-- suppress window are about the same object. 6.325.0 put the one
-- clipboard WRITE here for that reason, and because init.lua is at its
-- 3,800-line ceiling.
--
-- 🔎 THE RULE IT EXISTS FOR: hs.pasteboard.setContents REFUSES BY
-- RETURNING FALSE and never throws, so
-- `pcall(function() setContents(x) end)` is true either way. Three
-- callers announced "📋 Copied" under exactly that shape.
--
-- 🚨 AND THE SWEEP IS WHY THIS SECTION EXISTS: the mutation that makes
-- the door stop READING the return — `pcall(function()
-- setContents(t) ; wrote = true end)` — survived everything, because
-- every other suite drives a STUB of the door rather than the door
-- (6.273.0: the line is not the finding, the missing check is).
do
  local SAID = {}
  local REFUSE, GOT = false, nil
  hs.pasteboard = { setContents = function(t)
      if REFUSE then return false end
      GOT = t ; return true
  end }
  hs.alert = hs.alert or {}
  local keptAlert = hs.alert.show
  hs.alert.show = function(m) SAID[#SAID + 1] = tostring(m) end
  local keptDeg = _G.degrade
  local DEGRADED = {}
  _G.degrade = function(tool, why) DEGRADED[#DEGRADED + 1] = { tool, why } return false, why end

  check("📋 the door is published", type(_G.clipWrite) == "function")

  GOT = nil
  local ok1 = _G.clipWrite("hello", "a test")
  check("📋 a write macOS takes answers TRUE and really lands",
        ok1 == true and GOT == "hello", tostring(ok1) .. " / " .. tostring(GOT))

  -- 🚨 THE ONE THE SWEEP FOUND UNDRIVEN
  REFUSE, GOT = true, nil
  local ok2, why2 = _G.clipWrite("nope", "a test")
  REFUSE = false
  check("🚨 a write macOS REFUSES answers FALSE — setContents returns a "
        .. "boolean and never throws, so a pcall alone calls it success",
        ok2 == false and why2 ~= nil, tostring(ok2) .. " / " .. tostring(why2))
  check("🔔 …and it takes the degrade door, so the ledger and "
        .. "_G.todayReport() can see it",
        #DEGRADED >= 1 and tostring(DEGRADED[#DEGRADED][2]):find("refused", 1, true) ~= nil,
        DEGRADED[#DEGRADED] and DEGRADED[#DEGRADED][2] or "none")
  check("🔎 …and it is COUNTED, because \"intermittent\" is a count and "
        .. "not a sample (6.229.0)",
        _G.clipWrites.refused >= 1, _G.clipWrites.refused)

  local ok3, why3 = _G.clipWrite("", "a test")
  check("📏 nothing to copy is its OWN answer, not a refusal by macOS",
        ok3 == false and why3 ~= why2 and _G.clipWrites.empty >= 1,
        tostring(why3))
  local ok4 = _G.clipWrite(nil, "a test")
  check("🛟 a nil is refused rather than thrown at", ok4 == false)

  -- 🔎 three states in the report, and the ⚠️ is not forgotten
  local rep = _G.clipboardWriteReport()
  check("🔎 the report names the refusals rather than only the successes",
        rep:find("REFUSED", 1, true) ~= nil and rep:find("last   :", 1, true) ~= nil,
        rep:match("[^\n]*REFUSED[^\n]*") or rep)

  hs.alert.show = keptAlert
  _G.degrade = keptDeg
end

print(("\n%s  %d passed, %d failed"):format(FAIL == 0 and "✅" or "❌", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
