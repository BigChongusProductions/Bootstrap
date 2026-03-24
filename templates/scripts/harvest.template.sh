#!/usr/bin/env bash
# harvest.sh — Scan project lessons for patterns eligible for promotion
#
# Scans %%LESSONS_FILE%% for entries not yet promoted to LESSONS_UNIVERSAL.md.
# Run on-demand or at session end to catch unpromoted patterns.
#
# Usage: bash harvest.sh [--dry-run]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LESSONS="$PROJECT_DIR/%%LESSONS_FILE%%"
UNIVERSAL="$HOME/.claude/LESSONS_UNIVERSAL.md"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [ ! -f "$LESSONS" ]; then
    echo "❌ %%LESSONS_FILE%% not found at $LESSONS"
    exit 1
fi

if [ ! -f "$UNIVERSAL" ]; then
    echo "⚠️  LESSONS_UNIVERSAL.md not found — creating at $UNIVERSAL"
    cat > "$UNIVERSAL" << 'HEREDOC'
# Universal Lessons
> Patterns that recur across 2+ projects. Promoted from project-level LESSONS files.

| Date | Pattern | Source Project | Prevention Rule |
|------|---------|---------------|-----------------|
HEREDOC
fi

echo "── Harvest: scanning %%LESSONS_FILE%% for unpromoted patterns ──"
echo ""

# Count entries in corrections log (skip header row)
TOTAL=$(grep -c '^|' "$LESSONS" 2>/dev/null)
TOTAL="${TOTAL:-0}"
PROMOTED=$(grep -ci 'Yes' "$LESSONS" 2>/dev/null)
PROMOTED="${PROMOTED:-0}"
UNPROMOTED=$((TOTAL - PROMOTED - 2))  # subtract header + separator rows

if [ "$UNPROMOTED" -le 0 ]; then
    echo "✅ No unpromoted patterns found."
    exit 0
fi

echo "📋 $UNPROMOTED unpromoted pattern(s) found:"
echo ""
# Show entries where "Promoted" column is empty or "No"
grep '^|' "$LESSONS" | grep -vi 'promoted\|---' | grep -v '| Yes |' | while IFS= read -r line; do
    echo "  $line"
done

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "(dry run — no changes made)"
else
    echo ""
    echo "Review the patterns above. To promote, manually add to $UNIVERSAL"
    echo "and mark the source entry as promoted in %%LESSONS_FILE%%."
fi
