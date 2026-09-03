-- =====================================================================
-- test_power_tools.lua — ⇪; types, counts, strips and reads metadata
-- =====================================================================
--     lua5.4 test_power_tools.lua [/path/to/hammerspoon]
--
-- Executes modules/power_tools.lua against a stubbed hs.
--
-- THREE SECTIONS HAVE TEETH:
--
--   §4 SECURE INPUT COMES FIRST. Under secure event input macOS drops
--      synthetic keystrokes at the window server: nothing arrives, no
--      error is raised, and the field stays empty. Typing anyway and
--      reporting success is the worst available outcome, so the check
--      must happen BEFORE a single character is posted.
--
--   §5 EXACTLY ONE CALLBACK, EVER. The first draft of whenClear used a
--      doWhile to wait plus a doAfter to decide what happened next —
--      two timers that could BOTH reach the callback. "The clipboard
--      was typed twice" cannot be undone out of a text field, so the
--      count is asserted rather than assumed.
--
--   §6 THE BORROWED CLIPBOARD GOES BACK. Reading a selection costs a
--      ⌘C, which means overwriting whatever you had copied. A tool that
--      keeps it is a tool you stop using, and the restore happens on
--      EVERY path including the one where the copy came back empty.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local CLIP       = nil          -- what the pasteboard holds
local FLAVORS    = { "public.utf8-plain-text" }
local SET_CALLS  = 0
local CLEARED    = 0
local TYPED      = {}           -- every keyStrokes burst, in order
local KEYSTROKES = {}           -- every keyStroke (modifier) call
local SECURE     = false
local MODS       = {}
local AX         = true
local AXSEL      = nil          -- what AXSelectedText answers
local AXTIMEOUTS = {}           -- every setTimeout call, by element
local ALERTS     = {}
local TIMERS     = {}           -- doAfter
local EVERY      = {}           -- doEvery
local NOW        = 1000
local CHOOSERS   = {}
local SHOWS      = 0
local TASKS      = {}
local SUPPRESSED = 0
local SYSKEYS    = {}           -- every media key posted
local FRONT_APP  = "TextEdit"
local FRONT_TITLE = nil         -- the focused window's title
-- Which apps this pretend Mac has open. Empty by default: the pause key
-- must do the right thing on a Mac with no player running, and that is
-- the case it is easiest to forget to test.
local RUNNING    = {}
local GETCALLS   = 0            -- hs.application.get calls — must stay 0
local SERVICE_HAS = true        -- is screenshots loaded?
local ZBAR       = "/opt/homebrew/bin/zbarimg"

hs = {
    accessibilityState = function() return AX end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = {
        getContents    = function() return CLIP end,
        setContents    = function(s) CLIP = s ; SET_CALLS = SET_CALLS + 1
                                     FLAVORS = { "public.utf8-plain-text" } end,
        clearContents  = function() CLIP = nil ; CLEARED = CLEARED + 1 end,
        contentTypes   = function() return FLAVORS end,
    },
    eventtap = {
        event = {
            newSystemKeyEvent = function(key, down)
                local e = { key = key, down = down }
                function e:post() SYSKEYS[#SYSKEYS + 1] = self ; return self end
                return e
            end,
        },
        keyStrokes = function(s) TYPED[#TYPED + 1] = s end,
        keyStroke  = function(mods, key) KEYSTROKES[#KEYSTROKES + 1] =
                         (mods[1] or "") .. "+" .. key end,
        isSecureInputEnabled     = function() return SECURE end,
        checkKeyboardModifiers   = function() return MODS end,
    },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            EVERY[#EVERY + 1] = t
            return t
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "", query_ = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args, started = false,
                        terminated = false }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    fs = {
        -- The two directories that exist in this stub Mac. pathFromTitle
        -- refuses a path that is not there, because Finder opening
        -- nothing is worse than being told the title was not a path.
        attributes = function(p, what)
            local dirs = { ["/Users/test/code"] = true, ["/Users/test"] = true }
            if dirs[p] then
                if what == "mode" then return "directory" end
                return { mode = "directory", size = 128 }
            end
            if what == "mode" and p:find("^/Users/test/gone") then return nil end
            local a = { size = 2048, mode = "file", modification = 1700000000,
                        creation = 1600000000, access = 1700000001,
                        permissions = "rw-r--r--", uid = 501, gid = 20, nlink = 1 }
            if what then return a[what] end
            return a
        end,
    },
    axuielement = {
        applicationElement = function()
            local el = {}
            function el:setTimeout(n) AXTIMEOUTS[#AXTIMEOUTS + 1] = n ; return self end
            function el:attributeValue(name)
                if name == "AXFocusedUIElement" then
                    local f = {}
                    function f:setTimeout(n) AXTIMEOUTS[#AXTIMEOUTS + 1] = n
                                             return self end
                    function f:attributeValue(n2)
                        if n2 == "AXSelectedText" then return AXSEL end
                        return nil
                    end
                    return f
                end
                return nil
            end
            return el
        end,
    },
    application = {
        frontmostApplication = function()
            return {
                name = function() return FRONT_APP end,
                focusedWindow = function()
                    if FRONT_TITLE == nil then return nil end
                    return { title = function() return FRONT_TITLE end }
                end,
            }
        end,
        -- 🚨 STILL ASKED OF HAMMERSPOON, NOT OF APPLESCRIPT — naming an
        -- app to AppleScript launches it. But since 6.137.0 the question
        -- is ONE bulk runningApplications() sweep: get() by name measured
        -- ~3,000ms per MISS on macOS 27, and the pause key paid it per
        -- player precisely when no player was open. get stays here only
        -- as a tripwire — the module must never call it again.
        runningApplications = function()
            local list = {}
            for n in pairs(RUNNING) do
                list[#list + 1] = { name = function() return n end }
            end
            return list
        end,
        get = function(n) GETCALLS = GETCALLS + 1
                          return RUNNING[n] and { name = function() return n end } or nil end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.pasteboardSuppress = function() SUPPRESSED = SUPPRESSED + 1 end
-- The service registry, as power_tools sees it: it asks screenshots.lua
-- where zbarimg is rather than keeping a second copy of the search list.
-- 🔠 6.132.0 — the case rows go through the REAL modules/text_case.lua,
-- loaded here rather than stubbed. A stub that answers case.apply with
-- whatever the test expects proves only that the test agrees with itself;
-- what can actually break is the two files disagreeing.
local CASE_SERVICES = {}
do
    local tcChunk = assert(loadfile(HS .. "/modules/text_case.lua"))
    local TCM = tcChunk()
    TCM.setup({ provide = function(n, f) CASE_SERVICES[n] = f end })
end
local CASE_OFF = false   -- a Mac where text_case failed to load
_G.service = {
    has  = function(n)
        if n == "shots.zbarPath" then return SERVICE_HAS end
        return (not CASE_OFF) and CASE_SERVICES[n] ~= nil
    end,
    call = function(n, ...)
        if n == "shots.zbarPath" then return ZBAR end
        if CASE_OFF then return nil end
        local f = CASE_SERVICES[n]
        if f then return f(...) end
    end,
}

local BOUND, PROVIDED = {}, {}
local CORE = {
    homeDir = "/Users/test",
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/power_tools.lua"))
local M = chunk()
M.setup(CORE)
local pt = _G.powerTools

local function reset()
    TYPED, KEYSTROKES, ALERTS, TIMERS, EVERY = {}, {}, {}, {}, {}
    SYSKEYS = {}
    SET_CALLS, CLEARED, SUPPRESSED = 0, 0, 0
    MODS, SECURE, AXSEL = {}, false, nil
    pt.lastNote = nil
    pt.settleTimer, pt.startTimer = nil, nil
end

-- Run every pending doAfter once, newest last, until none are left.
-- ⚠️ A STOPPED TIMER IS NEVER FIRED, because Hammerspoon does not fire
-- one either. A stub that ignores :stop() tests a world that cannot
-- happen and hides the world that can.
local function runAfters(n)
    for _ = 1, (n or 10) do
        local pending = TIMERS
        if #pending == 0 then return end
        TIMERS = {}
        for _, t in ipairs(pending) do
            if not t.stopped then t.fn() end
        end
    end
end

-- Drain EVERYTHING — repeating timers and one-shots alike — the way a
-- real Mac would over the next second. Used where the question is "how
-- many times did this happen in total", which is the only shape that
-- catches two timers racing to the same callback.
local function drain(rounds)
    for _ = 1, (rounds or 60) do
        local moved = false
        for _, t in ipairs(EVERY) do
            if not t.stopped then t.fn() ; moved = true end
        end
        if #TIMERS > 0 then
            local pending = TIMERS
            TIMERS = {}
            for _, t in ipairs(pending) do
                if not t.stopped then t.fn() ; moved = true end
            end
        end
        if not moved then return end
    end
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Power Tools")
check("it declares a family", M.family == "text")
check("⇪; is bound", BOUND["+;"] ~= nil)
check("the binding is attributed to this module",
      BOUND["+;"] and BOUND["+;"].src == "power tools")
check("it publishes _G.powerTools", type(pt) == "table")
check("every action has a service", PROVIDED["power.plain"] and PROVIDED["power.type"]
      and PROVIDED["power.count"] and PROVIDED["power.metadata"]
      and PROVIDED["power.show"] and PROVIDED["power.report"])
check("the cheat sheet key cell is exactly ⇪;", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪;" then return true end
    end
    return false
end)())
check("all eighteen tools are in the list", #pt.tools == 18, #pt.tools)
check("…and each has a stable id", (function()
    -- 6.132.0 added countclip and case; 6.133.0 added define; 6.139.0
    -- added backup and backupreport; 6.140.0 added the grayscale relay
    -- rows; 6.142.0 added freekeys (the future-options ledger); 6.145.0
    -- retired the grayscale setup row with its console door; 6.147.0
    -- added defaultapp — LL called the keyless 📎 tool "buried", and
    -- ⇪; is where the act-now tools live; 6.152.0 added hspause (the
    -- ⇪⇧1 pause-Hammerspoon switch). ids are what
    -- _G.powerReport() counts by and what ⇪space's run map points
    -- at, so they are checked by name rather than by number alone.
    local want = { plain = true, type = true, count = true, meta = true,
                   pause = true, hspause = true,
                   ghere = true, greveal = true, qr = true,
                   countclip = true, case = true, define = true,
                   backup = true, backupreport = true,
                   mono = true, invert = true,
                   freekeys = true, defaultapp = true }
    for _, t in ipairs(pt.tools) do
        if not want[t.id] then return false end
        want[t.id] = nil
    end
    return next(want) == nil
end)())

-- 🌑 6.140.0 — THE GRAYSCALE ROWS HOLD NO LOGIC. Both go through
-- pt.veilCall, which asks the service registry for screen_veil's
-- provider. The row must say so plainly when the veil is not loaded,
-- and must RELAY — not reimplement — when it is.
reset()
check("the mono row without Screen Veil says so instead of failing quietly",
      pt.run("mono") == false
      and ALERTS[1] ~= nil
      and ALERTS[1]:find("Screen Veil module is not loaded", 1, true) ~= nil)
do
    local relayed = {}
    CASE_SERVICES["veil.mono"]      = function() relayed.mono   = true; return true end
    CASE_SERVICES["veil.invert"]    = function() relayed.invert = true; return true end
    reset()
    check("with Screen Veil loaded, mono and invert relay by service name",
          pt.run("mono") == true and pt.run("invert") == true
          and relayed.mono and relayed.invert)
end
-- 🪦 6.145.0 — the setup row retired with the setup door itself, at
-- LL's word. The exact-set check above already refuses a stray id;
-- this names the absence so a revival cannot land quietly.
check("🪦 the setup row is gone — the tick is made by hand, and the "
      .. "native triple-press of Touch ID walks there",
      pt.byId("monoset") == nil)
-- 🔑 THE FOUR WITH A KEY OF THEIR OWN. ⇪⇧, and ⇪⇧. are NOT among them
-- and must never be: numpad_layer's laptop window row has claimed both
-- since 6.114.0 (shrink and grow), and the first draft of this release
-- pointed two tools at them. The hyper sentry would have printed a
-- conflict at boot and one of the window keys would have gone quietly
-- dead, which is the failure this config exists to prevent.
check("⇪' pauses everything", BOUND["+'"] ~= nil)
check("⇪` opens Ghostty here", BOUND["+`"] ~= nil)
check("⇪⇧` reveals it in Finder", BOUND["shift+`"] ~= nil)
check("⇪5 reads a QR code", BOUND["+5"] ~= nil)
check("🚨 nothing here claims ⇪⇧, or ⇪⇧. — numpad_layer owns both",
      BOUND["shift+,"] == nil and BOUND["shift+."] == nil)
check("each new key is attributed to what it does", (function()
    return BOUND["+'"].src == "pause all media"
       and BOUND["+`"].src == "ghostty here"
       and BOUND["shift+`"].src == "reveal ghostty"
       and BOUND["+5"].src == "read a QR code"
end)())

-- =====================================================================
out("\n=== 1b. ⏸ 6.152.0 — pause Hammerspoon itself (⇪⇧1) ===\n")
-- =====================================================================
-- LL: "Can I pause Hammerspoon using an empty key from my Cheat Sheet?"
-- The key toggles _G.hsPaused; init.lua's hyperBind honours it for every
-- OTHER shortcut, and the typing taps carry their own guards. What THIS
-- module owes: the binding, the published combo, the flag's lifecycle,
-- and a menu-bar marker with a way back.
check("⇪⇧1 is bound to the pause switch", BOUND["shift+1"] ~= nil
      and BOUND["shift+1"].src == "pause Hammerspoon")
check("…its normalized combo is published for init.lua's wrap, hint too",
      _G.hsPauseCombo == "shift+1"
      and tostring(_G.hsPauseHint):find("1", 1, true) ~= nil, _G.hsPauseCombo)
local MENUBARS = {}
hs.menubar = { new = function()
    local mb = { deleted = false }
    function mb:setTitle(t) self.title = t ; return self end
    function mb:setTooltip(t) self.tip = t ; return self end
    function mb:setClickCallback(f) self.click = f ; return self end
    function mb:delete() self.deleted = true end
    MENUBARS[#MENUBARS + 1] = mb
    return mb
end }
ALERTS = {}
_G.hsPaused = false
BOUND["shift+1"].fn()
check("one press raises _G.hsPaused and SAYS so", _G.hsPaused == true
      and (ALERTS[1] or ""):find("paused", 1, true) ~= nil, ALERTS[1])
check("…and the alert names the way back", (ALERTS[1] or ""):find("resumes", 1, true) ~= nil)
check("…with a ⏸ HS flag standing in the menu bar",
      MENUBARS[1] and MENUBARS[1].title == "⏸ HS"
      and MENUBARS[1].deleted == false)
BOUND["shift+1"].fn()
check("the second press resumes and takes the flag down",
      _G.hsPaused == false and MENUBARS[1].deleted == true)
check("clicking the menu-bar flag resumes too — no keyboard needed",
      (function()
    BOUND["shift+1"].fn()
    local mb = MENUBARS[#MENUBARS]
    if not (mb and mb.click) then return false end
    mb.click()
    return _G.hsPaused == false and mb.deleted
end)())
check("hspause is a palette row, so ⇪; finds it when the key is forgotten",
      (function()
    for _, t in ipairs(pt.tools) do if t.id == "hspause" then return true end end
end)())
_G.hsPaused = false

-- =====================================================================
out("\n=== 2. 🔢 the counters, which are pure functions of a string ===\n")
-- =====================================================================
check("words: a plain sentence", pt.countWords("one two three") == 3)
check("words: runs of whitespace do not inflate it",
      pt.countWords("  one   two \n three  ") == 3,
      pt.countWords("  one   two \n three  "))
check("words: empty text is zero", pt.countWords("") == 0)
check("words: whitespace only is zero", pt.countWords("   \n\t ") == 0)

local total, bare, bytes = pt.countChars("hello world")
check("characters: counted with spaces", total == 11, total)
check("…and again without them", bare == 10, bare)
-- 🚨 #s is BYTES. A curly quote is three of them and one character, so a
-- byte count reports a paragraph as longer than it is.
local t2, b2, by2 = pt.countChars("don’t")
check("characters: a curly apostrophe is ONE character", t2 == 5, t2)
check("…and THREE bytes, which is why # is not the answer", by2 == 7, by2)
check("…and the byte count is reported separately, not instead", by2 ~= t2)

check("sentences: three plain ones",
      pt.countSentences("One. Two! Three?") == 3,
      pt.countSentences("One. Two! Three?"))
check("sentences: text with no punctuation is still one",
      pt.countSentences("no full stop here") == 1)
check("sentences: an unterminated last sentence is counted",
      pt.countSentences("First one. And a second without a stop") == 2,
      pt.countSentences("First one. And a second without a stop"))
check("sentences: empty text is zero", pt.countSentences("") == 0)
-- 🚨 THE + QUANTIFIER IS LOAD-BEARING. "Wait... what?" ends with a run
-- of three dots and one question mark: two sentences, not four. Drop the
-- + and every trailing ellipsis in the document inflates the count.
check("sentences: a run of dots is ONE terminator, not three",
      pt.countSentences("Wait... what?") == 2,
      pt.countSentences("Wait... what?"))
check("sentences: a real ellipsis character mid-sentence does not split it",
      pt.countSentences("Well… maybe.") == 1,
      pt.countSentences("Well… maybe."))

local lines, paras = pt.countLines("a\nb\n\nc")
check("lines counted", lines == 4, lines)
check("blank lines do not count as paragraphs", paras == 3, paras)

local st = pt.statsFor("Hello there. This is a test!")
check("statsFor returns all five numbers",
      st.words == 6 and st.sentences == 2 and st.lines == 1
      and st.paragraphs == 1 and st.chars == 28,
      st.words .. "/" .. st.sentences .. "/" .. st.chars)
-- ⚠️ The ~ is the honesty marker on an estimate. It is asserted because
-- dropping it turns "about two" into "two", which is a different claim.
check("the sentence figure is presented with a ~",
      pt.statsText(st):find("~", 1, true) ~= nil, pt.statsText(st))
check("…and the word and character figures are NOT", (function()
    local s = pt.statsText(st)
    local wordPart = s:match("(%d+ words)")
    return wordPart ~= nil and not s:find("~%d+ words")
end)())

-- =====================================================================
out("\n=== 3. 📋 strip clipboard formatting ===\n")
-- =====================================================================
reset()
CLIP, FLAVORS = "styled text", { "public.rtf", "public.html", "public.utf8-plain-text" }
check("it reports success", pt.stripClipboard() == true)
check("the text survived", CLIP == "styled text", CLIP)
check("…written back exactly once", SET_CALLS == 1, SET_CALLS)
check("it said how many flavours went away", ALERTS[1]
      and ALERTS[1]:find("2 flavours removed", 1, true) ~= nil, ALERTS[1])

reset()
CLIP, FLAVORS = "already plain", { "public.utf8-plain-text" }
pt.stripClipboard()
-- "Stripped" with nothing visibly changed is indistinguishable from
-- "did nothing", and this is a tool you use when you cannot see whether
-- it worked. Saying so is the proof.
check("an already-plain clipboard says so rather than claiming a strip",
      ALERTS[1] and ALERTS[1]:find("Already plain", 1, true) ~= nil, ALERTS[1])

reset()
CLIP = nil
check("an empty clipboard refuses", pt.stripClipboard() == false)
check("…and nothing was written", SET_CALLS == 0, SET_CALLS)
check("…with a reason on screen", ALERTS[1]
      and ALERTS[1]:find("no text", 1, true) ~= nil, ALERTS[1])

-- =====================================================================
out("\n=== 4. 🚨 SECURE INPUT IS CHECKED BEFORE A SINGLE CHARACTER ===\n")
-- =====================================================================
reset()
CLIP   = "lee@example.com"
SECURE = true
check("it refuses", pt.typeClipboard() == false)
check("NOTHING was typed", #TYPED == 0, #TYPED)
check("…not even a timer was armed to type later", #TIMERS == 0, #TIMERS)
check("…and it named secure input as the reason", ALERTS[1]
      and ALERTS[1]:find("Secure input", 1, true) ~= nil, ALERTS[1])
check("…and recorded it", pt.lastNote
      and pt.lastNote:find("secure input", 1, true) ~= nil, pt.lastNote)

reset()
CLIP = nil
check("an empty clipboard refuses too", pt.typeClipboard() == false)
check("…having typed nothing", #TYPED == 0)

reset()
CLIP = string.rep("x", pt.typeMax + 1)
check("more than typeMax refuses", pt.typeClipboard() == false)
check("…having typed nothing", #TYPED == 0)
check("…and said how much was too much", ALERTS[1]
      and ALERTS[1]:find(tostring(pt.typeMax), 1, true) ~= nil, ALERTS[1])

-- =====================================================================
out("\n=== 5. 🚨 THE MODIFIERS CLEAR FIRST — AND FIRE EXACTLY ONCE ===\n")
-- =====================================================================
-- ⇪; means ⌘⇧⌃⌥ were held moments ago. A keystroke posted while one is
-- still down is a MENU COMMAND in whatever app is in front, not a
-- character.
reset()
CLIP = "lee@example.com"
MODS = { cmd = true, shift = true }
check("it starts", pt.typeClipboard() == true)
check("nothing is typed on the keypress", #TYPED == 0, #TYPED)
runAfters(1)                 -- the typeDelay timer
check("…still nothing, because ⌘⇧ are down", #TYPED == 0, #TYPED)
check("a settle timer is ticking instead", #EVERY == 1, #EVERY)
EVERY[1].fn()                -- one tick, modifiers still held
check("…and it keeps waiting while they are held", #TYPED == 0, #TYPED)
MODS = {}
EVERY[1].fn()                -- the tick where they come up
check("the moment they clear, the text is typed", #TYPED > 0, #TYPED)
check("…and the settle timer stopped itself", EVERY[1].stopped == true)

-- 🚨 THE COUNT. Two timers both reaching the callback would type the
-- clipboard TWICE, into a text field, with no undo. Draining every
-- remaining timer the way a real second would is the only shape that
-- catches that: one copy of the text, not two.
drain()
check("🚨 what was typed reassembles to the clipboard EXACTLY ONCE",
      table.concat(TYPED) == "lee@example.com", table.concat(TYPED))
check("…and no timer is left running afterwards", (function()
    for _, t in ipairs(EVERY) do if not t.stopped then return false end end
    return #TIMERS == 0
end)(), #TIMERS)

-- A modifier that never comes up must not be typed through.
reset()
CLIP = "secret"
MODS = { cmd = true }
pt.typeClipboard()
drain()
check("a modifier that never clears means NOTHING is typed", #TYPED == 0, #TYPED)
check("…and it says why rather than going quiet", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("still held", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])

-- Long text is posted in bursts, and every character survives.
reset()
CLIP = string.rep("abcdefghij", 40)      -- 400 characters
MODS = {}
pt.typeClipboard()
drain()
check("400 characters go out in several bursts",
      #TYPED > 1, #TYPED)
check("…and not one character is lost or duplicated",
      table.concat(TYPED) == CLIP, #table.concat(TYPED))

-- =====================================================================
out("\n=== 6. 🚨 THE BORROWED CLIPBOARD GOES BACK ===\n")
-- =====================================================================
reset()
AX, AXSEL = true, "The quick brown fox. It jumped!"
check("with accessibility answering, it counts without touching ⌘C",
      pt.countSelection() == true)
check("…no ⌘C was sent", #KEYSTROKES == 0, #KEYSTROKES)
check("…the clipboard was never written", SET_CALLS == 0, SET_CALLS)
check("…and a timeout was set on the element FIRST", #AXTIMEOUTS >= 1, #AXTIMEOUTS)
check("…the numbers reached the screen", ALERTS[1]
      and ALERTS[1]:find("6 words", 1, true) ~= nil, ALERTS[1])

reset()
AX, AXSEL = true, nil        -- an app that answers accessibility with nothing
CLIP = "MY IMPORTANT CLIPBOARD"
pt.countSelection()
check("with no AX answer it falls back to ⌘C", #KEYSTROKES == 1, #KEYSTROKES)
check("…which is a real ⌘C", KEYSTROKES[1] == "cmd+c", KEYSTROKES[1])
check("…and the clipboard watcher was suppressed across the round trip",
      SUPPRESSED == 1, SUPPRESSED)
check("…the clipboard was cleared first, so a failed copy reads as empty",
      CLEARED == 1, CLEARED)
CLIP = "the selected words here"      -- the app answers the ⌘C
runAfters(1)                          -- copyWait
check("the copied text is counted", ALERTS[1]
      and ALERTS[1]:find("4 words", 1, true) ~= nil, ALERTS[1])
runAfters(1)                          -- restoreAfter
check("🚨 the original clipboard is PUT BACK",
      CLIP == "MY IMPORTANT CLIPBOARD", CLIP)

-- …and on the path where the copy came back with nothing.
reset()
AX, AXSEL = true, nil
CLIP = "KEEP ME"
pt.countSelection()
CLIP = nil                            -- nothing was selected, ⌘C did nothing
runAfters(1)
check("an empty copy says nothing was selected", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Nothing selected", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])
runAfters(1)
check("🚨 …and the clipboard is STILL put back", CLIP == "KEEP ME", CLIP)

-- =====================================================================
out("\n=== 7. ℹ️ mdls parsing: a value can span lines ===\n")
-- =====================================================================
-- An array attribute prints one element per line. A line without a
-- leading key CONTINUES the previous attribute; parse it any other way
-- and every array attribute becomes a row of junk with no name on it.
local MDLS = [[
kMDItemContentType             = "public.jpeg"
kMDItemPixelHeight             = 1080
kMDItemKeywords                = (
    "holiday",
    "beach"
)
kMDItemFSName                  = "photo.jpg"
]]
local rows = pt.parseMdls(MDLS)
local by = {}
for _, r in ipairs(rows) do by[r.key] = r.value end
check("every attribute became one row", #rows == 4, #rows)
check("a simple value is read", by["kMDItemContentType"] == '"public.jpeg"',
      by["kMDItemContentType"])
check("a numeric value is read", by["kMDItemPixelHeight"] == "1080")
check("🚨 an array value keeps ALL its elements on ONE row",
      by["kMDItemKeywords"] and by["kMDItemKeywords"]:find("holiday", 1, true)
      and by["kMDItemKeywords"]:find("beach", 1, true), by["kMDItemKeywords"])
check("…and the attribute AFTER it is not swallowed",
      by["kMDItemFSName"] == '"photo.jpg"', by["kMDItemFSName"])

local sr = pt.statRows("/tmp/photo.jpg")
local sBy = {}
for _, r in ipairs(sr) do sBy[r.key] = r.value end
check("the filesystem rows come from hs.fs, not mdls", #sr >= 8, #sr)
check("…the size is in bytes and MB", sBy["Size"]
      and sBy["Size"]:find("2048 bytes", 1, true) ~= nil, sBy["Size"])
-- 🚨 hs.fs reports permissions as the rwx STRING. Formatting it with %o
-- gave "0" for every file — wrong in a way that looks like an answer.
check("🚨 permissions are the rwx string, not a bogus 0",
      sBy["Permissions"] == "rw-r--r--", sBy["Permissions"])

-- =====================================================================
out("\n=== 8. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
reset()
pt.showMetadata("/tmp/photo.jpg", rows)
local mc = CHOOSERS[#CHOOSERS]
check("the metadata panel opened", mc ~= nil and #mc.choices_ == 4,
      mc and #mc.choices_)
check("every row value is a string, number or boolean", (function()
    for _, c in ipairs(mc.choices_) do
        for k, v in pairs(c) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false, k .. " is a " .. t
            end
        end
    end
    return true
end)())
check("…and the payload resolves to a real attribute", (function()
    for _, c in ipairs(mc.choices_) do
        if pt.metaRows[c.idx] == nil then return false end
    end
    return true
end)())
check("⏎ on a row copies the VALUE, not the key", (function()
    CLIP, SET_CALLS = nil, 0
    mc.cb({ idx = 1 })
    return CLIP == pt.metaRows[1].value and SET_CALLS == 1
end)(), CLIP)

pt.show()
local pc = CHOOSERS[#CHOOSERS]
check("the palette lists all eighteen tools", #pc.choices_ == 18, #pc.choices_)
check("every palette row value is a scalar too", (function()
    for _, c in ipairs(pc.choices_) do
        for _, v in pairs(c) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false
            end
        end
    end
    return true
end)())
check("…and its payload is the tool id, which resolves", (function()
    for _, c in ipairs(pc.choices_) do
        if pt.byId(c.id) == nil then return false end
    end
    return true
end)())

-- =====================================================================
out("\n=== 9. a tool that throws costs one tool, not the palette ===\n")
-- =====================================================================
reset()
local saved = pt.tools[1].run
pt.tools[1].run = function() error("boom") end
check("running it returns false rather than propagating", pt.run("plain") == false)
check("…it says which tool failed", ALERTS[1]
      and ALERTS[1]:find("Strip clipboard formatting", 1, true) ~= nil, ALERTS[1])
check("…and records the throw", pt.lastNote
      and pt.lastNote:find("threw", 1, true) ~= nil, pt.lastNote)
pt.tools[1].run = saved
check("an unknown id refuses without throwing", pt.run("nope") == false)

-- =====================================================================
out("\n=== 11. ⏸ pause: the media key, and only apps ALREADY running ===\n")
-- =====================================================================
-- 🚨 NAMING AN APP IN APPLESCRIPT LAUNCHES IT. A "pause everything" key
-- that opens Music because Music was closed is worse than no key, so the
-- script checks System Events' process list before it tells anybody
-- anything — and that check lives in the script text, which is what is
-- asserted here because the script is what ships.
reset()
TASKS = {}
check("it reports success", pt.pauseAll() == true)
check("🎹 the media key was posted", #SYSKEYS == 2, #SYSKEYS)
check("…as a down and then an up, which is what a real ⏯ press is",
      SYSKEYS[1] and SYSKEYS[1].key == "PLAY" and SYSKEYS[1].down == true
      and SYSKEYS[2] and SYSKEYS[2].down == false,
      SYSKEYS[1] and SYSKEYS[1].key)
local pauseTask = TASKS[#TASKS]
check("an osascript child process was started", pauseTask ~= nil
      and pauseTask.bin == "/usr/bin/osascript" and pauseTask.started == true,
      pauseTask and pauseTask.bin)
check("🚨 the script consults the running process list FIRST",
      pauseTask and pauseTask.args[2]:find("name of every process", 1, true) ~= nil)
check("🚨 …and only tells an app that is IN that list",
      pauseTask and pauseTask.args[2]:find("runningNames contains", 1, true) ~= nil)
-- ⚠️ THE ARGUMENT LIST IS pt.players MINUS THE TOGGLE-ONLY NAMES (6.126.0).
-- VLC understands neither verb this script sends, so passing it costs two
-- Apple Events that can only fail. It is told by pt.pauseToggleOnly, which
-- knows its vocabulary — see section 14.
local function expectedArgv()
    local want, skip = {}, {}
    for _, n in ipairs(pt.toggleOnly or {}) do
        if (pt.toggleScripts or {})[n] then skip[n] = true end
    end
    for _, n in ipairs(pt.players) do
        if not skip[n] then want[#want + 1] = n end
    end
    return want
end
check("every player is passed as an argument, not baked into the script",
      pauseTask and #pauseTask.args == 2 + #expectedArgv(),
      pauseTask and #pauseTask.args)
check("…and they are pt.players in order, minus the toggle-only ones",
      (function()
    if not pauseTask then return false end
    for i, n in ipairs(expectedArgv()) do
        if pauseTask.args[2 + i] ~= n then
            return false, "arg " .. i .. " = "
                   .. tostring(pauseTask.args[2 + i]) .. ", wanted " .. n
        end
    end
    return true
end)())
check("🚨 …and VLC is NOT among them — this script cannot say anything it"
      .. " understands", (function()
    if not pauseTask then return false end
    for i = 3, #pauseTask.args do
        if pauseTask.args[i] == "VLC" then return false, "passed at " .. i end
    end
    return true
end)())
check("it counts what it told you", (function()
    pauseTask.cb(0, "3\n", "")
    return pt.lastPaused == 3
end)(), pt.lastPaused)
check("…and says so, media key and players separately", ALERTS[#ALERTS]
      and ALERTS[#ALERTS]:find("3 players", 1, true) ~= nil, ALERTS[#ALERTS])

reset()
TASKS = {}
pt.pauseAll()
TASKS[#TASKS].cb(0, "0\n", "")
check("with no scriptable player running it says the media key went alone",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("no scriptable player", 1, true) ~= nil,
      ALERTS[#ALERTS])

-- =====================================================================
out("\n=== 14. ⏸ VLC, which speaks a different language ===\n")
-- =====================================================================
-- LL: "⇪' does not pause VLC."
--
-- 🚨 VLC HAS NO `pause` AND NO `playpause`. The generic script said both,
-- VLC understood neither, the inner try swallowed the second error, and
-- the film played on — with the count in the alert one short every time.
-- Its toggle is spelled `play`, and `play` SENT TO A PAUSED VLC STARTS
-- IT. Every check here exists so that a pause key never starts anything.
check("pt.toggleOnly names VLC", (function()
    for _, n in ipairs(pt.toggleOnly or {}) do
        if n == "VLC" then return true end
    end
    return false
end)())
check("🚨 every held-back name has a script of its own — a name in"
      .. " pt.toggleOnly with nothing to say it would be told NOTHING",
      (function()
    for _, n in ipairs(pt.toggleOnly or {}) do
        if not (pt.toggleScripts or {})[n] then return false, n end
    end
    return true
end)())
check("…and VLC stays in pt.players, which is where the report reads from",
      (function()
    for _, n in ipairs(pt.players) do if n == "VLC" then return true end end
    return false
end)())

local S = pt.vlcPauseScript or ""
check("🚨 the script asks System Events whether VLC is running",
      S:find('exists process "VLC"', 1, true) ~= nil)
check("🚨 …BEFORE the tell that would relaunch a departed VLC", (function()
    local guard = S:find("exists process", 1, true)
    local tell  = S:find('tell application "VLC"', 1, true)
    if not (guard and tell) then return false, "guard or tell missing" end
    return guard < tell, guard .. " vs " .. tell
end)())
check("🚨 it reads `playing` before it sends a verb", (function()
    local ask = S:find("if playing", 1, true)
    local act = S:find("\n%s*play%s*\n")
    if not (ask and act) then return false, "ask or verb missing" end
    return ask < act, ask .. " vs " .. act
end)())
check("🚨 the only verb it sends is `play` — never pause, never playpause",
      (function()
    for line in S:gmatch("[^\n]+") do
        local w = line:match("^%s*(%a+)%s*$")
        if w == "pause" or w == "playpause" then return false, w end
    end
    return S:find("\n%s*play%s*\n") ~= nil
end)())
check("…and it answers in the three words pt.pauseToggleOnly knows",
      S:find('"absent"', 1, true) ~= nil and S:find('"paused"', 1, true) ~= nil
      and S:find('"already"', 1, true) ~= nil)
-- 🚨 THE REASON THIS IS A SEPARATE SCRIPT IS NOT TIDINESS. `playing` and
-- `play` are VLC's OWN terminology, which AppleScript can only resolve
-- when the app is named as a LITERAL — and a literal name compiles
-- against a dictionary that a Mac without VLC does not have. In the
-- shared script it would take the whole pause key down; on its own it can
-- only ever take itself down.
check("🚨 no literal \"VLC\" in the script every player depends on — a Mac"
      .. " with no VLC installed must still be able to compile it",
      (pt.pauseScript or ""):find('"VLC"', 1, true) == nil)
check("…so they are two different scripts", pt.vlcPauseScript ~= pt.pauseScript)

reset()
TASKS   = {}
RUNNING = {}
local vlcSaid, vlcCalls = "unset", 0
pt.pauseToggleOnly(function(x) vlcCalls = vlcCalls + 1 ; vlcSaid = x end)
check("🚨 with VLC not running NOTHING is launched — asking AppleScript"
      .. " would have opened it", #TASKS == 0, #TASKS)
check("…and the caller is told once that there is nothing to say",
      vlcCalls == 1 and vlcSaid == nil, tostring(vlcSaid))
check("🚨 and hs.application.get was never asked — by name it costs"
      .. " ~3,000ms per missing player on macOS 27 (the 6.137.0 freeze)",
      GETCALLS == 0, GETCALLS)

RUNNING = { VLC = true }
TASKS   = {}
vlcSaid, vlcCalls = "unset", 0
pt.pauseToggleOnly(function(x) vlcCalls = vlcCalls + 1 ; vlcSaid = x end)
local vt = TASKS[#TASKS]
check("with VLC running an osascript child process is started",
      vt ~= nil and vt.bin == "/usr/bin/osascript" and vt.started == true,
      vt and vt.bin)
check("…carrying VLC's own script, not the generic one",
      vt ~= nil and vt.args[2] == pt.vlcPauseScript)
check("…and the caller has not been answered yet", vlcCalls == 0, vlcCalls)

-- One keypress, one answer: run the script and hand back what it said.
local function vlcSays(reply)
    TASKS = {}
    local got, n = "unset", 0
    pt.pauseToggleOnly(function(x) n = n + 1 ; got = x end)
    local t = TASKS[#TASKS]
    if not t then return "NO TASK", n end
    t.cb(0, reply, "")
    return got, n
end

local r, n = vlcSays("paused\n")
check("`paused` becomes a phrase for the alert", r == "VLC paused", tostring(r))
check("…and done() is called exactly once per keypress", n == 1, n)
r = vlcSays("already\n")
check("🚨 `already` says so rather than claiming a pause that never"
      .. " happened", r == "VLC was already paused", tostring(r))
r = vlcSays("absent\n")
check("`absent` — VLC quit in the gap between the two checks — says"
      .. " nothing at all", r == nil, tostring(r))
r = vlcSays("")
check("an empty answer is reported, not counted as a pause",
      r == "VLC did not answer", tostring(r))

-- ---- both halves, one pill -------------------------------------------
reset()
TASKS = {}
pt.pauseAll()
local generic = TASKS[#TASKS]
generic.cb(0, "1\n", "")
check("🚨 the alert WAITS for VLC — one keypress must not show two pills",
      #ALERTS == 0, #ALERTS)
local vt2 = TASKS[#TASKS]
check("…VLC's task is started by the generic script's answer",
      vt2 ~= nil and vt2 ~= generic and vt2.args[2] == pt.vlcPauseScript)
vt2.cb(0, "paused\n", "")
check("…and then exactly one alert appears", #ALERTS == 1, #ALERTS)
check("…carrying the count and VLC together", ALERTS[1]
      and ALERTS[1]:find("1 player", 1, true) ~= nil
      and ALERTS[1]:find("VLC paused", 1, true) ~= nil, ALERTS[1])

reset()
TASKS = {}
pt.pauseAll()
TASKS[#TASKS].cb(0, "0\n", "")
TASKS[#TASKS].cb(0, "paused\n", "")
check("🚨 with VLC the only player, it does not report that nothing was"
      .. " running", ALERTS[#ALERTS]
      and ALERTS[#ALERTS]:find("no scriptable player", 1, true) == nil
      and ALERTS[#ALERTS]:find("VLC paused", 1, true) ~= nil, ALERTS[#ALERTS])
RUNNING = {}

-- =====================================================================
out("\n=== 12. 👻 Ghostty: a window title is only a path when it IS one ===\n")
-- =====================================================================
-- 🚨 REVEALING THE WRONG FOLDER IS WORSE THAN SAYING THE TITLE WAS NOT A
-- PATH. Ghostty writes titles like "~/code/thing — zsh" at a prompt and
-- "vim README.md" the moment you run something, and only the first kind
-- can be trusted.
check("an absolute path is a path", pt.pathFromTitle("/Users/test/code") == "/Users/test/code",
      pt.pathFromTitle("/Users/test/code"))
check("a ~ path is expanded against the home directory",
      pt.pathFromTitle("~/code") == "/Users/test/code",
      pt.pathFromTitle("~/code"))
check("🚨 the shell name after an em dash is trimmed off",
      pt.pathFromTitle("~/code — zsh") == "/Users/test/code",
      pt.pathFromTitle("~/code — zsh"))
check("…and after a plain hyphen too",
      pt.pathFromTitle("/Users/test/code - bash") == "/Users/test/code",
      pt.pathFromTitle("/Users/test/code - bash"))
check("🚨 a command line is NOT a path", pt.pathFromTitle("vim README.md") == nil,
      pt.pathFromTitle("vim README.md"))
check("🚨 an ssh session is NOT a path",
      pt.pathFromTitle("ssh build@10.0.0.4") == nil,
      pt.pathFromTitle("ssh build@10.0.0.4"))
check("🚨 a path that does not exist is NOT a path — Finder would open nothing",
      pt.pathFromTitle("/Users/test/gone") == nil,
      pt.pathFromTitle("/Users/test/gone"))
check("an empty title is nil", pt.pathFromTitle("") == nil)
check("a nil title is nil, not a throw", pt.pathFromTitle(nil) == nil)

reset()
TASKS = {}
FRONT_APP = "Ghostty"
FRONT_TITLE = "~/code — zsh"
check("with a usable title, reveal goes straight to Finder",
      pt.revealGhostty() == true)
check("…opening the resolved directory", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/open" and t.args[1] == "/Users/test/code" then
            return true
        end
    end
    return false
end)())
check("…without shelling out to lsof at all", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/bin/sh" then return false end
    end
    return true
end)())

reset()
TASKS = {}
FRONT_TITLE = "vim README.md"
pt.revealGhostty()
check("with an unusable title it falls back to asking the shell", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/bin/sh" then return true end
    end
    return false
end)())
check("…using lsof on Ghostty's own children", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/bin/sh" then
            return t.args[2]:find("lsof", 1, true) ~= nil
               and t.args[2]:find("Ghostty", 1, true) ~= nil
        end
    end
    return false
end)())
check("…and when no shell answers, it says so rather than opening nothing",
      (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/bin/sh" then t.cb(0, "", "") end
    end
    for _, a in ipairs(ALERTS) do
        if a:find("Could not tell where", 1, true) then return true end
    end
    return false
end)(), ALERTS[#ALERTS])

reset()
TASKS = {}
FRONT_APP = "Finder"
check("Ghostty here asks FINDER where it is, not Ghostty",
      pt.ghosttyHere() == true and TASKS[1]
      and TASKS[1].bin == "/usr/bin/osascript"
      and TASKS[1].args[2]:find("Finder", 1, true) ~= nil)
TASKS[1].cb(0, "/Users/test/code\n", "")
check("…then launches Ghostty with --working-directory", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/open" then
            for _, a in ipairs(t.args) do
                if a == "--working-directory=/Users/test/code" then return true end
            end
        end
    end
    return false
end)())
check("…with -n, so a second window opens instead of raising the first",
      (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/open" then
            for _, a in ipairs(t.args) do
                if a == "-na" then return true end
            end
        end
    end
    return false
end)())

-- =====================================================================
out("\n=== 13. 🔳 QR: no decoder is a NAMED refusal ===\n")
-- =====================================================================
-- 🚨 macOS ships no QR decoder Hammerspoon can reach, so this needs
-- zbarimg. Failing as though the code were unreadable would send you
-- looking at the screen instead of at Homebrew.
reset()
TASKS = {}
SERVICE_HAS = false
check("with the screenshots module absent it refuses", pt.readQR() == false)
check("…nothing was captured", #TASKS == 0, #TASKS)
check("…and it names the reason", ALERTS[1]
      and ALERTS[1]:find("screenshots module", 1, true) ~= nil, ALERTS[1])

reset()
TASKS = {}
SERVICE_HAS, ZBAR = true, nil
check("with no zbarimg installed it refuses", pt.readQR() == false)
check("…and says to install it", ALERTS[1]
      and ALERTS[1]:find("brew install zbar", 1, true) ~= nil, ALERTS[1])

-- 📍 The path is ASKED FOR by service name, never copied. A second copy
-- of screenshots.lua's five candidate locations is a list that drifts.
reset()
TASKS = {}
SERVICE_HAS, ZBAR = true, "/opt/homebrew/bin/zbarimg"
check("with a decoder it captures the screen", pt.readQR() == true)
local cap = TASKS[1]
check("…via screencapture", cap and cap.bin == "/usr/sbin/screencapture",
      cap and cap.bin)
check("…silently, so the shutter does not fire", cap and (function()
    for _, a in ipairs(cap.args) do if a == "-x" then return true end end
    return false
end)())
cap.cb(0, "", "")
local dec = TASKS[2]
check("…then runs the decoder the service named",
      dec and dec.bin == "/opt/homebrew/bin/zbarimg", dec and dec.bin)
check("a decoded payload lands on the clipboard", (function()
    dec.cb(0, "QR-Code:https://example.com/x\n", "")
    return CLIP == "https://example.com/x"
end)(), CLIP)
check("…and is shown, so you can see WHAT was copied", ALERTS[#ALERTS]
      and ALERTS[#ALERTS]:find("example.com", 1, true) ~= nil, ALERTS[#ALERTS])

reset()
TASKS = {}
pt.readQR()
TASKS[1].cb(0, "", "")
TASKS[2].cb(4, "", "")
check("no code on screen says exactly that", ALERTS[#ALERTS]
      and ALERTS[#ALERTS]:find("No QR code", 1, true) ~= nil, ALERTS[#ALERTS])

reset()
TASKS = {}
pt.readQR()
TASKS[1].cb(1, "", "")     -- screencapture refused
check("a failed capture is reported, not decoded", (function()
    return #TASKS == 1
end)(), #TASKS)

-- =====================================================================
out("\n=== 15. 📋 the counts on the clipboard (6.132.0) ===\n")
-- =====================================================================
-- LL: "Allow both counts to be posted to the clipboard." It is a SECOND
-- row rather than a change to the first, and §15 is mostly about proving
-- the first row still does not touch your clipboard.
reset()
AXSEL = "one two three four five"
CLIP  = "something I was keeping"
pt.run("count")
check("🚨 the plain count row does NOT touch the clipboard",
      CLIP == "something I was keeping", CLIP)
check("…and it did show the numbers", (ALERTS[1] or ""):find("5 words") ~= nil,
      ALERTS[1])

reset()
AXSEL = "one two three four five"
CLIP  = "something I was keeping"
pt.run("countclip")
check("the → clipboard row copies", CLIP ~= "something I was keeping", CLIP)
check("…both counts, in one line", CLIP == "5 words · 23 characters", CLIP)
check("…and says on screen that it copied",
      (ALERTS[1] or ""):find("copied") ~= nil, ALERTS[1])
check("…and the numbers are still shown too",
      (ALERTS[1] or ""):find("5 words") ~= nil, ALERTS[1])
check("the report shows what was copied last",
      _G.powerReport():find("5 words · 23 characters", 1, true) ~= nil)

-- 🚨 A CLIPBOARD THAT REFUSES MUST NOT BE REPORTED AS A SUCCESS. The
-- whole value of this row is that you can paste the numbers afterwards.
do
    reset()
    AXSEL = "one two"
    local realSet = hs.pasteboard.setContents
    hs.pasteboard.setContents = function() error("pasteboard is busy", 0) end
    pt.run("countclip")
    hs.pasteboard.setContents = realSet
    check("🚨 a refused clipboard says so rather than claiming success",
          (ALERTS[1] or ""):find("refused") ~= nil, ALERTS[1])
    check("…and the counts are still on screen",
          (ALERTS[1] or ""):find("2 words") ~= nil, ALERTS[1])
end

-- =====================================================================
out("\n=== 16. 🔠 change the case of the selection (6.132.0) ===\n")
-- =====================================================================
-- The rules come from the real modules/text_case.lua — see the service
-- stub at the top. These checks are about the three things THIS file
-- owns: reading the selection first, previewing against it, and typing
-- the answer back under the same guards typeClipboard needs.
local function lastChooser() return CHOOSERS[#CHOOSERS] end

reset()
AXSEL = "Some Words Here"
local before = #CHOOSERS
check("the case row opens a picker", pt.run("case") and #CHOOSERS > before)
do
    local c = lastChooser()
    check("…with all six cases in it", #c.choices_ == 6, #c.choices_)
    -- 🚨 THE PREVIEW IS OF YOUR TEXT. A sample cannot warn you that three
    -- of the six are about to throw your punctuation away.
    local subs = {}
    for _, ch in ipairs(c.choices_) do subs[ch.id] = ch.subText end
    check("🚨 the UPPERCASE row previews YOUR text, not a sample",
          subs.upper == "SOME WORDS HERE", subs.upper)
    check("🚨 …and so does the snake row", subs.snake == "some_words_here",
          subs.snake)
    check("…and the kebab row", subs.kebab == "some-words-here", subs.kebab)
    check("the placeholder says how much is selected",
          c.placeholder:find("15 characters") ~= nil, c.placeholder)
end

-- ⏎ on a row types the result back over the still-live selection.
do
    local c = lastChooser()
    c.cb({ id = "snake", ok = true })
    runAfters()
    drain(40)
    check("⏎ types the transformed text back",
          table.concat(TYPED) == "some_words_here", table.concat(TYPED))
end

-- 🚨 EVERY GUARD typeClipboard HAS, because this types too.
do
    reset() ; AXSEL = "Some Words Here"
    pt.run("case")
    SECURE = true
    lastChooser().cb({ id = "upper", ok = true })
    runAfters() ; drain(40)
    check("🚨 secure input stops the case being typed", #TYPED == 0,
          table.concat(TYPED))
    check("…and says why", (ALERTS[#ALERTS] or ""):find("Secure input") ~= nil,
          ALERTS[#ALERTS])
    SECURE = false
end
do
    reset() ; AXSEL = "Some Words Here"
    pt.run("case")
    MODS = { cmd = true }          -- never comes up
    lastChooser().cb({ id = "upper", ok = true })
    runAfters() ; drain(80)
    check("🚨 a held modifier stops it too — a keystroke under ⌘ is a menu "
          .. "command in somebody else's app", #TYPED == 0, table.concat(TYPED))
    MODS = {}
end
do
    reset() ; AXSEL = string.rep("word ", 2000)
    pt.run("case")
    lastChooser().cb({ id = "upper", ok = true })
    runAfters() ; drain(40)
    check("🚨 too much text to type is refused rather than half-typed",
          #TYPED == 0, #TYPED)
    check("…and the cap is named", (ALERTS[#ALERTS] or ""):find("cap is") ~= nil,
          ALERTS[#ALERTS])
end

-- 🚨 AN UNCHANGED RESULT IS NOT TYPED. Retyping an identical paragraph
-- is invisible until you reach for undo and find a step that did nothing.
do
    reset() ; AXSEL = "already lower"
    pt.run("case")
    lastChooser().cb({ id = "lower", ok = true })
    runAfters() ; drain(40)
    check("🚨 nothing is typed when the case would change nothing",
          #TYPED == 0, table.concat(TYPED))
    check("…and it says so", (ALERTS[#ALERTS] or ""):find("Already") ~= nil,
          ALERTS[#ALERTS])
end

-- The selection is read the same two ways the counter reads it.
do
    reset() ; AXSEL = nil ; CLIP = nil
    pt.run("case")
    CLIP = "From The Clipboard"
    runAfters()
    check("an app with no accessibility falls back to ⌘C",
          (lastChooser().choices_[6] or {}).subText == "from_the_clipboard",
          (lastChooser().choices_[6] or {}).subText)
    drain(40)
end
do
    reset() ; AXSEL = nil ; CLIP = nil
    local n = #CHOOSERS
    pt.run("case")
    runAfters() ; drain(40)
    check("no selection at all opens no picker", #CHOOSERS == n, #CHOOSERS - n)
    check("…and says which two routes were tried",
          (ALERTS[#ALERTS] or ""):find("accessibility") ~= nil, ALERTS[#ALERTS])
end

-- 🚨 NO ENGINE, NO PICKER. A row that opens an empty chooser is worse
-- than a row that explains itself.
do
    reset() ; AXSEL = "Some Words"
    CASE_OFF = true
    local n = #CHOOSERS
    local ran = pt.run("case")
    check("🚨 the case row refuses when text_case is not loaded", ran == false)
    check("…without opening a picker", #CHOOSERS == n)
    check("…and names the module", (ALERTS[#ALERTS] or ""):find("Text Case") ~= nil,
          ALERTS[#ALERTS])
    check("…and the report says the engine is missing",
          _G.powerReport():find("MISSING") ~= nil)
    CASE_OFF = false
    check("…and the report finds it again once it is back",
          _G.powerReport():find("6 cases") ~= nil)
end

-- =====================================================================
out("\n=== 10. the report tells the truth ===\n")
-- =====================================================================
SECURE = true
local rep = _G.powerReport()
check("the report names the module", rep:find("POWER TOOLS", 1, true) ~= nil)
check("…and warns when secure input would block typing",
      rep:find("blocked", 1, true) ~= nil, rep)
SECURE = false
AX = false
rep = _G.powerReport()
check("…and says when counting has to fall back to ⌘C",
      rep:find("⌘C", 1, true) ~= nil, rep)
AX = true

-- =====================================================================
out("\n=== 11. 🆓 the free-key ledger (6.142.0) ===\n")
-- =====================================================================
-- LL: "These shortcuts were supposed to be cleaned, cleared and the
-- keys listed as future possible options for keyboard shortcuts." The
-- ledger is READ from _G.hyperBound rather than written by hand,
-- because a hand-written survey is exactly what missed ⇪⇧9 in 6.141.0
-- (the laptop row built its claims in a loop; no literal "⇪⇧9" existed
-- to grep). These checks feed it a small fake registry and expect the
-- report to repeat only what the registry says.
do
    local savedBound = _G.hyperBound
    _G.hyperBound = {
        ["9"]       = "grayscale relay",   -- claimed → not free
        ["1"]       = "chord",             -- forwarded raw → FREE
        ["shift+9"] = "invert colours",    -- claimed → not free
        ["pad1"]    = "numpad pad1",       -- claimed → not free
    }
    CLIP, SET_CALLS = nil, 0
    ALERTS = {}
    local rep = _G.freeKeys()
    check("the report exists and says it reads the LIVE registry",
          type(rep) == "string" and rep:find("LIVE", 1, true) ~= nil)
    local plainLine = rep:match("⇪    ([^\n]*)") or ""
    check("a chord-forwarded key is listed free — claiming ⇪1 costs only "
          .. "the raw-chord forward",
          plainLine:find("%f[%w]1%f[%W]") ~= nil, plainLine)
    check("a claimed key is NOT listed — ⇪9 is the grayscale relay",
          plainLine:find("%f[%w]9%f[%W]") == nil, plainLine)
    local shiftLine = rep:match("⇪⇧   ([^\n]*)") or ""
    check("a claimed shifted key is NOT listed — ⇪⇧9 is invert",
          shiftLine:find("%f[%w]9%f[%W]") == nil, shiftLine)
    check("a freed shifted digit IS listed — ⇪⇧7 came back in 6.142.0",
          shiftLine:find("%f[%w]7%f[%W]") ~= nil, shiftLine)
    check("🔒 ⇪⇧Z is never listed — reserved is not free, and the report "
          .. "says which and quotes why",
          shiftLine:find("%f[%w]z%f[%W]") == nil
          and rep:find("reserved", 1, true) ~= nil
          and rep:find("We will use that later", 1, true) ~= nil, shiftLine)
    check("a claimed pad key is NOT listed — ⇪pad1 is the capture row",
          (rep:match("⇪ pad   ([^\n]*)") or "x"):find("pad1%f[%W]") == nil,
          rep:match("⇪ pad   ([^\n]*)"))
    check("the list lands on the clipboard, whole",
          SET_CALLS >= 1 and CLIP == rep)
    check("…and says so on screen", ALERTS[#ALERTS] ~= nil
          and ALERTS[#ALERTS]:find("Free keys", 1, true) ~= nil,
          ALERTS[#ALERTS])
    check("the ⇪; row runs the same report and counts as a run",
          pt.run("freekeys") == true and (pt.ran.freekeys or 0) >= 1)
    _G.hyperBound = savedBound
end

-- =====================================================================
out(("\n── test_power_tools: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
