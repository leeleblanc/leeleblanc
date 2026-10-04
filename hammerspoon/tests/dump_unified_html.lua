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
  timer = { secondsSinceEpoch = function() return 1.4231 end },
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
  pasteboard = { setContents = function() return true end, writeObjects = function() return true end },
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
  -- 📋 6.325.0 — THE ONE CLIPBOARD DOOR, in the stub too. The three
  -- callers that used to announce "📋 Copied" over a write macOS may
  -- have refused now ask core.copyText, so a core stub without it
  -- throws rather than silently taking a different path — and a stub
  -- that always SUCCEEDS could never drive the refusal (6.290.0).
  copyText = function(text, who)
      _G.COPIES = _G.COPIES or {}
      _G.COPIES[#_G.COPIES + 1] = { text = text, who = who }
      if _G.COPY_REFUSES then return false, "macOS refused the write" end
      if type(text) ~= "string" or text == "" then return false, "there was nothing to copy" end
      pcall(function() hs.pasteboard.setContents(text) end)
      return true
  end,
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
