#!/usr/bin/env bash
# =============================================================================
# db_queries.sh — Thin Python CLI dispatcher with bash fallback
#
# Delegates to the Python `dbq` package for all db_queries commands.
# If Python 3.10+ is not available, falls back to the legacy bash
# implementation (db_queries_legacy.sh) automatically.
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

# Require Python 3.10+; fall back to legacy bash implementation if unavailable
if ! python3 -c "import sys; assert sys.version_info >= (3, 10)" 2>/dev/null; then
    source "${SCRIPT_DIR}/db_queries_legacy.sh" "$@"
    exit
fi

# The dbq package lives in the dev-framework templates
DBQ_LIB="${HOME}/.claude/dev-framework/templates/scripts"
export PYTHONPATH="${DBQ_LIB}${PYTHONPATH:+:${PYTHONPATH}}"

exec python3 -m dbq "$@"
