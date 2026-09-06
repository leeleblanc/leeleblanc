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
        function t:terminate() self.terminated = true end     -- 6.174.0 — a superseded task is stopped
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
    local fg = lastTaskWith("grep", "^tags?:")
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
    check("…then a FRONT-MATTER grep (-m 1 -A 12, ^tags?:)", fg and fg ~= tg and fg.started
          and taskArgs(fg):find("-m 1 -A 12", 1, true) and taskArgs(fg):find("^tags?:", 1, true) and v.fmTask == fg, taskArgs(fg))
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
check("6.173.2: the window is 10% see-through by default (alpha 0.9 applied)", v.alpha == 0.9 and view.alphaSet == 0.9, tostring(view.alphaSet))
check("a scan runs on open and a held rescan timer is armed", lastTask("find") and lastTask("find").started and v.rescanTimer and v.rescanTimer.kind == "every")
local h = view.htmlSet or ""
check("the page lists every note and the open one", h:find("NOTES = %[") and h:find('"Alpha"') and h:find('"New Idea"') and h:find('CUR = "Alpha.md"'))
check("the page carries the row walker block", h:find("function rowKey") and h:find("function moveSel") and h:find("function rowAct") and h:find("e%.altKey || !inText%(%)"))
check("the page forwards an F18 keyup", h:find("a:'f18up'"))
check("the page has the [[ autocomplete and ⌘⏎ follow", h:find("function autocomplete") and h:find("function linkAtCaret") and h:find("a:'follow'"))
check("the page has the graph canvas and force layout", h:find('id="cv"') and h:find("function graphStart") and h:find("GRAPH = {nodes:"))
check("text is 16 px and no placeholder survives", h:find("font%-size:16px") and not h:find("FS%d?px") and not h:find("FSLABEL"))
check("backlinks pane lists Beta for Alpha", h:find('← Beta'))
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
    check("the report shows the alpha and how to make it solid", r:find("alpha 0.90 (see-through; vault = { alpha = 1 } for solid)", 1, true) ~= nil, r)
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
    check("the textarea holds the tab's text", h:find("<textarea", 1, true) and h:find(">groceries\nmilk [[Alpha]]</textarea>", 1, true))
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
    check("the report has the scratch line", _G.vaultReport():find("scratch: 3 tabs of the Scorp Pad", 1, true) ~= nil)
    _G.scratchPad = nil
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
