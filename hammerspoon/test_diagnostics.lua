-- Harness for §1.11 diagnostics, plus a whole-file audit of init.lua:
-- the removal of App Lock and the bug classes the audit went looking for
-- are asserted against the shipped text itself, not against a copy.
local printed, clip, written = {}, nil, {}
local realprint = print
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  table.insert(printed, table.concat(p, " "))
end
local NOW = 500
hs = {
  timer = { secondsSinceEpoch = function() return NOW end },
  json  = { decode = function(s)
      if s == '{"ok":true}' then return { ok = true } end
      error("Unable to parse JSON")
  end },
  fs = { attributes = function(p)
      if p == "/tmp/hs-test" then return { mode = "directory", size = 0 } end
      return { mode = "file", size = 42 }
  end },
  pasteboard = { setContents = function(t) clip = t end },
  alert = { show = function() end },
  hotkey = { bind = function() end },
  screen = { allScreens = function()
      return { { name = function() return "LG HDR 4K" end,
                 frame = function() return { x=0,y=0,w=3840,h=2160 } end } }
  end },
  window = { orderedWindows = function() NOW = NOW + 0.5; return { 1, 2, 3 } end },
  application = { frontmostApplication = function()
      return { name = function() return "Ghostty" end } end },
  host = { operatingSystemVersionString = function() return "macOS 26.1" end },
  processInfo = { version = "1.0.0" },
  accessibilityState = function() return true end,
}
hostTag, logsDir, backupDir, asanaEnabled = "TestMac", "/tmp/hs-test", "/tmp/hs-backup", true
altTab = { enabled = true, includeMinimized = false, maxWindows = 24, session = nil }
_G.autocorrectStatus = "ON (10970 fixes)"
_G.hotkeyBoundCount, _G.hotkeyConflictCount = 4, 0
_G.configVersion = "6.35.0"

local realopen = io.open
io.open = function(path, mode)
  if mode == "w" then
    return { write = function(_, t) written[path] = t end, close = function() end }
  end
  return realopen(path, mode)
end

-- The real file declares a no-op stub at the top and §1.11 EXTENDS it;
-- the harness has to stand in for that stub, and asserting the extend
-- (rather than replace) behaviour is itself part of the test below.
_G.diag = { verbose = false, trail = {}, errors = {}, marks = {},
            say = function() end, warn = function() end,
            err = function() end, mark = function() end }
_G.diag.trail[1] = "pre-existing entry from before §1.11 loaded"
dofile("BLOCK_PATH")
local keptEarly = _G.diag.trail[1] == "pre-existing entry from before §1.11 loaded"
io.open = realopen

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end
local function inReport(r, pat) return r:find(pat, 1, true) ~= nil end

out("\n=== 1. The trail records even when nobody is watching ===\n")
check("§1.11 EXTENDS the early stub instead of replacing it", keptEarly)
_G.diag.verbose = false
printed = {}
_G.diag.say("test", "quiet event")
check("event recorded to the trail", #_G.diag.trail >= 2)
check("...but NOT printed while verbose is off", #printed == 0, printed[1])
_G.diag.verbose = true
_G.diag.say("test", "loud event")
check("printed once verbose is on", #printed == 1, #printed)
_G.diag.verbose = false
for i = 1, 300 do _G.diag.say("flood", "event " .. i) end
check("trail is a RING BUFFER, not a leak", #_G.diag.trail == _G.diag.maxTrail, #_G.diag.trail)
check("...keeping the NEWEST entries", _G.diag.trail[#_G.diag.trail]:find("event 300"))

out("\n=== 2. Errors are captured, including from async callbacks ===\n")
check("hs.uncaughtErrorHandler is installed", type(hs.uncaughtErrorHandler) == "function")
hs.uncaughtErrorHandler("boom in a timer callback")
check("an uncaught error is recorded", #_G.diag.errors == 1, #_G.diag.errors)
check("...with the message", _G.diag.errors[1]:find("boom in a timer callback", 1, true) ~= nil)
for i = 1, 60 do _G.diag.err("err " .. i) end
check("error buffer is bounded too", #_G.diag.errors == _G.diag.maxErrors, #_G.diag.errors)

out("\n=== 3. safeJson: the major audit fix ===\n")
check("valid JSON decodes", (function()
  local d = _G.safeJson('{"ok":true}', "t"); return d and d.ok == true
end)())
check("an HTML proxy page returns nil instead of THROWING", (function()
  local ok, res = pcall(_G.safeJson, "<html>Sign in to the network</html>", "t")
  return ok and res == nil
end)())
check("...and says what actually arrived", (function()
  for _, l in ipairs(printed) do if l:find("not JSON", 1, true) then return true end end
end)())
check("an empty body returns nil, no throw", (function()
  local ok, res = pcall(_G.safeJson, "", "t"); return ok and res == nil
end)())
check("a nil body returns nil, no throw", (function()
  local ok, res = pcall(_G.safeJson, nil, "t"); return ok and res == nil
end)())

out("\n=== 4. Boot marks ===\n")
_G.diag.marks = {}
NOW = 502.5
_G.diag.mark("§3.12 hyper wired")
check("mark records elapsed since boot start", _G.diag.marks[1].at > 0, _G.diag.marks[1].at)
check("...under its own name", _G.diag.marks[1].name == "§3.12 hyper wired")

out("\n=== 5. The report has what I need to debug from ===\n")
local r = _G.diag.report()
for _, want in ipairs({
  "config version : 6.35.0", "macOS", "machine        : TestMac",
  "accessibility  : granted", "BOOT", "hyper wired", "SCREENS", "LG HDR 4K",
  "HOTKEYS", "global bound   : 4", "FEATURES", "Asana          : on",
  "Autocorrect    : ON", "⌥Tab switcher", "LIVE PROBE", "orderedWindows",
  "PATHS", "/tmp/hs-test", "ERRORS", "LAST 25 EVENTS", "END OF REPORT" }) do
  check("report contains: " .. want, inReport(r, want))
end
check("live probe TIMES the window enumeration (the beachball measure)",
  r:find("orderedWindows : 3 windows in %d") ~= nil)
check("a slow enumeration is flagged in the report", r:find("SLOW") ~= nil)
check("report says how to turn verbose on", inReport(r, "_G.diag.verbose = true"))

out("\n=== 6. ⇪⇧D delivers it three ways ===\n")
printed, clip, written = {}, nil, {}
io.open = function(path, mode)
  if mode == "w" then return { write = function(_, t) written[path] = t end, close = function() end } end
  return realopen(path, mode)
end
_G.diag.show()
io.open = realopen
check("printed to the Console", #printed >= 1)
check("copied to the clipboard", clip ~= nil and clip:find("DIAGNOSTIC REPORT", 1, true) ~= nil)
check("saved to the Logs folder, tagged per machine",
  written["/tmp/hs-test/diagnostics-TestMac.txt"] ~= nil,
  next(written))

out("\n=== 7. Whole-file audit of the shipped init.lua ===\n")
local INIT = "INIT_PATH"
local f = realopen(INIT, "r"); local text = f:read("*a"); f:close()
-- The audit covers the MODULE FILES too, so a bug class cannot escape
-- it simply by having been moved out of init.lua.
local MODS = { "daily_backup", "app_peek", "window_switcher",
               "window_arranger", "copy_on_select", "command_history",
               "app_watcher", "file_tracker", "autocorrect", "activity_tracker",
               "update_tracker", "asana_comments", "document_watcher" }
local moduleText = {}
for _, m in ipairs(MODS) do
  local mf = realopen("MODULES_DIR/" .. m .. ".lua", "r")
  if mf then moduleText[m] = mf:read("*a"); mf:close(); text = text .. "\n" .. moduleText[m] end
end
check("init.lua compiles", (loadfile(INIT)) ~= nil, select(2, loadfile(INIT)))
for _, m in ipairs(MODS) do
  local path = "MODULES_DIR/" .. m .. ".lua"
  check("module compiles: " .. m, (loadfile(path)) ~= nil, select(2, loadfile(path)))
  check("module returns a contract: " .. m, (function()
    local ok, mod = pcall(dofile, path)
    return ok and type(mod) == "table" and type(mod.setup) == "function"
  end)())
end
check("the migrated sections are GONE from init.lua", (function()
  local f2 = realopen(INIT, "r"); local only = f2:read("*a"); f2:close()
  for _, gone in ipairs({ "1.7 DAILY BACKUP", "1.8 APP PEEK", "1.10 WINDOW SWITCHER",
                          "1.9 WINDOW ARRANGER", "3.11 GLOBAL COPY-ON-SELECT",
                          "6.5 COMMAND HISTORY", "3.7 APP WATCHER",
                          "3.8 FILE TRACKER", "3.9 AUTOCORRECT", "3.6 ACTIVITY TRACKER",
                          "3.10 APP UPDATE TRACKER", "3.5 ASANA COMMENTS",
                          "X.1 DOCUMENT WATCHER" }) do
    if only:find(gone, 1, true) then return false end
  end
  return true
end)())
check("modules never reach into init.lua's locals", (function()
  for m, body in pairs(moduleText) do
    for line in body:gmatch("[^\n]+") do
      if not line:match("^%s*%-%-") then
        -- these must arrive via core, never as free-floating globals
        for _, forbidden in ipairs({ "popupScreenKeys", "resolveBaseScreen%(",
                                     "logsDir", "backupDir" }) do
          if line:find(forbidden) and not line:find("core%.") then return false, m end
        end
      end
    end
  end
  return true
end)())
local function liveCode(pattern)      -- matches outside comment lines
  for line in text:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") and line:find(pattern) then return line end
  end
end
check("no App Lock code remains", not liveCode("appLock"), liveCode("appLock"))
check("no App Lock section header", not text:find("6.6 APP LOCK", 1, true))
check("no PIN prompt code", not liveCode("appLockChallenge"))
check("applock.json is STILL excluded from backups (leftovers never sync)",
  text:find("--exclude 'applock.json'", 1, true) ~= nil)
check("no unprotected hs.json.decode on network replies",
  not liveCode("hs%.json%.decode%(body%)") and not liveCode("hs%.json%.decode%(b%)")
  and not liveCode("hs%.json%.decode%(responseBody%)"))
check("hs.window.filter is never CALLED (naming it in a changelog string is fine)",
  not liveCode("hs%%.window%%.filter%%.new") and not liveCode("window%%.filter%%.default"))
check("no discarded timer objects", not liveCode("^%s*hs%.timer%.do"))
check("no io.open used as a bare existence test", not liveCode("io%.open%b()%s*==%s*nil"))
check("uncaughtErrorHandler is wired in the real file",
  liveCode("hs%.uncaughtErrorHandler") ~= nil)
check("boot report prints total load time", text:find("Boot:     %%.2fs") ~= nil)
-- ── THE 6.42.0 REGRESSION GUARD ──────────────────────────────────────
-- When a section became a module, code left behind in init.lua kept
-- calling its functions by bare name. Lua does not object: the name just
-- becomes a nil GLOBAL, and nothing fails until the key is pressed. That
-- is exactly how ⇪0 crashed. This walks init.lua looking for calls to
-- any function that now lives inside a module file.
check("NO DANGLING CALLS: init.lua never calls a function that moved into a module",
  (function()
    local fh = realopen(INIT, "r"); local only = fh:read("*a"); fh:close()
    local defined = {}
    for line in only:gmatch("[^\n]+") do
      for n in line:gmatch("local%s+function%s+([%w_]+)") do defined[n] = true end
      for n in line:gmatch("^%s*function%s+([%w_]+)%s*%(") do defined[n] = true end
      for n in line:gmatch("local%s+([%w_]+)%s*=") do defined[n] = true end
    end
    local inModule = {}
    for m, body in pairs(moduleText) do
      for n in body:gmatch("local%s+function%s+([%w_]+)") do inModule[n] = m end
    end
    for line in only:gmatch("[^\n]+") do
      -- Strip string literals before scanning. The changelog notes in
      -- this file NAME the functions that moved, and prose inside a
      -- string is not a call — an earlier version of this guard flagged
      -- its own changelog entry, which is the same false-positive shape
      -- as matching a module name inside a comment.
      local code = line:gsub('"[^"]*"', '""')
      if not code:match("^%s*%-%-") then
        for n in code:gmatch("[%s,(=]([%l][%w_]+)%s*%(") do
          if inModule[n] and not defined[n] then
            return false
          end
        end
      end
    end
    return true
  end)())
check("cross-boundary calls go through the service registry",
      text:find("_G.service.call(", 1, true) ~= nil)
check("...and modules publish through core.provide",
      text:find("core.provide(", 1, true) ~= nil)
check("the service registry warns instead of throwing when a provider is missing",
      text:find("No provider for", 1, true) ~= nil)
check("a broken Homebrew is reported ONCE, not once per app",
      (moduleText.update_tracker or ""):find("updateTrackerBrewWarned", 1, true) ~= nil)
check("...and names the actual repair rather than blaming the cask token",
      (moduleText.update_tracker or ""):find("brew update --force", 1, true) ~= nil)

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
