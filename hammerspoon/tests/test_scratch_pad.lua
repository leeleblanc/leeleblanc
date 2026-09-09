-- =====================================================================
-- test_scratch_pad.lua — ⇪1: tabs, saved as you type, history, 4 PM task
-- =====================================================================
--     lua5.4 test_scratch_pad.lua [/path/to/hammerspoon]
--
-- The claims under test: every keystroke lands in Lua at once and on
-- disk after the debounce (one held timer, re-armed per key); a closed
-- tab with text is the newest history row and comes back on restore; the
-- last tab closing leaves a blank one; pin keeps the pad up on Esc and
-- hides it from the escape router; the 16:00 send builds ONE task with
-- every section, start 07:30 / due 16:00 on today, assignee "me", the
-- identifying comment, and skips an empty or unchanged day; without a
-- webview the plain prompt still edits and saves; a broken store or a
-- failed write never loses the text in Lua; and the module owns no
-- eventtap, no hs.window read and no unheld timer.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail = 0, 0
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        io.write("   ❌ " .. label
                 .. (extra and ("  [" .. tostring(extra) .. "]") or "") .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a small real JSON (the store is nested; the module round-trips it) --
local function jenc(v)
    local tv = type(v)
    if tv == "table" then
        if #v > 0 or next(v) == nil then
            local p = {} for _, x in ipairs(v) do p[#p + 1] = jenc(x) end
            return "[" .. table.concat(p, ",") .. "]"
        end
        local p = {}
        for k, x in pairs(v) do p[#p + 1] = string.format("%q", tostring(k)) .. ":" .. jenc(x) end
        return "{" .. table.concat(p, ",") .. "}"
    elseif tv == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == "\n" then return "\\n" elseif c == '"' then return '\\"'
            elseif c == "\\" then return "\\\\" else return string.format("\\u%04x", c:byte()) end
        end) .. '"'
    elseif tv == "number" then return tostring(v)
    elseif tv == "boolean" then return tostring(v)
    else return "null" end
end
local function jdec(s)
    local i = 1
    local function ws() i = s:find("%S", i) or #s + 1 end
    local val
    local function str()
        i = i + 1; local b = {}
        while true do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1 return table.concat(b) end
            if c == "\\" then
                local n = s:sub(i + 1, i + 1)
                if n == "n" then b[#b + 1] = "\n" elseif n == "u" then
                    b[#b + 1] = string.char(tonumber(s:sub(i + 2, i + 5), 16)); i = i + 4
                else b[#b + 1] = n end
                i = i + 2
            else b[#b + 1] = c; i = i + 1 end
            if i > #s then error("bad json") end
        end
    end
    function val()
        ws(); local c = s:sub(i, i)
        if c == "{" then
            local o = {} i = i + 1 ws()
            if s:sub(i, i) == "}" then i = i + 1 return o end
            while true do
                ws(); local k = str(); ws(); i = i + 1
                o[k] = val(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "}" then return o end
                if d ~= "," then error("bad json") end
            end
        elseif c == "[" then
            local a = {} i = i + 1 ws()
            if s:sub(i, i) == "]" then i = i + 1 return a end
            while true do
                a[#a + 1] = val(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "]" then return a end
                if d ~= "," then error("bad json") end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
        else
            local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if not n or n == "" then error("bad json") end
            i = i + #n return tonumber(n)
        end
    end
    local v = val()
    return v
end

-- ---- a controllable world ------------------------------------------------
local FILES, WRITE_FAILS, WRITE_BLOCK = {}, false, nil
local realIoOpen = io.open
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        if WRITE_FAILS then return nil end
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s return true end,
                 close = function() FILES[path] = table.concat(buf) end }
    end
    if FILES[path] == nil then return nil end
    local content, done = FILES[path], false
    return { read = function() if done then return nil end done = true return content end,
             close = function() end }
end
local realRename = os.rename
os.rename = function(a, b)
    if FILES[a] == nil then return nil, "no such file" end
    FILES[b] = FILES[a]; FILES[a] = nil
    return true
end

local ALERTS, PROVIDED, WEBVIEWS, PROMPTS, TIMERS, PRINTED = {}, {}, {}, {}, {}, {}
local PASTED, PB_FAIL, PB_REFUSE = {}, false, false
local PROMPT_ANSWER = { "Cancel", "" }
local UC_CALLBACK = nil
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

local function newWebviewStub(rect)
    local v = { rect = rect, _style = 0, deleted = false, shown = 0, hidden = 0, htmlSet = nil }
    function v:windowTitle(t) self.title = t return self end
    function v:allowTextEntry(x) self.textEntry = x return self end
    function v:alpha(a) self.alphaSet = a return self end
    function v:closeOnEscape(x) self.closeOnEsc = x return self end
    function v:level(l) self.lvl = l return self end
    function v:behaviorAsLabels(b) self.behave = b return self end
    function v:windowStyle(x) if x ~= nil then self._style = x end return self._style end
    function v:html(h) self.htmlSet = h return self end
    function v:show() self.shown = self.shown + 1 return self end
    function v:hide() self.hidden = self.hidden + 1 return self end
    function v:bringToFront() return self end
    function v:delete() self.deleted = true return self end
    function v:frame(f) if f then self.rect = f end return self.rect end
    return v
end

local function mkTimer(kind, delay, fn, at, rep)
    local t = { kind = kind, delay = delay, fn = fn, at = at, repeats = rep, stopped = false }
    function t:stop() self.stopped = true end
    function t:fire() if not self.stopped then self.fn() end end
    TIMERS[#TIMERS + 1] = t
    return t
end

hs = {
    webview = {
        windowMasks = { nonactivating = 128 },
        usercontent = { new = function(name)
            local uc = { name = name }
            function uc:setCallback(fn) UC_CALLBACK = fn end
            return uc
        end },
        new = function(rect, _, _)
            local v = newWebviewStub(rect)
            WEBVIEWS[#WEBVIEWS + 1] = v
            return v
        end,
    },
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end },
    drawing = { windowLevels = { floating = 5 } },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    dialog = { textPrompt = function(title, msg, dflt, ok, cancel)
        PROMPTS[#PROMPTS + 1] = { title = title, msg = msg, dflt = dflt }
        return PROMPT_ANSWER[1], PROMPT_ANSWER[2]
    end },
    timer = {
        doAfter = function(d, fn) return mkTimer("after", d, fn) end,
        doEvery = function(d, fn) return mkTimer("every", d, fn) end,
        doAt    = function(at, rep, fn) return mkTimer("at", nil, fn, at, rep) end,
    },
    json = { encode = function(t) return jenc(t) end, decode = jdec },
    fs = { mkdir = function() return true end },
    mouse = { absolutePosition = function() return { x = 300, y = 300 } end },
    eventtap = { checkMouseButtons = function() return { left = false } end },
    -- 6.182.0 — the sequential copy's other half. PB_FAIL makes the write
    -- refuse, which is the path where the grab must still be safe.
    -- 🚨 6.198.0 — PB_REFUSE is the OTHER refusal, and the one that was
    -- missing: hs.pasteboard.setContents answers FALSE without throwing.
    -- PB_FAIL alone tested only the half that pcall catches, so the module
    -- could read two values from the pcall, call every quiet refusal a
    -- success, and stay green. A stub gentler than the real thing is a
    -- hole with a tick beside it.
    pasteboard = { setContents = function(t)
        if PB_FAIL then error("pasteboard refused") end
        if PB_REFUSE then return false end
        PASTED[#PASTED + 1] = tostring(t); return true
    end },
}

_G.diag = { say = function() end, warn = function() end, err = function() end, mark = function() end }

local CLAIMED_ESC = {}
_G.claimEscape = function(name, _, present, close)
    CLAIMED_ESC[name] = { present = present, close = close }
end
_G.movablePanels, _G.editors = {}, {}
_G.rewrittenFiles = {}

local SUBMITS, SUBMIT_RESULT = {}, true
_G.asanaSubmitTask = function(title, desc, assignee, attach, extra)
    SUBMITS[#SUBMITS + 1] = { title = title, desc = desc, assignee = assignee, attach = attach, extra = extra }
    return SUBMIT_RESULT
end

local HYPER, WRITE_WARNS = {}, {}
local EXPECTED, SEEN = {}, {}
_G.hyperExpectRelease = function(secs, who) EXPECTED[#EXPECTED + 1] = { secs = secs, who = who } return true end
_G.hyperReleaseSeen = function(who) SEEN[#SEEN + 1] = who return true end
local CORE = {
    logsDir = "/logs",
    asanaEnabled = true,
    provide = function(n, f) PROVIDED[n] = f end,
    hyperAddShortcut = function(mods, key, fn, src)
        HYPER[table.concat(mods or {}, "+") .. "|" .. tostring(key)] = { fn = fn, src = src }
    end,
    warnWriteFailed = function(what) WRITE_WARNS[#WRITE_WARNS + 1] = what end,
}

local mod = dofile(HS .. "/modules/scratch_pad.lua")
mod.setup(CORE)
mod.warm(CORE)
local sp = _G.scratchPad
local TODAY = os.date("%Y-%m-%d")

local function lastTimer(kind)
    for i = #TIMERS, 1, -1 do if TIMERS[i].kind == kind and not TIMERS[i].stopped then return TIMERS[i] end end
end
local function msg(m) sp.handleMessage(m) end
local function store() return FILES[sp.file] and jdec(FILES[sp.file]) end

-- =======================================================================
out("1) the doors in — ⇪N, ⇪2, escape claim, editors row, services, the store\n")
-- =======================================================================
-- 🔑 6.182.0 — ⇪N, was ⇪1. LL: "I think hyper+N is enough to open the
-- Scorp Pad. Do you?" Four keys reached this one window; now one does,
-- ⇪2 is the sequential copy, and ⇪1 is FREE. Asserted as a pair — the
-- key that arrived AND the key that left — because a check that only
-- looked for ⇪N would pass with ⇪1 still bound beside it.
check("⇪N is claimed for the pad", HYPER["|n"] ~= nil and HYPER["|n"].src == "scratch pad")
check("…and ⇪1 is not bound by this module at all", HYPER["|1"] == nil)
check("⇪2 is claimed for the sequential copy",
      HYPER["|2"] ~= nil and HYPER["|2"].src == "sequential copy")
check("the escape router knows 'scratchpad'", CLAIMED_ESC.scratchpad ~= nil)
check("an editors row exists with view AND show (show never toggles)",
      #_G.editors == 1 and _G.editors[1].view and _G.editors[1].show)
check("a movable panel row exists", #_G.movablePanels == 1 and _G.movablePanels[1].name == "scratch pad")
check("scratch.show / scratch.send / scratch.report are published",
      PROVIDED["scratch.show"] and PROVIDED["scratch.send"] and PROVIDED["scratch.report"])
check("the store lives under logsDir/scratch", sp.file == "/logs/scratch/scratch.json")
check("the store is registered with the write ledger", _G.rewrittenFiles[sp.file] ~= nil)
check("a fresh install starts with exactly one blank tab", #sp.tabs == 1 and sp.tabs[1].text == "")
check("the 16:00 send is armed and HELD in sp.sendTimer",
      sp.sendTimer ~= nil and sp.sendTimer.kind == "at" and sp.sendTimer.at == "16:00" and sp.sendTimer.repeats == "1d")

-- =======================================================================
out("2) typing — Lua at once, disk after the debounce, one held timer\n")
-- =======================================================================
sp.show()
local view = WEBVIEWS[#WEBVIEWS]
check("the pad opened one webview with the page in it", view and view.htmlSet and view.htmlSet:find("Scorp Pad", 1, true))
-- 6.171.0 — 1024×768, 35% translucent, both from sp.* so a profile can change them
check("6.171.1: the pad is 768×1024 (portrait) by default", sp.width == 768 and sp.height == 1024)
check("6.172.1: the window is SOLID (alpha 1 — never applied to the view)", sp.alpha == 1 and view and view.alphaSet == nil, view and tostring(view.alphaSet))
check("6.171.2: the page text is 16 px and no FS placeholder survives",
      sp.fontSize == 16 and view and view.htmlSet and view.htmlSet:find("font%-size:16px") ~= nil
      and view.htmlSet:find("FS%d?px") == nil, view and view.htmlSet and view.htmlSet:match("font%-size:[^;]+"))
check("6.171.2: the chrome sizes off the text (14 px buttons, 13 px labels)",
      view and view.htmlSet and view.htmlSet:find("font%-size:14px") and view.htmlSet:find("font%-size:13px"))
check("an empty tab is named by its place, not 'Untitled'", view.htmlSet:find(">Scratch 1<", 1, true) ~= nil and view.htmlSet:find("Untitled", 1, true) == nil)
check("opening told the hyper watchdog to expect the release within 1.5 s",
      EXPECTED[#EXPECTED] and EXPECTED[#EXPECTED].secs == 1.5)
msg({ a = "f18up" })
check("an F18 keyUp seen by the page releases ⇪ through _G.hyperReleaseSeen", SEEN[#SEEN] == "the scratch pad")
check("the header buttons say what they do", view.htmlSet:find("📌 Pin", 1, true) and view.htmlSet:find("→ Asana now", 1, true))
check("allowTextEntry(true) so it takes typing", view.textEntry == true)
check("closeOnEscape is OFF — the page decides what Esc means (pin)", view.closeOnEsc == false)
check("floating level + every Space", view.lvl == 5 and view.behave and view.behave[1] == "canJoinAllSpaces")
check("the non-activating mask was applied and read back", sp.nonActivatingApplied == true, sp.nonActivatingWhy)
local tab1 = sp.tabs[1].id
msg({ a = "edit", id = tab1, text = "hello", sel = 5 })
check("a keystroke is in Lua at once", sp.tabs[1].text == "hello")
check("…but not on disk yet", FILES[sp.file] == nil)
local t1 = sp.saveTimer
check("a debounce timer is armed and HELD in sp.saveTimer", t1 ~= nil and t1.kind == "after" and t1.delay == sp.saveDelay)
msg({ a = "edit", id = tab1, text = "hello w", sel = 7 })
check("a second keystroke re-arms: the first timer is stopped, a new one held", t1.stopped and sp.saveTimer ~= t1)
sp.saveTimer:fire()
local st = store()
check("after the debounce the store holds the text", st and st.tabs[1].text == "hello w", FILES[sp.file])
check("the temp file was renamed over — no .tmp left", FILES[sp.file .. ".tmp"] == nil)
check("the save count moved and dirty cleared", sp.saves == 1 and sp.dirty == false)
check("the page does NOT re-render on a keystroke (the caret would jump)", view.htmlSet:find("hello", 1, true) == nil)

-- =======================================================================
out("3) tabs — new, switch, ⌘1..9, close to history, the last one stays\n")
-- =======================================================================
msg({ a = "new", id = tab1, text = "hello w", sel = 7 })
check("⌘T adds a tab and makes it active", #sp.tabs == 2 and sp.active == sp.tabs[2].id)
local tab2 = sp.tabs[2].id
msg({ a = "edit", id = tab2, text = "second\nline two", sel = 3 })
check("the page re-rendered with both tabs", view.htmlSet:find('data-id="' .. tab2 .. '"', 1, true) ~= nil)
check("the tab title is the first line", sp.titleOf(sp.tabs[2]) == "second")
msg({ a = "switch", id = tab2, text = "second\nline two", tid = tab1 })
check("clicking a tab switches", sp.active == tab1)
msg({ a = "nth", id = tab1, text = "hello w", n = "2" })
check("⌘2 switches to the second tab", sp.active == tab2)
msg({ a = "cycle", id = tab2, text = "second\nline two", d = 1 })
check("⌃Tab cycles forward and wraps to the first tab", sp.active == tab1)
msg({ a = "cycle", id = tab1, text = "hello w", d = -1 })
check("⌃⇧Tab cycles back (wrapping) to the last tab", sp.active == tab2)
msg({ a = "close", id = tab2, text = "second\nline two", tid = tab2 })
check("⌘W on a tab with text: it is gone from the tabs…", #sp.tabs == 1 and sp.tabs[1].id == tab1)
check("…and is the newest history row with its title", sp.history[1] and sp.history[1].id == tab2 and sp.history[1].title == "second")
check("closing wrote the store at once", store().history[1].text == "second\nline two")
msg({ a = "new", id = tab1, text = "hello w" })
local tab3 = sp.tabs[2].id
msg({ a = "close", id = tab3, text = "   ", tid = tab3 })
check("an empty tab closes without a history row", #sp.history == 1 and #sp.tabs == 1)
msg({ a = "close", id = tab1, text = "hello w", tid = tab1 })
check("closing the LAST tab leaves one blank tab", #sp.tabs == 1 and sp.tabs[1].text == "" and sp.active == sp.tabs[1].id)
check("its text went to the history (now two rows, newest first)", #sp.history == 2 and sp.history[1].id == tab1)
local before = #sp.tabs
sp.maxTabs = 1
msg({ a = "new", id = sp.tabs[1].id, text = "" })
check("maxTabs holds and says so", #sp.tabs == before and ALERTS[#ALERTS]:find("tabs already", 1, true))
sp.maxTabs = 12

-- =======================================================================
out("4) history — embedded for the filter, restore brings a row back\n")
-- =======================================================================
check("the page embeds the history rows as ROWS for the JS filter",
      view.htmlSet:find("var ROWS = [{", 1, true) and view.htmlSet:find('"second"', 1, true))
check("a filter box sits under the text", view.htmlSet:find('id="q"', 1, true) ~= nil)
msg({ a = "restore", id = sp.tabs[1].id, text = "", rid = tab2 })
check("restore reopens the row as the active tab", sp.active == sp.tabs[#sp.tabs].id and sp.tabs[#sp.tabs].text == "second\nline two")
check("…and removes it from the history", #sp.history == 1 and sp.history[1].id == tab1)
check("restore of an unknown id is a no-op", sp.restore("nope") == false)

-- =======================================================================
out("5) pin and Esc\n")
-- =======================================================================
check("unpinned: the escape router sees the pad", CLAIMED_ESC.scratchpad.present() == true)
msg({ a = "pin", id = sp.active, text = "second\nline two" })
check("📌 toggles on and is remembered in the store", sp.pinned == true and store().pinned == true)
check("pinned: the escape router leaves the pad alone", CLAIMED_ESC.scratchpad.present() == false)
local hiddenBefore = view.hidden
msg({ a = "esc", id = sp.active, text = "second\nline two" })
check("pinned + Esc: the pad stays (hidden+shown, not deleted)", sp.webview ~= nil and view.deleted == false and view.hidden == hiddenBefore + 1)
msg({ a = "pin", id = sp.active, text = "second\nline two" })
msg({ a = "edit", id = sp.active, text = "second\nline two!" })
msg({ a = "esc", id = sp.active, text = "second\nline two!" })
check("unpinned + Esc: the pad closes…", sp.webview == nil and view.deleted == true)
check("…and pending keystrokes were written first", store().tabs[#sp.tabs].text == "second\nline two!" and sp.dirty == false)
sp.show()
check("⇪1 again reopens with the text where it was", WEBVIEWS[#WEBVIEWS].htmlSet:find("line two!", 1, true) ~= nil)
sp.show()
check("⇪1 while open closes (toggle)", sp.webview == nil)

-- =======================================================================
out("6) the 16:00 task — one task, every section, 07:30 → 16:00, me\n")
-- =======================================================================
SUBMITS = {}
local ok, why = sp.send("scheduled")
check("with text the send is accepted", ok == true and #SUBMITS == 1, why)
local s = SUBMITS[1]
check("title is the prefix + the day", s and s.title:find("^Scorp pad · ") ~= nil, s and s.title)
check("notes hold the open tab under a ## heading", s and s.desc:find("## second\nsecond\nline two!", 1, true) ~= nil, s and s.desc)
check("notes hold the row closed today too", s and s.desc:find("## hello w (closed", 1, true) ~= nil)
check("assignee is me, no attachment", s and s.assignee == "me" and s.attach == "")
check("start 07:30 and due 16:00, both on today",
      s and s.extra.startDate == TODAY and s.extra.startTime == "07:30"
      and s.extra.dueDate == TODAY and s.extra.dueTime == "16:00")
check("the identifying comment rides on extra.comment", s and s.extra.comment == sp.comment and sp.comment:find("Sent by Hammerspoon", 1, true))
check("the day's checksum is remembered in the store", store().sent[TODAY] ~= nil)
ok, why = sp.send("scheduled")
check("sending again with nothing changed is skipped", ok == false and why == "unchanged" and #SUBMITS == 1)
sp.setText(sp.active, "second\nline two!!")
ok = sp.send("button")
check("a change sends again", ok == true and #SUBMITS == 2)
check("the report names the last send", _G.scratchPadReport():find("last send:", 1, true) ~= nil)
-- the scheduled timer runs the same path, inside pcall
SUBMITS = {}
sp.setText(sp.active, "third try")
sp.sendTimer:fire()
check("the 16:00 timer sends", #SUBMITS == 1 and SUBMITS[1].extra.dueTime == "16:00")
-- nothing to send
local keepTabs, keepHist = sp.tabs, sp.history
sp.tabs, sp.history = { { id = "x", text = "  ", createdAt = 0, updatedAt = 0 } }, {}
sp.active = "x"
ok, why = sp.send("scheduled")
check("an empty day is skipped, not sent", ok == false and why == "nothing to send")
sp.tabs, sp.history = keepTabs, keepHist
sp.active = sp.tabs[1].id
-- Asana off
CORE.asanaEnabled = false
sp.setText(sp.active, "asana off text")
ok, why = sp.send("scheduled")
check("Asana off: not sent, said in the Console, text kept",
      ok == false and why == "asana off" and PRINTED[#PRINTED]:find("Asana is off", 1, true)
      and sp.tabs[1].text == "asana off text")
CORE.asanaEnabled = true
-- validation rejected
SUBMIT_RESULT = false
sp.setText(sp.active, "rejected text")
ok, why = sp.send("scheduled")
check("a rejected submit keeps the text and is not marked sent", ok == false and why == "rejected" and sp.tabs[1].text == "rejected text")
SUBMIT_RESULT = true
check("_G.scratchPadSend() is the Console door", type(_G.scratchPadSend) == "function")

-- =======================================================================
out("7) degrade — no webview, a broken store, a failed write\n")
-- =======================================================================
local savedWebview = hs.webview
hs.webview = nil
PROMPT_ANSWER = { "Save", "typed in the plain box" }
sp.show()
check("no webview: the plain prompt opens on the current tab", #PROMPTS == 1 and PROMPTS[1].dflt == "rejected text")
check("…and Save edits + writes the tab", sp.tabs[1].text == "typed in the plain box" and store().tabs[1].text == "typed in the plain box")
hs.webview = savedWebview

WRITE_FAILS = true
sp.setText(sp.active, "kept in memory")
local okS = sp.saveNow()
check("a failed write is reported once through core.warnWriteFailed", okS == false and WRITE_WARNS[#WRITE_WARNS] == "scratch pad store")
check("...and SAID on screen, once per streak", ALERTS[#ALERTS]:find("NOT SAVED", 1, true) ~= nil)
local nAl = #ALERTS
sp.saveNow()
check("...the second failure in the streak is silent", #ALERTS == nAl)
check("...and the header wears the ⚠ badge on the next render", (function() sp.show(); local h = WEBVIEWS[#WEBVIEWS].htmlSet; sp.hide(); return h:find("⚠ not saved", 1, true) ~= nil end)())
check("…and the text is still in Lua", sp.tabs[1].text == "kept in memory")
check("…and the report shows the error", _G.scratchPadReport():find("⚠️", 1, true) ~= nil)
WRITE_FAILS = false
sp.saveNow()
check("a write that succeeds again says so", ALERTS[#ALERTS]:find("Saving again", 1, true) ~= nil)

-- a fresh module over a broken store starts empty and leaves the file
FILES[sp.file] = "<<not json>>"
_G.editors, _G.movablePanels = {}, {}
local mod2 = dofile(HS .. "/modules/scratch_pad.lua")
mod2.setup(CORE)
local sp2 = _G.scratchPad
check("an unreadable store starts with one blank tab and leaves the file", #sp2.tabs == 1 and FILES[sp2.file] == "<<not json>>")
check("…and says so in the report", _G.scratchPadReport():find("unreadable", 1, true) ~= nil)

-- =======================================================================
out("7b) 6.173.0 — hosted in the Vault window\n")
-- =======================================================================
do
    local HOST = { enabled = true, webview = nil, doc = nil, shows = {}, toggles = 0, hides = 0 }
    function HOST.showScratch(id) HOST.shows[#HOST.shows + 1] = id or "active"; HOST.webview = HOST.webview or {}; HOST.doc = { scratch = id or sp2.active } return true end
    function HOST.toggleScratch() HOST.toggles = HOST.toggles + 1; if HOST.webview then HOST.webview = nil; HOST.doc = nil else HOST.showScratch(nil) end return true end
    function HOST.hide() HOST.hides = HOST.hides + 1; HOST.webview = nil; HOST.doc = nil end
    _G.vault = HOST
    check("sp.host() is the vault when it is loaded and viaVault is on", sp2.host() == HOST and sp2.viaVault == true)
    sp2.viaVault = false
    check("viaVault = false → no host (the pad's own window)", sp2.host() == nil)
    sp2.viaVault = true
    HOST.enabled = false
    check("a disabled vault is no host", sp2.host() == nil)
    HOST.enabled = true
    sp2.show()
    check("⇪1 opens the vault on the tabs, no window of its own", HOST.toggles == 1 and HOST.webview ~= nil and sp2.webview == nil)
    sp2.show()
    check("⇪1 again closes it through the host", HOST.toggles == 2 and HOST.webview == nil)
    sp2.openKind("capture", { text = "from ⇪N" })
    local ct
    for _, t in ipairs(sp2.tabs) do if t.kind == "capture" then ct = t end end
    check("⇪N makes the Capture tab and shows it in the vault", ct and ct.text == "from ⇪N" and HOST.shows[#HOST.shows] == ct.id and sp2.active == ct.id)
    local ed
    for _, e in ipairs(_G.editors) do if e.name == "Scorp Pad" then ed = e end end
    check("the editors entry reports the host window while a tab is open there", ed and ed.view() == HOST.webview)
    HOST.doc = { rel = "Alpha.md" }
    check("…and nothing while the host shows a note", ed and ed.view() == nil)
    local plainBefore = 0
    for _, t in ipairs(sp2.tabs) do if not t.kind then plainBefore = plainBefore + 1 end end
    local keepSvc = _G.service
    local QUEUED = {}
    _G.service = { has = function(n) return n == "capturePad.add" end,
                   call = function(n, text) if n == "capturePad.add" then QUEUED[#QUEUED + 1] = text return true end end }
    sp2.onHostClose()
    _G.service = keepSvc
    local plainAfter = 0
    for _, t in ipairs(sp2.tabs) do if not t.kind then plainAfter = plainAfter + 1 end end
    check("the host closing files the Capture tab (capturePad.add) and keeps plain tabs",
          ct and sp2.findTab(ct.id) == nil and QUEUED[1] == "from ⇪N" and plainAfter == plainBefore)
    sp2.hide()
    check("sp.hide with the host open closes the host", HOST.hides == 1)
    check("the report says whose window it is", _G.scratchPadReport():find("window: the Vault's", 1, true) ~= nil)
    _G.vault = nil
end

-- =======================================================================
out("8) the source itself — no tap, no AX, wired everywhere\n")
-- =======================================================================
local function slurp(p) local f = assert(realIoOpen(p)); local s = f:read("a"); f:close(); return s end
local src   = slurp(HS .. "/modules/scratch_pad.lua")
local init  = slurp(HS .. "/init.lua")
local coex  = slurp(HS .. "/core/coexist.lua")
local uni   = slurp(HS .. "/modules/unified_search.lua")
local hints = slurp(HS .. "/modules/shortcut_hints.lua")
local tc    = slurp(HS .. "/modules/task_creator.lua")
local rt    = slurp(HS .. "/tools/run-tests.sh")
check("🚨 the module owns NO eventtap — nothing can swallow a key system-wide", src:find("hs%.eventtap%.new") == nil)
check("🚨 the module reads NO hs.window / axuielement", src:find("hs%.window") == nil and src:find("axuielement") == nil)
check("🚨 the module has no hs.hotkey of its own (⇪1 goes through core)", src:find("hs%.hotkey") == nil)
check("every hs.timer result is assigned (held)", not src:find("\n%s*hs%.timer%.do"))
check("init.lua loads scratch_pad", init:find('"scratch_pad"', 1, true) ~= nil)
check("the escape ladder has a scratchpad rung under taskform", coex:find("scratchpad =  74", 1, true) ~= nil)
check("⇪space has a Scratch pad source", uni:find('tag = "scratch"', 1, true) ~= nil and uni:find("scratch = 200", 1, true) ~= nil)
-- 6.182.0 — ⇪N and ⇪2 are filed; ⇪1 came OUT, because a group row for a
-- key nothing binds is dead config that outlives the key it described.
check("⇪N and ⇪2 are filed in the hint groups",
      hints:find('n = "Notes & capture"', 1, true) ~= nil
      and hints:find('["2"] = "Notes & capture"', 1, true) ~= nil)
check("…and ⇪1's row is gone with the key", hints:find('["1"] = "Notes & capture"', 1, true) == nil)
check("asanaSubmitTask honours extra.comment", tc:find("extra.comment", 1, true) ~= nil)
check("run-tests lists this suite", rt:find("test_scratch_pad", 1, true) ~= nil)

-- =======================================================================
out("9) ⇪N and ⇪2 open here — Capture / Append tabs file where they always did\n")
-- =======================================================================
_G.editors, _G.movablePanels = {}, {}
FILES = {}
local mod3 = dofile(HS .. "/modules/scratch_pad.lua")
mod3.setup(CORE)
sp = _G.scratchPad
local QUEUED, QUEUE_OK = {}, true
_G.service = {
    has  = function(n) return n == "capturePad.add" end,
    call = function(n, text)
        if n ~= "capturePad.add" then return nil end
        QUEUED[#QUEUED + 1] = text
        if not QUEUE_OK then return false, "queue full" end
        return true, { text = text }
    end,
}
local FILED, FILE_RESULT = {}, { true, "📝 1 Logs", "" }
_G.notePad = { fileAll = function(text) FILED[#FILED + 1] = text
    return FILE_RESULT[1], FILE_RESULT[2], FILE_RESULT[3] end }

check("openKind on an unknown kind is refused", sp.openKind("nope") == false)
check("⇪N with the pad closed opens it with a 🗒 Capture tab active",
      sp.openKind("capture") == true and sp.webview ~= nil and sp.activeTab().kind == "capture")
local cap = sp.activeTab()
check("the tab bar shows the badge and the header shows the kind's hint",
      WEBVIEWS[#WEBVIEWS].htmlSet:find("🗒 Capture", 1, true) and WEBVIEWS[#WEBVIEWS].htmlSet:find("queues this for the 4 PM", 1, true))
msg({ a = "edit", id = cap.id, text = "call Dana about the SAC values", sel = 5 })
sp.openKind("capture")
check("⇪N again reuses the one Capture tab (no second)",
      #sp.tabs == 2 and sp.activeTab().id == cap.id and sp.tabs[2].text == "call Dana about the SAC values")
check("⇪2 opens a ➕ Append tab seeded with the prefix",
      sp.openKind("append", { prefix = "* " }) and sp.activeTab().kind == "append" and sp.activeTab().text == "* ")
local app = sp.activeTab()
msg({ a = "edit", id = app.id, text = "* an idea\n+ a log line", sel = 3 })
check("openKind with text replaces the Append tab's text (the clipboard door)",
      sp.openKind("append", { text = "clip text" }) and app.text == "clip text" and #sp.tabs == 3)
msg({ a = "edit", id = app.id, text = "* an idea\n+ a log line", sel = 3 })

msg({ a = "close", id = cap.id, text = "call Dana about the SAC values", tid = cap.id })
check("⌘W on the Capture tab queues its text for the 4 PM send…", QUEUED[#QUEUED] == "call Dana about the SAC values")
check("…and it is gone from the tabs and in the history marked filed",
      sp.findTab(cap.id) == nil and sp.history[1].id == cap.id and sp.history[1].kind == "capture"
      and sp.history[1].filedAs:find("4 PM Asana queue", 1, true) ~= nil)
check("the history row wears the badge", WEBVIEWS[#WEBVIEWS].htmlSet:find('"🗒 call Dana', 1, true) ~= nil)

sp.openKind("capture", { text = "second capture" })
QUEUE_OK = false
local cap2 = sp.activeTab()
msg({ a = "close", id = cap2.id, text = "second capture", tid = cap2.id })
check("a failed queue KEEPS the tab and its text, and says so",
      sp.findTab(cap2.id) ~= nil and cap2.text == "second capture" and ALERTS[#ALERTS]:find("Kept in its tab", 1, true))
QUEUE_OK = true

FILE_RESULT = { false, "⚠️ Logs failed", "+ a log line" }
msg({ a = "close", id = app.id, text = "* an idea\n+ a log line", tid = app.id })
check("the Append tab routes through notePad.fileAll", FILED[#FILED] == "* an idea\n+ a log line")
check("a partial failure keeps ONLY the leftover lines in the tab", sp.findTab(app.id) ~= nil and app.text == "+ a log line")
FILE_RESULT = { true, "📝 1 Logs", "" }

-- closing the PAD files every kind tab, keeps the scratch ones
local plain = sp.tabs[1]
sp.setText(plain.id, "plain scratch text")
sp.hide()
check("closing the pad files the Append tab…", FILED[#FILED] == "+ a log line" and sp.findTab(app.id) == nil)
check("…and the Capture tab…", QUEUED[#QUEUED] == "second capture" and sp.findTab(cap2.id) == nil)
check("…and leaves the plain scratch tab alone", sp.findTab(plain.id) ~= nil and plain.text == "plain scratch text")

-- the pad's own 4 PM task never carries them
sp.openKind("capture", { text = "not for the day task" })
local _, notes = sp.dayBody(TODAY)
check("dayBody skips Capture/Append tabs and their history rows",
      notes:find("plain scratch text", 1, true) and not notes:find("not for the day task", 1, true)
      and not notes:find("call Dana", 1, true))
sp.hide()

-- the store round-trips the kind
_G.editors, _G.movablePanels = {}, {}
local mod4 = dofile(HS .. "/modules/scratch_pad.lua")
mod4.setup(CORE)
local kinds = {}
for _, h in ipairs(_G.scratchPad.history) do kinds[#kinds + 1] = tostring(h.kind) end
check("history kinds survive a reload", table.concat(kinds, ","):find("capture", 1, true) ~= nil)

local cp = slurp(HS .. "/modules/capture_pad.lua")
local npS = slurp(HS .. "/modules/note_pad.lua")
-- 6.182.0 — both pads still route into this one through openKind; what
-- changed is the DOOR, from a hyper key each to a row in the section.
-- So the routing assertions stay and a new one says the keys are gone:
-- if either module bound its old key again, two modules would fight for
-- it and the cheat sheet would show it twice.
check("capture_pad still routes to scratchPad.openKind('capture')",
      cp:find('_G.scratchPad.openKind("capture")', 1, true) and cp:find("pad.viaScratch = true", 1, true))
check("…and no longer binds ⇪N itself while viaScratch is on",
      cp:find("if not pad.viaScratch then", 1, true) ~= nil
      and cp:find('core.hyperAddShortcut({}, pad.key, function() pad.openHere() end', 1, true) ~= nil)
check("np.show routes to openKind('append') — except the 16:01 review",
      npS:find('_G.scratchPad.openKind("append"', 1, true) and npS:find("np.show({ review = true })", 1, true)
      and npS:find("np.viaScratch = true", 1, true))
check("…and note_pad's laptop key is cleared, not just unbound",
      npS:find("np.laptopKey = nil", 1, true) ~= nil)

print = realPrint
io.open, os.rename = realIoOpen, realRename
out("\n=== 6.170.0 — arrow through the history rows ===\n")
do
    local f = io.open(HS .. "/modules/scratch_pad.lua", "r"); local src = f:read("a"); f:close()
    check("the page carries the row walker over #rows .row",
          src:find("ROWSEL = '#rows .row'", 1, true) and src:find("function rowKey(e)", 1, true)
          and src:find("function moveSel(d)", 1, true))
    check("⏎ on a highlighted row restores it, the same message a click sends",
          src:find("function rowAct(r){ say({a:'restore', rid: r.getAttribute('data-id')}); }", 1, true) ~= nil)
    check("the keydown handler asks the walker first, after Esc", (function()
        local a = src:find("say({a:'esc'}); return; }", 1, true)
        local b = src:find("if (rowKey(e)) return;", 1, true)
        return a and b and b > a and b - a < 80
    end)())
    check("a new filter resets the highlight", src:find("SEL = -1; draw();", 1, true) ~= nil)
    check("the highlight has a style", src:find(".row.sel{", 1, true) ~= nil)
    check("the text box keeps plain arrows (inText checks TEXTAREA)",
          src:find("a.tagName === 'TEXTAREA'", 1, true) ~= nil)
end

out("\n=== 6.177.0 — the way out: every tab as a .md note Obsidian opens ===\n")
do
    -- the controllable world again (the sections above hand io.open back)
    local READS = {}
    io.open = function(path, mode)
        if (mode or "r"):find("w") then
            if WRITE_FAILS or (WRITE_BLOCK and path:find(WRITE_BLOCK, 1, true)) then return nil end
            local buf = {}
            return { write = function(_, s) buf[#buf + 1] = s return true end,
                     close = function() FILES[path] = table.concat(buf) end }
        end
        READS[#READS + 1] = path
        if FILES[path] == nil then return nil end
        local content, done = FILES[path], false
        return { read = function() if done then return nil end done = true return content end,
                 close = function() end }
    end
    os.rename = function(a, b)
        if FILES[a] == nil then return nil, "no such file" end
        FILES[b] = FILES[a]; FILES[a] = nil
        return true
    end
    local realExecute = os.execute
    local EXEC = {}
    os.execute = function(cmd) EXEC[#EXEC + 1] = cmd return true end

    local function reset()
        FILES = {}
        sp.tabs, sp.history, sp.exported, sp.lastExport = {}, {}, {}, nil
        sp.exportToVault, sp.exportHistory, sp.exportMax = true, true, 500
        sp.active = nil
        _G.vault = nil
        sp.cloudDir = nil
    end
    local function md(name) return FILES["/logs/vault/Scratch/" .. name] end
    local function mdNames()
        local n = {}
        for path in pairs(FILES) do
            local f = path:match("^/logs/vault/Scratch/(.+)$")
            if f then n[#n + 1] = f end
        end
        table.sort(n)
        return n
    end

    -- ---- where the notes go, on either Mac -------------------------------
    reset()
    local dir, how = sp.exportDir()
    check("with no vault module and no OneDrive the notes still have a home",
          dir == "/logs/vault/Scratch" and how == "local", dir .. " / " .. tostring(how))
    _G.vault = { dir = "/od/Vault" }
    dir, how = sp.exportDir()
    check("...the loaded vault's own folder is the truth when it is up",
          dir == "/od/Vault/Scratch" and how == "vault", dir)
    _G.vault = nil
    sp.cloudDir = "/od"
    dir, how = sp.exportDir()
    check("...and without the module it works out the SAME folder from OneDrive",
          dir == "/od/Vault/Scratch" and how == "cloud", dir)
    _G.vault = { dir = "" }
    check("an empty vault dir is not trusted — the fallback takes over",
          (select(1, sp.exportDir())) == "/od/Vault/Scratch")

    -- ---- names Finder, OneDrive and Obsidian all accept -------------------
    reset()
    check("a slash in a title never becomes a folder", sp.exportSafeName("costs 50/50 split") == "costs 50-50 split")
    check("colons, stars and quotes go too", sp.exportSafeName('a:b*c"d?e') == "a-b-c-d-e")
    check("a newline is not a file name", sp.exportSafeName("first line\nsecond") == "first line second")
    check("a leading dot never makes a hidden file", sp.exportSafeName(".hidden") == "hidden")
    check("nothing to name is still named", sp.exportSafeName("   ") == "Scratch")
    check("a long title is cut, not refused", #sp.exportSafeName(string.rep("x", 200)) == sp.exportNameChars)

    -- ---- the name a tab keeps forever ------------------------------------
    reset()
    local n1 = sp.exportNameFor("t1", "Shopping")
    check("a tab's file is named for its first line", n1 == "Shopping.md")
    check("...and asking again gives the SAME name, so a second export updates it",
          sp.exportNameFor("t1", "Renamed since") == "Shopping.md")
    check("a second tab with the same title gets its own file",
          sp.exportNameFor("t2", "Shopping") == "Shopping 2.md")
    check("the ledger lives in the store", sp.exported.t1 == "Shopping.md" and sp.exported.t2 == "Shopping 2.md")

    -- ---- the export itself ------------------------------------------------
    reset()
    sp.newTab("Milk\nBread")
    sp.newTab("")                     -- an empty tab is nothing to export
    sp.history = { { id = "h1", title = "Old thought", text = "was thinking", closedAt = os.time() } }
    local ok, summary = sp.exportAll("test")
    check("the export says it worked", ok == true, summary)
    check("one file per tab with text, and none for the empty one", #mdNames() == 2, table.concat(mdNames(), ", "))
    check("the closed-tab history comes too", md("Old thought.md") ~= nil)
    local body = md("Milk.md") or ""
    check("the note opens as Markdown with front matter Obsidian reads",
          body:find("^---\n") and body:find("\ntitle: Milk\n", 1, true) and body:find("\n---\n\n", 1, true))
    check("...it says where it came from", body:find("\nsource: Scorp Pad\n", 1, true) ~= nil)
    check("...and wears a tag, so the vault's tag list finds them all",
          body:find("\ntags: scorp%-pad\n") ~= nil)
    check("the text is the text — no Markdown is invented for LL",
          body:find("\n\nMilk\nBread\n$") ~= nil, body)
    check("no .tmp is left behind", (function()
        for path in pairs(FILES) do if path:find("%.tmp$") then return false end end
        return true
    end)())
    check("the summary names the folder", summary:find("/logs/vault/Scratch", 1, true) ~= nil, summary)
    check("...and says honestly that this Mac had no OneDrive",
          summary:find("no OneDrive found", 1, true) ~= nil, summary)
    check("the report of the last run is kept", sp.lastExport and sp.lastExport.wrote == 2)
    check("the ledger was saved with the store, so the names survive a reload",
          (function() local st = store() return st and st.exported and st.exported ~= nil end)())
    check("no file in the vault was READ — a OneDrive placeholder read can block", (function()
        for _, p in ipairs(READS) do if p:find("/vault/", 1, true) then return false end end
        return true
    end)())

    -- exporting twice updates the same files instead of breeding copies
    local before = #mdNames()
    sp.exportAll("again")
    check("a second export updates the same files", #mdNames() == before, table.concat(mdNames(), ", "))

    -- ---- the switches -----------------------------------------------------
    reset()
    sp.newTab("only the open one")
    sp.history = { { id = "h1", title = "Closed", text = "closed text" } }
    sp.exportHistory = false
    sp.exportAll("no history")
    check("exportHistory = false leaves the history behind", md("Closed.md") == nil and #mdNames() == 1)

    reset()
    sp.newTab("one"); sp.newTab("two"); sp.newTab("three")
    sp.exportMax = 2
    local okM, sumM = sp.exportAll("capped")
    check("exportMax stops the export and SAYS it stopped",
          #mdNames() == 2 and sumM:find("stopped at 2", 1, true) ~= nil, sumM)

    reset()
    sp.newTab("something")
    sp.exportToVault = false
    local okOff, whyOff = sp.exportAll("off")
    check("with the export switched off nothing is written and the reason is named",
          okOff == false and #mdNames() == 0 and whyOff:find("export is off", 1, true) ~= nil, whyOff)

    -- ---- it degrades, it never breaks -------------------------------------
    reset()
    sp.newTab("keeps its text")
    WRITE_BLOCK = "/logs/vault/Scratch/"
    local okF, sumF = sp.exportAll("write fails")
    WRITE_BLOCK = nil
    check("an unwritable vault folder fails honestly", okF == false and sumF:find("could not be written", 1, true), sumF)
    check("...and the tab still has every word of its text",
          sp.tabs[1].text == "keeps its text" and #sp.tabs == 1)
    check("...and the pad's own store is untouched by the failure", sp.lastSaveErr == nil)

    reset()
    sp.newTab("first"); sp.newTab("second")
    WRITE_BLOCK = "/logs/vault/Scratch/first.md"
    local okP, sumP = sp.exportAll("one fails")
    WRITE_BLOCK = nil
    check("one file failing costs that file, not the export",
          md("second.md") ~= nil and okP == false and sumP:find("1 could not be written", 1, true), sumP)

    -- ---- the doors in -----------------------------------------------------
    reset()
    sp.newTab("through the page")
    local alertsBefore = #ALERTS
    msg({ a = "export" })
    check("⌘⇧S from the page exports and says what happened on screen",
          md("through the page.md") ~= nil and #ALERTS > alertsBefore
          and tostring(ALERTS[#ALERTS]):find("📤", 1, true), tostring(ALERTS[#ALERTS]))
    reset()
    sp.newTab("from the Console")
    -- (an earlier section loaded a SECOND copy of the module, so the global
    -- belongs to that one — here we prove the door exists and reports.)
    local realP = print; print = function() end
    local okC, sumC = _G.scorpPadExport()
    print = realP
    check("_G.scorpPadExport() is the Console door and always reports",
          type(_G.scorpPadExport) == "function" and type(sumC) == "string"
          and sumC:find("Scratch", 1, true) ~= nil, tostring(sumC))
    check("...and the pad's own export writes the note", (function()
        local okE = sp.exportAll("console")
        return okE == true and md("from the Console.md") ~= nil
    end)(), table.concat(mdNames(), ", "))

    reset()
    os.execute = realExecute
    io.open, os.rename = realIoOpen, realRename
end

do
    local f = io.open(HS .. "/modules/scratch_pad.lua", "r"); local src = f:read("a"); f:close()
    check("the page sends ⌘⇧S as the export",
          src:find("e.shiftKey && (e.key === 's' || e.key === 'S')", 1, true) ~= nil)
    local vf = io.open(HS .. "/modules/vault.lua", "r"); local vsrc = vf:read("a"); vf:close()
    check("the Vault window has the same key, and hands the work to the pad",
          vsrc:find("say({a:'export'})", 1, true) and vsrc:find('elseif a == "export" then', 1, true))
    check("...and the vault never assumes the pad is loaded",
          vsrc:find('"the Scorp Pad is not loaded"', 1, true) ~= nil)
    check("the report names the folder and the last run",
          src:find('"   export: ⌘⇧S → "', 1, true) ~= nil)
end


-- =======================================================================
out("\n=== 6.182.0 — ⇪2, the sequential copy ===\n")
-- =======================================================================
-- LL: "Can I select some text, and then immediately select some more text
-- and have it append the text I just copied a few seconds before … so I
-- can build a block of text that I can then edit quickly instead of
-- having to make multiple copy/pastes."
do
    sp.tabs, sp.history, sp.collectId, sp.collectCount = {}, {}, nil, 0
    PASTED, ALERTS = {}, {}

    local ok1, block1 = sp.collect("first piece")
    check("the first grab makes ONE Collect tab and holds the text",
          ok1 and #sp.tabs == 1 and sp.collectId == sp.tabs[1].id
          and sp.tabs[1].text:find("first piece", 1, true) ~= nil, tostring(block1))
    local madeOne = sp.tabs[1].id

    local ok2, block2 = sp.collect("second piece")
    check("the second grab APPENDS to the same tab — no second Collect tab "
          .. "(this is the row that fails if the id is not remembered)",
          ok2 and #sp.tabs == 1 and sp.tabs[1].id == madeOne
          and block2:find("first piece", 1, true) and block2:find("second piece", 1, true),
          tostring(block2))
    check("…separated by the join, so the pieces do not run together",
          block2:find("first piece" .. sp.collectJoin .. "second piece", 1, true) ~= nil, block2)
    check("…and the count is what the alert will say", sp.collectCount == 2, sp.collectCount)

    check("an empty selection is refused and changes nothing",
          (function()
              local okE, why = sp.collect("   \n  ")
              return okE == false and why:find("nothing", 1, true) and sp.collectCount == 2
          end)())

    -- The tab id is what survives a reload; without it a restart would
    -- silently start a SECOND Collect tab beside the first, and the block
    -- would quietly split in half. (io.open is the real one by this point
    -- in the suite, so this is asserted against the source: both halves,
    -- the write and the read back — one without the other is useless.)
    do
        local src = slurp(HS .. "/modules/scratch_pad.lua")
        check("the Collect tab's id is written to the store AND read back",
              src:find("collectId = sp.collectId", 1, true) ~= nil
              and src:find('sp.collectId = type(data.collectId) == "string"', 1, true) ~= nil)
    end

    -- ⌘W can send the Collect tab to the history; the next grab must
    -- start a fresh one rather than resurrect a tab that is not there
    sp.tabs = {}
    local ok3 = sp.collect("after it was closed")
    check("…and if that tab has gone, the next grab starts a new one",
          ok3 and #sp.tabs == 1 and sp.collectId == sp.tabs[1].id
          and sp.collectId ~= madeOne)
end

do
    -- the key: selection in, tab + clipboard + alert out
    sp.tabs, sp.collectId, sp.collectCount = {}, nil, 0
    PASTED, ALERTS, PB_FAIL, PB_REFUSE = {}, {}, false, false
    local keepSvc = _G.service
    _G.service = {
        has  = function(n) return n == "power.readSelection" end,
        call = function(_, _, done) done("a sentence from the page") return true end,
    }
    sp.collectFromSelection()
    check("⇪2 reads the selection through power_tools' ONE reader and appends it",
          #sp.tabs == 1 and sp.tabs[1].text:find("a sentence from the page", 1, true) ~= nil)
    check("…and the WHOLE block goes on the clipboard, so ⌘V pastes the lot",
          PASTED[#PASTED] == sp.tabs[1].text, tostring(PASTED[#PASTED]))
    check("…and the alert names the running count and the ⌘V",
          ALERTS[#ALERTS]:find("1 grab", 1, true) and ALERTS[#ALERTS]:find("⌘V", 1, true),
          ALERTS[#ALERTS])

    -- 🛟 the clipboard half may fail; the grab must NOT be lost with it
    PB_FAIL = true
    sp.collectFromSelection()
    check("🛟 a pasteboard that refuses does not lose the grab",
          sp.collectCount == 2 and select(2, sp.tabs[1].text:gsub("a sentence from the page", "")) == 2)
    check("…and it SAYS so rather than claiming the copy worked",
          ALERTS[#ALERTS]:find("clipboard refused", 1, true) ~= nil
          and ALERTS[#ALERTS]:find("⌘V pastes", 1, true) == nil, ALERTS[#ALERTS])
    PB_FAIL = false

    -- 🚨 6.198.0 — the refusal that does NOT throw. Same promise, and
    -- until now the module read two values from the pcall and announced
    -- "⌘V pastes the block" over a pasteboard that had just said no.
    PB_REFUSE = true
    sp.collectFromSelection()
    check("🚨 a pasteboard answering FALSE is a refusal too, and is said",
          ALERTS[#ALERTS]:find("clipboard refused", 1, true) ~= nil
          and ALERTS[#ALERTS]:find("⌘V pastes", 1, true) == nil, ALERTS[#ALERTS])
    check("…and that grab is not lost either", sp.collectCount == 3,
          sp.collectCount)
    PB_REFUSE = false

    -- 🛟 no power_tools at all
    _G.service = { has = function() return false end }
    ALERTS = {}
    local okNo, whyNo = sp.collectFromSelection()
    check("🛟 without Power Tools it says so and does nothing",
          okNo == false and whyNo:find("power_tools", 1, true)
          and ALERTS[#ALERTS]:find("needs Power Tools", 1, true) ~= nil, ALERTS[#ALERTS])
    _G.service = keepSvc
end

do
    local src = slurp(HS .. "/modules/scratch_pad.lua")
    check("🚨 the sequential copy NEVER raises the window — the point is "
          .. "that you stay in the page you are reading",
          src:find("function sp.collectFromSelection", 1, true) ~= nil
          and src:match("function sp%.collectFromSelection.-\n    end"):find("sp.open()", 1, true) == nil)
    local vsrc = slurp(HS .. "/modules/vault.lua")
    check("the vault section is SCRATCH NOTES, with the two + rows in it",
          vsrc:find("📝 SCRATCH NOTES", 1, true) and vsrc:find('data-tab="+capture"', 1, true)
          and vsrc:find('data-tab="+append"', 1, true))
    check("…and those rows route through the same openKind the old keys used",
          vsrc:find("a:'tabkind'", 1, true) and vsrc:find('elseif a == "tabkind" then', 1, true)
          and vsrc:find("pcall(sp.openKind, kind)", 1, true))
    check("…and a × on a + row can never be read as closing a tab",
          vsrc:find("tid.charAt(0) !== '+'", 1, true) ~= nil)
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
