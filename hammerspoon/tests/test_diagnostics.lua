-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
-- HS   = the config being tested (init.lua + modules/)
-- HERE = this tests folder, which is where the extracted fixtures live
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local HS   = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
             or ((os.getenv("HOME") or ".") .. "/.hammerspoon")
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
-- 6.44.11 — RUNS THE SHIPPED FILE, NOT A COPY. tests/diag_test.lua was a
-- hand-extracted slice of §1.11 and had drifted out of step with init.lua
-- — it was no longer even a verbatim substring of it. Every check below
-- was therefore green against code that was not what ships. §1.11 now
-- lives in core/diagnostics.lua, so the suite loads that, the same way
-- init.lua does.
local DIAG_PATH = HS .. "/core/diagnostics.lua"
local diagChunk = assert(loadfile(DIAG_PATH),
                         "cannot load the shipped diagnostics: " .. DIAG_PATH)
diagChunk()({ logsDir = logsDir, hostTag = hostTag, asanaEnabled = asanaEnabled })
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
local INIT = HS .. "/init.lua"
local f = realopen(INIT, "r"); local text = f:read("*a"); f:close()
-- initText is init.lua ALONE, before the modules and core files are
-- appended below. It matters: a check like "init.lua loads the boot
-- report" against the CONCATENATED text passes even when init.lua stops
-- loading it, because core/boot_report.lua names itself in its own
-- header. Two mutations slipped through exactly that way before this
-- split existed. Anything asserting what init.lua itself does must use
-- initText; anything hunting a bug CLASS should use text, so the class
-- cannot escape by moving to another file.
local initText = text
-- ...and it has to ignore COMMENTS. "init.lua loads core/boot_report.lua"
-- stayed green under a mutation that pointed the loader at a file that
-- does not exist — because the comment ABOVE the loader says the name
-- too. A prose mention is not a call. Everything asserting that init.lua
-- DOES something goes through here.
local function initLive(needle, plain)
  for line in initText:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") and line:find(needle, 1, plain ~= false) then
      return line
    end
  end
end
-- The audit covers the MODULE FILES too, so a bug class cannot escape
-- it simply by having been moved out of init.lua.
local MODS = { "daily_backup", "app_peek", "window_switcher",
               "window_arranger", "copy_on_select", "command_history",
               "app_watcher", "file_tracker", "autocorrect", "activity_tracker",
               "update_tracker", "asana_comments", "document_watcher",
               "screen_veil", "mini_calendar", "quick_append",
               "capture_pad", "numpad_layer" }
local moduleText = {}
for _, m in ipairs(MODS) do
  local mf = realopen(HS .. "/modules/" .. m .. ".lua", "r")
  if mf then moduleText[m] = mf:read("*a"); mf:close(); text = text .. "\n" .. moduleText[m] end
end
-- ...and the CORE files, for exactly the same reason. 6.44.11 lifted §1.11
-- and §1.6 out of init.lua, and the moment it did, every audit rule below
-- stopped covering them — the "uncaughtErrorHandler is wired" check failed
-- not because the wiring had gone but because the auditor had stopped
-- looking where it lives. An audit that shrinks when code moves is worse
-- than no audit, because it stays green while its coverage falls away.
local CORE = { "diagnostics", "cheatsheet", "boot_report" }
local coreText, coreFound = {}, {}
for _, c in ipairs(CORE) do
  local cf = realopen(HS .. "/core/" .. c .. ".lua", "r")
  if cf then
    coreText[c] = cf:read("*a"); cf:close()
    coreFound[c] = true
    text = text .. "\n" .. coreText[c]
  end
end
check("init.lua compiles", (loadfile(INIT)) ~= nil, select(2, loadfile(INIT)))
for _, m in ipairs(MODS) do
  local path = HS .. "/modules/" .. m .. ".lua"
  check("module compiles: " .. m, (loadfile(path)) ~= nil, select(2, loadfile(path)))
  check("module returns a contract: " .. m, (function()
    local ok, mod = pcall(dofile, path)
    return ok and type(mod) == "table" and type(mod.setup) == "function"
  end)())
end
-- Core files get the same treatment modules get. They are dofile'd by
-- init.lua at a fixed point rather than loaded by the §1.12 loader, so a
-- broken one is NOT isolated the way a broken module is — which is the
-- reason to check them harder, not less.
for _, c in ipairs(CORE) do
  local path = HS .. "/core/" .. c .. ".lua"
  check("core file present: " .. c, coreFound[c] == true, path)
  if coreFound[c] then
    check("core file compiles: " .. c, (loadfile(path)) ~= nil, select(2, loadfile(path)))
    check("core file returns an initialiser: " .. c, (function()
      local ok, fn = pcall(dofile, path)
      return ok and type(fn) == "function"
    end)())
  end
end
check("INIT.LUA ITSELF loads every core file — checked against init.lua alone, "
      .. "because a core file names itself in its own header",
  (function()
    -- The full loader expression, not the bare filename: each loader also
    -- prints a failure message naming its own file, so a check for
    -- "core/boot_report.lua" stayed green under a mutation that pointed
    -- loadfile at a path that does not exist. Only the real call counts.
    for _, c in ipairs(CORE) do
      if not initLive("hs.configdir .. '/core/" .. c .. ".lua'") then return false, c end
    end
    return true
  end)())
check("...and every one of those loads is inside a pcall, so a missing or "
      .. "broken core file degrades instead of killing the boot",
  (function()
    for _, guard in ipairs({ "diagOK", "csOK", "brOK" }) do
      if not initLive(guard) then return false, guard end
    end
    return true
  end)())
check("...and each failure prints, because a silent one looks like success",
  (function()
    for _, guard in ipairs({ "diagOK", "csOK", "brOK" }) do
      if not initLive("if not " .. guard .. " then") then return false, guard end
    end
    return true
  end)())
check("init.lua ASKS macOS about Accessibility rather than assuming it",
  initLive("pcall(function() axOK = hs.accessibilityState() end)") ~= nil)

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
-- 6.44.11 — the boot report became rows + a formatter, so the old check
-- for the literal "Boot:     %.2fs" was asserting the layout, not the
-- fact. The fact is what matters: boot time is still reported.
check("boot report still reports total load time",
  text:find('{ "Boot",', 1, true) ~= nil and text:find("%%.2fs") ~= nil)

-- ── QUIET BOOT (6.44.11) ─────────────────────────────────────────────
-- Fourteen lines on every reload is not information, it is what you
-- scroll past. These assert the new contract: summarise what is right,
-- always print what is wrong, keep the full detail one call away.
check("a healthy boot summarises instead of printing every row",
  text:find("All green.", 1, true) ~= nil)
check("...and every row still carries a problem flag, so nothing silently "
      .. "drops out of the report",
  (function()
    local rows = text:match("local bootRows = (%b{})")
    if not rows then return false end
    local n = select(2, rows:gsub('{ "', ""))
    return n >= 9        -- Storage Data Backup Asana Autocorrect Hotkeys Boot Modules Hyper Access
  end)())
check("...problems print unconditionally, not only when verbose",
  text:find("if r%[3%] then problems") ~= nil)
check("...accessibility is a row now, not a straggler print underneath",
  text:find('{ "Access", axOK', 1, true) ~= nil
  and not liveCode('print%("   Access:'))
check("the full report is still reachable on demand",
  liveCode("function _G%.bootReport") ~= nil)
check("...and verbose mode PERSISTS, so it survives the reload you set it before",
  liveCode("hs%.settings%.set%(\"hsBootVerbose\"") ~= nil
  and liveCode("hs%.settings%.get%(\"hsBootVerbose\"") ~= nil)
check("hs.hotkey's own enable/disable chatter is turned down",
  liveCode("hs%.hotkey%.setLogLevel") ~= nil)
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


-- =====================================================================
-- 8. THE BOOT REPORT, EXECUTED (6.44.11)
-- =====================================================================
-- Section 7 greps the shipped text. That proves a string exists. It
-- cannot tell you whether a healthy boot actually stays quiet, or
-- whether a broken one actually speaks up — which is the whole contract.
-- So this runs the real file, repeatedly, and reads what it printed.
out("\n=== 8. Boot report, executed ===\n")
local BR_PATH = HS .. "/core/boot_report.lua"
local brChunk = loadfile(BR_PATH)
check("core/boot_report.lua loads", brChunk ~= nil, select(2, loadfile(BR_PATH)))

if brChunk then
  local lines = {}
  local realPrint2 = print
  print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
    lines[#lines+1] = table.concat(t, " ")
  end
  local SETTINGS = {}
  hs.settings = { get = function(k) return SETTINGS[k] end,
                  set = function(k, v) SETTINGS[k] = v end }
  _G.moduleLoaded, _G.moduleFailed = 18, 0
  _G.hotkeyBoundCount, _G.hotkeyConflictCount = 4, 0
  _G.hyperShortcutCount, _G.hyperForwardCount, _G.hyperConflictCount = 34, 32, 0
  _G.autocorrectStatus, _G.moduleProfileName, _G.moduleDir = "ON", "TestMac", "/m"

  local function run(over)
    lines = {}
    local cfg = { hostTag = "TestMac", cloudDir = "/cloud", logsDir = "/cloud/Logs",
                  backupDir = "/cloud/Backups", asanaEnabled = true,
                  secretsStatus = "loaded", axOK = true }
    for k, v in pairs(over or {}) do if v == false then cfg[k] = nil else cfg[k] = v end end
    local api = brChunk()(cfg)
    return table.concat(lines, "\n"), api
  end

  local healthy, api = run()
  check("a healthy boot prints 2 lines, not 14", #lines == 2, #lines .. ": " .. healthy)
  check("...and says so plainly", healthy:find("All green", 1, true) ~= nil)
  check("...naming host, modules and shortcuts",
    healthy:find("TestMac", 1, true) and healthy:find("18", 1, true)
    and healthy:find("34", 1, true))
  check("...and pointing at the full report rather than hiding it",
    healthy:find("bootReport", 1, true) ~= nil)
  check("...while still building every row underneath",
    type(api) == "table" and #api.rows >= 10, api and #api.rows)

  local faults = {
    { "a failed module",       nil, function() _G.moduleFailed = 3 end,        "Modules" },
    { "a hotkey conflict",     nil, function() _G.hotkeyConflictCount = 2 end, "Hotkeys" },
    { "a hyper conflict",      nil, function() _G.hyperConflictCount = 1 end,  "Hyper"   },
    { "missing Accessibility", { axOK = false }, nil,                          "Access"  },
    { "Asana off",             { asanaEnabled = false }, nil,                  "Asana"   },
    { "no OneDrive",           { cloudDir = false }, nil,                      "Storage" },
  }
  for _, f in ipairs(faults) do
    local sM, sH, sY = _G.moduleFailed, _G.hotkeyConflictCount, _G.hyperConflictCount
    if f[3] then f[3]() end
    local o = run(f[2])
    check("⚠️ " .. f[1] .. " is reported even on an otherwise clean boot",
      o:find(f[4], 1, true) ~= nil and o:find("⚠️", 1, true) ~= nil, o)
    check("...and it suppresses the \"All green\" line", o:find("All green", 1, true) == nil)
    _G.moduleFailed, _G.hotkeyConflictCount, _G.hyperConflictCount = sM, sH, sY
  end

  SETTINGS.hsBootVerbose = true
  local full = run()
  check("verbose mode prints the whole report", #lines >= 10, #lines)
  check("...including rows a quiet boot leaves out",
    full:find("Backup", 1, true) and full:find("Autocorrect", 1, true))
  SETTINGS.hsBootVerbose = nil

  run()
  check("bootVerbose() reads the stored preference", _G.bootVerbose() == false)
  _G.bootVerbose(true)
  check("...and writing it PERSISTS, surviving the next reload",
    SETTINGS.hsBootVerbose == true and _G.bootVerbose() == true)
  _G.bootVerbose(false)
  check("...and can be turned back off", SETTINGS.hsBootVerbose == false)

  print = realPrint2
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
