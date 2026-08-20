-- =====================================================================
-- test_editor_picker.lua — right ⌥⌥ opens the editors; ⌘C⌘V and the LEFT
-- ⌥ do not
-- =====================================================================
--     lua5.4 test_editor_picker.lua [/path/to/hammerspoon]
--
-- Executes modules/editor_picker.lua against a stubbed hs and drives the
-- REAL event-tap callback with synthetic modifier and key events.
--
-- The section that matters most is 2. A double-tap watcher that reads
-- only flagsChanged cannot tell ⌘C-then-⌘V from ⌘ tapped twice, and
-- copy-then-paste is one of the most common things anybody does at a
-- keyboard — so a picker that opened on it would be unusable, and it
-- would be unusable in a way that looks like a haunting rather than a
-- bug. Every one of those checks fails if the keyDown branch is removed.
--
-- Section 2f is the side machinery from 6.121.0. The gesture settled on
-- right ⌥⌥ in 6.122.0 — Alfred took right ⌃⌃, so neither program has to
-- share a key — and the checks there still decide whether the RIGHT one
-- is what fires. They fail if the side is read from the wrong edge of the
-- press, if a wrong-side key is merely ignored instead of cancelling, or
-- if a press whose side cannot be read is GUESSED.

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

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- the stub Mac ------------------------------------------------------
local NOW      = 1000.0          -- wall clock, moved by hand
local TAP      = nil             -- the one keyboard tap the module makes
local ALERTS   = {}
local CLIP     = nil             -- what reached the pasteboard
local MODS     = {}              -- what checkKeyboardModifiers reports
local CHOOSERS = {}
local SHOWN    = {}              -- chooser:show() / core.showPopup calls

-- 🖱 THE MOUSE TYPES ARE REAL STUB ENTRIES, not decoration. 6.124.0 put
-- the gesture on ⌃, where ⌃-click is the Mac right-click and ⌃-scroll is
-- screen zoom, so the module watches them to CANCEL a half-made gesture.
-- A stub missing them would silently drop those types from WATCHED_TYPES
-- and section 2i would be testing nothing.
local TYPES = {
    keyDown = 10, flagsChanged = 12,
    leftMouseDown = 1, rightMouseDown = 3, otherMouseDown = 25,
    scrollWheel = 22,
}

-- The real macOS keycodes. The module reads hs.keycodes.map and falls
-- back to these same numbers, so the stub carries the map to prove the
-- lookup is wired — section 2f moves one of them to prove it is USED.
local KC = {
    cmd = 55, rightcmd = 54, alt = 58, rightalt = 61,
    ctrl = 59, rightctrl = 62, shift = 56, rightshift = 60,
}
local L_CMD, R_CMD          = KC.cmd, KC.rightcmd
local L_ALT, R_ALT          = KC.alt, KC.rightalt

hs = {
    keycodes = { map = KC },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(_, fn) return { stop = function() end, fn = fn } end,
    },
    eventtap = {
        event = { types = TYPES },
        new = function(types, cb)
            TAP = { types = types, cb = cb, started = false }
            function TAP:start() self.started = true return self end
            function TAP:stop()  self.started = false end
            return TAP
        end,
        checkKeyboardModifiers = function() return MODS end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(t) CLIP = t return true end },
    chooser = {
        new = function(cb)
            local c = { cb = cb, rows = nil, placeholder = nil }
            function c:choices(r) self.rows = r return self end
            function c:placeholderText(t) self.placeholder = t return self end
            function c:searchSubText() return self end
            function c:width() return self end
            function c:show() SHOWN[#SHOWN + 1] = self return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide   = function(n, f) PROVIDED[n] = f end,
    showPopup = function(c) SHOWN[#SHOWN + 1] = c end,
}

-- ---- synthetic events --------------------------------------------------
-- 🚨 THE DEFAULT KEYCODE IS THE RIGHT ⌘, because that is what 6.121.0
-- watches and every check written before it meant "a ⌘ tap this config
-- accepts". Pass `code` to say otherwise; pass false to build an event
-- with NO readable keycode, which is the third case the module has to
-- handle and the one it must refuse rather than guess at.
local function flagsEvent(flags, code)
    local e = { getType = function() return TYPES.flagsChanged end,
                getFlags = function() return flags or {} end }
    if code ~= false then
        e.getKeyCode = function() return code or R_CMD end
    end
    return e
end
local function keyEvent()
    return { getType = function() return TYPES.keyDown end,
             getFlags = function() return {} end }
end
-- A pointer event carries no keycode at all, which is the point: it can
-- only ever be an intruder, never half a gesture.
local function mouseEvent(name)
    return { getType = function() return TYPES[name] end,
             getFlags = function() return {} end }
end

-- ---- load it -----------------------------------------------------------
local chunk = assert(loadfile(HS .. "/modules/editor_picker.lua"))
local M = chunk()
_G.editors = {}
M.setup(CORE)
local ep = _G.editorPicker
M.warm(CORE)

out("\n=== 1. it loads, binds and starts ===\n")
check("the module returns a table with a name", M.name == "Editor Picker")
check("it declares a family", M.family == "text")
check("it publishes _G.editorPicker", type(ep) == "table")
-- ⌨️ 6.125.0 — THE PICKER BINDS NO ⇪ KEY AT ALL, and this is the check
-- that says so. LL asked for ⇪⇧Z back for something else; a suite that
-- merely stopped naming the old key would let a stray binding come back
-- and take it again without a word.
check("🚨 the picker binds NO ⇪ key — ⇪⇧Z is free and stays free",
      BOUND["shift+z"] == nil)
check("…and no other ⇪ key either — the tap-free way in is ⇪space, so a "
      .. "binding appearing here means a key was quietly spent", (function()
    local bound = {}
    for combo, rec in pairs(BOUND) do
        if rec and rec.src == "editor picker" then bound[#bound + 1] = combo end
    end
    if #bound > 0 then
        table.sort(bound)
        return false, table.concat(bound, ", ")
    end
    return true
end)())
check("ep.key is nil, which is what the guard at the binding reads",
      ep.key == nil)
-- 🚨 THE ROW AND THE RUN MAP KEY ARE TWO HALVES OF ONE JOIN.
-- unified_search attaches a service to a row BY ITS KEY CELL, so ["🗂"]
-- is runnable only while a row spells it exactly that way. verifyTools
-- catches the drift at runtime; this catches it before it ships.
check("the sheet carries a 🗂 row for the keyless route",
      M.cheatsheet.entries[2] ~= nil
      and M.cheatsheet.entries[2][1] == "🗂",
      M.cheatsheet.entries[2] and M.cheatsheet.entries[2][1])
-- ⌨️ AND THE KEY CAN COME BACK IN ONE LINE, which is what the header
-- promises. A setting nobody exercises is a setting that has quietly
-- stopped working — ep.tapSide's side machinery is kept honest the same
-- way in section 2f.
check("with no key, wayIn() names ⇪space",
      ep.wayIn() == "⇪space → \"editor\"", ep.wayIn())
check("…and setting ep.key names a real ⇪ chord again", (function()
    local saved = ep.key
    ep.key = "z"
    local s = ep.wayIn()
    ep.key = saved
    return s == "⇪⇧Z", s
end)())
check("warm() started the tap", TAP ~= nil and TAP.started == true)
check("the tap watches flagsChanged AND keyDown", (function()
    if not TAP then return false end
    local wantsFlags, wantsKeys = false, false
    for _, t in ipairs(TAP.types) do
        if t == TYPES.flagsChanged then wantsFlags = true end
        if t == TYPES.keyDown      then wantsKeys  = true end
    end
    return wantsFlags and wantsKeys
end)())
-- 🚨 AND THE POINTER TYPES, which is what makes ⌃ survivable as a
-- gesture. Drop any one of these from the module and a right-click stops
-- cancelling — see section 2i for what that costs.
check("…and every pointer event that can land mid-press", (function()
    if not TAP then return false end
    local seen = {}
    for _, t in ipairs(TAP.types) do seen[t] = true end
    for _, name in ipairs({ "leftMouseDown", "rightMouseDown",
                            "otherMouseDown", "scrollWheel" }) do
        if not seen[TYPES[name]] then return false, name end
    end
    return true
end)())
check("no event name was silently dropped", #ep.MISSING_TYPES == 0,
      table.concat(ep.MISSING_TYPES, ","))
check("three services are published",
      PROVIDED["editors.show"] and PROVIDED["editors.list"]
      and PROVIDED["editors.report"])
-- 🚨 THE SHIPPED GESTURE, PINNED (6.124.0). LL asked for a double
-- Control and moved Alfred off ⌃⌃ to make room, having established by
-- test that "Alfred fires on either Control" — so no side split was
-- available and none is attempted. A release that quietly moved this
-- back onto ⌘ or ⌥ would break a gesture he has retrained onto, and
-- nothing else in the file would notice.
check("the shipped gesture is ⌃, tapped twice, either side",
      ep.tapMod == "ctrl" and ep.tapSide == "either",
      tostring(ep.tapMod) .. "/" .. tostring(ep.tapSide))
check("…and it names itself that way", ep.gesture() == "⌃⌃", ep.gesture())
check("…and the cheat sheet says so too",
      M.cheatsheet.title:find("⌃⌃", 1, true) ~= nil
      and M.cheatsheet.entries[1][1] == "⌃⌃", M.cheatsheet.title)
-- ⚠️ AND IT MUST NOT BE SIDE-RESTRICTED, on purpose. Apple builds no
-- keyboard with a right ⌃, so tapSide = "right" here would work on LL's
-- external board and die silently the moment he opens the laptop.
check("…and no side is demanded of a key Apple does not ship",
      ep.tapSide == "either", ep.tapSide)

-- =====================================================================
out("\n=== 2. 🚨 ⌘C THEN ⌘V DOES NOT OPEN THE PICKER ===\n")
-- =====================================================================
-- The whole reason this tap subscribes to keyDown. Delete the keyDown
-- branch of the callback and every check in this section fails.
--
-- ⚠️ RUN DELIBERATELY ON ⌘, EITHER SIDE — the 6.116.0 gesture. Nothing in
-- this section is about WHICH key starts a gesture; it is about what
-- happens between the two taps, and that is the same argument whatever
-- the modifier. Reading these checks against ⌘ is reading them as they
-- were written. The shipped right ⌥⌥ is pinned in section 1 and taken
-- apart in 2f.
local function feed(e) return TAP.cb(e) end
local function tick(dt) NOW = NOW + dt end
ep.tapMod, ep.tapSide = "cmd", "either"
ep.resolveCodes()

local function reset()
    ep.resetTapState()
    SHOWN = {}
    ep.fires = 0
end

-- ⌘ down · c · ⌘ up · ⌘ down · v · ⌘ up, all of it fast
reset()
feed(flagsEvent({ cmd = true })); tick(0.04)
feed(keyEvent());                 tick(0.02)
feed(flagsEvent({}));             tick(0.05)
feed(flagsEvent({ cmd = true })); tick(0.04)
feed(keyEvent());                 tick(0.02)
feed(flagsEvent({}))
check("⌘C then ⌘V did NOT fire", ep.fires == 0, ep.fires)
check("…and opened nothing", #SHOWN == 0, #SHOWN)

-- A key pressed BETWEEN two otherwise-clean taps also cancels: ⌘-tap,
-- type a letter, ⌘-tap is two gestures with a sentence between them.
reset()
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({})); tick(0.05)
feed(keyEvent());                 tick(0.05)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("a keystroke between the taps cancels the gesture", ep.fires == 0, ep.fires)

-- ⌘⇧ is a chord, not a tap, even with no key in it (⌘⇧4 arrives that way
-- when the screenshot is taken by the system before the key reaches us).
reset()
feed(flagsEvent({ cmd = true, shift = true })); tick(0.05)
feed(flagsEvent({})); tick(0.05)
feed(flagsEvent({ cmd = true, shift = true })); tick(0.05)
feed(flagsEvent({}))
check("⌘⇧ tapped twice does not fire", ep.fires == 0, ep.fires)

-- ⇧ joining a ⌘ that is already down dirties it too.
reset()
feed(flagsEvent({ cmd = true })); tick(0.03)
feed(flagsEvent({ cmd = true, shift = true })); tick(0.03)
feed(flagsEvent({})); tick(0.05)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("⇧ joining a held ⌘ dirties that tap", ep.fires == 0, ep.fires)

-- Holding ⌘ (reading a menu) is not a tap however clean it is.
reset()
feed(flagsEvent({ cmd = true })); tick(1.2); feed(flagsEvent({})); tick(0.05)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("a HELD ⌘ then a tap does not fire", ep.fires == 0, ep.fires)

-- Two clean taps too far apart are two taps, not a gesture.
reset()
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({})); tick(2.0)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("two taps a second apart do not fire", ep.fires == 0, ep.fires)

out("\n=== 2b. …and two clean taps DO ===\n")
reset()
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({})); tick(0.10)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("⌘⌘ fired exactly once", ep.fires == 1, ep.fires)
check("…and the picker was shown", #SHOWN == 1, #SHOWN)

-- A third tap must not fire again off the back of the second: the pair
-- is consumed, so ⌘⌘⌘ is one picker, not two.
reset()
for _ = 1, 3 do
    feed(flagsEvent({ cmd = true })); tick(0.05)
    feed(flagsEvent({})); tick(0.10)
end
check("⌘⌘⌘ fires once, not twice", ep.fires == 1, ep.fires)

out("\n=== 2c. it never eats a keystroke, on any path ===\n")
local returns = {}
reset()
returns[#returns + 1] = feed(flagsEvent({ cmd = true }))
returns[#returns + 1] = feed(keyEvent())
returns[#returns + 1] = feed(flagsEvent({}))
returns[#returns + 1] = feed(flagsEvent({ cmd = true }))
returns[#returns + 1] = feed(flagsEvent({}))
returns[#returns + 1] = feed({ getType = function() error("boom") end })
local allFalse = true
for _, r in ipairs(returns) do if r ~= false then allFalse = false end end
check("every path returns false, including the throwing one", allFalse)
check("a throw was counted rather than swallowed", ep.tapFailures >= 1,
      ep.tapFailures)

out("\n=== 2d. it stands down for injection and for ⇪ ===\n")
reset()
_G.typingInjection = function() return true end
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({})); tick(0.10)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("synthetic keys cannot assemble the gesture", ep.fires == 0, ep.fires)
_G.typingInjection = function() return false end

reset()
_G.hyperActive = true
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({})); tick(0.10)
feed(flagsEvent({ cmd = true })); tick(0.05); feed(flagsEvent({}))
check("⇪'s synthetic ⌘⇧⌃⌥ cannot assemble it either", ep.fires == 0, ep.fires)
_G.hyperActive = nil

out("\n=== 2e. repeated throws switch the tap off, not the keyboard ===\n")
ep.tapFailures = 0
local bad = { getType = function() error("boom") end }
local lastReturn
for _ = 1, ep.failLimit do lastReturn = feed(bad) end
check("the tap stopped itself", ep.tapRunning == false)
check("…and still passed that keystroke through", lastReturn == false)
check("it said so in the Console", (function()
    for _, l in ipairs(printed) do
        if l:find("switched off", 1, true) then return true end
    end
    return false
end)())
-- 🚨 THE WAY-IN SENTENCE IS THE POINT OF THE MESSAGE, not decoration.
-- It prints at the one moment the reader has just lost the gesture, so it
-- has to name a route that actually exists — which is why ep.wayIn()
-- builds it from ep.key instead of four hard-coded copies of a key that
-- went away in 6.125.0.
check("…and named ⇪space as the way in", (function()
    for _, l in ipairs(printed) do
        if l:find("⇪space → \"editor\" still opens", 1, true) then return true end
    end
    return false
end)())
check("…and did NOT name the key it gave back", (function()
    for _, l in ipairs(printed) do
        if l:find("⇪⇧Z", 1, true) then return false, l end
    end
    return true
end)())
TAP.started = true ; ep.tapRunning = true ; ep.tapFailures = 0

-- =====================================================================
out("\n=== 2f. 🚨 ONE KEY, AND IT IS THE RIGHT ONE ===\n")
-- =====================================================================
-- ⚠️ RUN ON right ⌥ DELIBERATELY, AND IT IS NO LONGER WHAT SHIPS. The
-- side machinery survived 6.124.0 as a setting — the shipped gesture
-- just does not use it, because Alfred turned out to be side-blind and
-- ⌃⌃ was taken whole instead. Exercising it on ⌥ is exercising the same
-- code the moment anyone sets tapSide, and ⌥ is the modifier with a real
-- left and right on every keyboard, which ⌃ is not. Section 1 pins what
-- actually ships; this section proves the machinery under it still works.
ep.tapMod, ep.tapSide = "alt", "right"
ep.resolveCodes()
ep.describe()

local function tapWith(code, gap)
    feed(flagsEvent({ [ep.tapMod] = true }, code)); tick(0.05)
    feed(flagsEvent({}, code)); tick(gap or 0.10)
end
local function doubleTap(code)
    reset()
    tapWith(code); tapWith(code)
end

check("the keycodes were resolved from hs.keycodes.map",
      ep.leftCode == 58 and ep.rightCode == 61,
      tostring(ep.leftCode) .. "/" .. tostring(ep.rightCode))
check("a keycode is attributed to its side",
      ep.sideOf(61) == "right" and ep.sideOf(58) == "left"
      and ep.sideOf(54) == nil and ep.sideOf(nil) == nil)

doubleTap(R_ALT)
check("right ⌥⌥ opens the picker", ep.fires == 1, ep.fires)

doubleTap(L_ALT)
check("left ⌥⌥ does NOT — the other ⌥ is not this gesture",
      ep.fires == 0, ep.fires)

-- The wrong side must CANCEL, not merely fail to count. If it only failed
-- to count, a left-hand tap mid-sequence would leave a right-⌥ tap armed
-- and the next right ⌥ a beat later would open the picker unasked.
reset()
tapWith(R_ALT)          -- one good tap, armed
tapWith(L_ALT)          -- the other hand
tapWith(R_ALT)          -- and a good tap right after
check("a left ⌥ between two right ⌥ taps cancels the gesture",
      ep.fires == 0, ep.fires)

reset()
tapWith(L_ALT); tapWith(R_ALT)
check("left-then-right is not a pair either", ep.fires == 0, ep.fires)

-- Counters. These are what _G.editorPickerReport() prints, and the only
-- way to tell "you have not pressed it yet" from "this keyboard has none".
ep.sidesSeen = { left = 0, right = 0 }
reset()
tapWith(R_ALT); tapWith(R_ALT); tapWith(L_ALT)
check("each side is counted as it is pressed",
      ep.sidesSeen.right == 2 and ep.sidesSeen.left == 1,
      tostring(ep.sidesSeen.right) .. "/" .. tostring(ep.sidesSeen.left))

-- 🚨 A PRESS WITH NO READABLE SIDE IS REFUSED, NOT GUESSED.
ep.sideUnknown, ep.saidUnknown = 0, false
reset()
feed(flagsEvent({ alt = true }, false)); tick(0.05)
feed(flagsEvent({}, false)); tick(0.10)
feed(flagsEvent({ alt = true }, false)); tick(0.05)
feed(flagsEvent({}, false))
check("a press naming no side does not fire", ep.fires == 0, ep.fires)
check("…and was counted", ep.sideUnknown == 2, ep.sideUnknown)
check("…and the keystroke still passed through",
      feed(flagsEvent({ alt = true }, false)) == false)

-- Said ONCE at the limit, not once per keypress.
local function unknownLines()
    local n = 0
    for _, l in ipairs(printed) do
        if l:find("could not be attributed", 1, true) then n = n + 1 end
    end
    return n
end
ep.sideUnknown, ep.saidUnknown = 0, false
for _ = 1, ep.sideUnknownLimit * 3 do ep.noteUnknownSide() end
check("the Console is told once, not once per press", unknownLines() == 1,
      unknownLines())
check("…and it names the setting that fixes it", (function()
    for _, l in ipairs(printed) do
        if l:find("tapSide", 1, true) and l:find("either", 1, true) then
            return true
        end
    end
    return false
end)())
check("…and it names the tap-free way in", (function()
    for _, l in ipairs(printed) do
        if l:find("could not be attributed", 1, true) then
            return l:find("⇪space → \"editor\" opens", 1, true) ~= nil, l
        end
    end
    return false
end)())

out("\n=== 2g. the side is a setting, and so is the modifier ===\n")
-- 🚨 A MODIFIER THAT IS NOT tapMod MUST DO NOTHING AT ALL. With the tap
-- set to ⌥ above, neither ⌘⌘ nor ⌃⌃ may open anything — and ⌃ is the
-- interesting one now that ⌃⌃ is what ships, because it proves the
-- gesture follows the SETTING and is not hard-coded anywhere.
reset()
feed(flagsEvent({ cmd = true }, R_CMD)); tick(0.05); feed(flagsEvent({}, R_CMD))
tick(0.10)
feed(flagsEvent({ cmd = true }, R_CMD)); tick(0.05); feed(flagsEvent({}, R_CMD))
check("⌘⌘ does not open the picker any more", ep.fires == 0, ep.fires)
reset()
feed(flagsEvent({ ctrl = true }, KC.rightctrl)); tick(0.05)
feed(flagsEvent({}, KC.rightctrl)); tick(0.10)
feed(flagsEvent({ ctrl = true }, KC.rightctrl)); tick(0.05)
feed(flagsEvent({}, KC.rightctrl))
check("…nor does ⌃⌃ while the tap is set to ⌥", ep.fires == 0, ep.fires)

-- 🚨 THE INTRUDER TEST FOLLOWS THE SETTING. With tapMod = "alt", ⌥ is the
-- gesture and must not count as a foreign modifier in its own press —
-- while ⌘ now must. Hard-code that list again and this fails.
reset()
feed(flagsEvent({ alt = true, cmd = true }, R_ALT)); tick(0.05)
feed(flagsEvent({}, R_ALT)); tick(0.10)
feed(flagsEvent({ alt = true }, R_ALT)); tick(0.05)
feed(flagsEvent({}, R_ALT))
check("⌥ held with ⌘ is a chord, not half a gesture", ep.fires == 0, ep.fires)

ep.tapSide = "left"
ep.describe()
doubleTap(L_ALT)
check("tapSide = \"left\" moves it to the left ⌥", ep.fires == 1, ep.fires)
doubleTap(R_ALT)
check("…and the right ⌥ is the one refused now", ep.fires == 0, ep.fires)
check("the gesture renames itself", ep.gesture() == "left ⌥⌥", ep.gesture())

ep.tapSide = "either"
ep.sideUnknown = 0
ep.describe()
doubleTap(L_ALT)
check("tapSide = \"either\" takes the side out of it — left fires",
      ep.fires == 1, ep.fires)
doubleTap(R_ALT)
check("…and so does right", ep.fires == 1, ep.fires)
reset()
feed(flagsEvent({ alt = true }, false)); tick(0.05)
feed(flagsEvent({}, false)); tick(0.10)
feed(flagsEvent({ alt = true }, false)); tick(0.05)
feed(flagsEvent({}, false))
check("…and an unreadable side is not refused when no side was asked for",
      ep.fires == 1, ep.fires)
check("…nor counted as a refusal", ep.sideUnknown == 0, ep.sideUnknown)

-- Back onto ⌘ and out again, because the modifier is a setting and the
-- 6.116.0 gesture has to remain one line away.
ep.tapSide, ep.tapMod = "either", "cmd"
ep.describe()
doubleTap(R_CMD)
check("tapMod = \"cmd\" restores the 6.116.0 gesture", ep.fires == 1, ep.fires)
check("…and it renames itself back", ep.gesture() == "⌘⌘", ep.gesture())
ep.tapSide, ep.tapMod = "right", "alt"
ep.describe()
check("the gesture follows the modifier", ep.gesture() == "right ⌥⌥",
      ep.gesture())
check("…and so do the keycodes, without being told to re-resolve",
      ep.sideOf(R_ALT) == "right" and ep.sideOf(R_CMD) == nil,
      tostring(ep.leftCode) .. "/" .. tostring(ep.rightCode))

-- The map is the source of the keycodes, not the fallback constants.
KC.rightalt = 99
ep.resolveCodes()
check("a keyboard map that moves a key is followed", ep.rightCode == 99,
      ep.rightCode)
doubleTap(99)
check("…and the moved key is the one that fires", ep.fires == 1, ep.fires)
KC.rightalt = R_ALT

-- A map that cannot tell the two apart FAILS OPEN, because refusing every
-- press would be a gesture that silently stopped working.
KC.alt = KC.rightalt
ep.resolveCodes()
check("one keycode for both keys is noticed", ep.sideReadable == false)
doubleTap(R_ALT)
check("…and the gesture still works rather than dying quietly",
      ep.fires == 1, ep.fires)
KC.alt = 58

-- Back to the shipped settings for everything below.
ep.tapMod, ep.tapSide = "ctrl", "either"
ep.resolveCodes()
ep.describe()
ep.sidesSeen, ep.sideUnknown, ep.saidUnknown = { left = 0, right = 0 }, 0, false
reset()

-- =====================================================================
out("\n=== 2h. 🚨 ⌃-CLICK AND ⌃-SCROLL DO NOT OPEN THE PICKER ===\n")
-- =====================================================================
-- The reason 6.124.0 could move the gesture onto ⌃ at all. ⌃-click IS
-- the Mac right-click and ⌃-scroll IS screen zoom, so on the shipped
-- gesture these are the two commonest ⌃ events on the machine:
--
--        ⌃-click        ctrl↓ · (click) · ctrl↑
--        ⌃ tapped once  ctrl↓ ·         · ctrl↑
--
-- identical to a keyDown-and-flagsChanged tap. Two right-clicks inside
-- ep.tapGap would have opened the picker over whatever was being
-- clicked. Delete any pointer type from ep.INTRUDER_NAMES and this
-- section fails — which is the whole job of this section.
ep.tapMod, ep.tapSide = "ctrl", "either"
ep.resolveCodes()
ep.describe()

local L_CTRL, R_CTRL = KC.ctrl, KC.rightctrl

-- ⌃ down · click · ⌃ up, twice over, fast — a double right-click.
local function ctrlClick(name, code)
    feed(flagsEvent({ ctrl = true }, code)); tick(0.02)
    feed(mouseEvent(name));                  tick(0.02)
    feed(flagsEvent({}, code));              tick(0.05)
end

for _, name in ipairs({ "leftMouseDown", "rightMouseDown",
                        "otherMouseDown", "scrollWheel" }) do
    reset()
    ctrlClick(name, L_CTRL); ctrlClick(name, L_CTRL)
    check("two ⌃ presses around a " .. name .. " do NOT open the picker",
          ep.fires == 0, ep.fires)
end

-- 🚨 AND IT CANCELS RATHER THAN MERELY FAILING TO COUNT. A click that
-- only failed to register would leave the first tap armed, and the next
-- bare ⌃ tap a beat later would open the picker unasked — which is the
-- same argument the wrong-side check in 2f makes.
reset()
tapWith(L_CTRL)                    -- one clean tap, armed
feed(mouseEvent("rightMouseDown")) -- a right-click lands
tick(0.05)
tapWith(L_CTRL)                    -- and a clean tap right after
check("a click between two ⌃ taps cancels the gesture", ep.fires == 0,
      ep.fires)

-- The gesture still has to WORK, on both keys, with the mouse quiet.
reset() ; tapWith(L_CTRL) ; tapWith(L_CTRL)
check("a clean left ⌃⌃ still opens it", ep.fires == 1, ep.fires)
reset() ; tapWith(R_CTRL) ; tapWith(R_CTRL)
check("…and so does a clean right ⌃⌃", ep.fires == 1, ep.fires)

-- A pointer event with nothing armed must be free, not an error: this is
-- the scroll-wheel hot path and it runs on every scroll event forever.
reset()
for _ = 1, 200 do feed(mouseEvent("scrollWheel")) end
check("scrolling with no gesture in flight is inert", ep.fires == 0, ep.fires)
check("…and never consumes the event",
      feed(mouseEvent("scrollWheel")) == false)

-- =====================================================================
out("\n=== 2i. nothing may name the gesture from memory ===\n")
check("the cheat sheet title names the live gesture",
      M.cheatsheet.title:find("⌃⌃", 1, true) ~= nil,
      M.cheatsheet.title)
check("…and so does its first row",
      M.cheatsheet.entries[1][1] == "⌃⌃", M.cheatsheet.entries[1][1])
check("…and the side row says both keys fire it",
      M.cheatsheet.entries[8][1] == "either ⌃", M.cheatsheet.entries[8][1])
-- 🚨 THE MOUSE ROW NAMES THE LIVE MODIFIER TOO. "⌃-click does not open
-- it" becomes a lie the moment tapMod moves, and a cheat sheet that lies
-- confidently is the thing this whole section exists to prevent.
check("…and the mouse row names the live modifier",
      M.cheatsheet.entries[9][2]:find("⌃-click", 1, true) ~= nil,
      M.cheatsheet.entries[9][2])
ep.tapMod, ep.tapSide = "alt", "right"
ep.resolveCodes() ; ep.describe()
check("changing the modifier rewrites the sheet rather than leaving it stale",
      M.cheatsheet.title:find("right ⌥⌥", 1, true) ~= nil
      and M.cheatsheet.entries[1][1] == "right ⌥⌥",
      M.cheatsheet.title)
check("…the mouse row followed it",
      M.cheatsheet.entries[9][2]:find("⌥-click", 1, true) ~= nil,
      M.cheatsheet.entries[9][2])
check("…and so did the side row",
      M.cheatsheet.entries[8][1] == "left ⌥⌥", M.cheatsheet.entries[8][1])
-- The harvested group holds the SAME entries table by reference but its
-- own copy of the title string, so describe() has to go and fix that too.
_G.moduleCheatsheets = { { source = M.name, title = "stale", entries = M.cheatsheet.entries } }
ep.describe()
check("a title already harvested by init.lua is corrected in place",
      _G.moduleCheatsheets[1].title == M.cheatsheet.title,
      _G.moduleCheatsheets[1].title)
_G.moduleCheatsheets = nil
-- Back to the shipped gesture, and it stays there to the end of the file:
-- section 6 reads the report and the report must describe what ships.
ep.tapMod, ep.tapSide = "ctrl", "either"
ep.resolveCodes() ; ep.describe()

-- =====================================================================
out("\n=== 3. the roster, sorted ===\n")
-- =====================================================================
local OPENED, SHOWED = {}, {}
local fakeView = { bringToFront = function() end, hswindow = function() return nil end }

_G.editors = {
    { name = "Empty One", key = "⇪1", order = 10,
      show = function() SHOWED[#SHOWED + 1] = "Empty One" end,
      size = function() return 0 end },
    { name = "Has Text",  key = "⇪2", order = 20, what = "a draft",
      show = function() SHOWED[#SHOWED + 1] = "Has Text" end,
      size = function() return 412 end,
      text = function() return "the draft text" end },
    { name = "Is Open",   key = "⇪3", order = 30,
      view = function() return fakeView end,
      show = function() SHOWED[#SHOWED + 1] = "Is Open" end,
      size = function() return 3 end },
    { name = "No Size",   key = "⇪4", order = 5,
      show = function() SHOWED[#SHOWED + 1] = "No Size" end },
}

local states = ep.states()
check("all four are listed", #states == 4, #states)
check("the OPEN one sorts first", states[1].name == "Is Open", states[1].name)
check("then the one with text", states[2].name == "Has Text", states[2].name)
check("the empty ones come last", (states[3].name == "Empty One"
      or states[3].name == "No Size") and (states[4].name == "Empty One"
      or states[4].name == "No Size"), states[3].name .. "/" .. states[4].name)
check("declared order breaks ties inside a band", states[3].name == "No Size",
      states[3].name)

local rows = ep.rows()
local function rowFor(name)
    for _, r in ipairs(rows) do if r.edName == name then return r end end
end
check("the open row is marked in its title",
      rowFor("Is Open").text:find("●", 1, true) ~= nil, rowFor("Is Open").text)
check("…and says OPEN NOW in its subtitle",
      rowFor("Is Open").subText:find("OPEN NOW", 1, true) ~= nil)
check("a sized row prints its size",
      rowFor("Has Text").subText:find("412 characters", 1, true) ~= nil,
      rowFor("Has Text").subText)
check("a row carries its own description",
      rowFor("Has Text").subText:find("a draft", 1, true) ~= nil)
check("an empty row says empty",
      rowFor("Empty One").subText:find("empty", 1, true) ~= nil,
      rowFor("Empty One").subText)
-- 🚨 A missing size function is NOT an empty editor, and saying "empty"
-- for it would be a small lie about somebody else's data.
check("a row with no size function does NOT claim to be empty",
      rowFor("No Size").subText:find("empty", 1, true) == nil,
      rowFor("No Size").subText)

_G.editors = {}
check("with nothing registered it says so, rather than showing a blank list",
      ep.rows()[1].text:find("No editors", 1, true) ~= nil)

-- =====================================================================
out("\n=== 4. 🚨 ⏎ ON AN OPEN EDITOR NEVER CALLS show() ===\n")
-- =====================================================================
-- pad.show() and np.show() TOGGLE, and for the Note Pad closing FILES
-- the draft. Picking an open pad out of this list in order to go and
-- READ it must not be the keystroke that files it.
local fronted = 0
local toggler = { bringToFront = function() fronted = fronted + 1 end,
                  hswindow = function() return nil end }
SHOWED = {}
_G.editors = {
    { name = "Open Pad", key = "⇪N",
      view = function() return toggler end,
      show = function() SHOWED[#SHOWED + 1] = "Open Pad" end },
    { name = "Shut Pad", key = "⇪M",
      view = function() return nil end,
      show = function() SHOWED[#SHOWED + 1] = "Shut Pad" end },
}
ep.open("Open Pad")
check("an OPEN editor was brought to the front", fronted == 1, fronted)
check("…and show() was never called on it", #SHOWED == 0,
      table.concat(SHOWED, ","))
ep.open("Shut Pad")
check("a CLOSED editor is opened with show()",
      SHOWED[1] == "Shut Pad", table.concat(SHOWED, ","))

-- A registration whose view() throws must cost one row, not the picker.
_G.editors[#_G.editors + 1] = {
    name = "Broken", view = function() error("nope") end,
    show = function() SHOWED[#SHOWED + 1] = "Broken" end }
local okStates = pcall(ep.states)
check("a throwing view() does not take the roster down", okStates)
ep.open("Broken")
check("…and its row falls back to opening it", SHOWED[#SHOWED] == "Broken")

ALERTS = {}
check("an unknown name is refused rather than guessed", ep.open("Nope") == false)
local noOpen = { name = "No Way In" }
_G.editors = { noOpen }
ALERTS = {}
check("an editor with no way to open says so", ep.open("No Way In") == false)
check("…out loud", #ALERTS == 1 and ALERTS[1]:find("no way to open", 1, true))

-- =====================================================================
out("\n=== 5. ⌥⏎ copies without opening ===\n")
-- =====================================================================
SHOWED, ALERTS, CLIP = {}, {}, nil
_G.editors = {
    { name = "Full",  text = function() return "carry me" end,
      show = function() SHOWED[#SHOWED + 1] = "Full" end },
    { name = "Blank", text = function() return "" end,
      show = function() SHOWED[#SHOWED + 1] = "Blank" end },
    { name = "Mute",  show = function() SHOWED[#SHOWED + 1] = "Mute" end },
}
check("copying returns true", ep.copy("Full") == true)
check("the text reached the clipboard", CLIP == "carry me", CLIP)
check("🚨 and NOTHING was opened", #SHOWED == 0, table.concat(SHOWED, ","))
check("it says what it copied and how much",
      ALERTS[#ALERTS]:find("Copied Full", 1, true)
      and ALERTS[#ALERTS]:find("8", 1, true), ALERTS[#ALERTS])

CLIP = "PRECIOUS"
check("an empty editor is refused", ep.copy("Blank") == false)
check("🚨 …and the clipboard is left ALONE, not blanked", CLIP == "PRECIOUS", CLIP)
check("it says the editor was empty",
      ALERTS[#ALERTS]:find("empty", 1, true), ALERTS[#ALERTS])
check("an editor with no text function is refused", ep.copy("Mute") == false)
check("…and says so", ALERTS[#ALERTS]:find("no text to copy", 1, true))

-- The completion callback reads ⌥ at the moment of the press.
SHOWED, CLIP = {}, nil
_G.editors = {
    { name = "Full", text = function() return "carry me" end,
      show = function() SHOWED[#SHOWED + 1] = "Full" end },
}
ep.show()
local pickerChooser = ep.chooser
MODS = { alt = true }
pickerChooser.cb({ edName = "Full" })
check("⌥⏎ copies", CLIP == "carry me", CLIP)
check("…without opening", #SHOWED == 0, table.concat(SHOWED, ","))
MODS = {}
pickerChooser.cb({ edName = "Full" })
check("plain ⏎ opens", SHOWED[1] == "Full", table.concat(SHOWED, ","))
check("a dismissed picker (nil pick) does nothing", (function()
    local before = #SHOWED
    pickerChooser.cb(nil)
    return #SHOWED == before
end)())
check("the picker is filed in _G.choosers so Esc reaches it",
      _G.choosers and _G.choosers.editorPicker == pickerChooser)

-- =====================================================================
out("\n=== 6. the report ===\n")
-- =====================================================================
_G.editors = {
    { name = "One", key = "⇪1", size = function() return 5 end },
}
local rep = _G.editorPickerReport()
check("it names the tap's state", rep:find("watcher    : running", 1, true) ~= nil,
      rep)
check("it names the gesture and both settings it is made of",
      rep:find("⌃⌃", 1, true) ~= nil
      and rep:find("tapMod = ctrl", 1, true) ~= nil
      and rep:find("tapSide = either", 1, true) ~= nil, rep)
check("it names the keyless way in rather than a key it no longer holds",
      rep:find("fallback   : ⇪space", 1, true) ~= nil
      and rep:find("no key of its own", 1, true) ~= nil, rep)
-- 🚨 THE REPORT MUST NOT THROW WHEN ep.key IS nil, and nil is what ships.
-- The old line was ep.key:upper(), which would have errored inside the one
-- function you run to find out why the picker is not working.
check("…and the report survives ep.key being nil at all",
      rep:find("⇪⇧Z", 1, true) == nil, rep)
check("it counts the roster", rep:find("registered : 1", 1, true) ~= nil, rep)
check("it lists each editor", rep:find("One", 1, true) ~= nil)
-- 🚨 AND IT SAYS NOTHING IS MISSING, which is what proves the pointer
-- types actually resolved on this Hammerspoon rather than being skipped.
check("it does not warn about missing event types",
      rep:find("no event type for", 1, true) == nil, rep)

-- 🚨 THE PART THAT DIAGNOSES A KEYBOARD WITH NO RIGHT KEY. Zero presses
-- on the side you chose means the gesture cannot fire, and this report is
-- the only place that would ever say why.
--
-- ⚠️ EXERCISED ON A SIDE-RESTRICTED SETTING ON PURPOSE. The shipped
-- gesture is "either", which cannot produce this warning by design — but
-- the warning is exactly what saves anyone who sets tapSide = "right" on
-- an Apple keyboard that has no right ⌃, so it is still tested.
ep.tapSide = "right"
ep.sidesSeen, ep.sideUnknown = { left = 3, right = 0 }, 0
rep = _G.editorPickerReport()
check("it prints how many times each key has been pressed",
      rep:find("left 3 · right 0", 1, true) ~= nil, rep)
check("…and warns when the chosen side has never been seen",
      rep:find("has not been pressed once", 1, true) ~= nil
      and rep:find("tapSide = \"either\"", 1, true) ~= nil, rep)
-- 🚨 AND THE SHIPPED SETTING MUST NOT PRODUCE IT. A gesture that fires on
-- either key has no "chosen side" to be missing, and a report that nagged
-- about one anyway would be the confident wrong answer again.
ep.tapSide = "either"
rep = _G.editorPickerReport()
check("…and never warns about a side when none was chosen",
      rep:find("has not been pressed once", 1, true) == nil, rep)
ep.tapSide = "right"
ep.sidesSeen, ep.sideUnknown = { left = 3, right = 9 }, 4
rep = _G.editorPickerReport()
check("no such warning once the chosen side has been used",
      rep:find("has not been pressed once", 1, true) == nil, rep)
check("…but refused presses are still reported",
      rep:find("4 presses named no side", 1, true) ~= nil, rep)
ep.sidesSeen, ep.sideUnknown = { left = 0, right = 1 }, 0
ep.tapSide = "either"          -- back to what ships
_G.editors = {}
rep = _G.editorPickerReport()
check("an empty roster is explained, not just zero",
      rep:find("Nothing registered", 1, true) ~= nil)

-- =====================================================================
out("\n=== 7. 🚨 THE ROSTER CANNOT ROT ===\n")
-- =====================================================================
-- The same shape of guard as the escape-router roster check in
-- test_integration, and for the same reason: this registry is filled by
-- OTHER files, so a module that grows an editor window — or loses its
-- registration in a refactor — would silently shrink the picker, and the
-- only symptom is a row that is not there. A comment asking people to
-- remember is not a sentry.
local function slurp(p)
    local f = io.open(p, "rb"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end
local MUST_REGISTER = {
    "capture_pad", "note_pad", "ocr_engine",
    "clipboard_history", "win_pin", "screenshot_editor",
}
local missing = {}
for _, name in ipairs(MUST_REGISTER) do
    local src = slurp(HS .. "/modules/" .. name .. ".lua")
    if not src or not src:find("table.insert(_G.editors", 1, true) then
        missing[#missing + 1] = name
    end
end
check("every editor-owning module registers into _G.editors",
      #missing == 0, table.concat(missing, ", "))

-- And the module list must actually load it, or none of the above ships.
local initSrc = slurp(HS .. "/init.lua") or ""
check("editor_picker is in init.lua's BASE list",
      initSrc:find('"editor_picker"', 1, true) ~= nil)

-- 🚨 THE INVARIANT THE TWO WINDOWS DEPEND ON. maxHold is how long a ⌘
-- may be down and still count as a tap; tapGap is how long the pair may
-- take. Either one at or above the human double-tap rhythm makes chords
-- indistinguishable from gestures, which is section 2 all over again.
check("maxHold is tight enough to exclude a held ⌘", ep.maxHold <= 0.5,
      ep.maxHold)
check("tapGap is tight enough to exclude two separate taps", ep.tapGap <= 0.5,
      ep.tapGap)

-- =====================================================================
out("\n=== 8. it survives a Mac with no event tap at all ===\n")
-- =====================================================================
local realNew = hs.eventtap.new
hs.eventtap.new = function() error("no accessibility") end
ep.stopTap()
local started = ep.startTap()
check("startTap reports failure rather than throwing", started == false)
-- 🚨 THIS IS THE CHECK THE WHOLE SECTION EXISTS FOR, and 6.125.0 changed
-- what it has to look at. Until now the answer was "⇪⇧Z is still bound".
-- With the key given back, the second way in is the ⇪space run-map row —
-- so what must survive a dead event tap is the SERVICE that row calls.
-- If this ever goes nil, the picker has exactly one way in and the header
-- forbids that.
check("…and the service ⇪space runs is still published",
      type(PROVIDED["editors.show"]) == "function")
check("…and unified_search's run map still points at it — the row and the "
      .. "service are two halves of one route and half of it is nothing",
      (function()
    local f = io.open(HS .. "/modules/unified_search.lua", "r")
    local src = f and f:read("*a")
    if f then f:close() end
    if not src then return false, "unified_search.lua unreadable" end
    return src:find('%["🗂"%]%s*=%s*"editors%.show"') ~= nil
end)())
check("…and the picker still opens", (function()
    _G.editors = { { name = "One", show = function() end } }
    local before = #SHOWN
    ep.show()
    return #SHOWN == before + 1
end)())
hs.eventtap.new = realNew

-- ---- result ------------------------------------------------------------
out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
