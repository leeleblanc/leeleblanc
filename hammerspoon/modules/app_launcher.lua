-- =====================================================================
-- MODULE: APP LAUNCHER (⇪D) — launch any installed app, from the keyboard
-- =====================================================================
-- ⇪D lists every application installed on this Mac. Type a few letters,
-- press Return, and it launches — or, if it is already running, comes to
-- the front. That second half matters: the key means "get me this app",
-- not "start another copy".
--
-- ---------------------------------------------------------------------
-- WHERE IT LOOKS, AND WHY THAT LIST IS THE WHOLE POINT
-- ---------------------------------------------------------------------
--   /Applications          the regular folder — most personal-Mac installs
--   ~/Applications         per-USER installs. On the work Mac, where there
--                          is no admin right, this is where everything you
--                          are allowed to install actually lands (JetBrains
--                          Toolbox, Chrome web apps, hand-dragged bundles).
--   /System/Applications   Safari, Mail, Terminal — Apple moved the
--                          built-ins here in Catalina; a launcher that
--                          skips it answers "Safari" with silence.
--
-- Each folder is also read ONE level deep — that is where Utilities and
-- vendor folders ("Adobe Creative Cloud", "Chrome Apps.localized") keep
-- their apps — and never deeper, and never INSIDE an .app bundle.
--
-- A folder that does not exist contributes nothing and complains about
-- nothing. That is the two-Mac story in one line: the personal Mac has a
-- full /Applications and little in ~/Applications, the work Mac is the
-- reverse, and the SAME module serves both without a settings fork —
-- which is this config's whole §0.1 thesis.
--
-- ---------------------------------------------------------------------
-- WHY NOT ⌘space, AND WHY NOT ⇪W
-- ---------------------------------------------------------------------
-- Spotlight searches everything — files, mail, web — and what it ranks
-- first is its call, not yours. This list is apps first, and all of
-- them, with the folder each one came from printed under its name (the
-- same app installed twice shows twice, labelled). And macOS 26 retired
-- Launchpad, so "see every installed app" no longer has a system home.
--
-- 🗂 6.96.0 — AND NOW YOUR FILES, BEHIND THE APPS. When the Search
-- Index module (search_index.lua) is loaded, typing three or more
-- letters also lists matching FILES from its OneDrive + home-folder
-- index, 📄-labelled with their folder, under whatever apps match.
-- Apps always outrank files; ⏎ on a file row opens it in its default
-- app. The index is searched IN MEMORY (no disk on a keystroke), and
-- when the module is absent or its index is empty, ⇪D is exactly the
-- apps-only picker it was in 6.91.0 — including its native fuzzy
-- filter. With files on, filtering is "every word is a substring",
-- the same rule every other picker in this config uses.
--
-- ⇪W is the neighbour, not a rival: ⇪W summons an app that is already
-- RUNNING to this monitor; ⇪D launches ones that are not. Reach for ⇪D,
-- and if it turns out the app was open the whole time, it focuses — the
-- two keys meet in the middle on purpose.
--
-- There is no ⇪⇧D twin — Diagnostics has owned ⇪⇧D since 6.19.0 and a
-- launcher does not outrank the tool that debugs everything else. The
-- inventory lives in _G.appLauncherReport() instead.
--
-- ---------------------------------------------------------------------
-- ⚠️ THE DEFENSIVE POSTURE (same reasoning as ⇪M, smaller stakes)
-- ---------------------------------------------------------------------
-- Walking local folders is fast, but "fast" is a measurement, not a
-- promise: a network-mounted folder or a wedged volume can stall a
-- directory read. So the walk is time-boxed, every filesystem call sits
-- inside a pcall, and results are cached — a pathwatcher on each folder
-- drops the cache the moment something is installed or removed, so the
-- cache can be LONG without ever being stale.

local M = {
    name  = "App Launcher",
    order = 7.5,
    family = "find",               -- with App Peek (7) and the ⌥Tab switcher (8)
    cheatsheet = {
        title = "🚀 APP LAUNCHER (⇪D — every installed app, by name)",
        entries = {
            { "⇪D",    "Type an app's name, ⏎ launches it (focuses if running)" },
            { "scope", "/Applications · ~/Applications · /System/Applications" },
            { "",      "…each one folder deep: Utilities, vendor folders" },
            { "files", "3+ letters: indexed FILES list under the apps — ⏎ opens" },
            { "work",  "Same key both Macs — user-dir installs included" },
            { "⇪W",    "Neighbour key: summon an already-RUNNING app instead" },
        },
    },
}

function M.setup(core)
    local launcher = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    launcher.enabled    = true
    launcher.key        = "d"      -- ⇪D. No ⇪⇧D — Diagnostics owns it.
    launcher.cacheSecs  = 300      -- long on purpose: the pathwatchers
                                   -- invalidate on real change, so this is
                                   -- only the backstop for missed events
    launcher.scanBudget = 1.0      -- hard stop for the whole walk, seconds
    launcher.icons      = true     -- app icons in the picker rows
    launcher.iconBudget = 0.6      -- seconds of icon loading per build;
                                   -- rows past the budget simply get none
    launcher.files      = true     -- 6.96.0: indexed files behind the apps
    launcher.fileRows   = 12       -- at most this many file rows per keystroke
    -- Folders searched, in the order their rows should win ties. label is
    -- what the picker prints under each app's name. core.homeDir with a
    -- fallback, not bare: a harness core without it is a real shape.
    local home = core.homeDir or os.getenv("HOME") or "~"
    launcher.dirs = {
        { path = "/Applications",          label = "/Applications"        },
        { path = home .. "/Applications",  label = "~/Applications"       },
        { path = "/System/Applications",   label = "/System/Applications" },
    }
    -- ✏️ Extra folders, per machine if you like (absolute paths):
    --     launcher.extraDirs = { "/opt/homebrew/Caskroom" }
    launcher.extraDirs = {}
    -- ----------------------------------------------------------------------

    launcher.cache, launcher.cacheAt, launcher.lastScanMs = nil, 0, 0

    local function say(m)  if _G.diag then _G.diag.say("launcher", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("launcher", m) end end

    -- hs.timer in a pcall rather than bare: on a half-initialised install
    -- the extension can be missing, and a clock that answers os.time() is
    -- better than a launcher that answers a traceback.
    local function epoch()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        if ok and type(t) == "number" then return t end
        return os.time()
    end

    -- One directory listing, fully guarded. hs.fs.dir THROWS on a missing
    -- folder (a Mac without ~/Applications is normal, not broken), and the
    -- iterator itself can fail mid-walk on a vanishing volume — so the
    -- whole loop lives inside the pcall and a failure yields {}.
    local function entriesIn(dir)
        local names = {}
        pcall(function()
            for name in hs.fs.dir(dir) do
                if name ~= "." and name ~= ".." then
                    names[#names + 1] = name
                end
            end
        end)
        return names
    end

    local function isDir(path)
        local ok, mode = pcall(function()
            return hs.fs.attributes(path, "mode")
        end)
        return ok and mode == "directory"
    end

    -- depth counts REMAINING sublevels: 1 at a root (so Utilities is
    -- reached), 0 inside it. An .app is taken and never entered — a bundle
    -- is a directory full of helper bundles that are not launch targets.
    local function appsIn(dir, label, depth, found, deadline)
        for _, name in ipairs(entriesIn(dir)) do
            if epoch() > deadline then
                warn("scan budget exhausted in " .. dir)
                return
            end
            local full = dir .. "/" .. name
            if name:sub(-4) == ".app" then
                found[#found + 1] = {
                    name = name:sub(1, -5), path = full, label = label,
                }
            elseif depth > 0 and isDir(full) then
                appsIn(full, label, depth - 1, found, deadline)
            end
        end
    end

    -- ---- the scan --------------------------------------------------------
    function launcher.scan(force)
        local now = epoch()
        if not force and launcher.cache
           and (now - launcher.cacheAt) < launcher.cacheSecs then
            return launcher.cache
        end

        local t0, found = now, {}
        local deadline = t0 + launcher.scanBudget
        for _, d in ipairs(launcher.dirs) do
            appsIn(d.path, d.label, 1, found, deadline)
        end
        for _, p in ipairs(launcher.extraDirs) do
            local label = p:gsub("^" .. home:gsub("%p", "%%%0"), "~")
            appsIn(p, label, 1, found, deadline)
        end

        -- Sorted by name; the same name from two folders keeps the
        -- launcher.dirs order, so /Applications outranks ~/Applications
        -- for ties — both rows show, labelled, and the common one is first.
        local rank = {}
        for i, d in ipairs(launcher.dirs) do rank[d.label] = i end
        table.sort(found, function(a, b)
            local an, bn = a.name:lower(), b.name:lower()
            if an ~= bn then return an < bn end
            return (rank[a.label] or 99) < (rank[b.label] or 99)
        end)

        launcher.lastScanMs = (epoch() - t0) * 1000
        launcher.cache, launcher.cacheAt = found, epoch()
        say(string.format("%d apps in %.0fms", #found, launcher.lastScanMs))
        return found
    end

    -- Installing or deleting an app drops the cache, so ⇪D right after an
    -- install already knows. Watchers start in warm(), off the boot path.
    launcher.watchers = {}
    local function watch()
        for _, d in ipairs(launcher.dirs) do
            pcall(function()
                local w = hs.pathwatcher.new(d.path, function()
                    launcher.cache = nil
                end)
                if w then
                    w:start()
                    launcher.watchers[#launcher.watchers + 1] = w
                end
            end)
        end
    end

    -- ---- launching one ---------------------------------------------------
    -- launchOrFocus does both halves of the promise in one call and takes
    -- a full path, so two same-named apps in different folders stay two
    -- different targets. hs.open is the Finder's double-click — the
    -- fallback for the odd bundle launchOrFocus turns its nose up at.
    function launcher.launch(entry)
        if not (entry and entry.path) then return false end
        local ok, res = pcall(function()
            return hs.application.launchOrFocus(entry.path)
        end)
        if ok and res then
            say("launched " .. entry.path)
            return true
        end
        local ok2, res2 = pcall(function() return hs.open(entry.path) end)
        if ok2 and res2 then
            say("opened " .. entry.path .. " via hs.open")
            return true
        end
        hs.alert.show("🚀 " .. (entry.name or "That app") .. " would not launch")
        warn((entry.name or entry.path) .. ": launchOrFocus and hs.open both refused")
        return false
    end

    -- ---- files behind the apps (6.96.0) ----------------------------------
    -- One function answers "what rows does this query deserve": matching
    -- app rows first (every word a substring of the name), then the
    -- index's best files, 📄-labelled. Exposed on launcher for the test
    -- suite, and only ever called when the index module is loaded — an
    -- apps-only Mac keeps the chooser's native filter untouched.
    function launcher.rowsFor(query)
        local all = launcher.currentChoices or {}
        local q = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if q == "" then return all end
        local toks = {}
        for w in q:gmatch("%S+") do toks[#toks + 1] = w end
        local out = {}
        for _, row in ipairs(all) do
            local name, hit = row.text:lower(), true
            for _, w in ipairs(toks) do
                if not name:find(w, 1, true) then hit = false ; break end
            end
            if hit then out[#out + 1] = row end
        end
        local fi = _G.fileIndex
        if launcher.files and fi and type(fi.search) == "function" then
            local okS, hits = pcall(fi.search, q, launcher.fileRows)
            if okS and type(hits) == "table" then
                for _, h in ipairs(hits) do
                    out[#out + 1] = { text = h.name, subText = "📄 " .. h.dir,
                                      path = h.path, kind = "file" }
                end
            end
        end
        return out
    end

    -- ---- the picker ------------------------------------------------------
    launcher.chooser = nil    -- HELD: an unreferenced hs.chooser is collected
    local iconCache = {}      -- path → hs.image, kept across shows

    function launcher.show()
        if not launcher.enabled then return end
        local apps = launcher.scan(false)
        if #apps == 0 then
            hs.alert.show("🚀 No applications found — check launcher.dirs "
                .. "in app_launcher.lua", 4)
            return
        end

        local iconStop = epoch() + launcher.iconBudget
        local choices = {}
        for _, e in ipairs(apps) do
            local row = { text = e.name, subText = e.label, path = e.path }
            if launcher.icons and epoch() < iconStop then
                if iconCache[e.path] == nil then
                    local okI, img = pcall(function()
                        return hs.image.iconForFile(e.path)
                    end)
                    iconCache[e.path] = (okI and img) or false
                end
                if iconCache[e.path] then row.image = iconCache[e.path] end
            end
            choices[#choices + 1] = row
        end

        if not launcher.chooser then
            launcher.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                if pick.kind == "file" then
                    -- ⏎ on a file row: the Finder double-click, by path.
                    local okO, res = pcall(function() return hs.open(pick.path) end)
                    if not (okO and res) then
                        hs.alert.show("📄 " .. (pick.text or "That file")
                            .. " would not open")
                        warn((pick.path or "?") .. ": hs.open refused")
                    end
                    return
                end
                launcher.launch({ name = pick.text, path = pick.path })
            end)
            -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it BEFORE the
            -- cheat sheet (the router only sees that registry)
            _G.choosers = _G.choosers or {}
            _G.choosers.appLauncher = launcher.chooser
            -- subText is a folder path; matching on it would make "app"
            -- hit every row, so the filter reads names only (the default,
            -- stated here so nobody "fixes" it to true without reading this)
            pcall(function()
                launcher.chooser:searchSubText(false)
                launcher.chooser:width(30)
            end)
            -- 🗂 6.96.0: with the index module loaded, WE become the
            -- filter (the chooser's own cannot append rows it was never
            -- given). Installed once, only when there is an index to ask.
            if launcher.files and type(_G.fileIndex) == "table" then
                pcall(function()
                    launcher.chooser:queryChangedCallback(function(q)
                        local okR, rows = pcall(launcher.rowsFor, q)
                        if okR and rows then launcher.chooser:choices(rows) end
                    end)
                end)
            end
        end
        launcher.currentChoices = choices
        launcher.chooser:choices(choices)
        -- A query kept from last time must keep filtering: the native
        -- filter would have; ours has to be re-asked once on reopen.
        pcall(function()
            local q = launcher.chooser:query()
            if type(q) == "string" and q ~= ""
               and launcher.files and type(_G.fileIndex) == "table" then
                launcher.chooser:choices(launcher.rowsFor(q))
            end
        end)
        local hint = (launcher.files and type(_G.fileIndex) == "table")
                     and " apps + your files — type, ⏎ launches or opens"
                     or  " apps — type, ⏎ launches"
        launcher.chooser:placeholderText(#apps .. hint)
        launcher.chooser:show()
    end

    function _G.appLauncherReport()
        local apps = launcher.scan(true) or {}
        local byLabel, labels = {}, {}
        for _, e in ipairs(apps) do
            if not byLabel[e.label] then
                byLabel[e.label] = 0 ; labels[#labels + 1] = e.label
            end
            byLabel[e.label] = byLabel[e.label] + 1
        end
        local L = { string.format("🚀 APP LAUNCHER on %s — %d apps in %.0fms",
                    tostring(core.hostTag), #apps, launcher.lastScanMs) }
        for _, lab in ipairs(labels) do
            L[#L + 1] = string.format("   %-24s %d", lab, byLabel[lab])
        end
        for _, e in ipairs(apps) do
            L[#L + 1] = string.format("   %-32s %s", e.name, e.label)
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if launcher.enabled then
        core.hyperAddShortcut({}, launcher.key, launcher.show, "app launcher")
    end

    core.provide("appLauncher.show",   function() return launcher.show()      end)
    core.provide("appLauncher.list",   function() return launcher.scan(false) end)
    core.provide("appLauncher.report", function() return _G.appLauncherReport() end)

    -- Off the boot path on purpose: the first scan and the pathwatchers
    -- both belong to the warm phase, so ⇪D's first press is instant and a
    -- slow folder cannot slow the boot.
    M.warm = function()
        watch()
        launcher.scan(true)
    end

    _G.appLauncher = launcher
    M.launcher = launcher
    M.config   = launcher
end

return M
