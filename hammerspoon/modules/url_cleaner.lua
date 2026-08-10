-- =====================================================================
-- MODULE: URL CLEANER (⇪K) — the real link, without the marketing cruft
-- =====================================================================
-- Copy a link. Press ⇪K. The clipboard now holds the link the sender
-- actually meant, with the tracking removed and any redirect wrapper
-- unwrapped. ⇪⇧K puts the original back if you did not want that.
--
-- Two different jobs, and they are worth telling apart:
--
--   1. TRACKING PARAMETERS — the ?utm_source=…&fbclid=… tail. Pure string
--      work: chop the known offenders out of the query and leave every
--      other parameter alone.
--   2. REDIRECT WRAPPERS — where the URL you were given is not the
--      destination at all, but a click-counter that CONTAINS the
--      destination, percent-encoded. Outlook Safe Links, Proofpoint,
--      Google's /url?q=, Facebook's l.facebook.com. Unwrapping these is
--      also pure string work, because the real URL is right there in the
--      text you already have.
--
-- ---------------------------------------------------------------------
-- 🚫 WHAT IT DELIBERATELY WILL NOT DO: EXPAND SHORTENERS
-- ---------------------------------------------------------------------
-- bit.ly, t.co, lnkd.in, tinyurl and friends do NOT contain their
-- destination. The only way to learn it is to ask their server — and
-- that is a bad trade twice over:
--
--   · IT REGISTERS THE CLICK. Fetching the redirect tells the tracker
--     exactly what you were trying to avoid telling it. Cleaning a link
--     by pinging the tracker is self-defeating.
--   · IT SENDS THE LINK OFF YOUR MAC. On the work MacBook that means a
--     URL from a work email leaving to a third-party host, from a tool
--     you installed. That is not a decision this module should make
--     quietly on your behalf.
--
-- So this module makes NO NETWORK REQUESTS AT ALL. When it sees a
-- shortener it says so plainly and leaves the link alone, rather than
-- doing nothing and looking broken. Everything it does is offline,
-- instant, and private.
--
-- ---------------------------------------------------------------------
-- 🛟 BLOCKLIST, NEVER ALLOWLIST
-- ---------------------------------------------------------------------
-- Only KNOWN tracking parameters are removed; anything unrecognised is
-- kept. The opposite design — keep only what is known good — looks
-- tidier and quietly breaks real links, because ?v= on YouTube, ?q= on a
-- search, ?id= and ?page= everywhere are load-bearing. A cleaner that
-- occasionally leaves a stray parameter is a nuisance; one that
-- occasionally breaks the link is worse than not having it.
--
-- ⚠️ THE PARAMETERS DELIBERATELY NOT REMOVED, and why, because these look
-- like oversights and are not:
--   · `ref`   — GitHub, Substack and many docs sites use it for real
--               routing. Removing it 404s them.
--   · `s`     — Twitter uses ?s=20 for tracking; hundreds of other sites
--               use ?s= as the SEARCH query. Not worth the collateral.
--   · `si`    — YouTube tracking, but also Spotify's share identifier.
--   · `source`— tracking on some sites, pagination or auth flow on others.
-- Add any of them to cleaner.extraParams if you decide otherwise on a
-- particular machine; that is what the setting is for.

local M = {
    name  = "URL Cleaner",
    order = 13.7,
    cheatsheet = {
        title = "🔗 URL CLEANER (⇪K — the real link, no marketing cruft)",
        entries = {
            { "⇪K",      "Clean the URL on the clipboard, in place" },
            { "⇪⇧K",     "Undo — put the original link back" },
            { "removes", "utm_*, fbclid, gclid, mc_eid, igshid and ~40 more" },
            { "unwraps", "Outlook Safe Links · Proofpoint · Google /url · Facebook" },
            { "won't",   "expand bit.ly & co — that needs a request that REGISTERS" },
            { "",        "the click and sends the link off this Mac. It says so." },
            { "keeps",   "every parameter it does not recognise — never breaks a link" },
            { "text ok", "works on a whole paragraph, cleaning every link in it" },
        },
    },
}

function M.setup(core)
    local cleaner = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    cleaner.enabled     = true
    cleaner.key         = "k"        -- ⇪K clean · ⇪⇧K undo
    cleaner.maxUnwraps  = 6          -- a wrapped-in-a-wrapper chain is real;
                                     -- an unbounded loop on a cyclic one is not
    cleaner.alertSeconds = 2.5
    -- Anything you want removed on THIS Mac beyond the list below. Exact
    -- names, or a trailing * for a prefix: { "ref", "s", "spm*" }
    cleaner.extraParams = {}
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("urlClean", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("urlClean", m) end end

    -- ---- the blocklist ---------------------------------------------------
    -- Exact names first, prefixes second. Grouped by who put them there so
    -- the list stays auditable rather than becoming folklore.
    cleaner.dropExact = {
        -- Facebook / Meta
        "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
        -- Google / DoubleClick
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "gad_source",
        -- Microsoft / Bing
        "msclkid",
        -- Yandex / Twitter / TikTok
        "yclid", "twclid", "ttclid", "ttc_id",
        -- Mailchimp
        "mc_cid", "mc_eid",
        -- HubSpot
        "_hsenc", "_hsmi", "hsctatracking", "__hstc", "__hssc", "__hsfp",
        -- Marketo / Pardot / Eloqua
        "mkt_tok", "pi_ad_id", "pi_campaign_id", "elqtrackid", "elqtrack",
        -- Klaviyo / Vero / Omeda / ConvertKit / Drip
        "_kx", "vero_id", "vero_conv", "oly_anon_id", "oly_enc_id",
        "ck_subscriber_id", "__s",
        -- Instagram
        "igshid", "igsh",
        -- LinkedIn
        "trk", "trkcampaign", "originaltrk", "licu", "lipi",
        -- Reddit / Yahoo / AOL
        "share_id", "correlation_id", "guccounter", "guce_referrer",
        "guce_referrer_sig",
        -- Matomo / Piwik / Open Web Analytics
        "pk_campaign", "pk_kwd", "pk_source", "pk_medium", "pk_content",
        "_openstat", "owa_medium", "owa_source",
        -- Adobe / Webtrends / misc analytics
        "s_cid", "cmpid", "cid", "ncid", "icid", "wickedid", "wickedsource",
        "campaign_id", "adgroupid", "targetid", "matchtype", "device",
        -- Branch / AppsFlyer / Adjust deep-link attribution
        "_branch_match_id", "_branch_referrer", "af_siteid", "adjust_tracker",
        -- Alibaba / AliExpress
        "spm", "scm", "aff_platform", "aff_trace_key",
        -- Amazon associate + session cruft
        "tag", "linkcode", "linkid", "ascsubtag", "psc", "th", "ref_",
        -- Substack / Beehiiv
        "publication_id", "post_id", "isfreemail", "triedredirect",
    }
    cleaner.dropPrefix = { "utm_", "utm-", "pk_", "piwik_", "matomo_",
                           "hsa_", "mtm_", "stm_", "vero_", "at_custom" }

    -- ---- the redirect wrappers ------------------------------------------
    -- host pattern -> the query parameter holding the real URL.
    cleaner.wrappers = {
        { host = "safelinks%.protection%.outlook%.com", param = "url"  },
        { host = "urldefense%.proofpoint%.com",         param = "u",
          -- ⚠️ PROOFPOINT ENCODES DIFFERENTLY, and this is the detail that
          -- makes a naive unwrap produce a broken link: in the v2 scheme
          -- "-" means "%" and "_" means "/". Decode those BEFORE the
          -- ordinary percent-decoding, or you get %3A back as a literal.
          proofpoint = true },
        { host = "urldefense%.com",                     param = "u", proofpoint = true },
        { host = "^www%.google%.[%w.]+$",               param = "q"   },
        { host = "^google%.[%w.]+$",                    param = "q"   },
        { host = "^l%.facebook%.com$",                  param = "u"   },
        { host = "^lm%.facebook%.com$",                 param = "u"   },
        { host = "^l%.instagram%.com$",                 param = "u"   },
        { host = "^out%.reddit%.com$",                  param = "url" },
        { host = "^steamcommunity%.com$",               param = "url" },
        { host = "^www%.youtube%.com$",                 param = "q",
          pathNeeds = "^/redirect" },
        { host = "^href%.li$",                          param = nil   },
        { host = "%.awstrack%.me$",                     param = nil   },
    }

    -- Shorteners: named so the module can EXPLAIN itself instead of
    -- silently doing nothing. It never contacts any of them.
    cleaner.shorteners = {
        "bit%.ly", "t%.co", "lnkd%.in", "tinyurl%.com", "goo%.gl", "ow%.ly",
        "buff%.ly", "rebrand%.ly", "is%.gd", "cutt%.ly", "shorturl%.at",
        "t%.ly", "rb%.gy", "trib%.al", "dlvr%.it", "amzn%.to", "youtu%.be",
        "spoti%.fi", "apple%.co", "nyti%.ms", "wapo%.st", "on%.ft%.com",
    }

    -- =====================================================================
    -- PRIMITIVES
    -- =====================================================================
    local function percentDecode(s)
        -- Note: "+" is NOT turned into a space. That rule belongs to HTML
        -- form encoding, and applying it to a URL extracted from a
        -- parameter corrupts any path or query that legitimately contains
        -- a plus — which Google Docs and many CDNs do.
        return (tostring(s):gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end))
    end

    local function splitURL(url)
        local scheme, rest = url:match("^(%a[%w+.-]*)://(.*)$")
        if not scheme then return nil end
        local hostport, tail = rest:match("^([^/?#]*)(.*)$")
        local path, query, frag = tail:match("^([^?#]*)%??([^#]*)#?(.*)$")
        return { scheme = scheme, host = hostport or "", path = path or "",
                 query = query or "", frag = frag or "" }
    end

    local function joinURL(u)
        local s = u.scheme .. "://" .. u.host .. u.path
        if u.query ~= "" then s = s .. "?" .. u.query end
        if u.frag  ~= "" then s = s .. "#" .. u.frag end
        return s
    end

    local function hostOnly(hostport)
        return (tostring(hostport):gsub(":%d+$", "")):lower()
    end

    -- Ordered list of {name, rawPair} so rebuilding preserves the order the
    -- site chose. Reordering a query is usually harmless and occasionally
    -- is not — signed URLs care.
    local function parseQuery(q)
        local out = {}
        for pair in tostring(q):gmatch("[^&]+") do
            local name = pair:match("^([^=]*)")
            out[#out + 1] = { name = (name or ""):lower(), raw = pair }
        end
        return out
    end

    local function shouldDrop(name)
        for _, n in ipairs(cleaner.dropExact) do if name == n then return true end end
        for _, p in ipairs(cleaner.dropPrefix) do
            if name:sub(1, #p) == p then return true end
        end
        for _, extra in ipairs(cleaner.extraParams or {}) do
            local e = tostring(extra):lower()
            if e:sub(-1) == "*" then
                if name:sub(1, #e - 1) == e:sub(1, #e - 1) then return true end
            elseif name == e then return true end
        end
        return false
    end

    function cleaner.isShortener(url)
        local u = splitURL(url); if not u then return false end
        local h = hostOnly(u.host)
        for _, pat in ipairs(cleaner.shorteners) do
            if h:match("^" .. pat .. "$") or h:match("%." .. pat .. "$") then
                return true, (h:gsub("^www%.", ""))
            end
        end
        return false
    end

    -- =====================================================================
    -- THE TWO TRANSFORMS
    -- =====================================================================
    -- Returns the inner URL if this one is a wrapper, else nil.
    local function unwrapOnce(url)
        local u = splitURL(url); if not u then return nil end
        local h = hostOnly(u.host)
        for _, w in ipairs(cleaner.wrappers) do
            if h:match(w.host) and (not w.pathNeeds or u.path:match(w.pathNeeds)) then
                local candidate
                if w.param then
                    for _, p in ipairs(parseQuery(u.query)) do
                        if p.name == w.param then
                            candidate = p.raw:match("^[^=]*=(.*)$") or ""
                            break
                        end
                    end
                else
                    -- href.li style: the whole thing after "?" IS the URL.
                    candidate = u.query
                end
                if candidate and candidate ~= "" then
                    if w.proofpoint then
                        candidate = candidate:gsub("%-", "%%"):gsub("_", "/")
                    end
                    local inner = percentDecode(candidate)
                    -- Only accept something that is itself a URL. A wrapper
                    -- whose parameter holds a path fragment or an opaque id
                    -- must be left alone rather than turned into nonsense.
                    if inner:match("^https?://") then return inner, h end
                end
                return nil
            end
        end
        -- Generic: a parameter literally named url/redirect/dest/target
        -- whose value is a full URL. Common on ad servers with no
        -- recognisable host. Conservative by construction — the value has
        -- to already look like a URL.
        for _, p in ipairs(parseQuery(u.query)) do
            if p.name == "url" or p.name == "redirect" or p.name == "redirect_uri"
            or p.name == "dest" or p.name == "destination" or p.name == "target"
            or p.name == "r" or p.name == "link" then
                local v = percentDecode(p.raw:match("^[^=]*=(.*)$") or "")
                if v:match("^https?://") and hostOnly(splitURL(v).host) ~= h then
                    return v, h
                end
            end
        end
        return nil
    end

    local function stripParams(url)
        local u = splitURL(url); if not u then return url, 0 end
        if u.query == "" then return url, 0 end
        local kept, removed = {}, 0
        for _, p in ipairs(parseQuery(u.query)) do
            if shouldDrop(p.name) then removed = removed + 1
            else kept[#kept + 1] = p.raw end
        end
        u.query = table.concat(kept, "&")
        return joinURL(u), removed
    end

    -- The whole pipeline for ONE url. Returns cleaned, report table.
    function cleaner.clean(url)
        local report = { unwrapped = {}, removed = 0, shortener = nil,
                         changed = false }
        local current = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if not splitURL(current) then return url, report end

        for _ = 1, cleaner.maxUnwraps do
            local inner, from = unwrapOnce(current)
            if not inner then break end
            report.unwrapped[#report.unwrapped + 1] = from
            current = inner
        end

        local stripped, n = stripParams(current)
        current, report.removed = stripped, n

        -- A query that is now empty leaves a bare "?" — cosmetic, and the
        -- point of this tool is a link you would be happy to paste.
        current = current:gsub("%?$", ""):gsub("#$", "")

        local isShort, name = cleaner.isShortener(current)
        if isShort then report.shortener = name end

        report.changed = (current ~= url)
        return current, report
    end

    -- =====================================================================
    -- WHOLE-TEXT MODE
    -- =====================================================================
    -- If the clipboard is exactly one URL, clean it. If it is prose with
    -- links in it, clean every link and leave the prose alone — which is
    -- what you want after copying a paragraph out of an email.
    function cleaner.cleanText(text)
        local totals = { urls = 0, removed = 0, unwrapped = 0, shorteners = {} }
        local out = tostring(text or ""):gsub("https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
            function(match)
                -- Trailing sentence punctuation is not part of the link.
                -- ")" is only trimmed when unbalanced, because Wikipedia
                -- URLs genuinely end in one.
                local url, trail = match, ""
                while true do
                    local last = url:sub(-1)
                    if last:match("[%.,;:!%?'\"]") then
                        trail = last .. trail ; url = url:sub(1, -2)
                    elseif last == ")" and select(2, url:gsub("%(", "")) < select(2, url:gsub("%)", "")) then
                        trail = last .. trail ; url = url:sub(1, -2)
                    else break end
                end
                local cleaned, rep = cleaner.clean(url)
                totals.urls = totals.urls + 1
                totals.removed = totals.removed + rep.removed
                totals.unwrapped = totals.unwrapped + #rep.unwrapped
                if rep.shortener then
                    totals.shorteners[#totals.shorteners + 1] = rep.shortener
                end
                return cleaned .. trail
            end)
        return out, totals
    end

    -- =====================================================================
    -- THE KEYS
    -- =====================================================================
    cleaner.lastOriginal = nil

    function cleaner.run()
        if not cleaner.enabled then return end
        local ok, text = pcall(hs.pasteboard.getContents)
        if not ok or type(text) ~= "string" or text == "" then
            hs.alert.show("🔗 Clipboard is empty (or is not text)")
            return
        end
        if not text:find("https?://") then
            hs.alert.show("🔗 No link on the clipboard — nothing changed")
            say("no URL in clipboard")
            return
        end

        local cleaned, t = cleaner.cleanText(text)
        if cleaned == text then
            local msg = "🔗 Already clean"
            if #t.shorteners > 0 then
                msg = "🔗 " .. t.shorteners[1] .. " is a shortener — the real "
                    .. "destination is only on their server.\nExpanding it would "
                    .. "register the click and send the link off this Mac, so "
                    .. "this does not do it."
            end
            hs.alert.show(msg, cleaner.alertSeconds)
            say("no change (" .. t.urls .. " url(s))")
            return
        end

        cleaner.lastOriginal = text
        local okSet = pcall(hs.pasteboard.setContents, cleaned)
        if not okSet then
            hs.alert.show("🔗 Could not write to the clipboard")
            warn("pasteboard write failed")
            return
        end

        local bits = {}
        if t.unwrapped > 0 then bits[#bits + 1] = t.unwrapped .. " redirect unwrapped" end
        if t.removed  > 0 then bits[#bits + 1] = t.removed .. " tracker removed" end
        local what = (#bits > 0) and table.concat(bits, " · ") or "tidied"
        if t.urls > 1 then what = what .. "  (" .. t.urls .. " links)" end
        hs.alert.show("🔗 " .. what .. "  —  ⇪⇧K undoes", cleaner.alertSeconds)
        say(what)
    end

    function cleaner.undo()
        if not cleaner.lastOriginal then
            hs.alert.show("🔗 Nothing to undo")
            return
        end
        local ok = pcall(hs.pasteboard.setContents, cleaner.lastOriginal)
        if ok then
            hs.alert.show("🔗 Original link restored")
            say("undo")
            cleaner.lastOriginal = nil
        else
            hs.alert.show("🔗 Could not write to the clipboard")
        end
    end

    -- A Console helper, so you can see what it WOULD do without touching
    -- the clipboard — the fastest way to check a rule before trusting it.
    function _G.urlCleanTest(url)
        local cleaned, rep = cleaner.clean(url)
        print("🔗 in  : " .. tostring(url))
        print("   out : " .. tostring(cleaned))
        print(("   %d tracker(s) removed, %d wrapper(s) unwrapped%s"):format(
            rep.removed, #rep.unwrapped,
            rep.shortener and (", shortener: " .. rep.shortener) or ""))
        return cleaned
    end

    if cleaner.enabled then
        core.hyperAddShortcut({}, cleaner.key, cleaner.run, "url cleaner")
        core.hyperAddShortcut({ "shift" }, cleaner.key, cleaner.undo,
                              "url cleaner — undo")
    end

    -- url.clean is the PURE function and takes a URL; these two are the
    -- key actions, which read and write the clipboard on their own.
    core.provide("url.cleanClipboard", function() return cleaner.run()  end)
    core.provide("url.undo",           function() return cleaner.undo() end)
    core.provide("url.clean",     function(u) return (cleaner.clean(u)) end)
    core.provide("url.cleanText", function(t) return (cleaner.cleanText(t)) end)

    _G.urlCleaner = cleaner
    M.cleaner = cleaner
    M.config  = cleaner
end

return M
