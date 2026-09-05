-- =====================================================================
-- test_shortcut_hints — the card after a ⇪ key (6.163.0)
-- =====================================================================
-- Drives the REAL modules/shortcut_hints.lua against a stubbed hs: the
-- rows a press resolves to, the card's existence, the dismiss tap
-- observing without consuming, the 10-second fade, the off switch, the
-- pause switch, the latch touch, and the source sentries.
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local PRINTED = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- ---- a stub hs -------------------------------------------------------
local CANVASES, TIMERS, TAPS = {}, {}, {}
local NOW = 1000
local function newCanvas(rect)
    local c = { rect = rect, shown = false, deleted = false, els = {}, hidden = nil,
                mouse = nil, activating = nil, lvl = nil }
    function c:level(l) self.lvl = l; return self end
    function c:behaviorAsLabels(t) self.beh = t; return self end
    function c:clickActivating(b) self.activating = b; return self end
    function c:canvasMouseEvents(a, b, cc, d) self.mouse = { a, b, cc, d }; return self end
    function c:alpha(a) self.a = a; return self end
    function c:replaceElements(e) self.els = e; return self end
    function c:show() self.shown = true; return self end
    function c:hide(secs) self.hidden = secs or 0; return self end
    function c:delete() self.deleted = true; return self end
    function c:frame(r) if r then self.rect = r end; return self.rect end
    CANVASES[#CANVASES + 1] = c
    return c
end
_G.hs = {
    canvas = { new = newCanvas, windowLevels = { overlay = 101, mainMenu = 24 } },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, live = true }
            function t:stop() self.live = false; return self end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    eventtap = {
        event = { types = { keyDown = 10, keyUp = 11, leftMouseDown = 1, rightMouseDown = 3 },
                  properties = { keyboardEventAutorepeat = 8 } },
        new = function(types, fn)
            local t = { types = types, fn = fn, on = false }
            function t:start() self.on = true; return self end
            function t:stop() self.on = false; return self end
            function t:isEnabled() return self.on end
            TAPS[#TAPS + 1] = t
            return t
        end,
    },
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 25, w = 2560, h = 1385 } end }
    end, allScreens = function() return {} end },
}
local function ev(t, code, rep)
    return { getType = function() return t end, getKeyCode = function() return code end,
             getProperty = function() return rep or 0 end }
end
local function drain()
    local due = TIMERS; TIMERS = {}
    table.sort(due, function(a, b) return a.secs < b.secs end)
    for _, t in ipairs(due) do if t.live then NOW = NOW + t.secs; t.fn() end end
end

-- ---- init.lua globals the module reads ---------------------------------
_G.panelLevel = function(name) return name == "hint" and 28 or 24 end
_G.showCanvasSafely = function(c) c:show(); return true end
_G.hyperTouchCalls = 0
_G.hyperTouch = function() _G.hyperTouchCalls = _G.hyperTouchCalls + 1 end
_G.hyperActive = false
_G.hsPaused = false
_G.typingInjection = function() return false end
_G.moduleCheatsheets = {
    { title = "✅ TASK FORM", entries = { { "⇪T", "Open the form" } } },
    { title = "🪟 WINDOW ARRANGER", entries = { { "⇪← / ⇪→", "Left / right half" }, { "⇪↑", "Fill screen" } } },
    { title = "📸 SCREENSHOTS", entries = { { "⇪4", "Capture" }, { "⇪⇧4", "Panel" } } },
}
-- what hyperBind filed on this Mac
_G.hyperBound = {
    t = "alt+cmd+ctrl+t", a = "alt+cmd+ctrl+a", b = "alt+cmd+ctrl+b",
    c = "alt+cmd+ctrl+c", l = "alt+cmd+ctrl+l",
    left = "alt+ctrl+left", right = "alt+ctrl+right", up = "alt+ctrl+f",
    ["4"] = "screenshot — save + copy",                 -- ⇪⇧4 NOT bound here
    ["shift+3"] = "mouse follows focus",                 -- a Mouse key alone
    ["shift+1"] = "pause Hammerspoon",
    q = "chord", g = "chord", ["shift+g"] = "chord",   -- unclaimed keys, forwarded
    ["shift+8"] = "something new with no group yet",
}
_G.hsPauseCombo = "shift+1"

local PROVIDED = {}
local core = {
    provide = function(name, fn) PROVIDED[name] = fn end,
    resolveBaseScreen = function() return hs.screen.mainScreen() end,
}

local M = assert(loadfile(HS .. "/modules/shortcut_hints.lua"))()
check("module contract: name/order/family/cheatsheet/setup",
      type(M.name) == "string" and type(M.order) == "number" and M.family == "config"
      and type(M.cheatsheet) == "table" and type(M.setup) == "function")
M.setup(core)
local hint = M.config
check("M.config is the live table (settings override lands)", type(hint) == "table" and hint.enabled == true)
check("the hook is published", type(_G.shortcutHint) == "function")
check("the report is a global AND a service",
      type(_G.shortcutHintsReport) == "function" and PROVIDED["shortcutHints.report"] ~= nil)

-- =====================================================================
out("\n=== 1. ⇪T resolves to the OTHER Asana keys ===\n")
-- =====================================================================
local rows, group = hint.rowsFor("t")
check("group is Asana", group == "Asana", group)
local labels = {}
for _, r in ipairs(rows or {}) do labels[#labels + 1] = r[1] end
check("the four siblings, sorted, and NOT ⇪T itself",
      table.concat(labels, " ") == "⇪A ⇪B ⇪C ⇪L", table.concat(labels, " "))
check("descriptions come from the core rows when no module owns the key",
      rows and rows[1][2] == "Format Asana URL from clipboard", rows and rows[1][2])
check("labels: shift+t → ⇪⇧T, left → ⇪←, pad1 → ⇪pad1, space → ⇪space",
      M.labelOf("shift+t") == "⇪⇧T" and M.labelOf("left") == "⇪←"
      and M.labelOf("pad1") == "⇪pad1" and M.labelOf("space") == "⇪space")

-- =====================================================================
out("\n=== 2. The card: exists, sits bottom-right, never takes focus ===\n")
-- =====================================================================
check("a press shows the card", _G.shortcutHint("t", "alt+cmd+ctrl+t") == true)
local c = CANVASES[#CANVASES]
check("...drawn, shown, on the hint rung", c and c.shown and c.lvl == 28, c and c.lvl)
check("...bottom-right of the base screen",
      c and c.rect.x + c.rect.w == 2560 - hint.margin
      and c.rect.y + c.rect.h == 25 + 1385 - hint.margin, c and (c.rect.x .. "," .. c.rect.y))
check("...click-through and non-activating",
      c and c.activating == false and c.mouse and c.mouse[1] == false)
check("...over full-screen apps and every Space",
      c and c.beh and c.beh[1] == "canJoinAllSpaces" and c.beh[2] == "fullScreenAuxiliary")
local text = {}
for _, e in ipairs(c and c.els or {}) do if e.type == "text" then text[#text + 1] = e.text end end
local joined = table.concat(text, " | ")
check("...names the group and the four keys", joined:find("ASANA", 1, true) and joined:find("⇪A", 1, true)
      and joined:find("⇪L", 1, true) and not joined:find("⇪T", 1, true), joined)
check("a dismiss tap exists and is running only while the card is up",
      hint.tap and hint.tap.on == true)
check("the hold timer is HELD in the module table", hint.holdTimer ~= nil)

-- =====================================================================
out("\n=== 3. Any key or click dismisses — observed, never consumed ===\n")
-- =====================================================================
_G.hyperActive = true
NOW = NOW + 1                                            -- past the grace window
local consumed = hint.tap.fn(ev(10, 2))
check("a keyDown returns false (Esc still reaches the picker)", consumed == false)
check("...and the card is gone", hint.canvas == nil and c.deleted == true)
check("...and the tap stopped", hint.tap.on == false)
check("...and a key seen under ⇪ touched the latch watchdog", _G.hyperTouchCalls == 1)
check("...counted", hint.dismissed == 1)
_G.hyperActive = false
_G.shortcutHint("t", "x")
local c2 = CANVASES[#CANVASES]
NOW = NOW + 1
check("a click dismisses too, unconsumed",
      hint.tap.fn(ev(1)) == false and c2.deleted)
check("the tap listens for key, left and right clicks",
      #hint.tap.types == 3 and hint.tap.types[1] == 10)

-- what must NOT dismiss
_G.shortcutHint("t", "x")
local c2b = CANVASES[#CANVASES]
check("within the grace window a shortcut's own synthetic input is ignored",
      hint.tap.fn(ev(10, 2)) == false and not c2b.deleted)
NOW = NOW + 1
check("Caps Lock itself (F18) never dismisses", hint.tap.fn(ev(10, 79)) == false and not c2b.deleted)
check("a key auto-repeat never dismisses", hint.tap.fn(ev(10, 2, 1)) == false and not c2b.deleted)
check("...but a real key does", hint.tap.fn(ev(10, 2)) == false and c2b.deleted)

-- =====================================================================
out("\n=== 4. Ten seconds, then a fade ===\n")
-- =====================================================================
_G.shortcutHint("t", "x")
local c3 = CANVASES[#CANVASES]
check("the hold is 10 seconds", hint.holdTimer and hint.holdTimer.secs == 10, hint.holdTimer and hint.holdTimer.secs)
drain()
check("after the hold the canvas fades (hide with a duration) and a fade timer is held",
      c3.hidden == hint.fadeSecs and hint.fadeTimer ~= nil, c3.hidden)
check("...the tap stopped at the start of the fade", hint.tap.on == false)
drain()
check("...and then it is deleted and forgotten", c3.deleted and hint.canvas == nil and hint.faded == 1)

-- a new press mid-fade replaces the old card cleanly
_G.shortcutHint("t", "x")
local c4 = CANVASES[#CANVASES]
_G.shortcutHint("left", "y")
local c5 = CANVASES[#CANVASES]
check("a second press replaces the first card (one at a time)", c4.deleted and not c5.deleted and hint.canvas == c5)
hint.hide()

-- =====================================================================
out("\n=== 5. When there is nothing to say, nothing is drawn ===\n")
-- =====================================================================
local before = #CANVASES
check("a lone key in its group (⇪⇧3, Mouse) draws no card",
      _G.shortcutHint("shift+3", "mouse follows focus") == false and #CANVASES == before)
check("...and the report says why", hint.last and tostring(hint.last.why):find("nothing else", 1, true) ~= nil,
      hint.last and hint.last.why)
check("an unmapped combo draws no card", _G.shortcutHint("shift+9", "x") == false and #CANVASES == before)
check("a forwarded chord never hints", _G.shortcutHint("q", "chord") == false and #CANVASES == before)
check("the pause switch never hints", _G.shortcutHint("shift+1", "pause Hammerspoon") == false and #CANVASES == before)
local rg = hint.rowsFor("6")
check("forwarded chords are never siblings (⇪G/⇪⇧G are chords here → This Mac has none)", rg == nil)
_G.hsPaused = true
check("paused: no card", _G.shortcutHint("t", "x") == false and #CANVASES == before)
_G.hsPaused = false
hint.enabled = false
check("settings off: no card", _G.shortcutHint("t", "x") == false and #CANVASES == before)
hint.enabled = true
-- only keys BOUND on this Mac are listed: ⇪4's sibling ⇪⇧4 is unbound here
local r4, g4 = hint.rowsFor("4")
check("only bound siblings are listed (⇪⇧4 unbound → Screenshots has none)", r4 == nil, g4)
-- Windows: the arranger keys plus the ⌥Tab extra, described from the cheat sheet
local rw = hint.rowsFor("left")
local seen = {}
for _, r in ipairs(rw or {}) do seen[r[1]] = r[2] end
check("Windows after ⇪←: ⇪→ and ⇪↑ from the sheet, ⌥Tab as an extra, not ⇪←",
      seen["⇪→"] == "Window arranger: Left / right half" and seen["⇪↑"] == "Window arranger: Fill screen"
      and seen["⌥Tab"] ~= nil and seen["⇪←"] == nil)
-- the cap
hint.maxRows = 1
local rr, _, more = hint.rowsFor("t")
check("more than maxRows is cut, and the overflow is counted", #rr == 1 and more == 3, more)
hint.maxRows = 9

-- =====================================================================
out("\n=== 6. The report ===\n")
-- =====================================================================
local rep = _G.shortcutHintsReport()
check("report names the last press, the counts and the unmapped bound keys",
      rep:find("SHORTCUT HINTS", 1, true) and rep:find("shown", 1, true)
      and rep:find("no group : ⇪⇧8", 1, true) ~= nil   -- bound, unmapped
      and rep:find("⇪Q", 1, true) == nil                 -- a chord is not "unmapped"
      and rep:find("last     :", 1, true), rep)
-- descriptions: continuation rows fold in, terse ones get a subject
_G.moduleCheatsheets[#_G.moduleCheatsheets + 1] =
    { title = "🔤 AUTOCORRECT (⇪S)", entries = { { "⇪S", "Toggle on/off" }, { "", "and learn" } } }
_G.hyperBound.s = "autocorrect"; _G.hyperBound.z = "autocorrect undo"
local rs = hint.rowsFor("z")
check("a terse description gets its sheet group's subject, continuation rows folded in",
      rs and rs[1][1] == "⇪S" and rs[1][2] == "Autocorrect: Toggle on/off and learn", rs and rs[1][2])
check("subjectOf strips emoji and the parenthetical",
      M.subjectOf("✂️ TEXT EXPANDER (Alfred snippets)") == "Text expander", M.subjectOf("✂️ TEXT EXPANDER (Alfred snippets)"))

-- =====================================================================
out("\n=== 7. Source sentries ===\n")
-- =====================================================================
local f = io.open(HS .. "/modules/shortcut_hints.lua", "r")
local src = f:read("*a"); f:close()
local code = src:gsub("%-%-[^\n]*", "")
check("no hs.window.filter", not code:find("hs%.window%.filter"))
check("the tap starts with the pause check",
      code:find("local function onEvent%(ev%)\n%s*if _G%.hsPaused then return false end") ~= nil)
check("the card's screen comes from mainScreen, never an AX read", not code:find("resolveBaseScreen"))
check("the tap stands down during an injection", code:find("_G%.typingInjection") ~= nil)
check("keys under ⇪ touch the latch watchdog", code:find("_G%.hyperTouch%(%)") ~= nil)
check("no bare hs.timer statement (every timer held)", not code:find("\n%s*hs%.timer%.do"))
check("no claimEscape, no _G.choosers, no draggable (a display, not a dialog)",
      not code:find("claimEscape") and not code:find("_G%.choosers") and not code:find("makeCanvasDraggable"))
local rt = io.open(HS .. "/tools/run-tests.sh", "r"); local rts = rt:read("*a"); rt:close()
check("run-tests.sh names this suite", rts:find("test_shortcut_hints", 1, true) ~= nil)
local ini = io.open(HS .. "/init.lua", "r"); local inis = ini:read("*a"); ini:close()
check("BASE names the module", inis:find('"shortcut_hints",', 1, true) ~= nil)
check("hyperBind calls the hook after the shortcut, nil-guarded and pcall'd",
      inis:find("if _G%.shortcutHint then pcall%(_G%.shortcutHint, combo, source%) end") ~= nil)
local cx = io.open(HS .. "/core/coexist.lua", "r"); local cxs = cx:read("*a"); cx:close()
check("the panel ladder has the hint rung", cxs:find("\n%s*hint%s*=%s*4,") ~= nil)

print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, fl in ipairs(failures) do io.write("  ❌ " .. fl .. "\n") end
os.exit(fail == 0 and 0 or 1)
