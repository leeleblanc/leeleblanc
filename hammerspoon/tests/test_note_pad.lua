-- =====================================================================
-- test_note_pad.lua — the Capture-Pad-style window that files to FILES
-- =====================================================================
--     lua5.4 test_note_pad.lua [/path/to/hammerspoon]
--
-- The claims under test: the three doors in (edit-the-clipboard, type
-- to Ideas & Scratch, type to Logs) are published services; filing goes
-- through notes.append and relays ITS verdict — close-and-confirm on
-- success, stay-open on failure, because closing would discard the one
-- copy of a note that just failed to save; re-aiming keeps the draft;
-- ⌘⇧C copies back and says how much; a Mac without a webview still
-- files through the plain prompt; and a profile without quick_append
-- gets told, not a half-working pad.

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
local ALERTS, PROVIDED, WEBVIEWS, PROMPTS = {}, {}, {}, {}
local CLIPBOARD = ""
local PROMPT_ANSWER = { "Cancel", "" }
local UC_CALLBACK = nil

local function newWebviewStub(rect)
    local v = { rect = rect, _style = 0, deleted = false, shown = false,
                htmlSet = nil }
    function v:windowTitle() return self end
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
    timer = { doEvery = function(_, fn)
        local t = { fn = fn }
        function t:stop() self.stopped = true end
        return t
    end },
    eventtap = { checkMouseButtons = function() return {} end },
}

_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local APPENDED = {}
local APPEND_RESULT = { true, "📝 Inbox ← 1 line: hello" }
local REGISTRY = {
    ["notes.append"] = function(text, targetName)
        APPENDED[#APPENDED + 1] = { text = text, target = targetName }
        return APPEND_RESULT[1], APPEND_RESULT[2]
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

_G.quickAppend = {
    defaultTarget = 1,
    targets = {
        { name = "Inbox",           file = "inbox.txt" },
        { name = "Ideas & Scratch", file = "ideas.txt" },
        { name = "Logs",            file = "log.txt" },
    },
}

local CLAIMED_ESC = {}
_G.claimEscape = function(name, _, present, close)
    CLAIMED_ESC[name] = { present = present, close = close }
end
_G.movablePanels = {}

local CORE = { provide = function(n, f) PROVIDED[n] = f end }

local mod = dofile(HS .. "/modules/note_pad.lua")
mod.setup(CORE)
local np = _G.notePad

-- =======================================================================
out("1) the doors in — three services, an escape claim, a drag entry\n")
-- =======================================================================
check("notes.editClipboard is published", PROVIDED["notes.editClipboard"] ~= nil)
check("notes.typeIdeas is published",     PROVIDED["notes.typeIdeas"] ~= nil)
check("notes.typeLog is published",       PROVIDED["notes.typeLog"] ~= nil)
check("notePad.show is published",        PROVIDED["notePad.show"] ~= nil)
check("the pad claims Esc through the router", CLAIMED_ESC["notepad"] ~= nil)
check("…and registers with the ⌘-drag layer",
      #_G.movablePanels == 1 and _G.movablePanels[1].name == "note pad")

-- =======================================================================
out("2) ⇪pad2 — the clipboard opens FOR EDITING, page built right\n")
-- =======================================================================
CLIPBOARD = 'copied <text> & "quotes"'
PROVIDED["notes.editClipboard"]()
local view = WEBVIEWS[#WEBVIEWS]
check("a webview opened", view ~= nil and view.shown)
check("the clipboard is IN the page, HTML-escaped",
      view and view.htmlSet
      and view.htmlSet:find("copied &lt;text&gt; &amp; &quot;quotes&quot;", 1, true) ~= nil)
check("every target is a button on the page",
      view and view.htmlSet:find("Ideas &amp; Scratch", 1, true) ~= nil
      and view.htmlSet:find("Logs", 1, true) ~= nil)
check("the default target starts highlighted",
      view and view.htmlSet:find('class="tgt on"', 1, true) ~= nil)
check("say() attaches the live textarea to EVERY message (the 6.44.7 rule)",
      view and view.htmlSet:find("m.text = t.value", 1, true) ~= nil)
check("⌘⏎ files, ⌘⇧C copies, Esc closes — all in the page's keydown",
      view and view.htmlSet:find("e.key === 'Enter'", 1, true) ~= nil
      and view.htmlSet:find("'c' || e.key === 'C'", 1, true) ~= nil
      and view.htmlSet:find("e.key === 'Escape'", 1, true) ~= nil)
check("the JS bridge is connected", UC_CALLBACK ~= nil)
check("the non-activating mask was applied AND verified",
      np.nonActivatingApplied == true, np.nonActivatingWhy)

-- =======================================================================
out("3) filing — notes.append's verdict decides what happens\n")
-- =======================================================================
UC_CALLBACK({ body = { a = "file", text = "edited note", sel = 3 } })
check("the text went through notes.append",
      #APPENDED == 1 and APPENDED[1].text == "edited note")
check("…aimed at the DEFAULT target when none was picked",
      APPENDED[1].target == "Inbox", APPENDED[1].target)
check("success shows quick_append's own confirmation — file, count, preview",
      ALERTS[#ALERTS] == "📝 Inbox ← 1 line: hello", ALERTS[#ALERTS])
check("…and the pad closed", view.deleted == true)
check("…and the draft was cleared for next time", np.draft == "")

-- Failure: the pad must STAY OPEN — closing discards the only copy.
PROVIDED["notes.editClipboard"]()
view = WEBVIEWS[#WEBVIEWS]
APPEND_RESULT = { false, "could not open /gone/inbox.txt" }
UC_CALLBACK({ body = { a = "file", text = "precious words" } })
check("a failed save alerts with the reason",
      ALERTS[#ALERTS]:find("could not open", 1, true) ~= nil, ALERTS[#ALERTS])
check("…and the pad STAYS OPEN — the note is the only copy",
      view.deleted == false)
check("…and the draft still holds the words", np.draft == "precious words")
APPEND_RESULT = { true, "📝 Inbox ← 1 line: hello" }

-- =======================================================================
out("4) re-aiming — ⌘2 moves the target, not the text\n")
-- =======================================================================
UC_CALLBACK({ body = { a = "aim", target = "Ideas & Scratch",
                       text = "precious words", sel = 8 } })
check("the highlight moved to the picked target",
      np.target == "Ideas & Scratch")
view = WEBVIEWS[#WEBVIEWS]
check("…the page re-rendered with the draft intact",
      view.htmlSet:find("precious words", 1, true) ~= nil)
UC_CALLBACK({ body = { a = "file", text = "precious words" } })
check("filing now goes to the aimed target",
      APPENDED[#APPENDED].target == "Ideas & Scratch",
      APPENDED[#APPENDED].target)

-- =======================================================================
out("5) ⌘⇧C — the edited text back onto the clipboard, counted\n")
-- =======================================================================
PROVIDED["notes.typeIdeas"]()
UC_CALLBACK({ body = { a = "copy", text = "take this back" } })
check("the clipboard now holds the edited text", CLIPBOARD == "take this back")
check("…and the alert says how much was copied",
      ALERTS[#ALERTS]:find("14 chars", 1, true) ~= nil, ALERTS[#ALERTS])

-- =======================================================================
out("6) the aimed doors — pad* → Ideas & Scratch, pad- → Logs\n")
-- =======================================================================
check("notes.typeIdeas aims at Ideas & Scratch", np.target == "Ideas & Scratch")
PROVIDED["notes.typeLog"]()
check("notes.typeLog aims at Logs", np.target == "Logs")
UC_CALLBACK({ body = { a = "file", text = "logged" } })
check("…and files there", APPENDED[#APPENDED].target == "Logs")

-- =======================================================================
out("7) an empty clipboard still opens — with the truth said\n")
-- =======================================================================
CLIPBOARD = ""
PROVIDED["notes.editClipboard"]()
check("the pad opened anyway — the key was pressed to WRITE",
      WEBVIEWS[#WEBVIEWS].shown)
check("…and the alert says why the box is blank",
      (function()
          for _, a in ipairs(ALERTS) do
              if a:find("no text", 1, true) then return true end
          end
      end)())
UC_CALLBACK({ body = { a = "close" } })
check("Esc's close message tears the window down",
      WEBVIEWS[#WEBVIEWS].deleted == true)

-- =======================================================================
out("8) no webview — the plain prompt still files, same service\n")
-- =======================================================================
local savedWebview = hs.webview
hs.webview = nil
local before = #APPENDED
PROMPT_ANSWER = { "File it", "typed into the prompt" }
np.draft = ""
PROVIDED["notes.typeLog"]()
check("the fallback prompt was shown", #PROMPTS > 0)
check("…naming the target it will file to",
      PROMPTS[#PROMPTS].msg:find("Logs", 1, true) ~= nil, PROMPTS[#PROMPTS].msg)
check("…and what was typed reached notes.append",
      #APPENDED == before + 1
      and APPENDED[#APPENDED].text == "typed into the prompt")
PROMPT_ANSWER = { "Cancel", "x" }
PROVIDED["notes.typeLog"]()
check("Cancel files nothing", #APPENDED == before + 1)
hs.webview = savedWebview

-- =======================================================================
out("9) a profile without quick_append — told, not half-working\n")
-- =======================================================================
local savedQa = _G.quickAppend
_G.quickAppend = nil
ALERTS = {}
local okNoQa = np.fileIt("orphan note")
check("filing refuses without a crash", okNoQa == false)
check("…and the alert names the missing module",
      ALERTS[1] and ALERTS[1]:find("Quick Append", 1, true) ~= nil, ALERTS[1])
_G.quickAppend = savedQa

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
