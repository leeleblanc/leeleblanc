-- Renders 📝 HAMSIDIAN TABS' real page HTML to stdout, so the JS harness
-- (test_scratch_js.js) can execute the ACTUAL row drawing, the history
-- strip's click handling and the row walker instead of a hand-written
-- copy of them.
--
--     lua5.4 dump_scratch_html.lua /path/to/modules > /tmp/scratch.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE — print is redirected to stderr.
--
-- 🧪 WHY THIS EXISTS (6.364.0). Six pages this config draws had a suite
-- and this one did not — and it is the page holding his writing, with a
-- tab strip, a history strip and a row walker in it. 6.231.0 wrote the
-- rule after the music card shipped a page nothing ran: "A PAGE THIS
-- CONFIG DRAWS IS A PAGE THE GATE RUNS." The ✕ added in 6.364.0 is the
-- reason it could not wait: one handler serves the ✕ and the row it sits
-- inside, so a version that asks them in the wrong order RESTORES the tab
-- it was told to forget — and no amount of grepping the source proves the
-- order is right. Firing a real click does.
--
-- 🗂 THE ROWS ARE THE MODULE'S OWN (6.203.0): `sp.historyJson()` builds
-- the payload, so a bug in the SENDING is visible here rather than being
-- papered over by a hand-built fixture. The titles carry the characters a
-- real tab title is allowed to hold — an ampersand, angle brackets and a
-- quote — because those are what break markup.
local MODDIR = arg[1] or "./modules"
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  io.stderr:write(table.concat(p, " "), "\n")
end

local function enc(v)
  local t = type(v)
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      return ({ ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n',
                ['\r'] = '\\r', ['\t'] = '\\t' })[c]
             or string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  if t == "number"  then return tostring(v) end
  if t == "boolean" then return tostring(v) end
  if t ~= "table"   then return "null" end
  if v[1] ~= nil or next(v) == nil then
    local o = {}
    for _, x in ipairs(v) do o[#o + 1] = enc(x) end
    return "[" .. table.concat(o, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local o = {}
  for _, k in ipairs(keys) do o[#o + 1] = enc(k) .. ":" .. enc(v[k]) end
  return "{" .. table.concat(o, ",") .. "}"
end

hs = {
  timer    = { secondsSinceEpoch = function() return 1.4231 end,
               doAfter = function() return { stop = function() end } end,
               doEvery = function() return { stop = function() end,
                                             start = function(s) return s end } end,
               doAt = function() return { stop = function() end } end },
  alert    = { show = function() end },
  fs       = { attributes = function() end, mkdir = function() end,
               dir = function() return function() return nil end end },
  json     = { encode = function(t) return enc(t) end, decode = function() return nil end },
  screen   = { mainScreen = function()
                 return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end,
                          fullFrame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
               end },
  drawing  = { windowLevels = { floating = 1 } },
  settings = { get = function() end, set = function() end },
  pasteboard = { getContents = function() return "" end, setContents = function() return true end,
                 changeCount = function() return 1 end },
  webview  = { usercontent = { new = function() return { setCallback = function(s) return s end } end } },
  host     = { localizedName = function() return "TestMac" end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local M = dofile(MODDIR .. "/scratch_pad.lua")
M.setup({
  homeDir = "/nonexistent",
  logsDir = "/logs",
  provide = function() end,
  hyperAddShortcut = function() end,
  -- 🔬 IT CAN REFUSE, as macOS can (6.290.0): hs.pasteboard.setContents
  -- answers FALSE rather than throwing, and a stub that only ever says
  -- yes is a hole with a tick beside it. test_stub_fidelity §6b fails the
  -- gate for one that cannot — and it failed THIS file on the run that
  -- added it, which is the ratchet earning its place.
  copyText = function(t) if _G.COPY_REFUSES then return false, "macOS refused the write" end
                         _G.PB = t return true end,
})

local sp = _G.scratchPad
-- The OPEN tabs: one ordinary, one wearing the failed mark, so the suite
-- can tell a tab's own ✕ (close) from a history row's ✕ (forget).
sp.tabs = {
  { id = "t-open", text = "a draft I am typing", createdAt = 1, at = 1 },
  { id = "t-fail", text = "the one that did not send", createdAt = 1, at = 1 },
}
sp.active = "t-open"
-- The CLOSED tabs. The titles hold what a real one may: & < > and a quote.
sp.history = {
  { id = "h-amp",   title = "Simon & Garfunkel notes", text = "first closed",
    createdAt = 1, closedAt = 1700000000 },
  { id = "h-tag",   title = '<b>bold</b> and "quoted"', text = "second closed",
    createdAt = 1, closedAt = 1700000100 },
  { id = "h-plain", title = "ordinary tab", text = "third closed",
    createdAt = 1, closedAt = 1700000200 },
}
sp.filter = ""
io.write(sp.buildHtml())
