-- =====================================================================
-- MODULE: NET WATCH (⇪⇧6) — who's talking, to whom, and why
-- =====================================================================
-- LL, with the ⇪7 About-This-Mac card open: "Can you make the panel of
-- information more indepth? Specifically I want it to list any
-- application that is running something that is communicating with some
-- service to do something. Say what the application is · say what the
-- application is doing · resolve where the application is pulling its
-- data from." Plus ⌘1 to copy everything as one report and ⌘2 to copy a
-- single app's report out.
--
-- ⇪⇧6 (the shift of ⇪6, net tools — the ledger listed it free) answers
-- with one picker: every application of YOURS that holds a live network
-- connection, one row per app, connection counts and remote ends in the
-- subtitle. ⏎ on an app copies THAT app's report; the first row — ⌘1,
-- the chooser numbers it natively — copies the whole thing.
--
-- ---------------------------------------------------------------------
-- 🔬 WHERE THE ANSWERS COME FROM, layer by layer
-- ---------------------------------------------------------------------
--   · THE CONNECTIONS: /usr/sbin/lsof -i, field output (-F), so no
--     column guessing — command names with spaces ("Google Chrome
--     Helper") arrive intact. Run WITHOUT root, which means it lists
--     the processes this user owns: your apps, your helpers, your
--     agents. Root's daemons need admin and are deliberately out —
--     this tool answers "what are MY apps doing", not "audit the OS".
--   · THE NAMES: each remote IP is reverse-resolved through
--     /usr/bin/dscacheutil (the system resolver's own cache — the ⇪6
--     flush tool's other half), one lookup at a time, cached for the
--     session. Private-range addresses are labeled "local network"
--     instead of resolved: your printer does not need a DNS story.
--   · THE WHY: a small rule table maps well-known process and domain
--     names to what they are and why they talk (Microsoft AutoUpdate
--     monitors Office updates; apsd is every push notification; …).
--     A name no rule matches says so — "unrecognized" with the raw
--     path shown — rather than guessing confidently. Intent cannot be
--     read off a socket; the table records what is DOCUMENTED, and
--     the honest fallback is the whole point of having one.
--
-- ⚠️ A SNAPSHOT, NOT A MONITOR. Each press runs one lsof, then stops —
-- no polling, no background task, nothing for the battery saver to
-- slow. Connections open and close constantly; press again for now.
-- =====================================================================

local M = {
    name  = "Net Watch",
    order = 14.07,
    family = "config",
    cheatsheet = {
        title = "🌐 NET WATCH (⇪⇧6 — who's talking, and why)",
        entries = {
            { "⇪⇧6",   "Every app of yours with a live connection — one row per app" },
            { "⏎",     "Copy that app's report: what · why · each resolved path" },
            { "⌘1",    "Copy the FULL report — every app, every connection" },
            { "names",  "Remote IPs reverse-resolved · known services explained" },
            { "honest", "An unknown service says “unrecognized”, never a guess" },
            { "check",  "_G.netWatchReport() — the same full report, in the Console" },
        },
    },
}

function M.setup(core)
    local nw = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    nw.enabled     = true
    nw.key         = "6"          -- ⇪⇧6  (⇪6 is net tools)
    nw.keyMods     = { "shift" }
    nw.lsofTimeout = 10           -- seconds before the snapshot is abandoned
    nw.dnsTimeout  = 3            -- per reverse lookup
    nw.dnsMax      = 24           -- distinct IPs resolved per snapshot
    nw.remoteShow  = 3            -- remote names shown in a row's subtitle
    -- ----------------------------------------------------------------------

    -- Constants, so test_diagnostics' external-binary review can see them.
    nw.LSOF        = "/usr/sbin/lsof"
    nw.DSCACHEUTIL = "/usr/bin/dscacheutil"

    -- 📖 THE RULE TABLE. Matched (as Lua patterns, case-insensitive)
    -- against the PROCESS name first, then against each RESOLVED remote
    -- domain. First hit wins, so specific process rules sit above the
    -- broad domain rules. `what` answers "say what the application is /
    -- is doing"; `why` answers "why is it doing this".
    nw.known = {
        { m = "microsoft autoupdate", what = "Microsoft AutoUpdate — the Office update helper",
          why = "monitors and downloads Microsoft app updates" },
        { m = "onedrive",       what = "OneDrive sync engine",
          why = "keeps your OneDrive folder in sync — the Logs folder rides on it" },
        { m = "^apsd$",         what = "Apple Push Notification service",
          why = "the one persistent connection every notification arrives over" },
        { m = "identityservicesd", what = "Apple identity services",
          why = "iMessage/FaceTime/iCloud account sessions" },
        { m = "^cloudd$",       what = "iCloud sync daemon",
          why = "documents, photos and app data syncing with iCloud" },
        { m = "^trustd$",       what = "certificate verifier",
          why = "checks TLS certificates against Apple's revocation servers" },
        { m = "^rapportd$",     what = "device-to-device link (Handoff/AirDrop)",
          why = "finds and talks to your other Apple devices nearby" },
        { m = "hammerspoon",    what = "this config",
          why = "Asana calls, and whichever tool you just ran" },
        { m = "chrome",         what = "Google Chrome (or one of its site processes)",
          why = "the pages, extensions and sync you have open" },
        { m = "safari",         what = "Safari (or one of its page processes)",
          why = "the pages you have open" },
        { m = "slack",          what = "Slack", why = "its persistent message socket" },
        { m = "zoom",           what = "Zoom",  why = "meeting or pre-meeting keepalive" },
        { m = "teams",          what = "Microsoft Teams",
          why = "its persistent message/call socket" },
        { m = "spotify",        what = "Spotify", why = "audio streaming and its cache" },
        { m = "vlc",            what = "VLC",
          why = "a network stream, or its update check" },
        -- domain rules (checked against resolved names, after processes)
        { m = "office%.com",    what = "a Microsoft Office cloud endpoint",
          why = "document sync, licensing or telemetry to Microsoft's cloud" },
        { m = "microsoft",      what = "a Microsoft service",
          why = "updates, licensing or telemetry" },
        { m = "windowsupdate",  what = "Microsoft's update CDN",
          why = "downloads Microsoft app updates" },
        { m = "apple%.com",     what = "an Apple service",
          why = "updates, push, iCloud or certificate checks" },
        { m = "icloud",         what = "iCloud", why = "account or data sync" },
        { m = "akamai",         what = "the Akamai CDN",
          why = "static content — many vendors' updates and media ride on it" },
        { m = "cloudfront",     what = "Amazon's CloudFront CDN",
          why = "static content served from an edge node" },
        { m = "fastly",         what = "the Fastly CDN",
          why = "static content served from an edge node" },
        { m = "amazonaws",      what = "a service hosted on AWS",
          why = "whichever vendor rents this address — the app column says who asked" },
        { m = "googleapis",     what = "a Google API endpoint",
          why = "sync, safe-browsing lists, or an app using Google's cloud" },
        { m = "1e100%.net",     what = "Google's serving infrastructure",
          why = "any Google-backed page or service" },
        { m = "azure",          what = "a service hosted on Microsoft Azure",
          why = "whichever vendor rents this address — the app column says who asked" },
    }

    nw.conns   = {}      -- the parsed snapshot: { cmd, pid, proto, remote, state }
    nw.apps    = {}      -- aggregated per app, in row order
    nw.dns     = {}      -- ip -> resolved name | false (tried, no answer)
    nw.dnsQ    = {}      -- ips waiting for a lookup
    nw.chooser = nil     -- HELD
    nw.task    = nil     -- HELD: the running lsof
    nw.dnsTask = nil     -- HELD: the running dscacheutil
    nw.dnsWatch = nil    -- HELD: its per-lookup deadline
    nw.watch   = nil     -- HELD: the lsof deadline
    nw.scanAt  = nil
    nw.scanMs  = 0
    nw.lastErr = nil

    local function say(m)  if _G.diag then _G.diag.say("netWatch", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("netWatch", m) end end

    -- ---- parsing ---------------------------------------------------------
    -- lsof -F: records begin p<pid> / c<command>; every network file then
    -- contributes P<proto> and n<name>, with TST=<state> for TCP. The
    -- name is "local->remote" for a peer, plain "addr:port" or "*:port"
    -- for a listener.
    function nw.parse(out)
        local conns = {}
        local pid, cmd, proto = nil, nil, nil
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local tag, rest = line:sub(1, 1), line:sub(2)
            if tag == "p" then
                pid, cmd, proto = tonumber(rest), nil, nil
            elseif tag == "c" then
                cmd = rest
            elseif tag == "P" then
                proto = rest
            elseif tag == "n" then
                local localEnd, remote = rest:match("^(.-)%->(.+)$")
                conns[#conns + 1] = {
                    cmd = cmd or "?", pid = pid or 0, proto = proto or "?",
                    localEnd = localEnd or rest,
                    remote = remote,            -- nil = a listener
                    state = nil,
                }
            elseif tag == "T" then
                local st = rest:match("^ST=(.+)$")
                if st and conns[#conns] then conns[#conns].state = st end
            end
        end
        return conns
    end

    function nw.ipOf(remote)
        if type(remote) ~= "string" then return nil end
        -- v6 arrives as [2620:149:a44::4]:443 — the brackets are the split
        local v6 = remote:match("^%[(.-)%]")
        if v6 then return v6 end
        return remote:match("^([%d%.]+):") or remote:match("^([%d%.]+)$")
    end

    function nw.isPrivate(ip)
        if type(ip) ~= "string" then return false end
        if ip:match("^10%.") or ip:match("^127%.") or ip:match("^169%.254%.")
           or ip:match("^192%.168%.") then return true end
        local second = tonumber(ip:match("^172%.(%d+)%."))
        if second and second >= 16 and second <= 31 then return true end
        if ip:match("^f[cde]") or ip:match("^::1$") or ip:match("^fe80") then
            return true
        end
        return false
    end

    -- One line per remote end: "TCP 1.2.3.4:443 (ESTABLISHED) → name"
    function nw.remoteName(ip)
        if not ip then return nil end
        if nw.isPrivate(ip) then return "local network" end
        local r = nw.dns[ip]
        if r == nil then return "resolving…" end
        if r == false then return "no reverse name" end
        return r
    end

    -- ---- aggregation -----------------------------------------------------
    function nw.aggregate(conns)
        local byApp, order = {}, {}
        for _, c in ipairs(conns) do
            local name = c.cmd or "?"
            -- a GUI app's display name beats its process name when
            -- Hammerspoon knows the pid ("Electron" → "Slack")
            local okA, app = pcall(hs.application.applicationForPID, c.pid)
            if okA and app then
                local okN, n = pcall(function() return app:name() end)
                if okN and type(n) == "string" and n ~= "" then name = n end
            end
            local rec = byApp[name]
            if not rec then
                rec = { name = name, pids = {}, conns = {}, listeners = 0 }
                byApp[name] = rec
                order[#order + 1] = rec
            end
            rec.pids[c.pid] = true
            if c.remote then
                rec.conns[#rec.conns + 1] = c
            else
                rec.listeners = rec.listeners + 1
            end
        end
        -- the busiest talkers first; pure listeners sink to the bottom
        table.sort(order, function(a, b)
            if #a.conns ~= #b.conns then return #a.conns > #b.conns end
            return a.name:lower() < b.name:lower()
        end)
        return order
    end

    -- what/why for one app, from its name and its resolved remotes
    function nw.explain(rec)
        local hay = { rec.name:lower() }
        for _, c in ipairs(rec.conns) do
            local name = nw.remoteName(nw.ipOf(c.remote))
            if name and name ~= "resolving…" and name ~= "no reverse name"
               and name ~= "local network" then
                hay[#hay + 1] = name:lower()
            end
        end
        for _, rule in ipairs(nw.known) do
            for _, h in ipairs(hay) do
                if h:find(rule.m) then
                    return rule.what, rule.why, true
                end
            end
        end
        return "unrecognized — the paths below show exactly where it connects",
               "no rule matches this name; judge it by its remote ends", false
    end

    -- ---- reports ---------------------------------------------------------
    function nw.appReport(rec)
        local what, why = nw.explain(rec)
        local pids = {}
        for p in pairs(rec.pids) do pids[#pids + 1] = p end
        table.sort(pids)
        local L = {}
        L[#L + 1] = string.format("%s (pid %s) — %d connection%s%s",
            rec.name, table.concat(pids, ", "), #rec.conns,
            #rec.conns == 1 and "" or "s",
            rec.listeners > 0 and (" · " .. rec.listeners .. " listening") or "")
        L[#L + 1] = "   what : " .. what
        L[#L + 1] = "   why  : " .. why
        for _, c in ipairs(rec.conns) do
            local ip = nw.ipOf(c.remote)
            L[#L + 1] = string.format("   path : %s %s → %s%s",
                c.proto or "?", c.localEnd or "?", c.remote or "?",
                c.state and (" (" .. c.state .. ")") or "")
            local name = nw.remoteName(ip)
            if name then
                L[#L + 1] = "          " .. tostring(ip) .. " resolves to " .. name
            end
        end
        return table.concat(L, "\n")
    end

    function nw.fullReport()
        local L = {
            "🌐 WHO'S TALKING — " .. tostring(core.hostTag or "this Mac")
                .. ", " .. os.date("%Y-%m-%d %H:%M:%S", nw.scanAt or os.time()),
            "(your processes only — root's daemons need admin, and lsof runs without it)",
            "",
        }
        if #nw.apps == 0 then
            L[#L + 1] = nw.lastErr
                        and ("nothing listed — " .. nw.lastErr)
                        or  "no app of yours holds a network connection right now"
        end
        for _, rec in ipairs(nw.apps) do
            L[#L + 1] = nw.appReport(rec)
            L[#L + 1] = ""
        end
        return table.concat(L, "\n")
    end

    local function copy(text, label)
        local ok = false
        pcall(function() ok = hs.pasteboard.setContents(text) ~= false end)
        pcall(function()
            hs.alert.show(ok and ("🌐 " .. label .. " copied")
                          or "🌐 Could not reach the clipboard", 2.5)
        end)
        return ok and text or nil
    end

    -- ---- the picker ------------------------------------------------------
    function nw.rows()
        local rows = {
            { text = "📋 Copy the FULL network report",
              subText = (#nw.apps) .. " talking apps · every path, resolved — ⌘1",
              act = "all" },
        }
        for i, rec in ipairs(nw.apps) do
            local what = select(1, nw.explain(rec))
            local remotes, seen = {}, {}
            for _, c in ipairs(rec.conns) do
                local name = nw.remoteName(nw.ipOf(c.remote))
                if name and not seen[name] then
                    seen[name] = true
                    remotes[#remotes + 1] = name
                    if #remotes >= nw.remoteShow then break end
                end
            end
            rows[#rows + 1] = {
                text = string.format("🖥  %s — %d connection%s", rec.name,
                        #rec.conns, #rec.conns == 1 and "" or "s"),
                subText = (#remotes > 0 and (table.concat(remotes, " · ") .. "   ·   ")
                           or "") .. what,
                idx = i,
            }
        end
        return rows
    end

    -- Re-set the rows as resolutions land, so "resolving…" becomes a
    -- name under your cursor — but only while the panel is actually up.
    function nw.refreshChooser()
        if not nw.chooser then return end
        local visible = false
        pcall(function() visible = nw.chooser:isVisible() end)
        if not visible then return end
        pcall(function() nw.chooser:choices(nw.rows()) end)
    end

    -- ---- reverse DNS, one at a time --------------------------------------
    function nw.resolveNext()
        if nw.dnsTask then return end
        local ip = table.remove(nw.dnsQ, 1)
        if not ip then
            nw.refreshChooser()
            return
        end
        if nw.dns[ip] ~= nil then return nw.resolveNext() end
        local t
        local okNew = pcall(function()
            t = hs.task.new(nw.DSCACHEUTIL, function(_, sout)
                nw.dnsTask = nil
                local name = tostring(sout or ""):match("name:%s*(%S+)")
                nw.dns[ip] = name or false
                nw.refreshChooser()
                nw.resolveNext()
            end, { "-q", "host", "-a", "ip_address", ip })
            t:start()
        end)
        if not (okNew and t) then
            nw.dns[ip] = false
            return nw.resolveNext()
        end
        nw.dnsTask = t
        -- a lookup that hangs is answered "no name" and the queue moves
        -- on. The deadline is HELD (nw.dnsWatch) — the whole-file audit
        -- rightly refuses a discarded timer, which macOS may collect
        -- before it ever fires.
        pcall(function()
            local held = t
            nw.dnsWatch = hs.timer.doAfter(nw.dnsTimeout, function()
                if nw.dnsTask == held then
                    pcall(function() held:terminate() end)
                    nw.dnsTask = nil
                    nw.dns[ip] = nw.dns[ip] or false
                    nw.resolveNext()
                end
            end)
        end)
    end

    function nw.queueDns()
        local queued, n = {}, 0
        nw.dnsQ = {}
        for _, rec in ipairs(nw.apps) do
            for _, c in ipairs(rec.conns) do
                local ip = nw.ipOf(c.remote)
                if ip and not nw.isPrivate(ip) and nw.dns[ip] == nil
                   and not queued[ip] then
                    queued[ip] = true
                    n = n + 1
                    if n > nw.dnsMax then break end
                    nw.dnsQ[#nw.dnsQ + 1] = ip
                end
            end
        end
        nw.resolveNext()
    end

    -- ---- the snapshot ----------------------------------------------------
    function nw.scan(andThen)
        if nw.task then return false end
        local started = hs.timer.secondsSinceEpoch
                        and hs.timer.secondsSinceEpoch() or os.time()
        local t
        local okNew = pcall(function()
            t = hs.task.new(nw.LSOF, function(code, sout, serr)
                nw.task = nil
                if nw.watch then
                    pcall(function() nw.watch:stop() end)
                    nw.watch = nil
                end
                local now = hs.timer.secondsSinceEpoch
                              and hs.timer.secondsSinceEpoch() or os.time()
                nw.scanMs = math.floor((now - started) * 1000)
                nw.scanAt = os.time()
                -- lsof exits 1 when SOME process refused it — with output
                -- still on stdout. Only an EMPTY answer is a failure.
                nw.conns = nw.parse(sout)
                if #nw.conns == 0 and code ~= 0 then
                    nw.lastErr = "lsof exited " .. tostring(code) .. " — "
                                 .. tostring(serr or ""):sub(1, 120)
                    warn(nw.lastErr)
                else
                    nw.lastErr = nil
                end
                nw.apps = nw.aggregate(nw.conns)
                say(string.format("%d connections across %d apps in %dms",
                    #nw.conns, #nw.apps, nw.scanMs))
                nw.queueDns()
                if andThen then andThen() end
            end, { "-i", "-n", "-P", "-w", "+c", "0", "-FpcnPT" })
            t:start()
        end)
        if not (okNew and t) then
            nw.lastErr = "could not start lsof"
            warn(nw.lastErr)
            pcall(function() hs.alert.show("🌐 lsof unavailable", 3) end)
            return false
        end
        nw.task = t
        local okDog, dog = pcall(hs.timer.doAfter, nw.lsofTimeout, function()
            nw.watch = nil
            if nw.task then
                pcall(function() nw.task:terminate() end)
                nw.task = nil
                nw.lastErr = "lsof took over " .. nw.lsofTimeout .. "s and was stopped"
                warn(nw.lastErr)
                pcall(function() hs.alert.show("🌐 " .. nw.lastErr, 4) end)
            end
        end)
        nw.watch = okDog and dog or nil
        return true
    end

    function nw.show()
        if not nw.enabled then return end
        nw.scan(function()
            if not nw.chooser then
                -- ⚠️ each row carries `act` or `idx` — SCALARS, which
                -- survive the trip through Objective-C (a nested table
                -- would not; see app_kill's header on that trap).
                nw.chooser = hs.chooser.new(function(pick)
                    if not pick then return end
                    if pick.act == "all" then
                        copy(nw.fullReport(), "Full network report")
                        return
                    end
                    local rec = pick.idx and nw.apps[pick.idx]
                    if rec then
                        copy(nw.appReport(rec), rec.name .. " report")
                    end
                end)
                _G.choosers = _G.choosers or {}
                _G.choosers.netWatch = nw.chooser
                pcall(function()
                    nw.chooser:searchSubText(true)
                    nw.chooser:width(48)
                end)
            end
            nw.chooser:choices(nw.rows())
            nw.chooser:placeholderText(string.format(
                "%d apps talking · ⏎ one report · ⌘1 everything · %dms snapshot",
                #nw.apps, nw.scanMs))
            nw.chooser:query("")
            if core.showPopup then core.showPopup(nw.chooser)
            else nw.chooser:show() end
        end)
    end

    -- ---- console twin ----------------------------------------------------
    function _G.netWatchReport()
        local s = nw.fullReport()
        print(s)
        return s
    end

    if nw.enabled then
        core.hyperAddShortcut(nw.keyMods, nw.key, function() nw.show() end,
                              "net watch")
    end
    core.provide("netwatch.show",   function() return nw.show() end)
    core.provide("netwatch.report", function() return _G.netWatchReport() end)

    _G.netWatch = nw
    M.nw     = nw
    M.config = nw
end

return M
