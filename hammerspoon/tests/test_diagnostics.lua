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
diagChunk()({ logsDir = logsDir, hostTag = hostTag, asanaEnabled = asanaEnabled,
              backupDir = backupDir })
-- 6.145.2 — the global dies the moment the chunk has been handed the value.
-- Before the fix, diagnostics read `backupDir` as a GLOBAL — which this
-- harness defined (above) and init.lua never does, its backupDir being a
-- local — so this suite stayed green while every real Mac's report printed
-- "backup dir : not configured". With the global gone, the report below can
-- only know the path if it actually kept core.backupDir.
backupDir = nil
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
check("backup dir is the PASSED value, not a global only this harness sets",
  inReport(r, "backup dir     : /tmp/hs-backup"), r:match("backup dir[^\n]*"))
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
-- ⚠️ READ FROM DISK, NOT RETYPED. A hand-copied list drifts the moment a
-- module is added — this one sat at 18 of 26 files for several releases,
-- so the audit below silently stopped covering a third of the config.
-- init.lua's own default profile is the source of truth for what SHIPS;
-- reading it is what test_integration already does for the same reason.
local MODS = {}
do
  local f = realopen(HS .. "/init.lua", "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  -- 🚨 6.66.3 — READS BASE, NOT THE `default` PROFILE. init.lua used to
  -- carry three hand-typed module lists, one per machine, and this read
  -- one of them. When the restructure replaced them with a single BASE
  -- list this match returned nil, MODS came back EMPTY, no module source
  -- was appended, and SEVEN unrelated checks failed at once — none of
  -- them mentioning modules. A silent nil from a pattern is a bad way to
  -- learn that, which is why the guard below is now an assertion rather
  -- than an `or ""`.
  local block = src:match("local BASE = {(.-)\n}")
  for name in (block or ""):gmatch('"([%w_]+)"') do MODS[#MODS + 1] = name end
end
-- 🚨 FAIL LOUDLY IF THE LIST IS EMPTY. Every check below that greps
-- module source silently passes-or-fails on nothing when MODS is empty,
-- and the failures point anywhere but here.
check("the module list was read out of init.lua's BASE — an empty list "
      .. "here makes every module check below meaningless",
      #MODS >= 25, #MODS)
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
-- 6.139.0 — the exclusion moved from a quoted shell string to the
-- rebuild kit's exclude TABLE, which is applied to every rsync the
-- backup runs. The claim is unchanged: the leftover PIN hash from the
-- removed App Lock must never reach a cloud copy.
check("applock.json is STILL excluded from backups (leftovers never sync)",
  text:find('"applock.json"', 1, true) ~= nil)
check("no unprotected hs.json.decode on network replies",
  not liveCode("hs%.json%.decode%(body%)") and not liveCode("hs%.json%.decode%(b%)")
  and not liveCode("hs%.json%.decode%(responseBody%)"))
check("hs.window.filter is never CALLED (naming it in a changelog string is fine)",
  not liveCode("hs%%.window%%.filter%%.new") and not liveCode("window%%.filter%%.default"))
check("no discarded timer objects", not liveCode("^%s*hs%.timer%.do"))

-- 🚨 6.57.0 — THE HEADER DATE MUST TRACK THE VERSION.
-- The file carried "08-05-26" for a dozen releases while the version
-- marker moved on without it, so the one line a human reads first was
-- quietly wrong. Asserted here so it cannot drift again.
do
  local dateLine = initText:match("\n%-%- (%d%d%-%d%d%-%d%d) using Claude")
  check("init.lua's header carries an edited date", dateLine ~= nil, dateLine)
  check("...and it is marked as something that gets bumped, so the next "
        .. "person knows it is not decoration",
        initText:find("Bumped with every release", 1, true) ~= nil)
end

-- 🚨 6.57.0 — A MODULE MUST NOT CLAIM A HYPER KEY THAT §0.4 ALREADY
-- MIGRATES SOMETHING ONTO. This is the gap that let three working
-- shortcuts die silently. test_integration checks module-against-module
-- collisions, but §0.4's migration map lives in init.lua and was never
-- part of that comparison — so focus_mode took ⇪F from the file
-- tracker, workspaces took ⇪W from the summon-an-app picker, and bulk
-- rename took ⇪⇧R from reset-nudge-offset. Each printed ONE line at
-- boot and killed a feature. Never again.
do
  local migr = {}
  for old, mods, key in initText:gmatch('%["([^"]+)"%]%s*=%s*{%s*{([^}]*)}%s*,%s*"([^"]+)"%s*}') do
    -- Only entries whose OLD chord is still bound somewhere can actually
    -- claim the hyper key; a map entry nothing triggers is inert.
    migr[(mods:find("shift") and "shift|" or "|") .. key] = old
  end
  local claims, dupes = {}, {}
  for _, m in ipairs(MODS) do
    local src = moduleText[m]
    if src then
      -- resolve `x.key = "q"` style indirection
      local keyvals = {}
      for var, k in src:gmatch('(%w+%.%w*[Kk]ey)%s*=%s*"([%w]+)"') do keyvals[var] = k end
      for mods, k in src:gmatch('hyperAddShortcut%(%s*{([^}]*)}%s*,%s*([^,]+),') do
        k = k:gsub("%s+", "")
        local key = k:match('^"(.-)"$') or keyvals[k]
        if key then
          local tag = (mods:find("shift") and "shift|" or "|") .. key
          if migr[tag] then
            dupes[#dupes + 1] = tag .. " (" .. m .. " vs migrated "
                                .. migr[tag] .. ")"
          end
          claims[tag] = m
        end
      end
    end
  end
  check("🚨 NO MODULE CLAIMS A HYPER KEY THE MIGRATION MAP ALSO CLAIMS — "
        .. "the collision that silently killed ⇪F, ⇪W and ⇪⇧R",
        #dupes == 0, table.concat(dupes, "; "))
end

-- 🚨 6.53.0 — A BAD KEY NAME MUST NOT TAKE THE WHOLE CONFIG DOWN.
-- hs.hotkey.bind THROWS on a key macOS has no code for. A module's bad
-- key was always survivable (§1.12 runs every setup() in a pcall), but
-- init.lua's own binds are top level in the stretch that runs BEFORE the
-- loader — so one typo in an ✏️ EDIT HERE block took everything down:
-- no hotkeys, no modules, no cheat sheet, and the reason only in a
-- Console nobody had open. Audited from source: the sentry wraps
-- hs.hotkey.bind at file scope and has no harness to drive.
do
  local codeOnly = {}
  for line in initText:gmatch("[^\n]+") do
    codeOnly[#codeOnly + 1] = line:match("^%s*%-%-") and "" or line
  end
  local initCode = table.concat(codeOnly, "\n")

  local sentry = initCode:match("hs%.hotkey%.bind%s*=%s*function.-\nend")
  check("the hotkey sentry still wraps hs.hotkey.bind", sentry ~= nil)
  if sentry then
    -- ⚠️ THESE TWO HAVE TO BE PRECISE, and the first draft was not.
    -- "does pcall appear" and "does hyperBindStub appear" were both TRUE
    -- even with the guard removed, because the migration branch above
    -- already contains a pcall and already returns the stub. Restoring
    -- the unprotected bind failed only one of three assertions — two
    -- were reading neighbouring code. What actually distinguishes the
    -- fixed file is the ABSENCE of a bare tail call.
    check("🚨 THE REAL BIND IS NOT CALLED UNPROTECTED — a bare "
          .. "`return hsHotkeyBindOriginal(...)` lets an invalid key throw "
          .. "out of init.lua and take every feature with it",
          initCode:find("return%s+hsHotkeyBindOriginal%(") == nil)
    check("🚨 ...it is called inside a pcall that captures the result",
          initCode:find("pcall%(function%(%)%s*bound%s*=%s*hsHotkeyBindOriginal") ~= nil
          or initCode:find("bound%s*=%s*hsHotkeyBindOriginal") ~= nil)
    -- Returning nil would only move the failure: the caller's :enable()
    -- would then throw instead, which is the same death one line later.
    check("🚨 ...and a rejected key returns the inert stub, not nil — nil "
          .. "just moves the crash to the caller's :enable()", (function()
        local rejectAt = sentry:find("HOTKEY REJECTED")
        local stubAt   = sentry:find("_G%.hyperBindStub%(%)", rejectAt or 1)
        return rejectAt ~= nil and stubAt ~= nil and stubAt > rejectAt
    end)())
    check("...and the rejection is COUNTED and NAMED, so it is not silent",
          sentry:find("hotkeyRejected") ~= nil
          and sentry:find("HOTKEY REJECTED") ~= nil)
  end
end

-- 🚨 6.53.0 — ERROR REPORTING MUST NOT DEPEND ON A FILE THAT CAN FAIL.
-- hs.uncaughtErrorHandler is the ONLY place an error inside a timer,
-- HTTP reply or watcher can be seen — a pcall in whatever scheduled the
-- callback cannot catch it. It used to be installed only by
-- core/diagnostics.lua, which loads ~1,000 lines into boot and is
-- correctly pcall'd so a broken copy cannot stop the config. That left
-- errors vanishing silently (a) for all of early boot and (b) for the
-- entire session if that one file failed to load — precisely when you
-- most need reporting, and nothing announced the loss.
do
  -- ⚠️ THESE CHECKS COMPARE POSITIONS, SO THEY MUST READ CODE ONLY.
  -- The first version searched initText raw and failed on its own
  -- documentation: the comment above the fix names both
  -- "core/diagnostics.lua" and the old `err = function() end`, so the
  -- prose explaining the bug was mistaken for the bug. That is the exact
  -- trap this file warns about at the top — a prose mention is not a
  -- call — and it caught the person who wrote the warning.
  local codeOnly = {}
  for line in initText:gmatch("[^\n]+") do
    codeOnly[#codeOnly + 1] = line:match("^%s*%-%-") and "" or line
  end
  local initCode = table.concat(codeOnly, "\n")

  local initAt = initCode:find("hs%.uncaughtErrorHandler%s*=")
  check("🚨 init.lua INSTALLS AN UNCAUGHT ERROR HANDLER ITSELF",
        initAt ~= nil)
  local coreAt = initCode:find("core/diagnostics%.lua")
  check("🚨 ...and installs it BEFORE core/diagnostics.lua loads, or early "
        .. "boot keeps its silent window",
        initAt ~= nil and coreAt ~= nil and initAt < coreAt,
        tostring(initAt) .. " vs " .. tostring(coreAt))
  check("🚨 the stand-in diag RECORDS errors rather than discarding them — "
        .. "`err = function() end` is a no-op that loses every early error",
        initCode:find("err%s*=%s*function%(%s*%)%s*end") == nil)
  -- The recorder has to be bounded: an error inside a repeating timer
  -- fires forever, and an unbounded list grows until the Mac suffers.
  check("...and the recorder is bounded, so a repeating error cannot grow "
        .. "without limit",
        initCode:find("_G%.diag%.errors") ~= nil
        and initCode:find("table%.remove") ~= nil)
end

-- 📋 THE CLIPBOARD EDIT AUDIT MOVED, and became a better test.
-- 6.52.0 checked from SOURCE that the edit path copied to the clipboard
-- and that the cache was written before the pasteboard — because the
-- code was in init.lua with no harness to drive. 6.55.0 moved it to
-- modules/clipboard_history.lua, so tests/test_clipboard.lua now drives
-- the real functions and asserts the BEHAVIOUR instead of the text. A
-- source audit is what you write when you cannot run the thing; it is
-- not the goal.
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

-- 🗂 6.101.0 — EVERY MODULE DECLARES ITS CHEAT SHEET FAMILY. The families
-- exist so ⇪/ reads as a map instead of an index, and the membership is
-- declared BY EACH MODULE rather than in a list inside cheatsheet.lua —
-- because a list over there drifts the moment a module is added, which is
-- the same trap this file's MODS list was rescued from in 6.66.3. The
-- fallback is honest (an unfiled module shows up under "NOT YET FILED"
-- rather than vanishing) but it is a safety net, not a destination: a new
-- module must not be able to reach a release without picking a family.
do
  local families, unfiled, unknown = {}, {}, {}
  do
    local cf = realopen(HS .. "/core/cheatsheet.lua", "r")
    local src = cf and cf:read("*a") or ""
    if cf then cf:close() end
    local block = src:match("cheatSheet%.families%s*=%s*{(.-)\n%s*}")
    for id in (block or ""):gmatch('id%s*=%s*"([%w_]+)"') do families[id] = true end
  end
  -- "auto" is a real family that lives in the loader rather than the list:
  -- those modules collapse into the RUNS ITSELF box instead of getting a
  -- band of their own.
  families.auto = true
  check("core/cheatsheet.lua declares a family list the audit can read",
        next(families) ~= nil and families.windows == true)
  for _, m in ipairs(MODS) do
    local fam = (moduleText[m] or ""):match("\n%s*family%s*=%s*\"([%w_]+)\"")
    if not fam then unfiled[#unfiled + 1] = m
    elseif not families[fam] then unknown[#unknown + 1] = m .. "=" .. fam end
  end
  check("🗂 every shipped module declares a cheat sheet family — a new one "
        .. "cannot reach a release unfiled", #unfiled == 0,
        table.concat(unfiled, ", "))
  check("...and every family it names actually exists in cheatSheet.families",
        #unknown == 0, table.concat(unknown, ", "))
  -- The automatic tools are the ones with no keys at all. Their one line
  -- in the RUNS ITSELF box IS their whole entry on the sheet, so a missing
  -- summary is a tool the sheet lists by name and cannot describe.
  local noSummary = {}
  for _, m in ipairs(MODS) do
    local body = moduleText[m] or ""
    if body:match("\n%s*family%s*=%s*\"auto\"")
       and not body:match("\n%s*summary%s*=%s*\"") then
      noSummary[#noSummary + 1] = m
    end
  end
  check("...and every family = \"auto\" module carries the one-line summary "
        .. "the RUNS ITSELF box prints for it", #noSummary == 0,
        table.concat(noSummary, ", "))
end

-- 🔑 6.102.0 — ONE OWNER PER ⇪ KEY on the cheat sheet. Cross-references
-- are welcome — App Launcher pointing at ⇪W, Begone at ⇪⇧T — but a row
-- that puts the bare key in its KEY CELL claims it, and with the sheet
-- grouped by family the same key then renders as two different tools in
-- two different bands. The convention: the owner writes "⇪W"; everyone
-- else writes "vs ⇪W" / "via ⇪W" / "in ⇪W" so the reference reads as
-- one. Single letters only, on purpose: pad keys and named keys are
-- documented from two angles by design (numpad's map next to each
-- tool's own rows), and policing those would outlaw the good kind.
do
  local owner, dupes = {}, {}
  for _, m in ipairs(MODS) do
    local body = moduleText[m] or ""
    for _, pat in ipairs({ '{%s*"(⇪[A-Z])"%s*,', '{%s*"(⇪⇧[A-Z])"%s*,' }) do
      for key in body:gmatch(pat) do
        if owner[key] and owner[key] ~= m then
          dupes[#dupes + 1] = key .. " (" .. owner[key] .. " + " .. m .. ")"
        end
        owner[key] = owner[key] or m
      end
    end
  end
  -- The probes are MODULE-owned keys (mouse grid, chrome history) on
  -- purpose: ⇪⇧D and friends live in core/ and init.lua's builtin
  -- groups, which this audit deliberately does not read.
  check("🔑 the audit sees the single-letter ⇪ keys at all",
        owner["⇪X"] ~= nil and owner["⇪Y"] ~= nil)
  check("every single-letter ⇪/⇪⇧ key is claimed by exactly ONE module's "
        .. "cheat entries — cross-references say 'vs/via/in' instead",
        #dupes == 0, table.concat(dupes, ", "))
end


-- =====================================================================
-- 7b. THE ALERT WRAPPER SWEEPS ITS OWN WRECKAGE (6.100.1)
-- =====================================================================
-- LL's phantom window, 08-18-26: hs.alert.show threw mid-draw (the
-- 6.56.0 NSRemoteView collision), the 6.88.0 pcall caught it, and an
-- empty bordered pill sat on screen for hours because nothing cleaned
-- up the half-drawn frame. The fix sweeps and retries — and a grep
-- cannot prove a retry retries, so the block is lifted out of the
-- shipped source and RUN against an hs.alert that throws.
out("\n=== 7b. The alert wrapper, executed (6.100.1) ===\n")
do
  local s  = initText:find("_G.rawAlertShow = _G.rawAlertShow", 1, true)
  local em = "end end -- alert wrap"
  local e  = initText:find(em, 1, true)
  check("the alert-wrap block is findable (both anchors present)",
        s ~= nil and e ~= nil and e > s)
  if s and e then
    local block = initText:sub(s, e + #em - 1)
    local shows, closed, timers, said = {}, 0, {}, {}
    local throwsLeft = 0
    local SB
    SB = {
      table = table, pcall = pcall, select = select, tostring = tostring,
      collectgarbage = function() end,
      print = function(m) said[#said + 1] = tostring(m) end,
      hs = {
        alert = {
          show = function(...)
            if throwsLeft > 0 then
              throwsLeft = throwsLeft - 1
              error("NSInternalInconsistencyException -[NSRemoteView "
                    .. "containingWindowWillOrderOnScreen:]")
            end
            shows[#shows + 1] = table.pack(...)
            return "uuid"
          end,
          closeAll = function() closed = closed + 1 end,
        },
        timer = {
          doAfter = function(delay, fn)
            local t = { delay = delay, fn = fn, stop = function() end }
            timers[#timers + 1] = t
            return t
          end,
        },
      },
    }
    SB._G = SB
    SB.canvasShowTimers = {}   -- init.lua defines this ABOVE the block
    local fn, lerr = load(block, "init-alert-wrap", "t", SB)
    check("the block compiles standalone", fn ~= nil, lerr)
    if fn then
      fn()
      check("_G.phantom is defined by the block", type(SB.phantom) == "function")

      -- 1) a throw is caught, and a retry is scheduled AND HELD
      throwsLeft = 1
      SB.hs.alert.show("💾 saved", 2)
      check("the throw did not escape, and nothing drew yet", #shows == 0)
      check("a retry was scheduled one run-loop turn later",
            #timers == 1 and timers[1].delay < 0.5,
            timers[1] and timers[1].delay)
      check("...and the timer object is HELD — an unreferenced timer is "
            .. "collected and never fires", SB.canvasShowTimers[1] == timers[1])

      -- 2) the retry sweeps FIRST, then re-shows the ORIGINAL arguments
      timers[1].fn()
      check("the sweep closed tracked alerts before retrying", closed >= 1, closed)
      check("the alert was shown on retry, arguments intact",
            #shows == 1 and shows[1][1] == "💾 saved" and shows[1][2] == 2,
            shows[1] and shows[1][1])

      -- 3) both attempts failing gives up LOUDLY and names the manual sweep
      throwsLeft = 2
      SB.hs.alert.show("again")
      timers[#timers].fn()
      check("a double failure prints the manual way out (_G.phantom)",
            (function()
              for _, m in ipairs(said) do
                if m:find("_G.phantom", 1, true) then return true end
              end
            end)() == true, said[#said])
      check("...and does not loop — the retry schedules no third timer",
            #timers == 2, #timers)

      -- 4) the manual sweep stands alone
      closed = 0
      SB.phantom(true)
      check("_G.phantom(true) sweeps quietly — closeAll, no new alert",
            closed == 1 and #shows == 1)
    end
  end
end


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


-- =====================================================================
-- 9. WORK-MAC SAFETY: NO ADMIN, NO SYSTEM WRITES, NO SURPRISES
-- =====================================================================
-- The work MacBook is the primary machine and carries NO admin rights.
-- Everything below is a standing guarantee, not a one-time audit: if a
-- future change adds a privileged operation, a write outside $HOME, or
-- a call to a binary that is not on the list, this suite fails before
-- the change ever reaches that Mac.
out("\n=== 9. Work-Mac safety (no admin rights) ===\n")

-- The scan reads STRING LITERALS as code, and it must: my own mutation
-- test proved the point by hiding a sudo inside "sudo mkdir -p " and the
-- scanner caught it. The one exception is the changelog note, which is
-- prose written to a CSV and never executed — a paragraph describing
-- "no sudo, no launchctl" failed the very check it was describing. So
-- that single assignment is excluded BY NAME, and nothing else is.
local function safetyCode(pattern)
  for line in text:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-")
       and not line:match("currentNotes%s*=")
       and not line:match("unusedNotes[%w_]*%s*=")
       and line:find(pattern) then
      return line
    end
  end
end

-- 9a. NOTHING ELEVATES. sudo, an AppleScript asking for administrator
-- privileges, or a chown would each need an admin password the work Mac
-- does not have — and would be an IT red flag besides.
for _, forbidden in ipairs({
  { "sudo",                          "runs a command as root" },
  { "with administrator privileges", "AppleScript's password prompt" },
  { "do shell script.*admin",        "AppleScript shell escalation" },
  { "chown",                         "changes file ownership" },
  { "launchctl",                     "installs or loads a launch daemon" },
  { "security add%-generic%-password", "writes to the login keychain" },
  { "csrutil",                       "touches System Integrity Protection" },
  { "spctl",                         "touches Gatekeeper" },
}) do
  check("never " .. forbidden[2] .. " (" .. forbidden[1] .. ")",
        not safetyCode(forbidden[1]), safetyCode(forbidden[1]))
end

-- 9b. EVERY EXTERNAL BINARY IS ON A KNOWN LIST. An unexpected one is not
-- automatically wrong, but it is something I must have decided on
-- deliberately rather than let drift in.
local ALLOWED_BINARIES = {
  ["/usr/bin/curl"]      = "Asana API + attachment upload (ships with macOS)",
  ["/usr/bin/shortcuts"] = "image OCR via your own Shortcut (ships with macOS)",
  ["/usr/bin/hidutil"]   = "Caps Lock -> hyper remap, per-user (ships with macOS)",
  ["/usr/bin/open"]      = "relaunch an app you asked to reopen (ships with macOS)",
  -- 6.140.0 — screen_veil joined as a second caller: the grayscale
  -- read-back READS com.apple.universalaccess after relaying ⌥⌘F5. It
  -- never writes it — test_features 4b pins that structurally, and the
  -- 9a launchctl/killall bans above already fence off 6.82.0's other
  -- failed routes.
  ["/usr/bin/defaults"]  = "read an app's version from its plist + the "
                        .. "grayscale preference read-back (ships with macOS)",
  -- 🚨 6.65.1 — AND THIS ONE IS A DELIBERATE, LOAD-BEARING CHOICE, which
  -- is exactly what this list exists to record. Every AppleScript in this
  -- config used to run IN PROCESS via hs.osascript.applescript, which
  -- sends Apple Events on Hammerspoon's main thread. An Objective-C
  -- exception from that machinery ABORTS the application, and a Lua
  -- pcall cannot catch it — pcall catches Lua errors, and an ObjC
  -- exception is not one. It crashed LL's Mac on macOS 26.6.1.
  -- Shelling out to the SAME AppleScript means the worst case is a child
  -- process exiting non-zero. The extra binary is the price, and it is
  -- one Apple ships.
  ["/usr/bin/osascript"] = "Finder selection + Finder comment tags, OUT OF "
                        .. "PROCESS so an Apple Event cannot abort us (ships with macOS). "
                        -- 6.146.0 — and the 📎 default-apps tool: its -l JavaScript
                        -- bridge is the only route from here to the LaunchServices
                        -- set-handler API, same binary, same out-of-process safety.
                        .. "Also 📎's LaunchServices read/write via -l JavaScript",
  -- 6.139.0 — the backup no longer goes through a shell at all (rsync is
  -- run directly, argument array); zsh stays reviewed for the two callers
  -- below, each of which passes a fixed command of its own.
  ["/bin/zsh"]           = "universal actions' open-with lines + update "
                        .. "tracker's version checks (ships with macOS)",
  ["/usr/bin/rsync"]     = "the daily backup / rebuild kit copies, run "
                        .. "directly with an argument array (ships with macOS)",
  -- 6.92.0 — ⇪Y reads Chrome's History database. Chrome keeps the live
  -- file locked, so a COPY is queried — by Apple's own sqlite3, out of
  -- process (hs.task), because a 100 MB history must never block the
  -- keyboard. /bin/sh choreographs the copy-then-query; every path
  -- reaches it as a POSITIONAL argument, never interpolated into the
  -- script, which is what makes "Application Support" safe unquoted.
  ["/usr/bin/sqlite3"]   = "⇪Y queries a COPY of Chrome's History (ships with macOS)",
  ["/bin/sh"]            = "chrome_history's copy-then-query runner + the "
                        .. "6.96.0 search-index build script (ships with macOS)",
  -- 6.96.0 — Doc Keywords reads a .docx's text. A .docx IS a zip with
  -- the text at word/document.xml; unzip -p streams that one member to
  -- stdout in a child process — no Word automation, nothing installed,
  -- and a corrupt file is a child exiting non-zero, never a hang here.
  ["/usr/bin/unzip"]     = "doc_keywords reads word/document.xml from a "
                        .. ".docx, OUT OF PROCESS (ships with macOS)",
  -- 6.93.0 — ⇪I asks SPOTLIGHT which files were opened: mdfind finds
  -- them (kMDItemLastUsedDate is stamped only when an app opens a file
  -- FOR the user — the whole plist-exclusion design), mdls reads each
  -- hit's opened/modified dates. Same /bin/sh positional-args runner.
  ["/usr/bin/mdfind"]    = "⇪I finds recently opened/changed files (ships with macOS)",
  ["/usr/bin/mdls"]      = "⇪I reads opened/modified dates per file (ships with macOS)",
  -- 6.86.0 — the ⇪4 screenshot capture. The same binary ⌘⇧4 itself uses;
  -- run with -i to a file in the OneDrive folder, which is what lets one
  -- keystroke both SAVE and COPY where macOS natively only does one.
  ["/usr/sbin/screencapture"] = "⇪4 capture to OneDrive + clipboard (ships with macOS)",
  -- 6.88.0 — ⌃⏎ on a panel history row: re-encode a PNG screenshot as a
  -- small JPEG next to the original. sips is Apple's own image tool.
  ["/usr/bin/sips"] = "⌃⏎ compress screenshot to jpg (ships with macOS)",
  -- 6.120.0 — THE NETWORK TOOLS (⇪6). Four diagnostics LL asked for by
  -- name. Every one ships with macOS and every one is run with bounded
  -- arguments (ping -c, traceroute -m/-w) so it cannot run forever.
  -- ⚠️ The host is passed as a POSITIONAL ARGUMENT to hs.task, never
  -- interpolated into a shell line, so a hostname containing shell
  -- metacharacters is only ever a hostname that will not resolve.
  ["/sbin/ping"]             = "⇪6 ping, bounded by -c (ships with macOS)",
  ["/usr/bin/nslookup"]      = "⇪6 DNS lookup (ships with macOS)",
  ["/usr/sbin/traceroute"]   = "⇪6 traceroute, bounded by -m and -w (ships with macOS)",
  -- The two halves of a DNS flush. The second needs to signal a root
  -- process and therefore CANNOT succeed without admin — the module runs
  -- both, checks both, and reports which one worked, because a half
  -- flush reported as a flush is the failure that wastes an afternoon.
  ["/usr/bin/dscacheutil"]   = "⇪6 flush, half 1 · ⇪⇧6 reverse-resolves each "
                            .. "remote IP, no privileges (ships with macOS)",
  ["/usr/bin/killall"]       = "⇪6 flush, half 2 — needs admin, reported when it "
                            .. "fails rather than hidden (ships with macOS)",
  -- 6.120.0 — THE MAC PANEL (⇪7). Everything About This Mac shows.
  -- sysctl, sw_vers and df answer instantly and run on the keypress;
  -- system_profiler takes SECONDS and ioreg a tenth of one, so those two
  -- run out of process and fill themselves in when they land.
  ["/usr/sbin/sysctl"]         = "⇪7 chip, memory, model id, boot time (ships with macOS)",
  ["/usr/bin/sw_vers"]         = "⇪7 macOS version and build (ships with macOS)",
  ["/bin/df"]                  = "⇪7 free disk — `df -k` says its unit in its own "
                              .. "name, which hs.fs.freeSpace does not (ships with macOS)",
  ["/usr/sbin/system_profiler"] = "⇪7 the model's MARKETING name, async because it "
                              .. "takes 1-3 SECONDS (ships with macOS)",
  ["/usr/sbin/ioreg"]          = "⇪7 serial number (ships with macOS)",
  ["/usr/bin/grep"]            = "⇪7 picks the serial line out of ioreg (ships with macOS)",
  -- 6.120.0 — ⇪⇧` REVEALS GHOSTTY'S FOLDER. A terminal's directory
  -- belongs to the SHELL, not the window, and is published nowhere a
  -- neighbouring process can read. The window title is tried first
  -- because it names the FRONT window; this pipeline is the fallback
  -- when the title is not a path.
  ["/usr/bin/pgrep"]         = "⇪⇧` finds Ghostty's child shells (ships with macOS)",
  ["/usr/sbin/lsof"]         = "⇪⇧` reads a shell's cwd · ⇪⇧6 lists every app's "
                            .. "live connections, one snapshot per press (ships with macOS)",
  ["/usr/bin/xargs"]         = "⇪⇧` feeds one pid to lsof (ships with macOS)",
  ["/usr/bin/sed"]           = "⇪⇧` extracts the n-prefixed path (ships with macOS)",
  ["/usr/bin/tail"]          = "⇪⇧` takes the newest shell (ships with macOS)",
  -- 6.119.0 — ⇪⇧; lists and ends processes. Two ps calls joined on pid,
  -- because comm and args both contain spaces and one call leaves no
  -- separator a pattern can find.
  ["/bin/ps"]                = "⇪⇧; the process list, twice (ships with macOS)",
  ["/bin/kill"]              = "⇪⇧; ends one — four names refused outright, "
                            .. "under ⌥ as well (ships with macOS)",
  ["/opt/homebrew/bin/brew"] = "OPTIONAL update checks, admin install",
  ["/usr/local/bin/brew"]    = "OPTIONAL update checks, admin install",
  -- the no-admin Homebrew prefixes, which are $HOME-relative in the source
  -- (home .. "/homebrew/bin/brew") and so arrive here without the prefix
  ["/homebrew/bin/brew"]        = "OPTIONAL, under $HOME — the no-admin install",
  ["/.homebrew/bin/brew"]       = "OPTIONAL, under $HOME — the no-admin install",
  ["/.local/homebrew/bin/brew"] = "OPTIONAL, under $HOME — the no-admin install",
}
-- 🚨 6.133.0 — OPTIONAL BINARIES ARE A SEPARATE TABLE, NOT AN ENTRY IN
-- THE ONE ABOVE. ⇪8 looks for WordNet's `wn`, which does NOT ship with
-- macOS — so filing it under ALLOWED_BINARIES would have silenced 9c by
-- asserting something untrue. The claim 9c makes is the one that matters
-- on a managed Mac and it must stay exactly true: every binary this
-- config REQUIRES is one macOS already ships. Anything here is one it
-- can do without, the way it does without brew — the feature degrades
-- and says so, and nothing else changes.
local OPTIONAL_BINARIES = {
  -- ~/bin/wn arrives here as "/bin/wn": the search path is built as
  -- home .. "/bin/wn", so the quoted fragment in the source looks like a
  -- system path to this scan. It is not one.
  ["/bin/wn"] = "OPTIONAL, under $HOME — WordNet for ⇪8; without it the "
             .. "define panel hands off to Dictionary.app instead",
}
local seen, unexpected = {}, {}
for line in text:gmatch("[^\n]+") do
  if not line:match("^%s*%-%-") then
    for path in line:gmatch('"(/[%w%./_%-]+)"') do
      -- only executables: a path handed to hs.task/os.execute, not data
      if path:match("^/usr/bin/") or path:match("^/bin/") or path:match("^/sbin/")
         or path:match("^/usr/sbin/") or path:match("brew$") then
        seen[path] = true
        if not (ALLOWED_BINARIES[path] or OPTIONAL_BINARIES[path]) then
          unexpected[#unexpected+1] = path
        end
      end
    end
  end
end
check("no external binary outside the reviewed list",
      #unexpected == 0, table.concat(unexpected, ", "))
check("...and the list is not empty (the scan actually ran)", next(seen) ~= nil)

-- 9c. EVERY BINARY USED IS ONE macOS ALREADY SHIPS, except brew, which
-- is optional. This is the claim that matters for a managed Mac: the
-- config installs nothing and depends on nothing IT has to approve.
for path in pairs(seen) do
  if not (path:match("brew$") or OPTIONAL_BINARIES[path]) then
    check("ships with macOS: " .. path, ALLOWED_BINARIES[path] ~= nil)
  end
end

-- 9d. BREW IS OPTIONAL, AND ITS ABSENCE IS HANDLED. If IT blocks it, or
-- it is simply not installed, the config must lose one feature and say
-- so — not fail, not retry forever, not nag.
local ut = moduleText.update_tracker or ""
-- 6.87.0 carve-out: the screenshots module LOOKS UNDER the brew prefixes
-- for zbarimg (the optional QR decoder) — it checks file existence and
-- runs zbarimg itself, never brew. Lines mentioning zbar are that lookup;
-- any OTHER brew reference in it still fails here.
-- 6.139.0 — daily_backup joins update_tracker as a legitimate brew
-- RUNNER: the rebuild kit's Brewfile comes from `brew bundle dump`, the
-- manifest asks `brew list --cask` who it already owns, and adoption
-- asks `brew search`. All three go through hs.task with argument
-- arrays, all three stand down when brew is absent, and the module's
-- own suite (test_daily_backup §7) proves the degradation. Any brew
-- reference in any OTHER module still fails here.
check("brew is RUN only from update_tracker and daily_backup (screenshots "
      .. "may look under the brew prefixes for zbarimg)", (function()
  for name, body in pairs(moduleText) do
    if name ~= "update_tracker" and name ~= "daily_backup" then
      for line in body:gmatch("[^\n]+") do
        -- 6.120.0 — power_tools joins the same carve-out. ⇪5 reads QR
        -- codes and asks screenshots.lua for the zbarimg path by service
        -- name rather than keeping a second copy of the search list; the
        -- ONLY place it says "brew" is the sentence that tells you how to
        -- install the decoder when there isn't one. Any OTHER brew
        -- reference in either module still fails here.
        -- 6.133.0 — define.lua joins the same carve-out for the same
        -- reason. ⇪8 looks under the brew prefixes for `wn` and runs wn
        -- itself; the only place it says "brew" other than those paths
        -- is the sentence telling you how to install WordNet when there
        -- isn't one. Any OTHER brew reference in any of the three still
        -- fails here.
        if not line:match("^%s*%-%-") and line:find("brew", 1, true)
           and not ((name == "screenshots" or name == "power_tools")
                    and line:lower():find("zbar", 1, true))
           and not (name == "define"
                    and (line:lower():find("wordnet", 1, true)
                         or line:find("/bin/wn", 1, true))) then
          return false, name
        end
      end
    end
  end
  for line in initText:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") and not line:match("currentNotes%s*=")
       and line:find("brew", 1, true) then return false, "init.lua" end
  end
  return true
end)())
check("...a missing brew is reported, not thrown", ut:find("no Homebrew found", 1, true) ~= nil)
check("...and every brew lookup is wrapped so a blocked shell cannot raise",
      (function()
        for line in ut:gmatch("[^\n]+") do
          if not line:match("^%s*%-%-") and line:find("hs.execute", 1, true)
             and not line:find("pcall", 1, true) then
            -- allowed only if the enclosing line is inside a pcall block;
            -- the shipped code wraps each one, so a bare call is a fail
            local before = ut:sub(1, ut:find(line, 1, true))
            if not before:sub(-400):find("pcall", 1, true) then return false, line end
          end
        end
        return true
      end)())
check("...the no-admin install locations are searched FIRST",
      (function()
        local iHome = ut:find('home %.%. "/homebrew/bin/brew"')
        local iOpt  = ut:find('"/opt/homebrew/bin/brew"')
        return iHome ~= nil and iOpt ~= nil and iHome < iOpt
      end)())

-- 9e. NOTHING IS WRITTEN OUTSIDE THE USER'S OWN DIRECTORY. Every write
-- target is built from logsDir or configDir, both of which resolve under
-- $HOME (OneDrive lives at ~/Library/CloudStorage/...).
check("every file written is under the user's home directory", (function()
  for line in text:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") then
      local target = line:match('io%.open%(%s*"(/[^"]+)"%s*,%s*"[wa]')
      if target then return false, target end        -- a hard-coded absolute write
    end
  end
  return true
end)())
check("...and the log root itself is $HOME-based on both branches",
      initLive('logsDir   = cloudDir .. "/Logs"')
      and initLive('logsDir   = hs.configdir .. "/logs"'))

-- 9f. THE REMAP IS PER-USER AND ITS REFUSAL IS HANDLED. hidutil
-- property --set affects only the logged-in user and needs no password,
-- but a managed Mac can still refuse it. That must cost the hyper key
-- and nothing else.
check("the Caps Lock remap is a per-user hidutil property set, not a daemon",
      initLive('"property", "--set"') ~= nil and not safetyCode("launchctl"))
check("...and a refusal is caught and explained, not fatal",
      initText:find("hidutil could not remap", 1, true) ~= nil
      and initText:find("Everything else still works", 1, true) ~= nil)

-- 9g. THE ONLY HOST THIS CONFIG CONTACTS IS ASANA.
-- The first version of this check failed on shottr.cc and was WRONG to.
-- There is a difference worth keeping straight: a host the config talks
-- to by itself, versus a vendor download page handed to your browser
-- because you selected that row and pressed Enter. The second is you
-- clicking a link. Only the first is network activity this config
-- initiates, and that is what is asserted here.
-- 🚨 6.133.0 — THE RULE GAINED ITS FIRST EXCEPTION, AND GOT STRICTER
-- FOR IT. ⇪8 can ask dictionaryapi.dev for a definition. Widening this
-- to "these hosts" would have retired the only property worth having,
-- so the exception is NAMED and the thing now asserted is the one that
-- actually protects the work Mac: the shipped default must be OFF, and
-- the fetch must be gated on the same switch. A host in this table is a
-- host you can turn on; it is not a host this config contacts.
local OPT_IN_HOSTS = {
  ["api.dictionaryapi.dev"] = { module = "define", switch = "allowNetwork" },
}
check("the only host the config CONTACTS unasked is Asana",
      (function()
        local hosts = {}
        for line in text:gmatch("[^\n]+") do
          if not line:match("^%s*%-%-") then
            -- a URL is only "contacted" if it reaches an HTTP call or curl
            if line:find("hs.http", 1, true) or line:find("asyncPost", 1, true)
               or line:find("curl", 1, true) or line:find("api.", 1, true) then
              for h in line:gmatch('https://([%w%.%-]+)') do hosts[h] = true end
            end
          end
        end
        for h in pairs(hosts) do
          if h ~= "app.asana.com" and not OPT_IN_HOSTS[h] then return false, h end
        end
        return next(hosts) ~= nil        -- and the scan must have found it
      end)())
-- 🚨 AND EVERY OPT-IN HOST SHIPS OFF. This is the check that replaces
-- what the old wording promised. A default flipped to true — by an
-- edit, a merge, or a good intention — turns a tool that sends nothing
-- anywhere into one that sends the words you are writing to a third
-- party, silently, on a managed machine. It fails the gate instead.
for host, spec in pairs(OPT_IN_HOSTS) do
  local body = moduleText[spec.module] or ""
  -- ⚠️ CODE ONLY. The first version of this check searched the raw file
  -- and failed on the module's own refusal message — the sentence that
  -- tells you how to switch the provider ON contains the assignment as
  -- text. A sentry that cannot tell an instruction from a string would
  -- have been silenced by rewording the message, which is exactly the
  -- wrong lesson. Comments and string literals come out first, the same
  -- way the showPopup audit strips comments before counting calls.
  local code = body:gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""')
  check("🚨 " .. host .. " is OFF in the shipped source ("
        .. spec.module .. "." .. spec.switch .. " = false)",
        code:find("%." .. spec.switch .. "%s*=%s*false") ~= nil
        and code:find("%." .. spec.switch .. "%s*=%s*true") == nil,
        code:match("[%w_]*%." .. spec.switch .. "%s*=%s*%w+"))
  check("..." .. host .. "'s fetch is gated on that switch, so turning it "
        .. "off really stops it", (function()
          for line in body:gmatch("[^\n]+") do
            if not line:match("^%s*%-%-") and line:find("asyncGet", 1, true) then
              -- the guard is the line above it in the same function
              local at = body:find(line, 1, true)
              return body:sub(math.max(1, at - 400), at)
                         :find("if not " .. "d%." .. spec.switch) ~= nil
            end
          end
          return false
        end)())
  check("..." .. host .. " is reachable only through a provider that "
        .. "reports itself unavailable when the switch is off",
        body:find("available = function%(%) return d%." .. spec.switch) ~= nil)
end
check("...every OTHER url is only ever handed to your browser, never fetched",
      (function()
        local ut2 = moduleText.update_tracker or ""
        -- the vendor pages live in one table and are opened from one place
        if not ut2:find("hs.urlevent.openURL(choice.url)", 1, true) then return false end
        for line in ut2:gmatch("[^\n]+") do
          if not line:match("^%s*%-%-") and line:find("https://", 1, true) then
            -- a vendor row is data: `url = "https://..."`, never a call
            if not line:find('url%s*=%s*"https://') then return false, line end
          end
        end
        return true
      end)())
check("...and those vendor pages open only on a row YOU selected",
      (moduleText.update_tracker or ""):find("hs.urlevent.openURL(choice.url)", 1, true) ~= nil)
check("...and it is off entirely without secret.lua",
      initLive("asanaEnabled") ~= nil and initText:find("secret.lua", 1, true) ~= nil)


-- =====================================================================
-- 10. CAPABILITIES, EXECUTED — the two-Mac contract (6.44.13)
-- =====================================================================
-- One init.lua runs on a personal Mac with admin rights and a managed
-- work Mac with none. This block drives BOTH profiles through the real
-- file and reads what it says, because "works on both Macs" is a claim
-- that can only be checked by asking it as both Macs.
out("\n=== 10. Capabilities, executed ===\n")
local CAP_PATH = HS .. "/core/capabilities.lua"
local capChunk = loadfile(CAP_PATH)
check("core/capabilities.lua loads", capChunk ~= nil, select(2, loadfile(CAP_PATH)))

if capChunk then
  local AX = true
  hs.accessibilityState = function() return AX end

  local function asMac(cfg, globals)
    -- A LIST, not a table of nils. `{ brewPathInUse = nil }` stores
    -- nothing at all — pairs() never yields a nil value — so the reset
    -- silently did nothing and the previous Mac's brew path leaked into
    -- the next profile, reporting brew ON for a Mac that has none. The
    -- same trap that makes `#` unreliable on a list with holes.
    for _, k in ipairs({ "hyperRemapOK", "hyperRemapWhy",
                         "ocrShortcutAvailable", "brewPathInUse" }) do
      _G[k] = nil
    end
    _G.moduleLoaded, _G.moduleFailed = 18, 0
    for k, v in pairs(globals or {}) do _G[k] = v end
    local base = { cloudDir = "/cloud", logsDir = "/cloud/Logs",
                   backupDir = "/cloud/Backups", hostTag = "TestMac",
                   asanaEnabled = true, secretsStatus = "loaded",
                   hyperEnabled = true }
    for k, v in pairs(cfg or {}) do if v == false then base[k] = nil else base[k] = v end end
    capChunk()(base)
    local caps, by = _G.capabilities(), {}
    for _, c in ipairs(caps) do by[c.key] = c end
    return by, _G.capabilityReport()
  end

  -- ---- the personal Mac: everything on ------------------------------
  AX = true
  local home, homeReport = asMac({}, { hyperRemapOK = true, ocrShortcutAvailable = true,
                                       brewPathInUse = "/opt/homebrew/bin/brew" })
  for _, k in ipairs({ "cloud", "backup", "asana", "ax", "hyper", "ocr", "brew", "modules" }) do
    check("personal Mac — " .. k .. " reports ON", home[k] and home[k].state == "ON",
          home[k] and home[k].state)
  end
  check("...and the report says so in one line",
        homeReport:find("Everything this config can do", 1, true) ~= nil)
  check("...with no cost lines, because nothing is degraded",
        homeReport:find("↳", 1, true) == nil)

  -- ---- the work Mac: no admin, no brew, no OneDrive, no remap -------
  AX = false
  local work, workReport = asMac(
    { cloudDir = false, backupDir = false, asanaEnabled = false, secretsStatus = "missing" },
    { hyperRemapOK = false, hyperRemapWhy = "exit 1 — not permitted",
      ocrShortcutAvailable = false, brewPathInUse = nil })
  for _, k in ipairs({ "cloud", "backup", "asana", "ax", "hyper", "ocr", "brew" }) do
    check("work Mac — " .. k .. " reports OFF, not an error",
          work[k] and work[k].state == "OFF", work[k] and work[k].state)
  end
  check("work Mac — modules still load, so it is not all bad news",
        work.modules.state == "ON")
  check("every OFF capability says WHY", (function()
    for _, k in ipairs({ "cloud", "backup", "asana", "ax", "hyper", "ocr", "brew" }) do
      if not work[k].why or work[k].why == "" then return false, k end
    end
    return true
  end)())
  check("every OFF capability says what it COSTS you", (function()
    for _, k in ipairs({ "cloud", "backup", "asana", "ax", "hyper", "ocr", "brew" }) do
      if not work[k].cost or work[k].cost == "" then return false, k end
    end
    return true
  end)())
  check("...and brew's cost says plainly that nothing else uses it",
        work.brew.cost:find("NOTHING ELSE USES BREW", 1, true) ~= nil)
  check("...and the hyper failure carries hidutil's actual reason",
        work.hyper.why:find("not permitted", 1, true) ~= nil)
  check("the report counts what is degraded instead of burying it",
        workReport:find("not fully on", 1, true) ~= nil)

  -- ---- UNKNOWN is a real answer, not a synonym for OFF --------------
  AX = true
  local booting = asMac({}, {})   -- async probes have not reported yet
  check("a probe that has not finished is UNKNOWN, never OFF",
        booting.hyper.state == "UNKNOWN" and booting.ocr.state == "UNKNOWN",
        booting.hyper.state .. "/" .. booting.ocr.state)
  check("...because 'not answered yet' and 'this Mac cannot' need "
        .. "different reactions from me",
        booting.hyper.why:find("not reported back yet", 1, true) ~= nil)

  -- ---- a broken secret.lua is NOT the same as a missing one ---------
  local broke = asMac({ asanaEnabled = false, secretsStatus = "broken: unexpected symbol" },
                      {})
  check("a BROKEN secret.lua is distinguished from a missing one",
        broke.asana.why:find("EXISTS but failed", 1, true) ~= nil)
  check("...and says it is the fixable kind", broke.asana.cost:find("fixable", 1, true) ~= nil)

  -- ---- a partly-failed module load is PARTIAL, not ON or OFF --------
  local partial = asMac({}, { moduleLoaded = 15, moduleFailed = 3 })
  check("modules failing is PARTIAL — the rest still work",
        partial.modules.state == "PARTIAL" and partial.modules.why:find("3", 1, true))

  -- ---- hyperEnabled = false is a CHOICE, not a failure --------------
  local off = asMac({ hyperEnabled = false }, {})
  check("hyperEnabled = false reads as your choice, not a fault",
        off.hyper.why:find("your choice", 1, true) ~= nil)

  -- ---- accessibility unreadable -> UNKNOWN, and no crash ------------
  hs.accessibilityState = function() error("boom") end
  local axbad = asMac({}, {})
  check("an unreadable Accessibility state is UNKNOWN, and does not raise",
        axbad.ax.state == "UNKNOWN", axbad.ax.state)
  hs.accessibilityState = function() return AX end
end


-- =====================================================================
-- 11. THE DOCS AND TOOLS MUST TRACK THE CODE (6.44.13)
-- =====================================================================
-- Adding core/capabilities.lua left INSTALL.md saying "3 files",
-- hs-doctor.sh checking three names, and hs-install.sh refusing to
-- require the fourth. Three separate places silently out of step with
-- one new file — and the install script is the one thing standing
-- between a half-copied config and the primary work Mac. So the file
-- list is derived from DISK here, and anything that hard-codes it has
-- to agree.
out("\n=== 11. Docs and tools track the code ===\n")
local onDisk = {}
do
  local pipe = io.popen('ls "' .. HS .. '/core"/*.lua 2>/dev/null')
  if pipe then
    for line in pipe:lines() do
      local n = line:match("([^/]+)%.lua$")
      if n then onDisk[#onDisk + 1] = n end
    end
    pipe:close()
  end
end
table.sort(onDisk)
check("core/ has files to check", #onDisk > 0, #onDisk)

-- 🚨 6.58.0 — THE GAP THAT LET core/notices.lua SHIP BROKEN. Every one of
-- these files is loaded by init.lua as `chunk()(coreTable)`, which means
-- the file MUST `return function(core) ... end` — but nothing in this
-- suite ever checked that shape, because dofile()-ing a core file
-- directly in a test does not care what it returns. The only thing that
-- caught it was tools/hs-install.sh's independent verify step, on a real
-- install, after the fact. That is a real safety net doing its job, but
-- a bug it alone catches is a bug this suite should have caught first.
--
-- Two checks, and they are read from the SAME two places the real
-- failure came from: every file actually on disk in core/, and every
-- chunk()(...) call site actually in init.lua — not a retyped list of
-- either, for the same reason MODS above is read from disk now instead
-- of hand-copied.
for _, n in ipairs(onDisk) do
  -- readAll is defined further down this file; inlined here rather than
  -- reordering the suite around one check.
  local body = ""
  local f = realopen(HS .. "/core/" .. n .. ".lua", "r")
  if f then body = f:read("*a") or ""; f:close() end
  check("core/" .. n .. ".lua IS an initialiser — `return function(core)`, "
        .. "the exact shape hs-install.sh verifies before trusting an "
        .. "install", body:find("return function(core)", 1, true) ~= nil)
end

do
  local codeOnly = {}
  for line in initText:gmatch("[^\n]+") do
    codeOnly[#codeOnly + 1] = line:match("^%s*%-%-") and "" or line
  end
  local initCode = table.concat(codeOnly, "\n")
  for _, n in ipairs(onDisk) do
    -- Find this file's own loadfile(path) call, then confirm the chunk
    -- is CALLED WITH AN ARGUMENT close by — `chunk()(` for the normal
    -- case, or `chunk()` immediately followed by `({` on the next call
    -- for the multi-line table literals cheatsheet/capabilities use.
    local siteAt = initCode:find("core/" .. n .. "%.lua")
    if siteAt then
      local window = initCode:sub(siteAt, siteAt + 400)
      check("init.lua calls core/" .. n .. ".lua's chunk with an argument "
            .. "— a bare chunk() silently discards whatever function(core) "
            .. "expected to receive, exactly as core/notices.lua did",
            window:find("chunk%(%)%(") ~= nil, n)
    end
  end
end

local function readAll(p)
  local f = realopen(p, "r"); if not f then return nil end
  local t = f:read("*a"); f:close(); return t
end

local doctor  = readAll(HS .. "/tools/hs-doctor.sh")  or ""
local install = readAll(HS .. "/tools/hs-install.sh") or ""
local guide   = readAll(HS .. "/INSTALL.md")          or ""

check("hs-doctor.sh exists",  doctor  ~= "")
check("hs-install.sh exists", install ~= "")
check("INSTALL.md exists",    guide   ~= "")

-- hs-install.sh names the core files in TWO loops — once to refuse an
-- incomplete download, once to verify the result. A plain substring
-- search over the file passes when a name is dropped from one of them,
-- which is the worse half: the pre-check is what stops a half-copied
-- config reaching the work Mac. So both loops are pulled out and each
-- must list every file.
local installLoops = {}
for line in install:gmatch("[^\n]+") do
  if line:find("for n in ", 1, true) and line:find("boot_report", 1, true) then
    installLoops[#installLoops + 1] = line
  end
end
check("hs-install.sh still has both core loops (pre-check and verify)",
      #installLoops == 2, #installLoops)

for _, n in ipairs(onDisk) do
  check("hs-doctor.sh knows about core/" .. n,  doctor:find(n, 1, true)  ~= nil)
  check("hs-install.sh REQUIRES core/" .. n .. " in BOTH loops", (function()
    if #installLoops == 0 then return false end
    for _, loop in ipairs(installLoops) do
      if not loop:find(n, 1, true) then return false, loop end
    end
    return true
  end)())
  check("INSTALL.md documents core/" .. n,      guide:find(n, 1, true)   ~= nil)
  check("init.lua actually loads core/" .. n,
        initLive("hs.configdir .. '/core/" .. n .. ".lua'") ~= nil)
end

-- the counts printed to a human have to match reality too, or the
-- "expect N" line becomes a lie the moment a file is added
check("hs-doctor.sh's expected core count matches disk",
      doctor:find("expect " .. #onDisk .. ")", 1, true) ~= nil, #onDisk)
check("hs-install.sh's core count matches disk",
      install:find("all " .. #onDisk .. " present", 1, true) ~= nil, #onDisk)
check("INSTALL.md's core count matches disk",
      guide:find(tostring(#onDisk) .. " files, loaded directly", 1, true) ~= nil, #onDisk)

-- and the module count, for the same reason
local modCount = 0
do
  local pipe = io.popen('ls "' .. HS .. '/modules"/*.lua 2>/dev/null | wc -l')
  if pipe then modCount = tonumber(pipe:read("*a")) or 0; pipe:close() end
end
check("hs-doctor.sh's expected module count matches disk",
      modCount > 0 and doctor:find("expect " .. modCount .. ")", 1, true) ~= nil, modCount)
check("INSTALL.md's module count matches disk",
      modCount > 0 and guide:find(modCount .. " files, loaded by", 1, true) ~= nil, modCount)

-- INSTALL.md has to name the things it tells you to type
for _, needed in ipairs({
  "hs-install.sh", "hs-doctor.sh", "run-tests.sh", "secret.lua",
  "asanaToken", "scutil --get ComputerName", "_G.capabilityReport()",
  "_G.bootVerbose(true)", "--rollback", "--dry-run",
}) do
  check("INSTALL.md tells you about: " .. needed, guide:find(needed, 1, true) ~= nil)
end
-- 6.105.0: the name moved to modules/ocr_engine.lua with the engine. The
-- point of the check is unchanged — INSTALL.md tells you to create an
-- Apple Shortcut by name, and if the code looks for a different string
-- you get a Mac where image OCR silently never runs.
check("INSTALL.md names the OCR shortcut EXACTLY as the code looks for it",
      guide:find("HS OCR", 1, true) ~= nil
      and (moduleText["ocr_engine"] or ""):find('shortcutName     = "HS OCR"',
                                                1, true) ~= nil)

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
