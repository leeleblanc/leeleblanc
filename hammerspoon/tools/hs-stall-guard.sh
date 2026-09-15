#!/bin/sh
# =====================================================================
# hs-stall-guard.sh — a second process that watches Hammerspoon's PULSE
# =====================================================================
#     sh hs-stall-guard.sh <dir> <stallSecs> <checkSecs> <maxRelaunches>
#
# modules/stall_guard.lua starts this (6.208.0) and never touches it
# again. Hammerspoon writes the epoch second into <dir>/heartbeat every
# couple of seconds FROM ITS MAIN THREAD — the thread that draws the
# screen and reads the keyboard — so when that thread stalls (the beach
# ball), the beat stops. Nothing inside Hammerspoon can notice that,
# because the thing that would notice is the thing that is stuck. This
# script is outside, so it can.
#
# WHAT IT DOES, in order, and nothing else:
#   · sleeps <checkSecs>, reads the beat, works out how old it is;
#   · a beat older than <stallSecs> is ONE stale reading — it takes TWO
#     IN A ROW (a single slow write on a busy Mac is not a hang). The
#     module passes 60 and 10 (6.213.1): above the longest main-thread
#     job this config is known to do, because a kill cannot be undone;
#   · with two, and Hammerspoon actually running: log it, /bin/kill -9
#     the process (the only thing that frees a hung main thread), lift
#     the ⇪ keyboard remap that a hard kill leaves behind (the hidutil
#     line init.lua's own comment calls the manual escape hatch), and
#     `open -a Hammerspoon` — which boots the config again, and the
#     config then announces this log line to LL.
#
# WHAT STOPS IT LYING:
#   · SLEEP. Close the lid, open it an hour later, and the beat is an
#     hour old for a second or two. A loop that wakes to a wall-clock
#     gap of more than three checks throws that reading away.
#   · A CLEAN QUIT. init.lua's shutdownCallback writes <dir>/quit; the
#     next loop sees it and exits. (A reload is a quit then a boot: the
#     new boot spawns a new guard, which removes the marker.)
#   · A NEWER GUARD. Each guard writes its own pid to <dir>/guard.pid.
#     A guard that finds another pid there is the OLD one and exits —
#     so a boot never leaves two of these behind.
#   · A LIMIT. Before relaunching it counts relaunches already in the
#     log within the last ten minutes; at <maxRelaunches> it logs that
#     it is giving up and EXITS. A config that stalls at boot must not
#     be relaunched forever.
#   · NOT RUNNING IS NOT STALLED. No Hammerspoon process means nothing
#     to guard: it never launches one on its own, and after a minute of
#     that it exits.
#
# It runs as LL, from LL's own directory, with no sudo, no launchd, no
# LaunchAgent — it MUST work on the work Mac. Every binary it needs is
# named absolutely, and each can be overridden through an SG_* variable
# so the test suite runs this exact file on Linux with stubs in place of
# kill / pgrep / open / hidutil.

PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

DIR=$1
STALL=${2:-60}
CHECK=${3:-10}
MAX=${4:-3}

[ -n "$DIR" ] || exit 2
[ -d "$DIR" ] || exit 2

KILL=${SG_KILL:-/bin/kill}
PGREP=${SG_PGREP:-/usr/bin/pgrep}
OPEN=${SG_OPEN:-/usr/bin/open}
HIDUTIL=${SG_HIDUTIL:-/usr/bin/hidutil}
APP=${SG_APP:-Hammerspoon}
WINDOW=${SG_WINDOW:-600}       # the relaunch limit's window, seconds

BEAT="$DIR/heartbeat"
PIDF="$DIR/guard.pid"
QUIT="$DIR/quit"
LOG="$DIR/stall-guard.log"

now() { date +%s; }
stamp() { date "+%Y-%m-%d %H:%M:%S"; }
log() { printf '%s %s %s\n' "$(now)" "$(stamp)" "$*" >> "$LOG"; }

echo $$ > "$PIDF" || exit 2
rm -f "$QUIT"
log "started pid=$$ stall=${STALL}s check=${CHECK}s max=$MAX"

stale=0
notRunning=0
last=$(now)

while :; do
    sleep "$CHECK"

    # a newer guard, or a clean quit — either way this one is finished
    if [ "$(cat "$PIDF" 2>/dev/null)" != "$$" ]; then
        log "exit: replaced by a newer guard"
        exit 0
    fi
    if [ -f "$QUIT" ]; then
        log "exit: Hammerspoon quit cleanly"
        exit 0
    fi

    t=$(now)
    gap=$((t - last))
    last=$t
    if [ "$gap" -gt $((CHECK * 3)) ]; then
        # the Mac slept (or the clock jumped): the beat is old because
        # nothing ran, not because Hammerspoon hung. Start over.
        log "skipped a reading after a ${gap}s gap (sleep?)"
        stale=0
        continue
    fi

    pid=$("$PGREP" -x "$APP" 2>/dev/null | head -1)
    if [ -z "$pid" ]; then
        stale=0
        notRunning=$((notRunning + 1))
        if [ "$((notRunning * CHECK))" -ge 60 ]; then
            log "exit: Hammerspoon is not running"
            exit 0
        fi
        continue
    fi
    notRunning=0

    beat=$(cat "$BEAT" 2>/dev/null)
    case "$beat" in
        ''|*[!0-9]*) stale=0; continue ;;   # no beat yet, or not a number
    esac
    age=$((t - beat))
    if [ "$age" -lt "$STALL" ]; then
        stale=0
        continue
    fi

    stale=$((stale + 1))
    [ "$stale" -ge 2 ] || continue

    # two stale readings in a row, Hammerspoon running: it is hung.
    recent=$(awk -v since="$((t - WINDOW))" '$1 >= since && /relaunched/ { n++ } END { print n + 0 }' "$LOG" 2>/dev/null)
    if [ "${recent:-0}" -ge "$MAX" ]; then
        log "gave up: $recent relaunches in the last $((WINDOW / 60)) min — not relaunching pid=$pid (stalled ${age}s)"
        exit 0
    fi
    log "relaunched: stalled ${age}s, killed pid=$pid"
    "$KILL" -9 "$pid" 2>/dev/null
    sleep 1
    "$HIDUTIL" property --set '{"UserKeyMapping":[]}' >/dev/null 2>&1
    "$OPEN" -a "$APP" >/dev/null 2>&1
    # give the new instance a full stall's worth of time to boot and beat
    # before reading again, or its boot is the next "stall"
    sleep "$STALL"
    stale=0
    last=$(now)
done
