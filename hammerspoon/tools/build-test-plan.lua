#!/usr/bin/env lua
-- =====================================================================
-- BUILD-TEST-PLAN — the steps LL runs to score a release, as a file he
-- actually receives
-- =====================================================================
--     lua tools/build-test-plan.lua .          ← writes TESTING.md
--     lua tools/build-test-plan.lua . --check  ← verifies it is current
--
-- 6.271.0 — LL: "if we want to score each release, I need a set of
-- directions that explicitly state the steps that you want me to take to
-- test each release … I'm running through the cheat sheet checking
-- features, but that is a basic level of tests … could you provide a set
-- of testing steps? That way I can return to you with robust data for you
-- to analyze rather than me just saying that worked or that didn't work."
--
-- 🚨 THE FINDING BEHIND THIS RELEASE, and it is not that the steps needed
-- writing: THEY WERE ALREADY WRITTEN. CLAUDE.md carried SEVENTY-TWO
-- "verify with LL" blocks over 1,451 lines — one per release for months —
-- and CLAUDE.md is not in the package. The archive he opens has six files
-- at its root and none of them is a test plan. So every step I have ever
-- asked him to run has been filed where only I can read it, while he was
-- left to invent his own testing by walking the cheat sheet. He was
-- scoring blind because the instructions never shipped.
--
-- 🔑 GENERATED, NEVER HAND-WRITTEN, for the same reason the feature list
-- is: a test plan kept in step by hand is one that stops matching the
-- release it describes, and then it is worse than nothing — he would run
-- the wrong steps and report a pass on a feature that was not built.
-- CLAUDE.md stays the single source; this lifts the blocks out of it.
--
-- 📏 IT SHIPS THE MOST RECENT `KEEP` RELEASES ONLY. He installs one
-- archive that carries several releases, so the plan carries exactly the
-- ones that archive is new for — older blocks stay in CLAUDE.md, which is
-- in git.
-- =====================================================================
local HS    = arg and arg[1] or "."
local CHECK = arg and arg[2] == "--check"
local OUT   = HS .. "/TESTING.md"
local KEEP  = 4

local function readAll(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local init    = readAll(HS .. "/init.lua") or ""
local version = init:match("ARCHITECTURE VERSION CONTROL: ([%d%.]+)") or "?"

-- CLAUDE.md lives at the REPO root, one level above the config. It is
-- deliberately not in the package; only these blocks are.
local memory = readAll(HS .. "/../CLAUDE.md") or readAll("CLAUDE.md") or ""
if memory == "" then
    io.stderr:write("build-test-plan: cannot read CLAUDE.md — no test plan written\n")
    os.exit(1)
end

-- Each block runs from its "- 6.X.Y verify with LL" header to the next
-- top-level "- " bullet at column 0. Versions are sorted numerically,
-- newest first: "6.9.0" must not sort above "6.270.0".
local blocks, order = {}, {}
local pos = 1
while true do
    local s, e, hdr = memory:find("\n(%- 6[%d%.]+ verify with LL)", pos)
    if not s then break end
    local vnum = hdr:match("^%- (6[%d%.]+) verify") or ""
    local nxt = memory:find("\n%- [^ ]", e) or #memory
    local body = memory:sub(s + 1, nxt)
    if vnum ~= "" and not blocks[vnum] then
        blocks[vnum] = body
        order[#order + 1] = vnum
    end
    pos = e
end

local function key(v)
    local a, b, c = v:match("^(%d+)%.(%d+)%.(%d+)$")
    return (tonumber(a) or 0) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
end
table.sort(order, function(x, y) return key(x) > key(y) end)

local L = {}
local function out(s) L[#L + 1] = s end

out("# TESTING — how to score release " .. version)
out("")
out("You install ONE archive and it carries several releases. Below are the")
out("steps for each release this archive is new for, newest first. Run the")
out("newest one first: if it passes, the ones under it were carried along")
out("and are worth a quick pass rather than a full one.")
out("")
out("## How to report back, so the answer is data rather than a verdict")
out("")
out("For every numbered step, send me one of these three:")
out("")
out("  * **PASS** — it did what the step says it should.")
out("  * **FAIL** — plus what happened INSTEAD, in your words. A screenshot")
out("    of the wrong thing is worth more than a sentence about it; three")
out("    releases this year were diagnosed by a photograph and nothing else.")
out("  * **BLOCKED** — you could not run the step at all. That is a")
out("    different fact from a failure and it changes what I look at.")
out("")
out("Then paste the Console lines the steps ask for **whether or not")
out("anything failed**. A report from a working Mac is what tells me what")
out("a broken one is missing — without it I am comparing a failure against")
out("nothing.")
out("")
out("A release is a WIN when every step in its section passes. Anything")
out("else is a LOSS and I fix it before building further. You are the only")
out("scorer; I never mark my own.")
out("")
out("---")
out("")

local shown = 0
for _, v in ipairs(order) do
    if shown >= KEEP then break end
    shown = shown + 1
    out("## " .. v)
    out("")
    -- The block is a CLAUDE.md bullet: strip the leading "- " and the
    -- two-space continuation indent so it reads as prose in a document
    -- rather than as a list item inside someone else's notes.
    for line in (blocks[v] .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("^%- ", ""):gsub("^  ", "")
        out(line)
    end
    out("")
end

if shown == 0 then
    out("_No verify steps were found for this release. That is a fault in the")
    out("release, not in your testing — tell me and I will write them._")
end

out("---")
out("")
out("_Generated from the release notes — never hand-edited, so it cannot")
out("describe steps for a release that was not built._")

local text = table.concat(L, "\n") .. "\n"

if CHECK then
    local have = readAll(OUT)
    if have ~= text then
        io.stderr:write("❌ TESTING.md is out of date — run tools/build-test-plan.lua\n")
        os.exit(1)
    end
    print("✅ TESTING.md is current — " .. shown .. " release(s), version " .. version)
    os.exit(0)
end

local f = assert(io.open(OUT, "w")); f:write(text); f:close()
print("✍️  wrote " .. OUT .. " — " .. shown .. " release(s), version " .. version)
