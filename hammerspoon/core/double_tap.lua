-- =====================================================================
-- core/double_tap.lua — ⌘⌘ · ⌥⌥ · ⌃⌃, one engine, many gestures
-- =====================================================================
-- 6.292.0. LL: "My double tap for my clipboard history uses
-- command+command, is that built? Same as opt+option to move to the
-- menu bar even if the app is full-screen?"
--
-- The honest answer was NO to both. He asked in 6.198.0, again on
-- 2026-09-13, and they had never been built — while the MACHINERY for
-- them has been running on his Mac since 6.116.0, inside
-- modules/editor_picker.lua, driving ⌃⌃. This file is that machinery
-- lifted out so a gesture is a registration rather than a second copy
-- of a state machine (6.231.0).
--
-- 🔑 WHY THE ENGINE IS SHARED AND ⌃⌃ IS NOT ON IT YET, stated rather
-- than left to be discovered. editor_picker's tap is the one place in
-- this config that watches keyDown GLOBALLY, and a mistake there does
-- not break a feature — it takes the keyboard, which is exactly what
-- 6.214.0 cost him. So the new engine proves itself on the two NEW
-- gestures first and editor_picker migrates in its own later release,
-- once his Mac has run this code for a while. That is this project's
-- own new-ground habit applied to a refactor: the first release is the
-- one that can be judged, not the one that touches everything.
-- 📏 THE COST IS REAL AND IS NAMED: until that migration there are two
-- copies of the double-tap rule in this config, and two taps on
-- flagsChanged. Both are cheap; neither is free. `_G.doubleTapReport()`
-- says so on its last line so nobody has to remember.
--
-- 🖥 "EVEN IF THE APP IS FULL-SCREEN" is already how every panel here
-- is built and needed no work: this config's windows are drawn by an
-- ACCESSORY app (no Dock icon), and hs.chooser and the webview panels
-- come forward over a full-screen app because of it. The gesture
-- itself is an event tap, which macOS delivers whatever is on screen.
--
-- =====================================================================
-- THE RULES, all inherited from editor_picker and all load-bearing
-- =====================================================================
-- · A TAP IS DOWN AND UP INSIDE maxHold. A modifier you are HOLDING to
--   use is down for as long as you are reading the menu.
-- · TWO TAPS INSIDE tapGap ARE ONE GESTURE. Both windows are tight:
--   every millisecond of slack is a millisecond in which a real chord
--   can be mistaken for half a gesture.
-- · ANY OTHER MODIFIER DIRTIES THE PRESS — ⌘ arriving alongside ⇧ is
--   not a tap, and ⇧ joining a held ⌘ is not either.
-- · A KEY OR A MOUSE BUTTON BETWEEN THE HALVES PROVES IT WAS A CHORD,
--   and cancels a sequence already half made. The mouse ones are not
--   decoration: ⌃-click IS the Mac right-click and ⌃-scroll IS screen
--   zoom, so a flagsChanged-only tap cannot see the middle column of
--       ⌃-click       ctrl↓ · (click) · ctrl↑
--       ⌃ tapped once ctrl↓ ·         · ctrl↑
--   and two right-clicks inside tapGap would fire the gesture.
-- · IT NEVER LOOKS AT WHICH KEY YOU TYPED. The keyDown branch reads no
--   keycode and no characters; it records THAT a key happened. The
--   keycode it does read belongs to flagsChanged events, where the
--   "key" is ⌘ or ⌥ and nothing anyone could be writing with.
-- · IT STANDS DOWN FOR THE INJECTION GUARD (6.218.0) and for ⇪
--   (_G.hyperActive), so the expander's synthetic keys and §3.12's boot
--   self-test cannot assemble a gesture nobody made.
-- · EVERY PATH RETURNS false. This tap watches; it never consumes. It
--   sees keyDown, so a path returning true would take the keyboard away
--   entirely rather than break one feature.
-- · IT DISABLES ITSELF RATHER THAN DEGRADING THE KEYBOARD: failLimit
--   consecutive throws and it stops and says so.

local dt = {}

-- ---- configuration ---------------------------------------------------
dt.maxHold  = 0.35     -- a tap is the modifier down and up inside this
dt.tapGap   = 0.35     -- and the second tap lands inside this
dt.failLimit = 5       -- consecutive callback throws before standing down

-- 🎹 WHICH PHYSICAL KEY. The numbers are the documented macOS keycodes
-- and have not moved in twenty years, but they are the FALLBACK and not
-- the source: hs.keycodes is the thing that knows, and a hard-coded
-- constant that drifts is a gesture that dies quietly.
dt.MOD_KEYS = {
    cmd   = { glyph = "⌘", left = "cmd",   right = "rightcmd",   codes = { 55, 54 } },
    alt   = { glyph = "⌥", left = "alt",   right = "rightalt",   codes = { 58, 61 } },
    ctrl  = { glyph = "⌃", left = "ctrl",  right = "rightctrl",  codes = { 59, 62 } },
    shift = { glyph = "⇧", left = "shift", right = "rightshift", codes = { 56, 60 } },
}
dt.ALL_MODS = { "cmd", "alt", "ctrl", "shift" }

-- 🚨 BUILT BY LOOKUP, NOT WRITTEN OUT, and any name this Hammerspoon
-- does not have is SKIPPED rather than stored as nil: a nil in a
-- watched-types list is not a smaller feature, it is an eventtap that
-- fails to construct and takes every gesture with it.
dt.INTRUDER_NAMES = {
    "keyDown",
    "leftMouseDown",    -- ⌃-click is the Mac right-click
    "rightMouseDown",
    "otherMouseDown",
    "scrollWheel",      -- ⌃-scroll is screen zoom
}
dt.INTRUDER_TYPES, dt.WATCHED_TYPES, dt.MISSING_TYPES = {}, {}, {}
do
    local T = (hs and hs.eventtap and hs.eventtap.event
               and hs.eventtap.event.types) or {}
    for _, name in ipairs(dt.INTRUDER_NAMES) do
        local t = T[name]
        if t ~= nil then
            dt.INTRUDER_TYPES[t] = true
            dt.WATCHED_TYPES[#dt.WATCHED_TYPES + 1] = t
        else
            dt.MISSING_TYPES[#dt.MISSING_TYPES + 1] = name
        end
    end
    if T.flagsChanged ~= nil then
        dt.WATCHED_TYPES[#dt.WATCHED_TYPES + 1] = T.flagsChanged
    end
end

-- ---- the register ----------------------------------------------------
dt.gestures = {}        -- ordered list of records
dt.byName   = {}
dt.tap, dt.tapRunning, dt.tapFailures = nil, false, 0
dt.fires, dt.lastFire = 0, nil
dt.sideUnknownLimit = 12

-- What to CALL a gesture, everywhere it is named. One function so the
-- cheat sheet, the report and the Console can never disagree.
function dt.glyph(mod)
    local spec = dt.MOD_KEYS[mod]
    if not spec then return "??" end
    return spec.glyph .. spec.glyph
end

-- PURE given the map: nil means "this event does not name a side", which
-- is NOT the same as "either side".
function dt.sideOf(g, keyCode)
    if not g then return nil end
    if g.codesFor ~= g.mod then dt.resolveCodes(g) end
    if type(keyCode) ~= "number" then return nil end
    if keyCode == g.leftCode  then return "left"  end
    if keyCode == g.rightCode then return "right" end
    return nil
end

function dt.resolveCodes(g)
    local spec = dt.MOD_KEYS[g.mod] or dt.MOD_KEYS.cmd
    local left, right = spec.codes[1], spec.codes[2]
    pcall(function()
        local map = hs and hs.keycodes and hs.keycodes.map
        if type(map) ~= "table" then return end
        if type(map[spec.left])  == "number" then left  = map[spec.left]  end
        if type(map[spec.right]) == "number" then right = map[spec.right] end
    end)
    -- ⚠️ A KEYBOARD MAP THAT GIVES BOTH SIDES THE SAME NUMBER cannot tell
    -- them apart, and pretending otherwise would silently refuse every
    -- press. Say so and stop asking.
    g.sideReadable = (left ~= right)
    g.leftCode, g.rightCode, g.codesFor = left, right, g.mod
    return left, right
end

-- The only place the setting is interpreted. Anything other than "left"
-- or "right" means the side does not matter, which makes a typo in a
-- profile fail OPEN rather than kill the gesture.
function dt.sideOK(g, side)
    if g.side ~= "left" and g.side ~= "right" then return true end
    if not g.sideReadable then return true end
    return side == g.side
end

-- Every modifier that is NOT the one this gesture is made of. Read from
-- the record rather than written out, so a gesture on ⌥ does not count
-- ⌥ as an intruder in its own gesture.
local function otherFlags(g, flags)
    for _, m in ipairs(dt.ALL_MODS) do
        if m ~= g.mod and flags[m] == true then return true end
    end
    return flags.fn == true
end

-- THE STATE MACHINE. Called with a plain flags table, a wall clock and
-- the keycode of the modifier that changed (nil when unknown). Returns
-- true on the frame that COMPLETES a double tap. Its state lives on the
-- record, so N gestures run side by side without interfering.
function dt.onFlags(g, flags, now, keyCode)
    if not g then return false end
    flags = flags or {}
    local down   = flags[g.mod] == true
    local others = otherFlags(g, flags)
    if down and g.downAt == nil then
        g.downAt = now
        g.dirty  = others            -- ⌘ arriving alongside ⇧ is not a tap
        -- 🚨 THE SIDE IS DECIDED ON THE WAY DOWN, and a wrong-side key
        -- does not merely fail to count — it DIRTIES the press, which
        -- clears any half-made sequence on the release below. Tapping
        -- the left key twice therefore cannot leave a right-only
        -- gesture armed.
        local side = dt.sideOf(g, keyCode)
        if side then
            g.sidesSeen[side] = (g.sidesSeen[side] or 0) + 1
        elseif g.side == "left" or g.side == "right" then
            dt.noteUnknownSide(g)
        end
        if not dt.sideOK(g, side) then g.dirty = true end
    elseif down and g.downAt ~= nil then
        if others then g.dirty = true end        -- ⇧ joined a held ⌘
    elseif not down and g.downAt ~= nil then
        local held = now - g.downAt
        g.downAt = nil
        if g.dirty or others or held > (g.maxHold or dt.maxHold) then
            -- Not a tap, and it breaks any sequence in progress: a tap
            -- then a chord must not leave half a gesture armed for the
            -- next tap a minute later.
            g.lastTapAt, g.dirty = 0, false
            return false
        end
        g.dirty = false
        if g.lastTapAt > 0 and (now - g.lastTapAt) <= (g.tapGap or dt.tapGap) then
            g.lastTapAt = 0
            return true
        end
        g.lastTapAt = now
    end
    return false
end

-- Any real key press means the modifier around it was a chord, not a
-- tap — and it cancels a sequence already half made.
function dt.onIntruder(g)
    -- Nothing armed, nothing to cancel. This is the scroll-wheel hot
    -- path — one comparison, then out — and it is why watching scroll
    -- costs nothing measurable.
    if g.downAt == nil and g.lastTapAt == 0 then return end
    g.dirty, g.lastTapAt = true, 0
end

function dt.resetState(g)
    g.downAt, g.dirty, g.lastTapAt = nil, false, 0
end

-- A side setting this Mac cannot honour is a gesture that has quietly
-- stopped working, and the one thing worse than that is not being told.
-- Counted always; said ONCE, at the limit — a line per keypress is a
-- scroll, not a warning.
function dt.noteUnknownSide(g)
    g.sideUnknown = (g.sideUnknown or 0) + 1
    if g.saidUnknown or g.sideUnknown < dt.sideUnknownLimit then return end
    g.saidUnknown = true
    print("⌨️ " .. dt.glyph(g.mod) .. ": " .. g.sideUnknown .. " " .. g.mod
          .. " presses could not be attributed to a left or right key, so "
          .. "the gesture is being refused. Set side = \"either\" to take "
          .. "the side out of it.")
    if _G.notices then
        pcall(_G.notices.record, "runtime", "double tap",
              dt.glyph(g.mod) .. " refused — no side on the keycode")
    end
end

-- ---- registration ----------------------------------------------------
-- cfg: { mod = "cmd", side = "either", action = fn, label = "…",
--        maxHold = n, tapGap = n }
function dt.register(name, cfg)
    if type(name) ~= "string" or type(cfg) ~= "table" then
        return nil, "a gesture needs a name and a table"
    end
    if not dt.MOD_KEYS[cfg.mod] then
        return nil, "not a modifier this engine knows: " .. tostring(cfg.mod)
    end
    if type(cfg.action) ~= "function" then
        return nil, "a gesture with no action is a tap that does nothing"
    end
    -- 🚨 TWO GESTURES ON ONE MODIFIER CANNOT BOTH BE RIGHT unless they
    -- are on different SIDES: the first to complete would fire and the
    -- second would see a state machine it did not drive. Refused by
    -- name, with the holder named, rather than silently shadowing.
    for _, g in ipairs(dt.gestures) do
        if g.name ~= name and g.mod == cfg.mod
           and (g.side == cfg.side or g.side == "either" or cfg.side == "either") then
            return nil, dt.glyph(cfg.mod) .. " is already " .. g.name .. "'s"
        end
    end
    dt.unregister(name)
    local g = {
        name = name, mod = cfg.mod, side = cfg.side or "either",
        action = cfg.action, label = cfg.label or name,
        maxHold = cfg.maxHold, tapGap = cfg.tapGap,
        downAt = nil, dirty = false, lastTapAt = 0,
        sidesSeen = { left = 0, right = 0 }, sideUnknown = 0,
        fires = 0, sideReadable = true,
    }
    dt.resolveCodes(g)
    dt.gestures[#dt.gestures + 1] = g
    dt.byName[name] = g
    return g
end

function dt.unregister(name)
    local g = dt.byName[name]
    if not g then return false end
    for i, other in ipairs(dt.gestures) do
        if other == g then table.remove(dt.gestures, i) break end
    end
    dt.byName[name] = nil
    return true
end

-- ---- the tap ---------------------------------------------------------
-- The body is kept OUT of the callback so the callback is nothing but
-- pcall and a return false (6.235.0).
local function onEvent(ev)
    -- Synthetic keys are not gestures. Checked FIRST, before any state
    -- is touched, so an injection cannot even CANCEL a sequence.
    if _G.typingInjection and _G.typingInjection() then return end
    -- ⇪ is F18 plus a synthetic ⌘⇧⌃⌥ chord (§3.12). `otherFlags` already
    -- rejects it, but saying so here means a change to the hyper
    -- implementation cannot quietly make ⇪ look like a bare ⌘ tap.
    if _G.hyperActive then
        for _, g in ipairs(dt.gestures) do dt.resetState(g) end
        return
    end
    if _G.hsPaused then return end
    local t = ev:getType()
    if dt.INTRUDER_TYPES[t] then
        for _, g in ipairs(dt.gestures) do dt.onIntruder(g) end
        return
    end
    local flags = ev:getFlags() or {}
    -- 🚨 pcall, AND NOT BECAUSE getKeyCode IS EXOTIC. It is the one call
    -- here that a stubbed, replayed or synthesised event may simply not
    -- carry, and a throw would be a throw inside a keyboard tap. nil is
    -- a perfectly good answer: it means "no side", which sideOK knows.
    local code = nil
    pcall(function() code = ev:getKeyCode() end)
    local now = (hs and hs.timer and hs.timer.secondsSinceEpoch
                 and hs.timer.secondsSinceEpoch()) or os.time()
    for _, g in ipairs(dt.gestures) do
        if dt.onFlags(g, flags, now, code) then dt.fire(g) end
    end
end

function dt.fire(g)
    g.fires = g.fires + 1
    dt.fires = dt.fires + 1
    dt.lastFire = dt.glyph(g.mod) .. " → " .. g.label
    local ok, err = pcall(g.action)
    if not ok then
        g.threw = (g.threw or 0) + 1
        dt.lastThrow = g.name .. ": " .. tostring(err)
        local door = (dt.core and dt.core.degrade)
                     or (_G.core and _G.core.degrade)
        if door then
            pcall(door, "Double tap " .. dt.glyph(g.mod), tostring(err))
        end
    end
end

-- 🚨 EVERY PATH RETURNS false.
function dt.handler(ev)
    local ok, err = pcall(onEvent, ev)
    if ok then
        dt.tapFailures = 0
        return false
    end
    dt.tapFailures = dt.tapFailures + 1
    dt.lastThrow = tostring(err)
    if dt.tapFailures >= dt.failLimit then
        dt.stop()
        print("⌨️ Double tap: the watcher threw " .. dt.failLimit
              .. " times in a row and has been switched off. Every hyper "
              .. "shortcut still works. Last error: " .. tostring(err))
        if _G.notices then
            pcall(_G.notices.record, "runtime", "double tap",
                  "watcher disabled after repeated failures")
        end
    end
    return false
end

function dt.start()
    if dt.tap then return true, "already running" end
    if #dt.gestures == 0 then return false, "no gesture wants it" end
    if not (hs and hs.eventtap and hs.eventtap.new) then
        return false, "this Hammerspoon has no event taps"
    end
    if #dt.WATCHED_TYPES == 0 then
        return false, "this Hammerspoon names none of the event types"
    end
    local okNew, tap = pcall(hs.eventtap.new, dt.WATCHED_TYPES,
                             function(ev) return dt.handler(ev) end)
    if not (okNew and tap) then
        dt.tapRunning = false
        return false, "macOS refused the double-tap watcher"
    end
    dt.tap = tap
    -- 6.265.0: created, wired, and REFUSING TO START is a different
    -- shape from "new threw", and on a beta OS it is the one this
    -- config keeps meeting. Only here does nilling the slot matter.
    local okStart = pcall(function() tap:start() end)
    dt.tapRunning = okStart and true or false
    if not okStart then
        dt.tap = nil
        return false, "the double-tap watcher would not start"
    end
    return true
end

function dt.stop()
    if dt.tap then pcall(function() dt.tap:stop() end) end
    dt.tap, dt.tapRunning = nil, false
    for _, g in ipairs(dt.gestures) do dt.resetState(g) end
    return true
end

-- ---- the report ------------------------------------------------------
function _G.doubleTapReport()
    local L = { "⌨️ DOUBLE TAP — ⌘⌘ · ⌥⌥ (one engine, one watcher)" }
    local function line(t) L[#L + 1] = t end
    if #dt.gestures == 0 then
        line("   gestures : none registered")
    else
        for _, g in ipairs(dt.gestures) do
            line("   " .. dt.glyph(g.mod) .. "       : " .. g.label
                 .. " · side " .. g.side .. " · " .. g.fires .. " fired"
                 .. (g.threw and g.threw > 0
                     and ("  ⚠️ " .. g.threw .. " threw") or ""))
            if not g.sideReadable then
                line("   ↳ ⚠️ this keyboard reports ONE keycode for both "
                     .. g.mod .. " keys, so the side setting cannot apply")
            end
            if (g.sideUnknown or 0) > 0 then
                line("   ↳ " .. g.sideUnknown .. " press(es) named no side")
            end
        end
    end
    -- 🔎 THREE STATES (6.196.1): never asked for · asked and refused ·
    -- running. "The gesture does nothing" reads the same in all three.
    if dt.tap and dt.tapRunning then
        line("   watcher  : running · " .. #dt.WATCHED_TYPES
             .. " event type(s) · " .. dt.fires .. " fire(s) this session")
    elseif #dt.gestures == 0 then
        line("   watcher  : not started — nothing has registered a gesture")
    else
        line("   watcher  : ⚠️ NOT RUNNING — macOS would not give this Mac "
             .. "an event tap, so the double taps do nothing")
    end
    if #dt.MISSING_TYPES > 0 then
        line("   ↳ ⚠️ this Hammerspoon does not name: "
             .. table.concat(dt.MISSING_TYPES, ", ")
             .. " — a chord may read as a gesture")
    end
    line("   timing   : a tap is under " .. dt.maxHold .. "s · two taps "
         .. "within " .. dt.tapGap .. "s are one gesture")
    if dt.lastFire then line("   last     : " .. dt.lastFire) end
    if dt.lastThrow then line("   ↳ ⚠️ last throw: " .. tostring(dt.lastThrow)) end
    -- 📏 THE COST THIS RELEASE CHOSE, said where it is read rather than
    -- left in a commit message: editor_picker's ⌃⌃ still runs its own
    -- copy of this engine on its own tap, on purpose (its tap is the one
    -- that watches keyDown globally, and 6.214.0 is what a mistake there
    -- costs). Folding it in is its own release.
    line("   ↳ ⌃⌃ (the editor picker) is NOT on this engine yet — it "
         .. "keeps its own tap until this one has been proven on a Mac")
    print(table.concat(L, "\n"))
end

-- 🔌 THE CORE CONTRACT: every file in core/ returns an INITIALISER, not
-- a table — `return function(core)` is the exact shape hs-install.sh
-- verifies before trusting an install, and test_diagnostics fails a
-- core file that skips it. The first draft returned `dt` directly and
-- the gate caught it, which is the sentry doing precisely its job: a
-- bare chunk() silently discards whatever function(core) expected.
return function(core)
    dt.core = core
    return dt
end
