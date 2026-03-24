#!/bin/bash
# SUPERSEDED by pre-edit-check.template.sh (BP-012) — kept for reference
# Tier 1: Delegation Gate Context Injection
# Fires on every Edit/Write tool call. Injects a reminder into Claude's context
# so the delegation gate is structurally harder to forget.
#
# How it works:
# - Reads tool_input from stdin (JSON)
# - Counts recent Edit/Write calls via a state file
# - First 1-2 edits: silent (single-file tasks are exempt)
# - 3+ edits without approval: escalates to "ask" (human must click through)
#
# State file: .claude/hooks/.delegation_state
# Format: line 1 = edit count, line 2 = last approval timestamp (epoch)

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

STATE_FILE="$CWD/.claude/hooks/.delegation_state"

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
    echo "0" >> "$STATE_FILE"
fi

# Read state
EDIT_COUNT=$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo "0")
LAST_APPROVAL=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")

# Increment counter
EDIT_COUNT=$((EDIT_COUNT + 1))

# Write updated count back
echo "$EDIT_COUNT" > "$STATE_FILE"
echo "$LAST_APPROVAL" >> "$STATE_FILE"

# Decision logic:
# - Edits 1-2: inject context reminder only (non-blocking)
# - Edits 3+: escalate to "ask" if no recent approval
# - After approval (mark_delegation_approved.sh sets timestamp): reset to advisory

NOW=$(date +%s)
APPROVAL_AGE=$((NOW - LAST_APPROVAL))
APPROVAL_FRESH=false
if [ "$APPROVAL_AGE" -lt 1800 ]; then  # 30 minutes
    APPROVAL_FRESH=true
fi

if [ "$EDIT_COUNT" -ge 3 ] && [ "$APPROVAL_FRESH" = "false" ]; then
    # Escalate: 3+ file edits without delegation approval
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: "DELEGATION GATE: 3+ file modifications detected without delegation approval. If this is a multi-step task (2+ subtasks or 3+ files), present a delegation table first. Run: bash mark_delegation_approved.sh to clear this gate after approval."
        }
    }'
else
    # Advisory: inject context reminder (non-blocking)
    jq -n --arg count "$EDIT_COUNT" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            additionalContext: ("DELEGATION GATE REMINDER (edit #" + $count + "): If this is part of a multi-step task (2+ subtasks or 3+ files), a delegation table must have been presented and approved. If you skipped it, STOP and present the table now.")
        }
    }'
fi
