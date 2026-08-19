dofile("/tmp/claude-0/-home-user-leeleblanc/ba31b659-abb1-5eea-86c2-26b0bf67ba0f/scratchpad/hs_mock.lua")

-- App Lock is the one feature here that can lock the USER out of their
-- own Mac if it misbehaves. These tests weight heavily toward the
-- fail-safe paths, not the happy path.

TEST.launchedTasks = {}
local realTaskNew = hs.task.new
hs.task.new = function(path, cb, args)
    local rec = { path = path, args = args, cb = cb }
    table.insert(TEST.launchedTasks, rec)
    return realTaskNew(path, cb, args)
end

-- Seed a known PIN (1234) before init loads, so the tests can exercise
-- the parts that legitimately refuse to work without one. Written by
-- hand rather than through the config, so the on-disk format itself is
-- part of what's under test. NOTE: apps is empty — test 1 still proves
-- nothing gets locked just because a PIN exists.
do
    local f = io.open(TEST.baseDir .. "/applock.json", "w")
    f:write('{"salt":"testsalt","hash":"' .. hs.hash.SHA256("testsalt:1234") .. '","apps":{}}')
    f:close()
end

local INIT_PATH = os.getenv("INIT_PATH") or "/root/.claude/uploads/ba31b659-abb1-5eea-86c2-26b0bf67ba0f/6b22eae3-init.lua"
local ok, err = pcall(dofile, INIT_PATH)
if not ok then print("LOAD FAILED: " .. tostring(err)); os.exit(1) end
print("=== init.lua loaded without error ===\n")

-- 1. Nothing may be locked out of the box. Shipping a config that starts
--    locking apps on install would be hostile.
assert(_G.appLockCountForTest() == 0,
    "FAIL: " .. _G.appLockCountForTest() .. " apps are locked by default — must be zero")
print("PASS: nothing is locked by default")

-- 2. Hammerspoon can NEVER be locked. If it could, the escape hatch
--    (Console, reload, editing init.lua) would be behind the lock.
assert(_G.appLockNeverLockForTest["Hammerspoon"] == true,
    "FAIL: Hammerspoon is not on the never-lock list")
assert(_G.appLockIsLockedForTest("Hammerspoon") == false,
    "FAIL: Hammerspoon reports as lockable")
print("PASS: Hammerspoon can never be locked — Console stays reachable")

-- 3. The PIN must never be stored in the clear, and must be salted so
--    the same PIN on two machines doesn't produce the same hash.
local h1 = _G.appLockHashForTest("1234", "saltA")
local h2 = _G.appLockHashForTest("1234", "saltB")
local h3 = _G.appLockHashForTest("9999", "saltA")
assert(not h1:find("1234", 1, true), "FAIL: the PIN appears in its own hash")
assert(h1 ~= h2, "FAIL: salt is not affecting the hash")
assert(h1 ~= h3, "FAIL: different PINs produce the same hash")
assert(#h1 >= 16, "FAIL: hash is suspiciously short: " .. h1)
print("PASS: PIN is salted and hashed, never stored in the clear")

-- 4. PIN verification must accept the right PIN and reject everything
--    else — including the empty string, which is what a cancelled or
--    failed prompt produces.
assert(_G.appLockCheckPinForTest("1234") == true,
    "FAIL: the correct PIN was rejected")
assert(_G.appLockCheckPinForTest("9999") == false, "FAIL: a wrong PIN was accepted")
assert(_G.appLockCheckPinForTest("") == false, "FAIL: an empty PIN was accepted")
assert(_G.appLockCheckPinForTest("1234 ") == false, "FAIL: PIN matching is not exact")
print("PASS: PIN verification accepts only the exact PIN")

-- 5. The prompt must never block Hammerspoon's main thread.
local src = io.open(INIT_PATH):read("*a")
-- Non-greedy: a greedy .* would run past this section to the LAST
-- "7. BOOTSTRAP" in the file, dragging in unrelated code that legitimately
-- uses blocking dialogs and failing for the wrong reason.
-- Bounded by the section's OWN terminator, not by whatever section
-- happens to follow it. "up to 7. BOOTSTRAP" quietly swallowed the
-- experimental Document Watcher when that was added between them, and
-- this test started reporting App Lock bugs that belonged to other code.
local lockSection = src:match("6%.6 APP LOCK(.-)end%)%(%) %-%- \194\1676%.6 App Lock") or ""
assert(lockSection ~= "", "FAIL: could not isolate the App Lock section to inspect it")

-- Check CODE, not prose: the comments name the rejected APIs on purpose.
local lockCode = {}
for line in lockSection:gmatch("[^\n]*") do
    if not line:match("^%s*%-%-") then table.insert(lockCode, line) end
end
lockCode = table.concat(lockCode, "\n")

assert(not lockCode:find("hs%.dialog%.textPrompt"),
    "FAIL: App Lock uses hs.dialog.textPrompt — that blocks the main thread")
assert(not lockCode:find("hs%.osascript%.applescript"),
    "FAIL: App Lock uses hs.osascript.applescript — that blocks the main thread")
print("PASS: no blocking dialog API — cannot beachball Hammerspoon")

-- 6. 6.23.0: the prompt must be a CHOOSER shown via showPopup, not an
--    osascript dialog. osascript has no Dock presence, so it could not
--    take focus, ⌘-Tab could not reach it, window tools could not see
--    it, and it ignored the active monitor.
assert(not lockCode:find("/usr/bin/osascript", 1, true),
    "FAIL: still using an osascript dialog — it can't focus or follow your active screen")
assert(lockCode:find("showPopup(_G.choosers.appLockPin)", 1, true),
    "FAIL: the PIN prompt is not shown through showPopup, so it won't land on the active screen")
print("PASS: PIN prompt is a chooser placed on the active screen")

-- 7. The PIN must be MASKED, and the masking must not be able to recurse.
local pinChooser = _G.appLockPinChooserForTest()
assert(pinChooser, "FAIL: no PIN chooser exists")
assert(type(pinChooser.queryChangedFn) == "function",
    "FAIL: PIN chooser has no queryChanged handler, so nothing masks the input")
pinChooser.queryChangedFn("1")
pinChooser.queryChangedFn("•2")
pinChooser.queryChangedFn("••3")
pinChooser.queryChangedFn("•••4")
assert(_G.appLockPinBufferForTest() == "1234",
    "FAIL: typed PIN not reconstructed — got [" .. tostring(_G.appLockPinBufferForTest()) .. "]")
assert(pinChooser.lastQuery == "••••",
    "FAIL: the field shows [" .. tostring(pinChooser.lastQuery) .. "] instead of bullets — PIN is visible")
local shown = pinChooser.lastChoices[1]
assert(shown and not tostring(shown.text):find("1234", 1, true),
    "FAIL: the PIN is rendered in the row text")
pinChooser.queryChangedFn("•••")            -- backspace
assert(_G.appLockPinBufferForTest() == "123",
    "FAIL: backspace did not shorten the buffer")
assert(lockCode:find("pinSettingQuery", 1, true),
    "FAIL: no re-entrancy guard — a self-firing query() would hang Hammerspoon")
print("PASS: PIN is masked, reconstructed correctly, and cannot recurse")

-- 8. The PIN file must be local-only and excluded from the cloud backup,
--    exactly like secret.lua.
assert(_G.appLockFileForTest:find(TEST.baseDir, 1, true),
    "FAIL: PIN file is not in hs.configdir — it must never live in OneDrive")
assert(src:find("%-%-exclude 'applock%.json'"),
    "FAIL: applock.json is not excluded from the rsync backup")
print("PASS: PIN file is machine-local and excluded from backups")

-- 9. The watcher must ignore events it doesn't care about. `activated`
--    fires constantly; anything expensive on that path is a stall.
local watcher = nil
for _, w in ipairs(TEST.capturedAppWatchers) do watcher = w end
assert(watcher, "FAIL: no application watcher registered")
assert(lockCode:find("hs%.application%.watcher%.activated"),
    "FAIL: App Lock does not watch the activated event — apps already running would bypass it")
assert(lockCode:find("hs%.application%.watcher%.launched"),
    "FAIL: App Lock does not watch the launched event")
print("PASS: watcher covers both launch and activation")

-- 10. An unlock must not outlive the screen locking.
assert(lockCode:find("screensDidLock", 1, true),
    "FAIL: unlocks are not cleared when the screen locks")
assert(lockCode:find("systemWillSleep", 1, true),
    "FAIL: unlocks are not cleared on sleep")
print("PASS: unlocks are cleared on screen lock and sleep")

-- 11. Registering the manager shortcut must not have collided with
--     anything, and must not have stolen a key from another feature.
assert(_G.hyperConflictCount == 0,
    "FAIL: adding App Lock introduced " .. tostring(_G.hyperConflictCount) .. " hyper conflicts")
local modal = _G.hyperModal
assert(type(modal.bindings["shift+l"]) == "function",
    "FAIL: ⇪⇧L (App Lock manager) is not bound")
assert(type(modal.bindings["l"]) == "function",
    "FAIL: ⇪L (Asana list) was clobbered by App Lock")
print("PASS: ⇪⇧L bound with no conflicts, ⇪L still intact")

-- 12. A lockout window must exist, or a 4-digit PIN could be tried
--     endlessly at machine speed.
assert(lockCode:find("appLockMaxAttempts", 1, true)
   and lockCode:find("lockoutUntil", 1, true),
    "FAIL: no attempt limit / lockout — unlimited PIN guessing")
print("PASS: wrong-PIN attempts are rate-limited")

-- 13. REGRESSION (6.23.0): the lock / "it says unlocked" / lock rhythm.
-- Every protected app used to have ONE row whose Enter meant "remove
-- from the protected list". So after a PIN unlock, pressing Enter to
-- lock it again silently UN-PROTECTED it: you then re-added it (2nd
-- press) and it locked (3rd). Enter must now flip what the row shows.
TEST.runningApps = { TextEdit = true, Safari = true }
local mgr = _G.choosers.appLock

local function rowFor(choices, appName, action)
    for _, c in ipairs(choices) do
        if c.app == appName and (action == nil or c.action == action) then return c end
    end
    return nil
end

-- Protect TextEdit from the "not protected" row.
local rows = _G.appLockRenderManagerForTest("main")
local protectRow = rowFor(rows, "TextEdit", "protect")
assert(protectRow, "FAIL: no row offers to protect a running, unprotected app")
mgr.callback(protectRow)
assert(_G.appLockCountForTest() == 1, "FAIL: protecting an app did not add it to the list")

-- It is now protected AND locked, so its row must offer to UNLOCK.
rows = _G.appLockRenderManagerForTest("main")
local lockedRow = rowFor(rows, "TextEdit")
assert(lockedRow and lockedRow.action == "unlock",
    "FAIL: a locked app's Enter should unlock it, got action=" .. tostring(lockedRow and lockedRow.action))
assert(not lockedRow.text:find("○"), "FAIL: locked app is not shown as locked")

-- Simulate the PIN unlock, then check the row flips to "lock it again"
-- rather than "remove protection" — the exact 6.22 bug.
_G.appLockUnlockedForTest()["TextEdit"] = true
rows = _G.appLockRenderManagerForTest("main")
local unlockedRow = rowFor(rows, "TextEdit")
assert(unlockedRow and unlockedRow.action == "lock",
    "FAIL: after unlocking, Enter does '" .. tostring(unlockedRow and unlockedRow.action) ..
    "' instead of re-locking — this is the lock/unlock/lock bug")

-- And pressing it must re-lock immediately, not un-protect.
TEST.hiddenApps, TEST.hideCalls = {}, {}
mgr.callback(unlockedRow)
assert(_G.appLockUnlockedForTest()["TextEdit"] == nil, "FAIL: Enter did not re-lock the app")
assert(_G.appLockCountForTest() == 1,
    "FAIL: re-locking removed the app from protection — the 6.22 bug is back")
assert(TEST.hiddenApps["TextEdit"], "FAIL: re-locking did not hide the app")
print("PASS: Enter flips lock<->unlock and never silently un-protects")

-- 14. Un-protecting must require the PIN and live behind its own mode.
-- Without this, anyone could open ⇪⇧L and remove the lock in one
-- keypress, making the whole feature decorative.
rows = _G.appLockRenderManagerForTest("main")
local hasRemoveMode = false
for _, c in ipairs(rows) do if c.action == "removemode" then hasRemoveMode = true end end
assert(hasRemoveMode, "FAIL: no separate 'stop protecting' entry point")

local removeRows = _G.appLockRenderManagerForTest("remove")
local unprotectRow = rowFor(removeRows, "TextEdit", "unprotect")
assert(unprotectRow, "FAIL: remove mode does not list protected apps")

local unprotectBranch = lockCode:match('elseif c%.action == "unprotect"(.-)elseif') or ""
assert(unprotectBranch ~= "", "FAIL: no unprotect branch found")
assert(unprotectBranch:find("appLockAskPin", 1, true)
   and unprotectBranch:find("appLockCheckPin", 1, true),
    "FAIL: un-protecting an app does not require the PIN — the lock would be decorative")
print("PASS: un-protecting is PIN-gated and behind its own mode")
_G.appLockRenderManagerForTest("main")

-- ---------------------------------------------------------------------
-- 6.22.0 — the two things that were actually broken in use
-- ---------------------------------------------------------------------

-- 15. THE REAL BUG: locking an app that is ALREADY OPEN must hide it now.
-- 6.21 only reacted to launch/activate, so locking the app in front of
-- you did visibly nothing and you could keep typing in it.
TEST.runningApps = { TextEdit = true, Finder = true }
TEST.hiddenApps, TEST.hideCalls = {}, {}
local hid = _G.appLockHideAppForTest("TextEdit")
assert(hid, "FAIL: hiding an already-running app reported failure")
assert(TEST.hiddenApps["TextEdit"], "FAIL: TextEdit was never actually hidden")
assert(not TEST.hiddenApps["Finder"], "FAIL: hid an app that was not asked for")
print("PASS: locking an already-open app hides it immediately")

-- 16. The hide must be wired into the manager's PROTECT and LOCK
--     branches, not just exist as a function nobody calls — which is
--     exactly how the 6.21 bug shipped.
for _, branch in ipairs({ "protect", "lock" }) do
    local code = lockCode:match('elseif c%.action == "' .. branch .. '"(.-)elseif') or ""
    assert(code ~= "", "FAIL: could not find the manager's '" .. branch .. "' branch")
    assert(code:find("appLockHideApp", 1, true),
        "FAIL: the '" .. branch .. "' action does not hide the app — the 6.21 bug is back")
end
print("PASS: both protect and lock actually hide the app")

-- 17. NO TIMER. The 15-minute expiry was never asked for.
assert(not lockCode:find("appLockGraceMinutes", 1, true),
    "FAIL: the grace-period timer is still present")
assert(not lockCode:find("unlockedUntil", 1, true),
    "FAIL: unlocks are still expiry-based rather than manual")
local unlockedTable = _G.appLockUnlockedForTest()
assert(type(unlockedTable) == "table", "FAIL: unlock state is not a plain set")
print("PASS: no unlock timer — unlock is a plain on/off state")

-- 18. Nothing may re-lock on its own by default. The user asked for
--     manual control; automatic re-locking ships OFF.
assert(lockCode:find("appLockRelockOnScreenLock", 1, true),
    "FAIL: no explicit flag controlling automatic re-locking")
assert(src:find("local appLockRelockOnScreenLock = false", 1, true),
    "FAIL: automatic re-lock on screen lock is not OFF by default")
print("PASS: automatic re-locking exists but is off by default")

-- 19. A failed hide must be reported, not swallowed. The old bare pcall
--     made a lock that did nothing look identical to one that worked.
assert(lockCode:find("could not hide", 1, true),
    "FAIL: hide() failures are still silent")
print("PASS: hide() failures are reported to the Console")

-- 20. "Re-lock everything now" must actually hide the running locked apps.
assert(lockCode:find("appLockHideAllLocked", 1, true),
    "FAIL: re-lock-everything does not hide anything")
print("PASS: re-lock everything hides running locked apps")

-- ---------------------------------------------------------------------
-- 6.24.0 — the strobe / beachball feedback loop
-- ---------------------------------------------------------------------
-- Hiding an app changes focus; a focus change fires another `activated`;
-- closing the PIN chooser hands focus back to the app we just hid. That
-- is a closed loop. In 6.23 it ran flat out: holding ⌘-Tab strobed the
-- screen between the app and Hammerspoon and pinned the main thread for
-- ~5 seconds. These tests drive the loop directly.

-- Find the App Lock watcher (the last one registered; App Monitor also
-- registers one, and matching the wrong one would test nothing).
local lockWatcher = nil
for _, w in ipairs(TEST.capturedAppWatchers) do
    if type(w.callback) == "function" then lockWatcher = w end
end
assert(lockWatcher, "FAIL: App Lock registered no application watcher")

-- 6.25.0: the challenge hides the app, then waits 0.15s to CONFIRM it
-- actually went away (macOS can finish unhiding after our hide) before
-- showing the prompt. Nothing fires timers in this harness, so drive
-- them by hand — otherwise the prompt never opens and every assertion
-- below would be testing a half-finished state.
-- 6.25.1 polls every 30ms until the app has STAYED hidden for a few
-- consecutive checks, so this must keep firing timers until the chain
-- ends — a single pass would stop partway and the prompt would never
-- open.
local function flushAppLockTimers()
    local fired = 0
    for _ = 1, 60 do
        local pending = {}
        for _, t in ipairs(TEST.capturedDoAfter) do
            if t.delay == 0.03 and not t.__fired then
                t.__fired = true
                table.insert(pending, t.fn)
            end
        end
        if #pending == 0 then break end
        for _, fn in ipairs(pending) do pcall(fn); fired = fired + 1 end
    end
    return fired
end

-- TextEdit is protected and locked from the earlier tests.
_G.appLockUnlockedForTest()["TextEdit"] = nil
_G.appLockClearCooldownForTest()
TEST.hiddenApps, TEST.hideCalls = {}, {}
TEST.runningApps = { TextEdit = true }

-- 21a. Holding ⌘-Tab fires a burst of activations for the same locked
--      app. Exactly ONE hide may result. In 6.23 the watcher hid the app
--      BEFORE checking whether a prompt was already open, so every event
--      in the burst hid again — 25 hides, 25 focus changes, strobe.
local app = TEST.makeApp("TextEdit")
for _ = 1, 25 do
    lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
end
assert(#TEST.hideCalls == 1,
    "FAIL: " .. #TEST.hideCalls .. " hide() calls from one burst of activations" ..
    " — this is the strobe (expected exactly 1)")
flushAppLockTimers()   -- let the confirm-hidden step run and open the prompt
print("PASS: a burst of 25 activations while prompting produces exactly one hide")

-- 21b. The other half of the loop: once the prompt CLOSES, focus returns
--      to the app we hid, firing another activation. What must be
--      suppressed is the PROMPT — the app must still be hidden each time.
_G.appLockPinChooserForTest().callback(nil)   -- Esc
TEST.hideCalls = {}
local promptsBefore = _G.appLockPromptCountForTest()
for _ = 1, 25 do
    lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
end
assert(_G.appLockPromptCountForTest() == promptsBefore,
    "FAIL: the PIN prompt reopened during the cooldown — that is the loop")
print("PASS: no prompt reopens during the cooldown")

-- 21c. THE HOLE 6.24.0 OPENED. Its cooldown check sat ABOVE the hide, so
--      the handler bailed out entirely — and a locked app clicked within
--      those 2 seconds came back on screen with NO PIN. Hiding must
--      happen on EVERY activation, cooldown or not.
assert(#TEST.hideCalls == 25,
    "FAIL: only " .. #TEST.hideCalls .. "/25 activations hid the app — during a" ..
    " cooldown a locked app could be reopened with no PIN at all")
print("PASS: a locked app is hidden on every activation, cooldown or not")
-- 22. 6.22's retry fired a timer on EVERY activation, so a ⌘-Tab burst
--     queued dozens of re-hides — that was the strobe. 6.25 re-verifies
--     too, but ONCE per challenge. Assert the burst above queued at most
--     one, which is the distinction that matters.
assert(not lockCode:find("appLockHideTimers", 1, true),
    "FAIL: 6.22's per-event re-hide retry is back — it is the strobe engine")
-- The poll is a CHAIN (one timer alive at a time), so what matters is
-- that a 25-event burst didn't start 25 independent chains.
local liveTimers = #_G.appLockVerifyTimersForTest()
assert(liveTimers <= 1,
    "FAIL: " .. liveTimers .. " verify chains running at once — that is per-event, not per-challenge")
print("PASS: the confirm-hidden poll runs once per challenge, not per event")

-- 23. While a PIN prompt is open, further activations must do NOTHING —
--     the app is already hidden, and touching it only moves focus again.
_G.appLockClearCooldownForTest()
TEST.hideCalls = {}
-- Re-open a prompt (the cooldown was just cleared, so this engages).
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
flushAppLockTimers()
_G.appLockClearCooldownForTest()
TEST.hideCalls = {}
for _ = 1, 10 do
    lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
end
assert(#TEST.hideCalls == 0,
    "FAIL: " .. #TEST.hideCalls .. " hides while a prompt was open — the loop is still live")
print("PASS: activations during an open PIN prompt are ignored")

-- 24. Events for apps that are not locked must cost nothing at all.
TEST.hideCalls = {}
local safari = TEST.makeApp("Safari")
for _ = 1, 50 do
    lockWatcher.callback("Safari", hs.application.watcher.activated, safari)
end
assert(#TEST.hideCalls == 0, "FAIL: an unprotected app got hidden")
assert(not TEST.hiddenApps["Safari"], "FAIL: Safari was hidden")
print("PASS: unprotected apps are untouched by the watcher")

-- 25. Once the prompt is dismissed and the cooldown lapses, a genuine
--     later switch must PROMPT again — damping must not quietly turn
--     into "the lock stopped working", which is exactly how it looked.
_G.appLockPinChooserForTest().callback(nil)   -- Esc
_G.appLockClearCooldownForTest()
TEST.hideCalls = {}
local before25 = _G.appLockPromptCountForTest()
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
flushAppLockTimers()
assert(#TEST.hideCalls == 1, "FAIL: the app was not hidden")
assert(_G.appLockPromptCountForTest() == before25 + 1,
    "FAIL: no PIN prompt after the cooldown lapsed — the lock stopped working")
print("PASS: the lock re-engages and re-prompts once the cooldown lapses")

-- 26. promptOpen must never be able to stick. If the chooser closes
--     without its completion running, the watcher's early return on
--     promptOpen would silently disable App Lock until a reload — an
--     invisible failure, and a plausible cause of "works one time".
assert(_G.appLockPromptOpenForTest() == true, "FAIL: expected a prompt to be open now")
assert(src:find("hideCallback", 1, true),
    "FAIL: no hideCallback safety net — a stuck prompt would disable App Lock silently")
assert(lockCode:find("closed without reporting", 1, true),
    "FAIL: the stuck-prompt recovery does not announce itself in the Console")
print("PASS: an abnormally closed prompt is recovered, not left stuck")

-- ---------------------------------------------------------------------
-- 6.25.0 — the app must never be reachable without the PIN
-- ---------------------------------------------------------------------

-- 27. THE ESCAPE HOLE. Clicking a hidden app's Dock icon makes macOS
--     unhide AND activate it; our hide() lands mid-unhide and macOS
--     finishes the unhide afterwards, leaving the app VISIBLE behind the
--     prompt. Pressing Esc then just closed the prompt and handed the
--     app over with no PIN.
_G.appLockClearCooldownForTest()
_G.appLockPinChooserForTest().callback(nil)      -- clear any open prompt
_G.appLockClearCooldownForTest()
TEST.hiddenApps, TEST.hideCalls = {}, {}
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
assert(TEST.hiddenApps["TextEdit"], "FAIL: the app was not hidden on activation")
-- macOS finishes its unhide AFTER our hide — the race.
TEST.hiddenApps["TextEdit"] = nil
flushAppLockTimers()
assert(TEST.hiddenApps["TextEdit"],
    "FAIL: the app was left VISIBLE behind the PIN prompt — its contents are readable")
print("PASS: the macOS unhide race is caught before the prompt appears")

-- Now Esc. The app must go back into hiding, not be handed over.
TEST.hiddenApps["TextEdit"] = nil                 -- app visible again
_G.appLockPinChooserForTest().callback(nil)       -- Esc
assert(TEST.hiddenApps["TextEdit"],
    "FAIL: pressing Esc left the app on screen — you can walk straight in without a PIN")
print("PASS: cancelling the prompt re-hides the app")

-- 28. A WRONG PIN must not hand the app over either.
_G.appLockClearCooldownForTest()
TEST.hiddenApps, TEST.hideCalls = {}, {}
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
flushAppLockTimers()
TEST.hiddenApps["TextEdit"] = nil                 -- pretend it is visible
_G.appLockPinChooserForTest().callback({ text = "row" })   -- submits empty buffer
assert(TEST.hiddenApps["TextEdit"],
    "FAIL: a failed unlock left the app visible")
assert(_G.appLockUnlockedForTest()["TextEdit"] ~= true,
    "FAIL: a failed unlock marked the app unlocked")
print("PASS: a failed unlock re-hides the app and does not unlock it")

-- 29. THE LATE UNHIDE (6.25.1). macOS may finish unhiding AFTER our
--     first check. 6.25.0 looked exactly once, 150ms in — so a late
--     unhide sailed straight past it, and the app sat visible for that
--     whole 150ms besides (the flash on Dock clicks). The poll must keep
--     watching until the app has STAYED hidden.
local function stepOneTick()
    for _, t in ipairs(TEST.capturedDoAfter) do
        if t.delay == 0.03 and not t.__fired then
            t.__fired = true
            pcall(t.fn)
            return true
        end
    end
    return false
end

-- Drain every timer left over from the tests above FIRST. Without this,
-- an old chain still holding a closure over TextEdit fires during the
-- flush below and re-hides the app — which made this test pass even with
-- the polling disabled. It was measuring leftovers, not the poll.
flushAppLockTimers()
_G.appLockClearCooldownForTest()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockClearCooldownForTest()
TEST.hiddenApps, TEST.hideCalls = {}, {}
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
assert(TEST.hiddenApps["TextEdit"], "FAIL: not hidden on activation")

stepOneTick()                        -- first check: looks hidden, all fine
TEST.hiddenApps["TextEdit"] = nil    -- ...and NOW macOS finishes unhiding
flushAppLockTimers()                 -- the poll must notice and re-hide
assert(TEST.hiddenApps["TextEdit"],
    "FAIL: an unhide that lands after the first check was missed — the app" ..
    " would sit visible behind the prompt")
print("PASS: an unhide arriving after the first check is still caught")

-- 30. The poll must be bounded. An app that refuses to stay hidden must
--     not spin timers forever — it should give up and prompt anyway.
_G.appLockClearCooldownForTest()
_G.appLockPinChooserForTest().callback(nil)
_G.appLockClearCooldownForTest()
TEST.hiddenApps, TEST.hideCalls = {}, {}
local stubborn = TEST.makeApp("TextEdit")
stubborn.isHidden = function() return false end   -- never stays hidden
local promptsBefore30 = _G.appLockPromptCountForTest()
lockWatcher.callback("TextEdit", hs.application.watcher.activated, stubborn)
local ticks = flushAppLockTimers()
assert(ticks < 40, "FAIL: the verify poll ran " .. ticks .. " times — it is unbounded")
assert(_G.appLockPromptCountForTest() == promptsBefore30 + 1,
    "FAIL: an app that won't stay hidden never got a PIN prompt at all")
assert(#_G.appLockVerifyTimersForTest() == 0, "FAIL: verify timers left running")
print("PASS: the poll gives up after a bounded number of tries and still prompts")

-- ---------------------------------------------------------------------
-- 6.26.0 — re-lock when you switch away
-- ---------------------------------------------------------------------
-- The reason App Lock kept looking like it "worked once and then
-- degraded": a PIN unlocked the app permanently, so every later switch
-- correctly did nothing. Event-driven re-locking makes it behave like a
-- lock without introducing any timer.

flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockClearCooldownForTest()

-- 31. OFF by default — nothing automatic unless it is asked for.
assert(_G.appLockRelockOnLeaveForTest() == false,
    "FAIL: re-lock-on-switch-away is on by default; it must be opt-in")

-- With it OFF, an unlocked app must STAY unlocked when you leave it.
_G.appLockUnlockedForTest()["TextEdit"] = true
lockWatcher.callback("TextEdit", hs.application.watcher.deactivated, app)
assert(_G.appLockUnlockedForTest()["TextEdit"] == true,
    "FAIL: the app re-locked on switch-away even though the option is off")
print("PASS: with the option off, an unlock survives switching away")

-- 32. Turn it on from the manager — no file editing.
local rows31 = _G.appLockRenderManagerForTest("main")
local toggleRow = nil
for _, c in ipairs(rows31) do
    if c.action == "toggleRelockOnLeave" then toggleRow = c end
end
assert(toggleRow, "FAIL: no manager row to turn re-lock-on-switch-away on")
assert(toggleRow.text:find("OFF", 1, true), "FAIL: the row does not show the current state")
_G.choosers.appLock.callback(toggleRow)
assert(_G.appLockRelockOnLeaveForTest() == true, "FAIL: the toggle did not turn it on")
print("PASS: the option is toggleable from ⇪⇧L and shows its state")

-- 33. With it ON, leaving the app re-locks AND hides it.
TEST.hiddenApps, TEST.hideCalls = {}, {}
_G.appLockUnlockedForTest()["TextEdit"] = true
lockWatcher.callback("TextEdit", hs.application.watcher.deactivated, app)
assert(_G.appLockUnlockedForTest()["TextEdit"] ~= true,
    "FAIL: switching away did not re-lock the app")
assert(TEST.hiddenApps["TextEdit"], "FAIL: the re-locked app was not hidden")
print("PASS: switching away re-locks and hides the app")

-- 34. Coming back must then ask for the PIN again — the whole point.
_G.appLockClearCooldownForTest()
local before34 = _G.appLockPromptCountForTest()
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
flushAppLockTimers()
assert(_G.appLockPromptCountForTest() == before34 + 1,
    "FAIL: returning to a re-locked app did not ask for the PIN")
print("PASS: returning to the app asks for the PIN again")

-- 35. Deactivating an app that is NOT protected must cost nothing.
TEST.hiddenApps = {}
lockWatcher.callback("Safari", hs.application.watcher.deactivated, safari)
assert(not TEST.hiddenApps["Safari"], "FAIL: an unprotected app was hidden on switch-away")
print("PASS: switching away from an unprotected app does nothing")

-- Leave the setting off so a re-run starts from the shipped default.
_G.choosers.appLock.callback({ action = "toggleRelockOnLeave" })

-- ---------------------------------------------------------------------
-- 6.27.0 — only real applications, and the removal row is reachable
-- ---------------------------------------------------------------------
-- The picker listed every running PROCESS: loginwindow, photolibraryd,
-- universalaccessd, siriactionsd, nbagent, printtool… none of them
-- lockable, and they buried the handful of real apps.

-- 36. The daemon filter itself, against the exact names that showed up.
local realApp = TEST.makeApp("TextEdit")
TEST.appPaths["TextEdit"] = "/System/Applications/TextEdit.app"
assert(_G.appLockIsRealAppForTest(realApp), "FAIL: a genuine app was filtered out")

local daemons = {
    { "loginwindow",            0,  "/System/Library/CoreServices/loginwindow.app" },
    { "photolibraryd",         -1,  "/System/Library/PrivateFrameworks/photolibraryd" },
    { "universalaccessd",      -1,  "/usr/libexec/universalaccessd" },
    { "siriactionsd",          -1,  "/System/Library/PrivateFrameworks/siriactionsd" },
    { "nbagent",                0,  "/System/Library/CoreServices/nbagent.app" },
    { "printtool",              0,  "/System/Library/Frameworks/printtool.app" },
}
for _, d in ipairs(daemons) do
    local nm, kind, path = d[1], d[2], d[3]
    TEST.appKinds[nm], TEST.appPaths[nm] = kind, path
    assert(not _G.appLockIsRealAppForTest(TEST.makeApp(nm)),
        "FAIL: OS process '" .. nm .. "' is still offered for locking")
end
print("PASS: OS daemons are filtered out (" .. #daemons .. " real examples)")

-- 37. A helper app buried inside another bundle must not be offered,
--     even though it can legitimately report a Dock icon.
TEST.appKinds["Helper"] = 1
TEST.appPaths["Helper"] = "/Applications/Foo.app/Contents/Library/LoginItems/Helper.app"
assert(not _G.appLockIsRealAppForTest(TEST.makeApp("Helper")),
    "FAIL: a helper nested inside another .app bundle was offered")
print("PASS: helper apps nested inside other bundles are excluded")

-- 38. An app outside the Applications folders is not offered either.
TEST.appKinds["Stray"] = 1
TEST.appPaths["Stray"] = "/Users/someone/Downloads/Stray.app"
assert(not _G.appLockIsRealAppForTest(TEST.makeApp("Stray")),
    "FAIL: an app outside the configured roots was offered")
print("PASS: only apps under the configured Applications folders are offered")

-- 39. End to end: the manager list must contain the real app and none
--     of the daemons.
TEST.runningApps = { TextEdit = true, Safari = true }
for _, d in ipairs(daemons) do TEST.runningApps[d[1]] = true end
TEST.appPaths["Safari"] = "/Applications/Safari.app"
local rows39 = _G.appLockRenderManagerForTest("main")
local listed = {}
for _, c in ipairs(rows39) do if c.app then listed[c.app] = true end end
for _, d in ipairs(daemons) do
    assert(not listed[d[1]], "FAIL: '" .. d[1] .. "' is in the picker")
end
assert(listed["Safari"], "FAIL: a real app is missing from the picker")
print("PASS: the picker lists real apps only")

-- 40. "Stop protecting an app…" must be the FIRST row — it was at the
--     bottom of a long list and effectively undiscoverable.
assert(rows39[1] and rows39[1].action == "removemode",
    "FAIL: the first row is '" .. tostring(rows39[1] and rows39[1].action) ..
    "', not the un-protect entry point")
local removeModeCount = 0
for _, c in ipairs(rows39) do
    if c.action == "removemode" then removeModeCount = removeModeCount + 1 end
end
assert(removeModeCount == 1, "FAIL: the un-protect row appears " .. removeModeCount .. " times")
print("PASS: 'Stop protecting an app…' is the first row, listed once")

-- ---------------------------------------------------------------------
-- 6.27.1 — the PIN prompt must stay on the monitor you were heading to
-- ---------------------------------------------------------------------
-- Hiding a locked app makes macOS fall back to the app that was in front
-- BEFORE, which is often on another monitor. By the time the prompt
-- opens, "the frontmost app" is that fallback app, so the prompt used to
-- appear back where you came from — the bounce.

flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockClearCooldownForTest()

local lockedScreen = { frame = function() return { x = 1920, y = 0, w = 1920, h = 1080 } end,
                       name  = function() return "Locked App Monitor" end }
TEST.appScreens["TextEdit"] = lockedScreen

-- 41. Assert WHERE the prompt actually lands, not merely that a flag was
--     set. The locked app sits on a second monitor at x=1920..3840; the
--     fallback screen is the main one at x=0..1920. Capturing the point
--     passed to show() tells us which one won.
local shownAt = nil
local pinC = _G.appLockPinChooserForTest()
pinC.show = function(_, point) shownAt = point; return pinC end
_G.popupScreenOverride = nil
-- ⌘-Tab to a hidden app makes macOS UNHIDE and activate it, so at the
-- moment the watcher fires the app is on screen with a real window.
-- Leaving it "hidden" here would be modelling a state that cannot occur.
TEST.hiddenApps["TextEdit"] = nil
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
flushAppLockTimers()
assert(shownAt, "FAIL: the PIN prompt was never shown")
assert(shownAt.x >= 1920,
    "FAIL: the prompt opened at x=" .. tostring(shownAt.x) .. ", on the FALLBACK monitor —" ..
    " it followed the focus bounce instead of staying on the locked app's screen")
print("PASS: the prompt opens on the locked app's monitor (x=" .. math.floor(shownAt.x) .. ")")

-- 42. The override must be CLEARED afterwards. Leaving it set would pin
--     every other picker in the config to App Lock's last screen.
assert(_G.popupScreenOverride == nil,
    "FAIL: popupScreenOverride was left set — every other popup would be stuck on that monitor")
print("PASS: the screen override is cleared once the prompt is placed")

-- 43. resolveBaseScreen must actually honour the override when set.
assert(src:find("if _G.popupScreenOverride then return _G.popupScreenOverride end", 1, true),
    "FAIL: resolveBaseScreen ignores the override, so the prompt would still follow the bounce")
assert(lockCode:find("appLockRememberScreen", 1, true),
    "FAIL: App Lock never captures the locked app's screen before hiding it")
local challengeCode = lockCode:match("appLockChallenge(.-)appLockHideAllLocked") or lockCode
assert(challengeCode:find("appLockRememberScreen(app)", 1, true),
    "FAIL: the screen is not captured in the challenge, before the hide bounces focus")
print("PASS: the locked app's screen is captured before hiding and honoured after")

-- ---------------------------------------------------------------------
-- 6.29.0 — cover instead of hide, and the ways out of a cover
-- ---------------------------------------------------------------------
-- Hiding a locked app forces macOS to give focus to something else,
-- which on two monitors drags the view across and back. Covering leaves
-- the app in place, so nothing moves on its own.

flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockClearCooldownForTest()
_G.appLockRemoveCoversForTest()

-- 44. Activating a locked app must paint a cover.
TEST.canvases = {}
TEST.hiddenApps["TextEdit"] = nil
TEST.appScreens["TextEdit"] = lockedScreen
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
assert(_G.appLockCoverCountForTest() > 0,
    "FAIL: no cover was painted — the app is only hidden, so the bounce is still there")
assert(TEST.liveCovers() > 0, "FAIL: the cover was created but never shown")
print("PASS: activating a locked app paints a cover over its screen")

-- 45. The cover must actually conceal: opaque fill, and it names the way
--     out. A see-through panel would defeat the whole point.
local cover = nil
for _, c in ipairs(TEST.canvases) do if c.visible then cover = c end end
assert(cover, "FAIL: no visible cover canvas")
local fill = nil
for _, e in ipairs(cover.elements) do
    if e.type == "rectangle" then fill = e end
end
assert(fill and fill.fillColor and fill.fillColor.alpha >= 0.95,
    "FAIL: the cover is see-through (alpha " .. tostring(fill and fill.fillColor and fill.fillColor.alpha) .. ")")
local blob = ""
for _, e in ipairs(cover.elements) do blob = blob .. " " .. tostring(e.text or "") end
assert(blob:find("H", 1, true), "FAIL: the cover never tells you the panic key")
print("PASS: the cover is opaque and shows the way out")

-- 46. It also hides the app and sends focus somewhere PREDICTABLE, so
--     macOS is not left to pick a destination on another monitor.
assert(TEST.hiddenApps["TextEdit"], "FAIL: the app was not hidden behind the cover")
local wentToFallback = false
for _, n in ipairs(TEST.launchedOrFocused) do
    if n == "Finder" then wentToFallback = true end
end
assert(wentToFallback, "FAIL: focus was not sent to Finder — macOS would choose, and that is the bounce")
print("PASS: app hidden behind the cover, focus sent to Finder deliberately")

-- 47. A correct PIN restores the app AND lifts the cover.
flushAppLockTimers()
_G.appLockPinChooserForTest().callback({ text = "row" })   -- empty buffer = wrong
_G.appLockRemoveCoversForTest()
assert(_G.appLockCoverCountForTest() == 0, "FAIL: covers survived removal")
print("PASS: covers can be lifted")

-- 48. THE PANIC KEY. A hyper modal binding (⇪⇧H), integrated like all
--     other shortcuts. Unclaimed hyper keys forward the raw chord, so it
--     works even if the modal is wedged.
local modal = _G.hyperModal
assert(modal, "FAIL: _G.hyperModal missing")
local panic = modal.bindings["shift+h"]
assert(panic and type(panic) == "function", "FAIL: ⇪⇧H panic key not bound in hyper modal")
_G.appLockClearCooldownForTest()
TEST.hiddenApps["TextEdit"] = nil
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
assert(_G.appLockCoverCountForTest() > 0, "FAIL: expected a cover to clear")
panic()
assert(_G.appLockCoverCountForTest() == 0, "FAIL: the panic key did not clear the cover")
print("PASS: ⇪⇧H clears every cover, and it works via hyper modal (unclaimed keys forward the chord)")

-- 49. THE WATCHDOG. A cover with no prompt behind it is orphaned and
--     must disappear on its own — the last line of defence against being
--     stranded behind an opaque panel.
-- NOTE: this deliberately paints a cover DIRECTLY rather than going
-- through the watcher. Driving it through the watcher meant the cancel
-- path had already removed the cover, so the watchdog had nothing to do
-- and the test passed even with the watchdog deleted. It was measuring
-- the cleanup it was supposed to be a backstop for.
local watchdog = nil
for _, t in ipairs(TEST.capturedTimers) do
    if t.interval == 3 then watchdog = t.fn end
end
assert(watchdog, "FAIL: no watchdog timer for orphaned covers")

-- Close whatever prompt test 48 left open, then confirm we really are
-- in the "no prompt" state the watchdog keys off.
flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockRemoveCoversForTest()
assert(_G.appLockPromptOpenForTest() == false, "FAIL: a prompt is still open, cannot test orphan cleanup")
_G.appLockShowCoversForTest(app, "TextEdit")
assert(_G.appLockCoverCountForTest() > 0, "FAIL: could not paint a cover to orphan")
watchdog()
assert(_G.appLockCoverCountForTest() == 0,
    "FAIL: the watchdog left an orphaned cover on screen — you would be stuck behind it")
print("PASS: the watchdog clears a cover left with no prompt behind it")

-- 50. THE COVER MUST SURVIVE OUR OWN SIDE EFFECTS (6.29.1).
-- Covering is immediately followed by hiding the app and focusing
-- Finder, and hiding the frontmost app makes macOS fire `deactivated`
-- for it. 6.29.0's deactivate handler removed covers unconditionally, so
-- the cover was destroyed roughly a frame after being painted — cover
-- mode was really hide mode wearing a hat.
flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)
flushAppLockTimers()
_G.appLockClearCooldownForTest()
_G.appLockRemoveCoversForTest()

TEST.hiddenApps["TextEdit"] = nil
lockWatcher.callback("TextEdit", hs.application.watcher.activated, app)
assert(_G.appLockCoverCountForTest() > 0, "FAIL: no cover was painted")
assert(_G.appLockPromptOpenForTest() == true, "FAIL: expected a challenge in flight")

-- This is the event our OWN hide+focus generates.
lockWatcher.callback("TextEdit", hs.application.watcher.deactivated, app)
assert(_G.appLockCoverCountForTest() > 0,
    "FAIL: the cover was torn down by the deactivate our own hide caused —" ..
    " cover mode collapses back into hide mode")
print("PASS: the cover survives the deactivate caused by hiding the app")

-- 51. But a GENUINE switch away — no challenge in flight — must still
--     clear it, or a cover could outlive the app being frontmost.
-- Flush FIRST: the challenge waits for the confirm-hidden poll before it
-- opens the prompt, so cancelling before that has nothing to cancel and
-- promptOpen would stay stuck true.
flushAppLockTimers()
_G.appLockPinChooserForTest().callback(nil)     -- close the prompt
assert(_G.appLockPromptOpenForTest() == false, "FAIL: prompt still open")
_G.appLockShowCoversForTest(app, "TextEdit")
assert(_G.appLockCoverCountForTest() > 0, "FAIL: could not paint a cover")
lockWatcher.callback("TextEdit", hs.application.watcher.deactivated, app)
assert(_G.appLockCoverCountForTest() == 0,
    "FAIL: a cover survived a genuine switch away with no prompt open")
print("PASS: a genuine switch away still clears the cover")

print("\n=== ALL ASSERTIONS PASSED ===")
