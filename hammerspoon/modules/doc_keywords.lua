-- =====================================================================
-- MODULE: DOC KEYWORDS — Word files write their own search terms
-- =====================================================================
-- LL: "when I create a Word file and when I open one again, for
-- hammerspoon to select keywords and [put them] into the details or
-- comments section when you right click on a file and want to see
-- certain attributes and metadata. What I'm trying to accomplish is
-- making files more searchable."
--
-- ---------------------------------------------------------------------
-- WHAT IT DOES
-- ---------------------------------------------------------------------
-- Save a .docx anywhere under OneDrive, ~/Documents or ~/Desktop and a
-- few seconds later its FINDER COMMENT (right-click → Get Info →
-- Comments) reads:
--
--     keywords: budget, revenue, quarterly, forecast, …
--
-- — the eight words that actually characterise the document, counted
-- from its text with the throwaway words (the, and, would…) removed.
-- Finder comments are the ONE metadata field Spotlight reliably
-- indexes (kMDItemFinderComment — the same route the ⇪O OCR tagger
-- proved in 6.62), so a file named "Document 7 final v2.docx" becomes
-- findable by what is IN it, in Spotlight, in Finder search, and in
-- ⇪D once the search index picks the file up.
--
-- ---------------------------------------------------------------------
-- WHEN IT FIRES, said honestly
-- ---------------------------------------------------------------------
-- A pathwatcher sees every CREATE and every SAVE (Word writes the file
-- on both). Opening a document and closing it WITHOUT saving touches
-- nothing on disk, so the comment keeps its last keywords — which are
-- still the right keywords for unchanged content. The event is
-- debounced: Word saves in a flurry of temp-file renames, and we read
-- the file once, after the flurry settles. _G.tagDoc("/path/to.docx")
-- tags any one file on demand.
--
-- Only .docx: that format is a zip with the text in word/document.xml,
-- readable with /usr/bin/unzip -p in a child process — no Word
-- automation, nothing installed. Old-style .doc is a binary container
-- with no such door; those files are left untouched rather than
-- half-read.
--
-- ---------------------------------------------------------------------
-- A SYNC IS NOT A SAVE (6.110.0)
-- ---------------------------------------------------------------------
-- Saving one document is one file. A first OneDrive sync, a restored
-- backup or a folder someone shares with you is HUNDREDS, and the
-- module used to treat them identically: every settled path started its
-- own unzip immediately, each success started its own osascript, and
-- each of those printed its own console line. LL's log showed the
-- result — several hundred 🏷 lines between 04:58 and 05:13, with four
-- real LuaSkin errors buried in the middle of them, plus a few hundred
-- child processes racing on a machine that had other work to do.
--
-- So a settled batch is now a RUN, and a run is bounded twice:
--
--   • dk.maxInFlight files are read at a time. The rest wait in a queue
--     and start as slots free, so the cost of a thousand-file sync is
--     time, never a process storm. Nothing is dropped.
--   • A run bigger than dk.chatty reports a TOTAL when it finishes,
--     not a line per file. Every file is still recorded in full —
--     _G.docKeywordsReport() lists them, and _G.tagDoc() always names
--     the file you asked for, even mid-run.
--
-- The Console is where errors are supposed to be visible. A module that
-- fills it with routine success is hiding them.
--
-- ---------------------------------------------------------------------
-- 🚨 THE COMMENT IS YOURS FIRST, OURS SECOND
-- ---------------------------------------------------------------------
-- The comment is only written when it is EMPTY or when it already
-- starts with "keywords:" — the marker that says the last writer was
-- this module. A comment you typed by hand is never overwritten, the
-- same never-clobber rule the OCR tagger ships with. And the write
-- goes through /usr/bin/osascript OUT OF PROCESS — the in-process
-- AppleScript crash of 6.65.1 is not getting a second chance. First
-- use asks for Automation permission for Finder (System Settings →
-- Privacy & Security → Automation); on a work Mac where that is
-- locked down, every failure is one ⚠️ console line, and everything
-- else keeps running.

local M = {
    name  = "Doc Keywords",
    order = 11.2,
    family = "auto",
    summary = "Word files get Spotlight keywords as you save them",              -- beside the Document Watcher (11)
    cheatsheet = {
        title = "🏷 DOC KEYWORDS (automatic — Word files tag themselves)",
        entries = {
            { "auto",  "Saving a .docx writes 'keywords: …' into its Finder comment" },
            { "scope", "OneDrive · ~/Documents · ~/Desktop (settles a few seconds after save)" },
            { "find",  "Spotlight & Finder search match the comment — search what's IN the file" },
            { "safe",  "A comment YOU typed is never overwritten (only ours refresh)" },
            { "bulk",  "A sync burst reads a few at a time and reports a total, not a line each" },
            { "hand",  "_G.tagDoc(\"/path/to.docx\") tags one now · _G.docKeywordsReport()" },
        },
    },
}

function M.setup(core)
    local dk = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    dk.enabled   = true
    dk.quietSecs = 6          -- the save-flurry settles this long first
    dk.keywords  = 8          -- how many words the comment carries
    dk.minLen    = 4          -- shorter words are glue, not keywords
    dk.minBytes  = 512        -- smaller = a placeholder mid-save; skip
    dk.maxBytes  = 15 * 1024 * 1024   -- bigger = not worth reading for tags
    dk.marker    = "keywords:"        -- our signature; only these refresh
    dk.maxInFlight = 3        -- files read at a time; the rest queue and wait
    dk.chatty      = 3        -- a run bigger than this reports a total, not lines
    dk.logMax      = 200      -- what _G.docKeywordsReport() can still show you
    -- ✏️ Words that describe every document and therefore none. One
    -- string, space-separated, so adding one is typing it.
    dk.stopwords = [[
        the and for you your yours that this these those with have has had
        from are was were will would could should shall may might must can
        about into over under between through during after before while
        when where which what who whom whose been being they them their
        there here than then not but our ours out its also just like very
        more most some any all each other only own same such does did done
        make made making take taken took give given need needs needed use
        used using page date time year week day month please thanks regards
        dear hello sincerely subject re fw fwd
    ]]
    -- ----------------------------------------------------------------------

    local home = core.homeDir or os.getenv("HOME") or ""
    dk.roots = {}
    if core.cloudDir then dk.roots[#dk.roots + 1] = core.cloudDir end
    if home ~= "" then
        dk.roots[#dk.roots + 1] = home .. "/Documents"
        dk.roots[#dk.roots + 1] = home .. "/Desktop"
    end

    local function say(m)  if _G.diag then _G.diag.say("dockw", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("dockw", m) end end

    local STOP = {}
    for w in dk.stopwords:gmatch("%S+") do STOP[w] = true end

    -- ---- the pure half, exposed for the test suite -----------------------
    -- Is this a file we tag? .docx only, and never Word's "~$…" lock
    -- files or anything hidden.
    function dk.wantsFile(path)
        local name = tostring(path or ""):match("[^/]*$") or ""
        if name:sub(1, 2) == "~$" or name:sub(1, 1) == "." then return false end
        return name:lower():sub(-5) == ".docx"
    end

    -- word/document.xml → readable text: tags become spaces, the five
    -- XML entities come back as characters. That is ALL a keyword count
    -- needs — this is not a renderer.
    function dk.textFromXml(xml)
        local s = tostring(xml or ""):gsub("<[^>]->", " ")
        s = s:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
             :gsub("&quot;", '"'):gsub("&apos;", "'")
        return s
    end

    -- The count: lowercase words of minLen+ letters, stopwords out,
    -- most frequent first, first-seen breaking ties (stable, so the
    -- opening paragraph outranks the appendix at equal counts).
    function dk.pickKeywords(text)
        local count, first, seen = {}, {}, 0
        for w in tostring(text or ""):lower():gmatch("[%a]+") do
            if #w >= dk.minLen and not STOP[w] then
                if not count[w] then
                    seen = seen + 1 ; first[w] = seen
                end
                count[w] = (count[w] or 0) + 1
            end
        end
        local words = {}
        for w in pairs(count) do words[#words + 1] = w end
        table.sort(words, function(a, b)
            if count[a] ~= count[b] then return count[a] > count[b] end
            return first[a] < first[b]
        end)
        while #words > dk.keywords do words[#words] = nil end
        return words
    end

    function dk.commentFor(words)
        if not words or #words == 0 then return nil end
        return dk.marker .. " " .. table.concat(words, ", ")
    end

    local function escAS(s)
        return (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'))
    end

    -- Write-if-ours: empty comments and "keywords:…" comments are fair
    -- game; anything else is a human's and is kept. Same shape as the
    -- OCR tagger's script, plus the refresh clause.
    function dk.scriptFor(path, comment)
        return 'tell application "Finder"\n'
            .. 'set theFile to (POSIX file "' .. escAS(path) .. '") as alias\n'
            .. 'set c to comment of theFile\n'
            .. 'if c is "" or c starts with "' .. escAS(dk.marker) .. '" then\n'
            .. 'set comment of theFile to "' .. escAS(comment) .. '"\n'
            .. 'return "written"\n'
            .. 'else\n'
            .. 'return "kept"\n'
            .. 'end if\n'
            .. 'end tell'
    end

    -- ---- the machinery ---------------------------------------------------
    dk.pending  = {}     -- path -> true, waiting for the flurry to settle
    dk.done     = {}     -- path -> mtime we last tagged, so a save tags once
    dk.tasks    = {}     -- HELD: a collected hs.task is reaped mid-read
    dk.log      = {}     -- this session's taggings, for the report
    dk.queue    = {}     -- FIFO: settled paths waiting for a free slot
    dk.inFlight = 0      -- files being read right now (never > maxInFlight)
    dk.batch    = nil    -- the run in progress, or nil between runs
    dk.loud     = {}     -- paths _G.tagDoc asked for: those always speak

    local function logIt(path, what)
        dk.log[#dk.log + 1] = { when = os.date("%H:%M:%S"),
                                file = path:match("[^/]*$") or path,
                                what = what }
        while #dk.log > dk.logMax do table.remove(dk.log, 1) end
    end

    -- Does this file get to print? Small runs name every file; a file
    -- you asked for by hand always names itself, mid-run or not.
    local function speaks(path)
        return dk.loud[path] or not (dk.batch and dk.batch.quiet)
    end

    -- ---- the run ---------------------------------------------------------
    -- A first sync does not arrive in one wave, it dribbles in over
    -- minutes. So a run stays open through the quiet gaps and closes
    -- only once the queue has been empty for a settle — otherwise thirty
    -- waves would print thirty summaries, which is the same flood with
    -- extra steps.
    local function runOpen(adding)
        if dk.batchTimer then
            pcall(function() dk.batchTimer:stop() end)
            dk.batchTimer = nil
        end
        dk.batch = dk.batch or { total = 0, started = os.time(),
                                 written = 0, kept = 0, refused = 0,
                                 unread = 0, empty = 0 }
        dk.batch.total = dk.batch.total + (adding or 0)
        dk.batch.quiet = dk.batch.total > dk.chatty
        return dk.batch
    end

    local function runClose()
        dk.batchTimer = nil
        local b = dk.batch
        dk.batch = nil
        if not (b and b.quiet) then return end     -- a small run already spoke
        -- Every write refused means one cause, not N: say it once.
        if b.refused > 0 and b.written == 0 then
            print("⚠️ Doc Keywords: Finder refused all " .. b.refused
                  .. " write(s) — grant Hammerspoon Automation permission for "
                  .. "Finder (System Settings → Privacy & Security)")
        end
        local parts = {}
        local function part(n, s) if n > 0 then parts[#parts + 1] = n .. " " .. s end end
        part(b.written, "tagged")
        part(b.kept,    "left alone (your comment)")
        part(b.empty,   "with no words worth writing")
        part(b.unread,  "unreadable")
        if b.written > 0 then part(b.refused, "refused by Finder") end
        if #parts == 0 then return end
        print("🏷 Doc Keywords: " .. table.concat(parts, ", ") .. " in "
              .. math.max(0, os.time() - (b.started or os.time())) .. "s"
              .. " — _G.docKeywordsReport() names them")
    end

    -- One file is finished with, however it ended. Every path out of a
    -- read or a write lands here EXACTLY once: it frees the slot, counts
    -- the outcome, and lets the next file in.
    local function finish(path, outcome)
        dk.loud[path] = nil
        if dk.inFlight > 0 then dk.inFlight = dk.inFlight - 1 end
        if dk.batch and outcome then
            dk.batch[outcome] = (dk.batch[outcome] or 0) + 1
        end
        dk.pump()
    end

    -- Bounded on purpose. A thousand-file sync costs time here, never a
    -- thousand child processes — which is the difference between a work
    -- Mac that stays usable and one that does not.
    function dk.pump()
        if dk.pumping then return end        -- finish() → pump() → finish() → …
        dk.pumping = true
        while dk.inFlight < dk.maxInFlight and #dk.queue > 0 do
            local path = table.remove(dk.queue, 1)
            if not dk.process(path) and dk.batch then
                -- Skipped before it ever took a slot: gone again,
                -- placeholder-sized, or already tagged at this mtime. It
                -- was never part of the run, so it is not counted in it.
                dk.batch.total = math.max(0, dk.batch.total - 1)
            end
        end
        dk.pumping = false
        if dk.inFlight == 0 and #dk.queue == 0 and dk.batch and not dk.batchTimer then
            pcall(function()
                dk.batchTimer = hs.timer.doAfter(dk.quietSecs, function()
                    pcall(runClose)
                end)
            end)
            if not dk.batchTimer then runClose() end   -- no timers? close now
        end
    end

    local function fileAttr(path, what)
        local v
        pcall(function() v = hs.fs.attributes(path, what) end)
        return v
    end

    function dk.writeComment(path, comment)
        local okNew, t = pcall(function() return hs.task.new("/usr/bin/osascript",
            function(exitCode, stdOut)
                dk.tasks[path] = nil
                local res = tostring(stdOut or ""):gsub("%s+$", "")
                local name = path:match("[^/]*$") or path
                -- The log records every file either way; only the CONSOLE
                -- goes quiet in a big run, and only for routine outcomes.
                local loud = speaks(path)
                if exitCode == 0 and res == "written" then
                    logIt(path, comment)
                    if loud then
                        print("🏷 Doc Keywords → " .. name .. " — "
                              .. comment:sub(#dk.marker + 2))
                    end
                    finish(path, "written")
                elseif exitCode == 0 then
                    logIt(path, "kept your comment")
                    if loud then
                        print("ℹ️ Doc Keywords: " .. name
                              .. " already has YOUR comment — kept")
                    end
                    finish(path, "kept")
                else
                    logIt(path, "Finder said no")
                    if loud then
                        print("⚠️ Doc Keywords: Finder scripting failed for " .. name
                              .. " — grant Hammerspoon Automation permission for "
                              .. "Finder (System Settings → Privacy & Security)")
                    end
                    finish(path, "refused")
                end
            end, { "-e", dk.scriptFor(path, comment) }) end)
        if not (okNew and t) then
            warn("hs.task unavailable for the Finder comment")
            return false
        end
        dk.tasks[path] = t
        if not pcall(function() return t:start() end) then
            dk.tasks[path] = nil
            return false
        end
        return true
    end

    function dk.process(path, force)
        if not dk.enabled then return false end
        if not force and not dk.wantsFile(path) then return false end
        local size = fileAttr(path, "size")
        if type(size) ~= "number" then return false end          -- gone again
        if size < dk.minBytes or size > dk.maxBytes then return false end
        local mtime = fileAttr(path, "modification")
        if not force and mtime and dk.done[path] == mtime then return false end
        dk.done[path] = mtime or true

        local okNew, t = pcall(function() return hs.task.new("/usr/bin/unzip",
            function(exitCode, stdOut)
                dk.tasks["unzip:" .. path] = nil
                if exitCode ~= 0 then
                    -- Not an error worth a banner: an encrypted or
                    -- half-synced docx reads as "no tags today".
                    say("unzip could not read " .. path)
                    finish(path, "unread")
                    return
                end
                -- The slot stays held until Finder answers, so one file
                -- is one slot from first read to written comment.
                local writing = false
                local okAll = pcall(function()
                    local words = dk.pickKeywords(dk.textFromXml(stdOut))
                    local comment = dk.commentFor(words)
                    if comment then writing = dk.writeComment(path, comment) end
                end)
                if not okAll then
                    warn("keyword pass failed on " .. path)
                    finish(path, "unread")
                elseif not writing then
                    finish(path, "empty")     -- read fine, nothing worth writing
                end
            end, { "-p", path, "word/document.xml" }) end)
        if not (okNew and t) then
            warn("hs.task unavailable for the docx read")
            return false
        end
        dk.tasks["unzip:" .. path] = t
        if not pcall(function() return t:start() end) then
            dk.tasks["unzip:" .. path] = nil
            return false
        end
        dk.inFlight = dk.inFlight + 1     -- counted only once it is really running
        return true
    end

    function dk.flush()
        dk.timer = nil
        local settled = dk.pending
        dk.pending = {}
        local n = 0
        for path in pairs(settled) do
            dk.queue[#dk.queue + 1] = path
            n = n + 1
        end
        if n == 0 then return end
        runOpen(n)
        dk.pump()
    end

    function dk.onEvents(paths)
        if not dk.enabled or type(paths) ~= "table" then return end
        local any = false
        for _, p in ipairs(paths) do
            if dk.wantsFile(p) then dk.pending[p] = true ; any = true end
        end
        if any and not dk.timer then
            pcall(function()
                dk.timer = hs.timer.doAfter(dk.quietSecs, function()
                    pcall(dk.flush)
                end)
            end)
            -- No timer on this Mac? Tag now rather than never.
            if not dk.timer then dk.flush() end
        end
    end

    -- ---- console verbs ---------------------------------------------------
    function _G.tagDoc(path)
        if type(path) ~= "string" or path == "" then
            print("🏷 _G.tagDoc(\"/full/path/to/file.docx\") — tags that one file")
            return false
        end
        -- You asked for this one by name, so it reports by name even if a
        -- sync run is going on around it and everything else is quiet.
        dk.loud[path] = true
        local started = dk.process(path, true)
        if not started then dk.loud[path] = nil end
        print(started
              and ("🏷 Doc Keywords: reading " .. (path:match("[^/]*$") or path)
                   .. " — the comment lands in a moment")
              or  ("⚠️ Doc Keywords could not start on " .. path
                   .. " — is it a real .docx under " .. dk.minBytes .. "+ bytes?"))
        return started
    end

    function _G.docKeywordsReport()
        local L = { "🏷 DOC KEYWORDS this session — newest last (last "
                    .. dk.logMax .. " kept)" }
        for _, e in ipairs(dk.log) do
            L[#L + 1] = string.format("   %s  %-36s %s", e.when, e.file, e.what)
        end
        if #dk.log == 0 then
            L[#L + 1] = "   none yet — save a .docx (or _G.tagDoc a path)"
        end
        -- Mid-run, say so: a quiet Console during a big sync is the point,
        -- not a sign that nothing is happening.
        if dk.batch then
            L[#L + 1] = string.format(
                "   ── a run is going: %d of %d done · %d reading · %d queued",
                (dk.batch.written or 0) + (dk.batch.kept or 0)
                + (dk.batch.refused or 0) + (dk.batch.unread or 0)
                + (dk.batch.empty or 0),
                dk.batch.total or 0, dk.inFlight, #dk.queue)
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    core.provide("docKeywords.tag",    function(p) return _G.tagDoc(p) end)
    core.provide("docKeywords.report", function() return _G.docKeywordsReport() end)

    -- Watchers start in warm(), off the boot path; a root that does not
    -- exist contributes nothing (the work Mac may have no personal
    -- OneDrive — Tuesday, not an error).
    dk.watchers = {}
    M.warm = function()
        if not dk.enabled then return end
        for _, root in ipairs(dk.roots) do
            pcall(function()
                if hs.fs.attributes(root, "mode") == "directory" then
                    local w = hs.pathwatcher.new(root, function(paths)
                        pcall(dk.onEvents, paths)
                    end)
                    if w then
                        w:start()
                        dk.watchers[#dk.watchers + 1] = w
                    end
                end
            end)
        end
        say(#dk.watchers .. " watcher(s) on " .. #dk.roots .. " root(s)")
    end

    _G.docKeywords = dk
    M.dk     = dk
    M.config = dk
end

return M
