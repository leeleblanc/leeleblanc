-- =====================================================================
-- test_vault.lua — ⇪3: linked Markdown notes in OneDrive, backlinks, graph
-- =====================================================================
--     lua5.4 test_vault.lua [/path/to/hammerspoon]
--
-- The claims under test: the vault is <OneDrive>/Vault (local fallback
-- without OneDrive); the index comes from find + grep in hs.task, never
-- from reading every file; [[Target|alias]] / [[Target#h]] resolve to
-- Target case-insensitively; backlinks are the inverse of links and a
-- name with no file is "unresolved" (a hollow dot); opening a note reads
-- ONE file, a missing one is created with a heading; every keystroke
-- lands in Lua and the .md file is written after the debounce (tmp +
-- rename), at once on switching and closing; a save re-parses the note's
-- links without a rescan; ⌘D opens Daily/<date>.md; following a
-- Markdown link resolves relative to the note; ⌘K writes a relative
-- link; the page carries the row walker and the ⇪ keyup forward; the
-- prompt fallback still edits and saves; no eventtap, no hs.window read.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail = 0, 0
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        io.write("   ❌ " .. label .. (extra and ("  [" .. tostring(extra) .. "]") or "") .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a controllable world ------------------------------------------------
local FILES, WRITE_FAILS, READS = {}, false, {}
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        if WRITE_FAILS then return nil end
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s return true end,
                 close = function() FILES[path] = table.concat(buf) end }
    end
    READS[#READS + 1] = path
    if FILES[path] == nil then return nil end
    local content, done = FILES[path], false
    return { read = function() if done then return nil end done = true return content end,
             close = function() end }
end
os.rename = function(a, b)
    if FILES[a] == nil then return nil, "no such file" end
    FILES[b] = FILES[a]; FILES[a] = nil
    return true
end

local ALERTS, PROVIDED, WEBVIEWS, PROMPTS, TIMERS, PRINTED, TASKS, OPENED, SETTINGS = {}, {}, {}, {}, {}, {}, {}, {}, {}
local PROMPT_ANSWERS = {}
local UC_CALLBACK, EVALS = nil, {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

local function newWebviewStub(rect)
    local v = { rect = rect, _style = 0, deleted = false, shown = 0, htmlSet = nil }
    function v:windowTitle(t) self.title = t return self end
    function v:allowTextEntry(x) self.textEntry = x return self end
    function v:alpha(a) self.alphaSet = a return self end
    function v:closeOnEscape(x) return self end
    function v:level(l) return self end
    function v:behaviorAsLabels(b) return self end
    function v:windowStyle(x) if x ~= nil then self._style = x end return self._style end
    function v:html(h) self.htmlSet = h return self end
    function v:show() self.shown = self.shown + 1 return self end
    function v:hide() return self end
    function v:bringToFront() return self end
    function v:delete() self.deleted = true return self end
    function v:frame(f) if f then self.rect = f end return self.rect end
    function v:evaluateJavaScript(js) EVALS[#EVALS + 1] = js return self end
    return v
end
local function mkTimer(kind, delay, fn)
    local t = { kind = kind, delay = delay, fn = fn, stopped = false }
    function t:stop() self.stopped = true end
    function t:fire() if not self.stopped then self.fn() end end
    TIMERS[#TIMERS + 1] = t
    return t
end

hs = {
    webview = {
        windowMasks = { nonactivating = 128 },
        usercontent = { new = function(name)
            local uc = { name = name }
            function uc:setCallback(fn) UC_CALLBACK = fn end
            return uc
        end },
        new = function(rect) local v = newWebviewStub(rect); WEBVIEWS[#WEBVIEWS + 1] = v; return v end,
    },
    screen = { mainScreen = function() return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end } end },
    drawing = { windowLevels = { floating = 5 } },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    dialog = {
        textPrompt = function(title, msg, dflt)
            PROMPTS[#PROMPTS + 1] = { title = title, msg = msg, dflt = dflt }
            local a = table.remove(PROMPT_ANSWERS, 1) or { "Cancel", "" }
            return a[1], a[2]
        end,
        chooseFileOrFolder = function() return { ["1"] = "file:///Users/ll/OneDrive/Documents/Plans/Q4%20plan.pdf" } end,
    },
    timer = {
        doAfter = function(d, fn) return mkTimer("after", d, fn) end,
        doEvery = function(d, fn) return mkTimer("every", d, fn) end,
    },
    fs = { mkdir = function() return true end },
    mouse = { absolutePosition = function() return { x = 300, y = 300 } end },
    eventtap = { checkMouseButtons = function() return { left = false } end },
    settings = { get = function(k) return SETTINGS[k] end, set = function(k, x) SETTINGS[k] = x end },
    task = { new = function(bin, cb, args)
        local t = { bin = bin, cb = cb, args = args, started = false, terminated = false }
        function t:start() self.started = true return true end
        -- 6.174.0 — A KILLED RUN EXITS TOO (chrome_history's 6.148.0
        -- lesson): terminate() still delivers the callback, with the
        -- signal's exit code. The stub does the same, so the suite sees
        -- what the real hs.task would do.
        function t:terminate()
            self.terminated = true
            if self.cb then pcall(self.cb, 15, "", "") end
        end
        TASKS[#TASKS + 1] = t
        return t
    end },
    open = function(p) OPENED[#OPENED + 1] = p return true end,
    urlevent = { openURL = function(u) OPENED[#OPENED + 1] = u return true end },
}

_G.diag = { say = function() end, warn = function() end }
local CLAIMED_ESC = {}
_G.claimEscape = function(name, _, present, close) CLAIMED_ESC[name] = { present = present, close = close } end
_G.movablePanels, _G.editors = {}, {}
local HYPER, WRITE_WARNS, EXPECTED, SEEN = {}, {}, {}, {}
_G.hyperExpectRelease = function(secs, who) EXPECTED[#EXPECTED + 1] = { secs = secs, who = who } return true end
_G.hyperReleaseSeen = function(who) SEEN[#SEEN + 1] = who return true end
local CORE = {
    cloudDir = "/Users/ll/OneDrive", logsDir = "/Users/ll/OneDrive/Logs",
    provide = function(n, f) PROVIDED[n] = f end,
    hyperAddShortcut = function(mods, key, fn, src)
        HYPER[table.concat(mods or {}, "+") .. "|" .. tostring(key)] = { fn = fn, src = src }
    end,
    warnWriteFailed = function(what) WRITE_WARNS[#WRITE_WARNS + 1] = what end,
}

local mod = dofile(HS .. "/modules/vault.lua")
mod.setup(CORE)
local v = _G.vault
local VAULT = "/Users/ll/OneDrive/Vault"
local function msg(m) v.handleMessage(m) end
local function lastTimer(kind)
    for i = #TIMERS, 1, -1 do if TIMERS[i].kind == kind and not TIMERS[i].stopped then return TIMERS[i] end end
end
local function lastTask(bin)
    for i = #TASKS, 1, -1 do if TASKS[i].bin:match(bin) then return TASKS[i] end end
end
-- 6.174.0 — the newest task of a binary whose ARGS carry a flag (find /
-- the link grep / the tag greps / search / tasks / mentions share bins)
local function taskArgs(t) return t and table.concat(t.args, " ") or "" end
local function lastTaskWith(bin, needle)
    for i = #TASKS, 1, -1 do
        if TASKS[i].bin:match(bin) and taskArgs(TASKS[i]):find(needle, 1, true) then return TASKS[i] end
    end
end
local function countTasks(bin)
    local n = 0
    for _, t in ipairs(TASKS) do if t.bin:match(bin) then n = n + 1 end end
    return n
end
-- the scan chain since 6.174.0: after the LINK grep answers, a TAG grep and
-- then a FRONT-MATTER grep follow; this feeds both "no match"
local function finishTagGreps(tagOut, fmOut)
    local tg = lastTaskWith("grep", "-rHoIE")
    if tg then tg.cb(tagOut and 0 or 1, tagOut or "", "") end
    local fg = lastTaskWith("grep", "^---")
    if fg then fg.cb(fmOut and 0 or 1, fmOut or "", "") end
end

-- =======================================================================
out("1) the doors in — ⇪3, the folder, escape claim, services, no forbidden calls\n")
-- =======================================================================
check("⇪3 is claimed for the vault", HYPER["|3"] ~= nil and HYPER["|3"].src == "vault")
check("the vault is <OneDrive>/Vault", v.dir == VAULT, v.dir)
check("the escape router knows 'vault'", CLAIMED_ESC.vault ~= nil)
check("an editors row and a movable panel row exist", #_G.editors == 1 and #_G.movablePanels == 1)
check("vault.show / open / rescan / report are published",
      PROVIDED["vault.show"] and PROVIDED["vault.open"] and PROVIDED["vault.rescan"] and PROVIDED["vault.report"])
check("the cheat sheet names ⇪3, ⇪1 and Obsidian", mod.cheatsheet.title:find("⇪3") and mod.cheatsheet.title:find("⇪1") and (function()
    for _, e in ipairs(mod.cheatsheet.entries) do if e[1] == "Obsidian" then return true end end end)())
do
    local src = io.open(HS .. "/modules/vault.lua") and "" or ""
    local f = io.open(HS .. "/modules/vault.lua", "r")
    local real = nil
    -- the stubbed io.open only knows FILES; read the source through the real loader instead
    local chunk = loadfile(HS .. "/modules/vault.lua")
    check("the module compiles", chunk ~= nil)
    local rf = io.popen and io.popen("cat '" .. HS .. "/modules/vault.lua'")
    real = rf and rf:read("a") or ""
    if rf then rf:close() end
    check("no eventtap is created (the page's keydown is the only key handler)", not real:find("hs%.eventtap%.new"))
    check("no hs.window read", not real:find("hs%.window%."))
    check("the index comes from find and grep in hs.task", real:find("hs%.task%.new, v%.FIND") and real:find("hs%.task%.new, v%.GREP"))
    check("every timer is held (doAfter/doEvery results assigned)", not real:find("\n%s*hs%.timer%.do"))
end
do
    local other = dofile(HS .. "/modules/vault.lua")
    other.setup({ logsDir = "/logs", provide = function() end, hyperAddShortcut = function() end })
    check("without OneDrive the vault is <logsDir>/vault", other.config.dir == "/logs/vault", other.config.dir)
    mod.setup(CORE); v = _G.vault    -- back to the OneDrive world
end

-- =======================================================================
out("2) links — targets, resolution, backlinks, unresolved\n")
-- =======================================================================
check("[[Target|alias]] and [[Target#Heading]] both resolve to Target",
      v.linkTarget("Target|shown") == "Target" and v.linkTarget(" Target#Part 2 ") == "Target")
local ls = v.linksIn("see [[Alpha]] and [[beta|B]] then [[alpha#top]] and [[Gamma]]")
check("linksIn dedupes case-insensitively and keeps order", #ls == 3 and ls[1] == "Alpha" and ls[2] == "beta" and ls[3] == "Gamma", table.concat(ls, ","))

-- =======================================================================
out("3) the index — find, then grep, both off the main thread\n")
-- =======================================================================
READS = {}
local ok = v.scan("test")
check("scan starts a find task on the vault folder", ok == true and lastTask("find") and lastTask("find").started and lastTask("find").args[1] == VAULT)
check("find prunes .obsidian", table.concat(lastTask("find").args, " "):find("%.obsidian") ~= nil)
check("scanning flag is up and a second scan is refused", v.scanning == true and select(2, v.scan("again")) == "already scanning")
lastTask("find").cb(0, VAULT .. "/Alpha.md\n" .. VAULT .. "/Projects/Beta.md\n" .. VAULT .. "/Gamma.md\n", "")
check("three notes indexed, sorted by name, found case-insensitively",
      #v.notes == 3 and v.notes[1].name == "Alpha" and v.notes[2].name == "Beta" and v.find("beta") and v.find("BETA").rel == "Projects/Beta.md")
check("the grep task followed, excluding .obsidian", lastTask("grep") and lastTask("grep").started
      and table.concat(lastTask("grep").args, " "):find("exclude%-dir=%.obsidian") ~= nil)
lastTask("grep").cb(0, VAULT .. "/Alpha.md:[[Beta|B]]\n" .. VAULT .. "/Alpha.md:[[Gamma]]\n" .. VAULT .. "/Projects/Beta.md:[[alpha]]\n" .. VAULT .. "/Gamma.md:[[Delta]]\n", "")
do  -- 6.174.0 — two more greps follow the links: #tags (-o, the wide shape), then front-matter tags:
    local tg = lastTask("grep")
    check("6.174.0: a TAG grep follows the link grep (-rHoIE, the wide #shape, not the [[ pattern)",
          tg and tg.started and taskArgs(tg):find("-rHoIE", 1, true) and taskArgs(tg):find("#[^[:space:]#]+", 1, true)
          and taskArgs(tg):find("exclude-dir=.obsidian", 1, true) and not taskArgs(tg):find("\\[\\[", 1, true), taskArgs(tg))
    check("…the scan is still running while it does", v.scanning == true and v.tagTask == tg)
    tg.cb(1, "", "")
    local fg = lastTask("grep")
    -- 6.185.0 — it asks for the opening --- and reads the WHOLE block, so
    -- one grep builds both the tag index and the query FIELDS
    check("…then a FRONT-MATTER grep (-m 1 -A 30, the opening ---)", fg and fg ~= tg and fg.started
          and taskArgs(fg):find("-m 1 -A 30", 1, true) and taskArgs(fg):find("^---[[:space:]]*$", 1, true)
          and taskArgs(fg):find("^tags?:", 1, true) == nil and v.fmTask == fg, taskArgs(fg))
    fg.cb(1, "", "")
    check("…and both fields are released when the chain ends", v.tagTask == nil and v.fmTask == nil)
end
check("scan finished: links per note", v.scanning == false and v.scanErr == nil and #v.links["Alpha.md"] == 2 and v.links["Projects/Beta.md"][1] == "alpha")
check("backlinks are the inverse (Alpha ← Beta, Beta ← Alpha)",
      v.backlinks.alpha and v.backlinks.alpha[1] == "Projects/Beta.md" and v.backlinks.beta and v.backlinks.beta[1] == "Alpha.md")
check("Delta has no file: unresolved, remembered by name", v.unresolved.delta and v.unresolved.delta.name == "Delta" and v.unresolved.delta.from[1] == "Gamma.md")
check("no note file was READ to build the index", #READS == 0, #READS)
do
    local g = v.graphJson()
    check("graph JSON has 4 nodes (3 notes + 1 ghost) and 4 edges", select(2, g:gsub("{n:", "")) == 4 and g:find('ghost:1') and select(2, g:gsub("%[%d+,%d+%]", "")) == 4, g)
end
do
    v.scan("grep fails")
    lastTask("find").cb(0, VAULT .. "/Alpha.md\n", "")
    lastTask("grep").cb(2, "", "grep: boom")
    check("a grep error is reported, not swallowed", v.scanErr and v.scanErr:find("grep exited 2"), v.scanErr)
    v.scan("no links")
    lastTask("find").cb(0, VAULT .. "/Alpha.md\n" .. VAULT .. "/Projects/Beta.md\n" .. VAULT .. "/Gamma.md\n", "")
    lastTask("grep").cb(1, "", "")
    finishTagGreps()
    check("grep exit 1 (no matches) is a clean empty scan", v.scanErr == nil and next(v.links) == nil)
    lastTask("find").cb(0, "", "")   -- restore the earlier links for the rest
    v.scan("restore")
    lastTask("find").cb(0, VAULT .. "/Alpha.md\n" .. VAULT .. "/Projects/Beta.md\n" .. VAULT .. "/Gamma.md\n", "")
    lastTask("grep").cb(0, VAULT .. "/Alpha.md:[[Beta|B]]\n" .. VAULT .. "/Alpha.md:[[Gamma]]\n" .. VAULT .. "/Projects/Beta.md:[[alpha]]\n" .. VAULT .. "/Gamma.md:[[Delta]]\n", "")
    finishTagGreps()
end

-- =======================================================================
out("4) opening, typing, saving — one file read, tmp + rename, debounce\n")
-- =======================================================================
FILES[VAULT .. "/Alpha.md"] = "# Alpha\n\nsee [[Beta|B]] and [[Gamma]]\n"
FILES[VAULT .. "/Projects/Beta.md"] = "# Beta\n\nsee [[alpha]]\n"
READS = {}
check("opening Alpha reads exactly that file", v.openNote("alpha") and #READS == 1 and READS[1] == VAULT .. "/Alpha.md" and v.doc.text:find("^# Alpha"))
check("it is remembered as the last note", SETTINGS["vault.lastNote"] == "Alpha.md")
msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n\nsee [[Beta|B]] and [[Gamma]] and [[Delta]]\n", sel = 5 })
check("a keystroke lands in Lua at once and nothing is on disk yet", v.doc.text:find("%[%[Delta%]%]") and v.dirty and FILES[VAULT .. "/Alpha.md"]:find("Delta") == nil)
check("the outgoing links are live before any save", #v.links["Alpha.md"] == 3 and v.links["Alpha.md"][3] == "Delta")
local st = lastTimer("after")
check("one held debounce timer of saveDelay", st and st.delay == v.saveDelay and v.saveTimer == st)
st:fire()
check("the .md file is written after the debounce, via tmp + rename",
      FILES[VAULT .. "/Alpha.md"]:find("Delta") and FILES[VAULT .. "/Alpha.md.tmp"] == nil and v.saves == 1 and not v.dirty)
check("Delta now has two backlinkers (Gamma and Alpha)", v.unresolved.delta and #v.unresolved.delta.from == 2)
do
    msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n\nchanged\n", sel = 3 })
    WRITE_FAILS = true
    lastTimer("after"):fire()
    check("a failed write is said once, counted, and the text stays in Lua",
          v.saveFails == 1 and v.lastSaveErr and #WRITE_WARNS == 1 and #ALERTS >= 1 and ALERTS[#ALERTS]:find("NOT SAVED") and v.doc.text:find("changed"))
    WRITE_FAILS = false
    msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n\nchanged twice\n", sel = 3 })
    lastTimer("after"):fire()
    check("the next keystroke retries and clears the error", v.lastSaveErr == nil and FILES[VAULT .. "/Alpha.md"]:find("changed twice"))
end
check("a message for another note's rel never overwrites the open one",
      (function() msg({ a = "edit", rel = "Other.md", text = "stray", sel = 0 }); return not v.doc.text:find("stray") end)())

-- =======================================================================
out("5) new notes, daily notes, following links\n")
-- =======================================================================
check("opening a name with no file creates it with a heading and saves at once",
      v.openNote("New Idea") and FILES[VAULT .. "/New Idea.md"] == "# New Idea\n\n" and v.find("new idea") ~= nil)
check("the new note joined the index (4 notes)", #v.notes == 4)
check("switching away saved the previous note first (Alpha on disk holds its last text)", FILES[VAULT .. "/Alpha.md"]:find("changed twice"))
check("a slash in a name becomes a dash (no folder escape)", v.openNote("a/b:c") and v.doc.rel == "a-b-c.md")
local today = os.date("%Y-%m-%d")
check("⌘D opens Daily/<date>.md with the day as heading",
      v.openDaily() and v.doc.rel == "Daily/" .. today .. ".md" and FILES[VAULT .. "/Daily/" .. today .. ".md"]:find("^# %a+ %d+ %a+ %d%d%d%d"))
check("following [[Delta]] creates Delta (the ghost becomes a note)",
      v.follow("Delta|shown", false) and v.doc.rel == "Delta.md" and v.unresolved.delta == nil and v.backlinks.delta and #v.backlinks.delta == 1)
v.openNote("Beta")
check("following a relative Markdown file link resolves against the note's folder and opens it",
      v.follow("../Docs/Q4%20plan.pdf", true) and OPENED[#OPENED] == VAULT .. "/Docs/Q4 plan.pdf", OPENED[#OPENED])
check("an http link opens as a URL", v.follow("https://example.com/x", true) and OPENED[#OPENED] == "https://example.com/x")
check("a relative .md link opens that note instead of the app",
      v.follow("../Alpha.md", true) and v.doc.rel == "Alpha.md")
do
    local link = v.linkFile()
    check("⌘K writes a Markdown link relative to the note (up out of the vault into OneDrive)",
          link == "[Q4 plan.pdf](../Documents/Plans/Q4%20plan.pdf)", link)
end

-- =======================================================================
out("6) the window — page contents, walker, ⇪ keyup, hide saves\n")
-- =======================================================================
v.show()
local view = WEBVIEWS[#WEBVIEWS]
check("⇪3 opens one webview, shown, non-activating applied",
      view and view.shown == 1 and v.nonActivatingApplied == true and view.title == "Vault")
check("the hyper watchdog is told to expect a release", EXPECTED[#EXPECTED] and EXPECTED[#EXPECTED].who == "the vault")
-- 6.181.0 — 0.9, because LL asked for it in those words ("make the
-- Scorp pad 90% black"). 6.175.2 had settled on solid after three
-- passes; this is the fourth and it is settled the other way. The
-- 6.175.2 TEETH stay, tested from the other side: at exactly 1 the
-- module must still not call view:alpha() at all — asking macOS for an
-- alpha of 1 is how a window ends up on a translucency path it does not
-- need — and below 1 it must actually set it, or the number is a lie.
check("6.181.1: the window is 97% opaque by default", v.alpha == 0.97, tostring(v.alpha))
check("…and below 1 the alpha is really SET on the window",
      math.abs((view.alphaSet or 0) - 0.97) < 0.001, tostring(view.alphaSet))
do
    v.hide("t"); v.alpha = 1; v.show()
    local solid = WEBVIEWS[#WEBVIEWS]
    check("…and at exactly 1 it is never set at all (the 6.175.2 guard holds)",
          solid.alphaSet == nil, tostring(solid.alphaSet))
    v.hide("t"); v.alpha = 0.97; v.show()
    view = WEBVIEWS[#WEBVIEWS]
end
check("a scan runs on open and a held rescan timer is armed", lastTask("find") and lastTask("find").started and v.rescanTimer and v.rescanTimer.kind == "every")
local h = view.htmlSet or ""
check("the page lists every note and the open one", h:find("NOTES = %[") and h:find('"Alpha"') and h:find('"New Idea"') and h:find('CUR = "Alpha.md"'))
check("the page carries the row walker block", h:find("function rowKey") and h:find("function moveSel") and h:find("function rowAct") and h:find("e%.altKey || !inText%(%)"))
check("the page forwards an F18 keyup", h:find("a:'f18up'"))
check("the page has the [[ autocomplete and ⌘⏎ follow", h:find("function autocomplete") and h:find("function linkAtCaret") and h:find("a:'follow'"))
check("the page has the graph canvas and force layout", h:find('id="cv"') and h:find("function graphStart") and h:find("GRAPH = {nodes:"))
-- 6.181.0 — 13 px (LL asked for 13pt), and the window grew to carry it.
-- The derived sizes come off it, so a placeholder left unreplaced would
-- show up as a literal FS1px/FS2px in the page.
check("text is 13 px and no placeholder survives",
      h:find("font%-size:13px") and h:find("font%-size:11px") and h:find("font%-size:10px")
      and not h:find("FS%d?px") and not h:find("FSLABEL"))
check("…and the window grew with the smaller type", v.width == 1440 and v.height == 940,
      tostring(v.width) .. "x" .. tostring(v.height))
check("backlinks pane lists Beta for Alpha", h:find('← Beta'))
-- 🏷 6.181.0 — LL asked for tool tips on the pad's icons. Every button
-- already carried a title="", and a non-activating WKWebView panel does
-- not reliably raise the native box, so the page paints its own. These
-- check the layer exists AND that there is something for it to show.
check("the page has its own tooltip layer, fed by the titles already there",
      h:find('id="tip"', 1, true) and h:find("getAttribute('data-tip')", 1, true)
      and h:find("removeAttribute('title')", 1, true) and h:find("#tip{position:fixed", 1, true))
check("...and every header icon has a title for it to show",
      select(2, h:gsub('<button[^>]-title="', "")) >= 8,
      tostring(select(2, h:gsub('<button[^>]-title="', ""))))
msg({ a = "f18up", rel = "Alpha.md", text = v.doc.text, sel = 0 })
check("f18up reaches hyperReleaseSeen", SEEN[#SEEN] == "the vault")
msg({ a = "graph", rel = "Alpha.md", text = v.doc.text, sel = 0 })
check("⌘G switches the page to the graph view", v.view == "graph" and view.htmlSet:find('<body class="graph"'))
msg({ a = "graph", rel = "Alpha.md", text = v.doc.text, sel = 0 })
check("⌘G again returns to the editor", v.view == "edit")
msg({ a = "open", name = "Gamma", rel = "Alpha.md", text = v.doc.text, sel = 0 })
check("a row click opens that note in the same window", v.doc.rel == "Gamma.md" and view.htmlSet:find('CUR = "Gamma.md"'))
msg({ a = "linkfile", rel = "Gamma.md", text = "# Gamma\n", sel = 8 })
check("⌘K inserts the link into the page at the caret", EVALS[#EVALS] and EVALS[#EVALS]:find('insertAtCaret%("%[Q4 plan.pdf%]'), EVALS[#EVALS])
msg({ a = "edit", rel = "Gamma.md", text = "# Gamma\n\nunsaved", sel = 3 })
msg({ a = "esc", rel = "Gamma.md", text = "# Gamma\n\nunsaved", sel = 3 })
check("Esc closes, saves the pending text, stops the rescan timer",
      v.webview == nil and view.deleted and FILES[VAULT .. "/Gamma.md"] == "# Gamma\n\nunsaved" and v.rescanTimer == nil)
check("the escape router's present() is false once closed", CLAIMED_ESC.vault.present() == false)
do
    v.show()
    check("⇪3 again reopens", v.webview ~= nil)
    v.show()
    check("⇪3 while open closes (toggle)", v.webview == nil)
end

-- =======================================================================
out("7) degrade — no webview, the prompt still edits and saves\n")
-- =======================================================================
do
    local saved = hs.webview
    hs.webview = nil
    PROMPT_ANSWERS = { { "Save", "# Gamma\n\nfrom the prompt" } }
    v.show()
    check("without a webview the prompt edits the open note and saves it",
          #PROMPTS >= 1 and FILES[VAULT .. "/Gamma.md"] == "# Gamma\n\nfrom the prompt", FILES[VAULT .. "/Gamma.md"])
    hs.webview = saved
end
do
    local r = _G.vaultReport()
    check("the report names the folder, the note count and Obsidian", r:find(VAULT, 1, true) and r:find("notes  : 7") and r:find("Obsidian"), r)
    check("the report shows the alpha and how to make it solid again",
          r:find("alpha 0.97 (see-through; vault = { alpha = 1 } for solid)", 1, true) ~= nil, r)
end

-- =======================================================================
out("8) 6.173.0 — the Scorp Pad's tabs live in this window\n")
-- =======================================================================
do
    -- a stand-in for scratch_pad's brain: tabs, history, the filing hooks
    local PAD = { viaVault = true, tabs = {}, history = {}, historyRows = 200, active = nil, sets = {}, saves = 0,
                  closedHost = 0, sent = 0, kinds = { capture = { badge = "🗒", label = "Capture", hint = "⌘W queues this" } } }
    local n = 0
    function PAD.newTab(text, kind) n = n + 1; local t = { id = "t" .. n, text = text or "", kind = kind }; PAD.tabs[#PAD.tabs + 1] = t; PAD.active = t.id; return t end
    function PAD.findTab(id) for i, t in ipairs(PAD.tabs) do if t.id == id then return t, i end end end
    function PAD.activeTab() return PAD.active and PAD.findTab(PAD.active) or PAD.tabs[1] end
    function PAD.titleOf(t) local f = t.text:match("[^\n]*"); if f == "" then return (PAD.kinds[t.kind or ""] or {}).label or "Scratch" end return f end
    function PAD.kindOf(t) return t and t.kind and PAD.kinds[t.kind] or nil end
    function PAD.setText(id, text) local t = PAD.findTab(id); if t then t.text = text; PAD.sets[#PAD.sets + 1] = id .. "=" .. text end return t ~= nil end
    function PAD.closeTab(id) local t, i = PAD.findTab(id); if not t then return false end table.remove(PAD.tabs, i)
        if t.text ~= "" then table.insert(PAD.history, 1, { id = t.id, text = t.text, title = PAD.titleOf(t), closedAt = 0 }) end
        if #PAD.tabs == 0 then PAD.newTab("") end
        if PAD.active == id then PAD.active = PAD.tabs[math.min(i, #PAD.tabs)].id end return true end
    function PAD.restore(id) for i, h in ipairs(PAD.history) do if h.id == id then table.remove(PAD.history, i); PAD.newTab(h.text); return true end end return false end
    function PAD.onHostClose() PAD.closedHost = PAD.closedHost + 1 end
    function PAD.send() PAD.sent = PAD.sent + 1; return true, "sent" end
    function PAD.saveNow() PAD.saves = PAD.saves + 1 end
    PAD.newTab("groceries\nmilk [[Alpha]]"); PAD.newTab("", "capture"); PAD.active = "t1"
    _G.scratchPad = PAD

    check("without the pad module, v.sp() is nil and nothing here changes", (function() local keep = _G.scratchPad; _G.scratchPad = nil; local r = v.sp(); _G.scratchPad = keep; return r == nil end)())
    check("scratch_pad.viaVault = false keeps the pad's own window", (function() PAD.viaVault = false; local r = v.sp(); PAD.viaVault = true; return r == nil end)())
    check("v.sp() finds the pad", v.sp() == PAD)

    v.openNote("Gamma")
    check("⇪1 (toggleScratch) with the window closed opens it on the active tab",
          v.toggleScratch() and v.webview ~= nil and v.doc and v.doc.scratch == "t1" and v.doc.rel == "scratch:t1")
    local h = v.webview.htmlSet
    check("the list carries a 📝 SCRATCH section, the tab rows, + new tab, then 🕸 NOTES",
          h:find("📝 SCRATCH", 1, true) and h:find('TABS = [{id:"t1",t:"groceries"', 1, true) and h:find("HASPAD = true", 1, true)
          and h:find("🕸 NOTES", 1, true) and h:find("new tab ⌘T", 1, true))
    check("a Capture tab row carries its badge and kind", h:find('{id:"t2",t:"Capture",b:"🗒",k:"capture"}', 1, true) ~= nil)
    check("the header says Scorp Pad, offers ⌘W and → Asana now", h:find("📝 Scorp Pad", 1, true) and h:find("→ Asana now", 1, true) and h:find("a:'tabclose'", 1, true))
    check("the right pane shows the tab's links out (Alpha) and HISTORY, not backlinks",
          h:find("HISTORY", 1, true) and h:find('data-name="Alpha">→ Alpha', 1, true) and not h:find("BACKLINKS", 1, true))
    -- 6.174.0 — the spare newline after the start tag: HTML discards one
    -- there, so a note beginning with a blank line reaches the page whole
    check("the textarea holds the tab's text", h:find("<textarea", 1, true) and h:find(">\ngroceries\nmilk [[Alpha]]</textarea>", 1, true))
    local writes = 0
    for k in pairs(FILES) do if k:find("scratch", 1, true) then writes = writes + 1 end end
    msg({ a = "edit", rel = "scratch:t1", text = "groceries\nmilk, eggs", sel = 5 })
    check("typing into a tab goes to the pad's setText, never to a file", PAD.sets[#PAD.sets] == "t1=groceries\nmilk, eggs" and v.doc.text == "groceries\nmilk, eggs" and not v.dirty and writes == 0)
    check("v.links never learns a scratch rel", v.links["scratch:t1"] == nil)
    msg({ a = "tabnew", rel = "scratch:t1", text = "groceries\nmilk, eggs", sel = 5 })
    check("⌘T makes a new tab and opens it", #PAD.tabs == 3 and v.doc.scratch == "t3")
    msg({ a = "tabnth", n = "1", rel = "scratch:t3", text = "", sel = 0 })
    check("⌘1 opens the first tab", v.doc.scratch == "t1")
    msg({ a = "tabcycle", d = 1, rel = "scratch:t1", text = v.doc.text, sel = 0 })
    check("⌃Tab cycles to the next tab", v.doc.scratch == "t2")
    msg({ a = "tabcycle", d = -1, rel = "scratch:t2", text = "", sel = 0 })
    check("⌃⇧Tab cycles back", v.doc.scratch == "t1")
    msg({ a = "tabclose", tid = "t1", rel = "scratch:t1", text = v.doc.text, sel = 0 })
    check("⌘W closes the tab into the history and opens the pad's next active tab",
          PAD.history[1] and PAD.history[1].id == "t1" and #PAD.tabs == 2 and v.doc.scratch == PAD.active and v.webview.htmlSet:find('data-hist="t1"', 1, true))
    msg({ a = "restore", rid = "t1", rel = v.doc.rel, text = v.doc.text, sel = 0 })
    check("a history click restores the tab and opens it", #PAD.history == 0 and #PAD.tabs == 3 and v.doc.text == "groceries\nmilk, eggs")
    msg({ a = "send", rel = v.doc.rel, text = v.doc.text, sel = 0 })
    check("→ Asana now is the pad's own send", PAD.sent == 1)
    msg({ a = "open", name = "Gamma", rel = v.doc.rel, text = v.doc.text, sel = 0 })
    check("a note row from a tab opens the note; the header is the Vault's again",
          v.doc.rel == "Gamma.md" and v.webview.htmlSet:find("🕸 Vault", 1, true) and v.webview.htmlSet:find("BACKLINKS", 1, true))
    check("…and the SCRATCH section is still listed", v.webview.htmlSet:find("📝 SCRATCH", 1, true) ~= nil)
    check("⇪1 with a note open jumps to the tabs (no close)", v.toggleScratch() and v.webview ~= nil and v.doc.scratch ~= nil)
    check("⇪1 with a tab open closes the window and lets the pad file its kind tabs",
          v.toggleScratch() and v.webview == nil and PAD.closedHost == 1)
    msg({ a = "pin" })
    check("📌 pins: remembered, and the escape router stands aside", v.pinned == true and SETTINGS["vault.pinned"] == true)
    v.show()
    check("…while pinned, the router's present() is false with the window open", v.webview ~= nil and CLAIMED_ESC.vault.present() == false)
    local before = v.webview
    msg({ a = "esc", rel = v.doc.rel, text = v.doc.text, sel = 0 })
    check("Esc on a pinned window only hands the keys back", v.webview == before)
    msg({ a = "pin" })
    v.hide()
    -- 6.177.0 — ⌘⇧S hands the export to the pad, and survives its absence
    PAD.exports = 0
    function PAD.exportAll(why) PAD.exports = PAD.exports + 1; return true, "2 notes → /od/Vault/Scratch" end
    msg({ a = "export" })
    check("6.177.0: ⌘⇧S asks the pad to export — the vault does none of the work", PAD.exports == 1)
    check("...and it says on screen where the notes went",
          tostring(ALERTS[#ALERTS]):find("/od/Vault/Scratch", 1, true) ~= nil, tostring(ALERTS[#ALERTS]))
    do
        local keep = _G.scratchPad; _G.scratchPad = nil
        local ok = pcall(msg, { a = "export" })
        _G.scratchPad = keep
        check("...and with no pad loaded it says so instead of throwing",
              ok and tostring(ALERTS[#ALERTS]):find("not loaded", 1, true) ~= nil, tostring(ALERTS[#ALERTS]))
    end
    PAD.exportAll = nil
    local okNo = pcall(msg, { a = "export" })
    check("...an old pad without the export still costs nothing", okNo == true)

    -- 6.180.0 — the anchors half: vault.link writes ONE line under the
    -- heading, vault.names lists the notes, and follow() opens an
    -- absolute link (including one whose file has moved).
    do
        local ok, why = PROVIDED["vault.link"]("Anchored", "- [Contract](file:///a/b.docx)")
        check("6.180.0: vault.link creates the note and writes the line under the heading", (function()
            local t = v.doc and v.doc.text or ""
            return ok and t:find("## Linked", 1, true) and t:find("- [Contract](file:///a/b.docx)", 1, true)
        end)(), v.doc and v.doc.text)
        local again = select(2, PROVIDED["vault.link"]("Anchored", "- [Contract](file:///a/b.docx)"))
        check("...and the SAME link twice is one line, not two",
              again == "already linked"
              and select(2, (v.doc.text):gsub("%- %[Contract%]", "")) == 1, again)
        PROVIDED["vault.link"]("Anchored", "- [Second](file:///a/c.docx)")
        check("...a second link goes under the same heading, newest first",
              v.doc.text:find("## Linked\n%- %[Second%]") ~= nil, v.doc.text)
        check("...and it refuses politely with nothing to link",
              PROVIDED["vault.link"]("Anchored", "") == false)
        local names = PROVIDED["vault.names"]()
        check("vault.names lists the notes for the anchors picker",
              type(names) == "table" and #names > 0, names and #names)
    end
    do
        OPENED = {}
        v.follow("file:///tmp/does-not-matter.txt", true)
        check("6.180.0: an absolute file:// link is opened as a FILE, not joined onto the note's folder",
              (OPENED[#OPENED] or ""):find("^/tmp/does%-not%-matter%.txt") ~= nil
              or (ALERTS[#ALERTS] or ""):find("not where the link says", 1, true) ~= nil,
              tostring(OPENED[#OPENED] or ALERTS[#ALERTS]))
        v.follow("message://%3Cabc@example.com%3E", true)
        check("...and a scheme only its own app understands is handed to macOS",
              (OPENED[#OPENED] or ""):find("^message://") ~= nil, OPENED[#OPENED])
    end

    check("the report has the scratch line", _G.vaultReport():find("scratch: 3 tabs of the Scorp Pad", 1, true) ~= nil)
    _G.scratchPad = nil
end

-- =======================================================================
out("9) 6.174.0 — tags: the grammar, the front matter, the index from two more greps\n")
-- =======================================================================
local WARNS = {}
_G.diag.warn = function(_, m) WARNS[#WARNS + 1] = tostring(m) end
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
check("tagOk: letters, digits with a non-digit, nested, trailing punctuation off, Unicode",
      v.tagOk("Work") == "Work" and v.tagOk("2024") == nil and v.tagOk("2024-plan") == "2024-plan" and v.tagOk("a/b.") == "a/b"
      and v.tagOk("café") == "café" and v.tagOk("") == nil and v.tagOk("x)") == "x" and v.tagOk("a b") == nil)
do
    local got = v.tagsIn("---\ntags: [Work, home/x]\n  - extra\n---\n# H\ntext #Work #2024 a#b [[N#h]] https://x/y#z #café.\n```\n#code\n```\n#Done\n")
    check("tagsIn: front matter (inline + list item), body tags, no heading / number / [[N#h]] / URL / fenced tag, first-seen case",
          same(got, { "Work", "home/x", "extra", "café", "Done" }), table.concat(got, ","))
    check("tagsIn: `tags: a, b`, `tags: a b`, `tag: a`, quotes and a leading # stripped, YAML list form",
          same(v.tagsIn("---\ntags: a, b\n---\n"), { "a", "b" }) and same(v.tagsIn("---\ntags: a b\n---\n"), { "a", "b" })
          and same(v.tagsIn("---\ntag: '#solo'\n---\n"), { "solo" }) and same(v.tagsIn("---\ntags:\n  - one\n  - \"two\"\nother: x\n  - three\n---\n"), { "one", "two" }))
    check("tagsIn: no closing --- means no front matter (the lines are body)", same(v.tagsIn("---\ntags: a\n#b\n"), { "b" }))
    check("tagsIn: a ~~~ fence hides tags too; case-insensitive dedupe keeps the first spelling",
          same(v.tagsIn("~~~\n#hidden\n~~~\n#Tag #tag #TAG\n"), { "Tag" }))
end
-- the scan, with tags: Alpha open and carrying #Work live
FILES[VAULT .. "/Alpha.md"] = "# Alpha\n\nsee [[Beta|B]] and [[Gamma]] #Work\n"
v.openNote("Alpha")
READS = {}
local NOTES9 = VAULT .. "/Alpha.md\n" .. VAULT .. "/Projects/Beta.md\n" .. VAULT .. "/Gamma.md\n" .. VAULT .. "/Delta.md\n"
    .. VAULT .. "/New Idea.md\n" .. VAULT .. "/Daily.md\n" .. VAULT .. "/Templates/Meeting.md\n" .. VAULT .. "/Daily/" .. today .. ".md\n"
local LINKS9 = VAULT .. "/Alpha.md:[[Beta|B]]\n" .. VAULT .. "/Alpha.md:[[Gamma]]\n" .. VAULT .. "/Projects/Beta.md:[[alpha]]\n" .. VAULT .. "/Gamma.md:[[Delta]]\n"
v.scanning = false
check("a scan starts (find → link grep → tag grep)", v.scan("tags") == true)
lastTask("find").cb(0, NOTES9, "")
lastTaskWith("grep", "\\[\\[").cb(0, LINKS9, "")
local tg = lastTaskWith("grep", "-rHoIE")
check("the tag grep is HELD and started", tg and v.tagTask == tg and tg.started)
tg.cb(0, VAULT .. "/Alpha.md: #Work\n" .. VAULT .. "/Gamma.md:#work/deep\n" .. VAULT .. "/Gamma.md: #2024\n/elsewhere/x.md:#no\n", "")
check("the tag index is NOT assigned before the chain ends (only the open note's live #Work exists)", v.tags["work/deep"] == nil and v.tags.work.count == 1 and v.scanning == true)
local fg = lastTaskWith("grep", "^---")
check("the front-matter grep is HELD and started", fg and v.fmTask == fg and fg.started)
fg.cb(0, VAULT .. "/Projects/Beta.md:1:---\n" .. VAULT .. "/Projects/Beta.md-2-tags: [Home, \"#Work\"]\n" .. VAULT .. "/Projects/Beta.md-3-  - listed\n" .. VAULT .. "/Projects/Beta.md-4-status: reading\n" .. VAULT .. "/Projects/Beta.md-5-rating: 5\n" .. VAULT .. "/Projects/Beta.md-6----\n--\n" .. VAULT .. "/Gamma.md:70:---\n" .. VAULT .. "/Gamma.md-71-tags: late\n", "")
check("scan finished with tags: #work counts Alpha, Beta (front matter) and Gamma (nested child)",
      v.scanning == false and v.scanErr == nil and v.tags.work and v.tags.work.count == 3, v.tags.work and v.tags.work.count)
check("work/deep is its own tag on Gamma only", v.tags["work/deep"] and #v.tags["work/deep"].rels == 1 and v.tags["work/deep"].rels[1] == "Gamma.md")
check("front matter: the inline list and the `- listed` item both count", v.tags.home and v.tags.home.count == 1 and v.tags.listed and v.tags.listed.count == 1)
check("#2024 is a number, `tags:` on line 70 is not front matter, /elsewhere is not the vault",
      v.tags["2024"] == nil and v.tags.late == nil and v.tags.no == nil)
check("the display name is the first-seen spelling and the list is by count", v.tags.work.name == "Work" and v.tagList[1].key == "work" and v.tagList[1].count == 3)
check("no note file was READ for the tags", #READS == 0, #READS)
check("tagsOf never learns a scratch rel and the open note's entry is live", v.tagsOf["Alpha.md"] and v.tagsOf["Alpha.md"][1] == "Work")
check("the two greps share one line counter (4 tag lines + 9 front-matter lines)", v.tagLines == 13, v.tagLines)
-- 6.185.0 — the SAME grep that built the tags built the FIELDS. No second
-- pass over the vault, no note read, and the answer is per note.
check("6.185.0: the front-matter FIELDS are indexed off the same grep",
      v.fmOf["Projects/Beta.md"] and v.fmOf["Projects/Beta.md"].status == "reading"
      and v.fmOf["Projects/Beta.md"].rating == "5", v.fmOf["Projects/Beta.md"])
check("…tags are NOT duplicated into the fields — they already travel as g:[…]",
      v.fmOf["Projects/Beta.md"].tags == nil and v.fmOf["Projects/Beta.md"].tag == nil)
check("…a --- that is not on line 1 opens nothing (it is a divider in someone's prose)",
      v.fmOf["Gamma.md"] == nil, v.fmOf["Gamma.md"])
check("…and STILL no note file was read to learn any of it", #READS == 0, #READS)
check("v.fmFields lists every key seen, by count then name",
      #v.fmFields == 2 and v.fmFields[1].name == "rating" and v.fmFields[1].count == 1
      and v.fmFields[2].name == "status", v.fmFields)
-- v.fmIn is the Lua twin for the OPEN note: exact, live, and the only
-- place a note's own text is parsed for fields
check("v.fmIn reads one note's front matter: scalars, a list joined, tags skipped", (function()
    local f = v.fmIn("---\ntitle: Deep Work\ntags: [a, b]\nstatus: reading\ngenre:\n  - focus\n  - craft\n---\n# body\nstatus: not this\n")
    return f.title == "Deep Work" and f.status == "reading" and f.genre == "focus, craft" and f.tags == nil, f
end)())
check("v.fmIn refuses a block with no closing --- — that is body text, not front matter",
      next(v.fmIn("---\nstatus: reading\nand then prose\n")) == nil)
check("v.fmIn refuses a --- that is not the first line", next(v.fmIn("# Title\n---\nstatus: x\n---\n")) == nil)
check("a value longer than fmMaxLen is CLAMPED, so one paragraph cannot bloat the page",
      #(v.fmIn("---\nnote: " .. string.rep("x", 400) .. "\n---\n").note or "") == v.fmMaxLen)
check("a note with more than fmMaxFields keys keeps the first fmMaxFields, and does not grow", (function()
    local L = { "---" }
    for i = 1, 40 do L[#L + 1] = "k" .. i .. ": v" .. i end
    L[#L + 1] = "---"
    local f, n = v.fmIn(table.concat(L, "\n") .. "\n"), 0
    for _ in pairs(f) do n = n + 1 end
    return n == v.fmMaxFields and f.k1 == "v1", n
end)())
do
    -- a failed tag grep is optional: links stay, the scan finishes, a warn line says so
    local before = v.tags.work.count
    v.scan("tags fail")
    lastTask("find").cb(0, NOTES9, "")
    lastTaskWith("grep", "\\[\\[").cb(0, LINKS9, "")
    lastTaskWith("grep", "-rHoIE").cb(2, "", "grep: boom")
    check("tag grep exit 2: a warn line, no scanErr, links intact, scan finished, tags untouched",
          v.scanning == false and v.scanErr == nil and #v.links["Alpha.md"] == 2 and WARNS[#WARNS]:find("tags: grep exited 2", 1, true)
          and v.tags.work.count == before, WARNS[#WARNS])
    -- a failed front-matter grep keeps what the tag grep found
    v.scan("fm fail")
    lastTask("find").cb(0, NOTES9, "")
    lastTaskWith("grep", "\\[\\[").cb(0, LINKS9, "")
    lastTaskWith("grep", "-rHoIE").cb(0, VAULT .. "/Gamma.md:#only\n", "")
    lastTaskWith("grep", "^---").cb(2, "", "grep: boom")
    check("front-matter grep exit 2: the inline tags are kept, the scan finishes", v.scanning == false and v.tags.only and v.tags.home == nil, WARNS[#WARNS])
    -- back to the full index
    v.scan("tags again")
    lastTask("find").cb(0, NOTES9, "")
    lastTaskWith("grep", "\\[\\[").cb(0, LINKS9, "")
    lastTaskWith("grep", "-rHoIE").cb(0, VAULT .. "/Alpha.md: #Work\n" .. VAULT .. "/Gamma.md:#work/deep\n", "")
    lastTaskWith("grep", "^---").cb(0, VAULT .. "/Projects/Beta.md:1:---\n" .. VAULT .. "/Projects/Beta.md-2-tags: [Home, \"#Work\"]\n" .. VAULT .. "/Projects/Beta.md-3-  - listed\n" .. VAULT .. "/Projects/Beta.md-4-status: reading\n" .. VAULT .. "/Projects/Beta.md-5-rating: 5\n" .. VAULT .. "/Projects/Beta.md-6----\n", "")
    check("…restored", v.tags.work.count == 3 and v.tags.home ~= nil)
    check("…and the FIELDS came back with them — one grep, both indexes",
          v.fmOf["Projects/Beta.md"] and v.fmOf["Projects/Beta.md"].status == "reading" and #v.fmFields == 2, v.fmFields)
end
-- live: a keystroke changes the open note's tags at once, the index on save
msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n#Fresh\n", sel = 3 })
check("typing #Fresh into Alpha is in tagsOf before any save", same(v.tagsOf["Alpha.md"], { "Fresh" }))
lastTimer("after"):fire()
check("the save rebuilds the index: #fresh exists, #work dropped to 2", v.tags.fresh and v.tags.fresh.count == 1 and v.tags.work.count == 2)
check("tagsJson is the list in count order", v.tagsJson():find('^%[{k:"work",n:"Work",c:2}'), v.tagsJson())
check("notesJson rows carry g:[tags] and tpl:1 for a template",
      v.notesJson():find('{n:"Alpha",r:"Alpha.md",g:["fresh"],l:[]}', 1, true) and v.notesJson():find('{n:"Meeting",r:"Templates/Meeting.md",g:[],l:[],tpl:1}', 1, true), v.notesJson())
-- 6.183.0 — l: the KEYS a note links out to. A query's FROM [[Note]] is
-- answered in the page, so the row has to carry them; without this the
-- page cannot tell which notes point at anything.
check("notesJson carries each note's outgoing link KEYS, lower-cased, for FROM [[Note]]", (function()
    local keep = v.links["Gamma.md"]
    v.links["Gamma.md"] = { "Alpha", "Delta Two" }
    local out = v.notesJson()
    v.links["Gamma.md"] = keep
    return out:find('{n:"Gamma",r:"Gamma.md",g:["work/deep"],l:["alpha","delta two"]}', 1, true) ~= nil, out
end)())
check("setNotes drops the tags of a note that vanished", (function()
    local keep = v.tagsOf["Gamma.md"]
    v.setNotes({ "Alpha.md", "Projects/Beta.md" })
    local gone = v.tagsOf["Gamma.md"] == nil and v.tags["work/deep"] == nil
    local rels = {}
    for line in NOTES9:gmatch("[^\n]+") do rels[#rels + 1] = line:sub(#VAULT + 2) end
    v.setNotes(rels); v.tagsOf["Gamma.md"] = keep; v.rebuildTags()
    return gone and v.tags["work/deep"] ~= nil
end)())
v.show()
local h9 = WEBVIEWS[#WEBVIEWS].htmlSet or ""
check("the page carries TAGS, TAGROWS, TEMPLATES, TPLDIR, MODE and the new load state",
      h9:find('TAGS = [{k:"work",n:"Work",c:2}', 1, true) and h9:find("TAGROWS = 15", 1, true)
      and h9:find('TEMPLATES = [{n:"Meeting",r:"Templates/Meeting.md"}]', 1, true) and h9:find('TPLDIR = "Templates"', 1, true)
      and h9:find('MODE = "notes"', 1, true) and h9:find("SMARTLISTS = true", 1, true) and h9:find("LINEH = 13 * 1.5", 1, true)
      and h9:find("CARETLINE = 0", 1, true) and h9:find("CARETHEAD = null", 1, true) and h9:find("DAILY = null", 1, true)
      and not h9:find("FSNUM", 1, true), h9:match("var TAGS[^\n]*"))
check("the report counts the tags and names the top ones", _G.vaultReport():find("tags   : 5 tags on 3 notes · top #work 2 · #fresh 1 · #home 1", 1, true) ~= nil, _G.vaultReport():match("tags   :[^\n]*"))
check("…and says so when there are none", (function()
    local keep = v.tagsOf; v.tagsOf = {}; v.rebuildTags()
    local r = _G.vaultReport():find("tags   : none yet — type #word in a note", 1, true) ~= nil
    v.tagsOf = keep; v.rebuildTags()
    return r
end)())
-- 6.185.0 — the fields line, in all three states it can be in
check("the report names the front-matter FIELDS a query can WHERE on",
      _G.vaultReport():find("fields : 2 on 1 notes · rating 1 · status 1 — a query can WHERE on any of them", 1, true) ~= nil,
      _G.vaultReport():match("fields :[^\n]*"))
check("…says so when there are none, with the shape to type",
      (function()
          local keep = v.fmOf; v.fmOf = {}; local kf = v.fmFields; v.fmFields = {}
          local r = _G.vaultReport():find("fields : none yet — put `status: reading` under a --- line", 1, true) ~= nil
          v.fmOf, v.fmFields = keep, kf
          return r
      end)())
-- IT DEGRADES, IT NEVER BREAKS: a failed grep must not read as "no fields"
check("…and NAMES the failure when the front-matter grep is what went wrong",
      (function()
          local keep, kf = v.fmOf, v.fmFields
          v.fmOf, v.fmFields, v.fmErr = {}, {}, "grep exited 2: boom"
          local r = _G.vaultReport():find("fields : none — the front-matter grep failed (grep exited 2: boom)", 1, true) ~= nil
          v.fmOf, v.fmFields, v.fmErr = keep, kf, nil
          return r
      end)(), _G.vaultReport():match("fields :[^\n]*"))
check("search and tasks report lines before any use", _G.vaultReport():find("search : never (⌘⇧F)", 1, true) and _G.vaultReport():find("tasks  : not listed yet (⌘⇧K)", 1, true))

-- =======================================================================
out("10) 6.174.0 — templates: Templates/*.md, moment tokens, {{cursor}}, /bin/cat in a task\n")
-- =======================================================================
check("v.templates() lists Templates/Meeting.md and nothing else", #v.templates() == 1 and v.templates()[1].rel == "Templates/Meeting.md")
check("templateByName matches by rel under Templates/ (case-insensitive)", v.templateByName("meeting") and v.templateByName("meeting").rel == "Templates/Meeting.md")
check("a ROOT note named Daily never shadows a template", v.find("daily") ~= nil and v.templateByName("Daily") == nil)
check("isTemplateRel is case-insensitive", v.isTemplateRel("templates/x.md") == true and v.isTemplateRel("Alpha.md") == false)
local T = os.time({ year = 2026, month = 9, day = 6, hour = 14, min = 5, sec = 9 })
check("momentFormat: YYYY-MM-DD", v.momentFormat("YYYY-MM-DD", T) == "2026-09-06", v.momentFormat("YYYY-MM-DD", T))
check("momentFormat: dddd D MMMM YYYY", v.momentFormat("dddd D MMMM YYYY", T) == "Sunday 6 September 2026", v.momentFormat("dddd D MMMM YYYY", T))
check("momentFormat: ddd DD MMM YY", v.momentFormat("ddd DD MMM YY", T) == "Sun 06 Sep 26", v.momentFormat("ddd DD MMM YY", T))
check("momentFormat: HH:mm:ss and h:mm A", v.momentFormat("HH:mm:ss", T) == "14:05:09" and v.momentFormat("h:mm A", T) == "2:05 PM", v.momentFormat("h:mm A", T))
check("momentFormat: [literal], m/s, Q and dd copy through", v.momentFormat("[Day] D, YY", T) == "Day 6, 26" and v.momentFormat("m/s", T) == "5/9"
      and v.momentFormat("Q", T) == "Q" and v.momentFormat("dd", T) == "dd" and v.momentFormat("[open", T) == "[open")
do
    local filled, caret = v.fillTemplate("# {{title}}\n{{date}} {{time}} {{ date }} {{date:}} {{date:YYYY}} {{nope}} {{title\n100%\n{{cursor}}x{{cursor}}", { title = "Meeting", when = T })
    local want = "# Meeting\n2026-09-06 14:05 2026-09-06 2026-09-06 2026 {{nope}} {{title\n100%\nx"
    check("fillTemplate: title, date, time, spaces, empty format, a format, unknown and unclosed stay, % survives, cursors vanish",
          filled == want, filled)
    check("…the caret is where the FIRST {{cursor}} was", caret == #"# Meeting\n2026-09-06 14:05 2026-09-06 2026-09-06 2026 {{nope}} {{title\n100%\n", caret)
    local f2, c2 = v.fillTemplate("{{cursor}}")
    check("a lone {{cursor}} → empty text, caret 0", f2 == "" and c2 == 0)
    local f3, c3 = v.fillTemplate("plain")
    check("no cursor → nil caret", f3 == "plain" and c3 == nil)
    local n = #PRINTED
    check("Templater <% %> is left verbatim and said once in the Console",
          v.fillTemplate("<% tp.x %>", { name = "Templates/Meeting.md" }) == "<% tp.x %>" and #PRINTED == n + 1 and PRINTED[#PRINTED]:find("Templater", 1, true) and PRINTED[#PRINTED]:find("Templates/Meeting.md", 1, true))
end
-- ⌘⇧T: insert at the caret
v.openNote("Alpha")
READS = {}
local catsBefore = countTasks("cat")
msg({ a = "tplinsert", name = "Meeting", rel = "Alpha.md", text = v.doc.text, sel = 0 })
local ct = lastTask("cat")
check("⌘⇧T starts /bin/cat on the template, HELD, with a 10 s held timer and a hint on the page",
      countTasks("cat") == catsBefore + 1 and ct.args[1] == VAULT .. "/Templates/Meeting.md" and ct.started and v.catTask == ct
      and v.catTimer and v.catTimer.kind == "after" and v.catTimer.delay == 10 and EVALS[#EVALS]:find('^vaultHint%("fetching'), EVALS[#EVALS])
local tm = v.catTimer
ct.cb(0, "## {{title}}\n{{cursor}}- ", "")
check("the body lands as insertAtCaret(head, tail) split at {{cursor}}, {{title}} = the note's name",
      EVALS[#EVALS] == 'insertAtCaret("## Alpha\\n","- ")', EVALS[#EVALS])
check("…task released, timer stopped, no file read on the main thread", v.catTask == nil and v.catTimer == nil and tm.stopped and #READS == 0)
msg({ a = "tplinsert", name = "Meeting", rel = "Alpha.md", text = v.doc.text, sel = 0 })
ct = lastTask("cat")
v.catTimer:fire()
check("no answer in 10 s: the task is terminated and LL is told", ct.terminated and v.catTask == nil and ALERTS[#ALERTS]:find("did not arrive", 1, true), ALERTS[#ALERTS])
msg({ a = "tplinsert", name = "Meeting", rel = "Alpha.md", text = v.doc.text, sel = 0 })
local first = lastTask("cat")
msg({ a = "tplinsert", name = "Meeting", rel = "Alpha.md", text = v.doc.text, sel = 0 })
local n = #EVALS
first.cb(0, "late", "")
check("a superseded fetch is terminated and its late answer changes nothing", first.terminated and #EVALS == n)
lastTask("cat").cb(0, "x", "")
v.openNote("Alpha")
msg({ a = "tplinsert", name = "Meeting", rel = "Alpha.md", text = v.doc.text, sel = 0 })
ct = lastTask("cat")
v.openNote("Gamma")
ct.cb(0, "## late", "")
check("a template that arrives after switching notes is not inserted", not EVALS[#EVALS]:find("insertAtCaret", 1, true), EVALS[#EVALS])
check("⌘⇧T with an unknown template alerts", (function() msg({ a = "tplinsert", name = "Nope" }); return ALERTS[#ALERTS]:find('no template named "Nope"', 1, true) ~= nil end)())
do
    local keep = v.doc; v.doc = nil
    msg({ a = "tplinsert", name = "Meeting" })
    check("⌘⇧T with no note open alerts", ALERTS[#ALERTS]:find("open a note first", 1, true) ~= nil, ALERTS[#ALERTS])
    v.doc = keep
end
-- ⌘⇧N: a new note from a template
PROMPT_ANSWERS = { { "Create", "Standup" } }
msg({ a = "tplnew", name = "Meeting", rel = v.doc.rel, text = v.doc.text, sel = 0 })
check("⌘⇧N prompts 'New note from Meeting' and fetches the template", PROMPTS[#PROMPTS].title == "New note from Meeting" and lastTask("cat").args[1] == VAULT .. "/Templates/Meeting.md")
lastTask("cat").cb(0, "## {{title}}\n{{cursor}}- ", "")
check("the note is created from the filled template and opened", FILES[VAULT .. "/Standup.md"] == "## Standup\n- " and v.doc.rel == "Standup.md")
check("the page gets the caret as CARETHEAD once", WEBVIEWS[#WEBVIEWS].htmlSet:find('CARETHEAD = "## Standup\\n"', 1, true) ~= nil)
v.render()
check("…and the next render has CARETHEAD = null", WEBVIEWS[#WEBVIEWS].htmlSet:find("CARETHEAD = null", 1, true) ~= nil)
msg({ a = "tplnew", name = "" })
check("⌘⇧N's '— blank —' row is the plain ⌘N prompt", PROMPTS[#PROMPTS].title == "New note")
msg({ a = "tplnone" })
check("no templates yet → an alert naming the folder", ALERTS[#ALERTS]:find("No templates yet", 1, true) and ALERTS[#ALERTS]:find("/Templates", 1, true))
PROMPT_ANSWERS = { { "Create", "Alpha" } }
catsBefore = countTasks("cat")
msg({ a = "tplnew", name = "Meeting" })
check("an existing name is refused: alert, the note opens untouched, no fetch",
      ALERTS[#ALERTS]:find("already exists", 1, true) and v.doc.rel == "Alpha.md" and countTasks("cat") == catsBefore)
-- ⌘D and ‹ › with Templates/Daily.md
do
    -- the index keys notes by NAME (one Daily per vault): the root Daily.md must go first
    local rels = {}
    for _, nn in ipairs(v.notes) do if nn.rel ~= "Daily.md" then rels[#rels + 1] = nn.rel end end
    rels[#rels + 1] = "Templates/Daily.md"
    v.setNotes(rels)
    check("the report names the daily template once it is indexed", _G.vaultReport():find("templates: 2 in Templates/ · daily template: Templates/Daily.md", 1, true) ~= nil, _G.vaultReport():match("templates:[^\n]*"))
    catsBefore = countTasks("cat")
    msg({ a = "daily" })
    check("⌘D on an EXISTING daily note opens it as is — never re-templated", v.doc.rel == "Daily/" .. today .. ".md" and countTasks("cat") == catsBefore)
    local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
    msg({ a = "dayshift", d = 1, rel = v.doc.rel, text = v.doc.text, sel = 0 })
    check("› onto a day with no note fetches Templates/Daily.md", countTasks("cat") == catsBefore + 1 and lastTask("cat").args[1] == VAULT .. "/Templates/Daily.md")
    lastTask("cat").cb(0, "# {{title}}\n{{date:dddd}}\n", "")
    check("the new daily note is the filled template: {{title}} = the date, {{date:}} for THAT day",
          FILES[VAULT .. "/Daily/" .. tomorrow .. ".md"] == "# " .. tomorrow .. "\n" .. os.date("%A", os.time() + 86400) .. "\n" and v.doc.rel == "Daily/" .. tomorrow .. ".md",
          FILES[VAULT .. "/Daily/" .. tomorrow .. ".md"])
    rels[#rels] = nil
    v.setNotes(rels)
    check("without a daily template the report says none", _G.vaultReport():find("daily template: none", 1, true) ~= nil)
    local keep = v.templatesDir; v.templatesDir = "Nowhere"
    check("no templates at all → the report says where to put them", _G.vaultReport():find("templates: none — put .md files in Nowhere/", 1, true) ~= nil, _G.vaultReport():match("templates:[^\n]*"))
    v.templatesDir = keep
end

-- =======================================================================
out("11) 6.174.0 — search inside every note: debounce, one held grep, terms in Lua\n")
-- =======================================================================
do
    local Tq = v.searchTerms('quarterly "big plan" tag:#Work path:Daily')
    check("searchTerms: terms, a quoted phrase, tag: (# off, lowercased), path:", same(Tq.terms, { "quarterly", "big plan" }) and Tq.tag == "work" and Tq.path == "daily")
    check("searchTerms: file: is path:, an unclosed quote runs to the end", v.searchTerms("file:X").path == "x" and v.searchTerms('"a b').terms[1] == "a b")
end
v.openNote("Alpha")
local grepsBefore = countTasks("grep")
msg({ a = "mode", m = "search" })
check("entering search mode starts no grep", v.mode == "search" and countTasks("grep") == grepsBefore)
msg({ a = "search", q = "plan" })
check("a keystroke arms a held 0.3 s timer, no grep yet", countTasks("grep") == grepsBefore and v.searchTimer and v.searchTimer.kind == "after" and v.searchTimer.delay == 0.3)
local st1 = v.searchTimer
msg({ a = "search", q = "plan " })
check("the next keystroke stops the first timer and arms a new one", st1.stopped and v.searchTimer ~= st1)
v.searchTimer:fire()
local sg = lastTask("grep")
check("the grep: -rniIHF, -m 20, -e plan, the vault, not the [[ pattern; HELD; searching",
      countTasks("grep") == grepsBefore + 1 and taskArgs(sg):find("-rniIHF", 1, true) and taskArgs(sg):find("-m 20", 1, true)
      and taskArgs(sg):find("-e plan " .. VAULT, 1, true) and not taskArgs(sg):find("\\[\\[", 1, true) and v.searchTask == sg and v.searching == true, taskArgs(sg))
sg.cb(0, VAULT .. "/Alpha.md:3:the big plan\n" .. VAULT .. "/Gamma.md:9:no plan here\n/elsewhere/x.md:1:plan\n", "")
check("two rows (the stray path skipped), note · line · text", #v.searchRows == 2 and v.searchRows[1].n == "Alpha" and v.searchRows[1].r == "Alpha.md"
      and v.searchRows[1].l == 3 and v.searchRows[1].x == "the big plan")
check("the rows reach the page by eval, no rebuild, with the query they answer",
      EVALS[#EVALS]:find('^setRows%("search", %[{n:"Alpha",r:"Alpha.md",l:3,x:"the big plan"}') and EVALS[#EVALS]:find(', false, "plan "%)$'), EVALS[#EVALS])
check("lastSearch and the counters", v.lastSearch.hits == 2 and v.lastSearch.files == 2 and v.searches == 1 and v.searching == false and v.searchTask == nil)
v.searchQuery = 'plan "big"'; v.runSearch()
check("AND: the longest term goes to grep", taskArgs(lastTask("grep")):find("-e plan ", 1, true) ~= nil)
lastTask("grep").cb(0, VAULT .. "/Alpha.md:3:the big plan\n" .. VAULT .. "/Gamma.md:9:no plan here\n", "")
check("…the other terms are checked in Lua: Alpha only", #v.searchRows == 1 and v.searchRows[1].r == "Alpha.md")
v.searchQuery = "plan tag:fresh"; v.runSearch()
lastTask("grep").cb(0, VAULT .. "/Alpha.md:3:the big plan\n" .. VAULT .. "/Gamma.md:9:no plan here\n", "")
check("tag:fresh keeps only notes tagged fresh", #v.searchRows == 1 and v.searchRows[1].r == "Alpha.md")
v.searchQuery = "plan path:gam"; v.runSearch()
lastTask("grep").cb(0, VAULT .. "/Alpha.md:3:the big plan\n" .. VAULT .. "/Gamma.md:9:no plan here\n", "")
check("path:gam keeps only rels containing it", #v.searchRows == 1 and v.searchRows[1].r == "Gamma.md")
grepsBefore = countTasks("grep")
v.searchQuery = "tag:fresh"; v.runSearch()
check("operators only: no grep, the note NAMES that pass, line 0", countTasks("grep") == grepsBefore and #v.searchRows == 1 and v.searchRows[1].n == "Alpha" and v.searchRows[1].l == 0)
v.searchQuery = "plan"; v.runSearch()
local s1 = lastTask("grep")
v.runSearch()
check("a second search terminates the first grep", s1.terminated and v.searchTask ~= s1)
s1.cb(0, VAULT .. "/Alpha.md:3:late\n", "")
check("…and its late answer changes nothing", v.searching == true and #v.searchRows == 1)
v.setMode("notes")
check("leaving search mode clears the rows and the task", v.searchRows[1] == nil and v.searchTask == nil and v.mode == "notes")
msg({ a = "mode", m = "search" })
msg({ a = "search", q = "  " })
check("an empty box: no timer, an empty list on the page", v.searchTimer == nil and EVALS[#EVALS] == 'setRows("search", [], false, "")', EVALS[#EVALS])
do
    local lines = {}
    for i = 1, 205 do lines[#lines + 1] = VAULT .. "/Alpha.md:" .. i .. ":plan " .. i end
    v.searchQuery = "plan"; v.runSearch()
    lastTask("grep").cb(0, table.concat(lines, "\n") .. "\n", "")
    check("205 hits → 200 rows and a 'more' flag on the page", #v.searchRows == 200 and v.searchMore == true and EVALS[#EVALS]:find(', true, "plan"%)$'))
    local long = "plan " .. string.rep("a", 114) .. "🙂" .. string.rep("b", 180)
    v.runSearch()
    lastTask("grep").cb(0, VAULT .. "/Alpha.md:1:" .. long .. "\n", "")
    local x = v.searchRows[1].x
    check("a snippet is cut to ≤120 bytes without splitting a UTF-8 character", #x <= 122 and utf8.len(x) ~= nil and x:sub(-3) == "…", #x)
    v.searchQuery = "zzz"; v.runSearch()
    lastTask("grep").cb(0, VAULT .. "/Alpha.md:1:" .. string.rep("x", 100) .. " zzz tail\n", "")
    check("…and starts ≤30 chars before the term, with … where it was cut", v.searchRows[1].x:find("^…") and v.searchRows[1].x:find("zzz", 1, true) ~= nil, v.searchRows[1].x)
    v.searchQuery = "plan"; v.runSearch()
    lastTask("grep").cb(2, "", "grep: boom")
    check("grep exit 2 → searchErr, no rows, the report shows ⚠️", v.searchErr and v.searchErr:find("grep exited 2", 1, true) and #v.searchRows == 0
          and _G.vaultReport():find("search : \"plan\" → 0 hits in 0 notes", 1, true) and _G.vaultReport():find("⚠️ grep exited 2", 1, true), _G.vaultReport():match("search :[^\n]*"))
    v.runSearch()
    lastTask("grep").cb(1, "", "")
    check("grep exit 1 is a clean 'no hit'", v.searchErr == nil and #v.searchRows == 0)
end
msg({ a = "open", name = "Gamma", line = 9 })
check("⏎ on a hit opens the note with CARETLINE = 9 on the page, still in search mode",
      v.doc.rel == "Gamma.md" and WEBVIEWS[#WEBVIEWS].htmlSet:find("CARETLINE = 9", 1, true) and v.mode == "search"
      and WEBVIEWS[#WEBVIEWS].htmlSet:find('MODE = "search"', 1, true) and _G.vaultReport():find("· mode: search", 1, true))
v.render()
check("…and the next render has CARETLINE = 0", WEBVIEWS[#WEBVIEWS].htmlSet:find("CARETLINE = 0", 1, true) ~= nil)
msg({ a = "search", q = "x" })
v.hide()
check("closing the window leaves search mode and drops its task and timer", v.mode == "notes" and v.searchTask == nil and v.searchTimer == nil and v.searchQuery == "")
v.show()
check("the vault.search service runs a search from the Console", (function()
    local ok = PROVIDED["vault.search"]("plan")
    return ok == true and v.mode == "search" and lastTask("grep") and taskArgs(lastTask("grep")):find("-e plan", 1, true)
end)())
v.setMode("notes")

-- =======================================================================
out("12) 6.174.0 — tasks: every open - [ ] in one grep, the open note refreshed from its text\n")
-- =======================================================================
do
    local ts = v.tasksIn("- [ ] a\n  * [ ] b\n+ [ ] c\n3. [ ] d\n- [x] done\n-[ ] no\n")
    check("tasksIn: -, *, + and 1. markers with [ ]; [x] and a missing space are not open",
          #ts == 4 and ts[1].line == 1 and ts[2].line == 2 and ts[3].line == 3 and ts[4].line == 4
          and ts[1].text == "a" and ts[2].text == "b" and ts[3].text == "c" and ts[4].text == "d")
end
msg({ a = "mode", m = "tasks" })
local tk = lastTask("grep")
check("entering ☑ starts the task grep: -rnHIE with the ERE, HELD, listing",
      v.mode == "tasks" and taskArgs(tk):find("-rnHIE", 1, true) and taskArgs(tk):find("^[[:space:]]*([-*+]|[0-9]+\\.) \\[ \\]", 1, true)
      and v.tasksTask == tk and v.tasksListing == true, taskArgs(tk))
local TASKOUT = VAULT .. "/Groceries.md:4:- [ ] buy milk\n" .. VAULT .. "/Alpha.md:2:  * [ ] call\n" .. VAULT .. "/Templates/Meeting.md:3:- [ ] agenda\n" .. VAULT .. "/Alpha.md:5:1. [ ] later\n"
tk.cb(0, TASKOUT, "")
check("3 rows (the template skipped), sorted by note then line, the marker stripped",
      #v.taskRows == 3 and v.taskRows[1].r == "Alpha.md" and v.taskRows[1].l == 2 and v.taskRows[2].l == 5 and v.taskRows[3].r == "Groceries.md" and v.taskRows[3].x == "buy milk")
check("the rows reach the page and the listing is stamped", EVALS[#EVALS]:find('^setRows%("tasks", %[{n:"Alpha"') and v.lastTasks ~= nil and v.tasksListing == false and v.tasksTask == nil, EVALS[#EVALS])
msg({ a = "tasks" })
local tk2 = lastTask("grep")
check("↻ inside the view runs a new grep and terminates the old one", tk2 ~= tk and v.tasksTask == tk2)
local nRows = #v.taskRows
tk.cb(0, VAULT .. "/Stale.md:1:- [ ] stale\n", "")
check("a stale answer changes nothing", #v.taskRows == nRows and v.taskRows[1].r ~= "Stale.md")
tk2.cb(0, TASKOUT, "")
v.openNote("Alpha")
msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n- [ ] one\n- [x] done\n- [ ] two\n", sel = 3 })
local evalsBefore = #EVALS
lastTimer("after"):fire()
check("a save while ☑ is up refreshes the OPEN note's rows from its text — no grep",
      #v.taskRows == 3 and v.taskRows[1].r == "Alpha.md" and v.taskRows[1].l == 2 and v.taskRows[1].x == "one" and v.taskRows[2].l == 4
      and v.taskRows[3].r == "Groceries.md" and #EVALS == evalsBefore + 1 and EVALS[#EVALS]:find('^setRows%("tasks"') and countTasks("grep") == countTasks("grep"))
v.setMode("notes")
msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n- [ ] one\n", sel = 3 })
evalsBefore = #EVALS
lastTimer("after"):fire()
check("…in notes mode the same save evaluates nothing", #EVALS == evalsBefore)
msg({ a = "mode", m = "tasks" })
lastTask("grep").cb(0, TASKOUT, "")
grepsBefore = countTasks("grep")
msg({ a = "rescan" })
check("↻ (rescan) in tasks mode starts a task grep", countTasks("grep") == grepsBefore + 1 and taskArgs(lastTask("grep")):find("-rnHIE", 1, true) ~= nil)
lastTask("grep").cb(1, "", "")
check("exit 1: no tasks, no error", #v.taskRows == 0 and v.tasksErr == nil)
lastTask("grep").cb(2, "", "grep: boom")
msg({ a = "tasks" })
lastTask("grep").cb(2, "", "grep: boom")
check("exit 2: tasksErr, shown in the report", v.tasksErr and _G.vaultReport():find("tasks  : 0 open in 0 notes · listed", 1, true) and _G.vaultReport():find("⚠️ grep exited 2", 1, true))
msg({ a = "tasks" })
lastTask("grep").cb(0, TASKOUT, "")
check("the report counts open tasks and notes", _G.vaultReport():find("tasks  : 3 open in 2 notes · listed", 1, true) ~= nil, _G.vaultReport():match("tasks  :[^\n]*"))
check("the vault.tasks service lists from the Console", PROVIDED["vault.tasks"]() == true and v.mode == "tasks")
v.setMode("notes")

-- =======================================================================
out("13) 6.174.0 — unlinked mentions: whole-word grep -l, minus self, backlinkers and templates\n")
-- =======================================================================
v.openNote("Alpha")
local mg = lastTask("grep")
check("opening Alpha starts a mentions grep (-rliwIF -e Alpha), HELD, pending for key alpha",
      taskArgs(mg):find("-rliwIF", 1, true) and taskArgs(mg):find("-e Alpha " .. VAULT, 1, true) and v.mentionTask == mg
      and v.unlinked.pending == true and v.unlinked.key == "alpha", taskArgs(mg))
mg.cb(0, VAULT .. "/Alpha.md\n" .. VAULT .. "/Projects/Beta.md\n" .. VAULT .. "/Gamma.md\n" .. VAULT .. "/Templates/Meeting.md\n", "")
check("Gamma is the one unlinked mention (Alpha itself, Beta the backlinker and the template drop out)",
      same(v.unlinked.rels, { "Gamma.md" }) and v.unlinked.pending == false and v.mentionTask == nil)
check("…and the page gets it by eval, keyed to the note", EVALS[#EVALS] == 'setMentions([{n:"Gamma",r:"Gamma.md"}], "alpha", "")', EVALS[#EVALS])
v.render()
check("a rebuild pre-fills the pane from Lua", WEBVIEWS[#WEBVIEWS].htmlSet:find('UNLINKED MENTIONS · 1</h4><ul id="unl"><li class="lnk" data-name="Gamma" title="Gamma.md">≈ Gamma</li>', 1, true) ~= nil)
check("the report has the mentions line", _G.vaultReport():find("mentions: 1 unlinked for Alpha.md · extracts: 0 · random: 0", 1, true) ~= nil, _G.vaultReport():match("mentions:[^\n]*"))
v.openNote("Alpha")
mg = lastTask("grep")
v.openNote("Gamma")
check("opening another note terminates the probe", mg.terminated and v.unlinked.key == "gamma" and v.unlinked.pending == true)
local n13 = #EVALS
mg.cb(0, VAULT .. "/Delta.md\n", "")
check("…and its answer is discarded", v.unlinked.key == "gamma" and v.unlinked.rels[1] == nil and #EVALS == n13)
check("the report says it is looking", _G.vaultReport():find("mentions: looking for Gamma.md", 1, true) ~= nil)
grepsBefore = countTasks("grep")
v.openNote("Brand New")
check("a note created this instant starts no probe", countTasks("grep") == grepsBefore and v.unlinked.key ~= "brand new")
check("…and the report says so", _G.vaultReport():find("mentions: not searched for Brand New.md (new note)", 1, true) ~= nil, _G.vaultReport():match("mentions:[^\n]*"))
do
    FILES[VAULT .. "/Bo.md"] = "# Bo\n"
    local rels = {}
    for _, nn in ipairs(v.notes) do rels[#rels + 1] = nn.rel end
    rels[#rels + 1] = "Bo.md"
    v.setNotes(rels)
    grepsBefore = countTasks("grep")
    v.openNote("Bo")
    check("a two-letter name is not searched for", countTasks("grep") == grepsBefore and v.unlinked.why == "too short" and v.unlinked.pending == false)
    check("…said in the report", _G.vaultReport():find("mentions: not searched for Bo.md (name too short)", 1, true) ~= nil)
end
v.openNote("Alpha")
do
    local lines = {}
    for i = 1, 51 do lines[#lines + 1] = VAULT .. "/M" .. string.format("%02d", i) .. ".md" end
    lastTask("grep").cb(0, table.concat(lines, "\n") .. "\n", "")
    check("51 files → the first 50, marked 'more'", #v.unlinked.rels == 50 and v.unlinked.more == true and EVALS[#EVALS]:find(', "alpha", "more"%)$'))
end
v.openNote("Alpha")
lastTask("grep").cb(2, "", "grep: boom")
check("a grep error is kept, not alerted", v.unlinked.why and v.unlinked.why:find("grep exited 2", 1, true) and EVALS[#EVALS]:find('"grep exited 2: grep: boom"%)$'))
v.openNote("Alpha")
lastTask("grep").cb(1, "", "")
check("no mention: an empty answer", v.unlinked.rels[1] == nil and v.unlinked.why == nil and _G.vaultReport():find("mentions: none for Alpha.md", 1, true))

-- =======================================================================
out("14) 6.174.0 — extract the selection into a new note\n")
-- =======================================================================
msg({ a = "edit", rel = "Alpha.md", text = "# Alpha\n\nkeep this\nmove me\n", sel = 3 })
lastTimer("after"):fire()
PROMPT_ANSWERS = { { "Create", "" } }
msg({ a = "extract", head = "# Alpha\n\nkeep this\n", selText = "move me" })
check("the prompt offers the first line as the name", PROMPTS[#PROMPTS].title == "Extract to a new note" and PROMPTS[#PROMPTS].dflt == "move me", PROMPTS[#PROMPTS].dflt)
check("the source keeps [[move me]] where the selection was, saved at once", FILES[VAULT .. "/Alpha.md"] == "# Alpha\n\nkeep this\n[[move me]]\n", FILES[VAULT .. "/Alpha.md"])
check("the new note is # name + the selection, and it opens", FILES[VAULT .. "/move me.md"] == "# move me\n\nmove me\n" and v.doc.rel == "move me.md" and v.extracts == 1)
msg({ a = "extract", head = "", selText = "  " })
check("no selection → an alert", ALERTS[#ALERTS]:find("select some text first", 1, true) ~= nil)
local snap = FILES[VAULT .. "/move me.md"]
msg({ a = "extract", head = "wrong", selText = "move me" })
check("a page whose text disagrees with Lua's copy is refused, nothing written", ALERTS[#ALERTS]:find("the text changed", 1, true) and FILES[VAULT .. "/move me.md"] == snap)
PROMPT_ANSWERS = { { "Create", "Gamma" } }
msg({ a = "extract", head = "# move me\n\n", selText = "move me" })
check("an existing name is refused, nothing written", ALERTS[#ALERTS]:find('a note named "Gamma" already exists', 1, true) and FILES[VAULT .. "/move me.md"] == snap and v.doc.rel == "move me.md")
PROMPT_ANSWERS = { { "Cancel", "" } }
msg({ a = "extract", head = "# move me\n\n", selText = "move me" })
check("Cancel writes nothing", FILES[VAULT .. "/move me.md"] == snap and v.extracts == 1)
do
    local keep = v.doc
    v.doc = { scratch = "x", rel = "scratch:x", name = "x", text = "hello" }
    msg({ a = "extract", head = "", selText = "hello" })
    check("a scratch tab cannot extract", ALERTS[#ALERTS]:find("not a scratch tab", 1, true) ~= nil)
    v.doc = keep
end
msg({ a = "edit", rel = "move me.md", text = "# move me\n\n- [ ] Buy list\nmilk\n", sel = 3 })
PROMPT_ANSWERS = { { "Cancel", "" } }
msg({ a = "extract", head = "# move me\n\n", selText = "- [ ] Buy list\nmilk" })
check("the default name strips the list marker and box", PROMPTS[#PROMPTS].dflt == "Buy list", PROMPTS[#PROMPTS].dflt)

-- =======================================================================
out("15) 6.174.0 — daily ‹ ›: the day before / after, no template\n")
-- =======================================================================
check("dailyEpochOf reads Daily/YYYY-MM-DD.md and nothing else",
      os.date("%Y-%m-%d", v.dailyEpochOf("Daily/2026-09-06.md")) == "2026-09-06" and v.dailyEpochOf("Alpha.md") == nil and v.dayOf("daily/2026-09-06.md") == "2026-09-06")
msg({ a = "daily" })
local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
msg({ a = "dayshift", d = -1, rel = v.doc.rel, text = v.doc.text, sel = 0 })
check("‹ opens the day before, created with the weekday heading",
      v.doc.rel == "Daily/" .. yesterday .. ".md" and FILES[VAULT .. "/Daily/" .. yesterday .. ".md"] == "# " .. os.date("%A %d %B %Y", os.time() - 86400) .. "\n\n", v.doc.rel)
local todayText = FILES[VAULT .. "/Daily/" .. today .. ".md"]
msg({ a = "dayshift", d = 1, rel = v.doc.rel, text = v.doc.text, sel = 0 })
check("› from there opens today's note unchanged", v.doc.rel == "Daily/" .. today .. ".md" and FILES[VAULT .. "/Daily/" .. today .. ".md"] == todayText)
local hd = WEBVIEWS[#WEBVIEWS].htmlSet
check("a daily note's page knows the days either side", hd:find('DAILY = {prev:"' .. yesterday .. '",next:"' .. os.date("%Y-%m-%d", os.time() + 86400) .. '"}', 1, true) ~= nil, hd:match("var DAILY[^\n]*"))
check("…and its header wears ‹ yesterday · tomorrow › (dayshift buttons)",
      hd:find('title="Previous day ⌘⇧[">‹ ' .. yesterday .. '</button>', 1, true) ~= nil
      and hd:find('title="Next day ⌘⇧]">' .. os.date("%Y-%m-%d", os.time() + 86400) .. ' ›</button>', 1, true) ~= nil)
v.openNote("Alpha"); v.render()
msg({ a = "dayshift", d = -1 })
check("‹ › with a plain note open only alerts", v.doc.rel == "Alpha.md" and ALERTS[#ALERTS]:find("open a daily note first", 1, true) ~= nil)
check("…and its page has DAILY = null", WEBVIEWS[#WEBVIEWS].htmlSet:find("DAILY = null", 1, true) ~= nil)

-- =======================================================================
out("16) 6.174.0 — a random note, never a template, never this one\n")
-- =======================================================================
math.randomseed(1)
do
    local okAll, prev = true, v.doc.rel
    for _ = 1, 10 do
        msg({ a = "random" })
        if v.doc.rel == prev or v.isTemplateRel(v.doc.rel) then okAll = false end
        prev = v.doc.rel
    end
    check("ten ⌘⇧R never reopen the same note nor a template", okAll and v.randoms == 10, v.doc.rel)
    local rels = {}
    for _, nn in ipairs(v.notes) do rels[#rels + 1] = nn.rel end
    v.setNotes({ "Alpha.md", "Templates/Meeting.md" })
    v.openNote("Alpha")
    msg({ a = "random" })
    check("only templates and the open note left → an alert", ALERTS[#ALERTS]:find("nothing else to open", 1, true) and v.doc.rel == "Alpha.md" and v.randoms == 10)
    v.setNotes(rels)
    check("the report counts extracts and randoms", _G.vaultReport():find("· extracts: 1 · random: 10", 1, true) ~= nil)
end

-- =======================================================================
out("17) 6.174.0 — the doors: no new hyper key, the source sentries, the page's contract\n")
-- =======================================================================
do
    local n17 = 0
    for k in pairs(HYPER) do n17 = n17 + 1 end
    check("still ONE hyper key (⇪3) — ⇪⇧T / ⇪⇧U / ⇪⇧Z untouched", n17 == 1 and HYPER["|3"] ~= nil)
    local rf = io.popen("cat '" .. HS .. "/modules/vault.lua'")
    local real = rf and rf:read("a") or ""
    if rf then rf:close() end
    local _, taskNews = real:gsub("pcall%(hs%.task%.new", "")
    check("exactly five task births: find, link grep, tag grep, front-matter grep, startTask", taskNews == 5, taskNews)
    check("no hs.json, no eventtap, no hs.window, every timer held", not real:find("hs%.json") and not real:find("hs%.eventtap%.new")
          and not real:find("hs%.window%.") and not real:find("\n%s*hs%.timer%.do"))
    check("templates are read by /bin/cat in a task, never io.open", real:find('CAT             = "/bin/cat"', 1, true) and not real:find("io%.open%(rec"))
    check("vault.search and vault.tasks are published", PROVIDED["vault.search"] ~= nil and PROVIDED["vault.tasks"] ~= nil)
    local names = {}
    for _, e in ipairs(mod.cheatsheet.entries) do names[e[1]] = e[2] end
    check("the cheat sheet names the new keys", names["#tag"] and names["⌘⇧F"] and names["⌘⇧K · ⌘L"] and names["⌘⇧N · ⌘⇧T"] and names["⌘⇧E · ⌘⇧R"]
          and names["⌘F · ⌘O · ↑↓ ⏎"] and names["OUTLINE · ≈"] and names["⌘N · ⌘D"]:find("Templates/Daily.md", 1, true))
    check("the summary grew", mod.summary:find("tags, templates, full-text search, tasks", 1, true) ~= nil)
    v.render()
    local hp = WEBVIEWS[#WEBVIEWS].htmlSet
    check("the page has the Lua → page state and the mentions pane; one script block; insertAtCaret takes a tail",
          hp:find('var SEARCH = {q:"", rows:[], more:false, err:"", busy:false}', 1, true) and hp:find("var TASKS = {rows:[", 1, true)
          and hp:find('var UNL = {key:"alpha"', 1, true) and hp:find('id="unlh"', 1, true) and hp:find('id="unl"', 1, true)
          and hp:find("function insertAtCaret(str, tail)", 1, true) and select(2, hp:gsub("<script", "")) == 1 and not hp:find("FS%d?px") and not hp:find("FSNUM"))
    -- the page itself (6.174.0): the ids, the globals and the functions Lua and the JS suite rely on
    local function has(...) for _, needle in ipairs({ ... }) do if not hp:find(needle, 1, true) then return false, needle end end return true end
    check("the page has the mode strip, the 🔎 ☑ buttons, the footer, chips and outline", has('id="mode"', 'id="sbtn"', 'id="kbtn"', 'id="foot"', 'id="chips"', 'id="outline"', 'id="hint"'))
    check("…the page-side globals", has('MODE = "notes"', 'TEMPLATES = [', 'TPLDIR = "Templates"', 'SMARTLISTS = true', 'LINEH = 13 * 1.5', 'TAGROWS = 15', 'CURKEY = "alpha"', 'DAILY = '))
    check("…the Lua → page entry points and the page's own helpers", has("function setRows", "function setMentions", "function vaultHint", "function gotoLine", "function toggleTask", "function tplPick", "function setMode", "function tagsOf", "function drawOutline", "function drawFoot"))
    check("…the messages the new keys send", has("a:'tplnew'", "a:'tplinsert'", "a:'search'", "a:'dayshift'", "a:'extract'", "a:'random'", "a:'mode'", "a:'tplnone'"))
    check("tag rows walk with the ONE row walker (ROWSEL)", hp:find("ROWSEL = '#rows li[data-name],#rows li[data-tab],#rows li[data-tag]'", 1, true) ~= nil)
    check("the chips sit first in the right pane, the OUTLINE last, after the mentions",
          hp:find('<div id="links"><div id="chips" hidden></div><h4>LINKS OUT</h4>', 1, true) ~= nil and hp:find('<h4>OUTLINE</h4><ul id="outline"></ul></div>', 1, true) ~= nil
          and hp:find('<ul id="unl">', 1, true) < hp:find('<h4>OUTLINE</h4>', 1, true))
    -- 6.183.0 — 🔎 QUERY sits between the mentions and the outline, and it
    -- ships HIDDEN: a note with no query block must look exactly as it did.
    check("6.183.0: the 🔎 QUERY block sits after the mentions and before the outline, hidden until a note has one",
          hp:find('<div id="qbox" hidden><h4 id="qh">🔎 QUERY</h4><ul id="qres"></ul></div>', 1, true) ~= nil
          and hp:find('<ul id="unl">', 1, true) < hp:find('id="qbox"', 1, true)
          and hp:find('id="qbox"', 1, true) < hp:find('<h4>OUTLINE</h4>', 1, true))
    -- BOTH DIRECTIONS of the bridge, read off the code: every a:'x' the page can send has a
    -- handleMessage branch; every function Lua evals exists on the page
    local missing = {}
    for act in hp:gmatch("a:'([%w_]+)'") do
        if not real:find('a == "' .. act .. '"', 1, true) then missing[#missing + 1] = act end
    end
    check("every action the page sends has a Lua branch", #missing == 0, table.concat(missing, ","))
    local noFn = {}
    for fn in real:gmatch("v%.eval%([\"']([%a_]+)%(") do
        if not hp:find("function " .. fn .. "(", 1, true) then noFn[#noFn + 1] = fn end
    end
    check("every function Lua evals is defined on the page", #noFn == 0, table.concat(noFn, ","))
    -- a scratch tab's page: no note panes, the footer and the tag rows still there
    if v.sp() then
        v.openScratch(nil); v.render()
        local hs17 = WEBVIEWS[#WEBVIEWS].htmlSet
        local markup = hs17:match("^(.-)<script>") or ""
        check("a scratch tab's page has no chips, outline or mentions pane — the footer stays",
              not markup:find('id="chips"', 1, true) and not markup:find("OUTLINE", 1, true) and not markup:find("UNLINKED", 1, true) and markup:find('id="foot"', 1, true) ~= nil)
        v.openNote("Alpha"); v.render()
    end
end

-- =======================================================================
out("18) 6.174.0 review — the killed task, the note the index has not seen,\n")
out("    link-safe names, the stale filter and the page handshake\n")
-- =======================================================================
do
    v.openNote("Alpha"); v.render()
    -- (a) a terminated task's exit (15) is not an answer
    v.setMode("tasks")                       -- starts the ☑ grep
    local tt = v.tasksTask
    v.tasksErr, v.lastTasks = nil, nil
    v.hide()                                 -- terminates it: the stub fires cb(15, …)
    check("closing the window mid-☑-grep is not reported as a grep failure",
          v.tasksErr == nil and v.lastTasks == nil and tt ~= nil and tt.terminated == true, tostring(v.tasksErr))
    v.open(); v.openNote("Alpha")
    local mt = lastTaskWith("grep", "-rliwIF")
    v.hide()
    check("…nor is a terminated mentions grep", v.unlinked.why == nil and mt ~= nil and mt.terminated == true, tostring(v.unlinked.why))
    v.open(); v.openNote("Alpha"); v.render()
    local before = #ALERTS
    v.insertTemplate("Meeting")
    local ct, tm = lastTask("cat"), v.catTimer
    if tm then tm.fn() end                   -- the 10 s timeout fires and kills the read
    check("a template that never arrives says so ONCE, not twice",
          ct ~= nil and ct.terminated == true and #ALERTS == before + 1
          and ALERTS[#ALERTS]:find("did not arrive", 1, true) ~= nil, table.concat(ALERTS, " | ", before + 1))

    -- (b) a note the index has not seen yet is OPENED, never seeded over
    local rel = VAULT .. "/Daily/2026-09-05.md"
    FILES[rel] = "# Friday\n\nyesterday's words\n"
    v.notes, v.byKey = {}, {}                -- as after a reload, before the find lands
    v.openNote("2026-09-05", "Daily", "# seeded\n\n")
    check("a note the index does not know is read off disk, not overwritten",
          v.doc.text == "# Friday\n\nyesterday's words\n" and v.doc.created ~= true
          and FILES[rel] == "# Friday\n\nyesterday's words\n", v.doc.text)
    v.scan("restore"); lastTask("find").cb(0, table.concat({
        VAULT .. "/Alpha.md", VAULT .. "/Beta.md", VAULT .. "/Templates/Meeting.md" }, "\n"), "")
    local lg = lastTaskWith("grep", "%[%[") ; if lg then lg.cb(1, "", "") end
    finishTagGreps()

    -- (c)(d) a name that has to survive [[ ]]
    v.openNote("Alpha"); v.setText("keep ## Q3 plan #work\nmore\n")
    PROMPT_ANSWERS[1] = { "Create", "" }     -- take the offered default
    v.extract("keep ", "## Q3 plan #work\nmore\n")
    check("an extracted name keeps no character that [[links]] cannot address",
          PROMPTS[#PROMPTS].dflt == "Q3 plan work" and v.doc.name == "Q3 plan work"
          and FILES[VAULT .. "/Alpha.md"]:find("[[Q3 plan work]]", 1, true) ~= nil, PROMPTS[#PROMPTS].dflt)
    check("…and the link resolves to the note that was just created",
          v.linkTarget("Q3 plan work") == v.doc.name, v.linkTarget("Q3 plan work"))
    v.openNote("Alpha"); v.setText("Xcode tips\nrest\n")
    PROMPT_ANSWERS[1] = { "Cancel", "" }
    v.extract("", "Xcode tips\nrest\n")
    check("a selection starting with an X keeps it (the [ ] box comes off whole)",
          PROMPTS[#PROMPTS].dflt == "Xcode tips", PROMPTS[#PROMPTS].dflt)
    v.openNote("Alpha"); v.setText("- [x] done thing\n")
    PROMPT_ANSWERS[1] = { "Cancel", "" }
    v.extract("", "- [x] done thing\n")
    check("…and a ticked task line still loses its box", PROMPTS[#PROMPTS].dflt == "done thing", PROMPTS[#PROMPTS].dflt)

    -- (e) the notes filter never reaches the ☑ box
    v.openNote("Alpha"); v.filter = "alp"; v.setMode("tasks"); v.render()
    check("a rebuild in ☑ TASKS mode leaves the box empty, not on the notes filter",
          WEBVIEWS[#WEBVIEWS].htmlSet:find('id="q" placeholder="filter notes… ⌘F" value=""', 1, true) ~= nil)
    v.setMode("notes"); v.render()

    -- (f) a note that starts with a blank line reaches the page whole
    v.openNote("Alpha"); v.setText("\n# after a blank line\n"); v.render()
    check("a leading blank line survives the textarea (the spare newline HTML eats)",
          WEBVIEWS[#WEBVIEWS].htmlSet:find(">\n\n# after a blank line", 1, true) ~= nil)

    -- (g) the page says when it is ready, and gets what arrived meanwhile
    v.openNote("Alpha")
    v.unlinked = { key = v.doc.key, rels = { "Gamma.md" }, pending = false, why = nil, more = false }
    EVALS[#EVALS + 1] = "sentinel"
    msg({ a = "ready" })
    check("the page's ready handshake re-sends the mentions answer it missed",
          EVALS[#EVALS]:find('setMentions([{n:"Gamma",r:"Gamma.md"}], "alpha"', 1, true) ~= nil, EVALS[#EVALS])
    check("the page announces itself when its load sequence ends",
          WEBVIEWS[#WEBVIEWS].htmlSet:find("say({a:'ready'})", 1, true) ~= nil)
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
