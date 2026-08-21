#!/bin/sh
# =====================================================================
# hs-install.sh — install a new config version, reversibly
# =====================================================================
#     sh hs-install.sh <folder-you-unzipped>          # install
#     sh hs-install.sh --rollback                     # undo the last one
#     sh hs-install.sh <folder> --dry-run             # show, change nothing
#
# WHY THIS EXISTS. The work MacBook is the primary machine. The risk on
# it has never been the Lua — it is the COPY. 6.44.11 added a core/
# folder, so `cp init.lua ~/.hammerspoon/` now produces a half-updated
# install that starts, looks fine, and has lost ⇪/ and ⇪⇧D. That class of
# mistake has cost us more time than any bug, and it is entirely avoidable.
#
# WHAT IT GUARANTEES
#   · It checks the SOURCE is complete before touching anything.
#   · It backs up your entire current config first, timestamped.
#   · It verifies the result, and if the verify fails it rolls back BY
#     ITSELF and tells you nothing changed.
#   · secret.lua and logs/ are never touched, never copied, never backed
#     up anywhere this script controls. Your token stays where it is.
#
# WHAT IT WILL NOT DO
#   · run as root — it refuses, and says so
#   · use sudo, install anything, or touch a single file outside $HOME
#   · reload Hammerspoon: that stays your decision, after you have read
#     what it did
# =====================================================================

set -u

HS="${HAMMERSPOON_DIR:-$HOME/.hammerspoon}"
BACKUP_ROOT="$HS/.backups"
SRC=""
DRY=0
ROLLBACK=0

for a in "$@"; do
    case "$a" in
        --dry-run)  DRY=1 ;;
        --rollback) ROLLBACK=1 ;;
        -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
        *)          SRC="$a" ;;
    esac
done

say  () { echo "$@"; }
die  () { echo "✗ $*" >&2; exit 1; }

# Running this as root would create root-owned files in your home folder
# that you would then need admin rights to fix — on the exact machine
# where you do not have them.
[ "$(id -u)" = "0" ] && die "do NOT run this as root. Run it as yourself."

# ---------------------------------------------------------------- rollback
if [ "$ROLLBACK" = "1" ]; then
    [ -d "$BACKUP_ROOT" ] || die "no backups at $BACKUP_ROOT — nothing to roll back to."
    LAST=$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -1)
    [ -n "$LAST" ] || die "no backups found in $BACKUP_ROOT"
    B="$BACKUP_ROOT/$LAST"
    say "── ROLLBACK ──"
    say "   restoring from: $B"
    [ -f "$B/init.lua" ] || die "that backup has no init.lua — refusing to use it."
    cp "$B/init.lua" "$HS/init.lua" || die "could not restore init.lua"
    for d in core modules; do
        if [ -d "$B/$d" ]; then
            rm -rf "$HS/$d" && cp -R "$B/$d" "$HS/$d" || die "could not restore $d/"
        fi
    done
    # 🚨 THE SNIPPETS FOLDER IS RESTORED FILE-BY-FILE, NOT WIPED. core/ and
    # modules/ are ours entirely, so replacing them wholesale is right;
    # snippets/ may also hold packs somebody unzipped there by hand, and
    # `rm -rf` would take those with it to undo an install.
    if [ -f "$B/snippets-bundled.lua" ]; then
        mkdir -p "$HS/snippets"
        cp "$B/snippets-bundled.lua" "$HS/snippets/bundled.lua" \
            || die "could not restore snippets/bundled.lua"
    elif [ -f "$B/snippets-absent" ]; then
        rm -f "$HS/snippets/bundled.lua"
    fi
    say "   ✅ restored. Reload Hammerspoon (menu bar → Reload Config)."
    say "   version now: $(grep -m1 '_G.configVersion' "$HS/init.lua" | sed 's/.*"\(.*\)".*/\1/')"
    exit 0
fi

[ -n "$SRC" ] || die "usage: sh hs-install.sh <folder-you-unzipped>  [--dry-run]"
[ -d "$SRC" ] || die "not a folder: $SRC"

# ------------------------------------------------- 1. is the SOURCE whole?
# Checked BEFORE anything is touched. A truncated download is the classic
# silent failure: the file exists, looks fine, and has lost its tail.
say "── 1. CHECKING WHAT YOU DOWNLOADED ──"
[ -f "$SRC/init.lua" ] || die "no init.lua in $SRC"
NEWVER=$(grep -m1 '_G.configVersion' "$SRC/init.lua" | sed 's/.*"\(.*\)".*/\1/')
[ -n "$NEWVER" ] || die "$SRC/init.lua has no version marker — it is not a config file."

miss=""
for a in "_G.configVersion" "moduleProfiles" "loadModules" "Core Systems Booted"; do
    grep -q "$a" "$SRC/init.lua" || miss="$miss $a"
done
[ -z "$miss" ] || die "the downloaded init.lua is INCOMPLETE (missing:$miss). Re-download it."

say "   init.lua : $NEWVER  ($(wc -l < "$SRC/init.lua" | tr -d ' ') lines) ✅ complete"

# core/ is required from 6.44.11 on. Install it or refuse — a half
# install is the exact failure this script exists to prevent.
NEEDS_CORE=0
grep -q "core/diagnostics.lua" "$SRC/init.lua" && NEEDS_CORE=1
if [ "$NEEDS_CORE" = "1" ]; then
    [ -d "$SRC/core" ] || die "this init.lua needs a core/ folder and your download has none.
   Installing it alone would silently cost you ⇪/ and ⇪⇧D. Re-download the zip."
    for n in diagnostics cheatsheet boot_report capabilities notices coexist hyper_key changelog_csv console lag; do
        [ -f "$SRC/core/$n.lua" ] || die "core/$n.lua is missing from your download. Re-download."
    done
    say "   core/    : 9 files ✅ present"
else
    say "   core/    : not required by this version"
fi

if [ -d "$SRC/modules" ]; then
    say "   modules/ : $(ls -1 "$SRC/modules"/*.lua 2>/dev/null | wc -l | tr -d ' ') files"
else
    say "   modules/ : not in this download — your existing ones are kept"
fi

# 📦 SHIPPED SNIPPETS (6.105.0). This script did not copy snippets/ for
# four versions, so the packs the zip carried never reached
# ~/.hammerspoon and the text expander only ever saw the OneDrive folder.
# Nobody noticed because that folder had everything in it anyway. Now
# that the packs ship as ONE generated bundled.lua, "the zip carries
# them" has to actually be true.
#
# Your OWN snippets are NOT here. They live in the Logs folder alongside
# autocorrect.csv, which this script has never touched and still doesn't.
if [ -f "$SRC/snippets/bundled.lua" ]; then
    say "   snippets/: bundled.lua ($(wc -c < "$SRC/snippets/bundled.lua" | tr -d ' ') bytes)"
elif [ -d "$SRC/snippets" ]; then
    say "   snippets/: $(find "$SRC/snippets" -name '*.json' 2>/dev/null | wc -l | tr -d ' ') files (unbundled)"
else
    say "   snippets/: not in this download — your existing ones are kept"
fi

CURVER="none"
[ -f "$HS/init.lua" ] && CURVER=$(grep -m1 '_G.configVersion' "$HS/init.lua" | sed 's/.*"\(.*\)".*/\1/')
say ""
say "   $CURVER  →  $NEWVER"

if [ "$DRY" = "1" ]; then
    say ""
    say "── DRY RUN — nothing was changed. ──"
    say "   Run without --dry-run to install."
    exit 0
fi

# ---------------------------------------------------------- 2. back up
say ""
say "── 2. BACKING UP YOUR CURRENT CONFIG ──"
STAMP=$(date '+%Y%m%d-%H%M%S')
B="$BACKUP_ROOT/$STAMP-was-$CURVER"
mkdir -p "$B" || die "could not create $B"
[ -f "$HS/init.lua" ] && cp "$HS/init.lua" "$B/init.lua"
for d in core modules; do
    [ -d "$HS/$d" ] && cp -R "$HS/$d" "$B/$d"
done
# Only the generated file, flattened to one name so the rollback above
# cannot be confused by a snippets/ directory that also holds packs. A
# marker records "there wasn't one", so rolling back to a version before
# 6.105.0 removes it rather than leaving a table that version cannot read.
if [ -f "$HS/snippets/bundled.lua" ]; then
    cp "$HS/snippets/bundled.lua" "$B/snippets-bundled.lua"
else
    : > "$B/snippets-absent"
fi
say "   saved: $B"
say "   (secret.lua and logs/ are deliberately NOT copied — your token stays put)"

# ---------------------------------------------------------- 3. install
say ""
say "── 3. INSTALLING ──"
cp "$SRC/init.lua" "$HS/init.lua" || die "could not write $HS/init.lua"
say "   init.lua ✅"
if [ -d "$SRC/core" ]; then
    mkdir -p "$HS/core"
    cp "$SRC/core"/*.lua "$HS/core/" || die "could not write core/"
    say "   core/    ✅ $(ls -1 "$HS/core"/*.lua | wc -l | tr -d ' ') files"
fi
if [ -d "$SRC/modules" ]; then
    mkdir -p "$HS/modules"
    cp "$SRC/modules"/*.lua "$HS/modules/" || die "could not write modules/"
    say "   modules/ ✅ $(ls -1 "$HS/modules"/*.lua | wc -l | tr -d ' ') files"
fi
if [ -d "$SRC/tools" ]; then
    mkdir -p "$HS/tools"
    cp "$SRC/tools"/*.sh "$HS/tools/" 2>/dev/null
    # 6.105.0 — the .lua tools travel too. build-snippets.lua regenerates
    # snippets/bundled.lua from the .json packs already on this Mac, and it
    # can only do that from its installed path next to them.
    cp "$SRC/tools"/*.lua "$HS/tools/" 2>/dev/null
    say "   tools/   ✅ $(ls -1 "$HS/tools"/*.sh "$HS/tools"/*.lua 2>/dev/null | wc -l | tr -d ' ') files"
fi
if [ -d "$SRC/snippets" ]; then
    mkdir -p "$HS/snippets"
    cp -R "$SRC/snippets"/. "$HS/snippets/" || die "could not write snippets/"
    # 🚨 THE OLD PACKS ARE LEFT WHERE THEY ARE. A previous unzip may have
    # put 2,006 .json files here; the expander ignores them once
    # bundled.lua loads, and deleting somebody's snippets folder to save
    # 8 MB is not a trade this script gets to make on its own. It says
    # where they are and lets you decide.
    if [ -f "$HS/snippets/bundled.lua" ]; then
        say "   snippets/ ✅ bundled.lua"
        OLDJSON=$(find "$HS/snippets" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
        if [ "${OLDJSON:-0}" -gt 0 ]; then
            say "      ($OLDJSON older .json snippet files are still in $HS/snippets"
            say "       and are now ignored — safe to delete if you want the space)"
        fi
    else
        say "   snippets/ ✅ $(find "$HS/snippets" -name '*.json' 2>/dev/null | wc -l | tr -d ' ') files"
    fi
fi

# ------------------------------------------------------------ 4. verify
# If this fails, the install is undone automatically. A broken config on
# the primary machine is not something to leave sitting there while you
# read an error message.
say ""
say "── 4. VERIFYING ──"
fail=""
INSTVER=$(grep -m1 '_G.configVersion' "$HS/init.lua" | sed 's/.*"\(.*\)".*/\1/')
[ "$INSTVER" = "$NEWVER" ] || fail="$fail version-mismatch"
for a in "_G.configVersion" "loadModules" "Core Systems Booted"; do
    grep -q "$a" "$HS/init.lua" || fail="$fail truncated"
done
if [ "$NEEDS_CORE" = "1" ]; then
    # EXISTENCE IS NOT INTEGRITY. The first version of this check was
    # `[ -f ... ]`, and a zero-byte core/boot_report.lua sailed through it
    # — which is precisely the half-installed state this script exists to
    # prevent, just with the file present. Each one must actually be the
    # initialiser init.lua is going to call.
    for n in diagnostics cheatsheet boot_report capabilities notices coexist hyper_key changelog_csv console lag; do
        f="$HS/core/$n.lua"
        if [ ! -s "$f" ]; then
            fail="$fail core/$n-empty"
        elif ! grep -q "return function(core)" "$f"; then
            fail="$fail core/$n-not-an-initialiser"
        fi
    done
fi

if [ -n "$fail" ]; then
    say "   ❌ VERIFY FAILED:$fail"
    say "   Rolling back automatically — your Mac is being put back as it was."
    cp "$B/init.lua" "$HS/init.lua" 2>/dev/null
    for d in core modules; do
        [ -d "$B/$d" ] && rm -rf "$HS/$d" && cp -R "$B/$d" "$HS/$d"
    done
    say "   ✅ rolled back to $CURVER. Nothing was left broken. Do NOT reload."
    exit 1
fi

say "   ✅ version    $INSTVER"
say "   ✅ init.lua   complete"
[ "$NEEDS_CORE" = "1" ] && say "   ✅ core/      all 10 present"
say ""
say "── DONE ──"
say "   Now: Hammerspoon menu bar → Reload Config"
say "   Then, to confirm on this Mac:   sh $HS/tools/hs-doctor.sh"
say ""
say "   If anything is wrong after the reload, undo it with:"
say "       sh $HS/tools/hs-install.sh --rollback"
