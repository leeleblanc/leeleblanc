-- =====================================================================
-- modules/anchors.lua — ⇪⇧U: link what is in front of you to a note
-- =====================================================================
-- LL: "I like Hookmark. Is there some kind of tool we can build out into
-- hammer-sidian?" Hookmark is one idea done well — link the thing you are
-- looking at to another thing, in both directions. The vault already had
-- half of it: [[wikilinks]] between notes, backlinks, ⌘K for a file. The
-- missing half is outward: the document, the tab, the message in front of
-- you RIGHT NOW, and a way back to the note about it.
--
-- ⇪⇧U works out what is in front, then either OPENS the note that already
-- links to it, or writes the link into one. That is the whole tool.
--
-- 📄 THE LINK IS PLAIN MARKDOWN, IN THE NOTE. Not a sidecar, not a
-- database, not an ID only this config understands:
--
--     ## Linked
--     - [Contract.docx](file:///Users/lee/OneDrive/Contract.docx)
--     - [Quarterly plan](https://app.asana.com/0/12/34)
--
-- Obsidian opens those links itself. That keeps the promise the vault was
-- built on (6.172.0, 6.177.0): the FOLDER is the database, and you can
-- walk away with it. Hookmark's own links live in Hookmark's database;
-- these live in your notes.
--
-- 🔎 AND THE REVERSE DIRECTION NEEDS NO STORE AT ALL. "Which notes
-- mention this document?" is a grep over the vault — /usr/bin/grep -rl in
-- a HELD hs.task, the same machinery the [[link]] index already uses.
-- Nothing to keep in sync, nothing to corrupt, nothing to migrate.
--
-- 🚚 MOVE SURVIVAL. A path breaks the moment a file is renamed or filed
-- somewhere else — the one thing a document link must survive, and the
-- reason Hookmark stores bookmarks rather than paths. When the vault
-- follows an anchor whose file has gone, it asks this module
-- (`anchors.resolve`, through the service registry) and this module asks
-- the file index that ⇪D already builds for the same NAME. The filename
-- is already in the link, so nothing extra is written to make this work.
--
-- 🛟 IT DEGRADES, IT NEVER BREAKS. No vault module → it says so and does
-- nothing else. No Accessibility → no document path, but the browser tab
-- and the app name still work. No file index → a moved file is reported
-- as moved instead of silently reopening the wrong thing. osascript slow
-- or refused → the timer kills it and the app name carries the anchor.
-- Every step is pcall'd; nothing here can cost you a keystroke.
--
-- 🔎 AND THE "PICK A NOTE" ROW ASKS AN INDEX THAT MAY NOT HAVE BEEN READ
-- (6.405.0). The vault builds its notes index when Hamsidian OPENS —
-- 6.267.0 moved that disk work off the boot path deliberately — so before
-- the first ⇪3 of a session `vault.names` answers an empty list, and this
-- module read that as "you have no notes" and said so, over a vault
-- holding twenty. An empty list cannot say WHICH empty it is, so the
-- state rides back beside it now and the three cases are three sentences:
-- read-and-holding-nothing · never read (asked for, and waited for,
-- bounded) · a scan already running (waited for, never restarted).
-- 📏 The OTHER legs are unaffected and that is worth knowing before
-- bisecting: "which notes already mention this?" is a grep over the
-- folder, so it has always worked cold.
--
-- 🔒 WHAT IT NEVER DOES: read your text. It reads a window's title, a
-- document's PATH and a browser's URL — never the contents of either, and
-- never the clipboard.
-- =====================================================================

local M = {
    name  = "anchors",
    order = 13.995, -- unique, and beside the vault: the sheet sorts by this,
                    -- and a tie makes its running order depend on table iteration
    family = "capture",
    cheatsheet = {
        title = "🔗 ANCHORS (⇪⇧U — link what is in front of you to a note)",
        -- 🚨 6.269.0 — THIS KEY IS `entries`, AND IT WAS `rows` FROM THE
        -- DAY THIS MODULE WAS WRITTEN (6.180.0). The loader reads
        -- `g.entries` and coerces a missing one to {}, so all eight rows
        -- below were registered as a card with a title and nothing under
        -- it: ⇪/ drew "🔗 ANCHORS …" over empty space for eighty-nine
        -- releases. Renaming the key is the whole fix; the rows never
        -- changed. The loader NAMES this shape now and a gate sentry
        -- refuses it, so it cannot come back silently in another module.
        entries = {
            { "⇪⇧U",      "Link the front document / tab / app to a vault note" },
            { "again",     "Already linked? The rows at the top are the notes that mention it" },
            { "⏎",         "Open that note in Hamsidian (⇪3)" },
            { "new",       "First row makes a note named after the thing and links it" },
            { "pick",      "Last row: choose any existing note to link it into" },
            { "in a note", "The link is plain Markdown under '## Linked' — Obsidian opens it" },
            { "moved",     "A renamed or moved file is found again by name (the ⇪D index)" },
            { "Console",   "_G.anchorsReport()" },
        },
    },
}

local OSASCRIPT = "/usr/bin/osascript"
local GREP      = "/usr/bin/grep"

function M.setup(core)
    local anc = {
        enabled   = true,
        key       = "u",          -- ⇪⇧U (⇪U is free and stays free)
        shift     = true,
        section   = "## Linked",  -- must match vault.linkSection
        folder    = "",           -- vault subfolder for a NEW anchor note; "" = the root
        maxRows   = 25,
        oscriptTimeout = 4,       -- seconds before a silent browser is given up on
        grepTimeout    = 8,
        titleChars     = 60,
        -- 6.405.0 — how long "pick a note" may wait for the notes index
        -- on a cold start. The names arrive on the FIRST of the vault's
        -- four greps (a /usr/bin/find), so this is a short wait and not
        -- a whole scan; 12 × 0.25 s is about three seconds.
        pickTries      = 12,
        pickWaitSecs   = 0.25,
        -- the browsers whose front tab can be asked for, by app name
        browsers = {
            ["Safari"] = "Safari", ["Google Chrome"] = "chromium",
            ["Microsoft Edge"] = "chromium", ["Brave Browser"] = "chromium",
            ["Arc"] = "chromium", ["Chromium"] = "chromium",
            ["Safari Technology Preview"] = "Safari",
        },
        -- state. 🚨 6.262.0: the tasks live in SEPARATE SLOTS, keyed by
        -- what they are doing — never in one `task` field — so starting
        -- one can never drop the last reference to another (6.196.1).
        tasks = {}, hops = {}, killer = nil, chooser = nil,
        hopped = 0, hopsMissed = 0,
        last = nil, opens = 0, links = 0, resolved = 0, lastWhy = nil,
        -- 🔎 6.273.0 — WHICH LEG ANSWERED, counted apart. ⇪⇧U can name a
        -- browser tab, a document or the app alone, and for eighty-nine
        -- releases only the third could ever happen (a shifted read of
        -- _G.service.call killed the other two). Nothing said so, because
        -- "the app only" is also a perfectly honest degrade. A count per
        -- leg is the one line that tells a working Mac from a broken one:
        -- documents at 0 after a day in Word is the fault, in a number.
        legs = { tab = 0, file = 0, app = 0 }, lastLeg = nil,
        -- 🔎 6.405.0 — THE "PICK A NOTE" ROW, counted by what it found.
        -- `empty` is the only case the old sentence was ever right about,
        -- and `gaveUp` is the one worth reading: it means the index never
        -- arrived, which is a fault rather than a cold start.
        pick = { asked = 0, opened = 0, waited = 0, empty = 0, gaveUp = 0, noTimer = 0 },
        pickWait = nil, pickWhy = nil,
    }
    M.config = anc
    _G.anchors = anc

    local function say(m) if _G.diag and _G.diag.say then _G.diag.say("anchors", m) end end
    local function warn(m) if _G.diag and _G.diag.warn then _G.diag.warn("anchors", m) end end
    local function alert(m, s)
        pcall(function() hs.alert.show(m, s or 2.5) end)
    end
    local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function has(name)
        return _G.service and _G.service.has and _G.service.has(name)
    end
    -- 🔌 6.273.0 — A WRAPPER'S TWO SHAPES HAVE TO AGREE, AND THESE DID
    -- NOT. This answered `false, "not loaded"` for a missing provider —
    -- a STATUS in slot one — while handing back _G.service.call's values
    -- RAW on success, where slot one is DATA. Every call site in this
    -- module was written to the failure shape and so read the provider
    -- one slot late: the document leg, the moved-file resolver and the
    -- "pick a note" row could not work on any Mac from 6.180.0 to
    -- 6.272.0, and each failed into a plausible answer ("the app only",
    -- "no notes yet") so nothing ever looked wrong. init.lua's registry
    -- answers nil for a missing provider; this answers nil too, so
    -- neither path has anything extra in front to strip.
    local function call(name, ...)
        if not has(name) then return nil end
        return _G.service.call(name, ...)
    end

    -- ---- 🚨 stepping off a task's own callback ----------------------------
    -- 6.196.1, learned when this exact shape killed Hammerspoon natively
    -- with no Lua error and nothing in the Console: NEVER START A TASK
    -- FROM INSIDE ANOTHER TASK'S CALLBACK, and never drop the last
    -- reference to the task whose callback is RUNNING. hs.task's
    -- finaliser tears down the NSTask and the callback block underneath
    -- the live frame, so whether it kills the Mac depends on where the
    -- garbage collector happens to land.
    --
    -- Both halves are the same hop: whatever the callback wanted to do
    -- next happens a turn later, from a HELD timer in its OWN slot, by
    -- which time the callback has RETURNED and its task can be let go.
    function anc.hop(slot, fn)
        local ok, t = pcall(hs.timer.doAfter, 0, function()
            anc.hops[slot] = nil
            anc.tasks[slot] = nil   -- the callback has returned: safe now
            anc.hopped = anc.hopped + 1
            pcall(fn)
        end)
        if ok and t then anc.hops[slot] = t; return true end
        -- No timer on this Mac. The work still has to happen — a ⇪⇧U that
        -- answers nothing is worse than one that answers on the old path
        -- — so it happens here, and the report SAYS the hop was missed
        -- rather than reading as health.
        anc.hopsMissed = anc.hopsMissed + 1
        pcall(fn)
        return false
    end

    -- ---- what is in front of me ------------------------------------------
    -- Never blocks: the AX read is doc_memory's (timed, and the only
    -- AXDocument path in the config), the browser read is a held hs.task
    -- with a killer timer, and the answer arrives in a callback.

    function anc.frontApp()
        local ok, app = pcall(hs.application.frontmostApplication)
        if not (ok and app) then return nil end
        local name
        pcall(function() name = app:name() end)
        return name and tostring(name) or nil
    end

    -- Percent-encode the characters that would break a Markdown link.
    function anc.encode(path)
        return (tostring(path or ""):gsub("[ ()<>\"'`#?%%\\]", function(c)
            return string.format("%%%02X", c:byte())
        end))
    end

    function anc.fileURL(path)
        return "file://" .. anc.encode(path)
    end

    -- One line of Markdown for a target. The title is squeezed so a long
    -- window title cannot make an unreadable note.
    function anc.linkLine(t)
        if type(t) ~= "table" or not t.url then return nil end
        local title = trim(t.title or t.url)
        title = title:gsub("[%[%]\n\r]", " "):gsub("%s+", " ")
        if #title > anc.titleChars then title = title:sub(1, anc.titleChars - 1) .. "…" end
        if title == "" then title = t.url end
        local when = os.date("%Y-%m-%d")
        return "- [" .. title .. "](" .. t.url .. ")  · " .. (t.app or "?") .. " · " .. when
    end

    -- The AppleScript for one browser's front tab. Chromium browsers and
    -- Safari use different words for the same thing, which is the fault
    -- that broke tab search in 6.152.0 — so each is written out in full
    -- rather than assembled from a template.
    function anc.script(app, kind)
        local esc = tostring(app):gsub('"', '\\"')
        if kind == "Safari" then
            return 'tell application "' .. esc .. '"\n'
                .. '  set theURL to URL of front document\n'
                .. '  set theName to name of front document\n'
                .. '  return theURL & "\\n" & theName\n'
                .. 'end tell'
        end
        return 'tell application "' .. esc .. '"\n'
            .. '  set theTab to active tab of front window\n'
            .. '  return (URL of theTab) & "\\n" & (title of theTab)\n'
            .. 'end tell'
    end

    -- cb(target | nil, why). A target is { kind, url, title, app }.
    function anc.identify(cb)
        local app = anc.frontApp()
        if not app then return cb(nil, "no front app") end

        -- 1. a browser tab, if the front app is one
        local kind = anc.browsers[app]
        if kind then
            local script = anc.script(app, kind)
            local done = false
            local function finish(t, why)
                if done then return end
                done = true
                if anc.killer then pcall(function() anc.killer:stop() end); anc.killer = nil end
                cb(t, why)
            end
            -- The callback works out the ANSWER and hands it to the hop;
            -- it does not run the caller's cb itself, because the caller
            -- opens a chooser, writes a note and can start the grep — all
            -- of it inside this task's own frame if it were called here.
            local okT, task = pcall(hs.task.new, OSASCRIPT, function(code, out, _)
                local t, why
                if code ~= 0 then
                    why = app .. " did not answer (Automation not granted?)"
                else
                    local url = tostring(out or ""):match("^[^\n]*") or ""
                    local title = tostring(out or ""):match("\n(.*)$") or ""
                    url, title = trim(url), trim(title)
                    if url == "" then why = "no tab open in " .. app
                    else t = { kind = "tab", url = url, title = title ~= "" and title or url, app = app } end
                end
                anc.hop("tab", function() finish(t, why) end)
            end, { "-e", script })
            if not (okT and task) then return cb(nil, "could not start osascript") end
            anc.tasks.tab = task
            -- HELD, and killed on its own timer: a browser that never
            -- answers must not leave a process or a dangling callback.
            local okK, k = pcall(hs.timer.doAfter, anc.oscriptTimeout, function()
                anc.killer = nil
                pcall(function() task:terminate() end)
                finish(nil, app .. " did not answer in " .. anc.oscriptTimeout .. "s")
            end)
            anc.killer = okK and k or nil
            if not pcall(function() task:start() end) then
                return finish(nil, "could not run osascript")
            end
            return
        end

        -- 2. the front window's document, via doc_memory (the only
        --    AXDocument reader in the config)
        if has("docs.front") then
            -- 🔌 6.273.0. _G.service.call hands back the PROVIDER'S OWN
            -- values, raw — there is no `ok` in front of them. Reading one
            -- put `doc` a slot late, so `type(doc) == "table"` was false on
            -- every success and this leg has never once fired on a Mac.
            local doc, why = call("docs.front")
            if type(doc) == "table" and doc.path then
                return cb({ kind = "file", url = anc.fileURL(doc.path), path = doc.path,
                            title = doc.title or doc.path:match("[^/]+$"), app = doc.app or app })
            end
            anc.lastWhy = tostring(why or "no document")
        end

        -- 3. nothing but the app itself. Still worth an anchor — "the note
        --    about the thing I was doing in Word" is a real link — but it
        --    is honest about being weaker than a path.
        return cb({ kind = "app", url = "", title = app, app = app }, "no document or tab — the app only")
    end

    -- ---- which notes already mention it ----------------------------------
    -- grep -rl over the vault, in a held task. The needle is the PATH (or
    -- the URL); if that finds nothing and the target is a file, the
    -- basename is tried too, which is what finds a note written before the
    -- file moved.
    function anc.notesFor(t, cb)
        local dir = _G.vault and _G.vault.dir
        if not dir then return cb({}, "Hamsidian is not loaded") end
        local needles = {}
        if t.path then
            needles[#needles + 1] = t.path
            local base = t.path:match("[^/]+$")
            if base and base ~= t.path then needles[#needles + 1] = base end
        elseif t.url and t.url ~= "" then
            needles[#needles + 1] = t.url
        elseif t.title then
            needles[#needles + 1] = t.title
        end
        if #needles == 0 then return cb({}, "nothing to look for") end

        local i, found = 0, {}
        local function step()
            i = i + 1
            if i > #needles or #found > 0 then return cb(found) end
            local args = { "-rlF", "--include=*.md", "-e", needles[i], dir }
            -- 🚨 THE SECOND NEEDLE IS THE COMMON CASE, which is what made
            -- this the dangerous one: the basename grep runs whenever the
            -- path grep found nothing, i.e. every ⇪⇧U on a document with
            -- no note yet. Starting it from inside the first grep's own
            -- callback is 6.196.1 exactly — and the old line above it
            -- (`anc.grepTask = nil`) dropped the running task as well.
            local okT, task = pcall(hs.task.new, GREP, function(_, out, _)
                for line in tostring(out or ""):gmatch("[^\n]+") do
                    local rel = line:sub(1, #dir + 1) == dir .. "/" and line:sub(#dir + 2) or line
                    local name = rel:gsub("%.md$", ""):match("([^/]+)$")
                    if name and #found < anc.maxRows then
                        found[#found + 1] = { name = name, rel = rel }
                    end
                end
                anc.hop("grep", step)
            end, args)
            if not (okT and task) then return cb(found, "grep would not start") end
            anc.tasks.grep = task
            if not pcall(function() task:start() end) then return cb(found, "grep would not run") end
        end
        step()
    end

    -- ---- 🚚 move survival --------------------------------------------------
    -- The vault asks this when an anchor's file is not where the link
    -- says. The filename is already in the link, and ⇪D's index already
    -- knows every file by name — so no extra bookkeeping was ever needed.
    function anc.resolve(path)
        path = tostring(path or "")
        local base = path:match("[^/]+$")
        if not base or base == "" then return nil end
        if not has("index.search") then return nil end
        local rows = call("index.search", base, 10)          -- 6.273.0: raw
        if type(rows) ~= "table" then return nil end
        for _, r in ipairs(rows) do
            local p = type(r) == "table" and (r.path or r.subText or r.text) or tostring(r)
            if type(p) == "string" and p ~= "" and p:match("[^/]+$") == base and p ~= path then
                anc.resolved = anc.resolved + 1
                say("resolved a moved file: " .. base)
                return p
            end
        end
        return nil
    end

    -- ---- the picker --------------------------------------------------------
    function anc.linkInto(name, t)
        local line = anc.linkLine(t)
        if not line then return false, "nothing to link" end
        -- 🚨 6.273.0. "Hamsidian is not loaded" used to be the answer to
        -- EVERY failed write, because vault.link's own `false` landed in
        -- the slot this code read as the registry's. The two questions are
        -- asked apart now: is there a provider, and what did it say.
        if not has("vault.link") then return false, "Hamsidian is not loaded" end
        local ok, why = call("vault.link", name, line,
                             anc.folder ~= "" and anc.folder or nil)
        if not ok then return false, tostring(why or "could not write the note") end
        anc.links = anc.links + 1
        anc.last = { name = name, title = t.title, url = t.url, at = os.time(), why = why }
        call("vault.show")
        alert("🔗 " .. (why == "already linked" and "Already in " or "Linked into ") .. name, 2)
        return true
    end

    function anc.rowsFor(t, notes)
        local rows = {}
        for _, n in ipairs(notes or {}) do
            rows[#rows + 1] = {
                text = "📄 " .. n.name,
                subText = "already links this · " .. n.rel,
                act = "open", name = n.name,
            }
        end
        local newName = trim(t.title or t.app or "Anchor")
        rows[#rows + 1] = {
            text = "➕ New note: " .. newName,
            subText = "makes the note and writes the link into it",
            act = "new", name = newName,
        }
        rows[#rows + 1] = {
            text = "📁 Link it into an existing note…",
            subText = "pick any note in Hamsidian",
            act = "pick",
        }
        return rows
    end

    -- the picker itself, once there is something to pick from. Lifted out
    -- of pickNote rather than copied, because pickNote now reaches it from
    -- two places — straight away, and a beat later once the index lands —
    -- and two copies of a picker is how they come to disagree (6.231.0).
    local function showPicker(t, names)
        local choices = {}
        for _, n in ipairs(names) do
            choices[#choices + 1] = { text = n, subText = "link it into this note", name = n }
        end
        local ch = hs.chooser.new(function(pick)
            if not pick then return end
            local ok, why = anc.linkInto(pick.name, t)
            if not ok then alert("🔗 " .. tostring(why), 3) end
        end)
        _G.choosers = _G.choosers or {}
        _G.choosers.anchorsPick = ch
        pcall(function() ch:searchSubText(true); ch:width(35) end)
        ch:choices(choices)
        ch:placeholderText(#choices .. " notes — type to filter")
        if core.showPopup then core.showPopup(ch) else ch:show() end
        anc.pick.opened = anc.pick.opened + 1
    end

    -- 🔎 6.405.0 — AN INDEX NOBODY HAS READ CANNOT SAY THERE ARE NO NOTES.
    -- This asked `vault.names`, got an empty list on a cold start, and
    -- said "No notes to pick yet — make one with the first row" over a
    -- full vault — which is LL's own report. The vault's notes index is
    -- built when Hamsidian OPENS (6.267.0 moved disk work off the boot
    -- path, deliberately), so before his first ⇪3 of a session there was
    -- nothing in it and nothing anywhere could say so.
    -- 🔑 THE STATE DECIDES, NOT THE COUNT. `vault.names` answers the state
    -- as a second value now, so: read-and-holding-nothing is the sentence
    -- the old code was right about, and an UNREAD index is asked to read
    -- itself and waited for.
    local function pickTry(t, tries)
        local names, state, swhy = call("vault.names")
        if type(names) ~= "table" then names = {} end
        if #names > 0 then
            if tries < anc.pickTries then anc.pick.waited = anc.pick.waited + 1 end
            showPicker(t, names)
            return
        end
        -- READ and genuinely empty: the only case the old message fitted
        if state == "read" then
            anc.pick.empty = anc.pick.empty + 1
            anc.pickWhy = "the index is read and Hamsidian holds no notes"
            alert("🔗 Hamsidian has no notes yet — the first row makes one", 3)
            return
        end
        -- 📏 BOUNDED, AND THE BOUND IS A SENTENCE (6.197.2): an index that
        -- never arrives is a fault, and a wait that ends in silence is
        -- indistinguishable from the bug this release fixes.
        if tries <= 0 then
            anc.pick.gaveUp = anc.pick.gaveUp + 1
            anc.pickWhy = tostring(swhy or state or "unknown")
            alert("🔗 Hamsidian is still reading your notes — press ⇪⇧U again"
                  .. " in a moment", 4)
            return
        end
        -- Ask for the read ONCE, on the first turn, and only when a scan
        -- is not already running: restarting one under itself is 6.304.0's
        -- generation problem with a four-task chain behind it.
        if tries == anc.pickTries then
            alert("🔗 Reading your notes…", 1.5)
            if state ~= "scanning" then pcall(call, "vault.rescan") end
        end
        local okT, timer = pcall(hs.timer.doAfter, anc.pickWaitSecs, function()
            anc.pickWait = nil
            pickTry(t, tries - 1)
        end)
        if okT and timer then
            anc.pickWait = timer    -- HELD, in its own slot (6.196.1)
        else
            -- No timer on this Mac. Say so rather than spinning inline —
            -- the scan has been asked for and the next press will find it.
            anc.pick.noTimer = anc.pick.noTimer + 1
            anc.pickWhy = "this Mac would not arm a wait for the index"
            alert("🔗 Hamsidian is reading your notes — press ⇪⇧U again in a moment", 4)
        end
    end

    local function pickNote(t)
        anc.pick.asked = anc.pick.asked + 1
        -- A wait already in flight is the SAME press (6.246.0): a second
        -- one would put two timers on one slot and drop the first.
        if anc.pickWait then return end
        pickTry(t, anc.pickTries)
    end

    function anc.present(t, notes, why)
        local rows = anc.rowsFor(t, notes)
        if not anc.chooser then
            anc.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                if pick.act == "open" then
                    if not select(1, call("vault.open", pick.name)) then
                        alert("🔗 Hamsidian is not loaded", 3)
                    else
                        call("vault.show")
                    end
                elseif pick.act == "new" then
                    local ok, w = anc.linkInto(pick.name, anc.pending or t)
                    if not ok then alert("🔗 " .. tostring(w), 3) end
                elseif pick.act == "pick" then
                    pickNote(anc.pending or t)
                end
            end)
            _G.choosers = _G.choosers or {}
            _G.choosers.anchors = anc.chooser
            pcall(function() anc.chooser:searchSubText(true); anc.chooser:width(35) end)
        end
        anc.pending = t
        anc.chooser:choices(rows)
        local what = t.kind == "tab" and "tab" or (t.kind == "file" and "document" or "app")
        anc.chooser:placeholderText("🔗 " .. what .. ": " .. tostring(t.title or t.app or "?")
                                    .. (why and ("  (" .. why .. ")") or ""))
        if core.showPopup then core.showPopup(anc.chooser) else anc.chooser:show() end
    end

    function anc.show()
        anc.opens = anc.opens + 1
        if not has("vault.link") then
            alert("🔗 Hamsidian is not loaded — an anchor needs somewhere to live", 3)
            return false
        end
        anc.identify(function(t, why)
            if not t then
                anc.lastWhy = tostring(why or "nothing identified")
                alert("🔗 " .. anc.lastWhy, 3)
                return
            end
            -- counted HERE, the one place every leg passes through — three
            -- increments at the three cb() sites is three places for one
            -- to drift (6.231.0).
            local leg = tostring(t.kind or "app")
            anc.legs[leg] = (anc.legs[leg] or 0) + 1
            anc.lastLeg = leg
            anc.notesFor(t, function(notes, gwhy)
                anc.present(t, notes, why or gwhy)
            end)
        end)
        return true
    end

    -- ---- doors in ----------------------------------------------------------
    if anc.enabled ~= false then
        core.hyperAddShortcut(anc.shift and { "shift" } or {}, anc.key,
                              function() anc.show() end, nil, nil, "anchors")
    end
    core.provide("anchors.show",    function() return anc.show() end)
    core.provide("anchors.resolve", function(p) return anc.resolve(p) end)
    core.provide("anchors.report",  function() return _G.anchorsReport() end)

    _G.anchorsReport = function()
        local L = { "🔗 ANCHORS — ⇪⇧U links what is in front of you to a note" }
        L[#L + 1] = "   vault  : " .. (has("vault.link")
                    and ((_G.vault and _G.vault.dir or "?") .. "  · section " .. tostring(anc.section))
                    or "NOT loaded — ⇪⇧U will say so and do nothing")
        L[#L + 1] = "   reads  : browser tab (osascript, " .. anc.oscriptTimeout .. "s limit) · "
                    .. (has("docs.front") and "front document (doc_memory)" or "no document reader")
                    .. " · the app name always"
        L[#L + 1] = "   moved  : " .. (has("index.search")
                    and ("resolved by name through the ⇪D file index · " .. anc.resolved .. " so far")
                    or "the file index is not loaded — a moved file is reported, not guessed")
        -- 🚨 6.262.0. A count that only ever reads as health would say
        -- nothing, so the MISSED hops outrank it: a Mac that could not
        -- arm the timer is running the shape that crashes, and that is
        -- the line worth reading (6.196.1).
        if anc.hopsMissed > 0 then
            L[#L + 1] = "   tasks  : ⚠️ " .. anc.hopsMissed .. " callback(s) could NOT step off a held timer"
                        .. " — this Mac ran the next step inside the last one's frame"
        else
            L[#L + 1] = "   tasks  : " .. anc.hopped .. " callback(s) stepped off a held timer before the"
                        .. " next task started · slots: " .. (anc.tasks.tab and "tab " or "")
                        .. (anc.tasks.grep and "grep" or "") .. ((not anc.tasks.tab and not anc.tasks.grep) and "none held" or "")
        end
        L[#L + 1] = "   used   : opened " .. anc.opens .. " · linked " .. anc.links
        local LEGNAME = { tab = "browser tab", file = "document", app = "the app alone" }
        L[#L + 1] = "   named  : " .. anc.legs.tab .. " browser tab(s) · " .. anc.legs.file
                    .. " document(s) · " .. anc.legs.app .. " app only"
                    .. (anc.lastLeg and ("  — last: " .. (LEGNAME[anc.lastLeg] or anc.lastLeg)) or "")
        -- 🔎 THREE STATES, NEVER TWO (6.196.1): never pressed is not the
        -- same fact as pressed-and-never-named-a-document, and before
        -- 6.273.0 the second was guaranteed on every Mac.
        if anc.opens > 0 and anc.legs.tab == 0 and anc.legs.file == 0 then
            L[#L + 1] = "   ↳ every press so far has fallen back to the app name."
                        .. " In a browser or a Word document that is the shape of a fault"
        end
        -- 🔎 6.405.0 — THE INDEX, READ RIGHT NOW. This is the artefact: an
        -- empty list with "unread" beside it is a cold start and not an
        -- empty vault, and before this release no number on his Mac could
        -- tell the two apart.
        local inames, istate, iwhy = call("vault.names")
        L[#L + 1] = "   index  : " .. (type(inames) == "table"
                    and (#inames .. " note(s) the index knows") or "no answer from Hamsidian")
                    .. " · " .. tostring(istate or "?") .. " — " .. tostring(iwhy or "")
        L[#L + 1] = "   pick   : " .. anc.pick.asked .. " asked · " .. anc.pick.opened
                    .. " opened the picker · " .. anc.pick.waited .. " waited for the index · "
                    .. anc.pick.empty .. " found Hamsidian genuinely empty"
        if anc.pick.gaveUp > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. anc.pick.gaveUp .. " gave up waiting for the notes index"
                        .. " — an index that never arrives is a fault, not a cold start"
        end
        if anc.pick.noTimer > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. anc.pick.noTimer .. " wait(s) could not be armed —"
                        .. " this Mac would not give hs.timer a slot"
        end
        if anc.pickWhy then L[#L + 1] = "   ↳ last : " .. tostring(anc.pickWhy) end
        local l = anc.last
        L[#L + 1] = "   last   : " .. (l and (l.name .. " — " .. tostring(l.title) .. " ("
                    .. os.date("%b %d %H:%M", l.at) .. ")") or "nothing yet")
        if anc.lastWhy then L[#L + 1] = "   note   : " .. anc.lastWhy end
        L[#L + 1] = "   never  : reads your text, the clipboard, or a file's contents"
        print(table.concat(L, "\n"))
        return #L
    end

    say("ready — ⇪⇧" .. anc.key:upper())
end

return M
