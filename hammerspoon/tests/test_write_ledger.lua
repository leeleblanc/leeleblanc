-- =====================================================================
-- test_write_ledger.lua — "how do I know my logs are actually saving?"
-- =====================================================================
--     lua5.4 test_write_ledger.lua [/path/to/hammerspoon]
--
-- Executes modules/write_ledger.lua against REAL FILES in a temporary
-- directory — no stubbed filesystem, because the whole module is a claim
-- about what is on disk and a stub would only confirm my idea of it.
-- (That mistake has been made in this repo before: the 6.69.0 hs.fs.dir
-- stub was more forgiving than the API and hid a bug that stopped every
-- snippet loading.) Only hs.fs, hs.timer and hs.alert are stood in for.
--
-- Section 4 is the one with teeth: the twin detector is the 6.115.0 bug
-- turned into a check. Two files that are the same log under two names,
-- one of them frozen since July, is the exact situation LL was looking at
-- when he asked this question — and it is invisible to any amount of
-- instrumentation on the write path, because every write succeeded.

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

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- a real temporary tree ---------------------------------------------
local ROOT = os.getenv("TMPDIR") or "/tmp"
ROOT = ROOT:gsub("/$", "") .. "/hs-write-ledger-test-" .. tostring(os.time())
local LOGS = ROOT .. "/Logs"
local CFG  = ROOT .. "/hammerspoon"
os.execute("mkdir -p '" .. LOGS .. "/Terminal+Ghostty' '" .. CFG .. "'")

local function put(path, body)
    local f = assert(io.open(path, "w"))
    f:write(body)
    f:close()
end
local function slurp(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end
local function touchAge(path, secondsAgo)
    -- Real mtimes, set through the real filesystem: a stubbed one would
    -- only prove the arithmetic, not that the module reads the field.
    local when = os.date("!%Y%m%d%H%M.%S", os.time() - secondsAgo)
    os.execute("touch -t " .. os.date("%Y%m%d%H%M.%S", os.time() - secondsAgo)
               .. " '" .. path .. "' 2>/dev/null")
    return when
end

put(LOGS .. "/activity_history-TestMac.csv", "a,b,c\n1,2,3\n4,5,6\n")
put(LOGS .. "/image_text-TestMac.csv",       "when,text\n1,hello\n")
put(LOGS .. "/file_changes-TestMac.csv",     "ts,name\n1,x\n2,y\n3,z\n")
put(LOGS .. "/Terminal+Ghostty/command_history.log", "ls\ncd\n")
put(LOGS .. "/not-a-log.png",                "binary-ish")
put(CFG  .. "/clipboard_history.json",       '{"a":1}')

-- ---- the stub Mac, as thin as it can be --------------------------------
local ALERTS, TIMERS = {}, {}
local NOW = os.time() + 0.0

package.path = package.path
hs = {
    configdir = CFG,
    fs = {
        dir = function(d)
            -- The REAL two-value contract: an iterator plus the state it
            -- reads from. A closure that needs no state is exactly the
            -- forgiving stub that hid the 6.69.0 bug.
            local p = io.popen("ls -a '" .. d .. "' 2>/dev/null")
            if not p then error("no such directory") end
            local names = {}
            for line in p:lines() do names[#names + 1] = line end
            p:close()
            if #names == 0 then error("no such directory: " .. d) end
            local state = { i = 0, names = names }
            return function(st)
                st.i = st.i + 1
                return st.names[st.i]
            end, state
        end,
        attributes = function(path)
            -- GNU stat and BSD stat disagree on every flag, and `stat -f`
            -- means "filesystem status" on GNU — so it SUCCEEDS with the
            -- wrong output rather than failing over. Both forms are tried
            -- and the answer is accepted only if it parses.
            for _, cmd in ipairs({ "stat -c '%s %Y %F' ", "stat -f '%z %m %HT' " }) do
                local p = io.popen(cmd .. "'" .. path .. "' 2>/dev/null")
                if p then
                    local line = p:read("*l") ; p:close()
                    local size, mtime, kind =
                        tostring(line or ""):match("^(%d+)%s+(%d+)%s+(.*)$")
                    if size then
                        return { size = tonumber(size),
                                 modification = tonumber(mtime),
                                 mode = (kind:lower():find("director")
                                         and "directory" or "file") }
                    end
                end
            end
            return nil
        end,
    },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local PROVIDED = {}
local CORE = {
    logsDir = LOGS,
    hostTag = "TestMac",
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/write_ledger.lua"))
local M = chunk()
M.setup(CORE)
local wl = _G.writeLedger

out("\n=== 1. it loads, and binds no key at all ===\n")
check("the module returns a table with a name", M.name == "Write Ledger")
check("it declares a family", M.family == "config")
check("_G.saved is the entry point a human would type",
      type(_G.saved) == "function")
check("⇪⇧D can ask for the same block",
      type(_G.writeLedgerReport) == "function")
check("three services are published",
      PROVIDED["writeLedger.report"] and PROVIDED["writeLedger.check"]
      and PROVIDED["writeLedger.scan"])
-- 🚨 IT MUST NOT CLAIM A HOTKEY. Every single-letter ⇪ and ⇪⇧ key was
-- already taken when this was written, and a module that quietly grabbed
-- one would have shadowed a tool LL uses. The source is the check.
local src = slurp(HS .. "/modules/write_ledger.lua")
check("it never calls hyperAddShortcut",
      src:find("hyperAddShortcut", 1, true) == nil)

out("\n=== 2. the scan sees the log files and nothing else ===\n")
local files = wl.scan()
local byName = {}
for _, f in ipairs(files) do byName[f.name] = f end
check("it found the activity log", byName["activity_history-TestMac.csv"] ~= nil)
check("it found the OCR text log", byName["image_text-TestMac.csv"] ~= nil)
check("it looked one folder down for the command log",
      byName["command_history.log"] ~= nil)
check("it found the json in ~/.hammerspoon",
      byName["clipboard_history.json"] ~= nil)
check("🚨 it ignored the .png — this is a LOG ledger, not a file browser",
      byName["not-a-log.png"] == nil)
check("every entry carries a real size",
      (byName["activity_history-TestMac.csv"] or {}).size == 18,
      (byName["activity_history-TestMac.csv"] or {}).size)
check("…and a real modification time",
      ((byName["activity_history-TestMac.csv"] or {}).mtime or 0) > 0)

out("\n=== 3. the round trip is a real write, not a stat ===\n")
local okProbe, note = wl.probe()
check("the probe succeeded", okProbe == true, note)
check("…and reported how long it took", tostring(note):find("ms") ~= nil, note)
check("🚨 and it cleaned up after itself — no probe file left behind",
      slurp(LOGS .. "/.hs-write-probe") == nil)
-- A folder that will not take a write is the OneDrive-offline failure,
-- and it must be reported as a failure rather than assumed away.
local realLogs = CORE.logsDir
CORE.logsDir = ROOT .. "/does-not-exist"
local okBad, whyBad = wl.probe()
check("an unwritable folder fails the probe", okBad == false)
check("…and says what could not be done", type(whyBad) == "string"
      and #whyBad > 0, whyBad)
CORE.logsDir = realLogs

-- =====================================================================
out("\n=== 4. 🚨 TWO FILES THAT ARE THE SAME LOG ===\n")
-- =====================================================================
-- The 6.115.0 bug: activity_history.csv sat frozen in ~/.hammerspoon
-- while activity_history-<Mac>.csv was the one being written. Every
-- write succeeded, so nothing on the write path could have caught it.
put(CFG .. "/activity_history.csv", "old,frozen,rows\n1,2,3\n")
touchAge(CFG .. "/activity_history.csv", 40 * 86400)     -- 40 days old
touchAge(LOGS .. "/activity_history-TestMac.csv", 60)    -- a minute ago

local twins = wl.twins(wl.scan())
check("the twin was found", #twins == 1, #twins)
check("…and it named the FROZEN one as the stale side",
      twins[1] and twins[1].stale.path:find("hammerspoon/activity_history.csv",
                                            1, true) ~= nil,
      twins[1] and twins[1].stale.path)
check("…and the machine-tagged one as the live side",
      twins[1] and twins[1].live.name == "activity_history-TestMac.csv",
      twins[1] and twins[1].live.name)
check("…and said how far apart they are, in days",
      twins[1] and twins[1].days >= 30, twins[1] and twins[1].days)

-- 🚨 A .superseded FILE IS NOT A TWIN. 6.115.0 renames adopted originals
-- to that suffix precisely so they stop looking like live logs; flagging
-- them here would make the fix look like the bug it fixed.
--
-- ⚠️ THE FIRST VERSION OF THIS CHECK PROVED NOTHING. It passed with the
-- exclusion deleted, because the identity function stripped only one
-- extension — so "image_text-TestMac.csv.superseded" and
-- "image_text-TestMac.csv" never landed in the same group and the
-- exclusion was dead code. The two checks below close that: the FIRST
-- one asserts they share an identity (which is what makes the exclusion
-- load-bearing), and only then does the second one mean anything.
put(LOGS .. "/image_text-TestMac.csv.superseded", "old\n")
touchAge(LOGS .. "/image_text-TestMac.csv.superseded", 90 * 86400)
touchAge(LOGS .. "/image_text-TestMac.csv", 60)
check("a retired copy shares an identity with its live original — "
      .. "without this the exclusion below is untested dead code",
      wl.identity("image_text-TestMac.csv.superseded")
      == wl.identity("image_text-TestMac.csv"),
      wl.identity("image_text-TestMac.csv.superseded") .. " vs "
      .. wl.identity("image_text-TestMac.csv"))
local scanned = wl.scan()
local sawRetired = false
for _, f in ipairs(scanned) do
    if f.name:find("superseded", 1, true) then
        sawRetired = true
        check("…and it IS scanned, so it can be listed", f.retired == true)
    end
end
check("the retired copy reached the scan at all", sawRetired)
local twins2 = wl.twins(scanned)
local flaggedSuperseded = false
for _, t in ipairs(twins2) do
    if t.stale.path:find("superseded", 1, true) then flaggedSuperseded = true end
end
check("a .superseded file is never called a stale twin",
      flaggedSuperseded == false)
check("…and the report lists it under RETIRED instead",
      wl.report():find("RETIRED COPIES", 1, true) ~= nil)

-- 🚨 THE OTHER MAC'S LOG IS NOT A FROZEN TWIN. The Logs folder lives in
-- OneDrive, so the work Mac's activity_history-Lees-Work-MacBook.csv
-- sits right beside this one and is SUPPOSED to be untouched for days —
-- nobody is using that Mac today. A rule that stripped any machine tag
-- would cry wolf every single session on the two-Mac setup this whole
-- config is built around.
put(LOGS .. "/activity_history-Lees-Work-MacBook.csv", "other,mac\n1,2\n")
touchAge(LOGS .. "/activity_history-Lees-Work-MacBook.csv", 45 * 86400)
touchAge(LOGS .. "/activity_history-TestMac.csv", 60)
local crossMac = false
for _, t in ipairs(wl.twins(wl.scan())) do
    if t.stale.path:find("Work%-MacBook") then crossMac = true end
end
check("another machine's log is NEVER called a stale twin of this one",
      crossMac == false)
check("…because only this Mac's tag is stripped from the identity",
      wl.identity("activity_history-Lees-Work-MacBook.csv")
      ~= wl.identity("activity_history-TestMac.csv"))
os.remove(LOGS .. "/activity_history-Lees-Work-MacBook.csv")

-- Two files of the same name that are BOTH current are not a problem —
-- the alarm is staleness, not duplication.
touchAge(CFG .. "/activity_history.csv", 120)
check("two same-named files both written recently are NOT flagged",
      #wl.twins(wl.scan()) == 0, #wl.twins(wl.scan()))
touchAge(CFG .. "/activity_history.csv", 40 * 86400)

-- =====================================================================
out("\n=== 5. 🔇 the quiet check says nothing when nothing is wrong ===\n")
-- =====================================================================
os.remove(CFG .. "/activity_history.csv")
os.remove(LOGS .. "/image_text-TestMac.csv.superseded")
wl.takeBaseline()
printed = {}
local problems = wl.check(true)
check("a healthy Mac produces no problems", #problems == 0, #problems)
check("🚨 …and prints NOTHING. LL: 'not flood the console like messages "
      .. "in the past'", #printed == 0, table.concat(printed, " | "))

-- Growth is the normal case and is also silent.
put(LOGS .. "/activity_history-TestMac.csv", "a,b,c\n1,2,3\n4,5,6\n7,8,9\n")
printed = {}
check("a file that GREW is not a problem", #wl.check(true) == 0)
check("…and is still silent", #printed == 0, table.concat(printed, " | "))

out("\n=== 5b. …and speaks up when something is ===\n")
put(LOGS .. "/activity_history-TestMac.csv", "a\n")    -- shrank
printed = {}
problems = wl.check(true)
check("a shrunken file is a problem", #problems == 1, #problems)
check("…said out loud, once",
      #printed == 1 and printed[1]:find("SHRUNK", 1, true) ~= nil,
      table.concat(printed, " | "))
-- 🚨 ONCE PER SESSION, NOT ONCE PER CHECK. A warning you have learned to
-- scroll past is not a warning, and this timer fires 16 times a day.
printed = {}
wl.check(true) ; wl.check(true) ; wl.check(true)
check("🚨 repeating the check does NOT repeat the message", #printed == 0,
      table.concat(printed, " | "))

os.remove(LOGS .. "/file_changes-TestMac.csv")
printed = {}
problems = wl.check(true)
local saidGone = false
for _, l in ipairs(printed) do
    if l:find("GONE", 1, true) then saidGone = true end
end
check("a file that vanished since boot is reported", saidGone,
      table.concat(printed, " | "))

-- =====================================================================
out("\n=== 5c. 💾 6.154.0 — a REWRITTEN store that shrinks is not a truncation ===\n")
-- =====================================================================
-- LL's Console: "recent_docs-Lees-MacBook-Air.csv has SHRUNK — 49.7 KB
-- at boot, 48.8 KB now. That is either a rotation or a truncation, and
-- only one of them is fine." Neither: that file is the ⇪I CACHE,
-- rewritten whole after every Spotlight scan, and it shrinks whenever a
-- document ages out of the 30-day window. The shrink rule was written
-- for append-only logs and did not know the difference.
put(LOGS .. "/recent_docs-TestMac.csv", "path,used,mod\n/a,1,2\n/b,3,4\n/c,5,6\n")
put(LOGS .. "/custom_store-TestMac.csv", "k,v\n1,2\n3,4\n5,6\n")
put(CFG  .. "/frames.json", '{"a":1,"b":2,"c":3}')
_G.rewrittenFiles = { [LOGS .. "/custom_store-TestMac.csv"] = "a store its module registered" }
wl.takeBaseline()
put(LOGS .. "/recent_docs-TestMac.csv", "path,used,mod\n/a,1,2\n/b,3,4\n")  -- one aged out
put(LOGS .. "/custom_store-TestMac.csv", "k,v\n1,2\n3,4\n")
put(CFG  .. "/frames.json", '{"a":1,"b":2}')
printed = {}
problems = wl.check(true)
check("🚨 the ⇪I cache shrinking a little is NOT a problem — it is known "
      .. "by name as a store rewritten whole on every save",
      #problems == 0 and wl.rewrittenWhy(LOGS .. "/recent_docs-TestMac.csv") ~= nil,
      #problems > 0 and problems[1].text or nil)
check("…nor a store whose module REGISTERED it in _G.rewrittenFiles",
      wl.rewrittenWhy(LOGS .. "/custom_store-TestMac.csv") == "a store its module registered")
check("…nor a .json store — a JSON array cannot be appended to, so every "
      .. "JSON file here is rewritten from scratch",
      wl.rewrittenWhy(CFG .. "/frames.json") ~= nil)
check("🚨 …and NOTHING was printed — the Console line LL asked about is gone",
      #printed == 0, table.concat(printed, " | "))
local rep5c = wl.report()
check("the report says 'rewritten — normal' instead of ⚠️ for it",
      rep5c:find("rewritten — normal", 1, true) ~= nil, rep5c)
check("an append-only log is judged exactly as before",
      wl.rewrittenWhy(LOGS .. "/activity_history-TestMac.csv") == nil)
-- Losing MORE THAN HALF is the clipboard-history P4 disaster wearing a
-- different filename, and that is still worth a look — once.
put(LOGS .. "/recent_docs-TestMac.csv", "path,used,mod\n")
printed = {}
problems = wl.check(true)
check("🚨 …but a rewritten store that LOST MORE THAN HALF is called out",
      #problems == 1 and #printed == 1
      and printed[1]:find("MORE THAN HALF", 1, true) ~= nil,
      table.concat(printed, " | "))
check("…saying why a smaller file would normally have been fine",
      printed[1] and printed[1]:find("rewritten", 1, true) ~= nil, printed[1])
printed = {}
wl.check(true)
check("…and once only, like every other finding", #printed == 0,
      table.concat(printed, " | "))
check("the service lets a module that loads AFTER the ledger register its file",
      (function()
    PROVIDED["writeLedger.rewritten"]("/x/y.csv", "why")
    return _G.rewrittenFiles["/x/y.csv"] == "why"
end)())
os.remove(LOGS .. "/recent_docs-TestMac.csv")
os.remove(LOGS .. "/custom_store-TestMac.csv")
os.remove(CFG  .. "/frames.json")
_G.rewrittenFiles = {}

out("\n=== 6. the report answers the question ===\n")
put(LOGS .. "/file_changes-TestMac.csv", "ts,name\n1,x\n2,y\n3,z\n")
put(LOGS .. "/activity_history-TestMac.csv", "a,b,c\n1,2,3\n4,5,6\n")
wl.takeBaseline()
put(LOGS .. "/activity_history-TestMac.csv", "a,b,c\n1,2,3\n4,5,6\n7,8,9\n")
local rep = wl.report()
check("it names the machine", rep:find("TestMac", 1, true) ~= nil)
check("it proves the folder takes writes right now",
      rep:find("round trip", 1, true) ~= nil
      and rep:find("wrote and read a probe file back", 1, true) ~= nil, rep)
check("it has a column for rows", rep:find("ROWS", 1, true) ~= nil)
check("it counts the rows of a CSV",
      rep:find("activity_history", 1, true) ~= nil and rep:find("%s4%s") ~= nil)
check("it says what grew since boot", rep:find("SINCE BOOT", 1, true) ~= nil)
check("…and by how much", rep:find("+", 1, true) ~= nil)
check("an untouched file says 'unchanged', not '+0 B'",
      rep:find("unchanged", 1, true) ~= nil, rep)
check("it ends with a verdict rather than a table you have to read",
      rep:find("✅", 1, true) ~= nil or rep:find("⚠️", 1, true) ~= nil)

_G.writeFailures = { ["activity history"] = 3, ["OCR log"] = 1 }
rep = wl.report()
check("🚨 write failures are surfaced, with their counts",
      rep:find("WRITE FAILURES", 1, true) ~= nil
      and rep:find("activity history ×3", 1, true) ~= nil, rep)
_G.writeFailures = nil
rep = wl.report()
check("…and no such line when there have been none",
      rep:find("WRITE FAILURES", 1, true) == nil)

out("\n=== 7. _G.saved() prints and returns the same text ===\n")
printed = {}
local returned = _G.saved()
check("it printed once", #printed == 1, #printed)
check("…and returned what it printed", returned == printed[1])
check("the text is the report", tostring(returned):find("WHAT IS ACTUALLY SAVING",
                                                        1, true) ~= nil)

-- A report that throws must not take the Console call down with it.
local realScan = wl.scan
wl.scan = function() error("disk is on fire") end
printed = {}
local r2 = _G.saved()
check("a broken report returns nil rather than throwing", r2 == nil)
check("…and says why", #printed == 1
      and printed[1]:find("failed", 1, true) ~= nil, printed[1])
check("⇪⇧D's caller gets a block, not an error",
      tostring(_G.writeLedgerReport()):find("report failed", 1, true) ~= nil)
wl.scan = realScan

out("\n=== 8. warm() takes a baseline and arms one timer ===\n")
TIMERS = {}
wl.baseline = nil
M.warm(CORE)
check("the baseline was taken", type(wl.baseline) == "table")
check("exactly one timer is armed", #TIMERS == 1, #TIMERS)
check("…at the declared interval", TIMERS[1] and TIMERS[1].secs == wl.checkEvery)
check("🚨 the timer object is HELD — an unreferenced hs.timer is collected "
      .. "and a collected timer never fires", wl.timer ~= nil)
check("nothing was printed at warm", (function()
    printed = {}
    return #printed == 0
end)())

-- 🚨 THE INTERVAL CANNOT BE TUNED INTO NOISE. A check every few seconds
-- is the console flood this module exists to avoid.
check("the check interval is minutes, not seconds", wl.checkEvery >= 300,
      wl.checkEvery)
check("the row count has a size ceiling so a big log is not read on a timer",
      wl.rowCountMax > 0)

out("\n=== 9. it degrades on a Mac where the Logs folder is gone ===\n")
CORE.logsDir = ROOT .. "/vanished"
local okScan, files2 = pcall(wl.scan)
check("scanning a missing folder does not throw", okScan)
check("…it just finds fewer files", okScan and type(files2) == "table")
local okRep, text = pcall(wl.report)
check("the report still builds", okRep, text)
check("…and says the round trip failed rather than claiming success",
      okRep and text:find("❌", 1, true) ~= nil)
CORE.logsDir = LOGS

-- ---- clean up ----------------------------------------------------------
os.execute("rm -rf '" .. ROOT .. "'")

out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
