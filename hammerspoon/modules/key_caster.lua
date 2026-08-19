-- =====================================================================
-- MODULE: KEY CASTER (⇪⇧B) — show the shortcuts as you press them
-- =====================================================================
-- A near-black rounded panel, floating on a shadow, right-hand edge of
-- whichever screen you are working on, vertically centred. Every shortcut
-- you press appears in it, under the name of the app it landed in. It
-- stays up while you are still pressing, GROWS as more keys arrive, and
-- fades a moment after you stop.
--
--        ⇪⇧B        turn it on and off
--        drag it    it stays where you put it for the session
--
-- ---- 📏 6.116.0 — IT IS THE SIZE OF WHAT IS IN IT -------------------
-- Until now it was a fixed 400×600 box, so one keystroke drew one line
-- at the top of a rectangle six lines tall and mostly air. LL: "I need
-- the keycaster grow in size as keys are sent", and "can the keycaster
-- be bigger". Those are the same fix: the panel is now exactly as tall
-- as the lines it holds and as wide as the widest of them, which is
-- what lets the type inside be large without the box owning the screen.
-- It grows DOWNWARD and LEFTWARD, keeping the anchors that matter — the
-- right edge and the vertical centre — so a new keystroke never shoves
-- the panel sideways under your eye.
--
-- ---- WHAT IT SHOWS, AND WHAT IT DELIBERATELY DOES NOT ---------------
-- LL: "would not display when only typing words -- unless I want to
-- display them along with other keypresses."
--
-- So the default is SHORTCUTS ONLY. A keystroke earns a line if it is:
--        · any combination with ⌘ ⌃ ⌥ fn or ⇪ (the hyper key)
--        · ⇧ with a NON-typing key — ⇧⇥, ⇧⎋, ⇧↑
--        · a bare special key that needs no modifier — ⎋ ⇥ ⏎ ⌫ ↑↓←→
--          ⇞ ⇟ ↖ ↘ and every F-key
--        · fn + anything, F-keys included
-- and it does NOT earn one if it is:
--        · a letter, digit or punctuation mark, with or without ⇧
--
-- 🚨 ⇧ + A LETTER IS A CAPITAL LETTER, NOT A SHORTCUT. That single rule
-- is the difference between a useful panel and one that scrolls your
-- whole sentence up the side of the screen. Set kc.showTyping = true
-- (or the ⌨️ row in ⇪⇧B's own toggle) and everything appears, which is
-- what you want when recording a demo.
--
-- ---- ⇪ IS INVISIBLE FROM THE OUTSIDE, AND THIS IS WHY --------------
-- Caps Lock is remapped to F18 at the HID level and turned into a modal
-- in §3.12. Anything watching the keyboard therefore sees a bare F18, or
-- — for a key the modal does not claim — a SYNTHETIC ⌘⇧⌃⌥ chord. Neither
-- is what you pressed. Drawing "⌘⇧⌃⌥X" for a key you experienced as
-- "⇪X" is accurate and useless, so this module reads _G.hyperActive
-- (published by §3.12 in 6.71.0) and renders ⇪ instead. If that global
-- is missing — an older init.lua, a changed §3.12 — it falls back to
-- watching F18 itself and says so once. It never guesses silently.
--
-- =====================================================================
-- 🚨 THIS IS THE THIRD GLOBAL KEYBOARD TAP IN THIS CONFIG
-- =====================================================================
-- Autocorrect watches every keystroke. The text expander watches every
-- keystroke. This makes three, and it is the only one of them that
-- exists purely to look at things — so it is held to the strictest
-- version of every rule the other two follow:
--
--   · IT NEVER CONSUMES A KEYSTROKE. The callback returns false on every
--     path, including the error paths. There is a test that drives every
--     branch and asserts the return value, because a display tool that
--     eats a keypress is worse than no display tool.
--   · IT NEVER LOGS WHAT YOU TYPE. Nothing reaches the Console, the
--     notices ledger or ⇪⇧D except COUNTS. The panel itself is the only
--     place a keystroke is ever rendered, and it holds kc.maxLines of
--     them in memory and nothing on disk. With showTyping off it does
--     not even keep the characters.
--   · IT STANDS DOWN FOR THE SHARED INJECTION GUARD, so the expander's
--     and autocorrect's synthetic typing is not drawn as though you had
--     pressed it.
--   · IT DISABLES ITSELF RATHER THAN DEGRADING YOUR KEYBOARD. See the
--     🛟 note at the tap: consecutive failures stop it and report. LL's
--     requirement, in their words: "anything we add must fail without
--     ruining, stopping, or interfering with any other running tool
--     that functions properly."
--   · IT IS OFF UNTIL YOU TURN IT ON. kc.startEnabled = false, so a
--     module whose whole job is watching your keyboard does nothing at
--     all until asked.

local M = {
    name  = "Key Caster",
    order = 13.57,
    family = "config",          -- with the other keyboard tools
    cheatsheet = {
        title = "⌨️ KEY CASTER (⇪⇧B — show the keys you press)",
        entries = {
            { "⇪⇧B",     "Turn the panel on / off (it starts OFF)" },
            { "shows",   "Shortcuts only — ⌘⌃⌥fn⇪ combos, ⎋ ⇥ ⏎ arrows, F-keys" },
            { "app",     "The frontmost app's name sits above the keys" },
            { "expands", "A text-expander snippet shows as ⌨ trigger → what it did" },
            { "hides",   "Plain typing, and ⇧+letter (that is a capital)" },
            { "all keys", "_G.keyCastTyping(true) — show typing too, for a demo" },
            { "where",   "Right edge, vertically centred — it GROWS as keys arrive" },
            { "drag",    "Move it anywhere; it stays there for the session" },
            { "stays",   "Up while you keep pressing, fades after you stop" },
            { "never",   "Nothing you type is logged anywhere — see the header" },
        },
    },
}

function M.setup(core)
    local kc = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    kc.enabled      = true      -- false = the module loads and binds nothing
    -- ⇪⇧B for Broadcast — and it took two tries to get here, both caught
    -- before this module ever reached a keyboard:
    --   · ⇪⇧K ("keys") collided with the URL cleaner's undo — §0.3's
    --     hotkey sentry.
    --   · ⇪⇧B ("cast") collided with a MIGRATED alt+cmd+ctrl+shift+c,
    --     which lives in §0.4's migration map rather than in any module —
    --     a source a human survey of modules/ would have missed entirely.
    -- That second one is the whole argument for the sentry: a silently
    -- shadowed shortcut is indistinguishable from a broken feature, and
    -- both of these would have been exactly that.
    kc.key          = "b"
    kc.startEnabled = false     -- 🔒 OFF at boot. Turn it on when you want it.
    kc.showTyping   = false     -- true = plain letters appear too
    kc.showBareModifiers = false -- true = a lone ⇧ or ⌘ press gets a line
    kc.maxLines     = 8         -- how many key combos are visible at once
    kc.holdSecs     = 7.0       -- fade this long after the LAST keystroke
    kc.fadeSecs     = 0.15      -- fast fade
    kc.repeatWindow = 0.9       -- same combo inside this becomes "×2"
    kc.dedupeWindow = 0.06      -- one press, two events (see the ⇪ note)
    -- 📱 6.116.0 — WHICH APP THE KEYS ARE LANDING IN. LL: "I need the
    -- application it is in while it is capturing keys? It's great for
    -- displaying but it's not that useful." A header line, dimmer and
    -- smaller than the keys, naming the frontmost app.
    kc.showApp      = true
    -- ⏱ …and the app name is CACHED. hs.application.frontmostApplication()
    -- on every keystroke is a call into the Accessibility API from inside
    -- an event tap, which is the one place in this config where a few
    -- milliseconds per key actually adds up. Half a second is far shorter
    -- than the time it takes to switch apps and far longer than the gap
    -- between two keys in a burst.
    kc.appCacheSecs = 0.5
    -- ⌨️ 6.116.0 — TEXT EXPANSIONS GET A LINE. LL: "Can the keycaster be
    -- bigger and show text expansion key?" The expander calls
    -- _G.keyCastNote() when it fires; the caster cannot see the expansion
    -- itself because it stands down for the shared injection guard, which
    -- is exactly right — those synthetic keys are not keys you pressed.
    kc.showExpansions = true
    -- 🔒 AND IT SHOWS THE TRIGGER, NOT THE TEXT, BY DEFAULT. LL's snippets
    -- hold real email addresses, a phone number and an employee ID —
    -- that is why snippets/ is in .gitignore — and a panel that paints
    -- them across the screen is one screen-share away from being the
    -- wrong tool. The trigger is what he asked for anyway ("show text
    -- expansion key"). Set this true when recording a demo of the
    -- expander itself.
    kc.showExpansionText = false
    -- Type. Sans serif.
    kc.font         = "Helvetica Neue"
    -- 📏 6.116.0 — THE PANEL IS SIZED BY WHAT IS IN IT. LL: "I need the
    -- keycaster grow in size as keys are sent." It was a fixed 400×600
    -- box, which meant one keystroke drew one line at the top of a
    -- half-empty rectangle six lines tall — and made "can the keycaster
    -- be bigger" a strange request to receive about a panel that was
    -- mostly air. Now the height is the number of lines actually held and
    -- the width is the widest of them, so the box is always snug and the
    -- type inside it can be large without the panel dominating the
    -- screen.
    kc.lineH        = 58        -- one row of keys
    kc.fontSize     = 40        -- the keys themselves
    kc.headerSize   = 20        -- the app name above them
    kc.minW         = 240       -- never narrower than this
    kc.maxW         = 660       -- never wider; long labels are clipped, not wrapped
    kc.padX, kc.padY = 22, 16
    kc.marginRight  = 28        -- gap from the right edge of the screen
    -- 🎨 6.90.0 — the shared card look (modules/ui_style.lua); the old
    -- literals stay as fallbacks so a boot without it draws unchanged.
    local st = _G.uiStyle or {}
    kc.radius       = st.radius or 12
    kc.bg           = st.bg    or { red = 0.04, green = 0.04, blue = 0.05, alpha = 0.93 }
    kc.fg           = st.fg    or { white = 1.00, alpha = 0.97 }
    kc.fgDim        = st.fgDim or { white = 1.00, alpha = 0.45 }   -- older lines recede
    kc.shadowBlur   = 22
    kc.shadowAlpha  = 0.55
    -- 🛟 Consecutive callback failures before the tap switches itself off.
    kc.maxFailures  = 5
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("keyCaster", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("keyCaster", m) end end

    kc.on        = false     -- is the caster listening?
    kc.lines     = {}        -- { text, at, count } — newest LAST
    kc.canvas    = nil
    kc.pos       = nil       -- where you dragged it, this session
    kc.failures  = 0
    kc.shown     = 0         -- counts only; never the keys themselves
    kc.hideTimer = nil
    kc.lastEvent = nil       -- { text, at } for the dedupe window

    -- ---- naming the keys -------------------------------------------------
    -- The glyphs macOS itself uses, so the panel reads like a menu.
    local GLYPH = {
        ["escape"] = "⎋", ["tab"] = "⇥", ["return"] = "⏎", ["padenter"] = "⌤",
        ["delete"] = "⌫", ["forwarddelete"] = "⌦", ["space"] = "␣",
        ["up"] = "↑", ["down"] = "↓", ["left"] = "←", ["right"] = "→",
        ["home"] = "↖", ["end"] = "↘", ["pageup"] = "⇞", ["pagedown"] = "⇟",
        ["help"] = "?⃝", ["clear"] = "⌧", ["padclear"] = "⌧",
    }

    -- Keys that are a SHORTCUT on their own, with no modifier at all.
    -- Deliberately does NOT include space or the character keys.
    local BARE_WORTHY = {
        ["escape"] = true, ["tab"] = true, ["return"] = true,
        ["padenter"] = true, ["forwarddelete"] = true,
        ["up"] = true, ["down"] = true, ["left"] = true, ["right"] = true,
        ["home"] = true, ["end"] = true, ["pageup"] = true,
        ["pagedown"] = true, ["help"] = true,
    }

    -- ⚠️ DELETE IS NOT IN THE LIST ABOVE, on purpose. Backspace is part of
    -- typing — you press it constantly — and a panel that lit up on every
    -- correction would be unusable. ⌘⌫ and ⌥⌫ still show, because those
    -- carry a modifier and go through the normal rule.

    -- Text labels for the display — modifier names and special-key names,
    -- joined with "+" so the panel reads like a menu item label.
    local KEY_TEXT = {
        ["escape"] = "escape", ["tab"] = "tab", ["return"] = "return",
        ["padenter"] = "enter", ["delete"] = "delete",
        ["forwarddelete"] = "fwd-del", ["space"] = "space",
        ["up"] = "up", ["down"] = "down", ["left"] = "left", ["right"] = "right",
        ["home"] = "home", ["end"] = "end", ["pageup"] = "page-up",
        ["pagedown"] = "page-down", ["help"] = "help",
        ["clear"] = "clear", ["padclear"] = "clear",
    }

    local function isFKey(name)
        return name:match("^f%d+$") ~= nil
    end

    -- A single printable character is typing. Anything longer is a named
    -- key (hs gives "escape", "pageup", "f3"…).
    local function isCharacterKey(name)
        if not name then return false end
        if #name == 1 then return true end
        return name == "space"
    end

    -- Build the display string for one event, or nil if it does not earn a
    -- line. THIS FUNCTION IS THE WHOLE POLICY and it is pure — no state,
    -- no drawing — so the test can drive every combination through it
    -- directly rather than through a canvas.
    function kc.describe(name, flags, hyper)
        if not name or name == "" then return nil end
        flags = flags or {}
        name = tostring(name):lower()

        -- The hyper key eats the four modifiers it synthesises: while ⇪ is
        -- held, ⌘⇧⌃⌥ on the event are ours, not yours.
        local cmd, ctrl, alt, shift = flags.cmd, flags.ctrl, flags.alt, flags.shift
        if hyper then cmd, ctrl, alt, shift = false, false, false, false end
        local fn = flags.fn

        local hasHard = hyper or cmd or ctrl or alt or fn
        local worthy
        if hasHard then
            worthy = true                       -- any real modifier chord
        elseif shift then
            -- ⇧ alone counts ONLY with a non-typing key. ⇧a is a capital A.
            worthy = not isCharacterKey(name)
                     and (BARE_WORTHY[name] or isFKey(name) or GLYPH[name] ~= nil)
        else
            worthy = BARE_WORTHY[name] or isFKey(name)
        end
        if not worthy and kc.showTyping then worthy = true end
        if not worthy then return nil end

        local out = {}
        if hyper then out[#out + 1] = "hyper" end
        if fn    then out[#out + 1] = "fn" end
        if ctrl  then out[#out + 1] = "ctrl" end
        if alt   then out[#out + 1] = "opt" end
        if shift then out[#out + 1] = "shift" end
        if cmd   then out[#out + 1] = "cmd" end

        local label = KEY_TEXT[name]
        if not label then
            if isFKey(name) then label = name:upper()
            elseif #name == 1 then label = name
            else label = name end
        end
        out[#out + 1] = label
        return table.concat(out, "+")
    end

    -- ---- 📱 which app the keys are landing in -----------------------------
    -- Cached: see kc.appCacheSecs. A failure here costs the header line and
    -- nothing else — the keys are what the panel is for.
    kc.appName    = nil
    kc.appNameAt  = 0
    function kc.frontApp()
        if not kc.showApp then return nil end
        local now = hs.timer.secondsSinceEpoch()
        if kc.appName and (now - kc.appNameAt) < kc.appCacheSecs then
            return kc.appName
        end
        local name
        pcall(function()
            local app = hs.application.frontmostApplication()
            if app then name = app:name() end
        end)
        kc.appName, kc.appNameAt = name, now
        return name
    end

    -- ---- 📏 how wide does this text need to be? ---------------------------
    -- An ESTIMATE, deliberately, and deliberately a generous one: too wide
    -- is a slightly roomy panel, too narrow is a clipped shortcut, and only
    -- one of those is a bug.
    --
    -- The exact answer would mean hs.drawing.getTextDrawingSize — which is
    -- deprecated, and hs-lint fails the build for reaching into hs.drawing
    -- at all, correctly: mixing it with hs.canvas means two coordinate and
    -- level systems in one config. Measuring through a throwaway canvas is
    -- the modern route and is not worth it here, because everything on this
    -- panel is a short label of the shape "hyper+shift+page-down".
    --
    -- 🚨 CHARACTERS, NOT BYTES. "⌨ hte → 12 chars" is 20 characters and 26
    -- bytes; counting bytes would draw a panel a third wider than it needs
    -- to be, and the glyph-heavy lines are exactly the ones this panel
    -- exists to show.
    local function textWidth(text, size)
        local s = tostring(text)
        local n
        pcall(function() n = utf8.len(s) end)
        return (n or #s) * size * 0.62
    end

    -- ---- the panel -------------------------------------------------------
    -- 📐 THE SIZE IS THE CONTENT. Height is however many lines are actually
    -- held (plus the app header when there is one); width is the widest
    -- line, floored at minW and capped at maxW.
    function kc.contentSize()
        local header = kc.frontApp()
        local rows   = #kc.lines
        local h = kc.padY * 2 + rows * kc.lineH
        if header then h = h + kc.headerSize + 8 end

        local widest = kc.minW - kc.padX * 2
        for _, l in ipairs(kc.lines) do
            local text = l.text
            if l.count > 1 then text = text .. "  ×" .. l.count end
            local tw = textWidth(text, kc.fontSize)
            if tw > widest then widest = tw end
        end
        if header then
            local hw = textWidth(header, kc.headerSize)
            if hw > widest then widest = hw end
        end
        local w = math.min(kc.maxW, math.max(kc.minW, widest + kc.padX * 2))
        return math.floor(w), math.floor(h), header
    end

    local function panelFrame()
        local scr
        pcall(function() scr = core.resolveBaseScreen and core.resolveBaseScreen() end)
        if not scr then pcall(function() scr = hs.screen.mainScreen() end) end
        if not scr then return nil end
        local f
        pcall(function() f = scr:frame() end)
        if not f then return nil end

        local w, h, header = kc.contentSize()

        -- The canvas is bigger than the box so the SHADOW is not clipped.
        -- A shadow drawn to the edge of its own canvas is a grey stripe.
        local pad = kc.shadowBlur + 6
        if kc.pos then
            -- 🚨 A GROWING PANEL KEEPS ITS RIGHT EDGE. The text is right
            -- aligned and the panel lives on the right of the screen, so
            -- growth has to go LEFTWARD — anchoring the left edge instead
            -- would make every new keystroke shove the whole panel
            -- sideways under your eye. The drag remembers both, and the
            -- right edge wins when it is known (a hand-set kc.pos with
            -- only x still works, which is what the tests set).
            local x = kc.pos.right and (kc.pos.right - (w + pad * 2)) or kc.pos.x
            local p = { x = x, y = kc.pos.y }
            if _G.clampToScreen then
                p = _G.clampToScreen(p, w + pad * 2, h + pad * 2) or p
            end
            return { x = p.x, y = p.y, w = w + pad * 2, h = h + pad * 2 },
                   w, h, pad, header
        end
        -- 📍 RIGHT EDGE, VERTICALLY CENTRED, on the screen holding the
        -- front window, so it follows you between monitors and Spaces.
        -- Both anchors are edges the growth does not move: the box gets
        -- taller around its own middle and wider to the left.
        return {
            x = f.x + f.w - w - kc.marginRight - pad,
            y = f.y + (f.h - h) / 2 - pad,
            w = w + pad * 2, h = h + pad * 2,
        }, w, h, pad, header
    end

    local function elements(w, h, pad, header)
        local els = {
            {
                type = "rectangle", action = "fill",
                fillColor = kc.bg,
                roundedRectRadii = { xRadius = kc.radius, yRadius = kc.radius },
                frame = { x = pad, y = pad, w = w, h = h },
                -- The shadow IS the perimeter — there is no stroke. That
                -- is what makes it read as floating rather than as a box
                -- with a border drawn round it.
                withShadow = true,
                shadow = {
                    blurRadius = kc.shadowBlur,
                    color = { alpha = kc.shadowAlpha, black = 1.0 },
                    offset = { h = -3.0, w = 0.0 },
                },
            },
        }
        -- 📱 The app header, above the keys and deliberately quieter than
        -- them: it is context, not content. Drawn first so the keys sit
        -- under it in reading order.
        local top = pad + kc.padY
        if header then
            els[#els + 1] = {
                type = "text", text = header,
                textFont = kc.font, textSize = kc.headerSize,
                textColor = kc.fgDim,
                textAlignment = "right",
                frame = { x = pad + kc.padX * 0.5, y = top,
                          w = w - kc.padX, h = kc.headerSize + 4 },
            }
            top = top + kc.headerSize + 8
        end
        for i, l in ipairs(kc.lines) do
            local text = l.text
            if l.count > 1 then text = text .. "  ×" .. l.count end
            -- Newest line is bright; older ones recede so your eye lands on
            -- what you just pressed without the panel flashing.
            local newest = (i == #kc.lines)
            els[#els + 1] = {
                type = "text", text = text,
                textFont = kc.font, textSize = kc.fontSize,
                textColor = newest and kc.fg or kc.fgDim,
                textAlignment = "right",
                frame = { x = pad + kc.padX * 0.5,
                          y = top + (i - 1) * kc.lineH,
                          w = w - kc.padX, h = kc.lineH },
            }
        end
        return els
    end

    function kc.hide()
        if kc.hideTimer then
            pcall(function() kc.hideTimer:stop() end)
            kc.hideTimer = nil
        end
        local c = kc.canvas
        kc.canvas = nil                 -- cleared FIRST, like every other
        kc.lines = {}                   -- panel in this config
        if c then pcall(function() c:delete() end) end
    end

    -- 🕒 THE FADE IS RE-ARMED ON EVERY KEYSTROKE, WHICH IS THE ASK.
    -- LL: "should not fade until the keypresses are done displaying so we
    -- must leave the box up until the key presses are done." So the timer
    -- is not a lifetime, it is an IDLE timeout — each new key cancels the
    -- pending fade and starts a fresh one. Hold a chord down and the panel
    -- simply stays.
    local function armHide()
        if kc.hideTimer then pcall(function() kc.hideTimer:stop() end) end
        kc.hideTimer = hs.timer.doAfter(kc.holdSecs, function()
            local c = kc.canvas
            if not c then return end
            -- Fade THEN delete, and the delete is what actually clears the
            -- state — so a keystroke landing mid-fade (below) can simply
            -- reset the alpha and cancel this.
            pcall(function() c:alpha(1.0) end)
            local okFade = pcall(function()
                c:hide(kc.fadeSecs)
            end)
            local t = hs.timer.doAfter(kc.fadeSecs + 0.05, function()
                if kc.canvas == c then kc.hide() end
            end)
            kc.fadeTimer = t
            if not okFade then kc.hide() end
        end)
    end

    function kc.render()
        if #kc.lines == 0 then kc.hide() return false end
        local rect, w, h, pad, header = panelFrame()
        if not rect then
            warn("no screen to draw on")
            return false
        end
        if not kc.canvas then
            local okNew, c = pcall(hs.canvas.new, rect)
            if not (okNew and c) then
                warn("hs.canvas.new failed — the caster cannot draw")
                return false
            end
            kc.canvas = c
            pcall(function()
                c:level((_G.panelLevel and _G.panelLevel("keycaster"))
                        or (hs.canvas.windowLevels or {}).overlay)
                -- Over full-screen apps and on every Space, like every
                -- other panel here. "stationary" is about Spaces and says
                -- nothing about full screen — 6.66.1 learned that twice.
                c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
            end)
            if _G.makeCanvasDraggable then
                _G.makeCanvasDraggable(c, "key caster", function(fr)
                    -- Both anchors are kept: `right` is what a growing
                    -- panel holds on to, `x` is the fallback for a
                    -- position set by hand.
                    kc.pos = { x = fr.x, y = fr.y, right = fr.x + (fr.w or 0) }
                    say("moved to " .. math.floor(fr.x) .. "," .. math.floor(fr.y))
                end)
            end
        else
            pcall(function() kc.canvas:frame(rect) end)
        end
        -- A keystroke arriving mid-fade cancels it and brings the panel
        -- back to full opacity rather than letting it vanish under you.
        if kc.fadeTimer then pcall(function() kc.fadeTimer:stop() end) end
        pcall(function() kc.canvas:alpha(1.0) end)
        pcall(function() kc.canvas:replaceElements(elements(w, h, pad, header)) end)
        if _G.showCanvasSafely then _G.showCanvasSafely(kc.canvas, "key caster")
        else pcall(function() kc.canvas:show() end) end
        armHide()
        return true
    end

    -- ---- one keystroke ---------------------------------------------------
    function kc.push(text, isRepeat)
        if not text then return false end
        local now = hs.timer.secondsSinceEpoch()
        -- 🔁 ONE PRESS CAN ARRIVE TWICE. A hyper shortcut fires the modal
        -- AND — for a key the modal does not claim — re-sends a synthetic
        -- ⌘⇧⌃⌥ chord, so the tap sees two events a few milliseconds apart
        -- describing one keypress. Same text inside dedupeWindow is one
        -- press, not two.
        --
        -- 🚨 EXCEPT WHEN IT IS A KEY REPEAT, and getting that wrong made
        -- a held ⌘V show "×1". macOS repeats at roughly 30–60ms, which is
        -- INSIDE the dedupe window — so a window narrow enough to be safe
        -- for the double-event is also narrow enough to eat every repeat,
        -- and there is no gap between the two that a timer can tell apart.
        -- The event itself knows: an autorepeat carries a flag. That is
        -- the discriminator, not the clock.
        local last = kc.lastEvent
        if not isRepeat and last and last.text == text
           and (now - last.at) < kc.dedupeWindow then
            return false
        end
        kc.lastEvent = { text = text, at = now }

        local tail = kc.lines[#kc.lines]
        if tail and tail.text == text and (now - tail.at) < kc.repeatWindow then
            tail.count = tail.count + 1     -- held key: ⌘V ×3, not three rows
            tail.at = now
        else
            kc.lines[#kc.lines + 1] = { text = text, at = now, count = 1 }
            while #kc.lines > kc.maxLines do table.remove(kc.lines, 1) end
        end
        kc.shown = kc.shown + 1             -- a COUNT. Never the keystroke.
        return kc.render()
    end

    -- ---- the tap ---------------------------------------------------------
    -- 🛟 IT DISABLES ITSELF RATHER THAN DEGRADING YOUR KEYBOARD.
    -- LL's requirement: "anything we add must fail without ruining,
    -- stopping, or interfering with any other running tool that functions
    -- properly." An eventtap callback that throws on every keystroke is
    -- the worst shape a failure can take here — it does not stop, it just
    -- makes every key a little more expensive and fills the Console. So
    -- the whole body is wrapped, consecutive failures are counted, and
    -- past kc.maxFailures the tap STOPS ITSELF and says so once. A
    -- successful keystroke resets the counter, because an occasional
    -- failure (a screen disappearing mid-draw) is not the same thing.
    local function onEvent(ev)
        if not kc.on then return false end
        -- The expander's and autocorrect's synthetic typing is not yours.
        if _G.typingInjection and _G.typingInjection() then return false end

        local t = ev:getType()
        local types = hs.eventtap.event.types
        local hyper = _G.hyperActive == true or kc.f18Down == true

        if t == types.flagsChanged then
            if not kc.showBareModifiers then return false end
            local f = ev:getFlags() or {}
            local names = {}
            if hyper   then names[#names + 1] = "hyper" end
            if f.fn    then names[#names + 1] = "fn" end
            if f.ctrl  then names[#names + 1] = "ctrl" end
            if f.alt   then names[#names + 1] = "opt" end
            if f.shift then names[#names + 1] = "shift" end
            if f.cmd   then names[#names + 1] = "cmd" end
            if #names > 0 then kc.push(table.concat(names, "+")) end
            return false
        end

        if t ~= types.keyDown then return false end
        local code = ev:getKeyCode()
        local name = hs.keycodes.map[code]
        -- F18 IS the hyper key on this Mac (hidutil remaps Caps Lock to
        -- it). Track it as a fallback for _G.hyperActive and never draw
        -- it as a key in its own right — you did not press "F18".
        if name == "f18" then
            kc.f18Down = true
            -- The previous one is STOPPED before it is replaced. Holding
            -- ⇪ sends repeated F18 keyDowns, and without this the first
            -- press's timer fires three seconds later and clears the flag
            -- while you are still holding the key — so the fallback would
            -- start labelling ⇪ chords as plain keys mid-hold.
            if kc.f18Timer then pcall(function() kc.f18Timer:stop() end) end
            kc.f18Timer = hs.timer.doAfter(3, function() kc.f18Down = false end)
            return false
        end
        -- Is this macOS repeating a held key, or you pressing again?
        -- Only the event knows; see the 🚨 in push(). Guarded because
        -- getProperty is the one call here that varies between
        -- Hammerspoon builds, and a missing property must degrade to
        -- "not a repeat" rather than take the keystroke down with it.
        local isRepeat = false
        pcall(function()
            local props = hs.eventtap.event.properties
            if props and props.keyboardEventAutorepeat then
                isRepeat = ev:getProperty(props.keyboardEventAutorepeat) == 1
            end
        end)
        local text = kc.describe(name, ev:getFlags() or {}, hyper)
        if text then kc.push(text, isRepeat) end
        return false
    end

    function kc.handler(ev)
        -- 🚨 EVERY PATH RETURNS false. This module watches; it never
        -- consumes. A display tool that eats a keystroke is worse than no
        -- display tool, so even the failure path below returns false.
        local ok, err = pcall(onEvent, ev)
        if ok then
            kc.failures = 0
            return false
        end
        kc.failures = kc.failures + 1
        if kc.failures >= kc.maxFailures then
            kc.stop("it failed " .. kc.failures .. " times in a row")
            print("⌨️ Key Caster: switched itself OFF after " .. kc.failures
                  .. " consecutive failures — your keyboard and every other "
                  .. "tool are unaffected. Last error: " .. tostring(err))
            if _G.notices then
                _G.notices.record("keyCaster", "disabled itself",
                                  tostring(err))
                _G.notices.tell("⌨️ Key Caster switched itself off",
                                "It was failing on every keystroke — see the Console",
                                { key = "keycaster:off", every = 600 })
            end
        end
        return false
    end

    function kc.start()
        if kc.on then return true end
        local axOK = false
        pcall(function() axOK = hs.accessibilityState() end)
        if not axOK then
            hs.alert.show("⌨️ Key Caster needs Accessibility")
            warn("no Accessibility — the caster cannot watch the keyboard")
            return false
        end
        if not _G.keyCasterTap then
            local okNew, tap = pcall(hs.eventtap.new, {
                hs.eventtap.event.types.keyDown,
                hs.eventtap.event.types.flagsChanged,
            }, function(ev) return kc.handler(ev) end)
            if not (okNew and tap) then
                warn("could not create the event tap")
                hs.alert.show("⌨️ Key Caster could not start — see the Console")
                return false
            end
            _G.keyCasterTap = tap
        end
        kc.failures = 0
        local started = pcall(function() _G.keyCasterTap:start() end)
        if not started then
            warn("the event tap would not start")
            return false
        end
        kc.on = true
        say("on")
        hs.alert.show("⌨️ Key Caster ON")
        return true
    end

    function kc.stop(why)
        kc.on = false
        if _G.keyCasterTap then pcall(function() _G.keyCasterTap:stop() end) end
        kc.hide()
        say("off" .. (why and (" (" .. why .. ")") or ""))
        return true
    end

    function kc.toggle()
        if kc.on then
            hs.alert.show("⌨️ Key Caster OFF")
            return kc.stop("toggled")
        end
        return kc.start()
    end

    -- ---- wiring ----------------------------------------------------------
    if kc.enabled then
        core.hyperAddShortcut({ "shift" }, kc.key, function() kc.toggle() end,
                              "key caster")
    end

    core.provide("keyCaster.toggle", function() return kc.toggle() end)
    core.provide("keyCaster.start",  function() return kc.start()  end)
    core.provide("keyCaster.stop",   function() return kc.stop("service") end)

    _G.keyCastTyping = function(on)
        kc.showTyping = (on ~= false)
        print("⌨️ Key Caster: plain typing is now "
              .. (kc.showTyping and "SHOWN" or "hidden"))
        return kc.showTyping
    end

    -- ---- ⌨️ 6.116.0 — SOMETHING ELSE HAPPENED, PUT IT ON THE PANEL --------
    -- LL: "Can the keycaster be bigger and show text expansion key?"
    --
    -- 🚨 THE EXPANDER HAS TO TELL US, because the caster cannot see this
    -- for itself and MUST NOT. A snippet firing is a burst of synthetic
    -- keystrokes, and this module stands down for the shared injection
    -- guard the whole time they arrive — correctly, because they are not
    -- keys anybody pressed. So the only honest way to show an expansion
    -- is for the module that performed it to say so.
    --
    -- The hook is a bare global rather than a service call so the expander
    -- can fire it with `if _G.keyCastNote then` and needs to know nothing
    -- else about this module — including whether it is loaded, enabled, or
    -- switched on. Every one of those is checked HERE.
    function kc.note(label)
        if not (kc.on and kc.showExpansions) then return false end
        if type(label) ~= "string" or label == "" then return false end
        -- Notes bypass the dedupe window: two identical expansions in
        -- quick succession are two real events, not one press seen twice.
        return kc.push(label, true)
    end

    -- expansion(trigger, expandedText, name) — the shape the expander calls.
    -- 🔒 THE TEXT IS SUMMARISED, NOT SHOWN, unless kc.showExpansionText is
    -- on: LL's snippets hold real email addresses, a phone number and an
    -- employee ID. "Show text expansion key" is answered by the trigger.
    function kc.expansion(trigger, text, name)
        if not kc.showExpansions then return false end
        local t = tostring(trigger or "?")
        local body
        if kc.showExpansionText and type(text) == "string" then
            body = text:gsub("%s+", " ")
            if #body > 28 then body = body:sub(1, 27) .. "…" end
        elseif type(name) == "string" and name ~= "" then
            body = name
        else
            body = (type(text) == "string" and #text or 0) .. " chars"
        end
        return kc.note("⌨ " .. t .. " → " .. body)
    end

    _G.keyCastNote = function(label) return kc.note(label) end
    _G.keyCastExpansion = function(trigger, text, name)
        return kc.expansion(trigger, text, name)
    end
    core.provide("keyCaster.note",      function(l) return kc.note(l) end)
    core.provide("keyCaster.expansion",
                 function(t, x, n) return kc.expansion(t, x, n) end)
    -- 6.89.0 — listed for Window Move with plain = true: the caster is
    -- pure display (clicks mean nothing on it), so a BARE click-hold
    -- drags it, exactly as LL asked. ⌘-drag works too.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "key caster",
        plain = true,
        frame = function() return kc.canvas and kc.canvas:frame() end,
        move  = function(x, y)
            if kc.canvas then kc.canvas:topLeft({ x = x, y = y }) end
        end,
    })

    _G.keyCaster = kc
    M.kc     = kc
    M.config = kc

    -- 🔒 NOT STARTED. A module whose whole job is watching your keyboard
    -- does nothing at all until you ask it to — kc.startEnabled = true
    -- above if you want it live from boot.
    if kc.startEnabled then
        -- HELD. An unreferenced hs.timer is collected before it fires —
        -- the exact bug that lost 6.33.0's warm-up, and test_diagnostics
        -- caught this one before it shipped.
        _G.keyCasterBootTimer = hs.timer.doAfter(2, function()
            pcall(kc.start)
        end)
    end

    -- ⇪ visibility check, said ONCE and only if it matters. Without
    -- _G.hyperActive the panel would draw ⌘⇧⌃⌥X for what you pressed as
    -- ⇪X — the F18 fallback covers it, and you should know which one you
    -- are getting rather than wondering why the glyphs look wrong.
    if _G.hyperActive == nil then
        print("⌨️ Key Caster: _G.hyperActive is not published by this "
              .. "init.lua, so ⇪ is detected by watching F18 directly. "
              .. "Shortcuts will still be labelled ⇪, slightly less reliably.")
        if _G.notices then
            _G.notices.record("keyCaster", "no _G.hyperActive",
                              "falling back to watching F18")
        end
    end
end

return M
