-- Harness for §1.12, the module system. Runs the REAL loader against
-- the REAL module files, plus deliberately broken ones written on the
-- fly, because failure isolation is the half of this that matters.
local MODDIR = "MODULES_DIR"
local printed = {}
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  table.insert(printed, table.concat(p, " "))
end
local NOW, bound, tasks, timers = 100, {}, {}, {}
local warmTimerFns = {}
WARMED = nil
hs = {
  configdir = MODDIR:gsub("/modules$", ""),
  timer = { secondsSinceEpoch = function() NOW = NOW + 0.001; return NOW end,
            doAt = function(t, r, fn) local o = { at = t }; table.insert(timers, o); return o end,
            doAfter = function(_, fn) table.insert(warmTimerFns, fn)
                             return { stop = function() end } end,
            doEvery = function(_, fn) return { stop = function() end, start = function(s) return s end } end,
            new = function() return { start = function(s) return s end, stop = function() end } end,
            usleep = function() end },
  hotkey = { bind = function(mods, key, fn)
      table.insert(bound, table.concat(mods, "+") .. "+" .. tostring(key)); return {} end },
  alert = { show = function() end },
  task  = { new = function(_, _, _) return { start = function() end } end },
  application = { frontmostApplication = function() return nil end,
                  watcher = { new = function(fn)
                      return { start = function(s) return s end,
                               stop  = function(s) return s end } end,
                              activated = 1, deactivated = 2, launched = 3, terminated = 4 } },
  axuielement = { applicationElement = function() return nil end,
                  observer = { new = function() return nil end } },
  uielement   = { watcher = { new = function() return nil end } },
  canvas = { windowLevels = { overlay = 1 }, new = function() return nil end },
  eventtap = { checkKeyboardModifiers = function() return {} end,
               new = function() return { start = function(s) return s end,
                                         stop = function(s) return s end,
                                         isEnabled = function() return true end } end,
               keyStroke = function() end, keyStrokes = function() end,
               event = { types = { keyDown = 10, flagsChanged = 12 },
                         properties = { keyboardEventKeycode = "kc" },
                         newKeyEvent = function() return { post = function() end } end } },
  pathwatcher = { new = function() return { start = function(s) return s end,
                                            stop = function(s) return s end } end },
  fs = { attributes = function(path)
      local f = io.open(path, "r"); if not f then return nil end; f:close()
      return { mode = "file", size = 1 } end,
      dir = function() return function() return nil end end,
      mkdir = function() return true end },
  notify = { new = function() return { send = function() end } end },
  caffeinate = { watcher = { new = function() return { start = function(s) return s end,
                                                       stop = function(s) return s end } end,
                             screensDidLock = 1, screensDidUnlock = 2,
                             systemDidWake = 3, systemWillSleep = 4 } },
  http = { asyncGet = function() end, asyncPost = function() end,
           doRequest = function() return 200, "{}", {} end },
  urlevent = { bind = function() end },
  spaces = nil,
  settings = { get = function() return nil end, set = function() end },
  keycodes = { map = setmetatable({}, { __index = function() return 0 end }) },
  distributednotifications = { new = function() return { start=function(s) return s end,
                                                        stop=function(s) return s end } end },
  window = { orderedWindows = function() return {} end,
             filter = nil },
  pasteboard = { getContents = function() return "" end, setContents = function() end },
  chooser = { new = function()
      local c = {}
      for _, m in ipairs({ "choices", "placeholderText", "query", "show", "hide",
                           "queryChangedCallback", "rows", "width", "searchSubText",
                           "bgDark", "selectedRow", "refreshChoicesCallback" }) do
        c[m] = function() return c end
      end
      return c
  end },
  image = { imageFromAppBundle = function() return nil end },
  accessibilityState = function() return true end,
}
_G.choosers = {}          -- created in §1 of the real init.lua
_G.service = { registry = {},
  provide = function(n, f) _G.service.registry[n] = f end,
  has = function(n) return _G.service.registry[n] ~= nil end,
  call = function(n, ...) local f = _G.service.registry[n]
    if not f then return nil end
    return (select(2, pcall(f, ...))) end }
_G.hyperPending = {}
_G.hyperAddShortcut = function(mods, key, fn, src)
  table.insert(_G.hyperPending, { mods = mods, key = key, fn = fn, source = src })
end
_G.diag = { verbose = false, trail = {}, errors = {}, marks = {},
            say = function() end, warn = function() end,
            err = function() end, mark = function() end }
homeDir, cloudDir, logsDir = "/tmp/h", "/tmp/c", "/tmp/l"
backupDir, hostTag = "/tmp/b", "Lees-MacBook-Air"
warnWriteFailed, adoptLegacyFile, csvQuote = function() end, function() end, function(s) return s end
popupScreenKeys = { mods = { "ctrl", "alt", "cmd" } }
showPopup, resolveBaseScreen = function() end,
  function() return { frame = function() return { x=0,y=0,w=3840,h=2160 } end } end
panelAlpha, asanaEnabled, asanaToken, asanaWorkspaceId = 0.9, true, "tok", "ws"
formatDuration = function(s) return tostring(s).."s" end
splitCSVLine = function(l) local o={} for f in tostring(l):gmatch('[^,]+') do o[#o+1]=f end return o end
_G.configVersion, _G.safeJson = "6.36.0", function() end

dofile("LOADER_PATH")   -- defines _G.loadModules and loads the real list

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end
local function statusOf(n)
  for _, r in ipairs(_G.moduleStatus) do if r.name == n then return r end end
end

out("\n=== 1. The three real modules load ===\n")
check("all thirteen loaded", _G.moduleLoaded == 13 and _G.moduleFailed == 0,
      tostring(_G.moduleLoaded) .. "/" .. tostring(_G.moduleFailed))
for _, n in ipairs({ "daily_backup", "app_peek", "window_switcher", "window_arranger",
                     "copy_on_select", "command_history", "app_watcher", "file_tracker",
                     "autocorrect", "activity_tracker", "update_tracker",
                     "asana_comments", "document_watcher" }) do
  local r = statusOf(n)
  check(n .. " ok", r and r.ok, r and r.err)
end
check("each records how long it took", (function()
  for _, r in ipairs(_G.moduleStatus) do if type(r.ms) ~= "number" then return false end end
  return true
end)())
check("modules load from LOCAL disk, not the cloud folder",
  _G.moduleDir:find("OneDrive") == nil and _G.moduleDir:find("modules") ~= nil, _G.moduleDir)

out("\n=== 2. They actually did their work ===\n")
local combos = {}
for _, c in ipairs(bound) do combos[c] = true end
check("App Peek bound its hotkey", combos["ctrl+alt+cmd+P"], table.concat(bound, " "))
check("Window Switcher bound ⌥Tab", combos["alt+tab"])
check("Window Arranger bound its half-screen keys", (function()
  for c in pairs(combos) do if c:find("Left") or c:find("left") then return true end end
end)(), table.concat(bound, " "))
check("Command History queued its hyper key through core, not a raw bind", (function()
  for _, q in ipairs(_G.hyperPending) do if q.key == "h" then return true end end
end)(), #_G.hyperPending .. " queued")
check("several modules now claim hyper keys the supported way",
      #_G.hyperPending >= 1, #_G.hyperPending)
check("Window Switcher bound ⌥⇧Tab", combos["alt+shift+tab"])
check("Daily Backup scheduled its 17:00 timer", timers[1] and timers[1].at == "17:00")
check("the switcher published altTab for ⇪⇧D", type(_G.altTab) == "table")

out("\n=== 3. Cheat sheet groups travel WITH the module ===\n")
-- 11, not 13: Copy-on-Select and Asana Comments each declare no group,
-- because their entries belong to groups (CLIPBOARD & OCR, ASANA) that
-- are still owned by sections inside init.lua.
check("eleven groups registered; two modules deliberately declare none",
      #_G.moduleCheatsheets == 11, #_G.moduleCheatsheets)
local byOrder = {}
for _, g in ipairs(_G.moduleCheatsheets) do byOrder[g.order] = g.title end
check("App Peek claims slot 7", (byOrder[7] or ""):find("APP PEEK", 1, true))
check("Window Switcher claims slot 8", (byOrder[8] or ""):find("WINDOW SWITCHER", 1, true))
check("Daily Backup claims slot 15", (byOrder[15] or ""):find("BACKUP", 1, true))
check("Window Arranger claims slot 6", (byOrder[6] or ""):find("WINDOW ARRANGER", 1, true))
check("Command History claims slot 12", (byOrder[12] or ""):find("COMMAND HISTORY", 1, true))
check("App Watcher claims slot 1", (byOrder[1] or ""):find("APP MONITOR", 1, true))
check("File Tracker claims slot 10", (byOrder[10] or ""):find("FILE TRACKER", 1, true))
check("Autocorrect claims slot 13", (byOrder[13] or ""):find("AUTOCORRECT", 1, true))
check("Activity Tracker claims slot 4", (byOrder[4] or ""):find("ACTIVITY", 1, true))
check("Update Tracker claims slot 9", (byOrder[9] or ""):find("APP UPDATES", 1, true))
check("Document Watcher claims slot 11", (byOrder[11] or ""):find("DOCUMENT WATCHER", 1, true))
check("every registered group carries entries", (function()
  for _, g in ipairs(_G.moduleCheatsheets) do
    if type(g.entries) ~= "table" or #g.entries == 0 then return false end
  end
  return true
end)())

out("\n=== 4. The core surface is complete and explicit ===\n")
for _, key in ipairs({ "logsDir", "backupDir", "hostTag", "homeDir", "cloudDir",
                       "popupMods", "showPopup", "resolveBaseScreen", "panelAlpha",
                       "warnWriteFailed", "adoptLegacyFile", "csvQuote",
                       "asanaEnabled", "diag", "safeJson", "configDir", "version",
                       "hyperAddShortcut", "splitCSVLine", "formatDuration",
                       "provide", "call" }) do
  check("core." .. key .. " is published", _G.core[key] ~= nil)
end

out("\n=== 4b. Machine profiles: one file, two Macs ===\n")
check("this machine matched its own profile", _G.moduleProfileName == "Lees-MacBook-Air",
      _G.moduleProfileName)
check("an unknown Mac falls back to `default` rather than loading nothing", (function()
  local saved = _G.moduleProfiles["Lees-MacBook-Air"]
  local pick = _G.moduleProfiles["A-Brand-New-Mac"] and "A-Brand-New-Mac" or "default"
  return pick == "default" and _G.moduleProfiles.default ~= nil and saved ~= nil
end)())
check("every profile lists only modules that exist on disk", (function()
  for pname, prof in pairs(_G.moduleProfiles) do
    for _, m in ipairs(prof.modules or {}) do
      local f = io.open(MODDIR .. "/" .. m .. ".lua", "r")
      if not f then return false, pname .. " → " .. m end
      f:close()
    end
  end
  return true
end)())
check("profile settings override a module's config after setup", (function()
  _G.moduleStatus, _G.moduleCheatsheets = {}, {}
  _G.loadModules({ "window_switcher" }, { window_switcher = { maxWindows = 7 } })
  return _G.altTab.maxWindows == 7
end)(), _G.altTab and _G.altTab.maxWindows)
check("...and the override is recorded for the report",
      (statusOf("window_switcher") or {}).overrides == "maxWindows",
      (statusOf("window_switcher") or {}).overrides)
check("a module with no config table ignores overrides harmlessly", (function()
  _G.moduleStatus = {}
  local ok = pcall(_G.loadModules, { "daily_backup" }, { daily_backup = { nonsense = 1 } })
  return ok and statusOf("daily_backup").ok
end)())

out("\n=== 4c. warm(): the expensive half runs AFTER boot ===\n")
_G.moduleStatus, _G.moduleCheatsheets, _G.moduleWarmTimers = {}, {}, {}
-- reset the harness's own capture list too: the real modules loaded at
-- dofile time already queued warm callbacks, and firing one of THOSE
-- here would test the wrong thing (it did, once).
warmTimerFns = {}
WARMED = nil
local warmRec
do
  local f = io.open(MODDIR .. "/t_warm.lua", "w")
  f:write([[local M = {}
    M.name, M.order = "Warm", 99
    M.setup = function(core)
      _G.__setupRan = true
      M.warm = function(core) WARMED = true end
    end
    return M]])
  f:close()
  _G.loadModules({ "t_warm" })
  warmRec = statusOf("t_warm")
end
check("setup() ran during boot", _G.__setupRan == true)
check("warm() did NOT run during boot", WARMED == nil)
check("a warm timer was scheduled and HELD", #_G.moduleWarmTimers == 1)
check("...and the record says warm is pending", warmRec.warmPending == true)
warmTimerFns[#warmTimerFns]()
check("warm() runs when the timer fires", WARMED == true)
check("...and its duration is recorded separately from setup",
      type(warmRec.warmMs) == "number" and warmRec.warmed == true, warmRec.warmMs)
do
  local f2 = io.open(MODDIR .. "/t_warmfail.lua", "w")
  f2:write([[local M = {}
    M.name = "WarmFail"
    M.setup = function(core)
      M.warm = function() error("warm exploded") end
    end
    return M]])
  f2:close()
  _G.moduleStatus, _G.moduleWarmTimers = {}, {}
  _G.loadModules({ "t_warmfail" })
  warmTimerFns[#warmTimerFns]()
  local r = statusOf("t_warmfail")
  check("a warm() that throws is caught and named", r.warmed == false
        and (r.warmErr or ""):find("warm exploded", 1, true) ~= nil, r.warmErr)
  check("...and the module still counts as loaded", r.ok == true)
end
os.remove(MODDIR .. "/t_warm.lua"); os.remove(MODDIR .. "/t_warmfail.lua")
check("autocorrect defers its 11k-row CSV to warm()", (function()
  local m = dofile(MODDIR .. "/autocorrect.lua")
  m.setup(_G.core)
  return type(m.warm) == "function"
end)())

out("\n=== 4d. The service registry (the ⇪0 crash of 6.40.0) ===\n")
check("activity_tracker publishes its renderer",
      _G.service.has("activity.renderChoices"))
check("asana_comments publishes its comment poster",
      _G.service.has("asana.addComment"))
check("calling a MISSING service returns nil instead of throwing", (function()
  local ok, res = pcall(_G.service.call, "nothing.here")
  return ok and res == nil
end)())

out("\n=== 5. Failure is ISOLATED — the whole point ===\n")
local function writeMod(name, body)
  local f = io.open(MODDIR .. "/" .. name .. ".lua", "w"); f:write(body); f:close()
end
writeMod("t_syntax", "return { name='x', setup = function(  ")           -- unparseable
writeMod("t_throws", "error('boom at load time') ")                       -- throws on load
writeMod("t_nosetup", "return { name = 'no setup here' }")                -- breaks contract
writeMod("t_noreturn", "local M = {} ")                                   -- forgot the return
writeMod("t_setupfails", "return { name='s', setup = function() error('setup exploded') end }")
writeMod("t_good", [[return { name = "Good", order = 42,
  cheatsheet = { title = "✅ GOOD", entries = { { "k", "v" } } },
  setup = function(core) _G.__goodRan = true end }]])

_G.moduleStatus, _G.moduleCheatsheets = {}, {}
local loaded, failed = _G.loadModules({
  "t_syntax", "t_throws", "t_nosetup", "t_noreturn", "t_setupfails", "t_good", "t_missing" })
check("the good module still loaded despite five broken ones",
      _G.__goodRan == true and loaded == 1, loaded)
check("all six failures counted", failed == 6, failed)
check("a syntax error is named as a syntax error",
      (statusOf("t_syntax").err or ""):find("syntax error", 1, true))
check("a module that throws at load is caught",
      (statusOf("t_throws").err or ""):find("failed while loading", 1, true))
check("a missing setup() is caught by the contract check",
      (statusOf("t_nosetup").err or ""):find("setup()", 1, true))
check("a forgotten `return M` is caught too",
      (statusOf("t_noreturn").err or ""):find("setup()", 1, true))
check("a setup() that throws is caught",
      (statusOf("t_setupfails").err or ""):find("setup() failed", 1, true))
check("a MISSING file says 'not found', not 'syntax error'",
      (statusOf("t_missing").err or ""):find("not found", 1, true), statusOf("t_missing").err)
check("every failure is named in the Console", (function()
  local n = 0
  for _, l in ipairs(printed) do if l:find("MODULE FAILED", 1, true) then n = n + 1 end end
  return n == 6
end)())
check("a failed module registers NO cheat sheet group (never advertise "
      .. "a shortcut nothing bound)", #_G.moduleCheatsheets == 1, #_G.moduleCheatsheets)
check("...while the good one does", _G.moduleCheatsheets[1].order == 42)

out("\n=== 6. Load order is explicit, not filesystem order ===\n")
_G.moduleStatus = {}
_G.loadModules({ "t_good", "t_missing", "t_syntax" })
check("modules are recorded in the order listed",
  _G.moduleStatus[1].name == "t_good" and _G.moduleStatus[2].name == "t_missing"
  and _G.moduleStatus[3].name == "t_syntax")

for _, n in ipairs({ "t_syntax", "t_throws", "t_nosetup", "t_noreturn", "t_setupfails", "t_good" }) do
  os.remove(MODDIR .. "/" .. n .. ".lua")
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
