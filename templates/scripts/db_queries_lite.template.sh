#!/usr/bin/env bash
# =============================================================================
# db_queries.sh — Lite Engine (restricted command set)
#
# Delegates to the Python `dbq` package for Lite-tier commands only.
# Full-tier commands (delegation, falsification, snapshots, loopbacks, etc.)
# are rejected with a helpful message.
#
# Placeholders replaced at activation time:
#   %%PROJECT_DB%%      — SQLite database filename (e.g. my_project.db)
#   %%PROJECT_NAME%%    — Human-readable project name
#   %%LESSONS_FILE%%    — Lessons/corrections log filename
#   %%PHASES%%          — Space-separated phase list (e.g. P1-PLAN P2-BUILD)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set DB path for the Python package if not already overridden
export DB_OVERRIDE="${DB_OVERRIDE:-${SCRIPT_DIR}/%%PROJECT_DB%%}"

# Set project config via env vars (populated at activation time)
export DBQ_PROJECT_NAME="${DBQ_PROJECT_NAME:-%%PROJECT_NAME%%}"
export DBQ_LESSONS_FILE="${DBQ_LESSONS_FILE:-%%LESSONS_FILE%%}"
export DBQ_PHASES="${DBQ_PHASES:-%%PHASES%%}"

# ── Lite command whitelist ──
LITE_COMMANDS="init-db|health|verify|quick|done|next|status|start|skip|task|add-task|log-lesson|log|board|phase|gate|gate-pass"
CMD="${1:-}"

if [ -z "$CMD" ]; then
    echo "db_queries.sh — Lite Engine for %%PROJECT_NAME%%"
    echo ""
    echo "Commands:"
    echo "  Database:   init-db  health  verify"
    echo "  View:       next  status  phase  board  task <id>"
    echo "  Lifecycle:  start <id>  done <id>  skip <id> [reason]"
    echo "  Create:     quick \"title\" [phase] [tag]"
    echo "              add-task <id> <phase> \"title\" <tier>"
    echo "  Gates:      gate  gate-pass <phase>"
    echo "  Logging:    log-lesson \"what\" \"pattern\" \"rule\""
    echo "              log \"type\" \"summary\""
    echo ""
    echo "For delegation, falsification, snapshots, loopbacks:"
    echo "  Upgrade to Full engine — see ~/.claude/dev-framework/README.md"
    exit 0
fi

if ! echo "$CMD" | grep -qE "^($LITE_COMMANDS)$"; then
    echo "Command '$CMD' is not available in Lite tier."
    echo ""
    echo "Available: init-db health verify next status phase board task"
    echo "           start done skip quick add-task gate gate-pass log-lesson log"
    echo ""
    echo "To upgrade: see ~/.claude/dev-framework/README.md"
    exit 1
fi

# ── Python dispatch ──
if ! python3 -c "import sys; assert sys.version_info >= (3, 10)" 2>/dev/null; then
    if [ -f "${SCRIPT_DIR}/db_queries_legacy.sh" ]; then
        source "${SCRIPT_DIR}/db_queries_legacy.sh" "$@"
        exit
    fi
    echo "Error: Python 3.10+ required. Install it or provide db_queries_legacy.sh."
    exit 1
fi

DBQ_LIB="${HOME}/.claude/dev-framework/templates/scripts"
export PYTHONPATH="${DBQ_LIB}${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m dbq "$@"
