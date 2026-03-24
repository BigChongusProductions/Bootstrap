#!/bin/bash
# Hook: End-of-Turn Verification (Stop)
# Fires after Claude finishes responding.
# Checks for common session hygiene issues and injects warnings.
#
# Replaces: nothing (new capability)
#
# Returns: additionalContext with warnings (non-blocking)
# Only fires if issues are detected — silent when clean.

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fallback CWD
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
    exit 0
fi

WARNINGS=""

# Check 1: Large number of uncommitted changes
if [ -d "$CWD/.git" ]; then
    DIRTY=$(cd "$CWD" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIRTY" -gt 10 ]; then
        WARNINGS="${WARNINGS}\n- 📁 ${DIRTY} uncommitted files — consider committing before continuing"
    fi
fi

# Check 2: High edit count without delegation approval
STATE_FILE="$CWD/.claude/hooks/.delegation_state"
if [ -f "$STATE_FILE" ]; then
    EDIT_COUNT=$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo "0")
    LAST_APPROVAL=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    APPROVAL_AGE=$((NOW - LAST_APPROVAL))

    if [ "$EDIT_COUNT" -gt 8 ] && [ "$APPROVAL_AGE" -gt 1800 ]; then
        WARNINGS="${WARNINGS}\n- ✏️ ${EDIT_COUNT} edits this session without delegation approval — is this still a single-task scope?"
    fi
fi

# Check 3: NEXT_SESSION.md very stale (>24h) — reminder to save
if [ -f "$CWD/NEXT_SESSION.md" ]; then
    NOW=$(date +%s)
    MTIME=$(stat -c %Y "$CWD/NEXT_SESSION.md" 2>/dev/null || stat -f %m "$CWD/NEXT_SESSION.md" 2>/dev/null || echo "0")
    AGE_HOURS=$(( (NOW - MTIME) / 3600 ))
    if [ "$AGE_HOURS" -gt 24 ]; then
        WARNINGS="${WARNINGS}\n- 📋 NEXT_SESSION.md is ${AGE_HOURS}h old — save session when ready"
    fi
fi

# Only output if we have warnings
if [ -n "$WARNINGS" ]; then
    jq -n --arg reason "$(echo -e "🔍 END-OF-TURN CHECKS:${WARNINGS}")" '{
        stopReason: $reason
    }'
fi

exit 0
