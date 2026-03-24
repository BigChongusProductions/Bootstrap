#!/bin/bash
# SUPERSEDED by pre-edit-check.template.sh for Standard/Large tiers (BP-012)
# Still used directly by settings_lite.template.json for Small tier projects.
# Tier 3: Architecture File Protection
# Blocks Edit/Write to critical project files without human confirmation.
# These files control the entire workflow — unauthorized changes cause cascading damage.
#
# Protected patterns are configurable via .claude/hooks/protected-files.conf
# One pattern per line. If the file doesn't exist, defaults are used.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Get the file being modified
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# If no file path (shouldn't happen for Edit/Write, but be safe), allow
if [ -z "$FILE" ]; then
    exit 0
fi

# Load protected patterns
CONF_FILE="$CWD/.claude/hooks/protected-files.conf"

if [ -f "$CONF_FILE" ]; then
    # Read patterns from config (skip comments and blank lines)
    PATTERNS=()
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/#.*//' | xargs)  # strip comments + whitespace
        [ -n "$line" ] && PATTERNS+=("$line")
    done < "$CONF_FILE"
else
    # Default protected patterns
    PATTERNS=(
        "CLAUDE.md"
        "_RULES.md"
        "AGENT_DELEGATION.md"
        "db_queries.sh"
        "coherence_registry.sh"
        "coherence_check.sh"
        "session_briefing.sh"
        "milestone_check.sh"
        "save_session.sh"
        "work.sh"
        "fix.sh"
        ".git/hooks/"
        "frameworks/"
    )
fi

# Check if the file matches any protected pattern
BASENAME=$(basename "$FILE")
for pattern in "${PATTERNS[@]}"; do
    # Match against both full path and basename
    if [[ "$FILE" == *"$pattern"* ]] || [[ "$BASENAME" == *"$pattern"* ]]; then
        jq -n --arg file "$BASENAME" --arg pattern "$pattern" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: ("ARCHITECTURE PROTECTION: " + $file + " is a protected infrastructure file (matched: " + $pattern + "). Modifying it requires explicit human approval. Verify this change is intentional and won'\''t break the workflow engine.")
            }
        }'
        exit 0
    fi
done

# Not protected — allow silently
exit 0
