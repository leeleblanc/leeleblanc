-- =====================================================================
-- MODULE: GROUND PROBE — what does THIS Mac actually answer? (no key)
-- =====================================================================
-- 6.242.0. The instrument behind the habit written down on 2026-09-17,
-- after 6.231.0 → 6.237.0 cost three losses in a row:
--
--     every release is labelled KNOWN GROUND (the gate can see it —
--     expect it to work) or NEW GROUND (a macOS surface this config has
--     not touched — expect a round), and on new ground the FIRST release
--     is the probe that prints what macOS actually answered, never a fix
--     built on a belief.
--
-- Every one of those three losses happened at a boundary the gate is
-- blind to: hs.webview cannot take a drop · a throw inside a dragging
-- callback is silent · Finder hands over an inode, not a path. None of
-- them could have been found by reading Lua, and all three were found in
-- one evening once something PRINTED what macOS had said.
--
-- So this module asks the questions the NEXT few releases depend on, and
-- prints the answers with the release each one decides written beside
-- it. It changes no behaviour, binds no key and touches no store. It is
-- a `_G.groundReport()` and nothing else.
--
-- ---------------------------------------------------------------------
-- 🔬 WHAT IT ASKS, AND WHAT EACH ANSWER DECIDES
-- ---------------------------------------------------------------------
--   · ACCESSIBILITY — hs.accessibilityState(). Without it hs.eventtap
--     cannot even be created (6.196.0), so this is the floor under click
--     hints, the draft keeper, the doubled-word mark and every tap that
--     already runs.
--   · SECURE INPUT — read, never re-probed. core/capabilities.lua owns
--     that question and asks it in a HELD task; asking it a second way
--     here would be a second opinion about something already answered
--     (6.202.0's deleted-not-tuned rule).
--   · THE FOCUSED ELEMENT — its role, whether it answers
--     AXSelectedTextRange, and whether AXBoundsForRange hands back a
--     RECTANGLE. That last one decides 🟥 the doubled-word underline
--     outright: with no rect there is nowhere to draw, and the feature is
--     the pink alert instead. It also decides how much 💾 the draft
--     keeper can see.
--   · THE CLICKABLE ELEMENTS — a BOUNDED walk of the front window,
--     counting elements and the ones with a clickable role, timed. That
--     is 🖱 click hints: how many hints there would be, and what asking
--     costs on this Mac in the app he actually uses.
--   · ⌘SPACE — whether macOS's own Spotlight shortcut is still enabled,
--     read out of com.apple.symbolichotkeys in a task. He said he would
--     take ⌘Space from Spotlight himself; this says whether he has.
--   · A flagsChanged TAP — can one be created and started at all. That
--     is ⌘⌘ and ⌥⌥, which are double-taps of a MODIFIER and need that
--     event type or they need nothing.
--
-- ---------------------------------------------------------------------
-- 🚨 THE RULES IT KEEPS
-- ---------------------------------------------------------------------
--   · NOTHING RUNS ON THE BOOT PATH. The only work at startup is one
--     `defaults read` in a task, on a held timer after warm, so the first
--     `_G.groundReport()` has an answer to print instead of "asking".
--   · THE AX WALK IS BOUNDED THREE WAYS and says WHICH bound it hit —
--     elements, depth and milliseconds. A bounded scan that reports a
--     state it did not finish reading owes that distinction (6.197.2),
--     and this walk runs on the main thread, in the module whose whole
--     subject is what the main thread costs (6.228.0).
--   · EVERY AX READ IS TIMED (`gp.axTimeout`) and pcall'd — doc_memory's
--     6.160.2 rule, because a slow app answering an AX question is the
--     ⇪Y beach ball in a different costume.
--   · "NOT ASKED", "ASKED AND FAILED" and "ANSWERED" never read the same
--     (6.196.1). Every row here has three states for that reason.
--   · IT PRINTS AS ONE STRING (6.179.1).
-- =====================================================================

local M = {
    name   = "Ground Probe",
    order  = 14.9,
    family = "config",
    summary = "what this Mac answers about the surfaces the next releases need",
    cheatsheet = {
        title = "🧭 GROUND PROBE (no key — a Console report)",
        entries = {
            { "Console", "_G.groundReport() — what macOS answers here, with the release each answer decides" },
            { "reads",   "Accessibility · Secure Input · the focused text element · the front window's clickable elements · ⌘Space · a modifier tap" },
            { "safe",    "It changes nothing, binds nothing and writes nothing. Every AX read is timed and the walk is bounded three ways" },
            { "why",     "On NEW GROUND the first release is a probe that prints what macOS actually said, never a fix built on a belief" },
        },
    },
}

function M.setup(core)
    -- ✏️ EDIT HERE ---------------------------------------------------------
    local gp = {}
    gp.axTimeout   = 0.15   -- seconds, per AX question (doc_memory's number)
    gp.maxElements = 400    -- the walk stops here and SAYS so
    gp.maxDepth    = 12
    gp.budgetMs    = 250    -- …or here, whichever comes first
    gp.maxKids     = 120    -- children read from any one element
    -- ----------------------------------------------------------------------

    gp.spotlight = { state = "not asked yet", enabled = nil, at = nil,
                     why = nil, asks = 0, answers = 0 }
    _G.groundProbeTask  = _G.groundProbeTask  or nil
    _G.groundProbeTimer = _G.groundProbeTimer or nil
    _G.groundProbeKill  = _G.groundProbeKill  or nil

    local DEFAULTS = "/usr/bin/defaults"

    local function num(v, d)
        local n = tonumber(v) ; if n and n == n then return n end ; return d
    end

    -- A monotonic millisecond with a degrade, so "never measured" cannot read
    -- the same as "measured and fast" (6.196.1, and file_tracker's clock).
    gp.clockName = "nothing timed yet"
    function gp.nowMs()
        if hs.timer and hs.timer.absoluteTime then
            local ok, v = pcall(hs.timer.absoluteTime)
            if ok and tonumber(v) then
                gp.clockName = "hs.timer.absoluteTime"
                return tonumber(v) / 1e6
            end
        end
        gp.clockName = "os.clock (coarse)"
        return (os.clock() or 0) * 1000
    end

    -- =====================================================================
    -- ⌘SPACE — IS SPOTLIGHT STILL HOLDING IT?
    -- =====================================================================
    -- PURE, so the gate proves the parse against the real shape of the file
    -- with no Mac under it. `defaults read com.apple.symbolichotkeys` prints
    -- an old-style plist; hotkey 64 is "Show Spotlight search", which is the
    -- ⌘Space LL says he will hand over.
    --
    -- 🚨 AND AN ABSENT KEY IS NOT A DISABLED ONE. macOS writes a hotkey into
    -- that file when you CHANGE it; a Mac nobody has touched has no 64 block
    -- at all and Spotlight still owns ⌘Space. Reading "no block" as "off"
    -- would tell him the key was free on the one Mac where it certainly is
    -- not. Three answers, not two.
    -- → true | false | nil, why
    function gp.parseSpotlight(out)
        if type(out) ~= "string" or out == "" then
            return nil, "nothing to read"
        end
        -- The 64 block, up to the next top-level "<digits> =" or the end.
        local from = out:find("\n%s*64%s*=")
        if not from then
            return nil, "no 64 entry — macOS has never been asked to change"
                        .. " it, so Spotlight still has ⌘Space"
        end
        local rest  = out:sub(from + 1)
        local stop  = rest:find("\n%s*%d+%s*=", 2)
        local block = stop and rest:sub(1, stop - 1) or rest
        local en = block:match("enabled%s*=%s*(%w+)")
        if en == nil then
            return nil, "a 64 entry with no enabled flag — unreadable"
        end
        -- macOS writes 1/0 here; some builds write true/false. Both are real.
        if en == "1" or en == "true" then return true, "enabled" end
        if en == "0" or en == "false" then return false, "disabled" end
        return nil, "enabled = " .. tostring(en) .. ", which is neither"
    end

    -- The IO half. Held in its own global slot and killed on a timer —
    -- 6.196.1's two rules for any task this config starts.
    function gp.askSpotlight(done)
        if type(hs.task) ~= "table" or type(hs.task.new) ~= "function" then
            gp.spotlight.state = "asked and could not run"
            gp.spotlight.why   = "hs.task is unavailable — cannot read the shortcut"
            if done then pcall(done, gp.spotlight) end
            return false, gp.spotlight.why
        end
        gp.spotlight.asks = gp.spotlight.asks + 1
        local okT, t = pcall(hs.task.new, DEFAULTS,
            function(_, out, _)
                if _G.groundProbeKill then
                    pcall(function() _G.groundProbeKill:stop() end)
                    _G.groundProbeKill = nil
                end
                local on, why = gp.parseSpotlight(out)
                gp.spotlight.enabled = on
                gp.spotlight.why     = why
                gp.spotlight.state   = "answered"
                gp.spotlight.at      = os.time()
                gp.spotlight.answers = gp.spotlight.answers + 1
                if done then pcall(done, gp.spotlight) end
            end,
            { "read", "com.apple.symbolichotkeys" })
        if not (okT and t) then
            gp.spotlight.state = "asked and could not run"
            gp.spotlight.why   = "hs.task refused to start " .. DEFAULTS
            if done then pcall(done, gp.spotlight) end
            return false, gp.spotlight.why
        end
        _G.groundProbeTask = t
        gp.spotlight.state = "asking"
        pcall(function() t:start() end)
        -- A task whose callback never comes must not leave the state reading
        -- "asking" for ever — 6.155.0's killer timer.
        local okK, k = pcall(hs.timer.doAfter, 6, function()
            if gp.spotlight.state == "asking" then
                gp.spotlight.state = "asked and never answered"
                gp.spotlight.why   = "the read did not come back within 6 s"
            end
            pcall(function() if _G.groundProbeTask then _G.groundProbeTask:terminate() end end)
            _G.groundProbeKill = nil
        end)
        if okK and k then _G.groundProbeKill = k end
        return true
    end

    -- =====================================================================
    -- THE AX WALK — BOUNDED THREE WAYS, AND IT SAYS WHICH ONE BIT
    -- =====================================================================
    -- Takes any element that answers :attributeValue(name), so the gate
    -- drives it with a fake tree and can prove every bound by making the
    -- tree bigger than the bound — which is the only way to prove a budget
    -- BITES rather than merely EXISTS (6.187.0's rule, paid for twice).
    gp.clickRoles = {
        AXButton = true, AXLink = true, AXCheckBox = true, AXRadioButton = true,
        AXPopUpButton = true, AXMenuButton = true, AXMenuItem = true,
        AXTextField = true, AXTextArea = true, AXComboBox = true,
        AXDisclosureTriangle = true, AXTab = true, AXSlider = true,
    }

    function gp.axCount(root, opts)
        opts = opts or {}
        local maxEl    = num(opts.maxElements, gp.maxElements)
        local maxDepth = num(opts.maxDepth,    gp.maxDepth)
        local budgetMs = num(opts.budgetMs,    gp.budgetMs)
        local maxKids  = num(opts.maxKids,     gp.maxKids)
        local out = { elements = 0, clickable = 0, depth = 0, ms = 0,
                      stopped = nil, roles = {} }
        if not root then out.stopped = "no element" ; return out end
        local t0 = gp.nowMs()
        local function ask(el, name)
            local v ; pcall(function() v = el:attributeValue(name) end) ; return v
        end
        local function visit(el, depth)
            if out.stopped then return end
            if out.elements >= maxEl then out.stopped = "elements" ; return end
            if (gp.nowMs() - t0) > budgetMs then out.stopped = "time" ; return end
            out.elements = out.elements + 1
            if depth > out.depth then out.depth = depth end
            pcall(function() el:setTimeout(num(gp.axTimeout, 0.15)) end)
            local role = ask(el, "AXRole")
            if type(role) == "string" then
                out.roles[role] = (out.roles[role] or 0) + 1
                if gp.clickRoles[role] then out.clickable = out.clickable + 1 end
            end
            if depth >= maxDepth then
                -- Deliberately not a stop: one deep branch must not end the
                -- walk of every other branch. It is recorded as a bound hit
                -- only if nothing worse happened.
                out.deepHits = (out.deepHits or 0) + 1
                return
            end
            local kids = ask(el, "AXChildren")
            if type(kids) ~= "table" then return end
            for i, k in ipairs(kids) do
                if i > maxKids then out.wideHits = (out.wideHits or 0) + 1 ; break end
                visit(k, depth + 1)
                if out.stopped then return end
            end
        end
        pcall(visit, root, 1)
        out.ms = gp.nowMs() - t0
        if not out.stopped and (out.deepHits or 0) > 0 then out.stopped = "depth" end
        if not out.stopped and (out.wideHits or 0) > 0 then out.stopped = "width" end
        return out
    end

    -- =====================================================================
    -- THE FOCUSED ELEMENT — AND THE ONE QUESTION THAT DECIDES 🟥
    -- =====================================================================
    -- 🟥 A pink underline under a doubled word can only be drawn if macOS
    -- will say WHERE the word is on screen. AXBoundsForRange is the only
    -- way to ask, it is a PARAMETERISED attribute, and plenty of apps do not
    -- implement it. This asks for the rect of the first character of the
    -- selection: a rectangle back means the mark is drawable in this app, and
    -- nothing back means the alert is the whole feature here.
    function gp.focusedFacts()
        local f = { app = nil, role = nil, rangeOK = false, boundsOK = false,
                    rect = nil, why = nil }
        if type(hs.axuielement) ~= "table" then
            f.why = "hs.axuielement is not available in this Hammerspoon"
            return f
        end
        local app = nil
        pcall(function() app = hs.application.frontmostApplication() end)
        if not app then f.why = "no front application" ; return f end
        pcall(function() f.app = app:name() end)
        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then f.why = "no AX element for " .. tostring(f.app) ; return f end
        pcall(function() axApp:setTimeout(num(gp.axTimeout, 0.15)) end)
        local el
        pcall(function() el = axApp:attributeValue("AXFocusedUIElement") end)
        if not el then
            f.why = "nothing is focused in " .. tostring(f.app)
                    .. " — click into a text field and run it again"
            return f
        end
        pcall(function() el:setTimeout(num(gp.axTimeout, 0.15)) end)
        pcall(function() f.role = el:attributeValue("AXRole") end)
        local range
        pcall(function() range = el:attributeValue("AXSelectedTextRange") end)
        f.rangeOK = (range ~= nil)
        if not f.rangeOK then
            f.why = "it answers no AXSelectedTextRange — this is not a text"
                    .. " element, or the app does not expose one"
            return f
        end
        -- One character at the caret. A range of zero length is legal and is
        -- what an empty field answers; ask for 1 so a rect has a width.
        local loc = 0
        if type(range) == "table" then loc = num(range.location, 0) end
        local rect
        pcall(function()
            rect = el:parameterizedAttributeValue("AXBoundsForRange",
                                                  { location = loc, length = 1 })
        end)
        if type(rect) == "table" and rect.w ~= nil then
            f.boundsOK, f.rect = true, rect
        elseif type(rect) == "table" and rect.size ~= nil then
            f.boundsOK, f.rect = true, rect
        else
            f.why = "AXSelectedTextRange yes, AXBoundsForRange NO — this app"
                    .. " will not say where a word is on screen"
        end
        return f
    end

    -- =====================================================================
    -- A MODIFIER TAP — ⌘⌘ AND ⌥⌥ NEED IT OR THEY NEED NOTHING
    -- =====================================================================
    -- Created and immediately stopped. It is never started with a handler
    -- that does anything: this release changes no behaviour, and a tap left
    -- running would be exactly that.
    function gp.flagsTapOK()
        if type(hs.eventtap) ~= "table" or type(hs.eventtap.new) ~= "function" then
            return false, "hs.eventtap is not available"
        end
        local types = hs.eventtap.event and hs.eventtap.event.types
        if not (types and types.flagsChanged) then
            return false, "this Hammerspoon has no flagsChanged event type"
        end
        local ok, tap = pcall(hs.eventtap.new, { types.flagsChanged },
                              function() return false end)
        if not (ok and tap) then
            return false, "hs.eventtap.new refused — Accessibility is the"
                          .. " usual reason, and a re-grant needs a RELAUNCH"
        end
        local started = false
        pcall(function() tap:start() ; started = tap:isEnabled() end)
        pcall(function() tap:stop() end)
        if not started then
            return false, "it was created but would not start"
        end
        return true, "created and started (then stopped again at once)"
    end

    -- =====================================================================
    -- THE REPORT
    -- =====================================================================
    function _G.groundReport()
        local L = { "🧭 GROUND PROBE — what THIS Mac answers, and what each"
                    .. " answer decides" }
        local function line(t) L[#L + 1] = t end

        -- ---- Accessibility ------------------------------------------
        local axOK = nil
        pcall(function() axOK = hs.accessibilityState() end)
        line("   access   : " .. (axOK == true and "GRANTED"
                                  or axOK == false and "⚠️ NOT GRANTED"
                                  or "could not ask"))
        if axOK ~= true then
            line("   ↳ without it hs.eventtap cannot even be CREATED, so the")
            line("     snippets, autocorrect, the key caster and ⇪'s fallback")
            line("     are all off. Grant it, then QUIT AND RELAUNCH — taps are")
            line("     built at launch and a mid-session grant changes nothing.")
        end

        -- ---- Secure input (read, never re-probed) -------------------
        local si = _G.secureInput
        if type(si) ~= "table" then
            line("   secure   : core/capabilities.lua has not loaded — not asked")
        elseif si.on == nil then
            line("   secure   : not answered yet — " .. tostring(si.why))
        elseif si.on then
            line("   secure   : ⚠️ HELD by " .. tostring(si.app or "?")
                 .. " (pid " .. tostring(si.pid) .. ") — every tap is deaf"
                 .. " while it is, and so is every other app")
        else
            line("   secure   : clear — nothing is holding the keyboard")
        end

        -- ---- The focused element ------------------------------------
        local f = gp.focusedFacts()
        line("   front    : " .. tostring(f.app or "nothing")
             .. (f.role and ("  ·  focused role " .. tostring(f.role)) or ""))
        line("   caret    : " .. (f.rangeOK and "AXSelectedTextRange answered"
                                  or "no AXSelectedTextRange"))
        line("   bounds   : " .. (f.boundsOK
             and "AXBoundsForRange ANSWERED — a mark can be drawn over the text here"
             or  "⚠️ no rectangle — a mark cannot be drawn in this app"))
        if f.why then line("   ↳ " .. f.why) end
        if f.boundsOK and type(f.rect) == "table" then
            line(("   ↳ one character at the caret is at %s,%s %s×%s")
                 :format(tostring(f.rect.x), tostring(f.rect.y),
                         tostring(f.rect.w), tostring(f.rect.h)))
        end
        line("   ↳ DECIDES 🟥 the doubled-word mark and 💾 the draft keeper.")
        line("     Run this again with the caret in Chrome, in Asana, and in")
        line("     Mail — the answer is per APP, and that is the whole point.")

        -- ---- The clickable elements ---------------------------------
        local root = nil
        if type(hs.axuielement) == "table" then
            pcall(function()
                local app = hs.application.frontmostApplication()
                local axApp = app and hs.axuielement.applicationElement(app)
                if axApp then
                    axApp:setTimeout(num(gp.axTimeout, 0.15))
                    root = axApp:attributeValue("AXFocusedWindow")
                end
            end)
        end
        if not root then
            line("   clicks   : no front window to walk — not asked")
        else
            local w = gp.axCount(root)
            line(("   clicks   : %d element(s) · %d with a clickable role · %.0f ms")
                 :format(w.elements, w.clickable, w.ms))
            -- 🔎 A BOUNDED SCAN THAT DID NOT FINISH SAYS SO (6.197.2): the
            -- counts above are a FLOOR when a bound bit, not a measurement.
            if w.stopped then
                line("   ↳ ⚠️ it stopped at the " .. tostring(w.stopped)
                     .. " bound, so those counts are a FLOOR, not a total")
                line("     (elements " .. gp.maxElements .. " · depth "
                     .. gp.maxDepth .. " · " .. gp.budgetMs .. " ms · "
                     .. gp.maxKids .. " children per element)")
            else
                line("   ↳ it walked the WHOLE window inside every bound")
            end
            line("   ↳ DECIDES 🖱 click hints: that is how many hints this")
            line("     window would grow, and what asking cost your main")
            line("     thread — which is the number 6.228.0 taught us to fear.")
        end

        -- ---- ⌘Space -------------------------------------------------
        local sp = gp.spotlight
        if sp.state == "answered" then
            if sp.enabled == true then
                line("   ⌘space   : Spotlight STILL HAS IT — enabled in"
                     .. " com.apple.symbolichotkeys")
            elseif sp.enabled == false then
                line("   ⌘space   : FREE — Spotlight's own shortcut is switched off")
            else
                line("   ⌘space   : unreadable — " .. tostring(sp.why))
            end
            if sp.enabled ~= false and sp.why then
                line("   ↳ " .. tostring(sp.why))
            end
        else
            line("   ⌘space   : " .. tostring(sp.state)
                 .. (sp.why and ("  ·  " .. tostring(sp.why)) or ""))
        end
        line("   ↳ DECIDES the ⌘Space launcher. Turn Spotlight's shortcut off")
        line("     in System Settings › Keyboard › Keyboard Shortcuts ›")
        line("     Spotlight, then run this again — it must read FREE first.")
        -- Asked again for NEXT time, never blocking this print.
        pcall(gp.askSpotlight)

        -- ---- A modifier tap -----------------------------------------
        local tapOK, tapWhy = gp.flagsTapOK()
        line("   ⌘⌘ / ⌥⌥  : " .. (tapOK and "a modifier tap works here"
                                   or "⚠️ no modifier tap"))
        line("   ↳ " .. tostring(tapWhy))
        line("   ↳ DECIDES ⌘⌘ the clipboard picker and ⌥⌥ the menu bar.")

        line("   clock    : " .. tostring(gp.clockName))
        line("   ↳ this report changes NOTHING. It binds no key, writes no")
        line("     file and leaves no tap running.")
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if core.provide then
        core.provide("ground.report", function() return _G.groundReport() end)
    end

    -- One `defaults read` in a task, on a held timer AFTER warm, so his
    -- first _G.groundReport() has an answer rather than "asking". Nothing
    -- else here runs until he asks.
    M.warm = function()
        local ok, t = pcall(hs.timer.doAfter, 3, function()
            pcall(gp.askSpotlight)
        end)
        if ok and t then _G.groundProbeTimer = t end
        return true
    end

    _G.groundProbe = gp
    M.gp     = gp
    M.config = gp
end

return M
