-- =====================================================================
-- test_console.lua — the console gate: the ⛔ ERRORS section, the
-- ⚠️ NONBREAKING section (6.96.0), and the repeat limiter. 6.95.0+
-- =====================================================================
--     lua5.4 test_console.lua [/path/to/hammerspoon]
--
-- The requirement, in the owner's words: "when there is an error, place
-- it in a defined section in the output of the console ... a header
-- that said ERRORS with some kind of double : characters that make it
-- stand out, and if the errors are repetitive, it limits the number of
-- repeating errors ... If they are not, it would report unique
-- individual errors."  And 6.96.0: "separate a type of error, errors
-- that don't break hammer spoon operations ... put that in its own
-- section that way I can work on errors with you."
--
-- The properties held here:
--   P1  A CLASSIFIED LINE OPENS ITS SECTION, ONCE. Consecutive lines of
--       one kind share one banner; a different kind, or normal output,
--       closes it first — sections never interleave.
--   P1b BREAKING AND NONBREAKING ARE SEPARATE SECTIONS. 💥/traceback
--       shapes wear the ::⛔:: banner; ⚠️/error shapes wear ----⚠️----.
--   P2  A REPEATING LINE STOPS AT THE LIMIT and is counted, not lost —
--       and lines differing only in NUMBERS count as the same line.
--   P3  UNIQUE ERRORS ALL PRINT. Suppression is per-line, never global.
--   P4  NOTHING REPORT-SHAPED IS EVER GATED. Multi-line or very long
--       output passes straight through — you cannot suppress ⇪⇧D.
--   P5  THE GATE NEVER EATS A LINE, even when the gate itself is broken.
--   P6  QUIET LINES COME BACK. After the window passes, the hidden count
--       is summarised and the line prints again.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end

-- ---- a controllable Mac ----------------------------------------------
local CLOCK = 1000
hs = { timer = { secondsSinceEpoch = function() return CLOCK end } }

-- The "real" console: everything the gate lets through lands here.
local OUT = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    OUT[#OUT + 1] = table.concat(p, "\t")
end

local chunk, loadErr = loadfile(HS .. "/core/console.lua")
if not chunk then
    realPrint("cannot load core/console.lua: " .. tostring(loadErr))
    realPrint("0 passed, 1 failed")
    os.exit(1)
end
local con = chunk()({})

local function outHas(s)
    for _, l in ipairs(OUT) do if l:find(s, 1, true) then return true end end
    return false
end
local function countOut(s)
    local n = 0
    for _, l in ipairs(OUT) do if l:find(s, 1, true) then n = n + 1 end end
    return n
end
local function firstAt(s)
    for i, l in ipairs(OUT) do if l:find(s, 1, true) then return i end end
end
local function reset() OUT = {}; con.tracked = {}; con.order = {}
                       con.section = nil end

-- =====================================================================
realPrint("-- 1. install: print is now the gate, raw is the console ----")
-- =====================================================================
check("loading the file returns the gate table", type(con) == "table")
check("the gate is installed over print", print == con.gate)
check("_G.consoleGate is published for the Console", _G.consoleGate == con)
check("_G.errorsReport is published", type(_G.errorsReport) == "function")
check("the gate is on by default", con.enabled == true)

print("plain line one")
check("a normal line passes through", outHas("plain line one"))
check("a normal line opens no banner",
      not outHas("ERRORS") and not outHas("NONBREAKING"))
check("multiple args join like print does", (function()
    reset(); print("a", 1, "b")
    return OUT[1] == "a\t1\tb"
end)())

-- =====================================================================
realPrint("-- 2. the ⛔ ERRORS section (P1) -----------------------------")
-- =====================================================================
reset()
print("booting module A")
print("💥 module B: failed while loading — boom")
check("a breaking line opens the ⛔ banner", outHas("⛔ ERRORS"))
check("the banner uses the :: characters LL asked for", (function()
    for _, l in ipairs(OUT) do
        if l:find("⛔ ERRORS", 1, true) then return l:find("::", 1, true) ~= nil end
    end
end)())
check("the banner prints BEFORE the error", (function()
    local bAt, eAt = firstAt("⛔ ERRORS"), firstAt("module B")
    return bAt and eAt and bAt < eAt
end)())

print("💥 module C: also broken uncaught")
check("a second consecutive breaking error shares the banner (one, not two)",
      countOut("⛔ ERRORS") == 1)
print("normal service resumes")
check("the first normal line closes the section", outHas("end errors"))
check("the close lands BEFORE the normal line", (function()
    local cAt, nAt = firstAt("end errors"), firstAt("normal service")
    return cAt and nAt and cAt < nAt
end)())
print("💥 UNCAUGHT: later trouble")
check("a LATER breaking error opens a fresh banner", countOut("⛔ ERRORS") == 2)

-- =====================================================================
realPrint("-- 2b. the ⚠️ NONBREAKING section (P1b, 6.96.0) --------------")
-- =====================================================================
reset()
print("⚠️ module D: folder missing, carrying on")
check("a nonbreaking line opens the ---- banner, not the :: one",
      outHas("⚠️ NONBREAKING") and not outHas("⛔ ERRORS"))
check("…drawn with dashes so the two sections read differently", (function()
    for _, l in ipairs(OUT) do
        if l:find("⚠️ NONBREAKING", 1, true) then
            return l:find("--", 1, true) ~= nil and l:find("::", 1, true) == nil
        end
    end
end)())
print("🚨 module E: cannot write its CSV")
check("a second nonbreaking line shares the banner",
      countOut("⚠️ NONBREAKING") == 1)
print("💥 module F: traceback follows")
check("a BREAKING line closes the nonbreaking section first", (function()
    local softClose, hardOpen = firstAt("end nonbreaking"), firstAt("⛔ ERRORS")
    return softClose and hardOpen and softClose < hardOpen
end)())
print("back to normal")
check("…and normal output closes the breaking one", outHas("end errors"))
check("sections never nest — every open banner was closed",
      con.section == nil)

check("the classifier splits the config's actual vocabulary", (function()
    local hard = { "💥 boom", "⛔ blocked", "stack traceback:",
                   "UNCAUGHT: x", "core/console.lua failed to load",
                   "failed while loading — nil", "syntax error near ')'" }
    local soft = { "⚠️ warn", "🚨 bad", "❌ no",
                   "plain error: x", "task FAILED" }
    for _, s in ipairs(hard) do
        if con.kindOf(s) ~= "hard" then return false, s end
    end
    for _, s in ipairs(soft) do
        if con.kindOf(s) ~= "soft" then return false, s end
    end
    return true
end)())
check("isError still answers the old question for both kinds",
      con.isError("💥 boom") and con.isError("⚠️ warn"))
check("an ordinary receipt is neither", con.kindOf("📋 Copied 3 items") == nil)

-- =====================================================================
realPrint("-- 3. the repeat limiter (P2) -------------------------------")
-- =====================================================================
reset()
for _ = 1, 8 do print("⚠️ widget X: could not sync") end
check("a repeating error prints exactly repeatLimit times",
      countOut("could not sync") == con.repeatLimit,
      countOut("could not sync"))
check("then ONE ↻ notice says it is repeating", countOut("↻ that line is repeating") == 1)
check("the ↻ notice points at _G.errorsReport()", outHas("_G.errorsReport()"))
check("the hidden copies were counted, not lost", (function()
    for _, e in pairs(con.tracked) do
        if e.sample:find("widget X", 1, true) then return e.total == 8 end
    end
end)())

reset()
print("⚠️ retry 1/5 in 2s")
print("⚠️ retry 2/5 in 4s")
print("⚠️ retry 3/5 in 8s")
check("lines differing only in NUMBERS are the same line (counters/timestamps)",
      countOut("retry") == con.repeatLimit, countOut("retry"))
check("…and they share one record with the full count", (function()
    local n = 0
    for _, e in pairs(con.tracked) do
        if e.sample:find("retry", 1, true) then n = e.total end
    end
    return n == 3
end)())

-- =====================================================================
realPrint("-- 4. unique errors all print (P3) --------------------------")
-- =====================================================================
reset()
print("⚠️ alpha broke")
print("⚠️ beta broke")
print("⚠️ gamma broke")
check("three DIFFERENT errors all print — suppression is per-line",
      outHas("alpha broke") and outHas("beta broke") and outHas("gamma broke"))
check("…inside a single shared banner", countOut("⚠️ NONBREAKING") == 1)

-- =====================================================================
realPrint("-- 5. report-shaped output is never gated (P4) --------------")
-- =====================================================================
reset()
local report = "🩺 REPORT\nline two\nline three"
for _ = 1, 5 do print(report) end
check("a multi-line report prints EVERY time you ask for it",
      countOut("🩺 REPORT") == 5, countOut("🩺 REPORT"))
local long = "L" .. string.rep("x", con.bigLine + 10)
for _ = 1, 5 do print(long) end
check("a very long line passes through ungated every time",
      countOut("Lxxx") == 5)
check("passthrough leaves no dangling banner state", con.section == nil)

reset()
print("⚠️ one error")
check("banner open before the report", con.section == "soft")
print(report)
check("a passthrough CLOSES an open section first", (function()
    local cAt, rAt = firstAt("end nonbreaking"), firstAt("🩺 REPORT")
    return cAt and rAt and cAt < rAt and con.section == nil
end)())

-- =====================================================================
realPrint("-- 6. the gate can break; the line still prints (P5) --------")
-- =====================================================================
reset()
local realDecide = con.decide
con.decide = function() error("the gate itself is broken") end
print("⚠️ must still reach the console")
check("a broken gate falls back to printing RAW", outHas("must still reach"))
con.decide = realDecide

con.enabled = false
reset()
for _ = 1, 4 do print("⚠️ same line") end
check("enabled=false is a true passthrough — no limiting", countOut("same line") == 4)
check("…and no banner", not outHas("NONBREAKING"))
con.enabled = true

-- =====================================================================
realPrint("-- 7. quiet lines come back (P6) ----------------------------")
-- =====================================================================
reset()
for _ = 1, 6 do print("⚠️ flappy thing failed") end
check("suppressed while repeating", countOut("flappy thing") == con.repeatLimit)
CLOCK = CLOCK + con.repeatWindow + 1
print("⚠️ flappy thing failed")
check("after the quiet window it prints again",
      countOut("flappy thing") >= con.repeatLimit + 1)
check("…and the hidden count is summarised first", outHas("↻ ×4 more were hidden"))

-- =====================================================================
realPrint("-- 8. _G.errorsReport() — both kinds, grouped ---------------")
-- =====================================================================
reset()
for _ = 1, 7 do print("⚠️ disk D: write refused") end
print("💥 module Q: failed while loading — nil")
print("a normal line between")
local s = _G.errorsReport()
check("the report returns a string", type(s) == "string")
check("it lists the repeated error with its FULL count", s:find("×7", 1, true) ~= nil, s)
check("it lists the breaking error too", s:find("module Q", 1, true) ~= nil)
check("it does not list normal lines", s:find("a normal line between", 1, true) == nil)
check("breaking wears the :: banner, nonbreaking the ---- one",
      s:find("⛔ ERRORS", 1, true) ~= nil
      and s:find("⚠️ NONBREAKING", 1, true) ~= nil)
check("breaking is listed FIRST, the improvement pile after", (function()
    local hardAt = s:find("module Q", 1, true)
    local softAt = s:find("disk D", 1, true)
    return hardAt and softAt and hardAt < softAt
end)())
check("the report goes through raw print (visible in the console)",
      outHas("disk D: write refused"))

reset()
local s2 = _G.errorsReport()
check("an error-free session says so, in both sections",
      s2:find("none — nothing has broken", 1, true) ~= nil
      and s2:find("none — nothing nonbreaking", 1, true) ~= nil, s2)

-- =====================================================================
realPrint("-- 9. bounds and hygiene ------------------------------------")
-- =====================================================================
reset()
-- Letter tags, not digit suffixes: numbers are normalized away (and a
-- line grown past bigLine would pass through), so distinct keys must
-- differ in LETTERS while staying short.
local function tag(i)
    local s = ""
    repeat s = string.char(97 + i % 26) .. s; i = math.floor(i / 26) until i == 0
    return s
end
for i = 1, con.maxTracked + 50 do print("unique " .. tag(i)) end
check("the tracked table is bounded (oldest forgotten)",
      #con.order == con.maxTracked, #con.order)

check("each record remembers WHICH section it belongs to", (function()
    reset()
    print("⚠️ politely degraded")
    print("💥 actually broken")
    local soft, hard
    for _, e in pairs(con.tracked) do
        if e.sample:find("politely", 1, true) then soft = e.kind end
        if e.sample:find("actually", 1, true) then hard = e.kind end
    end
    return soft == "soft" and hard == "hard"
end)())

check("uninstall restores the raw print", (function()
    con.uninstall()
    local restored = (print == con.raw)
    con.install()
    return restored and print == con.gate
end)())

check("a second load takes over the FIRST gate's raw print (no chain)", (function()
    local c2 = loadfile(HS .. "/core/console.lua")()({})
    local ok = (c2.raw == con.raw) and print == c2.gate
    -- put the original back for anything after us
    _G.consoleGate = con; con.install()
    return ok
end)())

check("no hs.timer on this Mac still ticks (os.time fallback)", (function()
    local savedTimer = hs.timer
    hs.timer = nil
    reset()
    local ok = pcall(print, "⚠️ clockless error")
    hs.timer = savedTimer
    return ok and outHas("clockless error")
end)())

-- =====================================================================
print = realPrint
print(string.format("%d passed, %d failed", pass, fail))
for _, f in ipairs(failures) do print("   ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
