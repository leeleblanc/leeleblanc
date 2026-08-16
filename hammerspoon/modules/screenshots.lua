-- =====================================================================
-- MODULE: SCREENSHOTS (⇪4) — every capture saved to OneDrive AND copied
-- =====================================================================
-- ⇪4 starts the native crosshair capture (the same one ⌘⇧4 gives you;
-- press SPACE mid-selection to switch to window capture, Esc to bail).
-- The image lands in BOTH places at once:
--
--   1. A timestamped PNG in OneDrive's "2026 Screenshots" folder, so it
--      syncs and survives.
--   2. The macOS clipboard, so ⌘V pastes it immediately.
--
-- macOS itself makes you choose — ⌘⇧4 saves a file, ⌘⌃⇧4 copies to the
-- clipboard, never both. This module runs `screencapture -i` to a file
-- and then reads that file back onto the clipboard, which is the whole
-- trick.
--
-- ⇪⇧4 opens the SCREENSHOT PANEL (6.87.0): eight action rows on top
-- (⌘1–⌘8 jump straight to one), your history below — newest first,
-- each row with a thumbnail. TYPING SEARCHES (6.88.0): the moment the
-- query is non-empty the action rows step aside and every matching
-- screenshot is listed — filename, date and size all match, so "aug 13"
-- or "edited" or "1.2 MB" each work. Backspace to empty brings the
-- actions back. On a history row: ⏎ puts the image back on the
-- clipboard, ⌘⏎ copies its file PATH (which is exactly what the Task
-- Form's 📎 field wants), ⌥⏎ opens it in the EDITOR
-- (modules/screenshot_editor.lua), and ⌃⏎ COMPRESSES it — sips (the
-- macOS image tool) writes a "… (compressed).jpg" next to the original
-- and puts THAT on the clipboard; the PNG stays untouched.
--
--   1 · Capture area          native crosshair, like ⇪4
--   2 · Scrolling capture     EXPERIMENTAL — see the honest note below
--   3 · Recognize text / QR   text via your HS OCR Shortcut; QR via
--                             zbar when installed (brew install zbar)
--   4 · Blur / edit newest    the newest screenshot, straight into the editor
--   5 · Repeat last area      re-shoot the exact same rectangle
--   6 · Capture active window frontmost window, no clicking
--   7 · Delayed (10s)         full screen, ten seconds from now
--
-- Captures started FROM THE PANEL open the editor when they finish
-- (shots.editAfterMenu below turns that off); ⇪4 stays the instant
-- no-window path.
--
-- ---------------------------------------------------------------------
-- 🧻 SCROLLING CAPTURE — EXPERIMENTAL, AND WHY THAT WORD IS THERE
-- ---------------------------------------------------------------------
-- Real scrolling capture (CleanShot, Shottr) stitches by IMAGE
-- ALIGNMENT — it finds where two frames overlap. Hammerspoon has no
-- image-diff machinery, so this one works by trust instead: it sends
-- pixel-exact scroll events (scroll down exactly as many pixels as the
-- captured area is tall), shoots a slice after each, and stacks the
-- slices. Browsers and most editors honor pixel scrolls exactly →
-- seamless. Apps that snap scrolling to lines or rubber-band → visible
-- seams. Sticky headers repeat in every slice; shots.scroll.cropTop
-- crops that many points off the top of every slice after the first.
-- The pointer is parked in the selected area first, because macOS
-- routes scroll events to whatever is under the pointer.
--
-- ---------------------------------------------------------------------
-- 🚫 WHAT IT DELIBERATELY DOES NOT DO: WATCH THE CLIPBOARD
-- ---------------------------------------------------------------------
-- The other way to get "copied images end up in a folder" is a
-- pasteboard watcher that saves every image that ever crosses the
-- clipboard. That fires on every image copied out of a browser, a PDF,
-- a Slack thread — and quietly fills the folder with junk that was
-- never a screenshot. A deliberate keystroke saves exactly what you
-- meant to keep, and nothing else.
--
-- ---------------------------------------------------------------------
-- ☁️ ONEDRIVE, TWO HONEST CAVEATS
-- ---------------------------------------------------------------------
--   · WRITES are safe: the folder is inside ~/Library/CloudStorage, so
--     the file is written locally and OneDrive uploads it in its own
--     time. No capture ever waits on the network.
--   · READS can stall: Files-On-Demand may have evicted an OLD
--     screenshot to cloud-only. Picking one of those in the history
--     forces a download first — a beat of delay on ancient rows, never
--     on fresh ones. The picker's thumbnails read the files too, which
--     is why the list is capped (shots.maxList) instead of thumbnailing
--     the whole folder.
-- =====================================================================

local M = {
    name  = "Screenshots",
    order = 23,
    cheatsheet = {
        title = "📸 SCREENSHOTS (⇪4 capture · ⇪⇧4 panel)",
        entries = {
            { "⇪4",   "Instant capture: crosshair · SPACE = window · Esc = cancel" },
            { "",     "saves to OneDrive/2026 Screenshots + copies to clipboard" },
            { "⇪⇧4",  "Panel: 8 actions (⌘1–⌘8) + history below · ⌘8 = BIG thumbnails" },
            { "⌘1–7", "area · scrolling · text/QR · edit newest · repeat · window · 10s" },
            { "type",  "search the history — actions step aside while you type" },
            { "⏎",    "history row: image on clipboard · ⌘⏎ its file PATH" },
            { "⌥⏎",   "history row: open in the editor (blur/text/arrows)" },
            { "⌃⏎",   "history row: compress to “… (compressed).jpg” + clipboard" },
        },
    },
}

function M.setup(core)
    local shots = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    shots.enabled   = true
    shots.key       = "4"     -- ⇪4 capture · ⇪⇧4 panel (mnemonic: ⌘⇧4)
    shots.dir       = (core.homeDir or os.getenv("HOME") or "")
                      .. "/Library/CloudStorage/OneDrive-Personal/2026 Screenshots"
    shots.maxList   = 30      -- newest N screenshots shown in the panel
    shots.historyRows = 8     -- history rows VISIBLE below the action rows
    shots.thumbH    = 72      -- thumbnail height in panel rows, pixels
    shots.alertSecs = 2.0
    shots.jpegQuality = 70    -- ⌃⏎ compress: sips jpeg formatOptions 0–100
    -- captures started from the ⇪⇧4 panel open the blur editor when done;
    -- ⇪4 never does (it is the fast path)
    shots.editAfterMenu = true
    shots.delaySecs     = 10          -- the "Delayed" action's countdown
    shots.ocrShortcut   = "HS OCR"    -- same Shortcut ⇪O's OCR index uses
    -- 🧻 scrolling capture (EXPERIMENTAL — see header)
    shots.scroll = {
        height    = 2000,   -- total pixels of page to capture, top slice included
        settle    = 0.4,    -- seconds to let the app finish scrolling per step
        cropTop   = 0,      -- points to crop off slices 2+ (sticky headers)
        maxSlices = 12,     -- hard cap, whatever `height` asks for
    }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("screenshots", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("screenshots", m) end end

    -- ---- folder ----------------------------------------------------------
    -- Checked at CAPTURE time, not at boot: setup() must stay cheap, and
    -- on the hostile Mac (no OneDrive, hs.fs answering nil) the module
    -- should degrade to a clear alert, not a boot error.
    function shots.ensureDir()
        local mode
        pcall(function() mode = hs.fs.attributes(shots.dir, "mode") end)
        if mode == "directory" then return shots.dir end
        local made = false
        pcall(function() made = hs.fs.mkdir(shots.dir) end)
        if made then
            say("created " .. shots.dir)
            return shots.dir
        end
        -- mkdir cannot create parents; if OneDrive-Personal itself is
        -- missing (not signed in, different account name) say WHERE it
        -- looked rather than failing into the Console.
        pcall(function()
            hs.alert.show("📸 Screenshots folder unavailable:\n" .. shots.dir, 4)
        end)
        warn("folder unavailable: " .. shots.dir)
        return nil
    end

    -- ---- filenames -------------------------------------------------------
    -- Same shape macOS uses ("Screenshot 2026-08-15 at 14.23.05.png") so
    -- the folder sorts naturally in Finder. Dots in the time, not colons:
    -- HFS+/APFS display colons as slashes and some sync targets refuse
    -- them outright.
    function shots.filenameAt(t)
        return os.date("Screenshot %Y-%m-%d at %H.%M.%S", t) .. ".png"
    end

    local function freshPath()
        local base = shots.dir .. "/" .. shots.filenameAt()
        local exists
        pcall(function() exists = hs.fs.attributes(base, "size") end)
        if not exists then return base end
        -- two captures inside one second — number the second one rather
        -- than letting screencapture overwrite the first
        for n = 2, 99 do
            local p = base:gsub("%.png$", (" (%d).png"):format(n))
            local e
            pcall(function() e = hs.fs.attributes(p, "size") end)
            if not e then return p end
        end
        return base
    end

    -- ---- capture (⇪4 and the panel's variants) ---------------------------
    function shots.finish(path, thenEdit)
        -- Esc during selection: screencapture exits WITHOUT writing the
        -- file. That is a cancel, not an error — stay silent.
        local size
        pcall(function() size = hs.fs.attributes(path, "size") end)
        if not size or size == 0 then
            say("capture cancelled")
            return false
        end
        local img
        pcall(function() img = hs.image.imageFromPath(path) end)
        local copied = false
        if img then
            pcall(function() copied = hs.pasteboard.writeObjects(img) and true end)
        end
        if thenEdit then
            -- panel-initiated capture: straight into the blur editor.
            -- The file + clipboard above already happened, so a missing
            -- editor module costs only the window, never the capture.
            local opened = core.call("screenshotEditor.open", path)
            if not opened then
                pcall(function()
                    hs.alert.show("📸 Saved · copied — editor unavailable", shots.alertSecs)
                end)
            end
        elseif copied then
            pcall(function()
                hs.alert.show("📸 Saved to 2026 Screenshots · on the clipboard",
                              shots.alertSecs)
            end)
        else
            -- The file is the half that must never be lost; say so
            -- plainly instead of pretending the copy worked.
            pcall(function()
                hs.alert.show("📸 Saved to 2026 Screenshots — clipboard copy failed",
                              shots.alertSecs)
            end)
        end
        say("captured " .. (path:match("[^/]+$") or path)
            .. (copied and " (copied)" or " (copy FAILED)"))
        return true
    end

    -- One task-runner for every screencapture variant: same holding
    -- pattern, same failure alerts, different argument lists.
    function shots.runCapture(args, path, thenEdit, onDone)
        local t
        local ok = pcall(function()
            t = hs.task.new("/usr/sbin/screencapture", function()
                shots.captureTask = nil    -- release only when done
                if onDone then
                    onDone(path)
                else
                    shots.finish(path, thenEdit)
                end
            end, args)
        end)
        if not (ok and t) then
            pcall(function() hs.alert.show("📸 screencapture unavailable", 3) end)
            warn("hs.task.new failed for screencapture")
            return false
        end
        shots.captureTask = t   -- HELD: an unreferenced hs.task is collected
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            shots.captureTask = nil
            pcall(function() hs.alert.show("📸 could not start screencapture", 3) end)
            return false
        end
        return true
    end

    function shots.capture(thenEdit)
        if not shots.ensureDir() then return end
        local path = freshPath()
        shots.runCapture({ "-i", path }, path, thenEdit)
    end

    -- Panel action 5 — the exact same rectangle again. The rect comes
    -- from our own selector (native -i cannot report where you dragged),
    -- is remembered for the session, and -R re-shoots it on demand.
    function shots.captureRect(rect, thenEdit)
        if not shots.ensureDir() then return end
        local path = freshPath()
        shots.lastRect = rect
        shots.runCapture({
            "-x",
            ("-R%d,%d,%d,%d"):format(rect.x, rect.y, rect.w, rect.h),
            path,
        }, path, thenEdit)
    end

    function shots.repeatArea(thenEdit)
        if shots.lastRect then
            shots.captureRect(shots.lastRect, thenEdit)
        else
            shots.selectArea(function(rect) shots.captureRect(rect, thenEdit) end)
        end
    end

    -- Panel action 6 — the frontmost window, no clicking. -l takes the
    -- window's CGWindowID, which hs.window already knows.
    function shots.captureWindow(thenEdit)
        local id
        pcall(function()
            local w = hs.window.frontmostWindow()
            id = w and w:id()
        end)
        if not id then
            pcall(function() hs.alert.show("📸 No frontmost window to capture", 3) end)
            return
        end
        if not shots.ensureDir() then return end
        local path = freshPath()
        shots.runCapture({ "-x", "-l", tostring(id), path }, path, thenEdit)
    end

    -- Panel action 7 — screencapture's own -T does the countdown, so the
    -- panel can close and the Mac can be arranged in peace.
    function shots.captureDelayed(thenEdit)
        if not shots.ensureDir() then return end
        local path = freshPath()
        pcall(function()
            hs.alert.show(("📸 Full screen in %d seconds — set it up…")
                          :format(shots.delaySecs), 2.5)
        end)
        shots.runCapture({ "-x", "-T", tostring(shots.delaySecs), path },
                         path, thenEdit)
    end

    -- ---- our own area selector -------------------------------------------
    -- Needed because native `screencapture -i` never reports WHERE you
    -- dragged — and both "repeat this area" and the scrolling capture
    -- need the rectangle as numbers. A full-screen dimmed canvas, a
    -- dashed band that follows the drag, Esc bails out.
    function shots.cancelSelect()
        if shots.selTap then
            pcall(function() shots.selTap:stop() end)
            shots.selTap = nil
        end
        if shots.selCanvas then
            pcall(function() shots.selCanvas:delete() end)
            shots.selCanvas = nil
        end
    end

    function shots.selectArea(cb)
        shots.cancelSelect()
        local scr
        pcall(function() scr = hs.mouse.getCurrentScreen() end)
        if not scr then
            pcall(function()
                scr = core.resolveBaseScreen and core.resolveBaseScreen()
                      or hs.screen.mainScreen()
            end)
        end
        if not scr then return end
        local sf
        pcall(function() sf = scr:frame() end)
        if not sf then return end

        local canvas
        pcall(function() canvas = hs.canvas.new(sf) end)
        if not canvas then return end
        canvas:appendElements(
            { type = "rectangle", action = "fill",
              fillColor = { black = 1, alpha = 0.18 } },
            { type = "rectangle", action = "stroke",
              strokeColor = { red = 0.29, green = 0.5, blue = 0.88, alpha = 0.95 },
              strokeWidth = 2, strokeDashPattern = { 6, 4 },
              frame = { x = 0, y = 0, w = 0, h = 0 } })
        pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
        pcall(function()
            canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        pcall(function() canvas:canvasMouseEvents(true, true, false, true) end)

        local startPt = nil
        pcall(function()
            canvas:mouseCallback(function(_, msg, _, mx, my)
                -- mouseCallback runs per event — same rule as an eventtap:
                -- an error here repeats forever, so the body is guarded
                local ok = pcall(function()
                    if msg == "mouseDown" then
                        startPt = { x = mx, y = my }
                    elseif msg == "mouseMove" and startPt then
                        canvas[2].frame = {
                            x = math.min(startPt.x, mx), y = math.min(startPt.y, my),
                            w = math.abs(mx - startPt.x), h = math.abs(my - startPt.y),
                        }
                    elseif msg == "mouseUp" and startPt then
                        local rect = {
                            x = math.floor(sf.x + math.min(startPt.x, mx)),
                            y = math.floor(sf.y + math.min(startPt.y, my)),
                            w = math.floor(math.abs(mx - startPt.x)),
                            h = math.floor(math.abs(my - startPt.y)),
                        }
                        shots.cancelSelect()
                        if rect.w >= 8 and rect.h >= 8 then cb(rect) end
                    end
                end)
                if not ok then shots.cancelSelect() end
            end)
        end)
        -- showCanvasSafely, not canvas:show(): show() THROWS when another
        -- process's remote view is mid-transition (the Safari/Spotlight
        -- bug every canvas popup in this config guards against)
        if _G.showCanvasSafely then
            _G.showCanvasSafely(canvas, "area selector")
        end
        shots.selCanvas = canvas   -- HELD

        -- Esc = never mind. keyDown 53 is Escape; the callback is
        -- pcall'd and answers true (swallow) only for that one key.
        -- the handler is NAMED and invoked through pcall — the guarded
        -- tap shape every keyDown watcher in this config uses: an error
        -- in here would otherwise raise once per keystroke until macOS
        -- switches the tap off
        function shots.selEscape(ev)
            -- another module's synthetic typing is not the user
            -- pressing Esc (core/coexist.lua rule)
            if _G.typingInjection and _G.typingInjection() then
                return false
            end
            if ev:getKeyCode() == 53 then
                shots.cancelSelect()
                return true
            end
            return false
        end
        pcall(function()
            shots.selTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown },
                function(ev)
                    local ok, swallow = pcall(shots.selEscape, ev)
                    return ok and swallow or false
                end)
            shots.selTap:start()
        end)
        pcall(function() hs.alert.show("🖱 Drag an area · Esc cancels", 1.2) end)
    end

    -- ---- scrolling capture (EXPERIMENTAL — see header) -------------------
    -- The PLAN is pure and tested: slice 1 is the selection as-is, every
    -- later slice scrolls by (height - cropTop) and crops cropTop off its
    -- top, until `target` pixels are covered or the cap says stop.
    function shots.scrollPlan(rectH, target, cropTop)
        rectH   = math.floor(tonumber(rectH) or 0)
        target  = math.floor(tonumber(target) or 0)
        cropTop = math.max(0, math.floor(tonumber(cropTop) or 0))
        if rectH <= 0 then return {}, 0 end
        if cropTop >= rectH then cropTop = 0 end
        local plan = { { scroll = 0, crop = 0 } }
        local covered, step = rectH, rectH - cropTop
        while covered < target and #plan < shots.scroll.maxSlices do
            plan[#plan + 1] = { scroll = step, crop = cropTop }
            covered = covered + step
        end
        return plan, covered
    end

    function shots.stitch(files, rect, plan, thenEdit)
        local outPath
        local ok, err = pcall(function()
            local imgs, heights, w, totalH = {}, {}, 0, 0
            for i, f in ipairs(files) do
                local img = hs.image.imageFromPath(f)
                if img then
                    local sz = img:size()
                    -- the FILE is in pixels, the SELECTION is in points;
                    -- Retina makes them differ by 2x, so the crop scales
                    local scale = sz.w / rect.w
                    local cropPx = math.floor((plan[i].crop or 0) * scale)
                    if cropPx > 0 and img.croppedCopy then
                        img = img:croppedCopy({ x = 0, y = cropPx,
                                                w = sz.w, h = sz.h - cropPx })
                        sz = img:size()
                    end
                    imgs[#imgs + 1] = img
                    heights[#heights + 1] = sz.h
                    w = math.max(w, sz.w)
                    totalH = totalH + sz.h
                end
            end
            assert(#imgs > 0 and totalH > 0, "no slices decoded")
            local canvas = hs.canvas.new({ x = 0, y = 0, w = w, h = totalH })
            local y = 0
            for i, img in ipairs(imgs) do
                canvas:appendElements({
                    type = "image", image = img, imageScaling = "none",
                    frame = { x = 0, y = y, w = w, h = heights[i] },
                })
                y = y + heights[i]
            end
            local outImg = canvas:imageFromCanvas()
            canvas:delete()
            assert(outImg, "canvas would not render")
            outPath = shots.dir .. "/"
                      .. shots.filenameAt():gsub("%.png$", " (scrolling).png")
            assert(outImg:saveToFile(outPath), "could not write " .. outPath)
        end)
        for _, f in ipairs(files) do pcall(os.remove, f) end
        if not ok then
            pcall(function()
                hs.alert.show("🧻 Stitch failed — slices discarded ("
                              .. tostring(err) .. ")", 4)
            end)
            warn("stitch: " .. tostring(err))
            return
        end
        shots.finish(outPath, thenEdit)
    end

    function shots.scrollingCapture(thenEdit)
        if not shots.ensureDir() then return end
        shots.selectArea(function(rect)
            local plan = shots.scrollPlan(rect.h, shots.scroll.height,
                                          shots.scroll.cropTop)
            if #plan == 0 then return end
            -- scroll events go to whatever is UNDER THE POINTER — park it
            pcall(function()
                hs.mouse.absolutePosition({ x = rect.x + rect.w / 2,
                                            y = rect.y + rect.h / 2 })
            end)
            local files, i = {}, 0
            local function step()
                i = i + 1
                if i > #plan then
                    shots.stitch(files, rect, plan, thenEdit)
                    return
                end
                local function shoot()
                    -- dot-file name: our own list() skips dot-files, so a
                    -- half-done run never shows up in the history panel
                    local slice = shots.dir .. ("/.scroll-slice-%02d.png"):format(i)
                    local okRun = shots.runCapture({
                        "-x",
                        ("-R%d,%d,%d,%d"):format(rect.x, rect.y, rect.w, rect.h),
                        slice,
                    }, slice, false, function()
                        files[#files + 1] = slice
                        step()
                    end)
                    if not okRun then
                        for _, f in ipairs(files) do pcall(os.remove, f) end
                    end
                end
                if plan[i].scroll > 0 then
                    pcall(function()
                        hs.eventtap.event.newScrollEvent(
                            { 0, -plan[i].scroll }, {}, "pixel"):post()
                    end)
                    shots.scrollTimer = hs.timer.doAfter(shots.scroll.settle, shoot)
                else
                    shoot()
                end
            end
            pcall(function()
                hs.alert.show(("🧻 Scrolling: %d slices…"):format(#plan), 1.5)
            end)
            step()
        end)
    end

    -- ---- recognize text / QR ---------------------------------------------
    -- Text rides the SAME Apple Shortcut ⇪O's OCR index uses. QR needs a
    -- decoder macOS does not ship — zbar's zbarimg, when brew installed
    -- it. QR is tried first (exact payloads beat OCR's guess at one).
    function shots.zbarPath()
        if shots._zbar ~= nil then
            return shots._zbar or nil
        end
        local home = core.homeDir or os.getenv("HOME") or ""
        for _, p in ipairs({
            "/opt/homebrew/bin/zbarimg", "/usr/local/bin/zbarimg",
            home .. "/homebrew/bin/zbarimg", home .. "/.homebrew/bin/zbarimg",
            home .. "/.local/homebrew/bin/zbarimg",
        }) do
            local sz
            pcall(function() sz = hs.fs.attributes(p, "size") end)
            if sz then shots._zbar = p return p end
        end
        shots._zbar = false
        return nil
    end

    function shots.recognizeFile(path)
        local function ocr()
            if _G.ocrShortcutAvailable == false then
                pcall(function()
                    hs.alert.show("📝 Needs the “" .. shots.ocrShortcut
                                  .. "” Shortcut (same one ⇪O uses)", 4)
                end)
                return
            end
            local t
            pcall(function()
                t = hs.task.new("/usr/bin/shortcuts", function(code, sout)
                    shots.ocrTask = nil
                    local text = tostring(sout or ""):match("^%s*(.-)%s*$") or ""
                    if code == 0 and text ~= "" then
                        pcall(function() hs.pasteboard.setContents(text) end)
                        pcall(function()
                            hs.alert.show("📝 Text copied: "
                                          .. text:gsub("%s+", " "):sub(1, 60), 3)
                        end)
                    else
                        pcall(function() hs.alert.show("📝 No text found", 2.5) end)
                    end
                end, { "run", shots.ocrShortcut, "-i", path })
                t:start()
            end)
            shots.ocrTask = t   -- HELD
        end

        local zbar = shots.zbarPath()
        if not zbar then ocr() return end
        local t
        pcall(function()
            t = hs.task.new(zbar, function(code, sout)
                shots.qrTask = nil
                local payload = tostring(sout or ""):match("^%s*(.-)%s*$") or ""
                if code == 0 and payload ~= "" then
                    pcall(function() hs.pasteboard.setContents(payload) end)
                    pcall(function()
                        hs.alert.show("🔳 Code copied: " .. payload:sub(1, 60), 3)
                    end)
                else
                    ocr()   -- no code in the image — fall through to text
                end
            end, { "--raw", "-q", path })
            t:start()
        end)
        if t then shots.qrTask = t else ocr() end
    end

    function shots.recognize()
        if not shots.ensureDir() then return end
        local path = freshPath()
        shots.runCapture({ "-i", path }, path, false, function()
            local size
            pcall(function() size = hs.fs.attributes(path, "size") end)
            if not size or size == 0 then return end   -- Esc = cancel
            shots.recognizeFile(path)
        end)
    end

    -- ---- listing ---------------------------------------------------------
    local IMAGE_EXT = { png = true, jpg = true, jpeg = true, gif = true,
                        tiff = true, heic = true, webp = true }

    function shots.list()
        local out = {}
        pcall(function()
            for f in hs.fs.dir(shots.dir) do
                local ext = f:match("%.(%w+)$")
                if f:sub(1, 1) ~= "." and ext and IMAGE_EXT[ext:lower()] then
                    local p = shots.dir .. "/" .. f
                    local mt, sz
                    pcall(function()
                        mt = hs.fs.attributes(p, "modification")
                        sz = hs.fs.attributes(p, "size")
                    end)
                    out[#out + 1] = { name = f, path = p,
                                      mtime = tonumber(mt) or 0,
                                      size  = tonumber(sz) or 0 }
                end
            end
        end)
        table.sort(out, function(a, b)
            if a.mtime ~= b.mtime then return a.mtime > b.mtime end
            return a.name > b.name   -- same second: the "(2)" copy first
        end)
        return out
    end

    function shots.latest()
        local l = shots.list()
        return l[1] and l[1].path or nil
    end

    -- ---- history picker (⇪⇧4) --------------------------------------------
    -- Thumbnails are the expensive part: hs.image.imageFromPath decodes
    -- the WHOLE png just to draw a 72px row. Two defences: the list cap,
    -- and this cache — keyed by path + mtime so an edited file re-reads
    -- but an unchanged one never decodes twice in a session.
    shots.thumbCache = {}

    local function thumbFor(entry)
        local c = shots.thumbCache[entry.path]
        if c and c.mtime == entry.mtime then return c.img end
        local img
        pcall(function()
            local full = hs.image.imageFromPath(entry.path)
            if full then
                img = full:setSize({ w = shots.thumbH * 1.6, h = shots.thumbH })
            end
        end)
        if img then
            shots.thumbCache[entry.path] = { mtime = entry.mtime, img = img }
        end
        return img
    end

    local function prettySize(bytes)
        if bytes >= 1024 * 1024 then
            return string.format("%.1f MB", bytes / (1024 * 1024))
        end
        return string.format("%d KB", math.max(1, math.floor(bytes / 1024)))
    end

    -- ---- ⌃⏎ compress (6.88.0) --------------------------------------------
    -- LL: "Can you give me an option to compress an image file if I want
    -- to?" — sips ships with macOS and re-encodes a PNG screenshot as a
    -- JPEG at a fraction of the size (screenshots compress spectacularly:
    -- flat color, hard edges). The original is NEVER touched; the small
    -- copy lands next to it and on the clipboard, ready to paste where a
    -- 3 MB PNG would be rude.
    function shots.compressedPathFor(path)
        local stem = path:gsub("%.%w+$", "")
        local candidate = stem .. " (compressed).jpg"
        local exists
        pcall(function() exists = hs.fs.attributes(candidate, "size") end)
        if not exists then return candidate end
        for n = 2, 99 do
            local p = stem .. (" (compressed %d).jpg"):format(n)
            local e
            pcall(function() e = hs.fs.attributes(p, "size") end)
            if not e then return p end
        end
        return candidate
    end

    function shots.compressFile(path)
        local origSz = 0
        pcall(function() origSz = hs.fs.attributes(path, "size") or 0 end)
        local outPath = shots.compressedPathFor(path)
        local t
        local ok = pcall(function()
            t = hs.task.new("/usr/bin/sips", function(code)
                shots.sipsTask = nil
                local newSz
                pcall(function() newSz = hs.fs.attributes(outPath, "size") end)
                if code == 0 and newSz and newSz > 0 then
                    local copied = false
                    pcall(function()
                        local img = hs.image.imageFromPath(outPath)
                        if img then
                            copied = hs.pasteboard.writeObjects(img) and true
                        end
                    end)
                    pcall(function()
                        hs.alert.show(("🗜 %s → %s%s"):format(
                            prettySize(origSz), prettySize(newSz),
                            copied and " · on the clipboard" or ""), 3)
                    end)
                    say(("compressed %s → %s"):format(prettySize(origSz),
                                                      prettySize(newSz)))
                else
                    pcall(function()
                        hs.alert.show("🗜 Compression failed — could not re-encode "
                                      .. (path:match("[^/]+$") or path), 4)
                    end)
                    warn("sips failed on " .. path)
                end
            end, { "-s", "format", "jpeg",
                   "-s", "formatOptions", tostring(shots.jpegQuality),
                   path, "--out", outPath })
            t:start()
        end)
        if ok and t then
            shots.sipsTask = t   -- HELD: an unreferenced hs.task is collected
        else
            pcall(function() hs.alert.show("🗜 sips unavailable", 3) end)
        end
    end

    -- ---- the ⇪⇧4 panel: eight actions, then history -----------------------
    -- hs.chooser numbers its first rows ⌘1–⌘9 natively, which is why the
    -- actions sit on top: ⌘3 IS "recognize text", no arrowing needed.
    function shots.actionRows()
        local qr = shots.zbarPath()
        return {
            { text = "📐 Capture area", act = "area",
              subText = "crosshair select — saved + copied, then the editor" },
            { text = "🧻 Scrolling capture (experimental)", act = "scroll",
              subText = ("drag an area — captures ~%dpx tall · best in browsers")
                        :format(shots.scroll.height) },
            { text = "🔤 Recognize text / QR", act = "recognize",
              subText = qr and "text via HS OCR · QR/barcodes via zbar"
                        or "text via HS OCR · QR needs `brew install zbar`" },
            { text = "🖌 Blur / edit newest screenshot", act = "editNewest",
              subText = "open the newest capture in the blur editor" },
            { text = "🔁 Repeat last area", act = "repeat",
              subText = shots.lastRect
                        and ("re-shoot %d×%d at %d,%d")
                            :format(shots.lastRect.w, shots.lastRect.h,
                                    shots.lastRect.x, shots.lastRect.y)
                        or "no area yet — you will drag one first" },
            { text = "🪟 Capture active window", act = "window",
              subText = "the frontmost window, no clicking" },
            { text = ("⏲ Delayed capture (%ds)"):format(shots.delaySecs),
              act = "delayed",
              subText = "full screen, after the countdown" },
            -- 6.89.0 — LL: "Thumbnails … must be 50% larger, I can't read
            -- them." A chooser row's height is fixed inside Hammerspoon
            -- itself, so the fix is one keystroke away instead: Unified
            -- Search draws the same folder at 84px. (⇪⇧space from anywhere.)
            { text = "🔎 BIG thumbnails — browse in Unified Search",
              act = "bigBrowse",
              subText = "same screenshots, 2× the thumbnail, searchable (⇪⇧space)" },
        }
    end

    function shots.runAction(act)
        local edit = shots.editAfterMenu
        if     act == "area"       then shots.capture(edit)
        elseif act == "scroll"     then shots.scrollingCapture(edit)
        elseif act == "recognize"  then shots.recognize()
        elseif act == "editNewest" then
            local p = shots.latest()
            if p then
                if not core.call("screenshotEditor.open", p) then
                    pcall(function() hs.alert.show("🖌 Editor unavailable", 3) end)
                end
            else
                pcall(function() hs.alert.show("📸 No screenshots yet — ⇪4 takes one", 3) end)
            end
        elseif act == "repeat"     then shots.repeatArea(edit)
        elseif act == "window"     then shots.captureWindow(edit)
        elseif act == "delayed"    then shots.captureDelayed(edit)
        elseif act == "bigBrowse"  then
            if not core.call("unified.show", "@shots ") then
                pcall(function()
                    hs.alert.show("🔎 Unified Search is not loaded", 3)
                end)
            end
        end
    end

    function shots.choicesFrom(list)
        local choices = {}
        for _, a in ipairs(shots.actionRows()) do choices[#choices + 1] = a end
        for i, e in ipairs(list) do
            if i > shots.maxList then break end
            choices[#choices + 1] = {
                text    = e.name,
                subText = os.date("%b %d %Y  %H:%M", e.mtime)
                          .. "  ·  " .. prettySize(e.size)
                          .. "  ·  ⏎ image · ⌘⏎ path · ⌥⏎ edit · ⌃⏎ jpg",
                path    = e.path,
            }
        end
        if #list == 0 then
            choices[#choices + 1] = {
                text    = "No screenshots yet",
                subText = "⇪4 takes one — it lands in " .. shots.dir,
            }
        end
        return choices
    end

    function shots.onPick(choice)
        if not choice then return end
        if choice.act then
            shots.runAction(choice.act)
            return
        end
        if not choice.path then return end
        -- hs.chooser reports nothing about modifiers, but the keyboard
        -- state at selection time is readable — same trick the window
        -- switcher uses. ⌘⏎ = the PATH, ⌥⏎ = the editor, ⌃⏎ = compress.
        local mods = {}
        pcall(function() mods = hs.eventtap.checkKeyboardModifiers() or {} end)
        if mods.ctrl then
            shots.compressFile(choice.path)
            return
        end
        if mods.cmd then
            local ok = false
            pcall(function() ok = hs.pasteboard.setContents(choice.path) end)
            pcall(function()
                hs.alert.show(ok and "📎 Path copied" or "⚠️ Could not copy path",
                              shots.alertSecs)
            end)
            return
        end
        if mods.alt then
            if not core.call("screenshotEditor.open", choice.path) then
                pcall(function() hs.alert.show("🖌 Editor unavailable", 3) end)
            end
            return
        end
        -- ☁️ this read is the one that can stall on a cloud-evicted file —
        -- see the OneDrive note in the header.
        local img
        pcall(function() img = hs.image.imageFromPath(choice.path) end)
        local copied = false
        if img then
            pcall(function() copied = hs.pasteboard.writeObjects(img) and true end)
        end
        pcall(function()
            hs.alert.show(copied and "📋 Screenshot on the clipboard"
                                  or "⚠️ Could not read that screenshot",
                          shots.alertSecs)
        end)
    end

    -- 6.88.0 — LL: "I can't tell if I can search the window." Typing now
    -- ANSWERS that: the query filters the HISTORY (name + date + size all
    -- match), and the action rows step aside while a query is live
    -- so the matches are all you see. Empty query = actions + history.
    function shots.filterChoices(query)
        query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local all = shots.allChoices or {}
        if query == "" then return all end
        local out = {}
        for _, c in ipairs(all) do
            if c.path then
                local hay = (tostring(c.text or "") .. " "
                             .. tostring(c.subText or "")):lower()
                if hay:find(query, 1, true) then out[#out + 1] = c end
            end
        end
        if #out == 0 then
            out[1] = { text = "No screenshots match “" .. query .. "”",
                       subText = "⌫ clears the search — the actions come back" }
        end
        return out
    end

    function shots.show()
        if not shots.chooser then
            local ok = pcall(function()
                shots.chooser = hs.chooser.new(function(choice)
                    shots.onPick(choice)
                end)
            end)
            if not (ok and shots.chooser) then
                shots.chooser = nil
                pcall(function() hs.alert.show("📸 panel unavailable", 3) end)
                return
            end
            -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.screenshots = shots.chooser
            pcall(function()
                shots.chooser:placeholderText(
                    "Type to search screenshots · ⌘1–⌘8 actions")
            end)
            pcall(function()
                shots.chooser:queryChangedCallback(function(q)
                    -- per-keystroke callback: guarded like an eventtap —
                    -- an error in here would repeat on every character
                    pcall(function()
                        shots.chooser:choices(shots.filterChoices(q))
                    end)
                end)
            end)
        end
        local list = shots.list()
        local choices = shots.choicesFrom(list)
        -- attach thumbnails AFTER choicesFrom so the pure list logic
        -- stays testable without hs.image
        for _, c in ipairs(choices) do
            if c.path then
                local mt
                for _, e in ipairs(list) do
                    if e.path == c.path then mt = e; break end
                end
                if mt then c.image = thumbFor(mt) end
            end
        end
        shots.allChoices = choices   -- what the search filter works over
        -- 6.88.0 — LL: "I don't see the image history." The default
        -- chooser height is 10 rows and the 7 actions ate 7 of them; the
        -- history was there but below the fold. Tall enough now that the
        -- actions AND a screenful of history are visible at once.
        pcall(function()
            local hist = math.max(1, math.min(#list, shots.historyRows))
            shots.chooser:rows(#shots.actionRows() + hist)
        end)
        pcall(function() shots.chooser:choices(choices) end)
        if core.showPopup then
            core.showPopup(shots.chooser)
        else
            pcall(function() shots.chooser:show() end)
        end
    end

    -- ---- keys & services -------------------------------------------------
    if shots.enabled then
        core.hyperAddShortcut({}, shots.key, function() shots.capture() end,
                              "screenshot — save + copy")
        core.hyperAddShortcut({ "shift" }, shots.key, function() shots.show() end,
                              "screenshot panel")
    end

    -- screenshots.latest is what the Task Form's 📸 button calls — one
    -- keystroke from "capture" to "attached to a task".
    core.provide("screenshots.latest",  function() return shots.latest() end)
    core.provide("screenshots.capture", function() return shots.capture() end)
    core.provide("screenshots.show",    function() return shots.show() end)

    _G.screenshots = shots
    M.shots  = shots
    M.config = shots
end

return M
