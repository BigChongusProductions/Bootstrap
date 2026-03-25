#!/usr/bin/env bash
# sync.sh — Framework sync and symlink verification
# Usage:
#   bash ~/.claude/frameworks/sync.sh --verify           # Check canonical symlinks
#   bash ~/.claude/frameworks/sync.sh [project-path]     # Compare project copies vs canonical
#   bash ~/.claude/frameworks/sync.sh --init <path>      # Bootstrap frameworks into a project
#
# Canonical frameworks live at ~/.claude/frameworks/ as symlinks to the bootstrap repo.
# Projects @import from canonical via CLAUDE.md. This script verifies integrity.

set -euo pipefail

CANONICAL="$HOME/.claude/frameworks"

# ── --verify mode: check that canonical frameworks are valid symlinks ──
if [ "${1:-}" = "--verify" ]; then
    echo ""
    echo "━━━ Framework Symlink Verification ━━━"
    echo ""
    BROKEN=0
    OK=0
    for fw in "$CANONICAL"/*.md; do
        [ -e "$fw" ] || [ -L "$fw" ] || continue
        BASENAME=$(basename "$fw")
        if [ -L "$fw" ]; then
            TARGET=$(readlink "$fw")
            if [ -f "$TARGET" ]; then
                VER=$(grep -m1 "^version:" "$fw" 2>/dev/null | awk '{print $2}')
                echo "  ✅ $BASENAME (v${VER:-?}) → $(basename "$(dirname "$TARGET")")/$BASENAME"
                OK=$((OK + 1))
            else
                echo "  ❌ $BASENAME → $TARGET (broken symlink)"
                BROKEN=$((BROKEN + 1))
            fi
        else
            echo "  ⚠️  $BASENAME — regular file (should be symlink to templates/frameworks/)"
            BROKEN=$((BROKEN + 1))
        fi
    done
    echo ""
    if [ "$BROKEN" -eq 0 ]; then
        echo "✅ All $OK framework symlinks intact"
    else
        echo "⚠️  $BROKEN framework(s) need fixing"
        echo "   Fix: cd ~/.claude/frameworks && ln -sf /path/to/repo/templates/frameworks/<name>.md <name>.md"
    fi
    echo ""
    exit 0
fi

# ── Project comparison mode (legacy: for projects with local framework copies) ──

PROJECT_PATH="${1:-.}"
LOCAL="$PROJECT_PATH/frameworks"

echo ""
echo "━━━ Framework Sync Check ━━━"
echo ""

if [ ! -d "$CANONICAL" ]; then
    echo "❌ Canonical frameworks not found at $CANONICAL"
    exit 1
fi

if [ ! -d "$LOCAL" ]; then
    echo "ℹ️  No frameworks/ directory in $PROJECT_PATH"
    echo "   v0.6.0+ projects use @~/.claude/frameworks/ imports (no local copies needed)."
    echo "   To verify canonical symlinks: bash ~/.claude/frameworks/sync.sh --verify"
    echo "   To adopt local copies: bash ~/.claude/frameworks/sync.sh --init $PROJECT_PATH"

    if [ "${1:-}" = "--init" ] && [ -n "${2:-}" ]; then
        PROJECT_PATH="$2"
        LOCAL="$PROJECT_PATH/frameworks"
        echo ""
        echo "Creating $LOCAL and copying all frameworks..."
        mkdir -p "$LOCAL"
        for fw in "$CANONICAL"/*.md; do
            [ -f "$fw" ] || continue
            cp "$fw" "$LOCAL/"
            echo "  ✅ $(basename "$fw")"
        done
        echo ""
        echo "✅ Frameworks initialized in $LOCAL"
        echo "   Add '@frameworks/<name>.md' imports to your project's CLAUDE.md"
    fi
    exit 0
fi

STALE=0
UP_TO_DATE=0
LOCAL_ONLY=0

for fw in "$LOCAL"/*.md; do
    [ -f "$fw" ] || continue
    BASENAME=$(basename "$fw")
    CANON="$CANONICAL/$BASENAME"

    if [ ! -f "$CANON" ]; then
        echo "  ℹ️  $BASENAME — local only (no canonical version)"
        LOCAL_ONLY=$((LOCAL_ONLY + 1))
        continue
    fi

    LOCAL_VER=$(grep -m1 "^version:" "$fw" 2>/dev/null | awk '{print $2}')
    CANON_VER=$(grep -m1 "^version:" "$CANON" 2>/dev/null | awk '{print $2}')

    if [ -z "$LOCAL_VER" ] || [ -z "$CANON_VER" ]; then
        echo "  ⚠️  $BASENAME — missing version header"
        continue
    fi

    if [ "$LOCAL_VER" = "$CANON_VER" ]; then
        # Also check content hash for same-version modifications
        LOCAL_HASH=$(md5 -q "$fw" 2>/dev/null || md5sum "$fw" 2>/dev/null | awk '{print $1}')
        CANON_HASH=$(md5 -q "$CANON" 2>/dev/null || md5sum "$CANON" 2>/dev/null | awk '{print $1}')
        if [ "$LOCAL_HASH" = "$CANON_HASH" ]; then
            echo "  ✅ $BASENAME — v$LOCAL_VER (in sync)"
            UP_TO_DATE=$((UP_TO_DATE + 1))
        else
            echo "  ⚠️  $BASENAME — v$LOCAL_VER (content differs despite same version)"
            STALE=$((STALE + 1))
        fi
    else
        echo "  📦 $BASENAME — local v$LOCAL_VER → canonical v$CANON_VER (update available)"
        STALE=$((STALE + 1))
    fi
done

# Check for canonical frameworks not in the project
for fw in "$CANONICAL"/*.md; do
    [ -f "$fw" ] || continue
    BASENAME=$(basename "$fw")
    if [ ! -f "$LOCAL/$BASENAME" ]; then
        echo "  📦 $BASENAME — available but not adopted (v$(grep -m1 "^version:" "$fw" 2>/dev/null | awk '{print $2}'))"
    fi
done

echo ""
echo "━━━"
if [ "$STALE" -eq 0 ]; then
    echo "✅ All $UP_TO_DATE framework(s) in sync"
else
    echo "⚠️  $STALE framework(s) need updating"
    echo ""
    echo "To update all: cp ~/.claude/frameworks/*.md $LOCAL/"
    echo "To update one: cp ~/.claude/frameworks/<name>.md $LOCAL/"
fi
echo ""
