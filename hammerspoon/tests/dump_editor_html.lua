-- Renders the Screenshot Editor's real page HTML to stdout, so the JS
-- harness (test_editor_js.js) can execute the ACTUAL blur code instead
-- of a hand-written copy of it. Same contract as dump_pad_html.lua:
--
--     lua5.4 dump_editor_html.lua /path/to/modules > /tmp/editor.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE — print is redirected to stderr.
local MODDIR = arg[1] or "./modules"
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  io.stderr:write(table.concat(p, " "), "\n")
end
hs = {
  timer = { secondsSinceEpoch = function() return 1 end },
  alert = { show = function() end },
  fs = { attributes = function() end },
  drawing = { windowLevels = { floating = 1 } },
  screen = { mainScreen = function()
    return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
  end },
  base64 = { encode = function(s) return s end, decode = function(s) return s end },
  image = { imageFromPath = function() end },
  pasteboard = { writeObjects = function() return true end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local M = dofile(MODDIR .. "/screenshot_editor.lua")
M.setup({
  provide = function() end,
  resolveBaseScreen = function()
    return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
  end,
})

-- a 1x1 transparent PNG — a real data URI shape, tiny on purpose
io.write(_G.screenshotEditor.buildHtml(
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
