-- =====================================================================
-- test_note_pad.lua — the Quick Append Pad: one box, four destinations
-- =====================================================================
--     lua5.4 test_note_pad.lua [/path/to/hammerspoon]
--
-- The claims under test: every LINE routes by its prefix (* Idea,
-- + Log, ! task, ? note — the last two into the Capture Pad queue
-- verbatim), unprefixed lines are Logs and continuation lines stay
-- with their entry; CLOSING FILES EVERYTHING and failures stay in the
-- draft because they exist nowhere else; the 16:01 review reads
-- today's CSV records (including quoted multi-line ones) and one click
-- queues an entry as a forced task; a Mac without a webview routes
-- through the plain prompt; and a profile without the Capture Pad
-- demotes a ! line to a Log LOUDLY instead of dropping it.

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

-- ---- a controllable world --------------------------------------------
local ALERTS, PROVIDED, WEBVIEWS, PROMPTS, TIMERS = {}, {}, {}, {}, {}
local CLIPBOARD = ""
local PROMPT_ANSWER = { "Cancel", "" }
local UC_CALLBACK = nil

local function newWebviewStub(rect)
    local v = { rect = rect, _style = 0, deleted = false, shown = false,
                htmlSet = nil }
    function v:windowTitle(t) self.title = t return self end
    function v:allowTextEntry() return self end
    function v:closeOnEscape() return self end
    function v:level() return self end
    function v:behaviorAsLabels() return self end
    function v:windowStyle(x)
        if x ~= nil then self._style = x end
        return self._style
    end
    function v:html(h) self.htmlSet = h return self end
    function v:show() self.shown = true return self end
    function v:bringToFront() return self end
    function v:delete() self.deleted = true return self end
    function v:frame(f) if f then self.rect = f end return self.rect end
    return v
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
    pasteboard = {
        getContents = function() return CLIPBOARD end,
        setContents = function(s) CLIPBOARD = tostring(s) return true end,
    },
    dialog = { textPrompt = function(title, msg, dflt, ok, cancel)
        PROMPTS[#PROMPTS + 1] = { title = title, msg = msg, dflt = dflt }
        return PROMPT_ANSWER[1], PROMPT_ANSWER[2]
    end },
    timer = {
        doEvery = function(_, fn)
            local t = { fn = fn }
            function t:stop() self.stopped = true end
            return t
        end,
        doAt = function(at, rep, fn)
            local t = { at = at, repeats = rep, fn = fn, kind = "at" }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    eventtap = { checkMouseButtons = function() return {} end },
}

_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local APPENDED, QUEUED = {}, {}
local APPEND_RESULT = { true, "📝 Logs ← 1 line: hello" }
local QUEUE_RESULT  = { true, "Call Dana" }
local REGISTRY = {
    ["notes.append"] = function(text, targetName)
        APPENDED[#APPENDED + 1] = { text = text, target = targetName }
        return APPEND_RESULT[1], APPEND_RESULT[2]
    end,
    ["capturePad.add"] = function(text)
        QUEUED[#QUEUED + 1] = text
        return QUEUE_RESULT[1], QUEUE_RESULT[2]
    end,
}
_G.service = {
    registry = REGISTRY,
    has  = function(n) return REGISTRY[n] ~= nil end,
    call = function(n, ...)
        local fn = REGISTRY[n]
        if not fn then return nil end
        return fn(...)
    end,
}

-- The pad reads the CSV through quickAppend.csvPath for the review.
local CSV_PATH = os.tmpname()
_G.quickAppend = {
    defaultTarget = 1,
    targets = {
        { name = "Logs",  file = "log.txt" },
        { name = "Ideas", file = "ideas.txt" },
    },
    csvPath = function() return CSV_PATH end,
}

local CLAIMED_ESC = {}
_G.claimEscape = function(name, _, present, close)
    CLAIMED_ESC[name] = { present = present, close = close }
end
_G.movablePanels = {}

-- 💻 6.114.0 — the pad claims ⇪2, its first key of its own. Recorded here
-- rather than swallowed, so the assertion below is about a real claim.
local HYPER = {}
local CORE = {
    provide = function(n, f) PROVIDED[n] = f end,
    hyperAddShortcut = function(mods, key, fn, src)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. tostring(key)] = { fn = fn, src = src }
    end,
}

local mod = dofile(HS .. "/modules/note_pad.lua")
mod.setup(CORE)
local np = _G.notePad

-- =======================================================================
out("1) the doors in — services, escape claim, drag entry, daily timer\n")
-- =======================================================================
check("notes.openPad is published (⇪pad2)",   PROVIDED["notes.openPad"] ~= nil)
check("notes.typeIdeas is published (⇪pad*)", PROVIDED["notes.typeIdeas"] ~= nil)
check("notes.typeLog is published (⇪pad-)",   PROVIDED["notes.typeLog"] ~= nil)
check("notes.editClipboard stays published for choosers and the Console",
      PROVIDED["notes.editClipboard"] ~= nil)
check("notes.review is published",            PROVIDED["notes.review"] ~= nil)
-- 💻 6.114.0 — THE PAD'S FIRST KEY OF ITS OWN. Until now it had none:
-- ⇪pad2, ⇪pad* and ⇪pad- are all bound by numpad_layer, so on a MacBook
-- with no external keyboard the most-used capture window in the config
-- could not be opened at all. 2 is the same digit as ⇪pad2, which is the
-- entire mnemonic and the reason it is not an arbitrary free key.
check("💻 the pad claims ⇪2 — the one door that works with no number pad",
      HYPER["|2"] ~= nil, table.concat((function()
          local t = {} for k in pairs(HYPER) do t[#t + 1] = k end
          table.sort(t) return t
      end)(), ","))
check("…and pressing it opens the pad", (function()
    if not HYPER["|2"] then return false end
    np.draft = ""
    local before = np.webview
    HYPER["|2"].fn()
    return np.webview ~= nil and before == nil
end)())
np.hide()
check("the pad claims Esc through the router", CLAIMED_ESC["notepad"] ~= nil)
check("…and registers with the ⌘-drag layer",
      #_G.movablePanels == 1 and _G.movablePanels[1].name == "quick append pad")
mod.warm(CORE)
check("warm() arms the daily review timer", TIMERS[1] ~= nil)
check("…at 16:01 — one minute AFTER the Capture Pad's send",
      TIMERS[1] and TIMERS[1].at == "16:01" and TIMERS[1].repeats == "1d")
check("…and the timer object is HELD (a collected timer never fires)",
      np.reviewTimer ~= nil)

-- =======================================================================
out("2) the parser — prefixes route, continuations stay, plain = Log\n")
-- =======================================================================
local es = np.parseEntries("* an idea\nsecond line of the idea\n"
    .. "+ a log\n! call Dana about the audit\n? remember the keycode\n"
    .. "plain trailing line")
check("six lines become four entries — two are continuations", #es == 4, #es)
check("* starts an Idea", es[1] and es[1].kind == "Ideas")
check("…and the unprefixed line under it CONTINUES it",
      es[1] and es[1].text == "an idea\nsecond line of the idea", es[1] and es[1].text)
check("+ starts a Log", es[2] and es[2].kind == "Logs" and es[2].text == "a log")
check("! is a task", es[3] and es[3].kind == "task")
check("? is a note", es[4] and es[4].kind == "note")
check("a plain line after a prefixed entry continues THAT entry",
      es[4] and es[4].text == "remember the keycode\nplain trailing line",
      es[4] and es[4].text)
local es2 = np.parseEntries("no prefix at all")
check("a box with no prefixes is one Log — 'if you can't tell, make it "
      .. "a Log entry'", #es2 == 1 and es2[1].kind == "Logs")
check("a prefix with nothing after it is abandoned, not filed",
      #np.parseEntries("*\n+  \n") == 0)
check("an empty box is no entries", #np.parseEntries("") == 0)

-- =======================================================================
out("3) closing files EVERYTHING — the one close path routes it all\n")
-- =======================================================================
PROVIDED["notes.openPad"]()
local view = WEBVIEWS[#WEBVIEWS]
check("a webview opened", view ~= nil and view.shown)
check("…titled Quick Append", view.title == "Quick Append", view.title)
check("the prefix legend is on the page",
      view.htmlSet:find("<b>*</b> Idea", 1, true) ~= nil
      and view.htmlSet:find("<b>!</b> task", 1, true) ~= nil)
check("say() attaches the live textarea to EVERY message (the 6.44.7 rule)",
      view.htmlSet:find("m.text = t.value", 1, true) ~= nil)
check("the non-activating mask was applied AND verified",
      np.nonActivatingApplied == true, np.nonActivatingWhy)

UC_CALLBACK({ body = { a = "close",
    text = "plain log line\n* an idea\n+ a log\n! call Dana" } })
check("closing routed the plain, * and + lines through notes.append",
      #APPENDED == 3
      and APPENDED[1].target == "Logs"  and APPENDED[1].text == "plain log line"
      and APPENDED[2].target == "Ideas" and APPENDED[2].text == "an idea"
      and APPENDED[3].target == "Logs"  and APPENDED[3].text == "a log",
      #APPENDED)
check("…and the ! line went to the Capture Pad queue with its prefix, "
      .. "so its own title rules decide",
      #QUEUED == 1 and QUEUED[1] == "!call Dana", QUEUED[1])
check("one summary alert counts the destinations",
      ALERTS[#ALERTS]:find("2 Logs", 1, true) ~= nil
      and ALERTS[#ALERTS]:find("1 Idea", 1, true) ~= nil
      and ALERTS[#ALERTS]:find("1 → Asana queue", 1, true) ~= nil,
      ALERTS[#ALERTS])
check("…the pad closed", view.deleted == true)
check("…and the draft is empty for next time", np.draft == "")

-- A failed append: the failing entry STAYS in the draft.
PROVIDED["notes.openPad"]()
view = WEBVIEWS[#WEBVIEWS]
APPEND_RESULT = { false, "could not open /gone/log.txt" }
UC_CALLBACK({ body = { a = "close", text = "+ precious words" } })
check("a failed entry is kept in the draft — it exists nowhere else",
      np.draft:find("precious words", 1, true) ~= nil, np.draft)
check("…and the alert says what failed",
      ALERTS[#ALERTS]:find("could not open", 1, true) ~= nil, ALERTS[#ALERTS])
APPEND_RESULT = { true, "📝 Logs ← 1 line: hello" }
np.draft = ""

-- Reopening an open pad files the old draft FIRST (reopen IS a close).
PROVIDED["notes.openPad"]()
UC_CALLBACK({ body = { a = "insertClip", text = "+ typed then abandoned" } })
local before = #APPENDED
PROVIDED["notes.typeIdeas"]()
check("reopening by another key files what was in the box first",
      #APPENDED == before + 1
      and APPENDED[#APPENDED].text == "typed then abandoned")
check("…and the new door's prefix seeds the now-empty box",
      np.draft == "* ", np.draft)
UC_CALLBACK({ body = { a = "close", text = "" } })

-- =======================================================================
out("4) insert clipboard — ⌘⇧V puts the clipboard INTO the box\n")
-- =======================================================================
PROVIDED["notes.openPad"]()
CLIPBOARD = "from the clipboard"
UC_CALLBACK({ body = { a = "insertClip", text = "+ already typed" } })
check("the clipboard landed on its own line under the draft",
      np.draft == "+ already typed\nfrom the clipboard", np.draft)
CLIPBOARD = ""
UC_CALLBACK({ body = { a = "insertClip", text = np.draft } })
check("an empty clipboard says so instead of inserting nothing",
      ALERTS[#ALERTS]:find("no text", 1, true) ~= nil, ALERTS[#ALERTS])
UC_CALLBACK({ body = { a = "close", text = "" } })
np.draft = ""

-- =======================================================================
out("5) the prefix doors — pad* seeds *, pad- seeds +\n")
-- =======================================================================
PROVIDED["notes.typeIdeas"]()
check("⇪pad* opens with '* ' waiting", np.draft == "* ")
UC_CALLBACK({ body = { a = "close", text = "" } })
PROVIDED["notes.typeLog"]()
check("⇪pad- opens with '+ ' waiting", np.draft == "+ ")
UC_CALLBACK({ body = { a = "close", text = "" } })
CLIPBOARD = "clip text"
PROVIDED["notes.editClipboard"]()
check("editClipboard seeds the box with the clipboard itself",
      np.draft == "clip text")
UC_CALLBACK({ body = { a = "close", text = "" } })
np.draft = ""

-- =======================================================================
out("6) the 16:01 review — today's CSV rows, one click → a task\n")
-- =======================================================================
local today = os.date("%Y-%m-%d")
local csv = io.open(CSV_PATH, "w")
csv:write("Date,Note Type,Note entry\n")
csv:write("2020-01-01 09:00,Logs,ancient history\n")
csv:write(today .. " 09:15,Ideas,\"an idea, with a comma\"\n")
csv:write(today .. " 11:40,Logs,\"a log\nacross two lines\"\n")
csv:close()
local opened = np.review()
check("review opens when today has entries", opened == true)
check("…listing ONLY today's — the 2020 row stayed out",
      #np.reviewList == 2, #np.reviewList)
check("…with quoted commas intact",
      np.reviewList[1] and np.reviewList[1].text == "an idea, with a comma",
      np.reviewList[1] and np.reviewList[1].text)
check("…and a quoted MULTI-LINE note read as one record",
      np.reviewList[2] and np.reviewList[2].text == "a log\nacross two lines",
      np.reviewList[2] and np.reviewList[2].text)
view = WEBVIEWS[#WEBVIEWS]
check("the page asks the question",
      view.htmlSet:find("turning into a task", 1, true) ~= nil)
local qBefore = #QUEUED
UC_CALLBACK({ body = { a = "toTask", idx = 1, text = "" } })
check("→ Task queues the entry FORCED as a task (! prefix)",
      #QUEUED == qBefore + 1 and QUEUED[#QUEUED] == "!an idea, with a comma",
      QUEUED[#QUEUED])
check("…and the row shows queued instead of the button",
      WEBVIEWS[#WEBVIEWS].htmlSet:find("queued ✓", 1, true) ~= nil)
UC_CALLBACK({ body = { a = "toTask", idx = 1, text = "" } })
check("a second click on the same row does NOT queue it twice",
      #QUEUED == qBefore + 1)
UC_CALLBACK({ body = { a = "close", text = "" } })
check("closing the review clears review mode", np.reviewMode == false)

os.remove(CSV_PATH)
check("a day with no entries alerts instead of opening", (function()
    local n = #WEBVIEWS
    local ok = np.review()
    return ok == false and #WEBVIEWS == n
           and ALERTS[#ALERTS]:find("no notes today", 1, true) ~= nil
end)())

-- =======================================================================
out("7) no webview — the plain prompt routes through the same parser\n")
-- =======================================================================
local savedWebview = hs.webview
hs.webview = nil
local aBefore, qBefore2 = #APPENDED, #QUEUED
PROMPT_ANSWER = { "File it", "* prompt idea\n! prompt task" }
np.draft = ""
PROVIDED["notes.openPad"]()
check("the fallback prompt was shown", #PROMPTS > 0)
check("…and its entries routed exactly like the pad's",
      #APPENDED == aBefore + 1 and APPENDED[#APPENDED].target == "Ideas"
      and #QUEUED == qBefore2 + 1 and QUEUED[#QUEUED] == "!prompt task")
PROMPT_ANSWER = { "Cancel", "x" }
PROVIDED["notes.openPad"]()
check("Cancel files nothing", #APPENDED == aBefore + 1)
hs.webview = savedWebview

-- =======================================================================
out("8) a profile without the Capture Pad — demoted LOUDLY, never dropped\n")
-- =======================================================================
REGISTRY["capturePad.add"] = nil
local aBefore2 = #APPENDED
local ok2, summary2 = np.fileAll("! orphan task")
check("the ! line was saved as a Log instead of vanishing",
      #APPENDED == aBefore2 + 1 and APPENDED[#APPENDED].target == "Logs"
      and APPENDED[#APPENDED].text == "orphan task")
check("…and the summary SAYS the intent was lost",
      tostring(summary2):find("Capture Pad not loaded", 1, true) ~= nil,
      summary2)

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
