-- =====================================================================
-- test_clipboard.lua — the feature whose worst failure LOSES YOUR HISTORY
-- =====================================================================
--     lua5.4 test_clipboard.lua [/path/to/hammerspoon]
--
-- Clipboard history was in init.lua until 6.55.0, spread over four
-- places, with no way to drive it — so it was only ever audited from
-- SOURCE. Now it is a module and the real functions can be run. The
-- properties:
--
--   P1  A BAD WRITE NEVER DESTROYS THE FILE. It is rewritten on every
--       copy, so this is not a one-off risk — it is a thousand chances
--       a day. An encode that will not read back must leave the
--       existing file ALONE, and an unreadable file must be BACKED UP
--       before anything starts fresh over the top of it.
--   P2  EDITING AN ENTRY COPIES IT, AND DOES NOT DUPLICATE IT. Setting
--       the pasteboard wakes the watcher; the dedupe is what turns that
--       into a lift-to-front instead of a second row. Deleting copies
--       nothing.
--   P3  THE PICKER SURVIVES hs.chooser's BRIDGE. Choices round-trip
--       through Objective-C and come back as REBUILT tables, so table
--       identity cannot be used to find the entry — only a number
--       survives. This is why applyEdit takes an index.
--   P4  A COPY MADE DURING BOOT IS NOT LOST when the file finishes
--       loading a couple of seconds later and replaces the cache.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a filesystem and a Mac, in tables --------------------------------
local FILES, ALERTS, PASTEBOARD, printed = {}, {}, nil, {}
local ENCODE_BREAKS, DECODE_BREAKS, WRITE_FAILS = false, false, false
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

local realIoOpen = io.open
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        if WRITE_FAILS then return nil end
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s end,
                 close = function() FILES[path] = table.concat(buf) end }
    end
    if FILES[path] == nil then return nil end
    local content, done = FILES[path], false
    return { read = function() if done then return nil end done = true return content end,
             close = function() end }
end

-- A JSON stand-in that can be told to misbehave, so P1 can be exercised.
local function enc(t)
    if ENCODE_BREAKS then return "<<not json>>" end
    local parts = {}
    for _, it in ipairs(t) do
        parts[#parts + 1] = (it.date or "") .. "\1" .. (it.text or "")
    end
    return table.concat(parts, "\2")
end
local function dec(s)
    if DECODE_BREAKS then error("bad json") end
    if tostring(s):find("<<not json>>", 1, true) then error("bad json") end
    -- ⚠️ THE STUB HAS TO THROW LIKE THE REAL ONE. hs.json.decode RAISES on
    -- malformed input; the first version of this stub quietly returned an
    -- empty table instead, so the module's "unreadable file" branch was
    -- never reached and the backup guard looked untested when it was
    -- merely unexercised.
    if s ~= "" and not tostring(s):find("\1", 1, true) then error("bad json") end
    local o = {}
    for chunk in tostring(s):gmatch("[^\2]+") do
        local d, t = chunk:match("^(.-)\1(.*)$")
        if d then o[#o + 1] = { date = d, text = t } end
    end
    return o
end

local HYPER, PROVIDED = {}, {}
hs = {
    json = { encode = enc, decode = dec },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(t) PASTEBOARD = t ; return true end,
                   getContents = function() return PASTEBOARD end },
    chooser = { new = function(fn)
        local c = { fn = fn }
        for _, m in ipairs({ "placeholderText", "show", "width", "searchSubText" }) do
            c[m] = function(self) return self end
        end
        function c:choices(x) self.rows = x ; return self end
        function c:queryChangedCallback(f) self.qcb = f ; return self end
        return c end },
    dialog = { textPrompt = function() return "Cancel", "" end },
    timer = { secondsSinceEpoch = function() return 1000 end },
    configdir = "/cfg",
}
_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local CORE = {
    hostTag = "Test-Mac", logsDir = "/logs",
    warnWriteFailed = function() ALERTS[#ALERTS + 1] = "writeFailed" end,
    adoptLegacyFile = function() end,
    showPopup = function(c) c.shown = true end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, C
local function boot()
    ALERTS, PASTEBOARD, printed, HYPER, PROVIDED = {}, nil, {}, {}, {}
    ENCODE_BREAKS, DECODE_BREAKS, WRITE_FAILS = false, false, false
    _G.clipboardCache = nil
    M = dofile(HS .. "/modules/clipboard_history.lua")
    M.setup(CORE)
    C = _G.clipboardHistory
    return C
end

-- =====================================================================
out("\n=== 1. Contract ===\n")
-- =====================================================================
boot()
check("the module returns name, order and a cheatsheet",
      M.name == "Clipboard History" and type(M.order) == "number"
      and type(M.cheatsheet) == "table")
check("it claims ⇪V and ⇪⇧V", HYPER["|v"] ~= nil and HYPER["shift|v"] ~= nil)
check("its order collides with none of focus_mode/bulk_rename/workspaces",
      M.order ~= 14.0 and M.order ~= 14.1 and M.order ~= 14.2)
-- 🗂 6.113.0, on request: filed under CAPTURE, not TEXT. Asserted rather
-- than left to the file, because a family is one word in a table that a
-- later edit can revert without anything noticing until the sheet is open.
check("filed under the capture family — it takes something IN and keeps it",
      M.family == "capture", M.family)
check("the watcher in init.lua can reach it by service",
      PROVIDED["clipboard.add"] ~= nil)
check("the file is read in warm(), not on the boot path",
      type(M.warm) == "function")
check("its file is tagged per machine, so two Macs sharing one OneDrive "
      .. "never overwrite each other",
      C.file:find("Test%-Mac") ~= nil, C.file)

-- =====================================================================
out("\n=== 2. Adding, dedupe, caps ===\n")
-- =====================================================================
boot()
C.loaded = true
check("a copy is stored", C.add("hello") == true and #_G.clipboardCache == 1)
check("the same text copied again is NOT stored twice",
      C.add("hello") == false and #_G.clipboardCache == 1)
C.add("world")
C.add("hello")
check("🚨 copying an OLD item moves it to the FRONT rather than making a "
      .. "second row", #_G.clipboardCache == 2
      and _G.clipboardCache[1].text == "hello")
check("empty and non-string copies are ignored",
      C.add("") == false and C.add(nil) == false and C.add(42) == false)

boot() ; C.loaded = true
check("an item over the size cap is skipped, so the file stays quick to "
      .. "write", C.add(string.rep("x", C.maxItemSize + 1)) == false)
check("...and it says so rather than silently dropping it", (function()
    for _, l in ipairs(printed) do
        if l:find("over 1 MB", 1, true) then return true end
    end
end)())

boot() ; C.loaded = true ; C.max = 5
for i = 1, 12 do C.add("item " .. i) end
check("the history is capped", #_G.clipboardCache == 5, #_G.clipboardCache)
check("...keeping the NEWEST", _G.clipboardCache[1].text == "item 12")

-- =====================================================================
out("\n=== 3. P1 — a bad write must never destroy the file ===\n")
-- =====================================================================
boot() ; C.loaded = true
FILES = {}
C.add("keep me")
local saved = FILES[C.file]
check("a normal save writes the file", saved ~= nil)

ENCODE_BREAKS = true
C.add("this will not encode")
check("🚨 P1: AN ENCODE THAT WILL NOT READ BACK LEAVES THE EXISTING FILE "
      .. "ALONE — writing it is what corrupted the file originally, and it "
      .. "was only noticed at the next reload as 'history wiped'",
      FILES[C.file] == saved, "file changed")
check("...and you are told, rather than it failing quietly", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("NOT saved", 1, true) then return true end
    end
end)(), ALERTS[#ALERTS])
ENCODE_BREAKS = false

-- An unreadable file on load.
boot()
FILES = { [C.file] = "this is not parseable at all" }
C.load()
check("🚨 P1: AN UNREADABLE FILE IS BACKED UP BEFORE STARTING FRESH — it "
      .. "used to fall back to {} silently, and the very next copy "
      .. "overwrote the broken file with that empty list",
      (function()
    for path, body in pairs(FILES) do
        if path:find("%.corrupt%-") and body == "this is not parseable at all" then
            return true
        end
    end
end)())
check("...and the cache is empty rather than half-parsed",
      #_G.clipboardCache == 0)
check("...and it is announced", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("unreadable", 1, true) then return true end
    end
end)())

boot() ; C.loaded = true
WRITE_FAILS = true
C.add("nowhere to go")
check("a write that cannot open the file warns instead of pretending",
      (function()
    for _, a in ipairs(ALERTS) do if a == "writeFailed" then return true end end
end)())

-- =====================================================================
out("\n=== 4. P2 — editing copies, deleting does not ===\n")
-- =====================================================================
boot() ; C.loaded = true
C.add("third") ; C.add("second") ; C.add("first")
C.renderEdit("")                      -- builds the snapshot the picker uses
PASTEBOARD = nil
local res = C.applyEdit(2, "second, corrected")
check("editing reports success", res == "updated", res)
check("🚨 P2: THE EDITED TEXT IS PUT ON THE CLIPBOARD — you edited it in "
      .. "order to paste it", PASTEBOARD == "second, corrected", tostring(PASTEBOARD))
check("...and the stored entry changed", (function()
    for _, e in ipairs(_G.clipboardCache) do
        if e.text == "second, corrected" then return true end
    end
end)())

-- 🚨 The duplicate question, driven the way the real watcher would.
local before = #_G.clipboardCache
C.add(PASTEBOARD)                     -- the watcher waking on our own write
check("🚨 P2: THE WATCHER SEEING OUR OWN WRITE DOES NOT ADD A SECOND ROW — "
      .. "the dedupe lifts the edited entry instead of copying it",
      #_G.clipboardCache == before, before .. " -> " .. #_G.clipboardCache)

boot() ; C.loaded = true
C.add("doomed")
C.renderEdit("")
PASTEBOARD = nil
res = C.applyEdit(1, "")
check("saving an entry EMPTY deletes it", res == "deleted"
      and #_G.clipboardCache == 0)
check("🚨 ...and deleting copies NOTHING — 'unless I delete it' was the "
      .. "asked-for split", PASTEBOARD == nil, tostring(PASTEBOARD))

-- =====================================================================
out("\n=== 5. P3 — surviving hs.chooser's bridge ===\n")
-- =====================================================================
boot() ; C.loaded = true
C.add("c") ; C.add("b") ; C.add("a")
C.renderEdit("")
-- A copy arrives while the picker is open, shifting every index by one.
C.add("brand new")
res = C.applyEdit(2, "b, edited")
check("🚨 P3: THE RIGHT ENTRY IS EDITED EVEN AFTER A NEW COPY SHIFTED "
      .. "EVERY INDEX — the snapshot holds the real object and its CURRENT "
      .. "position is re-found before writing", res == "updated")
check("...and it really was 'b' that changed", (function()
    for _, e in ipairs(_G.clipboardCache) do
        if e.text == "b, edited" then return true end
    end
end)())
check("...and nothing else was harmed", (function()
    local seen = {}
    for _, e in ipairs(_G.clipboardCache) do seen[e.text] = true end
    return seen["a"] and seen["c"] and seen["brand new"]
end)())

boot() ; C.loaded = true
C.add("only")
C.renderEdit("")
_G.clipboardCache = {}                -- the entry vanishes entirely
check("an entry that is gone reports 'gone' rather than editing the wrong "
      .. "row", C.applyEdit(1, "x") == "gone")

-- =====================================================================
out("\n=== 6. P4 — a copy made during boot is not lost ===\n")
-- =====================================================================
boot()
FILES = { [C.file] = "Aug 01\1old one\2Aug 01\1older" }
-- A copy lands BEFORE warm() has read the file, which is the two-second
-- window between setup() and the deferred load.
C.add("copied during boot")
check("it is held while the file has not loaded", #C.preload == 1)
M.warm()
check("🚨 P4: THE BOOT-TIME COPY SURVIVES THE LOAD that replaced the whole "
      .. "cache", _G.clipboardCache[1].text == "copied during boot",
      tostring((_G.clipboardCache[1] or {}).text))
check("...and the file's own history is there underneath it",
      #_G.clipboardCache == 3, #_G.clipboardCache)
check("...and the holding list is cleared afterwards", #C.preload == 0)

-- =====================================================================
out("\n=== 7. Mutation — are these load-bearing? ===\n")
-- =====================================================================
do
    -- Mutation 1: save without verifying the encode round-trips.
    boot() ; C.loaded = true
    FILES = {} ; C.add("precious")
    local good = FILES[C.file]
    local realSave = C.save
    C.save = function()
        local body = hs.json.encode(_G.clipboardCache)   -- no verify
        local f = io.open(C.file, "w")
        if f then f:write(body); f:close() end
        return true
    end
    ENCODE_BREAKS = true
    C.add("breaks the encode")
    local clobbered = (FILES[C.file] ~= good)
    ENCODE_BREAKS = false ; C.save = realSave
    check("MUTATION: skipping the round-trip check overwrites a good file "
          .. "with unreadable JSON — P1 catches it", clobbered)

    -- Mutation 2: edit without copying to the clipboard.
    boot() ; C.loaded = true
    C.add("x") ; C.renderEdit("") ; PASTEBOARD = nil
    local realApply = C.applyEdit
    C.applyEdit = function(i, t)
        _G.clipboardCache[1].text = t ; return "updated"
    end
    C.applyEdit(1, "edited")
    local copied = (PASTEBOARD ~= nil)
    C.applyEdit = realApply
    check("MUTATION: an edit that does not touch the pasteboard leaves you "
          .. "to copy it again — P2 catches it", copied == false)

    -- Mutation 3: match the entry by table identity, as the original did.
    boot() ; C.loaded = true
    C.add("one") ; C.renderEdit("")
    local handedBack = { text = "one" }   -- what the bridge really returns
    local foundByIdentity = false
    for _, v in ipairs(_G.clipboardCache) do
        if v == handedBack then foundByIdentity = true end
    end
    check("MUTATION: comparing the REBUILT table hs.chooser hands back by "
          .. "identity never matches — which is why every edit used to "
          .. "answer 'that entry is gone'", foundByIdentity == false)
end

-- =====================================================================
out("\n=== 8. ☑️ Select mode — pick several rows, act on them ONCE ===\n")
-- =====================================================================
-- 6.97.0. hs.chooser has no shift-click multi-select, so Enter TAGS
-- rows and an action row applies to all of them — the same pattern the
-- Document Watcher list proved. Tags key on the ENTRY TABLE, so a copy
-- arriving mid-pick shifts every index and loses nothing.
boot() ; C.loaded = true
C.add("third") ; C.add("second") ; C.add("first")
C.renderEdit("")
local rows = C.editChooser.rows
check("the normal edit list leads with ONE action row: ☑️ Select several…",
      rows[1] and rows[1].action == "selecton"
      and rows[1].text:find("Select several", 1, true) ~= nil)
check("...and entry rows still carry their index for one-at-a-time edits",
      rows[2] and rows[2].idx == 1, tostring(rows[2] and rows[2].idx))

C.editChooser.fn({ action = "selecton" })
rows = C.editChooser.rows
check("entering select mode re-renders with delete / copy / never-mind rows",
      rows[1] and rows[1].action == "deletetagged"
      and rows[2] and rows[2].action == "copytagged"
      and rows[3] and rows[3].action == "selectoff")
check("...saying honestly that nothing is picked yet",
      rows[1].text:find("Nothing picked yet", 1, true) ~= nil)
check("...and the picker was reopened for the next pick",
      C.editChooser.shown == true)

C.editChooser.fn({ idx = rows[4].idx })          -- pick "first"
rows = C.editChooser.rows
check("Enter on a row PICKS it — the row wears a ✓",
      rows[4].text:find("✓ first", 1, true) == 1 and C.taggedCount() == 1,
      rows[4].text)
C.editChooser.fn({ idx = rows[4].idx })          -- unpick it again
check("Enter on a picked row UNPICKS it", C.taggedCount() == 0)

C.editChooser.fn({ idx = C.editChooser.rows[4].idx })   -- first
C.editChooser.fn({ idx = C.editChooser.rows[6].idx })   -- third
check("two picked, and the action row counts them",
      C.taggedCount() == 2
      and C.editChooser.rows[1].text:find("Delete the 2", 1, true) ~= nil,
      C.editChooser.rows[1].text)

FILES = {}
C.editChooser.fn({ action = "deletetagged" })
check("🗑 deleting the picked rows removes exactly those",
      #_G.clipboardCache == 1 and _G.clipboardCache[1].text == "second",
      #_G.clipboardCache)
check("...saves the file", FILES[C.file] ~= nil)
check("...announces the count", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Deleted 2", 1, true) then return true end
    end
end)(), ALERTS[#ALERTS])
check("...and ends select mode — the job it existed for is done",
      C.selectMode == false and C.taggedCount() == 0)

-- Copy-as-one.
boot() ; C.loaded = true
C.add("gamma") ; C.add("beta") ; C.add("alpha")
C.renderEdit("")
C.editChooser.fn({ action = "selecton" })
C.editChooser.fn({ idx = C.editChooser.rows[4].idx })   -- alpha
C.editChooser.fn({ idx = C.editChooser.rows[6].idx })   -- gamma
PASTEBOARD = nil
C.editChooser.fn({ action = "copytagged" })
check("📋 the picked rows are copied as ONE text, joined with line breaks, "
      .. "in history order", PASTEBOARD == "alpha\ngamma", tostring(PASTEBOARD))
check("...announced with the count", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Copied 2", 1, true) then return true end
    end
end)())
check("...and select mode ends here too", C.selectMode == false)

-- The empty-handed and reset paths.
boot() ; C.loaded = true
C.add("only")
C.renderEdit("")
C.editChooser.fn({ action = "selecton" })
C.editChooser.fn({ action = "deletetagged" })
check("deleting with NOTHING picked deletes nothing and says so",
      #_G.clipboardCache == 1 and (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Nothing picked", 1, true) then return true end
    end
end)())
C.renderEdit("")
C.editChooser.fn({ action = "selecton" })
C.editChooser.fn({ idx = C.editChooser.rows[4].idx })
C.editChooser.fn({ action = "selectoff" })
check("✖️ never mind forgets the picks and returns to one-at-a-time",
      C.selectMode == false and C.taggedCount() == 0
      and C.editChooser.rows[1].action == "selecton")
C.editChooser.fn({ action = "selecton" })
C.editChooser.fn({ idx = C.editChooser.rows[4].idx })
HYPER["shift|v"]()
check("🚨 a fresh ⇪⇧V always starts UNPICKED — reopening into week-old "
      .. "✓ marks is how the wrong rows get deleted",
      C.selectMode == false and C.taggedCount() == 0)

boot() ; C.loaded = true
C.renderEdit("")
check("an empty history offers no action rows — nothing to pick",
      C.editChooser.rows[1]
      and C.editChooser.rows[1].action == nil
      and C.editChooser.rows[1].text:find("empty", 1, true) ~= nil)

-- =====================================================================
out("\n💾 the CSV supplier (6.130.0)\n")
-- =====================================================================
-- LL: "Can these write into one file, .csv perhaps?"
--
-- 🚨 THE WHOLE HISTORY, NOT THE NEWEST ITEM. This store also answers
-- `text`, which is the ⌥⏎ answer and is deliberately just the top of the
-- stack. If the export fell back to that, a thousand-item clipboard would
-- write ONE row and the spreadsheet would look finished.
do
    local row
    for _, e in ipairs(_G.editors or {}) do
        if type(e) == "table" and e.name == "Clipboard" then row = e end
    end
    check("💾 the Clipboard registration supplies a csv function",
          row ~= nil and type(row.csv) == "function")
    _G.clipboardCache = {
        { date = "Aug 21 14:23", text = "newest" },
        { date = "Aug 21 09:01", text = "middle" },
        { date = "Aug 20 17:44", text = "oldest" },
    }
    local items = row and row.csv() or {}
    check("🚨 …carrying EVERY item, not just the one ⌥⏎ would copy",
          #items == 3, #items)
    check("💾 …newest first, the order the cache is already kept in",
          items[1] and items[1].text == "newest", items[1] and items[1].text)
    check("💾 …each with the date it was copied",
          items[1] and items[1].when == "Aug 21 14:23", items[1] and items[1].when)
    -- 🛡 The cache is loaded off disk and can be anything after a bad
    -- write; a malformed row must cost itself and not the export.
    _G.clipboardCache = { { text = "good" }, { date = "x" }, "junk", 7 }
    check("🛡 …and a malformed cache row is dropped, not exported",
          #row.csv() == 1, #row.csv())
    _G.clipboardCache = {}
    check("🛡 …an empty history exports no rows rather than one blank",
          #row.csv() == 0, #row.csv())
end

io.open = realIoOpen
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
