-- =====================================================================
-- test_doc_keywords.lua — Word files tag themselves. 6.96.0
-- =====================================================================
--     lua5.4 test_doc_keywords.lua [/path/to/hammerspoon]
--
-- The properties held here:
--   K1  ONLY REAL .docx FILES ARE TOUCHED — never Word's ~$ lock
--       files, never hidden files, never .doc/.txt.
--   K2  THE KEYWORDS ARE THE DOCUMENT'S OWN: frequency-ranked, glue
--       words removed, ties to the words that appear FIRST.
--   K3  EVERYTHING HEAVY IS OUT OF PROCESS: unzip reads the text,
--       osascript writes the comment; the main thread only counts.
--   K4  A HUMAN'S COMMENT IS NEVER OVERWRITTEN — only empty comments
--       and our own "keywords:" comments are written.
--   K5  A SAVE-FLURRY IS ONE READ (debounce), one save is one tag
--       (mtime guard), and every failure is one console line.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        local line = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        failures[#failures + 1] = line
        io.write("   ❌ " .. line .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a controllable Mac ----------------------------------------------
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function saidLine(s)
    for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end
end

local TASKS, TIMERS, WATCHERS, ATTR = {}, {}, {}, {}
hs = {
    task = { new = function(cmd, cb, args)
        local t = { cmd = cmd, cb = cb, args = args, started = false }
        function t:start() self.started = true ; return self end
        TASKS[#TASKS + 1] = t
        return t
    end },
    timer = { doAfter = function(secs, fn)
        local t = { secs = secs, fn = fn }
        function t:stop() self.stopped = true ; return self end
        TIMERS[#TIMERS + 1] = t
        return t
    end },
    fs = { attributes = function(path, what)
        local a = ATTR[path]
        if a then return a[what] end
    end },
    pathwatcher = { new = function(path, fn)
        local w = { path = path, fn = fn, started = false }
        function w:start() self.started = true ; return self end
        WATCHERS[#WATCHERS + 1] = w
        return w
    end },
}
_G.diag = { say = function() end, warn = function() end }

local HOME  = "/Users/lee"
local CLOUD = HOME .. "/Library/CloudStorage/OneDrive-Personal"
local PROVIDED = {}
local CORE = {
    homeDir = HOME, cloudDir = CLOUD, logsDir = "/tmp", hostTag = "Test-Mac",
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, DK
local function boot()
    printed, TASKS, TIMERS, WATCHERS, ATTR, PROVIDED = {}, {}, {}, {}, {}, {}
    M = dofile(HS .. "/modules/doc_keywords.lua")
    M.setup(CORE)
    DK = M.dk
end

local DOC = CLOUD .. "/Documents/Q3 Report.docx"
local function realDoc(path, size, mtime)
    ATTR[path] = { size = size or 40000, modification = mtime or 111 }
end

-- Enough of a word/document.xml to be honest about the shape.
local XML = [[<?xml version="1.0"?><w:document><w:body>
<w:p><w:r><w:t>Budget budget BUDGET revenue revenue forecast</w:t></w:r></w:p>
<w:p><w:r><w:t>The quarterly numbers &amp; the revenue outlook</w:t></w:r></w:p>
<w:p><w:r><w:t>forecast headcount headcount plan for the team</w:t></w:r></w:p>
</w:body></w:document>]]

-- =====================================================================
out("── test_doc_keywords (module at " .. HS .. ")\n")

-- ---- 1. contract ----------------------------------------------------
out("   1. module contract — automatic, no key claimed\n")
boot()
check("module name", M.name == "Doc Keywords", M.name)
check("cheatsheet says it is automatic",
      (M.cheatsheet.title or ""):find("automatic", 1, true))
check("_G.docKeywords published", _G.docKeywords == DK)
check("_G.tagDoc and _G.docKeywordsReport published",
      type(_G.tagDoc) == "function" and type(_G.docKeywordsReport) == "function")
check("services provided", type(PROVIDED["docKeywords.tag"]) == "function"
      and type(PROVIDED["docKeywords.report"]) == "function")
check("config table exposed for profile overrides", M.config == DK)
check("warm() defined — watchers stay off the boot path", type(M.warm) == "function")
check("the roots are OneDrive, Documents and Desktop", (function()
    local want = { [CLOUD] = true, [HOME .. "/Documents"] = true,
                   [HOME .. "/Desktop"] = true }
    local n = 0
    for _, r in ipairs(DK.roots) do
        if not want[r] then return false, r end
        n = n + 1
    end
    return n == 3, n
end)())

-- ---- 2. which files (K1) --------------------------------------------
out("   2. only real .docx files\n")
check(".docx wanted", DK.wantsFile("/a/b/Report.docx"))
check("case-insensitive", DK.wantsFile("/a/b/REPORT.DOCX"))
check("Word's ~$ lock file refused", not DK.wantsFile("/a/b/~$Report.docx"))
check("hidden file refused", not DK.wantsFile("/a/b/.Report.docx"))
check("old binary .doc refused (no zip door to read it through)",
      not DK.wantsFile("/a/b/Report.doc"))
check("everything else refused", not DK.wantsFile("/a/b/Report.txt")
      and not DK.wantsFile("/a/b/docx") and not DK.wantsFile(nil))

-- ---- 3. the keywords (K2) -------------------------------------------
out("   3. the words: frequency first, glue removed, ties stable\n")
local text = DK.textFromXml(XML)
check("tags are stripped to spaces", not text:find("<", 1, true))
check("entities decode", text:find("numbers & the", 1, true) ~= nil)
local words = DK.pickKeywords(text)
check("most frequent word first — counting is case-insensitive",
      words[1] == "budget", table.concat(words, ","))
check("revenue (3) before forecast/headcount (2)", words[2] == "revenue")
check("equal counts keep first-appearance order — forecast before headcount",
      words[3] == "forecast" and words[4] == "headcount",
      table.concat(words, ","))
check("stopwords never rank ('the' appears 4 times and is absent)", (function()
    for _, w in ipairs(words) do if w == "the" or w == "for" then return false end end
    return true
end)())
check("short glue is out (minLen)", (function()
    for _, w in ipairs(words) do if #w < DK.minLen then return false end end
    return true
end)())
check("the list caps at dk.keywords", #words <= DK.keywords, #words)
check("the comment wears the marker",
      DK.commentFor({ "budget", "revenue" }) == "keywords: budget, revenue")
check("no words, no comment, no write", DK.commentFor({}) == nil)

-- ---- 4. the pipeline (K3) -------------------------------------------
out("   4. save → settle → unzip → count → Finder comment\n")
boot()
M.warm()
check("no watcher for a root that does not exist (work-Mac Tuesday)",
      #WATCHERS == 0, #WATCHERS)
ATTR[CLOUD] = { mode = "directory" }
ATTR[HOME .. "/Documents"] = { mode = "directory" }
boot()
ATTR[CLOUD] = { mode = "directory" }
ATTR[HOME .. "/Documents"] = { mode = "directory" }
M.warm()
check("one started watcher per EXISTING root", #WATCHERS == 2
      and WATCHERS[1].started and WATCHERS[2].started, #WATCHERS)

realDoc(DOC)
WATCHERS[1].fn({ DOC, "/x/ignored.txt", "/x/~$Q3 Report.docx" })
check("a save arms ONE settle timer at quietSecs",
      #TIMERS == 1 and TIMERS[1].secs == DK.quietSecs, #TIMERS)
WATCHERS[1].fn({ DOC })
check("the flurry does not arm a second one", #TIMERS == 1, #TIMERS)
check("nothing is read before the flurry settles", #TASKS == 0)
TIMERS[1].fn()
check("settle: ONE unzip, out of process, -p word/document.xml",
      #TASKS == 1 and TASKS[1].cmd == "/usr/bin/unzip"
      and TASKS[1].args[1] == "-p" and TASKS[1].args[2] == DOC
      and TASKS[1].args[3] == "word/document.xml" and TASKS[1].started,
      TASKS[1] and TASKS[1].cmd)
TASKS[1].cb(0, XML, "")
check("the text spawns the Finder write, out of process too",
      #TASKS == 2 and TASKS[2].cmd == "/usr/bin/osascript", TASKS[2] and TASKS[2].cmd)
local script = TASKS[2].args and TASKS[2].args[2] or ""
check("the script names the file as a POSIX path",
      script:find(DOC, 1, true) ~= nil)
check("…writes the counted keywords", script:find("budget", 1, true) ~= nil)
check("…and only over an empty or OUR comment (K4)",
      script:find('c is ""', 1, true) ~= nil
      and script:find('starts with "keywords:"', 1, true) ~= nil)
TASKS[2].cb(0, "written\n", "")
check("written: one 🏷 console line with the words",
      saidLine("🏷 Doc Keywords → Q3 Report.docx") and saidLine("budget"))
check("…and the session log remembers it", (function()
    local rep = _G.docKeywordsReport()
    return rep:find("Q3 Report.docx", 1, true) ~= nil
end)())

-- ---- 5. the guards (K5) ---------------------------------------------
out("   5. one save is one tag; humans win; failures are one line\n")
printed = {}
WATCHERS[1].fn({ DOC })
TIMERS[#TIMERS].fn()
check("same mtime again: no second read", #TASKS == 2, #TASKS)
realDoc(DOC, 41000, 222)                    -- a real new save
WATCHERS[1].fn({ DOC })
TIMERS[#TIMERS].fn()
check("a NEW save reads again", #TASKS == 3, #TASKS)
TASKS[3].cb(0, XML, "")
TASKS[4].cb(0, "kept\n", "")
check("a human's comment is kept, and says so quietly",
      saidLine("already has YOUR comment"))
realDoc(DOC, 42000, 333)
WATCHERS[1].fn({ DOC })
TIMERS[#TIMERS].fn()
TASKS[5].cb(0, XML, "")
printed = {}
TASKS[6].cb(1, "", "not allowed")
check("no Automation permission: ONE honest ⚠️ line naming the fix",
      saidLine("⚠️ Doc Keywords") and saidLine("Automation permission"))
realDoc(CLOUD .. "/tiny.docx", 100)
check("a placeholder-sized file is skipped",
      DK.process(CLOUD .. "/tiny.docx") == false)
check("a vanished file is skipped", DK.process(CLOUD .. "/gone.docx") == false)
printed = {}
local n = #TASKS
realDoc(CLOUD .. "/enc.docx")
DK.process(CLOUD .. "/enc.docx")
TASKS[#TASKS].cb(1, "", "unsupported compression")
check("an unreadable docx costs nothing and prints nothing",
      #printed == 0)

-- ---- 6. by hand & hostile -------------------------------------------
out("   6. _G.tagDoc, and a Mac where hs.task is gone\n")
printed = {}
_G.tagDoc("")
check("bare _G.tagDoc() teaches its own usage", saidLine("_G.tagDoc("))
realDoc(DOC, 43000, 444)
printed = {}
_G.tagDoc(DOC)
check("a path starts the read immediately (no debounce by hand)",
      TASKS[#TASKS].cmd == "/usr/bin/unzip" and saidLine("reading Q3 Report.docx"))
local savedTask = hs.task
hs.task = nil
realDoc(DOC, 44000, 555)
local okHostile = pcall(DK.process, DOC, true)
check("no hs.task: no throw", okHostile)
hs.task = savedTask

-- ---- 7. a sync burst is a RUN, not a flood (K6) ----------------------
-- 6.110.0. LL's Console log had several hundred 🏷 lines in it and four
-- real errors buried inside them. These checks are the reason that
-- cannot happen again: the readers are capped, the narration is capped,
-- and NOTHING is dropped to achieve either.
out("   7. a sync burst: capped readers, one summary, nothing lost\n")

-- Drive every outstanding task to completion, watching the cap hold.
-- Returns the highest number of readers that ever ran at once.
local function drain(writeResult, writeCode)
    local peak, i, guard = 0, 0, 0
    while i < #TASKS and guard < 4000 do
        i, guard = i + 1, guard + 1
        local t = TASKS[i]
        if not t.drained_ then
            t.drained_ = true
            if t.cmd == "/usr/bin/unzip" then t.cb(0, XML, "")
            else t.cb(writeCode or 0, writeResult or "written\n", "") end
        end
        if DK.inFlight > peak then peak = DK.inFlight end
    end
    return peak
end

local function bulkBoot(n)
    boot()
    ATTR[CLOUD] = { mode = "directory" }
    M.warm()
    local paths = {}
    for i = 1, n do
        local p = string.format("%s/bulk %02d.docx", CLOUD, i)
        realDoc(p, 40000, 900 + i)
        paths[#paths + 1] = p
    end
    printed = {}
    WATCHERS[1].fn(paths)
    TIMERS[#TIMERS].fn()               -- the flurry settles: the run starts
    return paths
end

bulkBoot(25)
check("only maxInFlight files are read at once — the rest wait in line",
      #TASKS == DK.maxInFlight and #DK.queue == 25 - DK.maxInFlight,
      #TASKS .. " reading, " .. #DK.queue .. " queued")
check("the run knows its own size", DK.batch and DK.batch.total == 25,
      DK.batch and DK.batch.total)
check("…and that it is far too big to narrate", DK.batch and DK.batch.quiet == true)
local peak = drain()
check("🚨 the reader cap held for the whole run — never a process storm",
      peak <= DK.maxInFlight, "peak " .. peak)
check("all 25 were read AND written — a cap delays, it never drops",
      #TASKS == 50, #TASKS)
check("🚨 not one per-file line for 25 files", (function()
    for _, l in ipairs(printed) do
        if l:find("Doc Keywords → ", 1, true) then return false, l end
    end
    return true
end)())
check("…but the session log kept every one of them", #DK.log == 25, #DK.log)
check("nothing is said until the run has been quiet for a settle",
      #printed == 0, printed[1])

-- A first sync dribbles in over minutes. That is ONE run, not thirty.
local late = CLOUD .. "/late.docx"
realDoc(late, 40000, 990)
WATCHERS[1].fn({ late })
TIMERS[#TIMERS].fn()
check("a later wave joins the run in progress — no summary in between",
      #printed == 0 and DK.batch and DK.batch.total == 26,
      DK.batch and DK.batch.total)
drain()
TIMERS[#TIMERS].fn()               -- the run finally goes quiet
check("ONE line closes the run, counting every file in it",
      #printed == 1 and printed[1]:find("26 tagged", 1, true) ~= nil,
      printed[1] or "(silence)")
check("…and it points at where the detail lives",
      (printed[1] or ""):find("_G.docKeywordsReport", 1, true) ~= nil)
check("the run is closed out clean",
      DK.batch == nil and DK.inFlight == 0 and #DK.queue == 0)

-- Small is still chatty: saving a document must still show its keywords.
bulkBoot(2)
drain()
check("a run of 2 still names every file — the feature, not the flood",
      saidLine("bulk 01.docx") and saidLine("bulk 02.docx"))
check("…and prints no summary over the top of them", not saidLine("in 0s"))

-- Asked for by name = answered by name, however loud the room is.
bulkBoot(25)
local byHand = CLOUD .. "/by hand.docx"
realDoc(byHand, 40000, 991)
printed = {}
_G.tagDoc(byHand)
TASKS[#TASKS].cb(0, XML, "")
TASKS[#TASKS].cb(0, "written\n", "")
check("_G.tagDoc names ITS file even while a quiet run is going",
      saidLine("🏷 Doc Keywords → by hand.docx"))
check("…and the quiet run around it stayed quiet", (function()
    for _, l in ipairs(printed) do
        if l:find("Doc Keywords → ", 1, true)
           and not l:find("by hand.docx", 1, true) then return false, l end
    end
    return true
end)())

-- One cause, one line. Not one line per file for the same locked-down Mac.
bulkBoot(10)
drain("", 1)
TIMERS[#TIMERS].fn()
check("🚨 a Mac that refuses every write says so ONCE, naming the fix",
      #printed == 1 and printed[1]:find("refused all 10", 1, true) ~= nil
      and printed[1]:find("Automation permission", 1, true) ~= nil,
      printed[1] or "(silence)")

-- =====================================================================
out(string.format("\n── test_doc_keywords: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
