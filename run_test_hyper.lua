dofile("/tmp/claude-0/-home-user-leeleblanc/ba31b659-abb1-5eea-86c2-26b0bf67ba0f/scratchpad/hs_mock.lua")

-- Capture what hs.task is asked to run, so we can verify the hidutil
-- remap command is EXACTLY right — a wrong HID code would silently
-- remap the wrong key on a real Mac, which no syntax check would catch.
TEST.launchedTasks = {}
local realTaskNew = hs.task.new
hs.task.new = function(path, cb, args)
    table.insert(TEST.launchedTasks, { path = path, args = args, cb = cb })
    return realTaskNew(path, cb, args)
end

local INIT_PATH = os.getenv("INIT_PATH") or "/root/.claude/uploads/ba31b659-abb1-5eea-86c2-26b0bf67ba0f/6b22eae3-init.lua"
local ok, err = pcall(dofile, INIT_PATH)
if not ok then print("LOAD FAILED: " .. tostring(err)); os.exit(1) end
print("=== init.lua loaded without error ===\n")

-- ---------------------------------------------------------------------
-- A. The Caps Lock -> F18 remap (unchanged since 6.17.0)
-- ---------------------------------------------------------------------
local remap = nil
for _, t in ipairs(TEST.launchedTasks) do
    if t.path == "/usr/bin/hidutil" then remap = t end
end
assert(remap, "FAIL: hidutil was never invoked — the Caps Lock remap would never happen")
assert(remap.args[1] == "property" and remap.args[2] == "--set",
    "FAIL: wrong hidutil subcommand: " .. table.concat(remap.args, " "))
local payload = remap.args[3]
assert(payload:find("0x700000039", 1, true), "FAIL: source HID code (Caps Lock 0x700000039) missing")
assert(payload:find("0x70000006D", 1, true), "FAIL: destination HID code (F18 0x70000006D) missing")
assert(remap.cb ~= nil, "FAIL: hidutil call has no async callback — is it blocking the main thread?")
print("PASS: Caps Lock -> F18 remap issued asynchronously with correct HID codes")

local f18 = nil
for _, h in ipairs(TEST.capturedHotkeys) do
    if h.key == "F18" then f18 = h end
end
assert(f18, "FAIL: F18 was never bound — the hyper key would do nothing")
assert(type(f18.releasedFn) == "function", "FAIL: F18 has no RELEASED function — hyper would latch on forever")
local modal = _G.hyperModal
assert(modal, "FAIL: _G.hyperModal missing")
f18.fn()
assert(modal.entered == true, "FAIL: pressing F18 did not enter the hyper modal")
f18.releasedFn()
assert(modal.entered == false, "FAIL: releasing F18 did not exit the hyper modal")
print("PASS: hold enters hyper, release exits it (no latching)")

-- ---------------------------------------------------------------------
-- B. 6.19.0 — EVERY shortcut migrated onto Caps Lock
-- ---------------------------------------------------------------------

-- 1. The strongest possible check that the migration is complete: after
--    load, the ONLY thing still registered as a global system hotkey
--    should be F18 itself. Anything else means a shortcut never moved.
-- F18 is the hyper trigger. App Lock's panic key (⇪⇧H) is now in the
-- hyper modal, but unclaimed hyper keys forward the raw chord, so it
-- works even if the modal is wedged.
local intentionalGlobals = { F18 = true }
local strays = {}
for _, h in ipairs(TEST.capturedHotkeys) do
    if not intentionalGlobals[h.key] then
        local m = {}
        for _, x in ipairs(h.mods or {}) do table.insert(m, tostring(x):lower()) end
        table.sort(m)
        table.insert(strays, table.concat(m, "+") .. "+" .. tostring(h.key):lower())
    end
end
assert(#strays == 0,
    "FAIL: these shortcuts are STILL global instead of on Caps Lock: " ..
    table.concat(strays, "  "))
print("PASS: no global shortcuts left — F18 is the only system hotkey")

-- 2. Every entry in the §0.4 map must have matched a real bind call. An
--    orphan means a typo'd combo, and that feature silently keeps its
--    OLD key — the single most likely way this refactor breaks quietly.
local orphans = {}
for combo in pairs(_G.hyperKeyMap) do
    if not _G.hyperMigrationsSeen[combo] then table.insert(orphans, combo) end
end
table.sort(orphans)
assert(#orphans == 0,
    "FAIL: " .. #orphans .. " map entries never matched a real shortcut: " ..
    table.concat(orphans, "  "))
local mapCount = 0
for _ in pairs(_G.hyperKeyMap) do mapCount = mapCount + 1 end
assert(_G.hyperShortcutCount == mapCount,
    "FAIL: " .. mapCount .. " mappings declared but " ..
    tostring(_G.hyperShortcutCount) .. " were bound")
print("PASS: all " .. mapCount .. " mapped shortcuts migrated, zero orphans")

-- 3. Nothing may land on the same hyper combo twice — the user named
--    "conflicting assigned keys" as a failure condition outright.
assert(_G.hyperConflictCount == 0,
    "FAIL: " .. tostring(_G.hyperConflictCount) .. " hyper combos are double-bound")
print("PASS: zero hyper conflicts across " .. _G.hyperBoundCount .. " bindings")

-- 4. Spot-check the layout actually landed where it was designed to.
local tier1 = {
    a = "format Asana URL", b = "browse teams", c = "comment on task",
    t = "create task",      l = "list tasks",  v = "clipboard history",
    o = "OCR search",       ["0"] = "activity tracker",
    f = "file tracker",     u = "update tracker",
    s = "autocorrect toggle", z = "autocorrect undo",
    left = "left half",     right = "right half",
    up = "fill screen",     down = "restore frame",
    ["\\"] = "split",       w = "app jump",
    ["["] = "monitor left", ["]"] = "monitor right",
    ["/"] = "cheat sheet",  ["="] = "add entry",
    ["-"] = "remove entry", e = "edit entry", p = "app peek",
}
local missing = {}
for k, what in pairs(tier1) do
    if type(modal.bindings[k]) ~= "function" then
        table.insert(missing, k .. " (" .. what .. ")")
    end
end
assert(#missing == 0, "FAIL: tier-1 keys not bound: " .. table.concat(missing, ", "))
print("PASS: all 25 tier-1 shortcuts bound on bare ⇪")

local tier2 = { "shift+v", "shift+o", "shift+c", "shift+r",
                "shift+up", "shift+down", "shift+left", "shift+right" }
for _, c in ipairs(tier2) do
    assert(type(modal.bindings[c]) == "function", "FAIL: ⇪" .. c .. " not bound")
end
print("PASS: all " .. #tier2 .. " tier-2 (⇪⇧) shortcuts bound")

-- 5. The five app launchers 6.17.0 invented were never asked for and are
--    gone. They used to sit on t/c/o/s/m, where real tools now live.
for _, c in ipairs({ "alt+t", "alt+c", "alt+o", "alt+m", "alt+s" }) do
    assert(modal.bindings[c] == nil,
        "FAIL: app launcher ⇪" .. c .. " is back — it was removed in 6.19.0")
end
assert(_G.hyperApps == nil, "FAIL: hyperApps still exists")
local launched = 0
for _, t in ipairs(TEST.launchedTasks) do
    if t.path == "/usr/bin/open" then launched = launched + 1 end
end
assert(launched == 0, "FAIL: something still launches apps at boot")
print("PASS: the five invented app launchers are gone")

-- ---------------------------------------------------------------------
-- C. Chord forwarding still works for keys no shortcut claimed
-- ---------------------------------------------------------------------
TEST.sentKeyStrokes = {}
local fn = modal.bindings["k"]
assert(type(fn) == "function", "FAIL: unclaimed key 'k' forwards nothing")
fn()
assert(#TEST.sentKeyStrokes == 1, "FAIL: ⇪k sent " .. #TEST.sentKeyStrokes .. " keystrokes, expected 1")
local ks = TEST.sentKeyStrokes[1]
assert(ks.key == "k", "FAIL: ⇪k forwarded the wrong key: " .. tostring(ks.key))
local got = {}
for _, m in ipairs(ks.mods) do got[m] = true end
for _, need in ipairs({ "cmd", "shift", "ctrl", "alt" }) do
    assert(got[need], "FAIL: forwarded chord is missing '" .. need .. "'")
end
assert(#ks.mods == 4, "FAIL: chord has " .. #ks.mods .. " modifiers, expected 4")
assert(type(ks.delay) == "number" and ks.delay < 50000,
    "FAIL: keystroke delay would fall back to the laggy 200ms default")
print("PASS: unclaimed keys still forward exactly ⌘⇧⌃⌥+key (" .. _G.hyperForwardCount .. " of them)")

-- A claimed key must NOT also forward the chord, or the shortcut would
-- fire and then leak a stray ⌘⇧⌃⌥ keystroke into the app underneath.
TEST.sentKeyStrokes = {}
modal:enter()
pcall(modal.bindings["p"])
assert(#TEST.sentKeyStrokes == 0,
    "FAIL: ⇪P ran its action AND forwarded a chord — the app would receive a stray keystroke")
modal:exit()
print("PASS: claimed keys run their action only, no stray chord")

-- ---------------------------------------------------------------------
-- D. Regression guards
-- ---------------------------------------------------------------------
-- 6.18.1: bare F-keys must stay unbound. macOS reserves some of them
-- (F11 = Show Desktop), and registering one fails with -9878 on EVERY
-- Caps Lock press, forever.
local fbound = {}
for n = 1, 12 do
    if modal.bindings["f" .. n] ~= nil then table.insert(fbound, "f" .. n) end
end
assert(#fbound == 0,
    "FAIL: bare F-keys bound again (" .. table.concat(fbound, " ") ..
    ") — this re-creates the -9878 Console spam")
print("PASS: bare F-keys not registered — no RegisterEventHotKey -9878 spam")

-- Popup nudging is press-and-hold; losing the repeat handler would make
-- it move once per tap instead of walking.
local nudge = modal.bindingDetail["shift+left"]
assert(nudge and type(nudge.repeated) == "function",
    "FAIL: ⇪⇧← lost its repeat handler — nudging would no longer hold-to-walk")
print("PASS: hold-to-repeat preserved through the migration")

print("\n=== ALL ASSERTIONS PASSED ===")
