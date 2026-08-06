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
            { "shows", "EVERY window: all desktops/Spaces, all monitors, minimised too" },
            { "also", "Running apps with no open window — selecting one activates it" },
            { "tuning", "altTab.includeOtherSpaces / includeApps / maxWindows (module file)" },
            { "⌘Tab", "Untouched — macOS reserves it, and it switches apps not windows" },
        },
    },
}

function M.setup(core)
    local altTab = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    altTab.enabled          = true   -- false = ⌥Tab does nothing (panic switch)
    altTab.includeMinimized  = true  -- minimised windows are listed too
    altTab.includeOtherSpaces = true -- windows on OTHER desktops/Spaces and
                                     -- other monitors (see the note below —
                                     -- this is the setting that fixes
                                     -- "⌥Tab only shows this desktop")
    altTab.includeApps       = true  -- also list running apps that have NO
                                     -- open window, so "every open program"
                                     -- really means every one
    altTab.maxWindows        = 36    -- hard cap on tiles, keeps cost bounded

    -- ⏱ 6.41.0 — A HARD DEADLINE ON THE WINDOW SWEEP. On a real Mac this
    -- took 15.9 SECONDS across 15 apps: the Accessibility API can block
    -- for a second or more per application (an app that is swapped out
    -- after an idle period is the usual reason), and 15 of those in a row
    -- is a freeze, not a switcher. The sweep now stops when the budget is
    -- spent and shows what it managed to collect. A partial list you can
    -- see beats a complete one that arrives 16 seconds late.
    altTab.listBudget  = 0.8   -- seconds; the sweep stops when spent
    altTab.cacheFor    = 4.0   -- reuse the last list for this long
    -- ✏️ Apps that are always slow to answer go here, by exact name, and
    -- are never asked. ⇪⇧D names the worst offender after every press.
    altTab.skipApps    = {}
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
    -- ⚠️ 6.39.0 — WHY THIS ASKS EVERY APPLICATION INSTEAD OF ASKING FOR
    -- "ALL WINDOWS". hs.window.orderedWindows() and hs.window.allWindows()
    -- report ONLY the current Mission Control Space. That is a documented
    -- macOS limit, not a Hammerspoon bug, and it is exactly why ⌥Tab
    -- showed nothing from your other desktops. Hammerspoon's own
    -- documented answer is hs.window.filter — the module that froze this
    -- Mac for 44 seconds in 6.33.0, so that door stays shut.
    --
    -- The third route: ask each APPLICATION for its own windows. The
    -- Accessibility API hands over an app's windows wherever they are —
    -- other Spaces, other monitors, minimised — because AX has no concept
    -- of a Space at all. That is the whole fix.
    --
    -- ONLY GUI APPS ARE ASKED (app:kind() == 1). Background daemons and
    -- menu-bar agents are precisely the population whose AX timeouts made
    -- window.filter unusable; they own no windows worth switching to, so
    -- skipping them costs nothing and avoids all of that.
    --
    -- Order: the CURRENT Space first, front-to-back, because that is the
    -- order you are already thinking in — then everything else, appended.
    -- Every phase is timed and the whole thing stays capped.
    function altTab.listWindows()
        local t0 = hs.timer.secondsSinceEpoch()
        local entries, seenWin, seenApp = {}, {}, {}

        local function add(w)
            local okId, id = pcall(function() return w:id() end)
            if not (okId and id) or seenWin[id] then return end
            local okStd, standard = pcall(function() return w:isStandard() end)
            if not (okStd and standard) then return end
            if not altTab.includeMinimized then
                local okMin, min = pcall(function() return w:isMinimized() end)
                if okMin and min then return end
            end
            seenWin[id] = true
            table.insert(entries, { win = w })
        end

        -- 1. This Space, in front-to-back order.
        local okSpace, spaceErr = pcall(function()
            for _, w in ipairs(hs.window.orderedWindows() or {}) do add(w) end
        end)
        if not okSpace then
            print("🔄 Window switcher: could not list windows on this Space — "
                  .. tostring(spaceErr))
            _G.diag.warn("altTab", "current-Space listing failed: " .. tostring(spaceErr))
        end
        local tOrdered = hs.timer.secondsSinceEpoch() - t0

        -- 2. Every other window, app by app — the cross-Space part.
        local appsSeen, withWindows = {}, {}
        local truncated, slowestApp, slowestTime = false, nil, 0
        if altTab.includeOtherSpaces or altTab.includeApps then
            local okApps, appErr = pcall(function()
                local skip = {}
                for _, n in ipairs(altTab.skipApps or {}) do skip[n] = true end

                for _, app in ipairs(hs.application.runningApplications() or {}) do
                    -- THE DEADLINE. Checked beforeeach app rather than after,
                    -- so the budget is a ceiling on what we ask for, not a
                    -- report on what we already spent.
                    if hs.timer.secondsSinceEpoch() - t0 > altTab.listBudget then
                        truncated = true
                        break
                    end
                    local okKind, kind = pcall(function() return app:kind() end)
                    local okName, aname = pcall(function() return app:name() end)
                    aname = okName and aname or "?"
                    if okKind and kind == 1 and not skip[aname] then
                        table.insert(appsSeen, app)
                        if altTab.includeOtherSpaces then
                            -- Timed PER APP: when one application is the
                            -- reason a press felt slow, the report has to
                            -- be able to name it. A single culprit goes in
                            -- altTab.skipApps and the problem is over.
                            local a0 = hs.timer.secondsSinceEpoch()
                            local okW, appWins = pcall(function() return app:allWindows() end)
                            if okW then
                                for _, w in ipairs(appWins or {}) do add(w) end
                            end
                            local took = hs.timer.secondsSinceEpoch() - a0
                            if took > slowestTime then slowestTime, slowestApp = took, aname end
                        end
                    end
                end
            end)
            if not okApps then
                print("🔄 Window switcher: could not list windows per application — "
                      .. tostring(appErr))
                _G.diag.warn("altTab", "per-application listing failed: " .. tostring(appErr))
            end
        end

        -- Which apps already own a listed window? Worked out from the
        -- ENTRIES, not from how many each app contributed: an app whose
        -- windows were all picked up by the current-Space pass adds
        -- nothing new in the per-app pass, and counting that as "has no
        -- windows" gave every app on this desktop a second, bogus
        -- "no open window" tile.
        for _, e in ipairs(entries) do
            if e.win then
                local okA, a = pcall(function() return e.win:application() end)
                if okA and a then
                    local okN, n = pcall(function() return a:name() end)
                    if okN and n then withWindows[n] = true end
                end
            end
        end

        -- 3. Apps that are running with NO window at all. Without these,
        --    "every open program" quietly means "every open window", and
        --    an app you minimised to nothing would be unreachable.
        if altTab.includeApps then
            for _, app in ipairs(appsSeen) do
                local okName, name = pcall(function() return app:name() end)
                if okName and name and not withWindows[name] and not seenApp[name] then
                    seenApp[name] = true
                    table.insert(entries, { app = app, appOnly = true })
                end
            end
        end

        local elapsed = hs.timer.secondsSinceEpoch() - t0
        _G.diag.say("altTab", string.format(
            "listed %d entries in %.3fs (this Space %.3fs, %d apps%s%s)",
            #entries, elapsed, tOrdered, #appsSeen,
            truncated and ", BUDGET SPENT" or "",
            slowestApp and string.format(", slowest: %s %.2fs", slowestApp, slowestTime) or ""))
        if truncated then
            print(string.format(
                "🔄 Window switcher: stopped after %.1fs / %d apps — showing what it had. "
                .. "Slowest app: %s (%.2fs). Add it to altTab.skipApps in "
                .. "modules/window_switcher.lua, or raise altTab.listBudget.",
                elapsed, #appsSeen, tostring(slowestApp), slowestTime))
        elseif elapsed > altTab.slowWarnSeconds then
            print(string.format(
                "🔄 Window switcher: listing took %.2fs across %d apps (slowest: %s %.2fs)",
                elapsed, #appsSeen, tostring(slowestApp), slowestTime))
        end
        _G.altTabLastListing = {
            seconds = elapsed, apps = #appsSeen, entries = #entries,
            truncated = truncated, slowestApp = slowestApp, slowestTime = slowestTime,
        }

        while #entries > altTab.maxWindows do table.remove(entries) end
        altTab.cache = { at = hs.timer.secondsSinceEpoch(), entries = entries }
        return entries
    end

    -- Repeated presses inside a few seconds reuse the last list instead of
    -- paying the Accessibility cost again. Deliberately SHORT: a stale
    -- switcher that misses a window you just opened would be worse than a
    -- slow one. There is no background refresh on purpose — a timer doing
    -- this sweep every N seconds would move the freeze somewhere you
    -- cannot see it coming, which is strictly worse than a slow keypress.
    function altTab.listWindowsCached()
        local c = altTab.cache
        if c and (hs.timer.secondsSinceEpoch() - c.at) < (altTab.cacheFor or 0) then
            _G.diag.say("altTab", "reused cached window list (" .. #c.entries .. " entries)")
            return c.entries
        end
        return altTab.listWindows()
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
        if s.truncated then
        caption = caption .. "      ⚠️ list cut short at " ..
                  string.format("%.1fs", (_G.altTabLastListing or {}).seconds or 0) ..
                  " — see the Console"
    end
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
            local item = s.items[s.index]
            if item and item.appOnly and item.app then
                -- No window to focus: bring the application forward instead.
                pcall(function() item.app:activate() end)
            elseif item and item.win then
                pcall(function()
                    if item.win:isMinimized() then item.win:unminimize() end
                    -- focus() on a window living on another Space makes
                    -- macOS switch Spaces to reach it, which is what
                    -- Windows' Alt+Tab does too.
                    item.win:focus()
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
        local wins = altTab.listWindowsCached()
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
        for _, entry in ipairs(wins) do
            local w    = entry.win
            local app  = entry.app or (w and w:application())
            local name = app and app:name() or "?"
            local title
            if entry.appOnly then
                title = "no open window — switches to the app"
            else
                title = w:title()
                if title == nil or title == "" then title = name end
            end
            -- Snapshots are per-window and cheap (CoreGraphics, not AX), but
            -- still pcall'd: one uncooperative window must not take the
            -- whole switcher down.
            -- A window on another Space has nothing on screen to capture,
            -- so snapshot() returns nil for it and the app icon stands in.
            -- That is expected here, not a failure.
            local okSnap, img = false, nil
            if w then okSnap, img = pcall(function() return w:snapshot() end) end
            if not (okSnap and img) and app then
                local okIcon, icon = pcall(function()
                    return hs.image.imageFromAppBundle(app:bundleID())
                end)
                img = okIcon and icon or nil
            end
            table.insert(items, {
                win = w, app = app, appOnly = entry.appOnly, image = img,
                label = name, full = name .. " — " .. title,
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
        truncated = (_G.altTabLastListing or {}).truncated or false,
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
    -- Exposed as `config` so a MACHINE PROFILE in init.lua can override
    -- these per Mac (a work Mac with more corporate agents running may
    -- want a lower cap) without editing this file.
    M.config  = altTab
end

return M
