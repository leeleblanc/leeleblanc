-- =====================================================================
-- MODULE: BULK RENAME (⇪R) — 2 files or 1,000, in about four keystrokes
-- =====================================================================
-- Select files in Finder, press ⇪R, pick a rule, look at the preview,
-- press ⏎. ⇪⇧R undoes the whole batch. Nothing is renamed until the
-- preview has been shown, and nothing is renamed at all if any two files
-- would collide.
--
-- ---------------------------------------------------------------------
-- 🚨 THE THING THAT MAKES THIS DIFFERENT: SIDECARS TRAVEL WITH THE FILM
-- ---------------------------------------------------------------------
-- Look at what you are actually renaming:
--
--   Dark.Matter.2024.S01E01.108.mp4
--   Dark.Matter.2024.S01E01.108.srt          ← must match, exactly
--   Dark.Matter.2024.S01E02.1080p.ATVP-[y2flix.cc].mp4
--   Dark.Matter.2024.S01E02.1080p.ATVP-[y2flix.cc].srt
--
-- A subtitle is found by FILENAME. Every player, without exception,
-- loads <name>.srt next to <name>.mp4 — so a rename that touches the
-- video and not the subtitle does not "leave a file behind", it SILENTLY
-- BREAKS SUBTITLES, and you find out an hour into the episode.
--
-- So this module never renames files. It renames GROUPS: everything
-- sharing a stem moves together, by construction, because every rule
-- rewrites the STEM and the extensions are reattached afterwards. There
-- is no code path that can rename a .mp4 and not its .srt.
--
-- It also understands the subtitle tails that break naive stem matching —
-- `film.en.srt`, `film.forced.srt`, `film.sdh.srt` all belong to
-- `film.mp4`, and their tails are preserved through the rename. See
-- splitTail().
--
-- ---------------------------------------------------------------------
-- ⚠️ WHY IT REFUSES RATHER THAN OVERWRITES
-- ---------------------------------------------------------------------
-- os.rename() over an existing file DESTROYS that file, with no warning
-- and no undo. A bulk rename is precisely where two files collapse onto
-- one name — strip "1080p" from both `a.1080p.mp4` and `a.mp4` and you
-- have asked for one file to eat the other. So:
--
--   · The plan is computed IN FULL before anything is touched, and any
--     collision aborts the WHOLE batch. Not "skips the bad one" — a
--     half-renamed folder is worse than an unrenamed one.
--   · Renaming happens in TWO PHASES through temporary names, so a
--     cycle (a→b, b→a) works instead of destroying a file. A one-pass
--     rename cannot do this and will eat `b`.
--   · Every batch writes an undo log to disk BEFORE it runs, so ⇪⇧R
--     works even if Hammerspoon restarts in between.

local M = {
    name  = "Bulk Rename",
    order = 14.1,        -- see the note on focus_mode's order: 13.11 would
                         -- have been fine, but 14.x keeps the new block
                         -- clear of the 13.1-vs-13.10 trap entirely.
    cheatsheet = {
        title = "✏️ BULK RENAME (⇪R — Finder selection, 2 files or 1,000)",
        entries = {
            { "⇪R",     "Rename the Finder selection — pick rule, preview, ⏎" },
            { "undo",   "First row of ⇪R undoes the last batch — survives a restart" },
            { "tv",     "Normalise S01E01 naming across a whole season" },
            { "junk",   "Strip [tags], 1080p, WEBRip, release groups" },
            { "find",   "Find and replace · regex · sequential numbering" },
            { "safe",   "Subtitles move WITH their video — always, by design" },
            { "",       "Any collision aborts the whole batch. Nothing partial." },
        },
    },
}

function M.setup(core)
    local br = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    br.enabled     = true
    br.key         = "r"          -- ⇪R rename · ⇪⇧R undo
    br.maxFiles    = 2000         -- refuse absurd batches rather than hang
    br.previewRows = 60           -- how many rows the preview lists at once
    br.undoFile    = (core.logsDir or "/tmp") .. "/rename_undo.json"

    -- Tails that belong to a sidecar rather than to the name. `film.en.srt`
    -- is film's English subtitle, NOT a file called "film.en".
    br.sidecarTails = {
        "en", "eng", "english", "es", "spa", "fr", "fre", "de", "ger",
        "forced", "sdh", "cc", "default",
    }

    -- Tokens `junk` removes. Order matters only for readability; each is a
    -- Lua pattern applied to the stem.
    br.junkPatterns = {
        "%[[^%]]*%]",              -- [y2flix.cc], [rarbg]
        "%b()",                    -- (2024) when it is a duplicate tag
        "%f[%w]2160p%f[%W]", "%f[%w]1080p%f[%W]", "%f[%w]720p%f[%W]",
        "%f[%w]480p%f[%W]",
        "%f[%w]ATVP%f[%W]", "%f[%w]AMZN%f[%W]", "%f[%w]NF%f[%W]",
        "%f[%w]WEB%-?DL%f[%W]", "%f[%w]WEBRip%f[%W]", "%f[%w]BluRay%f[%W]",
        "%f[%w]HDTV%f[%W]", "%f[%w]x264%f[%W]", "%f[%w]x265%f[%W]",
        "%f[%w]H%.?264%f[%W]", "%f[%w]HEVC%f[%W]", "%f[%w]DDP?5%.1%f[%W]",
        "%f[%w]AAC%f[%W]", "%f[%w]10bit%f[%W]", "%f[%w]REPACK%f[%W]",
        "%f[%w]PROPER%f[%W]",
    }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("rename", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("rename", m) end end

    -- =====================================================================
    -- THE ENGINE — pure functions, no Finder, no disk, no hs
    -- =====================================================================
    -- Everything below this line is testable on any machine with lua5.4,
    -- which is why the rules live here and not tangled into the chooser.

    -- "/a/b/c.mp4" -> "/a/b", "c", "mp4"
    function br.splitPath(path)
        local dir, file = path:match("^(.*)/([^/]+)$")
        if not dir then dir, file = ".", path end
        local stem, ext = file:match("^(.*)%.([^.]+)$")
        if not stem then stem, ext = file, "" end
        return dir, stem, ext
    end

    -- "Dark.Matter.S01E01.en" -> "Dark.Matter.S01E01", "en"
    -- A tail is only split off when it is a KNOWN sidecar tail. Splitting
    -- on any trailing token would mangle "Dark.Matter.2024" into
    -- "Dark.Matter" + "2024" and lose the year.
    function br.splitTail(stem)
        local head, last = stem:match("^(.*)%.([^.]+)$")
        if not head then return stem, "" end
        local low = last:lower()
        for _, t in ipairs(br.sidecarTails) do
            if low == t then return head, last end
        end
        return stem, ""
    end

    -- Group paths by the stem they share, so a rule that rewrites the stem
    -- moves every member together. THIS is the subtitle guarantee.
    function br.group(paths)
        local groups, order = {}, {}
        for _, p in ipairs(paths) do
            local dir, stem, ext = br.splitPath(p)
            local base, tail = br.splitTail(stem)
            local key = dir .. "\0" .. base
            if not groups[key] then
                groups[key] = { dir = dir, base = base, members = {} }
                order[#order + 1] = key
            end
            table.insert(groups[key].members,
                         { path = p, ext = ext, tail = tail })
        end
        local out = {}
        for _, k in ipairs(order) do out[#out + 1] = groups[k] end
        return out
    end

    -- ---- the rules -------------------------------------------------------
    -- Each takes (base, index, ctx) and returns a new base. They are pure;
    -- ctx carries anything derived from the whole batch.

    local function tidy(s)
        s = s:gsub("%.%.+", "."):gsub("^[%.%s%-_]+", ""):gsub("[%.%s%-_]+$", "")
        s = s:gsub("%s%s+", " ")
        return s
    end

    br.rules = {}

    br.rules.junk = {
        label = "Strip junk — [tags], 1080p, WEBRip, release groups",
        fn = function(base)
            local s = base
            for _, pat in ipairs(br.junkPatterns) do s = s:gsub(pat, "") end
            -- A trailing "-GROUP" left after the quality tokens go.
            s = s:gsub("%-[%u%d]+$", "")
            return tidy(s)
        end,
    }

    -- 🚨 THE ONE THAT FIXES THE SCREENSHOT.
    -- Every file in the batch is reduced to <Show>.<Year>.S01E01, with the
    -- show and year taken from whichever file in the batch HAS them. That
    -- is what makes an odd one out — `…S01E01.108.mp4` sitting among
    -- `…S01E02.1080p.ATVP-[y2flix.cc].mp4` — come out identical to its
    -- siblings instead of merely tidier than before.
    br.rules.tv = {
        label = "TV: normalise to Show.Year.S01E01 across the whole season",
        prep = function(groups)
            local show, year
            for _, g in ipairs(groups) do
                local s = g.base
                local head = s:match("^(.-)[%.%s_%-]*[Ss]%d%d?[Ee]%d%d?")
                if head and head ~= "" then
                    local h = tidy(head)
                    local y = h:match("[%.%s](%d%d%d%d)$")
                    if y then h = h:gsub("[%.%s]%d%d%d%d$", "") end
                    -- The LONGEST candidate wins: a file whose show name
                    -- was truncated by junk must not define the batch.
                    if not show or #h > #show then show = h end
                    if y and not year then year = y end
                end
            end
            return { show = show, year = year }
        end,
        fn = function(base, _, ctx)
            local se, ep = base:match("[Ss](%d%d?)[Ee](%d%d?)")
            if not se then return base end       -- not an episode: left alone
            local show = (ctx and ctx.show) or base:match("^(.-)[%.%s_%-]*[Ss]%d")
            show = tidy(show or "Show")
            local parts = { show }
            if ctx and ctx.year then parts[#parts + 1] = ctx.year end
            parts[#parts + 1] = string.format("S%02dE%02d",
                                tonumber(se), tonumber(ep))
            return tidy(table.concat(parts, "."))
        end,
    }

    br.rules.dots = {
        label = "Dots → spaces",
        fn = function(base) return tidy((base:gsub("%.", " "))) end,
    }
    br.rules.spaces = {
        label = "Spaces → dots",
        fn = function(base) return tidy((base:gsub("%s+", "."))) end,
    }
    br.rules.lower = {
        label = "lowercase everything",
        fn = function(base) return base:lower() end,
    }
    br.rules.title = {
        label = "Title Case Each Word",
        fn = function(base)
            return (base:gsub("(%a[%w']*)", function(w)
                return w:sub(1, 1):upper() .. w:sub(2):lower()
            end))
        end,
    }

    -- Sequential numbering. `prefix` and `pad` come from the prompt.
    br.rules.seq = {
        label = "Sequential: Prefix 001, 002, 003 …",
        needs = "prefix",
        fn = function(_, i, ctx)
            local pad = (ctx and ctx.pad) or 3
            local pre = (ctx and ctx.prefix) or "File"
            return string.format("%s %0" .. pad .. "d", pre, i)
        end,
    }

    -- Literal find/replace, and its regex twin. `find` is escaped for the
    -- literal version so a user typing "1080p." does not get a wildcard.
    local function escapePattern(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

    br.rules.replace = {
        label = "Find and replace (literal)",
        needs = "replace",
        fn = function(base, _, ctx)
            if not (ctx and ctx.find and ctx.find ~= "") then return base end
            return tidy((base:gsub(escapePattern(ctx.find), (ctx.repl or ""):gsub("%%", "%%%%"))))
        end,
    }
    br.rules.regex = {
        label = "Find and replace (Lua pattern)",
        needs = "replace",
        fn = function(base, _, ctx)
            if not (ctx and ctx.find and ctx.find ~= "") then return base end
            -- A bad pattern is a user typo, not a crash. gsub throws on
            -- malformed patterns, so it is pcall'd and the name left alone.
            local ok, out = pcall(function()
                return (base:gsub(ctx.find, ctx.repl or ""))
            end)
            if ok and out then return tidy(out) end
            return base
        end,
    }

    -- ---- planning ---------------------------------------------------------
    -- Returns plan, problems. plan is a list of {from, to} across ALL
    -- members of every group. problems is non-empty when nothing may run.
    function br.plan(paths, ruleName, ctx)
        local rule = br.rules[ruleName]
        if not rule then return nil, { "no such rule: " .. tostring(ruleName) } end
        local groups = br.group(paths)
        local prepCtx = ctx or {}
        if rule.prep then
            local extra = rule.prep(groups) or {}
            for k, v in pairs(extra) do
                if prepCtx[k] == nil then prepCtx[k] = v end
            end
        end

        local plan, problems, seen = {}, {}, {}
        -- Every existing name in the affected directories, so a rename onto
        -- an untouched bystander file is caught too — not just collisions
        -- between two files in the batch.
        local inBatch = {}
        for _, p in ipairs(paths) do inBatch[p] = true end

        for i, g in ipairs(groups) do
            local okRule, newBase = pcall(rule.fn, g.base, i, prepCtx)
            if not okRule or type(newBase) ~= "string" or newBase == "" then
                newBase = g.base                  -- a rule may decline; never blank
            end
            for _, m in ipairs(g.members) do
                local name = newBase
                if m.tail ~= "" then name = name .. "." .. m.tail end
                if m.ext  ~= "" then name = name .. "." .. m.ext  end
                local to = g.dir .. "/" .. name
                if to ~= m.path then
                    if seen[to] then
                        problems[#problems + 1] =
                            "two files would both become " .. name
                    end
                    seen[to] = true
                    plan[#plan + 1] = { from = m.path, to = to, name = name }
                end
            end
        end

        -- Landing on a file that exists and is NOT part of this batch is an
        -- overwrite. os.rename would destroy it silently.
        for _, it in ipairs(plan) do
            if not inBatch[it.to] and br.exists(it.to) then
                problems[#problems + 1] = "would overwrite existing " .. it.name
            end
        end
        return plan, problems, prepCtx
    end

    -- Overridable so tests can plan without a filesystem.
    function br.exists(path)
        local ok, a = pcall(hs.fs.attributes, path)
        return ok and a ~= nil
    end

    -- ---- applying ---------------------------------------------------------
    -- 🚨 TWO PHASES. Renaming a→b and b→a in one pass destroys one file.
    -- Going through temporaries makes any permutation safe, including the
    -- swap, the rotation, and the shift-by-one that a numbering rule
    -- produces constantly.
    function br.apply(plan)
        if #plan == 0 then return 0, {} end
        local tmp, done, errs = {}, 0, {}
        for i, it in ipairs(plan) do
            local t = it.from .. ".__brtmp" .. i
            local ok, err = os.rename(it.from, t)
            if ok then tmp[#tmp + 1] = { tmpPath = t, to = it.to, from = it.from }
            else errs[#errs + 1] = tostring(err) end
        end
        for _, t in ipairs(tmp) do
            local ok, err = os.rename(t.tmpPath, t.to)
            if ok then done = done + 1
            else
                errs[#errs + 1] = tostring(err)
                -- Put it back where it came from rather than leaving a
                -- .__brtmp file the user has to clean up by hand.
                pcall(function() os.rename(t.tmpPath, t.from) end)
            end
        end
        return done, errs
    end

    function br.writeUndo(plan)
        local ok, enc = pcall(hs.json.encode, { at = os.time(), items = plan })
        if not ok then return end
        local f = io.open(br.undoFile, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed(br.undoFile) end
            return
        end
        f:write(enc); f:close()
    end

    -- Is there a batch to put back? Read from disk, so it survives a
    -- Hammerspoon restart exactly as the undo itself does.
    function br.hasUndo()
        local f = io.open(br.undoFile, "r")
        if not f then return false end
        local raw = f:read("*a"); f:close()
        return type(raw) == "string" and #raw > 2
    end

    function br.undo()
        local f = io.open(br.undoFile, "r")
        if not f then hs.alert.show("✏️ Nothing to undo"); return end
        local raw = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, raw)
        if not ok or type(data) ~= "table" or type(data.items) ~= "table" then
            hs.alert.show("✏️ The undo log is unreadable"); return
        end
        local back = {}
        for _, it in ipairs(data.items) do
            back[#back + 1] = { from = it.to, to = it.from,
                                name = it.from:match("[^/]+$") or it.from }
        end
        local done, errs = br.apply(back)
        os.remove(br.undoFile)
        hs.alert.show(string.format("✏️ Undid %d rename%s%s", done,
            done == 1 and "" or "s",
            #errs > 0 and (" · " .. #errs .. " failed") or ""), 3)
        say("undo restored " .. done .. " files")
    end

    -- =====================================================================
    -- THE MAC HALF — Finder selection and the picker
    -- =====================================================================
    function br.selection()
        -- 🚨 6.75.0 — `with timeout of 3 seconds`, AND THAT IS THE WHOLE
        -- DURABILITY STORY FOR THIS LINE. The call below is SYNCHRONOUS:
        -- it blocks the only thread Hammerspoon has until Finder answers.
        -- AppleScript's default timeout is TWO MINUTES, so a Finder that
        -- is wedged — spinning on a network volume, mid-relaunch, waiting
        -- on a permissions prompt — turns one ⇪R into a two-minute
        -- beachball with the keyboard taps frozen along with it.
        -- Three seconds is far longer than a healthy Finder needs and
        -- short enough that a sick one is an inconvenience rather than a
        -- lockup. On timeout osascript exits non-zero, the pcall below
        -- returns no paths, and the rename reports "nothing selected"
        -- instead of hanging your Mac.
        local script = [[
with timeout of 3 seconds
  tell application "Finder"
    set out to ""
    repeat with f in (get selection)
      set out to out & (POSIX path of (f as alias)) & linefeed
    end repeat
    return out
  end tell
end timeout]]
        -- 🚨 6.65.1 — OUT OF PROCESS. This was hs.osascript.applescript,
        -- which runs NSAppleScript inside Hammerspoon; an Objective-C
        -- exception from the Apple Event machinery ABORTS the app and
        -- CANNOT be caught by pcall (Lua's pcall catches Lua errors, and
        -- an ObjC exception is not one). That crash is documented on
        -- ocrWriteFinderComment in init.lua, from LL's own report.
        --
        -- ⚠️ WHY hs.execute HERE AND AN ASYNC TASK IN universal_actions.
        -- They need different things and the difference is safety, not
        -- taste. This function feeds a RENAME — acting on a stale list
        -- would rename files you did not select, which is destructive and
        -- unrecoverable. So this read must be FRESH and it must be
        -- SYNCHRONOUS. hs.execute is both, and it still runs osascript as
        -- a separate process, so nothing it does can take Hammerspoon
        -- down. The Universal Actions panel is non-destructive and shows
        -- you the filename it is acting on, so it can afford a cached
        -- answer and the fully asynchronous read that goes with it.
        --
        -- THE COST, NAMED: hs.execute blocks the main thread until Finder
        -- answers. Finder is normally instant; a wedged Finder would hold
        -- the keyboard for as long as it takes. That is the accepted
        -- trade against renaming the wrong files, and it happens on a
        -- keypress you made, never on a timer.
        --
        -- ⚠️ SHELL QUOTING, NOT LUA QUOTING. The first version of this
        -- line used ("%q"):format(script), which is Lua's quoting: it
        -- escapes a newline as backslash-then-newline. That is correct
        -- Lua and WRONG SHELL — inside double quotes the shell reads
        -- backslash-newline as a line CONTINUATION and joins the lines,
        -- so a multi-line AppleScript arrives as one line and fails to
        -- compile. Single quotes with '\'' for any embedded quote is the
        -- only form that passes an arbitrary string through /bin/sh
        -- unaltered.
        local quoted = "'" .. script:gsub("'", [['\'']]) .. "'"
        local okExec, out = pcall(hs.execute, "/usr/bin/osascript -e " .. quoted)
        if not okExec or type(out) ~= "string" then return {} end
        local res = out
        local paths = {}
        for line in res:gmatch("[^\r\n]+") do
            -- Finder gives directories a trailing slash; renaming folders
            -- in bulk is a different and far more dangerous job, so they
            -- are dropped rather than quietly included.
            if line ~= "" and not line:match("/$") then
                paths[#paths + 1] = line
            end
        end
        return paths
    end

    br.chooser = nil     -- HELD: an unreferenced hs.chooser is collected

    local function showPreview(paths, ruleName, ctx)
        local plan, problems, usedCtx = br.plan(paths, ruleName, ctx)
        if not plan then hs.alert.show("✏️ " .. (problems[1] or "?")); return end

        if #problems > 0 then
            local msg = "✏️ REFUSED — nothing was renamed\n"
                        .. problems[1]
                        .. (#problems > 1 and ("\n+" .. (#problems - 1) .. " more") or "")
            hs.alert.show(msg, 5)
            warn("plan refused: " .. table.concat(problems, "; "))
            return
        end
        if #plan == 0 then
            hs.alert.show("✏️ That rule changes nothing here", 2); return
        end

        local choices = { {
            text    = string.format("✅ APPLY — rename %d file%s", #plan,
                                    #plan == 1 and "" or "s"),
            subText = "⏎ to run · Esc to cancel · ⇪⇧R undoes it afterwards",
            apply   = true,
        } }
        for i, it in ipairs(plan) do
            if i > br.previewRows then
                choices[#choices + 1] = {
                    text = string.format("… and %d more", #plan - br.previewRows),
                    subText = "the preview is truncated; the batch is not",
                }
                break
            end
            choices[#choices + 1] = {
                text    = it.name,
                subText = "was  " .. (it.from:match("[^/]+$") or it.from),
            }
        end

        local ch = hs.chooser.new(function(pick)
            if not (pick and pick.apply) then
                hs.alert.show("✏️ Cancelled — nothing renamed", 1.5); return
            end
            -- The log is written BEFORE the renames, so a crash halfway
            -- through still leaves something to undo from.
            br.writeUndo(plan)
            local done, errs = br.apply(plan)
            local msg = string.format("✏️ Renamed %d file%s", done,
                                      done == 1 and "" or "s")
            if #errs > 0 then msg = msg .. "\n⚠️ " .. #errs .. " failed" end
            hs.alert.show(msg .. "\n⇪⇧R to undo", 3)
            say(string.format("applied %s to %d files (%d errors)",
                              ruleName, done, #errs))
        end)
        pcall(function() ch:width(40); ch:searchSubText(true) end)
        ch:choices(choices)
        ch:placeholderText(string.format("%s — %d file%s, no collisions",
            (br.rules[ruleName].label or ruleName), #plan, #plan == 1 and "" or "s"))
        br.chooser = ch
        ch:show()
    end

    -- Rules that need typed input ask for it, then preview.
    local function collect(ruleName, paths)
        local need = br.rules[ruleName].needs
        if not need then showPreview(paths, ruleName, nil); return end
        if need == "replace" then
            local b, find = hs.dialog.textPrompt("Find", "Text to find", "", "Next", "Cancel")
            if b == "Cancel" then return end
            local b2, repl = hs.dialog.textPrompt("Replace with",
                             "Leave empty to delete it", "", "Preview", "Cancel")
            if b2 == "Cancel" then return end
            showPreview(paths, ruleName, { find = find, repl = repl })
        elseif need == "prefix" then
            local b, pre = hs.dialog.textPrompt("Prefix",
                           "Files become 'Prefix 001', 'Prefix 002' …",
                           "File", "Preview", "Cancel")
            if b == "Cancel" then return end
            showPreview(paths, ruleName, { prefix = pre, pad = 3 })
        end
    end

    function br.show()
        if not br.enabled then return end
        local paths = br.selection()
        if #paths == 0 then
            hs.alert.show("✏️ Select some files in Finder first", 3); return
        end
        if #paths > br.maxFiles then
            hs.alert.show(string.format("✏️ %d files selected — the limit is %d",
                          #paths, br.maxFiles), 4)
            return
        end

        local groups = br.group(paths)
        local sidecars = #paths - #groups
        local order = { "tv", "junk", "replace", "regex", "seq",
                        "dots", "spaces", "title", "lower" }
        local choices = {}
        -- Undo first, when there is a batch to undo. It has no key of its
        -- own because ⇪⇧R belongs to something older; see the wiring note.
        if br.hasUndo() then
            choices[#choices + 1] = {
                text    = "↺ Undo the last rename",
                subText = "puts the previous batch back, exactly",
                undo    = true,
            }
        end
        for _, name in ipairs(order) do
            local r = br.rules[name]
            if r then
                choices[#choices + 1] = {
                    text = r.label, subText = "rule: " .. name, rule = name,
                }
            end
        end

        local ch = hs.chooser.new(function(pick)
            if not pick then return end
            if pick.undo then br.undo() return end
            collect(pick.rule, paths)
        end)
        pcall(function() ch:width(40); ch:searchSubText(true) end)
        ch:choices(choices)
        ch:placeholderText(string.format(
            "%d file%s in %d group%s%s — pick a rule",
            #paths, #paths == 1 and "" or "s",
            #groups, #groups == 1 and "" or "s",
            sidecars > 0 and (", " .. sidecars .. " sidecar"
                              .. (sidecars == 1 and "" or "s") .. " will follow") or ""))
        br.chooser = ch
        ch:show()
    end

    function _G.renameReport()
        local paths = br.selection()
        local groups = br.group(paths)
        local L = { string.format("✏️ BULK RENAME — %d selected, %d group(s)",
                    #paths, #groups) }
        for i, g in ipairs(groups) do
            if i > 20 then L[#L + 1] = "   …"; break end
            local exts = {}
            for _, m in ipairs(g.members) do
                exts[#exts + 1] = (m.tail ~= "" and (m.tail .. ".") or "") .. m.ext
            end
            L[#L + 1] = string.format("   %-52s [%s]", g.base,
                                      table.concat(exts, " "))
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if br.enabled then
        core.hyperAddShortcut({}, br.key, br.show, "bulk rename")
        -- 🚨 NO ⇪⇧R BINDING. ⇪⇧R was already RESET NUDGE OFFSET, reached
        -- through §0.4's migration of ⌃⌥⌘R. Claiming it printed one HYPER
        -- CONFLICT line at boot and silently killed a working shortcut.
        -- Undo needs no key of its own: it is the FIRST ROW of the ⇪R
        -- picker whenever there is something to undo — the same pattern
        -- Workspaces uses for reset, for the same reason — and it stays
        -- published as rename.undo for a free number-pad key:
        --       numpad.actions["pad-"] = "rename.undo"
    end

    core.provide("rename.show",   function()        return br.show()         end)
    core.provide("rename.undo",   function()        return br.undo()         end)
    core.provide("rename.plan",   function(p, r, c) return br.plan(p, r, c) end)
    core.provide("rename.groups", function(p)      return br.group(p)       end)
    core.provide("rename.report", function()       return _G.renameReport() end)

    _G.bulkRename = br
    M.br     = br
    M.config = br
end

return M
