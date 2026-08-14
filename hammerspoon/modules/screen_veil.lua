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
-- For LITERAL black-and-white, macOS has it built in and Hammerspoon is
-- not involved:
--     System Settings → Accessibility → Display → Color Filters
--     → on, Filter type: Grayscale
-- and the Shortcut panel (⌥⌘F5) can put it on a key. That switch runs
-- inside WindowServer, below every app, which is why it can do what a
-- canvas cannot. The two stack fine — veil for brightness, Color
-- Filters for colour.
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
    cheatsheet = {
        title = "🌗 SCREEN VEIL (⇪G — dim every display)",
        entries = {
            { "⇪G",     "Toggle the veil on/off over ALL connected monitors" },
            { "⇪⇧G",    "Cycle strength: Movie 20% · Reading 40% · Dim 60% · Deep 75% · Max 90%" },
            { "⇪⇧=",    "5% stronger" },
            { "⇪⇧-",    "5% weaker" },
            { "⌃⌥⌘⇧G", "PANIC — remove the veil no matter what" },
            { "note",   "A veil dims and mutes; it cannot desaturate. True B&W:" },
            { "",       "Accessibility → Display → Color Filters → Grayscale" },
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

    -- ---- keys ------------------------------------------------------------
    core.hyperAddShortcut({}, veil.toggleKey, function() veil.toggle() end, "screen veil")
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
