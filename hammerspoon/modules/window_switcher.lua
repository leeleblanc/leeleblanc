-- =====================================================================
-- MODULE: WINDOW SWITCHER (was §1.10) — ⌥Tab, Windows-style, one card per window
-- =====================================================================
-- Hold ⌥ and tap Tab to walk every open WINDOW — one thumbnail card
-- each — ⌥⇧Tab to walk back, release ⌥ to switch to the highlighted
-- one, Esc to cancel. That is the Windows Alt+Tab behaviour, which
-- macOS does not have: ⌘Tab switches APPS, so a five-window app hides
-- behind a single icon. ⌘Tab itself is left alone — macOS reserves it,
-- as §0.3's knownSystemCombos table already records. 6.154.0 draws the
-- cards as a ROLODEX (see altTab.layout in the ✏️ block); the 6.34.0
-- tile wall is one setting away.
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
--   • ONE per-app sweep over GUI apps only (6.152.0 — it used to also
--     call hs.window.orderedWindows(), which re-runs the same sweep
--     internally: the whole cost, paid twice). Front-to-back order
--     comes from hs.window._orderedwinids(), the raw CoreGraphics id
--     list — milliseconds, no watchers, no subscriptions.
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
    family = "windows",
    cheatsheet = {
        title = "🔄 WINDOW SWITCHER (⌥Tab — Windows-style)",
        entries = {
            { "⌥Tab", "Hold ⌥, tap Tab to turn the ROLODEX of windows, release to switch" },
            { "⌥⇧Tab", "Turn it backwards" },
            { "console", "The Hammerspoon Console is a card too, whenever it is open" },
            { "← →", "Keep ⌥ down: one card, wrapping like Tab" },
            { "↑ ↓", "Keep ⌥ down: turn the wheel FIVE cards at a time" },
            { "Home / End", "First card / last card" },
            { "Return", "Switch to the front card without waiting for ⌥ release" },
            { "cards", "One thumbnail per WINDOW — the front card large, neighbours" },
            { "",      "receding either side; EVERY window is on the wheel" },
            { "grid",  "altTab.layout = \"grid\" brings the tile wall back" },
            { "Esc", "Cancels — no switch" },
            { "shows", "Every window: all monitors, minimised too, other desktops" },
            { "memory", "Another desktop's windows are REMEMBERED from the last press" },
            { "",      "that saw them — one ⌥Tab on a desktop teaches it (per reload)" },
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
    altTab.includeOtherSpaces = true -- windows on OTHER desktops/Spaces —
                                     -- 6.152.0: this now gates the MEMORY
                                     -- (see the note at listWindows), which
                                     -- is the only way such windows can be
                                     -- listed at all
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
    altTab.listBudget  = 0.8   -- seconds; the PER-APP sweep stops when
                               -- spent. 6.151.0: measured over that sweep
                               -- alone — a slow on-screen listing (phase
                               -- 1) can no longer starve it to zero apps.
    -- ⏱ 6.153.0 — AND A SEPARATE ONE FOR THE MEMORY. Re-proving a
    -- remembered window is a synchronous AX round-trip to its app, and
    -- LL's Console showed the sum: "listing took 1.64s across 13 apps
    -- (slowest: 0.01s)" — thirteen fast apps CANNOT add up to 1.64s, so
    -- the missing 1.5s was the probe loop, which ran per press,
    -- unbudgeted, outside the per-app timer that was supposed to name
    -- slow things. Probes now stop when this budget is spent; what the
    -- budget could not reach is listed anyway (it was alive recently)
    -- and probed FIRST next press — least-recently-verified first — so
    -- a closed window is still culled within a press or two instead of
    -- haunting the grid forever.
    altTab.probeBudget = 0.25  -- seconds per press spent re-proving
                               -- remembered windows
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
    -- 🗂 6.154.0 — THE ROLODEX. LL: "Can you make Opt+Tab like a rolladex
    -- of tiles?" One card front and centre, its neighbours receding to
    -- either side — smaller, fainter, overlapped — and Tab turns the
    -- wheel. Three things the tile wall could not do fall out of it:
    --   · EVERY window is reachable. The wall drew only what the screen
    --     could hold and admitted the rest in a footer; the wheel shows
    --     a window of cards over the whole list, so 36 windows on a
    --     laptop are 36 cards, not 15 plus an apology.
    --   · Snapshots are taken LAZILY, for the cards on screen, one more
    --     per turn — not one per window on the keypress you are waiting
    --     on (the 6.35.0 lesson, taken further).
    --   · It reads as a ring: past the last card is the first, the way
    --     Tab has always wrapped.
    -- "grid" keeps the 6.34.0 tile wall exactly as it was.
    altTab.layout        = "rolodex"
    altTab.cardW, altTab.cardH = 320, 200   -- the centre card
    altTab.rolodexSide   = 3        -- cards shown either side of the centre
    altTab.rolodexScale  = 0.80     -- each step back shrinks by this much
    altTab.rolodexStep   = 0.38     -- sideways step per card, × cardW
    altTab.rolodexFade   = 0.22     -- alpha lost per step back
    altTab.rolodexJump   = 5        -- ↑ ↓ turn the wheel this many cards

    altTab.session = nil   -- nil when idle; a table while the HUD is up
    altTab.poll    = nil   -- MUST be held: an unreferenced timer is collected
    altTab.escKey  = nil   -- the bare-Esc hotkey; see altTab.navKeys below
    altTab.navKeys = nil   -- every in-HUD key, built once, armed per session

    -- ---- window list ----------------------------------------------------
    -- ⚠️ 6.39.0 — WHY THIS ASKS EVERY APPLICATION INSTEAD OF ASKING FOR
    -- "ALL WINDOWS". hs.window.orderedWindows() and hs.window.allWindows()
    -- report ONLY the current Mission Control Space. That is a documented
    -- macOS limit, not a Hammerspoon bug. Hammerspoon's own documented
    -- answer is hs.window.filter — the module that froze this Mac for 44
    -- seconds in 6.33.0, so that door stays shut.
    --
    -- 🚨 6.152.0 — ONE SWEEP, A CHEAP Z-ORDER, AND A MEMORY. Two findings
    -- off LL's Console rebuilt this function:
    --
    --   • THE OLD PHASE 1 WAS THE SAME SWEEP, PAID TWICE. It called
    --     hs.window.orderedWindows(), which internally asks every GUI app
    --     for its windows AGAIN (plus an isHidden per app and a
    --     visibility check per window) just to learn the stacking order —
    --     1.6s on LL's Air, every press, on top of the per-app pass's own
    --     0.7s. The stacking order is available WITHOUT any of that:
    --     hs.window._orderedwinids() is the raw CoreGraphics id list,
    --     front-to-back, in milliseconds. So the per-app pass is now the
    --     ONLY Accessibility sweep, and the id list ranks its results.
    --     That is "⌥Tab is slow to display", roughly halved at the root.
    --
    --   • AX DOES NOT REPORT OTHER DESKTOPS, AND NEVER DID. The 6.39.0
    --     comment above believed app:allWindows() returned windows on
    --     every Space. It returns minimised windows (they belong to no
    --     Space) — which is why 6.151.0 genuinely fixed those — but a
    --     window parked on ANOTHER desktop is simply absent from the
    --     answer: LL's sweep asked Chrome, Chrome answered in 0.00s, and
    --     the Docs window on Desktop 2 was not in it. The private APIs
    --     that can enumerate other Spaces return "a lot of false
    --     positives" by their own documentation and need window.filter to
    --     prune (banned), so the fix is a MEMORY instead: every window
    --     this function ever lists is remembered (altTab.known, id →
    --     window), and the AX element for a live window stays valid after
    --     its Space stops being enumerated — only the LISTING forgets it,
    --     the handle still answers role/title/focus. So windows the sweep
    --     no longer sees are probed (under altTab.probeBudget since
    --     6.153.0 — the probes ARE AX round-trips, and unbudgeted they
    --     were 1.5s of LL's press) and, if still alive, added as tiles;
    --     selecting one activates its app and focuses it, and macOS
    --     itself carries you to its desktop. The one honest limit: a
    --     window is remembered from the first ⌥Tab press that could see
    --     its Space — press ⌥Tab once on a desktop and its windows are
    --     known from then on (a reload starts the memory fresh).
    --
    -- ONLY GUI APPS ARE ASKED (app:kind() == 1). Background daemons and
    -- menu-bar agents are precisely the population whose AX timeouts made
    -- window.filter unusable; they own no windows worth switching to.
    --
    -- Order: this desktop front-to-back first (the CG id ranks), then the
    -- unranked — minimised and remembered/other-desktop windows — in
    -- sweep order, then app-only tiles. Sweep order is frontmost app,
    -- then apps that had a visible window LAST listing, then the rest, so
    -- the budget is spent on the apps you are most likely reaching for.
    altTab.known    = {}   -- id -> { win, app, name }; survives between presses
    altTab.lastHere = {}   -- app name -> true if it had a visible window last time

    function altTab.listWindows()
        local t0 = hs.timer.secondsSinceEpoch()
        local entries, seenWin, seenApp = {}, {}, {}
        -- ⏱ 6.156.0 — EVERY PHASE IS TIMED. LL's Console, again:
        -- "listing took 1.64s across 13 apps (slowest: Alfred Preferences
        -- 0.00s · memory: 0 probed in 0.00s)" — thirteen apps at 0.00s
        -- and no probes cannot add up to 1.64s, so the time was in a
        -- phase nothing measured. The owners pass (below) is the likely
        -- one: one application() + name() per entry, both AX round
        -- trips, outside every timer — and it no longer needs them (the
        -- sweep knows each window's app already). Whatever is left, the
        -- slow line now names the slowest phase, so the next paste is
        -- an answer rather than a question.
        local phases, pMark = {}, t0
        local function phase(name)
            local t = hs.timer.secondsSinceEpoch()
            phases[name] = (phases[name] or 0) + (t - pMark)
            pMark = t
        end

        -- 0. The stacking order, from CoreGraphics alone: id -> rank,
        -- front-to-back, current desktop only. pcall'd and optional —
        -- _orderedwinids is an hs.window internal, so a build without it
        -- costs the z-order, never the switcher.
        local zorder = {}
        pcall(function()
            local ids = (hs.window._orderedwinids and hs.window._orderedwinids()) or {}
            for i, id in ipairs(ids) do zorder[id] = i end
        end)
        phase("zorder")

        local seq = 0
        -- appName (6.156.0): the sweep knows which app it asked, so the
        -- entry carries the name and the owners pass below never has to
        -- ask AX for it again.
        local function add(w, remembered, appName)
            local okId, id = pcall(function() return w:id() end)
            if not (okId and id) or seenWin[id] then return end
            local okStd, standard = pcall(function() return w:isStandard() end)
            if not (okStd and standard) then return end
            if not altTab.includeMinimized then
                local okMin, min = pcall(function() return w:isMinimized() end)
                if okMin and min then return end
            end
            seenWin[id] = true
            seq = seq + 1
            table.insert(entries, { win = w, id = id, rank = zorder[id],
                                    seq = seq, remembered = remembered,
                                    appName = appName })
        end

        local skip = {}
        for _, n in ipairs(altTab.skipApps or {}) do skip[n] = true end

        -- 1. THE sweep — the only Accessibility pass, budgeted. It ALWAYS
        -- runs: since 6.152.0 it is the sole source of window objects, so
        -- the include* flags gate what is done with its results (the
        -- memory, the app-only tiles), never the sweep itself.
        local appsSeen, withWindows = {}, {}
        local truncated, slowestApp, slowestTime = false, nil, 0
        do
            local okApps, appErr = pcall(function()
                local frontName
                pcall(function()
                    local fa = hs.application.frontmostApplication()
                    if fa then frontName = fa:name() end
                end)
                -- kind() and name() are cheap properties off the bulk
                -- enumeration (the app_watcher 6.16.22 lesson), so
                -- ranking every app costs nothing next to one
                -- allWindows() call.
                local first, second, rest = {}, {}, {}
                for _, app in ipairs(hs.application.runningApplications() or {}) do
                    local okKind, kind = pcall(function() return app:kind() end)
                    local okName, aname = pcall(function() return app:name() end)
                    aname = okName and aname or "?"
                    if okKind and kind == 1 and not skip[aname] then
                        local a = { app = app, name = aname }
                        if aname == frontName then table.insert(first, a)
                        elseif altTab.lastHere[aname] then table.insert(second, a)
                        else table.insert(rest, a) end
                    end
                end
                local ordered = first
                for _, a in ipairs(second) do table.insert(ordered, a) end
                for _, a in ipairs(rest)   do table.insert(ordered, a) end
                phase("apps")

                local t1 = hs.timer.secondsSinceEpoch()
                for _, a in ipairs(ordered) do
                    -- THE DEADLINE. Checked before each app rather than
                    -- after, so the budget is a ceiling on what we ask
                    -- for, not a report on what we already spent.
                    if hs.timer.secondsSinceEpoch() - t1 > altTab.listBudget then
                        truncated = true
                        break
                    end
                    table.insert(appsSeen, a.app)
                    -- Timed PER APP: when one application is the
                    -- reason a press felt slow, the report has to
                    -- be able to name it. A single culprit goes in
                    -- altTab.skipApps and the problem is over.
                    local a0 = hs.timer.secondsSinceEpoch()
                    local okW, appWins = pcall(function() return a.app:allWindows() end)
                    if okW then
                        for _, w in ipairs(appWins or {}) do
                            add(w, false, a.name)
                            -- Feed the memory: any id add() accepted
                            -- (now or earlier this pass) is a real,
                            -- standard window worth remembering. `at` is
                            -- when it was last PROVEN alive — the sweep
                            -- just proved it, for free, so phase 2's
                            -- probes can spend their budget on windows
                            -- nothing has vouched for lately.
                            local okId, id = pcall(function() return w:id() end)
                            if okId and id and seenWin[id] then
                                altTab.known[id] = { win = w, app = a.app,
                                                     name = a.name, at = a0 }
                            end
                        end
                    end
                    local took = hs.timer.secondsSinceEpoch() - a0
                    if took > slowestTime then slowestTime, slowestApp = took, a.name end
                end
            end)
            if not okApps then
                print("🔄 Window switcher: could not list windows per application — "
                      .. tostring(appErr))
                _G.diag.warn("altTab", "per-application listing failed: " .. tostring(appErr))
            end
        end
        phase("sweep")

        -- 1b. HAMMERSPOON'S OWN CONSOLE (6.147.0 — LL: "Can I use
        -- alt+tab to land on the Hammerspoon console?"). It slips the
        -- net on purpose: Hammerspoon is a menu-bar app, so the
        -- kind == 1 sweep never asks it, and on some builds the console
        -- window answers isStandard() = false, which add() treats as
        -- "not a window you switch to". So it is asked for BY NAME —
        -- hs.console.hswindow() hands it over when it is open, and
        -- hands back nil when it is not (a closed console is not a
        -- tile, it is a tool you have not opened).
        pcall(function()
            if not (hs.console and hs.console.hswindow) then return end
            local cw = hs.console.hswindow()
            if not cw then return end
            local okId, id = pcall(function() return cw:id() end)
            if not (okId and id) or seenWin[id] then return end
            if not altTab.includeMinimized then
                local okMin, min = pcall(function() return cw:isMinimized() end)
                if okMin and min then return end
            end
            seenWin[id] = true
            seq = seq + 1
            table.insert(entries, { win = cw, id = id, rank = zorder[id], seq = seq,
                                    appName = "Hammerspoon" })
        end)
        phase("console")

        -- 2. THE MEMORY — windows this function listed before that the
        -- sweep no longer reports: parked on another desktop, or owned
        -- by an app the budget cut off this press. A dead APP costs
        -- nothing to detect (isRunning — no AX at all) and prunes its
        -- windows unconditionally. Re-proving a LIVE app's window is one
        -- AX attribute read (role), and 6.153.0 puts those under
        -- altTab.probeBudget, least-recently-verified first: this loop
        -- was the 1.5s LL's Console could not account for — every
        -- remembered window, two AX round-trips, every press, outside
        -- the per-app timer. A window the budget cannot reach is listed
        -- anyway (something vouched for it recently) and is at the front
        -- of the probe queue next press, so a closed window still
        -- disappears within a press or two. A probed-dead window is
        -- forgotten outright, same as always.
        local remembered, probed, probeSecs = 0, 0, 0
        if altTab.includeOtherSpaces then
            local cands = {}
            for id, k in pairs(altTab.known) do
                if seenWin[id] then
                    -- re-seen this press: memory already refreshed above
                elseif skip[k.name] then
                    altTab.known[id] = nil     -- skipApps means hands off
                else
                    local appGone = false
                    pcall(function()
                        if k.app and k.app.isRunning and not k.app:isRunning() then
                            appGone = true
                        end
                    end)
                    if appGone then altTab.known[id] = nil
                    else table.insert(cands, { id = id, k = k }) end
                end
            end
            table.sort(cands, function(a, b)
                return (a.k.at or 0) < (b.k.at or 0)
            end)
            local p0 = hs.timer.secondsSinceEpoch()
            for _, c in ipairs(cands) do
                local id, k = c.id, c.k
                local alive = true
                -- The budget is a ceiling on what we ask for, checked
                -- BEFORE each probe — the listBudget rule, applied here.
                local now = hs.timer.secondsSinceEpoch()
                if now - p0 < altTab.probeBudget then
                    alive = false
                    pcall(function()
                        if k.win and k.win:role() == "AXWindow" then alive = true end
                    end)
                    probed = probed + 1
                    if alive then k.at = now end
                end
                if not alive then
                    altTab.known[id] = nil
                else
                    local listIt = true
                    if not altTab.includeMinimized then
                        -- Only pay this second AX read when the answer
                        -- can change anything: with minimised windows
                        -- included (the default) it never could, and it
                        -- used to run per window per press regardless.
                        local wasMin = false
                        pcall(function() wasMin = k.win:isMinimized() or false end)
                        listIt = not wasMin
                    end
                    if listIt then
                        seenWin[id] = true
                        seq = seq + 1
                        remembered = remembered + 1
                        table.insert(entries, { win = k.win, id = id,
                                                seq = seq, remembered = true,
                                                appName = k.name })
                    end
                end
            end
            probeSecs = hs.timer.secondsSinceEpoch() - p0
        end
        phase("memory")

        -- Which apps already own a listed window? Worked out from the
        -- ENTRIES, not from how many each app contributed: an app whose
        -- windows all arrived from the memory adds nothing new in the
        -- sweep, and counting that as "has no windows" would give it a
        -- second, bogus "no open window" tile. The same pass records
        -- which apps had a VISIBLE window (rank = this desktop) — next
        -- press's sweep asks them first.
        -- 6.156.0 — NO AX HERE ANY MORE. This used to ask application()
        -- and name() of every entry, two round trips each, outside every
        -- timer: the likeliest home of LL's unexplained 1.6s. Every entry
        -- now arrives knowing its app's name (the sweep asked that app;
        -- the memory remembered it; the console is Hammerspoon), and AX
        -- is asked only for an entry that somehow does not.
        local lastHere = {}
        for _, e in ipairs(entries) do
            local n = e.appName
            if not n and e.win then
                local okA, a = pcall(function() return e.win:application() end)
                if okA and a then
                    local okN, nm = pcall(function() return a:name() end)
                    if okN then n = nm end
                end
            end
            if n then
                withWindows[n] = true
                if e.rank then lastHere[n] = true end
            end
        end
        altTab.lastHere = lastHere
        phase("owners")

        -- Front-to-back for what is on this desktop (the CG ranks), then
        -- everything unranked — minimised, other desktops — in the order
        -- it was found. seq breaks ties so the sort is total and the
        -- grid cannot shuffle between openings.
        table.sort(entries, function(x, y)
            local rx = x.rank or math.huge
            local ry = y.rank or math.huge
            if rx ~= ry then return rx < ry end
            return x.seq < y.seq
        end)

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

        phase("tail")
        local elapsed = hs.timer.secondsSinceEpoch() - t0
        local slowPhase, slowPhaseSecs = "none", 0
        for k, v in pairs(phases) do
            if v > slowPhaseSecs then slowPhase, slowPhaseSecs = k, v end
        end
        _G.diag.say("altTab", string.format(
            "listed %d entries in %.3fs (%d apps, %d remembered — %d probed in %.2fs%s%s"
            .. ", slowest phase: %s %.2fs)",
            #entries, elapsed, #appsSeen, remembered, probed, probeSecs,
            truncated and ", BUDGET SPENT" or "",
            slowestApp and string.format(", slowest: %s %.2fs", slowestApp, slowestTime) or "",
            slowPhase, slowPhaseSecs))
        if truncated then
            -- The budget died inside the sweep, so there is a culprit
            -- worth naming and skipApps is advice that helps. (The
            -- memory softens the cut: windows of the apps the budget
            -- skipped still appear, from the last press that saw them.)
            print(string.format(
                "🔄 Window switcher: stopped after %.1fs / %d apps — showing what it had. "
                .. "Slowest app: %s (%.2fs). Add it to altTab.skipApps in "
                .. "modules/window_switcher.lua, or raise altTab.listBudget.",
                elapsed, #appsSeen, tostring(slowestApp), slowestTime))
        elseif elapsed > altTab.slowWarnSeconds then
            -- 6.153.0 — the line now accounts for the MEMORY too. LL's
            -- "1.64s across 13 apps (slowest: 0.01s)" was unanswerable
            -- precisely because the probes ran outside every timer.
            -- 6.156.0 — and for the PHASE, so a slow press names where
            -- the time went even when no app and no probe took it.
            print(string.format(
                "🔄 Window switcher: listing took %.2fs across %d apps (slowest: %s %.2fs"
                .. " · memory: %d probed in %.2fs · slowest phase: %s %.2fs)",
                elapsed, #appsSeen, tostring(slowestApp), slowestTime,
                probed, probeSecs, slowPhase, slowPhaseSecs))
        end
        _G.altTabLastListing = {
            seconds = elapsed, apps = #appsSeen, entries = #entries,
            remembered = remembered, probed = probed, probeSecs = probeSecs,
            truncated = truncated, slowestApp = slowestApp, slowestTime = slowestTime,
            phases = phases, slowPhase = slowPhase, slowPhaseSecs = slowPhaseSecs,
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

    -- 📸 The tile picture, taken ONCE per item and only when asked for.
    -- Snapshots are per-window and cheap (CoreGraphics, not AX), but
    -- still pcall'd: one uncooperative window must not take the whole
    -- switcher down. A window on another Space has nothing on screen to
    -- capture, so snapshot() returns nil for it and the app icon stands
    -- in. That is expected here, not a failure.
    --
    -- 🔐 THIS CALL IS THE ONLY THING IN THE WHOLE CONFIG THAT NEEDS
    -- SCREEN RECORDING PERMISSION. Photographing another app's window is
    -- a screen capture as far as macOS is concerned, so w:snapshot() is
    -- what makes the prompt appear. Set altTab.useSnapshots = false on a
    -- Mac where you cannot grant it (or simply do not want to): every
    -- tile falls back to the app icon, the switcher is otherwise
    -- identical, and macOS is never asked for the permission at all.
    function altTab.imageFor(item)
        if item.snapTried then return item.image end
        item.snapTried = true
        local w, app = item.win, item.app
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
        item.image = img
        return img
    end

    -- 🗂 6.154.0 — the rolodex: which cards are on the wheel right now,
    -- FAR TO NEAR so the centre paints last and on top. `off` is the
    -- card's distance from the centre (negative = left). With enough
    -- windows the wheel is a ring (past the last card is the first);
    -- with fewer than 2·side+1 it is a straight strip, so no window is
    -- ever drawn twice.
    function altTab.rolodexCards(s)
        local n, cards = #s.items, {}
        if n == 0 then return cards end
        local ring = n >= 2 * s.side + 1
        for d = s.side, 0, -1 do
            local offs = (d == 0) and { 0 } or { -d, d }
            for _, off in ipairs(offs) do
                local idx = s.index + off
                if ring then
                    idx = ((idx - 1) % n) + 1
                    cards[#cards + 1] = { idx = idx, off = off }
                elseif idx >= 1 and idx <= n then
                    cards[#cards + 1] = { idx = idx, off = off }
                end
            end
        end
        return cards
    end

    local function renderRolodex(s, els, sty)
        local cW, cH = altTab.cardW, altTab.cardH
        local centreX, topY = s.w / 2, altTab.pad
        for _, c in ipairs(altTab.rolodexCards(s)) do
            local item  = s.items[c.idx]
            local depth = math.abs(c.off)
            local scale = altTab.rolodexScale ^ depth
            local w, h  = cW * scale, cH * scale
            local x = centreX + c.off * altTab.rolodexStep * cW - w / 2
            local y = topY + (cH - h) / 2
            local alpha = math.max(0.15, 1 - depth * altTab.rolodexFade)
            local front = (c.off == 0)
            table.insert(els, {
                type = "rectangle", action = "strokeAndFill",
                fillColor   = front and { red = 0.28, green = 0.52, blue = 0.92, alpha = 0.35 }
                                    or { white = 0.10, alpha = 0.85 * alpha },
                strokeColor = front and (sty.selectLine
                                         or { red = 0.45, green = 0.68, blue = 1.0, alpha = 0.95 })
                                    or { white = 1, alpha = 0.18 * alpha },
                strokeWidth = front and 2 or 1,
                roundedRectRadii = { xRadius = 10 * scale, yRadius = 10 * scale },
                frame = { x = x, y = y, w = w, h = h },
            })
            -- taken here, for THIS card, the first time it is on the wheel
            local img = altTab.imageFor(item)
            if img then
                table.insert(els, {
                    type = "image", image = img, imageAlpha = alpha,
                    imageScaling = "scaleProportionally", imageAlignment = "center",
                    frame = { x = x + 8 * scale, y = y + 8 * scale,
                              w = w - 16 * scale, h = h - 16 * scale },
                })
            end
        end
        local current = s.items[s.index]
        table.insert(els, {
            type = "text", text = fit(current and current.label or "", 40),
            textSize = 13, textAlignment = "center", textColor = { white = 1 },
            frame = { x = altTab.pad, y = topY + cH + 8, w = s.w - altTab.pad * 2, h = 20 },
        })
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

        if s.layout == "rolodex" then renderRolodex(s, els, sty) end

        local titleChars = math.max(8, math.floor(altTab.tileW / 7))
        for i, item in ipairs(s.layout == "rolodex" and {} or s.items) do
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
        if s.layout == "rolodex" then
            -- the wheel's position, then the hint: ↑↓ only when a jump
            -- can actually move more than a step
            caption = string.format("%d / %d  ·  %s", s.index, #s.items, caption)
            if #s.items > altTab.rolodexJump then
                caption = caption .. string.format("      ←→ one · ↑↓ %d", altTab.rolodexJump)
            end
        -- The arrow hint only appears when there IS a second row, because
        -- on a single row ↑↓ do nothing and advertising a key that does
        -- nothing is worse than saying nothing at all.
        elseif (s.rows or 1) > 1 then
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
        -- 🗂 the rolodex has no rows: ↑↓ turn the wheel by rolodexJump,
        -- clamped at the ends (a big step that wrapped would be a guess)
        if s.layout == "rolodex" then
            altTab.jumpTo(s.index + delta * altTab.rolodexJump)
            return
        end
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
        local layout = (altTab.layout == "grid") and "grid" or "rolodex"

        -- Fitted to the SCREEN, not to a fixed column count. Six 200pt tiles
        -- plus padding is 1314pt — wider than a 1280pt laptop display, and a
        -- HUD wider than its screen centres itself with tiles cut off at
        -- BOTH edges. Columns come from the width that actually exists, rows
        -- from the height; anything that will not fit is dropped from the
        -- BACK (least recent) and the footer says how many are showing,
        -- because a silently shortened list is the same class of bug as text
        -- clipped mid-sentence. (The GRID's rule — the rolodex keeps every
        -- window, see the ✏️ block.)
        local cellH   = altTab.tileH + 24 + altTab.gap
        local cols    = math.floor((sf.w * 0.92 - altTab.pad * 2 + altTab.gap)
                                   / (altTab.tileW + altTab.gap))
        cols = math.max(1, math.min(altTab.maxCols, cols, #wins))
        local rowsMax = math.max(1, math.floor((sf.h * 0.9 - altTab.pad * 2 - 14) / cellH))
        local total   = #wins
        if layout == "grid" then
            for i = total, cols * rowsMax + 1, -1 do table.remove(wins, i) end
        end

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
            local item = {
                win = w, app = app, appOnly = entry.appOnly, image = nil,
                remembered = entry.remembered, label = name,
                -- A remembered tile says so in the caption: the sweep no
                -- longer sees this window (another desktop, usually), so
                -- selecting it rides the app activation across Spaces.
                full = name .. " — " .. title
                       .. (entry.remembered and "   · remembered (another desktop?)" or ""),
            }
            -- The grid draws every tile at once, so it captures every
            -- tile now; the rolodex captures each card the first time it
            -- turns into view (altTab.imageFor, from render).
            if layout == "grid" then altTab.imageFor(item) end
            table.insert(items, item)
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
        local side = 0
        if layout == "rolodex" then
            -- the wheel: a centre card and up to rolodexSide either way,
            -- fewer if the screen is narrow (the 1314pt lesson, again)
            side = math.min(altTab.rolodexSide, math.max(0, n - 1))
            local function wheelW(k)
                return altTab.pad * 2 + altTab.cardW
                       + 2 * k * altTab.rolodexStep * altTab.cardW
            end
            while side > 0 and wheelW(side) > sf.w * 0.92 do side = side - 1 end
            cols, rows = 1, 1
            w = wheelW(side)
            h = altTab.pad * 2 + altTab.cardH + 28 + 30
        end
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
            layout = layout, side = side,
            index = start,
            startedAt = hs.timer.secondsSinceEpoch(),
            canvas = canvas,
        }
        altTab.render()
        -- ⚠️ %.0f for the size: the wheel's width is a float (cardW × a
        -- fraction), and %d on a float RAISES in Lua 5.4
        _G.diag.say("altTab", string.format("HUD open: %d tiles, %s, %.0fx%.0f, start index %d",
            n, layout == "rolodex" and ("rolodex ±" .. side) or (cols .. " cols"),
            w, h, altTab.session.index))
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
