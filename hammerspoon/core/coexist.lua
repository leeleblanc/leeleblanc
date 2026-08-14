-- =====================================================================
-- core/coexist.lua — WHEN TWO FEATURES WANT THE SAME THING
-- =====================================================================
-- Lifted out of init.lua in 6.69.0, when init.lua crossed the 4,000-line
-- ceiling the integration suite holds it to. That ceiling is not
-- housekeeping: init.lua is the ORCHESTRATOR, and every line of feature
-- that settles in it is a line nothing can test in isolation.
--
-- Everything here answers one question in four places: TWO FEATURES WANT
-- THE SAME RESOURCE, WHO GETS IT?
--
--   the screen    two panels at one window level stack by whichever was
--                 shown last — undefined, which reads as "sometimes
--                 broken". _G.panelLevels writes the order down.
--   the Esc key   the cheat sheet holds a bare Esc the whole time it is
--                 open; the pomodoro wants it for ~20s after a phase
--                 ends. hs.hotkey settles that by enable order, which is
--                 an implementation detail rather than a policy.
--                 _G.routeEscape is the policy.
--   the keyboard  autocorrect and the text expander both watch every
--                 keystroke AND type back. Each had its own "am I
--                 injecting" flag, which is half of what is needed: a
--                 flag only tells the module that wrote it to stand down.
--   the clipboard multi-line snippets have to be pasted, which means
--                 borrowing your clipboard and putting it back — without
--                 the history watcher filing your own entry twice.
--
-- Loaded EARLY, right after core/notices.lua: the cheat sheet, the
-- pomodoro, the switcher, autocorrect and the expander all expect these
-- globals to exist by the time they set up. Called as chunk()(core) like
-- every other core file, though it needs nothing from it — the shape is
-- what matters, so this file can start taking configuration later
-- without every call site changing.
-- =====================================================================

return function(core)

-- =====================================================================
-- 🪟 PANEL STACKING ORDER (6.68.0)
-- =====================================================================
-- LL: "Bring the Hammerspoon tool window in front of shortcuts."
--
-- The pomodoro and the cheat sheet were both drawn at hs.canvas's
-- `overlay` level. Two windows at the SAME level are ordered by whichever
-- was shown last, which is why the timer sat behind the shortcut panel
-- some of the time and in front of it the rest — the stacking wasn't
-- wrong, it was UNDEFINED, and undefined reads as "sometimes broken".
--
-- So it is defined here, in one table, instead of as a magic string in
-- each module. The numbers are OFFSETS FROM `overlay`, not absolute
-- levels: an NSWindow level is just an integer and hs.canvas:level()
-- takes one, so "the cheat sheet's level plus three" survives macOS
-- renumbering the named constants in a way that hard-coded 200 would not.
--
-- 🚨 THE INVARIANT IS TESTED, not assumed: test_cheatsheet asserts
-- pomodoro > cheatsheet. Anything that quietly equalises them fails.
--
-- The Mouse Grid is NOT in this table on purpose. It sits at
-- `screenSaver` (~1000) because it is a targeting overlay that must be
-- above literally everything including these panels, and expressing that
-- as "overlay + 898" would obscure why.
_G.panelLevels = {
    cheatsheet = 0,   -- the reference level
    focus      = 0,
    popup      = 0,
    switcher   = 1,   -- ⌥Tab HUD: above the sheet, below the timer
    keycaster  = 2,   -- it shows what you just pressed, so it must not be
                      -- hidden BY what you just pressed: above the sheet
                      -- and the switcher, below the timer
    pomodoro   = 3,   -- ABOVE the cheat sheet — this is the ask
}

function _G.panelLevel(name)
    local base = 102   -- hs.canvas.windowLevels.overlay on every macOS to date
    pcall(function()
        local lv = (hs.canvas and hs.canvas.windowLevels or {}).overlay
        if type(lv) == "number" then base = lv end
    end)
    return base + (_G.panelLevels[name] or 0)
end

-- =====================================================================
-- ⌨️ ONE INJECTION GUARD FOR EVERY TAP THAT TYPES (6.69.0)
-- =====================================================================
-- This config now has TWO event taps watching every keystroke and typing
-- back into the document: autocorrect and the text expander. Each one
-- had its OWN "am I injecting" flag, which is exactly half of what is
-- needed — a flag only tells the module that wrote it to stand down.
--
-- What actually happens without a shared one:
--   · The expander fires `hte` → types "the". Autocorrect's tap sees
--     t, h, e as real typing and appends them to its word buffer, which
--     already held part of the trigger. Its next boundary check runs
--     against a word nobody typed.
--   · Worse in the other direction: autocorrect fixes "teh" → "the" by
--     sending backspaces and retyping. The expander's tap sees those
--     characters, and if the corrected word happens to END in a trigger,
--     it expands — a snippet fired by a spelling fix, which is
--     indistinguishable from a bug from where you are sitting.
--
-- 🚨 A COUNTER, NOT A BOOLEAN. Nested injection is a real state: an
-- expander snippet that ends in a word autocorrect wants to fix would
-- clear a boolean on the way out of the inner call and leave the outer
-- one unguarded. Counters compose; booleans do not.
--
-- ⏱ AND IT SELF-CLEARS. A throw between the increment and the decrement
-- would wedge the counter above zero forever, which silently switches
-- BOTH features off for the rest of the session — the quietest possible
-- failure. withInjection() decrements on the way out of a pcall, and the
-- watchdog below is the second line of defence.
_G.injectDepth = 0
_G.injectStartedAt = nil

function _G.typingInjection()
    return (_G.injectDepth or 0) > 0
end

-- Run fn with every keystroke watcher standing down. Returns fn's own
-- ok/err, so a caller can still report its own failure.
function _G.withInjection(fn)
    _G.injectDepth = (_G.injectDepth or 0) + 1
    _G.injectStartedAt = hs.timer.secondsSinceEpoch()
    local ok, err = pcall(fn)
    _G.injectDepth = math.max(0, (_G.injectDepth or 1) - 1)
    if _G.injectDepth == 0 then _G.injectStartedAt = nil end
    return ok, err
end

-- No injection can legitimately last two seconds. If one appears to,
-- something threw past a decrement and both typing features are now
-- switched off with nothing to switch them back on.
_G.injectWatchdog = hs.timer.doEvery(5, function()
    local at = _G.injectStartedAt
    if at and (hs.timer.secondsSinceEpoch() - at) > 2 then
        print("⌨️ Injection guard was stuck for >2s — cleared. Autocorrect "
              .. "and the text expander were both standing down until now.")
        if _G.notices then
            _G.notices.record("runtime", "injection guard",
                              "stuck above zero; cleared by the watchdog")
        end
        _G.injectDepth, _G.injectStartedAt = 0, nil
    end
end)

-- =====================================================================
-- 📋 BORROWING THE CLIPBOARD (6.69.0)
-- =====================================================================
-- Some snippets have to be PASTED rather than typed — anything with a
-- newline in it, because a synthetic Return in a chat box sends the
-- message instead of breaking the line. Pasting means putting text on
-- the pasteboard and putting the old contents back afterwards.
--
-- The shared pasteboard watcher below polls changeCount every 0.5s and
-- files whatever it finds into clipboard history. A borrow-and-restore
-- that straddles a poll would file your ORIGINAL clipboard entry a
-- second time — harmless, but it reorders the history you were about to
-- use. This lets the borrower say "the next change is mine".
_G.pasteboardSuppressUntil = 0
function _G.pasteboardSuppress(secs)
    _G.pasteboardSuppressUntil = hs.timer.secondsSinceEpoch() + (secs or 1.0)
end

-- =====================================================================
-- ⎋ WHO GETS ESCAPE (6.68.0)
-- =====================================================================
-- LL: "Everytime I hit escape the shortcut windows disappear. And, the
-- tool should be in the foreground so I [don't] accidently stop [the
-- timer by] escaping the shortcuts window first."
--
-- Two panels can want Esc at the same moment: the cheat sheet always
-- wants it (Esc closes it), and the pomodoro wants it for the ~20s after
-- a phase ends (Esc stops the timer). hs.hotkey resolves that by
-- ENABLE ORDER — the most recently enabled binding for a key wins — so
-- opening the sheet while the timer was flashing silently stole Esc from
-- the timer, and closing the sheet first was the only way to reach it.
-- Enable order is an implementation detail, not a policy, and a policy
-- is what this needs.
--
-- So: claimants register a priority and an "am I active right now?"
-- test, and whoever holds Esc asks this router FIRST. Highest active
-- priority wins; ties and inactive claimants are ignored. A claimant
-- whose handler throws does NOT swallow the keystroke — it reports and
-- lets the caller carry on, because an Esc that does nothing at all is
-- the worst of the three outcomes.
_G.escapeClaims = {}

-- priority: bigger wins. active(): true when this claimant wants Esc NOW.
function _G.claimEscape(name, priority, active, handle)
    if type(name) ~= "string" or type(active) ~= "function"
       or type(handle) ~= "function" then
        print("⎋ claimEscape: bad registration for " .. tostring(name))
        return false
    end
    for _, c in ipairs(_G.escapeClaims) do
        if c.name == name then
            c.priority, c.active, c.handle = priority or 0, active, handle
            return true
        end
    end
    table.insert(_G.escapeClaims, {
        name = name, priority = priority or 0, active = active, handle = handle,
    })
    return true
end

-- Called by whoever currently owns the Esc key. Returns the name of the
-- claimant that handled it, or nil meaning "it's yours, carry on".
function _G.routeEscape(caller)
    local mine = 0
    for _, c in ipairs(_G.escapeClaims) do
        if c.name == caller then mine = c.priority or 0 end
    end
    local best
    for _, c in ipairs(_G.escapeClaims) do
        if c.name ~= caller and (c.priority or 0) > mine then
            local ok, live = pcall(c.active)
            if ok and live and (not best or c.priority > best.priority) then
                best = c
            elseif not ok then
                print("⎋ escape router: " .. c.name .. " could not say whether "
                      .. "it wanted Esc — skipped")
            end
        end
    end
    if not best then return nil end
    local ok, err = pcall(best.handle)
    if not ok then
        print("⎋ escape router: " .. best.name .. " failed to handle Esc — "
              .. tostring(err))
        if _G.notices then
            _G.notices.record("runtime", "escape router",
                              best.name .. " failed to handle Esc: " .. tostring(err))
        end
        return nil          -- fall through: the caller still gets its Esc
    end
    if _G.diag then _G.diag.say("escape", best.name .. " took Esc from " .. tostring(caller)) end
    return best.name
end

end
