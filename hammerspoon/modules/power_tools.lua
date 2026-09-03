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
-- 6.120.0 added four more, each with a key of its own as well, because
-- these are the ones you press mid-something rather than go looking for:
--
--   "Can you create a key that will pause all audio and video?"
--   "Can we open a Ghostty terminal from current Finder folder; and open
--    current Ghostty teminal path in Finder?"
--   "How about an on screen QR reader?"
--
-- One key opens the list, you type two letters, ⏎ runs it.
--
--        ⇪;         the power tools — type to filter, ⏎ runs it
--        ⇪'         ⏸ pause all audio and video
--        ⇪`         👻 Ghostty at the front Finder folder
--        ⇪⇧`        📂 Finder at the front Ghostty folder
--        ⇪5         🔳 read a QR code off the screen
--
-- 🔑 WHY THESE KEYS AND NOT LETTERS. There are none left — every ⇪
-- letter and every ⇪⇧ letter has been claimed since 6.104.0. ⇪5 sits
-- beside ⇪4, the screenshot key, because both read the screen; ⇪' and
-- ⇪` are simply the two nearest unclaimed keys, and there is no
-- mnemonic being implied. All of them are in ⇪⇧/ too.
--
-- 6.126.0 — LL: "⇪' does not pause VLC." It did not, and it never had:
-- VLC's dictionary has no `pause` and no `playpause`, so both verbs the
-- shared script sent bounced, silently. Its toggle is spelled `play`, and
-- `play` sent to a paused VLC starts it — so VLC gets its own script that
-- reads the `playing` property first. See pt.vlcPauseScript.
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
-- 📋 6.132.0 — LL: "Allow both counts to be posted to the clipboard."
-- That is a SECOND ROW rather than a change to the first one. A tool you
-- press to read a number must not quietly replace what is on your
-- clipboard — you reached for the count, not for a paste — and ⇪V's
-- history would fill with "128 words · 742 characters" lines nobody
-- asked to keep. So: Count the selection shows. Count the selection →
-- clipboard shows AND copies, and says so.
--
-- ---------------------------------------------------------------------
-- 🔠 CHANGE THE CASE OF THE SELECTION (6.132.0)
-- ---------------------------------------------------------------------
-- LL: "I need a way to Change/Transform Text Case … I think I have
-- something already to pick out and transform file names, can we add
-- this to that tool?"
--
-- ⇪R does file names and cannot touch a sentence in an email, so the six
-- cases live in modules/text_case.lua and BOTH tools ask it. Nothing
-- about what a word is is decided in this file.
--
-- 🚨 THE SELECTION IS READ BEFORE THE PICKER OPENS, not after, and that
-- ordering is the whole design. It means every row shows what that case
-- will do to YOUR text rather than to the word "hello" — and three of
-- the six (camel, kebab, snake) throw your punctuation away by
-- definition. A preview of somebody else's sample cannot warn you about
-- that; a preview of your own paragraph can.
--
-- ⚠️ AND IT REPLACES BY TYPING, because macOS has no "set the selection"
-- API — nothing can hand text back to an arbitrary app's text field. The
-- result is posted as keystrokes over the still-live selection, which
-- means it inherits every guard the row above it needed: the secure
-- input check first, the wait for ⌘⇧⌃⌥ to come up, and the length cap.
-- If any of those refuses, nothing is typed and the selection stands.
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
            { "📋 count", "The same, and both counts onto the clipboard" },
            { "🔠 case",  "UPPER · lower · Title · camel · kebab · snake —" },
            { "",        "each row previews YOUR text, then ⏎ types it back" },
            { "📖 define", "Meaning + synonyms together — ⏎ swaps the word" },
            { "📋 plain", "Strips every bit of formatting off the clipboard" },
            { "ℹ️ meta",  "Every mdls attribute of the Finder selection, ⏎ copies" },
            { "⇪'",     "⏸ Pause all audio and video — media key + every" },
            { "",       "scriptable player that is already running" },
            { "⇪⇧1",    "⏸ PAUSE HAMMERSPOON — ⇪ shortcuts and typing helpers" },
            { "",       "off until pressed again · ⏸ HS in the menu bar meanwhile" },
            { "⇪`",     "👻 Ghostty at the front Finder window's folder" },
            { "⇪⇧`",    "📂 Finder at the front Ghostty window's folder" },
            { "⇪5",     "🔳 Read a QR code off the screen — needs zbar" },
            { "🆓 free", "_G.freeKeys() — every unclaimed key, from the live registry" },
            { "📎 open in", "Default app for a file type — set it, proof read back" },
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
    -- 📋 6.132.0 — what the second count row puts on the clipboard. Two
    -- numbers, because "both counts" was the ask; the sentence estimate is
    -- deliberately not in here, since a ~ in a pasted line is a footnote
    -- nobody carries with them.
    pt.countFormat  = "%d words · %d characters"
    -- 🔠 case (6.132.0)
    pt.previewChars = 64           -- how much of your text each row shows
    -- 🚨 Per-element Accessibility timeout, in seconds. The freeze guard,
    -- not a tuning knob — see pt.axSelection.
    pt.axTimeout    = 0.10
    -- ℹ️ metadata
    pt.mdlsTimeout  = 6            -- seconds before mdls is abandoned
    pt.valueChars   = 300          -- attribute value shown in a row
    -- ⏸ pause everything (6.120.0)
    pt.pauseKey     = "'"          -- ⇪'  — one key, no picker
    pt.pauseMods    = {}
    -- ⏸ 6.152.0 — PAUSE HAMMERSPOON ITSELF. LL: "Can I pause Hammerspoon
    -- using an empty key from my Cheat Sheet?" — ⇪⇧1, the first key of
    -- the row 6.142.0 cleared for exactly this kind of ask. One press:
    -- every OTHER ⇪ shortcut goes quiet (enforced centrally in init.lua's
    -- hyperBind, so no shortcut can forget) and the typing interceptors
    -- (autocorrect, expander, key caster) stand down via _G.hsPaused
    -- guards at the top of their taps. Press it again: everything is
    -- back. A ⏸ HS menu-bar flag shows while paused — clicking it
    -- resumes too. Trackers and timers keep running: pause means "get
    -- out of my keyboard", not "stop keeping my logs".
    pt.hsPauseKey   = "1"          -- ⇪⇧1
    pt.hsPauseMods  = { "shift" }
    -- ✏️ THE PLAYERS TOLD BY NAME, in addition to the media key. Order is
    -- irrelevant; each is asked only if it is already running, because
    -- naming an app in AppleScript LAUNCHES it, and "pause everything"
    -- that opens Music is not what anybody meant.
    pt.players      = { "Music", "Spotify", "VLC", "QuickTime Player",
                        "TV", "IINA" }
    -- 🚨 PLAYERS WHOSE ONLY VERB IS A TOGGLE, handled apart from the rest.
    -- VLC has no `pause` and no `playpause`; its dictionary spells the
    -- toggle `play`. Sending `play` blindly to a PAUSED VLC starts it,
    -- which is the same sin as launching Music. Each name here gets its
    -- own script that reads a "still playing?" property first. See
    -- pt.pauseToggleOnly below. Names here are NOT passed to the generic
    -- script — two Apple Events that can only ever fail are two too many.
    pt.toggleOnly   = { "VLC" }
    -- 👻 Ghostty ↔ Finder (6.120.0)
    pt.ghosttyKey   = "`"          -- ⇪` here · ⇪⇧` reveals in Finder
    pt.ghosttyMods  = {}
    pt.revealMods   = { "shift" }
    pt.ghosttyApp   = "Ghostty"
    -- 🔳 QR (6.120.0)
    -- ⇪5 sits next to ⇪4, the screenshot key, because both of them read
    -- the screen. That is the only one of this release's digits with a
    -- reason behind it, and the others say so.
    pt.qrKey        = "5"
    pt.qrMods       = {}
    pt.qrTimeout    = 8            -- seconds before the decode is abandoned
    -- ----------------------------------------------------------------------

    pt.chooser    = nil   -- HELD: an unreferenced hs.chooser is collected
    pt.metaChooser = nil  -- HELD
    pt.caseChooser = nil  -- HELD
    pt.settleTimer, pt.typeTimer, pt.copyTimer = nil, nil, nil  -- HELD
    pt.startTimer, pt.metaTimer = nil, nil                      -- HELD
    pt.metaTask, pt.selTask = nil, nil                          -- HELD
    pt.metaRows  = {}
    pt.ran       = {}     -- id -> how many times
    pt.lastNote  = nil
    pt.typed     = 0      -- characters typed this session
    pt.lastCountLine = nil  -- what the count row last put on the clipboard
    pt.caseText  = nil      -- the selection the open case picker will act on

    -- See the 🚨 note at revealGhostty: these are constants so the
    -- external-binary review in test_diagnostics can see them.
    pt.PGREP, pt.LSOF  = "/usr/bin/pgrep", "/usr/sbin/lsof"
    pt.XARGS, pt.SED   = "/usr/bin/xargs", "/usr/bin/sed"
    pt.TAIL            = "/usr/bin/tail"

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

    -- ⏳ 6.132.0 — WHAT READS THE SELECTION, factored out so the case rows
    -- use exactly the same two routes in exactly the same order. Both
    -- callers need "AX first, ⌘C second, refuse third", and two copies of
    -- that would be two places for the refusal message to drift.
    -- `done(text, how)` — how is "accessibility" or "⌘C". done is never
    -- called with nil; the refusal is shown here and the caller stops.
    function pt.withSelection(label, done)
        local text = pt.axSelection()
        if text then done(text, "accessibility") return true end
        pt.copySelection(function(copied)
            if not copied then
                note("no selection could be read, by either route")
                hs.alert.show(label .. " Nothing selected — or this app answers\n"
                    .. "neither accessibility nor ⌘C", 4)
                return
            end
            done(copied, "⌘C")
        end)
        return true
    end

    -- toClipboard comes from the SECOND count row. See the header for why
    -- it is a second row and not a change to the first one.
    function pt.countSelection(toClipboard)
        return pt.withSelection("🔢", function(text, how)
            pt.showStats(text, how, toClipboard)
        end)
    end

    function pt.showStats(text, how, toClipboard)
        local st = pt.statsFor(text)
        pt.lastStats = st
        local copied = false
        if toClipboard then
            local line = pt.countFormat:format(st.words, st.chars)
            pt.lastCountLine = line
            -- 📋 NOT suppressed from ⇪V's history, unlike the borrowed
            -- clipboard in copySelection. That one is a round trip nobody
            -- asked for; this one is the whole point of the row, and a copy
            -- you deliberately made belongs in the history of copies.
            copied = pcall(function() hs.pasteboard.setContents(line) end)
            if not copied then note("could not put the counts on the clipboard") end
        end
        say(("counted via %s: %d words, %d chars, ~%d sentences%s")
            :format(how, st.words, st.chars, st.sentences,
                    toClipboard and (copied and " (copied)" or " (copy FAILED)") or ""))
        local body = pt.statsText(st)
        if toClipboard then
            body = body .. "\n" .. (copied
                and ("📋 " .. pt.lastCountLine .. " — copied")
                or  "📋 The clipboard refused the counts")
        end
        hs.alert.show(body, pt.statsShow)
    end

    -- =====================================================================
    -- 🔠 CHANGE THE CASE OF THE SELECTION (6.132.0)
    -- =====================================================================
    -- Every case rule lives in modules/text_case.lua. This file reads the
    -- selection, draws the picker and types the answer back; it does not
    -- know what a word is and must not learn.
    function pt.caseList()
        if not (_G.service and _G.service.has and _G.service.has("case.list")) then
            return nil
        end
        local ok, list = pcall(function() return _G.service.call("case.list") end)
        if ok and type(list) == "table" and #list > 0 then return list end
        return nil
    end

    -- One line, whitespace collapsed, cut to fit a chooser row. A preview
    -- that wraps is a preview you cannot compare against the row above it.
    function pt.preview(s)
        s = tostring(s or ""):gsub("%s+", " "):gsub("^%s+", "")
        if s == "" then return "(nothing)" end
        local n = utf8 and utf8.len and utf8.len(s) or nil
        if (n or #s) <= pt.previewChars then return s end
        if n then
            local cut = utf8.offset(s, pt.previewChars + 1)
            return (cut and s:sub(1, cut - 1) or s:sub(1, pt.previewChars)) .. "…"
        end
        return s:sub(1, pt.previewChars) .. "…"
    end

    function pt.changeCase()
        if not pt.caseList() then
            note("case.list has no provider — is modules/text_case.lua loaded?")
            hs.alert.show("🔠 The Text Case module is not loaded, so there\n"
                .. "are no cases to choose from. ⇪⇧D lists module status.", 5)
            return false
        end
        return pt.withSelection("🔠", function(text)
            pt.showCases(text)
        end)
    end

    function pt.showCases(text)
        local list = pt.caseList() or {}
        local choices = {}
        for _, c in ipairs(list) do
            local out
            local ok, res = pcall(function()
                return _G.service.call("case.apply", c.id, text)
            end)
            if ok and type(res) == "string" then out = res end
            choices[#choices + 1] = {
                text    = c.label,
                -- 🚨 THE PREVIEW IS OF YOUR TEXT, not of a sample. See the
                -- header: camel, kebab and snake drop punctuation, and the
                -- only warning that means anything is seeing it happen to
                -- the paragraph you actually highlighted.
                subText = out and pt.preview(out)
                              or  "⚠️ this case could not be applied",
                id      = c.id,
                ok      = out ~= nil,
            }
        end
        if not pt.caseChooser then
            pt.caseChooser = hs.chooser.new(function(pick)
                if not (pick and pick.ok) then return end
                pt.applyCase(pick.id, pt.caseText)
            end)
            _G.choosers = _G.choosers or {}
            _G.choosers.powerCase = pt.caseChooser
            pcall(function()
                pt.caseChooser:searchSubText(false)
                pt.caseChooser:width(42)
            end)
        end
        -- Held on pt rather than closed over, so a second ⇪; while the
        -- first picker is open cannot type the FIRST selection's text.
        pt.caseText = text
        pt.caseChooser:choices(choices)
        pt.caseChooser:placeholderText(
            ("%d characters selected — pick a case"):format(#text))
        pt.caseChooser:query("")
        if core.showPopup then core.showPopup(pt.caseChooser)
        else pt.caseChooser:show() end
        return true
    end

    -- =====================================================================
    -- ⌨️ REPLACE THE SELECTION — the guarded chain, in ONE place (6.133.0)
    -- =====================================================================
    -- 🚨 THE SAME THREE GUARDS typeClipboard needs, for the same reasons.
    -- Extracted from applyCase the moment a SECOND tool wanted to write
    -- over your selection: ⇪8 replaces a word with its synonym, and a
    -- second copy of "check secure input, wait for the modifiers, cap the
    -- length" is a second place for one of those three to be forgotten.
    -- The one that would be forgotten is the secure-input check, because
    -- it is the only one whose absence is INVISIBLE — nothing arrives, no
    -- error is raised, and the field simply stays as it was.
    --
    -- Published as power.replaceSelection so any module can use it without
    -- reaching into this one. `icon` and `what` only shape the messages;
    -- the refusals have to name the tool you actually pressed.
    function pt.typeOver(text, icon, what)
        icon, what = icon or "⌨️", what or "text"
        if type(text) ~= "string" or text == "" then
            note("nothing to type over the selection (" .. what .. ")")
            return false
        end
        if #text > pt.typeMax then
            note(what .. " too long to type (" .. #text .. " characters)")
            hs.alert.show(("%s %d characters is too much to type back — the\n"
                .. "cap is %d. Nothing was changed.")
                :format(icon, #text, pt.typeMax), 5)
            return false
        end
        local okSec, secure = pcall(hs.eventtap.isSecureInputEnabled)
        if okSec and secure then
            note("secure input is on — " .. what .. " cannot be typed back")
            hs.alert.show(icon .. " Secure input is ON — macOS blocks synthetic\n"
                .. "keystrokes. Your selection is untouched.", 5)
            return false
        end
        pt.startTimer = hs.timer.doAfter(pt.typeDelay, function()
            pt.startTimer = nil
            pt.whenClear(function(clear)
                if not clear then
                    note("modifiers never came up — refused to type " .. what)
                    hs.alert.show(icon .. " ⌘⇧⌃⌥ still held — nothing typed", 3)
                    return
                end
                say(("%s: %d characters typed back"):format(what, #text))
                pt.postText(text)
            end)
        end)
        return true
    end

    -- ⚠️ AND ONE GUARD THAT IS THIS TOOL'S ALONE: an unchanged result is
    -- not typed at all. Retyping a paragraph that is already lowercase
    -- replaces it with an identical paragraph, which is invisible unless
    -- the app's undo stack matters to you — and it always does. That test
    -- cannot move into typeOver, because ⇪8 replacing a word with a
    -- synonym has no "unchanged" to compare against.
    function pt.applyCase(id, text)
        if type(text) ~= "string" or text == "" then
            note("no text held for the case picker")
            return false
        end
        local ok, out = pcall(function()
            return _G.service.call("case.apply", id, text)
        end)
        if not (ok and type(out) == "string") then
            note("case.apply(" .. tostring(id) .. ") gave nothing back")
            hs.alert.show("🔠 That case could not be applied — see the Console", 4)
            return false
        end
        if out == text then
            hs.alert.show("🔠 Already " .. tostring(id) .. " — nothing typed", 3)
            return false
        end
        return pt.typeOver(out, "🔠", "case " .. tostring(id))
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
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(pt.metaChooser)
        else pt.metaChooser:show() end
    end

    -- =====================================================================
    -- ⏸ PAUSE ALL AUDIO AND VIDEO
    -- =====================================================================
    -- LL: "Can you create a key that will pause all audio and video?"
    --
    -- 🚨 READ THIS BEFORE BELIEVING THE NAME. macOS has no "pause
    -- everything" call, and there is no API that enumerates what is
    -- making sound. What exists is:
    --
    --   1. THE MEDIA KEY. Posting NX_KEYTYPE_PLAY is exactly what the ⏯
    --      key on the keyboard does, and macOS routes it to ONE app —
    --      whichever it currently considers "now playing". That is the
    --      only mechanism that reaches a browser tab, and it reaches
    --      exactly one of them.
    --   2. NAMED APPS. A scriptable player can be told to pause by name.
    --      That covers the desktop players and nothing else.
    --
    -- So this posts the media key AND tells every player in pt.players
    -- that is ALREADY RUNNING to pause. Between them that is everything
    -- on a normal Mac except a second browser tab playing under the
    -- first — and the alert says how many were told, so you can see
    -- when something was missed rather than wondering.
    --
    -- ⚠️ IT ONLY TALKS TO APPS THAT ARE ALREADY RUNNING, and that is not
    -- politeness. Naming an application in AppleScript LAUNCHES it, so a
    -- naive "tell application Music to pause" on a Mac with Music closed
    -- opens Music. A pause key that starts a music player is worse than
    -- no pause key.
    --
    -- 🚨 AND THE osascript RUNS IN A CHILD PROCESS, for the reason
    -- universal_actions documents at length: an AppleScript error raised
    -- inside Hammerspoon's own Apple Event handler is an Objective-C
    -- exception, which unwinds straight past pcall and takes the whole
    -- app down. A child process can only take itself down.
    pt.pauseScript = [[
on run argv
    set toldCount to 0
    tell application "System Events"
        set runningNames to name of every process
    end tell
    repeat with n in argv
        if runningNames contains (n as text) then
            try
                tell application (n as text) to pause
                set toldCount to toldCount + 1
            on error
                try
                    tell application (n as text) to playpause
                    set toldCount to toldCount + 1
                end try
            end try
        end if
    end repeat
    return toldCount
end run]]

    -- =================================================================
    -- ⏸ VLC, WHICH SPEAKS A DIFFERENT LANGUAGE
    -- =================================================================
    -- LL: "⇪' does not pause VLC."
    --
    -- 🚨 THE SCRIPT ABOVE REACHED VLC AND SAID TWO THINGS IT DOES NOT
    -- UNDERSTAND. VLC's dictionary has no `pause` and no `playpause`. Both
    -- branches of that try/on error raised errAEEventNotHandled, the inner
    -- `try` swallowed the second one without a word, and VLC played on.
    -- toldCount did not move either, so the count in the alert has been
    -- quietly one short whenever VLC was running.
    --
    -- ⚠️ AND THE OBVIOUS FIX STARTS PLAYBACK. VLC's toggle is spelled
    -- `play`, and `play` sent to a PAUSED VLC begins playing it. A pause
    -- key that starts a film is the same failure as a pause key that opens
    -- Music — worse, because you meant to silence the machine. So this
    -- reads the `playing` property first and sends nothing when it is
    -- false.
    --
    -- 🚨 AND IT IS A SEPARATE SCRIPT FOR A REASON THAT IS NOT TIDINESS.
    -- `playing` and `play` are VLC's OWN terminology, and AppleScript can
    -- only resolve an app's terminology when the app is named as a
    -- LITERAL — `tell application (n as text)` inside the generic loop
    -- resolves nothing at compile time. Naming VLC literally means this
    -- text is compiled against VLC's dictionary, so it must not be part of
    -- the script every player depends on: on a Mac with no VLC installed,
    -- a compile failure here would take the whole pause key down with it.
    -- In its own child process it can only take itself down, and it is
    -- only ever launched when VLC is already running.
    --
    -- ⚠️ THE RUNNING CHECK IS MADE TWICE, AND BOTH ARE LOAD-BEARING.
    -- Hammerspoon checks before launching osascript at all; the script
    -- checks again on the inside, because VLC can quit in the gap between
    -- the two, and `tell application "VLC"` on a departed VLC RELAUNCHES
    -- IT. The whole point of this key is that it never starts anything.
    pt.vlcPauseScript = [[
tell application "System Events"
    if not (exists process "VLC") then return "absent"
end tell
tell application "VLC"
    if playing then
        play
        return "paused"
    else
        return "already"
    end if
end tell]]

    -- 🚨 THE NAME → SCRIPT MAP IS WHAT MAKES pt.toggleOnly SAFE TO EDIT.
    -- A name listed in pt.toggleOnly is held back from the generic script,
    -- so if nothing here can say it, it is told NOTHING — the pause key
    -- would go quiet for that player and the alert would not notice. Both
    -- sides read this table, so a name without a script simply stays in
    -- the generic script where it was.
    pt.toggleScripts = { VLC = pt.vlcPauseScript }

    -- Runs the toggle-only players and calls done(summary) with a short
    -- phrase for the alert, or nil when there was nothing to say.
    function pt.pauseToggleOnly(done)
        -- 🚨 ASKED OF HAMMERSPOON, NOT OF APPLESCRIPT. hs.application
        -- does not launch anything to answer "is it running";
        -- AppleScript would have to name the app to ask, and naming it
        -- launches it.
        --
        -- 🚨 6.137.0 — AND ASKED BY BULK SWEEP, NOT BY NAME. This used to
        -- be hs.application.get(n) per player, which on macOS 27 costs
        -- ~3,000ms per name that is NOT running (the same name-resolution
        -- freeze focus_mode paid every 4 seconds, measured on LL's Mac) —
        -- so the pause key hung for seconds precisely when no player was
        -- open. One runningApplications() enumeration (5ms for 128 apps,
        -- measured) plus a pure-Lua name match — app_watcher's 6.16.22
        -- idiom. If the enumeration itself fails, every player reads as
        -- not running and the key falls through to its other duties;
        -- wrong-but-instant beats right-but-frozen on a keypress.
        local sweep = {}
        pcall(function()
            for _, a in ipairs(hs.application.runningApplications() or {}) do
                local okN, n2 = pcall(function() return a:name() end)
                if okN and n2 then sweep[n2] = true end
            end
        end)
        local name, script, extras = nil, nil, 0
        for _, n in ipairs(pt.toggleOnly or {}) do
            local s = (pt.toggleScripts or {})[n]
            if s and sweep[n] then
                if name then extras = extras + 1 else name, script = n, s end
            end
        end
        -- A tripwire for a future second entry, not a thing that happens
        -- today: one keypress gets one alert, so only the first running
        -- toggle-only player is carried into it.
        if extras > 0 then
            warn(extras .. " other toggle-only player(s) went untold —"
                 .. " pt.pauseToggleOnly carries one per keypress")
        end
        if not name then return done(nil) end

        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(_, out2, _)
                pt.vlcTask = nil
                local r = tostring(out2 or ""):gsub("%s+$", "")
                pt.lastVLC = r
                if r == "paused" then
                    done(name .. " paused")
                elseif r == "already" then
                    -- Said out loud rather than folded into the count. The
                    -- machine is quiet either way, and "already" is the
                    -- answer to "why did the number not go up".
                    done(name .. " was already paused")
                elseif r == "absent" then
                    done(nil)
                else
                    warn(name .. " did not answer the pause script: " .. r)
                    done(name .. " did not answer")
                end
            end, { "-e", pt.vlcPauseScript })
        end)
        if not (okNew and t) then
            note("could not start osascript for " .. name)
            return done(nil)
        end
        pt.vlcTask = t
        pcall(function() t:start() end)
    end

    function pt.pauseAll()
        -- The media key first, because it is instant and it is the only
        -- thing that reaches a browser.
        local okKey = pcall(function()
            local e = hs.eventtap.event
            e.newSystemKeyEvent("PLAY", true):post()
            e.newSystemKeyEvent("PLAY", false):post()
        end)
        if not okKey then
            note("could not post the media key")
        end

        -- 🚨 THE TOGGLE-ONLY PLAYERS ARE HELD BACK FROM THIS SCRIPT. Every
        -- name passed here is sent `pause` and then `playpause`, and for
        -- VLC both of those are Apple Events it cannot handle — two round
        -- trips whose only possible outcome is a swallowed error. They are
        -- handled by pt.pauseToggleOnly instead, which knows their verb.
        local skip = {}
        for _, n in ipairs(pt.toggleOnly or {}) do
            if (pt.toggleScripts or {})[n] then skip[n] = true end
        end
        local args = { "-e", pt.pauseScript }
        for _, n in ipairs(pt.players) do
            if not skip[n] then args[#args + 1] = n end
        end
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(_, out2, _)
                pt.pauseTask = nil
                local told = tonumber((tostring(out2 or ""):match("(%d+)"))) or 0
                pt.lastPaused = told
                -- ⚠️ THE ALERT WAITS FOR VLC. Showing "2 players told" and
                -- then a second pill a moment later reads as two events
                -- when it was one keypress, so the summary is assembled
                -- once both halves have answered.
                pt.pauseToggleOnly(function(extra)
                    local msg
                    if told > 0 then
                        msg = "⏸ Paused — media key sent, and " .. told
                              .. " player" .. (told == 1 and "" or "s")
                              .. " told by name"
                    elseif extra then
                        msg = "⏸ Paused — media key sent"
                    else
                        msg = "⏸ Media key sent — no scriptable player was running"
                    end
                    if extra then msg = msg .. " · " .. extra end
                    say("media key posted, " .. told .. " player(s) told to pause"
                        .. (extra and (" · " .. extra) or ""))
                    hs.alert.show(msg, 3)
                end)
            end, args)
        end)
        if not (okNew and t) then
            note("could not start osascript — media key only")
            hs.alert.show("⏸ Media key sent (no scriptable players reached)", 2.5)
            return true
        end
        pt.pauseTask = t
        pcall(function() t:start() end)
        return true
    end

    -- =====================================================================
    -- 👻 GHOSTTY ↔ FINDER
    -- =====================================================================
    -- LL: "Can we open a Ghostty terminal from current Finder folder; and
    -- open current Ghostty terminal path in Finder?"
    --
    -- The first direction is easy and reliable: Finder knows its front
    -- window's folder and says so, and Ghostty takes --working-directory.
    --
    -- 🚨 THE SECOND DIRECTION IS THE HARD ONE, AND IT IS WORTH SAYING WHY.
    -- A terminal's "current directory" belongs to the SHELL, not the
    -- terminal — Ghostty is a window around a process whose cwd changes
    -- every time you type cd, and it publishes that nowhere a neighbouring
    -- process can simply read. Two routes are tried, in order:
    --
    --   1. THE WINDOW TITLE. Ghostty sets it from OSC 7 / OSC 2, which
    --      for a normal shell prompt is the working directory — often
    --      abbreviated with ~. Free, instant, and correct whenever the
    --      shell is at a prompt rather than running something that
    --      renamed the title (vim, ssh, a long build).
    --   2. lsof ON THE SHELL. When the title is not a path, the child
    --      processes of Ghostty are asked for their cwd directly. This
    --      is the truth, and it costs a process launch.
    --
    -- ⚠️ WITH SEVERAL GHOSTTY WINDOWS OPEN, ROUTE 2 CANNOT TELL THEM
    -- APART. There is no mapping from a window to the pid drawing it that
    -- Hammerspoon can read, so it takes the most recently started shell.
    -- Route 1 has no such problem — it reads the FRONT window's own title
    -- — which is the reason it is tried first rather than being the
    -- fallback. When route 2 is used the alert says so.
    local FINDER_DIR = [[
tell application "Finder"
    try
        return POSIX path of (target of front Finder window as alias)
    on error
        return POSIX path of (path to desktop folder)
    end try
end tell]]

    function pt.ghosttyHere()
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(_, out2, _)
                pt.ghostTask = nil
                local dir = tostring(out2 or ""):match("^%s*(.-)%s*$")
                if dir == "" then
                    note("Finder named no folder")
                    hs.alert.show("👻 Finder has no front window", 3)
                    return
                end
                local ok = pcall(function()
                    hs.task.new("/usr/bin/open", nil, {
                        "-na", pt.ghosttyApp, "--args",
                        "--working-directory=" .. dir,
                    }):start()
                end)
                if ok then
                    pt.lastGhostty = dir
                    say("opened " .. pt.ghosttyApp .. " at " .. dir)
                    hs.alert.show("👻 " .. pt.ghosttyApp .. " — "
                        .. (dir:match("([^/]+)/?$") or dir), 2.5)
                else
                    note("could not launch " .. pt.ghosttyApp)
                    hs.alert.show("👻 Could not open " .. pt.ghosttyApp, 3)
                end
            end, { "-e", FINDER_DIR })
        end)
        if not (okNew and t) then
            note("could not start osascript — no Finder folder")
            hs.alert.show("👻 Could not ask Finder where it is", 3)
            return false
        end
        pt.ghostTask = t
        pcall(function() t:start() end)
        return true
    end

    -- A window title is a path when it starts with / or ~. Ghostty also
    -- writes titles like "~/code/thing — zsh", so the tail after an em
    -- dash or a colon is trimmed before the test. Anything else is not a
    -- path and must NOT be guessed at: revealing the wrong folder is
    -- worse than saying the title was not one.
    function pt.pathFromTitle(title)
        if type(title) ~= "string" then return nil end
        local s = title:match("^%s*(.-)%s*$")
        s = s:gsub("%s+[—–%-|:].*$", "")
        s = s:match("^%s*(.-)%s*$")
        if s == "" then return nil end
        if s:sub(1, 1) == "~" then
            local home = core.homeDir or os.getenv("HOME")
            if not home then return nil end
            s = home .. s:sub(2)
        end
        if s:sub(1, 1) ~= "/" then return nil end
        if hs.fs.attributes(s, "mode") ~= "directory" then return nil end
        return s
    end

    function pt.ghosttyTitle()
        local okApp, app = pcall(hs.application.frontmostApplication)
        if not (okApp and app) then return nil end
        local name
        pcall(function() name = app:name() end)
        if name ~= pt.ghosttyApp then return nil, "front app is " .. tostring(name) end
        local title
        pcall(function()
            local w = app:focusedWindow()
            if w then title = w:title() end
        end)
        return pt.pathFromTitle(title), title
    end

    function pt.revealGhostty()
        local dir, title = pt.ghosttyTitle()
        if dir then
            pt.lastReveal = dir
            pcall(function()
                hs.task.new("/usr/bin/open", nil, { dir }):start()
            end)
            hs.alert.show("👻 Finder — " .. (dir:match("([^/]+)/?$") or dir), 2.5)
            return true
        end
        -- Route 2: ask the shells themselves.
        local t
        local okNew = pcall(function()
            t = hs.task.new("/bin/sh", function(_, out2, _)
                pt.revealTask = nil
                local path = tostring(out2 or ""):match("^%s*(.-)%s*$")
                if path == "" or path:sub(1, 1) ~= "/" then
                    note("no shell under " .. pt.ghosttyApp .. " reported a cwd"
                         .. (title and (" (title was: " .. tostring(title) .. ")") or ""))
                    hs.alert.show("👻 Could not tell where " .. pt.ghosttyApp
                        .. " is.\nIts title is not a path and no shell answered.", 4)
                    return
                end
                pt.lastReveal = path
                say("revealed " .. path .. " (via lsof)")
                pcall(function()
                    hs.task.new("/usr/bin/open", nil, { path }):start()
                end)
                hs.alert.show("👻 Finder — " .. (path:match("([^/]+)/?$") or path)
                    .. "\n(from the shell, not the window title)", 3)
            end, { "-c",
                -- The newest descendant of Ghostty that has a cwd. See the
                -- header: with several windows open this cannot tell which
                -- one is in front, and the alert says as much.
                "pgrep -P \"$(pgrep -n -x " .. pt.ghosttyApp .. ")\" 2>/dev/null"
                .. " | tail -1 | xargs -I{} lsof -a -d cwd -p {} -Fn 2>/dev/null"
                .. " | sed -n 's/^n//p' | tail -1" })
        end)
        if not (okNew and t) then
            note("could not start the cwd lookup")
            hs.alert.show("👻 Could not tell where " .. pt.ghosttyApp .. " is", 3)
            return false
        end
        pt.revealTask = t
        pcall(function() t:start() end)
        return true
    end

    -- =====================================================================
    -- 🔳 READ A QR CODE OFF THE SCREEN
    -- =====================================================================
    -- LL: "How about an on screen QR reader?"
    --
    -- It scans the WHOLE screen rather than asking you to drag a box
    -- around the code, and that is the better shape for this: zbar finds
    -- a code anywhere in the image, so a region selection is a step that
    -- buys nothing and costs you a drag. Press the key, the payload is on
    -- the clipboard.
    --
    -- 🚨 IT NEEDS zbarimg, WHICH macOS DOES NOT SHIP. There is no QR
    -- decoder in any Apple framework Hammerspoon can reach — Vision has
    -- one, and Hammerspoon exposes no binding to it. `brew install zbar`
    -- and this works; without it the refusal says exactly that rather
    -- than failing as if the code were unreadable.
    --
    -- 📍 WHERE THE PATH COMES FROM. modules/screenshots.lua already hunts
    -- for zbarimg across five install locations, including the two
    -- no-admin Homebrew prefixes this config supports. It publishes that
    -- as a service and this asks for it by name, because a second copy of
    -- the list is a list that drifts.
    function pt.zbarPath()
        if not (_G.service and _G.service.has
                and _G.service.has("shots.zbarPath")) then
            return nil, "the screenshots module is not loaded on this Mac"
        end
        local ok, p = pcall(function() return _G.service.call("shots.zbarPath") end)
        if ok and type(p) == "string" and p ~= "" then return p end
        return nil, "zbarimg is not installed — brew install zbar"
    end

    function pt.readQR()
        local zbar, why = pt.zbarPath()
        if not zbar then
            note("no QR decoder: " .. tostring(why))
            hs.alert.show("🔳 No QR decoder — " .. tostring(why), 5)
            return false
        end
        local shot = os.tmpname() .. ".png"
        local cap
        local okCap = pcall(function()
            -- -x silences the shutter, -r keeps it raw (no shadow or
            -- window dressing to confuse the decoder).
            cap = hs.task.new("/usr/sbin/screencapture", function(code)
                pt.qrCapTask = nil
                if code ~= 0 then
                    note("screencapture exited " .. tostring(code))
                    hs.alert.show("🔳 Could not capture the screen", 3)
                    return
                end
                pt.decodeQR(zbar, shot)
            end, { "-x", "-r", shot })
        end)
        if not (okCap and cap) then
            note("could not run screencapture")
            hs.alert.show("🔳 Could not capture the screen", 3)
            return false
        end
        pt.qrCapTask = cap
        pcall(function() cap:start() end)
        return true
    end

    function pt.decodeQR(zbar, shot)
        local t
        local okNew = pcall(function()
            t = hs.task.new(zbar, function(_, out2, _)
                pt.qrTask = nil
                pcall(os.remove, shot)
                -- zbarimg prints "QR-Code:<payload>", one per code found.
                local payloads = {}
                for line in tostring(out2 or ""):gmatch("[^\n]+") do
                    local body = line:match("^[%w%-]+:(.*)$")
                    if body and body ~= "" then payloads[#payloads + 1] = body end
                end
                if #payloads == 0 then
                    note("no code found on screen")
                    hs.alert.show("🔳 No QR code on this screen", 2.5)
                    return
                end
                local text = table.concat(payloads, "\n")
                pt.lastQR = text
                pcall(function() hs.pasteboard.setContents(text) end)
                say("decoded " .. #payloads .. " code(s)")
                local shown = text:gsub("\n", " · ")
                if #shown > 90 then shown = shown:sub(1, 89) .. "…" end
                hs.alert.show("🔳 Copied — " .. shown, 5)
            end, { "-q", "--raw", shot })
        end)
        if not (okNew and t) then
            pcall(os.remove, shot)
            note("could not run zbarimg")
            hs.alert.show("🔳 Could not run the QR decoder", 3)
            return
        end
        pt.qrTask = t
        pcall(function() t:start() end)
        pt.qrTimer = hs.timer.doAfter(pt.qrTimeout, function()
            pt.qrTimer = nil
            if pt.qrTask == t then
                pcall(function() t:terminate() end)
                pt.qrTask = nil
                pcall(os.remove, shot)
                note("zbarimg did not answer in " .. pt.qrTimeout .. "s")
                hs.alert.show("🔳 The QR decoder did not answer", 3)
            end
        end)
    end

    -- =====================================================================
    -- ⏸ PAUSE HAMMERSPOON (6.152.0) — see the note at pt.hsPauseKey
    -- =====================================================================
    function pt.hsPauseToggle()
        _G.hsPaused = not _G.hsPaused
        if _G.hsPaused then
            pcall(function()
                if pt.hsPauseMenu then pt.hsPauseMenu:delete() end
                pt.hsPauseMenu = hs.menubar.new()
                if pt.hsPauseMenu then
                    pt.hsPauseMenu:setTitle("⏸ HS")
                    pt.hsPauseMenu:setTooltip("Hammerspoon is paused — "
                        .. tostring(_G.hsPauseHint) .. " (or this click) resumes")
                    pt.hsPauseMenu:setClickCallback(function() pt.hsPauseToggle() end)
                end
            end)
            pcall(function()
                hs.alert.show("⏸ Hammerspoon paused\n⇪ shortcuts and typing "
                    .. "helpers are off — " .. tostring(_G.hsPauseHint)
                    .. " resumes", 4)
            end)
            say("paused — every hyper shortcut but the pause key is quiet")
        else
            pcall(function()
                if pt.hsPauseMenu then pt.hsPauseMenu:delete() end
                pt.hsPauseMenu = nil
            end)
            pcall(function() hs.alert.show("▶️ Hammerspoon back on", 2.5) end)
            say("resumed")
        end
        return _G.hsPaused
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
        -- 6.132.0 — the second count row. It shows the same numbers AND
        -- copies two of them; the row above never touches your clipboard.
        { id = "countclip", icon = "📋", title = "Count the selection → clipboard",
          sub = "The same numbers, and “N words · N characters” copied",
          run = function() return pt.countSelection(true) end },
        { id = "case",  icon = "🔠", title = "Change the case of the selection",
          sub = "UPPER · lower · Title · camel · kebab · snake, previewed first",
          run = function() return pt.changeCase() end },
        -- 6.133.0 — ⇪8 has its own key; the row is here because ⇪; is
        -- where you look when the key has not stuck yet.
        { id = "define", icon = "📖", title = "Define the selection",
          sub = "Meaning and synonyms together — ⏎ swaps the word · ⇪8",
          run = function()
              if not (_G.service and _G.service.has
                      and _G.service.has("define.selection")) then
                  note("define.selection has no provider")
                  hs.alert.show("📖 The Define module is not loaded.\n"
                      .. "⇪⇧D lists module status.", 4)
                  return false
              end
              return _G.service.call("define.selection") and true or false
          end },
        { id = "meta",  icon = "ℹ️", title = "File metadata",
          sub = "Every mdls attribute of the Finder selection — ⏎ copies one",
          run = function() return pt.fileMetadata() end },
        -- 6.120.0 — the four with a key of their own. They are listed here
        -- as well because ⇪; is the place you look when the key has not
        -- stuck yet, and because ⇪⇧/ lists this module's rows.
        { id = "pause", icon = "⏸", title = "Pause all audio and video",
          sub = "Media key + every scriptable player that is running · ⇪'",
          run = function() return pt.pauseAll() end },
        -- 6.152.0 — the OTHER pause: Hammerspoon itself.
        { id = "hspause", icon = "⏸", title = "Pause Hammerspoon",
          sub = "⇪ shortcuts + typing helpers off until pressed again · ⇪⇧1",
          run = function() return pt.hsPauseToggle() end },
        { id = "ghere", icon = "👻", title = "Ghostty here",
          sub = "Open Ghostty at the front Finder window's folder · ⇪`",
          run = function() return pt.ghosttyHere() end },
        { id = "greveal", icon = "📂", title = "Reveal Ghostty's folder",
          sub = "Open Finder where the front Ghostty window is · ⇪⇧`",
          run = function() return pt.revealGhostty() end },
        { id = "qr",    icon = "🔳", title = "Read a QR code on screen",
          sub = "Scans the whole screen, payload to the clipboard · ⇪5",
          run = function() return pt.readQR() end },
        -- 6.139.0 — the rebuild kit's two by-hand doors. Rows rather than
        -- keys, deliberately: a backup is run by hand twice a year, and
        -- that does not earn a ⇪ letter. The daily 5 PM run needs no door
        -- at all.
        { id = "backup", icon = "☁️", title = "Back up now — the rebuild kit",
          sub = "Config, dotfiles, Brewfile, app manifest → OneDrive",
          run = function()
              if not (_G.service and _G.service.has
                      and _G.service.has("backup.now")) then
                  note("backup.now has no provider")
                  hs.alert.show("☁️ The Daily Backup module is not loaded.\n"
                      .. "⇪⇧D lists module status.", 4)
                  return false
              end
              return _G.service.call("backup.now") and true or false
          end },
        { id = "backupreport", icon = "🧾", title = "Backup report",
          sub = "Destination, last run, what was skipped and why",
          run = function()
              if not (_G.service and _G.service.has
                      and _G.service.has("backup.report")) then
                  note("backup.report has no provider")
                  hs.alert.show("☁️ The Daily Backup module is not loaded.\n"
                      .. "⇪⇧D lists module status.", 4)
                  return false
              end
              local ok = _G.service.call("backup.report") and true or false
              if ok then
                  hs.alert.show("☁️ Report is in the Hammerspoon Console", 2)
              end
              return ok
          end },
        -- 6.140.0 — grayscale, at last. These rows hold no logic of their
        -- own: screen_veil.lua owns the relay and the reason it works
        -- where 6.82.0's four attempts did not. 6.140.0 shipped them
        -- keyless (every ⇪ letter was taken); 6.141.0 gave the toggle
        -- ⇪9 at LL's ask, and the sentry refused ⇪⇧9 for invert — it
        -- was the numpad laptop row's key. 6.142.0: LL cleared that
        -- whole row, so invert has ⇪⇧9 after all, exactly as picked.
        -- 🪦 6.145.0 — the setup row is gone with the setup door itself,
        -- at LL's word: the one-time tick was made by hand, and the
        -- native triple-press of Touch ID covers the walk to the pane.
        { id = "mono",  icon = "🌑", title = "Grayscale on/off",
          sub = "Relays ⌥⌘F5, the macOS switch · ⇪9 · native: triple-press Touch ID",
          run = function() return pt.veilCall("mono") end },
        { id = "invert", icon = "🔄", title = "Invert the screen colours",
          sub = "Relays ⌃⌥⌘8. Inversion, NOT grayscale — no setup · ⇪⇧9",
          run = function() return pt.veilCall("invert") end },
        -- 🆓 6.142.0 — the list LL asked for, as a tool rather than a
        -- document: "the keys listed as future possible options for
        -- keyboard shortcuts". _G.freeKeys() owns the logic below.
        { id = "freekeys", icon = "🆓", title = "Free keys — future shortcut options",
          sub = "Every unclaimed ⇪ / ⇪⇧ / pad key, read from the LIVE registry",
          run = function() return _G.freeKeys() ~= nil end },
        -- 📎 6.147.0 — LL, the day after 6.146.0 shipped it keyless:
        -- "The tool to set default apps is buried". The @tool row stays
        -- (it is still the searchable front door), but ⇪; is where the
        -- act-now tools live, so it earns a row here too — same guarded
        -- service-call shape as the backup and veil rows above.
        { id = "defaultapp", icon = "📎", title = "Default app for a file type",
          sub = "Pick a type, pick the app — LaunchServices read back as proof",
          run = function()
              if not (_G.service and _G.service.has
                      and _G.service.has("defaultApps.show")) then
                  note("defaultApps.show has no provider")
                  hs.alert.show("📎 The Default Apps module is not loaded.\n"
                      .. "⇪⇧D lists module status.", 4)
                  return false
              end
              return _G.service.call("defaultApps.show") and true or false
          end },
    }

    -- 6.140.0 — the guard the grayscale rows share (three rows then, two
    -- since 6.145.0 retired setup). The backup rows above spell the same
    -- guard out inline. Everything goes through the service registry, so
    -- the rows work when Screen Veil is loaded and say so when it is not.
    function pt.veilCall(what)
        local svc = "veil." .. what
        if not (_G.service and _G.service.has and _G.service.has(svc)) then
            note(svc .. " has no provider")
            hs.alert.show("🌑 The Screen Veil module is not loaded.\n"
                .. "⇪⇧D lists module status.", 4)
            return false
        end
        return _G.service.call(svc) and true or false
    end

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
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(pt.chooser)
        else pt.chooser:show() end
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
        local cases = pt.caseList()
        L[#L + 1] = "   case engine  : " ..
            (cases and (#cases .. " cases from modules/text_case.lua")
                   or  "MISSING — 🔠 will refuse; is text_case loaded?")
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
        if pt.lastCountLine then
            L[#L + 1] = "   last copied  : " .. pt.lastCountLine
        end
        if pt.lastNote then L[#L + 1] = "   last problem : " .. pt.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- =====================================================================
    -- _G.freeKeys() — THE KEYS LISTED AS FUTURE POSSIBLE OPTIONS (6.142.0)
    -- =====================================================================
    -- LL: "These shortcuts were supposed to be cleaned, cleared and the
    -- keys listed as future possible options for keyboard shortcuts."
    -- Every earlier attempt at that list was a careful read of the source
    -- — and 6.141.0 showed what a careful read is worth: ⇪⇧9 LOOKED free
    -- in a survey of documented keys because the numpad laptop row built
    -- its claims in a LOOP, so no literal "⇪⇧9" existed to find. This
    -- list is therefore not written, it is READ — from _G.hyperBound, the
    -- registry every binding fills at boot and the conflict sentry trusts.
    --
    -- WHAT "FREE" MEANS HERE, exactly:
    --   · a plain ⇪ key whose registry source is "chord" is FREE —
    --     hyperFinalize gives every leftover bare key a raw ⌘⇧⌃⌥ forward,
    --     so claiming one costs only that forward.
    --   · a ⇪⇧ combination is FREE when nothing claims it at all —
    --     shifted keys are never chord-forwarded.
    --   · ⇪⇧Z is NEVER listed. LL: "don't use ⇪⇧Z please. We will use
    --     that later." Reserved is not free, and the report says which.
    --   · a pad key this Mac has no key code for is named, not listed —
    --     a key that cannot be pressed is not an option (the ⇪pad+ rule;
    --     _G.padProbe() has the full story).
    function _G.freeKeys()
        local bound = _G.hyperBound or {}
        local function ownerOf(mods, key)
            return bound[(mods == "") and key or (mods .. "+" .. key)]
        end
        local names = {}
        for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
            names[#names + 1] = c
        end
        for d = 0, 9 do names[#names + 1] = tostring(d) end
        for _, k in ipairs({ "-", "=", "[", "]", "\\", ";", "'", ",", ".",
                             "/", "`", "space", "tab", "return",
                             "left", "right", "up", "down" }) do
            names[#names + 1] = k
        end
        local freePlain, freeShift = {}, {}
        for _, k in ipairs(names) do
            local plain = ownerOf("", k)
            if plain == nil or plain == "chord" then
                freePlain[#freePlain + 1] = k
            end
            if ownerOf("shift", k) == nil and k ~= "z" then
                freeShift[#freeShift + 1] = k
            end
        end
        local padNames = { "pad0","pad1","pad2","pad3","pad4","pad5","pad6",
                           "pad7","pad8","pad9","pad.","pad+","pad-","pad*",
                           "pad/","pad=","padenter","padclear" }
        local map = hs.keycodes and hs.keycodes.map
        local padFree, padShiftFree, padDead = {}, {}, {}
        for _, n in ipairs(padNames) do
            if map and map[n] == nil then
                padDead[#padDead + 1] = n
            else
                if ownerOf("", n) == nil then
                    padFree[#padFree + 1] = n
                end
                if ownerOf("shift", n) == nil then
                    padShiftFree[#padShiftFree + 1] = n
                end
            end
        end
        -- ⌘⇧pad is the one layer the hyper registry cannot answer for: it
        -- binds through hs.hotkey, not the modal. Its table is the truth.
        local cmdShiftPad = "unknown — numpad_layer is not loaded"
        local nl = _G.numpadLayer
        if nl and type(nl.cmdShiftActions) == "table" then
            local claimed = {}
            for k in pairs(nl.cmdShiftActions) do claimed[#claimed + 1] = k end
            table.sort(claimed)
            cmdShiftPad = (#claimed == 0)
                and "ALL free — and a real macOS modifier, usable outside ⇪"
                or ("all free EXCEPT " .. table.concat(claimed, " "))
        end
        local function joined(list)
            return (#list == 0) and "none — every one is claimed"
                   or table.concat(list, " ")
        end
        local out = {
            "════════════════════════════════════════════════════════",
            " FREE KEYS — future shortcut options   " .. os.date("%Y-%m-%d %H:%M"),
            " Read from the LIVE hyper registry, not from any list a",
            " person maintains. If a key is here, nothing claims it.",
            "════════════════════════════════════════════════════════",
            "   ⇪    " .. joined(freePlain),
            "   ⇪⇧   " .. joined(freeShift),
            "   🔒 NOT listed and NOT free: ⇪⇧Z is reserved —",
            "      LL: \"don't use ⇪⇧Z please. We will use that later.\"",
            "   ⇪ pad   " .. joined(padFree),
            "   ⇪⇧ pad  " .. joined(padShiftFree),
            "   ⌘⇧ pad  " .. cmdShiftPad,
        }
        if #padDead > 0 then
            out[#out + 1] = "   ⚠️ no key code on this Mac (not options): "
                            .. table.concat(padDead, " ")
        end
        out[#out + 1] = ""
        out[#out + 1] = "   ℹ️ A free plain ⇪ key currently forwards the raw"
        out[#out + 1] = "      ⌘⇧⌃⌥ chord; claiming it costs only that forward."
        out[#out + 1] = "      Shifted combinations do nothing at all today."
        out[#out + 1] = "════════════════════════════════════════════════════════"
        local text = table.concat(out, "\n")
        print(text)
        pcall(function() hs.pasteboard.setContents(text) end)
        hs.alert.show("🆓 Free keys copied — the list is in the Console too", 3)
        return text
    end

    if pt.enabled then
        core.hyperAddShortcut(pt.keyMods, pt.key, function() pt.show() end,
                              "power tools")
        -- 6.120.0 — four of the rows also get a key of their own, because
        -- these are the ones you press mid-something rather than go
        -- looking for. ⇪; still lists them.
        core.hyperAddShortcut(pt.pauseMods,   pt.pauseKey,
                              function() pt.run("pause") end, "pause all media")
        core.hyperAddShortcut(pt.ghosttyMods, pt.ghosttyKey,
                              function() pt.run("ghere") end, "ghostty here")
        core.hyperAddShortcut(pt.revealMods,  pt.ghosttyKey,
                              function() pt.run("greveal") end, "reveal ghostty")
        core.hyperAddShortcut(pt.qrMods,      pt.qrKey,
                              function() pt.run("qr") end, "read a QR code")
        -- ⏸ 6.152.0 — the pause switch. Its normalized combo is published
        -- BEFORE binding so init.lua's hyperPauseWrap can recognise "this
        -- is the one key that still works while paused". The combo string
        -- must match hyperCombo's spelling: sorted mods + "+" + key.
        do
            local ms = {}
            for _, m in ipairs(pt.hsPauseMods) do ms[#ms + 1] = tostring(m):lower() end
            table.sort(ms)
            _G.hsPauseCombo = (#ms == 0) and tostring(pt.hsPauseKey):lower()
                or (table.concat(ms, "+") .. "+" .. tostring(pt.hsPauseKey):lower())
            _G.hsPauseHint = "⇪" .. (#ms > 0 and "⇧" or "") .. tostring(pt.hsPauseKey)
        end
        core.hyperAddShortcut(pt.hsPauseMods, pt.hsPauseKey,
                              function() pt.hsPauseToggle() end,
                              "pause Hammerspoon")
    end
    core.provide("power.show",     function() return pt.show() end)
    core.provide("power.plain",    function() return pt.run("plain") end)
    core.provide("power.type",     function() return pt.run("type")  end)
    core.provide("power.count",    function() return pt.run("count") end)
    core.provide("power.countClip", function() return pt.run("countclip") end)
    core.provide("power.case",     function() return pt.run("case") end)
    -- 6.133.0 — the guarded replace, for any module that needs to write
    -- over your selection. ⇪8 is the first caller; see pt.typeOver.
    core.provide("power.replaceSelection",
                 function(text, icon, what) return pt.typeOver(text, icon, what) end)
    -- …and the reader that goes with it, so a caller does not grow its own
    -- copy of "accessibility first, ⌘C second, refuse third" either.
    core.provide("power.readSelection",
                 function(label, done) return pt.withSelection(label, done) end)
    core.provide("power.metadata", function() return pt.run("meta")  end)
    core.provide("power.pause",    function() return pt.run("pause") end)
    core.provide("power.ghostty",  function() return pt.run("ghere") end)
    core.provide("power.reveal",   function() return pt.run("greveal") end)
    core.provide("power.qr",       function() return pt.run("qr") end)
    core.provide("power.report",   function() return _G.powerReport() end)
    core.provide("power.freeKeys", function() return pt.run("freekeys") end)

    _G.powerTools = pt
    M.pt     = pt
    M.config = pt
end

return M
