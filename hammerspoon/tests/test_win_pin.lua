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
out("6. editing and removing through ⇪⇧U\n")
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
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f2 in ipairs(failures) do out("  ✗ " .. f2 .. "\n") end
os.exit(fail == 0 and 0 or 1)
