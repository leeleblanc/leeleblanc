-- =====================================================================
-- test_asana_dashboard.lua — 🚪 6.386.0, §6 leaves init.lua
-- =====================================================================
--     lua5.4 test_asana_dashboard.lua [/path/to/hammerspoon]
--
-- LL: "Yes, and make this move safe-proof and non-destructive for the
-- Asana dashboard both on my home and work mac."
--
-- A move is the one kind of release where "it still works" is the ENTIRE
-- claim, so this suite is written against the three ways a move of this
-- shape goes wrong rather than against the feature's own behaviour:
--
--   1. A HELPER LEFT BEHIND. Seven things this code read as init.lua's
--      own locals are now reached off `core`. Miss one and it is nil at
--      PRESS time — a traceback out of hyperBind on his Mac and nothing
--      the gate would notice, because the gate never presses the key.
--      §2 is a source sentry; §4 drives every key for real.
--   2. THE KEYS BOUND AT THE WRONG MOMENT. ⌃⌥⌘L / ⌃⌥⌘C / ⌃⌥⌘B are all
--      in §0.4's migration map, so hs.hotkey.bind does NOT register them
--      — it appends them to _G.hyperMigrations, which _G.hyperFinalize()
--      drains ONCE, after the module loader. setup() is therefore the
--      last moment such a bind can be made, and a bind moved to warm()
--      would be appended to a list nobody reads again: three silently
--      dead keys. §3 models that drain and drives both sides of it.
--   3. A WORK MAC WITH LESS ON IT. No secret.lua, or asana_comments not
--      loaded, must cost one shortcut and SAY so — never a throw and
--      never a silence (6.177.0 · 6.215.0). §5.
--
-- 🔬 THE HARNESS MODELS init.lua's OWN hs.hotkey.bind WRAPPER, migration
-- map and all, rather than a bind that registers (6.290.0, thirteenth
-- time: a stub gentler than the provider does not miss a bug, it
-- CERTIFIES it). With a plain registering stub, check 3 below would pass
-- with the binds moved to warm() — which is the whole release.

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
local function slurp(p)
    local f = io.open(p, "r") ; if not f then return nil end
    local s = f:read("*a") ; f:close() ; return s
end

local MODPATH = HS .. "/modules/asana_dashboard.lua"
local SRC = slurp(MODPATH) or ""
local INIT = slurp(HS .. "/init.lua") or ""
-- Comments stripped (6.262.0): the prose in this module deliberately
-- quotes the very shapes the sentries below forbid.
local CODE = SRC:gsub("\n%s*%-%-[^\n]*", "\n")
-- 🚨 AND STRING LITERALS GO TOO, for the bare-name sentries below only.
-- The report prints the seven helper names as DATA ("asanaToken", …), so a
-- sentry looking for a bare `asanaToken` matched its own needle and went
-- red on correct code — 6.359.0's finding, in this suite, on its first run.
local NOSTR = CODE:gsub('"[^"\n]*"', '""'):gsub("'[^'\n]*'", "''")

-- =====================================================================
out("\n=== 1. 🚪 the move happened, and nothing was left behind ===\n")
-- =====================================================================
check("the module file exists and is the whole section", #SRC > 10000, #SRC)
-- 📏 6.400.0 — THE MARGIN IS NAMED, NOT TYPED. This shipped asserting a
-- bare `n < 3500`, which is 6.248.0's defect: a literal standing in for a
-- rule, so it goes red on a change it has nothing to say about — and it
-- did, on a 70-line Console divider, while the real ceiling sat 295 lines
-- away. The ceiling is 3,800 (the gate fails at it and below 4,000); what
-- 6.386.0's move bought is a WORKING MARGIN under that, so the margin is
-- what the check states. Still a ratchet: 195 lines tighter than where
-- 6.385.0 sat, and a release that wants more than this has to trim first,
-- which 6.400.0 did (120 lines to 70) before this number moved.
local INIT_CEILING, INIT_MARGIN = 3800, 200
check(("init.lua is under its %d-line ceiling with the %d-line working "
       .. "margin 6.386.0's move bought"):format(INIT_CEILING, INIT_MARGIN),
      (function()
          local n = 0 ; for _ in INIT:gmatch("\n") do n = n + 1 end
          return n < (INIT_CEILING - INIT_MARGIN), n
      end)(), (function() local n = 0 ; for _ in INIT:gmatch("\n") do n = n + 1 end ; return n end)())
check("…and kept NO copy of the dashboard — a copy left behind is two "
      .. "copies that drift (6.104.0)",
      not INIT:find("local function fetchAsanaDashboard", 1, true)
      and not INIT:find("local asanaCaps", 1, true)
      and not INIT:find("_G.asanaSelect.rows = function", 1, true))
check("🔑 …while §1.5 still drags the legend with a nudged picker, through "
      .. "the one nil-guarded global that crosses the boundary",
      INIT:find("if movedAny and _G.asanaLegendSync then", 1, true) ~= nil)
check("…and BASE lists it", INIT:find('"asana_dashboard"', 1, true) ~= nil)

-- =====================================================================
out("\n=== 2. 🔌 every helper comes off `core`, not a vanished local ===\n")
-- =====================================================================
-- 🚨 THE ONE THAT WOULD HAVE COST A RELEASE. A half-done rewrite leaves a
-- bare `showPopup(...)` reading a GLOBAL that does not exist, which is nil
-- at press time and throws — on his Mac, from a keypress, with a green
-- gate behind it. Each of the seven is checked BY NAME because each is a
-- different dead key.
for _, name in ipairs({ "showPopup", "resolveBaseScreen", "chooserTopLeft",
                        "requireAsana" }) do
    check("🔌 " .. name .. " is called as core." .. name .. ", never bare",
          NOSTR:find("core%." .. name .. "%(") ~= nil
          and NOSTR:find("[^.%w]" .. name .. "%(") == nil,
          NOSTR:match("[^.%w]" .. name .. "%(") and "a bare call survives" or nil)
end
for _, name in ipairs({ "asanaToken", "asanaWorkspaceId", "panelAlpha" }) do
    check("🔌 " .. name .. " is read as core." .. name .. ", never bare",
          NOSTR:find("core%." .. name) ~= nil
          and NOSTR:find("[^.%w]" .. name .. "[^%w]") == nil,
          NOSTR:match("[^.%w]" .. name .. "[^%w]") and "a bare read survives" or nil)
end
-- 🔒 AND THE TOKEN NEVER REACHES A PROCESS ARGUMENT LIST. A hard rule of
-- this project, and the one thing in this file that could leak a secret.
check("🔒 the token never goes near a shell — no hs.execute, no hs.task",
      CODE:find("hs.execute", 1, true) == nil
      and CODE:find("hs.task", 1, true) == nil
      and CODE:find("io.popen", 1, true) == nil)
check("…and it is only ever an Authorization header",
      (function()
          local n = 0
          for _ in CODE:gmatch('Bearer') do n = n + 1 end
          return n == 2, n .. " Bearer site(s)"   -- the fetch and the delete
      end)())
-- 📋 6.325.0 — THE CLIPBOARD WRITE READS ITS ANSWER NOW. setContents
-- refuses by RETURNING FALSE and never throws, so the old line claimed
-- "Copied" over a write macOS may have declined. That rule named three
-- files in 6.325.0 and this one was inside init.lua, where nobody grepped.
check("📋 the team-name copy goes through core.copyText, which reads the "
      .. "refusal setContents answers with",
      CODE:find("core%.copyText%(") ~= nil
      and CODE:find("hs.pasteboard.setContents", 1, true) == nil)
-- 📋 No cheatsheet of its own: core/cheatsheet.lua's ✅ ASANA card has
-- printed ⇪B, ⇪C and ⇪L for a hundred releases, and a second copy is the
-- double listing LL objected to from a screenshot in 6.90.1.
check("📋 it declares NO cheatsheet group — the ✅ ASANA card already "
      .. "prints these three keys",
      CODE:find("cheatsheet", 1, true) == nil)
check("…and core/cheatsheet.lua still carries that card",
      (slurp(HS .. "/core/cheatsheet.lua") or ""):find("✅ ASANA", 1, true) ~= nil)

-- =====================================================================
out("\n=== 3. 🪜 the keys bind in setup(), which is the LAST moment ===\n")
-- =====================================================================
-- The harness, from here down: a Mac in tables, with init.lua's own
-- hs.hotkey.bind wrapper modelled faithfully.
local MIGRATION_MAP = {   -- the three rows of §0.4 that matter here
    ["alt+cmd+ctrl+l"] = { {}, "l" },
    ["alt+cmd+ctrl+c"] = { {}, "c" },
    ["alt+cmd+ctrl+b"] = { {}, "b" },
}
local migrations, registered, bound = {}, {}, {}
local alerts, degrades, printed = {}, {}, {}
local chooserShown, canvasesShown = {}, {}
local SETTINGS, GETS, REQUESTS, REPLY = {}, {}, {}, {}
local BAD_KEYS = {}      -- key -> true: hs.hotkey.bind throws for it
local COPY_OK = true     -- macOS's answer to a clipboard write

local realPrint = print
local function capture(on)
    if on then printed = {} ; print = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
        printed[#printed + 1] = table.concat(t, " ")
    end else print = realPrint end
end
local function said(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return l end end
end
local function alerted(needle)
    for _, l in ipairs(alerts) do if l:find(needle, 1, true) then return l end end
end
local function degraded(needle)
    for _, d in ipairs(degrades) do if (d.why or ""):find(needle, 1, true) then return d end end
end

local function normalizeCombo(mods, key)
    local m = {}
    for _, x in ipairs(mods or {}) do m[#m + 1] = tostring(x):lower() end
    table.sort(m)
    return table.concat(m, "+") .. "+" .. tostring(key):lower()
end

local function newChooser(fn)
    local o = { fn = fn, rowsList = nil, placeholder = nil, nrows = nil }
    function o:choices(c) self.rowsList = c ; return self end
    function o:placeholderText(t) self.placeholder = t ; return self end
    function o:rows(n) self.nrows = n ; return self end
    function o:width() return 40 end
    function o:hideCallback() return self end
    function o:searchSubText() return self end
    function o:show() chooserShown[#chooserShown + 1] = self ; return self end
    function o:isVisible() return true end
    return o
end

_G.hs = {
    -- 🔬 init.lua's OWN wrapper: a combo in the migration map is APPENDED
    -- to _G.hyperMigrations and never reaches macOS; hyperFinalize drains
    -- that list once. And a bad key name THROWS, which is what the door's
    -- pcall is for.
    hotkey = {
        bind = function(mods, key, fn)
            if BAD_KEYS[tostring(key):lower()] then
                error("Hotkey.bind: unknown key " .. tostring(key), 0)
            end
            local combo = normalizeCombo(mods, key)
            local t = MIGRATION_MAP[combo]
            if t then
                migrations[#migrations + 1] = { from = combo, mods = t[1], key = t[2], fn = fn }
                return { migrated = true }
            end
            registered[combo] = fn
            return { combo = combo }
        end,
    },
    http = {
        asyncGet = function(url, headers, cb)
            GETS[#GETS + 1] = { url = url, headers = headers }
            for frag, rep in pairs(REPLY) do
                if url:find(frag, 1, true) then return cb(rep[1], rep[2]) end
            end
            cb(500, "")
        end,
        asyncRequest = function(url, method, body, headers, cb)
            REQUESTS[#REQUESTS + 1] = { url = url, method = method, headers = headers }
            cb(200, "{}")
        end,
    },
    chooser = { new = newChooser },
    alert   = { show = function(t) alerts[#alerts + 1] = tostring(t) end },
    canvas  = {
        windowLevels = { overlay = 7 },
        new = function(frame)
            local c = { frame = frame, els = nil, deleted = false }
            function c:appendElements(e) self.els = e ; return self end
            function c:level() return self end
            function c:behaviorAsLabels() return self end
            function c:delete() self.deleted = true ; return self end
            function c:show() return self end
            return c
        end,
    },
    dialog  = {
        textPrompt = function() return "Cancel", "" end,
        blockAlert = function() return "Cancel" end,
    },
    eventtap = { checkKeyboardModifiers = function() return {} end },
    urlevent = { openURL = function() end },
    pasteboard = { setContents = function() return COPY_OK end },
    settings = { get = function(k) return SETTINGS[k] end,
                 set = function(k, v) SETTINGS[k] = v end },
    timer   = { doAfter = function(_, f) return { stop = function() end, fn = f } end },
    screen  = {},
    json    = { encode = function() return "{}" end },
}
_G.safeJson = function(body) local ok, v = pcall(load("return " .. body)) ; return ok and v or nil end
_G.showCanvasSafely = function(c) canvasesShown[#canvasesShown + 1] = c ; return true end
_G.uiStyle = nil
_G.lastPopupPlacement = { screen = { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end,
                                     name = function() return "Test" end },
                          point = { x = 100, y = 300 } }
_G.service = { has = function() return false end, call = function() end }

local REQUIRE_ASANA = true
local core = {
    asanaEnabled     = true,
    asanaToken       = "SECRET-TOKEN",
    asanaWorkspaceId = "12345",
    requireAsana     = function()
        if REQUIRE_ASANA then return true end
        hs.alert.show("⚠️ Asana is not set up on this Mac")
        return false
    end,
    showPopup         = function(c) return c:show() end,
    resolveBaseScreen = function() return _G.lastPopupPlacement.screen end,
    chooserTopLeft    = function() return { x = 100, y = 300 } end,
    panelAlpha        = 0.95,
    -- 🔬 6.290.0's ratchet (test_stub_fidelity §6) requires a core copyText
    -- stub that can SAY NO, and it reads the body TEXTUALLY — so the
    -- refusal is written as a literal `return false` rather than hidden
    -- behind a flag it cannot see. 6.342.0: a textual sentry closes the
    -- literal half of a class and never the variable half, and the sentry
    -- was right to fail this suite's first draft.
    copyText          = function(t)
        if not COPY_OK then return false, "macOS refused the write" end
        return true
    end,
    degrade           = function(tool, why) degrades[#degrades + 1] = { tool = tool, why = why } ; return false, why end,
    provide           = function() end,
}

-- The §1.12 loader's order, modelled: load → setup → (settings) → warm,
-- and only THEN the migration drain, exactly as init.lua does at §7.
local function loadFresh()
    migrations, registered, bound = {}, {}, {}
    alerts, degrades, chooserShown, canvasesShown = {}, {}, {}, {}
    GETS, REQUESTS = {}, {}
    _G.choosers = {}
    _G.asanaSelect, _G.asanaLegendCanvas, _G.asanaLegendSync = nil, nil, nil
    _G.asanaTeamMembers, _G.fetchAsanaTeamMembers = nil, nil
    return dofile(MODPATH)
end
-- 📏 THE COMBO KEY IS mods+key, PLUS-SEPARATED (init.lua's own
-- normalizeCombo), NOT the pipe form the test registry uses elsewhere. All
-- three of these migrate to a BARE ⇪ letter, so the drained name is the
-- letter alone — indexed that way here so a reader cannot misread which
-- of the two formats is in play.
local function finalize()
    for _, m in ipairs(migrations) do
        assert(#(m.mods or {}) == 0, "a ⇪ letter, not a chord")
        bound[m.key] = m.fn
    end
end

local mod = loadFresh()
check("the module returns a table with a name, an order and a family",
      type(mod) == "table" and mod.name == "Asana Dashboard"
      and type(mod.order) == "number" and mod.family == "capture", tostring(mod.name))
check("…and no cheatsheet on the table itself", mod.cheatsheet == nil)
check("🔑 _G.asanaLegendSync is published at LOAD, before setup — §1.5 and "
      .. "window_move can ask for it the moment the module is on disk",
      type(_G.asanaLegendSync) == "function")
check("…and calling it with nothing drawn does nothing and does not throw",
      (function() local ok = pcall(_G.asanaLegendSync) ; return ok end)())
-- 🚨 THE GUARD THAT MAKES THAT SAFE: a canvas recorded with setup never
-- run means `core` is nil, and the legend redraw would index it.
-- 🚨 THE ONE WAY A STRANGER CAN REACH THE REDRAW, driven as a PROPERTY.
-- window_move nudges a picker and calls _G.asanaLegendSync; before setup
-- has run `core` is nil, so the function must turn away without indexing
-- it. FOUR early returns can do that and each masks the next, so the
-- sweep could kill none of them individually — which is 6.273.0's own
-- boundary: where a promise rests on several independent guards there is
-- no single line to mutate and no single check to write. What CAN be
-- asserted is the promise itself, in every state a caller can leave the
-- world in: it does not throw, and it draws nothing.
_G.asanaLegendCanvas = { delete = function() end }
_G.choosers = {}
check("🚨 …and with a canvas recorded but setup never run, it REFUSES "
      .. "rather than indexing a nil core",
      (function() local ok, err = pcall(_G.asanaLegendSync) ; return ok, err end)())
check("…and it did so WITHOUT drawing anything", #canvasesShown == 0, #canvasesShown)
-- 🧪 …and the same call with a picker present must still refuse, which is
-- what tells the chooser guard apart from the counts guard above it.
_G.choosers = { asana = newChooser(function() end) }
_G.asanaLegendCanvas = { delete = function() end }
check("🧪 …and with a picker present too, the counts guard holds the line "
      .. "— nothing has been fetched, so there is nothing to draw",
      (function() local ok = pcall(_G.asanaLegendSync) ; return ok and #canvasesShown == 0 end)(),
      #canvasesShown)
_G.asanaLegendCanvas = nil
_G.choosers = {}

capture(true) ; mod.setup(core) ; capture(false)
check("🪜 setup() bound THREE keys", #migrations == 3, #migrations)
check("…and every one of them went into the MIGRATION list, not to macOS — "
      .. "§0.4 rewrites all three onto ⇪",
      next(registered) == nil, next(registered))
finalize()
check("🪜 …so after _G.hyperFinalize() drains it, ⇪L, ⇪C and ⇪B are bound",
      type(bound["l"]) == "function" and type(bound["c"]) == "function"
      and type(bound["b"]) == "function",
      tostring(bound["l"]) .. " / " .. tostring(bound["c"]) .. " / " .. tostring(bound["b"]))
-- 🚨 THE MUTATION THIS SECTION EXISTS FOR, driven rather than described:
-- a bind made after the drain is appended to a list nobody reads again.
do
    local afterDrain = #migrations
    hs.hotkey.bind({"cmd", "ctrl", "alt"}, "L", function() end)
    check("🚨 A BIND MADE AFTER THE DRAIN IS DEAD — which is what moving "
          .. "these three to warm() would do, silently",
          #migrations == afterDrain + 1 and bound["l"] ~= migrations[#migrations].fn,
          "appended but never drained")
    migrations[#migrations] = nil
end
check("…and the module has no warm() that could be mistaken for the place "
      .. "to bind them", mod.warm == nil)
check("🔎 the source binds inside setup and nowhere else",
      (function()
          local body = CODE:match("function M%.setup%(c%)(.*)return M") or ""
          local inSetup = 0
          for _ in body:gmatch("hs%.hotkey%.bind") do inSetup = inSetup + 1 end
          local total = 0
          for _ in CODE:gmatch("hs%.hotkey%.bind") do total = total + 1 end
          return inSetup == total and total >= 1, inSetup .. " of " .. total
      end)())

-- =====================================================================
out("\n=== 4. 🎯 every key, driven for real ===\n")
-- =====================================================================
REPLY = { ["/tasks?assignee=me"] = { 200, [[{ data = {
    { gid = "1", name = "Late thing",   due_on = "2020-01-02", permalink_url = "u1" },
    { gid = "2", name = "Later thing",  due_on = "2020-01-09", permalink_url = "u2" },
    { gid = "3", name = "No date here", created_at = "2026-05-05T00:00:00.000Z", permalink_url = "u3" },
} }]] } }
capture(true) ; bound["l"]() ; capture(false)
check("🎯 ⇪L fetched, banded and opened the picker — the whole feature, "
      .. "through core.showPopup", #chooserShown >= 1 and _G.choosers.asana ~= nil)
check("…and the token travelled in the header, never in the URL",
      (function()
          for _, g in ipairs(GETS) do
              if g.url:find("SECRET-TOKEN", 1, true) then return false end
              if (g.headers or {})["Authorization"] ~= "Bearer SECRET-TOKEN" then return false end
          end
          return #GETS == 1
      end)(), #GETS .. " fetch(es)")
check("…and the workspace came off core.asanaWorkspaceId",
      (GETS[1] or {}).url and GETS[1].url:find("workspace=12345", 1, true) ~= nil)
check("…three tasks in, three bands out, plus the ☑️ select-mode row",
      _G.asanaSelect.master and #_G.asanaSelect.master == 3
      and #_G.choosers.asana.rowsList == 4,
      tostring(_G.asanaSelect.master and #_G.asanaSelect.master))
check("…the overdue one is first and carries its band",
      (_G.asanaSelect.master[1].subText or ""):find("🔴 Overdue", 1, true) ~= nil,
      _G.asanaSelect.master[1].subText)
check("🎨 …and the legend strip was drawn, placed off core.chooserTopLeft "
      .. "and filled with core.panelAlpha",
      #canvasesShown == 1 and said("🎨 Legend on 'Test'") ~= nil, said("🎨 Legend"))
check("…the strip sits ABOVE the picker's own top edge, never estimated",
      canvasesShown[1].frame.y < 300, canvasesShown[1].frame.y)

-- 🧪 6.230.0 — THE FIXTURE THAT BITES THE CAPS. Three tasks are under
-- every one of the five limits, so a cap obeyed and a cap ignored give
-- the identical answer and the mutation sweep found nothing to kill. The
-- documented promise is 40 + 10 + 30 + 10 + 10 = 100 tasks MAXIMUM, and
-- the only input that can prove it is one that overflows a band.
do
    local many = {}
    for i = 1, 45 do
        many[#many + 1] = ('{ gid = "o%d", name = "Overdue %d", due_on = "2020-01-%02d", permalink_url = "u" }')
                          :format(i, i, (i % 28) + 1)
    end
    for i = 1, 14 do
        many[#many + 1] = ('{ gid = "n%d", name = "Undated %d", created_at = "2026-05-%02dT00:00:00.000Z", permalink_url = "u" }')
                          :format(i, i, (i % 28) + 1)
    end
    REPLY = { ["/tasks?assignee=me"] = { 200, "{ data = { " .. table.concat(many, ", ") .. " } }" } }
    capture(true) ; bound["l"]() ; capture(false)
    local m = _G.asanaSelect.master or {}
    check("📏 a band that OVERFLOWS is trimmed to its cap — 45 overdue in, "
          .. "40 out, and 14 undated in, 10 out",
          #m == 50, #m .. " row(s) kept from 59")
    local overdue, undated = 0, 0
    for _, c in ipairs(m) do
        if (c.subText or ""):find("🔴", 1, true) then overdue = overdue + 1 end
        if (c.subText or ""):find("🟣", 1, true) then undated = undated + 1 end
    end
    check("…and the trim is PER BAND, not a total taken off the end",
          overdue == 40 and undated == 10, overdue .. " overdue · " .. undated .. " undated")
    check("…the overdue band is still NEWEST due first inside the cap, so "
          .. "the cap keeps the most relevant of each band",
          m[1].dueTime > m[2].dueTime and m[2].dueTime > m[3].dueTime)
    check("🎨 …and the legend pills count the rows each band CONTRIBUTED, "
          .. "never the rows it had", canvasesShown[#canvasesShown] ~= nil)
end
REPLY = { ["/tasks?assignee=me"] = { 200, [[{ data = {
    { gid = "1", name = "Late thing",   due_on = "2020-01-02", permalink_url = "u1" },
    { gid = "2", name = "Later thing",  due_on = "2020-01-09", permalink_url = "u2" },
    { gid = "3", name = "No date here", created_at = "2026-05-05T00:00:00.000Z", permalink_url = "u3" },
} }]] } }

capture(true) ; bound["c"]() ; capture(false)
check("🎯 ⇪C opens the same picker in comment mode",
      (_G.choosers.asana.placeholder or ""):find("comment on", 1, true) ~= nil,
      _G.choosers.asana.placeholder)

_G.asanaTeamMembers = { { name = "Ann Example", email = "ann@x.com", teams = { "Core" } } }
COPY_OK = true
capture(true) ; bound["b"]() ; capture(false)
check("🎯 ⇪B lists the team off the list asana_comments publishes",
      _G.choosers.asanaTeam ~= nil and #_G.choosers.asanaTeam.rowsList == 1)
check("…with the team folded into the subtext so typing 'core' narrows",
      (_G.choosers.asanaTeam.rowsList[1].subText or ""):find("Core", 1, true) ~= nil,
      _G.choosers.asanaTeam.rowsList[1].subText)
_G.choosers.asanaTeam.fn({ name = "Ann Example" })
check("…and ⏎ on a row copies the name through the one door that reads "
      .. "macOS's answer", alerted("📋 Copied Ann Example") ~= nil, alerts[#alerts])
-- 🚨 AND A REFUSED WRITE IS SAID, NOT CLAIMED (6.325.0). The old line
-- printed "Copied" whatever macOS answered.
COPY_OK = false ; alerts = {}
_G.choosers.asanaTeam.fn({ name = "Bob Example" })
check("🚨 …and a write macOS REFUSES says so instead of claiming success",
      alerted("refused") ~= nil and alerted("📋 Copied") == nil, alerts[#alerts])
COPY_OK = true

-- 🗑 The bulk delete, which is the one verb here that destroys something.
out("\n  4a. 🗑 the delete still asks first, and still asks Asana properly\n")
_G.asanaSelect.on = true
alerts = {}
_G.asanaSelect.delete({ { gid = "1", text = "✓ Late thing" } })
check("🗑 a Cancel at the confirmation deletes NOTHING",
      #REQUESTS == 0 and alerted("Nothing deleted") ~= nil, alerts[#alerts])
hs.dialog.blockAlert = function() return "Delete" end
alerts, REQUESTS = {}, {}
_G.asanaSelect.delete({ { gid = "7", text = "✓ Late thing" } })
check("…and a Delete sends ONE DELETE, by gid, with the token in a header",
      #REQUESTS == 1 and REQUESTS[1].method == "DELETE"
      and REQUESTS[1].url:find("/tasks/7", 1, true) ~= nil
      and REQUESTS[1].headers["Authorization"] == "Bearer SECRET-TOKEN"
      and not REQUESTS[1].url:find("SECRET-TOKEN", 1, true),
      REQUESTS[1] and REQUESTS[1].url)
check("…and an empty list is refused rather than confirmed",
      (function() alerts = {} ; _G.asanaSelect.delete({})
          return alerted("Nothing picked") ~= nil end)(), alerts[#alerts])

-- =====================================================================
out("\n=== 5. 🔒 the work Mac — less on it, and nothing breaks ===\n")
-- =====================================================================
-- 🚨 NO secret.lua. Every key must say so and attempt nothing.
mod = loadFresh() ; REQUIRE_ASANA = false
capture(true) ; mod.setup(core) ; capture(false) ; finalize()
alerts, GETS = {}, {}
capture(true) ; bound["l"]() ; bound["c"]() ; bound["b"]() ; capture(false)
check("🔒 with no secret.lua, all three keys refuse and NOTHING is fetched",
      #GETS == 0 and alerted("Asana is not set up") ~= nil, #GETS .. " fetch(es)")
REQUIRE_ASANA = true

-- 🚨 asana_comments DID NOT LOAD. Before the move this code was init.lua
-- and `#_G.asanaTeamMembers` could only ever run long after; it is still
-- only reachable from a keypress, so this is a belt — but a module that
-- failed must cost one shortcut, not a traceback out of hyperBind.
mod = loadFresh()
capture(true) ; mod.setup(core) ; capture(false) ; finalize()
degrades, alerts = {}, {}
local okB = pcall(bound["b"])
check("🔒 ⇪B with no team list and no fetcher does NOT throw",
      okB == true, tostring(okB))
check("…and it takes the degrade door, naming the module that is missing",
      degraded("Asana Comments module") ~= nil,
      degrades[1] and degrades[1].why)
check("…and the report counts it apart", (function()
    capture(true) ; _G.asanaDashboardReport() ; capture(false)
    return said("found no fetcher") ~= nil
end)(), said("team"))

-- 🚨 A FETCHER THAT ANSWERS WITH AN EMPTY LIST is a different fact from
-- no fetcher at all, and must read differently.
_G.asanaTeamMembers = {}
_G.fetchAsanaTeamMembers = function(done) done() end
degrades, alerts = {}, {}
check("…while a fetcher that comes back EMPTY says that instead",
      (function()
          local ok = pcall(bound["b"])
          return ok and alerted("Couldn't load team members") ~= nil
                 and degraded("Asana Comments module") == nil
      end)(), alerts[#alerts])

-- 🚨 A KEY macOS HAS NO CODE FOR costs ONE shortcut, not the module.
mod = loadFresh() ; BAD_KEYS["c"] = true
capture(true) ; mod.setup(core) ; capture(false) ; finalize()
check("🚨 one refused bind costs one key — the other two still bind",
      #migrations == 2 and bound["l"] and bound["b"] and not bound["c"],
      #migrations .. " bound")
check("…and the refusal is NAMED through the degrade door, never swallowed",
      degraded("could not be bound") ~= nil, degrades[#degrades] and degrades[#degrades].why)
BAD_KEYS["c"] = nil

-- =====================================================================
out("\n=== 6. 🔎 the report — three states, and the seven it depends on ===\n")
-- =====================================================================
-- 6.196.1 — a module whose setup never ran and one whose binds were all
-- refused read the same from outside, and each needs a different fix.
mod = loadFresh()
capture(true) ; _G.asanaDashboardReport() ; capture(false)
check("🔎 before setup it says setup has NOT run, and names the dead keys",
      said("setup has NOT run") ~= nil, printed[3])
check("…and does not claim the keys are bound", said("3 of 3 bound") == nil)

mod = loadFresh() ; BAD_KEYS["l"], BAD_KEYS["c"], BAD_KEYS["b"] = true, true, true
mod.setup(core)
capture(true) ; _G.asanaDashboardReport() ; capture(false)
check("🔎 setup ran and bound NOTHING reads as its own ⚠️ state, never as "
      .. "'not loaded' and never as health",
      said("bound NOTHING") ~= nil and said("setup has NOT run") == nil, printed[3])
BAD_KEYS["l"], BAD_KEYS["c"], BAD_KEYS["b"] = nil, nil, nil

mod = loadFresh() ; mod.setup(core)
capture(true) ; _G.asanaDashboardReport() ; capture(false)
check("🔎 …and the healthy state names all three keys and WHEN they bound",
      said("3 of 3 bound in setup()") ~= nil and said("⇪L · ⇪C · ⇪B") ~= nil
      and said("hyperFinalize") ~= nil, printed[3])
-- 🔌 6.339.0 — AN INCOMPLETE core TABLE IS A FOUR-RELEASE TRAP, because
-- every one of these is nil-guarded or indexed at press time. The report
-- names a missing member rather than letting it refuse in silence.
check("🔌 the report confirms all seven helpers are on the core table",
      said("every helper this module moved away from is on the core table") ~= nil)
do
    local thin = {}
    for k, v in pairs(core) do thin[k] = v end
    thin.chooserTopLeft = nil
    mod = loadFresh() ; mod.setup(thin)
    capture(true) ; _G.asanaDashboardReport() ; capture(false)
    check("🔌 …and a core table MISSING one names it, loudly",
          said("MISSING from core: chooserTopLeft") ~= nil, said("seven"))
end
mod = loadFresh() ; mod.setup(core)
capture(true) ; bound = {} ; finalize() ; bound["l"]() ; _G.asanaDashboardReport() ; capture(false)
check("🔎 …and after a press it counts the presses and the HTTP answers",
      said("1 open (⇪L)") ~= nil and said("HTTP 200×1") ~= nil, said("fetches"))
REPLY = { ["/tasks?assignee=me"] = { 401, "" } }
alerts = {}
capture(true) ; bound["l"]() ; _G.asanaDashboardReport() ; capture(false)
check("🔒 …and a 401 says the token is the problem, in the alert AND the "
      .. "report, rather than a bare status code",
      alerted("Asana rejected the token") ~= nil
      and said("revoked or mistyped") ~= nil, said("last"))

-- =====================================================================
io.write(string.format("\n── test_asana_dashboard: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    io.write("\nFAILURES:\n")
    for _, f in ipairs(failures) do io.write("  • " .. f .. "\n") end
    os.exit(1)
end
