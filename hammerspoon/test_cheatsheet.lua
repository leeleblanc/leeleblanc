-- Harness: runs the REAL §1.6 code against a stubbed hs, then measures
-- what it actually draws. Nothing here is mocked at the layout level.
local SCR = { x = 0, y = 0, w = 3840, h = 2160 }
local drawn = {}          -- last element list handed to the canvas
local canvasRect          -- rect the canvas was created with
local shown, deleted = 0, 0
local hotkeysEnabled, hotkeysDisabled = 0, 0
local tapRunning = false
local MOUSE = { x = 0, y = 0 }

hs = {
  canvas = {
    windowLevels = { overlay = 102 },
    new = function(rect)
      canvasRect = rect
      local c = {}
      function c:replaceElements(els) drawn = els; return c end
      function c:appendElements(els) drawn = els; return c end
      function c:show() shown = shown + 1; return c end
      function c:delete() deleted = deleted + 1; return c end
      function c:level() return c end
      function c:behaviorAsLabels() return c end
      return c
    end,
  },
  hotkey = {
    new = function(mods, key, pressed, released, repeatfn)
      local valid = { escape=1, up=1, down=1, pageup=1, pagedown=1, home=1, ["end"]=1 }
      assert(valid[key], "unexpected key bound: " .. tostring(key))
      local hk = { key = key, fire = pressed, repeatfn = repeatfn }
      function hk:enable() hotkeysEnabled = hotkeysEnabled + 1; return hk end
      function hk:disable() hotkeysDisabled = hotkeysDisabled + 1; return hk end
      return hk
    end,
  },
  eventtap = {
    new = function(types, fn)
      local t = { fn = fn }
      function t:start() tapRunning = true; return t end
      function t:stop() tapRunning = false; return t end
      return t
    end,
    event = {
      types = { scrollWheel = 22 },
      properties = {
        scrollWheelEventIsContinuous     = "cont",
        scrollWheelEventDeltaAxis1       = "line",
        scrollWheelEventPointDeltaAxis1  = "px",
      },
    },
  },
  mouse = { absolutePosition = function() return MOUSE end },
  alert = { show = function() end },
}
function resolveBaseScreen()
  return { frame = function() return SCR end }
end
_G.customShortcuts = {}

local function wheelEvent(props)
  return { getProperty = function(_, k) return props[k] end }
end

dofile("GROUPS_PATH")   -- cheatSheetGroups()
dofile("BLOCK_PATH")    -- the section under test, returns the namespace
local CS = _G.__cheatSheet

-- ---------------------------------------------------------------- utils
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; print(("  ✅ %s"):format(name))
  else fail = fail + 1; print(("  ❌ %s — %s"):format(name, tostring(detail or ""))) end
end
local function ulen(s) return utf8.len(s) or #s end
local function texts()
  local t = {}
  for _, e in ipairs(drawn) do if e.type == "text" then table.insert(t, e) end end
  return t
end
local function st() return _G.cheatSheetState end

-- ================================================================ TESTS
print("\n=== 1. Single column, vertical, fits the screen ===")
CS.show()
local S = st()
check("one column only (no colGap / no second x)", (function()
  local xs = {}
  for _, e in ipairs(texts()) do if e.frame.x > 0 then xs[e.frame.x] = true end end
  local n = 0; for _ in pairs(xs) do n = n + 1 end
  return n <= 1
end)(), "more than one text column x found")
check("panel narrower than half a 4K screen", canvasRect.w <= SCR.w * 0.55 and canvasRect.w <= 760, canvasRect.w)
check("panel height within 86% of screen", canvasRect.h <= SCR.h * 0.86 + 0.01, canvasRect.h)
check("panel centred on the screen", math.abs((canvasRect.x + canvasRect.w/2) - (SCR.x + SCR.w/2)) < 0.01)
check("content is long enough to need scrolling", S.maxFirst > 1, S.maxFirst)

print("\n=== 2. No dead space, no half-drawn rows ===")
check("height is exactly chrome + whole rows",
  math.abs(canvasRect.h - (S.contentTop + S.footerH + 8 + S.visible * S.lineH)) < 0.01,
  canvasRect.h)
local topOK, botOK = true, true
for _, e in ipairs(texts()) do
  if e.frame.x > 0 then   -- a content row (title/footer are full-width at x=0)
    if e.frame.y < S.contentTop - 0.01 then topOK = false end
    if e.frame.y + e.frame.h > S.contentTop + S.visible * S.lineH + 0.01 then botOK = false end
  end
end
check("no row drawn above the title area", topOK)
check("no row drawn over the footer", botOK)

print("\n=== 3. Nothing overruns the column (the 6.31.0 bug stays fixed) ===")
local widest, longest = 0, ""
for _, e in ipairs(texts()) do
  if e.frame.x > 0 then
    if e.frame.x + e.frame.w > widest then widest = e.frame.x + e.frame.w end
    if ulen(e.text) > ulen(longest) then longest = e.text end
  end
end
check("text frames stay clear of the scrollbar", widest <= S.sbX - 1, widest .. " vs sbX " .. S.sbX)
local budget = math.max(20, math.floor(S.contentW / (S.entrySize * 0.52)))
check("longest rendered line within the character budget",
  ulen(longest) <= budget, ulen(longest) .. " chars > budget " .. budget)
print(("     longest line (%d chars): %s"):format(ulen(longest), longest))

print("\n=== 4. Translucency ===")
check("panel alpha is see-through but readable (0.6–0.85)",
  drawn[1].fillColor.alpha >= 0.6 and drawn[1].fillColor.alpha <= 0.85, drawn[1].fillColor.alpha)
check("panel is near-black, so white text keeps contrast",
  drawn[1].fillColor.red <= 0.12 and drawn[1].fillColor.blue <= 0.14)
check("entry text is full white", (function()
  for _, e in ipairs(texts()) do
    if e.frame.x > 0 and e.textColor.white then return e.textColor.white >= 0.99 end
  end
end)())

print("\n=== 5. Scrolling: keys ===")
CS.scrollTo(1)
check("starts at the top", st().first == 1)
CS.scrollBy(-5); check("cannot scroll above the first row", st().first == 1, st().first)
CS.scrollBy(3);  check("↓ moves down by rows", st().first == 4, st().first)
local page = CS.pageStep()
check("a page keeps 2 rows of overlap", page == S.visible - 2, page)
CS.scrollBy(page)
check("PgDn advances one page (clamped at the end)",
  st().first == math.min(S.maxFirst, 4 + page), st().first)
CS.scrollTo(math.maxinteger)
check("End lands exactly on the last full view", st().first == S.maxFirst, st().first)
CS.scrollBy(50); check("cannot scroll past the end", st().first == S.maxFirst, st().first)
local lastIdx = st().first + st().visible - 1
check("the final row is reachable (nothing stranded below the fold)",
  lastIdx >= #st().lines, lastIdx .. " of " .. #st().lines)
CS.scrollTo(1); check("Home returns to the top", st().first == 1)

print("\n=== 6. Scrolling: wheel ===")
local P = hs.eventtap.event.properties
MOUSE = { x = canvasRect.x - 50, y = canvasRect.y + 10 }   -- pointer OUTSIDE
local consumed = CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -3 }))
check("wheel passes through when the pointer is off the sheet", consumed == false and st().first == 1)
MOUSE = { x = canvasRect.x + canvasRect.w/2, y = canvasRect.y + canvasRect.h/2 }  -- INSIDE
consumed = CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -3 }))
check("wheel is claimed over the sheet", consumed == true)
check("negative delta scrolls DOWN the list", st().first == 4, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = 2 }))
check("positive delta scrolls UP the list", st().first == 2, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventDeltaAxis1] = -999 }))
check("one violent flick is capped at 10 rows", st().first == 12, st().first)
CS.scrollTo(1)
local before = st().first
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
check("a tiny trackpad nudge does not move a row yet", st().first == before, st().first)
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
CS.wheelHandler(wheelEvent({ [P.scrollWheelEventIsContinuous] = 1, [P.scrollWheelEventPointDeltaAxis1] = -8 }))
check("accumulated trackpad pixels do move it (no rounding to zero)", st().first > before, st().first)

print("\n=== 7. Scrollbar tracks the position ===")
local function thumb()
  local t
  for _, e in ipairs(drawn) do
    if e.type == "rectangle" and e.frame and e.frame.w == st().sbW then t = e end
  end
  return t
end
CS.scrollTo(1)
local top = thumb()
check("thumb starts at the top of the track", math.abs(top.frame.y - st().contentTop) < 0.01)
CS.scrollTo(math.maxinteger)
local bot = thumb()
check("thumb ends flush with the bottom of the track",
  math.abs((bot.frame.y + bot.frame.h) - (st().contentTop + st().visible * st().lineH)) < 0.01)
check("thumb never leaves the track", bot.frame.y >= st().contentTop - 0.01)

print("\n=== 8. Cost stays flat as the list grows ===")
local baseEls = #drawn
for i = 1, 300 do
  table.insert(_G.customShortcuts, { keys = "⇪⇧" .. i, desc = "A deliberately long custom description " .. i, group = "BULK" })
end
CS.show()
check("300 extra entries are all in the list", #st().lines > 300, #st().lines)
check("but the canvas element count barely moves",
  #drawn <= baseEls + 2, #drawn .. " vs " .. baseEls)
check("still one column, still the same width", canvasRect.w <= 760, canvasRect.w)
_G.customShortcuts = {}

print("\n=== 9. Redraw keeps your place; a fresh open does not ===")
CS.show()
CS.scrollTo(20)
CS.show(true)
check("add/edit/delete redraw preserves the scroll position", st().first == 20, st().first)
CS.show()
check("⇪/ opens at the top", st().first == 1, st().first)
CS.scrollTo(st().maxFirst)
local wasAt = st().first
_G.customShortcuts = {}
CS.show(true)
check("a shortened list clamps back into range instead of showing blanks",
  st().first <= st().maxFirst, st().first .. " > " .. st().maxFirst)

print("\n=== 10. Small laptop screen ===")
SCR = { x = 0, y = 0, w = 1280, h = 800 }
CS.show()
check("panel still fits the screen", canvasRect.w <= 1280 and canvasRect.h <= 800 * 0.86 + 0.01)
check("still readable — at least 8 rows visible", st().visible >= 8, st().visible)
local ok10 = true
for _, e in ipairs(texts()) do
  if e.frame.x > 0 and (e.frame.x + e.frame.w) > st().sbX then ok10 = false end
end
check("no overrun on the narrower column", ok10)
SCR = { x = 0, y = 0, w = 3840, h = 2160 }

print("\n=== 11. Teardown is complete ===")
CS.show()
local d0, e0 = deleted, hotkeysDisabled
CS.hide()
check("canvas deleted", deleted == d0 + 1)
check("every hotkey disabled (Esc + 6 scroll keys)", hotkeysDisabled >= e0 + 7, hotkeysDisabled - e0)
check("wheel tap stopped", tapRunning == false)
check("state cleared", _G.cheatSheetState == nil and _G.cheatSheetCanvas == nil)
check("scrolling after hide is a no-op, not an error", (function()
  local ok = pcall(function() CS.scrollBy(5); CS.render(); CS.wheelHandler(wheelEvent({})) end)
  return ok
end)())

print("\n=== 12. Toggle ===")
CS.toggle(); check("toggle opens", _G.cheatSheetCanvas ~= nil)
CS.toggle(); check("toggle closes", _G.cheatSheetCanvas == nil)

print(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
