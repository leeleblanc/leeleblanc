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
  echo "   count: $(ls -1 "$HS/modules"/*.lua 2>/dev/null | wc -l | tr -d ' ') files (expect 18)"
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
  for n in diagnostics cheatsheet boot_report; do
    f="$HS/core/$n.lua"
    if [ -f "$f" ]; then
      printf "   %-22s %7s  %-16s %s\n" "$n" \
        "$(wc -c < "$f" | tr -d ' ')" "$(mtime "$f" '%m-%d %H:%M')" ""
    else
      printf "   %-22s %7s  %-16s %s\n" "$n" "-" "-" "❌ MISSING"
    fi
  done
  echo "   count: $(ls -1 "$HS/core"/*.lua 2>/dev/null | wc -l | tr -d ' ') files (expect 3)"
fi

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

# ---- 6. the hyper key remap ------------------------------------------
echo
echo "── 6. CAPS LOCK → F18 REMAP (the hyper key) ──"
out=$(hidutil property --get "UserKeyMapping" 2>/dev/null)
if echo "$out" | grep -q 0x700000039; then
  echo "   ✅ remap is ACTIVE (Caps Lock is sending F18)"
elif [ -z "$out" ] || [ "$out" = "(null)" ]; then
  echo "   ⚠️  NO REMAP SET — Caps Lock is a normal Caps Lock right now."
  echo "      init.lua sets this at boot, so this usually means init.lua"
  echo "      did not finish loading."
else
  echo "   ? unexpected: $out"
fi

# ---- 7. what to paste back -------------------------------------------
echo
echo "── 7. NEXT ──"
echo "   Paste everything above, plus the FIRST RED LINE from the"
echo "   Hammerspoon Console (menubar icon → Console). The Console's"
echo "   first error is the cause; everything after it is fallout."
echo "════════════════════════════════════════════════════════════"
