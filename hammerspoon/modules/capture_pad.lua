-- =====================================================================
-- MODULE: CAPTURE PAD (⇪N) — jot all day, everything lands in Asana at 4 PM
-- =====================================================================
-- ⇪N opens a pad. Type a note, ⌘⏎ files it. ⌘⇧V pins whatever image is on
-- the clipboard to the note you are writing. Nothing leaves the machine
-- while you work. At 16:00 every queued note becomes an Asana task in
-- your project, its images become attachments, and the queue empties.
-- ⇪⇧N sends the queue immediately if you would rather not wait.
--
-- ---------------------------------------------------------------------
-- HOW A NOTE BECOMES A TASK TITLE
-- ---------------------------------------------------------------------
-- Two shapes, and which one you get depends on whether the note actually
-- asks for something to be done:
--
--   "Verb + rest of task"      when the sentence is an instruction
--       "Email Dana the Q3 numbers"  →  Email Dana the Q3 numbers
--       "need to renew the SSL cert" →  Renew the SSL cert
--
--   "Note :: rest of the note"  for everything else
--       "Dana prefers Thursdays"     →  Note :: Dana prefers Thursdays
--
-- Both are capped at 10 words; anything past that, and every image, goes
-- into the Asana description instead, so nothing is lost and no title is
-- a paragraph.
--
-- ⚠️ WHERE THIS IS A GUESS, AND WHAT TO DO ABOUT IT. Deciding whether an
-- English sentence "clearly indicates action" is a judgement call, and
-- this makes it with a word list, so it will be wrong sometimes. The two
-- honest failure modes:
--   • "Call with Dana Tuesday" — "call" is a NOUN here. Handled: a verb
--     followed by with/from/at/is/was/about is treated as a noun (see
--     NOUNISH below), because those words do not follow an imperative.
--   • "Ship it" vs "Ship of Theseus" — no word list settles that.
-- So there is a manual override that always wins, and it is one keystroke:
--       start the note with  !   to FORCE  Verb + rest
--       start the note with  ?   to FORCE  Note ::
-- Everything else is the word list's best guess, and the list is right
-- there in this file to edit.
--
-- 🔐 THE ASANA TOKEN NEVER APPEARS IN AN ARGUMENT LIST. Uploading an
-- attachment needs curl (Asana wants multipart, hs.http does not speak
-- it), and `curl -H "Authorization: Bearer …"` puts your token in the
-- process table where any process on the Mac can read it with ps. The
-- header is fed to curl on STDIN via `-H @-` instead. If that fails the
-- upload is abandoned rather than retried the unsafe way.
--
-- 🐛 6.44.1 — WHY EVERY ATTACHMENT WAS SILENTLY FAILING. Two bugs, both
-- in uploadAttachment below, both now fixed and covered by a test:
--   1. setInput() was called AFTER start(). The Hammerspoon docs say
--      setInput "can be called before the task has been started, to
--      prepare some input for it" — that phrasing is deliberate: for a
--      non-streaming task (this one has no streamCallbackFn) the stdin
--      pipe is wired up from whatever was already queued at start time.
--      Called after, the data missed the window: curl read stdin, got
--      an immediate EOF, and posted with NO Authorization header at
--      all. Asana correctly returned 401, which curl still reports as
--      exit code 0 — curl only fails on a TRANSPORT error, never on an
--      HTTP error status — so the upload "succeeded" and quietly did
--      nothing.
--   2. The failure branch printed `tostring(err or out)`, meant to
--      prefer stderr and fall back to the response body. Lua's `or`
--      doesn't work that way when err is an empty string: "" is TRUTHY
--      in Lua (only nil and false are falsy), so `err or out` always
--      picked err — silently, every time, even when it was "" and out
--      held the actual 401 body. That is why the Console showed
--      "attachment failed (curl 0) for …" with nothing after the dash.
--
-- 💾 NOTHING IS DELETED BEFORE IT IS DELIVERED. A note leaves the queue
-- only after Asana returns the new task's gid. A failed send is kept and
-- retried at the next flush, up to capturePad.maxRetries, after which it
-- is parked and shown in the pad rather than dropped.

local M = {
    name  = "Capture Pad",
    order = 13.1,
    cheatsheet = {
        title = "🗒 CAPTURE PAD (⇪N — collect now, Asana at 4 PM)",
        entries = {
            { "⇪N",   "Open / close the pad" },
            { "⌘⏎",   "File the note you are typing" },
            { "⌘⇧V",  "Attach the clipboard image to the note you are typing" },
            { "✕",     "On a pinned thumbnail — removes just that image before you file" },
            { "⇪⇧N",  "Send the whole queue to Asana right now" },
            { "16:00", "Automatic: every queued note becomes a task in your project" },
            { "title", "\"Verb + rest\" if it asks for an action, else \"Note :: rest\"" },
            { "",      "10 words max — the rest, and every image, go in the description" },
            { "! / ?", "Start a note with ! to force a task, ? to force a note" },
            { "Esc",   "Close the pad (the queue is kept on disk)" },
        },
    },
}

function M.setup(core)
    local pad = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    pad.enabled    = true
    pad.sendAt     = "16:00"     -- 24h clock. The daily flush.
    pad.titleWords = 10          -- the cap you asked for
    pad.notePrefix = "Note :: "  -- exactly as specified, spaces included
    pad.maxRetries = 3           -- failed sends parked after this many tries
    pad.projectId  = nil         -- nil = use core.asanaProjectId from init.lua
    pad.width, pad.height = 760, 700
    pad.key        = "n"
    pad.maxImagesPerNote = 8
    pad.maxQueue   = 200         -- a bounded queue; see the note on flush()
    pad.uploadTimeout = 60       -- seconds curl may spend on one attachment
    pad.flushTimeout  = 300      -- seconds a whole flush may take before the
                                 -- "already sending" latch is force-cleared
    -- ----------------------------------------------------------------------

    pad.dir      = (core.logsDir or core.homeDir) .. "/capture-pad"
    pad.imageDir = pad.dir .. "/images"
    pad.file     = pad.dir .. "/queue.json"
    pad.queue    = {}     -- notes waiting for 16:00
    pad.parked   = {}     -- notes that failed maxRetries times
    pad.draft    = ""     -- what is in the textarea, kept across redraws
    pad.draftImages = {}  -- images pinned to the note being typed
    pad.webview  = nil    -- HELD
    pad.uc       = nil    -- HELD: the JS→Lua message port
    pad.timer    = nil    -- HELD: the 16:00 flush
    pad.sending  = false  -- one flush at a time

    -- =====================================================================
    -- TITLE RULES
    -- =====================================================================
    -- Imperatives that start a work note. Deliberately NOT here: "note"
    -- (it collides with the Note :: form), and bare "meeting"/"update"
    -- style words that are nouns far more often than verbs.
    local ACTION_VERBS = {}
    for _, v in ipairs({
        "add","adjust","align","announce","answer","apply","approve","arrange","ask",
        "assign","attach","audit","block","book","budget","build","buy","call","cancel",
        "change","chase","check","clarify","clean","clear","close","collect","compare",
        "compile","complete","confirm","connect","contact","continue","copy","correct",
        "create","cut","debug","decide","delete","deliver","deploy","design","document",
        "double-check","draft","drop","edit","email","enable","ensure","escalate",
        "estimate","expand","explain","export","extend","file","fill","find","finish",
        "fix","follow","forward","gather","generate","get","give","hire","implement",
        "import","improve","install","invite","investigate","invoice","join","kill",
        "launch","learn","leave","link","list","load","lock","look","mail","make",
        "measure","meet","merge","message","migrate","move","open","order","organise",
        "organize","pay","phone","pick","pin","plan","post","prepare","present","print",
        "process","publish","pull","push","raise","read","rebuild","recheck","record",
        "reduce","refactor","register","reinstall","remind","remove","rename","renew",
        "reorder","repair","replace","reply","report","request","research","reset",
        "resolve","respond","restart","restore","review","revise","rewrite","run",
        "schedule","send","set","settle","setup","share","ship","sign","simplify",
        "sort","split","start","stop","submit","subscribe","swap","switch","sync",
        "tell","test","tidy","track","train","transfer","translate","trim","try",
        "unblock","uninstall","unlock","update","upgrade","upload","validate","verify",
        "visit","wait","watch","write",
    }) do ACTION_VERBS[v] = true end

    -- A word that follows a real imperative is an object or a preposition of
    -- direction ("send it to…", "call Dana"). These follow a NOUN instead —
    -- "call WITH Dana", "email FROM legal", "review IS due" — so seeing one
    -- immediately after a candidate verb flips the verdict back to Note.
    local NOUNISH = {}
    for _, v in ipairs({
        "with","from","is","was","are","were","at","about","re","went","happened",
        "said","says","looks","seems","today","tomorrow","yesterday","tonight",
    }) do NOUNISH[v] = true end

    -- Phrases that ARE an instruction but bury the verb. The capture is the
    -- verb, so "I need to renew the cert" becomes "Renew the cert" — the
    -- "Verb + rest of task" shape you asked for, not "I need to…".
    local LEAD_INS = {
        "^i +need +to +", "^we +need +to +", "^need +to +", "^needs +to +",
        "^i +have +to +", "^we +have +to +", "^have +to +",
        "^i +should +", "^we +should +", "^should +",
        "^i +must +", "^we +must +", "^must +",
        "^remember +to +", "^don'?t +forget +to +", "^dont +forget +to +",
        "^make +sure +to +", "^make +sure +", "^be +sure +to +",
        "^todo *[:%-] *", "^to +do *[:%-] *", "^action *[:%-] *",
    }

    local function words(s)
        local out = {}
        for w in tostring(s or ""):gmatch("%S+") do table.insert(out, w) end
        return out
    end

    local function firstNWords(s, n)
        local w = words(s)
        if #w <= n then return table.concat(w, " "), false end
        local keep = {}
        for i = 1, n do keep[i] = w[i] end
        return table.concat(keep, " "), true
    end

    local function capitaliseFirst(s)
        return (tostring(s or ""):gsub("^%l", string.upper))
    end

    -- A note is often a paragraph; the title is its opening thought and
    -- everything else is what the description is for. These are two steps,
    -- not one, and the ORDER matters — see stripMarkers below.
    local function firstLine(text)
        for l in tostring(text or ""):gmatch("[^\r\n]+") do
            if l:gsub("%s+", "") ~= "" then
                return (l:gsub("^%s+", ""):gsub("%s+$", ""))
            end
        end
        return ""
    end

    local function firstSentence(line)
        -- Split on . ! ? ; — searching from character 2, never 1. A note
        -- that opens with the "!" override IS a "!" followed by a space, so
        -- searching from the start would cut the sentence down to the
        -- override character and throw the note away. That is not
        -- hypothetical; it is what the first version of this did.
        local cut = line:find("[%.!%?;]%s", 2)
        if cut then line = line:sub(1, cut) end
        return (line:gsub("[%.!%?;,%s]+$", ""))
    end

    -- Strip the list markers people type without thinking. Returns the
    -- cleaned sentence and a forced verdict ("action", "note" or nil).
    local function stripMarkers(sentence)
        local forced = nil
        local s = sentence
        s = s:gsub("^%s*[%-%*•]%s*", "")
        s = s:gsub("^%s*%[[ xX]%]%s*", "")
        s = s:gsub("^%s*#+%s*", "")
        if s:sub(1, 1) == "!" then
            forced = "action"; s = s:gsub("^!+%s*", "")
        elseif s:sub(1, 1) == "?" then
            forced = "note";   s = s:gsub("^%?+%s*", "")
        end
        if s:lower():match("^todo%s*[:%-]") or s:lower():match("^action%s*[:%-]") then
            forced = forced or "action"
        end
        if s:lower():match("^note%s*[:%-]") then
            forced = forced or "note"
            s = s:gsub("^[Nn][Oo][Tt][Ee]%s*[:%-]%s*", "")
        end
        return (s:gsub("^%s+", "")), forced
    end

    -- The whole decision, in one testable function.
    -- Returns: title, kind ("action" | "note"), truncated
    --
    -- Markers come off BEFORE the sentence split, never after: "!" and "?"
    -- are both sentence-enders as well as overrides, so splitting first
    -- would treat the override as the end of a one-character sentence.
    function pad.titleFor(text)
        local sentence, forced = stripMarkers(firstLine(text))
        sentence = firstSentence(sentence)
        if sentence == "" then
            return pad.notePrefix .. "(empty note)", "note", false
        end

        local body, kind = sentence, forced

        if kind ~= "note" then
            -- A lead-in ("I need to …") is stripped so the VERB starts the
            -- title. Only the first match applies; they are alternatives,
            -- not layers.
            local stripped
            for _, pat in ipairs(LEAD_INS) do
                local s2, n = body:lower():gsub(pat, "")
                if n > 0 then
                    -- Re-cut the ORIGINAL string at the same offset so the
                    -- rest keeps its capitals ("renew the SSL cert", not
                    -- "renew the ssl cert").
                    stripped = body:sub(#body - #s2 + 1)
                    break
                end
            end
            if stripped and stripped:gsub("%s+", "") ~= "" then
                body = stripped
                kind = kind or "action"
            end
        end

        if not kind then
            local w = words(body)
            local first  = (w[1] or ""):lower():gsub("[^%a%-']", "")
            local second = (w[2] or ""):lower():gsub("[^%a%-']", "")
            if ACTION_VERBS[first] and not NOUNISH[second] then
                kind = "action"
            else
                kind = "note"
            end
        end

        local trimmed, truncated = firstNWords(body, pad.titleWords)
        if kind == "action" then
            return capitaliseFirst(trimmed) .. (truncated and "…" or ""), "action", truncated
        end
        return pad.notePrefix .. trimmed .. (truncated and "…" or ""), "note", truncated
    end

    -- The description. Empty string means "no description needed", which is
    -- the case for a short note with no images and nothing cut off.
    function pad.descriptionFor(note)
        local title, _, truncated = pad.titleFor(note.text)
        local textWords = #words(note.text)
        local multiline = tostring(note.text):find("[\r\n]") ~= nil
        local needsBody = truncated or multiline or textWords > pad.titleWords
        local parts = {}
        if needsBody then table.insert(parts, note.text) end
        if #(note.images or {}) > 0 then
            table.insert(parts, string.format("%d image%s attached.",
                #note.images, #note.images == 1 and "" or "s"))
        end
        if #parts == 0 then return "" end
        table.insert(parts, string.format("— captured %s on %s",
            os.date("%Y-%m-%d %H:%M", note.createdAt or os.time()),
            core.hostTag or "this Mac"))
        local _ = title
        return table.concat(parts, "\n\n")
    end

    -- =====================================================================
    -- QUEUE, ON DISK
    -- =====================================================================
    local function ensureDirs()
        for _, d in ipairs({ pad.dir, pad.imageDir }) do
            if hs.fs.attributes(d) == nil then pcall(hs.fs.mkdir, d) end
        end
    end

    function pad.save()
        ensureDirs()
        local blob = hs.json.encode({ queue = pad.queue, parked = pad.parked })
        local f = io.open(pad.file, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("capture pad queue") end
            return false
        end
        local okW = pcall(function() f:write(blob) end)
        local okC = pcall(function() f:close() end)
        if not (okW and okC) then
            if core.warnWriteFailed then core.warnWriteFailed("capture pad queue") end
            return false
        end
        return true
    end

    function pad.load()
        local f = io.open(pad.file, "r")
        if not f then return end
        local blob = f:read("a"); f:close()
        -- safeJson, never hs.json.decode directly: a half-written file
        -- raises, and a raise here would take the whole module's setup down.
        local data = _G.safeJson(blob, "capturePad/queue")
        if type(data) ~= "table" then return end
        pad.queue  = type(data.queue)  == "table" and data.queue  or {}
        pad.parked = type(data.parked) == "table" and data.parked or {}
        _G.diag.say("capturePad", string.format("loaded %d queued, %d parked",
                                                #pad.queue, #pad.parked))
    end

    local function newId()
        return string.format("%d-%04d", os.time(), math.random(0, 9999))
    end

    function pad.addNote(text, images)
        text = tostring(text or ""):gsub("%s+$", "")
        if text:gsub("%s+", "") == "" and #(images or {}) == 0 then
            return false, "nothing to file"
        end
        if #pad.queue >= pad.maxQueue then
            return false, string.format(
                "the queue is full (%d) — send it with ⇪⇧N first", pad.maxQueue)
        end
        local note = {
            id = newId(), text = text, createdAt = os.time(),
            images = images or {}, tries = 0,
        }
        table.insert(pad.queue, note)
        pad.save()
        _G.diag.say("capturePad", "queued: " .. (pad.titleFor(text)))
        return true, note
    end

    function pad.removeNote(id)
        for i = #pad.queue, 1, -1 do
            if pad.queue[i].id == id then table.remove(pad.queue, i) end
        end
        for i = #pad.parked, 1, -1 do
            if pad.parked[i].id == id then table.remove(pad.parked, i) end
        end
        pad.save()
    end

    -- =====================================================================
    -- IMAGES — taken from the macOS clipboard by Lua, never by the webview
    -- =====================================================================
    -- A WKWebView can be made to intercept a paste and hand back a data URI,
    -- but it only sees what the web content model calls an image, which is
    -- not the same set as what macOS puts on the pasteboard (a Preview crop,
    -- a Finder file promise, a screenshot straight off ⌘⇧4). Reading
    -- hs.pasteboard directly gets all of them, and the webview is then only
    -- ever asked to display a thumbnail we generated ourselves.
    function pad.attachClipboardImage()
        local img = hs.pasteboard.readImage()
        if not img then
            pad.toast("No image on the clipboard — copy one first (⌘⇧4 then ⌘V here)")
            return false
        end
        if #pad.draftImages >= pad.maxImagesPerNote then
            pad.toast("That is " .. pad.maxImagesPerNote .. " images — file this note first")
            return false
        end
        ensureDirs()
        local path = pad.imageDir .. "/" .. newId() .. ".png"
        local ok = false
        pcall(function() ok = img:saveToFile(path, "PNG") end)
        if not ok then
            pad.toast("Could not save that image — see the Console")
            print("🗒 Capture Pad: saveToFile failed for " .. path)
            return false
        end
        table.insert(pad.draftImages, path)
        _G.diag.say("capturePad", "attached image " .. path)
        pad.render()
        return true
    end

    -- =====================================================================
    -- SENDING
    -- =====================================================================
    -- Attachments go through curl because Asana wants multipart/form-data
    -- and hs.http cannot build it. `-H @-` tells curl to read ONE header
    -- line off stdin — simpler than the old `-K` config-file syntax, which
    -- needed exact `key = "value"` quoting and gave no sign at all when a
    -- mismatch dropped the header silently.
    local function uploadAttachment(taskGid, path, onDone)
        if hs.fs.attributes(path) == nil then
            print("🗒 Capture Pad: image vanished before upload — " .. path)
            if onDone then onDone(false) end
            return
        end
        local url = "https://app.asana.com/api/1.0/tasks/" .. taskGid .. "/attachments"

        local okNew, t = pcall(hs.task.new, "/usr/bin/curl", function(code, out, err)
            -- `-w "\n%{http_code}"` appends the REAL HTTP status after
            -- whatever curl wrote to stdout, so success is verified against
            -- that status rather than by guessing from the body — curl exits
            -- 0 on a 401 just as readily as on a 201, since it only fails on
            -- a transport error, never an HTTP one.
            local body, status = tostring(out or ""), nil
            local statusStr = body:match("\n(%d%d%d)%s*$")
            if statusStr then
                status = tonumber(statusStr)
                body = body:sub(1, #body - #statusStr - 1)
            end
            local ok = (code == 0) and (status == 200 or status == 201)
            if not ok then
                -- out (the response body) is shown FIRST, not `err or out` —
                -- err is "" on a plain HTTP failure, and "" is truthy in
                -- Lua, so `err or out` was silently choosing the empty
                -- string over the body that actually explained the failure.
                local detail = body ~= "" and body or (err ~= "" and err or "no response")
                print(string.format(
                    "🗒 Capture Pad: attachment failed (curl exit %s, HTTP %s) for %s — %s",
                    tostring(code), tostring(status or "?"), path, detail))
            end
            if onDone then onDone(ok) end
        -- --max-time is not decoration. Every callback in this file is
        -- chained: a curl that never returns means the note that owns it is
        -- never removed AND pad.sending is never cleared, so the pad stops
        -- flushing for the rest of the day with nothing on screen to say why.
        -- A bounded upload turns that into one reported failure.
        end, { "-s", "--max-time", tostring(pad.uploadTimeout),
               "-X", "POST", "-H", "@-", "-F", "file=@" .. path,
               "-w", "\n%{http_code}", url })
        if not (okNew and t) then
            print("🗒 Capture Pad: could not start curl for " .. path)
            if onDone then onDone(false) end
            return
        end

        -- ⚠️ setInput() BEFORE start(), never after — see the 6.44.1 note at
        -- the top of this file. This is a non-streaming task (no
        -- streamCallbackFn), so per the Hammerspoon docs stdin is wired up
        -- from whatever was already queued when the task starts; fed after,
        -- the data misses the window entirely.
        local fed = pcall(function()
            t:setInput("Authorization: Bearer " .. core.asanaToken .. "\n")
        end)
        if not fed then
            print("🗒 Capture Pad: could not pass the token to curl safely — "
                  .. "attachment skipped, the image is still at " .. path)
            if onDone then onDone(false) end
            return
        end

        -- closeInput() is deliberately NOT called: the docs say it is only
        -- for a task with a STREAMING callback, and this one has none —
        -- stdin closes on its own once the data from setInput() is written.
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            print("🗒 Capture Pad: curl would not start for " .. path)
            if onDone then onDone(false) end
        end
    end

    local function createTask(note, onDone)
        local title = pad.titleFor(note.text)
        local desc  = pad.descriptionFor(note)
        local data  = { name = title }
        if desc ~= "" then data.notes = desc end
        local project = pad.projectId or core.asanaProjectId
        if project and project ~= "" then
            data.projects = { project }
        elseif core.asanaWorkspaceId then
            data.workspace = core.asanaWorkspaceId
        end

        hs.http.asyncPost("https://app.asana.com/api/1.0/tasks",
            hs.json.encode({ data = data }),
            { ["Authorization"] = "Bearer " .. core.asanaToken,
              ["Content-Type"]  = "application/json" },
            function(status, body)
                if status ~= 200 and status ~= 201 then
                    print("🗒 Capture Pad: task creation failed (HTTP " ..
                          tostring(status) .. ") — " .. tostring(body))
                    onDone(false)
                    return
                end
                local parsed = _G.safeJson(body, "capturePad/task")
                local gid = parsed and parsed.data and parsed.data.gid
                if not gid then
                    print("🗒 Capture Pad: Asana accepted the task but returned no gid")
                    onDone(false)
                    return
                end
                local images = note.images or {}
                if #images == 0 then onDone(true, gid, 0) return end
                -- Attachments are best-effort AND SEQUENTIAL: eight parallel
                -- curls against one endpoint is how you earn a 429. The task
                -- is already created, so a failed image is reported and the
                -- file is left on disk rather than costing you the note.
                --
                -- imagesFailed travels back to the caller: a note whose task
                -- was created but whose image did NOT attach must never be
                -- reported as a clean "sent" — that silence is exactly what
                -- made the 6.44.0 curl bug invisible until you went looking
                -- in Asana yourself.
                local i, imagesFailed = 0, 0
                local function nextImage()
                    i = i + 1
                    if i > #images then onDone(true, gid, imagesFailed) return end
                    uploadAttachment(gid, images[i], function(ok)
                        if not ok then imagesFailed = imagesFailed + 1 end
                        nextImage()
                    end)
                end
                nextImage()
            end)
    end

    -- One flush, one note at a time, sequentially. Sequential is the point:
    -- thirty parallel task creations is a burst Asana rate-limits, and a
    -- rate-limited flush loses the ordering that makes the queue readable.
    function pad.flush(reason)
        if pad.sending then
            _G.diag.say("capturePad", "flush already running — ignored")
            return
        end
        if not core.asanaEnabled then
            hs.alert.show("🗒 Capture Pad: no Asana token — the queue is kept, nothing sent")
            return
        end
        if #pad.queue == 0 then
            if reason == "manual" then hs.alert.show("🗒 Capture Pad: nothing queued") end
            return
        end

        pad.sending = true
        local total, sent, failed, imagesFailed = #pad.queue, 0, 0, 0
        _G.diag.say("capturePad", string.format("flush (%s): %d notes", reason or "auto", total))

        local done = false
        local function finish(why)
            if done then return end
            done = true
            pad.sending = false
            if pad.watchdog then
                pcall(function() pad.watchdog:stop() end)
                pad.watchdog = nil
            end
            pad.save()
            pad.render()
            local msg = string.format("🗒 Capture Pad → Asana: %d sent", sent)
            if failed > 0 then msg = msg .. ", " .. failed .. " kept for next time" end
            if imagesFailed > 0 then
                msg = msg .. string.format(" (⚠️ %d image%s did not attach — see Console)",
                    imagesFailed, imagesFailed == 1 and "" or "s")
            end
            if why then msg = msg .. " (" .. why .. ")" end
            hs.alert.show(msg, 4)
            print(msg)
        end

        -- The whole flush is a chain of network callbacks, and a chain has
        -- one failure mode a single call does not: if any link never fires,
        -- pad.sending stays true and every later flush — including tomorrow's
        -- 4 PM one — is silently ignored. The watchdog is what stops one
        -- wedged request costing you every send after it. HELD, like every
        -- other timer here.
        pad.watchdog = hs.timer.doAfter(pad.flushTimeout, function()
            if not done then
                print("🗒 Capture Pad: flush ran past " .. pad.flushTimeout ..
                      "s — unlatching so the next one can run. Nothing was lost.")
                finish("timed out")
            end
        end)

        local function step()
            local note = pad.queue[1]
            if not note then finish() return end
            createTask(note, function(ok, gid, imgFailed)
                if ok then
                    sent = sent + 1
                    if imgFailed and imgFailed > 0 then
                        imagesFailed = imagesFailed + imgFailed
                        print(string.format(
                            "🗒 Capture Pad: task created but %d of %d image(s) did not "
                            .. "attach — %s (task still exists in Asana, gid %s)",
                            imgFailed, #(note.images or {}), pad.titleFor(note.text),
                            tostring(gid)))
                    end
                    table.remove(pad.queue, 1)
                else
                    failed = failed + 1
                    note.tries = (note.tries or 0) + 1
                    table.remove(pad.queue, 1)
                    if note.tries >= pad.maxRetries then
                        note.parkedAt = os.time()
                        table.insert(pad.parked, note)
                        print("🗒 Capture Pad: parked after " .. note.tries ..
                              " failed sends — " .. pad.titleFor(note.text))
                    else
                        -- Back of the queue, not the front: one poisonous
                        -- note must not block the twenty behind it.
                        table.insert(pad.queue, note)
                    end
                end
                pad.save()
                -- The re-queue above means #pad.queue can stay level, so the
                -- loop is bounded by the number of notes we started with
                -- rather than by the queue emptying.
                if sent + failed >= total then finish() return end
                step()
            end)
        end
        step()
    end

    -- =====================================================================
    -- THE PAD ITSELF
    -- =====================================================================
    function pad.toast(msg)
        hs.alert.show("🗒 " .. msg, 3)
    end

    local function escapeHtml(s)
        return (tostring(s or "")
            :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            :gsub('"', "&quot;"))
    end

    -- Thumbnails are data: URIs generated here rather than file:// links.
    -- A WKWebView loaded from an html string has no file access at all, so
    -- a file:// image would silently show as a broken picture.
    local function thumbFor(path)
        local img = hs.image.imageFromPath(path)
        if not img then return nil end
        local ok, uri = pcall(function()
            return img:setSize({ w = 120, h = 90 }):encodeAsURLString()
        end)
        return ok and uri or nil
    end

    local function buildHtml()
        local rows = {}
        for _, n in ipairs(pad.queue) do
            local title, kind = pad.titleFor(n.text)
            table.insert(rows, string.format(
                '<li class="%s"><span class="k">%s</span><span class="t">%s</span>'
                .. '<span class="m">%s%s</span></li>',
                kind, kind == "action" and "TASK" or "NOTE", escapeHtml(title),
                os.date("%H:%M", n.createdAt or os.time()),
                #(n.images or {}) > 0 and ("  ·  " .. #n.images .. " img") or ""))
        end
        local parked = ""
        if #pad.parked > 0 then
            parked = string.format(
                '<p class="parked">⚠️ %d note%s could not be sent after %d tries — '
                .. 'they are kept in queue.json, not lost.</p>',
                #pad.parked, #pad.parked == 1 and "" or "s", pad.maxRetries)
        end
        -- Each thumbnail carries its own ✕, calling removeImg(i) with a
        -- 1-based index — so a wrongly pinned image can be taken back off
        -- the note before you file it, instead of sitting there uncertain
        -- whether it is really attached.
        local thumbs = {}
        for i, p in ipairs(pad.draftImages) do
            local uri = thumbFor(p)
            if uri then
                table.insert(thumbs, '<span class="thumb"><img src="' .. uri
                    .. '"><button type="button" class="x" onclick="removeImg(' .. i
                    .. ')" title="Remove this image">×</button></span>')
            else
                table.insert(thumbs, '<span class="thumb badimg">?<button type="button" '
                    .. 'class="x" onclick="removeImg(' .. i
                    .. ')" title="Remove this image">×</button></span>')
            end
        end

        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:15px; line-height:1.5; background:#141418; color:#e8e8ec; }
  header { padding:14px 18px 8px; display:flex; justify-content:space-between;
           align-items:baseline; border-bottom:1px solid #2a2a32; }
  h1 { font-size:16px; margin:0; font-weight:600; }
  .hint { color:#8a8a96; font-size:13px; }
  #wrap { padding:14px 18px; }
  /* 🐛 6.44.1 — the textarea used to set its font with the `font`
     shorthand, a fixed pixel size mixed on the same line with the global
     keyword that means "same as my parent" — a combination the CSS spec
     does not allow, since that keyword is only valid as the shorthand's
     ENTIRE value. WebKit drops an invalid shorthand rule outright rather
     than partially applying it, so the textarea fell back to its default
     (small, monospace) no matter what size was written there. Longhand
     font-family / font-size below, so there is nothing left to parse as
     one disallowed combination. */
  textarea { width:100%; box-sizing:border-box; height:180px; resize:vertical;
             background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
             border-radius:8px; padding:12px;
             font-family:-apple-system,BlinkMacSystemFont,sans-serif;
             font-size:16px; line-height:1.5; }
  textarea:focus { outline:none; border-color:#4a7fe0; }
  textarea::placeholder { color:#5c5c68; }
  #thumbs { display:flex; gap:10px; flex-wrap:wrap; margin-top:10px; padding:4px 6px 0 0; }
  .thumb { position:relative; display:inline-block; line-height:0; }
  .thumb img { height:64px; border-radius:6px; border:1px solid #33333e; }
  .thumb .x { position:absolute; top:-7px; right:-7px; width:20px; height:20px;
              border-radius:50%; background:#8a2b25; color:#fff; border:1px solid #141418;
              font-size:13px; line-height:18px; padding:0; cursor:pointer; }
  .thumb .x:hover { background:#c0392b; }
  .badimg { width:64px; height:64px; line-height:64px !important;
            text-align:center; background:#2a2a32; border-radius:6px; color:#888;
            font-size:15px; }
  .bar { margin-top:12px; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:7px 13px; font-size:14px; cursor:pointer; }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  button:hover { filter:brightness(1.18); }
  h2 { font-size:12px; text-transform:uppercase; letter-spacing:.08em;
       color:#7c7c88; margin:22px 0 8px; }
  ul { list-style:none; margin:0; padding:0; }
  li { display:flex; gap:10px; align-items:baseline; padding:8px 10px;
       border-radius:7px; background:#1b1b22; margin-bottom:5px; font-size:15px; }
  .k { font-size:10px; font-weight:700; letter-spacing:.06em; padding:2px 6px;
       border-radius:4px; flex:none; }
  li.action .k { background:#2f5d3a; color:#9de8b0; }
  li.note   .k { background:#3a3550; color:#c3b6ee; }
  .t { flex:1; }
  .m { color:#75757f; font-size:13px; flex:none; }
  .parked { color:#e8b06a; font-size:13px; }
  .empty { color:#6d6d78; font-style:italic; }
</style>
<header>
  <h1>🗒 Capture Pad</h1>
  <span class="hint">⌘⏎ file · ⌘⇧V image · sends at ]] .. escapeHtml(pad.sendAt) .. [[</span>
</header>
<div id="wrap">
  <textarea id="t" placeholder="Type a note. Start with ! to force a task, ? to force a note."
            autofocus>]] .. escapeHtml(pad.draft) .. [[</textarea>
  <div id="thumbs">]] .. table.concat(thumbs) .. [[</div>
  <div class="bar">
    <button class="go" onclick="fileIt()">File it &nbsp;⌘⏎</button>
    <button onclick="say({a:'image'})">Attach clipboard image &nbsp;⌘⇧V</button>
    <button onclick="say({a:'flush'})">Send now</button>
    <span class="hint">]] .. #pad.queue .. [[ queued</span>
  </div>
  <h2>Waiting for ]] .. escapeHtml(pad.sendAt) .. [[</h2>
  ]] .. parked .. [[
  ]] .. (#rows > 0 and ("<ul>" .. table.concat(rows) .. "</ul>")
                   or '<p class="empty">Nothing queued yet.</p>') .. [[
</div>
<script>
  function say(m){ window.webkit.messageHandlers.capturePad.postMessage(m); }
  var t = document.getElementById('t');
  function fileIt(){ say({a:'add', text:t.value}); }
  function removeImg(i){ say({a:'removeImage', index:i, text:t.value}); }
  window.addEventListener('keydown', function(e){
    if (e.metaKey && e.key === 'Enter') { e.preventDefault(); fileIt(); }
    else if (e.metaKey && e.shiftKey && (e.key === 'v' || e.key === 'V')) {
      e.preventDefault(); say({a:'image', text:t.value});
    }
    else if (e.key === 'Escape') { e.preventDefault(); say({a:'close', text:t.value}); }
  });
  // Put the caret back where a redraw found it: the pad is re-rendered
  // from Lua after every change, so without this every attached image
  // would send the cursor to the start of the draft.
  t.focus(); t.setSelectionRange(t.value.length, t.value.length);
</script>
]]
    end

    function pad.render()
        if not pad.webview then return end
        pcall(function() pad.webview:html(buildHtml()) end)
    end

    local function handleMessage(body)
        if type(body) ~= "table" then return end
        -- Whatever was in the textarea travels with every message, so the
        -- draft survives a redraw no matter which button caused it.
        if body.text ~= nil then pad.draft = tostring(body.text) end

        if body.a == "add" then
            local ok, res = pad.addNote(body.text or pad.draft, pad.draftImages)
            if ok then
                pad.draft, pad.draftImages = "", {}
                pad.render()
            else
                pad.toast(res)
            end
        elseif body.a == "image" then
            pad.attachClipboardImage()
        elseif body.a == "removeImage" then
            local idx = tonumber(body.index)
            if idx and pad.draftImages[idx] then
                table.remove(pad.draftImages, idx)
                pad.render()
            end
        elseif body.a == "flush" then
            pad.flush("manual")
        elseif body.a == "close" then
            pad.hide()
        end
    end

    function pad.hide()
        if pad.webview then
            pcall(function() pad.webview:delete() end)
            pad.webview = nil
        end
    end

    -- No webview (an old Hammerspoon, a broken WebKit) must not mean no
    -- capture pad: the queue, the title rules and the 4 PM send all work
    -- without one, so ⇪N falls back to a plain text box.
    local function promptFallback()
        local button, typed = hs.dialog.textPrompt("Capture Pad",
            "Type a note. It is queued and sent to Asana at " .. pad.sendAt ..
            ".\n(! forces a task, ? forces a note.)", "", "Queue it", "Cancel")
        if button ~= "Queue it" then return end
        local ok, res = pad.addNote(typed, {})
        pad.toast(ok and ("queued — " .. pad.titleFor(typed)) or res)
    end

    function pad.show()
        if not pad.enabled then return end
        if pad.webview then pad.hide() return end
        if not (hs.webview and hs.webview.usercontent) then
            promptFallback()
            return
        end

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(pad.width, sf.w - 40)
        local h = math.min(pad.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3, w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "capturePad")
        if not (okUc and uc) then promptFallback() return end
        pad.uc = uc     -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("🗒 Capture Pad: message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            pad.uc = nil
            promptFallback()
            return
        end
        pad.webview = view
        pcall(function() view:windowTitle("Capture Pad") end)
        pcall(function() view:windowStyle({ "titled", "closable", "resizable", "utility" }) end)
        pcall(function() view:allowTextEntry(true) end)       -- without this you cannot type
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pad.render()
        pcall(function() view:show() end)
        -- bringToFront + the window being key is what puts the caret in the
        -- textarea; autofocus alone does nothing if the window is not key.
        pcall(function() view:bringToFront(true) end)
        pcall(function() hs.application.launchOrFocus("Hammerspoon") end)
        _G.diag.say("capturePad", "pad opened, " .. #pad.queue .. " queued")
    end

    function pad.toggle()
        if pad.webview then pad.hide() else pad.show() end
    end

    -- ---- keys, timer, services -------------------------------------------
    core.hyperAddShortcut({}, pad.key, function() pad.toggle() end, "capture pad")
    core.hyperAddShortcut({ "shift" }, pad.key, function() pad.flush("manual") end,
                          "capture pad — send now")

    core.provide("capturePad.add", function(text) return pad.addNote(text, {}) end)
    core.provide("capturePad.flush", function() pad.flush("service") end)
    core.provide("capturePad.title", function(text) return pad.titleFor(text) end)

    _G.capturePad = pad
    M.pad    = pad
    M.config = pad
end

-- The queue is read from disk and the daily send is armed in warm(), not
-- setup(): both touch the filesystem, and boot is measured.
function M.warm(core)
    local pad = M.pad
    if not pad then return end
    pad.load()
    -- HELD in pad.timer. hs.timer.doAt returns a timer that is collected
    -- like any other object if nothing keeps it, and a collected timer does
    -- not fire — which for this module would mean the 4 PM send simply
    -- never happening, with no error anywhere to say so.
    local ok, t = pcall(hs.timer.doAt, pad.sendAt, "1d", function()
        pad.flush("scheduled")
    end)
    if ok and t then
        pad.timer = t
        _G.diag.say("capturePad", "daily send armed for " .. pad.sendAt)
    else
        print("🗒 Capture Pad: could not arm the " .. pad.sendAt ..
              " send — use ⇪⇧N to send by hand")
    end
end

return M
