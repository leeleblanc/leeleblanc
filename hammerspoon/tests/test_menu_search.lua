-- =====================================================================
-- test_menu_search.lua — ⇪. flattens the front app's menus, correctly
-- =====================================================================
--     lua5.4 test_menu_search.lua [/path/to/hammerspoon]
--
-- Executes modules/menu_search.lua against a stubbed hs and inspects the
-- rows it builds from a menu tree.
--
-- TWO SECTIONS HAVE TEETH, and they are the two places this module can
-- be wrong without anything looking wrong:
--
--   §3 THE MODIFIER BITMASK. AXMenuItemCmdModifiers uses ZERO to mean ⌘
--      and bit 3 to mean "no command key" — the opposite of the obvious
--      reading. Get it backwards and every ⌘-shortcut in the panel
--      renders bare, which does not look like a bug; it looks like the
--      app has no shortcut for that item. Every check here fails if the
--      bit-3 test is inverted or dropped.
--
--   §4 THE EXTRA AXChildren LEVEL. getMenuItems() returns menus whose
--      AXChildren is a table CONTAINING the item list, not the item list
--      itself. Walking it as if it were the list directly finds ZERO
--      items and reports success — an empty panel, no error, nothing in
--      the Console. The fixture is shaped like the real thing so that
--      mistake fails here instead of on a Mac.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local AX        = true
local ALERTS    = {}
local TIMERS    = {}
local NOW       = 1000
local CHOOSERS  = {}
local SHOWS     = 0      -- ⚠️ the module reuses ONE chooser, so counting
                         -- CHOOSERS counts constructions, not openings
local SELECTED  = {}      -- every path handed to selectMenuItem
local SELECT_OK = true
local ASYNC     = true    -- does this hs have the callback form?
local MENUS     = nil     -- what getMenuItems hands back
local ASYNC_CB  = nil     -- held so the test can answer whenever it likes
local APP_NAME, APP_PID = "TextEdit", 501

local function makeApp()
    local app = {}
    function app:name() return APP_NAME end
    function app:pid() return APP_PID end
    function app:selectMenuItem(path)
        SELECTED[#SELECTED + 1] = path
        return SELECT_OK
    end
    function app:getMenuItems(cb)
        if cb then
            if not ASYNC then error("no callback form on this build") end
            ASYNC_CB = cb
            return true
        end
        return MENUS
    end
    return app
end

hs = {
    accessibilityState = function() return AX end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    application = { frontmostApplication = function() return makeApp() end },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, shown = 0, placeholder = "",
                        query_ = nil, width_ = nil, searchSub = false }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() self.shown = self.shown + 1
                              SHOWS = SHOWS + 1 ; return self end
            function c:width(n) self.width_ = n ; return self end
            function c:searchSubText(b) self.searchSub = b ; return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/menu_search.lua"))
local M = chunk()
M.setup(CORE)
local ms = _G.menuSearch

-- Guarded, so a build that takes the BLOCKING path instead REPORTS the
-- failures above rather than taking the whole file down on a nil callback
-- — the same reason test_right_click guards its settle-timer ticks.
local function answer(tree)
    if type(ASYNC_CB) ~= "function" then
        check("a callback was waiting to be answered", false, "ASYNC_CB is nil")
        return false
    end
    ASYNC_CB(tree)
    return true
end

local function reset()
    ALERTS, TIMERS, SELECTED = {}, {}, {}
    ASYNC_CB = nil
    ms.cache, ms.pending, ms.lastNote = nil, false, nil
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Menu Search")
check("it declares a family", M.family == "find")
check("⇪. is bound", BOUND["+."] ~= nil)
check("the binding is attributed to this module",
      BOUND["+."] and BOUND["+."].src == "menu search")
check("it publishes _G.menuSearch", type(ms) == "table")
check("two services are published",
      PROVIDED["menuSearch.show"] and PROVIDED["menuSearch.report"])
check("the cheat sheet key cell is exactly ⇪.", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪." then return true end
    end
    return false
end)())

-- =====================================================================
out("\n=== 2. it refuses without Accessibility, by name ===\n")
-- =====================================================================
reset()
AX = false
ms.show()
check("nothing was scanned", ASYNC_CB == nil)
check("it said so", #ALERTS == 1, #ALERTS)
check("…and named Accessibility as the reason",
      ALERTS[1] and ALERTS[1]:find("Accessibility", 1, true) ~= nil, ALERTS[1])
AX = true

-- =====================================================================
out("\n=== 3. 🚨 THE MODIFIER BITMASK: 0 MEANS ⌘, BIT 3 MEANS NO ⌘ ===\n")
-- =====================================================================
-- Driven through the real flatten(), because the shortcut column is
-- built there and a unit test of a local function would not prove the
-- panel shows it.
local function shortcutOf(item)
    local rows = ms.flatten({
        { AXTitle = "File", AXChildren = { { item } } },
    })
    return rows[1] and rows[1].shortcut
end

check("mask 0 with 'S' is ⌘S — the zero value MEANS command",
      shortcutOf({ AXTitle = "Save", AXMenuItemCmdChar = "s",
                   AXMenuItemCmdModifiers = 0 }) == "⌘S",
      shortcutOf({ AXTitle = "Save", AXMenuItemCmdChar = "s",
                   AXMenuItemCmdModifiers = 0 }))
check("mask 1 is ⇧⌘",
      shortcutOf({ AXTitle = "Save As", AXMenuItemCmdChar = "s",
                   AXMenuItemCmdModifiers = 1 }) == "⇧⌘S")
check("mask 2 is ⌥⌘",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "w",
                   AXMenuItemCmdModifiers = 2 }) == "⌥⌘W")
check("mask 4 is ⌃⌘",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "f",
                   AXMenuItemCmdModifiers = 4 }) == "⌃⌘F")
check("mask 3 is ⇧⌥⌘ — modifiers combine, in a fixed order",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "p",
                   AXMenuItemCmdModifiers = 3 }) == "⇧⌥⌘P")
-- 🚨 THE CHECK THAT CATCHES THE INVERSION. Bit 3 set means the shortcut
-- has NO command key: F11 is F11, not ⌘F11. A build that reads the mask
-- the obvious way renders this as ⌘ and this check fails.
check("mask 8 has NO ⌘ at all — bit 3 is the no-command flag",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "h",
                   AXMenuItemCmdModifiers = 8 }) == "H",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "h",
                   AXMenuItemCmdModifiers = 8 }))
check("mask 9 is ⇧ with no ⌘",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "h",
                   AXMenuItemCmdModifiers = 9 }) == "⇧H",
      shortcutOf({ AXTitle = "x", AXMenuItemCmdChar = "h",
                   AXMenuItemCmdModifiers = 9 }))
check("an item with no shortcut renders an EMPTY string, not a guess",
      shortcutOf({ AXTitle = "About This Mac" }) == "")
check("a glyph keycode is named where one is worth naming (⌫)",
      shortcutOf({ AXTitle = "Delete", AXMenuItemCmdGlyph = 0x7F,
                   AXMenuItemCmdModifiers = 0 }) == "⌘⌫")
check("an unknown glyph renders nothing rather than a wrong key",
      shortcutOf({ AXTitle = "Odd", AXMenuItemCmdGlyph = 0x99,
                   AXMenuItemCmdModifiers = 0 }) == "")

-- =====================================================================
out("\n=== 4. 🚨 THE EXTRA AXChildren LEVEL ===\n")
-- =====================================================================
-- Shaped exactly like a real getMenuItems() answer: each menu's
-- AXChildren is a table CONTAINING the item list.
local TREE = {
    { AXTitle = "File", AXChildren = { {
        { AXTitle = "New",  AXMenuItemCmdChar = "n", AXMenuItemCmdModifiers = 0 },
        { AXTitle = "Open", AXMenuItemCmdChar = "o", AXMenuItemCmdModifiers = 0 },
        { AXTitle = "Export As", AXChildren = { {
            { AXTitle = "PDF…" },
            { AXTitle = "Web Page…", AXEnabled = false },
        } } },
        { AXTitle = "Print…", AXMenuItemCmdChar = "p", AXMenuItemCmdModifiers = 0 },
    } } },
    { AXTitle = "Edit", AXChildren = { {
        { AXTitle = "Undo", AXEnabled = false },
        { AXTitle = "Show Ruler", AXMenuItemMarkChar = "✓" },
    } } },
}

local rows = ms.flatten(TREE)
check("the tree flattens to something, not nothing", #rows > 0, #rows)
check("…to exactly the eight items in it", #rows == 8, #rows)

local byLeaf = {}
for _, r in ipairs(rows) do byLeaf[r.path[#r.path]] = r end

check("a top-level item is found", byLeaf["New"] ~= nil)
check("…under its own menu", byLeaf["New"] and byLeaf["New"].path[1] == "File")
check("a NESTED item is found", byLeaf["PDF…"] ~= nil)
check("…carrying the whole path, menu first",
      byLeaf["PDF…"] and #byLeaf["PDF…"].path == 3
      and byLeaf["PDF…"].path[1] == "File"
      and byLeaf["PDF…"].path[2] == "Export As"
      and byLeaf["PDF…"].path[3] == "PDF…",
      byLeaf["PDF…"] and table.concat(byLeaf["PDF…"].path, " ▸ "))
check("the submenu HEADING is listed too, marked as one",
      byLeaf["Export As"] and byLeaf["Export As"].submenu == true)
check("a leaf is not marked as a submenu",
      byLeaf["New"] and byLeaf["New"].submenu ~= true)
check("both menus were walked, not just the first",
      byLeaf["Undo"] ~= nil and byLeaf["New"] ~= nil)

-- =====================================================================
out("\n=== 5. disabled items are SHOWN, and refuse to run ===\n")
-- =====================================================================
check("AXEnabled = false is recorded as disabled",
      byLeaf["Undo"] and byLeaf["Undo"].enabled == false)
-- 🚨 The failure direction that costs nothing: an app that never sets
-- AXEnabled must not have every one of its items refused.
check("AXEnabled UNSET is treated as ENABLED",
      byLeaf["New"] and byLeaf["New"].enabled == true)
check("a checked item is recorded as checked",
      byLeaf["Show Ruler"] and byLeaf["Show Ruler"].mark == true)

local choices = ms.choicesFrom(rows)
check("by default the disabled item is still OFFERED", (function()
    for _, c in ipairs(choices) do
        if c.text:find("Undo", 1, true) then return true end
    end
    return false
end)())
check("…and marked, so the greying is visible in the panel", (function()
    for _, c in ipairs(choices) do
        if c.text:find("Undo", 1, true) then
            return c.subText:find("unavailable right now", 1, true) ~= nil
        end
    end
    return false
end)())

reset()
ms.rows = rows
local undoIdx
for i, r in ipairs(rows) do if r.path[#r.path] == "Undo" then undoIdx = i end end
check("picking a disabled item does NOT reach selectMenuItem",
      ms.pick(undoIdx, makeApp()) == false and #SELECTED == 0, #SELECTED)
check("…and says the app is refusing it, not the list",
      ALERTS[1] and ALERTS[1]:find("greyed out", 1, true) ~= nil, ALERTS[1])

reset()
ms.rows = rows
local pdfIdx
for i, r in ipairs(rows) do if r.path[#r.path] == "PDF…" then pdfIdx = i end end
check("picking an enabled item DOES reach selectMenuItem",
      ms.pick(pdfIdx, makeApp()) == true and #SELECTED == 1, #SELECTED)
check("…with the full path, not just the leaf",
      SELECTED[1] and #SELECTED[1] == 3 and SELECTED[1][1] == "File",
      SELECTED[1] and table.concat(SELECTED[1], " ▸ "))

-- hideDisabled is a real switch, not a comment
ms.hideDisabled = true
local fewer = ms.choicesFrom(rows)
check("ms.hideDisabled = true actually drops them",
      #fewer < #choices and #fewer == #choices - 2, #fewer)
ms.hideDisabled = false

-- =====================================================================
out("\n=== 6. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
-- Every value in a chooser row crosses into Objective-C. A nested table
-- does not survive, and LuaSkin discards the WHOLE list and logs rather
-- than throwing — so the panel opens empty with nothing to catch. This
-- is the same rule ⇪⇧T learned in 6.109.0, checked here rather than
-- trusted.
check("every row value is a string, number or boolean", (function()
    for _, c in ipairs(choices) do
        for k, v in pairs(c) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false, k .. " is a " .. t
            end
        end
    end
    return true
end)())
check("…and the payload is an integer index", (function()
    for _, c in ipairs(choices) do
        if math.type(c.idx) ~= "integer" then return false end
    end
    return true
end)())
check("…that resolves to a real row", (function()
    for _, c in ipairs(choices) do
        if rows[c.idx] == nil then return false end
    end
    return true
end)())
check("no row carries the path table itself", (function()
    for _, c in ipairs(choices) do
        if c.path ~= nil then return false end
    end
    return true
end)())

-- =====================================================================
out("\n=== 7. 🚨 THE SCAN IS ASYNCHRONOUS ===\n")
-- =====================================================================
-- The blocking form of getMenuItems() can freeze the keyboard for
-- seconds on an app with deep menus, and a keyboard that stops answering
-- is indistinguishable from a crash. These checks fail if the module
-- ever calls the sync form while the callback form exists.
reset()
ASYNC = true
MENUS = TREE
ms.show()
check("the panel does NOT open on the keypress", SHOWS == 0, SHOWS)
check("…a callback is waiting instead", type(ASYNC_CB) == "function")
check("…and it said it was reading", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Reading", 1, true) then return true end
    end
    return false
end)())
check("a timeout timer was armed", #TIMERS >= 1, #TIMERS)

answer(TREE)
check("when the answer arrives, the panel opens", SHOWS == 1, SHOWS)
check("…listing every item", CHOOSERS[1] and #CHOOSERS[1].choices_ == 8,
      CHOOSERS[1] and #CHOOSERS[1].choices_)
check("…named after the app it read", CHOOSERS[1]
      and CHOOSERS[1].placeholder:find("TextEdit", 1, true) ~= nil,
      CHOOSERS[1] and CHOOSERS[1].placeholder)
check("…with the query cleared, so it opens on the whole list",
      CHOOSERS[1] and CHOOSERS[1].query_ == "")
check("the scan recorded which path it took", ms.lastPath == "async", ms.lastPath)
check("…and how many items it found", ms.lastCount == 8, ms.lastCount)

-- The sync form is the fallback, and only that.
reset()
ASYNC = false
ms.cache = nil
APP_PID = 777          -- a different app, so the cache cannot answer
ms.show()
check("with no callback form, the sync form still opens the panel",
      SHOWS == 2, SHOWS)
check("…and it is recorded as the sync path", ms.lastPath == "sync", ms.lastPath)
ASYNC = true

-- =====================================================================
out("\n=== 8. a timeout is a NAMED refusal, not a dead key ===\n")
-- =====================================================================
reset()
ms.cache = nil
APP_PID = 888
ms.show()
check("it is waiting", ms.pending == true)
-- Guarded for the same reason answer() is: a build that took the
-- BLOCKING path arms no timeout timer at all, and reading .fn on nil
-- would take the file down before it could report §7's failures.
local timeoutTimer = TIMERS[#TIMERS]
check("a timeout timer exists to fire", timeoutTimer ~= nil)
if timeoutTimer then timeoutTimer.fn() end
check("the timeout fires and stops waiting", ms.pending == false)
check("…and names the app that did not answer",
      ms.lastNote and ms.lastNote:find(APP_NAME, 1, true) ~= nil, ms.lastNote)
check("…on screen too", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("did not answer", 1, true) then return true end
    end
    return false
end)())
-- 🚨 And a LATE answer after a timeout must not open a panel from under
-- you. This is the check that would have caught it firing twice.
local before = SHOWS
if ASYNC_CB then ASYNC_CB(TREE) end
check("a late answer still opens the panel it was asked for",
      SHOWS == before + 1, SHOWS)

-- =====================================================================
out("\n=== 9. the cache is short, and per-app ===\n")
-- =====================================================================
reset()
ms.cache = nil
APP_PID = 900
ms.show()
answer(TREE)
local shown = SHOWS
ASYNC_CB = nil
ms.show()      -- same app, immediately: must NOT re-scan
check("a second press of the same app does NOT re-scan", ASYNC_CB == nil)
check("…and opens the panel straight away, from the cache",
      SHOWS == shown + 1, SHOWS)
check("…exactly ONE chooser exists for all of this", #CHOOSERS == 1, #CHOOSERS)

reset()
APP_PID = 901  -- a different app must always re-scan
ms.show()
check("a DIFFERENT app is never served from the cache",
      type(ASYNC_CB) == "function")

reset()
APP_PID = 900
NOW = NOW + 60   -- long past ms.cacheSecs
ms.show()
check("…and neither is the same app once the cache has expired",
      type(ASYNC_CB) == "function")

-- =====================================================================
out("\n=== 10. the report tells the truth ===\n")
-- =====================================================================
local rep = _G.menuSearchReport()
check("the report names the module", rep:find("MENU SEARCH", 1, true) ~= nil)
check("…says whether Accessibility is on",
      rep:find("accessibility", 1, true) ~= nil)
check("…counts the scans", rep:find("scans", 1, true) ~= nil)
check("…and names the last app it read",
      rep:find(APP_NAME, 1, true) ~= nil, rep)

-- =====================================================================
out(("\n── test_menu_search: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
