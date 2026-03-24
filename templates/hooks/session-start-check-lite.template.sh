#!/bin/bash
# Hook: Session Start — Lite Engine (SessionStart)
# Simplified version: reads NEXT_SESSION.md + checks dirty tree.
# No session_briefing.sh, no DB health check, no delegation state.

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

CONTEXT_PARTS=""
WARNINGS=""

# ── 1. Read NEXT_SESSION.md (last session's handoff) ──
NEXT_SESSION="$CWD/NEXT_SESSION.md"
if [ -f "$NEXT_SESSION" ]; then
    NOW=$(date +%s)
    FILE_MTIME=$(stat -c %Y "$NEXT_SESSION" 2>/dev/null || stat -f %m "$NEXT_SESSION" 2>/dev/null || echo "0")
    AGE_HOURS=$(( (NOW - FILE_MTIME) / 3600 ))

    if [ "$AGE_HOURS" -gt 48 ]; then
        WARNINGS="${WARNINGS}\n⚠️ STALE HANDOFF: NEXT_SESSION.md is ${AGE_HOURS}h old (>48h). State may have changed."
    elif [ "$AGE_HOURS" -gt 24 ]; then
        WARNINGS="${WARNINGS}\nℹ️ AGING HANDOFF: NEXT_SESSION.md is ${AGE_HOURS}h old."
    fi

    HANDOFF=$(head -80 "$NEXT_SESSION")
    CONTEXT_PARTS="${CONTEXT_PARTS}

## Last Session Handoff (NEXT_SESSION.md, ${AGE_HOURS}h old)
${HANDOFF}"
else
    WARNINGS="${WARNINGS}\n⚠️ NO HANDOFF: NEXT_SESSION.md missing. No context from previous session."
fi

# ── 2. Uncommitted changes ──
if [ -d "$CWD/.git" ]; then
    DIRTY_COUNT=$(cd "$CWD" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIRTY_COUNT" -gt 0 ]; then
        WARNINGS="${WARNINGS}\nℹ️ DIRTY TREE: ${DIRTY_COUNT} uncommitted change(s) from previous session."
    fi
fi

# ── Build final context ──
FULL_CONTEXT="🚀 SESSION START (Lite Engine)
${CONTEXT_PARTS}"

if [ -n "$WARNINGS" ]; then
    FULL_CONTEXT="${FULL_CONTEXT}

## Warnings
$(echo -e "$WARNINGS")"
fi

FULL_CONTEXT="${FULL_CONTEXT}

## Action Required
Run \`bash db_queries.sh next\` and \`bash db_queries.sh status\`, then present the brief.
Wait for Master's 'go' before starting any work."

jq -n --arg ctx "$FULL_CONTEXT" '{
    hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $ctx
    }
}'
