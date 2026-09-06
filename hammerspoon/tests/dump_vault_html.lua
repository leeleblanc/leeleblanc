-- Renders the Vault's real page HTML to stdout, so test_vault_js.js can
-- execute the ACTUAL [[ autocomplete, link-at-caret, row walker and
-- graph code instead of a hand-written copy.
--
--     lua5.4 dump_vault_html.lua /path/to/modules > /tmp/vault.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE — print is redirected to stderr.
local MODDIR = arg[1] or "./modules"
local out = {}
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  io.stderr:write(table.concat(p, " "), "\n")
end
hs = {
  timer = { doAfter = function() return { stop = function() end } end,
            doEvery = function() return { stop = function() end } end },
  alert = { show = function() end }, fs = { mkdir = function() end },
  drawing = { windowLevels = { floating = 1 } },
  screen = { mainScreen = function() return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end } end },
  dialog = { textPrompt = function() return "Cancel", "" end },
  settings = { get = function() end, set = function() end },
  mouse = { absolutePosition = function() return { x = 0, y = 0 } end },
  eventtap = { checkMouseButtons = function() return {} end },
  task = { new = function() return { start = function() return true end } end },
  webview = {
    windowMasks = { nonactivating = 128 },
    usercontent = { new = function() local uc = {} function uc:setCallback(f) self.cb = f return self end return uc end },
    new = function(rect)
      local w = { styleMask = 0 }
      function w:html(h) out[#out + 1] = h return self end
      function w:windowStyle(s) if s == nil then return self.styleMask end self.styleMask = s return self end
      for _, m in ipairs({ "windowTitle", "allowTextEntry", "closeOnEscape", "level", "alpha",
                           "behaviorAsLabels", "show", "bringToFront", "delete", "frame" }) do
        w[m] = function(self) return self end
      end
      return w
    end },
}
_G.diag = { say = function() end, warn = function() end }
local mod = dofile(MODDIR .. "/vault.lua")
mod.setup({ cloudDir = "/od", logsDir = "/od/Logs", provide = function() end, hyperAddShortcut = function() end })
local v = _G.vault
v.setNotes({ "Alpha.md", "Projects/Beta.md", "Gamma.md", "Long Name Here.md" })
v.setLinkLines("/od/Vault/Alpha.md:[[Beta|B]]\n/od/Vault/Gamma.md:[[Alpha]]\n/od/Vault/Gamma.md:[[Delta]]\n")
v.doc = { name = "Alpha", rel = "Alpha.md", path = "/od/Vault/Alpha.md", key = "alpha", text = "# Alpha\n\nsee [[Beta|B]] and [x](../Docs/x.pdf)\n" }
v.links["Alpha.md"] = v.linksIn(v.doc.text)
v.open()
io.write(out[#out] or "")
