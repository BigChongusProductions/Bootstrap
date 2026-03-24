#!/bin/bash
# Hook: Post-Compaction Context Recovery (PostCompact)
# Fires after context compaction (manual /compact or auto at 95% capacity).
# Re-injects critical behavioral rules that may have been summarized away.
#
# Replaces: nothing (new capability — previously rules silently disappeared)
#
# Returns: additionalContext with critical rules + current state

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fallback CWD
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
    CWD="$(pwd)"
fi

# Read delegation state
EDIT_COUNT=0
APPROVAL_STATUS="unknown"
STATE_FILE="$CWD/.claude/hooks/.delegation_state"
if [ -f "$STATE_FILE" ]; then
    EDIT_COUNT=$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo "0")
    LAST_APPROVAL=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    AGE=$(( (NOW - LAST_APPROVAL) / 60 ))
    if [ "$AGE" -lt 30 ]; then
        APPROVAL_STATUS="approved ${AGE}m ago"
    else
        APPROVAL_STATUS="expired (${AGE}m ago)"
    fi
fi

# Read next tasks (quick, 3 lines max)
NEXT_TASKS="(db_queries.sh not available)"
if [ -f "$CWD/db_queries.sh" ]; then
    NEXT_TASKS=$(bash "$CWD/db_queries.sh" next 2>/dev/null | head -5 || echo "(query failed)")
fi

# Read current phase/signal from NEXT_SESSION.md if available
PHASE_INFO="(unknown — read NEXT_SESSION.md)"
if [ -f "$CWD/NEXT_SESSION.md" ]; then
    PHASE_INFO=$(grep -E "^(Phase|Signal|Next)" "$CWD/NEXT_SESSION.md" 2>/dev/null | head -3 || echo "(parse failed)")
fi

# Build the recovery context
CONTEXT="🔄 POST-COMPACTION CONTEXT RECOVERY

## Critical Rules (these survive compaction)
1. CORRECTION GATE: If user indicates something failed/is wrong → FIRST action is: bash db_queries.sh log-lesson
2. DELEGATION GATE: 2+ subtasks or 3+ files → present delegation table FIRST, wait for approval
3. PRE-TASK CHECK: Run bash db_queries.sh check <id> before each task — obey STOP verdicts
4. DB PROTECTION: NEVER write to registered project DBs (permissions.deny enforces Write/Edit; hook enforces Bash)
5. BUILD GATE: STOP if bash build_summarizer.sh build exits non-zero
6. PHASE GATE: Don't cross phase boundaries without bash db_queries.sh gate-pass

## Current Session State
- Delegation: edit #${EDIT_COUNT}, approval ${APPROVAL_STATUS}
- ${PHASE_INFO}

## Next Tasks
${NEXT_TASKS}

%%AGENT_NAMES%%"

jq -n --arg ctx "$CONTEXT" '{
    additionalContext: $ctx
}'
