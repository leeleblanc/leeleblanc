-- Renders the 🎬 Mug Player's real page HTML to stdout, so the JS
-- harness (test_mug_js.js) executes the ACTUAL drawing, drop and
-- keyboard code instead of a hand-written copy of it.
--
--     lua5.4 dump_mug_html.lua /path/to/modules [rows.json] > /tmp/mug.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE — print is redirected to stderr.
--
-- 🚚 THE SECOND FILE IS THE POINT (6.203.0): a harness that hand-builds
-- the payload the page receives cannot see a bug in the SENDING. So the
-- real `vid.rowsJson()` is written out for a queue holding the names a
-- film file is really allowed to have — an ampersand, angle brackets, a
-- quote, an apostrophe, a percent and a hash — and the JS suite draws
-- THAT.
local MODDIR = arg[1] or "./modules"
local ROWS   = arg[2]
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
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" then return "null" end
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
  timer   = { doAfter = function() return { stop = function() end } end,
              doEvery = function() return { stop = function() end } end },
  fs      = { mkdir = function() return true end },
  alert   = { show = function() end },
  window  = { focusedWindow = function() return nil end },
  screen  = { mainScreen = function()
                return { frame = function()
                  return { x = 0, y = 0, w = 1440, h = 900 } end } end,
              allScreens = function() return {} end },
  drawing = { windowLevels = { floating = 5 } },
  canvas  = { windowLevels = { dragging = 11 }, new = function() return nil end },
  task    = { new = function() return { start = function() return true end } end },
  json    = { encode = function(v) return enc(v) end, decode = function() return nil end },
  webview = { usercontent = { new = function() return
                { setCallback = function() end } end },
              new = function() return nil end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.service = { has = function() return false end, call = function() return nil end }

local CORE = {
  homeDir = "/Users/lee",
  hyperAddShortcut = function() end,
  provide = function() end,
  degrade = function() return false end,
}
local M = assert(loadfile(MODDIR .. "/video_player.lua"))()
M.setup(CORE)
local vid = _G.mugPlayer

-- 🔤 Names a film file is really allowed to have. Every one of these has
-- broken a page in this config at least once.
vid.queue = {
  { path = "/F/Simon & Garfunkel.mp4" },
  { path = "/F/<Live> at the \"Apollo\".mp4" },
  { path = "/F/Don't Look Up 50% #2.mp4" },
}
for _, t in ipairs(vid.queue) do t.title = vid.titleOf(t.path) end
vid.history = { { path = "/F/Old & Grey.mp4", title = "Old & Grey", at = 1 } }
vid.index, vid.sel, vid.selList = 1, 1, "queue"

if ROWS then
  local f = assert(io.open(ROWS, "w"))
  f:write(vid.rowsJson())
  f:close()
end

-- The page is built through the module's own builder, reached the only
-- way a test can reach a local: by rendering with the real show() path
-- disabled. vid.buildPage is published for exactly this.
io.write(vid.buildPage())
