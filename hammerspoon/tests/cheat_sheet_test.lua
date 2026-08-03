-- =====================================================================
-- Shortcut cheat sheet (§1.6) — offline test suite
-- =====================================================================
-- Runs §1.6 out of init.lua under a mock Hammerspoon, with no
-- Hammerspoon and no network. It reads the section straight out of
-- init.lua, so it always tests the code you actually ship.
--
--     cd hammerspoon && lua5.4 tests/cheat_sheet_test.lua
--
-- Exit status is 0 only if every check passes.
-- =====================================================================

local TMP = os.getenv("CS_TMP") or "/tmp/cs_test"
os.execute("rm -rf " .. TMP .. " && mkdir -p " .. TMP)

-- ---------- tiny JSON (only needs to round-trip the custom list) -------
local json = {}
function json.encode(v)
  local out = {}
  for _, c in ipairs(v) do
    out[#out+1] = string.format('{"keys":%q,"desc":%q,"group":%q}',
      c.keys or "", c.desc or "", c.group or "")
  end
  return "[" .. table.concat(out, ",") .. "]"
end
function json.decode(s)
  local list = {}
  for obj in tostring(s or ""):gmatch("%b{}") do
    local e = {}
    for k, v in obj:gmatch('"(%w+)":"(.-)"') do e[k] = v end
    list[#list+1] = e
  end
  return list
end

-- ---------- mock hs ----------
ALERTS, PRINTS, HOTKEYS, COPIED = {}, {}, {}, nil
CHOOSER_CFG = {}
local realprint = print
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
  PRINTS[#PRINTS+1] = table.concat(p, " ")
end

hs = {
  configdir = TMP,
  json = json,
  alert = { show = function(m) ALERTS[#ALERTS+1] = tostring(m) end },
  pasteboard = { setContents = function(s) COPIED = s; return true end },
  dialog = { textPrompt = function() return "Cancel", "" end },
  hotkey = {
    bind = function(mods, key, fn)
      HOTKEYS[#HOTKEYS+1] = { mods = mods, key = key, fn = fn }
      return { enable = function() end, disable = function() end }
    end,
    new = function() return { enable = function() end, disable = function() end } end,
  },
  chooser = {
    new = function(fn)
      local c = { _fn = fn, _choices = {}, _visible = false, _query = "" }
      function c:choices(t) self._choices = t; return self end
      -- Config is recorded PER CHOOSER: §1.6 builds three of them
      -- (the sheet, plus the edit and remove pickers) and a single
      -- shared table would just report whichever was created last.
      c.cfg = {}
      function c:placeholderText(s) self.cfg.placeholder = s; return self end
      function c:width(n) self.cfg.width = n; return self end
      function c:rows(n) self.cfg.rows = n; return self end
      function c:bgDark(b) self.cfg.bgDark = b; return self end
      function c:queryChangedCallback(f) self._qcb = f; return self end
      function c:query(q)
        if q == nil then return self._query end
        self._query = q
        if self._qcb then self._qcb(q) end
        return self
      end
      function c:show() self._visible = true; return self end
      function c:hide() self._visible = false; return self end
      function c:isVisible() return self._visible end
      function c:select(i) return self._fn(self._choices[i]) end
      return c
    end,
  },
}

-- ---------- upvalues §1.6 borrows from the rest of init.lua ----------
logsDir = TMP
function adoptLegacyFile() end
function warnWriteFailed(l) WRITEFAIL = l end
function showPopup(c) c:show() end
function resolveBaseScreen() return nil end
popupScreenKeys = { mods = { "ctrl", "alt", "cmd" } }
_G.choosers = {}

-- ---------- pull §1.6 straight out of init.lua ----------
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local initPath = os.getenv("CS_INIT") or (here .. "/../init.lua")
local fh = assert(io.open(initPath, "r"), "cannot open " .. initPath)
local full = fh:read("*a"); fh:close()

local s = full:find('local cheatSheetKey')
local e = full:find("%-%- 1%.7 DAILY BACKUP")
assert(s and e, "could not delimit §1.6")
-- back up past the ==== banner that precedes §1.7
local section = full:sub(s, e - 1):gsub("%-%-=+%s*$", "")
assert(load(section, "@cheat-sheet-section"))()

-- ---------- tests ----------
local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1
  else fail = fail + 1; realprint("  FAIL: " .. name .. (extra and ("  [" .. tostring(extra) .. "]") or "")) end
end

local CS = _G.choosers.cheatSheet
local function openSheet()
  for _, h in ipairs(HOTKEYS) do
    if h.key == "/" then h.fn(); return end
  end
  error("toggle hotkey not found")
end

realprint("== it is a chooser, configured to scroll ==")
check("cheat sheet is an hs.chooser", CS ~= nil)
check("registered in _G.choosers so nudging finds it", _G.choosers.cheatSheet ~= nil)
check("fixed row count (scrolls, does not grow)", CS.cfg.rows == 14, CS.cfg.rows)
check("wider than the 40% default", CS.cfg.width == 60, CS.cfg.width)
check("placeholder advertises search",
  CS.cfg.placeholder and CS.cfg.placeholder:lower():find("search", 1, true) ~= nil,
  CS.cfg.placeholder)
check("toggle/add/edit/remove all still bound", #HOTKEYS == 4, #HOTKEYS)

realprint("== single column, no canvas ==")
check("no canvas handle exists", _G.cheatSheetCanvas == nil)
check("no global Esc hotkey exists", _G.cheatSheetEscHotkey == nil)
openSheet()
check("opens visible", CS:isVisible() == true)
local all = CS._choices
check("renders a flat single-column list", #all > 50, #all)
local flat = true
for _, c in ipairs(all) do
  if type(c.text) ~= "string" then flat = false end
end
check("every row is one text string", flat)

realprint("== unfiltered view keeps group headers ==")
local headers, entries = 0, 0
for _, c in ipairs(all) do
  if c.cheatHeader then headers = headers + 1 else entries = entries + 1 end
end
check("headers present when not searching", headers > 10, headers)
check("entries present", entries > 40, entries)
check("headers are not selectable", (function()
  for _, c in ipairs(all) do
    if c.cheatHeader and c.cheatKeys ~= nil then return false end
  end
  return true
end)())
check("entries carry their group as subtitle", (function()
  for _, c in ipairs(all) do
    if c.cheatKeys and (not c.subText or c.subText == "") then return false end
  end
  return true
end)())

realprint("== searching ==")
CS:query("asana")
local hits = CS._choices
check("count row is first", hits[1].cheatHeader == true, hits[1].text)
check("count row reports a number", hits[1].text:find("%d") ~= nil, hits[1].text)
check("headers dropped while searching", (function()
  for i = 2, #hits do if hits[i].cheatHeader then return false end end
  return true
end)())
check("results narrowed", #hits < #all, #hits .. " of " .. #all)
check("every hit actually mentions asana", (function()
  for i = 2, #hits do
    local hay = (hits[i].text .. " " .. (hits[i].subText or "")):lower()
    if not hay:find("asana", 1, true) then return false end
  end
  return true
end)())

realprint("== multi-word search is AND, order-independent ==")
CS:query("asana task")
local a = #CS._choices
CS:query("task asana")
local b = #CS._choices
check("both orders agree", a == b, a .. " vs " .. b)
check("narrower than one word alone", a < #hits, a .. " vs " .. #hits)
CS:query("asana zzzznope")
check("a term that matches nothing empties it", #CS._choices == 1, #CS._choices)
check("empty search explains itself",
  CS._choices[1].subText:lower():find("try part of a key", 1, true) ~= nil,
  CS._choices[1].subText)

realprint("== spelled-out modifier names find glyph rows ==")
-- Nobody types ⇧ into a search box. These are the words they type.
for _, pair in ipairs({ { "shift", "⇧" }, { "cmd", "⌘" }, { "command", "⌘" },
                        { "alt", "⌥" }, { "option", "⌥" }, { "ctrl", "⌃" },
                        { "hyper", "⇪" }, { "capslock", "⇪" } }) do
  local word, glyph = pair[1], pair[2]

  -- How many rows carry this glyph in their KEYS at all?
  local expected = {}
  for _, c in ipairs(all) do
    if c.cheatKeys and c.cheatKeys:find(glyph, 1, true) then expected[c.text] = true end
  end
  local expectedN = 0
  for _ in pairs(expected) do expectedN = expectedN + 1 end

  CS:query(word)
  local got = {}
  for i = 2, #CS._choices do got[CS._choices[i].text] = true end
  local gotN = 0
  for _ in pairs(got) do gotN = gotN + 1 end

  check('"' .. word .. '" finds rows', gotN > 0, gotN)
  -- The direction that matters: searching the WORD must never miss a row
  -- that carries the GLYPH. Extra hits are fine and expected — "command"
  -- should also find the COMMAND HISTORY group, and the HELP row that
  -- documents this feature contains the words themselves.
  local missing
  for text in pairs(expected) do
    if not got[text] then missing = text; break end
  end
  check('"' .. word .. '" misses no ' .. glyph .. ' row (' .. expectedN .. ' of them)',
    missing == nil, missing)
end
CS:query("arrow")
check("\"arrow\" finds the arrow keys", #CS._choices - 1 > 0, #CS._choices - 1)
CS:query("⇪n")
check("searching the glyph itself still works", #CS._choices - 1 >= 1, #CS._choices - 1)
CS:query("shift asana")
check("modifier name combines with a word", #CS._choices - 1 >= 0)

realprint("== pattern-special characters must not crash ==")
-- A cheat sheet is FULL of ⇪[ ⇪\ ⇪- ⇪/ and typing one of those into a
-- search box would hand Lua's pattern engine a malformed pattern if the
-- match were not plain-text. Each of these is a real key on this sheet.
for _, q in ipairs({ "[", "]", "\\", "-", "%", "(", ")", ".", "+", "*", "?", "^", "$",
                     "%[", "[[", "((", "%%", "a-", "-a", "⇪[", "⇪\\" }) do
  local ok, err = pcall(function() CS:query(q) end)
  check("query " .. string.format("%q", q) .. " does not crash", ok, err)
end
CS:query("[")
check("bracket search returns the monitor keys", #CS._choices >= 2, #CS._choices)

realprint("== Enter copies the key combo ==")
CS:query("")
local firstEntry
for i, c in ipairs(CS._choices) do
  if c.cheatKeys and c.cheatKeys ~= "" then firstEntry = i; break end
end
COPIED = nil
CS:select(firstEntry)
check("copied something", COPIED ~= nil and COPIED ~= "", COPIED)
check("copied the key, not the description",
  COPIED == CS._choices[firstEntry].cheatKeys, COPIED)
COPIED = nil
for i, c in ipairs(CS._choices) do
  if c.cheatHeader then CS:select(i); break end
end
check("header row copies nothing", COPIED == nil, COPIED)
COPIED = nil
CS._fn(nil)
check("dismissal copies nothing", COPIED == nil)

realprint("== reopening clears a stale search ==")
CS:query("asana")
check("filtered before close", #CS._choices < #all)
CS:hide()
openSheet()
check("reopens unfiltered", #CS._choices == #all, #CS._choices .. " vs " .. #all)
check("query box cleared", CS:query() == "", CS:query())

realprint("== toggle ==")
check("visible after open", CS:isVisible() == true)
for _, h in ipairs(HOTKEYS) do if h.key == "/" then h.fn() end end
check("second press closes it", CS:isVisible() == false)
for _, h in ipairs(HOTKEYS) do if h.key == "/" then h.fn() end end
check("third press reopens it", CS:isVisible() == true)

realprint("== custom entries reach the sheet ==")
table.insert(_G.customShortcuts, { keys = "⌘⇧5", desc = "Screenshot menu", group = "MACOS" })
_G.cheatSheetRefreshIfOpen()
local found, groupFound = false, false
for _, c in ipairs(CS._choices) do
  if c.cheatKeys == "⌘⇧5" then found = true; if c.subText:find("MACOS") then groupFound = true end end
end
check("custom entry rendered while open", found)
check("custom group shown", groupFound)
CS:query("screenshot")
check("custom entry is searchable", (function()
  for i = 2, #CS._choices do
    if CS._choices[i].cheatKeys == "⌘⇧5" then return true end
  end
  return false
end)())

realprint("== refresh is a no-op when closed ==")
CS:hide()
local before = #CS._choices
table.insert(_G.customShortcuts, { keys = "⌘X", desc = "Later", group = "" })
_G.cheatSheetRefreshIfOpen()
check("closed sheet not re-rendered", #CS._choices == before, #CS._choices .. " vs " .. before)
openSheet()
check("next open picks it up", (function()
  for _, c in ipairs(CS._choices) do if c.cheatKeys == "⌘X" then return true end end
  return false
end)())

realprint("== render errors surface instead of blanking ==")
-- Blowing up cheatSheetRows does NOT work: ipairs on a string just
-- yields nothing, so the render succeeds with an empty list. Break the
-- matcher instead, which is code the render actually calls.
local savedMatch = _G.cheatSheetMatches
_G.cheatSheetMatches = function() error("injected failure") end
CS:query("boom")
check("bad state shows an error row, not a blank list", #CS._choices == 1, #CS._choices)
check("error row names the console",
  CS._choices[1].text:find("Console", 1, true) ~= nil, CS._choices[1].text)
_G.cheatSheetMatches = savedMatch

realprint("")
realprint(string.format("PASS %d   FAIL %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
