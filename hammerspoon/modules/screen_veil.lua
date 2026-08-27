-- =====================================================================
-- MODULE: SCREEN VEIL (⇪G) — a chrome-less dimming filter over every display
-- =====================================================================
-- ⇪G toggles a borderless, click-through sheet over EVERY connected
-- monitor. ⇪⇧G cycles its strength: Movie 20% → Reading 40% → Dim 60% →
-- Deep 75% → Max 90%. ⇪⇧= and ⇪⇧- nudge it 5% at a time. ⌃⌥⌘⇧G is the
-- panic key and tears every sheet down no matter what state this is in.
--
-- ⚠️ READ THIS FIRST — WHAT THIS IS AND IS NOT.
-- You asked for a GRAYSCALE filter. This is a NEUTRAL VEIL, which is a
-- different thing, and the difference is not a shortcut I took — it is
-- the API:
--
--   • hs.canvas COMPOSITES. It draws a translucent sheet ON TOP of the
--     screen. It can darken and it can mute, because a neutral grey
--     laid over a colour pulls that colour toward grey. What it cannot
--     do is DESATURATE: turning a red pixel into the grey of the same
--     brightness means reading that pixel and mixing its channels, and
--     a compositing layer never sees the pixels underneath it.
--   • hs.screen:setGamma() cannot do it either, and for a more final
--     reason: a gamma table is one transfer curve PER CHANNEL. Channels
--     never meet, so no gamma table of any shape can average them.
--     Real desaturation is a colour-matrix operation and macOS exposes
--     it in exactly one place — see below.
--
-- So: for "dim it until I can read / watch a film through it", which is
-- what the 90%-to-a-comfortable-number range you described actually
-- describes, this module is the right tool and does the whole job.
-- For LITERAL black-and-white, the switch lives in macOS:
--     System Settings → Accessibility → Display → Color Filters
--     → on, Filter type: Grayscale
-- That switch runs inside WindowServer, below every app, which is why it
-- can do what a canvas cannot. The two stack fine — veil for brightness,
-- Color Filters for colour. ⇪9 presses the shortcut macOS already binds
-- to that switch; see the next block.
--
-- ---------------------------------------------------------------------
-- 🌑 6.140.0 — GRAYSCALE, AND WHY THE FOURTH ATTEMPT IS DIFFERENT
-- ---------------------------------------------------------------------
-- 6.82.0 removed a grayscale toggle. The note reads: "defaults write +
-- launchctl, killall, and osascript all failed or errored in practice."
-- That verdict was correct and it is still correct. But every one of
-- those four tried to do the SAME THING — SET THE SETTING — and macOS
-- does not let a process do that. The switch belongs to universalaccessd,
-- the preference domain is cached, and a UI walk through System Settings
-- breaks on the next OS release.
--
-- 🔑 THE ROUTE THAT WAS NEVER TRIED: do not set the value. PRESS THE KEY
-- macOS IS ALREADY LISTENING FOR. macOS ships an Accessibility Shortcut
-- bound to ⌥⌘F5. Its feature list is yours to choose, and when Color
-- Filters is the ONLY feature ticked, that shortcut stops opening a panel
-- and becomes a direct grayscale toggle handled inside the OS.
--
-- Sending ⌥⌘F5 needs no new permission — Hammerspoon already posts
-- keystrokes — and nothing here can break when System Settings is
-- rearranged, because nothing here reads System Settings.
--
-- ⚠️ WHAT THIS STILL CANNOT DO, AND WILL NOT PRETEND TO. The one-time
-- tick is YOURS, made by hand: System Settings → Accessibility →
-- Shortcut → tick Color Filters and NOTHING ELSE. It is precisely the
-- step 6.82.0 proved a program cannot take. (6.140.0–6.144.1 shipped a
-- setup door that opened the pane for you; 6.145.0 retired it at LL's
-- word — the tick was already made, and triple-pressing Touch ID, the
-- native macOS shortcut, covers the toggle without Hammerspoon at all.)
-- If you leave more than one feature ticked, ⌥⌘F5 opens the chooser
-- panel instead of toggling — that is macOS behaving as designed, not a
-- fault here, and _G.monoReport() says so rather than guessing.
--
-- 🚨 SAFETY. A full-screen sheet you cannot dismiss would be a bad day,
-- so: the strength is HARD-CAPPED at 90% (M.config.maxLevel) and never
-- reaches opaque; the panic key ⌃⌥⌘⇧G is bound separately from the
-- toggle and calls the teardown directly; and the veil is NEVER restored
-- on in the on-state at boot — a reload always comes up clear. The
-- strength is remembered, the on-switch is not.

local M = {
    name  = "Screen Veil",
    order = 13.4,
    family = "windows",
    cheatsheet = {
        title = "🌗 SCREEN VEIL (⇪G — dim every display)",
        entries = {
            { "⇪G",     "Toggle the veil on/off over ALL connected monitors" },
            { "⇪⇧G",    "Cycle strength: Movie 20% · Reading 40% · Dim 60% · Deep 75% · Max 90%" },
            { "⇪⇧=",    "5% stronger" },
            { "⇪⇧-",    "5% weaker" },
            { "⌃⌥⌘⇧G", "PANIC — remove the veil no matter what" },
            { "⇪9",     "Grayscale on/off — relays ⌥⌘F5, the macOS switch" },
            { "3× Touch ID", "Grayscale natively — triple-press Touch ID, macOS's own shortcut" },
            { "⇪⇧9",    "Invert the screen colours — relays ⌃⌥⌘8, no setup" },
            { "note",   "A veil dims and mutes; it cannot desaturate. True B&W" },
            { "",       "is Color Filters — set up once, by hand: tick it ALONE" },
            { "",       "under Accessibility → Shortcut. ⇪; lists the rows" },
            { "",       "Click-through: the veil never eats a click or takes focus" },
        },
    },
}

function M.setup(core)
    local veil = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    veil.enabled   = true    -- false = the keys bind and do nothing
    veil.maxLevel  = 0.90    -- hard ceiling. Do NOT raise this to 1.0.
    veil.minLevel  = 0.05
    veil.step      = 0.05    -- ⇪⇧= / ⇪⇧- increment
    -- 0.0 = pure black (dims only) · 0.5 = light grey (mutes colour hard
    -- but washes the picture out) · 0.22 is the middle: dark enough that
    -- 90% really is "nearly black", grey enough that at 20% colours go
    -- quiet instead of just dark.
    veil.tintWhite = 0.22
    -- "overlay" sits above ordinary windows and, with fullScreenAuxiliary
    -- below, above full-screen video too. "screenSaver" is higher still —
    -- use it only if you find something that pokes through, because it
    -- also covers Hammerspoon's own alerts.
    veil.windowLevel = "overlay"
    veil.presets = {
        { name = "Movie",   level = 0.20 },
        { name = "Reading", level = 0.40 },
        { name = "Dim",     level = 0.60 },
        { name = "Deep",    level = 0.75 },
        { name = "Max",     level = 0.90 },
    }
    veil.readoutSeconds = 1.4   -- how long the "Reading · 40%" badge stays
    veil.toggleKey  = "g"
    -- ----------------------------------------------------------------------

    veil.canvases    = {}     -- screen id -> hs.canvas. HELD: an unreferenced
                              -- canvas is collected and the veil vanishes.
    veil.on          = false
    veil.level       = 0.40
    veil.presetIndex = 2
    veil.screenWatch = nil    -- HELD for the same reason
    veil.readoutTimer = nil   -- and again: 6.33.0's warm-up timer was thrown
                              -- away on the line that made it, and so never
                              -- fired. Every timer in this file is stored.
    veil.readoutText = nil

    local function clamp(x)
        if x ~= x then return veil.minLevel end          -- NaN guard
        if x < veil.minLevel then return veil.minLevel end
        if x > veil.maxLevel then return veil.maxLevel end
        return x
    end

    -- ---- drawing ---------------------------------------------------------
    -- Elements are rebuilt from scratch every time rather than mutated in
    -- place. It is a two-element canvas; the cost is nothing, and it means
    -- there is exactly one code path that decides what is on screen.
    local function elementsFor(screenFrame)
        local els = {
            {
                type = "rectangle", action = "fill",
                fillColor = { white = veil.tintWhite, alpha = veil.level },
                frame = { x = 0, y = 0, w = screenFrame.w, h = screenFrame.h },
            },
        }
        if veil.readoutText then
            local w, h = 260, 54
            local x = (screenFrame.w - w) / 2
            local y = screenFrame.h - h - 90
            table.insert(els, {
                type = "rectangle", action = "strokeAndFill",
                fillColor   = { white = 0.05, alpha = 0.88 },
                strokeColor = { white = 1, alpha = 0.25 }, strokeWidth = 1,
                roundedRectRadii = { xRadius = 12, yRadius = 12 },
                frame = { x = x, y = y, w = w, h = h },
            })
            table.insert(els, {
                type = "text", text = veil.readoutText,
                textSize = 18, textAlignment = "center",
                textColor = { white = 0.96 },
                frame = { x = x, y = y + 14, w = w, h = 28 },
            })
        end
        return els
    end

    -- Tear every sheet down. Must be safe to call at any time, from any
    -- state, twice in a row — it is the panic path.
    function veil.hide()
        for id, c in pairs(veil.canvases) do
            pcall(function() c:delete() end)
            veil.canvases[id] = nil
        end
        veil.canvases = {}
        veil.on = false
        veil.readoutText = nil
        if veil.readoutTimer then
            pcall(function() veil.readoutTimer:stop() end)
            veil.readoutTimer = nil
        end
        _G.diag.say("veil", "hidden")
    end

    -- Build (or rebuild) one sheet per connected screen. Called on show, on
    -- every strength change, and whenever the display arrangement changes.
    function veil.draw()
        if not veil.on then return end
        local screens = hs.screen.allScreens() or {}
        local live = {}

        for _, scr in ipairs(screens) do
            local okId, id = pcall(function() return scr:id() end)
            if okId and id then
                live[id] = true
                -- fullFrame, not frame: frame stops below the menu bar and
                -- above the Dock, and a veil with two bright stripes across
                -- it is not a veil.
                local okF, f = pcall(function() return scr:fullFrame() end)
                if okF and f then
                    local c = veil.canvases[id]
                    if not c then
                        local okNew, made = pcall(hs.canvas.new, f)
                        if okNew and made then
                            c = made
                            veil.canvases[id] = c
                            local lvl = (hs.canvas.windowLevels or {})[veil.windowLevel]
                                        or (hs.canvas.windowLevels or {}).overlay
                            pcall(function() c:level(lvl) end)
                            -- canJoinAllSpaces: follow the user between
                            -- desktops. fullScreenAuxiliary: also appear over
                            -- a full-screen app, which is the whole point when
                            -- the thing being watched is a full-screen film.
                            -- stationary: don't slide during a Space swipe.
                            pcall(function()
                                c:behaviorAsLabels({ "canJoinAllSpaces",
                                                     "fullScreenAuxiliary",
                                                     "stationary" })
                            end)
                            -- CLICK-THROUGH. Both halves are needed: no mouse
                            -- tracking at all, and no activation on click. A
                            -- sheet that swallowed clicks would make the
                            -- machine look frozen.
                            pcall(function() c:canvasMouseEvents(false, false, false, false) end)
                            pcall(function() c:clickActivating(false) end)
                        end
                    else
                        pcall(function() c:frame(f) end)
                    end
                    if c then
                        pcall(function() c:replaceElements(elementsFor(f)) end)
                        -- See _G.showCanvasSafely in init.lua: a bare pcall stops the throw
                        -- from escaping but gives up on the FIRST failure. The helper retries a
                        -- run loop turn later, which is what actually recovers a collision with
                        -- another app's remote view.
                        if _G.showCanvasSafely then
                            _G.showCanvasSafely(c, "screen veil")
                        else pcall(function() c:show() end) end
                    end
                end
            end
        end

        -- A monitor that has been unplugged leaves a canvas behind that
        -- belongs to a screen that no longer exists. Reap it here rather
        -- than leaking one per hot-plug.
        for id, c in pairs(veil.canvases) do
            if not live[id] then
                pcall(function() c:delete() end)
                veil.canvases[id] = nil
            end
        end
    end

    -- The badge that names the strength. Drawn INSIDE the veil canvas on
    -- purpose: hs.alert draws at its own window level and would end up
    -- underneath the very sheet it is describing.
    function veil.flashReadout(text)
        veil.readoutText = text
        if veil.readoutTimer then pcall(function() veil.readoutTimer:stop() end) end
        veil.draw()
        veil.readoutTimer = hs.timer.doAfter(veil.readoutSeconds, function()
            veil.readoutText = nil
            veil.draw()
        end)
    end

    local function describe()
        local name
        for _, p in ipairs(veil.presets) do
            if math.abs(p.level - veil.level) < 0.001 then name = p.name end
        end
        return (name and (name .. " · ") or "") ..
               string.format("%d%%", math.floor(veil.level * 100 + 0.5))
    end

    function veil.show()
        if not veil.enabled then
            hs.alert.show("🌗 Screen veil is switched off in its module file")
            return
        end
        veil.on = true
        veil.draw()
        veil.flashReadout("🌗 " .. describe())
        _G.diag.say("veil", "shown at " .. describe())
    end

    function veil.toggle()
        if veil.on then veil.hide() else veil.show() end
    end

    function veil.setLevel(x, label)
        veil.level = clamp(x)
        hs.settings.set("screenVeil.level", veil.level)
        if veil.on then
            veil.flashReadout("🌗 " .. (label or describe()))
        else
            -- Changing the strength while it is off turns it on, because
            -- otherwise the key appears to do nothing at all.
            veil.show()
        end
    end

    function veil.nudge(delta)
        veil.setLevel(veil.level + delta)
    end

    function veil.cyclePreset()
        veil.presetIndex = (veil.presetIndex % #veil.presets) + 1
        local p = veil.presets[veil.presetIndex]
        veil.setLevel(p.level, p.name .. " · " ..
                      string.format("%d%%", math.floor(p.level * 100 + 0.5)))
    end

    -- ---- GRAYSCALE: THE RELAY --------------------------------------------
    -- See the 6.140.0 block at the top of the file for why this presses a
    -- key instead of writing a preference. Nothing below creates a tap or
    -- a repeating timer; the one timer is a single shot on your keypress.

    -- ✏️ EDIT HERE — only if you have rebound the macOS side.
    veil.monoMods   = { "alt", "cmd" }           -- Accessibility Shortcut
    veil.monoKey    = "f5"
    veil.invertMods = { "ctrl", "alt", "cmd" }   -- stock "Invert colors"
    veil.invertKey  = "8"
    -- 6.141.0 — LL asked for a key after all ("why am I not using some
    -- hyperkey combo for my new grayscale?") and picked ⇪9 — with ⇪⇧9
    -- for invert. The conflict sentry refused the second half: ⇪⇧9 was
    -- the numpad laptop row's TOP-RIGHT window key, held since 6.114.0.
    -- 6.142.0 — LL's answer was to clear that whole layer ("These
    -- shortcuts were supposed to be cleaned, cleared and the keys
    -- listed as future possible options"), so the refusal's reason is
    -- gone and ⇪⇧9 goes where LL pointed in the first place: Invert
    -- colours. The sentry was right both times — it guards owners, and
    -- the owner changed by LL's word, not by a quiet steal.
    veil.monoHyperKey   = "9"
    veil.invertHyperKey = "9"     -- with shift: ⇪⇧9, LL's 6.141.0 pick
    veil.readBackAfter = 0.6   -- seconds to wait before re-reading the pref
    veil.monoTimer  = nil      -- HELD — the rule at the top applies here too
    veil.DEFAULTS   = "/usr/bin/defaults"  -- reviewed in test_diagnostics 9b

    -- Reads the PREFERENCE FILE. That is not the same as reading the screen,
    -- and the difference matters: macOS caches this domain, so a value read
    -- an instant after a change can still be the old one. Every line that
    -- uses this labels it as a preference, never as a fact about what you
    -- are looking at.
    -- ⚠️ SYNCHRONOUS ON PURPOSE, and allowed to be: one `defaults read` of
    -- one small domain answers in milliseconds, and it runs only on an
    -- action you just took — never inside a tap, never on a repeating
    -- timer. Same reasoning as ⇪7's instant reads in mac_panel.lua. The
    -- whole domain is read in ONE child process and the three keys picked
    -- out of the dump, rather than three shells for three keys.
    function veil.monoState()
        local out
        pcall(function()
            out = hs.execute(veil.DEFAULTS
                  .. " read com.apple.universalaccess 2>/dev/null")
        end)
        if type(out) ~= "string" then out = "" end
        local function num(key)
            -- %f[%w] so "grayscale" cannot match inside a longer key name
            local v = out:match("%f[%w]" .. key .. "%s*=%s*(%-?%d+)")
            return v and tonumber(v) or nil
        end
        return {
            filterOn   = num("colorFilterEnabled"),
            filterType = num("colorFilterType"),
            legacyGray = num("grayscale"),
        }
    end

    function veil.monoReport()
        local st  = veil.monoState()
        local out = {}
        local function line(s) out[#out + 1] = s end
        line("🌑 GRAYSCALE — what the preference file says")
        line("")
        if st.filterOn == nil then
            line("   com.apple.universalaccess would not answer for")
            line("   colorFilterEnabled. That is usually not a fault — it")
            line("   means the key has never been written, so Color Filters")
            line("   has not been switched on even once. Flip it on by hand:")
            line("   Settings → Accessibility → Display → Color Filters.")
        else
            line(("   Color Filters ......... %s")
                 :format(st.filterOn == 1 and "ON" or "off"))
            if st.filterType then
                line(("   Filter type ........... %d%s"):format(
                     st.filterType,
                     st.filterType == 0 and "  (Grayscale)"
                     or "  ⚠️ a filter IS on, but it is not grayscale"))
            end
        end
        if st.legacyGray == 1 then
            line("   Legacy grayscale key .. ON")
        end
        line("")
        line("   ⚠️ THIS IS THE PREFERENCE FILE, NOT THE SCREEN. macOS caches")
        line("   the domain, so a value read a moment after a change can")
        line("   still be the old one. Trust your eyes over this block.")
        line("")
        line("   ⌥⌘F5 toggles grayscale — but ONLY if Color Filters is the")
        line("   one feature ticked under Accessibility → Shortcut. With")
        line("   more than one ticked, macOS opens a chooser panel instead")
        line("   and nothing toggles. Triple-pressing Touch ID — the native")
        line("   macOS shortcut — fires the same toggle, no Hammerspoon.")
        local s = table.concat(out, "\n")
        pcall(function() hs.pasteboard.setContents(s) end)
        return s
    end

    -- 🪦 6.145.0 — the setup door is RETIRED at LL's word ("remove it and
    -- rollback changes"). It opened the Settings pane for the one-time
    -- tick; LL had already made the tick by hand, and the native
    -- triple-press of Touch ID covers the toggle from there. The tick
    -- itself was never this module's to make — that finding (6.82.0)
    -- stands, and every text below points at the pane by name instead.

    function veil.mono()
        -- The trailing 0 is the inter-event delay. Left to default it is
        -- 200ms of BLOCKED MAIN THREAD per press; hyper_key.lua passes 0
        -- for the same reason.
        local ok = pcall(function()
            hs.eventtap.keyStroke(veil.monoMods, veil.monoKey, 0)
        end)
        if not ok then
            pcall(function() hs.alert.show("🌑 Could not send ⌥⌘F5", 3) end)
            return false
        end
        _G.diag.say("veil", "sent ⌥⌘F5 (macOS Accessibility Shortcut)")
        -- Read back AFTER a beat. Asking immediately returns the value from
        -- before the keystroke often enough that an instant read would make
        -- a working toggle look broken.
        if veil.monoTimer then pcall(function() veil.monoTimer:stop() end) end
        veil.monoTimer = hs.timer.doAfter(veil.readBackAfter, function()
            veil.monoTimer = nil
            local st, said = veil.monoState(), nil
            if st.filterOn == 1 then
                said = (st.filterType == nil or st.filterType == 0)
                       and "🌑 Grayscale ON"
                       or  "🌑 A colour filter is on — but not grayscale"
            elseif st.filterOn == 0 then
                said = "🌑 Colour is back"
            else
                said = "🌑 Sent ⌥⌘F5 — if nothing changed, tick Color Filters"
                       .. " (alone) under Settings → Accessibility → Shortcut"
            end
            pcall(function() hs.alert.show(said, 2) end)
        end)
        return true
    end

    -- Inversion is NOT desaturation and is not offered as a substitute for
    -- it. It is here because it is the one colour change that needs no
    -- setup whatsoever: ⌃⌥⌘8 ships already bound.
    function veil.invert()
        local ok = pcall(function()
            hs.eventtap.keyStroke(veil.invertMods, veil.invertKey, 0)
        end)
        if ok then
            pcall(function() hs.alert.show("🔄 Invert colours (⌃⌥⌘8)", 2) end)
        else
            pcall(function() hs.alert.show("🔄 Could not send ⌃⌥⌘8", 3) end)
        end
        return ok
    end

    _G.mono          = function() return veil.mono() end
    _G.monoReport    = function() return veil.monoReport() end
    _G.invertColours = function() return veil.invert() end

    -- The ⇪; rows in power_tools reach these by SERVICE NAME (pt.veilCall)
    -- so that module never holds a reference into this one. Guarded the
    -- way daily_backup guards its own: a stub core without provide is a
    -- test harness, not an error.
    if core.provide then
        core.provide("veil.mono",      function() return veil.mono() end)
        core.provide("veil.invert",    function() return veil.invert() end)
        core.provide("veil.monoReport", function() return veil.monoReport() end)
    end

    -- ---- keys ------------------------------------------------------------
    core.hyperAddShortcut({}, veil.toggleKey, function() veil.toggle() end, "screen veil")
    core.hyperAddShortcut({}, veil.monoHyperKey, function() veil.mono() end,
                          "grayscale relay")
    core.hyperAddShortcut({ "shift" }, veil.invertHyperKey,
                          function() veil.invert() end, "invert colours")
    core.hyperAddShortcut({ "shift" }, veil.toggleKey, function() veil.cyclePreset() end,
                          "screen veil strength")
    core.hyperAddShortcut({ "shift" }, "=", function() veil.nudge(veil.step) end,
                          "screen veil +5%")
    core.hyperAddShortcut({ "shift" }, "-", function() veil.nudge(-veil.step) end,
                          "screen veil -5%")

    -- The panic key is a PLAIN global chord, not a hyper shortcut. Hyper is
    -- a modal built on an event tap and a hidutil remap; if the thing that
    -- has gone wrong is hyper itself, a hyper-based escape hatch is no
    -- escape hatch. This one goes through hs.hotkey directly.
    hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "G", function()
        veil.hide()
        hs.alert.show("🌗 Screen veil removed")
    end)

    -- ---- display changes -------------------------------------------------
    -- Plug in a monitor, unplug one, change resolution, open the lid: the
    -- veil has to follow. Held in veil.screenWatch — see the timer note at
    -- the top of the file, the rule is the same for watchers.
    local okW, w = pcall(function()
        return hs.screen.watcher.new(function()
            if veil.on then
                _G.diag.say("veil", "display arrangement changed — redrawing")
                veil.draw()
            end
        end)
    end)
    if okW and w then
        veil.screenWatch = w
        pcall(function() veil.screenWatch:start() end)
    end

    _G.screenVeil = veil
    M.veil   = veil
    M.config = veil
end

-- Restore the STRENGTH you last used, never the on-state. A config reload
-- that came back with the screen already dark would look like a fault.
function M.warm(core)
    local veil = M.veil
    if not veil then return end
    local saved = hs.settings.get("screenVeil.level")
    if type(saved) == "number" and saved > 0 then
        veil.level = math.max(veil.minLevel, math.min(veil.maxLevel, saved))
        for i, p in ipairs(veil.presets) do
            if math.abs(p.level - veil.level) < 0.001 then veil.presetIndex = i end
        end
        _G.diag.say("veil", string.format("restored strength %d%% (off, as always at boot)",
                                          math.floor(veil.level * 100 + 0.5)))
    end
end

return M
