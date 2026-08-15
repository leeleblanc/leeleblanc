-- =====================================================================
-- MODULE: POMODORO (⇪⇧P) — launch it and forget it
-- =====================================================================
-- 25 minutes of work, then 5 minutes to stand up. One key starts it, the
-- same key puts it away, and in between you are not asked to do anything.
--
-- A small panel sits just under the clock in the top-right corner and
-- counts down. At zero it FLASHES — amber for the break, so the change is
-- visible from the corner of your eye without a sound and without a
-- notification landing on whatever you are doing. Then it counts the five
-- minutes and stops.
--
--        ⇪⇧P        start · and press it again to put it away
--
-- 🚨 IT WAS ⇪pad+ IN 6.65.0, AND THAT KEY WAS DEAD. It was assigned,
-- documented, listed on the cheat sheet and covered by a test — and on
-- LL's Mac hs.keycodes.map["pad+"] returns nil, so the numpad layer
-- correctly SKIPPED it rather than binding nil, and the key did nothing.
-- Every layer of the process agreed it worked; the keyboard disagreed.
-- A letter key cannot fail that way, so the timer lives on one now.
-- Run _G.padProbe() to see which pad keys this Mac can actually send.
--        ⏎          reset and go again          ┐ only while it is
--        esc        stop and close it           ┘ asking (see below)
--
-- =====================================================================
-- 🚨 THE ONE REAL HAZARD, AND WHY ⏎ AND esc WORK THE WAY THEY DO
-- =====================================================================
-- The obvious implementation of "press Enter to reset" is a modal that
-- captures Enter for as long as the timer is on screen. That would be
-- TWENTY-FIVE MINUTES during which Enter does not send an email, does not
-- submit a form and does not put a newline in a document — and nothing
-- on screen would explain why. This config has already shipped one
-- keyboard-holding bug (the pre-6.47.0 menu bar scan) and the lesson is
-- not one worth learning twice.
--
-- So the keys are captured ONLY while the timer is ASKING YOU SOMETHING:
-- the moment a phase ends, for pom.answerSecs seconds. That is the only
-- window in which "Enter means reset" is what you would expect it to
-- mean. Outside it, ⇪pad+ toggles the timer and Enter is Enter.
--
-- A WATCHDOG RELEASES THE KEYS unconditionally when that window expires,
-- and it is armed BEFORE the modal is entered, not after — so a throw
-- between the two cannot leave the keyboard captured. Same contract as
-- the Mouse Grid: state, then screen, then keyboard, and any failure
-- undoes all three.
--
-- ⚠️ IT DOES NOT SURVIVE A RELOAD. ⇪R rebuilds every module, so a running
-- timer stops. Deliberate: persisting it would mean a countdown that
-- resumes hours later claiming you are mid-session, which is worse than
-- starting again.

local M = {
    name  = "Pomodoro",
    order = 13.65,
    cheatsheet = {
        title = "🍅 POMODORO (⇪⇧P — 25 on, 5 off)",
        entries = {
            { "⇪⇧P",     "Start it · press again to put it away" },
            { "auto",    "25:00 work, then it FLASHES and counts 5:00 break" },
            { "⏎",       "Reset and go again — only while it is flashing" },
            { "esc",     "Stop and close — only while it is flashing" },
            { "where",   "Top-right, just under the clock" },
            { "note",    "Enter/esc are NOT captured during the countdown" },
            { "was",     "⇪pad+ in 6.65.0 — that key does not exist on this Mac" },
        },
    },
}

function M.setup(core)
    local pom = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    pom.enabled    = true
    pom.key        = "p"         -- ⇪⇧P. A LETTER, deliberately: see the 🚨
                                 -- in the header for why it is not a pad key.
    pom.workMins   = 25          -- the session
    pom.breakMins  = 5           -- stand up, stretch
    pom.width      = 170         -- the size you asked for
    pom.height     = 99
    pom.marginX    = 12          -- gap from the right edge of the screen
    pom.marginY    = 6           -- gap below the menu bar (under the clock)
    -- 🚨 How long ⏎ / esc are captured after a phase ends. Every second
    -- here is a second Enter does not work in the app you are typing in,
    -- so it is deliberately short. It is not a comfort setting.
    pom.answerSecs = 20
    pom.flashCount = 6           -- how many times the panel blinks
    pom.flashSecs  = 0.45        -- per blink
    -- 🧟 How long the panel may sit on screen with nothing driving it
    -- before it decides that is a bug and closes itself. See the note at
    -- isAlive(). Generous, because a legitimate pause between phases must
    -- never trip it — this is a safety net, not a policy.
    pom.zombieSecs = 60
    -- ----------------------------------------------------------------------

    -- Colours. Work is calm, break is amber and loud enough to catch the
    -- eye at the edge of vision, which is the entire point of the flash.
    pom.bgWork   = { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 }
    pom.bgBreak  = { red = 0.55, green = 0.38, blue = 0.02, alpha = 0.94 }
    pom.bgFlash  = { red = 1.00, green = 0.84, blue = 0.00, alpha = 0.96 }
    pom.fgWork   = { white = 1.0, alpha = 0.97 }
    pom.fgFlash  = { red = 0.10, green = 0.08, blue = 0.00, alpha = 1.0 }

    local function say(m)  if _G.diag then _G.diag.say("pomodoro", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("pomodoro", m) end end

    -- state: nil when off. Otherwise { phase, endsAt, canvas, ticker, … }
    pom.pos   = nil       -- where you dragged it to, this session
    pom.state = nil
    pom.modal = nil       -- HELD across presses; built once, never rebuilt
    pom.guard = nil       -- the watchdog that releases the keyboard

    -- ---- geometry --------------------------------------------------------
    -- Under the CLOCK, which means the top-right of the screen holding the
    -- frontmost app — not always the main display. resolveBaseScreen is the
    -- same helper every other panel in this config uses, so the timer opens
    -- on the monitor you are working on.
    local function panelFrame()
        local scr
        pcall(function() scr = core.resolveBaseScreen and core.resolveBaseScreen() end)
        if not scr then pcall(function() scr = hs.screen.mainScreen() end) end
        if not scr then return nil end
        local f
        pcall(function() f = scr:frame() end)          -- excludes the menu bar
        if not f then return nil end
        -- 🖐 6.67.0 — A REMEMBERED POSITION WINS. Drag the panel and it
        -- stays where you put it for the rest of the session; ⇪R (reload)
        -- clears it, as does pom.pos = nil. Clamped to a real screen, so
        -- unplugging the display you dragged it to cannot restore it to
        -- coordinates that no longer exist.
        if pom.pos then
            local p2 = _G.clampToScreen and _G.clampToScreen(pom.pos, pom.width, pom.height)
                       or pom.pos
            return { x = p2.x, y = p2.y, w = pom.width, h = pom.height }
        end
        return {
            x = f.x + f.w - pom.width - pom.marginX,
            y = f.y + pom.marginY,
            w = pom.width, h = pom.height,
        }
    end

    -- 🚨 6.70.0 — GUARDED AGAINST INFINITY, AND THAT IS NOT HYPOTHETICAL.
    -- tick() sets s.endsAt = math.huge to make phaseEnded fire exactly
    -- once. If anything then reaches this function with that value —
    -- which is exactly what happened once the answer window expired —
    -- string.format("%02d", math.huge) raises "number has no integer
    -- representation". paint() pcalls its caller, so the throw was
    -- swallowed and the panel simply stopped updating: once a second,
    -- forever, an error nobody ever saw. A silent throw on a repeating
    -- timer is the quietest bug this config can have.
    local function mmss(secs)
        if type(secs) ~= "number" or secs ~= secs        -- NaN
           or secs == math.huge or secs == -math.huge then
            return "--:--"
        end
        secs = math.max(0, math.floor(secs + 0.5))
        if secs > 359999 then secs = 359999 end          -- 99:59:59 of minutes
        return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
    end

    -- ---- drawing ---------------------------------------------------------
    local function elements(label, clock, bg, fg)
        return {
            { type = "rectangle", action = "fill", fillColor = bg,
              roundedRectRadii = { xRadius = 12, yRadius = 12 },
              frame = { x = 0, y = 0, w = pom.width, h = pom.height } },
            { type = "text", text = label,
              textSize = 12, textColor = fg, textAlignment = "center",
              frame = { x = 0, y = 10, w = pom.width, h = 18 } },
            { type = "text", text = clock,
              textSize = 40, textColor = fg, textAlignment = "center",
              frame = { x = 0, y = 30, w = pom.width, h = 52 } },
        }
    end

    local function paint(label, clock, bg, fg)
        local s = pom.state
        if not (s and s.canvas) then return end
        pcall(function()
            s.canvas:replaceElements(elements(label, clock, bg, fg))
        end)
    end

    -- ---- the keyboard, held for as short a time as possible --------------
    local function releaseKeys(why)
        if pom.guard then pcall(function() pom.guard:stop() end); pom.guard = nil end
        if pom.modal then pcall(function() pom.modal:exit() end) end
        if pom.state then pom.state.asking = false end
        if why then say("keys released (" .. why .. ")") end
    end

    -- 🚨 WATCHDOG FIRST, THEN THE MODAL. Armed before the keyboard is
    -- taken so that a throw in between cannot leave ⏎ and esc captured
    -- with nothing scheduled to give them back.
    -- onExpire: what to do if you never answer. THIS PARAMETER IS THE BUG
    -- FIX. It used to be nothing — the watchdog called releaseKeys() and
    -- stopped there, which exits the modal and clears `asking` and leaves
    -- the PANEL ON SCREEN. For the work→break case that was fine, because
    -- the flash's completion starts the break regardless. For the final
    -- "DONE ⏎ / esc" it was not: twenty seconds after the timer finished,
    -- ⏎ and esc were released and the panel became furniture. Nothing was
    -- bound to it, Esc did nothing, and the only way out was ⇪⇧P or the
    -- Console. LL: "is stuck on screen or I'm not hitting the escape key
    -- right." They were hitting it right.
    local function askForAnswer(onExpire)
        local s = pom.state
        if not s then return end
        -- 🚨 EACH ASK CARRIES ITS OWN TICKET, and a watchdog that is no
        -- longer the current one does NOTHING. There are two asks per
        -- cycle (work→break and break→DONE) and each arms a watchdog on
        -- the same field. Without a ticket, a stale one arriving late
        -- calls releaseKeys(), which stops pom.guard — by then the NEWER
        -- watchdog — and the current question is left with no watchdog at
        -- all. That is a keyboard held with nothing scheduled to give it
        -- back, which is the one failure this whole design exists to
        -- prevent. Found by a test firing both watchdogs in one go.
        pom.askSeq = (pom.askSeq or 0) + 1
        local ticket = pom.askSeq
        pom.guard = hs.timer.doAfter(pom.answerSecs, function()
            if pom.askSeq ~= ticket then return end     -- a later ask owns it now
            releaseKeys("nobody answered")
            if onExpire then pcall(onExpire) end
        end)
        if not pcall(function() pom.modal:enter() end) then
            releaseKeys("could not take the keyboard")
            warn("modal:enter() failed — ⏎/esc unavailable this round")
            -- 🚨 AND IF THE KEYBOARD COULD NOT BE TAKEN, DO NOT SIT THERE
            -- ASKING A QUESTION NOBODY CAN ANSWER. The panel is showing
            -- "⏎ ⁄ esc" over keys that are not bound.
            if onExpire then pcall(onExpire) end
            return
        end
        s.asking = true
    end

    -- ---- flashing --------------------------------------------------------
    -- A blink is two paints on a repeating timer, counted down and then
    -- stopped. It leaves the panel in the phase's own colours whichever
    -- half of the blink it stops on, so it can never freeze mid-flash.
    local function flash(label, bgA, fgA, bgB, fgB, done)
        local s = pom.state
        if not s then return end
        local left, on = pom.flashCount * 2, true
        if s.flasher then pcall(function() s.flasher:stop() end) end
        s.flasher = hs.timer.doEvery(pom.flashSecs, function()
            if not pom.state then return end
            paint(label, on and "— • —" or mmss(0), on and bgB or bgA,
                  on and fgB or fgA)
            on = not on
            left = left - 1
            if left <= 0 then
                pcall(function() s.flasher:stop() end)
                s.flasher = nil
                if done then pcall(done) end
            end
        end)
    end

    -- ---- phases ----------------------------------------------------------
    local function startPhase(phase)
        local s = pom.state
        if not s then return end
        s.phase  = phase
        s.endsAt = hs.timer.secondsSinceEpoch()
                   + (phase == "work" and pom.workMins or pom.breakMins) * 60
        paint(phase == "work" and "FOCUS" or "BREAK",
              mmss(s.endsAt - hs.timer.secondsSinceEpoch()),
              phase == "work" and pom.bgWork or pom.bgBreak, pom.fgWork)
        say(phase .. " phase started")
    end

    local function phaseEnded()
        local s = pom.state
        if not s then return end
        if s.phase == "work" then
            -- The flash IS the notification. No sound, no hs.notify: this
            -- fires while you are mid-sentence in something, and the whole
            -- design goal is "tells you without taking over".
            flash("STAND UP", pom.bgBreak, pom.fgWork, pom.bgFlash, pom.fgFlash,
                  function() startPhase("break") end)
            -- Nothing to do on expiry: the flash's own completion starts
            -- the break whether you answered or not, so the panel keeps
            -- counting and stays alive.
            askForAnswer(nil)
        else
            flash("DONE", pom.bgWork, pom.fgWork, pom.bgFlash, pom.fgFlash,
                  function()
                      paint("DONE", "⏎ ⁄ esc", pom.bgWork, pom.fgWork)
                  end)
            -- 🚨 THE CYCLE IS OVER. If you do not say "go again" within
            -- answerSecs, it closes itself. There is nothing left for this
            -- panel to count and no keys left bound to it — leaving it up
            -- is leaving a dead window on your screen.
            askForAnswer(function() pom.stop("nobody answered — cycle over") end)
        end
    end

    -- 🧟 6.70.0 — THE ZOMBIE CHECK, AND WHY IT IS A CLASS FIX.
    -- The bug LL hit was ONE path that left the panel on screen with
    -- nothing driving it. Fixing that path is necessary and it is not
    -- sufficient: the panel is a window this module opens and only this
    -- module can close, so EVERY future path that forgets to close it has
    -- the same symptom — a dead rectangle over your work with no
    -- keystroke bound to it. So instead of trusting the paths, the ticker
    -- asks once a second whether the panel is still ALIVE:
    --
    --      alive = counting down  OR  mid-flash  OR  waiting on an answer
    --
    -- Anything else for zombieSecs is a bug, whether or not I have thought
    -- of it, and it closes itself and SAYS SO rather than sitting there.
    -- The report is the point: a panel that quietly tidies itself away
    -- teaches nobody anything.
    local function isAlive(s)
        if s.asking then return true end
        if s.flasher then return true end
        local e = s.endsAt
        if type(e) == "number" and e ~= math.huge and e > hs.timer.secondsSinceEpoch() then
            return true
        end
        return false
    end

    local function tick()
        local s = pom.state
        if not s then return end
        if s.flasher then s.zombieSince = nil return end   -- mid-flash: leave it alone
        local left = s.endsAt - hs.timer.secondsSinceEpoch()
        if left <= 0 then
            s.endsAt = math.huge              -- fire phaseEnded exactly once
            phaseEnded()
            return
        end
        if isAlive(s) then
            s.zombieSince = nil
        else
            s.zombieSince = s.zombieSince or hs.timer.secondsSinceEpoch()
            if hs.timer.secondsSinceEpoch() - s.zombieSince > pom.zombieSecs then
                local phase = tostring(s.phase)
                -- 🚨 CLOSE FIRST, REPORT SECOND, AND THAT ORDER IS THE
                -- WHOLE POINT. The first version of this block reported
                -- and then closed — and the test caught it immediately,
                -- because _G.notices.tell threw and pom.stop() was never
                -- reached. The panel printed "so it closed itself" and
                -- then sat there, which is worse than the bug it was
                -- reporting: now the Console is lying to you.
                -- A REPORTING CALL MUST NEVER BE ABLE TO PREVENT THE
                -- REPAIR IT IS REPORTING. Everything below is pcall'd for
                -- the same reason.
                pom.stop("stranded panel")
                pcall(function()
                    print(string.format(
                        "🍅 Pomodoro: the panel was on screen for %.0fs with "
                        .. "nothing driving it — no countdown, no flash, no "
                        .. "question — so it closed itself. That is a bug in "
                        .. "this module, not in what you pressed. Phase was "
                        .. "'%s'.", pom.zombieSecs, phase))
                end)
                pcall(function()
                    if not _G.notices then return end
                    if _G.notices.record then
                        _G.notices.record("pomodoro", "stranded panel",
                            "on screen with nothing driving it; phase " .. phase)
                    end
                    if _G.notices.tell then
                        _G.notices.tell("🍅 The timer panel was stuck",
                                        "It closed itself — see the Console",
                                        { key = "pomodoro:zombie", every = 600 })
                    end
                end)
                return
            end
        end
        paint(s.phase == "work" and "FOCUS" or "BREAK", mmss(left),
              s.phase == "work" and pom.bgWork or pom.bgBreak, pom.fgWork)
    end

    -- ---- start / stop ----------------------------------------------------
    function pom.stop(why)
        releaseKeys(nil)
        local s = pom.state
        pom.state = nil                        -- cleared FIRST: every timer
                                               -- callback above bails on nil,
                                               -- so nothing can repaint a
                                               -- canvas that is being deleted
        if s then
            if s.ticker  then pcall(function() s.ticker:stop()  end) end
            if s.flasher then pcall(function() s.flasher:stop() end) end
            if s.canvas  then pcall(function() s.canvas:delete() end) end
        end
        if why then say("stopped (" .. why .. ")") end
        return true
    end

    function pom.start()
        pom.stop(nil)                          -- idempotent restart
        local frame = panelFrame()
        if not frame then
            hs.alert.show("🍅 Pomodoro: no screen to draw on")
            warn("could not resolve a screen")
            return false
        end
        local okNew, c = pcall(hs.canvas.new, frame)
        if not (okNew and c) then
            hs.alert.show("🍅 Pomodoro could not open — see the Console")
            warn("hs.canvas.new failed")
            return false
        end
        pom.state = { phase = "work", endsAt = 0, canvas = c }
        local okShow = pcall(function()
            -- 🚨 6.66.1 — fullScreenAuxiliary, NOT "stationary".
            -- "stationary" means "do not move me when Spaces change". It
            -- says NOTHING about full screen, and without
            -- fullScreenAuxiliary a canvas cannot draw over a full-screen
            -- app at all — the timer simply was not there, which reads as
            -- "the shortcut did nothing" rather than as a drawing bug.
            -- Every other panel in this config already had this; the two
            -- that did not were the two written most recently.
            -- 🪟 6.68.0 — ABOVE THE CHEAT SHEET. Both panels used to be at
            -- `overlay`, and two windows at one level are stacked by
            -- whichever was shown last: the timer appeared in front or
            -- behind depending on the order you happened to press the
            -- keys. _G.panelLevel makes that a decision instead of an
            -- accident — see the stacking table in init.lua.
            c:level((_G.panelLevel and _G.panelLevel("pomodoro"))
                    or (hs.canvas.windowLevels or {}).overlay)
            c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
            -- 🖐 6.67.0 — DRAGGABLE, which means it no longer clicks
            -- through. That was the old behaviour and the reasoning was
            -- sound (a panel that swallows clicks for 25 minutes is an
            -- obstacle) — but you cannot grab something that is not there
            -- to be grabbed, and being able to move it was the ask. It is
            -- 170x99 in a screen corner; move it if it is in your way.
            -- makeCanvasDraggable sets the mouse events it needs.
            c:replaceElements(elements("FOCUS", mmss(pom.workMins * 60),
                                       pom.bgWork, pom.fgWork))
        end)
        if _G.makeCanvasDraggable then
            _G.makeCanvasDraggable(c, "pomodoro", function(f)
                pom.pos = { x = f.x, y = f.y }
                say("moved to " .. math.floor(f.x) .. "," .. math.floor(f.y))
            end)
        end
        if okShow then
            -- 🚨 6.66.3 — THROUGH showCanvasSafely, NOT A BARE :show().
            -- From LL's Console, on a hotkey press while Safari's URL-completion
            -- popup was on screen:
            --   NSInternalInconsistencyException: '<NSRemoteView …
            --   SPCompletionListServiceViewController> notified of <HSCanvasWindow>
            --   but expected (null)' in -[NSRemoteView containingWindowWillOrderOnScreen:]
            -- AppKit asserts when our window is ordered on screen while ANOTHER
            -- process's remote view is mid-transition. It is a timing collision, not
            -- a permanent state, which is why the shared helper retries once a run
            -- loop turn later and only then reports. A bare :show() throws, abandons
            -- the rest of the open sequence, and leaves a half-ordered ghost.
            okShow = (_G.showCanvasSafely
                      and _G.showCanvasSafely(c, "pomodoro"))
                     or pcall(function() c:show() end)
        end
        if not okShow then
            pom.stop("draw failed")
            hs.alert.show("🍅 Pomodoro could not draw — see the Console")
            return false
        end
        startPhase("work")
        -- 🚨 THE TICK IS PCALL'D, AND A SWALLOWED THROW IS REPORTED.
        -- It has to be pcall'd — an error on a repeating timer that
        -- reaches the uncaught handler once a second is its own disaster
        -- — but the bare pcall() that was here is how mmss(math.huge)
        -- threw sixty times a minute without anyone ever seeing it. Said
        -- ONCE per run, because the whole failure mode is repetition.
        pom.tickErrorSaid = false
        pom.state.ticker = hs.timer.doEvery(1, function()
            local ok, err = pcall(tick)
            if not ok and not pom.tickErrorSaid then
                pom.tickErrorSaid = true
                print("🍅 Pomodoro: the once-a-second update threw and was "
                      .. "caught — the panel will stop updating. " .. tostring(err))
                if _G.notices then
                    _G.notices.record("pomodoro", "tick failed", tostring(err))
                end
            end
        end)
        say("started")
        return true
    end

    function pom.toggle()
        if not pom.enabled then return false end
        if pom.state then return pom.stop("toggled off") end
        return pom.start()
    end

    -- ---- wiring ----------------------------------------------------------
    -- The modal is built ONCE and reused. Rebuilding it per press is how a
    -- config ends up with two modals bound to the same key, one of which
    -- nothing holds a reference to and nothing can ever exit — the exact
    -- trap section 2 of the Mouse Grid suite exists to catch.
    local okModal, modal = pcall(hs.hotkey.modal.new)
    if okModal and modal then
        pom.modal = modal
        pcall(function()
            modal:bind({}, "return",   function() releaseKeys("⏎");  pom.start() end)
            modal:bind({}, "padenter", function() releaseKeys("⏎");  pom.start() end)
            modal:bind({}, "escape",   function() releaseKeys("esc"); pom.stop("esc") end)
        end)
    else
        warn("no modal — ⏎/esc will not answer the timer, ⇪⇧P still toggles it")
    end

    -- ⎋ 6.68.0 — CLAIM Esc WHILE THE TIMER IS ASKING. The modal above is
    -- enough on its own ONLY when nothing else holds a bare Esc. The cheat
    -- sheet does, for as long as it is open, and hs.hotkey gives the key
    -- to whichever binding was enabled most recently — so opening the
    -- sheet during the flash took Esc away from the timer, and you had to
    -- close the sheet first to reach it. That is the bug LL reported.
    --
    -- Priority 100 against the sheet's 10: for the ~20 seconds a phase
    -- ending is waiting on an answer, the timer wins. The rest of the
    -- time active() returns false and Esc closes the sheet exactly as
    -- before — this takes nothing away, it only breaks a tie.
    if _G.claimEscape then
        _G.claimEscape("pomodoro", 100,
            function() return (pom.state and pom.state.asking) == true end,
            function() releaseKeys("esc"); pom.stop("esc") end)
    end

    if pom.enabled then
        core.hyperAddShortcut({ "shift" }, pom.key, function() pom.toggle() end,
                              "pomodoro")
    end

    core.provide("pomodoro.toggle", function() return pom.toggle() end)
    core.provide("pomodoro.start",  function() return pom.start()  end)
    core.provide("pomodoro.stop",   function() return pom.stop("service") end)

    -- 6.89.0 — listed for Window Move with plain = true: the timer card is
    -- pure display, so a bare click-hold drags it. ⌘-drag works too.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "pomodoro",
        plain = true,
        frame = function()
            return pom.state and pom.state.canvas and pom.state.canvas:frame()
        end,
        move  = function(x, y)
            if pom.state and pom.state.canvas then
                pom.state.canvas:topLeft({ x = x, y = y })
            end
        end,
    })

    _G.pomodoro = pom
    M.pom    = pom
    M.config = pom
end

return M
