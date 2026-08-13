#!/bin/bash
# hs-crash — collect every Hammerspoon crash macOS already saved, plus the
# state the machine was in when they happened.
#
#   bash ~/hs-crash.sh          # then paste the whole output back
#
# WHY THIS EXISTS: "Hammerspoon crashed again and I couldn't grab the crash
# report." You never have to. macOS writes every crash to
# ~/Library/Logs/DiagnosticReports/ and leaves it there — catching it in the
# moment was never required, and believing otherwise costs a debugging round
# every time.
#
# It only READS. It changes nothing, starts nothing and stops nothing.
#
# THE ONE QUESTION THIS ANSWERS, and it decides everything that follows:
# WAS THE CONFIG EVEN LOADED WHEN IT CRASHED?
#   · crash with NO config present  → not our Lua. Hammerspoon itself, or
#     Hammerspoon against this macOS. Nothing I write can fix it and
#     reinstalling/updating Hammerspoon is the move.
#   · crash in SAFE mode            → one of four modules.
#   · crash with the full config    → back to the normal hunt.
# Section 2 records which of those was true, so nobody has to remember.

HS="${1:-$HOME/.hammerspoon}"
DR="$HOME/Library/Logs/DiagnosticReports"
N="${2:-4}"          # how many crash reports to summarise

echo "════════════════════════════════════════════════════════════"
echo " HAMMERSPOON CRASH COLLECTOR   $(date '+%Y-%m-%d %H:%M')"
echo "════════════════════════════════════════════════════════════"

# ---- 1. the machine ---------------------------------------------------
echo
echo "── 1. THIS MAC ──"
echo "   macOS   : $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "   hardware: $(sysctl -n hw.model 2>/dev/null)"
APP=""
for p in "/Applications/Hammerspoon.app" "$HOME/Applications/Hammerspoon.app"; do
  [ -d "$p" ] && APP="$p" && break
done
if [ -n "$APP" ]; then
  V=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
  B=$(defaults read "$APP/Contents/Info.plist" CFBundleVersion 2>/dev/null)
  echo "   Hammerspoon: ${V:-?} (build ${B:-?})  at $APP"
else
  echo "   Hammerspoon: not found in /Applications or ~/Applications"
fi
if pgrep -x Hammerspoon >/dev/null 2>&1; then
  echo "   running : YES (pid $(pgrep -x Hammerspoon | tr '\n' ' '))"
else
  echo "   running : no"
fi

# ---- 2. WHAT CONFIG WAS IN PLACE -------------------------------------
# The decisive section. Read section 3's timings together with this.
echo
echo "── 2. 🚨 WHAT CONFIG IS IN PLACE (this decides everything) ──"
if [ ! -d "$HS" ]; then
  echo "   ❌ NO CONFIG AT $HS"
  echo "      If a crash below happened while this was true, the config is"
  echo "      NOT the cause — Hammerspoon crashed with nothing of ours to run."
else
  if [ -f "$HS/init.lua" ]; then
    ver=$(grep -m1 '_G.configVersion' "$HS/init.lua" | sed 's/.*"\(.*\)".*/\1/')
    echo "   init.lua: present, version ${ver:-UNKNOWN}"
    echo "   modules : $(ls -1 "$HS/modules"/*.lua 2>/dev/null | wc -l | tr -d ' ')"
  else
    echo "   ⚠️ $HS exists but has NO init.lua"
  fi
  if [ -f "$HS/SAFE" ]; then
    echo "   🚑 SAFE MODE IS ON — only 4 modules load"
  else
    echo "   SAFE mode: off (full module set)"
  fi
fi
for q in "$HOME/hammerspoon-broken" "$HOME/.hammerspoon.bak"; do
  [ -d "$q" ] && echo "   (a quarantined copy also exists at $q)"
done

# ---- 3. the crashes ---------------------------------------------------
echo
echo "── 3. CRASH REPORTS macOS ALREADY SAVED ──"
if [ ! -d "$DR" ]; then
  echo "   no DiagnosticReports folder at $DR"
else
  ALL=$(ls -t "$DR"/Hammerspoon*.ips 2>/dev/null)
  if [ -z "$ALL" ]; then
    echo "   ✅ no Hammerspoon crash reports on this Mac at all"
  else
    echo "   $(echo "$ALL" | wc -l | tr -d ' ') total. Newest $N summarised below."
    echo
    echo "   ALL CRASH TIMES (newest first) — bunched times mean a launch loop:"
    echo "$ALL" | head -20 | while read -r f; do
      echo "      $(basename "$f")"
    done
    echo
    echo "$ALL" | head -"$N" | while read -r f; do
      echo "   ──────────────────────────────────────────────────────────"
      echo "   $(basename "$f")"
      # python3 ships with macOS. The .ips format is a JSON header line
      # followed by a JSON body, so it is parsed rather than grepped —
      # grepping a JSON blob for "frames" is how you get the wrong thread.
      python3 - "$f" <<'PY' 2>/dev/null || echo "      (could not parse — raw head follows)"
import json, sys, datetime
p = sys.argv[1]
raw = open(p, "r", errors="replace").read()
nl = raw.find("\n")
body = json.loads(raw[nl+1:])

exc  = body.get("exception", {}) or {}
term = body.get("termination", {}) or {}
print("      exception : %s  %s" % (exc.get("type",""), exc.get("signal","")))
if term:
    print("      terminated: %s (%s)" % (term.get("indicator",""), term.get("namespace","")))
asi = body.get("asi") or {}
for k, v in asi.items():
    for line in v:
        print("      note      : %s: %s" % (k, line))

# ⏱ TIME FROM LAUNCH TO CRASH — the single most useful number here.
# Under a second means it died while init.lua was still loading. Minutes
# later means something you did, or a timer, and that is a different hunt.
# Parsed WITH the fractional part. Truncating at 19 chars drops it, and
# 31.0348 -> 31.6389 then reads as 0.0s instead of 0.6s. Both say "during
# load", but the moment a real gap appears — 2.5s, 40s — a truncated
# figure starts lying about which half of the boot it died in.
# ⚠️ SPLIT OFF THE TIMEZONE, do not slice a fixed width. The field is
# "2026-08-13 07:51:31.0348 -0500" and the fractional part is FOUR digits,
# not six — so a [:26] slice lands mid-timezone and the parse fails, which
# silently drops this whole line from the report. Two fields, always.
def t(s):
    parts = str(s).strip().split()
    if len(parts) < 2:
        return None
    stamp = parts[0] + " " + parts[1]
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.datetime.strptime(stamp, fmt)
        except Exception:
            pass
    return None
a, b = t(body.get("procLaunch","")), t(body.get("captureTime",""))
if a and b:
    secs = (b - a).total_seconds()
    when = "DURING CONFIG LOAD" if secs < 3 else "after the config was up"
    print("      launch→crash: %.1fs  → %s" % (secs, when))

# The faulting thread only.
for th in body.get("threads", []):
    if th.get("triggered"):
        imgs = body.get("usedImages", [])
        print("      faulting thread: %s" % (th.get("queue") or th.get("name") or "?"))
        for fr in th.get("frames", [])[:14]:
            i = fr.get("imageIndex", -1)
            name = imgs[i].get("name","?") if 0 <= i < len(imgs) else "?"
            sym  = fr.get("symbol") or ("+%d" % fr.get("imageOffset", 0))
            print("        %-22s %s" % (name, sym))
        break
PY
    done
  fi
fi

# ---- 4. leftovers that outlive the process ---------------------------
echo
echo "── 4. STATE THAT SURVIVES HAMMERSPOON DYING ──"
echo "   These are NOT cleared by quitting or killing it. If the keyboard or"
echo "   Mission Control still feel wrong, this is where it lives."
out=$(hidutil property --get "UserKeyMapping" 2>/dev/null)
if [ -z "$out" ] || [ "$out" = "(null)" ]; then
  echo "   ✅ hidutil: no remap — Caps Lock is a normal Caps Lock"
else
  if echo "$out" | grep -qE '0x700000039|30064771129'; then
    echo "   ⚠️ hidutil: Caps Lock IS remapped to F18 right now."
    echo "      With Hammerspoon not running, that key does nothing at all."
    echo "      Clear it:  hidutil property --set '{\"UserKeyMapping\":[]}'"
  else
    echo "   ? hidutil: some other mapping is set"
  fi
fi
echo "   Dock/WindowManager: if Mission Control or the four-finger swipe are"
echo "      stuck, run 'killall Dock'. A wedge there is the DOCK, not"
echo "      Hammerspoon, which is why killing Hammerspoon never helps."

# ---- 5. login item ----------------------------------------------------
echo
echo "── 5. DOES IT COME BACK BY ITSELF? ──"
if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -qi hammerspoon; then
  echo "   ⚠️ Hammerspoon IS a login item — it relaunches (and re-applies the"
  echo "      Caps Lock remap) every time you log in. Remove it while we are"
  echo "      still diagnosing: System Settings → General → Login Items."
else
  echo "   ✅ not a login item, or the list is not readable without permission"
fi

echo
echo "── 6. NEXT ──"
echo "   Paste everything above. Section 2 plus the 'launch→crash' line in"
echo "   section 3 is the whole diagnosis: config present or not, and whether"
echo "   it died while loading."
echo "════════════════════════════════════════════════════════════"
