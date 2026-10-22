-- =====================================================================
-- MODULE: TIMER (⇪⇧T) — say how long, in words, and forget about it
-- =====================================================================
-- Press the key, type a length the way you would say it out loud, press
-- Return. A small card appears under the clock in the top-right corner
-- and counts down. At zero it says so loudly and STAYS saying so, so a
-- timer that ends while you are away is still waiting when you get back.
--
--        ⇪⇧T        ask how long · and press it again to put the card away
--        esc        stop it      (see 🚨 THE ESC RULE below — it matters)
--
-- 📣 ANY OF THESE, and the box shows you what it understood before you
-- commit to it:
--        15s · 15 sec · 15 seconds
--        25                        (a bare number means MINUTES, and the
--                                   box says so while you are typing it)
--        24h and 35m
--        24 hours and five minutes
--        twenty five minutes · half an hour · an hour and a half
--        1h 30                     (a trailing number with no unit is the
--                                   next unit down — the box says so)
--        5m30s · 2d · 3 days
--
-- =====================================================================
-- 🚨 THE ESC RULE, AND WHY IT IS NOT "ESC WHILE THE CARD IS UP"
-- =====================================================================
-- LL asked for "when visible, hitting escape, stops the timer", and the
-- literal reading of that is a trap this config has already refused once.
-- Binding bare Esc through hs.hotkey SWALLOWS it system-wide for as long
-- as the binding is enabled — and a timer here can run for 24 hours. For
-- a day, Esc would not dismiss a dialog, would not leave a full-screen
-- film (he has the Mug Player), would not cancel a Spotlight search, and
-- NOTHING on screen would explain why. modules/pomodoro.lua's own header
-- refuses exactly this for ⏎ over 25 minutes; the same reasoning, longer.
--
-- 🔑 SO THE SHAPE THAT SATISFIES BOTH (6.311.0's rule: look for the shape
-- that satisfies both rules rather than trading one away) — bare Esc is
-- live in the two moments a person actually reaches for it, and the card
-- SAYS SO on its bottom line exactly when it is listening (6.203.0 — the
-- refusal is drawn where he is looking):
--    · while the POINTER IS OVER THE CARD — to stop a timer deliberately
--      you look at it, and the hover poll already exists for the alpha;
--    · for tm.escSecs after the card is brought up — "press the key, see
--      it, kill it" needs no mouse at all.
-- Outside those, Esc belongs to his apps. ⇪Esc stops it from anywhere,
-- through the escape router, which costs no app anything because that
-- key is already this config's.
--
-- 📏 COST, NAMED: press Esc while looking at the card with the pointer
-- elsewhere and more than tm.escSecs after it appeared, and nothing
-- happens. The bottom line is what tells you which state you are in.
-- =====================================================================
-- 🔑 HIDE IS NOT STOP, and that distinction is his, not mine. ⇪⇧T with
-- the card up PUTS IT AWAY AND THE TIMER KEEPS RUNNING; ⇪⇧T again brings
-- it back. Only Esc (or ⇪Esc, or the end of the countdown) ends it. Which
-- means a running timer can be invisible — so the announcement at zero is
-- load-bearing rather than decoration: the card shows ITSELF, flashes,
-- alerts, writes a Console line, and sends a notification that survives
-- Focus (6.278.0 — a 24-hour timer lands while he is in a meeting).
-- =====================================================================
-- 💾 IT SURVIVES A RELOAD, because the durations he asked for are longer
-- than the gaps between reloads — he reloads to install releases. The
-- deadline (one number) and the words he typed go into hs.settings on
-- start and stop, never on a tick, and M.warm restores it. THREE STATES
-- (6.196.1): still running · it ENDED while this config was not running,
-- said rather than fired hours late · nothing to restore.
-- =====================================================================
-- 🪟 IT LOOKS LIKE THE POMODORO because that is what was asked for: the
-- same corner, the same rounded card, the same shared style table, the
-- same alpha knobs. It is NOT the pomodoro's code — folding the two
-- cards into one drawing helper would be a second change in this release
-- and would touch a module that works, so the duplication is NAMED here
-- and the fold is its own release.
-- 🗓 And it does not sit ON the pomodoro: if that card is on screen when
-- this one opens, this one drops below it by tm.slotGap (tm.slotOffset,
-- PURE). A nil-guarded read of the other module's published frame — no
-- new service, and with pomodoro absent there is simply no offset.
-- =====================================================================
local M = {
    name   = "timer",
    order  = 13.655,         -- beside the pomodoro (13.65): same corner,
                             -- same shape, and it reads the pomodoro's
                             -- frame, so loading after it is honest even
                             -- though the read is nil-guarded either way.
    family = "time",
    cheatsheet = {
        title = "⏱ TIMER (⇪⇧T — say how long, in words)",
        entries = {
            { "⇪⇧T",   "Ask how long, then count it down in the corner" },
            { "",      "⇧ plus the letter T, next to R and Y" },
            { "",      "15s · 25 · 24h and 35m · twenty five minutes ·" },
            { "",      "half an hour · 1h 30 · 5m30s · 2 days" },
            { "again", "⇪⇧T with the card up PUTS IT AWAY — it keeps running" },
            { "esc",   "Stops it, while the pointer is on the card or just" },
            { "",      "after you bring it up (the card's last line says which)" },
            { "⇪⎋",    "Stops it from anywhere, pointer or no pointer" },
            { "⏱ ends", "The card shows itself, flashes and stays until you" },
            { "",      "answer it — a timer that ended while you were away" },
            { "",      "is still waiting when you come back" },
            { "check", "_G.timerReport() — what is running, and the last one" },
        },
    },
}

-- ---------------------------------------------------------------------
-- PURE — the whole grammar and every decision, provable with no Mac.
-- They live on M (not inside setup) so the gate can reach them and so
-- tools/build-feature-list.lua reads a table that is true before setup
-- has run (6.311.0).
-- ---------------------------------------------------------------------
local WORDS = {
    zero = 0, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
    seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12,
    thirteen = 13, fourteen = 14, fifteen = 15, sixteen = 16,
    seventeen = 17, eighteen = 18, nineteen = 19, twenty = 20,
    thirty = 30, forty = 40, fifty = 50, sixty = 60, seventy = 70,
    eighty = 80, ninety = 90,
}
local UNITS = {
    s = 1, sec = 1, secs = 1, second = 1, seconds = 1,
    m = 60, min = 60, mins = 60, minute = 60, minutes = 60,
    h = 3600, hr = 3600, hrs = 3600, hour = 3600, hours = 3600,
    d = 86400, day = 86400, days = 86400,
}
-- The unit one step down, for a trailing number with no unit of its own
-- ("1h 30"). Seconds have nothing below them, so a trailing number there
-- is refused rather than silently added as seconds twice.
local SMALLER = { [86400] = 3600, [3600] = 60, [60] = 1 }
local NOISE   = { ["and"] = true, ["then"] = true, ["plus"] = true,
                  ["for"] = true, ["in"] = true }
local UNIT_NAME = { [86400] = "day", [3600] = "hour", [60] = "minute", [1] = "second" }

M.WORDS, M.UNITS = WORDS, UNITS       -- read by the suite, never written

-- 🔤 Tokenise. A token is a number or a run of letters, so "24h" and
-- "5m30s" need no special case. Anything else is refused BY NAME —
-- including ":", which is refused on purpose: "1:30" could be a minute
-- and a half or an hour and a half, and this config does not guess
-- (6.200.0). The refusal names both readings and the forms that work.
function M.tokens(s)
    local toks, i, n = {}, 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("%d") then
            local num = s:match("^%d+%.?%d*", i)
            toks[#toks + 1] = { kind = "num", v = tonumber(num), raw = num }
            i = i + #num
        elseif c:match("%a") then
            local w = s:match("^%a+", i)
            toks[#toks + 1] = { kind = "word", v = w }
            i = i + #w
        elseif c == ":" then
            return nil, 'I cannot tell whether a time like "1:30" is one '
                        .. 'minute thirty or one hour thirty — write it as '
                        .. '1m30s or 1h30m'
        else
            return nil, 'could not read "' .. c .. '"'
        end
    end
    return toks
end

-- ⏱ parseDuration — seconds, and ALWAYS a sentence saying what it did
-- or why it would not. Three shapes of answer (6.196.1): a number with a
-- plain reading · nil with a reason a person can act on · nil with
-- "nothing typed", which is not the same as a refusal.
--   maxSecs / defaultUnit are ARGUMENTS so the gate can move them
--   (6.239.0) rather than asserting the shipped numbers twice over.
function M.parseDuration(s, maxSecs, defaultUnit)
    maxSecs     = maxSecs or (7 * 86400)
    defaultUnit = defaultUnit or 60
    if type(s) ~= "string" then return nil, "nothing typed" end
    local clean = s:lower():gsub("[,&]", " "):gsub("%-", " ")
    if clean:match("^%s*$") then return nil, "nothing typed" end

    local toks, why = M.tokens(clean)
    if not toks then return nil, why end

    local total, pending, frac, lastUnit, sawUnit = 0, nil, false, nil, false
    local notes = {}

    local function takeNumber(v, isFrac)
        if pending == nil then
            pending, frac = v, isFrac or false
            return true
        end
        -- "twenty five" — a round ten and then a digit is one number.
        if not isFrac and not frac and pending >= 20 and pending % 10 == 0
           and pending <= 90 and v >= 1 and v <= 9 then
            pending = pending + v
            return true
        end
        -- "two and a half" — a fraction after a number joins it.
        if isFrac then pending = pending + v ; return true end
        return false, 'two numbers with no unit between them ("'
                      .. tostring(pending) .. " " .. tostring(v) .. '")'
    end

    for idx, t in ipairs(toks) do
        if t.kind == "num" then
            local ok, err = takeNumber(t.v)
            if not ok then return nil, err end
        else
            local w = t.v
            if w == "a" or w == "an" then
                -- 🔑 "a"/"an" is ONE only when it is counting a unit that
                -- follows it ("an hour"); in "a half" and in "half an
                -- hour" it is noise. Without this, "half an hour" reads
                -- as two numbers in a row and is refused — which is the
                -- most natural thing a person could type.
                local nxt = toks[idx + 1]
                local nextIsUnit = nxt and nxt.kind == "word" and UNITS[nxt.v] ~= nil
                if pending == nil and nextIsUnit then pending = 1 end
            elseif w == "half" then
                local ok, err = takeNumber(0.5, true)
                if not ok then return nil, err end
            elseif WORDS[w] then
                local ok, err = takeNumber(WORDS[w])
                if not ok then return nil, err end
            elseif UNITS[w] then
                if pending == nil then
                    return nil, '"' .. w .. '" with no number in front of it'
                end
                total   = total + pending * UNITS[w]
                lastUnit, pending, frac, sawUnit = UNITS[w], nil, false, true
            elseif NOISE[w] then        -- "and", "then", "plus", "for", "in"
                pending = pending      -- deliberately nothing
            else
                return nil, 'could not read "' .. w .. '"'
            end
        end
    end

    if pending ~= nil then
        if not sawUnit then
            -- A bare number. MINUTES, because "set a timer for 25" means
            -- minutes to almost everyone — and the box shows the reading
            -- before he presses Return, so the assumption is visible
            -- rather than a guess (6.297.0).
            total = total + pending * defaultUnit
            notes[#notes + 1] = "no unit given, so "
                                .. (UNIT_NAME[defaultUnit] or "minute") .. "s"
        elseif frac and lastUnit then
            -- "an hour and a half" — the half belongs to the hour.
            total = total + pending * lastUnit
        else
            local down = SMALLER[lastUnit or 1]
            if not down then
                return nil, 'a number after seconds ("' .. tostring(pending)
                            .. '") has no unit below it'
            end
            total = total + pending * down
            notes[#notes + 1] = tostring(pending) .. " read as "
                                .. (UNIT_NAME[down] or "") .. "s"
        end
    end

    total = math.floor(total + 0.5)
    if total <= 0 then return nil, "that is no time at all" end
    if total > maxSecs then
        return nil, "that is longer than " .. M.sayDuration(maxSecs)
    end
    return total, M.sayDuration(total)
           .. (#notes > 0 and (" — " .. table.concat(notes, " · ")) or "")
end

-- 🗣 "1 day 2 hours 3 minutes" — the words, for the preview, the card and
-- the alert. One function, every surface, so they cannot drift.
function M.sayDuration(secs)
    if type(secs) ~= "number" or secs ~= secs
       or secs == math.huge or secs == -math.huge then return "an unknown length" end
    secs = math.max(0, math.floor(secs + 0.5))
    if secs == 0 then return "no time at all" end
    -- 🗣 DAYS ONLY WHEN THEY READ AS DAYS. "24h and 35m" collapsed to
    -- "1 day 35 minutes" is arithmetically right and reads as though the
    -- box had rewritten what he typed — and this line's whole job is to
    -- confirm it understood him. So one day with a remainder stays in
    -- hours ("24 hours 35 minutes", his own words back), while two days
    -- or a whole number of them are days ("2 days", "3 days 2 hours").
    local days = math.floor(secs / 86400)
    local useDays = days >= 2 or (days >= 1 and secs % 86400 == 0)
    local parts, left = {}, secs
    for _, u in ipairs({ 86400, 3600, 60, 1 }) do
        if u ~= 86400 or useDays then
            local n = math.floor(left / u)
            if n > 0 then
                parts[#parts + 1] = n .. " " .. UNIT_NAME[u] .. (n == 1 and "" or "s")
                left = left - n * u
            end
        end
    end
    return table.concat(parts, " ")
end

-- 🕐 The digits on the card. H:MM:SS once there is an hour in it, MM:SS
-- below that. GUARDED AGAINST INFINITY AND NaN, which is not
-- hypothetical: pomodoro.lua 6.70.0 lost a release to
-- string.format("%02d", math.huge) raising inside a pcall'd tick — once
-- a second, for ever, with nobody ever seeing it.
function M.clockText(secs)
    if type(secs) ~= "number" or secs ~= secs
       or secs == math.huge or secs == -math.huge then return "--:--" end
    secs = math.max(0, math.floor(secs + 0.5))
    if secs >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(secs / 3600),
                             math.floor((secs % 3600) / 60), secs % 60)
    end
    return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

-- 🔑 What the key does RIGHT NOW. Four answers, and the fourth is forced
-- by the other three rather than chosen: he named "ask", "hide" and
-- "stop", and a card that can be hidden while running must be able to
-- come back.
function M.keyVerdict(running, onScreen)
    if not running then
        return "ask", "nothing is running — ask how long"
    end
    if onScreen then
        return "hide", "the card is up — put it away, the timer keeps running"
    end
    return "show", "it is running out of sight — bring the card back"
end

-- ⎋ Is bare Esc ours at this instant? See 🚨 THE ESC RULE in the header.
-- Answers the reason as well, because the card PRINTS it: a rule that is
-- explained is a rule he can remember (6.377.0's ⌨️ lesson).
function M.escWanted(onScreen, hovering, shownAgo, escSecs)
    if not onScreen then return false, "the card is not up" end
    if hovering then return true, "esc stops it" end
    if type(shownAgo) == "number" and type(escSecs) == "number"
       and shownAgo >= 0 and shownAgo <= escSecs then
        return true, "esc stops it"
    end
    return false, "⇪⎋ stops it"
end

-- 👻 One answer for the card's opacity, asked by every path, so no two
-- paths can disagree (pomodoro 6.154.0's shape).
function M.alphaFor(left, alertSecs, hovered, loud, idle, alert)
    idle, alert = idle or 0.90, alert or 0.90
    if hovered or loud then return alert end
    if type(left) == "number" and left == left and left ~= math.huge
       and left <= (alertSecs or 60) then return alert end
    return idle
end

-- 🗓 Where to open so the pomodoro's card is not covered. pomFrame is
-- the other card's frame or nil; the answer is a y offset and a reason.
function M.slotOffset(pomFrame, gap, ownTop)
    gap = gap or 8
    if type(pomFrame) ~= "table" or type(pomFrame.y) ~= "number"
       or type(pomFrame.h) ~= "number" then
        return 0, "the pomodoro is not on screen"
    end
    -- Only step down if the two would actually overlap vertically: a
    -- pomodoro dragged to the bottom of the screen must not push this
    -- card off the top of it.
    if type(ownTop) == "number" and ownTop >= pomFrame.y + pomFrame.h then
        return 0, "the pomodoro is above this card already"
    end
    return pomFrame.h + gap, "below the pomodoro's card"
end

-- 💾 What a stored deadline means now. THREE STATES, and the middle one
-- is the whole reason this is a function: a deadline that passed while
-- Hammerspoon was not running must be SAID, never fired hours late as
-- though it had just happened.
function M.restoreVerdict(saved, now)
    if type(saved) ~= "table" or type(saved.endsAt) ~= "number" then
        return "none", "nothing was running"
    end
    if type(now) ~= "number" then return "none", "no clock to compare against" end
    local left = saved.endsAt - now
    if left > 0 then
        return "running", M.clockText(left) .. " still to go"
    end
    return "ended", "it ended " .. M.sayDuration(-left)
                    .. " ago, while this config was not running"
end

function M.setup(core)
    local tm = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    tm.enabled   = true
    tm.key       = "t"             -- ⇪⇧T. HIS key, by name. The registry
    tm.mods      = { "shift" }     -- said it held power_tools' "type the
                                   -- clipboard"; that moved to ⇪⇧\ in the
                                   -- same release and still runs from ⇪;.
    -- 📐 The card. Same width and the same alpha knobs as the pomodoro so
    -- the two read as one family; one line shorter because there is no
    -- workday line and no tally.
    tm.scale     = 1.2
    tm.width     = math.floor(170 * 1.2 + 0.5)
    tm.height    = math.floor(128 * 1.2 + 0.5)
    tm.marginX   = 12
    tm.marginY   = 6
    tm.slotGap   = 8               -- gap below the pomodoro's card
    tm.alphaIdle  = 0.90
    tm.alphaAlert = 0.90
    tm.cardAlpha  = 0.78
    tm.inkAlpha   = 0.80
    tm.alertSecs  = 60             -- solid for the last minute. A timer
                                   -- shorter than this is solid all the
                                   -- way through, which is right.
    tm.hoverSecs  = 0.15           -- the hover poll. A poll, NOT a canvas
                                   -- mouseCallback: window_move's drag
                                   -- owns that (one per canvas).
    -- ⎋ How long bare Esc stays ours after the card is brought up. Every
    -- second here is a second Esc does not reach the app you are in, so
    -- it is deliberately short. It is not a comfort setting.
    tm.escSecs    = 10
    -- ⏱ The longest timer this will set. A number he can raise, and the
    -- refusal names it rather than just saying no.
    tm.maxSecs    = 7 * 86400
    -- A bare number ("25") means this many seconds × the number. 60 =
    -- minutes. The box always says which, so this is a default and never
    -- a hidden rule.
    tm.defaultUnit = 60
    -- 🔊 The announcement at zero, played toneRepeats times. Resolved
    -- ONCE, on the keypress — never from inside a timer (6.210.0).
    tm.toneOn      = true
    tm.toneName    = "Submarine"
    tm.toneFile    = "/System/Library/Sounds/Submarine.aiff"
    tm.toneRepeats = 4
    tm.toneEvery   = 2.5
    tm.toneVolume  = 0.8
    tm.flashSecs   = 0.5           -- how fast the ⏱ TIME UP card blinks
    -- 💾 The one stored value, so a reload does not lose a long timer.
    tm.settingsKey = "timer.running"
    -- ---------------------------------------------------------------------

    local st = _G.uiStyle or {}
    tm.bg      = st.bg     or { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 }
    tm.fg      = st.fg     or { white = 1.0, alpha = 0.97 }
    tm.bgFlash = st.accent or { red = 1.00, green = 0.84, blue = 0.00, alpha = 0.96 }
    tm.fgFlash = { red = 0.10, green = 0.08, blue = 0.00, alpha = 1.0 }

    -- 🔑 ONE LITERAL FOR THE KEY, rendered from the binding it is bound
    -- with, so the card, the box, the cheat sheet and the report cannot
    -- disagree with the keyboard (6.311.0).
    function tm.keyLabel()
        local out = "⇪"
        for _, m in ipairs(tm.mods or {}) do
            if tostring(m):lower() == "shift" then out = out .. "⇧" end
        end
        return out .. tostring(tm.key):upper()
    end

    local function say(m)  if _G.diag then _G.diag.say("timer", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("timer", m) end end
    local function clock() return (hs.timer and hs.timer.secondsSinceEpoch
                                   and hs.timer.secondsSinceEpoch()) or os.time() end
    local function degrade(why)
        if core and core.degrade then return core.degrade("Timer", why) end
        pcall(function() hs.alert.show("⚠️ Timer — " .. tostring(why)) end)
        warn(why)
        return false, why
    end

    -- counters, for the report
    tm.counts = { asked = 0, started = 0, fired = 0, stopped = 0,
                  hidden = 0, shown = 0, refused = 0, escStops = 0,
                  restored = 0, endedAway = 0, noBelt = 0 }
    tm.lastWhy   = nil             -- the last refusal the box printed
    tm.lastRun   = nil             -- { asked, secs, endedAt, how }

    -- ---- the card -------------------------------------------------------
    local function S(n) return math.floor(n * tm.scale + 0.5) end

    local function faded(c, frac)
        return { red = c.red, green = c.green, blue = c.blue,
                 white = c.white, alpha = (c.alpha or 1) * frac }
    end

    local function panelFrame()
        local scr
        pcall(function() scr = core.resolveBaseScreen and core.resolveBaseScreen() end)
        if not scr then pcall(function() scr = hs.screen.mainScreen() end) end
        if not scr then return nil end
        local f
        pcall(function() f = scr:frame() end)
        if not f then return nil end
        -- A remembered position wins, clamped to a screen that exists.
        if tm.pos then
            local p2 = _G.clampToScreen and _G.clampToScreen(tm.pos, tm.width, tm.height)
                       or tm.pos
            return { x = p2.x, y = p2.y, w = tm.width, h = tm.height }
        end
        local top = f.y + tm.marginY
        -- 🗓 nil-guarded: with pomodoro absent or not running there is no
        -- offset, and slotOffset says so.
        local pomFrame
        pcall(function()
            local p = _G.pomodoro
            if p and p.state and p.state.canvas then pomFrame = p.state.canvas:frame() end
        end)
        local dy, dyWhy = M.slotOffset(pomFrame, tm.slotGap, top)
        tm.slotWhy = dyWhy
        return { x = f.x + f.w - tm.width - tm.marginX, y = top + dy,
                 w = tm.width, h = tm.height }
    end

    local function hovering()
        local s = tm.state
        if not (s and s.canvas) then return false end
        local pt, fr
        pcall(function() pt = hs.mouse.absolutePosition() end)
        pcall(function() fr = s.canvas:frame() end)
        if not (pt and fr) then return false end
        return pt.x >= fr.x and pt.x <= fr.x + fr.w
               and pt.y >= fr.y and pt.y <= fr.y + fr.h
    end

    -- ⎋ The one place that decides whether bare Esc is ours, and the one
    -- place that turns the modal on and off. The card's bottom line is
    -- drawn from the SAME answer, so what it says is what is true.
    local function escState()
        local s = tm.state
        if not s then return false, "the card is not up" end
        local ago = (s.shownAt and (clock() - s.shownAt)) or nil
        return M.escWanted(s.canvas ~= nil, s.hovered == true, ago, tm.escSecs)
    end

    local function applyEscModal()
        local want = escState()
        if not tm.modal then return end
        if want and not tm.modalOn then
            tm.modalOn = true
            pcall(function() tm.modal:enter() end)
        elseif not want and tm.modalOn then
            tm.modalOn = false
            pcall(function() tm.modal:exit() end)
        end
    end

    local function elements(label, digits, asked, hint, bg, fg)
        local loud = (bg == tm.bgFlash)
        local fill = loud and bg or faded(bg, tm.cardAlpha or 1)
        local ink  = loud and fg or faded(fg, tm.inkAlpha or 1)
        local dim  = faded(ink, 0.78)
        local small = S((st.font and st.font.label) or 12)
        return {
            { type = "rectangle", action = "fill", fillColor = fill,
              roundedRectRadii = { xRadius = st.radius or 12,
                                   yRadius = st.radius or 12 },
              frame = { x = 0, y = 0, w = tm.width, h = tm.height } },
            { type = "text", text = label, textSize = small,
              textColor = ink, textAlignment = "center",
              frame = { x = 0, y = S(10), w = tm.width, h = S(18) } },
            { type = "text", text = digits,
              textSize = S((st.font and st.font.big) or 40),
              textColor = ink, textAlignment = "center",
              frame = { x = 0, y = S(30), w = tm.width, h = S(52) } },
            { type = "text", text = asked, textSize = small,
              textColor = dim, textAlignment = "center",
              frame = { x = 0, y = S(86), w = tm.width, h = S(16) } },
            -- ⎋ The line that teaches the Esc rule, and it is READ from
            -- escState rather than typed, so it cannot promise a key that
            -- is not live.
            { type = "text", text = hint, textSize = small,
              textColor = dim, textAlignment = "center",
              frame = { x = 0, y = S(104), w = tm.width, h = S(16) } },
        }
    end
    tm.elements = elements         -- exposed for the harness

    local function paint(label, bg, fg)
        local s = tm.state
        if not (s and s.canvas) then return end
        local left = (s.endsAt or 0) - clock()
        local _, hint = escState()
        local digits = (s.fired and "0:00") or M.clockText(left)
        pcall(function()
            s.canvas:replaceElements(elements(label or "TIMER", digits,
                                              s.asked or "", hint or "",
                                              bg or tm.bg, fg or tm.fg))
        end)
        local a = M.alphaFor(left, tm.alertSecs, s.hovered, s.fired or s.flasher,
                             tm.alphaIdle, tm.alphaAlert)
        if s.alphaNow ~= a then
            s.alphaNow = a
            pcall(function() s.canvas:alpha(a) end)
        end
    end
    tm.paint = paint

    -- ---- the stored deadline -------------------------------------------
    -- 🚨 CLEAR, NOT set(nil). `hs.settings.set(key, nil)` is not a
    -- reliable delete — modules/mouse_follows.lua has used clear() with
    -- set(nil) only as the fallback since 6.160.2 — and the cost of
    -- getting it wrong here is the worst shape this module has: a timer
    -- he STOPPED coming back on the next boot, or being announced as
    -- having "ended while away" when he cancelled it himself.
    function tm.forget()
        local cleared = pcall(function() hs.settings.clear(tm.settingsKey) end)
        if not cleared then
            pcall(function() hs.settings.set(tm.settingsKey, nil) end)
        end
        return cleared
    end

    local function remember()
        local s = tm.state
        pcall(function()
            if not (hs.settings and hs.settings.set) then return end
            if s and s.endsAt and not s.fired then
                hs.settings.set(tm.settingsKey,
                                { endsAt = s.endsAt, asked = s.asked,
                                  secs = s.secs })
            else
                tm.forget()
            end
        end)
    end

    -- ---- start / stop / hide / show -------------------------------------
    local function tearDown()
        local s = tm.state
        if not s then return end
        for _, k in ipairs({ "ticker", "hoverer", "flasher", "toner" }) do
            if s[k] then pcall(function() s[k]:stop() end) ; s[k] = nil end
        end
        if s.canvas then pcall(function() s.canvas:delete() end) ; s.canvas = nil end
        tm.modalOn = false
        if tm.modal then pcall(function() tm.modal:exit() end) end
    end

    function tm.stop(why)
        local s = tm.state
        if not s then return false, "nothing is running" end
        tm.lastRun = { asked = s.asked, secs = s.secs, endedAt = clock(),
                       how = why or "stopped" }
        tearDown()
        tm.state = nil
        remember()
        tm.counts.stopped = tm.counts.stopped + 1
        if why == "esc" or why == "⇪esc" then
            tm.counts.escStops = tm.counts.escStops + 1
        end
        say("stopped (" .. tostring(why or "?") .. ")")
        return true
    end

    -- 🔊 Resolved on the keypress, never in a timer. false after a failed
    -- lookup, and the report says so rather than going quietly silent.
    function tm.resolveTone()
        if tm.sound ~= nil then return tm.sound end
        local snd
        pcall(function()
            snd = hs.sound and hs.sound.getByName and hs.sound.getByName(tm.toneName)
        end)
        if not snd then
            pcall(function()
                snd = hs.sound and hs.sound.getByFile and hs.sound.getByFile(tm.toneFile)
            end)
        end
        tm.sound = snd or false
        if not snd then tm.toneWhy = "no " .. tostring(tm.toneName) .. " on this Mac" end
        return tm.sound
    end

    local function playTone()
        local snd = tm.resolveTone()
        if not snd then return end
        pcall(function()
            snd:volume(tm.toneVolume)
            snd:play()
        end)
    end

    -- ⏱ ZERO. The announcement is the feature, not decoration — the card
    -- may well be hidden, so every channel speaks and the card STAYS.
    local function fire()
        local s = tm.state
        if not s or s.fired then return end
        s.fired = true
        s.endsAt = clock()
        -- ⎋ THE ALARM OWNS Esc FOR escSecs, bounded, from the moment it
        -- goes off — a card that is asking you something should answer to
        -- the key you reach for. Bounded is the whole point: pomodoro
        -- 6.68.0 holds Esc for answerSecs and no longer, because an alarm
        -- nobody is there to answer must not keep the key for ever.
        s.shownAt = clock()
        remember()                         -- forget it: it is no longer running
        tm.counts.fired = tm.counts.fired + 1
        local words = s.asked or M.sayDuration(s.secs)
        if not s.canvas then tm.show("it ended") end
        -- the blink
        pcall(function()
            local on = false
            s.flasher = hs.timer.doEvery(tm.flashSecs, function()
                on = not on
                pcall(function()
                    if on then paint("⏱ TIME UP", tm.bgFlash, tm.fgFlash)
                    else paint("⏱ TIME UP", tm.bg, tm.fg) end
                end)
            end)
        end)
        paint("⏱ TIME UP", tm.bgFlash, tm.fgFlash)
        -- ⎋ TAKE Esc NOW, not on the next tick. The window is re-stamped
        -- above; without this the modal was only entered a second later,
        -- and the first second of an alarm going off is precisely when
        -- the key is pressed. Found by this release's own sweep.
        applyEscModal()
        pcall(function() hs.alert.show("⏱ TIME UP — " .. words, 6) end)
        print("⏱ Timer: TIME UP — " .. words)
        -- a notification HOLDS through Focus and lands when it ends: a
        -- long timer is exactly the one that fires during a meeting.
        pcall(function()
            if _G.notices and _G.notices.tell then
                _G.notices.tell("⏱ Timer", words .. " is up", { key = "timer.fired" })
            end
        end)
        if tm.toneOn then
            local n = 0
            playTone()
            pcall(function()
                s.toner = hs.timer.doEvery(tm.toneEvery, function()
                    n = n + 1
                    if n >= (tm.toneRepeats - 1) then
                        pcall(function() if s.toner then s.toner:stop() ; s.toner = nil end end)
                    end
                    pcall(playTone)
                end)
            end)
        end
    end
    tm.fire = fire

    -- Draw the card for the state that already exists. Used by start,
    -- by show() after a hide, and by fire() when it ended out of sight.
    local function draw(why)
        local s = tm.state
        if not s then return false, "nothing is running" end
        if s.canvas then return true, "already up" end
        local frame = panelFrame()
        if not frame then return degrade("no screen to draw the card on") end
        local okNew, c = pcall(hs.canvas.new, frame)
        if not (okNew and c) then return degrade("hs.canvas.new would not make the card") end
        local okWire = pcall(function()
            c:level((_G.panelLevel and _G.panelLevel("pomodoro"))
                    or (hs.canvas.windowLevels or {}).overlay)
            c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        if not okWire then
            pcall(function() c:delete() end)
            return degrade("macOS would not place the card")
        end
        if _G.makeCanvasDraggable then
            _G.makeCanvasDraggable(c, "timer", function(f)
                tm.pos = { x = f.x, y = f.y }
                say("moved to " .. math.floor(f.x) .. "," .. math.floor(f.y))
            end)
        end
        -- 🚨 showCanvasSafely, never a bare :show() — and with NO late
        -- retry on purpose (6.266.0): a card this module has stopped
        -- tracking must never be put back on screen behind its back, and
        -- pressing the key again is one keystroke.
        local okShow = (_G.showCanvasSafely and _G.showCanvasSafely(c, "timer"))
        if okShow == nil then okShow = pcall(function() c:show() end) end
        if not okShow then
            pcall(function() c:delete() end)
            return degrade("macOS would not put the card on screen — press "
                           .. tm.keyLabel() .. " again")
        end
        s.canvas  = c
        s.shownAt = clock()
        s.hovered = hovering()
        paint(s.fired and "⏱ TIME UP" or "TIMER",
              s.fired and tm.bgFlash or tm.bg, s.fired and tm.fgFlash or tm.fg)
        -- the hover poll: it decides the alpha AND whether Esc is ours
        pcall(function()
            s.hoverer = hs.timer.doEvery(tm.hoverSecs, function()
                pcall(function()
                    local s2 = tm.state
                    if not (s2 and s2.canvas) then return end
                    local h = hovering()
                    local changed = (h ~= s2.hovered)
                    s2.hovered = h
                    applyEscModal()
                    if changed then paint(s2.fired and "⏱ TIME UP" or "TIMER",
                                          s2.fired and tm.bgFlash or tm.bg,
                                          s2.fired and tm.fgFlash or tm.fg) end
                end)
            end)
        end)
        applyEscModal()
        say("card drawn (" .. tostring(why or "?") .. ")")
        return true
    end
    tm.draw = draw

    function tm.show(why)
        local s = tm.state
        if not s then return false, "nothing is running" end
        local ok, w = draw(why or "shown")
        if ok then tm.counts.shown = tm.counts.shown + 1 end
        return ok, w
    end

    -- 🔑 HIDE KEEPS THE TIMER RUNNING. The canvas and the hover poll go;
    -- the TICKER stays, because it is what reaches zero. Esc is released
    -- with the card — there is nothing on screen to point at.
    function tm.hide(why)
        local s = tm.state
        if not s then return false, "nothing is running" end
        if s.hoverer then pcall(function() s.hoverer:stop() end) ; s.hoverer = nil end
        if s.flasher then pcall(function() s.flasher:stop() end) ; s.flasher = nil end
        if s.canvas then pcall(function() s.canvas:delete() end) ; s.canvas = nil end
        s.hovered, s.shownAt = false, nil
        tm.modalOn = false
        if tm.modal then pcall(function() tm.modal:exit() end) end
        tm.counts.hidden = tm.counts.hidden + 1
        say("card hidden (" .. tostring(why or "?") .. "), still running")
        return true
    end

    function tm.start(secs, asked)
        if type(secs) ~= "number" or secs <= 0 then
            return false, "no length to count"
        end
        if tm.state then tm.stop("restarted") end
        tm.state = { endsAt = clock() + secs, secs = secs,
                     asked = asked or M.sayDuration(secs), fired = false }
        if tm.toneOn then tm.resolveTone() end    -- named now, not at zero
        local ok, why = draw("started")
        if not ok then
            -- The card could not be drawn. The TIMER STILL RUNS — a
            -- countdown with no card is worth more than no countdown, and
            -- the announcement at zero does not need the card to exist.
            degrade("the card could not be drawn (" .. tostring(why)
                    .. ") — the timer is running anyway and will say so at zero")
        end
        -- 🚨 THE TICKER IS HELD IN ITS OWN SLOT on the state: an
        -- unreferenced hs.timer is collected and never fires, so the
        -- assignment IS the mechanism (6.196.1).
        local armed = pcall(function()
            tm.state.ticker = hs.timer.doEvery(1, function()
                pcall(function()
                    local s = tm.state
                    if not s then return end
                    if not s.fired and clock() >= s.endsAt then fire() ; return end
                    if s.canvas and not s.fired then paint("TIMER", tm.bg, tm.fg) end
                    applyEscModal()      -- the escSecs window closes here
                end)
            end)
        end)
        if not (armed and tm.state and tm.state.ticker) then
            tm.counts.noBelt = tm.counts.noBelt + 1
            degrade("this Mac would not give the timer a ticker — it cannot "
                    .. "count down. Nothing is running.")
            tearDown()
            tm.state = nil
            return false, "no timer available"
        end
        remember()
        tm.counts.started = tm.counts.started + 1
        say("started " .. M.sayDuration(secs))
        return true
    end

    -- ---- the box --------------------------------------------------------
    local function rowFor(q)
        local secs, why = M.parseDuration(q, tm.maxSecs, tm.defaultUnit)
        if secs then
            return { { text = "⏱ " .. why,
                       subText = "⏎ starts it · " .. M.clockText(secs)
                                 .. " on the card",
                       secs = secs, asked = why } }, secs, why
        end
        return { { text = "⏱ " .. (q == "" and "How long?" or why),
                   subText = q == ""
                     and "15s · 25 · 24h and 35m · twenty five minutes · half an hour"
                     or  "try 15s · 25 · 24h and 35m · twenty five minutes",
                   secs = nil } }, nil, why
    end
    tm.rowFor = rowFor

    function tm.ask()
        tm.counts.asked = tm.counts.asked + 1
        if not tm.chooser then
            local okC, c = pcall(hs.chooser.new, function(row)
                if not (row and row.secs) then
                    say("box closed with nothing to count")
                    return
                end
                tm.start(row.secs, row.asked)
            end)
            if not (okC and c) then
                return degrade("this Mac would not open the how-long box")
            end
            tm.chooser = c
            _G.choosers = _G.choosers or {}
            _G.choosers.timer = c
            pcall(function()
                c:width(34)
                c:rows(2)
                c:searchSubText(false)
                -- 🔎 The box IS the preview (6.297.0): every keystroke
                -- re-renders the one row with what it understood, so an
                -- assumption — "25 means minutes" — is visible BEFORE he
                -- presses Return rather than being a guess afterwards.
                c:queryChangedCallback(function(q)
                    local rows, secs, why = rowFor(q or "")
                    if not secs then tm.lastWhy = why end
                    pcall(function()
                        c:choices(rows)
                        -- :choices() DROPS the selection (6.227.0), and the
                        -- one row here is the one ⏎ must take.
                        c:selectedRow(1)
                    end)
                end)
            end)
        end
        local rows = rowFor("")
        pcall(function()
            tm.chooser:query("")
            tm.chooser:choices(rows)
            tm.chooser:selectedRow(1)
            tm.chooser:placeholderText("How long? 15s · 25 · 24h and 35m · "
                                       .. "twenty five minutes · half an hour")
        end)
        -- 🚨 core.showPopup, never a bare :show() — an unplaced picker
        -- leaves the last one's coordinates standing (6.127.0), and the
        -- shared door is what catches a chooser macOS refuses (6.314.0).
        if core.showPopup then core.showPopup(tm.chooser)
        else pcall(function() tm.chooser:show() end) end
        return true
    end

    -- ---- the key --------------------------------------------------------
    function tm.press()
        local s = tm.state
        local what = M.keyVerdict(s ~= nil, s ~= nil and s.canvas ~= nil)
        if what == "ask" then return tm.ask() end
        if what == "hide" then
            -- A card that has FIRED is answering you, so the key clears
            -- it rather than hiding an alarm that is going off.
            if s.fired then return tm.stop("answered") end
            return tm.hide("key")
        end
        return tm.show("key")
    end

    -- ---- the report -----------------------------------------------------
    function _G.timerReport()
        local L = {}
        local c = tm.counts
        L[#L + 1] = "⏱ TIMER — " .. tm.keyLabel()
        local s = tm.state
        if not s then
            L[#L + 1] = "   running: nothing"
        elseif s.fired then
            L[#L + 1] = "   running: ⏱ TIME UP — " .. tostring(s.asked)
                        .. " · the card is waiting to be answered"
        else
            local left = s.endsAt - clock()
            L[#L + 1] = "   running: " .. M.clockText(left) .. " left of "
                        .. tostring(s.asked)
                        .. (s.canvas and " · the card is up"
                            or " · THE CARD IS HIDDEN, and it is still counting")
        end
        if s and s.canvas then
            local want, why = escState()
            L[#L + 1] = "   esc    : " .. (want and "ours right now" or "your apps'")
                        .. " — the card's last line reads “" .. tostring(why) .. "”"
        else
            L[#L + 1] = "   esc    : your apps' — the card is not up. "
                        .. "⇪⎋ stops a hidden timer."
        end
        L[#L + 1] = "   counts : " .. c.asked .. " asked · " .. c.started
                    .. " started · " .. c.fired .. " reached zero · "
                    .. c.stopped .. " stopped (" .. c.escStops .. " by esc)"
        L[#L + 1] = "   ↳ card : " .. c.hidden .. " hidden · " .. c.shown
                    .. " brought back · place: " .. tostring(tm.slotWhy or "not drawn yet")
        if tm.lastRun then
            L[#L + 1] = "   ↳ last : " .. tostring(tm.lastRun.asked) .. " — "
                        .. tostring(tm.lastRun.how) .. " at "
                        .. os.date("%H:%M:%S", math.floor(tm.lastRun.endedAt or 0))
        else
            L[#L + 1] = "   ↳ last : no timer has ended this session"
        end
        if tm.lastWhy then
            L[#L + 1] = "   ↳ box  : the last thing it could not read — "
                        .. tostring(tm.lastWhy)
        end
        -- 🔊 three states, because "silent on purpose" and "silent because
        -- this Mac has no such sound" are opposite facts (6.196.1).
        if not tm.toneOn then
            L[#L + 1] = "   tone   : off in settings — the card still flashes"
        elseif tm.sound == nil then
            L[#L + 1] = "   tone   : " .. tostring(tm.toneName)
                        .. " — not looked for yet (resolved on the keypress)"
        elseif tm.sound == false then
            L[#L + 1] = "   tone   : ⚠️ SILENT — " .. tostring(tm.toneWhy)
                        .. "; the flash and the notification still happen"
        else
            L[#L + 1] = "   tone   : " .. tostring(tm.toneName) .. " × "
                        .. tm.toneRepeats .. " at zero"
        end
        if tm.restoreWhy then
            L[#L + 1] = "   reload : " .. tostring(tm.restoreWhy)
        end
        if c.noBelt > 0 then
            L[#L + 1] = "   ⚠️ " .. c.noBelt .. " start(s) had no ticker — "
                        .. "nothing was counted"
        end
        L[#L + 1] = "   max    : " .. M.sayDuration(tm.maxSecs)
                    .. " · a bare number means "
                    .. ((tm.defaultUnit == 60) and "minutes" or (tm.defaultUnit .. "s"))
        print(table.concat(L, "\n"))
    end

    -- ---- wiring ---------------------------------------------------------
    -- The modal is built ONCE and entered/exited by escState. Rebuilding
    -- it per press is how a config ends up with two modals on one key,
    -- one of which nothing can ever exit.
    local okModal, modal = pcall(hs.hotkey.modal.new)
    if okModal and modal then
        tm.modal = modal
        pcall(function()
            modal:bind({}, "escape", function() tm.stop("esc") end)
        end)
    else
        warn("no modal — esc will not stop the timer; " .. tm.keyLabel()
             .. " still hides it and ⇪⎋ still stops it")
    end

    -- ⎋ The router: ⇪⎋ reaches a HIDDEN timer, which bare Esc deliberately
    -- cannot. Active whenever anything is running, so it is the answer
    -- that always works. 101 is one rung above the pomodoro: when both
    -- cards are asking, the one the pointer is on should win.
    if _G.claimEscape then
        _G.claimEscape("timer", nil,
            function() return tm.state ~= nil end,
            function() tm.stop("⇪esc") end)
    end

    if tm.enabled then
        core.hyperAddShortcut(tm.mods, tm.key, function() tm.press() end, "timer")
    end

    core.provide("timer.start",  function(secs, asked) return tm.start(secs, asked) end)
    core.provide("timer.stop",   function() return tm.stop("service") end)
    core.provide("timer.ask",    function() return tm.ask() end)
    core.provide("timer.report", function() return _G.timerReport() end)

    -- 6.232.0 — a panel this config draws is a panel _G.movablePanels
    -- knows about, or it is movable by NO means. plain = true: the card is
    -- pure display, so a bare click-hold drags it.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "timer",
        plain = true,
        frame = function()
            return tm.state and tm.state.canvas and tm.state.canvas:frame()
        end,
        move  = function(x, y)
            if tm.state and tm.state.canvas then
                tm.state.canvas:topLeft({ x = x, y = y })
            end
        end,
    })

    _G.timer = tm
    M.tm     = tm
    M.config = tm
end

-- 💾 Restored in warm, never in setup: anything a module reads at setup
-- is a tax every other module and every key pays (6.267.0).
function M.warm(core)
    local tm = M.tm
    if not tm then return end
    local saved
    pcall(function()
        if hs.settings and hs.settings.get then saved = hs.settings.get(tm.settingsKey) end
    end)
    local now = (hs.timer and hs.timer.secondsSinceEpoch and hs.timer.secondsSinceEpoch())
                or os.time()
    local what, why = M.restoreVerdict(saved, now)
    tm.restoreWhy = why
    if what == "running" then
        tm.counts.restored = tm.counts.restored + 1
        tm.start(saved.endsAt - now, saved.asked)
        print("⏱ Timer: a timer was still running — " .. tostring(why))
    elseif what == "ended" then
        tm.counts.endedAway = tm.counts.endedAway + 1
        tm.forget()
        -- 🚨 SAID, NOT FIRED. An alarm going off hours after the fact is
        -- worse than useless: it is indistinguishable from one that is
        -- going off now.
        pcall(function()
            hs.alert.show("⏱ Your " .. tostring(saved.asked or "timer")
                          .. " ended while Hammerspoon was not running", 5)
        end)
        print("⏱ Timer: " .. tostring(why) .. " (" .. tostring(saved.asked) .. ")")
    end
end

return M
