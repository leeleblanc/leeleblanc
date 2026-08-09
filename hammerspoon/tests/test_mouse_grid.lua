-- =====================================================================
-- test_mouse_grid.lua — the overlay that could lock you out of your Mac
-- =====================================================================
--     lua5.4 test_mouse_grid.lua                    # ~/.hammerspoon
--     lua5.4 test_mouse_grid.lua /path/to/hammerspoon
--
-- This suite EXECUTES modules/mouse_grid.lua against a stubbed hs. It
-- does not read it as text. Grepping for "grid.hide" proves the name is
-- present and proves nothing about whether the overlay comes down.
--
-- WHAT IT IS REALLY FOR. Every other module in this config fails by
-- doing nothing. This one can fail by eating every keystroke you make
-- with a sheet over your screen, on the work MacBook, in a meeting. So
-- the centre of this file is ONE assertion, made after EVERY operation
-- in every test:
--
--        grid.state ~= nil   ⟺   a modal is entered   ⟺   a canvas is up
--
-- If those three ever disagree you are either locked out (keys captured,
-- nothing visible) or stranded (sheet visible, keys dead). checkInv()
-- below runs after literally every state change, including the failure
-- paths, and section 8 MUTATES THE SHIPPED FILE to prove that this suite
-- actually fails when the invariant is broken — a green run that stays
-- green after you delete the teardown is not a test, it is decoration.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")
local MODFILE = HS .. "/modules/mouse_grid.lua"

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
    end
end
local function out(s) io.write(s) end

-- =====================================================================
-- STUBS
-- =====================================================================
local printed, ALERTS = {}, {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

local SCREENS, CANVASES, CANVAS_NEW, TIMERS = {}, {}, 0, {}
local MOUSE_AT, CLICKS, AX_OK = { x = 0, y = 0 }, {}, true
local GLOBAL_HOTKEYS, HYPER, PROVIDED = {}, {}, {}
local SCREEN_WATCHERS = {}
local NOW = 1000

local function mkScreen(id, x, y, w, h)
    return {
        id = function() return id end,
        fullFrame = function() return { x = x, y = y, w = w, h = h } end,
        frame     = function() return { x = x, y = y + 25, w = w, h = h - 25 } end,
    }
end
local function setScreens(list) SCREENS = list end

local function mkCanvas(frame)
    CANVAS_NEW = CANVAS_NEW + 1
    local c = { frame = frame, elements = {}, visible = false, deleted = false, lvl = nil }
    function c:replaceElements(e) self.elements = e; return self end
    function c:show()   self.visible = true;  return self end
    function c:hide()   self.visible = false; return self end
    function c:delete() self.visible = false; self.deleted = true; return self end
    function c:level(l) self.lvl = l; return self end
    function c:behaviorAsLabels() return self end
    CANVASES[#CANVASES + 1] = c
    return c
end

-- The modal stub is the important one: it records bindings by chord so a
-- test can PRESS a key, and tracks entered/exited so the invariant is
-- observable rather than assumed.
local MODALS = {}
local function mkModal()
    local m = { binds = {}, entered = false }
    function m:bind(mods, key, fn)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        self.binds[table.concat(ms, "+") .. "|" .. tostring(key)] = fn
        return self
    end
    function m:enter() self.entered = true;  return self end
    function m:exit()  self.entered = false; return self end
    MODALS[#MODALS + 1] = m
    return m
end

hs = {
    configdir = HS,
    screen = {
        allScreens = function() return SCREENS end,
        mainScreen = function() return SCREENS[1] end,
        watcher = { new = function(fn)
            local w = { fn = fn, started = false }
            function w:start() self.started = true; return self end
            function w:stop()  self.started = false; return self end
            SCREEN_WATCHERS[#SCREEN_WATCHERS + 1] = w
            return w
        end },
    },
    canvas = {
        new = function(frame) return mkCanvas(frame) end,
        windowLevels = { overlay = 25, screenSaver = 1000 },
    },
    hotkey = {
        bind = function(mods, key, fn)
            local ms = {}
            for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
            table.sort(ms)
            GLOBAL_HOTKEYS[table.concat(ms, "+") .. "|" .. tostring(key)] = fn
            return {}
        end,
        modal = { new = function() return mkModal() end },
    },
    mouse = {
        absolutePosition = function(p)
            if p then MOUSE_AT = { x = p.x, y = p.y } end
            return MOUSE_AT
        end,
        getCurrentScreen = function() return SCREENS[1] end,
    },
    eventtap = {
        leftClick  = function(p) CLICKS[#CLICKS + 1] = { kind = "left",  p = p } end,
        rightClick = function(p) CLICKS[#CLICKS + 1] = { kind = "right", p = p } end,
        event = {
            types = { leftMouseDown = 1, leftMouseUp = 2 },
            properties = { mouseEventClickState = "clickState" },
            newMouseEvent = function(t, p)
                local e = { t = t, p = p }
                function e:setProperty(k, v) self.prop = v; return self end
                function e:post() CLICKS[#CLICKS + 1] = { kind = "double", p = self.p } end
                return e
            end,
        },
    },
    accessibilityState = function() return AX_OK end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = {
        secondsSinceEpoch = function() NOW = NOW + 0.001; return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
}

_G.diag = {
    said = {},
    say  = function(tag, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(tag, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err  = function(tag, m) _G.diag.said[#_G.diag.said + 1] = "err " .. m end,
    mark = function() end,
}
local function warned(needle)
    for _, l in ipairs(_G.diag.said) do
        if l:sub(1, 4) == "warn" and l:find(needle, 1, true) then return true end
    end
    return false
end

local CORE = {
    hostTag = "Test-Mac",
    hyperAddShortcut = function(mods, key, fn, src)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. tostring(key)] = fn
    end,
    provide = function(name, fn) PROVIDED[name] = fn end,
    call    = function() end,
}

-- =====================================================================
-- HARNESS
-- =====================================================================
local grid   -- the live module table under test

local function resetWorld()
    CANVASES, CANVAS_NEW, TIMERS = {}, 0, {}
    CLICKS, ALERTS, printed = {}, {}, {}
    MODALS, GLOBAL_HOTKEYS, HYPER, PROVIDED, SCREEN_WATCHERS = {}, {}, {}, {}, {}
    MOUSE_AT, AX_OK = { x = 0, y = 0 }, true
    _G.diag.said = {}
    _G.mouseGrid, _G.mouseGridReport = nil, nil
end

-- Load the SHIPPED file. `src` lets section 8 hand in a mutated copy.
local function loadModule(src)
    resetWorld()
    local chunk, err
    if src then chunk, err = load(src, "mutated")
    else chunk, err = loadfile(MODFILE) end
    if not chunk then return nil, err end
    local okM, M = pcall(chunk)
    if not okM then return nil, M end
    local okS, sErr = pcall(M.setup, CORE)
    if not okS then return nil, sErr end
    grid = _G.mouseGrid
    return M
end

local function anyCanvasVisible()
    for _, c in ipairs(CANVASES) do if c.visible then return true end end
    return false
end
local function anyModalEntered()
    for _, m in ipairs(MODALS) do if m.entered then return true end end
    return false
end

-- 🚨 THE ONE ASSERTION. Called after every single operation below.
local invBreaks = 0
local function checkInv(where)
    local s, c, m = grid.state ~= nil, anyCanvasVisible(), anyModalEntered()
    if not (s == c and c == m) then
        invBreaks = invBreaks + 1
        failures[#failures + 1] = string.format(
            "INVARIANT BROKEN at %s: state=%s canvas=%s modal=%s", where,
            tostring(s), tostring(c), tostring(m))
        fail = fail + 1
        return false
    end
    pass = pass + 1
    return true
end

local function pickKey(k)  -- press a key while the grid is up
    local fn = grid.pickModal.binds["|" .. k]
    if not fn then error("no pick binding for " .. k) end
    fn()
end
local function landKey(k, mods)
    local fn = grid.landModal.binds[(mods or "") .. "|" .. k]
    if not fn then error("no land binding for " .. (mods or "") .. "|" .. k) end
    fn()
end
local function typeLabel(label)
    for ch in label:gmatch(".") do pickKey(ch) end
end
local function liveTimer()
    for i = #TIMERS, 1, -1 do if not TIMERS[i].stopped then return TIMERS[i] end end
    return nil
end

local ONE = { mkScreen(1, 0, 0, 1512, 982) }
local TWO = { mkScreen(1, 0, 0, 1512, 982), mkScreen(2, 1512, 0, 2560, 1440) }

-- =====================================================================
out("\n=== 1. Contract, boot and key claims ===\n")
-- =====================================================================
setScreens(ONE)
local M = loadModule()
check("the shipped file loads and setup() runs", M ~= nil, M == nil and "load failed" or nil)
check("it declares a name",  M and M.name == "Mouse Grid")
check("it declares an order", M and type(M.order) == "number")
check("it registers a cheat sheet group", M and M.cheatsheet ~= nil)
check("config is exposed so a machine profile can retune it",
      M and M.config ~= nil and M.config == grid)
check("⇪X is claimed", HYPER["|x"] ~= nil)
check("⇪⇧X is claimed for click-on-arrival", HYPER["shift|x"] ~= nil)
check("the PANIC key is a plain chord, NOT a ⇪ shortcut — if ⇪ is what "
      .. "broke, a ⇪ panic key cannot be pressed",
      GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|X"] ~= nil)
check("a screen watcher is registered", #SCREEN_WATCHERS == 1)
check("...and STARTED (an unstarted watcher never fires)",
      SCREEN_WATCHERS[1] and SCREEN_WATCHERS[1].started == true)
check("the watcher is HELD on the module table, not left to the collector",
      grid.screenWatch ~= nil)
check("services are published", PROVIDED["mouseGrid.show"] ~= nil
      and PROVIDED["mouseGrid.hide"] ~= nil and PROVIDED["mouseGrid.report"] ~= nil)
check("nothing is drawn at boot — setup() must not touch the screen",
      CANVAS_NEW == 0 and not anyCanvasVisible())
check("no modal is entered at boot", not anyModalEntered())
checkInv("boot")

-- =====================================================================
out("\n=== 2. Two modals, never one — the unbind trap ===\n")
-- =====================================================================
-- hs.hotkey.modal has NO unbind. One modal would keep eating the alphabet
-- in landed mode, where those keys must reach the app underneath.
check("there are two distinct modals",
      grid.pickModal ~= nil and grid.landModal ~= nil
      and grid.pickModal ~= grid.landModal)
check("the picking modal binds every alphabet letter", (function()
    for ch in grid.alphabet:gmatch(".") do
        if grid.pickModal.binds["|" .. ch] == nil then return false, ch end
    end
    return true
end)())
check("the LANDED modal binds NO letter at all — everything you type after "
      .. "landing must reach the app underneath, with no exceptions to "
      .. "remember", (function()
    for ch in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
        if grid.landModal.binds["|" .. ch] ~= nil then return false, ch end
    end
    return true
end)())
check("escape backs out of BOTH", grid.pickModal.binds["|escape"] ~= nil
      and grid.landModal.binds["|escape"] ~= nil)
check("⌫ undoes a letter while typing", grid.pickModal.binds["|delete"] ~= nil)
check("space and return both click once landed",
      grid.landModal.binds["|space"] ~= nil and grid.landModal.binds["|return"] ~= nil)
check("⇧space right-clicks", grid.landModal.binds["shift|space"] ~= nil)
check("all four arrows nudge, coarse and fine", (function()
    for _, k in ipairs({ "up", "down", "left", "right" }) do
        if grid.landModal.binds["|" .. k] == nil then return false end
        if grid.landModal.binds["shift|" .. k] == nil then return false end
    end
    return true
end)())
check("⌘Q is NOT claimed by either modal — an overlay you can always quit "
      .. "out of cannot lock you out",
      grid.pickModal.binds["cmd|q"] == nil and grid.landModal.binds["cmd|q"] == nil)

-- =====================================================================
out("\n=== 3. Geometry: capacity, uniqueness, reachability ===\n")
-- =====================================================================
setScreens(ONE)
loadModule()
grid.show(false)
checkInv("after show")
local cache = grid.cache
check("capacity is exactly alphabet^length", cache.capacity == 9 ^ 3, cache.capacity)
check("cells never exceed the label capacity", cache.used <= cache.capacity, cache.used)
check("no cell is left unlabelled and therefore unreachable",
      cache.truncated == 0, cache.truncated)
check("one 1512x982 display resolves to a sane grid",
      cache.screens[1].cols == 34 and cache.screens[1].rows == 21,
      cache.screens[1].cols .. "x" .. cache.screens[1].rows)
check("cells land near Apple's own 44pt minimum control size",
      cache.screens[1].cellW > 40 and cache.screens[1].cellW < 50
      and cache.screens[1].cellH > 40 and cache.screens[1].cellH < 50,
      string.format("%.1f x %.1f", cache.screens[1].cellW, cache.screens[1].cellH))

check("EVERY label is unique — a duplicate sends the pointer to the wrong "
      .. "cell and looks like a random bug", (function()
    local seen, n = {}, 0
    for _, p in ipairs(cache.screens) do
        for _, c in ipairs(p.cells) do
            if seen[c.label] then return false, c.label end
            seen[c.label] = true; n = n + 1
        end
    end
    return n == cache.used
end)())
check("every label is exactly labelLength long", (function()
    for _, p in ipairs(cache.screens) do
        for _, c in ipairs(p.cells) do
            if #c.label ~= grid.labelLength then return false end
        end
    end
    return true
end)())
check("every label uses ONLY alphabet characters", (function()
    local ok = {}
    for ch in grid.alphabet:gmatch(".") do ok[ch] = true end
    for _, p in ipairs(cache.screens) do
        for _, c in ipairs(p.cells) do
            for ch in c.label:gmatch(".") do if not ok[ch] then return false, ch end end
        end
    end
    return true
end)())
check("every cell centre is INSIDE its display", (function()
    for _, p in ipairs(cache.screens) do
        local f = p.frame
        for _, c in ipairs(p.cells) do
            if c.ax < f.x or c.ax > f.x + f.w then return false end
            if c.ay < f.y or c.ay > f.y + f.h then return false end
        end
    end
    return true
end)())
check("the grid covers the FULL frame, menu bar included — frame() would "
      .. "make the menu bar and the Dock unreachable",
      cache.screens[1].frame.h == 982 and cache.screens[1].frame.y == 0)
grid.hide("test")
checkInv("after hide")

out("   -- two displays --\n")
setScreens(TWO)
loadModule()
grid.show(false)
checkInv("two-screen show")
cache = grid.cache
check("both displays get cells", #cache.screens == 2
      and #cache.screens[1].cells > 0 and #cache.screens[2].cells > 0)
check("the label space is still not overrun", cache.used <= cache.capacity
      and cache.truncated == 0, cache.used)
check("labels stay unique ACROSS displays", (function()
    local seen = {}
    for _, p in ipairs(cache.screens) do
        for _, c in ipairs(p.cells) do
            if seen[c.label] then return false, c.label end
            seen[c.label] = true
        end
    end
    return true
end)())
check("the bigger display gets more cells — area-proportional, not "
      .. "one-share-each", #cache.screens[2].cells > #cache.screens[1].cells,
      #cache.screens[1].cells .. " vs " .. #cache.screens[2].cells)
check("cells on the second display carry its absolute coordinates, so the "
      .. "pointer lands on THAT screen", cache.screens[2].cells[1].ax >= 1512)
grid.hide("test")
checkInv("two-screen hide")

-- =====================================================================
out("\n=== 4. Typing, filtering and landing ===\n")
-- =====================================================================
setScreens(ONE)
loadModule()
grid.show(false)
checkInv("show")
check("the overlay is up", anyCanvasVisible() and grid.state.phase == "pick")
check("nothing is typed yet", grid.state.typed == "")

local function candidateCount()
    local n = 0
    for _ in pairs(grid.state.matches or {}) do n = n + 1 end
    return n
end

pickKey("a")
checkInv("after 1st letter")
check("one letter narrows 714 cells to 81", candidateCount() == 81, candidateCount())
check("the pointer has NOT moved yet",
      MOUSE_AT.x == 0 and MOUSE_AT.y == 0)
pickKey("a")
checkInv("after 2nd letter")
check("two letters narrow it to 9", candidateCount() == 9, candidateCount())
check("still no jump before the label is complete", MOUSE_AT.x == 0)

check("labels show only what is LEFT to type — repeating the typed prefix "
      .. "is noise, and dropping it makes each redraw cheaper", (function()
    for _, p in ipairs(grid.cache.screens) do
        for _, el in ipairs(p.labelCanvas.elements) do
            if el.type == "text" and #el.text ~= 1 then return false, el.text end
        end
    end
    return true
end)())

pickKey("a")
checkInv("after landing")
check("the third letter jumps the pointer to the cell centre",
      math.abs(MOUSE_AT.x - 1512 / 34 / 2) < 0.01
      and math.abs(MOUSE_AT.y - 982 / 21 / 2) < 0.01,
      string.format("%.2f,%.2f", MOUSE_AT.x, MOUSE_AT.y))
check("the grid comes down on landing", (function()
    for _, p in ipairs(grid.cache.screens) do
        if p.gridCanvas.visible or p.labelCanvas.visible then return false end
    end
    return true
end)())
check("landed mode is entered, not exited", grid.state
      and grid.state.phase == "landed")
check("the landed badge is on screen — keys are being captured and "
      .. "something must SAY SO", grid.cross ~= nil and grid.cross.visible)
check("the picking modal has handed over to the landed one",
      grid.pickModal.entered == false and grid.landModal.entered == true)
check("no click happened by itself", #CLICKS == 0)
grid.hide("test")
checkInv("hide from landed")
check("the badge is destroyed, not merely hidden", grid.cross == nil)

out("   -- backspace --\n")
loadModule(); grid.show(false)
typeLabel("aa"); checkInv("typed aa")
grid.backspace(); checkInv("backspaced")
check("⌫ widens the candidate set back out", candidateCount() == 81, candidateCount())
grid.backspace(); checkInv("backspaced to empty")
check("⌫ back to nothing typed", grid.state.typed == "")
grid.backspace(); checkInv("backspace past empty")
check("⌫ past the start CLOSES the grid rather than sitting there doing "
      .. "nothing", grid.state == nil)

out("   -- a label on the last partial row --\n")
loadModule(); grid.show(false)
local last = grid.cache.screens[1].cells[#grid.cache.screens[1].cells]
typeLabel(last.label)
checkInv("landed on last cell")
check("the very last cell is reachable and lands where it says",
      math.abs(MOUSE_AT.x - last.ax) < 0.01 and math.abs(MOUSE_AT.y - last.ay) < 0.01,
      last.label)
grid.hide("test")

-- =====================================================================
out("\n=== 5. Clicking, nudging, and Accessibility ===\n")
-- =====================================================================
loadModule(); grid.show(false); typeLabel("aaa")
local landedAt = { x = MOUSE_AT.x, y = MOUSE_AT.y }
landKey("up"); checkInv("nudged up")
check("↑ nudges by nudgeStep", math.abs(MOUSE_AT.y - (landedAt.y - grid.nudgeStep)) < 0.01,
      MOUSE_AT.y)
check("nudging does NOT close the overlay — nudge-then-click is the whole "
      .. "point of landed mode", grid.state ~= nil and grid.state.phase == "landed")
landKey("right", "shift"); checkInv("fine nudge")
check("⇧→ nudges by the fine step",
      math.abs(MOUSE_AT.x - (landedAt.x + grid.nudgeFine)) < 0.01, MOUSE_AT.x)
check("the badge follows the pointer as it moves",
      grid.cross ~= nil and grid.cross.visible)
landKey("space"); checkInv("after click")
check("space clicks once", #CLICKS == 1 and CLICKS[1].kind == "left", #CLICKS)
check("it clicks the NUDGED point, not the original cell centre",
      math.abs(CLICKS[1].p.x - MOUSE_AT.x) < 0.01
      and math.abs(CLICKS[1].p.y - MOUSE_AT.y) < 0.01)
check("everything is torn down after the click", grid.state == nil
      and grid.cross == nil and not anyModalEntered())

loadModule(); grid.show(false); typeLabel("aaa"); landKey("space", "shift")
checkInv("right click")
check("⇧space right-clicks", #CLICKS == 1 and CLICKS[1].kind == "right")

loadModule(); grid.show(false); typeLabel("aaa"); landKey("2")
checkInv("double click")
check("2 posts a REAL double click (clickState 2), not two singles that "
      .. "most apps read as two separate selections",
      #CLICKS == 4 and CLICKS[1].kind == "double", #CLICKS)

out("   -- ⇪⇧X clicks on arrival --\n")
loadModule(); grid.show(true); typeLabel("aaa")
checkInv("click on arrival")
check("⇪⇧X clicks the moment the label completes", #CLICKS == 1)
check("...and does not linger in landed mode", grid.state == nil)

out("   -- no Accessibility (the work Mac) --\n")
loadModule()
AX_OK = false
grid.show(false); checkInv("show without AX")
check("the grid still opens without Accessibility", grid.state ~= nil)
typeLabel("aaa"); checkInv("jumped without AX")
check("THE JUMP STILL WORKS — warping the pointer needs no permission",
      MOUSE_AT.x > 0 and MOUSE_AT.y > 0)
landKey("space"); checkInv("click refused")
check("...but the click is refused rather than silently doing nothing",
      #CLICKS == 0)
check("and it says WHY, naming Accessibility", (function()
    for _, a in ipairs(ALERTS) do if a:find("Accessibility", 1, true) then return true end end
    return false
end)())
check("the refusal is recorded in the diagnostic trail",
      warned("Accessibility off"))
check("the overlay is fully down after a refused click", grid.state == nil)
AX_OK = true

-- =====================================================================
out("\n=== 6. 🚨 SAFETY: every path out, including the broken ones ===\n")
-- =====================================================================
out("   -- escape --\n")
loadModule(); grid.show(false); typeLabel("aa")
grid.pickModal.binds["|escape"]()
checkInv("escape while typing")
check("⎋ closes the grid", grid.state == nil)
check("⎋ leaves the pointer exactly where it was — a cancel that moves the "
      .. "mouse is not a cancel", MOUSE_AT.x == 0 and MOUSE_AT.y == 0)

loadModule(); grid.show(false); typeLabel("aaa")
grid.landModal.binds["|escape"]()
checkInv("escape while landed")
check("⎋ leaves landed mode", grid.state == nil and grid.cross == nil)
check("...and leaves the pointer where you put it", MOUSE_AT.x > 0)

out("   -- the panic key --\n")
loadModule(); grid.show(false); typeLabel("a")
GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|X"]()
checkInv("panic from pick")
check("⌃⌥⌘⇧X clears a grid mid-type", grid.state == nil and not anyCanvasVisible())
loadModule(); grid.show(false); typeLabel("aaa")
GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|X"]()
checkInv("panic from landed")
check("⌃⌥⌘⇧X clears the landed badge too", grid.state == nil and grid.cross == nil)

out("   -- the watchdog --\n")
loadModule(); grid.show(false)
local wd = liveTimer()
check("showing the grid arms a watchdog", wd ~= nil and wd.secs == grid.timeoutSecs)
wd.fn()
checkInv("watchdog fired")
check("an overlay left open tears ITSELF down", grid.state == nil
      and not anyCanvasVisible())
check("the watchdog says so in the trail", warned("watchdog fired"))

loadModule(); grid.show(false); typeLabel("aaa")
wd = liveTimer()
check("landed mode re-arms the watchdog on its own, shorter timer",
      wd ~= nil and wd.secs == grid.landedSecs, wd and wd.secs)
wd.fn(); checkInv("landed watchdog")
check("a landed badge left open tears itself down too", grid.state == nil)

loadModule(); grid.show(false)
typeLabel("a"); typeLabel("a")
local live = 0
for _, t in ipairs(TIMERS) do if not t.stopped then live = live + 1 end end
check("only ONE watchdog is ever live — each keystroke re-arms and stops "
      .. "the last, so old timers cannot fire under a new session", live == 1, live)
grid.hide("test"); checkInv("hide")
live = 0
for _, t in ipairs(TIMERS) do if not t.stopped then live = live + 1 end end
check("hiding stops the watchdog — nothing is left ticking", live == 0, live)

out("   -- toggle, double-show, double-hide --\n")
loadModule()
grid.show(false); checkInv("show 1")
grid.show(false); checkInv("show 2 (toggle off)")
check("pressing ⇪X while it is up puts it away rather than stacking a "
      .. "second overlay", grid.state == nil and not anyCanvasVisible())
grid.hide("again"); checkInv("hide when already hidden")
grid.hide("again"); checkInv("hide x3")
check("hide() is idempotent — calling it on a closed grid is harmless",
      grid.state == nil)

out("   -- a throw inside a key binding --\n")
loadModule(); grid.show(false)
grid.cache.screens = nil   -- force typeChar to blow up mid-flight
pickKey("a")
checkInv("after an error in a binding")
check("an exception inside a modal binding TEARS THE OVERLAY DOWN rather "
      .. "than leaving a keyboard-eating sheet on your screen",
      grid.state == nil and not anyCanvasVisible() and not anyModalEntered())
check("and the error reaches the diagnostic trail", warned("typeChar"))

out("   -- a dead-end prefix --\n")
loadModule(); grid.show(false)
-- 'l' exists but the grid stops at 714 cells, so some 'l' prefixes are
-- genuinely empty. Find one and prove it is rejected, not fatal.
local dead
for ch in grid.alphabet:gmatch(".") do
    local found = false
    for _, c in ipairs(grid.cache.screens[1].cells) do
        if c.label:sub(1, 2) == "l" .. ch then found = true break end
    end
    if not found then dead = ch break end
end
check("the truncated last row really does create empty prefixes to test",
      dead ~= nil, dead)
if dead then
    pickKey("l"); checkInv("typed l")
    local before = candidateCount()
    pickKey(dead); checkInv("dead-end rejected")
    check("a prefix with no cells is REJECTED, leaving you where you were, "
          .. "rather than stranding you in a grid with nothing selectable",
          grid.state ~= nil and grid.state.typed == "l" and candidateCount() == before)
    check("...and it says so", #ALERTS > 0)
end
grid.hide("test"); checkInv("cleanup")

out("   -- displays change while the grid is up --\n")
setScreens(ONE); loadModule(); grid.show(false)
setScreens(TWO)
SCREEN_WATCHERS[1].fn()
checkInv("after a display change")
check("plugging in a monitor closes the overlay instead of drawing "
      .. "yesterday's layout over today's screens", grid.state == nil)
check("the stale geometry cache is dropped", grid.cache == nil)
grid.show(false); checkInv("show after display change")
check("the next show rebuilds for the NEW layout", #grid.cache.screens == 2)
grid.hide("test"); checkInv("cleanup")

-- =====================================================================
out("\n=== 7. The performance architecture is real, not aspirational ===\n")
-- =====================================================================
setScreens(ONE); loadModule()
grid.show(false)
local afterFirst = CANVAS_NEW
grid.hide("t"); grid.show(false); grid.hide("t"); grid.show(false)
check("canvases are built ONCE per display layout and reused — rebuilding "
      .. "~1,500 elements per press is the difference between a tool you "
      .. "reach for and one you forget", CANVAS_NEW == afterFirst,
      afterFirst .. " -> " .. CANVAS_NEW)
check("two canvases per screen: static scrim+lines, and the labels that "
      .. "actually redraw", afterFirst == 2)
check("the scrim and grid lines are a separate canvas from the labels",
      grid.cache.screens[1].gridCanvas ~= grid.cache.screens[1].labelCanvas)
check("the unfiltered label table is cached, so even the first draw is a "
      .. "reuse from the second invocation on",
      grid.cache.screens[1].fullLabels ~= nil
      and #grid.cache.screens[1].fullLabels == #grid.cache.screens[1].cells)

local full = #grid.cache.screens[1].labelCanvas.elements
pickKey("a")
local one = #grid.cache.screens[1].labelCanvas.elements
pickKey("a")
local two = #grid.cache.screens[1].labelCanvas.elements
check("each keystroke shrinks the redraw — 714 -> 81 -> 9",
      full > one and one > two and two == 9,
      full .. " -> " .. one .. " -> " .. two)
grid.hide("t"); checkInv("cleanup")

check("the grid canvas is the scrim plus one line per divider, not one "
      .. "rectangle per cell", (function()
    local p = grid.cache.screens[1]
    return #p.gridCanvas.elements == 1 + (p.cols - 1) + (p.rows - 1)
end)(), #grid.cache.screens[1].gridCanvas.elements)
check("the overlay draws ABOVE the menu bar — at overlay level the top "
      .. "25pt hides behind it and menu-bar items become unreachable",
      grid.cache.screens[1].gridCanvas.lvl == 1000)

out("   -- the colours you asked for --\n")
local scrim = grid.cache.screens[1].gridCanvas.elements[1]
check("the scrim is 30% coverage, not 30% brightness — an opaque 30% grey "
      .. "would hide the very thing you are aiming at",
      scrim.fillColor.alpha == 0.30 and scrim.fillColor.white == 0.00,
      tostring(scrim.fillColor.alpha))
local line = grid.cache.screens[1].gridCanvas.elements[2]
check("grid lines are 80% grey", line.strokeColor.white == 0.80)
check("the scrim covers the whole display", scrim.frame.w == 1512
      and scrim.frame.h == 982)

out("   -- the report --\n")
setScreens(TWO); loadModule()
local rep = _G.mouseGridReport()
check("_G.mouseGridReport() exists and returns its text", type(rep) == "string")
check("it names the alphabet and the capacity arithmetic",
      rep:find("729", 1, true) ~= nil)
check("it prints the REAL cell size per display, which is the only number "
      .. "that decides whether this is usable on a given Mac",
      rep:find("cell = ", 1, true) ~= nil)
check("it warns when two displays make the cells coarser than most buttons",
      rep:find("coarser", 1, true) ~= nil)
check("it reports the Accessibility state, because that decides whether "
      .. "space-to-click works", rep:find("Accessibility", 1, true) ~= nil)
-- loadModule() resets the world, AX_OK included — so this must come AFTER
-- it, not before. (It was before, and the check passed for the wrong
-- reason until the suite was read back.)
loadModule(); AX_OK = false; rep = _G.mouseGridReport()
check("...and says the jump still works when it is off",
      rep:find("jump works", 1, true) ~= nil)
AX_OK = true

-- =====================================================================
out("\n=== 8. MUTATIONS — proof this suite fails when it should ===\n")
-- =====================================================================
-- A suite that stays green after you delete the teardown is decoration.
-- Each mutation reverses one invariant in the SHIPPED source and runs a
-- probe that MUST fail. If a probe still passes, that line is untested.
local src do
    local f = io.open(MODFILE, "r"); src = f:read("*a"); f:close()
end

local mutations = {
    {
        name  = "hide() no longer exits the modals",
        from  = 'pcall(function() if grid.pickModal then grid.pickModal:exit() end end)',
        to    = '-- removed',
        probe = function()
            setScreens(ONE); grid.show(false); grid.hide("m")
            -- keys captured, nothing on screen: the lock-out
            return not anyModalEntered()
        end,
    },
    {
        name  = "hide() no longer hides the canvases",
        from  = '        hideAllShown()\n        pcall(function() if grid.cross',
        to    = '        pcall(function() if grid.cross',
        probe = function()
            setScreens(ONE); grid.show(false); grid.hide("m")
            return not anyCanvasVisible()
        end,
    },
    {
        -- 🐛 THE REGRESSION THIS SUITE ACTUALLY CAUGHT, pinned so it cannot
        -- come back. hide() originally walked `grid.cache.screens or {}` to
        -- put the overlay away. When the thing that broke IS the cache,
        -- `or {}` turns the teardown into a no-op: the modal exits, the
        -- state clears, and the sheet stays on screen over everything.
        -- Teardown must never depend on the structure that just failed.
        name  = "hide() goes back to trusting the cache it is cleaning up after",
        from  = '        hideAllShown()\n        pcall(function() if grid.cross',
        to    = '        if grid.cache then\n'
             .. '            for _, p in ipairs(grid.cache.screens or {}) do\n'
             .. '                pcall(function() p.gridCanvas:hide() end)\n'
             .. '                pcall(function() p.labelCanvas:hide() end)\n'
             .. '            end\n'
             .. '        end\n'
             .. '        pcall(function() if grid.cross',
        probe = function()
            setScreens(ONE); grid.show(false)
            grid.cache.screens = nil        -- the cache is what broke
            pcall(pickKey, "a")             -- error path -> hide()
            return not anyCanvasVisible()   -- the sheet must be gone
        end,
    },
    {
        name  = "showCanvas stops recording what it put on screen",
        from  = 'grid.shown[#grid.shown + 1] = c',
        to    = '-- removed',
        probe = function()
            setScreens(ONE); grid.show(false); grid.hide("m")
            return not anyCanvasVisible()
        end,
    },
    {
        name  = "the watchdog no longer tears down",
        from  = 'grid.hide("watchdog")',
        to    = '-- removed',
        probe = function()
            setScreens(ONE); grid.show(false)
            local t = liveTimer(); t.fn()
            return grid.state == nil
        end,
    },
    {
        name  = "labels lose a digit and collide",
        from  = 'local digit = math.floor(index / (n ^ (place - 1))) % n',
        to    = 'local digit = math.floor(index / (n ^ (place - 1))) % (n - 1)',
        probe = function()
            setScreens(ONE); grid.show(false)
            local seen = {}
            for _, p in ipairs(grid.cache.screens) do
                for _, c in ipairs(p.cells) do
                    if seen[c.label] then return false end
                    seen[c.label] = true
                end
            end
            return true
        end,
    },
    {
        name  = "a throw in a binding is no longer caught",
        from  = 'local ok, err = pcall(grid.typeChar, ch)',
        to    = 'local ok, err = true, nil; grid.typeChar(ch)',
        probe = function()
            setScreens(ONE); grid.show(false)
            grid.cache.screens = nil
            pcall(pickKey, "a")
            return grid.state == nil and not anyCanvasVisible()
        end,
    },
    {
        name  = "showing twice stacks instead of toggling",
        from  = 'if grid.state then grid.hide("toggled off") return false end',
        to    = '',
        probe = function()
            setScreens(ONE); grid.show(false); grid.show(false)
            return grid.state == nil
        end,
    },
    {
        name  = "landed mode forgets to leave the picking modal",
        from  = 'pcall(function() grid.pickModal:exit() end)',
        to    = '-- removed',
        probe = function()
            setScreens(ONE); grid.show(false); typeLabel("aaa")
            -- both modals live means the alphabet is still being eaten
            return not (grid.pickModal.entered and grid.landModal.entered)
        end,
    },
    {
        name  = "the click no longer checks Accessibility",
        from  = 'if not axAvailable() then\n            grid.hide("click refused")',
        to    = 'if false then\n            grid.hide("click refused")',
        probe = function()
            setScreens(ONE); grid.show(false); AX_OK = false
            typeLabel("aaa"); landKey("space")
            local n = #CLICKS; AX_OK = true
            return n == 0
        end,
    },
}

for _, mut in ipairs(mutations) do
    local mutated, n = src:gsub(mut.from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"),
                                (mut.to:gsub("%%", "%%%%")), 1)
    if n == 0 then
        check("MUTATION ANCHOR MISSING (the file changed under the test): "
              .. mut.name, false)
    else
        local okLoad = loadModule(mutated)
        if not okLoad then
            -- A mutation that will not even load is still a caught mutation.
            check("mutation caught at load: " .. mut.name, true)
        else
            local okProbe, res = pcall(mut.probe)
            check("mutation CAUGHT: " .. mut.name, (not okProbe) or (res == false))
        end
    end
end
setScreens(ONE); loadModule()

-- =====================================================================
out("\n=== 9. Cross-Mac: it must survive a hostile machine ===\n")
-- =====================================================================
out("   -- one tiny display --\n")
setScreens({ mkScreen(1, 0, 0, 800, 600) })
loadModule(); grid.show(false); checkInv("tiny display")
check("a small display still gets a full, unique, reachable grid",
      grid.cache.truncated == 0 and grid.cache.used > 0)
grid.hide("t")

out("   -- four displays --\n")
setScreens({ mkScreen(1, 0, 0, 1512, 982), mkScreen(2, 1512, 0, 2560, 1440),
             mkScreen(3, 4072, 0, 1920, 1080), mkScreen(4, 0, 982, 1280, 800) })
loadModule(); grid.show(false); checkInv("four displays")
check("four displays split the label space without overrun",
      grid.cache.used <= grid.cache.capacity and grid.cache.truncated == 0,
      grid.cache.used)
check("every display gets at least one cell", (function()
    for _, p in ipairs(grid.cache.screens) do
        if #p.cells == 0 then return false end
    end
    return true
end)())
check("labels remain unique across all four", (function()
    local seen = {}
    for _, p in ipairs(grid.cache.screens) do
        for _, c in ipairs(p.cells) do
            if seen[c.label] then return false end
            seen[c.label] = true
        end
    end
    return true
end)())
grid.hide("t"); checkInv("cleanup")

out("   -- no displays at all (a Mac with the lid shut) --\n")
setScreens({})
loadModule()
local okShow = grid.show(false)
check("no screens does not crash the module", okShow == false)
checkInv("no screens")
check("it explains itself rather than failing silently", #ALERTS > 0)

out("   -- hs.canvas refuses to allocate --\n")
setScreens(ONE)
local savedNew = hs.canvas.new
hs.canvas.new = function() return nil end
loadModule()
okShow = grid.show(false)
check("a canvas that cannot be created is handled, not thrown",
      okShow == false)
checkInv("canvas allocation failed")
check("...and reported", warned("show failed") or #ALERTS > 0)
hs.canvas.new = savedNew

out("   -- a wider alphabet for multi-monitor Macs --\n")
setScreens(TWO); loadModule()
grid.alphabet = "asdfghjklzxcvbnm"   -- 16 keys
grid.show(false); checkInv("wider alphabet")
check("widening the alphabet really does buy capacity (16^3 = 4096)",
      grid.cache.capacity == 16 ^ 3, grid.cache.capacity)
check("...and it buys finer cells, which is the whole reason to do it",
      grid.cache.screens[1].cellW < 45, grid.cache.screens[1].cellW)
check("labels stay unique with the new alphabet", (function()
    local seen = {}
    for _, p in ipairs(grid.cache.screens) do
        for _, c in ipairs(p.cells) do
            if seen[c.label] then return false end
            seen[c.label] = true
        end
    end
    return true
end)())
grid.hide("t"); checkInv("cleanup")

out("   -- a four-deep home row --\n")
setScreens(ONE); loadModule()
grid.labelLength = 4
grid.show(false); checkInv("length 4")
check("labelLength 4 gives 6561 labels", grid.cache.capacity == 9 ^ 4)
check("every label is now four characters", (function()
    for _, c in ipairs(grid.cache.screens[1].cells) do
        if #c.label ~= 4 then return false end
    end
    return true
end)())
typeLabel(grid.cache.screens[1].cells[1].label)
checkInv("landed with a 4-char label")
check("a four-letter label lands correctly", grid.state ~= nil
      and grid.state.phase == "landed")
grid.hide("t")

out("   -- disabled by a machine profile --\n")
setScreens(ONE); loadModule()
grid.enabled = false
check("grid.enabled = false refuses to open", grid.show(false) == false)
checkInv("disabled")
grid.enabled = true

-- =====================================================================
out("\n=== 10. Work-Mac safety: nothing here needs admin ===\n")
-- =====================================================================
-- Same guarantee the rest of the config is held to. A module that shells
-- out or writes outside $HOME would break it, and this one must not.
do
    local body = src:gsub("%-%-[^\n]*", "")   -- strip comments; prose is not code
    for _, bad in ipairs({ "sudo", "launchctl", "csrutil", "spctl", "chown",
                           "hs%.task", "os%.execute", "io%.popen", "hs%.osascript" }) do
        check("mouse_grid runs no " .. bad:gsub("%%", ""),
              body:find(bad) == nil)
    end
    check("it writes no files at all — nothing to land outside $HOME",
          body:find("io%.open") == nil)
    check("it makes no network calls", body:find("hs%.http") == nil)
    check("the only macOS permission it can need is Accessibility, and it "
          .. "degrades rather than fails without it",
          body:find("hs%.accessibilityState") ~= nil)
end

-- =====================================================================
out("\n=== 11. It is wired into init.lua and the docs ===\n")
-- =====================================================================
do
    local f = io.open(HS .. "/init.lua", "r")
    local init = f and f:read("*a") or ""
    if f then f:close() end
    -- Live code only: my own comment mentioning a file is not the file
    -- being loaded, and that exact mistake made a 6.44.11 audit lie.
    local live = init:gsub("%-%-[^\n]*", "")
    local profiles = 0
    for _ in live:gmatch('"mouse_grid"') do profiles = profiles + 1 end
    check("mouse_grid is listed in ALL THREE machine profiles — personal, "
          .. "work and default", profiles == 3, profiles)

    local f2 = io.open(HS .. "/tools/run-tests.sh", "r")
    local rt = f2 and f2:read("*a") or ""
    if f2 then f2:close() end
    check("run-tests.sh runs this suite — a test nothing runs is not a test",
          rt:find("test_mouse_grid", 1, true) ~= nil)

    local f3 = io.open(HS .. "/tools/hs-doctor.sh", "r")
    local dr = f3 and f3:read("*a") or ""
    if f3 then f3:close() end
    -- Counted from DISK, not typed here: a hard-coded number in the test
    -- that keeps the docs honest is the same drift it exists to prevent.
    local nMods = 0
    do
        local pipe = io.popen('ls -1 "' .. HS .. '/modules"/*.lua 2>/dev/null | wc -l')
        if pipe then nMods = tonumber((pipe:read("*a") or ""):match("%d+")) or 0; pipe:close() end
    end
    check("the module directory was counted", nMods > 0, nMods)
    check("hs-doctor.sh expects the REAL module count",
          dr:find("expect " .. nMods, 1, true) ~= nil, nMods)

    local f4 = io.open(HS .. "/INSTALL.md", "r")
    local inst = f4 and f4:read("*a") or ""
    if f4 then f4:close() end
    check("INSTALL.md's module count matches what ships",
          inst:find(nMods .. " files", 1, true) ~= nil, nMods)
    check("INSTALL.md's confirmation table includes ⇪X, so a fresh install "
          .. "is actually verified", inst:find("⇪X", 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 12. Hostile display geometry — the hang, not the crash ===\n")
-- =====================================================================
-- Everything here was found by reading the code against Hammerspoon's own
-- source rather than by a test failing, which is why each one gets a test
-- now. The first is the worst failure this module could have.
out("   -- a display reporting zero height --\n")
setScreens({ mkScreen(1, 0, 0, 1512, 982), mkScreen(2, 1512, 0, 1920, 0) })
loadModule()
-- 🚨 If this regresses, it does not fail — it HANGS. w/h is infinite,
-- math.floor(math.huge) is math.huge, and `for c = 0, inf` never returns.
-- Hammerspoon spins with no error and no recovery but a force-quit.
do
    local done = false
    local ok = pcall(function() grid.show(false); done = true end)
    check("a zero-height display does not hang the cell loop", ok and done)
end
checkInv("zero-height display")
check("the good display still gets a full grid", grid.cache ~= nil
      and #grid.cache.screens == 1, grid.cache and #grid.cache.screens)
check("the unusable display is NAMED, not silently dropped — a screen "
      .. "missing from the grid is a region you cannot reach",
      warned("unusable frame"))
check("no cell is left unlabelled", grid.cache.truncated == 0)
grid.hide("t"); checkInv("cleanup")

out("   -- every other way a frame can be broken --\n")
for _, bad in ipairs({
    { "negative width",  mkScreen(2, 0, 0, -100, 800) },
    { "zero width",      mkScreen(2, 0, 0, 0, 800) },
    { "NaN height",      mkScreen(2, 0, 0, 800, 0 / 0) },
    { "infinite width",  mkScreen(2, 0, 0, math.huge, 800) },
}) do
    setScreens({ mkScreen(1, 0, 0, 1512, 982), bad[2] })
    loadModule()
    local ok = pcall(function() grid.show(false) end)
    check("survives a display with " .. bad[1], ok and grid.state ~= nil, bad[1])
    checkInv(bad[1])
    grid.hide("t")
end

out("   -- a frame that PASSES the filter and still overflows --\n")
-- 🚨 THE FRAME FILTER IS NOT ENOUGH, AND THIS IS THE PROOF. w and h here
-- are both finite and positive, so usableFrame() accepts them — and w/h is
-- still infinity, so cols becomes inf and the cell loop never returns.
-- What saves it is the cols clamp in planScreen. Remove that clamp and
-- this check does not fail, it HANGS — which is why it is worth its own
-- case rather than being folded into the fuzzer.
setScreens({ mkScreen(1, 0, 0, 1512, 982), mkScreen(2, 0, 982, 1e300, 1e-300) })
loadModule()
do
    local done = false
    local ok = pcall(function() grid.show(false); done = true end)
    check("a frame that survives the filter but overflows the division is "
          .. "still bounded by the cols clamp", ok and done)
end
checkInv("overflowing frame")
check("...and it produces no unreachable cells",
      grid.cache and grid.cache.truncated == 0)
grid.hide("t")

out("   -- a thin strip beside big displays (small share, huge aspect) --\n")
-- This is when cols can exceed the labels actually available: the strip's
-- share of the label space is tiny while its aspect ratio is enormous.
-- Without cols <= share the surplus cells carry no label and the right of
-- that display is unreachable.
setScreens({ mkScreen(1, 0, 0, 3840, 2160), mkScreen(2, 3840, 0, 3840, 2160),
             mkScreen(3, 7680, 0, 3840, 2160), mkScreen(4, 0, 2160, 6016, 100) })
loadModule(); grid.show(false); checkInv("thin strip")
check("cells never exceed the label capacity even on a pathological layout",
      grid.cache.used <= grid.cache.capacity,
      grid.cache.used .. "/" .. grid.cache.capacity)
check("...and nothing is left unlabelled", grid.cache.truncated == 0,
      grid.cache.truncated)
check("every display still gets at least one cell", (function()
    for _, p in ipairs(grid.cache.screens) do
        if #p.cells == 0 then return false end
    end
    return true
end)())
grid.hide("t")

out("   -- fractional frames (a scaled Retina display) --\n")
-- string.format("%d", 1512.5) RAISES in Lua 5.4. Screen frames are not
-- something this module controls, so no %d may touch one.
setScreens({ mkScreen(1, 0.5, 0.5, 1512.5, 982.25) })
loadModule()
do
    local ok = pcall(function() grid.show(false) end)
    check("a fractional screen frame does not raise 'number has no integer "
          .. "representation'", ok and grid.state ~= nil)
end
checkInv("fractional frame")
grid.hide("t")
check("and the report survives it too", (function()
    return (pcall(_G.mouseGridReport))
end)())

out("   -- an alphabet key this keyboard cannot send --\n")
-- hs.hotkey's getKeycode RAISES on an unknown key name rather than
-- returning nil, so one exotic character would kill setup().
hs.keycodes = { map = { a = 0, s = 1, d = 2, f = 3, g = 5, h = 4,
                        j = 38, k = 40, l = 37 } }
setScreens(ONE); loadModule()
grid.alphabet = "asdfghjkl€"
do
    local ok = pcall(function() grid.show(false) end)
    check("an untypeable character is dropped rather than taking the module "
          .. "down", ok and grid.state ~= nil)
end
check("...and it says which key it dropped", warned("dropped unusable"))
check("no cell is labelled with a key you cannot press", (function()
    for _, c in ipairs(grid.cache.screens[1].cells) do
        if c.label:find("€", 1, true) then return false end
    end
    return true
end)())
checkInv("bad alphabet key")
grid.hide("t")
hs.keycodes = nil

out("   -- a badge that cannot be drawn --\n")
-- 🚨 The invisible-capture hazard: landed mode with no badge means keys are
-- being eaten and nothing on screen says so.
setScreens(ONE); loadModule(); grid.show(false)
local savedNew2 = hs.canvas.new
typeLabel("aa")
hs.canvas.new = function() return nil end     -- fail only the badge
pickKey("a")
hs.canvas.new = savedNew2
checkInv("badge allocation failed")
check("if the landed badge cannot be drawn, landed mode is REFUSED rather "
      .. "than captured invisibly", grid.state == nil)
check("...but the pointer still moved, which is most of the value",
      MOUSE_AT.x > 0)
check("and it says why", warned("invisibly"))

setScreens(ONE); loadModule(); grid.show(false); typeLabel("aaa")
check("landed normally first", grid.state ~= nil and grid.cross ~= nil)
hs.canvas.new = function() return nil end
landKey("up")
hs.canvas.new = savedNew2
checkInv("badge lost mid-nudge")
check("a badge lost DURING a nudge tears landed mode down too — the old "
      .. "one is already destroyed by then", grid.state == nil)

-- =====================================================================
out("\n=== 13. Geometry fuzz — 4,000 random display layouts ===\n")
-- =====================================================================
-- The invariants above were checked against layouts I thought of. This
-- checks them against layouts I did not. Every property here is one whose
-- violation is a screen region you cannot reach, or a hang.
do
    math.randomseed(20260808)
    -- The last few of each are deliberately pathological. Realistic monitor
    -- sizes alone never produce a share small enough with an aspect large
    -- enough to expose the cols<=share clamp — reverting that clamp left
    -- 237 checks green until these shapes were added.
    local sizes = { 800, 1024, 1280, 1366, 1440, 1512, 1680, 1920, 2560,
                    3440, 3840, 5120, 640, 320, 6016, 7680 }
    local heights = { 480, 600, 720, 768, 800, 900, 982, 1050, 1080, 1440,
                      1600, 1964, 2160, 240, 100, 60 }
    local worst, cases, bad = 0, 0, nil
    -- ⚠️ The alphabet is NOT varied in here. The modal binds one hotkey per
    -- alphabet character during setup(), so widening it afterwards would
    -- build a geometry using letters that were never bound — and the probe
    -- below would fail on the test's own mistake rather than on the
    -- module's. The wide alphabet is covered in section 9, where the
    -- module is set up with it. Only labelLength varies here, because every
    -- home-row character stays bound whatever its length.
    for iter = 1, 1500 do
      -- Each case is isolated: an unexpected throw is REPORTED with its
      -- layout, not allowed to kill the run and hide the other 1,499.
      local okCase, caseErr = pcall(function()
        local n = 1 + (iter % 4)          -- 1..4 displays
        local list, x, desc = {}, 0, {}
        for i = 1, n do
            local w = sizes[math.random(#sizes)]
            local h = heights[math.random(#heights)]
            list[#list + 1] = mkScreen(i, x, 0, w, h)
            desc[#desc + 1] = w .. "x" .. h
            x = x + w
        end
        local layout = table.concat(desc, " + ")
        setScreens(list)
        loadModule()
        if iter % 7 == 0 then grid.labelLength = 2 + (iter % 3) end
        local ok, err = pcall(function() grid.show(false) end)
        cases = cases + 1
        if not ok then bad = bad or (layout .. " threw: " .. tostring(err)); return end
        local c = grid.cache
        if not c then bad = bad or (layout .. ": no cache built"); return end
        local function fault(m) bad = bad or (layout .. ": " .. m) end

        -- P1: never more cells than labels. Violation = unreachable screen.
        if c.used > c.capacity then
            fault("cells > capacity " .. c.used .. "/" .. c.capacity); return
        end
        -- P2: no cell may be left without a label.
        if c.truncated ~= 0 then fault("truncated " .. c.truncated); return end
        -- P3: labels unique across every display. A duplicate sends the
        -- pointer somewhere you did not ask for and looks like randomness.
        local seen = {}
        for _, p in ipairs(c.screens) do
            for _, cell in ipairs(p.cells) do
                if seen[cell.label] then fault("dup label " .. cell.label); return end
                seen[cell.label] = true
            end
        end
        -- P4: every cell centre lands inside its own display.
        for _, p in ipairs(c.screens) do
            if p.cols < 1 or p.rows < 1 then fault("empty grid"); return end
            for _, cell in ipairs(p.cells) do
                if cell.ax < p.frame.x or cell.ax > p.frame.x + p.frame.w
                or cell.ay < p.frame.y or cell.ay > p.frame.y + p.frame.h then
                    fault("cell centre outside its display"); return
                end
            end
        end
        -- P5: the grid must reach the far edges. A band of screen the
        -- labels never cover is invisible to every other check here.
        for _, p in ipairs(c.screens) do
            local last = p.cells[#p.cells]
            if not last then fault("a display got no cells"); return end
            if (p.frame.x + p.frame.w) - last.ax > p.cellW then
                fault("right edge unreachable"); return
            end
            if (p.frame.y + p.frame.h) - last.ay > p.cellH then
                fault("bottom edge unreachable"); return
            end
        end
        -- P6: typing a label lands the pointer on exactly that cell —
        -- probed on the LAST display, the one an off-by-one in the
        -- area-split would strand.
        local pn = c.screens[#c.screens]
        local probe = pn.cells[math.random(#pn.cells)]
        typeLabel(probe.label)
        if math.abs(MOUSE_AT.x - probe.ax) > 0.01
        or math.abs(MOUSE_AT.y - probe.ay) > 0.01 then
            fault("landed off-target on " .. probe.label); return
        end
        -- P7: the invariant, on every one of these layouts.
        local st, cv, md = grid.state ~= nil, anyCanvasVisible(), anyModalEntered()
        if not (st == cv and cv == md) then fault("invariant broken"); return end
        grid.hide("fuzz")
        if grid.state ~= nil or anyCanvasVisible() or anyModalEntered() then
            fault("not fully torn down"); return
        end
        worst = math.max(worst, c.used)
      end)
      if not okCase then bad = bad or ("case " .. iter .. " threw: " .. tostring(caseErr)) end
      if bad then break end
    end
    check(cases .. " random layouts: no crash, no hang, no unreachable cell, "
          .. "no duplicate label, no off-target landing, both far edges "
          .. "covered, invariant held", bad == nil, bad)
    check("the fuzzer actually exercised large grids", worst > 500, worst)
end
setScreens(ONE); loadModule()

-- =====================================================================
out("\n=== 14. THE EXPLORER — random action sequences, then shrinking ===\n")
-- =====================================================================
-- WHAT THIS IS, IN PLAIN TERMS. Every test above this line is a sequence
-- of actions I thought to write down. This one writes them itself.
--
-- The whole algorithm is three steps and fits in your head:
--
--   1. GENERATE. Pick random actions from the list a real person can
--      perform — open, type a letter, backspace, escape, nudge, click,
--      let the watchdog fire, change displays, hit the panic key — and
--      do them in a random order.
--   2. CHECK. After EVERY single action, assert the things that must be
--      true no matter what happened before. Not "did it do the right
--      thing" — that needs a human. "Is it in a state that is allowed."
--   3. SHRINK. When a sequence fails, delete steps one at a time and
--      keep any deletion that still fails. Repeat until nothing more can
--      go. A 40-step failure becomes a 3-step bug report.
--
-- STEP 3 IS THE ONE THAT MAKES THIS WORTH HAVING. Random testing without
-- shrinking hands you a 40-step trace and a shrug. With it you get the
-- shortest sequence that reproduces the fault, which is usually short
-- enough to read and fix directly.
--
-- WHAT IT CAN AND CANNOT DO. It cannot tell you the grid landed on the
-- RIGHT cell — that is a correctness question and needs the scripted
-- tests above. It CAN tell you the module got into a state it swears is
-- impossible, via a route neither of us would have thought to try. Those
-- are exactly the bugs that survive review.
do
    -- ---- the properties. Violating any of these is a bug, whatever the
    -- route taken to get there. P3 is the important one: it is the
    -- "never capture the keyboard invisibly" rule, stated as arithmetic.
    local function violation()
        local st = grid.state ~= nil
        local cv, md = anyCanvasVisible(), anyModalEntered()
        if not (st == cv and cv == md) then
            return ("P1 state=%s canvas=%s modal=%s"):format(
                tostring(st), tostring(cv), tostring(md))
        end
        if not st then
            if #grid.shown ~= 0 then return "P2 closed but " .. #grid.shown .. " canvases tracked as shown" end
            if grid.cross ~= nil then return "P2 closed but the badge survives" end
            for _, t in ipairs(TIMERS) do
                if not t.stopped then return "P2 closed but a watchdog is still ticking" end
            end
        else
            if grid.state.phase == "landed" and not (grid.cross and grid.cross.visible) then
                return "P3 capturing keys in landed mode with NO visible badge"
            end
            if grid.state.phase == "pick" and #grid.state.typed >= grid.labelLength then
                return "P4 a complete label was typed and it is still picking"
            end
            local live = 0
            for _, t in ipairs(TIMERS) do if not t.stopped then live = live + 1 end end
            if live > 1 then return "P5 " .. live .. " watchdogs live at once" end
        end
        return nil
    end

    -- ---- the actions a person can actually perform. Each is named, so a
    -- failing sequence is a list of strings you can read and replay.
    local ACT = {}
    local function act(name, fn) ACT[#ACT + 1] = { name = name, fn = fn } end
    act("show",      function() grid.show(false) end)
    act("showClick", function() grid.show(true) end)
    act("hide",      function() grid.hide("explorer") end)
    act("escape",    function()
        if grid.state and grid.state.phase == "pick" then grid.pickModal.binds["|escape"]()
        elseif grid.state then grid.landModal.binds["|escape"]() end end)
    act("backspace", function() if grid.state then pcall(grid.backspace) end end)
    for ch in ("asdfghjkl"):gmatch(".") do
        act("type:" .. ch, function()
            local fn = grid.pickModal.binds["|" .. ch]
            if fn then fn() end
        end)
    end
    -- Reaching landed mode by chance would take 9^3 aligned keystrokes, so
    -- it is offered directly. Without this the whole landed half of the
    -- state machine is explored roughly never.
    act("land", function()
        if not (grid.state and grid.state.phase == "pick" and grid.cache) then return end
        local label = grid.cache.screens[1].cells[1].label
        for c in label:sub(#grid.state.typed + 1):gmatch(".") do
            local fn = grid.pickModal.binds["|" .. c]
            if fn then fn() end
        end
    end)
    for _, k in ipairs({ "up", "down", "left", "right" }) do
        act("nudge:" .. k, function()
            local fn = grid.landModal.binds["|" .. k]
            if fn and grid.state and grid.state.phase == "landed" then fn() end end)
    end
    act("click",  function()
        local fn = grid.landModal.binds["|space"]
        if fn and grid.state and grid.state.phase == "landed" then fn() end end)
    act("dblclick", function()
        local fn = grid.landModal.binds["|2"]
        if fn and grid.state and grid.state.phase == "landed" then fn() end end)
    act("watchdog", function()
        local t = liveTimer(); if t then t.fn() end end)
    act("panic",   function() GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|X"]() end)
    act("screens", function()
        setScreens(TWO)
        if SCREEN_WATCHERS[1] then SCREEN_WATCHERS[1].fn() end
        setScreens(ONE) end)
    act("axOff",   function() AX_OK = false end)
    act("axOn",    function() AX_OK = true end)
    act("report",  function() pcall(_G.mouseGridReport) end)

    local byName = {}
    for _, a in ipairs(ACT) do byName[a.name] = a.fn end

    -- ---- replay a named sequence from a clean module. Returns the step
    -- and the reason on failure, so the shrinker can tell "still broken"
    -- from "broken differently".
    -- `src` is threaded through so the explorer can be pointed at a
    -- MUTATED module, which is the only honest way to prove the whole
    -- pipeline works. (It also means a planted bug cannot be monkey-
    -- patched in from outside: replay() reloads the module every time and
    -- would wipe it — which is exactly how the first version of the
    -- self-check below fooled itself into passing.)
    local function replay(seq, src)
        setScreens(ONE)
        AX_OK = true
        loadModule(src)
        for i, name in ipairs(seq) do
            local ok, err = pcall(byName[name])
            if not ok then return i, name .. " threw: " .. tostring(err) end
            local v = violation()
            if v then return i, v end
        end
        return nil
    end

    -- ---- the shrinker. Greedy deletion: try removing each step; keep the
    -- removal if the sequence still fails. Repeat until a full pass
    -- removes nothing. Simple, and it is what turns a wall of noise into
    -- something you can act on.
    local function shrink(seq, src)
        local changed = true
        while changed and #seq > 1 do
            changed = false
            local i = 1
            while i <= #seq do
                local cand = {}
                for j, n in ipairs(seq) do if j ~= i then cand[#cand + 1] = n end end
                if #cand > 0 and replay(cand, src) then
                    seq = cand ; changed = true
                else
                    i = i + 1
                end
            end
        end
        return seq
    end

    math.randomseed(4711)
    local SEQS, LEN = 400, 40
    local found, steps = nil, 0
    for _ = 1, SEQS do
        local seq = {}
        for _ = 1, LEN do seq[#seq + 1] = ACT[math.random(#ACT)].name end
        local at, why = replay(seq)
        steps = steps + (at or LEN)
        if at then
            local minimal = shrink(seq)
            local _, minWhy = replay(minimal)
            found = ("%s  ←  %s"):format(minWhy or why, table.concat(minimal, " → "))
            break
        end
    end
    check(SEQS .. " random action sequences (" .. steps .. " actions): the "
          .. "module never reached a state it forbids — not locked out, not "
          .. "stranded, never capturing keys without a visible badge",
          found == nil, found)

    -- ---- DOES THE EXPLORER ACTUALLY WORK? ----------------------------
    -- 400 green sequences prove nothing unless the machinery can fail. So
    -- the whole pipeline — generate, check, shrink — is run against a
    -- module deliberately broken in the exact way that matters.
    do
        check("a legal sequence is judged legal", replay({ "show", "type:a" }) == nil)

        -- 1. Do the PROPERTIES bite? Put the module into each forbidden
        --    state by hand and confirm violation() names it.
        setScreens(ONE); loadModule(); grid.show(false)
        grid.state = nil                            -- stranded: sheet up, keys freed
        check("P1 catches a teardown that clears the state and leaves the "
              .. "overlay on screen", (violation() or ""):find("P1", 1, true) ~= nil,
              violation())
        -- P3 earns its place only where P1 cannot see the fault: landed
        -- mode with the badge gone but SOMETHING still on screen, so the
        -- state/canvas/modal counts all agree and only the badge rule
        -- notices that what you can see is not what is capturing keys.
        loadModule(); grid.show(false); typeLabel("aaa")
        pcall(function() grid.cross:delete() end)
        grid.cross = nil
        grid.cache.screens[1].gridCanvas:show()     -- the grid, not the badge
        check("P3 catches landed mode with no badge in the one case P1 "
              .. "cannot see — something else is on screen, so the counts "
              .. "agree and only the badge rule objects",
              (violation() or ""):find("P3", 1, true) ~= nil, violation())

        -- 2. Does the SEARCH find it, and does the SHRINKER reduce it?
        --    A module whose hide() no longer puts the canvases away is the
        --    lock-out shape, reachable from a two-step sequence.
        local broken = src:gsub("        hideAllShown%(%)\n        pcall%(function%(%) if grid%.cross",
                                "        pcall(function() if grid.cross", 1)
        check("the mutation anchor still matches the shipped file", broken ~= src)
        math.randomseed(99)
        local hit, minimal = nil, nil
        for _ = 1, 40 do
            local seq = {}
            for _ = 1, LEN do seq[#seq + 1] = ACT[math.random(#ACT)].name end
            if replay(seq, broken) then
                hit = seq
                minimal = shrink(seq, broken)
                break
            end
        end
        check("🔎 the explorer FINDS a broken teardown on its own, without "
              .. "being told where to look", hit ~= nil)
        if hit and minimal then
            out(("      planted a broken teardown → found in a %d-step "
                 .. "sequence → shrank to %d: %s\n"):format(
                 #hit, #minimal, table.concat(minimal, " → ")))
        end
        check("✂️ and the shrinker cuts the "
              .. (hit and #hit or 0) .. "-step failure down to "
              .. (minimal and #minimal or 0) .. " steps — that reduction is "
              .. "the whole reason this is worth running",
              minimal ~= nil and #minimal <= 4,
              minimal and table.concat(minimal, " → "))
    end
end
setScreens(ONE); loadModule()

-- =====================================================================
realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
