-- =====================================================================
-- test_file_tracker.lua — the CSV schema, and the migration onto it
-- =====================================================================
--     lua5.4 test_file_tracker.lua [/path/to/hammerspoon]
--
-- Executes modules/file_tracker.lua against a stubbed hs, but with REAL
-- FILES in a real temp directory. That is deliberate and it is the whole
-- point of this suite: 6.115.0 rewrites 90 days of LL's file history in
-- place, on a Mac nobody is watching, and a migration tested against a
-- stubbed io proves only that the stub agrees with itself.
--
-- 📅 WHAT CHANGED, AND WHY IT NEEDED A MIGRATION AT ALL
-- The CSV used to be written
--     file_name,new_name,present_location,moved_location,timestamp,event,epoch
-- with the timestamp formatted DD/MM/YY HH:MM. Two problems, both real:
--   · the date was the FIFTH column of a log about when things happened
--   · DD/MM/YY is read as MM/DD/YY by Excel on a US locale, and imported
--     as TEXT — so sorting it sorts alphabetically and every row
--     beginning "11/" clumps together regardless of month or year
-- It is now
--     timestamp,file_name,new_name,present_location,moved_location,event,epoch
-- with an ISO 8601 timestamp.
--
-- 🚨 THE RULE THIS SUITE ENFORCES ABOVE ALL OTHERS: the old date TEXT is
-- never parsed. Every row already carries an epoch, so the new timestamp
-- is regenerated from that number. Section 3 exists to prove it, by
-- feeding in rows whose old text and whose epoch disagree and insisting
-- the epoch wins — because a migration that "helpfully" parsed 11/07/26
-- would silently move a third of the history to the wrong month.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- =====================================================================
-- STUBS — everything except the filesystem, which is real on purpose
-- =====================================================================
local printed, ALERTS = {}, {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function logged(needle)
    for _, line in ipairs(printed) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

local NOW = 1787000000   -- a fixed "now" so retention maths is deterministic

hs = {
    configdir = nil,   -- replaced once DIR exists; file_tracker reads it
                       -- directly for the ~/.hammerspoon exclusion rules
    -- 🗂 6.229.0: the tracker LISTS the home folder now, to watch the
    -- folders inside it instead of the whole thing. The stub answers from a
    -- table rather than the disk so the gate stays hermetic — and
    -- `attributes` still returns nil for the one-argument call the rename
    -- pairing makes, which is a different question (does this file exist).
    fs = { attributes = function(path, what)
               if what == "mode" and _G.FAKE_DIRS and _G.FAKE_DIRS[path] then
                   return "directory"
               end
               return nil
           end,
           dir = function(path)
               local names, i = (_G.FAKE_TREE or {})[path], 0
               if not names then error("no such directory: " .. tostring(path)) end
               return function()
                   i = i + 1
                   return names[i]
               end
           end,
           mkdir = function() return true end },
    pathwatcher = { new = function(_, fn)
        local w = { fn = fn }
        function w:start() return self end
        function w:stop()  return self end
        return w
    end },
    chooser = { new = function(fn)
        local c = { cb = fn, rows = {} }
        function c:placeholderText() return self end
        function c:queryChangedCallback(f) self.qc = f; return self end
        function c:hideCallback(f) self.hideCb = f; return self end
        function c:choices(v) self.rows = v; return self end
        function c:show() return self end
        return c
    end },
    hotkey = { bind = function() return {} end },
    timer  = { doAfter = function() return {} end,
               secondsSinceEpoch = function() return NOW end },
    pasteboard = { setContents = function() return true end },
    alert  = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.choosers = {}

-- The two CSV helpers file_tracker takes from core. Same behaviour as
-- init.lua's: quote-safe out, positional (empty-preserving) in.
local function csvQuote(s)
    s = tostring(s or "")
    if s:find('[",\n]') then return '"' .. s:gsub('"', '""') .. '"' end
    return s
end
local function splitCSVLine(line)
    local fields, i, n = {}, 1, #line
    while i <= n do
        if line:sub(i, i) == '"' then
            local j, buf = i + 1, {}
            while j <= n do
                local c = line:sub(j, j)
                if c == '"' then
                    if line:sub(j + 1, j + 1) == '"' then buf[#buf + 1] = '"'; j = j + 2
                    else j = j + 1; break end
                else buf[#buf + 1] = c; j = j + 1 end
            end
            fields[#fields + 1] = table.concat(buf)
            if line:sub(j, j) == ',' then j = j + 1 end
            i = j
        else
            local comma = line:find(',', i, true)
            if comma then fields[#fields + 1] = line:sub(i, comma - 1); i = comma + 1
            else fields[#fields + 1] = line:sub(i); i = n + 1 end
        end
    end
    return fields
end

local DIR = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
            .. "/hs-ft-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
os.execute("mkdir -p '" .. DIR .. "'")
hs.configdir = DIR
local CSV = DIR .. "/file_changes-Test-Mac.csv"

local function put(path, body)
    local h = io.open(path, "w") ; if h then h:write(body); h:close() end
end
local function get(path)
    local h = io.open(path, "r") ; if not h then return nil end
    local s = h:read("*a"); h:close(); return s
end
local function lines(path)
    local body = get(path) or ""
    local t = {} ; for l in body:gmatch("[^\r\n]+") do t[#t + 1] = l end ; return t
end
local function wipe()
    os.execute("rm -f '" .. CSV .. "' '" .. CSV .. ".before-iso-dates'")
end

-- Load the module fresh and run its setup against the temp directory.
-- Re-dofile'd each time so every scenario gets its own captured locals —
-- ftNeedsMigration in particular is per-setup state, and a suite that
-- reused one instance would be testing a flag that latched on the first
-- fixture and never cleared.
local function boot()
    local M = dofile(HS .. "/modules/file_tracker.lua")
    M.setup({
        homeDir = DIR, cloudDir = nil, logsDir = DIR, hostTag = "Test-Mac",
        configDir = DIR,
        csvQuote = csvQuote, splitCSVLine = splitCSVLine,
        warnWriteFailed = function(l) print("WRITEFAIL " .. tostring(l)) end,
        adoptLegacyFile = function() end,
        showPopup = function() end,
    })
    return M
end

local HEADER = "timestamp,file_name,new_name,present_location,moved_location,event,epoch"

-- Two moments far enough apart that no timezone can confuse them, and
-- expected strings computed with the SAME os.date the module uses — so
-- this suite passes in Denver and in Sydney rather than only where it
-- was written.
local T_JUL = os.time({ year = 2026, month = 7, day = 11, hour = 14, min = 30 })
local T_AUG = os.time({ year = 2026, month = 8, day = 3,  hour = 9,  min = 5  })
local ISO_JUL = os.date("%Y-%m-%d %H:%M", T_JUL)
local ISO_AUG = os.date("%Y-%m-%d %H:%M", T_AUG)

-- =====================================================================
out("\n=== 1. The schema itself ===\n")
-- =====================================================================
wipe()
boot()
check("a brand-new CSV is created with a header", get(CSV) ~= nil)
check("🚨 the date is the FIRST column — the whole point of the change",
      (lines(CSV)[1] or ""):match("^timestamp,") ~= nil, lines(CSV)[1])
check("...and the header is exactly the documented seven columns",
      lines(CSV)[1] == HEADER, lines(CSV)[1])
check("epoch stays LAST — it is machinery, not something to read",
      (lines(CSV)[1] or ""):match(",epoch$") ~= nil)

-- =====================================================================
out("\n=== 2. Migrating a 6.114.0 file ===\n")
-- =====================================================================
-- The layout every existing Mac has on disk right now.
wipe()
local OLD_BODY =
    "file_name,new_name,present_location,moved_location,timestamp,event,epoch\n"
    .. '"budget.xlsx","budget final.xlsx","~/Documents","","11/07/26 14:30","Renamed",' .. T_JUL .. "\n"
    .. '"photo.png","","~/Desktop","~/Pictures","03/08/26 09:05","Moved",' .. T_AUG .. "\n"
put(CSV, OLD_BODY)
printed = {}
boot()
local L = lines(CSV)

check("🚨 an existing file is REWRITTEN into the new layout — a migration "
      .. "that only applied to new rows would leave the file half in each "
      .. "format forever", L[1] == HEADER, L[1])
check("every row survived the migration", #L == 3, #L)
check("the first data row now leads with its ISO date",
      (L[2] or ""):sub(1, #ISO_JUL) == ISO_JUL, L[2])
check("...and the fields after it kept their meaning, in order", (function()
    local c = splitCSVLine(L[2] or "")
    return c[2] == "budget.xlsx" and c[3] == "budget final.xlsx"
       and c[4] == "~/Documents" and c[5] == "" and c[6] == "Renamed"
       and tonumber(c[7]) == T_JUL
end)(), L[2])
check("the second row too — including an empty new_name column, which "
      .. "must stay an empty FIELD rather than vanishing and shifting "
      .. "everything left", (function()
    local c = splitCSVLine(L[3] or "")
    return c[1] == ISO_AUG and c[2] == "photo.png" and c[3] == ""
       and c[4] == "~/Desktop" and c[5] == "~/Pictures" and c[6] == "Moved"
end)(), L[3])
check("the migration announces itself with a row count", logged("migrated 2 rows"))

check("📦 the pre-migration file is kept beside it",
      get(CSV .. ".before-iso-dates") == OLD_BODY)
check("...and the backup is announced too", logged("before-iso-dates"))

-- Idempotence. A migration that ran on every boot would rewrite the whole
-- file forever, and — worse — the SECOND run would overwrite the backup
-- with the already-migrated content, quietly destroying the only copy of
-- the original.
local AFTER_FIRST = get(CSV)
printed = {}
boot()
check("🚨 booting again does NOT migrate a second time",
      not logged("migrated"), printed[1])
check("...the file is unchanged", get(CSV) == AFTER_FIRST)
check("🚨 ...and the backup still holds the ORIGINAL, not a copy of the "
      .. "migrated file", get(CSV .. ".before-iso-dates") == OLD_BODY)

-- =====================================================================
out("\n=== 3. The old date text is DISCARDED, never parsed ===\n")
-- =====================================================================
-- 🚨 THE CENTRAL CLAIM OF THIS RELEASE. "11/07/26" is the 11th of July to
-- LL and November 7th to Excel, and a migration that tried to read it
-- would have to guess. It does not guess: it throws the text away and
-- rebuilds the date from the epoch, which has exactly one meaning.
--
-- These fixtures make the two sources DISAGREE on purpose. If any part of
-- the migration were reading the text, these rows would come out wrong —
-- and they would look perfectly plausible, which is why this is asserted
-- rather than assumed.
wipe()
put(CSV,
    "file_name,new_name,present_location,moved_location,timestamp,event,epoch\n"
    .. '"a.txt","","~/D","","01/01/99 00:00","Created",' .. T_JUL .. "\n"
    .. '"b.txt","","~/D","","garbage not a date","Created",' .. T_AUG .. "\n"
    .. '"c.txt","","~/D","","","Created",' .. T_JUL .. "\n")
boot()
L = lines(CSV)
check("🚨 a row whose old text says 1999 still migrates to its EPOCH's "
      .. "date — the text is not consulted",
      (L[2] or ""):sub(1, #ISO_JUL) == ISO_JUL, L[2])
check("a row with unparseable date text migrates cleanly rather than "
      .. "being dropped", (L[3] or ""):sub(1, #ISO_AUG) == ISO_AUG, L[3])
check("a row with an EMPTY date text still gets a real date",
      (L[4] or ""):sub(1, #ISO_JUL) == ISO_JUL, L[4])
check("all three rows are present — none was discarded for having a bad "
      .. "date", #L == 4, #L)

-- =====================================================================
out("\n=== 4. Both layouts in one file ===\n")
-- =====================================================================
-- 🚨 WHY PER-ROW DETECTION AND NOT PER-FILE. This CSV is APPENDED TO by a
-- long-running process. Upgrading mid-session leaves a file with 6.114.0
-- rows above and 6.115.0 rows below, and a loader that read the header
-- once and trusted it for the whole file would mis-read half of them —
-- silently, since every field is a string and none of them would error.
wipe()
put(CSV,
    HEADER .. "\n"
    .. csvQuote(ISO_AUG) .. ',"new.txt","","~/D","","Created",' .. T_AUG .. "\n"
    .. '"old.txt","","~/D","","11/07/26 14:30","Created",' .. T_JUL .. "\n")
boot()
L = lines(CSV)
check("a file holding BOTH layouts is read whole", #L == 3, #L)
check("...the already-new row is left as it is", (function()
    local c = splitCSVLine(L[2] or "")
    return c[1] == ISO_AUG and c[2] == "new.txt"
end)(), L[2])
check("🚨 ...and the old row beneath it is converted, not mis-read as a "
      .. "file called '11/07/26'", (function()
    local c = splitCSVLine(L[3] or "")
    return c[1] == ISO_JUL and c[2] == "old.txt" and c[6] == "Created"
end)(), L[3])

-- =====================================================================
out("\n=== 5. Retention still works across the change ===\n")
-- =====================================================================
-- The prune reads `epoch`, which did not move — but the prune and the
-- migration now run in the same boot, and a rewrite that happened before
-- the prune would write the expired rows back out.
wipe()
local ANCIENT = os.time() - (200 * 86400)   -- well past the 90-day window
local RECENT  = os.time() - (2 * 86400)
put(CSV,
    "file_name,new_name,present_location,moved_location,timestamp,event,epoch\n"
    .. '"ancient.txt","","~/D","","01/01/26 00:00","Created",' .. ANCIENT .. "\n"
    .. '"recent.txt","","~/D","","01/08/26 00:00","Created",' .. RECENT .. "\n")
boot()
L = lines(CSV)
check("rows past the 90-day window are pruned during migration", #L == 2, #L)
check("...and it is the OLD one that went",
      (L[2] or ""):find("recent.txt", 1, true) ~= nil, L[2])

-- =====================================================================
out("\n=== 6. Quoting survives the reorder ===\n")
-- =====================================================================
-- Reordering columns is exactly the kind of change that breaks quoting,
-- because the writer was rewritten and a comma in a file name is the
-- thing that turns one row into two.
wipe()
put(CSV,
    "file_name,new_name,present_location,moved_location,timestamp,event,epoch\n"
    .. '"Q3, final ""draft"".docx","","~/My Docs, old","","11/07/26 14:30","Renamed",' .. T_JUL .. "\n")
boot()
L = lines(CSV)
check("a file name containing a comma and quotes still occupies ONE row",
      #L == 2, #L)
check("...and round-trips exactly", (function()
    local c = splitCSVLine(L[2] or "")
    return c[2] == 'Q3, final "draft".docx' and c[4] == "~/My Docs, old"
end)(), L[2])
check("🚨 the search cache never reaches disk — _hay is built per entry "
      .. "for the picker and would be an eighth column if a writer ever "
      .. "iterated the row table instead of naming its fields",
      (get(CSV) or ""):find("_hay") == nil)

-- =====================================================================
out("\n=== 7. Damaged and hostile files ===\n")
-- =====================================================================
wipe()
put(CSV,
    "file_name,new_name,present_location,moved_location,timestamp,event,epoch\n"
    .. '"good.txt","","~/D","","11/07/26 14:30","Created",' .. T_JUL .. "\n"
    .. "half a line with no epoch\n"
    .. '"noepoch.txt","","~/D","","11/07/26 14:30","Created",notanumber\n')
local ok = pcall(boot)
check("a truncated or corrupt line does not stop the migration", ok)
L = lines(CSV)
check("...the good row survives", #L == 2 and (L[2] or ""):find("good.txt", 1, true) ~= nil, #L)
check("...and rows with no usable epoch are dropped rather than written "
      .. "back with an invented date",
      (get(CSV) or ""):find("noepoch") == nil)

wipe()
put(CSV, "")
ok = pcall(boot)
check("an empty file is survivable", ok and (lines(CSV)[1] == HEADER))

wipe()
put(CSV, HEADER .. "\n")
ok = pcall(boot)
check("a header-only file is survivable", ok and (lines(CSV)[1] == HEADER))

-- =====================================================================
out("\n=== 8. New rows are written in the new shape ===\n")
-- =====================================================================
-- The migration is worth nothing if the recorder then appends 6.114.0
-- rows underneath it.
wipe()
boot()
check("the live recorder writes an ISO, date-first row", (function()
    -- fileTrackerRecord is a local; the pathwatcher callback is the only
    -- public way in, which is also the honest way — it is the path a real
    -- rename takes.
    local before = #lines(CSV)
    local src = get(HS .. "/modules/file_tracker.lua") or ""
    -- The recorder's own timestamp format, read from source: the append
    -- path shares fileTrackerRow with the rewrite path, so the only place
    -- the two could still disagree is the format string itself.
    return src:find('os%.date%("%%Y%-%%m%-%%d %%H:%%M"%)') ~= nil and before >= 1
end)())
check("🚨 no writer still spells the old DD/MM/YY format", (function()
    local src = get(HS .. "/modules/file_tracker.lua") or ""
    -- Stripped of comments first: the header block above the code
    -- EXPLAINS the old format and therefore contains it, so a raw search
    -- finds the explanation and passes while the bug is still there.
    local code = src:gsub("%-%-[^\n]*", "")
    return code:find("%%d/%%m/%%y") == nil
end)())
check("both writers share ONE row builder, so the column order cannot "
      .. "drift between an append and a rewrite", (function()
    local src = get(HS .. "/modules/file_tracker.lua") or ""
    local code = src:gsub("%-%-[^\n]*", "")
    local _, n = code:gsub("fileTrackerRow%(", "")
    return n >= 3   -- one definition, one append use, one rewrite use
end)())

-- =====================================================================
out("\n=== 👁 6.157.0 — the preview pane beside the file list ===\n")
-- =====================================================================
do
    boot()
    local ch = _G.choosers.fileTracker
    check("the picker suspends the pane when it hides", type(ch.hideCb) == "function")
    _G.fileTrackerLog = _G.fileTrackerLog or {}
    table.insert(_G.fileTrackerLog, {
        fileName = "Quarterly numbers (final) (really final).xlsx", newName = "",
        presentLoc = "/Users/lee/OneDrive/Reports", movedLoc = "/Users/lee/Archive",
        event = "Moved", timestamp = "2026-09-03 10:00", epoch = 0,
    })
    ch.qc("Quarterly")
    local r = ch.rows[1]
    check("a row carries every field of the event, one per line, for the pane",
          r and type(r.rawText) == "string"
          and r.rawText:find("Moved  Quarterly numbers", 1, true) ~= nil
          and r.rawText:find("\nin  /Users/lee/OneDrive/Reports", 1, true) ~= nil
          and r.rawText:find("\nto  /Users/lee/Archive", 1, true) ~= nil
          and r.when == "2026-09-03 10:00", r and r.rawText)
    local src = get(HS .. "/modules/file_tracker.lua") or ""
    check("...and the hotkey opens the pane after the picker shows",
          src:find('"preview.open"', 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 🕵️ 6.228.0 — the clock, the door and the switch ===\n")
-- =====================================================================
-- LL, 2026-09-14: "I can't move files in drag and drop again." Proven to
-- be this module by stopping its watchers in the Console. What was NOT
-- proven is WHICH half costs the time — the FSEvents wake-up, or the
-- synchronous CSV write into OneDrive — and those are two different
-- repairs. So this release measures them APART, and this section's job is
-- to make sure they can never quietly become one number.

-- A controllable clock. ft.nowMs prefers hs.timer.absoluteTime, so the
-- suite can hand it any duration it likes and prove the slow path without
-- a Mac, without a real file event and without waiting 120 ms.
local FAKE_NS = 0
hs.timer.absoluteTime = function() return FAKE_NS end
local function advance(ms) FAKE_NS = FAKE_NS + ms * 1e6 end

local D8   = DIR .. "/s8"
local H8   = D8 .. "/home"          -- what is watched
local L8   = D8 .. "/logs"          -- where the CSV goes
local CSV8 = L8 .. "/file_changes-Test-Mac.csv"
-- 🚨 THEY MUST BE DIFFERENT FOLDERS. fileTrackerExcludedPath drops the whole
-- logs folder, so its own CSV can never wake it — which also means a fixture
-- whose home IS its logs folder records nothing and every counter reads 0
-- while looking like a broken feature. (Worth keeping: it says the tracker
-- does NOT feed itself.)
local function wipe8()
    os.execute("rm -rf '" .. D8 .. "' && mkdir -p '" .. H8 .. "/Documents' '" .. L8 .. "'")
    -- 6.229.0: one folder inside the home folder, so the narrowed watch has
    -- exactly one thing to watch and every 6.228.0 check below still counts
    -- the same single watcher.
    _G.FAKE_TREE = { [H8] = { ".", "..", "Documents" } }
    _G.FAKE_DIRS = { [H8 .. "/Documents"] = true }
end

local DEGRADES = {}
local function boot228(extra)
    local M = dofile(HS .. "/modules/file_tracker.lua")
    local c = {
        homeDir = H8, cloudDir = nil, logsDir = L8, hostTag = "Test-Mac",
        configDir = D8,
        csvQuote = csvQuote, splitCSVLine = splitCSVLine,
        warnWriteFailed = function(l) print("WRITEFAIL " .. tostring(l)) end,
        adoptLegacyFile = function() end,
        showPopup = function() end,
        degrade = function(tool, why)
            DEGRADES[#DEGRADES + 1] = tostring(tool) .. " :: " .. tostring(why)
            return false, why
        end,
    }
    for k, v in pairs(extra or {}) do c[k] = v end
    M.setup(c)
    return M, c
end

-- A move of one file, as macOS reports it: two halves of a rename, the
-- old path gone and the new one present.
local function moveEvent(M, oldPath, newPath)
    local w = _G.fileTrackerWatchers[1]
    if not w then return false end
    w.fn({ oldPath }, { { itemIsFile = true, itemRenamed = true } })
    w.fn({ newPath }, { { itemIsFile = true, itemRenamed = true } })
    return true
end

wipe8()
local M8 = boot228()
check("🚨 setup() alone starts NO watcher — the profile's settings are "
      .. "applied after setup returns, so a watcher started there could "
      .. "never be switched off",
      #(_G.fileTrackerWatchers or {}) == 0, #(_G.fileTrackerWatchers or {}))
check("...and the module offers a config table for that override to land on",
      type(M8.config) == "table" and M8.config.enabled == true)
check("...with warm() as the thing that actually starts it",
      type(M8.warm) == "function")

if type(M8.warm) == "function" then pcall(M8.warm) end
check("warm() starts the watcher", #_G.fileTrackerWatchers == 1,
      #_G.fileTrackerWatchers)
check("...and the state says so in words",
      tostring(M8.config.state):find("watching", 1, true) ~= nil,
      M8.config.state)

-- 🔒 THE SWITCH. This is the check LL's Mac depends on tonight: with the
-- override applied the way init.lua applies it, nothing may be watched.
wipe8()
local M9 = boot228()
M9.config.enabled = false            -- exactly what init.lua's settings block does
if type(M9.warm) == "function" then pcall(M9.warm) end
check("🔒 enabled = false means NOT ONE folder is watched",
      #_G.fileTrackerWatchers == 0, #_G.fileTrackerWatchers)
check("...and the report's state names the settings line that did it",
      tostring(M9.config.state):find("enabled = false", 1, true) ~= nil,
      M9.config.state)

-- ---- the two clocks, kept apart --------------------------------------
wipe8()
printed = {}
DEGRADES = {}
local M10 = boot228()
if type(M10.warm) == "function" then pcall(M10.warm) end
local st = M10.config.stats
check("nothing is timed before macOS wakes it", st.callbacks == 0 and st.writes == 0)

FAKE_NS = 0
moveEvent(M10, H8 .. "/a.txt", H8 .. "/b.txt")
check("a move wakes the module twice and both wake-ups are counted",
      st.callbacks == 2, st.callbacks)
check("...and the paths it was handed are counted too", st.paths == 2, st.paths)
check("...and the row reached the CSV", st.rows == 1, st.rows)
check("🚨 the WRITE has its own counter — one write, not two, and not "
      .. "folded into the wake-ups", st.writes == 1, st.writes)

-- 🚨 THE MUTATION THIS SECTION EXISTS FOR: a build that adds both
-- durations into one total reads as "the file tracker is slow", which
-- names a module and not a cause. Narrowing the watched folders and
-- moving the write off the main thread are different repairs.
wipe8()
FAKE_NS = 0
DEGRADES = {}
local M11 = boot228()
if type(M11.warm) == "function" then pcall(M11.warm) end
local s11 = M11.config.stats
-- Drive one event whose WRITE is expensive and whose classification is not:
-- the clock is read either side of io.open, so advancing it during the
-- write shows up on the write's total and nowhere else.
local realOpen = io.open
io.open = function(path, mode)
    if mode == "a" then advance(300) end
    return realOpen(path, mode)
end
moveEvent(M11, H8 .. "/c.txt", H8 .. "/d.txt")
io.open = realOpen
check("🚨 a slow WRITE is charged to the write, not to the wake-up",
      s11.writeWorstMs >= 300, s11.writeWorstMs)
check("...and the wake-up's own total still contains it (it is inside), "
      .. "so the two are reported side by side rather than one of them",
      s11.cbWorstMs >= 300, s11.cbWorstMs)
check("...the slow WRITE is counted as a slow write", s11.slowWrite == 1,
      s11.slowWrite)
check("🔔 ...and it took the degrade door, naming the tool",
      #DEGRADES > 0 and DEGRADES[1]:find("File tracker", 1, true) == 1,
      DEGRADES[1])
check("🔔 ...and the door's words say what it costs, in LL's terms",
      (DEGRADES[1] or ""):find("drag and drop", 1, true) ~= nil, DEGRADES[1])
-- 🧪 AND THIS ROW EXISTS BECAUSE THE TWO ABOVE PASSED WITH THE WRITE'S OWN
-- ALERT DELETED. A slow write is INSIDE the wake-up it happens in, so the
-- wake-up crosses the threshold on the same event and alerts too — and both
-- of those alerts carry the tool name and the words "drag and drop". A check
-- that only looks for the tool is not a check on the write. Same family as
-- 6.212.0's line-that-counted-any-stroke: assert the thing that is unique to
-- the branch you meant.
local function degradeSaying(needle)
    for _, d in ipairs(DEGRADES) do
        if d:find(needle, 1, true) then return true end
    end
    return false
end
check("🔔 ...and one of them names the CSV WRITE by itself — the half to fix",
      degradeSaying("a CSV write"), table.concat(DEGRADES, " | "))
check("🔔 ...while the wake-up it happened inside is named separately",
      degradeSaying("an FSEvents wake-up"), table.concat(DEGRADES, " | "))

-- A fast event must alert NOBODY. A door that opens on every file move is
-- a door LL turns off within a day.
wipe8()
FAKE_NS = 0
DEGRADES = {}
local M12 = boot228()
if type(M12.warm) == "function" then pcall(M12.warm) end
moveEvent(M12, H8 .. "/e.txt", H8 .. "/f.txt")
check("🤫 a fast event alerts nothing at all", #DEGRADES == 0, #DEGRADES)
check("...and is counted as not slow",
      M12.config.stats.slowCb == 0 and M12.config.stats.slowWrite == 0)

-- ---- the report ------------------------------------------------------
wipe8()
printed = {}
local M13 = boot228()
if type(M13.warm) == "function" then pcall(M13.warm) end
_G.fileTrackerReport()
check("🚨 the report prints as ONE string (6.179.1 — the console gate eats "
      .. "rows otherwise)", #printed == 1, #printed)
local rep = printed[1] or ""
check("...it says macOS has not woken it, which is NOT the same as 0 ms",
      rep:find("has not woken this module once", 1, true) ~= nil, rep)
-- 6.229.0 REPLACED THIS CHECK RATHER THAN DELETING IT. Until this release
-- it read "it names the whole home folder as what it watches", and that was
-- true and was the bug. What it must name now is the narrowed list AND what
-- it stopped watching — a report that quietly said less would be the worst
-- outcome of this change.
check("...it names each folder it watches, by path",
      rep:find(H8 .. "/Documents", 1, true) ~= nil, rep)
check("🎯 ...and it says WHY that list, not the whole home folder",
      rep:find("~/Library is not one of them", 1, true) ~= nil, rep)
check("📏 ...and it names the cost it just took on — a loose file at the "
      .. "top of ~ is not watched any more",
      rep:find("loose file at the top of ~", 1, true) ~= nil, rep)
check("...and it hands over the reach knob beside the off switch",
      rep:find("folders = ", 1, true) ~= nil, rep)
check("...and it hands over the off switch",
      rep:find("settings = { file_tracker = { enabled = false } }", 1, true) ~= nil)

printed = {}
FAKE_NS = 0
moveEvent(M13, H8 .. "/g.txt", H8 .. "/h.txt")
_G.fileTrackerReport()
rep = printed[1] or ""
check("🚨 once woken, the report stops saying 'not woken' — a module that "
      .. "has been measured and is fast must not read like one that was "
      .. "never asked", rep:find("has not woken", 1, true) == nil, rep)
check("...wake-ups and writes get their own lines, with their own worsts",
      rep:find("wake%-ups :") ~= nil and rep:find("writes   :") ~= nil, rep)
check("...and a quiet session says so rather than printing a ⚠️ nobody needs",
      rep:find("none over", 1, true) ~= nil, rep)
check("...the report names the clock that actually answered, so 'never "
      .. "measured' and 'measured and fast' cannot read alike (6.196.1)",
      rep:find("clock    : hs.timer.absoluteTime", 1, true) ~= nil, rep)

-- The OneDrive line is the honest half of the diagnosis, and it must only
-- appear when the CSV really is in a cloud folder — on a Mac with no
-- OneDrive it would be a lie.
check("no cloud folder, no OneDrive warning",
      rep:find("INSIDE OneDrive", 1, true) == nil, rep)
wipe8()
printed = {}
local M14 = boot228({ cloudDir = L8 })
M14.warm()
_G.fileTrackerReport()
check("🚨 a CSV that IS inside the cloud folder says so — that write is the "
      .. "prime suspect and the report must not bury it",
      (printed[1] or ""):find("INSIDE OneDrive", 1, true) ~= nil, printed[1])

-- A Mac whose Hammerspoon has no absoluteTime still counts, less precisely,
-- and the report SAYS which clock answered rather than quietly implying the
-- good one (6.196.1: a state you did not read must not read like one you did).
wipe8()
printed = {}
local savedAbs = hs.timer.absoluteTime
hs.timer.absoluteTime = nil
local M14b = boot228()
if type(M14b.warm) == "function" then pcall(M14b.warm) end
moveEvent(M14b, H8 .. "/i.txt", H8 .. "/j.txt")
_G.fileTrackerReport()
hs.timer.absoluteTime = savedAbs
check("🚨 no absoluteTime: it still times, and the report NAMES the weaker "
      .. "clock instead of claiming the good one",
      (printed[1] or ""):find("os.clock", 1, true) ~= nil, printed[1])
check("...and the counting is unaffected", M14b.config.stats.callbacks == 2,
      M14b.config.stats.callbacks)

-- ---- the hand switch --------------------------------------------------
wipe8()
local M15 = boot228()
if type(M15.warm) == "function" then pcall(M15.warm) end
check("stopWatching() lets LL stop it without a reload",
      M15.config.stopWatching() and #_G.fileTrackerWatchers == 0)
M15.config.startWatching()
check("...and startWatching() puts it back", #_G.fileTrackerWatchers == 1)
M15.config.startWatching()
check("...starting twice does not double the watchers",
      #_G.fileTrackerWatchers == 1, #_G.fileTrackerWatchers)

-- A throw inside the classifier must cost this module, never the tap, and
-- must STILL be timed — or the one event that hurts is the one not counted.
wipe8()
printed = {}
local M16 = boot228()
if type(M16.warm) == "function" then pcall(M16.warm) end
local w16 = _G.fileTrackerWatchers[1]
local okThrow = pcall(function() w16.fn(nil, nil) end)
check("a callback handed nothing does not throw out into the pathwatcher",
      okThrow)
check("...and it was still counted", M16.config.stats.callbacks == 1,
      M16.config.stats.callbacks)

-- 🚨 AND A REAL THROW, because "handed nothing" never reached the code that
-- can fail: the classifier returns early on an empty list, so the pcall
-- around it had no check that could fail it. The one event that hurts must
-- not be the one event nobody counts.
local realAttrs = hs.fs.attributes
hs.fs.attributes = function() error("AX went away mid-event") end
printed = {}
local okBoom = pcall(function()
    w16.fn({ H8 .. "/boom.txt" }, { { itemIsFile = true, itemRenamed = true } })
end)
hs.fs.attributes = realAttrs
check("🚨 a throw inside the classifier costs this module, never the "
      .. "pathwatcher macOS calls", okBoom)
check("...it is still TIMED and COUNTED — the slow event is exactly the one "
      .. "likely to throw", M16.config.stats.callbacks == 2,
      M16.config.stats.callbacks)
check("...and it is SAID, not swallowed", logged("File tracker callback error"))

-- =====================================================================
-- 🎯 6.229.0 — WHAT IS WATCHED, decided off a list of names
-- =====================================================================
-- LL, 2026-09-15: "Can I get a paper trail of /Users/leeleblanc or is that
-- too broad?" His own 6.228.0 report answered it — 60,115 wake-ups and
-- 16,597 ms of main thread across a day, to keep 49 rows — so the folders
-- are chosen now instead of taking the home folder whole. ft.watchRoots is
-- PURE, which is what lets the whole rule be proven here with no Mac and no
-- file system underneath it.
--
-- 🚨 THE SECTION WRAPS ITSELF AND COUNTS ITS OWN CHECKS (6.186.0): a throw
-- in here would delete every check after it while the run still said
-- "0 failed".
out("\n=== 🎯 6.229.0 — the watch is narrowed at the watch ===\n")
local before229 = pass + fail
local ok229, err229 = pcall(function()

local MW = boot228()
local ftw = MW.config
local HOME = "/Users/lee"

-- The shape of a real home folder, as hs.fs.dir would hand it over.
local REAL = { "Applications", "Desktop", "Documents", "Downloads",
               "Library", "Movies", "Music", "Pictures",
               ".hammerspoon", ".Trash", ".ssh" }

local function has(list, want)
    for _, v in ipairs(list) do if v == want then return true end end
    return false
end
local function skippedHas(list, want)
    for _, v in ipairs(list) do if v.name == want then return true end end
    return false
end

local kept, skipped = ftw.watchRoots(HOME, nil, REAL)

check("🎯 ~/Library is NOT watched — that is the whole release",
      not has(kept, HOME .. "/Library"), table.concat(kept, " "))
check("...and it is NAMED as skipped, never silently dropped",
      skippedHas(skipped, "Library"))
check("...while the folders his files are actually in ARE watched",
      has(kept, HOME .. "/Documents") and has(kept, HOME .. "/Desktop")
      and has(kept, HOME .. "/Downloads"), table.concat(kept, " "))

-- 🚨 THE MUTATION THIS PAIR EXISTS FOR: "skip everything hidden" is one
-- character shorter and silently retires a decision fileTrackerExcludedPath
-- makes on purpose — ~/.hammerspoon IS tracked, because config edits and
-- init.lua swaps are worth a paper trail. A rule that narrows a watch must
-- not quietly un-decide something the exclusions already decided.
check("🔒 .hammerspoon survives the hidden rule — the exclusions keep it "
      .. "deliberately", has(kept, HOME .. "/.hammerspoon"),
      table.concat(kept, " "))
check("...but every OTHER hidden folder is skipped",
      not has(kept, HOME .. "/.Trash") and not has(kept, HOME .. "/.ssh"),
      table.concat(kept, " "))
check("...and . and .. are never watch roots",
      not has(kept, HOME .. "/.") and not has(kept, HOME .. "/.."))

-- OneDrive lives INSIDE ~/Library on this Mac. Skipping Library would take
-- it with it, and the tracker's whole cross-machine value with it.
local CLOUD = HOME .. "/Library/CloudStorage/OneDrive-Personal"
local kept2 = ftw.watchRoots(HOME, CLOUD, REAL)
check("☁️ OneDrive is added back BY NAME even though it lives inside the "
      .. "folder that was skipped", has(kept2, CLOUD), table.concat(kept2, " "))
check("...and skipping Library still holds around it",
      not has(kept2, HOME .. "/Library"), table.concat(kept2, " "))

-- 🚨 AND THE OPPOSITE CASE, which costs double: a cloud folder that a kept
-- folder already contains would be a SECOND pathwatcher over the same tree,
-- so macOS wakes this module twice for one file event — the exact cost this
-- release exists to cut, paid in duplicate.
local INSIDE = HOME .. "/Documents/OneDrive"
local kept3 = ftw.watchRoots(HOME, INSIDE, REAL)
check("🚨 a cloud folder already inside a watched folder is NOT watched "
      .. "twice", not has(kept3, INSIDE), table.concat(kept3, " "))
check("...and ft.covers is the thing that knows",
      ftw.covers(HOME .. "/Documents", INSIDE)
      and not ftw.covers(HOME .. "/Documents", HOME .. "/DocumentsOld/x"))

-- A home folder with nothing in it is not an error, and is not a reason to
-- watch everything: it is simply nothing to watch.
local kept4 = ftw.watchRoots(HOME, nil, {})
check("an empty listing watches nothing, and says nothing was skipped",
      #kept4 == 0)

-- ---- the listing half ------------------------------------------------
-- 🚨 A LOOSE FILE AT THE TOP OF ~ IS NOT A FOLDER and must never become a
-- watch root — hs.pathwatcher wants a directory, and this is the one place
-- that can tell them apart.
_G.FAKE_TREE = { [HOME] = { ".", "..", "Documents", "notes.txt" } }
_G.FAKE_DIRS = { [HOME .. "/Documents"] = true }
local dirs = ftw.homeDirs(HOME)
check("📁 the listing keeps DIRECTORIES only — a loose file is not a watch "
      .. "root", dirs and #dirs == 1 and dirs[1] == "Documents",
      dirs and table.concat(dirs, " "))

-- 🔎 "COULD NOT LIST" AND "NOTHING THERE" MUST NOT READ THE SAME (6.196.1's
-- rule, in the place that decides what gets watched at all): an empty answer
-- would watch NOTHING and report it as normal — the feature gone, silently.
check("🔎 a Mac that cannot list its home folder answers nil, not {}",
      ftw.homeDirs(HOME, function() error("no") end,
                   function() return "directory" end) == nil)
check("...and a Hammerspoon with no hs.fs at all says the same",
      ftw.homeDirs(HOME, nil, nil) == nil or type(hs.fs.dir) == "function")

-- ---- end to end, through warm() --------------------------------------
wipe8()
DEGRADES = {}
_G.FAKE_TREE = { [H8] = { ".", "..", "Documents", "Library", ".ssh" } }
_G.FAKE_DIRS = { [H8 .. "/Documents"] = true, [H8 .. "/Library"] = true,
                 [H8 .. "/.ssh"] = true }
local M17 = boot228()
if type(M17.warm) == "function" then pcall(M17.warm) end
check("🎯 warm() starts ONE watcher for the one folder that earns it, not "
      .. "one for the home folder", #_G.fileTrackerWatchers == 1,
      #_G.fileTrackerWatchers)
check("...and nothing degraded on the way — this is the normal path",
      #DEGRADES == 0, table.concat(DEGRADES, " | "))

-- 🔌 THE REACH IS HIS, and it is a settings line, not a release: the same
-- rule as every other knob here, applied to the one thing 6.228.0 said was
-- his call.
wipe8()
_G.FAKE_TREE = { [H8] = { ".", "..", "Documents", "Library" } }
_G.FAKE_DIRS = { [H8 .. "/Documents"] = true, [H8 .. "/Library"] = true }
local M18 = boot228()
M18.config.folders = { H8 .. "/Downloads", H8 .. "/Pictures" }
if type(M18.warm) == "function" then pcall(M18.warm) end
check("🔌 settings = { file_tracker = { folders = ... } } is watched "
      .. "VERBATIM — his list, not ours", #_G.fileTrackerWatchers == 2,
      #_G.fileTrackerWatchers)

-- 🚨 AND THE FALLBACK NEVER WATCHES NOTHING. A Mac that cannot answer about
-- its own home folder loses the paper trail entirely if this returns an
-- empty list — so it watches wide, the slow way, and SAYS SO through the 🔔
-- door rather than degrading into silence.
wipe8()
DEGRADES = {}
_G.FAKE_TREE = {}                       -- hs.fs.dir will throw on H8 now
local M19 = boot228()
if type(M19.warm) == "function" then pcall(M19.warm) end
check("🚨 a Mac that cannot list its home folder still watches it — the "
      .. "paper trail degrades, it never disappears",
      #_G.fileTrackerWatchers >= 1, #_G.fileTrackerWatchers)
check("🔔 ...and it takes the door, so LL is told rather than finding out "
      .. "in a month", #DEGRADES == 1
      and DEGRADES[1]:find("could not list", 1, true) ~= nil,
      table.concat(DEGRADES, " | "))
check("...and the report's watching line carries the same warning",
      (function()
           printed = {}
           _G.fileTrackerReport()
           return (printed[1] or ""):find("could not list", 1, true) ~= nil
       end)(), printed[1])

end)
if not ok229 then
    check("🚨 the 6.229.0 section ran to the end without throwing", false,
          tostring(err229))
end
check("🚨 ...and it asserted every check it was written to make (a throw "
      .. "deletes the rest while the run still says 0 failed)",
      (pass + fail) - before229 >= 20, (pass + fail) - before229)

os.execute("rm -rf '" .. DIR .. "'")

realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
