# Installing this config — the work Mac included

A new Mac, a wiped Mac, or a second one. Follow this top to bottom and you
get an identical working setup — same shortcuts, same behaviour, same data.

**Time:** about 20 minutes, most of it waiting for a download.

**Admin rights: NOT REQUIRED.** Every required step works on an IT-managed
Mac with no admin password. What IT *may* need to allow is listed in one
place — see **What IT has to say yes to** at the bottom — and the config
runs, degraded but honest, even if they say no to all of it.

> ### 🚨 THE ONE THING PEOPLE GET WRONG
> The files must end up in **`~/.hammerspoon`** — a hidden folder in your
> home directory. Unpacking the archive into `~/Downloads` and reloading
> does **nothing**: Hammerspoon never looks there. Step 3 is the step that
> moves them, and it prints what it did. If you skip it or it fails, every
> later step fails too, and the symptom is "nothing happened".
>
> One command tells you whether this Mac is installed at all:
> ```sh
> ls ~/.hammerspoon/init.lua && sed -n 7p ~/.hammerspoon/init.lua
> ```
> ✅ **Success:** a path, then `-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.2xx.x`
> ❌ **Failure:** `No such file or directory` — you are not installed. Go to Step 3.

---

## How to read this

Every step has a ✅ and a ❌. Run the check, look at which one you got.
If you got ❌, the fix is on the same line — you do not have to guess, and
you do not have to ask me before trying it.

A step marked **[optional]** can be skipped entirely. The config detects
it is missing, turns that one feature off, and says so in its own report.
Nothing else is affected.

---

## What you end up with

```
~/.hammerspoon/
├── init.lua              the orchestrator — profiles, hyper key, pickers
├── secret.lua            YOUR Asana token. Per-machine. Never synced.
├── core/                 12 files, loaded directly by init.lua
│   ├── diagnostics.lua       ⇪⇧D
│   ├── cheatsheet.lua        ⇪/
│   ├── boot_report.lua       the Console's first two lines
│   ├── boot_cost.lua         where the boot time went (silent unless it was slow)
│   ├── key_trail.lua         the last two dozen ⇪ shortcuts and how long each took
│   ├── capabilities.lua      what works on THIS Mac
│   ├── coexist.lua           who gets Esc, the screen, the keyboard
│   ├── hyper_key.lua         ⇪'s second way in, and the proof it works
│   ├── changelog_csv.lua     one Excel-ready row per version
│   ├── console.lua           the ⛔ ERRORS + ⚠️ NONBREAKING sections + repeat limiter
│   ├── lag.lua               which tap is eating the keystroke — OFF unless ~/.hammerspoon/LAGPROBE exists
│   └── notices.lua           the failure ledger — nothing fails silently
├── modules/              71 files, loaded by the §1.12 loader
├── snippets/
│   └── bundled.lua       1,926 public snippets — ships in the archive
├── tools/                hs-doctor.sh · hs-install.sh · run-tests.sh · hs-stall-guard.sh
├── TESTING.md            how to score this release
├── RESOLVED-FEATURE-REQUESTS.txt   every feature and how to use it
└── logs/                 only if there is no OneDrive on this Mac
```

Everything lives under your home folder. **Nothing is installed
system-wide, nothing needs sudo, nothing touches /Library.**

---

## Step 1 — Install Hammerspoon

Download from **https://www.hammerspoon.org** and drag `Hammerspoon.app`
to **`/Applications`**.

**If macOS refuses** — "you don't have permission" — drag it to
**`~/Applications`** instead. Make that folder first if it does not exist:

```sh
mkdir -p ~/Applications
```

It works identically from there. Nothing in this config cares where the
app lives.

Launch it once. macOS will ask "are you sure you want to open it" the
first time — that is Gatekeeper, not IT, and clicking Open is enough.

**Set it to start at login:** menu bar hammer → *Preferences* → tick
*Launch Hammerspoon at login*.

✅ **Success:** a hammer icon in your menu bar.
❌ **Failure — "cannot be opened because the developer cannot be
verified":** right-click the app → *Open* → *Open*. That is the
documented way past Gatekeeper and needs no admin.
❌ **Failure — the app is blocked by your organisation:** this is the one
thing IT must allow. See the bottom section; there is no workaround.

> **Why not `brew install hammerspoon`?** You do not need Homebrew for any
> of this, and on the work Mac you probably cannot have it. The direct
> download is the same application.

---

## Step 2 — Grant Accessibility

Menu bar hammer → *Preferences* → it prompts, or do it directly:

**System Settings → Privacy & Security → Accessibility → turn Hammerspoon on**

You may have to click the padlock. On a managed Mac you can usually
unlock it with **your own login password** — this is a per-user setting,
not a system one. Try before assuming you cannot.

✅ **Success:** Hammerspoon appears in that list with its switch ON.
❌ **Failure — the switch will not stay on:** IT has an MDM profile
blocking it. **Keep going anyway.** You lose only the features that move
or hide *other apps'* windows — Window Arranger, App Peek, app summon,
Window Return. Every hotkey, picker, tracker, snippet and Asana feature
still works.
❌ **Failure — Hammerspoon is not in the list at all:** launch it once
first; it only appears after it has asked.

> **Important:** Accessibility is read when Hammerspoon **launches**. If
> you grant it while Hammerspoon is running, **Quit and relaunch** — a
> Reload is not enough.

---

## Step 3 — Put the files in `~/.hammerspoon` 🚨

**This is the step that matters.** It is the one that was easy to miss.

### 3a. Unpack the archive

The download is a **`.tar.gz`**. macOS unpacks it on a double-click
exactly as it unpacks a `.zip` — or do it in Terminal, which is more
predictable:

```sh
mkdir -p ~/Downloads/hs-new
tar -xzf ~/Downloads/hammerspoon*.tar.gz -C ~/Downloads/hs-new
```

✅ **Success:**
```sh
ls ~/Downloads/hs-new
```
shows `init.lua`, `core`, `modules`, `snippets`, `tools`, `TESTING.md`.

❌ **Failure — the folder is empty or has only one item:** the download
did not arrive whole. Check it before going on:

```sh
tar -tzf ~/Downloads/hammerspoon*.tar.gz | wc -l     # entries
sed -n 7p ~/Downloads/hs-new/init.lua                # the version
```
✅ ~190 entries and a version line. ❌ `0`, an error, or nothing — download
it again. **Do not install a partial archive.**

❌ **Failure — you double-clicked and got a folder inside a folder:** look
for `init.lua`. Whichever folder directly contains `init.lua` is the one
to use below. There is no wrapper folder in the archive itself, but Safari
sometimes adds one.

### 3b. See what the installer WOULD do

```sh
sh ~/Downloads/hs-new/tools/hs-install.sh ~/Downloads/hs-new --dry-run
```

This changes **nothing**. Read the output. It names every folder it would
write and where.

✅ **Success:** it lists `core/ : 9 files ✅ present`, a modules count, and
a `snippets/: bundled.lua (…bytes)` line.
❌ **Failure — "this init.lua needs a core/ folder and your download has
none":** you are pointing it at the wrong folder, or the archive is
partial. Back to 3a.

### 3c. Install for real

```sh
sh ~/Downloads/hs-new/tools/hs-install.sh ~/Downloads/hs-new
```

It backs up whatever is already there, installs, verifies, and **rolls
itself back if the verify fails**. It refuses to run as root.

✅ **Success:** lines reading `core/ ✅`, `modules/ ✅`, `snippets/ ✅
bundled.lua`, and a final verify that passes.

❌ **Failure — "Operation not permitted":** Terminal has not been given
access to your home folder. **System Settings → Privacy & Security →
Files and Folders → Terminal → allow Downloads folder.** No admin needed.

❌ **Failure — anything else:** nothing has changed; the script rolls back
on its own. Send me the output.

### 3d. Prove it landed

**Do not skip this.** This is the check that would have caught the work
Mac:

```sh
ls ~/.hammerspoon/init.lua
sed -n 7p ~/.hammerspoon/init.lua
ls ~/.hammerspoon/core | wc -l
ls ~/.hammerspoon/modules | wc -l
ls ~/.hammerspoon/snippets/bundled.lua
```

✅ **Success:** a path · the version line · `12` · `71` · a path.
❌ **Failure — any "No such file or directory":** the install did not
happen. Re-run 3c and read its output rather than re-running blindly.

> **Never just `cp init.lua`.** `init.lua` alone produces a config that
> starts, looks fine, and has silently lost ⇪/ and ⇪⇧D because `core/` is
> missing. That is the single most common way to break this install, and
> it is exactly why the script exists.

**Undo any install:** `sh ~/.hammerspoon/tools/hs-install.sh --rollback`

---

## Step 4 — Reload and read the boot line

Menu bar hammer → **Reload Config**.

Open the Console (menu bar hammer → *Console*). A healthy boot is two
lines:

```
🧭 Lees-MacBook-Air  ·  71 modules  ·  106 ⇪ shortcuts  ·  0.13s
   All green.  ⇪ is proven on your next Caps Lock press.  ⇪⇧D diagnostic report
```

✅ **Success:** your machine's name, a module count, "All green", and a
boot under a second.

❌ **Failure — nothing at all in the Console:** the files are not in
`~/.hammerspoon`. Back to Step 3d.

❌ **Failure — red text / a Lua error:** run, in Terminal:
```sh
sh ~/.hammerspoon/tools/hs-doctor.sh
```
It works even when Hammerspoon does not, reports what is actually on
disk, and names the missing piece. Send me its output.

❌ **Failure — it boots but says fewer modules than you expect:** that is
normal if a profile turned some off; it is not an error.

---

## Step 5 — Check what this Mac can actually do

In the **Hammerspoon Console**:

```lua
_G.capabilityReport()
```

This is the single most useful command on a work Mac. It prints every
capability, whether it is on, why, and — when it is off — exactly what
that costs you.

✅ **Success:** a list with most rows on. Rows that are off name their
reason.
❌ **Failure — "attempt to call a nil value":** `core/` did not install.
Step 3d.

Then, in **Terminal**:

```sh
sh ~/.hammerspoon/tools/hs-doctor.sh
```

Read-only. It reports every external command this config will run and
whether it exists on **this** Mac, and every path it writes to.

---

## Step 6 — Snippets (they already work — here is how to tell)

**The 1,926 public snippets ship inside the archive** and Step 3 put them
in place. There is nothing to install, nothing to download, and no
Homebrew involved.

Where they live: `~/.hammerspoon/snippets/bundled.lua` — one generated
file, about 123 KB, read once at boot.

### Check them

Press **⇪⇧S**.

✅ **Success:** a picker with sections — emoji, compose sequences and the
packs. Type to filter; ⏎ inserts one.

In the Console:
```lua
_G.snippetsList()
```
✅ **Success:** a count in the thousands and the collection names.
❌ **Failure — 0 snippets:** `ls ~/.hammerspoon/snippets/bundled.lua`. If
that file is missing, Step 3 did not copy it — re-run 3c.

### Type one

Snippet expansion is a keyboard tap, so it needs **Accessibility**
(Step 2). Type a trigger in any app.

✅ **Success:** it expands as you type.
❌ **Failure — the picker works but typing a trigger does nothing:**
Accessibility is off, or was granted after launch. Quit and relaunch
Hammerspoon, then `_G.capabilityReport()`.

### 🔑 Your OWN snippets (textpanders) — the part that needs a decision

Your private snippets are **not** in the archive, by design: they hold
real addresses, a phone number and an employee ID, so they are never put
in the repo or in a release.

They live in your **OneDrive Logs folder**, at `<Logs>/snippets`, and this
config reads that folder **in addition to** the bundled one. Anything
there wins a name collision, so your own version always beats a shipped
one.

**On the work Mac you have two ways to get them:**

**Option A — sign into the same OneDrive.** Nothing else to do. The folder
appears, and the next reload picks it up.

**Option B — copy the folder by hand** (if OneDrive is not allowed at
work):
```sh
mkdir -p ~/.hammerspoon/logs/snippets
# then copy your textpanders folder into it from a USB stick or Downloads
```
Then in the Console: `_G.snippetsList()` — your section should appear at
the top of ⇪⇧S.

> ⚠️ **Think before you do Option B on a work Mac.** That folder holds your
> home address, your phone number and an employee ID. Copying it onto an
> IT-managed machine puts it on a disk your employer administers and may
> back up. The public 1,926 snippets work without it. My advice: leave
> textpanders off the work Mac unless you need a specific one, and add
> that single snippet by hand instead.

---

## Step 7 — [optional] Asana: `secret.lua`

This file is **per-machine and deliberately never synced or backed up**. It
is not in the archive. Create it by hand:

```sh
cat > ~/.hammerspoon/secret.lua <<'EOF'
return {
    asanaToken       = "PASTE_YOUR_PERSONAL_ACCESS_TOKEN_HERE",
    -- Optional. These are IDs, not secrets.
    asanaWorkspaceId = "182448385076670",
    asanaProjectId   = "745948257030523",
}
EOF
chmod 600 ~/.hammerspoon/secret.lua
```

Get a token at **https://app.asana.com/0/my-apps** → *Personal access
tokens* → *Create new token*.

✅ **Success:** press ⇪T — the task form opens and can create a task.
❌ **Failure — "broken: file doesn't return a table":** the file exists
and has a typo. **It must start with the word `return`.**
❌ **Failure — Asana features say they are off:** no `secret.lua`. Nothing
else is affected.

> On a work Mac, check your employer's policy before putting a personal
> Asana token on it. `chmod 600` means only your account can read the
> file, but it is still on their disk.

---

## Step 8 — [optional] This machine's name

```sh
scutil --get ComputerName
```

Open `~/.hammerspoon/init.lua`, search for `_G.moduleProfiles`, and check
there is an entry matching that name exactly (spaces become hyphens —
`Lee's MacBook Air` becomes `Lees-MacBook-Air`).

**If there is no matching entry the config uses `default`, which loads
everything. Nothing breaks either way.** A profile only exists so you can
turn modules *off* on a particular machine.

Tell me the work Mac's name and I will ship a profile for it — that is one
line in a release, and it is how we switch off anything that misbehaves
there without you editing `init.lua`.

---

## Step 9 — [optional] The OCR shortcut

Only needed if you want copied images read for text.

1. Open **Shortcuts.app**
2. New shortcut named exactly **`HS OCR`**
3. One action: **Extract Text from Image**, input = *Shortcut Input*
4. In the shortcut's details set *Receive: Images*

✅ **Success:** copy an image, then press ⇪O — the text is searchable.
❌ **Failure:** image OCR reports itself off. Nothing else changes.

Shortcuts.app ships with macOS. No admin, no IT.

---

## Step 10 — [optional] Extra command-line tools

**None of these are required. The config works without every one of
them** and says so in `hs-doctor.sh`.

Everything else this config runs — `osascript`, `sqlite3`, `rsync`,
`grep`, `find`, `sips`, `mdfind`, `screencapture`, `shortcuts`, `open`,
`defaults`, `hidutil` — **already ships with macOS**. Nothing to install.

| Tool | Powers | Without it |
|---|---|---|
| `blueutil` | ⇪⇧7 connects/disconnects Bluetooth devices | ⇪⇧7 still lists paired devices; ⏎ opens System Settings |
| `speedtest` | the network speed row | that row says it is unavailable |
| `zbarimg` | QR codes in screenshots | QR reading is off |
| `wn` (WordNet) | ⇪; definitions | definitions are off |

These come from Homebrew. **On a Mac with no admin rights you can install
Homebrew into your home folder** — no sudo, nothing system-wide:

```sh
mkdir -p ~/homebrew
curl -L https://github.com/Homebrew/brew/tarball/master \
  | tar xz --strip 1 -C ~/homebrew
echo 'export PATH="$HOME/homebrew/bin:$PATH"' >> ~/.zprofile
```

Open a new Terminal window, then e.g. `brew install blueutil`.

The config searches `~/homebrew`, `~/.homebrew` and `~/.local/homebrew`
**before** the admin locations, so a home-folder Homebrew is found
automatically.

✅ **Success:** `which brew` prints a path under your home folder.
❌ **Failure — `curl` is blocked:** your network filters GitHub. Skip this
whole step; four small features stay off and nothing else changes.

---

## Step 11 — Confirm it works

| Press | Expect |
|---|---|
| ⇪/ | the cheat sheet — every tool, searchable, punctuation included |
| ⇪⇧D | a diagnostic report, also copied to your clipboard |
| ⇪⇧S | your snippets — ⏎ inserts one |
| ⇪X | the mouse grid — type a cell's 3 letters, the pointer jumps there |
| ⇪D | every installed app — type a name, ⏎ launches it |
| ⇪N | Hamsidian |
| ⇪3 | Hamsidian, on the notes side |
| ⇪⇧U | link what is in front of you to a note |
| ⇪4 | screenshot an area, with a live pixel size readout |
| ⇪V | clipboard history |
| ⌥Tab | the window switcher |

**If ⇪ does nothing at all**, the Caps Lock remap was refused. Run
`_G.capabilityReport()` — it will say so and why. Everything not on ⇪
still works.

---

## What IT has to say yes to

Take this list to them. It is short, and three of the four are
per-user settings you can usually turn on yourself.

| What | Why | If they say no |
|---|---|---|
| **Allow Hammerspoon to run** | It is an unsigned-by-Apple-Store open-source automation app. This is the only hard requirement. | Nothing works. There is no workaround. |
| **Accessibility for Hammerspoon** | Lets it see key presses and move windows. | Keyboard shortcuts, snippets and pickers still work; only window-moving features are lost. |
| **Screen Recording for Hammerspoon** | Only for ⇪5 scrolling screenshots. | ⇪4 and ⇪⇧1 still work; ⇪5 says it cannot. |
| **Automation → Hammerspoon → Finder / Chrome** | Lets ⇪⇧A read the Finder selection and ⇪⇧U read a browser tab. | Those two read nothing and say so. |

**What IT does NOT have to allow — say this explicitly, it heads off
most objections:**

- **No admin password is needed** for any step above.
- **Nothing is installed system-wide.** Everything is in your home folder.
- **No sudo, ever.** The config refuses to run anything as root, including
  its own installer.
- **No LaunchAgent, no launchd, no login item other than the app itself.**
  Even the stall guard is an ordinary shell script started by Hammerspoon
  as you, in your own folder.
- **No network listening.** It makes outbound calls only to Asana (if you
  add a token) and a speed test (if you install one).
- **No kernel extension, no profile, no certificate.**
- **It can be removed by deleting one folder:** `rm -rf ~/.hammerspoon`
  and dragging the app to the Trash.

### Minimising what you have to ask for

If you want to ask for as little as possible, ask for **the app** and
**Accessibility** only. That is the 90% configuration: every shortcut,
picker, snippet, tracker, the clipboard history, Hamsidian and the
screenshots all work. Add Screen Recording and Automation later, once it
has been running quietly for a few weeks and is no longer a novelty.

---

## Troubleshooting

**"I installed it and nothing happened"**
Nine times out of ten the files are not in `~/.hammerspoon`. Run the check
in the box at the top of this file.

**Hammerspoon will not start / red errors on reload**
```sh
sh ~/.hammerspoon/tools/hs-doctor.sh
```
Works even when Hammerspoon does not.

**Something worked before this install**
```sh
sh ~/.hammerspoon/tools/hs-install.sh --rollback
```
Restores the previous version. Then Reload Config.

**A shortcut does nothing**
`_G.capabilityReport()` in the Console. Most dead shortcuts are one of:
Accessibility not granted, the hyper remap refused, or no `secret.lua`.

**An alert or panel does not appear**
```lua
_G.alertReport()        -- did macOS refuse to draw a message?
_G.canvasShowReport()   -- did macOS refuse to draw a panel?
```

**An empty rounded window is stuck on screen**
A half-drawn alert: another app's popup made macOS throw mid-draw. The
config sweeps and retries these itself; for one that got through, run
`_G.phantom()` in the Console — and Reload Config clears it for certain.

**I want the long boot report back**
```lua
_G.bootVerbose(true)     -- persists across reloads
_G.bootReport()          -- or print it once, right now
```

**I need more detail while reproducing a bug**
```lua
_G.diag.verbose = true   -- until the next reload
```
Everything is recorded to the trail either way — ⇪⇧D includes the last 25
events whether verbose was on or not.

---

## Moving to a second Mac

1. Steps 1–4 exactly as above.
2. Create a **new** `secret.lua` on that machine — do not copy it.
3. Tell me the machine's name so it gets a profile (Step 8).
4. Sign into the same OneDrive if you want shared history. Per-machine
   files are tagged with the computer name so the two never overwrite each
   other; `autocorrect.csv` and `custom_shortcuts.json` are shared on
   purpose.

No OneDrive on that Mac is fine — logs fall back to `~/.hammerspoon/logs`
and the daily backup turns itself off.

---

## Before you ship a change (development only)

```sh
sh <the unpacked folder>/tools/run-tests.sh <the unpacked folder>
```

Run it from the **unpacked archive, before Step 3** — `hs-install.sh` does
not copy `tests/`, so pointed at the installed copy it reports every Lua
stage as missing. That is a skip, not a pass.

Needs `lua` and `node`, neither of which ships with macOS, so this is a
personal-Mac tool. **On the work Mac use `hs-doctor.sh`, which needs
nothing.**
