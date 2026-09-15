-- Renders Unified Search's real page HTML to stdout, so the JS harness
-- (test_unified_js.js) can execute the ACTUAL filter/keyboard/bridge
-- code instead of a hand-written copy. Same contract as the other dumps:
--
--     lua5.4 dump_unified_html.lua /path/to/modules > /tmp/unified.html
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
  image = {
    imageFromPath = function(p)
      return { setSize = function()
        return { encodeAsURLString = function()
          return "data:image/png;base64,THUMB"
        end }
      end }
    end,
  },
  pasteboard = { setContents = function() end, writeObjects = function() return true end },
  webview = { usercontent = { new = function() end } },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

-- fixture stores: five sources, nine rows — enough for the grouped view,
-- the @tags, and a hostile string that must not become markup
_G.clipboardCache = {
  { date = "Aug 15 10:00", text = "alpha receipt from the cafe" },
  { date = "Aug 14 09:00", text = "beta memo about nothing" },
  { date = "Aug 13 08:00", text = "<script>alert(1)</script> gamma" },
}
_G.screenshots = {
  list = function()
    return {
      { name = "receipt scan.png", path = "/od/receipt scan.png",
        mtime = 100, size = 51200 },
      { name = "whiteboard.png",   path = "/od/whiteboard.png",
        mtime = 90, size = 2097152 },
    }
  end,
}
_G.asanaTaskHistory = {
  { title = "Ship the receipt report", timestamp = 100, desc = "", assignee = "Lee" },
}
_G.capturePad = { queue = { { text = "pad receipt idea", createdAt = 50 } } }

local M = dofile(MODDIR .. "/unified_search.lua")
M.setup({
  logsDir = "/nonexistent", hostTag = "Dump",
  provide = function() end,
  call = function(n)
    if n == "commands.entries" then
      return { { cmd = "git status", when = "2026-08-15" },
               { cmd = "open receipt.pdf" } }
    end
  end,
  hyperAddShortcut = function() end,
  resolveBaseScreen = function()
    return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
  end,
})

_G.unifiedSearch.gather()
io.write(_G.unifiedSearch.buildHtml(""))
