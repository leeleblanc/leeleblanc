-- =====================================================================
-- MODULE: SELF TEST (_G.selfTest) — do the big tools answer?
-- =====================================================================
-- LL, 2026-11-06: "After Hammerspoon runs the first time, can it do a
-- set of checks for most important functions? Screenshot tool, snippets
-- tool, autocorrect, draft keeper, right-click."
--
--        _G.selfTest()    the block, on demand
--        at boot          printed ONCE, a few seconds in
--
-- ---- 🔑 WHY IT IS NOT install_check -------------------------------------
-- 6.399.0 already answers "did the whole release land?" — one stat per
-- runtime file against MANIFEST.txt. That is a question about BYTES ON
-- DISK, and every file can be present and correct while the thing he
-- pressed does nothing: a tap macOS refused, a dictionary that did not
-- load, a folder OneDrive took away. Joining the two would make one
-- report that answers two questions and cannot say which half failed.
-- Two instruments, two questions, and each says which it is.
--
-- ---- 🔎 EVERY ROW IS READ, NEVER RETYPED ---------------------------------
-- A check that asserts what a tool SAYS about itself can never notice
-- those words going false (6.276.0), so every row here asks the live
-- thing: the tap object, the loaded table, the registry, a stat. The
-- one thing it must never do is DO the thing — no screenshot is taken,
-- no snippet is typed, nothing is written. A self-test that acts is a
-- self-test that can break the Mac it is reassuring you about.
--
-- ---- 🔎 FOUR STATES, NOT TWO (6.196.1) ----------------------------------
--      ✅  it answered, and the answer is healthy
--      ⚠️  it answered, and the answer is a fault — with what to do
--      ⏳  not yet — warm has not run, or nothing has used it this boot
--      ❔  the CHECK ITSELF failed (it raised, or the thing it asks for
--          is not there at all). Never a pass: "I could not ask" and
--          "it is fine" are opposite facts, and this is the module
--          where printing the reassuring one would be worst.
--
-- ---- 📣 IT SPEAKS ON A HEALTHY MAC, DELIBERATELY -------------------------
-- 6.269.0's rule is that a new instrument should be silent when nothing
-- is wrong. This one breaks it ON PURPOSE and on his own words — he
-- asked for a set of checks AFTER THE FIRST RUN, and the value of the
-- block is knowing the tools DID answer on the three hundred mornings
-- before the one when they do not. `settings = { self_test =
-- { sayBoot = false } }` makes it quiet and leaves _G.selfTest().
-- =====================================================================

local M = {
    name  = "Self Test",
    order = 99.6,              -- after everything it asks about
    family = "config",
    cheatsheet = {
        title = "🩺 SELF TEST (_G.selfTest — do the big tools answer?)",
        entries = {
            { "run it",   "_G.selfTest() — one row per tool, in the Console" },
            { "at boot",  "The same block prints once, a few seconds in" },
            { "checks",   "Screenshots · snippets · autocorrect · draft keeper ·" },
            { "",         "right-click · the ⇪ key itself · Accessibility" },
            { "reads",    "The live tool, never what the tool says about itself" },
            { "never",    "Takes a screenshot, types a snippet or writes a file" },
            { "quiet",    "settings = { self_test = { sayBoot = false } }" },
            { "vs 🩺",    "install check is the OTHER question — are the FILES here" },
        },
    },
}

function M.setup(core)
    local st = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    st.enabled  = true
    st.sayBoot  = true        -- print the block once per boot
    st.sayAfter = 9           -- seconds after warm (install_check is at 6)
    -- ----------------------------------------------------------------------

    st.runs      = 0
    st.lastAt    = nil
    st.lastRows  = nil
    st.bootTimer = nil        -- HELD (6.196.1)
    st.noBelt    = 0
    st.saidBoot  = false

    -- ---- PURE: the verdict for one row ----------------------------------
    -- A check hands back (state, detail). This turns a RAISE into ❔
    -- rather than letting it take the whole block down — an instrument
    -- that can raise is worse than one that lies (6.282.0).
    function st.ask(name, fn)
        local ok, state, detail = pcall(fn)
        if not ok then
            return { name = name, state = "❔",
                     detail = "the check itself failed: " .. tostring(state) }
        end
        if state ~= "✅" and state ~= "⚠️" and state ~= "⏳" and state ~= "❔" then
            return { name = name, state = "❔",
                     detail = "the check answered something that is not a state" }
        end
        return { name = name, state = state, detail = tostring(detail or "") }
    end

    -- ---- PURE: is a tap alive? ------------------------------------------
    -- 🚨 AN EVENTTAP THAT EXISTS IS NOT AN EVENTTAP THAT IS RUNNING.
    -- macOS switches taps off across some transitions and tells nobody
    -- (6.303.0), so the object being there is the reassuring half and
    -- isEnabled() is the half that matters.
    function st.tapState(tap)
        if tap == nil then return "⚠️", "not created — nothing is watching the keyboard" end
        local ok, on = pcall(function() return tap:isEnabled() end)
        if not ok then return "❔", "the tap would not say whether it is running" end
        if on == true then return "✅", "running" end
        return "⚠️", "created and NOT running — macOS switched it off"
    end

    -- ---- the rows --------------------------------------------------------
    -- Order is his: the cross-cutting ones first, because every tool
    -- below them is dead when Accessibility is off and no row under it
    -- would explain why.
    function st.rows()
        local R = {}
        local function add(name, fn) R[#R + 1] = st.ask(name, fn) end

        add("Accessibility", function()
            local ok, granted = pcall(hs.accessibilityState)
            if not ok then return "❔", "macOS would not answer" end
            if granted == true then return "✅", "granted" end
            return "⚠️", "OFF — no tap and no click can work. System Settings "
                         .. "→ Privacy & Security → Accessibility, then QUIT "
                         .. "and relaunch Hammerspoon (a grant is read at launch)"
        end)

        add("Secure Input", function()
            local ok, on = pcall(hs.eventtap.isSecureInputEnabled)
            if not ok then return "❔", "macOS would not answer" end
            if on ~= true then return "✅", "clear" end
            return "⚠️", "HELD by something — every shortcut and every tap on "
                         .. "this Mac is dead while it is. _G.secureInputReport()"
        end)

        -- 📏 6.416.0 — THE SAME NUMBER THE BOOT LINE PRINTS. This row read
        -- `_G.hyperBoundCount`, which counts EVERY combo claimed, while the
        -- boot line prints `_G.hyperShortcutCount` — the same total less the
        -- forwarded chords, because init.lua says in capitals that FORWARDED
        -- KEYS ARE NOT SHORTCUTS. So the block read "119 bound" eight lines
        -- under "111 ⇪ shortcuts", about one fact, every morning (LL's
        -- 2026-11-06 boot). 6.231.0: one renderer, two readers — a second
        -- number for an idea already rendered is a number that contradicts
        -- it. The fallback is the raw count, for a build that predates the
        -- published figure, and it SAYS which it used.
        add("⇪ shortcuts", function()
            local n    = tonumber(_G.hyperShortcutCount)
            local raw  = tonumber(_G.hyperBoundCount)
            local note = ""
            if not n then n, note = raw, " (every bind, forwarded keys included)" end
            if not n then return "❔", "the key registry has not been published" end
            if n <= 0 then return "⚠️", "NOTHING is bound to ⇪" end
            local c = tonumber(_G.hyperConflictCount) or 0
            if c > 0 then
                return "⚠️", n .. " bound, but " .. c .. " key(s) are claimed twice"
            end
            return "✅", n .. " bound, no key claimed twice" .. note
        end)

        add("Screenshots", function()
            local shots = _G.screenshots
            if type(shots) ~= "table" then return "❔", "the module did not load" end
            local dir = shots.dir
            if type(dir) ~= "string" or dir == "" then
                return "⚠️", "no folder is set"
            end
            local okA, a = pcall(function() return hs.fs.attributes(dir, "mode") end)
            if not okA then return "❔", "the folder could not be asked about" end
            if a ~= "directory" then
                return "⚠️", "the folder is NOT there — ⇪4 has nowhere to write: " .. dir
            end
            return "✅", "⇪4's folder is there — " .. dir
        end)

        -- 🚨 6.416.0 — THIS ROW ASKED A GLOBAL NOTHING PUBLISHES, AND SAID
        -- "NO snippets are loaded" ON EVERY MAC, FOR EVER (LL's 2026-11-06
        -- boot, over a library of nineteen hundred). It read `_G.expander`,
        -- which text_expander.lua has never set — it publishes expanderTap,
        -- expanderTimers, expanderResetBuffer and expanderWatchdog and
        -- nothing else. 6.339.0's shape: nil, nil-guarded, so the refusal
        -- was correct-looking code giving a correct-sounding reason.
        -- 🔬 AND THE GATE CERTIFIED IT: tests/test_self_test.lua assigned
        -- `_G.expander` itself, so the suite was green about a row that
        -- could not be green on a Mac (6.273.0). It asks the SERVICE now,
        -- which is the surface every other module reaches through and the
        -- one a check can drive honestly.
        -- 📏 AND IT NAMES THE RIGHT DOOR. The old row sent him to
        -- _G.snippetsImport(), which finds .alfredsnippets files — there is
        -- nothing to import when the library is already loaded. The command
        -- that answers "what is in there?" is _G.snippetsReport().
        add("Snippets", function()
            local s, d  = st.tapState(_G.expanderTap)
            local asked = _G.service and _G.service.has
                          and _G.service.has("expander.state")
            if not asked then
                return "❔", "the snippets module did not load — nothing to ask"
            end
            local ok, got = pcall(function()
                return _G.service.call("expander.state")
            end)
            if not ok or type(got) ~= "table" then
                return "❔", "the snippets module would not say — _G.snippetsReport()"
            end
            local n = tonumber(got.count) or 0
            if n == 0 then
                return "⚠️", "NO snippets are loaded — _G.snippetsReport() says why"
            end
            if not got.enabled then
                return "⏳", n .. " loaded · expansion is switched OFF"
            end
            if s ~= "✅" then return s, n .. " loaded, but the tap is " .. d end
            return "✅", n .. " loaded · the tap is running · _G.snippetsReport()"
        end)

        add("Autocorrect", function()
            local s, d = st.tapState(_G.autocorrectTap)
            if s ~= "✅" then return s, "the tap is " .. d end
            return "✅", "the tap is running · _G.autocorrectReport() for the rules"
        end)

        add("Draft keeper", function()
            local dk = _G.draftKeeper
            if type(dk) ~= "table" then return "❔", "the module did not load" end
            if not dk.enabled then
                return "⏳", "switched off — settings = { draft_keeper = "
                             .. "{ enabled = true } }"
            end
            if not dk.timer then
                return "⚠️", "ON and no timer is armed — _G.draftKeeper.start()"
            end
            return "✅", ("watching every %ds while one of %d app(s) is in "
                          .. "front · _G.draftCheck() asks about the field "
                          .. "the caret is in")
                         :format(dk.everySecs or dk.sampleSecs or 0, #dk.apps)
        end)

        add("Right-click", function()
            local rc = _G.rightClick
            if type(rc) ~= "table" then return "❔", "the module did not load" end
            if not rc.enabled then return "⏳", "switched off" end
            local ok, granted = pcall(hs.accessibilityState)
            if not (ok and granted == true) then
                return "⚠️", "bound, but Accessibility is off so no click can be posted"
            end
            return "✅", "⇪⇧F is bound" ..
                   (rc.useSelection and " · it aims at what the front app has selected"
                                     or " · it clicks where the pointer is")
        end)

        return R
    end

    -- ---- PURE: the block, from the rows ---------------------------------
    -- ONE RENDERER, TWO READERS (6.231.0): the boot line and _G.selfTest()
    -- print the same thing, so they cannot disagree about a verdict.
    function st.render(rows)
        local L = { "🩺 SELF TEST — do the big tools answer?" }
        local bad, unknown, waiting = 0, 0, 0
        for _, r in ipairs(rows) do
            if r.state == "⚠️" then bad = bad + 1
            elseif r.state == "❔" then unknown = unknown + 1
            elseif r.state == "⏳" then waiting = waiting + 1 end
            L[#L + 1] = ("   %s %-14s %s"):format(r.state, r.name, r.detail)
        end
        if bad == 0 and unknown == 0 then
            L[#L + 1] = "   ✅ every tool answered" ..
                        (waiting > 0 and (" · " .. waiting .. " switched off on purpose")
                                      or "")
        else
            L[#L + 1] = ("   ⚠️ %d fault(s)%s — the ⚠️ rows above say what to do")
                        :format(bad, unknown > 0
                                     and (" · " .. unknown .. " could not be asked")
                                     or "")
        end
        L[#L + 1] = "   ↳ _G.selfTest() runs it again · _G.installCheck() is the "
                    .. "OTHER question (are the files here)"
        return table.concat(L, "\n"), bad, unknown
    end

    function _G.selfTest(asText)
        local rows = st.rows()
        st.runs   = st.runs + 1
        st.lastAt = os.time()
        st.lastRows = rows
        local s = st.render(rows)
        if asText then return s end
        print(s)
    end

    if core.provide then
        core.provide("selfTest.rows", function() return st.rows() end)
    end

    _G.selfTestState = st
    M.st     = st
    M.config = st
end

-- ⏱ FROM warm, NEVER setup (6.267.0): every tool it asks about is
-- started in ITS warm, so a check during setup would report half of
-- them as not running and be a liar on a healthy Mac.
M.warm = function()
    local st = _G.selfTestState
    if not (st and st.enabled and st.sayBoot) then return end
    local function speak()
        st.bootTimer = nil
        st.saidBoot = true
        pcall(_G.selfTest)
    end
    local okT, t = pcall(hs.timer.doAfter, st.sayAfter or 9, speak)
    st.bootTimer = okT and t or nil        -- HELD (6.196.1)
    if not okT then
        -- A Mac that cannot arm a timer still gets the block; it is
        -- simply early, and early is better than silent in the module
        -- whose subject is being told.
        st.noBelt = (st.noBelt or 0) + 1
        pcall(speak)
    end
end

return M
