-- =====================================================================
-- test_win_pin.lua — a note stuck to ONE window, following it (⇪⇧U)
-- =====================================================================
--     lua5.4 test_win_pin.lua [/path/to/hammerspoon]
--
-- Executes modules/win_pin.lua against a stubbed hs and drives the REAL
-- functions: the four anchors, set/edit/remove, the follow tick and its
-- hide rules, the ADAPTIVE timer (the one thing changed coming in from
-- the Spoon that could regress silently), dead-vs-stale classification,
-- rebind and prune, persistence across a simulated reload with junk
-- records in the blob, and the Accessibility-off stand-down.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local WINDOWS  = {}     -- id -> window
local FOCUSED  = nil
local PIDS     = {}     -- pid -> true while that application is running
local SETTINGS = {}
local ALERTS   = {}
local TIMERS   = {}
local SHOWN    = {}     -- canvases _G.showCanvasSafely was asked to show
local AX       = true
local PROMPT   = { button = "OK", text = "" }
local BOUND    = {}     -- what hyperAddShortcut registered
local PROVIDED = {}

local function win(id, appName, pid, title, x, y, w, h, opts)
    opts = opts or {}
    local o = { _frame = { x = x, y = y, w = w, h = h } }
    o.id          = function() return id end
    o.title       = function() return title end
    o.isMinimized = function() return opts.minimized == true end
    o.frame       = function() return o._frame end
    o.application = function()
        if opts.noApp then return nil end
        return {
            pid          = function() return pid end,
            name         = function() return appName end,
            isFrontmost  = function() return opts.frontmost ~= false end,
            focusedWindow = function() return opts.focusedIsOther or o end,
        }
    end
    return o
end

local function canvas(f)
    local o = { _f = f, shown = false, deleted = false, hides = 0, shows = 0 }
    o.frame = function(self, nf)
        if nf then self._f = nf return self end
        return self._f
    end
    o.minimumTextSize  = function(_, _, text) return { w = 120, h = 20 + #tostring(text) } end
    o.level            = function() end
    o.clickActivating  = function(_, v) o.clickActivating_ = v end
    o.canvasMouseEvents = function(_, a, b, c, d) o.mouseEvents = { a, b, c, d } end
    o.show             = function(self) self.shown = true; self.shows = self.shows + 1 end
    o.hide             = function(self) self.shown = false; self.hides = self.hides + 1 end
    o.delete           = function(self) self.deleted = true; self.shown = false end
    return o
end

hs = {
    window = {
        get           = function(id) return WINDOWS[id] end,
        focusedWindow = function() return FOCUSED end,
    },
    application = {
        applicationForPID = function(pid) return PIDS[pid] and { pid = pid } or nil end,
    },
    canvas   = { new = function(f) return canvas(f) end },
    settings = { get = function(k) return SETTINGS[k] end,
                 set = function(k, v) SETTINGS[k] = v end },
    alert    = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    dialog   = { textPrompt = function() return PROMPT.button, PROMPT.text end },
    timer    = {
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    accessibilityState = function() return AX end,
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.showCanvasSafely = function(c) SHOWN[#SHOWN + 1] = c; c:show(); return true end

local CORE = {
    hyperAddShortcut = function(mods, key, fn, source)
        BOUND[#BOUND + 1] = { mods = mods, key = key, fn = fn, source = source }
    end,
    provide = function(name, fn) PROVIDED[name] = fn end,
}

local function lastAlert() return ALERTS[#ALERTS] or "" end

-- =====================================================================
out("── Window Pin: one note, one window, following it ──\n")
out("\n1. contract & wiring\n")
-- =====================================================================
local M = dofile(HS .. "/modules/win_pin.lua")
check("module loads and has setup()", type(M.setup) == "function")
check("filed under the windows family", M.family == "windows")
check("the cheat group claims ⇪⇧U and nothing else", (function()
    if type(M.cheatsheet) ~= "table" then return false end
    local keys = {}
    for _, e in ipairs(M.cheatsheet.entries) do
        local k = tostring(e[1])
        if k:match("^⇪") then keys[#keys + 1] = k end
    end
    return #keys == 1 and keys[1] == "⇪⇧U"
end)())

M.setup(CORE)
local wp = _G.winPin
check("module table exported", type(wp) == "table")
check("⇪⇧U is bound", #BOUND == 1 and BOUND[1].key == "u"
      and BOUND[1].mods[1] == "shift", BOUND[1] and BOUND[1].key)
check("_G.pins() is published for the Console", type(_G.pins) == "function")
check("services provided", type(PROVIDED["winPin.pin"]) == "function"
      and type(PROVIDED["winPin.unpinAll"]) == "function")
check("no timer runs while there is nothing to follow", wp.timer == nil)

-- =====================================================================
out("2. the four anchors\n")
-- =====================================================================
local WF = { x = 100, y = 200, w = 800, h = 600 }
wp.offsetX, wp.offsetY = 10, 40
wp.anchor = "topLeft"
local f = wp.overlayFrame(WF, 200, 50)
check("topLeft sits inside the top-left corner", f.x == 110 and f.y == 240,
      f.x .. "," .. f.y)
wp.anchor = "topRight"
f = wp.overlayFrame(WF, 200, 50)
check("topRight keeps its whole width on the window",
      f.x == 100 + 800 - 200 - 10 and f.y == 240, f.x .. "," .. f.y)
wp.anchor = "bottomLeft"
f = wp.overlayFrame(WF, 200, 50)
check("bottomLeft keeps its whole height on the window",
      f.x == 110 and f.y == 200 + 600 - 50 - 40, f.x .. "," .. f.y)
wp.anchor = "bottomRight"
f = wp.overlayFrame(WF, 200, 50)
check("bottomRight does both", f.x == 690 and f.y == 710, f.x .. "," .. f.y)
wp.anchor = "topRight"

-- =====================================================================
out("3. pinning — set(), and what it refuses\n")
-- =====================================================================
local ghostty = win(501, "Ghostty", 900, "staging — ssh", 0, 0, 700, 500)
WINDOWS[501] = ghostty
FOCUSED = ghostty
PIDS[900] = true

check("no text is refused, and says so",
      wp.set("", 501):find("empty", 1, true) ~= nil, wp.set("", 501))
check("a note past maxChars is refused rather than drawn off-screen",
      wp.set(string.rep("x", wp.maxChars + 1), 501):find("over the", 1, true) ~= nil)
check("a window that does not exist is refused",
      wp.set("hello", 999):find("no window", 1, true) ~= nil)

local said = wp.set("PROD — be careful", 501)
check("pinning reports the window it bound to",
      said:find("bound to window 501", 1, true) ~= nil, said)
check("the pin is held", type(wp.pins[501]) == "table")
check("…with a canvas built for it", wp.pins[501].canvas ~= nil)
check("…and the app is remembered for the dead/stale test later",
      wp.pins[501].appPid == 900 and wp.pins[501].appName == "Ghostty")
check("it persisted through hs.settings, so a reload costs nothing",
      type(SETTINGS["winPin.notes"]) == "table"
      and SETTINGS["winPin.notes"]["501"].text == "PROD — be careful")
check("the canvas went up through showCanvasSafely, not a bare show()",
      #SHOWN == 1 and SHOWN[1] == wp.pins[501].canvas, #SHOWN)
check("clicks pass through to the window under it",
      wp.pins[501].canvas.clickActivating_ == false
      and wp.pins[501].canvas.mouseEvents[1] == false)

-- =====================================================================
out("4. the follow tick\n")
-- =====================================================================
local before = wp.pins[501].lastFrame
check("the note was placed on the first tick", before ~= nil)
ghostty._frame = { x = 300, y = 250, w = 700, h = 500 }
wp.tick()
check("it follows the window when the window moves",
      wp.pins[501].lastFrame.x ~= before.x, wp.pins[501].lastFrame.x)
local shows = wp.pins[501].canvas.shows
wp.tick()
check("a tick that changes nothing does not re-place the canvas",
      wp.pins[501].lastFrame.x == wp.overlayFrame(ghostty._frame,
          wp.pins[501].canvas:frame().w, wp.pins[501].canvas:frame().h).x)
check("…and it is still shown each tick, so nothing can strand it hidden",
      wp.pins[501].canvas.shows > shows)

-- the app goes to the back
WINDOWS[501] = win(501, "Ghostty", 900, "staging — ssh", 300, 250, 700, 500,
                   { frontmost = false })
local visible = wp.tick()
check("a note hides when its app is not frontmost — it floats over "
      .. "everything, so a visible one would look pinned to the wrong window",
      wp.pins[501].canvas.shown == false and visible == 0, visible)
check("…and the cached position is dropped, so it cannot reappear stale",
      wp.pins[501].lastFrame == nil)

-- another window of the SAME app is in front
WINDOWS[501] = win(501, "Ghostty", 900, "staging — ssh", 300, 250, 700, 500,
                   { focusedIsOther = { id = function() return 502 end } })
wp.tick()
check("a note hides when another window of its own app is in front",
      wp.pins[501].canvas.shown == false)

-- =====================================================================
out("5. the adaptive timer — the Spoon polled at 33Hz forever\n")
-- =====================================================================
check("hidden notes fall back to the idle rate", wp.rate == wp.followIdle,
      wp.rate)
WINDOWS[501] = ghostty
wp.tick()
check("a visible note goes back to the fast rate", wp.rate == wp.followFast,
      wp.rate)
check("the timer is HELD (an unreferenced hs.timer is collected)",
      wp.timer ~= nil and wp.timer.every == true and wp.timer.stopped == false)
local held = wp.timer
wp.tick()
check("…and it is not churned when the rate has not changed", wp.timer == held)

-- =====================================================================
out("6. editing and removing through ⇪⇧U — on a Mac with NO hs.webview,\n")
out("   which is the small-prompt fallback and must keep the old meaning\n")
-- =====================================================================
PROMPT = { button = "OK", text = "PROD — do not deploy" }
wp.pin()
check("⇪⇧U on a pinned window edits that note",
      wp.pins[501].text == "PROD — do not deploy", wp.pins[501].text)
check("…and the old canvas was deleted, not leaked",
      SHOWN[1].deleted == true)

PROMPT = { button = "Cancel", text = "typed then cancelled" }
wp.pin()
check("Cancel changes nothing", wp.pins[501].text == "PROD — do not deploy")

PROMPT = { button = "OK", text = "" }
wp.pin()
check("clearing the box removes the note — the third outcome of the one key",
      wp.pins[501] == nil)
check("…and says so", lastAlert():find("removed", 1, true) ~= nil, lastAlert())
check("…and the timer stops when the last note goes", wp.timer == nil)
check("…and the removal was persisted",
      SETTINGS["winPin.notes"]["501"] == nil)

PROMPT = { button = "OK", text = "" }
wp.pin()
check("clearing an unpinned window says there was nothing to remove",
      lastAlert():find("Nothing to remove", 1, true) ~= nil, lastAlert())

-- =====================================================================
out("7. dead vs stale — the rule that a note is NEVER auto-deleted\n")
-- =====================================================================
local vscode = win(601, "Code", 901, "init.lua", 0, 0, 900, 700)
local slack  = win(602, "Slack", 902, "#general", 0, 0, 900, 700)
WINDOWS[601], WINDOWS[602] = vscode, slack
PIDS[901], PIDS[902] = true, true
FOCUSED = vscode; wp.set("review this", 601)
FOCUSED = slack;  wp.set("mute me", 602)
check("two notes are held", wp.pins[601] ~= nil and wp.pins[602] ~= nil)

-- Slack's window is gone but Slack is running: a background tab, maybe.
WINDOWS[602] = nil
local dead, stale = wp.classify()
check("an unresolvable window whose APP is alive is stale, not dead",
      #dead == 0 and #stale == 1 and stale[1].id == 602,
      #dead .. "/" .. #stale)
wp.tick()
check("a stale note hides and KEEPS its text — deleting on a guess would "
      .. "throw away something a person typed",
      wp.pins[602] ~= nil and wp.pins[602].text == "mute me")

-- Now VS Code quits outright.
WINDOWS[601] = nil; PIDS[901] = nil
dead, stale = wp.classify()
check("an unresolvable window whose app EXITED is dead",
      #dead == 1 and dead[1].id == 601, #dead .. "/" .. #stale)

local pruned = wp.prune()
check("prune removes the dead one only", wp.pins[601] == nil and wp.pins[602] ~= nil)
check("…and reports both numbers honestly",
      pruned:find("removed 1", 1, true) and pruned:find("kept 1", 1, true), pruned)

-- =====================================================================
out("8. rebind — a reopened tab comes back with a NEW id\n")
-- =====================================================================
local reopened = win(603, "Slack", 902, "#general", 0, 0, 900, 700)
WINDOWS[603] = reopened
FOCUSED = reopened
local listed = wp.rebind()
check("with only a STALE note, rebind lists rather than guesses — the tab "
      .. "may simply be in the background",
      listed:find("pick an id", 1, true) ~= nil, listed)
check("…and the note is untouched", wp.pins[602] ~= nil)

local moved = wp.rebind(602)
check("naming the id moves the text onto the focused window",
      moved:find("bound to window 603", 1, true) ~= nil, moved)
check("…the old id is released", wp.pins[602] == nil)
check("…and the text survived the move", wp.pins[603].text == "mute me")
check("an id that is not a movable note is refused",
      wp.rebind(4242):find("not a movable note", 1, true) ~= nil)

check("_G.pins() names the calls, so the Console answers its own question",
      (function()
          local s = wp.status()
          return s:find("rebind", 1, true) and s:find("prune", 1, true)
                 and s:find("unpinAll", 1, true)
      end)())

-- =====================================================================
out("9. a reload — notes come back, junk in the blob does not\n")
-- =====================================================================
SETTINGS["winPin.notes"]["777"] = { text = "" }              -- empty
SETTINGS["winPin.notes"]["778"] = { appName = "Ghost" }      -- no text at all
SETTINGS["winPin.notes"]["779"] = "not even a table"
local fresh = dofile(HS .. "/modules/win_pin.lua")
BOUND = {}
fresh.setup(CORE)
local wp2 = _G.winPin
check("the real note came back across the reload",
      wp2.pins[603] ~= nil and wp2.pins[603].text == "mute me")
check("…with a canvas rebuilt for it", wp2.pins[603].canvas ~= nil)
check("a half-written record is skipped, not fed to the canvas builder",
      wp2.pins[777] == nil and wp2.pins[778] == nil and wp2.pins[779] == nil)
check("restored count is reported", wp2.restored == 1, wp2.restored)

check("unpinAll clears everything and says how many",
      (function()
          local n = wp2.unpinAll()
          return n == 1 and next(wp2.pins) == nil and wp2.timer == nil
      end)())

-- =====================================================================
out("10. Accessibility off — stand down, and say why\n")
-- =====================================================================
AX = false
SETTINGS["winPin.notes"] = { ["800"] = { text = "should not be built" } }
TIMERS = {}
BOUND  = {}
local offM = dofile(HS .. "/modules/win_pin.lua")
offM.setup(CORE)
local wp3 = _G.winPin
check("nothing is restored and nothing is drawn", next(wp3.pins) == nil)
check("no timer polls windows it could never move", #TIMERS == 0, #TIMERS)
check("⇪⇧U is still bound, so the key is honest instead of silent",
      #BOUND == 1 and BOUND[1].key == "u")
BOUND[1].fn()
check("…and pressing it says what is wrong",
      lastAlert():find("Accessibility", 1, true) ~= nil, lastAlert())
check("set() refuses outright with Accessibility off",
      wp3.set("x", 501):find("Accessibility", 1, true) ~= nil)

-- =====================================================================
out("📐 6.112.0 — a note WRAPS, and can never be drawn off the screen\n")
-- =====================================================================
-- LL: "after I added one it's either not working or the window is there
-- I can't see it." It was the second one. The canvas was sized to one
-- unwrapped line, so its width grew without limit and the topRight
-- anchor pushed a long note clean off the LEFT edge of the display.
do
    -- Section 10 left _G.winPin as the Accessibility-OFF instance, which
    -- refuses everything by design. Boot a working one.
    AX = true
    SETTINGS["winPin.notes"] = nil
    dofile(HS .. "/modules/win_pin.lua").setup(CORE)
    local wpw = _G.winPin
    wpw.maxWidth, wpw.fontSize, wpw.padding = 360, 13, 10

    local cols = wpw.wrapCols()
    check("the wrap width comes from maxWidth, not from the text",
          cols > 20 and cols < 80, cols)

    local long = string.rep("x", 400)          -- the maxChars limit exactly
    local wrapped = wpw.wrapText(long, cols)
    check("🚨 an unbreakable 400-character run is BROKEN, not left one line",
          select(2, wrapped:gsub("\n", "")) >= 8,
          select(2, wrapped:gsub("\n", "")) .. " newlines")
    local widest = 0
    for line in (wrapped .. "\n"):gmatch("(.-)\n") do
        widest = math.max(widest, #line)
    end
    check("…and no wrapped line is wider than the column count",
          widest <= cols, widest .. " > " .. cols)

    check("the newlines you typed are KEPT — the prompt has promised this "
          .. "since 6.104.0", (function()
        local w = wpw.wrapText("one\ntwo\nthree", cols)
        return w == "one\ntwo\nthree"
    end)(), wpw.wrapText("one\ntwo\nthree", cols))
    check("blank lines survive as blank lines",
          wpw.wrapText("a\n\nb", cols) == "a\n\nb")
    check("words break at spaces, not mid-word", (function()
        local w = wpw.wrapText(string.rep("alpha ", 40), cols)
        for line in (w .. "\n"):gmatch("(.-)\n") do
            if line ~= "" and not line:match("^alpha[ alph]*a?$") then return false, line end
        end
        return true
    end)())

    -- The canvas that actually gets drawn, measured with realistic metrics.
    local savedNew = hs.canvas.new
    hs.canvas.new = function(f)
        local o = { _f = f, shown = false, deleted = false, hides = 0, shows = 0 }
        o.frame = function(self, nf) if nf then self._f = nf return self end return self._f end
        -- Menlo is monospace: 0.602 em advance. The OLD stub returned a
        -- fixed w = 120 for any text, which is precisely why the suite
        -- could not have caught this bug.
        o.minimumTextSize = function(_, _, text)
            local widest2, lines = 0, 0
            for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
                widest2 = math.max(widest2, #line) ; lines = lines + 1
            end
            return { w = math.ceil(widest2 * 13 * 0.602), h = lines * 17 }
        end
        o.level = function() end
        o.clickActivating = function() end
        o.canvasMouseEvents = function() end
        o.show = function(self) self.shown = true end
        o.hide = function(self) self.shown = false end
        o.delete = function(self) self.deleted = true end
        return o
    end

    local c400 = wpw.buildCanvas(long)
    check("🚨 a 400-character note is at most maxWidth wide (it used to be "
          .. "3,140pt — off every display sold)",
          c400:frame().w <= wpw.maxWidth, c400:frame().w)
    check("…and it got TALLER instead, which is what wrapping means",
          c400:frame().h > 60, c400:frame().h)

    -- The clamp is the guarantee that does not depend on the measuring.
    local CLAMPED = false
    _G.clampToScreen = function(pt, w2, h2)
        CLAMPED = true
        return { x = math.max(0, math.min(pt.x, 1440 - w2)),
                 y = math.max(0, math.min(pt.y, 900 - h2)) }
    end
    wpw.anchor, wpw.offsetX, wpw.offsetY = "topRight", 12, 44
    local off = wpw.overlayFrame({ x = 0, y = 100, w = 400, h = 300 }, 900, 60)
    check("🚨 a note too wide for its window is clamped ONTO the screen, "
          .. "never off the left edge", CLAMPED and off.x >= 0, off.x)
    _G.clampToScreen = nil
    hs.canvas.new = savedNew
end

-- =====================================================================
out("✍️ 6.112.0 — ⇪⇧U opens a real editor, not a one-line alert\n")
-- =====================================================================
do
    local VIEWS, UC = {}, {}
    hs.drawing = { windowLevels = { floating = 5 } }
    hs.webview = {
        windowMasks = { nonactivating = 128 },
        usercontent = { new = function(name)
            local u = { name = name }
            u.setCallback = function(self, fn) self.cb = fn end
            UC[#UC + 1] = u
            return u
        end },
        new = function(rect, _, uc)
            local v = { rect = rect, uc = uc, shown = false, deleted = false,
                        style = 0 }
            v.windowTitle      = function(self) return self end
            v.allowTextEntry   = function(self) return self end
            v.level            = function(self) return self end
            v.behaviorAsLabels = function(self, b) self.behaviors = b return self end
            v.windowStyle      = function(self, n)
                if n then self.style = n return self end
                return self.style
            end
            v.html             = function(self, h) self.htmlText = h return self end
            v.show             = function(self) self.shown = true return self end
            v.bringToFront     = function(self) return self end
            v.frame            = function(self, f) if f then self.rect = f end return self.rect end
            v.delete           = function(self) self.deleted = true end
            VIEWS[#VIEWS + 1] = v
            return v
        end,
    }
    AX = true
    SETTINGS["winPin.notes"] = nil
    BOUND = {}
    dofile(HS .. "/modules/win_pin.lua").setup(CORE)
    local wpe = _G.winPin
    local target = win(901, "Ghostty", 1901, "staging", 40, 60, 800, 600)
    WINDOWS[901] = target
    FOCUSED = target
    wpe.pins = {}

    ALERTS = {}
    wpe.pin()
    local view = VIEWS[#VIEWS]
    check("⇪⇧U opens a webview, not a dialog", view ~= nil and view.shown)
    check("…and it is a real box, not a one-line field",
          view.rect.w >= 400 and view.rect.h >= 240,
          view.rect.w .. "x" .. view.rect.h)
    check("…opened over the window it belongs to, not the middle of screen 1",
          view.rect.x > 40 and view.rect.x < 840, view.rect.x)
    check("the page carries a multi-line textarea", (view.htmlText or ""):find("<textarea", 1, true) ~= nil)
    check("…a live count against the limit that would refuse the pin",
          (view.htmlText or ""):find(tostring(wpe.maxChars), 1, true) ~= nil)
    check("…and ⌘⏎ / Esc are both offered in the page",
          (view.htmlText or ""):find("⌘⏎", 1, true) ~= nil
          and (view.htmlText or ""):find("Esc", 1, true) ~= nil)
    check("🚨 the non-activating mask is applied — an editor that pulled "
          .. "Hammerspoon forward would pin the note and then HIDE it",
          view.style == 128, view.style)

    -- The save path, with a note the old one-line field could not hold.
    local multi = "PROD — do not deploy\nsecond line\nthird line"
    UC[#UC].cb({ body = { a = "save", text = multi } })
    check("saving pins exactly what was typed, newlines and all",
          wpe.pins[901] and wpe.pins[901].text == multi,
          wpe.pins[901] and wpe.pins[901].text)
    check("…and the editor closed itself", view.deleted == true)
    check("…and the note that gets DRAWN is the wrapped form",
          wpe.pins[901].canvas ~= nil)

    -- 🚨 The guard that matters: the window is captured when the key is
    -- pressed, so focus moving while the box is open cannot misfile it.
    wpe.pin()
    local other = win(902, "Slack", 1902, "#general", 0, 0, 500, 400)
    WINDOWS[902] = other
    FOCUSED = other                      -- you clicked away mid-edit
    UC[#UC].cb({ body = { a = "save", text = "belongs to Ghostty" } })
    check("🚨 clicking another window mid-edit does NOT move the note onto it",
          wpe.pins[901].text == "belongs to Ghostty" and wpe.pins[902] == nil,
          wpe.pins[902] and "landed on Slack" or "ok")
    FOCUSED = target

    -- Cancel.
    wpe.pin()
    local v2 = VIEWS[#VIEWS]
    UC[#UC].cb({ body = { a = "cancel" } })
    check("Cancel changes nothing and closes the box",
          wpe.pins[901].text == "belongs to Ghostty" and v2.deleted == true)

    -- Remove, which the old flow could only express as "empty the box".
    wpe.pin()
    check("an existing note pre-fills the box",
          (VIEWS[#VIEWS].htmlText or ""):find("belongs to Ghostty", 1, true) ~= nil)
    check("…and offers an explicit Remove",
          (VIEWS[#VIEWS].htmlText or ""):find("Remove note", 1, true) ~= nil)
    UC[#UC].cb({ body = { a = "remove" } })
    check("Remove takes the note off that window", wpe.pins[901] == nil)

    -- An empty save still removes: that contract predates the window.
    wpe.set("temporary", 901)
    wpe.pin()
    UC[#UC].cb({ body = { a = "save", text = "   " } })
    check("emptying the box still removes, as the cheat sheet teaches",
          wpe.pins[901] == nil)

    -- ⇪⇧U twice is a toggle, not two stacked boxes.
    wpe.pin()
    local openCount = #VIEWS
    wpe.pin()
    check("⇪⇧U with the editor open closes it instead of stacking a second",
          #VIEWS == openCount and VIEWS[openCount].deleted == true)

    -- HTML escaping: a note is arbitrary text a person typed.
    wpe.set('</textarea><script>bad()</script>', 901)
    wpe.pin()
    check("🚨 a note containing HTML is escaped into the box, not executed",
          (VIEWS[#VIEWS].htmlText or ""):find("&lt;/textarea&gt;", 1, true) ~= nil
          and (VIEWS[#VIEWS].htmlText or ""):find("<script>bad()", 1, true) == nil)
    UC[#UC].cb({ body = { a = "cancel" } })

    hs.webview, hs.drawing = nil, nil
end

-- =====================================================================
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f2 in ipairs(failures) do out("  ✗ " .. f2 .. "\n") end
os.exit(fail == 0 and 0 or 1)
