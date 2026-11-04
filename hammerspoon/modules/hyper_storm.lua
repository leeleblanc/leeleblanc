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
-- 🔬 6.403.0 — AND IT NOW ASKS WHY. LL's 2026-11-04 Console caught ⇪
-- latching TWICE in forty-five seconds (05:14:39, held 7 s, 7 keys;
-- 05:15:24, held 14.4 s, 6 keys — and the second one PAUSED the
-- config). The guard did its job both times. What neither file could
-- say is WHICH of the three things that can latch ⇪ with the key
-- physically up had happened — the hidutil Caps Lock → F18 remap, the
-- F18 event tap, or Secure Input — because 6.303.0 built the probe
-- that reads all three and wired it to WAKE EVENTS ONLY. A storm is
-- the other moment those three facts decide something, and it is the
-- moment nobody is there to run a command.
--
-- 🔑 GENERAL, and it is the half to carry: WHEN A GUARD CATCHES A
-- FAULT, ASK THE QUESTIONS WHOSE ANSWERS DECIDE THE FIX, AT THAT
-- MOMENT. `before :` has always carried COUNTS — how many latches,
-- handovers, relays, autorepeats — and a count says how often, never
-- why. The probe is free on a healthy Mac because it only runs when a
-- storm fires, and it is the only reading taken while the fault is
-- still on the Mac.
--
-- 🚪 THE RELEASE COMES FIRST AND THE PROBE SECOND, asserted by a check
-- on the ORDER rather than on both having happened (6.220.0): the
-- release is what gets his keyboard back, and a probe that throws must
-- never be able to cost it.
-- 🪜 ITS ANSWERS ARRIVE LATE, because reading the remap is an out-of-
-- process task (6.228.0 — this runs while he is typing). So the file
-- is written AT ONCE without them, and a held timer APPENDS the three
-- answers a beat later. An append cannot shrink a file (6.279.0), so a
-- failed append costs the section and never the report.
-- 🚨 AND A SECOND STORM MUST NOT STOMP THE FIRST ONE'S PENDING APPEND —
-- his own log is two storms forty-five seconds apart, so that is not
-- hypothetical. One timer, a LIST of waiting files, drained together:
-- one probe answer serves every storm still waiting, and there is no
-- generation to get wrong (6.304.0's problem, dissolved rather than
-- guarded).
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
            { "why",       "a storm now ASKS which of three things latched ⇪ — the Caps Lock remap, the F18 tap, Secure Input — and appends the answers to its own file" },
            { "console",   "_G.stormReport() — the last storm, the counts, the newest report's text" },
            { "endings",   "_G.hyperKeyReport() — how the ⇪ hold ended: relay · handover · wake · LATCH." },
            { "",          "Only a latch is a fault; a panel taking the keyboard is not (6.285.0)" },
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
        -- 6.403.0 — the probe asked when a storm fires
        probeOn     = true,
        probeSecs   = 2.5,      -- beat before the answers are appended
        probeFresh  = 8,        -- a reading this old still describes this storm
        probeWaitMax = 8,       -- files that may be waiting for an append
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
        probeWaiting = {},      -- { {path, at}, ... } awaiting the answers
        probeTimer  = nil,      -- held: an unreferenced timer never fires
        probes      = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 },
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

    -- ---- why, pure --------------------------------------------------------
    -- 🔬 6.403.0 — the three things that can latch ⇪ with the key up,
    -- rendered from a probe table handed IN (6.234.0: the clock is an
    -- argument too, so the gate proves every state with no Mac).
    --
    -- 🔎 THREE FRESHNESS STATES, AND THEY MUST NOT READ ALIKE (6.196.1).
    -- A reading taken AT this storm answers about this storm. A reading
    -- left over from a wake forty minutes ago does NOT, and the middle
    -- state is the trap: printed without its age it is word-for-word
    -- the first, and it is exactly the state every file would have been
    -- in while the probe was wired to wakes alone. Never asked is
    -- neither of them.
    function st.probeLines(P, t)
        local L = {}
        local function add(x) L[#L + 1] = x end
        if type(P) ~= "table" or type(P.at) ~= "number" then
            add("why    : ⏳ NOT ASKED — the three things that can latch ⇪ with "
                .. "the key up were not read, so this file cannot say which")
            return L, "never"
        end
        local age = math.floor((tonumber(t) or P.at) - P.at)
        local fresh = age <= (tonumber(st.probeFresh) or 8)
        if fresh then
            add("why    : measured AT this storm (" .. tostring(P.why or "?")
                .. ", " .. os.date("%H:%M:%S", math.floor(P.at)) .. ")")
        else
            add(string.format("why    : ⚠️ AN OLD READING — taken %s at %s, "
                .. "%d s before this storm. It does NOT describe this storm.",
                tostring(P.why or "?"), os.date("%H:%M:%S", math.floor(P.at)), age))
        end
        -- One renderer, two readers (6.231.0): core/hyper_key.lua owns
        -- these sentences and _G.hyperKeyReport() prints the same three.
        -- A core that did not load must not cost the storm file, so the
        -- fallback says the words could not be built rather than health.
        local a, b, c
        if type(_G.hyperProbeAnswers) == "function" then
            local ok
            ok, a, b, c = pcall(_G.hyperProbeAnswers, P)
            if not ok then a, b, c = nil, nil, nil end
        end
        add("   remap : " .. tostring(a or "⚠️ could not be rendered (core/hyper_key.lua)"))
        add("   tap   : " .. tostring(b or "⚠️ could not be rendered (core/hyper_key.lua)"))
        add("   secure: " .. tostring(c or "⚠️ could not be rendered (core/hyper_key.lua)"))
        add(string.format("   counts: %d read(s) · %d could not be read · %d remap(s) put back%s",
            tonumber(P.reads) or 0, tonumber(P.failed) or 0, tonumber(P.repaired) or 0,
            (tonumber(P.repairFailed) or 0) > 0
                and (" · ⚠️ " .. P.repairFailed .. " repair(s) FAILED") or ""))
        return L, (fresh and "fresh" or "stale")
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
        -- 6.285.0 — the three endings, apart. Until then this number
        -- summed a real latch with two kinds of health (a panel taking
        -- the keyboard, and a page relaying the keyUp), so it climbed on
        -- a Mac where ⇪ had never once stuck.
        -- 6.302.0 — and a FOURTH ending: the Mac woke with ⇪ still held
        -- and the hold was let go. That is the shape of the 10:57 storm
        -- this line was read to diagnose, so a storm written AFTER this
        -- release with a wake count of 0 says the wake was not the cause.
        add(string.format("before : LATCH releases this session %d · panel handovers %d · keyUp relays %d · wake releases %d (of %d wake(s) seen, %s) · Caps Lock autorepeats %d · storms this session %d",
                          tonumber(_G.hyperLatchReleases) or 0,
                          tonumber(_G.hyperPanelHandovers) or 0,
                          tonumber(_G.hyperRelayReleases) or 0,
                          tonumber(_G.hyperWakeReleases) or 0,
                          tonumber(_G.hyperWakesSeen) or 0,
                          tostring(_G.hyperWakeState or "not started"),
                          tonumber(_G.hyperRepeats) or 0, st.storms))
        -- 🔬 6.403.0 — CAUSES BESIDE THE COUNTS. Everything above this
        -- line says how OFTEN; nothing said WHICH, and the fix differs
        -- for each of the three. At this instant the fresh reading has
        -- not landed (the remap is read out of process), so what prints
        -- here is whatever was last known — honestly labelled — and the
        -- fresh one is appended at the end of the file.
        add("")
        for _, x in ipairs(st.probeLines(_G.hyperWakeProbe, t)) do add(x) end
        if st.probeOn ~= false then
            add("   ↳ a FRESH reading was asked for the moment this storm "
                .. "fired; it is appended at the END of this file a few "
                .. "seconds later, and _G.hyperKeyReport() has it either way.")
        end
        add("")
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

    -- 📎 APPEND, NEVER REWRITE. An append cannot shrink a file
    -- (6.279.0), so a refused append costs this one section and can
    -- never cost the storm report already on disk. The write's own
    -- return is READ (6.325.0): io.write refuses by answering nil, and
    -- a pcall around it is true either way.
    function st.appendSection(path, name, lines)
        if type(path) ~= "string" or path == "" then return false, "no path" end
        local text = "\n── " .. tostring(name) .. " ──\n"
            .. table.concat(lines, "\n") .. "\n"
        local f, err = io.open(path, "a")
        if not f then return false, "cannot append to " .. path .. " (" .. tostring(err) .. ")" end
        local wrote, werr = f:write(text)
        f:close()
        if not wrote then return false, "the append was refused — " .. tostring(werr) end
        return true
    end

    -- 🪜 ONE TIMER, A LIST OF WAITING FILES. A second storm inside the
    -- beat ADDS to the list rather than taking the slot — his own log
    -- is two storms forty-five seconds apart, and a single slot would
    -- have dropped the first one's answers in silence. One probe answer
    -- serves every storm still waiting, so there is no generation to
    -- get wrong (6.304.0's problem dissolved rather than guarded).
    function st.probeWait(path, t)
        if #st.probeWaiting >= (tonumber(st.probeWaitMax) or 8) then
            st.probes.dropped = st.probes.dropped + 1
            return false, "too many files already waiting"
        end
        st.probeWaiting[#st.probeWaiting + 1] = { path = path, at = t }
        if st.probeTimer then return true, "a beat is already on its way" end
        if not (hs.timer and hs.timer.doAfter) then
            st.probes.noTimer = st.probes.noTimer + 1
            return false, "no hs.timer.doAfter on this Mac"
        end
        local ok
        ok, st.probeTimer = pcall(hs.timer.doAfter, tonumber(st.probeSecs) or 2.5,
                                  function() pcall(st.probeLand) end)
        if not ok or not st.probeTimer then
            st.probeTimer = nil
            st.probes.noTimer = st.probes.noTimer + 1
            return false, "could not arm the beat"
        end
        return true
    end

    -- The answers have landed in _G.hyperWakeProbe; give them to every
    -- file still waiting. Each one is rendered against ITS OWN storm
    -- time, so a file that waited through a second storm still reports
    -- its own freshness honestly.
    function st.probeLand()
        st.probeTimer = nil
        local pending = st.probeWaiting
        st.probeWaiting = {}
        for _, w in ipairs(pending) do
            local lines = st.probeLines(_G.hyperWakeProbe, w.at)
            local ok, why = st.appendSection(w.path, "why (measured at the storm)", lines)
            if ok then
                st.probes.landed = st.probes.landed + 1
            else
                st.probes.failed = st.probes.failed + 1
                st.probeWhy = why
            end
        end
        return true
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
        -- 🚪 THE PROBE COMES AFTER THE RELEASE, and a check asserts the
        -- ORDER rather than that both happened (6.220.0). The release is
        -- what lets his next key type; the probe is diagnosis, and a
        -- probe that throws must never be able to cost it.
        local asked = false
        if st.probeOn ~= false and type(_G.hyperWakeProbeRun) == "function" then
            st.probes.asked = st.probes.asked + 1
            asked = pcall(_G.hyperWakeProbeRun, "the ⇪ storm guard") and true or false
            if not asked then st.probes.failed = st.probes.failed + 1 end
            if path then st.probeWait(path, t) end
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
        if asked then msg = msg .. " · asking WHY — the answer lands in that file in a moment" end
        st.last = { at = t, age = age, keys = #st.order, path = path, why = werr,
                    paused = paused, released = released, asked = asked }
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
        -- 6.403.0 — asked/landed counted APART: a probe that was asked
        -- and whose answer never reached the file is not the same fact
        -- as one that was never asked (6.196.1).
        L[#L + 1] = string.format("   why    : %d probe(s) asked at a storm · %d answer(s) appended to the file",
                                  st.probes.asked, st.probes.landed)
        if st.probes.noTimer > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. st.probes.noTimer .. " could not arm the append beat — "
                .. "the answers are in _G.hyperKeyReport(), not in the file"
        end
        if st.probes.failed > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. st.probes.failed .. " failed — " .. tostring(st.probeWhy or "?")
        end
        if st.probes.dropped > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. st.probes.dropped .. " storm(s) got no answer: too many waiting at once"
        end
        if #st.probeWaiting > 0 then
            L[#L + 1] = "   ↳ " .. #st.probeWaiting .. " file(s) waiting for the answers right now"
        end
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
