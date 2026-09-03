# Hammerspoon config — changelog

Full version history for `init.lua`. The five most recent entries are
also kept inline at the top of the file; everything older lives only here.

```text
NEW IN 6.157.0 — THE PREVIEW PANE, ON EVERY PICKER THAT HOLDS TEXT:
  👁 LL, with ⇪O open: "I need a preview window for the relevant pickers
     like hyper+o. Can we correct all the picker tools that don't have
     one?" Forty-odd pickers were read for this. The pane (6.154.0's,
     beside ⇪V) used to need the picker to FILTER FOR ITSELF, so the
     rows the pane read were the rows on screen — which is why only ⇪V,
     ⇪⇧V and ⇪⇧T had one. hs.chooser answers that question directly:
     selectedRowContents(r) is the r-th row of whatever list the chooser
     is showing, its own filter included, so the pane now asks the
     chooser when no rows function was handed over. Wiring a picker up
     is three lines: a rawText on each row (and, if it likes, a head
     line or a `when`), a suspend when the picker hides, an open after
     it shows. The mouse row that turns out to be past the end of a
     filtered list falls back to the keyboard's row; a row with neither
     head nor when is headed by its size alone.
     WIRED, and what each shows: ⇪O and ⇪⇧O — the OCR text whole, with
     its moment (⇪O's rows always carried it: ⏎ copies it); ⇪H — the
     command, whole; ⇪⇧N — the LAST LINES of that notes file, read from
     the tail (one seek, 4 KB, never the 40 MB log); ⌃⌥⇧F — the file
     event with every field on its own line; ⇪Y — the whole title and
     the WHOLE url, headed by when · profile · visits and "from the
     archive" when it is; ⇪⇧' tab search — title and url whole, with
     window and tab; ⇪8 define — a sense's whole gloss; ⇪⇧W / ⇪⇧E — the
     document name whole, then date · app · time; ⌘⌥⇧0 activity —
     "app — title" whole, time, url; ⇪L — the task's whole name, its due
     line and its link (select mode included).
     LEFT ALONE, on purpose: pickers whose rows ARE the whole story —
     the action lists (⇪6 network, ⇪⇧4 actions, power tools, universal
     actions, the editor picker), app and window lists (⇪⇧A, ⌥-jump,
     app kill, default apps, menu bar, menu search, settings panes,
     Asana team, update tracker), the cheat sheet's two editors, bulk
     rename, and the ⇪⇧4 history rows, whose thumbnails already are the
     preview — and ⇪I, which is a page of its own, not a chooser. The
     Task Creator keeps its own mirror panel.
  ✅ Gate: 6,486 → 6,518 checks (test_clipboard 99 → 103;
     test_chrome_history 130 → 134; test_tab_search 65 → 69;
     test_file_tracker 35 → 38; test_define 129 → 133; test_select_mode
     43 → 47; test_features 447 → 456), 67 stages, lint and the hostile
     world green, in the tree and inside the package. The zip still
     carries no snippets/ (see 6.155.0).

NEW IN 6.156.1 — THE CHEAT SHEET, 20% LESS SEE-THROUGH:
  🪟 ⇪/ — LL: "Can we make the cheat sheet window less translucent by
     about 20%?" One knob, one number: cheatSheet.alpha in
     core/cheatsheet.lua goes 0.75 → 0.90 (0.75 × 1.2 — "20% less
     see-through" read as 20% more opaque, which is the change you can
     actually see; 0.80 would have been the arithmetic on the
     translucency and invisible in practice). The window behind the sheet
     is a hint now rather than a distraction, and the white text on the
     near-black panel reads better for it. The other canvas panels keep
     §1.5's panelAlpha; nothing else changed. test_cheatsheet's
     readability pin moved with it (the panel's alpha must equal the
     knob and sit inside 0.6–0.95).
  ✅ Gate: 6,485 → 6,486 checks (test_cheatsheet 185 → 186: one pin
     became two), 67 stages, lint and the hostile world green, in the
     tree and inside the package. The zip still carries no snippets/
     (see 6.155.0).

NEW IN 6.156.0 — ⇪Y WITHOUT THE LOGINS · ⇪⇧T SHOWS WHAT IS IN IT · ⇪L
DELETES · THE ⌘-DRAG THAT DID NOTHING · ⌥TAB'S PHASES:
  🙈 ⇪Y — LL: "Can you remove entries that are just logins? I don't need
     those." A page whose URL contains one of chrome.loginPatterns
     (login.live.com, accounts.google.com, /login, /signin, /oauth, /sso/,
     wsignin, okta, microsoftonline…, plain text, case-insensitive) or
     whose TITLE starts like a login page ("Sign in", "Log in", "Login |",
     "Verify it's you"…) is left out of the picker — and only the
     picker: the archive keeps every row, so chrome.hideLogins = false
     brings them back without an export. A page ABOUT logins is not a
     login (the wiki titled "Login procedures" stays); the placeholder
     counts what is hidden ("· 3 logins hidden"). Judged once per
     archive (cached on the entries table), not per keystroke.
  📜 ⇪Y — "can you show more than nine cmd+{number}? I'd like a
     scrollable list of at least 30 days." ⌘1–⌘9 are macOS's own row
     shortcuts and stop at nine; what was short was the LIST: the empty
     box held the newest 40 pages. It now holds everything from the last
     chrome.listDays (30) — never fewer than showRows, never more than
     chrome.listMax (3,000; hs.chooser scrolls) — and the picker stands
     sixteen rows tall (chrome.pickerRows). A typed search still returns
     the best forty.
  👁 ⇪⇧T — "To the right of the snippets panel can you show what is in
     the snippet collection? If I select one, nothing seems to happen. I
     can't remember what is in the collection if I can't see it." Two
     answers. The ⇪V preview pane is a SERVICE now (preview.open /
     suspend / close, published by clipboard_history; a row may bring
     its own head line) and the snippet picker uses it: a snippet row
     shows its WHOLE text with the trigger and collection above it, a
     collection heading lists every snippet in it — trigger and name,
     one per line — and the on/off row shows nothing. And ⏎ on a heading
     is no longer inert: the picker re-opens on that collection alone,
     with a "◂ All snippets" row on top to come back (a beat later, on a
     held timer — hs.chooser is mid-dismiss inside its own callback).
     For the pane to follow, the rows on screen must be rows this module
     knows, so the FILTERING moved here: every typed word must appear in
     the name, the trigger, the collection or the snippet's TEXT (the
     body was never searchable before), name and trigger hits first,
     headings and the on/off row stepping aside while a query is up.
  🗑 ⇪L (⌃⌥⌘L) — "Can we use the Asana hyper+L to also select and delete
     tasks in bulk or one line?" The picker grew the clipboard editor's
     select mode: "☑️ Select several to delete…" switches it on, ⏎ then
     TAGS rows (✓) and the picker re-opens with the tags kept, and
     "🗑 Delete N selected tasks" does the deed. One line: ⌥⏎ on any row
     deletes just that task. Both ASK FIRST — a dialog naming the tasks
     — and the request is DELETE /tasks/{gid}, one at a time, with the
     token in the header (never a process argument; the sentry pins
     it). Asana keeps a deleted task in Deleted Items for 30 days; the
     dialog says so. The list refreshes itself afterwards.
  🧲 ⌘-DRAG — "Holding ⌘ and drag from anywhere, from/to anywhere
     doesn't seem to work. And using ⌘shift+arrowkey does seem to work.
     Am I using the ⌘ drag movement wrong? Guess if you can't tell me."
     The guess, with the code in front of me: the nudge keys touch none
     of the drag engine, so the engine is the suspect, and it had one
     way to fail silently. Every tick it asked checkMouseButtons()
     whether the button was still down and ended the drag the first
     time it said no. That answer comes from the event system — and the
     mouse-DOWN that starts a picker drag is the one event the module
     CONSUMES (so a ⌘-click on a row does not also pick the row). A
     consumed press that never updates the session's button state reads
     as "released" on the very first tick, and the drag ends before it
     moves anything, with no line anywhere. The pad's header drag never
     consumed its press, which is why one could work and the other not.
     So the events drive the drag now: a tap on leftMouseDragged and
     leftMouseUp carries it (the HID keeps sending dragged events while
     the button is physically down, whatever the session state says),
     the mouse-up ends it, the tap never consumes anything, and the
     button poll is used only when that tap cannot be made. Every drag
     is written down — engine, moves, how it ended — and
     _G.windowMoveReport() prints the record; a drag that ended before
     it moved anything says so in the Console. If it STILL does not
     move, that Console line plus the report's "last drag" line is the
     whole diagnosis — paste them.
  ⏱ ⌥TAB — "listing took 1.64s across 13 apps (slowest: Alfred
     Preferences 0.00s · memory: 0 probed in 0.00s)", twice. Thirteen
     apps at 0.00s and no probes cannot add up to 1.64s, so the time was
     in a phase nothing measured. The likeliest: the OWNERS pass, which
     asked every listed window for its application() and then name() —
     two AX round trips each, outside every timer. It asks nothing now:
     the sweep already knows which app it asked, the memory remembered
     its name, the console is Hammerspoon, and every entry arrives
     carrying it. And every phase is timed — zorder, apps, sweep,
     console, memory, owners, sort, app-only, tail — so the slow line
     ends "· slowest phase: owners 1.52s" and the next paste is an
     answer. _G.altTabLastListing.phases has the numbers.
  🎯 "Dialog Home: Preview didn't accept an Accessibility watcher" — not
     bad. Some apps refuse an AX observer (Preview, Finder, VLC, Archive
     Utility do); Dialog Home says so once per app per session and
     simply does not home THAT app's dialogs. Nothing else is affected.
  ✅ Gate: 6,432 → 6,485 checks (test_chrome_history 119 → 130;
     test_expander 225 → 240; test_window_move 88 → 101; test_switcher
     181 → 185; test_clipboard 95 → 99; test_select_mode 37 → 43), 67
     stages, lint and the hostile world green, in the tree and inside
     the package. The zip still carries no snippets/ (see 6.155.0).

NEW IN 6.155.0 — WORDS ON EVERY SCREENSHOT · THE PANE RIDES A MOVED
PICKER · TWO CONSOLE LINES ANSWERED:
  🏷 ⇪⇧4 — LL, looking at the panel: "Can you see some of the screenshots
     have OCR'd thumbnails and others don't have words in the title? Is
     there a better way we can put words in the title along with the
     other information?" The row without words was SCR-20260902-rkdn.png
     — another capture tool's name — and 6.147.0's naming reached only
     the captures THIS module took (finish() OCRs those a few seconds
     after the shutter) plus whatever ⌘9 was pressed for. The folder is
     WATCHED now (hs.pathwatcher, started at boot when the folder exists
     and otherwise on first use): a mechanical, word-less arrival — an
     SCR- file, or a "Screenshot …" that the other Mac took and OneDrive
     brought over — waits until it has sat still for shots.watchSettle
     (2.5s; every write restarts the clock, so a half-written PNG is
     never OCR'd as nothing), then goes through the same nameByText the
     ⇪4 path uses and becomes "Screenshot <its own moment> — <its
     words>.png", one shortcuts process at a time under ⌘9's nameBusy
     discipline. Never touched: a file this module wrote itself (every
     path it creates is registered in shots.own — finish() names those,
     and the editor-bound ones are the editor's), a file the blur editor
     has open (_G.screenshotEditor.currentPath), a name a person chose,
     a name that already carries " — ". Beyond shots.watchCap (20) the
     rest are left for ⌘9 rather than piled up behind a OneDrive
     re-sync, and the ⌘9 row now says "N waiting" or "nothing waiting —
     every screenshot here carries its words". A one-slot task holder
     became a SET on the way: a ⇪4 OCR landing while an arrival was
     being named would have dropped the earlier task to the collector,
     and the queue would have waited for a callback that never came.
  🧲 ⇪V — LL: "On the screenshot that shows the Clipboard History panel,
     I can't move it. Should I be able to?" Yes, and it has been movable
     since 6.30/6.127.0: hold ⌘ and drag from ANYWHERE on it (a bare
     drag on the rows runs one — that is the row's job), or ⇪⇧-arrows
     nudge it, ⇪⇧R puts it back, and the spot sticks for the next picker
     you open. What did NOT survive a move was 6.154.0's preview pane: a
     nudge is hide() + show(point), the picker's hideCallback closed the
     pane AND stopped its poll, and nothing re-opened it because the
     re-show goes through core.showPopup, not this module's openers. The
     hideCallback now only SUSPENDS — the canvas goes at once (a pane
     over empty desk is wrong for as long as it lasts), the poll stays —
     and the pane closes for good only after the picker has been gone
     for clip.previewGrace (0.6s); a picker back inside that, at a new
     placement, gets its pane back THERE on the next tick. A ⌘-drag never
     hides the picker (show(point) re-anchors it live), and window_move
     now moves the placement record WITH the hand instead of at the
     drop, so the pane rides along at the poll's cadence.
  🏷 "⚠️ OCR tag: clipboard file URL(s) matched no usable image — a
     file-reference path macOS would not resolve — raw value:
     "/.file/id=6571367.22263352/"" — printed as LL ⌘C'd the unpacked
     6.154.0 FOLDER to install it. A folder copied in Finder arrives by
     reference exactly like an image does, realpath declined it, and
     6.98.0's rule ("an unresolvable reference is an anomaly worth one
     line") had no way to tell the two apart. It asks now: when neither
     route can NAME the reference, the filesystem is asked what it IS,
     and a directory is a normal miss — silent, like every other
     non-image ⌘C. A file nobody can name still gets its line, and the
     line says the filesystem calls it a file. The second route is new:
     CoreFoundation resolves file reference URLs itself (that is what
     they exist for) and hs.fs.pathFromURL hands the answer back on the
     builds that have it, asked only when realpath came up empty, and
     an answer that merely echoes the reference counts as none.
  🖱 "⚠️ mouseGrid: watchdog fired after 8s — landed badge left open" —
     the line that follows every ⇪X landing that is used with the
     TRACKPAD instead of the space bar, which 6.154.0's snap-to-control
     makes the natural thing to do: the pointer is already on the
     button. A mouse-down tap now runs ONLY while landed; the click is
     never consumed (the badge is click-through — hs.canvas ignores the
     mouse unless asked to track it, and the ring's middle is
     transparent anyway), the teardown is deferred one event-loop turn
     so it never happens inside the tap's own callback, and the tap is
     pcall'd end to end — no Accessibility, no tap, the watchdog alone
     as before. grid.clickEnds = false turns it off.
  ✅ Gate: 6,383 → 6,432 checks (test_screenshots 134 → 155;
     test_mouse_grid 326 → 339; test_ocr_tag 51 → 60; test_clipboard
     89 → 95), 67 stages, lint and the hostile world green, in the tree
     and inside the package.
  📦 THIS ZIP CARRIES NO snippets/ FOLDER — deliberately said out loud.
     snippets/ is never in git (it holds real personal data) and the
     build machine behind this session was rebuilt between 6.154.0 and
     6.155.0, so there was no bundled.lua to pack. That is safe by the
     installer's own rule: hs-install.sh touches ~/.hammerspoon/snippets
     ONLY when the download has a snippets/ folder, so the bundled.lua
     6.154.0 installed stays exactly where it is and ⇪⇧T keeps all 2,006
     snippets. The next snippets CHANGE needs the packs handed back
     (a zip of ~/.hammerspoon/snippets) before it can be built.

NEW IN 6.154.0 — SEVEN ASKS: ⇪V SHOWS THE WHOLE ENTRY · ⇪X LANDS ON THE
BUTTON · ⌥TAB IS A ROLODEX · ⇪6 GROWS A REPORT · ⇪Y REACHES 180 DAYS:
  👁 ⇪V / ⇪⇧V — LL: "Can the full contents of the clipboard item in cmd+V
     be shown as I arrow up/down, or put my mouse cursor on an item? The
     view should show to the right of the window and be able to scroll
     or automatically expand to show that entry." A pane beside the
     picker — to the right when it fits, else the left — shows the WHOLE
     entry of the row the arrows or the mouse are on, in Menlo, growing
     to the screen's bottom edge ("automatically expand") and ending in
     an honest "… N more lines — ⏎ copies all of it" when it must, never
     clipped mid-word. hs.chooser has no selection-changed callback and
     does NOT follow the mouse (HSChooser.m was read, not assumed), so
     ONE poll that runs only while a picker is up reads selectedRow()
     for the keyboard and computes the row under the pointer from the
     picker's box — the placement record plus window_move's row
     constants, since macOS gives a chooser no frame getter. The mouse
     wins inside the picker, the keyboard elsewhere; the hover maths
     assumes the list is unscrolled (there is no scroll getter). The
     picker's hideCallback closes the pane; the poll closes it too when
     the picker is simply gone. Click-through, on a new ladder rung
     (clippreview = 4, beside and above the chooser). clip.previewOn =
     false is the old list alone. Both openers keep their own
     core.showPopup line — test_integration counts one per picker.
  🎯 ⇪X — LL: "If the grid letters are close to a dialog box or tab, can
     we jump the cursor on top of that button? But, only if that button
     or field is within the box that I select by typing two letters and
     then the third of course would jump to that element." On the
     header's own terms — no accessibility-tree walk — the third letter
     now HIT-TESTS the cell: the centre first, then its four quarter
     points, at most five AX questions each with setTimeout, all under
     grid.snapBudget (80ms), and the centre alone when it already
     answers with a control. A control (grid.snapRoles: buttons, fields,
     checkboxes, radio buttons — macOS tabs — pop-ups, links, menu
     items…) whose CENTRE lies inside the cell wins, the nearest to the
     cell's centre if several; the pointer lands ON it and the landed
     badge names it ("🎯 Save · space click · ⎋ done"). The overlay is
     hidden BEFORE the question is asked (or our own scrim answers), and
     Hammerspoon's own pid is ignored as a belt to those braces. No
     Accessibility, an Electron app that answers nothing, a paragraph
     under the cell, a control merely overlapping it, a spent budget, an
     AX layer that throws: the cell-centre jump exactly as before — the
     failure mode is "no snap", never "no jump". ⇪⇧X clicks what it
     snapped onto. _G.mouseGridReport() grew a snap line.
  🗂 ⌥TAB — LL: "Can you make Opt+Tab like a rolladex of tiles?" The
     front card large and centred (320×200), neighbours receding either
     side — scaled by 0.8 per step, fainter, overlapped — drawn far to
     near so the centre paints on top; Tab turns the wheel, ← → one
     card, ↑ ↓ five (clamped: a big step that wrapped would be a guess),
     Home/End the ends, and past the last card is the first. Three
     things the tile wall could not do fall out of it: EVERY window is
     on the wheel (the wall drew what the screen held and admitted the
     rest in a footer); snapshots are taken LAZILY as cards come round —
     the visible seven on the press, one more per turn — not one per
     window on the keypress you are waiting on; and a narrow screen
     shows fewer side cards rather than overflowing. The caption reads
     "i / n · App — title". altTab.layout = "grid" is the 6.34.0 wall,
     unchanged, and the suite's geometry pins run against it; §15 pins
     the rolodex. (One %d on a float width found by the suite: the
     wheel's width is cardW × a fraction, and %d raises in Lua 5.4.)
  🩺 ⇪6 — LL: "can we use the command line to run multiple commands and
     build a report that tells us what is going on", "a picker that
     describes and then executes the commands", and "something that
     when run it cleans our network connections … But, we must be very
     safe. I do not want to disable or kill or cause conflicts with my
     network configs." 🩺 NETWORK REPORT: fourteen READ-ONLY questions in
     ONE /bin/sh run — ports, the IP per interface, the Wi-Fi network,
     the default router, the resolvers, three pings to the router and
     three to 1.1.1.1 (the internet with no DNS in the way), a timed
     lookup, the same lookup raced against 1.1.1.1 · 8.8.8.8 · 9.9.9.9,
     the public IP asked of OpenDNS BY DNS (no web page), Apple's
     captive-portal check, tunnels and VPN configurations, the routing
     table, the ARP cache. Every binary ships with macOS and reaches the
     script as a positional argument; every wait is bounded in its
     arguments (ping -c/-i/-t, dig +time/+tries, curl -m) under a 60s
     deadline. The Lua side parses the facts and reasons TOP DOWN, so
     the VERDICT names the FIRST broken link — no IP, no router, router
     silent (LOCAL), router fine but 1.1.1.1 silent (the ISP), pings
     fine but names fail (DNS — flush, or set 1.1.1.1), slow DNS with
     its number, a non-200 from captive.apple.com (a portal — open a
     browser), a connected VPN named — or one ✅ line with the numbers.
     WHAT WOULD HELP is by hand: the race's winner and where in System
     Settings to set it; this tool never changes network settings
     itself. Saved to Logs/net_report-<Mac>.txt, whole thing on the
     clipboard, verdict first. 🧹 REFRESH & VERIFY (SAFE) is the same
     script with the flush in front — exactly the two lines Flush DNS
     has run since 6.120.0, each half reported honestly (the
     mDNSResponder half needs admin; on the work Mac the report says so
     and that nothing else was touched). What "safe" means, pinned by
     name in the suite: no setairportpower, no setdnsservers, no route
     flush/add/delete, no arp -d, no sudo, no pkill/kill -9, no ipconfig
     set/renew, no ifconfig up/down, no launchctl — and the one signal
     it can send (-HUP to mDNSResponder) sits inside the refresh branch
     only. Eight more rows, each describing itself: ⏱ dig with timing
     (which server, how many ms), 🏁 DNS race (yours vs the public three,
     fastest first), 🔌 interfaces & addresses, 🏠 devices on this network
     (arp -a), 🌍 public IP (copied), and 🚀 speed test — the ONE optional
     tool, the way ⇪8's WordNet is: speedtest-cli under ~/homebrew,
     /opt/homebrew or /usr/local when Homebrew has it (LL runs Homebrew
     from his home directory on the work Mac), --simple, a 120s
     deadline; absent, the row says so and ⏎ copies the install command.
     test_diagnostics's reviewed-binary list grew the eight read-only
     binaries and net_tools joined the brew carve-out on define's terms.
  🗄 ⇪Y — LL: "Without bogging down Hammerspoon, Chrome, my MacBook
     overall, can we use our Chrome history search to go as far back in
     time as possible but not past 180 days?" Chrome itself deletes
     history at 90 days, so no export can hand back more — the second 90
     come from the ARCHIVE this module already keeps: chrome.mergeArchive
     carries forward rows from the previous save that the fresh export
     no longer contains (Chrome dropped them, or the per-profile cap cut
     them), keyed on the URL (Chrome's own key; a URL the export DID
     return wins with its newer visit count), inside chrome.days = 180,
     newest first, capped at chrome.maxTotal = 60,000 so neither the CSV
     nor the per-keystroke search grows without bound — "without
     bogging down" was the other half of the ask. loadCsv prunes past
     the window and caps too, so lowering chrome.days shortens the
     archive. The status line says "N kept from the archive"; the
     placeholder and cheat sheet say 180. The test suite's exact-count
     sections now start from an empty archive, since an export merges.
  💾 LL: "Is this a problem? … recent_docs-Lees-MacBook-Air.csv has
     SHRUNK — 49.7 KB at boot, 48.8 KB now. That is either a rotation or
     a truncation, and only one of them is fine." Neither: that file is
     the ⇪I CACHE, rewritten whole after every Spotlight scan, and it
     shrinks whenever a document ages out of the 30-day window. The
     write ledger's shrink rule was written for append-only logs and did
     not know the difference. It does now, three ways: a registry
     (_G.rewrittenFiles[path] = why — recent_docs, clipboard_history,
     chrome_history and the net report register themselves, and a
     later-loading module can use the writeLedger.rewritten service),
     .json by nature (a JSON array cannot be appended to), and name
     patterns for the caches that predate the registry (the OCR log
     after a ⇪⇧O delete, the update tracker). For those a smaller file
     is silent and the report says "rewritten — normal"; losing MORE
     THAN HALF is still reported, once, because a cache rewritten as
     nearly nothing is the clipboard-history P4 disaster under another
     name.
  👻 POMODORO — LL: "Can you fade both the Pomodoro focus box and the
     time instead of being solid white also? Both need to be more
     translucent." "Solid" had three causes, so three knobs: the whole
     card rose to 90% for the last five minutes (pom.alphaAlert, now
     75% — never solid), the card's fill was the shared 92% background
     (pom.cardAlpha = 0.78 of that — a COPY; the shared style table is
     untouched, test_style's identity pins hold), and the digits were
     97% white (pom.inkAlpha = 0.80 of that). The FLASH keeps its full
     colours: an alert nobody can see is no alert.
  ✅ Gate: 6,228 → 6,383 checks (test_switcher 160 → 181; test_mouse_grid
     296 → 326; test_clipboard 65 → 89; test_net_tools 66 → 115;
     test_write_ledger 65 → 75; test_chrome_history 110 → 119;
     test_tools 110 → 114; test_diagnostics 431 → 439), 67 stages, lint
     and the hostile world green, in the tree and inside the package.

NEW IN 6.153.0 — ⌥TAB'S HIDDEN 1.5 SECONDS · THE ⇪T WINDOW GROWS UP ·
⇪Y LEARNS TO COPY:
  🐢 LL: "Opt+Tab is very slow", with the Console line that could not
     explain itself: "🔄 Window switcher: listing took 1.64s across 13
     apps (slowest: NordVPN 0.01s)" — and 1.58s the next press,
     slowest Sublime Text, also 0.01s. Thirteen fast apps cannot add
     up to 1.64 seconds, so the missing ~1.5s had to be inside the
     measured region but outside the per-app timers: phase 2, the
     6.152.0 MEMORY, re-proving every remembered window the sweep no
     longer sees. Each re-proof was TWO synchronous AX round-trips
     (role, then isMinimized), per window, per press, unbudgeted —
     press ⌥Tab on a couple of desktops and the memory holds enough
     windows to burn a second and a half every single press.
  ⏱ THE FIX IS THE SWEEP'S OWN MEDICINE: altTab.probeBudget (0.25s),
     checked before each probe, least-recently-verified first. The
     sweep stamps windows it re-sees as verified for free, so the
     budget is spent only on windows nothing has vouched for lately. A
     window the budget cannot reach is still a tile — something
     vouched for it recently, and dropping it silently would resurrect
     the missing-windows bug — and it sits at the FRONT of next
     press's probe queue, so the culling of closed windows rotates
     through the whole memory within a few presses instead of
     stalling. The isMinimized read is skipped when minimised windows
     are included anyway (the default — that alone halves the AX
     cost), the withWindows/lastHere passes are merged (one
     application()+name() per entry, was two), and the slow-listing
     Console line now accounts for the phase: "· memory: N probed in
     X.XXs". The next unexplained slow press will name itself.
  ✅ THE ⇪T WINDOW, THREE COMPLAINTS IN ONE MESSAGE: "the SAC Values
     selector doesn't look right. Also, I can't move this window. And
     it doesn't seem active, I have to click on it." (1) A multi_enum
     field renders as CHECKBOX CHIPS now, not a <select multiple>: the
     list box was the one system-styled always-open control in a form
     of dark dropdowns, its ⌘-click rule lived in a hover tooltip, and
     WebKit paints the focused row solid blue — which reads as
     "already picked" when nothing is. Labelled checkboxes say all of
     it; the picks still travel as an array of option gids, so the
     submit path is untouched. (2) The TITLE BAR IS A DRAG HANDLE: the
     header reports mousedown and window_move drives the drag off the
     _G.movablePanels entry the form has had since 6.89.0 — the exact
     ⇪space recipe; ⌘-drag anywhere still works. (3) The form asks for
     the NON-ACTIVATING PANEL MASK (the Capture Pad's recipe, applied
     arithmetically and verified by read-back): allowTextEntry made the
     window ABLE to become key, but a plain panel from a background app
     only takes the keyboard once macOS activates the app — which a
     click is the first thing to do. With the mask it types the moment
     it opens, and Hammerspoon's other windows stay put.
  🕘 ⇪Y GROWS TWO VERBS — LL: "When I select an item from Chrome
     history and click on it, it launches that URL. But I might want
     to copy it and open it in another browser." hs.chooser has no
     per-row action API, so the pick reads the modifiers held at the
     moment of ⏎ (the standard Hammerspoon answer): ⌘⏎ copies the URL
     to the clipboard and opens nothing, ⌥⏎ opens it in Safari
     (chrome.altBrowser — one line to retarget), bare ⏎ opens in
     Chrome exactly as before. The placeholder teaches all three on
     every open, naming the alt browser off its bundle id; a build
     without hs.eventtap degrades to bare-⏎ behaviour.
  ✅ Gate: 6,209 → 6,228 checks (test_switcher 156 → 160: the probe
     budget and its rotation; test_taskform 52 → 61: chips, checked
     restore, dragStart by name, the verified mask, the maskless
     build; test_chrome_history 104 → 110: the three verbs, the
     placeholder, the eventtap-less degrade).

NEW IN 6.152.1 — THE BEACHBALL 6.152.0 SHIPPED, DEAD THE SAME DAY:
  🏖 LL, hours after installing 6.152.0: "Keeps giving me the spinning
     beachball. Something doesn't seem right." The Console pasted with
     it held the receipts: "✏️ Autocorrect tap was disabled by macOS —
     revived" and the expander's twin, ~30 seconds after EVERY boot
     (21:19:59 and 21:20:45, two boots, both at +31s). macOS disables
     an event tap when its process stops servicing events for too
     long — a tap kill in the Console IS a beachball in writing, with
     a timestamp. The search index was exonerated by the second boot
     (no rebuild ran, the stall came anyway); what happens at +31s
     after every boot is the Chrome export completing: warm() starts
     it at +2s, and copying each profile's History database takes
     ~29s.
  🕘 THE CULPRIT WAS THE ⇪Y FIX SUCCEEDING. 6.152.0 freed the export
     from its pipe deadlock — and the completion callback then did
     everything in ONE main-thread pass: read megabytes of JSON back
     from the profile files, hs.json.decode the lot, build 20,000+
     entry tables (two gsubs, a lower, a strftime each), sort them,
     and write the whole CSV to the OneDrive Logs folder with two MORE
     os.date calls per row. That code path had never once run with
     real data — every export before 6.152.0 died in the pipe — so its
     cost was invisible until the day the fix landed. The boot-time
     loadCsv had the same growth: last session's CSV used to be
     stale-tiny (exports always died); now it is 20,000+ rows read
     back synchronously at warm().
  🔪 SO INGESTION IS SLICED — the ⌥Tab sweep's time-budget idea
     applied to parsing (chrome.sliceBudget, 40ms): a slice does at
     most that much work, parks a doAfter(0) continuation, lets
     keystrokes through, continues. Three structural changes make
     every unit of work cuttable: (1) the export emits ONE JSON OBJECT
     PER LINE (json_object per row) instead of one 20,000-row array,
     because a single giant hs.json.decode is an unbudgetable bite;
     (2) loadCsv is sliced the same way and answers through a
     callback (warm chains the export off its completion); (3) the CSV
     writer takes date and time from e.when — built once in finish()
     — instead of calling os.date twice per row: 40,000 strftimes a
     run, gone. Small exports still complete synchronously inside one
     slice (the tests rely on it); a newer ingest (⇪⇧Y mid-parse)
     supersedes the old one, which never installs. The report grows a
     receipt: "last parse: N rows in K slices, Nms total".
  ⏲ AND THE 45s EXPORT DEADLINE WAS A GUESS made in 6.147.0 while the
     deadlock kept any export from ever finishing — "a healthy export
     measures in single-digit seconds" was belief, not measurement.
     The first export that ever completed took ~29s on the Air, and
     the work Mac will be slower; at 45s the watchdog would kill
     legitimate runs on a bad day. It fires at 120s now, for the
     genuine never-coming-back hang only.
  ✅ Gate: 6,204 → 6,209 checks (test_chrome_history 99 → 104: the
     NDJSON shape, the parked continuation, the mid-flight
     non-install, the cross-turn finish, the sliced CSV).

NEW IN 6.152.0 — NINE ASKS IN ONE PASS: ⌥TAB'S MEMORY AND SPEED · THE
PAUSE KEY · THE POMODORO LOG · ⇪T'S DETAILS · THREE BUGS DEAD:
  🧠 ⌥TAB REMEMBERS OTHER DESKTOPS. LL, after 6.151.0: "Opt+tab still
     isn't detecting all windows. I swear it used too." The console
     proved the sweep RAN (12 apps, Chrome answering in 0.00s) — which
     falsifies the 6.39.0 belief this module was built on: macOS's
     Accessibility API returns an app's MINIMISED windows (no Space
     owns them) but simply omits windows parked on another desktop.
     6.151.0's fix genuinely delivered the minimised ones; the
     other-desktop ones were never in AX's answer at all. The private
     APIs that CAN enumerate other Spaces return "a lot of false
     positives" by their own documentation and need hs.window.filter
     (banned since the 44-second beachball) to prune — so the fix is a
     MEMORY instead: every window a listing sees is remembered (id →
     hs.window), the AX handle stays valid after its Space stops being
     enumerated, and remembered windows the sweep no longer reports
     are probed cheaply (isRunning first — no AX — then one role read)
     and shown as tiles, captioned "remembered". Dead ones are
     forgotten on the spot. Selecting one activates its app and
     focuses the window; macOS itself carries you to its desktop. The
     honest limit, stated on the cheat sheet: a window is known from
     the first press that could see its desktop — one ⌥Tab per desktop
     per reload teaches it.
  ⚡ AND THE PRESS IS ~HALF THE PRICE. "It is also slow to display":
     the old phase 1, hs.window.orderedWindows(), internally re-runs
     the whole per-app sweep (plus an isHidden per app and visibility
     checks per window) just to learn the stacking order — 1.6s on
     this Air by LL's console, on top of the sweep's own 0.7s, every
     uncached press. The stacking order now comes from
     hs.window._orderedwinids() — the raw CoreGraphics id list,
     milliseconds, pcall'd with a sweep-order fallback — and the
     budgeted per-app sweep is the ONLY Accessibility pass. Sweep
     order: frontmost app, then apps that had a visible window last
     press, then the rest; tiles sort by CG rank, then discovery.
     The "on-screen list alone took Ns" message retired with the
     phase that caused it.
  ⏸ PAUSE HAMMERSPOON — ⇪⇧1. LL: "Can I pause Hammerspoon using an
     empty key from my Cheat Sheet?" The first spend from the 6.142.0
     free row. One press: _G.hsPaused goes up, every OTHER hyper
     shortcut is suppressed centrally (hyperBind wraps all three
     handlers at bind time, so migrations, modules and hyperActions
     are all covered and none can forget), and the typing interceptors
     — autocorrect, the expander, the key caster — pass every
     keystroke through untouched via one guard at the top of each
     handler. The taps stay RUNNING (a stopped tap needs its watchdog
     dance to come back; a pass-through costs one comparison). A
     ⏸ HS menu-bar flag stands while paused; clicking it resumes, as
     does ⇪⇧1 — the one hyper key the wrap exempts, via
     _G.hsPauseCombo published before binding. A shortcut pressed
     while paused gets one throttled alert naming the way back.
     Trackers and timers keep running: pause means "out of my
     keyboard", not "stop keeping my logs".
  🍅 THE POMODORO GROWS UP (four asks in one):
     · 20% BIGGER — pom.scale = 1.2, applied through S() to the card
       AND every drawn size and position, so the type scales with it.
     · FAINT UNTIL IT MATTERS — whole-window alpha via canvas:alpha():
       30% through the countdown, 90% for the last five minutes, mid-
       flash, while asking, and UNDER THE MOUSE — a 0.15s hover poll
       (not a canvas mouseCallback: window_move's drag owns that, one
       per canvas) makes it solid the moment you point at it and faint
       again when you leave. One targetAlpha() answers every path.
     · THE LOG — pomodoro_log-<Mac>.csv in the Logs folder:
       date,time,event,detail; a `started` row for every launch (⇪⇧P
       and ⏎ alike), a `completed` row when the 25 minutes finish —
       the moment a pomodoro counts.
     · THE TALLIES — at workdayEnd (4:30) a card says "Today: N
       pomodoros completed (M started)"; Fridays append the Mon–Fri
       week table. hs.timer.doAt, daily, weekend-guarded.
       _G.pomodoroReport() prints today + the week + the file path any
       time; pomodoro.report is a service.
  ✅ ⇪T LEARNS THE DETAILS (two asks):
     · THE SCHEDULE — optional Start/End date and time fields (native
       date/time inputs). Asana's rules are enforced BEFORE the
       request, as alerts instead of Console 400s: a time needs its
       date; a start needs an end; with both dates set the times come
       as a pair or not at all (start_at cannot ride with due_on).
       Dates go as start_on/due_on, timed ones as start_at/due_at in
       ISO 8601 with the local offset spelled ±hh:mm.
     · THE PROJECT'S FIELDS — ACD Strategic Principle, SAC Values,
       Task Priority, Progress, Supervisor: those are the project's
       custom fields, and their gids and option lists belong to Asana,
       not this repo. warm() fetches custom_field_settings once per
       boot into _G.asanaCustomFields; the form renders what came
       back — enum → dropdown, multi_enum → multi-select (⌘-click),
       people → input over the same team datalist as Assignee (names
       resolve through the same roster at submit), number/text →
       inputs; unsupported subtypes are skipped whole. Values travel
       as custom_fields keyed by gid; empties are dropped. Edit a
       dropdown in Asana and ⇪T has it on the next reload. The pipe
       chooser's four-string call is untouched, and the draft —
       schedule and picks included — still survives Esc.
  🗂 TAB SEARCH NEVER WORKED, AND NOW DOES. LL's ⛔ errors section:
     "osascript exited 1: 577:579: syntax error: Expected end of line
     but found identifier." Character 577 is the Safari branch's
     `tab ti of window wi` — and without `using terms from
     application "Safari"`, the bare word `tab` parses as
     AppleScript's built-in tab-CHARACTER constant, so the whole
     script failed to COMPILE on every press, Chromium branch
     included, while the alert blamed Automation permission (the
     CLAUDE.md open item chased that theory too). The jump script had
     the identical flaw. Both now borrow Safari's dictionary, exactly
     as the Chromium branch has always borrowed Chrome's. ⇪⇧' still
     needs the Automation grant, once per browser — expect the macOS
     prompts on first real use.
  🕘 THE ⇪Y HANG, SOLVED AT THE ROOT. Every flight-recorder kill read
     "it hung at: querying Default" — and the mechanism was in
     6.148.0's own comment: "stdout only reaches Lua when the task
     EXITS." sqlite3 writes megabytes of JSON (20,000 rows/profile)
     into a 64 KB pipe nothing drains until exit; the buffer fills,
     sqlite3 blocks mid-write, the task can never exit, the watchdog
     kills it at 45s — every run, deterministically. The data never
     touches the pipe now: each profile's rows are redirected to
     their own temp file and stdout carries two marker lines per
     profile (##PROFILE##, ##FILE##); parse() reads the files back
     and deletes them. An empty file is a profile with nothing in
     the window, not a warning.
  🆓 THE ⇪⇧pad WINDOW MAP IS CLEARED. LL: "Why does the numpad section
     on the cheat sheet still list some window arranging keys? Those
     should just say: 'Key available for use'." — the 6.142.0
     instruction, applied to the pad. shiftActions is empty-but-
     claimable (the cmdShiftActions posture); the zones and verbs stay
     in numpad.run, so `pad7 = "topLeft"` revives a key in one line;
     the sheet's rows now read, in LL's words, "Key available for
     use". Halves/maximise/put-back/monitors still live on ⇪arrows.
  🧲 WINDOW MOVE → "PANEL MOVE". LL: "Why don't we combine these two
     because they both work on windows: Window picker, Window move?"
     They work on DIFFERENT windows — the Arranger moves your apps',
     this module moves Hammerspoon's own panels and pickers — and the
     old title is what hid that. Retitled on the sheet and in
     _G.windowMoveReport(); nothing about the mechanics changed.
  🐛 AND THE CONSOLE CRASH: window_return.lua:209 fed a float to %d
     ("number has no integer representation", once per snapshot
     cycle, straight off LL's paste). Floored.
  🧪 THE GATE, REBUILT WHERE THE WORLD CHANGED: test_switcher's
     harness now tells the AX truth (allWindows omits other-desktop
     windows), so the memory is proven the way it will really run —
     learn on one desktop, serve on another, forget the dead; the
     legacy orderedWindows stub COUNTS calls so the double sweep
     cannot creep back. test_chrome_history feeds marker+file stdout
     and proves the files are deleted after parsing. test_tab_search
     pins `using terms from application "Safari"` in BOTH scripts.
     test_task_creator covers the date rules, the ISO offsets, every
     custom-field shape and the fetch; test_taskform drives the
     Details section end to end. test_tools covers the alpha ramp,
     the hover, the log rows and the tallies. test_power_tools walks
     the pause lifecycle. 6,137 → 6,204 checks, 67 stages green.

NEW IN 6.151.0 — ⌥TAB: THE OTHER CHROME WINDOWS, FOUND AT LAST:
  🪟 LL: "Alt+Tab is not showing all windows. Example it shows one
     Chrome window but no other Chrome windows I have open. how do we
     solve this?" The one it showed was the Chrome window on the
     current desktop; the missing ones were minimised or on other
     desktops. Those are findable ONLY by the per-app sweep —
     hs.window.orderedWindows() reports the current Space, minus
     minimised windows, by macOS design (the 6.39.0 note) — and the
     sweep was being starved two different ways at once.
  ⏱ STARVATION ONE: THE WRONG CLOCK. The 0.8s listBudget (the 6.41.0
     answer to a 15.9s freeze) started counting BEFORE the on-screen
     listing, and on this Mac that listing alone has taken 3.0s (the
     6.148.0 console paste: "stopped after 3.0s / 0 apps"). By the
     time the per-app loop reached its first deadline check the budget
     was already gone, so it asked ZERO applications and ⌥Tab quietly
     degraded to "this desktop only" — while the cheat sheet went on
     promising "EVERY window: all desktops/Spaces, minimised too".
     6.148.0 made the MESSAGE honest about this and left the
     starvation in; LL's report is what that trade-off costs. The
     sweep now takes its own t1 the moment it starts, and the budget
     is measured against that: a slow phase 1 costs a Console line
     (reworded — it now says the sweep still ran, with the apps
     count), never the cross-Space windows. Worst case is phase 1's
     time PLUS one full budget, and the 4s cache amortises it.
  🥇 STARVATION TWO: macOS'S ORDER, NOT YOURS. Within the sweep,
     applications were asked in runningApplications() order, so
     background agents at the front ate the budget (and their windows
     ate maxWindows slots) while Chrome sat at the back of the line.
     Apps that own a window phase 1 already listed are asked FIRST
     now: an app with a window on your desktop is precisely the app
     whose OTHER windows you are reaching for. Ranking is pure Lua
     over the bulk enumeration (kind/name properties — the app_watcher
     6.16.22 lesson), so it costs nothing next to one AX call.
  📏 ⇪⇧D: _G.altTabLastListing grows orderedSecs, so the next console
     paste shows phase 1's own cost beside the sweep's. The 6.148.0
     "0 apps / Slowest app: nil" state is impossible by construction
     now — the first app is always reached — and its special-case
     message retired with it.
  🧪 test_switcher 145 → 152: 9b now proves the 3.0s-phase-1 scenario
     still asks every app (and publishes orderedSecs); 9c's clock
     sequence gained the sweep's own t1 tick; new 9d rebuilds LL's
     exact report — one Chrome window visible, one minimised, one on
     another desktop, Chrome LAST in macOS's order behind ten slow
     agents — and pins that both hidden Chrome windows are tiles while
     the agent queue is still cut short by the budget. 6,137 checks
     across the gate.

NEW IN 6.150.0 — THE APP MONITOR ALARM: ONLY ESC DISMISSES IT:
  🖱 LL: "if click off this tool it stops the alarm. Can we set it so
     that it will not close until I click escape?" The tool: the App
     Watcher popup — the one that appears, pinging, when a watched
     app quits. Root cause: that popup is an hs.chooser, and macOS
     closes a chooser THE MOMENT IT LOSES KEY FOCUS. That close calls
     the completion callback with nil — byte-for-byte the same nil
     the callback gets for Esc. So a stray click on any other window
     read as "acknowledged, stop the alarm": the 6.16.21 no-auto-
     dismiss design ("if you're away, a popup that gives up means
     you'd never find out"), quietly undone by a mouse. Worse than
     away: you were AT the Mac, mid-click on something else, and
     still never found out.
  ⎋ THE TWO NILS ARE TOLD APART BY THE KEYBOARD. hs.chooser exposes
     no "why did I close" API, so the module now watches for the one
     signal that distinguishes them: a small keyDown eventtap records
     WHEN Esc was last pressed while the popup was actually visible.
     The callback then reads the nil against that clock. Nil with a
     fresh press (0.75s) = you dismissed it — notification posted,
     alarm stopped, queue advances, exactly as before. Nil without
     one = focus theft (a click, ⌘-tab, a new dialog) — NOT an
     answer, so the same question is re-presented a beat (0.25s)
     later, and the ping sequence never stopped in between. Buttons
     arrive as a real choice and are untouched. The tap OBSERVES
     (returns false, never eats a key), is pcall-shielded, checks
     _G.typingInjection() so the expander's synthetic Esc cannot
     acknowledge a crash, and runs ONLY while a popup is waiting —
     started in showNext, stopped with the ping — so it adds nothing
     to the standing keyboard path core/lag.lua exists to police.
  🐕 THE PING DOUBLES AS A WATCHDOG. Placement moved out of showNext
     into appMonitorPresent(), because one question can now need
     presenting more than once. Each ping also asks: question still
     open, popup not visible, no reshow in flight, no recent Esc to
     explain it? Then re-present — covering any hide path that skips
     the chooser callback. The alarm you can hear and the popup you
     can answer stay one thing. An Esc pressed while the popup is
     HIDDEN (the beat between click-off and re-show) is deliberately
     ignored: it was aimed at whatever you clicked, not at a popup
     you could not see.
  🧪 test_app_watcher grew from 44 to 69 checks, and dismiss() in its
     harness is now the FULL Esc sequence (tap sees the key, then
     hide + nil callback) — a bare nil callback is the click-off
     shape and no longer dismisses anything, which is the entire
     point. Pinned: click-off posts no notification, re-shows, and
     the pings run straight through; Esc posts exactly one and
     silences the alarm; buttons still resolve; the tap runs only
     while a popup waits; a hidden-popup Esc resolves nothing; the
     watchdog re-presents; click-off does not skip the queue; an
     injected Esc cannot answer. 6,130 checks across the gate.
  📋 Cheat sheet row updated: "Esc — The ONLY dismiss (clicking
     elsewhere brings it back) → posts notification".

NEW IN 6.149.0 — THE ⇪Q DIM: DARKER, AND A SHIELD THAT STAYS TRUE:
  🌑 LL: "the ⇪Q dim needs to be darker and does it handle pop-ups
     that could appear? In essence, I'd like to nabb interruptions."
     Darker first: fm.dimAlpha rises 0.55 → 0.75. At 0.55 a dimmed
     Slack was still legible enough to read, which is the opposite of
     a shield; at 0.75 the shapes survive ("that's Slack") but the
     words do not. One number to taste, and the suite now pins it at
     ≥ 0.7 so a future tweak cannot quietly fade it back.
  🕳 POP-UPS, THE HONEST ANSWER: the sheet itself already caught
     them. It sits at mainMenu−3 on the coexist ladder — above every
     ordinary window level (normal 0, floating 3, modal 8) — so a
     dialog appearing mid-meeting rises UNDER the dim and comes up
     dimmed. The HOLES were the way through: bare rectangles captured
     once at engage time, so a pop-up landing ON TOP of the meeting
     window sat inside the hole and showed through at full
     brightness — center-screen, over the one place you were
     guaranteed to be looking. And a moved or resized meeting window
     slid into the dim while its stale hole lit up whatever had
     drifted underneath.
  🔄 SO THE HOLES ARE LIVE NOW, AND THEY KNOW ABOUT Z-ORDER. Every
     two seconds — only while the dim is up; the repaint timer is
     born in dimOn and dies in dimOff — the canvas elements are
     rebuilt from the real window stack, painted back-to-front the
     way the screen itself is: a critical window paints "clear" (a
     hole), anything else paints the dim color with compositeRule
     "copy", so an intruder OVER the meeting heals the hole shut
     exactly where it sits. "copy" and not a plain fill because
     0.75-alpha over 0.75-alpha stacks to 0.94 and every overlap
     would read as a randomly darker patch. One CGWindow sweep plus
     a replaceElements per screen per tick — no canvas created or
     shown — and deliberately NOT in the eco registry: that is for
     cadences that run all day, and this one exists only while a
     meeting does, the moment the shield being right matters most.
  🔔 WHAT THE DIM STILL DOES NOT CATCH, said plainly: notification
     banners, which draw above mainMenu. Those are the macOS Focus
     half's job — the Meeting Focus On/Off Shortcuts — same as ever.
     The cheat sheet row now says "pop-ups included" on the dim line.
  🧪 test_focus 4b: the canvas stub records what was painted and
     orderedWindows became controllable. Pinned: the darkness floor;
     hole = clear at the meeting's frame; intruder-over-meeting =
     copy AFTER the hole, at the intruder's frame, at dimAlpha;
     intruder-under-meeting = the hole painted last and winning; a
     pop-up arriving after engage nabbed on the next tick; a moved
     meeting window's hole following it; the repaint timer torn down
     with the dim. 82 checks in the suite, 6,105 across the gate.
  📏 AND GUIDE.md's MEASURING SNIPPET WAS ITSELF UNDERCOUNTING, by
     exactly 130: test_arranger and test_activity_url print their own
     "✅ test_x:" prefix on the gate row, the snippet's sed only knew
     the "── test_x:" shape, and an unrecognized row passed through
     unparsed — counted as a suite, summed as ZERO checks. It now
     grabs the number in front of "passed" instead of parsing the
     prefix. The documented totals were never wrong — they were
     summed by hand at each ceremony — but the tool the paragraph
     told a reader to trust was. Fourth entry in that block's own
     "wrong in a new way" ledger.

NEW IN 6.148.0 — EVERY TOOL POPS IN FRONT OF THE CHEAT SHEET:
  🪟 LL, with ⇪space layered over the sheet in their screenshot: "Can
     you make all the tools pop in front of the cheat sheet? Like the
     app picker/universal launcher." Why only those behaved: the
     webview tools (⇪space, ⇪I, the pads, the editors) all call
     hs.webview's bringToFront(true), which parks them near
     screenSaver (~1000) — while hs.chooser's panel is PINNED at
     mainMenu+3 by Hammerspoon itself (HSChooser.m, read from the
     source, 2026-09-01) and exposes no level API at all. The sheet
     drew at `overlay` (102), seventy-five levels above the chooser's
     rung: all seventeen chooser tools — ⇪D apps, ⇪V clipboard, ⇪;
     power tools, ⇪⇧4 screenshots, ⇪⇧6 net watch, 📎 default apps
     and the rest — opened UNDERNEATH the reference that told you
     about them.
  🪜 THE LADDER (core/coexist.lua) IS REBUILT AROUND THAT FIXED RUNG:
     offsets from mainMenu now, with the chooser's +3 written down as
     the landmark nobody can move. The sheet drops to mainMenu−2 —
     THE FLOOR, the statement _G.escapePriorities has made since
     6.78.0 ("closes last" IS "drawn under"). The canvas cards
     (⇪- calendar, 16:01 rollup, Asana mirror, ⇪7 card, ⌥Tab HUD,
     win_pin stickers) take NAMED rungs between sheet and chooser —
     five of them used to name `overlay` directly, TYING the sheet
     and stacking by accident of show order, the same undefinedness
     6.68.0 first fought. Only the Key Caster (+4) and the pomodoro
     (+5) outrank the chooser: the two windows that must never hide
     behind what you press. The ⇪Q dim drops below even the sheet —
     a dim that covered your picker was backwards. Deliberately above
     the whole ladder, unchanged: every webview panel, the mouse
     grid, the screenshot area-picker, the legend strip, the veil.
     test_integration executes the real block and pins the policy:
     sheet under the chooser rung, every card between the two,
     pomodoro on top, and each of the five cards asking for its
     level BY NAME instead of a bare `overlay`.
  🔄 THE SWITCHER'S "0 apps / Slowest app: nil" LINE RETIRED — LL's
     console showed it three times ("stopped after 3.0s / 0 apps —
     Slowest app: nil (0.00s)"). Zero apps means the per-app pass
     never ran: hs.window.orderedWindows() alone spent the whole
     budget. The message now blames the on-screen listing with its
     own timing and says the cross-Space pass was skipped — instead
     of naming a nil app and suggesting a skipApps fix that could
     not possibly have helped. A genuinely slow app still gets the
     classic line with its name; both paths are under test.
  🕘 THE ⇪Y KILL NAMES THE STEP IT DIED IN. The 6.147.0 watchdog did
     its job on the Air — twice — and could say nothing but "it
     hung": a killed task's stdout dies with it. The export script
     now logs one line to a progress file BEFORE each step (copying
     Default, querying Profile 1, … finished cleanly) — a FILE, not
     stdout, because stdout is the JSON data channel a marker would
     corrupt. The kill reads the file's last line into its status,
     alert, notice and the report's new "progress:" line: "it hung
     at: copying Default" points at the History COPY (permission
     territory); "querying …" would point at sqlite3. Two smaller
     lies fixed around it: the killed sh still EXITS (code 15, from
     our own terminate), and that exit used to land in the completion
     callback and overwrite the honest KILLED status with "export
     failed (sh exited 15)" — LL's console showed exactly that pair.
     The guard is PER-RUN, so a killed run's late exit can no longer
     touch a newer run's state either.

NEW IN 6.147.0 — SIX ANSWERS: WHO'S TALKING · NAMES · CLOCK · CONSOLE:
  🌐 NET WATCH (modules/net_watch.lua, the sixty-second module, on
     ⇪⇧6 — the free-keys ledger listed it, and it is the shift of ⇪6
     net tools). LL, with the ⇪7 card open: "Can you make the panel
     of information more indepth? Specifically I want it to list any
     application that is running something that is communicating with
     some service to do something … Say what the application is · Say
     what the application is doing · Resolve where the application is
     pulling its data from." Plus ⌘1 copy-all and ⌘2 copy-one.
     · THE CONNECTIONS: one /usr/sbin/lsof -i snapshot per press,
       field output (-F) so command names with spaces arrive whole,
       run without root — YOUR apps, by design; the report's first
       line says root's daemons need admin. No polling, nothing for
       the battery saver to slow.
     · THE NAMES: every public remote IP reverse-resolved through
       dscacheutil (the resolver's own cache), ONE lookup at a time
       with a per-lookup deadline, cached per session; private-range
       addresses labeled "local network", never resolved.
     · THE WHY: a rule table maps known processes and domains to what
       they are and why they talk — Microsoft AutoUpdate monitors
       Office updates, apsd is every notification's one connection,
       an Akamai name is a CDN edge. A name no rule matches says
       UNRECOGNIZED and shows its raw paths — the honest fallback is
       the point; a confident wrong "why" teaches you to trust wrong
       answers about your own network. (A break test replaces the
       fallback and watches an unknown daemon wear AutoUpdate's
       story.)
     · THE COPIES: row 1 (the chooser's native ⌘1) copies the FULL
       report; ⏎ on any app row (⌘2 reaches the first) copies that
       app's alone — name/pids, what, why, and each path as
       "TCP local → remote (STATE)" with "IP resolves to name" under
       it. _G.netWatchReport() prints the same thing.
  🕐 THE DATE PICKER'S CLOCK AND REPORT (⇪⇧0) — LL: "Can you it the
     date picker give all as a 'Date report:'? And can you enter a
     time display: 2:00:00 PM so I can see what time it is?" The
     panel's footer now shows the time as big as the date, LIVE to
     the second (one render a second, only while the panel is open,
     stopped on close). R copies "Date report:" — the highlighted
     date in all seven formats, the week/day/relative line, and
     "Time now:" closing it. The leading zero is shaved by hand
     (2:00:00 PM, not 02:00:00 PM) because %-I is a GNU extension
     BSD strftime does not have. calendar.report is published.
  🏷 SCREENSHOTS NAMED BY WHAT IS ON THEM — LL: "Can we apply better
     naming conventions to the screenshot files than SCR- so the OCR
     text is applied and searchable?" Every ⇪4-family capture is
     OCR'd in the background (same HS OCR Shortcut) and renamed
     "Screenshot … — its own words.png" a few seconds later — except
     one headed into the blur editor, where a rename would orphan the
     save. ⌘9 in the ⇪⇧4 panel (the ninth native slot) sweeps the
     backlog: SCR-YYYYMMDD-xxxx files fold into the same convention
     keeping their real mtime; word-less "Screenshot …" files gain
     theirs; a name that already carries " — ", or one a person
     chose, is NEVER touched. One shortcuts process at a time, capped
     per sweep, closing with "Named N of M — K had no readable text".
     The text also lands in the Finder comment through the OCR
     engine's new ocr.comment service (its never-overwrite rule
     applies), so Spotlight finds it two ways.
  🔄 ⌥TAB LANDS ON THE HAMMERSPOON CONSOLE — LL asked exactly that.
     The console slips both of the switcher's nets: Hammerspoon is a
     menu-bar app (the kind == 1 per-app pass never asks it) and the
     console window can answer isStandard() = false. So it is asked
     for BY NAME — hs.console.hswindow() — when open; a closed
     console is not a tile, it is a tool you have not opened.
  🕘 ⇪Y'S EXPORT GETS A DEADLINE — LL: "Messages are saying still
     building Chrome history." On the Air the /bin/sh export hung,
     `exporting` stayed true, and every press answered "press again
     in a moment" — forever, with nothing saying it was stuck. The
     export now arms a 45s watchdog: a hang is terminated, status
     says KILLED and points at _G.chromeHistoryReport(), a notice is
     recorded, and the waiting alert counts the seconds so a healthy
     two-second export and a hang read differently. The watchdog is
     stopped on every normal exit and the suite drives both paths.
  📎 DEFAULT APPS, UNBURIED — LL: "The tool to set default apps is
     buried and I'm not sure it's working." It keeps its @tool row
     and gains a ⇪; power-tools row (seventeenth tool), the same
     guarded service-call shape as the backup and veil rows. Whether
     it WORKS on this Mac: press it once and read the alert — the
     verdict is LaunchServices' own read-back, and
     _G.defaultAppsReport() keeps the receipts.
  🧪 tests/test_net_watch.lua is the sixty-second Lua suite (56
     checks); test_screenshots +17, test_features +8, test_switcher
     +3, test_chrome_history +7, test_power_tools 17-tool pins.
     Counts: 62 modules; gate 6,073 checks over sixty-seven stages.

NEW IN 6.146.0 — DEFAULT APPS: A FILE TYPE OPENS IN THE APP YOU CHOSE:
  📎 LL: "Can we create a tool that will allow me to set a default
     application for a specific file type? So, PDFs open in Acrobat
     instead? Also, we need to verify the setting/assignment took."
     Both halves are the spec, and both shipped. modules/
     default_apps.lua, the sixty-first module, keyless the way the
     rollup is — every ⇪ letter is long spoken for, and a tool used a
     few times a year has no claim on one. ⇪space (or ⇪⇧/), @tool,
     the 📎 row is its front door; the run map joins 📎 to
     defaultApps.show the way 📊 reaches the rollup.
  🗂 TWO PICKERS. First the type: the common extensions preloaded,
     and ANY typed extension grows its own row the moment it passes
     the guard (letters, digits, + . _ -, twenty characters — the
     same regex again inside the script, because argv is an input
     even when this file is not the caller). Then the app: ONLY the
     apps whose Info.plist claims the type — the same set Finder
     offers under Open With — with today's default starred, bundle id
     and path in the subtitle, and an app that is listed but gone
     from disk saying so. Picking the starred row changes nothing and
     says why. An app that never claimed the type is not offered:
     every app that mishandles a type it never claimed started
     exactly that way.
  🔏 THE WRITE GOES THROUGH LAUNCHSERVICES — the registry Finder's
     Get Info → "Change All…" writes — via osascript -l JavaScript,
     the one reviewed binary, OUT OF PROCESS (the 6.65.1 rule: an
     Apple Event cannot abort us from a child), no admin, no new
     dependency, both Macs. Lua never touches the registry; it only
     reads the child's JSON.
  ✅ THE VERDICT IS THE READ-BACK, NOT THE RETURN CODE — the half of
     the request that says "verify the assignment took". The same
     script, in the same run, reads the registry back through TWO
     independent doors: LSCopyDefaultRoleHandler (the table the write
     targets) and NSWorkspace's app-for-type answer (what macOS 12+
     would actually launch). The alert quotes what LaunchServices NOW
     says — matched case-insensitively, because LS lowercases bundle
     ids on the way out, with the raw string kept so a real mismatch
     is never smoothed over. Status 0 with the wrong read-back is a
     loud DID NOT TAKE. And a re-check two seconds later asks AGAIN:
     a write undone by a racing LS refresh flips the history entry to
     FAILED and shouts, because you had already stopped watching.
  🧾 _G.defaultAppsReport() (also defaultApps.report): every change
     this session — was, wanted, read-back, the 2s confirmation — and
     the one trap the registry cannot see: a per-file "Always Open
     With" override beats the type-wide default, so ONE stubborn file
     after a verified change is Get Info on that file, not a failed
     write. URL schemes (the default browser) are documented out of
     scope: macOS requires consent in System Settings there.
  🧪 tests/test_default_apps.lua, the sixty-first Lua suite, 80
     checks: the guard, both pickers, the argv, the verdict rules,
     the revert catch, the honest failure paths, the JXA pinned to
     keep both witnesses — plus cross-file sentries (BASE, the run
     map, the gate itself) and three break tests: verdict-trusts-
     status-0, guard removed, revert-stays-green — each proving the
     lie the intact module refuses to tell. Counts: 61 modules
     (INSTALL.md, hs-doctor), gate 5,979 checks over sixty-six
     stages.

NEW IN 6.145.2 — THE BACKUP LINE THAT ALWAYS SAID "not configured":
  🔎 LL pasted a clean 6.145.1 diagnostic and asked "How are we
     looking?" — and one line in it was lying. PATHS said "backup
     dir : not configured" while CAPABILITIES, in the SAME report,
     showed the 5:00 PM daily backup armed into OneDrive. Both were
     sincere: the backups run off core.backupDir, which was set; the
     PATHS line read a GLOBAL named backupDir that no Mac ever sets,
     and _G.diag.fileInfo(nil) answers "not configured".
  🧬 THE BUG SHIPPED IN 6.44.11, when §1.11 was lifted out of
     init.lua into core/diagnostics.lua. Inside init.lua the line had
     read backupDir as an UPVALUE and was right; the extraction passed
     three values (logsDir, hostTag, asanaEnabled) and missed the
     fourth — the file's own header said "the three values", so it
     believed itself. Every diagnostic report on every Mac has printed
     the false line since. Nothing downstream reads it; the cost was
     purely a lie waiting to send a future debugging session hunting a
     backup problem that does not exist.
  🫥 WHY 5,895 CHECKS NEVER CAUGHT IT: the test harness defines
     backupDir as a real global (line 42 of test_diagnostics.lua, one
     assignment with hostTag and friends), so in the SUITE the bare
     global read found a value and the line looked right. init.lua
     never does that — its backupDir is a local. The green was real;
     the environment was not.
  🩹 THE FIX IS FOUR WORDS AND A TRAP. init.lua passes backupDir in
     the table (§1.11 load site); diagnostics unpacks it like the
     other three, and the untouched PATHS line binds to the new local.
     The suite now hands the chunk the value and then DELETES its
     harness global before building the report — so the report can
     only be right by keeping core.backupDir, and the next accidental
     global read fails the suite instead of every Mac. test_diagnostics
     427 checks; the gate 5,896 over the same sixty-five stages.

NEW IN 6.145.1 — THE ECHO ROW: EVERY doEvery TIMER, COUNTED ONCE:
  ⏱ Parked since 6.137.0 ("noted, not fixed"), picked by LL from the
     open list. The lag probe's timer table carried an
     "hs/timer.lua:173" row — 19,228 fires in LL's own 6.137.0
     report — that belonged to no module. Hammerspoon's doEvery is
     Lua, not C: hs/timer.lua builds the timer it hands back by
     calling hs.timer.new, the OTHER function the probe wraps. So
     every doEvery timer was wrapped twice — measured once under its
     caller's name and once under that one shared library line — and
     the timer totals, and the "share of the one thread" verdict they
     feed, claimed the timers cost more than they did.
  🚿 THE FIX IS A PASS-THROUGH, NOT A FILTER. While the wrapped
     doEvery is calling the real one, a flag makes the new-wrapper
     hand the inner call straight through — that timer is already
     being measured under the right name; wrapping it again is what
     MADE the echo row. The real call runs inside pcall so a doEvery
     that throws (a bad interval) cannot leave the flag stuck ON —
     stuck, every hs.timer.new for the rest of the session would pass
     by unmeasured and the table would quietly go blind.
  🧪 THE STUB NOW TELLS THE TRUTH. test_lag's doEvery stub used to
     build its timer by hand, which is why no test ever saw the echo:
     it now builds it the way hs/timer.lua really does — through
     hs.timer.new — so the whole existing suite runs against the real
     shape. New checks pin one record per doEvery, the flag OFF again
     for the next direct hs.timer.new, and the throw path resetting
     it; BREAK V drops the flag on purpose and watches the echo row
     come back and a single fire get counted twice. test_lag 243
     checks; the gate 5,895 over the same sixty-five stages.

NEW IN 6.145.0 — THE SETUP DOOR RETIRES; THE SHEET NAMES TRIPLE-PRESS:
  🪦 LL, straight after the 6.144.1 ship: "Ok, remove it and rollback
     changes. But, please add triple press to the cheat sheet, the
     native mac shortcut." Done, both halves. _G.monoSetup() is GONE —
     the console door, the veil.monoSetup service, the 🛠 "Set up
     grayscale (once)" row in ⇪;, and the open(1) task that 6.144.1
     had just added to make the pane-open work. The one-time Color
     Filters tick was always LL's to make (the 6.82.0 finding), it was
     already made by hand, and triple-pressing Touch ID — macOS's own
     trigger for the same Accessibility Shortcut — covers the walk to
     the pane without Hammerspoon's help. ⇪9 STAYS: it posts the true
     F5 keycode beneath the media-key layer and was never the
     complaint — it is the half LL called "mine that we built in".
  ⌨️ THE CHEAT SHEET NAMES THE NATIVE ROUTE. The Screen Veil box gains
     a "3× Touch ID" row — grayscale natively, triple-press Touch ID,
     macOS's own shortcut — beside ⇪9, and its note now names the
     by-hand setup (tick Color Filters ALONE under Accessibility →
     Shortcut) instead of pointing at a door that no longer exists.
     Every other text that pointed there — monoReport's tail, the
     read-back's "nothing changed" alert, the ⇪; mono row's subtitle —
     now names the pane, or the triple-press, by hand.
  🧪 THE RETIREMENT IS PINNED, NOT JUST DONE: test_features holds the
     global gone, the service gone, the name out of screen_veil's
     source, the whole run opening zero URLs, and the Touch ID row
     present on the sheet; test_power_tools holds the ⇪; palette at
     sixteen rows with monoset refused by the exact-set check.
  ⚖️ KEPT, DELIBERATELY — the one part of 6.144.1 that does not roll
     back: the ⇪, repair. settings_panes still goes through
     /usr/bin/open with the exit code read and hs.urlevent banned by
     its suite. Reverting that would re-brick URL rows that had never
     opened in the first place; it is a separate tool's real bug fix,
     not part of the setup door, and it stays.

NEW IN 6.144.1 — THE SETTINGS DOOR THAT NEVER OPENED:
  🚪 LL, with the Color Filters screenshots and their console open:
     "Hmmm... the Mac shortcut doesn't work same as mine that we built"
     — and above it, the line that cracked the case:
     "ERROR: urlevent: hs.urlevent.openURL() called for a URL that
     lacks '://'", printed by _G.monoSetup(). Verified against
     Hammerspoon's own source: hs.urlevent.openURL REFUSES any URL
     without '://' — it logs exactly that line and returns false
     without opening anything — and every x-apple.systempreferences:
     destination is exactly that shape. So monoSetup's pane-open had
     NEVER worked, from 6.140.0 to 6.144.0: the walkthrough alert
     showed, System Settings stayed shut, and the instructions only
     ever landed because LL walked to the pane by hand.
  🚨 AND THE SAME LANDMINE SAT UNDER ⇪,. settings_panes wrapped the
     same call in a pcall with an hs.execute fallback below it — but a
     REFUSAL IS A RETURN VALUE, NOT A THROW. The pcall reported
     success, the fallback never ran once, sp.opens counted a pane
     that never opened, and every URL row of ⇪, was silently dead
     while reporting itself fine. The two disk-pane rows (which used
     open(1) directly) were the only ones actually opening — which is
     precisely the kind of partial failure that looks like "it works
     sometimes" and never gets reported.
  🔧 THE FIX IS THE BORING, CORRECT ONE: everything goes through
     /usr/bin/open now. One hs.task per open, the destination as a
     single ARGUMENT (an array, the net_tools rule — no shell, no
     quoting to get wrong), and open(1) takes a Settings URL and a
     .prefPane path alike, so the branch the old code needed is gone
     with the bug. Failure is read from the exit code — the only
     place open(1) reports it — and a refused pane now says so out
     loud (alert + sp.lastNote) instead of counting as a success.
     settings_panes no longer contains hs.urlevent OR hs.execute at
     all. screen_veil's monoSetup opens the Color Filters pane the
     same way, and says so honestly if even open(1) is refused.
  ⌨️ THE ANSWER TO THE ACTUAL QUESTION, for the record: nothing in
     LL's setup was wrong — both screenshots showed it done exactly
     right (Color Filters on, Grayscale, the ONLY feature ticked
     under Shortcut). On the built-in keyboard the key printed F5 is
     the dictation/media key, so a bare ⌥⌘F5 never reaches the
     Accessibility Shortcut at all — the by-hand chord is Fn⌥⌘F5, or
     triple-pressing Touch ID. ⇪9 posts the TRUE F5 keycode in
     software, beneath the media-key remapping, which is why the key
     we built works where the printed chord does not. ⇪9 stays the
     reliable switch; this is a point for it, not against it.
  🧪 test_settings_panes rewrote its opening section: one open(1)
     task per open, URL as the single argument, the refusal callback
     announces, and the hs.urlevent door is pinned shut twice — the
     stub records any call to it (must stay at zero for the whole
     suite) and the shipped source is checked to contain neither
     hs.urlevent nor hs.execute. test_features' monoSetup check now
     proves the pane opens through open(1) and that nothing touched
     the URL handler.

NEW IN 6.144.0 — BATTERY SAVER: ON BATTERY, THE CONFIG SLOWS ITSELF:
  🔋 LL: "Ok, now I need a tool that when I am only on battery power,
     I lower the battery consumption. … DO not propose screen dimming.
     I can do that on my own. Let's be creative, but aim for
     stability." Two halves came out of that sentence — one turns the
     config's own cost down, one names where the real battery goes.
  🐢 ECO MODE, THROUGH A REGISTRY. modules/battery_saver.lua plus an
     eco registry in init.lua, beside the service registry and built
     on the same one-way contract: the code that OWNS each timer
     declares a normal and a battery cadence and an apply function
     that rebuilds its own timer; battery_saver only says WHEN.
     Nothing ever reaches into another module's timer. On battery:
        clipboard poll        0.5s → 2s   — the biggest constant cost
                              in the whole config: 7,200 wake-ups an
                              hour become 1,800; the worst case is a
                              copy taking 2s to reach ⇪V's history
        injection watchdog    5s   → 60s
        autocorrect watchdog  30s  → 120s — a tap macOS kills stays
        expander watchdog     30s  → 120s   dead up to 2 min, said
                                            plainly in both modules
        activity poll         5s   → 15s  — boundaries up to 15s
                                            coarser; durations, idle
                                            credit and the lock
                                            watcher are untouched
        focus detection       4s   → 12s  — joining is still instant
                                            (app watcher); leaving is
                                            noticed up to 12s late
     and the Spotlight boot scan — the priciest periodic thing this
     config runs — WAITS: the CSV cache serves ⇪I exactly as it does
     in the first seconds of every boot, opening the panel still
     scans when stale (that is you asking), ⇪⇧I still forces one,
     and the deferred scan fires by itself when the cord is back.
     Every cadence is restored the moment AC returns.
  📢 THE HOG CALLER-OUT. The real battery goes to other apps, so on
     battery only, one out-of-process ps (argument array, no shell)
     every 4 minutes watches for an app holding over 60% CPU across
     two consecutive samples — and NAMES it in a notification, once
     per app per hour. Dropping under the line resets the strikes
     but never the mute, so an app sawing across the threshold is
     still one name an hour. It never kills anything: ⇪⇧; is the
     hammer, and it stays yours. _G.battReport() adds the numbers —
     charge, drain in mA, time left, the last sample's top five.
  ⚖️ STABLE BY CONSTRUCTION, which was the brief:
     · EVENT-DRIVEN — hs.battery.watcher fires only on a power
       change; on AC this module adds ZERO periodic work.
     · DEBOUNCED — power must hold 20s before cadences flip, so
       briefly unplugging to move to the couch changes nothing. Boot
       skips the debounce: a Mac that boots on battery IS on
       battery, and late (warm-phase) registrations are caught by
       the registry itself, which applies the active cadence to
       arrivals.
     · STATE-PRESERVING — every rebuild keeps the running/stopped
       state it found, so the lag probe's held-down watchdogs stay
       held down through a flip (core/lag.lua stops and restarts
       them BY NAME; the new object sits under the old name).
     · A DESKTOP IS A NO-OP — the power source never reads Battery
       Power, the watcher never fires, the module loads and sleeps.
       The work Mac needs no profile override.
  🚫 DELIBERATELY NOT DONE, each a decision: no screen dimming (LL's
     own, by request); no pmset / macOS Low Power Mode toggling — it
     needs root, meaning a password prompt on every unplug or a
     sudoers edit, both against this config's security posture, and
     System Settings already offers Low Power Mode "Only on Battery"
     natively (set it once by hand); no killing, pausing or renicing
     of other apps, ever.
  🖥 Console doors: _G.eco() what is slowed right now and by how
     much · _G.battReport() · _G.ecoOn() / _G.ecoOff() force it
     either way · _G.ecoAuto() hands control back to the cord.
  🧪 tests/test_battery_saver.lua (53 checks) drives the debounced
     flip, the flap that must flip nothing, exact-cadence restore,
     boot-on-battery, the hog strikes and the once-an-hour mute, the
     forced modes and the no-battery stand-down — against the eco
     registry EXTRACTED from init.lua's real source, so a drifted
     stub fails the suite. Source sentries pin all seven shipped
     registrations by name and pin that each rebuild preserves
     running state. test_integration's clipboard sentry learned the
     poll body's new named-function shape and still proves the
     changeCount advances before the suppression check.

NEW IN 6.143.0 — DIALOG HOME: DIALOGS LAND AT YOUR SPOT:
  🎯 LL, with a screenshot of Finder's "A folder named 'core' already
     exists in this location. Do you want to replace it…" box: "Can we
     capture this kind of window and make it appear in the same place,
     on my primary monitor?" That is the dialog every install of this
     very config produces — drag the zip's folders into ~/.hammerspoon
     and Finder asks about `core` and `modules` in a box that opens
     wherever the app feels like putting it. macOS gives you no say;
     on two monitors you hunt for the question before you can answer
     it. Now you don't: modules/dialog_home.lua, automatic, no key.
  🪟 WHAT COUNTS AS "THIS KIND OF WINDOW": role AXWindow with subrole
     AXDialog or AXSystemDialog — the accessibility API's own word for
     a dialog — plus standard windows that declare themselves MODAL (a
     dialog in a window's clothing; dh.alsoModal turns that rule off).
     Sheets are never touched: they are glued to their window's title
     bar and belong to it, not to a spot. Anything dialog-flagged but
     bigger than 60% of the screen is left alone, and a window whose
     size cannot be read is left alone honestly rather than flung.
  🎯 WHERE THEY LAND: one spot. Default — centred, a little high (the
     place macOS puts alerts), on the PRIMARY monitor: the menu-bar
     screen from System Settings → Displays, hs.screen.primaryScreen,
     NOT mainScreen (that is the focus-follows-you behaviour being
     replaced, and the suite pins the difference on two stub screens).
     Every move is verified a beat later and re-applied once if the
     app snapped its dialog back — the 6.123.0 VLC lesson: a move that
     silently did nothing looks identical to success until you look
     again. A dialog that refuses twice goes on file, not on retry.
  🖐 THE CAPTURE IS LITERAL. Drag any dialog somewhere better: when
     the drag goes quiet (debounced — AXWindowMoved fires per step,
     one drag must be one capture, not two hundred), that position
     becomes the new home, persisted in hs.settings and validated on
     the way back in like every remembered position in this config (a
     NaN or a half-written blob reads as NO spot). The module's own
     moves open a suppression window first, so its AXWindowMoved echo
     can never read as your drag — break-tested: removing that guard
     fails exactly one check. _G.dialogHome.reset() forgets the spot.
  ⚖️ WATCHED THE ONLY WAY THIS CONFIG ALLOWS. Not hs.window.filter —
     that module subscribes to every window of every app, froze this
     Mac for 44 seconds once (window_switcher's header tells it), and
     is banned with sentries; dialog_home now sits IN that sentry
     sweep by name, since watching windows appear is that API's
     textbook bait. Instead: ONE Accessibility observer on the
     FRONTMOST app, re-attached as you switch (copy_on_select's shape
     since 6.55), every element behind an AX timeout (the wedged-app
     rule), no polling, no keyboard taps. The honest limit: a dialog
     popping in a BACKGROUND app is placed the moment you switch to
     that app — attach() sweeps that one app's windows, measured, and
     a slow app is named (Window Return's rule). Apps that refuse a
     watcher are recorded once per session, not once per activation.
  🔎 _G.dialogs() answers before you ask twice: the home screen, the
     spot and whether it was captured or default, the LAST window
     seen with its subrole — so a dialog that slipped through teaches
     you the exact string to add to dh.subroles — and who refused.
     Accessibility off: the module stands down completely and
     _G.dialogs() says why, the Window Return way. New suite
     test_dialog_home (52 checks) joins the gate; off switch:
     dh.enabled = false in the EDIT HERE.

NEW IN 6.142.0 — THE NUMBER-ROW LAYER COMES OUT; FREE KEYS GET A LEDGER:
  🆓 LL, with a screenshot of the "NO NUMBER PAD" cheat sheet box:
     "These shortcuts were supposed to be cleaned, cleared and the
     keys listed as future possible options for keyboard shortcuts.
     Like we just used ⇪9 on the keypad for grayscale." Both halves,
     done.
  🧹 CLEANED AND CLEARED. numpad_layer's 6.114.0 laptop layer — the
     ⇪⇧ number-row mirror of the pad window map — is GONE: the
     rowActions table is deleted (not parked; a parked table is a
     claim you have to remember not to believe), its ten bindings are
     unbound, and the count check drops 33 → 23 so the clearing stays
     cleared. ⇪⇧1 2 3 5 7 8, ⇪⇧comma, ⇪⇧period and ⇪⇧return are
     future shortcut options now. The pad window map (⇪⇧pad) and the
     capture row (⇪pad) are untouched; on a laptop the halves,
     maximise, put-back and monitor moves remain on ⇪← ⇪→ ⇪↑ ⇪↓ and
     ⇪[ ⇪] — the quarters and centre are pad-only again, a documented
     hole rather than nine spent keys. The layer's old cheat sheet
     box became the ledger that says where its keys went.
  🔄 AND THE KEY THAT LAYER BLOCKED IS RELEASED: ⇪⇧9 = Invert
     colours (relays ⌃⌥⌘8) — the exact pick from 6.141.0 that the
     no-two-owners sentry refused while the row owned the key. The
     sentry was right both times: it guards owners, and the owner
     changed by LL's word, not by a quiet steal. test_features flips
     the 6.141.0 pin — ⇪⇧9 must now BE the veil's invert, and the
     other freed row keys must claim nothing.
  📋 LISTED, NOT REMEMBERED: _G.freeKeys(), also the 🆓 row in ⇪;.
     Prints every unclaimed ⇪ / ⇪⇧ / pad key and copies the list —
     READ from _G.hyperBound, the live registry the conflict sentry
     trusts, never from documentation, because a hand-made survey is
     exactly what missed ⇪⇧9 in 6.141.0 (the row built its claims in
     a loop; no literal "⇪⇧9" existed to grep). A chord-forwarded
     plain key counts as free and says what claiming it costs; pad
     keys this Mac cannot send are named, not listed (the ⇪pad+
     rule); ⇪⇧Z is shown reserved, never free: "We will use that
     later."

NEW IN 6.141.0 — GRAYSCALE GETS ITS KEY: ⇪9 TOGGLES:
  🌑 LL: "why am I not using some hyperkey combo for my new
     grayscale?" Fair question. 6.140.0 shipped it keyless because
     every ⇪ letter was already claimed and the judgment was that
     ⌥⌘F5 — which IS a dedicated grayscale key on the keyboard once
     the one-time setup is done — plus the ⇪; rows covered an
     occasional toggle. LL wanted a key anyway and picked ⇪9, with
     ⇪⇧9 for invert (⇪1 and ⇪3 remain the last free plain keys;
     ⇪⇧Z stays reserved at LL's earlier ask).
  🚨 AND THE SENTRY EARNED ITS KEEP. The first draft bound both keys
     and the integration suite's NO-TWO-OWNERS check refused to ship
     it: ⇪⇧9 has been the numpad laptop row's TOP-RIGHT window key
     since 6.114.0 — the same collision family the sentry caught on
     ⇪⇧4 back then, and precisely the silent theft it exists to
     prevent. numpad_layer's own rule stands: a documented hole
     beats a stolen key.
  ⌨️ SO: ⇪9 = grayscale on/off — relays ⌥⌘F5 and keeps the honest
     read-back; it lives in screen_veil.lua beside ⇪G. Invert keeps
     its ⇪; row plus ⌃⌥⌘8, which macOS ships already bound — a
     hyper relay for it would spend a key on a key. The ⇪; mono row
     names ⇪9 in its sub line. Setup stays keyless on purpose — it
     is run once per Mac, ever: _G.monoSetup(), one tick, yours.
  🧪 test_features 4b fires ⇪9 through the stub and checks ⌥⌘F5
     comes out the other side — and pins that the veil never claims
     ⇪⇧9, so this exact collision cannot come back quietly.

NEW IN 6.140.1 — THE WORK MAC BACKS UP DOCUMENTS TOO:
  ☁️ LL: "For my work computer, all documents are safe to backup."
     6.139.0 had guessed the other way and set docs = false in the
     work profile so Documents/Desktop would stay in the company's
     OneDrive. That override is now REMOVED: both Macs build the full
     rebuild kit — Documents and Desktop included. One profile line
     changed; the docs knob itself stays in daily_backup.lua for any
     future Mac that needs it, and test_daily_backup still proves it
     drops exactly Documents and Desktop when set.
  📁 First work-Mac run note: macOS gates Documents/Desktop behind
     Full Disk Access. If the run reports "grant Hammerspoon Full
     Disk Access", that is the whole fix — the report names it rather
     than failing quietly, exactly as 6.139.0 built it to.

NEW IN 6.140.0 — GRAYSCALE, AT LAST: PRESS THE KEY macOS OWNS:
  🌑 6.82.0 removed a grayscale toggle after four failed routes —
     defaults write, launchctl, killall, osascript. That verdict
     stands: all four tried to SET the setting, and macOS does not let
     a process do that. The route none of them tried: press the key
     macOS is already listening for. The Accessibility Shortcut ships
     bound to ⌥⌘F5, and when Color Filters is the ONLY feature ticked
     under Accessibility → Shortcut, ⌥⌘F5 stops opening a chooser
     panel and becomes a direct grayscale toggle handled inside
     WindowServer — below every app, which is exactly the place a
     Hammerspoon canvas can never reach (the 6.82.0 header explains
     why a canvas can dim and mute but never desaturate).
  ⇪; gains three rows: Grayscale on/off · Set up grayscale (once) ·
     Invert the screen colours (⌃⌥⌘8 — inversion, not grayscale, but
     the one colour change that needs no setup at all). Console doors:
     _G.mono() · _G.monoSetup() · _G.monoReport() · _G.invertColours().
     No new ⇪ key; grayscale does not earn one. The rows hold no logic:
     power_tools relays by service name (pt.veilCall → veil.mono /
     veil.monoSetup / veil.invert) and says so plainly when the Screen
     Veil module is not loaded.
  🛠 THE ONE-TIME TICK IS YOURS. _G.monoSetup() opens the right pane
     and names the three ticks — Color Filters on, type Grayscale,
     then under Shortcut tick Color Filters and UNTICK EVERYTHING
     ELSE — and gets out of the way. Making that tick is precisely the
     step 6.82.0 proved a program cannot take.
  🔎 THE READ-BACK IS HONEST. 0.6s after the keypress the module reads
     the PREFERENCE FILE (one /usr/bin/defaults read of the whole
     com.apple.universalaccess domain — never a write; test_features
     4b pins that structurally, and launchctl/killall stay banned
     config-wide by test_diagnostics 9a) and reports what it found:
     grayscale on, colour back, "a filter is on but not grayscale", or
     "run _G.monoSetup() once". Never a success it cannot see, and the
     report says in as many words that it read a preference file, not
     the screen.
  ⌨️ Both keystrokes are posted with an explicit 0 delay — the
     hs.eventtap.keyStroke default is 200ms of blocked main thread,
     and after the lag month that default is not welcome here. The
     read-back timer is HELD in veil.monoTimer per the 6.33.0 rule.
  🌗 The veil (⇪G) is unchanged and the two stack: veil for
     brightness, Color Filters for colour.

NEW IN 6.139.0 — THE REBUILD KIT: A CLEAN INSTALL IN ONE FOLDER:
  ☁️ LL: "Is there a way for Hammerspoon to backup my user directory
     for future OSX installs, my applications directory using homebrew
     as much as possible, but a better method that also accounts for
     apps homebrew can't install, all to my OneDrive?" The Daily
     Backup module — 68 lines that had copied ~/.hammerspoon at 5 PM
     since §1.7 was a section of init.lua — grew into the answer.
     Same timer, same destination, same excluded token; a far bigger
     kit.
  📦 WHAT LANDS IN OneDrive/Backups/Hammerspoon/<Mac>/ EVERY DAY:
     · the config, exactly as before (secret.lua excluded)
     · RebuildKit/dotfiles — .zshrc, .zprofile, .gitconfig, .config/,
       and ~/.ssh/config (the settings FILE; the keys beside it are
       never touched)
     · RebuildKit/LaunchAgents and RebuildKit/Fonts
     · RebuildKit/Documents and Desktop (home Mac; see the work note)
     · RebuildKit/Brewfile — brew bundle dump: formulae, casks, taps,
       Mac App Store apps
     · RebuildKit/apps.csv — EVERY installed non-Apple app with
       version, bundle id, and its way back: app-store (a receipt in
       the bundle proves it), homebrew (a cask this Mac owns), or
       direct (reinstall from the vendor — the honest rows)
     · RebuildKit/README.md — the restore guide, REWRITTEN WITH REAL
       NUMBERS after every run, so future-LL on a blank Mac follows
       instructions that describe this kit, not a generic hope. Steps:
       OneDrive down, brew, brew bundle, walk the direct rows, copy
       dotfiles, copy the config, recreate secret.lua by hand, grant
       the permissions ⇪⇧D lists.
  🧭 DELIBERATELY A KIT, NOT A MIRROR. Time Machine (an external
     drive) stays the byte-for-byte, versioned safety net; OneDrive
     gets the curated set a clean install cannot get anywhere else.
     A whole home folder synced to OneDrive fails in practice — file
     counts, caches, node_modules — and sync is not backup: it
     replicates a deletion as faithfully as an edit.
  🚨 WHAT NEVER LEAVES THE MAC, BY DESIGN: secret.lua (excluded on
     the config entry AND in the global exclude list every rsync
     carries — belt and braces), private SSH keys, the Keychain.
     test_daily_backup holds each of these as law: the kit table may
     not contain the .ssh folder, an id_rsa path, or a Keychain path,
     and every rsync's argument array must carry
     --exclude secret.lua.
  🍺 _G.backupAdopt() — THE BETTER-THAN-BREWFILE MOVE. brew bundle
     only records what brew installed. Adoption closes the gap: the
     apps marked `direct` in the manifest are checked against brew's
     cask index, and every exact match is printed as the ready-to-run
     line `brew install --cask --adopt <token>` — Homebrew takes over
     the copy already in /Applications without reinstalling it, and
     the Brewfile covers it forever after.
  ⏱ NONE OF IT TOUCHES THE KEYBOARD. Every rsync and every brew call
     is an hs.task with an argument ARRAY (the net_tools rule — no
     shell strings, no quoting bugs), strictly one at a time with a
     breath between steps; the app scan reads Info.plists a slice per
     step instead of ~80 in one gulp. Built three releases after the
     6.137.0 lag post-mortem and tested to never reintroduce it: the
     suite greps the shipped file for io.popen / os.execute /
     hs.execute and fails if one appears.
  🏢 THE WORK MAC RUNS THE SAME FILE, SMALLER. §0.1 lands it on
     whatever OneDrive that machine has; its profile sets docs=false
     so Documents/Desktop stay out (they live in the company's own
     OneDrive already, and a personal backup habit on a managed Mac
     should stay inside the lines); no Homebrew → the Brewfile step
     stands down and the report says so; a folder Full Disk Access
     won't open is recorded as partial WITH the fix named, never a
     crash. A missing source is "not on this Mac", never a failure.
  🧰 TWO NEW ⇪; ROWS, NO NEW KEY: "Back up now — the rebuild kit" and
     "Backup report". A backup is run by hand twice a year; that does
     not earn a ⇪ letter. Console: _G.backupNow() · _G.backupReport()
     · _G.backupAdopt(). The report names the destination, the last
     run's per-area outcome, and the manifest count; a kit older than
     3 days is called out at boot.

NEW IN 6.138.0 — THE WHEEL FOLLOWS THE DRAG:
  🖱 LL, the day after the lag fix: "I can no longer use my magic pad
     to scroll the list. Keyboard works fine." And then, having tried a
     fresh open and a drag: "Seems like a drag kills the sheet
     functionality."
  🎯 THE BUG WAS A RECTANGLE LEFT BEHIND. The cheat sheet's wheel
     handler only claims a scroll when the pointer sits inside st.rect
     — that is what lets the window UNDER the open sheet keep scrolling
     normally. Dragging the sheet (6.67.0) moved the canvas but never
     moved that rectangle: after a drag, two-finger scrolls over the
     sheet landed "outside" and were declined, while scrolls over the
     empty desk where the sheet USED to be were still being swallowed.
     Closing and reopening rebuilt the rectangle, which is why the
     fault healed itself just often enough to be confusing.
  ⌨️ WHY THE KEYBOARD NEVER NOTICED: the arrow keys scroll through
     hotkeys, a separate route with no hit test at all. "Keyboard works
     fine" was the fingerprint that ruled out everything else.
  🔎 DIAGNOSED BY MEASUREMENT, THE 6.137.0 WAY: a temporary spy tap on
     LL's Mac counted 356 scroll events delivered with 246 passing the
     hit test — macOS 27 was delivering every event, the sheet's tap
     was alive, and the rectangle left at the old spot was the whole
     story. The spy disarmed itself after 25 seconds.
  ✅ ONE FIX, WHERE THE DRAG ENDS: the sheet's drop handler now writes
     the dropped frame into st.rect alongside the position it already
     remembered — verbatim, not clamped, because the hit box must match
     the canvas wherever the drag physically left it.
  🛡 test_cheatsheet: dropping the sheet must move the wheel's hit box
     with it, and the wheel must be claimed at the new position with no
     reopen in between.

NEW IN 6.137.0 — THE LAG, FOUND AND KILLED. IT WAS NEVER A TAP:
  🎯 MEASURED AT LAST, AND THE TAPS WERE INNOCENT. The probe's own
     report on LL's Mac: all five keyboard taps together cost 0.08ms
     per keystroke. The stalls were a TIMER — focus_mode's meeting tick
     blocked the one thread ~1,549ms EVERY 4 SECONDS, like clockwork
     (stall log: 17:45:50, :54, :58, 17:46:02 …). Direct timing then
     pinned the exact line: hs.application.get("Microsoft Outlook") =
     2,884ms, then 3,023ms, per call, with Outlook not running. On
     macOS 27 a name lookup that MISSES takes hs.application's slow
     "alternate names / Spotlight" resolution path every time — a miss
     cannot be cached, so an idle Mac paid the most, forever.
  ⌨️ WHY A TIMER READS AS TYPING LAG. Every keystroke visits five event
     taps, and each tap is a round trip through Hammerspoon's ONE
     thread. Freeze that thread 1.5 seconds in every 4 and keystrokes
     queue behind the freeze: typing turns to sludge, quitting
     Hammerspoon fixes it instantly — LL's report, word for word. The
     control test proved the other half: TEN do-nothing taps on an
     empty config typed perfectly clean. Taps are cheap. The thread
     they all share was the whole story.
  🧪 THE METHOD IS THE ACTUAL NEWS. 6.131.0–6.136.0 shipped four
     releases of instrument-building and guesswork; the lag survived
     all of them. 6.137.0 came from three measurements LL ran in the
     console — the probe report, a 5ms bulk sweep, a 3s name lookup —
     and the fix was not written until the numbers named the line.
  ✅ THE CURE IS THE 6.16.22 IDIOM, APPLIED THREE TIMES OVER:
     · focus_mode: Outlook now comes out of the bulk
       runningApplications() sweep the meeting detector already runs
       (5ms for 128 apps, measured), stashed in fm._outlook — never
       looked up by name. Budget-exhausted sweeps skip the reminder
       scan for one 4s tick rather than risk a stale answer.
     · power_tools: the pause key asks one bulk sweep instead of
       get() per toggle-only player, so it no longer hangs for seconds
       precisely when no player is open.
     · window_return: the 30-second snapshot was one 1,586ms
       hs.window.allWindows() gulp — the same freeze at a lower dose.
       It now walks ONE app per 0.05s step, regular GUI apps only
       (background agents get no Accessibility round trip), abandons
       uncommitted when a monitor change lands mid-sweep, keeps a
       per-app ms profile in wr.lastSweep, and names any app slower
       than 250ms in the console — the next fix gets a name, not a
       guess.
  🛡 AND IT STAYS DEAD. test_focus P7 fails the suite if focus_mode
     ever calls hs.application.get/find again (a call counter AND a
     comment-stripped source grep); test_power_tools counts get()
     calls and demands zero; test_window_return proves the snapshot
     never asks for the whole desktop at once, never sweeps an agent,
     commits nothing before its steps run, and abandons cleanly on a
     mid-sweep monitor change.

NEW IN 6.136.0 — THE PROBE WAS THE PRIME SUSPECT, SO IT IS NOW OFF:
  🚨 THE LAG PROBE IS THE LEADING SUSPECT FOR THE LAG IT WAS BUILT TO
     FIND. LL: "total shit show. All kinds of keys stopped working" and
     "once I start Hammerspoon, I'm fucked." core/lag.lua shipped in
     6.131.0 — exactly the window LL had already described as "the last,
     at least two versions". Three releases (6.131.0, 6.134.0, 6.135.0)
     were spent building better instruments on top of that file without
     once testing the instrument itself.
  📝 IT WAS WRITTEN DOWN AND NOT ACTED ON. core/lag.lua's own comment at
     the install call reads: "this file was added in 6.131.0 and the lag
     was reported again in 6.133.0." The coincidence was noticed, typed
     into a source file, and then built past.
  🔍 THE MECHANISM. install() replaces hs.eventtap.new for the whole
     session, so EVERY tap in the config gets an extra Lua closure
     between macOS and the real handler, and each of those closures does
     two clock reads, four table writes and a comparison ON EVERY
     KEYSTROKE. With five always-on keyboard taps that is five closures
     and ten clock reads per character typed. installTimers() does the
     same to every repeating timer.
  💣 AND THEN THE SECOND-ORDER EFFECT, WHICH IS THE ONE THAT BITES.
     macOS DISABLES an event tap whose callback takes too long. That is
     not a theory — it is the documented reason text_expander and
     autocorrect each run a watchdog to restart a stopped tap. A probe
     that makes every callback slower can push taps past that timeout:
     macOS kills them, the watchdogs revive them, they are killed again.
     From the outside that is "all kinds of keys stopped working".
  🔒 AND THERE WAS NO WAY TO SWITCH IT OFF. _G.lagQuiet() stops the
     probe's heartbeat and NOT the wrapper, so the expensive half — the
     part sitting on the keystroke path — ran no matter what was typed
     into the console. The only honest way out was deleting the file.
     6.135.0 spent an entire release on the difference between a tap
     that is INERT and one that is GONE, and never noticed that the
     probe only ever offered itself the weaker of those two. The same
     trap, one level up.
  🧨 THE 6.131.0 REASONING, AND WHERE IT WENT WRONG. That release argued
     the probe must be "ALWAYS ON, DELIBERATELY", because lag that comes
     and goes is not reproducible on demand and the evidence has to
     already exist by the time you think to look. That is sound for an
     intermittent fault. It is wrong here for two reasons: the cost of
     always-on was asserted ("two clock reads per event") and never
     measured, and LL's lag turned out to be constant from launch — so
     the tradeoff bought nothing and charged full price.
  ✅ SO: NO FILE, NO PROBE. core/lag.lua now installs nothing at all
     unless ~/.hammerspoon/LAGPROBE exists. Same shape as SAFE mode,
     deliberately: a file whose existence is the whole message, checked
     once at load, with nothing inside it to get wrong. A file rather
     than a setting because the state that matters is "what happens at
     the next launch", and a file is the one thing you can still change
     when the keyboard is the broken part.
  🎛 _G.lagOn() writes the file, _G.lagOff() removes it. Both require a
     reload and say so: install() must run before the first tap is
     created, so arming a live session is impossible, and reporting
     "armed" while the wrapper is not in place would be exactly the
     class of confident-wrong-answer 6.135.0 was written to prevent.
  📋 _G.lagReport() LEADS WITH "THE PROBE IS DISARMED" when it is off. A
     disarmed probe has an empty tap table and a zero count, which reads
     precisely like "measured everything, found nothing" — the most
     misleading thing this report could say to someone whose typing is
     broken. It now says the empty tables mean NO DATA.
  🩹 EMERGENCY PATH, for a machine that is already unusable: quit
     Hammerspoon, then
        mv ~/.hammerspoon/core/lag.lua ~/.hammerspoon/core/lag.lua.off
     init.lua loads that file inside a pcall, so its absence is a
     printed warning and nothing else — all 58 modules still load.
  🚑 AND SAFE MODE NOW OUTRANKS THE ARMING FILE. init.lua loads
     core/lag.lua at line ~641 and does not check for the SAFE file
     until line ~3290, so for its whole life SAFE mode cut the module
     list from 58 to 4 and left the probe wrapping every tap that
     remained. That made SAFE mode unable to answer the one question it
     exists for: fewer modules also means fewer taps for the probe to
     wrap, so the two explanations move together and neither can be
     ruled out. SAFE now means safe — no instrument on the keystroke
     path, whatever the arming file says — and the report says so, with
     the way back out, for anyone reading it mid-diagnosis.
  🧪 test_lag 206 → 236 checks. §18 asserts that a disarmed probe leaves
     hs.eventtap.new as the SAME function object — not "equivalent",
     untouched — wraps nothing, records nothing, and starts no heartbeat.
     Three new break tests: R inverts the gate (the 6.131.0 behaviour,
     which must never be reachable by accident again), S makes armed()
     answer true with no file present, T drops the disarmed banner so an
     empty report looks innocent, U removes the SAFE-mode override.
     62 stages green.

NEW IN 6.135.0 — THE STRONGER DOSE, AND A TEST THAT COULD HAVE LIED:
  🔌🔌 _G.lagTapsGone() STOPS EVERY KEYBOARD TAP FOR REAL.
     6.134.0 shipped _G.lagTapsOff(), which makes each tap's callback
     INERT — it returns immediately without ever running the module's
     handler. That was the right answer to a specific hazard: text_expander
     and autocorrect each run a 30-second watchdog that finds a stopped tap
     and starts it again, so a stop-based test would have silently undone
     itself mid-experiment.
  🚨 IT WAS ALSO A TRAP, AND THAT IS THE REAL NEWS IN THIS VERSION.
     An inert tap IS STILL A TAP. It is still registered with macOS, and
     the keystroke still travels through the event-tap machinery to reach
     it — it just meets a function that returns straight away.
     That measures what our CALLBACKS cost. It cannot measure what HAVING
     FIVE TAPS costs, and those are different numbers: the dispatch itself
     has a price, secure input degrades every tap at once, and a stale
     Accessibility grant can make the whole mechanism crawl with no
     callback being slow at all.
     So "I ran lagTapsOff and nothing changed" would have been read as
     "the taps are innocent" in exactly the case where the taps are the
     entire problem. A confident wrong answer — which core/lag.lua's own
     header calls worse than no answer — reached by a road nobody had
     walked down when the switch was designed.
  🐕 SO tapsGone HOLDS THE WATCHDOGS DOWN FIRST, by name (_G.expanderWatchdog,
     _G.autocorrectWatchdog), and only then stops each keyboard tap.
     Stopping a tap while its watchdog is still running is a race the
     watchdog wins inside thirty seconds. They are reached by global name
     rather than through a new module API, because the modules must not
     gain a "please stop watching" entry point that ships forever for the
     sake of one diagnostic.
  ↩️ AND IT RESTORES ONLY WHAT IT STOPPED. Each record remembers whether
     its tap was running when the test began. screenshots' select-mode tap
     spends nearly all its life stopped, and a restore that started it
     would switch on something the config had deliberately switched off.
     The mouse tap is never touched: this is a question about typing.
  ⏲ Same self-restoring timer as tapsOff, same default of 90 seconds, and
     the same loud warning if the timer fails to arm — with the taps gone,
     ⇪ does nothing, so the Console is the only way back.
  🔒 THE REPORT NOW NAMES SECURE INPUT. macOS turns it on for password
     fields, and an app that quits badly can leave it on for everybody
     afterwards. While it is on, every tap is being throttled by the OS —
     an OS-level fact about all of them at once that no per-tap number can
     show, and that bisecting one tap at a time will never find, because
     none of them is individually at fault.
  📝 AND THE "NEXT" BLOCK STOPPED OVERCLAIMING. It used to say "Still
     slow? It is not a tap" after an inert run. It now says that the inert
     result rules out what the callbacks DO, not the taps themselves, and
     points at _G.lagTapsGone() as the next step.
  📋 Run them in order: _G.lagTapsOff() first, _G.lagTapsGone() only if
     the first one changed nothing.
  🧪 tests/test_lag.lua grows to 206 checks: §16 covers the stronger dose
     (taps stopped not inert, mouse tap untouched, an already-stopped tap
     left alone, watchdogs held and released, the restore timer, both
     report banners, all three secure-input states) and §17 adds four
     break tests — N: the watchdogs are not held down; O: restore starts
     every tap rather than the ones it stopped; P: lag.gone is never set
     so the taps never come back; Q: the report describes a stopped config
     as merely inert.

NEW IN 6.134.0 — THE SWITCH, NOT JUST THE GAUGE:
  ⌨️ LL: "We have a problem. Since the last, at least two versions, once
     I launch Hammerspoon my typing goes very slowly. My typing goes
     from smooth to very slow. I quit Hammerspoon. Then, back to normal.
     What do you need from me?"

  🔍 FIRST, WHAT IT IS NOT — checked before a line was written, because
     the cheapest fix is the one you do not build. 6.132.0 added
     text_case, which touches no hs API at all and cannot cost a
     keystroke anything. 6.133.0 added define, which does nothing
     whatsoever until ⇪8 is pressed. Neither creates an event tap or a
     repeating timer. Whatever this is, those two versions did not
     introduce it — which also means the report "since the last two
     versions" is measuring when it became UNBEARABLE, not when it
     started.

  🔌 SO THE PROBE GAINS A SWITCH. 6.131.0 built a gauge: it measures
     every tap and every stall and prints a table. A gauge answers "how
     bad" and this problem needs "which one", and the gap between them
     is a controlled experiment nobody could run — because the only
     control available was quitting Hammerspoon, which changes nine
     taps, forty timers and every watcher at once. That proves the
     config is responsible and names nothing inside it.

         _G.lagTapsOff()   every keyboard tap inert for 90 seconds
         _G.lagTapsOn()    undo it now
         _G.lagOnly(n)     exactly one tap runs; the rest stay inert
         _G.lagMute(n)     make one tap inert on its own
         _G.lagUnmute(n)   and put it back

     Type during the window. Whether the lag goes away is the whole
     answer, and it arrives in one round rather than five.

  🚨 INERT, NOT STOPPED, AND THAT DISTINCTION IS THE ENTIRE DESIGN.
     Stopping a tap is the obvious implementation and it does not
     survive contact with this config: text_expander and autocorrect
     each run a 30-second watchdog that looks for a stopped tap and
     starts it again. A test that quietly undoes itself half a minute in
     does not fail — it LIES, and it lies in the direction of "the taps
     are innocent", which is the one conclusion this whole exercise
     exists to test. So the tap keeps running and the WRAPPER returns
     false without ever calling the module's handler. Nothing can re-arm
     what was never disarmed, the keystroke reaches the app untouched,
     and the cost on the normal path is one comparison against an
     upvalue.

  🚨 AND IT RETURNS false, NEVER true. true means "I handled this event"
     and would EAT every keystroke in the config for as long as the
     switch was on. This is a button pressed by someone whose typing is
     already broken; the one thing it must never do is make that worse.

  ⏲ IT PUTS ITSELF BACK. While taps are inert ⇪ does nothing — ⇪ IS a
     tap, and that is precisely the thing under test — so a switch with
     no timer is a switch that can strand you in a config with no
     shortcuts, needing the Console to escape. Ninety seconds by
     default. The worst case is that you wait.

  🔢 THE # COLUMN IS THE CREATION NUMBER, NOT THE ROW POSITION. The
     report sorts by time spent, so a number that meant "third row"
     would name a different tap between reading it and typing it — and
     naming the wrong tap is the only bug a numbering scheme can have.

  ⏱ AND THE TIMERS ARE MEASURED NOW, so "not a tap" stops being a dead
     end. The old report could tell you the one thread blocked for 900ms
     at 14:32 and not one word about what was running; a stall with no
     attribution is a symptom restated, not a diagnosis. hs.timer.doEvery
     and hs.timer.new are wrapped exactly as hs.eventtap.new is, so
     nothing has to register and a timer written next year is measured
     the day it is written. Records are aggregated BY CALL SITE, so a
     timer created in a loop cannot grow the table forever — a leak
     inside the tool whose job is finding leaks. The section totals the
     lot as a share of the one thread, which is the number that actually
     answers "is a timer eating my Mac": a 0.05s timer taking 1ms costs
     2% of the thread forever, while a 60s timer taking 200ms costs 0.3%
     and looks far worse in the max column.

  🚨 hs.timer.doAfter IS DELIBERATELY NOT WRAPPED. It is the one-shot,
     called from alerts, debounces and every deferred paste — often
     several times a second. Resolving a call site costs a stack walk,
     and paying for one on every doAfter would put a real cost on a hot
     path in order to measure cost. A one-shot that blocks the thread
     still appears, as a stall with the time of day beside it.

  🚨 THE PROBE MEASURES ITS OWN HEARTBEAT, UNDER ITS OWN NAME. The site
     walker steps deliberately PAST core/lag.lua so that a module's tap
     is blamed on the module rather than on the probe that wrapped it —
     and that same rule would have filed the probe's own 20-a-second
     timer under init.lua, whoever happened to load core/. A tool that
     cannot be asked whether it is itself the problem is the wrong tool
     for this job, and it is a fair question: this file shipped in
     6.131.0 and the lag was reported again in 6.133.0. _G.lagQuiet()
     stops the heartbeat outright, so the probe can be ruled out rather
     than argued about — at the cost of the stall log, which is why
     lagTapsOff deliberately does NOT do it.

  📋 THE REPORT GOES TO THE CLIPBOARD, and ends by naming the next
     command rather than the next decision. Everything above it is
     evidence, and evidence handed to someone whose typing is broken is
     a second job.

  🔨 FIVE NEW BREAK TESTS, and section 12 is now one of the four in this
     suite marked as having teeth. The switch returns true and eats
     every keystroke. The switch does nothing and reports taps innocent.
     reset() lifts the suspension and silently ends the experiment it
     was called to begin. Timer records key by creation and the table
     grows forever. The heartbeat loses its override and the probe
     exonerates itself. All five pass, which is to say all five caught
     the break.

  🩹 AND ONE TEST THAT WAS ALWAYS WRONG. "The verdict names a keyboard
     tap, never the mouse one" was implemented as "the verdict line does
     not contain 90" — the mouse tap's average. Adding fifty lines to
     the stub moved the heavy tap to line 390, the verdict read
     "test_lag.lua:390", and the check failed over a probe behaving
     perfectly. A test that fails on a line number is a test that gets
     silenced rather than read. It now compares against the sites the
     probe actually recorded.
```

```text
NEW IN 6.133.0 — WHAT IT MEANS, AND WHAT ELSE YOU COULD SAY:
  📖 LL: "I need a way to look up words for their definition and be
     presented at the same time with their synonyms. How can we build
     this?"
  ⇪8 — put the cursor on a word or select it. One list opens holding
     both: every sense of the word with its definition, and under each
     sense the words that share it. ⏎ ON A SYNONYM REPLACES YOUR
     SELECTION WITH IT. Nothing selected opens the box empty; type a
     word and press ⏎. It is also a row on ⇪; and on ⇪space.
  ❓ AND YES, YOUR MAC ALREADY DOES THIS — ⌃⌘D. Apple's Look Up popover
     is good and this does not replace it. Three things it will not do,
     which are the three reasons this exists: the thesaurus is a
     SEPARATE ENTRY you scroll to or click into, and "at the same time"
     was the whole of the ask; you cannot act on it, so reading that
     `terse` is a synonym of `curt` and then retyping it by hand is the
     part that wastes the time; and in a good half of these apps it
     wants the mouse.
  📚 THERE IS NO ONE SOURCE THAT IS PRESENT ON EVERY MAC, offline, free,
     and legally ours to read. There are four partial ones. So the
     sources are a LIST, asked in order, and the panel says which one
     answered:
       1. WordNet (`brew install wordnet`) — offline, one process, no
          network. Not a compromise: its data model IS the thing that
          was asked for — a sense, its definition, and the set of words
          that share that sense. Most dictionaries make you infer that
          pairing; WordNet stores it.
       2. dictionaryapi.dev — definitions and synonyms per sense in one
          keyless call. OFF BY DEFAULT.
       3. Dictionary.app — always there, nothing to install, and Oxford
          rather than WordNet's terser glosses. Not in-panel, so it is
          the floor rather than the answer — the last row always hands
          off to it, even when something else answered.
  🚨 "NO DEFINITION FOUND" IS WHAT A MISSING wn LOOKS LIKE, and it is
     also what a nonsense word looks like — and the first is fixed by
     one brew command while the second is not fixable at all. Every
     provider therefore carries a why() that names the FIX rather than
     the fault, and _G.defineReport() prints which sources this Mac has,
     which it does not, and what to do about it.
  🚫 THE ONE THAT IS DELIBERATELY NOT HERE: Apple's own dictionary DATA.
     It is the best text on the machine and already licensed to you, and
     it lives in Body.data — zlib-compressed chunks of Apple-schema XML
     whose layout has changed across macOS releases. It is crackable
     without Homebrew, since macOS ships a Perl with zlib. It is absent
     because a parser that breaks on a macOS update fails by handing you
     GARBLED TEXT rather than by saying it cannot read the file, and
     this config would rather refuse than lie. If it is ever written it
     becomes provider 0 and nothing else changes — which is most of why
     the providers are a list at all.
  🌐 THE WEB PROVIDER IS OFF UNTIL YOU TURN IT ON. A lookup sends the
     word you are writing about to somebody else's server. On the work
     MacBook that is a sentence fragment leaving a managed machine, and
     the proxy may eat the request anyway. The default sends nothing
     anywhere; d.allowNetwork = true is one edit, and the report says
     the option exists whether or not you have taken it.
  ⏱ EVERY LOOKUP IS ASYNCHRONOUS, AND THAT IS NOT A PREFERENCE.
     Hammerspoon has one thread and it is the thread that reads your
     keyboard. A synchronous `wn` or a synchronous fetch does not make
     the panel slow — it stops your typing, in every app, for as long as
     it takes. That is precisely the fault 6.131.0 built core/lag.lua to
     measure, and shipping a new cause of it in the next release would
     be a poor joke. A sentry reads the module for io.popen, hs.execute
     and hs.http.get and fails on any of them.
  🚨 AND A LATE ANSWER MUST NOT LAND IN THE WRONG WORD. Look up `terse`,
     give up, look up `laconic`; terse's reply arrives a second later
     and repaints the open picker with terse's synonyms under laconic's
     title. ⏎ then types the wrong word into your document, and
     everything on screen agreed it was right. Every lookup carries a
     GENERATION number — bumped on each lookup and again when the picker
     closes — and a reply whose generation is stale is dropped without
     being drawn. BREAK D removes that guard and watches the wrong word
     arrive.
  ⌨️ THE GUARDED REPLACE MOVED INTO power_tools AND IS PUBLISHED as
     power.replaceSelection. ⇪8 is the second tool to write over your
     selection, and a second copy of "check secure input, wait for
     ⌘⇧⌃⌥, cap the length" is a second place to forget one of them. The
     one that would be forgotten is the secure-input check, because it
     is the only one whose absence is INVISIBLE — nothing arrives, no
     error is raised, and the field simply stays as it was.
  ✂️ THE PARSERS ARE PURE FUNCTIONS OF A STRING, so tests/test_define.lua
     drives both from captured `wn` output and captured JSON with no
     Mac, no Homebrew and no network in it — 129 checks, seven break
     tests. The fiddly ones are real: a gloss containing " -- " must not
     bleed into the synonym list, `light_up` must reach your sentence as
     "light up", the word itself is dropped from its own synonyms
     because a row whose ⏎ retypes what you already had reads as broken,
     and a sense whose only member IS the word KEEPS ITS DEFINITION
     rather than vanishing with it.

NEW IN 6.132.0 — THE CASE OF THE THING:
  🔠 LL: "I need a way to Change/Transform Text Case — upper, lower,
     title, camel, kebab, or snake. I think I have something already to
     pick out and transform file names, can we add this to that tool? I
     am open as always, to your suggestions."
  ✅ YES AND NO, AND THE "NO" HALF IS THE DESIGN. ⇪R (bulk rename) walks
     a Finder selection, groups sidecars, checks for collisions and calls
     os.rename. It cannot touch the sentence you have highlighted in an
     email, because there is no file there to rename. So the six cases
     went into ⇪R as asked — all six, where there had been two — AND onto
     ⇪; for text selected anywhere on the Mac.
  🚨 WHICH MEANT THE RULES COULD LIVE IN NEITHER OF THEM. Two copies of
     "what is a word?" is two copies that drift, and the drift is
     silent: ⇪R would snake_case a file one way and ⇪; would snake_case
     the same text another way, and nothing anywhere would report a
     problem. modules/text_case.lua owns all six; both tools ask it
     through core.call at the moment you press the key, so load order
     does not matter and neither of them can opt out.
  ✂️ THE HARD PART IS THE WORD BOUNDARY, not the capital letters. camel,
     kebab and snake all need the same answer to "where do the words
     start?", and the answer is three rules: split on punctuation, split
     at a lower-or-digit followed by an upper (fooBar → foo Bar, and
     iPhone14Pro → i Phone14 Pro, which is why digits are in that rule),
     and split an acronym off the word behind it (XMLHttpRequest → XML
     Http Request).
  🚨 A BYTE ABOVE 127 IS PART OF A WORD. Lua's %w is ASCII-only in the C
     locale, so the obvious [%w]+ run pattern treats the two bytes of "é"
     as punctuation and DROPS THEM: café comes out of snake_case as
     "caf". Not mangled, not flagged — gone. The run class carries
     \128-\255 explicitly. The other half of the same rule is that an em
     dash is above 127 too, so `this—that` would weld into one word;
     the separators that are NOT letters are therefore named in a list
     rather than guessed at from the bytes.
  🔤 AND THE SIX ARE TWO IDEAS, NOT SIX VARIATIONS OF ONE. UPPER, lower
     and Title KEEP THE TEXT'S SHAPE — every space, comma and line break
     stays where it was. camel, kebab and snake REBUILD the text from its
     words, and the punctuation is not preserved because it is the thing
     being replaced: the separator IS the case. `Hello, world!` is
     `HELLO, WORLD!` under upper and `hello-world` under kebab, and the
     comma is not lost by accident.
  ↩️ THE REBUILDING THREE RUN PER LINE. Select a list of eight things,
     choose snake_case, and you get eight snake_case lines — not one
     200-character identifier with the whole list welded into it.
  👁 ⇪; PREVIEWS ALL SIX AGAINST YOUR OWN TEXT, and that ordering is the
     whole design: the selection is read BEFORE the picker opens. Three
     of the six throw your punctuation away by definition, and a preview
     of somebody else's sample cannot warn you about that. A preview of
     the paragraph you actually highlighted can.
  ⚠️ AND IT REPLACES BY TYPING, because macOS has no "set the selection"
     API — nothing can hand text back to an arbitrary app's text field.
     The result is posted as keystrokes over the still-live selection,
     so it inherits every guard ⇪; already needed to type the clipboard:
     the secure-input check first, the wait for ⌘⇧⌃⌥ to come up, and the
     length cap. An unchanged result is not typed at all, because
     retyping an identical paragraph is invisible until you reach for
     undo and find a step that did nothing.
  🔢 COUNT → CLIPBOARD IS A SECOND ROW, NOT A CHANGE TO THE FIRST.
     LL: "Allow both counts to be posted to the clipboard." A tool you
     press to read a number must not quietly replace what is on your
     clipboard — you reached for the count, not for a paste — and ⇪V's
     history would fill with "128 words · 742 characters" lines nobody
     asked to keep. Count the selection shows. Count the selection →
     clipboard shows AND copies, and says which.
  🖱 RIGHT-CLICK NOW SAYS WHEN IT FIRED BLIND. LL: "I don't always have
     the same options when I use our right-click tool." That is this,
     exactly. ⇪⇧F waits for the modifier keys to come up before posting,
     because a context menu reads the modifiers held when it OPENS and
     Chrome deliberately answers a ⇧-click with its own menu instead of
     the page's. When the wait ran out with ⇧ still down, the click went
     out anyway — silently. Two menus, one key, nothing on screen saying
     which one you were about to get.
  ⏳ THE WAIT WENT 0.30s → 0.45s, because ⇪ is ⌘⌃⌥⇧ held together and
     letting go of all four is not one motion. And a blind fire now names
     the modifier that was still down, on screen and as a running count
     in _G.rightClickReport(). It still fires: swallowing the press would
     trade a confusing menu for a dead key, and a dead key gets pressed
     again with the same modifiers held.
  ⚠️ SOME MENUS REALLY ARE DIFFERENT, with nothing wrong anywhere.
     Right-clicking a misspelled word in Chrome gives you Add to
     Dictionary and the spelling suggestions; right-clicking the
     paragraph beside it does not. That is the page deciding what is
     under the pointer, which is the one thing this module deliberately
     never guesses at.
  🔑 ⇪⇧V WAS NEVER MISSING. LL: "Shouldn't this be in the edit picker?
     Sorry if I'm missing it. hyper+shift+V." It was there — as the
     Clipboard row in the ⌃⌃ editor picker, whose key cell said ⇪V alone.
     ⇪⇧V is that row's edit-and-delete view and has been since 6.97.0;
     the row simply never said so, so the picker read as though ⇪V were
     the only way in. It now reads ⇪V / ⇪⇧V, the shape the Screenshots
     row has used since 6.122.0.
  🧪 tests/test_text_case.lua — 101 checks, eight of them break tests.
     BREAK A is the accented letter being deleted by a "simplified" run
     pattern; BREAK E is the rebuilding cases welding a selected list
     into one identifier; BREAK F is the picker advertising a transform
     the code no longer performs. test_rename and test_power_tools both
     load the REAL text_case module rather than stubbing it, because a
     stub that answers case.apply with whatever the test expects proves
     only that the test agrees with itself.
  🔌 AND A CASE RULE WITH NO ENGINE REFUSES BY NAME. If text_case fails
     to load, br.plan returns no plan and names the missing module rather
     than handing every original name back and showing you a preview of
     a rename that would change nothing.

NEW IN 6.131.0 — WHICH TAP IS EATING THE KEYSTROKE:
  ⏱ LL: "Something is running perhaps Hammerspoon to cause my typing to
     lag. Once I quit Hammerspoon, the lag went away. Seems related, but
     nothing to report from the console."
  🚨 THE CONSOLE WAS NEVER GOING TO HAVE IT. A console prints what
     something CHOSE to print, and a slow function is not an error — it
     prints nothing at all. Quitting Hammerspoon and watching the lag go
     is a real measurement, and it narrows the fault to this config;
     nothing narrower than "this config" was available to either of us.
     core/lag.lua closes that gap by measuring instead of waiting to be
     told.
  ⌨️ WHY A TAP CAN CAUSE THIS AT ALL. An hs.eventtap is not a listener,
     it sits IN THE PATH of the event: macOS hands it your keystroke and
     the character does not reach the app you are typing into until the
     callback returns. This config runs eight or nine keyboard taps at
     once — the hyper key, the text expander, autocorrect, the ⌃⌃
     gesture, the key caster when it is on — all on Hammerspoon's one
     thread, in series. The delay on every key is the SUM of all of
     them. Each one is fast. "Fast" is a claim that had never been
     checked, and eight unchecked claims is the exact shape of a problem
     that arrives gradually and has no error to show for itself.
  🎯 SO IT WRAPS hs.eventtap.new ITSELF, ONCE, BEFORE ANYTHING RUNS.
     Every tap in this config — core/ and modules/ alike — is born from
     that one function. Wrapping it instruments all of them at once and
     needs no cooperation from any module: nothing registers, nothing is
     edited, and a tap written in a future version is measured the day
     it is written without anybody remembering to. debug.getinfo names
     the CALLER, so the report says "text_expander.lua:1133" rather than
     an anonymous function nobody can place.
  📉 AND THE HALF THAT NO TAP CAN EXPLAIN: STALLS. Hammerspoon has one
     thread, and anything slow on it stops the keyboard just as
     effectively without any tap being slow — a synchronous shell
     command, a folder read that reaches OneDrive, a big JSON write. A
     heartbeat set to fire every 50ms CANNOT fire while that thread is
     busy, so how late it fires is a direct measurement of how long the
     thread was blocked. The worst dozen are kept, with the time of day
     and the app that was in front.
  ⚠️ AND SOME STALLS ARE HONEST. Opening a picker that scans a folder
     blocks the thread on purpose and will appear here. The report says
     so rather than implying every row is a bug.
  ⏱ IT IS ALWAYS ON, AND THAT IS THE DESIGN. The obvious alternative is
     a switch: turn the probe on, reproduce the problem, read the
     numbers. It is the wrong one here, because lag that comes and goes
     is not reproducible on demand — by the time you have noticed it,
     decided it is real, found the Console and turned something on, the
     cause may be over. The evidence has to already exist at the moment
     you think to look. So it costs what it costs, always: two clock
     reads and four arithmetic operations per event, against a callback
     budget measured in milliseconds.
  🚨 NO pcall IN THE HOT PATH, AND NO table.pack EITHER. A probe whose
     job is to measure per-keystroke cost must not add a per-keystroke
     pcall to do it — and a pcall there would ALSO swallow the errors
     that each module's own guard counts in order to switch a broken tap
     off. table.pack would allocate a table on every keystroke, making
     the probe a source of the symptom it was built to find. The
     callback is called directly and its two return values are carried
     by two named locals, which is the whole documented contract.
  🩺 TWO BUGS IN THE PROBE'S OWN "WHERE DID THIS TAP COME FROM" COLUMN
     WERE CAUGHT BY ITS TESTS AND BOTH ARE NOW BREAK TESTS. Asking
     debug.getinfo for a fixed stack level was wrong because pcall is
     itself a frame, so every tap was reported as created inside
     core/lag.lua; fixing that by walking the stack then landed on the
     C frame and reported "[C]:-1". Neither threw. Both produced a full,
     confident, useless table — which is precisely the failure this file
     exists to prevent, so BREAK G and BREAK H hold them shut.
        _G.lagReport()    everything measured so far
        _G.lagReset()     zero the counters and start again
```

```text
NEW IN 6.130.0 — EVERY EDITOR INTO ONE SPREADSHEET:
  💾 THE LAST ROW OF THE ⌃⌃ PICKER WRITES ALL OF IT TO ONE CSV.
         LL: "Can these write into one file, .csv perhaps? Too crazy?"
     Not crazy — the roster the editor picker already shows was the right
     list; it simply had no way to hand its CONTENTS over. The bottom row
     of the picker now writes <Logs>/editors-<Mac>.csv, one row per item:
         Date,Editor,Item,When,Label,Characters,Text
     Also reachable as core.call("editors.csv").
  🚨 IT IS A SNAPSHOT, SO IT OVERWRITES — and that is a deliberate break
     with every other CSV in this config. The others append because they
     are LOGS: one row per event, as it happens. This one dumps whole
     stores. Appending it would write a thousand clipboard rows underneath
     last time's byte-identical thousand — a longer file that is not a
     longer record, and unusable in the Excel it was asked for. The Date
     column stamps when the snapshot was taken; re-running takes a new one.
  🗂 A NEW OPTIONAL `csv` FIELD, AND MOST MODULES NEEDED NOTHING. An
     editor holding ONE thing — either pad, whose entire content is a
     draft — already answers `text`, and that becomes its single row for
     free. Only the four multi-item stores had to say so:
         clipboard_history   every copy, newest first, with its date
         ocr_engine          every capture — rawText, NOT the 65-char
                             picker preview, which would have produced a
                             spreadsheet of truncated cells that looks
                             complete
         win_pin             every note, LABELLED with the window it is
                             stuck to, sorted by window id so two exports
                             of unchanged pins match
         screenshots         every capture's full path, size and mtime
  ⚠️ A STORE SUPPLYING NEITHER IS SIMPLY ABSENT from the file, which is
     invisible once you are looking at a spreadsheet. So
     _G.editorPickerReport() now prints where the CSV goes, a 💾 and a row
     count against every editor that would contribute, and "supplies no
     csv and no text" against every one that would not.
  📸 SCREENSHOTS JOINS THE EDITOR PICKER, AND ITS ⏎ OPENS THE FOLDER.
         LL: "I feel like any screenshots should be captured here, by a
         line entry that sends me to that screenshot's folder"
     It is the odd row on that roster on purpose: every other entry opens
     a text surface, this one opens Finder — through hs.task, never
     hs.execute, because that folder lives in OneDrive where a synchronous
     `open` can hang Hammerspoon's only thread and the keyboard with it.
     It offers no `text`, so ⌥⏎ cannot put an empty string on the
     clipboard over something you wanted, and it is in the CSV too.
  🩺 THE SENTRIES THAT KEEP IT HONEST. test_editor_picker now requires
     every MULTI-item store to declare `csv` — without it the export
     silently falls back to `text`, exports one row, and looks finished —
     and requires the OCR store to export rawText specifically. The first
     version of that second check passed a real break (the word "rawText"
     still appeared in the guard one line up); it matches the assignment
     now.

NEW IN 6.129.0 — THE KEYS THAT ALWAYS MOVED IT:

  🪟 LL, after three consecutive versions of drag fixes: "Can this box
  move or not? We're stuck in a loop. Can't move it no matter what.
  Also, what key combo will move this? Maybe it's me and not you?"

  ✅ IT WAS NOT THEM.

  ⇪⇧ ← → ↑ ↓ has moved an open picker since 6.30. Fifty pixels a tap,
  hold the arrow to walk it across the screen, ⇪⇧R puts it back to
  automatic placement. It is an hs.hotkey — a Carbon RegisterEventHotKey
  — so it fires THROUGH a chooser that owns the keyboard, and it
  repositions by hide() followed by show(point), which is the only
  reposition macOS gives an hs.chooser at all.

  It shares nothing with the mouse tap, the chooser globalCallback, or
  the computed grab box. Those three are what 6.126.0, 6.127.0 and
  6.128.0 were spent debugging. A path that works had been sitting
  beside them the whole time.

  🚨 AND IT WAS MISSING FROM THE ONE PLACE IT WAS NEEDED.

  The nudge is in the global cheat sheet, and has been for a long time.
  It was NOT in the WINDOW MOVE group — the group a person opens at the
  exact moment a picker will not move. That group listed the ⌃⌥⌘R reset
  for a nudge whose ARROWS it never named, followed by five mouse
  gestures of unproven reliability.

  So the one screen consulted at the moment of failure documented every
  unproven way to move a picker and omitted the proven one.

  The group now leads with the keys. _G.windowMoveReport() prints them
  at the top of every report, and says outright that the keyboard path
  does not go through the mouse tap — so a broken tap can never take the
  working method down with it.

  ⚠️ NEVER DRAG A PICKER BY ITS ROWS — now stated outright, in the
  cheatsheet and in the report.

  A bare click on a row RUNS that entry and closes the picker. The most
  natural place to grab a list is the one place that cannot possibly
  work, and nothing said so. Bare click-hold drags the SEARCH BAND only.
  ⌘ held drags from anywhere, on or off the picker.

  🔍 TWO THINGS VERIFIED AGAINST HAMMERSPOON'S OWN SOURCE rather than
  assumed, because three versions of guessing had earned it:

    · chooser:show(point) on an ALREADY-VISIBLE chooser really does
      move it. showAtPoint: → showWithHints:NO atPoint: has no
      isVisible guard and no early return before setFrameTopLeftPoint:.
      The drag's move call was never the problem.
    · hs.chooser genuinely exposes no frame getter. The full binding
      list is show/hide/isVisible/choices/query/width/rows and friends
      — no frame, no topLeft. window_move COMPUTES a grab box because
      it is forced to, not by choice.

  💡 THE LESSON: a working feature nobody can find is indistinguishable
  from a broken one, and it costs more — because the hunt for the bug
  happens in code that does not have one. When a fix ships three times
  and the report is still "it does not move", stop editing the
  mechanism and go read what the user was told to press.

NEW IN 6.128.0 — AND IT STILL DID NOT MOVE:

  🪟 LL, on the 6.127.0 fix: "I clicked and dragged and nothing
  happened."

  6.127.0 was a real bug really fixed. It was not the only way to get
  nothing, because a ⌘-drag on a picker had to pass TWO separately
  computed tests before it was allowed to start — and either one failing
  looks identical from the outside: a picker that will not move, in
  silence.

  🚨 TEST ONE — "IS A PICKER OPEN" had exactly one source of truth:
  hs.chooser.globalCallback firing willOpen. If it never arrived, the
  entire picker branch of the mouse tap was skipped, and ⌘ did nothing
  whatsoever. macOS will answer chooser:isVisible() directly — §1.5's
  nudge has asked it since 6.30 — so that is the truth now. The callback
  is a HINT that gets checked, and 6.127.0's placement record (which
  names its chooser) is a second way in when the callback never came.

  The two directions are deliberately not symmetrical. The callback
  already stated this picker opened, so it stands unless isVisible()
  explicitly says otherwise — a Hammerspoon build without the getter
  must not lose the drag. A chooser reached from the RECORD has no such
  statement behind it (a record outlives its picker by design), so it is
  promoted only on an explicit yes.

  🚨 TEST TWO — "IS THE CLICK INSIDE THE BOX", and the box is a GUESS.
  There is no frame getter for an hs.chooser, so the box is assembled
  from a recorded top-left, a width the picker may decline to give, and
  an assumed 44px row height. Every way any of those can be wrong
  presented as "this picker cannot be moved".

  ⌘-DRAG NO LONGER ASKS THE BOX. A visible picker plus ⌘ moves it, from
  anywhere — which is the principle the module already held when there
  was NO box ("better a jump-to-hand than a picker that cannot be moved
  at all"); there was no honest reason to be stricter when the box is
  merely a guess. The box now decides one thing only: where the
  bare-click SEARCH BAND is, where being wrong costs a click nobody
  wanted anyway.

  The cost, accepted knowingly: a ⌘-click landing OUTSIDE an open picker
  starts a drag instead of reaching the app underneath. It is a rare
  gesture while a picker holds the keyboard, Esc puts the picker away
  first, and dropping it where it started costs nothing.

  🩺 AND EVERY CLICK IS WRITTEN DOWN. 6.127.0 recorded only DECLINED
  ⌘-clicks — so the two commonest ways to get nothing (a bare click
  below the search band; a picker the module never saw at all) both left
  the record empty and the report printing "last refusal: none".
  _G.windowMoveReport() now replays the last click it judged: where it
  was, which modifier was held, whether a picker was seen and how it
  knew, the box and band it was measured against, and what it decided.

  ⚠️ THE REPORT IS ALWAYS READ WITH NOTHING OPEN. A chooser holds the
  keyboard, so reaching the Console means closing it first. 6.127.0's
  report printed the LIVE box and LIVE picker anyway — which in that
  state are a 40%-width fallback and "no" — labelled exactly like
  measured values. Everything live now says so: "computed NOW, with
  nothing open", "width is a guess", and a placement whose picker is
  simply not on screen no longer reads as a warning about another one.

  💡 THE LESSON, worth keeping: a feature gated on a computed value
  fails exactly like a feature that is missing. Gate on something the OS
  will state, or do not gate.

  🧪 test_window_move.lua: 66 → 78 checks. Section 4d drives the
  visibility paths (a picker the callback never announced is still
  found and still drags; an explicit isVisible() == false beats the
  callback; a chooser with no getter at all is trusted from the
  callback), and the old "⌘-click outside the box belongs to the Mac"
  check is REVERSED on purpose.
```

```text
NEW IN 6.127.0 — THE PICKERS THAT COULD NOT BE MOVED:

  🪟 LL: "The screenshot is a picker window I can't grab and move. Why?"

  Because fourteen modules opened their picker with a bare
  chooser:show(). ⇪; ⇪, ⇪. ⇪D ⇪Y ⇪⇧; ⇪⇧' ⇪⇧. and several more could not
  be dragged at all — not by ⌘-drag, not by the search band — and
  nothing anywhere said why.

  🚨 THE PLACEMENT RECORD WAS GLOBAL AND DID NOT SAY WHOSE.
  This is the part worth keeping, because the shape will come back.

  macOS gives hs.chooser no frame getter. There is no way to ask a picker
  where it is or how big it is, so window_move COMPUTES its grab box from
  _G.lastPopupPlacement — the record core.showPopup writes when it places
  a popup. That record held a screen and a point, and nothing else. It
  said "a picker opened here", not WHICH picker.

  A picker opened with a bare chooser:show() records nothing at all. So
  while it was on screen, the record still described whichever picker had
  last gone through showPopup — possibly one closed an hour ago, possibly
  one on another monitor. The box was computed at those coordinates. The
  ⌘-click on the picker actually in front of you fell outside it.

  And here is the bit that made it a dead end rather than a rough edge:
  window_move already handles "no box" gracefully — it grabs the panel by
  the hand, deliberately, with a comment saying a jump-to-hand beats a
  picker that cannot be moved at all. But a WRONG box is not a missing
  one. It went down the other branch and DECLINED the click.

  ✅ TWO CHANGES, BOTH SMALL.
  Every picker in the config now opens through core.showPopup. And the
  record names the chooser it belongs to, so a record for somebody else
  reads as no record — which drops through to the grab that always
  worked.

  ↕️ THEY ALSO REJOIN THE POSITION SYSTEM THEY WERE MISSING.
  The same absent call cost those pickers everything else placement does:
  the ⇪⇧-arrow nudge, the remembered offset, ⌃⌥⌘R, and opening on the
  screen you are looking at rather than the main one. They had been
  landing wherever macOS put them since the day each was written.

  🩺 _G.windowMoveReport() — NEW, AND THE ACTUAL LESSON.
  window_move was the only module in this config without a report, and it
  is the one that fails SILENTLY BY DESIGN. A mouse tap cannot announce
  that it refused a click: the click belongs to whatever app is
  underneath, and a tap that talks about other people's clicks is a tap
  you turn off. So there was no Console line, no pill, no trace — the
  panel simply did not move, and the only thing to do about it was
  report it in words, which is what happened.

  The report prints the tap's state and error count, every registered
  panel and whether it is open, the placement on record, WHO it belongs
  to, the computed box, the band strip, and the last refused ⌘-click with
  its coordinates and the box it was measured against.

  🧪 THE SENTRY COUNTS PICKERS, NOT FILES.
  A module that builds three choosers must place three — net_tools does,
  and a file-level check would have passed while two of its three were
  still opening unplaced. Comments are stripped before the scan, because
  the comment explaining why showPopup is used satisfies a substring
  search on its own. Both of those were found by break tests that were
  supposed to fail and did not.

NEW IN 6.126.0 — ⇪' NOW ACTUALLY PAUSES VLC:

  ⏸ LL: "⇪' does not pause VLC."

  It did not, and it never had. Here is exactly what was happening.

  The pause key does two things: it posts the ⏯ media key, which is the
  only thing that reaches a browser, and then it tells every player in
  pt.players by name, because the media key only reaches whichever app
  macOS thinks is "now playing". What it told each player was `pause`,
  and if that failed, `playpause`.

  VLC's AppleScript dictionary contains NEITHER of those words. Both
  verbs raised errAEEventNotHandled, the second one inside an inner try
  that swallowed it without a word, and the film played on. The number in
  the alert was one short every time VLC was running, which is the only
  visible trace this left.

  🚨 AND THE OBVIOUS FIX STARTS PLAYBACK.
  VLC spells its toggle `play`. Not "play if stopped" — the toggle. Sent
  to a playing VLC it pauses; sent to a PAUSED VLC it starts it. A pause
  key that begins a film is the same failure as a pause key that opens
  Music, and worse in kind, because you pressed it to make the machine
  quiet and it made noise.

  So VLC's script reads the `playing` property first and sends nothing at
  all when it is false. The alert then says "VLC was already paused",
  which is also the answer to "why did the number not go up".

  ⚠️ IT IS A SEPARATE SCRIPT, AND THAT IS NOT TIDINESS.
  `playing` and `play` are VLC's own terminology, and AppleScript can
  only resolve an app's terminology when the app is named as a LITERAL.
  The shared script says `tell application (n as text)` — a name decided
  at runtime — which is exactly why it can loop over six players, and
  exactly why it can only send them universal verbs.

  Naming VLC literally means the text is compiled against VLC's
  dictionary. On a Mac with no VLC installed that compile FAILS, and if
  the line lived in the shared script the failure would take the whole
  pause key down with it — every player, over one missing app. In its own
  child process, launched only when VLC is already running, it can only
  ever take itself down.

  🚨 THE RUNNING CHECK IS MADE TWICE AND BOTH ARE LOAD-BEARING.
  Hammerspoon asks hs.application.get(name) before launching osascript at
  all. AppleScript cannot be asked that question, because naming an app
  is what launches it — the reason the shared script consults System
  Events' process list before it says anything to anybody.

  The script then asks System Events again on the inside, because VLC can
  quit in the gap between the two checks, and `tell application "VLC"` on
  a VLC that has just quit RELAUNCHES IT. This key never starts anything.
  That is the whole design, and it now holds for VLC too.

  🔔 ONE KEYPRESS STILL GETS ONE PILL.
  The generic script and VLC's script run in two child processes, so the
  alert waits for both halves before it draws: "⏸ Paused — media key
  sent, and 2 players told by name · VLC paused". Two pills a moment
  apart would read as two events when it was one keypress.

  🧪 A NAME HELD BACK MUST HAVE SOMETHING TO SAY IT.
  pt.toggleOnly lists the players kept out of the shared script, and
  pt.toggleScripts maps each of them to its own script. Both sides read
  the map, so a name added to pt.toggleOnly without a script stays in the
  shared script where it was rather than being dropped from both paths
  and silently told nothing. A test fails if that map ever goes empty.

NEW IN 6.125.0 — ⇪⇧Z IS YOURS AGAIN, AND THE PICKER GOES KEYLESS:

  ⌨️ THE EDITOR PICKER HAS NO ⇪ KEY AT ALL NOW.
  LL: "This key should be free for future use: ⇪⇧Z"

  It is free. Nothing in this config binds ⇪⇧Z, and a test now fails if
  anything starts to — including the picker quietly taking some other key
  instead, which is the way a giveback like this usually gets undone.

  🚨 AND THERE WAS NOWHERE TO MOVE IT TO.
  This is the part worth knowing, because it is why the answer is a
  keyless route rather than a different letter. Every ⇪ letter and every
  ⇪⇧ letter is spoken for. ⇪E was the obvious mnemonic and §0.4's
  migration map has held it since long before the picker existed — the
  hotkey sentry said so the first time the suite ran, which is the whole
  reason that sentry is there. ⇪⇧Z was what was left in 6.116.0, and it
  was described in the module header at the time as "the last free
  letter", not as a mnemonic.

  What is genuinely unclaimed today is ⇪⇧6 and the three brackets. Those
  are keys nobody can guess, and spending one on a handrail nobody
  touches on a day when the double tap works is a bad trade — it takes a
  key you might want later to buy a shortcut you will never press.

  🗂 SO IT TOOK THE ROUTE THE ROLLUP ALREADY TOOK.
  unified_search's run map has carried ["📊"] = "rollup.show" since
  6.105.0 for precisely this case, written when the daily rollup found
  every ⇪⇧ letter gone: a tool with no key, reached from ⇪space. The
  picker now sits beside it as ["🗂"] = "editors.show". ⇪space, type
  "editor", press ⏎. It costs one line and no key.

  ⚠️ AND IT IS STILL TWO INDEPENDENT WAYS IN.
  That matters more here than it did for the rollup, and it is the reason
  this was not simply deleted. The picker's main way in is a double tap
  of ⌃ — an hs.eventtap, and macOS switches taps off when it revokes
  Accessibility. The module's own header forbids the tap being the only
  way in. ⇪ is Caps Lock remapped to F18 and bound with hs.hotkey, which
  fails for entirely different reasons and on entirely different days. So
  the ⇪space row is not a convenience for this module, it is the second
  route it is required to have, and a test asserts both halves of it —
  the published service and the run-map row that calls it.

  🩺 THE FOUR "the tap is down, use X instead" MESSAGES NOW BUILD THE
     ROUTE FROM THE SETTING.
  All four had "⇪⇧Z" typed straight into them. The moment the key went
  away, every one of them became a false sentence printed at exactly the
  moment the reader has just lost the gesture and most needs the truth.
  ep.wayIn() is now the single place that answers "how do I open this
  without the tap", the same way ep.gesture() has answered "what is the
  gesture" since 6.121.0. The report's fallback line comes from it too —
  and that line used to be ep.key:upper(), which on a nil key would have
  thrown inside the one function you would run to find out what is wrong.

  ⌨️ ep.key IS STILL READ, so the key is one line from coming back.
  Set it to a letter and the ⇪ binding returns on the next reload, for
  whenever a letter frees up. A test exercises that path rather than
  trusting it, because a setting nobody ever runs is a setting that has
  quietly stopped working.

  WHAT WAS DELIBERATELY NOT TOUCHED
  The ⌃⌃ gesture, the pointer-cancel machinery and the side machinery are
  all byte-identical to 6.124.0. This release moves one thing: where the
  tap-free way in lives.

NEW IN 6.124.0 — THE PICKER MOVES TO ⌃⌃, AND THE MOUSE GETS A VOTE:

  ✋ THE EDITOR PICKER IS ON ⌃⌃ NOW, EITHER CONTROL KEY.
  LL: "please fix only the shortcut keys first for a double ctrl+ctrl."

  The obvious objection was raised first, because this config's own notes
  had recorded the deal as "Alfred → right ⌃⌃, this picker → right ⌥⌥",
  and moving onto ⌃ walks into Alfred. The offered way out was a side
  split: give Alfred the right ⌃ and take the left. That offer was wrong,
  and it was wrong for a reason 6.121.0 had already written down and
  6.122.0 had already designed around — splitting a modifier needs BOTH
  programs to tell the sides apart, and whether Alfred does was called
  "Alfred's business, unreadable from in here".

  Unreadable from in here is not the same as unanswerable. LL tested it:

      LL: "Alfred fires on either Control"

  So Alfred is side-blind and the split was never available — not merely
  unproven, impossible. LL moved Alfred off ⌃⌃ instead, which removes the
  conflict rather than dividing it, and the picker took the key whole.

  ⌨️ THE HARDWARE WAS MEASURED TOO, NOT ASSUMED.
  Apple builds no keyboard with a right Control key, so before offering a
  side at all this needed to know whether LL's board has one. A
  flagsChanged probe printed keycode 62, so it does. The shipped setting
  still does not use it: tapSide is "either", because "right" would work
  at the desk and die silently the moment the laptop lid opens. The same
  probe printed 61 for right ⌥ — the 6.122.0 gesture was never broken by
  hardware, it was simply never installed — and printed nothing at all
  for keycode 57, which is Caps Lock correctly remapped to F18.

  🖱 AND ⌃-CLICK NO LONGER OPENS IT, which is what made ⌃ usable at all.
  ⌃-click IS the Mac right-click and ⌃-scroll IS screen zoom, so on ⌃ the
  two commonest gestures on the machine are:

      ⌃-click        ctrl↓ · (click) · ctrl↑
      ⌃ tapped once  ctrl↓ ·         · ctrl↑

  — indistinguishable to a tap that watches only the keyboard. Two right-
  clicks inside ep.tapGap would have opened the picker over whatever was
  being clicked on. That is the identical argument the ⌘C/⌘V block at the
  top of editor_picker.lua has always made, arriving through a different
  device, and ⌥ never had it: nobody ⌥-clicks, everybody ⌃-clicks.

  The tap now also watches leftMouseDown, rightMouseDown, otherMouseDown
  and scrollWheel, and treats every one of them exactly as it treats a
  keyDown — as proof the modifier around it was a chord, cancelling any
  half-made gesture rather than merely failing to count it. The watched
  types are resolved by lookup and anything this Hammerspoon does not
  have is SKIPPED and named in _G.editorPickerReport(), because a nil in
  a watched-types list is not a smaller feature, it is an eventtap that
  fails to construct and takes the gesture down with it.

  ⚙️ THE SIDE MACHINERY STAYS, AND IS NOT DEAD CODE. tapSide = "left" or
  "right" still works and is still covered by its own tests — it is what
  the next side-aware program will need, and it is the reason the report
  can answer "which ⌃ did that come from" at all. "either" is a setting,
  not a removal. "alt"/"right" is 6.122.0's ⌥⌥ and "cmd"/"either" is
  6.116.0's ⌘⌘; both remain one line away.

  ⚠️ WHAT THIS RELEASE DELIBERATELY DOES NOT TOUCH. LL: "Only fix the
  other stuff if will not absolutely interfere with the work we are
  doing." ⇪⇧Z is still the fallback key and the VLC pause script is
  untouched, both of which have open work of their own.

NEW IN 6.123.0 — THE COLUMN THAT WAS PROMISED, AND THE WINDOW THAT ONLY
HALF-MOVED:

  🌐 activity_history.csv HAS A url COLUMN.
  LL, twice: "a tool that would save any and all URLs and Window titles
  would be posted to a .csv file." 6.120.0 answered honestly that only
  half of it existed — window titles yes, URLs no — and that nothing in
  that release was building the other half either. This builds it, and it
  arrives now because LL supplied the fact that unlocks it: "I use Chrome
  exclusively."

  That fact matters more than it sounds. There is no macOS API for "the
  URL in the frontmost window" — a browser is just an app with a window
  title, and the address is private to it. The only way to ask is to ask
  the browser, in its own scripting language, and every browser answers
  differently or not at all. One browser is a build. Every browser is a
  maintenance treadmill with Safari's sandbox at the end of it.

  Columns are now date,app,title,seconds,url. A row is written when the
  window in front changes — and a Chrome tab switch changes the window
  title, so it is one row per page you actually looked at, with how long
  you looked at it. That is the difference between this and ⇪Y: ⇪Y is
  Chrome's own history database, a list of what you navigated to. This is
  an observation of what was in front of you.

  ⚡ IT LIVES IN THE ACTIVITY TRACKER, NOT IN A MODULE OF ITS OWN.
  The obvious shape was url_tracker.lua with its own poller. That is
  precisely the design 6.104.0 DELETED: document_watcher was a second
  five-second timer writing a second CSV about the same window switches
  the tracker was already watching. Rebuilding it with URLs in it would
  be the same mistake with a new column. The tracker already knows when a
  window comes forward and already writes the row. The URL is a column on
  that row, not a second observer.

  🕵️ INCOGNITO IS NEVER RECORDED, AND IT FAILS CLOSED.
  Chrome is asked for the window's mode before it is asked for the URL,
  so the address of an incognito page never crosses into Lua at all. The
  default in that script is "incognito", not "normal" — a window whose
  mode cannot be read is skipped rather than guessed at. An incognito
  window is a statement that this page should not be written down, and
  writing it into a file that syncs to OneDrive would be a plain betrayal
  of that.

  🔐 AND NAMED SECRETS ARE CUT OUT BEFORE ANYTHING IS WRITTEN.
  Query strings carry password reset links, OAuth codes, API keys and
  session tokens, and this file outlives the login it belonged to. Named
  secrets are stripped — including from the FRAGMENT, which is where
  OAuth's implicit flow actually puts an access token, and which a
  stripper that only reads the query string would miss entirely. What is
  kept is deliberate: ?v= is what makes a YouTube row mean anything, and
  a search you ran is a thing you might want to find again. There is also
  an empty au.skipHosts list for sites that should never be recorded at
  all — empty by default, because guessing which sites someone considers
  private is not mine to do.

  🔒 THE ALLOW-LIST IS EXACT-MATCH, AND THAT IS A SECURITY DECISION.
  The app's name is interpolated into AppleScript source. Application
  names come from macOS and an app may call itself anything at all,
  quotation marks included — so a name that reached that string unchecked
  could close the tell block and run its own AppleScript as you. Matching
  against five exact literals means the text that reaches the script is
  always one of five known strings, whatever the frontmost app is called.

  ⚡ AND THE ASK IS ASYNCHRONOUS, ALWAYS. hs.osascript.applescript would
  have been three lines shorter and runs on the main thread — the one
  your keyboard is on. A Chrome that is beachballing does not answer
  Apple events promptly, and a synchronous ask would freeze every hotkey
  in this config until it did.

  🏁 THE STAMP IS A COUNTER, NOT THE START TIME. An answer that arrives
  after you have already switched tabs must not be written onto the row
  you are on now. The first draft matched on the session's startTime —
  and os.time() has one-second resolution, so two sessions opening inside
  the same second share one, and the stale answer would have passed. The
  poller's five-second interval makes that rare rather than impossible,
  and "rare" is not a property worth relying on when a counter is exact.

  ⚠️ FOUR HONEST LIMITS. macOS must be told to allow Hammerspoon to
  control Chrome (System Settings → Privacy & Security → Automation);
  until then the column stays empty and _G.urlReport() says so by name
  rather than leaving a blank column with no reason. Sessions under ten
  seconds are discarded, so a tab you flicked past never gets a row. A
  single-page app that changes the URL without changing the window title
  keeps the URL captured when the session opened. And a row whose answer
  had not arrived yet is written with an empty url rather than delayed.

  🎬 ⇪[ AND ⇪] NO LONGER LEAVE A WINDOW HANGING OFF THE MONITOR.
  LL: "I'm trying to show that VLC doesn't display correct. Using
  hyper+[/] doesn't all the way work. But hyper+any arrow is fine." Both
  halves of that were exactly right, and the second half is what
  identified the bug.

  Every arrangement in window_arranger COMPUTES a rectangle and asks for
  it. An app is free to answer with a different one, and some do: VLC's
  video window is aspect-locked with a minimum size, so asked to become
  the proportional version of itself on another monitor it keeps the
  width it wants — and accepts the origin it was handed. The result is a
  window hanging off the edge with its playlist sidebar sliced away,
  which is what LL's screenshot showed. moveToScreen's own
  ensureInScreenBounds does not catch this: it clamps the rectangle being
  REQUESTED, and the app resizes afterwards.

  So the frame is now READ BACK after the move and nudged in with
  setTopLeft — which moves without resizing, because resizing is the
  argument that window has just won. Trying to resize it again only
  restarts the fight. Right and bottom are clamped first and left and top
  second, so for a window WIDER THAN THE SCREEN the far edge is what
  overhangs and never the title bar or the left-hand controls. And when a
  window still does not fit, or refused to change monitor at all, the
  alert now SAYS SO — the old one showed "🪟 → monitor" unconditionally,
  so the one case worth knowing about looked exactly like success.

  Why the arrows were fine: a left-half snap starts at the screen's own
  left edge, so an app that refuses to shrink grows inward, where you can
  still see it. The same settle is applied to the halves, the split and
  the ⇪W summon anyway; a window that complied is never moved by it.

  🧪 TWO NEW SUITES, 130 CHECKS, EIGHT BREAK TESTS. tests/test_arranger
  drives the real bindings against a stub window that accepts origins and
  refuses sizes — a VLC in miniature — and tests/test_activity_url drives
  the real URL engine, including the tab-switch race, through the real
  poller. Two checks were rewritten after a break test failed to bite:
  one that claimed to prove the incognito guard and in fact proved only
  that the http-only backstop existed, and a migration test that
  re-implemented the CSV parser instead of running it.

```

```text
NEW IN 6.122.0 — TWO SEARCHES THAT WERE ONLY LOOKING AT HALF THE ROOM:

  ✋ THE EDITOR PICKER IS ON right ⌥⌥ NOW, AND ⌘ IS FREE AGAIN.
  6.121.0 offered LL the right ⌘ with the left one left to Alfred. What
  he did instead was better than what was offered:

      Alfred      → right ⌃⌃
      this picker → right ⌥⌥

  Two keys neither program has to share. Nothing depends any more on
  whether Alfred can tell its ⌘ keys apart, which was the one thing this
  config could not find out from in here — and the side machinery still
  earns its keep, because it is what makes right ⌥⌥ mean the RIGHT ⌥ and
  leaves the left one free. tapMod = "cmd" with tapSide = "either"
  restores the 6.116.0 gesture in one line.

  ⚙️ ⇪, SEARCHES THE SETTINGS, NOT JUST THE PANES.
  LL: "What does this mean? I wanted to be able to search all Settings
  app."

  A fair complaint. 6.119.0 searched the ~58 PANES — the destinations in
  the sidebar. It could find "Displays"; it could not find "Night
  Shift", which is a switch inside Displays. Nobody thinks "I need the
  Displays pane"; they think "where is Night Shift".

  There is no list of every setting macOS has that this config can read.
  Apple does not publish one, the panes are SwiftUI views rather than
  files on disk, and the index behind System Settings' own search box is
  private. So there are two answers, and the module is explicit about
  which is which:

    1. ~190 NAMED SETTINGS, hand-written and therefore exactly as
       complete as somebody made it. Each points at the pane that holds
       it and says where in that pane to look, so "hot corners" lands
       you in Desktop & Dock knowing it is at the very bottom. This is
       the fast half — one ⏎ and you are THERE.
    2. THE LAST ROW IS ALWAYS "🔎 Search System Settings for …", which
       hands your words to Apple's OWN search field: the complete index,
       maintained by the people who move the settings. Slower — it lands
       you in Settings looking at a result list — but it cannot be out
       of date and it cannot be missing an entry. The hand-written half
       is never a ceiling.

  🚨 THE HAND-OFF TYPES; IT DOES NOT POKE A VALUE IN. Setting AXValue on
  a SwiftUI search field frequently updates the text and runs no search:
  the binding never fires. So the field is focused and the characters
  are typed — real synthetic keystrokes, and therefore inside
  _G.withInjection like every other typing tool here, so autocorrect,
  the expander and the Key Caster do not treat this config's own typing
  as yours.

  ⏳ AND IT POLLS FOR THE FIELD rather than sleeping a fixed time, since
  System Settings can take a moment or an age to draw. If it never finds
  one it SAYS SO, with the query, rather than typing into whatever
  happens to have focus — blind keystrokes are how a search query ends
  up in a document.

  A term naming a pane that does not exist is dropped and counted, and
  the suite fails on the first orphan: a row that lists perfectly and
  does nothing on ⏎ is the exact failure this module's header complains
  about in Apple's URL scheme.

  📸 ⇪⇧4's SEARCH READS THE WHOLE FOLDER, AND THE TEXT INSIDE THE IMAGES.
  LL: "How do I search and bring up an image that is stored in the
  screenshots folder?"

  You could, and it was two things short of an answer.

    1. IT ONLY EVER SAW THIRTY FILES. shots.maxList caps the list for a
       good reason — every row decodes a whole PNG to draw a 72px
       thumbnail — but the SEARCH was filtering that same capped list.
       Anything older than your last thirty captures was unfindable and
       nothing said so. The cap is now a drawing limit only: the moment
       you type, the query runs over every file in the folder.
    2. A SCREENSHOT'S NAME IS A TIMESTAMP, which is the one thing you
       never remember about it. You remember what was ON it.

  So the search now asks Spotlight too, with mdfind restricted to that
  folder. That reaches the OCR text ⇪O's tagger has been writing into
  each screenshot's Finder comment since 6.98.0 — searchable all along,
  with nothing reading it back — plus whatever macOS indexed itself,
  which on recent builds includes text found in images. Rows say WHICH
  half found them, because "matched the name" and "matched the text
  inside it" are different claims.

  ⏳ THE SPOTLIGHT HALF IS DEBOUNCED AND ASYNCHRONOUS. Name matches
  appear as you type, Spotlight's fold in a moment later, and a result
  whose query is no longer in the box is DISCARDED rather than shown. A
  hit for a file that has since left the folder is dropped rather than
  offered as a row that opens nothing.

  ☁️ AND IT CAN HONESTLY FIND NOTHING. This folder is in OneDrive; a
  cloud-evicted file may not be indexed and Spotlight can be off for a
  volume entirely. The name search always runs, so the panel is never
  worse than it was — but the empty result says which halves actually
  ran rather than implying both did.

  🩹 ONE REAL BUG, FOUND BY A BREAK TEST THAT CRASHED WHERE IT SHOULD
  HAVE REPORTED. settings_panes' open() guarded with `not row.url`, and
  `not ""` is false in Lua — so a row carrying an empty string walked
  straight past it into hs.urlevent.openURL("") and then into a
  concatenation of a name such a row does not have. Guarded on type and
  emptiness now, and it names what it refused.

NEW IN 6.121.0 — THE LEFT ⌘ GOES BACK TO ALFRED:

  ✋ THE EDITOR PICKER NOW WATCHES THE RIGHT ⌘ ONLY.
  LL: "Right now, I use the cmd+cmd so technically it's a conflict with
  Hammerspoon. Can I use left cmd twice for Alfred and right cmd for
  Hammerspoon?"

  Yes — on this side of the fence, which is the honest shape of the
  answer. A flagsChanged event carries the KEYCODE of the modifier that
  changed, and left ⌘ (55) and right ⌘ (54) are two different keys. So
  the tap can be told to care about one of them, and it now is: the
  default gesture is right ⌘⌘, and 6.116.0's "either ⌘" is one setting
  away.

  Tapping left ⌘ twice does not merely fail to open the picker — it
  DIRTIES the press, which clears any half-made gesture. Reaching for
  Alfred can never leave this armed for whatever right ⌘ comes next.

  🚨 IT TAKES TWO TO SPLIT A KEY AND THIS CONFIG IS ONLY ONE OF THEM.
  Whether Alfred distinguishes the sides is Alfred's business and cannot
  be read from in here. If Alfred fires on BOTH ⌘ keys then right ⌘⌘
  opens Alfred as well as this picker, and no setting in this config
  changes that. Which is exactly why the modifier is a setting too:

      _G.editorPicker.tapMod  = "cmd" | "alt" | "ctrl" | "shift"
      _G.editorPicker.tapSide = "right" | "left" | "either"

  tapMod = "alt" puts the picker on right ⌥⌥, which Alfred is not
  watching at all. The test that decides between them takes ten seconds:
  tap the right ⌘ twice and see whether Alfred comes up.

  🚨 THE SIDE CHECK DOES NOT REPLACE THE keyDown WATCH, and 6.116.0's
  reason for that watch is untouched. Somebody who copies and pastes
  with the right ⌘ produces right-⌘C then right-⌘V, which passes the
  side check perfectly. Narrowing the gesture to one key narrows WHO may
  start it; it says nothing about what happened in the middle.

  ⚠️ A SIDE IT CANNOT READ IS REFUSED, NOT GUESSED — a guess is the
  conflict coming back. Refused presses are counted, and after twelve of
  them the Console says so ONCE and names the setting that takes the
  side out of it. _G.editorPickerReport() prints the gesture, both
  settings it is made of, how many times each ⌘ has been pressed this
  session, and a warning when the side you chose has never been seen —
  which is what a keyboard with no right ⌘ looks like from in here.

  A keyboard map that reports one keycode for both keys FAILS OPEN: the
  side is ignored and either key works, because a gesture that silently
  stopped working is worse than one that is merely not narrowed.

  🗂 The cheat sheet, the report and every Console line read the gesture
  from the setting rather than saying ⌘⌘ from memory, so ⇪/ cannot
  advertise a key the tap is not watching. Rewritten again in warm(),
  after machine-profile overrides land, since those are applied after
  setup() returns.

NEW IN 6.120.0 — THE OTHER EIGHT, AND THE KEY THAT WAS ALREADY TAKEN:

  6.119.0 shipped four of the twelve LL asked for in one message. These
  are the remaining eight, which closes the list.

  🗂 ⇪⇧' TAB SEARCH — every open tab, from anywhere.
  LL: "Can we search my current open tabs and then jump to that tab,
  from another application or on the desktop, in a folder? Essentially
  anywhere but the app can I do this."

  Yes, and that is the whole reason it is on ⇪. Press it in Finder, in
  Word, on the desktop, in a terminal, type three letters of the page's
  title, press ⏎, and that tab is in front of you. The browser does not
  need to be frontmost and does not need to be visible.

  Chrome, Safari, Edge, Brave and Arc are all asked, and each row names
  its own browser — so two copies of the same page in two browsers are
  two distinguishable rows. Adding another Chromium browser is one line;
  they share Chrome's AppleScript dictionary.

  ⚠️ A TAB IS ADDRESSED AS A POSITION, AND POSITIONS MOVE. There is no
  stable identifier AppleScript can use — you reach a tab as "tab 4 of
  window 2", which is where it is sitting right now. Drag a tab between
  the scan and the jump and those numbers point somewhere else. Two
  defences: the list is NEVER CACHED, so the numbers are milliseconds
  old, and the jump VERIFIES — it returns the URL it actually landed on
  and compares it, so "that tab moved" is something you are told rather
  than something you discover by reading the wrong page.

  🌐 ⇪6 NETWORK TOOLS — flush · ping · nslookup · traceroute.
  LL: "Give me network tools that are / flush / ping / nslookup /
  traceroute"

  Pick one that needs a host and a second box opens where whatever you
  type IS the host. No dialog, no form. Your clipboard prefills it with
  the scheme, path and port stripped off, because "ping
  https://docs.example.com/a/b" is a thing ping cannot do.

  The output comes back as a searchable list — one row per line, ⏎ copies
  that line — and the whole thing is on the clipboard before you have
  read it, because the next step is usually pasting it to somebody.

  🚨 A DNS FLUSH CANNOT FULLY WORK WITHOUT ADMIN, AND THIS ONE SAYS SO.
  It is two commands:

      dscacheutil -flushcache          ← no privileges needed
      sudo killall -HUP mDNSResponder  ← needs an admin password

  The second is the one that actually makes mDNSResponder forget, and it
  needs to signal a root process. On the work Mac it CANNOT succeed —
  and every "flush your DNS" instruction on the internet runs both and
  mentions neither. This runs both, checks each, and reports which half
  worked, because a half flush reported as a flush is how you spend an
  afternoon debugging a cache that was never cleared. When the privileged
  half fails, the alert names the remedy that needs no password: toggle
  Wi-Fi off and on.

  🖥 ⇪7 MAC PANEL — About This Mac, as a card.
  LL: "Can you create windows like Pomodoro for: About This Mac"

  The Pomodoro's shape: a small card in the corner of the screen you are
  looking at, draggable, above everything else. ⇪7 opens it, ⇪7 puts it
  away. It carries what Apple's own panel carries plus the four things
  you actually go looking for that Apple does not put on the front page —
  uptime, free disk, battery health, and this Mac's IP.

  ⚡ IT DRAWS BEFORE IT KNOWS EVERYTHING. Nearly all of it is sysctl and
  Hammerspoon's own APIs, which answer in microseconds. Two things do
  not: the MARKETING NAME ("MacBook Pro" rather than "Mac14,9") needs
  system_profiler, which takes one to three SECONDS, and the serial needs
  ioreg. So the card opens instantly and fills those two in when they
  land. A panel that takes three seconds to appear is a panel you stop
  pressing.

  ⚠️ AND "reading…" IS DIFFERENT FROM "—", deliberately. The first will
  change; the second will not. Showing one for the other leaves you
  waiting for a number that is never coming.

  ⏸ ⇪' PAUSE ALL AUDIO AND VIDEO.
  LL: "Can you create a key that will pause all audio and video?"

  🚨 READ THIS BEFORE BELIEVING THE NAME. macOS has no "pause everything"
  call and no API that enumerates what is making sound. What exists is
  the MEDIA KEY, which macOS routes to ONE app — whichever it currently
  considers "now playing", and the only mechanism that can reach a
  browser tab — and telling a scriptable player to pause BY NAME, which
  covers the desktop players and nothing else.

  So the key does both, and the alert says how many players it reached,
  so a miss is visible rather than something you wonder about.

  ⚠️ IT ONLY TALKS TO APPS THAT ARE ALREADY RUNNING, and that is not
  politeness: naming an application in AppleScript LAUNCHES it. A naive
  "tell application Music to pause" on a Mac with Music closed OPENS
  MUSIC, and a pause key that starts a music player is worse than no
  pause key. The same hazard governs ⇪⇧', which is why both check the
  running process list first.

  👻 ⇪` GHOSTTY HERE · ⇪⇧` REVEAL IT IN FINDER.
  LL: "Can we open a Ghostty terminal from current Finder folder; and
  open current Ghostty teminal path in Finder?"

  The first direction is easy and reliable. The second is the hard one
  and is worth saying why: A TERMINAL'S CURRENT DIRECTORY BELONGS TO THE
  SHELL, NOT THE WINDOW. Ghostty is a window around a process whose cwd
  changes every time you type cd, and it publishes that nowhere a
  neighbouring process can simply read.

  Two routes, in order. The WINDOW TITLE first — Ghostty sets it from
  OSC 7, which at a prompt is the working directory — because it is free,
  instant, and reads the FRONT window's own title. When the title is not
  a path (you are in vim, or ssh, or a long build), lsof on Ghostty's
  child shells is the fallback. That route cannot tell two Ghostty
  windows apart, so it takes the newest shell, and the alert says when it
  was used. A title that is not a path is never guessed at: revealing the
  wrong folder is worse than saying the title was not one.

  🔳 ⇪5 READ A QR CODE OFF THE SCREEN.
  LL: "How about an on screen QR reader?"

  It scans the WHOLE screen rather than asking you to drag a box, because
  zbar finds a code anywhere in the image and a region selection is a
  step that buys nothing. Press the key, the payload is on the clipboard.

  ⚠️ IT NEEDS zbarimg, WHICH macOS DOES NOT SHIP. There is no QR decoder
  in any Apple framework Hammerspoon can reach. `brew install zbar` and
  it works; without it the refusal says exactly that, rather than failing
  as though the code were unreadable. The PATH comes from
  screenshots.lua, which already hunts five install locations including
  the two no-admin Homebrew prefixes — asked for by service name rather
  than copied, because a second copy of that list is a list that drifts.

  ---------------------------------------------------------------------
  🚨 ⇪⇧, AND ⇪⇧. WERE ALREADY TAKEN
  ---------------------------------------------------------------------
  The first draft of this release put the network tools on ⇪⇧. and the
  Mac panel on ⇪⇧,. Both are owned by numpad_layer's laptop window row
  and have been since 6.114.0 — they are shrink and grow.

  The hyper sentry would have caught it at boot and printed a conflict,
  and then one of those two window keys would have been quietly dead
  until somebody read the Console. This one was caught by reading the map
  before writing the key rather than by the boot, which is the cheaper
  place to catch it. A check in the suite now asserts that nothing in
  power_tools claims either.

  That is the second time in two releases that running out of keys has
  produced a near-miss, and the reason is worth stating plainly: EVERY ⇪
  LETTER AND EVERY ⇪⇧ LETTER HAS BEEN CLAIMED SINCE 6.104.0. What is left
  is punctuation and seven digits, and digits carry no mnemonic — which
  is why ⇪6 and ⇪7 matter more in ⇪⇧/ than on the keyboard, and why the
  modules say so rather than pretending otherwise.

  ---------------------------------------------------------------------
  🚨 WHAT THE GATE CAUGHT
  ---------------------------------------------------------------------

  🚨 THE EXTERNAL-BINARY REVIEW FOUND SIXTEEN UNDECLARED COMMANDS — and
  the interesting half is the ones it could NOT see. test_diagnostics
  scans every module for quoted absolute paths and fails on anything not
  on its reviewed list, which is the guard that stops a dependency
  drifting in unnoticed. A binary written INSIDE a longer shell string —
  "/usr/bin/dscacheutil -flushcache; …" — is invisible to that scan.

  Three of the new modules were written that way, and would have shipped
  eight commands that the review had never seen and never approved. Every
  one is a named constant now, so the guard is real rather than
  accidentally bypassed, and all sixteen are declared with what they are
  for. ps and kill in ⇪⇧; were in the same position and are fixed too.

  🚨 THE TAB JUMP COUNTED A WRONG LANDING AS A SUCCESS. ts.jumps was
  incremented before the URL comparison, so _G.tabReport() would agree
  with you about a jump that went to the wrong page — a report that
  confirms something that did not happen is worse than no report. Found
  by its own test on the first run, and the order is asserted now.

  🚨 THE FIRST DISK FIGURE COULD HAVE BEEN WRONG BY 1024×. The obvious
  route is hs.fs.freeSpace, whose unit has differed between Hammerspoon
  versions — and no value it returns distinguishes the two, because 400
  GB in bytes and 400 GB in kilobytes are both plausible readings of a
  real Mac. The first draft guessed with a threshold. `df -k` says
  kilobytes in its own name: one multiplication, no guess, and the test
  pins the exact figure so "393 MB free" and "393 TB free" both fail.

  ---------------------------------------------------------------------
  📋 AND THE ANSWER TO THE ONE QUESTION THAT WAS NOT A TOOL
  ---------------------------------------------------------------------
  LL: "A while back I asked for a tool that would save any and all URLs
  and Window titles would be posted to a .csv file. Did we get around to
  that?"

  HALF, and the half that exists has existed for a long time. WINDOW
  TITLES: yes — activity_history CSV has recorded app + window title per
  interval since well before the rename, ⇪⇧W searches it, and ⇪space
  reads it as one of its sources. URLS: no. ⇪Y archives Chrome's own
  history database, which is a different thing from "every URL that
  passed through a window" — it is Chrome's record, not an observation of
  yours, and it says nothing about Safari or about a URL you looked at
  without navigating. A combined one was never built, and nothing in this
  release builds it either.
```

```text
NEW IN 6.119.0 — TWELVE TOOLS ASKED FOR, THE FIRST FOUR OF THEM, AND
THE KEYBOARD RUNNING OUT OF LETTERS:

  LL asked for twelve things in one message. Four are here; the rest are
  named at the bottom of this entry with what each one needs, so nothing
  in that list quietly becomes something nobody wrote down.

  🔑 FIRST, THE CONSTRAINT THAT SHAPED ALL OF IT: EVERY ⇪ LETTER AND
  EVERY ⇪⇧ LETTER IS CLAIMED. win_pin called ⇪⇧U "the last free ⇪⇧
  letter" in 6.104.0 and it was right. Fifty-two letter combos,
  fifty-two owners, and that has been true for fifteen versions without
  anybody stating it as a fact about the config rather than a remark in
  one module's header.

  So these four land on PUNCTUATION. That is not a workaround and not a
  consolation prize: ⇪, sits exactly where ⌘, sits in every Mac
  application ever written, and the other three are one reach from the
  home row. All four are ALSO runnable from ⇪⇧/ with no key at all, the
  way the daily rollup has been since 6.105.0 — and that matters more
  for these than for anything above them, because a key nobody can guess
  is a key nobody presses. ⇪⇧/ then "kill" is how ⇪⇧; will actually be
  reached until the punctuation is in the fingers.

  🔎 ⇪.  MENU SEARCH — the front app's menus, by typing.
  LL: "For the focused application, can you create something to search
  through menu options for front-most application"

  Every menu item the frontmost app publishes, flattened into one list.
  "pdf" finds File ▸ Export As ▸ PDF… without knowing it was under
  Export. Each row shows the item's own keyboard shortcut where it has
  one, and the path it came from, and both are searchable.

  Greyed-out items are LISTED rather than hidden. Hiding them answers
  "where is Paste Special?" with an empty list, which reads as "this app
  has no Paste Special" rather than "not right now". They are marked,
  and picking one says the app is refusing it — not the list.

  🚨 THE SCAN IS ASYNCHRONOUS AND THAT IS NOT OPTIONAL. The blocking
  form of getMenuItems() is documented by Hammerspoon itself as able to
  "take a very long time", and on an app with deep menus it holds the
  main thread — the thread that reads your keyboard. A keyboard that
  stops answering is indistinguishable from a crash. The callback form
  runs; a timeout turns a slow app into a named refusal rather than a
  key that sometimes does nothing.

  ⚙️ ⇪,  SETTINGS PANES — System Settings, by name.
  LL: "Can you create a tool that lets me search then open macOS
  settings pane?"

  The reason this earns a key: THIS CONFIG TELLS YOU TO VISIT
  "System Settings → Privacy & Security → Accessibility" IN NINE
  DIFFERENT ALERTS, and that trip is open Settings, scroll a sidebar of
  thirty, find Privacy & Security, scroll ITS list of twenty. All five
  of those destinations — Accessibility, Screen Recording, Automation,
  Input Monitoring, Full Disk Access — are one row each now.

  ⚠️ AND THE HONEST LIMIT, STATED IN THE MODULE AND IN THE REPORT:
  macOS does not refuse a pane identifier it no longer recognises.
  System Settings opens at whatever page it likes and `open` still exits
  0, so there is no return code this module can check and no way for it
  to verify a destination. It can only report that it asked.
  _G.settingsProbe() opens each entry in turn, slowly enough to watch,
  because that is the only test of somebody else's URL scheme that tells
  the truth.

  💀 ⇪⇧; APP KILL — find the process, end the process.
  LL: "I need power tool to Kill an Application?" — and sent the Alfred
  Ruby workflow he had been using, built around
      ps -A -o pid -o %cpu -o comm | grep -i …

  This is that, with the ps output in a chooser. ⏎ asks it to quit, ⌥⏎
  forces, and picking a process that ignored the quit forces it too.

  The Ruby version let you type "chrome:renderer" to filter by a command
  line ARGUMENT, because a Mac running eleven Chrome helpers needs some
  way to tell them apart. An hs.chooser gives no hook to reinterpret the
  query mid-type, so that syntax cannot be reproduced faithfully. What
  replaced it reaches the same place by a shorter road: the FULL command
  line rides in each row's subtitle and the chooser searches subtitles,
  so typing "renderer" filters on it — no colon, no special form, and it
  composes with the name.

  🚨 FOUR NAMES ARE REFUSED OUTRIGHT, INCLUDING UNDER ⌥. launchd,
  kernel_task, WindowServer and loginwindow. kill -9 on WindowServer is
  not an inconvenience — it logs you out, every app, no save prompt. ⌥
  is the "I mean it" modifier and this is the one place where meaning it
  is not enough. Hammerspoon refuses itself too, not to protect itself
  but because quitting it from inside itself leaves you with no ⇪ and no
  sign that it worked.

  🧰 ⇪;  POWER TOOLS — four things too small for a key each.

  ⌨️ TYPE THE CLIPBOARD.
  LL: "Did you create my tool that allows me to paste into fields that I
  cannot? These would be confirmations like typing your email twice."

  🚨 THE ANSWER IS NO, AND IT IS WORTH SAYING PLAINLY: nothing anywhere
  in this config typed the clipboard rather than pasting it. "Copy as
  Plain Text" in ⇪⇧A strips formatting, which is a different problem
  with a similar shape, and is probably what was being half-remembered.

  A "confirm your email address" field that refuses ⌘V is not protecting
  anything — the page has an onpaste handler returning false, believing
  that retyping proves you read it. Synthetic keystrokes are
  indistinguishable from fingers, so the field takes them, and the typo
  the exercise exists to prevent cannot happen.

  🚨 SECURE INPUT IS CHECKED BEFORE A SINGLE CHARACTER GOES OUT. When a
  password field has secure event input on, macOS drops synthetic
  keystrokes at the window server: nothing arrives, no error is raised,
  the field stays empty. Typing into that and reporting success would be
  the worst outcome available. And the text waits for ⌘⇧⌃⌥ to come up
  first — you reached this row through ⇪, and a keystroke posted under a
  live ⌘ is a menu command in somebody else's app.

  🔢 COUNT THE SELECTION.
  LL: "1) total word count, 2) total character count, and 3) total
  sentence count"

  All three, plus lines and paragraphs. The selection is read through
  accessibility first, which costs nothing and disturbs nothing; apps
  that do not answer that fall back to a ⌘C with the clipboard SAVED
  FIRST AND PUT BACK AFTER, and the pasteboard watcher suppressed across
  the round trip so ⇪V's history does not fill with things you never
  copied.

  ⚠️ THE SENTENCE FIGURE CARRIES A ~ AND THE OTHERS DO NOT. It counts
  runs of . ! or ? followed by whitespace or the end of the text.
  "Dr. Smith went to the U.S. yesterday." is three by that rule and one
  by yours. Doing better needs a tokenizer with an abbreviation list,
  which is a real library rather than twenty lines — so it is presented
  as an estimate instead of being quietly wrong. Words and characters
  have no such problem, and characters are counted in CHARACTERS: a
  curly apostrophe is three bytes and one character, and # would have
  reported every em-dash-heavy paragraph as longer than it is.

  📋 STRIP CLIPBOARD FORMATTING — and say how many flavours went away.
  "Stripped" with nothing visibly different is indistinguishable from
  "did nothing", and this is a tool you reach for precisely when you
  cannot see whether it worked.

  ℹ️ FILE METADATA — every mdls attribute of the Finder selection, as a
  list you type into rather than a window you scroll, because what you
  usually want from metadata is ONE value in the clipboard. ⏎ copies it.

  ---------------------------------------------------------------------
  🚨 THREE THINGS CAUGHT BEFORE THEY SHIPPED
  ---------------------------------------------------------------------

  🚨 hs-lint FOUND A SCAN THAT WOULD HAVE BEEN DEAD ON ARRIVAL.
  settings_panes captured one return value from hs.fs.dir. The iterator
  needs the second one; `for e in iter do` throws "directory metatable
  expected, got nil" at RUNTIME and never at load, so the .prefPane scan
  would have found nothing, said nothing, and looked exactly like a Mac
  with no third-party panes installed. The suite's hs.fs.dir stub now
  REFUSES to iterate without its directory object, so it cannot return.
  The walk is also pcall'd per directory now: one unreadable folder must
  cost that folder, not the whole picker.

  🚨 THE FIRST whenClear USED TWO TIMERS AND BOTH COULD FIRE. A doWhile
  to wait plus a doAfter to decide what happened next — and "the
  clipboard was typed twice" cannot be undone out of a text field. It is
  one timer with one callback now, and the test reassembles everything
  that was typed and asserts exactly one copy of it. Reintroducing the
  two-timer shape fails that check, which is how it was confirmed to
  have teeth rather than assumed to.

  🔢 THE SUITE COUNTS IN GUIDE.md WERE WRONG A SECOND TIME. 6.118.0
  corrected "forty-eight Lua suites" — the stage count wearing the wrong
  label — and left the stage figure at forty-eight, which was ALSO
  wrong: the gate reported fifty at the time. Two wrong numbers in one
  paragraph, one of them introduced by the fix for the other. All three
  figures are measured off the gate now (forty-nine Lua suites, 4,456
  checks, fifty-four stages) and GUIDE.md tells you to read them from
  the gate rather than from the paragraph.

  ---------------------------------------------------------------------
  📋 THE EIGHT NOT IN THIS VERSION, AND WHAT EACH NEEDS
  ---------------------------------------------------------------------
  Written down so none of them quietly becomes something nobody
  recorded. All eight are next.

    🗂 SEARCH OPEN BROWSER TABS AND JUMP TO ONE, from anywhere.
       Chrome and Safari both enumerate their tabs over AppleScript and
       both can raise one. Needs a separate osascript process, for the
       reason universal_actions documents at length.
    ⏸ ONE KEY THAT PAUSES ALL AUDIO AND VIDEO. The media key reaches
       whichever app macOS considers "now playing" — one app, not all —
       so this is a media key PLUS named pauses for the players that
       accept one. That limit will be stated on the key, not discovered.
    🖥 ABOUT THIS MAC AS A PANEL, in the Pomodoro's shape.
    🌐 NETWORK TOOLS — flush DNS, ping, nslookup, traceroute, with the
       output somewhere you can read and copy it.
    👻 GHOSTTY ↔ FINDER, both directions.
    🔳 AN ON-SCREEN QR READER. Half of this already exists: screenshots
       finds zbarimg when Homebrew has it, and ⇪⇧4's "recognize
       text/QR" uses it. What is missing is a key that grabs a region
       and decodes without going through the screenshot panel.

    And two answers rather than tools:
    📄 "A while back I asked for a tool that would save any and all URLs
       and Window titles to a .csv file. Did we get around to that?"
       HALF. Window titles yes — activity_history CSV has recorded
       app + window title per interval since long before the rename, and
       ⇪⇧W searches it. URLs no: ⇪Y archives Chrome's own history
       database, which is a different thing from "every URL that passed
       through a window". A combined one was never built.
    📋 STRIP CLIPBOARD FORMATTING already half-existed as ⇪⇧A's "Copy as
       Plain Text". ⇪; now has it as a first-class row, which is where
       it should have been.
```

```text
NEW IN 6.118.0 — TWO LISTS THAT LOSE YOUR PLACE, AND NO LONGER DO:

  🔎 SEARCHING THE CHEAT SHEET NO LONGER COSTS YOUR PLACE IN IT.
  LL: "The cheat sheet remembers its position when I scroll. But loses
  it when I search."

  Both halves of that were true, and only one of them was deliberate.
  Typing a filter goes to the TOP on purpose and still does: a filtered
  sheet is a different, shorter list, and row 40 of the old one is blank
  space that reads as "found nothing". What was missing is the way BACK.
  Clearing the query rebuilt the FULL list at row 1, so a search cost
  you your place whether it found anything or not — and the cheapest way
  to look something up was the one that threw away where you were.

  The sheet now records the row a search took you FROM, at the moment
  the query leaves empty, and returns you to it when the query comes
  back to empty. Both routes out of a search are covered, because there
  are two: ⌫ back to nothing, and Esc, which clears before it closes.
  Closing while still filtered stores that same row, so ⇪/ reopens you
  where you were reading rather than where the filter had you.

  🚨 AND hide() HAS BEEN CLAIMING THIS SINCE 6.111.0. Its comment said
  that closing while filtered "keeps the last row you were on BEFORE you
  searched". It did no such thing: it kept whatever was stored at the
  PREVIOUS close, which is that row only if you had not scrolled since
  opening. The sentence is true now, and the check that holds it to it
  deliberately arranges for the stored row and the current row to
  differ — with the old code it stores the wrong one and fails.

  ✏️ cheatSheet.rememberScroll = false still turns the whole thing off.

  🗂 ⇪⇧T IS SECTIONED BY COLLECTION, WITH YOURS AT THE TOP.
  LL: "Can you separate the snippets into sections with my textpanders
  first?"

  One flat A–Z list of 2,006 rows put the 80 snippets LL wrote among
  1,349 emoji and 548 compose-key sequences. Alphabetical is a fine
  order for a list you can see the whole of, and this is not one — and
  the alphabet was actively working against him here, since ComposeKey
  and Emoji_Pack both sort ahead of textpanders.

  Every collection now gets a heading row, and the sections come in
  rank order: collections named in exp.sectionOrder first (textpanders,
  by default), then anything found in your own snippets folder, then
  the shipped packs A–Z, then the ⚡ actions — which are not snippets at
  all but modules borrowing a trigger, and belong at the end rather than
  salted through your own writing. A–Z runs INSIDE a section now, not
  across the whole panel. A heading is inert: it carries no pick, and
  the callback returns on it before it looks one up.

  🚨 TWO DIFFERENT IDEAS OF "MINE", which is why there is a list as well
  as a flag. Anything under exp.dir is yours BY CONSTRUCTION — you
  imported or wrote it, and it already wins a collision — so it needs no
  naming. textpanders is the awkward case: your own export, but SHIPPED,
  sitting on disk beside four packs you downloaded and indistinguishable
  from them by any structural test. Only you can say it is yours, so you
  say it in exp.sectionOrder.

  ⚠️ SECTIONS ARE THE RESTING ORDER, NOT A SEARCH ORDER, and that is
  hs.chooser's doing rather than a decision made here: the moment you
  type, it scores every row against what you typed and reorders the
  panel itself. Nothing in Lua can hold a section together through that.
  What survives is the pack name, now printed on every row's second line
  as well as in its heading, so a match still says where it came from.

  ✏️ exp.sections = false restores the one flat A–Z list of before.

  🧪 AND ONE OF THE NEW CHECKS PASSED AGAINST BROKEN CODE. "⚡ actions
  are LAST" went green with the actions deliberately ranked as an
  ordinary shipped pack — because "⚡" is 0xE2… in UTF-8 and sorts after
  every ASCII pack name there is. The check was reading a lucky byte and
  calling it an ordering. The fixture now carries a pack whose name
  begins with a 4-byte emoji, which sorts AFTER the actions heading, so
  the position is decided by the rank again and the break fails as it
  should. Third one of these in three releases: a check that excludes
  nothing still goes green, and the only way to know is to break the
  code on purpose and watch.

NEW IN 6.117.0 — TWO DELETIONS. NOTHING GAINED A FEATURE:

  📧 THE OUTLOOK PROBE IS DELETED, NOT SHELVED.
  LL: "IT won't approve it… remove the outlook probe and the test
  stage."

  6.105.0 took the probe out of the module list and left the file in
  tools/, on the reasoning that a diagnostic costing nothing at boot
  costs nothing at all. That was wrong, and the previous release proved
  it: the probe was still 41 KB of every zip, still held a row on the
  health monitor's cheat sheet pointing at a dofile() nobody was ever
  going to type, and still ran a 46-check suite on every release for a
  question that has been answered. Route A came back hollow and route B
  is blocked by tenant policy. There is no third route to keep a probe
  warm for.

  Gone: tools/outlook-probe.lua, tests/test_outlook_probe.lua, the
  health monitor's cheat sheet row, the runner stage. Fifty stages now,
  not fifty-one. init.lua's module list and safe-mode notes say the
  probe was deleted and why, so that this is not re-litigated in six
  months by someone reading a gap between two version numbers.

  🚨 THIS IS NOT AN OUTLOOK PURGE, and the difference matters. Safe
  Links unwrapping (⇪⇧L) still unwraps safelinks.protection.outlook.com,
  focus mode still reads the reminder popup for a Teams join link —
  which is the one calendar signal New Outlook did not take away —
  update_tracker still carries the cask and app_watcher still carries
  the app. Those work, they are used daily, and none of them was part of
  the automation question the tenant policy closed.

  📦 THE ZIP IS 40% SMALLER, AND NOTHING WAS LEFT OUT OF IT.
  LL: "can you reduce the file size at all: it's now 2.1 mb."

  2,006 .json snippet packs were 797 KB of that 2.1 MB — and
  text_expander.lua does not read them. It reads snippets/bundled.lua,
  and its own comment has said so since 6.105.0: "IF THE TABLE LOADS,
  THE PACKS ARE NOT SCANNED." Every release since has shipped 2,006
  files that the config opens and deliberately ignores, most of the cost
  being the filenames rather than the ~150 bytes inside each one.

  All 2,006 snippets still ship, in the 128 KB table that was already
  doing the work. Nothing you can type changed. The packs stay in the
  working tree because tools/build-snippets.lua rebuilds the table from
  them; they simply stop travelling.

  🚨 YOUR OWN IMPORTS ARE IN A DIFFERENT FOLDER AND ARE UNTOUCHED. Those
  live under the OneDrive logs folder (exp.dir), not in the config, and
  are scanned on every load exactly as before — that scan is why the
  directory code stays. And hs-install.sh has never deleted the old
  packs out of ~/.hammerspoon/snippets, so the ones already on your Mac
  stay where they are; they were being ignored in favour of the table
  anyway.

  🕰 A SUITE THAT ONLY PASSED ON THE DAY IT WAS WRITTEN.
  Found while gating this release, and not something LL reported.

  test_rollup pinned its fixtures to a hardcoded 2026-08-19 and then
  called roll.text() with NO ARGUMENT, so the module fell back to the
  real clock. The two agreed on exactly one calendar day. On 2026-08-20
  "today's documents appear" failed — and the check under it, "🚨 and
  YESTERDAY's do not", turned out to have been passing vacuously: once
  the real date matches neither fixture, nothing appears at all and an
  exclusion check that proves nothing still goes green. That is the same
  dead-guard shape as the .superseded exclusion caught in 6.116.0.

  Every call now passes the day explicitly, and ONE new check covers the
  no-argument default against the real clock, because that is the path
  16:01 actually takes in production. Both were confirmed failing
  against a deliberately broken daily_rollup.lua before being kept.
  daily_rollup.lua itself was correct and is unchanged.

NEW IN 6.116.0 — FIVE THINGS LL ASKED FOR, IN THE ORDER HE ASKED FOR
THEM (#16, #15, #11, #14, #17):

  🗂 ⌘⌘ OPENS EVERY EDITOR AT ONCE.
  LL: "Right now a double-click of the cmd+cmd key pressed quickly.
  Could I bring up all my editor windows up and then let me select the
  one I need to copy from or edit from?"

  Tap ⌘ twice, quickly, touching nothing else. A picker lists every
  editor this config owns — the Capture Pad, the Note Pad, the OCR text
  store, clipboard history, window pins, the screenshot editor — sorted
  with whatever is open at the top and whatever has text in it next, and
  with how much is in each one. ⏎ opens the one you chose, or brings it
  to the front if it is already up. ⌥⏎ copies its text WITHOUT opening
  anything, which is the "copy from" half of the ask. ⇪⇧Z opens the same
  picker for when the tap is not running.

  🚨 THE TAP WATCHES keyDown AS WELL AS THE MODIFIERS, and that is the
  whole design rather than an implementation detail. A flagsChanged-only
  watcher cannot tell these two apart:

      ⌘C then ⌘V     cmd↓ · c · cmd↑ · cmd↓ · v · cmd↑
      ⌘ tapped twice cmd↓ ·   · cmd↑ · cmd↓ ·   · cmd↑

  It cannot see the middle column. Copy-then-paste — which everybody
  does forty times a day — would have opened the picker over whatever
  you were doing, and timing does not separate them because copy-paste
  is fast on purpose. So this is the FOURTH global keyboard tap in this
  config, held to every rule the other three follow: one return
  statement and it returns false, it reads no keycodes, it stands down
  for the shared injection guard, and five consecutive throws switch it
  off while ⇪⇧Z keeps working.

  🚨 AND ⏎ ON AN OPEN EDITOR NEVER CALLS show(). pad.show() and
  np.show() TOGGLE — right for their own keys, exactly wrong here — and
  closing the Note Pad FILES the draft. Picking an open pad out of a
  list of editors in order to go and READ it must never be the keystroke
  that files it, so the registry keeps `view` and `show` as separate
  fields and the picker only ever calls `show` on a surface that is
  closed.

  Editors register themselves into _G.editors the way they already
  register into _G.movablePanels, so this module names no other module
  and one that is not loaded contributes no dead row. A source scan
  fails the suite if any of the six stops registering — the escape-
  router roster rotted twice before anyone noticed, and this is the same
  shape of registry.

  🖱 ⇪⇧F RIGHT-CLICKS WHEREVER THE POINTER IS.
  LL: "I need a right key tool that works to generate a right-click for
  files, chrome, etc. If it is anything that has a right-click, I want
  to be able to access it."

  The mouse grid (⇪X) has right-clicked since 6.45.0, but only as the
  last step of aiming: ⇪X, type the cell letters, ⇧space. That is the
  right tool when the pointer has to get somewhere first and the wrong
  one when it is already sitting on the file.

  ⏳ IT WAITS A FEW MILLISECONDS FOR THE MODIFIERS TO COME UP, and that
  is not fussiness. A context menu reads the modifiers held when it
  OPENS: ⇧ makes Chrome deliberately bypass a page's own menu and show
  its own, and ⌥ swaps half of Finder's menu for its alternates. ⇪⇧F
  means ⇧ is held at the moment you press it, so a click posted on the
  keypress opens the WRONG MENU every single time — which reads as the
  feature being half-built rather than as a modifier leak. It polls for
  the keys to clear, fires the moment they do, RE-READS the pointer (the
  trackpad is under your other hand) and fires anyway after 300ms rather
  than swallowing the press. The posted events also carry explicitly
  empty flags, which is why they are built by hand instead of through
  hs.eventtap.rightClick.

  It asks Accessibility nothing about what is under the pointer — no
  focused element, no selected file, no window tree. A test reads the
  source and fails if that changes, because that promise is the reason
  "anything that has a right-click" is true.

  💾 _G.saved() PROVES THE LOGS ARE ACTUALLY SAVING.
  LL: "How do I know all my logs and other tracking files/editing files
  like OCR edits are actually saving? Should we build in a Hammerspoon
  console that captures if it does, but not floor the console like
  messages in the past?"

  🚨 IT WATCHES THE FILES, NOT THE WRITES. The obvious build wraps every
  write and logs the bytes. It answers the wrong question, and it
  answered it wrong on this very Mac one version ago: in 6.115.0 THREE
  FILES SHARED A NAME AND TWO OF THEM WERE FROZEN. Every write
  succeeded. Every write went to the right file. A write-logger would
  have printed a cheerful line each time while LL sat looking at a file
  that had not changed since July, because the file he opened was not
  the file being written.

  So it reads the disk: every log file with its size, its row count,
  when it was last written and how much it has grown since this config
  booted — plus a round trip that writes a probe file into the Logs
  folder, reads it back, compares it and deletes it, because "the folder
  exists" and "the folder will take a write right now" are different
  claims and only the second one is the question when OneDrive has gone
  offline.

  🔇 AND IT DOES NOT FLOOD THE CONSOLE. The background check runs every
  30 minutes and prints on exactly three conditions — a file that has
  vanished, a file that has shrunk, two files that look like the same
  log with one of them stale — and says each ONE TIME per session. On a
  healthy Mac it is silent all day.

  🚨 ONLY THIS MAC'S TAG IS STRIPPED WHEN COMPARING NAMES. The Logs
  folder is in OneDrive, so the work Mac's file sits right beside the
  home Mac's and is SUPPOSED to be untouched for days. A rule that
  stripped any machine tag would have cried wolf every session on the
  two-Mac setup this config is built around.

  It binds no hotkey: every single-letter ⇪ and ⇪⇧ key was already
  taken, and a module that quietly grabbed one would have shadowed a
  tool that works. It is _G.saved() in the Console and a WHAT IS SAVING
  block inside ⇪⇧D, which is the key you already press when something is
  wrong. warnWriteFailed also counts its failures now, before its
  once-only alert gate rather than after: one failure and forty failures
  used to look identical.

  ⌨️ THE KEY CASTER GROWS, NAMES THE APP, AND SHOWS EXPANSIONS.
  LL: "I need the application it is in while it is capturing keys? It's
  great for displaying but it's not that useful", "Can the keycaster be
  bigger and show text expansion key?", and "I need the keycaster grow
  in size as keys are sent."

  📏 The last two were one fix. It was a fixed 400×600 box, so one
  keystroke drew one line at the top of a rectangle six lines tall and
  mostly air — which is what made "can it be bigger" a strange request
  to receive about a panel already using 68pt type. It is now exactly as
  tall as the lines it holds and as wide as the widest of them, which is
  what lets the type be large without the box owning the screen. It
  grows DOWNWARD and LEFTWARD, keeping the right edge and the vertical
  centre, because anchoring the left edge would make every new keystroke
  shove the panel sideways under your eye while you are reading it.

  📱 The frontmost app's name sits above the keys, smaller and dimmer,
  because it is context rather than content — and it is cached for half
  a second, since hs.application.frontmostApplication() is a call into
  the Accessibility API from inside an event tap.

  ⌨️ A snippet firing gets a line: ⌨ hte → shorthand. 🚨 The expander
  has to tell us, because the caster cannot see this for itself and must
  not: a snippet is a burst of synthetic keystrokes and the caster
  stands down for the shared injection guard the whole time they arrive.
  🔒 It shows the TRIGGER, not the text: those snippets hold real email
  addresses, a phone number and an employee ID, and a panel that paints
  them across the screen is one screen-share away from being the wrong
  tool. kc.showExpansionText = true for a demo.

  🧹 AND FOUR OF MY OWN CHECKS PROVED NOTHING UNTIL THEY WERE FIXED —
  each found by deliberately breaking the code they guard and watching
  them pass anyway:
    · the .superseded exclusion in the write ledger was dead code,
      because the identity function stripped only one extension so a
      retired copy never grouped with its live original;
    · the key caster's app-name cache check pressed the same key six
      times, and the double-event dedupe window swallowed five of them
      before they reached a redraw;
    · the key caster's new sections ran after a section that loads a
      SECOND copy of the module and re-points every published global at
      it, so they were driving a caster that was switched off;
    · and the right-click test took the whole file down on a nil timer
      instead of reporting the failure it had found.

  Sentries: modules 46 → 49 (editor_picker, right_click, write_ledger),
  test stages 48 → 51, hs-doctor and INSTALL.md counts moved with them.
  The hotkey sentry caught ⇪E on the first run (§0.4 has held it for the
  cheat sheet's entry editor since long before this release) and the
  one-owner-per-key audit caught a cross-reference row that claimed ⇪X.

NEW IN 6.115.0 — FOUR THINGS LL ASKED FOR, AND THE FILE THAT WAS LYING
TO HIM:

  📅 THE FILE CHANGES CSV LEADS WITH ITS DATE, IN ISO 8601.
  LL: "On the {X} file, the date should be first? Can we do that & fix
  the current file?" — attaching a screenshot of
  file_changes-Lees-MacBook-Air.csv.

  Both halves of that were a real defect rather than a preference.
  The timestamp was the FIFTH column, in a log whose entire purpose is
  when-did-this-file-move: four columns of names and paths to scroll
  past before reaching the one fact you opened it for. And it was
  written DD/MM/YY HH:MM, which Excel on a US locale reads as MM/DD/YY
  — "11/07/26" is the 11th of July here and November 7th there, and
  nothing in the file says which. Worse, Excel imports that column as
  TEXT, so sorting it sorts alphabetically and every row beginning
  "11/" clumps together regardless of month or year.

  🔍 THAT IS PROBABLY THE "ONLY SHOWS JULY 11TH" REPORT. Not missing
  data — a sort artefact of an ambiguous format. (See the frozen-file
  entry below for the other half of the answer.)

  The columns are now
      timestamp,file_name,new_name,present_location,moved_location,event,epoch
  with an ISO 8601 timestamp: unambiguous to a human, unambiguous to
  Excel, and correct when sorted as plain text. Only the timestamp
  moved; everything else kept its order, so a spreadsheet built on this
  file needs one column re-pointed, not six.

  🔧 YOUR EXISTING FILE IS MIGRATED IN PLACE at the first boot on this
  version, and 🚨 THE OLD DATE TEXT IS NEVER PARSED. Every row already
  carries an `epoch` column, so the new timestamp is REGENERATED from
  that number. There is no day/month ambiguity to get wrong because the
  ambiguous field is discarded rather than interpreted — a migration
  that "helpfully" read 11/07/26 would silently move a third of the
  history to the wrong month and look perfectly plausible doing it. A
  test feeds in rows whose text says 1999 while their epoch says 2026
  and insists the epoch wins.

  The pre-migration file is kept as file_changes-<Mac>.csv.before-iso-dates.
  The migration is lossless by construction, but that is a claim about
  the code, not about the disk it just ran on.

  DETECTION IS PER ROW, NOT PER FILE. This CSV is appended to by a
  long-running process, so upgrading mid-session leaves 6.114.0 rows
  above and 6.115.0 rows below. A loader that read the header once and
  trusted it for the whole file would mis-read half of them — silently,
  since every field is a string and none of them would raise. ⇪space's
  file-move source has the same mapper for the same reason, and cannot
  even see a header: it reads only the last 256 KB of the file.

  🚨 THREE FILES SHARED A NAME AND TWO OF THEM WERE FROZEN.
  This is the other half of the "only July 11th" answer, and LL could
  not have found it: adoptLegacyFile copied the old file forward when
  the logs moved into OneDrive and left the original in place FOREVER,
  under a nearly identical name, with nothing marking it dead:

      ~/.hammerspoon/activity_history.csv     frozen on upgrade day
      <Logs>/activity_history.csv             frozen on upgrade day
      <Logs>/activity_history-<Mac>.csv       the only live one

  Open either of the first two and you are reading a snapshot. The old
  comment in init.lua said the legacy file was "left in place untouched
  (delete it yourself whenever you're confident)" — which asks you to be
  confident about precisely the thing the naming has hidden. The same
  pattern applied to file_changes.csv, custom_shortcuts.json,
  autocorrect.csv, image_text.csv, the clipboard store and
  asana_history.json: seven adoptions, seven stale twins.

  An adopted original is now RENAMED to <name>.superseded. Renamed, not
  deleted — this config does not destroy your data to tidy up — but
  renamed to something Excel will not open on a double-click and no
  human will mistake for live.

  🔗 AND A RETIRED FILE IS STILL A VALID ADOPTION SOURCE, which matters
  because <Logs> is inside OneDrive and therefore SHARED BY BOTH MACS.
  Retiring on the home Mac would otherwise pull the adoption source out
  from under the work Mac's first boot — the exact two-machine data loss
  this fix exists to prevent. Reading .superseded as a fallback costs
  four lines and makes retirement lossless.

  🚨 AND IT RETIRES ON EVERY BOOT, not only on a fresh adoption. Both of
  LL's Macs adopted these files releases ago, so a fix that only ran in
  the adoption branch would have fixed nobody — every machine that has
  the problem is already past it. Once renamed it is one failed io.open
  forever after.

  The copy is also READ BACK AND COMPARED before the original is
  retired. io.write returning without error is not proof the bytes
  landed: a full disk or an online-only OneDrive folder can take the
  write and lose it, and renaming the original on that assumption would
  leave the only good copy under a name nothing reads.

  ⏱ HOLD AN ARROW IN THE MOUSE GRID AND IT KEEPS MOVING.
  LL: "Can you make it so that hyper+X allows the arrows to be pressed
  and held down? Right now you have to rapidly hit the key to move."

  The cause was the shape of the call, not the nudge. Every landed-mode
  arrow was bound with one function, which hs.hotkey.modal:bind takes as
  pressedfn and nothing else — so one keypress was one nudge forever,
  and the 1-point fine nudge meant forty taps to cross an icon. Passing
  the same function as both pressedfn and repeatfn is the fix, and it is
  not a new idea here: init.lua's popup nudge keys (bindNudge, §1.5)
  have done exactly this since they were written, with a comment
  explaining that a tap nudges once and a hold repeats at the OS rate.
  The mouse grid simply never got it.

  🚨 THE ARGUMENT LIST IS LOAD-BEARING: (mods, key, fn, nil, fn).
  modal:bind's signature is (mods, key, message, pressedfn, releasedfn,
  repeatfn) and it only shifts those along when the third argument is a
  function — so the natural-looking bind(mods, key, fn, fn) lands the
  second fn in RELEASEDFN, which fires the nudge again when you let go
  and still never repeats. There is a check for that specific mistake,
  because it presents as "the pointer overshoots by one step" rather
  than as a repeat bug. Clicks are asserted NOT to repeat: a held space
  turning into a click storm on whatever you just landed on would be a
  worse bug than the one being fixed.

  WHY NO SUITE CAUGHT IT: the modal stub recorded bindings as
  bind(mods, key, fn) and swallowed every argument after the third. "All
  four arrows nudge, coarse and fine" passed for releases while holding
  an arrow did nothing, because the stub could not see the slot the
  difference lives in.

  ✍️ ⇪⇧O EDITS IN A WINDOW, NOT AN ALERT.
  LL: "Edit OCR is too small — give me a window like notepad", with a
  screenshot of one line of "All Snippets" in a box that could not show
  the rest. And separately: "it doesn't come to the front for an
  immediately editable window, I have to click on it."

  It was hs.dialog.textPrompt — a fixed-size NSAlert wrapped around a
  ONE-LINE NSTextField. It cannot be resized, it cannot scroll, and
  Return presses the default button instead of inserting a newline,
  while the thing being edited is OCR output, which is multi-line by
  definition. A page of scanned text went into a control that could show
  about 25 characters of it. win_pin hit exactly this in 6.112.0 and got
  the Capture Pad's window; this is that window, sized for a page:
  760×520, sixteen rows, monospace, a character and line count, ⌘⏎ to
  save, Esc to cancel, draggable by its header, and listed for ⇪⇧W like
  every other panel.

  🎯 IT TAKES FOCUS ON OPEN — allowTextEntry(true) plus bringToFront,
  the same pair the Quick Append Pad uses. That is the "I have to click
  on it" report, and it is two calls. It activates deliberately, unlike
  Window Pin's editor, which must not pull Hammerspoon forward because
  it hides its note when the app loses focus; this box has no such rule
  and one job.

  THERE IS A DELETE BUTTON NOW. "Save it empty to delete this entry" is
  a fine rule and a terrible thing to have to discover from a sentence
  you did not read. Emptying the box still deletes — the rule did not
  change, it just stopped being the only way.

  🚨 AND ⇪⇧O NOW CLOSES AN OPEN EDITOR FIRST, which the modal alert
  never needed to. ocr.edit() re-reads the CSV into a fresh snapshot,
  and a box left open from a previous press still holds an INDEX into
  the old one — saving it would overwrite whichever entry now happens to
  sit at that position. Reachable simply by pressing ⇪⇧O twice.

  A Mac without hs.webview still gets the small prompt, pre-filled, with
  the same delete-on-empty rule: the managed work Mac is where webview
  is most likely to be missing, and a rewrite that turned ⇪⇧O into a
  dead key there would be a worse outcome than the small box ever was.
  The fallback is tested as hard as the window.

  📦 AND THE ZIP STOPPED FAILING ITS OWN TEST SUITE.
  Found by running the suite against the UNZIPPED tree rather than the
  repo, as part of verifying this release — which is the only place it
  shows, and is why it survived from 6.105.0 to here.

  The release deliberately packages snippets/bundled.lua and leaves the
  source packs out, because textpanders holds real email addresses, a
  phone number and an employee ID. So in the shipped tree snippets/
  EXISTS but has no packs in it: the drift sentry generated an empty
  table from nothing, compared it to the real one, and reported
  "❌ snippets/bundled.lua is STALE". The builder's skip branch only ever
  covered a snippets/ directory that was MISSING ENTIRELY, which is the
  fresh-clone case, not the shipped-zip case.

  The symptom is the worst possible one for a release: run-tests.sh on a
  correct install tree printing "❌ 1 stage(s) failed. Do not ship this."

  ⚖️ THE FIX DOES NOT WEAKEN THE SENTRY, and there is a test that says
  so. With no packs on disk there is nothing to have drifted FROM, so
  --check reports a skip and says in words that it could not check. On
  any machine that HAS the packs — the only place a pack can actually be
  edited, and therefore the only place drift can happen — it still
  compares byte for byte. Asked to BUILD from nothing it is still a hard
  error: a skip is about having nothing to compare, not permission to
  write an empty table over a good one.

  ── WHAT BREAKS IF YOU UNDO ANY OF IT ──────────────────────────────
  the fix removed                            the check that fails
  ──────────────────────────────────────────────────────────────────
  arrows bound with one fn again             every arrow REPEATS while held
  bind(mods, key, fn, fn) instead            no arrow fires on RELEASE
  repeat swept onto clicks too               clicks do NOT repeat
  adoptLegacyFile leaves the original        an ALREADY-ADOPTED machine
                                             still gets its twin renamed
  .superseded not read as a source           a RETIRED file is still a
                                             valid adoption source
  retire before the read-back                the copy is read back and
                                             compared BEFORE retiring
  migration parses the DD/MM/YY text         a row whose old text says
                                             1999 migrates to its EPOCH
  layout decided once from the header        the old row beneath it is
                                             converted, not mis-read
  ⇪space keeps the old column indices        an OLD-layout row in the
                                             SAME file is read correctly
  no bringToFront on the OCR editor          it comes to the FRONT on open
  no allowTextEntry                          the box takes keystrokes
  ⇪⇧O leaves the old editor open             pressing ⇪⇧O again CLOSES it
  editor text not HTML-escaped               the text is HTML-ESCAPED
  --check with no packs fails again          the table WITHOUT its packs
                                             is a skip, not a failure
  the skip swallows real drift too           a pack edited after the
                                             build still reports STALE
  ──────────────────────────────────────────────────────────────────

  Counts: test_mouse_grid 290 → 296 · test_ocr_tag 21 → 51 ·
  test_integration 147 → 160 · test_unified 81 → 85 · test_expander
  208 → 215 · a new test_file_tracker at 35. 46 → 47 stages. Hostile:
  46 modules, 0 that did not degrade. Lint: 0 error, 1 pre-existing
  warning.

NEW IN 6.114.0 — EVERY SHORTCUT WORKS WITH NO EXTERNAL KEYBOARD, AND
FOUR THINGS THAT WERE ALREADY WRONG:
  LL: "Sometimes I will not have an external keyboard on my work
  MacBook, well and my home, and sometimes I will not. How do I handle
  shortcut keys when I don't have an external keyboard?"

  ⇪ ITSELF WAS NEVER THE PROBLEM. Caps Lock is on every MacBook and the
  hidutil remap that turns it into F18 is per-USER, not per-device, so
  the hyper key works on a bare laptop exactly as it does docked. (It is
  re-applied at every Hammerspoon launch because a reboot wipes it, and
  it can need elevated rights on Sonoma and later — the 🎹 line in the
  boot report says which.) The number pad was the problem.

  TAKING INVENTORY MADE THE FIX SMALL. Most of the pad already had a
  laptop route and had had one for versions:
        ⇪pad1 ≈ ⇪J        ⇪pad3 ≈ ⇪⇧J       ⇪pad4 ≈ ⇪\
        ⇪⇧pad4/6 ≈ ⇪←/⇪→  ⇪⇧pad0 ≈ ⇪↑       ⇪⇧pad. ≈ ⇪↓
        ⇪⇧pad/ ≈ ⇪[       ⇪⇧pad* ≈ ⇪]
  What had NO route at all was the Quick Append Pad — note_pad.lua binds
  no letter, so ⇪pad2, ⇪pad* and ⇪pad- were its only doors — and nine
  window placements: the four quarters, top and bottom half, centre 70%,
  centre-without-resizing, grow and shrink. So on a MacBook with nothing
  plugged in, the most-used capture window in the config could not be
  opened, and a documented chunk of the window map simply was not there.
  Nothing on screen said so. "The bindings sit there doing nothing and
  are still correct when you plug the pad back in" is true, and it is
  not an answer.

  💻 ⇪⇧ + THE NUMBER ROW — THE SAME NINE ZONES, ONE ROW UP. ⇪⇧7 does what
     ⇪⇧pad7 does. It is not a copy: both layers hand the same string to
     numpad.run() over the same numpad.zones, so there is one definition
     of "top-left quarter" and the two cannot drift. A test asserts them
     digit for digit, because a table that LOOKS like a mirror is not a
     mirror and the drift would be silent — the window would just land
     somewhere else.
       · The mnemonic is honestly weaker and the file says so. The pad's
         3×3 block IS the screen; a row is a straight line. What survives
         is the digit, and that is the only claim being made.
       · 4, 6 and 0 ARE DELIBERATELY ABSENT, each because the zone
         already has a better laptop key: ⇪← ⇪→ ⇪↑. Completing the
         pattern would have meant taking ⇪⇧4 off the Screenshots panel
         to duplicate a key that works everywhere already.
       · ⇪⇧, shrinks and ⇪⇧. grows (think < and >), and ⇪⇧⏎ centres
         without resizing — the same key as ⇪⇧padenter, one keyboard
         over.
       · AUTO-DETECTING THE KEYBOARD AND SWAPPING LAYERS WAS CONSIDERED
         AND REJECTED. hs.usb.watcher could do it. A config where one key
         does different things depending on what is plugged in is a
         config you hesitate before pressing, which is worse than a
         missing key. Both layers are always live.

  💻 ⇪2 OPENS THE QUICK APPEND PAD. A digit and not a letter because
     there is no free ⇪ letter left — all twenty-six are claimed on the
     plain layer, and ⇪⇧ has only F and Z, neither of which says "note
     pad" to anyone. 2 is not an arbitrary free key: it is THE SAME DIGIT
     as ⇪pad2, which makes it one fact to remember instead of two. The
     claim stops there — this is not "the number row mirrors the pad
     row", which would break at ⇪4 (Screenshots).

  💻 THE SIX ⇪pad TOOLS ARE RUNNABLE FROM ⇪space NOW. They were already
     LISTED there — the tool source lists every cheat sheet row — and ⏎
     on one copied the key string instead of running it, because
     uni.runnable had no entry for it. So ⇪space showed a MacBook user a
     tool they could see, name, and not use. The actions were already
     published service names; this was six lines of join.

  🚨 AND THE NEW SENTRY CAUGHT THE FIRST DRAFT OF THIS VERY LAYER. ⇪⇧1–9
     LOOKED free — a grep for shifted digits finds mini_calendar's ⇪⇧0
     and nothing else, because screenshots.lua spells its key
     `shots.key = "4"` and the grep never saw it. The suite named it on
     the first run: "⇪⇧4 (numpad row 4 vs screenshot panel)". That is the
     whole argument for a sentry over a careful read — the careful read
     had already happened.

  ---------------------------------------------------------------------
  AND FOUR THINGS THAT WERE ALREADY WRONG, found while auditing the
  keyboard for the above. None of them was reported; all of them were
  reachable by hand.

  🚨 ⏎ ON "RESET NUDGE OFFSET" IN ⇪space RAN A BULK RENAME UNDO — which
     MOVES FILES ON DISK. uni.runnable had ["⇪⇧R"] = "rename.undo", and
     the tool list attaches a service to a row BY ITS KEY CELL. The only
     row whose key cell says ⇪⇧R is the popup nudge reset (§0.4 maps
     ⌥⌘⌃R onto it). Both existing checks passed: verifyTools confirms the
     service exists and confirms the key matches a live row, and it did
     both — while joining two different features. The entry is gone, and
     _G.service.owner now records which module published each service so
     a test can ask the question nothing could ask before.

  🚨 BULK RENAME TOLD YOU TO PRESS A KEY IT DOES NOT OWN, in four places
     including `hs.alert.show(msg .. "\n⇪⇧R to undo")` — the alert that
     fires the instant files have moved, when you most need the way back.
     ⇪⇧R is the nudge reset. The module's own wiring note has said so,
     correctly, since it was written ("🚨 NO ⇪⇧R BINDING"); the code
     refused to claim a key it did not own while the prose told you to
     press it. The undo route is unchanged and always was: the FIRST ROW
     of ⇪R, offered whenever there is a batch to undo.

  🚨 FOUR SHORTCUTS WERE ON THE CHEAT SHEET TWICE. ⇪O and ⇪⇧O were left
     in core/cheatsheet.lua's hand-written CLIPBOARD & OCR group when the
     OCR engine became a module in 6.105.0 and brought its own group;
     ⇪T and ⇪⇧S were left in the ASANA group when the task form did the
     same. Six more were duplicated across two SPELLINGS — "⇪ pad1" in
     the numpad layer, "⇪pad1" in quick_append — which is worse than
     cosmetic, since a run map can only point at one spelling. The
     identical complaint was raised by hand from a screenshot in 6.90.1
     about ⇪V, fixed by hand, and written up in a comment asking that it
     not happen again. It happened four more times. There is a sentry now
     and it reads BOTH sources — the module groups and the hand-written
     ones — which is why it saw what four years of per-module suites
     could not: no single suite had ever looked at both halves of the
     sheet at once.

  🔗 ⇪↓ COULD NOT PUT BACK A WINDOW THE PAD HAD MOVED. numpad_layer kept
     its own prior-frame table and window_arranger kept another, so
     placing a window with ⇪⇧pad7 and then pressing ⇪↓ answered "No prior
     position remembered for this window" — about a window it had just
     watched move. One memory now: the pad and laptop layers write
     through windows.rememberFrame, and both restore keys read the same
     table. It is also BOUNDED for the first time; numpad's private table
     was capped at 40 with a comment calling an uncapped one "a slow leak
     that nothing ever notices, which is the worst kind", while the
     shared table it should have been using had no cap at all.

  TEST EVIDENCE. Nine new guards, each confirmed FAILING against a
  deliberately broken variant before being kept:
      · run map pointed back at ⇪⇧R          → the ownership check names it
      · a duplicated ⇪O row put back         → 2 failures, dupe + ambiguity
      · service owner tracking removed       → "mouseGrid.show = init.lua"
      · ⇪⇧4 put back in the laptop layer     → the ⇪ collision sentry
      · ⇪2 binding removed                   → 2 failures in test_note_pad
      · laptop 2 changed to topHalf          → the mirror check
      · the shared-memory write-through cut  → the ⇪↓ link check
      · windows.rememberFrame unpublished    → the cross-module link check
  Counts: test_features 404 → 411, test_integration 138 → 147,
  test_note_pad 54 → 56, test_modules unchanged at 118.
  46 stages green · hostile 46 modules, 0 that did not degrade ·
  lint 0 error, 1 pre-existing warning, 3 note.

NEW IN 6.113.0 — A PINNED NOTE CAN MOVE TO ANOTHER WINDOW:
  LL, reviewing 6.112.0 on the work MacBook: "Long note work. But can I
  move and pin it if I need to set it to another window?"

  THE ANSWER WAS NO, AND THE MODULE LOOKED LIKE IT SAID YES. _G.pins()
  printed "_G.winPin.rebind()   move a stranded note onto this window",
  which reads like the call for exactly this. It was not. rebind()
  worked off wp.classify(), and classify only ever returned notes whose
  window NO LONGER RESOLVED — dead (the app exited) or stale (the app is
  alive, the window is not there). A note on a window you can see was in
  neither list, so rebind(id) answered "id N is not a movable note" and
  the only way to move a note was to open it, copy the text, empty the
  box to remove it, focus the other window and paste it back.

  🧭 YOU NOW DRIVE FROM THE DESTINATION. Focus the window you WANT the
  note on, press ⇪⇧U, and the editor lists every other note as a button:
  app name, a snippet of the text, and a chip if its window is stale or
  dead. Click one and it moves. That direction is the whole design —
  the hard half of "move X to Y" is naming Y, and Y is the window you
  are looking at, so this needs no window picker and cannot pick wrong.
  The list is capped at wp.moveRows (8) with "+N more — _G.pins()", so a
  Mac with twenty notes does not get a wall of buttons in a box it is
  trying to let you type in.

  Moving onto a window that already has a note REPLACES it, and the
  heading says so before you click ("Move a note here — replaces the
  note above") rather than after.

  🚨 AND THE MOVE PUTS THE NOTE BACK IF IT CANNOT FINISH. This is the
  part worth reading. The old rebind did:
        wp.remove(src.id, true)
        return wp.set(text)
  — remove first, then re-pin. If wp.set refused (the destination went
  away between those two lines, or it had no id) the text was gone, and
  nothing anywhere else in the module could recover it. Notes are typed
  by a person and there is no undo for them. wp.moveTo() now restores
  the source note, canvas and all, and returns "the move did not happen
  (...) — the note is still on window N". A test moves a note to id 4242
  and asserts the text is still where it started; with the restore
  removed that check reports "got: LOST".

  ONE MOVER, THREE DOORS. wp.moveTo(from, to) is the only thing that
  moves a note; the editor's buttons, rebind(id) and a Console call all
  go through it, so there is one answer to what moving means rather than
  three that can drift. rebind() keeps its name and its no-argument
  behaviour (it still only auto-picks when there is exactly one note and
  it is certainly dead) and now accepts live ids. wp.classify() is
  derived from the new wp.movable() rather than walking wp.pins a second
  time — two copies of the dead/stale rule is how they end up
  disagreeing about what stale means.

  What comes back from the page is not trusted: the id is tonumber'd, so
  "902" works (a WKWebView hands back JSON) and anything that is not a
  number moves nothing.

  🗂 CLIPBOARD HISTORY MOVES FROM ✂️ TEXT TO 🗒 CAPTURE, on request. The
  families are about what a tool is FOR, not what it operates on, and a
  store that catches everything you copy so you can go back for it is
  the same shape as the Capture Pad and Quick Append. "text" keeps the
  things that TRANSFORM text — Text Expander, Autocorrect, Begone, OCR,
  URL Cleaner. Nothing followed it automatically: ⇪H (Command History)
  reads a shell's history file rather than catching anything and was
  already under FIND & OPEN, and the hand-written CLIPBOARD & OCR group
  is ⇪O/⇪⇧O/⇪⇧C, which is OCR and copy-on-select. No key, binding or
  behaviour changed — this is the position of one card on one panel, and
  it is now asserted in test_clipboard.lua so a later edit cannot revert
  it quietly.

  TESTS: test_win_pin 91 → 119, test_clipboard 57 → 58. Every new guard
  was confirmed FAILING against a broken variant before being kept —
  restore removed → the note reads LOST; rebind restricted to non-live
  notes again → three checks; the move list withheld → seven; the
  moveRows cap removed → two; the tonumber dropped → two; the self-move
  refusal removed → one. Two of the new checks were rewritten after
  first being written badly: one crashed the run instead of naming the
  guard that caught it (it indexed a note the breakage had deleted), and
  one passed under every variant because a non-numeric id and a missing
  note produce the same refusal — it now asserts the whole pin table is
  unchanged, and that a numeric STRING id still works.

NEW IN 6.112.0 — ⇪⇧U GETS A REAL BOX, AND ITS NOTES STOP VANISHING:
  LL, with two screenshots of the pin prompt showing the same ~25
  visible characters scrolling out of a one-line field: "That note
  window is tiny. And after I added one it's either not working or the
  window is there I can't see it. Also that box is way too small."

  Two separate faults. The one that was NOT reported as the main
  complaint is the serious one.

  📐 FAULT ONE — THE NOTE WAS BEING DRAWN OFF THE SCREEN.
  buildCanvas sized the canvas to whatever ONE UNWRAPPED LINE of the
  text measured, so its width grew without limit as the note got
  longer. With the default topRight anchor the note's x is
      winFrame.x + winFrame.w - noteWidth - offsetX
  so once the note is wider than its window that goes NEGATIVE, and a
  window near the left of the display puts the note off the edge of it.
  Measured against the shipped file with Menlo's real metrics
  (0.602 em advance at 13pt), on an 800pt window at x=100:

      chars   note w   note x    on screen?
      20      176      712       ok
      60      488      400       ok
      100     800      88        ok
      200     1580     -692      OFF — runs off the LEFT edge
      400     3140     -2252     OFF — runs off the LEFT edge

  So the note was pinned, saved, followed, and invisible — which is
  exactly "it's either not working or I can't see it". wp.maxChars = 400
  did not save it, and the comment on that line — "a longer note is
  refused rather than drawn off-screen" — was the opposite of true: 400
  characters is 3,140pt, off-screen on every display ever sold.
  Notes now WRAP at wp.maxWidth (360pt): the newlines you typed are
  kept, a word too long to fit is broken rather than allowed to widen
  the note, and the width is hard-capped afterwards in case a
  proportional font or a measurement quirk gets past the wrap. The
  final frame is then clamped to a real screen. A note can now be badly
  placed. It can no longer be invisible.
  🚨 THE OLD TEST STUB RETURNED w = 120 FOR ANY TEXT, which is precisely
  why 64 green checks never caught this. The new one measures.

  ✍️ FAULT TWO — THE BOX WAS NEVER GOING TO BE BIG ENOUGH.
  It was hs.dialog.textPrompt: a fixed-size NSAlert around a ONE-LINE
  NSTextField. It cannot be resized, it cannot scroll, and it cannot
  accept a Return — Return presses the default button. The prompt's own
  message said "Newlines are fine", which you could not act on in that
  control at all. No amount of tuning fixes a box that is the wrong
  kind of box.
  ⇪⇧U now opens the Capture Pad's window instead:
    • multi-line, and MONOSPACE AT THE NOTE'S OWN WRAP WIDTH — what
      wraps in the box is what wraps on screen
    • a live character count against wp.maxChars, because the limit
      REFUSES the pin and finding that out from an alert after typing
      400 characters is the worst possible moment to learn it. Over the
      limit, the Pin button disables itself.
    • ⌘⏎ pins · Esc cancels · an explicit "Remove note" button, which
      the old flow could only express as "clear the box and press OK"
    • draggable by its header, opened OVER the window it belongs to
      (on three monitors, "where did the box go" is a real cost)
    • non-activating, and this one earns its keep: wp.isShowing() hides
      a note unless its app is frontmost, so an editor that dragged
      Hammerspoon forward would pin the note and then immediately hide
      it — the same "did that even work?" this version exists to fix.
      When macOS refuses the mask, the Console says so and says what it
      will look like.
  🚨 THE WINDOW IS CAPTURED WHEN YOU PRESS THE KEY, not when you save.
  The editor can take focus; clicking another window mid-edit must not
  move the note onto it.
  A Mac with no hs.webview still gets the small prompt. Same meaning —
  one function, wp.applyEdit, decides what a finished edit means, so the
  two boxes cannot drift into disagreeing about it.

  THE TESTS (27 new, test_win_pin 64 → 91). Section 6 now explicitly
  covers the no-webview fallback, and it passes UNCHANGED — which is the
  evidence that the old contract survived the rewrite. Each new guard
  was broken separately to prove it bites:
    • no wrapping + no width cap → "a 400-character note is at most
      maxWidth wide" fails, as does "it got TALLER instead"
    • no screen clamp → "a note too wide for its window is clamped ONTO
      the screen" fails
    • pin to whatever is focused at SAVE time → "clicking another window
      mid-edit does NOT move the note onto it" fails
    • no HTML escaping → "a note containing HTML is escaped into the
      box, not executed" fails (a note is arbitrary text a person typed,
      and it goes into a WebKit page)

NEW IN 6.111.0 — ⇪/ REOPENS WHERE YOU WERE READING:
  LL: "The cheat sheet still isn't remembering where I am when I close
  it. How can we fix this?"

  WHICH "WHERE" — MEASURED, NOT GUESSED. Three things that sentence
  could have meant, each checked against the shipped file by driving it
  with the test suite's stubs before writing a line:
      panel position across a close ....... ✅ worked (reopened at 111,222)
      scroll position across a close ...... ❌ row 20 → back to row 1
      the search filter you had typed ..... ❌ cleared, deliberately
  So the panel half (6.67.0 for a close, 6.106.0 for a reload) was
  already doing its job, and the thing actually being lost was the ROW.
  hide() set _G.cheatSheetState = nil and show() started at keepFirst =
  1, so a 300-row sheet you had walked halfway down began again from the
  top every single time you reopened it.

  THE FIX IS A THREE-WAY DISTINCTION, and that is the whole subtlety.
  show()'s preserveScroll argument had two meaningful states and needed
  three:
      show(true)  — an in-place redraw (an entry added, edited, deleted).
                    Keep the CURRENT row; the list barely changed.
      show(false) — a FILTER keystroke. Go to the top, deliberately: you
                    are looking at a different, shorter list, and row 40
                    of the old one is blank space that reads as "the
                    search found nothing".
      show(nil)   — a fresh ⇪/. Reopen where you last closed it.
  🚨 nil and false used to behave identically, which is precisely why
  this could not be written as `or cheatSheet.scroll`: the filter path
  passes false and must never get the remembered row back.

  TWO GUARDS THAT MATTER MORE THAN THE FEATURE:
    • CLOSING WHILE FILTERED DOES NOT STORE THE FILTERED ROW. Row 12 of
      "what matched win" is not row 12 of the sheet, and storing it
      would reopen you somewhere you had never been. The row from before
      you searched is kept instead — which is where you were reading.
    • A REMEMBERED ROW OUTLIVES THE LIST IT CAME FROM. It is clamped to
      the current last-full-view on the way back in, so a sheet that got
      shorter reopens on real content rather than on blank space.

  SESSION-SCOPED ON PURPOSE — the one place this differs from the panel
  position, which does persist to hs.settings. A position is a pair of
  screen coordinates and means the same thing tomorrow. A scroll row is
  an INDEX INTO A LIST rebuilt from the modules at every boot: a module
  that fails to load, a custom entry, a new family, and row 40 is
  somewhere else entirely. Restoring a stale index would put you
  confidently in the wrong place, which is worse than the top.
  cheatSheet.rememberScroll = false returns to always-from-the-top.

  THE TESTS (8 new, test_cheatsheet 168 → 176). Each confirmed failing
  against the old behaviour first, and each half of the change was
  broken separately to prove the guards are independent: removing the
  restore fails "reopening puts you back where you were reading" (1 vs
  12 — the reported bug exactly), removing the capture fails it at "nil
  vs 12", and dropping just the unfiltered-list condition fails "closing
  while FILTERED does not store a filtered row". One existing check,
  "⇪/ opens at the top", was rewritten rather than deleted: it stated a
  contract that no longer holds and would have gone on passing by
  accident whenever the remembered row happened to be nil.

NEW IN 6.110.0 — DOC KEYWORDS STOPS SHOUTING:
  The other half of the log that produced 6.109.0. LL: "Fix the Docs
  Keywords."

  WHAT THE LOG SHOWED. Between 04:58 and 05:13 the Console carried
  several hundred lines of:
      🏷 Doc Keywords → <file>.docx — <eight words>
  and the four LuaSkin errors that turned out to be a real bug sat in
  the middle of them, unread. That is a first OneDrive sync being
  tagged, and it is working as designed — which was the problem. The
  design was wrong in two ways at once.

  ONE: A SYNC WAS TREATED LIKE A SAVE. dk.flush() walked every settled
  path and called dk.process on each one immediately. Three hundred
  settled files started three hundred unzip child processes in the same
  tick, and every one that succeeded started an osascript on top of it.
  Nothing bounded it. On a work Mac with other work to do that is a
  process storm caused by a background nicety.
  A settled batch is a RUN now. Paths go into a FIFO queue and
  dk.maxInFlight (3) are read at a time; a slot frees when a file's
  Finder comment is written, not when its text is read, so one file is
  one slot end to end. A thousand-file sync now costs TIME. Nothing is
  dropped to achieve that — the queue drains completely.

  TWO: EVERY FILE NARRATED ITSELF. One line per file is right when you
  saved one document and want to see its keywords. It is wrong three
  hundred times, because a Console full of routine success is a Console
  where errors are invisible — demonstrably so, since that is exactly
  what happened to the LuaSkin errors.
  A run bigger than dk.chatty (3) now reports a total when it finishes:
      🏷 Doc Keywords: 312 tagged, 4 left alone (your comment) in 41s
        — _G.docKeywordsReport() names them
  Below that threshold every file still names itself, unchanged.

  WHAT IS DELIBERATELY NOT QUIETER:
    • _G.tagDoc("/path") always names ITS file, even while a quiet run
      is going on around it. You asked by name, you get answered by
      name.
    • The session log records every file either way, and now keeps 200
      of them rather than 40, so a big run is still fully inspectable
      after the fact.
    • _G.docKeywordsReport() adds a live line mid-run ("42 of 312 done ·
      3 reading · 267 queued") so a quiet Console never reads as a
      stalled one.
    • A Mac with no Automation permission used to print one ⚠️ per file
      — the loudest possible way to say ONE thing. A run where every
      write is refused now says it once and names the fix.

  A run stays open across waves. A first sync does not arrive at once,
  it dribbles in over minutes, so the run closes only after the queue
  has been empty for a settle (dk.quietSecs). Thirty waves are one run
  and one summary, not thirty summaries — the same flood with extra
  steps.

  THE TESTS (17 new, test_doc_keywords 46 → 63). A throttle nobody has
  watched throttle is a guess, so each was confirmed failing against
  the old behaviour before being kept: raising dk.maxInFlight to 9999
  fails "only maxInFlight files are read at once" (25 reading, 0
  queued), and raising dk.chatty to 9999 fails seven checks including
  "not one per-file line for 25 files" and "a Mac that refuses every
  write says so ONCE" — both reproducing LL's log exactly. The run also
  proves the cap held at every step, that all 25 files were read AND
  written, and that the session log kept all 25 while the Console
  showed none.

NEW IN 6.109.0 — ⇪⇧T GETS ITS ROWS BACK:
  LL sent a Console log. Buried in a wall of Doc Keywords lines were
  four LuaSkin errors:
      LuaSkin: dictionary key (fn) cannot be converted into a proper NSObject
      LuaSkin: dictionary key (snip) cannot be converted into a proper NSObject
      LuaSkin: array element (table: 0x…) cannot be converted into a proper NSObject
      LuaSkin: hs.chooser:choices() table could not be parsed correctly.
  Those are real, and they are old. A chooser row is handed across to
  Objective-C, so every value in it has to be convertible — a string, a
  number, a boolean. exp.show() was putting the snippet TABLE in the row
  (.snip), and on an action snippet that table holds a FUNCTION (.fn).
  Neither survives the bridge. LuaSkin threw out the key, then the row,
  then the whole list, and the panel never got its rows.

  🚨 The reason it went unnoticed: LuaSkin LOGS this, it does not raise.
  The pcall wrapped around :choices() had nothing to catch, :show() ran
  regardless, and the only evidence was four lines in a Console nobody
  reads during a working day. Introduced in 6.68.0.

  The fix is small: the snippet stays in a Lua table inside show(), and
  the row carries a plain integer index into it. The callback resolves
  the index instead of unpacking the row. .trigger stays exactly as it
  was — a string was never the problem.

  Two tests were added. One walks every row ⇪⇧T emits and fails on any
  value that is not a string, number or boolean. The other checks the
  index still resolves. Both were confirmed to FAIL against the old
  code before the fix went in — a guard nobody has watched fail is a
  guard you are only guessing about.

NEW IN 6.108.0 — BEGONE IS FILED UNDER TEXT:
  LL flagged the placement: Begone sat in ⏱ TIME & ATTENTION. That band
  was defensible — Begone kills the things that interrupt the day — but
  a family is where the HAND goes looking, not where the taxonomy is
  cleverest, and the hand goes looking for a typed keyword next to the
  other typed things. It now sits in ✂️ TEXT & CLIPBOARD, directly under
  the Text Expander (13.58 → 13.59), the module whose machinery fires
  it and swallows the word.
  One word changed in modules/begone.lua. No key, no binding, no
  behaviour — the position of one card on one panel.

NEW IN 6.107.0 — ⇪space STAYS WHERE YOU PUT IT TOO:
  LL: "yes do hyperkey+space too". The other half of 6.106.0, and the
  same gap: modules/unified_search.lua has reopened the panel where you
  dragged it since 6.93.0, but the position lived on the module's own
  table, and that table is rebuilt on every reload. Within a session it
  remembered; across a reload it centred.
  One hs.settings key now, "unifiedSearch.pos", validated on the way back
  in exactly as the cheat sheet's is — two finite numbers or it is not a
  position, so a string, a nil, a NaN or an infinity from the plist reads
  as "no stored position" rather than as coordinates. The existing
  posStillOnScreen guard still runs on top, so a position from a monitor
  you have since unplugged re-centres instead of opening somewhere you
  cannot see.

  🚨 THE WRITE IS DEBOUNCED, and that is the one real difference from the
  cheat sheet. The sheet saves from an onDrop callback that fires once.
  This panel has no drop callback: window_move's beginDrag calls move()
  from a repeating timer for the WHOLE drag, so a save inside move()
  would hit the settings plist tens of times a second for as long as the
  mouse button is down. uni.pos still updates on every tick — the panel
  tracks the pointer exactly as before — and only the WRITE waits
  uni.posSaveDelay (0.4s) for you to settle. If no timer is available at
  all (a harness, a stripped build) it writes immediately instead:
  debouncing is an optimisation, not a rule, and losing the position is
  worse than writing twice.

  _G.unifiedCenter() re-centres and forgets the stored value.
  uni.rememberPos = false restores always-centred.

NEW IN 6.106.0 — THE SHEET STAYS WHERE YOU PUT IT, AND ⇪Y CAN BE ASKED
WHAT IS WRONG:
  Two questions from LL, answered in code.

  🖐 THE CHEAT SHEET REMEMBERS ITS POSITION ACROSS RELOADS —
  core/cheatsheet.lua. "Can we make the cheat sheet remember where it was
  before it was closed?" It already did, within a session: 6.67.0 made it
  draggable and the position lives on the namespace table, so it survived
  a redraw (the panel is rebuilt on every character you type into the
  search box) and a reopen. What it did not survive was a RELOAD, which
  rebuilds that table — so every reload put the sheet back in the middle
  of the screen and you moved it again.
  It is one hs.settings key now, "cheatSheet.pos", written when you drop
  the panel and read back at load.
  VALIDATED ON THE WAY IN, the rule win_pin's notes already follow.
  hs.settings is a plist on disk: it can be hand-edited, written by an
  older or newer build, and can hand back a string, a nil or a NaN. A
  position is two finite numbers or it is not a position — and a NaN
  reaching the canvas draws the sheet nowhere at all, with no way back
  except editing settings. Junk reads as "no stored position" and the
  sheet centres.
  STILL CLAMPED. A remembered position outlives the display it was set
  on; the existing clamp now runs on the value that came off disk, not
  only on a live drag.
  _G.cheatSheetCenter() re-centres it AND forgets the stored value — the
  way out when a position is wrong in a way clamping cannot fix, and the
  sheet redraws immediately rather than promising to next time.
  cheatSheet.rememberPos = false restores always-centred.
  (The old comment claimed "Reset with ⇪R". There was no such binding —
  it was stale. The sheet's own HELP card now names the real one.)

  🕘 _G.chromeHistoryReport() ANSWERS "IS ⇪Y WORKING?" —
  modules/chrome_history.lua. LL: "Chrome fuzzy history might not be
  working, how can I tell?" The honest answer was that you could not, not
  from this report: it printed the status line and a per-profile table,
  which is useful once things work and says nothing when they do not. An
  empty list looked identical whether sqlite3 was missing, Chrome had
  never run as this user, Full Disk Access was off, or there genuinely
  was nothing in the ninety-day window — four different fixes behind one
  silence.
  Each is now its own line: sqlite3 present, Chrome's support folder
  present, how many History databases are readable RIGHT NOW (and their
  sizes), the CSV's size and age, and the export timings the cheat sheet
  has promised since 6.92.0 and never actually printed. It then runs a
  live search for a common substring, so the report covers the MATCHER
  and not merely that a file parsed.
  It ends in a verdict: "✅ WORKING" with the row count, or a numbered
  list of what to fix, each item carrying its own remedy. The Full Disk
  Access case is called out by name because it is both the likeliest and
  the least guessable — without it hs.fs.attributes answers nil for a
  file that is plainly there, and every symptom reads as "no history"
  rather than "not allowed to look".
  The whole report goes to the clipboard, so it can be pasted straight
  back.

  The cheat sheet card changed with it: "console — _G.chromeHistoryReport()
  — per profile, span, file, timings" became "not working? …", which is
  the question you would actually be asking when you go looking.

  Also corrected: text_expander's comment pointed at _G.snippets(), which
  does not exist. The command is _G.snippetsList().

NEW IN 6.105.0 — 700 KB OFF THE DOWNLOAD, THE ROOT FILE SHRINKS,
45 → 46 MODULES:
  Four items off the queue, in the order LL cleared them.

  📦 THE SHIPPED SNIPPETS BECOME ONE FILE — modules/text_expander.lua,
  tools/build-snippets.lua, snippets/bundled.lua. This came straight
  out of LL's question: "Can you compress zip file without breaking or
  have we moved what we can to .lua files we call?" The answer,
  measured rather than guessed: the compression was already maxed (-9
  is the highest deflate level and was already in use), so there was
  nothing left to turn up — but 714 KB of a 1.79 MB download was 2,006
  tiny Alfred JSONs whose FILENAMES cost more in the zip's central
  directory than their contents did. Folded into one generated Lua
  table they are 130 KB raw and 30 KB compressed. The whole zip drops
  from about 1.81 MB to about 1.11 MB.
  The bigger win is not the download. text_expander used to open and
  parse 2,006 files on every reload to build the trigger table; it
  opens one now.
  THE PACKS REMAIN THE SOURCE, and NEITHER goes into git. .gitignore
  has excluded snippets/ all along because textpanders holds real email
  addresses, phone numbers, an employee ID and out-of-office text — and
  bundled.lua is that same data in one file, so "it is only build
  output" is not a reason to commit it. Both live in the working tree
  and travel in the release zip; the builder runs before packaging.
  tests/test_expander.lua §17c re-runs the builder in --check mode and
  fails if the two have drifted, so a pack edited without a rebuild
  cannot ship quietly — and reports a SKIP where there are no packs to
  check against, because a fresh clone has none and must still go
  green.
  AND IT IS A PREFERENCE, NOT A REQUIREMENT. A syntax error, a file
  that throws, a table from a future version, no triggers table, all
  junk triggers, or no table at all — every one of those falls back to
  walking the .json files and prints why. The table is loaded with an
  EMPTY environment, so it is data that cannot reach hs, io or os even
  if something got into it. And when the table loads, the packs beside
  it are NOT scanned: unzipping over an older install leaves 2,006
  stale files there, and reading both would report every trigger as
  colliding with itself.
  Your own snippets are untouched. ~/.hammerspoon/Logs/snippets is
  still scanned as JSON and still wins on a collision, so Alfred
  exports keep dropping straight in.
  🚨 AND THE INSTALLER NEVER ACTUALLY COPIED snippets/ AT ALL. Four
  versions of "the zip carries the packs, unzipping IS the install"
  and hs-install.sh copied init.lua, core/, modules/ and tools/*.sh —
  never the snippets. Nobody noticed because the OneDrive folder had
  everything in it anyway. It copies them now, backs up the generated
  file, restores it on --rollback, and says how many stale .json files
  are still sitting there (it does not delete them: removing somebody's
  snippets folder to save 8 MB is not a trade a script gets to make).
  tools/*.lua travel too, which is what makes the next item work.

  🔍 THE OCR ENGINE LEFT init.lua — modules/ocr_engine.lua. 464 lines
  out of the root file: the "HS OCR" boot check, the QWERTY strip, the
  clipboard-image path, the whole file-tagging route (pasteboard
  shape-guessing, /.file/ reference resolution, the out-of-process
  Finder scripting) and both pickers. It was the last large feature
  still living ABOVE the module loader, where an error takes the entire
  config down instead of costing one feature — and it is the code that
  talks to Finder over Apple Events, which is the one thing here with a
  documented history of aborting the whole app (6.65.1).
  Nothing about the behaviour changed. ⇪O searches, ⇪⇧O edits, select
  mode still deletes several at once, and the globals other files read
  — _G.ocrShortcutAvailable, _G.choosers.ocr, _G.choosers.ocrEdit — are
  set under the same names. The two chord entries left _G.hyperKeyMap
  because the module claims ⇪O and ⇪⇧O directly, exactly as
  clipboard_history had to in 6.57.0.
  The clipboard watcher STAYED in init.lua, deliberately: one timer
  reads one pasteboard changeCount and chooses between copied image
  files, a raw image, and text, and clipboard history is the other half
  of that choice. It calls ocr.clipboardFiles / ocr.tagFiles / ocr.image
  through the registry, and a missing provider leaves the text path
  running.
  Two suites stopped doing string surgery on init.lua as a result.
  test_select_mode used to cut a do...end block out by marker comment
  and compile it with upvalues injected; test_ocr_tag did the same with
  a "return paths\nend" search. Both load the module now.

  📊 A DAILY ROLLUP AT 16:01 — modules/daily_rollup.lua. One card in
  the corner with the day on it: how long the Mac was in use and where,
  which documents you were actually in, and what you captured to the
  pad. It fades after 25 seconds; click it to dismiss it early.
  IT STORES NOTHING. No new file, not one byte written. Every number is
  read at the moment of drawing from a store another module already
  keeps — activity.dayTotals, activity.docs, notes.today. A rollup with
  its own daily totals would be a fourth thing that can disagree with
  the other three, which is what retired the Document Watcher in
  6.104.0.
  IT REPLACED A POPUP RATHER THAN ADDING ONE. The activity tracker
  opened a chooser at 16:00 and the Quick Append Pad opens its review
  at 16:01 — two panels a minute apart, both taking the keyboard, both
  arriving mid-sentence. The 16:00 chooser is now off (the flag is
  still in activity_tracker, and ⇪0 and the 🔧 rows still reach the full
  report). A canvas cannot take focus, so the card can appear while you
  are typing and the sentence keeps going where it was.
  AND IT STAYS AWAY ON AN EMPTY DAY. If every section is empty the
  timer draws nothing — a card that says "nothing to report" is one you
  learn to dismiss unread, and then you dismiss the one that mattered.
  On demand it always draws and says the day was quiet.
  A section whose store is MISSING says so rather than reporting zero.
  "You did no work today" and "the module that counts your work did not
  load" must never look the same.
  No key: every ⇪⇧ letter is taken. _G.rollup() from the Console, or
  the 📊 row in ⇪space's 🔧 tools.

  📧 THE OUTLOOK PROBE IS NO LONGER A MODULE — tools/outlook-probe.lua.
  It binds no key, watches nothing, and answered its question on the
  home Mac in 6.65.0, but it still loaded at every boot, held a module
  slot and printed itself onto the cheat sheet. It is a console tool
  now:
      dofile(hs.configdir .. "/tools/outlook-probe.lua")
  It was moved rather than deleted because the WORK Mac is a different
  Mac — a different Outlook build, possibly a different answer. The
  Health Monitor's cheat sheet card carries the one line that says it
  exists.

  SENTRIES AND COUNTS: 45 → 46 modules across all six places, the test
  runner gained test_rollup (forty-one Lua suites), hs-doctor dropped
  its outlook_probe marker, and INSTALL.md's OCR-shortcut check now
  reads the module instead of init.lua. init.lua: 3,592 → 3,128 lines.

NEW IN 6.104.0 — TWO TOOLS RETIRED, ONE ADDED, 46 → 45 MODULES:
  Three things from LL's redundancy review, shipped together:
  "WinPin: adapt it, on ⇪⇧U, the last free ⇪⇧ letter. Retire
  document_watcher, and merging ⇪space with ⇪⇧/."

  📌 WINDOW PIN — modules/win_pin.lua, ⇪⇧U, Windows family. A note
  stuck to ONE window: it follows that window as it moves, hides when
  the window is behind something else or its app is not frontmost, and
  comes back when it does. Terminal tabs each keep their own note,
  free, because apps like Ghostty and iTerm expose every tab as its
  own accessibility window with a stable id; Chrome and Safari do not,
  so those get one note per window — stated as the limit it is. One
  key, three outcomes, because there was no second key to spend: ⇪⇧U
  on an unpinned window prompts, on a pinned one edits, and clearing
  the box removes. _G.pins() prints the ledger and names the calls for
  moving, pruning and clearing notes.

  Adapted from Blackman99/WinPin.spoon (MIT, credited in the module
  header), with five changes coming in, each recorded there: (1) THE
  FOLLOW TIMER IS ADAPTIVE — the original polls window geometry every
  0.03s for as long as any note exists, 33 wake-ups a second forever
  including while every note is hidden; here it runs fast only while a
  note is ON SCREEN and drops to 0.5s otherwise. (2) Canvases go up
  through _G.showCanvasSafely, because this one shows inside a LOOP and
  one 6.56.0-style throw would abandon every note after it. (3) Colours
  come from ui_style. (4) Accessibility is a gate, not a crash. (5)
  hs.settings values are validated on the way back in.
  And one bug found by writing the tests: the original's
  `winId and hs.window.get(winId) or hs.window.focusedWindow()` reads
  as "that window, else the focused one" and actually means "that
  window, and if it has GONE, silently pin to whatever is in front" —
  which rebind() could have used to move a note onto the wrong window
  and report success. Asked for an id, this answers about that id.

  ⚰️ THE DOCUMENT WATCHER IS RETIRED into the Activity Tracker.
  Both polled the frontmost window every 5 seconds and both
  accumulated time from it — one into activity_history.csv keyed by
  app+title, one into doc_wather.csv keyed by a filename pulled out of
  that same title. Two timers, two CSVs, two sets of rounding, one
  signal, and no way to say which was right when they disagreed. The
  tracker survives because it stores strictly MORE: a window title
  contains the filename, a filename does not contain the title. So
  ⇪⇧W (the documents you worked in) and ⇪⇧E (edit or delete one) now
  live in activity_tracker.lua and are DERIVED from the sessions it
  already records — the two can no longer disagree because there is
  only one of them. Select mode is unchanged in both. What the merge
  costs, stated in the module and here: doc_wather.csv stops being
  written (it is still READ by ⇪space, so everything logged before the
  merge stays searchable, and it is not deleted); its rows do not
  migrate, because they are per-day totals and these are sessions, and
  adding them would double-count every day both modules ran; and
  deleting a document now removes its SESSIONS, so that time leaves
  the app totals too — the prompt says so before you confirm.

  🔧 THE TOOL PICKER IS RETIRED into Unified Search. ⇪⇧/ still works
  and now opens the ⇪space panel on "@tool ", exactly as ⇪⇧space opens
  it on "@shots". The tools are one more source in the one box, listed
  LAST so what you saved stays above what is always there, and typing
  "url" finds both the link cleaner and the URLs you copied. ⏎ on a 🔧
  row RUNS the tool — the one row kind whose Enter is not a copy — and
  a row with no runnable service copies its key instead. The run map
  and its two-sided verify (the service must exist AND the key must
  still appear on the cheat sheet) came across intact; its Lua-pattern
  hazard did not need to, because that panel filters in JavaScript with
  indexOf, literal by construction rather than by remembering a fourth
  argument.

  Counts moved 46 → 45 in all five sentries, plus three new hs-doctor
  markers. tests/test_win_pin.lua is new (64 checks); the Tool Picker's
  coverage moved into test_unified.lua §2b and the Document Watcher's
  into test_select_mode.lua §1, both pointed at the surviving code so a
  behaviour lost in either merge fails a test rather than a Monday.
  The suite is 39 Lua suites, 45 stages.
```

```text
NEW IN 6.103.0 — DOCK BACK IN, WINDOWS GO BACK:
  LL: "Windows scattering when I plug into the dock. Yup." The story
  behind this one: LL brought in two community Spoons to evaluate.
  WinPin (pin a note to a window) was judged worth adapting and is
  still on the backlog. SpaceSaver — 1,600 lines that save and restore
  macOS Spaces layouts per monitor configuration — was judged the
  right pain but the wrong tool for this config: because
  hs.spaces.moveWindowToSpace silently fails on macOS 15+, it moves
  windows by SYNTHESIZING REAL MOUSE DRAGS and cycling through every
  Space on capture, which fights Window Move's click tap and
  coexist.lua head-on, depends on an external yq binary against the
  work-Mac constraint, and none of it is testable in the stubbed
  suites. The 80% of the value is dock/undock recovery, and that
  needs none of the above.

  So: modules/window_return.lua (the 46th module, Windows family, no
  key). Every 30s it quietly remembers where your visible windows sit,
  filed under a SIGNATURE of the connected screens (sorted UUIDs) —
  the laptop alone is one setup, laptop+dock another, each with its
  own memory. When a monitor change settles into a setup it knows
  (the settle wait is SpaceSaver's hardest-won lesson, kept: monitors
  arrive one at a time, DisplayLink ones change resolution late, and
  restoring early gets undone), the scattered windows are put back —
  matched by window id first (ids outlive reloads and dock cycles;
  they die only with the app), then by exact bundle+title, each side
  consumed as it matches so two "Untitled" windows get one frame
  each. A frame whose center lands on no current screen is skipped,
  never flung; a window within 4px is left alone; an unmatched window
  is never guessed at. Snapshots pause while a change is in flight so
  a mid-transition mess is never saved over a good layout. Layouts
  persist in hs.settings. _G.windowsBack() is the by-hand version,
  and it answers honestly when there is nothing to do. Without
  Accessibility the module stands down and says so instead of polling
  windows it cannot move. Scope stated plainly: frames only, the
  visible Space only — hs.spaces is never touched.

  Also: INSTALL.md's Step 9 still promised "⇪⇧S workspaces", a
  feature that stopped existing when 6.86.0 gave ⇪⇧S to past-task
  search. The row now tells the truth, and Step 9 gained the
  unplug/replug check.

NEW IN 6.102.0 — PICKERS DRAG BY THEIR SEARCH BAND:
  LL, with a screenshot of the Activity Report: "I can't move gray
  window and you say I could move them all." The gray windows are the
  hs.chooser pickers, and since 6.89.0 they moved only with ⌘ held —
  but LL's original spec was "click and hold then move the mouse
  cursor", no modifier. The pickers now follow the same header rule
  the Capture Pad and the editor shipped with: the SEARCH BAND across
  the top drags with a bare click-hold (the band is the one strip of
  a picker where a bare click did nothing you will miss — the rows
  below still mean "pick this one", so they keep needing ⌘). Where
  you drop it is committed to the shared popup offset, exactly like a
  ⌘ drag: the next picker opens there. The accepted cost, stated
  honestly: the mouse no longer places the text caret in the query
  field — type, ⌫, or ⌘A there instead. A ⌘-click the module DECLINES
  (outside its computed box) now records where it thought the picker
  was to the ⇪⇧D trail, so the next "I can't move it" report comes
  with evidence.

  Two housekeeping fixes riding along. The Quick Append Pad's Esc row:
  every boot printed "'notepad' is not in _G.escapePriorities — using
  50", which ranked the pad BELOW Unified Search, so one Esc with both
  open closed the search page first. It now sits at 73, between the
  Capture Pad (72, its template) and the Task Form (75); closing the
  pad is always safe because CLOSING FILES EVERYTHING. And one owner
  per ⇪ key on the cheat sheet: ⇪W rendered under both Find & Open
  (App Launcher's neighbour-key hint) and Windows & Pointer (Window
  Arranger, its real owner) — with the sheet grouped by family the
  same key read as two different tools. Cross-reference rows now say
  "vs ⇪W" / "via ⇪⇧T" / "in ⇪D" instead of claiming the key, and a
  disk audit in test_diagnostics holds the rule: a single-letter ⇪ or
  ⇪⇧ key may appear in exactly one module's key column.

NEW IN 6.101.0 — THE CHEAT SHEET BECOMES A MAP:
  LL: "Can we combine certain single tools of similar types? Examples:
  anything that moves or changes or adjusts application windows, mouse
  grid… anything that takes input like the Quick append note or
  Asana… any single items that are just one type and tools that are
  just automated like back-ups… and the other groupings you find and
  suggest."

  THE NUMBERS BEHIND THE ASK. Forty-seven sections, 293 shortcut rows,
  ~335 lines — sorted A–Z. Alphabetical is the only order you can
  PREDICT without having read the file, which is why 6.66.1 chose it,
  and it is also an INDEX rather than a MAP: to find the split-windows
  key you had to already know it lives under W for Window Arranger.
  Worse, twenty of the forty-five modules sat at order = 13, the
  default nobody set, so what looked like a considered sequence was
  alphabetical-by-accident.

  EIGHT FAMILIES, EACH WITH A BAND. Sections now sort into families
  first and A–Z INSIDE the family, under a heading across the sheet:
      🪟 WINDOWS & POINTER    arranger · switcher · ⌘-drag · mouse grid ·
                             app peek · screen veil · ⇪⇧pad window map
      🗒 CAPTURE & TASKS      Capture Pad · Quick Append Pad · ⇪J ·
                             Task Form · Asana · the ⇪pad capture row
      🔎 FIND & OPEN          ⇪space · ⇪D · ⇪M · ⇪Y · command history
      📁 FILES & DOCUMENTS    ⇪I · ⇪R · the file index · file tracker
      ✂️ TEXT & CLIPBOARD     ⇪V · snippets · ⇪K · ⇪⇧A · autocorrect
      📸 SCREEN CAPTURE       ⇪4 · the editor
      ⏱ TIME & ATTENTION     ⇪Q · ⇪⇧P · ⇪⇧0 · activity · begone
      🩺 THE CONFIG ITSELF    health · key caster · tool picker · help
  A band is drawn from the FILTERED list, so searching never leaves a
  heading standing over nothing. Bands carry no section tag: the 6.94.0
  boxes close around the tools and leave the heading outside.

  ⚙️ THE AUTOMATIC TOOLS COLLAPSE. Seven modules with no keys between
  them — backup, app watcher, update tracker, doc keywords, document
  watcher, the Outlook probe, copy-on-select — were spending ~25 rows
  of the sheet on things you cannot press. They are now ONE box, one
  line each, still listed by name: a tool you have forgotten exists is
  a tool you cannot trust. copy_on_select appears there for the first
  time, having never had a cheat sheet group at all.

  🗂 EACH MODULE DECLARES ITS OWN FAMILY, in its own file, next to its
  name and order. The alternative — a membership list inside
  cheatsheet.lua — drifts the moment a module is added, which is the
  exact trap test_diagnostics' module list was rescued from in 6.66.3.
  A module that declares nothing lands in a visible "🧩 NOT YET FILED"
  band rather than being absorbed into a plausible neighbour, and
  test_diagnostics fails until it picks one. Same for a family that
  does not exist.

  🔢 THE NUMPAD IS TWO TOOLS, so it now registers TWO groups. ⇪ + pad
  captures text; ⇪⇧ + pad moves windows. Filing all twenty-four rows
  under either family would be a lie about half of them, so the loader
  learned to accept a LIST of groups from one module — each with its
  own family, and each with its own slot a thousandth apart, because
  two groups sharing an order number is not cosmetic: Lua's table.sort
  is not stable, so they would swap places at random between reloads.

  NOTHING ELSE MOVED. No key changed, no binding moved, no module file
  merged. This release is the order and the headings of one panel.

  THE BUG THIS FOUND. cheatSheet.filtered() rebuilds a partially
  matched group rather than passing it through — and the first version
  of that rebuild copied title, entries and order but not the family.
  Every band on the page vanished the moment you typed a letter, while
  the sections stayed. Copy everything the page GROUPS BY, not just
  what it prints. A test now types into the sheet and counts the bands.

  Tests: 152 in test_cheatsheet (13 new, covering bands, the collapse,
  the misc fallback and the search case), plus 4 in test_diagnostics
  auditing every module on disk for a family it recognises and every
  automatic one for the summary line the box prints.

NEW IN 6.100.2 — THE CHEAT SHEET STOPS SHOUTING:
  LL: "soften the black boxes around each tool to a similar gray of
  each shortcut box."

  6.94.0 put every tool's section on ⇪/ inside a black-outlined box,
  which was the ask at the time and read well at three or four
  sections. There are forty-two. At that count a 2px black stroke
  around each one stops being a frame and becomes a GRID ruled over
  the sheet — the eye lands on the lines instead of the words, and the
  black is the one colour on the panel that nothing else uses.

  So the section edge is now the SHARED hairline: modules/ui_style.lua's
  `stroke`, the same grey at the same width as the cheat sheet panel's
  own border and every other card in the config. The grouping that the
  black was carrying moves to the fill — each box lifts off the panel a
  little more (0.045 → 0.07) so a tool still reads as its own card
  rather than a run of rows. Same boxes, same one-per-section rule,
  same scrolling behaviour; only the shouting is gone.

  ONE HAIRLINE, NAMED ONCE. The panel's edge and the section boxes now
  draw from a single `edge` local, so "the boxes match the panel" is
  true by construction. They were two literals that happened to agree —
  and in the fallback path (no ui_style loaded) they did NOT agree,
  0.22 against 0.18, which is exactly the drift this removes.
  ✏️ Both knobs are named and commented at the draw site: put a colour
  of your own in sectionEdge for a stronger outline (the old black was
  { white = 0, alpha = 0.90 } at strokeWidth 2), or raise sectionFill
  to stand the cards further off the panel.

  🚨 AND THE TEST THAT WAS NOT TESTING. test_cheatsheet found section
  boxes by `strokeColor.white == 0` — it was really asking "is it
  black?", so the moment the colour changed, five structural checks
  (one box per section, clear of the scrollbar, drawn under the text,
  rows inside their bounds, boxes follow the scroll) would have gone on
  passing while matching NOTHING. Boxes are now identified by shape —
  a stroked rectangle with a frame of its own — and the colour ask is
  asserted as a RELATIONSHIP: each box wears the same stroke as the
  panel's own edge, whatever that is. 140 checks, 4 of them new.

NEW IN 6.100.1 — THE PHANTOM PILL GETS SWEPT:
  LL, with a screenshot of an empty black pill with a white border,
  parked on screen and taking no clicks: "I don't know how to fix this
  phantom Hammerspoon window. Can you?" The Console's last line named
  the culprit ten hours earlier: "an alert could not draw — another
  app's popup was mid-transition".

  THE DIAGNOSIS. That pill is hs.alert's own frame — black fill, white
  stroke, capsule corners — with no text in it. The 6.56.0 story again:
  ordering any window on screen notifies every AppKit observer, and
  another app's popup mid-transition throws its assertion back through
  OUR draw call. The 6.88.0 wrapper pcall'd hs.alert.show so the throw
  could not kill the config — but the throw lands MID-draw, after the
  alert's frame is already on screen and before the text is drawn or
  the fade-out timer armed. The pcall kept the config alive and kept
  the wreckage: an alert with no timer never fades, and an alert is
  not a window anything can close. It sits there until Hammerspoon
  reloads. Surviving was not enough.

  THE FIX, THE showCanvasSafely WAY. The catch now cleans up and
  retries: one run-loop turn later it sweeps — hs.alert.closeAll(0)
  reaches a wreck hs.alert registered before the throw; a double
  collectgarbage reaches one it did NOT, because a canvas nobody
  references is torn down by its __gc — then shows the SAME alert
  again with its original arguments. A retry that also fails says so
  in the Console and gives the manual way out. The sweep's cost is
  honest and accepted: a healthy alert sharing the screen at that
  exact instant is closed too — alerts live two seconds, phantoms
  live forever. The retry timer is HELD in _G.canvasShowTimers, same
  shelf as the canvas retries, because an unreferenced timer is
  collected and never fires.

  _G.phantom() IS YOURS. The same sweep, run by hand from the Console,
  for any pill that got there before this release (or survives the
  automatic path). Still on screen after that? Reload Config resets
  the Lua state, which clears it for certain. GUIDE §5 and INSTALL's
  troubleshooting both carry the row.

  THE PROOF RUNS. test_diagnostics grew §7b (11 checks): the wrapper
  block is lifted out of the shipped init.lua and EXECUTED against an
  hs.alert.show that throws — asserting the throw is contained, the
  retry is scheduled and HELD, the sweep runs BEFORE the retry, the
  original arguments arrive intact, a double failure names _G.phantom()
  without scheduling a third attempt, and the manual sweep stands
  alone. A grep can prove a string exists; it cannot prove a retry
  retries.

NEW IN 6.100.0 — ONE BOX, FOUR DESTINATIONS · BEGONE READS DESCRIPTIONS:
  LL's follow-up landed while 6.99.0 was still warm: "Can you combine
  the Capture Pad features & the Quick Append" — with a prefix outline,
  a re-cut CSV, a 4:01 review, and two bug reports. All of it is here.

  1) THE QUICK APPEND PAD IS THE COMBINATION. ⇪pad2 opens the one box
  (same Capture-Pad card, drag header, ⌘⏎). Every LINE routes by its
  prefix, exactly as outlined:
      * …   an IDEA  → ideas.txt + a notes.csv row
      + …   a LOG    → log.txt   + a notes.csv row
      ! …   an Asana TASK → handed to the Capture Pad queue verbatim
      ? …   an Asana note → same queue
      plain a LOG — "if you can't tell, make it a 'Log' entry"
  A line with a prefix STARTS an entry; unprefixed lines CONTINUE the
  entry above them, so a two-line idea stays one idea and one box can
  hold a day's worth. ! and ? are the Capture Pad's own prefixes — its
  title rules, 16:00 send, retry and parking all apply unchanged, and
  ⇪N remains for images and the queue UI. On a profile without the
  Capture Pad a ! line is saved as a Log and the alert SAYS the intent
  was lost — demoted loudly, never dropped silently.

  2) CLOSING FILES EVERYTHING. "On each close of the Quick Append Pad,
  the entries are written into the file." There is now exactly ONE
  close path and the filing lives inside it: Esc, ⌘⏎, and even the pad
  being reopened by another capture key all route the box first. The
  only entries not written are failures — they stay in the draft
  (they exist nowhere else) and the summary alert names them. The
  summary counts destinations: "📝 2 Logs · 1 Idea · 1 → Asana queue".
  ⌘⇧V inserts the clipboard into the box; ⇪pad* / ⇪pad- open the pad
  pre-typed with "* " / "+ "; ⇪pad1 still files the clipboard with no
  window at all — now as a LOG, the new default.

  3) THE CSV IS | Date | Note Type | Note entry |. Three columns,
  verbatim; Date carries the minute ("2026-08-18 14:32") so it still
  sorts. Note Type is ONLY Ideas or Logs — an unknown target records
  as Logs, per the can't-tell rule. Targets slimmed to match: Logs
  (default) and Ideas; Scratch REMOVED, Inbox no longer offered (both
  files keep their text on disk). A notes.csv left in 6.99.0's
  four-column format is rotated whole to notes-v1.csv on first append
  — appending new rows to old columns would misalign silently, and a
  CSV that lies is worse than none.

  4) THE 16:01 REVIEW. Every day, one minute after the Capture Pad's
  16:00 Asana send, the pad opens itself with TODAY'S notes.csv
  entries and asks LL's question: anything worth turning into a task?
  One click sends an entry to the Capture Pad queue forced as a task
  (!), the row flips to "queued ✓", a second click cannot double-send.
  (LL's sentence ended mid-air — "…turned into" — so task-promotion is
  the assumption, it being the only "turn into" this config has.) Days
  with no entries get a two-second alert, not a window. The reader is
  a real CSV state machine, so a quoted multi-line note reviews as one
  record. Armed in warm(), timer HELD.

  5) BEGONE, ROUND TWO: THE NAMES MOVED, NOT JUST THE FURNITURE.
  "Doesn't seem to be working. I still see banners when I do a two
  finger swipe." The 6.99.0 deep walk was reaching the right elements
  and still closing zero, and the reason is finally specific: an AX
  action has a NAME and a DESCRIPTION, and on macOS 26 "Close"/"Clear
  All" moved from the name to the description — `whose name is
  "Close"` matched nothing. Every action is now checked by name OR
  description, and as a third way in, an AXButton whose own
  description says Clear/Close (the hover ✕ the deep walk surfaces) is
  pressed directly. Still Clear-All-first, multi-pass, off the main
  thread, closed/seen reporting. The two-finger-swipe list clears
  while it is OPEN on screen; if a sweep ever again sees plenty and
  closes none, the alert points at _G.begoneProbe() — that output is
  the map for the next address.

  6) AND THE PIPE, SETTLED: the key LL was asking about is ⇪\ — the
  backslash/pipe key, NO ⌘ in it — carrying "split the two most recent
  windows", which is why it sat under "Recent documents" in his notes.
  Pressing it WITH ⌘ does nothing, which is the likely "not working".
  The split has lived on ⇪pad4 since 6.99.0; ⇪⇧pad3 stays the
  bottom-right window and ⇪pad3 the file picker, so pad4 it remains.

  tests/test_note_pad.lua rewritten for the combination (54 checks:
  parser, routing, close-files-everything, failure-stays-in-draft,
  review with quoted multi-line records, no-webview prompt, loud
  demotion); test_features pins the two-target spec, the three-column
  header, the Logs coercion and the v1 rotation; test_begone pins
  description matching and the button press. Runner still 43 stages.

NEW IN 6.99.0 — THE NUMBER PAD CAPTURES · THE NOTE PAD · BEGONE ON 26:
  Three asks in one message, plus a bug report with a screenshot.

  1) THE ⇪ + pad CAPTURE ROW. LL: "Can we use the
  hyper+shift+numpad+{number} for quick append …" — with the ⇪⇧pad
  layer already spent on the window grid (and worth keeping: it is the
  spatial map), the requests landed on the PLAIN ⇪pad layer, which
  6.66.0 cleared for exactly this day. Six keys are claimed, all by
  published service name, none a duplicate of a letter key:
     ⇪pad1  clipboard → the default notes file, instantly, confirmed
            with the file, the line count and a preview
     ⇪pad2  clipboard → the NEW Note Pad — read what you copied, fix
            it, ⌘⏎ files it (the "quick edit with an editor" ask)
     ⇪pad3  clipboard → the pick-a-file chooser (⇪⇧J's picker)
     ⇪pad4  split the two most recent windows side-by-side. LL asked
            after "hyper+cmd+|": that key is ⇪\ — the backslash/pipe
            key — carrying the split. ⇪\ still works; pad4 is the
            easier address. window_arranger publishes windows.splitTwo.
     ⇪pad*  an empty Note Pad aimed at Ideas & Scratch
     ⇪pad-  an empty Note Pad aimed at Logs
  pad+ was deliberately avoided — hs.keycodes.map["pad+"] is nil on
  LL's Mac (the 6.65.0 lesson padProbe() exists to teach). The rest of
  the layer stays free: pad0 pad5–9 pad. pad/ padenter padclear.

  2) THE NOTE PAD (modules/note_pad.lua, module #45). "On open, use a
  window like 'Capture Pad'" — so it IS that window: same dark card,
  same drag header, same ⌘⏎, non-activating panel, over-full-screen
  behaviour and the say()-carries-the-text rule all inherited from the
  Capture Pad's hard-won history. But where ⇪N queues for ASANA, this
  files to the QUICK APPEND TEXT FILES and closes. The target row
  (⌘1/⌘2/⌘3 or a click) re-aims a note without losing a character;
  ⌘⇧C copies the edited text back to the clipboard, counted; a failed
  save keeps the pad OPEN, because closing would discard the only copy.
  No webview? The plain prompt files through the same service. And on
  request the targets slimmed: "Ideas" and "Scratch" are ONE line now —
  Ideas & Scratch (ideas.txt; an old scratch.txt keeps its text, it
  just isn't offered) — and "Log" reads "Logs".

  3) notes.csv — THE SEARCHABLE INDEX. "Build a searchable .csv file
  that I can draw on with entries for 'Idea & Scratch' and 'Logs'."
  Every append — ⇪J, ⇪⇧J, every pad key, the Note Pad, the
  notes.append service — now also writes ONE CSV row next to the text
  files: date, time, category (the target's name), note. Quoted the
  chrome_history way, so Excel opens it by double-click and a
  multi-line note stays one row. The text file remains the thing you
  READ; the CSV is the thing you SEARCH. If the row fails while the
  text write succeeded, the alert says so — two stores that drift
  silently are worse than one.

  4) BEGONE LEARNED THE macOS 26 LAYOUT. LL: "Begone doesn't seem to
  be working. See screenshot." The screenshot showed WHY: the sweep
  knew three fixed addresses (Big Sur / Monterey–Ventura / Sonoma),
  macOS 26 moved the furniture again, and the last-resort fallback
  pressed Close on WINDOWS — which carry no such action — so it
  reported "nothing to dismiss" at a screen full of notifications.
  Two changes:
  a) A FOURTH ADDRESS: when no fixed path answers, the entire contents
     of every NotificationCenter window is walked and anything with a
     Clear All or Close action is pressed, wherever Apple nested it
     this year. Clear All still outranks Close; still multi-pass;
     still off the main thread.
  b) ZERO IS TWO DIFFERENT ANSWERS NOW. The script returns "closed
     seen", and the alert can finally tell the truth apart: zero seen
     → "no banners on screen — open Notification Center from the
     clock first to also empty its history" (the drawer's list is only
     reachable while it is OPEN); plenty seen but zero closed → "run
     _G.begoneProbe()", plus a notices-ledger entry, because that is
     the furniture moving again and the probe maps the new address.

  Docs rode along: INSTALL.md Step 3 no longer globs for a wrapper
  folder the zip does not contain (init.lua sits at the zip ROOT — the
  old commands died safely at the installer's completeness check, but
  died), Step 9 and GUIDE §8 describe the capture row, and the module
  count sentries moved 44→45 (hs-doctor, INSTALL.md, the loader map).
  NEW tests/test_note_pad.lua (39 checks); test_begone grew the
  macOS 26 checks (deep walk present and ordered before the bare-
  windows fallback, closed/seen contract, the three zero messages);
  test_features covers the merged targets and the CSV (header once,
  commas and newlines quoted whole). The runner is 43 stages.

NEW IN 6.98.0 — OCR SEES id= FILES · THE TASK CREATOR MOVES OUT:
  Two things, both starting from LL's Console questions.

  1) FILE-REFERENCE PATHS RESOLVE NOW. LL pasted:
     "🏷 OCR tag: clipboard has file URL(s) but no image files matched
         ↳ first candidate: no file extension found — raw value:
           \"/.file/id=6571367.18736568/\""
  and asked: "Isn't this non-breaking? If not, do we even need to show
  that line or only show when it errors?"
  Non-breaking, yes — nothing was failing. But the line had caught
  something real: "/.file/id=…" is a macOS FILE-REFERENCE path (a file
  named by id instead of by name — some apps put files on the clipboard
  that way), and the extension check can't see through it, so a REAL
  IMAGE copied like that was silently skipped. Fixed properly: the
  filesystem itself translates id paths (realpath), so the candidate is
  resolved FIRST and judged by its real name — that image OCRs and tags
  now. And the reporting followed 6.97.0's errors-only rule: ⌘C on
  ordinary non-image files prints NOTHING (that was most of what this
  line said), while genuine anomalies — a supported image that isn't
  readable, a reference path macOS refuses to resolve — print ONE line
  carrying the ⚠️ mark, which core/console.lua files under NONBREAKING.
  tests/test_ocr_tag.lua (21 checks) proves all of it on the REAL
  init.lua source, lifted the way test_hyper_key does.

  2) THE TASK CREATOR IS A MODULE. LL said yes to continuing the
  migration ("the OCR engine and Asana task creator are the two big
  blocks left"). The creator was the cleaner, safer cut — the OCR
  engine shares one clipboard watcher with the history module and was
  reworked twice in the last two releases, so it goes next, separately.
  Everything between §3.12 and §5 — the 30-day history, the attachment
  upload, the pipe parser, the assignee autocomplete, the draft mirror,
  the one shared submit path, the pipe chooser, and its three keys
  (⌃⌥⌘T · ⇪⇧S · ⌃⌥⌘A) — now lives in modules/task_creator.lua (module
  #44), taking shared services from `core` exactly like asana_comments
  did in 6.40.0. Nothing outside needed changing: every consumer
  (task_form, unified_search, window_move, §1.5 nudging) already went
  through guarded _G names, which is what made the cut safe. init.lua
  drops ~530 lines to ~3,510. core gained two entries for it:
  requireAsana (the press-time "no secret.lua" gate) and chooserTopLeft
  (the mirror places by it). The 💬 auto-comment text moved from an
  init.lua local to M.config.autoComment, so a machine profile can
  override or disable it per Mac.

  Two real fixes rode along, both stated in the module header:
  a) 🔐 THE TOKEN LEFT curl's ARGUMENT LIST. The attachment upload ran
     `curl -H "Authorization: Bearer <token>"` — argv is visible to
     `ps` for the whole upload, and this was the LAST place the token
     appeared there (the Capture Pad fixed its own copy in 6.44.2).
     Same cure: the header goes in a chmod-600 file under
     ~/.hammerspoon/.tmp — LOCAL disk on purpose, never a OneDrive
     folder — curl reads `-H @file`, the file dies when curl answers,
     and warm() sweeps leftovers after a crash.
  b) UPLOAD SUCCESS IS JUDGED BY HTTP STATUS. curl exits 0 on a 401
     just as readily as on a 201, so the old check could say
     "📎 Attachment uploaded" for an upload Asana refused. Now
     `-w "%{http_code}"` answers and only 200/201 counts; a bounded
     --max-time keeps a hung upload from holding its history row at
     "⏳ Posting…" forever.

  tests/test_task_creator.lua (51 checks) boots the real module:
  history prune/save on real disk, the pipe parser's forgiveness,
  autocomplete without the roster, submit validation, and C5's
  security property — NO curl argument contains the token, the header
  file carries exactly the auth line and is deleted on success AND
  failure. Counting sentries did their job during the move:
  test_diagnostics/test_mouse_grid (module count 43→44 in hs-doctor +
  INSTALL.md) and test_style (the bgWith(panelAlpha) pair now spans
  two files) all had to be updated to let this ship.

NEW IN 6.97.0 — ☑️ PICK SEVERAL · A QUIETER OCR · THE FILE MAP:
  Three requests, one release.

  1) SELECT MODE IN EVERY EDITOR. LL: "When I use a history edit like
  hyperkey+shift+v, I can only edit one entry at a time. But I remember
  being able to do this with another editor. Am I wrong? And also, can
  we make anything that has an editor, a multi-select tool?"
  Not wrong — the Document Watcher LIST (⇪⇧W) has had exactly this
  since it shipped: hs.chooser has no shift-click multi-select, so
  Enter TAGS rows (✓) and one action row acts on all of them. That
  proven pattern is now in all three entry EDITORS:
     ⇪⇧V  clipboard edit — "☑️ Select several…", then 🗑 Delete the N
          picked, or 📋 Copy them as ONE text (joined with line
          breaks, in history order — the joined text becomes the top
          history entry, because that is what a copy means).
     ⇪⇧E  document watcher edit — pick rows, delete them together.
     ⇪⇧O  OCR history edit — same, on the CSV.
  Everywhere: "✖️ Never mind" backs out, a bulk action ENDS select
  mode, and a fresh open always starts unpicked — reopening into
  week-old ✓ marks is how the wrong rows get deleted. Clipboard tags
  key on the ENTRY, not the index, so a copy arriving mid-pick shifts
  nothing. One-at-a-time editing is untouched in all three.
  Tests: test_clipboard grew to 57 (new §8); NEW test_select_mode.lua
  (27 checks) covers ⇪⇧E and — lifted from init.lua source, the
  test_hyper_key way — ⇪⇧O. The runner is now 40 stages.

  2) OCR: ERRORS ONLY. LL: "Can't we reduce the OCR indexed to errors
  only?" Done — "📋 OCR indexed N chars" is gone (6.65.0 had already
  silenced the success alert; this silences the console line too). The
  CSV is the record and ⇪O is the receipt. Failures still print, and
  test_select_mode §3 proves the success line stays gone by searching
  init.lua's CODE with comments stripped.

  3) THE FILE MAP + COMMENT HYGIENE. LL: "Can you organize the init.lua
  so that it is formatted with best practices? Rearrange anything that
  will make the init.lua easier for Hammerspoon to read and run. Do
  your best. Do what is safe."
  Stated honestly: Lua reads init.lua ONCE, top to bottom, and section
  order does not change its speed — the only order that matters is
  "defined before used", and MOVING code to tidy the numbering is
  exactly how 6.40.0 lost two function definitions. So nothing moved.
  What changed: a 🗺 FILE MAP at the top lists every section in the
  order it actually runs (the historical numbers are names, not
  positions — §1.4 and §1.12 really do live at the bottom), and five
  of the longest inline war stories (6.66.2 dock icon, 6.44.10 console
  quiet, EmmyLua, 6.56.0 canvas throw, 6.65.1 osascript crash,
  6.66.3 profile drift) were compressed to their load-bearing rule
  plus a "Full story: NEW IN x.y.z" pointer into this file — which is
  the trimming discipline test_integration has always encoded: safe
  only because the CHANGELOG is the complete record. Net: init.lua
  went from 3,999 to ~3,980 lines WITH the new ⇪⇧O select mode and
  the map added, still under the 4,000 budget and 60% comment cap.

NEW IN 6.96.0 — NONBREAKING ERRORS · THE ⇪D FILE INDEX · DOC KEYWORDS:
  Three requests, one release.

  1) THE NONBREAKING SECTION (core/console.lua). LL: "Is there a way
  that I can separate a type of error, errors that don't break hammer
  spoon operations. I'm thinking nonbreakable errors and put that in
  its own section that way I can work on errors with you and
  continuously improve the code."  Yes — and worth it: "error" was
  hiding two situations. The gate now classifies every line:
     ⛔ ERRORS (::::: banner)    BREAKING — 💥/⛔ marks, tracebacks,
        "uncaught", "failed to load"/"failed while loading", "syntax
        error". Something STOPPED; a tool is missing until fixed.
     ⚠️ NONBREAKING (----- banner)  ⚠️ 🚨 ❌ marks plus error/fail —
        this config's house style for "degraded politely, still
        running". The improvement pile, to work through with Claude.
  Breaking is matched first (so "failed while loading" lands there
  despite containing "fail"); both lists are editable tables at the
  top of the file. Sections never interleave — a different kind, or
  normal output, closes the open banner first. _G.errorsReport() now
  groups: breaking first, nonbreaking after, each with ×count and
  first–last times. The repeat limiter is unchanged and applies to
  both. test_console.lua grew to 56 checks.

  2) THE SEARCH INDEX (modules/search_index.lua) + ⇪D INTEGRATION.
  LL: "it would build some kind of index ... a file sitting in
  OneDrive, that helps with search results, and this would get
  integrated into my app picker/document searcher. So the search has
  to be light nimble fast doesn't use a lot of CPU cycles or GPU
  cycles or RAM and instead is aggressively efficient. ... the
  primary files it should search ... are my OneDrive folders, the
  other main folder it should search is my user level folder ...
  above all else, we don't want a heavy complicated burdensome
  search."
  THE FILE: <OneDrive>/Logs/search_index-<Mac>.txt — plain text, one
  absolute path per line. Not JSON (parse before first match), not
  XML (heavier still), not CSV (filenames contain commas): a path
  per line needs NO decoder, and the filename is just the tail of
  the line. Per-machine, like every other store.
  THE BUILD: /usr/bin/find under nice -n 19 in a CHILD process —
  zero main-thread cost — walking OneDrive to the bottom and ~ five
  levels deep, pruning dot-folders/node_modules/Library/.app
  bundles, capped per root, written to a temp file and RENAMED so a
  half-built index never publishes. Cloud-only OneDrive files list
  fine (find reads metadata, downloads nothing). Rebuilt when older
  than 12h (warm + timer), or _G.indexNow() on demand;
  _G.fileIndexReport() explains itself.
  THE SEARCH: loaded lazily ONCE into memory, then a keystroke
  touches no disk. Every word must match; filename hits outrank
  folder hits; shorter paths outrank deeper. And each added letter
  NARROWS the previous result set instead of rescanning — typing
  gets cheaper as it gets longer.
  ⇪D: with the index present, three or more typed letters list
  matching FILES (📄 + folder) under the matching apps — apps always
  first. ⏎ on a file row opens it in its default app. No index
  module, or an empty index? ⇪D is exactly the 6.91.0 apps-only
  picker, native fuzzy filter included.

  3) DOC KEYWORDS (modules/doc_keywords.lua). LL: "when I create a
  Word file and when I open one again, for hammer spoon to select
  keywords in at into the details or comments section when you write
  click on a file ... What I'm trying to accomplish is making files
  more searchable."  Saving a .docx under OneDrive, ~/Documents or
  ~/Desktop now writes "keywords: budget, revenue, …" — its 8 most
  frequent real words, stopwords removed, ties to first appearance —
  into the FINDER COMMENT, the one field Spotlight reliably indexes
  (the same route ⇪O's OCR tagger proved). Save-flurries are
  debounced to one read; one save tags once (mtime guard); the text
  is read by /usr/bin/unzip -p and the comment written by
  /usr/bin/osascript, both OUT of process (the 6.65.1 lesson). A
  comment YOU typed is NEVER overwritten — only empty comments and
  our own "keywords:" ones refresh. Honest limits, stated: .docx
  only (.doc is a binary with no zip door), and opening without
  saving touches nothing — the old keywords stand for unchanged
  text. First use asks for Finder Automation permission; a locked-
  down work Mac costs one ⚠️ line per attempt, nothing more.
  _G.tagDoc("/path.docx") tags by hand; _G.docKeywordsReport() lists
  the session's taggings.

  TESTS: test_search_index.lua (51 checks — the nice'd/pruned/capped
  build script, atomic publish, single-flight builds, lazy load,
  ranking, the narrowing cache answering identically to a full scan,
  staleness, hostile Macs) and test_doc_keywords.lua (46 checks —
  file selection, keyword ranking, the out-of-process pipeline, the
  never-clobber clause IN the AppleScript, debounce/mtime guards,
  permission failure = one honest line). test_app_launcher.lua grew
  a 14-check section: file rows join after 3 letters, apps stay
  first, ⏎ opens, a throwing index costs the file rows never the
  picker, no index = untouched native filter. Runner: 33 Lua suites.

NEW IN 6.95.0 — THE CONSOLE GETS AN ⛔ ERRORS SECTION + A REPEAT LIMITER:
  LL: "when there is an error, it place it in a defined section in the
  output of the console so it would almost be like a header that said
  errors with some kind of OR double: characters that make it stand
  out, and if the errors are repetitive, it limits the number of
  repeating error errors that occur if they are all the same. If they
  are not, it would report unique individual errors. Also, I see a lot
  of key press announcement when I use my shortcut keys, are those
  necessary? And can we reduce that number but still make the console
  output useful"

  THE GATE (core/console.lua, the ninth core file): one wrapper over
  print that every line the config — and hs.logger — emits passes
  through. A console is an append-only stream, so the "defined
  section" is drawn inline: the first error after normal output opens
  a  :::::::  ⛔ ERRORS  :::::::  banner (the double-colon characters,
  as asked), consecutive errors share it, and the first normal line
  closes it with an "end errors" rule. Errors are recognised by the
  marks the config actually uses (⚠️ 🚨 💥 ❌ ⛔) plus the words
  error/fail/uncaught/traceback — an editable list at the top.

  THE REPEAT LIMITER: each distinct line prints twice
  (consoleGate.repeatLimit), then ONE ↻ notice says it is repeating
  and further copies are COUNTED, not printed. "Distinct" ignores
  numbers — the same error with a new counter, size or timestamp in
  it is the same error — which is what turns an error inside a
  once-a-second timer, or a receipt printed on every key press, from
  a wall of scroll into three lines and a total. A line quiet for
  repeatWindow (120s) gets its hidden count summarised and may print
  again: a problem that comes BACK deserves to be seen again. Unique
  errors are untouched — suppression is per-line, never global.
  _G.errorsReport() (type it in the Console) lists every unique error
  this session with ×count, first and last time.

  WHAT IS NEVER GATED, by shape not by caller: multi-line output and
  lines over 200 bytes pass straight through — so ⇪⇧D's report,
  _G.noticesReport() and _G.bootReport() can never be suppressed as
  "a repeat of the report you asked for a minute ago". The gate is
  held to the notices.lua standard: everything pcall'd, and a failure
  inside the gate prints the line RAW — it can fail to tidy, it
  cannot fail to deliver. Honest limit: Hammerspoon's C side writes a
  few lines (the grey "-- Loading extension" ones) straight to the
  Console window without touching Lua's print; those cannot be gated.

  THE KEY-PRESS NOISE: the config itself prints no line per shortcut
  press — the recurring per-press lines are Hammerspoon re-reporting
  the same registration/hotkey complaints and modules repeating one
  receipt, and both are exactly what the limiter collapses. Nothing
  informative was deleted; it is counted instead of scrolled.

  TESTS: tests/test_console.lua — 47 checks over the banner opening
  once and closing, repeat suppression with totals kept, digit-
  normalized keys, unique errors all printing, report-shaped output
  passing through and closing an open banner, the broken-gate
  fallback, the quiet-window comeback, the ×count report, the bound
  on remembered lines, install/uninstall and the no-hs.timer Mac.
  hs-install.sh and hs-doctor.sh now verify nine core files.

NEW IN 6.94.0 — THE SHEET SCALES TO THE MONITOR + THE TIMER TELLS TIME:
  LL: "Can we make the cheat sheet flexible and dynamic so that it
  scales to the size of the monitor and in each section on the sheet
  for each tool be outlined in Black? Also, on the Pomodoro timer,
  below the countdown clock, can we also display the regular time and
  date and how many hours are left in the day if I'm working from
  7:30 to 4:30, and that is how many hours left in the workday. I
  don't take lunch."

  THE CHEAT SHEET (⇪/) SCALES: the fixed 1024x768 of 6.57.0 is gone.
  The sheet now takes a FRACTION of whichever monitor it opens on —
  cheatSheet.widthFrac (0.55) of the width, heightFrac (0.86, the old
  ceiling, now the target) of the height — so a 4K display gets a
  genuinely bigger sheet with more rows on screen, and a laptop gets
  the same proportions scaled down. Still clamped to 90% of the
  screen and floored at 360, so no fraction can hang it off a
  display. The old behaviour is one ✏️ edit away: a NUMBER in
  cheatSheet.width/height pins that dimension exactly as before.
  EVERY SECTION IN A BLACK-OUTLINED BOX: each tool's group is drawn
  inside a rounded rectangle — 2pt black stroke, a faint lift of fill
  so the edge reads on the dark panel — computed from the rows
  actually in view, so the cost stays flat however long the list
  grows. Spacer rows carry no section and become the gaps between
  boxes; a section half scrolled off is boxed to its visible half.

  THE POMODORO (⇪⇧P) TELLS TIME: two dimmed lines under the
  countdown, repainted every second with the ticker. Line one is the
  wall clock and date ("2:47 PM · Sat Aug 16" — 12-hour built by
  hand, because %p is locale-dependent and can be empty). Line two is
  the workday: "workday: 3h 12m left" against pom.workdayStart 7:30 →
  pom.workdayEnd 16:30, NO lunch subtracted, exactly as specified.
  Before 7:30 it says "workday starts 7:30" (a constant 9h 00m reads
  like a stuck countdown); at 4:30 it says done; Sat/Sun say "no
  workday today" (pom.weekendsOff = false counts every day). The
  minutes CEIL so 4:29:30 reads "1m left", never a premature "0m
  left". Panel grows 99 → 132 tall to hold the lines; every epoch is
  FLOORED before os.date — secondsSinceEpoch returns fractional
  floats, os.date throws on them, and paint()'s pcall would swallow
  that throw once a second forever (the 6.70.0 lesson, and the same
  crash recent_docs hit twice in 6.93.0).

  TESTS: test_cheatsheet gains a 6.94.0 section (scaling on 4K and
  laptop stubs, one box per visible section, black + ≥2pt, boxes
  under the text and clear of the scrollbar, boxes following the
  scroll, the fixed-size override) and its three fixed-1024
  assertions now assert the fraction; test_tools gains the wall-clock
  block (formats at known local epochs, the 7:30/16:30/weekend/
  garbage-config edges, the 12 AM/PM edge, fractional epochs not
  throwing). 137 + 138 checks in those two suites, all green.

NEW IN 6.93.0 — RECENT DOCUMENTS (⇪I) + THE SHEET CLOSES LAST:
  LL: "find recent documents that I've opened … populate the first
  nine documents that have been opened recently, and then after that
  … start showing other documents … search in multiple ways by file
  name by date by file extension … leave out files that I don't
  actively use … I have thousands of P lists [plists] and I don't
  want those to turn up." · "I thought of some other file types I
  would need..txt. .lua, .csv so essentially if it's a file type, I
  recently opened, it should display file types like the file type i
  just opened. So I won't always know what file types I'm going to be
  working on. And, you know how I have the file watcher. I'm watching
  files. I'm also watching renamed files. Could we integrate that
  here." · "I'd like the last thing to close is the cheat sheet.
  Above any other hammer spoon window of any type, the cheat sheet
  should close last even if it's in front of another hammer spoon
  window." · "What kind of display window will it have? … When can I
  drag it around the screen where I need to?"

  NEW MODULE recent_docs.lua (⇪I — the last free bare letter): the
  nine last-opened documents first, numbered, ⌘1–⌘9 opening them
  directly; below, every document type you work in, grouped with the
  ⇪space-style @tags. THE "OPENED" SIGNAL IS SPOTLIGHT'S
  kMDItemLastUsedDate, and that choice IS the plist answer: macOS
  stamps it only when an app opens a file FOR the user, never on a
  background write — the thousands of system-churned plists carry no
  stamp, the one opened while working in Outlook does. mdfind finds
  the candidates, mdls reads each hit's opened/modified dates — both
  out of process (hs.task, /bin/sh), every path and query a
  POSITIONAL argument, results cached in recent_docs-<Mac>.csv so the
  first ⇪I after login answers on yesterday's data while a fresh scan
  lands behind it (10 min staleness; ⇪⇧I re-scans on demand). A
  Spotlight-off Mac degrades to a Desktop/Documents/Downloads walk by
  mtime, and says so, rather than showing an empty panel.
  TYPES TEACH THEMSELVES: seed types (Word/Excel/PowerPoint/PDF/
  images/mail plus LL's txt, lua, csv) also show files merely
  MODIFIED — a just-received attachment appears before it's opened.
  Any OTHER extension joins the moment ONE file of it is opened, but
  a learned type only ever lists files with an opened-by-you stamp:
  eager to learn, structurally incapable of flooding. Learned types
  persist per-machine (recent_doc_types-<Mac>.csv, capped at 24),
  _G.recentDocsReport() shows them, _G.recentDocs.unlearn() forgets.
  THE ⇪F INTEGRATION: the tracker's log remembers what a file USED to
  be called — Spotlight only knows what it's called now. Its rename
  chains (A→B→C, walked oldest→newest, "Moved out" dropping the
  trail) become invisible search ALIASES (type the old name, find the
  renamed file), a story line on the row ("was Budget draft.xlsx"),
  and activity for ranking — a file renamed by hand in Finder floats
  up even though it was never "opened". Deliberate hand events
  (renames/moves, never Created-noise) of known types even earn rows
  of their own, existence-checked and hard-capped. Loose coupling:
  reads _G.fileTrackerLog, never calls the module; tracker off means
  no aliases and the report says exactly that.
  THE WINDOW is the ⇪space webview style — a search field, 19px rows,
  story sub-lines, section @tags — with both house drags (bare drag
  on the header, ⌘-drag anywhere) and the pomodoro's 6.67.0 rule THE
  ⇪space PANEL NEVER LEARNED: a remembered position wins. Drag either
  panel once and it reopens there — unless that screen is gone, in
  which case it re-centers instead of opening where you can't see.
  ⏎ opens, ⌘⏎ reveals in Finder, ⌥⏎ copies the path; search matches
  every word against name, folder, date, extension, @tag and old
  names, substring first then in-order characters ("bgt" still finds
  Budget.xlsx).

  THE SHEET CLOSES LAST, UNIVERSALLY: 6.78.0 built the rule but its
  roster had rotted — every window built since was invisible to the
  escape router, so one Esc took it AND the sheet. Eleven choosers
  are now filed in _G.choosers (⇪V clipboard + its ⇪⇧V editor, ⇪D
  launcher, ⇪Y history, ⇪M menu bar, ⇪⇧T snippets, ⇪⇧J targets, ⇪R
  rename, ⇪⇧/ tools, ⇪⇧A actions, screenshots, app monitor) and the
  four webview panels claim Esc with declared priorities (⇪space 55,
  ⇪I 58, ⇪N pad 72 — hiding it never loses the draft, ⇪T form 75,
  ⇪⇧4 editor 80). The ⇪Q focus dim joins the veil and the Key Caster
  in the deliberately-unclaimed list: the camera drives it, an Esc
  would read as flicker. New drift sentry: any module that calls
  hs.chooser.new without touching _G.choosers fails the build, so the
  roster can never rot again.

  TESTS: NEW test_recent_docs.lua — the scan-output parser (tabs,
  NUL-marker dates, UTC), the learned-types opened-only rule (an
  opened plist appears; the unopened thousands cannot), rename-chain
  aliases end-to-end, the 9-shelf numbering, remembered-position
  geometry, escape claim, hostile/no-Spotlight degradation.
  test_unified: position memory + escape claim. test_integration:
  the chooser-registry sweep. Suite: 36 stages; hostile world
  degrades 41 modules; mdfind/mdls join the reviewed-binaries list
  and hs-doctor's census. Inline changelog: 6.89.0 rotated out.

NEW IN 6.92.0 — CHROME HISTORY (⇪Y) + BEGONE (typed) + ⇪space TAGS:
  LL: "Chrome history saver with a powerful fuzzy search control over
  the Chrome history. Saves 90 days of history in the best file format
  to retrieve the most relevant data. Is searchable in the unified
  clipboard." · "Unified clipboard: I can't read all the tool tips." ·
  "Clear visible macOS notification banners via the begone keyword."

  NEW MODULE chrome_history.lua (⇪Y): Chrome deletes history older
  than 90 days, silently and by design, and keeps what remains locked
  in a SQLite file nothing else reads. ⇪Y gets it out: every profile's
  History database (Default, Profile N — the non-browsing "System
  Profile"/"Guest Profile" folders are skipped) is COPIED to the temp
  folder with its -wal/-shm companions and the copy is queried by
  Apple's own /usr/bin/sqlite3 — out of process via hs.task, because a
  100 MB history must never block the keyboard, and with every path a
  POSITIONAL /bin/sh argument, never interpolated, which is what makes
  "Application Support" and "Profile 1" safe unquoted. -json output
  because page titles contain every delimiter anyone ever chose;
  Chrome's hidden-redirect noise filtered (hidden = 0); timestamps
  converted from Chrome's µs-since-1601 epoch.
  THE FILE: chrome_history-<Mac>.csv in the Logs folder — "best
  format" here has meant the same thing since image_text.csv: Excel
  opens it by double-click, grep reads it, OneDrive syncs it, and it
  outlives Chrome's 90-day guillotine. Rewritten whole on each export
  (the newest 90 days IS the contract); warm() reads it back at boot
  so ⇪Y answers seconds after login on yesterday's data while the
  fresh export lands behind it. Re-exports when 6h stale or on ⇪⇧Y,
  which alerts the count. No pathwatcher on purpose: Chrome writes
  History on practically every page view.
  THE FUZZY SEARCH: hs.chooser filters substring-only, so ⇪Y filters
  for itself (queryChangedCallback, the ⇪F/⇪V pattern): every word
  must match — substring first, then the word's characters as an
  in-order Lua pattern ("gml" → g.-m.-l, still C-speed) — ranked
  tight-over-scattered, title-over-URL, recency breaking ties. ⏎
  reopens the page in Chrome by bundle id, default browser fallback.
  KEY: bare ⇪Y was one of the two unclaimed letters — Y as in
  "historY" — sitting beside the history shelf (⇪F files, ⇪⇧W docs,
  ⇪H commands). ⇪⇧Y = refresh + count. _G.chromeHistoryReport() prints
  per-profile counts and spans. Bare I is now the last free letter.

  UNIFIED SEARCH (⇪space) — @web joins the stores: the same 90 days
  searchable next to clipboard, commands, notes; there ⏎ COPIES the
  URL (the clipboard picker's contract — ⇪Y is the reopen control).
  And the readability fix: the placeholder had outgrown the input box
  — nine @tags trailing off the right edge is why "I can't read all
  the tool tips". The placeholder now teaches the RULE ("a @tag pins
  one source") and each section header carries its own tag (📋
  Clipboard — 400 @clip), where it can never be clipped.

  NEW MODULE begone.lua: type `begone` anywhere and every notification
  banner on screen closes. The word deletes itself — it fires through
  the Text Expander, which gained ACTION TRIGGERS for it: a snippet
  whose payload is a function (expander.addAction service; actions
  live in their own table and survive exp.load() rebuilding snippets
  from disk, checked). The sweep: /usr/bin/osascript as an hs.task
  (out of process — the 6.65.1 lesson; a multi-pass sweep can take a
  second and must not stall typing), asking System Events for each
  banner's Close / Clear All accessibility action at all three
  addresses Apple has used (Big Sur windows, Monterey/Ventura scroll
  area, Sonoma+ one group deeper), repeating while progress is made.
  The count comes back as an alert ("🔕 3 begone"); an Accessibility
  refusal says "check Accessibility" and lands in the notices ledger.
  _G.begone() runs it from the Console; _G.begoneProbe() prints the
  banner window's whole accessibility tree — the map for when a macOS
  update moves the furniture again. WHY A TYPED WORD: banners arrive
  precisely while you are typing; the dismissal lives where your hands
  already are. It is in ⇪⇧T too, and picking it there runs it.

  TESTS: NEW test_chrome_history.lua (68) — profile discovery vs
  Chrome's non-profile folders, positional-args export, a broken
  profile costs a warning not the export, CSV quoting round-trip,
  ranking probes (substring beats sequence, title beats URL, recency
  ties), chooser reuse, staleness, no-Chrome Mac. NEW test_begone.lua
  (33) — registration through the expander, the three addresses in
  the script, counts/zero/Accessibility-refusal, the probe, and an
  expander-less profile that reports instead of dying. test_expander
  §18 (+15) — typing the word runs the fn, len-1 backspaces, nothing
  typed, boundary rule holds, a throwing action is caught and
  ledgered, the action SURVIVES a rescan, ⇪⇧T lists and runs it.
  Suite: 35 stages; hostile world degrades 40 modules; sqlite3 and
  /bin/sh join the reviewed-binaries list and hs-doctor's census.
  Inline changelog: 6.88.0 rotated out (five entries stay five).

NEW IN 6.91.0 — APP LAUNCHER (⇪D):
  LL: "I need an application launcher that will launch apps in the
  regular applications folder on my personal, and for my work and
  personal mac, be able to launch applications from the user directory."
  NEW MODULE app_launcher.lua: ⇪D lists every installed app — type,
  ⏎ launches it, or focuses it if it is already running (the key means
  "get me this app", not "start another copy").
  WHERE IT LOOKS: /Applications, ~/Applications and /System/Applications
  (Safari and friends moved there in Catalina), each read ONE folder
  deep — Utilities, vendor folders, Chrome Apps.localized — and never
  inside an .app bundle. A folder that does not exist contributes
  nothing and complains about nothing, which is the whole two-Mac
  story: the personal Mac's apps live in /Applications, the work Mac's
  (no admin rights) land in ~/Applications, and the SAME module serves
  both with zero settings fork. launcher.extraDirs takes any additions.
  THE ROWS know where they came from: the source folder prints under
  each app's name, so the same app installed in two places shows twice,
  labelled, and /Applications wins the tie for the top row. App icons
  load under a 0.6s budget; rows past it just go without.
  DEFENSIVE, same reasoning as ⇪M at smaller stakes: every filesystem
  call is pcall'd, the walk is time-boxed (1s), results are cached long
  (300s) because a pathwatcher on each folder drops the cache the
  moment anything is installed or removed — so ⇪D right after an
  install already knows. The first scan and the watchers start in
  warm(), off the boot path. Launching tries launchOrFocus(full path)
  then hs.open, and admits failure in one alert naming the app.
  KEY CHOICE: bare ⇪D was one of only three unclaimed tier-1 keys
  (D, I, Y) — D as in "the keyboard Dock". There is NO ⇪⇧D twin;
  Diagnostics has owned ⇪⇧D since 6.19.0 and keeps it. The inventory
  is _G.appLauncherReport(). ⇪W is the deliberate neighbour: ⇪W
  summons a RUNNING app to this monitor, ⇪D launches installed ones,
  and both keep their jobs. (macOS 26 retired Launchpad, so "see every
  installed app" no longer had a system home.)
  TESTS: NEW test_app_launcher.lua, 57 checks — bundle non-descent
  (a Weird.app containing Helper.app must yield ONE app), depth cap
  (TooDeep.app two levels down stays unlisted), work-Mac shape (missing
  roots are Tuesday, not an error), cache TTL + watcher invalidation,
  scan budget on a wedged folder, launch fallback chain with the full
  path of the exact copy picked, one honest alert when both refuse.
  Suite grows to 33 stages; hostile world now degrades 38 modules.
  Inline changelog: 6.87.0 rotated out (five entries stay five).

NEW IN 6.90.1 — MENU BAR PICKER DEDUPE (⇪M):
  LL, from a screenshot of ⇪M showing "Bartender 6" on ⌘2–⌘5: "why do I
  see Bartender repeated?" Because the picker lists STATUS ITEMS, not
  apps, and Bartender genuinely owns several — its real icon plus the
  invisible spacer items it hides other apps' icons behind — and none of
  them carry an AXDescription, so every row fell back to the same
  "Bartender 6 / menu bar item" label. Honest, and useless.
  NOW: rows the picker cannot tell apart — same app, same detail —
  collapse into ONE row marked "×N". Picking it tries AXPress/AXShowMenu
  on EVERY item in the group before any click fallback, and activates
  the first that responds: the real icon answers, the spacers don't. The
  click fallback fires once, at the first item that HAS a position — a
  synthetic click on a zero-width spacer is a click on whatever sits
  behind it. The placeholder owns the difference ("13 items in 10 rows")
  and ⇪⇧M's inventory still lists every item, because the SCAN stays
  honest — only the picker merges.
  ALSO, from the same conversation ("And do those shortcuts conflict?"):
  the cheat sheet listed ⇪V/⇪⇧V twice — once in the static CLIPBOARD &
  OCR group, once in the CLIPBOARD HISTORY group the module has owned
  since 6.55.0. The keys were never bound twice (the hyperBind sentry
  would name it at boot); the SHEET was written twice. The static rows
  are gone. Keys documented once cannot read as a conflict.
  TESTS: test_menubar 56 → 66 — merge counts, ×N label, scan honesty
  (all items still found), first-responder activation, single click at
  the positioned item, one alert (not one per item) when nothing responds,
  same-description merge, placeholder wording.

NEW IN 6.90.0 — ONE SHARED LOOK (modules/ui_style.lua):
  LL, looking at the pomodoro FOCUS card: "How many of the windows could
  be in the GUI-style screenshot for the Pomodoro timer?" — then "Build
  it and ship it!". Eleven panels could, and now they DO: the card's
  style — background {0.09, 0.10, 0.13 @ 0.92}, white type @ 0.97, 12px
  corners, the selection blues, the flash amber — lives in ONE ✏️ table
  in NEW MODULE ui_style.lua, published as _G.uiStyle (and the style.get
  service), loaded FIRST so every panel after it can read it.
  WHO WEARS IT: the pomodoro card itself (the reference now CONSUMES the
  table, so an edit there moves it too) · the mini calendar (was radius
  16, its own near-black, its own blues) · the key caster (was its own
  black) · the ⌥Tab switcher card (was radius 18) · the cheat sheet (was
  radius 16; its alpha knob still rules the see-through, via
  bgWith(alpha)) · the ⇪T task mirror and the Asana legend strip (shared
  hue at their existing panelAlpha) · and all four webviews — Capture
  Pad, screenshot editor, Task Form, Unified Search — which append
  uiStyle.cssOverride() LAST inside their stylesheets so the cascade
  lets the shared colors win without touching any layout.
  WHAT IS NOT SHARED, deliberately: each panel's inner content — the
  calendar's day cells, the switcher's translucent tile wash over window
  snapshots, the editor's tools, the pomodoro's BREAK amber (a meaning,
  not chrome). Chrome is unified; content keeps its job.
  SAFETY: every consumer reads _G.uiStyle WITH a fallback to the exact
  literals it shipped with — a boot where ui_style fails looks like
  6.89.0, never like a blank panel. The module itself touches no hs.*
  API at all (its test runs it with hs = nil to prove it). Machine
  profiles can override any token (M.config IS the table).
  TESTS: new test_style.lua (38 checks — tokens verbatim, converters
  clamp garbage, bgWith hands out copies, pomodoro adoption, all 11
  consumers wired); adoption sections added to test_keycaster (identity
  with a published style) and test_switcher (card + selection border);
  test_unified proves cssOverride rides in exactly when published.
  Counts: 37 modules, 27 Lua suites.

NEW IN 6.89.0 — EVERY WINDOW MOVABLE + UNIFIED SEARCH (⇪space):
  EVERY WINDOW MOVABLE (LL: "I need every window movable, I should be able
  to click and hold then move the mouse cursor to move the window."):
  NEW MODULE window_move.lua. Hold ⌘, click and hold ON any panel, move
  the mouse — the Capture Pad, the editor, the Task Form, the mini
  calendar, the pomodoro card, the key caster, Unified Search, and (the
  hard part) THE NATIVE PICKERS: hs.chooser exposes no window handle, so
  the module re-anchors the visible chooser live through chooser:show(pt)
  and COMMITS where you drop it to §1.5's popupOffset — a dragged picker
  position sticks for the next picker, and ⌃⌥⌘R still resets to automatic.
  Display-only panels (pomodoro, key caster) drag with a BARE click-hold —
  no ⌘ — because clicks mean nothing on them; panels you click IN keep
  their clicks, and ⌘ is what says "the window, not the thing in it". The
  editor gained a title-bar grip that bare-drags like the pad's header.
  Driven from Lua by polling the real mouse at 60 Hz (the pad's proven
  6.44.2 pattern — an event-driven drag dies when the pointer outruns the
  window). The mouse tap consumes a click ONLY when it takes the drag, and
  stands down after five consecutive errors, mouse untouched.
  UNIFIED SEARCH, ⇪space (LL: "one unified clipboard picker where I can
  type and search all my sources combined … So yes, everything"): NEW
  MODULE unified_search.lua. One typed search across clipboard history,
  command history, the screenshot folder (with thumbnails), quick-append
  notes, Asana task history, the OCR log, document-watcher rows, file-move
  rows, and the Capture Pad queue — each store read the way its own picker
  reads it, each inside its own pcall so a broken store costs one source,
  never the panel. Every word must match; a @tag word (@clip @cmd @shots
  @note @asana @ocr @doc @file @pad) pins one source. ⏎ COPIES the row —
  full text for text rows, the image itself for screenshots; ⌘⏎ copies
  the file path (the ⇪⇧4 convention). Esc closes; header drags.
  THUMBNAILS 50% LARGER (LL: "Thumbnails on image and this new tool must
  be 50% larger, I can't read them."): an hs.chooser row's height is fixed
  inside Hammerspoon itself (HSChooser.m sizes the panel as rowHeight ×
  rows; no API exists), so a chooser thumbnail CANNOT grow — stated here
  rather than pretended otherwise. Unified Search is the fix: it is a
  webview, its rows are ours — 19px titles and 84px thumbnails (a chooser
  renders ≈13px and ≈40px). ⇪⇧space opens it pre-filtered to "@shots",
  and the ⇪⇧4 panel gained ⌘8 "BIG thumbnails" that does the same.
  command_history now provides commands.entries so both pickers read one
  loader; the ⇪⇧4 panel is 8 actions (⌘1–⌘8) and sizes itself from the
  real action count.
  Tests: new test_window_move (drag engine, ⌘/plain hit rules, chooser
  re-anchor + offset commit, tap stand-down), new test_unified (all nine
  sources parsed from fixture stores, caps, JSON escaping incl. </script,
  pick/path/close bridge actions), a new run-tests stage 3c that EXECUTES
  the search page's JS under node (filter, @tags, arrows, ⏎/⌘⏎, groups),
  and test_screenshots updated for the eighth action row.

NEW IN 6.88.0 — EDITOR TOOLS + PANEL SEARCH + COMPRESS:
  THE EDITOR GREW TOOLS (LL: "Can I draw text boxes… move them… white text
  and white outline? Can I draw arrows that rotate and stretch?"): ▦ Blur /
  🅣 Text / ➤ Arrow, as toolbar buttons or B/T/A. Text: click, type, ⏎ —
  white text in a white outline box (a soft dark shadow keeps it readable
  on white screenshots); drag to move, double-click to re-edit, size scales
  with the image. Arrows: drag one out; drag either END to stretch AND
  rotate in one motion (the head follows), drag the shaft to move. ⌫
  deletes the selected note. Text and arrows stay LIVE OBJECTS on an
  overlay canvas until save paints them into the pixels once — and one
  undo stack covers everything: blurs, adds, moves, edits, deletes.
  ⌘⇧⏎ (or the button) saves a SMALL JPEG instead of PNG.
  THE PANEL ANSWERED LL'S TWO COMPLAINTS: "I don't see the image history"
  — it was there but below the fold (7 actions ate the default 10 rows);
  the chooser now sizes itself to actions + a screenful of history. "I
  can't tell if I can search" — typing now filters the history (filename,
  date, size all match) and the action rows step aside while a query is
  live. And the compression request: ⌃⏎ on any history row re-encodes it
  as "… (compressed).jpg" via /usr/bin/sips (ships with macOS) next to the
  untouched original, small copy on the clipboard, alert names both sizes.
  THE 13:56 CONSOLE ERROR (NSRemoteView assertion killing a hotkey
  callback while Safari/WebKit autocomplete was open): hs.alert.show is
  now wrapped once in init.lua — it draws with hs.canvas, so it could
  throw the same collision showCanvasSafely already guards — and the
  mouse grid's crosshair, the last bare canvas:show() in the config, now
  routes through showCanvasSafely too.
  Tests: 12 checks added to test_screenshots (rows, search filter, sips
  args and numbering), 4 to test_editor (jpg saves), and the node stage
  now drives the REAL page handlers through text/arrow create, move,
  stretch, re-edit, delete, undo and both save formats (39 checks).

NEW IN 6.87.0 — SCREENSHOT PANEL + BLUR EDITOR:
  ⇪⇧4 grew from a history picker into the SCREENSHOT PANEL: seven capture
  actions on top (⌘1–⌘7 jump straight to one), history below. The actions:
  area capture · scrolling capture (EXPERIMENTAL — pixel-exact scroll
  events + slice stacking; seamless in browsers, seams possible in apps
  that snap scrolling; scroll.cropTop crops sticky headers) · recognize
  text/QR (text via the HS OCR Shortcut; QR via zbar when brew installed
  it, tried first) · blur/edit newest · repeat last area (our own selector
  remembers the rect; -R re-shoots it) · active window (-l, no clicking) ·
  delayed 10s (-T). Panel-initiated captures open the editor when done
  (shots.editAfterMenu); ⇪4 stays the instant path.
  NEW MODULE screenshot_editor.lua — THE BLUR EDITOR: the screenshot opens
  in a window, every box you drag is blurred in place (a box blur written
  in the page's JS — Hammerspoon has no image filters, a WKWebView canvas
  does), ⌘Z un-blurs, ⌘⏎ saves "… (edited).png" NEXT TO the original and
  copies it; the original file is never touched. Reached from the panel
  and ⌥⏎ on any history row; no hotkey of its own.
  Tests: 25 checks added to test_screenshots, new test_editor (24), and a
  new run-tests stage 3b that EXECUTES the editor page's JS under node —
  the blur, the drag, the undo, on real pixel buffers (15 checks).

NEW IN 6.86.0 — TASK FORM + SCREENSHOTS:
  ⇪T now opens a labeled FORM (modules/task_form.lua): Title / Description /
  Assignee / Attachment, each label permanently visible — the old one-line
  picker's placeholder vanished on the first keystroke. ⏎ sends from any
  field, ⇥ moves between fields, ⌥⏎ = newline in Description, Esc keeps the
  draft; 📸 button (or ⌘L) fills Attachment with the newest screenshot.
  The pipe picker survives as the past-task SEARCH on ⇪⇧S (⇪⇧T was taken by
  the Text Expander). Both paths submit through one shared function,
  _G.asanaSubmitTask — extracted UNCHANGED from the chooser callback.
  New Screenshots module (modules/screenshots.lua): ⇪4 runs the native
  crosshair capture and puts the result in TWO places at once — a
  timestamped PNG in OneDrive/2026 Screenshots AND the clipboard (macOS
  natively does one or the other, never both). ⇪⇧4 opens the history:
  newest-first with thumbnails, ⏎ puts the image back on the clipboard,
  ⌘⏎ copies its file path. Deliberately NOT a clipboard watcher — only a
  deliberate keystroke saves, so browser/PDF image copies never pile up.

NEW IN 6.85.0 — KEY CASTER TEXT LABELS + RIGHT-SIDE VERTICAL PANEL:
  Panel reverts to vertical stacking (one line per combo, newest at bottom,
  older lines dimmed). Fixed 400×600, right-anchored, font auto-computed to
  fill the box (lineH=93 → fontSize=68). Key labels now use plain text joined
  with "+": cmd+x, shift+tab, hyper+x, fn+F3 — no Unicode glyphs.
  Bare letters/numbers alone still suppressed.

NEW IN 6.84.0 — KEY CASTER HORIZONTAL LAYOUT:
  Panel now displays key combos in a single horizontal row (left→right)
  instead of stacking vertically. Box anchors to the left screen edge and
  grows rightward as combos accumulate. Font 20→28pt. Hold time 2.5→7 s;
  fade 0.35→0.15 s (fast). Single letters/numbers alone still suppressed;
  hyper combos with any key (including letters/numbers) still show as ⇪+key.

NEW IN 6.83.2 — KEY CASTER FIXED SIZE:
  Panel fixed at 270×134 (kc.fixedW / kc.fixedH). Set either to nil to
  revert to dynamic sizing.

NEW IN 6.83.1 — KEY CASTER 20PT + EXPANDER DOUBLE-POST FIX:
  Key caster font bumped 16→20pt, panel padding scaled up.
  Text expander: fixed double-post when expansion text contains its own
  trigger — hs.eventtap.keyStrokes() is async; kept injecting guard active
  for 80ms after expansion so in-flight events are discarded.

NEW IN 6.83.0 — WORKSPACES REMOVED:
  ⇪⇧S is free again. Module used private hs.spaces APIs — removed on
  user request. Use macOS native Mission Control Spaces directly.

NEW IN 6.82.0 — GRAYSCALE REMOVED:
  pad9 is free again. macOS does not expose a reliable programmatic
  interface for toggling the display grayscale filter — defaults write +
  launchctl, killall, and osascript all failed or errored in practice.

NEW IN 6.80.0 — VOLUME MODULE REMOVED:
  🗑 modules/volume.lua is gone. Use Vorssaint (vorssaint/vorssaint-utils)
     for volume — driverless, Core Audio Process Taps, real per-app mixing,
     macOS 14.2+, Apple Silicon, System Audio Recording permission only.
     The ⇪. ⇪, ⇪⇧, ⇪⇧. keys are now free.
  🐛 ROOT CAUSE of "can't reset the volume": the 6.79.2 escape shadow
     (0.5s after any chooser closed) was triggered by the volume chooser
     dismissing on Esc, which then held the cheat sheet open on the same
     keypress. Gone with the module.

NEW IN 6.79.2 — THE SHORTCUTS PANEL TRULY CLOSES LAST:
  🐛 RACE: an hs.chooser (volume, app-switcher) dismisses itself natively
     on Esc before the cheat sheet's Carbon hotkey fires. By then,
     escapeOthersActive() sees nothing open and the sheet closes.
  🔍 ROOT CAUSE 1 — nil caller in routeEscape: when hyper_key.lua's tap
     routes a bare Esc, caller is nil. The old code set mine = 0, which is
     also the cheat sheet's priority floor — making it invisible as a valid
     target. Fixed: mine = nil so a nil caller reaches the floor claimant.
  ✅ FIX 1: `local mine = nil` in routeEscape (core/coexist.lua).
  🔍 ROOT CAUSE 2 — chooser closes before the Esc handler runs:
     the sheet asked "is anything up?" too late. The window was already gone.
  ✅ FIX 2: escape shadow (core/cheatsheet.lua). The sheet polls
     escapeOthersActive every 0.25s while visible and writes
     _G.cheatSheetOtherSeenAt. On Esc, if another panel was seen within the
     last 0.5s, the sheet defers. The chooser closes; the sheet stays put;
     the next Esc (past the 0.5s window) closes the sheet cleanly.
  🧪 19/19 mutations caught. 26 stages green.

NEW IN 6.79.1 — A CORRECTION: PER-APP MIXING NO LONGER NEEDS A DRIVER:
  🚨 I TOLD LL THE WRONG THING, TWICE, AND THEY WOULD HAVE DECIDED ON IT.
     I said real per-app volume on macOS "means being an audio driver",
     and that the only options — BackgroundMusic and SoundSource — both
     need admin rights and were therefore out on the work Mac. The first
     half stopped being true in macOS 14.2 and I did not know it.
  🔍 LL pointed at vorssaint/vorssaint-utils, which does exactly what I
     said required a driver, and its README says "no audio driver, no
     setup". Reading the source settles how:
         Sources/Vorssaint/Services/Audio/AppVolumeMixer.swift
         CATapDescription(stereoMixdownOfProcesses: objects)
         description.muteBehavior = .mutedWhenTapped
         description.isPrivate    = true
         AudioHardwareCreateProcessTap(description, &tapID)
         AudioHardwareCreateAggregateDevice(...)
         engine.gain = Float(app.volume)
     CORE AUDIO PROCESS TAPS. Tap the process, mute its normal output,
     put the tap in an aggregate device, and re-render the samples through
     an IO proc that multiplies by your gain. That is a real mixer.
     · Multiplying the samples yourself is also why it can push an app
       PAST 100% — you are no longer limited to attenuating a device.
     · Pointing the aggregate at a chosen output is the per-app ROUTING.
     · The cost is one TCC permission, System Audio Recording. No kext,
       no admin, no install. macOS 14.2+ and Apple Silicon.
  📌 WHAT THAT CHANGES FOR THE WORK MAC: it may well be possible there
     after all. The blocker is no longer "needs admin to install a
     driver" — it is only whether the Mac lets you install an app and
     grant it System Audio Recording, which is an ordinary MDM question
     rather than a flat no.
  🚧 AND HAMMERSPOON STILL CANNOT DO IT. No hs.* extension binds
     AudioHardwareCreateProcessTap and none of the API is reachable from
     Lua; it would take a native helper. modules/volume.lua stays exactly
     what it is — the zero-install approximation — and its header now says
     so, and says to use Vorssaint if you want the real thing.
  ✏️ Corrected in the three places that shipped the wrong claim: the
     module header, its cheat-sheet row, and the GUIDE troubleshooting
     table. A comment that is confidently wrong is worse than no comment,
     and this config's comments are its documentation.

NEW IN 6.79.0 — I MISDIAGNOSED YOUR MAC, AND PER-APP VOLUME:
  🚨 6.76.0's SELF-TEST WAS WRONG ON THE MAC WHERE EVERYTHING WORKS. LL's
     MacBook Air — where ⇪ has worked for sixty releases — booted to:
         🎹 ⇪ did not fire: F18 reached the config (event tap) but the
            shortcut bound to it never ran.
         🎹 ⇪ IS RUNNING WITHOUT CARBON on this Mac — and it works.
     and switched a perfectly healthy Mac onto the fallback. Not cosmetic
     either: the fallback stops entering the modal, which really does cost
     the cheat sheet's type-to-filter and ⌥Tab's arrows on a machine that
     had them. I broke a working Mac while fixing a broken one.
  🔍 WHY, stated flatly because I assumed the opposite when I wrote it: a
     CGEvent posted by hs.eventtap does NOT reliably reach Carbon's
     RegisterEventHotKey dispatch. Event taps see it — that half was real,
     and it is why the tap column scored. So the probe could only ever
     measure "did the tap see it", and the Carbon column read zero on
     every Mac, healthy or broken. A test whose negative result is
     identical on a working machine and a failing one is not a test, and
     this one had a side effect.
  ✅ VERIFICATION NOW USES THE KEY YOU ACTUALLY PRESS. No synthetic events
     and nothing to be wrong about: the tap sees a real F18 keyDown before
     Carbon does, notes the Carbon counter, and looks again a quarter of a
     second later. Carbon fired → both paths work, verified, never checked
     again. Carbon did not → its F18 hotkey genuinely does not dispatch
     here, which is the work Mac's symptom measured exactly the way LL
     measured it by hand: hold Caps Lock, read the flag.
     · ⇪ is proven on your first Caps Lock press instead of two seconds
       after boot. That is a better moment: the real key, real conditions.
     · The probe survives as a DIAGNOSTIC — _G.hyperSelfTest() — and now
       prints, in as many words, that a zero in its Carbon column proves
       nothing. It no longer decides anything.
     · And a posted F18 is explicitly not treated as a press, or the same
       bug would have walked straight back in through the new door.
  🐛 A SECOND BUG THE NEW TEST FOUND: engaging the dispatcher left the
     modal ENTERED for the rest of the session, all 107 hotkeys enabled —
     dead weight while Carbon is dead, and a double dispatch the moment
     it is not. The press that proves Carbon dead had entered it a
     quarter-second earlier, and hyperExit() declines to leave once the
     dispatcher owns ⇪.
  🧪 AND THE STUB NOW KNOWS THE DIFFERENCE THAT CAUSED ALL THIS. Posted
     events reach taps and NOT Carbon, and Carbon dispatches on the run
     loop rather than inside the tap callback. The old stub delivered
     posted events to both layers, synchronously — which is why 98 checks
     and 33 mutations all passed over a bug that misdiagnosed LL's Mac on
     its first boot. 97 checks, 35/35 mutations caught.
  🔊 modules/volume.lua — PER-APP VOLUME, HONESTLY LABELLED. LL: "Control
     the volume on individual apps, how can I?"
     · macOS has NO per-app output volume. CoreAudio volume belongs to a
       DEVICE; every app is mixed by coreaudiod before it reaches one. To
       turn one app down you must be an audio driver — BackgroundMusic and
       SoundSource both install one, and both need admin rights the work
       Mac does not give.
     · So there are two mechanisms and the module never lets them be
       confused. 🎯 APP: Music and Spotify are scriptable, so their own
       mixer moves and nothing else changes — real per-app volume, two
       apps at different levels at once. 🌐 SYSTEM: everything else moves
       the system volume and REMEMBERS the level for that app, then
       restores it when you switch back.
     · The 🎯/🌐 in the alert is not decoration, it is the entire safety
       story. A tool that sometimes moves one app and sometimes moves the
       whole Mac, looking identical doing both, is worse than no tool.
     · ⇪. up · ⇪, down · ⇪⇧, mute · ⇪⇧. the panel. Both arrows repeat when
       held, which is how volume keys are actually used.
     · An app we have never been told about is left COMPLETELY alone on
       activation. A module that reset your volume on every window switch
       would be unusable, and "helpful" is not a defence.
     · AppleScript through hs.task with `with timeout of 3 seconds`, never
       hs.osascript — 6.75.0 was a whole pass about synchronous calls
       freezing the keyboard, and this one is on a key you hold down.
     · 54 checks, 16/16 mutations caught.

NEW IN 6.78.0 — THE CHEAT SHEET CLOSES LAST:
  🚨 LL: "make the shortcut key cheat sheet stay up instead of it grabbing
     escape and closing. It should be the last window to close after all
     other pop-ups."
  🔍 WHY IT WAS GRABBING IT, and it is not what it looks like. Only TWO
     things in the whole config ever claimed Esc — the sheet and the
     pomodoro — so the router had two members and every OTHER panel was
     invisible to it. The sheet holds a bare-Esc hotkey the entire time it
     is open, and a bare-Esc hotkey fires no matter which window has
     focus. Open the sheet, open a chooser or the calendar on top of it,
     press Esc, and the SHEET closed — not because anything decided it
     should, but because nothing had decided anything.
     · Its priority was a literal 10 written inside cheatsheet.lua, which
       sat ABOVE every panel with no claim at all, i.e. all of them but
       the pomodoro. The one number that was supposed to make it yield was
       the number making it win.
  🪟 AND THE ANSWER WAS ALREADY WRITTEN DOWN ONE TABLE UP. "Closes last"
     and "sits at the bottom of the stack" are one statement, so the
     escape order is now the panel order: _G.escapePriorities in
     core/coexist.lua, with the cheat sheet as the FLOOR. It is the
     backdrop you read while you work the thing in front of it.
         cheatsheet 0 · calendar 30 · switcher 40 · chooser 70 ·
         pomodoro 100 · mousegrid 900
  ⎋ FOUR PANELS THAT NEVER CLAIMED ESC NOW DO: the mini calendar, the
     window switcher, the mouse grid, and — centrally — every chooser.
     · ONE chooser claim, not fifteen. It reads _G.choosers at Esc time
       rather than at load time, because init.lua fills that table long
       after coexist runs and a list captured there would be permanently
       empty. A chooser added later is covered without touching the file.
       Choosers hold real keyboard focus, so this was the most visible
       form of the bug.
     · The screen veil and the Key Caster deliberately stay OUT. The veil
       is meant to be hard to dismiss — it has its own panic chord
       (⌃⌥⌘⇧G) precisely so a stray Esc cannot lift it — and the Key
       Caster is a display, not a dialog: Esc is a keystroke it should be
       DRAWING, not obeying.
  🚨 AN UNLISTED PANEL IS REPORTED, AND LANDS ABOVE THE FLOOR. An omitted
     priority used to default to zero, which is the sheet's floor — so a
     new panel that forgot one would be a panel the sheet closes INSTEAD
     of, i.e. this exact bug reintroduced by a spelling mistake. It is now
     looked up, an unknown name prints and files a notice, and it gets 50
     meanwhile. Of the two ways to be wrong, "too eager" is the one you
     can see; "the backdrop vanished" is the one you cannot.
  🛟 AND THE SHEET STAYS PUT EVEN WHEN THE OTHER PANEL FAILS. routeEscape
     returns nil in two very different cases — nobody wanted the key, and
     somebody wanted it and THREW — and it has to, because for most
     callers that fall-through is right. For the sheet it is exactly
     wrong: a broken calendar handler would close the SHEET, which is
     neither what you pressed Esc for nor something you could tell apart
     from a bug. _G.escapeOthersActive() asks the second question.
  🧪 24 NEW CHECKS ACROSS FOUR SUITES, and the reason they are spread out
     is the reason five mutations survived the first run: the router being
     right is worth nothing if the panels never ask it. The policy is
     tested in test_integration, and the WIRING — this module registers a
     claim, this one defers to the central table, the sheet really does
     consult it before closing — in test_cheatsheet, test_modules and
     test_mouse_grid, where the real files are already executed.
     12/12 mutations caught.

NEW IN 6.77.0 — FIX IT ALL: THE REST OF THE KEYBOARD, AND A RECORD THAT WENT STALE:
  🚨 6.76.0 RESCUED ⇪ AND LEFT EVERYTHING ELSE WHERE IT FOUND IT. It
     shipped with a line in the GUIDE admitting that the plain ⌃⌥⌘ chords
     stayed dead on a Mac with no working Carbon layer. That was a report,
     not a fix — and it left one genuine TRAP: ⇪/ opens a full-screen
     cheat sheet whose Escape is a Carbon hotkey. A panel you can open and
     cannot close is worse than a panel you cannot open at all.
  🎹 SO THE SAME TAP CARRIES THE STANDALONE GLOBAL HOTKEYS TOO, out of
     _G.globalDispatch, which §0.3 fills from the one wrapper every
     hs.hotkey.bind in this config already passes through. No second list,
     the same reasoning as the hyper dispatcher.
     · THREE RAILS, each load-bearing, because this branch runs while you
       are ORDINARILY TYPING rather than holding ⇪:
       1. AT LEAST ONE MODIFIER. A bare-key entry here would mean the
          letter d runs a shortcut instead of typing a d. Bare keys are
          exactly what a modal registers — and modal bindings never reach
          hs.hotkey.bind, so none can be in the table. The rail makes that
          structural instead of something to remember.
       2. THE FULL ⌘⇧⌃⌥ CHORD IS REFUSED WHILE ONE IS IN FLIGHT.
          Unclaimed hyper keys forward that chord and it returns through
          this same tap a millisecond later. Release ⇪ inside that gap and
          the echo looks like a real hotkey press — ⇪G could have fired
          the screen-veil escape. _G.hyperForwardChord() stamps the send
          time; the rail refuses the chord until it expires.
       3. EVERY ENTRY IS PERMANENTLY ENABLED. Everything that arms and
          disarms at runtime — the cheat sheet's keys, ⌥Tab's nav keys —
          is built with hs.hotkey.new, which the wrapper never sees. A
          bound-then-disabled hotkey would be fired WHILE DISABLED, so
          hs-lint has a rule for it rather than this paragraph having to
          be read: bound-hotkey-later-disabled, ERROR.
  ⎋ AND ESCAPE IS RESCUED SEPARATELY, because it is the one key whose
     absence traps you. Routed through coexist's escape router, so
     whichever panel currently claims Esc gets it — cheat sheet, pomodoro,
     anything added later — without this file knowing their names. Nothing
     wants it: passed through untouched, never eaten.
  📊 HONEST ABOUT WHAT IS STILL DEGRADED, and it is now only this: the
     cheat sheet's type-to-filter and ⌥Tab's arrow navigation stay on
     Carbon. Both still OPEN, and Escape still closes them. The boot
     message says so in those words rather than "some things".
  🚨 AND THE CHANGELOG CSV HAD BEEN STUCK ON 6.63.0 FOR THIRTEEN RELEASES.
     The version, the date and the entire notes paragraph were hard-coded
     in init.lua, so keeping it honest meant remembering to retype a wall
     of prose into a Lua string every release. The moment that was
     forgotten the file quietly stopped describing the config while
     continuing to look like it did — a rule 7 failure with no error to
     notice: nothing throws, the boot line is green, and the record is
     thirteen versions out of date.
     · core/changelog_csv.lua now reads _G.configVersion and lifts that
       version's entry straight out of CHANGELOG.md, which the suite
       already forces to contain every entry inline in init.lua. Nothing
       left to keep in step, so nothing left to forget.
     · A MISSING entry is reported rather than written as a blank row.
     · Lifted into core/ for the same reason: it is a feature, and
       init.lua is the orchestrator.
  🧪 tests/test_hyper_key.lua is now 98 checks, 33/33 mutations caught.
     §0.3's REAL hs.hotkey.bind wrapper is lifted out of init.lua and run,
     so what is tested is that the recording and the dispatcher agree —
     a suite that hand-filled _G.globalDispatch would prove the dispatcher
     right about a table nothing produces.

NEW IN 6.76.0 — THE HYPER KEY HAD ONE WAY IN, AND ON THE WORK MAC IT DIED:
  🚨 THE SYMPTOM WAS A GREEN BOOT ON A DEAD KEYBOARD. LL's work Mac
     printed "32 modules · 80 ⇪ shortcuts · 1.03s / All green" and not one
     shortcut worked: "All dead now. Nothing happens." Every number on
     that line was correct. Registering a shortcut is not being able to
     fire one, and nothing in this config — or in its test suite — could
     tell the two apart.
  🔬 WHAT WAS RULED OUT, one measurement each, so nobody repeats them:
     Accessibility granted · the hidutil remap applied and read back
     correct · Secure Input not held · zero hotkey conflicts · 107 modal
     bindings registered · event taps alive · ⌥Tab still working. And the
     one that decided it: holding Caps Lock for five seconds while a timer
     printed _G.hyperActive gave FALSE, on a Mac where a probe logged
     "KEY 79 f18" for every press. F18 was arriving. The hs.hotkey handler
     bound to it was never called.
     · Two of my own diagnostics were wrong on the way there and are
       recorded so they are not repeated: ⌃⌥⌘/ had been RETIRED by the
       §0.4 migration map, so testing it proved nothing; and _G.hyperActive
       read inside an event tap always reads false, because taps fire
       BEFORE Carbon dispatch even on a working Mac.
  🎹 SO ⇪ HAS TWO INDEPENDENT WAYS IN NOW. hs.hotkey is Carbon's
     RegisterEventHotKey, dispatched by the system; hs.eventtap is a
     CGEventTap that sees the key BEFORE Carbon does. A managed Mac can
     lose the first and keep the second — another process holding the F18
     registration, an MDM shortcut payload, a security agent — none of
     which this config can see or change. So it stopped trying to diagnose
     the cause and stopped depending on a single path.
     · Both paths are idempotent: enter() on an entered modal is a no-op,
       so a Mac where Carbon works is completely unaffected. A double
       enter costs nothing; a missing one costs 107 shortcuts.
     · And the tap does NOT swallow F18, or the fallback would break the
       very Mac it exists to leave alone.
  🛟 AND A COMPLETE CARBON-FREE HYPER KEYBOARD BEHIND IT, inert unless the
     self-test proves the modal's hotkeys dead. It reads the SAME table
     hyperBind already fills, so there is no second list of shortcuts to
     keep in step — every hyper shortcut in the config goes through that
     one function, so the dispatcher cannot miss one.
     · It eats the keystroke it acts on, or ⇪D would run the shortcut AND
       type a d.
     · It refuses the forwarded ⌘⇧⌃⌥ chord outright. Unclaimed hyper keys
       re-send that chord, it comes back through the same tap, and an
       infinite keyboard loop is not a bug you get to debug comfortably.
     · It honours the shared injection guard, so a snippet expanding while
       ⇪ is held cannot fire a shortcut — with ONE exception, the
       self-test's own keystroke, which exists to reach it.
  🔬 AND THE CONFIG NOW PRESSES ITS OWN KEY. Two seconds after boot it
     posts F18 + ⇧F19 and reads the answer. ⇧F19 because no Mac keyboard
     has it, macOS reserves nothing on it, and if every layer failed it
     lands in your document as nothing at all.
     · Fires → silent, and ⇪⇧D says which path carried it.
     · Modal hotkeys dead → it engages the dispatcher, RE-TESTS rather
       than assuming, and says so on screen.
     · Nothing at all → 🚨 on screen, with the two failures kept apart
       because they have different repairs: F18 never arrived, versus F18
       arrived and no shortcut ran.
     · The probe can never leave ⇪ latched: a lost keyUp is detected and
       the modal forced back out.
  🚨 "ALL GREEN" NO LONGER IMPLIES A KEY NOBODY HAS TRIED. The healthy
     boot line now says the proof is two seconds away, and ⇪⇧D reports
     "hyper PROVEN" beside the count that was not enough on its own.
  🧪 tests/test_hyper_key.lua — 71 checks, and the work Mac is a TEST CASE
     now rather than an anecdote: the stub has a switch for each layer and
     the real delivery order (taps first, Carbon only if nothing consumed
     it). Turn Carbon off and you have that machine. §3.12's
     hyperEnter/hyperExit/hyperBind are lifted out of init.lua and RUN, so
     what is tested is that the two files agree with each other.
     · All 20 mutations caught. Three survived the first run and each was
       a real weakness: a chord guard tested against a shortcut that could
       never match it, a suppression test poisoned by an earlier line, and
       a boot-line check that was a source grep — it stayed green under
       `false and _G.hyperSelfTestPending`, which is the exact shape of
       assertion this config has been bitten by three releases running.
  ⏳ _G.suppressTypingFor() in core/coexist.lua — a deadline-based sibling
     to withInjection, for events that are POSTED rather than typed. A
     post returns before the keystroke arrives, so a call-scoped counter
     is already back to zero by then. A deadline cannot leak: the worst a
     forgotten one does is expire.

NEW IN 6.75.0 — NOTHING LEFT THAT CAN BEACHBALL YOUR MAC:
  🧵 THE WHOLE RISK, IN ONE SENTENCE: Hammerspoon has ONE thread. Every
     synchronous call on it freezes your keyboard, your event taps and
     every panel until it returns. So this pass hunted synchronous calls
     with no ceiling on how long they can take.
  🚨 THE BREW PROBE BLOCKED THE MAIN THREAD ON EVERY BOOT. LL's log reads
     "no brew in the usual paths; asking your login shell shortly…" EVERY
     time — so the branch the old waiver dismissed as rare is their
     normal one. And it asked a LOGIN shell: zsh sources .zprofile,
     .zshrc and everything those pull in — nvm, pyenv, rbenv, conda,
     corporate MDM scripts. Routinely one to three seconds with the whole
     Mac frozen, a few seconds after login, every login.
     · Now hs.task: same shell, off-thread, answer in a callback. The
       task is HELD, or it is collected before it replies.
     · The old waiver was not wrong about the mechanism, only about the
       frequency. "Rare" is a claim about someone's machine, and it was
       never checked against theirs.
  ⏱ AND THE FINDER CALL BEHIND ⇪R HAD A TWO-MINUTE FUSE. A synchronous
     osascript inherits AppleScript's DEFAULT timeout of 120 seconds. A
     Finder spinning on a network volume, mid-relaunch, or waiting on a
     permissions prompt would have held the main thread for all of it —
     one keypress, a two-minute beachball, keyboard included.
     · `with timeout of 3 seconds` now. Far longer than a healthy Finder
       needs, short enough that a sick one is an inconvenience. On
       timeout osascript exits non-zero, no paths come back, and the
       rename says "nothing selected" instead of hanging the Mac.
  🔎 sync-osascript-no-timeout is a lint rule now, so the class cannot
     come back. outlook_probe is waived WITH ITS REASON: it binds no key
     and runs only when you type _G.outlookProbe() in the Console — a
     diagnostic you start deliberately and watch, where a slow answer is
     the finding rather than a surprise.
  ✅ VERIFIED CLEAN in the same sweep: both `while true` loops are
     bounded (each iteration shortens the string or breaks), no usleep
     anywhere, every automatic AppleScript path is already hs.task, and
     every Accessibility call still carries the timeout that has been
     enforced since 6.65.2.

NEW IN 6.74.0 — THE SNIPPETS SHIP IN THE ZIP:
  📦 LL: "wait... I still have to use the .alfredsnippets?" No, and that
     was an oversight worth naming: I built the importer, tested it
     against the real corpus, and then handed over a config that still
     needed a manual step. All 2,006 snippets are now unpacked inside the
     release zip at ~/.hammerspoon/snippets. Unzipping is the install.
  🚨 SCANNED, NOT COPIED into the OneDrive folder. A copy needs an "have
     I already done this" flag, and that flag is a thing that can be
     wrong — stale after an edit, lost on a reinstall, or right on one
     Mac and not the other. Two directories and no state instead. The
     OneDrive folder is scanned SECOND, so anything you import or write
     yourself overrides what shipped and re-unzipping never clobbers it.
  🔒 IN THE ZIP ONLY, NEVER IN GIT. textpanders holds real email
     addresses, a phone number, an employee ID, Zoom links and
     out-of-office text. .gitignore says so, with the reason.

NEW IN 6.73.0 — READ BACKWARDS: THE BOOT LINE CANNOT SEE THE WARM PHASE:
  🚨 THE ONE FAILURE THAT ACTUALLY BIT US WAS INVISIBLE BY DESIGN.
     Reading the boot backwards, the LAST thing that runs is warm() —
     seconds after the summary line has already printed "All green".
     · 6.69.0: "31 modules · All green", and then text_expander's warm()
       threw and all 2,006 snippets were missing. The summary was not
       wrong; it was reporting on a phase that had not happened yet.
     · And a warm() failure went to print() and _G.diag ONLY. No notices
       ledger entry, no on-screen word. A module that fails to warm is a
       DEAD FEATURE — no dictionary, no snippets — whose keys all still
       answer and do nothing. That is precisely the silent failure rule 7
       exists to forbid, in the code that reports failures.
  ✅ A warm() failure now reaches the ledger AND the screen, and the warm
     phase reports its own result once the last module has had its turn —
     silent when everything worked, because a second "all green" nobody
     needs is how people learn to skim the first one.
  📦 And the release zip was verified file-for-file against the repo: 71
     files each side, nothing missing.

NEW IN 6.72.0 — A FULL DEBUG PASS, AND TWO REAL BUGS IN THE KEYBOARD:
  🔬 HOW THIS PASS WAS RUN, because the method is the point. Three bugs
     had reached LL's Mac through a fully green suite in as many
     releases, and every one of them was the same shape: a stub more
     forgiving than the API it stood in for, or an assertion that checked
     the easy half. So this pass hunted THAT, rather than re-reading
     code hoping to spot something.
       1. A multi-return audit over the whole config — the exact class
          that killed hs.fs.dir.
       2. All 32 modules executed against three hostile worlds.
       3. All three keyboard taps loaded into ONE process for the first
          time, with a stub that feeds synthetic keystrokes BACK through
          the taps the way a real Mac does.
     Step 3 is where both real bugs were, and neither could have been
     found any other way: each module is correct about its own half.
  🚨 A SPELLING FIX COULD FIRE A SNIPPET. The text expander never checked
     the shared injection guard on the READ side.
     · Its own header claimed "IT STANDS DOWN FOR THE SHARED INJECTION
       GUARD". Only the WRITE half ever did — expansions went out through
       withInjection, but the tap itself only ever checked exp.injecting,
       which knows about this module's own typing and nothing else.
     · So every character autocorrect typed arrived at the expander
       looking exactly like a keypress. If a corrected word ended in a
       trigger, THE SNIPPET FIRED. A spelling fix expanding into an email
       signature.
     · The buffer reset below cannot prevent this — by the time
       autocorrect calls it, the expansion has already gone off. The
       read-side check is the part that has to come first.
  🚨 AND A CORRECTION MOVED THE DOCUMENT UNDER THE EXPANDER. The reset
     between the two was one-directional: an expansion told autocorrect
     to drop its word; a correction told the expander nothing.
     · Type "teh" then space. Autocorrect consumes the space, fixes the
       word and injects "the ". The expander correctly ignores the
       injection — which is exactly what leaves its rolling buffer
       holding "teh" while the document reads "the ".
     · That is not cosmetic. The buffer is what the word-boundary rule
       reads, so a trigger typed straight afterwards looks mid-word and
       is silently suppressed; and an expansion's delete count assumes
       the trigger's characters sit in front of the caret.
  🛟 TWO OF THE THREE TAPS RAN WITH AN UNGUARDED CALLBACK. The key caster
     was written with a pcall'd body and a self-disable; autocorrect has
     run without one since 6.10.0, and the expander since 6.68.0.
     · Everything in those callbacks reaches into an event object and
       does utf8 arithmetic on a rolling buffer. An error there escapes
       into Hammerspoon's event machinery ON EVERY KEYSTROKE. It does not
       stop — it just makes the whole keyboard slower and louder, and
       macOS switches off taps that behave that way.
     · All three now absorb, count consecutive failures, and stand down
       at five rather than degrade the keyboard for the session. All
       three return false on the failure path: a tap that eats a
       keystroke when it fails has taken a character and given nothing
       back.
  🧪 tools/hs-hostile.lua — A MAC THAT REFUSES EVERYTHING. All 32 modules
     loaded and set up against three worlds:
       EMPTY    every API answers nil — no screens attached, empty
                pasteboard, Accessibility withheld, folders missing.
                These are real shapes, not hypotheticals. Every module
                degrades; it is a GATE in run-tests.sh now.
       THROW    every API raises. ~19 modules throw at CREATION, which is
                expected and fine — the loader isolates it and nothing is
                left running. Read the line numbers, not the count.
       MISSING  whole hs.* extensions absent, i.e. an older Hammerspoon.
     THROW and MISSING are a register, not a to-do list. Wrapping every
     hs.hotkey.bind in a pcall would be noise with no reader.
  🔎 THREE NEW LINT RULES, one per class this pass turned up:
       keyboard-tap-ignores-injection   ERROR
       eventtap-callback-unguarded      WARN
       fs-dir-loses-state               ERROR
     Each was verified to fire against the pre-fix code and to stay quiet
     after. A rule that has never been seen to fail is not a rule.
  🧹 document_watcher was the only module reaching for the
     _G.hyperAddShortcut GLOBAL instead of taking it from `core`, which
     every other module does. Moved, for one less thing that is true of
     thirty-one files and not the thirty-second.
  ⏱ And the key caster's ⇪ fallback timer is stopped before it is
     replaced. Holding ⇪ sends repeated F18 keyDowns; without that, the
     first press's timer fired three seconds later and cleared the flag
     while the key was still down.
  ✅ VERIFIED CLEAN, and worth recording so the next pass can skip it:
     no remaining multi-return misuse, no unheld timers (all five the
     audit flagged are stored on the next line), no modal entered without
     an exit path, and every module degrades in the empty world.

NEW IN 6.71.0 — SHOW THE KEYS, AND THE BUG THAT ATE THE SNIPPETS:
  🚨 NOT ONE SNIPPET LOADED IN 6.69.0. From LL's Console:
        text_expander.lua:208: bad argument #1 to 'for iterator'
        (directory metatable expected, got nil)
     · hs.fs.dir returns TWO values — the iterator AND the directory
       object it walks. The iterator is a C function that reads the
       directory out of that second value on EVERY call, so capturing
       one variable and writing `for entry in iter do` hands it a nil
       state. warm() threw on the first folder it touched and the whole
       feature was dead: 2,006 triggers, none of them loaded.
     · Both call sites in text_expander had it. capture_pad.lua has
       always had it right — I did not look before writing mine.
     · The two safe forms, for the record:
           for entry in hs.fs.dir(path) do            -- for takes all 3
           local it, obj = hs.fs.dir(path) ; for e in it, obj do
       A pcall around the call is what makes the unsafe one easy to
       write without noticing.
  ⚠️ AND MY OWN TEST RATIFIED THE BUG, which is the part worth keeping.
     The stub returned a self-contained Lua closure that needed no
     state, so the broken call worked perfectly against it and the suite
     was green. A stub more forgiving than the API it stands in for does
     not test the code — it confirms my idea of the API. That is the
     same failure as reading a module list from the file that had the
     list wrong (6.66.3), in a different costume.
     · The stub now DEMANDS the state and raises the real message.
     · hs-lint has a new ERROR rule, fs-dir-loses-state, so the class
       cannot come back anywhere in the config rather than just here.
  ⌨️ KEY CASTER (⇪⇧B) — show the shortcuts as you press them.
     · A nearly black rounded panel floating on a shadow, right-hand
       edge of whichever screen you are working on, vertically centred.
       16px sans serif. Draggable, and it remembers where you put it.
     · It STAYS UP WHILE YOU ARE STILL PRESSING. The fade is an IDLE
       timeout, not a lifetime: every new keystroke cancels the pending
       fade and arms a fresh one, so a chord held down simply stays.
     · A held key becomes "⌘V ×3" rather than three rows.
  🚨 IT SHOWS SHORTCUTS, NOT TYPING, and one rule carries that:
     ⇧ + A LETTER IS A CAPITAL LETTER, NOT A SHORTCUT. Without it the
     panel scrolls your whole sentence up the side of the screen.
     · Shows: any ⌘ ⌃ ⌥ fn or ⇪ combination; ⇧ with a NON-typing key
       (⇧⇥, ⇧⎋, ⇧↑); bare special keys that need no modifier (⎋ ⇥ ⏎
       arrows ⇞ ⇟ ↖ ↘); every F-key; fn + anything.
     · Hides: letters, digits, punctuation, with or without ⇧. And
       backspace on its own — it is part of typing, and a panel that lit
       up on every correction would be unusable. ⌘⌫ still shows.
     · _G.keyCastTyping(true) shows everything, for a demo or a
       screencast.
  🛟 AND IT SWITCHES ITSELF OFF RATHER THAN DEGRADING YOUR KEYBOARD.
     LL's requirement, verbatim: "anything we add must fail without
     ruining, stopping, or interfering with any other running tool that
     functions properly." This is the THIRD global keyboard tap in the
     config and the only one that exists purely to look at things, so:
     · IT NEVER CONSUMES A KEYSTROKE. Every path returns false,
       including the failure paths. The suite drives every branch and
       asserts the return value, because a display tool that eats a
       keypress is worse than no display tool.
     · IT NEVER LOGS WHAT YOU TYPE. Nothing reaches the Console, the
       ledger or ⇪⇧D except counts. The panel is the only place a
       keystroke is ever rendered, and it holds six of them in memory
       and nothing on disk.
     · It stands down for the shared injection guard, so the expander's
       and autocorrect's synthetic typing is not drawn as yours.
     · Five consecutive callback failures and it STOPS ITSELF and says
       so. A tap that throws on every keystroke does not stop on its
       own — it just makes the whole keyboard slower and louder.
     · It starts OFF. A module whose job is watching your keyboard does
       nothing at all until you press ⇪⇧B.
  🔦 _G.hyperActive IS NOW PUBLISHED BY §3.12, because ⇪ IS INVISIBLE
     FROM THE OUTSIDE. Caps Lock is remapped to F18 at the HID level and
     turned into a modal, so anything watching the keyboard sees either
     a bare F18 or — for an unclaimed key — a synthetic ⌘⇧⌃⌥ chord.
     Neither is what you pressed. The panel would have drawn "⌘⇧⌃⌥X"
     for a key you experienced as "⇪X": technically accurate, useless.
     One boolean set in the two handlers that already know beats every
     consumer guessing. The module falls back to watching F18 itself if
     that global is absent, and says which one it is using.
  🔑 ⇪⇧K AND ⇪⇧C WERE BOTH ALREADY TAKEN, and §0.3 caught both before
     this module ever reached a keyboard — ⇪⇧K by the URL cleaner's
     undo, ⇪⇧C by a MIGRATED alt+cmd+ctrl+shift+c that lives in §0.4's
     migration map rather than in any module. That second one is a
     source no human survey of modules/ would have found, and a silently
     shadowed shortcut is indistinguishable from a broken feature.
     It is ⇪⇧B, for Broadcast.
  🎹 A HELD KEY IS TOLD FROM A DOUBLE EVENT BY THE EVENT, NOT THE CLOCK.
     A hyper press can arrive twice (the modal, then the synthetic
     chord) so identical text inside 60ms is collapsed — but macOS
     repeats a held key every 30-60ms, which is INSIDE that window. No
     timer can separate them. The autorepeat flag on the event can, and
     does. Found by the suite showing "⌘V ×1" for a held key.

NEW IN 6.70.0 — THE TIMER PANEL THAT WOULD NOT GO AWAY:
  🍅 IT WAS STUCK, AND LL WAS PRESSING ESCAPE CORRECTLY. From the
     screenshot: a panel reading "DONE ⏎ ⁄ esc", and "is stuck on screen
     or I'm not hitting the escape key right. But escape works for other
     Hammerspoon items."
     · When a cycle finishes, the panel asks whether to go again and
       captures ⏎ and esc for answerSecs (20s). A watchdog releases them
       when that window expires — and it released the KEYBOARD while
       leaving the SCREEN alone. Twenty seconds after the timer finished,
       the panel was a dead rectangle with nothing bound to it. ⇪⇧P or
       the Console were the only ways out.
     · The watchdog now takes an onExpire. For the final "DONE", that is
       "close". For the work→break question it is deliberately nothing,
       because the break is already counting by then and closing there
       would end your cycle for looking away for twenty seconds.
     · It also closes if the modal cannot be entered at all — a panel
       showing "⏎ ⁄ esc" over keys that are not bound is the same lie.
  🧟 AND A PANEL WITH NOTHING DRIVING IT NOW CLOSES ITSELF, WHATEVER
     STRANDED IT. Fixing the one path is necessary and not sufficient.
     This panel is a window only this module can close, so EVERY future
     path that forgets to close it has exactly the same symptom. So
     instead of trusting the paths, the ticker asks once a second:
         alive = counting down OR mid-flash OR waiting on an answer
     Anything else for a minute is a bug whether or not I have thought
     of it. It closes, and it says so — a panel that quietly tidies
     itself away teaches nobody anything.
  ∞ THE CLOCK HAD BEEN THROWING ONCE A SECOND, SILENTLY, AND THAT IS
     WHY IT FROZE. tick() sets the end time to math.huge so the phase-end
     fires exactly once. Once anything reached the clock formatter with
     that value, string.format("%02d", inf) raises "number has no integer
     representation" — inside paint()'s pcall, so it was swallowed. Sixty
     errors a minute, forever, unseen; the panel simply stopped updating
     and kept whatever it had painted last. mmss() guards infinity and
     NaN now, and the tick reports a caught throw ONCE per run, because
     the whole failure mode is repetition.
  🚨 A REPORTING CALL MUST NEVER BE ABLE TO PREVENT THE REPAIR IT IS
     REPORTING. The first version of the zombie fix printed "so it closed
     itself" and THEN called stop() — with a notices call in between that
     threw. The panel announced its own repair and stayed exactly where
     it was, which is worse than the original bug: now the Console is
     lying to you. Repair first, report second, pcall the report. Caught
     by the new test, not by reading it back.
  🎟 AND EACH ASK CARRIES ITS OWN TICKET. There are two questions per
     cycle and both arm a watchdog on the same field. A stale one
     arriving late called releaseKeys(), which stops whatever watchdog is
     current — leaving the LIVE question with none, i.e. a keyboard held
     with nothing scheduled to give it back. That is the one failure this
     module's whole design exists to prevent. Also caught by the test.
  🔢 ⌘⇧ + NUMBER PAD IS A THIRD LAYER, AND IT IS FREE. LL: "if i press
     cmd+shift+{number pad 3} it should be assignable."
     · ⇪pad has been free and assignable since 6.66.0, so the capability
       existed — but only behind Caps Lock, which is this config's own
       invention (hidutil remaps it to F18 and §3.12 makes it a modal).
       None of that exists outside Hammerspoon.
     · ⌘⇧ is a REAL modifier combination that macOS, Raycast, Keyboard
       Maestro and everything else already understand, so a ⌘⇧pad
       shortcut keeps working where a ⇪ one cannot reach and can be
       handed to something other than this config later.
     · Bound with hs.hotkey.bind, NOT hyperAddShortcut — the other two
       layers only exist while Caps Lock is held, so registering this one
       through the hyper modal would have meant it only fired with ⇪ held
       too. It would have looked like it worked. There is a test for
       exactly that.
     · Add entries to numpad.cmdShiftActions, same service-name format as
       the other two layers.
  ✅ AND THE SUITE THAT WAS MISSING ALL OF THIS. The old check for the
     answer watchdog asserted that the KEYBOARD came back and never once
     asked about the SCREEN — which is precisely why this shipped. The
     replacement drives a whole cycle to "DONE", expires the question,
     and asserts the canvas is deleted. test_tools also captures print()
     now instead of discarding it, so "it says so" is checkable at all.
  🔊 NOT IN THIS RELEASE, AND SAYING SO PLAINLY: there is no volume
     control tool in this config and there never has been. The only
     audio code anywhere is focus mode muting the MICROPHONE. Per-app
     volume of the kind SoundSource and Volume Mixer provide is not
     something Hammerspoon can do at all — it needs an audio HAL driver,
     which is why those products ship a system extension. System volume,
     output/input device switching and a mute toggle ARE reachable and
     are not built yet.

NEW IN 6.69.0 — YOUR ACTUAL 2,006 SNIPPETS, AND WHAT THEY BROKE:
  📦 ALL FIVE COLLECTIONS IMPORT AND WORK. Every prefix rule below was
     READ OUT OF THE FILES, not guessed at:
       Emoji Pack            1349   NO info.plist AT ALL
       ComposeKey             548   prefix "§" — a TWO-BYTE character
       textpanders             80   empty (bare gg1-style keywords)
       Mac symbols             23   prefix "!!"
       Ghostty or Terminal      6   empty (";" already in each keyword)
     · A MISSING info.plist IS NOT A BROKEN COLLECTION, it is a
       collection with no prefix. Emoji Pack ships without one.
     · A PREFIX IS NOT REQUIRED TO BE ASCII. ComposeKey's "§" is two
       bytes, so every length and offset in the matcher had to be honest
       about the difference between bytes and characters.
     · 636 of the 2,006 triggers CONTAIN A SPACE (":aerial tramway:",
       "!!caps lock"). A buffer that cleared on space would have lost a
       third of them; this one keeps spaces, which is why they work.
     · Only 77 triggers begin with a letter or digit — and those are
       exactly the gg1 family the word-boundary rule exists for. The
       other 1,929 start with punctuation and are exempt automatically.
     · 0 triggers collide across the five collections.
  ⌨️ MATCHING IS NOW A REVERSE TRIE, AND THAT IS NOT A REFINEMENT.
     The first version compared EVERY trigger against the buffer on
     EVERY KEYSTROKE. Six snippets: invisible. 2,006 snippets: two
     thousand string comparisons between pressing a key and the letter
     appearing, on the only thread Hammerspoon has.
     · Each trigger is inserted backwards into a byte trie; matching
       walks back from the end of the buffer and stops the moment there
       is no child. Cost is bounded by the LONGEST TRIGGER (33 bytes),
       not by how many exist — the same work at six snippets or six
       thousand.
     · Measured in the suite: 0.6µs per keystroke over 2,006 triggers.
     · "Correct but too slow to type through" is a bug like any other,
       and it is the kind a six-snippet fixture will never show you.
  ⏳ !!delf, !!tableft AND !!tabright WORK AGAIN — all three were
     unreachable. Expansion fires the instant a trigger completes, so
     !!del expanded on the "l" and left you holding a stray "f"; !!tab
     did the same to both tab variants.
     · The SHORTER trigger now waits 0.35s to see whether you are still
       typing. One more keystroke either extends it to the longer
       trigger or settles it immediately — no pause you have to sit
       through unless you genuinely stop.
     · 🚨 AND IT CONSUMES NOTHING WHILE WAITING. The characters reach
       the document exactly as typed, so abandoning the wait owes you
       nothing. The only thing a pending expansion ever does is delete
       text it can see is there — which is why an arrow key, a click,
       Return, Escape or backspace cancels it outright rather than
       firing into a caret that has moved.
     · Two triggers out of 2,006 pay for this. Nothing else waits.
  📋 MULTI-LINE SNIPPETS ARE PASTED, NOT TYPED. hs.eventtap.keyStrokes
     sends synthetic key events, and a synthetic Return inside a Teams
     message, an Asana comment or a chat box SENDS the thing instead of
     breaking the line. Eight of your snippets are multi-line or long —
     the out-of-office, the book-recommendation reply, the Asana and
     OCLC blocks — precisely the ones where firing early would be most
     embarrassing.
     · TWO OF THEM CARRY WINDOWS CRLF LINE ENDINGS (kn1, ll1). A lone
       CR is a Return to macOS, so "Kindly," would have sent on its own
       and "LL" would have become a second message. Normalised at load.
     · Your clipboard is borrowed and PUT BACK — on the failure path
       too. Borrowing it and forgetting to return it is worse than not
       having the feature.
     · The restore is DELAYED, because ⌘V is asynchronous from here:
       restoring in the same breath is a race the app loses.
     · And the clipboard-history watcher is told to look away, so a
       snippet does not reorder the history you were about to use.
  🚨 ONE INJECTION GUARD FOR BOTH TYPING WATCHERS. Autocorrect and the
     text expander both watch every keystroke AND type back into the
     document. Each had its OWN "am I injecting" flag, which is exactly
     half of what is needed — a flag only tells the module that wrote it
     to stand down. What actually happened without a shared one:
     · The expander fires `hte` → types "the". Autocorrect's tap reads
       those as real typing and files them into a word buffer that
       already held part of the trigger.
     · Worse in the other direction: autocorrect fixes "teh" → "the",
       and if the corrected word happens to end in a trigger, a snippet
       fires. A spelling fix that expands into an email signature is
       indistinguishable from a bug from where you are sitting.
     · It is a COUNTER, not a boolean. Nesting is a real state, and a
       boolean would clear on the way out of the inner call and leave
       the outer one unguarded.
     · And it SELF-CLEARS. A throw between the increment and the
       decrement would wedge it above zero forever, silently switching
       BOTH features off for the rest of the session — the quietest
       possible failure. There is a watchdog for that too.
     · The expander also tells autocorrect to drop its word buffer after
       an expansion, since it ate the trigger's last character and left
       autocorrect holding the front of a word that is no longer there.
  ✅ AND AUTOCORRECT FINALLY HAS A TEST SUITE. It has run on this Mac
     since 6.10.0 against ~11,000 dictionary rows with NO behavioural
     test of any kind — the other suites only ever checked that it
     loaded. The TWo-caps rule is one line of Lua pattern, and it is now
     pinned to LL's own description of it:
         USa → Usa   ·   SAt → Sat   ·   USA untouched
         US untouched (no third letter to judge by)
         TV's untouched (the apostrophe ends the word first)
         IDs / TVs / MHz allowed   ·   ITs deliberately NOT allowed
     That suite got written the moment a SECOND event tap started
     sharing the keyboard with it. Two taps on one keystroke stream is
     exactly the arrangement where a rule this quiet breaks unnoticed.
  🤝 core/coexist.lua. init.lua crossed the 4,000-line ceiling its own
     integration suite holds it to — and that ceiling is not
     housekeeping, it is what keeps init.lua an orchestrator instead of
     a container. Panel stacking, Esc routing, the injection guard and
     clipboard borrowing moved into one file, because all four answer
     the same question in four places: TWO FEATURES WANT THE SAME
     RESOURCE, WHO GETS IT?
  📈 A SLOW SNIPPET SCAN NOW REPORTS ITSELF WITH ITS NUMBER. Reading
     2,006 files takes ~0.3s locally and runs in warm(), off the boot
     path — but the folder lives in OneDrive alongside autocorrect.csv,
     and two thousand tiny files in a synced folder is exactly the shape
     that Files On-Demand turns into two thousand downloads. Past two
     seconds it says so, names the folder, and tells you what to do.

NEW IN 6.68.0 — SNIPPETS, AND THREE THINGS THAT WERE LEFT TO CHANCE:
  ✂️ TEXT EXPANDER (⇪⇧T). LL: "Snippets attached. Some have a trigger
     convention and some are just three letter combos like gg1 … Not all
     my snippets require a prefix. Ghostty does. Textapanders doesn't."
     Type a trigger, get the text — and BOTH conventions work at once.
     · WHY THEY CAN COEXIST, which is the whole design: .alfredsnippets
       is a ZIP of one JSON per snippet plus an info.plist carrying
       snippetkeywordprefix / snippetkeywordsuffix. That plist is the
       COLLECTION-WIDE convention. A collection exported with prefix ";"
       stores bare keywords and gets the ";" added here; your Ghostty
       export has an EMPTY prefix because the ";" is already baked into
       each keyword. Read the plist, apply it, and `;bd` and `gg1` come
       out as equals. Nothing about either style is hard-coded.
     · _G.snippetsImport("~/Downloads/x.alfredsnippets") imports one.
       _G.snippetAdd("gg1", "text") writes one by hand into its own
       collection, so an Alfred re-import can never overwrite yours.
       _G.snippetsList() prints every trigger loaded, and every snippet
       that did NOT load, with the reason.
     · {cursor} {clipboard} {date} {time} expand. Anything else in braces
       is inserted LITERALLY and reported once — a snippet that quietly
       loses "{date:yyyy}" is worse than one that visibly contains it.
     · ⇪⇧T searches them by name and inserts one, for the snippet you know
       you have and cannot remember the trigger for.
  🚨 IT WATCHES EVERY KEYSTROKE YOU TYPE, because there is no other way to
     build an expander. So, explicitly: NOTHING IS EVER LOGGED — not the
     buffer, not to the Console, not to the ledger, not into a
     diagnostic. The only thing that leaves the module is the NAME of a
     snippet that fired. The buffer holds 64 characters. macOS secure
     input switches event taps off inside password fields, so those are
     structurally unreachable. Terminal is excluded by default. The tap
     is revived on the same 30s watchdog autocorrect uses, because a
     silently dead expander is rule 7's exact failure mode.
  🧨 A BARE THREE-LETTER TRIGGER NEEDS A WORD BOUNDARY IN FRONT OF IT.
     Plain suffix matching fires the moment the last character is typed,
     wherever it lands: `abc` would expand in the middle of "fabcd". A
     trigger starting with punctuation — `;bd`, `:sig` — is EXEMPT,
     because that leading character IS the boundary and demanding another
     would break the very convention it exists to serve.
     expander.wordStartOnly = false restores plain Alfred behaviour.
  🪟 THE POMODORO NOW SITS ABOVE THE CHEAT SHEET. LL: "Bring the
     Hammerspoon tool window in front of shortcuts."
     · Both panels were drawn at hs.canvas's `overlay` level, and two
       windows at the SAME level are ordered by whichever was shown last.
       So the timer appeared in front or behind depending on the order you
       happened to press the keys. The stacking was not wrong, it was
       UNDEFINED — and undefined reads as "sometimes broken".
     · _G.panelLevels writes the order down in one table, as OFFSETS from
       `overlay` rather than absolute numbers: an NSWindow level is just an
       integer, so "the sheet's level plus three" survives macOS
       renumbering the named constants. The invariant is TESTED —
       pomodoro > cheatsheet — not assumed.
  ⎋ AND ESC NOW GOES TO THE RIGHT PANEL. LL: "Everytime I hit escape the
     shortcut windows disappear."
     · The cheat sheet holds a bare-Esc hotkey the whole time it is open.
       The pomodoro wants Esc for the ~20 seconds after a phase ends.
       hs.hotkey resolves that by ENABLE ORDER — most recently enabled
       wins — so opening the sheet while the timer was flashing silently
       stole Esc from the timer and you had to close the sheet first.
       Enable order is an implementation detail; this needed a policy.
     · _G.routeEscape is that policy. Claimants register a priority and an
       "am I active right now" test; whoever holds Esc asks the router
       first. Timer (100) over sheet (10), and ONLY while a phase-end is
       actually waiting on an answer — the rest of the time Esc closes the
       sheet exactly as before. A claimant whose handler throws does not
       swallow the keystroke: it reports and the caller carries on,
       because an Esc that does nothing at all is the worst outcome.
  🔄 ⌥TAB ACTUALLY SWITCHES NOW — AND SAYS SO WHEN IT DOESN'T. LL:
     "Alt+tab does not reliably bring me to the select app or do it
     consistently." Three separate causes, all real:
     · hs.window:focus() IS becomeMain() + raise(). Both act WITHIN the
       owning application and NEITHER activates it. If the target belongs
       to an app that is not already frontmost — the only interesting case
       for a window switcher — the window rose and your keyboard stayed
       exactly where it was. The app is activated first now, then the
       window focused. One missing line, every background switch.
     · UNMINIMIZING IS NOT INSTANT. unminimize() starts the genie
       animation and returns immediately; a focus() in the same tick lands
       on a window that is not on screen yet and is dropped. That path
       waits for the animation now.
     · THE 4-SECOND LIST CACHE IS DROPPED ON EVERY SWITCH. It was keyed on
       time alone, and front-to-back order is exactly what a switch
       CHANGES — so a second ⌥Tab within the window reused a list where
       position 1 was the window you had just left and position 2 was the
       one you were now in. Two quick presses "switched" you to where you
       already were.
  🎯 AND THE STARTING TILE IS ANCHORED TO THE WINDOW YOU ARE ACTUALLY IN.
     `index = 2` was shorthand for "the tile after the current one" and
     assumed the list always begins with the focused window. It usually
     does and it does not have to. The front window is now located in the
     list by id, so the answer is right whatever order the list came back
     in; not found falls back to the old behaviour, which is correct.
  🚨 THE TOOL PICKER'S RUN MAP STILL SAID ⇪pad+ AND ⇪pad*. Both keys moved
     to letters in 6.66.0 — pad+ does not exist in hs.keycodes.map on this
     Mac — and the map kept the old names, so the pomodoro and the mouse
     locator were the two tools ⇪⇧/ could never actually run.
     · tp.verify() did not catch it because it checked that the SERVICE
       existed, which it did. A run map is a JOIN between two tables that
       both change, and checking one side of a join catches half the
       drift. It checks the key side against the live cheat sheet now,
       which is what found this.

NEW IN 6.67.0 — GRAB THE PANELS AND MOVE THEM:
  🖐 LL: "Great pop-up. But I can't drag the window. Same with shortcuts
     window. Both should be moveable." An hs.canvas is not an NSWindow
     with a title bar — there is nothing to grab, so dragging has to be
     built: notice the press, follow the pointer, move the panel.
     _G.makeCanvasDraggable does it once, in init.lua, for every panel
     rather than twice by hand and a third time next month.
  📌 AND THE POSITION IS REMEMBERED. Drop a panel and it reopens where you
     left it for the rest of the session; ⇪R clears both.
     · THIS MATTERS MOST FOR THE CHEAT SHEET, and the reason is the search
       box: typing REBUILDS THE CANVAS ON EVERY CHARACTER. A position
       stored on the canvas would be lost between "a" and "as" and the
       sheet would jump back to centre mid-search. It lives on the
       namespace instead, and there is a check that types three
       characters and asserts the panel has not moved.
  🖥 CLAMPED TO A REAL SCREEN, both of them. A remembered position
     outlives the display it was set on: drag the sheet to the 4K, unplug
     it, and without clamping the sheet is restored to coordinates that no
     longer exist — invisible, with no way to reach it and no obvious
     cause.
  🚨 THE DRAG IS FOLLOWED BY AN EVENTTAP, NOT BY CANVAS MOUSE EVENTS, and
     that is not a preference. A canvas only reports movement while the
     pointer is INSIDE it; any drag faster than the panel redraws — which
     is most drags — leaves the pointer behind, the events stop, and the
     panel is stranded halfway across the screen.
     · An eventtap is also the most dangerous object in this config, so it
       gets the same treatment as every other one here: it starts on
       mouseDown and stops on mouseUp; a WATCHDOG stops it after 20
       seconds no matter what, because a mouseUp delivered to another
       process is a mouseUp we never see; it returns false, so it OBSERVES
       the drag rather than swallowing it; and only one drag can be live
       at a time. A tap left running is a tap reading every mouse event
       you make for the rest of the session.
     · The watchdog is armed BEFORE the tap is created, same ordering as
       the Mouse Grid and the pomodoro modal: a throw between the two
       must not leave a global mouse tap with nothing scheduled to stop
       it.
  ⚖️ THE COST, AND IT WAS A DOCUMENTED FEATURE. The cheat sheet used to
     let clicks fall THROUGH to the window behind it — 6.31.0 turned mouse
     events off entirely because "a stray click used to dismiss the
     reference mid-lookup". A panel you can grab is a panel that takes
     clicks; it cannot do both. A click still does not CLOSE it, which was
     the actual hazard.
  🧪 1,902 checks, 17 suites, 0 failures, 0 lint findings. Seven mutations
     caught across the two panels: never registering, not storing the
     drop, ignoring a stored position, and dropping the clamp. One check
     had to be made defensive first — with the registration mutation
     applied there is no DRAGGABLE[1], and a bare index aborted the run
     and blamed the wrong line. That is the third time that lesson has
     come up in this project.

NEW IN 6.66.5 — SEVENTEEN WARNINGS IN TWO SECONDS, AND THEY WERE MINE:
  🚨 "hs.hotkey system callback for an eventUID we don't know about: 0",
     seventeen times across two seconds of LL's Console. That is
     Hammerspoon being handed a key event for a hotkey it has just been
     told to forget — and the cause was the cheat sheet search box added
     in 6.66.0.
     · Typing a character calls show() to rebuild the filtered rows.
       show() calls hide() first, so it can never stack two panels. And
       hide() disabled all THIRTY-EIGHT search keys, which enableInput()
       re-enabled a moment later.
     · SEVENTY-SIX hotkey operations per character typed, with real key
       events arriving in the middle of them. Nothing broke — every check
       passed, the search worked, and the only symptom was macOS saying
       the churn was absurd. It was right.
  ✅ hide(keepInput) — a REDRAW rebuilds the canvas and leaves the
     keyboard exactly as it is; only a real close touches the keys.
     Measured in the suite: 45 disables per keystroke before, 0 after.
     · AND THE OTHER HALF IS PINNED JUST AS HARD: a real close must still
       release every key. A sheet that closed while holding 38 bare
       letters is a keyboard that types into nothing, which would be the
       worst bug this file could have. Both directions are
       mutation-verified.
  🔇 COPY-ON-SELECT SAYS IT ONCE PER APP, NOT ONCE PER ACTIVATION.
     "Finder didn't accept an Accessibility watcher" fired every time
     Finder came forward, and the same for Asana, Archive Utility, Teams
     and System Settings. The fact is worth knowing exactly once: a whole
     class of application — Electron shells, Apple's own newer panels —
     simply does not implement AXFocusedUIElementChanged, and no amount of
     retrying changes that. Repeating it turns a real finding into
     wallpaper, and wallpaper is what you scroll past on the day it
     matters.
  ✅ EVERYTHING ELSE IN THAT LOG WAS THE CONFIG WORKING: OCR indexed 276
     characters silently (6.65.0's rule), the Capture Pad sent one item to
     Asana, and the file tracker suppressed a created-file burst. The only
     remaining noise is the /.file/id= clipboard form, which is macOS
     handing us a file reference with no extension — correctly reported,
     nothing to fix.
  🧪 1,888 checks, 17 suites, 0 failures, 0 lint findings.

NEW IN 6.66.4 — THE BOOT LINE COUNTED ONE SOURCE OUT OF THREE:
  🔢 "32 ⇪ shortcuts" READ THE SAME BEFORE AND AFTER 6.66.3 added four
     modules and four new keys. That is what gave it away.
     _G.hyperShortcutCount was #_G.hyperMigrations — the §0.4 migration
     map ALONE — so every shortcut a module registers through
     hyperAddShortcut was invisible to it. The number never described what
     it claimed to; it happened to look plausible.
  🚨 AND IT IS PRINTED AT EVERY LOGIN, on the one line this config asks
     you to read, immediately beside the module count that DID reveal the
     four missing modules. Sitting next to a number that was doing its job
     lent it a credibility it had not earned. A figure that looks like a
     total and is not is exactly the quiet misreport rule 7 exists to
     forbid — and unlike a silent failure, this one was actively
     reassuring.
  ✅ It reads _G.hyperBoundCount now: hyperBind increments that once per
     combo actually claimed, from every source — the migration map,
     modules, and your own hyperActions.
     · FORWARDED CHORDS ARE SUBTRACTED, deliberately. Every unclaimed
       letter re-sends ⌘⇧⌃⌥+itself so hyper keeps working with Raycast and
       browser extensions; counting those would report roughly forty
       whatever this config actually binds, which is a different lie.
     · _G.hyperMigrationCount keeps the old figure for anyone who wants
       it, under a name that says what it is.
  📈 EXPECT THE NUMBER TO JUMP on the next boot. The jump IS the bug:
     those shortcuts were always bound and never counted.
  🧪 1,885 checks, 17 suites, 0 failures, 0 lint findings. The new checks
     assert that modules really do claim ⇪ keys (a zero there would mean
     the count is measuring the wrong thing again) and that the boot line
     derives from hyperBoundCount rather than the migration map. Both
     mutation-verified by restoring the old expression.

NEW IN 6.66.3 — FOUR MODULES HAD NEVER LOADED ON LL'S MAC:
  🚨 "26 modules · All green" WAS TRUE, AND THAT IS THE WORST PART.
     Thirty module files sat on disk. Nothing failed, because nothing was
     asked to load. init.lua carried THREE hand-typed `modules` lists —
     one per machine profile — and 6.65.0 through 6.66.2 added the new
     modules to `default` alone. LL's Mac matches the "Lees-MacBook-Air"
     profile, so the Tool Picker (⇪⇧/), Universal Actions (⇪⇧A), the
     Pomodoro (⇪⇧P) and the Outlook Probe have not existed on his machine
     since the day each was written.
     · Four releases of work, every one of it tested, documented,
       shipped, and absent. He has been reporting on features he did not
       have — and the boot report, the cheat sheet and the diagnostics all
       agreed with him that everything was fine.
  ⚠️ THE TEST SUITE AGREED WITH THE BUG, which is the part worth carrying
     forward. test_integration deliberately READS the module list out of
     init.lua rather than retyping it, on the sound reasoning that a
     hand-copied list in a test would drift from the config. But init.lua
     contained three hand-copied lists, and the test read the one that
     happened to be correct. test_diagnostics had the identical read and
     the identical blind spot.
     · A test that reads the same wrong source as the code does not check
       the code, it CONFIRMS it. The fix is not a better pattern match —
     it is checking against something the code cannot also be wrong
       about, which here is the FILESYSTEM.
  ✅ ONE LIST. `local BASE` holds the modules; every profile calls
     profileFrom{ without = {…}, plus = {…}, settings = {…} } and declares
     only its DIFFERENCES. The list is COPIED per profile, never shared —
     a profile that referenced BASE and then dropped an entry would drop
     it for every other profile too. Adding a module is now one edit that
     reaches all three Macs.
  🔒 TWO CHECKS THAT WOULD HAVE CAUGHT IT, both now failing the build:
     · EVERY MODULE FILE ON DISK MUST BE IN BASE. A .lua in modules/ that
       no profile loads is a feature that reports "All green" forever.
     · NO PROFILE MAY HAND-TYPE ITS OWN LIST. The structural fix has to be
       proven in use, not described in a comment.
     Both were mutation-verified: removing pomodoro from BASE and giving a
     profile its own list each fail loudly and name the cause.
  🖼 THE CANVAS EXCEPTION FROM LL'S CONSOLE IS FIXED TOO:
       NSInternalInconsistencyException … '<NSRemoteView …
       SPCompletionListServiceViewController> notified of <HSCanvasWindow>
       but expected (null)' … -[NSRemoteView containingWindowWillOrderOnScreen:]
     A bare canvas:show() colliding with Safari's URL-completion popup
     mid-transition. _G.showCanvasSafely — which catches it, retries one
     run loop turn later, and reports through the ledger if it still
     refuses — has existed since the last time this happened, and SIX
     canvases bypassed it: three in Mouse Grid, plus the pomodoro, window
     switcher and mini calendar. Focus Mode and Screen Veil used a bare
     pcall, which stops the throw escaping but gives up on the first
     failure and says nothing.
     · All eight go through the helper now, and lint rule
       canvas-show-unprotected counts bare shows against protected ones
       per file — counted rather than forbidden, because the CORRECT
       pattern deliberately contains a bare show in its else-branch
       fallback. The first version of the rule flagged all three correct
       call sites.
  🧪 1,882 checks, 17 suites, 0 failures, 0 lint findings.

NEW IN 6.66.2 — "SOME WINDOWS DON'T COME FORWARD BUT SOME DO":
  🎯 EXACTLY RIGHT, AND THE SPLIT IS THE WHOLE DIAGNOSIS. LL noticed that
     the shortcuts panel appears over full-screen apps and other windows
     do not. That is not inconsistency, it is two different technologies:
     · WORKING: hs.canvas — the cheat sheet, Mouse Grid, pomodoro, screen
       veil. A canvas accepts fullScreenAuxiliary, and 6.66.1 fixed the
       last two that were still on "stationary".
     · NOT WORKING: hs.chooser — clipboard history (⇪V), OCR search (⇪O),
       the Tool Picker (⇪⇧/), Universal Actions (⇪⇧A), the menu bar
       picker (⇪M), every Asana list.
  🖥 THE CAUSE IS THE DOCK ICON, and it is documented Hammerspoon
     behaviour rather than a defect in this config. From the official
     hs.chooser documentation:
       "As of macOS Sierra and later, if you want an hs.chooser object to
        appear above full-screen windows you must hide the Hammerspoon
        Dock icon first, using hs.dockicon.hide()"
     The rule is AppKit's: an app WITH a Dock icon is a REGULAR
     application, and a regular app's panels cannot be drawn over another
     app's full-screen Space without switching Spaces. An app without one
     is an ACCESSORY application, and its panels float anywhere. A
     chooser is a native NSPanel exposing no collection-behaviour API, so
     no amount of Lua can grant it what a canvas gets for free — which is
     why 6.66.1's fix helped the canvases and did nothing for the
     pickers.
  ✅ HIDDEN AT BOOT, FROM init.lua rather than from the Preferences
     checkbox. A setting that lives only in a GUI does not travel to the
     other Mac, and this config's whole design is that the file IS the
     configuration. The failure path says so out loud rather than leaving
     you to wonder why ⇪V still will not open over Excel in full screen.
  ⚖️ THE TRADE, STATED SO IT IS A CHOICE AND NOT A SURPRISE:
     · GIVES UP: the Dock icon, and Hammerspoon in ⌘Tab.
     · KEEPS: the menu bar icon, every hotkey, the Console (menu bar icon
       → Console) and Preferences. Nothing becomes unreachable — this
       config is driven entirely by ⇪ shortcuts and the menu bar, so the
       Dock icon was never a route to anything.
     · hideDockIcon = false near the top of init.lua puts it back.
  🧪 THE TEST FOR THIS CAUGHT ME OUT FIRST, and the mistake is worth
     recording because it is the SECOND time in one day: the check greps
     init.lua for hs.dockicon.hide, and the comment block explaining the
     fix CONTAINS that string — so deleting the actual call still passed.
     hs-lint's canvas-not-fullscreen rule had the identical failure a few
     hours earlier, where a comment mentioning fullScreenAuxiliary
     silenced the check on the file documenting it. Both strip comments
     before searching now. A search for CODE has to look at code.
  🧪 1,876 checks, 17 suites, 0 failures, 0 lint findings.

NEW IN 6.66.1 — "MY SHORTCUTS DON'T WORK OVER FULL SCREEN APPS":
  🚨 THEY DID WORK. THE PANELS WERE INVISIBLE, and that is a much worse
     failure than a dead key because it is indistinguishable from one.
     Two canvases were still on "stationary" behaviour rather than
     fullScreenAuxiliary: the POMODORO and the Focus Mode dimmer — the two
     most recently written, which is exactly where a convention gets lost.
     · "stationary" means "do not move me when Spaces change". It says
       NOTHING about full screen. Without fullScreenAuxiliary a canvas
       cannot draw over a full-screen app AT ALL, so the shortcut fired,
       the panel was built, and nothing appeared.
     · Ten of the twelve call sites in this config were already correct.
       That is the shape of this class of bug: a convention followed
       almost everywhere is invisible in the one place it was not.
  🔒 A LINT RULE, SO IT CANNOT COME BACK — and it took two attempts, both
     of which are worth recording because each was a plausible-looking
     check that silently did the wrong thing:
     · ATTEMPT ONE flagged all twelve correct call sites. The linter
       BLANKS STRING LITERALS before rules see a line, which is right for
       nearly every rule and fatal for one that has to read what is inside
       a string — "fullScreenAuxiliary" was invisible to it.
     · ATTEMPT TWO counted over raw file text instead, and a COMMENT
       mentioning fullScreenAuxiliary counted as a use of it. The file
       explaining the fix silenced the check on itself.
     · It now reads comment-stripped, string-preserved source, and counts
       behaviorAsLabels calls against fullScreenAuxiliary mentions per
       file — which also handles the call being split across two lines.
  🔤 THE CHEAT SHEET IS PURE A–Z. The pins are gone, on request.
     6.65.0 pinned Mouse Grid and Tool Picker above the alphabetical run,
     which was ALSO asked for at the time ("put the grid first, then
     alphabetize the rest"). Those two instructions do not agree and the
     later one wins. Pure alphabetical is the more defensible default
     anyway: it is the only order you can PREDICT without having read the
     file, and a pinned section is one you must remember is pinned before
     you can find anything else.
     · cheatSheet.pinned still exists and still works — add words from a
       group's title to pin it back. A test drives the mechanism with a
       pin set, so an empty list stays a CHOICE rather than quietly
       becoming a dead code path.
     · A module that FAILED to load still outranks everything, pinned or
       not. A feature that vanished without explanation is the one thing
       that must never be scrolled to.
  🔢 THE NUMBER PAD SCREENSHOT WAS 6.65.x. Everything shown in it was
     already cleared in 6.66.0 — every ⇪ + pad key is free, all ten digits
     and every arithmetic key. Installing 6.66.1 is the whole fix.
  🧪 1,873 checks, 17 suites, 0 failures, 0 lint findings.

NEW IN 6.66.0 — THE SEARCH BOX, AND A KEY THAT WAS NEVER BOUND:
  🔎 TYPE INTO THE CHEAT SHEET ITSELF. ⇪/ and then just start typing. The
     panel filters live, in the SAME 20pt translucent column, with the
     query shown in the title and a match count beside it. Esc clears the
     query; a second Esc closes the sheet.
     · ↩️ THIS REVERSES WHAT I TOLD LL, and the reversal is the point. I
       said a canvas cannot take keyboard focus, so search had to be a
       separate hs.chooser window. Both halves are true and together they
       are beside the point: Mouse Grid has captured bare letters over a
       canvas overlay since 6.45.0 without ever taking focus. Bind the
       keys, keep the typed string yourself, draw it. The constraint was
       real and the conclusion drawn from it was lazy.
     · A group whose TITLE matches keeps ALL its entries — searching
       "grid" shows the whole Mouse Grid section, not only the rows with
       the word in them.
     · 🧨 PLAIN TEXT, NEVER A PATTERN. This sheet is a wall of ⇪[ ⇪\ ⇪-
       ⇪/ ⇪= and every one is an operator in Lua's pattern engine. Typing
       one into a box that fed that engine hands it a malformed pattern
       and throws. Fourteen of them are test cases.
     · Backspace steps a CHARACTER, not a byte: lopping one byte off a
       multi-byte glyph leaves a string hs.canvas will not draw.
     · 🚨 THE TRADE, STATED PLAINLY: while the sheet is open it CAPTURES
       LETTERS, so you cannot type into another window without closing it.
       That is the same bargain the Mouse Grid makes, with the same safety
       property behind it — keys are only ever taken while something is on
       screen saying so — and hide() gives all thirty-eight back through
       individual pcalls, so one failing disable cannot strand the rest.
  🔢 THE ⇪ + PAD LAYER IS EMPTY, on request, and that is a feature. Every
     entry it held was a SECOND way to press a key that already existed:
     pad7→⇪Q, pad8→⇪⇧Q, pad4→⇪R, pad5→⇪X, pad6→⇪M, pad1→⇪K, pad3→⇪⇧0,
     pad.→⇪⇧R. Ten keys spent on duplicates is ten keys unavailable for
     anything new. All ten digits and every arithmetic key are now free.
     The ⇪⇧ WINDOW MAP IS UNTOUCHED — its 3×3 layout is the one thing on
     the pad that is not duplicated by a letter anywhere.
  🚨 AND ⇪pad+ NEVER WORKED. LL was right, and the way it failed is the
     lesson. It was assigned to the pomodoro in 6.65.0, documented in the
     header, listed on the cheat sheet, and covered by a test that
     asserted the assignment. On his Mac hs.keycodes.map["pad+"] returns
     nil, so bindAll correctly SKIPPED it rather than binding nil and
     taking the layer down. Every layer of the process agreed the feature
     worked. The only thing that disagreed was the keyboard, and it said
     so in one console line at boot.
     · The pomodoro is on ⇪⇧P now. A letter cannot fail that way.
     · A SKIPPED KEY IS REPORTED through the notice ledger, not whispered
       to a console nobody has open. That was a rule-7 violation sitting
       in a module that already knew the answer and kept it to itself.
     · _G.padProbe() prints every pad key, its key code on THIS Mac, and
       what it is bound to on both layers. Run it BEFORE assigning a pad
       key, not after wondering why nothing happens. It also names the
       usual culprit: Accessibility → Pointer Control → Mouse Keys eats
       the entire number pad when it is on.
     · The test that asserted ⇪pad+ was the pomodoro now asserts the
       opposite — the timer must NOT be on a pad key — so the shape of
       this mistake cannot come back.
  🖱 ⇪⇧L FINDS THE POINTER. grid.locate() has existed since 6.45.0 bound
     to nothing, went to ⇪pad* in 6.65.0, and lands on a letter now that
     the pad is clear.
     · 🚨 AND IT WAS DRAWING WRONG. The ring used "overlay" level and
       "stationary" behaviour while the grid itself uses screenSaver and
       fullScreenAuxiliary. Consequences, both invisible until hit: at
       overlay the ring HIDES BEHIND THE MENU BAR, so a pointer parked
       near the top was not found by the tool whose only job is finding
       it; and without fullScreenAuxiliary a canvas cannot draw over a
       FULL-SCREEN app at all — exactly when a pointer goes missing,
       because there is no window furniture left to locate it against.
       "stationary" only means "do not move me when Spaces change".
  🧪 1,873 checks across 17 suites, 0 failures, 0 lint errors, 0 lint
     warnings. Twenty-seven new checks; six mutations caught on the search
     box alone, including show() losing the query to its own internal
     hide() — which would have made typing filter the list and instantly
     unfilter it, reading as "the search does nothing" rather than as a
     bug.

NEW IN 6.65.2 — A LINTER, INSTEAD OF FIXING ONE MORE OF THESE BY HAND:
  🔍 tools/hs-lint.lua — every rule is a bug that REACHED LL'S MAC. Not a
     style guide, not best practice copied from somewhere: a receipt, with
     the version it was found in attached. It reads init.lua, core/ and
     all thirty modules in about a second and runs FIRST in run-tests.sh,
     ahead of every suite.
     · WHY STATIC AND NOT MORE TESTS, which is the real argument: an
       Accessibility call with no setTimeout is correct Lua. It compiles,
       it passes every test anyone will ever write for it, and then it
       freezes a real keyboard when one app answers slowly. Some bug
       classes are only visible by SHAPE, and no amount of behavioural
       testing finds them.
     · A LINTER THAT CRIES WOLF GETS TURNED OFF, so rules are narrow on
       purpose. A check that is 80% right is worse than none: the 20%
       teaches you to skim past output you should be reading. Two rules
       were cut back for exactly this after their first run.
  🚨 IT FOUND A REAL FREEZE ON ITS FIRST RUN — copy_on_select.
     The module asks other applications for AXFocusedUIElement and
     AXSelectedText with NO setTimeout. That is the precise hazard
     menubar_items fixed in 6.47.0, still live in a second module, and
     WORSE placed: menubar_items asks on a keypress, this asks on EVERY
     APP SWITCH. A wedged app holds Hammerspoon's main thread, and the
     main thread is what reads your keyboard.
     · LL's console had been naming the badly-behaved apps for weeks —
       "Microsoft Teams didn't accept an Accessibility watcher", "System
       Settings didn't accept an Accessibility watcher". Those lines are
       the observer being REFUSED, which was handled. The unhandled case
       is the app that accepts and then does not answer.
  🚨 AND A BUG THREE WEEKS OLD, IN CODE I HAD JUST WRITTEN.
     universal_actions reported SUCCESS for three actions whose service
     might not exist. _G.service.call prints and returns nil on a missing
     provider — it never throws — so the pcall around it succeeded whether
     the service ran or was never registered. The action was then
     REMEMBERED and floated to the top of the most-used list having done
     nothing at all.
     · tool_picker got exactly this guard when it was written, with a
       comment explaining why. universal_actions, written the same day,
       did not. That is what a linter is for: I do not reliably remember
       my own lesson across two files in one sitting.
  📋 THE FULL RULE SET, all of it from this project's own scar tissue:
     · applescript-in-process   (6.65.1 — the crash)
     · canvas-empty-elements    (6.62.0 — the two-screen crash)
     · paren-starts-line        (6.64.0 — the config that would not load)
     · lua-quote-for-shell      (6.65.1 — %q is not shell quoting)
     · ax-without-timeout       (6.47.0 — the frozen keyboard)
     · unheld-object            (collected timers and menubar items)
     · service-call-unchecked   (6.65.0 — "ran it", having not)
     · adopt-decoded-table      (6.62.0 — queue and parked became ONE)
     · pattern-on-variable      (⇪[ and ⇪% are pattern operators)
     · module-contract          (a module that loads as nothing)
     · deprecated-drawing, private-api, blocking-main-thread
  ✍️ A WAIVER REQUIRES A REASON. `-- hs-lint: allow <rule> — why`, and a
     BARE waiver is itself reported. The point of an exception is that
     somebody thought about it; the written reason is the only evidence
     that anyone did. Five are in place, each one arguing its case —
     notices.lua (nil is a meaningful answer), numpad_layer (a test
     resolves every name against the live registry, which is stronger
     than a runtime check), update_tracker and outlook_probe and the
     shutdown hidutil call (blocking is correct in each).
  ℹ️ INFO IS A REGISTER, NOT A QUEUE. Seven notes mark code that is
     CORRECT but fragile — hs.spaces private APIs, calls that block the
     main thread. Waivers deliberately do NOT clear them. After a macOS
     update, that list is the first thing to re-verify: Tahoe is exactly
     the event those notes exist for.
  ⚖️ THE LINTER MADE ITS OWN MISTAKE, and it stays in the history because
     it is the best possible argument for one of its rules: interpolating
     a rule id straight into a Lua pattern matched nothing, because
     "service-call-unchecked" contains '-', which is a QUANTIFIER. Every
     file-level waiver silently failed to apply, and the tool reported
     problems that had already been argued and settled. That is the
     pattern-on-variable rule, committed by the file that defines it.
  🧪 1,846 checks, 17 suites, 0 failures, 0 lint errors, 0 lint warnings.
     The copy_on_select timeout and the universal_actions guard both have
     tests; the guard's three checks were mutation-verified by removing
     it again.

NEW IN 6.65.1 — THE CRASH, AND THE pcall THAT WAS NEVER PROTECTION:
  💥 HAMMERSPOON WAS ABORTING, from LL's report on macOS 26.6.1, 0.6
     seconds after launch:
       _NSAppleEventManagerGenericHandler
       handleUncaughtException
       -[SentryCrashExceptionApplication reportException:]
       abort()
     An uncaught OBJECTIVE-C exception raised while the main thread was
     handling an Apple Event.
  🚨 EVERY AppleScript IN THIS CONFIG NOW RUNS OUT OF PROCESS.
     hs.osascript.applescript runs NSAppleScript INSIDE Hammerspoon and
     sends Apple Events on its main thread. /usr/bin/osascript is the
     same AppleScript in a child process, where the worst outcome is a
     non-zero exit.
     · ⚠️ AND THE pcall AROUND IT WAS WORTH NOTHING — the part worth
       carrying forward. Lua's pcall catches LUA errors. An Objective-C
       exception is not one: it unwinds straight past pcall into the
       uncaught handler and aborts the application. Four versions of this
       file wrapped those calls and read as if they were handled. Every
       "it is wrapped, so it is safe" instinct was wrong here.
     · 🎯 THE WORST OFFENDER NEEDED NO KEYPRESS. The OCR Finder-comment
       tagger runs from the CLIPBOARD WATCHER: copy image files in Finder
       and it fires on its own, including seconds after login while the
       clipboard still holds what it held yesterday. LL's own console
       shows that path running on file URLs at boot, which is why the
       crash looked unconnected to anything he did.
     · TWO SHAPES, AND THE DIFFERENCE IS SAFETY, NOT TASTE. bulk_rename
       reads the Finder selection SYNCHRONOUSLY via hs.execute, because
       it feeds a rename and a stale list would rename files you did not
       select — destructive and unrecoverable. Universal Actions reads it
       ASYNCHRONOUSLY via hs.task and caches, because it is
       non-destructive and shows you the filename in its own title before
       you choose. The cost of hs.execute is named: it blocks the main
       thread until Finder answers, on a keypress you made, never on a
       timer.
     · A SHELL-QUOTING BUG CAUGHT ON THE WAY: the first version used
       Lua's ("%q"):format for the script. %q escapes a newline as
       backslash-newline, which is correct Lua and WRONG SHELL — inside
       double quotes the shell reads that as a line CONTINUATION and
       joins the lines, so a multi-line AppleScript arrives as one line
       and fails to compile. Single quotes with '\'' is the only form
       that passes an arbitrary string through /bin/sh unaltered.
  🔑 CAPS LOCK IS GIVEN BACK WHEN HAMMERSPOON GOES AWAY. A hidutil remap
     is a SYSTEM-WIDE HID mapping. It is not owned by this process and it
     does not die with it: quit, force quit or crash, and Caps Lock is
     still sending F18 with nothing left running to turn that into a
     modifier. The keyboard is then quietly missing a key and the obvious
     remedy — kill the app that did this — is the one thing that cannot
     help. That is the "killing it does not free up the keys you can use
     natively" half of LL's report, and it was this line's absence.
     hs.shutdownCallback now lifts the remap on a clean quit and on ⇪R.
     · ⚠️ A HARD CRASH STILL CANNOT RUN THAT, because nothing gets to
       run. The manual escape hatch stays the important one:
           hidutil property --set '{"UserKeyMapping":[]}'
       A reboot clears it too.
  🚑 SAFE MODE. `touch ~/.hammerspoon/SAFE`, reload, and four modules
     load instead of thirty. In a crash loop every way of fixing this
     config goes THROUGH the config — the cheat sheet, ⇪⇧D, the reload
     key, the Console — and a loop takes all of them at once. The only
     advice left was "move init.lua aside", which turns everything off
     and teaches you nothing about which part was at fault.
     · WHAT SURVIVES: the hyper key and the cheat sheet are not modules,
       they live in init.lua and always load, so ⇪/ still works and you
       can read your way out. Plus health_monitor, mini_calendar,
       window_arranger and numpad_layer.
     · WHAT DOES NOT, and this is the point: nothing that talks to
       another application, drives a private macOS API, or runs on a
       timer. Those are the three things that can abort the app or wedge
       the desktop.
     · `rm ~/.hammerspoon/SAFE` restores everything.
  🖱 ON MISSION CONTROL AND THE FOUR-FINGER SWIPE, HONESTLY: nothing in
     this config binds a trackpad gesture, and I cannot prove the cause
     from the report. What I can say is that the only module touching
     Spaces internals is workspaces, through hs.spaces, which drives
     PRIVATE macOS APIs — precisely the kind that break on a new major
     release, and macOS 26.6.1 is new. When they wedge, the thing that is
     stuck is the DOCK, not Hammerspoon, which explains why killing
     Hammerspoon does not release it and `killall Dock` does. Safe mode
     excludes workspaces, so a safe-mode boot is also the test.
  🧪 1,834 checks, 17 suites, 0 failures. New in this release:
     · A STATIC BAN: no shipped file may contain the string
       hs.osascript.applescript. This is a grep, deliberately, in a suite
       that otherwise executes everything — the property IS textual
       ("this call is absent"), and executing cannot prove a branch is
       absent when the branch may be the one the test did not take.
     · AND A RUNTIME ONE: the stubbed hs.osascript.applescript THROWS.
       A stub returning a plausible value would let the crash walk back
       in unnoticed.
     · The harness now prints each failure AS IT HAPPENS. The banned-call
       stub aborts the run by design, and a summary that never prints
       took every finding before it down with it — which happened while
       writing these very checks.

NEW IN 6.65.0 — A SEARCH BOX, A PINNED SHEET, AND FOUR NEW TOOLS:
  🔎 ⇪⇧/ IS A SEARCH BOX OVER EVERY SHORTCUT. The cheat sheet (⇪/) is a
     good thing to READ, and reading is the wrong verb when you already
     know roughly what you want. "oh I need a URL tool" — type "url" and
     there they are. It searches the SAME assembled groups the sheet
     draws, so the two can never disagree about what exists; the entries
     come from whichever modules actually loaded this session, rebuilt on
     every press rather than cached, so a module that failed to load
     cannot still be offered here.
     · Words match in ANY ORDER and ALL must match — "clean url" and
       "url clean" both find the link cleaner.
     · 🧨 THE FILTER IS PLAIN TEXT, NEVER A PATTERN. This config's
       shortcuts are written in ⇪[ ⇪\ ⇪- ⇪/ ⇪= and every one of those is
       an operator in Lua's pattern engine. Each find() passes `true` as
       its fourth argument, which is what turns matching off.
     · ⏎ RUNS IT when it can, rather than telling you a key and leaving
       you to press it. Entries whose key maps to a published service are
       invoked; the rest are copied to the clipboard.
     · 🚨 has() BEFORE call(). _G.service.call does NOT throw on a missing
       provider — it prints and returns nil — so a pcall around it
       succeeds whether the service ran or never existed. Without the
       has() check this picker would have reported "ran it" while doing
       nothing at all. The run map is also verified against the live
       registry on first press, and a name that resolves to nothing is
       reported through the ledger.
     · ⚠️ WHY NOT A SEARCH BOX ON THE SHEET ITSELF: that sheet is drawn on
       hs.canvas, and a canvas cannot take keyboard focus without giving
       up the two properties that make it good — it floats WITHOUT
       stealing focus, so it never interrupts typing, and it closes on Esc
       without capturing Esc globally. The other branch already paid that
       price in 6.31.1. ⇪/ to browse, ⇪⇧/ to search, neither compromised.
     · The cost, and it is a real one: hs.chooser picks its own row font
       and exposes no opacity API, so this window does not inherit the
       sheet's 20pt text or its translucency. macOS limitation, same one
       §1.5 has noted for every picker in this config.
  📌 THE SHEET IS PINNED-THEN-ALPHABETICAL. Mouse Grid first, Tool Picker
     second, everything else A–Z, ⭐ custom entries last, and a module
     that FAILED to load still outranks all of it.
     · 🚨 THE TRAP THAT WAS ALMOST WALKED INTO: the sheet was ordered by
       each module's `order` field, which is its LOAD order. Renumbering
       modules to move a section up the page would have reordered the
       BOOT — which is how a module ends up running before something it
       depends on. The sheet sorts for itself now; load order is
       untouched.
     · Position is decided on the title with the leading emoji and the
       trailing (⇪X — …) parenthetical stripped. Sorting the raw string
       files most of the sheet under whatever emoji happens to lead,
       which is not an order anyone can predict.
  🎯 THE GRID NARROWS VISIBLY, WHICH IT DID NOT BEFORE. Type a letter and
     the lattice DROPS AWAY; what remains is the still-reachable cells,
     each in a thick amber box.
     · Dropping the lattice is ONE element (keep the scrim, drop the
       segments), not one greyed rectangle per discarded cell — so the
       more the grid narrows the CHEAPER the redraw gets.
     · Labels are 14pt MINIMUM and grow to fill their cell, clamped by
       width so a label can never spill out of a narrow one. They grow
       FURTHER as you narrow: two characters left to type need less width
       than three. 12pt was chosen to fit; this is chosen to be read.
     · The box is inset by half its stroke so two adjacent survivors read
       as two targets rather than one wide one.
     · 🚨 AND THE BUG THAT CAME WITH IT, caught by its own test: the
       canvases are CACHED across hide/show, so once typing had stripped
       the lattice the next ⇪X would have opened a grid with no lines in
       it — last session's final frame, looking exactly like a rendering
       fault. show() restores the lattice explicitly now.
  🍅 POMODORO on ⇪pad+. 25 minutes, then it flashes amber and counts you
     five. 170×99, top-right, just under the clock, on the monitor
     holding the frontmost app. Click-through, so it is a timer and not
     an obstacle.
     · 🚨 ⏎ AND esc ARE CAPTURED ONLY WHILE IT IS ASKING — the ~20s after
       a phase ends. The obvious implementation captures Enter for as
       long as the timer is up, which is TWENTY-FIVE MINUTES in which
       Enter does not send an email, submit a form or make a newline, and
       nothing on screen explains why. This config has shipped one
       keyboard-holding bug already (the pre-6.47.0 menu bar scan).
     · The watchdog that releases the keys is armed BEFORE the modal is
       entered, so a throw between the two cannot strand it.
     · The flash IS the notification — no sound, no hs.notify. It fires
       while you are mid-sentence in something else.
  ⚡ UNIVERSAL ACTIONS on ⇪U — Alfred's panel, done natively, for what
     this config can actually do: Reveal · Open · Open With · Copy Path ·
     Copy File · Terminal Here · Get Info · Open URL · Clean URL · Plain
     Text · Large Type · Email · Snippet · Rename.
     · The action you used last is at the top next time, persisted to the
       Logs folder and shared between both Macs. Remembered on SUCCESS
       only — floating an action that just failed is the opposite of help.
     · Actions that cannot apply right now are HIDDEN, not offered and
       then failed. A list that offers "Open URL" when there is no URL is
       a list you stop trusting.
     · The context is captured for THAT press, not re-read in the
       callback — after a few seconds of scrolling the Finder selection
       need not still be what the panel said it was acting on.
     · It takes its own copy of the JSON decoder's table, one string at a
       time. Adopting the decoder's tables is what left the Capture Pad
       with queue and parked as ONE table in 6.62.0.
     · ⚠️ NOT Alfred's list and it cannot be — Alfred owns its actions and
       exposes no API to enumerate or invoke them. Ours works with Alfred
       closed.
  🖱 ⇪pad* FINDS THE POINTER. grid.locate() has existed since 6.45.0,
     published as a service and deliberately bound to nothing on the
     argument that macOS shake-to-grow already covers it. It is bound
     now. The asterisk is the mnemonic — the only key on the pad shaped
     like the thing it draws.
  📧 _G.outlookProbe() — READ-ONLY, no key, no watcher, runs only when
     called by name. The email tracker asked for (sender, keyword,
     attachment type, month, weekday) is buildable IN FULL on legacy
     Outlook, which ships a real AppleScript dictionary, and only PARTLY
     on the redesign, which dropped most of it. Guessing which is
     installed is precisely how 6.63.0 muted a microphone for a week.
     Nine scripting probes, then an Accessibility tree walk (bounded at
     4,000 nodes — an unbounded walk of a mail client's view tree hangs),
     with a verdict at the end. Samples are truncated so a paste-back
     cannot spill a whole email.
  🔇 OCR SUCCESS IS SILENT NOW. "📋 OCR Indexed" popped on every image
     that touched the clipboard — an alert for the thing working exactly
     as designed. Rule 7 says tell me when something FAILS, and the
     corollary has to be that success does not interrupt: an alert seen
     twenty times a day is one you stop reading, including on the day it
     says something else. A failed Finder tag is a PARTIAL failure (text
     indexed, file not tagged, so a Finder search will not match it) and
     still reports — through the ledger, not a popup.
  🧹 THE ⇪M PICKER LISTS REAL APPS ONLY. macOS runs a fleet of faceless
     agents that each own a menu bar extra — the clock, Control Center,
     the input-source menu, Stage Manager, WindowManager. They ARE status
     items, so the scan was right to find them, and none can be usefully
     driven by "pick it and click it". Fourteen are skipped now.
     ⚠️ A DENY LIST, NOT A RULE: there is no flag that means "agent, not
     app". LSUIElement is set by plenty of menu-bar-only apps you DO want
     here (1Password, Bartender, Ice, NordVPN), so filtering on it would
     throw away the good with the bad.
  🧪 269 → 285 grid checks and 65 → 71 sheet checks, ELEVEN mutations
     caught between them: the pin emptied, the pins reversed, the emoji
     left in the sort key, broken modules demoted, custom entries
     promoted, the lattice never dropped, the lattice never restored,
     the highlight never drawn, the highlight not inset, a thin border,
     and the label floor put back to 12.
     · The old order test listed all sixteen titles in sequence, so it
       broke whenever a module was added whether or not anything was
       wrong. It pins the RULE now, and drives the pin through the real
       sort against a fixture whose title beats "MOUSE GRID"
       alphabetically — the case that would pass by accident if the pin
       did nothing.
     · One test was made to fail CLEANLY rather than crash: with the
       lattice-restore mutation applied it indexed a element that no
       longer existed, aborting the run and pointing the traceback at
       the wrong line.

NEW IN 6.64.0 — EDITOR AUTOCOMPLETE FOR THE hs.* API:
  💡 EMMYLUA ANNOTATIONS. It writes out files describing every
     Hammerspoon function — name, arguments, return type — and an editor
     that speaks the Lua language server protocol reads them, finishes
     `hs.pasteboard.` for you and underlines a call you got wrong WHILE
     YOU TYPE. Ported from the 6.31.4 lineage on the other branch.
     · That last part is why it is worth having. Several real bugs in
       this config's history were exactly that shape: hs.pasteboard.readURL
       returning a different type than assumed, and the canvas
       replaceElements signature that caused 6.62.0's two-screen crash.
       Both parse fine. Both are invisible to luac and visible to a
       language server.
     · ZERO RUNTIME COST — it generates the files and stops. No hotkey,
       no timer, no watcher, nothing on the main thread afterwards.
     · Not installed? One console line and the config carries on, so this
       stays portable to a Mac that has never heard of it.
     · ⚠️ THE GENERATED FILES ALONE DO NOTHING. Your EDITOR has to be
       pointed at Spoons/EmmyLua.spoon/annotations. CotEditor cannot use
       them at all.
     · 🚨 AND IT SHIPPED BROKEN, FOR ONE CHARACTER. The block sits
       directly after `_G.diagBootStart = hs.timer.secondsSinceEpoch()`,
       and Lua read the assignment and the following `(function() … end)()`
       as ONE statement — a call of the number that assignment returned:
       "attempt to call a number value", and the whole config failed to
       load. A semicolon after the assignment is the entire fix. This is
       the one piece of Lua syntax where a newline is not a separator.
  🔊 APP MONITOR PINGS EVERY 0.5s, was 1s. Same ten sounds, same wrap,
     twice the rate — the popup waits indefinitely by design, so the
     thing that matters is reaching you in another room.

NEW IN 6.63.0 — FOCUS MODE WAS MUTING YOUR MIC BECAUSE TEAMS WAS OPEN:
  🎤 THE BUG, AND IT IS THE BAD KIND. The Teams pattern list was
       { "Meeting", "Call with", "| Microsoft Teams$" }
     and the third entry matches EVERY Teams window, because every Teams
     window title ends "| Microsoft Teams". In a Lua pattern `|` is an
     ordinary character, not alternation — it is a literal pipe, not
     "or". So Focus Mode read "Teams is open" as "you are in a meeting",
     muted the microphone, turned Focus on and dimmed the screen. LL's
     own ⇪⇧Q report named the culprits, verbatim:
       Chat | Canales, Beatrice E | Microsoft Teams
       Teams and Channels | SAC-Library Team | 📚 CoDev (Collection …
       Teams and Channels | SAC-Library Team | 🌙 Good evening (Show …
     A chat, a channel, and a greeting card in a channel feed. The bare
     "Meeting" entry was nearly as bad: any channel or chat named
     "Meeting Notes" would do it too.
  🎯 STRICT NOW, AND DELIBERATELY SO. Patterns are ^-anchored to what a
     real meeting window STARTS with — Meeting in / Meeting with /
     Meeting | / Call with / Calling / Screen sharing — plus an
     exclusion list naming the main-window sections (Chat, Teams and
     Channels, Calendar, Activity, Files…) which is checked FIRST and
     wins outright.
  ⚖️ THIS WILL SOMETIMES MISS A REAL MEETING, and that is the correct
     way round. A miss costs one ⇪Q. A false positive mutes you
     mid-sentence and you find out from the silence — which is exactly
     what has been happening. When this feature is wrong, it should be
     wrong quietly.
  🔁 AND ⇪Q WAS BEING OVERRULED THREE SECONDS LATER. The file carried
     the comment "⇪Q is the override, so it must never argue with you",
     and then argued: turning Focus off by hand cleared the flag, and
     the very next detection tick found the same window and turned it
     straight back on.
       08:23:54 disengaged (manual ⇪Q)
       08:23:57 engaged (Microsoft Teams: Chat | …)
       08:24:00 disengaged (manual ⇪Q)
       08:24:01 engaged (Microsoft Teams: Chat | …)
     Three seconds, then one. That is not an override, it is a fight the
     person cannot win — and since the override exists precisely for
     when detection is wrong, failing then is the worst possible time.
  ⏳ A manual off now suppresses AUTO re-engagement for fm.manualOffSecs
     (15 minutes, tunable, 0 restores the old behaviour). Detection
     keeps running and the watchdog keeps its own clock; only the
     automatic engage is held off. Pressing ⇪Q ON engages instantly and
     CLEARS the suppression — it holds off the machine changing its
     mind, never the person changing theirs.
  🔍 _G.focusWindows() — RUN IT WHILE YOU ARE ACTUALLY IN A MEETING. It
     prints every Zoom and Teams window title open right now and, for
     each, whether the current rules would call it a meeting and exactly
     which pattern decided. The strict patterns above are informed
     guesses: Teams titles vary by build, by tenant, and by how a
     meeting was joined, and guessing confidently is what produced this
     bug. Rather than guess again, this prints the evidence.
  🧪 39 → 67 checks in test_focus. The false positives are written
     verbatim from the report, and the ⇪Q fight is reproduced as a
     sequence rather than asserted about. Six mutations caught: the
     original catch-all restored, a bare "Meeting" pattern, patterns
     unanchored, "Call with" unanchored, the exclusion pass deleted, and
     exclusions checked after the patterns instead of before.
  ⚖️ HONEST NOTE ON THE EXCLUSION LIST. With the patterns ^-anchored it
     is redundant BY CONSTRUCTION — a title starting "Chat |" cannot
     also start "Meeting in " — and a mutation run confirmed it:
     deleting the exclusion pass changed no result, which makes it an
     equivalent mutant rather than coverage. It is kept anyway, because
     the patterns WILL be loosened once real meeting titles come back
     from _G.focusWindows(), and the moment an anchor comes off,
     exclusions are the only thing standing between a channel and a
     muted microphone. So what the suite pins is the guarantee that
     survives that change: exclusions are checked first, and they win
     even against a pattern that matches.
  🏷 Stale ⇪F labels in this module corrected to ⇪Q — the key moved in
     6.48.0 and the header, the override note and the log line had all
     kept saying ⇪F, which is exactly the kind of thing that sends a
     non-coder pressing the wrong key during a meeting.

NEW IN 6.62.0 — TWO BUGS OFF LL's OWN CONSOLE, AND THE STUB THAT HID ONE:
  🎯 MOUSE GRID DIED THE MOMENT YOU TYPED, ON TWO SCREENS. Four times in
     one session:
       mouseGrid: typeChar: canvas.lua:382: bad argument #1 to
       'assignElement' (invalid element definition; must contain
       key-value pairs)
     typeChar filters cells by the typed prefix and then redraws EVERY
     screen's label canvas. On a multi-display setup the matches for a
     given letter can all live on ONE screen, and the other was handed
     replaceElements({}). hs.canvas only unwraps the single-table form
     when that table is NON-EMPTY:
       if elementList.n == 1 and #elementList[1] ~= 0 then ...
     so `{}` is not read as "draw nothing" — it is read as ONE element
     that happens to be empty, and an empty table has no key-value
     pairs. Hence the throw.
  💥 AND IT WAS WORSE THAN A LOG LINE. typeChar runs inside a pcall
     whose failure branch calls grid.hide("error"), so the throw did not
     merely complain — it TORE THE GRID DOWN. On a two-screen Mac,
     typing the first letter made the grid disappear. That is the
     symptom; the Console line was only the receipt for it.
  🧩 WHY THE EXISTING GUARD MISSED IT. typeChar already refuses a
     dead-end prefix, but the count it checks is of matches ACROSS ALL
     SCREENS. It is happily non-zero while an individual screen has
     none. The guard and the bug were looking at different things — a
     reminder that a check placed one level away from the failure is not
     the same as a check on the failure.
  🩹 THE FIX: a single setElements() helper that every label and grid
     draw goes through. When the element list is empty it substitutes
     one `action = "skip"` element — a valid definition that draws
     nothing, which is exactly what "this screen has no candidates"
     means. Built fresh on each call rather than shared, so no two
     canvases can ever hold the same table.
  🕳 THE REAL LESSON IS THE TEST STUB, NOT THE BUG. test_mouse_grid's
     canvas stub was, in full:
       function c:replaceElements(e) self.elements = e; return self end
     It accepted ANYTHING — including the precise empty table the real
     API rejects. So 265 checks, a 4,000-layout geometry fuzzer AND a
     random-action explorer with shrinking all ran green over a crash a
     real Mac hit within seconds of being used. A stub more permissive
     than the thing it stands in for does not merely fail to catch bugs;
     it MANUFACTURES confidence, which is worse than having no test.
     The stub now rejects what hs.canvas rejects, and with it in place
     the existing fuzzer failed on its own before a single new test had
     been written — the bug had been reachable by the suite all along.
  🗒 CAPTURE PAD: THE QUEUE AND THE PARKED LIST WERE ONE TABLE. Also
     straight off the boot log. The rawequal guard added in 6.44.10
     caught it and reset parked, and nothing was lost — the guard doing
     precisely its job, and worth noting it was written for a fault
     nobody had seen yet.
  🩹 BUT A SAFETY NET FIRING ON AN ORDINARY BOOT IS A BUG REPORT, NOT A
     RESTING STATE. The cause: load() ADOPTED the JSON decoder's own
     tables, which quietly assumes decode hands back a distinct table
     per key. It now takes its own copy, so the two lists are
     structurally incapable of being the same object no matter what the
     decoder does — and array shape is forced while we are there, so a
     JSON object cannot masquerade as a list. The rawequal guard stays
     as the second line; it just should not be the thing doing the work.
  🧪 386 checks in test_features, 269 in test_mouse_grid; 1,688 across
     sixteen Lua suites, 1,723 with the Capture Pad JavaScript. Both new cases
     were written from the Console lines themselves, and both were
     confirmed to FAIL against the old code before the fixes went in —
     the only evidence that a regression test is testing the regression.
  🔬 Mutations caught: the empty guard removed, redraw bypassing
     setElements, the skip element replaced by a bare empty table, the
     skip element made visible, load() adopting the decoder's tables
     again, asList returning its argument, and the rawequal guard
     removed. One mutation (asList dropping contents) crashes the suite
     rather than failing an assertion — still caught, since the runner
     reports a suite that does not finish, but recorded as the noisier
     kind of detection rather than counted as a clean one.

NEW IN 6.61.0 — THE LAST SILENT FAILURE IN APP MONITOR IS CLOSED:
  🔔 A WRONG SOUND NAME NOW TELLS YOU. This was the one thing still
     outstanding against rule 7 — flagged in 6.59.0, flagged again in
     6.60.0, declined both times because a sound was being chosen rather
     than a mechanism. hs.sound.getByName returns nil for a name that
     does not exist; the nil-check skipped it; you got a quieter, or
     entirely silent, popup and nothing anywhere said why. The names
     that fail are now reported, by name.
  🎚 TWO SEVERITIES, BECAUSE THEY ARE NOT THE SAME PROBLEM:
     · SOME names bad → a LEDGER LINE, visible in ⇪⇧D, no interruption.
       The popup still makes noise, so nothing is broken in the moment;
       it is a config mistake to find when you go looking. Alerting here
       would train you to dismiss the alert without reading it, which is
       how a safety net turns into furniture.
     · ALL names bad → an ON-SCREEN ALERT. This is the case that
       matters, and the reasoning is the whole point: a mute popup
       CANNOT DRAW YOU TO ITSELF, so if the sound is gone there is
       nothing else left to tell you. The alert names the exact
       spellings that failed so the fix is obvious, and carries a dedupe
       key so it says so once an hour rather than on every app close.
  ⏰ REPORTED AT LOGIN, NOT AT THE WORST MOMENT. Resolution moved into
     warm(), which the loader runs a couple of seconds after boot, off
     the load path. A broken sound list now surfaces while you are
     sitting at the machine — not on the night an app actually crashes,
     which is exactly when you need it to work and least want to be
     debugging it. The popup path still resolves on demand as a
     fallback, so sound works even if warm() never ran.
  💾 AND IT IS CACHED, so the ten lookups happen once rather than once
     per popup — the same reason they were never put on the 1s ping
     timer in the first place.
  🧪 44 checks in test_app_watcher. New cases: total silence alerts AND
     names the failures, a partly-broken list records instead of
     interrupting, three real closes still look up only once, a healthy
     list says NOTHING at all, warm() surfaces the problem at login, and
     a MISSING notice ledger still does not break the popup.
  🔬 THE MUTATION RUN FOUND TWO FAULTS IN THE TESTS THEMSELVES, both the
     same species as the bugs this suite exists to catch — a test that
     could not fail:
     · The first pass reported every mutation as "caught" because the
       mutations had broken the FILE, not the behaviour. An empty result
       read as a failure, so a syntax error scored as a win. There is a
       compile gate now: a mutant that will not parse is reported as
       INVALID rather than counted.
     · "Three closes report once" was quitting an already-quit app three
       times. The module only opens a popup for an app it believes is
       RUNNING, and only one popup is on screen at a time — so three
       quits were really one popup and the case measured nothing. It now
       relaunches and answers between closes. Only after that fix did
       the cache mutation actually fail, which is the point.
     All nine mutations caught afterwards, each verified to compile and
     to fail on an assertion rather than a crash.
  🧪 1,680 checks across sixteen Lua suites, plus 35 executed in the
     Capture Pad page JavaScript — 1,715 in total, read from the
     runner's output rather than added up by hand.
  ⚖️ ONE EQUIVALENT MUTANT, recorded rather than pretended away:
     removing the `if not _G.notices` guard changes nothing observable,
     because the whole report already sits inside a pcall. Two guards
     for one job. Kept anyway — the pcall protects the popup, the check
     states the intent — but it is not evidence of coverage and is not
     counted as such.

NEW IN 6.60.0 — THE APP MONITOR PING BECOMES A SEQUENCE, AND GETS TESTED:
  🔊 ONE SECOND, AND A DIFFERENT SOUND EVERY TIME. The waiting popup now
     pings every 1s instead of 2s, and each ping takes the next entry
     from a ten-name list: Hero, Glass, Sosumi, Submarine, Basso, Ping,
     Funk, Morse, Bottle, Blow. Ordered loudest-first so the opening
     seconds are the ones most likely to reach another room. Ten sounds
     at one second each is the ten seconds LL asked for.
  🔁 AND THEN IT WRAPS, RATHER THAN ENDING. This is the one real design
     decision in the change, and it is deliberate. The popup has waited
     INDEFINITELY since 6.16.21 — no auto-dismiss — precisely so that
     being away from the desk cannot let a closed app go unnoticed. A
     sound sequence that simply ran out after ten seconds would hand
     that failure straight back: the popup would still be there, but
     nothing would be calling you to it. So after ten seconds the list
     starts again, and the only thing that ever stops it is answering.
  🔉 WORTH KNOWING, SINCE IT IS A REAL TRADE: this is now a once-per-
     second sound that can run for hours if a Mac is left alone. Louder
     than the old 2s single ping by design. If it proves too much, the
     interval and the list are two separate constants at the top of
     modules/app_watcher.lua and either can be tuned without touching
     the other — a longer interval keeps the variety, a shorter list
     keeps the urgency.
  🧯 A MISSPELLED NAME NOW COSTS ONE SOUND, NOT ALL OF THEM. Every name
     is resolved once when the popup opens, and any that fail to resolve
     are dropped there rather than re-checked forever; the sequence
     closes the gap and carries on. The old single-constant version
     turned one typo into total silence.
  ⚠️ THE KNOWN GAP IS UNCHANGED AND STILL RECORDED: if EVERY name is
     wrong you get a silent popup and nothing explains why. That is the
     class of silent failure the notice ledger exists to abolish;
     app_watcher predates it and wiring it in was offered and declined.
     Now pinned by a test, so the behaviour is at least described rather
     than merely happening.
  ⏱ RESOLVED ONCE, NOT ON EVERY TICK. hs.sound.getByName goes out to the
     system. Calling it inside a one-second timer that may run for hours
     would be thousands of lookups for an answer that cannot change.
  🧪 AND THE PART THAT WAS MISSING: NOTHING IN THE SUITE HAD EVER
     EXECUTED THIS CODE. As one constant and one unconditional play()
     there was arguably nothing to test. As a resolve-and-filter loop
     plus a wrapping index there certainly is — an off-by-one that skips
     the first sound, a wrap that throws when the list runs out, and a
     resolution failure that takes the sequence down with it are all
     things this shape can now get wrong.
  🧪 tests/test_app_watcher DRIVES THE REAL MODULE through a stub hs —
     real setup(), real application-watcher callback, real timer
     function — rather than re-implementing the sequence and checking a
     copy of it. That distinction is not pedantry here: this config has
     already shipped a suite that passed while the real code was broken.
     27 checks: the first sound is immediate, ten seconds gives ten
     DIFFERENT sounds in the configured order, ping 11 wraps and ping 21
     wraps again, the interval is 1s, one bad name is survivable, and an
     entirely bad list fails silent rather than throwing.
  🔬 ALL SIX MUTATIONS CAUGHT: wrap removed, off-by-one on the index,
     interval reverted to 2s, a bad name aborting the whole list, the
     list reordered, and the initial pre-timer ping dropped.
  🧪 1,663 checks across sixteen Lua suites, plus 35 executed in the
     Capture Pad page JavaScript — 1,698 in total, counted from the
     runner's own output rather than added up by hand.
  🙈 AND ONE MORE INSTRUMENTATION BUG, LOGGED BECAUSE IT IS THE SAME
     FAMILY AS THE OTHERS: the first run of the new suite printed
     NOTHING and looked like a pass. The harness silences print() while
     the module runs, and swallowed its own output along with it. Test
     output goes through io.write now.

NEW IN 6.59.0 — TWO SMALL THINGS, BOTH OF THEM "IT WAS LYING TO YOU":
  🔊 APP MONITOR NOW SOUNDS "Hero" INSTEAD OF "Ping". Purely LL's
     choice, and the reasoning is worth keeping: since 6.16.21 the
     popup has had NO auto-dismiss — it waits indefinitely and pings
     every 2 seconds until answered — precisely so that being away
     from the desk cannot cause a closed app to go unnoticed. That
     design only works if the sound survives the distance. Ping does
     not always carry; Hero does.
  🎛 THE SETTING IS ONE CONSTANT, ON PURPOSE. appMonitorSoundName near
     the top of modules/app_watcher.lua feeds BOTH the initial alert
     and the repeating ping timer, so the two can never drift apart,
     and changing it again is a one-word edit plus a reload. The
     comment block above it now lists all fourteen built-in macOS
     sounds grouped by how much they carry, so the next change does
     not require going and looking them up.
  ⚠️ WHAT IS DELIBERATELY *NOT* FIXED HERE, RECORDED SO IT IS NOT
     FORGOTTEN: hs.sound.getByName is pcall-wrapped and its result is
     nil-checked, which means a MISSPELLED SOUND NAME PRODUCES NO
     SOUND AND NO ERROR — the popup still appears, silently, and
     nothing says why. That is exactly the class of silent failure the
     notice ledger exists to abolish; app_watcher predates it and was
     never wired in. Routing the miss into notices was offered for
     this release and declined in favour of the sound change alone.
     The constant's comment now warns about it in plain language
     ("if you change this and hear nothing, the spelling is the first
     suspect"), which is a smaller guarantee than the ledger but not
     nothing. Still outstanding.
  🩺 hs-doctor WAS CALLING A WORKING HYPER KEY "unexpected". Section 6
     tested for the Caps-Lock HID usage as the literal hex string
     0x700000039, but `hidutil property --get UserKeyMapping` returns
     DECIMAL on a real Mac — 30064771129, the same number written the
     other way. A correct remap therefore never matched, fell through
     to the error branch, and echoed the entire raw property list —
     once per HID device carrying the mapping, which in practice runs
     to a hundred-plus near-identical blocks scrolling past someone
     who has just been told something is wrong when nothing is.
  ✅ CONFIRMED AGAINST A REAL REPORT, not reasoned about: 30064771129
     = 0x700000039 (Caps Lock) and 30064771181 = 0x70000006D (F18) —
     exactly the remap this config installs. The diagnostic was wrong;
     the Mac was fine. Both forms are matched now, decimal first,
     since decimal is what actually appears.
  📉 AND THE ERROR BRANCH IS NOW READABLE. A genuinely wrong mapping
     prints the UNIQUE Src/Dst pairs rather than every repeated
     registry entry. A diagnostic that scrolls its own answer off the
     screen is not a diagnostic, and the repeat count is a property of
     how many HID devices are registered, not of the problem.
  🧪 Fixture-tested five ways before shipping: decimal mapping, hex
     mapping, empty output, "(null)", and a wrong mapping repeated
     four times (collapses to two lines). Full Lua suite green.

NEW IN 6.58.0 — THE INSTALLER CAUGHT WHAT THE TEST SUITE MISSED:
  🚨 REAL INSTALL, REAL FAILURE, WORKING SAFETY NET. Running
     hs-install.sh for real (not --dry-run) failed verification on
     "core/notices-not-an-initialiser" and rolled itself back
     automatically — exactly the job that check exists to do. Nothing
     on the Mac broke; it landed back on 6.54.0, untouched, with an
     explicit "do NOT reload" so there was never a moment of doubt
     about what state it was in.
  🔍 THE BUG: core/notices.lua was written as a bare `return notices`
     table and loaded with a bare `chunk()` — every one of the other
     four core/ files is `return function(core) ... end`, called as
     `chunk()(coreTable)`. It happened to run fine either way, because
     nothing inside notices.lua ever reads `core` — but "happens to
     run" and "matches the shape the installer promises to verify" are
     different claims, and the installer checks the second one on
     purpose. It refused rather than trust a file that merely worked.
  🩹 THE FIX: notices.lua now returns `function(core) ... end` like its
     siblings. Its call site in init.lua passes `{}` rather than the
     usual per-machine table, because notices loads BEFORE hostTag and
     logsDir exist as locals — deliberately, so it can report a module
     that fails to load. Moving the load point later to hand it real
     values would undo the reason it loads first. An honest empty table
     beats reordering fragile boot code to make one argument non-empty.
  🕳 THE GAP THIS EXPOSES: NOTHING IN THE TEST SUITE HAD EVER CHECKED
     THIS SHAPE. dofile()-ing a core file in a test does not care what
     it returns, so four releases shipped with this bug and every one
     of them passed the full suite. The installer's independent verify
     step was the only thing that ever looked. Closed now: an audit
     reads every file in core/ from DISK (not a retyped list — the same
     fix applied to the stale MODS list a few releases back) and checks
     it is `return function(core)`; a second pass reads init.lua's own
     load sites and checks each one calls its chunk with an argument.
     Verified by reverting notices.lua to the broken shape and by
     reverting init.lua's call site to a bare chunk() — the suite
     catches each independently.
  🧪 1,663 checks across sixteen Lua suites.

NEW IN 6.57.0 — THREE SHORTCUTS THAT WERE DYING SILENTLY, AND A LARGER PANEL:
  🚨 THE COLLISION test_integration NEVER CHECKED FOR. It loads all
     modules together and catches module-vs-module key clashes — but
     §0.4's hyper MIGRATION MAP lives in init.lua, outside that
     comparison, and three new modules had quietly claimed keys it
     already pointed somewhere else:
        ⇪F      focus_mode     vs   the FILE TRACKER (⌃⌥⇧F migrated)
        ⇪W      workspaces     vs   the SUMMON-AN-APP PICKER (⌃⌥W)
        ⇪⇧R     bulk_rename    vs   RESET NUDGE OFFSET (⌘⌃⌥⇧R)
     Each one printed a single "HYPER CONFLICT" line at boot and then
     silently killed the OLDER, working shortcut — "the later one wins"
     is correct Lua table semantics and the worst possible UX. Found
     from a real Console log, not from the suite.
  🔀 THE FIX, and a new test that makes the class impossible again:
        focus mode     → ⇪Q  ("Quiet") · ⇪⇧Q report
        workspaces     → ⇪⇧S ("Spaces")
        bulk rename    → undo moved OFF ⇪⇧R entirely, onto the picker's
                          own first row when there is a batch to undo —
                          the same pattern Workspaces already uses for
                          its reset, discovered rather than invented
     New code yields to what already works. test_diagnostics now reads
     §0.4's migration map and every module's hyperAddShortcut calls from
     the SAME source pass and fails if any two ever name the same chord
     — verified by reverting focus_mode to ⇪F and watching it catch it.
  📐 THE CHEAT SHEET IS 1024×768 BY DEFAULT, both configurable
     (cheatSheet.width / .height), both still clamped to the screen so
     neither can ever open larger than the display. Worth knowing which
     way the trade runs: WIDTH is free — a wider column means fewer
     entries wrap onto continuation lines, so 1024 shows MORE at once
     than 760 did — but HEIGHT is not: at 30pt a row, 768 shows roughly
     22 rows against the old ceiling's 36. The 86%-of-screen ceiling
     stayed, because a naive fixed clamp produced a panel covering 95%
     of a 1280×800 laptop screen, caught by the suite before shipping.
  🗓 THE HEADER DATE NOW TRACKS THE VERSION. It sat on 08-05-26 for a
     dozen releases while the version marker moved past it, so the one
     line a person reads first was quietly wrong — the same species of
     drift as this release's hyper-key bug, just in prose instead of
     code. Bumped every release from now on; asserted in the suite.
  🧪 1,655 checks. Also fixed in passing: the audit's own MODULE list
     had drifted to 18 of 26 files and was silently covering barely two
     thirds of the config — replaced with a read of init.lua's actual
     default profile, the same source test_integration already trusts.

NEW IN 6.56.0 — THE PHANTOM PANEL, AND WHY IT WAS NOT OUR CRASH:
  👻 REPORTED FROM A REAL MAC: pressing ⇪/ while Safari's address-bar
     autocomplete was open threw
        NSInternalInconsistencyException: '<NSRemoteView …
        SPCompletionListServiceViewController> notified of
        <HSCanvasWindow> but expected (null)'
     — and left a panel on screen that would not close, with the
     Console filling for minutes with alternating "Disabled / Re-enabled
     previous hotkey UP DOWN HOME END PAGEUP PAGEDOWN ESCAPE".
  🔍 THE THROW IS NOT OURS AND CANNOT BE PREVENTED. Ordering ANY window
     on screen makes AppKit post a notification that every observer
     receives — including Safari's completion list, which lives in
     ANOTHER PROCESS behind an NSRemoteView. If that view is
     mid-transition when the notification lands, its own assertion fires,
     inside Safari, about a window Safari does not own. No argument to
     :show() avoids it.
  🚨 WHAT WAS OURS WAS THE DAMAGE, and the damage was the whole symptom.
     canvas:show() was UNPROTECTED, so the throw abandoned the rest of
     the open sequence: _G.cheatSheetCanvas had already been set, and
     enableInput() never ran. The config then believed the sheet was
     open while the canvas sat half-ordered on screen — a panel you
     could see, could not scroll, and could not close, because every
     later ⇪/ took the hide() branch. Those are exactly the alternating
     hotkey lines. The phantom panel was not the exception; it was
     everything after the exception not happening.
  🩹 THE FIX, at all three canvas:show() sites: catch it, RETRY ONCE on
     the next run loop turn — this is a timing collision with another
     process, not a permanent state, so a moment later it works — and if
     it still refuses, say so through the 6.54.0 notice ledger instead
     of leaving a ghost behind. enableInput() now runs either way, so
     ⇪/ is never left toggling a panel you cannot use.
  🧪 REPRODUCED IN THE SUITE. The cheat sheet's canvas stub can now be
     told to throw exactly as AppKit did, and the test asserts the
     exception does not escape into the hotkey callback, that the input
     keys are still bound afterwards, and that the sheet reopens
     cleanly. Restoring the unprotected show() fails it.
  🧪 1,644 checks across sixteen Lua suites.

NEW IN 6.55.0 — CLIPBOARD HISTORY BECOMES A MODULE:
  📋 IT LIVED IN init.lua, IN FOUR SEPARATE PLACES: the file path in
     §0.2, load and save in §2, the dedupe buried inside the pasteboard
     watcher in §3, and two choosers in §5. Every one of those lines ran
     BEFORE the module loader — the stretch where a single error takes
     the WHOLE config down instead of costing you one feature. It is now
     modules/clipboard_history.lua, on ⇪V and ⇪⇧V. init.lua lost 190
     lines and clipboard history gained somewhere to be tested.
  🔗 ONE PIECE STAYED BEHIND, DELIBERATELY. The pasteboard watcher is
     SHARED with image OCR: one timer, one changeCount, choosing between
     copied image files, a raw image and text. Splitting it would mean
     two timers polling the same counter and racing over which handled a
     change first. So the watcher stays and calls clipboard.add through
     the service registry — and if the module is ever switched off, it
     gets no provider, says so once, and OCR carries on.
  🚨 AND THE MOVE INTRODUCED A DATA-LOSS BUG, WHICH THE NEW TESTS CAUGHT
     BEFORE IT SHIPPED. Reading the file was deferred to warm() to keep
     a possible megabyte off the boot path — correct on its own, but it
     opened a two-second window in which a copy would call save() and
     write a ONE-ITEM file straight over the real history. warm() would
     then dutifully load that back, having destroyed everything. Copies
     made before the file is in are now HELD and re-applied on top of it
     afterwards, and nothing is written until the file has been read.
     That property is exactly why the move needed its own suite rather
     than being done quickly.
  🧪 THE SOURCE AUDIT BECAME A REAL TEST. 6.52.0 could only check from
     SOURCE that an edit copies to the clipboard and that the cache is
     written before the pasteboard, because the code sat in init.lua
     with nothing to drive it. The module can be run, so those are now
     assertions about behaviour — including the one that matters most:
     the watcher waking on our own write does NOT add a second row,
     because the dedupe lifts the edited entry instead of copying it.
  🧪 The stub had to learn to fail properly, too. hs.json.decode RAISES
     on malformed input; the first version of the test's stand-in
     quietly returned an empty table, so the "unreadable file is backed
     up" branch was never reached and a working guard looked untested
     when it was merely unexercised.
  🧪 1,641 checks across sixteen Lua suites.

NEW IN 6.54.0 — NOTHING FAILS SILENTLY: THE NOTICE LEDGER (7g/7d/7e/6):
  🔔 ONE LEDGER, AND SURFACES THAT READ FROM IT. Every failure — a module
     that would not load, a runtime error, a failed shell hook — records
     into core/notices.lua, and that file alone decides whether, how and
     when you are told. Twenty-five modules each calling hs.notify would
     be twenty-five slightly different behaviours, twenty-five chances to
     forget, and nowhere that knows whether you have already been told.
     Add a surface later and every existing failure flows into it free.
  🔕 AND THE UNCOMFORTABLE PART, which is why 7d was needed at all: FOCUS
     MODE TURNS DO NOT DISTURB ON DURING MEETINGS, and macOS then
     SWALLOWS notifications WITHOUT REFUSING THEM. A hs.notify that
     "succeeded" can have shown you nothing, so a failure during a
     meeting could vanish entirely. Notices raised while Focus is on are
     now HELD and delivered when it ends — as ONE combined message, since
     coming out of a meeting to twelve stacked alerts is its own kind of
     failure. The queue is bounded and drops the OLDEST, because the
     recent ones are the ones still true when you get back.
     · WHAT CAN HONESTLY BE KNOWN about Focus: macOS has no public API.
       Two things are reliable — whether THIS config turned Focus on
       (exact, we did it), and the Do Not Disturb assertions file. When
       neither is conclusive it assumes NOT suppressed and shows you.
       That direction is deliberate: a notice shown during Focus is a
       mild annoyance, a notice silently swallowed is the whole bug.
     · hs.alert IS ALWAYS USED AS WELL, not as a nicety. Notification
       Centre can be switched off for Hammerspoon entirely and nothing
       tells us; hs.alert draws on the screen and obeys neither that nor
       Focus. It is what makes the guarantee true rather than hopeful.
  🆗 ONE SIGNAL AT LOGIN, AND ONLY WHEN IT MEANS SOMETHING. A clean boot
     gets a brief "ready" flash — the FadeLogo idea, natively, no Spoon —
     so a quiet Mac is never ambiguous between "fine" and "never
     started". A module that failed to load gets an alert NAMING it, and
     shown even during Focus, because a tool that did not load is wrong
     for the whole session. Silence means it worked; you are never asked
     to go and check.
     · ON A TIMER, NOT INLINE: an alert fired during the boot chunk can
       land before the screen is ready at login and simply not be seen,
       which would make the mechanism a lie on the one boot you most
       care about.
  🚨 THE LEDGER IS ITSELF A BOOT-PATH RISK, and is written accordingly.
     It reports other failures, so if it throws it takes the config down
     AND removes the explanation. Every macOS call is pcall'd, both
     queues are bounded, every entry point tolerates nil — and if
     core/notices.lua fails to load, THAT is announced on screen rather
     than leaving reporting quietly off.
  🩹 AND THE SUITE CAUGHT THE HALF-UPDATED INSTALL. Adding a fifth core/
     file failed four checks immediately: hs-install.sh would not have
     COPIED it (both loops name the files explicitly), and its count and
     INSTALL.md's still said four. That is the exact failure hs-doctor
     exists to catch, caught before shipping instead.
  🧪 1,603 checks across fourteen Lua suites. test_notices asserts a
     notice is never lost, never floods, that unknown Focus state means
     SHOW rather than hide, and that a clean boot stays quiet — each
     mutation-checked.

NEW IN 6.53.0 — THE CRITICAL-STOP PASS: TWO WAYS THE WHOLE CONFIG DIED:
  🚨 A BAD KEY NAME TOOK EVERYTHING DOWN. hs.hotkey.bind THROWS on a key
     macOS has no code for — a typo in an ✏️ EDIT HERE block, "esc " with
     a trailing space. A MODULE's bad key was always survivable, because
     §1.12 runs every setup() inside its own pcall. init.lua's OWN binds
     are not so lucky: they sit at top level in the 3,077 lines that run
     BEFORE the loader, so one typo meant no hotkeys, no modules, no
     cheat sheet, and the reason visible only in a Console you were not
     looking at. The sentry now catches the throw, NAMES the key, counts
     it, and hands back the same inert stub the migration path already
     returns — so that one shortcut is off and everything else boots.
     Returning nil was not an option: it only moves the crash to the
     caller's :enable() one line later.
  🚨 ERROR REPORTING DEPENDED ON A FILE THAT CAN FAIL. A Lua error inside
     a timer, an HTTP reply or a watcher CANNOT be caught by a pcall in
     whatever scheduled it — hs.uncaughtErrorHandler is the only place it
     can be seen at all. It was installed ONLY by core/diagnostics.lua,
     which loads a thousand lines into boot and is correctly pcall'd so a
     broken copy cannot stop the config. Two silent windows followed:
     every line before that file loads, and THE ENTIRE SESSION if it
     failed to load — which is precisely when you most need reporting,
     and nothing announced the loss. The earliest possible handler is now
     installed in init.lua itself, and the stand-in diag's err() RECORDS
     instead of being the no-op it was. core/diagnostics.lua still
     upgrades both, and preserves the error list, so anything caught
     during early boot still reaches ⇪⇧D.
  ✅ WHAT THE PASS CLEARED. All four core/ files load inside pcall. warm()
     is pcall'd, so a slow module cannot strand boot. 111 of 200 local
     slots free, so init.lua is not near the compile limit that would
     kill it outright. The only hs.execute calls — a LOGIN shell, which
     blocks — are in update_tracker's warm() and never on the boot path;
     setup() uses cheap io.open probes.
  🧪 TWO ROUNDS OF MY OWN TEST BUGS, both the same shape as the code bug.
     The first audit searched init.lua raw and failed on its own
     documentation: the comment explaining the fix names both
     "core/diagnostics.lua" and the old `err = function() end`, so the
     PROSE was mistaken for the code — the exact trap this suite warns
     about at the top. And the sentry audit's first draft passed with the
     guard removed, because "does pcall appear" and "does the stub
     appear" were both already true of the migration branch beside it;
     what actually distinguishes the fixed file is the ABSENCE of a bare
     `return hsHotkeyBindOriginal(...)`. Restoring the bug now fails four
     assertions instead of one.
  🧪 1,566 checks across thirteen Lua suites.

NEW IN 6.52.0 — TWO FIXES FOUND BY AUDITING init.lua:
  📋 AN EDITED CLIPBOARD ENTRY IS NOW COPIED. You edit an entry because
     you want to paste it, and the edit updated the stored history
     without touching the pasteboard — so you had to go and copy it
     again. Deleting still copies nothing, which is the asked-for split.
     · NO DUPLICATE APPEARS, and the reason is worth recording. Setting
       the pasteboard wakes the clipboard watcher, which would normally
       file a brand new entry and leave the same text twice — once
       edited in place, once fresh at the top. It does not, because the
       watcher's dedupe pass first REMOVES every entry matching the text
       that just arrived, and this entry now carries exactly that text,
       so it is LIFTED to the front instead of copied. That makes the
       ORDER load-bearing: the cache must hold the new text before the
       pasteboard does, and a test asserts that ordering specifically.
  🖥 THE CAPTURE PAD NOW OPENS OVER FULL-SCREEN APPS. It worked
     "sometimes", and the sometimes was: which Hammerspoon window you
     happened to open. LEVEL AND COLLECTION BEHAVIOUR ARE DIFFERENT
     THINGS. Level decides z-order WITHIN a Space, and bringToFront(true)
     already handled that — but a full-screen app is its OWN Space, and
     whether a window may appear over one is governed entirely by
     fullScreenAuxiliary. Every canvas popup here has set that since
     6.20. The webview never did, so it was left behind on the desktop
     Space, which looks exactly like "it opened but nothing appeared".
  🧪 THE TEST STUB WAS PART OF THE BUG CLASS. capture_pad's call is
     pcall'd, so when the webview stub lacked behaviorAsLabels the call
     failed silently and any assertion would have passed while the real
     module did nothing. The stub gained the method and a comment saying
     why it is load-bearing. Both fixes were mutation-checked by removing
     them and watching the tests fail.
  🔍 AND THE AUDIT ITSELF, which prompted both: 3,077 of init.lua's
     3,553 lines run BEFORE the module loader. Anything that throws in
     that stretch takes the WHOLE config down rather than one feature —
     so that is where fragility actually lives, and roughly 1,830 of
     those lines (§3.12 hyper key 838, §6 Asana 387, §2 OCR/clipboard
     341, §5 hotkey glue 263) are movable. Recorded here as the map for
     the next release rather than done in a hurry alongside two fixes.

NEW IN 6.51.0 — WORKSPACES (⇪W): NAME A SET OF APPS, BIND IT TO A SPACE:
  🗂 ⇪W asks which workspace this Space should be, remembers the answer,
     and sets it up: run onStart, open the apps, WAIT FOR THEM TO ACTUALLY
     APPEAR, then run onComplete. Press ⇪W on that Space again and the
     first row offers to re-apply what is already assigned.
     The format is the one that was asked for, unchanged:
        ws.workspaces = {
            DevWork = {
                onStart      = "~/.something/command.sh",
                Applications = { ["Google Chrome"] = {} },
                onComplete   = "~/.something/command.sh",
            },
        }
     ⚠️ THOSE COMMAS ARE NOT OPTIONAL. Lua separates table fields with
     `,` or `;`, so the version without them is a SYNTAX ERROR and the
     module will not load at all. Worth saying because the layout reads
     perfectly well without them. The `{}` after each app is where
     per-app options go; `{ zone = "leftHalf" }` places its window using
     the same zone names the numpad layer uses.
  ⏱ onComplete MEANS "THE APPS ARE UP", so it waits for them rather than
     firing straight after launchOrFocus, which would be a lie. It polls
     until every app answers or the budget runs out, then runs anyway —
     an app that never starts must not strand the workspace.
  🚨 THE FLAG THAT MUST NEVER STICK. ws.busy is the one-apply-at-a-time
     guard, so a failing step that leaves it set kills the feature until
     a reload with nothing saying why — the same failure shape as Focus
     Mode leaving the mic muted. Every exit goes through one finish()
     that clears it, a hook that never exits is TERMINATED after
     ws.hookTimeout, and 300 generated workspaces mixing failing
     launches, failing hooks and hooks that hang assert it always clears.
  🗺 SPACE IDs ARE NOT STABLE ACROSS LOGOUTS, which leaks straight into
     this feature: yesterday's saved binding can point at a Space that is
     now somebody else entirely. So the store is PRUNED against the
     Spaces that actually exist every time it is read, and a dead ID is
     dropped rather than guessed at — applying the wrong workspace to the
     wrong desktop is worse than forgetting. But an EMPTY answer from the
     API does not wipe the store: "told us nothing" is not "all gone".
     With no hs.spaces at all it degrades to one workspace for the Mac
     and says so once.
  🅿️ ⇪⇧W WAS ALREADY TAKEN by the Document Watcher, and quietly stealing
     a working shortcut is not a trade worth making silently. So reset
     lives on the FIRST ROW of the ⇪W picker whenever the Space already
     has a workspace, and is published as workspace.reset for one of the
     free number-pad keys:  numpad.actions["pad+"] = "workspace.reset"
  🐛 THE SUITE FOUND A REAL BUG ON ITS FIRST RUN: validate() recorded
     "Applications must be a table" and then iterated it anyway, so the
     validator CRASHED on exactly the input it had just caught — the one
     thing a validator must not do. Guarded and tested.
  🧪 1,545 checks across thirteen Lua suites. The explorer also caught a
     fault in its own clock budget: when BOTH hooks hang the chain needs
     two full timeouts to unwind, and advancing only one stopped the
     clock mid-chain and reported a working module as stuck.

NEW IN 6.50.0 — THE PAD SWAPS LAYERS, AND A POINTER RING:
  🔀 TOOLS MOVED TO THE PRIMARY HYPER KEY. 6.49.0 put windows on ⇪ + pad
     and tools on ⇪⇧ + pad. That was the wrong trade and it is now the
     other way round:
        ⇪  + pad  →  TOOLS    focus, rename, grid, menu bar, links
        ⇪⇧ + pad  →  WINDOWS  the 3×3 position map
     The argument for the old order was that the window map deserved the
     easier layer because it needs no memory. But the layer you press
     twenty times a day should be the one without the extra modifier, and
     that is the tools. The window map loses nothing by moving up one
     modifier: its mnemonic is spatial — the key's position is the
     window's position — not a fact about which modifiers are held.
  🆓 SIX KEYS LEFT DELIBERATELY FREE on the tool layer — pad+ pad- pad*
     pad/ padenter padclear — as the room for whatever comes next, with
     a test asserting they stay unclaimed so the reserve does not quietly
     get eaten.
  🖱 THE MouseCircle SPOON, DONE NATIVELY. A ring flashes at the pointer
     so you can find it on a wide desktop. Implemented as ~20 lines in
     mouse_grid.lua rather than by adding SpoonInstall, which would mean
     a second loading system running alongside the module loader, and a
     network fetch on the boot path, for one circle. Same result, in
     rebeccapurple as asked.
     · 🅿️ BOUND TO NO KEY ON PURPOSE. macOS shake-to-grow already does
       this, which is exactly why you had the Spoon disabled. It is
       published as mouseGrid.locate, so it goes on a free pad key the
       day you want it: numpad.actions["pad+"] = "mouseGrid.locate".
     · Note the Spoon bound it to hyper+M, which in this config is
       already Menu Bar Items — one more reason it did not simply drop in.
     · The ring is CLICK-THROUGH. Without that it is a disc of glass over
       whatever you were reaching for, for half a second. And a second
       press REPLACES the first ring rather than stacking canvases that
       each delete on their own schedule, which is how this leaks. Both
       are tested, and the leak guard was mutation-checked by removing it
       and watching the test fail.
  🧪 1,496 checks. The swap broke six existing assertions, which is what
     they were for — they encoded which layer was which. They now encode
     the new arrangement, including that the arithmetic keys moved to the
     window layer and that the tool layer's six free slots stay free.

NEW IN 6.49.0 — THE NUMBER PAD, SWITCHED ON, WITH TWO LAYERS:
  🔢 THE PAD IS LIVE. It shipped PARKED in 6.44.0 — a worked-out layout
     bound to nothing — and it is now on, with a second layer added:
        ⇪  + pad  →  WINDOWS   (the key's position IS the window's)
        ⇪⇧ + pad  →  TOOLS     (focus, rename, grid, menu bar, links)
     That is ~28 live shortcuts that cost ZERO letters on the main
     keyboard, because the pad sends its own key codes: pad7 is not 7,
     and ⇪pad7 is not ⇪⇧pad7.
  🪟 WINDOWS STAYED ON THE UNSHIFTED LAYER, deliberately. Its mnemonic is
     the best thing in that module — pad7 is the top-left quarter because
     7 IS the top-left key — and there is nothing to memorise. Burying it
     under a modifier to make room for tools would have traded the one
     layout that needs no memory for one that does. Tools took the
     shifted layer instead.
  🔌 THE TOOL LAYER BINDS BY SERVICE NAME, NOT BY FUNCTION. numpad_layer
     knows nothing about focus mode or renaming; it calls "focus.toggle"
     and the dispatcher resolves it. A pad key whose module is switched
     off on this Mac prints "no provider" instead of erroring. Four
     modules gained the entry-point service they had been missing —
     focus.toggle, rename.show, rename.undo, menuBar.show,
     url.cleanClipboard — because they had published only QUERIES
     (report, list, plan) and nothing a key could actually press.
  🚨 WHICH CREATED A NEW FAILURE MODE, SO IT GOT A NEW TEST. A typo in a
     service name — "focus.tggle" — binds perfectly, does nothing when
     pressed, and prints to a Console nobody is reading. The check that
     every shifted binding resolves to a real provider had to go in
     test_integration.lua and NOWHERE ELSE: every other suite loads one
     module at a time against stubs, so the registry is empty there and
     the same check would have passed vacuously while proving nothing.
     Verified by planting the typo and watching it fail.
  ✏️ ONE ECHO ACROSS THE LAYERS, on purpose: pad. undoes on both. ⇪pad.
     puts a window back where it was, ⇪⇧pad. undoes the last rename.
     The tool rows are grouped by row (meetings · pickers · clipboard)
     rather than pretending to a spatial logic they do not have.
  🧪 1,483 checks. Turning the layer on broke nine existing tests, which
     is exactly what they were for — they asserted it ships parked. They
     now assert the live two-layer contract, that parking is still
     reachable, and that the nil-key guard covers the shifted layer too.

NEW IN 6.48.0 — FOCUS MODE (⇪F) AND BULK RENAME (⇪R):
  🎯 FOCUS MODE. A Zoom or Teams MEETING WINDOW — not merely the app
     being open — mutes the mic, turns the camera off if it is provably
     on, runs your Do Not Disturb Shortcut, and dims every app that is
     not the meeting. Leaving puts back exactly what it changed.
     · IT CANNOT REVOKE CAMERA ACCESS. No macOS API exists. What it does
       instead is READ the meeting app's own menu: "Stop Video" present
       means the camera is on, so clicking it is deterministic. If only
       "Start Video" is there the camera is already off and it does
       NOTHING. Firing ⌘⇧V blindly is a coin flip that switches the
       camera ON half the time, which is worse than doing nothing.
       Teams exposes no readable camera menu, so Teams gets a muted mic
       and its camera left alone — stated rather than faked.
     · OUTLOOK'S CALENDAR IS NOT READ, deliberately. Classic Outlook had
       AppleScript; the rewritten one largely dropped it, and a detector
       that works on one build and silently fails on the next is worse
       than none. It watches the REMINDER WINDOW for a join link, which
       works on both builds and fires exactly when you care.
     · THE FAILURE THAT MATTERS IS A MIC LEFT MUTED, so the design is
       built around restoring rather than detecting: prior state is
       recorded BEFORE any change and a mic you muted yourself is never
       unmuted; every restore step is independently pcall'd and the mic
       goes first; a watchdog disengages on its own if detection dies.
  ✏️ BULK RENAME. Select files in Finder, ⇪R, pick a rule, check the
     preview, ⏎. ⇪⇧R undoes the batch and survives a restart.
     · SUBTITLES MOVE WITH THEIR VIDEO, BY CONSTRUCTION. A player finds
       captions by filename, so renaming a .mp4 and not its .srt does
       not leave a stray file — it silently kills subtitles. Rules
       rewrite the GROUP stem and extensions are reattached, so there is
       no code path that can separate them. It knows the tails that
       break naive matching too: film.en.srt, film.forced.srt.
     · IT REFUSES RATHER THAN OVERWRITES. os.rename destroys the target
       with no warning and no undo, and a bulk rename is exactly where
       two names collapse into one. Any collision aborts the WHOLE
       batch — a half-renamed folder is worse than an unrenamed one —
       and renames run in two phases through temporaries so a swap or a
       rotation works instead of eating a file.
     · The `tv` rule fixes the season that prompted this: eight episodes
       named .1080p.ATVP-[y2flix.cc] and one named .108 all become
       Dark.Matter.2024.S01E01 and siblings, subtitles included.
  🚨 THE SUITE CAUGHT TWO REAL BUGS IN THIS RELEASE BEFORE IT SHIPPED:
     · order = 13.10 IS order = 13.1 IN LUA. Trailing zeros do not
       survive, and 13.1 is the Capture Pad — so the obvious "next
       number after 13.9" was a silent cheat-sheet tie whose running
       order then depended on table iteration. Both new modules moved to
       14.x. This is why the integration suite loads all 24 modules
       together instead of testing each alone.
     · INSTALL.md's module count is asserted against disk, so 22-vs-24
       failed two suites rather than shipping a doc that lies.
  🧪 1,479 checks across twelve Lua suites. The two new ones are
     property-based: 400 random messy folders assert that no file is
     lost, no clean plan collides, every subtitle stays with its video
     and every batch undoes exactly; 500 random meeting days assert the
     mic is never stranded and never unmuted against the user's wishes.
     Three mutations were too weak to fire and had to be rewritten —
     one grouped by a rule that changed nothing, one probed a teardown
     that already guarded itself and was aimed at a step that runs
     first anyway.

NEW IN 6.47.1 — THE EXPLORER TURNED ON THE THREE NEWEST TOOLS:
  🔎 The random-sequence explorer built for the Mouse Grid now runs
     against the URL Cleaner, the Health Monitor and Menu Bar Items.
     Four findings came back. NONE was a bug in the shipped modules —
     three were faults in my own test instrumentation and one was a
     deliberate design decision the property had stated too broadly.
     That is worth recording rather than quietly fixing, because it is
     what property testing actually feels like: the properties are
     harder to state correctly than the code is to write.
  🔗 URL CLEANER, 8,000 generated URLs. Properties: never throws,
     IDEMPOTENT (cleaning a clean URL is a no-op), still a URL,
     wrapping cannot change the answer, every non-tracker survives,
     every tracker goes, the fragment is untouched.
     → Finding: it refused to unwrap a generic ?url= pointing at its
       OWN host. That is correct and now has its own test:
       example.com/login?url=example.com/dashboard is a login return
       path, not a redirect, and rewriting it sends you somewhere you
       did not ask to go. The fuzzer had generated an unrealistic
       input and asserted a naive substring match.
  🩺 HEALTH MONITOR, 600 random timelines / 36,000 events — files
     going quiet and coming back, midnight mid-outage, the lid shutting
     during a fault, modules failing and recovering, interleaved.
     → Finding: a module that FAILED TO LOAD is announced during the
       boot grace period. Deliberate: the grace period exists because
       module files do not exist yet, which says nothing about load
       status, and a certain fault should not wait twenty minutes.
     → Two of mine: the property read the clock BEFORE the action that
       changed it, and the harness let the simulated date run backward
       between timelines, visiting one calendar day twice.
     → And it added a rule nothing had checked: load failures obey the
       once-per-day limit too.
  📊 MENU BAR ITEMS, 500 random Mac populations — up to 30 apps mixing
     healthy, silent, wedged and action-refusing. The property that
     matters is that the scan returns inside its budget however bad the
     population, because that budget is your keyboard.
  🧬 EVERY PROPERTY WAS THEN MUTATION-TESTED, because a property that
     cannot fail is decoration. Breaking idempotence, the parameter
     blocklist, the once-per-day guard, the active-hours guard and the
     scan budget each fails the suite by name. Two of my first attempts
     at those mutations were too narrow to fire and had to be rewritten.
  🧪 1,410 checks across eleven suites.
  🩹 THE SHIP CHECK THEN FOUND TWO THINGS THE SUITES CANNOT SEE, both
     in what travels ALONGSIDE the code rather than in the code:
     · hs-doctor.sh's "is each module current?" markers stopped at
       6.44.4, so the four newest tools had no staleness check at all.
       Added, and menubar_items is checked for mb.axTimeout specifically
       — a copy without it is not merely old, it is the version that can
       hold the keyboard while a wedged app fails to answer.
     · GUIDE.md still said 6.44.0, "18 modules", and "five suites, 593
       checks". It now says 22, eleven and 1,410, documents core/ and
       tools/, explains why loader_test.lua is not a suite and errors if
       you run it, and stops listing §1.6 and §1.11 as work to do — they
       moved to core/ in 6.46.1. Headroom re-measured: 111 free locals,
       not 116.
     · hs-install.sh shipped WITHOUT its executable bit while the other
       two tools had theirs. Not broken — INSTALL.md invokes it as
       `sh …/hs-install.sh` throughout — but `./tools/hs-install.sh` is
       the obvious thing to type after `./tools/run-tests.sh`, and it
       answered "Permission denied". All three are 755 now.
     None is a runtime change, so the version stays 6.47.1. A manual
     three versions out of date is still a defect you ship.
  📦 THE ZIP IS VERIFIED BY EXTRACTING IT, not by trusting the file
     list: unpacked to an empty directory, its own tools/run-tests.sh
     runs all 1,410 checks green with nothing else present. That is what
     proves the archive is complete rather than merely large.

NEW IN 6.47.0 — MENU BAR ITEMS (⇪M), AND WHY IT IS NOT BARTENDER:
  🚫 THE HONEST PART FIRST. Bartender's central trick — HIDING other
     apps' menu bar icons — CANNOT be done in Hammerspoon, and the
     reason is not a gap in Hammerspoon. A menu bar icon is an
     NSStatusItem owned by the app that made it; macOS exposes no
     public API for one process to hide, move or reorder another
     process's status item. There is nothing to call. Bartender works
     around it by covering the real bar and drawing its own copies of
     the icons, which is why it needs SCREEN RECORDING — it has to
     photograph the menu bar, because it cannot ask for the images
     either. Hammerspoon could draw a black strip and nothing more.
  ✅ FOR REAL HIDING, USE ICE — free, open source, actively maintained:
     https://github.com/jordanbaird/Ice. It coexists fine with this.
  ⌨️ WHAT IS REACHABLE is the half that suits a keyboard-driven setup
     better anyway. ⇪M lists every status icon by owning app; type a
     few letters and press ⏎ to open it. No aiming at a 22-pixel glyph
     you cannot identify. ⇪⇧M prints an inventory. Accessibility only —
     no Screen Recording, nothing covered, nothing moved.
  🚨 ITS WORST FAILURE WOULD BE A FREEZE, NOT A CRASH. Reading another
     app's Accessibility tree is a SYNCHRONOUS call into that app, and
     Hammerspoon's main thread is your keyboard. Fifty apps with no
     timeout is a plausible way to lose the Mac for a minute — 6.33.0's
     ⌥Tab froze for exactly this reason. So every app element gets an
     explicit 0.1s timeout BEFORE it is asked anything, the whole scan
     is time-boxed at 2s and checked every iteration, and results are
     cached. The suite drives forty deliberately wedged apps and fails
     if the scan does not give up.
  🐛 One of mine, caught by the tests: pcall(function() el:performAction
     (a) end) DISCARDS the return value, so the success check never saw
     it and AXShowMenu fired straight after a perfectly good AXPress —
     activating every item twice. The `return` inside the wrapper is
     load-bearing.
  🧪 1,405 checks across eleven suites.

NEW IN 6.46.1 — init.lua GOES BACK TO BEING AN ORCHESTRATOR:
  📉 3,735 LINES → 3,511, AND NOT ONE LINE OF CODE WAS TOUCHED. 6.44.11
     cut this file from 6,012 to 3,376 by moving history out; within a
     few releases it was back to TWELVE inline changelog entries against
     a stated rule of five. Bloat creeps back about fifty lines a
     release and nobody notices, because each release only adds a little.
  🚨 AND IT NEARLY COST THREE VERSIONS OF HISTORY. 6.44.11, 6.44.12 and
     6.44.13 existed ONLY in this header — they were never backfilled
     into CHANGELOG.md. Trimming on the assumption that CHANGELOG.md was
     complete would have deleted them silently. They were moved across
     FIRST; CHANGELOG.md now holds all 114 versions.
  🧬 A TEST NOW ENFORCES BOTH HALVES, because a convention nothing checks
     is a convention that decays: at most five entries inline, and
     nothing inline that CHANGELOG.md is missing. The second is the one
     that matters — it makes losing history by trimming impossible.
  📐 AND THE ARCHITECTURAL CLAIM IS NOW TESTED RATHER THAN ASSERTED. A
     new tool costs init.lua its NAME in three profiles and nothing
     else. Across the whole of 6.45.0 → 6.46.0, three new tools added
     1,867 lines of module code and exactly NINE lines to init.lua.
     The suite fails if a module name ever appears here as code.
  🧪 1,358 checks across ten suites.

NEW IN 6.46.0 — A LINK CLEANER, A TOOL-HEALTH WATCHDOG, AND ⇪M → ⇪X:
  🎯 THE MOUSE GRID MOVED TO ⇪X. ⇪X opens it, ⇪⇧X clicks on arrival,
     ⌃⌥⌘⇧X is the panic key. Nothing else about it changed.
  🔗 NEW: modules/url_cleaner.lua. ⇪K rewrites the link on your
     clipboard into the one the sender actually meant — tracking
     parameters stripped, redirect wrappers unwrapped. ⇪⇧K undoes it.
     Works on a whole paragraph, cleaning every link in it.
  📧 THE WORK-INBOX CASES ARE THE POINT. Outlook Safe Links wraps
     almost every link in almost every corporate email; Proofpoint
     wraps the rest, and uses its OWN encoding where "-" means "%" and
     "_" means "/" — decode that as ordinary percent-encoding and you
     get a dead link. Both are handled, including one wrapper nested
     inside another, with a BOUNDED unwrap loop.
  🚫 IT WILL NOT EXPAND bit.ly & co, AND THAT IS THE DESIGN. A
     shortener does not contain its destination; the only way to learn
     it is to ask their server, which REGISTERS THE CLICK you were
     trying to avoid and sends a work link to a third-party host. The
     module makes NO network calls at all — a test fails the build if
     one ever appears — and says plainly why it stopped.
  🛟 BLOCKLIST, NEVER ALLOWLIST. Only known trackers are removed;
     anything unrecognised is kept. ?v= on YouTube, ?q= on a search,
     ?ref= on GitHub and ?page= everywhere are load-bearing. A cleaner
     that leaves a stray parameter is a nuisance; one that breaks the
     link is worse than not having it.
  🩺 NEW: modules/health_monitor.lua. The boot report says what LOADED.
     The capability report says what this Mac CAN do. Neither notices a
     module that loaded fine, reports no error, and stopped writing to
     its file three days ago — which you only find out by opening the
     Console you do not have open. This watches the OUTPUT of every
     tool that produces some and puts a PERSISTENT notification on
     screen when one goes quiet. ⇪⇧H for the full report.
  🧩 IT WATCHES FILES, SO NOT ONE LINE OF ANY EXISTING MODULE CHANGED.
     Twenty other modules, zero regression risk. It also catches
     HALF-broken — a watcher that silently detached still loads, still
     binds, still reports healthy, and stops writing.
  🚨 THE REAL WORK WAS NOT ALERTING. A monitor that cries wolf gets
     ignored, and an ignored monitor is worse than none: it trains you
     to dismiss the one notice that mattered. Staleness is counted in
     AWAKE TICKS, so shutting the lid for three days costs nothing;
     each check names the hours it is expected to be active; it speaks
     once per tool per day; and a boot grace period stops it judging
     modules that warm on a timer. Most of its test file is about
     staying silent.
  ⏱ hs.notify.show() WOULD HAVE BEEN THE WRONG CALL and looks like the
     right one: its notices inherit withdrawAfter = 5 seconds and
     vanish while you are looking elsewhere — the exact situation this
     module exists for. withdrawAfter = 0 makes them persist. Found by
     reading Hammerspoon's source, not by guessing.
  🔎 NEW IN THE TEST SUITE: AN EXPLORER. It writes its own test cases —
     random sequences of real actions, checking after EVERY step that
     the module is in a state it allows, then SHRINKING any failure by
     deleting steps while it still fails. Planted a broken teardown and
     it found it unaided in a 40-step sequence, then cut it to two:
     "showClick → escape". That reduction is the whole point; a 40-step
     trace is a haystack, a 2-step one is a bug report.
  🧪 1,344 checks across ten suites.

NEW IN 6.45.2 — DOES THE NEW MODULE BREAK THE OLD CONFIG?
  🔗 THE QUESTION NO OTHER SUITE HERE ASKED. Every test file proves one
     module correct IN ISOLATION, against stubs. That says nothing about
     nineteen of them sharing one keyboard, one hotkey table and one
     global namespace. NEW: tests/test_integration.lua.
  ⌨️ THE REAL RISK, AND IT IS SUBTLE. Mouse Grid binds BARE letters
     (a s d f g h j k l) while its overlay is up. The hyper key works by
     doing the same thing, and §3.12 deliberately does NOT exit the
     hyper modal when a shortcut fires — so while the grid is open BOTH
     modals have bare "a" bound. Whether that works is decided inside
     hs.hotkey's shadowing stack, which nothing here modelled.
  ✅ SO THE STACK IS NOW SIMULATED FAITHFULLY — enable()/disable()
     reimplemented from Hammerspoon's own hotkey.lua, same shadowing,
     same un-shadow scan — and the real sequence driven through it:
     ⇪ held → grid opens → grid's letters WIN → release ⇪ mid-grid and
     the grid KEEPS them → close the grid and hyper gets them BACK →
     close everything and the keyboard is clean. Both release orders,
     plus double-enter, double-exit, and the grid with no hyper at all.
  🧬 ALL 19 MODULES LOADED TOGETHER through the real §1.12 loader, then
     audited for the collisions that only appear in company: two modules
     on one ⇪ key, two on one global chord, two publishing one service
     name, two on one cheat-sheet slot, a malformed cheat-sheet row that
     would break EVERY group's rendering rather than just its own.
  🧪 4 mutations prove those checks bite: stealing ⇪N from the Capture
     Pad, Screen Veil's cheat-sheet slot, Screen Veil's panic key, and
     the Capture Pad's flush service are each caught by name.
  📣 ONE THING THIS COSTS YOU, BY DESIGN. §3.12 forwards every UNCLAIMED
     ⇪ key to the frontmost app as ⌘⇧⌃⌥+key. Claiming M means ⌘⇧⌃⌥M and
     ⌘⇧⌃⌥⇧M no longer reach Raycast, Rectangle or a browser extension.
     That is true of adding any ⇪ shortcut; it is worth knowing once.
  🧪 1,227 checks across eight suites.

NEW IN 6.45.1 — THE MOUSE GRID, AUDITED AGAINST HAMMERSPOON'S OWN SOURCE:
  🔬 THE GAP A TEST SUITE CANNOT CLOSE BY ITSELF. Every check in 6.45.0
     validated the module against MY stubs, which encode MY assumptions
     about the hs API. A wrong assumption passes the test and crashes
     the Mac. So Hammerspoon's source was read directly and every call
     this module makes was checked against it.
  ✅ CONFIRMED CORRECT: the canvas element types and every attribute
     used; center/radius on circle; coordinates on segments; frame on
     rectangle and text; roundedRectRadii; textAlignment "center";
     fillColor on closed shapes and strokeColor on primitives;
     windowLevels.screenSaver; every canvas method called; the mouse,
     eventtap and screen-watcher calls; and — the one most worth
     checking — that modal:bind is declared (mods, key, MESSAGE, fn) but
     shifts its arguments when a function arrives in the message slot.
  🐛 A HANG, WHICH IS WORSE THAN A CRASH. A display reporting height 0
     (one disconnecting mid-query, a virtual display, some
     screen-sharing sessions) makes w/h infinite; math.floor(math.huge)
     is math.huge, so the cell loop became `for c = 0, inf` and
     Hammerspoon spun forever with no error and no recovery but a
     force-quit. Frames are now sanity-filtered, and one clamp bounds
     the loop even for a frame that passes the filter and still
     overflows.
  🐛 UNREACHABLE SCREEN. Without cols <= share, an extreme aspect ratio
     on a small share produced more cells than labels; the surplus was a
     region of screen that could never be reached. The fuzzer finds it
     within ~50 layouts once the clamp is removed.
  🐛 A CRASH ON A SCALED DISPLAY. string.format("%d", x) RAISES in Lua
     5.4 for any float without an exact integer representation, and
     screen frames are not something this module controls. No "%d"
     touches a frame now.
  🐛 INVISIBLE KEY CAPTURE. If the landed badge failed to draw, the old
     one had already been destroyed — leaving the keyboard captured with
     nothing on screen saying so, the one thing this design forbids.
     Landed mode is now refused outright rather than entered blind.
  🐛 A KEY YOUR KEYBOARD CANNOT SEND. hs.hotkey RAISES on an unknown key
     name rather than returning nil, so one exotic character in
     grid.alphabet would have taken the module down at setup.
  🗑 AND ONE DELETION. A NaN/infinity guard was written, then removed on
     proof that it was UNREACHABLE — the clamp beside it already handled
     both. Untested code that looks like a safety net is worse than no
     code, because the next reader trusts it.
  🧪 4 mutations run against the NEW tests themselves; two were
     toothless and were rewritten until reverting each fix fails the
     suite. 1,500-layout geometry fuzzer. 244 checks on this module.

NEW IN 6.45.0 — MOUSE GRID (⇪M): TYPE THREE LETTERS, THE POINTER GOES THERE:
  🎯 ⇪M lays a labelled grid over EVERY display. Each cell carries three
     home-row letters; type them and the pointer jumps to that cell. ⇪⇧M
     clicks on arrival. After it lands you can stay on the keyboard —
     SPACE clicks, ⇧SPACE right-clicks, 2 double-clicks, arrows nudge 8pt
     (1pt with ⇧), ⎋ backs out — or just use the trackpad.
  📐 A COORDINATE TOOL, DELIBERATELY NOT AN ELEMENT TOOL. It knows nothing
     about what is underneath, which is exactly why it never fails: video,
     PDFs, a Photoshop canvas, a remote desktop, any pixel is reachable.
     Walking the Accessibility tree for real buttons (Vimac/Homerow style)
     is more precise where it works and returns NOTHING in Electron and
     Java apps, costs 100–500ms per invocation, and needs a permission the
     work Mac may withhold. That can be layered on later as a second stage
     sharing these keys; it must not be merged in, because the two have
     opposite failure modes.
  🚨 THE MOST DANGEROUS MODULE IN THIS CONFIG, AND BUILT LIKE IT. A
     full-screen overlay that captures keystrokes can lock you out of your
     own Mac. Four independent defences: ONE invariant (state ⟺ modal ⟺
     canvas) behind a single idempotent teardown that pcalls each step
     separately; a WATCHDOG so nothing outlives its keypress; a PANIC key
     on a plain chord (⌃⌥⌘⇧M) rather than ⇪, because if ⇪ is what broke
     then a ⇪ panic key is no panic key; and unbound keys PASS THROUGH, so
     ⌘Q and ⌘Tab keep working while the grid is up. Landed mode is never
     invisible — whenever keys are captured, a badge says so.
  🐛 THE SUITE CAUGHT THE EXACT FAILURE THAT MATTERS. hide() first walked
     `grid.cache.screens or {}` to put the overlay away. When the thing
     that broke IS the cache, `or {}` makes the teardown a no-op: the
     modal exited, the state cleared, and the sheet stayed on screen over
     everything. Teardown must never depend on the structure that just
     failed, so a flat list of what is actually on screen is now kept
     separately, and a mutation pins the regression.
  🐛 Also mine: `#chars ^ n` parses as `#(chars ^ n)` because Lua binds ^
     tighter than unary # — the same precedence family that crashed
     6.44.13's word-wrap.
  ⚡️ FAST BY ARCHITECTURE, NOT BY LUCK. 729 cells is ~1,500 canvas
     elements. Scrim and lines are one cached canvas per screen, built
     once per display layout; labels are a second canvas and the only
     thing redrawn; each keystroke shrinks 729 → 81 → 9, so every redraw
     is cheaper than the last. A screen watcher drops the cache when
     displays change, rather than drawing yesterday's grid over today's
     screens.
  🔢 CAPACITY IS ARITHMETIC, AND IT IS PUBLISHED. alphabet^length = 9³ =
     729 cells, ~45pt on one display, near Apple's own 44pt minimum
     control size. TWO DISPLAYS SPLIT THAT into ~85pt cells, coarser than
     many buttons — which is what the arrow-nudge is for, and widening
     grid.alphabet buys the fine grid back. _G.mouseGridReport() prints
     the real cell size on THIS Mac and warns when it is too coarse.
  ♿️ MOVING AND CLICKING ARE NOT THE SAME PERMISSION. Warping the pointer
     needs nothing, so the JUMP works on any Mac. Synthesising a click
     goes through hs.eventtap, which macOS gates behind Accessibility — so
     without it the grid still jumps and SPACE says why it could not
     click, instead of looking broken.
  🧪 207 new checks, 10 mutations, 1,123 across seven suites.

NEW IN 6.44.13 — "DOES IT WORK ON THIS MAC?", ANSWERED IN ONE CALL:
  🖥 ONE init.lua, TWO VERY DIFFERENT MACS. About a dozen things
     legitimately differ between the personal Air and the managed work
     MacBook. Every one was already handled, and every one printed its
     own line somewhere at boot — which is the problem. Twelve scattered
     lines is not an answer to "what works here", it is twelve things to
     go and find.
  ✅ NEW: core/capabilities.lua. _G.capabilityReport() reports OneDrive,
     backup, Asana, Accessibility, the hyper key, OCR, Homebrew and the
     module load — each with its STATE, the real REASON, and, when it is
     off, WHAT THAT COSTS YOU. "OFF" only means something if you know
     what it takes with it. Included in ⇪⇧D.
  ❔ UNKNOWN IS A REAL ANSWER. The hidutil remap and the OCR probe are
     decided asynchronously, well after boot. "Has not reported yet" and
     "this Mac cannot" need different reactions, so they are never
     folded together. A broken secret.lua is likewise distinguished from
     a missing one — broken is a typo you can fix in thirty seconds.
  🎹 The hyper remap's result is now RECORDED (_G.hyperRemapOK), not just
     printed once and lost. It is the single biggest difference between
     the two Macs, and asking you to scroll back for a line was a poor
     way to find it out.
  📄 NEW: INSTALL.md — rebuilding this config from nothing, step by step.
     Hammerspoon, Accessibility, the files, secret.lua, the machine
     profile, the OCR shortcut, no-admin Homebrew, verification, and
     what to do when a step fails. Every optional step is marked, with
     what you lose by skipping it.
  🧬 A TEST NOW KEEPS THE DOCS HONEST. Adding capabilities.lua left
     INSTALL.md saying "3 files", hs-doctor.sh checking three names and
     hs-install.sh requiring three — three places silently out of step
     with one new file, and the installer is what stands between a
     half-copied config and the primary Mac. The file list is read from
     DISK now and anything hard-coding it must agree. 7 mutations catch
     that drift, including one that only removed a name from the
     installer's PRE-CHECK loop and left the verify loop intact.
  🐛 Two of my own, both caught by running the code rather than reading
     it: a one-line conditional in the report's word-wrap relied on Lua
     binding `and` tighter than `or`, evaluated to a boolean and crashed
     on concat; and the capability load was first placed above
     `local hyperEnabled`, where a Lua local is invisible, so it
     captured nil and reported the hyper key disabled on BOTH Macs.
  🧪 940 checks across six suites.

NEW IN 6.44.12 — PROVING THIS IS SAFE ON A MANAGED WORK MAC:
  🔒 THE WORK MACBOOK IS THE PRIMARY MACHINE AND HAS NO ADMIN RIGHTS.
     That is now a tested guarantee rather than a claim. The suite fails
     if any future change adds sudo, an AppleScript admin prompt, chown,
     launchctl, a keychain write, csrutil or spctl.
  📋 EVERY EXTERNAL PROGRAM IS ON A REVIEWED LIST, and an unlisted one
     fails the build. The list: curl, shortcuts, hidutil, open, defaults,
     zsh, rsync. ALL SEVEN SHIP WITH macOS. This config installs nothing.
  🍺 HOMEBREW IS OPTIONAL AND ISOLATED. It is reached from exactly one
     module (update_tracker) and powers exactly one feature (⌃⌥⇧U). No
     brew = that feature is off and says so; nothing else notices. The
     no-admin prefixes under $HOME are searched BEFORE the admin ones,
     and a test enforces that order.
  🏠 NOTHING IS WRITTEN OUTSIDE $HOME. Every write target is built from
     logsDir or configDir; a hard-coded absolute write path fails the
     suite. /Applications and /usr/bin are READ only.
  🌐 THE ONLY HOST THIS CONFIG CONTACTS IS app.asana.com, and only with
     secret.lua present. My first version of that check failed on
     shottr.cc and was WRONG to: that is a vendor page handed to your
     browser because you selected the row and pressed Enter. A link you
     click is not network activity this config initiates. The test now
     keeps those two apart and asserts vendor URLs are never fetched.
  🧬 6 more mutations caught, including "a sudo appears in the backup
     command", "the remap becomes a launch daemon" and "a vendor page
     starts being FETCHED instead of opened".
  🛟 NEW: tools/hs-install.sh — INSTALL, VERIFIED AND REVERSIBLE. The
     risk on the work Mac was never the Lua, it was the COPY: since
     6.44.11 a bare `cp init.lua` produces a config that starts, looks
     fine, and has quietly lost ⇪/ and ⇪⇧D. This checks the download is
     complete BEFORE touching anything, backs up the current config,
     installs, verifies, and ROLLS ITSELF BACK if the verify fails. It
     refuses to run as root. --dry-run shows what it would do; --rollback
     undoes the last install. secret.lua and logs/ are never touched.
  🐛 Its own first verify checked only that each core file EXISTED — and
     a zero-byte one passed, which is the exact half-installed state the
     script exists to prevent. It checks size and content now. Found by
     testing the installer's failure paths rather than its happy path.
  🩺 hs-doctor.sh answers the question ON the work Mac: every external
     command, whether it is present there, and every path written to.
  🧪 875 checks across six suites.

NEW IN 6.44.11 — init.lua IS 44% SMALLER, AND THE CONSOLE IS TWO LINES:
  📉 6,012 LINES → 3,376. Nothing was deleted. 1,827 lines of changelog
     moved to CHANGELOG.md beside this file (all 107 versions, intact),
     and three big blocks moved into core/.
  📂 core/ IS NOT modules/. A module is loaded by the §1.12 loader,
     isolated, and configurable per machine. These three are dofile'd by
     init.lua at exactly the point they used to sit, because the loader
     runs LAST and depends on them: it logs through _G.diag, and every
     module registers a cheat sheet group as it loads. Boot order is
     unchanged. Each load is pcall'd, so a missing core file costs you
     that one feature and prints why — it does not stop the Mac.
       core/diagnostics.lua   §1.11, 287 lines   ⇪⇧D
       core/cheatsheet.lua    §1.6,  721 lines   ⇪/
       core/boot_report.lua   the Console's first impression
  🔇 A CLEAN BOOT IS NOW TWO LINES, not fourteen. Fourteen lines you have
     read a hundred times is not information; it is what you scroll past
     to reach the line you reloaded to see. The rule now: SUMMARISE WHAT
     IS RIGHT, ALWAYS PRINT WHAT IS WRONG. A failed module, a hotkey
     conflict, missing Accessibility, a broken secret.lua — each still
     prints its own full line, every time. Nothing was lost:
     _G.bootReport() prints everything on demand, and _G.bootVerbose(true)
     restores the full report at every boot. That preference is stored in
     hs.settings, so it survives the reload you set it before.
  🧪 THE TESTS STOPPED LYING. test_cheatsheet and test_diagnostics ran
     against tests/block_test.lua and tests/diag_test.lua — hand-extracted
     slices that had DRIFTED so far they were no longer even substrings of
     init.lua. Both suites now load the shipped core/ file. The drift was
     real and it was hiding things: running the real cheat sheet reached
     four hs.hotkey.bind calls and two hs.chooser pickers that the slice
     did not contain, none of which had ever been executed by a test. The
     two dead slices are deleted.
  🐛 AND THAT CAUGHT A BUG I HAD JUST WRITTEN. Lifting the boot report out
     carried its `local axOK = false; pcall(...)` along with it, where it
     shadowed the value being passed in. Effect: a Mac WITHOUT
     Accessibility would still boot to "All green" — the single most
     important thing that report has to warn about, silently dropped. The
     whole-file text audit could not see it. The test that RUNS the file
     caught it on its first execution.
  🧬 20 mutations caught. Three of them were MISSED first: the audit read
     init.lua concatenated with core/, so "init.lua loads the boot report"
     stayed green when init.lua stopped loading it — the core file names
     itself in its own header, and a comment satisfied the search. Fixed
     by auditing init.lua alone, ignoring comment lines, and matching the
     real loader expression instead of the bare filename.
  🩺 tools/run-tests.sh compiles core/ too; tools/hs-doctor.sh reports it
     and says plainly what is off if the folder never got copied across.
  🧪 855 checks across six suites.

NEW IN 6.44.10 — THE DUPLICATE "PARKED" ROW, AND A READABLE CONSOLE:
  🐛 A PARKED ROW SHOWING THE SAME NOTE AS THE QUEUED ROW BELOW IT. Two
     screenshots taken four minutes apart both showed it, and in both the
     parked text matched the queued text exactly — which is not a thing
     that happens twice by chance. The reason line gave it away: "parked
     before this pad tracked reasons" is what prints when a note has no
     parkedAt and no lastError, and a QUEUED note never has either. So a
     queued note was living in the parked list as well.
  🔒 FIXED IN THE DATA, NOT IN THE VIEW. pad.normalize() runs on every
     load: if the two lists are literally the same table it separates
     them, and any parked entry whose id is already in the queue is
     dropped. THE QUEUED COPY ALWAYS WINS — it is the one that actually
     sends, so the parked twin is stale by definition. A genuinely parked
     note, with its own id, is never touched.
  📣 AND IT SAYS SO. Both repairs print to the Console. A silent fix here
     would have left me guessing at the cause again later.
  🧬 4 mutations caught, including "one table used as both lists goes
     undetected" and "the guard eats genuinely parked notes".
  🔇 THE CONSOLE IS WORTH READING AGAIN. hs.hotkey logged every enable and
     disable at info level, and the ⌥Tab switcher binds 32 arrow hotkeys
     on open and releases them on close — 64 lines per use. Three switches
     in half a minute buried the boot report and the pad's send results
     under ~200 lines of bookkeeping. Log level is "warning" now: real
     problems still print, the chatter does not.
  🧪 374 checks in test_features.lua, 801 across all six suites.
NEW IN 6.44.9 — SEND NOW SENDS THE NOTE YOU ARE LOOKING AT, AND THE PAD
STOPS DRAGGING HAMMERSPOON TO THE FRONT:
  🐛 "NOTHING HAPPENS OTHER THAN LOCAL ACTIONS." Reported with a
     screenshot: text typed, an image attached, "0 queued", and Send now
     answering that there was nothing to send. It was telling the truth
     and it was useless. "File it" moves the compose box into the queue;
     "Send now" sends the QUEUE. So a note still sitting in front of you
     was, to the code, not a note yet. That is a distinction the pad
     invented and the person using it has no reason to care about. Send
     now files the open draft first and then sends. Whitespace is still
     not a note, and a draft that cannot be filed (queue full) stops the
     send and says so rather than sending a half-state.
  🪟 HAMMERSPOON JUMPED FORWARD ANYWAY. 6.44.6 removed this module's
     launchOrFocus, which stopped it ASKING for the app to activate — but
     macOS activates an application whenever one of its ordinary windows
     becomes key, and the pad has to become key to accept typing. Removing
     the request was never going to be enough. The one exemption is a
     panel carrying NSWindowStyleMaskNonactivatingPanel, and hs.webview
     builds its window on NSPanel, so the bit applies here.
  ✅ AND IT IS VERIFIED, NOT ASSUMED. This file already carried one
     windowStyle() call that looked handled and did nothing. So
     pad.applyNonActivating sets the mask and then READS IT BACK, because
     AppKit silently drops style bits it will not honour. It reports what
     actually happened in pad.nonActivatingApplied, and when the mask does
     not take it prints the reason and names the switch that certainly
     works (capturePad.focusOnOpen = false — the pad then opens without
     taking the keyboard at all, and you click into it).
  🧪 THE REAL CHANGE IS HOW THIS IS NOW CHECKED. Every Capture Pad bug in
     6.44.x lived in the page's JAVASCRIPT, and the suites could only read
     that JavaScript as TEXT. Grepping source for a function name proves
     the name is present; it proves nothing about what happens when you
     click. tests/dump_pad_html.lua renders the page from the REAL module
     and tests/test_pad_js.js EXECUTES it against a DOM stub, driving the
     actual onclick strings, the keydown handler and the drag. It catches
     the 6.44.7 wiped-draft bug, which no structural test could.
  🧬 12 mutations caught across the two layers, 6 Lua and 6 JavaScript,
     including "Send now stops filing the draft", "applyNonActivating
     claims success without reading the mask back", and "Send now bypasses
     say() and posts a bare message".
  🩺 NEW: tools/run-tests.sh. One command, one exit code: syntax on
     init.lua and all 18 modules, the five Lua suites, then the page
     JavaScript. It says plainly what it did NOT check — a skipped stage
     is never reported as a pass.
  🧪 366 checks in test_features.lua, 793 across all six suites.
NEW IN 6.44.8 — A STALE PARKED NOTE CAN NOW BE READ AND CLEARED:
  🕰 "PARKED · (blank) · earlier" MEANT NOTHING. A note parked BEFORE
     6.44.5 has no lastError and no parkedAt, because nothing recorded
     them yet — so its row rendered an empty gap where the reason
     belongs, which reads like a display fault rather than missing
     history. It now says which it is: "parked before this pad tracked
     reasons", or "reason not recorded" when the time is known but the
     cause is not.
  🗑 DISCARD, WITH A CONFIRMATION. Until now the only exit for a parked
     note was putting it back in the queue — which re-parks it if it
     still fails, so a note that can never send (a project you lost
     access to) sat in the banner forever and the only real fix was
     hand-editing queue.json. There is a Discard button now. It asks
     first, because this is the ONE action in the pad that destroys a
     note; it removes the note's images too rather than orphaning them
     in the images folder; and it never touches the live queue.
  🧬 Three mutations on the new destructive path are caught, including
     "discard also wipes the live queue" and "discard stops asking".
  🩺 NEW: tools/hs-doctor.sh. One read-only command that reports what
     is ACTUALLY installed — versions, per-module fix markers, file
     completeness, whether the remap is live — and works even when
     Hammerspoon will not start. Too much of 6.44's debugging went on
     guessing at the Mac's state from here.
  🧪 343 checks in test_features.lua, 735 across all five suites.
NEW IN 6.44.7 — ATTACHING AN IMAGE NO LONGER WIPES WHAT YOU TYPED:
  🐛 TWO BUTTONS SENT NO TEXT. The draft lives only in the page's DOM
     until a message carries it to Lua, which then writes it back on the
     next redraw. Every KEYBOARD path passed it (text: t.value) — but
     the "Attach clipboard image" and "Send now" BUTTONS sent bare
     {a:'image'} and {a:'flush'}. Lua kept its stale copy (empty, on a
     fresh pad) and the redraw replaced everything typed with it. That
     is exactly why ⌘⇧V worked and clicking the button did not.
  🔒 FIXED IN ONE PLACE, NOT AT SEVEN CALL SITES. say() now attaches the
     live textarea to EVERY message it sends, so a button added later
     cannot forget. All the individual `text: t.value` arguments are
     gone, and a test asserts none come back.
  ⌨️ THE CARET SURVIVES THE REDRAW TOO. Attaching an image mid-sentence
     used to dump the cursor at the end of the draft; the position now
     travels with the message and is restored. It is clamped in
     JavaScript rather than Lua on purpose — selectionStart counts
     UTF-16 units while Lua's # counts BYTES, and the two disagree the
     moment an emoji is in the note.
  ⚠️ HONEST LIMIT ON THE TESTS: this bug lived in JavaScript, which
     cannot be executed from Lua. The new checks are STRUCTURAL — they
     prove no call site omits the text and that say() always attaches
     it — plus the Lua half is exercised for real. Three mutations,
     including the original bug, are caught.
  🧪 330 checks in test_features.lua, 722 across all five suites.
NEW IN 6.44.6 — ⇪N NO LONGER DRAGS THE CONSOLE FORWARD:
  🐛 OPENING THE CAPTURE PAD ACTIVATED THE WHOLE APPLICATION. show() had
     an hs.application.launchOrFocus("Hammerspoon") in it, which I added
     to get the caret into the textarea. Wrong tool twice over: it
     activates the APP, so every Hammerspoon window came forward with
     the pad — the Console most visibly — and it was not needed at all.
     allowTextEntry(true) already sets canBecomeKeyWindow inside
     hs.webview (it defaults to NO), and bringToFront() already calls
     makeKeyAndOrderFront:. Raising one window was the job; activating
     the app was collateral damage. The call is gone.
  ⚙️ capturePad.focusOnOpen (default true) decides whether the pad takes
     the keyboard when it opens. Set it false to have the pad appear
     without stealing focus and click into it yourself. Neither setting
     activates the application.
  🔍 CHECKED THE REST OF THE CONFIG FOR THE SAME MISTAKE: nothing else
     does this. The other activate() calls (App Peek, Window Arranger,
     ⌥Tab) target the app you are switching TO, which is their whole
     purpose.
  🧪 A test asserts the app is never activated, and a mutation putting
     the old call back is caught. 317 checks in test_features.lua,
     709 across all five suites.
NEW IN 6.44.5 — A PARKED NOTE NOW EXPLAINS ITSELF:
  ⚠️ THE WARNING LOOKED LIKE A LIVE ERROR ABOUT THE WRONG NOTE. The pad
     said "1 note could not be sent after 3 tries" and then listed the
     QUEUED notes underneath — so the row you were reading was never the
     one that failed, and the banner reappeared after every successful
     send. Nothing was broken; it was just impossible to tell that from
     looking at it.
  🖥 PARKED NOTES GET THEIR OWN ROWS now, badged PARKED, dated, and
     carrying the reason the send failed — taken from Asana's own error
     message ("HTTP 403 — Not Authorized to access project") rather than
     a bare count. The banner says the note is from an EARLIER send and
     states plainly that it will NOT go out until you put it back.
  🚩 THE BEHAVIOUR THAT CAUSED THE CONFUSION IS CORRECT AND STAYS: a
     parked note is never included in a later send. That is what parking
     is for — a note that failed for a real reason must not be retried
     silently behind you. It moves only when you press the button.
  🧬 A MUTATION SURVIVED AND WAS INVESTIGATED RATHER THAN PAPERED OVER.
     Making flush() fall through to the parked list changed nothing —
     because the empty-queue guard returns before that line is ever
     reached. Proven equivalent by removing the guard as well, at which
     point the suite fails. A new test covers the real scenario: Send
     now with an empty queue and something parked must post nothing.
  🧪 312 checks in test_features.lua, 704 across all five suites.
NEW IN 6.44.4 — TEN AUDIT PASSES, AND THE ONE REAL BOTTLENECK:
  ⚡ THE SEARCH PICKERS WERE O(history) PER KEYSTROKE. ⇪F and ⇪0 both
     run from queryChangedCallback, so their filter loop fires on EVERY
     character typed — and each pass rebuilt a concatenated, lowercased
     haystack for every row of retained history (90 days of file events,
     120 days of raw activity sessions, one row per window focus change).
     Measured: 18ms per keystroke at 10,000 rows, 78ms at 40,000. That
     is typing lag on the main thread, and it grows all year.
     The search string is now built ONCE per entry and cached on it —
     about 18x faster. Cost is one string per row; both CSV writers name
     their columns explicitly, so the cache never reaches disk.
  ⚡ THE FILE-TRACKER LOG WAS PRUNED ONLY AT BOOT. Its retention cutoff
     ran once, when the module loaded, so on a Mac left logged in for
     weeks the in-memory list grew without limit until the next reload —
     and every ⇪F keystroke scanned all of it. It now prunes every 200
     recorded rows, which keeps recording O(1) amortised.
  🔬 WHAT THE OTHER PASSES FOUND: nothing. 19 files compile; no
     discarded timer or watcher; no ipairs over a literal that can hold
     nil; no unprotected hs.json.decode; no hs.window.filter; no
     accumulate-in-a-loop string building; no io.open inside a loop; no
     unresolved bare-global call. Two audits were themselves WRONG and
     were fixed before trusting them — one regex spanned newlines and
     reported a valid forward declaration as a dangling global, another
     counted a nested warm() body as boot-path cost.
  🚫 ONE OPTIMISATION MEASURED AND REJECTED. The autocorrect event tap
     runs on every keystroke system-wide and uses two Lua pattern
     matches. Replacing them with lookup tables benchmarks 2.8x and 4.1x
     faster — and saves 0.188 MICROSECONDS per keystroke. Not worth the
     churn, so it was not made. Speed-up ratios without absolute numbers
     are how pointless work gets justified.
  🧬 THE TEST SUITE IS NOW MUTATION-TESTED. 14 real invariants were
     deliberately reversed to see whether anything failed. Two survived
     the first run — both cache tests, because they grepped the source
     for a variable name instead of driving the picker, so a mutation
     that stopped READING the cache left them green. Rewritten to poison
     a cache entry and prove it is read. 14/14 caught now.
  🧪 291 checks in test_features.lua, 683 across all five suites.
NEW IN 6.44.3 — PARKED NUMPAD, CLICK-TO-COPY DATES, PERMISSION SWITCH:
  🅿️ THE NUMPAD LAYER IS NOW PARKED, NOT LIVE. numpad.enabled = false
     ships by default: the 3x3 layout is kept as a worked-out plan in
     the cheat sheet under a PARKED banner, and NOT ONE ⇪ + pad key is
     bound, so every one of them stays free for whatever you decide
     later. Not binding is a real difference, not cosmetic — a disabled
     handler that still claimed the keys would swallow each press and
     do nothing, which is indistinguishable from a dead keyboard.
     ⚠️ A MACHINE PROFILE CANNOT switch it on: profile settings are
     applied AFTER setup(), and binding happens during setup, so the
     override would arrive too late to claim anything. Edit the one
     line in modules/numpad_layer.lua and reload.
  📋 CLICKING A DATE IN THE CALENDAR COPIES IT, as 08-07-26 — every
     part zero-padded to two digits so pasted dates line up in a
     column. The alert names the weekday too ("08-07-26 (Fri) copied"),
     because the point of copying a date is usually that you are about
     to commit to it. C copies the highlighted date without the mouse,
     with no repeat handler so holding it cannot refill the clipboard
     thirty times a second. cal.copyFormat changes the shape;
     cal.copyOnClick = false goes back to click-selects-only.
  🔐 ONE SWITCH FOR THE ONE PERMISSION THIS CONFIG ACTUALLY NEEDS.
     altTab.useSnapshots = false. hs.window:snapshot() — photographing
     another app's window for the ⌥Tab tiles — is the ONLY call in the
     whole config that macOS treats as a screen capture, and therefore
     the only reason it ever asks for Screen Recording. Turn it off and
     every tile shows the app icon instead, the switcher is otherwise
     identical, and macOS is never asked. A test asserts snapshot() is
     called exactly zero times with the switch off.
  🧪 269 checks in test_features.lua, 116 in test_switcher.lua,
     661 across all five suites.
NEW IN 6.44.2 — CAPTURE PAD: DRAGGABLE, RELIABLE, AND CAPTIONED:
  🖱 THE PAD MOVES NOW. Drag it by its header bar. hs.webview builds
     its window with NSWindowStyleMaskBorderless hard-coded in the
     extension's own source and never sets movableByWindowBackground,
     so there is no native title bar and the windowStyle({"titled",…})
     call this module used to make was being ignored outright. The
     drag is driven from LUA rather than JS mousemove, and that matters:
     a WKWebView stops receiving mouse events the instant the pointer
     leaves it, so a JS-driven drag dies the moment you move faster
     than the window follows. Lua polls the real mouse position and
     the real button state instead, so a mouse-up released anywhere on
     screen still ends the drag.
  🔁 WHY SENDING WAS INCONSISTENT. 6.44.1 fixed the ordering bug that
     made attachments fail EVERY time; what was left failed only
     SOMETIMES. Feeding the auth header on curl's stdin means writing
     into a pipe that curl's own read loop is already running against —
     a race, and races do not fail consistently. The header now goes
     into a short-lived FILE: written, chmod 600, and closed before
     curl is even created, handed over as -H @<path>, and deleted the
     moment the upload's callback fires. A file curl opens after it is
     already complete on disk has nothing left to race. warm() also
     sweeps that folder at boot, so a force-quit mid-upload cannot
     leave a token sitting on disk.
  🗒 A NOTE WITH AN IMAGE KEPT ITS TEXT. The description was built only
     for notes too long for their own title, so a short note plus a
     screenshot produced a description reading "1 image attached." and
     a timestamp — the caption was dropped exactly when the image made
     it matter most. An image now always brings the note's text with it.
  ♻️ PARKED NOTES ARE RECOVERABLE. A note that failed maxRetries used
     to be reachable only by hand-editing queue.json. The pad now shows
     a button that puts them all back in the queue with their attempt
     count reset, for retrying a send that failed for a reason since
     fixed.
  🐛 CAUGHT BY ITS OWN TEST, IN MY OWN NEW CODE: beginDrag() set the
     grab offset and THEN called endDrag() to clear any previous drag —
     which wiped the offset it had just stored. The drag test failed on
     the first run and named it exactly.
  🧪 246 checks in test_features.lua, 632 across all five suites.
NEW IN 6.44.1 — CAPTURE PAD: THE IMAGE ATTACHMENT BUG, AND THE FONT:
  🐛 EVERY IMAGE ATTACHMENT WAS SILENTLY FAILING. Two bugs in
     uploadAttachment, both now covered by a test that reproduces the
     exact failure:
       1. setInput() was called AFTER t:start(). The Hammerspoon docs
          say setInput "can be called before the task has been
          started, to prepare some input for it" — for a task with no
          streaming callback (this one), stdin is wired up from
          whatever was already queued when the task starts. Called
          after, the data missed the window: curl hit EOF on stdin
          immediately, posted with NO Authorization header, Asana
          returned 401 — and curl still exits 0, because it only
          fails on a transport error, never an HTTP one. Fixed by
          calling setInput() before start(), and closeInput() is no
          longer called at all: the docs say it is only for a task
          WITH a streaming callback, and this one has none.
       2. The failure branch printed `tostring(err or out)`, meant to
          prefer stderr and fall back to the response body — except
          "" is TRUTHY in Lua, so an empty stderr string always won
          that `or`, hiding the actual 401 body behind a blank line
          in the Console every single time.
     The upload now also verifies the REAL HTTP status via curl's
     `-w "%{http_code}"` instead of guessing from whether the body
     contains the word "errors", and switched from `-K -` (a config
     file with exact quoting rules) to `-H @-` (one plain header line
     on stdin) — simpler, and nothing left to get the quoting wrong.
     A note whose task sends but whose image does not attach is no
     longer reported as a clean "N sent" — the flush summary now says
     so, names the task's gid, and the Console gives the real reason.
  🖼 EACH PINNED IMAGE NOW HAS A ✕. Pin the wrong one with ⌘⇧V and you
     can take it back off before filing, rather than wondering whether
     it is really attached to the note you are about to send.
  🔤 THE COMPOSE BOX FONT WAS NEVER ACTUALLY 14px. `font:14px inherit`
     is invalid CSS — the `font` shorthand only accepts the `inherit`
     keyword as its ENTIRE value, never mixed with an explicit size —
     and WebKit drops an invalid shorthand rule outright rather than
     applying the size and ignoring the rest. The textarea was quietly
     running on its browser default the whole time. Now set as plain
     longhand at 16px, box height raised 120px → 180px, and general
     text bumped 14px → 15px.
  🧪 227 checks in test_features.lua now drive the REAL webview path
     (a stub was added — the suite previously only exercised the
     no-webview fallback), reproducing the exact curl-exit-0/HTTP-401
     failure and asserting the Console shows the real response body.
NEW IN 6.44.0 — FIVE NEW FEATURES, AND ARROWS IN THE SWITCHER:
  ⌨️ ⌥TAB TAKES ARROW KEYS. Keep ⌥ down: ← → step one tile, ↑ ↓ jump a
     WHOLE ROW — six tiles a press on a six-column grid, which is the
     point when the list is thirty windows long. Home/End jump to the
     ends and Return switches without waiting for the ⌥ release. ↑ ↓ do
     NOT wrap: the target row has to exist, so ↑ on the top row leaves
     the highlight alone rather than teleporting it, and ↓ into a
     ragged last row lands on the nearest real tile.
  🐛 A REAL BUG FOUND WHILE BUILDING THAT: Esc has NEVER worked during
     an ⌥Tab hold. hs.hotkey matches modifier flags EXACTLY, the HUD
     only exists while ⌥ is held, and Esc was registered under the bare
     {} mask — so the cancel key could not fire during the one session
     it existed for. Every in-HUD key is now registered under all four
     live masks ({}, ⌥, ⇧, ⌥⇧), and a test asserts it.
  🌗 SCREEN VEIL (⇪G). A chrome-less, click-through sheet over EVERY
     connected display; ⇪⇧G cycles Movie 20% → Reading 40% → Dim 60% →
     Deep 75% → Max 90%, ⇪⇧= / ⇪⇧- nudge by 5%. HARD-CAPPED at 90% so
     it never reaches opaque, ⌃⌥⌘⇧G is a panic key bound OUTSIDE hyper,
     and a reload always comes back clear (the strength is remembered,
     the on-switch is not).
     ⚠️ HONEST LIMIT: this DIMS AND MUTES, it does not DESATURATE. A
     canvas composites on top and never sees the pixels underneath, and
     a gamma table is one curve per channel so it cannot average them
     either. True black-and-white lives in System Settings →
     Accessibility → Display → Color Filters → Grayscale, which runs
     inside WindowServer. The two stack.
  🗒 CAPTURE PAD (⇪N). Jot notes and pin clipboard images all day; at
     16:00 every note becomes an Asana task in your project. Titles
     follow the rule you specified: "Verb + rest of task" when the
     sentence asks for an action, "Note :: rest" otherwise, 10 words
     either way, with the overflow and the images going to the
     description. Start a note with ! to force a task or ? to force a
     note. ⇪⇧N sends now. NOTHING LEAVES THE QUEUE BEFORE ASANA
     RETURNS A GID, failures are retried and then parked, never
     dropped. 🔐 The token is fed to curl on stdin, never as an
     argument, so it is not in the process table.
  🗓 MINI CALENDAR (⇪⇧0). 1024×768, translucent black, 16px numbers,
     three months, current week banded, ±1 year and no further. Arrows
     walk days, ↑↓ weeks, [ ] months; it is clickable without stealing
     focus, and a menu-bar date opens it without Bartender.
     ⏰ Every date is built at NOON and stepped by 86400: midnight + 24h
     is 01:00 on the spring-forward day and 23:00 the SAME day in
     autumn, so a midnight-based "next day" silently stalls twice a
     year. Tested under a DST timezone, not just UTC.
  📝 QUICK APPEND (⇪J). Puts the clipboard into a text file without
     opening it — append mode, closed again before the alert. ⇪⇧J picks
     the file or offers a box to type into. Every write is checked:
     io.open returns nil rather than raising, so an unavailable OneDrive
     folder would otherwise fail in complete silence.
  🔢 NUMPAD LAYER (⇪ + number pad). YES, the number pad is a separate
     key path — pad7 is key code 89, the number-row 7 is 26, and both
     are free at the same time. The layer is a MAP, not a list: the pad
     is a 3×3 grid and so is your screen, so ⇪pad7 is the top-left
     quarter, ⇪pad4 the left half, ⇪pad5 the centre. Nothing to
     memorise. (Accessibility → Pointer Control → Mouse Keys eats the
     whole pad when it is on; that is the first thing to check.)
  🔀 ORDER NUMBERS ARE NOW GUARDED. The five new cheat-sheet groups sit
     at 13.1-13.5, and a test asserts every group's slot is unique —
     Lua's table.sort is not stable, so a tie makes the sheet reshuffle
     itself on every reload.
  🧪 593 checks across five suites, all passing.
NEW IN 6.43.1 — PROVING 6.43.0 IS SAFE ON THE OTHER MAC:
  ✅ THE PERSONAL MAC DOES NOT REGRESS, and this is tested, not
     asserted: a system install at /opt/homebrew is still found, the
     daily check is still scheduled, and warm() starts NO login shell
     when brew was already located. The shell is consulted only when
     the well-known paths miss — which on that Mac they do not.
  🔀 ONE REAL GAP THE TEST FOUND: a Mac can carry BOTH a leftover
     ~/homebrew AND a working /opt/homebrew. List order was picking
     between them blindly. Now — and ONLY in that case — the shell is
     asked which brew is actually on PATH, because that is the one
     `brew` means when you type it. The Console says which was chosen
     and which was ignored, instead of silently preferring one.
NEW IN 6.43.0 — HOMEBREW ON A MAC WITHOUT ADMIN RIGHTS:
  🍺 WHAT BROKE: the work MacBook said "Homebrew not found" while
     Homebrew was running perfectly in the next window. The tracker
     checked /opt/homebrew and /usr/local — the two places an ADMIN
     install goes. Without admin rights Homebrew installs to a custom
     prefix under your OWN HOME (~/homebrew), which neither path sees.
     That was my assumption baked in, not a broken Mac.
  🔍 DISCOVERY, IN TWO STEPS. The home-directory prefixes are checked
     first (cheap, no process). If none match, warm() asks your LOGIN
     shell with `command -v brew` — authoritative, because your shell
     profile is exactly what puts a custom prefix on PATH. It runs in
     warm() rather than setup() because starting a login shell costs
     100-300ms and that does not belong on the boot path. Finding it
     there also schedules the daily check that had been skipped.
  🗒 WHEN IT REALLY IS ABSENT, the message now LISTS EVERY PATH TRIED
     and tells you how to pin it, instead of "not found" with no
     detail on a Mac where brew is one directory away. Pin it with
     M.config.brewPath, or per machine from a profile.
  🐛 CAUGHT BY THE NEW TESTS MID-FIX — A CLASSIC LUA TRAP: the
     candidate list was written as
         ipairs({ M.config.brewPath, "~/homebrew/bin/brew", ... })
     and that first field is nil unless you set it. ipairs STOPS AT
     THE FIRST nil, so the loop body never executed once and NO path
     was ever checked on ANY Mac. Nothing errored — the search just
     silently did nothing. The list is built with table.insert now.
NEW IN 6.42.0 — DANGLING CALLS FIXED + A GUARD SO THEY CANNOT RETURN:
  💥 WHAT BROKE: ⇪0 crashed with "attempt to call a nil value (global
     'renderActivityChoices')". When §3.6 became a module its
     functions went with it, but hotkey handlers left behind in THIS
     file kept calling them by bare name. Lua turns a vanished local
     into a nil GLOBAL — no compile error, no boot error, nothing at
     all until the key is pressed. A static scan found TWO:
       · renderActivityChoices  → activity_tracker.lua   (⇪0)
       · addCommentToTask       → asana_comments.lua     (task
         creator auto-comment, and the dashboard's comment prompt)
  🔌 FIXED PROPERLY, NOT PATCHED — A SERVICE REGISTRY. A module now
     PUBLISHES what the rest of the config may call:
         core.provide("activity.renderChoices", fn)
     and anything else calls it with:
         _G.service.call("activity.renderChoices", "")
     A missing provider PRINTS which module is absent and returns nil
     instead of throwing, so an unloaded module degrades to a dead
     key with an explanation rather than a red error. The registry is
     stubbed on line one so it can never itself be nil, and ⇪⇧D lists
     every published service.
  🛡 THE GUARD THAT SHOULD HAVE EXISTED. The audit suite already
     checked that no MODULE reaches into init.lua's locals. It never
     checked the reverse — that init.lua does not call something that
     LEFT. It does now: the audit walks init.lua for calls to any
     function defined in any module file. That check is what would
     have caught this before delivery.
  🍺 HOMEBREW: ONE BREAKAGE, ONE MESSAGE. A corrupt brew API cache
     fails every cask at once, and the tracker printed "check the
     token in updateTrackerApps" fifteen times — sending you to fix
     something that was never wrong. The two causes are told apart
     now, and the brew-side one is reported ONCE per check with the
     actual repair:  rm -rf "$(brew --cache)/api" && brew update --force
NEW IN 6.41.0 — ⌥TAB: A DEADLINE, A CACHE, AND A NAMED CULPRIT:
  🧊 WHAT HAPPENED: on a real Mac, ⌥Tab took 15.90 SECONDS across 15
     apps. The per-application Accessibility sweep that 6.39.0 added
     to reach other desktops can block for a second or more PER APP
     (an app swapped out after an idle period is the usual reason),
     and fifteen of those in a row is a freeze, not a switcher. The
     6.39.0 instrumentation is what turned it into a number instead
     of a mystery — but a number is not a fix.
  ⏱ A HARD DEADLINE. altTab.listBudget (0.8s) is checked BEFORE each
     application, so it caps what gets asked for rather than
     reporting what was already spent. When it trips, the switcher
     opens with what it collected and the HUD says "list cut short",
     because a partial list you can see beats a complete one that
     arrives 16 seconds late — and a silently short list is the bug
     class this config keeps refusing to ship.
  🎯 THE CULPRIT GETS NAMED. Every application is timed individually;
     the Console and ⇪⇧D report the slowest one by name. If a single
     app is responsible, put it in altTab.skipApps and it is never
     asked again. That turns an unfixable "sometimes slow" into a
     one-line fix.
  💾 A SHORT CACHE (altTab.cacheFor, 4s) so repeated presses do not
     re-pay the cost. Short on purpose: a stale switcher missing the
     window you just opened would be worse than a slow one.
  🚫 NO BACKGROUND REFRESH, DELIBERATELY. A timer running this sweep
     every few seconds would move the freeze somewhere you cannot see
     it coming — strictly worse than a slow keypress.
NEW IN 6.40.0 — FEATURES ALL MODULAR · MACHINE PROFILES · WARM-UP:
  🧩 FOUR MORE SECTIONS OUT: Activity Tracker, App Update Tracker,
     Asana Comments, Document Watcher. THIRTEEN modules now, and this
     file is 5,377 lines — down from 9,529 at 6.35.0, a 44% cut.
     What remains here is core plus two pieces of infrastructure
     (the cheat sheet and the hyper key) that everything depends on.
  💻 MACHINE PROFILES (§1.12). The same init.lua and the same
     modules/ folder go on BOTH Macs; a table keyed by machine name
     is the only thing that differs. It lists which modules load and
     can override any module's `config` per machine, so a work Mac
     can run a lower ⌥Tab cap without editing the module. An unknown
     machine falls back to `default` and SAYS SO in the boot report
     rather than quietly loading nothing. Set your work Mac's name
     from `scutil --get ComputerName`.
  ⏱ PERFORMANCE — A WARM-UP PHASE. A module may define warm(), which
     the loader runs ~2s AFTER boot on a HELD timer. Autocorrect is
     why: parsing an 11,000-row CSV was the most expensive thing this
     config did at startup, and it bought nothing — a typo-corrector
     cannot help you before the desktop has drawn. The event tap now
     starts instantly and the dictionary arrives a moment later.
     setup() and warm() are timed separately in ⇪⇧D.
  🐛 TWO EXTRACTION BUGS, BOTH CAUGHT BY TESTS, BOTH WORTH KNOWING:
     1. Removing §3.6 deleted the ONLY definitions of csvQuote and
        splitCSVLine. Lua turns a vanished local into a GLOBAL lookup,
        so the file still COMPILED and would have crashed at boot the
        moment the changelog writer ran. Both are promoted into a new
        §1.4 — a compile that succeeds is not proof of anything.
     2. A `do` anchor matched the letters "do" inside a word in a
        comment and cut a module in half. Anchors are line-exact now.
  📖 HAMMERSPOON-GUIDE.md ships alongside: layout, install, the
     two-Mac workflow, how to write a module, and a troubleshooting
     table keyed by symptom.
NEW IN 6.39.0 — ⌥TAB NOW SEES EVERY DESKTOP, NOT JUST THIS ONE:
  🖥 THE BUG: ⌥Tab listed only the windows on the desktop you were
     looking at. hs.window.orderedWindows() and hs.window.allWindows()
     report ONLY the current Mission Control Space — a documented
     macOS limit, not a Hammerspoon bug. Hammerspoon's own documented
     answer is hs.window.filter, which is the module that froze this
     Mac for 44 seconds in 6.33.0, so that door stays shut.
  🔑 THE THIRD ROUTE: ask each APPLICATION for its own windows. The
     Accessibility API has no concept of a Space, so an app hands over
     its windows wherever they are — other desktops, other monitors,
     minimised. Only GUI apps are asked (app:kind() == 1), which skips
     exactly the background and menu-bar agents whose AX timeouts made
     window.filter unusable. The current Space is still listed FIRST,
     front-to-back, then everything else is appended and deduplicated
     by window id.
  📦 EVERY OPEN PROGRAM, not just every open window: minimised windows
     are included by default now, and a running app with NO window at
     all gets its own tile that ACTIVATES the app when selected.
     Cap raised 24 → 36. Knobs: altTab.includeOtherSpaces,
     includeApps, includeMinimized, maxWindows.
  🐛 CAUGHT BY THE TESTS MID-CHANGE: an app whose windows had all been
     picked up by the current-Space pass contributed nothing new in
     the per-app pass, so it looked like it owned no windows and got a
     second, bogus "no open window" tile — one per app on your current
     desktop. Ownership is now derived from the assembled entries.
  🔊 A failed enumeration phase PRINTS again (the rewrite had made it
     silent), and a failure on the current Space now degrades to the
     per-app list rather than to an empty switcher.
NEW IN 6.38.0 — THREE MORE OUT (nine modules, init.lua −27%):
  🧩 App Watcher (§3.7), File Tracker (§3.8) and Autocorrect (§3.9)
     are now modules. init.lua is 6,952 lines, down from 9,529 at
     6.35.0 — a 27% reduction, and every module file carries its own
     fresh 200-local budget.
  🔧 splitCSVLine MOVED INTO core. It was declared inside §3.6 but
     used by three OTHER sections — always a shared helper living in
     the wrong place. Moving it is precisely what let File Tracker
     and Autocorrect leave, and it is the pattern for the sections
     still waiting: find the helper the section is squatting on,
     promote it to core, THEN move the section.
  ✅ Autocorrect still publishes _G.autocorrectStatus and
     _G.autocorrectTap, so the boot report and ⇪⇧D read them exactly
     as before — the diagnostics did not need to know it moved.
NEW IN 6.37.0 — THREE MORE SECTIONS MOVED OUT:
  🧩 Window Arranger (§1.9), Copy-on-Select (§3.11) and Command
     History (§6.5) are now modules. Six in total; this file is down
     from 9,529 lines at 6.35.0 to 7,947.
  🔑 core.hyperAddShortcut — the supported way for a module to claim a
     ⇪ key. Wrapped rather than captured so it resolves at CALL time,
     which keeps the core table honest if §3.12 ever moves. Command
     History uses it, and carries a note that this only works because
     §1.12 loads modules BEFORE hyperFinalize drains the queue: move
     the loader earlier and that shortcut would silently never bind.
  ⚠️ Copy-on-Select declares NO cheat sheet group on purpose — its one
     entry (⇪⇧C) belongs to the 📋 CLIPBOARD & OCR group, which is
     still in this file. Splitting it out would drop a one-line group
     into the middle of the sheet for no benefit. Stated in the
     module rather than left as a silent inconsistency.
  🐛 AN EXTRACTION BUG THE TESTS CAUGHT: the old §3.11 wrapped its
     locals in a do...end block to stay under the 200-local budget.
     Moving the body into M.setup() split that `do` from its `end`
     across the function boundary — which still COMPILED, and made
     the module return nil instead of its contract table. The
     loader's "does not return a table with a setup() function"
     check is what caught it, which is precisely why it exists.
     The wrapper is gone now: a function scopes its locals already.
NEW IN 6.36.0 — MODULES: SECTIONS NOW LIVE IN THEIR OWN FILES:
  🧩 NEW §1.12 MODULE LOADER. Sections can now live in
     ~/.hammerspoon/modules/<name>.lua and are listed in moduleList.
     Three moved out first — Daily Backup (§1.7), App Peek (§1.8) and
     Window Switcher (§1.10), 464 lines out of this file. Everything
     not yet moved still works exactly as before: the two styles
     coexist on purpose so the move happens a few sections at a time
     instead of as one all-or-nothing rewrite.
  📏 WHY IT MATTERS MORE THAN TIDINESS: Lua's 200-local limit is PER
     CHUNK, and a file is a chunk. This file was measured at exactly
     200 with ZERO headroom in 6.35.0 — the next top-level `local`
     anywhere would have been a compile error taking the WHOLE config
     down. init.lua is at 12 free now, and every module file gets its
     own fresh 200.
  📖 THE CHEAT SHEET IS ASSEMBLED, NOT HARD-CODED. Each module
     registers its own group when it loads, and groups sort by an
     explicit UNIQUE order number (unique because table.sort in Lua
     is not stable — equal keys could reshuffle between reloads).
     Delete a module file and its group goes with it, instead of the
     sheet advertising a shortcut nothing binds — the exact drift the
     "hand-written snapshot" warning has apologised for since 6.10.
  🛟 FAILURE IS ISOLATED, which is the other half of the point. Every
     module is loaded, executed AND set up inside its own pcall: a
     syntax error in one costs you that module, not your hotkeys, not
     autocorrect, not the whole config. Before this, one bad line
     anywhere meant NOTHING loaded. Failures are named in the
     Console, counted in the boot report, listed in ⇪⇧D and shown as
     a ⚠️ group at the TOP of the cheat sheet.
  ☁️ MODULES LOAD FROM LOCAL DISK, DELIBERATELY. Loading them from
     the OneDrive folder would save a copy step and is the wrong
     trade: Files-On-Demand can leave a file as an online-only
     placeholder, and reading one triggers a SYNCHRONOUS download —
     a main-thread stall at every login on a slow network, the same
     failure shape as the 6.33.0 ⌥Tab freeze. Master copies live in
     OneDrive for durability and for copying to another Mac; the
     loader only ever reads local disk. The 5pm backup already
     rsyncs ~/.hammerspoon, so modules/ is covered automatically.
NEW IN 6.35.0 — APP LOCK REMOVED · DIAGNOSTICS ADDED · AUDIT FIXES:
  🗑 APP LOCK IS GONE. The whole PIN-gate feature (old §6.6, ~1150
     lines) has been deleted: the manager, the covers, the PIN
     prompts, the re-lock watcher, the panic key and its cheat sheet
     group. applock.json is STILL excluded from the backup, so a
     leftover file from an older version can never sync anywhere.
  🩺 NEW §1.11 DIAGNOSTICS — ⇪⇧D. Writes one report containing
     versions, boot timings, screens, hotkey counts, feature states,
     file paths with their write status, a LIVE window-enumeration
     timing, recent errors and the last 25 internal events — to the
     Console, your clipboard AND Logs/diagnostics-<machine>.txt.
     A 200-entry trail is recorded in memory ALWAYS, so the report
     shows what happened before a problem even though verbose was
     off at the time — which is the normal case, because nobody
     turns verbose on until after something breaks. Live verbose:
     type  _G.diag.verbose = true  in the Console, no reload.
     hs.uncaughtErrorHandler is now set, so an error thrown inside
     an async callback (HTTP reply, timer, watcher — everywhere a
     pcall in the calling function cannot reach) is captured with a
     timestamp instead of scrolling past.
  🔴 AUDIT FIX (MAJOR) — JSON OFF THE NETWORK COULD THROW. All six
     hs.json.decode calls on Asana replies ran unprotected INSIDE
     async HTTP callbacks. hs.json.decode RAISES on malformed input,
     and a corporate proxy or captive portal answering HTTP 200 with
     an HTML login page is precisely that — likelier on a work
     network than a broken API. The throw escaped every enclosing
     pcall. All six now go through _G.safeJson, which logs how many
     bytes arrived and how they start, then returns nil so the
     caller's existing "if not data" branch handles it.
  🟠 AUDIT FIX (MEDIUM) — THE FILE WAS ON THE 200-LOCAL CEILING WITH
     ZERO HEADROOM. Measured, not guessed: the main chunk of a Lua
     file IS a function, the limit is 200 locals per function, and
     this file was at exactly 200. The next `local` added ANYWHERE at
     top level would have been a compile error taking the WHOLE
     config down — a landmine for whoever edited next. §1.6's nine
     loose locals were folded into the cheatSheet table it already
     had, which buys 8 back. New sections must namespace.
  🟠 AUDIT FIX (MEDIUM) — the diagnostics API is now declared as a
     no-op stub on the FIRST line of the file and extended by §1.11.
     Sections earlier in the file log through it, so a partial load
     that never reached §1.11 would have thrown on a logging call:
     a diagnostics system causing the outage it exists to explain.
  🟠 AUDIT FIX (MEDIUM) — ⌥Tab captured thumbnails for up to 24
     windows and THEN trimmed the list to what the screen could hold,
     so a laptop captured 24 images to draw 15. Snapshots are cheap
     but not free (~5-20ms each) and that waste lands on the keypress
     you are waiting on. The grid is now worked out first, the list
     trimmed, and only the survivors captured — timed, and reported
     in the Console if it ever crosses 0.35s.
  🟡 AUDIT FIX (MINOR) — a leaked file handle: the changelog writer
     tested for the CSV with io.open(...) == nil and never closed
     what it opened, leaving it to the garbage collector.
  ⏱ Boot report now prints total load time, so a slow start is a
     number you can quote rather than a feeling.
NEW IN 6.34.0 — ⌥TAB SWITCHER REBUILT (6.33.0 FROZE THE MAC):
  🧊 WHAT WENT WRONG. 6.33.0's switcher beachballed Hammerspoon for
     44 seconds on the FIRST ⌥Tab. The Console dated it exactly:
       10:01:25  -- Loading extensions: window.filter
       10:02:09  ✏️ Autocorrect tap was disabled by macOS — revived
     macOS switches an event tap off when the owning app stops
     answering, so that second line is the main thread returning.
     CAUSE: hs.window.switcher is built on hs.window.filter, which
     enumerates and then SUBSCRIBES TO every running application over
     the Accessibility API — and clearing the default filter to get
     minimised windows pulled hidden and background apps in too. Each
     unresponsive app costs a full AX timeout, on the one thread
     Hammerspoon has. That is not tunable; the module was the wrong
     tool for a Mac with a lot of apps open.
  🔨 REBUILT WITHOUT hs.window.filter. §1.10 now lists windows with
     hs.window.orderedWindows() — one snapshot, already front-to-back,
     no watchers, GUI apps only — draws its own tile grid on hs.canvas
     and watches for the ⌥ release by POLLING
     hs.eventtap.checkKeyboardModifiers on a timer instead of adding
     another event tap macOS can switch off.
  📏 IT MEASURES ITSELF. Every enumeration is timed; anything past
     0.35s prints how long it actually took and which knob to turn.
     A slow machine now reports a number instead of a beachball.
     The list is capped (altTab.maxWindows = 24) — a bounded cost
     instead of a promise that can't be kept.
  🗑 A SECOND BUG, FOUND WHILE FIXING THE FIRST: 6.33.0's warm-up
     timer was created and its object thrown away on the same line.
     An unreferenced hs.timer is garbage-collected, so it never
     fired. Every timer here is stored.
  🛟 Esc cancels without switching · a watchdog closes a stuck HUD
     after 30s · altTab.enabled = false is a panic switch that makes
     ⌥Tab inert without touching anything else in this file.
  ⚠️ MINIMISED WINDOWS ARE OFF BY DEFAULT now (they need the slower
     hs.window.allWindows call): altTab.includeMinimized = true.
NEW IN 6.33.0 — ⌥TAB WINDOW SWITCHER (§1.10):
  🔄 WINDOWS-STYLE ALT+TAB, WHICH macOS DOES NOT HAVE. Hold ⌥ and tap
     Tab to walk every open WINDOW with a thumbnail tile each (title
     underneath), ⌥⇧Tab to walk back, release ⌥ to switch. ⌘Tab
     switches APPS and buries a five-window app behind one icon;
     this is per-window. ⌘Tab itself is untouched — macOS reserves
     it, as §0.3's own knownSystemCombos table says.
     Lists minimised windows and hidden apps too (altTab.includeHidden
     = false for visible-only), across all Spaces.
  ⚡ COSTS NOTHING AT BOOT. hs.window.filter has to subscribe to every
     running app and enumerate its windows, so it is built on the
     FIRST ⌥Tab and cached — then warmed quietly 5s after boot so
     that first press is instant anyway.
  🛟 DEGRADES INSTEAD OF DYING. Every setup step is pcall'd with a
     fallback: UI prefs rejected → stock look; custom filter fails →
     default filter. A plain-looking switcher still switches windows;
     an error during setup would have left ⌥Tab dead and silent.
  📖 CHEAT SHEET REORDERED to how you actually reach for things:
     App Monitor first, App Peek under Window Arranger, the new
     switcher after it, then App Updates → App Lock → File Tracker →
     Document Watcher, Autocorrect under Command History, Help last.
NEW IN 6.32.1:
  📖 HELP MOVED TO THE BOTTOM. The ❓ HELP group sat in the middle of
     the feature groups; it now comes last of the built-ins, directly
     after ☁️ BACKUP. Your own ⭐ entries still follow it.
NEW IN 6.32.0 — CHEAT SHEET IS ONE SCROLLING COLUMN:
  📜 IT GROWS DOWN, NOT SIDEWAYS. The sheet used to fill a column and
     then start another one to the right, so a long list spread into a
     wall of text. It is now a SINGLE column you scroll: ↑↓ a row at a
     time (hold to keep going), PgUp/PgDn a screenful, Home/End to the
     ends, or the scroll wheel / trackpad. A scrollbar and an
     "N–N of N" counter in the footer show where you are.
     The wheel is only claimed while the pointer is OVER the sheet —
     anywhere else it passes through, so the window underneath still
     scrolls normally with the sheet open beside it.
     ⚠️ Esc, the arrows, PgUp/PgDn and Home/End are captured GLOBALLY
     while the sheet is up (it takes no keyboard focus, so that is the
     only way it can hear them). Close it and they all go straight
     back to the app underneath.
  🫥 TRANSLUCENT AGAIN, BUT READABLE. The sheet now has its OWN
     see-through setting (cheatSheet.alpha = 0.75, top of §1.6) rather
     than sharing panelAlpha, and sits on a near-black panel instead
     of a grey one. That combination is the point: at the same alpha a
     darker panel holds white text at roughly 8:1 contrast, so you can
     see the window behind the sheet without the shortcuts fading into
     it. panelAlpha (0.90) still governs the legend strip and draft
     mirror — the two are now independent.
  ⚡ COST NO LONGER GROWS WITH THE LIST. Only the rows actually in
     view become canvas elements (~30), so 300 custom entries paint
     exactly as fast as 30. Scrolling changes one number and repaints
     that window of rows.
  📍 A REDRAW KEEPS YOUR PLACE. Adding, editing or deleting an entry
     while the sheet is open no longer throws you back to the top; a
     fresh ⇪/ still opens at the top. If the list gets SHORTER than
     where you were, the view clamps back into range instead of
     leaving you on blank rows.
  🧱 STRUCTURAL — the section is now one namespaced table
     (`local cheatSheet = {}`) instead of loose top-level locals.
     This file was at Lua's hard ceiling of 200 locals per chunk, and
     the main chunk IS a function: adding the scroll machinery as
     loose locals blew past it, which is a COMPILE error — the whole
     config would have refused to load, not just the cheat sheet.
     Fields on one table cost exactly one local however many are
     added later.
NEW IN 6.31.0 — CHEAT SHEET LEGIBILITY + HYPER W SWAP:
  📖 CHEAT SHEET ENTRIES NO LONGER GET CUT OFF. Every entry was one
     canvas text element in a fixed-width frame, so anything wider
     than the column was silently clipped mid-sentence — "F1-F12 —
     Not forwarded — macOS reserves some" just stopped there, with
     nothing to indicate text was missing. Long entries now wrap onto
     indented continuation lines. Width is ESTIMATED, not measured
     (hs.canvas exposes no text metrics), so the estimate is
     deliberately conservative: wrapping a word early is invisible,
     overrunning the column is the bug.
     Also fixed while in there: the width maths now counts CHARACTERS
     via utf8.len, not bytes. ⇪, ⌘ and — are multi-byte, so # would
     have over-counted them badly and wrapped far too early.
  🫥 PANELS 10% LESS TRANSLUCENT: panelAlpha 0.80 → 0.90. Affects the
     cheat sheet, the dashboard legend strip and the draft mirror.
  🖱 A CLICK NO LONGER CLOSES THE CHEAT SHEET. A stray click anywhere
     on a very wide panel used to dismiss the reference you were
     reading. It now stays up until you press Esc or ⇪/ deliberately.
     Mouse events are off entirely, so clicks pass through to whatever
     is underneath instead of being swallowed.
  ⌨️ HYPER W SWAPPED: ⇪W now summons an app to this monitor (the one
     reached for constantly) and ⇪⇧W opens the Document Watcher.
NEW IN 6.30.1:
  🧹 HOUSEKEEPING: removed the legacy "Lee additions / Be sure to
     have this added in" app list from the header (the watched-apps
     list in §3.7 IS the live list and always has been). Date stamp
     now always reads "MM-DD-YY using Claude". Added a changelog CSV
     at <logsDir>/changelog.csv — every version's verbose notes are
     written there on first boot (Excel-ready: Date | Version |
     Change notes). When the next MAJOR version lands (7.0.0), the
     in-file changelog for 6.x will be compressed to one-liners.
NEW IN 6.30.0 — APP LOCK: NEW KEY, OVERLAY-ONLY, NO REDUNDANT UNLOCK:
  ⌨️ THE MANAGER MOVED: ⇪⇧L → ⇪⇧H. (⇪H on its own is still Command
     History — hyper+H and hyper+shift+H are different combos, and the
     sentry confirms no conflict.) Nothing else about the manager
     changed. The cheat sheet and boot report were updated with it.
  🪟 OVERLAY ONLY, NO HIDING (appLockCoverThenHide now false).
     A locked app is no longer hidden and focus is no longer thrown to
     Finder — the app is left exactly where it sits and an opaque
     panel is painted over its screen. Hiding was what moved focus,
     and moving focus was the monitor-to-monitor bounce, so removing
     the hide removes the bounce by construction.
     TWO honest exceptions, both deliberate: if the cover cannot be
     painted at all it falls back to hiding rather than leaving the
     app exposed, and a CANCELLED or WRONG PIN hides it too — at that
     point the cover must come down, and an app left on screen with
     no PIN entered is exactly the leak this feature prevents.
  🔧 FIX — THE COVER WAS BURYING THE PIN PROMPT. The cover was drawn
     at canvas level `overlay` (102). An hs.chooser panel draws at
     `popUpMenu` (101). So the prompt was open and focused underneath
     a panel you could not see past — which is why the only way
     through was the panic key, and why the PIN worked immediately
     after clearing the cover. The cover now draws at `floating` (3):
     still above every ordinary app window, comfortably below the
     prompt.
  🔧 FIX — YOU COULD "UNLOCK" AN APP THAT WAS ALREADY UNLOCKED.
     Two causes, both fixed. (1) Opening the manager or a PIN prompt
     takes focus, so macOS fires `deactivated` for the app you were
     in — and with re-lock-on-leave ON that silently re-locked the app
     you had just unlocked, the moment you opened the list showing it.
     Our own popups no longer count as "you switched away". (2) The
     lock/unlock rows are rendered when the manager opens and can go
     stale while it is on screen; both actions now check LIVE state
     when you press Enter, so unlocking something already unlocked
     says so instead of asking for a PIN nothing needed.
NEW IN 6.29.1 — APP LOCK: the cover was destroying itself:
  🩹 Cover mode was really hide mode with an extra step. Covering is
     immediately followed by hiding the app and focusing Finder — and
     hiding the frontmost app makes macOS fire `deactivated` for it.
     6.29.0's deactivate handler removed covers unconditionally, so
     the panel was torn down roughly a frame after being painted, by
     our own side effect.
     The cover is now kept while a challenge is in flight. A genuine
     switch away (no prompt open) still clears it, and the 3s watchdog
     is unchanged as the backstop. Verified by restoring the old
     unconditional removal and watching the suite fail.

NEW IN 6.29.0 — APP LOCK: COVER INSTEAD OF HIDE (kills the bounce):
  🖥 The bounce was never a placement bug and could not be patched.
     HIDING an app forces macOS to hand focus to something else, and
     on two monitors that drags your view across and straight back.
     Hiding IS the bounce. 6.27.1 and 6.28.2 both aimed at the wrong
     thing; only the prompt's position improved.
     Now: an opaque panel is painted over the locked app's screen,
     the app is hidden BEHIND that panel (so there is no flash), and
     focus is sent deliberately to Finder. macOS never gets to choose
     the destination, so there is nothing to bounce to.
     Only the screens the app actually occupies are covered — blacking
     out every monitor to conceal one window would be its own problem.
  🚪 FOUR WAYS OUT, because a panel that will not clear is worse than
     any bug in this file so far:
       1. Enter the PIN.
       2. ⌘⇧⌃⌥K (or ⇪K) — panic key. A GLOBAL hotkey on purpose, so
          it fires even if the hyper modal is wedged. The panel says
          so, on screen, in the text.
       3. A watchdog every 3s clears any cover with no prompt behind
          it.
       4. Quit Hammerspoon — the panel is drawn by Hammerspoon, so it
          cannot outlive it. That one is true by construction.
     Each of the first three was verified by deleting it and watching
     the suite fail.
  ⚙️ appLockUseCover = false returns to the old hide-only behaviour;
     appLockCoverThenHide / appLockFallbackApp control the hide and
     where focus lands. All at §6.6.

NEW IN 6.28.2 — APP LOCK: the monitor bounce, actually fixed:
  🖥 6.27.1 claimed to fix this and did not. It captured the locked
     app's screen inside appLockChallenge — but the watcher HIDES the
     app before calling that function, and a hidden app has no focused
     window. appLockRememberScreen returned nil every time, no screen
     override was ever set, and the PIN prompt kept following the
     focus bounce to the monitor you came from.
     The screen is now captured in the watcher BEFORE the hide and
     passed into the challenge.
  🧪 WHY THE TEST PASSED ANYWAY: the mock returned a window for an app
     even while that app was hidden, which cannot happen on a real
     Mac. It certified code that could not work. The mock now returns
     nil for a hidden app, and the old ordering fails the test with
     "prompt opened on the FALLBACK monitor" — the same thing the real
     Mac was doing.

NEW IN 6.28.1 — DOCUMENT WATCHER: say it in plain English:
  💬 The multi-copy rows read "Copy 2 tagged / Enter here copies every
     tagged row · Enter on a row tags/untags it". "Tagged" was a word
     invented in this file — it meant nothing to anyone who had not
     read the source, and the row never said WHY it existed. Rewritten:
       ☑️ Copy several at once...   (pick rows one at a time)
       📋 Copy the 2 documents I picked
       ✖️ Never mind — go back
     and every row now states what Enter does TO THAT ROW: "Enter
     copies this one", "Enter adds this to the copy list", "PICKED —
     Enter removes it from the copy list".
     A test asserts the invented vocabulary stays out and that every
     row explains its own Enter. Confusing wording in the only
     instruction a user ever sees is a defect, not a cosmetic detail.

NEW IN 6.28.0 — DOCUMENT WATCHER (EXPERIMENTAL SECTION):
  📄 ⇪W lists every document you have worked in, with how long you
     spent in each. Searchable by name, extension or date; the first
     row is a running tally of today's documents and total time.
     Enter copies the highlighted row. ⇪⇧E edits or deletes an entry
     (clear the filename and press OK to delete it).
     Stored as Logs/doc_wather.csv — Date, Time of day, File name,
     Working time.
  🧪 It lives inside the EXPERIMENTAL SECTION banner near the end of
     this file, entirely within one immediately-invoked function. It
     borrows only logsDir, showPopup, csvQuote and hyperAddShortcut.
     Delete the whole block and nothing else breaks.
  ⚠️ THREE DEVIATIONS FROM THE REQUEST, all hs.chooser limits:
     1. Shift-click multi-select does not exist — hs.chooser is a
        single-selection list with no modifier-aware click callback.
        Replaced with a select mode: Enter tags rows (✓) and a
        "Copy N tagged" row copies them together.
     2. Bare "W" cannot be a command inside the window; the keyboard
        belongs to the search field, so it would just type "w". Edit
        moved to ⇪⇧E, which works while the list is open.
     3. ⇪W was already the app-summon picker — that moved to ⇪⇧W.
  ✅ ACCURACY: a sample counts only if you are present (2 min without
     input stops the clock) and the gap since the last sample is
     sane. Sleep, stalls and idle gaps are DISCARDED rather than
     billed to whatever document happened to be open, and any CSV row
     that is not fully well formed is dropped at load with a count in
     the Console. Wrong data is worse than missing data here.

NEW IN 6.27.1 — APP LOCK: the PIN prompt stops bouncing monitors:
  🖥 ⌘-Tab to a locked app on a second monitor and you landed on the
     app, then got thrown back to the monitor you came from. Cause:
     hiding the app makes macOS fall back to whatever was frontmost
     BEFORE — usually on the other screen — and by the time the prompt
     opened, showPopup resolved "the frontmost app" to that fallback.
     The prompt followed the bounce.
     App Lock now captures the locked app's screen BEFORE hiding it
     (once hidden it has no window and no screen to ask about) and
     pins the prompt there via a new _G.popupScreenOverride, which
     resolveBaseScreen honours ahead of everything else. The override
     is cleared the moment the prompt is placed — leaving it set would
     strand every other picker in this config on that monitor.
     Tested by asserting the actual coordinates the prompt opens at,
     not merely that a flag was set.

NEW IN 6.27.0 — APP LOCK: only real apps, and a reachable exit:
  🧹 The picker listed every running PROCESS, so it filled with
     loginwindow, photolibraryd, universalaccessd, siriactionsd,
     nbagent, printtool and dozens more — none of them lockable, and
     they buried the few apps you actually care about. It now offers
     an app only if it has a Dock icon (kind() == 1, verified against
     Hammerspoon source) AND lives under /Applications,
     /System/Applications or ~/Applications. Helper apps nested inside
     another bundle are excluded too — they can report a Dock icon.
     Edit appLockAppRoots at §6.6 if you keep apps somewhere else.
  ⬆️ "⚙️ Stop protecting an app…" is now the FIRST row. It was at the
     bottom of a long list and effectively undiscoverable. Safe as the
     default row: it only opens the removal list, and removing
     anything still asks for the PIN.

NEW IN 6.26.0 — APP LOCK: the reason it kept "working once":
  🔁 A PIN unlocked an app PERMANENTLY, until you re-locked it by hand
     from ⇪⇧L. So the first switch prompted, and every switch after it
     correctly did nothing at all — which reads exactly like the
     feature degrading. It was doing what 6.22 was told to do ("no
     time limits"), taken literally.
     New option: RE-LOCK WHEN YOU SWITCH AWAY. Leaving a protected app
     locks it again, so coming back always asks for the PIN. It is not
     a timer — nothing expires while you are sitting in the app; it
     locks on an event, the way a screen lock does.
     OFF by default (nothing automatic unless you ask), and toggleable
     straight from ⇪⇧L — "🔁 Re-lock when I switch away: ON/OFF" — so
     you can try both without editing this file. The choice is saved in
     applock.json, and the boot report says which mode you are in.

NEW IN 6.25.1 — APP LOCK: kill the flash when you click the Dock icon:
  ⚡ ⌘-Tab was already clean; the Dock was not. Your own Console log
     showed why — every Dock click logged "still visible after hide",
     and 6.25.0 only LOOKED ONCE, 150ms after hiding. So the window
     really was on screen for that whole 150ms. That is the flash.
     It now polls every 30ms and re-hides the instant it sees the
     window, so the visible moment is ~30ms instead of ~150ms.
  🐛 A single look was also just wrong: macOS can finish its unhide
     AFTER that check, and 6.25.0 would sail straight past it, leaving
     the app sitting visible behind the prompt. The poll now waits for
     the app to STAY hidden across a few consecutive checks.
  ⛔️ Bounded: it gives up after ~0.6s and prompts anyway rather than
     spinning timers at an app that refuses to stay hidden, and it is
     still ONE poll per challenge — never 6.22's per-event storm.

NEW IN 6.25.0 — APP LOCK: ESC NO LONGER HANDS YOU THE APP:
  🚪 THE HOLE: the app could be sitting VISIBLE behind the PIN prompt,
     and pressing Esc simply closed the prompt and left you in it.
     Two causes, both fixed:
     1. A RACE WITH macOS. Clicking a hidden app's Dock icon makes
        macOS unhide AND activate it. Our hide() lands in the middle
        and macOS finishes unhiding afterwards — app back on screen,
        document readable, prompt floating on top. The challenge now
        confirms the app really went away (0.15s) and re-hides if it
        didn't, BEFORE the prompt appears.
     2. CANCEL DID NOTHING. Esc, a wrong PIN, or the prompt closing
        abnormally now all re-hide the app. Any outcome that is not a
        successful unlock leaves it off screen.
  ♻️ This restores what 6.22's retry was protecting, WITHOUT the
     strobe: 6.22 queued a timer on every activation event, so a
     ⌘-Tab burst queued dozens. This fires once per challenge, behind
     promptOpen, and re-checks before acting. A test asserts a
     25-event burst queues at most one.

NEW IN 6.24.1 — APP LOCK: FIX "works once, then it's unreliable":
  🕳 SECURITY HOLE introduced by 6.24.0's own fix. Its 2-second
     cooldown check sat ABOVE the hide, so during those 2 seconds the
     handler bailed out completely — and a locked app clicked in the
     Dock inside that window came back on screen WITH NO PIN. The
     cooldown now gates only the PROMPT. Hiding happens on every
     activation, always. (Hiding was never what looped: it moves focus
     to some OTHER app, which isn't locked, so nothing re-fires. The
     loop was the prompt reopening as focus returned.)
     Locking from ⇪⇧L no longer starts a cooldown at all — it opens no
     prompt, so there is nothing to damp, and the cooldown was just
     delaying the first real PIN challenge.
  🩹 A prompt that closed WITHOUT its completion callback running left
     promptOpen stuck true, and the watcher's early return on that
     meant App Lock quietly stopped working until a reload. A
     hideCallback safety net now recovers it and says so in the
     Console. Silent death was the likeliest cause of "works one time".
  🔍 DIAGNOSTICS: App Lock now logs what it decided on every event for
     a locked app — hidden, prompt shown, suppressed by cooldown,
     ignored. Every bug in this feature so far has been invisible in
     the Console, which is why they took so many rounds to pin down.
     Set appLockDebug = false at §6.6 once you're happy with it.

NEW IN 6.24.0 — APP LOCK: FIX THE STROBE AND THE 5-SECOND BEACHBALL:
  ⚡ Both symptoms were ONE bug: a focus feedback loop. Hiding an app
     changes focus, a focus change fires another `activated` event,
     and closing the PIN chooser hands focus straight back to the app
     that was just hidden. hide -> focus -> activated -> hide -> …
     Holding ⌘-Tab feeds that loop a stream of events, so the screen
     strobed between the app and Hammerspoon (genuinely unpleasant to
     look at), and the churn pinned the main thread long enough to
     beachball for about five seconds.
  🛑 Three changes, each verified to be load-bearing by removing it
     and watching the tests fail:
     1. The watcher now returns EARLY — before hiding anything — when
        a PIN prompt is already open. 6.23 hid first and checked
        after, so every event in a ⌘-Tab burst hid again.
     2. A 2-second per-app cooldown after we act. This is what
        absorbs the focus-return event when the chooser closes, and
        stops the prompt reopening on itself.
     3. The 0.15s "hide again in case it bounced back" retry added in
        6.22 is GONE. It guarded a race that was never confirmed and
        it was the engine driving the strobe.
     A test fires 25 activation events in a burst and asserts exactly
     ONE hide results, plus a separate one for the post-close case.

NEW IN 6.23.0 — APP LOCK: PIN PROMPT IS A REAL WINDOW, AND ENTER
FINALLY DOES THE OBVIOUS THING:
  🖥 The PIN prompt was an osascript `display dialog`. osascript is a
     command-line process, not an app, and that one fact caused four
     separate complaints: it could not take keyboard focus, ⌘-Tab
     could not reach it, window tools like Scoot could not see it, and
     it ignored which monitor you were working on. It is now an
     hs.chooser like every other picker here, so showPopup() puts it
     on your ACTIVE screen, already focused — just type the PIN.
     The digits are masked: the real text is held in a buffer and the
     field is rewritten to bullets on each keystroke, behind a
     re-entrancy guard so it cannot loop.
  🔁 FIX the lock / "it says unlocked" / lock rhythm. Every protected
     app had ONE row and Enter always meant "remove from the protected
     list". So after unlocking with your PIN, pressing Enter to lock it
     again quietly UN-PROTECTED it; you then re-added it (2nd press)
     and locked it (3rd). Enter now flips exactly what the row shows:
     🔒 LOCKED + Enter asks for the PIN and unlocks · 🔓 UNLOCKED +
     Enter locks it again immediately. Re-locking needs no PIN (it only
     adds protection); unlocking always does.
  🛡 Removing an app from App Lock now REQUIRES the PIN, and lives
     behind its own "⚙️ Stop protecting an app…" row. Previously
     anyone could open ⇪⇧L and un-protect an app with one keypress and
     no PIN, which made the whole lock decorative.

NEW IN 6.22.0 — APP LOCK: NO TIMER, AND LOCKING ACTUALLY LOCKS:
  🔒 FIX: locking an app that was ALREADY OPEN did nothing visible.
     The watcher only reacted to an app launching or being switched
     to, so locking the app sitting in front of you left it fully
     usable — you could keep typing in it. Locking now hides the app
     immediately, and "Re-lock everything now" hides every locked app
     that is running.
  ⏱ REMOVED: the 15-minute unlock timer. It was never asked for and
     made the feature feel arbitrary. An unlock now lasts until YOU
     lock the app again from ⇪⇧L. The only thing that re-locks on its
     own is restarting Hammerspoon (unlocks are in memory only —
     surviving a reboot would defeat the point). If you DO want the
     screen locking to re-lock everything, flip
     appLockRelockOnScreenLock at §6.6; it ships off.
  🐛 hide() failures used to be swallowed by a bare pcall, so a lock
     that silently did nothing looked identical to one that worked.
     They now print. Hiding also verifies 0.15s later and re-hides if
     the app bounced back, which single-shot hiding raced against.

NEW IN 6.21.1 — FIX: "Set a PIN" did nothing at all:
  🔑 The PIN dialog never appeared and the Console said nothing. The
     AppleScript was written across several lines for readability, but
     AppleScript has NO implicit line continuation (it needs a literal
     ¬), so osascript failed to COMPILE. It exited non-zero with empty
     output, which the callback read as "user typed no PIN", and the
     row looked dead. The `display dialog` statement is now built on a
     single line, and a non-zero exit is now reported in the Console
     with the offending script printed — it can't fail mute again.

NEW IN 6.21.0 — APP LOCK (§6.6, ⇪⇧L):
  🔒 A PIN gate on chosen apps. A locked app is hidden the moment it
     launches or comes to the front, and a masked PIN prompt appears;
     correct PIN un-hides it and keeps it open for 15 minutes. The
     unlock ends early when the screen locks or the Mac sleeps.
     ⇪⇧L manages everything: set/change the PIN, and toggle any
     running app in or out of the locked list.

     ⚠️⚠️ THIS IS A PRIVACY SCREEN, NOT SECURITY. It stops someone
     casually opening an app on your unlocked Mac. It does NOT stop
     anyone trying: quitting Hammerspoon removes every lock, a 4-digit
     PIN is brute-forceable in an instant by anyone who copies the
     hash file, and it cannot stop reading DATA (locking Finder does
     nothing about Terminal or `cat`). For OS-enforced app locking use
     Screen Time → Content & Privacy; for data at rest use FileVault.

     SAFE BY DEFAULT: nothing is locked until you add it yourself, and
     Hammerspoon can never be locked, so the Console is always
     reachable. Locked-but-no-PIN-set fails OPEN rather than trapping
     you. Escape hatch: delete ~/.hammerspoon/applock.json.
     The PIN hash lives in ~/.hammerspoon/applock.json — local to this
     Mac, never synced to OneDrive, and now excluded from the nightly
     backup alongside secret.lua.
     NO BEACHBALL: the prompt runs as a separate osascript process via
     hs.task. hs.dialog.textPrompt / hs.osascript block the main
     thread, which would freeze all of Hammerspoon behind a dialog you
     walked away from.

NEW IN 6.20.0 — COMMAND HISTORY PICKER (§6.5, ⇪H):
  ⌨️ Clipboard History, but for your terminal. ⇪H opens a searchable
     list of every command in command_history.log; type to filter,
     Enter copies the command to the clipboard. Newest first, and
     repeated commands collapse to a single row so a wall of identical
     lines doesn't bury everything else.
     ⚠️ THIS CONFIG DOES NOT WRITE THAT LOG — your shell does. So the
     parser accepts several formats rather than assuming one: plain
     lines, zsh EXTENDED_HISTORY (": <epoch>:0;cmd"), "[timestamp] cmd",
     "2026-07-29 03:48:12  cmd", ISO timestamps, and numbered bash
     history. A line it doesn't recognise is shown as-is rather than
     dropped. If your format is none of these, tell me and I'll add it.
     The file is re-read on every open, never cached, or commands run
     after Hammerspoon started would be invisible.
     Only the last 512 KB is read (~10,000 commands): the log grows
     forever, and reading it whole on the main thread is exactly how
     the §3.7 beachball happened.
     If no log is found, the Console lists every path it checked —
     set commandHistoryPath in §6.5 and reload.
  🔑 New: _G.hyperAddShortcut(mods, key, fn, name) — the supported way
     to add a NEW hyper shortcut. It runs through the same conflict
     sentry as everything else. (§0.4's map is only for OLD shortcuts
     that moved.)

NEW IN 6.19.0 — EVERY SHORTCUT NOW LIVES ON CAPS LOCK (⇪):
  ⇪ All 33 shortcuts moved off ⌃⌥⌘ / ⌃⌥ / ⌃⌥⇧ / ⌘⌥⇧ / ⌘⌃⌥⇧ and onto
     the hyper key. One modifier to hold instead of five combos to
     remember: ⇪A, ⇪T, ⇪V, ⇪F, ⇪/ …  The full map is in §0.4 and the
     cheat sheet (⇪/) has been rewritten to match.
     TWO TIERS, because a flat map was impossible — V, C and O each
     meant three different things and F/←/→ two apiece:
       ⇪ + key   → the 25 primary tools
       ⇪⇧ + key  → edit/delete variants + popup nudging (8)
     WINDOW KEYS ARE NOW SPATIAL: ⇪←/→ halves, ⇪↑ fill, ⇪↓ put back,
     ⇪\\ split, ⇪[ / ⇪] move a monitor. That freed F for ⇪F Files.
     🗑 REMOVED: the five app launchers (Ghostty/Chrome/Outlook/Teams/
     Sublime) that 6.17.0 added. They were never asked for, and they
     were sitting on T/C/O/S/M where the real tools belong.
     SAFETY: two boot-time self-checks, because a silently dead
     shortcut is the worst outcome here — one warns if two shortcuts
     land on the same hyper combo, the other warns if a §0.4 entry
     never matched (meaning that feature quietly kept its OLD key).
     The boot report's new "Hyper:" line shows both counts.
     Keys no shortcut claims still forward raw ⌘⇧⌃⌥ to the front app.

NEW IN 6.18.1 — FIX: endless Console errors on every Caps Lock press:
  🔇 6.18.0 forwarded F1–F12 as well. Each forwarded key is registered
     as a BARE hotkey, and macOS reserves some bare function keys
     system-wide (F11 = Show Desktop), so registering them failed with
     "RegisterEventHotKey failed: -9878 ... already registered".
     Entering the modal re-enables every binding, so that error was
     re-logged on EVERY Caps Lock press — forever. The hyper key still
     worked; the Console just filled up. Function keys are now OFF by
     default. Everything else (a–z, 0–9, arrows, punctuation, editing
     keys) is unchanged. Set hyperForwardFKeys = true at §3.12 to get
     them back and accept the noise.

NEW IN 6.18.0 — HYPER KEY IS NOW A REAL ⌘⇧⌃⌥ CHORD (§3.12):
  ⌨️ Caps Lock no longer fires only the five shortcuts below — it now
     emits the actual four-modifier chord. Caps Lock + K sends ⌘⇧⌃⌥K
     to the frontmost app, exactly as if you held all four modifiers.
     That means hyper works with ANY app you can teach a ⌘⇧⌃⌥ shortcut
     to (Raycast, Alfred, Rectangle, Slack, browser extensions, app
     prefs) — the app never needs to know Hammerspoon exists.
     Covered: a–z, 0–9, F1–F12, arrows, and the usual punctuation.
     (6.19.0 note: the app launchers this version shipped have been
     removed, and the config's own shortcuts now claim most keys —
     see the 6.19.0 entry above for the current layout.)

NEW IN 6.17.0 — HYPER KEY, NO KARABINER (§3.12):
  ⌨️ Caps Lock became a 5th modifier via hidutil (see 6.19.0 above for
     how it behaves now).
     HOW, WITHOUT AN EXTRA APP: macOS's own /usr/bin/hidutil remaps
     Caps Lock to F18 (a key in the spec that no Mac keyboard has, so
     nothing else ever sends it); Hammerspoon treats F18 as hyper.
     Nothing to install — the whole thing travels in this file, which
     is the point: same config on the work Macs, no admin install.
     Re-applied at every Hammerspoon launch, so it survives reboots
     WITHOUT the LaunchDaemon plist the usual guides require (that
     route needs admin; this one does not).
     ⚠️ HONEST LIMIT: macOS Sonoma+ restricts hidutil in some
     configurations. If it's blocked on a managed Mac the boot log
     says so plainly on the 🎹 line — it will not fail silently, and
     nothing else in this config is affected.
     ⚠️ Caps Lock no longer toggles capitals while this is on. To
     revert: set hyperEnabled = false and reload, or run
     hidutil property --set '{"UserKeyMapping":[]}'
NEW IN 6.16.23:
  🧹 File Tracker no longer logs macOS's own internal churn. It was
     filling with Photos Library guts rewriting themselves every
     hour (temp-CPAnalyticsPropertiesCache.plist, store.updates,
     live.0.indexUpdates…). Now excluded: everything INSIDE media/
     document library bundles (.photoslibrary, .musiclibrary,
     .fcpbundle, .logicx…), Spotlight index folders, .noindex
     folders, OS-internal file types (.plist, .db/.sqlite + their
     -wal/-shm siblings, .log, .lock), and sandbox atomic-save
     scratch names (foo.plist.sb-9e7584f9-3sh4il).
     The bundles THEMSELVES are still tracked — move or rename your
     Photos Library and it still logs; only its internals are quiet.
     ✏️ Edit fileTrackerNoiseBundles / fileTrackerNoiseExts in §3.8
     to tune. Verified against the exact paths from the real report.
NEW IN 6.16.22:
  🥶 FIX: the reload beachball is gone. Console timestamps pinned an
     11-SECOND main-thread freeze to App Monitor's baseline scan,
     which called hs.application.get(name) once per watched app —
     20 separate NAME RESOLUTIONS (the gap opened on hs.application's
     own "alternate names / Spotlight support" line). 6.16.8's 0.1s
     deferral had only moved it off the config-LOAD path, which is
     why "-- Done." printed instantly while the UI still locked up
     right afterward — hs.timer.doAfter runs on the MAIN thread.
     Replaced with ONE hs.application.runningApplications() call plus
     a pure-Lua name match: verified 1 bulk call and 0 name lookups,
     down from 20. Old per-name path kept as a fallback if the
     enumeration ever returns empty.
NEW IN 6.16.21:
  🔔 App Monitor's popup no longer auto-dismisses after 30s — if
     you're away when a watched app quits, it now stays on screen
     (gently pinging every 2s, same "Ping" sound) until you actually
     respond, however long that takes. Esc still dismisses it and
     posts a notification either way.
NEW IN 6.16.20:
  🚨 FIX (the REAL remaining cause, found via Console instrumentation):
     6.16.18 fixed a genuine GC bug but App Monitor still never fired.
     Live Console evidence (Ghostty AND Microsoft Teams, reproduced
     twice) showed hs.application.get(name) still reporting the app
     as RUNNING even 0.3s after its own "terminated" event — re-scan-
     via-get() is unreliably stale on this Mac. The watcher itself
     handed us the correct appName directly every time in that same
     log, so the fix trusts THAT instead: no re-scan, no re-query,
     no dependency on get() ever catching up. Falls back to the old
     re-scan only if appName is ever nil (rare safety net).
NEW IN 6.16.18:
  🚨 FIX (real bug, confirmed reproducible): App Monitor never fired
     for ANY app — Teams, Ghostty, Sublime all confirmed dead — on
     both Macs. Root cause: 6.16.8's deferred boot setup used
     hs.timer.doAfter() WITHOUT storing its return value. That's a
     real, documented Hammerspoon gotcha (confirmed against
     Hammerspoon's own GitHub issues + wiki) — an unreferenced timer
     object can be silently garbage-collected before its delay
     elapses, canceling it with no error. Fixed by holding every
     such timer in a _G. variable (arrays for ones that can have
     several in flight at once, self-removing once each fires).
     Audited the WHOLE file for this same unstored-doAfter pattern
     and fixed all of them, not just App Monitor's: File Tracker's
     rename-pairing timer, Autocorrect's injection timer, and the
     three boot-time alert timers were all equally at risk.
NEW IN 6.16.17:
  🗑 Removed the §3.12 Change History picker (⌃⌥⌘H) and its
     init_changes.csv backing file, along with the 6.16.15/6.16.16
     entries proposing/backfilling it — decided it wasn't needed.
     Changelog entries resume living here as normal, same as always.
     (If <OneDrive>/Logs/init_changes.csv already got created on a
     reload, it's harmless to leave or delete by hand — nothing
     reads it anymore.)
NEW IN 6.16.14:
  🔧 FIX: typing an assignee that matched nobody showed nothing at
     all in the new inline suggestions — indistinguishable from the
     feature being broken. Now shows a clear "No team member
     matches" row (safe no-op, can't be submitted).
  🚨 FIX (the actual reported bug): a short digit string like "1"
     typed as the assignee was blindly treated as "already a valid
     GID" and sent straight to Asana, which rejected it with a raw
     API error. Real Asana GIDs are long (15+ digits); now requires
     6+ digits before trusting it as one — anything shorter falls
     through to the roster lookup and gets the same clear "no
     match" abort-and-alert as an unresolvable name.
NEW IN 6.16.13:
  👤 The Task Creator (⌃⌥⌘T) now suggests matching Asana team members
     INLINE while you're typing the Assignee field — no more leaving
     to ⌃⌥⌘B, copying a name, and coming back. Picking a suggestion
     splices the exact name into the draft and reopens; it does not
     submit the task. Suggestions only show while still in that
     field — once you're typing the attachment path, they stop.
NEW IN 6.16.12:
  ⌨️ Standardized every Asana hotkey onto the same ⌃⌥⌘ chord:
     ⌃⌥⌘A Format URL · ⌃⌥⌘B Browse Teams (was ⌃⇧⌥M) · ⌃⌥⌘C Comment
     (was ⌃⇧⌥C) · ⌃⌥⌘T Create task · ⌃⌥⌘L List tasks/Dashboard (was
     ⌃⇧⌥A). Verified zero conflicts via the file's own §0.3 Hotkey
     Conflict Sentry (still 33 bound, 0 internal conflicts) before
     shipping — not just a manual check. Cheat sheet (⌃⌥⌘/) merged
     the old separate TASKS/DASHBOARD groups into one, matching.
NEW IN 6.16.11:
  🏷️ The ⌃⇧⌥M team picker now shows which team each person is on
     (subText, e.g. "lee@x.com · SAC Library Core Projects") — cleaned
     of the "| N. ... |" formatting. Someone on both your teams shows
     once with both names, not as a duplicate row. Search now matches
     team name too (searchSubText), so typing "core" narrows to just
     that team. Doesn't touch hs.chooser's own native ⌘+number row
     shortcuts — those aren't ours to begin with.
NEW IN 6.16.10:
  🔤 FIX: 6.16.9's team names didn't match — the real Asana team names
     include the "| N. ... |" formatting (e.g. "| 1. SAC Library Core
     Projects |"), which the boot log confirmed as two straight
     "team not found" warnings. asanaTeamNames now has the exact
     literal names.
NEW IN 6.16.9:
  👥 FIX: the Asana team-member picker (⌃⇧⌥M) searched your ENTIRE
     organization (thousands of accounts on a big org) instead of
     just your team. Now scoped to specific team(s) by name — ✏️ EDIT
     asanaTeamNames near §0.2 to change which team(s) — resolved to
     their real GIDs once at boot (GET /workspaces/{gid}/teams) and
     merged from each team's own roster (GET /teams/{gid}/users).
     Falls back to the old whole-workspace roster if the list is
     empty or a name doesn't match.
NEW IN 6.16.8:
  🥶 FIX: reload beachballed every time. Timed boot checkpoints (6.16.7,
     now removed) proved it was Hammerspoon's OWN hs.application module
     taking 5-12s on its FIRST touch on this Mac, inside App Monitor's
     boot-time baseline scan — not our loop logic (everything after it,
     incl. the whole File Tracker FSEvents setup, ran in under a
     second). Ruled out Microsoft Defender file-scanning and a
     Gatekeeper network check as the cause (delay persisted with
     Defender-excluded and with Airplane Mode on) — the cost is
     apparently inherent on this machine and outside what our code
     controls. Fix: deferred App Monitor's baseline scan + watcher
     setup by 0.1s via hs.timer.doAfter, off the synchronous boot
     path — the other 32 hotkeys are live and the reload itself
     completes instantly; App Monitor's own protection comes online a
     few seconds later in the background instead of freezing the
     whole reload.
NEW IN 6.16.6:
  🚨 FIX: 6.16.4 called hideOnLostFocus() on the report chooser — NOT
     a real hs.chooser method, so it crashed the entire config on
     load. Reverted. Escape-to-close still works (it always did,
     natively) — there's no supported way to also block click-away
     dismissal.
NEW IN 6.16.5:
  🕒 FIX: Activity Tracker counted "app left frontmost" as usage, not
     actual use — leaving VLC playing or Sublime open while away from
     the keyboard for hours inflated its total. Now stops the clock
     after 5 min of no mouse/keyboard input (hs.host.idleTime), and
     credits time only up to when idling actually began.
NEW IN 6.16.4:
  📊 Activity Tracker reports now stay on screen until you press Esc —
     clicking away no longer auto-dismisses them (hideOnLostFocus off).
  🗓 Added a second weekly-recap firing: Friday 7:30 AM, alongside the
     existing Monday 7:30 AM one.
NEW IN 6.16.1:
  🔧 FIX: App Monitor's Spawn button didn't relaunch Alfred/Bartender
     — launchOrFocus(name) needs an exact bundle name, and those ship
     versioned on disk ("Alfred 5.app"), same mismatch already fixed
     in the App Update Tracker. Spawn now resolves the real bundle
     path first (shared findAppBundle) and launches via `open -a`.
NEW IN 6.16.0 — GLOBAL COPY-ON-SELECT (§3.11, ⌘⌃⌥⇧C, off by default):
  🖱️ Highlighting text anywhere — any app, any web page — copies it
     immediately, like Ghostty's terminal selection already does.
     Built on an hs.axuielement Accessibility observer watching the
     frontmost app; re-attaches on every app switch. Auto-copies
     flow through Clipboard History (⌃⌥⌘V) exactly like a manual ⌘C.
     HONEST LIMIT: only works where an app exposes standard
     Accessibility text selection — most native apps and browser
     page content do; some Electron/custom-drawn UIs don't. Password
     fields are protected by macOS and never exposed, by design.
NEW IN 6.15.4:
  📌 Boot now prints "init.lua ARCHITECTURE VERSION: X.Y.Z" as the
     very first Console line — any pasted Console log now proves
     which file is actually loaded, instead of guessing whether a
     bug report is against the latest fix or a stale copy.
NEW IN 6.15.3:
  🔧 FIX: clipboard edit/delete (⌘⌃⌥⇧V) always said "That entry is
     gone" — it matched a choice back to _G.clipboardCache by TABLE
     IDENTITY, but hs.chooser round-trips every choice through its
     Objective-C bridge, handing the completion callback a freshly
     rebuilt table, never the original object. Identity can't
     survive that. Switched to the same snapshot+index pattern the
     OCR edit picker already used successfully (a plain number
     survives the bridge by value, which is exactly why OCR worked
     and this didn't).
NEW IN 6.15.2:
  🔧 FIX: a clipboard history that failed to parse at boot ("Error
     deserialising JSON") used to fall back to an empty cache with
     no warning — and the NEXT save (any edit or copy) then wrote
     that emptiness over the broken file, permanently losing
     whatever was still in it. That's the "one edit wiped everything"
     report. Now: a bad file is backed up (clipboard_history-
     *.json.corrupt-<timestamp>) with an on-screen warning instead
     of silently starting empty, AND every save round-trips through
     decode first — if hs.json.encode ever produces something that
     doesn't parse back, the write is ABORTED (existing file left
     alone) rather than committed.
NEW IN 6.15.1:
  🔧 FIX: the team roster fetch 404'd — /projects/{gid}/users isn't
     a real Asana endpoint (not a private-project permission issue;
     that would be a 403, and this token already reads/writes this
     exact project fine elsewhere). Switched to workspace-level user
     listing, which is both correct AND a better fit: it's every
     person in the team's Asana workspace, not just whoever's
     already a member of this one project.
NEW IN 6.15.0:
  🔧 FIX: assigning a task to "Me" or a name ("Lee") failed with
     Asana's own error — "Not a valid actor ID" — because a display
     name was sent straight to the API, which only accepts "me", a
     numeric GID, or an email. resolveAssignee (§5) now resolves a
     typed name against a cached roster of the project's team before
     ever calling the API; an unresolvable name now shows a clear
     alert and ABORTS instead of guaranteeing an API error.
  👥 ⌃⇧⌥M browses that same roster — Enter copies a member's exact
     name so pasting it into the Assignee field always resolves.
NEW IN 6.14.0 — EDIT / DELETE CLIPBOARD & OCR HISTORY ENTRIES:
  ✏️ Both histories were browse-and-copy only until now. ⌘⌃⌥⇧V opens
     the clipboard history to EDIT or DELETE an entry (searchable,
     same as ⌃⌥⌘V); ⌘⌃⌥⇧O does the same for OCR history. Selecting a
     row opens a pre-filled dialog — change the text and Save to fix
     a bad OCR read or a copy you want cleaned up, or clear the text
     entirely and Save to DELETE that entry (stated plainly in the
     dialog, no separate delete hotkey needed).
     Clipboard edits match by the entry's actual identity, not a
     list position, so a new copy landing while the picker is open
     can't make an edit land on the wrong row. OCR edits work off a
     snapshot taken the moment the picker opens, same reasoning.
NEW IN 6.13.0 — APP UPDATE TRACKER ACTUALLY INSTALLS (§3.10.1):
  🍺 HOMEBREW ONE-KEY INSTALL: a row that's both "update-available"
     AND actually tracked by Homebrew as installed (checked via
     `brew list --cask --versions` — NOT the same as merely having a
     valid cask token, since most of these 18 apps were almost
     certainly installed by direct download, not brew) now installs
     the update on Enter: `brew upgrade --cask <token>`, then
     re-checks automatically so the row reflects what really
     happened. A new "⬆️ Upgrade ALL N brew-managed app(s) now" row
     appears at the top whenever more than one qualifies, batching
     them into a single brew invocation.
     HONEST LIMIT: this is deliberately conservative — an app brew
     never installed is left alone rather than force-reinstalling
     over it (which risks a conflict prompt or clobbering settings
     outside brew's view). Needs an admin-capable account; a
     locked-down managed Mac may block it entirely.
  🌐 DOWNLOAD-PAGE FALLBACK: every app now carries its vendor's
     official download/update page. Any "update-available" row that
     ISN'T brew-managed, and Microsoft Defender's permanent "no-cask"
     row, open that page on Enter instead of just copying — covering
     exactly the apps Homebrew can't touch.
NEW IN 6.12.2:
  🔧 FIX: Alfred and Bartender showed "Not installed here" despite
     being installed — both ship a VERSIONED .app bundle name on disk
     (Alfred 5.app, Bartender 5.app), not the fixed "Alfred.app" /
     "Bartender.app" this tracker assumed. findAppBundle now falls
     back to a prefix scan of /Applications when the exact name
     isn't found, the same fix Sublime already needed a one-off
     appBundle override for — this generalizes it for any app.
  🔄 FIX: the picker only auto-refreshed on the very first-ever
     check (or the 9am timer), so a corrected cask token or bundle
     path kept showing STALE cached results from before the fix
     until the next scheduled run — which is exactly what made the
     Defender fix above look like it hadn't taken effect. ⌃⌥⇧U now
     always kicks a fresh check in the background on open, the same
     pattern the Asana Dashboard already uses — cheap for something
     you trigger deliberately, not a background poll.
NEW IN 6.12.1:
  🔧 FIX: Microsoft Defender's guessed cask token ('microsoft-defender')
     doesn't exist in Homebrew — confirmed by the Console error the
     6.12.0 self-diagnosis was designed to surface: "No Cask with
     this name exists." Turns out there's no cask for Defender at
     all — it's an enterprise product distributed via Microsoft's
     installer / MDM (Intune, Jamf), not Homebrew. Rather than guess
     another token, updateTrackerApps entries can now have cask = nil
     for exactly this case: the tracker still reads the installed
     version and shows "🔍 No Homebrew cask — check manually" instead
     of hammering brew with a lookup that can only ever fail.
NEW IN 6.12.0 — APP UPDATE TRACKER (§3.10, ⌃⌥⇧U):
  📦 Answers "which of my apps are behind right now?" so updates can
     be batched into one IT ticket instead of installed piecemeal.
     For each app in updateTrackerApps, compares the version actually
     installed (read from its own Info.plist) against the latest
     version Homebrew's Cask database knows about — which tracks
     upstream releases whether or not the app was installed via
     Homebrew. Results are cached to app_updates-<Mac>.csv, refresh
     automatically once a day, and ⌃⌥⇧U opens a searchable picker
     sorted with "update available" first.
     HONEST LIMIT: no vendor here publishes a public release
     schedule (Chrome is the closest exception — a new stable
     roughly every 4 weeks), so this reports the PRESENT, not a
     forecast. Requires Homebrew on this Mac (read-only — nothing is
     installed or changed); missing → the feature reports itself off
     in the boot log. A wrong/renamed cask token is never silent:
     brew's own error is caught and named per-app in the Console.
NEW IN 6.11.3 — ACTIVITY TRACKER: REAL APPS ONLY, NO SLEEP INFLATION:
  👁 Only regular Dock apps (hs.application kind 1) are tracked now —
     loginwindow (the lock-screen process) and ScreenSaverEngine were
     being logged as "apps" because they're whatever's frontmost while
     the screen is locked. Filtering by kind is self-updating: install
     a real app tomorrow, it's tracked automatically, nothing to
     maintain. An activityIgnoredApps table lets you exclude a real
     app by name if you ever want to.
  🛌 FIX — THE 30-HOUR GHOST: a session left open across sleep/lock
     kept its original start time, and Hammerspoon's timers pause
     during sleep while the wall clock doesn't — so waking up Monday
     after locking Friday credited whatever was frontmost at lock
     time with the ENTIRE elapsed span. A new lock/sleep watcher now
     closes the open session the instant the screen locks or the
     system sleeps, so its duration stops at the real moment of lock.
     This was also quietly padding real apps' totals any time the Mac
     slept while one was frontmost — those historical numbers were
     somewhat inflated and won't be going forward.
  🧹 One-time boot cleanup purges any loginwindow / ScreenSaverEngine
     rows already sitting in your activity_history CSV from before
     this fix — harmless no-op once the CSV is already clean.
NEW IN 6.11.2 — DIAGNOSING "FILE URL(S) BUT NO IMAGE FILES MATCHED":
  🔍 That Console line said something didn't qualify but never said
     WHAT. Now it does: the first rejected candidate per copy is
     captured and printed underneath it — either its extension
     isn't in the supported list, or it is but the path didn't
     resolve to a readable local file. Non-printable bytes in the
     preview render as "?", which immediately shows if what Finder
     handed over wasn't a plain file:// string at all.
NEW IN 6.11.1:
  🔧 FIX: copying image files in Finder did nothing — the
     pasteboard file-URL reader (hs.pasteboard.readURL) returns
     nothing on some Hammerspoon versions, and every failure was
     swallowed silently. Detection rebuilt on readAllData (the raw
     pasteboard items, where Finder reliably puts a public.file-url
     per copied file), with the old readers kept as fallbacks.
     And it now NARRATES: the Console says how many image files
     were detected on every copy, says when a file URL was seen
     but unusable, and says when the OCR shortcut is missing —
     the next miss diagnoses itself instead of being silent.
NEW IN 6.11.0 — OCR TAGS THE FILE ITSELF:
  🏷 Copy image FILES in Finder (select → ⌘C, up to 15 at once) and
     each is OCR'd via your "HS OCR" shortcut; the extracted text
     is written into the file's FINDER COMMENT (Get Info →
     Comments, capped at 500 chars) — which Spotlight and Finder
     search index. A folder of screenshots with meaningless names
     becomes searchable by what's WRITTEN IN the images. The text
     also lands in the ⌃⌥⌘O OCR history as usual.
     • Files with an EXISTING comment are never clobbered — the
       OCR still goes to history; a console line notes the skip.
     • First run macOS asks "Hammerspoon wants to control Finder"
       — click OK, or comments can't be written (Automation
       permission, System Settings → Privacy & Security).
     HONEST LIMITS: raw clipboard images (screenshots, browser
     copies) have NO file behind them — they keep going to history
     only. And Finder comments are LOCAL metadata: OneDrive does
     not sync them, so a tag written on one Mac won't appear on
     the other. (Recent macOS also finds image text natively in
     Spotlight — this makes it explicit, visible, and yours.)
NEW IN 6.10.3:
  🫥 TRANSLUCENT PANELS: the cheat sheet, the dashboard's color
     legend strip, and the Task Creator's draft mirror are now 80%
     opaque (were 92–97%), so what's behind them stays visible.
     One setting controls all three: panelAlpha in §1.5 — raise it
     toward 1.0 for more solid, lower for more see-through (text
     readability suffers below ~0.65 over bright backgrounds).
     HONEST LIMIT: the PICKER LISTS (clipboard, Task Creator,
     dashboard…) are native macOS hs.chooser panels — Hammerspoon
     exposes NO opacity control for them, and they already have
     macOS's built-in slight blur. To watch something behind a
     picker: nudge it aside with ⌃⌥⌘-arrows (the offset sticks
     until ⌃⌥⌘R), or hide the front app with ⌃⌥⌘P App Peek.
NEW IN 6.10.2:
  📖 TASK CREATOR — SEE EVERYTHING YOU TYPE (⌃⌥⌘T): the popup is
     wider (60% of the screen, was 40%), and a LIVE DRAFT MIRROR
     panel appears just above the box the moment you type — your
     entire text, word-wrapped across up to 8 lines, updating on
     every keystroke. Long titles no longer vanish past the edge
     of the field. Rides along with ⌃⌥⌘-arrow nudges; disappears
     when the popup resolves.
     HONEST LIMIT: the input field itself is a native macOS
     single-line control — Hammerspoon can't make IT wrap, which
     is why the mirror exists. The field still holds the real
     text; the mirror is where you read it.
NEW IN 6.10.1:
  📝 TASK CREATOR DRAFT PERSISTENCE (⌃⌥⌘T): whatever you've typed
     in the box now survives the popup closing — click away, press
     Esc, or accidentally Enter on a history row, and the next
     ⌃⌥⌘T restores your exact text (a "Draft restored" alert says
     so). Every keystroke updates the draft, so nothing is ever
     more than one reopen away. The draft clears ONLY when a task
     is actually created (or if you delete the text yourself).
     In-memory, like window prior-positions — a Hammerspoon reload
     starts fresh.
NEW IN 6.10.0 — ONE DATA HOME (everything syncs, work-Mac ready):
  ☁️ ALL log, note & history files now live in your OneDrive Logs
     folder (~/Library/CloudStorage/OneDrive-Personal/Logs) —
     nothing data-like is stranded in ~/.hammerspoon anymore:
       PER-MACHINE (tagged with the Mac's name, so the two Macs
       never fight over a file):
         clipboard_history-<Mac>.json · asana_history-<Mac>.json ·
         file_changes-<Mac>.csv — joining activity_history-<Mac>.csv
         and image_text-<Mac>.csv, which already lived there.
       SHARED between both Macs (learned once, works everywhere):
         autocorrect.csv (your 10,970-fix dictionary + every
         exception ⌃⌥⌘Z ever learns) · custom_shortcuts.json
         (your ⭐ cheat-sheet entries).
     Existing files are ADOPTED automatically on first boot after
     this upgrade — contents copied to the new location, originals
     left untouched in ~/.hammerspoon. Nothing already recorded is
     lost.
  🗑 File Tracker's separate daily 5 PM OneDrive copy removed —
     the live CSV itself is in OneDrive now, so the copy timer
     had nothing left to do.
  🔐 secret.lua is now EXCLUDED from the nightly rsync backup —
     your Asana token never leaves this Mac, not even into your
     own OneDrive. (Each Mac keeps its own local secret.lua.)
  ⚠️ Writes to the Logs folder that fail (OneDrive quit, or the
     folder set to online-only) now warn ON SCREEN once per file
     instead of silently losing data. Keep the Logs folder set to
     "Always keep on this device" in OneDrive.
  💻 WORK MAC: no edits needed. The portability layer already
     prefers OneDrive-Personal even when a company OneDrive is
     also signed in — so both Macs read and write the same Logs
     folder. Install = copy this file + create secret.lua there.
NEW IN 6.9.2:
  ⌨️ The five core picker hotkeys (§5: format-URL A, clipboard V,
     task creator T, activity tracker 0, OCR O) moved into an
     editable coreKeys table — they were the last hardcoded keys
     in the file. Re-keying any of them is now a one-line edit,
     checked by the Hotkey Sentry at boot. No behavior change.
NEW IN 6.9.1:
  📋 Clipboard history upgraded: 100 → 1,000 items, and search now
     matches the FULL text of every item (was only the first 100
     characters a row displays — a match deep in a long copy was
     invisible). Re-copying something moves it to the front instead
     of using a second slot; items over ~1 MB are left out of
     history so the JSON file stays fast (console line notes it).
     Render armored like every other picker. Dates now include the
     day (Jul 13 09:41), since 1,000 items span weeks.
NEW IN 6.9.0:
  📖 247 classic human typos merged into autocorrect.csv (now
     10,970 fixes): teh→the, mna→man, alot→"a lot" (multi-word
     corrections work), dont→don't (apostrophes in corrections
     work), thier, recieve, seperate, libary… — the TextExpander
     export was machine-generated transpositions and had NONE of
     them. Real-word traps (wont, cant, its, wether, lets…)
     screened out by hand, then ALL 10,970 keys machine-audited:
     zero collide with another entry's correction or with the
     ~1,200 highest-frequency English words.
  🔑 HOTKEY CONFLICT SENTRY (§0.3): every hs.hotkey.bind passes
     through a registry wrapper. Binding the same combo twice
     inside this config prints a Console warning naming it (the
     later bind silently kills the earlier feature — now it
     announces itself). Combos matching known macOS defaults
     (Spotlight, Spaces, screenshots…) are also flagged. Boot
     report shows "Hotkeys: N bound, no internal conflicts".
     Honest limit: other APPS' shortcuts have no public API and
     can't be detected — the report says so.
NEW IN 6.8.1:
  📚 TWo-caps exceptions properly researched: ~80 defaults (the
     real taxonomy — two-letter initialisms with s/ed/ing suffixes
     like DMs/TAs/IDed/DJing, plus units like MHz/GPa/MWh/MBps).
     "ITs" deliberately excluded: it's a typo of "Its" far more
     often than a plural of IT.
  ↩️ ⌃⌥⌘Z — undo & learn: a wrong TWo-caps fix is rewound (if you
     haven't typed since) AND appended as a permanent "allow" row
     in autocorrect.csv — the exception list grows itself, since
     no list of acronyms is ever complete. Wrong dictionary fixes
     rewind once; the alert names the exact CSV row to delete if
     you want that permanent (dict entries are deliberate, so
     they're never silently removed).
NEW IN 6.8.0:
  ✏️ AUTOCORRECT (§3.9, ⌃⌥⌘S toggles): fixes the word you just
     finished typing, system-wide. Dictionary corrections (mna→man,
     case-preserving: Mna→Man, MNA→MAN) live EXTERNALLY in
     autocorrect.csv (~10,700 entries would bloat this file) —
     plain text, no permissions, auto-seeded with a starter list
     if missing. TWo-caps typos (MAn→Man, THe→The) are ONE RULE,
     not data: verified to reproduce all 3,597 ⇪ rows of the
     source list, and covers words not in it; real two-caps words
     (IDs, TVs, MHz…) are "allow" rows in the CSV.
     Needs Accessibility (politely off without it — boot report
     says so); passwords are protected by macOS secure input;
     pasted/existing text never touched. Excluded-apps list +
     30s watchdog (macOS silently disables slow event taps).
NEW IN 6.7.4:
  🔧 FIX: legend was invisible over native FULL-SCREEN apps (their
     own private Space) — a canvas belongs to one Space unless it
     declares canJoinAllSpaces + fullScreenAuxiliary, which the
     picker's panel does internally and ours didn't. Both the
     legend AND the cheat sheet (same latent bug) now declare them,
     so both appear everywhere, full screen included. A console
     line now logs the legend's monitor + frame on every show, so
     any future placement issue diagnoses itself.
NEW IN 6.7.3:
  🔧 FIX: legend appeared on one monitor but not the other — the
     picker and the legend each resolved "which screen?" separately,
     a moment apart, and focus shifting as the popup opens could
     make them disagree. showPopup now RECORDS the exact placement
     it used and the legend reuses it verbatim: same monitor, same
     coordinates, always.
  🔍 Legend text enlarged to 16px; pills scaled to match, and the
     strip is clamped fully on-screen at both edges (matters on
     wide-count days and on monitors left of the main display).
NEW IN 6.7.2:
  🔧 FIX: legend strip overlaid the bottom of the task list — its
     below-the-picker position relied on estimating the picker's
     height, and the estimate ran short. Now sits just ABOVE the
     search field, where placement is exact (we set the picker's
     top-left ourselves) — overlap is impossible by construction.
     Clamped so nudging the picker to the screen top can't push the
     strip off-screen.
NEW IN 6.7.1:
  🎨 Color legend strip under the dashboard picker: one pill per
     category (red Overdue, yellow Due today, blue Due this week,
     orange Due later, purple No due date) with the number of rows
     each contributed. Empty categories show no pill. Appears when
     the dashboard opens, follows ⌃⌥⌘-arrow nudges, and disappears
     when the picker resolves (pick, Esc, or click away). Built on
     hs.canvas since hs.chooser has no footer of its own — its
     position is estimated from row count, so it may sit a few px
     off if a macOS update changes row heights (cosmetic only).
NEW IN 6.7.0:
  📅 Dashboard rebuilt (drop-in Section 6 replacement): up to 100
     tasks across five capped categories, in this order —
     🔴 Overdue (max 40, newest due first), 🟡 Due today (max 10),
     🔵 Due this week (max 30, soonest first), 🟠 Due later
     (max 10, soonest first), 🟣 No due date (max 10, newest
     created first, listed last). Category names capitalize the
     first word only. Caps live in the asanaCaps config table.
     Both ⌃⇧⌥A (open) and ⌃⇧⌥C (comment) modes unchanged.
NEW IN 6.6.0:
  📅 Dashboard (⌃⇧⌥A / ⌃⇧⌥C) now shows EVERY incomplete task, not
     just dated-within-a-week ones: new ⚪️ NO DUE DATE bucket
     (newest created first — where fresh tasks live, fixing "recent
     tasks don't show") and 🟣 LATER bucket (due beyond this week,
     soonest first). Order: overdue → today → this week → no due
     date → later. Fetch limit set to 100 tasks explicitly.
NEW IN 6.5.2:
  🔧 FIX: Task Creator went BLANK when the attachment field held a
     folder path (trailing slash) — basename extraction returned nil
     and crashed the render callback, which leaves a chooser empty.
     Fixed, and ALL THREE searchable popups (tasks, activity, file
     tracker) are now armored: a render error shows an error row
     pointing at the Console instead of a silent blank window.
NEW IN 6.5.1:
  🔒 Asana token hardening: whitespace around the token in
     secret.lua is trimmed (a trailing space is invisible but causes
     a 401 identical to a revoked token), the token's shape is
     sanity-checked at boot (catches smart quotes / truncated
     pastes), and a 401 now says "revoked or mistyped — make a new
     token" instead of a bare status code.
NEW IN 6.5.0:
  🗑 All-display brightness REMOVED (§1.10, its event tap and its
     30s watchdog): unused, and only ever helped Apple/LG external
     displays. F1/F2 are now purely stock macOS. Nothing else
     touched — one less always-running listener.
NEW IN 6.4.1:
  🔧 FIX: 6.4.0 consumed F1/F2 and re-applied brightness itself —
     on Macs where setBrightness silently no-ops, that killed the
     keys entirely. Redesigned to NEVER consume: macOS handles the
     built-in display natively (keys can't break, by construction)
     and we mirror the resulting level to other supported displays
     a beat later. Headless Macs get manual stepping. Key-hold
     events coalesce into one trailing sync.
NEW IN 6.4.0:
  🔆 All-display brightness (§1.10): F1/F2 now adjust EVERY display
     macOS can control, in sync (native rebuild of the AllBrightness
     Spoon, ~50 lines). Self-healing: any failure passes the key
     back to macOS (stock behavior, never broken keys) and a 30s
     watchdog revives the listener if macOS disables it. Externals
     respond only if Apple/LG UltraFine (macOS limit — DDC monitors
     need MonitorControl/Lunar).
NEW IN 6.3.1:
  📁 ~/.hammerspoon is now TRACKED by the File Tracker despite being
     a hidden folder — init.lua swaps, secret.lua changes, and JSON
     creations all get a paper trail. Still excluded within it: the
     tracker's own CSV, hidden items, and the logs/ fallback folder.
     JSON rewrites stay silent (Modified events aren't logged).
NEW IN 6.3.0:
  📁 File Tracker now watches the ENTIRE home folder + OneDrive:
     ~/Library excluded (except OneDrive, which gets its own
     watcher), hidden folders/files excluded, own telemetry (Logs
     CSVs, Backups/Hammerspoon) excluded so it never logs itself,
     and a burst guard suppresses Created-row floods (unzips, mass
     exports) — renames/moves are never suppressed. Note: OneDrive
     sync means the other Mac's OneDrive file changes appear here
     too. Exclusion logic verified against 10 boundary cases.
NEW IN 6.2.0:
  📁 File Tracker (§3.8, ⌃⌥⇧F): logs renames, moves, renamed+moved,
     copies & created files in Desktop/Documents/Downloads (editable
     list) with old→new names & folders. Searchable picker; Enter
     copies a row. 90-day history in local Excel-ready
     ~/.hammerspoon/file_changes.csv, copied daily at 5:00 PM to
     OneDrive Logs (machine-tagged). Temp/hidden files ignored.
     Note: macOS reports a copy's destination only — sources of
     copies are unknowable via FSEvents.
NEW IN 6.1.1:
  🔍 secret.lua diagnostics: the boot report now distinguishes
     "missing" from "broken" (with the exact Lua error), and a
     broken file raises an on-screen alert instead of silently
     looking like a missing one.
NEW IN 6.1.0 — TWO MACS, ONE ONEDRIVE, NO COLLISIONS:
  🏷 Per-machine identity (hostTag from the Mac's name): activity &
     OCR CSVs are tagged per machine and backups go to
     Backups/Hammerspoon/<MachineName>/ — two Macs syncing the same
     Personal OneDrive can no longer create conflict copies or
     overwrite each other's backups. Existing untagged files are
     adopted automatically (originals left untouched).
  ♿️ Accessibility status in the boot PORTABILITY REPORT, with a
     pointer alert when not granted (window features inactive until
     then; everything else unaffected).
NEW IN 6.0.0 — PORTABLE ARCHITECTURE (work + personal Mac, one file):
  🧭 §0.1 Portability layer: OneDrive auto-detected per machine
     (OneDrive-Personal preferred, any OneDrive-* accepted, local
     ~/.hammerspoon/logs fallback). Override variables provided.
     Daily backup auto-disables where there's no cloud destination.
  🔐 §0.2 Credentials moved OUT of this file into per-machine
     ~/.hammerspoon/secret.lua — init.lua is now secret-free and
     freely copyable. No secret.lua → Asana features politely off.
  📴 Graceful degradation: Asana hotkeys gated; image OCR checks at
     boot whether this Mac's Shortcuts app has the OCR shortcut.
  🧾 Boot PORTABILITY REPORT in the Console + status in the ready
     alert. Manifest rewritten. Dead activityLogFile var removed.
(Older 4.x / 5.x changelog entries unchanged — see version history
 in your backups if ever needed.)
```
