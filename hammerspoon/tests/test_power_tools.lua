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
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.pasteboardSuppress = function() SUPPRESSED = SUPPRESSED + 1 end
-- The service registry, as power_tools sees it: it asks screenshots.lua
-- where zbarimg is rather than keeping a second copy of the search list.
_G.service = {
    has  = function(n) return SERVICE_HAS and n == "shots.zbarPath" end,
    call = function(n) if n == "shots.zbarPath" then return ZBAR end end,
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
check("all eight tools are in the list", #pt.tools == 8, #pt.tools)
check("…and each has a stable id", (function()
    local want = { plain = true, type = true, count = true, meta = true,
                   pause = true, ghere = true, greveal = true, qr = true }
    for _, t in ipairs(pt.tools) do
        if not want[t.id] then return false end
        want[t.id] = nil
    end
    return next(want) == nil
end)())
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
check("the palette lists all eight tools", #pc.choices_ == 8, #pc.choices_)
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
check("every player is passed as an argument, not baked into the script",
      pauseTask and #pauseTask.args == 2 + #pt.players,
      pauseTask and #pauseTask.args)
check("…and they are the ones in pt.players", (function()
    if not pauseTask then return false end
    for i, n in ipairs(pt.players) do
        if pauseTask.args[2 + i] ~= n then return false end
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
out(("\n── test_power_tools: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
