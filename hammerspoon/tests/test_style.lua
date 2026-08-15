-- =====================================================================
-- test_style.lua — 6.90.0 the shared style table (modules/ui_style.lua)
-- =====================================================================
--     lua5.4 test_style.lua [/path/to/hammerspoon]
--
-- Executes the REAL module and proves the whole contract:
--   · the tokens are the pomodoro FOCUS card's numbers, verbatim
--   · css()/bgHex()/bgWith()/cssOverride() convert correctly, clamp
--     garbage, and hand out COPIES where a caller could mutate
--   · it works with no hs and with a bare core (the hostile boot)
--   · the pomodoro — the REFERENCE card — actually reads it back
--   · every consumer file is wired to _G.uiStyle (source-level, with
--     comments stripped, the way test_switcher checks panelLevel)

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end

-- Deliberately NO hs stub: the module's header promises it touches no
-- hs.* API at all, and running it with hs = nil is that promise, tested.
hs = nil

local PROVIDED = {}
local core = { provide = function(n, fn) PROVIDED[n] = fn end }

out("=== 1. Contract and boot ===\n")
local mod = dofile(HS .. "/modules/ui_style.lua")
check("module returns the loader contract", type(mod) == "table"
      and type(mod.setup) == "function" and mod.name == "UI Style")
check("it loads FIRST — order below every other module's",
      type(mod.order) == "number" and mod.order < 1, mod.order)
check("cheatsheet block present (title + entries)",
      type(mod.cheatsheet) == "table" and mod.cheatsheet.entries
      and #mod.cheatsheet.entries >= 2)

mod.setup(core)
local S = _G.uiStyle
check("setup publishes _G.uiStyle", type(S) == "table")
check("core.provide'd as style.get — and it is the SAME table",
      PROVIDED["style.get"] ~= nil and PROVIDED["style.get"]() == S)
check("M.config IS the table, so machine profiles can override tokens",
      mod.config == S)

out("\n=== 2. The tokens are the FOCUS card, verbatim ===\n")
check("bg is the FOCUS card background (0.09/0.10/0.13 @ 0.92)",
      S.bg and S.bg.red == 0.09 and S.bg.green == 0.10
      and S.bg.blue == 0.13 and S.bg.alpha == 0.92)
check("fg is the FOCUS card white (0.97)",
      S.fg and S.fg.white == 1.00 and S.fg.alpha == 0.97)
check("accent is the flash amber (1.00/0.84/0.00)",
      S.accent and S.accent.red == 1.00 and S.accent.green == 0.84
      and S.accent.blue == 0.00)
check("radius is the card's 12", S.radius == 12)
check("a receded text color and a hairline stroke exist",
      S.fgDim and S.fgDim.alpha and S.fgDim.alpha < S.fg.alpha
      and S.stroke and S.stroke.alpha and S.stroke.alpha < 0.5)
check("the selection blues — solid, soft, line — all exist",
      S.select and S.selectSoft and S.selectLine
      and S.selectSoft.alpha < S.select.alpha)
check("the type scale carries the card's 12/40 (plus body & title)",
      S.font and S.font.label == 12 and S.font.big == 40
      and S.font.body and S.font.title)

out("\n=== 3. The converters ===\n")
check("css() on the card bg", S.css(S.bg) == "rgba(23,26,33,0.92)", S.css(S.bg))
check("css() understands {white=…} too",
      S.css(S.fg) == "rgba(255,255,255,0.97)", S.css(S.fg))
check("css() on garbage answers white rather than throwing",
      S.css(nil) == "rgba(255,255,255,1.00)"
      and S.css("nope") == "rgba(255,255,255,1.00)")
check("css() clamps out-of-range channels instead of overflowing",
      S.css({ red = 9, green = -3, blue = 0.5, alpha = 1 })
      == "rgba(255,0,128,1.00)",
      S.css({ red = 9, green = -3, blue = 0.5, alpha = 1 }))
check("bgHex() is the OPAQUE card color for webview pages",
      S.bgHex() == "#171a21", S.bgHex())

local seeThrough = S.bgWith(0.75)
check("bgWith(0.75) keeps the hue, takes the alpha",
      seeThrough.red == 0.09 and seeThrough.green == 0.10
      and seeThrough.blue == 0.13 and seeThrough.alpha == 0.75)
check("…and hands out a COPY — a caller writing into it cannot restyle "
   .. "every other panel", (function()
    seeThrough.red = 1.0
    return S.bg.red == 0.09 and S.bgWith(0.5) ~= seeThrough
end)())
check("cssOverride() is one body rule: shared bg + shared fg",
      S.cssOverride() == "body{background:#171a21;"
                         .. "color:rgba(255,255,255,0.97)}",
      S.cssOverride())
check("✏️ an edit to the table flows into cssOverride() live", (function()
    local old = S.bg.red
    S.bg.red = 1.0
    local changed = S.cssOverride():find("background:#ff1a21", 1, true) ~= nil
    S.bg.red = old
    return changed and S.cssOverride():find("#171a21", 1, true) ~= nil
end)())

out("\n=== 4. Hostile Monday ===\n")
check("setup survives a core with no provide()", (function()
    _G.uiStyle = nil
    local ok = pcall(mod.setup, {})
    return ok and type(_G.uiStyle) == "table"
end)())
check("setup twice is idempotent (a ⇪R must not stack anything)", (function()
    local ok = pcall(mod.setup, core)
    return ok and PROVIDED["style.get"]() == _G.uiStyle
end)())

out("\n=== 5. The REFERENCE card reads it back ===\n")
-- The pomodoro donated the numbers; prove it now CONSUMES the table, so
-- an ✏️ edit in ui_style.lua moves the FOCUS card with everything else.
hs = {  -- the minimum pomodoro's setup() touches
  hotkey = { modal = { new = function() return nil end } },
  alert  = { show = function() end },
}
_G.uiStyle = { bg = { red = 0.5 }, fg = { white = 0.5 },
               accent = { red = 0.6 }, radius = 12,
               font = { label = 12, big = 40 } }
local HYPER = {}
local pomCore = {
  provide = function() end,
  hyperAddShortcut = function(m, k, fn) HYPER[k] = fn end,
}
local pomMod = dofile(HS .. "/modules/pomodoro.lua")
local okPom = pcall(pomMod.setup, pomCore)
check("pomodoro sets up against the marker style", okPom == true)
check("🎨 FOCUS card background = uiStyle.bg (same table)",
      okPom and pomMod.pom.bgWork == _G.uiStyle.bg)
check("…text = uiStyle.fg, flash = uiStyle.accent",
      okPom and pomMod.pom.fgWork == _G.uiStyle.fg
      and pomMod.pom.bgFlash == _G.uiStyle.accent)
check("the break amber stays the pomodoro's own — it is a MEANING "
   .. "(stand up), not chrome",
      okPom and pomMod.pom.bgBreak ~= _G.uiStyle.bg
      and pomMod.pom.bgBreak.red == 0.55)
_G.uiStyle = nil

out("\n=== 6. Every consumer is wired (source, comments stripped) ===\n")
local function wired(rel, needle)
  local f = io.open(HS .. "/" .. rel, "r")
  if not f then return false end
  local src = f:read("*a"); f:close()
  src = src:gsub("%-%-[^\n]*", "")
  return src:find(needle, 1, true) ~= nil
end
for _, m in ipairs({ "pomodoro", "mini_calendar", "key_caster",
                     "window_switcher" }) do
  check(m .. " reads _G.uiStyle", wired("modules/" .. m .. ".lua", "_G.uiStyle"))
end
for _, m in ipairs({ "capture_pad", "task_form", "screenshot_editor",
                     "unified_search" }) do
  check(m .. "'s page takes cssOverride()",
        wired("modules/" .. m .. ".lua", "cssOverride"))
end
check("the cheat sheet card takes bgWith(alpha)",
      wired("core/cheatsheet.lua", "bgWith"))
check("the task mirror and Asana legend take bgWith(panelAlpha)", (function()
  local f = io.open(HS .. "/init.lua", "r")
  if not f then return false end
  local src = f:read("*a"); f:close()
  src = src:gsub("%-%-[^\n]*", "")
  local n, at = 0, 1
  while true do
    local s, e = src:find("bgWith(panelAlpha)", at, true)
    if not s then break end
    n = n + 1; at = e + 1
  end
  return n == 2, n
end)())

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
