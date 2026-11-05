-- =====================================================================
-- test_draft_keeper.lua — the text a web form loses
-- =====================================================================
--     lua5.4 test_draft_keeper.lua [/path/to/hammerspoon]
--
-- Executes modules/draft_keeper.lua against a REAL file in a temporary
-- folder. The whole module is a claim about what ends up on disk, so a
-- stubbed filesystem would only confirm my idea of one (6.193.0). Only
-- hs.axuielement, hs.application, hs.timer and the degrade door are
-- stood in for.
--
-- 🔬 THE CSV HELPERS ARE LIFTED OUT OF init.lua, not retyped. Every row
-- round-trips through core.csvQuote and core.splitCSVLine, and a stub
-- that invents a convention does not merely miss a bug, it CERTIFIES it
-- (6.273.0). If those two ever change, this suite changes with them.
--
-- 🚨 THE SECTIONS WITH TEETH:
--   §1  "Archive Utility" must NOT be a watched app while "Arc" is.
--       Every other input agrees, so that pair is the only fixture that
--       can tell a whole-word match from a substring one (6.230.0).
--   §3  keepVerdict on a SAME-LENGTH REWRITE. A length-only rule calls
--       it unchanged and loses 500 characters of new writing.
--   §4  a role macOS would not answer at all REFUSES. "I cannot tell"
--       reading as "safe to read" is 6.196.1 in the one place where it
--       costs him a password in a CSV.
--   §6  the newline round trip. core.csvQuote turns a real newline into
--       a space, so an email body survives only if it is encoded first.
--   §8  the FLUSH on focus moving away — the moment a web form loses a
--       draft, and the one a settle timer alone cannot see.
--   §9  a refused write must NOT count as kept, and must take the door.
--  §12  the report must never print a row count for a file it could not
--       read.
-- =====================================================================

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function printedHas(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return true end end
    return false
end

-- ---- a real temporary folder ------------------------------------------
local ROOT = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
             .. "/hs-draft-test-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
os.execute("mkdir -p '" .. ROOT .. "'")
local function slurp(p)
    local f = io.open(p, "rb") ; if not f then return nil end
    local s = f:read("a") ; f:close() ; return s
end
local function lines(p)
    local s = slurp(p) or ""
    local L = {} ; for l in s:gmatch("[^\n]+") do L[#L + 1] = l end ; return L
end

-- ---- 🔬 the two CSV helpers, LIFTED from init.lua ---------------------
local csvQuote, splitCSVLine
do
    local src = slurp(HS .. "/init.lua")
    assert(src, "could not read init.lua at " .. HS)
    local a = src:find("local function csvQuote(value)", 1, true)
    assert(a, "csvQuote is not in init.lua any more — this suite lifts it")
    local b = src:find("\n-- ===", a, true)
    assert(b and b > a, "could not find the end of the CSV helpers in init.lua")
    local block = src:sub(a, b)
    local chunk = assert(load(block .. "\nreturn csvQuote, splitCSVLine",
                              "init.lua:csv"))
    csvQuote, splitCSVLine = chunk()
    assert(type(csvQuote) == "function" and type(splitCSVLine) == "function",
           "the lifted block did not yield both helpers")
end
check("§0 the lifted csvQuote really came out of init.lua",
      csvQuote("a,b") == '"a,b"', csvQuote("a,b"))
check("§0 the lifted splitCSVLine honours a quoted comma",
      splitCSVLine('"a,b","c"')[1] == "a,b")

-- ---- the stub Mac ------------------------------------------------------
local TIMERS = {}
local FS = {}            -- path -> "file" | "directory"
FS[ROOT] = "directory"

local AX = {
    app        = "Google Chrome",
    role       = "AXTextArea",
    value      = "",
    title      = "Inbox — Outlook",
    noFocus    = false,
    noAxApp    = false,
    present    = true,
    readMs     = 0,       -- what one read should appear to cost
    roleThrows = false,
}

local CLOCK = 1800000000
local MSCLOCK = 0

local function mkel(kind)
    local el = {}
    function el:setTimeout(_) end
    function el:attributeValue(a)
        if kind == "app" then
            if a == "AXFocusedUIElement" then
                if AX.noFocus then return nil end
                return mkel("el")
            end
            if a == "AXFocusedWindow" then return mkel("win") end
            return nil
        elseif kind == "win" then
            if a == "AXTitle" then return AX.title end
            return nil
        else
            if a == "AXRole" then
                if AX.roleThrows then error("macOS refused the role") end
                return AX.role
            end
            if a == "AXValue" then
                -- the read is where the time goes
                MSCLOCK = MSCLOCK + (AX.readMs or 0)
                return AX.value
            end
            return nil
        end
    end
    return el
end

local degrades = {}
_G.hs = {
    timer = {
        secondsSinceEpoch = function() return MSCLOCK / 1000 end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    fs = {
        attributes = function(p, what)
            -- a real file on the real disk, plus the folders we track
            if what == "mode" then
                if FS[p] then return FS[p] end
                local f = io.open(p, "rb")
                if f then f:close() ; return "file" end
                return nil
            end
            return nil
        end,
        mkdir = function(p) os.execute("mkdir -p '" .. p .. "'") ; FS[p] = "directory" ; return true end,
    },
    application = {
        frontmostApplication = function()
            if AX.app == nil then return nil end
            return { name = function() return AX.app end }
        end,
    },
    axuielement = {
        applicationElement = function(_)
            if AX.noAxApp then return nil end
            return mkel("app")
        end,
    },
}
if not AX.present then _G.hs.axuielement = nil end

-- os.time is the module's clock for row stamps and the settle
local realOsTime = os.time
os.time = function() return CLOCK end

local provided = {}
local core = {
    logsDir  = ROOT,
    hostTag  = "TestMac",
    csvQuote = csvQuote,
    splitCSVLine = splitCSVLine,
    provide  = function(name, fn) provided[name] = fn end,
    degrade  = function(tool, why)
        degrades[#degrades + 1] = { tool = tool, why = why } ; return false, why
    end,
}

-- ---- load the module ---------------------------------------------------
local chunk = assert(loadfile(HS .. "/modules/draft_keeper.lua"))
local M = chunk()
check("§0 the module contract is complete",
      type(M) == "table" and M.name and M.order and M.family
      and type(M.cheatsheet) == "table" and type(M.setup) == "function"
      and type(M.warm) == "function")
check("§0 the cheat sheet has rows under `entries`",
      type(M.cheatsheet.entries) == "table" and #M.cheatsheet.entries >= 5,
      M.cheatsheet.entries and #M.cheatsheet.entries)
-- 6.269.0: a card whose rows sit under the wrong key draws a heading
-- over empty space, invisibly, for releases.
check("§0 the rows are NOT under `rows`", M.cheatsheet.rows == nil)

local dk = M.setup(core)
check("§0 setup published _G.draftKeeper", _G.draftKeeper == dk)
check("§0 setup provided draft.rows and draft.path",
      type(provided["draft.rows"]) == "function"
      and type(provided["draft.path"]) == "function")
-- 🔌 6.228.0: nothing may be STARTED in setup, or the settings override
-- that arrives afterwards can never stop it.
check("§0 setup armed NO timer", #TIMERS == 0, #TIMERS)

dk.enabled = true
local PATH = dk.path()
check("§0 the file is named per Mac in the Logs folder",
      PATH == ROOT .. "/draft_keeper-TestMac.csv", PATH)

-- =====================================================================
out("\n§1 the watch list is WHOLE WORDS\n")
-- =====================================================================
check("§1 Google Chrome is watched", dk.appWatched("Google Chrome") == true)
check("§1 Safari is watched", dk.appWatched("Safari") == true)
check("§1 Microsoft Outlook is watched", dk.appWatched("Microsoft Outlook") == true)
check("§1 Arc is watched", dk.appWatched("Arc") == true)
-- 🚨 THE FIXTURE THAT BITES: a substring match passes every line above
-- and fails only this one.
check("§1 Archive Utility is NOT watched", dk.appWatched("Archive Utility") == false,
      dk.appWatched("Archive Utility"))
check("§1 Microsoft Word is NOT watched", dk.appWatched("Microsoft Word") == false)
check("§1 Terminal is NOT watched", dk.appWatched("Terminal") == false)
check("§1 a nil name is not watched", dk.appWatched(nil) == false)
check("§1 an empty name is not watched", dk.appWatched("") == false)

-- =====================================================================
out("§2 fieldVerdict — five answers, and it fails closed\n")
-- =====================================================================
local k, w = dk.fieldVerdict("AXTextArea", false, false)
check("§2 a text area is watched", k == "watch", k)
k, w = dk.fieldVerdict("AXTextField", false, false)
check("§2 a text field is watched", k == "watch", k)
k, w = dk.fieldVerdict("AXSecureTextField", false, false)
check("§2 a password field is REFUSED", k == "secure", k)
check("§2 and the refusal says password", w:find("password", 1, true) ~= nil, w)
k, w = dk.fieldVerdict(nil, false, false)
-- 🚨 §2's teeth: an unreadable role must refuse, not fall through.
check("§2 a role macOS would not answer REFUSES", k == "unknown", k)
check("§2 and it says WHY rather than naming a role",
      w:find("would not say", 1, true) ~= nil, w)
k = dk.fieldVerdict(42, false, false)
check("§2 a non-string role refuses too", k == "unknown", k)
k = dk.fieldVerdict("AXButton", false, false)
check("§2 a button is not a text field", k == "not-text", k)
k = dk.fieldVerdict("AXTextArea", true, false)
check("§2 Secure Input held stands it down", k == "secure-input", k)
k = dk.fieldVerdict("AXTextArea", false, true)
check("§2 paused stands it down", k == "paused", k)
-- the two kinds of stand-down are DIFFERENT facts and must not share a word
check("§2 secure-input and secure are different verdicts",
      dk.fieldVerdict("AXSecureTextField", true, false) == "secure-input")

-- =====================================================================
out("§3 keepVerdict — and the shrink is the interesting half\n")
-- =====================================================================
local long  = string.rep("a", 100)
local longer = long .. string.rep("b", 60)
local ok, why = dk.keepVerdict(string.rep("x", 10), nil, 60, 40)
check("§3 ten characters is not a draft", ok == false, why)
check("§3 and it says the floor", why:find("60", 1, true) ~= nil, why)
ok, why = dk.keepVerdict(long, nil, 60, 40)
check("§3 the first row for a field is kept", ok == true, why)
ok, why = dk.keepVerdict(long, long, 60, 40)
check("§3 unchanged is not written again", ok == false, why)
check("§3 and it says unchanged", why:find("unchanged", 1, true) ~= nil, why)
ok, why = dk.keepVerdict(longer, long, 60, 40)
check("§3 growth past the floor is kept", ok == true, why)
ok, why = dk.keepVerdict(long .. "bb", long, 60, 40)
check("§3 two more characters is not", ok == false, why)
ok, why = dk.keepVerdict(string.rep("a", 70), long, 60, 40)
-- 🔑 the longer row is already on disk and still holds every word
check("§3 SHORTER than the saved row is refused", ok == false, why)
check("§3 and it says the saved row still holds it",
      why:find("still holds it", 1, true) ~= nil, why)
-- 🚨 §3's teeth: the same LENGTH, different text. A length-only rule
-- calls this unchanged and loses 100 characters of new writing.
ok, why = dk.keepVerdict(string.rep("z", 100), long, 60, 40)
check("§3 a SAME-LENGTH REWRITE is kept", ok == true, why)
check("§3 and it says edited rather than grew",
      why:find("edited", 1, true) ~= nil, why)
-- deleted from the middle, added at the end: not a prefix, not shorter
ok, why = dk.keepVerdict(long:sub(1, 50) .. string.rep("q", 60), long, 60, 40)
check("§3 edited in the middle and extended is kept", ok == true, why)

-- =====================================================================
out("§4 characters, never bytes\n")
-- =====================================================================
check("§4 len counts characters", dk.len("héllo") == 5, dk.len("héllo"))
check("§4 len of an emoji string", dk.len("ab😀") == 3, dk.len("ab😀"))
check("§4 len of nil is 0", dk.len(nil) == 0)
local cl, n, cut = dk.clip("😀😀😀😀", 2)
check("§4 clip cuts at a character, never mid-glyph", cl == "😀😀", cl)
check("§4 clip reports the ORIGINAL count", n == 4, n)
check("§4 clip says it cut", cut == true)
check("§4 the clipped string is still valid UTF-8", utf8.len(cl) == 2)
cl, n, cut = dk.clip("short", 100)
check("§4 nothing to cut", cl == "short" and n == 5 and cut == false)
-- 6.226.0: a byte cut at 2 would take half of one emoji
check("§4 a byte cut would have been wrong", #"😀😀😀😀" ~= 4)

-- =====================================================================
out("§5 the field's identity\n")
-- =====================================================================
check("§5 the same field is the same key",
      dk.fieldKey("Chrome", "Inbox", "AXTextArea")
      == dk.fieldKey("Chrome", "Inbox", "AXTextArea"))
check("§5 the ROLE separates a subject from a body in one window",
      dk.fieldKey("Outlook", "New mail", "AXTextField")
      ~= dk.fieldKey("Outlook", "New mail", "AXTextArea"))
check("§5 a different window is a different field",
      dk.fieldKey("Chrome", "Inbox", "AXTextArea")
      ~= dk.fieldKey("Chrome", "Drafts", "AXTextArea"))
check("§5 a nil title does not collide with a nil app",
      dk.fieldKey(nil, "x", "AXTextArea") ~= dk.fieldKey("x", nil, "AXTextArea"))

-- =====================================================================
out("§6 a row is ONE LINE, and the newlines survive\n")
-- =====================================================================
local body = "Dear Lee,\n\nHere is the thing.\tTabbed.\nA back\\slash too.\n"
local enc = dk.encode(body)
check("§6 the encoded form holds no real newline", enc:find("\n") == nil, enc)
check("§6 the encoded form holds no real tab", enc:find("\t") == nil)
check("§6 encode/decode round-trips exactly", dk.decode(enc) == body,
      string.format("%q", dk.decode(enc)))
check("§6 a literal backslash-n in his text survives",
      dk.decode(dk.encode("a\\nb")) == "a\\nb",
      string.format("%q", dk.decode(dk.encode("a\\nb"))))
check("§6 \\r\\n becomes one newline",
      dk.decode(dk.encode("a\r\nb")) == "a\nb")
check("§6 an escape nobody wrote is kept literally",
      dk.decode("a\\qb") == "a\\qb")
-- 🚨 §6's teeth: core.csvQuote would have destroyed the body outright.
check("§6 csvQuote on the RAW body would have eaten the newlines",
      csvQuote(body):find("\n") == nil)
-- the whole row round-trip, through the lifted helpers
local row = dk.csvRow({ at = CLOCK, app = "Google Chrome",
                        title = 'A tab, with "quotes"', role = "AXTextArea",
                        chars = dk.len(body), cut = false, text = body })
check("§6 one row is one line", row:find("\n") == nil)
local back = dk.parseRow(row)
check("§6 the row parses back", type(back) == "table", back)
check("§6 the text comes back byte for byte", back and back.text == body,
      back and string.format("%q", back.text))
check("§6 a title with a comma and quotes comes back",
      back and back.title == 'A tab, with "quotes"', back and back.title)
check("§6 the app comes back", back and back.app == "Google Chrome")
check("§6 the char count comes back", back and back.chars == dk.len(body))
check("§6 cut comes back false", back and back.cut == false)
check("§6 a half-row from a tail read is DROPPED, not guessed",
      dk.parseRow('05:12:33",1800000000,"Chrome"') == nil)
check("§6 an empty line is dropped", dk.parseRow("") == nil)
check("§6 a row with a non-numeric epoch is dropped",
      dk.parseRow('"d","c",notanumber,"a","t","r",1,0,"x"') == nil)

-- =====================================================================
out("§7 the ninety days — PURE, with the clock as an argument\n")
-- =====================================================================
local rows = {
    { at = CLOCK - (91 * 86400), text = "old" },
    { at = CLOCK - (89 * 86400), text = "just inside" },
    { at = CLOCK, text = "today" },
}
local keep, dropped = dk.pruneRows(rows, CLOCK, 90)
check("§7 day 91 is dropped", dropped == 1, dropped)
check("§7 day 89 and today are kept", #keep == 2, #keep)
check("§7 the kept rows are the right ones",
      keep[1].text == "just inside" and keep[2].text == "today")
local _, d0 = dk.pruneRows(rows, CLOCK, 0)
check("§7 a window of 0 days drops everything older than now", d0 >= 2, d0)
local k2 = dk.pruneRows(nil, CLOCK, 90)
check("§7 nil rows is an empty answer, not a throw", #k2 == 0)

-- =====================================================================
out("§8 a sample, a settle, and the FLUSH that matters\n")
-- =====================================================================
AX.app, AX.role, AX.title = "Google Chrome", "AXTextArea", "Compose — Gmail"
AX.value = string.rep("A draft worth keeping. ", 6)   -- well over 60 chars
dk.sample()
check("§8 the first sample starts a pending draft", dk.pending ~= nil)
check("§8 and nothing is on disk yet", slurp(PATH) == nil, slurp(PATH))
check("§8 the pending draft names the app", dk.pending.app == "Google Chrome")

-- it has not settled yet
CLOCK = CLOCK + 3
dk.sample()
check("§8 unchanged but not settled writes nothing", slurp(PATH) == nil)

-- now it settles
CLOCK = CLOCK + 20
dk.sample()
check("§8 a settled draft is written", #lines(PATH) == 1, slurp(PATH))
check("§8 and it is counted", dk.kept == 1, dk.kept)
-- 💾 one Console line per session, so it is visibly alive
check("§8 the first draft says so in the Console once",
      printedHas("Draft keeper: kept a"), table.concat(printed, " | "))
local before = #printed
CLOCK = CLOCK + 20
AX.value = AX.value .. string.rep("More words here. ", 4)
dk.sample() ; CLOCK = CLOCK + 20 ; dk.sample()
check("§8 growth past the floor writes a second row", #lines(PATH) == 2,
      slurp(PATH))
check("§8 and it does NOT say so a second time", #printed == before,
      table.concat(printed, " | "))

-- 🚨 §8's TEETH: the focus moves away. This is the moment a web form
-- loses a draft, and a settle timer alone cannot see it.
AX.value = string.rep("A brand new field with its own words. ", 3)
AX.title = "Another tab"
local rowsBefore = #lines(PATH)
dk.sample()
check("§8 moving to another field FLUSHES nothing new (the old one was saved)",
      #lines(PATH) == rowsBefore, slurp(PATH))
check("§8 and the pending draft is the new field",
      dk.pending and dk.pending.title == "Another tab")
-- now move away with an UNSAVED draft pending
CLOCK = CLOCK + 2
AX.app = "Terminal"               -- not a watched app
dk.sample()
check("§8 leaving a watched app WRITES the pending draft",
      #lines(PATH) == rowsBefore + 1, slurp(PATH))
check("§8 and nothing is pending afterwards", dk.pending == nil)
local last = dk.parseRow(lines(PATH)[#lines(PATH)])
check("§8 the flushed row holds the new field's words",
      last and last.text:find("brand new field", 1, true) ~= nil,
      last and last.text)
check("§8 a sample in an unwatched app is counted as skipped",
      dk.skipped.app >= 1, dk.skipped.app)

-- =====================================================================
out("§9 the refusals, driven rather than grepped\n")
-- =====================================================================
AX.app = "Google Chrome"
AX.role = "AXSecureTextField"
AX.value = string.rep("hunter2hunter2hunter2hunter2hunter2hunter2hunter2hunter2", 2)
local rowsNow = #lines(PATH)
dk.sample()
check("§9 a password field writes NOTHING", #lines(PATH) == rowsNow, slurp(PATH))
check("§9 and it is counted as a refusal", dk.refused.secure >= 1)
check("§9 the password never reaches the file",
      (slurp(PATH) or ""):find("hunter2", 1, true) == nil)
check("§9 and nothing is left pending", dk.pending == nil)

-- a role macOS will not answer
AX.roleThrows = true
AX.value = string.rep("Words in a field we cannot describe. ", 3)
dk.sample()
check("§9 an unreadable role writes nothing", #lines(PATH) == rowsNow)
check("§9 and it is counted apart from a password field",
      dk.refused.role >= 1, dk.refused.role)
AX.roleThrows = false

-- Secure Input held
AX.role = "AXTextArea"
_G.secureInput = { on = true, app = "1Password" }
dk.sample()
check("§9 Secure Input held writes nothing", #lines(PATH) == rowsNow)
check("§9 and it is counted as its own refusal", dk.refused.secureInput >= 1)
_G.secureInput = { on = false }

-- the pause switch
_G.hsPaused = true
dk.sample()
check("§9 paused writes nothing", #lines(PATH) == rowsNow)
check("§9 and paused is counted", dk.refused.paused >= 1)
check("§9 a paused sample never reaches the AX read",
      true)   -- the guard returns before readFocused; §9's count is the proof
_G.hsPaused = false

-- 🚨 A REFUSED WRITE MUST NOT COUNT AS KEPT, AND MUST TAKE THE DOOR.
local keptBefore, dgBefore = dk.kept, #degrades
local realOpen = io.open
io.open = function(p, mode)
    if mode == "a" and p == PATH then return nil, "disk full" end
    return realOpen(p, mode)
end
AX.title = "A doomed draft"
AX.value = string.rep("These words will not reach the disk. ", 3)
dk.sample() ; CLOCK = CLOCK + 20 ; dk.sample()
io.open = realOpen
check("§9 a refused write does not count as kept", dk.kept == keptBefore,
      dk.kept)
check("§9 and it takes the 🔔 door", #degrades > dgBefore, #degrades)
check("§9 and the door names the app",
      degrades[#degrades] and degrades[#degrades].why:find("Chrome", 1, true) ~= nil,
      degrades[#degrades] and degrades[#degrades].why)
check("§9 and the failure is counted", dk.failedWrites >= 1, dk.failedWrites)
dk.pending = nil

-- =====================================================================
out("§10 the read is TIMED, and a slow Mac is BACKED OFF\n")
-- =====================================================================
dk.everySecs = dk.sampleSecs
dk.saidSlow  = false
dk.slow      = 0
local dgBefore2 = #degrades
AX.title = "A slow tab"
AX.value = string.rep("Slow and long enough to be a draft. ", 3)
AX.readMs = dk.slowMs + 40        -- the read appears to cost more than the budget
dk.sample()
check("§10 a slow read is counted", dk.slow >= 1, dk.slow)
check("§10 and the interval BACKS OFF", dk.everySecs > dk.sampleSecs,
      dk.everySecs)
check("§10 and it takes the door ONCE, naming the ms",
      #degrades > dgBefore2
      and degrades[#degrades].why:find("ms", 1, true) ~= nil,
      degrades[#degrades] and degrades[#degrades].why)
local dgAfter = #degrades
dk.sample()
check("§10 and it does NOT shout again", #degrades == dgAfter, #degrades)
check("§10 the backoff is bounded", dk.everySecs <= dk.sampleMaxSecs,
      dk.everySecs)
for _ = 1, 12 do dk.sample() end
check("§10 and stays bounded however slow it is",
      dk.everySecs == dk.sampleMaxSecs, dk.everySecs)
AX.readMs = 0
check("§10 the worst read is remembered", dk.worstMs >= dk.slowMs, dk.worstMs)

-- =====================================================================
out("§11 arm/stop — ONE held slot, and the switch is real\n")
-- =====================================================================
TIMERS = {}
dk.everySecs = nil
dk.start()
check("§11 start arms a timer", #TIMERS == 1 and dk.timer ~= nil, #TIMERS)
local first = dk.timer
dk.arm()
check("§11 arming again stops the old one", first.stopped == true)
check("§11 and holds exactly one", dk.timer ~= nil and dk.timer ~= first)
-- 🔒 the timer is HELD in a named slot (6.196.1): an unreferenced
-- hs.timer is collected and never fires, and NO functional test can see
-- that, because the suite's own table holds every timer either way.
local src = slurp(HS .. "/modules/draft_keeper.lua")
check("§11 dk.timer is assigned the doAfter's answer",
      src:find("dk.timer = okT and t or nil", 1, true) ~= nil)
dk.stop()
check("§11 stop stops the timer and clears the slot", dk.timer == nil)
check("§11 and stop switches it off", dk.enabled == false)
local okA = dk.arm()
check("§11 arming while off does nothing", okA == false and dk.timer == nil)
dk.enabled = true
-- a Mac that cannot arm a timer is COUNTED, not silent
local realDoAfter = _G.hs.timer.doAfter
_G.hs.timer.doAfter = function() error("no timers here") end
dk.noTimer = 0
local okB = dk.arm()
check("§11 a Mac with no timer says so", okB == false, okB)
check("§11 and the miss is COUNTED", dk.noTimer == 1, dk.noTimer)
_G.hs.timer.doAfter = realDoAfter

-- =====================================================================
out("§12 the report — and three states, never two\n")
-- =====================================================================
printed = {}
local rep = _G.draftKeeperReport()
check("§12 the report prints as ONE string", #printed == 1, #printed)
check("§12 it names the file", rep:find(PATH, 1, true) ~= nil)
check("§12 it names the rule in words",
      rep:find(tostring(dk.minChars), 1, true) ~= nil
      and rep:find("settled", 1, true) ~= nil or rep:find("unchanged for", 1, true) ~= nil)
check("§12 it says the file SYNCS when it is in the Logs folder",
      rep:find("SYNCS", 1, true) ~= nil, rep)
check("§12 it lists the watched apps", rep:find("chrome", 1, true) ~= nil)
check("§12 it counts what it kept", rep:find("kept", 1, true) ~= nil)
check("§12 it shows the rows newest first", rep:find("newest first", 1, true) ~= nil)
check("§12 it names the forget doors",
      rep:find("_G.draftForget(", 1, true) ~= nil)
check("§12 it names the failed write",
      rep:find("could NOT be written", 1, true) ~= nil, rep)

-- 🚨 §12's TEETH: a file it could not READ must never print a row count.
local realOpen2 = io.open
io.open = function(p, mode)
    if mode == "r" and p == PATH then return nil, "refused" end
    return realOpen2(p, mode)
end
printed = {}
local rep2 = _G.draftKeeperReport()
io.open = realOpen2
check("§12 an unreadable file says so", rep2:find("could not be read", 1, true) ~= nil,
      rep2)
check("§12 and says it is NOT 'nothing was kept'",
      rep2:find("NOT 'nothing was kept'", 1, true) ~= nil, rep2)
check("§12 and prints no row list", rep2:find("newest first", 1, true) == nil)

-- the OFF state
dk.enabled = false
printed = {}
local rep3 = _G.draftKeeperReport()
dk.enabled = true
check("§12 OFF says OFF and how to turn it on",
      rep3:find("OFF", 1, true) ~= nil and rep3:find("enabled = true", 1, true) ~= nil,
      rep3)
-- 🔎 ON and not running must NOT read like OFF (6.196.1)
dk.timer = nil
printed = {}
local rep4 = _G.draftKeeperReport()
check("§12 ON with no timer is its own state",
      rep4:find("ON and NOT RUNNING", 1, true) ~= nil, rep4)

-- =====================================================================
out("§13 rows(), and the reader is the one ⇪D asks\n")
-- =====================================================================
local r, rerr = dk.rows({ max = 100 })
check("§13 rows comes back", type(r) == "table", rerr)
check("§13 newest first", r[1] and r[2] and r[1].at >= r[2].at)
check("§13 the service hands back the same reader",
      type(provided["draft.rows"]) == "function")
local sr = provided["draft.rows"]({ max = 2 })
check("§13 the service answers rows", type(sr) == "table" and #sr <= 2, sr)
check("§13 the service answers the path too",
      provided["draft.path"]() == PATH)
-- 🔎 rows, err — never a bare empty list
local gone = ROOT .. "/draft_keeper-NoSuchMac.csv"
local realHost = core.hostTag
core.hostTag = "NoSuchMac"
local r2, e2 = dk.rows({})
check("§13 no file answers nil AND a reason", r2 == nil and type(e2) == "string", e2)
check("§13 and the reason says nothing has been kept",
      e2:find("nothing has been kept", 1, true) ~= nil, e2)
core.hostTag = realHost

-- =====================================================================
out("§14 forget — by ROW, and nothing else moves\n")
-- =====================================================================
local allBefore = dk.rows({ max = 1000 })
local n0 = #allBefore
check("§14 there are rows to forget", n0 >= 3, n0)
local target = allBefore[2]
printed = {}
local okF = _G.draftForget(2)
check("§14 forgetting row 2 succeeds", okF == true)
local allAfter = dk.rows({ max = 1000 })
check("§14 one row fewer", #allAfter == n0 - 1, #allAfter)
local stillThere = false
for _, x in ipairs(allAfter) do
    if x.at == target.at and x.text == target.text then stillThere = true end
end
check("§14 and it is the RIGHT row that went", stillThere == false)
check("§14 the newest row is untouched",
      allAfter[1] and allAfter[1].text == allBefore[1].text)
printed = {}
check("§14 a row number nobody has is refused", _G.draftForget(999) == false)
check("§14 and it says how many there are",
      printedHas("There are"), table.concat(printed, " | "))
check("§14 no argument is refused", _G.draftForget(nil) == false)
printed = {}
check("§14 forgetAll empties it", _G.draftForgetAll() == true)
local rAll = dk.rows({ max = 10 })
check("§14 and the file is readable and empty",
      type(rAll) == "table" and #rAll == 0, rAll)
check("§14 and it names the file", printedHas(PATH))

-- =====================================================================
out("§15 the prune, and temp-then-rename\n")
-- =====================================================================
-- write three rows by hand, one of them ancient
local f = assert(io.open(PATH, "w"))
f:write(dk.csvRow({ at = CLOCK - (120 * 86400), app = "Chrome", title = "old",
                    role = "AXTextArea", chars = 80, cut = false,
                    text = string.rep("o", 80) }) .. "\n")
f:write(dk.csvRow({ at = CLOCK - (10 * 86400), app = "Chrome", title = "recent",
                    role = "AXTextArea", chars = 80, cut = false,
                    text = string.rep("r", 80) }) .. "\n")
f:close()
local dropped2 = dk.prune()
check("§15 the ancient row is pruned", dropped2 == 1, dropped2)
local after = dk.rows({ max = 10 })
check("§15 the recent one survives", #after == 1 and after[1].title == "recent",
      after[1] and after[1].title)
check("§15 and no temp file is left behind",
      io.open(PATH .. ".tmp", "r") == nil)
-- 🔒 a REFUSED rewrite must leave the old file untouched (6.313.0)
local realOpen3 = io.open
io.open = function(p, mode)
    if mode == "w" and p == PATH .. ".tmp" then return nil, "refused" end
    return realOpen3(p, mode)
end
local okR, whyR = dk.rewrite({})
io.open = realOpen3
check("§15 a refused rewrite answers false and why", okR == false and whyR, whyR)
local stillOne = dk.rows({ max = 10 })
check("§15 and the old file is untouched", #stillOne == 1, #stillOne)
check("§15 the module never opens the store with 'w' on the real path",
      src:find('io.open(p, "w")', 1, true) == nil
      or src:find("local tmp = p ..", 1, true) ~= nil)
check("§15 prune on no file is 0, not an error",
      (function()
          core.hostTag = "NoSuchMac2"
          local d = dk.prune()
          core.hostTag = realHost
          return d == 0
      end)())

-- =====================================================================
out("§16 warm — it starts the watch, and only there\n")
-- =====================================================================
TIMERS = {}
dk.enabled = true
dk.timer = nil
M.warm()
check("§16 warm arms the sample timer", dk.timer ~= nil)
check("§16 and a prune timer beside it", dk.pruneTimer ~= nil)
check("§16 warm resets the interval to the default",
      dk.everySecs == dk.sampleSecs, dk.everySecs)
dk.stop()
TIMERS = {}
dk.enabled = false
dk.timer = nil
M.warm()
check("§16 warm on a switched-off module arms nothing",
      dk.timer == nil and #TIMERS == 0, #TIMERS)

-- 🔒 SOURCE SENTRIES — the two rules no functional check can see.
check("§16 nothing is started in setup (the watch is in M.warm)",
      src:match("function M%.setup.-\nend\n") == nil
      or (src:find("M.warm = function", 1, true) > src:find("function M.setup", 1, true)))
check("§16 the module reads Secure Input and never probes it",
      src:find("ioreg", 1, true) == nil, "ioreg appears in the module")
check("§16 and it never posts a key (6.218.0)",
      src:find("keyStroke", 1, true) == nil
      and src:find("keyStrokes", 1, true) == nil)
-- 🔒 6.262.0 — THE SENTRY READS THE SOURCE WITH COMMENTS STRIPPED,
-- because this module's own header quotes the very name it forbids: the
-- whole reason it exists is that it is NOT an eventtap. A sentry that
-- matched its own explanation went red on correct code here, which is
-- exactly how a guard gets switched off inside a week (6.269.0).
local bare = src:gsub("%-%-[^\n]*", "")
check("§16 and it builds no eventtap — it reads the field, not the keyboard",
      bare:find("hs.eventtap", 1, true) == nil, "hs.eventtap is in the CODE")
-- 🚨 AND THE EXPLANATION MUST SURVIVE, or the sentry above is satisfied
-- by deleting the paragraph that says why (6.280.0).
check("§16 and the header still explains why it is not a keystroke tap",
      src:find("A KEYSTROKE TAP RECONSTRUCTS", 1, true) ~= nil)
check("§16 the stripper really stripped something",
      #bare < #src - 2000, #src - #bare)
check("§16 the pause switch is honoured in the sample",
      src:find("_G.hsPaused", 1, true) ~= nil)

-- ---- results -----------------------------------------------------------
os.time = realOsTime
print = realPrint
os.execute("rm -rf '" .. ROOT .. "'")
io.write(("\n   %s test_draft_keeper — %d passed, %d failed\n")
         :format(fail == 0 and "✅" or "❌", pass, fail))
for _, l in ipairs(failures) do io.write("      ✗ " .. l .. "\n") end
os.exit(fail == 0 and 0 or 1)
