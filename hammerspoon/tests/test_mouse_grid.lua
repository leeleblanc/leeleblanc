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
check("⇪M is claimed", HYPER["|m"] ~= nil)
check("⇪⇧M is claimed for click-on-arrival", HYPER["shift|m"] ~= nil)
check("the PANIC key is a plain chord, NOT a ⇪ shortcut — if ⇪ is what "
      .. "broke, a ⇪ panic key cannot be pressed",
      GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|M"] ~= nil)
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

out("   -- ⇪⇧M clicks on arrival --\n")
loadModule(); grid.show(true); typeLabel("aaa")
checkInv("click on arrival")
check("⇪⇧M clicks the moment the label completes", #CLICKS == 1)
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
GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|M"]()
checkInv("panic from pick")
check("⌃⌥⌘⇧M clears a grid mid-type", grid.state == nil and not anyCanvasVisible())
loadModule(); grid.show(false); typeLabel("aaa")
GLOBAL_HOTKEYS["alt+cmd+ctrl+shift|M"]()
checkInv("panic from landed")
check("⌃⌥⌘⇧M clears the landed badge too", grid.state == nil and grid.cross == nil)

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
check("pressing ⇪M while it is up puts it away rather than stacking a "
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
    check("hs-doctor.sh expects the new module count",
          dr:find("expect 19", 1, true) ~= nil)

    local f4 = io.open(HS .. "/INSTALL.md", "r")
    local inst = f4 and f4:read("*a") or ""
    if f4 then f4:close() end
    check("INSTALL.md's module count matches what ships",
          inst:find("19 files", 1, true) ~= nil)
    check("INSTALL.md's confirmation table includes ⇪M, so a fresh install "
          .. "is actually verified", inst:find("⇪M", 1, true) ~= nil)
end

-- =====================================================================
realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
