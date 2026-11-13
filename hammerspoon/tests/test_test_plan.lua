-- =====================================================================
-- test_test_plan.lua — tools/build-test-plan.lua, driven as a process
-- =====================================================================
--     lua5.4 tests/test_test_plan.lua [/path/to/hammerspoon]
--
-- 🚨 WHY THIS SUITE EXISTS, and it is 6.271.0's own finding one layer
-- out. That release shipped the test plan because the steps were being
-- written where only I could read them; the generator that lifts them
-- has had NO suite since, and it is the one tool whose failure hands LL
-- a document describing a release that was not built. 6.271.0 says a
-- stale plan is worse than none, because he runs the wrong steps and
-- reports a pass on something that does not exist.
--
-- 🔎 TWO REAL HOLES IT FOUND, both fixed in 6.428.0 and both pinned
-- below by a fixture that BITES (6.230.0 — pick the input where right
-- and wrong must differ):
--   · no ARCHITECTURE VERSION CONTROL stamp → it wrote a plan headed
--     "release ?" instead of refusing. That happens the moment the tool
--     is run without its <hs> argument, which is exactly how it was hit.
--   · steps for older releases but NONE for the one being built → it
--     wrote a plan NAMING this release whose newest section was the
--     previous one.
--
-- 📏 THE TOOL IS RUN AS A SUBPROCESS, from a clean working directory.
-- It falls back to reading CLAUDE.md from the CWD, so a suite that ran
-- it from the repo root would silently read the REAL release notes and
-- measure nothing (6.313.0 — a sentry over a haystack it did not prove
-- it read is green and measures nothing).
-- =====================================================================
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR") or "."

local pass, fail = 0, 0
local function check(label, ok, got)
    if ok then pass = pass + 1; print("  ✅ " .. label)
    else fail = fail + 1
         print("  ❌ " .. label .. (got and (" — " .. tostring(got)) or "")) end
end

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function write(path, text)
    local f = assert(io.open(path, "w")); f:write(text); f:close()
end
local function read(path)
    local f = io.open(path, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

-- an absolute path to the tool, because the tests run from elsewhere
local TOOL = HS .. "/tools/build-test-plan.lua"
if not TOOL:match("^/") then
    local p = io.popen("pwd"); local cwd = p:read("*l"); p:close()
    TOOL = cwd .. "/" .. TOOL
end
if not read(TOOL) then
    print("  ❌ cannot read " .. TOOL)
    print("0 passed, 1 failed"); os.exit(1)
end

local root = os.tmpname(); os.remove(root)
-- a space in the path on purpose: every argument this tool is given must
-- survive one, and the ceremony runs it against a real folder name
assert(os.execute("mkdir -p " .. q(root .. "/config dir")))
local CFG  = root .. "/config dir"
local PLAN = CFG .. "/TESTING.md"

-- run from a CLEAN cwd so the tool's CWD fallback cannot reach the real
-- CLAUDE.md of this repo
local function run(...)
    local parts = { "cd", q(root), "&&", "lua5.4", q(TOOL), q(CFG) }
    for _, v in ipairs({ ... }) do parts[#parts + 1] = q(v) end
    local cmd = table.concat(parts, " ") .. " 2>&1"
    local p = assert(io.popen(cmd))
    local text = p:read("*a")
    local ok = p:close()
    return ok == true, text or ""
end

local STAMP = "-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.999.0\n"
local NOTES =
    "- 6.999.0 verify with LL — the current one\n  PASS, FAIL or BLOCKED.\n\n"
 .. "- 6.998.0 verify with LL — the one before\n  Older steps.\n\n"
 .. "- 6.9.0 verify with LL — ancient\n  Must not sort above 6.998.0.\n"

-- ---------------------------------------------------------------- 1. writes
write(CFG .. "/init.lua", STAMP)
write(root .. "/CLAUDE.md", NOTES)
local ok = run()
check("a release with steps writes a plan", ok)
local plan = read(PLAN)
check("the plan exists", plan ~= nil)
plan = plan or ""
check("the title names the version from init.lua",
      plan:find("# TESTING — how to score release 6.999.0", 1, true) ~= nil)
check("the current release has a section", plan:find("## 6.999.0", 1, true) ~= nil)
check("the previous release is carried too", plan:find("## 6.998.0", 1, true) ~= nil)

-- 🔎 THE FIRST-LINE BLOCK. NOTES begins with a verify header at position
-- 1, and the scan needed a newline in front of one — so this very
-- fixture was invisible to the generator before 6.428.0. It is also why
-- the check above is the one that proves the fix.
check("a verify block on the source's FIRST line is found",
      plan:find("the current one", 1, true) ~= nil)

-- versions sort NUMERICALLY, newest first: 6.9.0 must not outrank 6.998.0
do
    local a = plan:find("## 6.999.0", 1, true) or 0
    local b = plan:find("## 6.998.0", 1, true) or 0
    local c = plan:find("## 6.9.0", 1, true) or 0
    check("releases are ordered newest first, numerically",
          a > 0 and b > a and c > b, ("%d/%d/%d"):format(a, b, c))
end

-- ------------------------------------------------------------- 2. the depth
check("a depth of 1 keeps only the current release",
      run("1") and not (read(PLAN) or ""):find("## 6.998.0", 1, true))
run()  -- back to the default depth

-- --------------------------------------------------------- 3. --check order
-- 6.420.0: BOTH options are read from EVERY position. `<hs> 4 --check`
-- used to set the depth, leave CHECK false and WRITE the file — a
-- verification that cannot fail because it overwrites what it verifies.
plan = read(PLAN)
check("--check passes on a current plan (flag first)", run("--check", "4"))
check("--check passes on a current plan (depth first)", run("4", "--check"))
check("--check changed nothing", read(PLAN) == plan)

write(PLAN, "a stale plan\n")
check("--check FAILS on a stale plan (depth first)", not run("4", "--check"))
check("a failed --check never rewrites the plan", read(PLAN) == "a stale plan\n")
check("--check FAILS on a stale plan (flag first)", not run("--check"))
check("an ordinary run repairs a stale plan", run())

-- ------------------------------------------------- 4. refused arguments
plan = read(PLAN)
for _, bad in ipairs({ "0", "1.5", "-2", "--unknown", "--Check" }) do
    check("an argument it does not understand is refused: " .. bad, not run(bad))
end
check("a refused argument leaves the plan intact", read(PLAN) == plan)

-- ------------------------------------------- 5. no stamp → no plan at all
-- The fixture that BITES: before 6.428.0 this wrote a file headed
-- "release ?", which is how it was hit — the tool run without its <hs>
-- argument read no init.lua and took the fallback.
write(CFG .. "/init.lua", "-- a file with no version stamp anywhere\n")
local refusedOk, refusedText = run()
check("no version stamp is REFUSED", not refusedOk)
check("the refusal names the argument to pass",
      refusedText:find("build%-test%-plan: no ARCHITECTURE VERSION CONTROL") ~= nil
      and refusedText:find("pass the config directory", 1, true) ~= nil,
      refusedText:sub(1, 60))
check("a refused version writes no plan over the old one",
      read(PLAN) == plan)

-- ------------------------------- 6. no steps for THIS release → no plan
write(CFG .. "/init.lua", STAMP)
write(root .. "/CLAUDE.md",
      "- 6.998.0 verify with LL — only the older one\n  Older steps.\n")
local noCur, noCurText = run()
check("steps for an older release but none for this one is REFUSED", not noCur)
check("the refusal names the missing block",
      noCurText:find("6.999.0 verify with LL", 1, true) ~= nil,
      noCurText:sub(1, 60))
check("the previous plan survives a refusal", read(PLAN) == plan)

-- --------------------------------------------- 7. no release notes at all
os.remove(root .. "/CLAUDE.md")
check("no CLAUDE.md anywhere is REFUSED", not run())
check("the plan still survives that too", read(PLAN) == plan)

assert(os.execute("rm -rf " .. q(root)))
print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
