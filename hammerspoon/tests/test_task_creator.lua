-- =====================================================================
-- test_task_creator.lua — the Asana Task Creator as a module. 6.98.0
-- =====================================================================
--     lua5.4 test_task_creator.lua [/path/to/hammerspoon]
--
-- The creator moved out of init.lua in 6.98.0. This suite boots the
-- REAL module with a Mac-in-tables and proves:
--
--   C1  the 30-day history loads, prunes, and saves on real disk
--   C2  the pipe parser still forgives quotes, ~, and leading junk
--   C3  assignee autocomplete works — and a missing asana_comments
--       roster costs autocomplete, never the picker
--   C4  the one shared submit path validates before it posts
--   C5  🔐 the attachment upload NEVER puts the token in curl's
--       argument list — it travels in a chmod-600 header file that is
--       deleted the moment curl answers, and success is judged by the
--       real HTTP status, not curl's exit code
--   C6  drafts survive, hotkeys land where they always did, and
--       warm() sweeps header files a killed Hammerspoon left behind
--
-- task_form.lua's side of the story is test_taskform.lua (it stubs
-- _G.asanaSubmitTask; here the real one answers).

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        io.write("   ❌ " .. failures[#failures] .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a Mac in tables --------------------------------------------------
local TMP = "/tmp/hs-test-task-creator-" .. tostring(os.time())
os.execute('rm -rf "' .. TMP .. '" && mkdir -p "' .. TMP .. '"')

local ALERTS, HTTP_POSTS, HTTP_GETS, TASKS, WARNS = {}, {}, {}, {}, {}
local BOUND, HYPER, SERVICE_CALLS = {}, {}, {}
local POPUPS, PASTE, PASTE_SET = 0, nil, nil
local NEXT_JSON = nil
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function alerted(needle)
    for _, a in ipairs(ALERTS) do if a:find(needle, 1, true) then return true end end
end

-- hs.json stand-in: a Lua-literal round trip. Both halves are ours, so
-- what the module writes it can read back — which is all the real
-- hs.json guarantees the module relies on.
local function ser(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        if #v > 0 then
            for _, x in ipairs(v) do parts[#parts + 1] = ser(x) end
        else
            for k, x in pairs(v) do
                parts[#parts + 1] = "[" .. string.format("%q", tostring(k)) .. "]=" .. ser(x)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v)
    else return tostring(v) end
end

local function newChooserStub(fn)
    local c = { fn = fn, queries = {} }
    function c:placeholderText(p) self.placeholder = p; return self end
    function c:choices(list) self.rows = list; return self end
    function c:query(q)
        if q ~= nil then table.insert(self.queries, q); self.q = q; return self end
        return self.q
    end
    function c:queryChangedCallback(f) self.qcb = f; return self end
    function c:width(w) self.w = w; return self end
    function c:isVisible() return false end
    return c
end

hs = {
    json  = { encode = function(t) return ser(t) end,
              decode = function(s) local f = load("return " .. s); return f and f() end },
    alert = { show = function(msg) table.insert(ALERTS, tostring(msg)) end },
    chooser = { new = newChooserStub },
    hotkey = { bind = function(mods, key, fn)
        BOUND[table.concat(mods, "+") .. "|" .. tostring(key)] = fn; return {} end },
    http = {
        asyncPost = function(url, body, headers, cb)
            table.insert(HTTP_POSTS, { url = url, body = body, headers = headers, cb = cb }) end,
        asyncGet = function(url, headers, cb)
            table.insert(HTTP_GETS, { url = url, headers = headers, cb = cb }) end,
    },
    task = { new = function(path, cb, args)
        local t = { path = path, cb = cb, args = args }
        function t:start() self.started = true; return true end
        table.insert(TASKS, t); return t end },
    pasteboard = { readString = function() return PASTE end,
                   setContents = function(s) PASTE_SET = s end },
    canvas = { windowLevels = { overlay = 1 }, new = function() return nil end },
    timer  = { secondsSinceEpoch = function() return os.time() end },
    fs = {
        attributes = function(p)
            if os.execute('test -e "' .. p .. '"') then return { mode = "file" } end
            return nil
        end,
        mkdir = function(p) return os.execute('mkdir -p "' .. p .. '"') end,
        dir = function(p)
            local h = io.popen('ls -1 "' .. p .. '" 2>/dev/null')
            local all = {}
            if h then for l in h:lines() do all[#all + 1] = l end; h:close() end
            local i = 0
            return function() i = i + 1; return all[i] end
        end,
    },
}

_G.choosers = {}
_G.asanaTaskHistory = {}
_G.asanaTeamMembers = {
    { name = "Sarah Chen",  gid = "123456789012345", email = "sc@example.edu" },
    { name = "Lee LeBlanc", gid = "222222222222222", email = "ll@example.edu" },
}

local ASANA_OK = true
local core = {
    logsDir = TMP, hostTag = "TestMac", configDir = TMP,
    homeDir = "/Users/lee",
    adoptLegacyFile = function() end,
    warnWriteFailed = function(what) table.insert(WARNS, what) end,
    showPopup = function() POPUPS = POPUPS + 1 end,
    resolveBaseScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end } end,
    chooserTopLeft = function() return { x = 0, y = 100 } end,
    panelAlpha = 0.9,
    requireAsana = function()
        if ASANA_OK then return true end
        table.insert(ALERTS, "🔒 Asana is off on this Mac"); return false
    end,
    asanaToken = "SECRET-TOKEN-abc123",
    asanaProjectId = "PROJ1",
    safeJson = function() return NEXT_JSON end,
    call = function(name, ...) table.insert(SERVICE_CALLS, { name = name, ... }) end,
    hyperAddShortcut = function(mods, key, fn)
        HYPER[table.concat(mods or {}, "+") .. "|" .. tostring(key)] = fn end,
}

-- =====================================================================
out("\n=== C1. History: load → prune 30 days → save, on real disk ===\n")

local histFile = TMP .. "/asana_history-TestMac.json"
local fresh = { title = "keep me",  timestamp = os.time() - 1000 }
local stale = { title = "forget me", timestamp = os.time() - 40 * 86400 }
local f = assert(io.open(histFile, "w"))
f:write(ser({ stale, fresh })); f:close()

local chunk = assert(loadfile(HS .. "/modules/task_creator.lua"))
local M = chunk()
check("the module keeps the contract (table with setup)",
      type(M) == "table" and type(M.setup) == "function")
check("it ships a profile-overridable config with the auto-comment knob",
      type(M.config) == "table" and type(M.config.autoComment) == "string")
check("init.lua's BASE list loads it on every Mac", (function()
    local fh = io.open(HS .. "/init.lua", "r"); if not fh then return false end
    local src = fh:read("*a"); fh:close()
    local base = src:match("local BASE = {(.-)\n}") or ""
    return base:find('"task_creator"', 1, true) ~= nil
end)())

local okSetup, setupErr = pcall(M.setup, core)
check("setup() runs clean", okSetup, setupErr)
check("the 40-day-old entry was pruned, the fresh one kept",
      #_G.asanaTaskHistory == 1 and _G.asanaTaskHistory[1].title == "keep me",
      #_G.asanaTaskHistory)
check("...and the pruned version went straight back to disk", (function()
    local fh = io.open(histFile, "r"); if not fh then return false end
    local on = hs.json.decode(fh:read("*a")); fh:close()
    return #on == 1 and on[1].title == "keep me"
end)())

out("\n=== C2. The pipe parser forgives what pasting does to paths ===\n")

local chooser = _G.choosers.task
check("the pipe chooser exists and is armored",
      chooser ~= nil and type(chooser.qcb) == "function")

local function actionRow(query)
    chooser.qcb(query)
    for _, row in ipairs(chooser.rows or {}) do
        if row.isAction then return row end
    end
end

local row = actionRow("Fix the printer | It is angry | | '~/shot.png'")
check("quotes are stripped and ~ becomes the home folder",
      row and row.rawAttach == "/Users/lee/shot.png", row and row.rawAttach)
row = actionRow("time|||/path/file.png")
check("no-space pipes still land the path in field 4",
      row and row.rawAttach == "/path/file.png", row and row.rawAttach)
row = actionRow("title | | | r /Users/lee/a.png")
check("leading junk before the first / is dropped",
      row and row.rawAttach == "/Users/lee/a.png", row and row.rawAttach)

out("\n=== C3. Assignee autocomplete — and life without the roster ===\n")

chooser.qcb("Task | | sa")
local suggestion
for _, r in ipairs(chooser.rows) do
    if r.isAssigneeSuggestion then suggestion = r break end
end
check("two pipes + a partial name suggests from the roster",
      suggestion and suggestion.memberName == "Sarah Chen",
      suggestion and suggestion.memberName)

chooser.qcb("Task | | zz")
local noMatch
for _, r in ipairs(chooser.rows) do
    if (r.text or ""):find("No team member matches", 1, true) then noMatch = r end
end
check("zero matches says so on a safe no-op row",
      noMatch ~= nil and noMatch.isHistory == true)

_G.asanaTeamMembers = nil
printed = {}
chooser.qcb("Task | | sa")
check("no roster (asana_comments off) costs autocomplete, NOT the picker",
      (function()
          for _, l in ipairs(printed) do
              if l:find("render error", 1, true) then return false end
          end
          for _, r in ipairs(chooser.rows) do
              if r.isAction then return true end
          end
      end)())
_G.asanaTeamMembers = {
    { name = "Sarah Chen",  gid = "123456789012345", email = "sc@example.edu" },
    { name = "Lee LeBlanc", gid = "222222222222222", email = "ll@example.edu" },
}

out("\n=== C4. One submit path, validating before it posts ===\n")

ALERTS, HTTP_POSTS = {}, {}
check("an empty title is refused with an alert, nothing posted",
      _G.asanaSubmitTask("", "", "", "") == false
      and alerted("title cannot be empty") and #HTTP_POSTS == 0)

ALERTS, HTTP_POSTS = {}, {}
check("a short digit string is NOT trusted as a GID (6.16.14 rule)",
      _G.asanaSubmitTask("T", "", "1", "") == false
      and alerted("No team member matches") and #HTTP_POSTS == 0)

ALERTS, HTTP_POSTS = {}, {}
check("a typed name resolves to the roster GID before the API sees it",
      _G.asanaSubmitTask("Named", "", "sarah chen", "") == true
      and #HTTP_POSTS == 1
      and HTTP_POSTS[1].body:find("123456789012345", 1, true) ~= nil)

HTTP_POSTS = {}
_G.asanaSubmitTask("Do thing", "the details", "me", "")
local post = HTTP_POSTS[1]
check("the post goes to the tasks endpoint",
      post and post.url == "https://app.asana.com/api/1.0/tasks")
check("the token travels in a header, never the body",
      post and post.headers["Authorization"] == "Bearer SECRET-TOKEN-abc123"
      and post.body:find("SECRET%-TOKEN") == nil)
check("the task is filed into the configured project",
      post and post.body:find("PROJ1", 1, true) ~= nil)
local entry = _G.asanaTaskHistory[#_G.asanaTaskHistory]
check("the history row shows ⏳ while the answer is out",
      entry and entry.displaySub:find("⏳", 1, true) == 1, entry and entry.displaySub)

ALERTS, SERVICE_CALLS, NEXT_JSON = {}, {}, { data = { gid = "999" } }
post.cb(201, "{}")
check("a 201 alerts success and stamps the history row ✅",
      alerted("✅ Task Created") and entry.displaySub:find("✅", 1, true) == 1)
check("...and the auto-comment goes through the asana_comments service",
      SERVICE_CALLS[1] and SERVICE_CALLS[1].name == "asana.addComment"
      and SERVICE_CALLS[1][1] == "999"
      and SERVICE_CALLS[1][2] == M.config.autoComment)
check("...and the outcome is persisted to disk", (function()
    local fh = io.open(histFile, "r"); if not fh then return false end
    local on = hs.json.decode(fh:read("*a")); fh:close()
    return on[#on] and on[#on].title == "Do thing"
end)())

HTTP_POSTS, SERVICE_CALLS = {}, {}
M.config.autoComment = ""
_G.asanaSubmitTask("Quiet one", "", "", "")
NEXT_JSON = { data = { gid = "1000" } }
HTTP_POSTS[1].cb(201, "{}")
check("autoComment = \"\" disables the comment (a profile can set this)",
      #SERVICE_CALLS == 0)
M.config.autoComment = "Sent by Hammerspoon Task Creator \"⌃⌥⌘T\", file init.lua"

ALERTS, HTTP_POSTS = {}, {}
_G.asanaSubmitTask("Doomed", "", "", "")
HTTP_POSTS[1].cb(500, "boom")
local doomed = _G.asanaTaskHistory[#_G.asanaTaskHistory]
check("an HTTP failure alerts and the history row says ❌, kept not dropped",
      alerted("❌ Error: 500") and doomed.displaySub:find("❌", 1, true) == 1)

out("\n=== C5. 🔐 The attachment upload keeps the token out of argv ===\n")

local attFile = TMP .. "/receipt.png"
f = assert(io.open(attFile, "w")); f:write("png-bytes"); f:close()

ALERTS, HTTP_POSTS, TASKS = {}, {}, {}
_G.asanaSubmitTask("With file", "", "", attFile)
NEXT_JSON = { data = { gid = "777" } }
HTTP_POSTS[1].cb(201, "{}")
local curl = TASKS[#TASKS]
check("a 201 with an attachment starts curl", curl and curl.started == true)
check("🚨 NO curl argument contains the token", (function()
    if not curl then return false end
    for _, a in ipairs(curl.args) do
        if tostring(a):find("SECRET", 1, true) then return false, a end
    end
    return true
end)())
local hdrPath
for i, a in ipairs(curl and curl.args or {}) do
    if a == "-H" then hdrPath = tostring(curl.args[i + 1]):match("^@(.+)$") end
end
check("the header arrives as -H @file instead", hdrPath ~= nil)
check("...and that file carries exactly the auth header", (function()
    local fh = hdrPath and io.open(hdrPath, "r"); if not fh then return false end
    local c = fh:read("*a"); fh:close()
    return c == "Authorization: Bearer SECRET-TOKEN-abc123\n"
end)())
check("...under ~/.hammerspoon/.tmp — local disk, never a synced folder",
      hdrPath ~= nil and hdrPath:find(TMP .. "/.tmp/hdr-", 1, true) == 1, hdrPath)
check("the upload is bounded (--max-time travels with it)", (function()
    for _, a in ipairs(curl and curl.args or {}) do
        if a == "--max-time" then return true end
    end
end)())

ALERTS = {}
curl.cb(0, "201", "")
check("a real 201 reports 📎 uploaded and stamps the history row",
      alerted("📎 Attachment uploaded")
      and _G.asanaTaskHistory[#_G.asanaTaskHistory].displaySub:find("📎 attached", 1, true) ~= nil)
check("...and the header file is already gone",
      io.open(hdrPath, "r") == nil)

HTTP_POSTS, TASKS = {}, {}
_G.asanaSubmitTask("Refused file", "", "", attFile)
NEXT_JSON = { data = { gid = "778" } }
HTTP_POSTS[1].cb(201, "{}")
curl = TASKS[#TASKS]
local hdr2
for i, a in ipairs(curl.args) do
    if a == "-H" then hdr2 = tostring(curl.args[i + 1]):match("^@(.+)$") end
end
ALERTS = {}
curl.cb(0, "401", "")
check("curl exit 0 with HTTP 401 is a FAILURE now, not a success",
      alerted("❌ Attachment upload failed")
      and _G.asanaTaskHistory[#_G.asanaTaskHistory].displaySub:find("⚠️ attach failed", 1, true) ~= nil)
check("...and the header file is gone on failure too",
      io.open(hdr2, "r") == nil)

ALERTS, HTTP_POSTS, TASKS = {}, {}, {}
_G.asanaSubmitTask("Ghost file", "", "", TMP .. "/nope.png")
NEXT_JSON = { data = { gid = "779" } }
HTTP_POSTS[1].cb(201, "{}")
check("a vanished attachment is one clear alert, no curl",
      alerted("⚠️ Attachment not found") and #TASKS == 0)

out("\n=== C6. Drafts, hotkeys, and the warm() sweep ===\n")

chooser.qcb("half-typed idea | still thinking")
check("every keystroke lands in _G.taskDraft",
      _G.taskDraft == "half-typed idea | still thinking")
ALERTS, POPUPS = {}, 0
_G.asanaOpenTaskChooser()
check("reopening restores the draft and says so",
      POPUPS == 1 and alerted("Draft restored")
      and chooser.queries[#chooser.queries] == "half-typed idea | still thinking")

_G.taskDraft = "A | B | sa | "
chooser.fn({ isAssigneeSuggestion = true, memberName = "Sarah Chen" })
check("picking a suggestion splices the name — it never submits",
      _G.taskDraft == "A | B | Sarah Chen | ", _G.taskDraft)

HTTP_POSTS = {}
chooser.fn({ isAction = true, rawTitle = "", rawDesc = "", rawAssignee = "", rawAttach = "" })
check("Enter on Create with an empty title keeps the draft",
      _G.taskDraft == "A | B | Sarah Chen | " and #HTTP_POSTS == 0)
chooser.fn({ isAction = true, rawTitle = "Ship it", rawDesc = "", rawAssignee = "", rawAttach = "" })
check("a successful submit clears the draft",
      _G.taskDraft == "" and #HTTP_POSTS == 1)

check("⌃⌥⌘T and ⌃⌥⌘A are bound (the §0.4 map turns them into ⇪T · ⇪A)",
      BOUND["ctrl+alt+cmd|T"] ~= nil and BOUND["cmd+ctrl+alt|A"] ~= nil)
check("⇪⇧S is registered through core.hyperAddShortcut",
      HYPER["shift|s"] ~= nil)

ASANA_OK = false
ALERTS, POPUPS = {}, 0
BOUND["ctrl+alt+cmd|T"]()
HYPER["shift|s"]()
check("no secret.lua: both keys explain instead of opening anything",
      POPUPS == 0 and #ALERTS == 2)
ASANA_OK = true

local FORM_CALLS = 0
_G.taskFormShow = function() FORM_CALLS = FORM_CALLS + 1 end
POPUPS = 0
BOUND["ctrl+alt+cmd|T"]()
check("⌃⌥⌘T prefers the labeled form when task_form loaded",
      FORM_CALLS == 1 and POPUPS == 0)
_G.taskFormShow = nil
BOUND["ctrl+alt+cmd|T"]()
check("...and falls back to the pipe chooser when it did not",
      POPUPS == 1)

PASTE = "https://app.asana.com/0/1200/1201234567890123"
HTTP_GETS, ALERTS, PASTE_SET = {}, {}, nil
BOUND["cmd+ctrl+alt|A"]()
check("⌃⌥⌘A asks the API about the task in the clipboard, token in a header",
      HTTP_GETS[1]
      and HTTP_GETS[1].headers["Authorization"] == "Bearer SECRET-TOKEN-abc123")
NEXT_JSON = { data = { name = "My Task" } }
HTTP_GETS[1].cb(200, "{}")
check("...and writes back 'Name | url'",
      PASTE_SET == "My Task | " .. PASTE and alerted("✅ Formatted"))
PASTE = "not an asana link"
ALERTS = {}
BOUND["cmd+ctrl+alt|A"]()
check("a non-Asana clipboard is one clear alert",
      alerted("does not contain an Asana URL"))

os.execute('mkdir -p "' .. TMP .. '/.tmp"')
f = assert(io.open(TMP .. "/.tmp/hdr-1-0001.txt", "w"))
f:write("Authorization: Bearer LEFTOVER\n"); f:close()
printed = {}
M.warm(core)
check("warm() sweeps header files a killed Hammerspoon left behind",
      io.open(TMP .. "/.tmp/hdr-1-0001.txt", "r") == nil)
check("...and says how many it cleared",
      printed[1] and printed[1]:find("leftover auth%-header"))

os.execute('rm -rf "' .. TMP .. '"')
out(("\n── test_task_creator: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
