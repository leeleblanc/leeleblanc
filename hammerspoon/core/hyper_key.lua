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
--   3. _G.hyperSelfTest — presses ⇪⇧F19 and reads the answer
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
            elseif t == hs.eventtap.event.types.keyUp then
                hyperExit()
            end
            return false
        end
        if not _G.hyperDispatchEngaged then return false end
        if not _G.hyperActive then return false end
        return _G.hyperTapDispatch(ev, t, code)
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
          .. " — Caps Lock now depends entirely on the Carbon hotkey. The "
          .. "self-test will say whether that is enough on this Mac.")
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
-- So the config now PRESSES ITS OWN KEY and reads the answer, once, a
-- moment after boot.
--
-- WHAT IT PROVES AND WHAT IT DOES NOT. The chain has two links:
--        Caps Lock ──hidutil──► F18 ──this config──► your shortcut
-- hidutil's exit code proves the first and is already reported at §3.12.
-- This proves the second, by posting F18 itself. Nothing here can test
-- the physical key — that would need a finger — so if hidutil says the
-- remap took and this says the shortcut fires, the only thing left
-- between them is the keyboard.
--
-- ⚠️ IT POSTS FOUR SYNTHETIC KEYSTROKES: F18 down, ⇧F19 down, ⇧F19 up,
-- F18 up. All four are queued in one go and arrive in order, so the modal
-- is live for the few milliseconds between the first and the last. Three
-- deliberate choices make that safe: ⇧F19 is a key no Mac keyboard has
-- and nothing else binds, so in the worst case it lands in your document
-- as nothing at all; _G.suppressTypingFor() stands the three typing
-- watchers down for the window, so the Key Caster does not draw keys you
-- never pressed; and the evaluation below force-exits the modal if our
-- own keyUp went missing.
-- ⇪⇧F19 EXISTS FOR ONE REASON: to be pressed by the test below. ⇧F19 and
-- not a letter, because the probe posts a REAL keystroke and a real
-- keystroke lands in whatever you are typing if the binding does not
-- swallow it. F19 is on no Mac keyboard, macOS reserves nothing on it,
-- and nothing else in this config binds it.
--
-- Registered in BOTH tables by hand rather than through §3.12's
-- hyperBind: it has to exercise the same two paths a real shortcut does,
-- and it must NOT appear in the shortcut count or the cheat sheet, which
-- are for shortcuts you can actually press.
_G.hyperProbeFires = 0
local function probeFired() _G.hyperProbeFires = _G.hyperProbeFires + 1 end
pcall(function() _G.hyperModal:bind({ "shift" }, "f19", probeFired) end)
if _G.hyperDispatch then
    _G.hyperDispatch["shift+f19"] = { pressed = probeFired, source = "self-test" }
end

local function selfTestPost()
    local ev = hs.eventtap.event
    _G.hyperSelfTestInFlight = true
    if _G.suppressTypingFor then _G.suppressTypingFor(0.8) end
    ev.newKeyEvent({}, "f18", true):post()
    ev.newKeyEvent({ "shift" }, "f19", true):post()
    ev.newKeyEvent({ "shift" }, "f19", false):post()
    ev.newKeyEvent({}, "f18", false):post()
end

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

-- stage 1 = as configured.  stage 2 = after engaging the tap dispatcher.
function _G.hyperSelfTest(stage)
    stage = stage or 1
    _G.hyperSelfTestPending = true
    if not (_G.hyperModal and hs.eventtap and hs.eventtap.event) then
        _G.hyperSelfTestPending = false
        return false
    end

    local base = {
        carbon = _G.hyperCarbonPresses or 0,
        tap    = _G.hyperTapPresses or 0,
        probe  = _G.hyperProbeFires or 0,
    }
    local wasActive = _G.hyperActive

    local okPost, postErr = pcall(selfTestPost)
    if not okPost then
        _G.hyperSelfTestInFlight = false
        _G.hyperSelfTestPending = false
        _G.hyperVerified = nil
        alarm("⚠️ 🎹 The ⇪ self-test could not run: " .. tostring(postErr),
              { "Posting a synthetic keystroke needs Accessibility. The hyper",
                "key may well be fine — this only means it went unproven." })
        return false
    end

    -- HELD in _G: an unreferenced hs.timer is collected, and a collected
    -- timer never fires — which would remove the entire answer.
    _G.hyperSelfTestTimer = hs.timer.doAfter(0.5, function()
        _G.hyperSelfTestInFlight = false
        local carbon = (_G.hyperCarbonPresses or 0) - base.carbon
        local tap    = (_G.hyperTapPresses or 0) - base.tap
        local probe  = (_G.hyperProbeFires or 0) - base.probe

        -- Our own probe must never leave ⇪ latched on. It posted an F18
        -- keyUp, so a still-true flag here means that keyUp went missing —
        -- and every subsequent keystroke would be treated as a hyper
        -- chord, which is the worst thing this could possibly leave
        -- behind.
        if _G.hyperActive and not wasActive then
            _G.hyperActive = false
            pcall(function() _G.hyperModal:exit() end)
        end

        _G.hyperSelfTestResult = { stage = stage, carbon = carbon,
                                   tap = tap, probe = probe }

        -- ── the shortcut fired: the chain works ──────────────────────
        if probe > 0 then
            _G.hyperSelfTestPending = false
            _G.hyperVerified = true
            _G.hyperPath = (stage == 2 and "event tap (dispatcher)")
                or (carbon > 0 and tap > 0 and "carbon + tap")
                or (carbon > 0 and "carbon" or "event tap")
            if stage == 2 then
                alarm("🎹 ⇪ IS RUNNING WITHOUT CARBON on this Mac — and it works.",
                    { "This Mac's system hotkey layer (Carbon RegisterEventHotKey)",
                      "does not deliver, so the event-tap dispatcher has taken",
                      "over all " .. tostring(_G.hyperShortcutCount or 0)
                      .. " ⇪ shortcuts. Verified by pressing one.",
                      "KNOWN COST: the few NON-hyper global hotkeys in §0.3 use",
                      "Carbon directly and are still dead. ⇪ shortcuts are not." },
                    "🎹 ⇪ switched to its fallback",
                    "Carbon hotkeys are dead on this Mac; ⇪ works anyway")
            elseif carbon == 0 then
                alarm("🎹 ⇪ works, but the Carbon hotkey for F18 never fired — "
                    .. "the event tap is carrying it.",
                    { "Worth knowing: it is a real difference between your two",
                      "Macs, and it is the half that failed silently until",
                      "6.76.0 gave it a second path." })
            elseif _G.diag then
                pcall(_G.diag.say, "hyper",
                      "self-test: ⇪⇧F19 fired via " .. tostring(_G.hyperPath))
            end
            return
        end

        -- ── F18 arrived, the shortcut did not fire ───────────────────
        -- Retry on the dispatcher only if the TAP saw F18: the dispatcher
        -- lives inside that tap, so a tap that missed the key cannot
        -- rescue it, and engaging it would stop the modal being entered
        -- at all — trading a broken hyper key for a worse one.
        if tap > 0 and stage == 1 and _G.hyperKeyTap then
            pcall(function() _G.hyperModal:exit() end)
            _G.hyperActive = false
            _G.hyperDispatchEngaged = true
            print("🎹 ⇪ did not fire: F18 reached the config ("
                  .. (carbon > 0 and "Carbon" or "event tap")
                  .. ") but the shortcut bound to it never ran. Switching ⇪ "
                  .. "to the event-tap dispatcher and testing again…")
            _G.hyperSelfTest(2)
            return
        end

        _G.hyperSelfTestPending = false
        _G.hyperVerified = false

        if carbon > 0 or tap > 0 then
            _G.hyperDispatchEngaged = false
            alarm("🚨 🎹 THE HYPER KEY IS DEAD ON THIS MAC. F18 arrives and no "
                .. "shortcut runs, on either path.",
                { "Both ways in were tried: the Carbon hotkey and the event tap.",
                  "All " .. tostring(_G.hyperShortcutCount or 0)
                  .. " ⇪ shortcuts are unreachable. The menu bar and",
                  "_G.bootReport() still work, and nothing else is affected.",
                  "WHAT TO TRY, in order:",
                  "  1. System Settings → Privacy & Security → Accessibility:",
                  "     switch Hammerspoon off and on again, then reload.",
                  "  2. Quit anything that grabs keys globally (Karabiner, BTT,",
                  "     Keyboard Maestro, a corporate agent) and reload.",
                  "  3. _G.hyperSelfTest() re-runs this test on demand." },
                "🚨 ⇪ does not work on this Mac",
                "F18 arrives, no shortcut runs — see the Console")
        else
            alarm("🚨 🎹 THE HYPER KEY IS DEAD ON THIS MAC. A synthetic F18 "
                .. "never reached the config at all.",
                { "The shortcuts are registered; nothing is delivering the key.",
                  "This is upstream of every ⇪ binding, so all "
                  .. tostring(_G.hyperShortcutCount or 0) .. " are unreachable.",
                  "WHAT TO TRY, in order:",
                  "  1. Accessibility for Hammerspoon — off, on, reload.",
                  "  2. Check the 🎹 line above for what hidutil said about the",
                  "     Caps Lock remap; if that failed, ⇪ cannot work.",
                  "  3. _G.hyperSelfTest() re-runs this test on demand." },
                "🚨 ⇪ does not work on this Mac",
                "F18 never arrives — see the Console")
        end
    end)
    return true
end

-- Scheduled, never inline. Two seconds is after the boot line has printed
-- and after the module warm phase has started, so the answer arrives
-- where you are already looking rather than in the middle of the boot.
if _G.hyperSelfTestPending then
    _G.hyperSelfTestBootTimer = hs.timer.doAfter(2.0, function()
        pcall(_G.hyperSelfTest, 1)
    end)
end

end
