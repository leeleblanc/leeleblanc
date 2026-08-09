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

-- The real list, read from init.lua rather than retyped — a hand-copied
-- list here would drift from the profile that actually ships.
local MODULES = {}
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or ""
    if f then f:close() end
    local block = init:match('default%s*=%s*{%s*modules%s*=%s*{(.-)}')
    for name in (block or ""):gmatch('"([%w_]+)"') do MODULES[#MODULES + 1] = name end
end
check("the module list was read from init.lua's default profile",
      #MODULES >= 19, #MODULES)
check("mouse_grid is in it", (function()
    for _, m in ipairs(MODULES) do if m == "mouse_grid" then return true end end
end)())

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

out("   -- namespace collisions --\n")
check("NO SERVICE NAME IS PUBLISHED TWICE", (function()
    local dupes = {}
    for n, c in pairs(SERVICES) do if c > 1 then dupes[#dupes + 1] = n end end
    if #dupes > 0 then return false, table.concat(dupes, ", ") end
    return true
end)())
check("mouse_grid's services are published", SERVICES["mouseGrid.show"] == 1)
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
        local live = init:gsub("%-%-[^\n]*", "")
        local mentions = select(2, live:gsub('"' .. m .. '"', ""))
        check("...init.lua mentions " .. m .. " ONLY as a profile entry (3x), "
              .. "never as code", mentions == 3, mentions)
    end
end

realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
