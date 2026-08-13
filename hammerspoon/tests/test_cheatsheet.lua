SHOW_THROWS = false
-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
-- HS   = the config being tested (init.lua + modules/)
-- HERE = this tests folder, which is where the extracted fixtures live
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local HS   = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
             or ((os.getenv("HOME") or ".") .. "/.hammerspoon")
-- Harness: runs the REAL §1.6 code against a stubbed hs, then measures
-- what it actually draws. Nothing here is mocked at the layout level.
local SCR = { x = 0, y = 0, w = 3840, h = 2160 }
local drawn = {}          -- last element list handed to the canvas
local canvasRect          -- rect the canvas was created with
local shown, deleted = 0, 0
local hotkeysEnabled, hotkeysDisabled = 0, 0
local tapRunning = false
local MOUSE = { x = 0, y = 0 }
local BOUND = {}          -- every hs.hotkey.bind the shipped file makes
local CHOOSERS = {}       -- every hs.chooser the shipped file builds

hs = {
  canvas = {
    windowLevels = { overlay = 102 },
    new = function(rect)
      canvasRect = rect
      local c = {}
      function c:replaceElements(els) drawn = els; return c end
      function c:appendElements(els) drawn = els; return c end
      -- SHOW_THROWS models the AppKit assertion seen in the wild: an
      -- exception raised inside ANOTHER app's remote view while our
      -- window is ordered on screen. See _G.showCanvasSafely.
      function c:show()
        if SHOW_THROWS then error("NSInternalInconsistencyException: remote view") end
        shown = shown + 1; return c
      end
      function c:delete() deleted = deleted + 1; return c end
      function c:level() return c end
      function c:behaviorAsLabels() return c end
      return c
    end,
  },
  hotkey = {
    new = function(mods, key, pressed, released, repeatfn)
      -- hotkey.new is the SCROLLING panel's own keys, and only those. A
      -- new key appearing here is a mistake worth failing on.
      local valid = { escape=1, up=1, down=1, pageup=1, pagedown=1, home=1, ["end"]=1 }
      assert(valid[key], "unexpected key bound: " .. tostring(key))
      local hk = { key = key, fire = pressed, repeatfn = repeatfn }
      function hk:enable() hotkeysEnabled = hotkeysEnabled + 1; return hk end
      function hk:disable() hotkeysDisabled = hotkeysDisabled + 1; return hk end
      return hk
    end,
    -- 6.44.11 — the shipped §1.6 binds ⇪/ ⇪= ⇪- ⇪⇧= at load time via
    -- hotkey.bind. tests/block_test.lua, the hand-extracted slice this
    -- suite used to run, had drifted and no longer contained those calls
    -- — so the stub never needed a bind and the real binding was untested.
    -- Recorded rather than ignored, so the assertions below can check it.
    bind = function(mods, key, pressed, released, repeatfn)
      BOUND[#BOUND + 1] = { mods = mods, key = key, fire = pressed }
      return { enable = function(s) return s end, disable = function(s) return s end }
    end,
  },
  eventtap = {
    new = function(types, fn)
      local t = { fn = fn }
      function t:start() tapRunning = true; return t end
      function t:stop() tapRunning = false; return t end
      return t
    end,
    event = {
      types = { scrollWheel = 22 },
      properties = {
        scrollWheelEventIsContinuous     = "cont",
        scrollWheelEventDeltaAxis1       = "line",
        scrollWheelEventPointDeltaAxis1  = "px",
      },
    },
  },
  mouse = { absolutePosition = function() return MOUSE end },
  alert = { show = function() end },
  json = { decode = function() return {} end, encode = function() return "[]" end },
  -- 6.44.11 — the shipped file builds two hs.chooser pickers at load time
  -- (⇪- remove a custom entry, ⇪⇧= edit one). The old slice had neither,
  -- so neither was ever exercised. They are recorded, not swallowed.
  chooser = {
    new = function(fn)
      local c = { onSelect = fn }
      function c:choices(v) if v then self.rows = v; return self end return self.rows end
      function c:placeholderText(t) self.placeholder = t; return self end
      function c:searchSubText(b) self.subText = b; return self end
      function c:width(w) self.w = w; return self end
      function c:rows(n) self.nrows = n; return self end
      function c:bgDark(b) self.dark = b; return self end
      function c:fgColor() return self end
      function c:subTextColor() return self end
      function c:show() shown = shown + 1; return self end
      function c:hide() return self end
      function c:query(q) if q ~= nil then self.q = q; return self end return self.q end
      CHOOSERS[#CHOOSERS + 1] = c
      return c
    end,
  },
  dialog = { textPrompt = function() return "Cancel", "" end },
  pasteboard = { getContents = function() return "" end,
                 setContents = function() return true end },
  timer = { doAfter = function() return { stop = function() end } end,
            secondsSinceEpoch = function() return 1 end },
  fs = { attributes = function() end, mkdir = function() end },
  configdir = "/tmp/hs-test",
}
logsDir = "/tmp/hs-test"
function adoptLegacyFile() end
function warnWriteFailed() end
function resolveBaseScreen()
  return { frame = function() return SCR end }
end
_G.choosers = {}          -- init.lua owns this table; the shipped file fills it
_G.customShortcuts = {}
_G.moduleStatus = {}
_G.moduleCheatsheets = {
  { title = "👀 APP PEEK", order = 7, entries = { { "⇪P", "Hide frontmost app" } } },
  { title = "🔄 WINDOW SWITCHER (⌥Tab — Windows-style)", order = 8,
    entries = { { "⌥Tab", "Walk every open window" } } },
  { title = "☁️ BACKUP (automatic)", order = 15,
    entries = { { "daily 5:00 PM", "~/.hammerspoon → OneDrive/Backups" } } },
  { title = "🪟 WINDOW ARRANGER", order = 6,
    entries = { { "⇪← / ⇪→", "Left / right half of screen" } } },
  { title = "⌨️ COMMAND HISTORY", order = 12,
    entries = { { "⇪H", "Search your shell history" } } },
  { title = "👁 APP MONITOR (automatic)", order = 1,
    entries = { { "Enter", "Spawn (relaunch) or End" } } },
  { title = "📁 FILE TRACKER", order = 10,
    entries = { { "⇪F", "Rename / move / copy history" } } },
  { title = "✏️ AUTOCORRECT", order = 13,
    entries = { { "⇪S", "Toggle on/off" } } },
  { title = "📊 ACTIVITY TRACKER", order = 4, entries = { { "⇪0", "Today's totals" } } },
  { title = "📦 APP UPDATES", order = 9, entries = { { "⇪U", "Which apps are behind" } } },
  { title = "📄 DOCUMENT WATCHER (experimental)", order = 11,
    entries = { { "⇪⇧W", "Documents worked on today" } } },
}

local function wheelEvent(props)
  return { getProperty = function(_, k) return props[k] end }
end

_G.diag = { say = function() end, warn = function() end, mark = function() end,
            err = function() end, verbose = false, trail = {}, errors = {}, marks = {} }
-- 6.44.11 — THIS NOW RUNS THE SHIPPED FILE, NOT A COPY OF IT. Until §1.6
-- moved out of init.lua, the only way to test it was tests/block_test.lua,
-- a hand-extracted slice. Slices drift: that one was no longer even a
-- verbatim substring of init.lua, so every check here was passing against
-- code that was not the code being shipped. core/cheatsheet.lua is the
-- real file, loaded the same way init.lua loads it.
local CS_PATH = HS .. "/core/cheatsheet.lua"
local csChunk = assert(loadfile(CS_PATH),
                       "cannot load the shipped cheat sheet: " .. CS_PATH)
local CS = csChunk()({
  logsDir           = logsDir,
  panelAlpha        = 0.90,
  popupScreenKeys   = { mods = { "cmd", "alt", "ctrl" } },
  resolveBaseScreen = resolveBaseScreen,
  showPopup         = function(c) if c and c.show then c:show() end end,
  warnWriteFailed   = warnWriteFailed,
  adoptLegacyFile   = adoptLegacyFile,
})

-- ---------------------------------------------------------------- utils
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; print(("  ✅ %s"):format(name))
  else fail = fail + 1; print(("  ❌ %s — %s"):format(name, tostring(detail or ""))) end
end
local function ulen(s) return utf8.len(s) or #s end
local function texts()
  local t = {}
  for _, e in ipairs(drawn) do if e.type == "text" then table.insert(t, e) end end
  return t
end
local function st() return _G.cheatSheetState end

-- ================================================================ TESTS
print("\n=== 1. Single column, vertical, fits the screen ===")
CS.show()
local S = st()
check("one column only (no colGap / no second x)", (function()
  local xs = {}
  for _, e in ipairs(texts()) do if e.frame.x > 0 then xs[e.frame.x] = true end end
  local n = 0; for _ in pairs(xs) do n = n + 1 end
  return n <= 1
end)(), "more than one text column x found")
-- 6.57.0 — the cap is now cheatSheet.width (1024 by default), not 760.
-- Width is the free dimension: a wider column means fewer entries wrap
-- onto continuation lines, so 1024 shows MORE shortcuts than 760 did.
check("panel no wider than asked for, and never more than 90% of screen",
      canvasRect.w <= 1024 + 0.01 and canvasRect.w <= SCR.w * 0.90 + 0.01,
      canvasRect.w)
check("panel height within 86% of screen", canvasRect.h <= SCR.h * 0.86 + 0.01, canvasRect.h)
check("panel centred on the screen", math.abs((canvasRect.x + canvasRect.w/2) - (SCR.x + SCR.w/2)) < 0.01)
check("content is long enough to need scrolling", S.maxFirst > 1, S.maxFirst)

print("\n=== 2. No dead space, no half-drawn rows ===")
check("height is exactly chrome + whole rows",
  math.abs(canvasRect.h - (S.contentTop + S.footerH + 8 + S.visible * S.lineH)) < 0.01,
  canvasRect.h)
local topOK, botOK = true, true
for _, e in ipairs(texts()) do
  if e.frame.x > 0 then   -- a content row (title/footer are full-width at x=0)
    if e.frame.y < S.contentTop - 0.01 then topOK = false end
    if e.frame.y + e.frame.h > S.contentTop + S.visible * S.lineH + 0.01 then botOK = false end
  end
end
check("no row drawn above the title area", topOK)
check("no row drawn over the footer", botOK)

print("\n=== 3. Nothing overruns the column (the 6.31.0 bug stays fixed) ===")
local widest, longest = 0, ""
for _, e in ipairs(texts()) do
  if e.frame.x > 0 then
    if e.frame.x + e.frame.w > widest then widest = e.frame.x + e.frame.w end
    if ulen(e.text) > ulen(longest) then longest = e.text end
  end
end
check("text frames stay clear of the scrollbar", widest <= S.sbX - 1, widest .. " vs sbX " .. S.sbX)
local budget = math.max(20, math.floor(S.contentW / (S.entrySize * 0.52)))
check("longest rendered line within the character budget",
  ulen(longest) <= budget, ulen(longest) .. " chars > budget " .. budget)
print(("     longest line (%d chars): %s"):format(ulen(longest), longest))

print("\n=== 4. Translucency ===")
check("panel alpha is see-through but readable (0.6–0.85)",
  drawn[1].fillColor.alpha >= 0.6 and drawn[1].fillColor.alpha <= 0.85, drawn[1].fillColor.alpha)
check("panel is near-black, so white text keeps contrast",
  drawn[1].fillColor.red <= 0.12 and drawn[1].fillColor.blue <= 0.14)
check("entry text is full white", (function()
  for _, e in ipairs(texts()) do
    if e.frame.x > 0 and e.textColor.white then return e.textColor.white >= 0.99 end
  end
end)())

print("\n=== 5. Scrolling: keys ===")
CS.scrollTo(1)
check("starts at the top", st().first == 1)
CS.scrollBy(-5); check("cannot scroll above the first row", st().first == 1, st().first)
CS.scrollBy(3);  check("↓ moves down by rows", st().first == 4, st().first)
local page = CS.pageStep()
check("a page keeps 2 rows of overlap", page == S.visible - 2, page)
CS.scrollBy(page)
check("PgDn advances one page (clamped at the end)",
  st().first == math.min(S.maxFirst, 4 + page), st().first)
CS.scrollTo(math.maxinteger)
check("End lands exactly on the last full view", st().first == S.maxFirst, st().first)
CS.scrollBy(50); check("cannot scroll past the end", st().first == S.maxFirst, st().first)
local lastIdx = st().first + st().visible - 1
check("the final row is reachable (nothing stranded below the fold)",
  lastIdx >= #st().lines, lastIdx .. " of " .. #st().lines)
CS.scrollTo(1); check("Home returns to the top", st().first == 1)

print("\n=== 6. Scrolling: wheel ===")
local P = hs.eventtap.event.properties
MOUSE = { x = canvasRect.x - 50, y = canvasRect.y + 10 }   -- pointer OUTSIDE
local consumed = CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -3 }))
check("wheel passes through when the pointer is off the sheet", consumed == false and st().first == 1)
MOUSE = { x = canvasRect.x + canvasRect.w/2, y = canvasRect.y + canvasRect.h/2 }  -- INSIDE
consumed = CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -3 }))
check("wheel is claimed over the sheet", consumed == true)
check("negative delta scrolls DOWN the list", st().first == 4, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = 2 }))
check("positive delta scrolls UP the list", st().first == 2, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -999 }))
check("one violent flick is capped at 10 rows", st().first == 12, st().first)
CS.scrollTo(1)
local before = st().first
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
check("a tiny trackpad nudge does not move a row yet", st().first == before, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
check("accumulated trackpad pixels do move it (no rounding to zero)", st().first > before, st().first)

print("\n=== 7. Scrollbar tracks the position ===")
local function thumb()
  local t
  for _, e in ipairs(drawn) do
    if e.type == "rectangle" and e.frame and e.frame.w == st().sbW then t = e end
  end
  return t
end
CS.scrollTo(1)
local top = thumb()
check("thumb starts at the top of the track", math.abs(top.frame.y - st().contentTop) < 0.01)
CS.scrollTo(math.maxinteger)
local bot = thumb()
check("thumb ends flush with the bottom of the track",
  math.abs((bot.frame.y + bot.frame.h) - (st().contentTop + st().visible * st().lineH)) < 0.01)
check("thumb never leaves the track", bot.frame.y >= st().contentTop - 0.01)

print("\n=== 8. Cost stays flat as the list grows ===")
local baseEls = #drawn
for i = 1, 300 do
  table.insert(_G.customShortcuts, { keys = "⇪⇧" .. i, desc = "A deliberately long custom description " .. i, group = "BULK" })
end
CS.show()
check("300 extra entries are all in the list", #st().lines > 300, #st().lines)
check("but the canvas element count barely moves",
  #drawn <= baseEls + 2, #drawn .. " vs " .. baseEls)
check("still one column, still the same width", canvasRect.w <= 1024 + 0.01, canvasRect.w)
_G.customShortcuts = {}

print("\n=== 9. Redraw keeps your place; a fresh open does not ===")
CS.show()
-- Pick a position that exists in THIS sheet rather than a hard-coded row:
-- groups keep moving into modules, so the sheet's length is not fixed.
local target = math.min(20, st().maxFirst)
CS.scrollTo(target)
CS.show(true)
check("add/edit/delete redraw preserves the scroll position", st().first == target,
      st().first .. " vs " .. target)
CS.show()
check("⇪/ opens at the top", st().first == 1, st().first)
CS.scrollTo(st().maxFirst)
local wasAt = st().first
_G.customShortcuts = {}
CS.show(true)
check("a shortened list clamps back into range instead of showing blanks",
  st().first <= st().maxFirst, st().first .. " > " .. st().maxFirst)

print("\n=== 10. Small laptop screen ===")
SCR = { x = 0, y = 0, w = 1280, h = 800 }
CS.show()
check("panel still fits the screen", canvasRect.w <= 1280 and canvasRect.h <= 800 * 0.86 + 0.01)
check("still readable — at least 8 rows visible", st().visible >= 8, st().visible)
local ok10 = true
for _, e in ipairs(texts()) do
  if e.frame.x > 0 and (e.frame.x + e.frame.w) > st().sbX then ok10 = false end
end
check("no overrun on the narrower column", ok10)
SCR = { x = 0, y = 0, w = 3840, h = 2160 }

print("\n=== 11. Teardown is complete ===")
CS.show()
local d0, e0 = deleted, hotkeysDisabled
CS.hide()
check("canvas deleted", deleted == d0 + 1)
check("every hotkey disabled (Esc + 6 scroll keys)", hotkeysDisabled >= e0 + 7, hotkeysDisabled - e0)
check("wheel tap stopped", tapRunning == false)
check("state cleared", _G.cheatSheetState == nil and _G.cheatSheetCanvas == nil)
check("scrolling after hide is a no-op, not an error", (function()
  local ok = pcall(function() CS.scrollBy(5); CS.render(); CS.wheelHandler(wheelEvent({})) end)
  return ok
end)())

print("\n=== 12. Toggle ===")
CS.toggle(); check("toggle opens", _G.cheatSheetCanvas ~= nil)
CS.toggle(); check("toggle closes", _G.cheatSheetCanvas == nil)

print("\n=== 13. Group order — pinned first, then A-Z (6.65.0) ===")
-- 🔄 THIS SECTION CHANGED IN 6.65.0 AND THE OLD VERSION WAS RIGHT TO FAIL.
-- Until now the sheet was ordered by each module's `order` field, which is
-- its LOAD order — so the page read in the sequence the config happened to
-- boot in, and moving a section up the page meant renumbering the boot.
-- The order is now decided by the sheet itself: pinned sections first,
-- everything else alphabetical, ⭐ custom entries last.
--
-- What the checks below pin is the RULE, not a transcript of today's list.
-- The old version listed all sixteen titles in sequence, so adding a
-- module broke it whether or not anything was actually wrong.
local got = {}
for _, g in ipairs(CS.groups()) do table.insert(got, g.title) end

-- The pinned sections are not in this test's fixture (they belong to
-- modules, and this file stubs the module list), so what is asserted here
-- is the fallback: with nothing pinned present, the page is A-Z.
local function sortKey(t)
  return (tostring(t):gsub("^[^%a]*", ""):gsub("%s*%b()%s*$", ""):upper())
end
check("every group is in alphabetical order by title, ignoring the "
      .. "leading emoji and the trailing (key) parenthetical", (function()
  for i = 2, #got do
    if sortKey(got[i - 1]) > sortKey(got[i]) then
      return false, sortKey(got[i - 1]) .. " > " .. sortKey(got[i])
    end
  end
  return true
end)())
check("the emoji does NOT decide position — ✅ ASANA sorts under A, "
      .. "not under whatever ✅ happens to be", (function()
  for i, t in ipairs(got) do
    if t:find("ASANA", 1, true) then
      -- ACTIVITY TRACKER, APP MONITOR, APP PEEK, APP UPDATES all precede it.
      return i > 1 and sortKey(got[i - 1]) < "ASANA"
    end
  end
  return false
end)())
check("a title's trailing parenthetical does not decide position either — "
      .. "WINDOW SWITCHER (⌥Tab …) files under W", (function()
  for i, t in ipairs(got) do
    if t:find("WINDOW SWITCHER", 1, true) then
      return sortKey(t) == "WINDOW SWITCHER"
    end
  end
  return false
end)())
check("APP LOCK is gone from the sheet", (function()
  for _, g in ipairs(CS.groups()) do
    if g.title:find("LOCK", 1, true) and not g.title:find("CAPS", 1, true) then return false end
    for _, e in ipairs(g.entries) do
      if tostring(e[2]):find("PIN", 1, true) then return false end
    end
  end
  return true
end)())

-- 🚨 THE PIN ITSELF, driven through the real sort rather than described.
-- A module group whose title contains MOUSE GRID must come FIRST, ahead of
-- everything alphabetical — including a title starting with "A", which is
-- the case that would pass by accident if the pin did nothing.
do
  local saved = _G.moduleCheatsheets
  _G.moduleCheatsheets = {
    { title = "🎯 MOUSE GRID (⇪X — type 3 letters)", entries = { { "⇪X", "grid" } }, order = 13.6 },
    { title = "🔎 TOOL PICKER (⇪⇧/ — search)",       entries = { { "⇪⇧/", "find" } }, order = 13.55 },
    { title = "🅰️ AAA FIRST ALPHABETICALLY",         entries = { { "⇪Z", "z" } },    order = 2 },
  }
  local pinned = {}
  for _, g in ipairs(CS.groups()) do table.insert(pinned, g.title) end
  check("🚨 MOUSE GRID is pinned to the top of the sheet, ahead of a "
        .. "group whose title beats it alphabetically",
        pinned[1] and pinned[1]:find("MOUSE GRID", 1, true) ~= nil,
        "found: " .. tostring(pinned[1]))
  check("TOOL PICKER is pinned second — pinned sections keep the order "
        .. "they are listed in, NOT alphabetical among themselves",
        pinned[2] and pinned[2]:find("TOOL PICKER", 1, true) ~= nil,
        "found: " .. tostring(pinned[2]))
  check("...and the alphabetical band starts immediately after the pins",
        pinned[3] and pinned[3]:find("AAA FIRST", 1, true) ~= nil,
        "found: " .. tostring(pinned[3]))
  _G.moduleCheatsheets = saved
end

-- A module that FAILED to load outranks even a pin. A feature that
-- vanished with no explanation is the one thing that must never be
-- scrolled to.
do
  local saved = _G.moduleStatus
  _G.moduleStatus = { { name = "mouse_grid", ok = false, err = "boom" } }
  local first = CS.groups()[1]
  check("🚨 a broken module is announced ABOVE the pinned sections — a "
        .. "feature that vanished without explanation is the worst thing "
        .. "to bury", first and first.title:find("FAILED TO LOAD", 1, true) ~= nil,
        "found: " .. tostring(first and first.title))
  _G.moduleStatus = saved
end

-- ⭐ custom entries sort last, after everything alphabetical.
do
  local saved = _G.customShortcuts
  _G.customShortcuts = { { keys = "⇪1", desc = "mine", group = "AAA" } }
  local list = CS.groups()
  local last = list[#list]
  check("your own ⭐ entries stay at the bottom even when the group name "
        .. "would sort first", last and last.title:find("⭐", 1, true) ~= nil,
        "found: " .. tostring(last and last.title))
  _G.customShortcuts = saved
end

-- =====================================================================
-- 6.44.11 — THE SURFACE THE OLD SLICE HID
-- =====================================================================
-- tests/block_test.lua had drifted far enough that it contained neither
-- the hs.hotkey.bind calls nor the two hs.chooser pickers. Running the
-- shipped file made both reachable for the first time, so both are now
-- asserted rather than merely survived.
print("\n=== 17. Keys and pickers the shipped file builds at load ===")
check("the cheat sheet binds its own keys at load time", #BOUND >= 3, #BOUND)
local boundKeys = {}
for _, b in ipairs(BOUND) do boundKeys[b.key] = b end
check("⇪/ toggles the sheet", boundKeys["/"] ~= nil)
check("⇪= adds a custom entry", boundKeys["="] ~= nil)
check("⇪- removes one", boundKeys["-"] ~= nil)
check("every binding carries a callback, not a nil", (function()
  for _, b in ipairs(BOUND) do if type(b.fire) ~= "function" then return false end end
  return true
end)())
check("...and they all go on the hyper mods, not bare keys", (function()
  for _, b in ipairs(BOUND) do
    if type(b.mods) ~= "table" or #b.mods == 0 then return false end
  end
  return true
end)())
check("both custom-entry pickers are built", #CHOOSERS >= 2, #CHOOSERS)
check("...and each one explains itself with placeholder text", (function()
  for _, c in ipairs(CHOOSERS) do
    if type(c.placeholder) ~= "string" or c.placeholder == "" then return false end
  end
  return true
end)())
check("...and both are reachable through _G.choosers, which init.lua owns",
  _G.choosers.removeShortcut ~= nil and _G.choosers.editShortcut ~= nil)
check("pressing ⇪- with no custom entries does not raise", (function()
  _G.customShortcuts = {}
  return pcall(boundKeys["-"].fire)
end)())
check("...and neither does ⇪⇧= (edit) with nothing to edit", (function()
  local edit = boundKeys["="]
  return edit ~= nil and pcall(edit.fire)
end)())

-- =====================================================================
-- 🚨 THE PHANTOM PANEL — a canvas:show() that throws (6.56.0)
-- =====================================================================
-- Reported from a real Mac: pressing ⇪/ while Safari's address-bar
-- autocomplete was open raised an AppKit assertion INSIDE SAFARI's
-- out-of-process view, about a window Safari does not own. The throw
-- itself is unpreventable. What was preventable is what it did to us:
-- _G.cheatSheetCanvas was already set, show() threw, and enableInput()
-- never ran — so the config believed the sheet was open while the panel
-- sat half-ordered on screen, and every later ⇪/ only called hide().
-- That is the alternating "Disabled / Re-enabled previous hotkey" pairs
-- the Console showed for minutes afterwards.
do
  CS.hide()
  SHOW_THROWS = true
  local ok = pcall(CS.show)
  SHOW_THROWS = false
  check("🚨 a throwing canvas:show() does NOT escape into the hotkey "
        .. "callback — the whole open sequence used to be abandoned", ok)
  check("🚨 ...and the input keys are still bound, so ⇪/ is not left "
        .. "toggling a panel you cannot see or scroll",
        _G.cheatSheetInputBound ~= false)
  CS.hide()
  check("...and it can be closed and reopened cleanly afterwards",
        (function()
           local ok2 = pcall(CS.show)
           local opened = (_G.cheatSheetCanvas ~= nil)
           CS.hide()
           return ok2 and opened
         end)())
end

print(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
