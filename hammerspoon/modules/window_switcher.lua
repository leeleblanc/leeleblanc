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
            { "← →", "Keep ⌥ down: step one tile, wrapping like Tab" },
            { "↑ ↓", "Keep ⌥ down: jump a whole ROW — the fast way across many rows" },
            { "Home / End", "First tile / last tile" },
            { "Return", "Switch to the highlighted tile without waiting for ⌥ release" },
            { "tiles", "One thumbnail per WINDOW, with its title underneath" },
            { "Esc", "Cancels — no switch" },
            { "shows", "EVERY window: all desktops/Spaces, all monitors, minimised too" },
            { "also", "Running apps with no open window — selecting one activates it" },
            { "tuning", "altTab.includeOtherSpaces / includeApps / maxWindows (module file)" },
            { "no perms", "altTab.useSnapshots = false — icons not thumbnails, and macOS" },
            { "",       "is never asked for Screen Recording (nothing else here needs it)" },
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
    -- 🔐 false = never photograph a window; every tile shows the app icon
    -- instead. This is the ONE setting in the whole config that decides
    -- whether macOS ever asks for Screen Recording permission — see the
    -- note at the snapshot call in begin() below.
    altTab.useSnapshots      = true

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
    altTab.escKey  = nil   -- the bare-Esc hotkey; see altTab.navKeys below
    altTab.navKeys = nil   -- every in-HUD key, built once, armed per session

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

        -- 🎨 6.90.0 — the card wears the shared style (ui_style.lua);
        -- the tiles' translucent wash stays its own: it sits OVER window
        -- snapshots, and the solid selection blue would hide them.
        local sty = _G.uiStyle or {}
        local els = {}
        table.insert(els, {
            type = "rectangle", action = "strokeAndFill",
            fillColor   = sty.bg or { red = 0.06, green = 0.06, blue = 0.08, alpha = 0.94 },
            strokeColor = sty.stroke or { white = 1, alpha = 0.22 }, strokeWidth = 1,
            roundedRectRadii = { xRadius = sty.radius or 18, yRadius = sty.radius or 18 },
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
                strokeColor = selected and (sty.selectLine
                                            or { red = 0.45, green = 0.68, blue = 1.0, alpha = 0.95 })
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
        -- The arrow hint only appears when there IS a second row, because
        -- on a single row ↑↓ do nothing and advertising a key that does
        -- nothing is worse than saying nothing at all.
        if (s.rows or 1) > 1 then
            caption = caption .. "      ↑↓ row · ←→ tile"
        end
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

    -- ---- actually switching (6.68.0) ------------------------------------
    -- LL: "Alt+tab does not reliably bring me to the select app or do it
    -- consistently."
    --
    -- 🚨 WHY win:focus() ON ITS OWN IS NOT A SWITCH. hs.window:focus() is
    -- becomeMain() + raise(), and both of those act WITHIN the owning
    -- application. Neither one activates that application. If the target
    -- belongs to an app that is not already frontmost — which is the only
    -- interesting case for a window switcher — the window rises and your
    -- keyboard stays exactly where it was. That is the whole "sometimes it
    -- doesn't take me there" complaint, and it is a one-line omission.
    --
    -- So the order is: activate the APP, then focus the WINDOW. Both, in
    -- that order, every time.
    --
    -- ⏱ AND UNMINIMIZING IS NOT INSTANT. unminimize() starts the genie
    -- animation and returns immediately; a focus() fired in the same tick
    -- lands on a window that is not on screen yet and is simply dropped.
    -- That path waits a beat first.
    altTab.verifyAfter  = 0.35   -- seconds before checking it worked
    altTab.unminimizeWait = 0.45 -- genie animation, roughly
    _G.altTabSwitchTimers = {}   -- HELD: an unreferenced timer never fires

    local function hold(t)
        table.insert(_G.altTabSwitchTimers, t)
        while #_G.altTabSwitchTimers > 8 do table.remove(_G.altTabSwitchTimers, 1) end
        return t
    end

    local function nameOf(item)
        local ok, n = pcall(function() return item.app and item.app:name() end)
        return (ok and n) or "?"
    end

    -- One switch attempt. Returns nothing; correctness is checked by the
    -- verifier below rather than assumed, because every call in here can
    -- fail silently at the macOS level.
    local function raise(item)
        if item.app then pcall(function() item.app:activate() end) end
        if item.win then
            pcall(function()
                item.win:becomeMain()
                item.win:raise()
                item.win:focus()
            end)
        end
    end

    -- 🚨 RULE #7: THE SWITCH REPORTS WHETHER IT WORKED. Everything above
    -- is best-effort at the macOS level, so a beat later we look at what
    -- is actually focused. Wrong window → one more attempt (an app that
    -- was swapped out often needs the second one). Still wrong → say so,
    -- with both names, instead of leaving you wondering whether you
    -- pressed the key properly.
    function altTab.switchTo(item)
        if not item then return false end
        local wantId
        pcall(function() wantId = item.win and item.win:id() end)
        local wantApp = nameOf(item)

        local function attempt(n)
            raise(item)
            hold(hs.timer.doAfter(altTab.verifyAfter, function()
                local okF, got = pcall(hs.window.focusedWindow)
                local gotId, gotApp
                if okF and got then
                    pcall(function() gotId = got:id() end)
                    pcall(function() gotApp = got:application():name() end)
                end
                -- An app-only tile has no window id to match, so the test
                -- is "is that app frontmost now", which is all it promised.
                local good
                if wantId then good = (gotId == wantId)
                else good = (gotApp == wantApp) end
                if good then
                    _G.diag.say("altTab", "switch confirmed: " .. wantApp)
                    _G.altTabLastSwitch = { ok = true, app = wantApp, attempts = n }
                    return
                end
                if n < 2 then
                    _G.diag.say("altTab", "switch to " .. wantApp
                                .. " did not take — retrying once")
                    attempt(n + 1)
                    return
                end
                _G.altTabLastSwitch = { ok = false, app = wantApp, got = gotApp,
                                        attempts = n }
                print("🔄 Window switcher: asked for " .. wantApp
                      .. " but the focus stayed on " .. tostring(gotApp or "nothing")
                      .. ". Usually macOS refusing to activate an app that is "
                      .. "busy or mid-launch — press ⌥Tab again.")
                if _G.notices then
                    _G.notices.record("runtime", "window switcher",
                        "could not switch to " .. wantApp
                        .. " (focus stayed on " .. tostring(gotApp or "nothing") .. ")")
                end
            end))
        end

        if item.win then
            local okMin, minimized = pcall(function() return item.win:isMinimized() end)
            if okMin and minimized then
                pcall(function() item.win:unminimize() end)
                hold(hs.timer.doAfter(altTab.unminimizeWait, function() attempt(1) end))
                return true
            end
        end
        attempt(1)
        return true
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
        altTab.armNavKeys(false)
        if not s then return end
        if s.canvas then pcall(function() s.canvas:delete() end) end

        _G.diag.say("altTab", "HUD closed (" .. (commit and "switching" or "cancelled") .. ")")
        if commit then
            -- 🚨 THE CACHE IS DROPPED ON EVERY SWITCH. It is keyed on time
            -- alone (4s), and front-to-back order is exactly what a switch
            -- changes — so a second ⌥Tab inside the window reused a list
            -- in which position 1 was still the window you had just LEFT
            -- and position 2 was the one you were now IN. Pressing ⌥Tab
            -- twice in quick succession therefore "switched" you to where
            -- you already were. That is the other half of "does not do it
            -- consistently", and no amount of focus-fixing addresses it.
            altTab.cache = nil
            altTab.switchTo(s.items[s.index])
        end
    end

    function altTab.advance(delta)
        local s = altTab.session
        if not s then return end
        local n = #s.items
        if n == 0 then return end
        s.index = ((s.index - 1 + delta) % n) + 1   -- wraps, like Windows
        altTab.render()
    end

    -- ---- arrow navigation (6.44.0) --------------------------------------
    -- Tab alone is one tile per press, which is fine for four windows and
    -- tedious for thirty. ← → are Tab and ⇧Tab by another name; ↑ ↓ move a
    -- WHOLE ROW, which is the actual saving — six tiles per keystroke on a
    -- six-column grid.
    --
    -- ↑ ↓ MOVE BY ROW, DO NOT WRAP, AND DO NOTHING AT THE EDGES. That is
    -- how every other grid on the Mac behaves — Finder's icon view,
    -- Launchpad — and matching them means there is nothing to learn.
    --
    -- The two rules that make it feel right:
    --   • The target ROW has to exist. ↑ on the top row and ↓ on the
    --     bottom row leave the highlight alone rather than teleporting it
    --     to the first or last tile, which is what an index-only clamp
    --     would do and what makes a grid feel unpredictable.
    --   • Inside a row that DOES exist, the index is clamped. The last row
    --     is usually short — 14 windows over 6 columns leaves 2 in the
    --     bottom row — so ↓ from column 5 has no cell directly below it and
    --     lands on the nearest real tile in that row instead of nothing.
    -- ← → still wrap, because a flat list has no ragged edge to fall off.
    function altTab.moveRow(delta)
        local s = altTab.session
        if not s then return end
        local n = #s.items
        if n == 0 then return end
        local cols = math.max(1, s.cols or 1)
        local rows = math.ceil(n / cols)
        local row  = math.floor((s.index - 1) / cols)
        local col  = (s.index - 1) % cols
        local targetRow = row + delta
        if targetRow < 0 or targetRow > rows - 1 then return end
        local target = targetRow * cols + col + 1
        if target > n then target = n end
        if target == s.index then return end
        s.index = target
        altTab.render()
    end

    function altTab.jumpTo(i)
        local s = altTab.session
        if not s then return end
        local n = #s.items
        if n == 0 then return end
        if i < 1 then i = 1 end
        if i > n then i = n end
        if i == s.index then return end
        s.index = i
        altTab.render()
    end

    -- ⚠️ WHY EVERY KEY IS REGISTERED FOUR TIMES, ONCE PER MODIFIER MASK.
    -- hs.hotkey matches the modifier flags EXACTLY: a hotkey registered as
    -- {} "escape" does not fire for ⌥Esc. The HUD only exists while ⌥ is
    -- held down, so every keystroke you make during it carries ⌥ — meaning
    -- the old {} "escape" binding could not fire during the very session it
    -- was meant to cancel. (That was a real bug, not a hypothetical: Esc
    -- has never worked mid-hold.) ⇧ is in the list too because ⌥⇧Tab walks
    -- backwards and you may still be holding ⇧ when you reach for an arrow.
    --
    -- These are hs.hotkey.new, NOT .bind: they are created disabled and are
    -- only enabled while the HUD is on screen, so the arrow keys, Esc and
    -- Return stay completely untouched the rest of the time.
    altTab.navMasks = { {}, { "alt" }, { "shift" }, { "alt", "shift" } }

    function altTab.ensureNavKeys()
        if altTab.navKeys then return altTab.navKeys end
        local actions = {
            { "left",   function() altTab.advance(-1) end },
            { "right",  function() altTab.advance(1)  end },
            { "up",     function() altTab.moveRow(-1) end },
            { "down",   function() altTab.moveRow(1)  end },
            { "home",   function() altTab.jumpTo(1) end },
            { "end",    function() altTab.jumpTo(math.maxinteger) end },
            { "escape", function() altTab.finish(false) end },
            { "return", function() altTab.finish(true)  end },
        }
        local keys = {}
        for _, mask in ipairs(altTab.navMasks) do
            for _, act in ipairs(actions) do
                local key, fn = act[1], act[2]
                -- The third and fifth arguments are pressed and REPEATED:
                -- holding ↓ keeps moving, the way a held arrow does
                -- everywhere else. Esc and Return get no repeat handler —
                -- a repeat there would fire finish() a second time.
                local repeatFn = (key ~= "escape" and key ~= "return") and fn or nil
                local ok, hk = pcall(hs.hotkey.new, mask, key, fn, nil, repeatFn)
                if ok and hk then
                    table.insert(keys, hk)
                    -- Kept under its old name so ⇪⇧D and the test harness
                    -- can still ask "is Esc armed?" the way they always did.
                    if key == "escape" and #mask == 0 then altTab.escKey = hk end
                else
                    print("🔄 Window switcher: could not register " ..
                          table.concat(mask, "+") .. "+" .. key .. " — " .. tostring(hk))
                end
            end
        end
        altTab.navKeys = keys
        return keys
    end

    function altTab.armNavKeys(on)
        for _, hk in ipairs(altTab.navKeys or {}) do
            pcall(function() if on then hk:enable() else hk:disable() end end)
        end
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
            --
            -- 🔐 THIS CALL IS THE ONLY THING IN THE WHOLE CONFIG THAT NEEDS
            -- SCREEN RECORDING PERMISSION. Photographing another app's
            -- window is a screen capture as far as macOS is concerned, so
            -- w:snapshot() is what makes the prompt appear. Set
            -- altTab.useSnapshots = false on a Mac where you cannot grant it
            -- (or simply do not want to): every tile falls back to the app
            -- icon, the switcher is otherwise identical, and macOS is never
            -- asked for the permission in the first place.
            local okSnap, img = false, nil
            if w and altTab.useSnapshots then
                okSnap, img = pcall(function() return w:snapshot() end)
            end
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

        -- 🎯 6.68.0 — THE STARTING TILE IS ANCHORED TO THE WINDOW YOU ARE
        -- ACTUALLY IN, not to position 1. `index = 2` was shorthand for
        -- "the tile after the current one" and quietly assumed the list
        -- always begins with the focused window. It usually does and it
        -- does not have to: a cached list is up to 4s old, and
        -- orderedWindows() puts a window there that may since have gone.
        -- When the assumption missed, the first ⌥Tab landed on a window
        -- one place off — sometimes the one you were already in, which
        -- looks exactly like the switcher doing nothing.
        --
        -- Found by asking the front window who it is and locating it, so
        -- the answer is right whatever order the list came back in. Not
        -- found (front app owns no listed window) → the old behaviour,
        -- which is the correct fallback: the first tile is a real target.
        local here = 1
        local okCur, cur = pcall(hs.window.focusedWindow)
        if okCur and cur then
            local okId, curId = pcall(function() return cur:id() end)
            if okId and curId then
                for i, it in ipairs(items) do
                    local okW, wid = pcall(function() return it.win and it.win:id() end)
                    if okW and wid == curId then here = i break end
                end
            end
        end
        -- Windows selects the NEXT window on the first press, not the one
        -- you are already in; ⌥⇧Tab selects the previous one. Both wrap.
        local start = ((here - 1 + (reverse and -1 or 1)) % n) + 1

        altTab.session = {
            items = items, cols = cols, rows = rows, w = w, h = h, hidden = total - n,
        truncated = (_G.altTabLastListing or {}).truncated or false,
            index = start,
            startedAt = hs.timer.secondsSinceEpoch(),
            canvas = canvas,
        }
        altTab.render()
        _G.diag.say("altTab", string.format("HUD open: %d tiles, %d cols, %dx%d, start index %d",
            n, cols, w, h, altTab.session.index))
        pcall(function()
            canvas:level((_G.panelLevel and _G.panelLevel("switcher"))
                         or hs.canvas.windowLevels.overlay)
        end)
        pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        -- See _G.showCanvasSafely in init.lua: a bare :show() throws when
        -- another app's remote view is mid-transition (Safari's URL
        -- completion is the usual one), abandoning the rest of the open
        -- sequence and leaving a half-ordered ghost.
        if _G.showCanvasSafely then _G.showCanvasSafely(canvas, "window switcher")
        else pcall(function() canvas:show() end) end

        altTab.ensureNavKeys()
        altTab.armNavKeys(true)

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
    -- ⎋ 6.78.0 — CLAIMED. The HUD's own Esc is armed only while a switch
    -- is in progress, and the cheat sheet's bare Esc is armed the whole
    -- time it is open — so ⌥Tab with the sheet up could close the SHEET
    -- and leave the switcher running. See core/coexist.lua.
    if _G.claimEscape then
        _G.claimEscape("switcher", nil,
            function() return altTab.session ~= nil end,
            function() altTab.finish(false) end)
    end

    _G.altTab = altTab
    M.altTab  = altTab
    -- Exposed as `config` so a MACHINE PROFILE in init.lua can override
    -- these per Mac (a work Mac with more corporate agents running may
    -- want a lower cap) without editing this file.
    M.config  = altTab
end

return M
