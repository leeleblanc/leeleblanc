-- Harness for §1.10. Runs the shipped code against a stubbed hs whose
-- windows, clock and modifier state are all under the test's control.
local bound, log = {}, {}
local NOW = 1000
local FAIL = { list = false, canvas = false, snapshot = false }
local COUNT = { ordered = 0, all = 0, apps = 0, canvasNew = 0, deleted = 0, alerts = 0 }
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
    if FAIL.snapshot then error("no snapshot") end
    return snap ~= false and ("snap:" .. id) or nil
  end
  function w:unminimize() unminimized = id end
  function w:focus() focused = id end
  function w:application()
    return { name = function() return app end,
             bundleID = function() return "com.test." .. app end }
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
  function a:allWindows() return wins or {} end
  function a:activate() ACTIVATED = name end
  return a
end
hs = {
  window = {
    orderedWindows = function()
      COUNT.ordered = COUNT.ordered + 1
      if FAIL.list then error("AX timeout") end
      local out = {}
      -- only windows flagged as being on the CURRENT space, and not minimised
      for _, w in ipairs(WINS) do
        if not w:isMinimized() and w.space ~= "other" then table.insert(out, w) end
      end
      return out
    end,
    allWindows = function() COUNT.all = COUNT.all + 1; return WINS end,
  },
  application = { runningApplications = function() COUNT.apps = COUNT.apps + 1; return APPS end },
  timer = {
    secondsSinceEpoch = function() return NOW end,
    doEvery = function(interval, fn)
      timer = { interval = interval, fn = fn, running = true }
      function timer:stop() self.running = false end
      return timer
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
    new = function(mods, key, fn)
      local hk = { key = key, fire = fn, on = false }
      function hk:enable() self.on = true; return hk end
      function hk:disable() self.on = false; return hk end
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
local mod = dofile("BLOCK_PATH")
-- resolveBaseScreen is looked up at CALL time, not captured, so the
-- small-screen test below can swap the screen out from under it.
mod.setup({ resolveBaseScreen = function(...) return resolveBaseScreen(...) end,
            diag = _G.diag })
local AT = mod.altTab

local out = io.write
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
  ACTIVATED = nil
  FAIL.list, FAIL.canvas, FAIL.snapshot = false, false, false
  focused, unminimized, drawn, timer, log = nil, nil, nil, nil, {}
  MODS = { alt = true }; NOW = 1000
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

out("\n=== 7. EVERY window: other Spaces, monitors, minimised ===\n")
reset(3)
local far = mkwin(90, "FarApp", "On another desktop"); far.space = "other"
local mini = mkwin(91, "MiniApp", "Minimised one", true)
table.insert(WINS, far); table.insert(WINS, mini)
APPS = appsFromWindows(WINS)
combos["alt+tab"]()
check("windows on ANOTHER Space are listed (the 6.39.0 fix)", (function()
  for _, i in ipairs(AT.session.items) do if i.win and i.win:id() == 90 then return true end end
end)(), #AT.session.items .. " items")
check("minimised windows are listed", (function()
  for _, i in ipairs(AT.session.items) do if i.win and i.win:id() == 91 then return true end end
end)())
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
check("includeOtherSpaces = false goes back to this Space only", (function()
  reset(3)
  local f2 = mkwin(92, "FarApp", "Other desktop"); f2.space = "other"
  table.insert(WINS, f2); APPS = appsFromWindows(WINS)
  AT.includeOtherSpaces, AT.includeApps = false, false
  combos["alt+tab"]()
  for _, i in ipairs(AT.session.items) do if i.win and i.win:id() == 92 then return false end end
  return true
end)())

out("\n=== 7b. Running apps with no window at all ===\n")
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

out("\n=== 8. Bounded cost ===\n")
reset(0)
for i = 1, 100 do table.insert(WINS, mkwin(i, "App" .. i, "W" .. i)) end
combos["alt+tab"]()
check("window list capped at maxWindows", #AT.session.items == AT.maxWindows, #AT.session.items)
check("grid never exceeds maxCols", AT.session.cols <= AT.maxCols, AT.session.cols)
check("HUD fits on the screen", AT.session.w <= 3840 and AT.session.h <= 2160,
      AT.session.w .. "x" .. AT.session.h)

out("\n=== 9. Slow machines report a number, not a beachball ===\n")
reset(5)
local realNow = hs.timer.secondsSinceEpoch
local step = 0
hs.timer.secondsSinceEpoch = function() step = step + 1; return 1000 + (step > 1 and 2.5 or 0) end
combos["alt+tab"]()
check("a slow enumeration is timed and reported", logged("took"), log[1])
check("...and says which knobs to turn", logged("includeOtherSpaces"))
hs.timer.secondsSinceEpoch = realNow

out("\n=== 10. Failures degrade, they don't hang or crash ===\n")
reset(5); FAIL.list = true
local ok = pcall(function() combos["alt+tab"]() end)
check("an AX failure on this Space does not throw", ok)
check("...is explained in the Console", logged("could not list windows on this Space"))
check("...and the per-app sweep still supplies the list (6.39.0: degrades "
      .. "to fewer windows rather than none)", AT.session ~= nil and #AT.session.items == 5,
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
combos["alt+tab"]()
check("a list that fits says nothing about hiding", (function()
  for _, e in ipairs(drawn) do
    if e.type == "text" and e.text:find("showing", 1, true) then return false end
  end
  return AT.session.hidden == 0
end)())
resolveBaseScreen = function() return { frame = function() return { x=0, y=0, w=3840, h=2160 } end } end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
