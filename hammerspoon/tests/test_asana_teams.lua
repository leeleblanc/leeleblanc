-- =====================================================================
-- test_asana_teams.lua — 🏷 6.284.0, the team name that goes stale
-- =====================================================================
--     lua5.4 test_asana_teams.lua [/path/to/hammerspoon]
--
-- LL: "Why do I have to hard code team names" — with the team's real
-- name beside it, one word shorter than the literal in the config.
--
-- The honest answer is that he should not have to. `resolveAsanaTeamGids`
-- has always fetched Asana's team list LIVE on every boot; what was stale
-- was the other half, the name it searches FOR. Asana's answer is fresh
-- and our question is not, so renaming a team is precisely what breaks
-- it — and the config then says, correctly, that no team has that name.
--
-- This suite proves the two halves of the fix with no Mac and no network
-- (M.teamKey and M.matchTeam are PURE and live outside setup), and then
-- boots the real module against a Mac-in-tables to prove the pin round
-- trip, the three printed states, and that the token never leaves the
-- Authorization header.

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

local mod = dofile(HS .. "/modules/asana_comments.lua")

-- =====================================================================
out("\n=== 1. 🔑 teamKey — what survives the decoration drifting ===\n")
-- =====================================================================
local K = mod.teamKey
check("the \"| N. Name |\" wrapper is decoration, not the name",
      K("| 2. SAC Library Team Member Projects |") == "sac library team member projects",
      K("| 2. SAC Library Team Member Projects |"))
check("…and the NUMBER can change without breaking the match",
      K("| 2. SAC Library Core Projects |") == K("| 7. SAC Library Core Projects |"))
check("case is not a difference", K("SAC Library") == K("sac library"))
check("outer whitespace is not a difference", K("  SAC Library  ") == K("SAC Library"))
check("a DOUBLED space inside the name is not a difference",
      K("SAC  Library") == K("SAC Library"))
-- 🔎 The old warning told him to "check spelling/spacing", which was
-- already stale advice — the compare was case-folded and trimmed on both
-- sides — and it could never have found THIS, because a non-breaking
-- space is invisible in a name copied out of a browser.
-- 🧪 6.230.0 — PICK THE INPUT WHERE THE TWO IMPLEMENTATIONS MUST DIFFER.
-- A bare "SAC<nbsp>Library" proves nothing: the punctuation rule below
-- already turns those two bytes into spaces and the answer comes out the
-- same with the nbsp line deleted. The fixture that bites puts the
-- non-breaking space INSIDE the decoration, where the "| N. …" pattern
-- needs a real %s and will not match one.
check("🚨 a NON-BREAKING space reads as a space — including inside the "
      .. "\"| N. \" wrapper, where it would otherwise defeat the strip",
      K("|\194\1602. SAC Library |") == K("| 2. SAC Library |"),
      K("|\194\1602. SAC Library |"))
check("…and in the body of the name too",
      K("SAC\194\160Library") == K("SAC Library"))
check("\"&\" and \"and\" are the same word",
      K("Projects & Tasks") == K("Projects and Tasks"), K("Projects & Tasks"))
check("punctuation is decoration", K("Projects: Tasks!") == K("Projects Tasks"))
check("nil and empty answer the empty key, never nil",
      K(nil) == "" and K("") == "")
check("🚨 …but a name with an EXTRA WORD is a DIFFERENT team, which is "
      .. "exactly LL's case and is why normalising alone cannot fix it",
      K("| 2. SAC Library Team Member Projects & Tasks |")
        ~= K("| 2. SAC Library Team Member Projects |"))

-- =====================================================================
out("\n=== 2. 🏷 matchTeam — three answers, and the middle one is the release ===\n")
-- =====================================================================
local TEAMS = {
    { gid = "111", name = "| 1. SAC Library Core Projects |" },
    { gid = "222", name = "| 2. SAC Library Team Member Projects |" },
    { gid = "333", name = "| 9. Something Else |" },
}
local WANT = { "| 1. SAC Library Core Projects |",
               "| 2. SAC Library Team Member Projects |" }

local r = mod.matchTeam(WANT, TEAMS, {})
check("both names match outright", #r == 2 and r[1].how == "name" and r[2].how == "name")
check("…and carry the real gids", r[1].gid == "111" and r[2].gid == "222")
check("…and each asks for its key to be PINNED", r[2].pin and r[2].pin[K(WANT[2])] == "222")

-- 🔑 THE RELEASE. The config still asks for the OLD name; Asana no longer
-- has it. The pin written on an earlier boot is what finds it anyway.
local RENAMED = {
    { gid = "111", name = "| 1. SAC Library Core Projects |" },
    { gid = "222", name = "| 2. SAC Library Reading Room |" },
}
local stale = { "| 1. SAC Library Core Projects |",
                "| 2. SAC Library Team Member Projects |" }
local pins = { [K(stale[2])] = "222" }
local r2 = mod.matchTeam(stale, RENAMED, pins)
check("🏷 A RENAMED TEAM IS STILL FOUND — by the gid pinned on an earlier boot",
      r2[2].how == "gid" and r2[2].gid == "222", r2[2].how)
check("…and it says what the team is called NOW, so the config can be "
      .. "brought into line rather than guessed at",
      r2[2].name == "| 2. SAC Library Reading Room |")
check("…and it pins the NEW key too, so a config brought into line matches "
      .. "by name again (the cheap way)",
      r2[2].pin and r2[2].pin[K("| 2. SAC Library Reading Room |")] == "222")
-- 🚨 AND IT RE-PINS THE KEY WE ASKED WITH. Pinning only the new name reads
-- as tidier and makes the pin DECAY: the config still asks the old name,
-- so the next boot would find no pin under it and fall to "none" — the
-- rename would survive exactly one boot.
check("🚨 …and it RE-PINS THE ASKED key, or the pin decays after one boot "
      .. "and the rename breaks on the next one",
      r2[2].pin and r2[2].pin[K(stale[2])] == "222")
check("…while the team that did NOT move still matches by name",
      r2[1].how == "name")

local r3 = mod.matchTeam(stale, RENAMED, {})
check("🔎 with no pin there is nothing to fall back on — 'none', not a guess",
      r3[2].how == "none" and r3[2].gid == nil)
check("…and 'none' carries no pin to write", r3[2].pin == nil)

-- 🚨 A STALE PIN MUST NOT INVENT A TEAM. The gid was pinned once; that
-- team is gone from Asana now. Answering "gid" here would hand the
-- roster fetch a gid that 404s, and the picker would be shortened with
-- no line saying why.
local r4 = mod.matchTeam({ "| 2. Gone |" }, { { gid = "999", name = "Other" } },
                         { [K("| 2. Gone |")] = "222" })
check("🚨 a pin whose gid is NOT in Asana's answer is not a match",
      r4[1].how == "none", r4[1].how)

-- Two configured names that resolve to the same team must not both claim
-- it: the roster fetch would ask for it twice and dedupe nothing.
local r5 = mod.matchTeam({ "| 1. Core |", "| 4. core |" },
                         { { gid = "111", name = "| 1. Core |" } }, {})
check("two names for one team claim it ONCE", r5[1].how == "name" and r5[2].how == "none")

check("a team with no gid in Asana's answer is skipped, never indexed",
      (function()
          local ok, res = pcall(mod.matchTeam, { "X" }, { { name = "X" } }, {})
          return ok and res[1].how == "none"
      end)())
check("nil arguments answer an empty list rather than throwing",
      (function()
          local ok, res = pcall(mod.matchTeam, nil, nil, nil)
          return ok and type(res) == "table" and #res == 0
      end)())

-- =====================================================================
out("\n=== 3. 🔌 the real module, against a Mac in tables ===\n")
-- =====================================================================
local printed = {}
local realPrint = print
local function capture(on)
    if on then
        printed = {}
        print = function(...)
            local t = {}
            for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
            printed[#printed + 1] = table.concat(t, " ")
        end
    else
        print = realPrint
    end
end
local function said(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return l end end
    return nil
end

local SETTINGS = {}
local GETS = {}
local REPLY = {}          -- url-substring -> { status, body }
_G.hs = {
    http = {
        asyncGet = function(url, headers, cb)
            GETS[#GETS + 1] = { url = url, headers = headers }
            for frag, rep in pairs(REPLY) do
                if url:find(frag, 1, true) then return cb(rep[1], rep[2]) end
            end
            cb(500, "")
        end,
        asyncPost = function() end,
    },
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
    json = { encode = function() return "{}" end },
    alert = { show = function() end },
}
_G.safeJson = function(body) return (load("return " .. body))() end

local provided = {}
local core = {
    asanaEnabled     = true,
    asanaToken       = "SECRET-TOKEN",
    asanaWorkspaceId = "12345",
    provide = function(n, f) provided[n] = f end,
}

local function boot()
    GETS = {}
    _G.asanaTeamMembers, _G.asanaTeamsSeen, _G.asanaTeamMatch = nil, nil, nil
    capture(true)
    mod.setup(core)
    capture(false)
end

-- --- 3a. the ordinary boot ------------------------------------------------
out("\n  3a. both teams match by name, and their gids are pinned\n")
REPLY = {
    ["/teams?opt_fields=name"] = { 200, [[{ data = {
        { gid = "111", name = "| 1. SAC Library Core Projects |" },
        { gid = "222", name = "| 2. SAC Library Team Member Projects |" },
    } }]] },
    ["/teams/111/users"] = { 200, [[{ data = { { gid = "a", name = "Ann" } } }]] },
    ["/teams/222/users"] = { 200, [[{ data = { { gid = "b", name = "Bob" } } }]] },
}
SETTINGS = {}
boot()
check("the team list is fetched LIVE at boot — Asana's answer is never stale",
      (function()
          for _, g in ipairs(GETS) do
              if g.url:find("/teams?opt_fields=name", 1, true) then return true end
          end
          return false
      end)())
check("…and it is the CONFIG's question that was stale, which is the whole "
      .. "answer to his question", said("⚠️ Asana team not found") == nil,
      said("⚠️ Asana team not found"))
check("both rosters are merged", #(_G.asanaTeamMembers or {}) == 2)
check("🏷 the gids are PINNED in hs.settings, which is what makes the NEXT "
      .. "rename cost nothing", (function()
          local p = SETTINGS["asana.teamGids"]
          return type(p) == "table" and p[K("| 2. SAC Library Team Member Projects |")] == "222"
      end)())
check("🔐 the token travels in the Authorization header and nowhere else — "
      .. "never in a URL", (function()
          for _, g in ipairs(GETS) do
              if g.url:find("SECRET-TOKEN", 1, true) then return false end
              if (g.headers or {})["Authorization"] ~= "Bearer SECRET-TOKEN" then return false end
          end
          return #GETS > 0
      end)())

-- --- 3b. he renames the team ---------------------------------------------
out("\n  3b. 🏷 he renames the team in Asana and NOTHING breaks\n")
REPLY["/teams?opt_fields=name"] = { 200, [[{ data = {
    { gid = "111", name = "| 1. SAC Library Core Projects |" },
    { gid = "222", name = "| 2. SAC Library Reading Room |" },
} }]] }
boot()
check("🏷 the renamed team is still resolved — by its pinned GID",
      said("Asana team renamed") ~= nil, printed[1])
check("…and the line says what it is called NOW",
      (said("Asana team renamed") or ""):find("SAC Library Reading Room", 1, true) ~= nil)
check("…and there is no ⚠️ at all, because nothing failed",
      said("⚠️ Asana team not found") == nil)
check("…and its members are still in the picker", #(_G.asanaTeamMembers or {}) == 2)
-- 🚨 A SECOND BOOT ON THE RENAMED TEAM. This is what a pin that only ever
-- records the CURRENT name cannot do: the config still asks the old name,
-- so the pin under the old key has to be re-written every boot.
boot()
check("🚨 …and it is STILL resolved on the boot after that — the pin does "
      .. "not decay", said("Asana team renamed") ~= nil
      and said("⚠️ Asana team not found") == nil)

-- --- 3c. no pin, no match -------------------------------------------------
out("\n  3c. 🔎 a team that really is missing NAMES what Asana answered\n")
SETTINGS = {}
boot()
local warn = said("⚠️ Asana team not found")
check("the ⚠️ fires when there is no name match and no pin", warn ~= nil)
-- 🔎 The old line said "check spelling/spacing against Asana" and named
-- nothing, so it could not be acted on: a WRONG rename warns identically.
check("🔎 …and it NAMES the teams Asana actually holds, so the rename is "
      .. "not a guess", warn and warn:find("SAC Library Reading Room", 1, true) ~= nil,
      warn)
check("…and it points at the command that lists them all",
      warn and warn:find("_G.asanaTeams()", 1, true) ~= nil)
check("🔎 …and the picker still works — the cost is a SHORTENED roster, "
      .. "never a broken door", #(_G.asanaTeamMembers or {}) >= 1)

-- --- 3d. the report -------------------------------------------------------
out("\n  3d. 🔎 _G.asanaTeams() — asked, beside answered\n")
check("the command exists", type(_G.asanaTeams) == "function")
capture(true); _G.asanaTeams(); capture(false)
local rep = table.concat(printed, "\n")
check("it names what we ASKED for", rep:find("asked", 1, true) ~= nil)
check("it names what Asana ANSWERED, with gids",
      rep:find("SAC Library Reading Room", 1, true) and rep:find("gid 222", 1, true))
check("it names the cost of a team that did not match — a shortened picker, "
      .. "not a broken submit",
      rep:find("still submits", 1, true) ~= nil, rep)
check("🔐 it never prints the token", rep:find("SECRET-TOKEN", 1, true) == nil)
check("it names the pin store, which is the mechanism",
      rep:find("asana.teamGids", 1, true) ~= nil)

-- 🔎 Asana OFF is a third state and must not read as "no teams".
local offCore = { asanaEnabled = false, provide = function() end }
capture(true); mod.setup(offCore); _G.asanaTeams(); capture(false)
check("with Asana off the report SAYS so rather than reading as 'no teams'",
      table.concat(printed, "\n"):find("Asana is OFF", 1, true) ~= nil)

-- =====================================================================
out("\n=== 4. 🚨 SOURCE — the rule, not the instance ===\n")
-- =====================================================================
do
    local fh = assert(io.open(HS .. "/modules/asana_comments.lua"), "module file")
    local src = fh:read("a"); fh:close()
    local code = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        code[#code + 1] = (line:gsub("%-%-.*$", ""))
    end
    code = table.concat(code, "\n")
    -- 🚨 The whole defect was a name compared BY HAND. One door, or the
    -- next person writes a second, gentler comparison beside it.
    check("🚨 SOURCE: the module compares team names through M.teamKey and "
          .. "nowhere else — no hand-rolled :lower() match survives",
          code:find("wantLower") == nil
          and code:find('t%.name:lower%(%)') == nil)
    check("🚨 SOURCE: matchTeam is the one matcher the resolver calls",
          code:find("M%.matchTeam%(") ~= nil)
    -- 🔐 secret.lua's rule, asserted rather than trusted: the token is a
    -- header value, never a URL and never an argument list.
    check("🔐 SOURCE: the token never reaches a URL",
          code:find('%.%. core%.asanaToken') == nil
          or code:find('Bearer " %.%. core%.asanaToken') ~= nil)
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then os.exit(1) end
