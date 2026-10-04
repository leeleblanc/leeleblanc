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
    pinbadge   = -1,  -- win_pin's stickers (module removed 6.166.0; rung kept)
    popup      = 0,   -- and a panel with no row lands here: above the
                      -- sheet, below the chooser — safe by default
    -- [chooser =  3]    macOS's fixed rung: written down, not ours to set
    keycaster  = 4,   -- above even the chooser you are typing into
    clippreview = 4,  -- ⇪V's preview pane sits BESIDE its chooser, and a
                      -- rung above it so no other panel can slide between
                      -- the list and the text it is showing (6.154.0)
    hint       = 4,   -- the shortcut-hint card (6.163.0; module deleted
                      -- 6.268.0, rung kept as pinbadge's is above)
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
-- withInjection() below is scoped to a function call. 🚨 6.218.0: that
-- is NOT enough for hs.eventtap.keyStrokes either — this comment said
-- "that call has typed the characters by the time it returns" for 142
-- releases and it was the one wrong line: keyStrokes POSTS, the post
-- returns immediately, the counter drops back to zero, and the
-- synthetic keystrokes reach the taps milliseconds later looking
-- exactly like real ones. That is how autocorrect corrected its own
-- retype for ever (LL's 6.216.0 "banshee"). Each tap that posts keys
-- must hold its OWN guard until the keys have drained — autocorrect
-- counts them off (acType), the expander holds a timer. The same was
-- always true of hs.eventtap.event:post():
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
-- 📋 WRITING TO THE PASTEBOARD (6.325.0)
-- =====================================================================
-- 🔎 hs.pasteboard.setContents REFUSES BY RETURNING FALSE AND NEVER
-- THROWS. 6.198.0 wrote that down and named text_expander and
-- url_cleaner as the files still carrying the shape it forbids:
--
--     pcall(function() hs.pasteboard.setContents(x) end)   -- true either way
--
-- 6.319.0 found a THIRD in screenshots.lua and added the rule that a
-- list of files named in a note is a SAMPLE unless somebody has
-- grepped. Somebody has now: of the setContents call sites in this
-- config, a handful read the return and the rest do not. THREE of them
-- announce "📋 Copied" unconditionally — ⇪D's unified search, ⇪V's
-- clipboard history and ⇪O's OCR log — so on a Mac where macOS refuses
-- the write (his own Console counted three refused ALERTS in eight
-- hours, and the pasteboard is refused by the same class of
-- transition) he is told his text was copied, presses ⌘V, and gets
-- whatever was there before. A message that is false at the moment it
-- is acted on is the worst shape a message can have (6.198.0).
--
-- 🔑 LIFTED FROM shots.copyOut, never written beside it: that function
-- has been right since 6.319.0, and a second copy of "did the
-- clipboard take it?" is a second copy to keep in step (6.231.0).
--
-- 🏠 IT LIVES HERE ON ITS MERITS, not because init.lua is full (it is —
-- 3,798 of its 3,800 lines). This file answers "two features want the
-- same resource, who gets it?", and the PASTEBOARD is one of them: the
-- borrow guard and the suppress window directly above are about the
-- same object.
--
-- 📏 It deliberately does NOT alert on success. A caller that wants to
-- say "📋 Copied" says it when this answers true — which is the whole
-- point: the sentence becomes conditional on the thing it describes.
_G.clipWrites = { asked = 0, wrote = 0, refused = 0, empty = 0, last = nil }

function _G.clipWrite(text, who)
    local st = _G.clipWrites
    who  = tostring(who or "a tool")
    text = (type(text) == "string") and text or ""
    st.asked = st.asked + 1
    local function record(ok, why)
        -- 🕒 the EPOCH, never a formatted string (6.282.0): macOS hands
        -- back a float here and os.date REFUSES one, which took a whole
        -- report down for eighteen releases.
        local at
        pcall(function() at = hs.timer.secondsSinceEpoch() end)
        st.last = { ok = ok, why = why, who = who, chars = #text,
                    at = (type(at) == "number") and at or os.time() }
        return ok, why
    end
    if text == "" then
        st.empty = st.empty + 1
        return record(false, "there was nothing to copy")
    end
    -- 🚨 `~= false`, not a bare truthiness test: a Hammerspoon whose
    -- setContents answers nil rather than a boolean must not read as a
    -- refusal, and one that answers false must not read as success.
    local wrote = false
    pcall(function() wrote = hs.pasteboard.setContents(text) ~= false end)
    if not wrote then
        st.refused = st.refused + 1
        -- 🔔 A BREAK IS SEEN, NEVER ONLY LOGGED (6.214.0), and it reaches
        -- the ledger and _G.todayReport() through the one door.
        if _G.degrade then
            pcall(_G.degrade, who, "macOS refused to put it on the clipboard — "
                  .. "nothing was copied, and whatever you had before is still there")
        elseif _G.notices and _G.notices.degrade then
            pcall(_G.notices.degrade, who, "macOS refused to put it on the clipboard")
        else
            pcall(function() hs.alert.show("⚠️ " .. who
                  .. " — macOS refused to put it on the clipboard", 6) end)
        end
        return record(false, "macOS refused the write")
    end
    st.wrote = st.wrote + 1
    return record(true)
end

function _G.clipboardWriteReport()
    local st = _G.clipWrites
    local L = { "📋 CLIPBOARD WRITES — this config putting text on the clipboard" }
    L[#L + 1] = "   asked  : " .. st.asked .. " · wrote " .. st.wrote
                .. " · nothing to copy " .. st.empty
    if st.refused > 0 then
        L[#L + 1] = "   ⚠️ REFUSED: " .. st.refused .. " write(s) macOS would not take."
        L[#L + 1] = "      Before 6.325.0 each of those said \"📋 Copied\" anyway."
    else
        L[#L + 1] = "   refused: none — macOS took every write it was asked for"
    end
    if st.last then
        L[#L + 1] = "   last   : " .. (st.last.ok and "✅ " or "❌ ") .. st.last.who
                    .. " · " .. st.last.chars .. " character(s) · "
                    .. os.date("%H:%M:%S", math.floor(tonumber(st.last.at) or 0))
                    .. (st.last.why and (" — " .. st.last.why) or "")
    else
        L[#L + 1] = "   last   : nothing has been copied through this door yet"
    end
    local out = table.concat(L, "\n")
    print(out)
    return out
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
    musicplayer = 32,  -- 6.231.0 — a corner card like the calendar, so it
                       -- sits beside it: Esc takes the player first, the
                       -- calendar next, and the cheat sheet still last.
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
    vault      =  75,   -- ⇪3 vault — closing saves the open note first
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
    anchors    =  71,   -- ⇪⇧U's picker (6.180.0) — a chooser, opened over
    anchorsPick =  71,  -- whatever you were looking at, so it closes first
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

-- ---- who is holding Esc, right now -----------------------------------
-- 6.189.0. LL's cheat sheet would not close and there was no way to ask
-- why: every claim, its priority and its live active() answer were only
-- ever consulted inside a keystroke. This prints them.
--
-- It also prints the sheet's last REFUSAL, which is the line that
-- matters when something is stuck — a claimant reporting itself active
-- while nothing is on screen is exactly the failure the sheet now
-- insists past, and this names it.
--
-- ONE STRING (6.179.1): the console gate splices banners through a
-- report printed row by row.
function _G.escapeReport()
    local L = { "⎋ ESCAPE ROUTER" }
    local claims = _G.escapeClaims or {}
    if #claims == 0 then
        L[#L + 1] = "   no claims registered — every Esc falls through"
    else
        -- Highest first: this is the order routeEscape considers them in.
        local order = {}
        for _, c in ipairs(claims) do order[#order + 1] = c end
        table.sort(order, function(a, b)
            return (a.priority or 0) > (b.priority or 0)
        end)
        for _, c in ipairs(order) do
            -- active() belongs to another module and may throw; a report
            -- that dies on one bad claimant tells you nothing about the
            -- rest, which is the opposite of its job.
            local ok, live = pcall(c.active)
            local state = (not ok) and "⛔ active() threw"
                          or (live and "🟢 wants esc now" or "· idle")
            L[#L + 1] = string.format("   %-12s %4d  %s",
                                      tostring(c.name), c.priority or 0, state)
        end
    end
    local cs = _G.cheatSheet
    L[#L + 1] = "   sheet   : " .. (_G.cheatSheetCanvas and "open" or "closed")
    local r = _G.escapeLastRefusal
    if r then
        L[#L + 1] = string.format("   refused : %s — %s (press %s of %s)",
            tostring(r.who), tostring(r.why), tostring(r.run or 0),
            tostring(cs and cs.escInsist or "?"))
        L[#L + 1] = "             ↳ that is who is refusing to let the "
                    .. "sheet close"
    else
        L[#L + 1] = "   refused : nothing — the last esc was not deferred"
    end
    if cs and cs.escInsist then
        L[#L + 1] = string.format("   insist  : %s presses within %ss closes "
                                  .. "the sheet regardless",
                                  tostring(cs.escInsist),
                                  tostring(cs.escInsistWindow))
    end
    print(table.concat(L, "\n"))
    return #claims
end


-- =====================================================================
-- 🖐 DRAGGABLE CANVAS PANELS — lifted out of init.lua in 6.306.0
-- =====================================================================
-- A fifth thing two features want: THE POINTER. It sat in init.lua
-- because it was written there (6.67.0), and init.lua is at its
-- 3,800-line budget — 6.285.0 moved _G.hyperEndVerdict for the same
-- reason. It belongs here on its own merits too: init.lua's file map
-- has filed "draggable panels" beside this file since §1.6 was written.
-- 📏 COST, NAMED: if this file fails to load, panels are no longer
-- draggable. Every caller already guards with `if _G.makeCanvasDraggable
-- then`, so that is a panel you cannot move, never a panel that breaks.
-- =====================================================================
-- 🖐 DRAGGABLE CANVAS PANELS (6.67.0)
-- =====================================================================
-- An hs.canvas has no title bar, so dragging is built once for every
-- panel: the press is caught on the canvas and the DRAG is followed by a
-- global eventtap (a canvas only reports movement while the pointer is
-- inside it, and a fast drag leaves it).
-- ⚠️ AN EVENTTAP IS THE MOST DANGEROUS OBJECT IN THIS CONFIG, so:
--   · it starts on mouseDown and stops on mouseUp;
--   · a WATCHDOG stops it after dragMaxSecs no matter what, because a
--     mouseUp delivered to another process is a mouseUp we never see;
--   · it returns false — it observes the drag, it does not swallow it;
--   · only ONE drag can be live at a time.
-- ⚖️ THE COST: a panel that can be grabbed CAPTURES CLICKS; the cheat
-- sheet no longer lets clicks fall through. Asked for, and accepted.
_G.dragMaxSecs = 20
_G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil

-- 🚪 6.306.0 — ONE EXIT, AND IT ALWAYS TELLS THE CALLER. LL, for the
-- SECOND time (6.138.0 was the first, in his words then: "Seems like a
-- drag kills the sheet functionality"), now: "just because I can launch
-- the cheat sheet doesn't mean it is functional", beside "when I move
-- the cheat sheet, I am jumped to another desktop".
-- 🔎 BOTH SENTENCES ARE ONE MECHANISM, and it is readable rather than
-- guessed. onDrop was reachable from exactly ONE of this engine's four
-- exits — the tap's leftMouseUp branch. The canvas's own mouseUp, the
-- watchdog, and the supersede at the top of a new drag all tore the drag
-- down SILENTLY. And onDrop is what does both of the things that keep the
-- sheet working: it moves the wheel's hit box (st.rect — 6.138.0's whole
-- fix) and it saves the position. So any drag whose mouseUp this tap did
-- not see left the panel physically moved with its hit box and its
-- remembered spot still at the old place: scrolling dead over the sheet,
-- still swallowed over the bare desk it used to cover, and the next open
-- back in the wrong spot. 6.138.0 fixed the update and put it behind the
-- one door that can fail to open.
-- 🖥 AND THE DESKTOP JUMP IS WHAT OPENS THAT FAILURE. This tap returns
-- false on purpose — it observes, it never swallows — so macOS sees the
-- drag too, and reads a three-finger one as a swipe between Spaces. A
-- Space switch mid-drag is exactly the transition macOS switches event
-- taps off across (6.303.0's own finding), so the mouseUp never arrives.
-- The jump may still happen; what changes here is that it no longer
-- costs him the panel.
-- 🧊 6.222.0's RULE, WHICH HAD ONLY EVER BEEN APPLIED TO A PAGE: "a drag
-- ends when the button comes up, WHEREVER that happens — listen for the
-- release, and ALSO treat moving with nothing held as the release." That
-- was written for the screenshot editor's own JS and never asked of this
-- helper, which drags four panels. 6.305.0's rule, one release later: a
-- rule written about one caller is not a rule until every caller has
-- been asked. And window_move already has the right shape — wm.endDrag
-- is one exit and runs endFn from every path, including its watchdog.
local function leftStillDown()
    local ok, btns = pcall(hs.eventtap.checkMouseButtons)
    if not (ok and type(btns) == "table") then return false end
    return btns.left == true or btns[1] == true
end

_G.dragDelivered, _G.dragNoFrame, _G.dragLastEnd = 0, 0, nil

-- THE DELIVERY LIVES IN dragStop ITSELF, not beside its callers: that is
-- what makes it impossible for a future exit to be added and forget
-- (6.299.0 — one door, and through it EXACTLY once).
local function dragStop(why)
    local d = _G.dragging
    if _G.dragTap   then pcall(function() _G.dragTap:stop()   end) end
    if _G.dragGuard then pcall(function() _G.dragGuard:stop() end) end
    _G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil
    if why and _G.diag then _G.diag.say("drag", "ended (" .. why .. ")") end
    -- 🗑 A `delivered` FLAG WAS WRITTEN HERE AND TAKEN OUT AGAIN (6.199.0,
    -- fifth time this project has made that call). Exactly-once is already
    -- structural: `d` is captured at the top and `_G.dragging` is nil'd
    -- BEFORE onDrop runs, so every later exit — a racing canvas mouseUp, a
    -- watchdog that was not stopped, a re-entrant call from inside onDrop
    -- itself — reads nil and returns here. The mutation sweep proved the
    -- flag unkillable: removing it failed no check, because nothing can
    -- reach the second call it guarded. A guard no test can fail is dead
    -- code with a comment on it. §4 asserts the real mechanism instead.
    if not (d and d.onDrop) then return end
    -- The panel has ALREADY moved by the time any exit is reached, so a
    -- caller that is not told is a caller whose record of where its panel
    -- sits is now wrong. The frame is read here, at the end, never from
    -- the caller's stale copy.
    local f
    pcall(function() f = d.canvas:frame() end)
    _G.dragLastEnd = { label = d.label, why = why or "superseded",
                       at = os.time(), got = f ~= nil }
    if f then
        _G.dragDelivered = _G.dragDelivered + 1
        pcall(d.onDrop, f)
    else
        -- A canvas that cannot answer its own frame is a panel nobody can
        -- record. Counted rather than swallowed: "never told" and "told
        -- wrongly" are different faults (6.196.1).
        _G.dragNoFrame = _G.dragNoFrame + 1
    end
end
_G.dragStop = dragStop

-- 🔎 The engine had no report at all, which is why this took two reports
-- from LL and a source read to find.
function _G.dragReport()
    local L = { "🖐 PANEL DRAG" }
    L[#L + 1] = ("   live   : %s"):format(_G.dragging
        and ("dragging " .. tostring(_G.dragging.label)) or "nothing is being dragged")
    L[#L + 1] = ("   drops  : %d delivered to the panel that moved"):format(_G.dragDelivered or 0)
    if (_G.dragNoFrame or 0) > 0 then
        L[#L + 1] = ("   ⚠️ %d drag(s) ended with a canvas that could not answer its own "
                     .. "frame — those panels moved and were never recorded"):format(_G.dragNoFrame)
    end
    local e = _G.dragLastEnd
    L[#L + 1] = e
        and ("   last   : %s ended by %s at %s%s"):format(e.label, e.why,
              os.date("%H:%M:%S", e.at), e.got and "" or " — NO FRAME")
        or  "   last   : no panel has been dragged this session"
    print(table.concat(L, "\n"))
end

-- onDrop(frame) is called when the drag finishes, so a caller can
-- REMEMBER where you put the panel. Without it a dragged panel snaps
-- back to its computed position the next time it is drawn — and the cheat
-- sheet redraws on every keystroke you type into it.
function _G.makeCanvasDraggable(canvas, label, onDrop)
    if not canvas then return false end
    local okEv = pcall(function() canvas:canvasMouseEvents(true, true, false, false) end)
    if not okEv then return false end
    local okCb = pcall(function()
        canvas:mouseCallback(function(cv, ev)
            if ev ~= "mouseDown" then
                if ev == "mouseUp" then dragStop("mouseUp on the panel") end
                return
            end
            dragStop(nil)                       -- never two at once
            local okM, m0 = pcall(hs.mouse.absolutePosition)
            local okF, f0 = pcall(function() return cv:frame() end)
            if not (okM and m0 and okF and f0) then return end
            -- onDrop rides on the drag itself, so every exit can reach it
            -- without the exit having to know the caller.
            _G.dragging = { canvas = cv, m0 = m0, f0 = f0, label = label,
                            onDrop = onDrop }

            -- 🚨 WATCHDOG FIRST, THEN THE TAP — the same ordering the
            -- Mouse Grid and the pomodoro use. Armed before the thing it
            -- protects exists, so a throw in between cannot leave a
            -- global mouse tap running with nothing scheduled to stop it.
            _G.dragGuard = hs.timer.doAfter(_G.dragMaxSecs, function()
                dragStop("watchdog — no mouseUp arrived")
            end)

            local T = hs.eventtap.event.types
            local watch = { T.leftMouseDragged, T.leftMouseUp }
            -- A Mac whose Hammerspoon has no mouseMoved type keeps the old
            -- two-event drag rather than failing to build a tap at all.
            if T.mouseMoved then watch[#watch + 1] = T.mouseMoved end
            local okTap, tap = pcall(hs.eventtap.new, watch, function(e)
                local d = _G.dragging
                if not d then return false end
                local t = e:getType()
                if t == T.leftMouseUp then
                    dragStop("mouseUp")
                    return false
                end
                if T.mouseMoved and t == T.mouseMoved then
                    -- 🧊 THE RELEASE WE NEVER SAW. macOS sends
                    -- leftMouseDragged while the left button is held and
                    -- mouseMoved when it is not, so a mouseMoved arriving
                    -- mid-drag IS the button coming up somewhere we were
                    -- not told about. checkMouseButtons is asked as a VETO
                    -- ONLY — window_move 6.156.0 paid for trusting it the
                    -- other way, where a consumed press reads as released
                    -- on the first tick and ends a drag before it moves.
                    -- Believing it only when it positively says "still
                    -- down" is safe in both directions: stale-as-released
                    -- ends the drag correctly, stale-as-held is no worse
                    -- than the behaviour this replaces.
                    if not leftStillDown() then
                        dragStop("the button came up elsewhere")
                    end
                    return false
                end
                local okNow, m = pcall(hs.mouse.absolutePosition)
                if not (okNow and m) then return false end
                pcall(function()
                    d.canvas:topLeft({ x = d.f0.x + (m.x - d.m0.x),
                                       y = d.f0.y + (m.y - d.m0.y) })
                end)
                return false        -- observe, never swallow
            end)
            if not (okTap and tap) then
                dragStop("could not create the drag tap")
                return
            end
            _G.dragTap = tap
            pcall(function() tap:start() end)
        end)
    end)
    return okCb
end

end
