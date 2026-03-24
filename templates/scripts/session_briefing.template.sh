#!/usr/bin/env bash
# Session Briefing — compact status digest at session start
#
# ┌─────────────────────────────────────────────────────────────────┐
# │  TEMPLATE PLACEHOLDERS — replace before use                     │
# │                                                                 │
# │  %%PROJECT_NAME%%   Human-readable project name                 │
# │                     e.g. "My Project"                           │
# │  %%PROJECT_DB%%        SQLite database filename (basename only)    │
# │                     e.g. "my_project.db"                        │
# │  %%LESSONS_FILE%%   Project lessons markdown filename           │
# │                     e.g. "LESSONS_MY_PROJECT.md"                │
# │  %%PROJECT_MEMORY_FILE%%    Project memory markdown filename            │
# │                     e.g. "MY_PROJECT_PROJECT_MEMORY.md"         │
# │  %%RULES_FILE%%     Project rules markdown filename             │
# │                     e.g. "MY_PROJECT_RULES.md"                  │
# │                                                                 │
# │  Example sed replacement:                                       │
# │    sed 's/%%PROJECT_NAME%%/My Project/g; \                      │
# │         s/%%PROJECT_DB%%/my_project.db/g; \                        │
# │         s/%%LESSONS_FILE%%/LESSONS_MYPROJECT.md/g; \            │
# │         s/%%PROJECT_MEMORY_FILE%%/MY_PROJECT_MEMORY.md/g; \             │
# │         s/%%RULES_FILE%%/MY_PROJECT_RULES.md/g' \               │
# │      session_briefing.template.sh > session_briefing.sh         │
# └─────────────────────────────────────────────────────────────────┘

DIR="$(dirname "$0")"
DB="$DIR/%%PROJECT_DB%%"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  %%PROJECT_NAME%% — Session Briefing  $(date '+%b %d, %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 0. sqlite3 + DB populated check — fail loudly if missing or empty
if ! command -v sqlite3 &>/dev/null; then
    echo ""
    echo "  ❌ CRITICAL: sqlite3 is not installed"
    echo "  DB commands require sqlite3. Install: apt install sqlite3 (Linux) or brew install sqlite3 (macOS)"
    echo "  This session cannot run DB-dependent workflow. Use a Claude Code session on your local machine."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
# Pipeline health — must pass before any other queries
HEALTH_OUT=$(bash "$DIR/db_queries.sh" health 2>&1)
HEALTH_EXIT=$?
if [ "$HEALTH_EXIT" -ne 0 ]; then
    echo "$HEALTH_OUT" | sed 's/^/  /'
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
echo "$HEALTH_OUT" | tail -3 | head -2  # Just the verdict

# Silent daily auto-backup (max 1 per day, at session start)
BACKUP_DIR="$DIR/backups"
TODAY=$(date +%Y%m%d)
if ! ls "$BACKUP_DIR"/%%PROJECT_DB_NAME%%-${TODAY}*.db 2>/dev/null | head -1 | grep -q .; then
    bash "$DIR/db_queries.sh" backup >/dev/null 2>&1
fi

# 1. Phase status
echo ""
echo "  📊 PHASE STATUS"
if [ -f "$DB" ]; then
    sqlite3 -column "$DB" "
        SELECT '  ' || t_agg.phase ||
               ' done=' || t_agg.done_count ||
               '/' || t_agg.total_count ||
               CASE WHEN t_agg.ready_count > 0
                    THEN '  <- ' || t_agg.ready_count || ' ready for Claude'
                    ELSE '' END
        FROM (
            SELECT phase,
                   SUM(CASE WHEN status='DONE' THEN 1 ELSE 0 END) AS done_count,
                   COUNT(*) AS total_count,
                   SUM(CASE WHEN status='TODO' AND assignee='CLAUDE'
                            AND (blocked_by IS NULL OR blocked_by = ''
                                 OR blocked_by IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP')))
                            THEN 1 ELSE 0 END) AS ready_count
            FROM tasks
            WHERE queue != 'INBOX' AND COALESCE(track,'forward')='forward'
            GROUP BY phase
        ) t_agg
        ORDER BY t_agg.phase;
    " 2>/dev/null
else
    echo "  ⚠️  Database not found"
fi

# 2. Next Claude tasks
echo ""
echo "  🤖 NEXT TASKS (Claude Code)"
if [ -f "$DB" ]; then
    sqlite3 -column "$DB" "
        SELECT '  [' || t.priority || '] ' || t.id || ' ' || t.title ||
               CASE
                 WHEN t.blocked_by IS NOT NULL AND t.blocked_by != ''
                      AND t.blocked_by NOT IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP'))
                 THEN ' [BLOCKED: ' || t.blocked_by || ']'
                 ELSE ' [READY]'
               END
        FROM tasks t
        WHERE t.status='TODO' AND t.assignee='CLAUDE'
          AND t.queue != 'INBOX'
        ORDER BY t.phase, t.sort_order
        LIMIT 5;
    " 2>/dev/null
fi

# 2b. Inbox items
if [ -f "$DB" ]; then
    INBOX_CT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE queue='INBOX';" 2>/dev/null)
    if [ "$INBOX_CT" -gt 0 ]; then
        echo ""
        echo "  📥 INBOX: $INBOX_CT untriaged task(s) — run: bash db_queries.sh inbox"
    fi
fi

# 2c. Loopback status
if [ -f "$DB" ]; then
    LB_OPEN=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
    if [ "$LB_OPEN" -gt 0 ]; then
        LB_S1=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND severity=1 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        LB_S2=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND severity=2 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        LB_S3=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND severity=3 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        LB_S4=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND severity=4 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        GC_OPEN_LB=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND gate_critical=1 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        echo ""
        echo "  🔄 LOOPBACK: $LB_OPEN open (S1:$LB_S1 S2:$LB_S2 S3:$LB_S3 S4:$LB_S4) | Gate-critical open: $GC_OPEN_LB"

        # Circuit breaker
        CB_S1=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE track='loopback' AND severity=1 AND gate_critical=1 AND status NOT IN ('DONE','SKIP');" 2>/dev/null)
        if [ "$CB_S1" -gt 0 ]; then
            echo "     ⚠️  CIRCUIT BREAKER ACTIVE — $CB_S1 S1 gate-critical loopback(s)"
        fi

        # Overload warning
        OVERLOAD_THRESHOLD=10
        if [ "$LB_OPEN" -ge "$OVERLOAD_THRESHOLD" ]; then
            echo "     ⚠️  LOOPBACK OVERLOAD ($LB_OPEN >= $OVERLOAD_THRESHOLD) — consider a focused rework sprint"
        fi
    fi
fi

# 3. Master pending
echo ""
echo "  👤 MASTER PENDING"
if [ -f "$DB" ]; then
    MASTER_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='TODO' AND assignee IN ('MASTER','GEMINI');" 2>/dev/null)
    echo "  $MASTER_COUNT tasks total"
fi

# 4. Git state
echo ""
echo "  🌿 GIT STATE"
if cd "$DIR" 2>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || git rev-list --count main..HEAD 2>/dev/null || echo "?")
    LAST_COMMIT=$(git log -1 --pretty=format:"%s" 2>/dev/null | cut -c1-60)
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "  Branch: $BRANCH  |  $AHEAD commit(s) ahead of main  |  $UNCOMMITTED uncommitted file(s)"
    echo "  Last:   $LAST_COMMIT"
else
    echo "  ❌ Not a git repository at $DIR — git state unavailable"
fi

# 5. File health
echo ""
echo "  📁 FILE HEALTH"
check_file() {
    local file="$1" warn="$2" crit="$3" label="$4"
    if [ -f "$DIR/$file" ]; then
        lines=$(wc -l < "$DIR/$file" | tr -d ' ')
        if [ "$lines" -ge "$crit" ]; then
            echo "  ❌ $label: ${lines} lines (CRITICAL)"
        elif [ "$lines" -ge "$warn" ]; then
            echo "  ⚠️  $label: ${lines} lines (approaching limit)"
        else
            echo "  ✅ $label: ${lines} lines"
        fi
    fi
}
check_file "%%PROJECT_MEMORY_FILE%%" 500 700 "PROJECT_MEMORY"
check_file "%%RULES_FILE%%" 250 350 "RULES"
check_file "%%LESSONS_FILE%%" 100 150 "LESSONS"
check_file "LEARNING_LOG.md" 150 250 "LEARNING_LOG"

# 6. Coherence
if [ -f "$DIR/coherence_check.sh" ]; then
    COHERENCE=$(bash "$DIR/coherence_check.sh" --quiet 2>&1; echo $?)
    COHERENCE_EXIT="${COHERENCE##*$'\n'}"
    echo ""
    if [ "$COHERENCE_EXIT" = "1" ]; then
        echo "  ⚠️  COHERENCE: stale references found — run bash coherence_check.sh --fix"
    else
        echo "  ✅ COHERENCE: clean"
    fi
fi

# 7. @-import verification — catch silent missing files
echo ""
echo "  📎 @-IMPORT VERIFICATION"
IMPORT_OK=1
for claude_md in "$DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; do
    if [ -f "$claude_md" ]; then
        claude_dir="$(dirname "$claude_md")"
        while IFS= read -r imported; do
            target="$claude_dir/$imported"
            if [ ! -f "$target" ]; then
                echo "  ❌ MISSING: $imported (referenced in $(basename "$claude_md") but file does not exist at $target)"
                IMPORT_OK=0
            fi
        done < <(sed -n 's/^@//p' "$claude_md" 2>/dev/null)
    fi
done
if [ "$IMPORT_OK" -eq 1 ]; then
    echo "  ✅ All @-imports resolve to existing files"
fi

# 8. Knowledge health
echo ""
echo "  📚 KNOWLEDGE HEALTH"
KNOWLEDGE_DEBT=false

# Check unpromoted universal patterns in project LESSONS files
UNPROMOTED=0
for f in "$DIR"/LESSONS*.md; do
    if [ -f "$f" ]; then
        COUNT=$(grep -cE "^\|[^|]+\|[^|]+\| No( —| \|)" "$f" 2>/dev/null)
        COUNT="${COUNT:-0}"
        # Validate numeric
        if [[ "$COUNT" =~ ^[0-9]+$ ]]; then
            UNPROMOTED=$((UNPROMOTED + COUNT))
        fi
    fi
done

if [ "$UNPROMOTED" -gt 0 ]; then
    echo "  ⚠️  $UNPROMOTED universal pattern(s) awaiting promotion to LESSONS_UNIVERSAL.md"
    KNOWLEDGE_DEBT=true
else
    echo "  ✅ No unpromoted patterns"
fi

# Check LESSONS_UNIVERSAL.md freshness
UNIVERSAL="$HOME/.claude/LESSONS_UNIVERSAL.md"
if [ -f "$UNIVERSAL" ]; then
    LAST_MOD=$(stat -f %m "$UNIVERSAL" 2>/dev/null || stat -c %Y "$UNIVERSAL" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    if [[ "$LAST_MOD" =~ ^[0-9]+$ ]] && [ "$LAST_MOD" -gt 0 ]; then
        DAYS_STALE=$(( (NOW - LAST_MOD) / 86400 ))
        if [ "$DAYS_STALE" -gt 7 ]; then
            echo "  ⚠️  LESSONS_UNIVERSAL.md not updated in ${DAYS_STALE} days"
            KNOWLEDGE_DEBT=true
        fi
    fi
else
    echo "  ⚠️  ~/.claude/LESSONS_UNIVERSAL.md not found"
    KNOWLEDGE_DEBT=true
fi

# Check framework version drift (if project has frameworks/)
if [ -d "$DIR/frameworks" ] && [ -d "$HOME/.claude/frameworks" ]; then
    STALE_FW=0
    for fw in "$DIR/frameworks/"*.md; do
        [ -f "$fw" ] || continue
        BASENAME=$(basename "$fw")
        CANONICAL="$HOME/.claude/frameworks/$BASENAME"
        if [ -f "$CANONICAL" ]; then
            LOCAL_VER=$(grep -m1 "^version:" "$fw" 2>/dev/null | awk '{print $2}')
            CANON_VER=$(grep -m1 "^version:" "$CANONICAL" 2>/dev/null | awk '{print $2}')
            if [ "$LOCAL_VER" != "$CANON_VER" ] && [ -n "$CANON_VER" ]; then
                STALE_FW=$((STALE_FW + 1))
            fi
        fi
    done
    if [ "$STALE_FW" -gt 0 ]; then
        echo "  ⚠️  $STALE_FW framework(s) outdated — run: bash ~/.claude/frameworks/sync.sh ."
        KNOWLEDGE_DEBT=true
    else
        echo "  ✅ Frameworks in sync"
    fi
fi

if [ "$KNOWLEDGE_DEBT" = true ]; then
    echo "  📚 Address knowledge debt at session end — run: bash ~/.claude/harvest.sh"
fi

# 9. Session signal
echo ""
echo "  🚦 SESSION SIGNAL"

SIGNAL="GREEN"
SIGNAL_REASONS=""

# Missing @-imports → YELLOW (lesson infrastructure broken, but doesn't block code work)
if [ "$IMPORT_OK" -eq 0 ]; then
    SIGNAL="YELLOW"
    SIGNAL_REASONS="${SIGNAL_REASONS}  ⚠️  Missing @-import file(s) — lesson/rules infrastructure incomplete\n"
fi

if [ -f "$DB" ]; then
    # Next Claude task
    NEXT_CLAUDE_TASK=$(sqlite3 "$DB" "
        SELECT id || '|' || phase || '|' || title || '|' || COALESCE(blocked_by,'')
        FROM tasks
        WHERE status='TODO' AND assignee='CLAUDE'
          AND queue != 'INBOX'
        ORDER BY phase, sort_order
        LIMIT 1;
    " 2>/dev/null)

    NEXT_TASK_ID=$(echo "$NEXT_CLAUDE_TASK" | cut -d'|' -f1)
    NEXT_TASK_PHASE=$(echo "$NEXT_CLAUDE_TASK" | cut -d'|' -f2)
    NEXT_TASK_TITLE=$(echo "$NEXT_CLAUDE_TASK" | cut -d'|' -f3)
    NEXT_TASK_BLOCKED=$(echo "$NEXT_CLAUDE_TASK" | cut -d'|' -f4)

    # Check prior phases incomplete
    if [ -n "$NEXT_TASK_PHASE" ]; then
        INCOMPLETE_PRIOR=$(sqlite3 "$DB" "
            SELECT phase || ' (' || COUNT(*) || ' task(s))'
            FROM tasks
            WHERE status NOT IN ('DONE','SKIP')
            AND COALESCE(track,'forward')='forward'
            AND phase < '$NEXT_TASK_PHASE'
            AND queue != 'INBOX'
            GROUP BY phase;
        " 2>/dev/null)
        if [ -n "$INCOMPLETE_PRIOR" ]; then
            SIGNAL="RED"
            SIGNAL_REASONS="${SIGNAL_REASONS}  ❌ Prior phase(s) have incomplete tasks: $INCOMPLETE_PRIOR\n"
        fi
    fi

    # Check phase gates
    if [ -n "$NEXT_TASK_PHASE" ]; then
        PHASES_BEFORE=$(sqlite3 "$DB" "
            SELECT DISTINCT phase FROM tasks WHERE phase < '$NEXT_TASK_PHASE' AND queue != 'INBOX' ORDER BY phase;
        " 2>/dev/null)
        for PB in $PHASES_BEFORE; do
            GATE_PASSED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM phase_gates WHERE phase='$PB';" 2>/dev/null)
            if [ "$GATE_PASSED" -eq 0 ]; then
                SIGNAL="RED"
                SIGNAL_REASONS="${SIGNAL_REASONS}  ❌ $PB phase gate not passed\n"
            fi
        done
    fi

    # Check Master/Gemini blockers
    BLOCKER_COUNT=$(sqlite3 "$DB" "
        SELECT COUNT(DISTINCT b.id)
        FROM tasks t JOIN tasks b ON t.blocked_by = b.id
        WHERE t.status != 'DONE' AND t.assignee = 'CLAUDE'
          AND b.status != 'DONE' AND b.assignee IN ('MASTER', 'GEMINI');
    " 2>/dev/null)

    if [ "$BLOCKER_COUNT" -gt 0 ]; then
        UNBLOCKED_CLAUDE=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM tasks
            WHERE status='TODO' AND assignee='CLAUDE'
            AND (blocked_by IS NULL OR blocked_by = ''
                 OR blocked_by IN (SELECT id FROM tasks WHERE status IN ('DONE','SKIP'))
                 OR blocked_by NOT IN (SELECT id FROM tasks));
        " 2>/dev/null)
        if [ "$UNBLOCKED_CLAUDE" -eq 0 ]; then
            SIGNAL="RED"
            SIGNAL_REASONS="${SIGNAL_REASONS}  ❌ All Claude tasks are blocked by Master/Gemini\n"
        elif [ "$SIGNAL" != "RED" ]; then
            SIGNAL="YELLOW"
            SIGNAL_REASONS="${SIGNAL_REASONS}  ⚠️  Some Master/Gemini blockers exist but unblocked Claude tasks available\n"
        fi
    fi

    # Rule: S1 gate-critical loopback unresolved + unacknowledged → YELLOW
    CB_UNACKED=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tasks t
        LEFT JOIN loopback_acks la ON t.id = la.loopback_id
        WHERE t.track='loopback' AND t.severity=1 AND t.gate_critical=1
          AND t.status NOT IN ('DONE','SKIP')
          AND la.loopback_id IS NULL;
    " 2>/dev/null)
    if [ "$CB_UNACKED" -gt 0 ]; then
        [ "$SIGNAL" != "RED" ] && SIGNAL="YELLOW"
        SIGNAL_REASONS="${SIGNAL_REASONS}  ⚠️  $CB_UNACKED S1 circuit breaker(s) unacknowledged\n"
    fi

    # Check next task blocked — only cross-phase blockers trigger YELLOW
    if [ -n "$NEXT_TASK_BLOCKED" ]; then
        BLOCKER_INFO=$(sqlite3 "$DB" "SELECT status || '|' || phase FROM tasks WHERE id='$NEXT_TASK_BLOCKED';" 2>/dev/null)
        BLOCKER_STATUS=$(echo "$BLOCKER_INFO" | cut -d'|' -f1)
        BLOCKER_PHASE=$(echo "$BLOCKER_INFO" | cut -d'|' -f2)
        if [ "$BLOCKER_STATUS" != "DONE" ] && [ "$BLOCKER_STATUS" != "SKIP" ]; then
            if [ -z "$BLOCKER_STATUS" ]; then
                # Stale reference — nonexistent task
                [ "$SIGNAL" != "RED" ] && SIGNAL="YELLOW"
                SIGNAL_REASONS="${SIGNAL_REASONS}  ⚠️  Next task $NEXT_TASK_ID has stale blocked_by: $NEXT_TASK_BLOCKED (not found)\n"
            elif [ "$BLOCKER_PHASE" != "$NEXT_TASK_PHASE" ]; then
                # Cross-phase blocker — real problem
                [ "$SIGNAL" != "RED" ] && SIGNAL="YELLOW"
                SIGNAL_REASONS="${SIGNAL_REASONS}  ⚠️  Next task $NEXT_TASK_ID is blocked by $NEXT_TASK_BLOCKED (cross-phase)\n"
            fi
            # Same-phase blockers are advisory — don't change signal
        fi
    fi

    # Output signal
    if [ "$SIGNAL" = "GREEN" ]; then
        echo "  ✅ GREEN — All clear"
        [ -n "$NEXT_TASK_ID" ] && echo "  📋 Next: $NEXT_TASK_ID — $NEXT_TASK_TITLE"
    elif [ "$SIGNAL" = "YELLOW" ]; then
        echo "  ⚠️  YELLOW — Attention needed"
        echo -e "$SIGNAL_REASONS"
        [ -n "$NEXT_TASK_ID" ] && echo "  📋 Next: $NEXT_TASK_ID — $NEXT_TASK_TITLE"
    else
        echo "  🛑 RED — Hard stop"
        echo -e "$SIGNAL_REASONS"
        [ -n "$NEXT_TASK_ID" ] && echo "  📋 Next (blocked): $NEXT_TASK_ID — $NEXT_TASK_TITLE"
    fi

    GATES=$(sqlite3 "$DB" "SELECT GROUP_CONCAT(phase, ', ') FROM phase_gates;" 2>/dev/null)
    [ -n "$GATES" ] && echo "  🚧 Gates passed: $GATES" || echo "  🚧 Gates passed: None yet"
    echo "  ⏸️  Milestone gates: active (run 'check <id>' — may return CONFIRM requiring Master approval)"
fi

echo ""
echo "  ⚡ Quick start: bash db_queries.sh resume"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
