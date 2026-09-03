-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
-- HS   = the config being tested (init.lua + modules/)
-- HERE = this tests folder, which is where the extracted fixtures live
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local HS   = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
             or ((os.getenv("HOME") or ".") .. "/.hammerspoon")
-- Harness for §1.10. Runs the shipped code against a stubbed hs whose
-- windows, clock and modifier state are all under the test's control.
local bound, log = {}, {}
local NOW = 1000
local FAIL = { list = false, canvas = false, snapshot = false }
local COUNT = { ordered = 0, all = 0, apps = 0, canvasNew = 0, deleted = 0,
                alerts = 0, legacy = 0 }
local ACTIVATED = nil
local MODS = { alt = true }
local focused, unminimized = nil, nil
local drawn, timer = nil, nil

local function mkwin(id, app, title, minimized, standard, snap)
  local w = {}
  function w:id() return id end
  function w:title() return title end
  function w:isStandard() return standard ~= false end
  function w:isMinimized() return minimized == true end
  function w:snapshot()
    SNAPSHOT_CALLS = SNAPSHOT_CALLS + 1
    if FAIL.snapshot then error("no snapshot") end
    return snap ~= false and ("snap:" .. id) or nil
  end
  function w:unminimize() unminimized = id end
  -- 6.152.0 — the memory probes a remembered window's role to learn
  -- whether it still exists. A live AX element answers "AXWindow"; a
  -- destroyed one answers nil. w.dead = true models closing the window.
  function w:role() if w.dead then return nil end return "AXWindow" end
  -- 6.68.0 — becomeMain/raise are what hs.window:focus() is actually made
  -- of, and the fix is that they are NOT a substitute for activating the
  -- owning app. Recorded separately so a test can tell the two apart.
  function w:becomeMain() MAINED = id end
  function w:raise() RAISED = id end
  function w:focus() focused = id end
  function w:application()
    -- activate() belongs here because a REAL hs.window:application() hands
    -- back a real hs.application, which has it. Leaving it off made the
    -- 6.68.0 "activate the owning app" fix look like it had not been
    -- written — the pcall around it succeeded at doing nothing.
    return { name = function() return app end,
             bundleID = function() return "com.test." .. app end,
             activate = function() ACTIVATED = app end }
  end
  return w
end

local WINS, APPS = {}, {}
local mkapp
-- An app owns windows that may live on ANY Space; orderedWindows only
-- ever reports the ones on the current one, which is the bug being fixed.
-- Build the running-app list FROM the windows, the way macOS actually
-- reports it: an app owns the windows whose application() is that app.
-- (An earlier version of this harness named the app differently from its
-- own windows, which no real Mac does, and it made every app look like it
-- owned nothing.)
local function appsFromWindows(wins)
  local byName, order, out = {}, {}, {}
  for _, w in ipairs(wins) do
    local n = w:application():name()
    if not byName[n] then byName[n] = {}; table.insert(order, n) end
    table.insert(byName[n], w)
  end
  for _, n in ipairs(order) do table.insert(out, mkapp(n, byName[n])) end
  return out
end
function mkapp(name, wins, kind)
  local a = {}
  function a:name() return name end
  function a:kind() return kind or 1 end
  function a:bundleID() return "com.test." .. name end
  -- 🚨 6.152.0 — THE STUB NOW TELLS THE AX TRUTH. app:allWindows()
  -- returns minimised windows (no Space owns them) but NOT windows
  -- parked on another desktop — that is the real macOS behaviour the
  -- old harness contradicted, and the contradiction let "windows on
  -- ANOTHER Space are listed" pass for years while LL's real Chrome
  -- windows were missing. Other-desktop windows can only reach the
  -- grid through the module's memory now, here as on a real Mac.
  function a:allWindows()
    local out = {}
    for _, w in ipairs(wins or {}) do
      if w.space ~= "other" then table.insert(out, w) end
    end
    return out
  end
  function a:isRunning() return a.running ~= false end
  function a:activate() ACTIVATED = name end
  return a
end
PENDING = {}        -- one-shot timers the module has queued but not run
MAINED, RAISED, FRONTWIN = nil, nil, nil
hs = {
  window = {
    -- 6.152.0 — orderedWindows must NEVER be called any more: it re-runs
    -- the whole per-app sweep internally (the 1.6s LL paid twice every
    -- press). COUNT.legacy catches a regression that reintroduces it.
    orderedWindows = function()
      COUNT.legacy = COUNT.legacy + 1
      local out = {}
      for _, w in ipairs(WINS) do
        if not w:isMinimized() and w.space ~= "other" then table.insert(out, w) end
      end
      return out
    end,
    -- The raw CoreGraphics id list: front-to-back, current desktop only,
    -- no minimised windows — exactly what the real internal returns.
    _orderedwinids = function()
      COUNT.ordered = COUNT.ordered + 1
      if FAIL.list then error("CG refused") end
      local out = {}
      for _, w in ipairs(WINS) do
        if not w:isMinimized() and w.space ~= "other" then table.insert(out, w:id()) end
      end
      return out
    end,
    allWindows = function() COUNT.all = COUNT.all + 1; return WINS end,
    -- 6.68.0 — the switcher asks who is in front, twice: to anchor the
    -- starting tile, and to VERIFY the switch actually landed. FRONTWIN is
    -- the test's handle on both. nil = "nothing focused", which is the
    -- default and keeps every pre-6.68 expectation intact.
    focusedWindow = function() return FRONTWIN end,
  },
  application = {
    runningApplications = function() COUNT.apps = COUNT.apps + 1; return APPS end,
    -- 6.152.0 — the sweep asks the frontmost app first; derived from
    -- FRONTWIN so the anchor tests drive both with one handle.
    frontmostApplication = function()
      return FRONTWIN and FRONTWIN:application() or nil
    end,
  },
  timer = {
    secondsSinceEpoch = function() return NOW end,
    doEvery = function(interval, fn)
      timer = { interval = interval, fn = fn, running = true }
      function timer:stop() self.running = false end
      return timer
    end,
    -- 6.68.0 — the switch VERIFIER runs on a one-shot timer, as does the
    -- wait for the unminimize animation. They are queued rather than fired
    -- so a test can decide when (and whether) time passes: firing them
    -- inline would make every switch synchronous and hide the very race
    -- the delay exists to avoid.
    doAfter = function(delay, fn)
      local t = { delay = delay, fn = fn, running = true }
      function t:stop() self.running = false end
      table.insert(PENDING, t)
      return t
    end,
  },
  canvas = {
    windowLevels = { overlay = 102 },
    new = function(rect)
      if FAIL.canvas then return nil end
      COUNT.canvasNew = COUNT.canvasNew + 1
      local c = { rect = rect }
      function c:replaceElements(els) drawn = els; return c end
      function c:show() return c end
      function c:delete() COUNT.deleted = COUNT.deleted + 1; return c end
      function c:level() return c end
      function c:behaviorAsLabels() return c end
      return c
    end,
  },
  hotkey = {
    bind = function(mods, key, fn)
      table.insert(bound, { combo = table.concat(mods, "+") .. "+" .. key, fn = fn })
    end,
    new = function(mods, key, fn, releasedFn, repeatFn)
      local hk = { key = key, fire = fn, on = false,
                   mods = mods, mask = table.concat(mods or {}, "+"),
                   releasedFn = releasedFn, repeatFn = repeatFn }
      function hk:enable() self.on = true; return hk end
      function hk:disable() self.on = false; return hk end
      table.insert(NAVKEYS, hk)
      return hk
    end,
  },
  eventtap = { checkKeyboardModifiers = function() return MODS end },
  image = { imageFromAppBundle = function(b) return "icon:" .. tostring(b) end },
  alert = { show = function() COUNT.alerts = COUNT.alerts + 1 end },
}
function resolveBaseScreen() return { frame = function() return { x=0, y=0, w=3840, h=2160 } end } end
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  table.insert(log, table.concat(p, " "))
end

_G.diag = { say = function() end, warn = function() end, mark = function() end,
            err = function() end, verbose = false, trail = {}, errors = {}, marks = {} }
local mod = dofile(HS .. "/modules/window_switcher.lua")
-- resolveBaseScreen is looked up at CALL time, not captured, so the
-- small-screen test below can swap the screen out from under it.
mod.setup({ resolveBaseScreen = function(...) return resolveBaseScreen(...) end,
            diag = _G.diag })
local AT = mod.altTab

local out = io.write
NAVKEYS = {}
SNAPSHOT_CALLS = 0
-- Drain every queued one-shot timer, repeatedly, because a verifier that
-- retries queues another one. Bounded so a retry loop that never settles
-- fails the test instead of hanging it.
local function runPending(rounds)
  for _ = 1, (rounds or 4) do
    local batch = PENDING
    PENDING = {}
    if #batch == 0 then return end
    for _, t in ipairs(batch) do if t.running then t.fn() end end
  end
end
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end
local function logged(pat)
  for _, l in ipairs(log) do if l:find(pat, 1, true) then return true end end
  return false
end
local combos = {}
local function reset(n)
  WINS = {}
  for i = 1, (n or 5) do table.insert(WINS, mkwin(i, "App" .. i, "Window " .. i)) end
  AT.finish(false)
  APPS = appsFromWindows(WINS)
  COUNT.ordered, COUNT.all, COUNT.apps, COUNT.canvasNew, COUNT.deleted, COUNT.alerts = 0,0,0,0,0,0
  COUNT.legacy = 0
  AT.known, AT.lastHere = {}, {}   -- 6.152.0 — each scenario starts unlearned
  ACTIVATED = nil
  FAIL.list, FAIL.canvas, FAIL.snapshot = false, false, false
  SNAPSHOT_CALLS = 0
  AT.useSnapshots = true    -- the Screen Recording switch, on by default
  focused, unminimized, drawn, timer, log = nil, nil, nil, nil, {}
  MAINED, RAISED, FRONTWIN = nil, nil, nil
  PENDING = {}
  MODS = { alt = true }; NOW = 1000
  AT.cache = nil          -- each scenario starts with a cold list
  AT.listBudget = 999     -- no deadline unless a test sets one
  AT.probeBudget = 999    -- 6.153.0 — same rule for the memory probes
  AT.enabled, AT.includeMinimized = true, true
  AT.includeOtherSpaces, AT.includeApps = true, true
end
for _, b in ipairs(bound) do combos[b.combo] = b.fn end

out("\n=== 1. Bindings, and nothing runs at load ===\n")
check("⌥Tab bound", combos["alt+tab"] ~= nil)
check("⌥⇧Tab bound", combos["alt+shift+tab"] ~= nil)
check("⌘Tab left alone", combos["cmd+tab"] == nil)
check("no window enumeration at load", COUNT.ordered == 0 and COUNT.all == 0)
check("no canvas at load", COUNT.canvasNew == 0)
check("no timer at load", timer == nil)
check("hs.window.filter is never referenced", hs.window.filter == nil)
check("the module declares its own cheat sheet group",
  mod.cheatsheet and mod.cheatsheet.title:find("WINDOW SWITCHER", 1, true) ~= nil)
check("...and its slot in the sheet", mod.order == 8, mod.order)
check("module exposes a setup() per the contract", type(mod.setup) == "function")

out("\n=== 2. A press opens the HUD ===\n")
reset(5)
combos["alt+tab"]()
check("windows listed exactly once", COUNT.ordered == 1, COUNT.ordered)
check("HUD drawn", COUNT.canvasNew == 1)
check("selection starts on the SECOND window (Windows behaviour)", AT.session.index == 2, AT.session.index)
check("poll timer created", timer ~= nil and timer.running == true)
check("...and is HELD, not garbage (the 6.33.0 bug)", AT.poll == timer)
check("Esc is armed while the HUD is up", AT.escKey and AT.escKey.on == true)
check("one tile per window", (function()
  local imgs = 0
  for _, e in ipairs(drawn) do if e.type == "image" then imgs = imgs + 1 end end
  return imgs == 5
end)())

out("\n=== 3. Tabbing walks the list ===\n")
combos["alt+tab"]()
check("second press advances", AT.session.index == 3, AT.session.index)
check("...without re-listing the windows", COUNT.ordered == 1, COUNT.ordered)
combos["alt+tab"](); combos["alt+tab"](); combos["alt+tab"]()
check("wraps around the end", AT.session.index == 1, AT.session.index)
combos["alt+shift+tab"]()
check("⌥⇧Tab steps backwards (wrapping)", AT.session.index == 5, AT.session.index)

out("\n=== 4. Releasing ⌥ switches ===\n")
MODS = {}
timer.fn()
check("focused the highlighted window", focused == 5, focused)
check("HUD deleted", COUNT.deleted == 1)
check("poll timer stopped and released", timer.running == false and AT.poll == nil)
check("Esc disarmed", AT.escKey.on == false)
check("session cleared", AT.session == nil)
focused = nil
timer.fn()
check("a second release cannot switch again", focused == nil)

out("\n=== 5. Esc cancels ===\n")
reset(4)
combos["alt+tab"]()
AT.escKey.fire()
check("no window focused", focused == nil)
check("HUD deleted", COUNT.deleted == 1)
check("session cleared", AT.session == nil)

out("\n=== 6. Reverse opens on the LAST window ===\n")
reset(4)
combos["alt+shift+tab"]()
check("⌥⇧Tab opens on the last window", AT.session.index == 4, AT.session.index)

out("\n=== 7. EVERY window: minimised via AX, other desktops via MEMORY ===\n")
-- 🚨 6.152.0 — macOS's Accessibility API returns an app's minimised
-- windows (no Space owns them) but NOT its windows on another desktop.
-- The harness models that truth now (see mkapp), so the other-desktop
-- promise must be met the way the module actually meets it: a window is
-- REMEMBERED from the first press that could see its desktop, and served
-- from that memory ever after — pruned the moment it dies.
reset(3)
local far = mkwin(90, "FarApp", "On another desktop"); far.space = "other"
local mini = mkwin(91, "MiniApp", "Minimised one", true)
table.insert(WINS, far); table.insert(WINS, mini)
APPS = appsFromWindows(WINS)
local function listedId(id)
  for _, i in ipairs(AT.session.items) do
    if i.win and i.win:id() == id then return i end
  end
end
combos["alt+tab"]()
check("minimised windows are listed", listedId(91) ~= nil)
check("🚨 a window on another desktop is NOT in AX's answer — a first, "
   .. "unlearned press cannot see it (this is macOS, not a choice)",
      listedId(90) == nil, #AT.session.items .. " items")
AT.finish(false)
-- One press on its own desktop is the whole lesson.
far.space = nil
AT.cache = nil
combos["alt+tab"]()
check("a press on its own desktop lists it normally", listedId(90) ~= nil)
AT.finish(false)
far.space = "other"          -- back on the first desktop: AX forgets it…
AT.cache = nil
combos["alt+tab"]()
check("🧠 …and the MEMORY does not: it is a tile from wherever you are",
      listedId(90) ~= nil)
check("...its caption says it is remembered",
      listedId(90) and listedId(90).remembered == true)
check("this Space still comes FIRST", AT.session.items[1].win:id() == 1,
      AT.session.items[1].win and AT.session.items[1].win:id())
check("no window is listed twice", (function()
  local seen = {}
  for _, i in ipairs(AT.session.items) do
    local id = i.win and i.win:id()
    if id then if seen[id] then return false end seen[id] = true end
  end
  return true
end)())
check("the timing line counts the remembered windows for ⇪⇧D",
      _G.altTabLastListing and _G.altTabLastListing.remembered == 1,
      _G.altTabLastListing and _G.altTabLastListing.remembered)
AT.finish(false)
-- A closed window must not haunt the grid: the probe finds the AX
-- element dead and the memory forgets it, permanently.
far.dead = true
AT.cache = nil
combos["alt+tab"]()
check("a CLOSED remembered window is probed, found dead, and dropped",
      listedId(90) == nil)
check("...and forgotten outright, not re-probed forever",
      AT.known[90] == nil)
far.dead = false
check("only GUI apps are asked (background agents skipped)", (function()
  APPS = { mkapp("Daemon", { mkwin(70, "Daemon", "hidden helper") }, 0) }
  reset(2)
  APPS = appsFromWindows(WINS)
  table.insert(APPS, mkapp("Daemon", { mkwin(70, "Daemon", "helper") }, 0))
  combos["alt+tab"]()
  for _, i in ipairs(AT.session.items) do
    if i.win and i.win:id() == 70 then return false end
  end
  return true
end)())
check("includeOtherSpaces = false switches the memory off too", (function()
  reset(3)
  local f2 = mkwin(92, "FarApp", "Other desktop")
  table.insert(WINS, f2); APPS = appsFromWindows(WINS)
  combos["alt+tab"]()                 -- learned while on this desktop
  AT.finish(false)
  f2.space = "other"
  AT.includeOtherSpaces, AT.includeApps = false, false
  AT.cache = nil
  combos["alt+tab"]()
  for _, i in ipairs(AT.session.items) do if i.win and i.win:id() == 92 then return false end end
  return true
end)())

out("\n=== 7d. 6.153.0 — the memory probes are BUDGETED ===\n")
-- 🚨 LL's Console: "listing took 1.64s across 13 apps (slowest: 0.01s)".
-- Thirteen fast apps cannot add up to 1.64 seconds — the missing 1.5s
-- was THIS loop: every remembered window, an AX round-trip, every
-- press, outside every timer in the file. Probing now stops when
-- altTab.probeBudget is spent; what the budget could not reach is still
-- a tile (something vouched for it recently), and is probed FIRST next
-- press — least recently verified first — so the culling of dead
-- windows rotates through the whole memory instead of stalling.
reset(2)
ROLES = {}
local fars = {}
for i = 1, 6 do
  local fw = mkwin(400 + i, "Far" .. i, "Away " .. i)
  local realRole = fw.role
  -- each probe costs half a second of AX time, and is recorded
  fw.role = function(self)
    table.insert(ROLES, 400 + i); NOW = NOW + 0.5; return realRole(self)
  end
  table.insert(fars, fw); table.insert(WINS, fw)
end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()              -- the learning press: all six seen here
AT.finish(false)
for _, fw in ipairs(fars) do fw.space = "other" end
ROLES = {}
NOW = NOW + 10                   -- past the cache; the memory serves them now
AT.cache = nil
AT.probeBudget = 0.8             -- two 0.5s probes fit, four do not
combos["alt+tab"]()
check("🚨 probing STOPS when the budget is spent", #ROLES == 2, #ROLES)
check("...the unreached windows are still tiles — alive until proven "
   .. "otherwise, never silently dropped", (function()
  local n = 0
  for _, i in ipairs(AT.session.items) do
    local id = i.win and i.win:id()
    if id and id > 400 then n = n + 1 end
  end
  return n == 6
end)(), #AT.session.items .. " items")
check("...and the probe count and cost are published for ⇪⇧D",
      _G.altTabLastListing.probed == 2 and _G.altTabLastListing.probeSecs >= 1,
      tostring(_G.altTabLastListing.probed) .. " in "
      .. tostring(_G.altTabLastListing.probeSecs) .. "s")
local firstRound = {}
for _, id in ipairs(ROLES) do firstRound[id] = true end
AT.finish(false)
ROLES = {}
NOW = NOW + 10
AT.cache = nil
combos["alt+tab"]()
check("🔁 the NEXT press probes the windows the budget skipped — least "
   .. "recently verified first, so the queue rotates",
      #ROLES == 2 and not firstRound[ROLES[1]] and not firstRound[ROLES[2]],
      table.concat(ROLES, ","))
AT.finish(false)
reset(2)
APPS = appsFromWindows(WINS)
table.insert(APPS, mkapp("Notes", {}))
combos["alt+tab"]()
local appTile
for _, i in ipairs(AT.session.items) do if i.appOnly then appTile = i end end
check("an app with no open window still gets a tile", appTile ~= nil)
check("...labelled as such", appTile and appTile.full:find("no open window", 1, true) ~= nil,
      appTile and appTile.full)
check("...and shows its app icon since there is nothing to snapshot",
      appTile and appTile.image == "icon:com.test.Notes", appTile and appTile.image)
for k, i in ipairs(AT.session.items) do if i.appOnly then AT.session.index = k end end
MODS = {}; timer.fn()
check("selecting it ACTIVATES the app instead of focusing a window",
      ACTIVATED == "Notes" and focused == nil, tostring(ACTIVATED))

out("\n=== 7c. The 15.9-second lesson: a deadline and a cache ===\n")
reset(4)
AT.listBudget = 999
combos["alt+tab"]()
local firstCount = COUNT.apps
AT.finish(false)
combos["alt+tab"]()
check("a second press within the cache window does NOT re-scan the apps",
      COUNT.apps == firstCount, COUNT.apps .. " vs " .. firstCount)
check("...and still shows the same windows", #AT.session.items > 0)
AT.finish(false)
NOW = NOW + AT.cacheFor + 1
combos["alt+tab"]()
check("once the cache expires it scans again", COUNT.apps > firstCount, COUNT.apps)

reset(4)
-- make every app cost 0.5s of AX time; with a 0.8s budget the sweep must
-- stop early rather than paying it 15 times over
local slowApps = {}
for i = 1, 15 do
  local w = mkwin(200 + i, "Slow" .. i, "W")
  local a = mkapp("Slow" .. i, { w })
  local realAll = a.allWindows
  a.allWindows = function(self) NOW = NOW + 0.5; return realAll(self) end
  table.insert(slowApps, a)
end
APPS = slowApps
AT.listBudget = 0.8
AT.cache = nil
combos["alt+tab"]()
check("the sweep STOPS when the budget is spent", COUNT.apps <= 15, COUNT.apps)
check("...and the Console says so, with what to do about it",
      logged("stopped after") and logged("altTab.skipApps"))
check("...naming the slowest application", logged("Slow"))
check("...and it still opens with what it collected", AT.session ~= nil)
check("the HUD admits the list was cut short", (function()
  for _, e in ipairs(drawn) do
    if e.type == "text" and e.text:find("cut short", 1, true) then return true end
  end
end)())
check("the timing is published for ⇪⇧D", _G.altTabLastListing
      and _G.altTabLastListing.truncated == true, _G.altTabLastListing)
AT.finish(false)

reset(3)
local sw = mkwin(300, "Chatty", "W"); sw.space = "other"
local chatty = mkapp("Chatty", { sw })
chatty.allWindows = function(self) NOW = NOW + 5; return { sw } end
APPS = appsFromWindows(WINS); table.insert(APPS, chatty)
AT.skipApps = { "Chatty" }
AT.cache, AT.listBudget = nil, 999
combos["alt+tab"]()
check("an app on skipApps is never asked (the escape hatch)", (function()
  for _, i in ipairs(AT.session.items) do
    if i.win and i.win:id() == 300 then return false end
  end
  return true
end)())
AT.skipApps = {}

out("\n=== 8. Bounded cost ===\n")
reset(0)
for i = 1, 100 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("window list capped at maxWindows", #AT.session.items == AT.maxWindows, #AT.session.items)
check("grid never exceeds maxCols", AT.session.cols <= AT.maxCols, AT.session.cols)
check("HUD fits on the screen", AT.session.w <= 3840 and AT.session.h <= 2160,
      AT.session.w .. "x" .. AT.session.h)

out("\n=== 9. Slow machines report a number, not a beachball ===\n")
reset(5)   -- budget stays at reset()'s 999: nothing truncates, the
           -- slow WARNING is the branch under test
local realNow = hs.timer.secondsSinceEpoch
local step = 0
hs.timer.secondsSinceEpoch = function() step = step + 1; return 1000 + (step > 1 and 2.5 or 0) end
AT.listWindows()
check("a slow enumeration is timed and reported",
      (log[#log] or ""):find("listing took", 1, true) ~= nil, log[#log])
hs.timer.secondsSinceEpoch = realNow

out("\n=== 9b. 6.152.0 — one sweep, not two: orderedWindows is gone ===\n")
-- 🚨 The old phase 1 called hs.window.orderedWindows(), which INTERNALLY
-- re-runs the whole per-app sweep (plus extra attribute reads) just to
-- learn the stacking order — 1.6s on LL's Air, on top of the sweep's own
-- 0.7s, every press. That is "⌥Tab is slow to display". The order now
-- comes from the raw CoreGraphics id list, which costs milliseconds.
reset(3)
combos["alt+tab"]()
check("🚨 hs.window.orderedWindows is NEVER called — the double sweep is gone",
      COUNT.legacy == 0, COUNT.legacy)
check("...the CG id list is consulted instead, once per listing",
      COUNT.ordered == 1, COUNT.ordered)
AT.finish(false)
-- The CG ranks decide the tile order, whatever order the sweep found
-- the windows in.
reset(3)
local realIds = hs.window._orderedwinids
hs.window._orderedwinids = function() return { 3, 1, 2 } end
AT.cache = nil
combos["alt+tab"]()
check("tiles follow the CG front-to-back order, not the sweep order",
      AT.session.items[1].win:id() == 3 and AT.session.items[2].win:id() == 1
      and AT.session.items[3].win:id() == 2,
      AT.session.items[1].win and AT.session.items[1].win:id())
AT.finish(false)
-- _orderedwinids is an hs.window INTERNAL: a build without it must cost
-- the ordering, never the switcher.
hs.window._orderedwinids = nil
AT.cache = nil
combos["alt+tab"]()
check("a build without _orderedwinids still lists every window",
      AT.session ~= nil and #AT.session.items == 3,
      AT.session and #AT.session.items)
hs.window._orderedwinids = realIds
AT.finish(false)

out("\n=== 9c. a genuinely slow APP is still named ===\n")
-- The classic message survives for the case it was built for: the
-- budget dies inside the sweep, with a culprit worth naming. (Clock
-- sequence rebuilt for 6.152.0's single-sweep call order.)
reset(2)
AT.listBudget = 0.8
local seq = { 1000,     -- t0
              1000.1,   -- t1: the sweep starts its own clock
              1000.2,   -- App1's deadline check — 0.1s in, within budget
              1000.3,   -- App1's own timer starts
              1001.2,   -- …and ends: App1 took 0.9s
              1001.1,   -- App2's deadline check — 1.0s > 0.8s, break
              1001.4, 1001.4 }
local tick = 0
hs.timer.secondsSinceEpoch = function() tick = tick + 1 ; return seq[tick] or 1001.4 end
AT.listWindows()
hs.timer.secondsSinceEpoch = realNow
check("one slow app is named, with its own time",
      (log[#log] or ""):find("Slowest app: App1", 1, true) ~= nil, log[#log])
check("...and the skipApps advice appears only on THIS path",
      (log[#log] or ""):find("skipApps", 1, true) ~= nil)

out("\n=== 9d. the other Chrome windows: visible apps first + the memory ===\n")
-- LL: "it shows one Chrome window but no other Chrome windows I have
-- open". Rebuilt end to end: the minimised window comes from the sweep
-- (asked FIRST, because Chrome had a visible window last press, while
-- background agents eat the budget behind it), and the other-desktop
-- window comes from the memory — AX will not hand it over at all.
reset(0)
local chromeHere = mkwin(500, "Chrome", "Docs")
local chromeMin  = mkwin(501, "Chrome", "Mail", true)          -- minimised
local chromeAway = mkwin(502, "Chrome", "Calendar")            -- for now, here
WINS = { chromeHere, chromeMin, chromeAway }
local chromeApp = mkapp("Chrome", { chromeHere, chromeMin, chromeAway })
APPS = { chromeApp }
combos["alt+tab"]()              -- the learning press: all three seen
AT.finish(false)
chromeAway.space = "other"       -- …then Calendar moves to Desktop 2
WINS = { chromeHere, chromeMin, chromeAway }
APPS = {}
for i = 1, 10 do          -- background agents, each 0.5s of AX time,
  local a = mkapp("Agent" .. i, { mkwin(600 + i, "Agent" .. i, "W") })
  local realAll = a.allWindows
  a.allWindows = function(self) NOW = NOW + 0.5; return realAll(self) end
  table.insert(APPS, a)
end
table.insert(APPS, chromeApp)   -- …and Chrome dead LAST in macOS's order
AT.listBudget = 0.8
AT.cache = nil
combos["alt+tab"]()
local ids = {}
for _, i in ipairs(AT.session.items) do
  if i.win then ids[i.win:id()] = true end
end
check("the minimised Chrome window is a tile", ids[501] == true)
check("the other-desktop Chrome window is a tile — served by the memory",
      ids[502] == true)
check("...even though the budget still cut the agent queue short",
      _G.altTabLastListing.truncated == true)
check("...because Chrome was asked before the agents that macOS listed first",
      (function()
        -- Only agents asked BEFORE the break contributed windows; with
        -- Chrome first, at most two agents fit the 0.8s budget.
        local agents = 0
        for id in pairs(ids) do if id > 600 then agents = agents + 1 end end
        return agents <= 2
      end)(), (function()
        local n = 0
        for id in pairs(ids) do if id > 600 then n = n + 1 end end
        return n
      end)())
AT.finish(false)

out("\n=== 10. Failures degrade, they don't hang or crash ===\n")
reset(5); FAIL.list = true
local ok = pcall(function() combos["alt+tab"]() end)
check("a CG id-list failure does not throw (6.152.0: it is pcall'd)", ok)
check("...and costs only the ordering — the sweep still supplies every "
      .. "window", AT.session ~= nil and #AT.session.items == 5,
      AT.session and #AT.session.items or "no session")
AT.finish(false)
reset(5); FAIL.canvas = true
ok = pcall(function() combos["alt+tab"]() end)
check("a canvas failure does not throw", ok and AT.session == nil)
check("...and tells you", COUNT.alerts >= 1)
reset(5); FAIL.snapshot = true
ok = pcall(function() combos["alt+tab"]() end)
check("windows with no snapshot still get a tile", ok and #AT.session.items == 5)
check("...falling back to the app icon", AT.session.items[1].image == "icon:com.test.App1",
      tostring(AT.session.items[1].image))
reset(1)
combos["alt+tab"]()
check("a single window opens nothing and says so", AT.session == nil and COUNT.alerts == 1)

out("\n=== 11. Watchdog and panic switch ===\n")
reset(5)
combos["alt+tab"]()
NOW = 1000 + AT.maxSessionSecs + 1
timer.fn()
check("a stuck HUD tears itself down", AT.session == nil and COUNT.deleted == 1)
check("...without switching windows", focused == nil)
check("...and says why", logged("watchdog"))
reset(5)
AT.enabled = false
combos["alt+tab"]()
check("altTab.enabled = false makes ⌥Tab inert", AT.session == nil and COUNT.ordered == 0)

out("\n=== 12. Titles are truncated, never clipped ===\n")
reset(0)
table.insert(WINS, mkwin(1, "App", string.rep("VeryLongWindowTitle", 20)))
table.insert(WINS, mkwin(2, "Ünïcödé ⌘ App ⇪", "Second"))
APPS = appsFromWindows(WINS)
AT.enabled = true
combos["alt+tab"]()
local longest = 0
for _, e in ipairs(drawn) do
  if e.type == "text" then
    local n = utf8.len(e.text) or #e.text
    if n > longest then longest = n end
  end
end
check("no rendered label is absurdly long", longest <= math.floor(AT.session.w / 8), longest)
check("multi-byte labels survive truncation", (function()
  for _, e in ipairs(drawn) do
    if e.type == "text" and e.text:find("Ünïcödé", 1, true) then return utf8.len(e.text) ~= nil end
  end
  return false
end)())

out("\n=== 13. Small laptop screen (the 1314pt overflow) ===\n")
resolveBaseScreen = function() return { frame = function() return { x=0, y=0, w=1280, h=800 } end } end
reset(0)
for i = 1, 24 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("HUD fits inside a 1280x800 screen",
      AT.session.w <= 1280 and AT.session.h <= 800, AT.session.w .. "x" .. AT.session.h)
check("columns fitted to the width, not fixed at 6", AT.session.cols < 6, AT.session.cols)
check("the tiles it cannot fit are dropped, not drawn off-screen", #AT.session.items < 24, #AT.session.items)
check("...and the footer admits it", (function()
  for _, e in ipairs(drawn) do
    if e.type == "text" and e.text:find("showing", 1, true) then return true end
  end
end)())
reset(0)
for i = 1, 4 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("a list that fits says nothing about hiding", (function()
  for _, e in ipairs(drawn) do
    if e.type == "text" and e.text:find("showing", 1, true) then return false end
  end
  return AT.session.hidden == 0
end)())
resolveBaseScreen = function() return { frame = function() return { x=0, y=0, w=3840, h=2160 } end } end

-- =====================================================================
out("\n=== 11. Arrow navigation across the grid (6.44.0) ===\n")
-- ⇪ Six columns, 14 windows: rows of 6, 6 and 2.
resolveBaseScreen = function() return { frame = function() return { x=0, y=0, w=3840, h=2160 } end } end
reset(0)
for i = 1, 14 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("a 14-window list lays out 6 columns", AT.session.cols == 6, AT.session.cols)
check("...and records its row count for the ↑↓ maths", AT.session.rows == 3, AT.session.rows)

local function navKey(mask, key)
  for _, hk in ipairs(NAVKEYS) do
    if hk.mask == mask and hk.key == key then return hk end
  end
end

check("→ is registered", navKey("alt", "right") ~= nil)
check("← is registered", navKey("alt", "left") ~= nil)
check("↑ is registered", navKey("alt", "up") ~= nil)
check("↓ is registered", navKey("alt", "down") ~= nil)
check("Home and End are registered",
  navKey("alt", "home") ~= nil and navKey("alt", "end") ~= nil)
check("Return commits without waiting for the ⌥ release",
  navKey("alt", "return") ~= nil)

-- ⚠️ THE MODIFIER-MASK BUG. hs.hotkey matches flags EXACTLY, and the HUD
-- only exists while ⌥ is held, so a key registered under the bare {} mask
-- can never fire during a session. Esc was registered that way until
-- 6.44.0 and therefore never worked mid-hold.
check("🐛 Esc is registered for the ⌥ mask, not only the bare one",
  navKey("alt", "escape") ~= nil)
check("...and for ⌥⇧ too, since ⌥⇧Tab leaves ⇧ down",
  navKey("alt+shift", "escape") ~= nil)
check("...and every arrow carries all four masks", (function()
  for _, mask in ipairs({ "", "alt", "shift", "alt+shift" }) do
    for _, k in ipairs({ "left", "right", "up", "down" }) do
      if not navKey(mask, k) then return false end
    end
  end
  return true
end)())

check("the nav keys are ARMED while the HUD is up", navKey("alt", "right").on == true)

AT.session.index = 1
navKey("alt", "right").fire()
check("→ steps one tile", AT.session.index == 2, AT.session.index)
navKey("alt", "left").fire()
check("← steps back", AT.session.index == 1, AT.session.index)
navKey("alt", "left").fire()
check("← wraps to the end, like Tab", AT.session.index == 14, AT.session.index)
navKey("alt", "right").fire()
check("→ wraps to the start", AT.session.index == 1, AT.session.index)

AT.session.index = 1
navKey("alt", "down").fire()
check("↓ jumps a WHOLE ROW, not one tile", AT.session.index == 7, AT.session.index)
navKey("alt", "down").fire()
check("...and again", AT.session.index == 13, AT.session.index)
navKey("alt", "up").fire()
check("↑ comes back a row", AT.session.index == 7, AT.session.index)

AT.session.index = 3
navKey("alt", "down").fire()
check("↓ from the middle of row 1 lands in the same column of row 2",
  AT.session.index == 9, AT.session.index)
navKey("alt", "down").fire()
check("↓ into the RAGGED last row lands on the nearest real tile in that "
   .. "row, not on a cell that does not exist", AT.session.index == 14, AT.session.index)
navKey("alt", "down").fire()
check("...and then stops: there is no row below the bottom one",
  AT.session.index == 14, AT.session.index)
AT.session.index = 3
navKey("alt", "up").fire()
check("↑ on the TOP row does nothing — it does not teleport to tile 1",
  AT.session.index == 3, AT.session.index)
AT.session.index = 9
navKey("alt", "up").fire()
check("...but ↑ from row 2 keeps the column", AT.session.index == 3, AT.session.index)

navKey("alt", "end").fire()
check("End goes to the last tile", AT.session.index == 14, AT.session.index)
navKey("alt", "home").fire()
check("Home goes to the first", AT.session.index == 1, AT.session.index)

check("holding an arrow repeats (a held ↓ keeps moving)",
  navKey("alt", "down").repeatFn ~= nil)
check("...but Return does NOT repeat — a repeat would commit twice",
  navKey("alt", "return").repeatFn == nil)
check("...and neither does Esc", navKey("alt", "escape").repeatFn == nil)

AT.session.index = 5
navKey("alt", "return").fire()
check("Return switches to the highlighted window", focused == 5, focused)
check("...and closes the HUD", AT.session == nil)
check("🔑 every nav key is DISARMED when the HUD closes, so the arrow keys "
   .. "are untouched the rest of the time", (function()
  for _, hk in ipairs(NAVKEYS) do if hk.on then return false end end
  return true
end)())

reset(0)
for i = 1, 3 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("a single-row HUD reports one row", AT.session.rows == 1, AT.session.rows)
AT.session.index = 2
navKey("alt", "down").fire()
check("↓ on a single row does nothing rather than jumping randomly",
  AT.session.index == 2, AT.session.index)
check("...and the footer does not advertise ↑↓ when there is only one row",
  (function()
    for _, e in ipairs(drawn) do
      if e.type == "text" and e.text:find("↑↓ row", 1, true) then return false end
    end
    return true
  end)())
AT.finish(false)

-- =====================================================================
out("\n=== 12. Screen Recording: the one permission this config needs ===\n")
-- 🔐 w:snapshot() photographs another app's window, which macOS treats as
-- a screen capture — it is the ONLY call in the whole config that makes
-- the Screen Recording prompt appear. On a managed Mac where that cannot
-- be granted, altTab.useSnapshots = false avoids ever asking.
reset(4)
combos["alt+tab"]()
check("with snapshots ON, windows really are photographed", SNAPSHOT_CALLS > 0,
  SNAPSHOT_CALLS)
check("...and the tiles show those photographs",
  AT.session.items[1].image == "snap:1", tostring(AT.session.items[1].image))
AT.finish(false)

reset(4)
AT.useSnapshots = false
combos["alt+tab"]()
check("🔐 with the switch OFF, snapshot() is never called even once — so "
   .. "macOS is never asked for Screen Recording", SNAPSHOT_CALLS == 0, SNAPSHOT_CALLS)
check("...the switcher still opens with every window", #AT.session.items == 4)
check("...and every tile falls back to its app icon",
  AT.session.items[1].image == "icon:com.test.App1",
  tostring(AT.session.items[1].image))
check("...so nothing about switching windows is lost", AT.session.index == 2)
AT.finish(false)

-- =====================================================================
out("\n=== 13. 6.68.0 — the switch actually switches ===\n")
-- LL: "Alt+tab does not reliably bring me to the select app or do it
-- consistently." Three separate causes, one section each.

out("\n  13a. the owning app is ACTIVATED, not just the window raised\n")
reset(4)
combos["alt+tab"]()                       -- index 2 → App2
MODS = {}; timer.fn()
check("the window is focused", focused == 2, focused)
check("🚨 AND ITS APPLICATION IS ACTIVATED. hs.window:focus() is "
   .. "becomeMain()+raise(); both act INSIDE the owning app and neither "
   .. "brings it forward, which is the whole bug", ACTIVATED == "App2", ACTIVATED)
check("becomeMain and raise still happen too", MAINED == 2 and RAISED == 2,
      tostring(MAINED) .. "/" .. tostring(RAISED))

out("\n  13b. the switch is VERIFIED, and reports when it fails\n")
reset(4)
combos["alt+tab"]()
FRONTWIN = nil                            -- nothing came forward
MODS = {}; timer.fn()
check("a verifier is queued rather than assuming it worked", #PENDING > 0, #PENDING)
FRONTWIN = WINS[2]                        -- ...but it did land
runPending()
check("a confirmed switch is silent", not logged("but the focus stayed on"))
check("...and recorded", _G.altTabLastSwitch and _G.altTabLastSwitch.ok == true,
      _G.altTabLastSwitch and tostring(_G.altTabLastSwitch.ok))

reset(4)
combos["alt+tab"]()
MODS = {}; timer.fn()
FRONTWIN = WINS[4]                        -- macOS put someone ELSE in front
runPending()
check("🚨 A SWITCH THAT DID NOT TAKE IS REPORTED, not swallowed (rule 7)",
      logged("but the focus stayed on"), table.concat(log, " | "):sub(1, 120))
check("...it retried before giving up", _G.altTabLastSwitch
      and _G.altTabLastSwitch.attempts == 2,
      _G.altTabLastSwitch and tostring(_G.altTabLastSwitch.attempts))
check("...and the report names both apps", logged("App2") and logged("App4"))

out("\n  13c. unminimizing waits for the animation\n")
reset(3)
local hidden = mkwin(80, "Hidden", "Minimised", true)
table.insert(WINS, hidden); APPS = appsFromWindows(WINS)
combos["alt+tab"]()
for i, it in ipairs(AT.session.items) do
  if it.win and it.win:id() == 80 then AT.jumpTo(i) end
end
MODS = {}; timer.fn()
check("unminimize was called", unminimized == 80, unminimized)
check("🚨 BUT FOCUS DID NOT FIRE IN THE SAME TICK — the genie animation "
   .. "is still running and a focus() there is simply dropped",
      focused == nil, focused)
FRONTWIN = hidden
runPending()
check("...it lands once the animation has had its beat", focused == 80, focused)

out("\n  13d. the stale-cache switch, which is the 'twice in a row' bug\n")
reset(5)
combos["alt+tab"]()
MODS = {}; timer.fn()
runPending()
check("🚨 THE CACHE IS DROPPED ON A SWITCH. It is keyed on TIME alone, and "
   .. "front-to-back order is exactly what a switch changes — so a second "
   .. "⌥Tab inside 4s reused a list where you were already position 2",
      AT.cache == nil, tostring(AT.cache))
reset(5)
combos["alt+tab"]()
AT.escKey.fire()                          -- cancelled, nothing changed
check("...but CANCELLING keeps it, because nothing moved", AT.cache ~= nil)

out("\n  13e. the first tile is anchored to the window you are IN\n")
reset(5)
FRONTWIN = WINS[3]                        -- you are in window 3, not window 1
combos["alt+tab"]()
check("🎯 opens on the tile AFTER the front window, wherever it sits in "
   .. "the list — `index = 2` assumed the list always starts with you",
      AT.session.index == 4, AT.session.index)
AT.finish(false)

reset(5)
FRONTWIN = WINS[3]
combos["alt+shift+tab"]()
check("⌥⇧Tab steps back from where you are", AT.session.index == 2, AT.session.index)
AT.finish(false)

reset(5)
FRONTWIN = WINS[1]
combos["alt+shift+tab"]()
check("...wrapping past the front of the list", AT.session.index == 5, AT.session.index)
AT.finish(false)

reset(5)
FRONTWIN = mkwin(999, "Elsewhere", "not in the list")
combos["alt+tab"]()
check("a front window that is not listed falls back to the old behaviour",
      AT.session.index == 2, AT.session.index)
AT.finish(false)

out("\n  13f. the panel level is shared, not hand-typed\n")
check("the HUD asks _G.panelLevel rather than naming `overlay` itself",
  (function()
    local f = io.open(HS .. "/modules/window_switcher.lua"); local s = f:read("*a"); f:close()
    -- Comments are stripped: an explanatory comment mentioning the helper
    -- silenced this exact class of check twice before (6.66.2, 6.66.3).
    s = s:gsub("%-%-[^\n]*", "")
    return s:find("panelLevel(\"switcher\")", 1, true) ~= nil
  end)())

out("\n=== 14. 6.90.0 — the card wears the shared style ===\n")
-- Publish a style table the way modules/ui_style.lua does and redraw:
-- the HUD's card must take it (same tables, not copies). Without one —
-- every section above — it fell back to its own literals, so both
-- halves of the contract are now proven.
_G.uiStyle = {
  bg         = { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 },
  stroke     = { white = 1.00, alpha = 0.18 },
  radius     = 12,
  selectLine = { red = 0.45, green = 0.72, blue = 1.00, alpha = 0.95 },
}
reset(3)
combos["alt+tab"]()
check("🎨 the card takes _G.uiStyle.bg — the FOCUS card's color",
  drawn and drawn[1] and drawn[1].fillColor == _G.uiStyle.bg)
check("...the shared hairline stroke", drawn[1].strokeColor == _G.uiStyle.stroke)
check("...and the shared 12px corners",
  drawn[1].roundedRectRadii and drawn[1].roundedRectRadii.xRadius == 12)
check("the selected tile's border is the shared selection blue", (function()
  for _, e in ipairs(drawn) do
    if e.strokeColor == _G.uiStyle.selectLine then return true end
  end
  return false
end)())
_G.uiStyle = nil

out("\n=== 14. 6.147.0 — the Hammerspoon Console is a tile ===\n")
-- LL: "Can I use alt+tab to land on the Hammerspoon console?" The
-- console slips both of the module's nets — Hammerspoon is a menu-bar
-- app (never asked by the kind == 1 pass) and the console window can
-- answer isStandard() = false — so it is asked for BY NAME.
reset(2)
local CONSOLE = mkwin(999, "Hammerspoon", "Hammerspoon Console", false, false)
hs.console = { hswindow = function() return CONSOLE end }
check("an open console is listed even though isStandard() is false and "
      .. "no kind-1 app owns it", (function()
    for _, e in ipairs(AT.listWindows()) do
        if e.win and e.win:id() == 999 then return true end
    end
    return false
end)())
hs.console = { hswindow = function() return nil end }
AT.cache = nil
check("a CLOSED console is not a tile — it is a tool you have not opened",
      (function()
    for _, e in ipairs(AT.listWindows()) do
        if e.win and e.win:id() == 999 then return false end
    end
    return true
end)())
local MINI_CONSOLE = mkwin(998, "Hammerspoon", "Hammerspoon Console", true, false)
hs.console = { hswindow = function() return MINI_CONSOLE end }
AT.cache = nil
AT.includeMinimized = false
check("a minimised console honours includeMinimized like every window",
      (function()
    for _, e in ipairs(AT.listWindows()) do
        if e.win and e.win:id() == 998 then return false end
    end
    return true
end)())
AT.includeMinimized = true
hs.console = nil

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
