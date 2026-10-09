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
-- actions back.
--
-- ---------------------------------------------------------------------
-- 🔎 6.122.0 — TYPING SEARCHES THE WHOLE FOLDER, AND THE TEXT INSIDE
-- ---------------------------------------------------------------------
-- LL: "How do I search and bring up an image that is stored in the
-- screenshots folder?"
--
-- You could, and it was two things short of an answer.
--
--   1. IT ONLY EVER SAW THIRTY FILES. shots.maxList caps the list, for a
--      good reason — every row decodes a whole PNG to draw a 72px
--      thumbnail — but the SEARCH was filtering that same capped list.
--      Anything older than your last thirty captures was unfindable, and
--      nothing said so. The cap now applies to the idle view only: the
--      moment you type, the query runs over every file in the folder.
--
--   2. A SCREENSHOT'S NAME IS A TIMESTAMP, which is the one thing you
--      never remember about it. You remember what was ON it.
--
-- So the search now asks Spotlight as well, with mdfind, restricted to
-- this folder. That reaches two things a filename never could:
--
--   · THE TEXT THIS CONFIG ALREADY WROTE. ⇪O's OCR tagger has been
--     putting recognised text into each screenshot's Finder comment
--     since 6.98.0, and Spotlight indexes Finder comments. Every image
--     you have ever run through it is searchable by its own words, and
--     has been all along — nothing was reading it back.
--   · WHATEVER macOS INDEXED ITSELF, which on recent builds includes
--     text found in images without anybody asking.
--
-- Rows say WHICH of the two found them, because "matched the name" and
-- "matched the text inside it" are different claims and a row that
-- blurred them would be guessing on your behalf.
--
-- ⏳ THE SPOTLIGHT HALF IS ASYNCHRONOUS AND DEBOUNCED. mdfind is a
-- separate process; spawning one per keystroke would leave a queue of
-- them racing to answer a question you have already finished typing. The
-- name matches appear instantly, the Spotlight ones fold in a moment
-- later, and a result whose query is no longer what is in the box is
-- DISCARDED rather than shown.
--
-- ☁️ AND IT CAN LEGITIMATELY FIND NOTHING. This folder lives in
-- OneDrive; a file evicted to cloud-only may not be indexed, and
-- Spotlight can be switched off for a volume entirely. The name search
-- always runs, so the panel is never worse than it was — but "no text
-- matches" is not proof that no screenshot contains those words.
--
-- ---------------------------------------------------------------------
-- On a history row: ⏎ puts the image back on the
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
    family = "screen",
    cheatsheet = {
        title = "📸 SCREENSHOTS (⇪4 area · every tool on its own key)",
        entries = {
            { "⇪4",   "Area capture: drag on our selector, live size · Esc = cancel" },
            { "",     "saves to OneDrive/2026 Screenshots + copies to clipboard" },
            { "⇪⇧1",  "🖌 Blur / edit the newest screenshot" },
            { "⇪⇧2",  "🪟 Capture the active window — no clicking" },
            { "⇪⇧3",  "⏲ Delayed capture, full screen after the countdown" },
            { "⇪⇧4",  "🔤 Recognize text / QR — the words go to the clipboard" },
            -- 🔁 6.341.0 — 6.181.0's rule: the sheet is where the division
            -- between the two keys is readable, and until now it was
            -- nowhere. The OCR still runs on a ⇪4 shot in the background
            -- (it names the file and fills ⇪O); what it no longer does is
            -- take the picture off the clipboard.
            { "📋 which", "⇪4 leaves the PICTURE on the clipboard, always · ⇪⇧4 is" },
            { "",         "the OCR door · the words of a ⇪4 shot are in ⇪O and in" },
            { "",         "its file name · textToClipboard = true swaps them back" },
            { "⇪5",   "🧻 Scrolling capture (experimental) — best in browsers · the result is saved AND on the clipboard" },
            { "📐 size", "⇪4 / ⇪5 / “repeat area” / the editor's ⌘A show a LIVE 1280 × 720" },
            { "",        "white on 90%-opaque black · areaNative = true for macOS's" },
            { "",        "crosshairs follow the pointer and the numbers are there before" },
            { "",        "you press — crosshair = false turns the lines off" },
            { "check", "_G.screenshotsReport() — the folder, the watcher, and the last scrolling run slice by slice" },
            { "⇪⇧5",  "Panel: 9 actions (⌘1–⌘9) + history below · ⌘8 = BIG thumbnails" },
            { "🏷 names", "Every capture — ⇪4's AND other tools' SCR- files — gets" },
            { "",       "ITS OWN words in the name as it lands · ⌘9 sweeps the backlog" },
            { "type",  "searches the WHOLE folder — not just the newest 30 —" },
            { "",      "by name, by date, and by the TEXT INSIDE the image" },
            { "⏎",    "history row: image on clipboard · ⌘⏎ its file PATH" },
            { "⌥⏎",   "history row: open in the editor (blur/text/arrows)" },
            { "⌃⏎",   "history row: compress to “… (compressed).jpg” + clipboard" },
            { "⌃⌃",   "“Screenshots” in the editor picker — ⏎ OPENS THE FOLDER" },
        },
    },
}

function M.setup(core)
    local shots = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    shots.enabled   = true
    shots.copySuppressSecs = 10  -- 6.170.3: the poll sits out our own copy this long at most
    shots.key       = "4"     -- ⇪4 area capture (mnemonic: ⌘⇧4). UNCHANGED.
    -- 📸 6.194.0 — LL'S OWN MAP, in his words: "Blur/Edit: this would be
    -- the screenshot editor brought up by hyper+shift+1 · Screenshot
    -- Active window: hyper+shift+2 · Delay screenshot: hyper+shift+3 ·
    -- Area screenshot would be hyper+4 · Text capture would be
    -- hyper+shift+4 · Scrolling capture would be hyper+5."
    -- Every one of these already existed as a ROW in the ⌘1–⌘9 panel and
    -- ran through shots.runAction; giving them keys costs one table, not
    -- one new code path each. That is why the acts are named here rather
    -- than re-implemented — a key and its row are the SAME action, so
    -- they cannot drift.
    -- The PANEL moved off ⇪⇧4 to make room for text capture (LL's call);
    -- it now sits at ⇪⇧5, beside ⇪5 scrolling, so the whole screenshot
    -- family lives in the 1-5 block.
    shots.panelKey  = "5"     -- ⇪⇧5 the ⌘1–⌘9 panel (was ⇪⇧4 until 6.194.0)
    shots.toolKeys  = {
        -- combo (mods, key)          the act shots.runAction already knows
        { { "shift" }, "1", "editNewest", "screenshot editor"      },
        { { "shift" }, "2", "window",     "capture active window"  },
        { { "shift" }, "3", "delayed",    "delayed screenshot"     },
        { { "shift" }, "4", "recognize",  "text capture (OCR)"     },
        { {},          "5", "scroll",     "scrolling capture"      },
    }
    shots.dir       = (core.homeDir or os.getenv("HOME") or "")
                      .. "/Library/CloudStorage/OneDrive-Personal/2026 Screenshots"
    -- 🧻 6.213.3 — THE SLICES NEVER GO INTO THE SCREENSHOTS FOLDER. LL's
    -- first ⇪5 on 6.206.0 said it in screencapture's own words: "slice 1
    -- of 4: screencapture exit 0 — screencapture: cannot write file to
    -- intended destination, /Users/…/OneDrive-Personal/2026 Screenshots/…".
    -- The slice was a DOT-FILE (.scroll-slice-01.png, since 6.87.0, so the
    -- panel would never list a half-done run) inside a folder OneDrive's
    -- File Provider owns, and screencapture would not write it there —
    -- while every plain-named capture into the same folder lands fine
    -- (LL's ⇪4 at 22:26:17 the same evening). So ⇪5 had never once worked
    -- with the folder in OneDrive. The slices now go to a LOCAL folder no
    -- cloud provider owns, with a plain name (the panel reads shots.dir
    -- only, so the dot bought nothing there). Fallback: the system's
    -- temporary folder; if that fails too the run stops before its first
    -- slice and says so. Flat knob — `settings = { screenshots =
    -- { sliceDir = "…" } }` moves it.
    shots.sliceDir  = (core.homeDir or os.getenv("HOME") or "")
                      .. "/Library/Application Support/Hammerspoon/scroll-slices"
    shots.sliceHome = nil     -- { dir, how } once a run has asked
    shots.maxList   = 30      -- newest N shown when the box is EMPTY. Not a
                              -- search limit — see shots.searchMax
    -- 🔎 6.122.0 — the search half. searchMax is a DRAWING limit, not a
    -- matching one: every file in the folder is compared, and this many
    -- of the best are given thumbnails. Raise it and the panel gets
    -- slower, because a thumbnail decodes a whole PNG.
    shots.searchMax  = 60
    shots.findDelay  = 0.25   -- quiet time before mdfind is spawned
    shots.findTimeout = 6.0   -- and how long it is given to answer
    shots.MDFIND     = "/usr/bin/mdfind"
    shots.historyRows = 8     -- history rows VISIBLE below the action rows
    shots.thumbH    = 72      -- thumbnail height in panel rows, pixels
    shots.alertSecs = 2.0
    -- 📐 6.260.0 — THE LIVE SIZE READOUT (LL: "show a live 1280 × 720 in
    -- white on a 90 %-opaque black box", read together with his earlier
    -- "Change the pixel measurement tool numbers to solid white in a
    -- black box that is 10% translucent" — one ask written twice, and
    -- "90 %-opaque" and "10% translucent" are the SAME number: 0.9).
    --
    -- 🚨 IT IS A BUILD, NOT A RESTYLE, and only reading said so. There is
    -- no pixel readout anywhere in this config: the numbers he has been
    -- looking at are macOS's OWN `screencapture -i` HUD, which
    -- Hammerspoon can neither restyle, move nor read. Our selector —
    -- shots.selectArea, the one ⇪5, the editor's ⌘A and "repeat area"
    -- drag on — has drawn a dashed band and NOTHING ELSE since it was
    -- written. So the thing to change did not exist; it had to be made,
    -- on the one selection surface this config owns.
    --
    -- 📏 NAMED, NOT FIXED: ⇪4 is still `screencapture -i`, so it keeps
    -- macOS's HUD and gets no readout of ours. Routing ⇪4 through our
    -- selector would give it one and would cost the native magnifier and
    -- SPACE-to-capture-a-window, which he never asked to pay — his call,
    -- and its own release.
    -- 📐 6.264.0 — ⇪4 DRAGS ON OUR SELECTOR, so the live size readout
    -- appears on the key he actually presses. LL, on 6.260.0: "The
    -- screenshot crosshairs, yes I get it that's Mac, but I wanted a
    -- visual that shows the pixels measurements better." 6.260.0 named
    -- this as his call and its own release; this is him making it.
    -- true here goes back to `screencapture -i` and macOS's own HUD.
    --
    -- 🚪 6.337.0 — AND IT IS TRUE AGAIN, ON HIS EVIDENCE AND NOT ON TASTE
    -- (LL: "I just don't get why OCR hyper+shift+4 works and hyper+4
    -- still does not"). Both keys ask shots.ensureDir() first and both
    -- land a file in the same folder, so the folder is not the
    -- difference. The difference is the whole of it: ⇪⇧4 hands the drag
    -- to `screencapture -i`, a SEPARATE PROCESS whose event grab belongs
    -- to the window server, and ⇪4 since 6.264.0 performs the drag ITSELF
    -- in an hs.canvas mouseCallback. macOS reads a three-finger trackpad
    -- drag as a Space swipe and a Space transition is exactly when it
    -- stops delivering events to us — so the same hand motion that works
    -- on ⇪⇧4 cannot work on ours. No fix inside the selector can reach
    -- that, because the gesture is taken from us before the selector is
    -- asked.
    -- 🔑 6.266.0's RULE, AND THIS IS THE CONDITION IT NAMES: ⇪4 on our
    -- selector has now cost SIX releases — 6.264.0 built it, 6.265.0 made
    -- its fallback reachable, 6.274.0 counted its refusals, 6.282.0
    -- stopped its report throwing, 6.318.0 drew the crosshairs macOS had
    -- been drawing for free, 6.336.0 added a drag-end watch — and every
    -- one of those changed something INSIDE the same pipeline. When a
    -- thing fails that many times and every fix so far moved a part of
    -- it, THE PIPELINE IS THE VARIABLE: stop refining it and route
    -- around it. ⇪4 is the code path that demonstrably works on his Mac,
    -- which is the one ⇪⇧4 uses.
    -- 📏 COST, NAMED, AND IT IS THE THING HE ASKED FOR TWICE: ⇪4 has no
    -- live W × H and no crosshair of ours — it has macOS's HUD, which
    -- carries its own numbers, plus the native magnifier and SPACE to
    -- shoot a window, both of which 6.264.0 took away. "Repeat area"
    -- (⌘5) also loses its rectangle after a ⇪4, because -i cannot report
    -- where you dragged. Our selector is NOT deleted and is not even
    -- switched off: ⇪5, the editor's ⌘A and repeat-area still drag on it,
    -- readout and crosshairs and all. One line puts ⇪4 back on it:
    -- `settings = { screenshots = { areaNative = false } }`.
    shots.areaNative   = true
    -- What this module SHIPS, so areaPlan can tell "the default" from
    -- "he overrode it" without either of them having to be retyped
    -- (6.276.0: read the truth, never keep a second copy by hand).
    shots.areaNativeDefault = true
    -- 🔎 6.274.0 — "INTERMITTENTLY WORKING" IS A COUNT, NOT A SAMPLE.
    -- `shots.areaLast` records the LAST press, which can never answer a
    -- question about a key that works most of the time (6.229.0: when a
    -- cost is paid per event, count the events). These count the routes
    -- ⇪4 actually took, and `refused` is the one that matters — his own
    -- settings line and a Mac that could not draw our selector both end
    -- in "native", and they are opposite facts.
    shots.areaRuns = { ours = 0, native = 0, refused = 0 }
    shots.dirFails = 0
    -- 🚪 6.336.0 — A DRAG ENDS WHEREVER THE BUTTON COMES UP, and this
    -- selector had exactly ONE exit: a mouseUp delivered INSIDE its own
    -- canvas. A canvas mouseCallback hears nothing that happens off its
    -- own frame, so a release on another display, past a screen edge, or
    -- during a Space switch (macOS reads a three-finger drag as a swipe,
    -- and a Space transition is exactly when it switches event delivery
    -- out from under us — 6.306.0) never arrived: the band stayed at the
    -- size of the last event it saw, the selection never fired, and the
    -- overlay stayed on screen until Esc. LL: ⇪4 "did show crosshairs,
    -- on releasing it said 0x0 pixels, and then jumped a few desktops,
    -- and then I had to hit escape to get it in." All three sentences
    -- are that one missing exit, in order.
    -- 🔁 THIRD CALLER OF A RULE THIS CONFIG HAS WRITTEN TWICE — 6.222.0
    -- for the editor's page, 6.306.0 for the panel drag engine, and
    -- nobody asked the selector (6.305.0: a rule written about one
    -- caller is not a rule until every caller has been asked).
    shots.selPollSecs = 0.2
    shots.selEnds     = { mouseUp = 0, belt = 0, tiny = 0, noBelt = 0, noSignal = 0 }
    shots.selLastEnd  = nil   -- { how, w, h, at } — the report's evidence
    -- 📐 6.318.0 — the crosshair ⇪⇧4 has had all along (it is macOS's,
    -- on `screencapture -i`) and ⇪4 lost in 6.264.0 when it moved onto
    -- our own selector. Its own switch, independent of the readout:
    -- they are two different things he can want apart.
    shots.crosshair    = true
    shots.crossThick   = 1       -- points; a hairline, like macOS's
    shots.crossAlpha   = 0.55
    shots.crossLast    = nil     -- { x, y, at } — the report's evidence
    shots.sizeReadout  = true    -- the live W × H while you drag
    shots.sizeAlpha    = 0.9     -- the black box: "90 %-opaque" == "10% translucent"
    shots.sizeFontSize = 15
    shots.sizePad      = 7       -- points of black around the digits
    shots.sizeGap      = 8       -- points between the band and the box
    shots.sizeCharW    = 0.62    -- a digit's width as a fraction of the size
    shots.sizeLast     = nil     -- { w, h, why, at } — the report's evidence
    shots.sizeFailed   = nil     -- set once if the readout ever threw mid-drag
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
    -- 🏷 6.147.0 — CONTENT NAMES. LL: "Can we apply better naming
    -- conventions to the screenshot files than SCR- so the OCR text is
    -- applied and searchable?" Two halves:
    --   · every ⇪4-family capture is OCR'd in the background and its
    --     name gains the shot's own words a few seconds later:
    --     "Screenshot 2026-09-01 at 04.48.37 — worked and verified.png"
    --   · ⌘9 in the panel sweeps the backlog: SCR-YYYYMMDD-xxxx files
    --     (another capture tool's naming) are folded into this module's
    --     convention, word-less "Screenshot …" files gain theirs.
    -- A name that already carries " — " is finished and never touched;
    -- so is any name a person chose (neither SCR- nor "Screenshot …").
    shots.nameByContent = true   -- rename own captures automatically
    shots.slugWords     = 7      -- at most this many words in the name
    shots.slugChars     = 48     -- and at most this many characters
    shots.sweepCap      = 40     -- files OCR'd per ⌘9 sweep, one at a time
    -- 👀 6.155.0 — ARRIVALS FROM OTHER TOOLS ARE NAMED TOO. LL, looking at
    -- the panel: "some of the screenshots have OCR'd thumbnails and others
    -- don't have words in the title … Is there a better way we can put
    -- words in the title along with the other information?" The word-less
    -- rows were not ours: SCR-20260902-rkdn.png is another capture tool's
    -- name, and nothing named those until ⌘9 was pressed. The folder is
    -- WATCHED now: every mechanical, word-less arrival — an SCR- file, or
    -- a "Screenshot …" from the other Mac via OneDrive — is queued for the
    -- same OCR a ⇪4 capture gets, once it has sat still for watchSettle.
    -- One shortcuts process at a time, as ⌘9 does; beyond watchCap they
    -- wait for ⌘9 rather than piling up behind a OneDrive re-sync.
    shots.watchFolder = true
    shots.watchSettle = 2.5      -- seconds a new file must be still before OCR
    shots.watchCap    = 20       -- arrivals queued at once; the rest wait for ⌘9
    -- 🔁 6.281.0 — AND A FILE THAT OCR'd TO NOTHING IS NOT OFFERED AGAIN.
    -- wantsName() only stops matching once a name holds " — ", and a name is
    -- only written when OCR returns words — so a word-less image re-qualified
    -- on EVERY folder event, for ever, one `shortcuts` process each time.
    -- (LL: "those green icons just do something like loop and loop and loop
    -- like it's running OCR nonstop." The green pills ARE those processes.)
    shots.triedMax  = 3      -- OCRs of one file before the watcher stops offering it
    shots.triedKeep = 400    -- files remembered; the oldest is forgotten first
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
        if mode == "directory" then
            shots.startWatch()      -- idempotent; a folder that exists is watched
            return shots.dir
        end
        local made = false
        pcall(function() made = hs.fs.mkdir(shots.dir) end)
        if made then
            say("created " .. shots.dir)
            shots.startWatch()
            return shots.dir
        end
        -- mkdir cannot create parents; if OneDrive-Personal itself is
        -- missing (not signed in, different account name) say WHERE it
        -- looked rather than failing into the Console.
        -- 🔔 6.274.0 — AND IT TAKES THE DOOR. An alert was the whole of
        -- what this said, and an alert is exactly what macOS was refusing
        -- on LL's Mac (three in eight hours). The degrade door alerts AND
        -- prints AND lands in `_G.degradeReport()`, so a ⇪4 that did
        -- nothing leaves a record even when the message never drew.
        shots.dirFails = (shots.dirFails or 0) + 1
        shots.dirFailWhy = "the screenshots folder is not there: " .. shots.dir
        if type(core.degrade) == "function" then
            pcall(core.degrade, "Screenshots folder", shots.dirFailWhy)
        else
            pcall(function()
                hs.alert.show("📸 Screenshots folder unavailable:\n" .. shots.dir, 4)
            end)
        end
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

    -- 👀 6.155.0 — every path THIS module writes is registered, so the
    -- folder watcher can tell its own captures (finish() names those, or
    -- the editor holds them) from another tool's arrivals.
    shots.own = {}
    local function freshPath()
        local base = shots.dir .. "/" .. shots.filenameAt()
        local exists
        pcall(function() exists = hs.fs.attributes(base, "size") end)
        if not exists then shots.own[base] = true ; return base end
        -- two captures inside one second — number the second one rather
        -- than letting screencapture overwrite the first
        for n = 2, 99 do
            local p = base:gsub("%.png$", (" (%d).png"):format(n))
            local e
            pcall(function() e = hs.fs.attributes(p, "size") end)
            if not e then shots.own[p] = true ; return p end
        end
        shots.own[base] = true
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
        shots.copyToPasteboard(path, function(copied) shots.afterCopy(path, thenEdit, copied) end)
        return true
    end

    function shots.afterCopy(path, thenEdit, copied)
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
        -- 🏷 6.147.0 — the name gains the shot's own words, a few
        -- seconds behind the capture. NOT when the blur editor is about
        -- to open on this exact path: a rename under the editor would
        -- orphan its save. (The clipboard holds pixels, not the path,
        -- so the rename never breaks a paste.)
        if shots.nameByContent and not thenEdit then
            shots.nameByText(path)
        end
        return true
    end
    core.provide("screenshots.copyToPasteboard", function(p, cb)
        return shots.copyToPasteboard(p, cb or function() end)
    end)

    -- One task-runner for every screencapture variant: same holding
    -- pattern, same failure alerts, different argument lists.
    function shots.runCapture(args, path, thenEdit, onDone)
        local t
        local ok = pcall(function()
            t = hs.task.new("/usr/sbin/screencapture", function(exitCode, sout, serr)
                -- 🚨 6.206.0 — the finished task stays REFERENCED until the
                -- next capture replaces it. Dropping the last reference to
                -- a task from inside its own callback is 6.196.1's
                -- use-after-free, and the scrolling run allocates heavily
                -- (twelve decodes, a canvas) inside this very callback.
                shots.lastCaptureTask = t
                shots.captureTask = nil    -- release only when done
                shots.lastExit = { code = exitCode, err = tostring(serr or "") }
                if onDone then
                    onDone(path, exitCode, serr)
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
        -- 🚨 6.170.3 — `screencapture -i` TAKES THE KEYBOARD. LL's Console
        -- after ⇪4: "⇪ released by the watchdog — held 29s with no key
        -- event and no F18 keyUp". The crosshair grabs every event, the
        -- Caps Lock keyUp never reaches Hammerspoon, and until the
        -- watchdog lets go every key LL types runs a hyper shortcut —
        -- the "dead keyboard". Same cure as the scratch pad (6.165.1):
        -- nobody holds ⇪ through a crosshair, so the deadline drops to
        -- 1.5 s of silence. Only the DEADLINE changes, never the way in.
        if args[1] == "-i" then shots.expectHyperRelease() end
        return true
    end

    function shots.expectHyperRelease()
        if _G.hyperExpectRelease then
            pcall(_G.hyperExpectRelease, 1.5, "the screenshot tool")
        end
    end

    -- 🚨 6.170.3 — THE CLIPBOARD COPY LEAVES THE MAIN THREAD. Until now
    -- finish() decoded the whole screenshot (a 5120×2880 PNG on the 4K)
    -- with hs.image.imageFromPath and pushed the pixels through
    -- hs.pasteboard.writeObjects — a second full encode — on the main
    -- thread, and the clipboard poll then decoded the pasteboard AGAIN
    -- half a second later. Three passes over 15 million pixels while
    -- ⇪ was latched (see runCapture) is the beach ball LL saw. Now
    -- /usr/bin/osascript reads the PNG straight onto the pasteboard in
    -- an hs.task (HELD), and the poll is asked to sit out the change
    -- (`_G.pasteboardSuppressUntil`): the file's OCR already runs from
    -- the file. writeObjects stays only as the fallback when no task
    -- can be made.
    function shots.copyToPasteboard(path, done)
        -- 📋 6.319.0 — RECORD WHAT WE PUT THERE. A shot's own words may
        -- later replace it on the clipboard, and the ONLY thing that
        -- entitles them to is this: we put this very file there, the
        -- counter has not moved since, and it was seconds ago.
        local function finish(ok)
            if ok then
                local c, n
                pcall(function() c = hs.pasteboard.changeCount() end)
                pcall(function() n = hs.timer.secondsSinceEpoch() end)
                shots.ownClip = { path = path, at = n or os.time(),
                                  count = (type(c) == "number") and c or nil }
            end
            done(ok)
        end
        local script = ('set the clipboard to (read (POSIX file "%s") as «class PNGf»)')
                       :format(path:gsub('"', '\\"'))
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/osascript", function(exitCode)
                shots.copyTask = nil
                local now = 0
                pcall(function() now = hs.timer.secondsSinceEpoch() end)
                _G.pasteboardSuppressUntil = now + 1
                finish(exitCode == 0)
            end, { "-e", script })
        end)
        local started = false
        if okNew and t then
            shots.copyTask = t   -- HELD
            pcall(function() started = t:start() end)
        end
        if started then
            local now = 0
            pcall(function() now = hs.timer.secondsSinceEpoch() end)
            _G.pasteboardSuppressUntil = now + shots.copySuppressSecs
            return true
        end
        shots.copyTask = nil
        local copied = false
        pcall(function()
            local img = hs.image.imageFromPath(path)
            if img then copied = hs.pasteboard.writeObjects(img) and true end
        end)
        finish(copied)
        return false
    end

    -- ⇪4, and the "📐 Capture area" row of the ⇪⇧5 panel — ONE function,
    -- two callers, so the key and its panel row cannot come to mean
    -- different things (6.194.0's rule about shots.toolKeys, here in the
    -- one action that pre-dates it).
    function shots.capture(thenEdit)
        if not shots.ensureDir() then return end
        local started, why
        if not shots.areaNative then
            -- 🚨 READ THREE VALUES (6.179.0). selectArea answers
            -- false, why since 6.264.0, and reading two would make a
            -- refusal look like a successful start — ⇪4 would then do
            -- nothing at all, which is the one outcome worse than
            -- keeping macOS's HUD.
            local ok, a, b = pcall(shots.selectArea, function(rect)
                shots.captureRect(rect, thenEdit, true)
            end)
            if ok then started, why = a, b
            else started, why = false, "the selector threw: " .. tostring(a) end
        end
        local how, note = shots.areaPlan(shots.areaNative, started, why,
                                         shots.areaNative ~= shots.areaNativeDefault)
        local at = 0
        pcall(function() at = hs.timer.secondsSinceEpoch() end)
        shots.areaLast = { how = how, why = note, at = at }
        shots.areaRuns[how] = (shots.areaRuns[how] or 0) + 1
        -- 🔔 A DEGRADE IS SEEN, NEVER ONLY LOGGED (6.215.0) — but only
        -- when it IS one: his own settings line choosing the native
        -- crosshair is a decision, not a fault, so it never alerts.
        if how == "native" and not shots.areaNative then
            shots.areaRuns.refused = shots.areaRuns.refused + 1
            if type(core.degrade) == "function" then
                pcall(core.degrade, "Screenshot area selector", note)
            end
        end
        if how == "ours" then return true end
        local path = freshPath()
        shots.runCapture({ "-i", path }, path, thenEdit)
        return true
    end

    -- Panel action 5 — the exact same rectangle again. The rect comes
    -- from our own selector (native -i cannot report where you dragged),
    -- is remembered for the session, and -R re-shoots it on demand.
    -- `withSound` is 6.264.0 and it exists to keep a SWAP faithful rather
    -- than to add anything: this path has always passed -x (silent),
    -- which is right for "repeat that rectangle" and wrong for ⇪4, where
    -- the shutter has been the confirmation since the day it was bound.
    -- Swapping one crosshair for another must not quietly also remove a
    -- sound. Existing callers pass nothing and are unchanged.
    function shots.captureRect(rect, thenEdit, withSound)
        if not shots.ensureDir() then return end
        local path = freshPath()
        shots.lastRect = rect
        local args = {}
        if not withSound then args[#args + 1] = "-x" end
        args[#args + 1] = ("-R%d,%d,%d,%d"):format(rect.x, rect.y, rect.w, rect.h)
        args[#args + 1] = path
        shots.runCapture(args, path, thenEdit)
    end

    -- 📐 6.264.0 — WHICH CROSSHAIR, PURE, and it answers WHY as well as
    -- which, because ⇪4 looking unchanged has three different causes and
    -- a report that cannot tell them apart is the 6.196.1 failure again:
    -- he asked for it (his settings line) · this Mac could not draw ours
    -- (a real degrade) · it is ours and working. Three branches, three
    -- mutations. `started` is only ever consulted when we actually tried.
    -- 🚪 6.337.0 — A FOURTH ANSWER, because the default moved. Until now
    -- "native" could only mean his own settings line, so that is what the
    -- sentence said. It is the SHIPPED behaviour now, and a report that
    -- tells him he asked for something he did not is worse than one that
    -- says nothing (6.196.1 — and 6.274.0 counts these apart on purpose).
    -- `asked` is the caller's answer to "did an override put us here",
    -- never a second copy of the default.
    function shots.areaPlan(native, started, why, asked)
        if native then
            if asked then
                return "native", "macOS's own crosshair and HUD — your settings line "
                       .. "asked for it (screenshots = { areaNative = true })"
            end
            return "native", "macOS's own crosshair and HUD — the shipped default since "
                   .. "6.337.0, because this is the drag ⇪⇧4 uses and it works "
                   .. "(screenshots = { areaNative = false } puts our selector back)"
        end
        if started == false then
            return "native", "our selector could not start ("
                   .. tostring(why or "no reason given")
                   .. ") — macOS's crosshair instead, so ⇪4 still captures"
        end
        return "ours", "our selector, with the live size readout"
    end

    -- 📏 6.255.0 — THE VERDICT ON A CAPTURE, PURE: exit code, file size and
    -- screencapture's own first line in, ok/why out. It exists because
    -- there are TWO callers now (the editor's area grab and its full-screen
    -- grab) and a second copy of "was that a real file?" is a second copy
    -- to keep in step — 6.187.0's two-readers rule, paid before it costs
    -- anything. A zero-byte file with exit 0 is a FAILURE: screencapture
    -- has written one (6.213.3 found it doing exactly that in a cloud
    -- folder), and a caller handed that path opens an empty image.
    function shots.captureVerdict(exitCode, size, serr)
        exitCode = tonumber(exitCode)
        size     = tonumber(size) or 0
        if exitCode == 0 and size > 0 then return true end
        local why = "screencapture exit " .. tostring(exitCode)
        local first = tostring(serr or ""):match("[^\n]+")
        if first and first ~= "" then why = why .. " — " .. first end
        if size <= 0 then why = why .. " — no file was written" end
        return false, why
    end

    -- 🖥 6.255.0 — the editor's DELAYED grab (⌘D), and the same door the
    -- full-screen grab uses: a whole-screen `screencapture -x [-T N]`
    -- whose PATH is handed to the caller. No clipboard, no editor opened,
    -- no panel — captureAreaTo's contract exactly, minus the selector.
    -- cb(path) on success, cb(nil, why) on anything else, and NEVER both.
    -- The countdown is screencapture's own -T, so nothing of ours holds
    -- the main thread while the Mac is being arranged.
    function shots.captureScreenTo(delay, cb)
        if type(cb) ~= "function" then return false, "no callback" end
        if not shots.ensureDir() then cb(nil, "no screenshots folder") return false end
        -- 🗑 6.255.0 — a `if delay < 0 then delay = 0 end` guard was written
        -- here and taken out again: the only reader is `delay > 0`, so a
        -- negative number already means "no -T, shoot now" and no mutation
        -- could fail. A guard no test can fail is dead code with a comment
        -- on it (6.199.0) — THIRD time this project has made that call.
        delay = math.floor(tonumber(delay) or 0)
        local path = freshPath()
        local args = { "-x" }
        if delay > 0 then
            args[#args + 1] = "-T"
            args[#args + 1] = tostring(delay)
        end
        args[#args + 1] = path
        local started = shots.runCapture(args, path, false, function(p, exitCode, serr)
            local size
            pcall(function() size = hs.fs.attributes(p, "size") end)
            local ok, why = shots.captureVerdict(exitCode, size, serr)
            if ok then cb(p) else cb(nil, why) end
        end)
        if not started then cb(nil, "screencapture could not be started") return false end
        return true
    end

    -- 🖌 6.213.0 — the editor's "Add capture" (⌘A): OUR selector, a -x -R
    -- shot of that rectangle, and the PATH handed to the caller — no
    -- clipboard, no editor open, no panel. cb(path) on success, cb(nil,
    -- why) on anything else, and never both.
    function shots.captureAreaTo(cb)
        if type(cb) ~= "function" then return false, "no callback" end
        if not shots.ensureDir() then cb(nil, "no screenshots folder") return false end
        local picked = false
        shots.selectArea(function(rect)
            picked = true
            local path = freshPath()
            shots.lastRect = rect
            local started = shots.runCapture({
                "-x",
                ("-R%d,%d,%d,%d"):format(rect.x, rect.y, rect.w, rect.h),
                path,
            }, path, false, function(p, exitCode, serr)
                local size
                pcall(function() size = hs.fs.attributes(p, "size") end)
                -- 6.255.0 — one verdict, two callers (see captureVerdict)
                local ok, why = shots.captureVerdict(exitCode, size, serr)
                if ok then cb(p) else cb(nil, why) end
            end)
            if not started then cb(nil, "screencapture could not be started") end
        end)
        return true
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
        if shots.selPoll then
            pcall(function() shots.selPoll:stop() end)
            -- 🪜 HELD ONE MORE TURN, never dropped from inside its own
            -- callback. The belt below ends a drag from the timer's own
            -- tick, and nilling the only reference to a timer whose
            -- callback is RUNNING is 6.196.1's use-after-free wearing
            -- hs.timer's hat (6.198.0 found exactly that in power_tools).
            -- One slot, released by the next selector.
            shots.selPollLast, shots.selPoll = shots.selPoll, nil
        end
        if shots.selTap then
            pcall(function() shots.selTap:stop() end)
            shots.selTap = nil
        end
        if shots.selCanvas then
            pcall(function() shots.selCanvas:delete() end)
            shots.selCanvas = nil
        end
    end

    -- 🕒 PURE — a stored timestamp as HH:MM:SS, and the whole point
    -- is that it FLOORS. `hs.timer.secondsSinceEpoch()` answers
    -- 1758769234.8231, and Lua's os.date REFUSES a float outright:
    -- "bad argument #2 to 'date' (number has no integer representation)".
    -- So a report line built from one does not print something wrong, it
    -- THROWS — and takes the entire report down with it (6.282.0: LL's
    -- `_G.screenshotsReport()` died at the `area` line, which is every
    -- session in which he had pressed ⇪4 even once).
    -- 🔑 ONE DOOR FOR EVERY STORED CLOCK IN THIS REPORT. Three lines read
    -- an `at` field — size, area and scroll — and only ONE of them was fed
    -- a float; the other two are integers by luck, because their writers
    -- happen to call os.time(). Flooring the one writer would fix the
    -- instance and leave the class, so the READER is where this lives.
    -- It answers a sentence and never raises: a report that dies while
    -- describing itself is worse than any line it could have printed.
    function shots.clockText(at)
        local n = tonumber(at)
        -- 0 is what the writer leaves when the clock could not be read
        -- (`local at = 0` before a pcall'd assignment), so it is "not
        -- recorded" rather than 1970.
        if not n or n <= 0 then return "time not recorded" end
        local ok, s = pcall(os.date, "%H:%M:%S", math.floor(n))
        if not ok or type(s) ~= "string" then return "time not recorded" end
        return s
    end

    -- ✏️ PURE — the string, exactly as LL wrote it: "1280 × 720", with a
    -- MULTIPLICATION SIGN (U+00D7) and not an x. Both numbers are
    -- floored: a drag is measured in points and a fractional pixel is a
    -- number nobody can act on.
    function shots.sizeText(w, h)
        local function whole(v)
            v = math.floor(tonumber(v) or 0)
            if v < 0 then v = 0 end
            return v
        end
        return ("%d × %d"):format(whole(w), whole(h))
    end

    -- ✏️ PURE — the black box around the digits. COUNTED IN CHARACTERS,
    -- never bytes: "×" is two bytes and one character, so `#` would make
    -- every box a glyph too wide and the digits would sit off centre.
    -- 6.226.0's rule (utf8.len, never #), in a new place.
    function shots.sizeBox(text, fontSize, pad, charW)
        fontSize = tonumber(fontSize) or 15
        pad      = tonumber(pad) or 7
        charW    = tonumber(charW) or 0.62
        local chars = 0
        if type(text) == "string" then
            local ok, n = pcall(function() return utf8.len(text) end)
            chars = (ok and n) or #text
        end
        return math.floor(chars * fontSize * charW + pad * 2 + 0.5),
               math.floor(fontSize + pad * 2 + 0.5)
    end

    -- ✏️ PURE — WHERE the box goes, and WHY. Centred under the band is
    -- the eye's place for it: the numbers describe the thing above them.
    -- THREE ANSWERS, in order, because a readout you cannot see is the
    -- bug this release exists to avoid:
    --   · below the selection — the ordinary case;
    --   · ABOVE it, when the band is against the bottom of the screen;
    --   · INSIDE it, at its own bottom edge, when neither side has room
    --     (a drag as tall as the display, which is not a rare drag).
    -- The x is clamped into the screen, and a clamp is SAID: a box that
    -- has been moved sideways is no longer describing the band's centre,
    -- and "it looks off" must have an answer in the report.
    function shots.sizePlan(band, screen, boxW, boxH, gap)
        band, screen = band or {}, screen or {}
        local bx, by = tonumber(band.x) or 0, tonumber(band.y) or 0
        local bw, bh = tonumber(band.w) or 0, tonumber(band.h) or 0
        local sw, sh = tonumber(screen.w) or 0, tonumber(screen.h) or 0
        boxW, boxH = tonumber(boxW) or 0, tonumber(boxH) or 0
        gap = tonumber(gap) or 0

        local why = "below the selection"
        local y = by + bh + gap
        if y + boxH > sh then
            y = by - gap - boxH
            why = "above it — no room below"
            if y < 0 then
                y = by + bh - gap - boxH
                why = "inside it — no room either side"
            end
        end
        if y < 0 then y = 0 end
        if y + boxH > sh then y = math.max(0, sh - boxH) end

        local want = bx + (bw - boxW) / 2
        local x = want
        if x < 0 then x = 0 end
        if x + boxW > sw then x = math.max(0, sw - boxW) end
        if math.abs(x - want) > 0.5 then why = why .. " · nudged into the screen" end

        return { x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                 w = boxW, h = boxH }, why
    end

    -- =====================================================================
    -- 📐 6.318.0 — ⇪4 HAS CROSSHAIRS, AND THE NUMBERS ARE THERE BEFORE
    --              YOU PRESS ANYTHING
    -- =====================================================================
    -- LL: "The hyper+shift+4 has pixel crosshairs, hyper+4 does not, so
    -- that is an easy fix and something I've asked for numerous times.
    -- Along with that it was working before. This is what I am talking
    -- about: don't break as we build."
    --
    -- 🔎 AND HE IS RIGHT TWICE OVER. ⇪⇧4 is `screencapture -i` and keeps
    -- macOS's own HUD — full-screen crosshairs with live coordinates,
    -- drawn the instant the key is pressed. ⇪4 was that too until
    -- 6.264.0 moved it onto OUR selector, which until this release drew
    -- a dim wash and NOTHING ELSE until the button went down: no
    -- crosshair ever, and no numbers until a drag had started. So the
    -- two keys really did differ, the difference really did arrive with
    -- a release of mine, and "it was working before" is the plain truth.
    --
    -- 📏 THE CHOICE 6.264.0 MADE IS NOT REVERSED, because reversing it
    -- costs him the live W × H he asked for twice. What was missing is
    -- the half macOS was giving him for free, and it is ours to draw:
    -- the crosshair follows the pointer from the moment the selector
    -- arms, and the box shows the POINTER'S POSITION until there is a
    -- rectangle to measure. 6.238.0's rule in a new place — a number
    -- that appears late is a number you do not trust.

    -- PURE: the two lines of the crosshair, as frames on the selector's
    -- own canvas. Clamped into the screen, because a pointer parked on
    -- the last pixel would otherwise draw a line half outside it.
    function shots.crossPlan(x, y, screen, thick)
        screen = screen or {}
        local sw, sh = tonumber(screen.w) or 0, tonumber(screen.h) or 0
        local t = tonumber(thick) or 1
        if t < 1 then t = 1 end
        x = math.max(0, math.min(tonumber(x) or 0, sw))
        y = math.max(0, math.min(tonumber(y) or 0, sh))
        local function band(a, span) return math.max(0, math.min(a - t / 2, span - t)) end
        return { x = math.floor(band(x, sw) + 0.5), y = 0, w = t, h = sh },
               { x = 0, y = math.floor(band(y, sh) + 0.5), w = sw, h = t }
    end

    -- PURE: what the box says BEFORE a drag — where the pointer is, in
    -- the screen's own pixels, which is what macOS's HUD shows. Floored,
    -- for the same reason sizeText floors: a fractional pixel is not
    -- something you can act on.
    function shots.pointText(x, y)
        return string.format("%d, %d", math.floor(tonumber(x) or 0),
                                       math.floor(tonumber(y) or 0))
    end

    -- The crosshair's own draw. MOVED and never rebuilt — this runs per
    -- mouse event and 6.247.0 priced a rebuild on a path like that.
    -- 🚨 THE INDICES ARE RECORDED, NEVER ASSUMED, and the mutation
    -- sweep is what said so. The first version hard-coded elements 5
    -- and 6 — right only while the READOUT's two elements sit at 3 and
    -- 4. With `sizeReadout = false` they are not appended at all, the
    -- crosshair lands at 3 and 4, and writing to 5 threw into the
    -- guard: the crosshair was SILENTLY DEAD for anyone who had turned
    -- the numbers off. One switch's state deciding where another
    -- switch's elements live is exactly the coupling a literal index
    -- hides. `shots.crossIdx` is set where they are appended; the 5/6
    -- default is only for a caller driving this function directly.
    function shots.drawCross(canvas, x, y, sf, idx)
        idx = idx or shots.crossIdx or { 5, 6 }
        local v, h = shots.crossPlan(x, y, { w = sf.w, h = sf.h }, shots.crossThick)
        canvas[idx[1]].frame = v
        canvas[idx[2]].frame = h
        shots.crossLast = { x = math.floor(tonumber(x) or 0),
                            y = math.floor(tonumber(y) or 0), at = os.time() }
    end

    -- The box, showing a POSITION rather than a size. It goes through
    -- sizeBox and sizePlan exactly as the size does — one placement
    -- rule, so the box cannot sit in one place before a drag and
    -- another during it (6.231.0: one function, two callers).
    function shots.drawPoint(canvas, x, y, sf)
        local text = shots.pointText(x, y)
        local boxW, boxH = shots.sizeBox(text, shots.sizeFontSize,
                                         shots.sizePad, shots.sizeCharW)
        local frame = shots.sizePlan({ x = x, y = y, w = 0, h = 0 },
                                     { w = sf.w, h = sf.h }, boxW, boxH, shots.sizeGap)
        canvas[3].frame = frame
        canvas[4].frame = { x = frame.x, y = frame.y + shots.sizePad - 2,
                            w = frame.w, h = shots.sizeFontSize + 6 }
        canvas[4].text  = text
    end

    -- The ONE place the readout is written to the canvas. Element 3 is
    -- the box, element 4 the digits, and both are MOVED — never deleted
    -- and rebuilt. This runs per mouse event and 6.247.0 priced a
    -- rebuild on a path like that: two NSWindows per keystroke was a
    -- cadence LL could feel.
    function shots.drawSize(canvas, band, sf)
        local text = shots.sizeText(band.w, band.h)
        local boxW, boxH = shots.sizeBox(text, shots.sizeFontSize,
                                         shots.sizePad, shots.sizeCharW)
        local frame, why = shots.sizePlan(band, { w = sf.w, h = sf.h },
                                          boxW, boxH, shots.sizeGap)
        canvas[3].frame = frame
        -- the text's own frame is inset by the padding, or the glyphs
        -- sit against the top edge of the black
        canvas[4].frame = { x = frame.x, y = frame.y + shots.sizePad - 2,
                            w = frame.w, h = shots.sizeFontSize + 6 }
        canvas[4].text  = text
        shots.sizeLast = { w = math.floor(tonumber(band.w) or 0),
                           h = math.floor(tonumber(band.h) or 0),
                           why = why, at = os.time() }
    end

    -- 📐 6.264.0 — IT ANSWERS WHETHER IT STARTED. Until now every failure
    -- here was a bare `return`: no canvas, no screen, and the caller was
    -- told nothing while the callback simply never fired. That was
    -- survivable while the only callers were ⇪5 and the editor's ⌘A,
    -- which have nowhere else to go — and it is not survivable now that
    -- ⇪4 routes through here, because ⇪4 has somewhere very good to go
    -- (macOS's own crosshair) and a key that silently captures nothing is
    -- worse than a key that captures without our numbers on it.
    -- true / false, why — read THREE values at the call site (6.179.0).
    -- 🔬 PURE — `hs.eventtap.checkMouseButtons()` IS A VETO, NOT AN
    -- ORACLE, and the direction is load-bearing (6.306.0; window_move
    -- 6.156.0 paid for trusting it the other way). It is believed only
    -- when it positively says a button is STILL DOWN. An empty table,
    -- a nil, a Mac that cannot answer — all read as "the drag is over",
    -- because ending a drag early costs one selection he can take
    -- again, and not ending it costs an overlay he can only clear with
    -- Esc, which is the bug being fixed.
    function shots.dragStillHeld(buttons)
        if type(buttons) ~= "table" then
            return false, "this Mac would not say which buttons are down"
        end
        for _, down in pairs(buttons) do
            if down == true then return true, "a button is still down" end
        end
        return false, "no button is down"
    end

    -- 🚨 6.337.0 — AND THE BELT ASKED IT IN THE FORBIDDEN DIRECTION.
    -- 6.336.0 quoted 6.306.0's sentence into its own release notes —
    -- "checkMouseButtons IS A VETO, NOT AN ORACLE … believed only when it
    -- positively says STILL DOWN" — and then built a 0.2 s timer whose
    -- SOLE trigger is the negative answer. In core/coexist.lua the veto
    -- is consulted only AFTER a mouseMoved event has independently proved
    -- the button is up (macOS sends leftMouseDragged while it is held);
    -- there the negative confirms a fact we already have. Here nothing
    -- else was asked, so "it would not say" and "it came up" were acted
    -- on identically.
    -- 🔎 WHAT THAT COSTS, and it is the reason ⇪4 got WORSE rather than
    -- better: a three-finger trackpad drag presses no physical button, so
    -- `pressedMouseButtons` can report nothing throughout — and the belt
    -- then ended the drag on its FIRST tick, 0.2 s after the press, a few
    -- pixels wide, into finishAt's "📐 Nothing captured — that drag
    -- measured 3 × 2". 6.335.0 at least drew a band.
    -- 🔑 THE RULE, IMPLEMENTED THIS TIME: an instrument that has never
    -- once said "down" during this drag is UNINFORMATIVE, not negative.
    -- Three answers (6.196.1): held · ended · stand down, and only the
    -- second may touch the selection. PURE, so the gate proves all three
    -- with no Mac and no trackpad.
    function shots.beltVerdict(sawHeld, buttons)
        if shots.dragStillHeld(buttons) then
            return "held", "a button is still down"
        end
        if not sawHeld then
            return "standDown", "this Mac has not once reported a held button during "
                   .. "this drag — the watch cannot tell a release from a drag it "
                   .. "never saw, so it does nothing"
        end
        return "ended", "the button came up somewhere this canvas could not hear"
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
        if not scr then return false, "this Mac named no screen to draw on" end
        local sf
        pcall(function() sf = scr:frame() end)
        if not sf then return false, "the screen would not give its frame" end

        local canvas
        pcall(function() canvas = hs.canvas.new(sf) end)
        if not canvas then return false, "hs.canvas would not make the selector" end
        canvas:appendElements(
            { type = "rectangle", action = "fill",
              fillColor = { black = 1, alpha = 0.18 } },
            { type = "rectangle", action = "stroke",
              strokeColor = { red = 0.29, green = 0.5, blue = 0.88, alpha = 0.95 },
              strokeWidth = 2, strokeDashPattern = { 6, 4 },
              frame = { x = 0, y = 0, w = 0, h = 0 } })
        -- 📐 6.260.0 — the readout rides on the SAME canvas as the band:
        -- a second window would be a second thing to place, level, show
        -- and tear down, and a drag is not a place to own two of
        -- anything. Both elements start at zero size, so a Mac that
        -- never drags sees exactly what it saw before.
        local readout = false
        if shots.sizeReadout then
            local okR = pcall(function()
                canvas:appendElements(
                    { type = "rectangle", action = "fill",
                      fillColor = { black = 1, alpha = shots.sizeAlpha },
                      roundedRectRadii = { xRadius = 5, yRadius = 5 },
                      frame = { x = 0, y = 0, w = 0, h = 0 } },
                    { type = "text", text = "",
                      textColor = { white = 1, alpha = 1 },
                      textSize = shots.sizeFontSize,
                      textAlignment = "center",
                      frame = { x = 0, y = 0, w = 0, h = 0 } })
            end)
            readout = okR and true or false
            if not okR then
                shots.sizeFailed = "this Mac refused the readout elements — "
                                   .. "the selector still works, there is just no live size"
                if type(core.degrade) == "function" then
                    pcall(core.degrade, "Screenshot size readout", shots.sizeFailed)
                end
            end
        end
        -- 📐 6.318.0 — the crosshair, elements 5 and 6. It rides the SAME
        -- canvas as the band and the box, for the reason 6.260.0 gave:
        -- a drag is not a place to own two windows. It is appended last
        -- so drawSize's elements stay at 3 and 4 and nothing above this
        -- line has to move.
        -- 🚨 AND IT NEEDS THE READOUT'S SLOTS. Without them there is
        -- nothing to write a position into, so the crosshair is drawn
        -- and the numbers are simply absent — which is honest, and the
        -- report says which of the two this Mac has.
        local cross = false
        shots.crossIdx = nil
        if shots.crosshair then
            local base = (readout and 4 or 2)
            local okC = pcall(function()
                canvas:appendElements(
                    { type = "rectangle", action = "fill",
                      fillColor = { white = 1, alpha = shots.crossAlpha },
                      frame = { x = 0, y = 0, w = 0, h = 0 } },
                    { type = "rectangle", action = "fill",
                      fillColor = { white = 1, alpha = shots.crossAlpha },
                      frame = { x = 0, y = 0, w = 0, h = 0 } })
            end)
            cross = okC and true or false
            if cross then shots.crossIdx = { base + 1, base + 2 } end
            if not okC then
                shots.crossFailed = "this Mac refused the crosshair elements — "
                                    .. "the selector still works, there are just no crosshairs"
                if type(core.degrade) == "function" then
                    pcall(core.degrade, "Screenshot crosshair", shots.crossFailed)
                end
            end
        end
        pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
        pcall(function()
            canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        pcall(function() canvas:canvasMouseEvents(true, true, false, true) end)
        shots.expectHyperRelease()   -- 6.170.3: the selector takes the keyboard like -i does

        -- 🔒 THE READOUT IS DECORATION ON A LOAD-BEARING DRAG, so it is
        -- guarded APART from the drag it decorates. The mouse callback's
        -- own pcall cancels the whole selection when the body throws
        -- (an error here would otherwise repeat per event) — which is
        -- right for the band and wrong for the numbers: a readout that
        -- throws must cost the readout and never the selection. It goes
        -- quiet for the rest of the drag, takes the 🔔 door once, and
        -- the report says so afterwards.
        -- 📐 6.318.0 — ONE DOOR FOR THE CROSSHAIR TOO, and the sweep is
        -- what said so: the arm-time draw used a bare pcall, so a Mac
        -- where the crosshair throws switched it off SILENTLY before
        -- the first mouse event and the 🔔 door was never taken. A
        -- failure the report cannot see is 6.196.1 inside the feature
        -- built to answer "why has ⇪4 no crosshairs?".
        local function showCross(x, y)
            if pcall(shots.drawCross, canvas, x, y, sf) then return true end
            shots.crossFailed = "the crosshair threw mid-drag — the selection itself is unaffected"
            if type(core.degrade) == "function" then
                pcall(core.degrade, "Screenshot crosshair", shots.crossFailed)
            end
            return false
        end

        local function showPoint(x, y)
            if pcall(shots.drawPoint, canvas, x, y, sf) then return true end
            shots.sizeFailed = "the readout threw mid-drag — the selection itself is unaffected"
            if type(core.degrade) == "function" then
                pcall(core.degrade, "Screenshot size readout", shots.sizeFailed)
            end
            return false
        end

        local function showSize(band)
            local okD = pcall(shots.drawSize, canvas, band, sf)
            if okD then return true end
            shots.sizeFailed = "the readout threw mid-drag — the selection itself is unaffected"
            if type(core.degrade) == "function" then
                pcall(core.degrade, "Screenshot size readout", shots.sizeFailed)
            end
            return false
        end

        local startPt = nil

        -- 🔑 ONE FINISH, TWO CALLERS (6.231.0): the mouseUp the canvas
        -- hears, and the belt below for every release it cannot. Two
        -- copies of this arithmetic is how the two exits come to
        -- disagree about what was selected.
        local function finishAt(mx, my, how)
            if not startPt then return end
            local rect = {
                x = math.floor(sf.x + math.min(startPt.x, mx)),
                y = math.floor(sf.y + math.min(startPt.y, my)),
                w = math.floor(math.abs(mx - startPt.x)),
                h = math.floor(math.abs(my - startPt.y)),
            }
            startPt = nil
            shots.cancelSelect()
            shots.selEnds[how] = (shots.selEnds[how] or 0) + 1
            shots.selLastEnd = { how = how, w = rect.w, h = rect.h, at = os.time() }
            if rect.w >= 8 and rect.h >= 8 then
                cb(rect)
                return
            end
            -- 🚨 AND A DRAG TOO SMALL TO CAPTURE SAYS SO. This exit was a
            -- bare `end`: the selector vanished, nothing was captured and
            -- nothing was said, which is a key that did nothing (6.320.0
            -- — a refusal he cannot act on is a defect even when it is
            -- right). It names the size, because "0 × 0" is the whole
            -- diagnosis when a release went somewhere we could not hear.
            shots.selEnds.tiny = shots.selEnds.tiny + 1
            pcall(function()
                hs.alert.show(("📐 Nothing captured — that drag measured %d × %d. "
                               .. "Press the key again and drag a rectangle.")
                              :format(rect.w, rect.h), 3)
            end)
        end

        pcall(function()
            canvas:mouseCallback(function(_, msg, _, mx, my)
                -- mouseCallback runs per event — same rule as an eventtap:
                -- an error here repeats forever, so the body is guarded
                local ok = pcall(function()
                    -- 📐 6.318.0 — THE CROSSHAIR FOLLOWS WHATEVER THE
                    -- EVENT IS, before a press as much as during a drag.
                    -- That is the whole difference he reported: ⇪⇧4's
                    -- macOS HUD is there the instant the key is pressed
                    -- and ours drew nothing until the button went down.
                    if cross then cross = showCross(mx, my) end
                    if msg == "mouseMove" and not startPt then
                        -- nothing pressed yet: the box shows WHERE the
                        -- pointer is, which is what macOS's HUD shows,
                        -- so the numbers are never late (6.238.0)
                        if readout then readout = showPoint(mx, my) end
                        return
                    end
                    if msg == "mouseDown" then
                        startPt = { x = mx, y = my }
                        -- the readout is live from the press, not from
                        -- the first movement: 0 × 0 is the honest answer
                        -- for a drag that has not started, and a number
                        -- that appears late is a number you do not trust
                        if readout then
                            readout = showSize({ x = mx, y = my, w = 0, h = 0 })
                        end
                    elseif msg == "mouseMove" and startPt then
                        local band = {
                            x = math.min(startPt.x, mx), y = math.min(startPt.y, my),
                            w = math.abs(mx - startPt.x), h = math.abs(my - startPt.y),
                        }
                        canvas[2].frame = band
                        -- 🚨 ASKED EVERY TIME, and the answer is KEPT: a
                        -- readout that has already gone down must not be
                        -- asked again on the next mouse event, or one
                        -- throw becomes one per pixel of the drag — and
                        -- with the readout switched off there are no
                        -- elements 3 and 4 to write to at all.
                        if readout then readout = showSize(band) end
                    elseif msg == "mouseUp" and startPt then
                        finishAt(mx, my, "mouseUp")
                    end
                end)
                if not ok then shots.cancelSelect() end
            end)
        end)
        -- showCanvasSafely, not canvas:show(): show() THROWS when another
        -- process's remote view is mid-transition (the Safari/Spotlight
        -- bug every canvas popup in this config guards against)
        --
        -- 🚨 6.265.0 — AND ITS ANSWER IS READ. This threw ⇪4 away for a
        -- release. 6.264.0 routed ⇪4 through here and wrote a fallback to
        -- macOS's crosshair for "a Mac that cannot draw our selector",
        -- with a whole paragraph swearing that a ⇪4 which captures
        -- nothing is worse than a ⇪4 with Apple's HUD on it — and then
        -- DISCARDED the one value that says whether it drew. init.lua's
        -- showCanvasSafely returns FALSE when macOS refuses the first
        -- :show() (it retries 50 ms later and tells nobody), so on the
        -- refusal this function answered `true`, areaPlan said "ours",
        -- the fallback never ran, and the key did nothing at all and said
        -- nothing. THE FALLBACK EXISTED AND WAS UNREACHABLE.
        -- 🧪 The check that was supposed to prove it stubbed hs.canvas.new
        -- to return nil — "cannot CREATE" — and never "created, refused to
        -- SHOW", which is the case that actually happens on his Mac
        -- (6.193.0: a stub gentler than the real provider). Both are
        -- driven now.
        -- 🪟 AND A REFUSED CANVAS IS TORN DOWN rather than left holding a
        -- keyDown tap and a retry timer that can order an owner-less
        -- overlay on screen a turn later — the 🟡 frozen-grid-box shape,
        -- in the module that would have grown it next.
        local shown
        if _G.showCanvasSafely then
            shown = _G.showCanvasSafely(canvas, "area selector") and true or false
        else
            -- No helper at all: show it ourselves rather than never
            -- showing it. Before 6.265.0 a Hammerspoon without that
            -- global drew no selector AND reported success.
            shown = pcall(function() canvas:show() end) and true or false
        end
        if not shown then
            shots.selCanvas = canvas
            shots.cancelSelect()
            return false, "macOS would not put the selector on screen"
        end
        shots.selCanvas = canvas   -- HELD
        shots.selStarted = true

        -- 🚪 6.336.0 — THE RELEASE WE CANNOT HEAR. The canvas callback is
        -- the only thing that ends a drag and it only fires over its own
        -- frame, so this asks macOS directly: while a drag is open and no
        -- button is down any more, the button came up somewhere else and
        -- the drag is over. It does not merely UNSTICK the overlay — it
        -- finishes the selection he actually dragged, from where the
        -- pointer is now.
        -- 📏 THE POINT IS CLAMPED INTO THIS SCREEN, and that is not
        -- tidiness: a release on the other display answers a point
        -- outside this canvas, and a rectangle running off the screen is
        -- one screencapture silently trims — so the band he watched and
        -- the file he gets would disagree.
        -- 🚨 6.337.0 — the belt only acts once this Mac has POSITIVELY
        -- reported a held button during THIS drag. Per selector, never
        -- global: a Mac that reports a physical click fine still has
        -- gesture drags it cannot see, so the two must not vouch for
        -- each other.
        local sawHeld, toldNoSignal = false, false
        local function beltTick()
            if not startPt then return end
            local btn
            pcall(function() btn = hs.eventtap.checkMouseButtons() end)
            local act = shots.beltVerdict(sawHeld, btn)
            if act == "held" then sawHeld = true; return end
            if act == "standDown" then
                -- 🔔 COUNTED ONCE PER DRAG, not once per tick: a number
                -- that climbs five times a second is a number nobody can
                -- read, and this one is the evidence that the recovery
                -- stood down rather than that it worked (6.229.0 counts
                -- events, 6.196.1 says a stand-down must not read as
                -- health).
                if not toldNoSignal then
                    toldNoSignal = true
                    shots.selEnds.noSignal = (shots.selEnds.noSignal or 0) + 1
                end
                return
            end
            local mp
            pcall(function() mp = hs.mouse.absolutePosition() end)
            if not mp then
                -- cannot say where it ended: end it at the press, which
                -- takes finishAt's 0 × 0 refusal and SAYS so. An overlay
                -- left up is the failure this release exists to remove.
                finishAt(startPt.x, startPt.y, "belt")
                return
            end
            local lx = math.max(0, math.min(sf.w, (mp.x or 0) - (sf.x or 0)))
            local ly = math.max(0, math.min(sf.h, (mp.y or 0) - (sf.y or 0)))
            finishAt(lx, ly, "belt")
        end

        local armed = false
        pcall(function()
            shots.selPoll = hs.timer.doEvery(shots.selPollSecs, function()
                if not pcall(beltTick) then shots.cancelSelect() end
            end)
            armed = shots.selPoll ~= nil
        end)
        if not armed then
            -- 🔔 A Mac that cannot arm it still selects, on the old path.
            -- What it loses is the recovery, so it is COUNTED and named
            -- rather than left to look like health (6.196.1).
            shots.selEnds.noBelt = (shots.selEnds.noBelt or 0) + 1
            if type(core.degrade) == "function" then
                pcall(core.degrade, "Screenshot area selector",
                      "this Mac would not arm the drag-end watch — a release macOS "
                      .. "swallows will leave the selector on screen until you press Esc")
            end
        end

        -- 📐 6.318.0 — DRAWN AT ONCE, AT THE POINTER, BEFORE ANY EVENT.
        -- Waiting for the first mouseMove would mean a selector that
        -- looks exactly like the old one until you jiggle the mouse,
        -- which is "it did not work" for anybody who presses ⇪4 and
        -- drags straight away. macOS's HUD is there the instant the key
        -- is pressed and so is this.
        if cross or readout then
            local mp
            pcall(function() mp = hs.mouse.absolutePosition() end)
            if mp then
                local lx, ly = (mp.x or 0) - (sf.x or 0), (mp.y or 0) - (sf.y or 0)
                if cross   then cross   = showCross(lx, ly) end
                if readout then readout = showPoint(lx, ly) end
            end
        end

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
        return true
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

    -- 🧻 6.206.0 — THE RUN KEEPS ITS RECEIPTS. LL's ⇪5: "Stitch failed —
    -- slices discarded (screenshots.lua:664: no slices decoded)". That
    -- line said every slice failed to decode and NOTHING about why: the
    -- slice capture ignored screencapture's exit code and its stderr,
    -- appended the path whether or not a file had been written, and the
    -- stitch deleted the slices before anyone could look. 6.201.0's rule
    -- — ask for the artefact before theorising about the mechanism — so
    -- the run now records, per slice, the exit code, the first line of
    -- stderr and whether the file exists and how big it is; stops at the
    -- FIRST slice that fails, naming it; keeps the slices on disk when
    -- it fails (in the local slice folder, 6.213.3); and
    -- `_G.screenshotsReport()`'s "scroll :" line repeats all of it.
    shots.scrollLast = nil    -- { at, planned, shot, decoded, outcome, why, slices }
    local function firstLine(sv)
        sv = tostring(sv or ""):match("^%s*(.-)%s*$") or ""
        return sv:match("^[^\r\n]*") or sv
    end
    local function sizeOf(path)
        local size
        pcall(function() size = hs.fs.attributes(path, "size") end)
        return size
    end
    local function scrollFail(run, why, files)
        run.outcome, run.why = "failed", why
        -- 🚨 KEPT, NOT DISCARDED. A slice that would not stitch is the
        -- only evidence of what screencapture actually wrote.
        run.kept = files
        local keptNote = (files and #files > 0)
            and (" · %d slice(s) kept at %s/scroll-slice-NN.png"):format(
                    #files, tostring(run.sliceDir or shots.sliceDir))
            or ""
        pcall(function()
            hs.alert.show("🧻 Scrolling capture stopped — " .. why
                          .. "\n_G.screenshotsReport() has the details", 5)
        end)
        warn("scrolling capture: " .. why .. keptNote)
        if _G.notices and _G.notices.record then
            pcall(function()
                _G.notices.record("screenshots", "scrolling capture failed", why)
            end)
        end
    end

    -- 6.213.3 — where the slices go. → dir | nil, why. A folder that
    -- exists is used; one that does not is created (one level — the
    -- Hammerspoon support folder exists on any Mac running this); a FILE
    -- in the way is a refusal, never overwritten; the temporary folder is
    -- the degrade and the report names it.
    function shots.sliceFolder()
        local function usable(d)
            if type(d) ~= "string" or d == "" then return false end
            local mode
            pcall(function() mode = hs.fs.attributes(d, "mode") end)
            if mode == "directory" then return true end
            if mode ~= nil then return false end
            local made
            pcall(function() made = hs.fs.mkdir(d) end)
            return made == true
        end
        if usable(shots.sliceDir) then
            shots.sliceHome = { dir = shots.sliceDir, how = "local, never synced" }
            return shots.sliceDir
        end
        local tmp
        pcall(function() tmp = hs.fs.temporaryDirectory() end)
        if type(tmp) == "string" then tmp = tmp:gsub("/+$", "") end
        if usable(tmp) then
            shots.sliceHome = { dir = tmp, how = ("temporary — %s could not be created")
                                                 :format(tostring(shots.sliceDir)) }
            return tmp
        end
        shots.sliceHome = { dir = nil, how = ("neither %s nor the temporary folder"
                                              .. " could be created"):format(tostring(shots.sliceDir)) }
        return nil, shots.sliceHome.how
    end

    -- Decode one slice, or say exactly which of the three ways it failed.
    -- → img, sizePx | nil, why
    function shots.decodeSlice(path)
        local size = sizeOf(path)
        if not size then return nil, "no file was written" end
        if size == 0 then return nil, "the file is empty (0 bytes)" end
        local img
        pcall(function() img = hs.image.imageFromPath(path) end)
        if not img then
            return nil, ("the file exists (%d bytes) but did not decode as an image"):format(size)
        end
        local sz
        pcall(function() sz = img:size() end)
        if not (sz and sz.w and sz.w > 0 and sz.h and sz.h > 0) then
            return nil, ("the file exists (%d bytes) but has no size"):format(size)
        end
        return img, sz
    end

    function shots.stitch(files, rect, plan, thenEdit, run)
        run = run or shots.scrollLast or {}
        local outPath
        local ok, err = pcall(function()
            local imgs, heights, w, totalH = {}, {}, 0, 0
            for i, f in ipairs(files) do
                local img, sz = shots.decodeSlice(f)
                if not img then
                    error(("slice %d of %d: %s"):format(i, #files, tostring(sz)), 0)
                end
                -- the FILE is in pixels, the SELECTION is in points;
                -- Retina makes them differ by 2x, so the crop scales
                local scale = sz.w / rect.w
                local cropPx = math.floor(((plan[i] or {}).crop or 0) * scale)
                if cropPx > 0 and img.croppedCopy then
                    img = img:croppedCopy({ x = 0, y = cropPx,
                                            w = sz.w, h = sz.h - cropPx })
                    sz = img:size()
                end
                imgs[#imgs + 1] = img
                heights[#heights + 1] = sz.h
                w = math.max(w, sz.w)
                totalH = totalH + sz.h
                run.decoded = (run.decoded or 0) + 1
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
            shots.own[outPath] = true
            assert(outImg:saveToFile(outPath), "could not write " .. outPath)
        end)
        if not ok then
            scrollFail(run, "stitch: " .. tostring(err), files)
            return
        end
        for _, f in ipairs(files) do pcall(os.remove, f) end
        run.outcome, run.why, run.out = "ok", nil, outPath
        run.kept = nil
        -- finish() copies the result to the clipboard (off the main
        -- thread, 6.170.3) and says so, exactly as ⇪4 does
        shots.finish(outPath, thenEdit)
    end

    function shots.scrollingCapture(thenEdit)
        if not shots.ensureDir() then return end
        shots.selectArea(function(rect)
            local plan = shots.scrollPlan(rect.h, shots.scroll.height,
                                          shots.scroll.cropTop)
            if #plan == 0 then return end
            local run = { at = os.time(), planned = #plan, shot = 0, decoded = 0,
                          outcome = "running", rect = rect, slices = {} }
            shots.scrollLast = run
            -- 6.213.3 — the slices' folder, decided ONCE per run, before
            -- the first slice: no folder means no capture, said plainly.
            local sliceDir, sliceWhy = shots.sliceFolder()
            if not sliceDir then
                scrollFail(run, "no folder for the slices — " .. tostring(sliceWhy), {})
                return
            end
            run.sliceDir = sliceDir
            -- scroll events go to whatever is UNDER THE POINTER — park it
            pcall(function()
                hs.mouse.absolutePosition({ x = rect.x + rect.w / 2,
                                            y = rect.y + rect.h / 2 })
            end)
            local files, i = {}, 0
            local function step()
                i = i + 1
                if i > #plan then
                    -- 🚨 OFF THE TASK CALLBACK FIRST (6.196.1): the last
                    -- slice's callback is the frame this runs in, and
                    -- the stitch allocates a canvas and a dozen images.
                    shots.stitchTimer = hs.timer.doAfter(0, function()
                        shots.stitch(files, rect, plan, thenEdit, run)
                    end)
                    return
                end
                local function shoot()
                    -- 6.213.3: a plain name in the LOCAL slice folder —
                    -- never the screenshots folder (see sliceDir's note)
                    local slice = sliceDir .. ("/scroll-slice-%02d.png"):format(i)
                    local okRun = shots.runCapture({
                        "-x",
                        ("-R%d,%d,%d,%d"):format(rect.x, rect.y, rect.w, rect.h),
                        slice,
                    }, slice, false, function(_, exitCode, serr)
                        local size = sizeOf(slice)
                        run.slices[#run.slices + 1] = {
                            n = i, code = exitCode, err = firstLine(serr), size = size,
                        }
                        if (exitCode ~= nil and exitCode ~= 0) or not size or size == 0 then
                            local why = ("slice %d of %d: screencapture exit %s"):format(
                                i, #plan, tostring(exitCode))
                            local e = firstLine(serr)
                            if e ~= "" then why = why .. " — " .. e end
                            why = why .. (not size and " — no file was written"
                                          or (size == 0 and " — the file is empty" or ""))
                            if e:lower():find("image") or e:lower():find("display")
                               or e:lower():find("permission") then
                                why = why .. " (if macOS is refusing the capture: System"
                                      .. " Settings → Privacy & Security → Screen"
                                      .. " Recording → Hammerspoon, then quit and relaunch)"
                            end
                            scrollFail(run, why, files)
                            return
                        end
                        run.shot = run.shot + 1
                        files[#files + 1] = slice
                        step()
                    end)
                    if not okRun then
                        scrollFail(run, ("slice %d of %d: screencapture could not be started")
                                        :format(i, #plan), files)
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

    -- 📋 6.319.0 — THE WORDS LAND ON THE CLIPBOARD (LL: "Once I OCR some
    -- text, that text should immediately go onto the clipboard so I can
    -- paste it").
    -- 🔎 AND ⇪⇧4 ALREADY DID, which is the half to say first: 6.173.1
    -- wired recognizeFile to setContents and it has copied ever since.
    -- What never copied is the OTHER door — the shot ⇪4 takes, which the
    -- watcher OCRs to NAME it and then throws the words away into a CSV.
    -- 6.317.0's rule, one module along: when he asks for something this
    -- config can nearly do, find which DOOR is missing rather than
    -- building a second instrument beside the one that works.
    --
    -- 🚨 AND A SWAP MUST NEVER COST HIM A COPY HE MADE. The only thing
    -- these words are allowed to replace is THE SHOT THEY WERE READ
    -- FROM, still sitting on the clipboard where this config put it
    -- seconds ago — never a copy of his, never a shot that arrived from
    -- the other Mac over OneDrive, never one he took five minutes back.
    -- 6.198.0 paid for this in power_tools and the lesson is the same:
    -- ask macOS's CHANGE COUNTER, which sees the two writes a text
    -- comparison never can (the same thing copied twice, and anything
    -- that is not text).
    -- 📏 COST, NAMED, because it is a real one: after a ⇪4 whose words
    -- were read, ⌘V pastes the WORDS and no longer the picture. The
    -- picture is not lost — it is in the folder, under a name made of
    -- those same words, and ⇪⇧5 then ⏎ puts it back on the clipboard.
    -- The alert says so at the moment it happens, because a clipboard
    -- that changed under him with nothing said is the surprise this
    -- release would otherwise be.
    --     settings = { screenshots = { textToClipboard = false } }
    --
    -- 🔁 6.341.0 — AND IT SHIPS OFF, ON HIS WORD. LL: "When I take a
    -- screenshot that always takes priority, unless I use my
    -- hyper+shift+4 … Right now I have to use hyper+shift+5 to place the
    -- screenshot back. Reverse that."
    --
    -- 🔎 AND IT EXPLAINS "SOMETIMES", which is how he reported it: the
    -- swap only ever fired when OCR actually found WORDS, when the shot
    -- was still the thing on the clipboard, and inside clipSwapSecs. A
    -- photograph, a dark panel, a diagram, a copy of his own in between —
    -- any of those left the picture alone. One key, two outcomes, no way
    -- to tell in advance which: that is worse than either behaviour.
    --
    -- 🚪 THE OTHER DOOR IS UNTOUCHED. ⇪⇧4 (shots.recognizeFile) has
    -- copied its OCR text through its own path since 6.173.1 and does not
    -- read this flag, so the key he names as the OCR door keeps being it.
    -- And the OCR still RUNS here, in the background, exactly as he asked:
    -- the file is renamed after its words, the words go into the Finder
    -- comment and into ⇪O's log. What stops is only the clipboard write.
    --
    -- ✍️ 6.267.0 decides the shape: a wrong default is CHANGED AND
    -- SHIPPED, never left as a settings line for him to type. The switch
    -- stays so the release is reversible and the gate can drive it both
    -- ways, and it is documented rather than prescribed.
    shots.textToClipboard = false
    shots.clipSwapSecs    = 25     -- a shot older than this speaks for nobody
    shots.ownClip         = nil    -- { path, count, at } — what WE last put there
    shots.clipStats       = { wrote = 0, failed = 0, empty = 0,
                              swapped = 0, held = 0, off = 0 }
    shots.clipLast        = nil    -- { ok, why, chars, at }
    shots.clipThrew       = 0      -- the swap raised inside the callback
    shots.swapWhy         = nil    -- why the last arrival did not swap

    -- PURE: may the words of `path` replace what is on the clipboard?
    -- SIX answers and only one of them writes (6.196.1) — "we never put
    -- anything there", "that is a different shot", "macOS would not say",
    -- "you copied since", "too long ago", and yes.
    function shots.swapVerdict(own, path, nowCount, now, secs)
        if type(path) ~= "string" or path == "" then
            return false, "there is no file for the words to speak for"
        end
        if type(own) ~= "table" then
            return false, "this config has not put a shot on the clipboard"
        end
        if own.path ~= path then
            return false, "the clipboard holds a different shot"
        end
        -- 🚨 UNKNOWN REFUSES, and that is the opposite of pt.borrowIntact
        -- on purpose: a default is chosen against the damage its own
        -- feature can do. The damage here is destroying something he
        -- copied; the cost of refusing is that he fetches the words from
        -- ⇪O. Those are not the same size.
        if type(own.count) ~= "number" or type(nowCount) ~= "number" then
            return false, "macOS would not say whether the clipboard had changed"
        end
        if own.count ~= nowCount then
            return false, "you copied something else after the shot"
        end
        local age = (tonumber(now) or 0) - (tonumber(own.at) or 0)
        local lim = tonumber(secs) or 0
        if age < 0 or age > lim then
            return false, ("the shot was %ds ago, past the %ds window")
                          :format(math.floor(age < 0 and 0 or age), math.floor(lim))
        end
        return true, "the clipboard still holds the shot these words came from"
    end

    -- 📋 ONE DOOR for every text this module puts on the clipboard
    -- (6.231.0). It exists because of what the three sites it replaces
    -- had in common: `pcall(function() hs.pasteboard.setContents(t) end)`
    -- — and setContents REFUSES BY RETURNING FALSE, never by throwing, so
    -- that pcall is true either way and "📝 Text copied" was printed over
    -- a write that had not happened. 6.198.0 wrote this rule down and
    -- named two files still carrying the shape; this module was a third.
    function shots.copyOut(text)
        local st = shots.clipStats
        text = (type(text) == "string") and text or ""
        local function record(ok, why)
            local k = ok and "wrote" or why
            st[k] = (st[k] or 0) + 1
            -- 🕒 the EPOCH, never a formatted string: every report line
            -- in this module reads a stored clock through shots.clockText,
            -- and a source sentry holds the class (6.282.0). macOS hands
            -- back a float here, which is the whole reason that exists.
            local at
            pcall(function() at = hs.timer.secondsSinceEpoch() end)
            shots.clipLast = { ok = ok, why = why, chars = #text,
                               at = (type(at) == "number") and at or os.time() }
            return ok, why
        end
        if text == "" then return record(false, "empty") end
        local wrote = false
        pcall(function() wrote = hs.pasteboard.setContents(text) ~= false end)
        if not wrote then
            -- 🔔 A BREAK IS SEEN, NEVER ONLY LOGGED (6.214.0). The words
            -- are not lost — ⇪O has them — and that is what the door says.
            if type(core.degrade) == "function" then
                pcall(core.degrade, "OCR clipboard",
                      "the words were read but macOS refused to put them on "
                      .. "the clipboard — they are in the log, press ⇪O")
            end
            return record(false, "failed")
        end
        -- the clipboard holds TEXT now, so no later arrival may "swap"
        -- against a shot that is no longer there.
        shots.ownClip = nil
        return record(true, "wrote")
    end

    -- 🔎 6.206.0 — THE REPORT this module never had. The folder, the
    -- watcher, the last capture's exit, and the last scrolling run with
    -- every slice's receipt — "no slices decoded" is a question this
    -- answers now instead of a sentence in an alert.
    function _G.screenshotsReport()
        local L = { "📸 SCREENSHOTS" }
        L[#L + 1] = "   folder  : " .. tostring(shots.dir)
        L[#L + 1] = "   watcher : " .. (shots.watcher and "watching for arrivals"
                    or (shots.watchFolder and "not started (first capture starts it)"
                        or "off (shots.watchFolder = false)"))
                    .. " · named on arrival " .. tostring(shots.namedOnArrival)
                    .. " · left for ⌘9 " .. tostring(shots.leftForSweep)
        -- 🔎 6.281.0 — THE LINE ABOVE COULD NOT SEE A RUNAWAY, and that is
        -- why "I don't know" was the honest answer to "is it looping?".
        -- namedOnArrival counts only SUCCESSES and leftForSweep only cap
        -- OVERFLOW, so a word-less image incremented neither: an infinite
        -- loop read "0 · 0" for as long as it ran. 6.196.1's rule, broken
        -- inside the report built to keep it. These count the OCRs.
        do
            local started = shots.ocrStarted or 0
            local named   = shots.namedOnArrival or 0
            L[#L + 1] = ("   OCR     : %d run · %d named · %d read no text · "
                         .. "%d had no usable name · %d failed · %d never ran")
                        :format(started, named, shots.ocrNoText or 0,
                                shots.ocrNoName or 0, shots.ocrFailed or 0,
                                shots.ocrNotRun or 0)
            -- what they BOUGHT beside what they cost (6.229.0) — and never
            -- a division that did not happen dressed as a measurement
            -- (6.230.0's max(rows,1)).
            if started > 0 then
                L[#L + 1] = ("   yield   : %d of %d OCR(s) bought a name")
                            :format(named, started)
            else
                L[#L + 1] = "   yield   : no OCR has run this session"
            end
            local nTried, nCapped = 0, 0
            for _, n in pairs(shots.tried or {}) do
                nTried = nTried + 1
                if n >= (shots.triedMax or 3) then nCapped = nCapped + 1 end
            end
            if nTried == 0 then
                L[#L + 1] = "   tried   : nothing has OCR'd to nothing yet"
            else
                L[#L + 1] = ("   tried   : %d file(s) remembered · %d at the %d-try "
                             .. "cap — the watcher no longer offers those, ⌘9 still does")
                            :format(nTried, nCapped, shots.triedMax or 3)
            end
            if (shots.refusedTried or 0) > 0 then
                L[#L + 1] = ("   ↳ %d re-queue(s) refused this session · last: %s")
                            :format(shots.refusedTried, tostring(shots.triedLast or "?"))
            end
        end
        if shots.lastExit then
            L[#L + 1] = "   last screencapture exit : " .. tostring(shots.lastExit.code)
                        .. (shots.lastExit.err ~= "" and (" — " .. firstLine(shots.lastExit.err)) or "")
        else
            L[#L + 1] = "   last screencapture exit : none this session"
        end
        local sh = shots.sliceHome
        L[#L + 1] = "   slices  : " .. (sh and (sh.dir and (sh.dir .. " · " .. sh.how)
                                                or ("⚠️ NONE — " .. tostring(sh.how)))
                                       or ("not yet asked · will use " .. tostring(shots.sliceDir)
                                           .. " (local, never OneDrive)"))
        -- 📐 6.260.0 — three states that must not read alike (6.196.1):
        -- switched off ≠ on but never dragged ≠ on and drawn. A fourth,
        -- the readout having THROWN, outranks all three — it is the one
        -- state where "0 drawn" would be a lie about a healthy Mac.
        L[#L + 1] = "   size    : " .. (
            (not shots.sizeReadout)
                and "OFF — settings = { screenshots = { sizeReadout = false } }"
            or shots.sizeFailed and ("⚠️ " .. tostring(shots.sizeFailed))
            or (shots.sizeLast
                and ("%d × %d · %s · last drawn %s"):format(
                        shots.sizeLast.w, shots.sizeLast.h,
                        tostring(shots.sizeLast.why),
                        shots.clockText(shots.sizeLast.at))
                or ("white on black at alpha " .. tostring(shots.sizeAlpha)
                    .. " · nothing dragged yet this session")))
        -- 📐 6.318.0 — THE CROSSHAIR, and it is counted apart from the
        -- readout on purpose: "⇪4 has no crosshairs" and "⇪4 has no
        -- numbers" were ONE complaint from him and are two different
        -- failures here, with two different switches (6.196.1).
        L[#L + 1] = "   cross   : " .. (
            (not shots.crosshair)
                and "OFF — settings = { screenshots = { crosshair = false } }"
            or shots.crossFailed and ("⚠️ " .. tostring(shots.crossFailed))
            or (shots.crossLast
                and ("drawn · last at %d, %d · %s"):format(
                        shots.crossLast.x, shots.crossLast.y,
                        shots.clockText(shots.crossLast.at))
                or ("hairline at alpha " .. tostring(shots.crossAlpha)
                    .. " · the selector has not been opened yet this session")))
        -- 📋 6.319.0 — WHO GOT THE CLIPBOARD. Three states that must not
        -- read alike (6.196.1): switched off ≠ on and nothing has
        -- qualified ≠ on and it swapped. A REFUSED write outranks all
        -- three, because "0 swapped" over a dead door is the reassuring
        -- lie 6.260.0's size line exists to forbid.
        do
            local cs = shots.clipStats or {}
            local line
            if not shots.textToClipboard then
                -- 🔁 6.341.0 — THIS IS THE SHIPPED DEFAULT NOW, so it must
                -- not read like something he switched off and forgot. The
                -- count is what PROVES it: "N arrival(s) kept the picture"
                -- is the release working, not a tally of refusals.
                line = ("the shot keeps the clipboard — ⇪⇧4 is the OCR door "
                        .. "(shipped default since 6.341.0) · %d arrival(s) "
                        .. "kept the picture this session")
                       :format(cs.off or 0)
            elseif (shots.clipThrew or 0) > 0 then
                line = ("⚠️ %d swap(s) THREW — the words are in ⇪O and the "
                        .. "naming was unaffected"):format(shots.clipThrew)
            elseif (cs.failed or 0) > 0 then
                line = ("⚠️ %d clipboard write(s) REFUSED by macOS — the words "
                        .. "are in ⇪O"):format(cs.failed)
            elseif (cs.wrote or 0) == 0 then
                line = ("on — no OCR text has reached the clipboard yet this "
                        .. "session (a shot's words replace it for %ds)")
                       :format(shots.clipSwapSecs or 0)
            else
                line = ("%d text(s) copied · %d of them replaced the shot they "
                        .. "were read from · %d arrival(s) left your own copy alone")
                       :format(cs.wrote or 0, cs.swapped or 0, cs.held or 0)
            end
            L[#L + 1] = "   clip    : " .. line
            if shots.clipLast then
                L[#L + 1] = ("             ↳ last: %s · %d character(s) at %s")
                            :format(shots.clipLast.ok and "copied"
                                    or ("NOT copied — " .. tostring(shots.clipLast.why)),
                                    shots.clipLast.chars or 0,
                                    shots.clockText(shots.clipLast.at))
            end
            if shots.swapWhy and (cs.held or 0) > 0 then
                L[#L + 1] = "             ↳ last arrival did not swap: "
                            .. tostring(shots.swapWhy)
            end
            -- 🔁 6.341.0 — the way back, said once, under the state it
            -- reverses rather than inside it
            if not shots.textToClipboard then
                L[#L + 1] = "             ↳ settings = { screenshots = "
                            .. "{ textToClipboard = true } } puts the swap back"
            end
        end
        -- 📐 6.264.0 — the line under it used to end "⇪4 is macOS's own
        -- crosshair and keeps its HUD". It is not, by default, any more.
        -- 📐 6.337.0 — ⇪4 came OFF our selector again, on his evidence, so
        -- this line no longer claims it. ⇪5, the editor's ⌘A and
        -- repeat-area still drag on ours, readout and crosshairs and all.
        L[#L + 1] = "             ↳ ⇪5, the editor's ⌘A and 'repeat area' drag on OUR "
                    .. "selector, with crosshairs and a live size; ⇪4 is macOS's own "
                    .. "crosshair and HUD again (6.337.0)"
        -- 🔎 THREE STATES (6.196.1): ⇪4 looking unchanged is either his
        -- own settings line or a Mac that could not draw ours, and those
        -- are opposite facts. Never asked is a third.
        L[#L + 1] = "   area    : " .. (
            shots.areaLast
                and ((shots.areaLast.how == "native" and not shots.areaNative
                        and "⚠️ " or "")
                     .. tostring(shots.areaLast.why)
                     .. " · last pressed "
                     .. shots.clockText(shots.areaLast.at))
            or (shots.areaNative
                    and "macOS's own crosshair and HUD — the shipped default "
                        .. "(areaNative = false puts our selector back) · not "
                        .. "pressed yet this session"
                    or "our selector, with the live size readout · not pressed "
                       .. "yet this session"))
        -- 🔎 6.274.0 — the routes, counted apart, because "intermittent"
        -- is the one thing a single last-press line cannot describe.
        local ar = shots.areaRuns or {}
        local pressed = (ar.ours or 0) + (ar.native or 0)
        if pressed == 0 then
            L[#L + 1] = "   routes  : ⇪4 has not been pressed this session"
        else
            L[#L + 1] = ("   routes  : %d press(es) — %d on our selector · %d on macOS's crosshair")
                        :format(pressed, ar.ours or 0, ar.native or 0)
            if (ar.refused or 0) > 0 then
                L[#L + 1] = "   ↳ ⚠️ " .. ar.refused .. " of those were a REFUSAL, not your settings line"
                            .. " — that is the intermittent one"
            end
        end
        -- 🚪 6.336.0 — HOW THE DRAG ENDED, counted apart. "the button came
        -- up where we could not see it" climbing is the evidence for the
        -- Space-swipe story and the only thing that can settle it without
        -- asking him to remember what his fingers did.
        local se = shots.selEnds or {}
        local ends = (se.mouseUp or 0) + (se.belt or 0)
        if ends == 0 then
            L[#L + 1] = "   drag    : no drag has finished this session"
        else
            L[#L + 1] = ("   drag    : %d finished — %d on the release itself · "
                         .. "%d where macOS swallowed the release")
                        :format(ends, se.mouseUp or 0, se.belt or 0)
            if (se.belt or 0) > 0 then
                L[#L + 1] = "   ↳ a release off this screen, past its edge, or across a "
                            .. "desktop switch — recovered rather than left on screen"
            end
            if (se.tiny or 0) > 0 then
                L[#L + 1] = "   ↳ " .. se.tiny .. " of them were too small to capture and said so"
            end
            local le = shots.selLastEnd
            if le then
                L[#L + 1] = ("   ↳ last: %d × %d, %s · %s")
                            :format(le.w or 0, le.h or 0,
                                    le.how == "belt" and "the release was swallowed"
                                                      or "ended on the release",
                                    shots.clockText(le.at))
            end
        end
        if (se.noSignal or 0) > 0 then
            L[#L + 1] = "   ↳ " .. se.noSignal .. " drag(s) ran with no held-button signal "
                        .. "at all — the drag-end watch stood down rather than guess "
                        .. "(a trackpad gesture drag presses no button)"
        end
        if (se.noBelt or 0) > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. se.noBelt .. " selector(s) ran with NO drag-end watch — "
                        .. "a swallowed release leaves this one up until Esc"
        end
        if (shots.dirFails or 0) > 0 then
            L[#L + 1] = "   ↳ ⚠️ " .. shots.dirFails .. " press(es) found no folder to write to: "
                        .. tostring(shots.dirFailWhy)
        end
        local r = shots.scrollLast
        if not r then
            L[#L + 1] = "   scroll  : never run this session (⇪5)"
        else
            L[#L + 1] = ("   scroll  : %s · %d planned · %d shot · %d decoded · %s")
                        :format(shots.clockText(r.at), r.planned or 0, r.shot or 0,
                                r.decoded or 0, tostring(r.outcome))
            if r.why then L[#L + 1] = "             ↳ " .. tostring(r.why) end
            if r.out then L[#L + 1] = "             ↳ " .. tostring(r.out) end
            for _, sl in ipairs(r.slices or {}) do
                L[#L + 1] = ("             slice %02d: exit %s · %s%s"):format(
                    sl.n, tostring(sl.code),
                    sl.size and (tostring(sl.size) .. " bytes") or "no file",
                    (sl.err and sl.err ~= "") and (" · " .. sl.err) or "")
            end
            if r.kept and #r.kept > 0 then
                L[#L + 1] = "             ↳ the slices were KEPT for a look: "
                            .. tostring(r.sliceDir or shots.sliceDir) .. "/scroll-slice-NN.png"
            end
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
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

    -- 6.173.1 — LL: "OCR Logs do not have what hyper+v or the system
    -- clipboard has after an OCR event using hyper+4 or hyper+shift+4."
    -- 6.172.1 wired only the name-on-arrival path; the RECOGNIZE path
    -- (⇪4's text-to-clipboard, the panel's OCR row) put words on the
    -- pasteboard and nowhere else. Every text this module puts on the
    -- clipboard now goes through here — the one door into ⇪O's log.
    -- 6.187.0 — and WHICH IMAGE it came from. Every caller here has the
    -- file in hand; passing it is what lets ⇪space's @images show you the
    -- picture instead of only the words. A caller without one passes
    -- nothing and the row is the two-column row it always was.
    function shots.recordText(text, path)
        if _G.service and _G.service.has and _G.service.has("ocr.record") then
            pcall(function() _G.service.call("ocr.record", text, path) end)
        end
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
                        -- 6.319.0 — through the one door, which READS the
                        -- return: this alert claimed a copy that had not
                        -- happened whenever macOS refused the write.
                        -- 📓 THE LOG FIRST, THE CLIPBOARD SECOND, and the
                        -- order is load-bearing: a refused write tells him
                        -- "⇪O has it", so the log must not sit behind the
                        -- step that can fail (6.246.0's ordering rule, in
                        -- the one place the fallback is named out loud).
                        shots.recordText(text, path)
                        local put = shots.copyOut(text)
                        pcall(function()
                            hs.alert.show(put
                                and ("📝 Text copied: "
                                     .. text:gsub("%s+", " "):sub(1, 60))
                                or ("⚠️ Read the text, but macOS refused the "
                                    .. "clipboard — ⇪O has it"), 3)
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
                    shots.recordText(payload, path)
                    local put = shots.copyOut(payload)
                    pcall(function()
                        hs.alert.show(put
                            and ("🔳 Code copied: " .. payload:sub(1, 60))
                            or ("⚠️ Read the code, but macOS refused the "
                                .. "clipboard — ⇪O has it"), 3)
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

    -- ---- content names (6.147.0) -----------------------------------------
    -- The words OF the shot become the NAME of the shot, so Finder,
    -- Spotlight, ⇪⇧4 and ⇪⇧space all find it by what was on the screen
    -- — with no index in the way, because the index IS the filename.

    -- OCR text → the filename's word part. Words under three characters
    -- are noise ("of", "at", UI chrome) unless they carry a digit, which
    -- is usually the part you remember ("403", "M5").
    function shots.slugFrom(text)
        local words = {}
        for w in tostring(text or ""):gmatch("[%w][%w'%-]*") do
            if #w >= 3 or w:match("%d") then
                words[#words + 1] = w
                if #words >= shots.slugWords then break end
            end
        end
        local slug = table.concat(words, " ")
        if #slug > shots.slugChars then
            slug = slug:sub(1, shots.slugChars):gsub("%s+%S*$", "")
        end
        slug = slug:gsub("^%s+", ""):gsub("%s+$", "")
        if slug == "" then return nil end
        return slug
    end

    -- What a file should be called once its words are known. nil means
    -- "leave it alone": it already carries words (an " — " in the name),
    -- or its name was chosen by a person — only the two mechanical
    -- conventions (SCR-… and this module's own) are ever rewritten.
    function shots.contentName(basename, slug, mtime)
        if not slug then return nil end
        if basename:find(" — ", 1, true) then return nil end
        local stem, ext = basename:match("^(.+)%.(%w+)$")
        if not stem then return nil end
        if stem:match("^SCR%-%d%d%d%d%d%d%d%d%-") then
            -- another tool's random suffix: fold into this module's own
            -- shape, keeping the file's real moment (its mtime)
            stem = os.date("Screenshot %Y-%m-%d at %H.%M.%S", mtime or os.time())
        elseif not stem:match("^Screenshot ") then
            return nil
        end
        return stem .. " — " .. slug .. "." .. ext
    end

    -- The names this module is allowed to rewrite: an image with one of
    -- the two MECHANICAL names (another tool's SCR-…, or our own
    -- timestamp) and no words yet. One definition, used by ⌘9's sweep and
    -- the folder watcher alike — two copies of this rule would drift.
    function shots.wantsName(name)
        local ext = tostring(name or ""):match("%.(%w+)$")
        if not ext then return false end
        ext = ext:lower()
        if ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then return false end
        if name:find(" — ", 1, true) then return false end
        return name:match("^SCR%-%d%d%d%d%d%d%d%d%-") ~= nil
            or name:match("^Screenshot ") ~= nil
    end

    function shots.renameTo(path, newBase)
        local dir = path:match("^(.*)/[^/]+$") or shots.dir
        local target = dir .. "/" .. newBase
        local exists
        pcall(function() exists = hs.fs.attributes(target, "size") end)
        if exists then
            local stem, ext = newBase:match("^(.+)%.(%w+)$")
            for n = 2, 99 do
                target = dir .. "/" .. stem .. " " .. n .. "." .. ext
                local e2 = nil
                pcall(function() e2 = hs.fs.attributes(target, "size") end)
                if not e2 then break end
            end
        end
        local ok = os.rename(path, target)
        if not ok then
            warn("rename failed: " .. (path:match("[^/]+$") or path))
            return nil
        end
        say("named by content: " .. (target:match("[^/]+$") or target))
        return target
    end

    -- OCR one file, rename it from its words, and hand the words to the
    -- OCR engine for the Finder comment (its never-overwrite rule
    -- applies there, not here). Failure costs the new name only — the
    -- file itself is never at risk, rename is the ONLY write.
    shots.nameTasks = {}

    -- 🔁 6.281.0 — WHAT THIS MODULE HAS ALREADY TRIED.
    -- FAILURES ONLY, and that is the whole economy of it: a SUCCESS renames
    -- the file, the new name carries " — ", and wantsName() refuses it for
    -- ever — the rename IS the memory. Recording successes here would spend
    -- a bounded table on entries that can never be looked up again, and
    -- evict the word-less ones this exists to hold.
    -- In MEMORY, not on disk, deliberately: hs.settings writes the whole
    -- Hammerspoon domain on the main thread (6.228.0) and this folder is
    -- the one the watcher watches (6.229.0). COST, NAMED: a reload gives
    -- every word-less file triedMax fresh attempts, once. That is finite;
    -- what it replaces was not.
    shots.tried      = {}    -- path -> attempts that produced no name
    shots.triedSeq   = {}    -- insertion order, so the bound has something to drop
    shots.triedLast  = nil
    shots.ocrStarted = 0     -- `shortcuts` processes this session — the green pills
    shots.ocrNoText  = 0     -- ran, exit 0, read nothing
    shots.ocrNoName  = 0     -- read words, but no usable name came out
    shots.ocrFailed  = 0     -- ran and exited non-zero
    shots.ocrNotRun  = 0     -- never spawned — MUST NOT count as evidence
    shots.refusedTried = 0   -- re-queues this rule turned away

    -- PURE. The whole refusal rule, so the gate proves it with no Mac.
    -- Answers whether the watcher may OCR this path again, AND why.
    function shots.triedVerdict(n, max)
        if type(n) ~= "number" or n <= 0 then return true, "not tried yet" end
        if type(max) ~= "number" or max <= 0 then return true, "no cap" end
        if n >= max then
            return false, ("OCR'd %d time(s) with no readable text"):format(n)
        end
        return true, ("tried %d of %d"):format(n, max)
    end

    -- PURE given its two tables. Bounded: every table in this config is
    -- (shots.own and shots.pending are not, and are named in the report).
    function shots.noteTried(tried, seq, path, keep)
        if type(tried) ~= "table" or type(seq) ~= "table" then return false end
        if type(path) ~= "string" or path == "" then return false end
        local cap = (type(keep) == "number" and keep >= 1) and keep or 400
        if tried[path] == nil then
            seq[#seq + 1] = path
            tried[path] = 0
            while #seq > cap do
                local gone = table.remove(seq, 1)
                -- never forget the path we are recording right now
                if gone ~= path then tried[gone] = nil end
            end
        end
        tried[path] = (tried[path] or 0) + 1
        return true, tried[path]
    end

    -- The gate both doors ask. A table lookup, NO stat: this runs inside
    -- the FSEvents callback, on the main thread, once per path per wake-up
    -- (6.228.0 — a main thread this config is busy on is a mouse this Mac
    -- has lost).
    function shots.mayTry(path)
        return (shots.triedVerdict(shots.tried[path], shots.triedMax))
    end

    function shots.nameByText(path, onDone)
        if _G.ocrShortcutAvailable == false then
            -- 🚨 6.281.0 — NOTHING RAN, SO NOTHING IS EVIDENCE. This exit and
            -- the one below hand back nil without ever spawning a process;
            -- a caller that recorded an attempt here would permanently
            -- blacklist every file it touched during an OCR outage.
            shots.ocrNotRun = shots.ocrNotRun + 1
            if onDone then onDone(nil, "not run") end
            return false
        end
        local t
        local okNew = pcall(function()
            t = hs.task.new("/usr/bin/shortcuts", function(code, sout)
                shots.nameTask = nil
                shots.nameTasks[t] = nil
                local newPath
                local text = tostring(sout or ""):match("^%s*(.-)%s*$") or ""
                -- 🔎 6.281.0 — FOUR OUTCOMES, NOT TWO. This handed back
                -- newPath alone, so "OCR read nothing" and "the Shortcut
                -- never ran" reached the caller as the same nil — and one
                -- of those must be remembered while the other must never
                -- be. 6.196.1, in the callback the whole loop turns on.
                local why
                if code ~= 0 then
                    why = "failed"
                    shots.ocrFailed = shots.ocrFailed + 1
                elseif text == "" then
                    why = "no text"
                    shots.ocrNoText = shots.ocrNoText + 1
                end
                if code == 0 and text ~= "" then
                    local base = path:match("[^/]+$") or path
                    local mtime
                    pcall(function()
                        mtime = hs.fs.attributes(path, "modification")
                    end)
                    local newBase = shots.contentName(base, shots.slugFrom(text), mtime)
                    if newBase then newPath = shots.renameTo(path, newBase) end
                    if newPath and _G.service and _G.service.has
                       and _G.service.has("ocr.comment") then
                        pcall(function()
                            _G.service.call("ocr.comment", newPath, text)
                        end)
                    end
                    -- 6.172.1 — the words also go into the OCR log ⇪O
                    -- reads (they never did: only the Finder comment).
                    -- 6.187.0 — with the file they were read from, and it
                    -- must be the NEW name: this path renames the shot to
                    -- match its contents, so recording the old name would
                    -- file every arrival against a file that is already gone.
                    shots.recordText(text, newPath or path)
                    -- 📋 6.319.0 — AND THE WORDS GO ON THE CLIPBOARD, but
                    -- ONLY when the thing they would replace is the shot
                    -- they were read from, still there, put there by this
                    -- config, seconds ago. Everything else — a copy of
                    -- his, an arrival from the other Mac, a shot from
                    -- five minutes back — is refused and SAID.
                    if shots.textToClipboard then
                        -- 🔒 ITS OWN GUARD, and the sweep is what asked for
                        -- it: this sits in the MIDDLE of a task callback
                        -- whose later half still has to run — the rename's
                        -- verdict and `onDone`, which drainQueue waits on
                        -- (6.155.0). A throw here is a silence that strands
                        -- the naming queue, so the convenience never shares
                        -- the load-bearing path's guard (6.235.0, 6.260.0).
                        local okSwap = pcall(function()
                            local c, n
                            pcall(function() c = hs.pasteboard.changeCount() end)
                            pcall(function() n = hs.timer.secondsSinceEpoch() end)
                            local may, swapWhy = shots.swapVerdict(
                                shots.ownClip, path, c, n or os.time(),
                                shots.clipSwapSecs)
                            shots.swapWhy = swapWhy
                            if may and shots.copyOut(text) then
                                shots.clipStats.swapped =
                                    (shots.clipStats.swapped or 0) + 1
                                pcall(function()
                                    hs.alert.show("🔤 The words are on the clipboard "
                                        .. "— ⌘V pastes them · ⇪⇧5 then ⏎ puts the "
                                        .. "picture back", 3)
                                end)
                            elseif not may then
                                shots.clipStats.held =
                                    (shots.clipStats.held or 0) + 1
                            end
                        end)
                        if not okSwap then
                            -- 🔔 and it is SEEN, not swallowed: a swap that
                            -- went quiet on its own is 6.196.1's failure
                            -- inside the feature built to answer "why did
                            -- my words not land?"
                            shots.clipThrew = (shots.clipThrew or 0) + 1
                            shots.swapWhy = "the swap THREW — the naming and "
                                            .. "the log were not affected"
                            if type(core.degrade) == "function" then
                                pcall(core.degrade, "OCR clipboard",
                                      "the words were read and logged, but "
                                      .. "putting them on the clipboard threw "
                                      .. "— ⇪O has them")
                            end
                        end
                    else
                        shots.clipStats.off = (shots.clipStats.off or 0) + 1
                        shots.swapWhy = "settings = { screenshots = "
                                        .. "{ textToClipboard = false } }"
                    end
                    -- words were read, but a slug may be empty and a rename
                    -- may fail — neither is "no text", and only one is a name
                    if newPath then
                        why = "named"
                    else
                        why = "no name"
                        shots.ocrNoName = shots.ocrNoName + 1
                    end
                end
                if onDone then onDone(newPath, why) end
            end, { "run", shots.ocrShortcut, "-i", path })
            t:start()
        end)
        if not (okNew and t) then
            shots.ocrNotRun = shots.ocrNotRun + 1
            if onDone then onDone(nil, "not run") end
            return false
        end
        -- HELD — as a SET (6.155.0). One slot held only the newest task;
        -- a ⇪4 capture OCR'd while an arrival was being named dropped the
        -- earlier task to the collector, whose callback then never came,
        -- and a queue waiting on that callback would have waited forever.
        shots.nameTask = t
        shots.nameTasks[t] = true
        -- counted HERE, where a process really exists — not at the gate.
        -- nameByText can answer nil synchronously without spawning, and
        -- drainQueue re-enters itself on that path (6.229.0: count the
        -- thing that costs, not the thing that was asked for).
        shots.ocrStarted = shots.ocrStarted + 1
        return true
    end

    -- ⌘9 — the backlog. Serial ON PURPOSE: one `shortcuts` process at a
    -- time, so forty queued OCRs cost a quiet minute, not forty
    -- simultaneous processes.
    shots.nameBusy = false
    function shots.renameSweep()
        if not shots.ensureDir() then return end
        if shots.nameBusy then
            pcall(function()
                hs.alert.show("🏷 A naming sweep is already running", 2.5)
            end)
            return
        end
        local todo = {}
        pcall(function()
            for f in hs.fs.dir(shots.dir) do
                if #todo >= shots.sweepCap then break end
                if shots.wantsName(f) then
                    todo[#todo + 1] = shots.dir .. "/" .. f
                end
            end
        end)
        if #todo == 0 then
            pcall(function()
                hs.alert.show("🏷 Nothing to name — every screenshot here "
                              .. "already carries its words", 3)
            end)
            return
        end
        shots.nameBusy = true
        local renamed, silent, i = 0, 0, 0
        local function step()
            i = i + 1
            local path = todo[i]
            if not path then
                shots.nameBusy = false
                pcall(function()
                    hs.alert.show(("🏷 Named %d of %d — %d had no readable text")
                                  :format(renamed, #todo, silent), 4)
                end)
                say(("sweep: %d/%d renamed, %d text-free"):format(renamed, #todo, silent))
                shots.drainQueue()      -- arrivals that waited for the sweep
                return
            end
            local started = shots.nameByText(path, function(newPath, why)
                if newPath then
                    renamed = renamed + 1
                else
                    silent = silent + 1
                    -- 🔁 6.281.0 — ⌘9 is an INSTRUCTION and is never refused
                    -- (it does not ask mayTry), but what it learns still
                    -- counts: three silent OCRs is three silent OCRs,
                    -- whoever asked for them.
                    if why ~= "not run" then
                        shots.noteTried(shots.tried, shots.triedSeq, path,
                                        shots.triedKeep)
                    end
                end
                step()
            end)
            if not started then
                shots.nameBusy = false
                pcall(function()
                    hs.alert.show("🏷 OCR unavailable — needs the “"
                                  .. shots.ocrShortcut .. "” Shortcut", 4)
                end)
            end
        end
        pcall(function()
            hs.alert.show("🏷 Naming " .. #todo
                          .. " screenshots by their text…", 2.5)
        end)
        step()
    end

    -- ---- 👀 the folder watcher (6.155.0) ---------------------------------
    -- Another tool's capture, or a screenshot the other Mac took, lands
    -- in this folder with a mechanical name and no words. The watcher
    -- queues it for the same OCR a ⇪4 capture gets — after it has sat
    -- still for watchSettle (a file still being written OCRs as
    -- nothing), one shortcuts process at a time (the ⌘9 discipline,
    -- sharing its nameBusy flag), and never a file this module wrote
    -- itself (finish() names those) or one the blur editor has open (a
    -- rename under the editor would orphan its save).
    shots.watcher = nil    -- HELD: an unreferenced pathwatcher is collected
    shots.pending = {}     -- path -> settle timer (HELD, same reason)
    shots.queue   = {}     -- paths waiting for the one-at-a-time OCR
    shots.namedOnArrival = 0
    shots.leftForSweep   = 0

    local function editorHolds(path)
        local ed = _G.screenshotEditor
        return type(ed) == "table" and ed.currentPath == path
    end

    function shots.queueArrival(path)
        local size
        pcall(function() size = hs.fs.attributes(path, "size") end)
        if not size or size == 0 then return false end   -- gone, or empty
        local name = path:match("[^/]+$") or path
        if not shots.wantsName(name) then return false end   -- renamed meanwhile
        if shots.own[path] or editorHolds(path) then return false end
        -- 🔁 6.281.0 — the settled gate. onFolderEvent asks the same
        -- question earlier and more cheaply; this one is what COUNTS a
        -- refusal, because by here the file is real, still, and ours to
        -- have queued.
        local mayTry, whyTry = shots.triedVerdict(shots.tried[path], shots.triedMax)
        if not mayTry then
            shots.refusedTried = shots.refusedTried + 1
            shots.triedLast = (path:match("[^/]+$") or path)
                              .. " — " .. tostring(whyTry)
            return false
        end
        for _, q in ipairs(shots.queue) do if q == path then return false end end
        if #shots.queue >= shots.watchCap then
            shots.leftForSweep = shots.leftForSweep + 1
            if shots.leftForSweep == 1 then
                say(("%d arrivals already waiting — the rest are left for ⌘9")
                    :format(shots.watchCap))
            end
            return false
        end
        shots.queue[#shots.queue + 1] = path
        shots.drainQueue()
        return true
    end

    function shots.drainQueue()
        if shots.nameBusy then return end
        if #shots.queue == 0 then return end
        if _G.ocrShortcutAvailable == false then
            -- no OCR on this Mac: nothing to wait for, and ⌘9 will say so
            -- out loud when pressed — this path stays quiet after one line
            shots.leftForSweep = shots.leftForSweep + #shots.queue
            shots.queue = {}
            if not shots.saidNoOcr then
                shots.saidNoOcr = true
                say("arrivals not named — the “" .. shots.ocrShortcut
                    .. "” Shortcut is unavailable here")
            end
            return
        end
        local path = table.remove(shots.queue, 1)
        shots.nameBusy = true
        local started = shots.nameByText(path, function(newPath, why)
            shots.nameBusy = false
            if newPath then
                shots.namedOnArrival = shots.namedOnArrival + 1
                say("named on arrival: " .. (newPath:match("[^/]+$") or newPath))
            elseif why ~= "not run" then
                -- 🔁 6.281.0 — an OCR that ran and bought no name is the
                -- evidence. "not run" is not: see nameByText's two exits.
                shots.noteTried(shots.tried, shots.triedSeq, path, shots.triedKeep)
            end
            shots.drainQueue()
        end)
        if not started then
            shots.nameBusy = false
            shots.leftForSweep = shots.leftForSweep + #shots.queue
            shots.queue = {}
        end
    end

    function shots.onFolderEvent(paths)
        if not shots.watchFolder then return end
        for _, p in ipairs(type(paths) == "table" and paths or {}) do
            if type(p) == "string" and p:match("^(.*)/[^/]+$") == shots.dir then
                local name = p:match("[^/]+$") or ""
                if shots.wantsName(name) and not shots.own[p]
                   and shots.mayTry(p) then
                    -- "still" means no event for watchSettle: every write
                    -- restarts the clock
                    local old = shots.pending[p]
                    if old then pcall(function() old:stop() end) end
                    local okT, t = pcall(hs.timer.doAfter, shots.watchSettle, function()
                        shots.pending[p] = nil
                        pcall(shots.queueArrival, p)
                    end)
                    shots.pending[p] = (okT and t) or nil
                end
            end
        end
    end

    function shots.startWatch()
        if not shots.watchFolder then return false end
        if shots.watcher then return true end
        if not (hs.pathwatcher and hs.pathwatcher.new) then return false end
        local ok, w = pcall(hs.pathwatcher.new, shots.dir, function(paths)
            pcall(shots.onFolderEvent, paths)
        end)
        if not (ok and w) then
            warn("could not watch the folder — arrivals wait for ⌘9")
            return false
        end
        local okS = pcall(function() w:start() end)
        if not okS then
            warn("the folder watcher would not start — arrivals wait for ⌘9")
            return false
        end
        shots.watcher = w
        say("watching the folder — other tools' captures get their words as they land")
        return true
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

    -- ---- 🗂 the folder itself (6.130.0) -----------------------------------
    -- LL: "I feel like any screenshots should be captured here, by a line
    -- entry that sends me to that screenshot's folder"
    --
    -- 🚨 hs.task, NEVER hs.execute. hs.execute is SYNCHRONOUS and blocks
    -- the only thread Hammerspoon has — and this folder lives inside
    -- ~/Library/CloudStorage, where `open` on a directory OneDrive has not
    -- finished materialising can sit there for seconds. A Mac frozen
    -- keyboard-and-all is a far worse answer than a slow Finder window.
    -- Same rule, same reason, as the sync-osascript rule in hs-lint.
    function shots.revealFolder()
        local dir = shots.ensureDir()
        if not dir then return false end   -- ensureDir has already alerted
        local t
        local ok = pcall(function()
            t = hs.task.new("/usr/bin/open",
                            function() shots.openTask = nil end, { dir })
        end)
        if not (ok and t) then
            pcall(function() hs.alert.show("📸 Could not open the folder", 3) end)
            warn("hs.task.new failed for /usr/bin/open")
            return false
        end
        shots.openTask = t   -- HELD: an unreferenced hs.task is collected
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            shots.openTask = nil
            pcall(function() hs.alert.show("📸 Could not open the folder", 3) end)
            warn("/usr/bin/open would not start")
            return false
        end
        say("opened " .. dir .. " in Finder")
        return true
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
    function shots.actionRows(list)
        local qr = shots.zbarPath()
        -- 6.155.0 — the ⌘9 row says how many are WAITING, when the list
        -- is to hand: "nothing waiting" is the honest state most days now
        -- that arrivals are named as they land.
        local waiting = nil
        if type(list) == "table" then
            waiting = 0
            for _, e in ipairs(list) do
                if type(e) == "table" and shots.wantsName(e.name or "") then
                    waiting = waiting + 1
                end
            end
        end
        local nameSub
        if waiting == 0 then
            nameSub = "nothing waiting — every screenshot here carries its words"
        elseif waiting then
            nameSub = ("%d waiting — SCR-/word-less files get their text in the "
                       .. "name (%d per run, one at a time)"):format(waiting, shots.sweepCap)
        else
            nameSub = ("SCR-/word-less files get their text in the name "
                       .. "(%d per run, one at a time)"):format(shots.sweepCap)
        end
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
            -- 6.147.0 — ⌘9, the backlog namer. The ninth and last slot
            -- the chooser numbers natively.
            { text = "🏷 Name them by what's ON them", act = "nameSweep",
              subText = nameSub },
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
        elseif act == "nameSweep"  then shots.renameSweep()
        end
    end

    function shots.choicesFrom(list)
        local choices = {}
        for _, a in ipairs(shots.actionRows(list)) do choices[#choices + 1] = a end
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

    -- ---- 🔎 the search (6.88.0, and the whole folder since 6.122.0) ------
    -- One row per matching file, built from the FULL listing rather than
    -- the capped view. See the 🔎 block in the header for why that
    -- distinction is the fix rather than a detail.
    function shots.searchRow(e, why)
        return {
            text    = e.name,
            subText = os.date("%b %d %Y  %H:%M", e.mtime)
                      .. "  ·  " .. prettySize(e.size)
                      .. "  ·  " .. why
                      .. "  ·  ⏎ image · ⌘⏎ path · ⌥⏎ edit · ⌃⏎ jpg",
            path    = e.path,
        }
    end

    -- The name half. Every word must appear somewhere in the row, so
    -- "aug 13" and "13 aug" both work and neither matches everything.
    function shots.nameMatches(query, list)
        local words = {}
        for w in tostring(query or ""):lower():gmatch("%S+") do
            words[#words + 1] = w
        end
        local out = {}
        if #words == 0 then return out end
        for _, e in ipairs(list or {}) do
            local hay = (tostring(e.name or "") .. " "
                         .. os.date("%b %d %Y  %H:%M", e.mtime) .. " "
                         .. prettySize(e.size)):lower()
            local all = true
            for _, w in ipairs(words) do
                if not hay:find(w, 1, true) then all = false break end
            end
            if all then out[#out + 1] = e end
        end
        return out
    end

    -- 🚨 THE MERGE IS ORDERED, AND THE ORDER IS THE POINT. A file that
    -- matched its NAME is a file you half-remembered correctly; a file
    -- that matched only its indexed text is a guess that paid off. The
    -- first kind goes on top, and each row says which it was, because
    -- "matched the name" and "matched the text inside it" are different
    -- claims and blurring them would be guessing on your behalf.
    function shots.mergeResults(named, spotlight, list)
        local out, seen = {}, {}
        for _, e in ipairs(named or {}) do
            if not seen[e.path] then
                seen[e.path] = true
                out[#out + 1] = shots.searchRow(e, "name")
            end
        end
        local byPath = {}
        for _, e in ipairs(list or {}) do byPath[e.path] = e end
        for _, p in ipairs(spotlight or {}) do
            local e = byPath[p]
            -- ⚠️ A SPOTLIGHT HIT THAT IS NOT IN THE LISTING IS DROPPED.
            -- mdfind answers about the folder as the INDEX last saw it;
            -- a file deleted since would otherwise be offered as a row
            -- that opens nothing.
            if e and not seen[p] then
                seen[p] = true
                out[#out + 1] = shots.searchRow(e, "text inside it")
            end
        end
        return out
    end

    -- Thumbnails for what will actually be drawn, and no further: each one
    -- decodes a whole PNG. This is why searchMax exists.
    function shots.withThumbs(rows, list)
        local byPath = {}
        for _, e in ipairs(list or {}) do byPath[e.path] = e end
        local out = {}
        for i, r in ipairs(rows) do
            if i > shots.searchMax then break end
            if r.path and byPath[r.path] then r.image = thumbFor(byPath[r.path]) end
            out[#out + 1] = r
        end
        return out
    end

    function shots.noMatchRow(query, spotlightRan)
        return {
            text    = "No screenshots match “" .. query .. "”",
            -- ☁️ Honest about what was actually asked. "Nothing matched"
            -- and "nothing matched and Spotlight never answered" are not
            -- the same result, and this folder is in OneDrive where the
            -- second is a real possibility.
            subText = spotlightRan
                      and "Names, dates and indexed text all searched · ⌫ clears it"
                      or  "Names and dates searched — Spotlight had no answer · ⌫ clears it",
        }
    end

    -- The synchronous half: runs on every keystroke, never spawns
    -- anything, and is what you actually see while you are still typing.
    function shots.filterChoices(query)
        query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then return shots.allChoices or {} end
        local list = shots.fullList or {}
        local rows = shots.mergeResults(shots.nameMatches(query, list),
                                        shots.spotlightFor(query), list)
        if #rows == 0 then
            return { shots.noMatchRow(query, shots.spotlightQuery == query) }
        end
        return shots.withThumbs(rows, list)
    end

    -- ---- the Spotlight half ---------------------------------------------
    -- Cached per query so the synchronous filter above can read the last
    -- answer without waiting, and so a re-render on the same query does
    -- not spawn a second mdfind.
    shots.spotlightQuery   = nil
    shots.spotlightResults = nil
    shots.findTask  = nil   -- HELD: an unreferenced hs.task is collected
    shots.findTimer = nil   -- HELD: ditto an hs.timer

    function shots.spotlightFor(query)
        if shots.spotlightQuery == query then return shots.spotlightResults end
        return nil
    end

    function shots.parseMdfind(out)
        local paths = {}
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local p = line:gsub("^%s+", ""):gsub("%s+$", "")
            if p ~= "" and p:sub(1, 1) == "/" then paths[#paths + 1] = p end
        end
        return paths
    end

    function shots.stopFind()
        if shots.findTimer then pcall(function() shots.findTimer:stop() end) end
        shots.findTimer = nil
        if shots.findTask then pcall(function() shots.findTask:terminate() end) end
        shots.findTask = nil
    end

    -- Debounced: the timer is re-armed on every keystroke, so mdfind is
    -- spawned once you stop typing rather than once per character.
    function shots.startFind(query, onDone)
        shots.stopFind()
        if query == "" then return false end
        local ok = pcall(function()
            shots.findTimer = hs.timer.doAfter(shots.findDelay, function()
                shots.findTimer = nil
                local started = pcall(function()
                    shots.findTask = hs.task.new(shots.MDFIND, function(_, sout)
                        shots.findTask = nil
                        -- 🚨 AN ANSWER TO A QUESTION YOU HAVE FINISHED
                        -- ASKING IS NOT AN ANSWER. Two keystrokes land
                        -- while mdfind is running; showing its result
                        -- would replace the list under the query you are
                        -- now typing.
                        if shots.liveQuery ~= query then return end
                        shots.spotlightQuery   = query
                        shots.spotlightResults = shots.parseMdfind(sout)
                        if onDone then pcall(onDone, query) end
                    end, { "-onlyin", shots.dir, query })
                    if shots.findTask then shots.findTask:start() end
                end)
                if not started then
                    shots.findTask = nil
                    -- Spotlight being unavailable costs the text half and
                    -- nothing else — the name search already answered.
                    say("mdfind unavailable — searching names only")
                end
            end)
        end)
        return ok and shots.findTimer ~= nil
    end

    -- Every keystroke: draw the name matches NOW, and ask Spotlight for
    -- the rest. The redraw when mdfind answers goes through the same
    -- filterChoices, so there is one place that decides what a row says.
    function shots.onQuery(q)
        local query = tostring(q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        shots.liveQuery = query
        if query == "" then
            shots.stopFind()
            pcall(function() shots.chooser:choices(shots.allChoices or {}) end)
            return
        end
        pcall(function() shots.chooser:choices(shots.filterChoices(query)) end)
        shots.startFind(query, function(answered)
            -- Checked again here as well as inside the task callback: the
            -- redraw is the thing with a visible cost, and two guards on
            -- the same race is cheaper than one race that gets through.
            if shots.liveQuery ~= answered then return end
            pcall(function() shots.chooser:choices(shots.filterChoices(answered)) end)
        end)
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
                    "Type to search screenshots · ⌘1–⌘9 actions")
            end)
            pcall(function()
                shots.chooser:queryChangedCallback(function(q)
                    -- per-keystroke callback: guarded like an eventtap —
                    -- an error in here would repeat on every character
                    pcall(function() shots.onQuery(q) end)
                end)
            end)
        end
        shots.liveQuery = ""
        shots.stopFind()
        local list = shots.list()
        shots.fullList = list          -- what the SEARCH works over: all of it
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
        shots.allChoices = choices   -- the IDLE view: actions + the newest few
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
    -- 👀 The watcher starts at boot ONLY if the folder is already there —
    -- one stat, no mkdir, no alert; ensureDir() starts it on first use
    -- otherwise. (The hostile Mac with no OneDrive boots without it.)
    if shots.enabled and shots.watchFolder then
        local mode
        pcall(function() mode = hs.fs.attributes(shots.dir, "mode") end)
        if mode == "directory" then shots.startWatch() end
    end
    if shots.enabled then
        core.hyperAddShortcut({}, shots.key, function() shots.capture() end,
                              "screenshot — save + copy")
        -- 📸 6.194.0 — one bind per row of shots.toolKeys. A row whose act
        -- runAction does not know would be a key that does nothing, so the
        -- gate joins this table against runAction's own branches and fails
        -- on either side — the 6.114.0 ⇪⇧R lesson, applied to keys.
        for _, t in ipairs(shots.toolKeys or {}) do
            local mods, key, act, label = t[1], t[2], t[3], t[4]
            core.hyperAddShortcut(mods, key, function()
                shots.runAction(act)
            end, label)
        end
        core.hyperAddShortcut({ "shift" }, shots.panelKey, function() shots.show() end,
                              "screenshot panel")
    end

    -- screenshots.latest is what the Task Form's 📸 button calls — one
    -- keystroke from "capture" to "attached to a task".
    -- 6.120.0 — WHERE zbarimg IS, published rather than copied. ⇪⇧` reads
    -- QR codes off the screen and needs the same decoder this module
    -- already hunts for. A second copy of the five candidate paths in
    -- another file is a list that drifts: Homebrew moves, a new
    -- no-admin install location gets added here, and the other copy goes
    -- on looking in the old places and reporting "no decoder installed"
    -- on a Mac that has one. One list, one owner, asked for by name.
    core.provide("shots.zbarPath",      function() return shots.zbarPath() end)
    core.provide("screenshots.latest",  function() return shots.latest() end)
    core.provide("screenshots.capture", function() return shots.capture() end)
    core.provide("screenshots.captureAreaTo", function(cb) return shots.captureAreaTo(cb) end)
    core.provide("screenshots.captureScreenTo",
                 function(delay, cb) return shots.captureScreenTo(delay, cb) end)
    core.provide("screenshots.show",    function() return shots.show() end)
    -- 6.258.0 — this module owns the folder, so it answers "what is in it";
    -- the editor's ⌘O asks rather than listing the folder a second time.
    core.provide("screenshots.list",    function() return shots.list() end)
    core.provide("screenshots.folder",  function() return shots.revealFolder() end)

    -- 🗂 6.130.0 — IN THE EDITOR PICKER (⌃⌃), and it is the odd row there
    -- on purpose. Every other entry on that roster opens a TEXT surface;
    -- this one opens a FOLDER, because that is the ask — one line that
    -- puts you where the captures are, from the same list you already
    -- reach for when you want something you saved earlier.
    --
    -- ⏱ size() SCANS THE DIRECTORY, which is a real cost on a OneDrive
    -- folder with hundreds of files in it. Accepted for exactly the reason
    -- the OCR entry accepts its disk read: the picker only ever opens on a
    -- deliberate gesture, never on a timer and never at boot.
    --
    -- No `view` (there is no window of ours to raise), and no `text` — a
    -- folder has nothing for ⌥⏎ to copy, and saying so by omission is what
    -- makes the picker print "has no text to copy" instead of putting an
    -- empty string on the clipboard over something you wanted.
    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "Screenshots",
        key   = "⇪4 / ⇪⇧4",
        what  = "⏎ opens the folder in Finder",
        order = 70,
        unit  = "captures",
        size  = function() return #shots.list() end,
        show  = function() shots.revealFolder() end,
        -- 💾 6.130.0 — and it is IN the one-file CSV export too. A row in
        -- the picker that contributes no column to the spreadsheet is a
        -- hole exactly where somebody would go looking. The text cell is
        -- the full path, so it can be pasted straight into Go-to-Folder.
        csv   = function()
            local out = {}
            for _, f in ipairs(shots.list()) do
                out[#out + 1] = {
                    when  = os.date("%Y-%m-%d %H:%M:%S", f.mtime),
                    label = string.format("%.0f KB", (f.size or 0) / 1024),
                    text  = f.path,
                }
            end
            return out
        end,
    })

    _G.screenshots = shots
    M.shots  = shots
    M.config = shots
end

return M
