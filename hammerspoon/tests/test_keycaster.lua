-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- Harness for the KEY CASTER. Drives the REAL event tap with real key
-- events and reads back what it drew.
--
-- 🚨 THE TWO THINGS THIS SUITE EXISTS FOR, above all the drawing:
--
--   1. IT MUST NEVER CONSUME A KEYSTROKE. This is the third global
--      keyboard tap in the config and the only one that exists purely to
--      LOOK at things. A display tool that eats a keypress is worse than
--      no display tool, so every branch below asserts the return value —
--      including the branches that fail.
--   2. IT MUST FAIL WITHOUT TAKING ANYTHING ELSE WITH IT. LL's words:
--      "anything we add must fail without ruining, stopping, or
--      interfering with any other running tool that functions properly."
--      A tap that throws on every keystroke does not stop — it just makes
--      the whole keyboard slower and louder. So it counts failures and
--      switches ITSELF off.
-- =====================================================================

local CANVASES, ALERTS, TIMERS, PRINTED = {}, {}, {}, {}
local NOW, AXOK = 1000, true
local TAP, SCREEN = nil, { x = 0, y = 0, w = 1512, h = 944 }
local DRAGGABLE = {}

local function mkTimer(kind, secs, fn)
    local t = { kind = kind, secs = secs, fn = fn, live = true }
    function t:stop() self.live = false; return self end
    table.insert(TIMERS, t)
    return t
end

hs = {
  canvas = {
    windowLevels = { overlay = 102 },
    new = function(frame)
      local c = { frame_ = frame, elements = {}, shown = false, alpha_ = 1 }
      function c:replaceElements(e) self.elements = e; return c end
      function c:show() self.shown = true; return c end
      function c:hide() self.shown = false; return c end
      function c:delete() self.deleted = true; return c end
      function c:level(l) self.level_ = l; return c end
      function c:behaviorAsLabels(b) self.behaviour = b; return c end
      function c:alpha(a) if a then self.alpha_ = a end; return c end
      function c:frame(f) if f then self.frame_ = f end; return self.frame_ end
      function c:canvasMouseEvents() return c end
      function c:mouseCallback() return c end
      table.insert(CANVASES, c)
      return c
    end,
  },
  eventtap = {
    event = { types = { keyDown = 10, keyUp = 11, flagsChanged = 12 },
              properties = { keyboardEventAutorepeat = 8 } },
    new = function(types, fn)
      TAP = { types = types, fn = fn, on = false }
      function TAP:start() self.on = true end
      function TAP:stop() self.on = false end
      function TAP:isEnabled() return self.on end
      return TAP
    end,
  },
  timer = {
    secondsSinceEpoch = function() return NOW end,
    doAfter = function(s, f) return mkTimer("after", s, f) end,
    doEvery = function(s, f) return mkTimer("every", s, f) end,
  },
  screen = { mainScreen = function()
    return { frame = function() return SCREEN end,
             fullFrame = function() return SCREEN end }
  end, allScreens = function()
    return { { fullFrame = function() return SCREEN end } }
  end },
  keycodes = { map = {} },
  alert = { show = function(m) table.insert(ALERTS, m) end },
  accessibilityState = function() return AXOK end,
  hotkey = { bind = function() end },
}

-- A key-code table both directions, the way hs.keycodes.map really is.
local NAMES = { "a","b","c","x","z","1","escape","tab","return","delete",
                "forwarddelete","space","up","down","left","right","home",
                "end","pageup","pagedown","f1","f3","f18","padenter" }
for i, n in ipairs(NAMES) do
  hs.keycodes.map[n] = 100 + i
  hs.keycodes.map[100 + i] = n
end

print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  table.insert(PRINTED, table.concat(p, " "))
end

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { recorded = {},
  record = function(k, s, m) table.insert(_G.notices.recorded, k .. "|" .. s .. "|" .. m) end,
  tell = function() end }
_G.panelLevel = function(name) return 102 + (name == "keycaster" and 2 or 0) end
_G.showCanvasSafely = function(c) c:show(); return true end
_G.clampToScreen = function(pt) return pt end
_G.makeCanvasDraggable = function(c, label, onDrop)
  table.insert(DRAGGABLE, { canvas = c, label = label, onDrop = onDrop })
  return true
end
_G.injectDepth = 0
_G.typingInjection = function() return _G.injectDepth > 0 end
_G.hyperActive = false

local PROVIDED, HYPER = {}, {}
local core = {
  resolveBaseScreen = function() return hs.screen.mainScreen() end,
  provide = function(n, fn) PROVIDED[n] = fn end,
  hyperAddShortcut = function(mods, key, fn, src)
    HYPER[table.concat(mods, "+") .. "+" .. key] = { fn = fn, src = src }
  end,
}

local mod = dofile(HS .. "/modules/key_caster.lua")
mod.setup(core)
local kc = mod.kc

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end

-- Fire one key event through the REAL tap. Returns what the tap returned,
-- which is the thing that decides whether your keystroke survives.
local function key(name, flags, type_, repeating)
  return TAP.fn({
    getType = function() return type_ or hs.eventtap.event.types.keyDown end,
    getKeyCode = function() return hs.keycodes.map[name] end,
    getFlags = function() return flags or {} end,
    getProperty = function(_, p)
      if p == hs.eventtap.event.properties.keyboardEventAutorepeat then
        return repeating and 1 or 0
      end
      return 0
    end,
  })
end
local function lines()
  local t = {}
  for _, l in ipairs(kc.lines) do
    t[#t + 1] = l.text .. (l.count > 1 and ("×" .. l.count) or "")
  end
  return t
end
local function lastLine() local l = lines(); return l[#l] end
local function reset()
  kc.hide(); kc.lines = {}
  kc.lastEvent, kc.f18Down = nil, false
  _G.hyperActive, _G.injectDepth = false, 0
  kc.showTyping, kc.showBareModifiers = false, false
  kc.failures, kc.on = 0, true
  CANVASES, ALERTS, PRINTED, TIMERS = {}, {}, {}, {}
  NOW = NOW + 10
end

-- =====================================================================
out("\n=== 1. The module contract, and its own file ===\n")
check("it is its own module, not another block in init.lua",
  mod.name == "Key Caster" and type(mod.setup) == "function")
check("it declares a cheat sheet group",
  mod.cheatsheet and mod.cheatsheet.title:find("KEY CASTER", 1, true) ~= nil)
check("it declares a slot in the sheet", type(mod.order) == "number")
check("it binds ⇪⇧B and nothing else", (function()
  local n = 0
  for _ in pairs(HYPER) do n = n + 1 end
  return n == 1 and HYPER["shift+b"] ~= nil
end)(), (function() for k in pairs(HYPER) do return k end end)())
check("it publishes keyCaster.toggle/start/stop",
  PROVIDED["keyCaster.toggle"] and PROVIDED["keyCaster.start"]
  and PROVIDED["keyCaster.stop"] and true)
check("🔒 IT IS OFF UNTIL ASKED. A module whose whole job is watching your "
   .. "keyboard must not start doing that at boot", kc.on == false)
check("...and no tap exists yet either", TAP == nil)
check("_G.keyCastTyping is reachable from the Console",
  type(_G.keyCastTyping) == "function")

-- =====================================================================
out("\n=== 2. 🚨 IT NEVER CONSUMES A KEYSTROKE ===\n")
kc.start()
check("starting creates the tap and runs it", TAP ~= nil and TAP.on == true)
reset()
local everyReturn = {}
local cases = {
  { "a", {} },                                  -- plain typing
  { "a", { shift = true } },                    -- a capital
  { "x", { cmd = true } },                      -- a real shortcut
  { "escape", {} },                             -- a bare special key
  { "f3", { fn = true } },                      -- fn + F-key
  { "f18", {} },                                -- the hyper key itself
  { "tab", { shift = true } },                  -- ⇧ + non-typing
  { "z", { cmd = true, alt = true, ctrl = true, shift = true } },
}
for _, c in ipairs(cases) do
  everyReturn[#everyReturn + 1] = tostring(key(c[1], c[2]))
end
key("a", {}, hs.eventtap.event.types.flagsChanged)
everyReturn[#everyReturn + 1] = tostring(
  key("a", {}, hs.eventtap.event.types.keyUp))
check("🚨 EVERY event type and every branch returns false — this module "
   .. "watches, it never eats", (function()
    for _, r in ipairs(everyReturn) do if r ~= "false" then return false, r end end
    return true
  end)(), table.concat(everyReturn, ","))

-- =====================================================================
out("\n=== 3. What earns a line, and what does not ===\n")
reset()
check("plain typing draws nothing", key("a", {}) == false and #kc.lines == 0)
check("...and neither does a whole word", (function()
    for _, ch in ipairs({ "a", "b", "c", "1" }) do key(ch, {}) end
    return #kc.lines == 0
  end)(), table.concat(lines(), " "))
reset()
check("🚨 ⇧ + A LETTER IS A CAPITAL, NOT A SHORTCUT — the single rule that "
   .. "keeps your sentence off the side of the screen",
  key("a", { shift = true }) == false and #kc.lines == 0, lastLine())
reset()
check("⌘X earns a line", (function() key("x", { cmd = true }); return lastLine() end)() == "⌘X",
  lastLine())
reset(); key("x", { cmd = true, shift = true })
check("⌘⇧X too", lastLine() == "⇧⌘X", lastLine())
reset(); key("x", { ctrl = true, alt = true })
check("⌃⌥X too", lastLine() == "⌃⌥X", lastLine())
reset(); key("escape", {})
check("a bare ⎋ earns one — it is a shortcut with no modifier",
  lastLine() == "⎋", lastLine())
reset(); key("tab", {})
check("bare ⇥ too", lastLine() == "⇥", lastLine())
reset(); key("up", {})
check("bare arrows too", lastLine() == "↑", lastLine())
reset(); key("f3", {})
check("a bare F-key too", lastLine() == "F3", lastLine())
reset(); key("f3", { fn = true })
check("fn + F-key, which is what the fn key is FOR", lastLine() == "fnF3",
  lastLine())
reset(); key("tab", { shift = true })
check("⇧⇥ earns one — ⇧ counts against a NON-typing key", lastLine() == "⇧⇥",
  lastLine())
reset()
check("🚨 BACKSPACE ALONE DOES NOT. It is part of typing — you press it "
   .. "constantly — and a panel that lit up on every correction would be "
   .. "unusable", key("delete", {}) == false and #kc.lines == 0, lastLine())
reset(); key("delete", { cmd = true })
check("...but ⌘⌫ does, because it carries a modifier", lastLine() == "⌘⌫",
  lastLine())
reset()
check("space alone does not", key("space", {}) == false and #kc.lines == 0)

out("\n  3b. the ⌨️ switch, for when you DO want everything\n")
reset(); kc.showTyping = true
key("a", {})
check("_G.keyCastTyping(true) shows plain typing as well",
  lastLine() == "A", lastLine())
key("b", { shift = true })
check("...capitals included", lastLine() == "⇧B", lastLine())
kc.showTyping = false
check("the Console switch really flips it", (function()
    _G.keyCastTyping(true);  local a = kc.showTyping
    _G.keyCastTyping(false); return a == true and kc.showTyping == false
  end)())

-- =====================================================================
out("\n=== 4. ⇪ — the key that is invisible from outside ===\n")
reset()
_G.hyperActive = true
key("x", { cmd = true, shift = true, ctrl = true, alt = true })
check("🚨 WHILE ⇪ IS HELD, THE SYNTHETIC ⌘⇧⌃⌥ CHORD IS RENDERED AS ⇪. "
   .. "Drawing '⌘⇧⌃⌥X' for a key you experienced as '⇪X' is accurate and "
   .. "useless", lastLine() == "⇪X", lastLine())
reset()
_G.hyperActive = true
key("x", {})
check("...and a claimed hyper key, which carries no modifiers at all, is "
   .. "still ⇪X", lastLine() == "⇪X", lastLine())
reset()
check("🚨 F18 ITSELF IS NEVER DRAWN — you did not press 'F18', you pressed "
   .. "Caps Lock, and the config remapped it",
  key("f18", {}) == false and #kc.lines == 0, lastLine())
check("...but it IS remembered, as the fallback for when _G.hyperActive "
   .. "is not published by init.lua", kc.f18Down == true)
reset()
_G.hyperActive = false
kc.f18Down = true
key("x", {})
check("...and that fallback really labels it ⇪", lastLine() == "⇪X", lastLine())

-- =====================================================================
out("\n=== 5. The panel: where it is, and what it looks like ===\n")
reset(); key("escape", {})
local c = CANVASES[#CANVASES]
check("it drew", c ~= nil and c.shown == true)
check("📍 RIGHT-JUSTIFIED — its right edge is near the screen's, not in "
   .. "the middle", (function()
    local right = c.frame_.x + c.frame_.w
    return right > SCREEN.w - 80 and right <= SCREEN.w, right
  end)(), c and (c.frame_.x + c.frame_.w))
check("📍 VERTICALLY CENTRED", (function()
    local mid = c.frame_.y + c.frame_.h / 2
    return math.abs(mid - (SCREEN.y + SCREEN.h / 2)) < 4, mid
  end)(), c and (c.frame_.y + c.frame_.h / 2))
check("it follows the screen you are working on, not always the main one",
  (function()
    local f = io.open(HS .. "/modules/key_caster.lua")
    local src = f:read("*a"); f:close()
    src = src:gsub("%-%-[^\n]*", "")
    return src:find("resolveBaseScreen", 1, true) ~= nil
  end)())
local rect = (function()
    for _, e in ipairs(c.elements) do if e.type == "rectangle" then return e end end
  end)()
check("the box is nearly black", rect and rect.fillColor.red < 0.1
      and rect.fillColor.green < 0.1 and rect.fillColor.blue < 0.1)
check("...with rounded corners", rect and rect.roundedRectRadii
      and rect.roundedRectRadii.xRadius > 0)
check("🌑 ...AND A SHADOW AS THE PERIMETER, which is what makes it read as "
   .. "floating rather than as a box with a border drawn round it",
   rect and rect.withShadow == true and rect.shadow
   and rect.shadow.blurRadius > 0, rect and tostring(rect.withShadow))
check("🚨 THE CANVAS IS BIGGER THAN THE BOX, or the shadow is clipped to "
   .. "its own edge and becomes a grey stripe",
   rect and rect.frame.x > 0 and rect.frame.y > 0
   and (rect.frame.x + rect.frame.w) < c.frame_.w,
   rect and (rect.frame.x .. "/" .. c.frame_.w))
local txt = (function()
    for _, e in ipairs(c.elements) do if e.type == "text" then return e end end
  end)()
check("the text is 16px, as asked", txt and txt.textSize == 16, txt and txt.textSize)
check("...in a sans-serif face", txt and txt.textFont == "Helvetica Neue",
      txt and txt.textFont)
check("...right-aligned inside the box", txt and txt.textAlignment == "right")
check("it draws over full-screen apps and on every Space", (function()
    local b = {}
    for _, x in ipairs(c.behaviour or {}) do b[x] = true end
    return b.canJoinAllSpaces and b.fullScreenAuxiliary
  end)(), table.concat(c.behaviour or {}, ","))
check("🪟 it sits ABOVE the cheat sheet — a panel that shows what you just "
   .. "pressed must not be hidden BY what you just pressed",
   c.level_ == _G.panelLevel("keycaster")
   and _G.panelLevel("keycaster") > _G.panelLevel("cheatsheet"),
   c.level_)

out("\n  5b. dragging\n")
local reg = DRAGGABLE[#DRAGGABLE]
check("it registers itself as draggable", reg and reg.label == "key caster",
      reg and reg.label)
check("...with an onDrop, without which it would snap back on every "
   .. "keystroke — and this panel redraws on EVERY keystroke",
   reg and type(reg.onDrop) == "function")
if reg and reg.onDrop then reg.onDrop({ x = 200, y = 300, w = 200, h = 90 }) end
check("dropping it remembers the position", kc.pos and kc.pos.x == 200,
      kc.pos and kc.pos.x)
reset(); kc.pos = { x = 200, y = 300 }
key("escape", {})
check("...and the next draw opens there", CANVASES[#CANVASES].frame_.x == 200,
      CANVASES[#CANVASES].frame_.x)
kc.pos = nil

-- =====================================================================
out("\n=== 6. 🕒 It stays up while you are still pressing ===\n")
-- LL: "should not fade until the keypresses are done displaying so we
-- must leave the box up until the key presses are done."
reset(); key("escape", {})
local hide1 = (function()
    for _, t in ipairs(TIMERS) do
      if t.live and t.kind == "after" and t.secs == kc.holdSecs then return t end
    end
  end)()
check("a fade is armed after the first keystroke", hide1 ~= nil)
key("tab", {})
check("🚨 A SECOND KEYSTROKE CANCELS THE PENDING FADE. The timer is an "
   .. "IDLE timeout, not a lifetime — hold a chord down and the panel "
   .. "simply stays", hide1.live == false, tostring(hide1.live))
local hide2 = (function()
    for _, t in ipairs(TIMERS) do
      if t.live and t.kind == "after" and t.secs == kc.holdSecs then return t end
    end
  end)()
check("...and a fresh one is armed in its place", hide2 ~= nil and hide2 ~= hide1)
check("both keys are on screen", #kc.lines == 2, table.concat(lines(), " "))
hide2.fn()
for _, t in ipairs(TIMERS) do
  if t.live and t.kind == "after" and t.secs == kc.fadeSecs + 0.05 then t.fn() end
end
check("...and when you finally stop, it goes away",
      kc.canvas == nil and #kc.lines == 0, #kc.lines)

out("\n  6b. a held key is counted, not repeated\n")
reset()
-- 🚨 A HELD KEY ARRIVES AS AUTOREPEATS, and that flag is the ONLY thing
-- that separates it from one press arriving twice: macOS repeats at
-- 30-60ms, well inside the 60ms dedupe window the double-event needs.
-- A clock cannot tell these apart. The event can.
key("x", { cmd = true })
key("x", { cmd = true }, nil, true)
key("x", { cmd = true }, nil, true)
check("three of the same combo is one line with a count, not three rows",
      #kc.lines == 1 and lastLine() == "⌘X×3", table.concat(lines(), " "))
check("🚨 AND A NON-REPEAT DOUBLE EVENT IS STILL COLLAPSED — the dedupe "
   .. "did not simply get switched off to make the count work",
   (function()
      reset(); _G.hyperActive = true
      key("x", { cmd = true, ctrl = true, alt = true, shift = true })
      key("x", {})
      return #kc.lines == 1 and lastLine() == "⇪X"
   end)(), table.concat(lines(), " "))
reset()
key("x", { cmd = true })
key("x", { cmd = true }, nil, true)
NOW = NOW + kc.repeatWindow + 1
key("x", { cmd = true })
check("...but the same combo LATER is a new line — that is you pressing "
   .. "it again, not holding it", #kc.lines == 2, table.concat(lines(), " "))

out("\n  6c. the list is bounded\n")
reset()
for i = 1, kc.maxLines + 4 do
  NOW = NOW + 1
  key(({ "escape", "tab", "up", "down", "left", "right", "home", "end",
         "pageup", "pagedown" })[((i - 1) % 10) + 1], {})
end
check("it never grows past maxLines — the panel is a display, not a log",
      #kc.lines == kc.maxLines, #kc.lines)

out("\n  6d. one press that arrives twice\n")
reset()
_G.hyperActive = true
key("x", { cmd = true, ctrl = true, alt = true, shift = true })
key("x", {})              -- the same press, arriving again microseconds later
check("🔁 a hyper press can fire the modal AND re-send a synthetic chord; "
   .. "the same text inside the dedupe window is ONE line",
   #kc.lines == 1, table.concat(lines(), " "))

-- =====================================================================
out("\n=== 7. Sharing the keyboard with the other two taps ===\n")
reset()
_G.injectDepth = 1
check("🚨 IT STANDS DOWN FOR THE SHARED INJECTION GUARD. The expander's "
   .. "and autocorrect's synthetic typing is not yours and must not be "
   .. "drawn as though you pressed it",
   key("x", { cmd = true }) == false and #kc.lines == 0, lastLine())
_G.injectDepth = 0
key("x", { cmd = true })
check("...and your next real keystroke is drawn normally",
      lastLine() == "⌘X", lastLine())

-- =====================================================================
out("\n=== 8. 🛟 It fails without taking anything else with it ===\n")
-- LL: "anything we add must fail without ruining, stopping, or
-- interfering with any other running tool that functions properly."
reset()
-- 🚨 THE FAILURE HAS TO ARRIVE WHERE ONE REALLY WOULD. My first version
-- of this made hs.canvas.new throw — and proved nothing, because
-- render() already pcalls it and returns false. That is the module being
-- correct, not the test being right. A hostile EVENT is the shape a real
-- failure takes: something the callback reads that refuses to answer.
local function badKey()
  return TAP.fn({
    getType = function() return hs.eventtap.event.types.keyDown end,
    getKeyCode = function() error("this event refuses to answer") end,
    getFlags = function() return {} end,
    getProperty = function() return 0 end,
  })
end
local rets = {}
for i = 1, kc.maxFailures - 1 do
  NOW = NOW + 1
  rets[#rets + 1] = tostring(badKey())
end
check("🚨 A THROWING CALLBACK STILL RETURNS false — your keystroke reaches "
   .. "the app whatever happens in here", (function()
    for _, r in ipairs(rets) do if r ~= "false" then return false, r end end
    return true
  end)(), table.concat(rets, ","))
check("...and it is still running, because an occasional failure is not a "
   .. "broken feature", kc.on == true, kc.failures)
NOW = NOW + 1
local lastRet = tostring(badKey())
check("🛟 PAST maxFailures IT SWITCHES ITSELF OFF rather than throwing on "
   .. "every keystroke for the rest of the session", kc.on == false, kc.failures)
check("...still returning false on the way out", lastRet == "false", lastRet)
check("...and the tap is really stopped, not just flagged",
      TAP.on == false)
check("🚨 AND IT SAYS SO, naming itself and saying nothing else is affected",
  (function()
    for _, l in ipairs(PRINTED) do
      if l:find("switched itself OFF", 1, true) then return true end
    end
  end)(), table.concat(PRINTED, " | "):sub(1, 140))
check("...to the ledger as well", #_G.notices.recorded > 0)
check("a successful keystroke resets the counter", (function()
    kc.start(); kc.failures = 3
    NOW = NOW + 1
    key("escape", {})
    return kc.failures == 0
  end)(), kc.failures)

out("\n  8b. and the rest of the config is untouched\n")
check("stopping deletes the panel and leaves no canvas behind", (function()
    reset(); key("escape", {})
    local live = CANVASES[#CANVASES]
    kc.stop("test")
    return live.deleted == true and kc.canvas == nil
  end)())
check("stopping twice does not throw", pcall(kc.stop, "again"))
check("a keystroke arriving after stop draws nothing and still returns false",
  (function()
    local r = key("escape", {})
    return r == false and #kc.lines == 0
  end)())
check("🚨 IT NEVER LOGS WHAT YOU TYPED. Checked as text over the whole "
   .. "file, because it is a promise about every path and not about the "
   .. "ones this suite happened to walk", (function()
    local f = io.open(HS .. "/modules/key_caster.lua")
    local src = f:read("*a"); f:close()
    src = src:gsub("%-%-[^\n]*", "")            -- comments discuss it freely
    -- No print/record/say of a rendered keystroke or the line list.
    return not src:find("print%([^)]*text")
       and not src:find("record%([^)]*text")
       and not src:find("say%([^)]*text")
       and not src:find("print%([^)]*kc%.lines")
       and not src:find("record%([^)]*kc%.lines")
  end)())
check("...and what it DOES keep is a count", type(kc.shown) == "number")

-- =====================================================================
out("\n=== 9. No Accessibility, no tap, and it says so ===\n")
kc.stop("test")
AXOK = false
_G.keyCasterTap = nil
ALERTS = {}
check("it refuses to start without Accessibility rather than pretending",
      kc.start() == false and kc.on == false)
check("...and says why on screen", #ALERTS > 0
      and tostring(ALERTS[1]):find("Accessibility", 1, true) ~= nil,
      ALERTS[1])
AXOK = true

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
