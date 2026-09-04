-- =====================================================================
-- MODULE: CLIPBOARD HISTORY (⇪V) — every copy, searchable · ⇪⇧V to edit
-- =====================================================================
-- ⇪V searches the FULL text of every saved copy, not just the 100
-- characters a row shows. ⇪⇧V opens the same list to edit or delete an
-- entry — and an edited entry is put back on the clipboard, because you
-- edited it in order to paste it.
--
-- ---------------------------------------------------------------------
-- 6.55.0 — WHY THIS IS A MODULE NOW
-- ---------------------------------------------------------------------
-- This lived in init.lua, spread over four separate places: the file
-- path in §0.2, load/save in §2, the dedupe inside the pasteboard
-- watcher in §3, and two choosers in §5. Every one of those lines ran
-- BEFORE the module loader, in the stretch where a single error takes
-- the whole config down rather than costing you one feature. Moving it
-- buys three things: init.lua gets shorter, a fault in clipboard
-- history now costs you clipboard history, and the behaviour finally
-- has somewhere to be tested.
--
-- 🔗 THE ONE THING THAT STAYED BEHIND, and why. The pasteboard watcher
-- in init.lua is SHARED with image OCR — one timer reading one
-- changeCount, deciding between "copied image files", "a raw image" and
-- "text". Splitting that in two would mean two timers polling the same
-- counter and racing over which handled a change first. So the watcher
-- stays, and calls clipboard.add through the service registry. If this
-- module is switched off the watcher simply gets no provider, prints so
-- once, and OCR carries on.
--
-- ---------------------------------------------------------------------
-- 🚨 THE FAILURE THAT MATTERS HERE IS LOSING THE HISTORY
-- ---------------------------------------------------------------------
-- The file is rewritten on EVERY copy, so a bad write is not a one-off:
-- it is a thousand chances a day to destroy the lot. Two guards, both
-- carried over intact because both were earned by real incidents:
--   · AN UNREADABLE FILE IS BACKED UP BEFORE ANYTHING ELSE. It used to
--     fall back to {} silently, and the very next copy overwrote the
--     broken file with that empty list — losing whatever was still
--     recoverable inside it.
--   · AN ENCODE IS VERIFIED BEFORE IT IS COMMITTED. If encode ever
--     produces something that will not read back, the existing file is
--     left ALONE. Writing it was what corrupted the file in the first
--     place, and it was discovered only at the next reload, as
--     "history wiped".

local M = {
    name  = "Clipboard History",
    order = 14.3,
    -- 🗂 6.113.0 — MOVED FROM "text" TO "capture", ON REQUEST. The families
    -- are about what a tool is FOR, not what it operates on, and a store
    -- that catches everything you copy so you can go back for it later is
    -- the same shape as the Capture Pad and Quick Append: it takes
    -- something in and keeps it. "text" is where things that TRANSFORM
    -- text live — Text Expander, Autocorrect, Begone, OCR, URL Cleaner.
    -- ⚠️ NOTHING FOLLOWS IT AUTOMATICALLY. ⇪H (Command History) reads a
    -- shell's history file rather than catching anything, and was already
    -- filed under FIND & OPEN; the hand-written CLIPBOARD & OCR group in
    -- core/cheatsheet.lua is ⇪O/⇪⇧O/⇪⇧C, which is OCR and copy-on-select,
    -- so it stays in "text" too. Say the word if either should move.
    family = "capture",
    cheatsheet = {
        title = "📋 CLIPBOARD HISTORY (⇪V — every copy, searchable)",
        entries = {
            { "⇪V",   "Search clipboard history — matches the FULL text" },
            { "👁 pane","Beside the list: the WHOLE entry of the row the arrows or the" },
            { "",     "mouse are on — grows to the screen edge, then '… N more lines'" },
            { "⇪⇧V",  "Edit or delete an entry · an edit is re-copied" },
            { "☑️ row","Pick several rows, then delete or copy them as ONE" },
            { "keeps","The last 1,000 copies, newest first" },
            { "skips","Anything over ~1 MB, so the file stays quick to write" },
            { "dedupe","Copying something again moves it up, not a second row" },
        },
    },
}

function M.setup(core)
    local clip = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    clip.enabled     = true
    clip.key         = "v"          -- ⇪V search · ⇪⇧V edit
    clip.max         = 1000         -- how many copies to keep
    clip.maxItemSize = 1000000      -- ~1 MB; bigger copies are not stored
    clip.rows        = 250          -- rows shown before you narrow the search
    clip.preview     = 100          -- characters shown per row
    -- 👁 6.154.0 — the pane beside the picker (see THE PREVIEW PANE below)
    clip.previewOn   = true         -- false = the list alone, as before
    clip.previewW    = 420          -- points wide; shrinks if the screen is narrow
    clip.previewPoll = 0.08         -- seconds between selection/hover reads —
                                    -- runs ONLY while a picker is on screen
    clip.previewMaxChars = 12000    -- characters laid out per preview
    clip.previewGrace = 0.6         -- 6.155.0: seconds the pane waits for a
                                    -- NUDGED picker to come back (⇪⇧-arrows
                                    -- hide + re-show it) before it gives up
    clip.previewMousePx = 2         -- 6.160.4: points the pointer must MOVE
                                    -- between two polls to take the pane —
                                    -- a pointer merely resting on the
                                    -- picker never has it
    clip.file        = (core.logsDir or hs.configdir)
                       .. "/clipboard_history-" .. tostring(core.hostTag) .. ".json"
    -- ----------------------------------------------------------------------

    -- 💾 6.154.0 — the file is rewritten WHOLE on every copy, edit and
    -- delete, so it shrinks whenever you delete an entry. Said to the
    -- write ledger, which otherwise reads a smaller file as a truncation.
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[clip.file] = "the clipboard history — rewritten on every copy, edit and delete"

    -- The one-time migration of the pre-6.10 file from ~/.hammerspoon into
    -- the Logs folder came across with the rest of the feature: it belongs
    -- with the code that owns the file, not in the orchestrator.
    if core.adoptLegacyFile then
        pcall(core.adoptLegacyFile, clip.file,
              hs.configdir .. "/clipboard_history.json")
    end

    _G.clipboardCache = _G.clipboardCache or {}
    clip.loaded  = false
    clip.preload = {}     -- copies made before the file finished loading

    local function say(m)  if _G.diag then _G.diag.say("clipboard", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("clipboard", m) end end

    -- Anything that goes wrong here is exactly the kind of thing that used
    -- to be visible only in the Console. 6.54.0 gave us somewhere better.
    local function tellFailure(title, detail, key)
        if _G.notices then
            _G.notices.record("runtime", "clipboard_history", detail)
            _G.notices.tell(title, detail, { key = key, every = 600, seconds = 6 })
        else
            hs.alert.show("⚠️ " .. title .. "\n" .. detail, 6)
        end
        print("🚨 Clipboard history: " .. detail)
    end

    -- ---- disk -------------------------------------------------------------
    function clip.load()
        local f = io.open(clip.file, "r")
        if not f then _G.clipboardCache = {} return true end
        local content = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, content)
        if ok and type(data) == "table" then
            _G.clipboardCache = data
            return true
        end
        -- 🚨 BACK UP BEFORE STARTING FRESH. Falling back to {} silently
        -- meant the next copy overwrote the broken file with an empty
        -- list, destroying whatever was still recoverable in it.
        _G.clipboardCache = {}
        local backupPath = clip.file .. ".corrupt-" .. os.date("%Y%m%d-%H%M%S")
        local bf = io.open(backupPath, "w")
        if bf then bf:write(content); bf:close() end
        tellFailure("Clipboard history was unreadable",
                    "backed up to " .. backupPath .. " and started fresh",
                    "clip:corrupt")
        return false
    end

    function clip.save()
        local okEnc, body = pcall(hs.json.encode, _G.clipboardCache)
        if not okEnc or type(body) ~= "string" then
            tellFailure("Clipboard history NOT saved",
                        "encode failed; the existing file was left untouched",
                        "clip:encode")
            return false
        end
        -- 🚨 VERIFY BEFORE COMMITTING. Writing an encode that will not read
        -- back is what corrupted the file originally, and it was noticed
        -- only at the next reload, as "history wiped".
        local okDec, decoded = pcall(hs.json.decode, body)
        if not okDec or type(decoded) ~= "table" then
            tellFailure("Clipboard history NOT saved",
                        "the encoded JSON would not read back; file untouched",
                        "clip:roundtrip")
            return false
        end
        local f = io.open(clip.file, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("clipboard history") end
            return false
        end
        f:write(body); f:close()
        return true
    end

    -- ---- adding -----------------------------------------------------------
    -- Called by init.lua's shared pasteboard watcher via the service
    -- registry. Returns true when something was actually stored.
    function clip.add(text)
        if type(text) ~= "string" or text == "" then return false end
        if #text > clip.maxItemSize then
            print("📋 Clipboard item not saved to history (over 1 MB)")
            return false
        end
        local cache = _G.clipboardCache
        -- Already at the top: nothing to do. This is also what stops the
        -- clipboard-edit path filing a duplicate — the edited entry
        -- carries the arriving text, so the dedupe below lifts it rather
        -- than copying it.
        if cache[1] and cache[1].text == text then return false end
        for i = #cache, 1, -1 do
            if cache[i].text == text then table.remove(cache, i) end
        end
        table.insert(cache, 1, { date = os.date("%b %d %H:%M"), text = text })
        while #cache > clip.max do table.remove(cache) end
        -- 🚨 DO NOT SAVE BEFORE THE FILE HAS BEEN READ. Deferring the
        -- load to warm() opened a two-second window at boot in which a
        -- copy would write a ONE-ITEM file straight over the real
        -- history — and warm() would then dutifully load that back,
        -- having destroyed everything. The copy is held instead and
        -- re-applied on top once the file is in, which is what
        -- clip.preload is for. Found by test_clipboard's P4.
        if not clip.loaded then
            clip.preload[#clip.preload + 1] = text
            return true
        end
        clip.save()
        return true
    end

    -- ---- the pickers -------------------------------------------------------
    clip.chooser, clip.editChooser = nil, nil   -- HELD: else collected
    local editSnapshot = {}

    -- =====================================================================
    -- 👁 THE PREVIEW PANE (6.154.0)
    -- =====================================================================
    -- LL: "Can the full contents of the clipboard item in ⌘V be shown as I
    -- arrow up/down, or put my mouse cursor on an item? The view should
    -- show to the right of the window and be able to scroll or
    -- automatically expand to show that entry."
    --
    -- hs.chooser has no selection-changed callback, and it does NOT follow
    -- the mouse — HSChooser.m has no mouseMoved and no tracking area
    -- (checked, not assumed) — so both halves of the ask are answered by
    -- ONE small poll that runs only while a picker is on screen:
    --   · the KEYBOARD answer is chooser:selectedRow()
    --   · the MOUSE answer is the row under the pointer, computed from the
    --     picker's box — the placement record plus window_move's row
    --     constants, because macOS gives a chooser no frame getter. The
    --     mouse wins while it is inside the picker, the keyboard the rest
    --     of the time — a rule 6.160.4 narrowed to the hand that MOVED,
    --     see below. (One honest limit: the box maths assumed the list
    --     was scrolled to its top; 6.160.4 estimates the scroll instead.)
    -- The pane is an hs.canvas beside the picker — to the RIGHT when it
    -- fits, else the left — sized to the text down to the screen's bottom
    -- edge ("automatically expand"); what will not fit ends in an honest
    -- "… N more lines" footer rather than being clipped mid-word. Text is
    -- pre-wrapped in Menlo, whose advance is known, so the height is
    -- arithmetic rather than a guess. The picker's hideCallback takes the
    -- pane down; the poll closes for good once the picker has been gone
    -- for clip.previewGrace.
    --
    -- 🧲 6.155.0 — THE PANE SURVIVES A MOVE. LL: "I can't move it. Should
    -- I be able to?" You can — ⌘-drag from anywhere on it, or ⇪⇧-arrows
    -- (window_move) — and the first cut of the pane did not survive the
    -- second: a nudge is hide() + show(point), the hideCallback closed
    -- the pane AND stopped the poll, and nothing re-opened it because the
    -- re-show goes through core.showPopup, not this module's openers. The
    -- hideCallback now only SUSPENDS (the canvas goes, the poll stays) and
    -- the poll closes for good only after the picker has been gone for
    -- clip.previewGrace; a picker that is back within it — a nudge takes
    -- one event-loop turn — gets its pane back at the NEW placement on
    -- the next tick. A ⌘-drag never hides the picker at all (show(point)
    -- re-anchors it live) and window_move now moves the placement point
    -- with the hand, so the pane rides along at the poll's cadence.
    --
    -- 🖱 6.160.4 — THE LAST HAND THAT MOVED. LL: "In my Chrome history
    -- list, the entry in the picker will say it's a particular line
    -- while the pop-up to the right will list something different."
    -- 6.154.0's rule — the mouse wins while it is INSIDE the picker —
    -- counted a pointer that was merely resting there, and since 6.160.0
    -- Mouse Follows Focus parks the pointer at the centre of the focused
    -- window: on a big Chrome window that is the centre of the screen,
    -- which is row 9 of the ⇪Y picker that opens around it. So the
    -- highlight sat on row 1, the pane showed row 9, and the arrows moved
    -- the highlight while the pane stayed put. Now the poll remembers
    -- where the pointer was and what the keyboard had: the mouse takes
    -- the pane only when it MOVES (clip.previewMousePx or more) onto a
    -- row, the keyboard takes it back the moment the selection changes,
    -- and a still pointer never overrules the highlight. While the mouse
    -- is the hand the pane's header says so ("🖱 under the pointer") —
    -- that is the one time the pane and the highlight are meant to
    -- differ. The row maths also stops assuming an unscrolled list: the
    -- first visible row is estimated from the keyboard — a new list is
    -- taken to start at the top (the usual order is type, then arrow;
    -- NSTableView keeps its scroll offset across a reload, and the
    -- selection pulls the estimate back to wherever the arrows put it),
    -- and an arrow that walks the selection past either edge scrolls
    -- the list just far enough to show it (HSChooser.m: every arrow is
    -- selectChoice, which is selectRowIndexes + scrollRowToVisible; it
    -- has no hover code at all, which is why the pane polls). A wheel
    -- scroll is still invisible (hs.chooser has no scroll getter), so it
    -- stays the one honest limit.
    clip.pv = { canvas = nil, poll = nil, chooser = nil, rowsFn = nil,
                lastKey = nil, gen = 0, hiddenAt = nil,
                rowH = 44, headH = 56,    -- window_move's chooserRowH / chooserHeadH
                -- 6.160.4: which hand has the pane, what each hand last
                -- did, and the estimated first visible row
                hand = "keys", lastMouse = nil, lastSel = nil, top = 1, lastN = nil }
    local pv = clip.pv

    local function now()
        local t
        pcall(function() t = hs.timer.secondsSinceEpoch() end)
        return tonumber(t) or os.time()
    end

    function clip.previewClose()
        if pv.poll   then pcall(function() pv.poll:stop()     end) ; pv.poll = nil end
        if pv.canvas then pcall(function() pv.canvas:delete() end) ; pv.canvas = nil end
        pv.chooser, pv.rowsFn, pv.lastKey, pv.shown, pv.hiddenAt = nil, nil, nil, nil, nil
        pv.hand, pv.lastMouse, pv.lastSel, pv.top, pv.lastN = "keys", nil, nil, 1, nil
    end

    -- The picker went away: the pane goes with it NOW (a pane over an
    -- empty spot is wrong for as long as it lasts), the poll stays for
    -- previewGrace in case the picker is only being moved.
    function clip.previewSuspend()
        if pv.canvas then pcall(function() pv.canvas:delete() end) ; pv.canvas = nil end
        pv.lastKey, pv.shown = nil, nil
        if pv.poll then pv.hiddenAt = pv.hiddenAt or now()
        else clip.previewClose() end
    end

    -- The picker's box, computed the way window_move computes its grab
    -- box: top-left from the placement record, width and rows asked of
    -- the chooser (pcall'd — both getters vary across builds). A record
    -- that names a DIFFERENT picker is worse than none (the 6.127.0 bug).
    function clip.previewBox(chooser)
        local placed = _G.lastPopupPlacement
        if not (placed and placed.point) then return nil, "no placement on record" end
        if placed.chooser ~= nil and placed.chooser ~= chooser then
            return nil, "the placement on record belongs to a different picker"
        end
        local sf
        pcall(function() sf = placed.screen and placed.screen:frame() end)
        if type(sf) ~= "table" then sf = { x = 0, y = 0, w = 1440, h = 900 } end
        local w = sf.w * 0.4
        pcall(function()
            local pct = chooser:width()
            if type(pct) == "number" and pct > 0 and pct <= 100 then
                w = sf.w * pct / 100
            end
        end)
        local rows = 10
        pcall(function()
            local r = chooser:rows()
            if type(r) == "number" and r > 0 then rows = r end
        end)
        return { x = placed.point.x, y = placed.point.y, w = w,
                 h = pv.headH + rows * pv.rowH }, sf
    end

    -- Which row to show. 6.154.0 said "the mouse while it is inside the
    -- picker's rows, otherwise the keyboard" and 6.160.4 found that rule
    -- wrong the moment the pointer merely RESTS inside the picker (THE
    -- LAST HAND THAT MOVED, above). Now the mouse takes the pane when it
    -- MOVES onto a row, the keyboard takes it back when the selection
    -- changes, and a still pointer never overrules the highlight. nil =
    -- nothing to show. The second value names the hand; the third is the
    -- keyboard's row when the mouse won, so a mouse row that turns out to
    -- hold nothing (past the end of a filtered list) can fall back to it.
    function clip.previewRow(chooser, box, n)
        local sel
        pcall(function() sel = chooser:selectedRow() end)
        if not (type(sel) == "number" and sel >= 1 and sel <= n) then sel = nil end
        -- the first visible row, estimated: a new list is taken to start
        -- at the top, an arrow past either edge scrolls just far enough to
        -- show the selection (selectChoice → scrollRowToVisible), and the
        -- selection pulls the estimate along from there
        if n ~= pv.lastN then pv.top, pv.lastN = 1, n end
        local vis = math.max(1, math.floor((box.h - pv.headH) / pv.rowH + 0.5))
        if sel then
            if sel < pv.top then pv.top = sel
            elseif sel > pv.top + vis - 1 then pv.top = sel - vis + 1 end
        end
        local m
        pcall(function() m = hs.mouse.absolutePosition() end)
        if not (type(m) == "table" and type(m.x) == "number"
                and type(m.y) == "number") then m = nil end
        local moved = false
        if m then
            local last = pv.lastMouse
            if not last then
                pv.lastMouse = { x = m.x, y = m.y }      -- first look: resting
            elseif math.abs(m.x - last.x) >= clip.previewMousePx
                or math.abs(m.y - last.y) >= clip.previewMousePx then
                moved, pv.lastMouse = true, { x = m.x, y = m.y }
            end
        end
        local mouseRow
        if m and m.x >= box.x and m.x <= box.x + box.w
           and m.y >= box.y + pv.headH and m.y <= box.y + box.h then
            local r = pv.top + math.floor((m.y - box.y - pv.headH) / pv.rowH)
            if r >= 1 and r <= n then mouseRow = r end
        end
        local selChanged = pv.lastSel ~= nil and sel ~= pv.lastSel
        pv.lastSel = sel
        if not mouseRow then pv.hand = "keys"          -- off the rows: the keyboard's
        elseif moved then pv.hand = "mouse"             -- onto a row: the mouse's
        elseif selChanged then pv.hand = "keys" end     -- an arrow: the keyboard's
        if pv.hand == "mouse" and mouseRow then return mouseRow, "mouse", sel end
        if sel then return sel, "keys" end
        return nil
    end

    -- Word-wrapped into lines of at most `cols` monospace characters, so
    -- the pane's height is arithmetic. Leading indentation is kept, tabs
    -- become four spaces, a word longer than a line is cut.
    function clip.previewWrap(text, cols)
        cols = math.max(8, math.floor(cols or 60))
        local out = {}
        text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "    ")
        for raw in (text .. "\n"):gmatch("(.-)\n") do
            local line = raw:match("^%s*") or ""
            for word in raw:gmatch("%S+%s*") do
                while #word > cols do
                    if line ~= "" and line:match("%S") then
                        out[#out + 1] = (line:gsub("%s+$", "")) ; line = ""
                    end
                    out[#out + 1] = word:sub(1, cols)
                    word = word:sub(cols + 1)
                end
                if #line + #word > cols and line:match("%S") then
                    out[#out + 1] = (line:gsub("%s+$", ""))
                    line = word
                else
                    line = line .. word
                end
            end
            out[#out + 1] = (line:gsub("%s+$", ""))
        end
        if #out > 1 and out[#out] == "" then out[#out] = nil end
        return out
    end

    -- Lay the entry out beside the picker. Returns true when a pane is
    -- on screen for it. `how` names the hand (6.160.4): when it is the
    -- mouse, the header says so.
    function clip.previewDraw(entry, box, sf, key, how)
        if pv.canvas and pv.lastKey == key then return true end
        local sty = _G.uiStyle or {}
        local pad, fs = 14, 13
        local charW  = fs * 0.602                 -- Menlo's advance, per em
        local lineH  = math.floor(fs * 1.35 + 0.5)
        local gap, w = 12, clip.previewW
        local x = box.x + box.w + gap
        if x + w > sf.x + sf.w - 8 then
            if box.x - gap - w >= sf.x + 8 then
                x = box.x - gap - w                       -- the left, then
            else
                x = box.x + box.w + gap                   -- narrow screen:
                w = math.max(180, sf.x + sf.w - 8 - x)    -- take what fits
            end
        end
        local y    = box.y
        local maxH = sf.y + sf.h - 12 - y
        local text = tostring(entry.rawText or "")
        local shownText = text:sub(1, clip.previewMaxChars)
        local lines = clip.previewWrap(shownText, (w - pad * 2) / charW)
        local total = #lines
        local headH, footH, hidden = 20, 0, 0
        local bodyMax = math.max(1, math.floor((maxH - pad * 2 - headH) / lineH))
        if total > bodyMax then
            footH = 18
            local fit = math.max(1, math.floor((maxH - pad * 2 - headH - footH) / lineH))
            hidden = total - fit
            local cut = {}
            for i = 1, fit do cut[i] = lines[i] end
            lines = cut
        end
        local h = pad * 2 + headH + #lines * lineH + footH
        local rect = { x = x, y = y, w = w, h = h }
        local chars = #text
        local rawLines = select(2, text:gsub("\n", "")) + 1
        -- 6.156.0 — another picker's rows may bring their own header
        -- (the snippet picker names the trigger and the collection);
        -- 6.157.0 — or just a `when`, or nothing but the text
        local head = entry.head or string.format("%s%d char%s  ·  %d line%s%s",
            entry.when and ("📋 " .. tostring(entry.when) .. "  ·  ") or "",
            chars, chars == 1 and "" or "s",
            rawLines, rawLines == 1 and "" or "s",
            chars > clip.previewMaxChars
                and ("  ·  first " .. clip.previewMaxChars .. " shown") or "")
        if how == "mouse" then head = head .. "  ·  🖱 under the pointer" end
        local els = {
            { type = "rectangle", action = "strokeAndFill",
              fillColor   = sty.bg or { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 },
              strokeColor = sty.stroke or { white = 1, alpha = 0.18 }, strokeWidth = 1,
              roundedRectRadii = { xRadius = sty.radius or 12, yRadius = sty.radius or 12 },
              frame = { x = 0.5, y = 0.5, w = w - 1, h = h - 1 } },
            { type = "text", text = head, textSize = 11,
              textColor = sty.fgDim or { white = 1, alpha = 0.55 },
              textLineBreak = "truncateTail",
              frame = { x = pad, y = pad - 2, w = w - pad * 2, h = headH } },
            -- pre-wrapped, so "clip" here only ever trims a line the
            -- width estimate got slightly wrong — never re-wraps
            { type = "text", text = table.concat(lines, "\n"), textSize = fs,
              textFont = "Menlo", textLineBreak = "clip",
              textColor = sty.fg or { white = 1, alpha = 0.97 },
              frame = { x = pad, y = pad + headH, w = w - pad * 2,
                        h = #lines * lineH + 4 } },
        }
        if hidden > 0 then
            els[#els + 1] = {
                type = "text",
                text = string.format("… %d more line%s — ⏎ copies all of it",
                                     hidden, hidden == 1 and "" or "s"),
                textSize = 11, textColor = sty.fgDim or { white = 1, alpha = 0.55 },
                frame = { x = pad, y = h - pad - footH + 2, w = w - pad * 2, h = footH },
            }
        end
        if not pv.canvas then
            local okC, c = pcall(hs.canvas.new, rect)
            if not (okC and c) then return false end
            pv.canvas = c
            pcall(function()
                -- beside the chooser, never under it: the ladder's rung
                -- above macOS's fixed chooser level (core/coexist.lua)
                c:level((_G.panelLevel and _G.panelLevel("clippreview"))
                        or (hs.canvas.windowLevels or {}).popUpMenu
                        or (hs.canvas.windowLevels or {}).overlay)
            end)
            pcall(function() c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
            -- click-through: a pane that swallowed the click you were
            -- about to make on the picker would be worse than none
            pcall(function() c:canvasMouseEvents(false, false, false, false) end)
            pcall(function() c:replaceElements(els) end)
            if _G.showCanvasSafely then _G.showCanvasSafely(c, "clipboard preview")
            else pcall(function() c:show() end) end
        else
            pcall(function() pv.canvas:frame(rect) end)
            pcall(function() pv.canvas:replaceElements(els) end)
        end
        pv.lastKey = key
        return true
    end

    function clip.previewTick()
        local ch = pv.chooser
        if not ch then clip.previewClose() return end
        local vis
        pcall(function() vis = ch:isVisible() end)
        if vis == false then
            -- gone — for good, or for the one turn a nudge takes?
            if pv.canvas then pcall(function() pv.canvas:delete() end) ; pv.canvas = nil end
            pv.lastKey, pv.shown = nil, nil
            pv.hiddenAt = pv.hiddenAt or now()
            if now() - pv.hiddenAt >= clip.previewGrace then clip.previewClose() end
            return
        end
        pv.hiddenAt = nil
        local box, sf = clip.previewBox(ch)
        -- 👁 6.157.0 — TWO WAYS TO KNOW WHAT ROW r IS. A picker that
        -- filters for itself hands over rowsFn (the rows AS SHOWN); any
        -- other picker is asked directly — hs.chooser:selectedRowContents(r)
        -- returns the r-th row of whatever list the chooser is showing,
        -- its own filter included — so the pane needs nothing from the
        -- module beyond a rawText on each row. LL: "I need a preview
        -- window for the relevant pickers like hyper+o. Can we correct
        -- all the picker tools that don't have one?"
        local rows = pv.rowsFn and pv.rowsFn() or nil
        local n = rows and #rows or 100000
        local function rowAt(r)
            if rows then return rows[r] end
            local t
            pcall(function() t = ch:selectedRowContents(r) end)
            if type(t) == "table" and next(t) ~= nil then return t end
            return nil
        end
        local r, how, alt = nil, nil, nil
        if box then r, how, alt = clip.previewRow(ch, box, n) end
        local entry = r and rowAt(r)
        if not (entry and type(entry.rawText) == "string") and alt then
            r, how = alt, "keys"          -- the mouse sat past the list's end
            entry = rowAt(r)
        end
        if not (entry and type(entry.rawText) == "string") then
            -- an action row, an empty list, or nowhere to put the pane:
            -- take it down (a fresh one is cheap) and keep polling
            if pv.canvas then pcall(function() pv.canvas:delete() end) ; pv.canvas = nil end
            pv.lastKey, pv.shown = nil, nil
            return
        end
        local key = pv.gen .. ":" .. r .. ":" .. how .. ":" .. #entry.rawText
                    .. ":" .. entry.rawText:sub(1, 48)
        if pv.lastKey ~= key then clip.previewDraw(entry, box, sf, key, how) end
        pv.shown = { row = r, how = how }
    end

    function clip.previewOpen(chooser, rowsFn)
        clip.previewClose()
        if not (clip.previewOn and chooser) then return false end
        pv.chooser, pv.rowsFn = chooser, rowsFn
        local okT, t = pcall(hs.timer.doEvery, clip.previewPoll, function()
            local ok, err = pcall(clip.previewTick)
            if not ok then
                warn("preview pane — " .. tostring(err))
                clip.previewClose()
            end
        end)
        if not (okT and t) then pv.chooser, pv.rowsFn = nil, nil ; return false end
        pv.poll = t                 -- HELD: an unreferenced timer is collected
        pcall(clip.previewTick)     -- the first paint is now, not a poll later
        return true
    end

    -- Every way a picker opens goes through one of these two, so the pane
    -- follows. One placement call PER PICKER, on purpose: test_integration
    -- counts them against the pickers built, and that count is the
    -- contract that keeps every picker draggable (6.127.0).
    local function openMain()
        if core.showPopup then core.showPopup(clip.chooser)
        else clip.chooser:show() end
        clip.previewOpen(clip.chooser, function() return clip.lastChoices end)
    end
    local function openEdit()
        if core.showPopup then core.showPopup(clip.editChooser)
        else clip.editChooser:show() end
        clip.previewOpen(clip.editChooser, function() return clip.lastEditChoices end)
    end

    -- ☑️ 6.97.0 — SELECT MODE, the same pattern the Document Watcher list
    -- proved in 6.40.0: hs.chooser has no shift-click multi-select, so
    -- Enter TAGS rows (✓) and an action row applies to all of them at
    -- once. Tags key on the ENTRY TABLE, not the index — a copy made
    -- while the picker is open shifts every index, but identity holds.
    clip.selectMode = false
    clip.tagged     = {}        -- entry table -> true

    function clip.taggedCount()
        local n = 0
        for _ in pairs(clip.tagged) do n = n + 1 end
        return n
    end

    -- Both bulk actions end select mode: the job the mode existed for is
    -- done, and coming back to a stale pick-list is how mistakes happen.
    function clip.deleteTagged()
        local kept, removed = {}, 0
        for _, item in ipairs(_G.clipboardCache) do
            if clip.tagged[item] then removed = removed + 1
            else kept[#kept + 1] = item end
        end
        if removed > 0 then
            _G.clipboardCache = kept
            clip.save()
        end
        clip.selectMode, clip.tagged = false, {}
        return removed
    end

    function clip.copyTagged()
        local parts = {}
        for _, item in ipairs(_G.clipboardCache) do
            if clip.tagged[item] then parts[#parts + 1] = item.text or "" end
        end
        if #parts > 0 then
            -- One pasteboard write; the shared watcher files the joined
            -- text as a NEW top entry, which is what a copy means here.
            pcall(function() hs.pasteboard.setContents(table.concat(parts, "\n")) end)
        end
        clip.selectMode, clip.tagged = false, {}
        return #parts
    end

    local function oneLine(s) return (s:gsub("%s+", " ")) end

    function clip.render(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        for _, item in ipairs(_G.clipboardCache) do
            if q == "" or (item.text or ""):lower():find(q, 1, true) then
                choices[#choices + 1] = {
                    text    = oneLine(item.text or ""):sub(1, clip.preview),
                    subText = item.date or "",
                    rawText = item.text,
                    when    = item.date or "",
                }
                if #choices >= clip.rows then break end
            end
        end
        if #choices == 0 then
            choices[1] = {
                text = (q == "") and "Clipboard history is empty"
                       or ("No matches for \"" .. q .. "\""),
                subText = "Searches the full text of every saved item",
            }
        end
        clip.lastChoices = choices          -- 👁 what the preview pane indexes
        clip.pv.gen = clip.pv.gen + 1
        clip.chooser:choices(choices)
    end

    -- 🚨 THE SNAPSHOT+INDEX PATTERN IS LOAD-BEARING, and the reason is not
    -- obvious. This originally put the entry TABLE on the choice and
    -- compared it with == in the callback — but hs.chooser round-trips
    -- every choice through its Objective-C bridge, and what comes back is
    -- a FRESHLY REBUILT Lua table, never the object you handed it. Table
    -- identity cannot survive that trip, so the match always failed and
    -- every edit answered "that entry is gone". A NUMBER survives, so the
    -- index is passed and the real object looked up on our side.
    function clip.renderEdit(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        editSnapshot = {}
        local choices = {}
        if #_G.clipboardCache == 0 then
            -- An empty history gets no action rows — nothing to pick.
        elseif clip.selectMode then
            local n = clip.taggedCount()
            choices[#choices + 1] = {
                text    = (n == 0) and "☑️ Nothing picked yet"
                          or ("🗑 Delete the " .. n .. " I picked"),
                subText = (n == 0)
                          and "Go down the list and press Enter on the rows you want"
                          or "Press Enter HERE to delete them all",
                action  = "deletetagged",
            }
            choices[#choices + 1] = {
                text    = "📋 Copy the picked rows as ONE text",
                subText = (n == 0) and "Pick rows first"
                          or (n .. " row" .. ((n == 1) and "" or "s")
                              .. " joined with line breaks, then copied"),
                action  = "copytagged",
            }
            choices[#choices + 1] = {
                text    = "✖️ Never mind — go back",
                subText = "Forget the picks and return to one-at-a-time editing",
                action  = "selectoff",
            }
        else
            choices[#choices + 1] = {
                text    = "☑️ Select several…",
                subText = "Pick rows with Enter, then delete them or copy them as one",
                action  = "selecton",
            }
        end
        local shown = 0
        for i, item in ipairs(_G.clipboardCache) do
            if q == "" or (item.text or ""):lower():find(q, 1, true) then
                editSnapshot[i] = item
                local hint
                if not clip.selectMode then hint = "Enter to edit or delete"
                elseif clip.tagged[item] then hint = "PICKED — Enter unpicks it"
                else hint = "Enter picks it" end
                choices[#choices + 1] = {
                    text    = (clip.tagged[item] and "✓ " or "")
                              .. oneLine(item.text or ""):sub(1, clip.preview),
                    subText = (item.date or "") .. "  ·  " .. hint,
                    idx     = i,
                    rawText = item.text,        -- 👁 for the preview pane
                    when    = item.date or "",
                }
                shown = shown + 1
                if shown >= clip.rows then break end
            end
        end
        if shown == 0 then
            choices[#choices + 1] = {
                text = (q == "") and "Clipboard history is empty"
                       or ("No matches for \"" .. q .. "\""),
                subText = "",
            }
        end
        clip.lastEditChoices = choices      -- 👁 what the preview pane indexes
        clip.pv.gen = clip.pv.gen + 1
        clip.editChooser:choices(choices)
    end

    function clip.applyEdit(idxFromChoice, text)
        local entry = editSnapshot[idxFromChoice]
        if not entry then return "gone" end
        -- Re-find the entry's CURRENT position: a copy made while the
        -- picker was open shifts every index.
        local idx = nil
        for i, v in ipairs(_G.clipboardCache) do
            if v == entry then idx = i break end
        end
        if not idx then return "gone" end

        if not text or text:match("^%s*$") then
            table.remove(_G.clipboardCache, idx)
            clip.save()
            return "deleted"
        end
        _G.clipboardCache[idx].text = text
        clip.save()
        -- 🚨 THE EDITED TEXT GOES ON THE CLIPBOARD, and the ORDER matters.
        -- Setting the pasteboard wakes the watcher, which would normally
        -- file a second entry. It does not, because clip.add's dedupe
        -- removes any entry matching the arriving text and this one now
        -- carries exactly that text — so it is lifted to the front rather
        -- than copied. The cache must hold the new text BEFORE the
        -- pasteboard does, or the duplicate reappears.
        pcall(function() hs.pasteboard.setContents(text) end)
        return "updated"
    end

    -- ---- wiring ------------------------------------------------------------
    if clip.enabled then
        clip.chooser = hs.chooser.new(function(c)
            if c and c.rawText then
                pcall(function() hs.pasteboard.setContents(c.rawText) end)
                hs.alert.show("📋 Copied")
            end
        end)
        -- ⎋ 6.93.0: filed in _G.choosers so Esc closes ⇪V before the cheat sheet
        _G.choosers = _G.choosers or {}
        _G.choosers.clipboardHistory = clip.chooser
        pcall(function()
            clip.chooser:placeholderText("Search Clipboard History...")
        end)
        -- 👁 the pane goes down with the picker — Esc, a pick, a click away
        -- — and waits out a nudge (6.155.0, see previewSuspend)
        pcall(function()
            clip.chooser:hideCallback(function() clip.previewSuspend() end)
        end)
        clip.chooser:queryChangedCallback(function(query)
            local ok, err = pcall(clip.render, query)
            if not ok then
                warn("render failed: " .. tostring(err))
                clip.chooser:choices({ { text = "⚠️ Display error — see Console",
                                         subText = tostring(err) } })
            end
        end)

        local function reopenEdit()
            clip.renderEdit("")
            pcall(function() clip.editChooser:query("") end)
            openEdit()
        end

        clip.editChooser = hs.chooser.new(function(choice)
            if not choice then return end
            if choice.action == "selecton" then
                clip.selectMode, clip.tagged = true, {}
                reopenEdit(); return
            elseif choice.action == "selectoff" then
                clip.selectMode, clip.tagged = false, {}
                reopenEdit(); return
            elseif choice.action == "deletetagged" then
                local n = clip.deleteTagged()
                hs.alert.show((n > 0)
                    and ("🗑 Deleted " .. n .. " clipboard entr"
                         .. ((n == 1) and "y" or "ies"))
                    or "Nothing picked — press Enter on the rows you want first")
                return
            elseif choice.action == "copytagged" then
                local n = clip.copyTagged()
                hs.alert.show((n > 0)
                    and ("📋 Copied " .. n .. " entr" .. ((n == 1) and "y" or "ies")
                         .. " as one")
                    or "Nothing picked — press Enter on the rows you want first")
                return
            end
            if not choice.idx then return end
            if clip.selectMode then
                local entry = editSnapshot[choice.idx]
                if entry then
                    if clip.tagged[entry] then clip.tagged[entry] = nil
                    else clip.tagged[entry] = true end
                end
                reopenEdit(); return
            end
            local b, text = hs.dialog.textPrompt(
                "✏️ Edit clipboard entry",
                "Edit the text below.\nSave with it EMPTY to delete this entry.",
                (editSnapshot[choice.idx] or {}).text or "", "Save", "Cancel")
            if b ~= "Save" then return end
            local result = clip.applyEdit(choice.idx, text)
            if result == "gone" then
                hs.alert.show("⚠️ That entry is gone — history changed since "
                              .. "this picker opened")
            elseif result == "deleted" then
                hs.alert.show("🗑 Clipboard entry deleted")
            else
                hs.alert.show("✏️ Clipboard entry updated — and copied")
            end
        end)
        _G.choosers = _G.choosers or {}
        _G.choosers.clipboardEdit = clip.editChooser   -- ⎋ 6.93.0: same rule for ⇪⇧V
        pcall(function()
            clip.editChooser:placeholderText(
                "Search clipboard history to edit or delete — Enter opens a row")
        end)
        pcall(function()
            clip.editChooser:hideCallback(function() clip.previewSuspend() end)
        end)
        clip.editChooser:queryChangedCallback(function(query)
            local ok, err = pcall(clip.renderEdit, query)
            if not ok then
                warn("edit render failed: " .. tostring(err))
                clip.editChooser:choices({ { text = "⚠️ Display error — see Console",
                                             subText = tostring(err) } })
            end
        end)

        -- ⇪V / ⇪⇧V. The old ⌃⌥⌘V and ⌃⌥⌘⇧V chords are what §0.4's
        -- migration map POINTS AT these; binding the hyper keys directly
        -- is the same destination without the indirection.
        core.hyperAddShortcut({}, clip.key, function()
            clip.render("")
            openMain()
        end, "clipboard history")

        core.hyperAddShortcut({ "shift" }, clip.key, function()
            -- A fresh ⇪⇧V always starts in one-at-a-time mode: reopening
            -- into week-old ✓ marks is how the wrong rows get deleted.
            clip.selectMode, clip.tagged = false, {}
            clip.renderEdit("")
            openEdit()
        end, "clipboard edit")
    end

    -- 🗂 6.116.0 — listed for the ⌘⌘ editor picker. There is no `view`: a
    -- chooser is not a window this config can bring forward, so ⏎ always
    -- opens a fresh one, which for a picker is the same thing.
    --
    -- 🚨 INSIDE the enabled check. clip.chooser is only built when this
    -- module is enabled, so registering unconditionally would put a row in
    -- the picker whose ⏎ calls a method on nil — a dead row is worse than
    -- an absent one, because you only find out by pressing it.
    if clip.enabled then
        _G.editors = _G.editors or {}
        table.insert(_G.editors, {
            name  = "Clipboard",
            -- 6.132.0 — LL: "Shouldn't this be in the edit picker? ⇪⇧V."
            -- It was: ⇪⇧V is this row's EDIT view. The row simply never
            -- said so, so the picker read as if ⇪V were the only way in.
            -- Same shape as the Screenshots row's "⇪4 / ⇪⇧4", where the
            -- second key is likewise a different view, not a second door
            -- into the same one.
            key   = "⇪V / ⇪⇧V",
            what  = "everything you have copied",
            order = 40,
            unit  = "items",
            show  = function()
                clip.render("")
                openMain()
            end,
            size  = function() return #(_G.clipboardCache or {}) end,
            text  = function()
                local top = (_G.clipboardCache or {})[1]
                return top and top.text or nil
            end,
            -- 💾 6.130.0 — the whole history for the one-file CSV export.
            -- `text` above is the ⌥⏎ answer and is deliberately just the
            -- newest item; this is every item, and the cache is stored
            -- newest-first already, which is the order the export wants.
            csv   = function()
                local out = {}
                for _, it in ipairs(_G.clipboardCache or {}) do
                    if type(it) == "table" and type(it.text) == "string" then
                        out[#out + 1] = { when = it.date, text = it.text }
                    end
                end
                return out
            end,
        })
    end

    core.provide("clipboard.add",   function(t) return clip.add(t)   end)
    core.provide("clipboard.save",  function()  return clip.save()   end)
    core.provide("clipboard.count", function()  return #_G.clipboardCache end)
    -- 👁 6.156.0 — THE PANE IS A SERVICE. Any picker whose rows carry a
    -- rawText (and, optionally, a head line) can have the same pane beside
    -- it: hand over the chooser and a function returning the rows AS SHOWN
    -- (the caller must do its own filtering, so row indexes match). One
    -- pane at a time — the second opener closes the first.
    core.provide("preview.open",    function(ch, rowsFn) return clip.previewOpen(ch, rowsFn) end)
    core.provide("preview.suspend", function() clip.previewSuspend() return true end)
    core.provide("preview.close",   function() clip.previewClose()   return true end)

    -- ⏱ THE FILE IS READ IN warm(), NOT setup(). It can be a megabyte and
    -- it is on the boot path otherwise. Copies made in the ~2 seconds
    -- before it lands are kept in clip.preload and re-applied on top
    -- afterwards, so nothing copied during boot is lost to the load.
    M.warm = function()
        clip.load()
        for i = #clip.preload, 1, -1 do
            local t = clip.preload[i]
            local cache = _G.clipboardCache
            for j = #cache, 1, -1 do
                if cache[j].text == t then table.remove(cache, j) end
            end
            table.insert(cache, 1, { date = os.date("%b %d %H:%M"), text = t })
        end
        while #_G.clipboardCache > clip.max do table.remove(_G.clipboardCache) end
        if #clip.preload > 0 then clip.save() end
        clip.preload, clip.loaded = {}, true
        say(#_G.clipboardCache .. " items loaded")
    end

    _G.clipboardHistory = clip
    M.clip   = clip
    M.config = clip
end

return M
