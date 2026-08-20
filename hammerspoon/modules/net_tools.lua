-- =====================================================================
-- MODULE: NETWORK TOOLS (⇪6) — flush · ping · nslookup · traceroute
-- =====================================================================
-- LL: "Give me network tools that are / flush / ping / nslookup /
-- traceroute"
--
-- ⇪6 lists them. Pick one that needs a host and a second box opens where
-- whatever you type IS the host — no dialog, no form. The output comes
-- back as a searchable list, one row per line, and the whole thing is on
-- the clipboard before you have read it.
--
--        ⇪6         the four tools · ⏎ runs one
--
-- 📋 THE HOST BOX PREFILLS FROM YOUR CLIPBOARD. Copy a URL, press ⇪6,
-- pick ping, and the host is already there with the scheme and path
-- stripped off — because "ping https://docs.example.com/a/b" is a thing
-- ping cannot do and a mistake worth not making twice.
--
-- ---------------------------------------------------------------------
-- 🚨 FLUSH DNS CANNOT FULLY WORK WITHOUT ADMIN, AND SAYS SO
-- ---------------------------------------------------------------------
-- A DNS flush on modern macOS is two commands:
--
--      dscacheutil -flushcache          ← no privileges needed
--      sudo killall -HUP mDNSResponder  ← needs an admin password
--
-- The first empties the directory-service cache. The second is the one
-- that actually makes mDNSResponder forget, and it needs to signal a
-- root process. On the work Mac, where there is no admin password, the
-- second CANNOT succeed — and every "flush your DNS" instruction on the
-- internet runs both without mentioning that.
--
-- So this runs both, checks each, and reports which half worked. A half
-- flush reported as a flush is how you spend twenty minutes debugging a
-- DNS entry that was never actually cleared. When the privileged half
-- fails the alert names the real remedy: toggle Wi-Fi off and on, which
-- restarts mDNSResponder's view of the world without any password.
--
-- ---------------------------------------------------------------------
-- 🚨 EVERY COMMAND IS ASYNCHRONOUS AND EVERY ONE HAS A DEADLINE
-- ---------------------------------------------------------------------
-- traceroute to an unreachable host takes as long as its hop count times
-- its timeout — thirty seconds is easy, minutes are possible. Run on the
-- main thread that is thirty seconds with no keyboard. Every command
-- here is an hs.task with a timeout that terminates it and says what it
-- was still waiting for, and the arguments are chosen to bound the wait
-- (ping -c, traceroute -m and -w) rather than trusting the default.
--
-- ⚠️ ARGUMENTS ARE PASSED AS A LIST, NEVER AS A SHELL STRING. A host is
-- text you typed or pasted, and a host called `; rm -rf ~` is only
-- dangerous if something hands it to a shell. hs.task.new takes an
-- argument array and execs directly — there is no shell in the path, so
-- there is nothing to inject into. The one place a shell IS used (the
-- flush, which genuinely needs two commands and their exit codes) takes
-- no user input at all.
-- =====================================================================

local M = {
    name  = "Network Tools",
    order = 14.05,
    family = "config",
    cheatsheet = {
        title = "🌐 NETWORK TOOLS (⇪6 — flush · ping · nslookup · traceroute)",
        entries = {
            { "⇪6",     "The four tools — ⏎ runs one" },
            { "host",   "Type it in the second box; the clipboard prefills it" },
            { "output", "One row per line, searchable — ⏎ copies that line," },
            { "",       "and the whole output is on the clipboard already" },
            { "flush",  "Runs both halves and says which one worked — the" },
            { "",       "mDNSResponder half needs admin and cannot on the work Mac" },
            { "check",  "_G.netReport() — what ran, how long, and what failed" },
        },
    },
}

function M.setup(core)
    local nt = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    nt.enabled   = true
    nt.key       = "6"           -- ⇪6. A digit because there is no letter
    nt.keyMods   = {}            -- left; see the 6.119.0 note in init.lua.
    nt.pingCount = 5             -- ping -c
    nt.traceHops = 20            -- traceroute -m
    nt.traceWait = 2             -- traceroute -w, seconds per hop
    nt.timeout   = 45            -- hard deadline for any one command
    nt.maxRows   = 400           -- output lines kept
    nt.recentMax = 12            -- hosts remembered between presses
    -- ----------------------------------------------------------------------

    nt.recent    = {}            -- hosts you have used, newest first
    nt.outRows   = {}            -- the last output, one line per entry
    nt.chooser, nt.hostChooser, nt.outChooser = nil, nil, nil   -- HELD
    nt.task, nt.timer = nil, nil                                -- HELD
    nt.running   = nil           -- what is in flight, for the report
    nt.lastMs, nt.runs = 0, 0
    nt.lastNote  = nil
    nt.history   = {}            -- { tool, host, ms, lines }

    local function say(m)  if _G.diag then _G.diag.say("netTools", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("netTools", m) end end
    local function note(m) nt.lastNote = m ; warn(m) end

    -- ---- what counts as a host -------------------------------------------
    -- A URL is not a host and neither is an email address, but both are
    -- things you will have on the clipboard when you reach for this. Strip
    -- them down rather than refusing them: "ping https://docs.example.com/
    -- a/b" is a mistake worth making impossible.
    function nt.hostFrom(text)
        if type(text) ~= "string" then return nil end
        local s = text:match("^%s*(.-)%s*$")
        if s == "" then return nil end
        s = s:gsub("^%a[%w%+%-%.]*://", "")   -- scheme
        s = s:gsub("^[^@/]*@", "")            -- user@ or an email local part
        s = s:gsub("[/?#].*$", "")            -- path, query, fragment
        s = s:gsub(":%d+$", "")               -- port
        if s == "" then return nil end
        -- A host is letters, digits, dots and hyphens — or an IP. Anything
        -- else is text that happened to be on the clipboard, and offering
        -- it as a host would send you round a loop wondering why the
        -- lookup failed.
        if not s:match("^[%w%-%.]+$") then return nil end
        if not s:find("%.") and s ~= "localhost" then return nil end
        return s
    end

    function nt.remember(host)
        local out = { host }
        for _, h in ipairs(nt.recent) do
            if h ~= host and #out < nt.recentMax then out[#out + 1] = h end
        end
        nt.recent = out
    end

    -- ---- running one -----------------------------------------------------
    -- ⚠️ ARGUMENTS AS A LIST. hs.task execs directly with no shell, so a
    -- host containing shell metacharacters is just a hostname that will
    -- not resolve. See the header.
    function nt.run(bin, args, label, done)
        if nt.task then
            local ok, running = pcall(function() return nt.task:isRunning() end)
            if ok and running then
                hs.alert.show("🌐 " .. tostring(nt.running)
                    .. " is still running — wait for it or press Esc", 3)
                return false
            end
        end
        local t0 = hs.timer.secondsSinceEpoch()
        nt.running = label
        local t
        local okNew = pcall(function()
            t = hs.task.new(bin, function(code, out, err)
                nt.task = nil
                nt.running = nil
                if nt.timer then
                    pcall(function() nt.timer:stop() end)
                    nt.timer = nil
                end
                nt.lastMs = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
                nt.runs = nt.runs + 1
                -- stderr matters here: nslookup writes "server can't find"
                -- to stdout on some builds and stderr on others, and a
                -- tool that hides half the answer is worse than none.
                local text = tostring(out or "")
                if tostring(err or "") ~= "" then
                    text = text .. "\n" .. tostring(err)
                end
                pcall(done, code, text)
            end, args)
        end)
        if not (okNew and t) then
            nt.running = nil
            note("could not start " .. bin)
            hs.alert.show("🌐 Could not run " .. label, 3)
            return false
        end
        nt.task = t
        pcall(function() t:start() end)
        hs.alert.show("🌐 " .. label .. "…", nt.timeout)
        nt.timer = hs.timer.doAfter(nt.timeout, function()
            nt.timer = nil
            if nt.task ~= t then return end
            pcall(function() t:terminate() end)
            nt.task, nt.running = nil, nil
            note(label .. " did not finish within " .. nt.timeout .. "s")
            hs.alert.show("🌐 " .. label .. " gave up after "
                .. nt.timeout .. "s", 4)
        end)
        return true
    end

    -- ---- the output list -------------------------------------------------
    -- One row per line. traceroute output is line-oriented by nature and
    -- a window you scroll is a window you scroll; a list is one you type
    -- "timeout" into. The WHOLE output goes on the clipboard immediately,
    -- because the usual next step is pasting it to somebody.
    function nt.showOutput(title, text)
        local rows = {}
        for line in tostring(text or ""):gmatch("[^\r\n]+") do
            if line:match("%S") then
                rows[#rows + 1] = line
                if #rows >= nt.maxRows then break end
            end
        end
        nt.outRows = rows
        pcall(function() hs.pasteboard.setContents(text) end)
        if #rows == 0 then
            hs.alert.show("🌐 " .. title .. " — no output", 3)
            return
        end
        local choices = {}
        for i, line in ipairs(rows) do
            choices[#choices + 1] = {
                text    = line,
                subText = title,
                idx     = i,
            }
        end
        if not nt.outChooser then
            nt.outChooser = hs.chooser.new(function(pick)
                if not pick then return end
                local line = nt.outRows[pick.idx]
                if not line then return end
                pcall(function() hs.pasteboard.setContents(line) end)
                hs.alert.show("🌐 Line copied", 1.5)
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.netOutput = nt.outChooser
            pcall(function()
                nt.outChooser:searchSubText(false)
                nt.outChooser:width(60)
            end)
        end
        nt.outChooser:choices(choices)
        nt.outChooser:placeholderText(title .. " — " .. #rows
            .. " lines, all of it already copied · ⏎ copies one line")
        nt.outChooser:query("")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(nt.outChooser)
        else nt.outChooser:show() end
    end

    -- ---- the four tools --------------------------------------------------
    -- 🚨 THE FLUSH IS THE ONE THAT NEEDS A SHELL, and the one place where
    -- that is safe: it takes NO user input. Two commands, two exit codes,
    -- reported separately — see the header for why reporting a half flush
    -- as a flush is the failure that matters.
    -- 🚨 THE TWO BINARIES ARE NAMED CONSTANTS, NOT TEXT INSIDE THE SHELL
    -- LINE, and that is not style. test_diagnostics scans this file for
    -- quoted absolute paths and fails on any binary not on its reviewed
    -- list — which is the guard that stops an external dependency
    -- drifting in unnoticed. A path buried inside a longer shell string
    -- is invisible to that scan, so writing it that way would slip past
    -- a check that exists precisely to catch it.
    nt.DSCACHE = "/usr/bin/dscacheutil"
    nt.KILLALL = "/usr/bin/killall"

    function nt.flush()
        return nt.run("/bin/sh", {
            "-c",
            nt.DSCACHE .. " -flushcache 2>&1; echo \"DSCACHE_RC=$?\"; "
            .. nt.KILLALL .. " -HUP mDNSResponder 2>&1; echo \"MDNS_RC=$?\"",
        }, "Flushing DNS", function(_, text)
            local dsRC   = tonumber(text:match("DSCACHE_RC=(%d+)"))
            local mdnsRC = tonumber(text:match("MDNS_RC=(%d+)"))
            local lines = { "Flush DNS", "" }
            lines[#lines + 1] = (dsRC == 0)
                and "✅ dscacheutil -flushcache — the directory service cache is empty"
                or  ("❌ dscacheutil -flushcache failed (exit " .. tostring(dsRC) .. ")")
            if mdnsRC == 0 then
                lines[#lines + 1] = "✅ killall -HUP mDNSResponder — the resolver was reset"
            else
                lines[#lines + 1] = "❌ killall -HUP mDNSResponder failed (exit "
                    .. tostring(mdnsRC) .. ") — this half needs an admin"
                lines[#lines + 1] = "   password and cannot work on a managed Mac."
                lines[#lines + 1] = ""
                lines[#lines + 1] = "   WITHOUT ADMIN, the working substitute is to turn"
                lines[#lines + 1] = "   Wi-Fi off and on again: it makes mDNSResponder"
                lines[#lines + 1] = "   rebuild its view without any password."
            end
            lines[#lines + 1] = ""
            lines[#lines + 1] = "raw output:"
            lines[#lines + 1] = text
            local both = (dsRC == 0 and mdnsRC == 0)
            hs.alert.show(both
                and "🌐 DNS flushed — both halves succeeded"
                or  "🌐 DNS HALF flushed — the resolver half needs admin.\n"
                    .. "Toggle Wi-Fi off and on to finish the job.", both and 3 or 6)
            nt.history[#nt.history + 1] = { tool = "flush", host = "-",
                                            ms = nt.lastMs, ok = both }
            nt.showOutput("Flush DNS", table.concat(lines, "\n"))
        end)
    end

    function nt.ping(host)
        nt.remember(host)
        return nt.run("/sbin/ping",
            { "-c", tostring(nt.pingCount), host },
            "ping " .. host, function(code, text)
                nt.history[#nt.history + 1] = { tool = "ping", host = host,
                                                ms = nt.lastMs, ok = code == 0 }
                nt.showOutput("ping " .. host, text)
            end)
    end

    function nt.nslookup(host)
        nt.remember(host)
        return nt.run("/usr/bin/nslookup", { host },
            "nslookup " .. host, function(code, text)
                nt.history[#nt.history + 1] = { tool = "nslookup", host = host,
                                                ms = nt.lastMs, ok = code == 0 }
                nt.showOutput("nslookup " .. host, text)
            end)
    end

    function nt.traceroute(host)
        nt.remember(host)
        -- -m and -w are what keep this bounded. See the header: an
        -- unreachable host with default settings can run for minutes.
        return nt.run("/usr/sbin/traceroute",
            { "-m", tostring(nt.traceHops), "-w", tostring(nt.traceWait), host },
            "traceroute " .. host, function(code, text)
                nt.history[#nt.history + 1] = { tool = "traceroute", host = host,
                                                ms = nt.lastMs, ok = code == 0 }
                nt.showOutput("traceroute " .. host, text)
            end)
    end

    nt.tools = {
        { id = "flush", icon = "🚽", title = "Flush DNS",
          sub = "Both halves, reported separately — one of them needs admin",
          needsHost = false, run = function() return nt.flush() end },
        { id = "ping",  icon = "📡", title = "Ping",
          sub = nil, needsHost = true, run = function(h) return nt.ping(h) end },
        { id = "look",  icon = "🔍", title = "nslookup",
          sub = "What DNS says this name resolves to, and which server said it",
          needsHost = true, run = function(h) return nt.nslookup(h) end },
        { id = "trace", icon = "🛣", title = "traceroute",
          sub = nil, needsHost = true, run = function(h) return nt.traceroute(h) end },
    }

    function nt.subFor(t)
        if t.id == "ping"  then return nt.pingCount .. " packets, then the summary" end
        if t.id == "trace" then return "at most " .. nt.traceHops .. " hops, "
                                      .. nt.traceWait .. "s each" end
        return t.sub or ""
    end

    function nt.byId(id)
        for _, t in ipairs(nt.tools) do if t.id == id then return t end end
        return nil
    end

    -- ---- the host box ----------------------------------------------------
    -- 🚨 WHATEVER YOU TYPE IS THE HOST, and that needs a queryChangedCallback
    -- rather than a plain chooser. An hs.chooser only ever hands back a ROW,
    -- so a box with no matching row hands back nothing and ⏎ does nothing —
    -- which reads as the tool being broken. Rebuilding the top row on every
    -- keystroke means there is always something for ⏎ to select, and that
    -- something is exactly what you typed.
    function nt.askHost(tool)
        local prefill = nil
        local okClip, clip = pcall(hs.pasteboard.getContents)
        if okClip then prefill = nt.hostFrom(clip) end

        local function build(query)
            local out = {}
            local typed = nt.hostFrom(query)
            if typed then
                out[#out + 1] = { text = tool.icon .. "  " .. tool.title
                                         .. "  " .. typed,
                                  subText = "⏎ runs it", host = typed }
            elseif query and query:match("%S") then
                out[#out + 1] = { text = "…" .. query,
                                  subText = "not a hostname yet — keep typing",
                                  host = "" }
            end
            if prefill and (not typed or typed ~= prefill) then
                out[#out + 1] = { text = prefill,
                                  subText = "from your clipboard", host = prefill }
            end
            for _, h in ipairs(nt.recent) do
                if h ~= prefill and h ~= typed then
                    out[#out + 1] = { text = h, subText = "used before", host = h }
                end
            end
            if #out == 0 then
                out[#out + 1] = { text = "Type a hostname or an IP address",
                                  subText = "example.com · 1.1.1.1 · localhost",
                                  host = "" }
            end
            return out
        end

        if not nt.hostChooser then
            nt.hostChooser = hs.chooser.new(function(pick)
                if not pick then return end
                if not pick.host or pick.host == "" then return end
                local t = nt.byId(nt.pendingTool)
                if t then t.run(pick.host) end
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.netHost = nt.hostChooser
            pcall(function()
                nt.hostChooser:searchSubText(false)
                nt.hostChooser:width(40)
                nt.hostChooser:queryChangedCallback(function(q)
                    nt.hostChooser:choices(build(q))
                end)
            end)
        end
        nt.pendingTool = tool.id
        nt.hostChooser:choices(build(prefill or ""))
        nt.hostChooser:placeholderText(tool.title
            .. " — type a hostname or IP, ⏎ runs it")
        nt.hostChooser:query(prefill or "")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(nt.hostChooser)
        else nt.hostChooser:show() end
    end

    function nt.show()
        if not nt.enabled then return end
        local choices = {}
        for _, t in ipairs(nt.tools) do
            choices[#choices + 1] = {
                text    = t.icon .. "  " .. t.title,
                subText = nt.subFor(t),
                id      = t.id,
            }
        end
        if not nt.chooser then
            nt.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                local t = nt.byId(pick.id)
                if not t then return end
                if t.needsHost then nt.askHost(t) else t.run() end
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.netTools = nt.chooser
            pcall(function()
                nt.chooser:searchSubText(true)
                nt.chooser:width(38)
            end)
        end
        nt.chooser:choices(choices)
        nt.chooser:placeholderText("network tools — ⏎ runs one")
        nt.chooser:query("")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(nt.chooser)
        else nt.chooser:show() end
    end

    -- ---- the report ------------------------------------------------------
    function _G.netReport()
        local L = { "🌐 NETWORK TOOLS" }
        L[#L + 1] = "   runs    : " .. nt.runs
                    .. (nt.running and ("  (RUNNING NOW: " .. nt.running .. ")") or "")
        if #nt.history == 0 then
            L[#L + 1] = "   history : nothing run this session"
        else
            for _, h in ipairs(nt.history) do
                L[#L + 1] = ("      %-11s %-28s %5dms  %s")
                            :format(h.tool, h.host, h.ms or 0,
                                    h.ok and "ok" or "non-zero exit")
            end
        end
        if #nt.recent > 0 then
            L[#L + 1] = "   hosts   : " .. table.concat(nt.recent, ", ")
        end
        L[#L + 1] = "   ⚠️ a DNS flush needs admin for the mDNSResponder half;"
        L[#L + 1] = "      without it, toggle Wi-Fi off and on instead."
        if nt.lastNote then L[#L + 1] = "   last problem: " .. nt.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if nt.enabled then
        core.hyperAddShortcut(nt.keyMods, nt.key, function() nt.show() end,
                              "network tools")
    end
    core.provide("net.show",   function() return nt.show() end)
    core.provide("net.flush",  function() return nt.flush() end)
    core.provide("net.report", function() return _G.netReport() end)

    _G.netTools = nt
    M.nt     = nt
    M.config = nt
end

return M
