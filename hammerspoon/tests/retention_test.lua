-- =====================================================================
-- Tracker row cap + changelog.csv — offline test suite
-- =====================================================================
--     cd hammerspoon && lua5.4 tests/retention_test.lua
--
-- The row cap is the dangerous one. It deletes rows from your real
-- history files on every boot, so the direction matters absolutely:
-- keeping the OLDEST 50,000 instead of the newest would quietly throw
-- away everything recent while looking like it worked. That is the
-- check this suite exists for.
-- =====================================================================

local TMP = os.getenv("RT_TMP") or "/tmp/rt_test"
os.execute("rm -rf " .. TMP .. " && mkdir -p " .. TMP)

PRINTS = {}
local realprint = print
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  PRINTS[#PRINTS+1] = table.concat(p, " ")
end

-- ---------- upvalues borrowed from init.lua ----------
logsDir = TMP
WARNED = nil
function warnWriteFailed(l) WARNED = l end
function csvQuote(value)
  local s = tostring(value or "")
  s = s:gsub('[\r\n]+', ' '):gsub('"', '""')
  return '"' .. s .. '"'
end

-- ---------- pull the pieces out of init.lua ----------
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local initPath = os.getenv("RT_INIT") or (here .. "/../init.lua")
local fh = assert(io.open(initPath, "r"), "cannot open " .. initPath)
local full = fh:read("*a"); fh:close()

local capS = full:find("_G%.trackerMaxRows = ")
local capE = full:find("local function pruneActivityLog", capS)
assert(capS and capE, "could not delimit the row-cap block")
assert(load(full:sub(capS, capE - 1), "@cap"))()

local clS = full:find("%-%- %-%-%-%- changelog%.csv")
local clE = full:find("end%)%(%)", clS)
assert(clS and clE, "could not delimit the changelog block")
local changelogBlock = full:sub(clS, clE + 5)

local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1
  else fail = fail + 1
    realprint("  FAIL: " .. name .. (extra and ("  ["..tostring(extra).."]") or "")) end
end

realprint("== the cap keeps the NEWEST rows ==")
check("cap is 50,000", _G.trackerMaxRows == 50000, _G.trackerMaxRows)

local small = {}
for i = 1, 10 do small[i] = i end
local out = _G.trackerCapRows(small, "test")
check("under the cap, list is untouched", #out == 10 and out[1] == 1 and out[10] == 10)
check("under the cap, nothing printed", #PRINTS == 0, PRINTS[1])

-- Rows are appended chronologically, so index 1 is oldest and index N
-- is newest. After capping, the LAST row must survive and the FIRST
-- must not.
local big = {}
for i = 1, 50010 do big[i] = i end
PRINTS = {}
local capped = _G.trackerCapRows(big, "📁 File tracker")
check("trimmed to exactly the cap", #capped == 50000, #capped)
check("NEWEST row survived", capped[#capped] == 50010, capped[#capped])
check("oldest rows were the ones dropped", capped[1] == 11, capped[1])
check("no gap in the middle", capped[2] == 12 and capped[500] == 510)
check("it says what it did", (function()
  for _, p in ipairs(PRINTS) do
    if p:find("capped", 1, true) and p:find("newest", 1, true) then return true end
  end
  return false
end)(), PRINTS[1])

local exact = {}
for i = 1, 50000 do exact[i] = i end
PRINTS = {}
local same = _G.trackerCapRows(exact, "test")
check("exactly at the cap is not trimmed", #same == 50000, #same)
check("exactly at the cap is silent", #PRINTS == 0)

check("empty list survives", #_G.trackerCapRows({}, "test") == 0)

realprint("== changelog.csv ==")
local path = TMP .. "/changelog.csv"
local function boot(version, note)
  _G.configVersion = version
  _G.changelogNote = note or "note for " .. version
  PRINTS = {}
  assert(load(changelogBlock, "@changelog"))()
end
local function readAll()
  local f = io.open(path, "r"); if not f then return nil end
  local c = f:read("*a"); f:close(); return c
end

boot("6.31.4")
local c = readAll()
check("file created", c ~= nil)
check("header written once", select(2, c:gsub("Date,Version,Change notes", "")) == 1, c)
check("version row present", c:find("6.31.4", 1, true) ~= nil, c)
check("note is CSV-quoted", c:find('"note for 6.31.4"', 1, true) ~= nil, c)
check("boot said so", (function()
  for _, p in ipairs(PRINTS) do if p:find("changelog.csv", 1, true) then return true end end
  return false
end)())

boot("6.31.4")
local c2 = readAll()
check("second boot does not duplicate", c2 == c, c2)
check("second boot stays quiet", #PRINTS == 0, PRINTS[1])

boot("6.32.0")
local c3 = readAll()
check("a new version appends", c3:find("6.32.0", 1, true) ~= nil)
check("still exactly one header", select(2, c3:gsub("Date,Version,Change notes", "")) == 1)
check("the old row is still there", c3:find("6.31.4", 1, true) ~= nil)

realprint("== a note containing a comma cannot break the columns ==")
os.execute("rm -f " .. path)
boot("7.0.0", "Row cap, changelog CSV, and EmmyLua")
local c4 = readAll()
check("comma-bearing note is quoted", c4:find('"Row cap, changelog CSV, and EmmyLua"', 1, true) ~= nil, c4)
boot("7.0.1")
check("and the next boot still parses the version back out",
  readAll():find("7.0.1", 1, true) ~= nil)
boot("7.0.1")
-- Count the VERSION FIELD, not raw occurrences: the note text also
-- contains the version string, so a naive count sees two per row.
local function rowsFor(version)
  local n = 0
  for line in readAll():gmatch("[^\n]+") do
    if line:match("^[^,]*,([^,]*),") == version then n = n + 1 end
  end
  return n
end
check("...and does not duplicate it", rowsFor("7.0.1") == 1, rowsFor("7.0.1"))
check("the earlier version still has exactly one row", rowsFor("7.0.0") == 1, rowsFor("7.0.0"))

realprint("== an unwritable path warns instead of dying ==")
logsDir = "/nonexistent-dir-" .. tostring(os.time())
WARNED = nil
boot("9.9.9")
check("warnWriteFailed called", WARNED ~= nil, WARNED)
check("did not throw", true)

realprint("")
realprint(string.format("PASS %d   FAIL %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
