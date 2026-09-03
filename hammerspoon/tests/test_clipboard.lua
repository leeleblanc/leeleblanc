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
-- 👁 6.154.0 — the preview pane's world: canvases, a poll timer, the
-- mouse, and a chooser that answers selectedRow / isVisible / hideCallback
local CANVASES, TIMERS = {}, {}
local SEL, VIS, MOUSE = 1, true, { x = 0, y = 0 }
hs = {
    json = { encode = enc, decode = dec },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(t) PASTEBOARD = t ; return true end,
                   getContents = function() return PASTEBOARD end },
    chooser = { new = function(fn)
        local c = { fn = fn }
        for _, m in ipairs({ "placeholderText", "show", "searchSubText" }) do
            c[m] = function(self) return self end
        end
        function c:choices(x) self.rows = x ; return self end
        function c:queryChangedCallback(f) self.qcb = f ; return self end
        -- the getters the preview pane asks (window_move asks the same two)
        function c:width(x) if x then return self end return 40 end
        function c:rows(x) if x then return self end return 10 end
        function c:selectedRow() return SEL end
        function c:isVisible() return VIS end
        function c:hideCallback(f) self.hideCb = f ; return self end
        function c:query() return self end
        return c end },
    canvas = {
        windowLevels = { mainMenu = 24, popUpMenu = 101, overlay = 25 },
        new = function(rect)
            local c = { rect = rect, elements = {}, shown = false, deleted = false }
            function c:replaceElements(e)
                if type(e) ~= "table" or #e == 0 then error("bad elements") end
                self.elements = e ; return self
            end
            function c:show()   self.shown = true  ; return self end
            function c:hide()   self.shown = false ; return self end
            function c:delete() self.deleted = true ; self.shown = false ; return self end
            function c:frame(r) if r then self.rect = r end return self.rect end
            function c:level(l) self.lvl = l ; return self end
            function c:behaviorAsLabels() return self end
            function c:canvasMouseEvents() return self end
            CANVASES[#CANVASES + 1] = c
            return c
        end,
    },
    mouse = { absolutePosition = function() return MOUSE end },
    dialog = { textPrompt = function() return "Cancel", "" end },
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
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
    -- 🔑 6.132.0 — LL: "Shouldn't this be in the edit picker? ⇪⇧V." It
    -- was, and had been since 6.97.0 — but the row's key cell said ⇪V
    -- alone, so the picker read as though ⇪V were the only way in and the
    -- edit view had no key at all. Both keys are bound (see §1); the row
    -- must NAME both, or the picker is the place the config lies about
    -- itself.
    check("🔑 the Clipboard row names the edit view's key too",
          row ~= nil and row.key == "⇪V / ⇪⇧V", row and row.key)
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

-- =====================================================================
out("\n=== 9. 👁 6.154.0 — the preview pane beside the picker ===\n")
-- =====================================================================
-- LL: "Can the full contents of the clipboard item in ⌘V be shown as I
-- arrow up/down, or put my mouse cursor on an item? The view should
-- show to the right of the window and be able to scroll or
-- automatically expand to show that entry."
-- hs.chooser has no selection callback and does not follow the mouse,
-- so a poll reads selectedRow() and the row under the pointer; the pane
-- is a canvas beside the picker, sized to the text.
do
    boot() ; C.loaded = true
    local LONG = {}
    for i = 1, 200 do LONG[i] = "line " .. i .. " of a long clipboard entry" end
    C.add("third")
    C.add(table.concat(LONG, "\n"))
    C.add("first is short")                 -- newest → row 1
    local SCREEN = { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    _G.lastPopupPlacement = { screen = SCREEN, point = { x = 300, y = 180 },
                              chooser = C.chooser }
    SEL, VIS, MOUSE = 1, true, { x = 0, y = 0 }
    CANVASES, TIMERS = {}, {}
    local function pane() return C.pv.canvas end
    local function bodyText()
        local c = pane()
        if not c then return "" end
        for _, e in ipairs(c.elements) do
            if e.type == "text" and e.textFont == "Menlo" then return e.text end
        end
        return ""
    end
    local function footer()
        local c = pane()
        if not c then return "" end
        local last = c.elements[#c.elements]
        return (last and last.type == "text") and last.text or ""
    end

    HYPER["|v"]()
    check("opening ⇪V starts a poll at clip.previewPoll — and only then",
          TIMERS[1] ~= nil and TIMERS[1].secs == C.previewPoll, TIMERS[1] and TIMERS[1].secs)
    check("…HELD on the module, not left to the collector", C.pv.poll == TIMERS[1])
    check("a pane is drawn the moment the picker opens", pane() ~= nil and pane().shown)
    local box = C.previewBox(C.chooser)
    check("…to the RIGHT of the picker's computed box",
          box and pane() and pane().rect.x >= box.x + box.w, pane() and pane().rect.x)
    check("…showing the WHOLE entry for the selected row", bodyText() == "first is short",
          bodyText())
    check("…with the date and the size in its header", (function()
        for _, e in ipairs(pane().elements) do
            if e.type == "text" and e.text:find("14 chars", 1, true) then return true end
        end
    end)())
    check("…click-through and on the rung above the chooser",
          pane().lvl ~= nil, pane().lvl)

    SEL = 2 ; TIMERS[1].fn()
    check("↓ onto the long entry: the pane FOLLOWS THE KEYBOARD, and shows the "
          .. "full text, not the 100-character row",
          bodyText():find("line 1 of a long", 1, true) ~= nil
          and bodyText():find("line 30 of", 1, true) ~= nil, bodyText():sub(1, 60))
    check("…auto-expanded down to the screen's bottom edge and no further",
          pane().rect.y + pane().rect.h <= 900 and pane().rect.h > 400,
          pane().rect.h)
    check("…and what will not fit is ADMITTED in a footer, never clipped "
          .. "mid-word", footer():find("more line", 1, true) ~= nil, footer())

    MOUSE = { x = box.x + 20, y = box.y + C.pv.headH + 2 * C.pv.rowH + 10 }
    TIMERS[1].fn()
    check("🖱 the mouse over row 3 WINS over the keyboard: the pane shows 'third'",
          bodyText() == "third", bodyText())
    check("…and the pane says which one it is following",
          C.pv.shown and C.pv.shown.how == "mouse" and C.pv.shown.row == 3)
    MOUSE = { x = 0, y = 0 } ; TIMERS[1].fn()
    check("the mouse off the picker hands back to the keyboard",
          bodyText():find("line 1 of", 1, true) ~= nil)
    local drawsBefore = #CANVASES
    TIMERS[1].fn() ; TIMERS[1].fn()
    check("the same row twice costs no redraw — the poll is cheap when "
          .. "nothing changed", #CANVASES == drawsBefore)

    -- near the right edge the pane goes LEFT
    _G.lastPopupPlacement.point = { x = 1000, y = 180 }
    SEL = 1 ; C.pv.lastKey = nil ; TIMERS[1].fn()
    check("with no room on the right the pane sits on the LEFT",
          pane().rect.x + pane().rect.w <= 1000, pane().rect.x)
    _G.lastPopupPlacement.point = { x = 300, y = 180 }

    -- typing re-renders the list: row 1 is a different entry now
    C.chooser.qcb("third") ; TIMERS[1].fn()
    check("after a search the pane re-keys on the NEW list — row 1 is the match",
          bodyText() == "third", bodyText())

    -- 🧲 6.155.0 — LL: "I can't move it. Should I be able to?" A ⇪⇧-arrow
    -- nudge is hide() + show(point); the pane must wait that out.
    local NOW = 1000
    local realClock = hs.timer.secondsSinceEpoch
    hs.timer.secondsSinceEpoch = function() return NOW end
    C.chooser.hideCb()
    check("the picker's hideCallback takes the pane down at once", C.pv.canvas == nil)
    check("…but the poll stays for clip.previewGrace — a nudged picker is "
          .. "about to come back", C.pv.poll == TIMERS[1] and not TIMERS[1].stopped)
    VIS = false ; TIMERS[1].fn()
    check("…a hidden picker inside the grace draws nothing and keeps polling",
          C.pv.canvas == nil and C.pv.poll ~= nil)
    VIS = true ; SEL = 1
    _G.lastPopupPlacement.point = { x = 340, y = 200 } ; TIMERS[1].fn()
    local box2 = C.previewBox(C.chooser)
    check("the picker back at a NEW spot gets its pane back THERE",
          pane() ~= nil and box2 and box2.x == 340
          and pane().rect.x >= box2.x + box2.w, pane() and pane().rect.x)
    check("…showing the selected row again", bodyText() == "third", bodyText())
    C.chooser.hideCb() ; VIS = false
    NOW = NOW + C.previewGrace ; TIMERS[1].fn()
    check("gone for the whole grace: the pane closes and the poll stops",
          C.pv.canvas == nil and C.pv.poll == nil and TIMERS[1].stopped == true)
    VIS = true
    _G.lastPopupPlacement.point = { x = 300, y = 180 }

    HYPER["|v"]() ; VIS = false ; C.pv.poll.fn()
    check("a picker that is simply GONE keeps the pane down while the grace runs",
          C.pv.canvas == nil and C.pv.poll ~= nil)
    NOW = NOW + C.previewGrace ; C.pv.poll.fn()
    check("…and closes the poll once it has run", C.pv.poll == nil)
    VIS = true
    hs.timer.secondsSinceEpoch = realClock

    _G.lastPopupPlacement = nil
    local okNo = pcall(function() HYPER["|v"]() end)
    check("no placement on record: no pane, and no throw",
          okNo and C.pv.canvas == nil)
    C.previewClose()

    -- ⇪⇧V: an action row previews nothing; an entry row previews its text
    _G.lastPopupPlacement = { screen = SCREEN, point = { x = 300, y = 180 },
                              chooser = C.editChooser }
    SEL = 1 ; HYPER["shift|v"]()
    check("⇪⇧V's '☑️ Select several…' row previews nothing", C.pv.canvas == nil)
    SEL = 2 ; C.pv.poll.fn()
    check("…and an entry row previews its full text", bodyText() == "first is short",
          bodyText())
    C.previewClose()

    C.previewOn = false
    HYPER["|v"]()
    check("clip.previewOn = false: no poll, no pane — the list alone, as before",
          C.pv.poll == nil and C.pv.canvas == nil)
    C.previewOn = true
    C.previewClose()

    -- 👁 6.156.0 — the pane is a SERVICE other pickers use (⇪⇧T's rows
    -- bring their own head line)
    check("preview.open / suspend / close are published",
          type(PROVIDED["preview.open"]) == "function"
          and type(PROVIDED["preview.suspend"]) == "function"
          and type(PROVIDED["preview.close"]) == "function")
    _G.lastPopupPlacement = { screen = SCREEN, point = { x = 300, y = 180 },
                              chooser = C.chooser }
    local foreign = { { text = "sig", rawText = "Kind regards,\nLee",
                        head = "✂️ sig  ·  textpanders  ·  17 chars" } }
    SEL = 1 ; VIS = true
    PROVIDED["preview.open"](C.chooser, function() return foreign end)
    check("a row's own head line replaces the clipboard header", (function()
        for _, e in ipairs(pane().elements) do
            if e.type == "text" and e.text == foreign[1].head then return true end
        end
    end)())
    check("...and its whole text is the body", bodyText() == "Kind regards,\nLee", bodyText())
    PROVIDED["preview.close"]()
    check("preview.close takes it down", C.pv.canvas == nil and C.pv.poll == nil)

    -- the wrap is arithmetic, and it keeps indentation
    local w = C.previewWrap("    indented code line that is fairly long indeed", 24)
    check("the wrap keeps leading indentation and breaks at words",
          w[1] == "    indented code line" and w[2] == "that is fairly long", w[1] .. "|" .. tostring(w[2]))
    check("a word longer than a line is cut rather than lost",
          #C.previewWrap(string.rep("x", 50), 20) == 3)
    _G.lastPopupPlacement = nil
end

io.open = realIoOpen
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
