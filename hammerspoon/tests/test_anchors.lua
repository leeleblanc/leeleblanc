-- =====================================================================
-- test_anchors.lua — ⇪⇧U: link what is in front of you to a note
-- =====================================================================
--     lua5.4 test_anchors.lua [/path/to/hammerspoon]
--
-- The claims under test: ⇪⇧U identifies a browser tab (osascript, held
-- task, killed on its own timer), a document (through doc_memory's
-- docs.front and nothing else), or the app alone — and never blocks on
-- any of them; the link it writes is PLAIN MARKDOWN so Obsidian can open
-- it; the reverse lookup is a grep over the vault with no store of its
-- own, and falls back to the file's NAME so a note written before the
-- file moved is still found; a moved file is resolved through the ⇪D
-- index; and every missing dependency — no vault, no doc reader, no file
-- index, a browser that never answers — degrades to a message instead of
-- a failure.

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

local PRINTED = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- ---- a controllable Mac ------------------------------------------------
local ALERTS, TIMERS, TASKS, CHOOSERS = {}, {}, {}, {}
local FRONT_APP = "Google Chrome"
local FS = { ["/Users/lee/Contract.docx"] = true }

local function mkTask(bin, cb, args)
    local t = { bin = bin, cb = cb, args = args, started = false, killed = false }
    function t:start() self.started = true; TASKS[#TASKS + 1] = self; return self end
    function t:terminate() self.killed = true; return self end
    return t
end

hs = {
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        doAfter = function(s, fn)
            local t = { secs = s, fn = fn, live = true }
            function t:stop() self.live = false; return self end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = { new = function(bin, cb, args) return mkTask(bin, cb, args) end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    application = { frontmostApplication = function()
        if not FRONT_APP then return nil end
        return { name = function() return FRONT_APP end }
    end },
    chooser = { new = function(cb)
        local c = { cb = cb, rows = {}, shown = false }
        function c:choices(r) self.rows = r; return self end
        function c:placeholderText(t) self.ph = t; return self end
        function c:searchSubText() return self end
        function c:width() return self end
        function c:show() self.shown = true; return self end
        CHOOSERS[#CHOOSERS + 1] = c
        return c
    end },
    fs = { attributes = function(p) return FS[p] and { mode = "file" } or nil end },
    urlevent = { openURL = function() end },
    open = function() return true end,
    settings = { get = function() end, set = function() end },
}

_G.diag = { say = function() end, warn = function() end, err = function() end }

-- ---- the service registry, exactly as init.lua publishes it ------------
local SERVICES, CALLS = {}, {}
_G.service = {
    has  = function(n) return SERVICES[n] ~= nil end,
    call = function(n, ...)
        CALLS[#CALLS + 1] = n
        if not SERVICES[n] then return false, "not loaded" end
        return true, SERVICES[n](...)
    end,
}
local HYPER = {}
local CORE = {
    logsDir = "/logs",
    provide = function(n, f) SERVICES[n] = f end,
    hyperAddShortcut = function(mods, key, fn, _, _, src)
        HYPER[table.concat(mods or {}, "+") .. "|" .. tostring(key)] = { fn = fn, src = src }
    end,
    showPopup = function(c) c:show() end,
}

-- the vault, as a service surface only (the module must not reach past it)
local VAULT = { dir = "/vault", notes = {}, linked = {}, shown = 0 }
_G.vault = VAULT
SERVICES["vault.link"] = function(name, line)
    VAULT.linked[#VAULT.linked + 1] = { name = name, line = line }
    return true, "linked"
end
SERVICES["vault.names"] = function() return { "Alpha", "Beta" } end
SERVICES["vault.open"]  = function(n) VAULT.opened = n; return true end
SERVICES["vault.show"]  = function() VAULT.shown = VAULT.shown + 1; return true end
SERVICES["docs.front"]  = function()
    return { path = "/Users/lee/Contract.docx", title = "Contract.docx", app = "Microsoft Word" }
end
SERVICES["index.search"] = function(q)
    if q == "Contract.docx" then
        return { { path = "/Users/lee/Archive/2026/Contract.docx" } }
    end
    return {}
end

local mod = dofile(HS .. "/modules/anchors.lua")
mod.setup(CORE)
local anc = _G.anchors

local function lastChooser() return CHOOSERS[#CHOOSERS] end
local function runTasks(outText, code)
    local list = TASKS
    TASKS = {}
    for _, t in ipairs(list) do
        if not t.killed then t.cb(code or 0, outText or "", "") end
    end
end
-- 🚨 6.262.0. The hop is a doAfter(0) — the turn a task's callback steps
-- off onto before the next task starts (6.196.1). It is fired APART from
-- the killer timer, because firing every timer at once would run a
-- four-second watchdog at time zero and call the answer a timeout.
local function fireHops()
    local keep, hops = {}, {}
    for _, t in ipairs(TIMERS) do
        if t.live and t.secs == 0 then hops[#hops + 1] = t else keep[#keep + 1] = t end
    end
    TIMERS = keep
    for _, t in ipairs(hops) do t.fn() end
    return #hops
end
local function fireTimers()
    local live = {}
    for _, t in ipairs(TIMERS) do if t.live then live[#live + 1] = t end end
    TIMERS = {}
    for _, t in ipairs(live) do t.fn() end
end

-- =======================================================================
out("1) the door in\n")
-- =======================================================================
check("⇪⇧U is claimed, and nothing else is", HYPER["shift|u"] ~= nil
      and HYPER["shift|u"].src == "anchors" and HYPER["|u"] == nil)
check("the services are published",
      SERVICES["anchors.show"] and SERVICES["anchors.resolve"] and SERVICES["anchors.report"])
check("_G.anchorsReport exists", type(_G.anchorsReport) == "function")

-- =======================================================================
out("2) the link is plain Markdown — Obsidian has to be able to open it\n")
-- =======================================================================
local line = anc.linkLine({ url = "file:///Users/lee/Contract.docx", title = "Contract.docx", app = "Microsoft Word" })
check("it is a Markdown list item with the title and the URL",
      line:find("^%- %[Contract%.docx%]%(file:///Users/lee/Contract%.docx%)") ~= nil, line)
check("...and it says which app it came from and when",
      line:find("Microsoft Word", 1, true) and line:find(os.date("%Y-%m-%d"), 1, true))
check("a title with brackets or newlines cannot break the link", (function()
    local l = anc.linkLine({ url = "https://x/y", title = "a [bad] title\nwith a newline", app = "Safari" })
    return l:find("^%- %[a bad title with a newline%]%(https://x/y%)") ~= nil, l
end)())
check("a very long title is cut, not passed through", (function()
    local l = anc.linkLine({ url = "https://x", title = string.rep("z", 300), app = "Safari" })
    return #l < 200
end)())
check("a space in a path is encoded, or the link stops at the space",
      anc.fileURL("/Users/lee/My File.docx") == "file:///Users/lee/My%20File.docx",
      anc.fileURL("/Users/lee/My File.docx"))
check("...and so are the characters Markdown would eat",
      anc.fileURL("/a/b(c)#d.docx") == "file:///a/b%28c%29%23d.docx", anc.fileURL("/a/b(c)#d.docx"))
check("no url means no line — an app-only target is not written as a link",
      anc.linkLine({ title = "Word", app = "Microsoft Word" }) == nil)

-- =======================================================================
out("3) what is in front — a browser tab, without blocking\n")
-- =======================================================================
FRONT_APP = "Google Chrome"
local got
anc.identify(function(t, why) got = { t = t, why = why } end)
check("a browser is asked through osascript, in a task", #TASKS == 1 and TASKS[1].bin == "/usr/bin/osascript")
check("...and the answer has not arrived yet — nothing blocked", got == nil)
check("...and a killer timer is held, so a silent browser cannot hang it",
      anc.killer ~= nil and #TIMERS >= 1)
runTasks("https://example.com/page\nExample — the page title")
check("🚨 the callback does NOT answer inside its own frame — it hops first",
      got == nil, got and "answered inside the task callback")
check("...and the hop is a HELD timer in its own slot", anc.hops.tab ~= nil)
check("...and the task is still referenced while its callback runs", anc.tasks.tab ~= nil)
fireHops()
check("...and the slot is let go once the callback has RETURNED", anc.tasks.tab == nil)
check("the tab becomes a target", got and got.t and got.t.kind == "tab"
      and got.t.url == "https://example.com/page"
      and got.t.title == "Example — the page title", got and got.t and got.t.url)
check("...and the killer timer was stopped once the answer came", anc.killer == nil)

got = nil
anc.identify(function(t, why) got = { t = t, why = why } end)
runTasks("", 1)
fireHops()
check("a browser that refuses Automation says so, and does not pretend",
      got and got.t == nil and tostring(got.why):find("did not answer", 1, true) ~= nil,
      got and tostring(got.why))

got = nil
anc.identify(function(t, why) got = { t = t, why = why } end)
local killer = anc.killer
fireTimers()
check("a browser that never answers is KILLED on its own timer and named",
      got and got.t == nil and tostring(got.why):find("did not answer in", 1, true) ~= nil,
      got and tostring(got.why))
TASKS = {}

check("Safari and the Chromium browsers get DIFFERENT scripts — the 6.152.0 fault",
      anc.script("Safari", "Safari"):find("front document", 1, true) ~= nil
      and anc.script("Google Chrome", "chromium"):find("active tab", 1, true) ~= nil)

-- =======================================================================
out("4) a document, through doc_memory and nothing else\n")
-- =======================================================================
FRONT_APP = "Microsoft Word"
got = nil
anc.identify(function(t, why) got = { t = t, why = why } end)
check("the front document becomes a file target",
      got and got.t and got.t.kind == "file"
      and got.t.path == "/Users/lee/Contract.docx"
      and got.t.url == "file:///Users/lee/Contract.docx", got and got.t and got.t.url)
check("...read through the docs.front SERVICE, never by reaching into the module", (function()
    local saw = false
    for _, c in ipairs(CALLS) do if c == "docs.front" then saw = true end end
    local src = (function() local f = io.open(HS .. "/modules/anchors.lua"); local s = f:read("a"); f:close(); return s end)()
    return saw and not src:find("axuielement", 1, true) and not src:find("_G.docMemory", 1, true)
end)())

local keep = SERVICES["docs.front"]
SERVICES["docs.front"] = nil
got = nil
anc.identify(function(t, why) got = { t = t, why = why } end)
check("with no document reader at all it still anchors the APP, and says why",
      got and got.t and got.t.kind == "app" and got.t.title == "Microsoft Word"
      and tostring(got.why):find("app only", 1, true) ~= nil, got and got.t and got.t.kind)
SERVICES["docs.front"] = keep

FRONT_APP = nil
got = nil
anc.identify(function(t, why) got = { t = t, why = why } end)
check("no front app at all is a message, not a crash", got and got.t == nil)
FRONT_APP = "Microsoft Word"

-- =======================================================================
out("5) which notes already link it — a grep, and no store of its own\n")
-- =======================================================================
local found
anc.notesFor({ path = "/Users/lee/Contract.docx" }, function(n, why) found = { n = n, why = why } end)
check("it greps the vault for the path", #TASKS == 1 and TASKS[1].bin == "/usr/bin/grep"
      and TASKS[1].args[#TASKS[1].args] == "/vault", TASKS[1] and TASKS[1].bin)
check("...for FIXED strings, and only .md files", (function()
    local a = table.concat(TASKS[1].args, " ")
    return a:find("-rlF", 1, true) and a:find("--include=*.md", 1, true)
end)(), TASKS[1] and table.concat(TASKS[1].args, " "))
runTasks("/vault/Contracts/Acme.md\n/vault/Daily/2026-09-07.md")
check("🚨 the grep callback hands over through the hop, never directly",
      found == nil and anc.hops.grep ~= nil, found and "answered inside the grep callback")
fireHops()
check("the notes come back by NAME, ready for the picker",
      found and #found.n == 2 and found.n[1].name == "Acme"
      and found.n[2].name == "2026-09-07", found and found.n and #found.n)

-- the fallback that survives a move
found = nil
TASKS = {}
anc.notesFor({ path = "/Users/lee/Contract.docx" }, function(n) found = n end)
runTasks("")                                     -- nothing matched the full path
-- 🚨 THE CRASH PATH ITSELF (6.196.1, and the reason 6.262.0 exists).
-- The basename grep runs whenever the path grep found nothing, which is
-- every ⇪⇧U on a document that has no note yet — so this is the common
-- case, not a rare one. Started from inside the first grep's callback it
-- would drop the last reference to the task whose callback is RUNNING,
-- and hs.task's finaliser tears the NSTask and the block down underneath
-- the live frame: no Lua error, nothing in the Console, the app gone.
check("🚨 the SECOND grep does not start inside the first one's callback",
      #TASKS == 0, #TASKS .. " task(s) started from inside the callback")
check("...the first grep is still referenced while its callback runs", anc.tasks.grep ~= nil)
check("...and the next step is held on its own hop timer", anc.hops.grep ~= nil)
fireHops()
check("nothing on the path → it tries the file's NAME next, a turn later", #TASKS == 1
      and table.concat(TASKS[1].args, " "):find("Contract.docx", 1, true) ~= nil,
      TASKS[1] and table.concat(TASKS[1].args, " "))
runTasks("/vault/Contracts/Acme.md")
fireHops()
check("...which is how a note written before the file moved is still found",
      found and #found == 1 and found[1].name == "Acme")

found = nil
TASKS = {}
local savedDir = VAULT.dir
_G.vault = nil
anc.notesFor({ path = "/x" }, function(n, why) found = { n = n, why = why } end)
check("no vault loaded → an empty answer with a reason, and no task started",
      found and #found.n == 0 and tostring(found.why):find("not loaded", 1, true) and #TASKS == 0)
_G.vault = VAULT

-- 🛠 AND A MAC THAT CANNOT ARM A TIMER STILL GETS ITS ANSWER. The hop
-- is the safe path, not the whole feature: if hs.timer.doAfter is gone
-- the work happens on the old path and the REPORT says so, because a
-- count that only ever reads as health answers nothing (6.196.1).
do
    PRINTED = {}
    _G.anchorsReport()
    check("a healthy Mac's report says how many callbacks stepped off a held timer",
          table.concat(PRINTED, "\n"):find("stepped off a held timer", 1, true) ~= nil,
          table.concat(PRINTED, "\n"))
    local keepDoAfter = hs.timer.doAfter
    hs.timer.doAfter = function() error("no timers on this Mac", 0) end
    local before = anc.hopsMissed
    found, TASKS = nil, {}
    anc.notesFor({ path = "/Users/lee/Contract.docx" }, function(n) found = n end)
    runTasks("/vault/Contracts/Acme.md")
    check("no hs.timer.doAfter → the answer still arrives", found and #found == 1, found and #found)
    check("...and the missed hop is COUNTED, not swallowed", anc.hopsMissed == before + 1,
          anc.hopsMissed)
    PRINTED = {}
    _G.anchorsReport()
    local rep = table.concat(PRINTED, "\n")
    check("...and the report leads with the ⚠️, not with a healthy-looking number",
          rep:find("could NOT step off", 1, true) ~= nil, rep)
    hs.timer.doAfter = keepDoAfter
    PRINTED = {}
    _G.anchorsReport()
    check("...and it goes on saying so afterwards — a missed hop is not forgotten "
          .. "the moment the next one works",
          table.concat(PRINTED, "\n"):find("could NOT step off", 1, true) ~= nil)
end

-- =======================================================================
out("6) 🚚 move survival — the link is the filename, so the index can find it\n")
-- =======================================================================
check("a moved file is found again by name through the ⇪D index",
      anc.resolve("/Users/lee/Contract.docx") == "/Users/lee/Archive/2026/Contract.docx",
      anc.resolve("/Users/lee/Contract.docx"))
check("...and the count is in the report", anc.resolved >= 1)
check("a file the index does not know is NOT guessed at",
      anc.resolve("/Users/lee/Nothing.pdf") == nil)
local keepIdx = SERVICES["index.search"]
SERVICES["index.search"] = nil
check("no file index → nil, so the vault says 'it has moved' instead of opening the wrong thing",
      anc.resolve("/Users/lee/Contract.docx") == nil)
SERVICES["index.search"] = keepIdx

-- =======================================================================
out("7) the picker, and what each row does\n")
-- =======================================================================
local target = { kind = "file", url = "file:///Users/lee/Contract.docx",
                 path = "/Users/lee/Contract.docx", title = "Contract.docx", app = "Microsoft Word" }
anc.present(target, { { name = "Acme", rel = "Contracts/Acme.md" } })
local ch = lastChooser()
check("the notes that already link it come FIRST — that is the 'hooked' list",
      ch.rows[1].act == "open" and ch.rows[1].text:find("Acme", 1, true) ~= nil, ch.rows[1].text)
check("...then a row that makes a note named after the thing",
      ch.rows[2].act == "new" and ch.rows[2].name == "Contract.docx", ch.rows[2].text)
check("...then a row to pick any existing note", ch.rows[3].act == "pick")
check("the placeholder says what it identified",
      ch.ph:find("document: Contract.docx", 1, true) ~= nil, ch.ph)
check("the picker is filed for Esc", _G.choosers.anchors ~= nil)

VAULT.linked = {}
ch.cb({ act = "new", name = "Contract.docx" })
check("⏎ on the new row writes ONE Markdown line into that note",
      #VAULT.linked == 1 and VAULT.linked[1].name == "Contract.docx"
      and VAULT.linked[1].line:find("file:///Users/lee/Contract.docx", 1, true) ~= nil,
      VAULT.linked[1] and VAULT.linked[1].line)
check("...and the vault window is brought up on it", VAULT.shown >= 1)
check("...and it says so on screen", tostring(ALERTS[#ALERTS]):find("Linked into", 1, true) ~= nil,
      ALERTS[#ALERTS])

ch.cb({ act = "open", name = "Acme" })
check("⏎ on a linked note opens that note", VAULT.opened == "Acme")

ch.cb({ act = "pick" })
local pick = lastChooser()
check("the pick row offers every note in the vault",
      #pick.rows == 2 and pick.rows[1].text == "Alpha", #pick.rows)
VAULT.linked = {}
pick.cb({ name = "Beta" })
check("...and picking one links into it", #VAULT.linked == 1 and VAULT.linked[1].name == "Beta")

-- =======================================================================
out("8) degrade — every missing piece is a message, never a failure\n")
-- =======================================================================
local keepLink = SERVICES["vault.link"]
SERVICES["vault.link"] = nil
ALERTS = {}
check("no vault module → ⇪⇧U says so and does nothing else",
      anc.show() == false and tostring(ALERTS[1]):find("Hamsidian is not loaded", 1, true) ~= nil,
      ALERTS[1])
SERVICES["vault.link"] = keepLink

check("a link into a note that cannot be written is reported, not swallowed", (function()
    SERVICES["vault.link"] = function() return false, "read-only" end
    local ok, why = anc.linkInto("Alpha", target)
    SERVICES["vault.link"] = keepLink
    return ok == false and tostring(why):find("read%-only")
end)())

check("the whole show() path survives a world where nothing is loaded", (function()
    local saved = SERVICES
    local ok = pcall(function()
        anc.show()
    end)
    SERVICES = saved
    return ok
end)())

-- =======================================================================
out("9) the source itself — the rules this module has to keep\n")
-- =======================================================================
do
    local f = io.open(HS .. "/modules/anchors.lua", "r")
    local src = f:read("a"); f:close()
    check("🔒 it never reads your text: no clipboard, no pasteboard, no keystrokes",
          not src:find("pasteboard", 1, true) and not src:find("eventtap", 1, true)
          and not src:find("keyStroke", 1, true))
    check("🔒 and it never reads a file's CONTENTS — only paths and titles",
          not src:find("io.open", 1, true) and not src:find("readFile", 1, true))
    -- 🚨 6.262.0 — ASSERTED AGAINST THE SOURCE, deliberately (6.196.1):
    -- a stub hs.task is collected by nobody, so a functional test of this
    -- class passes just as happily with the bug in.
    -- the sentries read the CODE, never the comments: the comments are
    -- where the story of the bug lives, and one of them quotes the line
    -- being banned (test_scratch_pad's rename sentry, same reason).
    local code = src:gsub("\n%s*%-%-[^\n]*", "\n")
    check("🚨 the tasks live in SEPARATE SLOTS — no single `task` field to overwrite",
          code:find("anc%.task%s*=") == nil and code:find("grepTask") == nil
          and code:find("anc.tasks.grep = task", 1, true) ~= nil
          and code:find("anc.tasks.tab = task", 1, true) ~= nil)
    check("🚨 the grep callback does not start the next grep — it hops", (function()
        local body = code:match("hs%.task%.new, GREP.-end, args")
        if not body then return false, "the grep task moved" end
        return body:find('anc.hop("grep"', 1, true) ~= nil
               and body:find("%f[%w]step%(%)") == nil
    end)())
    check("🚨 ...and the osascript callback does not answer inside its own frame",
          (function()
        local body = code:match("hs%.task%.new, OSASCRIPT.-end, { \"%-e\"")
        if not body then return false, "the osascript task moved" end
        -- finish() is called, but only from INSIDE the hop's closure:
        -- banning the name outright would be a sentry nobody could keep.
        return body:find('anc.hop("tab", function() finish(', 1, true) ~= nil
               and body:find("return finish%(") == nil
               and body:find("%f[%w]cb%(") == nil
    end)())
    check("🚨 ...and no callback releases the slot it is running in",
          code:find("anc%.tasks%.tab%s*=%s*nil") == nil
          and code:find("anc%.tasks%.grep%s*=%s*nil") == nil)
    check("every timer it makes is HELD (the 6.16.18 rule)",
          not src:find("\n%s+hs%.timer%.doAfter"), "an unheld timer would be GC'd")
    check("it reaches other modules through the SERVICE registry only",
          not src:find("_G.searchIndex", 1, true) and not src:find("_G.docMemory", 1, true)
          and src:find('call("vault.link"', 1, true) ~= nil)
    check("the picker goes through core.showPopup, never a bare :show()",
          src:find("core.showPopup", 1, true) ~= nil)
    check("it declares its cheat sheet and a unique order",
          src:find("cheatsheet", 1, true) and src:find("order = 13.995", 1, true))
    check("the vault carries the other half: a file:// link is followed, "
          .. "and a moved file asks anchors.resolve", (function()
        local vf = io.open(HS .. "/modules/vault.lua", "r")
        local v = vf:read("a"); vf:close()
        return v:find('scheme == "file"', 1, true)
               and v:find('anchors.resolve', 1, true)
               and v:find('provide("vault.link"', 1, true)
    end)())
end

print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
