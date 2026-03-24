#!/usr/bin/env bash
# =============================================================================
# TEMPLATE: db_queries.sh — Project SQLite Query Helpers
# Parameterized template — replace %%PLACEHOLDERS%% after copying
#
# Placeholders to replace before use:
#   %%PROJECT_DB%%          — SQLite database filename (e.g. my_project.db)
#   %%PROJECT_DB_NAME%%     — DB filename without extension (e.g. my_project)
#   %%LESSONS_FILE%%     — Lessons/corrections log filename (e.g. LESSONS_MYPROJECT.md)
#   AGENT_DELEGATION.md  — Agent delegation map filename (e.g. AGENT_DELEGATION.md)
#   %%PROJECT_NAME%%     — Human-readable project name (e.g. My Project)
#   %%PHASE_CASE_ORDINALS%%  — Bash case arms for phase_ordinal() function
#                             e.g. "P1-FOO) echo 0 ;; P2-BAR) echo 1 ;;"
#   %%PHASE_CASE_SQL%%       — SQL CASE arms for priority scoring
#                             e.g. "WHEN 'P1-FOO' THEN 0 WHEN 'P2-BAR' THEN 1"
#   %%PHASE_IN_SQL%%         — SQL IN list for health check
#                             e.g. "'P1-FOO', 'P2-BAR', 'P3-BAZ'"
# =============================================================================
# Project — SQLite Query Helpers
# Usage: bash db_queries.sh <command>

DB="$(dirname "$0")/%%PROJECT_DB%%"

if ! command -v sqlite3 &>/dev/null; then
    echo "❌ sqlite3 is not installed. DB commands require the sqlite3 CLI."
    echo "   Install: apt install sqlite3 (Linux) or brew install sqlite3 (macOS)"
    exit 1
fi

# Allow init-db to run without pre-existing file (it creates the DB)
if [ ! -f "$DB" ] && [ "$1" != "init-db" ]; then
    echo "❌ %%PROJECT_DB%% not found."
    echo "   Create it: bash db_queries.sh init-db"
    exit 1
fi

# Auto-apply migrations only if the tasks table exists (skip for fresh/empty DBs — use init-db first)
if [ -f "$DB" ] && sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='tasks'" 2>/dev/null | grep -q 1; then
    # Auto-create milestone_confirmations table if it doesn't exist
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS milestone_confirmations (
        task_id TEXT PRIMARY KEY,
        confirmed_on TEXT NOT NULL,
        confirmed_by TEXT DEFAULT 'MASTER',
        reasons TEXT
    );" 2>/dev/null

    # Auto-apply migrations (idempotent — each ALTER silently fails if column exists)
    for COL in "track TEXT DEFAULT 'forward'" "origin_phase TEXT" "discovered_in TEXT" \
               "severity INTEGER" "gate_critical INTEGER DEFAULT 0" "loopback_reason TEXT" \
               "details TEXT" "completed_on TEXT" "researched INTEGER DEFAULT 0"; do
        sqlite3 "$DB" "ALTER TABLE tasks ADD COLUMN $COL;" 2>/dev/null
    done
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS loopback_acks (
        loopback_id TEXT NOT NULL,
        acked_on TEXT NOT NULL,
        acked_by TEXT NOT NULL,
        reason TEXT NOT NULL,
        UNIQUE(loopback_id)
    );" 2>/dev/null
fi

# ── SQL sanitization ──────────────────────────────────────────
# Escapes single quotes for safe SQL interpolation.
# Rejects IDs containing SQL metacharacters (semicolons, dashes-dashes).
sanitize_id() {
    local val="$1"
    # Reject obviously malicious input (semicolons, double-dashes, quotes)
    if echo "$val" | grep -qE "[;'\"\`]|--" 2>/dev/null; then
        echo "❌ Invalid ID: contains forbidden characters" >&2
        exit 1
    fi
    # Additional safety: IDs should be alphanumeric + hyphens only
    if ! echo "$val" | grep -qE '^[A-Za-z0-9_-]+$' 2>/dev/null; then
        echo "❌ Invalid ID: must be alphanumeric with hyphens/underscores only" >&2
        exit 1
    fi
    echo "$val"
}

# Escapes single quotes for safe SQL string interpolation (for free-text fields)
sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

# Severity emoji helper
sev_icon() { case "$1" in 1) echo "🔴";; 2) echo "🟡";; 3) echo "🟢";; 4) echo "⚪";; *) echo "?";; esac; }

# Phase ordinal helper (for discovery lag analytics)
phase_ordinal() {
    case "$1" in
        %%PHASE_CASE_ORDINALS%%
        *) echo 99 ;;
    esac
}

case "$1" in

phase)
    echo ""
    echo "── Current Phase ─────────────────────────────────────────────"
    sqlite3 -column "$DB" "
        SELECT phase,
               COUNT(*) AS total,
               SUM(CASE WHEN status='DONE' THEN 1 ELSE 0 END) AS done,
               SUM(CASE WHEN status NOT IN ('DONE','SKIP') THEN 1 ELSE 0 END) AS remaining
        FROM tasks
        WHERE COALESCE(track,'forward')='forward'
        GROUP BY phase
        HAVING remaining > 0
        ORDER BY phase
        LIMIT 1;
    "
    echo ""
    ;;

blockers)
    echo ""
    echo "── Blockers: Master/Gemini tasks blocking Claude work ────────"
    BLOCKER_COUNT=$(sqlite3 "$DB" "
        SELECT COUNT(DISTINCT b.id)
        FROM tasks t
        JOIN tasks b ON t.blocked_by = b.id
        WHERE t.status != 'DONE'
          AND t.assignee = 'CLAUDE'
          AND b.status != 'DONE'
          AND b.assignee IN ('MASTER', 'GEMINI');
    " 2>/dev/null)

    if [ "$BLOCKER_COUNT" -gt 0 ]; then
        sqlite3 -column -header "$DB" "
            SELECT DISTINCT b.id AS blocker_id,
                   b.phase,
                   b.assignee,
                   b.title AS blocker_task,
                   GROUP_CONCAT(t.id, ', ') AS blocks_claude_tasks
            FROM tasks t
            JOIN tasks b ON t.blocked_by = b.id
            WHERE t.status != 'DONE'
              AND t.assignee = 'CLAUDE'
              AND b.status != 'DONE'
              AND b.assignee IN ('MASTER', 'GEMINI')
            GROUP BY b.id
            ORDER BY b.phase, b.sort_order;
        "
    else
        echo "  ✅ No Master/Gemini blockers — Claude work is unblocked"
    fi
    echo ""
    ;;

gate)
    echo ""
    echo "── Phase Gate Status ───────────────────────────────────────────"
    GATE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM phase_gates;" 2>/dev/null)
    if [ "$GATE_COUNT" -gt 0 ]; then
        sqlite3 -column -header "$DB" "
            SELECT phase, gated_on AS date, gated_by, notes
            FROM phase_gates
            ORDER BY phase;
        "
    else
        echo "  No phase gates passed yet."
    fi
    echo ""
    ;;

gate-pass)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh gate-pass <PHASE>"; exit 1; fi
    PHASE=$(echo "$2" | tr '[:lower:]' '[:upper:]')
    TODAY=$(date "+%b %d" | sed 's/ 0/ /')
    GATED_BY="${3:-MASTER}"
    NOTES="${4:-Phase gate review passed}"
    SAFE_NOTES=$(echo "$NOTES" | sed "s/'/''/g")
    sqlite3 "$DB" "INSERT OR REPLACE INTO phase_gates (phase, gated_on, gated_by, notes) VALUES ('$PHASE', '$TODAY', '$GATED_BY', '$SAFE_NOTES');"
    echo "🚧 Phase gate recorded: $PHASE passed ($TODAY, by $GATED_BY)"
    ;;

confirm)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh confirm <task-id> [reasons]"; exit 1; fi
    CONFIRM_ID=$(sanitize_id "$2") || exit 1
    TODAY=$(date "+%b %d" | sed 's/ 0/ /')
    CONFIRM_BY="${3:-MASTER}"
    CONFIRM_REASONS="${4:-Milestone confirmed}"
    # Verify task exists
    CONFIRM_CHECK=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$CONFIRM_ID';")
    if [ -z "$CONFIRM_CHECK" ]; then
        echo "❌ Task '$CONFIRM_ID' not found"
        exit 1
    fi
    sqlite3 "$DB" "INSERT OR REPLACE INTO milestone_confirmations (task_id, confirmed_on, confirmed_by, reasons) VALUES ('$CONFIRM_ID', '$TODAY', '$CONFIRM_BY', '$CONFIRM_REASONS');"
    echo "⏸️  Milestone confirmed: $CONFIRM_ID ($TODAY, by $CONFIRM_BY)"
    # Show confirmation history count
    TOTAL_CONFIRMS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM milestone_confirmations;" 2>/dev/null)
    echo "   Total milestone confirmations: $TOTAL_CONFIRMS"
    ;;

confirmations)
    echo ""
    echo "── Milestone Confirmations ─────────────────────────────────"
    CONF_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM milestone_confirmations;" 2>/dev/null)
    if [ "$CONF_COUNT" -gt 0 ]; then
        sqlite3 -column -header "$DB" "
            SELECT mc.task_id, mc.confirmed_on AS date, mc.confirmed_by AS by,
                   t.phase, t.title
            FROM milestone_confirmations mc
            JOIN tasks t ON mc.task_id = t.id
            ORDER BY t.sort_order;
        "
    else
        echo "  No milestone confirmations recorded yet."
    fi
    echo ""
    ;;

check)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh check <task-id>"; exit 1; fi
    TASK_ID=$(sanitize_id "$2") || exit 1
    CHECK_PASS=true

    TASK_INFO=$(sqlite3 "$DB" "SELECT phase || '|' || assignee || '|' || COALESCE(blocked_by,'') || '|' || status || '|' || title || '|' || COALESCE(needs_browser,0) || '|' || sort_order FROM tasks WHERE id='$TASK_ID';")
    if [ -z "$TASK_INFO" ]; then
        echo "❌ STOP — Task '$TASK_ID' not found in database"
        exit 1
    fi

    TASK_PHASE=$(echo "$TASK_INFO" | cut -d'|' -f1)
    TASK_ASSIGNEE=$(echo "$TASK_INFO" | cut -d'|' -f2)
    TASK_BLOCKED=$(echo "$TASK_INFO" | cut -d'|' -f3)
    TASK_STATUS=$(echo "$TASK_INFO" | cut -d'|' -f4)
    TASK_TITLE=$(echo "$TASK_INFO" | cut -d'|' -f5)
    TASK_BROWSER=$(echo "$TASK_INFO" | cut -d'|' -f6)
    TASK_SORT=$(echo "$TASK_INFO" | cut -d'|' -f7)

    echo ""
    echo "── Pre-Task Check: $TASK_ID — $TASK_TITLE ─────"

    # Extract track (defaults to 'forward' for old tasks)
    TASK_TRACK=$(sqlite3 "$DB" "SELECT COALESCE(track,'forward') FROM tasks WHERE id='$TASK_ID';")

    if [ "$TASK_TRACK" = "loopback" ]; then
        # ── Loopback check: relaxed phase rules ──
        echo "  ℹ️  Track: loopback (phase gate checks skipped)"
        TASK_SEV=$(sqlite3 "$DB" "SELECT severity FROM tasks WHERE id='$TASK_ID';")
        TASK_GC=$(sqlite3 "$DB" "SELECT gate_critical FROM tasks WHERE id='$TASK_ID';")
        TASK_ORIGIN=$(sqlite3 "$DB" "SELECT origin_phase FROM tasks WHERE id='$TASK_ID';")
        echo "  Origin: ${TASK_ORIGIN:-?} | Severity: S${TASK_SEV:-?} | Gate-critical: $([ "$TASK_GC" = "1" ] && echo 'YES' || echo 'no')"

        if [ "$TASK_STATUS" = "DONE" ]; then
            echo "  ⚠️  Task is already DONE"
            exit 0
        fi

        # Check 1: Assigned to Claude?
        if [ "$TASK_ASSIGNEE" != "CLAUDE" ]; then
            echo "  🛑 STOP — Task is assigned to $TASK_ASSIGNEE, not Claude"
            echo ""; echo "  🛑 CANNOT PROCEED"; exit 1
        fi

        # Check 2: blocked_by resolved?
        if [ -n "$TASK_BLOCKED" ]; then
            BLOCKER_STATUS=$(sqlite3 "$DB" "SELECT status FROM tasks WHERE id='$TASK_BLOCKED';")
            if [ -n "$BLOCKER_STATUS" ] && [ "$BLOCKER_STATUS" != "DONE" ] && [ "$BLOCKER_STATUS" != "SKIP" ]; then
                echo "  🛑 STOP — Blocked by $TASK_BLOCKED ($BLOCKER_STATUS)"
                echo ""; echo "  🛑 CANNOT PROCEED"; exit 1
            elif [ -z "$BLOCKER_STATUS" ]; then
                echo "  ⚠️  WARN — blocked_by '$TASK_BLOCKED' not found (stale reference)"
            fi
        fi

        # Lesson recall (reuse forward-task logic)
        LESSONS_FILE="$(dirname "$0")/%%LESSONS_FILE%%"
        if [ -f "$LESSONS_FILE" ]; then
            LB_KEYWORDS=$(echo "$TASK_TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | awk 'length >= 4' | head -8)
            LB_LESSON_HITS=""
            for KW in $LB_KEYWORDS; do
                HITS=$(grep -i "$KW" "$LESSONS_FILE" 2>/dev/null | grep "^|" | grep -v "^| Date" | grep -v "^|---" | head -2)
                [ -n "$HITS" ] && LB_LESSON_HITS="${LB_LESSON_HITS}${HITS}\n"
            done
            if [ -n "$LB_LESSON_HITS" ]; then
                UNIQUE_LB=$(echo -e "$LB_LESSON_HITS" | sort -u | head -3)
                if [ -n "$UNIQUE_LB" ]; then
                    echo ""
                    echo "  📖 Relevant lessons:"
                    echo "$UNIQUE_LB" | while IFS= read -r line; do
                        PATTERN=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
                        [ -n "$PATTERN" ] && echo "     ⚠️  $PATTERN"
                    done
                fi
            fi
        fi

        echo ""; echo "  ✅ GO — $TASK_ID is clear to start (loopback)"
        echo ""
        exit 0
    fi

    if [ "$TASK_STATUS" = "DONE" ]; then
        echo "  ⚠️  Task is already DONE"
        exit 0
    fi

    # Check: assigned to Claude?
    if [ "$TASK_ASSIGNEE" != "CLAUDE" ]; then
        echo "  🛑 STOP — Task is assigned to $TASK_ASSIGNEE, not Claude"
        CHECK_PASS=false
    fi

    # Check: prior phase incomplete?
    PRIOR_INCOMPLETE=$(sqlite3 "$DB" "
        SELECT phase || ': ' || COUNT(*) || ' task(s)'
        FROM tasks
        WHERE status NOT IN ('DONE','SKIP')
        AND COALESCE(track,'forward')='forward'
        AND phase < '$TASK_PHASE'
        AND queue != 'INBOX'
        GROUP BY phase;
    " 2>/dev/null)
    if [ -n "$PRIOR_INCOMPLETE" ]; then
        echo "  🛑 STOP — Prior phase(s) have incomplete tasks: $PRIOR_INCOMPLETE"
        CHECK_PASS=false
    fi

    # Check: prior phase gated?
    # Get the list of phases before this one that exist in the DB
    PHASES_BEFORE=$(sqlite3 "$DB" "
        SELECT DISTINCT phase FROM tasks
        WHERE phase < '$TASK_PHASE'
        ORDER BY phase;
    " 2>/dev/null)

    for PRIOR_PHASE in $PHASES_BEFORE; do
        GATE_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM phase_gates WHERE phase='$PRIOR_PHASE';" 2>/dev/null)
        if [ "$GATE_EXISTS" -eq 0 ]; then
            echo "  🛑 STOP — $PRIOR_PHASE phase gate not passed (run: bash db_queries.sh gate-pass $PRIOR_PHASE)"
            CHECK_PASS=false
        fi
    done

    # Check: blocked by unfinished dependency?
    # Cross-phase blockers are hard STOPs. Same-phase blockers are soft hints.
    if [ -n "$TASK_BLOCKED" ]; then
        BLOCKER_INFO=$(sqlite3 "$DB" "SELECT status || '|' || assignee || '|' || title || '|' || phase FROM tasks WHERE id='$TASK_BLOCKED';")
        if [ -z "$BLOCKER_INFO" ]; then
            echo "  ⚠️  WARN — blocked_by '$TASK_BLOCKED' references a nonexistent task (stale reference)"
            echo "         Fix: bash db_queries.sh unblock $TASK_ID"
        else
            BLOCKER_STATUS=$(echo "$BLOCKER_INFO" | cut -d'|' -f1)
            BLOCKER_ASSIGNEE=$(echo "$BLOCKER_INFO" | cut -d'|' -f2)
            BLOCKER_TITLE=$(echo "$BLOCKER_INFO" | cut -d'|' -f3)
            BLOCKER_PHASE=$(echo "$BLOCKER_INFO" | cut -d'|' -f4)
            if [ "$BLOCKER_STATUS" != "DONE" ] && [ "$BLOCKER_STATUS" != "SKIP" ]; then
                if [ "$BLOCKER_PHASE" != "$TASK_PHASE" ]; then
                    # Cross-phase: hard STOP
                    echo "  🛑 STOP — Blocked by $TASK_BLOCKED ($BLOCKER_ASSIGNEE, $BLOCKER_STATUS): $BLOCKER_TITLE"
                    CHECK_PASS=false
                else
                    # Same-phase: soft hint — warn but don't block
                    echo "  ⚠️  HINT — $TASK_BLOCKED is not yet done ($BLOCKER_STATUS), recommended to complete first"
                    echo "         Override: proceed if order doesn't matter for this task"
                fi
            fi
        fi
    fi

    # ── Milestone Gate (auto-detect) ──────────────────────────────
    # Runs ONLY when all STOP checks pass. Detects structural
    # checkpoints where Master confirmation is required.
    # Four rules: FIRST_IN_PHASE, FOLLOWS_EXTERNAL,
    #             LAST_CLAUDE_IN_PHASE, ROLLING(5)
    # Fully stateless — pure function of DB state.
    # ──────────────────────────────────────────────────────────────
    MILESTONE_REASONS=""

    if [ "$CHECK_PASS" = true ]; then

        # Rule 1: First Claude task in this phase (no DONE Claude tasks in same phase)
        DONE_CLAUDE_IN_PHASE=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE phase='$TASK_PHASE'
              AND assignee='CLAUDE'
              AND status='DONE';
        " 2>/dev/null)
        if [ "$DONE_CLAUDE_IN_PHASE" -eq 0 ]; then
            MILESTONE_REASONS="${MILESTONE_REASONS}  - First Claude task in phase $TASK_PHASE\n"
        fi

        # Rule 2: Previous task (by sort_order, excl. SKIP) is Master/Gemini
        PREV_TASK_INFO=$(sqlite3 "$DB" "
            SELECT assignee || '|' || id || '|' || title FROM tasks
            WHERE sort_order < $TASK_SORT
              AND status != 'SKIP'
            ORDER BY sort_order DESC
            LIMIT 1;
        " 2>/dev/null)
        if [ -n "$PREV_TASK_INFO" ]; then
            PREV_ASSIGNEE=$(echo "$PREV_TASK_INFO" | cut -d'|' -f1)
            PREV_ID=$(echo "$PREV_TASK_INFO" | cut -d'|' -f2)
            PREV_TITLE=$(echo "$PREV_TASK_INFO" | cut -d'|' -f3)
            if [ "$PREV_ASSIGNEE" = "MASTER" ] || [ "$PREV_ASSIGNEE" = "GEMINI" ]; then
                MILESTONE_REASONS="${MILESTONE_REASONS}  - Follows $PREV_ASSIGNEE task $PREV_ID: $PREV_TITLE\n"
            fi
        fi

        # Rule 3: Last remaining Claude task in this phase
        REMAINING_CLAUDE=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE phase='$TASK_PHASE'
              AND assignee='CLAUDE'
              AND status NOT IN ('DONE','SKIP')
              AND id != '$TASK_ID';
        " 2>/dev/null)
        if [ "$REMAINING_CLAUDE" -eq 0 ]; then
            REMAINING_MASTER=$(sqlite3 "$DB" "
                SELECT GROUP_CONCAT(id, ', ') FROM tasks
                WHERE phase='$TASK_PHASE'
                  AND assignee IN ('MASTER','GEMINI')
                  AND status NOT IN ('DONE','SKIP');
            " 2>/dev/null)
            if [ -n "$REMAINING_MASTER" ]; then
                MILESTONE_REASONS="${MILESTONE_REASONS}  - Last Claude task in $TASK_PHASE — Master tasks remain: $REMAINING_MASTER\n"
            else
                MILESTONE_REASONS="${MILESTONE_REASONS}  - Last task in $TASK_PHASE — phase gate review follows\n"
            fi
        fi

        # Rule 4: Rolling checkpoint
        # Two strategies (preferred → fallback):
        #   A. If milestone_confirmations has data: count DONE Claude tasks
        #      since the last confirmed task's sort_order. This is the most
        #      accurate signal — it tracks actual Master approvals.
        #   B. If no confirmations exist: structural detection — walk backward
        #      through DONE tasks counting until a natural checkpoint
        #      (rules 1-3 would have fired there).
        ROLLING_THRESHOLD=5

        # Strategy A: check milestone_confirmations for last confirmed sort_order
        LAST_CONFIRMED_SORT=$(sqlite3 "$DB" "
            SELECT MAX(t.sort_order) FROM milestone_confirmations mc
            JOIN tasks t ON mc.task_id = t.id
            WHERE t.sort_order < $TASK_SORT;
        " 2>/dev/null)
        LAST_CONFIRMED_SORT=${LAST_CONFIRMED_SORT:-0}

        if [ "$LAST_CONFIRMED_SORT" -gt 0 ]; then
            # Strategy A: count DONE Claude tasks since last confirmation
            ROLLING_COUNT=$(sqlite3 "$DB" "
                SELECT COUNT(*) FROM tasks
                WHERE assignee='CLAUDE'
                  AND status='DONE'
                  AND sort_order > $LAST_CONFIRMED_SORT
                  AND sort_order < $TASK_SORT;
            " 2>/dev/null)
            ROLLING_COUNT=${ROLLING_COUNT:-0}
            if [ "$ROLLING_COUNT" -ge "$ROLLING_THRESHOLD" ]; then
                MILESTONE_REASONS="${MILESTONE_REASONS}  - Rolling checkpoint: $ROLLING_COUNT tasks since last confirmed milestone\n"
            fi
        else
            # Strategy B: structural detection (no confirmations recorded yet)
            ROLLING_COUNT=$(sqlite3 "$DB" "
                WITH done_claude AS (
                    SELECT id, phase, sort_order,
                        ROW_NUMBER() OVER (ORDER BY sort_order DESC) AS rn
                    FROM tasks
                    WHERE assignee='CLAUDE'
                      AND status='DONE'
                      AND sort_order < $TASK_SORT
                    ORDER BY sort_order DESC
                ),
                with_checks AS (
                    SELECT dc.*,
                        (SELECT COUNT(*) FROM tasks t2
                         WHERE t2.phase = dc.phase
                           AND t2.assignee = 'CLAUDE'
                           AND t2.status = 'DONE'
                           AND t2.sort_order < dc.sort_order) AS done_before_in_phase,
                        COALESCE((SELECT t3.assignee FROM tasks t3
                         WHERE t3.sort_order < dc.sort_order
                           AND t3.status != 'SKIP'
                         ORDER BY t3.sort_order DESC LIMIT 1), '') AS prev_assignee,
                        (SELECT COUNT(*) FROM tasks t4
                         WHERE t4.phase = dc.phase
                           AND t4.assignee = 'CLAUDE'
                           AND t4.sort_order > dc.sort_order) AS later_in_phase
                    FROM done_claude dc
                ),
                counted AS (
                    SELECT *,
                        CASE WHEN done_before_in_phase = 0 THEN 1
                             WHEN prev_assignee IN ('MASTER','GEMINI') THEN 1
                             WHEN later_in_phase = 0 THEN 1
                             ELSE 0 END AS is_checkpoint
                    FROM with_checks
                    ORDER BY sort_order DESC
                )
                SELECT COUNT(*) FROM (
                    SELECT sort_order, is_checkpoint,
                        SUM(is_checkpoint) OVER (ORDER BY sort_order DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cp_seen
                    FROM counted
                ) sub
                WHERE cp_seen = 0;
            " 2>/dev/null)
            ROLLING_COUNT=${ROLLING_COUNT:-0}
            if [ "$ROLLING_COUNT" -ge "$ROLLING_THRESHOLD" ]; then
                MILESTONE_REASONS="${MILESTONE_REASONS}  - Rolling checkpoint: $ROLLING_COUNT tasks since last structural confirm\n"
            fi
        fi

        # ── Circuit breaker: unresolved S1 gate-critical loopbacks ──
        UNACKED_CB=$(sqlite3 "$DB" "
            SELECT t.id || ': ' || t.title
            FROM tasks t
            LEFT JOIN loopback_acks la ON t.id = la.loopback_id
            WHERE t.track='loopback' AND t.severity=1 AND t.gate_critical=1
              AND t.status NOT IN ('DONE','SKIP')
              AND la.loopback_id IS NULL;
        " 2>/dev/null)
        if [ -n "$UNACKED_CB" ]; then
            echo ""
            echo "  ⚠️  CIRCUIT BREAKER — Unresolved S1 gate-critical loopback(s):"
            echo "$UNACKED_CB" | while read -r line; do echo "    $line"; done
            echo ""
            echo "  Acknowledge to continue: bash db_queries.sh ack-breaker <LB-ID> \"reason\""
            MILESTONE_REASONS="${MILESTONE_REASONS}  - Circuit breaker: S1 loopback(s) unresolved\n"
        fi

    fi

    # ── Lesson Recall ─────────────────────────────────────────────
    # Grep LESSONS file for keywords relevant to this task.
    # Surfaces past corrections as reminders before work begins.
    # ──────────────────────────────────────────────────────────────
    LESSONS_FILE="$(dirname "$0")/%%LESSONS_FILE%%"
    LESSON_HITS=""
    if [ -f "$LESSONS_FILE" ] && [ "$CHECK_PASS" = true ]; then
        # Build keyword list from task title (lowercase, split on spaces, filter short words)
        KEYWORDS=$(echo "$TASK_TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | awk 'length >= 4' | head -8)

        # Also add generic keywords based on task context
        # If task involves delegation/sub-agents, surface delegation lessons
        TASK_DETAILS=$(sqlite3 "$DB" "SELECT COALESCE(details,'') FROM tasks WHERE id='$TASK_ID';" 2>/dev/null)
        COMBINED_TEXT=$(echo "$TASK_TITLE $TASK_DETAILS" | tr '[:upper:]' '[:lower:]')

        CONTEXT_KEYWORDS=""
        case "$COMBINED_TEXT" in
            *delegat*|*sub-agent*|*subagent*|*haiku*|*sonnet*|*tier*) CONTEXT_KEYWORDS="delegation tier" ;;
        esac
        case "$COMBINED_TEXT" in
            *handoff*|*next_session*|*session*|*save*) CONTEXT_KEYWORDS="$CONTEXT_KEYWORDS handoff intent fact" ;;
        esac
        case "$COMBINED_TEXT" in
            *model*|*orchestrat*|*opus*) CONTEXT_KEYWORDS="$CONTEXT_KEYWORDS model verification orchestrator" ;;
        esac
        case "$COMBINED_TEXT" in
            *phase*|*gate*|*batch*) CONTEXT_KEYWORDS="$CONTEXT_KEYWORDS delegation batch phase" ;;
        esac

        ALL_KEYWORDS="$KEYWORDS $CONTEXT_KEYWORDS"

        # Search corrections section for matching patterns
        for KW in $ALL_KEYWORDS; do
            HITS=$(grep -i "$KW" "$LESSONS_FILE" 2>/dev/null | grep "^|" | grep -v "^| Date" | grep -v "^|---" | head -3)
            if [ -n "$HITS" ]; then
                LESSON_HITS="${LESSON_HITS}${HITS}\n"
            fi
        done

        # Deduplicate hits
        if [ -n "$LESSON_HITS" ]; then
            UNIQUE_HITS=$(echo -e "$LESSON_HITS" | sort -u | head -5)
            if [ -n "$UNIQUE_HITS" ]; then
                echo ""
                echo "  📖 Relevant lessons from past corrections:"
                echo "$UNIQUE_HITS" | while IFS= read -r line; do
                    # Extract just the Pattern and Prevention Rule columns
                    PATTERN=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
                    RULE=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}')
                    if [ -n "$PATTERN" ] && [ -n "$RULE" ]; then
                        echo "     ⚠️  $PATTERN"
                        echo "     → $RULE"
                        echo ""
                    fi
                done
                # Update "Last Referenced" date for matched lessons
                TODAY_REF=$(date "+%Y-%m-%d")
                # Use sed to update the Last Referenced column for any matched pattern
                echo "$UNIQUE_HITS" | while IFS= read -r line; do
                    PATTERN_TEXT=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
                    if [ -n "$PATTERN_TEXT" ]; then
                        # Escape special characters for sed
                        ESCAPED=$(echo "$PATTERN_TEXT" | sed 's/[&/\]/\\&/g' | head -c 40)
                        sed -i "/$ESCAPED/s/| [0-9-]* |/| $TODAY_REF |/" "$LESSONS_FILE" 2>/dev/null
                    fi
                done
            fi
        fi
    fi

    # ── Critical File Awareness ────────────────────────────────────
    # Match task title/details keywords against the critical files
    # registry to surface audit prompts BEFORE work begins.
    # ────────────────────────────────────────────────────────────────
    CRITICAL_REGISTRY="$(dirname "$0")/critical_files_registry.sh"
    if [ -f "$CRITICAL_REGISTRY" ] && [ "$CHECK_PASS" = true ]; then
        source "$CRITICAL_REGISTRY"
        CRIT_KEYWORDS=$(echo "$TASK_TITLE $TASK_DETAILS" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:].' '\n' | awk 'length >= 3' | head -15)
        CRIT_HITS=""
        CRIT_ENTRY_COUNT=${#CRITICAL_PATTERNS[@]}

        for (( ci=0; ci<CRIT_ENTRY_COUNT; ci++ )); do
            pattern="${CRITICAL_PATTERNS[$ci]}"
            level="${CRITICAL_LEVELS[$ci]}"
            audit="${CRITICAL_AUDITS[$ci]}"
            pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')

            for kw in $CRIT_KEYWORDS; do
                if [[ "$pattern_lower" == *"$kw"* ]]; then
                    CRIT_HITS="${CRIT_HITS}     [$level] $pattern\n     → $audit\n\n"
                    break  # Don't double-match same pattern
                fi
            done
        done

        if [ -n "$CRIT_HITS" ]; then
            echo ""
            echo "  🔒 Critical files likely touched by this task:"
            echo -e "$CRIT_HITS"
        fi
    fi

    # ── Assumption Check (Layer 1) ──────────────────────────────
    # If task has unverified assumptions → ASSUME verdict
    # Only for Sonnet/Opus tasks (Haiku tasks are mechanical)
    ASSUME_BLOCK=false
    if [ "$CHECK_PASS" = true ]; then
        TASK_TIER=$(sqlite3 "$DB" "SELECT COALESCE(tier,'') FROM tasks WHERE id='$TASK_ID';" 2>/dev/null)
        if [ "$TASK_TIER" = "Sonnet" ] || [ "$TASK_TIER" = "Opus" ] || [ "$TASK_TIER" = "sonnet" ] || [ "$TASK_TIER" = "opus" ]; then
            UNVERIFIED=$(sqlite3 "$DB" "
                SELECT COUNT(*) FROM assumptions
                WHERE task_id='$TASK_ID' AND verified=0;
            " 2>/dev/null)
            UNVERIFIED=${UNVERIFIED:-0}
            if [ "$UNVERIFIED" -gt 0 ]; then
                echo ""
                echo "  🔬 ASSUME — $UNVERIFIED unverified assumption(s) for $TASK_ID:"
                sqlite3 "$DB" "
                    SELECT '     ' || id || '. ' || assumption ||
                           CASE WHEN verify_cmd IS NOT NULL THEN ' [cmd: ' || verify_cmd || ']' ELSE ' [manual]' END
                    FROM assumptions
                    WHERE task_id='$TASK_ID' AND verified=0;
                " 2>/dev/null
                echo ""
                echo "  Run: bash db_queries.sh verify-all $TASK_ID"
                ASSUME_BLOCK=true
            fi
        fi
    fi

    # ── Research Brief Check (Layer 2) ────────────────────────────
    # Soft gate: warns if Sonnet/Opus task not researched
    RESEARCH_WARN=false
    if [ "$CHECK_PASS" = true ] && [ "$ASSUME_BLOCK" = false ]; then
        TASK_TIER=$(sqlite3 "$DB" "SELECT COALESCE(tier,'') FROM tasks WHERE id='$TASK_ID';" 2>/dev/null)
        if [ "$TASK_TIER" = "Sonnet" ] || [ "$TASK_TIER" = "Opus" ] || [ "$TASK_TIER" = "sonnet" ] || [ "$TASK_TIER" = "opus" ]; then
            TASK_RESEARCHED=$(sqlite3 "$DB" "SELECT COALESCE(researched,0) FROM tasks WHERE id='$TASK_ID';" 2>/dev/null)
            if [ "$TASK_RESEARCHED" != "1" ]; then
                RESEARCH_WARN=true
            fi
        fi
    fi

    # ── Output verdict ────────────────────────────────────────────
    if [ "$CHECK_PASS" != true ]; then
        echo ""
        echo "  🛑 CANNOT PROCEED — resolve issues above first"
    elif [ "$ASSUME_BLOCK" = true ]; then
        echo ""
        echo "  🔬 ASSUME — Verify assumptions before starting $TASK_ID"
        echo "  Orchestrator must verify or clear assumptions before spawning sub-agents."
        if [ "$TASK_BROWSER" = "1" ]; then
            echo ""
            echo "  🌐 This task also requires browser review"
        fi
    elif [ -n "$MILESTONE_REASONS" ]; then
        echo ""
        echo "  ⏸️  CONFIRM — Milestone checkpoint before starting $TASK_ID"
        echo -e "$MILESTONE_REASONS"
        echo "  Present current progress to Master and wait for explicit approval."
        echo "  Master says 'go' → run: bash db_queries.sh confirm $TASK_ID → then proceed."
        echo "  Master says 'skip gate' → proceed + log override in session."
        # Still show browser flag if applicable
        if [ "$TASK_BROWSER" = "1" ]; then
            echo ""
            echo "  🌐 This task also requires browser review"
        fi
    else
        echo "  ✅ GO — $TASK_ID is clear to start"
        if [ "$RESEARCH_WARN" = true ]; then
            echo ""
            echo "  📚 RESEARCH — Task not marked as researched. Before coding:"
            echo "     1. Read lesson recall output above"
            echo "     2. Query context7 if using library APIs"
            echo "     3. Grep codebase for existing patterns to reuse"
            echo "     4. Verify types/interfaces this task depends on"
            echo "     Mark done: bash db_queries.sh researched $TASK_ID"
        fi
        # Auto-launch dev server + browser for visual tasks
        if [ "$TASK_BROWSER" = "1" ]; then
            echo ""
            echo "  🌐 This task requires browser review"
            bash "$(dirname "$0")/dev-review.sh"
        fi
    fi

    # ── UI Stress Checklist (Layer 3) ──────────────────────────────
    if [ "$TASK_BROWSER" = "1" ] && [ "$CHECK_PASS" = true ]; then
        echo ""
        echo "  UI Stress Checklist:"
        echo "  [ ] Viewport 320x568 (iPhone SE) — no overflow/clipped pins"
        echo "  [ ] Viewport 2560x1440 — no stretched elements"
        echo "  [ ] Rapid-click 5 pins in <2s — no stale tooltips"
        echo "  [ ] Rapid-switch all 7 periods — no overlay ghosting"
        echo "  [ ] Click pin → switch period → no orphaned panel"
    fi
    echo ""
    ;;

next)
    # Usage: bash db_queries.sh next [--ready-only] [--smart]
    # --ready-only: skip BLOCKED and STALE sections (saves ~800 tokens in session start)
    # --smart: score FORWARD tasks by impact (phase priority + blocking multiplier)
    READY_ONLY=0
    SMART=0
    for arg in "${@:2}"; do
        case "$arg" in
            --ready-only) READY_ONLY=1 ;;
            --smart) SMART=1 ;;
        esac
    done

    echo ""
    echo "── Task Queue ────────────────────────────────────────────────"

    # ── Circuit breaker check ──
    CB_COUNT=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tasks
        WHERE track='loopback' AND severity=1 AND gate_critical=1
          AND status NOT IN ('DONE','SKIP');
    " 2>/dev/null)

    if [ "$CB_COUNT" -gt 0 ]; then
        echo ""
        echo "  🔴 CIRCUIT BREAKER ($CB_COUNT S1 gate-critical loopback(s)):"
        sqlite3 "$DB" "
            SELECT '    ' || t.id || '  ' || t.title ||
                   '  [origin: ' || COALESCE(t.origin_phase,'?') || ', found: ' || COALESCE(t.discovered_in,'?') || ']' ||
                   CASE WHEN la.loopback_id IS NOT NULL THEN '  (acknowledged)' ELSE '' END
            FROM tasks t
            LEFT JOIN loopback_acks la ON t.id = la.loopback_id
            WHERE t.track='loopback' AND t.severity=1 AND t.gate_critical=1
              AND t.status NOT IN ('DONE','SKIP')
            ORDER BY t.sort_order;
        "
        # Blast radius
        sqlite3 "$DB" "
            SELECT '    Blast radius: ' || t.origin_phase || ' → ' ||
                   (SELECT COUNT(DISTINCT phase) FROM tasks
                    WHERE phase > t.origin_phase AND COALESCE(track,'forward')='forward') || ' phase(s) downstream'
            FROM tasks t
            WHERE t.track='loopback' AND t.severity=1 AND t.gate_critical=1
              AND t.status NOT IN ('DONE','SKIP');
        " 2>/dev/null
        echo ""
    fi

    # ── S2 Loopbacks ──
    S2_COUNT=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tasks t
        LEFT JOIN tasks b ON t.blocked_by = b.id
        WHERE t.track='loopback' AND t.severity=2
          AND t.status NOT IN ('DONE','SKIP')
          AND (t.blocked_by IS NULL OR t.blocked_by = '' OR b.status IN ('DONE','SKIP') OR b.id IS NULL);
    " 2>/dev/null)
    if [ "$S2_COUNT" -gt 0 ]; then
        echo "  🟡 LOOPBACK S2 ($S2_COUNT):"
        sqlite3 "$DB" "
            SELECT '    ' || t.id || '  ' || t.title ||
                   '  [origin: ' || COALESCE(t.origin_phase,'?') || ']' ||
                   CASE WHEN t.gate_critical=1 THEN '  gate-critical' ELSE '' END
            FROM tasks t
            LEFT JOIN tasks b ON t.blocked_by = b.id
            WHERE t.track='loopback' AND t.severity=2
              AND t.status NOT IN ('DONE','SKIP')
              AND (t.blocked_by IS NULL OR t.blocked_by = '' OR b.status IN ('DONE','SKIP') OR b.id IS NULL)
            ORDER BY t.sort_order;
        "
        echo ""
    fi

    # ── Forward READY tasks ──
    if [ "$SMART" -eq 1 ]; then
        echo "  📋 FORWARD (scored by impact):"
        sqlite3 -column -header "$DB" "
            SELECT t.id, t.priority, t.title, t.phase,
                   COALESCE(ub.unblocks, 0) AS unblocks,
                   (
                     (6 - CASE t.phase
                       %%PHASE_CASE_SQL%%
                       ELSE 7 END) * 100
                     + COALESCE(ub.unblocks, 0) * 10
                     + CASE t.priority
                       WHEN 'P0' THEN 50 WHEN 'P1' THEN 40 WHEN 'P2' THEN 30
                       WHEN 'P3' THEN 25 WHEN 'QK' THEN 20 WHEN 'LB' THEN 15
                       ELSE 10 END
                   ) AS score
            FROM tasks t
            LEFT JOIN (
                SELECT blocked_by, COUNT(*) AS unblocks
                FROM tasks WHERE status='TODO'
                  AND blocked_by IS NOT NULL AND length(blocked_by) > 0
                GROUP BY blocked_by
            ) ub ON ub.blocked_by = t.id
            LEFT JOIN tasks b ON t.blocked_by = b.id
            WHERE t.status='TODO' AND t.assignee='CLAUDE'
                AND t.queue <> 'INBOX'
                AND COALESCE(t.track,'forward') = 'forward'
                AND (t.blocked_by IS NULL OR length(t.blocked_by) = 0
                     OR b.status IN ('DONE','SKIP') OR b.id IS NULL)
            ORDER BY score DESC
            LIMIT 8;
        "
    else
        echo "  📋 FORWARD (ready):"
        sqlite3 -column -header "$DB" "
            SELECT t.id, t.priority, t.title, t.phase
            FROM tasks t
            LEFT JOIN tasks b ON t.blocked_by = b.id
            WHERE t.status='TODO' AND t.assignee='CLAUDE'
              AND t.queue != 'INBOX'
              AND COALESCE(t.track,'forward') = 'forward'
              AND (t.blocked_by IS NULL OR t.blocked_by = ''
                   OR b.status = 'DONE' OR b.status = 'SKIP'
                   OR b.id IS NULL)
            ORDER BY t.phase, t.sort_order
            LIMIT 8;
        "
    fi
    echo ""

    # ── S3/S4 Loopbacks ──
    S34_COUNT=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tasks t
        LEFT JOIN tasks b ON t.blocked_by = b.id
        WHERE t.track='loopback' AND t.severity IN (3,4)
          AND t.status NOT IN ('DONE','SKIP')
          AND (t.blocked_by IS NULL OR t.blocked_by = '' OR b.status IN ('DONE','SKIP') OR b.id IS NULL);
    " 2>/dev/null)
    if [ "$S34_COUNT" -gt 0 ]; then
        echo "  🟢 LOOPBACK S3/S4 ($S34_COUNT):"
        sqlite3 "$DB" "
            SELECT '    ' ||
                CASE t.severity WHEN 3 THEN '🟢' WHEN 4 THEN '⚪' ELSE '?' END ||
                ' ' || t.id || '  ' || t.title ||
                '  [origin: ' || COALESCE(t.origin_phase,'?') || ']'
            FROM tasks t
            LEFT JOIN tasks b ON t.blocked_by = b.id
            WHERE t.track='loopback' AND t.severity IN (3,4)
              AND t.status NOT IN ('DONE','SKIP')
              AND (t.blocked_by IS NULL OR t.blocked_by = '' OR b.status IN ('DONE','SKIP') OR b.id IS NULL)
            ORDER BY t.severity ASC, t.sort_order ASC;
        "
        echo ""
    fi

    # ── BLOCKED section (both tracks) ──
    if [ "$READY_ONLY" -eq 1 ]; then
        BLOCKED_COUNT=$(sqlite3 "$DB" "
            SELECT COUNT(*)
            FROM tasks t
            JOIN tasks b ON t.blocked_by = b.id
            WHERE t.status='TODO' AND t.assignee='CLAUDE'
              AND t.queue != 'INBOX'
              AND b.status NOT IN ('DONE','SKIP');
        ")
        [ "$BLOCKED_COUNT" -gt 0 ] && echo "  ($BLOCKED_COUNT blocked tasks — run 'next' without flag for details)"
        echo ""
    else
        BLOCKED_COUNT=$(sqlite3 "$DB" "
            SELECT COUNT(*)
            FROM tasks t
            JOIN tasks b ON t.blocked_by = b.id
            WHERE t.status='TODO' AND t.assignee='CLAUDE'
              AND t.queue != 'INBOX'
              AND b.status NOT IN ('DONE','SKIP');
        ")
        if [ "$BLOCKED_COUNT" -gt 0 ]; then
            echo "  ⛔ BLOCKED ($BLOCKED_COUNT):"
            sqlite3 "$DB" "
                SELECT '    ' || t.id ||
                    CASE COALESCE(t.track,'forward') WHEN 'loopback' THEN ' (LB)' ELSE '' END ||
                    '  ' || t.title ||
                    '  ← ' || b.id || ' (' || b.assignee || ', ' || b.status || ')'
                FROM tasks t
                JOIN tasks b ON t.blocked_by = b.id
                WHERE t.status='TODO' AND t.assignee='CLAUDE'
                  AND t.queue != 'INBOX'
                  AND b.status NOT IN ('DONE','SKIP')
                ORDER BY COALESCE(t.track,'forward') DESC, t.phase, t.sort_order;
            "
            echo ""
        fi

        # STALE blockers
        STALE_COUNT=$(sqlite3 "$DB" "
            SELECT COUNT(*)
            FROM tasks t
            WHERE t.status='TODO' AND t.blocked_by IS NOT NULL AND t.blocked_by != ''
              AND t.blocked_by NOT IN (SELECT id FROM tasks);
        ")
        if [ "$STALE_COUNT" -gt 0 ]; then
            echo "  ⚠️  STALE BLOCKERS ($STALE_COUNT) — reference nonexistent tasks:"
            sqlite3 "$DB" "
                SELECT '  ' || t.id || ' → ' || t.blocked_by || ' (not found)'
                FROM tasks t
                WHERE t.status='TODO' AND t.blocked_by IS NOT NULL AND t.blocked_by != ''
                  AND t.blocked_by NOT IN (SELECT id FROM tasks);
            "
            echo ""
        fi
    fi
    ;;

status)
    echo ""
    echo "── Phase status (forward track) ──────────────────────────────"
    sqlite3 -column -header "$DB" "
        SELECT phase,
               COUNT(*) AS total,
               SUM(CASE WHEN status='DONE' THEN 1 ELSE 0 END) AS done,
               SUM(CASE WHEN status='TODO' THEN 1 ELSE 0 END) AS todo,
               SUM(CASE WHEN status='BLOCKED' THEN 1 ELSE 0 END) AS blocked
        FROM tasks
        WHERE COALESCE(track,'forward')='forward'
        GROUP BY phase
        ORDER BY phase;
    "
    # Show loopback summary if any exist
    LB_TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback';" 2>/dev/null)
    if [ "$LB_TOTAL" -gt 0 ]; then
        LB_OPEN_ST=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        echo "  Loopback track: $LB_TOTAL total, $LB_OPEN_ST open — run 'loopbacks' for details"
    fi
    echo ""
    ;;

master)
    echo ""
    echo "── Master's TODO tasks ───────────────────────────────────────"
    sqlite3 -column -header "$DB" "
        SELECT id, phase, priority, title
        FROM tasks
        WHERE status='TODO' AND assignee IN ('MASTER', 'GEMINI')
        ORDER BY phase, sort_order;
    "
    echo ""
    ;;

task)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh task <id>"; exit 1; fi
    SAFE_TASK_ID=$(sanitize_id "$2") || exit 1
    echo ""
    sqlite3 "$DB" "
        SELECT '── Task: ' || id || ' ──' || char(10) ||
               'Phase:    ' || phase || char(10) ||
               'Queue:    ' || queue || ' | Assignee: ' || assignee || char(10) ||
               'Priority: ' || priority || ' | Status: ' || status || char(10) ||
               'Tier:     ' || COALESCE(tier, '⚠️  NOT ASSIGNED') || ' | Skill: ' || COALESCE(skill, 'none') || char(10) ||
               CASE WHEN blocked_by IS NOT NULL THEN 'Blocked by: ' || blocked_by || char(10) ELSE '' END ||
               CASE WHEN completed_on IS NOT NULL THEN 'Completed: ' || completed_on || char(10) ELSE '' END ||
               char(10) || 'Title: ' || title || char(10) ||
               CASE WHEN details IS NOT NULL THEN char(10) || 'Details:' || char(10) || details ELSE '' END ||
               CASE WHEN research_notes IS NOT NULL THEN char(10) || char(10) || '📖 Research:' || char(10) || research_notes ELSE '' END
        FROM tasks WHERE id='$SAFE_TASK_ID';
    "
    echo ""
    ;;

done)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh done <id>"; exit 1; fi
    SAFE_DONE_ID=$(sanitize_id "$2") || exit 1
    DONE_CHECK=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$SAFE_DONE_ID';")
    if [ -z "$DONE_CHECK" ]; then
        echo "❌ Task '$SAFE_DONE_ID' not found in database — check the ID"
        exit 1
    fi
    # Guard: don't re-process already-DONE tasks (prevents accidental commits under wrong task)
    ALREADY_DONE=$(sqlite3 "$DB" "SELECT status FROM tasks WHERE id='$SAFE_DONE_ID';")
    if [ "$ALREADY_DONE" = "DONE" ]; then
        COMPLETED_ON=$(sqlite3 "$DB" "SELECT completed_on FROM tasks WHERE id='$SAFE_DONE_ID';")
        echo "⚠️  Task '$SAFE_DONE_ID' is already DONE (completed: $COMPLETED_ON)"
        echo "   Skipping auto-commit. Use 'git commit' manually if needed."
        exit 0
    fi
    TODAY=$(date "+%b %d" | sed 's/ 0/ /')
    DONE_PHASE=$(sqlite3 "$DB" "SELECT phase FROM tasks WHERE id='$SAFE_DONE_ID';")
    sqlite3 "$DB" "UPDATE tasks SET status='DONE', completed_on='$TODAY' WHERE id='$SAFE_DONE_ID';"
    echo "✅ Marked DONE: $SAFE_DONE_ID ($TODAY)"

    # ── Loopback-specific done logic ──
    DONE_TRACK=$(sqlite3 "$DB" "SELECT COALESCE(track,'forward') FROM tasks WHERE id='$SAFE_DONE_ID';")
    if [ "$DONE_TRACK" = "loopback" ]; then
        DONE_SEV=$(sqlite3 "$DB" "SELECT severity FROM tasks WHERE id='$SAFE_DONE_ID';")
        DONE_ORIGIN=$(sqlite3 "$DB" "SELECT origin_phase FROM tasks WHERE id='$SAFE_DONE_ID';")
        DONE_DISC=$(sqlite3 "$DB" "SELECT discovered_in FROM tasks WHERE id='$SAFE_DONE_ID';")
        DONE_GC=$(sqlite3 "$DB" "SELECT gate_critical FROM tasks WHERE id='$SAFE_DONE_ID';")

        # Severity re-triage prompt (S1/S2 only — S3/S4 auto-confirm per spec ST-2)
        if [ "$DONE_SEV" -le 2 ] 2>/dev/null; then
            echo ""
            echo "  📋 Severity was S$DONE_SEV. Still accurate? Adjust via:"
            echo "     sqlite3 \"$DB\" \"UPDATE tasks SET severity=N WHERE id='$SAFE_DONE_ID';\""
        fi

        # Cluster check: other loopbacks targeting same origin
        LB_SAME_ORIGIN=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE track='loopback' AND origin_phase='$DONE_ORIGIN'
              AND status NOT IN ('DONE','SKIP') AND id != '$SAFE_DONE_ID';
        " 2>/dev/null)
        echo "  🔄 $LB_SAME_ORIGIN other loopback(s) target $DONE_ORIGIN."

        # Gate-critical resolution check
        if [ "$DONE_GC" = "1" ]; then
            GC_REMAINING=$(sqlite3 "$DB" "
                SELECT COUNT(*) FROM tasks
                WHERE track='loopback' AND discovered_in='$DONE_DISC'
                  AND gate_critical=1 AND status NOT IN ('DONE','SKIP');
            " 2>/dev/null)
            if [ "$GC_REMAINING" -eq 0 ]; then
                echo "  ✅ All gate-critical loopbacks for $DONE_DISC resolved. Gate check should pass."
            fi
        fi

        # Clean up circuit breaker ack if this was S1
        if [ "$DONE_SEV" = "1" ]; then
            sqlite3 "$DB" "DELETE FROM loopback_acks WHERE loopback_id='$SAFE_DONE_ID';"
        fi
    fi

    # ── Auto-commit on task completion ────────────────────────────────────
    PROJ_DIR="$(dirname "$0")"
    TASK_TITLE=$(sqlite3 "$DB" "SELECT title FROM tasks WHERE id='$SAFE_DONE_ID';")
    TASK_CHANGED=$(git -C "$PROJ_DIR" status --short 2>/dev/null)
    if [ -n "$TASK_CHANGED" ]; then
        TASK_FILE_COUNT=$(echo "$TASK_CHANGED" | wc -l | tr -d ' ')
        echo ""
        echo "  📦 Auto-committing $TASK_FILE_COUNT changed file(s)..."
        git -C "$PROJ_DIR" add -A 2>/dev/null
        COMMIT_MSG="[$DONE_PHASE] $SAFE_DONE_ID: $TASK_TITLE"
        git -C "$PROJ_DIR" commit -m "$COMMIT_MSG

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "  ✅ Committed: $COMMIT_MSG"
            # Auto-push
            git -C "$PROJ_DIR" push 2>/dev/null && echo "  ✅ Pushed." || echo "  ⚠️  Push failed (commit saved locally)."
        else
            echo "  ⚠️  Commit failed (pre-commit hook may have blocked it)."
            echo "  ⚠️  Reverting DB status — task '$SAFE_DONE_ID' back to TODO"
            sqlite3 "$DB" "UPDATE tasks SET status='TODO', completed_on=NULL WHERE id='$SAFE_DONE_ID';"
            echo "  Fix the issue and re-run: bash db_queries.sh done $SAFE_DONE_ID"
            exit 1
        fi
    fi

    if [ -n "$DONE_PHASE" ]; then
        REMAINING=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE phase='$DONE_PHASE' AND COALESCE(track,'forward')='forward' AND status NOT IN ('DONE','SKIP');
        " 2>/dev/null)
        # Include gate-critical loopbacks in "phase complete" check
        GC_LB_REMAINING=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE track='loopback' AND discovered_in='$DONE_PHASE'
              AND gate_critical=1 AND status NOT IN ('DONE','SKIP');
        " 2>/dev/null)
        REMAINING=$((REMAINING + GC_LB_REMAINING))
        REMAINING_CLAUDE=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE phase='$DONE_PHASE' AND assignee='CLAUDE' AND COALESCE(track,'forward')='forward' AND status NOT IN ('DONE','SKIP');
        " 2>/dev/null)

        if [ "$REMAINING" -eq 0 ]; then
            echo ""
            echo "╔═══════════════════════════════════════════════════════════╗"
            echo "║  🚧  PHASE COMPLETE: $DONE_PHASE                         "
            echo "║                                                           "
            echo "║  All tasks in $DONE_PHASE are DONE. Run the phase gate:   "
            echo "║                                                           "
            echo "║  Step 1 — Full validation:                                "
            echo "║    bash build_summarizer.sh test                          "
            echo "║                                                           "
            echo "║  Step 2 — Milestone merge check:                          "
            echo "║    bash milestone_check.sh $DONE_PHASE                    "
            echo "║                                                           "
            echo "║  Step 3 — Code review in Cowork (before merging):         "
            echo "║    Run /engineering:review with: git diff main..dev        "
            echo "║                                                           "
            echo "║  Step 4 — If all pass, record the gate:                   "
            echo "║    bash db_queries.sh gate-pass $DONE_PHASE               "
            echo "║                                                           "
            echo "║  Step 5 — Merge (only after gate-pass):                   "
            echo "║    git checkout main                                      "
            echo "║    git merge dev --no-ff -m \"Milestone: $DONE_PHASE\"      "
            echo "║    git checkout dev                                       "
            echo "╚═══════════════════════════════════════════════════════════╝"
        elif [ "$REMAINING_CLAUDE" -eq 0 ] && [ "$REMAINING" -gt 0 ]; then
            MASTER_REMAINING=$(sqlite3 "$DB" "
                SELECT GROUP_CONCAT(id || ' (' || assignee || ')', ', ')
                FROM tasks
                WHERE phase='$DONE_PHASE' AND status NOT IN ('DONE','SKIP');
            " 2>/dev/null)
            echo ""
            echo "📋 All Claude tasks in $DONE_PHASE done. Remaining: $MASTER_REMAINING"
            echo "   Phase gate cannot run until those complete."
        fi
    fi

    # Lightweight sync drift warning — runs after every done
    UNTIERED_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE tier IS NULL AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
    if [ "$UNTIERED_COUNT" -gt 0 ]; then
        echo ""
        echo "  🔄 $UNTIERED_COUNT task(s) missing tier assignment. Run: bash db_queries.sh sync-check"
    fi

    # Knowledge health nag — lightweight, runs after every done
    PROJ_DIR="$(dirname "$0")"
    KH_UNPROMOTED=0
    for f in "$PROJ_DIR"/LESSONS*.md; do
        if [ -f "$f" ]; then
            KH_COUNT=$(grep -cE "^\|[^|]+\|[^|]+\| No( —| \|)" "$f" 2>/dev/null)
            KH_COUNT="${KH_COUNT:-0}"
            if [[ "$KH_COUNT" =~ ^[0-9]+$ ]]; then
                KH_UNPROMOTED=$((KH_UNPROMOTED + KH_COUNT))
            fi
        fi
    done
    if [ "$KH_UNPROMOTED" -gt 3 ]; then
        echo ""
        echo "  📚 $KH_UNPROMOTED universal patterns awaiting promotion — run: bash ~/.claude/harvest.sh"
    fi

    # Breakage test warning (Layer 4) — for Sonnet+ tasks
    if [ "$3" != "--skip-break" ]; then
        DONE_TIER=$(sqlite3 "$DB" "SELECT COALESCE(tier,'') FROM tasks WHERE id='$SAFE_DONE_ID';" 2>/dev/null)
        DONE_BREAK=$(sqlite3 "$DB" "SELECT COALESCE(breakage_tested,0) FROM tasks WHERE id='$SAFE_DONE_ID';" 2>/dev/null)
        if [ "$DONE_BREAK" != "1" ]; then
            if [ "$DONE_TIER" = "Sonnet" ] || [ "$DONE_TIER" = "Opus" ] || [ "$DONE_TIER" = "sonnet" ] || [ "$DONE_TIER" = "opus" ]; then
                echo ""
                echo "  🔨 Breakage test not done for $SAFE_DONE_ID (tier: $DONE_TIER)"
                echo "     Pick the most critical assumption → temporarily break it → verify graceful failure"
                echo "     Mark done: bash db_queries.sh break-tested $SAFE_DONE_ID"
                echo "     Skip: bash db_queries.sh done $SAFE_DONE_ID --skip-break"
            fi
        fi
    fi
    ;;

start)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh start <id>"; exit 1; fi
    SAFE_START_ID=$(sanitize_id "$2") || exit 1
    sqlite3 "$DB" "UPDATE tasks SET status='IN_PROGRESS' WHERE id='$SAFE_START_ID';"
    echo "🔵 Marked IN_PROGRESS: $SAFE_START_ID"
    ;;

decisions)
    echo ""
    echo "── Decision log ──────────────────────────────────────────────"
    sqlite3 -column -header "$DB" "
        SELECT decision_date AS date, made_by, decision
        FROM decisions
        ORDER BY id DESC
        LIMIT 15;
    "
    echo ""
    ;;

sessions)
    echo ""
    echo "── Session log ───────────────────────────────────────────────"
    sqlite3 -column -header "$DB" "
        SELECT logged_at AS date, session_type AS type, summary
        FROM sessions
        ORDER BY id DESC;
    "
    echo ""
    ;;

log)
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: bash db_queries.sh log <type> <summary>"
        exit 1
    fi
    TODAY=$(date "+%b %d" | sed 's/ 0/ /')
    SAFE_TYPE=$(echo "$2" | sed "s/'/''/g")
    SAFE_SUMMARY=$(echo "$3" | sed "s/'/''/g")
    sqlite3 "$DB" "INSERT INTO sessions (session_type, summary) VALUES ('$SAFE_TYPE', '$SAFE_SUMMARY');"
    echo "✅ Session logged: $TODAY [$2]"
    ;;

board)
    python3 "$(dirname "$0")/generate_board.py"
    ;;

tag-browser)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh tag-browser <id> [0|1]"; exit 1; fi
    SAFE_TAG_ID=$(sanitize_id "$2") || exit 1
    VALUE="${3:-1}"
    sqlite3 "$DB" "UPDATE tasks SET needs_browser=$VALUE WHERE id='$SAFE_TAG_ID';"
    if [ "$VALUE" = "1" ]; then
        echo "🌐 Tagged $SAFE_TAG_ID as needs_browser"
    else
        echo "🌐 Untagged $SAFE_TAG_ID — no longer needs_browser"
    fi
    ;;

lessons)
    # Show all lessons with staleness info
    LESSONS_FILE="$(dirname "$0")/%%LESSONS_FILE%%"
    if [ ! -f "$LESSONS_FILE" ]; then
        echo "❌ %%LESSONS_FILE%% not found"
        exit 1
    fi
    echo ""
    echo "── Lessons & Corrections ─────────────────────────────────────"
    echo ""
    # Extract and display corrections with staleness check
    TODAY_SEC=$(date +%s)
    grep "^| 20" "$LESSONS_FILE" | awk -F'|' 'NF >= 7' | head -20 | while IFS='|' read -r _ DATE WRONG PATTERN RULE LAST_REF VIOLATIONS _; do
        DATE=$(echo "$DATE" | tr -d '[:space:]')
        PATTERN=$(echo "$PATTERN" | sed 's/^ *//;s/ *$//')
        RULE=$(echo "$RULE" | sed 's/^ *//;s/ *$//')
        LAST_REF=$(echo "$LAST_REF" | sed 's/^ *//;s/ *$//')
        VIOLATIONS=$(echo "$VIOLATIONS" | sed 's/^ *//;s/ *$//')
        # Check staleness
        STALE=""
        if [ -n "$LAST_REF" ] && [ "$LAST_REF" != "—" ]; then
            LAST_SEC=$(date -d "$LAST_REF" +%s 2>/dev/null || echo "0")
            if [ "$LAST_SEC" -gt 0 ]; then
                DAYS_AGO=$(( (TODAY_SEC - LAST_SEC) / 86400 ))
                if [ "$DAYS_AGO" -gt 30 ]; then
                    STALE=" ⚠️  STALE ($DAYS_AGO days)"
                fi
            fi
        elif [ "$LAST_REF" = "—" ]; then
            STALE=" ⚠️  NEVER REFERENCED"
        fi
        # Violation warning
        VIOL_WARN=""
        if [ -n "$VIOLATIONS" ] && [ "$VIOLATIONS" -ge 2 ] 2>/dev/null; then
            VIOL_WARN=" 🔴 VIOLATED ${VIOLATIONS}x — rewrite prevention rule!"
        fi
        echo "  [$DATE] $PATTERN"
        echo "    → $RULE"
        echo "    Last ref: $LAST_REF | Violations: $VIOLATIONS$STALE$VIOL_WARN"
        echo ""
    done
    ;;

log-lesson)
    # Atomically append a correction to %%LESSONS_FILE%%
    # Usage: bash db_queries.sh log-lesson "What went wrong" "Pattern" "Prevention rule" [--bp category affected-file]
    # Reduces friction from multi-step file edit to single command.
    # This exists because the soft "remember to log lessons" rule failed 3 times.
    # --bp flag: also escalate to bootstrap backlog (zero extra friction at the HARD GATE)
    LESSONS_FILE="$(dirname "$0")/%%LESSONS_FILE%%"
    if [ ! -f "$LESSONS_FILE" ]; then
        echo "❌ %%LESSONS_FILE%% not found"
        exit 1
    fi
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        echo "Usage: bash db_queries.sh log-lesson \"What went wrong\" \"Pattern\" \"Prevention rule\""
        echo "All 3 arguments are required."
        exit 1
    fi
    WHAT_WRONG="$2"
    PATTERN="$3"
    PREVENTION="$4"
    TODAY_LOG=$(date +%Y-%m-%d)

    # Find the corrections anchor marker (or fall back to end of Active Root Patterns section)
    ANCHOR_ROW=$(grep -n '<!-- CORRECTIONS-ANCHOR -->' "$LESSONS_FILE" | tail -1 | cut -d: -f1)
    if [ -z "$ANCHOR_ROW" ]; then
        # Fall back: insert before "## Insights" or "## Universal Patterns" section
        ANCHOR_ROW=$(grep -n "^## Insights\|^## Universal Patterns" "$LESSONS_FILE" | head -1 | cut -d: -f1)
    fi
    if [ -z "$ANCHOR_ROW" ]; then
        echo "❌ Could not find insertion point in LESSONS file"
        echo "   Add <!-- CORRECTIONS-ANCHOR --> where new corrections should appear."
        exit 1
    fi

    # Insert a markdown correction entry after the anchor line using awk
    # Uses ENVIRON instead of -v to preserve backslashes and special chars in input
    TEMP_LESSONS="/tmp/lessons_updated.md"
    export LOG_DATE="$TODAY_LOG" LOG_WHAT="$WHAT_WRONG" LOG_PATTERN="$PATTERN" LOG_PREVENTION="$PREVENTION"
    awk -v anchor="$ANCHOR_ROW" '
        NR == anchor {
            print
            print ""
            print "### " ENVIRON["LOG_DATE"] " — " ENVIRON["LOG_WHAT"]
            print "**Pattern:** " ENVIRON["LOG_PATTERN"]
            print "**Prevention:** " ENVIRON["LOG_PREVENTION"]
            next
        }
        { print }
    ' "$LESSONS_FILE" > "$TEMP_LESSONS"
    cp "$TEMP_LESSONS" "$LESSONS_FILE"
    rm -f "$TEMP_LESSONS"
    unset LOG_DATE LOG_WHAT LOG_PATTERN LOG_PREVENTION

    if grep -qF "$WHAT_WRONG" "$LESSONS_FILE"; then
        echo "✅ Lesson logged: $PATTERN"
        echo "   → $PREVENTION"
        echo ""
        echo "  💡 If this has a code-level root cause, add a test to src/__tests__/regression.test.ts"
        echo "     This turns prose lessons into automated guards."
    else
        echo "❌ Failed to write lesson to file"
        exit 1
    fi

    # --bp flag: also escalate to bootstrap backlog
    BP_FLAG=0
    BP_CAT="template"
    BP_FILE=""
    for i in $(seq 5 $#); do
        ARG="${!i}"
        if [[ "$ARG" == "--bp" ]]; then
            BP_FLAG=1
            NEXT_I=$((i + 1))
            NEXT2_I=$((i + 2))
            [ "$NEXT_I" -le "$#" ] && BP_CAT="${!NEXT_I}"
            [ "$NEXT2_I" -le "$#" ] && BP_FILE="${!NEXT2_I}"
        fi
    done
    if [ "$BP_FLAG" -eq 1 ]; then
        BACKLOG="$HOME/.claude/dev-framework/BOOTSTRAP_BACKLOG.md"
        if [ -f "$BACKLOG" ]; then
            # Reuse escalate logic inline
            BP_MAX=$(grep -oE 'BP-[0-9]+' "$BACKLOG" | sed 's/BP-//' | sort -n | tail -1)
            if [ -z "$BP_MAX" ]; then BP_ID="BP-001"; else BP_ID=$(printf "BP-%03d" $((BP_MAX + 1))); fi
            BP_TODAY=$(date "+%Y-%m-%d")
            BP_PROJECT=$(basename "$(dirname "$0")")
            BP_ANCHOR=$(grep -n '<!-- PENDING-ANCHOR' "$BACKLOG" | tail -1 | cut -d: -f1)
            if [ -z "$BP_ANCHOR" ]; then
                BP_ANCHOR=$(grep -n '^## Applied' "$BACKLOG" | head -1 | cut -d: -f1)
            fi
            if [ -n "$BP_ANCHOR" ]; then
                BP_TEMP="/tmp/backlog_bp_$$.md"
                export ESC_ID="$BP_ID" ESC_CAT="$BP_CAT" ESC_DESC="$PATTERN" ESC_TODAY="$BP_TODAY" ESC_PROJECT="$BP_PROJECT" ESC_PRIORITY="P2" ESC_FILE="${BP_FILE:-unknown (review needed)}"
                awk -v anchor="$BP_ANCHOR" '
                    NR == anchor {
                        print ""
                        print "### " ENVIRON["ESC_ID"] " [" ENVIRON["ESC_CAT"] "] " ENVIRON["ESC_DESC"]
                        print "- **Escalated:** " ENVIRON["ESC_TODAY"]
                        print "- **Source:** " ENVIRON["ESC_PROJECT"]
                        print "- **Priority:** " ENVIRON["ESC_PRIORITY"]
                        print "- **Affected:** " ENVIRON["ESC_FILE"]
                        print "- **Description:** " ENVIRON["ESC_DESC"]
                        print "- **Change:** (to be determined during review)"
                        print "- **Status:** pending"
                        print ""
                    }
                    { print }
                ' "$BACKLOG" > "$BP_TEMP"
                mv "$BP_TEMP" "$BACKLOG"
                echo "   📋 Also escalated to bootstrap backlog as $BP_ID [$BP_CAT]"
            fi
        else
            echo "   ⚠️  --bp flag used but $BACKLOG not found — skipping escalation"
        fi
    fi
    ;;

delegation)
    # Generate delegation table from DB — replaces manual AGENT_DELEGATION.md §8 maintenance
    # Usage: bash db_queries.sh delegation [PHASE]
    # If PHASE given, show only that phase. Otherwise show all incomplete phases.
    DELEG_PHASE="$2"

    if [ -n "$DELEG_PHASE" ]; then
        PHASE_FILTER="AND phase='$DELEG_PHASE'"
    else
        # Show all phases with remaining work, plus recently completed
        PHASE_FILTER=""
    fi

    echo ""
    echo "── Delegation Map (from DB) ────────────────────────────────────"
    echo ""

    # Get distinct phases to iterate
    PHASES=$(sqlite3 "$DB" "
        SELECT DISTINCT phase FROM tasks
        WHERE 1=1 $PHASE_FILTER
        ORDER BY phase;
    " 2>/dev/null)

    for PHASE in $PHASES; do
        PHASE_STATUS=$(sqlite3 "$DB" "
            SELECT CASE
                WHEN SUM(CASE WHEN status NOT IN ('DONE','SKIP') THEN 1 ELSE 0 END) = 0 THEN 'DONE'
                ELSE 'IN PROGRESS'
            END
            FROM tasks WHERE phase='$PHASE';
        " 2>/dev/null)

        echo "### $PHASE ($PHASE_STATUS)"
        echo "| Task | Tier | Skill | Status | Research Notes |"
        echo "|------|------|-------|--------|----------------|"

        sqlite3 "$DB" "
            SELECT '| ' || id || ' ' || title ||
                   ' | ' || COALESCE(UPPER(tier), '?') ||
                   ' | ' || COALESCE(skill, '—') ||
                   ' | ' || status ||
                   ' | ' || COALESCE(substr(research_notes, 1, 80), '—') ||
                   CASE WHEN length(COALESCE(research_notes,'')) > 80 THEN '...' ELSE '' END ||
                   ' |'
            FROM tasks
            WHERE phase='$PHASE'
            ORDER BY sort_order;
        " 2>/dev/null

        echo ""
    done
    ;;

sync-check)
    # Detect drift between DB task list and AGENT_DELEGATION.md §8
    # Reports: tasks in DB not in markdown, tasks in markdown not in DB,
    # tier/skill mismatches, missing research notes
    DELEG_FILE="$(dirname "$0")/AGENT_DELEGATION.md"
    DRIFT_COUNT=0

    echo ""
    echo "── Sync Check: DB ↔ AGENT_DELEGATION.md ──────────────────────"

    if [ ! -f "$DELEG_FILE" ]; then
        echo "  ❌ AGENT_DELEGATION.md not found"
        exit 1
    fi

    # Check 1: Tasks in DB but not mentioned in AGENT_DELEGATION.md
    DB_IDS=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE status != 'DONE' ORDER BY sort_order;" 2>/dev/null)
    MISSING_FROM_MD=""
    for ID in $DB_IDS; do
        if ! grep -q "$ID" "$DELEG_FILE" 2>/dev/null; then
            TITLE=$(sqlite3 "$DB" "SELECT title FROM tasks WHERE id='$ID';" 2>/dev/null)
            TIER=$(sqlite3 "$DB" "SELECT COALESCE(tier,'?') FROM tasks WHERE id='$ID';" 2>/dev/null)
            MISSING_FROM_MD="${MISSING_FROM_MD}    $ID ($TIER): $TITLE\n"
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
        fi
    done

    if [ -n "$MISSING_FROM_MD" ]; then
        echo ""
        echo "  ⚠️  Tasks in DB but NOT in AGENT_DELEGATION.md:"
        echo -e "$MISSING_FROM_MD"
    fi

    # Check 2: Tasks without tier assignment in DB
    UNTIERED=$(sqlite3 "$DB" "
        SELECT id || ': ' || title
        FROM tasks
        WHERE tier IS NULL AND status NOT IN ('DONE', 'SKIP')
        ORDER BY sort_order;
    " 2>/dev/null)

    if [ -n "$UNTIERED" ]; then
        echo "  ⚠️  Tasks without tier assignment:"
        echo "$UNTIERED" | while IFS= read -r line; do
            echo "    $line"
        done
        echo ""
        DRIFT_COUNT=$((DRIFT_COUNT + $(echo "$UNTIERED" | wc -l)))
    fi

    # Check 3: Tasks with research_notes in DB but "RESEARCH" not in their AGENT_DELEGATION.md entry
    RESEARCH_IDS=$(sqlite3 "$DB" "
        SELECT id FROM tasks
        WHERE research_notes IS NOT NULL
          AND research_notes != ''
          AND status NOT IN ('DONE', 'SKIP')
        ORDER BY sort_order;
    " 2>/dev/null)

    MISSING_RESEARCH=""
    for ID in $RESEARCH_IDS; do
        # Check if the line containing this task ID also contains "RESEARCH"
        TASK_LINE=$(grep "$ID" "$DELEG_FILE" 2>/dev/null | head -1)
        if [ -n "$TASK_LINE" ] && ! echo "$TASK_LINE" | grep -qi "RESEARCH" 2>/dev/null; then
            MISSING_RESEARCH="${MISSING_RESEARCH}    $ID — has research_notes in DB but no RESEARCH tag in markdown\n"
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
        fi
    done

    if [ -n "$MISSING_RESEARCH" ]; then
        echo "  ⚠️  Research notes not reflected in AGENT_DELEGATION.md:"
        echo -e "$MISSING_RESEARCH"
    fi

    # Check 4: PROJECT_MEMORY component count drift
    PM_FILE="$(dirname "$0")/%%PROJECT_NAME%%_PROJECT_MEMORY.md"
    if [ -f "$PM_FILE" ]; then
        DB_TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null)
        DB_PHASES=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT phase) FROM tasks;" 2>/dev/null)
        # Just report the counts so Claude can compare
        echo "  📊 DB totals: $DB_TOTAL tasks across $DB_PHASES phases"
    fi

    # Check 5: INBOX items pending triage
    INBOX_COUNT_SC=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE queue='INBOX';" 2>/dev/null)
    if [ "$INBOX_COUNT_SC" -gt 0 ]; then
        echo "  📥 $INBOX_COUNT_SC task(s) in INBOX awaiting triage"
        echo "     Run: bash db_queries.sh inbox"
        echo ""
    fi

    # Verdict
    if [ "$DRIFT_COUNT" -eq 0 ]; then
        echo ""
        echo "  ✅ Sync check passed — DB and markdown are consistent"
    else
        echo ""
        echo "  ⚠️  $DRIFT_COUNT drift(s) detected"
        echo "  Fix: run 'bash db_queries.sh delegation-md' to regenerate §8 from DB."
    fi
    echo ""
    ;;

add-task)
    # Add a new task with full delegation metadata
    # Usage: bash db_queries.sh add-task <id> <phase> <title> <tier> [skill] [blocked_by] [sort_order]
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
        echo "Usage: bash db_queries.sh add-task <id> <phase> <title> <tier> [skill] [blocked_by] [sort_order]"
        echo ""
        echo "  id:         Task ID (e.g., D-11, PL-08b)"
        echo "  phase:      Phase name (e.g., P3-DETAIL)"
        echo "  title:      Task title in quotes"
        echo "  tier:       haiku / sonnet / opus / gemini / skip"
        echo "  skill:      Optional skill routing (e.g., /frontend-design)"
        echo "  blocked_by: Optional blocker task ID"
        echo "  sort_order: Optional numeric sort order"
        exit 1
    fi

    NEW_ID=$(sanitize_id "$2") || exit 1
    NEW_PHASE="$3"
    NEW_TITLE=$(echo "$4" | sed "s/'/''/g")
    NEW_TIER="$5"
    NEW_SKILL="${6:-}"
    NEW_BLOCKED="${7:-}"
    NEW_SORT="${8:-999}"

    # Derive priority from phase
    NEW_PRIORITY=$(echo "$NEW_PHASE" | sed 's/-.*//' | sed 's/P/P/')

    SAFE_SKILL="NULL"
    [ -n "$NEW_SKILL" ] && SAFE_SKILL="'$(echo "$NEW_SKILL" | sed "s/'/''/g")'"

    SAFE_BLOCKED="NULL"
    [ -n "$NEW_BLOCKED" ] && SAFE_BLOCKED="'$NEW_BLOCKED'"

    sqlite3 "$DB" "
        INSERT OR REPLACE INTO tasks (id, phase, assignee, title, priority, status, blocked_by, sort_order, tier, skill)
        VALUES ('$NEW_ID', '$NEW_PHASE', 'CLAUDE', '$NEW_TITLE', '$NEW_PRIORITY', 'TODO', $SAFE_BLOCKED, $NEW_SORT, '$NEW_TIER', $SAFE_SKILL);
    "
    echo "✅ Added task: $NEW_ID ($NEW_TIER) — $4"
    echo "   Phase: $NEW_PHASE | Skill: ${NEW_SKILL:-none} | Blocked by: ${NEW_BLOCKED:-none}"
    echo ""
    echo "   ⚠️  Remember to update AGENT_DELEGATION.md §8 — run: bash db_queries.sh delegation $NEW_PHASE"
    ;;

verify)
    # Verify DB is populated — machine-readable check for handoff documents
    # HARDENED: checks that queries actually ran and returned numeric results.
    # Previous version had false-positive bug: empty string from failed query
    # caused [ "" -eq 0 ] to error silently, falling through to "✅ DB populated".
    TASK_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;" 2>&1) || {
        echo "  ❌ DB query failed: $TASK_COUNT"
        exit 1
    }
    # Validate we got an actual number, not an error message or empty string
    if ! [[ "$TASK_COUNT" =~ ^[0-9]+$ ]]; then
        echo "  ❌ DB query returned non-numeric result: '$TASK_COUNT'"
        echo "  The database may be corrupted or the 'tasks' table may not exist."
        exit 1
    fi
    CLAUDE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE assignee='CLAUDE';" 2>/dev/null || echo "?")
    MASTER_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE assignee='MASTER';" 2>/dev/null || echo "?")
    PHASE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT phase) FROM tasks;" 2>/dev/null || echo "?")

    # Check schema completeness (delegation columns from migration 001)
    TIER_COL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='tier';" 2>/dev/null || echo "0")
    SKILL_COL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='skill';" 2>/dev/null || echo "0")
    RNOTES_COL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='research_notes';" 2>/dev/null || echo "0")

    echo ""
    echo "── DB Verification ────────────────────────────────────────────"
    echo "  Tasks total:  $TASK_COUNT"
    echo "  Claude tasks: $CLAUDE_COUNT"
    echo "  Master tasks: $MASTER_COUNT"
    echo "  Phases:       $PHASE_COUNT"
    echo ""
    echo "  Schema:"
    [ "$TIER_COL" -eq 1 ] && echo "    ✅ tier column" || echo "    ❌ tier column MISSING — run: sqlite3 $DB < migrations/001_add_delegation_columns.sql"
    [ "$SKILL_COL" -eq 1 ] && echo "    ✅ skill column" || echo "    ❌ skill column MISSING"
    [ "$RNOTES_COL" -eq 1 ] && echo "    ✅ research_notes column" || echo "    ❌ research_notes column MISSING"
    echo ""
    if [ "$TASK_COUNT" -eq 0 ]; then
        echo "  ❌ DB IS EMPTY — run: sqlite3 %%PROJECT_DB%% < seed_tasks.sql"
    elif [ "$TIER_COL" -eq 0 ] || [ "$SKILL_COL" -eq 0 ] || [ "$RNOTES_COL" -eq 0 ]; then
        echo "  ⚠️  DB populated but schema incomplete — run migration 001"
    else
        echo "  ✅ DB populated and schema complete"
    fi
    echo ""
    ;;

init-db)
    # Initialize the database schema — creates all tables if they don't exist
    # Usage: bash db_queries.sh init-db
    # Safe to run multiple times (idempotent — CREATE TABLE IF NOT EXISTS)
    # Creates the DB file if it doesn't exist
    [ ! -f "$DB" ] && touch "$DB" && echo "  Created %%PROJECT_DB%%"
    echo "── Initializing %%PROJECT_DB%% schema ──────────────────────────────────"
    sqlite3 "$DB" "
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'TODO',
    priority TEXT DEFAULT 'P2',
    assignee TEXT NOT NULL DEFAULT 'CLAUDE',
    blocked_by TEXT,
    sort_order INTEGER DEFAULT 999,
    queue TEXT NOT NULL DEFAULT 'BACKLOG',
    tier TEXT,
    skill TEXT,
    needs_browser INTEGER DEFAULT 0,
    track TEXT DEFAULT 'forward',
    origin_phase TEXT,
    discovered_in TEXT,
    severity INTEGER DEFAULT 3,
    gate_critical INTEGER DEFAULT 0,
    loopback_reason TEXT,
    details TEXT,
    completed_on TEXT,
    researched INTEGER DEFAULT 0,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS phase_gates (
    phase TEXT PRIMARY KEY,
    gated_on TEXT,
    gated_by TEXT DEFAULT 'MASTER',
    notes TEXT
);
CREATE TABLE IF NOT EXISTS milestone_confirmations (
    task_id TEXT PRIMARY KEY,
    confirmed_on TEXT NOT NULL,
    confirmed_by TEXT DEFAULT 'MASTER',
    reasons TEXT
);
CREATE TABLE IF NOT EXISTS loopback_acks (
    loopback_id TEXT NOT NULL,
    acked_on TEXT NOT NULL,
    acked_by TEXT NOT NULL,
    reason TEXT NOT NULL,
    UNIQUE(loopback_id)
);
CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    options TEXT,
    choice TEXT,
    rationale TEXT,
    decided_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_type TEXT DEFAULT 'Claude Code',
    summary TEXT,
    logged_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS db_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phase TEXT,
    snapshot_at TEXT DEFAULT (datetime('now')),
    task_count INTEGER,
    file_paths TEXT
);
CREATE TABLE IF NOT EXISTS assumptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    assumption TEXT NOT NULL,
    verified INTEGER DEFAULT 0,
    verification_cmd TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
" 2>&1
    echo "  ✅ Schema ready. Tables: tasks, phase_gates, milestone_confirmations, loopback_acks,"
    echo "     decisions, sessions, db_snapshots, assumptions"
    echo ""
    ;;

health)
    # Pipeline health diagnostic — comprehensive integrity check
    # Usage: bash db_queries.sh health
    # Returns: HEALTHY (exit 0), DEGRADED (exit 0), or CRITICAL (exit 1)

    WARNINGS=0
    CRITICALS=0

    echo ""
    echo "── Pipeline Health Check ────────────────────────────────────"

    # 1. SQLite integrity check
    INTEGRITY=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1)
    if [ "$INTEGRITY" = "ok" ]; then
        echo "  ✅ SQLite integrity: ok"
    else
        echo "  ❌ SQLite integrity: FAILED"
        echo "     $INTEGRITY"
        CRITICALS=$((CRITICALS + 1))
        # Early exit — all other checks are unreliable on corrupt DB
        echo ""
        echo "  🔴 CRITICAL — $CRITICALS critical issue(s). Pipeline cannot proceed."
        echo "  Recovery: bash db_queries.sh restore (or: git checkout -- %%PROJECT_DB%%)"
        exit 1
    fi

    # 2. Table existence
    EXPECTED_TABLES="tasks phase_gates decisions sessions milestone_confirmations db_snapshots assumptions loopback_acks"
    for TBL in $EXPECTED_TABLES; do
        EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$TBL';" 2>/dev/null)
        if [ "$EXISTS" != "1" ]; then
            echo "  ❌ Missing table: $TBL"
            CRITICALS=$((CRITICALS + 1))
        fi
    done
    [ "$CRITICALS" -eq 0 ] && echo "  ✅ Required tables: all present"

    # 3. Schema columns on tasks table
    EXPECTED_COLS="id phase queue assignee title priority status blocked_by sort_order tier skill track origin_phase severity gate_critical"
    MISSING_COLS=""
    for COL in $EXPECTED_COLS; do
        HAS_COL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='$COL';" 2>/dev/null)
        if [ "$HAS_COL" != "1" ]; then
            MISSING_COLS="$MISSING_COLS $COL"
        fi
    done
    if [ -z "$MISSING_COLS" ]; then
        echo "  ✅ Schema columns: all 15 present"
    else
        echo "  ⚠️  Missing columns:$MISSING_COLS"
        WARNINGS=$((WARNINGS + 1))
    fi

    # 4. Data integrity checks
    # 4a. Duplicate task IDs
    DUPES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM (SELECT id FROM tasks GROUP BY id HAVING COUNT(*) > 1);" 2>/dev/null || echo "0")
    if [ "$DUPES" -gt 0 ]; then
        echo "  ❌ Duplicate task IDs: $DUPES"
        CRITICALS=$((CRITICALS + 1))
    fi

    # 4b. Circular dependencies
    CIRCULAR=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks a JOIN tasks b ON a.blocked_by = b.id AND b.blocked_by = a.id;" 2>/dev/null || echo "0")
    if [ "$CIRCULAR" -gt 0 ]; then
        echo "  ❌ Circular dependencies: $CIRCULAR"
        CRITICALS=$((CRITICALS + 1))
    fi

    # 4c. Broken blocked_by references
    BROKEN_REFS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks t1
        WHERE t1.blocked_by IS NOT NULL AND t1.blocked_by != '' AND t1.blocked_by != '—'
        AND NOT EXISTS (SELECT 1 FROM tasks t2 WHERE t2.id = t1.blocked_by);" 2>/dev/null || echo "0")
    if [ "$BROKEN_REFS" -gt 0 ]; then
        echo "  ⚠️  Broken blocked_by refs: $BROKEN_REFS"
        WARNINGS=$((WARNINGS + 1))
    fi

    # 4d. Unknown phases
    UNKNOWN_PH=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks
        WHERE phase NOT IN (
            %%PHASE_IN_SQL%%
        );" 2>/dev/null || echo "0")
    if [ "$UNKNOWN_PH" -gt 0 ]; then
        echo "  ⚠️  Unknown phases: $UNKNOWN_PH"
        WARNINGS=$((WARNINGS + 1))
    fi

    # 4e. Invalid statuses
    INVALID_ST=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks
        WHERE status NOT IN ('TODO','DONE','SKIP','MASTER','WONTFIX','IN_PROGRESS');" 2>/dev/null || echo "0")
    if [ "$INVALID_ST" -gt 0 ]; then
        echo "  ⚠️  Invalid statuses: $INVALID_ST"
        WARNINGS=$((WARNINGS + 1))
    fi

    # 4f. Loopbacks missing origin_phase
    LB_NO_ORIG=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks
        WHERE track='loopback' AND (origin_phase IS NULL OR origin_phase = '');" 2>/dev/null || echo "0")
    if [ "$LB_NO_ORIG" -gt 0 ]; then
        echo "  ⚠️  Loopbacks missing origin_phase: $LB_NO_ORIG"
        WARNINGS=$((WARNINGS + 1))
    fi

    # 4g. Orphaned phase gates
    ORPHAN_GATES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM phase_gates pg
        WHERE NOT EXISTS (SELECT 1 FROM tasks t WHERE t.phase = pg.phase);" 2>/dev/null || echo "0")
    if [ "$ORPHAN_GATES" -gt 0 ]; then
        echo "  ⚠️  Orphaned phase gates: $ORPHAN_GATES"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Verdict
    echo ""
    if [ "$CRITICALS" -gt 0 ]; then
        echo "  🔴 CRITICAL — $CRITICALS critical, $WARNINGS warning(s). Pipeline cannot proceed."
        echo "  Recovery: bash db_queries.sh restore (or: git checkout -- %%PROJECT_DB%%)"
        exit 1
    elif [ "$WARNINGS" -gt 0 ]; then
        echo "  🟡 DEGRADED — 0 critical, $WARNINGS warning(s). Non-blocking, should address."
    else
        echo "  🟢 HEALTHY — 0 critical, 0 warnings."
    fi
    echo ""
    ;;

backup)
    # Backup DB to backups/ directory with rotation
    # Usage: bash db_queries.sh backup
    SCRIPT_DIR="$(dirname "$0")"
    BACKUP_DIR="$SCRIPT_DIR/backups"
    mkdir -p "$BACKUP_DIR"

    # Check integrity before backup — don't backup corrupt data
    INTEGRITY=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1)
    if [ "$INTEGRITY" != "ok" ]; then
        echo "❌ DB integrity check failed — refusing to backup corrupt data"
        echo "   Run: bash db_queries.sh health"
        exit 1
    fi

    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/%%PROJECT_DB_NAME%%-${TIMESTAMP}.db"

    # Use SQLite's native backup (handles WAL mode safely)
    sqlite3 "$DB" ".backup '$BACKUP_FILE'"
    if [ $? -ne 0 ]; then
        echo "❌ Backup failed"
        exit 1
    fi

    # Verify backup
    BACKUP_INTEGRITY=$(sqlite3 "$BACKUP_FILE" "PRAGMA integrity_check;" 2>&1)
    if [ "$BACKUP_INTEGRITY" != "ok" ]; then
        echo "❌ Backup file failed integrity check — removing"
        rm -f "$BACKUP_FILE"
        exit 1
    fi

    BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    BACKUP_TASKS=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "?")

    # Rotation: keep last 10
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/%%PROJECT_DB_NAME%%-*.db 2>/dev/null | wc -l | tr -d ' ')
    if [ "$BACKUP_COUNT" -gt 10 ]; then
        EXCESS=$((BACKUP_COUNT - 10))
        ls -1t "$BACKUP_DIR"/%%PROJECT_DB_NAME%%-*.db | tail -n "$EXCESS" | while read -r old; do
            rm -f "$old"
        done
        BACKUP_COUNT=10
    fi

    echo "✅ Backup created: $(basename "$BACKUP_FILE")"
    echo "   Size: $BACKUP_SIZE | Tasks: $BACKUP_TASKS | Backups: $BACKUP_COUNT/10"
    ;;

restore)
    # Restore DB from backup
    # Usage: bash db_queries.sh restore [filename]
    # No args: list available backups
    SCRIPT_DIR="$(dirname "$0")"
    BACKUP_DIR="$SCRIPT_DIR/backups"

    if [ -z "${2:-}" ]; then
        # List available backups
        echo ""
        echo "── Available Backups ────────────────────────────────────────"
        if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/%%PROJECT_DB_NAME%%-*.db 2>/dev/null)" ]; then
            echo "  No backups found in $BACKUP_DIR/"
            echo "  Recovery option: git checkout -- %%PROJECT_DB%%"
            exit 0
        fi
        echo ""
        ls -1t "$BACKUP_DIR"/%%PROJECT_DB_NAME%%-*.db 2>/dev/null | while read -r bf; do
            BF_SIZE=$(ls -lh "$bf" | awk '{print $5}')
            BF_TASKS=$(sqlite3 "$bf" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "?")
            echo "  $(basename "$bf")  ($BF_SIZE, $BF_TASKS tasks)"
        done
        echo ""
        echo "Usage: bash db_queries.sh restore <filename>"
        echo "  (filename only — resolved relative to backups/)"
        exit 0
    fi

    # Resolve backup file path
    RESTORE_FILE="$2"
    if [ ! -f "$RESTORE_FILE" ]; then
        RESTORE_FILE="$BACKUP_DIR/$2"
    fi
    if [ ! -f "$RESTORE_FILE" ]; then
        echo "❌ Backup file not found: $2"
        echo "   Tried: $2 and $BACKUP_DIR/$2"
        echo "   Run: bash db_queries.sh restore  (to list available backups)"
        exit 1
    fi

    # Validate backup integrity
    RESTORE_INTEGRITY=$(sqlite3 "$RESTORE_FILE" "PRAGMA integrity_check;" 2>&1)
    if [ "$RESTORE_INTEGRITY" != "ok" ]; then
        echo "❌ Backup file failed integrity check — refusing to restore corrupt data"
        exit 1
    fi

    RESTORE_TASKS=$(sqlite3 "$RESTORE_FILE" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "?")

    # Safety backup of current DB before overwriting
    mkdir -p "$BACKUP_DIR"
    SAFETY_TS=$(date +%Y%m%d-%H%M%S)
    SAFETY_FILE="$BACKUP_DIR/pre-restore-${SAFETY_TS}.db"
    cp "$DB" "$SAFETY_FILE"
    echo "  Safety backup: $(basename "$SAFETY_FILE")"

    # Restore
    cp "$RESTORE_FILE" "$DB"

    # Verify post-restore
    POST_TASKS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
    if [ "$POST_TASKS" = "$RESTORE_TASKS" ]; then
        echo "✅ Restored from: $(basename "$RESTORE_FILE")"
        echo "   Tasks: $POST_TASKS (matches backup)"
    else
        echo "⚠️  Restored but task count mismatch: expected $RESTORE_TASKS, got $POST_TASKS"
    fi
    ;;

snapshot)
    LABEL="${2:-$(date +%Y-%m-%d-%H%M)}"
    # Sanitize label: escape single quotes for SQLite
    LABEL_SAFE=$(printf '%s' "$LABEL" | sed "s/'/''/g")
    GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

    TASK_JSON=$(sqlite3 "$DB" "SELECT json_group_array(json_object(
        'id', id, 'phase', phase, 'title', title, 'status', status, 'assignee', assignee
    )) FROM tasks;")

    GATES_JSON=$(sqlite3 "$DB" "SELECT json_group_array(json_object(
        'phase', phase, 'gated_on', gated_on
    )) FROM phase_gates;")

    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;")
    DONE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='DONE';")
    TODO=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='TODO';")
    BLOCKED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE blocked_by IS NOT NULL AND blocked_by != '' AND status != 'DONE';")
    BY_PHASE=$(sqlite3 "$DB" "SELECT json_group_array(json_object(
        'phase', phase,
        'total', total,
        'done', done
    )) FROM (SELECT phase, COUNT(*) as total, SUM(CASE WHEN status='DONE' THEN 1 ELSE 0 END) as done FROM tasks GROUP BY phase);")

    STATS_JSON=$(printf '{"total":%d,"done":%d,"todo":%d,"blocked":%d,"by_phase":%s}' "$TOTAL" "$DONE_COUNT" "$TODO" "$BLOCKED" "$BY_PHASE")

    # Use parameterized insert via heredoc to prevent SQL injection
    if ! sqlite3 "$DB" <<EOSQL
INSERT INTO db_snapshots (label, git_sha, task_summary, phase_gates, stats)
VALUES ('${LABEL_SAFE}', '${GIT_SHA}', '${TASK_JSON}', '${GATES_JSON}', '${STATS_JSON}');
EOSQL
    then
        echo "❌ Failed to save snapshot"
        exit 1
    fi

    SNAP_ID=$(sqlite3 "$DB" "SELECT id FROM db_snapshots ORDER BY id DESC LIMIT 1;")
    echo "✅ Snapshot #$SNAP_ID saved: \"$LABEL\" ($GIT_SHA)"
    ;;

snapshot-list)
    echo ""
    echo "── DB Snapshots ─────────────────────────────────────────────"
    sqlite3 -header -column "$DB" "SELECT id, created_at, label, git_sha,
        json_extract(stats, '$.done') || '/' || json_extract(stats, '$.total') as progress
        FROM db_snapshots ORDER BY id DESC;"
    echo ""
    ;;

snapshot-show)
    SNAP_ID="${2:?Usage: bash db_queries.sh snapshot-show <id>}"
    LABEL=$(sqlite3 "$DB" "SELECT label FROM db_snapshots WHERE id=$SNAP_ID;")
    if [ -z "$LABEL" ]; then
        echo "❌ Snapshot #$SNAP_ID not found"
        exit 1
    fi
    CREATED=$(sqlite3 "$DB" "SELECT created_at FROM db_snapshots WHERE id=$SNAP_ID;")
    GIT_SHA=$(sqlite3 "$DB" "SELECT git_sha FROM db_snapshots WHERE id=$SNAP_ID;")
    echo ""
    echo "── Snapshot #$SNAP_ID: $LABEL ($CREATED, $GIT_SHA) ──"
    echo ""
    echo "Stats:"
    sqlite3 "$DB" "SELECT
        json_extract(stats, '$.total') as total,
        json_extract(stats, '$.done') as done,
        json_extract(stats, '$.todo') as todo,
        json_extract(stats, '$.blocked') as blocked
        FROM db_snapshots WHERE id=$SNAP_ID;" -header -column
    echo ""
    echo "By phase:"
    sqlite3 "$DB" "SELECT
        json_extract(value, '$.phase') as phase,
        json_extract(value, '$.done') || '/' || json_extract(value, '$.total') as progress
        FROM db_snapshots, json_each(json_extract(stats, '$.by_phase'))
        WHERE db_snapshots.id=$SNAP_ID;" -header -column
    echo ""
    echo "Tasks:"
    sqlite3 "$DB" "SELECT
        json_extract(value, '$.id') as id,
        json_extract(value, '$.status') as status,
        json_extract(value, '$.phase') as phase,
        substr(json_extract(value, '$.title'), 1, 50) as title
        FROM db_snapshots, json_each(task_summary)
        WHERE db_snapshots.id=$SNAP_ID
        ORDER BY json_extract(value, '$.phase'), json_extract(value, '$.id');" -header -column
    echo ""
    ;;

snapshot-diff)
    ID1="${2:?Usage: bash db_queries.sh snapshot-diff <id1> <id2>}"
    ID2="${3:?Usage: bash db_queries.sh snapshot-diff <id1> <id2>}"

    CHECK1=$(sqlite3 "$DB" "SELECT COUNT(*) FROM db_snapshots WHERE id=$ID1;")
    CHECK2=$(sqlite3 "$DB" "SELECT COUNT(*) FROM db_snapshots WHERE id=$ID2;")
    if [ "$CHECK1" -eq 0 ] || [ "$CHECK2" -eq 0 ]; then
        echo "❌ One or both snapshot IDs not found"
        exit 1
    fi

    LABEL1=$(sqlite3 "$DB" "SELECT label FROM db_snapshots WHERE id=$ID1;")
    LABEL2=$(sqlite3 "$DB" "SELECT label FROM db_snapshots WHERE id=$ID2;")
    echo ""
    echo "── Snapshot Diff: #$ID1 ($LABEL1) → #$ID2 ($LABEL2) ──"
    echo ""

    # Extract task status from both snapshots using pure sqlite3
    TMP1=$(mktemp)
    TMP2=$(mktemp)
    sqlite3 "$DB" "SELECT printf('%-12s %-15s %s',
        json_extract(value, '$.id'),
        json_extract(value, '$.status'),
        json_extract(value, '$.title'))
        FROM db_snapshots, json_each(task_summary)
        WHERE db_snapshots.id=$ID1
        ORDER BY json_extract(value, '$.id');" > "$TMP1"

    sqlite3 "$DB" "SELECT printf('%-12s %-15s %s',
        json_extract(value, '$.id'),
        json_extract(value, '$.status'),
        json_extract(value, '$.title'))
        FROM db_snapshots, json_each(task_summary)
        WHERE db_snapshots.id=$ID2
        ORDER BY json_extract(value, '$.id');" > "$TMP2"

    CHANGES=$(diff "$TMP1" "$TMP2" || true)
    if [ -z "$CHANGES" ]; then
        echo "No task status changes between snapshots."
    else
        echo "$CHANGES"
    fi

    # Stats comparison
    echo ""
    STATS1=$(sqlite3 "$DB" "SELECT json_extract(stats, '$.done') || '/' || json_extract(stats, '$.total') FROM db_snapshots WHERE id=$ID1;")
    STATS2=$(sqlite3 "$DB" "SELECT json_extract(stats, '$.done') || '/' || json_extract(stats, '$.total') FROM db_snapshots WHERE id=$ID2;")
    echo "Progress: #$ID1=$STATS1 → #$ID2=$STATS2"

    rm -f "$TMP1" "$TMP2"
    ;;

tag-session)
    SESSION_NUM=$(( $(git -C "$(dirname "$0")" tag -l 'session/*' 2>/dev/null | wc -l) + 1 ))
    TAG_NAME="session/$(date +%Y-%m-%d)/$SESSION_NUM"
    git -C "$(dirname "$0")" tag "$TAG_NAME" HEAD
    echo "✅ Tagged: $TAG_NAME"
    ;;

session-tags)
    echo ""
    echo "── Session Tags ─────────────────────────────────────────────"
    TAGS=$(git -C "$(dirname "$0")" tag -l 'session/*' --sort=-creatordate 2>/dev/null)
    if [ -z "$TAGS" ]; then
        echo "  No session tags yet."
    else
        echo "$TAGS" | while read -r tag; do
            DATE=$(git -C "$(dirname "$0")" log -1 --format="%ai" "$tag" 2>/dev/null | cut -d' ' -f1-2)
            SHA=$(git -C "$(dirname "$0")" rev-parse --short "$tag" 2>/dev/null)
            echo "  $tag  ($SHA, $DATE)"
        done
    fi
    echo ""
    ;;

session-file)
    SESSION_NUM="${2:?Usage: bash db_queries.sh session-file <session-N> <file>}"
    FILE="${3:?Usage: bash db_queries.sh session-file <session-N> <file>}"

    # Find tag matching session number
    TAG=$(git -C "$(dirname "$0")" tag -l "session/*/$SESSION_NUM" 2>/dev/null | head -1)
    if [ -z "$TAG" ]; then
        echo "❌ No tag found for session $SESSION_NUM"
        echo "Available tags:"
        git -C "$(dirname "$0")" tag -l 'session/*' 2>/dev/null
        exit 1
    fi

    echo "── $FILE at $TAG ──"
    git -C "$(dirname "$0")" show "$TAG:$FILE" 2>/dev/null || echo "❌ $FILE not found at $TAG"
    ;;

# ══════════════════════════════════════════════════════════════════
# Falsification Protocol commands (Layer 1-4)
# ══════════════════════════════════════════════════════════════════

assume)
    # Register an assumption for a task
    # Usage: bash db_queries.sh assume <task-id> "assumption text" ["verify command"]
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: bash db_queries.sh assume <task-id> \"assumption text\" [\"verify command\"]"
        exit 1
    fi
    TASK_EXISTS=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$2';")
    if [ -z "$TASK_EXISTS" ]; then
        echo "❌ Task '$2' not found in database"
        exit 1
    fi
    ASSUME_TASK="$2"
    ASSUME_TEXT="$3"
    VERIFY_CMD="${4:-}"
    # Use parameterized-style insertion to avoid SQL injection from quotes in values
    ESCAPED_TEXT=$(echo "$ASSUME_TEXT" | sed "s/'/''/g")
    ESCAPED_CMD=$(echo "$VERIFY_CMD" | sed "s/'/''/g")
    if [ -n "$VERIFY_CMD" ]; then
        sqlite3 "$DB" "INSERT INTO assumptions (task_id, assumption, verify_cmd) VALUES ('$ASSUME_TASK', '$ESCAPED_TEXT', '$ESCAPED_CMD');"
    else
        sqlite3 "$DB" "INSERT INTO assumptions (task_id, assumption) VALUES ('$ASSUME_TASK', '$ESCAPED_TEXT');"
    fi
    NEW_ID=$(sqlite3 "$DB" "SELECT MAX(id) FROM assumptions WHERE task_id='$ASSUME_TASK';" 2>/dev/null)
    echo "✅ Assumption #$NEW_ID registered for $2: $3"
    if [ -n "$VERIFY_CMD" ]; then
        echo "   Verify: $VERIFY_CMD"
    else
        echo "   Verify: manual"
    fi
    ;;

verify-assumption)
    # Run verification for a specific assumption
    # Usage: bash db_queries.sh verify-assumption <task-id> <assumption-#>
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: bash db_queries.sh verify-assumption <task-id> <assumption-#>"
        exit 1
    fi
    ASSUME_INFO=$(sqlite3 "$DB" "SELECT assumption || '|' || COALESCE(verify_cmd,'') FROM assumptions WHERE task_id='$2' AND id=$3;" 2>/dev/null)
    if [ -z "$ASSUME_INFO" ]; then
        echo "❌ Assumption #$3 not found for task $2"
        exit 1
    fi
    ASSUME_TEXT=$(echo "$ASSUME_INFO" | cut -d'|' -f1)
    ASSUME_CMD=$(echo "$ASSUME_INFO" | cut -d'|' -f2-)
    echo "🔬 Verifying: $ASSUME_TEXT"
    if [ -z "$ASSUME_CMD" ]; then
        echo "   Manual verification required. Mark result:"
        echo "   Pass: sqlite3 $DB \"UPDATE assumptions SET verified=1, verified_on='$(date +%Y-%m-%d)' WHERE id=$3;\""
        echo "   Fail: sqlite3 $DB \"UPDATE assumptions SET verified=-1, verified_on='$(date +%Y-%m-%d)' WHERE id=$3;\""
    else
        echo "   Running: $ASSUME_CMD"
        RESULT=$(eval "$ASSUME_CMD" 2>&1)
        EXIT_CODE=$?
        echo "   Output: $RESULT"
        TODAY_V=$(date +%Y-%m-%d)
        if [ $EXIT_CODE -eq 0 ]; then
            sqlite3 "$DB" "UPDATE assumptions SET verified=1, verified_on='$TODAY_V' WHERE id=$3;"
            echo "   ✅ PASSED"
        else
            sqlite3 "$DB" "UPDATE assumptions SET verified=-1, verified_on='$TODAY_V' WHERE id=$3;"
            echo "   ❌ FAILED (exit code $EXIT_CODE)"
        fi
    fi
    ;;

verify-all)
    # Batch verify all assumptions for a task
    # Usage: bash db_queries.sh verify-all <task-id>
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh verify-all <task-id>"
        exit 1
    fi
    ASSUME_IDS=$(sqlite3 "$DB" "SELECT id FROM assumptions WHERE task_id='$2' AND verified=0 ORDER BY id;" 2>/dev/null)
    if [ -z "$ASSUME_IDS" ]; then
        echo "✅ No unverified assumptions for $2"
        exit 0
    fi
    echo ""
    echo "── Verifying assumptions for $2 ─────"
    PASS_COUNT=0
    FAIL_COUNT=0
    MANUAL_COUNT=0
    for AID in $ASSUME_IDS; do
        AINFO=$(sqlite3 "$DB" "SELECT assumption || '|' || COALESCE(verify_cmd,'') FROM assumptions WHERE id=$AID;" 2>/dev/null)
        ATEXT=$(echo "$AINFO" | cut -d'|' -f1)
        ACMD=$(echo "$AINFO" | cut -d'|' -f2-)
        if [ -z "$ACMD" ]; then
            echo "  #$AID: $ATEXT → [manual]"
            MANUAL_COUNT=$((MANUAL_COUNT + 1))
        else
            ARESULT=$(eval "$ACMD" 2>&1)
            AEXIT=$?
            TODAY_VA=$(date +%Y-%m-%d)
            if [ $AEXIT -eq 0 ]; then
                sqlite3 "$DB" "UPDATE assumptions SET verified=1, verified_on='$TODAY_VA' WHERE id=$AID;"
                echo "  #$AID: $ATEXT → ✅ PASSED"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                sqlite3 "$DB" "UPDATE assumptions SET verified=-1, verified_on='$TODAY_VA' WHERE id=$AID;"
                echo "  #$AID: $ATEXT → ❌ FAILED"
                echo "         Output: $ARESULT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        fi
    done
    echo ""
    echo "  Results: $PASS_COUNT passed, $FAIL_COUNT failed, $MANUAL_COUNT manual"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "  ⚠️  Fix failed assumptions before proceeding"
    fi
    ;;

assumptions)
    # List all assumptions for a task with status
    # Usage: bash db_queries.sh assumptions <task-id>
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh assumptions <task-id>"
        exit 1
    fi
    ATOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM assumptions WHERE task_id='$2';" 2>/dev/null)
    if [ "$ATOTAL" -eq 0 ]; then
        echo "No assumptions registered for $2"
        exit 0
    fi
    echo ""
    echo "── Assumptions for $2 ─────"
    sqlite3 "$DB" "
        SELECT '  ' ||
            CASE verified
                WHEN 1 THEN '✅'
                WHEN -1 THEN '❌'
                ELSE '⏳'
            END || ' #' || id || ': ' || assumption ||
            CASE WHEN verified_on IS NOT NULL THEN ' (' || verified_on || ')' ELSE '' END
        FROM assumptions
        WHERE task_id='$2'
        ORDER BY id;
    " 2>/dev/null
    echo ""
    ;;

researched)
    # Mark a task as researched (Layer 2)
    # Usage: bash db_queries.sh researched <task-id>
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh researched <task-id>"
        exit 1
    fi
    SAFE_R_ID=$(sanitize_id "$2") || exit 1
    RTASK_EXISTS=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$SAFE_R_ID';")
    if [ -z "$RTASK_EXISTS" ]; then
        echo "❌ Task '$SAFE_R_ID' not found in database"
        exit 1
    fi
    sqlite3 "$DB" "UPDATE tasks SET researched=1 WHERE id='$SAFE_R_ID';"
    echo "✅ Marked as researched: $SAFE_R_ID"
    ;;

break-tested)
    # Mark a task as breakage-tested (Layer 4)
    # Usage: bash db_queries.sh break-tested <task-id>
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh break-tested <task-id>"
        exit 1
    fi
    SAFE_B_ID=$(sanitize_id "$2") || exit 1
    BTASK_EXISTS=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$SAFE_B_ID';")
    if [ -z "$BTASK_EXISTS" ]; then
        echo "❌ Task '$SAFE_B_ID' not found in database"
        exit 1
    fi
    sqlite3 "$DB" "UPDATE tasks SET breakage_tested=1 WHERE id='$SAFE_B_ID';"
    echo "✅ Marked as breakage-tested: $SAFE_B_ID"
    ;;

quick)
    # Quick ad-hoc task capture — one command, zero follow-up
    # Usage: bash db_queries.sh quick "<title>" [phase] [tag] [--loopback ORIGIN] [--severity N] [--gate-critical] [--reason "text"]
    # Note: phase and tag args must precede flags
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh quick \"<title>\" [phase] [tag] [--loopback ORIGIN_PHASE] [--severity 1-4] [--gate-critical] [--reason \"text\"]"
        echo "  Without --loopback: captures to INBOX queue (existing behavior)"
        echo "  With --loopback:    creates a loopback task targeting ORIGIN_PHASE code"
        exit 1
    fi

    QK_TITLE=$(echo "$2" | sed "s/'/''/g")
    QK_PHASE="${3:-INBOX}"
    QK_TAG="${4:-}"

    # Parse optional flags from $5 onward
    QK_LOOPBACK=""
    QK_SEVERITY=""
    QK_GATE_CRIT=0
    QK_REASON=""
    shift 4 2>/dev/null  # Skip past title, phase, tag (may fail if <4 args — that's ok)
    while [ $# -gt 0 ]; do
        case "$1" in
            --loopback)   QK_LOOPBACK="$2"; shift 2 ;;
            --severity)   QK_SEVERITY="$2"; shift 2 ;;
            --gate-critical) QK_GATE_CRIT=1; shift ;;
            --reason)     QK_REASON="$2"; shift 2 ;;
            *)            shift ;;
        esac
    done

    QK_STAMP=$(date +%s)

    if [ -n "$QK_LOOPBACK" ]; then
        # ── Loopback task ──
        QK_ID="LB-${QK_STAMP: -4}"
        # Collision avoidance
        if sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$QK_ID';" | grep -q .; then
            QK_ID="${QK_ID}a"
        fi
        QK_SEV="${QK_SEVERITY:-3}"  # Default S3
        SAFE_REASON="NULL"
        [ -n "$QK_REASON" ] && SAFE_REASON="'$(echo "$QK_REASON" | sed "s/'/''/g")'"
        SAFE_TAG="NULL"
        [ -n "$QK_TAG" ] && SAFE_TAG="'$(echo "$QK_TAG" | sed "s/'/''/g")'"

        sqlite3 "$DB" "
            INSERT INTO tasks (id, phase, assignee, title, priority, status, queue, sort_order, details,
                               track, origin_phase, discovered_in, severity, gate_critical, loopback_reason)
            VALUES ('$QK_ID', '$QK_PHASE', 'CLAUDE', '$QK_TITLE', 'LB', 'TODO', 'A', 999, $SAFE_TAG,
                    'loopback', '$QK_LOOPBACK', '$QK_PHASE', $QK_SEV, $QK_GATE_CRIT, $SAFE_REASON);
        "
        SEV_ICON=$(sev_icon "$QK_SEV")
        echo "$SEV_ICON LB $QK_ID: $2"
        echo "   Origin: $QK_LOOPBACK | Severity: S$QK_SEV | Gate-critical: $([ $QK_GATE_CRIT -eq 1 ] && echo 'YES' || echo 'no')"
        [ -n "$QK_REASON" ] && echo "   Reason: $QK_REASON"
        # Circuit breaker warning
        if [ "$QK_SEV" -eq 1 ] && [ "$QK_GATE_CRIT" -eq 1 ]; then
            echo ""
            echo "   ⚠️  CIRCUIT BREAKER: S1 gate-critical loopback created."
            echo "   Forward tasks will show CONFIRM until this is resolved or acknowledged."
        fi
        # Blast radius estimation
        BLAST=$(sqlite3 "$DB" "
            SELECT COUNT(DISTINCT phase) FROM tasks
            WHERE phase > '$QK_LOOPBACK' AND COALESCE(track,'forward')='forward'
              AND status NOT IN ('DONE','SKIP');
        " 2>/dev/null)
        [ "$BLAST" -gt 0 ] && echo "   Blast radius: $QK_LOOPBACK → may affect $BLAST phase(s) downstream"
    else
        # ── Standard INBOX task (existing behavior, unchanged) ──
        QK_ID="QK-${QK_STAMP: -4}"
        if sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$QK_ID';" | grep -q .; then
            QK_ID="${QK_ID}a"
        fi
        SAFE_TAG="NULL"
        [ -n "$QK_TAG" ] && SAFE_TAG="'$(echo "$QK_TAG" | sed "s/'/''/g")'"
        sqlite3 "$DB" "
            INSERT INTO tasks (id, phase, assignee, title, priority, status, queue, sort_order, details)
            VALUES ('$QK_ID', '$QK_PHASE', 'CLAUDE', '$QK_TITLE', 'QK', 'TODO', 'INBOX', 999, $SAFE_TAG);
        "
        echo "📥 $QK_ID: $2"
    fi
    ;;

loopbacks)
    # View open loopback tasks, optionally filtered
    # Usage: bash db_queries.sh loopbacks [--origin PHASE] [--severity N] [--gate-critical] [--all]
    LB_FILTER="AND status NOT IN ('DONE','SKIP')"
    LB_EXTRA=""

    shift  # past "loopbacks"
    while [ $# -gt 0 ]; do
        case "$1" in
            --origin)       LB_EXTRA="$LB_EXTRA AND origin_phase='$2'"; shift 2 ;;
            --severity)     LB_EXTRA="$LB_EXTRA AND severity=$2"; shift 2 ;;
            --gate-critical) LB_EXTRA="$LB_EXTRA AND gate_critical=1"; shift ;;
            --all)          LB_FILTER=""; shift ;;
            *)              shift ;;
        esac
    done

    echo ""
    echo "── Loopback Tasks ───────────────────────────────────────────"

    # Count summary
    LB_OPEN=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
    LB_DONE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status='DONE';" 2>/dev/null)
    LB_SKIP=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status='SKIP';" 2>/dev/null)
    echo "  Open: $LB_OPEN | Done: $LB_DONE | Skipped: $LB_SKIP"
    echo ""

    # Severity breakdown of open
    if [ "$LB_OPEN" -gt 0 ]; then
        S1=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP') AND severity=1;" 2>/dev/null)
        S2=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP') AND severity=2;" 2>/dev/null)
        S3=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP') AND severity=3;" 2>/dev/null)
        S4=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP') AND severity=4;" 2>/dev/null)
        echo "  Severity: S1:$S1 S2:$S2 S3:$S3 S4:$S4"
        echo ""
    fi

    # List tasks
    sqlite3 "$DB" "
        SELECT
            CASE severity
                WHEN 1 THEN '🔴 S1'
                WHEN 2 THEN '🟡 S2'
                WHEN 3 THEN '🟢 S3'
                WHEN 4 THEN '⚪ S4'
                ELSE '   ??'
            END || ' | ' || id || ' | ' || title ||
            ' | origin: ' || COALESCE(origin_phase,'?') ||
            ' | found: ' || COALESCE(discovered_in,'?') ||
            CASE WHEN gate_critical=1 THEN ' | GATE-CRITICAL' ELSE '' END ||
            CASE WHEN status IN ('DONE','SKIP') THEN ' | ' || status ELSE '' END
        FROM tasks
        WHERE track='loopback' $LB_FILTER $LB_EXTRA
        ORDER BY severity ASC, sort_order ASC;
    "
    echo ""
    ;;

inbox)
    # Show all untriaged INBOX items
    echo ""
    echo "── Inbox (untriaged tasks) ──────────────────────────────────"
    INBOX_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE queue='INBOX';" 2>/dev/null)
    if [ "$INBOX_COUNT" -eq 0 ]; then
        echo "  (empty)"
    else
        sqlite3 -column -header "$DB" "
            SELECT id, title, phase,
                   COALESCE(details, '') AS tag
            FROM tasks
            WHERE queue='INBOX'
            ORDER BY sort_order, id;
        "
    fi
    echo ""
    echo "  $INBOX_COUNT item(s) in inbox"
    echo "  Triage: bash db_queries.sh triage <id> <phase> <tier> [skill] [blocked_by]"
    echo ""
    ;;

triage)
    # Promote an INBOX item to planned work, or triage as loopback
    # Usage: bash db_queries.sh triage <id> <phase> <tier> [skill] [blocked_by]
    #        bash db_queries.sh triage <id> loopback <origin_phase> [--severity N] [--gate-critical] [--reason text]
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: bash db_queries.sh triage <id> <phase> <tier> [skill] [blocked_by]"
        echo "       bash db_queries.sh triage <id> loopback <origin_phase> [--severity N] [--gate-critical] [--reason text]"
        exit 1
    fi
    TR_ID="$2"

    # Verify task exists
    TR_QUEUE=$(sqlite3 "$DB" "SELECT queue FROM tasks WHERE id='$TR_ID';")
    if [ -z "$TR_QUEUE" ]; then
        echo "❌ Task '$TR_ID' not found"
        exit 1
    fi

    # Check if triaging to loopback track
    if [ "$3" = "loopback" ]; then
        TR_ORIGIN="${4:-}"
        if [ -z "$TR_ORIGIN" ]; then
            echo "Usage: bash db_queries.sh triage <id> loopback <origin_phase> [--severity N] [--gate-critical] [--reason text]"
            exit 1
        fi
        TR_SEV=3; TR_GC=0; TR_REASON=""
        shift 4 2>/dev/null
        while [ $# -gt 0 ]; do
            case "$1" in
                --severity)     TR_SEV="$2"; shift 2 ;;
                --gate-critical) TR_GC=1; shift ;;
                --reason)       TR_REASON="$2"; shift 2 ;;
                *)              shift ;;
            esac
        done
        # Get discovered_in from the task's current phase
        TR_DISC=$(sqlite3 "$DB" "SELECT phase FROM tasks WHERE id='$TR_ID';")
        SAFE_REASON="NULL"
        [ -n "$TR_REASON" ] && SAFE_REASON="'$(echo "$TR_REASON" | sed "s/'/''/g")'"
        sqlite3 "$DB" "
            UPDATE tasks
            SET queue='A', track='loopback', priority='LB',
                origin_phase='$TR_ORIGIN', discovered_in='$TR_DISC',
                severity=$TR_SEV, gate_critical=$TR_GC, loopback_reason=$SAFE_REASON
            WHERE id='$TR_ID';
        "
        TR_TITLE=$(sqlite3 "$DB" "SELECT title FROM tasks WHERE id='$TR_ID';" 2>/dev/null)
        SEV_ICON=$(sev_icon "$TR_SEV")
        echo "$SEV_ICON Triaged as loopback: $TR_ID → origin $TR_ORIGIN (S$TR_SEV)"
        echo "   $TR_TITLE"
        [ "$TR_GC" -eq 1 ] && echo "   Gate-critical: YES"
        [ -n "$TR_REASON" ] && echo "   Reason: $TR_REASON"
    else
        # ── Standard triage (existing behavior) ──
        if [ -z "$4" ]; then
            echo "Usage: bash db_queries.sh triage <id> <phase> <tier> [skill] [blocked_by]"
            exit 1
        fi
        TR_PHASE="$3"
        TR_TIER="$4"
        TR_SKILL="${5:-}"
        TR_BLOCKED="${6:-}"

        if [ "$TR_QUEUE" != "INBOX" ]; then
            echo "⚠️  Task '$TR_ID' is already triaged (queue='$TR_QUEUE')"
            exit 1
        fi

        # Derive sort_order = MAX in phase + 10
        MAX_SORT=$(sqlite3 "$DB" "SELECT COALESCE(MAX(sort_order), 0) FROM tasks WHERE phase='$TR_PHASE';")
        TR_SORT=$((MAX_SORT + 10))

        # Derive priority from phase
        TR_PRIORITY=$(echo "$TR_PHASE" | sed 's/-.*//')

        SAFE_TR_SKILL="NULL"
        [ -n "$TR_SKILL" ] && SAFE_TR_SKILL="'$(echo "$TR_SKILL" | sed "s/'/''/g")'"

        SAFE_TR_BLOCKED="NULL"
        [ -n "$TR_BLOCKED" ] && SAFE_TR_BLOCKED="'$TR_BLOCKED'"

        sqlite3 "$DB" "
            UPDATE tasks
            SET queue='A', phase='$TR_PHASE', tier='$TR_TIER', priority='$TR_PRIORITY',
                sort_order=$TR_SORT, skill=$SAFE_TR_SKILL, blocked_by=$SAFE_TR_BLOCKED
            WHERE id='$TR_ID';
        "
        TR_TITLE=$(sqlite3 "$DB" "SELECT title FROM tasks WHERE id='$TR_ID';" 2>/dev/null)
        echo "✅ Triaged: $TR_ID → $TR_PHASE ($TR_TIER)"
        echo "   $TR_TITLE"
        echo "   Sort order: $TR_SORT | Skill: ${TR_SKILL:-none} | Blocked by: ${TR_BLOCKED:-none}"
    fi
    ;;

delegation-md)
    # Auto-regenerate AGENT_DELEGATION.md §8 from DB
    DELEG_FILE_MD="$(dirname "$0")/AGENT_DELEGATION.md"

    if [ ! -f "$DELEG_FILE_MD" ]; then
        echo "❌ AGENT_DELEGATION.md not found"
        exit 1
    fi

    # Check for markers
    if ! grep -q '<!-- DELEGATION-START -->' "$DELEG_FILE_MD"; then
        echo "❌ Missing <!-- DELEGATION-START --> marker in AGENT_DELEGATION.md"
        echo "   Add <!-- DELEGATION-START --> and <!-- DELEGATION-END --> markers around §8 content."
        exit 1
    fi

    # Build new content into a temp file
    CONTENT_FILE="/tmp/delegation_md_content.txt"
    > "$CONTENT_FILE"

    ALL_PHASES=$(sqlite3 "$DB" "
        SELECT DISTINCT phase FROM tasks WHERE queue != 'INBOX' AND COALESCE(track,'forward')='forward' ORDER BY phase;
    " 2>/dev/null)

    for PHASE in $ALL_PHASES; do
        DONE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE phase='$PHASE' AND COALESCE(track,'forward')='forward' AND status='DONE';" 2>/dev/null)
        TOTAL_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE phase='$PHASE' AND COALESCE(track,'forward')='forward' AND queue != 'INBOX';" 2>/dev/null)

        # Check if this phase has been gated — if so, collapse to a 1-line summary
        IS_GATED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM phase_gates WHERE phase='$PHASE';" 2>/dev/null)

        if [ "$IS_GATED" -gt 0 ] && [ "$DONE_COUNT" -eq "$TOTAL_COUNT" ]; then
            GATE_DATE=$(sqlite3 "$DB" "SELECT gated_on FROM phase_gates WHERE phase='$PHASE';" 2>/dev/null)
            echo "### $PHASE ($DONE_COUNT/$TOTAL_COUNT DONE) — gated $GATE_DATE" >> "$CONTENT_FILE"
            echo "" >> "$CONTENT_FILE"
            continue
        fi

        if [ "$DONE_COUNT" -eq "$TOTAL_COUNT" ]; then
            echo "### $PHASE (DONE — $DONE_COUNT/$TOTAL_COUNT)" >> "$CONTENT_FILE"
        else
            echo "### $PHASE ($DONE_COUNT/$TOTAL_COUNT done)" >> "$CONTENT_FILE"
        fi
        echo "| Task | Tier | Skill | Status | Why |" >> "$CONTENT_FILE"
        echo "|------|------|-------|--------|-----|" >> "$CONTENT_FILE"

        sqlite3 "$DB" "
            SELECT id || '|' || title || '|' || COALESCE(tier,'—') || '|' || COALESCE(skill,'—') || '|' || status || '|' || COALESCE(research_notes,'')
            FROM tasks
            WHERE phase='$PHASE' AND queue != 'INBOX' AND COALESCE(track,'forward')='forward'
            ORDER BY sort_order, id;
        " 2>/dev/null | while IFS='|' read -r T_ID T_TITLE T_TIER T_SKILL T_STATUS T_NOTES; do
            NOTE_PART=""
            [ -n "$T_NOTES" ] && NOTE_PART=" **RESEARCH:** $T_NOTES"
            echo "| $T_ID $T_TITLE | $T_TIER | $T_SKILL | $T_STATUS |$NOTE_PART |"
        done >> "$CONTENT_FILE"

        echo "" >> "$CONTENT_FILE"
    done

    # Check for INBOX items and add a note
    INBOX_CT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE queue='INBOX';" 2>/dev/null)
    if [ "$INBOX_CT" -gt 0 ]; then
        echo "### INBOX ($INBOX_CT untriaged)" >> "$CONTENT_FILE"
        echo "| Task | Title | Tag |" >> "$CONTENT_FILE"
        echo "|------|-------|-----|" >> "$CONTENT_FILE"
        sqlite3 "$DB" "
            SELECT id || '|' || title || '|' || COALESCE(details,'')
            FROM tasks
            WHERE queue='INBOX'
            ORDER BY id;
        " 2>/dev/null | while IFS='|' read -r I_ID I_TITLE I_TAG; do
            echo "| $I_ID | $I_TITLE | $I_TAG |"
        done >> "$CONTENT_FILE"
        echo "" >> "$CONTENT_FILE"
    fi

    # Reassemble: before START marker + START marker + new content + END marker + after END marker
    awk '/<!-- DELEGATION-START -->/ { print; exit }' "$DELEG_FILE_MD" > /tmp/delegation_md_final.txt
    cat "$CONTENT_FILE" >> /tmp/delegation_md_final.txt
    awk 'found { print } /<!-- DELEGATION-END -->/ { found=1 }' "$DELEG_FILE_MD" >> /tmp/delegation_md_final.txt

    # Write everything before the START marker line
    BEFORE_FILE="/tmp/delegation_md_before.txt"
    awk '/<!-- DELEGATION-START -->/ { exit } { print }' "$DELEG_FILE_MD" > "$BEFORE_FILE"
    cat "$BEFORE_FILE" > /tmp/delegation_md_final2.txt
    echo '<!-- DELEGATION-START -->' >> /tmp/delegation_md_final2.txt
    cat "$CONTENT_FILE" >> /tmp/delegation_md_final2.txt
    # Get everything from END marker onward (inclusive)
    awk '/<!-- DELEGATION-END -->/ { found=1 } found { print }' "$DELEG_FILE_MD" >> /tmp/delegation_md_final2.txt

    cp /tmp/delegation_md_final2.txt "$DELEG_FILE_MD"
    rm -f "$CONTENT_FILE" "$BEFORE_FILE" /tmp/delegation_md_final.txt /tmp/delegation_md_final2.txt

    echo "✅ Regenerated AGENT_DELEGATION.md §8 from DB"
    echo "   Phases: $(echo "$ALL_PHASES" | tr '\n' ' ')"
    [ "$INBOX_CT" -gt 0 ] && echo "   📥 $INBOX_CT inbox item(s) included" || true
    ;;

promote)
    # Quick-promote a universal pattern from project LESSONS to LESSONS_UNIVERSAL.md
    UNIVERSAL="$HOME/.claude/LESSONS_UNIVERSAL.md"
    if [ ! -f "$UNIVERSAL" ]; then
        echo "❌ $UNIVERSAL not found — run: bash ~/.claude/harvest.sh (creates it if missing)"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh promote \"pattern text\" [\"prevention rule\"]"
        echo "  Appends to ~/.claude/LESSONS_UNIVERSAL.md"
        exit 1
    fi
    TODAY=$(date "+%Y-%m-%d")
    PROJECT_NAME=$(basename "$(dirname "$0")")
    PATTERN="$2"
    PREVENTION="${3:-See source project LESSONS.md}"
    echo "| $TODAY | $PATTERN | $PROJECT_NAME | $PREVENTION |" >> "$UNIVERSAL"
    echo "✅ Promoted to LESSONS_UNIVERSAL.md"
    echo "   ⚠️  Remember to mark the source entry as promoted in LESSONS*.md"
    ;;

escalate)
    # Escalate a lesson to the bootstrap backlog for template/framework improvement
    # Usage: bash db_queries.sh escalate "description" [category] [affected-file] [--priority P0|P1|P2|P3]
    BACKLOG="$HOME/.claude/dev-framework/BOOTSTRAP_BACKLOG.md"
    if [ ! -f "$BACKLOG" ]; then
        echo "❌ $BACKLOG not found"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "Usage: bash db_queries.sh escalate \"description\" [category] [affected-file] [--priority P0|P1|P2|P3]"
        echo "  Categories: template (default), framework, process, system"
        echo "  Appends to ~/.claude/dev-framework/BOOTSTRAP_BACKLOG.md"
        exit 1
    fi
    ESC_DESC="$2"
    ESC_CAT="${3:-template}"
    ESC_FILE="${4:-unknown (review needed)}"
    ESC_PRIORITY="P2"
    # Parse --priority from any position
    for arg in "$@"; do
        if [[ "$arg" =~ ^P[0-3]$ ]]; then ESC_PRIORITY="$arg"; fi
    done
    for i in "$@"; do
        if [[ "$i" == "--priority" ]]; then NEXT_IS_PRIORITY=1; continue; fi
        if [[ "${NEXT_IS_PRIORITY:-0}" -eq 1 ]]; then ESC_PRIORITY="$i"; NEXT_IS_PRIORITY=0; fi
    done
    # Validate category
    case "$ESC_CAT" in
        template|framework|process|system) ;;
        --priority) ESC_CAT="template"; ;; # --priority passed as arg 3
        *) echo "⚠️  Unknown category '$ESC_CAT' — using 'template'"; ESC_CAT="template" ;;
    esac
    # Derive next BP-ID
    ESC_MAX=$(grep -oE 'BP-[0-9]+' "$BACKLOG" | sed 's/BP-//' | sort -n | tail -1)
    if [ -z "$ESC_MAX" ]; then
        ESC_ID="BP-001"
    else
        ESC_ID=$(printf "BP-%03d" $((ESC_MAX + 1)))
    fi
    ESC_TODAY=$(date "+%Y-%m-%d")
    ESC_PROJECT=$(basename "$(dirname "$0")")
    # Check for duplicates (same affected file + similar description)
    if [ "$ESC_FILE" != "unknown (review needed)" ]; then
        DUP_CHECK=$(grep -c "$ESC_FILE" "$BACKLOG" 2>/dev/null || echo 0)
        if [ "$DUP_CHECK" -gt 0 ]; then
            echo "⚠️  Backlog already has $DUP_CHECK item(s) mentioning $ESC_FILE"
            echo "   Adding anyway — review for duplicates with: bash ~/.claude/dev-framework/apply_backlog.sh"
        fi
    fi
    # Append to Pending section (before PENDING-ANCHOR)
    ESC_ANCHOR=$(grep -n '<!-- PENDING-ANCHOR' "$BACKLOG" | tail -1 | cut -d: -f1)
    if [ -z "$ESC_ANCHOR" ]; then
        # Fallback: append before ## Applied
        ESC_ANCHOR=$(grep -n '^## Applied' "$BACKLOG" | head -1 | cut -d: -f1)
    fi
    if [ -z "$ESC_ANCHOR" ]; then
        echo "❌ Could not find insertion point in BOOTSTRAP_BACKLOG.md"
        exit 1
    fi
    ESC_TEMP="/tmp/backlog_escalate_$$.md"
    export ESC_ID ESC_CAT ESC_DESC ESC_TODAY ESC_PROJECT ESC_PRIORITY ESC_FILE
    awk -v anchor="$ESC_ANCHOR" '
        NR == anchor {
            print ""
            print "### " ENVIRON["ESC_ID"] " [" ENVIRON["ESC_CAT"] "] " ENVIRON["ESC_DESC"]
            print "- **Escalated:** " ENVIRON["ESC_TODAY"]
            print "- **Source:** " ENVIRON["ESC_PROJECT"]
            print "- **Priority:** " ENVIRON["ESC_PRIORITY"]
            print "- **Affected:** " ENVIRON["ESC_FILE"]
            print "- **Description:** " ENVIRON["ESC_DESC"]
            print "- **Change:** (to be determined during review)"
            print "- **Status:** pending"
            print ""
        }
        { print }
    ' "$BACKLOG" > "$ESC_TEMP"
    mv "$ESC_TEMP" "$BACKLOG"
    echo "✅ Escalated to bootstrap backlog as $ESC_ID [$ESC_CAT] ($ESC_PRIORITY)"
    echo "   Review: bash ~/.claude/dev-framework/apply_backlog.sh $ESC_ID"
    ;;

unblock)
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh unblock <task-id>"; exit 1; fi
    UNBLOCK_ID=$(sanitize_id "$2") || exit 1
    OLD_BLOCKER=$(sqlite3 "$DB" "SELECT blocked_by FROM tasks WHERE id='$UNBLOCK_ID';")
    if [ -z "$OLD_BLOCKER" ] || [ "$OLD_BLOCKER" = "" ]; then
        echo "  Task $UNBLOCK_ID has no blocked_by set"
    else
        sqlite3 "$DB" "UPDATE tasks SET blocked_by=NULL WHERE id='$UNBLOCK_ID';"
        echo "✅ Cleared blocked_by on $UNBLOCK_ID (was: $OLD_BLOCKER)"
    fi
    ;;

ack-breaker)
    # Acknowledge a circuit breaker (S1 gate-critical loopback)
    # Usage: bash db_queries.sh ack-breaker <LB-ID> "<reason>"
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: bash db_queries.sh ack-breaker <LB-ID> \"<reason why forward work can continue>\""
        exit 1
    fi
    ACK_ID=$(sanitize_id "$2") || exit 1
    ACK_REASON=$(echo "$3" | sed "s/'/''/g")
    ACK_DATE=$(date "+%Y-%m-%d")

    # Verify it's actually a loopback task
    ACK_CHECK=$(sqlite3 "$DB" "SELECT track FROM tasks WHERE id='$ACK_ID';")
    if [ "$ACK_CHECK" != "loopback" ]; then
        echo "❌ '$ACK_ID' is not a loopback task"
        exit 1
    fi

    sqlite3 "$DB" "INSERT OR REPLACE INTO loopback_acks (loopback_id, acked_on, acked_by, reason) VALUES ('$ACK_ID', '$ACK_DATE', 'MASTER', '$ACK_REASON');"
    echo "✅ Circuit breaker acknowledged: $ACK_ID"
    echo "   Reason: $3"
    echo "   Forward tasks will no longer show CONFIRM for this loopback."
    ;;

skip)
    # Mark a task as SKIP (won't do / won't fix)
    # Usage: bash db_queries.sh skip <id> ["reason"]
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh skip <id> [\"reason\"]"; exit 1; fi
    SAFE_SKIP_ID=$(sanitize_id "$2") || exit 1
    SKIP_CHECK=$(sqlite3 "$DB" "SELECT id FROM tasks WHERE id='$SAFE_SKIP_ID';")
    if [ -z "$SKIP_CHECK" ]; then echo "❌ Task '$SAFE_SKIP_ID' not found"; exit 1; fi
    SKIP_REASON="${3:-}"
    TODAY=$(date "+%b %d" | sed 's/ 0/ /')
    SAFE_SKIP_REASON=""
    [ -n "$SKIP_REASON" ] && SAFE_SKIP_REASON=", details='$(echo "$SKIP_REASON" | sed "s/'/''/g")'"
    sqlite3 "$DB" "UPDATE tasks SET status='SKIP', completed_on='$TODAY' $SAFE_SKIP_REASON WHERE id='$SAFE_SKIP_ID';"
    echo "⏭️  Skipped: $SAFE_SKIP_ID ($TODAY)"
    [ -n "$SKIP_REASON" ] && echo "   Reason: $SKIP_REASON"
    # Clean up circuit breaker ack if this was a loopback
    SKIP_TRACK=$(sqlite3 "$DB" "SELECT COALESCE(track,'forward') FROM tasks WHERE id='$SAFE_SKIP_ID';")
    if [ "$SKIP_TRACK" = "loopback" ]; then
        sqlite3 "$DB" "DELETE FROM loopback_acks WHERE loopback_id='$SAFE_SKIP_ID';"
    fi
    ;;

loopback-stats)
    # Cross-project learning analytics for loopback tasks
    echo ""
    echo "══ LOOPBACK ANALYTICS ══════════════════════════════════════════"
    echo ""

    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback';" 2>/dev/null)
    OPEN=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
    DONE_LB=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status='DONE';" 2>/dev/null)
    SKIP_LB=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status='SKIP';" 2>/dev/null)
    echo "  Total: $TOTAL | Open: $OPEN | Done: $DONE_LB | Skipped: $SKIP_LB"
    echo ""

    if [ "$TOTAL" -eq 0 ]; then
        echo "  No loopback tasks yet."
        echo ""
        echo "══════════════════════════════════════════════════════════════════"
        echo ""
        exit 0
    fi

    echo "  By origin phase:"
    sqlite3 "$DB" "
        SELECT '    ' || COALESCE(origin_phase,'?') || ': ' || COUNT(*) ||
            ' (' ||
            'S1:' || SUM(CASE WHEN severity=1 THEN 1 ELSE 0 END) || ' ' ||
            'S2:' || SUM(CASE WHEN severity=2 THEN 1 ELSE 0 END) || ' ' ||
            'S3:' || SUM(CASE WHEN severity=3 THEN 1 ELSE 0 END) || ' ' ||
            'S4:' || SUM(CASE WHEN severity=4 THEN 1 ELSE 0 END) || ')'
        FROM tasks WHERE track='loopback'
        GROUP BY origin_phase
        ORDER BY COUNT(*) DESC;
    " 2>/dev/null
    echo ""

    echo "  Severity distribution:"
    sqlite3 "$DB" "
        SELECT '    S' || severity || ': ' || COUNT(*) ||
            ' (' || ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tasks WHERE track='loopback'), 0) || '%)'
        FROM tasks WHERE track='loopback' AND severity IS NOT NULL
        GROUP BY severity
        ORDER BY severity;
    " 2>/dev/null
    echo ""

    # Discovery lag metric using phase ordinals
    echo "  Discovery lag:"
    DISC_LAGS=""
    while IFS='|' read -r lb_origin lb_disc; do
        O_ORD=$(phase_ordinal "$lb_origin")
        D_ORD=$(phase_ordinal "$lb_disc")
        if [ "$O_ORD" -lt 99 ] && [ "$D_ORD" -lt 99 ]; then
            LAG=$((D_ORD - O_ORD))
            DISC_LAGS="${DISC_LAGS}${LAG}\n"
        fi
    done < <(sqlite3 "$DB" "SELECT origin_phase || '|' || discovered_in FROM tasks WHERE track='loopback' AND origin_phase IS NOT NULL AND discovered_in IS NOT NULL;" 2>/dev/null)
    if [ -n "$DISC_LAGS" ]; then
        LAG_COUNT=$(echo -e "$DISC_LAGS" | grep -c .)
        LAG_SUM=$(echo -e "$DISC_LAGS" | awk '{s+=$1} END {print s}')
        if [ "$LAG_COUNT" -gt 0 ] && [ -n "$LAG_SUM" ]; then
            LAG_AVG=$(echo "scale=1; $LAG_SUM / $LAG_COUNT" | bc 2>/dev/null || echo "?")
            echo "    Avg $LAG_AVG phases between origin and discovery ($LAG_COUNT samples)"
        fi
    else
        echo "    (insufficient data)"
    fi
    echo ""

    echo "  Top reasons:"
    sqlite3 "$DB" "
        SELECT '    ' || COALESCE(loopback_reason, '(none)') || ': ' || COUNT(*)
        FROM tasks WHERE track='loopback'
        GROUP BY loopback_reason
        ORDER BY COUNT(*) DESC
        LIMIT 5;
    " 2>/dev/null
    echo ""

    echo "  Gate-critical status:"
    GC_TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND gate_critical=1;" 2>/dev/null)
    GC_DONE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND gate_critical=1 AND status IN ('DONE','SKIP');" 2>/dev/null)
    GC_OPEN=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND gate_critical=1 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
    echo "    Total: $GC_TOTAL | Resolved: $GC_DONE | Open: $GC_OPEN"
    echo ""

    # Iteration hotspot warning
    HOTSPOT=$(sqlite3 "$DB" "
        SELECT origin_phase || ' (' || COUNT(*) || ' loopbacks)'
        FROM tasks WHERE track='loopback'
        GROUP BY origin_phase
        HAVING COUNT(*) >= 3
        ORDER BY COUNT(*) DESC
        LIMIT 1;
    " 2>/dev/null)
    if [ -n "$HOTSPOT" ]; then
        echo "  ⚠️  Iteration hotspot: $HOTSPOT — consider strengthening gate criteria"
        echo ""
    fi

    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    ;;

loopback-lesson)
    # Auto-generate a lesson entry from a resolved loopback
    # Usage: bash db_queries.sh loopback-lesson <LB-ID>
    if [ -z "$2" ]; then echo "Usage: bash db_queries.sh loopback-lesson <LB-ID>"; exit 1; fi
    LL_ID=$(sanitize_id "$2") || exit 1
    LL_INFO=$(sqlite3 "$DB" "
        SELECT title || '|' || COALESCE(origin_phase,'?') || '|' || COALESCE(discovered_in,'?') ||
               '|' || COALESCE(severity,'?') || '|' || COALESCE(loopback_reason,'unspecified') ||
               '|' || COALESCE(completed_on,'?')
        FROM tasks WHERE id='$LL_ID' AND track='loopback';
    " 2>/dev/null)
    if [ -z "$LL_INFO" ]; then
        echo "❌ '$LL_ID' is not a loopback task"
        exit 1
    fi

    LL_TITLE=$(echo "$LL_INFO" | cut -d'|' -f1)
    LL_ORIGIN=$(echo "$LL_INFO" | cut -d'|' -f2)
    LL_DISC=$(echo "$LL_INFO" | cut -d'|' -f3)
    LL_SEV=$(echo "$LL_INFO" | cut -d'|' -f4)
    LL_REASON=$(echo "$LL_INFO" | cut -d'|' -f5)
    LL_DATE=$(echo "$LL_INFO" | cut -d'|' -f6)

    LESSONS_FILE="$(dirname "$0")/%%LESSONS_FILE%%"
    LESSON_ENTRY="| $LL_DATE | Loopback $LL_ID: $LL_TITLE — discovered in $LL_DISC, origin $LL_ORIGIN (S$LL_SEV, reason: $LL_REASON). Gate should have caught this at $LL_ORIGIN phase. |"

    # Insert before ## Universal Patterns marker (not at EOF)
    if grep -q "## Universal Patterns" "$LESSONS_FILE" 2>/dev/null; then
        # Use sed to insert before the Universal Patterns section
        sed -i '' "/## Universal Patterns/i\\
\\
$LESSON_ENTRY\\
" "$LESSONS_FILE" 2>/dev/null
        echo "✅ Lesson inserted into %%LESSONS_FILE%% (before Universal Patterns)"
    else
        # Fallback: append to EOF if marker not found
        echo "" >> "$LESSONS_FILE"
        echo "$LESSON_ENTRY" >> "$LESSONS_FILE"
        echo "✅ Lesson appended to %%LESSONS_FILE%%"
    fi
    echo "   $LESSON_ENTRY"
    ;;

*)
    echo ""
    echo "Usage: bash db_queries.sh <command>"
    echo ""
    echo "  phase         Current phase (earliest with incomplete tasks)"
    echo "  blockers      Master/Gemini tasks blocking Claude work"
    echo "  gate          Show which phases have passed their gate"
    echo "  gate-pass <P> Record phase gate passed"
    echo "  check <id>    Pre-task safety check — GO, CONFIRM, or STOP with reasons"
    echo "  confirm <id>  Record Master approval of a milestone checkpoint"
    echo "  confirmations Show all milestone confirmations"
    echo "  next [--ready-only]  Next TODO tasks for Claude Code (--ready-only skips BLOCKED list)"
    echo "  status        Phase completion overview"
    echo "  master        Master's TODO tasks"
    echo "  task <id>     Full details for one task"
    echo "  done <id>     Mark a task DONE"
    echo "  unblock <id>  Clear a stale/resolved blocked_by reference"
    echo "  start <id>    Mark a task IN_PROGRESS"
    echo "  decisions     Recent decisions log"
    echo "  sessions      Session history"
    echo "  board         Generate TASK_BOARD.md"
    echo "  tag-browser <id> [0|1]  Mark task as needing browser review"
    echo "  lessons       Show all lessons with staleness and violation tracking"
    echo "  log-lesson \"what\" \"pattern\" \"rule\" [--bp cat file]  Append correction (+ optional bootstrap escalation)"
    echo "  verify        Check DB is populated (use in handoff docs, not by hand)"
    echo "  log <type> <summary>  Add a session log entry"
    echo ""
    echo "Ad-hoc task capture:"
    echo "  quick \"<title>\" [phase] [tag]  Capture ad-hoc task to INBOX (1 command)"
    echo "  inbox                          View untriaged INBOX items"
    echo "  triage <id> <phase> <tier> [skill] [blocked_by]  Promote to planned work"
    echo "  triage <id> loopback <origin> [--severity N] [--gate-critical]  Triage as loopback"
    echo "  skip <id> [\"reason\"]           Mark task SKIP (won't fix)"
    echo ""
    echo "Loopback:"
    echo "  quick ... --loopback ORIGIN    Create loopback task (fix earlier-phase code)"
    echo "  loopbacks [--origin] [--severity] [--gate-critical] [--all]  View loopback queue"
    echo "  ack-breaker <LB-ID> reason     Acknowledge S1 circuit breaker"
    echo "  loopback-stats                 Analytics: origins, severity, hotspots"
    echo "  loopback-lesson <LB-ID>        Generate lesson from resolved loopback"
    echo ""
    echo "Delegation & sync:"
    echo "  delegation [PHASE]    Generate delegation table from DB (all phases or specific)"
    echo "  delegation-md         Auto-regenerate AGENT_DELEGATION.md §8 from DB"
    echo "  sync-check            Detect drift between DB and AGENT_DELEGATION.md"
    echo "  add-task              Interactive: add a new task with all metadata"
    echo ""
    echo "Falsification protocol:"
    echo "  assume <id> \"text\" [\"cmd\"]  Register an assumption for a task"
    echo "  verify-assumption <id> <#>   Run verification for one assumption"
    echo "  verify-all <id>              Batch verify all assumptions for a task"
    echo "  assumptions <id>             List assumptions with status"
    echo "  researched <id>              Mark task as researched (soft gate)"
    echo "  break-tested <id>            Mark task as breakage-tested"
    echo ""
    echo "Health & recovery:"
    echo "  init-db                   Create all tables (run once after touch [project].db)"
    echo "  health                    Pipeline health diagnostic (HEALTHY/DEGRADED/CRITICAL)"
    echo "  backup                    Backup DB to backups/ directory"
    echo "  restore [file]            Restore DB from backup (lists backups if no file given)"
    echo ""
    echo "Versioning & snapshots:"
    echo "  snapshot [label]          Save DB task state snapshot"
    echo "  snapshot-list             List all snapshots"
    echo "  snapshot-show <id>        Show snapshot details"
    echo "  snapshot-diff <id1> <id2> Diff two snapshots"
    echo "  tag-session               Create session git tag"
    echo "  session-tags              List session tags"
    echo "  session-file <N> <file>   Show file at session N"
    echo ""
    echo "Knowledge transfer:"
    echo "  promote \"pattern\" [\"rule\"]  Quick-promote universal pattern to ~/.claude/LESSONS_UNIVERSAL.md"
    echo "  escalate \"desc\" [cat] [file] [--priority P0-P3]  Escalate to bootstrap backlog"
    echo ""
    echo "Related tools:"
    echo "  bash snapshot.sh save <file> [label]  Archive a file before overwrite"
    echo "  bash snapshot.sh save-all [label]     Archive all watched files"
    echo "  bash history.sh log <file>            Show file version history"
    echo "  bash history.sh diff <file> [N1 N2]   Diff file versions"
    echo ""
    ;;
esac
