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

local ALERTS = {}

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
      -- 6.66.0 — the SEARCH keys join the scrolling keys: every letter,
      -- every digit, space and delete are claimed while the sheet is open.
      -- They are still an allow-list rather than "anything goes", because
      -- the point of this assert is that a key appearing here unexpectedly
      -- is a mistake worth failing on.
      -- 6.250.0 — the PUNCTUATION keys join them. Listed here as a
      -- literal rather than read off cheatSheet.punctKeys, deliberately:
      -- this assert exists to notice a key nobody meant to bind, and a
      -- list that reads itself from the thing it is checking cannot. The
      -- two are joined by a check further down instead, so a new row in
      -- the module fails loudly here rather than drifting.
      local valid = { escape=1, up=1, down=1, pageup=1, pagedown=1, home=1, ["end"]=1,
                      space=1, delete=1 }
      for c in ("abcdefghijklmnopqrstuvwxyz0123456789"):gmatch(".") do valid[c] = 1 end
      for _, c in ipairs({ "-", "=", "[", "]", "\\", ";", "'", ",", ".",
                           "/", "`" }) do valid[c] = 1 end
      assert(valid[key], "unexpected key bound: " .. tostring(key))
      -- `enabled` is tracked per hotkey now, not just counted: "did closing
      -- the sheet give the alphabet back" is a question about individual
      -- keys, and a counter cannot answer it.
      -- 6.250.0 — the MODS are recorded now. A shifted bind and a bare
      -- one on the same key are two different hotkeys, and a stub that
      -- forgets which is which cannot tell "?" from "/".
      local ms = {}
      for _, m in ipairs(mods or {}) do ms[#ms + 1] = m end
      local hk = { key = key, mods = ms, fire = pressed,
                   repeatfn = repeatfn, enabled = false }
      function hk:enable() hotkeysEnabled = hotkeysEnabled + 1; hk.enabled = true; return hk end
      function hk:disable() hotkeysDisabled = hotkeysDisabled + 1; hk.enabled = false; return hk end
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
  alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
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
  -- ⏱ A CLOCK THE TEST DRIVES. The Escape shadow is a DEADLINE, so a
  -- frozen clock would make "half a second later" and "immediately" the
  -- same instant and every shadow assertion below would pass for free.
  timer = { doAfter = function() return { stop = function() end } end,
            doEvery = function(_, fn)
              local t = { fn = fn, live = true }
              function t:stop() self.live = false; return self end
              EVERY_TIMERS[#EVERY_TIMERS + 1] = t
              return t
            end,
            secondsSinceEpoch = function() return NOW end },
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

-- 🖐 6.67.0 — the drag helpers live in init.lua and are handed to panels
-- as globals. Stubbing them here is what makes the WIRING testable: does
-- the sheet register for dragging, does it remember where you dropped it,
-- and does a remembered position survive the redraw that happens on every
-- keystroke you type into the search box.
local DRAGGABLE, CLAMPED = {}, {}
_G.makeCanvasDraggable = function(canvas, label, onDrop)
  DRAGGABLE[#DRAGGABLE + 1] = { canvas = canvas, label = label, onDrop = onDrop }
  return true
end
_G.clampToScreen = function(pt, w, h)
  CLAMPED[#CLAMPED + 1] = { pt = pt, w = w, h = h }
  -- Clamp to the single stubbed screen, same contract as the real one.
  return { x = math.max(SCR.x, math.min(pt.x, SCR.x + SCR.w - (w or 0))),
           y = math.max(SCR.y, math.min(pt.y, SCR.y + SCR.h - (h or 0))) }
end
-- 6.44.11 — THIS NOW RUNS THE SHIPPED FILE, NOT A COPY OF IT. Until §1.6
-- moved out of init.lua, the only way to test it was tests/block_test.lua,
-- a hand-extracted slice. Slices drift: that one was no longer even a
-- verbatim substring of init.lua, so every check here was passing against
-- code that was not the code being shipped. core/cheatsheet.lua is the
-- real file, loaded the same way init.lua loads it.
-- ⎋ 6.78.0 — THE ESCAPE ROUTER, RECORDED. The sheet registers its claim
-- when the chunk runs, so the recorder has to exist BEFORE that line. The
-- priority table is lifted out of core/coexist.lua rather than retyped:
-- the property under test is that the sheet defers to that ONE table, and
-- a private copy here could agree with a literal the shipped file no
-- longer uses.
EVERY_TIMERS = {}
NOW = 1000
local ESC_CLAIMS = {}
local ESC_PRIORITIES = (function()
  local f = io.open(HS .. "/core/coexist.lua", "r")
  local src = f and f:read("*a") or ""; if f then f:close() end
  local block = src:match("(_G%.escapePriorities = {.-\n})")
  assert(block, "could not lift _G.escapePriorities from core/coexist.lua")
  local sb = { _G = nil }
  sb._G = sb
  load(block, "priorities", "t", sb)()
  return sb.escapePriorities
end)()
_G.escapeOthersActive = function() return nil end
_G.routeEscape = function() return nil end
function _G.claimEscape(name, priority, active, handle)
  ESC_CLAIMS[name] = { priority = priority, active = active, handle = handle }
  return true
end

-- 🖐 6.106.0 — hs.settings, which is where the dragged position now
-- survives a reload. A plain table stands in for the plist: the point
-- under test is that the sheet writes one key and validates whatever
-- comes back, not that macOS can store a dictionary.
local SETTINGS = {}
hs.settings = {
  set = function(k, v) SETTINGS[k] = v end,
  get = function(k) return SETTINGS[k] end,
}

local CS_PATH = HS .. "/core/cheatsheet.lua"
local csChunk = assert(loadfile(CS_PATH),
                       "cannot load the shipped cheat sheet: " .. CS_PATH)
local CORE_ARGS = {
  logsDir           = logsDir,
  panelAlpha        = 0.90,
  popupScreenKeys   = { mods = { "cmd", "alt", "ctrl" } },
  resolveBaseScreen = resolveBaseScreen,
  showPopup         = function(c) if c and c.show then c:show() end end,
  warnWriteFailed   = warnWriteFailed,
  adoptLegacyFile   = adoptLegacyFile,
}
-- Reloading the config means running this chunk again with the same core.
-- That is exactly what a "does the position survive a reload" check needs,
-- so the arguments are kept rather than inlined.
local function loadSheet() return csChunk()(CORE_ARGS) end
local CS = loadSheet()

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
-- 📐 6.181.0 — LL asked for 1024, so the width is PINNED again and the
-- 6.94.0 fraction is the fallback. Both halves are checked: the pin has
-- to hold on a 4K (where the fraction would have been far wider — 2160,
-- so a check that only said "≤ 90% of the screen" would pass either
-- way), and clearing it has to put the fraction back rather than
-- leaving a dead number in the module.
check("6.181.0: the width is pinned at 1024 on a 4K, not the 55% fraction",
      CS.width == 1024 and canvasRect.w == 1024
      and math.floor(SCR.w * (CS.widthFrac or 0)) > 1024,
      canvasRect.w)
do
  local pinned = CS.width
  CS.width = nil
  CS.show(); CS.show()   -- toggle shut, then open with the fraction
  check("...and clearing it goes back to the monitor fraction, never past 90%",
        canvasRect.w == math.floor(SCR.w * (CS.widthFrac or 0))
        and canvasRect.w <= SCR.w * 0.90 + 0.01, canvasRect.w)
  CS.width = pinned
  CS.show(); CS.show()
  check("...and putting the number back pins it again", canvasRect.w == 1024, canvasRect.w)
end
check("panel height within 86% of screen", canvasRect.h <= SCR.h * 0.86 + 0.01, canvasRect.h)
check("...and on a big display it USES that allowance rather than stopping "
      .. "at the old fixed 768 — height scales too",
      canvasRect.h >= SCR.h * 0.75, canvasRect.h)
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
-- 6.156.1 — LL: "less translucent by about 20%": the knob went 0.75 → 0.90.
-- The pin follows the KNOB, not a literal, and keeps the readable range.
check("panel alpha IS the cheatSheet.alpha knob, see-through but readable (0.6–0.95)",
  drawn[1].fillColor.alpha == CS.alpha
  and drawn[1].fillColor.alpha >= 0.6 and drawn[1].fillColor.alpha <= 0.95,
  drawn[1].fillColor.alpha)
check("...and 6.156.1's 20% is in: 0.90", CS.alpha == 0.90, CS.alpha)
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
-- 6.94.0 — counted in TEXT elements now, not raw elements: the section
-- boxes are rectangles whose count varies with which sections happen to
-- be in view, so raw #drawn compares two different views, not two costs.
-- The property under test is unchanged: rows painted stays view-sized.
local function textEls()
  local n = 0
  for _, e in ipairs(drawn) do if e.type == "text" then n = n + 1 end end
  return n
end
local baseTexts = textEls()
for i = 1, 300 do
  table.insert(_G.customShortcuts, { keys = "⇪⇧" .. i, desc = "A deliberately long custom description " .. i, group = "BULK" })
end
CS.show()
check("300 extra entries are all in the list", #st().lines > 300, #st().lines)
check("but the painted row count barely moves",
  textEls() <= baseTexts + 2, textEls() .. " vs " .. baseTexts)
check("still one column, still the pinned 1024", canvasRect.w == 1024, canvasRect.w)
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
-- 6.111.0 — this used to read "⇪/ opens at the top" full stop. It now
-- opens where you LEFT it, so the top is what you get when there is
-- nothing to remember. Stated explicitly, because the old check would
-- go on passing by accident whenever CS.scroll happened to be nil.
CS.scroll = nil
CS.show()
check("⇪/ opens at the top when nothing has been remembered yet",
      st().first == 1, st().first)
CS.scrollTo(st().maxFirst)
local wasAt = st().first
_G.customShortcuts = {}
CS.show(true)
check("a shortened list clamps back into range instead of showing blanks",
  st().first <= st().maxFirst, st().first .. " > " .. st().maxFirst)

print("\n=== 9b. 6.181.0 — hand-wrapped rows are joined back together ===")
-- LL: "some cheat sheet entries seem incomplete and have more of the
-- sentence. Am I right?" He was. Fifty-one rows across twenty-two
-- modules were split by hand across an empty-key continuation row,
-- from before this panel could wrap, and the tail read as a fragment.
do
  SCR = { x = 0, y = 0, w = 3840, h = 2160 }
  local realGroups = CS.groups
  CS.groups = function()
    return { { title = "🧪 JOIN", order = 1, entries = {
                { "k",  "Bartender covers the bar and screenshots it. For" },
                { "",   "real hiding use Ice" },
                { "",   "" },                      -- blank tail: dropped, not joined
                { "z",  "stands alone" },
              } },
              -- an empty key with NOTHING above it in its own group is a
              -- deliberate blank key, not a continuation, and survives
              { title = "🧪 FIRST", order = 2, entries = {
                { "", "orphan line" },
              } } }
  end
  CS.query = ""
  CS.show(true)
  local body = {}
  for _, l in ipairs(st().lines) do body[#body + 1] = l.text end
  local all = table.concat(body, "\n")
  check("the two halves are ONE entry now — this row fails if the join goes",
        all:find("Bartender covers the bar and screenshots it. For real hiding use Ice", 1, true) ~= nil,
        all)
  check("...and the tail never appears under an empty key of its own",
        all:find("—  real hiding", 1, true) == nil, all)
  check("...a row that is blank on both sides is dropped, not drawn as a bare dash",
        all:find("\n  —  \n") == nil and all:find("k  —  Bartender") ~= nil, all)
  check("...an unrelated entry is untouched", all:find("z  —  stands alone", 1, true) ~= nil)
  check("...and an empty key with nothing above it is left exactly as it was",
        all:find("orphan line", 1, true) ~= nil, all)
  CS.groups = realGroups
  CS.show(true)
end

print("\n=== 10. Small laptop screen ===")
SCR = { x = 0, y = 0, w = 1280, h = 800 }
CS.show()
check("panel still fits the screen", canvasRect.w <= 1280 and canvasRect.h <= 800 * 0.86 + 0.01)
-- 1024 asked for, 1152 allowed (90% of 1280) — the pin survives, and it
-- is the CLAMP that would take over on anything narrower.
check("...and 1024 still fits a 1280 laptop, under the 90% clamp",
      canvasRect.w == 1024 and canvasRect.w <= 1280 * 0.90 + 0.01, canvasRect.w)
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

print("\n=== 11b. 🔎 SEARCH — typing into the sheet (6.66.0) ===")
-- LL asked for this twice. The first answer was a separate hs.chooser
-- window, on the reasoning that "a canvas cannot take keyboard focus".
-- True, and beside the point: Mouse Grid has captured bare letters over a
-- canvas since 6.45.0 without ever taking focus. Bind the keys, keep the
-- string yourself, draw it.
CS.show()
-- The canvas stub records what it was handed in `drawn`, not on the
-- canvas object — so counting elements means reading that.
local function rowsNow()
  local n = 0
  for _, e in ipairs(drawn or {}) do
    if e.type == "text" then n = n + 1 end
  end
  return n
end
local unfiltered = rowsNow()
check("the sheet opens unfiltered", CS.query == "" and unfiltered > 10, unfiltered)

CS.typeChar("a"); CS.typeChar("s"); CS.typeChar("a")
check("typing narrows the list", rowsNow() < unfiltered,
      unfiltered .. " -> " .. rowsNow())
check("...and the query is what was typed", CS.query == "asa", CS.query)
check("a group whose TITLE matches keeps ALL its entries — searching "
      .. "'asana' should show the whole section, not only the rows with "
      .. "the word in them", (function()
  local g = CS.filtered()
  for _, grp in ipairs(g) do
    if grp.title:find("ASANA", 1, true) then return #grp.entries >= 5, #grp.entries end
  end
  return false, "asana group not found"
end)())

-- 🚨 6.66.5 — TYPING MUST NOT CHURN THE KEYBOARD. From LL's Console,
-- seventeen times in two seconds:
--      hs.hotkey system callback for an eventUID we don't know about: 0
-- That is Hammerspoon getting a key event for a hotkey it was just told
-- to forget. typeChar calls show() to rebuild the filtered rows, show()
-- calls hide() so it can never stack two panels, and hide() disabled all
-- 38 search keys — which enableInput() re-enabled a moment later. SEVENTY
-- SIX hotkey operations per character, with real key events landing in
-- the middle of them.
do
  local before = hotkeysDisabled
  CS.typeChar("d")
  local churn = hotkeysDisabled - before
  check("🚨 typing a character disables NO hotkeys — a redraw rebuilds the "
        .. "canvas, never the keyboard", churn == 0, churn .. " disabled")
  check("...and the sheet is still up and still filtering afterwards",
        _G.cheatSheetCanvas ~= nil and CS.query == "asad", CS.query)
  CS.backspace()
end
check("a real CLOSE still gives every key back — keepInput is for redraws "
      .. "only, and a sheet that closed without releasing 38 bare letters "
      .. "would be the worst bug in this file", (function()
  CS.show()
  CS.hide()
  for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
    if hk.enabled then return false end
  end
  return true
end)())
-- Re-seed to the state the checks below were written against: the block
-- above closed the sheet to prove a real close releases the keys.
CS.show(); CS.typeChar("a"); CS.typeChar("s"); CS.typeChar("a")
CS.backspace()
check("backspace widens it again", CS.query == "as", CS.query)
check("🚨 backspace steps a CHARACTER, not a byte — lopping one byte off a "
      .. "multi-byte glyph leaves a string hs.canvas will not draw",
      (function()
  CS.query = "⇪"                      -- three bytes, one character
  CS.backspace()
  return CS.query == ""
end)())

-- 🧨 THE ONE THAT MATTERS. This sheet is a wall of ⇪[ ⇪\ ⇪- ⇪/ ⇪= and
-- every one is an operator in Lua's pattern engine.
for _, q in ipairs({ "[", "]", "%", "%d", "(", ")", "*", "+", "-", "?",
                     "^", "$", ".", "%b()" }) do
  CS.query = ""
  local ok = pcall(function() CS.typeChar(q) end)
  check("typing " .. q .. " searches instead of throwing", ok)
end
CS.query = ""

check("esc CLEARS a query before it closes the sheet — a mistyped search "
      .. "should not cost a close-and-reopen", (function()
  CS.show(); CS.typeChar("z"); CS.typeChar("z"); CS.typeChar("z")
  CS.escape()
  return CS.query == "" and _G.cheatSheetCanvas ~= nil
end)())
check("...and a SECOND esc closes it", (function()
  CS.escape()
  return _G.cheatSheetCanvas == nil
end)())
check("a query matching nothing says so instead of drawing an empty panel",
      (function()
  CS.show(); CS.query = "zzzznothing"
  CS.show(false)
  for _, e in ipairs(drawn or {}) do
    if e.type == "text" and tostring(e.text):find("no shortcut matches", 1, true) then
      return true
    end
  end
  return false
end)())
CS.hide()
check("🚨 closing GIVES THE ALPHABET BACK — bare letter keys left enabled "
      .. "after the sheet is gone is a keyboard that types into nothing",
      (function()
  for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
    if hk.enabled then return false end
  end
  return true
end)())
check("...and the query is cleared, so ⇪/ never reopens still filtered",
      CS.query == "")

print("\n=== 11c. 🖐 DRAGGING (6.67.0) ===")
-- LL: "Great pop-up. But I can't drag the window. Same with shortcuts
-- window. Both should be moveable."
DRAGGABLE, CLAMPED = {}, {}
CS.pos = nil
CS.show()
check("the sheet registers itself as draggable", #DRAGGABLE == 1, #DRAGGABLE)
-- Indexed defensively: when the registration mutation lands there is no
-- DRAGGABLE[1], and a bare index aborts the run — killing every check
-- after it and blaming this line instead of the one that broke.
local reg = DRAGGABLE[1] or {}
check("...under a name, so a drag can be traced in the diagnostic trail",
      reg.label == "cheat sheet", tostring(reg.label))
check("...and hands over an onDrop, without which a dragged panel snaps "
      .. "back the next time it is drawn", type(reg.onDrop) == "function")

local defaultX = canvasRect.x
if reg.onDrop then reg.onDrop({ x = 100, y = 200, w = 300, h = 400 }) end
check("dropping it remembers where you put it",
      CS.pos and CS.pos.x == 100 and CS.pos.y == 200,
      CS.pos and CS.pos.x)

-- 🖱 6.138.0 — LL, on a Magic Trackpad: "Seems like a drag kills the
-- sheet functionality." The wheel handler hit-tests st.rect, and a drop
-- that moved the canvas but not that rectangle left a sheet the
-- trackpad could not scroll until it was closed and reopened.
check("🚨 the WHEEL'S HIT BOX MOVES WITH THE DROP — a rectangle left at "
      .. "the old spot is a sheet the trackpad cannot scroll until it "
      .. "is reopened",
      (function()
        local r = _G.cheatSheetState and _G.cheatSheetState.rect
        return r ~= nil and r.x == 100 and r.y == 200
                        and r.w == 300 and r.h == 400
      end)())
MOUSE = { x = 150, y = 300 }   -- inside the DROPPED frame
check("...so the wheel is claimed over the sheet's NEW position, with "
      .. "no reopen in between",
      CS.wheelHandler(wheelEvent({
        [hs.eventtap.event.properties.scrollWheelEventDeltaAxis1] = 2,
      })) == true)
CS.show()
check("...and the next draw opens THERE, not back in the centre",
      canvasRect.x == 100 and canvasRect.y == 200,
      canvasRect.x .. "," .. canvasRect.y)
check("...which is a different place from the default", defaultX ~= 100)

-- 🚨 THE ONE THAT MATTERS MOST HERE. Typing rebuilds this canvas on every
-- character. A position stored on the canvas would be lost between "a"
-- and "as", and the sheet would jump back to centre mid-search.
CS.typeChar("u"); CS.typeChar("r"); CS.typeChar("l")
check("🚨 a dragged position SURVIVES the redraw that happens on every "
      .. "keystroke — the search box rebuilds the canvas per character",
      canvasRect.x == 100 and canvasRect.y == 200,
      canvasRect.x .. "," .. canvasRect.y)
CS.query = ""

-- 🚨 6.248.0 — THIS ASSERTED THAT `_G.clampToScreen` WAS CALLED, and
-- 6.288.0 deliberately stops calling it. That helper walks
-- hs.screen.allScreens() and clamps to the FIRST screen the point
-- overlaps, which threw away the resolved screen on the last line — it is
-- right for a caller with no resolved screen and wrong for one that has
-- worked it out. The RULE this check exists for is unchanged and is what
-- it asserts now: the sheet is never restored somewhere you cannot see.
CS.pos = { x = 99999, y = 99999 }
CS.show()
check("a remembered position that no display can hold is not obeyed — the "
      .. "sheet is never restored somewhere invisible with no way back",
      canvasRect.x >= SCR.x and canvasRect.x < SCR.x + SCR.w
      and canvasRect.y >= SCR.y and canvasRect.y < SCR.y + SCR.h,
      canvasRect.x .. "," .. canvasRect.y)
CS.pos = nil
CS.hide()

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
-- 🔄 CHANGED IN 6.101.0, AND THE OLD RULE WAS RIGHT TO GO. Until now the
-- whole page was one A–Z run, which is an INDEX: to find the split-windows
-- key you had to already know it lives under W for Window Arranger. Groups
-- now sort into FAMILIES first (LL: "Can we combine certain single tools of
-- similar types?"), and A–Z runs INSIDE a family. What is asserted is that
-- rule — families in the declared order, alphabetical within each — not a
-- transcript of today's list.
check("groups sort into families, in the order the families are declared",
      (function()
  local idx = {}
  for i, f in ipairs(CS.families) do idx[f.id] = i end
  local seen = -1
  for _, g in ipairs(CS.groups()) do
    if g.famIdx then
      if g.famIdx < seen then
        return false, "family " .. tostring(g.family) .. " came after a later one"
      end
      seen = g.famIdx
    end
  end
  return true
end)())
check("...and A–Z still runs INSIDE each family, ignoring the leading "
      .. "emoji and the trailing (key) parenthetical", (function()
  local list = CS.groups()
  for i = 2, #list do
    local a, b = list[i - 1], list[i]
    if a.famIdx and b.famIdx and a.famIdx == b.famIdx
       and sortKey(a.title) > sortKey(b.title) then
      return false, sortKey(a.title) .. " > " .. sortKey(b.title)
        .. " inside " .. tostring(b.family)
    end
  end
  return true
end)())
check("the emoji does NOT decide position — ✅ ASANA sorts under A among "
      .. "its own family, not under whatever ✅ happens to be", (function()
  local list = CS.groups()
  for i, g in ipairs(list) do
    if g.title:find("ASANA", 1, true) then
      local prev = list[i - 1]
      -- Either it opens its family, or the group above it sorts before A.
      return (not prev) or prev.famIdx ~= g.famIdx
             or sortKey(prev.title) < "ASANA"
    end
  end
  return false
end)())
-- 🚨 A GROUP WITH NO FAMILY IS FILED VISIBLY, NEVER DROPPED AND NEVER
-- ABSORBED. This harness stubs the module list, so what it can prove is
-- the FALLBACK: an unfiled group still reaches the sheet, in the band
-- whose name admits what happened. That every SHIPPED module declares a
-- real family is a different question, asked of the files on disk in
-- test_diagnostics §7 — the fixture here could never answer it.
check("a group with NO family still reaches the sheet, in misc", (function()
  local saved = _G.moduleCheatsheets
  _G.moduleCheatsheets = {
    { title = "🧪 UNFILED", entries = { { "⇪Z", "z" } }, order = 5 },
  }
  local found
  for _, g in ipairs(CS.groups()) do
    if g.title:find("UNFILED", 1, true) then found = g.family end
  end
  _G.moduleCheatsheets = saved
  return found == "misc", "landed in: " .. tostring(found)
end)())
check("...and an UNKNOWN family is caught rather than dropped — a group "
      .. "claiming a family that does not exist still appears, in misc",
      (function()
  local saved = _G.moduleCheatsheets
  _G.moduleCheatsheets = {
    { title = "🧪 INVENTED", entries = { { "⇪Z", "z" } }, order = 5,
      family = "no_such_family" },
  }
  local found
  for _, g in ipairs(CS.groups()) do
    if g.title:find("INVENTED", 1, true) then found = g.family end
  end
  _G.moduleCheatsheets = saved
  return found == "misc", "landed in: " .. tostring(found)
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
  -- All three in ONE family, so the A–Z rule inside it is what decides —
  -- this fixture is about ordering, not about family membership.
  _G.moduleCheatsheets = {
    { title = "🎯 MOUSE GRID (⇪X — type 3 letters)", entries = { { "⇪X", "grid" } }, order = 13.6, family = "windows" },
    { title = "🔎 TOOL PICKER (⇪⇧/ — search)",       entries = { { "⇪⇧/", "find" } }, order = 13.55, family = "windows" },
    { title = "🅰️ AAA FIRST ALPHABETICALLY",         entries = { { "⇪Z", "z" } },    order = 2, family = "windows" },
  }
  local pinned = {}
  for _, g in ipairs(CS.groups()) do table.insert(pinned, g.title) end
  -- 🔤 6.66.1 — THE PIN LIST IS EMPTY, on request ("Alphabetize my
  -- shortcut list"). 6.65.0 pinned Mouse Grid and Tool Picker, which was
  -- ALSO asked for at the time; the two instructions disagree and the
  -- later one wins. What is asserted now is that nothing jumps the queue.
  check("🔤 NOTHING is pinned — a group whose title starts with A sorts "
        .. "first, even against sections that used to be pinned above it",
        pinned[1] and pinned[1]:find("AAA FIRST", 1, true) ~= nil,
        "found: " .. tostring(pinned[1]))
  check("...and MOUSE GRID takes its alphabetical place rather than the "
        .. "top", (function()
    for i, t in ipairs(pinned) do
      if t:find("MOUSE GRID", 1, true) then return i > 1, "position " .. i end
    end
    return false, "mouse grid not found"
  end)())
  -- ✏️ THE MECHANISM IS STILL THERE AND STILL WORKS. Driving it through
  -- the real sort keeps it honest: an empty list is a CHOICE, not a
  -- feature that quietly rotted.
  check("the pin mechanism still functions when a pin IS set — an empty "
        .. "list must be a decision, not a broken code path", (function()
    local savedPins = CS.pinned
    CS.pinned = { "MOUSE GRID" }
    local g = CS.groups()
    CS.pinned = savedPins
    return g[1] and g[1].title:find("MOUSE GRID", 1, true) ~= nil,
           "found: " .. tostring(g[1] and g[1].title)
  end)())
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


-- =====================================================================
print("\n=== THE CHEAT SHEET CLOSES LAST (6.78.0) ===")
-- =====================================================================
-- LL: "make the shortcut key cheat sheet stay up instead of it grabbing
-- escape and closing. It should be the last window to close after all
-- other pop-ups."
do
  local claim = ESC_CLAIMS["cheatsheet"]
  check("the sheet registers a claim on Esc at all", claim ~= nil)
  -- 🚨 THE POINT OF THE WHOLE CHANGE. It used to pass a literal 10, which
  -- sat ABOVE every panel that had no claim at all — i.e. all of them but
  -- the pomodoro — so the sheet took Esc from the calendar, the switcher
  -- and fifteen choosers. Deferring to coexist's table is what makes it
  -- the floor, and asserting the literal is gone is what keeps it there.
  check("🚨 ...and DEFERS to coexist's one priority table rather than "
     .. "naming a number of its own",
        claim ~= nil and (claim.priority == nil
                          or claim.priority == ESC_PRIORITIES.cheatsheet),
        claim and tostring(claim.priority))
  check("...and that table really does put the sheet below everything else",
    (function()
      local floor = ESC_PRIORITIES.cheatsheet
      if floor == nil then return false, "no cheatsheet entry" end
      for name, prio in pairs(ESC_PRIORITIES) do
        if name ~= "cheatsheet" and prio <= floor then return false, name end
      end
      return true
    end)())
  check("its active() is \"am I on screen\", so the router only arbitrates",
    (function()
      CS.hide()
      if claim.active() ~= false then return false, "active with no canvas" end
      CS.show(false)
      local up = claim.active()
      CS.hide()
      return up == true
    end)())

  -- 🚨 AND THE SHEET ACTUALLY ASKS. The router being right is worth
  -- nothing if cheatSheet.escape() never consults it — the mechanism and
  -- its wiring are two different things, and only one of them was tested.
  CS.show(false)
  CS.query = ""
  _G.escapeOthersActive = function() return "calendar" end
  CS.escape()
  check("🚨 the sheet STAYS UP while another panel is still on screen",
        _G.cheatSheetCanvas ~= nil)

  _G.escapeOthersActive = function() return nil end
  CS.escape()
  check("...and closes once it is the last thing left",
        _G.cheatSheetCanvas == nil)

  -- The clear-before-close behaviour has to survive all of it.
  CS.show(false)
  CS.query = "asana"
  _G.escapeOthersActive = function() return nil end
  CS.escape()
  check("...Esc still CLEARS a search before it closes anything",
        CS.query == "" and _G.cheatSheetCanvas ~= nil)
  CS.escape()
  check("...and the second Esc closes it", _G.cheatSheetCanvas == nil)

  -- routeEscape wins outright when it reports a handler ran.
  CS.show(false)
  CS.query = ""
  _G.routeEscape = function() return "pomodoro" end
  CS.escape()
  check("a panel that HANDLED the Esc keeps the sheet up too",
        _G.cheatSheetCanvas ~= nil)
  _G.routeEscape = function() return nil end
  CS.escape()
  check("...and the sheet is free again afterwards", _G.cheatSheetCanvas == nil)
end


-- =====================================================================
print("\n=== THE ESCAPE SHADOW (6.79.2) ===")
-- =====================================================================
-- LL: "When you hit escape any other Hammerspoon window closes after.
-- That means I have to open the shortcuts panel again each time and lose
-- my place."
--
-- 🚨 6.78.0 asked "is anything else on screen?" at the moment Esc
-- arrived, and that question loses a race it cannot win. One Escape
-- reaches TWO things: an hs.chooser dismisses itself natively the instant
-- the key lands — nothing here is consulted — while the sheet's own
-- bare-Esc hotkey is dispatched separately by Carbon. If the chooser has
-- already gone by the time we ask, the sheet closes on the same keystroke
-- that closed the chooser. So the sheet REMEMBERS instead of asking.
do
  local othersUp = false
  _G.escapeOthersActive = function() return othersUp and "chooser" or nil end
  _G.routeEscape = function() return nil end
  _G.cheatSheetOtherSeenAt = 0
  NOW = 1000

  local function tickPoller()
    for _, t in ipairs(EVERY_TIMERS) do if t.live then t.fn() end end
  end

  CS.show(false)
  check("opening the sheet starts the shadow poller, HELD in _G",
        _G.cheatSheetOtherWatch ~= nil)

  othersUp = true
  tickPoller()
  check("...and it writes down when something else was last on screen",
        _G.cheatSheetOtherSeenAt == 1000, _G.cheatSheetOtherSeenAt)

  -- the chooser dismisses ITSELF, so by the time Esc reaches us it is gone
  othersUp = false
  NOW = 1000.1
  CS.query = ""
  CS.escape()
  check("🚨 THE SHEET STAYS UP on the Escape that closed something else, "
     .. "even though nothing is on screen by the time we are asked — this "
     .. "is the race, and remembering is the only thing that survives it",
        _G.cheatSheetCanvas ~= nil)

  NOW = 1000.3
  CS.escape()
  check("...still up part-way through the shadow", _G.cheatSheetCanvas ~= nil)

  NOW = 1001.0
  CS.escape()
  check("...and a deliberate Escape after the shadow closes it, so the key "
     .. "still works and is never a mystery", _G.cheatSheetCanvas == nil)
  check("closing the sheet stops the poller — a timer nobody stops is a "
     .. "timer that outlives its panel",
        _G.cheatSheetOtherWatch == nil)

  -- the shadow must not swallow a plain Escape on a quiet desktop
  _G.cheatSheetOtherSeenAt = 0
  NOW = 2000
  CS.show(false)
  CS.query = ""
  CS.escape()
  check("🚨 with nothing else all session, ONE Escape still closes the "
     .. "sheet — the shadow is a memory of other panels, not a delay",
        _G.cheatSheetCanvas == nil)

  -- and it never overrides the two checks that come first
  CS.show(false)
  CS.query = ""
  othersUp = true
  NOW = 3000
  CS.escape()
  check("something genuinely still on screen keeps the sheet up regardless",
        _G.cheatSheetCanvas ~= nil)
  othersUp = false
  _G.routeEscape = function() return "pomodoro" end
  NOW = 4000
  _G.cheatSheetOtherSeenAt = 0
  CS.escape()
  check("...and a panel that HANDLED the Esc does too", _G.cheatSheetCanvas ~= nil)
  _G.routeEscape = function() return nil end
  CS.hide()
end

-- =====================================================================
print("\n=== THE SHEET CANNOT GET STUCK (6.189.0) ===")
-- =====================================================================
-- Everything above is the sheet deferring to whatever else is on screen,
-- and all of it trusts a claimant's own active() to go false again. A
-- claimant that gets that wrong refuses Esc FOREVER and the sheet is
-- unclosable by the key it tells you to press. So refusals are counted
-- and LL can insist.
do
  local stuck = true
  _G.escapeOthersActive = function() return stuck and "ghostPanel" or nil end
  _G.routeEscape = function() return nil end
  _G.cheatSheetOtherSeenAt = 0
  NOW = 5000
  CS.escInsist, CS.escInsistWindow = 2, 2.0
  CS.show(false); CS.query = ""

  CS.escape()
  check("one Esc still DEFERS to a claimant that says it is active — the "
     .. "sheet is still the last thing to close", _G.cheatSheetCanvas ~= nil)
  check("...and the refusal is written down, naming who",
        CS.lastEsc ~= nil and CS.lastEsc.who == "ghostPanel"
        and CS.lastEsc.run == 1, CS.lastEsc and CS.lastEsc.who)
  check("...and _G.escapeLastRefusal carries it to the report",
        _G.escapeLastRefusal == CS.lastEsc)

  NOW = 5000.4
  local alertsBefore = #ALERTS
  CS.escape()
  check("🚨 a SECOND Esc closes the sheet regardless — a claimant that "
     .. "never goes idle can no longer trap it", _G.cheatSheetCanvas == nil)
  check("...and LL is told who would not let go",
        (ALERTS[#ALERTS] or ""):find("ghostPanel", 1, true) ~= nil,
        ALERTS[#ALERTS])
  check("...and it is not silent about it", #ALERTS > alertsBefore)

  -- the run must not span a long gap, or a refusal from a minute ago
  -- pairs with a fresh one and one press closes the sheet
  CS.show(false); CS.query = ""
  NOW = 6000; CS.escape()
  NOW = 6000 + 5.0; CS.escape()
  check("two refusals far apart do NOT count as insistence — the window "
     .. "is real", _G.cheatSheetCanvas ~= nil)
  check("...and the run restarted rather than climbing", CS.lastEsc.run == 1,
        CS.lastEsc.run)

  -- a DIFFERENT claimant restarts the run too: insisting at one panel is
  -- not insisting at another
  CS.show(false); CS.query = ""
  NOW = 7000
  stuck = true
  _G.escapeOthersActive = function() return "panelA" end
  CS.escape()
  _G.escapeOthersActive = function() return "panelB" end
  NOW = 7000.2
  CS.escape()
  check("a refusal from a DIFFERENT claimant restarts the run",
        _G.cheatSheetCanvas ~= nil and CS.lastEsc.run == 1,
        CS.lastEsc and CS.lastEsc.run)

  -- an Esc that did something ends the run
  _G.escapeOthersActive = function() return stuck and "ghostPanel" or nil end
  CS.show(false); CS.query = ""
  NOW = 8000; CS.escape()
  stuck = false
  NOW = 8000.2; CS.escape()          -- this one closes it normally
  check("an Esc that actually acted clears the run", CS.lastEsc == nil)
  CS.show(false); CS.query = ""
  stuck = true
  NOW = 8000.4; CS.escape()
  check("...so the next refusal starts at press one, not two",
        _G.cheatSheetCanvas ~= nil and CS.lastEsc.run == 1)

  -- and LL can trade back — a pinned vault legitimately survives Esc
  CS.escInsist = 3
  CS.show(false); CS.query = ""
  NOW = 9000; CS.escape(); NOW = 9000.2; CS.escape()
  check("settings { cheatsheet = { escInsist = 3 } } takes three presses",
        _G.cheatSheetCanvas ~= nil, CS.lastEsc and CS.lastEsc.run)
  NOW = 9000.4; CS.escape()
  check("...and the third closes it", _G.cheatSheetCanvas == nil)
  CS.escInsist = 2

  -- the report itself lives with the ROUTER (core/coexist.lua) and is
  -- executed for real in test_integration; what the sheet owes it is the
  -- refusal, published where the report can read it.
  stuck = true
  CS.show(false); CS.query = ""
  NOW = 9500; CS.escape()
  check("🚨 the sheet publishes the refusal for _G.escapeReport() to name",
        _G.escapeLastRefusal ~= nil
        and _G.escapeLastRefusal.who == "ghostPanel"
        and _G.escapeLastRefusal.why ~= nil,
        _G.escapeLastRefusal and _G.escapeLastRefusal.who)
  CS.hide()
  _G.escapeOthersActive = function() return nil end
end

-- =====================================================================
print("\n=== SECTIONS BOXED, SIZED TO THE MONITOR (6.94.0 · softened 6.100.2) ===")
-- =====================================================================
-- LL: "Can we make the cheat sheet flexible and dynamic so that it
-- scales to the size of the monitor and ... each section on the sheet
-- for each tool be outlined in Black?" — then, 6.100.2: "soften the
-- black boxes around each tool to a similar gray of each shortcut box".
-- 🚨 THE BOXES ARE FOUND BY SHAPE, NOT BY COLOUR. The first version of
-- this harness matched strokeColor.white == 0, so it was really asking
-- "is it black?" — and every structural check below (one per section,
-- clear of the scrollbar, under the text) silently stopped testing
-- anything the moment the colour changed. A section box is now
-- identified the way it actually differs from the panel and the
-- scrollbar: a stroked rectangle WITH a frame of its own.
do
  SCR = { x = 0, y = 0, w = 3840, h = 2160 }
  CS.pos, CS.query = nil, ""
  _G.customShortcuts = {}
  CS.show()

  local function boxes()
    local out = {}
    for _, e in ipairs(drawn) do
      if e.type == "rectangle" and e.action == "strokeAndFill" and e.frame then
        out[#out + 1] = e
      end
    end
    return out
  end
  local bx = boxes()
  check("every visible section sits in its own outlined box", #bx >= 3, #bx)
  -- The ask, asserted as a RELATIONSHIP rather than a hard-coded colour:
  -- the section edge is the same hairline the panel itself is drawn with.
  local panelEdge
  for _, e in ipairs(drawn) do
    if e.type == "rectangle" and e.action == "strokeAndFill" and not e.frame then
      panelEdge = panelEdge or e
    end
  end
  check("the panel's own edge is findable, to compare against", panelEdge ~= nil)
  check("...and each tool's box wears the SAME grey hairline as the panel "
        .. "— siblings, not a black grid ruled over the sheet",
        bx[1] and panelEdge
        and bx[1].strokeColor.white == panelEdge.strokeColor.white
        and bx[1].strokeColor.alpha == panelEdge.strokeColor.alpha
        and bx[1].strokeWidth == panelEdge.strokeWidth,
        bx[1] and bx[1].strokeColor and
          ("white=" .. tostring(bx[1].strokeColor.white)
           .. " alpha=" .. tostring(bx[1].strokeColor.alpha)))
  check("...it is GREY, never black again — black is what was softened",
        bx[1] and (bx[1].strokeColor.white or 0) > 0.5
        and (bx[1].strokeColor.alpha or 1) < 0.5)
  check("...and the grouping survives the softer edge: each box still "
        .. "lifts off the panel with a fill of its own",
        bx[1] and bx[1].fillColor and (bx[1].fillColor.alpha or 0) >= 0.05,
        bx[1] and bx[1].fillColor and bx[1].fillColor.alpha)

  -- One box per visible SECTION — the spacer rows between groups are the
  -- gaps between boxes, never boxed themselves. Counted from the state
  -- the sheet itself laid out, so the check follows the real view.
  local S9 = st()
  local lastV = math.min(#S9.lines, S9.first + S9.visible - 1)
  local seen, nsec = {}, 0
  for i = S9.first, lastV do
    local s = S9.lines[i].sec
    if s and not seen[s] then seen[s] = true; nsec = nsec + 1 end
  end
  check("one box per visible section, spacers unboxed", #bx == nsec,
        #bx .. " boxes vs " .. nsec .. " sections")

  check("boxes stay clear of the scrollbar", (function()
    for _, b in ipairs(bx) do
      if b.frame.x + b.frame.w > S9.sbX - 1 then return false end
    end
    return true
  end)())
  check("boxes are drawn UNDER the text — outline behind every row, "
        .. "never through it", (function()
    local lastRect, firstText
    for i, e in ipairs(drawn) do
      if e.type == "rectangle" and e.action == "strokeAndFill" and e.frame then
        lastRect = i
      end
      if e.type == "text" and not firstText then firstText = i end
    end
    return lastRect and firstText and lastRect < firstText
  end)())
  check("every content row sits INSIDE its section's horizontal bounds",
        (function()
    for _, e in ipairs(texts()) do
      if e.frame.x > 0 and bx[1] and e.frame.x < bx[1].frame.x then
        return false
      end
    end
    return true
  end)())

  -- Scrolling to the end shows a different set of sections; the boxes
  -- must follow the view rather than being laid out once for the top.
  CS.scrollTo(math.maxinteger)
  check("boxes follow the scroll — the bottom of the list is boxed too",
        #boxes() >= 1, #boxes())

  -- ✏️ The old fixed size is one edit away, not gone: a number pins it.
  CS.width, CS.height = 900, 700
  CS.show()
  check("✏️ a NUMBER in cheatSheet.width still pins the old fixed size — "
        .. "scaling is the default, not a mandate",
        canvasRect.w == 900 and canvasRect.h <= 700 + 0.01,
        canvasRect.w .. "x" .. canvasRect.h)
  CS.width, CS.height = nil, nil
  CS.hide()
end

-- =====================================================================
print("\n=== 🗂 FAMILY BANDS ON THE PAGE (6.101.0) ===")
-- =====================================================================
-- LL: "Can we combine certain single tools of similar types?" The sort is
-- checked in §13; what is checked HERE is the page it produces — that a
-- band appears once above its tools, that it is not mistaken for a
-- section, and that a search does not leave a heading standing over
-- nothing.
do
  local saved = _G.moduleCheatsheets
  _G.moduleCheatsheets = {
    { title = "🪟 WINDOW ARRANGER",  entries = { { "⇪←", "left half" } },  order = 6,  family = "windows" },
    { title = "🎯 MOUSE GRID",       entries = { { "⇪X", "point" } },      order = 13, family = "windows" },
    { title = "🗒 CAPTURE PAD",      entries = { { "⇪N", "collect" } },    order = 13, family = "capture" },
    { title = "☁️ BACKUP",           entries = {},                         order = 15,
      family = "auto", summary = "Copies this config to OneDrive once a day", source = "Daily Backup" },
    { title = "👁 APP MONITOR",      entries = {},                         order = 1,
      family = "auto", summary = "Notices apps starting and quitting",     source = "App Watcher" },
  }
  _G.customShortcuts = {}
  CS.pos, CS.query = nil, ""
  CS.show()

  local function rowsOfKind(k)
    local out = {}
    for _, l in ipairs(st().lines) do
      if l.kind == k then out[#out + 1] = l.text end
    end
    return out
  end

  local bands = rowsOfKind("family")
  check("a band is drawn for each family present", #bands >= 3, #bands)
  check("...each family announces itself EXACTLY ONCE, however many tools "
        .. "it holds — WINDOWS has two here", (function()
    local seen = {}
    for _, b in ipairs(bands) do
      if seen[b] then return false, "repeated: " .. b end
      seen[b] = true
    end
    return true
  end)())
  check("...and the band sits ABOVE its first tool, not among the rows",
        (function()
    local lines = st().lines
    for i, l in ipairs(lines) do
      if l.kind == "family" then
        local nxt = lines[i + 1]
        if not (nxt and nxt.kind == "header") then
          return false, "row after a band was: " .. tostring(nxt and nxt.kind)
        end
      end
    end
    return true
  end)())
  -- 🚨 A BAND IS NOT A SECTION. Bands carry no `sec`, so the 6.94.0 boxes
  -- close around the tools and leave the heading outside — the whole point
  -- of a band being a different KIND of row.
  check("🚨 a band carries no section tag, so no box is drawn around it",
        (function()
    for _, l in ipairs(st().lines) do
      if l.kind == "family" and l.sec ~= nil then return false, l.text end
    end
    return true
  end)())
  check("...and it is drawn in the accent colour, not the blue a section "
        .. "header uses — a family must not read as one more tool",
        (function()
    local famText, hdrText
    for _, l in ipairs(st().lines) do
      if l.kind == "family" and not famText then famText = l.text end
      if l.kind == "header" and not hdrText then hdrText = l.text end
    end
    local famEl, hdrEl
    for _, e in ipairs(drawn) do
      if e.type == "text" and e.text == famText then famEl = e end
      if e.type == "text" and e.text == hdrText then hdrEl = e end
    end
    if not (famEl and hdrEl) then return false, "rows not drawn" end
    return famEl.textColor.red ~= hdrEl.textColor.red
           and famEl.textSize > hdrEl.textSize
  end)())

  -- ⚙️ The automatic tools collapse into ONE box, one line each.
  check("⚙️ the automatic tools collapse into a single RUNS ITSELF box",
        (function()
    local n = 0
    for _, g in ipairs(CS.groups()) do
      if g.title:find("RUNS ITSELF", 1, true) then n = n + 1 end
    end
    return n == 1, n .. " such boxes"
  end)())
  check("...listing each by NAME with its one-line summary, so a tool you "
        .. "cannot press is still a tool you know you have", (function()
    for _, g in ipairs(CS.groups()) do
      if g.title:find("RUNS ITSELF", 1, true) then
        local byName = {}
        for _, e in ipairs(g.entries) do byName[e[1]] = e[2] end
        return byName["Daily Backup"] == "Copies this config to OneDrive once a day"
               and byName["App Watcher"] == "Notices apps starting and quitting",
               "got: " .. tostring(byName["Daily Backup"])
      end
    end
    return false, "no RUNS ITSELF box"
  end)())
  check("...and they no longer hold sections of their own — that is the "
        .. "~25 rows of unpressable keys this removes", (function()
    for _, g in ipairs(CS.groups()) do
      if g.title:find("BACKUP", 1, true) or g.title:find("APP MONITOR", 1, true) then
        return false, "still its own section: " .. g.title
      end
    end
    return true
  end)())

  -- 🔎 A SEARCH MUST NOT LEAVE A HEADING OVER AN EMPTY FAMILY. The bands
  -- are emitted from the FILTERED list for exactly this reason.
  CS.query = "collect"
  CS.show()
  local filteredBands = rowsOfKind("family")
  check("🔎 filtering to one tool leaves ONLY that tool's family band",
        #filteredBands == 1 and filteredBands[1]:find("CAPTURE", 1, true) ~= nil,
        table.concat(filteredBands, " | "))
  CS.query = ""
  CS.hide()
  _G.moduleCheatsheets = saved
end

-- =====================================================================
print("\n=== 🖐 WHERE YOU LEFT IT — the position survives a reload (6.106.0) ===")
-- LL: "Can we make the cheat sheet remember where it was before it was
-- closed?" It already survived a redraw and a reopen, because the
-- position lives on the namespace table. It did NOT survive a reload,
-- which rebuilds that table — so every reload put the sheet back in the
-- middle and you moved it again.
do
  SETTINGS = {}
  CS.pos = nil
  CS.show()
  local drop = DRAGGABLE[#DRAGGABLE]
  check("the sheet still registers for dragging", drop ~= nil and drop.onDrop ~= nil)
  drop.onDrop({ x = 310, y = 205, w = 100, h = 100 })
  check("dropping it records the position for this session",
        CS.pos and CS.pos.x == 310 and CS.pos.y == 205, CS.pos and CS.pos.x)
  check("...and writes it to exactly ONE settings key",
        SETTINGS["cheatSheet.pos"] ~= nil and next(SETTINGS, next(SETTINGS)) == nil,
        (next(SETTINGS)))
  CS.hide()

  -- The whole point: a fresh chunk is what a reload is.
  local reloaded = loadSheet()
  check("🚨 a RELOAD picks the position back up",
        reloaded.pos and reloaded.pos.x == 310 and reloaded.pos.y == 205,
        reloaded.pos and reloaded.pos.x)

  -- 🚨 VALIDATED ON THE WAY IN. hs.settings is a plist on disk: editable,
  -- writable by another version, and perfectly capable of handing back a
  -- string or a NaN. A NaN reaches the canvas and the sheet is drawn
  -- nowhere at all, with no way back except editing settings by hand.
  local junk = {
    { "a string",        "220,140" },
    { "a number",        42 },
    { "a table with no coordinates", { w = 10 } },
    { "a NaN",           { x = 0/0, y = 10 } },
    { "an infinity",     { x = math.huge, y = 10 } },
    { "coordinates as text", { x = "left", y = "top" } },
  }
  for _, j in ipairs(junk) do
    SETTINGS["cheatSheet.pos"] = j[2]
    local r = loadSheet()
    check("junk in settings — " .. j[1] .. " — reads as NO position",
          r.pos == nil, r.pos and (tostring(r.pos.x) .. "," .. tostring(r.pos.y)))
  end

  -- Numbers that arrive as strings ARE coordinates; tonumber is the rule,
  -- not type(). A plist round-trip is exactly where that happens.
  SETTINGS["cheatSheet.pos"] = { x = "310", y = "205" }
  local coerced = loadSheet()
  check("numeric strings still count as a position",
        coerced.pos and coerced.pos.x == 310, coerced.pos and coerced.pos.x)

  -- The way out, for a position clamping cannot rescue.
  SETTINGS["cheatSheet.pos"] = { x = 310, y = 205 }
  local r2 = loadSheet()
  _G.cheatSheetCenter()
  check("_G.cheatSheetCenter() forgets the stored position",
        SETTINGS["cheatSheet.pos"] == nil)
  check("...and the sheet re-centres on the next open",
        r2.pos == nil, r2.pos)

  -- And the off switch does what it says, in both directions.
  SETTINGS["cheatSheet.pos"] = { x = 310, y = 205 }
  local off = loadSheet()
  off.rememberPos = false
  off.pos = nil
  check("rememberPos = false stops it being SAVED",
        (function()
           SETTINGS["cheatSheet.pos"] = nil
           off.savePos({ x = 1, y = 2 })
           return SETTINGS["cheatSheet.pos"] == nil
         end)())
  check("...and stops it being READ", off.loadPos() == nil)

  -- A remembered position outlives the display it was set on. The clamp
  -- was already here; this is the check that it still runs on the value
  -- that came from disk rather than only on a live drag.
  SETTINGS["cheatSheet.pos"] = { x = 99999, y = 99999 }
  local far = loadSheet()
  CLAMPED = {}
  far.show()
  -- 6.196.0 — REWRITTEN TO THE NEW CONTRACT, not loosened. Until this
  -- release a stored position was absolute, so one belonging to another
  -- display was CLAMPED — dragged back onto an edge of whichever screen
  -- was in front. LL: "the cheat sheet appears on the last monitor it
  -- appeared on and not the active application on another monitor where
  -- I am now working." A position is now an offset within its screen, and
  -- a legacy absolute one that does not fall on the screen being opened on
  -- is DROPPED for the centre rather than dragged to a corner of it. The
  -- promise that matters is unchanged and still asserted: it is never
  -- restored somewhere you cannot see.
  check("a legacy position from a monitor you no longer have is not obeyed "
        .. "— the sheet opens on the screen in front of you",
        canvasRect.x >= SCR.x and canvasRect.x < SCR.x + SCR.w
        and canvasRect.y >= SCR.y and canvasRect.y < SCR.y + SCR.h,
        canvasRect and (canvasRect.x .. "," .. canvasRect.y))
  far.hide()

  -- ---- 🖥 the offset really follows the screen (6.196.0) ------------
  -- THE MUTATION THIS CATCHES: storing dx/dy and then still drawing at
  -- the absolute x/y. Both are kept in the stored table on purpose (an
  -- older build must still find a position it understands), so a check
  -- that only asserted "it opened somewhere sensible" would pass with
  -- the offset ignored entirely. This moves the SCREEN out from under a
  -- fixed offset and demands the sheet move with it.
  do
    SETTINGS["cheatSheet.pos"] = { x = 40, y = 60, dx = 40, dy = 60 }
    local was = { x = SCR.x, y = SCR.y }
    local rel = loadSheet()
    SCR.x, SCR.y = was.x + 2560, was.y      -- LL's second monitor
    rel.show()
    check("🚨 a remembered position is an offset INTO the screen, so the "
          .. "sheet opens on the monitor the front app is on — this is "
          .. "LL's 'it appears on the last monitor, not the one I am "
          .. "working on'",
          canvasRect.x == SCR.x + 40 and canvasRect.y == SCR.y + 60,
          canvasRect.x .. "," .. canvasRect.y)
    check("...and the offset from the edge is exactly the one that was "
          .. "stored, so it stays where you put it",
          canvasRect.x - SCR.x == 40 and canvasRect.y - SCR.y == 60)
    rel.hide()
    SCR.x, SCR.y = was.x, was.y
  end
  SETTINGS = {}
end

-- =====================================================================
print("\n=== 📜 WHERE YOU HAD SCROLLED TO — survives a close (6.111.0) ===")
-- LL: "the cheat sheet still isn't remembering where I am when I close
-- it." The PANEL's position already survived a close and a reload; the
-- ROW you had scrolled to did not — hide() dropped the state and show()
-- began at 1. These checks hold the three-way contract that makes the
-- difference: nil reopens where you were, false (a filter keystroke)
-- goes to the top, true (a redraw) stays put.
do
  CS.rememberScroll = true
  CS.scroll = nil
  CS.show()
  local row = math.min(12, st().maxFirst)
  CS.scrollTo(row)
  CS.hide()                       -- a REAL close, the way Esc closes it
  check("the row is remembered at the moment of a real close",
        CS.scroll == row, tostring(CS.scroll) .. " vs " .. row)
  CS.show()
  check("🚨 reopening puts you back where you were reading",
        st().first == row, st().first .. " vs " .. row)

  -- The filter path must NOT get the remembered row back: it passes
  -- false, and false and nil used to be the same thing.
  CS.typeChar("w")
  check("typing a filter still snaps to the top of the shorter list",
        st().first == 1, st().first)
  CS.hide()
  check("…and closing while FILTERED does not store a filtered row",
        CS.scroll == row, tostring(CS.scroll) .. " vs " .. row)
  CS.show()
  check("…so you reopen at the row you were on BEFORE you searched",
        st().first == row, st().first .. " vs " .. row)

  -- An in-place redraw is a third case again.
  local moved = math.min(7, st().maxFirst)
  CS.scrollTo(moved)
  CS.show(true)
  check("an add/edit/delete redraw still keeps the CURRENT row, not the "
        .. "remembered one", st().first == moved, st().first .. " vs " .. moved)

  -- A remembered row outlives the list it came from.
  CS.hide()
  CS.scroll = 9999
  CS.show()
  check("🚨 a row past the end of a shorter sheet clamps to the last full "
        .. "view — never blank space", st().first == st().maxFirst,
        st().first .. " vs " .. st().maxFirst)

  CS.hide()
  CS.rememberScroll = false
  CS.scroll = 12
  CS.show()
  check("rememberScroll = false goes back to always opening at the top",
        st().first == 1, st().first)
  CS.rememberScroll = true
  CS.scroll = nil
  CS.hide()
end

-- =====================================================================
print("\n=== 🔎 …AND SURVIVES A SEARCH (6.118.0) ===")
-- LL: "The cheat sheet remembers its position when I scroll. But loses it
-- when I search." Going to the TOP while filtering is deliberate and
-- stays; what was missing was the way back. Clearing the query rebuilt
-- the full list at row 1, so looking one thing up cost you your place —
-- and there are two ways to clear a query (⌫ to empty, and Esc), so both
-- are driven here rather than one standing in for the other.
do
  CS.rememberScroll = true
  CS.scroll = nil
  CS.show()
  local anchor = math.min(11, st().maxFirst)
  CS.scrollTo(anchor)
  CS.typeChar("w")
  check("typing a filter still goes to the top of the shorter list",
        st().first == 1, st().first)
  CS.backspace()
  check("🔎 ⌫ back to nothing puts you where the search found you",
        st().first == anchor and CS.query == "",
        st().first .. " vs " .. anchor)

  CS.scrollTo(anchor)
  CS.typeChar("w"); CS.typeChar("i")
  _G.cheatSheetOtherSeenAt = 0        -- no other panel; see the shadow note
  CS.escape()
  check("🔎 …and so does Esc, which clears the query before it closes",
        st().first == anchor and CS.query == "" and _G.cheatSheetCanvas ~= nil,
        st().first .. " vs " .. anchor)

  -- 🚨 THE ONE THAT CATCHES THE OLD FALSE CLAIM. hide() has said since
  -- 6.111.0 that closing while filtered "keeps the last row you were on
  -- BEFORE you searched". It kept whatever was stored at the PREVIOUS
  -- close, which is that row only if you had not scrolled this time —
  -- so the stored row and the current row are deliberately DIFFERENT
  -- here. With the old code this stores `anchor` and fails.
  CS.hide()
  CS.show()
  local moved = math.min(5, st().maxFirst)
  CS.scrollTo(moved)
  CS.typeChar("w")
  CS.hide()
  check("🚨 closing mid-search stores the row the search took you FROM, "
        .. "not the row stored at the last close",
        CS.scroll == moved and moved ~= anchor,
        tostring(CS.scroll) .. " vs " .. moved)
  CS.show()
  check("…so ⇪/ reopens you there", st().first == moved,
        st().first .. " vs " .. moved)

  -- The anchor is spent, not sticky: a second search from a new row must
  -- come back to the NEW row, and a plain reopen must not be dragged to
  -- a row some earlier search happened to leave behind.
  local second = math.min(8, st().maxFirst)
  CS.scrollTo(second)
  CS.typeChar("w")
  CS.backspace()
  check("a second search anchors on where you were THAT time",
        st().first == second and second ~= moved,
        st().first .. " vs " .. second)
  check("…and the anchor is spent once it is used",
        CS.searchAnchor == nil, tostring(CS.searchAnchor))

  CS.hide()
  CS.scroll = nil
  CS.searchAnchor = nil
end


-- =====================================================================
-- 🔤 PUNCTUATION IS SEARCHABLE (6.250.0)
-- =====================================================================
-- LL: "When I search the cheat sheet, I can't search punctuation and I
-- should be able to." This sheet is a wall of ⇪\ ⇪' ⇪/ ⇪; ⇪[ ⇪] ⇪- ⇪=
-- and not one of them could be typed into its own search box: only
-- a-z, 0-9, space and delete were ever claimed.
do
  local before = pass + fail
  local okSection, secErr = pcall(function()

  -- ---- the map, as data ---------------------------------------------
  local rows = CS.punctKeys
  check("punctKeys is a list of rows, not a set of strings",
        type(rows) == "table" and #rows > 0 and type(rows[1]) == "table")
  check("every row names a key and at least one character it types",
        (function()
          for _, r in ipairs(rows) do
            if type(r.key) ~= "string" or r.key == "" then return false, r.key end
            if r.plain == nil and r.shift == nil then return false, r.key end
          end
          return true
        end)())
  check("no key appears twice — one key, one row",
        (function()
          local seen = {}
          for _, r in ipairs(rows) do
            if seen[r.key] then return false, r.key end
            seen[r.key] = true
          end
          return true
        end)())
  -- 🚨 MUTATION: give "1" a `plain` and the digit is bound twice — once
  -- by the a-z0-9 loop and once here — which is exactly the "two objects
  -- bound to one key, one of which nothing can disable" this file warns
  -- about at the top of the search-key block.
  check("🚨 a DIGIT row carries only its shifted character — its bare key "
        .. "is already claimed by the a-z0-9 loop",
        (function()
          for _, r in ipairs(rows) do
            if r.key:match("^%d$") and r.plain ~= nil then return false, r.key end
          end
          return true
        end)())
  -- The join the stub's allow-list cannot make for itself.
  check("every punctuation key the module names is one the stub allows — "
        .. "a new row fails here rather than drifting",
        (function()
          local allowed = {}
          for _, c in ipairs({ "-", "=", "[", "]", "\\", ";", "'", ",", ".",
                               "/", "`" }) do allowed[c] = true end
          for _, r in ipairs(rows) do
            if not (allowed[r.key] or r.key:match("^%d$")) then
              return false, r.key
            end
          end
          return true
        end)())

  -- ---- what is actually bound ----------------------------------------
  CS.show()
  local function keyFor(k, shifted)
    for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
      local hasShift = (hk.mods and #hk.mods > 0)
      if hk.key == k and hasShift == (shifted and true or false) then return hk end
    end
  end
  check("the backslash is bound bare", keyFor("\\", false) ~= nil)
  check("...and shifted, as a different hotkey", keyFor("\\", true) ~= nil)
  check("...and they are not the same object",
        keyFor("\\", false) ~= keyFor("\\", true))

  -- 🚨 A HELPER ANSWERS FALSELY RATHER THAN INDEXING A NIL (6.186.0):
  -- the mutation that stops a key being bound must FAIL these checks, not
  -- throw through them and delete every check after it. It did, first
  -- time, in three of six mutations.
  local function press(k, shifted)
    local hk = keyFor(k, shifted)
    if not (hk and hk.fire) then return false end
    hk.fire()
    return true
  end

  -- 🔤 THE REPORTED BUG: typing ⇪\'s own character into the box.
  CS.query = ""
  check("🔤 pressing \\ types a backslash into the search box",
        press("\\", false) and CS.query == "\\", CS.query)
  check("...and ⇧/ types a question mark",
        press("/", true) and CS.query == "\\?", CS.query)
  CS.query = ""
  check("...and a shifted DIGIT types its symbol",
        press("1", true) and CS.query == "!", CS.query)
  CS.query = ""

  -- ---- and the filter takes it ---------------------------------------
  check("matches() takes a backslash as TEXT, not as a pattern",
        CS.matches("⇪\\  split the two front windows", "\\") == true)
  check("...and a bracket does not throw",
        (function()
          local ok, r = pcall(CS.matches, "⇪[ move a window left", "[")
          return ok and r == true
        end)())
  check("...and a query that matches nothing still says no",
        CS.matches("⇪; power tools", "\\") == false)

  -- ---- a real close gives the new keys back too -----------------------
  CS.hide()
  check("closing the sheet releases the punctuation as well as the letters",
        (function()
          for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
            if hk.enabled then return false, hk.key end
          end
          return true
        end)())

  -- ---- a key that cannot be bound is NAMED ----------------------------
  -- 🚨 MUTATION: swallow the refusal. The shifted half assumes a US
  -- layout, so a Mac where ⇧- is not "_" simply fails to bind — and a
  -- count that says nothing is how that becomes "the search box is
  -- broken and nobody knows which key".
  do
    local realNew = hs.hotkey.new
    local killed = 0
    hs.hotkey.new = function(mods, key, ...)
      if key == "`" then killed = killed + 1 ; error("no such key", 0) end
      return realNew(mods, key, ...)
    end
    _G.cheatSheetSearchKeys = nil
    CS.show()
    hs.hotkey.new = realNew
    check("a key that will not bind is counted and named, and the rest "
          .. "still bind",
          killed > 0 and type(CS.searchKeysRefused) == "table"
          and #CS.searchKeysRefused == killed
          and (CS.searchKeysBound or 0) > 30,
          tostring(CS.searchKeysBound) .. " bound, "
          .. tostring(CS.searchKeysRefused and #CS.searchKeysRefused) .. " refused")
    CS.hide()
    _G.cheatSheetSearchKeys = nil
  end

  end)
  check("§6.250.0 ran to the end — a throw here deletes the checks after it",
        okSection == true, secErr)
  local ran = (pass + fail) - before
  check("§6.250.0 ran all of its checks (" .. ran .. " of 16+)", ran >= 16, ran)
end

-- =====================================================================
-- §6.269.0 — `_G.cheatSheetReport()`: the sheet's first report
-- =====================================================================
-- The sheet is the surface LL reads to find out what this config can do,
-- and until 6.269.0 it was the last big one with nothing to ask. It
-- exists because anchors.lua drew a heading over empty space for
-- eighty-nine releases and there was no question that would have said so.
-- 🧪 THE SECTION WRAPS ITSELF (6.186.0): a throw in here would delete the
-- checks after it while the run still printed "0 failed".
do
  local before = pass + fail
  local okSection, secErr = pcall(function()

  -- A capture that answers FALSELY rather than indexing a nil: a mutation
  -- must fail a check, never kill the run.
  local function runReport()
    local realPrint, out = print, {}
    print = function(...)                            -- luacheck: ignore
      local parts = {}
      for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
      out[#out + 1] = table.concat(parts, "\t")
    end
    local ok, err = pcall(function()
      if type(_G.cheatSheetReport) ~= "function" then error("no report", 0) end
      _G.cheatSheetReport()
    end)
    print = realPrint                                -- luacheck: ignore
    return { ok = ok, err = err, calls = #out, text = table.concat(out, "\n") }
  end

  loadSheet()   -- publishes _G.cheatSheetReport
  check("§6.269.0 the sheet publishes _G.cheatSheetReport()",
        type(_G.cheatSheetReport) == "function", type(_G.cheatSheetReport))

  local savedCards, savedFaults = _G.moduleCheatsheets, _G.cheatsheetFaults

  -- 🔎 THREE STATES, NEVER TWO (6.196.1). "nothing has registered yet"
  -- and "nothing is empty" are opposite facts about the same sheet.
  _G.moduleCheatsheets, _G.cheatsheetFaults = {}, {}
  local r = runReport()
  check("§6.269.0 a sheet NOTHING has registered into says so rather than "
        .. "reporting a clean bill of health",
        r.ok and r.text:find("has not been filled in", 1, true) ~= nil
            and r.text:find("empty  : none", 1, true) == nil, r.text)

  -- 📏 ONE STRING, ONE print (6.179.1): core/console.lua's gate silences
  -- repeated short lines and splices ⛔/⚠️ banners through a report
  -- printed row by row, so a multi-print report loses rows in the wild.
  _G.moduleCheatsheets = {
    { title = "🅰 ONE", entries = { { "⇪A", "a" }, { "⇪B", "b" } }, source = "one" },
    { title = "🅱 TWO", entries = { { "⇪C", "c" } },                source = "two" },
  }
  _G.cheatsheetFaults = {}
  r = runReport()
  check("§6.269.0 the report prints as ONE string, not row by row",
        r.ok and r.calls == 1, tostring(r.calls) .. " print call(s)")
  check("§6.269.0 a healthy sheet counts its cards, rows and modules",
        r.ok and r.text:find("2 card(s) · 3 row(s) from 2 module(s)", 1, true) ~= nil,
        r.text)
  check("§6.269.0 ...and says plainly that no card is empty",
        r.ok and r.text:find("empty  : none", 1, true) ~= nil
            and r.text:find("faults : none", 1, true) ~= nil, r.text)

  -- 🔗 THE BUG THIS REPORT EXISTS FOR: a card with a title and no rows.
  -- The check asserts the TITLE is named — a count alone ("1 empty") is
  -- the shape that left anchors invisible, because it does not say WHICH.
  _G.moduleCheatsheets[#_G.moduleCheatsheets + 1] =
    { title = "🔗 ANCHORS (⇪⇧U …)", entries = {}, source = "anchors" }
  r = runReport()
  check("§6.269.0 an EMPTY card is counted AND named, never just counted",
        r.ok and r.text:find("1 card(s) draw a title over nothing", 1, true) ~= nil
            and r.text:find("🔗 ANCHORS", 1, true) ~= nil
            and r.text:find("(from anchors)", 1, true) ~= nil, r.text)
  check("§6.269.0 ...and it does NOT still claim every card has rows",
        r.ok and r.text:find("every card on the sheet has rows", 1, true) == nil, r.text)

  -- 🔎 TWO KINDS OF EMPTY, AND THEY ARE OPPOSITE FACTS. `family = "auto"`
  -- registers a card for a tool with no cheat sheet of its own so the tool
  -- is LISTED at all; that card is a heading alone ON PURPOSE. Counting it
  -- beside a real one prints a ⚠️ on a healthy Mac — which is exactly what
  -- this report did when it was first written, and it is 6.196.1's rule
  -- broken by the instrument built to keep it. copy_on_select is the one
  -- real instance in this config today.
  _G.moduleCheatsheets = {
    { title = "🅰 ONE", entries = { { "⇪A", "a" } }, source = "one" },
    { title = "Copy-on-Select", entries = {}, source = "Copy-on-Select",
      empties = true, family = "auto" },
  }
  _G.cheatsheetFaults = {}
  r = runReport()
  check("§6.269.0 a card that is a heading ON PURPOSE is NOT counted as "
        .. "empty — a ⚠️ on a healthy Mac is a report you stop reading",
        r.ok and r.text:find("empty  : none", 1, true) ~= nil
            and r.text:find("draw a title over nothing", 1, true) == nil, r.text)
  check("§6.269.0 ...but it is still NAMED, so a deliberate heading is not "
        .. "simply hidden from him",
        r.ok and r.text:find("ON PURPOSE", 1, true) ~= nil
            and r.text:find("Copy-on-Select", 1, true) ~= nil, r.text)

  -- and the two must be told apart in the SAME sheet, which is the case
  -- no single-state fixture can prove.
  _G.moduleCheatsheets[#_G.moduleCheatsheets + 1] =
    { title = "🔗 ANCHORS (⇪⇧U …)", entries = {}, source = "anchors" }
  r = runReport()
  check("§6.269.0 a deliberate heading and a broken card on ONE sheet are "
        .. "counted apart, not summed",
        r.ok and r.text:find("1 card(s) draw a title over nothing", 1, true) ~= nil
            and r.text:find("🔗 ANCHORS", 1, true) ~= nil
            and r.text:find("ON PURPOSE", 1, true) ~= nil, r.text)

  -- 🔔 THE DIAGNOSIS, not the symptom: where the loader worked out WHICH
  -- key the rows are hiding under, the report hands over the one-word fix.
  _G.cheatsheetFaults = { {
    source = "anchors", title = "🔗 ANCHORS (⇪⇧U …)", key = "rows", rows = 8,
    why = "anchors's cheat-sheet card has a title and no rows — 8 row(s) "
       .. "are under `rows`, and the sheet only reads `entries`",
  } }
  r = runReport()
  check("§6.269.0 a fault is repeated in full, with the key the rows hid under",
        r.ok and r.text:find("8 row(s) are under `rows`", 1, true) ~= nil, r.text)
  check("§6.269.0 ...and names the file and the one-word fix",
        r.ok and r.text:find("`rows =` becomes `entries =`", 1, true) ~= nil
            and r.text:find("modules/anchors.lua", 1, true) ~= nil, r.text)
  check("§6.269.0 ...and the ⚠️ outranks the counts, so a faulty sheet "
        .. "never reads as a healthy one",
        r.ok and r.text:find("faults : none", 1, true) == nil, r.text)

  -- A fault recorded with no other key still reads as a sentence.
  _G.cheatsheetFaults = { { source = "x", title = "T",
    why = "x's cheat-sheet card has a title and no rows (its `entries` "
       .. "list is missing or empty)" } }
  r = runReport()
  check("§6.269.0 a fault with no other key to name still prints, and "
        .. "offers no one-word fix it cannot justify",
        r.ok and r.text:find("missing or empty", 1, true) ~= nil
            and r.text:find("becomes `entries =`", 1, true) == nil, r.text)

  _G.moduleCheatsheets, _G.cheatsheetFaults = savedCards, savedFaults

  end)
  check("§6.269.0 ran to the end — a throw here deletes the checks after it",
        okSection == true, secErr)
  local ran = (pass + fail) - before
  check("§6.269.0 ran all of its checks (" .. ran .. " of 14+)", ran >= 14, ran)
end

-- =====================================================================
print("\n=== 🖥 6.288.0 — IT OPENS ON THE SCREEN IT RESOLVED, NOT THE ONE THE SPOT CAME FROM ===")
-- =====================================================================
-- LL: "Appears on a different screen sometimes — and when it does it
-- seems to not be the frontmost window until I move it." Both halves are
-- one mechanism. 6.196.0 stores the spot as an OFFSET into the screen it
-- was dragged on and 6.236.0 resolves the right screen — both correct —
-- and then the last line handed the answer to _G.clampToScreen, which
-- clamps to the FIRST screen the point overlaps. An offset saved on the
-- 4K applied to the Air's origin lands on the 4K, and the clamp keeps it
-- there. A sheet on the other monitor is also a sheet that is not in
-- front of him; he drags it back, and it appears.
do
  local before = pass + fail
  local P = CS.placeIn
  check("cheatSheet.placeIn is PURE and reachable", type(P) == "function")

  local AIR = { x = 0, y = 0, w = 1440, h = 900 }
  local LG  = { x = 1440, y = 0, w = 3840, h = 2160 }

  local x, y, why = P(AIR, 400, 300, nil)
  check("nothing remembered → centred on the resolved screen",
        x == (1440 - 400) / 2 and y == (900 - 300) / 2, x .. "," .. y)
  check("…and it says so", why:find("centred", 1, true) ~= nil, why)

  x, y, why = P(AIR, 400, 300, { dx = 100, dy = 50 })
  check("a spot that FITS is honoured exactly", x == 100 and y == 50)
  check("…and it says so", why:find("where you put it", 1, true) ~= nil, why)

  -- 🚨 THE RELEASE. dx = 2000 is a spot he dragged to on the 4K. On the
  -- Air, sf.x + 2000 is physically ON the 4K, and the old code's clamp
  -- kept it there.
  x, y, why = P(AIR, 400, 300, { dx = 2000, dy = 50 })
  check("🚨 an offset saved on a BIGGER screen cannot push the sheet onto "
        .. "another monitor — this is his whole report",
        x >= AIR.x and x + 400 <= AIR.x + AIR.w, x .. " (+400) vs " .. AIR.w)
  check("…and it is NUDGED, not centred — he still gets the right-hand "
        .. "side of the screen he asked for", x == 1440 - 400, x)
  check("…and the report can tell him why", why:find("nudged", 1, true) ~= nil, why)

  x, y, why = P(AIR, 400, 300, { dx = -500, dy = -500 })
  check("a negative offset is nudged back too, never off the left edge",
        x == AIR.x and y == AIR.y, x .. "," .. y)

  -- the same spot on the big screen is simply honoured
  x, y, why = P(LG, 400, 300, { dx = 2000, dy = 50 })
  check("…while on the 4K that very offset fits and is obeyed",
        x == LG.x + 2000 and why:find("where you put it", 1, true) ~= nil,
        x .. " / " .. why)

  -- legacy absolute positions
  x, y, why = P(AIR, 400, 300, { x = 120, y = 90 })
  check("a LEGACY absolute spot on this screen is honoured", x == 120 and y == 90)
  x, y, why = P(AIR, 400, 300, { x = 3000, y = 90 })
  check("…and one on a screen you are not on is DROPPED for the centre, "
        .. "never dragged onto a screen it was never on",
        x == (1440 - 400) / 2, x)
  check("…and says which", why:find("screen you", 1, true) ~= nil, why)

  -- a panel bigger than the screen pins to the origin rather than sliding off
  x, y = P(AIR, 2000, 1200, { dx = 300, dy = 300 })
  check("a panel bigger than the screen pins to its origin",
        x == AIR.x and y == AIR.y, x .. "," .. y)

  -- ---- and it is what show() really uses --------------------------------
  -- 6.264.0: proving a pure decision is not proving anything CALLS it.
  -- 🧪 6.278.0 — A SECTION THAT READS A PUBLISHED GLOBAL MUST DRIVE THE
  -- INSTANCE THAT PUBLISHED IT. This suite loads the sheet several times
  -- and _G.cheatSheetReport belongs to the LAST one; driving CS while
  -- reading that report measures two objects and calls the disagreement
  -- a bug.
  SCR.x, SCR.y, SCR.w, SCR.h = 0, 0, 1440, 900
  local live = loadSheet()
  live.pos = { dx = 3000, dy = 20 }
  live.show()
  check("🚨 …and show() really asks it: a 4K offset does not put the panel "
        .. "on the 4K", canvasRect.x + canvasRect.w <= SCR.x + SCR.w,
        canvasRect.x .. "+" .. canvasRect.w)
  check("…and the placement is recorded for the report",
        live.lastPlace ~= nil and tostring(live.lastPlace.why):find("nudged", 1, true),
        live.lastPlace and live.lastPlace.why)
  -- 🚨 AND IT IS THE LATEST ONE. He opens this sheet many times a session;
  -- a record written once and kept would answer about the first draw for
  -- ever, which is worse than no record — it would look current.
  live.hide()
  live.pos = { dx = 60, dy = 40 }
  live.show()
  check("🚨 …and it is refreshed on EVERY draw, not written once",
        tostring(live.lastPlace.why):find("where you put it", 1, true) ~= nil,
        live.lastPlace.why)
  live.hide()
  live.pos = { dx = 3000, dy = 20 }
  live.show()
  local printed = {}
  local rp = print
  print = function(...) local t = {}
      for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
      printed[#printed+1] = table.concat(t, " ") end
  _G.cheatSheetReport()
  print = rp
  local rep = table.concat(printed, "\n")
  check("🔎 the report names where it landed and why — 'it opens on the "
        .. "wrong monitor sometimes' is a count, not a sample",
        rep:find("place  :", 1, true) ~= nil, rep)
  check("…and warns when the saved spot does not fit this screen",
        rep:find("does not fit", 1, true) ~= nil, rep)
  live.pos = nil
  live.hide()

  -- 🚨 SOURCE: clampToScreen must stay out of this file. It is right for
  -- a caller with no resolved screen and wrong for one that has worked it
  -- out, and using it here is exactly the defect (comments stripped,
  -- 6.262.0, because the comment explaining the rule names the call).
  do
    local fh = assert(io.open(HS .. "/core/cheatsheet.lua"))
    local src = fh:read("a"); fh:close()
    local code = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
      code[#code + 1] = (line:gsub("%-%-.*$", ""))
    end
    check("🚨 SOURCE: the sheet never places itself through _G.clampToScreen",
          table.concat(code, "\n"):find("clampToScreen") == nil)
  end

  local ran = (pass + fail) - before
  check("§6.288.0 ran all of its checks (" .. ran .. " of 20+)", ran >= 20, ran)
end

print(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
