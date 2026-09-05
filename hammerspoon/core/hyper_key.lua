-- =====================================================================
-- core/hyper_key.lua — THE SECOND WAY INTO THE HYPER KEY, AND THE PROOF
-- THAT ONE OF THEM WORKS. 6.76.0
-- =====================================================================
-- Loaded from the very END of init.lua, after §3.12 has built the modal
-- and after _G.hyperFinalize() has registered every shortcut — this file
-- needs the complete dispatch table, so it cannot run any earlier.
--
-- 🚨 WHY THIS FILE EXISTS. LL's work Mac booted to:
--        🧭 MLC409N-150727 · 32 modules · 80 ⇪ shortcuts · 1.03s
--           All green.
-- and not one shortcut worked. "All dead now. Nothing happens."
--
-- Everything that line could see was true. Everything it could not see
-- was the problem. Ruled out with one measurement each, recorded here so
-- nobody spends that evening again:
--   Accessibility granted · hidutil remap applied and read back correct ·
--   Secure Input not held · zero hotkey conflicts · 107 modal bindings
--   registered · event taps alive · ⌥Tab (an event tap) still working.
-- And the one that decided it: holding Caps Lock for five seconds while a
-- timer printed _G.hyperActive gave FALSE. A probe logged "KEY 79 f18" on
-- every press, so F18 was arriving — and the hs.hotkey handler bound to
-- it was never called.
--
-- THE TWO LAYERS ARE NOT THE SAME MACHINERY, which is the whole point:
--   hs.hotkey   → Carbon's RegisterEventHotKey, dispatched by the system
--   hs.eventtap → a CGEventTap, which sees the key BEFORE Carbon does
-- A managed Mac can lose the first and keep the second — another process
-- holding the F18 registration, an MDM shortcut payload, a security
-- agent: a dozen things this config can neither see nor change. So the
-- answer is not to diagnose the cause. It is to stop depending on a
-- single path, and then to CHECK, rather than count.
--
-- ⚠️ BOTH PATHS ARE IDEMPOTENT ON PURPOSE. On a Mac where Carbon works,
-- the tap and the hotkey both fire for the same press: enter() on an
-- already-entered modal re-enables its bindings and is otherwise a no-op,
-- and _G.hyperActive is set to the value it already holds. A double-enter
-- costs nothing. A missing enter costs 107 shortcuts.
--
-- WHAT THIS FILE OWNS
--   1. the event tap on F18 — the second way in
--   2. _G.hyperTapDispatch — a complete, Carbon-free hyper keyboard,
--      inert until the self-test proves it is needed
--   3. _G.globalTapDispatch — the same for the plain ⌃⌥⌘ chords §0.4
--      never migrated, plus an Escape rescue so no panel can trap you
--   4. _G.hyperForwardChord — the ⌘⇧⌃⌥ forward, stamped so its own echo
--      cannot be mistaken for a keypress
--   5. _G.hyperSelfTest — presses ⇪⇧F19 and reads the answer
-- =====================================================================

return function(core)

local hyperEnter = core.enter
local hyperExit  = core.exit
local hyperCombo = core.combo

-- ---- path two: the event tap ----------------------------------------
-- F18's keycode is 79. Asked for by name rather than written as 79, with
-- 79 as the fallback, because hs.keycodes is the thing that knows and a
-- hard-coded constant that drifts is a shortcut that dies quietly.
local F18_CODE = 79
pcall(function()
    local c = hs.keycodes and hs.keycodes.map and hs.keycodes.map["f18"]
    if type(c) == "number" then F18_CODE = c end
end)
_G.hyperF18Keycode = F18_CODE

-- ---- the Carbon-free dispatcher -------------------------------------
-- Called from the tap below, and ONLY once the self-test has proven that
-- the modal's Carbon hotkeys do not fire on this Mac. It reproduces what
-- hs.hotkey.modal does — match the key and the real modifier flags
-- against a table, call pressed once, repeated on autorepeat, released on
-- the way up — using the same three functions the modal was given, from
-- the same table, so there is no second list of shortcuts to keep in step
-- with the first. _G.hyperDispatch is filled by §3.12's hyperBind, which
-- every hyper shortcut in the config already goes through, so this cannot
-- miss one the way a parallel registration list would.
--
-- ⚠️ IT RETURNS TRUE, i.e. it EATS the keystroke, and it must: the whole
-- point of a hyper shortcut is that ⇪X runs an action instead of typing
-- an x. A dispatcher that acted AND let the character through would put
-- stray letters into whatever you were typing.
--
-- 🔁 AND IT REFUSES THE FULL CHORD, which is what stops this from feeding
-- itself. Unclaimed hyper keys forward ⌘⇧⌃⌥+key so hyper still works with
-- Raycast and friends; that synthetic chord comes straight back through
-- this same tap a millisecond later. It cannot match a real binding —
-- every one of them is registered bare or with ⇧ alone, never with all
-- four — but "cannot", resting on a naming convention, is not the same as
-- "will not", and an infinite keyboard loop is not a bug you get to debug
-- comfortably. All four modifiers down is refused outright.
function _G.hyperTapDispatch(ev, t, code)
    -- 🚨 THE INJECTION GUARD, and the one exception to it. A shortcut
    -- must never run because ANOTHER module typed — autocorrect retyping
    -- a word while ⇪ is held would otherwise fire whatever ⇪ + those
    -- letters are bound to. The exception is the self-test below, whose
    -- synthetic keystroke exists precisely to reach this line; without it
    -- the test would measure its own suppression and report a working
    -- hyper key as dead.
    if _G.typingInjection and _G.typingInjection()
       and not _G.hyperSelfTestInFlight then
        return false
    end

    local f = ev:getFlags() or {}
    if f.cmd and f.shift and f.ctrl and f.alt then return false end

    local mods = {}
    if f.cmd   then mods[#mods + 1] = "cmd"   end
    if f.shift then mods[#mods + 1] = "shift" end
    if f.ctrl  then mods[#mods + 1] = "ctrl"  end
    if f.alt   then mods[#mods + 1] = "alt"   end

    local name = hs.keycodes.map[code]
    if not name then return false end
    local entry = _G.hyperDispatch and _G.hyperDispatch[hyperCombo(mods, name)]
    if not entry then return false end

    if t == hs.eventtap.event.types.keyUp then
        if entry.released then pcall(entry.released) end
        return true
    end

    -- Is macOS repeating a held key, or did you press it again? Only the
    -- event knows. Guarded because getProperty is the one call here that
    -- varies between Hammerspoon builds, and a missing property must
    -- degrade to "not a repeat" rather than take the keystroke down.
    local repeating = false
    pcall(function()
        repeating = ev:getProperty(
            hs.eventtap.event.properties.keyboardEventAutorepeat) == 1
    end)
    if repeating then
        -- No repeat handler means the shortcut is deliberately once-per-
        -- press. Still consumed: a held ⇪→ must not start typing arrows.
        if entry.repeated then pcall(entry.repeated) end
    elseif entry.pressed then
        pcall(entry.pressed)
    end
    return true
end

-- 🔁 FORWARDING A HYPER CHORD, stamped. §3.12 forwards ⌘⇧⌃⌥+key for every
-- hyper key nothing has claimed, so hyper keeps working with apps that
-- know nothing about Hammerspoon. That synthetic chord returns through
-- the tap below a millisecond later — and if ⇪ happened to be released in
-- that gap, the global branch would read it as a genuine ⌘⇧⌃⌥ hotkey
-- press and fire whatever is bound there. So the send time is written
-- down, and the global branch refuses the full chord until it expires.
-- 0.25s is generous for a round trip and short enough that a chord you
-- press by hand a moment later still works.
_G.hyperChordUntil = 0
_G.hyperChordGrace = 0.25
function _G.hyperForwardChord(key, mods, delay)
    _G.hyperChordUntil = hs.timer.secondsSinceEpoch() + _G.hyperChordGrace
    hs.eventtap.keyStroke(mods or _G.hyperMods, key, delay or 0)
end

-- ---- and the PLAIN global hotkeys, for the same reason ---------------
-- 🚨 6.77.0 — ⇪ WAS ONLY 107 OF THE SHORTCUTS. When 6.76.0 proved Carbon
-- dead it rescued the hyper key and left everything else where it found
-- it, with a line in the GUIDE admitting so. That was a report, not a
-- fix, and it left one genuine TRAP: ⇪/ opens a full-screen cheat sheet
-- whose Escape is a Carbon hotkey. A panel you can open and cannot close
-- is worse than a panel you cannot open.
--
-- So the same tap also carries the standalone global hotkeys — the plain
-- ⌃⌥⌘ chords §0.4 never migrated — out of _G.globalDispatch, which §0.3
-- fills from the one wrapper every hs.hotkey.bind in this config goes
-- through.
--
-- 🚨 THREE RAILS, and each one is load-bearing:
--
--   1. AT LEAST ONE MODIFIER. This runs when ⇪ is NOT held, so it is
--      looking at ordinary typing. A bare-key entry here would mean the
--      letter d runs a shortcut instead of typing a d — and bare keys
--      are exactly what a modal registers. Modal bindings never reach
--      hs.hotkey.bind, so none can be in this table; the rail is what
--      makes that structural rather than something to remember.
--
--   2. THE FULL ⌘⇧⌃⌥ CHORD IS REFUSED WHILE ONE IS IN FLIGHT. Unclaimed
--      hyper keys forward that chord, and it returns through this tap a
--      millisecond later. Release ⇪ inside that gap and the returning
--      chord looks like a real global hotkey — so ⇪G could fire the
--      screen-veil escape. §3.12 stamps _G.hyperChordUntil before every
--      forward and this refuses the chord until it expires.
--
--   3. EVERY ENTRY HERE IS PERMANENTLY ENABLED. Nothing that gets
--      enabled and disabled at runtime is created with hs.hotkey.bind —
--      the cheat sheet's keys and ⌥Tab's nav keys all use hs.hotkey.new,
--      which this wrapper never sees. A new hs.hotkey.bind that is later
--      :disable()d would be fired here while disabled, so hs-lint has a
--      rule for it rather than a comment.
--
-- ⎋ AND ESCAPE IS RESCUED SEPARATELY, because it is the one key whose
-- absence traps you. It is routed through coexist's escape router, so
-- whichever panel currently claims Esc gets it — cheat sheet, pomodoro,
-- or anything added later — without this file knowing any of their names.
function _G.globalTapDispatch(ev, t, code)
    if _G.typingInjection and _G.typingInjection()
       and not _G.hyperSelfTestInFlight then
        return false
    end

    local name = hs.keycodes.map[code]
    if not name then return false end
    local f = ev:getFlags() or {}

    if name == "escape" and not (f.cmd or f.shift or f.ctrl or f.alt) then
        if t ~= hs.eventtap.event.types.keyDown then return false end
        local ok, taker = pcall(function()
            return _G.routeEscape and _G.routeEscape() or nil
        end)
        return (ok and taker) and true or false
    end

    local mods = {}
    if f.cmd   then mods[#mods + 1] = "cmd"   end
    if f.shift then mods[#mods + 1] = "shift" end
    if f.ctrl  then mods[#mods + 1] = "ctrl"  end
    if f.alt   then mods[#mods + 1] = "alt"   end
    if #mods == 0 then return false end                        -- rail 1
    if #mods == 4 and hs.timer.secondsSinceEpoch()
                      < (_G.hyperChordUntil or 0) then
        return false                                           -- rail 2
    end

    local entry = _G.globalDispatch
                  and _G.globalDispatch[_G.globalCombo(mods, name)]
    if not entry then return false end

    if t == hs.eventtap.event.types.keyUp then
        if entry.released then pcall(entry.released) end
        return true
    end
    local repeating = false
    pcall(function()
        repeating = ev:getProperty(
            hs.eventtap.event.properties.keyboardEventAutorepeat) == 1
    end)
    if repeating then
        if entry.repeated then pcall(entry.repeated) end
    elseif entry.pressed then
        pcall(entry.pressed)
    end
    return true
end

-- 🛟 GUARDED, COUNTED, AND IT STANDS DOWN RATHER THAN DEGRADE THE
-- KEYBOARD. Every keystroke on this Mac goes through this callback. An
-- error escaping it does not stop — it repeats forever, makes the whole
-- keyboard slower, and macOS eventually switches the tap off anyway
-- without telling you which one or why. Five consecutive failures and it
-- takes itself out, loudly. Same contract as the other three taps.
--
-- ⚠️ THE F18 HALF DELIBERATELY DOES NOT CHECK THE INJECTION GUARD. A
-- modifier is not typing: standing it down during an injection would mean
-- a snippet expanding while you hold ⇪ silently drops the hyper key
-- mid-hold. The guard belongs on the half that RUNS things, which is
-- where it is, above.
_G.hyperTapFailures = 0
local MAX_FAILURES = 5

local function hyperTapCallback(ev)
    local ok, err = pcall(function()
        local t = ev:getType()
        local code = ev:getKeyCode()
        if code == F18_CODE then
            if t == hs.eventtap.event.types.keyDown then
                hyperEnter("tap")
                if _G.hyperVerifyOnRealPress then _G.hyperVerifyOnRealPress() end
            elseif t == hs.eventtap.event.types.keyUp then
                hyperExit()
            end
            return false
        end
        -- 6.162.1: a key arriving while ⇪ is down proves the hold is real
        -- (the latch watchdog in init.lua §3.12 lets a SILENT hold go).
        if _G.hyperActive and _G.hyperTouch then _G.hyperTouch() end
        if not _G.hyperDispatchEngaged then return false end
        if _G.hyperActive then return _G.hyperTapDispatch(ev, t, code) end
        return _G.globalTapDispatch(ev, t, code)
    end)
    if ok then return err == true end

    _G.hyperTapFailures = _G.hyperTapFailures + 1
    print("⌨️ HYPER TAP error (" .. _G.hyperTapFailures .. "/"
          .. MAX_FAILURES .. "): " .. tostring(err))
    if _G.hyperTapFailures >= MAX_FAILURES then
        pcall(function() _G.hyperKeyTap:stop() end)
        print("⌨️ HYPER TAP STOPPED after " .. MAX_FAILURES
              .. " consecutive errors. Caps Lock now depends entirely on "
              .. "the Carbon hotkey; if that is dead on this Mac, ⇪ is off.")
        if _G.notices then
            pcall(_G.notices.record, "runtime", "hyper tap",
                  "stopped after " .. MAX_FAILURES .. " errors")
            pcall(_G.notices.tell, "⌨️ The ⇪ fallback switched itself off",
                  "See the Console — ⇪ may no longer work",
                  { key = "hypertap:dead", every = 900 })
        end
    end
    -- A tap that eats a keystroke when it fails has taken a character and
    -- given nothing back. Never consume on the failure path.
    return false
end

-- Created and started inside a pcall: hs.eventtap.new needs Accessibility
-- and a working hs.eventtap, and neither is guaranteed. Losing the
-- fallback must cost the fallback, not the boot.
local tapOK, tapErr = pcall(function()
    _G.hyperKeyTap = hs.eventtap.new(
        { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
        hyperTapCallback)
    _G.hyperKeyTap:start()
end)
if not tapOK then
    _G.hyperKeyTap = nil
    print("⚠️ 🎹 The ⇪ event-tap fallback could not start: " .. tostring(tapErr)
          .. " — Caps Lock now depends entirely on the Carbon hotkey, AND "
          .. "⇪ can no longer be verified at all: the check runs inside "
          .. "that tap. If your shortcuts work, nothing is wrong; if they "
          .. "do not, this line is the reason there is no second opinion.")
    pcall(function() _G.diag.warn("hyper", "event-tap fallback: "
          .. tostring(tapErr)) end)
end

-- =====================================================================
-- 🔬 DOES THE HYPER KEY ACTUALLY FIRE?
-- =====================================================================
-- Everything the boot line knew about the hyper key was a COUNT. "80 ⇪
-- shortcuts" meant eighty combos had been handed to hs.hotkey.modal and
-- none had complained. Registering is not firing, and rule 7 says nothing
-- may fail silently — a count is exactly how a keyboard fails silently:
-- every part reports success and the whole does nothing.
--
-- 🚨 6.79.0 — AND THE FIRST ANSWER TO THAT WAS WRONG, ON THE MAC WHERE
-- EVERYTHING WORKS. 6.76.0 tested it by POSTING a synthetic F18 and
-- watching for the Carbon handler. LL's MacBook Air — where ⇪ has worked
-- for sixty releases — booted to:
--        🎹 ⇪ did not fire: F18 reached the config (event tap) but the
--           shortcut bound to it never ran.
--        🎹 ⇪ IS RUNNING WITHOUT CARBON on this Mac — and it works.
-- and switched a perfectly healthy Mac onto the fallback. Not a cosmetic
-- error either: the fallback stops entering the modal, which really does
-- cost the cheat sheet's type-to-filter and ⌥Tab's arrow keys on a
-- machine that had them.
--
-- WHY IT WAS WRONG, and it is worth stating flatly because I assumed the
-- opposite when I wrote it: a CGEvent posted by hs.eventtap does NOT
-- reliably reach Carbon's RegisterEventHotKey dispatch. Event taps see
-- it — that half was real, and it is why the tap path scored. So the
-- probe could only ever measure "did the tap see it", and the Carbon
-- half read zero on every Mac, healthy or not. A test whose negative
-- result is the same on a working machine and a broken one is not a
-- test, and this one had a side effect.
--
-- ✅ SO VERIFICATION MOVED ONTO THE KEY YOU ACTUALLY PRESS. No synthetic
-- events, and nothing to be wrong about: the tap sees a REAL F18 keyDown
-- before Carbon does, notes the Carbon counter, and looks again a quarter
-- of a second later. Carbon fired → both paths work, verified, never
-- checked again. Carbon did not → its F18 hotkey genuinely does not
-- dispatch on this Mac, which is exactly the work Mac's symptom, measured
-- exactly the way LL measured it by hand: hold Caps Lock, read the flag.
--
-- The cost is that ⇪ is proven on your first Caps Lock press instead of
-- two seconds after boot. That is a better moment anyway — it is the real
-- key, in the real conditions, rather than an imitation of it.
_G.hyperVerified   = nil     -- nil = not yet observed
_G.hyperRealChecks = 0

local function alarm(headline, lines, screenTitle, screenBody)
    print(headline)
    for _, l in ipairs(lines or {}) do print("   " .. l) end
    if _G.diag then pcall(_G.diag.warn, "hyper", headline) end
    if _G.notices then
        pcall(_G.notices.record, "hyper", "self-test", headline)
        if screenTitle then
            pcall(_G.notices.tell, screenTitle, screenBody,
                  { key = "hyper:selftest", every = 3600 })
        end
    end
end

-- Called from the tap on every real F18 keyDown, and does nothing at all
-- after the first conclusive answer. One boolean and one timer: this runs
-- inside a keystroke callback, so it has to cost nothing once it is done.
function _G.hyperVerifyOnRealPress()
    -- 🚨 A POSTED F18 IS NOT A PRESS, and this line is the whole reason
    -- 6.76.0 went wrong wearing a different hat. The probe below posts an
    -- F18; the tap sees it exactly like a real one and would call us; a
    -- posted event does not reach Carbon; and we would conclude Carbon is
    -- dead — the original bug, rebuilt through the new mechanism. The
    -- flag the probe already sets is the fix.
    if _G.hyperSelfTestInFlight then return end
    if _G.hyperVerified ~= nil or _G.hyperVerifyPending then return end
    _G.hyperVerifyPending = true
    _G.hyperRealChecks = (_G.hyperRealChecks or 0) + 1
    local before = _G.hyperCarbonPresses or 0

    -- 0.25s: Carbon dispatches on the same run loop this tap is on, so
    -- the handler has run long before then if it is going to. Generous
    -- rather than tight, because the cost of waiting is nothing and the
    -- cost of asking too early is switching a working Mac to a fallback.
    _G.hyperVerifyTimer = hs.timer.doAfter(0.25, function()
        _G.hyperVerifyPending = false
        _G.hyperSelfTestPending = false
        local fired = (_G.hyperCarbonPresses or 0) > before

        if fired then
            _G.hyperVerified = true
            _G.hyperPath = "carbon + tap"
            if _G.diag then
                pcall(_G.diag.say, "hyper",
                      "verified on a real Caps Lock press: carbon + tap")
            end
            return
        end

        -- Carbon's F18 hotkey did not run for a key it definitely
        -- received — the tap is what called us, so the key arrived. That
        -- is the work Mac, measured the way LL measured it by hand.
        --
        -- 🚨 AND THE MODAL IS EXITED ON THE WAY IN. The press that proved
        -- Carbon dead entered the modal a quarter-second ago, back when
        -- the tap still did that — and hyperExit() will decline to leave
        -- it now, because from here on the dispatcher owns ⇪. Without
        -- this line the modal stays entered for the rest of the session
        -- with all 107 of its hotkeys enabled: dead weight while Carbon
        -- is dead, and a double dispatch the moment it is not.
        _G.hyperDispatchEngaged = true
        _G.hyperActive = false
        pcall(function() _G.hyperModal:exit() end)
        _G.hyperVerified = true
        _G.hyperPath = "event tap (dispatcher)"
        local globals = 0
        for _ in pairs(_G.globalDispatch or {}) do globals = globals + 1 end
        alarm("🎹 ⇪ IS RUNNING WITHOUT CARBON on this Mac — and it works.",
            { "Measured on a real Caps Lock press: F18 arrived, and this",
              "Mac's system hotkey layer (Carbon RegisterEventHotKey) did",
              "not dispatch it. The event-tap dispatcher has taken over all "
              .. tostring(_G.hyperShortcutCount or 0) .. " ⇪ shortcuts.",
              "The " .. tostring(globals) .. " standalone global hotkeys ride the same tap,",
              "and Escape is routed to whichever panel claims it, so",
              "nothing can open a sheet you cannot close.",
              "WHAT IS STILL DEGRADED, and it is only this: the keys that",
              "arm and disarm at runtime — the cheat sheet's type-to-",
              "filter and ⌥Tab's arrow navigation — use hs.hotkey.new and",
              "stay on Carbon. Both still OPEN, and Escape still closes." },
            "🎹 ⇪ switched to its fallback",
            "Carbon hotkeys are dead on this Mac; your shortcuts work anyway")
    end)
end

-- ---- the synthetic probe, kept as a DIAGNOSTIC only ------------------
-- 🚨 IT NO LONGER DECIDES ANYTHING, and that is the whole point of the
-- change above. Run it by hand when you want to see the two layers side
-- by side; read a zero in the Carbon column as "this told us nothing",
-- because a posted event is not guaranteed to reach Carbon at all.
--
-- ⇪⇧F19 exists for it to press: F19 is on no Mac keyboard, macOS reserves
-- nothing on it, and nothing else here binds it, so in the worst case the
-- keystroke lands in your document as nothing at all.
_G.hyperProbeFires = 0
local function probeFired() _G.hyperProbeFires = _G.hyperProbeFires + 1 end
pcall(function() _G.hyperModal:bind({ "shift" }, "f19", probeFired) end)
if _G.hyperDispatch then
    _G.hyperDispatch["shift+f19"] = { pressed = probeFired, source = "self-test" }
end

function _G.hyperSelfTest()
    if not (_G.hyperModal and hs.eventtap and hs.eventtap.event) then
        return false
    end
    local base = {
        carbon = _G.hyperCarbonPresses or 0,
        tap    = _G.hyperTapPresses or 0,
        probe  = _G.hyperProbeFires or 0,
    }
    local wasActive = _G.hyperActive

    local okPost, postErr = pcall(function()
        local ev = hs.eventtap.event
        _G.hyperSelfTestInFlight = true
        if _G.suppressTypingFor then _G.suppressTypingFor(0.8) end
        ev.newKeyEvent({}, "f18", true):post()
        ev.newKeyEvent({ "shift" }, "f19", true):post()
        ev.newKeyEvent({ "shift" }, "f19", false):post()
        ev.newKeyEvent({}, "f18", false):post()
    end)
    if not okPost then
        _G.hyperSelfTestInFlight = false
        print("⚠️ 🎹 The ⇪ probe could not run: " .. tostring(postErr)
              .. " — posting a synthetic keystroke needs Accessibility.")
        return false
    end

    -- HELD in _G: an unreferenced hs.timer is collected, and a collected
    -- timer never fires — which would remove the entire answer.
    _G.hyperSelfTestTimer = hs.timer.doAfter(0.5, function()
        _G.hyperSelfTestInFlight = false
        local carbon = (_G.hyperCarbonPresses or 0) - base.carbon
        local tap    = (_G.hyperTapPresses or 0) - base.tap
        local probe  = (_G.hyperProbeFires or 0) - base.probe

        -- The probe must never leave ⇪ latched on. It posted an F18
        -- keyUp, so a still-true flag here means that keyUp went missing —
        -- and every subsequent keystroke would be read as a hyper chord,
        -- which is the worst thing this could leave behind.
        if _G.hyperActive and not wasActive then
            _G.hyperActive = false
            pcall(function() _G.hyperModal:exit() end)
        end

        _G.hyperSelfTestResult = { carbon = carbon, tap = tap, probe = probe }
        print(("🔬 ⇪ probe — event tap saw F18: %s · Carbon saw F18: %s · "
               .. "⇪⇧F19 ran: %s"):format(tap, carbon, probe))
        print("   Carbon at 0 here proves NOTHING: a posted event does not "
              .. "reliably reach Carbon's hotkey dispatch. What decides it "
              .. "is your next real Caps Lock press.")
        print("   Verified: " .. tostring(_G.hyperVerified)
              .. "  ·  path: " .. tostring(_G.hyperPath or "not yet observed"))
    end)
    return true
end

end
