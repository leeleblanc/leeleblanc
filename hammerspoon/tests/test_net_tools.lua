-- =====================================================================
-- test_net_tools.lua — ⇪6 runs the four, bounded, and tells the truth
-- =====================================================================
--     lua5.4 test_net_tools.lua [/path/to/hammerspoon]
--
-- Executes modules/net_tools.lua against a stubbed hs.
--
-- THREE SECTIONS HAVE TEETH:
--
--   §3 THE HOST NEVER TOUCHES A SHELL. A hostname is text you typed or
--      pasted. hs.task takes an argument ARRAY and execs directly, so
--      there is no shell to inject into — but only as long as nobody
--      "simplifies" it into an /bin/sh -c string. These checks fail the
--      moment somebody does.
--
--   §4 EVERY COMMAND IS BOUNDED. traceroute to an unreachable host runs
--      for minutes on its defaults. -c, -m and -w are what make this a
--      keypress rather than a hostage situation.
--
--   §5 A HALF FLUSH IS REPORTED AS A HALF FLUSH. The mDNSResponder half
--      needs admin and cannot succeed on a managed Mac. Every "flush
--      your DNS" instruction on the internet runs both and mentions
--      neither, which is how you spend an afternoon debugging a cache
--      that was never cleared.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local TASKS    = {}
local ALERTS   = {}
local TIMERS   = {}
local CHOOSERS = {}
local SHOWS    = 0
local CLIP     = nil
local NOW      = 1000

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = {
        getContents = function() return CLIP end,
        setContents = function(s) CLIP = s end,
    },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args,
                        started = false, terminated = false, running = true }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            function t:isRunning() return self.running end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "",
                        query_ = nil, qcb = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            function c:queryChangedCallback(f) self.qcb = f ; return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/net_tools.lua"))
local M = chunk()
M.setup(CORE)
local nt = _G.netTools

local function reset()
    TASKS, ALERTS, TIMERS = {}, {}, {}
    nt.task, nt.running, nt.lastNote = nil, nil, nil
    nt.history, nt.recent = {}, {}
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Network Tools")
check("it declares a family", M.family == "config")
check("⇪6 is bound", BOUND["+6"] ~= nil)
check("the binding is attributed to this module",
      BOUND["+6"] and BOUND["+6"].src == "network tools")
check("it publishes _G.netTools", type(nt) == "table")
check("three services are published", PROVIDED["net.show"]
      and PROVIDED["net.flush"] and PROVIDED["net.report"])
check("the cheat sheet key cell is exactly ⇪6", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪6" then return true end
    end
    return false
end)())
check("all four tools LL named are STILL present (6.154.0 added eight more)", (function()
    local want = { flush = true, ping = true, look = true, trace = true }
    for _, t in ipairs(nt.tools) do want[t.id] = nil end
    return next(want) == nil
end)())
check("6.154.0 — twelve tools in all", #nt.tools == 12, #nt.tools)
check("🗣 …and EVERY row describes itself — LL: 'a picker that describes "
      .. "and then executes the commands'", (function()
    for _, t in ipairs(nt.tools) do
        if not (nt.subFor(t) and #nt.subFor(t) > 20) then return false, t.id end
    end
    return true
end)())
check("the report and the safe refresh lead the list", nt.tools[1].id == "report"
      and nt.tools[2].id == "refresh", nt.tools[1].id)

-- =====================================================================
out("\n=== 2. what counts as a host ===\n")
-- =====================================================================
check("a bare hostname passes", nt.hostFrom("example.com") == "example.com")
check("an IP passes", nt.hostFrom("1.1.1.1") == "1.1.1.1")
check("localhost passes, despite having no dot",
      nt.hostFrom("localhost") == "localhost")
-- 📋 The clipboard is where a host usually comes from, and what is on it
-- is usually a URL. "ping https://docs.example.com/a/b" is a mistake
-- worth making impossible.
check("🚨 a full URL is stripped to its host",
      nt.hostFrom("https://docs.example.com/a/b?x=1#f") == "docs.example.com",
      nt.hostFrom("https://docs.example.com/a/b?x=1#f"))
check("…including the port", nt.hostFrom("http://example.com:8080/") == "example.com")
check("…and basic-auth credentials",
      nt.hostFrom("https://user:pw@example.com/x") == "example.com",
      nt.hostFrom("https://user:pw@example.com/x"))
check("an email address becomes its domain",
      nt.hostFrom("lee@example.com") == "example.com",
      nt.hostFrom("lee@example.com"))
check("surrounding whitespace is trimmed",
      nt.hostFrom("  example.com \n") == "example.com")
-- Anything else is text that happened to be on the clipboard. Offering
-- it as a host sends you round a loop wondering why the lookup failed.
check("🚨 a sentence is NOT a host", nt.hostFrom("go and ask the network team") == nil)
check("🚨 a single word with no dot is NOT a host", nt.hostFrom("router") == nil)
check("🚨 a path is not a host", nt.hostFrom("/Users/test/file.txt") == nil,
      nt.hostFrom("/Users/test/file.txt"))
check("empty is nil", nt.hostFrom("") == nil)
check("nil is nil, not a throw", nt.hostFrom(nil) == nil)

-- =====================================================================
out("\n=== 3. 🚨 THE HOST NEVER TOUCHES A SHELL ===\n")
-- =====================================================================
reset()
nt.ping("example.com")
local t = TASKS[1]
check("ping runs the real binary directly", t and t.bin == "/sbin/ping", t and t.bin)
check("🚨 …NOT through a shell", t and t.bin ~= "/bin/sh" and t.bin ~= "/bin/zsh")
check("🚨 the host is a separate ARGUMENT, not part of a command string",
      (function()
    if not t then return false end
    for _, a in ipairs(t.args) do if a == "example.com" then return true end end
    return false
end)(), t and table.concat(t.args, " "))
check("…so a host full of shell metacharacters is just a bad hostname",
      (function()
    -- reset first: one command at a time is enforced, and the ping above
    -- is still "running" in the stub.
    nt.task = nil
    TASKS = {}
    nt.ping("a.com; rm -rf ~")   -- hostFrom would refuse this, so call direct
    local p = TASKS[1]
    if not p then return false end
    for _, a in ipairs(p.args) do
        if a == "a.com; rm -rf ~" then return true end   -- passed whole, unparsed
    end
    return false
end)())

reset()
nt.nslookup("example.com")
check("nslookup runs the real binary", TASKS[1]
      and TASKS[1].bin == "/usr/bin/nslookup", TASKS[1] and TASKS[1].bin)
reset()
nt.traceroute("example.com")
check("traceroute runs the real binary", TASKS[1]
      and TASKS[1].bin == "/usr/sbin/traceroute", TASKS[1] and TASKS[1].bin)

-- =====================================================================
out("\n=== 4. 🚨 EVERY COMMAND IS BOUNDED ===\n")
-- =====================================================================
-- traceroute to an unreachable host runs for MINUTES on its defaults.
reset()
nt.ping("example.com")
check("🚨 ping is bounded by -c", (function()
    for i, a in ipairs(TASKS[1].args) do
        if a == "-c" then return TASKS[1].args[i + 1] == tostring(nt.pingCount) end
    end
    return false
end)(), table.concat(TASKS[1].args, " "))

reset()
nt.traceroute("example.com")
local tr = TASKS[1]
check("🚨 traceroute is bounded by -m (max hops)", (function()
    for i, a in ipairs(tr.args) do
        if a == "-m" then return tr.args[i + 1] == tostring(nt.traceHops) end
    end
    return false
end)(), table.concat(tr.args, " "))
check("🚨 …and by -w (wait per hop)", (function()
    for i, a in ipairs(tr.args) do
        if a == "-w" then return tr.args[i + 1] == tostring(nt.traceWait) end
    end
    return false
end)(), table.concat(tr.args, " "))
check("a hard deadline timer was armed as well", #TIMERS >= 1, #TIMERS)
TIMERS[#TIMERS].fn()
check("…and it terminates the child rather than leaking it",
      tr.terminated == true)
check("…saying what it gave up on", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("gave up after", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])

-- Only one at a time: a second press while traceroute runs must not
-- spawn a second traceroute.
reset()
nt.ping("example.com")
local first = TASKS[1]
first.running = true
local before = #TASKS
check("a second command while one is running is refused", (function()
    nt.ping("other.com")
    return #TASKS == before
end)(), #TASKS)
check("…and says what it is waiting for", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("still running", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])

-- =====================================================================
out("\n=== 5. 🚨 A HALF FLUSH IS REPORTED AS A HALF FLUSH ===\n")
-- =====================================================================
reset()
nt.flush()
local fl = TASKS[1]
check("the flush needs a shell, because it is two commands and two codes",
      fl and fl.bin == "/bin/sh", fl and fl.bin)
check("🚨 …and it takes NO user input, which is what makes that safe",
      (function()
    -- the only argument beyond -c is the fixed script
    return fl and #fl.args == 2
end)(), fl and #fl.args)
check("both halves are in it", fl.args[2]:find("dscacheutil", 1, true)
      and fl.args[2]:find("mDNSResponder", 1, true))
check("🚨 …and each one's exit code is captured SEPARATELY",
      fl.args[2]:find("DSCACHE_RC", 1, true)
      and fl.args[2]:find("MDNS_RC", 1, true))

-- Both worked (an admin Mac).
fl.cb(0, "DSCACHE_RC=0\nMDNS_RC=0\n", "")
check("both succeeding is reported as a full flush", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("both halves succeeded", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])

-- 🚨 THE CASE THAT MATTERS: the work Mac, where the second half cannot
-- succeed and every instruction on the internet pretends otherwise.
reset()
nt.flush()
TASKS[1].cb(0, "DSCACHE_RC=0\nkillall: warning: ...\nMDNS_RC=1\n", "")
check("🚨 a half flush is NOT reported as a flush", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("HALF flushed", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])
check("🚨 …it names admin as the reason the second half failed", (function()
    for _, a in ipairs(ALERTS) do
        if a:lower():find("admin", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])
check("🚨 …and gives the remedy that works WITHOUT admin", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Wi%-Fi") then return true end
    end
    return false
end)(), ALERTS[#ALERTS])
check("the detail list says which half did what", (function()
    local c = CHOOSERS[#CHOOSERS]
    local joined = ""
    for _, ch in ipairs(c.choices_) do joined = joined .. ch.text .. "\n" end
    return joined:find("✅", 1, true) and joined:find("❌", 1, true)
end)())

-- =====================================================================
out("\n=== 6. the output list, and the whole thing on the clipboard ===\n")
-- =====================================================================
reset()
CLIP = "something else"
nt.ping("example.com")
TASKS[1].cb(0, "PING example.com\n64 bytes from 1.2.3.4\n\n--- stats ---\n", "")
check("🚨 the WHOLE output is copied before you have read it",
      CLIP and CLIP:find("64 bytes", 1, true) ~= nil, CLIP)
local oc = CHOOSERS[#CHOOSERS]
check("one row per non-empty line", #oc.choices_ == 3, #oc.choices_)
check("every row value is a string, number or boolean", (function()
    for _, ch in ipairs(oc.choices_) do
        for k, v in pairs(ch) do
            local t2 = type(v)
            if t2 ~= "string" and t2 ~= "number" and t2 ~= "boolean" then
                return false, k .. " is a " .. t2
            end
        end
    end
    return true
end)())
check("…and every payload resolves to a real line", (function()
    for _, ch in ipairs(oc.choices_) do
        if nt.outRows[ch.idx] == nil then return false end
    end
    return true
end)())
check("⏎ on a row copies THAT line", (function()
    oc.cb({ idx = 2 })
    return CLIP == "64 bytes from 1.2.3.4"
end)(), CLIP)
-- stderr is not thrown away: nslookup writes "can't find" to different
-- streams on different builds, and a tool that shows half the answer is
-- worse than one that shows none.
reset()
nt.nslookup("nope.invalid")
TASKS[1].cb(1, "", "** server can't find nope.invalid: NXDOMAIN\n")
check("🚨 stderr reaches the output too", (function()
    local c = CHOOSERS[#CHOOSERS]
    for _, ch in ipairs(c.choices_) do
        if ch.text:find("NXDOMAIN", 1, true) then return true end
    end
    return false
end)())
check("…and a non-zero exit is recorded as such",
      nt.history[#nt.history] and nt.history[#nt.history].ok == false)

-- =====================================================================
out("\n=== 7. 🚨 THE HOST BOX ALWAYS HAS A ROW FOR WHAT YOU TYPED ===\n")
-- =====================================================================
-- An hs.chooser only ever hands back a ROW. A box with no matching row
-- hands back nothing and ⏎ does nothing — which reads as the tool being
-- broken rather than as "there was no row".
reset()
CLIP = "https://example.com/docs"
nt.askHost(nt.byId("ping"))
local hc = nt.hostChooser
check("the clipboard prefills the box, stripped to a host",
      hc.query_ == "example.com", hc.query_)
check("a queryChangedCallback is installed", type(hc.qcb) == "function")
hc.qcb("apple.com")
check("🚨 typing a host produces a row for exactly that host", (function()
    return hc.choices_[1] and hc.choices_[1].host == "apple.com"
end)(), hc.choices_[1] and hc.choices_[1].host)
check("…labelled with the tool that will run", (function()
    return hc.choices_[1].text:find("Ping", 1, true) ~= nil
end)(), hc.choices_[1].text)
hc.qcb("appl")
check("🚨 a partial host still gives a row, so ⏎ is never dead", (function()
    return hc.choices_[1] ~= nil
end)())
check("…but that row cannot be run", hc.choices_[1].host == "",
      hc.choices_[1].host)
check("…and it says why", hc.choices_[1].subText:find("keep typing", 1, true) ~= nil,
      hc.choices_[1].subText)
check("⏎ on a real row runs the pending tool with that host", (function()
    TASKS = {}
    hc.qcb("apple.com")
    hc.cb(hc.choices_[1])
    return TASKS[1] and TASKS[1].bin == "/sbin/ping"
end)(), TASKS[1] and TASKS[1].bin)
check("…and the host is remembered for next time", (function()
    for _, h in ipairs(nt.recent) do if h == "apple.com" then return true end end
    return false
end)())
check("picking the placeholder row runs nothing", (function()
    TASKS = {}
    hc.cb({ host = "" })
    return #TASKS == 0
end)(), #TASKS)

-- =====================================================================
out("\n=== 8. the report tells the truth ===\n")
-- =====================================================================
reset()
nt.ping("example.com")
TASKS[1].cb(0, "ok\n", "")
local rep = _G.netReport()
check("the report names the module", rep:find("NETWORK TOOLS", 1, true) ~= nil)
check("…lists what ran, against what", rep:find("example.com", 1, true) ~= nil, rep)
-- 🚨 The caveat is in the REPORT as well as in the alert, because the
-- report is what you read when you are already confused about DNS.
check("🚨 …and repeats that a full flush needs admin",
      rep:lower():find("admin", 1, true) ~= nil, rep)
check("…naming the no-admin substitute", rep:find("Wi%-Fi") ~= nil, rep)

-- =====================================================================
out("\n=== 9. 🩺 6.154.0 — the report: many commands, one verdict ===\n")
-- =====================================================================
-- LL: "can we use the command line to run multiple commands and build a
-- report that tells us what is going on".
reset()
nt.reportFile = os.tmpname()
nt.report("report")
local rt = TASKS[1]
check("the report is ONE shell run", rt and rt.bin == "/bin/sh", rt and rt.bin)
local script = rt and rt.args[2] or ""
check("🚨 every binary reaches the script as a POSITIONAL argument — none is "
      .. "written into the script text", not script:find("/usr/", 1, true)
      and not script:find("/sbin/", 1, true)
      and rt.args[4] == nt.DIG and rt.args[16] == nt.KILLALL, script:sub(1, 80))
check("…and the mode rides last: 'report' asks only", rt.args[17] == "report", rt.args[17])
check("🚨 the script NEVER disables, kills, renews or reconfigures anything — "
      .. "LL: 'I do not want to disable or kill or cause conflicts'", (function()
    for _, bad in ipairs({ "setairportpower", "setdnsservers", "setnetworkserviceenabled",
                           "route flush", "route delete", "route add", "arp %-d",
                           "sudo", "pkill", "kill %-9", "ipconfig set", "renew",
                           "ifconfig %S+ down", "ifconfig %S+ up", "networksetup %-set",
                           "killall %-9", "dscl", "defaults write", "launchctl" }) do
        if script:find(bad) then return false, bad end
    end
    return true
end)())
check("🚨 the ONE signal it can send (-HUP to mDNSResponder, the flush) sits "
      .. "INSIDE the refresh branch and nowhere else", (function()
    local n = select(2, script:gsub('"%$kil"', ""))
    return n == 1 and script:find('if %[ "%$mode" = "refresh" %]') ~= nil
           and script:find('"%$kil" %-HUP mDNSResponder') ~= nil
end)())
check("every wait is bounded in its arguments", script:find("-c 3 -i 0.2 -t 4", 1, true)
      and script:find("+time=2 +tries=1", 1, true) and script:find("-m 4", 1, true))
check("the run has a deadline of its own, longer than one tool's",
      TIMERS[#TIMERS].secs == nt.reportTimeout and nt.reportTimeout > nt.timeout,
      TIMERS[#TIMERS].secs)

-- a healthy Mac, as the script would print it
local HEALTHY = [[
@@ ports
Hardware Port: Wi-Fi
Device: en0
Ethernet Address: aa:bb:cc:dd:ee:ff
Hardware Port: Thunderbolt Bridge
Device: bridge0
@@ addr
en0 192.168.1.23
@@ wifi
Current Wi-Fi Network: HomeNet
Security: WPA2 Personal
@@ gateway
   route to: default
destination: default
       mask: default
    gateway: 192.168.1.1
  interface: en0
@@ dns
resolver #1
  nameserver[0] : 192.168.1.1
  nameserver[1] : 1.1.1.1
@@ pinggw
PING 192.168.1.1: 56 data bytes
3 packets transmitted, 3 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 1.9/2.1/2.4/0.2 ms
@@ ping1
PING 1.1.1.1: 56 data bytes
3 packets transmitted, 3 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 13.0/14.2/15.1/0.9 ms
@@ dnstime
;; Query time: 14 msec
;; SERVER: 192.168.1.1#53(192.168.1.1) (UDP)
@@ race
;; Query time: 12 msec
;; SERVER: 1.1.1.1#53(1.1.1.1) (UDP)
;; Query time: 19 msec
;; SERVER: 8.8.8.8#53(8.8.8.8) (UDP)
;; Query time: 31 msec
;; SERVER: 9.9.9.9#53(9.9.9.9) (UDP)
@@ public
203.0.113.9
@@ captive
200 0.087
@@ vpn
lo0 gif0 stf0 en0 utun0 utun3
No network configurations
@@ routes
Destination        Gateway            Flags
default            192.168.1.1        UGScg
192.168.1/24       link#5             UCS
@@ arp
router (192.168.1.1) at 0:1:2:3:4:5 on en0 ifscope [ethernet]
printer (192.168.1.40) at 6:7:8:9:a:b on en0 ifscope [ethernet]
@@ done
]]
rt.cb(0, HEALTHY, "")
local R = nt.lastReport
check("the facts are parsed: IP on Wi-Fi", R and R.facts.addr[1].ip == "192.168.1.23"
      and R.facts.ports.en0 == "Wi-Fi")
check("…the network name", R.facts.ssid == "HomeNet", R.facts.ssid)
check("…the router and the resolvers", R.facts.gateway == "192.168.1.1"
      and R.facts.dns[2] == "1.1.1.1")
check("…both pings, loss and average", R.facts.pingGw.avg == 2.1
      and R.facts.ping1.loss == 0 and R.facts.ping1.avg == 14.2)
check("…the DNS time and who answered", R.facts.dnsMs == 14
      and R.facts.dnsServer == "192.168.1.1")
check("…the race, FASTEST FIRST", R.facts.race[1].server == "1.1.1.1"
      and R.facts.race[1].ms == 12 and R.facts.race[3].server == "9.9.9.9")
check("…the public IP and the portal check", R.facts.publicIp == "203.0.113.9"
      and R.facts.captiveCode == 200)
check("…the tunnels, and no VPN", #R.facts.tunnels == 2 and #R.facts.vpns == 0)
check("…and the LAN", R.facts.arpCount == 2 and R.facts.routeCount >= 2)
check("✅ a healthy Mac gets a ONE-LINE all-clear with the numbers in it",
      #R.verdict == 1 and R.verdict[1]:find("✅ All good", 1, true) ~= nil
      and R.verdict[1]:find("2 ms", 1, true) ~= nil, R.verdict[1])
check("the whole report is on the clipboard, verdict first",
      CLIP and CLIP:find("VERDICT", 1, true) ~= nil
      and CLIP:find("VERDICT", 1, true) < CLIP:find("FACTS", 1, true))
check("…and saved to the Logs folder", (function()
    local f = io.open(nt.reportFile, "r")
    if not f then return false end
    local s = f:read("*a") ; f:close() ; os.remove(nt.reportFile)
    return s:find("All good", 1, true) ~= nil
end)())
check("…which the write ledger knows is rewritten whole every run",
      _G.rewrittenFiles and _G.rewrittenFiles[nt.reportFile] ~= nil)

-- the verdict names the FIRST broken link, top down
local function verdictFor(text)
    return nt.verdict(nt.parseReport(text))
end
local function swap(text, from, to)
    local s, n = text:gsub(from, to)
    assert(n > 0, "fixture edit missed: " .. from)
    return s
end
local deadRouter = swap(HEALTHY, "3 packets transmitted, 3 packets received, 0%.0%% packet loss\nround%-trip min/avg/max/stddev = 1%.9/2%.1/2%.4/0%.2 ms",
                        "3 packets transmitted, 0 packets received, 100.0%% packet loss")
check("❌ a router that does not answer is called a LOCAL problem",
      verdictFor(deadRouter)[1]:find("LOCAL", 1, true) ~= nil, verdictFor(deadRouter)[1])
local deadInet = swap(HEALTHY, "3 packets transmitted, 3 packets received, 0%.0%% packet loss\nround%-trip min/avg/max/stddev = 13%.0/14%.2/15%.1/0%.9 ms",
                      "3 packets transmitted, 0 packets received, 100.0%% packet loss")
check("❌ router fine but 1.1.1.1 silent → the ISP, not this Mac",
      verdictFor(deadInet)[1]:find("ISP", 1, true) ~= nil, verdictFor(deadInet)[1])
local deadDns = swap(HEALTHY, ";; Query time: 14 msec\n;; SERVER: 192%.168%.1%.1#53%(192%.168%.1%.1%) %(UDP%)",
                     ";; connection timed out; no servers could be reached")
check("❌ pings fine but names do not resolve → DNS is the problem, with the fix",
      verdictFor(deadDns)[1]:find("DNS is the problem", 1, true) ~= nil
      and verdictFor(deadDns)[1]:find("Flush DNS", 1, true) ~= nil, verdictFor(deadDns)[1])
local slowDns = swap(HEALTHY, "Query time: 14 msec", "Query time: 180 msec")
local V, tips = verdictFor(slowDns)
check("⚠️ slow DNS is named with its number", V[1]:find("DNS is slow", 1, true)
      and V[1]:find("180 ms", 1, true), V[1])
check("💡 …and the race's winner is offered as the by-hand fix — with where "
      .. "to set it, and that this tool never will", tips[1]
      and tips[1]:find("1.1.1.1 answers in 12 ms", 1, true)
      and tips[1]:find("System Settings", 1, true)
      and tips[1]:find("never changes", 1, true), tips[1])
local portal = swap(HEALTHY, "200 0%.087", "302 0.120")
check("⚠️ a non-200 from captive.apple.com → a captive portal, with what to do",
      verdictFor(portal)[1]:find("Captive portal", 1, true) ~= nil
      and verdictFor(portal)[1]:find("browser", 1, true) ~= nil, verdictFor(portal)[1])
local vpn = swap(HEALTHY, "No network configurations",
                 '* (Connected)  0A1B2C3D IPSec  "Work VPN"  [IPSec]')
V = verdictFor(vpn)
check("🔒 a connected VPN is named, and said to carry everything above",
      V[#V]:find("VPN connected: Work VPN", 1, true) ~= nil, V[#V])
local noIp = swap(HEALTHY, "@@ addr\nen0 192%.168%.1%.23\n", "@@ addr\n")
V = verdictFor(noIp)
check("❌ no IP at all stops the reasoning at the first link — one line, "
      .. "the one to fix", #V == 1 and V[1]:find("No IP address", 1, true) ~= nil, V[1])

out("\n=== 9b. 🧹 the safe refresh: the flush, then the report ===\n")
reset()
nt.reportFile = os.tmpname()
nt.report("refresh")
rt = TASKS[1]
check("the refresh is the same script with mode 'refresh'", rt.args[17] == "refresh")
rt.cb(0, "@@ flush\nDSCACHE_RC=0\nkillall: warning: ...\nMDNS_RC=1\n" .. HEALTHY, "")
check("the report opens with the REFRESH block, both halves reported honestly",
      CLIP:find("🧹 REFRESH", 1, true) ~= nil
      and CLIP:find("✅ dscacheutil", 1, true) ~= nil
      and CLIP:find("needs admin", 1, true) ~= nil, CLIP:sub(1, 300))
check("…saying in so many words that nothing else was touched",
      CLIP:find("nothing else was touched", 1, true) ~= nil)
check("…and the verdict still follows", CLIP:find("VERDICT", 1, true) ~= nil)
check("history records it as a refresh", nt.history[#nt.history].tool == "refresh")
os.remove(nt.reportFile)
local rep9 = _G.netReport()
check("_G.netReport() now carries the last verdict and where the file went",
      rep9:find("last report", 1, true) ~= nil and rep9:find("All good", 1, true) ~= nil
      and rep9:find("saved:", 1, true) ~= nil, rep9)

out("\n=== 9c. the other new tools describe themselves and stay bounded ===\n")
reset()
nt.race()
rt = TASKS[1]
check("🏁 the race is one shell run, dig positional, the three resolvers as args",
      rt.bin == "/bin/sh" and rt.args[4] == nt.DIG and rt.args[5] == "1.1.1.1"
      and rt.args[7] == "9.9.9.9", table.concat(rt.args, " "):sub(1, 60))
rt.cb(0, "@@ system\n;; Query time: 40 msec\n;; SERVER: 10.0.0.1#53(10.0.0.1)\n"
         .. "@@ 1.1.1.1\n;; Query time: 12 msec\n;; SERVER: 1.1.1.1#53(1.1.1.1)\n"
         .. "@@ 8.8.8.8\n;; Query time: 19 msec\n;; SERVER: 8.8.8.8#53(8.8.8.8)\n"
         .. "@@ 9.9.9.9\n;; connection timed out\n", "")
check("…listed fastest first, yours labelled, a silent one honest",
      CLIP:find("1. 1.1.1.1", 1, true) ~= nil and CLIP:find("yours", 1, true) ~= nil
      and CLIP:find("no answer", 1, true) ~= nil, CLIP)
check("…and it says where YOU change it, and that it never will",
      CLIP:find("System Settings", 1, true) ~= nil
      and CLIP:find("never changes it", 1, true) ~= nil)

reset()
nt.dig("example.com")
check("⏱ dig runs the real binary with the host as its own argument, bounded",
      TASKS[1].bin == nt.DIG and TASKS[1].args[1] == "+time=2"
      and TASKS[1].args[2] == "+tries=1" and TASKS[1].args[3] == "example.com")
TASKS[1].cb(0, ";; Query time: 23 msec\n;; SERVER: 1.1.1.1#53(1.1.1.1)\n", "")
check("…and the title carries the timing", nt.outChooser.placeholder:find("23 ms", 1, true) ~= nil,
      nt.outChooser.placeholder)

reset()
nt.publicIp()
check("🌍 the public IP is a DNS question to OpenDNS, not a web page",
      TASKS[1].bin == nt.DIG and (function()
    local j = table.concat(TASKS[1].args, " ")
    return j:find("myip.opendns.com", 1, true) and j:find("@resolver1.opendns.com", 1, true)
end)())
TASKS[1].cb(0, "203.0.113.9\n", "")
check("…the answer is copied and announced", CLIP == "203.0.113.9" and (function()
    for _, a in ipairs(ALERTS) do if a:find("copied", 1, true) then return true end end
end)(), CLIP)

reset()
nt.lan()
check("🏠 the LAN list is arp -a, read only", TASKS[1].bin == nt.ARP
      and TASKS[1].args[1] == "-a" and #TASKS[1].args == 1)
reset()
nt.interfaces()
check("🔌 interfaces: networksetup and ipconfig, positional, list/get only",
      TASKS[1].bin == "/bin/sh" and TASKS[1].args[4] == nt.NETSETUP
      and TASKS[1].args[5] == nt.IPCONFIG
      and not TASKS[1].args[2]:find("%-set") and TASKS[1].args[2]:find("getifaddr", 1, true))

out("\n=== 9d. 🚀 the speed test is optional, the Homebrew way ===\n")
reset()
local realPaths = nt.speedtestPaths
nt.speedtestPaths = {}
check("absent: the row says how to install it", nt.subFor(nt.byId("speed")):find("Not installed", 1, true) ~= nil,
      nt.subFor(nt.byId("speed")))
check("…and ⏎ copies the install command instead of pretending", nt.speedtest() == false
      and CLIP == nt.speedInstall and #TASKS == 0, CLIP)
local sp = os.tmpname() .. "-speedtest-cli"
local spf = io.open(sp, "w") ; spf:write("#!/bin/sh\n") ; spf:close()
nt.speedtestPaths = { sp }
check("present: the row names the binary", nt.subFor(nt.byId("speed")):find("speedtest%-cli") ~= nil)
reset()
nt.speedtest()
check("…and it runs it directly, --simple, with a longer deadline than the rest",
      TASKS[1] and TASKS[1].bin == sp and TASKS[1].args[1] == "--simple"
      and TIMERS[#TIMERS].secs == nt.speedTimeout, TASKS[1] and TASKS[1].bin)
os.remove(sp)
nt.speedtestPaths = realPaths

-- =====================================================================
out(("\n── test_net_tools: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
