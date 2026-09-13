-- =====================================================================
-- 1.12 MODULE LOADER — sections live in their own files from here on
-- =====================================================================
-- A section that has been moved out lives in ~/.hammerspoon/modules/
-- <name>.lua and is named in a MACHINE PROFILE below. Everything not yet
-- moved still lives in this file and works exactly as before; the two
-- styles coexist deliberately, so the move happens a few sections at a
-- time rather than as one all-or-nothing rewrite.
--
-- WHY THIS MATTERS MORE THAN TIDINESS: Lua's limit of 200 locals is PER
-- CHUNK, and a file is a chunk. This file was measured at exactly 200
-- with ZERO headroom in 6.35.0 — the next top-level `local` added
-- anywhere would have been a compile error taking the WHOLE config down.
-- Every module file gets its own fresh 200.
--
-- ⚠️ MODULES LOAD FROM LOCAL DISK, NOT FROM ONEDRIVE — DELIBERATELY.
-- Loading them straight from the cloud folder would be one fewer copy
-- step, and it is the wrong trade: OneDrive's Files-On-Demand can leave
-- a file as an online-only placeholder, and READING one triggers a
-- synchronous download. In the boot path that is a main-thread stall at
-- every login on a slow network — the same failure shape as the ⌥Tab
-- freeze in 6.33.0, which is not a mistake worth making twice. The
-- master copies live in OneDrive for durability and for copying to
-- another Mac; the loader only ever reads local disk.
--
-- ---------------------------------------------------------------------
-- THE MODULE CONTRACT, in full:
--
--   return {
--     name  = "App Peek",            -- shown in the boot report
--     order = 7,                     -- its slot in the cheat sheet
--     cheatsheet = {                 -- travels WITH the module
--       title = "👀 APP PEEK",
--       entries = { { "⇪P", "Hide the frontmost app" } },
--     },
--     config = someTable,            -- OPTIONAL: settings a machine
--                                    -- profile may override
--     setup = function(core) ... end,-- REQUIRED: binds keys, cheap work
--   }
--
-- setup() may also assign M.warm = function(core) ... end before it
-- returns. See the two-phase note below.
-- ---------------------------------------------------------------------
--
-- ⏱ TWO PHASES: setup() THEN warm(). 6.40.0.
-- setup() runs during boot and must stay CHEAP — bind hotkeys, create
-- objects, nothing that touches a big file. Anything expensive goes in
-- warm(), which the loader runs a couple of seconds AFTER boot on a
-- stored timer. Autocorrect is the case that motivated it: parsing an
-- 11,000-row CSV was happening on the boot path, and a hotkey you cannot
-- press yet because the Mac is still starting is worth nothing. Now the
-- keys bind instantly and the dictionary arrives a moment later. The
-- Console and ⇪⇧D both show warm timings separately from setup timings,
-- so you can see exactly where the time goes.
--
-- FAILURE IS ISOLATED, which is the other half of the point. Every
-- module is loaded, executed, set up AND warmed inside its own pcall. A
-- syntax error in one module costs you that module — not your hotkeys,
-- not autocorrect, not the whole config. Before this, one bad line
-- anywhere meant NOTHING loaded. Failures are named in the Console,
-- counted in the boot report, listed in ⇪⇧D, and shown as a ⚠️ group at
-- the top of the cheat sheet so a missing feature is never a mystery.
_G.moduleDir         = hs.configdir .. "/modules"
_G.moduleStatus      = {}    -- one record per module, for the report
_G.moduleCheatsheets = {}    -- groups contributed by loaded modules
_G.moduleWarmTimers  = {}    -- HELD: an unreferenced hs.timer is collected

-- =====================================================================
-- ✏️ MACHINE PROFILES — WHICH MODULES RUN ON WHICH MAC
-- =====================================================================
-- The same init.lua and the same modules/ folder go on every Mac you
-- own; this table is the only thing that differs between them, and it
-- lives in the file rather than in per-machine edits so the two Macs
-- can never drift apart silently.
--
-- Keyed by the machine's ComputerName, which §0.1 already resolved into
-- hostTag — the same name that tags your log files. An unknown machine
-- (a new Mac, or one whose name changed) falls back to `default` and
-- says so in the boot report rather than loading nothing.
--
-- `modules`  = which module files to load, in load order.
-- `settings` = per-module overrides applied to that module's `config`
--              table after setup. Anything the module exposes there can
--              differ per machine without touching the module file.
_G.moduleProfiles = {
    -- ---- personal Mac: everything on -------------------------------
    ["Lees-MacBook-Air"] = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments",
            -- 6.44.0
            "screen_veil", "mini_calendar", "quick_append", "capture_pad",
            "numpad_layer",
        },
    },

    -- ---- work Mac -------------------------------------------------
    -- ✏️ PUT YOUR WORK MACHINE'S NAME HERE. Find it by running
    --      scutil --get ComputerName
    -- on that Mac, or just read the 🧭 PORTABILITY REPORT line at the
    -- top of its Hammerspoon Console — it prints the same name.
    -- Until you do, the work Mac uses `default` below, which loads
    -- everything; nothing breaks either way.
    ["Lees-Work-MacBook"] = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments",
            -- 6.44.0
            "screen_veil", "mini_calendar", "quick_append", "capture_pad",
            "numpad_layer",
        },
        settings = {
            -- Examples — delete or edit freely. These are exactly the
            -- knobs a work Mac tends to want different:
            window_switcher = {
                -- A work Mac with a lot of corporate agents running can
                -- make the cross-Space sweep slower; lower the cap or
                -- turn Spaces off here rather than editing the module.
                maxWindows = 24,
            },
        },
    },

    -- ---- any other Mac --------------------------------------------
    default = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments",
            -- 6.44.0
            "screen_veil", "mini_calendar", "quick_append", "capture_pad",
            "numpad_layer",
        },
    },
}

_G.moduleWarmDelay = 2.0   -- seconds after boot before warm() runs

-- The shared surface. This is the ONLY thing modules may depend on, and
-- keeping it explicit is what stops the coupling growing back: anything
-- not listed here is private to this file.
local core = {
    version     = _G.configVersion,
    -- paths (§0.1 portability layer)
    homeDir     = homeDir,     cloudDir  = cloudDir,
    logsDir     = logsDir,     backupDir = backupDir,
    hostTag     = hostTag,     configDir = hs.configdir,
    -- file helpers (§0.1 / §3.6)
    warnWriteFailed = warnWriteFailed,
    adoptLegacyFile = adoptLegacyFile,
    csvQuote        = csvQuote,
    splitCSVLine    = splitCSVLine,
    formatDuration  = formatDuration,
    -- popups & screens (§1.5)
    popupKeys        = popupScreenKeys,
    popupMods        = popupScreenKeys.mods,
    showPopup        = showPopup,
    resolveBaseScreen = resolveBaseScreen,
    panelAlpha       = panelAlpha,
    -- hyper keyspace (§3.12) — the supported way for a module to claim a
    -- ⇪ shortcut. Wrapped rather than captured, so it resolves at call
    -- time and this table stays honest if §3.12 ever moves.
    hyperAddShortcut = function(...) return _G.hyperAddShortcut(...) end,
    -- credentials (§0.2) — nil when secret.lua is absent, by design
    asanaEnabled     = asanaEnabled,
    asanaToken       = asanaToken,
    asanaWorkspaceId = asanaWorkspaceId,
    -- service registry (see the stub at the top of this file). A module
    -- publishes with core.provide("name", fn); anything else calls it
    -- with _G.service.call("name", ...) and gets a warning rather than a
    -- crash if the module is missing.
    provide  = function(name, fn) _G.service.provide(name, fn) end,
    call     = function(name, ...) return _G.service.call(name, ...) end,
    -- diagnostics (§1.11)
    diag     = _G.diag,
    safeJson = _G.safeJson,
}
_G.core = core   -- so a module author can inspect it from the Console

-- Load one module. Returns a status record; never throws, whatever the
-- module does.
local function loadOneModule(name, settings)
    local path = _G.moduleDir .. "/" .. name .. ".lua"
    local rec  = { name = name, path = path, ok = false, ms = 0 }
    local t0   = hs.timer.secondsSinceEpoch()

    -- loadfile REPORTS a syntax error rather than raising it, so this
    -- distinguishes "file missing" from "file broken" — two very
    -- different things to see in a boot report.
    local chunk, loadErr = loadfile(path)
    if not chunk then
        rec.err = (hs.fs.attributes(path) == nil)
                  and "not found at " .. path
                  or  ("syntax error — " .. tostring(loadErr))
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end

    local okRun, mod = pcall(chunk)
    if not okRun then
        rec.err = "failed while loading — " .. tostring(mod)
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end
    -- Validate the contract before trusting it: a module that returns
    -- nothing (a forgotten `return M`) would otherwise fail later, in a
    -- place with no obvious connection to the real mistake. This check
    -- has already earned its keep once — it caught a do...end block
    -- split across the new function boundary in 6.37.0.
    if type(mod) ~= "table" or type(mod.setup) ~= "function" then
        rec.err = "does not return a table with a setup() function"
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end

    -- 🔌 6.114.0 — NAME THE MODULE WHILE IT IS PUBLISHING. _G.service.provide
    -- reads this to record an owner per service. A global rather than a
    -- per-module `core` table on purpose: `core` is built ONCE and shared by
    -- every module, and cloning it per module to carry one string would
    -- copy a large table thirty times at boot for a field only the registry
    -- reads. Cleared straight after, so anything publishing outside a
    -- setup() is honestly recorded as init.lua rather than blamed on
    -- whichever module happened to load last.
    _G.moduleLoading = mod.name or name
    local okSetup, setupErr = pcall(mod.setup, core)
    _G.moduleLoading = nil
    rec.ms = (hs.timer.secondsSinceEpoch() - t0) * 1000
    if not okSetup then
        rec.err = "setup() failed — " .. tostring(setupErr)
        return rec
    end

    -- Machine-profile overrides, applied AFTER setup so the module's own
    -- defaults exist to be overridden.
    if settings and type(mod.config) == "table" then
        local applied = {}
        for k, v in pairs(settings) do
            mod.config[k] = v
            table.insert(applied, k)
        end
        if #applied > 0 then
            rec.overrides = table.concat(applied, ", ")
            _G.diag.say("module", name .. " profile overrides: " .. rec.overrides)
        end
    end

    rec.ok      = true
    rec.title   = mod.name or name
    rec.module  = mod
    -- The cheat sheet group is registered only after setup SUCCEEDS, so
    -- the sheet can never advertise a shortcut that was never bound.
    -- ⚠️ KEEP IN LOCKSTEP WITH init.lua §1.12. This file is a copy of the
    -- real loader so the module system can be driven from `lua` with no
    -- Hammerspoon; a copy that drifts tests a loader nobody ships. 6.101.0
    -- changed three things here — families, several groups per module, and
    -- a slot per GROUP — and test_tools asserts the two blocks agree.
    local cs     = mod.cheatsheet
    local groups = nil
    if type(cs) == "table" then groups = cs.title and { cs } or cs end
    if (not groups or #groups == 0) and mod.family == "auto" then
        groups = { { title = mod.name or name, entries = {} } }
    end
    for gi, g in ipairs(groups or {}) do
        if type(g) == "table" and g.title then
            table.insert(_G.moduleCheatsheets, {
                title   = g.title,
                entries = g.entries or {},
                order   = (mod.order or 500) + (gi - 1) / 1000,
                family  = g.family  or mod.family,
                summary = g.summary or mod.summary,
                source  = mod.name  or name,
            })
        end
    end
    return rec
end

-- Phase two. Scheduled, never inline: the whole point is that this work
-- is NOT on the boot path.
local function scheduleWarm(rec)
    local mod = rec.module
    if not (mod and type(mod.warm) == "function") then return end
    local delay = mod.warmAfter or _G.moduleWarmDelay
    local timer = hs.timer.doAfter(delay, function()
        local t0 = hs.timer.secondsSinceEpoch()
        local ok, err = pcall(mod.warm, core)
        rec.warmMs = (hs.timer.secondsSinceEpoch() - t0) * 1000
        if ok then
            rec.warmed = true
            _G.diag.say("module", string.format("%s warmed in %.0fms", rec.name, rec.warmMs))
        else
            rec.warmed = false
            rec.warmErr = tostring(err)
            print("🧩 MODULE WARM-UP FAILED — " .. rec.name .. ": " .. rec.warmErr)
            _G.diag.warn("module", rec.name .. " warm() — " .. rec.warmErr)
        end
    end)
    -- HELD. An unreferenced hs.timer is garbage-collected and silently
    -- never fires — that is exactly how 6.33.0 lost its warm-up.
    table.insert(_G.moduleWarmTimers, timer)
    rec.warmPending = true
end

-- Load every module in the given order. Order is EXPLICIT rather than a
-- directory scan: boot behaviour should not depend on how the filesystem
-- happens to sort names, and a stray file dropped in the folder must
-- never execute itself.
function _G.loadModules(list, settingsByModule)
    local loaded, failed = 0, 0
    for _, name in ipairs(list) do
        local rec = loadOneModule(name, settingsByModule and settingsByModule[name])
        table.insert(_G.moduleStatus, rec)
        if rec.ok then
            loaded = loaded + 1
            _G.diag.say("module", string.format("%s loaded in %.0fms", rec.name, rec.ms))
            scheduleWarm(rec)
        else
            failed = failed + 1
            print("🧩 MODULE FAILED — " .. rec.name .. ": " .. tostring(rec.err))
            _G.diag.warn("module", rec.name .. " — " .. tostring(rec.err))
        end
    end
    _G.diag.mark("§1.12 modules loaded")
    _G.moduleLoaded, _G.moduleFailed = loaded, failed
    return loaded, failed
end

-- Pick this machine's profile and run it.
_G.moduleProfileName = _G.moduleProfiles[hostTag] and hostTag or "default"
do
    local profile = _G.moduleProfiles[_G.moduleProfileName]
    _G.loadModules(profile.modules, profile.settings)
end

