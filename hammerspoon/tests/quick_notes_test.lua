-- =====================================================================
-- Quick Notes → Asana — offline test suite
-- =====================================================================
-- Runs the X.2 block out of init.lua under a mock Hammerspoon, on any
-- machine, with no Hammerspoon and no network. It reads the block
-- straight out of init.lua, so it always tests the code you actually
-- ship rather than a copy that has drifted.
--
--     cd hammerspoon && lua5.4 tests/quick_notes_test.lua
--
-- Exit status is 0 only if every check passes.
-- =====================================================================

-- Mock-Hammerspoon harness: loads the Quick Notes block for real and
-- exercises it. Catches load-time errors and logic bugs that a syntax
-- check cannot.

local TMP = os.getenv("QN_TMP") or "/tmp/qn_test"
os.execute("rm -rf " .. TMP .. " && mkdir -p " .. TMP)

-- ---------- minimal JSON ----------
local json = {}
local function esc(s)
  return (s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n' elseif c == '\r' then return '\\r'
    elseif c == '\t' then return '\\t' else return string.format('\\u%04x', c:byte()) end
  end))
end
local function enc(v)
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" then return tostring(v)
  elseif t == "number" then return tostring(v)
  elseif t == "string" then return '"' .. esc(v) .. '"'
  elseif t == "table" then
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n == #v and n > 0 then
      local out = {}
      for _, x in ipairs(v) do out[#out+1] = enc(x) end
      return "[" .. table.concat(out, ",") .. "]"
    elseif n == 0 then return "{}"
    else
      local keys = {}
      for k in pairs(v) do keys[#keys+1] = tostring(k) end
      table.sort(keys)
      local out = {}
      for _, k in ipairs(keys) do
        -- `false` is a value, not an absence: the obvious
        -- `v[k] ~= nil and v[k] or ...` idiom silently turns it into null.
        local val = v[k]
        if val == nil then val = v[tonumber(k)] end
        out[#out+1] = '"' .. esc(k) .. '":' .. enc(val)
      end
      return "{" .. table.concat(out, ",") .. "}"
    end
  end
  return "null"
end
json.encode = enc
function json.decode(s)
  local pos = 1
  local function skip() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
  local parse
  local function pstr()
    pos = pos + 1
    local buf = {}
    while true do
      local c = s:sub(pos, pos)
      if c == "" then error("unterminated string") end
      if c == '"' then pos = pos + 1; break end
      if c == "\\" then
        local n = s:sub(pos+1, pos+1)
        local m = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if n == "u" then
          buf[#buf+1] = utf8.char(tonumber(s:sub(pos+2, pos+5), 16)); pos = pos + 6
        else buf[#buf+1] = m[n] or n; pos = pos + 2 end
      else buf[#buf+1] = c; pos = pos + 1 end
    end
    return table.concat(buf)
  end
  parse = function()
    skip()
    local c = s:sub(pos, pos)
    if c == "{" then
      pos = pos + 1; local o = {}
      skip()
      if s:sub(pos, pos) == "}" then pos = pos + 1; return o end
      while true do
        skip(); local k = pstr(); skip()
        pos = pos + 1 -- ':'
        o[k] = parse(); skip()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "}" then break end
      end
      return o
    elseif c == "[" then
      pos = pos + 1; local a = {}
      skip()
      if s:sub(pos, pos) == "]" then pos = pos + 1; return a end
      while true do
        a[#a+1] = parse(); skip()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "]" then break end
      end
      return a
    elseif c == '"' then return pstr()
    elseif s:sub(pos, pos+3) == "true" then pos = pos + 4; return true
    elseif s:sub(pos, pos+4) == "false" then pos = pos + 5; return false
    elseif s:sub(pos, pos+3) == "null" then pos = pos + 4; return nil
    else
      local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num then error("bad json at " .. pos) end
      pos = pos + #num; return tonumber(num)
    end
  end
  local ok, res = pcall(parse)
  if not ok then return nil end
  return res
end

-- ---------- mock hs ----------
ALERTS, PRINTS, TIMERS, HOTKEYS, HTTP = {}, {}, {}, {}, {}
local realprint = print
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring((select(i, ...))) end
  PRINTS[#PRINTS+1] = table.concat(parts, " ")
end

local function chooserNew(fn)
  local c = { _fn = fn, _choices = {}, _visible = false, _query = "" }
  function c:choices(t) self._choices = t; return self end
  function c:placeholderText(s) return self end
  function c:width(n) return self end
  function c:queryChangedCallback(f) self._qcb = f; return self end
  function c:query(q) self._query = q; if self._qcb then self._qcb(q) end; return self end
  function c:show() self._visible = true; return self end
  function c:hide() self._visible = false; return self end
  function c:isVisible() return self._visible end
  function c:select(i) return self._fn(self._choices[i]) end
  return c
end

local canvasStore = {}
hs = {
  configdir = TMP,
  json = json,
  host = { localizedName = function() return "Test-Mac" end, idleTime = function() return 1 end },
  alert = { show = function(m, d) ALERTS[#ALERTS+1] = tostring(m) end },
  chooser = { new = chooserNew },
  hotkey = {
    new = function(mods, key, fn)
      local h = { mods = mods, key = key, fn = fn, enabled = false }
      function h:enable() self.enabled = true; return self end
      function h:disable() self.enabled = false; return self end
      function h:delete() return self end
      HOTKEYS[#HOTKEYS+1] = h
      return h
    end,
    bind = function() return { enable = function() end, disable = function() end } end,
  },
  timer = {
    doAt    = function(t, r, f) local o = { kind = "doAt", at = t, fn = f }; TIMERS[#TIMERS+1] = o; return o end,
    doEvery = function(s, f) local o = { kind = "doEvery", sec = s, fn = f }; TIMERS[#TIMERS+1] = o; return o end,
    doAfter = function(s, f) local o = { kind = "doAfter", sec = s, fn = f }; TIMERS[#TIMERS+1] = o; return o end,
  },
  settings = {
    _v = {},
    set = function(k, v) hs.settings._v[k] = v end,
    get = function(k) return hs.settings._v[k] end,
  },
  http = {
    asyncGet  = function(u, h, cb) HTTP[#HTTP+1] = { m = "GET", url = u, cb = cb } end,
    asyncPost = function(u, b, h, cb) HTTP[#HTTP+1] = { m = "POST", url = u, body = b, cb = cb } end,
  },
  screen = { mainScreen = function() return { frame = function() return { x = 0, y = 0, w = 1920, h = 1080 } end } end },
  canvas = {
    windowLevels = { floating = 3, overlay = 102 },
    new = function(f)
      local c = setmetatable({ _f = f, _els = {}, _shown = false },
        { __len = function(s) return #s._els end })
      function c:level() return self end
      function c:behaviorAsLabels() return self end
      function c:canvasMouseEvents() return self end
      function c:frame(r) if r then self._f = r end; return self._f end
      if not NO_REPLACE then
        function c:replaceElements(els) self._els = els; return self end
      end
      function c:removeElement(i) table.remove(self._els, i or #self._els); return self end
      function c:appendElements(els)
        for _, e in ipairs(els) do self._els[#self._els+1] = e end
        return self
      end
      function c:show() self._shown = true; return self end
      function c:hide() self._shown = false; return self end
      function c:delete() self._shown = false; return self end
      canvasStore[#canvasStore+1] = c
      return c
    end,
  },
  dialog = { textPrompt = function() return "Cancel", "" end },
  pasteboard = { setContents = function() return true end },
  urlevent = { openURL = function(u) OPENED = u; return true end },
  notify = { new = function() return { send = function() end } end },
  fs = { mkdir = function() return true end },
  eventtap = { keyStroke = function() end },
}

-- ---------- the upvalues the block borrows from init.lua ----------
logsDir = TMP
hostTag = "Test-Mac"
asanaToken = "2/1/1:deadbeef"
asanaEnabled = true
asanaProjectId = "745948257030523"
function csvQuote(v)
  local s = tostring(v or ""):gsub("[\r\n]+", " "):gsub('"', '""')
  return '"' .. s .. '"'
end
function showPopup(c) c:show() end
function warnWriteFailed(l) WRITEFAIL = l end
function resolveBaseScreen() return hs.screen.mainScreen() end
function requireAsana() return asanaEnabled end
_G.choosers = {}
_G.hyperMods = { "cmd", "shift", "ctrl", "alt" }
_G.hyperPending = {}
function _G.hyperAddShortcut(mods, key, fn, source)
  _G.hyperPending[#_G.hyperPending+1] = { mods = mods, key = key, fn = fn, source = source }
end

-- ---------- pull the X.2 block straight out of init.lua ----------
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local initPath = os.getenv("QN_INIT") or (here .. "/../init.lua")
local fh = assert(io.open(initPath, "r"), "cannot open " .. initPath)
local full = fh:read("*a"); fh:close()

local marker = full:find("%-%- X%.2 QUICK NOTES")
assert(marker, "X.2 Quick Notes block not found in " .. initPath)
local s = full:find(";%(function%(%)", marker)
local e = full:find("end%)%(%) %-%- X%.2 Quick Notes", s)
assert(s and e, "could not delimit the X.2 block")
local block = full:sub(s, full:find("\n", e) or #full)

local chunk = assert(load(block, "@quick-notes-block"))
chunk()

-- ---------- tests ----------
local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1
  else fail = fail + 1; realprint("  FAIL: " .. name .. (extra and ("  [" .. tostring(extra) .. "]") or "")) end
end

realprint("== title / verb detection ==")
local t = _G.qnTitleForTest
check("verb kept as-is", t("Email Dana the invoice") == "Email Dana the invoice", t("Email Dana the invoice"))
check("lowercase verb", t("fix the printer") == "fix the printer", t("fix the printer"))
check("non-verb prefixed", t("printer toner low") == "Task from notes: printer toner low", t("printer toner low"))
check("noun-first prefixed", t("meeting notes from Tuesday") == "Task from notes: meeting notes from Tuesday", t("meeting notes from Tuesday"))
-- "budget" is a real task verb ("Budget for Q3"), so a noun use of it is
-- read as imperative. First-word detection cannot tell these apart; the
-- honest outcome is a slightly odd title, never a wrong one.
check("verb-shaped noun kept (known limit)", t("budget numbers for Q3") == "budget numbers for Q3", t("budget numbers for Q3"))
check("please stripped for probe", t("Please send the deck") == "Please send the deck", t("Please send the deck"))
check("hyphen verb", t("Re-check the invoice") == "Re-check the invoice", t("Re-check the invoice"))
check("bullet stripped", t("- call Sam") == "call Sam", t("- call Sam"))
check("TODO stripped", t("TODO: review the PR") == "review the PR", t("TODO: review the PR"))
check("empty -> nil", t("") == nil)
check("whitespace -> nil", t("   ") == nil)
local _, isv = t("printer toner low")
check("isVerb false reported", isv == false)
local _, isv2 = t("Review the PR")
check("isVerb true reported", isv2 == true)
local long = t(string.rep("build ", 100))
check("long title clipped", #long <= 244, #long)

realprint("== qwerty cleaning ==")
local cl = _G.qnCleanForTest
check("smart quotes folded", cl("don\u{2019}t") == "don't", cl("don\u{2019}t"))
check("em dash folded", cl("3\u{2014}4pm") == "3-4pm", cl("3\u{2014}4pm"))
check("ellipsis folded", cl("wait\u{2026}") == "wait...", cl("wait\u{2026}"))
check("emoji dropped", cl("hello \u{1F600} world") == "hello world", cl("hello \u{1F600} world"))
check("cjk dropped", cl("a \u{4E2D}\u{6587} b") == "a b", cl("a \u{4E2D}\u{6587} b"))
check("newline collapsed", cl("a\nb") == "a b", cl("a\nb"))
check("nbsp folded", cl("a\u{00A0}b") == "a b", cl("a\u{00A0}b"))
check("bullet folded", cl("\u{2022} item") == "* item", cl("\u{2022} item"))
check("nil safe", cl(nil) == "")
check("pure ascii untouched", cl("Fix the printer (v2) 50% #3") == "Fix the printer (v2) 50% #3")

realprint("== csv round trip ==")
local sp = _G.qnSplitCSVForTest
local r = sp('2026-08-03,14:22,"note, with comma","said ""hi""",stmt,pending,,,')
check("comma in field", r[3] == "note, with comma", r[3])
check("escaped quotes", r[4] == 'said "hi"', r[4])
check("field count", #r == 9, #r)

local add = _G.qnAddForTest
add("Email Dana the invoice")
add("printer toner low")
add("note, with comma and \"quotes\"")
_G.qnSaveForTest()
local before = #_G.qnRowsForTest()
_G.qnLoadForTest()
local after = _G.qnRowsForTest()
check("rows survive save/load", #after == before, before .. " -> " .. #after)
check("comma note intact", after[3].note == 'note, with comma and "quotes"', after[3].note)
check("title persisted", after[2].title == "Task from notes: printer toner low", after[2].title)
check("status pending", after[1].status == "pending", after[1].status)
check("date shape", after[1].date:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil, after[1].date)
check("stmt is ascii", after[1].stmt:match("^[\32-\126]+$") ~= nil, after[1].stmt)
check("pending count", #_G.qnPendingForTest() == 3, #_G.qnPendingForTest())

realprint("== malformed rows are dropped, not posted ==")
local f = io.open(_G.qnFileForTest, "a"); f:write("garbage,row\n2026-13-99,99:99,x,,,,,,\n"); f:close()
_G.qnLoadForTest()
check("bad rows dropped", #_G.qnRowsForTest() == 3, #_G.qnRowsForTest())
local sawDrop = false
for _, p in ipairs(PRINTS) do if p:find("dropped") then sawDrop = true end end
check("drop was reported", sawDrop)

realprint("== date/time range validation (not just shape) ==")
local vd, vt = _G.qnValidDateForTest, _G.qnValidTimeForTest
check("month 13 rejected", vd("2026-13-09") == false)
check("day 99 rejected", vd("2026-01-99") == false)
check("day 00 rejected", vd("2026-01-00") == false)
check("month 00 rejected", vd("2026-00-09") == false)
check("real date accepted", vd("2026-08-03") == true)
check("hour 99 rejected", vt("99:22") == false)
check("hour 24 rejected", vt("24:00") == false)
check("minute 60 rejected", vt("10:60") == false)
check("real time accepted", vt("16:00") == true)
check("midnight accepted", vt("00:00") == true)
check("nil rejected", vd(nil) == false and vt(nil) == false)

realprint("== due logic ==")
hs.settings._v["qnLastRunDate"] = os.date("%Y-%m-%d")
check("not due once run today", _G.qnRunIsDueForTest() == false)
hs.settings._v["qnLastRunDate"] = "2000-01-01"
local hnow = tonumber(os.date("%H"))
check("due iff past post time", _G.qnRunIsDueForTest() == (hnow >= 16), "hour=" .. hnow)

realprint("== wiring ==")
check("4 hyper shortcuts", #_G.hyperPending == 4, #_G.hyperPending)
local keys = {}
for _, p in ipairs(_G.hyperPending) do
  keys[#keys+1] = ((p.mods[1] == "shift") and "shift+" or "") .. p.key
end
table.sort(keys)
check("keys are n/shift+g/shift+n/shift+p", table.concat(keys, ",") == "n,shift+g,shift+n,shift+p", table.concat(keys, ","))
check("daily timer at 16:00", TIMERS[1] and TIMERS[1].at == "16:00", TIMERS[1] and TIMERS[1].at)
check("choosers registered", _G.choosers.quickNote ~= nil and _G.choosers.quickNoteHistory ~= nil
  and _G.choosers.quickNoteFields ~= nil and _G.choosers.quickNoteEnum ~= nil)

realprint("== capture chooser ==")
local qc = _G.choosers.quickNote
qc:query("call the vendor")
check("save row first", qc._choices[1].qnAction == "save", qc._choices[1].qnAction)
check("save row text is the note", qc._choices[1].text == "\u{2795} call the vendor", qc._choices[1].text)
check("fields row second", qc._choices[2].qnAction == "savefields")
check("no verb notice absent for verb", qc._choices[3] == nil)
qc:query("printer toner low")
check("verb notice shown for non-verb", qc._choices[3] and qc._choices[3].qnAction == "noop")
qc:query("")
check("empty query shows hint", qc._choices[1].qnAction == "noop")
local sawSend = false
for _, c in ipairs(qc._choices) do if c.qnAction == "sendnow" then sawSend = true end end
check("send-now row when pending", sawSend)

local n0 = #_G.qnRowsForTest()
qc:query("Draft the release notes")
qc:select(1)
check("Enter on row 1 saves", #_G.qnRowsForTest() == n0 + 1, #_G.qnRowsForTest())
check("saved with verb title", _G.qnRowsForTest()[n0+1].title == "Draft the release notes",
  _G.qnRowsForTest()[n0+1].title)

realprint("== history chooser ==")
local hc = _G.choosers.quickNoteHistory
hc:query("")
check("history header first", hc._choices[1].qnAction == "noop")
hc:query("printer")
local hits = 0
for _, c in ipairs(hc._choices) do if c.qnAction == "open" then hits = hits + 1 end end
check("search narrows to 1", hits == 1, hits)
hc:query("zzzznope")
local hits2 = 0
for _, c in ipairs(hc._choices) do if c.qnAction == "open" then hits2 = hits2 + 1 end end
check("no matches -> 0 rows", hits2 == 0, hits2)

realprint("== posting ==")
ALERTS = {}
local pend = #_G.qnPendingForTest()
_G.hyperPending[4].fn()   -- shift+G = send now
check("one POST in flight", #HTTP == 1, #HTTP)
check("posts to /tasks", HTTP[1].url:find("/api/1.0/tasks", 1, true) ~= nil, HTTP[1].url)
local body = json.decode(HTTP[1].body)
check("payload has name", type(body.data.name) == "string", body.data.name)
check("payload on personal project", body.data.projects[1] == asanaProjectId, body.data.projects[1])
check("notes carry date statement", body.data.notes:find("Captured: ", 1, true) ~= nil)
check("no custom_fields when none picked", body.data.custom_fields == nil)
HTTP[1].cb(201, json.encode({ data = { gid = "111", permalink_url = "https://app.asana.com/0/1/111" } }))
check("row marked posted", _G.qnRowsForTest()[1].status == "posted", _G.qnRowsForTest()[1].status)
check("url stored", _G.qnRowsForTest()[1].url == "https://app.asana.com/0/1/111", _G.qnRowsForTest()[1].url)
-- drain the sequential queue
local guard = 0
while guard < 50 do
  guard = guard + 1
  local ran = false
  for i = #TIMERS, 1, -1 do
    if TIMERS[i].kind == "doAfter" then local fn = TIMERS[i].fn; table.remove(TIMERS, i); fn(); ran = true; break end
  end
  if not ran then break end
  if #HTTP > 0 then
    local h = table.remove(HTTP, 1)
    if h.m == "POST" then h.cb(201, json.encode({ data = { gid = "x", permalink_url = "u" } })) end
  end
end
local stillPending = #_G.qnPendingForTest()
check("all pending drained", stillPending == 0, stillPending)
local sawSuccess = false
for _, a in ipairs(ALERTS) do if a:find("sent to Asana", 1, true) then sawSuccess = true end end
check("success message posted", sawSuccess, table.concat(ALERTS, " | "))

realprint("== failure path ==")
add("Check the backups")
_G.hyperPending[4].fn()
local hp = HTTP[#HTTP]
hp.cb(401, '{"errors":[{"message":"Not Authorized"}]}')
local failedRow
for _, rr in ipairs(_G.qnRowsForTest()) do if rr.status == "failed" then failedRow = rr end end
check("401 marks row failed", failedRow ~= nil)
check("401 does not fabricate a url", failedRow and failedRow.url == "", failedRow and failedRow.url)

realprint("== panel ==")
_G.qnPanelShowForTest()
check("canvas created", canvasStore[#canvasStore]._shown == true)
local els = canvasStore[#canvasStore]._els
check("panel has elements", #els > 3, #els)
local digitKeys, escKey = 0, false
for _, h in ipairs(HOTKEYS) do
  if h.enabled and h.key == "escape" then escKey = true end
  if h.enabled and tonumber(h.key) then digitKeys = digitKeys + 1 end
end
check("escape enabled with panel", escKey)
check("digit keys enabled (bare + hyper = 18)", digitKeys == 18, digitKeys)
-- Row 1 is the newest note, which at this point is the one the 401
-- rejected. Pressing its digit must NOT invent a link.
OPENED = nil
for _, h in ipairs(HOTKEYS) do if h.enabled and h.key == "1" then h.fn(); break end end
check("digit on a failed row opens nothing", OPENED == nil, OPENED)
-- ...and a posted row's digit does open it. Find where that row landed.
local posIdx
local rowsNow = _G.qnRowsForTest()
for i = #rowsNow, 1, -1 do
  if rowsNow[i].status == "posted" then posIdx = #rowsNow - i + 1; break end
end
check("a posted row is on the panel", posIdx ~= nil and posIdx <= 9, posIdx)
OPENED = nil
for _, h in ipairs(HOTKEYS) do
  if h.enabled and h.key == tostring(posIdx) then h.fn(); break end
end
check("digit on a posted row opens its url", OPENED ~= nil, OPENED)
_G.qnPanelHideForTest()
local stillEnabled = 0
for _, h in ipairs(HOTKEYS) do if h.enabled then stillEnabled = stillEnabled + 1 end end
check("all panel keys released on hide", stillEnabled == 0, stillEnabled)

realprint("== panel row cap ==")
for i = 1, 20 do add("Ship item " .. i) end
_G.qnPanelShowForTest()
local rowsDrawn = 0
for _, e in ipairs(canvasStore[#canvasStore]._els) do
  if e.type == "circle" then rowsDrawn = rowsDrawn + 1 end
end
check("panel caps at 9 rows", rowsDrawn == 9, rowsDrawn)
_G.qnPanelHideForTest()

realprint("== custom fields: fetch & parse ==")
HTTP = {}
local fetched = nil
_G.qnFieldsFetchTest(function(ok, err) fetched = ok end)
check("fetch asks for custom_field_settings",
  HTTP[1] and HTTP[1].url:find("custom_field_settings", 1, true) ~= nil, HTTP[1] and HTTP[1].url)
check("fetch requests enum options",
  HTTP[1].url:find("enum_options.gid", 1, true) ~= nil)
HTTP[1].cb(200, json.encode({ data = {
  { custom_field = { gid = "10", name = "Priority", resource_subtype = "enum",
      enum_options = { { gid = "101", name = "High", enabled = true },
                       { gid = "102", name = "Low",  enabled = true },
                       { gid = "103", name = "Retired", enabled = false } } } },
  { custom_field = { gid = "20", name = "Effort", resource_subtype = "number" } },
  { custom_field = { gid = "30", name = "Due date", resource_subtype = "date" } },
  { custom_field = { gid = "40", name = "Notes field", resource_subtype = "text" } },
  { custom_field = { gid = "50", name = "Tags", resource_subtype = "multi_enum",
      enum_options = { { gid = "501", name = "ops" }, { gid = "502", name = "urgent" } } } },
  { name = "malformed, no gid" },
} }))
check("fetch succeeded", fetched == true)
local F = _G.qnFieldsForTest()
check("5 well-formed fields kept", #F == 5, #F)
check("malformed field skipped", F[6] == nil)
check("disabled enum option dropped", #F[1].options == 2, #F[1].options)
check("field kind read", F[1].kind == "enum" and F[2].kind == "number"
  and F[5].kind == "multi_enum", F[1].kind .. "/" .. F[2].kind .. "/" .. F[5].kind)
check("fetch failure surfaces", (function()
  HTTP = {}
  local r
  _G.qnFieldsFetchTest(function(ok) r = ok end)
  HTTP[1].cb(500, "boom")
  return r == false
end)())

realprint("== custom fields: picker rows ==")
local target = _G.qnRowsForTest()[#_G.qnRowsForTest()]
target.fields = {}
_G.qnFieldsPickTest(target)
local fc = _G.choosers.quickNoteFields
check("done row first", fc._choices[1].qnAction == "done", fc._choices[1].qnAction)
check("done says no fields", fc._choices[1].text:find("no custom fields", 1, true) ~= nil, fc._choices[1].text)
check("set-all row present", fc._choices[2].qnAction == "all")
check("no clear row when empty", fc._choices[3].qnAction == "refresh", fc._choices[3].qnAction)
local fieldRows = 0
for _, c in ipairs(fc._choices) do if c.qnAction == "field" then fieldRows = fieldRows + 1 end end
check("all 5 fields listed", fieldRows == 5, fieldRows)
fc:query("prior")
local narrowed = 0
for _, c in ipairs(fc._choices) do if c.qnAction == "field" then narrowed = narrowed + 1 end end
check("field search narrows", narrowed == 1, narrowed)

realprint("== custom fields: enum pick ==")
fc:query("")
for i, c in ipairs(fc._choices) do
  if c.qnAction == "field" and _G.qnFieldsForTest()[c.qnField].name == "Priority" then
    fc:select(i); break
  end
end
-- the picker chains through a doAfter; drain it
local function drainTimers(max)
  for _ = 1, (max or 20) do
    local ran = false
    for i = 1, #TIMERS do
      if TIMERS[i].kind == "doAfter" then
        local fn = TIMERS[i].fn; table.remove(TIMERS, i); fn(); ran = true; break
      end
    end
    if not ran then return end
  end
end
drainTimers()
local ec = _G.choosers.quickNoteEnum
check("enum chooser opened", ec._visible == true)
check("enum offers a no-value row", ec._choices[1].qnAction == "none", ec._choices[1].qnAction)
local highIdx
for i, c in ipairs(ec._choices) do if c.text == "High" then highIdx = i end end
check("enabled options shown", highIdx ~= nil)
ec:select(highIdx)
drainTimers()
check("enum value stored", target.fields["10"] ~= nil and target.fields["10"].value == "101",
  target.fields["10"] and target.fields["10"].value)
check("enum label stored", target.fields["10"].label == "High", target.fields["10"].label)

realprint("== custom fields: multi_enum toggle ==")
target.fields["50"] = nil
for i, c in ipairs(fc._choices) do
  if c.qnAction == "field" and _G.qnFieldsForTest()[c.qnField].name == "Tags" then
    fc:select(i); break
  end
end
drainTimers()
local opsIdx, urgIdx
for i, c in ipairs(ec._choices) do
  if c.text:find("ops", 1, true) then opsIdx = i end
  if c.text:find("urgent", 1, true) then urgIdx = i end
end
ec:select(opsIdx); drainTimers()
check("multi adds first", #target.fields["50"].value == 1, target.fields["50"] and #target.fields["50"].value)
for i, c in ipairs(ec._choices) do if c.text:find("urgent", 1, true) then urgIdx = i end end
ec:select(urgIdx); drainTimers()
check("multi adds second", #target.fields["50"].value == 2, #target.fields["50"].value)
check("multi label joins", target.fields["50"].label:find("ops", 1, true) ~= nil
  and target.fields["50"].label:find("urgent", 1, true) ~= nil, target.fields["50"].label)
local offIdx
for i, c in ipairs(ec._choices) do if c.text == "\u{2713} ops" then offIdx = i end end
check("checked option is marked", offIdx ~= nil)
ec:select(offIdx); drainTimers()
check("multi removes on re-pick", #target.fields["50"].value == 1, #target.fields["50"].value)
check("remaining is urgent", target.fields["50"].value[1] == "502", target.fields["50"].value[1])

realprint("== custom fields: payload shapes ==")
target.fields = {
  ["10"] = { kind = "enum",       value = "101",           label = "High" },
  ["20"] = { kind = "number",     value = 3,               label = "3" },
  ["30"] = { kind = "date",       value = "2026-08-09",    label = "2026-08-09" },
  ["40"] = { kind = "text",       value = "hello",         label = "hello" },
  ["50"] = { kind = "multi_enum", value = { "501", "502" }, label = "ops, urgent" },
}
local pl = _G.qnFieldsPayloadTest(target)
check("enum -> gid string", pl["10"] == "101", tostring(pl["10"]))
check("number -> number", pl["20"] == 3 and type(pl["20"]) == "number", type(pl["20"]))
check("date -> {date=}", type(pl["30"]) == "table" and pl["30"].date == "2026-08-09", enc(pl["30"]))
check("text -> string", pl["40"] == "hello")
check("multi_enum -> array", type(pl["50"]) == "table" and #pl["50"] == 2, enc(pl["50"]))
check("empty selection -> nil", _G.qnFieldsPayloadTest({ fields = {} }) == nil)
check("summary reads well", _G.qnFieldsSummaryTest(target):find("Priority: High", 1, true) ~= nil,
  _G.qnFieldsSummaryTest(target))

realprint("== custom fields: survive save/load and reach Asana ==")
_G.qnSaveForTest()
_G.qnLoadForTest()
local reloaded = _G.qnRowsForTest()[#_G.qnRowsForTest()]
check("fields survive the CSV", reloaded.fields["10"] and reloaded.fields["10"].value == "101",
  reloaded.fields["10"] and reloaded.fields["10"].value)
check("multi survives as array", type(reloaded.fields["50"].value) == "table"
  and #reloaded.fields["50"].value == 2, enc(reloaded.fields["50"].value))
check("number survives as number", reloaded.fields["20"].value == 3
  and type(reloaded.fields["20"].value) == "number", type(reloaded.fields["20"].value))
-- Sends are deliberately SEQUENTIAL (one POST, wait, next), so the queue
-- has to be walked rather than read off in one go.
local function drainPosts(rounds)
  local bodies = {}
  for _ = 1, (rounds or 200) do
    local moved = false
    if #HTTP > 0 then
      local h = table.remove(HTTP, 1)
      if h.m == "POST" then
        bodies[#bodies+1] = json.decode(h.body)
        h.cb(201, json.encode({ data = { gid = "9", permalink_url = "https://app.asana.com/0/1/9" } }))
        moved = true
      end
    end
    for i = 1, #TIMERS do
      if TIMERS[i].kind == "doAfter" then
        local fn = TIMERS[i].fn; table.remove(TIMERS, i); fn(); moved = true; break
      end
    end
    if not moved then break end
  end
  return bodies
end

reloaded.status = "pending"
HTTP = {}
_G.hyperPending[4].fn()
local bodies = drainPosts()
check("every pending note was sent", #bodies == #_G.qnPendingForTest() + #bodies, "sent " .. #bodies)
check("nothing left pending", #_G.qnPendingForTest() == 0, #_G.qnPendingForTest())
local withFields
for _, b in ipairs(bodies) do
  if b.data and b.data.custom_fields then withFields = b.data.custom_fields end
end
check("custom_fields reached Asana", withFields ~= nil)
check("all 5 fields sent", (function()
  if not withFields then return false end
  local n = 0
  for _ in pairs(withFields) do n = n + 1 end
  return n == 5
end)(), withFields and enc(withFields))
-- Exactly one note had fields attached, so exactly one payload may carry
-- them. This is the check that would catch rows sharing a fields table.
check("only the one note carries custom_fields", (function()
  local n = 0
  for _, b in ipairs(bodies) do
    if b.data and b.data.custom_fields ~= nil then n = n + 1 end
  end
  return n == 1, n
end)())

realprint("== a note with no fields still posts clean ==")
HTTP = {}
add("Renew the domain")
_G.hyperPending[4].fn()
local plainBodies = drainPosts()
local plain
for _, b in ipairs(plainBodies) do
  if b.data and b.data.name == "Renew the domain" then plain = b end
end
check("plain note was posted", plain ~= nil)
check("no custom_fields key", plain and plain.data.custom_fields == nil)
check("name is the verb title", plain and plain.data.name == "Renew the domain", plain and plain.data.name)
check("projects is the personal project", plain and plain.data.projects[1] == asanaProjectId)



realprint("== panel fallback when replaceElements is unavailable ==")
NO_REPLACE = true
_G.qnPanelHideForTest()
_G.qnPanelShowForTest()
local fb = canvasStore[#canvasStore]._els
check("fallback still populates the panel", #fb > 3, #fb)
local fbRows = 0
for _, e in ipairs(fb) do if e.type == "circle" then fbRows = fbRows + 1 end end
check("fallback draws the rows too", fbRows == 9, fbRows)
_G.qnPanelHideForTest()
NO_REPLACE = false

realprint("== boot report line ==")
check("boot status exists", type(_G.qnStatusForBoot) == "function")
local st = _G.qnStatusForBoot()
check("boot status mentions notes", st:find("note", 1, true) ~= nil, st)
check("boot status mentions send time", st:find("16:00", 1, true) ~= nil, st)
realprint("   boot line: " .. st)

realprint("")
realprint(string.format("PASS %d   FAIL %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
