-- =====================================================================
-- MODULE: WINDOW RETURN (automatic) — dock back in, windows go back
-- =====================================================================
-- LL: "Windows scattering when I plug into the dock. Yup." When a
-- monitor unplugs, macOS piles every window onto the screens that are
-- left, and plugging back in does NOT put them back. This module does:
-- it quietly remembers where your windows sit for EACH monitor setup,
-- and when a setup comes back, the windows that scattered return to
-- their remembered frames.
--
-- HOW IT KNOWS "WHICH SETUP": the sorted UUIDs of the connected
-- screens, joined into one signature string. Same physical monitors =
-- same signature, whatever order macOS lists them in. The laptop alone
-- is one setup; laptop + dock is another; each keeps its own memory.
--
-- ⚖️ THIS IS THE CONFIG'S ANSWER TO SpaceSaver, DELIBERATELY SMALLER.
-- LL brought in piclane's SpaceSaver Spoon (1,600 lines) and the
-- verdict was: right pain, wrong tool for THIS config. SpaceSaver
-- manages macOS Spaces — and because hs.spaces.moveWindowToSpace
-- "returns success without moving" on macOS 15+, it falls back to
-- SYNTHESIZING REAL MOUSE DRAGS and cycling every Space on capture.
-- That fights this config's own machinery head-on: Window Move's tap
-- consumes clicks it thinks belong to our panels, coexist.lua assumes
-- nothing else drives the screen, and none of it is testable in our
-- stubbed suites. So this module does the 80% with none of that:
--   • FRAMES ONLY, on the visible Space. hs.spaces is never touched.
--   • No synthetic input, no Space switching, no yq, no files to hand-
--     edit. One hs.settings key.
--   • Matching is id-first, then exact bundle+title — no title
--     patterns to write or mis-write.
-- The honest cost: windows parked on OTHER Spaces are invisible to
-- hs.window.allWindows() and stay wherever macOS left them. If that
-- ever hurts in practice, the answer is revisiting SpaceSaver's Space
-- walk — with eyes open about everything above — not patching here.
--
-- 🚨 THE SETTLE WAIT IS LOAD-BEARING (SpaceSaver's hardest-won lesson,
-- kept). Monitors do not arrive at once: a DisplayLink screen is
-- recognised first and gets its real resolution seconds later, and
-- macOS re-scatters windows at each step. Restoring into a half-built
-- setup means the last monitor's arrival undoes the work. So after a
-- screen change we wait for the debounce, then require the signature
-- to hold still for consecutive readings before acting.
--
-- WHY SNAPSHOTS ARE PERIODIC rather than taken "on unplug": there is
-- no "about to unplug" event — by the time the screen watcher fires,
-- macOS has already scattered the windows. The only way to hold the
-- docked layout is to already have it, so a quiet timer refreshes the
-- CURRENT setup's memory every snapshotSecs. Refreshes pause while a
-- screen change is in flight, so a mid-transition mess is never saved
-- over a good layout.
--
-- WHAT A RELOAD / RESTART COSTS: nothing. Layouts persist in
-- hs.settings, and macOS window ids outlive Hammerspoon — they change
-- only when the APP is relaunched, which is what the bundle+title
-- fallback is for. A window that matches neither is skipped, never
-- guessed at: SpaceSaver's own comments document how eager matching
-- moves the wrong window, and skipping is the mistake you don't notice.

local M = {
    name   = "Window Return",
    order  = 6.6,
    family = "windows",
    cheatsheet = {
        title = "🔁 WINDOW RETURN (automatic — dock back in, windows go back)",
        entries = {
            { "auto",   "Remembers where windows sit for EACH monitor setup (every 30s)" },
            { "auto",   "When a setup returns — dock back in — scattered windows snap back" },
            { "scope",  "The visible Space only; macOS Spaces are never touched" },
            { "match",  "By window id, then exact app+title — an unmatched window is left alone" },
            { "_G.windowsBack()", "Console: put them back right now, by hand" },
            { "off",    "wr.enabled = false in modules/window_return.lua's EDIT HERE" },
        },
    },
}

function M.setup(core)
    local wr = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    wr.enabled      = true
    wr.snapshotSecs = 30     -- how often the current setup's layout is refreshed
    wr.sweepStep    = 0.05   -- pause between apps inside one snapshot sweep
    wr.slowAppMs    = 250    -- an app slower than this gets named in the console
    wr.settleSecs   = 2.0    -- quiet time after a monitor change before looking
    wr.stableStep   = 1.0    -- seconds between stability readings
    wr.stableNeed   = 2      -- consecutive identical readings = settled
    wr.maxWaitSecs  = 20     -- give up waiting and act with what's there
    wr.minDriftPx   = 4      -- a window already within this many px is left alone
    -- ----------------------------------------------------------------------

    local SETTINGS_KEY = "windowReturn.layouts"

    local function say(m)  if _G.diag then _G.diag.say("windowReturn", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("windowReturn", m) end end

    -- Moving OTHER apps' windows is exactly what Accessibility gates. On
    -- a work Mac where IT refused it, start nothing: capabilities.lua
    -- already tells the user what being off costs, and a module that
    -- polls anyway just spends battery measuring windows it cannot move.
    local axOK = false
    pcall(function() axOK = hs.accessibilityState() == true end)

    wr.layouts = {}
    pcall(function()
        local saved = hs.settings.get(SETTINGS_KEY)
        if type(saved) == "table" then wr.layouts = saved end
    end)

    wr.sweeping   = false   -- a chunked snapshot is mid-flight (6.137.0)
    wr.sweepTimer = nil     -- HELD: the step timer between apps
    wr.lastSweep  = nil     -- per-app ms profile of the latest sweep

    function wr.signature()
        local uuids = {}
        pcall(function()
            for _, scr in ipairs(hs.screen.allScreens()) do
                local u = scr:getUUID()
                if u then uuids[#uuids + 1] = u end
            end
        end)
        table.sort(uuids)
        return table.concat(uuids, "+")
    end

    -- One remembered window. Everything pcall'd per window: a window can
    -- die between being listed and being asked its title, and one corpse
    -- must not cost the snapshot.
    local function describe(win)
        local ok, d = pcall(function()
            if not win:isStandard() or win:isMinimized() then return nil end
            local app = win:application()
            local bundle = app and app:bundleID()
            -- our own pickers and panels place themselves (§1.5); saving
            -- them here would fight the popupOffset system
            if not bundle or bundle == "org.hammerspoon.Hammerspoon" then return nil end
            local f = win:frame()
            if not (f and f.w and f.w > 0 and f.h and f.h > 0) then return nil end
            return { id = win:id(), bundle = bundle, title = win:title() or "",
                     x = f.x, y = f.y, w = f.w, h = f.h }
        end)
        return ok and d or nil
    end

    -- 🚨 6.137.0 — THE SNAPSHOT NO LONGER FREEZES THE KEYBOARD. The old
    -- body was one hs.window.allWindows() call: a synchronous
    -- Accessibility round trip to every app at once, measured at 1,586ms
    -- on macOS 27 — and it ran every 30 seconds on the one thread every
    -- keystroke waits on. Same disease as focus_mode's Outlook lookup,
    -- smaller dose (see the 6.137.0 note there).
    --
    -- Now the sweep is CHUNKED: regular GUI apps only (app:kind() == 1 —
    -- the background agents that make up most of ~128 running processes
    -- own no standard window and are not worth an AX round trip each),
    -- ONE app's windows per timer step, a breath between apps for
    -- keystrokes to get through. The trade, chosen deliberately: an
    -- accessory app's window (kind 0) is no longer remembered — describe()
    -- only keeps standard windows anyway, and those live in regular apps.
    -- A monitor change mid-sweep abandons the whole pass uncommitted:
    -- half of yesterday's desktop stitched to half of today's is worse
    -- than 30 more seconds of the layout we already had.
    --
    -- Each app's cost is measured into wr.lastSweep, and any single app
    -- over wr.slowAppMs gets named in the console — if one process is
    -- eating the sweep, the next fix should know its name, not guess.
    function wr.snapshot()
        if wr.transitioning then return end   -- never save a mid-change mess
        if wr.sweeping then return end        -- one sweep at a time
        local sig = wr.signature()
        if sig == "" then return end

        local apps = {}
        pcall(function()
            for _, a in ipairs(hs.application.runningApplications() or {}) do
                local okK, k = pcall(function() return a:kind() end)
                if okK and k == 1 then apps[#apps + 1] = a end
            end
        end)
        if #apps == 0 then return end

        wr.sweeping = true
        local entries = {}
        local profile = { apps = {}, totalMs = 0, at = os.date("%H:%M:%S") }
        local i = 0
        local function step()
            if wr.transitioning then wr.sweeping = false; return end
            i = i + 1
            local app = apps[i]
            if not app then
                wr.sweeping  = false
                wr.lastSweep = profile
                if #entries == 0 then return end  -- an empty desktop teaches nothing
                wr.layouts[sig] = { savedAt = os.time(), entries = entries }
                pcall(function() hs.settings.set(SETTINGS_KEY, wr.layouts) end)
                return
            end
            local t0 = hs.timer.absoluteTime()
            pcall(function()
                for _, win in ipairs(app:allWindows() or {}) do
                    local d = describe(win)
                    if d then entries[#entries + 1] = d end
                end
            end)
            local ms = (hs.timer.absoluteTime() - t0) / 1e6
            profile.totalMs = profile.totalMs + ms
            local an = "?"
            pcall(function() an = app:name() or "?" end)
            profile.apps[#profile.apps + 1] = { name = an, ms = ms }
            if ms > wr.slowAppMs then
                -- math.floor, because ms is a FLOAT (absoluteTime / 1e6)
                -- and Lua 5.4's %d throws "number has no integer
                -- representation" for 812.7 — a real crash off LL's
                -- Console (6.152.0), on the once-a-cycle snapshot timer.
                warn(("%s took %dms to list its windows"):format(an, math.floor(ms)))
            end
            -- HELD in wr: an unreferenced hs.timer is collected before it
            -- fires (the 6.16.18 lesson), and a collected step is a sweep
            -- that silently never finishes.
            wr.sweepTimer = hs.timer.doAfter(wr.sweepStep, step)
        end
        step()
    end

    -- Is this remembered frame still somewhere a window can live? A
    -- frame whose CENTER is on no current screen would be flung into the
    -- void — skip it rather than trust it.
    local function onSomeScreen(e)
        local cx, cy = e.x + e.w / 2, e.y + e.h / 2
        local ok, hit = pcall(function()
            for _, scr in ipairs(hs.screen.allScreens()) do
                local f = scr:fullFrame()
                if cx >= f.x and cx <= f.x + f.w
                   and cy >= f.y and cy <= f.y + f.h then return true end
            end
            return false
        end)
        return ok and hit
    end

    -- The restore plan: which live window gets which remembered frame.
    -- Pass 1 claims by window id (survives reload, dock, unplug — dies
    -- only with the app). Pass 2 lets still-unclaimed entries take an
    -- unclaimed window with the same bundle AND exact title. Each side
    -- is consumed as it matches, so two "Untitled" TextEdit windows get
    -- one frame each instead of both getting the first.
    function wr.plan(saved)
        local wins = {}
        pcall(function() wins = hs.window.allWindows() or {} end)
        local live, claimed = {}, {}
        for _, win in ipairs(wins) do
            local d = describe(win)
            if d then live[#live + 1] = { win = win, d = d } end
        end

        local moves, leftover = {}, {}
        local function drift(d, e)
            return math.abs(d.x - e.x) + math.abs(d.y - e.y)
                 + math.abs(d.w - e.w) + math.abs(d.h - e.h)
        end
        local function claim(entry, lv)
            claimed[lv] = true
            if not onSomeScreen(entry) then return end
            if drift(lv.d, entry) <= wr.minDriftPx then return end
            moves[#moves + 1] = { win = lv.win,
                frame = { x = entry.x, y = entry.y, w = entry.w, h = entry.h } }
        end

        for _, entry in ipairs(saved.entries or {}) do
            local hit
            for _, lv in ipairs(live) do
                if not claimed[lv] and lv.d.id == entry.id then hit = lv break end
            end
            if hit then claim(entry, hit) else leftover[#leftover + 1] = entry end
        end
        for _, entry in ipairs(leftover) do
            for _, lv in ipairs(live) do
                if not claimed[lv] and lv.d.bundle == entry.bundle
                   and lv.d.title == entry.title then
                    claim(entry, lv)
                    break
                end
            end
        end
        return moves
    end

    -- quiet=true is the automatic path finding nothing to do; by-hand
    -- calls always answer, because silence after a typed command reads
    -- as "it is broken".
    function wr.restore(quiet)
        local sig = wr.signature()
        local saved = wr.layouts[sig]
        if not saved then
            if not quiet then
                hs.alert.show("🔁 Window Return: nothing remembered for this"
                              .. " monitor setup yet — it learns within 30s")
            end
            return 0
        end
        local moves = wr.plan(saved)
        for _, mv in ipairs(moves) do
            pcall(function() mv.win:setFrame(mv.frame, 0) end)
        end
        if #moves > 0 then
            hs.alert.show("🔁 " .. #moves .. " window"
                          .. (#moves == 1 and "" or "s") .. " returned")
            say(#moves .. " windows returned for setup " .. sig)
        elseif not quiet then
            hs.alert.show("🔁 Window Return: everything is already where it was")
        end
        return #moves
    end

    -- ---- the settle wait, then the one decision ---------------------------
    -- HELD in wr.* — an unreferenced hs.timer is collected and never
    -- fires. Same rule as every timer in this config.
    wr.lastSig       = wr.signature()
    wr.transitioning = false

    function wr.settled()
        wr.transitioning = false
        local sig = wr.signature()
        if sig == wr.lastSig then return end     -- same setup; a false alarm
        wr.lastSig = sig
        if wr.layouts[sig] then wr.restore(true) end
    end

    local function stabilityLoop()
        local last, same, waited = nil, 0, 0
        local function step()
            local sig = wr.signature()
            if sig == last then same = same + 1 else same, last = 1, sig end
            if same >= wr.stableNeed or waited >= wr.maxWaitSecs then
                if waited >= wr.maxWaitSecs then
                    warn("screens never settled — acting after " .. waited .. "s anyway")
                end
                wr.settled()
                return
            end
            waited = waited + wr.stableStep
            wr.stepTimer = hs.timer.doAfter(wr.stableStep, step)
        end
        step()
    end

    function wr.screensChanged()
        wr.transitioning = true
        if wr.settleTimer then pcall(function() wr.settleTimer:stop() end) end
        wr.settleTimer = hs.timer.doAfter(wr.settleSecs, stabilityLoop)
    end

    _G.windowsBack = function() return wr.restore(false) end

    if wr.enabled and axOK then
        wr.watcher = hs.screen.watcher.new(function() wr.screensChanged() end)
        wr.watcher:start()
        -- first snapshot waits out the boot rush, then the quiet cadence
        wr.firstTimer = hs.timer.doAfter(15, function() wr.snapshot() end)
        wr.snapTimer  = hs.timer.doEvery(wr.snapshotSecs, function() wr.snapshot() end)
        say("watching — " .. (next(wr.layouts) and "layouts loaded" or "no layouts yet"))
    elseif wr.enabled then
        -- capabilities.lua already reports what Accessibility being off
        -- costs; this just keeps the by-hand command honest.
        say("off — Accessibility not granted, other apps' windows can't move")
        _G.windowsBack = function()
            hs.alert.show("🔁 Window Return is off — Accessibility is not"
                          .. " granted on this Mac (see ⇪⇧D)")
            return 0
        end
    end

    _G.windowReturn = wr
    M.wr     = wr
    M.config = wr
end

return M
