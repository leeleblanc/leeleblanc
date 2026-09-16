-- Renders the 🎵 Music Player's real page HTML to stdout, so the JS
-- harness (test_music_js.js) can execute the ACTUAL drawing, drop and
-- keyboard code instead of a hand-written copy of it.
--
--     lua5.4 dump_music_html.lua /path/to/modules [rows.json] > /tmp/music.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE — print is redirected to stderr.
--
-- 🚚 THE SECOND FILE IS THE POINT, and it is 6.203.0's rule: a harness
-- that hand-builds the payload the page receives cannot see a bug in the
-- SENDING. So the real `mp.rowsJson()` is written out for a queue holding
-- the names a file is really allowed to have — an ampersand, a pair of
-- angle brackets, a quote — and the JS suite draws THAT.
local MODDIR = arg[1] or "./modules"
local ROWS   = arg[2]
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  io.stderr:write(table.concat(p, " "), "\n")
end

-- a tiny JSON encoder, so the dump does not depend on Hammerspoon's
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
  timer   = { secondsSinceEpoch = function() return 1 end,
              doAfter = function() return { stop = function() end } end,
              doEvery = function() return { stop = function() end,
                                            start = function(s) return s end } end },
  alert   = { show = function() end },
  fs      = { attributes = function() end, mkdir = function() end },
  json    = { encode = function(t) return enc(t) end,
              decode = function() return nil end },
  sound   = { getByFile = function() return nil end },
  screen  = { mainScreen = function()
                return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end,
                         fullFrame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
              end },
  drawing = { windowLevels = { floating = 1 } },
  settings = { get = function() end, set = function() end },
  webview = { usercontent = { new = function() return { setCallback = function(s) return s end } end } },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local M = dofile(MODDIR .. "/music_player.lua")
M.setup({
  homeDir = "/nonexistent",
  provide = function() end,
  hyperAddShortcut = function() end,
})

local mp = _G.musicPlayer
if ROWS then
  -- the names a real music folder holds, plus the ones that break markup
  mp.queue = {
    { path = "/m/Simon & Garfunkel - The Sound of Silence.mp3",
      title = "Simon & Garfunkel - The Sound of Silence" },
    { path = "/m/AC-DC <Live> \"Bootleg\".m4a",
      title = 'AC-DC <Live> "Bootleg"' },
    { path = "/m/broken.flac", title = "broken",
      bad = ".flac does not play through macOS's own audio — convert it to m4a" },
  }
  mp.history = { { path = "/m/Simon & Garfunkel - The Sound of Silence.mp3",
                   title = "Simon & Garfunkel - The Sound of Silence", at = 1 } }
  mp.index, mp.sel, mp.mode, mp.playing = 1, 2, "all", true
  mp.refused = { { path = "/m/x.ogg", why = "<b>.ogg</b> is not an audio file this can play" } }
  local f = assert(io.open(ROWS, "w"))
  f:write(mp.rowsJson())
  f:close()
end

io.write(mp.buildHtml())
