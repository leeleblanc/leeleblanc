-- =====================================================================
-- test_workspaces.lua — async ordering, and a flag that must never stick
-- =====================================================================
--     lua5.4 test_workspaces.lua [/path/to/hammerspoon]
--
-- This module's chain is entirely asynchronous — onStart, then launch,
-- then wait for the apps, then onComplete — and every step can fail
-- independently. Two failures matter more than the rest:
--
--   P1  ws.busy MUST NEVER STICK TRUE. It is the one-apply-at-a-time
--       guard, so if a failing step leaves it set the feature is dead
--       until Hammerspoon reloads and nothing says why. This is the same
--       failure shape as Focus Mode leaving the mic muted.
--   P2  ORDER IS PRESERVED: onStart finishes before any app launches,
--       and onComplete does not run until the apps are actually up. The
--       whole point of onComplete is "the workspace is ready", and
--       firing it right after launchOrFocus would be a lie.
--
-- And one that is quieter but destroys data:
--   P3  A STALE SPACE ID IS DROPPED, NEVER GUESSED. Space IDs change on
--       logout, so a saved binding can point at a Space that is now
--       somebody else entirely. Applying the wrong workspace to the
--       wrong desktop is worse than forgetting the binding.
--   P4  ...but an EMPTY answer from the Spaces API must not wipe the
--       store. "The API told us nothing" is not "every Space is gone".

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a controllable Mac ----------------------------------------------
local CLOCK, TIMERS, TASKS, ALERTS, EVENTS = 0, {}, {}, {}, {}
local APPS_RUNNING, LAUNCH_FAILS, SPACES, FOCUSED = {}, {}, nil, "100"
local AUTO_TASK_EXIT, FILES = 0, {}
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- Drives the async chain: fire every timer whose moment has come, then
-- repeat, because a firing timer usually schedules the next one.
local function advance(seconds)
    local target = CLOCK + seconds
    local guard = 0
    while CLOCK < target do
        CLOCK = CLOCK + 0.05
        guard = guard + 1
        if guard > 10000 then break end
        for _, t in ipairs(TIMERS) do
            if not t.fired and not t.stopped and t.due <= CLOCK then
                t.fired = true
                t.fn()
            end
        end
    end
end

local realIoOpen = io.open
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s end,
                 close = function() FILES[path] = table.concat(buf) end }
    end
    if FILES[path] == nil then return nil end
    local content, done = FILES[path], false
    return { read = function() if done then return nil end done = true return content end,
             close = function() end }
end

hs = {
    timer = {
        secondsSinceEpoch = function() return CLOCK end,
        doAfter = function(secs, fn)
            local t = { due = CLOCK + secs, fn = fn, fired = false, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args, started = false,
                        terminated = false }
            function t:start()
                self.started = true
                EVENTS[#EVENTS + 1] = "hook:" .. tostring((args or {})[2])
                if AUTO_TASK_EXIT ~= nil then
                    self.cb(AUTO_TASK_EXIT, "", AUTO_TASK_EXIT == 0 and "" or "boom")
                end
                return true
            end
            function t:terminate() self.terminated = true end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    application = {
        launchOrFocus = function(name)
            EVENTS[#EVENTS + 1] = "launch:" .. name
            if LAUNCH_FAILS[name] then return false end
            APPS_RUNNING[name] = true
            return true
        end,
        get = function(name) return APPS_RUNNING[name] and { _n = name } or nil end,
    },
    spaces = {
        focusedSpace = function() return FOCUSED end,
        allSpaces = function() return SPACES end,
    },
    json = {
        encode = function(t)
            local parts = {}
            local keys = {}
            for k in pairs(t) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do parts[#parts + 1] = k .. "\1" .. t[k] end
            return table.concat(parts, "\2")
        end,
        decode = function(s)
            local o = {}
            for chunk in tostring(s):gmatch("[^\2]+") do
                local k, v = chunk:match("^(.-)\1(.*)$")
                if k then o[k] = v end
            end
            return o
        end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = { new = function(fn)
        local c = { fn = fn }
        for _, m in ipairs({ "width", "searchSubText", "placeholderText", "show" }) do
            c[m] = function(self) return self end
        end
        function c:choices(x) self.rows = x ; return self end
        return c end },
    pasteboard = { setContents = function() return true end },
}
_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local HYPER, PROVIDED = {}, {}
local CORE = {
    hostTag = "Test-Mac", logsDir = "/tmp/wstest",
    warnWriteFailed = function() end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, WS
local function boot()
    CLOCK, TIMERS, TASKS, ALERTS, EVENTS = 0, {}, {}, {}, {}
    APPS_RUNNING, LAUNCH_FAILS, printed = {}, {}, {}
    AUTO_TASK_EXIT, FOCUSED = 0, "100"
    SPACES = { ["screen-uuid"] = { 100, 200 } }
    M = dofile(HS .. "/modules/workspaces.lua")
    M.setup(CORE)
    WS = _G.workspaces
    return WS
end

-- =====================================================================
out("\n=== 1. Contract ===\n")
-- =====================================================================
boot()
check("the module returns name, order and a cheatsheet",
      M.name == "Workspaces" and type(M.order) == "number"
      and type(M.cheatsheet) == "table")
check("it claims ⇪W", HYPER["|w"] ~= nil)
check("🅿️ and does NOT claim ⇪⇧W, which the Document Watcher already owns",
      HYPER["shift|w"] == nil)
check("reset is published so a free pad key can reach it",
      PROVIDED["workspace.reset"] ~= nil and PROVIDED["workspace.apply"] ~= nil)
check("its order collides with neither focus_mode (14.0) nor bulk_rename (14.1)",
      M.order ~= 14.0 and M.order ~= 14.1)
check("store reading happens in warm(), not on the boot path",
      type(M.warm) == "function")

-- =====================================================================
out("\n=== 2. The format from the spec ===\n")
-- =====================================================================
boot()
WS.workspaces = {
    DevWork = {
        onStart      = "~/.something/start.sh",
        Applications = { ["Google Chrome"] = {} },
        onComplete   = "~/.something/done.sh",
    },
}
check("the documented shape validates clean",
      #WS.validate("DevWork", WS.workspaces.DevWork) == 0,
      (WS.validate("DevWork", WS.workspaces.DevWork))[1])
check("~ is expanded to $HOME rather than handed to the shell as a literal",
      WS.expandPath("~/x.sh") == (os.getenv("HOME") or "~") .. "/x.sh",
      WS.expandPath("~/x.sh"))

-- 🚨 The typo that a hand-edited table invites.
check("an unknown key is caught BEFORE anything launches", (function()
    local p = WS.validate("X", { Aplications = {} })
    return #p > 0 and p[1]:find("unknown key", 1, true) ~= nil
end)())
check("Applications must be a table",
      #WS.validate("X", { Applications = "Chrome" }) > 0)
check("a hook must be a string",
      #WS.validate("X", { onStart = 42 }) > 0)
check("an app's options must be a table — {} for none",
      #WS.validate("X", { Applications = { Chrome = "yes" } }) > 0)

-- =====================================================================
out("\n=== 3. Ordering — P2 ===\n")
-- =====================================================================
boot()
WS.workspaces = { Dev = {
    onStart      = "/bin/start.sh",
    Applications = { ["Google Chrome"] = {}, ["Slack"] = {} },
    onComplete   = "/bin/done.sh",
} }
WS.apply("Dev")
advance(12)
local order = table.concat(EVENTS, " ")
check("onStart runs first", EVENTS[1] == "hook:/bin/start.sh", order)
check("🚨 THE APPS LAUNCH ONLY AFTER onStart HAS FINISHED — not alongside it",
      order:find("hook:/bin/start%.sh.*launch:") ~= nil, order)
check("onComplete runs last, after both apps",
      EVENTS[#EVENTS] == "hook:/bin/done.sh", order)
check("both apps were launched", order:find("launch:Google Chrome", 1, true)
      and order:find("launch:Slack", 1, true))
check("P1: busy cleared at the end", WS.busy == false)

-- onComplete must WAIT for the apps, not fire straight after launching.
boot()
WS.workspaces = { Slow = {
    Applications = { ["Xcode"] = {} },
    onComplete   = "/bin/done.sh",
} }
LAUNCH_FAILS = {}
-- launchOrFocus succeeds but the app takes its time to actually appear.
hs.application.launchOrFocus = function(name)
    EVENTS[#EVENTS + 1] = "launch:" .. name ; return true
end
WS.apply("Slow")
advance(1)
check("🚨 onComplete has NOT fired while the app is still starting — "
      .. "firing it here would be a lie about the workspace being ready",
      table.concat(EVENTS, " "):find("hook:/bin/done%.sh") == nil,
      table.concat(EVENTS, " "))
APPS_RUNNING["Xcode"] = true       -- it finally appears
advance(2)
check("...and it fires once the app is actually up",
      table.concat(EVENTS, " "):find("hook:/bin/done%.sh") ~= nil)
check("P1: busy cleared", WS.busy == false)

-- =====================================================================
out("\n=== 4. Failure paths all clear the flag — P1 ===\n")
-- =====================================================================
-- An app that never appears must not hold the chain forever.
boot()
hs.application.launchOrFocus = function(name)
    EVENTS[#EVENTS + 1] = "launch:" .. name ; return true
end
WS.workspaces = { Ghost = {
    Applications = { ["NeverStarts"] = {} }, onComplete = "/bin/done.sh" } }
WS.apply("Ghost")
advance(WS.settleSecs + 3)
check("🚨 AN APP THAT NEVER APPEARS TIMES OUT — onComplete still runs and "
      .. "the workspace does not hang half-applied",
      table.concat(EVENTS, " "):find("hook:/bin/done%.sh") ~= nil)
check("P1: busy cleared after the timeout", WS.busy == false)

-- A hook that fails.
boot()
AUTO_TASK_EXIT = 1
WS.workspaces = { Bad = { onStart = "/bin/nope.sh",
                          Applications = { ["Google Chrome"] = {} } } }
WS.apply("Bad")
advance(12)
check("a failing onStart is REPORTED but the apps still open — a workspace "
      .. "that silently does nothing is the worse outcome",
      table.concat(EVENTS, " "):find("launch:Google Chrome", 1, true) ~= nil)
check("P1: busy cleared after a hook failure", WS.busy == false)
check("the failure is surfaced to the user, not just logged",
      (function()
          for _, a in ipairs(ALERTS) do if a:find("hook failed", 1, true) then return true end end
      end)(), ALERTS[#ALERTS])

-- stopOnHookFailure aborts instead, for a genuine prerequisite.
boot()
AUTO_TASK_EXIT = 1
WS.stopOnHookFailure = true
WS.workspaces = { Bad2 = { onStart = "/bin/nope.sh",
                           Applications = { ["Google Chrome"] = {} } } }
WS.apply("Bad2")
advance(12)
check("with stopOnHookFailure the apps are NOT opened",
      table.concat(EVENTS, " "):find("launch:", 1, true) == nil)
check("P1: busy cleared on the abort path too", WS.busy == false)

-- 🚨 A HOOK THAT NEVER EXITS. This is the one that would strand the flag.
boot()
AUTO_TASK_EXIT = nil          -- the task starts and never calls back
WS.workspaces = { Hang = { onStart = "/bin/hang.sh",
                           Applications = { ["Google Chrome"] = {} } } }
WS.apply("Hang")
advance(2)
check("while the hook runs, busy is held", WS.busy == true)
advance(WS.hookTimeout + 15)
check("🚨 A HOOK THAT NEVER EXITS IS ABANDONED — without this timer the "
      .. "workspace stays half-applied and busy sticks true until reload",
      WS.busy == false)
check("...and the runaway task was terminated, not left running",
      (function()
          for _, t in ipairs(TASKS) do if t.terminated then return true end end
      end)())

-- A second apply while one is running is refused, not interleaved.
boot()
AUTO_TASK_EXIT = nil
WS.workspaces = { A = { onStart = "/bin/a.sh", Applications = {} } }
WS.apply("A")
local secondStarted = WS.apply("A")
check("a second apply while one is in flight is refused",
      secondStarted == false and WS.busy == true)
advance(WS.hookTimeout + 15)
check("P1: and the first one still finishes and clears", WS.busy == false)

-- Applying a name that does not exist.
boot()
local okMissing = WS.apply("NoSuchThing")
check("applying an unknown workspace fails cleanly",
      okMissing == false and WS.busy == false)

-- =====================================================================
out("\n=== 5. Spaces — P3 and P4 ===\n")
-- =====================================================================
boot()
SPACES = { ["s1"] = { 100, 200 } }
local pruned, dropped = WS.pruneStore({ ["100"] = "Dev", ["999"] = "Ghost" })
check("🚨 P3: A SPACE ID THE SYSTEM NO LONGER LISTS IS DROPPED — IDs change "
      .. "on logout, and applying the wrong workspace to the wrong desktop "
      .. "is worse than forgetting",
      pruned["100"] == "Dev" and pruned["999"] == nil and dropped == 1)

boot()
SPACES = {}
local kept, dropped2 = WS.pruneStore({ ["100"] = "Dev" })
check("🚨 P4: AN EMPTY ANSWER FROM THE API DOES NOT WIPE THE STORE — "
      .. "'told us nothing' is not 'every Space is gone'",
      kept["100"] == "Dev" and dropped2 == 0)

boot()
hs.spaces = nil
check("with no hs.spaces at all it degrades instead of failing",
      WS.spacesOK() == false and WS.currentSpace() == "no-spaces-api")
local okPrune, keptNo = pcall(WS.pruneStore, { ["100"] = "Dev" })
check("...and pruning without the API keeps everything rather than guessing",
      okPrune and keptNo["100"] == "Dev")

-- Round-trip through the store.
boot()
FILES = {}
WS.assigned = { ["100"] = "Dev" }
check("the store writes", WS.save() == true)
WS.assigned = {}
WS.load()
check("...and reads back", WS.assigned["100"] == "Dev")

boot()
FILES = {}
FILES[WS.store] = "this is not json at all \1\2"
local okLoad = pcall(WS.load)
check("an unreadable store starts empty instead of throwing", okLoad)

-- =====================================================================
out("\n=== 6. The picker ===\n")
-- =====================================================================
boot()
WS.workspaces = { Dev = { Applications = { A = {} } },
                  Ops = { Applications = { B = {} } } }
WS.assigned = {}
WS.show()
local rows = WS.chooser.rows
check("with nothing assigned, every workspace is offered and there is no "
      .. "reset row", #rows == 2 and rows[1].reset == nil)

WS.assigned[WS.currentSpace()] = "Dev"
WS.show()
rows = WS.chooser.rows
check("once assigned, the FIRST row is the reset — that is where ⇪⇧W would "
      .. "have gone", rows[1].reset == true, rows[1].text)
check("...and the assigned one is marked",
      (function()
          for _, r in ipairs(rows) do
              if r.ws == "Dev" and r.text:find("assigned here", 1, true) then return true end
          end
      end)())

-- 🚨 Assign before apply, so a flaky hook cannot silently unbind a Space.
boot()
AUTO_TASK_EXIT = 1
WS.workspaces = { Dev = { onStart = "/bin/fail.sh", Applications = {} } }
WS.assigned = {}
WS.show()
WS.chooser.fn({ ws = "Dev" })
advance(12)
check("🚨 THE SPACE STAYS BOUND EVEN WHEN THE WORKSPACE FAILS TO APPLY — "
      .. "assigning after a successful apply would let a flaky hook quietly "
      .. "unbind the Space", WS.assigned[WS.currentSpace()] == "Dev")

boot()
WS.workspaces = {}
WS.show()
check("with nothing defined it says so rather than showing an empty list",
      (function()
          for _, a in ipairs(ALERTS) do
              if a:find("No workspaces defined", 1, true) then return true end
          end
      end)())

-- reset with nothing assigned falls through to the picker
boot()
WS.workspaces = { Dev = { Applications = {} } }
WS.assigned = {}
local r = WS.reset()
check("reset on an unassigned Space prompts instead of doing nothing",
      r == false and WS.chooser ~= nil)

-- =====================================================================
out("\n=== 7. THE EXPLORER — 300 random workspaces and failures ===\n")
-- =====================================================================
do
    math.randomseed(20260811)
    local bad, runs = nil, 0
    local APPS = { "Google Chrome", "Slack", "Xcode", "Terminal", "Notes" }
    for iter = 1, 300 do
        boot()
        hs.application.launchOrFocus = function(name)
            EVENTS[#EVENTS + 1] = "launch:" .. name
            if LAUNCH_FAILS[name] then return false end
            -- Some apps appear immediately, some never do.
            if math.random() < 0.7 then APPS_RUNNING[name] = true end
            return true
        end
        local def = { Applications = {} }
        local n = math.random(0, 4)
        for _ = 1, n do
            local a = APPS[math.random(#APPS)]
            def.Applications[a] = (math.random() < 0.2)
                and { zone = "leftHalf" } or {}
            if math.random() < 0.2 then LAUNCH_FAILS[a] = true end
        end
        if math.random() < 0.6 then def.onStart    = "/bin/s.sh" end
        if math.random() < 0.6 then def.onComplete = "/bin/c.sh" end
        WS.stopOnHookFailure = math.random() < 0.3
        -- Hooks succeed, fail, or hang.
        local roll = math.random(10)
        AUTO_TASK_EXIT = (roll <= 6) and 0 or ((roll <= 9) and 1 or nil)
        WS.workspaces = { R = def }

        runs = runs + 1
        local okApply = pcall(WS.apply, "R")
        if not okApply then bad = "apply threw on iter " .. iter break end
        -- ⚠️ THE BUDGET HAS TO COVER *BOTH* HOOKS HANGING. onStart can burn
        -- a full hookTimeout, then the apps settle, then onComplete can
        -- burn another. Advancing only one hookTimeout stops the clock
        -- mid-chain and reports a working module as stuck — which is
        -- exactly what the first run of this explorer did.
        advance(2 * WS.hookTimeout + WS.settleSecs + 30)

        -- P1: whatever happened, the flag is clear.
        if WS.busy then
            bad = string.format("iter %d: busy stuck (hooks=%s, apps=%d)",
                  iter, tostring(AUTO_TASK_EXIT), n)
            break
        end
        -- P2: if both hooks ran, onStart came before every launch and
        -- onComplete after them.
        local seq = table.concat(EVENTS, " ")
        if def.onStart and seq:find("launch:") and seq:find("hook:/bin/s%.sh") then
            if seq:find("launch:") < seq:find("hook:/bin/s%.sh") then
                bad = "iter " .. iter .. ": an app launched before onStart"
                break
            end
        end
        if def.onComplete and seq:find("hook:/bin/c%.sh") and seq:find("launch:") then
            local lastLaunch = 0
            for pos in seq:gmatch("()launch:") do lastLaunch = pos end
            if seq:find("hook:/bin/c%.sh") < lastLaunch then
                bad = "iter " .. iter .. ": onComplete ran before the last launch"
                break
            end
        end
        -- A second apply must always be possible afterwards.
        local okAgain = WS.apply("R")
        if okAgain ~= true then
            bad = "iter " .. iter .. ": could not apply again afterwards"
            break
        end
        advance(2 * WS.hookTimeout + WS.settleSecs + 30)
        if WS.busy then bad = "iter " .. iter .. ": busy stuck on the second run" break end
    end
    check(string.format("300 random workspaces (%d runs) mixing failing "
          .. "launches, failing hooks and hooks that never exit: busy NEVER "
          .. "stuck, ordering always held, and a second apply always worked",
          runs), bad == nil, bad)
end

-- =====================================================================
out("\n=== 8. Mutation — are these load-bearing? ===\n")
-- =====================================================================
do
    -- Without the abandon timer, a hanging hook strands busy forever.
    boot()
    AUTO_TASK_EXIT = nil
    local realRunHook = WS.runHook
    WS.runHook = function(cmd, label, done)
        if cmd == nil or cmd == "" then done(true) return end
        hs.task.new("/bin/zsh", function() done(true) end, { "-c", cmd }):start()
        -- MUTATION: no timeout timer at all
    end
    WS.workspaces = { H = { onStart = "/bin/hang.sh", Applications = {} } }
    WS.apply("H")
    advance(WS.hookTimeout + 30)
    local stuck = WS.busy
    WS.runHook = realRunHook
    WS.busy = false
    check("MUTATION: drop the abandon timer and a hanging hook wedges the "
          .. "feature until reload — P1 catches it", stuck == true)

    -- Without pruning, a stale ID survives and would apply the wrong
    -- workspace to a Space that is now something else.
    boot()
    SPACES = { s = { 100 } }
    local realPrune = WS.pruneStore
    WS.pruneStore = function(store) return store, 0 end
    FILES = {}
    WS.assigned = { ["999"] = "Ghost" }
    WS.save()
    WS.assigned = {}
    WS.load()
    local survived = WS.assigned["999"]
    WS.pruneStore = realPrune
    check("MUTATION: skip pruning and a dead Space ID survives a reload — "
          .. "P3 catches it", survived == "Ghost")
end

io.open = realIoOpen
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
