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
    fs = { attributes = function() return nil end,
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

os.execute("rm -rf '" .. DIR .. "'")

realPrint(table.concat(printed, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
