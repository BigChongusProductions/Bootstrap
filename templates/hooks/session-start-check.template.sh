#!/bin/bash
# Hook: Session Start — Full Briefing Injection (SessionStart)
# Fires when a Claude Code session begins or resumes.
#
# What it does:
#   1. Runs session_briefing.sh and captures the full output
#   2. Reads NEXT_SESSION.md (last session's handoff)
#   3. Checks handoff freshness, DB health, dirty tree
#   4. Injects EVERYTHING as additionalContext so Claude has full state
#      on the very first interaction — no manual "run briefing" step needed
#
# The CLAUDE.md rule "present status brief on first interaction" means
# Claude will auto-present this when the user types anything.
#
# Replaces: manual "bash session_briefing.sh" + "cat NEXT_SESSION.md" at session start

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

CONTEXT_PARTS=""
WARNINGS=""

# ── 1. Run session_briefing.sh (the full computed digest) ──
if [ -f "$CWD/session_briefing.sh" ]; then
    # Capture stdout; allow failure (no sqlite3 in some envs)
    BRIEFING=$(bash "$CWD/session_briefing.sh" 2>/dev/null) || BRIEFING="(session_briefing.sh failed — sqlite3 may not be available)"
    CONTEXT_PARTS="${CONTEXT_PARTS}

## Session Briefing (computed)
${BRIEFING}"
fi

# ── 2. Read NEXT_SESSION.md (last session's handoff) ──
NEXT_SESSION="$CWD/NEXT_SESSION.md"
if [ -f "$NEXT_SESSION" ]; then
    # Freshness check
    NOW=$(date +%s)
    FILE_MTIME=$(stat -c %Y "$NEXT_SESSION" 2>/dev/null || stat -f %m "$NEXT_SESSION" 2>/dev/null || echo "0")
    AGE_HOURS=$(( (NOW - FILE_MTIME) / 3600 ))

    if [ "$AGE_HOURS" -gt 48 ]; then
        WARNINGS="${WARNINGS}\n⚠️ STALE HANDOFF: NEXT_SESSION.md is ${AGE_HOURS}h old (>48h). State may have changed."
    elif [ "$AGE_HOURS" -gt 24 ]; then
        WARNINGS="${WARNINGS}\nℹ️ AGING HANDOFF: NEXT_SESSION.md is ${AGE_HOURS}h old."
    fi

    # Include the handoff content (truncate if huge)
    HANDOFF=$(head -80 "$NEXT_SESSION")
    CONTEXT_PARTS="${CONTEXT_PARTS}

## Last Session Handoff (NEXT_SESSION.md, ${AGE_HOURS}h old)
${HANDOFF}"
else
    WARNINGS="${WARNINGS}\n⚠️ NO HANDOFF: NEXT_SESSION.md missing. No context from previous session."
fi

# ── 3. DB health (quick check) ──
if [ -f "$CWD/db_queries.sh" ]; then
    DB_HEALTH=$(bash "$CWD/db_queries.sh" health 2>&1) || true
    if echo "$DB_HEALTH" | grep -qi "error\|fail\|corrupt"; then
        WARNINGS="${WARNINGS}\n⚠️ DB HEALTH ISSUE: $(echo "$DB_HEALTH" | grep -i 'error\|fail\|corrupt' | head -1)"
    fi
fi

# ── 4. Uncommitted changes ──
if [ -d "$CWD/.git" ]; then
    DIRTY_COUNT=$(cd "$CWD" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIRTY_COUNT" -gt 0 ]; then
        WARNINGS="${WARNINGS}\nℹ️ DIRTY TREE: ${DIRTY_COUNT} uncommitted change(s) from previous session."
    fi
fi

# ── 5. Reset delegation state for fresh session ──
STATE_FILE="$CWD/.claude/hooks/.delegation_state"
echo "0" > "$STATE_FILE"
echo "0" >> "$STATE_FILE"

# ── Build final context ──
FULL_CONTEXT="🚀 SESSION START — AUTO-BRIEFING
${CONTEXT_PARTS}"

if [ -n "$WARNINGS" ]; then
    FULL_CONTEXT="${FULL_CONTEXT}

## Warnings
$(echo -e "$WARNINGS")"
fi

FULL_CONTEXT="${FULL_CONTEXT}

## Action Required
Present the status brief (signal, phase, next task) as your FIRST response.
Wait for Master's 'go' before starting any work."

jq -n --arg ctx "$FULL_CONTEXT" '{
    hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $ctx
    }
}'
