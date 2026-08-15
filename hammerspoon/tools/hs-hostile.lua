-- =====================================================================
-- DEEP PASS: THE HOSTILE ENVIRONMENT
-- =====================================================================
-- Every suite in tests/ stubs `hs` to behave WELL. That proves the happy
-- path and says nothing about the Mac where the pasteboard is empty, the
-- screen list is empty, Accessibility is off, a file will not open and
-- every API answers nil.
--
-- This loads all 34 shipped modules for real and runs setup() and warm()
-- against three progressively worse worlds:
--
--   1. EMPTY    every API answers nil / {} / "" — the shapes a real Mac
--               produces at login, during a display change, on a locked
--               screen, or with permissions withheld.
--   2. THROWING every API raises. Models a wedged AX call, a dead
--               pasteboard server, an ObjC exception surfaced as a Lua
--               error.
--   3. MISSING  whole hs.* extensions are absent. Models an older
--               Hammerspoon or a stripped build.
--
-- A module that THROWS here is not automatically broken — the loader
-- pcalls setup() and warm(), so the config survives. But a throw means
-- it did not DEGRADE, and LL's standing requirement is that a failure
-- must not ruin, stop or interfere with anything else. A module that
-- throws halfway through setup() has already bound some keys and may
-- have left a tap running with nothing holding it.
--
-- Usage: tools/hs-hostile.lua <hammerspoon dir> [empty|throw|missing]
--
-- 📊 HOW TO READ THE RESULT, because two of the three modes are meant to
-- produce findings and one is not:
--
--   EMPTY is a GATE. Every one of these shapes happens on a real Mac —
--   no screens attached mid-switch, an empty pasteboard, Accessibility
--   withheld, a folder that is not there. A module that throws here
--   throws on somebody's Monday morning. run-tests.sh fails on it.
--
--   THROW and MISSING are a REGISTER, not a to-do list. They make
--   hs.hotkey.bind and hs.chooser.new raise, which does not happen on a
--   working Mac — so ~19 modules "failing" there is expected and
--   wrapping every one of those calls in a pcall would be noise with no
--   reader. What they are FOR is the shape of the failure: check that a
--   module throws at CREATION (nothing started yet) rather than after it
--   has already started a tap or a watcher, which would leave a live
--   resource behind a dead module. Read the line numbers, not the count.
-- =====================================================================

local HS   = arg[1] or "."
local MODE = arg[2] or "empty"

local calls, thrown = {}, {}

-- A table that answers ANY key with a function, so a module can call
-- something this harness never thought of and still get the world's
-- current behaviour rather than an "attempt to call a nil value".
local function world()
  local function answer(name)
    return function(...)
      calls[name] = (calls[name] or 0) + 1
      if MODE == "throw" then
        thrown[name] = true
        error("hostile: " .. name .. " refuses", 2)
      end
      return nil
    end
  end
  local cache = {}
  local function node(prefix)
    if cache[prefix] then return cache[prefix] end
    local t = {}
    cache[prefix] = t
    setmetatable(t, {
      __index = function(_, k)
        if type(k) ~= "string" then return nil end
        -- Anything that looks like a namespace gets another node; the
        -- leaf decision is made lazily by whether it is called or indexed.
        local child = node(prefix .. "." .. k)
        local f = answer(prefix .. "." .. k)
        return setmetatable({}, {
          __call  = function(_, ...) return f(...) end,
          __index = function(_, k2) return child[k2] end,
          __newindex = function(_, k2, v) rawset(child, k2, v) end,
        })
      end,
      __newindex = function(_, k, v) rawset(t, k, v) end,
    })
    return t
  end
  return node("hs")
end

hs = world()

-- The handful of values a module reads rather than calls. In EMPTY mode
-- these are the shapes a real Mac genuinely produces.
hs.configdir = "/tmp/hostile-hs"
os.execute("mkdir -p /tmp/hostile-hs")
if MODE ~= "missing" then
  hs.timer = {
    secondsSinceEpoch = function() return 1000 end,
    doAfter  = function() return { stop = function() end } end,
    doEvery  = function() return { stop = function() end } end,
    doAt     = function() return { stop = function() end } end,
    usleep   = function() end,
    new      = function() return { start = function() end, stop = function() end } end,
  }
  hs.keycodes = { map = setmetatable({}, { __index = function() return nil end }) }
  hs.canvas   = { new = function() return nil end, windowLevels = {} }
  hs.screen   = { allScreens = function() return {} end,
                  mainScreen = function() return nil end,
                  watcher = { new = function()
                     return { start = function() end, stop = function() end } end } }
  hs.window   = { orderedWindows = function() return {} end,
                  allWindows = function() return {} end,
                  focusedWindow = function() return nil end,
                  find = function() return nil end }
  hs.application = { runningApplications = function() return {} end,
                     frontmostApplication = function() return nil end,
                     get = function() return nil end,
                     watcher = { new = function()
                        return { start = function() end, stop = function() end } end,
                        activated = 1, deactivated = 2, launched = 3, terminated = 4 } }
  hs.fs = {
    attributes = function() return nil end,
    mkdir = function() return false end,
    dir = function() error("hostile: no such directory", 2) end,
    currentDir = function() return "/tmp" end,
  }
  hs.pasteboard = { getContents = function() return nil end,
                    readString  = function() return nil end,
                    readImage   = function() return nil end,
                    readAllData = function() return nil end,
                    setContents = function() return false end,
                    changeCount = function() return 0 end }
  hs.json = { decode = function() error("hostile: not json", 2) end,
              encode = function() return "{}" end }
  hs.eventtap = {
    new = function() return { start = function() end, stop = function() end,
                              isEnabled = function() return false end } end,
    keyStroke = function() end, keyStrokes = function() end,
    leftClick = function() end,
    checkKeyboardModifiers = function() return {} end,
    event = { types = { keyDown = 10, keyUp = 11, flagsChanged = 12,
                        leftMouseDown = 1, rightMouseDown = 3,
                        leftMouseDragged = 6, leftMouseUp = 2,
                        scrollWheel = 22, mouseMoved = 5 },
              properties = { keyboardEventAutorepeat = 8 },
              newKeyEvent = function() return { post = function() end } end },
  }
  hs.hotkey = {
    bind = function() return { enable = function() end, disable = function() end } end,
    new  = function() return { enable = function() end, disable = function() end } end,
    modal = { new = function()
      return { bind = function(s) return s end, enter = function() end,
               exit = function() end } end },
  }
  hs.chooser = { new = function()
    return setmetatable({}, { __index = function() return function(s) return s end end }) end }
  hs.alert  = { show = function() end, closeAll = function() end }
  hs.settings = { get = function() return nil end, set = function() end }
  hs.host = { idleTime = function() return 0 end, localizedName = function() return "Hostile" end }
  hs.execute = function() return "", false, "exit", 1 end
  hs.osascript = { applescript = function() return false, nil, nil end }
  hs.task = { new = function() return nil end }
  hs.mouse = { absolutePosition = function() return { x = 0, y = 0 } end,
               getRelativePosition = function() return { x = 0, y = 0 } end }
  hs.accessibilityState = function() return false end
  hs.axuielement = { applicationElement = function() return nil end,
                     systemWideElement = function() return nil end }
  hs.image = { imageFromAppBundle = function() return nil end,
               imageFromPath = function() return nil end }
  hs.menubar = { new = function() return nil end }
  hs.notify = { new = function() return nil end }
  hs.http = { asyncGet = function() end, asyncPost = function() end,
              get = function() return 0, "", {} end }
  hs.dialog = { textPrompt = function() return "Cancel", "" end,
                blockAlert = function() return "Cancel" end }
  hs.spaces = { focusedSpace = function() return nil end }
  hs.audiodevice = { defaultInputDevice = function() return nil end,
                     defaultOutputDevice = function() return nil end }
  hs.caffeinate = { watcher = { new = function()
    return { start = function() end, stop = function() end } end,
    screensDidLock = 1, screensDidUnlock = 2, systemDidWake = 3 } }
  hs.pathwatcher = { new = function()
    return { start = function() end, stop = function() end } end }
  hs.styledtext = { new = function(s) return s end }
  hs.drawing = { windowLevels = {} }
  hs.fnutils = { each = function() end, map = function() return {} end }
  hs.sound  = { getByName = function() return nil end }
  hs.spoons = {}
  hs.doc = {}
  hs.inspect = function(x) return tostring(x) end
end

-- 🚨 IN THROW MODE, MAKE THE CONCRETE STUBS THROW TOO. The first version
-- of this harness only made the AUTO-GENERATED metatable functions raise
-- — and every API a module actually uses had been given a well-behaved
-- concrete stub above, so THROW mode passed while testing almost nothing.
-- A harness that reports a clean run because it forgot to be hostile is
-- the same failure as a stub more forgiving than its API.
if MODE == "throw" then
  local function poison(t, prefix, seen)
    seen = seen or {}
    if seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
      local path = prefix .. "." .. tostring(k)
      if type(v) == "function" then
        rawset(t, k, function() error("hostile: " .. path .. " refuses", 2) end)
      elseif type(v) == "table" then
        poison(v, path, seen)
      end
    end
  end
  -- Everything EXCEPT the event-type constants, which are values a module
  -- compares against rather than behaviour it depends on. Poisoning those
  -- tests nothing and only produces noise.
  local keepTypes = hs.eventtap and hs.eventtap.event
  poison(hs, "hs", nil)
  if keepTypes then
    hs.eventtap.event.types = { keyDown = 10, keyUp = 11, flagsChanged = 12,
                                leftMouseDown = 1, rightMouseDown = 3,
                                leftMouseDragged = 6, leftMouseUp = 2,
                                scrollWheel = 22, mouseMoved = 5 }
    hs.eventtap.event.properties = { keyboardEventAutorepeat = 8 }
  end
  hs.configdir = "/tmp/hostile-hs"
end

-- 🚨 IN MISSING MODE, WHOLE EXTENSIONS ARE GONE — not present-but-useless.
-- Models an older Hammerspoon or a stripped build, where `hs.canvas` is
-- nil and indexing it throws rather than answering nil.
if MODE == "missing" then
  for _, ext in ipairs({ "canvas", "chooser", "axuielement", "menubar",
                         "notify", "spaces", "audiodevice", "webview",
                         "styledtext", "pathwatcher", "caffeinate" }) do
    rawset(hs, ext, nil)
  end
  rawset(hs, "screen", { allScreens = function() return {} end,
                         mainScreen = function() return nil end,
                         watcher = { new = function()
                           return { start = function() end } end } })
end

-- The globals a module may legitimately expect init.lua to have set.
_G.diag = { say = function() end, warn = function() end, err = function() end,
            mark = function() end, verbose = false, trail = {}, errors = {},
            marks = {} }
_G.notices = { record = function() end, tell = function() end, list = function() return {} end }
_G.service = { registry = {}, has = function() return false end,
               call = function() return nil end,
               provide = function(n, f) _G.service.registry[n] = f end }
_G.typingInjection = function() return false end
_G.withInjection = function(fn) return pcall(fn) end
_G.panelLevel = function() return 102 end
_G.showCanvasSafely = function() return false end
_G.clampToScreen = function(p) return p end
_G.makeCanvasDraggable = function() return false end
_G.pasteboardSuppress = function() end
_G.claimEscape = function() return true end
_G.routeEscape = function() return nil end
_G.hyperActive = false
_G.hyperBound, _G.hyperBoundCount, _G.hyperConflictCount = {}, 0, 0
-- init.lua creates these before modules load; several modules index them
-- directly. Provided here so the harness reproduces the real environment
-- rather than inventing a stricter one.
_G.choosers = {}
-- §3.12 publishes this before modules load. document_watcher is the only
-- module that reaches for the GLOBAL rather than taking it from `core` —
-- noted as an inconsistency, provided here so the harness reproduces the
-- real world instead of inventing a stricter one.
_G.hyperAddShortcut = function() end
_G.cheatSheet = { groups = function() return {} end, custom = {} }
_G.moduleLoaded, _G.moduleFailed = 0, 0

local realPrint = print
print = function() end

local core = {
  logsDir = "/tmp/hostile-hs", backupDir = "/tmp/hostile-hs",
  cloudDir = nil, hostTag = "Hostile", asanaEnabled = false,
  configDir = "/tmp/hostile-hs",
  popupKeys = { mods = { "ctrl", "alt", "cmd" } },
  popupScreenKeys = { mods = { "ctrl", "alt", "cmd" } },
  provide = function(n, f) _G.service.registry[n] = f end,
  hyperAddShortcut = function() end,
  resolveBaseScreen = function() return nil end,
  adoptLegacyFile = function() end,
  warnWriteFailed = function() end,
  splitCSVLine = function() return {} end,
  asanaRequest = function() end,
  diag = _G.diag,
}

local p = io.popen("ls " .. HS .. "/modules/*.lua")
local mods = {}
for l in p:lines() do mods[#mods + 1] = l end
p:close()

local bad = {}
for _, path in ipairs(mods) do
  local name = path:match("([%w_]+)%.lua$")
  local okLoad, mod = pcall(dofile, path)
  if not okLoad then
    bad[#bad + 1] = { name, "load", tostring(mod) }
  elseif type(mod) ~= "table" or type(mod.setup) ~= "function" then
    bad[#bad + 1] = { name, "contract", "no setup()" }
  else
    local okSetup, err = pcall(mod.setup, core)
    if not okSetup then
      bad[#bad + 1] = { name, "setup", tostring(err) }
    elseif type(mod.warm) == "function" then
      local okWarm, werr = pcall(mod.warm, core)
      if not okWarm then bad[#bad + 1] = { name, "warm", tostring(werr) } end
    end
  end
end

print = realPrint
print(("── HOSTILE WORLD: %s — %d modules, %d that did not degrade ──")
      :format(MODE:upper(), #mods, #bad))
for _, b in ipairs(bad) do
  print(("  ❌ %-20s %-8s %s"):format(b[1], b[2], b[3]:sub(1, 96)))
end
if #bad == 0 then print("  ✅ every module degraded without throwing") end
os.exit(#bad == 0 and 0 or 1)
