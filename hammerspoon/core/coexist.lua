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
-- 🪟 PANEL STACKING ORDER (6.68.0 · rebuilt around the chooser 6.148.0)
-- =====================================================================
-- LL, 6.68.0: "Bring the Hammerspoon tool window in front of shortcuts."
-- LL, 6.148.0: "Can you make all the tools pop in front of the cheat
-- sheet? Like the app picker/universal launcher."
--
-- The 6.68.0 table answered the first ask one panel at a time — the
-- pomodoro, then the ⌥Tab HUD, then the ⇪7 card — and every window
-- built since had to rediscover the problem. The second ask is the same
-- ask made universal, and it runs into a constraint the old table never
-- looked at:
--
-- 🚨 hs.chooser's panel sits at mainMenu+3 AND EXPOSES NO LEVEL API.
-- (HSChooser.m: `setLevel:(CGWindowLevelForKey(kCGMainMenuWindowLevelKey)
-- + 3)` — read from the Hammerspoon source, 2026-09-01.) Seventeen of
-- the tools here are choosers, and the old sheet at `overlay` (102) was
-- seventy-five levels ABOVE that rung: every picker the sheet told you
-- about opened UNDERNEATH it. The tools that DID pop in front — ⇪space,
-- ⇪I, the pads and the editors — are hs.webview windows, and every one
-- of them calls bringToFront(true), which parks it near screenSaver
-- (~1000). That is the behavior LL pointed at; the choosers can never
-- follow it, so the sheet comes down instead.
--
-- The chooser's rung cannot move, so the ladder is built AROUND it:
-- offsets from `mainMenu` (24 today), with the chooser's fixed +3 as
-- the landmark. The cheat sheet is the FLOOR — the statement
-- _G.escapePriorities already makes about Esc ("it closes last" IS
-- "it is drawn under everything"). The canvas cards live between the
-- sheet and the chooser, and only two things outrank the chooser: the
-- Key Caster (it shows what you press, and you press keys INTO
-- choosers) and the pomodoro (its 6.68.0 ask, unchanged).
--
-- 🚨 THE INVARIANTS ARE TESTED, not assumed: test_integration asserts
-- the sheet is below the chooser landmark, every card rung is above the
-- sheet, and the pomodoro still tops the ladder.
--
-- Deliberately NOT in this table, each ABOVE the whole ladder for its
-- own reason: every hs.webview panel (bringToFront(true), above), the
-- mouse grid and the screenshot area-picker (targeting overlays that
-- must beat everything), the keyboard legend strip (ambient and tiny),
-- and the screen veil (privacy — hard to lift by design).
_G.panelLevels = {
    focus      = -3,  -- ⇪Q dim: a backdrop even the sheet reads over
    cheatsheet = -2,  -- THE FLOOR. Everything pops in front of it.
    calendar   = -1,  -- ⇪- card — was at `overlay`, TIED with the sheet:
    rollup     = -1,  -- the 16:01 card — same tie, same fix
    taskcreator = -1, -- the Asana mirror card — same
    macpanel   = -1,  -- ⇪7 About-This-Mac card (6.120.0's ask, kept)
    switcher   = -1,  -- ⌥Tab HUD
    pinbadge   = -1,  -- win_pin's stickers
    popup      = 0,   -- and a panel with no row lands here: above the
                      -- sheet, below the chooser — safe by default
    -- [chooser =  3]    macOS's fixed rung: written down, not ours to set
    keycaster  = 4,   -- above even the chooser you are typing into
    clippreview = 4,  -- ⇪V's preview pane sits BESIDE its chooser, and a
                      -- rung above it so no other panel can slide between
                      -- the list and the text it is showing (6.154.0)
    hint       = 4,   -- the shortcut-hint card (6.163.0): over the picker
                      -- the key just opened, under the pomodoro
    pomodoro   = 5,   -- the 6.68.0 ask, still the top of the ladder
}

function _G.panelLevel(name)
    local base = 24    -- hs.canvas.windowLevels.mainMenu on every macOS to date
    pcall(function()
        local lv = (hs.canvas and hs.canvas.windowLevels or {}).mainMenu
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

-- ⏳ AND A SECOND SHAPE OF THE SAME IDEA (6.76.0): AN INJECTION THAT
-- OUTLIVES THE CALL THAT STARTED IT.
--
-- withInjection() below is scoped to a function call, which is right for
-- hs.eventtap.keyStrokes — that call has typed the characters by the time
-- it returns. It is WRONG for hs.eventtap.event:post(), which only queues
-- the event: the post returns immediately, the counter drops back to
-- zero, and the synthetic keystroke reaches the taps milliseconds later
-- looking exactly like a real one.
--
-- §3.12's hyper self-test posts four synthetic keys to find out whether
-- the hyper key actually fires. Without this, the Key Caster would draw
-- them on screen at every boot — a panel announcing keys you did not
-- press, which is the sort of small lie that teaches you to distrust the
-- whole display.
--
-- A DEADLINE, NOT A COUNTER, and deliberately so: this window is opened
-- by code that will not be on the stack when it needs to close, so there
-- is nobody left to decrement it. A deadline cannot leak — the worst a
-- forgotten one can do is stand the typing watchers down for the
-- fraction of a second it was given, and then it is over by itself.
_G.injectUntil = 0

function _G.typingInjection()
    if (_G.injectDepth or 0) > 0 then return true end
    return hs.timer.secondsSinceEpoch() < (_G.injectUntil or 0)
end

-- Stand the keystroke watchers down for the next `seconds`, for events
-- that are POSTED rather than typed. Capped hard at two seconds: this is
-- a window during which your real typing is ignored by autocorrect, the
-- expander and the Key Caster, and no legitimate burst of synthetic keys
-- takes anywhere near that long.
function _G.suppressTypingFor(seconds)
    local s = math.min(tonumber(seconds) or 0, 2.0)
    if s <= 0 then return 0 end
    local until_ = hs.timer.secondsSinceEpoch() + s
    if until_ > (_G.injectUntil or 0) then _G.injectUntil = until_ end
    return s
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
local function injectWatchdogCheck()
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
end
_G.injectWatchdog = hs.timer.doEvery(5, injectWatchdogCheck)

-- 🔋 6.144.0 — on battery this check runs once a minute instead of every
-- five seconds. The honest cost: a stuck guard — already a rare bug
-- caught past a pcall — could stand the typing features down for up to
-- a minute before this clears it, instead of up to seven seconds. The
-- rebuild preserves the running state, so a deliberately stopped
-- watchdog is never revived by a cadence change.
if _G.eco then
    _G.eco.register("injection watchdog", {
        normal = 5, saver = 60,
        apply = function(secs)
            local was, running = _G.injectWatchdog, true
            pcall(function() running = was:running() end)
            if was then pcall(function() was:stop() end) end
            _G.injectWatchdog = hs.timer.doEvery(secs, injectWatchdogCheck)
            if not running then pcall(function() _G.injectWatchdog:stop() end) end
        end,
    })
end

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
-- =====================================================================
-- ⎋ ESCAPE ORDER MIRRORS PANEL ORDER (6.78.0)
-- =====================================================================
-- LL: "make the shortcut key cheat sheet stay up instead of it grabbing
-- escape and closing. It should be the last window to close after all
-- other pop-ups."
--
-- 🚨 WHY IT WAS GRABBING IT. Only TWO things ever claimed Esc — the sheet
-- and the pomodoro — so the router had two members and every OTHER panel
-- was invisible to it. The sheet holds a bare-Esc hotkey the entire time
-- it is open, and a bare-Esc hotkey fires no matter which window has
-- focus. Open the sheet, then open a chooser or the calendar, press Esc,
-- and the SHEET closed: not because anything decided it should, but
-- because nothing had decided anything.
--
-- 🪟 AND THE ANSWER WAS ALREADY WRITTEN DOWN ONE TABLE UP. "Last to
-- close" is the same statement as "bottom of the stack": whatever is
-- drawn on top is what Esc should take first. So the two orders are the
-- same order, and the cheat sheet is the FLOOR of both — it is the
-- backdrop you read while you work the thing in front of it.
--
-- ⚠️ NOT EVERY PANEL BELONGS HERE. A claim means "Esc closes me", so
-- anything Esc must NOT close stays out on purpose:
--   · the screen veil — deliberately hard to dismiss; it has its own
--     panic chord (⌃⌥⌘⇧G) precisely so a stray Esc cannot lift it.
--   · the Key Caster — it is a display, not a dialog. Esc is a keystroke
--     it should be DRAWING, not obeying.
--   · the ⇪Q focus dim — the camera turns it on and off; an Esc that
--     lifted it would be undone by the next automation tick, which
--     reads as flicker, not as control. ⇪Q is its off switch.
_G.escapePriorities = {
    cheatsheet =   0,   -- THE FLOOR. Deliberately. It closes last.
    calendar   =  30,
    switcher   =  40,
    -- ⎋ 6.93.0 — LL, again: "Above any other hammerspoon window of any
    -- type, the cheat sheet should close last." The 6.78.0 rule was
    -- right but its ROSTER had rotted: every window built since —
    -- eleven choosers and four webview panels — was invisible to the
    -- router, so one Esc took them AND the sheet. The panels claim now:
    unified    =  55,   -- ⇪space search page
    recentdocs =  58,   -- ⇪I documents page
    capturepad =  72,   -- ⇪N pad — hiding it never loses the draft
    notepad    =  73,   -- ⇪pad2 pad — same shape; CLOSING FILES EVERYTHING,
                        -- so Esc here is always safe (6.102.0 — it ran on
                        -- the fallback 50 from 6.99.0 until the boot line
                        -- "'notepad' is not in _G.escapePriorities" told us)
    scratchpad =  74,   -- ⇪1 pad — hiding never loses text (saved as typed)
    taskform   =  75,   -- ⇪T form: real keyboard focus, like a chooser
    shoteditor =  80,   -- ⇪⇧4's editor — mid-edit, most modal
    ocredit    =  82,   -- ⇪⇧O's OCR text editor (6.116.0 — it shipped in
                        -- 6.115.0 claiming Esc with no declared priority
                        -- and ran on the fallback 50 until the boot line
                        -- named it, exactly as notepad did in 6.102.0).
                        -- ABOVE the chooser at 70 because it is opened FROM
                        -- that chooser, and above shoteditor because both
                        -- are unsaved-text windows and the one you are
                        -- typing into is the one Esc should cancel.
    chooser    =  70,   -- has real keyboard focus, so it goes near the top
    pomodoro   = 100,
    mousegrid  = 900,   -- drawn at screenSaver level, above everything
}

function _G.claimEscape(name, priority, active, handle)
    -- An omitted priority is looked up rather than defaulted to zero:
    -- zero is the cheat sheet's floor, and a panel that silently landed
    -- there is one the sheet closes INSTEAD of — the exact bug this
    -- table exists to end, reintroduced by a spelling mistake.
    --
    -- 🚨 SO AN UNLISTED NAME IS REPORTED, and lands ABOVE the floor
    -- rather than on it. Both halves matter: the message is how you find
    -- out, and the placement means that until you do, the new panel takes
    -- Esc too eagerly instead of the cheat sheet vanishing underneath it.
    -- Of the two ways to be wrong, only one of them is confusing.
    if priority == nil then
        priority = _G.escapePriorities[name]
        if priority == nil then
            priority = 50
            print("⎋ claimEscape: '" .. tostring(name) .. "' is not in "
                  .. "_G.escapePriorities — using 50. Add it to core/"
                  .. "coexist.lua so the order is decided in one place.")
            if _G.notices then
                pcall(_G.notices.record, "runtime", "escape router",
                      tostring(name) .. " has no declared priority")
            end
        end
    end
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
    -- 🚨 6.79.2 — nil MEANS "NOBODY IS ASKING ON THEIR OWN BEHALF", and it
    -- is not the same as priority zero. core/hyper_key.lua's Escape rescue
    -- calls this with no caller, and with `mine = 0` that made the cheat
    -- sheet — which sits at zero deliberately, so it closes last —
    -- ineligible for its own Esc. On a Mac running the event-tap
    -- dispatcher, where the sheet's own Carbon hotkey is dead, that left
    -- it IMPOSSIBLE TO CLOSE with the key it tells you to use.
    -- A caller outranks nothing; nil outranks nothing at all.
    local mine = nil
    for _, c in ipairs(_G.escapeClaims) do
        if c.name == caller then mine = c.priority or 0 end
    end
    local best
    for _, c in ipairs(_G.escapeClaims) do
        if c.name ~= caller and (mine == nil or (c.priority or 0) > mine) then
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

-- 🚨 "IS ANYTHING ELSE STILL ON SCREEN?" — asked SEPARATELY from "did it
-- handle the Esc?", and the difference is the whole feature.
--
-- routeEscape returns nil in two very different situations: nobody else
-- wanted it, and somebody wanted it but their handler THREW. It has to,
-- because for most callers that fall-through is right — you pressed Esc,
-- something should happen. For the cheat sheet it is exactly wrong: a
-- broken calendar handler would close the SHEET, which is neither what
-- you pressed Esc for nor something you can tell apart from a bug.
--
-- So the sheet asks this second question and stays put on a yes.
function _G.escapeOthersActive(caller)
    for _, c in ipairs(_G.escapeClaims) do
        if c.name ~= caller then
            local ok, live = pcall(c.active)
            if ok and live then return c.name end
        end
    end
    return nil
end

-- ---- the choosers, claimed centrally ---------------------------------
-- Fifteen of them, and not one had a claim. They are the popups most
-- likely to be open on top of the sheet — ⇪V, ⇪T, ⇪O, ⇪W and the rest —
-- and a chooser holds real keyboard focus, so Esc reaching the sheet
-- instead of the chooser is the most visible form of this bug.
--
-- ONE claim rather than fifteen, and it reads _G.choosers at Esc time
-- rather than at load time: init.lua fills that table well after this
-- file runs, and a list captured here would be permanently empty. It also
-- means a chooser added later is covered without touching this file.
function _G.visibleChooser()
    for _, c in pairs(_G.choosers or {}) do
        local ok, vis = pcall(function() return c:isVisible() end)
        if ok and vis then return c end
    end
    return nil
end

_G.claimEscape("chooser", nil,
    function() return _G.visibleChooser() ~= nil end,
    function()
        local c = _G.visibleChooser()
        if c then c:hide() end
    end)

end
