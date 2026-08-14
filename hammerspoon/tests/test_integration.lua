-- =====================================================================
-- test_integration.lua — does the NEW module break the OLD config?
-- =====================================================================
--     lua5.4 test_integration.lua [/path/to/hammerspoon]
--
-- THE QUESTION THIS ANSWERS, WHICH NO OTHER SUITE HERE DOES. Every other
-- test file proves one module correct IN ISOLATION, against stubs. That
-- says nothing about what happens when nineteen of them share one Mac,
-- one keyboard, one hotkey table and one global namespace. A module can
-- be perfect on its own and still take a shortcut away from another one.
--
-- Two things are checked, and the first is the one that actually worries
-- me:
--
--   §1 THE HOTKEY STACK, SIMULATED FAITHFULLY. Mouse Grid binds BARE
--      letter keys (a s d f g h j k l) while its overlay is up. The hyper
--      key works by doing exactly the same thing — and init.lua §3.12
--      deliberately does NOT exit the hyper modal when a shortcut fires,
--      so while the grid is open BOTH modals have bare "a" bound at once.
--      Whether that works is decided entirely inside hs.hotkey's
--      shadowing stack, which no stub in this repo models.
--
--      So §1 reimplements enable()/disable() EXACTLY as they appear in
--      Hammerspoon's own hotkey.lua — same stack, same shadowing, same
--      un-shadow scan on disable — and drives the real key sequence
--      through it, in both release orders.
--
--   §2 THE WHOLE CONFIG, LOADED. All nineteen real modules through the
--      real §1.12 loader, then audited for the collisions that only show
--      up together: two modules claiming one ⇪ key, two claiming one
--      cheat-sheet slot, two publishing the same service or global.

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local HS   = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
             or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- =====================================================================
out("\n=== 1. THE HOTKEY STACK: hyper and the grid, both live ===\n")
-- =====================================================================
-- Lifted line-for-line from Hammerspoon's extensions/hotkey/hotkey.lua so
-- that what is tested is THEIR algorithm, not my idea of it. The details
-- that matter and that a naive stub gets wrong:
--   · enable() disables every OTHER hotkey on that combo but does NOT
--     clear their Lua-side `.enabled` flag — that is what lets them come
--     back later.
--   · disable() scans the stack top-down for the first still-`.enabled`
--     entry and re-enables it. That is the un-shadowing.
local hotkeys = {}
local FIRED
local function mkHotkey(idx, tag, fn)
    local hk = { idx = idx, tag = tag, fn = fn, enabled = nil, live = false }
    local h = hotkeys[idx] or {}
    h[#h + 1] = hk
    hotkeys[idx] = h
    return hk
end
local function enable(self)
    if self.enabled then return self end          -- nested shadowing
    local idx = self.idx
    for i = #hotkeys[idx], 1, -1 do
        local hk = hotkeys[idx][i]
        if hk == self then table.remove(hotkeys[idx], i) end
        hk.live = false                            -- objc disable
    end
    self.enabled = true
    self.live = true
    hotkeys[idx][#hotkeys[idx] + 1] = self
    return self
end
local function disable(self)
    if not self.enabled then return self end
    local idx = self.idx
    self.enabled = nil
    self.live = false
    for i = #hotkeys[idx], 1, -1 do
        if hotkeys[idx][i].enabled then hotkeys[idx][i].live = true; break end
    end
    return self
end
-- A modal is just a bag of hotkeys enabled/disabled together.
local function mkModal(tag)
    local m = { keys = {}, tag = tag }
    function m:bind(key, fn) self.keys[#self.keys + 1] = mkHotkey(key, tag, fn); return self end
    function m:enter() for _, hk in ipairs(self.keys) do enable(hk) end; return self end
    function m:exit()  for _, hk in ipairs(self.keys) do disable(hk) end;  return self end
    return m
end
-- Pressing a key runs whichever hotkey on that combo is actually live.
local function press(key)
    FIRED = nil
    for _, hk in ipairs(hotkeys[key] or {}) do
        if hk.live then
            FIRED = hk.tag
            if hk.fn then hk.fn() end
            return hk.tag
        end
    end
    return nil     -- nothing bound: the keystroke reaches the app
end

local HOMEROW = { "a", "s", "d", "f", "g", "h", "j", "k", "l" }
local hyper, gridPick

local function buildWorld()
    hotkeys = {}
    -- §3.12: every unclaimed bare key forwards the raw chord, so the hyper
    -- modal really does bind the whole alphabet, not just the shortcuts.
    hyper = mkModal("hyper")
    for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do hyper:bind(c) end
    gridPick = mkModal("grid")
    for _, c in ipairs(HOMEROW) do gridPick:bind(c) end
end

out("   -- ⇪ held, grid opened, letters typed --\n")
buildWorld()
hyper:enter()                                   -- Caps Lock down
check("with ⇪ held, a bare letter belongs to hyper", press("a") == "hyper")
gridPick:enter()                                -- ⇪X opened the grid
check("the grid SHADOWS hyper's bare letters while it is up — otherwise "
      .. "typing a cell code would fire hyper shortcuts instead",
      press("a") == "grid")
check("...for every letter in the alphabet, not just the first", (function()
    for _, c in ipairs(HOMEROW) do if press(c) ~= "grid" then return false, c end end
    return true
end)())
check("a letter the grid does NOT use still reaches hyper — the grid takes "
      .. "only what it needs", press("q") == "hyper")

out("   -- release ⇪ while the grid is still open --\n")
hyper:exit()                                    -- Caps Lock up
check("🚨 releasing ⇪ does NOT kill the grid's keys — this is the one that "
      .. "would make the grid unusable in normal one-handed use",
      press("a") == "grid")
check("...and hyper's own letters are properly gone", press("q") == nil)
gridPick:exit()                                 -- typed the code / escaped
check("closing the grid frees the bare letters completely — nothing is "
      .. "left eating your keystrokes", press("a") == nil)

out("   -- the other order: close the grid while ⇪ is still held --\n")
buildWorld()
hyper:enter()
gridPick:enter()
check("grid has the keys", press("a") == "grid")
gridPick:exit()                                 -- ⎋ while still holding ⇪
check("🚨 closing the grid RESTORES hyper's bare keys, because you are "
      .. "still holding Caps Lock — this is the un-shadow path",
      press("a") == "hyper")
hyper:exit()
check("releasing ⇪ afterwards leaves the keyboard clean", press("a") == nil)

out("   -- pathological: double-enter, double-exit, exit out of order --\n")
buildWorld()
hyper:enter(); gridPick:enter(); gridPick:enter()   -- re-entry is a no-op
check("entering the grid twice does not corrupt the stack", press("a") == "grid")
gridPick:exit(); gridPick:exit()
check("exiting twice does not strand hyper's keys", press("a") == "hyper")
hyper:exit(); hyper:exit()
check("exiting hyper twice leaves nothing live", press("a") == nil)

buildWorld()
gridPick:enter()                                -- grid without hyper at all
check("the grid works when hyper never entered (a Mac where the Caps Lock "
      .. "remap was refused, driven from the Console)", press("a") == "grid")
gridPick:exit()
check("...and cleans up after itself there too", press("a") == nil)

-- =====================================================================
out("\n=== 2. THE WHOLE CONFIG, LOADED TOGETHER ===\n")
-- =====================================================================
local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

local NOW = 100
local HYPER_CLAIMS, SERVICES, GLOBAL_HOTKEYS = {}, {}, {}
local noop = function() end
local function chain() local t = {} ; setmetatable(t, { __index = function()
    return function(s) return s or t end end }) ; return t end

hs = setmetatable({
    configdir = HS,
    timer = { secondsSinceEpoch = function() NOW = NOW + 0.001; return NOW end,
              doAt = function() return chain() end,
              doAfter = function() return chain() end,
              doEvery = function() return chain() end,
              new = function() return chain() end, usleep = noop },
    hotkey = { bind = function(mods, key)
                   local ms = {}
                   for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
                   table.sort(ms)
                   local combo = table.concat(ms, "+") .. "|" .. tostring(key):lower()
                   GLOBAL_HOTKEYS[combo] = (GLOBAL_HOTKEYS[combo] or 0) + 1
                   return chain() end,
               new = function() return chain() end,
               setLogLevel = noop,
               modal = { new = function()
                   local m = {}
                   function m:bind() return self end
                   function m:enter() return self end
                   function m:exit() return self end
                   return m end } },
    canvas = { new = function() return chain() end,
               windowLevels = { overlay = 25, screenSaver = 1000 } },
    screen = { allScreens = function() return {} end,
               mainScreen = function() return nil end,
               watcher = { new = function() return chain() end } },
    mouse = { absolutePosition = function() return { x = 0, y = 0 } end,
              getCurrentScreen = function() return nil end },
    eventtap = { leftClick = noop, rightClick = noop,
                 checkKeyboardModifiers = function() return {} end,
                 new = function() return chain() end,
                 keyStroke = noop, keyStrokes = noop,
                 event = { types = {}, properties = {},
                           newKeyEvent = function() return chain() end,
                           newMouseEvent = function() return chain() end } },
    accessibilityState = function() return true end,
    alert = { show = noop },
    fs = { attributes = function(p)
               local f = io.open(p, "r"); if not f then return nil end
               f:close(); return { mode = "file", size = 1 } end,
           dir = function() return function() return nil end end,
           mkdir = function() return true end },
    settings = { get = function() return nil end, set = noop },
    keycodes = { map = setmetatable({}, { __index = function() return 0 end }) },
    window = { orderedWindows = function() return {} end,
               focusedWindow = function() return nil end, filter = nil },
    application = { frontmostApplication = function() return nil end,
                    watcher = { new = function() return chain() end } },
    task = { new = function() return chain() end },
    http = { asyncGet = noop, asyncPost = noop,
             doRequest = function() return 200, "{}", {} end },
    pathwatcher = { new = function() return chain() end },
    caffeinate = { watcher = { new = function() return chain() end } },
    notify = { new = function() return chain() end },
    urlevent = { bind = noop },
    chooser = { new = function() return chain() end },
    pasteboard = { getContents = function() return "" end, setContents = noop,
                   changeCount = function() return 1 end },
    dialog = { blockAlert = function() return "OK" end },
    axuielement = { applicationElement = function() return nil end,
                    observer = { new = function() return nil end } },
    uielement = { watcher = { new = function() return nil end } },
    distributednotifications = { new = function() return chain() end },
    image = {}, styledtext = {}, drawing = { windowLevels = {} },
    execute = function() return "", true, "exit", 0 end,
    osascript = { applescript = function() return false, nil, nil end },
    inspect = tostring, json = { encode = function() return "{}" end,
                                 decode = function() return {} end },
    spaces = nil, host = { localizedName = function() return "Test-Mac" end },
    audiodevice = {}, battery = {}, brightness = {},
}, { __index = function() return chain() end })

_G.diag = { say = noop, warn = noop, err = noop, mark = noop, verbose = false }
_G.safeJson = function() return nil end
_G.service = { provide = function(n) SERVICES[n] = (SERVICES[n] or 0) + 1 end,
               call = noop, providers = {} }
_G.hyperPending = {}
_G.hyperAddShortcut = function(mods, key, fn, src)
    local ms = {}
    for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
    table.sort(ms)
    local combo = table.concat(ms, "+") .. "|" .. tostring(key):lower()
    HYPER_CLAIMS[combo] = HYPER_CLAIMS[combo] or {}
    table.insert(HYPER_CLAIMS[combo], src or "?")
end
_G.moduleStatus, _G.moduleCheatsheets = {}, {}
_G.choosers, _G.configVersion = {}, "test"

-- The §0.1/§1.5 globals loader_test.lua closes over when it builds the
-- `core` table. Same set test_modules.lua provides; kept in step with it.
homeDir, cloudDir, logsDir = "/tmp/h", "/tmp/c", "/tmp/l"
backupDir, hostTag = "/tmp/b", "Test-Mac"
warnWriteFailed, adoptLegacyFile = noop, noop
csvQuote = function(s) return s end
splitCSVLine = function(l)
    local o = {} ; for f in tostring(l):gmatch("[^,]+") do o[#o + 1] = f end ; return o end
formatDuration = function(s) return tostring(s) .. "s" end
popupScreenKeys = { mods = { "ctrl", "alt", "cmd" } }
showPopup = noop
resolveBaseScreen = function()
    return { frame = function() return { x = 0, y = 0, w = 3840, h = 2160 } end } end
panelAlpha, asanaEnabled, asanaToken, asanaWorkspaceId = 0.9, true, "tok", "ws"
asanaProjectId = "proj"

dofile(HERE .. "/loader_test.lua")     -- the REAL §1.12 loader
_G.moduleDir = HS .. "/modules"

-- 🚨 6.66.3 — THIS BLOCK USED TO READ ONLY THE `default` PROFILE, and
-- that is how four releases of new modules never reached LL's Mac.
--
-- The list is read from init.lua rather than retyped, on the sound
-- reasoning that a hand-copied list here would drift. But init.lua
-- carried THREE hand-copied lists, one per machine profile, and this read
-- the one that happened to be correct. The Tool Picker, Universal
-- Actions, the Pomodoro and the Outlook Probe were all in `default` and
-- in neither machine profile; his boot said "26 modules · All green"
-- because nothing failed — nothing was asked to load.
--
-- A test that reads the same wrong source as the code confirms the code
-- instead of checking it. So the source of truth is now BASE, and the
-- check below is against the FILESYSTEM: every module that exists must be
-- loaded by every profile, or be explicitly excluded.
local MODULES = {}
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or ""
    if f then f:close() end
    local block = init:match("local BASE = {(.-)\n}")
    for name in (block or ""):gmatch('"([%w_]+)"') do MODULES[#MODULES + 1] = name end
end
check("the module list was read from init.lua's BASE list", #MODULES >= 19, #MODULES)
check("mouse_grid is in it", (function()
    for _, m in ipairs(MODULES) do if m == "mouse_grid" then return true end end
end)())

-- 🚨 THE CHECK THAT WOULD HAVE CAUGHT IT: disk versus config.
do
    local onDisk, listed = {}, {}
    local p = io.popen('ls "' .. HS .. '"/modules/*.lua 2>/dev/null')
    if p then
        for line in p:lines() do
            local n = line:match("([%w_]+)%.lua$")
            if n then onDisk[#onDisk + 1] = n end
        end
        p:close()
    end
    for _, m in ipairs(MODULES) do listed[m] = true end
    local orphans = {}
    for _, n in ipairs(onDisk) do
        if not listed[n] then orphans[#orphans + 1] = n end
    end
    check("🚨 EVERY MODULE ON DISK IS IN BASE — a module file that no "
          .. "profile loads is a feature written, tested, shipped and "
          .. "ABSENT, and it reports 'All green' the whole time",
          #orphans == 0, table.concat(orphans, ", "))
    check("...and the check saw a real directory, so a broken glob cannot "
          .. "make it pass by finding nothing", #onDisk >= 25, #onDisk)
end

-- 🚨 AND EVERY PROFILE GETS THEM. The bug was not a short list; it was
-- THREE lists that could disagree. profileFrom() makes that structurally
-- impossible, and this proves the structure is actually used rather than
-- described in a comment.
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or "" ; if f then f:close() end
    local profileBlock = init:match("_G%.moduleProfiles = {(.-)\n}") or ""
    local handTyped = profileBlock:match("modules%s*=%s*{")
    check("🚨 NO profile hand-types its own module list — every one derives "
          .. "from BASE, so adding a module reaches all three Macs in one "
          .. "edit", handTyped == nil,
          handTyped and "a profile still has its own modules = { }" or nil)
    local n = select(2, profileBlock:gsub("profileFrom", ""))
    check("...and all three profiles use it", n >= 3, n)
end

-- ⚠️ loader_test.lua LOADS THE REAL LIST as a side effect of being
-- dofile'd. Measuring without clearing first counts every module twice
-- and reports each one as colliding with itself — which is exactly what
-- the collision checks below did on their first run. They work; the
-- harness did not.
HYPER_CLAIMS, SERVICES, GLOBAL_HOTKEYS = {}, {}, {}
_G.moduleStatus, _G.moduleCheatsheets = {}, {}
printed = {}

local loaded, failed = _G.loadModules(MODULES)
check("🚨 ALL " .. #MODULES .. " REAL MODULES LOAD TOGETHER — adding "
      .. "mouse_grid breaks none of the other eighteen",
      failed == 0 and loaded == #MODULES,
      loaded .. " loaded, " .. failed .. " failed")
if failed > 0 then
    for _, st in ipairs(_G.moduleStatus) do
        if not st.ok then failures[#failures + 1] = "   ↳ " .. st.name .. ": "
                          .. tostring(st.err) end
    end
end

out("   -- shortcut collisions --\n")
check("🚨 NO TWO MODULES CLAIM THE SAME ⇪ SHORTCUT", (function()
    local dupes = {}
    for combo, srcs in pairs(HYPER_CLAIMS) do
        if #srcs > 1 then dupes[#dupes + 1] = combo .. " (" .. table.concat(srcs, " vs ") .. ")" end
    end
    if #dupes > 0 then return false, table.concat(dupes, "; ") end
    return true
end)())
check("mouse_grid claimed exactly ⇪X and ⇪⇧X",
      HYPER_CLAIMS["|x"] ~= nil and HYPER_CLAIMS["shift|x"] ~= nil)
check("NO TWO MODULES CLAIM THE SAME GLOBAL CHORD (the panic keys)",
      (function()
    local dupes = {}
    for combo, n in pairs(GLOBAL_HOTKEYS) do
        if n > 1 then dupes[#dupes + 1] = combo .. " x" .. n end
    end
    if #dupes > 0 then return false, table.concat(dupes, "; ") end
    return true
end)())
check("the Mouse Grid panic key is bound and is NOT a ⇪ shortcut",
      GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|x"] == 1)
check("it does not collide with Screen Veil's panic key ⌃⌥⌘⇧G",
      GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|g"] == 1)

-- 🚨 6.66.4 — THE BOOT LINE'S SHORTCUT COUNT MUST INCLUDE MODULES.
-- It was #_G.hyperMigrations: the §0.4 migration map alone. Every
-- shortcut a module registers was invisible, so LL's boot line read
-- "32 ⇪ shortcuts" before AND after four modules added four keys. A
-- number printed at every login that looks like a total and is not is a
-- quiet misreport, and it sat next to the module count that DID show the
-- real problem — lending it credibility it had not earned.
check("🚨 modules really do claim ⇪ shortcuts — if this is zero the boot "
      .. "line's count is measuring the wrong thing again", (function()
    local n = 0
    for _ in pairs(HYPER_CLAIMS) do n = n + 1 end
    return n >= 20, n
end)())
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or "" ; if f then f:close() end
    local code = init:gsub("\n%s*%-%-[^\n]*", "\n")
    check("...and the boot line counts what was actually BOUND, not just "
          .. "the migration map",
          code:find("hyperShortcutCount%s*=%s*_G%.hyperBoundCount") ~= nil)
    check("...minus the forwarded chords, which are not shortcuts — every "
          .. "unclaimed letter re-sends itself so hyper works with Raycast",
          code:find("hyperBoundCount%s*%-%s*forwarded") ~= nil)
end

out("   -- namespace collisions --\n")
check("NO SERVICE NAME IS PUBLISHED TWICE", (function()
    local dupes = {}
    for n, c in pairs(SERVICES) do if c > 1 then dupes[#dupes + 1] = n end end
    if #dupes > 0 then return false, table.concat(dupes, ", ") end
    return true
end)())
check("mouse_grid's services are published", SERVICES["mouseGrid.show"] == 1)

-- 🚨 THE NUMBER-PAD TYPO TEST, AND WHY IT CAN ONLY LIVE HERE.
-- Since 6.49.0 the ⇪⇧ + pad layer binds by SERVICE NAME, resolved at
-- keypress time. A typo — "focus.tggle" — binds perfectly, does nothing
-- when pressed, and prints "no provider" to a Console nobody is reading.
-- Every other suite loads one module at a time against stubs, so the
-- registry is empty there and the check would pass vacuously. This is the
-- only suite where all 24 modules are loaded together and the names can
-- actually be resolved.
-- 6.66.0 — the tool layer was CLEARED on request, so this check now runs
-- over the shifted layer's zone names plus whatever gets added back. It is
-- kept, and kept loud, precisely because the layer is now empty and
-- inviting: the next thing added there is exactly what this catches.
check("🚨 EVERY ⇪ pad KEY NAMES A SERVICE SOME MODULE REALLY PUBLISHES — "
      .. "a typo binds a key that silently does nothing", (function()
    local np = _G.numpadLayer
    if not np then return false, "numpad_layer did not load" end
    if not np.actions then return false, "no tool layer defined" end
    local missing, n = {}, 0
    for key, name in pairs(np.actions) do
        n = n + 1
        if type(name) == "string" and not SERVICES[name] then
            missing[#missing + 1] = key .. "→" .. name
        end
    end
    -- 🚨 AN EMPTY LAYER PASSES, AND THE COMMENT MATTERS MORE THAN THE
    -- CODE. Until 6.66.0 this returned FAILURE on an empty table, on the
    -- reasoning that a vacuous pass hides a broken fixture. That was right
    -- while the layer was supposed to be full; it is wrong now that it is
    -- deliberately empty, and leaving it would have meant a permanently
    -- red suite teaching everyone to ignore it. The check that actually
    -- protects us is unchanged: whatever IS there must resolve.
    if #missing > 0 then return false, table.concat(missing, ", ") end
    return true
end)())
check("...and the shifted layer is still fully populated, so an empty "
      .. "TOOL layer cannot be mistaken for a fixture that failed to load",
      (function()
    local np = _G.numpadLayer
    local n = 0
    for _ in pairs((np or {}).shiftActions or {}) do n = n + 1 end
    return n >= 17, n
end)())
check("...and no pad key means the same thing on both layers, which "
      .. "would waste a slot", (function()
    local np = _G.numpadLayer
    for key in pairs((np or {}).shiftActions or {}) do
        if (np.actions or {})[key] and np.actions[key] == np.shiftActions[key] then
            return false, key .. " is identical on both layers"
        end
    end
    return true
end)())
check("its globals do not stomp anything else's", _G.mouseGrid ~= nil
      and _G.mouseGridReport ~= nil)

out("   -- the cheat sheet --\n")
check("every loaded module registered a cheat sheet group",
      #_G.moduleCheatsheets >= 1, #_G.moduleCheatsheets)
check("NO TWO MODULES SHARE A CHEAT-SHEET ORDER — a tie makes the sheet's "
      .. "running order depend on table iteration, which is not stable",
      (function()
    local seen, dupes = {}, {}
    for _, cs in ipairs(_G.moduleCheatsheets) do
        local o = cs.order
        if seen[o] then dupes[#dupes + 1] = tostring(o) .. " (" .. tostring(seen[o])
                        .. " vs " .. tostring(cs.title) .. ")" end
        seen[o] = cs.title
    end
    if #dupes > 0 then return false, table.concat(dupes, "; ") end
    return true
end)())
check("the Mouse Grid group is on the sheet", (function()
    for _, cs in ipairs(_G.moduleCheatsheets) do
        if tostring(cs.title):find("MOUSE GRID", 1, true) then return true end
    end
end)())
check("every cheat sheet entry is a {key, description} pair — a malformed "
      .. "row would break rendering for EVERY group, not just its own",
      (function()
    for _, cs in ipairs(_G.moduleCheatsheets) do
        for _, e in ipairs(cs.entries or {}) do
            if type(e) ~= "table" or type(e[1]) ~= "string"
               or type(e[2]) ~= "string" then
                return false, tostring(cs.title)
            end
        end
    end
    return true
end)())

out("   -- boot cost --\n")
check("no module failed with a timing that suggests a boot-path stall",
      (function()
    for _, st in ipairs(_G.moduleStatus) do
        if (st.ms or 0) > 500 then return false, st.name .. " " .. st.ms .. "ms" end
    end
    return true
end)())
check("mouse_grid draws NOTHING at load — the grid must cost nothing until "
      .. "you press ⇪X", (function()
    for _, l in ipairs(printed) do
        if l:find("MODULE FAILED", 1, true) and l:find("mouse_grid", 1, true) then
            return false
        end
    end
    return _G.mouseGrid ~= nil and _G.mouseGrid.state == nil
           and _G.mouseGrid.cache == nil
end)())

-- =====================================================================
out("\n=== 3. init.lua must stay an ORCHESTRATOR, not a container ===\n")
-- =====================================================================
-- 6.44.11 cut this file from 6,012 lines to 3,376 by moving history and
-- three big blocks out. Within a few releases it was back to twelve
-- inline changelog entries and 3,735 lines — bloat creeps back roughly
-- 50 lines a release, and nobody notices because each release only adds
-- a little. These checks make the drift fail the build instead.
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or "" ; if f then f:close() end
    local f2 = io.open(HS .. "/CHANGELOG.md", "r")
    local chg = f2 and f2:read("*a") or "" ; if f2 then f2:close() end

    -- 🚨 6.66.2 — THE DOCK ICON IS LOAD-BEARING, which is not obvious and
    -- is exactly why it is pinned here. Every hs.chooser in this config —
    -- clipboard history, OCR search, the Tool Picker, Universal Actions,
    -- the menu bar picker, every Asana list — CANNOT open over a
    -- full-screen app while Hammerspoon has a Dock icon. That is AppKit's
    -- rule, documented in the hs.chooser docs, and there is no Lua-side
    -- workaround: a chooser is a native NSPanel with no collection
    -- behaviour API. Deleting this line silently costs you every picker in
    -- full screen, and the symptom ("some windows come forward, some do
    -- not") points nowhere near the cause.
    -- ⚠️ COMMENTS STRIPPED FIRST. The block above this call in init.lua
    -- explains the fix and therefore CONTAINS the string being searched
    -- for — so a grep over raw text passes even when the call itself is
    -- deleted. That exact mistake was made twice in one day: once here,
    -- and once in hs-lint's canvas-not-fullscreen rule, where a comment
    -- mentioning fullScreenAuxiliary silenced the check on the very file
    -- documenting it. A search for code has to look at code.
    local code = init:gsub("\n%s*%-%-[^\n]*", "\n")
    check("🚨 init.lua HIDES THE DOCK ICON — without it no hs.chooser can "
          .. "open over a full-screen app, and nothing in Lua can fix that "
          .. "afterwards", code:find("hs%.dockicon%.hide") ~= nil)
    check("...and it is behind a named switch rather than a bare call, so "
          .. "the Dock icon can be put back in one edit",
          code:find("hideDockIcon") ~= nil)
    check("...and the failure path SAYS SO rather than leaving you to "
          .. "wonder why ⇪V will not open over a full-screen app",
          init:find("not appear over full%-screen apps") ~= nil)

    local inline = {}
    for v in init:gmatch("\n%-%- NEW IN ([%d%.]+)") do inline[#inline + 1] = v end
    check("init.lua keeps at most FIVE changelog entries inline, which is "
          .. "the rule the file states for itself", #inline <= 5, #inline)

    -- 🚨 THE IMPORTANT ONE. Trimming the header is only safe while
    -- CHANGELOG.md is the complete record. When this cleanup was done,
    -- 6.44.11, 6.44.12 and 6.44.13 existed ONLY in init.lua — trimming
    -- blind would have destroyed three versions of history. This makes
    -- that impossible to do by accident ever again.
    local missing = {}
    for _, v in ipairs(inline) do
        if not chg:find("\nNEW IN " .. v:gsub("%.", "%%."), 1, false) then
            missing[#missing + 1] = v
        end
    end
    check("🚨 every entry still inline is ALSO in CHANGELOG.md, so trimming "
          .. "the header can never lose history", #missing == 0,
          table.concat(missing, ", "))

    check("CHANGELOG.md is the complete record and keeps growing",
          select(2, chg:gsub("\nNEW IN ", "")) >= 110,
          select(2, chg:gsub("\nNEW IN ", "")))

    local total = select(2, init:gsub("\n", "")) + 1
    local comments = select(2, init:gsub("\n%s*%-%-", ""))
    check("init.lua stays under 4,000 lines — it is the orchestrator, and "
          .. "every feature belongs in modules/ or core/", total < 4000, total)
    check("...and under 60% comment, which is where the header bloat shows "
          .. "up before the line count does",
          comments / total < 0.60, string.format("%.0f%%", comments / total * 100))

    -- The actual architectural claim, tested rather than asserted: a new
    -- tool costs init.lua its NAME in the profiles and nothing else.
    for _, m in ipairs({ "mouse_grid", "url_cleaner", "health_monitor" }) do
        local fh = io.open(HS .. "/modules/" .. m .. ".lua", "r")
        check(m .. " lives in its own file, not in init.lua", fh ~= nil)
        if fh then
            local body = fh:read("*a") ; fh:close()
            check("..." .. m .. " follows the module contract",
                  body:find("function M.setup", 1, true) ~= nil
                  and body:find("return M", 1, true) ~= nil)
        end
        -- 6.66.3 — THE COUNT DROPPED FROM THREE TO ONE, and that drop IS
        -- the fix: there used to be three hand-typed profile lists and
        -- there is now one BASE. health_monitor is named twice because
        -- SAFE mode lists it separately.
        --
        -- What this check has always really been about is unchanged:
        -- init.lua must never REFER to a module as code, only ever NAME it
        -- in a list. A count above the number of lists is the tell.
        local live = init:gsub("%-%-[^\n]*", "")
        local mentions = select(2, live:gsub('"' .. m .. '"', ""))
        local expected = (m == "health_monitor") and 2 or 1
        check("...init.lua NAMES " .. m .. " in a list (" .. expected
              .. "x) and never refers to it as code", mentions == expected,
              mentions)
    end
end

-- =====================================================================
out("\n=== 4. 6.68.0 — WHO IS IN FRONT, AND WHO GETS ESCAPE ===\n")
-- =====================================================================
-- Two panels can be on screen at once and two can want Esc at the same
-- moment. Both used to be settled by accident — by whichever canvas was
-- shown last, and by whichever hotkey was enabled last. Neither is a
-- policy, and "sometimes it works" is what an undefined policy feels
-- like from the keyboard.
--
-- 🚨 THE REAL BLOCK IS EXTRACTED FROM init.lua AND EXECUTED. Retyping it
-- here would be a second copy of my own idea of the rule, and a test that
-- checks the code against another copy of the same assumption confirms
-- the assumption. That is exactly how four modules never loaded (§2).
do
    local f = io.open(HS .. "/core/coexist.lua", "r")
    local init = f and f:read("*a") or "" ; if f then f:close() end
    -- 🚨 TWO SEPARATE ANCHORS, ONE PER BLOCK. A single span from
    -- _G.panelLevels to routeEscape's end LOOKED right and quietly grew to
    -- swallow whatever was inserted between them — which in 6.69.0 was the
    -- injection guard, complete with an hs.timer.doEvery the sandbox does
    -- not stub. An extraction that silently widens is an extraction that
    -- eventually tests something else.
    local levelsBlock = init:match(
        "(_G%.panelLevels = {.-\n    return base %+ %(_G%.panelLevels%[name%] or 0%)\nend)")
    local escBlock = init:match("(_G%.escapeClaims = {}.-\n    return best%.name\nend)")
    check("the panel-stacking block was found in core/coexist.lua", levelsBlock ~= nil)
    check("the escape-router block was found in core/coexist.lua", escBlock ~= nil)
    local block = levelsBlock and escBlock and (levelsBlock .. "\n" .. escBlock)

    if block then
        local sandbox = {
            hs = { canvas = { windowLevels = { overlay = 102 } },
                   timer = { secondsSinceEpoch = function() return 1000 end,
                             doEvery = function() return { stop = function() end } end } },
            print = function() end,
            table = table, type = type, ipairs = ipairs, pairs = pairs,
            pcall = pcall, tostring = tostring, math = math, string = string,
        }
        sandbox._G = sandbox
        local chunk, err = load(block, "panels", "t", sandbox)
        check("...and it loads and runs on its own", chunk ~= nil, err)
        if chunk then
            chunk()

            out("   -- the stacking order --\n")
            check("the cheat sheet is the reference level",
                  sandbox.panelLevel("cheatsheet") == 102,
                  sandbox.panelLevel("cheatsheet"))
            check("🪟 THE POMODORO IS STRICTLY ABOVE THE CHEAT SHEET. Both "
               .. "were `overlay`, and two windows at one level stack by "
               .. "whichever was shown last — so the timer was in front or "
               .. "behind depending on the order you pressed the keys",
                  sandbox.panelLevel("pomodoro") > sandbox.panelLevel("cheatsheet"),
                  sandbox.panelLevel("pomodoro") .. " vs "
                  .. sandbox.panelLevel("cheatsheet"))
            check("...and the ⌥Tab HUD sits between them",
                  sandbox.panelLevel("switcher") > sandbox.panelLevel("cheatsheet")
                  and sandbox.panelLevel("switcher") < sandbox.panelLevel("pomodoro"),
                  sandbox.panelLevel("switcher"))
            -- pcall'd: a regression here THROWS (arithmetic on nil) rather
            -- than returning a wrong number, and an unguarded throw aborts
            -- the run and blames whatever line came next. That lesson has
            -- cost this repo three debugging sessions.
            check("an unknown panel falls back to the reference level rather "
               .. "than to nil, which hs.canvas:level() would reject",
                  select(2, pcall(sandbox.panelLevel, "nothing at all")) == 102)
            check("the levels are OFFSETS, so they follow macOS if it "
               .. "renumbers the named constants", (function()
                sandbox.hs.canvas.windowLevels.overlay = 500
                local ok = sandbox.panelLevel("cheatsheet") == 500
                           and sandbox.panelLevel("pomodoro") == 503
                sandbox.hs.canvas.windowLevels.overlay = 102
                return ok
            end)())

            out("   -- who gets Esc --\n")
            local fired = {}
            local sheetOpen, timerAsking = true, false
            sandbox.claimEscape("cheatsheet", 10,
                function() return sheetOpen end,
                function() table.insert(fired, "cheatsheet") end)
            sandbox.claimEscape("pomodoro", 100,
                function() return timerAsking end,
                function() table.insert(fired, "pomodoro") end)

            check("with the timer idle, the sheet keeps its own Esc",
                  sandbox.routeEscape("cheatsheet") == nil)
            check("...and nothing else ran", #fired == 0, fired[1])

            timerAsking = true
            check("⎋ WHILE THE TIMER IS ASKING, IT TAKES Esc FROM THE SHEET. "
               .. "hs.hotkey gives a key to whichever binding was enabled "
               .. "most recently, so opening the sheet mid-flash silently "
               .. "stole Esc and you had to close the sheet first",
                  sandbox.routeEscape("cheatsheet") == "pomodoro")
            check("...and the timer's handler is what ran", fired[1] == "pomodoro",
                  fired[1])

            fired = {}
            check("a claimant never routes to ITSELF (that would recurse)",
                  sandbox.routeEscape("pomodoro") == nil)
            check("...and lower priorities are never promoted", #fired == 0)

            timerAsking = false
            fired = {}
            check("the moment the timer stops asking, Esc goes back to the "
               .. "sheet — this takes nothing away, it only breaks a tie",
                  sandbox.routeEscape("cheatsheet") == nil and #fired == 0)

            out("   -- and it fails safe --\n")
            timerAsking = true
            sandbox.claimEscape("pomodoro", 100,
                function() return true end,
                function() error("handler exploded") end)
            check("🚨 A CLAIMANT THAT THROWS DOES NOT SWALLOW THE KEYSTROKE. "
               .. "An Esc that does nothing at all is the worst of the three "
               .. "outcomes, so the caller still gets its own",
                  sandbox.routeEscape("cheatsheet") == nil)
            sandbox.claimEscape("pomodoro", 100,
                function() error("cannot say") end,
                function() table.insert(fired, "pomodoro") end)
            check("...and one that cannot even say whether it wants Esc is "
               .. "skipped rather than taken at its word",
                  sandbox.routeEscape("cheatsheet") == nil)
            check("re-registering a name REPLACES it instead of stacking a "
               .. "second claimant nothing can remove",
                  #sandbox.escapeClaims == 2, #sandbox.escapeClaims)
            -- BOTH callbacks are checked, not just the first. A registration
            -- with a live active() and a junk handle() would pass an
            -- active-only check and then throw the first time Esc was
            -- pressed — at which point the claim has already won the
            -- arbitration and the real owner has been skipped.
            check("a registration with a junk active() is refused, not stored",
                  sandbox.claimEscape("bad", 1, "not a function", function() end) == false
                  and #sandbox.escapeClaims == 2)
            check("...and so is one with a junk handle()",
                  sandbox.claimEscape("bad", 1, function() return true end, 42) == false
                  and #sandbox.escapeClaims == 2, #sandbox.escapeClaims)
        end
    end

    out("   -- 6.69.0: the shared injection guard --\n")
    -- Two taps now watch every keystroke AND type back into the document.
    -- Each had its own "am I injecting" flag, which is half of what is
    -- needed: a flag only tells the module that wrote it to stand down.
    local gblock = init:match("(_G%.injectDepth = 0.-\n    return ok, err\nend)")
    check("the injection guard was found in core/coexist.lua", gblock ~= nil)
    if gblock then
        local sb = {
            hs = { timer = { secondsSinceEpoch = function() return 1000 end } },
            pcall = pcall, math = math, type = type, print = function() end,
        }
        sb._G = sb
        local ch = load(gblock, "guard", "t", sb)
        check("...and it runs on its own", ch ~= nil)
        if ch then
            ch()
            check("nothing is injecting to start with", sb.typingInjection() == false)
            local sawInside = false
            sb.withInjection(function() sawInside = sb.typingInjection() end)
            check("a tap standing down can SEE that it should", sawInside == true)
            check("...and the guard drops again afterwards",
                  sb.typingInjection() == false)

            local depths = {}
            sb.withInjection(function()
                depths[1] = sb.injectDepth
                sb.withInjection(function() depths[2] = sb.injectDepth end)
                depths[3] = sb.injectDepth
            end)
            check("🚨 IT IS A COUNTER, NOT A BOOLEAN. An expander snippet "
               .. "ending in a word autocorrect wants to fix nests one "
               .. "injection inside another; a boolean would clear on the "
               .. "way out of the inner one and leave the outer unguarded",
                  depths[1] == 1 and depths[2] == 2 and depths[3] == 1,
                  table.concat(depths, "/"))
            check("...and unwinds all the way to zero",
                  sb.typingInjection() == false, sb.injectDepth)

            -- pcall'd: a regression here THROWS PAST withInjection, which
            -- aborts the whole run and blames the next line. Guarding the
            -- call is what turns that into one failing check.
            local outerOK, ok = pcall(sb.withInjection,
                                      function() error("the app refused") end)
            check("a throw inside does not escape withInjection", outerOK == true)
            check("...and is reported to the caller", ok == false)
            check("🚨 AND STILL RELEASES THE GUARD. A counter stuck above "
               .. "zero switches BOTH typing features off for the rest of "
               .. "the session — the quietest possible failure",
                  sb.typingInjection() == false, sb.injectDepth)
        end
    end

    out("   -- and the clipboard watcher can be told to look away --\n")
    do
        -- 🚨 THE TWO HALVES LIVE IN DIFFERENT FILES, so both are read.
        -- The borrower's switch is in core/coexist.lua; the watcher that
        -- has to honour it stayed in init.lua, shared with image OCR.
        -- Checking only the half that declares it is how you end up with
        -- a suppression nobody reads.
        local co = init:gsub("%-%-[^\n]*", "")
        local fi = io.open(HS .. "/init.lua", "r")
        local live = (fi and fi:read("*a") or ""):gsub("%-%-[^\n]*", "")
        if fi then fi:close() end
        check("_G.pasteboardSuppress exists for a borrower to call",
              co:find("function _G%.pasteboardSuppress%(") ~= nil)
        check("🚨 AND THE SHARED WATCHER ACTUALLY HONOURS IT. Publishing a "
           .. "suppression nobody reads is worse than not having one — it "
           .. "reads like the problem is solved",
              live:find("pasteboardSuppressUntil") ~= nil
              and live:find("hs%.timer%.secondsSinceEpoch%(%) < %(_G%.pasteboardSuppressUntil")
                  ~= nil)
        check("...and the changeCount is still advanced first, so the NEXT "
           .. "real copy is seen normally", (function()
            local w = live:match("_G%.clipboardTimer = hs%.timer%.doEvery%b()")
                      or live:match("_G%.clipboardTimer.-\n    end\n%)")
            if not w then return false end
            local iAdv = w:find("lastChangeCount = currentChangeCount", 1, true)
            local iSup = w:find("pasteboardSuppressUntil", 1, true)
            return iAdv and iSup and iAdv < iSup
        end)())
    end

    out("   -- and the panels really use it --\n")
    local function code(p)
        local fh = io.open(HS .. "/" .. p, "r")
        local s = fh and fh:read("*a") or "" ; if fh then fh:close() end
        -- 🚨 COMMENTS STRIPPED. An explanatory comment naming the helper
        -- silenced this exact class of check twice (6.66.2, 6.66.3).
        return s:gsub("%-%-[^\n]*", "")
    end
    check("the pomodoro asks for its level by name",
          code("modules/pomodoro.lua"):find('panelLevel("pomodoro")', 1, true) ~= nil)
    check("the cheat sheet asks for its level by name",
          code("core/cheatsheet.lua"):find('panelLevel("cheatsheet")', 1, true) ~= nil)
    check("the pomodoro claims Esc while it is asking",
          code("modules/pomodoro.lua"):find('claimEscape("pomodoro"', 1, true) ~= nil)
    check("🚨 AND THE CHEAT SHEET ASKS THE ROUTER BEFORE CLOSING ITSELF — "
       .. "it holds the bare Esc hotkey, so if it does not ask, no policy "
       .. "in init.lua can ever apply",
          code("core/cheatsheet.lua"):find('routeEscape("cheatsheet")', 1, true) ~= nil)
end

realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
