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
-- 6.174.0 — a template and a daily note in the index; tags, a task list and
-- a mentions answer, so the page has every pane's data to draw
v.setNotes({ "Alpha.md", "Projects/Beta.md", "Gamma.md", "Long Name Here.md", "Templates/Meeting.md", "Daily/2026-09-06.md" })
v.setLinkLines("/od/Vault/Alpha.md:[[Beta|B]]\n/od/Vault/Gamma.md:[[Alpha]]\n/od/Vault/Gamma.md:[[Delta]]\n")
v.tagsOf = { ["Alpha.md"] = { "Work" }, ["Gamma.md"] = { "work/deep" }, ["Projects/Beta.md"] = { "Home" } }
v.rebuildTags()
-- 6.185.0 — front-matter FIELDS, so the page has something for WHERE and
-- a TABLE's columns to work on
v.fmOf = {
    ["Alpha.md"]        = { status = "reading", rating = "5", genre = "focus, craft" },
    ["Projects/Beta.md"]= { status = "done",    rating = "3" },
    ["Gamma.md"]        = { status = "reading" },
    -- rating 10 exists so a NUMERIC comparison is provable: "10" > "3" is
    -- false as text and true as a number, and only one of those is right
    ["Long Name Here.md"] = { rating = "10" },
}
v.doc = { name = "Alpha", rel = "Alpha.md", path = "/od/Vault/Alpha.md", key = "alpha",
          text = "# Alpha\n\nsee [[Beta|B]] and [x](../Docs/x.pdf) #Work\n\n## Part two\n- [ ] a task\n- done\n" }
v.links["Alpha.md"] = v.linksIn(v.doc.text)
v.taskRows = { { n = "Gamma", r = "Gamma.md", l = 4, x = "call" } }
v.lastTasks = 0
v.unlinked = { key = "alpha", rels = { "Gamma.md" }, pending = false }
-- 6.173.0 — "pad" as the second argument: the Scorp Pad's tabs in the list, a tab open
if arg[2] == "pad" then
  local PAD = { viaVault = true, historyRows = 200, kinds = { capture = { badge = "🗒", label = "Capture", hint = "⌘W queues this" } },
                tabs = { { id = "t1", text = "groceries\nmilk [[Alpha]]" }, { id = "t2", text = "", kind = "capture" } },
                history = { { id = "h1", title = "old list", text = "old", closedAt = 0 } }, active = "t1" }
  function PAD.findTab(id) for _, t in ipairs(PAD.tabs) do if t.id == id then return t end end end
  function PAD.activeTab() return PAD.findTab(PAD.active) end
  function PAD.titleOf(t) local f = t.text:match("[^\n]*"); if f == "" then return (PAD.kinds[t.kind or ""] or {}).label or "Scratch" end return f end
  function PAD.kindOf(t) return t and t.kind and PAD.kinds[t.kind] or nil end
  function PAD.setText(id, text) local t = PAD.findTab(id); if t then t.text = text end return t ~= nil end
  function PAD.newTab() return nil end
  _G.scratchPad = PAD
  v.openScratch("t1")
end
v.open()
io.write(out[#out] or "")
