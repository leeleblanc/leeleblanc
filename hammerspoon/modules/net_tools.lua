-- =====================================================================
-- MODULE: NETWORK TOOLS (⇪6) — report · refresh · flush · ping · dig · …
-- =====================================================================
-- LL: "Give me network tools that are / flush / ping / nslookup /
-- traceroute" — and, 6.154.0: "run multiple commands and build a report
-- that tells us what is going on", "a picker that describes and then
-- executes the commands", and a cleaner that is "very safe. I do not
-- want to disable or kill or cause conflicts with my network configs."
--
-- ⇪6 lists them, every row saying what it tells you. Pick one that
-- needs a host and a second box opens where whatever you type IS the
-- host — no dialog, no form. The output comes back as a searchable list,
-- one row per line, and the whole thing is on the clipboard before you
-- have read it. The 🩺 report is also saved to the Logs folder.
--
--        ⇪6         twelve tools · ⏎ runs one
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
        title = "🌐 NETWORK TOOLS (⇪6 — report · refresh · ping · dig · race · …)",
        entries = {
            { "⇪6",     "Twelve tools, each row saying what it tells you — ⏎ runs one" },
            { "🩺 report","IP · router · internet · DNS speed · Wi-Fi · VPN · portal → a VERDICT" },
            { "",       "naming the first broken link; saved to Logs/net_report-<Mac>.txt" },
            { "🧹 refresh","Flush DNS then the report — nothing disabled, killed or reconfigured" },
            { "🏁 race", "Which resolver answers fastest from here (you change it, by hand)" },
            { "host",   "Type it in the second box; the clipboard prefills it" },
            { "output", "One row per line, searchable — ⏎ copies that line," },
            { "",       "and the whole output is on the clipboard already" },
            { "flush",  "Runs both halves and says which one worked — the" },
            { "",       "mDNSResponder half needs admin and cannot on the work Mac" },
            { "🚀 speed","speedtest-cli if Homebrew has it; the row says how to install it" },
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
    -- `timeout` (6.154.0) lets one caller ask for longer than nt.timeout —
    -- a speed test genuinely takes half a minute; nothing else does.
    function nt.run(bin, args, label, done, timeout)
        timeout = timeout or nt.timeout
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
        hs.alert.show("🌐 " .. label .. "…", timeout)
        nt.timer = hs.timer.doAfter(timeout, function()
            nt.timer = nil
            if nt.task ~= t then return end
            pcall(function() t:terminate() end)
            nt.task, nt.running = nil, nil
            note(label .. " did not finish within " .. timeout .. "s")
            hs.alert.show("🌐 " .. label .. " gave up after "
                .. timeout .. "s", 4)
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
    -- 6.154.0 — the report's questions. Every one ships with macOS and
    -- every one only READS (see THE REPORT below); they reach the script
    -- as positional arguments, never as text inside it, for the reason
    -- the 🚨 above gives.
    nt.DIG      = "/usr/bin/dig"
    nt.ROUTE    = "/sbin/route"
    nt.NETSETUP = "/usr/sbin/networksetup"
    nt.IFCONFIG = "/sbin/ifconfig"
    nt.SCUTIL   = "/usr/sbin/scutil"
    nt.ARP      = "/usr/sbin/arp"
    nt.NETSTAT  = "/usr/sbin/netstat"
    nt.CURL     = "/usr/bin/curl"
    nt.IPCONFIG = "/usr/sbin/ipconfig"
    nt.SED      = "/usr/bin/sed"
    nt.PING     = "/sbin/ping"

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

    -- =====================================================================
    -- 🩺 THE REPORT (6.154.0)
    -- =====================================================================
    -- LL: "can we use the command line to run multiple commands and build
    -- a report that tells us what is going on" — and, for the refresh:
    -- "something that when run it cleans our network connections so that
    -- are optimal and fast? But, we must be very safe. I do not want to
    -- disable or kill or cause conflicts with my network configs."
    --
    -- ONE /bin/sh RUN, FOURTEEN READ-ONLY QUESTIONS, ONE VERDICT. The
    -- script below asks, in order: which ports exist, which have an IP,
    -- the Wi-Fi network, the default router, the resolvers, three pings
    -- to the router and three to 1.1.1.1 (the internet with no DNS in
    -- the way), a timed DNS lookup, the same lookup raced against three
    -- public resolvers, the public IP (asked of OpenDNS by DNS — no web
    -- page), Apple's captive-portal check, the tunnels and VPN
    -- configurations, the routing table and the ARP cache. Each answer
    -- lands under an "@@ name" marker; the Lua side parses the facts and
    -- reasons from them TOP DOWN — no IP, then no router, then a router
    -- that will not answer, then an internet that will not, then names
    -- that will not resolve, then a portal in the way — so the verdict
    -- names the FIRST broken link, which is the one to fix.
    --
    -- 🚨 WHAT "SAFE" MEANS HERE, PRECISELY. Every command in the script
    -- reads. The refresh variant adds exactly the two lines the existing
    -- Flush DNS tool has run since 6.120.0 — empty the directory-service
    -- cache, and ask mDNSResponder to reload with SIGHUP — and reports
    -- each half as the flush always has. NOTHING is switched off, no
    -- interface is bounced, no lease is renewed, no route is flushed, no
    -- ARP entry is deleted, no DNS server is set, no sudo is attempted.
    -- Those are what the "network cleaners" on the internet do, every
    -- one of them needs admin or drops your connection for a moment, and
    -- every one is what LL ruled out. What this DOES do is tell you what
    -- would help and where to change it by hand (the DNS race is the
    -- usual answer). test_net_tools pins the banned verbs by name.
    --
    -- Every wait is bounded in the arguments (ping -c/-i/-t, dig
    -- +time/+tries, curl -m) and the whole run has nt.run's deadline.
    -- Paths reach the script as $1…$13; the mode is $14. No user input
    -- ever touches this script.
    local REPORT_SCRIPT = [[
dig="$1"; route="$2"; ns="$3"; ifc="$4"; scu="$5"; arp="$6"; ping="$7"; curl="$8"
ipc="$9"; sed="${10}"; nst="${11}"; dsc="${12}"; kil="${13}"; mode="${14}"
sec() { printf '\n@@ %s\n' "$1"; }
if [ "$mode" = "refresh" ]; then
  sec flush
  "$dsc" -flushcache 2>&1; echo "DSCACHE_RC=$?"
  "$kil" -HUP mDNSResponder 2>&1; echo "MDNS_RC=$?"
fi
sec ports
"$ns" -listallhardwareports 2>&1
sec addr
for d in en0 en1 en2 en3; do
  ip=$("$ipc" getifaddr "$d" 2>/dev/null)
  [ -n "$ip" ] && printf '%s %s\n' "$d" "$ip"
done
sec wifi
"$ns" -getairportnetwork en0 2>&1
"$ipc" getsummary en0 2>/dev/null | "$sed" -n -e 's/^ *SSID : /SSID: /p' -e 's/^ *Security : /Security: /p'
sec gateway
"$route" -n get default 2>&1
gw=$("$route" -n get default 2>/dev/null | "$sed" -n 's/^ *gateway: //p')
sec dns
"$scu" --dns 2>/dev/null | "$sed" -n '/^resolver #1$/,/^resolver #2$/p'
sec pinggw
if [ -n "$gw" ]; then "$ping" -c 3 -i 0.2 -t 4 "$gw" 2>&1; else echo "no gateway to ping"; fi
sec ping1
"$ping" -c 3 -i 0.2 -t 4 1.1.1.1 2>&1
sec dnstime
"$dig" +time=2 +tries=1 apple.com 2>&1
sec race
for r in 1.1.1.1 8.8.8.8 9.9.9.9; do
  "$dig" +time=2 +tries=1 "@$r" apple.com 2>&1 | "$sed" -n -e '/^;; Query time/p' -e '/^;; SERVER/p'
done
sec public
"$dig" +short +time=2 +tries=1 myip.opendns.com @resolver1.opendns.com 2>&1
sec captive
"$curl" -sS -m 4 -o /dev/null -w '%{http_code} %{time_total}\n' http://captive.apple.com/hotspot-detect.html 2>&1
sec vpn
"$ifc" -l 2>&1
"$scu" --nc list 2>&1
sec routes
"$nst" -rn -f inet 2>&1
sec arp
"$arp" -a 2>&1
sec done
]]
    nt.reportTimeout = 60         -- the whole run; each question is bounded on its own
    nt.reportFile = (core.logsDir or hs.configdir or "/tmp") .. "/net_report-"
                    .. tostring(core.hostTag or "Mac") .. ".txt"
    -- rewritten whole every run — the write ledger must not call that a truncation
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[nt.reportFile] = "the ⇪6 network report — rewritten on every run"
    nt.lastReport = nil

    -- "@@ name" markers → { name = { lines } }
    function nt.sections(text)
        local out, cur = {}, nil
        for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do
            local name = line:match("^@@ (%S+)")
            if name then
                cur = name
                out[cur] = out[cur] or {}
            elseif cur and line:match("%S") then
                table.insert(out[cur], line)
            end
        end
        return out
    end

    local function pingStats(lines)
        local s = {}
        for _, l in ipairs(lines or {}) do
            local tx, rx, loss = l:match("(%d+) packets transmitted, (%d+) packets received, ([%d%.]+)%% packet loss")
            if tx then s.sent, s.recv, s.loss = tonumber(tx), tonumber(rx), tonumber(loss) end
            local avg = l:match("round%-trip min/avg/max/stddev = [%d%.]+/([%d%.]+)/")
            if avg then s.avg = tonumber(avg) end
        end
        if s.sent == nil then return nil end
        return s
    end

    local function pingWords(s)
        if not s then return "no answer" end
        return string.format("%d/%d answered%s", s.recv or 0, s.sent or 0,
                             s.avg and string.format(", avg %.0f ms", s.avg) or "")
    end

    -- The script's output → facts. Every field is optional: a question
    -- that failed leaves its fact nil, and the verdict reads nil as "we
    -- could not tell", never as "fine".
    function nt.parseReport(text)
        local S = nt.sections(text)
        local r = { sections = S, addr = {}, ports = {}, dns = {}, race = {},
                    tunnels = {}, vpns = {} }
        if S.flush then
            local j = table.concat(S.flush, "\n")
            r.flush = { ds = tonumber(j:match("DSCACHE_RC=(%d+)")),
                        mdns = tonumber(j:match("MDNS_RC=(%d+)")) }
        end
        local port
        for _, l in ipairs(S.ports or {}) do
            local p = l:match("^Hardware Port: (.+)$")
            local d = l:match("^Device: (%S+)")
            if p then port = p elseif d and port then r.ports[d] = port end
        end
        for _, l in ipairs(S.addr or {}) do
            local d, ip = l:match("^(%S+) (%d+%.%d+%.%d+%.%d+)")
            if d then r.addr[#r.addr + 1] = { dev = d, ip = ip } end
        end
        for _, l in ipairs(S.wifi or {}) do
            r.ssid = r.ssid or l:match("^Current Wi%-Fi Network: (.+)$")
                     or l:match("^SSID: (.+)$")
            r.wifiSecurity = r.wifiSecurity or l:match("^Security: (.+)$")
            if l:find("not associated", 1, true) then r.wifiOff = true end
        end
        for _, l in ipairs(S.gateway or {}) do
            r.gateway = r.gateway or l:match("^%s*gateway: (%S+)")
            r.gwDev   = r.gwDev   or l:match("^%s*interface: (%S+)")
        end
        for _, l in ipairs(S.dns or {}) do
            local ip = l:match("nameserver%[%d+%] : (%S+)")
            if ip then r.dns[#r.dns + 1] = ip end
        end
        r.pingGw = pingStats(S.pinggw)
        r.ping1  = pingStats(S.ping1)
        for _, l in ipairs(S.dnstime or {}) do
            r.dnsMs = r.dnsMs or tonumber(l:match("Query time: (%d+) msec"))
            r.dnsServer = r.dnsServer or l:match("SERVER: ([^#%s]+)")
        end
        local pending
        for _, l in ipairs(S.race or {}) do
            local ms = tonumber(l:match("Query time: (%d+) msec"))
            if ms then pending = ms end
            local srv = l:match("SERVER: ([^#%s]+)")
            if srv then
                r.race[#r.race + 1] = { server = srv, ms = pending }
                pending = nil
            end
        end
        table.sort(r.race, function(a, b) return (a.ms or 1e9) < (b.ms or 1e9) end)
        for _, l in ipairs(S.public or {}) do
            r.publicIp = r.publicIp or l:match("^(%d+%.%d+%.%d+%.%d+)$")
        end
        for _, l in ipairs(S.captive or {}) do
            local code, secs = l:match("^(%d%d%d) ([%d%.]+)")
            if code then r.captiveCode, r.captiveSecs = tonumber(code), tonumber(secs) end
        end
        for _, l in ipairs(S.vpn or {}) do
            for u in l:gmatch("utun%d+") do r.tunnels[#r.tunnels + 1] = u end
            local name = l:match("%(Connected%).-\"([^\"]+)\"")
            if name then r.vpns[#r.vpns + 1] = name end
        end
        r.routeCount = #(S.routes or {})
        r.arpCount   = 0
        for _, l in ipairs(S.arp or {}) do
            if l:find(" at ", 1, true) then r.arpCount = r.arpCount + 1 end
        end
        return r
    end

    -- Top down: the FIRST broken link is the one to fix. Returns the
    -- verdict lines and the by-hand tips.
    function nt.verdict(r)
        local L, tips = {}, {}
        local ip = r.addr[1]
        if not ip then
            L[#L + 1] = "❌ No IP address on any interface — this Mac is not on a "
                        .. "network (Wi-Fi off, or no DHCP lease)"
            return L, tips
        end
        if not r.gateway then
            L[#L + 1] = "❌ No default router — on a network that is not routing "
                        .. "(router down, or DHCP handed out no router)"
            return L, tips
        end
        local gw, inet = r.pingGw, r.ping1
        if gw and gw.loss and gw.loss >= 100 then
            L[#L + 1] = string.format("❌ The router (%s) does not answer — a LOCAL "
                .. "problem: Wi-Fi signal, or the router itself", r.gateway)
        elseif gw and gw.loss and gw.loss > 0 then
            L[#L + 1] = string.format("⚠️ %.0f%% packet loss to the router — Wi-Fi "
                .. "signal or interference", gw.loss)
        elseif gw and gw.avg and gw.avg > 50 then
            L[#L + 1] = string.format("⚠️ Slow to the router (%.0f ms; wired is ~1, "
                .. "Wi-Fi 2–10) — congestion or a weak signal", gw.avg)
            tips[#tips + 1] = "The slow hop is INSIDE your home: closer to the router, "
                              .. "or its 5 GHz band"
        end
        if inet and inet.loss and inet.loss >= 100 then
            if not (gw and gw.loss and gw.loss >= 100) then
                L[#L + 1] = "❌ Router reachable but the internet is not (1.1.1.1 silent) "
                            .. "— the ISP / upstream link, not this Mac"
            end
        elseif inet and inet.loss and inet.loss > 0 then
            L[#L + 1] = string.format("⚠️ %.0f%% loss to the internet (1.1.1.1)", inet.loss)
        end
        local inetOk = inet and inet.loss and inet.loss < 100
        if not r.dnsMs then
            if inetOk then
                L[#L + 1] = "❌ DNS is the problem — addresses work, NAMES do not. "
                            .. "⇪6 → Flush DNS; failing that, set 1.1.1.1 as the resolver"
            end
        elseif r.dnsMs > 100 then
            L[#L + 1] = string.format("⚠️ DNS is slow — %d ms via %s (under 30 is normal)",
                                      r.dnsMs, r.dnsServer or "?")
        end
        if r.captiveCode and r.captiveCode ~= 200 then
            L[#L + 1] = string.format("⚠️ Captive portal or HTTP blocked — captive.apple.com "
                .. "answered %d, not 200. Open a browser page to log in", r.captiveCode)
        elseif not r.captiveCode and inetOk then
            L[#L + 1] = "⚠️ HTTP did not get through (no status from curl) though pings "
                        .. "do — a proxy or firewall in the way?"
        end
        if #r.vpns > 0 then
            L[#L + 1] = "🔒 VPN connected: " .. table.concat(r.vpns, ", ")
                        .. " — everything above went through it"
        end
        local fastest = r.race[1]
        if fastest and fastest.ms and r.dnsMs and fastest.ms + 15 < r.dnsMs then
            tips[#tips + 1] = string.format("%s answers in %d ms vs your resolver's %d ms — "
                .. "set it in System Settings → Wi-Fi → Details → DNS (this tool never "
                .. "changes network settings itself)", fastest.server, fastest.ms, r.dnsMs)
        end
        if #L == 0 then
            L[1] = string.format("✅ All good — %s on %s · router %s · internet %s · DNS %s",
                ip.ip, r.ports[ip.dev] or ip.dev,
                gw and gw.avg and string.format("%.0f ms", gw.avg) or "?",
                inet and inet.avg and string.format("%.0f ms", inet.avg) or "?",
                r.dnsMs and string.format("%d ms via %s", r.dnsMs, r.dnsServer or "?") or "?")
        end
        return L, tips
    end

    function nt.reportText(r, title)
        local L = { "🩺 " .. (title or "NETWORK REPORT") .. " — "
                    .. os.date("%Y-%m-%d %H:%M") .. " · " .. tostring(core.hostTag or "Mac"), "" }
        if r.flush then
            L[#L + 1] = "🧹 REFRESH — the only step that changed anything:"
            L[#L + 1] = (r.flush.ds == 0)
                and "   ✅ dscacheutil -flushcache — the directory-service cache is empty"
                or  ("   ❌ dscacheutil -flushcache failed (exit " .. tostring(r.flush.ds) .. ")")
            L[#L + 1] = (r.flush.mdns == 0)
                and "   ✅ killall -HUP mDNSResponder — the resolver was reset"
                or  ("   ⚪️ the mDNSResponder half needs admin (exit " .. tostring(r.flush.mdns)
                     .. ") — toggle Wi-Fi off and on to finish it; nothing else was touched")
            L[#L + 1] = ""
        end
        local V, tips = nt.verdict(r)
        L[#L + 1] = "VERDICT"
        for _, v in ipairs(V) do L[#L + 1] = "   " .. v end
        if #tips > 0 then
            L[#L + 1] = ""
            L[#L + 1] = "WHAT WOULD HELP — by hand; this tool changes no settings"
            for _, t in ipairs(tips) do L[#L + 1] = "   💡 " .. t end
        end
        L[#L + 1] = ""
        L[#L + 1] = "FACTS"
        if #r.addr == 0 then L[#L + 1] = "   IP        : none" end
        for _, a in ipairs(r.addr) do
            L[#L + 1] = string.format("   IP        : %s on %s (%s)", a.ip, a.dev,
                                      r.ports[a.dev] or "?")
        end
        L[#L + 1] = "   Wi-Fi     : " .. (r.ssid or (r.wifiOff and "not associated" or "unknown"))
                    .. (r.wifiSecurity and (" · " .. r.wifiSecurity) or "")
        L[#L + 1] = "   router    : " .. (r.gateway or "none")
                    .. (r.gwDev and (" via " .. r.gwDev) or "")
                    .. " · " .. pingWords(r.pingGw)
        L[#L + 1] = "   internet  : 1.1.1.1 · " .. pingWords(r.ping1)
        L[#L + 1] = "   DNS       : " .. (#r.dns > 0 and table.concat(r.dns, ", ") or "none listed")
                    .. (r.dnsMs and string.format(" · apple.com in %d ms via %s", r.dnsMs,
                                                  r.dnsServer or "?")
                        or " · lookup FAILED")
        if #r.race > 0 then
            local parts = {}
            for _, x in ipairs(r.race) do
                parts[#parts + 1] = x.server .. " " .. (x.ms and (x.ms .. " ms") or "—")
            end
            L[#L + 1] = "   DNS race  : " .. table.concat(parts, " · ") .. "  (fastest first)"
        end
        L[#L + 1] = "   public IP : " .. (r.publicIp or "unknown — the DNS question got no answer")
        L[#L + 1] = "   web check : " .. (r.captiveCode
            and string.format("captive.apple.com → %d in %.2fs", r.captiveCode, r.captiveSecs or 0)
            or "no HTTP status")
        L[#L + 1] = "   tunnels   : " .. (#r.tunnels > 0
            and (table.concat(r.tunnels, ", ") .. " (a VPN app uses one; so do Apple's own services)")
            or "none")
            .. (#r.vpns > 0 and (" · VPN connected: " .. table.concat(r.vpns, ", ")) or "")
        L[#L + 1] = string.format("   LAN       : %d device%s in the arp cache · %d routes",
                                  r.arpCount, r.arpCount == 1 and "" or "s", r.routeCount)
        L[#L + 1] = ""
        L[#L + 1] = "RAW — every command was read-only; each answer as it came"
        for _, name in ipairs({ "flush", "ports", "addr", "wifi", "gateway", "dns", "pinggw",
                                "ping1", "dnstime", "race", "public", "captive", "vpn",
                                "routes", "arp" }) do
            local lines = r.sections[name]
            if lines and #lines > 0 then
                L[#L + 1] = "   ── " .. name
                for _, l in ipairs(lines) do L[#L + 1] = "   " .. l end
            end
        end
        return table.concat(L, "\n")
    end

    function nt.saveReport(text)
        -- said again at write time, so a profile that moved the file
        -- still has it registered
        _G.rewrittenFiles = _G.rewrittenFiles or {}
        _G.rewrittenFiles[nt.reportFile] = "the ⇪6 network report — rewritten on every run"
        local ok = pcall(function()
            local f = io.open(nt.reportFile, "w")
            if not f then error("unwritable") end
            f:write(text, "\n")
            f:close()
        end)
        if not ok then warn("could not write " .. nt.reportFile) end
        return ok
    end

    -- mode: "report" (read-only) or "refresh" (the flush first — see the
    -- 🚨 above for exactly what that is and is not)
    function nt.report(mode)
        mode = (mode == "refresh") and "refresh" or "report"
        local label = (mode == "refresh") and "Refresh & verify" or "Network report"
        return nt.run("/bin/sh", {
            "-c", REPORT_SCRIPT, "hs-net-report",
            nt.DIG, nt.ROUTE, nt.NETSETUP, nt.IFCONFIG, nt.SCUTIL, nt.ARP, nt.PING,
            nt.CURL, nt.IPCONFIG, nt.SED, nt.NETSTAT, nt.DSCACHE, nt.KILLALL, mode,
        }, label, function(code, text)
            local r = nt.parseReport(text)
            local out = nt.reportText(r, label:upper())
            local V = nt.verdict(r)
            nt.lastReport = { at = os.time(), mode = mode, verdict = V, facts = r }
            nt.history[#nt.history + 1] = { tool = mode, host = "-",
                                            ms = nt.lastMs, ok = code == 0 }
            nt.saveReport(out)
            nt.showOutput(label, out)
        end, nt.reportTimeout)
    end

    -- ---- the other 6.154.0 tools ----------------------------------------
    -- ⏱ dig, with timing. hostFrom admits only [%w%-%.]+, so a host can
    -- never start with "@" or "+" and be read by dig as an option.
    function nt.dig(host)
        nt.remember(host)
        return nt.run(nt.DIG, { "+time=2", "+tries=1", host }, "dig " .. host,
            function(code, text)
                nt.history[#nt.history + 1] = { tool = "dig", host = host,
                                                ms = nt.lastMs, ok = code == 0 }
                local ms = tonumber(tostring(text):match("Query time: (%d+) msec"))
                local srv = tostring(text):match("SERVER: ([^#%s]+)")
                nt.showOutput("dig " .. host
                    .. (ms and string.format(" — %d ms via %s", ms, srv or "?") or ""), text)
            end)
    end

    -- 🏁 the DNS race on its own: your resolver against the public three.
    -- Same positional-argument shell as the report; no user input.
    nt.resolvers = { "1.1.1.1", "8.8.8.8", "9.9.9.9" }
    local RACE_SCRIPT = [[
dig="$1"; shift
printf '@@ system\n'; "$dig" +time=2 +tries=1 apple.com 2>&1
for r in "$@"; do printf '@@ %s\n' "$r"; "$dig" +time=2 +tries=1 "@$r" apple.com 2>&1; done
]]
    function nt.race()
        local args = { "-c", RACE_SCRIPT, "hs-dns-race", nt.DIG }
        for _, r in ipairs(nt.resolvers) do args[#args + 1] = r end
        return nt.run("/bin/sh", args, "DNS race", function(code, text)
            local S = nt.sections(text)
            local rows = {}
            for name, lines in pairs(S) do
                local j = table.concat(lines, "\n")
                rows[#rows + 1] = { name = name,
                                    ms = tonumber(j:match("Query time: (%d+) msec")),
                                    srv = j:match("SERVER: ([^#%s]+)") }
            end
            table.sort(rows, function(a, b) return (a.ms or 1e9) < (b.ms or 1e9) end)
            local L = { "🏁 DNS RACE — apple.com, asked once of each, fastest first", "" }
            for i, x in ipairs(rows) do
                L[#L + 1] = string.format("   %d. %-8s %s  %s", i,
                    x.name == "system" and "yours" or x.name,
                    x.ms and (x.ms .. " ms") or "no answer",
                    x.name == "system" and ("(" .. tostring(x.srv or "?") .. ")") or "")
            end
            L[#L + 1] = ""
            L[#L + 1] = "   To use the winner: System Settings → Wi-Fi → Details → DNS."
            L[#L + 1] = "   This tool never changes it for you."
            nt.history[#nt.history + 1] = { tool = "race", host = "-",
                                            ms = nt.lastMs, ok = code == 0 }
            nt.showOutput("DNS race", table.concat(L, "\n"))
        end)
    end

    function nt.lan()
        return nt.run(nt.ARP, { "-a" }, "Devices on this network", function(code, text)
            nt.history[#nt.history + 1] = { tool = "lan", host = "-",
                                            ms = nt.lastMs, ok = code == 0 }
            nt.showOutput("Devices on this network (arp -a)", text)
        end)
    end

    local IFACE_SCRIPT = [[
ns="$1"; ipc="$2"
"$ns" -listallhardwareports 2>&1
printf '\nADDRESSES\n'
for d in en0 en1 en2 en3 en4 en5; do
  ip=$("$ipc" getifaddr "$d" 2>/dev/null)
  [ -n "$ip" ] && printf '  %s  %s\n' "$d" "$ip"
done
exit 0
]]
    function nt.interfaces()
        return nt.run("/bin/sh", { "-c", IFACE_SCRIPT, "hs-net-ifaces", nt.NETSETUP, nt.IPCONFIG },
            "Interfaces & addresses", function(code, text)
                nt.history[#nt.history + 1] = { tool = "ifaces", host = "-",
                                                ms = nt.lastMs, ok = code == 0 }
                nt.showOutput("Interfaces & addresses", text)
            end)
    end

    -- 🌍 a DNS question, not a web page: OpenDNS answers myip.opendns.com
    -- with the address the question came from.
    function nt.publicIp()
        return nt.run(nt.DIG, { "+short", "+time=2", "+tries=1", "myip.opendns.com",
                                "@resolver1.opendns.com" }, "Public IP",
            function(code, text)
                local ip = tostring(text):match("(%d+%.%d+%.%d+%.%d+)")
                nt.history[#nt.history + 1] = { tool = "public", host = "-",
                                                ms = nt.lastMs, ok = ip ~= nil }
                -- the list first (it copies the whole answer), THEN the
                -- bare address over the top: the IP alone is what you
                -- paste into a form, not dig's transcript
                nt.showOutput("Public IP", ip and (ip .. "\n\n" .. tostring(text)) or text)
                if ip then
                    pcall(function() hs.pasteboard.setContents(ip) end)
                    hs.alert.show("🌍 Public IP " .. ip .. " — copied", 4)
                else
                    hs.alert.show("🌍 No answer from OpenDNS — is DNS working? "
                                  .. "(⇪6 → Network report)", 4)
                end
            end)
    end

    -- 🚀 THE ONE OPTIONAL TOOL, and it is optional the way ⇪8's WordNet is:
    -- speedtest-cli does not ship with macOS, it comes from Homebrew (which
    -- LL runs from his home directory on the work Mac, so those prefixes
    -- are searched first). Absent, the row says how to install it and ⏎
    -- copies the command; nothing else changes.
    local home = os.getenv("HOME") or core.homeDir or ""
    nt.speedtestPaths = {
        home .. "/homebrew/bin/speedtest-cli", home .. "/homebrew/bin/speedtest",
        home .. "/.homebrew/bin/speedtest-cli",
        "/opt/homebrew/bin/speedtest-cli", "/opt/homebrew/bin/speedtest",
        "/usr/local/bin/speedtest-cli", "/usr/local/bin/speedtest",
    }
    nt.speedInstall = "brew install speedtest-cli"
    nt.speedTimeout = 120
    function nt.findSpeedtest()
        for _, p in ipairs(nt.speedtestPaths) do
            local f = io.open(p, "r")
            if f then f:close() ; return p end
        end
        return nil
    end
    function nt.speedtest()
        local bin = nt.findSpeedtest()
        if not bin then
            pcall(function() hs.pasteboard.setContents(nt.speedInstall) end)
            hs.alert.show("🚀 No speed test installed — copied `" .. nt.speedInstall
                          .. "` for the terminal", 5)
            return false
        end
        local args = bin:match("speedtest%-cli$") and { "--simple" }
                     or { "--accept-license", "--accept-gdpr" }
        return nt.run(bin, args, "Speed test", function(code, text)
            nt.history[#nt.history + 1] = { tool = "speed", host = "-",
                                            ms = nt.lastMs, ok = code == 0 }
            nt.showOutput("Speed test", text)
        end, nt.speedTimeout)
    end

    -- ---- the picker's rows --------------------------------------------------
    -- LL: "create a picker that describes and then executes the commands".
    -- Every row's second line is what the command tells you, in words; a
    -- row that needs a host asks for it (the clipboard prefills).
    nt.tools = {
        { id = "report",  icon = "🩺", title = "Network report",
          sub = "What is going on: IP · router · internet · DNS speed · Wi-Fi · VPN · "
                .. "captive portal — read-only, ending in a VERDICT",
          needsHost = false, run = function() return nt.report("report") end },
        { id = "refresh", icon = "🧹", title = "Refresh & verify (safe)",
          sub = "Flush DNS (both halves, honestly reported), then the full report. "
                .. "Nothing disabled, nothing killed, no setting touched",
          needsHost = false, run = function() return nt.report("refresh") end },
        { id = "flush", icon = "🚽", title = "Flush DNS",
          sub = "Both halves, reported separately — one of them needs admin",
          needsHost = false, run = function() return nt.flush() end },
        { id = "ping",  icon = "📡", title = "Ping",
          sub = nil, needsHost = true, run = function(h) return nt.ping(h) end },
        { id = "look",  icon = "🔍", title = "nslookup",
          sub = "What DNS says this name resolves to, and which server said it",
          needsHost = true, run = function(h) return nt.nslookup(h) end },
        { id = "dig",   icon = "⏱", title = "dig — DNS with timing",
          sub = "Which server answered this name, and in how many milliseconds",
          needsHost = true, run = function(h) return nt.dig(h) end },
        { id = "race",  icon = "🏁", title = "DNS race",
          sub = "Your resolver vs 1.1.1.1 · 8.8.8.8 · 9.9.9.9 — who answers fastest "
                .. "from HERE (you change it; this never does)",
          needsHost = false, run = function() return nt.race() end },
        { id = "trace", icon = "🛣", title = "traceroute",
          sub = nil, needsHost = true, run = function(h) return nt.traceroute(h) end },
        { id = "ifaces", icon = "🔌", title = "Interfaces & addresses",
          sub = "Every port macOS knows (Wi-Fi, Ethernet, Thunderbolt) and the IP each one holds",
          needsHost = false, run = function() return nt.interfaces() end },
        { id = "lan",   icon = "🏠", title = "Devices on this network",
          sub = "arp -a: every device this Mac has exchanged packets with on the local network",
          needsHost = false, run = function() return nt.lan() end },
        { id = "public", icon = "🌍", title = "Public IP",
          sub = "What the internet sees you as — asked of OpenDNS by DNS, no web page involved",
          needsHost = false, run = function() return nt.publicIp() end },
        { id = "speed", icon = "🚀", title = "Speed test",
          sub = nil, needsHost = false, run = function() return nt.speedtest() end },
    }

    function nt.subFor(t)
        if t.id == "ping"  then return nt.pingCount .. " packets, then the summary" end
        if t.id == "trace" then return "at most " .. nt.traceHops .. " hops, "
                                      .. nt.traceWait .. "s each" end
        if t.id == "speed" then
            local bin = nt.findSpeedtest()
            if bin then
                return "Download and upload in Mbps — about 30 seconds ("
                       .. (bin:match("[^/]+$") or bin) .. ")"
            end
            return "Not installed — ⏎ copies `" .. nt.speedInstall
                   .. "` (speedtest-cli, optional, via Homebrew)"
        end
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
        if nt.lastReport then
            L[#L + 1] = "   last report (" .. os.date("%H:%M", nt.lastReport.at) .. ", "
                        .. nt.lastReport.mode .. "):"
            for _, v in ipairs(nt.lastReport.verdict or {}) do L[#L + 1] = "      " .. v end
            L[#L + 1] = "      saved: " .. nt.reportFile
        end
        L[#L + 1] = "   speed test: " .. (nt.findSpeedtest() or ("not installed ("
                    .. nt.speedInstall .. ")"))
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
    core.provide("net.health", function(mode) return nt.report(mode) end)   -- 6.154.0

    _G.netTools = nt
    M.nt     = nt
    M.config = nt
end

return M
