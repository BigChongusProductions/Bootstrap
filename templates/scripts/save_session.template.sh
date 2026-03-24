#!/usr/bin/env bash
# save_session.sh — Generate NEXT_SESSION.md from current DB + git state
# Usage: bash save_session.sh ["Session summary — what was accomplished"]
#
# Called manually or via: bash db_queries.sh save-session "summary"

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DB="$DIR/%%PROJECT_DB%%"
OUTFILE="$DIR/NEXT_SESSION.md"
SUMMARY="${1:-No summary provided}"
TODAY=$(date '+%Y-%m-%d')

# ─── Signal computation (shared with session_briefing.sh) ──────────────────
if [ ! -f "$DB" ]; then
    echo "❌ Database not found: $DB"
    exit 1
fi

source "$DIR/shared_signal.sh"
compute_signal "$DB"

# ─── State queries ─────────────────────────────────────────────────────────
CURRENT_PHASE=$(sqlite3 "$DB" "
    SELECT phase FROM tasks
    WHERE status='TODO' AND queue != 'INBOX'
    ORDER BY phase, sort_order LIMIT 1;
" 2>/dev/null)
[ -z "$CURRENT_PHASE" ] && CURRENT_PHASE="(all done)"

GATES_PASSED=$(sqlite3 "$DB" "
    SELECT GROUP_CONCAT(phase, ', ') FROM phase_gates WHERE gated_on IS NOT NULL;
" 2>/dev/null)
[ -z "$GATES_PASSED" ] && GATES_PASSED="None yet"

BLOCKED_COUNT=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM tasks
    WHERE status='TODO'
      AND blocked_by IS NOT NULL AND blocked_by != ''
      AND blocked_by NOT IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP'));
" 2>/dev/null)

READY_COUNT=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM tasks
    WHERE status='TODO' AND assignee='CLAUDE' AND queue != 'INBOX'
      AND (blocked_by IS NULL OR blocked_by = ''
           OR blocked_by IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP')));
" 2>/dev/null)

MASTER_PENDING=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM tasks WHERE status='TODO' AND assignee IN ('MASTER','GEMINI');
" 2>/dev/null)

# Next 3 ready Claude tasks
NEXT_3=$(sqlite3 "$DB" "
    SELECT '- ' || id || ' — ' || title
    FROM tasks
    WHERE status='TODO' AND assignee='CLAUDE' AND queue != 'INBOX'
      AND (blocked_by IS NULL OR blocked_by = ''
           OR blocked_by IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP')))
    ORDER BY phase, sort_order
    LIMIT 3;
" 2>/dev/null)
[ -z "$NEXT_3" ] && NEXT_3="- (none — all Claude tasks are blocked or done)"

# ─── Git: tasks completed this session ────────────────────────────────────
LAST_SESSION_TAG=$(git -C "$DIR" tag -l 'session/*' 2>/dev/null | sort -V | tail -1)
if [ -n "$LAST_SESSION_TAG" ]; then
    COMPLETED_THIS_SESSION=$(git -C "$DIR" log --oneline -10 "${LAST_SESSION_TAG}..HEAD" 2>/dev/null | sed 's/^/- /')
else
    COMPLETED_THIS_SESSION=$(git -C "$DIR" log --oneline -5 2>/dev/null | sed 's/^/- /')
fi
[ -z "$COMPLETED_THIS_SESSION" ] && COMPLETED_THIS_SESSION="- No commits since last session tag"

# ─── Write NEXT_SESSION.md ────────────────────────────────────────────────
cat > "$OUTFILE" << HEREDOC
# Next Session — %%PROJECT_NAME%%

**Handoff Source:** Claude Code
**Signal:** ${SIGNAL}
**Date Written:** ${TODAY}

---

## Session Start (copy-paste)

\`\`\`bash
cd %%PROJECT_PATH%%
bash session_briefing.sh
bash db_queries.sh next
\`\`\`

---

## State

- **Current Phase:** ${CURRENT_PHASE}
- **Phase Gates Passed:** ${GATES_PASSED}
- **First Task:** ${NEXT_TASK_ID:-(none)} — ${NEXT_TASK_TITLE}
- **Blocked Tasks:** ${BLOCKED_COUNT:-0}
- **Ready Tasks (Claude):** ${READY_COUNT:-0}
- **Master Pending:** ${MASTER_PENDING:-0}

---

## Session Summary

${SUMMARY}

---

## Overrides (active)

_None_

---

## Notes for Next Session

**Completed this session (git log):**
${COMPLETED_THIS_SESSION}

**Next up (Claude queue):**
${NEXT_3}

$(if [ -n "$SIGNAL_REASONS" ]; then printf "**Signal reasons (%s):**\n%b" "$SIGNAL" "$SIGNAL_REASONS"; fi)
HEREDOC

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Session Saved — $(date '+%b %d, %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Signal:    $SIGNAL"
echo "  Next task: ${NEXT_TASK_ID:-(none)} — ${NEXT_TASK_TITLE}"
echo "  Ready:     ${READY_COUNT:-0} Claude tasks   |   Blocked: ${BLOCKED_COUNT:-0}   |   Master pending: ${MASTER_PENDING:-0}"
echo ""
echo "  NEXT_SESSION.md written."
echo "  To start next session: bash work.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Lesson audit (non-fatal — surfaces stale/hot/violated lessons)
bash "$DIR/db_queries.sh" lesson-audit --quiet 2>/dev/null || true

# Log to DB
SAFE_SUMMARY=$(echo "$SUMMARY" | sed "s/'/''/g")
if ! sqlite3 "$DB" "INSERT INTO sessions (session_type, summary) VALUES ('Claude Code', '$SAFE_SUMMARY');" 2>&1; then
    echo "  ⚠️  Failed to log session to DB (DB may be locked or schema changed)"
fi

# Create session git tag (non-fatal)
bash "$DIR/db_queries.sh" tag-session 2>/dev/null || true

# Auto-commit DB if dirty after session log write
if ! git -C "$DIR" diff --quiet %%PROJECT_DB%% 2>/dev/null; then
    git -C "$DIR" add %%PROJECT_DB%%
    git -C "$DIR" commit -m "chore: auto-commit DB state at session end" --no-verify 2>/dev/null || true
fi
