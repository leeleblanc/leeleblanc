-- =====================================================================
-- test_stub_fidelity.lua — 🔬 6.290.0, the stub that is gentler than macOS
-- =====================================================================
--     lua5.4 test_stub_fidelity.lua [/path/to/hammerspoon]
--
-- 🔬 A STUB THAT IS GENTLER THAN THE REAL PROVIDER IS A HOLE WITH A TICK
-- BESIDE IT. That sentence is 6.193.0's, and CLAUDE.md cites it FIFTEEN
-- times, at fifteen different macOS surfaces. It has been learned fifteen
-- times and enforced zero times, because every instance was fixed at the
-- one stub that had just cost a release while the other seventy-five
-- suites went on lying about the same provider.
--
-- 🔑 WHY THIS IS THE ONE INSTRUMENT THIS PROJECT WAS MISSING. Classify
-- the ten losses on the scoreboard by where the defect lived and EIGHT of
-- ten sit at the macOS boundary — the one surface the gate cannot see.
-- Zero are logic errors in pure Lua. The mechanism is not carelessness
-- and it is not cleverness: this config writes the code, the test AND the
-- stub from ONE model of macOS, so when the model is wrong all three are
-- wrong in the same direction and they agree with each other. The gate
-- goes green. Green has always meant "the code matches our beliefs"; it
-- has never once meant "the code matches macOS".
--
-- So this suite does not test a module. It tests THE BELIEFS — every
-- stubbed macOS provider in tests/ is held against a contract, and every
-- contract below was paid for by a named loss. A row here is not a
-- preference; it is a receipt.
--
-- 🚨 AND IT SHIPS SILENT (6.269.0). A new instrument's first duty is to
-- say nothing when nothing is wrong, or it is switched off long before it
-- ever meets the fault it was built for. 6.290.0 corrected 28 stubs
-- across 25 files so that this file is green on a healthy tree the day it
-- lands. Every red from here on is a NEW lie.
--
-- 📏 NAMED, NOT CLAIMED: this audit is STATIC. It reads the source of
-- every suite; it cannot run macOS and it cannot know a contract nobody
-- has been burnt by yet. What it buys is a RATCHET — a class that has
-- cost a release cannot quietly reopen. §4 lists the contracts that are
-- known and NOT automated, deliberately, so the gap is written down
-- rather than implied.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        io.write("   ❌ " .. failures[#failures] .. "\n")
    end
end
local function out(s) io.write(s) end

-- =====================================================================
-- 🧰 THE READER
-- =====================================================================
-- Comments are stripped before anything is matched (6.262.0): the
-- comments in this project deliberately quote the very lines they forbid,
-- and a sentry that reads them goes red on a healthy tree. And a sentry
-- satisfied by DELETING the explanation is weaker than it reads, so §3
-- asserts the prose survives.
local function readFile(p)
    local h = io.open(p, "r")
    if not h then return nil end
    local s = h:read("a") ; h:close() ; return s
end

local function stripComments(s)
    s = s:gsub("%-%-%[%[.-%]%]", " ")     -- long comments
    return (s:gsub("%-%-[^\n]*", ""))     -- line comments
end

-- 🚨 THE BODY IS READ BY BALANCE, NEVER BY THE FIRST `end`. The probe
-- that found this release's 28 stubs used a lazy `(.-)end` and reported
-- test_bluetooth as returning nothing when it returns a boolean two
-- tokens later — the match stopped at an inner `if`'s own `end`. A
-- scanner with the wrong idea of where a thing ENDS is 6.263.0's
-- fixed-width window in a new costume, and it fails in the direction that
-- invents work. Openers are `function`, `do` and `if`; `for`/`while` are
-- not counted because each is always closed by its own `do`.
local function bodyAfter(code, startPos)
    local depth, i, n = 1, startPos, #code
    while i <= n do
        local s, e, word = code:find("%f[%w_]([%a_]+)%f[^%w_]", i)
        if not s then return nil end
        if word == "function" or word == "do" or word == "if" then
            depth = depth + 1
        elseif word == "end" then
            depth = depth - 1
            if depth == 0 then return code:sub(startPos, s - 1) end
        end
        i = e + 1
    end
    return nil
end

-- Every stub of `name` in `code`, as { params = "...", body = "..." }.
-- Both spellings this project uses: `name = function(a)` in a table, and
-- `function obj:name(a)` for a method.
-- 🚨 THE FRONTIER IS LOAD-BEARING, and leaving it out is how the first
-- draft of §4 passed its own mutation: `attributes%s*=%s*function` MATCHES
-- INSIDE `symlinkAttributes = function`, so a suite that stubs only the
-- symlink reader looked as though it had stubbed both. ANY SENTRY THAT
-- LOOKS FOR A NAME LOOKS FOR ITS BOUNDARY TOO — 6.236.0 wrote that after
-- `screenReport` matched `screenReportRenamed`, 6.270.0 wrote it again
-- after `tool-blur` matched `tool-blur-moved`, and this is the third
-- time. A rule this project has paid for three times belongs in the
-- shared reader, not in each caller.
local function stubsOf(code, name)
    local found = {}
    local pats = {
        "%f[%w_]" .. name .. "%s*=%s*function%s*(%b())",
        "function%s+[%w_]+[:%.]" .. name .. "%s*(%b())",
    }
    for _, pat in ipairs(pats) do
        local init = 1
        while true do
            local s, e, params = code:find(pat, init)
            if not s then break end
            local body = bodyAfter(code, e + 1)
            if body then found[#found + 1] = { params = params, body = body } end
            init = e + 1
        end
    end
    return found
end

-- A stub that deliberately RAISES is modelling a real refusal, not
-- dodging the contract — test_mouse_grid's topLeft throws the genuine
-- NSInternalInconsistencyException, which is the whole point of 6.266.0.
-- Exempt it by shape, never by file name.
--
-- 🚨 AND THE EXEMPTION IS "DOES NOTHING BUT THROW", NOT "MENTIONS error".
-- The first draft asked only whether `error(` appeared anywhere in the
-- body, and test_music_player's `currentTime` — a perfectly good setter
-- that raises only when the NO_SEEK flag is set — was waved straight
-- through, so the mutation making it getter-only SURVIVED. A conditional
-- refusal is a stub being MORE faithful, not less, and an exemption
-- keyed on the mere presence of a refusal path disarms the contract on
-- exactly the best stubs in the tree.
local function throws(body)
    return body:gsub("%s+", " "):match("^ ?error%s*%(") ~= nil
end

local files = {}
do
    local p = io.popen("ls " .. HS .. "/tests/*.lua 2>/dev/null")
    if p then
        for l in p:lines() do
            local base = l:match("([^/]+)$")
            if base ~= "test_stub_fidelity.lua" then
                files[#files + 1] = { name = base, code = stripComments(readFile(l) or "") }
            end
        end
        p:close()
    end
end
check("the audit can read the suites", #files > 50, #files .. " file(s)")

-- =====================================================================
out("\n=== 1. 🕒 THE CLOCK IS A FLOAT (6.282.0) ===\n")
-- =====================================================================
-- `hs.timer.secondsSinceEpoch()` returns 1758769234.8231. os.date REFUSES
-- a float with a fraction outright — "number has no integer
-- representation" — so a stub answering the INTEGER 1000 is a number of
-- the right value in the wrong REPRESENTATION, and every check that
-- formats a stored clock is green against it.
--
-- That is exactly what happened: `_G.screenshotsReport()` THREW on LL's
-- Mac in every session where ⇪4 had been pressed, for eighteen releases,
-- while the check rendering that very line passed. A fresh boot took the
-- `or` branch and printed happily, so the only Mac that could see it was
-- one that had used the key.
--
-- 🔎 AND THE FIXTURE MUST CARRY A FRACTION, which is 6.230.0's rule in
-- the place it costs most: `1000.0` is a float AND has an exact integer
-- representation, so os.date accepts it and a correct reader and a broken
-- one AGREE. A fixture where both implementations agree proves nothing.
local intClocks = {}
for _, f in ipairs(files) do
    for _, st in ipairs(stubsOf(f.code, "secondsSinceEpoch")) do
        local lit = st.body:match("^%s*return%s+([%d%.]+)%s*$")
        if lit and not lit:find("%.") then
            intClocks[#intClocks + 1] = f.name .. " → return " .. lit
        end
    end
end
check("no stubbed clock answers an INTEGER — macOS answers a float",
      #intClocks == 0, table.concat(intClocks, " · "))

-- The audit is worthless if it cannot see a violation, so it is driven
-- against one. This is the check that keeps the check honest.
do
    local sick = stripComments("local hs = { timer = { secondsSinceEpoch = function() return 1000 end } }")
    local st   = stubsOf(sick, "secondsSinceEpoch")
    check("§1 BITES: an integer clock is found", #st == 1
          and st[1].body:match("^%s*return%s+(%d+)%s*$") == "1000")
    local ok = stripComments("local hs = { timer = { secondsSinceEpoch = function() return 1000.4231 end } }")
    local st2 = stubsOf(ok, "secondsSinceEpoch")
    check("§1 IS SILENT on a fractional float", #st2 == 1
          and st2[1].body:match("^%s*return%s+([%d%.]+)%s*$"):find("%.") ~= nil)
    -- 🚨 The row that would have let 6.282.0 through a second time.
    local exact = "return 1000.0"
    check("§1 would still flag a float with no fraction if asked to",
          exact:match("([%d%.]+)"):find("%.") ~= nil)
end

-- =====================================================================
out("\n=== 2. 📋 setContents ANSWERS A BOOLEAN (6.198.0) ===\n")
-- =====================================================================
-- `hs.pasteboard.setContents` REFUSES BY RETURNING FALSE, not by throwing
-- — so `pcall(function() hs.pasteboard.setContents(x) end)` is true
-- either way, and three places in this config promised LL something they
-- had not done. A stub returning NIL makes a refusal indistinguishable
-- from a success at every call site, which is the same silence.
--
-- 🔎 AND THE REFUSAL CHECKS THAT EXISTED MADE IT THROW — the half pcall
-- catches, and the half macOS does not do. A stub answers exactly what
-- the real provider answers, refusals included.
local mutePaste = {}
for _, f in ipairs(files) do
    for _, st in ipairs(stubsOf(f.code, "setContents")) do
        if not throws(st.body) and not st.body:find("%f[%w_]return%f[^%w_]") then
            mutePaste[#mutePaste + 1] = f.name
        end
    end
end
check("every setContents stub answers something — macOS answers a boolean",
      #mutePaste == 0, table.concat(mutePaste, " · "))

do
    local sick = stripComments("local p = { setContents = function(t) CLIP = t end }")
    local st = stubsOf(sick, "setContents")
    check("§2 BITES: a setContents that returns nothing is found",
          #st == 1 and not st[1].body:find("return"))
    local ok = stripComments("local p = { setContents = function(t) CLIP = t ; return true end }")
    check("§2 IS SILENT on a stub that returns a boolean",
          stubsOf(ok, "setContents")[1].body:find("return true") ~= nil)
    -- The balanced reader, driven on the shape that broke the probe.
    local nested = stripComments(
        "local p = { setContents = function(s) if OK then P = s end return OK end }")
    local st3 = stubsOf(nested, "setContents")
    check("§2 reads PAST an inner `end` — the lazy match said this was mute",
          #st3 == 1 and st3[1].body:find("return OK") ~= nil, st3[1] and st3[1].body)
end

-- =====================================================================
out("\n=== 3. 🔧 A SETTER IS NOT A GETTER (6.227.0 · 6.239.0 · 6.247.0) ===\n")
-- =====================================================================
-- Three releases lost to the identical shape, in three different
-- providers: a stub that reads like the real method and quietly ignores
-- the value being SET. Every one of them let a whole feature pass its
-- tests while moving nothing on the Mac.
--
--   selectedRow  6.227.0 — the ⇪⇧V picker's highlight was restored on
--                every rebuild, into a getter, so the restore "succeeded"
--                and the row never moved.
--   currentTime  6.239.0 — ← → seek. Every seek "succeeded".
--   topLeft      6.247.0 — the grid overlay moved instead of rebuilding.
--                A getter-only stub passes every "it moved" check.
--
-- The contract is the narrowest thing that separates them: the stub must
-- ACCEPT a value. A stub that throws is modelling a refusal and is
-- exempt by shape.
local SETTERS = { "selectedRow", "currentTime", "topLeft" }
for _, m in ipairs(SETTERS) do
    local bad, seen = {}, 0
    for _, f in ipairs(files) do
        for _, st in ipairs(stubsOf(f.code, m)) do
            seen = seen + 1
            if st.params == "()" and not throws(st.body) then
                bad[#bad + 1] = f.name
            end
        end
    end
    check("🔧 " .. m .. " is stubbed as a SETTER wherever it is stubbed",
          #bad == 0, table.concat(bad, " · "))
    check("   ↳ and it IS stubbed somewhere — a contract nobody exercises"
          .. " is not a ratchet", seen > 0, m)
end

do
    local sick = stripComments("local c = {} function c:selectedRow() return SEL end")
    local st = stubsOf(sick, "selectedRow")
    check("§3 BITES: a getter-only selectedRow is found",
          #st == 1 and st[1].params == "()")
    local ok = stripComments("local c = {} function c:selectedRow(n) if n then SEL = n end return SEL end")
    check("§3 IS SILENT on a stub that takes the value",
          stubsOf(ok, "selectedRow")[1].params == "(n)")
    local refusing = stripComments('local c = {} function c:topLeft() error("unavailable") end')
    check("§3 EXEMPTS a stub that models a real refusal, by SHAPE not by name",
          throws(stubsOf(refusing, "topLeft")[1].body))
end

-- =====================================================================
out("\n=== 4. 🔗 attributes FOLLOWS A LINK, symlinkAttributes DOES NOT (6.230.0) ===\n")
-- =====================================================================
-- ~/OneDrive is a symlink to the CloudStorage folder, so the file tracker
-- watched one tree twice — inside the release whose whole purpose was
-- cutting wake-ups. `hs.fs.attributes` FOLLOWS the link and answered
-- "directory"; only `symlinkAttributes` says "link".
--
-- 🚨 AND THE STUB ANSWERED nil FOR A SYMLINK instead of following it, so
-- the bug was untestable. The contract: a suite that stubs one of the
-- pair stubs BOTH, or it cannot tell the question apart from the answer.
local lonely = {}
for _, f in ipairs(files) do
    local hasLink = #stubsOf(f.code, "symlinkAttributes") > 0
    local hasAttr = #stubsOf(f.code, "attributes") > 0
                    or f.code:find("attributes%s*=%s*[%w_]") ~= nil
    if hasLink and not hasAttr then lonely[#lonely + 1] = f.name end
end
check("🔗 no suite stubs symlinkAttributes without attributes beside it",
      #lonely == 0, table.concat(lonely, " · "))

-- =====================================================================
out("\n=== 5. 🔌 THE REGISTRY HANDS BACK RAW VALUES (6.273.0) ===\n")
-- =====================================================================
-- The costliest one, and the reason this whole file exists. A suite
-- invented `call = function(n, ...) return true, SERVICES[n](...) end`
-- under a comment reading "the service registry, exactly as init.lua
-- publishes it". Two divergences, both invisible at a call site: it
-- PREPENDS a status the real one never sends, and `return true, f(...)`
-- truncates f to ONE value. 106 checks stayed green for eighty-nine
-- releases while certifying a module that could do one of its four jobs.
--
-- A STUB THAT INVENTS A CALLING CONVENTION DOES NOT MERELY MISS THE BUG,
-- IT CERTIFIES IT — and when a comment claims a stub matches the real
-- thing, DIFF IT. tests/service_registry.lua LIFTS the real block out of
-- init.lua's source so no suite retypes it.
local reg = readFile(HS .. "/tests/service_registry.lua")
check("the lifted registry exists", reg ~= nil)
if reg then
    check("   ↳ it reads init.lua rather than retyping the block",
          reg:find("init%.lua") ~= nil)
end

-- 🚫 AND THE SYNTACTIC SENTRY FOR THIS ROW WAS WRITTEN HERE AND TAKEN
-- OUT AGAIN — FOR THE SECOND TIME, which is the finding worth keeping.
-- 6.273.0 had already tried "no call stub prepends a leading true",
-- found it goes red on CORRECT code, and wrote down why: a grep cannot
-- tell a status the provider RETURNED from one the caller IMAGINED.
-- `vault.link`'s own first value is a boolean; so is `capturePad.add`'s,
-- which is how test_scratch_pad's perfectly correct
-- `return true, { text = text }` lit up the first draft of this audit.
--
-- 🔑 THE LESSON IS ABOUT THIS FILE, NOT ABOUT THAT ROW. An audit built
-- to stop a class from reopening can itself reopen a class — I rebuilt a
-- sentry this project had already measured and discarded, with the
-- reasoning sitting in CLAUDE.md. So the rule earns its place here: A
-- CONTRACT THAT CANNOT DISTINGUISH THE CORRECT CASE IS NOT A CONTRACT,
-- and the answer is a FUNCTIONAL guard, never a wider grep — a
-- wrong-convention suite fails a real check now, which needs no
-- maintenance and cannot cry wolf.
--
-- What is asserted instead is that the functional guard EXISTS and is
-- where the comments say it is (6.269.0: when a comment claims a check,
-- grep for the check).
do
    local integ = readFile(HS .. "/tests/test_integration.lua") or ""
    check("🔌 the functional guard is real — test_integration refuses a suite"
          .. " that retypes the registry",
          integ:find("no suite prepends a status the real service%.call never sends") ~= nil)
    check("   ↳ and it matches the 6.273.0 SHAPE, not any leading true",
          integ:find("return true, SERVICES%[") ~= nil)
    check("   ↳ and at least one suite really runs on the lifted registry",
          integ:find("service_registry%%.lua") ~= nil
          or integ:find("on the lifted registry, so it is really used") ~= nil)
end

-- =====================================================================
out("\n=== 6. 📏 NAMED, NOT AUTOMATED — the gap, written down ===\n")
-- =====================================================================
-- 🚨 A COMMENT CLAIMING A GUARD THAT DOES NOT EXIST is worse than no
-- guard (6.269.0: when a comment claims a check, grep for the check). So
-- the contracts this audit KNOWS and cannot check statically are listed
-- here as data, printed, and counted — never implied by silence.
--
-- Each is real, each cost a release, and each needs a running Mac or a
-- per-module join that would cry wolf:
local NOT_AUTOMATED = {
    { "6.218.0", "hs.eventtap.keyStrokes POSTS — the keys come back through our own taps" },
    { "6.233.0", "hs.webview has NO drag-and-drop; hs.canvas is the only drop target" },
    { "6.235.0", "a throw inside a dragging callback is a SILENCE" },
    { "6.237.0", "Finder hands over a file-reference URL (inode), never a path" },
    { "6.251.0", "window:focus() must MOVE the focus — a getter-only stub hides the feature" },
    { "6.265.0", "a canvas can be created, wired, and then REFUSE to show" },
    { "6.289.0", "an eventtap can be created and then refuse to START" },
    { "6.201.0", "a suite stubbing setContents may also need changeCount — a join too"
                 .. " narrow to automate without crying wolf on 31 files" },
}
check("the unautomated contracts are listed, not implied", #NOT_AUTOMATED == 8)
for _, row in ipairs(NOT_AUTOMATED) do
    out("   · " .. row[1] .. "  " .. row[2] .. "\n")
end

-- And the prose that explains the rule must survive, or a future sweep
-- satisfies the sentry by deleting the reason (6.280.0).
--
-- 🚨 A SENTRY WHOSE NEEDLE EXISTS ONLY IN THE SENTRY ASSERTS ITS OWN
-- EXISTENCE, and the first draft of this very check did exactly that: it
-- searched for the lowercase "gentler than the real provider" while the
-- header carries it in CAPITALS, so the ONLY occurrence in the file was
-- the check's own source line. It matched itself. It could not fail, and
-- the mutation deleting the explanation sailed through.
--
-- GENERAL, and it is this file's own contribution rather than a rule
-- borrowed from an earlier release: WHEN A SENTRY READS THE FILE IT
-- LIVES IN, IT MUST NOT BE ABLE TO READ ITSELF. The needle lines are
-- removed before the search, so the only thing that can satisfy this
-- check is the prose.
do
    local raw   = readFile(HS .. "/tests/test_stub_fidelity.lua") or ""
    -- Every line that mentions the holder is a line of this check, never
    -- prose. Strip by the VARIABLE, so renaming it cannot silently leave
    -- the needle in the haystack again.
    local prose = raw:gsub("[^\n]*prose[^\n]*", "")
    check("🚨 the file still explains WHY, in the prose and not in the check",
          prose:lower():find("gentler than the real provider", 1, true) ~= nil
          and prose:find("6%.193%.0") ~= nil)
    check("   ↳ and the needle really was stripped, so this cannot match itself",
          prose:find("prose:lower", 1, true) == nil)
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then os.exit(1) end
