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
-- 🔌 6.114.0 — the stub records an OWNER per service, exactly as the real
-- registry in init.lua §0.1 does, reading the same _G.moduleLoading the
-- §1.12 loader sets around each setup(). Without it the run-map ownership
-- check below would have nothing to compare against, and a stub that
-- quietly answers nil would make that check pass on air.
SERVICE_OWNER = {}
_G.service = { provide = function(n)
                   SERVICES[n] = (SERVICES[n] or 0) + 1
                   SERVICE_OWNER[n] = _G.moduleLoading or "init.lua"
               end,
               owner = SERVICE_OWNER,
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

-- 🚨 EVERY PICKER IS PLACED BY THE ONE PLACEMENT FUNCTION (6.127.0).
--
-- LL: "The screenshot is a picker window I can't grab and move. Why?"
--
-- Because fourteen modules built an hs.chooser and opened it with a bare
-- chooser:show(). That is not merely "unplaced" — _G.lastPopupPlacement
-- is a SINGLE global record, and window_move computes a picker's grab box
-- from it, because macOS gives hs.chooser no frame getter to ask. A
-- picker that records nothing leaves the LAST picker's coordinates
-- standing, the ⌘-click on the real one falls outside that box, and the
-- drag is DECLINED. Those pickers could not be moved at all, and the
-- decline is silent by design — a mouse tap cannot make a noise about a
-- click that belongs to somebody else's app.
--
-- It also cost them the rest of the position system: the ⇪⇧-arrow nudge,
-- the remembered offset, ⌃⌥⌘R, and placement on the screen you are
-- actually looking at.
--
-- So: a module that makes a chooser must name showPopup. This is a source
-- scan and not a runtime check on purpose — the failure is a call that is
-- NOT made, and there is no way to observe an absence at runtime.
do
    local missing, scanned, withChooser = {}, 0, 0
    local p = io.popen('ls "' .. HS .. '"/modules/*.lua "' .. HS
                       .. '"/core/*.lua 2>/dev/null')
    if p then
        for path in p:lines() do
            local f = io.open(path, "r")
            if f then
                local src = f:read("*a") or ""
                f:close()
                scanned = scanned + 1
                -- 🚨 COMMENTS STRIPPED, the same lesson as the module-mention
                -- check above: the comment explaining WHY showPopup is used
                -- satisfies a naive substring search, so reverting the call
                -- and leaving the comment behind would pass. Proved by a
                -- break test that did exactly that.
                local live = src:gsub("%-%-[^\n]*", "")
                -- 🚨 AND IT COUNTS PICKERS, NOT FILES — the second lesson
                -- from the same break test. net_tools builds THREE choosers;
                -- a file-level "does showPopup appear anywhere" passes while
                -- two of the three are still opening unplaced. One placement
                -- call per picker is the actual contract.
                -- The [(,] anchor is what separates hs.chooser.new( and
                -- pcall(hs.chooser.new, …) from the words "hs.chooser.new"
                -- inside a warning message.
                local made = select(2, live:gsub("hs%.chooser%.new[%(,]", ""))
                if made > 0 then
                    withChooser = withChooser + made
                    local placed = select(2, live:gsub("showPopup%s*%(", ""))
                    if placed < made then
                        missing[#missing + 1] = (path:match("([%w_]+%.lua)$")
                            or path) .. (" (%d picker(s), %d placed)")
                            :format(made, placed)
                    end
                end
            end
        end
        p:close()
    end
    check("🚨 EVERY PICKER IN THE CONFIG IS PLACED THROUGH showPopup — a "
          .. "bare chooser:show() leaves another picker's coordinates on "
          .. "the record, and window_move declines the ⌘-drag against them",
          #missing == 0, table.concat(missing, ", "))
    check("...and the scan actually read the tree, so a broken glob "
          .. "cannot make it pass by finding nothing",
          scanned >= 40 and withChooser >= 30,
          scanned .. " files, " .. withChooser .. " pickers")
end

-- 🚨 AND THE REAL showPopup IS EXTRACTED FROM init.lua AND EXECUTED.
-- Routing every picker through showPopup only helps if showPopup writes
-- down WHICH picker it placed. That field is the whole repair: without it
-- the record is still just "some picker opened here", which is the lie
-- window_move was believing. Retyping the function here would test the
-- copy, so the shipped text is what runs.
do
    local fh = io.open(HS .. "/init.lua", "r")
    local init = fh and fh:read("*a") or ""
    if fh then fh:close() end

    local block = init:match("\n(local function showPopup%(.-\nend\n)")
    check("the showPopup block was found in init.lua", block ~= nil)

    if block then
        local SHOWN = {}
        local env = {
            resolveBaseScreen = function()
                return { frame = function()
                    return { x = 0, y = 0, w = 1000, h = 800 }
                end }
            end,
            chooserTopLeft = function() return { x = 300, y = 200 } end,
            _G = _G, pcall = pcall, type = type,
        }
        local fn = load(block .. "\nreturn showPopup", "showPopup", "t", env)
        check("...and it loads on its own", fn ~= nil)
        if fn then
            local ok, showPopup = pcall(fn)
            check("...and yields the function", ok and type(showPopup) == "function")
            if ok and type(showPopup) == "function" then
                local picker = { show = function(_, pt) SHOWN[#SHOWN + 1] = pt end }
                _G.lastPopupPlacement = nil
                showPopup(picker)
                check("🚨 THE PLACEMENT RECORD NAMES THE PICKER IT BELONGS "
                      .. "TO — window_move cannot tell a live box from a "
                      .. "departed picker's without it, and declines the "
                      .. "⌘-drag either way",
                      _G.lastPopupPlacement ~= nil
                      and _G.lastPopupPlacement.chooser == picker)
                check("...and still records the point, as it always did",
                      _G.lastPopupPlacement
                      and _G.lastPopupPlacement.point.x == 300)
                check("...and still shows the picker AT that point",
                      #SHOWN == 1 and SHOWN[1].x == 300 and SHOWN[1].y == 200)

                -- The panels that place themselves deliberately (the app
                -- monitor alert) must ALSO land on the record — an
                -- unrecorded picker is the stale-box bug wearing a hat.
                local own = { show = function(_, pt) SHOWN[#SHOWN + 1] = pt end }
                showPopup(own, { x = 42, y = 84 })
                check("🚨 a caller-supplied point is honoured AND recorded",
                      _G.lastPopupPlacement.chooser == own
                      and _G.lastPopupPlacement.point.x == 42
                      and SHOWN[#SHOWN].x == 42,
                      _G.lastPopupPlacement.point.x)
                _G.lastPopupPlacement = nil

                -- 🚨 6.160.1 — NEVER OFF THE SCREEN. LL's ⇪Y opened at
                -- x=2733 on a 2560-wide screen (a runaway nudge offset);
                -- macOS kept the picker on screen, the record kept the
                -- lie, and the preview pane drew itself over the list.
                -- The env's screen is 1000x800; the picker is 40% wide.
                local far = { show = function(_, pt) SHOWN[#SHOWN + 1] = pt end }
                _G.popupOffset = { x = 2067, y = 0 }
                env.chooserTopLeft = function() return { x = 2732, y = 584 } end
                showPopup(far)
                local rec = _G.lastPopupPlacement
                check("🚨 an automatic placement past the right edge is CLAMPED "
                      .. "onto the screen — and the record says where it "
                      .. "really is", rec and rec.point.x == 600
                      and SHOWN[#SHOWN].x == 600, rec and rec.point.x)
                check("...the bottom edge too (56 + 10 rows × 44 = 496 tall)",
                      rec and rec.point.y == 304 and SHOWN[#SHOWN].y == 304,
                      rec and rec.point.y)
                check("...and the nudge offset is folded back so it stops lying",
                      _G.popupOffset.x == 2067 - 2132 and _G.popupOffset.y == -280,
                      _G.popupOffset.x .. "," .. _G.popupOffset.y)
                check("...counted, for the report", (_G.popupClamped or 0) >= 1)
                -- a picker that says how wide it is gets clamped by THAT width
                local wide = { show = function(_, pt) SHOWN[#SHOWN + 1] = pt end,
                               width = function() return 48 end,
                               rows = function() return 12 end }
                _G.popupOffset = { x = 0, y = 0 }
                env.chooserTopLeft = function() return { x = 900, y = 100 } end
                showPopup(wide)
                check("...using the picker's OWN width (48% of 1000 → x = 520)",
                      _G.lastPopupPlacement.point.x == 520, _G.lastPopupPlacement.point.x)
                check("...and that fold-back is exactly the clamp (520 - 900)",
                      _G.popupOffset.x == -380, _G.popupOffset.x)
                _G.popupOffset = { x = 0, y = 0 }
                -- a caller's own point is clamped but never rewrites the offset
                showPopup(own, { x = 990, y = 790 })
                check("🚨 a caller-supplied point off the screen is clamped too, "
                      .. "and the offset is left alone",
                      _G.lastPopupPlacement.point.x == 600
                      and _G.popupOffset.x == 0 and _G.popupOffset.y == 0,
                      _G.lastPopupPlacement.point.x)
                env.chooserTopLeft = function() return { x = 300, y = 200 } end
                showPopup(picker)
                check("...and an on-screen point is untouched", SHOWN[#SHOWN].x == 300
                      and SHOWN[#SHOWN].y == 200 and _G.popupOffset.x == 0)
                _G.lastPopupPlacement = nil
                _G.popupOffset = nil
            end
        end
    end
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
-- 🔗 6.114.0 — THE CROSS-MODULE LINK BEHIND ⇪↓. numpad_layer calls
-- windows.rememberFrame on every placement so the pad and laptop layers
-- write into the SAME "put it back" memory ⇪↓ reads. That call is guarded
-- by service.has(), which is correct and means a vanished provider fails
-- SILENTLY — the placement still works, the restore just quietly stops
-- knowing about it. Exactly the shape of the bug this replaced, so it is
-- asserted here rather than left to be noticed.
check("🔗 windows.rememberFrame is published — the shared prior-frame "
      .. "memory the numpad and laptop layers write through to reach ⇪↓",
      SERVICES["windows.rememberFrame"] == 1,
      tostring(SERVICES["windows.rememberFrame"]))
check("…and numpad_layer really calls it, rather than keeping a private "
      .. "table again", (function()
    local f = io.open(HS .. "/modules/numpad_layer.lua", "r")
    local src = f and f:read("*a")
    if f then f:close() end
    return src ~= nil and src:find("windows.rememberFrame", 1, true) ~= nil
end)())

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
check("...and the CAPTURE ROW is populated, so an empty shifted layer "
      .. "cannot be mistaken for a fixture that failed to load (6.152.0: "
      .. "the shifted layer is deliberately empty — LL cleared the window "
      .. "map: “Those should just say: 'Key available for use'”)",
      (function()
    local np = _G.numpadLayer
    local n = 0
    for _ in pairs((np or {}).actions or {}) do n = n + 1 end
    local nShift = 0
    for _ in pairs((np or {}).shiftActions or {}) do nShift = nShift + 1 end
    return n >= 6 and nShift == 0, n .. "/" .. nShift
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

-- =====================================================================
-- 🔤 6.114.0 — ONE KEY, ONE ROW, ACROSS THE WHOLE SHEET
-- =====================================================================
-- WHY THIS BELONGS HERE AND NOWHERE ELSE. Every duplicate below was
-- invisible to every existing check, and for a structural reason: the
-- sheet is assembled from TWO sources that no single suite could see at
-- once. core/cheatsheet.lua carries hand-written groups; each module
-- carries its own. test_cheatsheet.lua exercises the first against
-- STUBBED module groups. The per-module suites exercise the second and
-- have never heard of the first. So a key documented in both was checked
-- twice and questioned never.
--
-- 🚨 WHAT THAT COST, all four found the day this check was written:
--   · ⇪O and ⇪⇧O appeared twice. OCR moved into modules/ocr_engine.lua
--     in 6.105.0 and brought its group along; the old core rows stayed.
--   · ⇪T and ⇪⇧S appeared twice, same shape — task_form owns them now,
--     the ASANA group still listed them.
--   · ⇪pad1–4, ⇪pad* and ⇪pad- appeared twice AND UNDER TWO SPELLINGS —
--     "⇪ pad1" in the numpad layer, "⇪pad1" in quick_append. That one
--     was not cosmetic: uni.runnable joins a service to a row BY ITS KEY
--     CELL, so a shortcut spelled two ways can only ever be runnable one
--     way, and ⇪space listed the same tool twice with one of them dead.
--
-- The identical complaint was raised by hand from a screenshot in 6.90.1
-- ("⇪V is on the sheet twice"), fixed by hand, and written up in a
-- comment in core/cheatsheet.lua — and then recurred four more times,
-- because a comment asking people to remember is not a sentry.
--
-- ⚠️ ONLY ⇪ CELLS ARE CHECKED. "undo", "how", "if dead", "first" are
-- labels in the key column, not keys, and they repeat across groups on
-- purpose. A key cell is one that starts with ⇪.
out("   -- one key, one row --\n")
local sheetCells = {}      -- normalized key -> { "group: ⇪X — desc", ... }
local cellOwner  = {}      -- normalized key -> the MODULE whose group holds it
local function noteCell(keys, desc, where, owner)
    if type(keys) ~= "string" or keys:sub(1, 3) ~= "⇪" then return end
    local norm = keys:gsub("%s+", ""):lower()
    sheetCells[norm] = sheetCells[norm] or {}
    table.insert(sheetCells[norm], where .. ": " .. keys .. " — " .. tostring(desc))
    cellOwner[norm] = owner        -- nil for the hand-written core groups
end
for _, cs in ipairs(_G.moduleCheatsheets or {}) do
    for _, e in ipairs(cs.entries or {}) do
        noteCell(e[1], e[2], tostring(cs.title):sub(1, 28), cs.source)
    end
end
-- The hand-written core groups are read from SOURCE. They live inside
-- cheatSheet.groups(), which needs the whole core sandbox to call, and
-- the thing being checked is a table literal — reading the literal is
-- reading exactly what ships.
do
    local f = io.open(HS .. "/core/cheatsheet.lua", "r")
    local src = f and f:read("*a")
    if f then f:close() end
    check("core/cheatsheet.lua is readable — this check is worthless if the "
          .. "hand-written groups are silently skipped", src ~= nil)
    for keys, desc in tostring(src or ""):gmatch("{%s*\"(⇪[^\"]*)\"%s*,%s*\"([^\"]*)\"%s*}") do
        noteCell(keys, desc, "core/cheatsheet")
    end
end
check("🚨 NO ⇪ KEY IS DOCUMENTED IN TWO GROUPS — one shortcut on the sheet "
      .. "twice reads as a conflict, and ⇪space lists it twice with only "
      .. "one of the two runnable", (function()
    local dupes = {}
    for norm, list in pairs(sheetCells) do
        if #list > 1 then
            dupes[#dupes + 1] = norm .. " ×" .. #list
                                .. " [" .. table.concat(list, " | ") .. "]"
        end
    end
    if #dupes > 0 then
        table.sort(dupes)   -- pairs() has no order and a report needs one
        return false, table.concat(dupes, "  ;;  ")
    end
    return true
end)())
check("…and the sheet actually had ⇪ rows to check — a scan that matched "
      .. "nothing would pass this silently, which is the failure mode a "
      .. "uniqueness test is most prone to",
      (function()
    local n = 0
    for _ in pairs(sheetCells) do n = n + 1 end
    return n >= 50, n
end)())

-- 🔧 THE OTHER HALF OF THE JOIN. uni.verifyTools already checks that a run
-- map entry names a real service AND that its key matches SOME live row.
-- Neither catches a key that matches the WRONG row — which is how
-- ["⇪⇧R"] = "rename.undo" came to sit on the row labelled "Reset nudge
-- offset", so that ⏎ on a row about popup placement ran a bulk rename undo
-- and moved files on disk. Both halves of that join passed. What nobody
-- checked was that the two halves were about the same thing.
check("🚨 every run-map key matches EXACTLY ONE cheat sheet row — zero "
      .. "means ⏎ hands back a key string, two means it is ambiguous which "
      .. "tool ⏎ runs", (function()
    local uni = _G.unifiedSearch
    if not (uni and uni.runnable) then return false, "unified_search did not load" end
    local bad = {}
    for keys in pairs(uni.runnable) do
        local norm = tostring(keys):gsub("%s+", ""):lower()
        local n = #(sheetCells[norm] or {})
        -- 📊 has no ⇪ and so is not in sheetCells by design; verifyTools
        -- covers it. Anything that starts with ⇪ must be here.
        if tostring(keys):sub(1, 3) == "⇪" and n ~= 1 then
            bad[#bad + 1] = keys .. " matches " .. n .. " rows"
        end
    end
    if #bad > 0 then table.sort(bad) return false, table.concat(bad, ", ") end
    return true
end)())

-- 🚨 AND THE CHECK THAT ACTUALLY CATCHES ⇪⇧R. The one above does not:
-- ⇪⇧R matched exactly one row, and that row was real. What was wrong is
-- WHICH row — the POPUP POSITION group, which is one of the hand-written
-- groups in core/cheatsheet.lua describing keys init.lua itself owns
-- (nudging choosers around, the help block, the Asana keys still living
-- in init.lua). A run map entry is by definition a MODULE'S tool: the
-- service comes from a module's core.provide, and the module carries its
-- own cheat sheet group. So a runnable key whose only row is hand-written
-- is a key and a service that came from two different places.
--
-- ⚠️ THE STRICTER RULE — "the row's module must be the service's module"
-- — WAS TRIED FIRST AND IS WRONG, which the suite said immediately. The
-- numpad layer BINDS ⇪pad1 and publishes nothing; the service it runs
-- belongs to Quick Append. That indirection is the layer's entire design
-- (every value in numpad.actions is another module's service name), so a
-- rule forbidding it would forbid the feature. Row-owner and
-- service-owner differing is normal. Having no row-owner at all is not.
check("🚨 every runnable row belongs to a MODULE's cheat sheet group — a "
      .. "run map entry landing on one of init.lua's hand-written rows "
      .. "means the key and the service came from different features, "
      .. "which is how ⏎ on 'Reset nudge offset' came to run a rename undo "
      .. "and move files on disk", (function()
    local uni = _G.unifiedSearch
    if not (uni and uni.runnable) then return false, "unified_search did not load" end
    local bad = {}
    for keys, svc in pairs(uni.runnable) do
        local norm = tostring(keys):gsub("%s+", ""):lower()
        if tostring(keys):sub(1, 3) == "⇪"
           and #(sheetCells[norm] or {}) == 1 and cellOwner[norm] == nil then
            bad[#bad + 1] = keys .. " → " .. svc
                .. " (its only row is hand-written, not a module's)"
        end
    end
    if #bad > 0 then table.sort(bad) return false, table.concat(bad, "; ") end
    return true
end)())
check("…and the sheet really did tell us which module owns which row — "
      .. "a group list with no `source` would make the check above pass "
      .. "by comparing nil to nil", (function()
    local n = 0
    for _, owner in pairs(cellOwner) do if owner ~= nil then n = n + 1 end end
    return n >= 40, n .. " module-owned key cells"
end)())
-- 🔌 The service registry learned who publishes what in 6.114.0 (§0.1).
-- Nothing depends on it yet beyond diagnostics, so this asserts the field
-- is real rather than an empty table nobody fills — an unused field that
-- silently answers nil is worse than no field, because the next check
-- written against it passes on air.
check("_G.service.owner names the module behind each service", (function()
    local n = 0
    for _ in pairs(SERVICE_OWNER) do n = n + 1 end
    return n >= 20 and SERVICE_OWNER["mouseGrid.show"] == "Mouse Grid"
           and SERVICE_OWNER["rename.undo"] == "Bulk Rename",
           n .. " owners, mouseGrid.show = " .. tostring(SERVICE_OWNER["mouseGrid.show"])
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
    -- 🚨 WIDENED ON PURPOSE IN 6.78.0, and the note above is the reason
    -- to say so out loud: this now runs to the END of the escape section
    -- rather than stopping at routeEscape, because _G.escapePriorities,
    -- _G.escapeOthersActive and the central chooser claim are all part of
    -- the same policy and all shipped after that old anchor. Stopping
    -- where it used to stop would have left the new half untested while
    -- the block it does extract stayed green.
    local escBlock = init:match(
        "(_G%.escapeClaims = {}.-if c then c:hide%(%) end\n    end%))")
    check("the panel-stacking block was found in core/coexist.lua", levelsBlock ~= nil)
    check("the escape-router block was found in core/coexist.lua", escBlock ~= nil)
    local block = levelsBlock and escBlock and (levelsBlock .. "\n" .. escBlock)

    if block then
        local sandbox = {
            hs = { canvas = { windowLevels = { overlay = 102, mainMenu = 24 } },
                   timer = { secondsSinceEpoch = function() return 1000 end,
                             doEvery = function() return { stop = function() end } end } },
            print = function() end,
            table = table, type = type, ipairs = ipairs, pairs = pairs,
            pcall = pcall, tostring = tostring, math = math, string = string,
            select = select, error = error,
        }
        sandbox._G = sandbox
        local chunk, err = load(block, "panels", "t", sandbox)
        check("...and it loads and runs on its own", chunk ~= nil, err)
        if chunk then
            chunk()

            out("   -- the stacking order --\n")
            -- 🪟 6.148.0 — THE LADDER IS BUILT AROUND THE CHOOSER'S RUNG.
            -- hs.chooser's panel sits at mainMenu+3 (HSChooser.m) and has
            -- no level API, so it is the one rung that cannot move.
            -- Seventeen tools are choosers, and the old sheet at overlay
            -- (102) covered every one of them — LL: "make all the tools
            -- pop in front of the cheat sheet".
            local chooserRung = 24 + 3
            check("the ladder is based on mainMenu — the band hs.chooser "
               .. "actually lives in — not on overlay, 75 levels above it",
                  sandbox.panelLevel("cheatsheet") == 24 - 2,
                  sandbox.panelLevel("cheatsheet"))
            check("🪟 THE SHEET IS BELOW THE CHOOSER RUNG (mainMenu+3): "
               .. "every picker now opens in front of it",
                  sandbox.panelLevel("cheatsheet") < chooserRung,
                  sandbox.panelLevel("cheatsheet"))
            check("...and every named rung is above the sheet, except the "
               .. "⇪Q dim — the one deliberate backdrop", (function()
                    for name in pairs(sandbox.panelLevels) do
                        if name ~= "cheatsheet" and name ~= "focus"
                           and sandbox.panelLevel(name)
                               <= sandbox.panelLevel("cheatsheet") then
                            return false, name
                        end
                    end
                    return true
                end)())
            check("...the canvas cards sit BETWEEN the sheet and the "
               .. "chooser — above the backdrop, below the picker in use",
                  (function()
                    for _, name in ipairs({ "calendar", "rollup",
                                            "taskcreator", "macpanel",
                                            "switcher", "pinbadge" }) do
                        local lv = sandbox.panelLevel(name)
                        if lv <= sandbox.panelLevel("cheatsheet")
                           or lv >= chooserRung then
                            return false, name
                        end
                    end
                    return true
                  end)())
            check("🪟 THE POMODORO IS STRICTLY ABOVE THE CHEAT SHEET — the "
               .. "6.68.0 ask survives the rebuild",
                  sandbox.panelLevel("pomodoro") > sandbox.panelLevel("cheatsheet"),
                  sandbox.panelLevel("pomodoro") .. " vs "
                  .. sandbox.panelLevel("cheatsheet"))
            check("...and it tops the whole ladder, chooser included, with "
               .. "the key caster right under it — the two windows that "
               .. "must never hide behind what you press",
                  sandbox.panelLevel("pomodoro") > chooserRung
                  and sandbox.panelLevel("keycaster") > chooserRung
                  and sandbox.panelLevel("pomodoro")
                      > sandbox.panelLevel("keycaster"))
            check("...and the ⌥Tab HUD sits between the sheet and the timer",
                  sandbox.panelLevel("switcher") > sandbox.panelLevel("cheatsheet")
                  and sandbox.panelLevel("switcher") < sandbox.panelLevel("pomodoro"),
                  sandbox.panelLevel("switcher"))
            -- pcall'd: a regression here THROWS (arithmetic on nil) rather
            -- than returning a wrong number, and an unguarded throw aborts
            -- the run and blames whatever line came next. That lesson has
            -- cost this repo three debugging sessions.
            check("an unknown panel falls back to the mainMenu base — above "
               .. "the sheet, below the chooser, and never nil, which "
               .. "hs.canvas:level() would reject",
                  select(2, pcall(sandbox.panelLevel, "nothing at all")) == 24)
            check("the levels are OFFSETS, so they follow macOS if it "
               .. "renumbers the named constants", (function()
                sandbox.hs.canvas.windowLevels.mainMenu = 500
                local ok = sandbox.panelLevel("cheatsheet") == 498
                           and sandbox.panelLevel("pomodoro") == 505
                sandbox.hs.canvas.windowLevels.mainMenu = 24
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

            -- 🚨 6.79.2 — nil IS NOT PRIORITY ZERO. core/hyper_key.lua's
            -- Escape rescue calls routeEscape with no caller, and with
            -- `mine = 0` the cheat sheet — which sits at zero on purpose,
            -- so it closes last — was ineligible for its own Esc. On a Mac
            -- running the event-tap dispatcher, where the sheet's Carbon
            -- hotkey is dead, that left it IMPOSSIBLE TO CLOSE with the
            -- key the panel itself tells you to press.
            --
            -- The claim list is SAVED AND PUT BACK: the checks after this
            -- one are built on the set registered above, and a scenario
            -- that quietly rewrites shared state passes while making its
            -- neighbours fail for reasons that have nothing to do with
            -- them.
            do
              local saved = sandbox.escapeClaims
              sandbox.escapeClaims = {}
              local closed = 0
              sandbox.claimEscape("cheatsheet", nil,
                  function() return true end,
                  function() closed = closed + 1 end)
              check("🚨 a caller-less Esc reaches the FLOOR claimant when it "
                 .. "is the only one up, or the cheat sheet cannot be closed "
                 .. "at all on a Mac using the event-tap dispatcher",
                (function()
                  local who = sandbox.routeEscape()
                  return who == "cheatsheet" and closed == 1, tostring(who)
                end)())

              local took
              sandbox.claimEscape("pomodoro", nil,
                  function() return true end,
                  function() took = "pomodoro" end)
              check("...and a higher claimant still outranks it when both "
                 .. "are up, so \"closes last\" survives the same path",
                (function()
                  local who = sandbox.routeEscape()
                  return who == "pomodoro" and took == "pomodoro", tostring(who)
                end)())
              check("...while a NAMED caller only ever yields UPWARD, so "
                 .. "the top panel asking finds nobody above it",
                    sandbox.routeEscape("pomodoro") == nil)
              sandbox.escapeClaims = saved
            end
            -- 3, not 2: core/coexist.lua registers the central chooser
            -- claim itself, which is the point of it being central.
            check("core/coexist.lua registers the chooser claim ITSELF, so "
               .. "fifteen choosers are covered without fifteen edits",
              (function()
                for _, c in ipairs(sandbox.escapeClaims) do
                  if c.name == "chooser" then return true end
                end
                return false
              end)())
            check("re-registering a name REPLACES it instead of stacking a "
               .. "second claimant nothing can remove",
                  #sandbox.escapeClaims == 3, #sandbox.escapeClaims)
            -- BOTH callbacks are checked, not just the first. A registration
            -- with a live active() and a junk handle() would pass an
            -- active-only check and then throw the first time Esc was
            -- pressed — at which point the claim has already won the
            -- arbitration and the real owner has been skipped.
            check("a registration with a junk active() is refused, not stored",
                  sandbox.claimEscape("bad", 1, "not a function", function() end) == false
                  and #sandbox.escapeClaims == 3)
            check("...and so is one with a junk handle()",
                  sandbox.claimEscape("bad", 1, function() return true end, 42) == false
                  and #sandbox.escapeClaims == 3, #sandbox.escapeClaims)

            out("   -- the cheat sheet closes LAST --\n")
            -- LL: "make the shortcut key cheat sheet stay up instead of
            -- it grabbing escape and closing. It should be the last
            -- window to close after all other pop-ups."
            check("🚨 THE CHEAT SHEET IS THE FLOOR of the escape order, "
               .. "strictly below every other panel. It used to be a "
               .. "literal 10, which was above every panel that had no "
               .. "claim at all — i.e. all of them but the pomodoro",
              (function()
                local floor = sandbox.escapePriorities.cheatsheet
                if floor == nil then return false, "no cheatsheet entry" end
                for name, p in pairs(sandbox.escapePriorities) do
                  if name ~= "cheatsheet" and p <= floor then return false, name end
                end
                return true
              end)())
            check("...and the order matches the order they STACK in, "
               .. "because \"closes last\" and \"sits at the bottom\" are "
               .. "one statement",
                  sandbox.escapePriorities.pomodoro
                    > sandbox.escapePriorities.switcher
                  and sandbox.escapePriorities.switcher
                    > sandbox.escapePriorities.cheatsheet)

            -- claimEscape now looks the priority up, so a panel cannot
            -- silently land on the sheet's floor by omitting one.
            local said = {}
            local realPrint = sandbox.print
            sandbox.print = function(m) said[#said + 1] = tostring(m) end
            sandbox.claimEscape("calendar", nil, function() return false end,
                                function() end)
            check("an omitted priority is LOOKED UP, not defaulted to zero",
              (function()
                for _, c in ipairs(sandbox.escapeClaims) do
                  if c.name == "calendar" then
                    return c.priority == sandbox.escapePriorities.calendar,
                           c.priority
                  end
                end
                return false, "calendar never registered"
              end)())
            sandbox.claimEscape("brand new panel", nil,
                                function() return false end, function() end)
            check("🚨 ...and a name NOT in the table is REPORTED rather than "
               .. "quietly landing on the floor the sheet occupies",
              (function()
                for _, m in ipairs(said) do
                  if m:find("_G.escapePriorities", 1, true) then return true end
                end
                return false, said[1]
              end)())
            check("...and lands ABOVE the sheet meanwhile, so the wrong "
               .. "behaviour is \"too eager\" rather than \"the sheet "
               .. "disappeared\"",
              (function()
                for _, c in ipairs(sandbox.escapeClaims) do
                  if c.name == "brand new panel" then
                    return c.priority > sandbox.escapePriorities.cheatsheet,
                           c.priority
                  end
                end
                return false
              end)())
            sandbox.print = realPrint

            -- ⎋ 6.116.0 — THE ROSTER, CHECKED AGAINST THE CALLERS. The
            -- warning above is a good backstop and a poor guard: it only
            -- fires on a Mac, at boot, in a console line that scrolls
            -- away. It has now been missed twice — notepad ran on the
            -- fallback 50 from 6.99.0 to 6.102.0, and ocredit shipped the
            -- same way in 6.115.0 and was caught only because LL pasted
            -- his boot log in for an unrelated reason. Every claimEscape
            -- that omits its priority is asking this table for one, so
            -- the table can be checked against the callers HERE, before
            -- the code ever reaches a Mac.
            do
              local missing, found = {}, 0
              local dirs = { "modules", "core" }
              for _, d in ipairs(dirs) do
                local p = io.popen('ls "' .. HS .. '/' .. d .. '" 2>/dev/null')
                for name in (p and p:lines() or function() end) do
                  if name:match("%.lua$") then
                    local f = io.open(HS .. "/" .. d .. "/" .. name, "r")
                    local src = f and f:read("*a") or ""
                    if f then f:close() end
                    -- Only the nil-priority form consults the table; a
                    -- call that passes its own number is deciding for
                    -- itself and is not this check's business.
                    for who in src:gmatch('claimEscape%s*%(%s*"([^"]+)"%s*,%s*nil') do
                      found = found + 1
                      if sandbox.escapePriorities[who] == nil then
                        missing[#missing + 1] = who .. " (" .. d .. "/" .. name .. ")"
                      end
                    end
                  end
                end
                if p then p:close() end
              end
              check("🚨 every claimEscape that omits a priority has one "
                 .. "declared in core/coexist.lua — the boot warning is a "
                 .. "backstop, not the guard",
                #missing == 0, table.concat(missing, ", "))
              -- Without this the loop above could silently match nothing
              -- and report success forever.
              check("...and the scan actually found claims to check",
                found >= 3, "found " .. found)
            end

            out("   -- and it stays up even when the other panel FAILS --\n")
            local calOpen = false
            for _, c in ipairs(sandbox.escapeClaims) do
              if c.name == "calendar" then
                c.active = function() return calOpen end
                c.handle = function() error("calendar handler is broken", 0) end
              end
            end
            timerAsking = false
            calOpen = true
            check("routeEscape reports nothing handled it when the other "
               .. "panel's handler throws — which is right for most callers",
                  sandbox.routeEscape("cheatsheet") == nil)
            check("🚨 ...but the SHEET still knows something is on screen, "
               .. "so it does not close. A broken calendar handler must "
               .. "not make the backdrop vanish",
                  sandbox.escapeOthersActive("cheatsheet") == "calendar",
                  tostring(sandbox.escapeOthersActive("cheatsheet")))
            calOpen = false
            check("...and with nothing else up, the sheet is free to close",
                  sandbox.escapeOthersActive("cheatsheet") == nil)

            out("   -- the choosers, claimed centrally --\n")
            local hidden = 0
            local vis = false
            sandbox.choosers = {
              clipboard = { isVisible = function() return vis end,
                            hide = function() hidden = hidden + 1 end },
              broken    = { isVisible = function() error("gone", 0) end,
                            hide = function() end },
            }
            check("a chooser that throws when asked is skipped, not fatal",
                  select(1, pcall(sandbox.visibleChooser)) == true)
            check("no visible chooser means no claim on Esc",
                  sandbox.visibleChooser() == nil)
            vis = true
            check("🚨 a VISIBLE chooser takes Esc from the cheat sheet — "
               .. "fifteen of them had no claim at all, and a chooser holds "
               .. "real keyboard focus, so this was the most visible form "
               .. "of the bug",
                  sandbox.routeEscape("cheatsheet") == "chooser")
            check("...and it is the chooser that got hidden", hidden == 1, hidden)
            check("...and _G.choosers is read at Esc time, not at load time, "
               .. "since init.lua fills it long after this file runs",
                  sandbox.escapeOthersActive("cheatsheet") == "chooser")
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
            -- 6.144.0 — the poll body became a NAMED function so the eco
            -- registry can rebuild the timer at battery cadence; the first
            -- pattern reads that form, the older two keep reading the
            -- inline-callback form should it ever come back.
            local w = live:match("local function clipboardPoll%(%).-\nend\n_G%.clipboardTimer")
                      or live:match("_G%.clipboardTimer = hs%.timer%.doEvery%b()")
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
    -- 🪟 6.148.0 — the five canvas cards that used to name `overlay`
    -- directly, tying themselves to the sheet's old level. A bare
    -- `overlay` reappearing in any of them is the 6.68.0 bug reborn.
    check("the ⇪- calendar card asks for its level by name",
          code("modules/mini_calendar.lua"):find('panelLevel("calendar")', 1, true) ~= nil)
    check("the 16:01 rollup card asks for its level by name",
          code("modules/daily_rollup.lua"):find('panelLevel("rollup")', 1, true) ~= nil)
    check("the Asana mirror card asks for its level by name",
          code("modules/task_creator.lua"):find('panelLevel("taskcreator")', 1, true) ~= nil)
    check("the ⇪Q dim asks for its level by name",
          code("modules/focus_mode.lua"):find('panelLevel("focus")', 1, true) ~= nil)
    check("win_pin's stickers ask for their level by name",
          code("modules/win_pin.lua"):find('panelLevel("pinbadge")', 1, true) ~= nil)
    check("the pomodoro claims Esc while it is asking",
          code("modules/pomodoro.lua"):find('claimEscape("pomodoro"', 1, true) ~= nil)
    check("🚨 AND THE CHEAT SHEET ASKS THE ROUTER BEFORE CLOSING ITSELF — "
       .. "it holds the bare Esc hotkey, so if it does not ask, no policy "
       .. "in init.lua can ever apply",
          code("core/cheatsheet.lua"):find('routeEscape("cheatsheet")', 1, true) ~= nil)

    -- ⎋ 6.93.0 — THE ROSTER CANNOT ROT AGAIN. LL, for the second time:
    -- "the cheat sheet should close last even if it's in front of another
    -- hammerspoon window". 6.78.0 built that rule, and it decayed because
    -- every chooser built afterwards forgot to file itself in _G.choosers
    -- — the only registry the escape router reads — so one Esc took the
    -- new picker AND the sheet. This sweep makes forgetting a build
    -- failure: create a chooser, touch the registry (or claim Esc).
    out("   -- every chooser is visible to the escape router --\n")
    local pipe = io.popen('ls -1 "' .. HS .. '/modules"')
    local modList = {}
    if pipe then
        for n in (pipe:read("*a") or ""):gmatch("[^\n]+") do
            if n:match("%.lua$") then modList[#modList + 1] = n end
        end
        pipe:close()
    end
    check("the module folder was listed for the sweep", #modList > 30, #modList)
    for _, n in ipairs(modList) do
        local src = code("modules/" .. n)
        if src:find("hs.chooser.new", 1, true) then
            check("⎋ " .. n .. " files its chooser in _G.choosers "
               .. "(or claims Esc itself)",
                  src:find("_G.choosers", 1, true) ~= nil
                  or src:find("claimEscape", 1, true) ~= nil)
        end
    end
end

-- =====================================================================
out("\n=== 5. 6.73.0 — THE BOOT LINE CANNOT SEE THE WARM PHASE ===\n")
-- =====================================================================
-- Read backwards, the LAST thing that runs is warm() — seconds after the
-- boot summary has already printed "All green". 6.69.0 proved what that
-- costs: "31 modules · All green", then the expander's warm() threw and
-- all 2,006 snippets were missing. The summary was not wrong; it was
-- reporting on a phase that had not happened.
do
    local f = io.open(HS .. "/init.lua", "r")
    local src = (f and f:read("*a") or ""):gsub("%-%-[^\n]*", "")
    if f then f:close() end
    local warmBlock = src:match("local function scheduleWarm.-\nend")
    check("the warm scheduler was found", warmBlock ~= nil)
    if warmBlock then
        check("a warm() failure is printed", warmBlock:find("WARM%-UP FAILED"))
        check("🚨 ...AND REACHES THE NOTICES LEDGER. Print-and-diag only is "
           .. "exactly how a dead feature stays invisible — the Console "
           .. "said it once and nothing else did",
           warmBlock:find("notices%.record") ~= nil)
        check("🚨 ...AND THE SCREEN. A module that failed to warm is a DEAD "
           .. "FEATURE whose keys still answer and do nothing",
           warmBlock:find("notices%.tell") ~= nil)
    end
    check("and the warm phase reports its OWN result, because the boot "
       .. "line printed before it existed",
       src:find("_G%.warmSummaryTimer") ~= nil)
    check("...on a HELD timer, or it is collected and never fires",
       src:find("_G%.warmSummaryTimer%s*=%s*hs%.timer%.doAfter") ~= nil)
    check("...and it stays silent when everything worked — a second 'all "
       .. "green' nobody needs teaches people to skim the first",
       src:find("if #bad == 0 then return end") ~= nil)
end

-- =====================================================================
out("\n=== 9. LEGACY ADOPTION — the stale twin must be renamed (6.115.0) ===\n")
-- =====================================================================
-- 📦 THE BUG THIS SECTION EXISTS FOR. adoptLegacyFile copied the old file
-- forward and left the original sitting there under a nearly identical
-- name, forever, with nothing marking it dead. LL ended up with
--
--     ~/.hammerspoon/activity_history.csv     ← frozen on upgrade day
--     <Logs>/activity_history.csv             ← frozen on upgrade day
--     <Logs>/activity_history-<Mac>.csv       ← the only live one
--
-- opened one of the frozen ones, and reported that his history had
-- stopped months earlier. Nothing was broken; he was reading a snapshot.
--
-- 🚨 AND THIS RUNS THE REAL FUNCTION, not a copy of it. The whole class
-- of bug here is "the shipped code does one thing and the test believes
-- another", so the function is EXTRACTED FROM init.lua's source and
-- loaded. A hand-copied reimplementation in this file would have passed
-- against the broken original just as happily.
do
    local f = io.open(HS .. "/init.lua", "r")
    local src = f and f:read("*a") or "" ; if f then f:close() end
    local block = src:match("(local function adoptLegacyFile.-\nend)\n\n%-%- WRITE%-FAILURE")
    check("adoptLegacyFile was found in init.lua and extracted whole",
          block ~= nil and #(block or "") > 400, block and #block or 0)

    local adopt = nil
    if block then
        local chunk = load(block .. "\nreturn adoptLegacyFile")
        if chunk then adopt = chunk() end
    end
    check("...and it loads as Lua", type(adopt) == "function")

    local DIR = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
                .. "/hs-adopt-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
    os.execute("mkdir -p '" .. DIR .. "'")
    local function put(name, body)
        local h = io.open(DIR .. "/" .. name, "w")
        if h then h:write(body); h:close() end
    end
    local function get(name)
        local h = io.open(DIR .. "/" .. name, "r")
        if not h then return nil end
        local s = h:read("*a"); h:close(); return s
    end
    local function gone(name) return get(name) == nil end

    if adopt then
        -- 1. THE CASE ON LL'S TWO MACS RIGHT NOW: adoption already
        -- happened releases ago, so the new file exists and the old one is
        -- still lying beside it. A fix that only ran on a FRESH adoption
        -- would have fixed nobody — every machine that has the problem is
        -- already past that branch.
        put("live-A.csv",   "new,rows\n1,2\n")
        put("legacy-A.csv", "old,rows\n9,9\n")
        adopt(DIR .. "/live-A.csv", DIR .. "/legacy-A.csv")
        check("🚨 an ALREADY-ADOPTED machine still gets its stale twin "
              .. "renamed — this is the branch every affected Mac takes",
              gone("legacy-A.csv") and get("legacy-A.csv.superseded") == "old,rows\n9,9\n")
        check("...and the LIVE file is not touched while that happens",
              get("live-A.csv") == "new,rows\n1,2\n")

        -- 2. A genuinely fresh adoption still copies, and now also retires.
        put("legacy-B.csv", "carried,forward\n")
        adopt(DIR .. "/live-B.csv", DIR .. "/legacy-B.csv")
        check("a fresh adoption copies the contents across",
              get("live-B.csv") == "carried,forward\n")
        check("...and retires the original in the same pass",
              gone("legacy-B.csv") and get("legacy-B.csv.superseded") == "carried,forward\n")

        -- 3. 🔗 THE TWO-MACHINE RULE, and the reason retirement renames
        -- instead of deleting. <Logs> lives in OneDrive and is SHARED. If
        -- the home Mac retired the shared legacy file and the work Mac had
        -- not booted yet, the work Mac's adoption source would have
        -- vanished — this fix would have caused precisely the kind of
        -- cross-machine data loss it was written to prevent.
        put("legacy-C.csv.superseded", "retired,by,the,other,mac\n")
        adopt(DIR .. "/live-C.csv", DIR .. "/legacy-C.csv")
        check("🚨 a RETIRED file is still a valid adoption source — the "
              .. "second Mac must not lose its history because the first "
              .. "Mac tidied up",
              get("live-C.csv") == "retired,by,the,other,mac\n")
        check("...and adopting FROM a retired file does not re-retire it, "
              .. "so a third machine can still find it",
              get("legacy-C.csv.superseded") == "retired,by,the,other,mac\n")

        -- 4. Retiring twice must never overwrite the first retirement —
        -- that would destroy the only copy of something to tidy up.
        put("live-D.csv",             "live\n")
        put("legacy-D.csv",           "second\n")
        put("legacy-D.csv.superseded", "first\n")
        adopt(DIR .. "/live-D.csv", DIR .. "/legacy-D.csv")
        check("🚨 an existing .superseded is never clobbered",
              get("legacy-D.csv.superseded") == "first\n"
              and get("legacy-D.csv.superseded-1") == "second\n")

        -- 5. A write that cannot land must NOT retire the original. The
        -- destination here is inside a directory that does not exist, so
        -- io.open(w) fails outright — the same shape as an offline
        -- OneDrive folder, which is the realistic version of this.
        put("legacy-E.csv", "must,survive\n")
        adopt(DIR .. "/no-such-dir/live-E.csv", DIR .. "/legacy-E.csv")
        check("🚨 a FAILED adoption keeps the original — retiring a file "
              .. "whose copy never landed would destroy the only copy",
              get("legacy-E.csv") == "must,survive\n"
              and gone("legacy-E.csv.superseded"))

        -- 6. Nothing to do at all is silent and harmless.
        local before = #printed
        adopt(DIR .. "/live-F.csv", DIR .. "/legacy-F.csv")
        check("no legacy file and no live file is a quiet no-op",
              gone("live-F.csv") and #printed == before)

        check("the retirement is announced, naming the live file so the "
              .. "Console says which one to actually open", (function()
            local sawRetire, sawLive = false, false
            for _, line in ipairs(printed) do
                if line:find("Retired superseded", 1, true) then sawRetire = true end
                if line:find("live file:", 1, true)         then sawLive   = true end
            end
            return sawRetire and sawLive
        end)())
    end

    -- The read-back check cannot be provoked with real files — a write
    -- that reports success and loses the bytes needs an offline OneDrive
    -- folder, not a temp directory. Pinned by source instead, because the
    -- ORDER is the whole protection: verify, then retire.
    check("🚨 the copy is read back and compared BEFORE the original is "
          .. "retired — io.write returning is not proof the bytes landed",
          block ~= nil and block:find("written ~= content") ~= nil)

    os.execute("rm -rf '" .. DIR .. "'")
end

realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
