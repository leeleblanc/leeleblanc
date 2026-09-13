-- =====================================================================
-- core/changelog_csv.lua — the release notes, Excel-ready. 6.77.0
-- =====================================================================
-- One row per version in <logs>/changelog.csv, appended on the first
-- boot of a new version.
--
-- 🚨 IT WAS STUCK ON 6.63.0 FOR THIRTEEN RELEASES. The version, the date
-- and the entire notes paragraph were hard-coded in init.lua, so keeping
-- the CSV honest meant remembering to retype a wall of prose into a Lua
-- string every release — and the moment that was forgotten, the file
-- quietly stopped describing the config while continuing to look like it
-- did. That is a rule 7 failure with no error to notice: nothing throws,
-- the boot line is green, and the record is thirteen versions stale.
--
-- Now it reads _G.configVersion and lifts that version's entry straight
-- out of CHANGELOG.md, which the suite already forces to contain every
-- entry that is inline in init.lua. There is nothing left to keep in
-- step, so there is nothing left to forget — and a MISSING entry is
-- reported rather than written as a blank row.
--
-- ⏱ On the boot path on purpose, and cheap on purpose: the CHANGELOG.md
-- read happens only when this version is not already in the CSV, i.e.
-- once per release, and the existence check that guards it is a read the
-- old version did anyway.
-- =====================================================================

return function(core)

local changelogFile = core.logsDir .. "/changelog.csv"
local version = _G.configVersion

local probe = io.open(changelogFile, "r")
if probe then
    local content = probe:read("*a"); probe:close()
    if content:find(version, 1, true) then return end
end

local md = io.open(hs.configdir .. "/CHANGELOG.md", "r")
local notes = md and md:read("*a") or nil
if md then md:close() end
notes = notes and notes:match("\nNEW IN " .. version:gsub("%.", "%%.")
                              .. "(.-)\nNEW IN ")
if not notes then
    print("📝 Changelog: no CHANGELOG.md entry for " .. version
          .. " — the CSV was NOT written. Add one and reload.")
    return
end
notes = notes:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")

local out = io.open(changelogFile, "a")
if not out then
    print("📝 Changelog: could not write " .. changelogFile)
    return
end
if not probe then out:write("Date,Version,Change notes\n") end
out:write(core.csvQuote(os.date("%m-%d-%y")) .. "," .. core.csvQuote(version)
          .. "," .. core.csvQuote(notes) .. "\n")
out:close()
print("📝 Changelog: " .. version .. " → " .. changelogFile)

end
