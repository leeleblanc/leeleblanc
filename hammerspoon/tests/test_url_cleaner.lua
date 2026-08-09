-- =====================================================================
-- test_url_cleaner.lua — real links, real cruft
-- =====================================================================
--     lua5.4 test_url_cleaner.lua [/path/to/hammerspoon]
--
-- Executes modules/url_cleaner.lua against a stubbed hs. The cases below
-- are shapes that actually turn up in a work inbox, not invented ones —
-- Outlook Safe Links and Proofpoint in particular, because on a managed
-- Mac almost every link in almost every email arrives wrapped in one.
--
-- THE RULE THIS SUITE ENFORCES ABOVE ALL OTHERS: never break a working
-- link. A cleaner that leaves a stray parameter is a nuisance; one that
-- eats ?v= or ?q= or ?id= is worse than not having it at all. Section 3
-- is entirely about things it must NOT touch.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed, ALERTS, CLIP = {}, {}, ""
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local HYPER, PROVIDED = {}, {}
hs = {
    pasteboard = { getContents = function() return CLIP end,
                   setContents = function(s) CLIP = s; return true end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = { secondsSinceEpoch = function() return 1000 end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}
local M = dofile(HS .. "/modules/url_cleaner.lua")
M.setup(CORE)
local C = _G.urlCleaner

local function clean(u) return (C.clean(u)) end
local function eq(label, input, want)
    local got = clean(input)
    check(label, got == want, got ~= want and got or nil)
end

-- =====================================================================
out("\n=== 1. Tracking parameters ===\n")
-- =====================================================================
eq("utm_* all go",
   "https://example.com/page?utm_source=news&utm_medium=email&utm_campaign=q3",
   "https://example.com/page")
eq("a real parameter SURVIVES alongside the cruft",
   "https://shop.com/p?id=42&utm_source=fb&color=blue",
   "https://shop.com/p?id=42&color=blue")
eq("parameter ORDER is preserved — signed URLs care",
   "https://a.com/x?b=2&utm_source=z&a=1&c=3",
   "https://a.com/x?b=2&a=1&c=3")
eq("fbclid", "https://news.com/story?fbclid=IwAR0abc", "https://news.com/story")
eq("gclid + msclkid", "https://x.com/?gclid=1&msclkid=2", "https://x.com/")
eq("Mailchimp mc_eid/mc_cid",
   "https://n.com/a?mc_cid=abc&mc_eid=def", "https://n.com/a")
eq("HubSpot _hsenc/_hsmi", "https://h.com/?_hsenc=p2A&_hsmi=99", "https://h.com/")
eq("Instagram igshid", "https://insta.com/p/x?igshid=abc", "https://insta.com/p/x")
eq("case-insensitive parameter names",
   "https://a.com/?UTM_SOURCE=x&FBCLID=y", "https://a.com/")
eq("the fragment is kept — it is a real anchor",
   "https://docs.com/g?utm_source=x#section-4", "https://docs.com/g#section-4")
eq("a bare '?' left behind is tidied away",
   "https://a.com/path?utm_source=x", "https://a.com/path")
eq("the port survives", "https://a.com:8443/x?fbclid=1", "https://a.com:8443/x")

-- =====================================================================
out("\n=== 2. Redirect wrappers — the work-inbox cases ===\n")
-- =====================================================================
eq("Outlook Safe Links, the single most common wrapper on a managed Mac",
   "https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Freal.com"
   .. "%2Fdoc%3Fid%3D7&data=05%7C01%7C&sdata=abc&reserved=0",
   "https://real.com/doc?id=7")
eq("Safe Links wrapping a URL that ITSELF has tracking — both layers go",
   "https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Freal.com"
   .. "%2Fa%3Futm_source%3Dnews%26id%3D3&data=05",
   "https://real.com/a?id=3")
-- ⚠️ Proofpoint's v2 scheme is "-" for "%" and "_" for "/". Decoding it as
-- ordinary percent-encoding yields a literal %3A and a dead link.
eq("Proofpoint v2, with its OWN encoding, not plain percent-encoding",
   "https://urldefense.proofpoint.com/v2/url?u=https-3A__real.com_page&d=DwMFaQ&r=x",
   "https://real.com/page")
eq("Google /url?q=",
   "https://www.google.com/url?q=https%3A%2F%2Ftarget.com%2Fx&sa=D&usg=AO",
   "https://target.com/x")
eq("Facebook l.facebook.com",
   "https://l.facebook.com/l.php?u=https%3A%2F%2Fdest.com%2Fp&h=AT1",
   "https://dest.com/p")
eq("a generic ?url= redirector on an unknown host",
   "https://click.mailer.io/c?url=https%3A%2F%2Ffinal.com%2Fpage&uid=9",
   "https://final.com/page")
eq("wrapper inside wrapper — Safe Links around a mailer redirect",
   "https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fclick.m.io"
   .. "%2Fc%3Furl%3Dhttps%253A%252F%252Ffinal.com%252Fx%26uid%3D9&data=05",
   "https://final.com/x")
check("the unwrap loop is BOUNDED — a self-referential wrapper must not spin",
      (function()
    local self1 = "https://click.mailer.io/c?url=" ..
                  "https%3A%2F%2Fclick.mailer.io%2Fc%3Furl%3Dhttps%253A%252F%252Fclick.mailer.io%252Fc"
    local done = false
    local ok = pcall(function() clean(self1); done = true end)
    return ok and done
end)())

-- =====================================================================
out("\n=== 3. 🛟 WHAT IT MUST NOT TOUCH ===\n")
-- =====================================================================
-- Every line here is a link that a slightly-too-clever cleaner breaks.
eq("YouTube ?v= is the video itself",
   "https://youtube.com/watch?v=dQw4w9WgXcQ&utm_source=x",
   "https://youtube.com/watch?v=dQw4w9WgXcQ")
eq("a search query", "https://duckduckgo.com/?q=lua+patterns",
   "https://duckduckgo.com/?q=lua+patterns")
eq("'+' in a query is NOT turned into a space",
   "https://a.com/?q=one+two&fbclid=1", "https://a.com/?q=one+two")
eq("GitHub ?ref= is routing, not tracking — removing it 404s",
   "https://github.com/a/b?ref=readme", "https://github.com/a/b?ref=readme")
eq("?s= is a search on most sites, so it stays",
   "https://blog.com/?s=hammerspoon", "https://blog.com/?s=hammerspoon")
eq("pagination", "https://forum.com/t/1?page=4", "https://forum.com/t/1?page=4")
eq("an already-clean URL is returned untouched",
   "https://example.com/a/b/c", "https://example.com/a/b/c")
eq("a URL with no query at all", "https://example.com", "https://example.com")
eq("percent-encoding in the PATH is left alone",
   "https://a.com/my%20file.pdf?utm_source=x", "https://a.com/my%20file.pdf")
check("a non-URL string is returned unchanged", clean("just some text") == "just some text")
check("an empty string does not crash", clean("") == "")
check("nil does not crash", (function()
    local ok = pcall(function() C.clean(nil) end) ; return ok end)())

-- =====================================================================
out("\n=== 4. Shorteners: named, never fetched ===\n")
-- =====================================================================
for _, s in ipairs({ "https://bit.ly/3abcXYZ", "https://t.co/abc123",
                     "https://lnkd.in/xyz", "https://youtu.be/dQw4w9WgXcQ" }) do
    local _, rep = C.clean(s)
    check("recognises " .. s:match("//([^/]+)") .. " as a shortener",
          rep.shortener ~= nil, rep.shortener)
end
check("🚫 THE MODULE MAKES NO NETWORK CALLS AT ALL — expanding a shortener "
      .. "would register the click and send the link off this Mac",
      (function()
    local f = io.open(HS .. "/modules/url_cleaner.lua", "r")
    local body = f:read("*a"):gsub("%-%-[^\n]*", "")   -- strip comments
    f:close()
    for _, bad in ipairs({ "hs%.http", "hs%.task", "io%.popen", "os%.execute",
                           "hs%.urlevent%.openURL", "hs%.execute" }) do
        if body:find(bad) then return false, bad end
    end
    return true
end)())

-- =====================================================================
out("\n=== 5. Whole-text mode ===\n")
-- =====================================================================
do
    local text = "See https://a.com/x?utm_source=n and https://b.com/y?fbclid=1 too."
    local got = C.cleanText(text)
    check("every link in a paragraph is cleaned, prose untouched",
          got == "See https://a.com/x and https://b.com/y too.", got)
    local got2 = C.cleanText("Read https://a.com/p?utm_source=x.")
    check("a full stop after a link is not swallowed into it",
          got2 == "Read https://a.com/p.", got2)
    local got3 = C.cleanText("(see https://a.com/p?utm_source=x)")
    check("an unbalanced closing bracket is not swallowed",
          got3 == "(see https://a.com/p)", got3)
    local got4 = C.cleanText("https://en.wikipedia.org/wiki/Lua_(programming)?utm_source=x")
    check("...but a BALANCED bracket that is part of the URL is kept",
          got4 == "https://en.wikipedia.org/wiki/Lua_(programming)", got4)
    local _, t = C.cleanText(text)
    check("the tally counts both links", t.urls == 2, t.urls)
    check("...and both trackers", t.removed == 2, t.removed)
end

-- =====================================================================
out("\n=== 6. The keys, the clipboard and undo ===\n")
-- =====================================================================
check("⇪K is claimed", HYPER["|k"] ~= nil)
check("⇪⇧K is claimed for undo", HYPER["shift|k"] ~= nil)
check("services are published", PROVIDED["url.clean"] ~= nil
      and PROVIDED["url.cleanText"] ~= nil)

CLIP = "https://a.com/x?utm_source=news&id=5" ; ALERTS = {}
HYPER["|k"]()
check("⇪K rewrites the clipboard in place",
      CLIP == "https://a.com/x?id=5", CLIP)
check("...and says what it did", #ALERTS == 1 and ALERTS[1]:find("removed", 1, true))
HYPER["shift|k"]()
check("⇪⇧K puts the original back",
      CLIP == "https://a.com/x?utm_source=news&id=5", CLIP)
HYPER["shift|k"]()
check("a second undo says there is nothing to undo",
      ALERTS[#ALERTS]:find("Nothing to undo", 1, true) ~= nil, ALERTS[#ALERTS])

CLIP = "https://already.clean/x" ; ALERTS = {}
HYPER["|k"]()
check("an already-clean link is left exactly alone",
      CLIP == "https://already.clean/x")
check("...and it says so rather than claiming to have done something",
      ALERTS[#ALERTS]:find("Already clean", 1, true) ~= nil, ALERTS[#ALERTS])

CLIP = "no link here at all" ; ALERTS = {}
HYPER["|k"]()
check("text with no link is untouched and explained",
      CLIP == "no link here at all"
      and ALERTS[#ALERTS]:find("No link", 1, true) ~= nil, ALERTS[#ALERTS])

CLIP = "https://bit.ly/3abc" ; ALERTS = {}
HYPER["|k"]()
check("a shortener EXPLAINS why it will not be expanded, instead of "
      .. "silently doing nothing", ALERTS[#ALERTS]:find("register the click", 1, true) ~= nil,
      ALERTS[#ALERTS])

CLIP = "" ; ALERTS = {}
HYPER["|k"]()
check("an empty clipboard does not crash", ALERTS[#ALERTS]:find("empty", 1, true) ~= nil)

-- =====================================================================
out("\n=== 7. Machine-tunable, and safe on the work Mac ===\n")
-- =====================================================================
C.extraParams = { "ref", "sessionid*" }
eq("extraParams removes what you add per machine",
   "https://github.com/a/b?ref=readme", "https://github.com/a/b")
eq("...including by prefix",
   "https://a.com/?sessionid_abc=1&keep=2", "https://a.com/?keep=2")
C.extraParams = {}
eq("and reverting the setting restores the safe default",
   "https://github.com/a/b?ref=readme", "https://github.com/a/b?ref=readme")

do
    local f = io.open(HS .. "/modules/url_cleaner.lua", "r")
    local body = f:read("*a"):gsub("%-%-[^\n]*", "") ; f:close()
    for _, bad in ipairs({ "sudo", "launchctl", "chown", "io%.open" }) do
        check("url_cleaner uses no " .. bad:gsub("%%", ""), body:find(bad) == nil)
    end
end

out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
