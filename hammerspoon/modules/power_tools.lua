-- =====================================================================
-- MODULE: POWER TOOLS (⇪;) — the small ones, in one list
-- =====================================================================
-- LL asked for four things that are each too small to deserve a key and
-- too useful to leave out:
--
--   "Did you create my tool that allows me to paste into fields that I
--    cannot? These would be confirmations like typing your email twice."
--   "Can you give me a tool where I select text and it tells me 1) total
--    word count, 2) total character count, and 3) total sentence count"
--   "Can you give me something to strip clipboard formatting?"
--   "List file metadata for a selected file"
--
-- One key opens the list, you type two letters, ⏎ runs it.
--
--        ⇪;         the power tools — type to filter, ⏎ runs it
--
-- ⚠️ THE ANSWER TO THE FIRST QUESTION IS NO, IT DID NOT EXIST. There was
-- nothing anywhere in this config that typed the clipboard rather than
-- pasting it. "Copy as Plain Text" in ⇪⇧A strips formatting, which is a
-- different problem with a similar shape, and that is probably the thing
-- being half-remembered. It is here now, and it is the row called
-- Type the clipboard.
--
-- ---------------------------------------------------------------------
-- ⌨️ TYPE THE CLIPBOARD — what it is actually for, and where it fails
-- ---------------------------------------------------------------------
-- A "confirm your email address" field that refuses ⌘V is not broken and
-- not protecting anything: the page has an onpaste handler that returns
-- false, in the belief that retyping proves you read it. Synthetic
-- keystrokes are indistinguishable from your fingers, so the field takes
-- them, and the typo the whole exercise was meant to prevent cannot
-- happen because the characters come from the clipboard.
--
-- 🚨 SECURE INPUT IS THE ONE THING THAT BEATS IT, and it is checked
-- BEFORE anything is typed. When a password field has secure event input
-- turned on, macOS stops synthetic keystrokes at the window server —
-- nothing arrives, no error is raised, and the field simply stays empty.
-- Typing into that and reporting success would be the worst possible
-- outcome, so the check comes first and the refusal names the reason.
--
-- ⏳ AND IT WAITS FOR THE MODIFIERS. You reached this row through ⇪,
-- which means ⌘⇧⌃⌥ were held moments ago. A keystroke posted while any
-- of them is still down arrives as ⌘-that-letter — a menu shortcut, not
-- a character, in whatever app is in front. Same hazard the right-click
-- module has, same fix: poll until they are up, fire the moment they
-- are, and give up rather than fire blind if they never come up.
--
-- ---------------------------------------------------------------------
-- 🔢 COUNTING — where the numbers come from, and what "sentence" means
-- ---------------------------------------------------------------------
-- The selection is read two ways, in order. First the accessibility API
-- asks the focused element for AXSelectedText, which costs nothing and
-- disturbs nothing. Apps that answer that (native Cocoa, most browser
-- page text) are done there. Apps that do not — the Electron ones,
-- mostly — fall back to a ⌘C with the clipboard SAVED FIRST AND PUT BACK
-- AFTER, and the clipboard watcher suppressed across the round trip so
-- your copy history does not fill with things you never copied.
--
-- ⚠️ SENTENCE COUNTING IS AN ESTIMATE AND IS LABELLED ONE. It counts
-- runs of . ! or ? that are followed by whitespace or the end of the
-- text. "Dr. Smith went to the U.S. yesterday." is three by that rule
-- and one by yours. Doing better needs a sentence tokenizer with an
-- abbreviation list, which is a real library, not twenty lines — so the
-- number is shown with a ~ in front of it rather than being quietly
-- wrong. Words and characters have no such problem and carry no ~.
--
-- ---------------------------------------------------------------------
-- ℹ️ FILE METADATA — why it is a picker and not a window
-- ---------------------------------------------------------------------
-- `mdls` on a photo returns sixty attributes. A window showing sixty
-- rows is a window you scroll; a chooser showing sixty rows is a list
-- you type "expos" into. And the thing you usually want from metadata is
-- ONE value, in the clipboard — so ⏎ on a row copies it.
-- =====================================================================

local M = {
    name  = "Power Tools",
    order = 13.98,
    family = "text",
    cheatsheet = {
        title = "🧰 POWER TOOLS (⇪; — the small ones, in one list)",
        entries = {
            { "⇪;",     "The list — type to filter, ⏎ runs it" },
            { "⌨️ type", "Types the clipboard key by key — for fields that" },
            { "",       "refuse ⌘V, like “confirm your email address”" },
            { "🔢 count", "Words · characters · ~sentences in the selection" },
            { "📋 plain", "Strips every bit of formatting off the clipboard" },
            { "ℹ️ meta",  "Every mdls attribute of the Finder selection, ⏎ copies" },
            { "check",  "_G.powerReport() — what ran, and what refused" },
        },
    },
}

function M.setup(core)
    local pt = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    pt.enabled      = true
    pt.key          = ";"          -- ⇪;  (⇪⇧; is app kill)
    pt.keyMods      = {}
    -- ⌨️ typing the clipboard
    pt.typeChunk    = 120          -- characters posted per burst
    pt.typeGap      = 0.03         -- seconds between bursts
    pt.typeMax      = 5000         -- refuse anything longer, with a count
    pt.typeDelay    = 0.25         -- let the picker close and focus return
    pt.settleTimeout = 0.60        -- give up waiting for ⌘⇧⌃⌥ to come up
    pt.settleTick   = 0.02
    -- 🔢 counting
    pt.copyWait     = 0.18         -- how long ⌘C is given to land
    pt.restoreAfter = 0.60         -- when the borrowed clipboard goes back
    pt.statsShow    = 7            -- seconds the numbers stay on screen
    -- 🚨 Per-element Accessibility timeout, in seconds. The freeze guard,
    -- not a tuning knob — see pt.axSelection.
    pt.axTimeout    = 0.10
    -- ℹ️ metadata
    pt.mdlsTimeout  = 6            -- seconds before mdls is abandoned
    pt.valueChars   = 300          -- attribute value shown in a row
    -- ----------------------------------------------------------------------

    pt.chooser    = nil   -- HELD: an unreferenced hs.chooser is collected
    pt.metaChooser = nil  -- HELD
    pt.settleTimer, pt.typeTimer, pt.copyTimer = nil, nil, nil  -- HELD
    pt.startTimer, pt.metaTimer = nil, nil                      -- HELD
    pt.metaTask, pt.selTask = nil, nil                          -- HELD
    pt.metaRows  = {}
    pt.ran       = {}     -- id -> how many times
    pt.lastNote  = nil
    pt.typed     = 0      -- characters typed this session

    local function say(m)  if _G.diag then _G.diag.say("powerTools", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("powerTools", m) end end

    local function note(m)
        pt.lastNote = m
        warn(m)
    end

    -- =====================================================================
    -- 📋 STRIP CLIPBOARD FORMATTING
    -- =====================================================================
    -- Reading the string flavor and writing it back is the whole trick:
    -- setContents REPLACES the pasteboard rather than adding to it, so the
    -- RTF, HTML and attributed-string flavors that carried the font, the
    -- colour and the tracking links do not survive the round trip.
    --
    -- ⚠️ IT REPORTS THE DIFFERENCE, and that is not decoration. "Stripped"
    -- with nothing visibly changed is indistinguishable from "did nothing",
    -- and this is a tool you reach for precisely when you cannot see
    -- whether it worked. Saying how many flavors went away is the proof.
    function pt.stripClipboard()
        local before = 0
        pcall(function()
            local all = hs.pasteboard.contentTypes()
            if type(all) == "table" then before = #all end
        end)
        local ok, text = pcall(hs.pasteboard.getContents)
        if not (ok and type(text) == "string" and text ~= "") then
            note("clipboard held no plain text to keep")
            hs.alert.show("📋 Nothing on the clipboard this can strip —\n"
                .. "it holds no text at all", 3.5)
            return false
        end
        local wrote = pcall(function() hs.pasteboard.setContents(text) end)
        if not wrote then
            note("could not write the stripped clipboard back")
            hs.alert.show("📋 Could not write the clipboard back", 3)
            return false
        end
        local after = 0
        pcall(function()
            local all = hs.pasteboard.contentTypes()
            if type(all) == "table" then after = #all end
        end)
        local dropped = before - after
        say("stripped clipboard: " .. before .. " flavors → " .. after)
        hs.alert.show(dropped > 0
            and ("📋 Formatting stripped — " .. dropped
                 .. " flavour" .. (dropped == 1 and "" or "s") .. " removed,\n"
                 .. #text .. " characters of plain text left")
            or  ("📋 Already plain — " .. #text .. " characters, nothing to strip"),
            3.5)
        return true
    end

    -- =====================================================================
    -- ⌨️ TYPE THE CLIPBOARD
    -- =====================================================================
    -- Wait for ⌘⇧⌃⌥ to come up, then post the text in bursts. Both halves
    -- matter: see the header for why a keystroke posted under a live
    -- modifier is a menu command rather than a character.
    function pt.modifiersHeld()
        local ok, mods = pcall(hs.eventtap.checkKeyboardModifiers)
        if not ok or type(mods) ~= "table" then return false end
        return (mods.cmd or mods.alt or mods.shift or mods.ctrl) == true
    end

    -- ⏳ ONE TIMER, ONE CALLBACK, EXACTLY ONCE — the same shape the
    -- right-click module settles with, and written that way deliberately.
    -- The obvious alternative (a doWhile to wait plus a doAfter to decide
    -- what happens next) has two timers that can both reach the callback,
    -- and "the clipboard was typed twice" is a defect you cannot undo out
    -- of a text field. fn is called with true when the modifiers actually
    -- came up and false when the timeout won.
    function pt.whenClear(fn)
        if pt.settleTimer then
            pcall(function() pt.settleTimer:stop() end)
            pt.settleTimer = nil
        end
        if not pt.modifiersHeld() then fn(true) return end
        local waited = 0
        local okTimer = pcall(function()
            pt.settleTimer = hs.timer.doEvery(pt.settleTick, function()
                waited = waited + pt.settleTick
                local clear = not pt.modifiersHeld()
                if not (clear or waited >= pt.settleTimeout) then return end
                pcall(function() pt.settleTimer:stop() end)
                pt.settleTimer = nil
                fn(clear)
            end)
        end)
        if not (okTimer and pt.settleTimer) then
            -- No timer means no wait. Refuse rather than type blind: a
            -- keystroke under a live ⌘ is a menu command in somebody
            -- else's app, which is the one outcome worse than nothing.
            warn("could not arm the settle timer — refusing to type")
            fn(false)
        end
    end

    function pt.typeClipboard()
        local ok, text = pcall(hs.pasteboard.getContents)
        if not (ok and type(text) == "string" and text ~= "") then
            note("nothing on the clipboard to type")
            hs.alert.show("⌨️ Nothing on the clipboard to type", 3)
            return false
        end
        if #text > pt.typeMax then
            note("clipboard too long to type (" .. #text .. " characters)")
            hs.alert.show(("⌨️ %d characters is too much to type — the cap is %d.\n"
                .. "Raise pt.typeMax if you really want to.")
                :format(#text, pt.typeMax), 5)
            return false
        end
        -- 🚨 THE CHECK THAT HAS TO COME FIRST. See the header: under secure
        -- input nothing arrives and nothing complains.
        local okSec, secure = pcall(hs.eventtap.isSecureInputEnabled)
        if okSec and secure then
            note("secure input is on — synthetic keystrokes are blocked")
            hs.alert.show("⌨️ Secure input is ON — macOS blocks synthetic\n"
                .. "keystrokes into password fields. Nothing was typed.", 5)
            return false
        end

        -- HELD. An unreferenced hs.timer is collected before it fires, and
        -- the symptom is "⇪; type does nothing, sometimes".
        pt.startTimer = hs.timer.doAfter(pt.typeDelay, function()
            pt.startTimer = nil
            pt.whenClear(function(clear)
                if not clear then
                    note("modifiers never came up — refused to type")
                    hs.alert.show("⌨️ ⌘⇧⌃⌥ still held — nothing typed", 3)
                    return
                end
                pt.postText(text)
            end)
        end)
        return true
    end

    -- Posted in bursts rather than one call. A single keyStrokes() of a
    -- few thousand characters floods the target app's event queue, and
    -- several apps drop characters out of the middle of it — which is the
    -- one failure mode this tool cannot have, because the whole point is
    -- that the text is exactly right.
    function pt.postText(text)
        local i, n = 1, #text
        local sent = 0
        local function burst()
            if i > n then
                pt.typed = pt.typed + sent
                pt.typeTimer = nil
                say("typed " .. sent .. " characters")
                return
            end
            local chunk = text:sub(i, i + pt.typeChunk - 1)
            i = i + pt.typeChunk
            sent = sent + #chunk
            pcall(function() hs.eventtap.keyStrokes(chunk) end)
            pt.typeTimer = hs.timer.doAfter(pt.typeGap, burst)
        end
        burst()
    end

    -- =====================================================================
    -- 🔢 COUNT THE SELECTION
    -- =====================================================================
    -- The counters themselves, split out so the suite can drive them with
    -- text instead of with a Mac. Every one of them is a pure function of
    -- a string, which is the only reason the numbers can be trusted: there
    -- is nothing in here that depends on which app was in front.
    function pt.countWords(s)
        local n = 0
        for _ in tostring(s or ""):gmatch("[^%s]+") do n = n + 1 end
        return n
    end

    function pt.countChars(s)
        s = tostring(s or "")
        local noSpace = s:gsub("%s", "")
        -- #s is BYTES. A curly quote is three of them and one character,
        -- so a byte count would report an em-dash-heavy paragraph as
        -- longer than it is. utf8.len is the honest number; it returns nil
        -- on malformed input, where the byte count is the better guess
        -- than no answer.
        local total = utf8 and utf8.len and utf8.len(s) or nil
        local bare  = utf8 and utf8.len and utf8.len(noSpace) or nil
        return total or #s, bare or #noSpace, #s
    end

    -- ~ because it is an estimate. See the header — abbreviations break it
    -- and no twenty-line rule fixes that.
    function pt.countSentences(s)
        s = tostring(s or "")
        if s:match("^%s*$") then return 0 end
        local n = 0
        for _ in s:gmatch("[%.!%?]+[%s\"'%)%]]*") do n = n + 1 end
        -- Text that ends without punctuation is still one sentence.
        if n == 0 then return 1 end
        if not s:match("[%.!%?][%s\"'%)%]]*$") then n = n + 1 end
        return n
    end

    function pt.countLines(s)
        s = tostring(s or "")
        if s == "" then return 0, 0 end
        local lines = 1
        for _ in s:gmatch("\n") do lines = lines + 1 end
        local paras = 0
        for _ in ("\n" .. s .. "\n"):gmatch("\n[^\n]") do paras = paras + 1 end
        return lines, paras
    end

    function pt.statsFor(s)
        local words          = pt.countWords(s)
        local chars, bare    = pt.countChars(s)
        local sentences      = pt.countSentences(s)
        local lines, paras   = pt.countLines(s)
        return {
            words = words, chars = chars, bare = bare,
            sentences = sentences, lines = lines, paragraphs = paras,
        }
    end

    function pt.statsText(st)
        return ("🔢  %d words\n%d characters   ·   %d without spaces\n"
                .. "~%d sentence%s   ·   %d line%s   ·   %d paragraph%s")
               :format(st.words, st.chars, st.bare,
                       st.sentences, st.sentences == 1 and "" or "s",
                       st.lines, st.lines == 1 and "" or "s",
                       st.paragraphs, st.paragraphs == 1 and "" or "s")
    end

    -- ---- reading what is selected ----------------------------------------
    -- Fast path first: ask the focused element. Costs nothing, disturbs
    -- nothing, and works in every app with honest accessibility support.
    function pt.axSelection()
        local ok, granted = pcall(hs.accessibilityState)
        if not (ok and granted) then return nil end
        local okApp, app = pcall(hs.application.frontmostApplication)
        if not (okApp and app) then return nil end
        local el
        pcall(function()
            local ax = hs.axuielement.applicationElement(app)
            if not ax then return end
            -- 🚨 setTimeout BEFORE ANYTHING IS ASKED. Every question below
            -- crosses into another application and waits for it to answer;
            -- with no timeout the default is generous, and one wedged app
            -- holds Hammerspoon's main thread — the thread that reads your
            -- keyboard. copy_on_select learned this in 6.65.2 and
            -- menubar_items in 6.47.0. The child element inherits nothing,
            -- so it is set on BOTH.
            pcall(function() ax:setTimeout(pt.axTimeout) end)
            el = ax:attributeValue("AXFocusedUIElement")
            if el then pcall(function() el:setTimeout(pt.axTimeout) end) end
        end)
        if not el then return nil end
        local text
        pcall(function() text = el:attributeValue("AXSelectedText") end)
        if type(text) == "string" and text ~= "" then return text end
        return nil
    end

    -- Slow path: borrow the clipboard. Saved first, put back after, and
    -- the pasteboard watcher suppressed across the whole round trip so the
    -- borrowed copy never lands in ⇪V's history.
    function pt.copySelection(done)
        local saved
        pcall(function() saved = hs.pasteboard.getContents() end)
        if _G.pasteboardSuppress then
            pcall(function() _G.pasteboardSuppress(pt.restoreAfter + 1.0) end)
        end
        pcall(function() hs.pasteboard.clearContents() end)
        pcall(function() hs.eventtap.keyStroke({ "cmd" }, "c", 0) end)
        pt.copyTimer = hs.timer.doAfter(pt.copyWait, function()
            local got
            pcall(function() got = hs.pasteboard.getContents() end)
            -- Put it back regardless of what we got. A tool that reads your
            -- selection and keeps your clipboard is a tool you stop using.
            pt.copyTimer = hs.timer.doAfter(pt.restoreAfter, function()
                pcall(function()
                    if saved then hs.pasteboard.setContents(saved)
                    else hs.pasteboard.clearContents() end
                end)
                pt.copyTimer = nil
            end)
            done(type(got) == "string" and got ~= "" and got or nil)
        end)
    end

    function pt.countSelection()
        local text = pt.axSelection()
        if text then
            pt.showStats(text, "accessibility")
            return true
        end
        pt.copySelection(function(copied)
            if not copied then
                note("no selection could be read, by either route")
                hs.alert.show("🔢 Nothing selected — or this app answers\n"
                    .. "neither accessibility nor ⌘C", 4)
                return
            end
            pt.showStats(copied, "⌘C")
        end)
        return true
    end

    function pt.showStats(text, how)
        local st = pt.statsFor(text)
        pt.lastStats = st
        say(("counted via %s: %d words, %d chars, ~%d sentences")
            :format(how, st.words, st.chars, st.sentences))
        hs.alert.show(pt.statsText(st), pt.statsShow)
    end

    -- =====================================================================
    -- ℹ️ FILE METADATA
    -- =====================================================================
    -- The Finder selection is read through a SEPARATE osascript PROCESS,
    -- for the reason universal_actions documents at length: an AppleScript
    -- error raised inside Hammerspoon's own Apple Event handler is an
    -- Objective-C exception, which unwinds straight past pcall and takes
    -- the app down. A child process can only take itself down.
    local FINDER_SEL = [[
tell application "Finder"
    set out to ""
    try
        set sel to selection as alias list
        repeat with f in sel
            set out to out & POSIX path of (f as text) & linefeed
        end repeat
    end try
    return out
end tell]]

    function pt.finderSelection(done)
        local okNew, t = pcall(hs.task.new, "/usr/bin/osascript",
            function(_, stdOut, _)
                local paths = {}
                for line in tostring(stdOut or ""):gmatch("[^\r\n]+") do
                    if line ~= "" then paths[#paths + 1] = line end
                end
                pt.selTask = nil
                pcall(done, paths)
            end,
            { "-e", FINDER_SEL })
        if not (okNew and t) then
            note("could not start osascript — no Finder selection")
            pcall(done, {})
            return
        end
        pt.selTask = t
        pcall(function() t:start() end)
    end

    -- mdls prints `key = value`, and a value can run over several lines
    -- (an array attribute prints one element per line inside parentheses).
    -- So a line WITHOUT a leading key continues the previous attribute
    -- rather than starting a new one — parse it any other way and every
    -- array attribute becomes a row of junk with no name on it.
    function pt.parseMdls(out)
        local rows, cur = {}, nil
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local k, v = line:match("^(%S+)%s*=%s*(.*)$")
            if k then
                cur = { key = k, value = v or "" }
                rows[#rows + 1] = cur
            elseif cur then
                local trimmed = line:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    cur.value = cur.value .. " " .. trimmed
                end
            end
        end
        for _, r in ipairs(rows) do
            r.value = r.value:match("^%s*(.-)%s*$") or r.value
        end
        return rows
    end

    -- `stat` answers the four questions mdls is worst at: the real byte
    -- size, the POSIX permissions, the owner, and the inode. Prepending
    -- them means the list opens with the things you most often wanted.
    function pt.statRows(path)
        local rows = {}
        local attrs = hs.fs.attributes(path)
        if type(attrs) ~= "table" then return rows end
        local function add(k, v) rows[#rows + 1] = { key = k, value = tostring(v) } end
        add("Path", path)
        add("Size", string.format("%d bytes  (%.2f MB)",
                                  attrs.size or 0, (attrs.size or 0) / 1048576))
        add("Kind", tostring(attrs.mode))
        add("Modified", os.date("%Y-%m-%d %H:%M:%S", attrs.modification or 0))
        add("Created",  os.date("%Y-%m-%d %H:%M:%S", attrs.creation or 0))
        add("Accessed", os.date("%Y-%m-%d %H:%M:%S", attrs.access or 0))
        -- hs.fs reports permissions as the rwx STRING ("rw-r--r--"), not a
        -- number. Formatting it with %o produced "0" for every file — the
        -- kind of wrong that looks like a real answer, which is why it is
        -- printed as what it is.
        add("Permissions", tostring(attrs.permissions))
        add("Owner uid", tostring(attrs.uid))
        add("Owner gid", tostring(attrs.gid))
        add("Links", tostring(attrs.nlink))
        return rows
    end

    function pt.fileMetadata()
        pt.finderSelection(function(paths)
            local path = paths[1]
            if not path then
                note("no file selected in Finder")
                hs.alert.show("ℹ️ Select a file in Finder first", 3)
                return
            end
            local t
            local okNew = pcall(function()
                t = hs.task.new("/usr/bin/mdls", function(_, out, _)
                    pt.metaTask = nil
                    local rows = pt.statRows(path)
                    for _, r in ipairs(pt.parseMdls(out)) do rows[#rows + 1] = r end
                    pt.showMetadata(path, rows)
                end, { path })
            end)
            if not (okNew and t) then
                -- No mdls is a shorter list, not no feature.
                note("could not start mdls — showing filesystem attributes only")
                pt.showMetadata(path, pt.statRows(path))
                return
            end
            pt.metaTask = t
            pcall(function() t:start() end)
            -- HELD, same reason: a collected timer never fires, and this
            -- one is the only thing that stops a wedged mdls from leaving
            -- the panel unopened with no explanation.
            pt.metaTimer = hs.timer.doAfter(pt.mdlsTimeout, function()
                pt.metaTimer = nil
                if pt.metaTask == t then
                    pcall(function() t:terminate() end)
                    pt.metaTask = nil
                    note("mdls did not answer in " .. pt.mdlsTimeout .. "s")
                    pt.showMetadata(path, pt.statRows(path))
                end
            end)
        end)
        return true
    end

    -- ⚠️ The row carries an INTEGER index into pt.metaRows. A nested table
    -- does not survive the crossing into Objective-C, and LuaSkin discards
    -- the WHOLE list and logs rather than throwing — an empty panel with
    -- nothing to catch. Same rule as ⇪⇧T's snippets (6.109.0).
    function pt.showMetadata(path, rows)
        pt.metaRows = rows
        if #rows == 0 then
            hs.alert.show("ℹ️ No metadata could be read for that file", 3)
            return
        end
        local choices = {}
        for i, r in ipairs(rows) do
            local v = r.value or ""
            if #v > pt.valueChars then v = v:sub(1, pt.valueChars - 1) .. "…" end
            choices[#choices + 1] = { text = r.key, subText = v, idx = i }
        end
        if not pt.metaChooser then
            pt.metaChooser = hs.chooser.new(function(pick)
                if not pick then return end
                local r = pt.metaRows[pick.idx]
                if not r then return end
                pcall(function() hs.pasteboard.setContents(r.value or "") end)
                hs.alert.show("ℹ️ " .. r.key .. " copied", 2)
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.fileMetadata = pt.metaChooser
            pcall(function()
                pt.metaChooser:searchSubText(true)
                pt.metaChooser:width(45)
            end)
        end
        pt.metaChooser:choices(choices)
        pt.metaChooser:placeholderText((path:match("([^/]+)$") or path)
            .. " — " .. #rows .. " attributes, ⏎ copies the value")
        pt.metaChooser:query("")
        pt.metaChooser:show()
    end

    -- =====================================================================
    -- THE LIST
    -- =====================================================================
    -- ✏️ To add one: copy a row. `id` is what _G.powerReport() counts by,
    -- so keep it stable. Each `run` returns truthy when it got as far as
    -- starting — an action that refuses says so on screen itself.
    pt.tools = {
        { id = "plain", icon = "📋", title = "Strip clipboard formatting",
          sub = "Keep the text, drop the font, colour, links and RTF",
          run = function() return pt.stripClipboard() end },
        { id = "type",  icon = "⌨️", title = "Type the clipboard",
          sub = "For fields that refuse ⌘V — “confirm your email address”",
          run = function() return pt.typeClipboard() end },
        { id = "count", icon = "🔢", title = "Count the selection",
          sub = "Words, characters and ~sentences in whatever is selected",
          run = function() return pt.countSelection() end },
        { id = "meta",  icon = "ℹ️", title = "File metadata",
          sub = "Every mdls attribute of the Finder selection — ⏎ copies one",
          run = function() return pt.fileMetadata() end },
    }

    function pt.byId(id)
        for _, t in ipairs(pt.tools) do
            if t.id == id then return t end
        end
        return nil
    end

    function pt.run(id)
        local t = pt.byId(id)
        if not t then
            note("no such power tool: " .. tostring(id))
            return false
        end
        pt.ran[id] = (pt.ran[id] or 0) + 1
        local ok, res = pcall(t.run)
        if not ok then
            note(id .. " threw: " .. tostring(res))
            hs.alert.show("🧰 " .. t.title .. " failed — see the Console", 3)
            return false
        end
        return res and true or false
    end

    function pt.show()
        if not pt.enabled then return end
        local choices = {}
        for _, t in ipairs(pt.tools) do
            choices[#choices + 1] = {
                text    = t.icon .. "  " .. t.title,
                subText = t.sub,
                id      = t.id,
            }
        end
        if not pt.chooser then
            pt.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                pt.run(pick.id)
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.powerTools = pt.chooser
            pcall(function()
                pt.chooser:searchSubText(true)
                pt.chooser:width(38)
            end)
        end
        pt.chooser:choices(choices)
        pt.chooser:placeholderText(#choices .. " power tools — type to filter")
        pt.chooser:query("")
        pt.chooser:show()
    end

    -- ---- the report ------------------------------------------------------
    function _G.powerReport()
        local L = { "🧰 POWER TOOLS" }
        local okSec, secure = pcall(hs.eventtap.isSecureInputEnabled)
        L[#L + 1] = "   secure input : " ..
            (okSec and (secure and "ON — typing the clipboard is blocked" or "off")
                   or "unknown")
        local ok, granted = pcall(hs.accessibilityState)
        L[#L + 1] = "   accessibility: " ..
            ((ok and granted) and "granted — selections read without ⌘C"
                              or "OFF — counting falls back to ⌘C")
        L[#L + 1] = "   typed        : " .. pt.typed .. " characters this session"
        local any = false
        for _, t in ipairs(pt.tools) do
            if pt.ran[t.id] then
                any = true
                L[#L + 1] = ("      %-6s %d run%s")
                            :format(t.id, pt.ran[t.id],
                                    pt.ran[t.id] == 1 and "" or "s")
            end
        end
        if not any then L[#L + 1] = "   ran          : nothing this session" end
        if pt.lastStats then
            L[#L + 1] = "   last count   : " ..
                pt.statsText(pt.lastStats):gsub("\n", " · "):gsub("🔢%s*", "")
        end
        if pt.lastNote then L[#L + 1] = "   last problem : " .. pt.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if pt.enabled then
        core.hyperAddShortcut(pt.keyMods, pt.key, function() pt.show() end,
                              "power tools")
    end
    core.provide("power.show",     function() return pt.show() end)
    core.provide("power.plain",    function() return pt.run("plain") end)
    core.provide("power.type",     function() return pt.run("type")  end)
    core.provide("power.count",    function() return pt.run("count") end)
    core.provide("power.metadata", function() return pt.run("meta")  end)
    core.provide("power.report",   function() return _G.powerReport() end)

    _G.powerTools = pt
    M.pt     = pt
    M.config = pt
end

return M
