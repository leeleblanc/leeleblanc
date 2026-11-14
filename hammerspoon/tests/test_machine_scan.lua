-- =====================================================================
-- test_machine_scan.lua — what IS this Mac?
-- =====================================================================
--     lua5.4 test_machine_scan.lua [/path/to/hammerspoon]
--
-- LL, 2026-11-14, with the work MacBook's name at last: "be sure to give
-- me a comprehensive Hammerspoon console report so that when I install
-- this on any work Macbook, I can give you a rich, detailed output."
--
-- 🚨 THE SECTIONS WITH TEETH:
--   §1  THE PROFILE RULE IS LIFTED OUT OF init.lua (6.273.0), not
--       retyped. The whole point of this release is a key that did not
--       match a machine, and a copy of the matcher in a test file is a
--       second thing to get wrong.
--   §2  AN AMBIGUOUS MATCH REFUSES. `pairs` has no order, so two keys
--       that normalise alike would give this Mac a different profile on
--       different boots. The fixture that BITES is two such keys —
--       with one, every implementation agrees (6.230.0).
--   §3  A STAT THAT RAISES IS "COULD NOT ASK", NEVER "NOT THERE"
--       (6.196.1). Those are opposite facts and only one of them is a
--       missing binary somebody can install.
--   §5  A SECTION THAT RAISES MUST NOT TAKE THE SCAN DOWN (6.282.0) —
--       this is the block that gets run on the Mac where something is
--       already wrong.
--   §6  AND THE CLOUD FOLDER MUST SHOUT. No cloud folder means Hamsidian
--       is honestly reporting "no notes yet" about a LOCAL folder it
--       created itself (6.317.0), which on a work Mac is the likeliest
--       single failure there is.
-- =====================================================================

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end

local realPrint = print
local PRINTED = {}
print = function(s) PRINTED[#PRINTED + 1] = tostring(s) end

local function slurp(p)
    local f = io.open(p, "r")
    local s = f and f:read("*a")
    if f then f:close() end
    return s
end

-- =====================================================================
-- §1 THE PROFILE RULE, LIFTED
-- =====================================================================
local initSrc = slurp(HS .. "/init.lua") or ""
local ruleSrc = initSrc:match("(local function profileNorm.-\nend)\n_G%.moduleProfileName")
check("🪪 the profile rule was lifted out of init.lua", ruleSrc ~= nil)

-- Runs the SHIPPED block against a synthetic profile table and hands
-- back _G.profileIdentity. A stand-in that answers falsely rather than
-- raising, so a mutation fails a check instead of killing the run
-- (6.186.0).
local function resolve(tag, raw, profiles)
    if not ruleSrc then return { how = "the rule could not be read" } end
    local fakeG = { moduleProfiles = profiles }
    local env = {
        hostTag = tag, hostRaw = raw, _G = fakeG,
        pairs = pairs, ipairs = ipairs, tostring = tostring, table = table,
    }
    local chunk = load(ruleSrc, "profileRule", "t", env)
    if not chunk then return { how = "the rule would not load" } end
    local ok = pcall(chunk)
    if not ok then return { how = "the rule raised" } end
    return fakeG.profileIdentity or { how = "the rule published nothing" }
end

local AIR  = "Lees-MacBook-Air"
local WORK = "MLC409N-153212"
local BOTH = { [AIR] = {}, [WORK] = {}, default = {} }

do
    local id = resolve(WORK, "MLC409N-153212", BOTH)
    check("an exact name matches, and says it was exact",
          id.how == "exact" and id.key == WORK, id.how .. "/" .. tostring(id.key))
    check("...and it carries the RAW name, not just the tag",
          id.raw == "MLC409N-153212", tostring(id.raw))
end

do
    -- The near-miss this release exists for: hostTag turns spaces into
    -- hyphens, so a Mac called "MLC409N 153212" tags as the key exactly
    -- — but one called "MLC409N.153212" tags as "MLC409N153212" and used
    -- to fall straight to the default with nothing on screen saying so.
    local id = resolve("MLC409N153212", "MLC409N.153212", BOTH)
    check("🪪 a name that differs only by punctuation still matches",
          id.key == WORK, tostring(id.key))
    check("...and it SAYS it needed the fallback, rather than claiming exact",
          id.how == "normalised", tostring(id.how))
end

do
    local id = resolve("SomeOtherMac", "SomeOtherMac", BOTH)
    check("an unknown Mac takes the default", id.key == nil, tostring(id.key))
    check("...and the default is NAMED as the default, not left blank",
          id.how == "default", tostring(id.how))
end

-- =====================================================================
-- §2 AMBIGUITY REFUSES — the fixture that bites
-- =====================================================================
do
    -- TWO keys normalising alike. With one, a first-match implementation
    -- and a refusing one agree and the check proves nothing (6.230.0).
    local two = { ["MLC409N-153212"] = {}, ["MLC409N 153212"] = {}, default = {} }
    local id = resolve("MLC409N153212", "MLC409N.153212", two)
    check("🚨 two keys that normalise alike are REFUSED, not guessed between",
          id.how == "ambiguous" and id.key == nil,
          tostring(id.how) .. "/" .. tostring(id.key))
    check("...and both offenders are NAMED so one can be renamed",
          type(id.ambiguous) == "table" and #id.ambiguous == 2,
          id.ambiguous and #id.ambiguous)
    check("...sorted, so the message does not change between boots",
          id.ambiguous and id.ambiguous[1] < id.ambiguous[2])
end

-- =====================================================================
-- §3 THE BINARY ROWS — first wins, missing names its paths, raising is
--    "could not ask"
-- =====================================================================
local CFG = {}
local FS  = {}          -- path -> attributes table, or nil
local RAISE_ON = nil

hs = {
    fs = { attributes = function(p)
               if RAISE_ON and p == RAISE_ON then error("macOS refused the stat") end
               return FS[p]
           end },
    host = {
        localizedName = function() return "MLC409N-153212" end,
        operatingSystemVersionString = function() return "macOS 27.0 (26A5388g)" end,
    },
    accessibilityState = function() return true end,
}

local core = {
    hostTag = WORK, cloudDir = "/Users/x/OneDrive", logsDir = "/Users/x/OneDrive/Logs",
    backupDir = "/Users/x/OneDrive/Backups", configDir = "/Users/x/.hammerspoon",
    provide = function(n, f) CFG[n] = f end,
}

local modSrc = slurp(HS .. "/modules/machine_scan.lua")
check("the module was read", modSrc ~= nil)
local M = assert(load(modSrc, "machine_scan", "t", _G))()
M.setup(core)

do
    local want = {
        { "both",   { "/a", "/b" } },
        { "second", { "/nope", "/b" } },
        { "none",   { "/x", "/y" } },
    }
    FS["/a"], FS["/b"] = { mode = "file" }, { mode = "file" }
    local rows = M.binaryRows(want, function(p) return hs.fs.attributes(p) ~= nil end)
    check("the FIRST candidate that exists wins", rows[1].path == "/a", rows[1].path)
    check("...and a later one is found when the first is absent",
          rows[2].path == "/b", rows[2].path)
    check("a row with none is MISSING", rows[3].state == "missing", rows[3].state)
    check("🔎 ...and it names every path it looked in — a missing binary whose "
          .. "search path is secret is one nobody can install",
          #rows[3].tried == 2 and rows[3].tried[1] == "/x")
end

do
    -- 6.196.1: "I could not ask" and "it is not there" are opposite
    -- facts, and only the second is actionable.
    RAISE_ON = "/boom"
    local rows = M.binaryRows({ { "raises", { "/boom" } } },
                              function(p) return hs.fs.attributes(p) ~= nil end)
    RAISE_ON = nil
    check("🔎 a stat that RAISES is 'unknown', never 'missing'",
          rows[1].state == "unknown", rows[1].state)
    check("...and macOS's own words ride into the row", rows[1].why ~= nil)
end

-- =====================================================================
-- §4 FOLDER STATES — four, not two
-- =====================================================================
do
    local stat = function(p)
        if p == "/raise" then error("refused") end
        return FS[p]
    end
    FS["/dir"]  = { mode = "directory" }
    FS["/file"] = { mode = "file" }
    local s1 = M.folderState("/dir",  stat)
    local s2 = M.folderState("/gone", stat)
    local s3 = M.folderState("/file", stat)
    local s4 = M.folderState("/raise", stat)
    local s5 = M.folderState(nil, stat)
    check("a real folder is ok",            s1 == "ok",      s1)
    check("an absent one is missing",       s2 == "missing", s2)
    check("🔎 a FILE where a folder should be is its own state, not 'ok'",
          s3 == "notdir", s3)
    check("🔎 a stat that raises is 'unknown', not 'missing'", s4 == "unknown", s4)
    check("🔎 and a path that was never resolved is 'unset'", s5 == "unset", s5)
end

-- =====================================================================
-- §5 THE SCAN RUNS, AND A BROKEN SECTION DOES NOT TAKE IT DOWN
-- =====================================================================
_G.configVersion      = "6.435.0"
_G.hostRawName        = "MLC409N-153212"
_G.moduleProfileName  = WORK
_G.profileIdentity    = { raw = "MLC409N-153212", tag = WORK, how = "exact", key = WORK }
_G.moduleStatus       = { { name = "a", ok = true }, { name = "b", ok = true } }
_G.hyperShortcutCount = 111
_G.secureInput        = { on = false }
_G.service = { has = function() return true end,
               call = function() return { count = 1926, enabled = true } end }

do
    local txt = _G.workmacbookScan(true)
    check("🪪 the scan returns its text when asked", type(txt) == "string" and #txt > 400)
    for _, want in ipairs({ "this Mac", "permissions", "binaries", "folders",
                            "snippets", "modules", "what to run next" }) do
        check("the scan has a " .. want .. " section", txt:find(want, 1, true) ~= nil)
    end
    check("...and it names THIS Mac, raw, not just the tag",
          txt:find("MLC409N-153212", 1, true) ~= nil)
    check("...and the snippet count comes from the expander, not from here",
          txt:find("1926", 1, true) ~= nil)
    check("🔒 and it never prints a count it was not given",
          txt:find("expander did not publish", 1, true) == nil)
end

do
    -- A section whose world is broken must print ❔ and let the rest run
    -- (6.282.0).
    -- 🔎 AND THE FIXTURE HAD TO MOVE TO FIND ONE. The obvious one — make
    -- hs.fs.attributes itself raise — proves nothing, because both the
    -- binaries and the folders sections already pcall every stat, which
    -- is §3 and §4 working. The section wrapper is the belt BEHIND
    -- those, for a raise nobody guarded, so the fixture has to be one: a
    -- `_G.moduleStatus` that is not a list at all, which is what a
    -- half-loaded boot leaves behind. The FIRST section is the one that
    -- dies, so the check below also proves the rest still ran.
    local wasStatus = _G.moduleStatus
    _G.moduleStatus = 5
    local txt = _G.workmacbookScan(true)
    _G.moduleStatus = wasStatus
    check("🚨 a section that raises prints ❔ and does not kill the scan",
          type(txt) == "string" and txt:find("❔ this section could not be read",
                                             1, true) ~= nil)
    check("...and the sections AFTER it still ran",
          txt and txt:find("what to run next", 1, true) ~= nil)
end

-- =====================================================================
-- §6 NO CLOUD FOLDER SHOUTS
-- =====================================================================
do
    local was = core.cloudDir
    core.cloudDir = nil
    local txt = _G.workmacbookScan(true)
    core.cloudDir = was
    check("🚨 a Mac with no cloud folder is SHOUTED at, not noted",
          txt:find("NO CLOUD FOLDER WAS FOUND", 1, true) ~= nil)
    check("...and it says the notes are not lost, only in the wrong place",
          txt:find("Nothing is lost", 1, true) ~= nil)
    local ok = _G.workmacbookScan(true)
    check("...and with the folder back the shout is gone",
          ok:find("NO CLOUD FOLDER", 1, true) == nil)
end

-- =====================================================================
-- §7 IT PRINTS WHEN NOT ASKED FOR TEXT, AND PUBLISHES ITS SERVICE
-- =====================================================================
do
    local n = #PRINTED
    local r = _G.workmacbookScan()
    check("📠 with no argument it PRINTS and returns nothing (6.417.0 — the "
          .. "Console echoes a return, and every report was doubling)",
          r == nil and #PRINTED > n)
    check("the scan is published as a service too", type(CFG["machine.scan"]) == "function")
end

-- =====================================================================
print = realPrint
if fail > 0 then
    print("\nFAILURES:")
    for _, f in ipairs(failures) do print("  ❌ " .. f) end
end
print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
