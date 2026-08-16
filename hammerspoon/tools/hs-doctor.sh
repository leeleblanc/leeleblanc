#!/bin/bash
# hs-doctor — one command that answers "what is actually installed and
# is it intact?" without needing Hammerspoon to be working.
#
#   bash ~/hs-doctor.sh          # then paste the whole output back
#
# Why this exists: most of our lost time has gone on ME GUESSING at your
# machine's state — which file landed, which version is live, whether a
# copy silently failed. This replaces the guessing with facts. It only
# reads; it changes nothing.

HS="${1:-$HOME/.hammerspoon}"

# stat differs between BSD (macOS) and GNU, and the BSD form SUCCEEDS with
# garbage on GNU rather than failing — so switch on the OS, not on exit code.
if [ "$(uname)" = "Darwin" ]; then
  mtime () { stat -f '%Sm' -t "$2" "$1" 2>/dev/null; }
else
  mtime () { stat -c '%y' "$1" 2>/dev/null | cut -c1-16; }
fi
echo "════════════════════════════════════════════════════════════"
echo " HAMMERSPOON DOCTOR   $(date '+%Y-%m-%d %H:%M')"
echo " config: $HS"
echo "════════════════════════════════════════════════════════════"

# ---- 1. is the app even running? -------------------------------------
echo
echo "── 1. IS HAMMERSPOON RUNNING ──"
if pgrep -x Hammerspoon >/dev/null 2>&1; then
  echo "   ✅ running (pid $(pgrep -x Hammerspoon | tr '\n' ' '))"
else
  echo "   ❌ NOT RUNNING — that alone explains every dead shortcut."
  echo "      Launch it from Applications, then run this again."
fi

# ---- 2. init.lua ------------------------------------------------------
echo
echo "── 2. init.lua ──"
if [ ! -f "$HS/init.lua" ]; then
  echo "   ❌ MISSING at $HS/init.lua — nothing can work without it."
else
  ver=$(grep -m1 '_G.configVersion' "$HS/init.lua" | sed 's/.*"\(.*\)".*/\1/')
  lines=$(wc -l < "$HS/init.lua" | tr -d ' ')
  bytes=$(wc -c < "$HS/init.lua" | tr -d ' ')
  echo "   version : ${ver:-UNKNOWN}"
  echo "   size    : $lines lines, $bytes bytes"
  echo "   modified: $(mtime "$HS/init.lua" '%Y-%m-%d %H:%M')"
  # A truncated download is the classic silent failure: the file exists,
  # looks fine, and is missing its tail.
  if tail -3 "$HS/init.lua" | grep -q 'Core Systems Booted\|^end\|^)' ; then
    echo "   tail    : ✅ looks complete"
  else
    echo "   tail    : ⚠️  LAST LINE IS: $(tail -1 "$HS/init.lua" | cut -c1-60)"
    echo "             If that looks mid-sentence, the file is TRUNCATED."
  fi
  # Anchors from the START, MIDDLE and END of the file. A truncated
  # download keeps the head and loses the tail, so a missing late anchor
  # is the tell — and it is the failure that looks like nothing at all.
  miss=""
  for a in "_G.configVersion" "moduleProfiles" "loadModules" "Core Systems Booted"; do
    grep -q "$a" "$HS/init.lua" || miss="$miss $a"
  done
  if [ -z "$miss" ]; then
    echo "   anchors : ✅ head, middle and tail all present"
  else
    echo "   anchors : ❌ MISSING:$miss  → the file is incomplete, re-copy it"
  fi
fi

# ---- 3. secret.lua ----------------------------------------------------
echo
echo "── 3. secret.lua (Asana token) ──"
if [ -f "$HS/secret.lua" ]; then
  echo "   ✅ present ($(wc -c < "$HS/secret.lua" | tr -d ' ') bytes) — contents NOT shown"
else
  echo "   ⚠️  missing — Asana features stay off, everything else is fine"
fi

# ---- 4. modules -------------------------------------------------------
echo
echo "── 4. MODULES ──"
if [ ! -d "$HS/modules" ]; then
  echo "   ❌ no modules/ folder at $HS/modules"
else
  printf "   %-22s %7s  %-16s %s\n" NAME BYTES MODIFIED NOTE
  for f in "$HS/modules"/*.lua; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .lua)
    b=$(wc -c < "$f" | tr -d ' ')
    m=$(mtime "$f" '%m-%d %H:%M')
    note=""
    [ "$n" = "init" ] && note="⚠️ STRAY init.lua — should NOT be in modules/"
    printf "   %-22s %7s  %-16s %s\n" "$n" "$b" "$m" "$note"
  done
  echo "   count: $(ls -1 "$HS/modules"/*.lua 2>/dev/null | wc -l | tr -d ' ') files (expect 40)"
fi

# ---- 4b. core ---------------------------------------------------------
# 6.44.11 moved three big blocks out of init.lua into core/. They are NOT
# loader-managed: init.lua dofile's them at a fixed point, and a missing
# one costs you that feature for the session. Worth checking explicitly,
# because copying init.lua alone now leaves an install half-updated —
# exactly the mistake this whole script exists to catch.
echo
echo "── 4b. CORE (dofile'd by init.lua, NOT loader-managed) ──"
if [ ! -d "$HS/core" ]; then
  echo "   ❌ no core/ folder at $HS/core"
  echo "      With 6.44.11+ this means ⇪/ (cheat sheet), ⇪⇧D (diagnostics)"
  echo "      and the boot summary are all OFF. Copy the core/ folder across."
else
  printf "   %-22s %7s  %-16s %s\n" NAME BYTES MODIFIED NOTE
  for n in diagnostics cheatsheet boot_report capabilities notices coexist hyper_key changelog_csv; do
    f="$HS/core/$n.lua"
    if [ -f "$f" ]; then
      printf "   %-22s %7s  %-16s %s\n" "$n" \
        "$(wc -c < "$f" | tr -d ' ')" "$(mtime "$f" '%m-%d %H:%M')" ""
    else
      printf "   %-22s %7s  %-16s %s\n" "$n" "-" "-" "❌ MISSING"
    fi
  done
  echo "   count: $(ls -1 "$HS/core"/*.lua 2>/dev/null | wc -l | tr -d ' ') files (expect 8)"
fi

# ---- 4c. what this config will actually run ---------------------------
# THE WORK-MAC QUESTION, answered on the work Mac itself: what external
# programs does this config invoke, do they exist here, and does any of
# it need admin? Everything below except brew ships with macOS. Nothing
# here is installed, nothing runs as root, nothing writes outside $HOME.
echo
echo "── 4c. EXTERNAL COMMANDS THIS CONFIG RUNS ──"
printf "   %-22s %-9s %s\n" BINARY PRESENT PURPOSE
check_bin () {
  if [ -x "$1" ]; then p="yes"; else p="MISSING"; fi
  printf "   %-22s %-9s %s\n" "$1" "$p" "$2"
}
check_bin /usr/bin/curl      "Asana API + attachments (macOS built-in)"
check_bin /usr/bin/shortcuts "image OCR via your Shortcut (macOS built-in)"
check_bin /usr/bin/hidutil   "Caps Lock -> hyper, per-user (macOS built-in)"
check_bin /usr/bin/open      "reopen an app you asked for (macOS built-in)"
check_bin /usr/bin/defaults  "read an app version (macOS built-in)"
check_bin /bin/zsh           "runs the rsync backup line (macOS built-in)"
check_bin /usr/bin/rsync     "the daily backup copy (macOS built-in)"
check_bin /usr/bin/sqlite3   "reads Chrome's History database for ⇪Y (macOS built-in)"
check_bin /bin/sh            "chrome_history's copy-then-query runner (macOS built-in)"
check_bin /usr/bin/osascript "closes notification banners for begone (macOS built-in)"
echo "   none of the above needs admin, and none is installed by this config"

echo
echo "   Homebrew (OPTIONAL — powers ⌃⌥⇧U update checks and nothing else):"
brewfound=""
for b in "$HOME/homebrew/bin/brew" "$HOME/.homebrew/bin/brew" \
         "$HOME/.local/homebrew/bin/brew" /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$b" ]; then
    printf "   %-46s %s\n" "$b" "found"
    brewfound="$brewfound $b"
  fi
done
if [ -z "$brewfound" ]; then
  echo "   none found — update checks are OFF. Every other feature is unaffected."
else
  onpath=$(command -v brew 2>/dev/null || true)
  [ -n "$onpath" ] && echo "   on your PATH: $onpath"
fi

echo
echo "── 4d. WHERE THIS CONFIG WRITES ──"
# Every write target is built from logsDir or configDir. Both are under
# $HOME. If anything below is outside your home folder, that is a bug.
echo "   config : $HS"
if [ -d "$HOME/Library/CloudStorage" ]; then
  od=$(ls -d "$HOME"/Library/CloudStorage/OneDrive* 2>/dev/null | head -1)
  if [ -n "$od" ]; then
    echo "   logs   : $od/Logs"
    echo "   backup : $od/Backups/Hammerspoon/$(scutil --get ComputerName 2>/dev/null | tr ' ' '-')"
  else
    echo "   logs   : $HS/logs   (no OneDrive found — local fallback)"
    echo "   backup : disabled (no cloud destination)"
  fi
else
  echo "   logs   : $HS/logs   (no CloudStorage folder — local fallback)"
fi
case "$HS" in
  "$HOME"/*) echo "   ✅ everything above is inside your home folder" ;;
  *)         echo "   ⚠️ config is OUTSIDE your home folder: $HS" ;;
esac

# ---- 5. version markers ----------------------------------------------
# Cheap, exact "is this file the one I sent" check. Each marker only
# exists at or after the version noted.
echo
echo "── 5. IS EACH MODULE CURRENT? ──"
check_marker () {   # file  marker  since
  local f="$HS/modules/$1.lua"
  if [ ! -f "$f" ]; then printf "   %-18s ❌ file missing\n" "$1"; return; fi
  if grep -q "$2" "$f" 2>/dev/null; then
    printf "   %-18s ✅ has '%s' (%s+)\n" "$1" "$2" "$3"
  else
    printf "   %-18s ❌ MISSING '%s' — older than %s\n" "$1" "$2" "$3"
  fi
}
check_marker capture_pad     "m.text = t.value"   6.44.7
check_marker capture_pad     "writeHeaderFile"    6.44.2
check_marker window_switcher "useSnapshots"       6.44.3
check_marker mini_calendar   "copyFormat"         6.44.3
check_marker numpad_layer    "bindAll"            6.44.3
check_marker file_tracker    "_ftSincePrune"      6.44.4
check_marker activity_tracker "e._hay"            6.44.4
# The four newest tools. These matter MORE than the ones above, not less:
# a stale copy of one of these is the likeliest thing to be sitting in a
# ~/.hammerspoon that was updated by hand instead of by hs-install.sh.
check_marker mouse_grid      "grid.labelLength"   6.45.0
check_marker url_cleaner     "cleaner.maxUnwraps" 6.46.0
check_marker health_monitor  "health.bootGraceMins" 6.46.0
# 🚨 axTimeout is the per-app Accessibility timeout. A menubar_items.lua
# without it is not merely old — it is the version that can hold the
# keyboard while a wedged app fails to answer. Treat its absence as
# serious, not cosmetic.
check_marker menubar_items   "mb.axTimeout"       6.47.0
# A numpad_layer without shiftActions is the PARKED-era file: the tool
# layer simply will not exist, and ⇪⇧ + pad will do nothing at all.
check_marker numpad_layer    "shiftActions"       6.49.0
# 🚨 Both 6.48.0 markers guard against DESTRUCTIVE older copies, which is
# a different class from "missing a feature":
#   · focus_mode without fm.watchdogSecs cannot un-stick itself, so a
#     missed meeting-end leaves the microphone muted indefinitely.
#   · bulk_rename without a two-phase apply destroys a file on any swap.
check_marker focus_mode      "fm.watchdogSecs"    6.48.0
# A focus_mode.lua without manualOffSecs re-engages three seconds after
# you turn it off by hand, and still treats any Teams window as a meeting.
check_marker focus_mode      "manualOffSecs"      6.63.0
check_marker bulk_rename     "__brtmp"            6.48.0
# A workspaces.lua without pruneStore trusts Space IDs across logouts,
# which silently applies the wrong workspace to the wrong desktop.
check_marker workspaces      "pruneStore"         6.51.0
# A clipboard_history.lua without the preload guard writes a one-item
# file over the real history if you copy during the first seconds of boot.
check_marker clipboard_history "clip.preload"       6.55.0
# A mouse_grid.lua without setElements throws on a second display the
# moment you type a letter whose matches are all on the other screen.
check_marker mouse_grid      "setElements"        6.62.0
# A capture_pad.lua without asList adopts the JSON decoder's own tables,
# which can leave queue and parked as ONE table.
check_marker capture_pad     "asList"             6.62.0
# An app_watcher.lua without appMonitorSounds is still on the single
# repeating sound at 2s. Worth a marker because the alternative way to
# check is to quit an app and listen, and a WRONG sound and a config
# that never installed sound identical from across the room.
check_marker app_watcher     "appMonitorResolveSounds" 6.61.0
# 🚨 A mouse_grid.lua without dropLattice is the pre-6.65.0 file, and the
# tell is subtle enough to be worth a marker: the grid still WORKS, it
# just never narrows visibly, so you would assume the feature was never
# delivered rather than that the file is stale.
check_marker mouse_grid      "dropLattice"        6.65.0
# The four tools added in 6.65.0. A MISSING FILE here is the likeliest
# outcome of a hand-copied install — init.lua's profile names them, so
# init.lua landing without them means four modules that fail to load and
# announce themselves at the top of the cheat sheet.
check_marker tool_picker       "tp.runnable"      6.65.0
check_marker universal_actions "ua.ordered"       6.65.0
check_marker pomodoro          "pom.answerSecs"   6.65.0
check_marker outlook_probe     "outlookProbe"     6.65.0

# ---- 6. the hyper key remap ------------------------------------------
# 🚨 6.59.0 — hidutil PRINTS THE MAPPING IN DECIMAL, NOT HEX. The check
# here used to grep only for the literal hex string "0x700000039" (Caps
# Lock's HID usage), but `hidutil property --get UserKeyMapping` on a
# real Mac returns HIDKeyboardModifierMappingSrc = 30064771129 — the
# same value, decimal. The hex string never matched, so a WORKING remap
# fell into the "unexpected" branch and dumped the raw property list —
# once per HID device registered with that mapping, which is why it can
# run to a hundred-plus near-identical blocks. Confirmed against a real
# report: 30064771129 = 0x700000039 (Caps Lock) and its paired
# 30064771181 = 0x70000006D (F18), exactly the remap this config sets.
#
# Both forms are checked now, decimal first since that is what was
# actually observed. And if the mapping genuinely is something else —
# a real misconfiguration, not this bug — the fallback summarises the
# UNIQUE Src/Dst pairs instead of echoing every repeated registry entry,
# so a real problem stays readable instead of scrolling off the screen.
echo
echo "── 6. CAPS LOCK → F18 REMAP (the hyper key) ──"
out=$(hidutil property --get "UserKeyMapping" 2>/dev/null)
if echo "$out" | grep -qE '0x700000039|30064771129'; then
  echo "   ✅ remap is ACTIVE (Caps Lock is sending F18)"
elif [ -z "$out" ] || [ "$out" = "(null)" ]; then
  echo "   ⚠️  NO REMAP SET — Caps Lock is a normal Caps Lock right now."
  echo "      init.lua sets this at boot, so this usually means init.lua"
  echo "      did not finish loading."
else
  echo "   ? unexpected — the remap does not match Caps Lock -> F18."
  echo "     Unique mapping(s) found (repeated entries per HID device collapsed):"
  echo "$out" | grep -E 'HIDKeyboardModifierMapping(Src|Dst)' \
    | sed 's/^[[:space:]]*//' | sort -u | sed 's/^/       /'
fi

# ---- 7. what to paste back -------------------------------------------
echo
echo "── 7. NEXT ──"
echo "   Paste everything above, plus the FIRST RED LINE from the"
echo "   Hammerspoon Console (menubar icon → Console). The Console's"
echo "   first error is the cause; everything after it is fallout."
echo "════════════════════════════════════════════════════════════"
