-- =====================================================================
-- test_default_apps.lua — 📎 a file type opens in the app YOU chose
-- =====================================================================
--     lua5.4 test_default_apps.lua [/path/to/hammerspoon]
--
-- Executes modules/default_apps.lua against a stubbed hs and drives the
-- REAL functions: the extension guard, the two-picker flow, the
-- osascript argv, the read-back verdict (status 0 is NOT success), the
-- case-insensitive bundle compare, the 2-second re-check that catches a
-- reverted write, the report, and the honest failure paths. The JXA
-- script itself is pinned as text — both LaunchServices witnesses must
-- stay in it. Nothing here touches a real LaunchServices database.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local ALERTS, TASKS, TIMERS, SAID, WARNED = {}, {}, {}, {}, {}
local CHOOSERS = {}
local realPrint = print

hs = {
    alert = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, argv)
            local t = { bin = bin, cb = cb, argv = argv, started = false }
            function t:start() self.started = true; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, rows = nil, shown = 0 }
            function c:choices(t) self.rows = t; return self end
            function c:placeholderText(p) self.placeholder = p; return self end
            function c:query(q) self.q = q; return self end
            function c:queryChangedCallback(fn) self.qcb = fn; return self end
            function c:searchSubText() return self end
            function c:width() return self end
            function c:show() self.shown = self.shown + 1; return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say  = function(_, m) SAID[#SAID + 1] = tostring(m) end,
            warn = function(_, m) WARNED[#WARNED + 1] = tostring(m) end,
            err  = function() end }

-- The module hands osascript's stdout to core.safeJson. The suite maps
-- each exact reply string it feeds back to the table it decodes to — a
-- real JSON parser would only obscure which reply drove which check.
local CANNED = {}
local function canned(str, tbl) CANNED[str] = tbl; return str end

local SERVICES, POPPED = {}, {}
local core = {
    provide  = function(name, fn) SERVICES[name] = fn end,
    showPopup = function(ch) POPPED[#POPPED + 1] = ch; ch:show() end,
    safeJson = function(body) return CANNED[body] end,
}

local chunk = assert(loadfile(HS .. "/modules/default_apps.lua"),
                     "cannot load modules/default_apps.lua")
local function boot()
    ALERTS, TASKS, TIMERS, SAID, WARNED = {}, {}, {}, {}, {}
    CHOOSERS, POPPED = {}, {}
    local M = chunk()
    M.setup(core)
    return _G.defaultApps, M
end

local function lastTask() return TASKS[#TASKS] end

-- =====================================================================
out("── Default Apps: a file type opens in the app YOU chose, proven ──\n")

out("\n=== 1. The module contract ===\n")
local da, M = boot()
check("name, order and family are declared",
      M.name == "Default Apps" and M.order == 14.2 and M.family == "config")
check("the cheat sheet group announces itself",
      M.cheatsheet and M.cheatsheet.title:find("DEFAULT APPS", 1, true) ~= nil)
check("the 📎 key cell appears EXACTLY once — the run map joins by it", (function()
    local n = 0
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "📎" then n = n + 1 end
    end
    return n == 1, n
end)())
check("...and one row points at the report", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[2]:find("_G.defaultAppsReport", 1, true) then return true end
    end
    return false
end)())
check("both services are published",
      SERVICES["defaultApps.show"] ~= nil and SERVICES["defaultApps.report"] ~= nil)
check("the binary is a named constant the external-binary review can see",
      da.OSASCRIPT == "/usr/bin/osascript")

out("\n=== 1b. The wire-up is real, not remembered ===\n")
-- Cross-file sentries: a keyless tool that loses its BASE entry or its
-- run-map row is a tool nobody can reach, and nothing else would notice.
local function readAll(p)
    local f = io.open(p, "r"); if not f then return "" end
    local s = f:read("*a"); f:close(); return s
end
check("init.lua's BASE list loads this module", (function()
    local base = readAll(HS .. "/init.lua"):match("local BASE = {(.-)\n}") or ""
    return base:find('"default_apps"', 1, true) ~= nil
end)())
check("⇪space's run map joins 📎 to defaultApps.show", (function()
    local uni = readAll(HS .. "/modules/unified_search.lua")
    return uni:find('%["📎"%]%s*=%s*"defaultApps%.show"') ~= nil
end)())
check("the gate runs this very suite", (function()
    return readAll(HS .. "/tools/run-tests.sh"):find("test_default_apps", 1, true) ~= nil
end)())

out("\n=== 2. The extension guard ===\n")
check('".PDF" is cleaned to "pdf"', da.cleanExt(".PDF") == "pdf")
check('"  pdf  " loses its whitespace', da.cleanExt("  pdf  ") == "pdf")
check('"tar.gz" style compound extensions pass', da.cleanExt("tar.gz") == "tar.gz")
check('"c++" passes — the plus is a real extension character', da.cleanExt("c++") == "c++")
check("an inner space is refused", da.cleanExt("p df") == nil)
check("a slash is refused — an extension is not a path", da.cleanExt("a/b") == nil)
check("empty is refused", da.cleanExt("") == nil and da.cleanExt("...") == nil)
check("longer than 20 characters is refused",
      da.cleanExt(string.rep("x", 21)) == nil)
check("a non-string is refused, not thrown on", da.cleanExt(nil) == nil
      and da.cleanExt(42) == nil)

out("\n=== 3. The JXA script carries both witnesses ===\n")
-- Pinned as text: these are the API names the whole feature stands on.
-- If one leaves the script, the verdict quietly loses a witness.
check("the write: LSSetDefaultRoleHandlerForContentType",
      da.jxa:find("LSSetDefaultRoleHandlerForContentType", 1, true) ~= nil)
check("witness 1: LSCopyDefaultRoleHandlerForContentType, read AFTER the write",
      da.jxa:find("LSCopyDefaultRoleHandlerForContentType", 1, true) ~= nil)
check("witness 2: NSWorkspace's URLForApplicationToOpenContentType",
      da.jxa:find("URLForApplicationToOpenContentType", 1, true) ~= nil)
check("the script guards its own argv even though Lua guards first",
      da.jxa:find("bad extension", 1, true) ~= nil)
check("every exit is JSON — the outer catch stringifies too",
      da.jxa:find("JSON.stringify", 1, true) ~= nil
      and da.jxa:find("catch", 1, true) ~= nil)
check("the candidate list comes from apps that CLAIM the type",
      da.jxa:find("LSCopyAllRoleHandlersForContentType", 1, true) ~= nil)

out("\n=== 4. sameBundle: LaunchServices lowercases on the way out ===\n")
check("com.adobe.Acrobat matches com.adobe.acrobat",
      da.sameBundle("com.adobe.Acrobat", "com.adobe.acrobat"))
check("a different app never matches",
      not da.sameBundle("com.apple.Preview", "com.adobe.acrobat"))
check("nil is not a match, and not an error",
      not da.sameBundle(nil, "x") and not da.sameBundle("x", nil))

out("\n=== 5. parse: osascript's stdout is not trusted ===\n")
local Q = canned('{"ok":true,"ext":"pdf"}', { ok = true, ext = "pdf" })
check("a JSON body decodes", da.parse(Q) ~= nil and da.parse(Q).ext == "pdf")
check("leading noise around the JSON is trimmed", da.parse("  " .. Q .. "\n") ~= nil)
check("an execution error is nil, not a throw",
      da.parse("execution error: something (-1743)") == nil)
check("empty and nil are nil", da.parse("") == nil and da.parse(nil) == nil)

out("\n=== 6. The verdict: status 0 is NOT success ===\n")
check("a matching read-back is the ONLY success", (function()
    local ok = da.verdict("com.adobe.Acrobat",
                          { ok = true, status = 0, readback = "com.adobe.acrobat" })
    return ok == true
end)())
check("status 0 with the WRONG read-back is a failure — the exact lie "
      .. "this tool exists to catch", (function()
    local ok, why = da.verdict("com.adobe.Acrobat",
                               { ok = true, status = 0, readback = "com.apple.Preview" })
    return ok == false and tostring(why):find("still reports", 1, true) ~= nil, why
end)())
check("no reply at all is a failure that says so", (function()
    local ok, why = da.verdict("x", nil)
    return ok == false and why ~= nil
end)())
check("a script-level error is carried through", (function()
    local ok, why = da.verdict("x", { err = "macOS has no type for .zzz" })
    return ok == false and tostring(why):find("no type", 1, true) ~= nil, why
end)())

out("\n=== 7. Picker 1: the file type ===\n")
da.show()
check("the type chooser opened through core.showPopup, never bare :show()",
      #POPPED == 1 and CHOOSERS[1].shown == 1)
check("it registered for Esc arbitration", _G.choosers.defaultApps == CHOOSERS[1])
check("the empty query lists the whole common set, no literal row",
      #da.rows1 == #da.common, #da.rows1)
CHOOSERS[1].qcb("pdf")
check("typing filters by extension AND label", (function()
    for _, r in ipairs(da.rows1) do
        if r.ext == "pdf" then return true end
    end
    return false
end)())
check("...without inventing a literal row for a listed extension", (function()
    for _, r in ipairs(da.rows1) do
        if r.text:find("📎", 1, true) then return false, r.text end
    end
    return true
end)())
CHOOSERS[1].qcb("xopq")
check("an unlisted extension gets its literal row, FIRST",
      da.rows1[1] and da.rows1[1].ext == "xopq"
      and da.rows1[1].text:find("📎", 1, true) ~= nil,
      da.rows1[1] and da.rows1[1].text)
CHOOSERS[1].qcb("p df")
check("...but not one that fails the guard", (function()
    for _, r in ipairs(da.rows1) do
        if r.text:find("📎", 1, true) then return false end
    end
    return true
end)())

out("\n=== 8. Picking a type asks LaunchServices, not a cache ===\n")
CHOOSERS[1].qcb("pdf")
local pdfIdx
for i, r in ipairs(da.rows1) do if r.ext == "pdf" then pdfIdx = i end end
CHOOSERS[1].cb({ idx = pdfIdx })
local t = lastTask()
check("one osascript task was spawned and started",
      t ~= nil and t.bin == "/usr/bin/osascript" and t.started)
check("...as JavaScript, script inline, op and extension as argv", (function()
    return t.argv[1] == "-l" and t.argv[2] == "JavaScript"
       and t.argv[3] == "-e" and t.argv[4] == da.jxa
       and t.argv[5] == "query" and t.argv[6] == "pdf"
end)())

local QUERY_PDF = canned(
    '{"q":1}',
    { ok = true, ext = "pdf", uti = "com.adobe.pdf",
      current = "com.apple.preview",
      modern = "/System/Applications/Preview.app",
      apps = {
        { bundle = "com.apple.Preview", path = "/System/Applications/Preview.app",
          name = "Preview" },
        { bundle = "com.adobe.Acrobat", path = "/Applications/Acrobat.app",
          name = "Adobe Acrobat" },
        { bundle = "com.gone.app", name = "com.gone.app" },
      } })
t.cb(0, QUERY_PDF, "")
local appCh = CHOOSERS[#CHOOSERS]
check("the app picker opened with every claiming app", #da.rows2 == 3, #da.rows2)
check("today's default wears the star — case-insensitively",
      da.rows2[1].current and da.rows2[1].text:find("⭐", 1, true) ~= nil
      and da.rows2[1].subText:find("current default", 1, true) ~= nil)
check("an app with no path is still offered, and says it is not on disk",
      da.rows2[3].subText:find("not on disk", 1, true) ~= nil, da.rows2[3].subText)
check("the placeholder names the extension AND its UTI",
      tostring(appCh.placeholder):find("pdf", 1, true) ~= nil
      and tostring(appCh.placeholder):find("com.adobe.pdf", 1, true) ~= nil)
check("it registered its own Esc slot",
      _G.choosers.defaultAppsApps == appCh)

out("\n=== 9. Picking the current default changes nothing ===\n")
local before = #TASKS
appCh.cb({ idx = 1 })
check("no write was attempted", #TASKS == before)
check("...and the alert says it already opens there",
      (ALERTS[#ALERTS] or ""):find("already opens", 1, true) ~= nil,
      ALERTS[#ALERTS])

out("\n=== 10. The write, verified by read-back ===\n")
appCh.cb({ idx = 2 })
local setT = lastTask()
check("the set op carries the extension and the bundle id",
      setT.argv[5] == "set" and setT.argv[6] == "pdf"
      and setT.argv[7] == "com.adobe.Acrobat")
local SET_OK = canned(
    '{"s":1}',
    { ok = true, ext = "pdf", uti = "com.adobe.pdf", status = 0,
      readback = "com.adobe.acrobat",
      modern = "/Applications/Acrobat.app" })
setT.cb(0, SET_OK, "")
check("the change is recorded with a ✅ verdict",
      #da.history == 1 and da.history[1].ok == true)
check("...remembering what it replaced",
      da.history[1].was == "com.apple.preview", da.history[1].was)
check("the alert says LaunchServices CONFIRMS, quoting the read-back",
      (ALERTS[#ALERTS] or ""):find("LaunchServices confirms", 1, true) ~= nil
      and (ALERTS[#ALERTS] or ""):find("com.adobe.acrobat", 1, true) ~= nil,
      ALERTS[#ALERTS])
check("a re-check is armed for " .. da.recheckSecs .. "s later",
      #TIMERS == 1 and TIMERS[1].secs == da.recheckSecs)

out("\n=== 11. The re-check: confirmed, or loudly reverted ===\n")
TIMERS[1].fn()
local reQ = lastTask()
check("the re-check ASKS again — same query op", reQ.argv[5] == "query")
reQ.cb(0, QUERY_PDF, "")   -- LS still says Preview: the write was undone
check("a reverted write flips the verdict to FAILED",
      da.history[1].ok == false
      and tostring(da.history[1].recheck):find("REVERTED", 1, true) ~= nil,
      da.history[1].recheck)
check("...and shouts, because you already stopped watching",
      (ALERTS[#ALERTS] or ""):find("REVERTED", 1, true) ~= nil, ALERTS[#ALERTS])

-- the happy path of the same timer
da, M = boot()
da.pending = { ext = "pdf", uti = "com.adobe.pdf", current = "com.apple.preview" }
da.set(da.pending, { bundle = "com.adobe.Acrobat", name = "Adobe Acrobat" })
lastTask().cb(0, SET_OK, "")
TIMERS[#TIMERS].fn()
local CONFIRM = canned(
    '{"c":1}',
    { ok = true, ext = "pdf", uti = "com.adobe.pdf",
      current = "com.adobe.acrobat", apps = {} })
lastTask().cb(0, CONFIRM, "")
check("a re-check that agrees marks the entry confirmed, quietly",
      da.history[1].ok == true and da.history[1].recheck == "confirmed",
      da.history[1].recheck)

out("\n=== 12. The write that did not take ===\n")
da, M = boot()
da.pending = { ext = "pdf", uti = "com.adobe.pdf", current = "com.apple.preview" }
da.set(da.pending, { bundle = "com.adobe.Acrobat", name = "Adobe Acrobat" })
local SET_BAD = canned(
    '{"b":1}',
    { ok = true, ext = "pdf", uti = "com.adobe.pdf", status = -54,
      readback = "com.apple.preview", modern = nil })
lastTask().cb(0, SET_BAD, "")
check("a mismatched read-back is recorded as FAILED, status kept",
      da.history[1].ok == false and da.history[1].status == -54)
check("the alert says DID NOT TAKE and shows the status",
      (ALERTS[#ALERTS] or ""):find("DID NOT TAKE", 1, true) ~= nil
      and (ALERTS[#ALERTS] or ""):find("-54", 1, true) ~= nil, ALERTS[#ALERTS])
check("no re-check is armed for a write that already failed", #TIMERS == 0)

out("\n=== 13. osascript failing is a verdict too ===\n")
da, M = boot()
da.pending = { ext = "pdf", uti = "com.adobe.pdf" }
da.set(da.pending, { bundle = "com.x", name = "X" })
lastTask().cb(1, "execution error: not authorized (-1743)", "")
check("garbage stdout becomes an honest DID NOT RUN, never a throw",
      da.history[1].ok == false
      and (ALERTS[#ALERTS] or ""):find("DID NOT RUN", 1, true) ~= nil,
      ALERTS[#ALERTS])
check("...and the report remembers the problem", da.lastNote ~= nil)

da, M = boot()
da.pickApp("zzz")
lastTask().cb(0, canned('{"e":1}', { ok = false, err = "macOS has no type for .zzz" }), "")
check("an unknown extension is the script's own words on screen",
      (ALERTS[#ALERTS] or ""):find("no type for .zzz", 1, true) ~= nil, ALERTS[#ALERTS])
da.pickApp("pdf")
lastTask().cb(0, canned('{"n":1}',
    { ok = true, ext = "pdf", uti = "com.adobe.pdf", apps = {} }), "")
check("a type nothing claims says so instead of an empty picker",
      (ALERTS[#ALERTS] or ""):find("No installed app claims", 1, true) ~= nil,
      ALERTS[#ALERTS])

out("\n=== 14. The report ===\n")
da, M = boot()
local r = _G.defaultAppsReport()
check("an empty session says so", r:find("nothing changed", 1, true) ~= nil)
check("...and always teaches the per-file override trap",
      r:find("Get Info", 1, true) ~= nil)
da.pending = { ext = "pdf", uti = "com.adobe.pdf", current = "com.apple.preview" }
da.set(da.pending, { bundle = "com.adobe.Acrobat", name = "Adobe Acrobat" })
lastTask().cb(0, SET_OK, "")
r = _G.defaultAppsReport()
check("a verified change prints ✅ with the read-back",
      r:find("✅ verified", 1, true) ~= nil
      and r:find("com.adobe.acrobat", 1, true) ~= nil, r)
check("the report is also a service", SERVICES["defaultApps.report"] ~= nil)

out("\n=== 15. BREAK the guards on purpose ===\n")
local src = readAll(HS .. "/modules/default_apps.lua")

-- BREAK A — the verdict trusts status 0. This is the failure mode the
-- whole feature was requested against: "we need to verify the
-- setting/assignment took". A build whose verdict ignores the read-back
-- calls the -54 write above a success.
do
    local broken = src:gsub(
        'if not da%.sameBundle%(reply%.readback or "", wantBundle%) then',
        'if false then')
    check("BREAK A really edited the source", broken ~= src)
    local okL, bChunk = pcall(load, broken, "broken-defaultapps-A")
    check("...and still compiles", okL and bChunk ~= nil)
    if okL and bChunk then
        local bM = bChunk()
        bM.setup(core)
        local bda = _G.defaultApps
        local took = bda.verdict("com.adobe.Acrobat",
                                 { ok = true, status = 0,
                                   readback = "com.apple.preview" })
        check("without the read-back compare, the wrong app verifies as "
              .. "✅ — proving that compare is the entire verdict",
              took == true, tostring(took))
    end
end

-- BREAK B — the extension guard. Extensions never touch a shell (argv
-- only), so the guard is defense-in-depth — but it is also what keeps
-- "p df/../x" out of the picker row and out of a spawned process.
do
    local broken = src:gsub(
        'if not s:match%("%^%[%%w%%%+%%%._%%%-%]%+%$"%) then return nil end', '')
    check("BREAK B really edited the source", broken ~= src)
    local okL, bChunk = pcall(load, broken, "broken-defaultapps-B")
    check("...and still compiles", okL and bChunk ~= nil)
    if okL and bChunk then
        local bM = bChunk()
        bM.setup(core)
        check("without the character guard, a path walks straight through "
              .. "cleanExt", _G.defaultApps.cleanExt("a/../b") ~= nil)
    end
end

-- BREAK C — the re-check keeps its mouth shut. A reverted write that
-- leaves ok = true is a report that lies forever after.
do
    local broken = src:gsub("entry%.ok = false\n", "\n", 1)
    check("BREAK C really edited the source", broken ~= src)
    local okL, bChunk = pcall(load, broken, "broken-defaultapps-C")
    check("...and still compiles", okL and bChunk ~= nil)
    if okL and bChunk then
        TIMERS, TASKS, ALERTS = {}, {}, {}
        local bM = bChunk()
        bM.setup(core)
        local bda = _G.defaultApps
        bda.pending = { ext = "pdf", uti = "com.adobe.pdf",
                        current = "com.apple.preview" }
        bda.set(bda.pending, { bundle = "com.adobe.Acrobat", name = "Adobe Acrobat" })
        TASKS[#TASKS].cb(0, SET_OK, "")
        TIMERS[#TIMERS].fn()
        TASKS[#TASKS].cb(0, QUERY_PDF, "")   -- LS says Preview again
        check("without the flip, a REVERTED write stays ✅ in history — "
              .. "the lie the intact module refuses to tell",
              bda.history[1].ok == true and
              tostring(bda.history[1].recheck):find("REVERTED", 1, true) ~= nil,
              tostring(bda.history[1].ok))
    end
end

-- rebuild the real module so nothing broken outlives this section
boot()

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
