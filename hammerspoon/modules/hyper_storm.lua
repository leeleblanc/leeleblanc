-- =====================================================================
-- 🌩 HYPER STORM GUARD — A STUCK ⇪ CATCHES ITSELF (no key)
-- =====================================================================
-- 6.214.1 — LL, on 6.214.0: "killed my keyboard and made every key
-- execute some hammerspoon action. I was able to pause it. When this
-- happens, can't hammerspoon catch itself, stop the execution after 5
-- seconds of this error condition and generate an error report I can
-- give you? I think it can because hammerspoon is still running."
--
-- WHAT HAPPENED. The ⇪ hold LATCHED — an F18 keyUp that never reached
-- the hotkey (6.162.1's class) — so every letter he typed ran the ⇪
-- shortcut on that letter. The 6.162.1 watchdog exists for exactly
-- this and could not end it, by its own rule: "any key the tap sees
-- while ⇪ is down proves the hold is real" re-stamps the deadline, and
-- a person fighting a dead keyboard presses keys without pause. The
-- watchdog waits for eight seconds of SILENCE; the storm is the
-- opposite of silence. That ⇧Esc alone paused it is the proof the hold
-- was latched: ⇪⇧Esc is the pause key, and ⇪ was already "held".
--
-- THE RULE. A hold is a STORM when all three are true: it has lasted
-- `st.secs` (5) seconds; at least `st.keys` (6) DIFFERENT ⇪ shortcuts
-- have fired inside it (a finger holding ⇪ presses one or two; a hand
-- typing a sentence presses six different letters in a second); and
-- no F18 autorepeat has arrived in the last `st.repeatGrace` (2) s — a
-- real finger on Caps Lock autorepeats (init.lua's F18 bind gained a
-- repeatfn for this), a phantom never does. Then it RELEASES the hold
-- (`_G.hyperForceRelease`), writes the report, alerts the path and
-- prints it. The shortcuts already fired stay fired — nothing here can
-- unrun them — but the seventh letter types. A second storm inside
-- `st.window` (600 s) also PAUSES the config (⇪⇧Esc resumes), because
-- two latches in ten minutes is a Mac that will latch a third time.
--
-- THE REPORT is a file he can hand over: ~/.hammerspoon/.storm/
-- storm-<epoch>.txt — version, Mac, time, how long the hold lasted,
-- every key that fired in it with the module that owns it, what panel
-- had asked for a release, the front app, then the key trail, the
-- error report and the notices as they stood. LOCAL, never OneDrive
-- (a temporary file goes to a local folder — 6.213.3's rule). The
-- next boot announces the newest one ONCE (hs.settings remembers), and
-- `_G.stormReport()` prints the summary and the newest file's text.
--
-- IT DEGRADES: no folder → the alert says the report was not written
-- and why, and the release still happens; no hs.settings → every boot
-- announces again and says so; a report gatherer that throws is one
-- missing section, named. `st.judge` is PURE — the whole rule is
-- provable without a Mac, and the suite runs it against the mutations
-- it exists to catch. Off: settings = { hyper_storm = { on = false } }.
-- =====================================================================
local M = {
    name    = "Hyper Storm Guard",
    order   = 13.86,
    family  = "auto",
    summary = "A latched ⇪ that is running your typing as shortcuts is released after 5 s and written up",
    cheatsheet = {
        title = "🌩 HYPER STORM GUARD (a stuck Caps Lock releases itself and writes a report)",
        entries = {
            { "automatic", "⇪ held 5 s with 6 different shortcuts fired and no Caps Lock autorepeat → the hold is a phantom: released" },
            { "report",    "~/.hammerspoon/.storm/storm-<epoch>.txt — send that file; the alert names it" },
            { "twice",     "a second storm in 10 min also pauses Hammerspoon — ⇪⇧Esc resumes" },
            { "console",   "_G.stormReport() — the last storm, the counts, the newest report's text" },
            { "off",       "settings = { hyper_storm = { on = false } }" },
        },
    },
}

function M.setup(core)
    core = core or {}
    local configDir = (hs and hs.configdir) or core.configDir
    local st = {
        on          = true,
        secs        = 5,        -- a hold this old…
        keys        = 6,        -- …with this many DIFFERENT shortcuts fired inside it…
        repeatGrace = 2,        -- …and no F18 autorepeat this recent, is a storm
        window      = 600,      -- two storms inside this → pause as well
        pauseAt     = 2,
        dir         = configDir and (configDir .. "/.storm") or nil,
        settingsKey = "hyperStorm.seenEpoch",
        readMax     = 8192,     -- bytes of a report echoed by _G.stormReport()
        sectionMax  = 6000,     -- bytes kept of each gathered report
        -- state
        holdId      = nil,      -- _G.hyperEnteredAt of the hold being watched
        seen        = {},       -- combo → true, for the hold being watched
        order       = {},       -- { combo, source } in the order they fired
        noted       = 0,
        storms      = 0,
        times       = {},       -- epochs of storms this session (the window rule)
        last        = nil,      -- { at, age, keys, path, why, paused }
        announced   = nil,
        announceWhy = nil,
    }
    M.config = st
    _G.hyperStorm = st

    local function now() return hs.timer.secondsSinceEpoch() end
    local function alert(m, secs) pcall(function() hs.alert.show(m, secs or 3) end) end
    local function record(what, why)
        if _G.notices and _G.notices.record then
            pcall(_G.notices.record, "runtime", "hyper_storm", what .. (why and (" — " .. why) or ""))
        end
    end
    -- 6.215.0 — the first taker of the degrade door: a folder that cannot
    -- be listed, or an announce that threw, is alerted at boot, not only
    -- printed into a report LL opens a week later. `st.degrade` so warm()
    -- (outside setup) reaches it; the fallback prints when core has no door.
    function st.degrade(why)
        if type(core) == "table" and type(core.degrade) == "function" then
            return core.degrade("Hyper storm guard", why)
        end
        print("⚠️ Hyper storm guard: " .. tostring(why))
        return false, why
    end

    -- ---- the rule, pure ---------------------------------------------------
    -- s = { active, enteredAt, repeatAt, distinct }, t = now. Returns
    -- true, age when the hold is a storm; false, why otherwise.
    function st.judge(s, t, cfg)
        cfg = cfg or st
        if not s.active then return false, "⇪ is not held" end
        if type(s.enteredAt) ~= "number" then return false, "no hold start recorded" end
        local age = t - s.enteredAt
        if age < cfg.secs then return false, string.format("held %.1f s — under %d s", age, cfg.secs) end
        if (s.distinct or 0) < cfg.keys then
            return false, string.format("%d different shortcut(s) — under %d", s.distinct or 0, cfg.keys)
        end
        if type(s.repeatAt) == "number" and t - s.repeatAt < cfg.repeatGrace then
            return false, string.format("Caps Lock autorepeated %.1f s ago — a real finger", t - s.repeatAt)
        end
        return true, age
    end

    -- ---- every ⇪ shortcut passes here (init.lua's hyperBind wrapper) ----
    function st.note(combo, source)
        if st.on == false then return false, "off" end
        if not _G.hyperActive then return false, "not held" end
        local id = _G.hyperEnteredAt
        if id ~= st.holdId then
            st.holdId, st.seen, st.order = id, {}, {}
        end
        combo = tostring(combo or "?")
        if not st.seen[combo] then
            st.seen[combo] = true
            st.order[#st.order + 1] = { combo, tostring(source or "?") }
        end
        st.noted = st.noted + 1
        local t = now()
        local storm, why = st.judge({ active = true, enteredAt = id, repeatAt = _G.hyperRepeatAt,
                                      distinct = #st.order }, t)
        if not storm then return false, why end
        return st.fire(why, t)
    end
    _G.hyperStormNote = st.note

    -- 6.214.2 — every keyDown the ⇪ tap sees while the hold is up (core/
    -- hyper_key.lua), named the way hyperBind names its combos so the
    -- same key from both doors is ONE key. This is what counts the
    -- letters a tool's own keyboard mode eats: LL's test typed x, ⇪X
    -- opened the mouse grid, the grid ate a–f, and the count stopped at
    -- one. The tap runs whether or not it dispatches, so this door is
    -- open on every Mac that grants Accessibility; hyperBind's note is
    -- the one that stays when it is not.
    function st.keyNote(code, ev)
        if st.on == false or not _G.hyperActive then return false, "not held" end
        local name
        pcall(function() name = hs.keycodes and hs.keycodes.map and hs.keycodes.map[code] end)
        if type(name) ~= "string" then name = "key" .. tostring(code) end
        if name == "f18" then return false, "the hyper key itself" end
        local mods = {}
        local f = {}
        pcall(function() f = (ev and ev.getFlags and ev:getFlags()) or {} end)
        for _, m in ipairs({ "alt", "cmd", "ctrl", "shift" }) do if f[m] then mods[#mods + 1] = m end end
        local combo
        if type(_G.hyperCombo) == "function" then
            combo = _G.hyperCombo(mods, name)
        else
            table.sort(mods)
            combo = (#mods > 0 and (table.concat(mods, "+") .. "+") or "") .. tostring(name):lower()
        end
        return st.note(combo, "typed under ⇪")
    end
    _G.hyperStormKey = st.keyNote

    -- ---- the report ---------------------------------------------------------
    local function captured(fnName)
        local fn = _G[fnName]
        if type(fn) ~= "function" then return "(" .. fnName .. " is not loaded)" end
        local buf = {}
        local saved = print
        print = function(...)
            local p = {}
            for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
            buf[#buf + 1] = table.concat(p, " ")
        end
        local ok, err = pcall(fn)
        print = saved
        if not ok then return "(" .. fnName .. " threw: " .. tostring(err) .. ")" end
        local s = table.concat(buf, "\n")
        if #s > st.sectionMax then s = s:sub(1, st.sectionMax) .. "\n… (cut at " .. st.sectionMax .. " bytes)" end
        return s
    end

    function st.reportText(age, t)
        local L = {}
        local function add(s) L[#L + 1] = s end
        local mac = "?"
        pcall(function() mac = hs.host.localizedName() end)
        local front = "?"
        pcall(function() front = hs.application.frontmostApplication():name() end)
        add("🌩 HYPER STORM REPORT — Hammerspoon config " .. tostring(_G.configVersion or "?"))
        add("when   : " .. os.date("%Y-%m-%d %H:%M:%S", math.floor(t)) .. " on " .. tostring(mac))
        add(string.format("hold   : ⇪ held %.1f s with no F18 keyUp; %d different shortcut(s) fired in it (%d presses noted)",
                          age, #st.order, st.noted))
        add("front  : " .. tostring(front))
        add("asked  : " .. tostring(_G.hyperReleaseExpected or "no panel had asked for a release"))
        add(string.format("before : watchdog releases this session %d · Caps Lock autorepeats %d · storms this session %d",
                          tonumber(_G.hyperLatchReleases) or 0, tonumber(_G.hyperRepeats) or 0, st.storms))
        add("keys   : (in order, combo · owner)")
        for i, k in ipairs(st.order) do add(string.format("   %2d. ⇪%s · %s", i, k[1], k[2])) end
        add("")
        add("── key trail ──"); add(captured("keyTrailReport"))
        add("── errors ──");    add(captured("errorsReport"))
        add("── notices ──");   add(captured("noticesReport"))
        return table.concat(L, "\n") .. "\n"
    end

    function st.ensureDir()
        if not st.dir then return false, "no config folder known" end
        local ok, attrs = pcall(function() return hs.fs and hs.fs.attributes and hs.fs.attributes(st.dir) end)
        if ok and type(attrs) == "table" and attrs.mode == "directory" then return true end
        if ok and type(attrs) == "table" then return false, st.dir .. " exists and is not a folder" end
        pcall(function() if hs.fs and hs.fs.mkdir then hs.fs.mkdir(st.dir) end end)
        local f = io.open(st.dir .. "/.probe", "w")
        if not f then return false, "cannot create " .. st.dir end
        f:close()
        os.remove(st.dir .. "/.probe")
        return true
    end

    function st.write(text, t)
        local ok, why = st.ensureDir()
        if not ok then return nil, why end
        local path = string.format("%s/storm-%d.txt", st.dir, math.floor(t))
        local f, err = io.open(path, "w")
        if not f then return nil, "cannot write " .. path .. " (" .. tostring(err) .. ")" end
        f:write(text)
        f:close()
        return path
    end

    -- ---- the storm ----------------------------------------------------------
    function st.fire(age, t)
        t = t or now()
        st.storms = st.storms + 1
        st.times[#st.times + 1] = t
        local recent = 0
        for _, e in ipairs(st.times) do if t - e <= st.window then recent = recent + 1 end end
        local text = st.reportText(age, t)
        local path, werr = st.write(text, t)
        local released = false
        if type(_G.hyperForceRelease) == "function" then
            released = _G.hyperForceRelease("the ⇪ storm guard") == true
        elseif type(_G.hyperReleaseSeen) == "function" then
            released = _G.hyperReleaseSeen("the ⇪ storm guard") == true
        end
        local paused = false
        if recent >= st.pauseAt then
            _G.hsPaused = true
            paused = true
        end
        local msg = string.format("🌩 ⇪ STORM CAUGHT — Caps Lock was stuck %.0f s and %d different keys ran ⇪ shortcuts. %s. %s",
            age, #st.order,
            released and "Released — the next key types" or "⚠️ could NOT release it — press Caps Lock once",
            path and ("Report: " .. path) or ("report NOT written — " .. tostring(werr)))
        if paused then msg = msg .. string.format(" — %d storms in %d min: PAUSED, %s resumes",
                                                  recent, math.floor(st.window / 60), _G.hsPauseHint or "⇪⇧Esc") end
        st.last = { at = t, age = age, keys = #st.order, path = path, why = werr, paused = paused, released = released }
        st.holdId, st.seen, st.order = nil, {}, {}
        print(msg .. "\n   _G.stormReport() prints the report.")
        alert(msg, 10)
        record("storm", string.format("%.0f s, %d keys%s", age, st.last.keys, paused and ", paused" or ""))
        return true, msg
    end

    -- ---- the next boot says it once ------------------------------------------
    function st.newest()
        if not st.dir then return nil, "no config folder known" end
        -- 6.214.2 — a folder that does not exist yet is "no reports", not
        -- an error: the first boot on a Mac read "⚠️ cannot list …: No such
        -- file or directory" in the report while the storm file it had
        -- just written sat under it. A missing folder returns nil, nil.
        local okA, attrs = pcall(function() return hs.fs and hs.fs.attributes and hs.fs.attributes(st.dir) end)
        if okA and attrs == nil then return nil, nil end
        local best, bestEpoch
        local ok, err = pcall(function()
            for name in hs.fs.dir(st.dir) do
                local e = tonumber(name:match("^storm%-(%d+)%.txt$"))
                if e and (not bestEpoch or e > bestEpoch) then best, bestEpoch = st.dir .. "/" .. name, e end
            end
        end)
        if not ok then return nil, "cannot list " .. st.dir .. " (" .. tostring(err) .. ")" end
        return best, bestEpoch
    end

    function st.announce()
        local path, epoch = st.newest()
        if not path then
            st.announceWhy = epoch
            if epoch then return st.degrade(epoch) end   -- a real refusal (cannot list) is seen
            return false, "no reports yet"               -- a missing folder is not
        end
        local seen, seenWhy
        local ok = pcall(function() seen = hs.settings.get(st.settingsKey) end)
        if not ok then seenWhy = "hs.settings unavailable — every boot will announce again" end
        st.announceWhy = seenWhy
        seen = tonumber(seen) or 0
        if epoch <= seen then return false, "already announced" end
        local line = "🌩 A ⇪ STORM was caught at " .. os.date("%Y-%m-%d %H:%M:%S", epoch)
            .. " — the report is " .. path .. " (send that file)."
        st.announced = line
        print(line .. "\n   _G.stormReport() prints it.")
        alert(line, 8)
        record("announced", path)
        pcall(function() hs.settings.set(st.settingsKey, epoch) end)
        return true, path
    end

    -- ---- the report ------------------------------------------------------------
    function _G.stormReport()
        local L = { "🌩 Hyper storm guard — " .. (st.on == false and "OFF (settings)" or
            string.format("watching: %d s held · %d different shortcuts · no Caps Lock autorepeat within %d s",
                          st.secs, st.keys, st.repeatGrace)) }
        L[#L + 1] = "   folder : " .. tostring(st.dir or "⚠️ none — no config folder known")
        local held = _G.hyperActive and _G.hyperEnteredAt
            and string.format("⇪ held %.1f s now, %d different shortcut(s) in it", now() - _G.hyperEnteredAt, #st.order)
            or "⇪ not held"
        L[#L + 1] = "   now    : " .. held
        if st.last then
            L[#L + 1] = string.format("   last   : %s — held %.0f s, %d keys, %s%s%s",
                os.date("%Y-%m-%d %H:%M:%S", math.floor(st.last.at)), st.last.age, st.last.keys,
                st.last.released and "released" or "NOT released",
                st.last.paused and ", paused" or "",
                st.last.path and (", report " .. st.last.path) or (", report NOT written — " .. tostring(st.last.why)))
        else
            L[#L + 1] = "   last   : no storm this session"
        end
        L[#L + 1] = string.format("   storms : %d this session · %d watchdog release(s) · %d Caps Lock autorepeat(s)",
                                  st.storms, tonumber(_G.hyperLatchReleases) or 0, tonumber(_G.hyperRepeats) or 0)
        if st.announced then L[#L + 1] = "   boot   : " .. st.announced end
        if st.announceWhy then L[#L + 1] = "   ⚠️ " .. tostring(st.announceWhy) end
        local path = st.newest()
        if path then
            local f = io.open(path, "r")
            if f then
                local text = f:read(st.readMax) or ""
                f:close()
                L[#L + 1] = "   newest : " .. path
                L[#L + 1] = "──────── " .. path .. " ────────"
                L[#L + 1] = text
            else
                L[#L + 1] = "   newest : " .. path .. " (⚠️ cannot read it)"
            end
        else
            L[#L + 1] = "   newest : no report on disk"
        end
        print(table.concat(L, "\n"))
    end
end

function M.warm(core)
    local st = _G.hyperStorm
    if not st or st.on == false then return end
    local ok, err = pcall(st.announce)
    if not ok then
        -- 6.215.0: a throw here used to vanish inside this pcall.
        st.announceWhy = "announce threw — " .. tostring(err)
        pcall(st.degrade, st.announceWhy)
    end
end

return M
