-- =====================================================================
-- test_editor_picker.lua — right ⌘⌘ opens the editors; ⌘C⌘V and the LEFT
-- ⌘ do not
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
-- Section 2f is 6.121.0's half of a fence LL shares with Alfred: the left
-- ⌘ is Alfred's and the right ⌘ is this config's. The checks there fail
-- if the side is read from the wrong edge of the press, if a wrong-side
-- key is merely ignored instead of cancelling, or if a press whose side
-- cannot be read is GUESSED — which would be the conflict coming back.

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

local TYPES = { keyDown = 10, flagsChanged = 12 }

-- The real macOS keycodes. The module reads hs.keycodes.map and falls
-- back to these same numbers, so the stub carries the map to prove the
-- lookup is wired — section 2f moves one of them to prove it is USED.
local KC = {
    cmd = 55, rightcmd = 54, alt = 58, rightalt = 61,
    ctrl = 59, rightctrl = 62, shift = 56, rightshift = 60,
}
local L_CMD, R_CMD, R_ALT = KC.cmd, KC.rightcmd, KC.rightalt

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
check("⇪⇧Z is bound as the tap-free way in", BOUND["shift+z"] ~= nil)
check("the binding is attributed to this module",
      BOUND["shift+z"] and BOUND["shift+z"].src == "editor picker")
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
check("three services are published",
      PROVIDED["editors.show"] and PROVIDED["editors.list"]
      and PROVIDED["editors.report"])

-- =====================================================================
out("\n=== 2. 🚨 ⌘C THEN ⌘V DOES NOT OPEN THE PICKER ===\n")
-- =====================================================================
-- The whole reason this tap subscribes to keyDown. Delete the keyDown
-- branch of the callback and every check in this section fails.
local function feed(e) return TAP.cb(e) end
local function tick(dt) NOW = NOW + dt end

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
check("…and named ⇪⇧Z as the way in", (function()
    for _, l in ipairs(printed) do
        if l:find("⇪⇧Z still opens", 1, true) then return true end
    end
    return false
end)())
TAP.started = true ; ep.tapRunning = true ; ep.tapFailures = 0

-- =====================================================================
out("\n=== 2f. 🚨 THE LEFT ⌘ IS ALFRED'S ===\n")
-- =====================================================================
-- LL runs Alfred on ⌘⌘. This config can only narrow its own half of that
-- key, and these checks are that half.
local function tapWith(code, gap)
    feed(flagsEvent({ [ep.tapMod] = true }, code)); tick(0.05)
    feed(flagsEvent({}, code)); tick(gap or 0.10)
end
local function doubleTap(code)
    reset()
    tapWith(code); tapWith(code)
end

check("the shipped default is the RIGHT key", ep.tapSide == "right", ep.tapSide)
check("…of the ⌘ modifier", ep.tapMod == "cmd", ep.tapMod)
check("the gesture names itself", ep.gesture() == "right ⌘⌘", ep.gesture())
check("the keycodes were resolved from hs.keycodes.map",
      ep.leftCode == 55 and ep.rightCode == 54,
      tostring(ep.leftCode) .. "/" .. tostring(ep.rightCode))
check("a keycode is attributed to its side",
      ep.sideOf(54) == "right" and ep.sideOf(55) == "left"
      and ep.sideOf(61) == nil and ep.sideOf(nil) == nil)

doubleTap(R_CMD)
check("right ⌘⌘ opens the picker", ep.fires == 1, ep.fires)

doubleTap(L_CMD)
check("left ⌘⌘ does NOT — that is Alfred's", ep.fires == 0, ep.fires)

-- The wrong side must CANCEL, not merely fail to count. If it only failed
-- to count, reaching for Alfred mid-sequence would leave a right-⌘ tap
-- armed and the next right ⌘ a beat later would open the picker.
reset()
tapWith(R_CMD)          -- one good tap, armed
tapWith(L_CMD)          -- Alfred
tapWith(R_CMD)          -- and a good tap right after
check("a left ⌘ between two right ⌘ taps cancels the gesture",
      ep.fires == 0, ep.fires)

reset()
tapWith(L_CMD); tapWith(R_CMD)
check("left-then-right is not a pair either", ep.fires == 0, ep.fires)

-- Counters. These are what _G.editorPickerReport() prints, and the only
-- way to tell "you have not pressed it yet" from "this keyboard has none".
ep.sidesSeen = { left = 0, right = 0 }
reset()
tapWith(R_CMD); tapWith(R_CMD); tapWith(L_CMD)
check("each side is counted as it is pressed",
      ep.sidesSeen.right == 2 and ep.sidesSeen.left == 1,
      tostring(ep.sidesSeen.right) .. "/" .. tostring(ep.sidesSeen.left))

-- 🚨 A PRESS WITH NO READABLE SIDE IS REFUSED, NOT GUESSED.
ep.sideUnknown, ep.saidUnknown = 0, false
reset()
feed(flagsEvent({ cmd = true }, false)); tick(0.05)
feed(flagsEvent({}, false)); tick(0.10)
feed(flagsEvent({ cmd = true }, false)); tick(0.05)
feed(flagsEvent({}, false))
check("a press naming no side does not fire", ep.fires == 0, ep.fires)
check("…and was counted", ep.sideUnknown == 2, ep.sideUnknown)
check("…and the keystroke still passed through",
      feed(flagsEvent({ cmd = true }, false)) == false)

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
check("…and it names ⇪⇧Z", (function()
    for _, l in ipairs(printed) do
        if l:find("could not be attributed", 1, true) then
            return l:find("⇪⇧Z", 1, true) ~= nil
        end
    end
    return false
end)())

out("\n=== 2g. the side is a setting, and so is the modifier ===\n")
ep.tapSide = "left"
ep.describe()
doubleTap(L_CMD)
check("tapSide = \"left\" moves it to the left ⌘", ep.fires == 1, ep.fires)
doubleTap(R_CMD)
check("…and the right ⌘ is the one refused now", ep.fires == 0, ep.fires)
check("the gesture renames itself", ep.gesture() == "left ⌘⌘", ep.gesture())

ep.tapSide = "either"
ep.sideUnknown = 0
ep.describe()
doubleTap(L_CMD)
check("tapSide = \"either\" is the 6.116.0 behaviour — left fires",
      ep.fires == 1, ep.fires)
doubleTap(R_CMD)
check("…and so does right", ep.fires == 1, ep.fires)
reset()
feed(flagsEvent({ cmd = true }, false)); tick(0.05)
feed(flagsEvent({}, false)); tick(0.10)
feed(flagsEvent({ cmd = true }, false)); tick(0.05)
feed(flagsEvent({}, false))
check("…and an unreadable side is not refused when no side was asked for",
      ep.fires == 1, ep.fires)
check("…nor counted as a refusal", ep.sideUnknown == 0, ep.sideUnknown)

-- ⌥ is the answer if Alfred turns out to fire on both ⌘ keys.
ep.tapSide, ep.tapMod = "right", "alt"
ep.describe()
check("the gesture follows the modifier", ep.gesture() == "right ⌥⌥",
      ep.gesture())
check("…and so do the keycodes, without being told to re-resolve",
      ep.sideOf(R_ALT) == "right" and ep.sideOf(R_CMD) == nil,
      tostring(ep.leftCode) .. "/" .. tostring(ep.rightCode))
doubleTap(R_ALT)
check("right ⌥⌥ opens the picker", ep.fires == 1, ep.fires)
reset()
feed(flagsEvent({ cmd = true }, R_CMD)); tick(0.05); feed(flagsEvent({}, R_CMD))
tick(0.10)
feed(flagsEvent({ cmd = true }, R_CMD)); tick(0.05); feed(flagsEvent({}, R_CMD))
check("…and ⌘⌘ no longer does anything at all", ep.fires == 0, ep.fires)
-- 🚨 THE INTRUDER TEST HAS TO FOLLOW THE SETTING TOO. With tapMod = "alt",
-- ⌥ is the gesture and must not count as a foreign modifier in its own
-- press — while ⌘ now must.
reset()
feed(flagsEvent({ alt = true, cmd = true }, R_ALT)); tick(0.05)
feed(flagsEvent({}, R_ALT)); tick(0.10)
feed(flagsEvent({ alt = true }, R_ALT)); tick(0.05)
feed(flagsEvent({}, R_ALT))
check("⌥ held with ⌘ is a chord, not half a gesture", ep.fires == 0, ep.fires)

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
ep.tapMod, ep.tapSide = "cmd", "right"
ep.resolveCodes()
ep.describe()
ep.sidesSeen, ep.sideUnknown, ep.saidUnknown = { left = 0, right = 0 }, 0, false
reset()

out("\n=== 2h. nothing may say ⌘⌘ from memory ===\n")
check("the cheat sheet title names the live gesture",
      M.cheatsheet.title:find("right ⌘⌘", 1, true) ~= nil,
      M.cheatsheet.title)
check("…and so does its first row",
      M.cheatsheet.entries[1][1] == "right ⌘⌘", M.cheatsheet.entries[1][1])
check("…and a row says whose the other one is",
      M.cheatsheet.entries[8][1] == "left ⌘⌘"
      and M.cheatsheet.entries[8][2]:find("Alfred", 1, true) ~= nil,
      M.cheatsheet.entries[8][1])
ep.tapMod = "ctrl" ; ep.resolveCodes() ; ep.describe()
check("changing the modifier rewrites the sheet rather than leaving it stale",
      M.cheatsheet.title:find("right ⌃⌃", 1, true) ~= nil
      and M.cheatsheet.entries[1][1] == "right ⌃⌃",
      M.cheatsheet.title)
-- The harvested group holds the SAME entries table by reference but its
-- own copy of the title string, so describe() has to go and fix that too.
_G.moduleCheatsheets = { { source = M.name, title = "stale", entries = M.cheatsheet.entries } }
ep.describe()
check("a title already harvested by init.lua is corrected in place",
      _G.moduleCheatsheets[1].title == M.cheatsheet.title,
      _G.moduleCheatsheets[1].title)
_G.moduleCheatsheets = nil
ep.tapMod = "cmd" ; ep.resolveCodes() ; ep.describe()

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
      rep:find("right ⌘⌘", 1, true) ~= nil
      and rep:find("tapMod = cmd", 1, true) ~= nil
      and rep:find("tapSide = right", 1, true) ~= nil, rep)
check("it names the fallback key", rep:find("⇪⇧Z", 1, true) ~= nil)
check("it counts the roster", rep:find("registered : 1", 1, true) ~= nil, rep)
check("it lists each editor", rep:find("One", 1, true) ~= nil)

-- 🚨 THE PART THAT DIAGNOSES A KEYBOARD WITH NO RIGHT ⌘. Nought presses on
-- the side you chose means the gesture cannot fire, and this report is the
-- only place that would ever say why.
ep.sidesSeen, ep.sideUnknown = { left = 3, right = 0 }, 0
rep = _G.editorPickerReport()
check("it prints how many times each key has been pressed",
      rep:find("left 3 · right 0", 1, true) ~= nil, rep)
check("…and warns when the chosen side has never been seen",
      rep:find("has not been pressed once", 1, true) ~= nil
      and rep:find("tapSide = \"either\"", 1, true) ~= nil, rep)
ep.sidesSeen, ep.sideUnknown = { left = 3, right = 9 }, 4
rep = _G.editorPickerReport()
check("no such warning once the chosen side has been used",
      rep:find("has not been pressed once", 1, true) == nil, rep)
check("…but refused presses are still reported",
      rep:find("4 presses named no side", 1, true) ~= nil, rep)
ep.sidesSeen, ep.sideUnknown = { left = 0, right = 1 }, 0
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
check("…and the fallback key is still bound", BOUND["shift+z"] ~= nil)
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
