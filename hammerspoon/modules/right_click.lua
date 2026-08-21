-- =====================================================================
-- MODULE: RIGHT CLICK (⇪⇧F) — a real right-click, wherever the pointer is
-- =====================================================================
-- LL: "I need a right key tool that works to generate a right-click for
-- files, chrome, etc. If it is anything that has a right-click, I want to
-- be able to access it."
--
-- Put the pointer over the thing. Press ⇪⇧F. The context menu opens —
-- Finder, Chrome, the Dock, a text field, anything, because what this
-- posts is the same rightMouseDown/rightMouseUp pair a two-button mouse
-- posts. Nothing is app-specific and nothing is guessed about the thing
-- under the pointer, which is why "anything that has a right-click"
-- really means anything.
--
--        ⇪⇧F        right-click at the pointer
--
-- The mouse grid (⇪X) has right-clicked since 6.45.0, but only as the
-- LAST step of aiming: ⇪X, type the cell letters, ⇧space. That is the
-- right tool when you need to get the pointer somewhere first, and the
-- wrong one when the pointer is already sitting on the file — three keys
-- and an overlay to do what one key should. This is the one key.
--
-- ---- ⏳ WHY IT WAITS A FEW MILLISECONDS FIRST -----------------------
-- 🚨 A CONTEXT MENU READS THE MODIFIERS THAT ARE HELD WHEN IT OPENS, and
-- ⇪⇧F means ⇧ is held at the moment you press it. That is not a
-- theoretical problem:
--
--     Finder    ⌥ swaps half the menu for its alternates ("Copy … as
--               Pathname" in place of "Copy")
--     Chrome    ⇧ deliberately bypasses a page's own custom menu and
--               shows Chrome's instead — a different menu, on purpose
--
-- So a click posted the instant the key goes down opens the WRONG MENU,
-- reliably, and looks like the feature half-working rather than like a
-- modifier leak. This module therefore posts nothing until the modifier
-- keys are actually up: it polls for them to clear, fires the moment
-- they do (a normal tap clears in well under a tenth of a second, so it
-- reads as instant), and after settleTimeout fires anyway rather than
-- swallowing the press — because a menu with the wrong items in it still
-- beats no menu and no explanation.
--
-- 🚨 6.132.0 — AND UNTIL NOW THERE WAS NO EXPLANATION.
-- LL: "I don't always have the same options when I use our right-click
-- tool." That is this, exactly. When the wait ran out with ⇧ still down,
-- the click went out anyway — silently — and Chrome answered it with its
-- own menu instead of the page's. Two menus, one key, nothing on screen
-- saying which one you were about to get, so the tool looked random.
--
-- Two changes, and the first one is the smaller:
--
--   · settleTimeout went 0.30 → 0.45. A third of a second is not long
--     enough to let go of a key you are still pressing when the shortcut
--     is a four-modifier chord; ⇪ is ⌘⌃⌥⇧ held together, and letting go
--     of all four is not one motion.
--   · A blind fire now SAYS SO — on screen, naming the modifiers that
--     were still down, and in _G.rightClickReport() as a running count.
--     The menu you get is still the wrong one. You now know it was.
--
-- ⚠️ IT STILL FIRES. Swallowing the press would trade a confusing menu
-- for a dead key, which is worse: a dead key gets pressed again, and the
-- second press has the same modifiers held as the first.
--
-- ⚠️ AND SOME MENUS REALLY ARE DIFFERENT, with nothing wrong anywhere.
-- Right-clicking a misspelled word in Chrome gives you Add to Dictionary
-- and the spelling suggestions; right-clicking the paragraph beside it
-- does not. That is the page and the app deciding what is under the
-- pointer, which is the one thing this module deliberately never guesses
-- at. Different thing under the pointer, different menu.
--
-- The posted events also carry EXPLICITLY EMPTY FLAGS, which is the same
-- protection from the other side: belt for the physical keys, braces for
-- anything the window server might attach on the way out.
--
-- ---- WHAT IT DOES NOT DO --------------------------------------------
-- It does not move the pointer, find the selected file, or ask
-- Accessibility what is under the cursor. Every one of those is a guess
-- about another application's insides, and this config has paid for that
-- kind of guess before. The pointer is where you put it; the click goes
-- there.
-- =====================================================================

local M = {
    name  = "Right Click",
    order = 7.7,
    family = "windows",
    cheatsheet = {
        title = "🖱 RIGHT CLICK (⇪⇧F)",
        entries = {
            { "⇪⇧F",  "Right-click wherever the pointer is — any app" },
            { "waits", "For ⇧ to come up first, so you get the normal menu" },
            { "says",  "If it gave up waiting, it tells you — that menu was" },
            { "",      "the modified one, not the usual one" },
            { "vs ⇪X", "The grid is the other way: aim first, ⇧space clicks" },
            { "check", "_G.rightClickReport() — how many fired, and where" },
        },
    },
}

function M.setup(core)
    local rc = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    rc.enabled       = true
    rc.key           = "f"           -- ⇪⇧F
    rc.keyMods       = { "shift" }
    -- ⏳ How long to wait for the modifier keys to come up before posting
    -- anyway. Long enough for a human to let go of a key they have already
    -- pressed; short enough that holding the key does not feel broken.
    -- 6.132.0: 0.30 → 0.45. See the header — ⇪ is four modifiers held at
    -- once and releasing all four is not one motion.
    rc.settleTimeout = 0.45
    rc.settleTick    = 0.02
    -- 📣 Say so when the wait ran out and the click went anyway. Off makes
    -- the tool silent again and the menus random again; it is a knob only
    -- because a person who has read the header may not want the alert.
    rc.warnOnBlind   = true
    rc.blindShow     = 4           -- seconds that warning stays up
    -- ----------------------------------------------------------------------

    rc.fires    = 0
    rc.blind    = 0         -- fires where the modifiers never came up
    rc.lastAt   = nil       -- the point of the last click
    rc.lastApp  = nil
    rc.lastWait = nil       -- how long we waited for the modifiers, in ms
    rc.lastBlind = nil      -- which modifiers were still down, last time
    rc.lastNote = nil       -- why the last one did not fire, if it did not
    rc.settleTimer = nil    -- HELD: an unreferenced hs.timer is collected

    local function say(m)  if _G.diag then _G.diag.say("rightclick", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("rightclick", m) end end

    -- ---- mouse truth, the same two-API dance window_move does -------------
    function rc.pointer()
        local fns = {}
        if type(hs.mouse.absolutePosition) == "function" then
            fns[#fns + 1] = hs.mouse.absolutePosition
        end
        if type(hs.mouse.getAbsolutePosition) == "function" then
            fns[#fns + 1] = hs.mouse.getAbsolutePosition
        end
        for _, fn in ipairs(fns) do
            local ok, p = pcall(fn)
            if ok and type(p) == "table" and p.x and p.y then return p end
        end
        return nil
    end

    local function axAvailable()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    function rc.modifiersHeld()
        local ok, mods = pcall(hs.eventtap.checkKeyboardModifiers)
        if not ok or type(mods) ~= "table" then return false end
        return (mods.cmd or mods.alt or mods.shift or mods.ctrl or mods.fn) == true
    end

    -- 📣 6.132.0 — WHICH ones, as symbols, for the blind-fire warning.
    -- "modifiers were still held" is a fact about the config; "⇧ was still
    -- held" is a fact about your hand, and only the second one tells you
    -- what to do differently. Returns "" when nothing is down.
    rc.MOD_SYMBOLS = {
        { key = "cmd", sym = "⌘" }, { key = "shift", sym = "⇧" },
        { key = "ctrl", sym = "⌃" }, { key = "alt",  sym = "⌥" },
        { key = "fn",  sym = "fn" },
    }

    function rc.heldNames()
        local ok, mods = pcall(hs.eventtap.checkKeyboardModifiers)
        if not ok or type(mods) ~= "table" then return "" end
        local out = {}
        for _, m in ipairs(rc.MOD_SYMBOLS) do
            if mods[m.key] then out[#out + 1] = m.sym end
        end
        return table.concat(out)
    end

    -- ---- the click itself -------------------------------------------------
    -- 🚨 BUILT BY HAND RATHER THAN hs.eventtap.rightClick, for one reason:
    -- setFlags. rightClick() gives no way to say "no modifiers", and this
    -- module's whole point is that the modifiers you are holding must not
    -- reach the menu.
    function rc.post(point)
        local e = hs.eventtap.event
        local ok, err = pcall(function()
            for _, t in ipairs({ e.types.rightMouseDown, e.types.rightMouseUp }) do
                e.newMouseEvent(t, point, {}):setFlags({}):post()
            end
        end)
        if ok then return true end
        -- An older hs without setFlags on a mouse event must not lose the
        -- feature — it loses only the extra protection, and says so once.
        local okFallback = pcall(function() hs.eventtap.rightClick(point) end)
        if okFallback then
            warn("posted through rightClick(); flags could not be cleared: "
                 .. tostring(err))
            return true
        end
        warn("could not post a right-click: " .. tostring(err))
        return false
    end

    local function frontAppName()
        local n
        pcall(function()
            local app = hs.application.frontmostApplication()
            if app then n = app:name() end
        end)
        return n or "?"
    end

    -- fire(point, waitedMs, stillHeld) — everything after the modifiers are
    -- settled, or after we gave up waiting for them. stillHeld is the
    -- symbols that were STILL down when the wait ran out, "" or nil when
    -- the wait ended properly.
    local function fire(point, waited, stillHeld)
        if not rc.post(point) then
            rc.lastNote = "the click could not be posted"
            hs.alert.show("🖱 Could not right-click — see the Console")
            return false
        end
        rc.fires   = rc.fires + 1
        rc.lastAt  = { x = point.x, y = point.y }
        rc.lastApp = frontAppName()
        rc.lastWait = waited
        rc.lastNote = nil
        local blind = (stillHeld and stillHeld ~= "") and stillHeld or nil
        rc.lastBlind = blind
        say(string.format("right-click at %d,%d in %s (waited %dms)%s",
            math.floor(point.x), math.floor(point.y), rc.lastApp, waited,
            blind and (" — BLIND, " .. blind .. " still held") or ""))
        -- 🚨 THE FIX FOR "I don't always have the same options". The click
        -- still went out; what changes is that you are told the menu you
        -- are looking at was opened under a live modifier, which is the
        -- one thing that makes the same key give two different menus.
        if blind then
            rc.blind = rc.blind + 1
            warn(("fired with %s still held after %dms — the menu may be the "
                  .. "modified one"):format(blind, waited))
            if rc.warnOnBlind then
                hs.alert.show(("🖱 %s was still held — this may be the %s menu,\n"
                    .. "not the normal one. Let go and press ⇪⇧F again.")
                    :format(blind, blind), rc.blindShow)
            end
        end
        return true
    end

    -- ---- ⇪⇧F -------------------------------------------------------------
    function rc.click()
        -- 🚫 NO ACCESSIBILITY, NO CLICK — and it says which, because a key
        -- that silently does nothing is the single most confusing kind of
        -- broken. Same message shape as the mouse grid's, which hits the
        -- same wall for the same reason.
        if not axAvailable() then
            rc.lastNote = "Accessibility is off"
            hs.alert.show("🖱 macOS will not let Hammerspoon click without "
                .. "Accessibility —\nSystem Settings → Privacy & Security → "
                .. "Accessibility.")
            warn("right-click requested with Accessibility off")
            return false
        end

        local point = rc.pointer()
        if not point then
            rc.lastNote = "the pointer position could not be read"
            hs.alert.show("🖱 Could not read where the pointer is")
            warn("no pointer position")
            return false
        end

        -- ⏳ One settle at a time. Pressing the key twice quickly must not
        -- leave two timers racing to post two clicks at two points.
        if rc.settleTimer then
            pcall(function() rc.settleTimer:stop() end)
            rc.settleTimer = nil
        end

        if not rc.modifiersHeld() then return fire(point, 0) end

        local waited = 0
        local okTimer = pcall(function()
            rc.settleTimer = hs.timer.doEvery(rc.settleTick, function()
                waited = waited + rc.settleTick
                local clear = not rc.modifiersHeld()
                if not (clear or waited >= rc.settleTimeout) then return end
                pcall(function() rc.settleTimer:stop() end)
                rc.settleTimer = nil
                -- 🚨 READ THE NAMES BEFORE POSTING, not after. The click
                -- takes the focus somewhere and the keys can come up in the
                -- same breath; asking afterwards reports "" for a fire that
                -- really was blind, which is the silence this release is
                -- about.
                local stillHeld = (not clear) and rc.heldNames() or nil
                -- 🚨 THE POINT IS RE-READ. The pointer can move during the
                -- wait — a trackpad is under your other hand — and a click
                -- posted at where it WAS is a click on the wrong thing.
                local now = rc.pointer() or point
                fire(now, math.floor(waited * 1000 + 0.5), stillHeld)
            end)
        end)
        if not (okTimer and rc.settleTimer) then
            -- No timer means no wait; the click still happens, which is the
            -- half of this that matters.
            warn("could not arm the settle timer — clicking immediately")
            return fire(point, 0)
        end
        return true
    end

    -- ---- 🩺 report --------------------------------------------------------
    function _G.rightClickReport()
        local L = { "🖱 RIGHT CLICK (⇪⇧F)" }
        L[#L + 1] = "   accessibility : " .. (axAvailable() and "granted" or "OFF — no click can be posted")
        L[#L + 1] = string.format("   fired         : %d time%s this session",
            rc.fires, rc.fires == 1 and "" or "s")
        L[#L + 1] = string.format("   blind         : %d of those fired with a "
            .. "modifier still down", rc.blind)
        if rc.blind > 0 then
            L[#L + 1] = "                   those are the ones where the menu "
                        .. "was not the usual one"
        end
        L[#L + 1] = string.format("   waits up to   : %dms for ⌘⇧⌃⌥ to come up "
            .. "(rc.settleTimeout)", math.floor(rc.settleTimeout * 1000 + 0.5))
        if rc.lastAt then
            L[#L + 1] = string.format("   last          : %d,%d in %s",
                math.floor(rc.lastAt.x), math.floor(rc.lastAt.y),
                tostring(rc.lastApp))
            L[#L + 1] = string.format("   waited        : %dms for the modifiers to clear",
                rc.lastWait or 0)
            if rc.lastBlind then
                L[#L + 1] = "   and gave up   : " .. rc.lastBlind
                            .. " was still held — that menu was the modified one"
            end
        else
            L[#L + 1] = "   last          : never — nothing has been clicked yet"
        end
        if rc.lastNote then
            L[#L + 1] = "   last refusal  : " .. rc.lastNote
        end
        local p = rc.pointer()
        L[#L + 1] = p and string.format("   pointer now   : %d,%d",
                                        math.floor(p.x), math.floor(p.y))
                      or  "   pointer now   : unreadable"
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if rc.enabled then
        core.hyperAddShortcut(rc.keyMods, rc.key, function() rc.click() end,
                              "right click")
    end
    core.provide("rightClick.click",  function() return rc.click() end)
    core.provide("rightClick.report", function() return _G.rightClickReport() end)

    _G.rightClick = rc
    M.rc     = rc
    M.config = rc
end

return M
