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
        return {
            x = f.x + f.w - pom.width - pom.marginX,
            y = f.y + pom.marginY,
            w = pom.width, h = pom.height,
        }
    end

    local function mmss(secs)
        secs = math.max(0, math.floor(secs + 0.5))
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
    local function askForAnswer()
        local s = pom.state
        if not s then return end
        pom.guard = hs.timer.doAfter(pom.answerSecs, function()
            releaseKeys("nobody answered")
        end)
        if not pcall(function() pom.modal:enter() end) then
            releaseKeys("could not take the keyboard")
            warn("modal:enter() failed — ⏎/esc unavailable this round")
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
            askForAnswer()
        else
            flash("DONE", pom.bgWork, pom.fgWork, pom.bgFlash, pom.fgFlash,
                  function()
                      paint("DONE", "⏎ ⁄ esc", pom.bgWork, pom.fgWork)
                  end)
            askForAnswer()
        end
    end

    local function tick()
        local s = pom.state
        if not s then return end
        if s.flasher then return end          -- mid-flash: leave it alone
        local left = s.endsAt - hs.timer.secondsSinceEpoch()
        if left <= 0 then
            s.endsAt = math.huge              -- fire phaseEnded exactly once
            phaseEnded()
            return
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
            c:level((hs.canvas.windowLevels or {}).overlay)
            c:behaviorAsLabels({ "canJoinAllSpaces", "stationary" })
            -- Click-through. A quarter of the screen corner that swallows
            -- clicks for 25 minutes is not a timer, it is an obstacle.
            c:canvasMouseEvents(false, false, false, false)
            c:replaceElements(elements("FOCUS", mmss(pom.workMins * 60),
                                       pom.bgWork, pom.fgWork))
            c:show()
        end)
        if not okShow then
            pom.stop("draw failed")
            hs.alert.show("🍅 Pomodoro could not draw — see the Console")
            return false
        end
        startPhase("work")
        pom.state.ticker = hs.timer.doEvery(1, function() pcall(tick) end)
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
        warn("no modal — ⏎/esc will not answer the timer, ⇪pad+ still toggles it")
    end

    if pom.enabled then
        core.hyperAddShortcut({ "shift" }, pom.key, function() pom.toggle() end,
                              "pomodoro")
    end

    core.provide("pomodoro.toggle", function() return pom.toggle() end)
    core.provide("pomodoro.start",  function() return pom.start()  end)
    core.provide("pomodoro.stop",   function() return pom.stop("service") end)

    _G.pomodoro = pom
    M.pom    = pom
    M.config = pom
end

return M
