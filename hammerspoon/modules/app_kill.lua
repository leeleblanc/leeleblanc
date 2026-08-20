-- =====================================================================
-- MODULE: APP KILL (⇪⇧;) — find the process, end the process
-- =====================================================================
-- LL: "I need power tool to Kill an Application?" — and sent the Alfred
-- workflow he had been using for it, a Ruby script around
--      ps -A -o pid -o %cpu -o comm | grep -i …
-- listing each match as "name — 12.3% CPU @ /path/to/it".
--
-- That is exactly what this does, minus Alfred and minus the XML. Press
-- ⇪⇧;, type part of the name, press ⏎ and it is asked to quit. Hold ⌥
-- when you press ⏎ — or pick the same still-running process a second
-- time — and it is killed outright.
--
--        ⇪⇧;        every running process, by name · ⏎ quit · ⌥⏎ force
--
-- ---------------------------------------------------------------------
-- 🎯 WHAT REPLACED THE `process:arg` SYNTAX, AND WHY
-- ---------------------------------------------------------------------
-- The Ruby version let you type "chrome:renderer" to filter by a command
-- line ARGUMENT, because a machine running eleven Chrome helpers needs
-- some way to tell them apart. An hs.chooser filters its own rows and
-- gives no hook to reinterpret the query mid-type, so that syntax cannot
-- be reproduced faithfully.
--
-- What is here instead reaches the same place by a shorter road: the
-- FULL COMMAND LINE rides in each row's subtitle, and the chooser is set
-- to search subtitles. Typing "renderer" therefore filters to the
-- processes whose arguments contain it — no colon, no special form, and
-- it composes with the name ("chrome renderer" narrows on both).
--
-- ---------------------------------------------------------------------
-- 🚨 THE THINGS IT WILL NOT KILL, AND WHY THAT IS NOT CAUTION
-- ---------------------------------------------------------------------
-- kill -9 on the wrong pid is not an inconvenience; on WindowServer or
-- loginwindow it logs you out and everything unsaved goes with it. Four
-- names and one pid are refused outright:
--
--      launchd (pid 1)   killing it panics the machine
--      kernel_task       not a process you can signal
--      WindowServer      instant logout, every app, no save prompt
--      loginwindow       the same, by a different route
--
-- Hammerspoon itself is refused too — not to protect it, but because
-- "quit Hammerspoon" from inside Hammerspoon leaves you with no ⇪ and
-- no way to notice that it worked. Use the menu bar for that, where the
-- consequence is visible.
--
-- ⚠️ EVERYTHING ELSE IS ALLOWED, including things you will regret. This
-- is a kill tool. It asks for a second press before it forces, and it
-- does not ask twice.
--
-- ---------------------------------------------------------------------
-- ⏱ WHY `ps` RUNS SYNCHRONOUSLY HERE
-- ---------------------------------------------------------------------
-- Everything else in this config that shells out does it asynchronously,
-- and that is the right default. This one does not, for one reason: a
-- picker that appears 50ms after the key reads as a flicker, not as a
-- panel, and `ps -A` on a loaded Mac measures in tens of milliseconds
-- rather than seconds — it walks a kernel table, it does not wait on
-- anything. The elapsed time of every scan is recorded and printed by
-- _G.killReport(), so if that assumption ever stops holding on a
-- particular machine the number will say so rather than the feeling.
-- =====================================================================

local M = {
    name  = "App Kill",
    order = 13.97,
    family = "config",
    cheatsheet = {
        title = "💀 APP KILL (⇪⇧; — end a process by name)",
        entries = {
            { "⇪⇧;",   "Every running process — type to filter, ⏎ asks it to quit" },
            { "⌥⏎",    "Force it: SIGKILL, no save prompt, no negotiation" },
            { "again",  "Picking a process that ignored the quit forces it too" },
            { "search",  "Subtitles carry the full command line — “renderer” works" },
            { "safe",   "launchd · kernel_task · WindowServer · loginwindow refused" },
            { "check",  "_G.killReport() — what was ended this session, and how" },
        },
    },
}

function M.setup(core)
    local ak = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ak.enabled     = true
    ak.key         = ";"          -- ⇪⇧;  (⇪; is the power tools palette)
    ak.keyMods     = { "shift" }
    -- How long after a polite quit a second pick counts as "it ignored me,
    -- force it". Long enough for an app with an unsaved-changes dialog to
    -- put that dialog up; short enough that it has expired by the time you
    -- come back to the picker for something unrelated.
    ak.forceWindow = 25
    ak.cacheSecs   = 2            -- repeated presses reuse the last ps
    ak.argChars    = 90           -- command line shown in the subtitle
    ak.minCPU      = -1           -- hide processes under this %CPU (-1 = show all)
    -- 🚨 NEVER, under any modifier. See the header — these are not
    -- "dangerous", they are "the session ends and takes your work".
    ak.refuse      = {
        ["launchd"]      = "killing pid 1 panics the machine",
        ["kernel_task"]  = "not a process you can signal",
        ["WindowServer"] = "this logs you out instantly, every app, no save prompt",
        ["loginwindow"]  = "this logs you out instantly, every app, no save prompt",
    }
    -- ----------------------------------------------------------------------

    ak.rows      = {}     -- index -> { pid, name, cpu, rss, path, args, gui }
    ak.chooser   = nil    -- HELD: an unreferenced hs.chooser is collected
    ak.quitAt    = {}     -- pid -> when it was politely asked
    ak.cache, ak.cacheAt = nil, 0
    ak.scanMs, ak.scans  = 0, 0
    ak.ended     = {}     -- a log of what this session actually ended
    ak.lastNote  = nil

    -- Constants, so test_diagnostics' external-binary review can see
    -- them: a path inside a longer command string is invisible to that
    -- scan, and the scan is what stops a dependency drifting in.
    ak.PS   = "/bin/ps"
    ak.KILL = "/bin/kill"

    local function say(m)  if _G.diag then _G.diag.say("appKill", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("appKill", m) end end

    local function selfPID()
        local ok, p = pcall(function() return hs.processInfo.processID end)
        if ok and type(p) == "number" then return p end
        return -1
    end

    -- ---- reading the process table ---------------------------------------
    -- TWO ps calls, joined on pid, and that is deliberate. `comm` and
    -- `args` both contain spaces, so asking for them in one row makes the
    -- boundary between them unparseable — a path like
    --      /Applications/Some App.app/Contents/MacOS/Some App
    -- has no field separator in it that a pattern can find. One call ends
    -- in comm, the other ends in args, and each is anchored to end-of-line.
    function ak.parse(commOut, argsOut)
        local by = {}
        for line in tostring(commOut or ""):gmatch("[^\n]+") do
            local pid, cpu, rss, path =
                line:match("^%s*(%d+)%s+([%d%.,]+)%s+(%d+)%s+(.+)$")
            if pid then
                -- Some locales report %CPU with a comma. The Ruby version
                -- matched [\.|\,] for the same reason; tonumber does not.
                local n = tonumber((cpu:gsub(",", ".")))
                by[tonumber(pid)] = {
                    pid  = tonumber(pid),
                    cpu  = n or 0,
                    rss  = tonumber(rss) or 0,
                    path = path,
                    name = path:match("([^/]+)$") or path,
                }
            end
        end
        for line in tostring(argsOut or ""):gmatch("[^\n]+") do
            local pid, args = line:match("^%s*(%d+)%s+(.+)$")
            if pid and by[tonumber(pid)] then
                by[tonumber(pid)].args = args
            end
        end
        return by
    end

    function ak.scan(force)
        local now = hs.timer.secondsSinceEpoch()
        if not force and ak.cache and (now - ak.cacheAt) < ak.cacheSecs then
            return ak.cache
        end
        local t0 = now
        local commOut, argsOut
        pcall(function() commOut = hs.execute(ak.PS .. " -Ao pid=,%cpu=,rss=,comm=") end)
        pcall(function() argsOut = hs.execute(ak.PS .. " -Ao pid=,args=") end)
        local by = ak.parse(commOut, argsOut)

        -- Which pids are GUI applications. hs.application knows; ps does
        -- not, and the distinction decides whether a polite quit means
        -- "ask the app to quit" or "send it SIGTERM".
        local okApps, apps = pcall(hs.application.runningApplications)
        if okApps and apps then
            for _, app in ipairs(apps) do
                local ok, pid = pcall(function() return app:pid() end)
                if ok and pid and by[pid] then
                    by[pid].gui = true
                    local okN, n = pcall(function() return app:name() end)
                    if okN and type(n) == "string" and n ~= "" then by[pid].name = n end
                end
            end
        end

        local rows = {}
        for _, r in pairs(by) do
            if r.cpu >= ak.minCPU then rows[#rows + 1] = r end
        end
        -- GUI apps first, then by CPU descending — which is the order you
        -- want when the reason you opened this is "something is hot".
        table.sort(rows, function(a, b)
            if (a.gui or false) ~= (b.gui or false) then return a.gui or false end
            if a.cpu ~= b.cpu then return a.cpu > b.cpu end
            return (a.name or ""):lower() < (b.name or ""):lower()
        end)
        ak.scanMs  = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
        ak.scans   = ak.scans + 1
        ak.cache   = rows
        ak.cacheAt = hs.timer.secondsSinceEpoch()
        return rows
    end

    -- ---- ending one ------------------------------------------------------
    function ak.refusalFor(row)
        if not row then return "no such process" end
        if ak.refuse[row.name] then return ak.refuse[row.name] end
        if row.pid == 1 then return "killing pid 1 panics the machine" end
        if row.pid == selfPID() then
            return "quitting Hammerspoon from inside Hammerspoon leaves you "
                .. "with no ⇪ and no sign it worked — use the menu bar"
        end
        return nil
    end

    local function mb(kb) return string.format("%.0f MB", (kb or 0) / 1024) end

    function ak.endIt(row, force)
        local why = ak.refusalFor(row)
        if why then
            hs.alert.show("💀 " .. row.name .. " — refused:\n" .. why, 5)
            ak.lastNote = row.name .. " refused (" .. why .. ")"
            warn(ak.lastNote)
            return false
        end

        local how, ok
        if force then
            how = "forced"
            ok = pcall(function() hs.execute(ak.KILL .. " -9 " .. row.pid) end)
        elseif row.gui then
            how = "asked to quit"
            local app = hs.application.applicationForPID(row.pid)
            if app then
                ok = pcall(function() app:kill() end)
            else
                ok = pcall(function() hs.execute(ak.KILL .. " " .. row.pid) end)
            end
            ak.quitAt[row.pid] = hs.timer.secondsSinceEpoch()
        else
            how = "signalled"
            ok = pcall(function() hs.execute(ak.KILL .. " " .. row.pid) end)
            ak.quitAt[row.pid] = hs.timer.secondsSinceEpoch()
        end

        if not ok then
            ak.lastNote = "could not signal " .. row.name .. " (pid " .. row.pid .. ")"
            warn(ak.lastNote)
            hs.alert.show("💀 Could not signal " .. row.name, 3)
            return false
        end
        ak.cache = nil        -- the list is stale the moment we act on it
        ak.ended[#ak.ended + 1] = {
            name = row.name, pid = row.pid, how = how,
            at = os.date("%H:%M:%S"),
        }
        say(how .. " " .. row.name .. " (pid " .. row.pid .. ")")
        hs.alert.show("💀 " .. row.name .. " — " .. how
            .. (force and "" or "\n⇪⇧; again within " .. ak.forceWindow
                             .. "s to force it"), force and 2.5 or 4)
        return true
    end

    -- ⌥ held at the moment ⏎ was pressed. The chooser callback runs while
    -- the key is still physically down, so this reads the real modifier
    -- rather than a remembered one — the same trick the right-click module
    -- uses from the other direction.
    local function altHeld()
        local ok, mods = pcall(hs.eventtap.checkKeyboardModifiers)
        return ok and type(mods) == "table" and mods.alt == true
    end

    -- ---- the picker ------------------------------------------------------
    -- ⚠️ The row carries an INTEGER index into ak.rows. Every value in a
    -- chooser row crosses into Objective-C, a nested table does not survive
    -- the trip, and LuaSkin discards the WHOLE list and logs rather than
    -- throwing — so the panel would open empty with nothing to catch.
    function ak.choices(rows)
        local out, now = {}, hs.timer.secondsSinceEpoch()
        for i, r in ipairs(rows) do
            local pending = ak.quitAt[r.pid]
                            and (now - ak.quitAt[r.pid]) < ak.forceWindow
            local sub = ("%.1f%% CPU   ·   %s   ·   pid %d")
                        :format(r.cpu, mb(r.rss), r.pid)
            if pending then sub = sub .. "   ·   ⏎ FORCES IT — it ignored the quit" end
            local args = r.args or r.path or ""
            if #args > ak.argChars then args = args:sub(1, ak.argChars - 1) .. "…" end
            out[#out + 1] = {
                text    = (r.gui and "🖥  " or "⚙️  ") .. r.name,
                subText = sub .. "   ·   " .. args,
                idx     = i,
            }
        end
        return out
    end

    function ak.show()
        if not ak.enabled then return end
        local rows = ak.scan(true)
        ak.rows = rows
        if #rows == 0 then
            hs.alert.show("💀 ps returned nothing — that should not happen", 3)
            return
        end
        if not ak.chooser then
            ak.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                local row = ak.rows[pick.idx]
                if not row then return end
                local now  = hs.timer.secondsSinceEpoch()
                local told = ak.quitAt[row.pid]
                local force = altHeld()
                              or (told and (now - told) < ak.forceWindow)
                ak.endIt(row, force and true or false)
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.appKill = ak.chooser
            pcall(function()
                ak.chooser:searchSubText(true)
                ak.chooser:width(45)
            end)
        end
        ak.chooser:choices(ak.choices(rows))
        ak.chooser:placeholderText(("%d processes — ⏎ quits, ⌥⏎ forces")
                                   :format(#rows))
        ak.chooser:query("")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(ak.chooser)
        else ak.chooser:show() end
    end

    -- ---- the report ------------------------------------------------------
    function _G.killReport()
        local L = { "💀 APP KILL" }
        L[#L + 1] = "   scans   : " .. ak.scans .. " (last took " .. ak.scanMs .. "ms)"
        L[#L + 1] = "   listed  : " .. (ak.cache and #ak.cache or 0) .. " processes"
        if #ak.ended == 0 then
            L[#L + 1] = "   ended   : nothing this session"
        else
            L[#L + 1] = "   ended   : " .. #ak.ended .. " this session"
            for _, e in ipairs(ak.ended) do
                L[#L + 1] = ("      %s  %-24s pid %-6d %s")
                            :format(e.at, e.name, e.pid, e.how)
            end
        end
        if ak.lastNote then L[#L + 1] = "   last problem: " .. ak.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if ak.enabled then
        core.hyperAddShortcut(ak.keyMods, ak.key, function() ak.show() end,
                              "app kill")
    end
    core.provide("kill.show",   function() return ak.show() end)
    core.provide("kill.report", function() return _G.killReport() end)

    _G.appKill = ak
    M.ak     = ak
    M.config = ak
end

return M
