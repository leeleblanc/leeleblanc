-- =====================================================================
-- MODULE: WORKSPACES (⇪W) — name a set of apps, bind it to a Space
-- =====================================================================
-- A workspace is a named list of applications plus two optional shell
-- hooks. ⇪W asks which workspace this Space should be, remembers the
-- answer, and sets it up: run onStart, open the apps, wait for them to
-- actually appear, run onComplete. Press ⇪W on that Space again and the
-- first row offers to re-apply what is already assigned.
--
-- ---------------------------------------------------------------------
-- ✏️ THE FORMAT, WHICH IS THE ONE YOU ASKED FOR
-- ---------------------------------------------------------------------
--   ws.workspaces = {
--       DevWork = {
--           onStart      = "~/.something/command.sh",
--           Applications = { ["Google Chrome"] = {} },
--           onComplete   = "~/.something/command.sh",
--       },
--   }
--
-- ⚠️ THOSE COMMAS ARE NOT OPTIONAL. Lua separates table fields with `,`
-- or `;`, so the version without them is a SYNTAX ERROR and the module
-- will not load at all — the loader will name the file and the line.
-- Worth stating because the layout reads perfectly well without them.
--
-- The `{}` after each app is where per-app options go. Today one is
-- supported, and an empty table means "just open it":
--       ["Google Chrome"] = { zone = "leftHalf" }
-- Zones are the same names the numpad layer uses: topLeft, topHalf,
-- topRight, leftHalf, centre, rightHalf, bottomLeft, bottomHalf,
-- bottomRight, full.
--
-- ---------------------------------------------------------------------
-- 🚨 WHAT "BOUND TO A SPACE" CAN AND CANNOT MEAN
-- ---------------------------------------------------------------------
-- macOS gives no public API for Spaces at all. hs.spaces exists and
-- works, but it drives PRIVATE system calls, and one consequence leaks
-- straight into this feature:
--
--   SPACE IDs ARE NOT STABLE ACROSS LOGOUTS. The number identifying
--   "Space 2" today is a different number tomorrow. A saved mapping of
--   space → workspace therefore goes stale on every reboot, and if it
--   were trusted blindly it would silently apply the wrong workspace to
--   the wrong Space, which is worse than forgetting.
--
-- So the store is PRUNED against the Spaces that actually exist every
-- time it is read, and an ID that no longer exists is dropped rather
-- than guessed at. See pruneStore(). If hs.spaces is missing entirely
-- (an older Hammerspoon), the module still works — it just cannot tell
-- Spaces apart, says so once, and treats the Mac as one Space.
--
-- ---------------------------------------------------------------------
-- ⚠️ THE HOOKS RUN REAL SHELL COMMANDS
-- ---------------------------------------------------------------------
-- onStart and onComplete are your own commands from your own config, run
-- as you, so the risk is the same as typing them — but two rules make
-- them safe to have on a hotkey:
--   · THEY GO THROUGH hs.task, NEVER hs.execute. hs.execute blocks the
--     main thread, and the main thread is your keyboard. A hook that
--     hangs must cost you nothing.
--   · A HOOK THAT FAILS IS REPORTED AND THE WORKSPACE STILL OPENS. A
--     workspace that silently does nothing because a script moved is the
--     worst outcome; the apps are the point, so they still arrive and
--     the failure is named. Set ws.stopOnHookFailure = true to abort
--     instead, if a hook is a genuine prerequisite.
--
-- ---------------------------------------------------------------------
-- 🅿️ ⇪⇧W WAS ALREADY TAKEN
-- ---------------------------------------------------------------------
-- The spec asked for "secondary + W" to reset the Space. ⇪⇧W already
-- opens the Document Watcher list, and quietly stealing a working
-- shortcut is not a trade worth making silently. So RESET LIVES ON THE
-- FIRST ROW of the ⇪W picker whenever this Space already has a
-- workspace, and is also published as workspace.reset — so it can go on
-- one of the free number-pad keys any time you want it:
--       numpad.actions["pad+"] = "workspace.reset"

local M = {
    name  = "Workspaces",
    order = 14.2,
    cheatsheet = {
        title = "🗂 WORKSPACES (⇪⇧S — Spaces: a named set of apps per Space)",
        entries = {
            { "⇪⇧S",     "Pick a workspace for this Space, remember it, set it up" },
            { "⇪⇧S again","First row re-applies what this Space is already set to" },
            { "does",    "onStart → open the apps → wait for them → onComplete" },
            { "shell",   "Hooks run via hs.task, never blocking the keyboard" },
            { "define",  "ws.workspaces at the top of modules/workspaces.lua" },
            { "spaces",  "Space IDs change on logout, so stale bindings are DROPPED" },
            { "",        "rather than guessed at — a wrong Space is worse than none" },
            { "reset",   "Also published as workspace.reset for a free pad key" },
        },
    },
}

function M.setup(core)
    local ws = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ws.enabled       = true
    -- 🚨 ⇪⇧S FOR "SPACES", NOT ⇪W. ⇪W was already the SUMMON-AN-APP
    -- picker, reached through §0.4's migration of ⌃⌥W, and ⇪⇧W is the
    -- Document Watcher. Claiming ⇪W printed one HYPER CONFLICT line and
    -- silently killed a working shortcut — new code yields.
    ws.key           = "s"
    ws.mods          = { "shift" }   -- ⇪⇧S
    ws.settleSecs    = 8        -- how long to wait for apps before onComplete
    ws.pollSecs      = 0.25     -- how often to check whether they have arrived
    ws.hookTimeout   = 30       -- a hook still running after this is abandoned
    ws.stopOnHookFailure = false
    ws.store         = (core.logsDir or "/tmp")
                       .. "/workspaces-" .. tostring(core.hostTag or "mac") .. ".json"

    -- ✏️ YOUR WORKSPACES GO HERE. See the header for the format, and mind
    -- the commas. Applications is a table keyed by the app's name exactly
    -- as it appears in /Applications.
    ws.workspaces = {
        DevWork = {
            Applications = {
                ["Google Chrome"] = {},
            },
        },
    }
    -- ----------------------------------------------------------------------

    ws.assigned = {}        -- spaceId -> workspace name
    ws.busy     = false     -- one apply at a time
    ws.timers   = {}        -- HELD: unreferenced hs.timers are collected
    ws.tasks    = {}        -- HELD: likewise for hs.task
    ws.lastRun  = nil
    ws.warned   = false

    local function say(m)  if _G.diag then _G.diag.say("workspaces", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("workspaces", m) end end

    -- ---- Spaces, defensively ---------------------------------------------
    function ws.spacesOK()
        return type(hs.spaces) == "table"
               and type(hs.spaces.focusedSpace) == "function"
    end

    -- The key a workspace is remembered against. When hs.spaces is absent
    -- every Space looks the same, so the whole Mac becomes one bucket —
    -- degraded, but honest and still useful.
    function ws.currentSpace()
        if not ws.spacesOK() then return "no-spaces-api" end
        local ok, id = pcall(hs.spaces.focusedSpace)
        if ok and id then return tostring(id) end
        return "unknown-space"
    end

    -- 🚨 PRUNE BEFORE TRUSTING. A space ID from a previous login may now
    -- belong to a DIFFERENT Space, so applying its workspace would set up
    -- the wrong desktop. Anything the system no longer lists is dropped.
    function ws.pruneStore(store)
        if not ws.spacesOK() then return store, 0 end
        local ok, all = pcall(hs.spaces.allSpaces)
        if not ok or type(all) ~= "table" then return store, 0 end
        local live = {}
        for _, ids in pairs(all) do
            if type(ids) == "table" then
                for _, id in ipairs(ids) do live[tostring(id)] = true end
            end
        end
        -- An empty answer means the API told us nothing, not that every
        -- Space vanished. Dropping the whole store on that would be a
        -- self-inflicted wipe.
        if next(live) == nil then return store, 0 end
        local pruned, dropped = {}, 0
        for id, name in pairs(store) do
            if live[id] then pruned[id] = name else dropped = dropped + 1 end
        end
        return pruned, dropped
    end

    -- ---- persistence ------------------------------------------------------
    function ws.load()
        local f = io.open(ws.store, "r")
        if not f then ws.assigned = {} return end
        local raw = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, raw)
        if not ok or type(data) ~= "table" then
            warn("the workspace store was unreadable; starting empty")
            ws.assigned = {}
            return
        end
        local pruned, dropped = ws.pruneStore(data)
        ws.assigned = pruned
        if dropped > 0 then
            say(dropped .. " stale Space binding(s) dropped — IDs change on logout")
            ws.save()
        end
    end

    function ws.save()
        local ok, enc = pcall(hs.json.encode, ws.assigned)
        if not ok then return false end
        local f = io.open(ws.store, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed(ws.store) end
            return false
        end
        f:write(enc); f:close()
        return true
    end

    -- ---- validation -------------------------------------------------------
    -- Run before anything is launched. A typo in a key name is the most
    -- likely mistake in a hand-edited table, and finding out by watching
    -- nothing happen is a bad way to learn about it.
    local KNOWN = { onStart = true, Applications = true, onComplete = true }

    function ws.validate(name, def)
        local problems = {}
        if type(def) ~= "table" then
            return { tostring(name) .. " is not a table" }
        end
        for k in pairs(def) do
            if not KNOWN[k] then
                problems[#problems + 1] = "unknown key '" .. tostring(k)
                    .. "' (expected onStart, Applications, onComplete)"
            end
        end
        if def.Applications ~= nil and type(def.Applications) ~= "table" then
            problems[#problems + 1] = "Applications must be a table"
        end
        for _, hook in ipairs({ "onStart", "onComplete" }) do
            if def[hook] ~= nil and type(def[hook]) ~= "string" then
                problems[#problems + 1] = hook .. " must be a string path"
            end
        end
        -- 🚨 THE TYPE CHECK GUARDS THE LOOP. Recording "Applications must
        -- be a table" and then iterating it anyway throws on exactly the
        -- input the check just caught — so the validator crashed instead
        -- of reporting, which is the one thing a validator must not do.
        if type(def.Applications) == "table" then
            for appName, opts in pairs(def.Applications) do
                if type(appName) ~= "string" then
                    problems[#problems + 1] = "an application key is not a string"
                end
                if opts ~= nil and type(opts) ~= "table" then
                    problems[#problems + 1] = tostring(appName)
                        .. "'s options must be a table (use {} for none)"
                end
            end
        end
        return problems
    end

    -- ---- shell hooks ------------------------------------------------------
    -- `~` is expanded here rather than left to the shell, because the
    -- string may be a bare path with no shell metacharacters and we want
    -- it to work either way.
    function ws.expandPath(p)
        if type(p) ~= "string" then return p end
        local home = os.getenv("HOME") or "~"
        return (p:gsub("^~", home))
    end

    -- Runs cmd, then calls done(ok). NEVER blocks: hs.task is asynchronous,
    -- and a hook still running after hookTimeout is abandoned so the rest
    -- of the workspace is not held hostage to it.
    function ws.runHook(cmd, label, done)
        if cmd == nil or cmd == "" then done(true) return end
        local full = ws.expandPath(cmd)
        local finished = false
        local function finish(ok, why)
            if finished then return end
            finished = true
            if not ok then warn(label .. " failed: " .. tostring(why)) end
            done(ok)
        end
        local okNew, task = pcall(function()
            return hs.task.new("/bin/zsh", function(code, _, stderr)
                if code == 0 then finish(true)
                else finish(false, "exit " .. tostring(code) .. " " .. tostring(stderr)) end
            end, { "-c", full })
        end)
        if not (okNew and task) then finish(false, "could not create the task") return end
        ws.tasks[#ws.tasks + 1] = task
        local okStart = pcall(function() return task:start() end)
        if not okStart then finish(false, "could not start") return end
        -- ⏱ The abandon timer. Without it a hook that never exits leaves
        -- the workspace half-applied and ws.busy stuck true forever.
        local t = hs.timer.doAfter(ws.hookTimeout, function()
            pcall(function() task:terminate() end)
            finish(false, "still running after " .. ws.hookTimeout .. "s")
        end)
        ws.timers[#ws.timers + 1] = t
    end

    -- ---- launching --------------------------------------------------------
    function ws.launchAll(def)
        local wanted, failed = {}, {}
        for appName in pairs(def.Applications or {}) do
            wanted[#wanted + 1] = appName
            local ok, res = pcall(hs.application.launchOrFocus, appName)
            if not ok or res == false then failed[#failed + 1] = appName end
        end
        table.sort(wanted); table.sort(failed)
        return wanted, failed
    end

    local ZONES = {
        topLeft = { 0, 0, 0.5, 0.5 },      topHalf = { 0, 0, 1.0, 0.5 },
        topRight = { 0.5, 0, 0.5, 0.5 },   leftHalf = { 0, 0, 0.5, 1.0 },
        centre = { 0.15, 0.10, 0.70, 0.80 },
        rightHalf = { 0.5, 0, 0.5, 1.0 },  bottomLeft = { 0, 0.5, 0.5, 0.5 },
        bottomHalf = { 0, 0.5, 1.0, 0.5 }, bottomRight = { 0.5, 0.5, 0.5, 0.5 },
        full = { 0, 0, 1.0, 1.0 },
    }

    -- Best-effort placement, once an app's window exists. Never fatal: a
    -- window that has not appeared yet simply does not get moved.
    function ws.placeApp(appName, zoneName)
        local frac = ZONES[zoneName]
        if not frac then return false end
        local app = hs.application.get(appName)
        if not app then return false end
        local okW, win = pcall(function() return app:mainWindow() end)
        if not (okW and win) then return false end
        local okS, scr = pcall(function() return win:screen() end)
        if not (okS and scr) then return false end
        local okF, sf = pcall(function() return scr:frame() end)
        if not (okF and sf) then return false end
        return (pcall(function()
            win:setFrame({ x = sf.x + sf.w * frac[1], y = sf.y + sf.h * frac[2],
                           w = sf.w * frac[3], h = sf.h * frac[4] }, 0)
        end))
    end

    -- ---- the apply chain --------------------------------------------------
    -- onStart → launch → settle → place → onComplete. Each step hands to
    -- the next by callback, so nothing blocks and the order still holds.
    function ws.apply(name, onDone)
        onDone = onDone or function() end
        local def = ws.workspaces[name]
        if not def then
            hs.alert.show("🗂 No workspace called " .. tostring(name))
            onDone(false) ; return false
        end
        if ws.busy then
            hs.alert.show("🗂 Already setting a workspace up")
            onDone(false) ; return false
        end
        local problems = ws.validate(name, def)
        if #problems > 0 then
            hs.alert.show("🗂 " .. name .. " is misconfigured:\n" .. problems[1], 5)
            warn(name .. ": " .. table.concat(problems, "; "))
            onDone(false) ; return false
        end

        ws.busy = true
        local result = { name = name, failed = {}, hookFailed = {} }

        -- 🚨 EVERY EXIT GOES THROUGH HERE. ws.busy sticking true would
        -- wedge the feature until a reload, so there is exactly one place
        -- that clears it and every path ends at it.
        local function finish(ok)
            ws.busy = false
            ws.lastRun = result
            local msg = "🗂 " .. name
            if #result.failed > 0 then
                msg = msg .. "\n⚠️ would not open: " .. table.concat(result.failed, ", ")
            end
            if #result.hookFailed > 0 then
                msg = msg .. "\n⚠️ hook failed: " .. table.concat(result.hookFailed, ", ")
            end
            hs.alert.show(msg, #result.failed + #result.hookFailed > 0 and 4 or 2)
            say(string.format("%s applied — %d app(s), %d failed, %d hook failure(s)",
                name, #(result.wanted or {}), #result.failed, #result.hookFailed))
            onDone(ok)
        end

        ws.runHook(def.onStart, name .. " onStart", function(startOK)
            if not startOK then
                result.hookFailed[#result.hookFailed + 1] = "onStart"
                if ws.stopOnHookFailure then finish(false) return end
            end

            local wanted, failed = ws.launchAll(def)
            result.wanted, result.failed = wanted, failed

            -- Settle: poll until every app that launched is actually
            -- running, or the budget runs out. onComplete means "the apps
            -- are up", and firing it immediately after launchOrFocus would
            -- be a lie — the apps are not up yet.
            local waited = 0
            local function afterSettle()
                for appName, opts in pairs(def.Applications or {}) do
                    if type(opts) == "table" and opts.zone then
                        pcall(ws.placeApp, appName, opts.zone)
                    end
                end
                ws.runHook(def.onComplete, name .. " onComplete", function(doneOK)
                    if not doneOK then
                        result.hookFailed[#result.hookFailed + 1] = "onComplete"
                    end
                    finish(true)
                end)
            end

            local function poll()
                waited = waited + ws.pollSecs
                local allUp = true
                for _, appName in ipairs(wanted) do
                    local isFailed = false
                    for _, f in ipairs(failed) do if f == appName then isFailed = true end end
                    if not isFailed and not hs.application.get(appName) then
                        allUp = false ; break
                    end
                end
                if allUp or waited >= ws.settleSecs then
                    if not allUp then
                        say("gave up waiting for apps after " .. ws.settleSecs .. "s")
                    end
                    afterSettle()
                else
                    local t = hs.timer.doAfter(ws.pollSecs, poll)
                    ws.timers[#ws.timers + 1] = t
                end
            end

            if #wanted == 0 then afterSettle()
            else
                local t = hs.timer.doAfter(ws.pollSecs, poll)
                ws.timers[#ws.timers + 1] = t
            end
        end)
        return true
    end

    -- ---- the picker -------------------------------------------------------
    ws.chooser = nil      -- HELD: an unreferenced hs.chooser is collected

    function ws.reset()
        local space = ws.currentSpace()
        local name = ws.assigned[space]
        if not name then
            hs.alert.show("🗂 This Space has no workspace yet — ⇪W to set one", 3)
            ws.show()
            return false
        end
        return ws.apply(name)
    end

    function ws.show()
        if not ws.enabled then return end
        local space = ws.currentSpace()
        local current = ws.assigned[space]

        local names = {}
        for n in pairs(ws.workspaces) do names[#names + 1] = n end
        table.sort(names)

        local choices = {}
        if current then
            choices[#choices + 1] = {
                text    = "↻ Reset this Space — re-apply " .. current,
                subText = "runs onStart, reopens the apps, runs onComplete",
                reset   = true,
            }
        end
        for _, n in ipairs(names) do
            local def = ws.workspaces[n] or {}
            local count = 0
            for _ in pairs(def.Applications or {}) do count = count + 1 end
            choices[#choices + 1] = {
                text    = n .. (n == current and "   ✓ assigned here" or ""),
                subText = count .. " app" .. (count == 1 and "" or "s")
                          .. (def.onStart and " · onStart" or "")
                          .. (def.onComplete and " · onComplete" or ""),
                ws      = n,
            }
        end
        if #choices == 0 then
            hs.alert.show("🗂 No workspaces defined — see ws.workspaces in "
                          .. "modules/workspaces.lua", 4)
            return
        end

        local ch = hs.chooser.new(function(pick)
            if not pick then return end
            if pick.reset then ws.reset() return end
            -- Assigning BEFORE applying, so a workspace that fails
            -- half-way is still the one this Space is set to. Otherwise a
            -- flaky hook would quietly unbind the Space.
            ws.assigned[space] = pick.ws
            ws.save()
            ws.apply(pick.ws)
        end)
        pcall(function() ch:width(35); ch:searchSubText(true) end)
        ch:choices(choices)
        ch:placeholderText(current
            and ("This Space is " .. current .. " — pick another, or reset")
            or  "Name the workspace for this Space")
        ws.chooser = ch
        ch:show()
    end

    function _G.workspaceReport()
        local L = { string.format("🗂 WORKSPACES on %s", tostring(core.hostTag)) }
        L[#L + 1] = "   Spaces API : " .. (ws.spacesOK() and "available"
                    or "MISSING — every Space looks the same to this module")
        L[#L + 1] = "   this Space : " .. ws.currentSpace()
                    .. " → " .. tostring(ws.assigned[ws.currentSpace()] or "unassigned")
        L[#L + 1] = "   defined:"
        local names = {}
        for n in pairs(ws.workspaces) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do
            local problems = ws.validate(n, ws.workspaces[n])
            local apps = {}
            for a in pairs((ws.workspaces[n] or {}).Applications or {}) do
                apps[#apps + 1] = a
            end
            table.sort(apps)
            L[#L + 1] = string.format("     %-16s %s%s", n,
                table.concat(apps, ", "),
                #problems > 0 and ("   ⚠️ " .. problems[1]) or "")
        end
        L[#L + 1] = "   bindings:"
        for id, n in pairs(ws.assigned) do
            L[#L + 1] = string.format("     space %-12s %s", id, n)
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if ws.enabled then
        core.hyperAddShortcut(ws.mods, ws.key, ws.show, "workspaces")
    end

    core.provide("workspace.show",   function()  return ws.show()     end)
    core.provide("workspace.reset",  function()  return ws.reset()    end)
    core.provide("workspace.apply",  function(n) return ws.apply(n)   end)
    core.provide("workspace.report", function()  return _G.workspaceReport() end)

    -- Reading and pruning the store touches disk and asks the Spaces API
    -- for every Space on the Mac, which is not boot-path work.
    M.warm = function()
        ws.load()
        if not ws.spacesOK() and not ws.warned then
            ws.warned = true
            print("🗂 Workspaces: this Hammerspoon has no hs.spaces, so every "
                  .. "Space looks the same and one workspace is remembered for "
                  .. "the whole Mac. Everything else works normally.")
        end
        say("ready — " .. tostring(ws.store))
    end

    _G.workspaces = ws
    M.ws     = ws
    M.config = ws
end

return M
