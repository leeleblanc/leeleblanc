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
-- 6.98.0: the task mirror moved to modules/task_creator.lua with the
-- rest of the creator, so the two call sites now live in two files —
-- the legend strip in init.lua (§6), the mirror in the module (where
-- panelAlpha arrives via core).
check("the Asana legend takes bgWith(panelAlpha)",
      wired("init.lua", "bgWith(panelAlpha)"))
check("the task mirror takes bgWith(core.panelAlpha)",
      wired("modules/task_creator.lua", "bgWith(core.panelAlpha)"))

-- =====================================================================
-- 🔤 6.369.0 — CAN THE CONTROL BE SEEN?
-- =====================================================================
-- LL: "There is not 'X' in the note list to remove an entry." There is,
-- and has been since 6.280.0. 6.361.0's rule in a second place: when a
-- tool goes unused, check that it can be READ before checking that it
-- is correct. These checks make "can it be seen" arithmetic.
out("\n🔤 the contrast arithmetic, and the ✕ he could not see\n")
do
  local M = dofile(HS .. "/modules/ui_style.lua")

  -- the arithmetic itself, against values anyone can check
  local function near(a, b) return a and math.abs(a - b) < 0.05 end
  check("black on white is the maximum ratio", near(M.contrast("#000000", "#ffffff"), 21))
  check("a colour against itself is 1:1", near(M.contrast("#17171c", "#17171c"), 1))
  check("the order of the two colours does not change the ratio",
        near(M.contrast("#000", "#fff"), M.contrast("#fff", "#000")))
  check("a three-digit hex is the same colour as its six-digit form",
        M.luminance("#fff") == M.luminance("#ffffff"))
  -- 🔎 nil, never a number, for anything it could not read: a ratio
  -- invented for a colour nobody understood is worse than none (6.196.1)
  check("🔎 a colour it cannot read answers nil, never a ratio",
        M.contrast("rebeccapurple", "#fff") == nil and M.luminance("#12345") == nil)
  check("…and so does a blend with no alpha", M.blend("#fff", "#000", nil) == nil)

  -- opacity is a BLEND, which is the thing a resting alpha hides
  check("opacity 1 is the ink itself", M.blend("#e8e8ec", "#17171c", 1) == "#e8e8ec")
  check("opacity 0 is the background", M.blend("#e8e8ec", "#17171c", 0) == "#17171c")
  check("an alpha past the ends is clamped, never wrapped",
        M.blend("#e8e8ec", "#17171c", 5) == "#e8e8ec"
        and M.blend("#e8e8ec", "#17171c", -5) == "#17171c")

  -- 📏 THE MEASUREMENT THIS RELEASE RESTS ON. The ✕ shipped at 0.28 in
  -- the note list and 0.3 in the closed-tab strip; both are under
  -- WCAG's 3:1 floor for a control, which is why he reported one that
  -- was there as missing.
  local SIDEBAR, INK = "#17171c", "#e8e8ec"
  local was28 = M.contrast(M.blend(INK, SIDEBAR, 0.28), SIDEBAR)
  local was30 = M.contrast(M.blend(INK, SIDEBAR, 0.30), SIDEBAR)
  check("📏 the OLD note ✕ really was under the floor", was28 < 3.0,
        ("%.2f:1"):format(was28))
  check("📏 …and so was the OLD closed-tab ✕", was30 < 3.0, ("%.2f:1"):format(was30))
  check("📏 the shipped resting alpha clears it, with room for a thin glyph",
        M.contrast(M.blend(INK, SIDEBAR, M.controlAlpha), SIDEBAR) >= 4.5,
        ("%.2f:1"):format(M.contrast(M.blend(INK, SIDEBAR, M.controlAlpha), SIDEBAR)))
  check("…and the hover state is brighter still, never dimmer",
        M.controlHoverAlpha > M.controlAlpha)
  local a, c = M.minAlphaFor(INK, SIDEBAR)
  check("the minimum alpha for the floor is found and is below the shipped one",
        a and a < M.controlAlpha and c >= 3.0, tostring(a))
  check("…and it answers nil when no alpha can reach the floor",
        M.minAlphaFor("#181820", "#17171c", 3.0) == nil)
end

-- =====================================================================
-- 🔤 THE PAGES DRAW IT AT THE MEASURED NUMBER, NOT A TYPED ONE
-- =====================================================================
out("\n🔤 every ✕ in a page is read from ui_style and clears the floor\n")
do
  local M = dofile(HS .. "/modules/ui_style.lua")
  local function src(f)
    local fh = assert(io.open(HS .. "/" .. f, "r"))
    local t = fh:read("a") ; fh:close()
    return t
  end
  -- 🔑 6.239.0 — THE PAGE IS GIVEN THE NUMBER. A literal typed into the
  -- CSS beside a literal in ui_style is two numbers kept in step by
  -- hand, which is how the note list and the closed-tab strip came to
  -- differ by 0.02 for no reason anyone could name.
  for _, f in ipairs({ "modules/vault.lua", "modules/scratch_pad.lua" }) do
    local t = src(f)
    local code = t:gsub("%-%-[^\n]*", "")
    check(f .. "'s ✕ opacity is a token, not a number",
          code:find("%.x{[^}]*opacity:CTRLA") ~= nil
          or code:find("%.x{float:right;opacity:CTRLA") ~= nil, f)
    check(f .. " substitutes it from _G.uiStyle",
          code:find('gsub%("CTRLA"') ~= nil and code:find("uiStyle") ~= nil, f)
    -- rule 1 of ui_style: every consumer reads it WITH A FALLBACK, so a
    -- boot where this module failed to load is the old look and never a
    -- page whose controls are invisible
    check(f .. " falls back to a visible value if ui_style did not load",
          code:find("controlAlpha%) or 0%.55") ~= nil, f)
    check(f .. " leaves no hard-coded dim ✕ behind",
          code:find("%.x{opacity:%.[0-4]") == nil
          and code:find("%.x{float:right;opacity:%.[0-4]") == nil, f)
  end
  -- 🔑 THE GLYPH SAYS WHAT THE ACT COSTS, and that is a rule rather
  -- than a tidy-up. × (the multiplication sign) CLOSES something that
  -- can be reopened — a tab goes to the history. ✕ (U+2715, a heavier
  -- stroke) REMOVES it from a list for good. The closed-tab strip drew
  -- the light × for an act that is permanent, which is the wrong weight
  -- as well as the wrong contrast.
  local sp = src("modules/scratch_pad.lua")
  local vt = src("modules/vault.lua")
  check("🔑 forgetting a closed tab draws the heavy ✕, not the light ×",
        sp:find("\\u2715", 1, true) ~= nil
        and sp:find("&times;</span></div>", 1, true) == nil)
  check("🔑 …the same glyph deleting a note draws", vt:find("\\u2715", 1, true) ~= nil)
  check("🔑 …and CLOSING a tab still draws the light ×, because it can be reopened",
        sp:find('title="Close ⌘W">×', 1, true) ~= nil)

  -- 📏 NAMED, NOT SWEPT (6.269.0). This rule is about CONTROLS — a
  -- thing you have to find and click. Receded LABELS ("no task
  -- matches", "loading…") and a drag ghost are dim on purpose, and a
  -- check that flagged those would go red on a healthy tree and be
  -- switched off inside a week. The bin's restore button measures
  -- 3.98:1 at 0.45 and is left alone for the same reason.
  check("📏 the bin's restore control already clears the floor, so it is untouched",
        M.contrast(M.blend("#e8e8ec", "#17171c", 0.45), "#17171c") >= 3.0)
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
