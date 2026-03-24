#!/bin/bash
# Hook: Sub-Agent Delegation Check (SubagentStart)
# Fires when a sub-agent is spawned.
# Verifies that delegation was recently approved before allowing multi-agent work.
#
# Replaces: delegation-reminder.sh's role for agent spawns
# (that hook only fires on Edit/Write, missing agent launches entirely)
#
# Returns: additionalContext (advisory, non-blocking)
# We don't block agent spawns — just make the gap visible.

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fallback CWD
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
    exit 0
fi

STATE_FILE="$CWD/.claude/hooks/.delegation_state"

# No state file = first action in session
if [ ! -f "$STATE_FILE" ]; then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "SubagentStart",
            additionalContext: "⚠️ DELEGATION CHECK: Spawning sub-agent with no delegation tracking this session. If this is part of a multi-step task (2+ subtasks or 3+ files), present a delegation table first and run: bash mark_delegation_approved.sh"
        }
    }'
    exit 0
fi

# Read approval timestamp
LAST_APPROVAL=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")
NOW=$(date +%s)
AGE_SECONDS=$((NOW - LAST_APPROVAL))
AGE_MINUTES=$((AGE_SECONDS / 60))

# 30-minute approval window (matches delegation-reminder.sh)
if [ "$AGE_SECONDS" -gt 1800 ]; then
    jq -n --arg age "${AGE_MINUTES}m" '{
        hookSpecificOutput: {
            hookEventName: "SubagentStart",
            additionalContext: ("⚠️ DELEGATION NOT APPROVED: No delegation table was approved in the last " + $age + ". For multi-step work (2+ subtasks or 3+ files), present a delegation table and run: bash mark_delegation_approved.sh")
        }
    }'
    exit 0
fi

# Fresh approval — allow silently
exit 0
