-- =====================================================================
-- MODULE: WINDOW SWITCHER (was §1.10) — ⌥Tab, Windows-style, one tile per window
-- =====================================================================
-- Hold ⌥ and tap Tab to walk every open WINDOW — one thumbnail tile
-- each — ⌥⇧Tab to walk back, release ⌥ to switch to the highlighted
-- one, Esc to cancel. That is the Windows Alt+Tab behaviour, which
-- macOS does not have: ⌘Tab switches APPS, so a five-window app hides
-- behind a single icon. ⌘Tab itself is left alone — macOS reserves it,
-- as §0.3's knownSystemCombos table already records.
--
-- ⚠️ 6.34.0 — WHY THIS IS HAND-BUILT AND NOT hs.window.switcher.
-- 6.33.0 used hs.window.switcher, which is built on hs.window.filter.
-- That combination BEACHBALLED Hammerspoon for 44 seconds on the first
-- press. The Console recorded it precisely:
--     10:01:25  -- Loading extensions: window.filter
--     10:02:09  ✏️ Autocorrect tap was disabled by macOS — revived
-- macOS disables an event tap when the owning app stops answering, so
-- that second line is the main thread coming back after 44 seconds.
-- The cause: hs.window.filter enumerates and then SUBSCRIBES TO every
-- running application over the Accessibility API — and because
-- setDefaultFilter({}) removed the exclusions, that included hidden and
-- background apps. Every unresponsive app costs a full AX timeout, and
-- they add up on the main thread, which is the only thread Hammerspoon
-- has. Nothing about that is tunable; the module is simply the wrong
-- tool on a machine with a lot of apps open.
--
-- So this section never touches hs.window.filter. Instead:
--   • hs.window.orderedWindows() — one snapshot of visible windows,
--     already in front-to-back order, no watchers, no subscriptions.
--     Only GUI apps are asked, which is what keeps hidden/background
--     apps (the expensive ones) out of the call entirely.
--   • The enumeration IS TIMED, every single press. If it ever crosses
--     altTab.slowWarnSeconds the Console prints how long it actually
--     took, so a slow machine reports a number instead of a beachball.
--   • The window list is CAPPED (altTab.maxWindows). A capped list is a
--     bounded cost; an uncapped one is a promise you can't keep.
--   • ⌥-release is detected by POLLING hs.eventtap.checkKeyboardModifiers
--     on a timer, not by another event tap. macOS switches taps off when
--     it feels like it (see the autocorrect line above); a timer it
--     leaves alone.
--   • THE TIMER OBJECT IS STORED. hs.timer objects are garbage-collected
--     if nothing holds a reference — 6.33.0's warm-up timer was thrown
--     away on the line that created it and therefore never fired.
--
-- 🚨 IF THIS EVER MISBEHAVES: set altTab.enabled = false below and
-- reload. The hotkeys stay bound and do nothing, so ⌥Tab goes back to
-- the app underneath and nothing else in this file is affected.

-- Moved out of init.lua in 6.36.0. The code below is unchanged apart
-- from taking resolveBaseScreen from `core`, and publishing altTab so
-- ⇪⇧D can report its state and the test harness can drive it.
local M = {
    name  = "Window Switcher",
    order = 8,
    cheatsheet = {
        title = "🔄 WINDOW SWITCHER (⌥Tab — Windows-style)",
        entries = {
            { "⌥Tab", "Hold ⌥, tap Tab to walk every open window, release to switch" },
            { "⌥⇧Tab", "Walk backwards through the same list" },
            { "tiles", "One thumbnail per WINDOW, with its title underneath" },
            { "Esc", "Cancels — no switch" },
            { "minimised", "Off by default — altTab.includeMinimized = true" },
            { "⌘Tab", "Untouched — macOS reserves it, and it switches apps not windows" },
        },
    },
}

function M.setup(core)
    local altTab = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    altTab.enabled          = true   -- false = ⌥Tab does nothing (panic switch)
    altTab.includeMinimized = false  -- true also lists minimised windows. This
                                     -- costs an hs.window.allWindows() call,
                                     -- which is slower than the ordered list —
                                     -- turn it on only if you want it.
    altTab.maxWindows       = 24     -- hard cap on tiles, keeps cost bounded
    altTab.slowWarnSeconds  = 0.35   -- warn in the Console past this
    altTab.maxSessionSecs   = 30     -- watchdog: tear a stuck HUD down
    altTab.tileW, altTab.tileH = 200, 128
    altTab.gap, altTab.pad     = 14, 22
    altTab.maxCols          = 6
    altTab.pollInterval     = 0.05   -- how often we check whether ⌥ is still down

    altTab.session = nil   -- nil when idle; a table while the HUD is up
    altTab.poll    = nil   -- MUST be held: an unreferenced timer is collected
    altTab.escKey  = nil

    -- ---- window list ----------------------------------------------------
    -- One snapshot, timed, capped. No filters, no watchers, no subscriptions.
    function altTab.listWindows()
        local t0 = hs.timer.secondsSinceEpoch()

        local ok, wins = pcall(function()
            local ordered = hs.window.orderedWindows() or {}
            if not altTab.includeMinimized then return ordered end
            -- Minimised windows are not in the ordered list, so they are
            -- appended after it — visible windows stay in front-to-back
            -- order, which is the order you actually think in.
            local seen, out = {}, {}
            for _, w in ipairs(ordered) do
                local id = w:id()
                if id then seen[id] = true end
                table.insert(out, w)
            end
            for _, w in ipairs(hs.window.allWindows() or {}) do
                local id = w:id()
                if id and not seen[id] and w:isMinimized() then table.insert(out, w) end
            end
            return out
        end)

        local elapsed = hs.timer.secondsSinceEpoch() - t0
        if not ok then
            print("🔄 Window switcher: could not list windows — " .. tostring(wins))
            return {}
        end
        if elapsed > altTab.slowWarnSeconds then
            print(string.format(
                "🔄 Window switcher: listing windows took %.2fs — if that is painful, "
                .. "lower altTab.maxWindows or set altTab.includeMinimized = false (§1.10)",
                elapsed))
        end

        -- Keep only real, titled windows, and never more than the cap.
        local out = {}
        for _, w in ipairs(wins) do
            local okStd, standard = pcall(function() return w:isStandard() end)
            if okStd and standard then
                table.insert(out, w)
                if #out >= altTab.maxWindows then break end
            end
        end
        _G.diag.say("altTab", string.format("listed %d windows in %.3fs (cap %d)",
            #out, elapsed, altTab.maxWindows))
        return out
    end

    -- ---- drawing --------------------------------------------------------
    local function fit(text, maxChars)
        text = tostring(text or "")
        local len = (utf8 and utf8.len(text)) or #text
        if not len or len <= maxChars then return text end
        local out, n = {}, 0
        for _, c in utf8.codes(text) do
            n = n + 1
            if n > maxChars - 1 then break end
            table.insert(out, utf8.char(c))
        end
        return table.concat(out) .. "…"
    end

    function altTab.render()
        local s = altTab.session
        if not (s and s.canvas) then return end

        local els = {}
        table.insert(els, {
            type = "rectangle", action = "strokeAndFill",
            fillColor   = { red = 0.06, green = 0.06, blue = 0.08, alpha = 0.94 },
            strokeColor = { white = 1, alpha = 0.22 }, strokeWidth = 1,
            roundedRectRadii = { xRadius = 18, yRadius = 18 },
            frame = { x = 0.5, y = 0.5, w = s.w - 1, h = s.h - 1 },
        })

        local titleChars = math.max(8, math.floor(altTab.tileW / 7))
        for i, item in ipairs(s.items) do
            local col = (i - 1) % s.cols
            local row = math.floor((i - 1) / s.cols)
            local x = altTab.pad + col * (altTab.tileW + altTab.gap)
            local y = altTab.pad + row * (altTab.tileH + 24 + altTab.gap)
            local selected = (i == s.index)

            table.insert(els, {
                type = "rectangle", action = "strokeAndFill",
                fillColor   = selected and { red = 0.28, green = 0.52, blue = 0.92, alpha = 0.35 }
                                        or { white = 1, alpha = 0.06 },
                strokeColor = selected and { red = 0.45, green = 0.68, blue = 1.0, alpha = 0.95 }
                                        or { white = 1, alpha = 0.10 },
                strokeWidth = selected and 2 or 1,
                roundedRectRadii = { xRadius = 10, yRadius = 10 },
                frame = { x = x, y = y, w = altTab.tileW, h = altTab.tileH + 24 },
            })

            -- The tile picture. A nil image is NOT passed to the canvas —
            -- some windows (and every window of an app that refuses a
            -- capture) have no snapshot, and an image element with no image
            -- is an error. Those tiles just show their title.
            if item.image then
                table.insert(els, {
                    type = "image", image = item.image,
                    imageScaling = "scaleProportionally", imageAlignment = "center",
                    frame = { x = x + 8, y = y + 6, w = altTab.tileW - 16, h = altTab.tileH - 14 },
                })
            end

            table.insert(els, {
                type = "text", text = fit(item.label, titleChars),
                textSize = 11, textAlignment = "center",
                textColor = selected and { white = 1 } or { white = 0.75 },
                frame = { x = x + 6, y = y + altTab.tileH - 4, w = altTab.tileW - 12, h = 22 },
            })
        end

        local current = s.items[s.index]
        local caption = current and current.full or ""
        if (s.hidden or 0) > 0 then
            caption = caption .. string.format("      (showing %d of %d — the screen holds no more)",
                                               #s.items, #s.items + s.hidden)
        end
        table.insert(els, {
            type = "text",
            text = fit(caption, math.floor(s.w / 8)),
            textSize = 14, textAlignment = "center", textColor = { white = 0.92 },
            frame = { x = altTab.pad, y = s.h - 30, w = s.w - altTab.pad * 2, h = 24 },
        })

        local ok, err = pcall(function() s.canvas:replaceElements(els) end)
        if not ok then print("🔄 Window switcher: render failed — " .. tostring(err)) end
    end

    -- ---- session lifecycle ----------------------------------------------
    function altTab.finish(commit)
        local s = altTab.session
        altTab.session = nil            -- cleared FIRST: teardown must be
                                        -- idempotent, and a second release
                                        -- event must not focus twice
        if altTab.poll then
            pcall(function() altTab.poll:stop() end)
            altTab.poll = nil
        end
        if altTab.escKey then pcall(function() altTab.escKey:disable() end) end
        if not s then return end
        if s.canvas then pcall(function() s.canvas:delete() end) end

        _G.diag.say("altTab", "HUD closed (" .. (commit and "switching" or "cancelled") .. ")")
        if commit then
            local win = s.items[s.index] and s.items[s.index].win
            if win then
                pcall(function()
                    if win:isMinimized() then win:unminimize() end
                    win:focus()
                end)
            end
        end
    end

    function altTab.advance(delta)
        local s = altTab.session
        if not s then return end
        local n = #s.items
        s.index = ((s.index - 1 + delta) % n) + 1   -- wraps, like Windows
        altTab.render()
    end

    function altTab.begin(reverse)
        local wins = altTab.listWindows()
        if #wins < 2 then
            hs.alert.show(#wins == 0 and "🔄 No windows to switch to"
                                      or "🔄 Only one window open")
            return false
        end

        -- ⚠️ 6.35.0 — THE GRID IS WORKED OUT BEFORE ANY SNAPSHOT IS TAKEN.
        -- It used to snapshot every window in the list and THEN trim the
        -- list to what the screen could hold, so on a laptop it captured up
        -- to 24 images to draw 15. A window snapshot is cheap but not free
        -- (~5-20ms each), and that waste lands entirely on the keypress you
        -- are waiting on. Capacity first, trim, then capture only what will
        -- actually be drawn.
        local screen = core.resolveBaseScreen()
        local sf = screen:frame()

        -- Fitted to the SCREEN, not to a fixed column count. Six 200pt tiles
        -- plus padding is 1314pt — wider than a 1280pt laptop display, and a
        -- HUD wider than its screen centres itself with tiles cut off at
        -- BOTH edges. Columns come from the width that actually exists, rows
        -- from the height; anything that will not fit is dropped from the
        -- BACK (least recent) and the footer says how many are showing,
        -- because a silently shortened list is the same class of bug as text
        -- clipped mid-sentence.
        local cellH   = altTab.tileH + 24 + altTab.gap
        local cols    = math.floor((sf.w * 0.92 - altTab.pad * 2 + altTab.gap)
                                   / (altTab.tileW + altTab.gap))
        cols = math.max(1, math.min(altTab.maxCols, cols, #wins))
        local rowsMax = math.max(1, math.floor((sf.h * 0.9 - altTab.pad * 2 - 14) / cellH))
        local total   = #wins
        for i = total, cols * rowsMax + 1, -1 do table.remove(wins, i) end

        local snapStart = hs.timer.secondsSinceEpoch()
        local items = {}
        for _, w in ipairs(wins) do
            local app  = w:application()
            local name = app and app:name() or "?"
            local title = w:title()
            if title == nil or title == "" then title = name end
            -- Snapshots are per-window and cheap (CoreGraphics, not AX), but
            -- still pcall'd: one uncooperative window must not take the
            -- whole switcher down.
            local okSnap, img = pcall(function() return w:snapshot() end)
            if not (okSnap and img) and app then
                local okIcon, icon = pcall(function()
                    return hs.image.imageFromAppBundle(app:bundleID())
                end)
                img = okIcon and icon or nil
            end
            table.insert(items, {
                win = w, image = img, label = name, full = name .. " — " .. title,
            })
        end
        local snapElapsed = hs.timer.secondsSinceEpoch() - snapStart
        _G.diag.say("altTab", string.format("captured %d tiles in %.3fs", #items, snapElapsed))
        if snapElapsed > altTab.slowWarnSeconds then
            print(string.format(
                "🔄 Window switcher: capturing %d thumbnails took %.2fs — lower "
                .. "altTab.maxWindows (§1.10) if that lag is noticeable", #items, snapElapsed))
        end

        local n    = #items
        cols       = math.max(1, math.min(cols, n))
        local rows = math.ceil(n / cols)
        local w    = altTab.pad * 2 + cols * altTab.tileW + (cols - 1) * altTab.gap
        local h    = altTab.pad * 2 + rows * cellH + 14
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2, w = w, h = h }

        local canvas = hs.canvas.new(rect)
        if not canvas then
            hs.alert.show("🔄 Window switcher: couldn't draw — check the Console")
            return false
        end

        altTab.session = {
            items = items, cols = cols, w = w, h = h, hidden = total - n,
            -- Windows selects the NEXT window on the first press, not the
            -- one you are already in; ⌥⇧Tab selects the last one.
            index = reverse and n or 2,
            startedAt = hs.timer.secondsSinceEpoch(),
            canvas = canvas,
        }
        altTab.render()
        _G.diag.say("altTab", string.format("HUD open: %d tiles, %d cols, %dx%d, start index %d",
            n, cols, w, h, altTab.session.index))
        pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
        pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        canvas:show()

        if not altTab.escKey then
            local ok, hk = pcall(hs.hotkey.new, {}, "escape", function() altTab.finish(false) end)
            if ok then altTab.escKey = hk end
        end
        if altTab.escKey then pcall(function() altTab.escKey:enable() end) end

        -- Poll for the ⌥ release. Held in altTab.poll on purpose — an
        -- unreferenced hs.timer gets collected and silently never fires,
        -- which is exactly how 6.33.0's warm-up went missing.
        altTab.poll = hs.timer.doEvery(altTab.pollInterval, function()
            local s = altTab.session
            if not s then return end
            local okMods, mods = pcall(hs.eventtap.checkKeyboardModifiers)
            if not okMods then altTab.finish(true) return end
            if not mods.alt then altTab.finish(true) return end
            -- Watchdog: a HUD that outlives its keypress (a missed release,
            -- a Space change mid-hold) tears itself down instead of sitting
            -- there over your screen forever.
            if hs.timer.secondsSinceEpoch() - s.startedAt > altTab.maxSessionSecs then
                print("🔄 Window switcher: session watchdog fired — closing")
                altTab.finish(false)
            end
        end)
        return true
    end

    function altTab.step(reverse)
        if not altTab.enabled then return end
        local ok, err = pcall(function()
            if altTab.session then
                altTab.advance(reverse and -1 or 1)
            else
                altTab.begin(reverse)
            end
        end)
        if not ok then
            print("🔄 Window switcher: " .. tostring(err))
            altTab.finish(false)   -- never leave a half-built HUD on screen
        end
    end

    -- Through the §0.3 sentry like every other binding, so a clash with
    -- anything added later is announced at boot.
    hs.hotkey.bind({ "alt" },          "tab", function() altTab.step(false) end)
    hs.hotkey.bind({ "alt", "shift" }, "tab", function() altTab.step(true)  end)

    -- Published for ⇪⇧D and for the test harness. _G rather than a
    -- return value because §1.11's report has to survive this module
    -- failing to load at all, and a nil check on a global is the
    -- simplest honest way to say "not loaded".
    _G.altTab = altTab
    M.altTab  = altTab
end

return M
