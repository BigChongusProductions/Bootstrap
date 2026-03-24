#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap_project.sh — Create a new project with the full workflow engine
#
# Usage:
#   bash bootstrap_project.sh "Project Name" /path/to/project
#
# What it creates:
#   - CLAUDE.md (project entry point with @imports)
#   - PROJECT_RULES.md (from template, with placeholders)
#   - LESSONS.md, PROJECT_MEMORY.md, LEARNING_LOG.md, NEXT_SESSION.md
#   - project.db (SQLite with full schema)
#   - db_queries.sh, session_briefing.sh, coherence_check.sh, coherence_registry.sh
#   - milestone_check.sh, build_summarizer.sh, work.sh, fix.sh
#   - generate_board.py
#   - .gitignore, .claude/settings.local.json
#   - Git repo with master + dev branches
#   - (optional) Framework files from ~/.claude/frameworks/ (via @imports)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Platform-aware in-place sed (macOS uses -i '', GNU/Linux uses -i)
sedi() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

if [ $# -lt 2 ]; then
    echo "Usage: bash bootstrap_project.sh \"Project Name\" /path/to/project [--lifecycle full|quick] [--non-interactive]"
    echo "  e.g. bash bootstrap_project.sh \"My Project\" ~/Desktop/MyProject --lifecycle full"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_PATH="$2"

# Parse flags
LIFECYCLE_MODE=""
NON_INTERACTIVE=false
shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --lifecycle) LIFECYCLE_MODE="${2:-full}"; shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        *) shift ;;
    esac
done

# If no lifecycle mode specified, ask interactively (unless --non-interactive)
if [ -z "$LIFECYCLE_MODE" ]; then
    if [ "$NON_INTERACTIVE" = true ]; then
        LIFECYCLE_MODE="full"
    else
        echo ""
        echo "  Choose project lifecycle mode:"
        echo ""
        echo "  [1] FULL (9-phase) — ENVISION → RESEARCH → DECIDE → SPECIFY → PLAN → BUILD → VALIDATE → SHIP → EVOLVE"
        echo "      Best for: serious projects, new domains, unfamiliar stacks"
        echo ""
        echo "  [2] QUICK (3-phase) — PLAN → BUILD → SHIP"
        echo "      Best for: small projects, known stack, clear scope already decided"
        echo ""
        read -p "  Enter 1 or 2 (default: 1): " LIFECYCLE_CHOICE
        case "$LIFECYCLE_CHOICE" in
            2) LIFECYCLE_MODE="quick" ;;
            *) LIFECYCLE_MODE="full" ;;
        esac
    fi
fi
PROJECT_NAME_UPPER=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
PROJECT_NAME_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
DB_NAME="${PROJECT_NAME_LOWER}.db"
MAC_USER=$(whoami)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🚀 Bootstrapping: $PROJECT_NAME"
echo "║  📁 Location: $PROJECT_PATH"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Create project directory ─────────────────────────────────────────────────
if [ -d "$PROJECT_PATH" ]; then
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "⚠️  Directory already exists: $PROJECT_PATH (continuing — non-interactive mode)"
    else
        echo "⚠️  Directory already exists: $PROJECT_PATH"
        read -p "   Continue anyway? (y/N) " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
else
    mkdir -p "$PROJECT_PATH"
    echo "✅ Created directory: $PROJECT_PATH"
fi

cd "$PROJECT_PATH"

# ── 1. CLAUDE.md (project entry point) ──────────────────────────────────────
cat > CLAUDE.md << 'CLAUDEEOF'
# %%PROJECT_NAME%% — Project Entry Point
> Cognitive rules auto-loaded from ~/.claude/CLAUDE.md (global).
> Core frameworks loaded via @imports below. Extended rules in refs/rules-extended.md (on demand).

@~/.claude/frameworks/session-protocol.md
@~/.claude/frameworks/phase-gates.md
@~/.claude/frameworks/correction-protocol.md
@~/.claude/frameworks/delegation.md
@%%PROJECT_NAME_UPPER%%_RULES.md
@AGENT_DELEGATION.md
@LESSONS_%%PROJECT_NAME_UPPER%%.md
CLAUDEEOF

sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" CLAUDE.md
sedi "s/%%PROJECT_NAME_UPPER%%/$PROJECT_NAME_UPPER/g" CLAUDE.md
echo "✅ CLAUDE.md"

# ── 2. PROJECT_RULES.md (from template) ─────────────────────────────────────
TEMPLATE="$HOME/.claude/dev-framework/templates/rules/RULES_TEMPLATE.md"
RULES_FILE="${PROJECT_NAME_UPPER}_RULES.md"

if [ -f "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$RULES_FILE"
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" "$RULES_FILE"
    sedi "s|%%PROJECT_NAME_UPPER%%|$PROJECT_NAME_UPPER|g" "$RULES_FILE"
    sedi "s|%%PROJECT_PATH%%|$PROJECT_PATH|g" "$RULES_FILE"
    sedi "s|%%MAIN_BRANCH%%|main|g" "$RULES_FILE"
    sedi "s|%%DEV_BRANCH%%|dev|g" "$RULES_FILE"
    echo "✅ $RULES_FILE (from template — customize %%PLACEHOLDERS%%)"
else
    echo "⚠️  Template not found at $TEMPLATE"
    echo "   Creating minimal rules file — copy template later for full version"
    cat > "$RULES_FILE" << RULESEOF
# $PROJECT_NAME — Project Rules
> Auto-imported by CLAUDE.md. Full template available at ~/.claude/templates/PROJECT_RULES_TEMPLATE.md
> Copy it here and customize the %%PLACEHOLDERS%% for the full workflow engine.

## Project North Star
> **TODO: Define your project's north star here.**

## Tech Stack & Environment
TODO: Define your tech stack here.

## MCP Servers & Plugins Available
TODO: List your MCP servers here.
RULESEOF
    echo "✅ $RULES_FILE (minimal — install template for full version)"
fi

# ── 3. LESSONS file ──────────────────────────────────────────────────────────
LESSONS_FILE="LESSONS_${PROJECT_NAME_UPPER}.md"
cat > "$LESSONS_FILE" << 'EOF'
# Lessons Learned
> Updated after every correction from Master. Reviewed at session start.
> **Rule:** After ANY correction, add a row to the Corrections Log before continuing work.

## Corrections Log
| Date | What Went Wrong | Pattern | Prevention Rule |
|------|----------------|---------|-----------------|
| | | | |

## Insights
> Things discovered during development that aren't corrections but are worth remembering.

| Date | Insight | Context |
|------|---------|---------|
| | | |

## Universal Patterns
> Patterns that appear across multiple projects. Candidates for promotion into CLAUDE.md.

| Date | Pattern | Promoted to CLAUDE.md? |
|------|---------|----------------------|
| | | |
EOF
echo "✅ $LESSONS_FILE"

# ── 4. PROJECT_MEMORY.md ────────────────────────────────────────────────────
cat > "${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md" << MEMEOF
# $PROJECT_NAME — Project Memory
> Living document. Updated when architecture changes. Read selectively per task.

## §1 — Project Overview
**What:** TODO
**Why:** TODO
**Status:** Phase 1 — Setup

## §2 — Section Lookup
| Need to know about... | Read section |
|----------------------|-------------|
| Project overview | §1 |
| Architecture | §3 |
| File structure | §4 |

## §3 — Architecture
TODO: Document your architecture here.

## §4 — File Structure
TODO: Document key files here.
MEMEOF
echo "✅ ${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md"

# ── 5. LEARNING_LOG.md ──────────────────────────────────────────────────────
cat > LEARNING_LOG.md << 'EOF'
# Learning Log
> Track new tools, techniques, MCPs, plugins, skills, and workflows as they're configured.

| Date | What | Category | Notes |
|------|------|----------|-------|
| | | | |
EOF
echo "✅ LEARNING_LOG.md"

# ── 6. NEXT_SESSION.md ──────────────────────────────────────────────────────
cat > NEXT_SESSION.md << NSEOF
# Next Session Handoff
> Auto-generated by save-session skill. Pre-computed startup context.

## Last Session
- **Date:** $(date '+%b %d, %Y')
- **Type:** Setup
- **Summary:** Project bootstrapped. Ready for phase planning.

## Phase Gates Passed
None yet.

## Next Tasks
Define phases and populate the task database.

## Blockers
None.

## Overrides (active)
None.
NSEOF
echo "✅ NEXT_SESSION.md"

# ── 7. SQLite Database ──────────────────────────────────────────────────────
if command -v sqlite3 &> /dev/null; then
    sqlite3 "$DB_NAME" << 'SQLEOF'
-- Schema aligned with Python CLI (dbq/db.py) — do not modify independently
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    queue TEXT DEFAULT 'A',
    assignee TEXT DEFAULT 'CLAUDE',
    title TEXT NOT NULL,
    priority TEXT DEFAULT 'P1',
    status TEXT DEFAULT 'TODO',
    blocked_by TEXT,
    details TEXT,
    completed_on TEXT,
    sort_order INTEGER DEFAULT 0,
    -- Loopback tracking
    track TEXT DEFAULT 'forward',
    origin_phase TEXT,
    discovered_in TEXT,
    severity INTEGER,
    gate_critical INTEGER DEFAULT 0,
    loopback_reason TEXT,
    -- Delegation metadata
    tier TEXT,
    skill TEXT,
    needs_browser INTEGER DEFAULT 0,
    -- Falsification protocol
    researched INTEGER DEFAULT 0,
    breakage_tested INTEGER DEFAULT 0,
    -- Additional columns (Python CLI compat)
    notes TEXT,
    research_notes TEXT,
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

CREATE TABLE IF NOT EXISTS assumptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    assumption TEXT NOT NULL,
    verify_cmd TEXT,
    verified INTEGER DEFAULT 0,
    verified_on TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS db_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT,
    git_sha TEXT,
    task_summary TEXT,
    phase_gates TEXT,
    stats TEXT,
    phase TEXT,
    snapshot_at TEXT DEFAULT (datetime('now')),
    task_count INTEGER,
    file_paths TEXT,
    created_at TEXT DEFAULT (datetime('now'))
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

-- Bootstrap session log
INSERT INTO sessions (session_type, summary)
VALUES ('Setup', 'Project bootstrapped with workflow engine');
SQLEOF
    # Seed phases based on lifecycle mode
    if [ "$LIFECYCLE_MODE" = "full" ]; then
        sqlite3 "$DB_NAME" << 'PHASEEOF'
-- Full 9-phase lifecycle: ENVISION → RESEARCH → DECIDE → SPECIFY → PLAN → BUILD → VALIDATE → SHIP → EVOLVE
INSERT INTO tasks (id, phase, assignee, title, status, sort_order, tier)
VALUES
  ('ENV-01', 'P1-ENVISION', 'MASTER', 'Complete ENVISION spec — pitch, audience, done criteria, exclusions', 'TODO', 10, 'master'),
  ('RES-01', 'P2-RESEARCH', 'MASTER', 'Complete RESEARCH spec — prior art, options, constraints, open questions', 'TODO', 20, 'master'),
  ('DEC-01', 'P3-DECIDE', 'MASTER', 'Complete DECISIONS spec — lock stack, scope, architecture', 'TODO', 30, 'master'),
  ('SPE-01', 'P4-SPECIFY', 'CLAUDE', 'Generate requirements.md from ENVISION + RESEARCH + DECISIONS', 'TODO', 40, 'opus'),
  ('SPE-02', 'P4-SPECIFY', 'MASTER', 'Review and annotate requirements.md', 'TODO', 41, 'master'),
  ('SPE-03', 'P4-SPECIFY', 'CLAUDE', 'Generate design.md from requirements.md', 'TODO', 42, 'opus'),
  ('SPE-04', 'P4-SPECIFY', 'MASTER', 'Review and annotate design.md', 'TODO', 43, 'master'),
  ('PLN-01', 'P5-PLAN', 'CLAUDE', 'Generate task breakdown from design.md', 'TODO', 50, 'opus');
PHASEEOF
        # Seed phase_gates for all 9 phases
        for PH in P1-ENVISION P2-RESEARCH P3-DECIDE P4-SPECIFY P5-PLAN P6-BUILD P7-VALIDATE P8-SHIP P9-EVOLVE; do
            sqlite3 "$DB_NAME" "INSERT OR IGNORE INTO phase_gates (phase) VALUES ('$PH');"
        done
        echo "✅ Seeded 9-phase lifecycle (P1-ENVISION through P9-EVOLVE)"
    else
        sqlite3 "$DB_NAME" << 'PHASEEOF'
-- Quick 3-phase lifecycle: PLAN → BUILD → SHIP
INSERT INTO tasks (id, phase, assignee, title, status, sort_order, tier)
VALUES
  ('PLN-01', 'P1-PLAN', 'CLAUDE', 'Generate task breakdown from project specs', 'TODO', 10, 'opus');
PHASEEOF
        # Seed phase_gates for all 3 phases
        for PH in P1-PLAN P2-BUILD P3-SHIP; do
            sqlite3 "$DB_NAME" "INSERT OR IGNORE INTO phase_gates (phase) VALUES ('$PH');"
        done
        echo "✅ Seeded 3-phase lifecycle (P1-PLAN → P2-BUILD → P3-SHIP)"
    fi

    echo "✅ $DB_NAME (SQLite — 8 tables, lifecycle: $LIFECYCLE_MODE)"
else
    echo "⚠️  sqlite3 not found — install it or create DB manually"
fi

# ── 7b. specs/ directory ─────────────────────────────────────────────────────
SPEC_TEMPLATES="$HOME/.claude/templates/specs"
if [ "$LIFECYCLE_MODE" = "full" ] && [ -d "$SPEC_TEMPLATES" ]; then
    mkdir -p specs
    for spec in "$SPEC_TEMPLATES"/*.template.md; do
        [ -f "$spec" ] || continue
        BASENAME=$(basename "$spec" .template.md)
        TARGET="specs/${BASENAME}.md"
        cp "$spec" "$TARGET"
        sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" "$TARGET"
    done
    echo "✅ specs/ directory (ENVISION, RESEARCH, DECISIONS, requirements, design)"
elif [ "$LIFECYCLE_MODE" = "quick" ]; then
    mkdir -p specs
    # Quick mode only gets requirements + design
    for spec in requirements design; do
        if [ -f "$SPEC_TEMPLATES/${spec}.template.md" ]; then
            cp "$SPEC_TEMPLATES/${spec}.template.md" "specs/${spec}.md"
            sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" "specs/${spec}.md"
        fi
    done
    echo "✅ specs/ directory (requirements, design — quick mode)"
fi

# ── 8. db_queries.sh (from template) ─────────────────────────────────────────
# Check both template locations — dev-framework has the complete set
SCRIPT_TEMPLATES="$HOME/.claude/templates/scripts"
if [ -d "$HOME/.claude/dev-framework/templates/scripts" ]; then
    SCRIPT_TEMPLATES="$HOME/.claude/dev-framework/templates/scripts"
fi
if [ -f "$SCRIPT_TEMPLATES/db_queries.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/db_queries.template.sh" db_queries.sh
    # Parameterize — handle both old (%%DB_NAME%%) and new (%%PROJECT_DB%%) placeholders
    LESSONS_FILE="LESSONS_${PROJECT_NAME_UPPER}.md"
    DB_NAME_BASE="${DB_NAME%.db}"
    sedi "s/%%DB_NAME%%/$DB_NAME/g" db_queries.sh
    sedi "s/%%PROJECT_DB%%/$DB_NAME/g" db_queries.sh
    sedi "s/%%DB_NAME_BASE%%/$DB_NAME_BASE/g" db_queries.sh
    sedi "s/%%LESSONS_FILE%%/$LESSONS_FILE/g" db_queries.sh
    sedi "s/%%DELEGATION_FILE%%/AGENT_DELEGATION.md/g" db_queries.sh
    sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" db_queries.sh
    # Compute phase list from lifecycle mode
    if [ "$LIFECYCLE_MODE" = "full" ]; then
        PHASES="P1-ENVISION P2-RESEARCH P3-DECIDE P4-SPECIFY P5-PLAN P6-BUILD P7-VALIDATE P8-SHIP P9-EVOLVE"
    else
        PHASES="P1-PLAN P2-BUILD P3-SHIP"
    fi
    sedi "s/%%PHASES%%/$PHASES/g" db_queries.sh
    chmod +x db_queries.sh
    echo "✅ db_queries.sh (53 commands — from template)"
else
    echo "⚠️  Template not found at $SCRIPT_TEMPLATES/db_queries.template.sh"
    echo "   Creating minimal db_queries.sh — update later"
    cat > db_queries.sh << 'DBEOF_FALLBACK'
#!/usr/bin/env bash
DB="$(dirname "$0")/%%DB_NAME%%"
echo "Minimal db_queries.sh — copy full version from ~/.claude/templates/scripts/"
DBEOF_FALLBACK
    sedi "s/%%DB_NAME%%/$DB_NAME/g" db_queries.sh
    chmod +x db_queries.sh
fi


# ── 9. session_briefing.sh (from template) ───────────────────────────────────
if [ -f "$SCRIPT_TEMPLATES/session_briefing.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/session_briefing.template.sh" session_briefing.sh
    MEMORY_FILE="${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md"
    sedi "s/%%DB_NAME%%/$DB_NAME/g" session_briefing.sh
    sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" session_briefing.sh
    sedi "s/%%MEMORY_FILE%%/$MEMORY_FILE/g" session_briefing.sh
    sedi "s/%%RULES_FILE%%/${PROJECT_NAME_UPPER}_RULES.md/g" session_briefing.sh
    sedi "s/%%LESSONS_FILE%%/$LESSONS_FILE/g" session_briefing.sh
    # Patch @-import resolution: expand ~ in paths before checking existence
    # The template has: target="$claude_dir/$imported" which fails for @~/.claude/... paths
    python3 -c "
import sys
old = 'target=\"\$claude_dir/\$imported\"'
new = '''# Expand ~ to \$HOME for absolute @imports (e.g., @~/.claude/frameworks/...)
            expanded=\"\${imported/#\\\\~/\$HOME}\"
            if [[ \"\$expanded\" == /* ]]; then
                target=\"\$expanded\"
            else
                target=\"\$claude_dir/\$expanded\"
            fi'''
with open('session_briefing.sh') as f:
    content = f.read()
if old in content:
    content = content.replace(old, new, 1)
    with open('session_briefing.sh', 'w') as f:
        f.write(content)
" 2>/dev/null || true
    chmod +x session_briefing.sh
    echo "✅ session_briefing.sh (from template + @import path fix)"
else
    echo "⚠️  session_briefing.template.sh not found — skipping"
fi

# ── 10. coherence_check.sh (from template) ──────────────────────────────────
if [ -f "$SCRIPT_TEMPLATES/coherence_check.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/coherence_check.template.sh" coherence_check.sh
    sedi "s/%%LESSONS_FILE%%/$LESSONS_FILE/g" coherence_check.sh
    chmod +x coherence_check.sh
    echo "✅ coherence_check.sh (from template)"
else
    echo "⚠️  coherence_check.template.sh not found — skipping"
fi

# ── 11. coherence_registry.sh (from template — empty starter) ───────────────
if [ -f "$SCRIPT_TEMPLATES/coherence_registry.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/coherence_registry.template.sh" coherence_registry.sh
    chmod +x coherence_registry.sh
    echo "✅ coherence_registry.sh (empty starter — add entries as architecture evolves)"
else
    echo "⚠️  coherence_registry.template.sh not found — skipping"
fi

# ── 12. milestone_check.sh (from template) ──────────────────────────────────
if [ -f "$SCRIPT_TEMPLATES/milestone_check.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/milestone_check.template.sh" milestone_check.sh
    sedi "s/%%DB_NAME%%/$DB_NAME/g" milestone_check.sh
    sedi "s/%%MAIN_BRANCH%%/main/g" milestone_check.sh
    sedi "s/%%DEV_BRANCH%%/dev/g" milestone_check.sh
    chmod +x milestone_check.sh
    echo "✅ milestone_check.sh (from template)"
else
    echo "⚠️  milestone_check.template.sh not found — skipping"
fi

# ── 13. build_summarizer.sh (from template or stub) ──────────────────────────
BUILD_TEMPLATE="$SCRIPT_TEMPLATES/build_summarizer.template.sh"
if [ -f "$BUILD_TEMPLATE" ]; then
    cp "$BUILD_TEMPLATE" build_summarizer.sh
    sedi "s/%%DB_NAME%%/$DB_NAME/g" build_summarizer.sh
    sedi "s/%%PROJECT_NAME%%/$PROJECT_NAME/g" build_summarizer.sh
    chmod +x build_summarizer.sh
    echo "✅ build_summarizer.sh (from template — customize build commands)"
else
    cat > build_summarizer.sh << 'BUILDEOF'
#!/usr/bin/env bash
# Build Summarizer — customize this for your project's build system
# Usage: bash build_summarizer.sh [build|test|clean]
MODE="${1:-build}"
echo "── Build Summarizer ($MODE) ──"
echo "⚠️  Stub. Copy full version from ~/.claude/dev-framework/templates/scripts/"
BUILDEOF
    chmod +x build_summarizer.sh
    echo "✅ build_summarizer.sh (stub — template not found)"
fi

# ── 14. generate_board.py ───────────────────────────────────────────────────
cat > generate_board.py << BOARDEOF
#!/usr/bin/env python3
"""Generate TASK_BOARD.md from the SQLite database."""
import sqlite3, os, sys
from datetime import datetime

DIR = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(DIR, "$DB_NAME")
OUTPUT = os.path.join(DIR, "TASK_BOARD.md")

if not os.path.exists(DB):
    print(f"❌ {DB} not found")
    sys.exit(1)

conn = sqlite3.connect(DB)
c = conn.cursor()

lines = [f"# $PROJECT_NAME — Task Board", f"> Generated: {datetime.now().strftime('%b %d, %Y %H:%M')}", ""]

# Get phases
c.execute("SELECT DISTINCT phase FROM tasks ORDER BY phase")
phases = [r[0] for r in c.fetchall()]

for phase in phases:
    c.execute("SELECT COUNT(*) FROM tasks WHERE phase=?", (phase,))
    total = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM tasks WHERE phase=? AND status='DONE'", (phase,))
    done = c.fetchone()[0]

    # Check gate
    c.execute("SELECT gated_on FROM phase_gates WHERE phase=?", (phase,))
    gate = c.fetchone()
    gate_str = f" — GATED {gate[0]}" if gate else ""

    lines.append(f"## {phase} ({done}/{total} done{gate_str})")
    lines.append("")
    lines.append("| ID | P | Assignee | Status | Title | Blocked By |")
    lines.append("|---|---|----------|--------|-------|------------|")

    c.execute("""
        SELECT id, priority, assignee, status, title, COALESCE(blocked_by, '')
        FROM tasks WHERE phase=?
        ORDER BY sort_order, id
    """, (phase,))
    for row in c.fetchall():
        status_icon = {"DONE": "✅", "TODO": "⬜", "IN_PROGRESS": "🔵", "SKIP": "⏭️"}.get(row[3], row[3])
        lines.append(f"| {row[0]} | {row[1]} | {row[2]} | {status_icon} | {row[4]} | {row[5]} |")
    lines.append("")

conn.close()

with open(OUTPUT, "w") as f:
    f.write("\\n".join(lines))
print(f"✅ TASK_BOARD.md generated ({len(phases)} phases)")
BOARDEOF
chmod +x generate_board.py
echo "✅ generate_board.py"

# ── 15. work.sh ─────────────────────────────────────────────────────────────
cat > work.sh << WORKEOF
#!/usr/bin/env bash
# $PROJECT_NAME — WORK MODE

set -euo pipefail

PROJECT="$PROJECT_PATH"
DB="\$PROJECT/$DB_NAME"

BOLD="\033[1m" GREEN="\033[32m" YELLOW="\033[33m" CYAN="\033[36m" RED="\033[31m" RESET="\033[0m"

clear
echo ""
echo -e "\${BOLD}╔══════════════════════════════════════════════════════════════╗\${RESET}"
echo -e "\${BOLD}║  🎯  $PROJECT_NAME — WORK MODE                              ║\${RESET}"
echo -e "\${BOLD}║  \$(date '+%A, %B %d, %Y')                                  ║\${RESET}"
echo -e "\${BOLD}╚══════════════════════════════════════════════════════════════╝\${RESET}"
echo ""

# Check DB
if [ ! -f "\$DB" ]; then
    echo -e "\${RED}❌ Database not found\${RESET}"
    exit 1
fi

# Backup DB
cp "\$DB" "\$DB.bak"
echo -e "\${GREEN}✅\${RESET} Database backed up"

# Clean journal
[ -f "\$DB-journal" ] && rm -f "\$DB-journal" && echo -e "\${YELLOW}⚠️\${RESET}  Cleaned stale journal"

# Git state
cd "\$PROJECT"
BRANCH=\$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "\$BRANCH" != "dev" ]; then
    echo -e "\${RED}⚠️  On branch '\$BRANCH' — should be 'dev'\${RESET}"
else
    echo -e "\${GREEN}✅\${RESET} Branch: dev"
fi

# Show tasks
echo ""
bash "\$PROJECT/db_queries.sh" next
bash "\$PROJECT/db_queries.sh" master

# Signal check
BRIEFING_OUTPUT=\$(bash "\$PROJECT/session_briefing.sh" 2>&1)
if echo "\$BRIEFING_OUTPUT" | grep -q "🛑 RED"; then
    echo -e "\${RED}\${BOLD}  🛑 SESSION SIGNAL: RED — BLOCKERS\${RESET}"
    echo "\$BRIEFING_OUTPUT" | grep "❌" | sed 's/^/  /'
    echo ""
    read -p "  Launch Claude Code anyway? (y/N) " OVERRIDE
    [[ ! "\$OVERRIDE" =~ ^[Yy]$ ]] && exit 0
elif echo "\$BRIEFING_OUTPUT" | grep -q "YELLOW"; then
    echo -e "\${YELLOW}⚠️  Signal: YELLOW\${RESET}"
else
    echo -e "\${GREEN}✅ Signal: GREEN\${RESET}"
fi

# Launch
echo ""
echo -e "\${CYAN}Launching Claude Code (opusplan)...\${RESET}"
osascript -e "
tell application \"Terminal\"
    activate
    do script \"cd $PROJECT_PATH && claude --model opusplan --dangerously-skip-permissions\"
end tell
"
echo -e "\${GREEN}✅ Claude Code launched\${RESET}"
WORKEOF
chmod +x work.sh
echo "✅ work.sh"

# ── 16. fix.sh ──────────────────────────────────────────────────────────────
cat > fix.sh << FIXEOF
#!/usr/bin/env bash
# $PROJECT_NAME — FIX MODE

set -euo pipefail

PROJECT="$PROJECT_PATH"
PROBLEM="\${1:-}"

BOLD="\033[1m" GREEN="\033[32m" YELLOW="\033[33m" CYAN="\033[36m" RED="\033[31m" RESET="\033[0m"

clear
echo -e "\${RED}\${BOLD}╔══════════════════════════════════════════════════════════════╗\${RESET}"
echo -e "\${RED}\${BOLD}║  🔧  $PROJECT_NAME — FIX MODE                                ║\${RESET}"
echo -e "\${RED}\${BOLD}╚══════════════════════════════════════════════════════════════╝\${RESET}"
echo ""

cd "\$PROJECT"
BRANCH=\$(git branch --show-current 2>/dev/null || echo "unknown")
echo "  Branch: \$BRANCH"
git log --oneline -5 2>/dev/null | sed 's/^/  /'
echo ""

if [ -n "\$PROBLEM" ]; then
    INITIAL_PROMPT="Fix this issue: \$PROBLEM"
    osascript -e "
    tell application \"Terminal\"
        activate
        do script \"cd $PROJECT_PATH && claude --model claude-opus-4-6 --dangerously-skip-permissions -p \\\"\$INITIAL_PROMPT\\\"\"
    end tell
    "
else
    osascript -e '
    tell application "Terminal"
        activate
        do script "cd $PROJECT_PATH && claude --model claude-opus-4-6 --dangerously-skip-permissions"
    end tell
    '
fi
echo -e "\${GREEN}✅ Opus launched\${RESET}"
FIXEOF
chmod +x fix.sh
echo "✅ fix.sh"

# ── 17. .gitignore ──────────────────────────────────────────────────────────
cat > .gitignore << 'GITEOF'
# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
.env.local
.env*.local

# Database backups
*.db.bak
*.db-journal
*.db-wal
*.db-shm

# Node (if applicable)
node_modules/
.next/
dist/
build/

# Python (if applicable)
__pycache__/
*.pyc
.venv/
venv/
GITEOF
echo "✅ .gitignore"

# ── 18. .claude/settings.local.json ─────────────────────────────────────────
mkdir -p .claude
cat > .claude/settings.local.json << 'SETTEOF'
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
SETTEOF
echo "✅ .claude/settings.local.json"

# ── 19. Knowledge harvest (forces promotion before new project) ──────────────
if [ -f "$HOME/.claude/harvest.sh" ]; then
    echo ""
    echo "→ Running knowledge harvest before new project setup..."
    bash "$HOME/.claude/harvest.sh" 2>&1 | grep -E "📚|✅|━━━" || true
fi

# ── 20. Verify frameworks exist (CLAUDE.md @imports point to ~/.claude/frameworks/) ──
CANONICAL_FW="$HOME/.claude/frameworks"
if [ -d "$CANONICAL_FW" ]; then
    FW_COUNT=$(ls "$CANONICAL_FW"/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ Frameworks verified: $FW_COUNT files at ~/.claude/frameworks/ (loaded via @import in CLAUDE.md)"
else
    echo "⚠️  No frameworks at $CANONICAL_FW — CLAUDE.md @imports will fail. Run /setup-templates first."
fi

# ── 21. refs/ directory (progressive disclosure) ────────────────────────────
mkdir -p refs
cat > refs/README.md << 'REFSEOF'
# Reference Sub-files

This directory contains detailed reference material loaded on demand.
The main RULES file stays compact; details live here.

Add new refs as sections in RULES outgrow ~50 lines.
Replace the section with: `> 📂 Moved to refs/<name>.md — read when [trigger].`
REFSEOF
echo "✅ refs/ directory"

# ── 22. AGENT_DELEGATION.md ─────────────────────────────────────────────────
DELEG_TEMPLATE="$HOME/.claude/dev-framework/templates/rules/AGENT_DELEGATION_TEMPLATE.md"
if [ -f "$DELEG_TEMPLATE" ]; then
    cp "$DELEG_TEMPLATE" AGENT_DELEGATION.md
    sedi "s|%%RULES_FILE%%|${PROJECT_NAME_UPPER}_RULES.md|g" AGENT_DELEGATION.md
    echo "✅ AGENT_DELEGATION.md (from template)"
else
    echo "⚠️  Template not found at $DELEG_TEMPLATE — creating minimal version"
    cat > AGENT_DELEGATION.md << DELEGEOF
# Agent Delegation Logic
> Authoritative reference for model selection, sub-agent spawning, and failure escalation.
> 📂 Tier definitions and delegation rules in \`~/.claude/frameworks/delegation.md\`.

## §7 — Delegation Map
<!-- DELEGATION-START -->
No tasks defined yet. Populate the DB and run: \`bash db_queries.sh delegation-md\`
<!-- DELEGATION-END -->
DELEGEOF
    echo "✅ AGENT_DELEGATION.md (minimal)"
fi

# ── 23. Deploy hook scripts (.claude/hooks/) ─────────────────────────────────
HOOK_TEMPLATES="$HOME/.claude/dev-framework/templates/hooks"
if [ -d "$HOOK_TEMPLATES" ]; then
    mkdir -p .claude/hooks
    HOOK_COUNT=0
    for hook_template in "$HOOK_TEMPLATES"/*.template.sh "$HOOK_TEMPLATES"/*.template.conf; do
        [ -f "$hook_template" ] || continue
        BASENAME=$(basename "$hook_template" | sed 's/\.template\././')
        cp "$hook_template" ".claude/hooks/$BASENAME"
        # Replace common placeholders
        sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" ".claude/hooks/$BASENAME"
        sedi "s|%%PROJECT_DB%%|$DB_NAME|g" ".claude/hooks/$BASENAME"
        sedi "s|%%LESSONS_FILE%%|$LESSONS_FILE|g" ".claude/hooks/$BASENAME"
        sedi "s|%%PROJECT_RULES_FILE%%|${PROJECT_NAME_UPPER}_RULES.md|g" ".claude/hooks/$BASENAME"
        sedi "s|%%OWN_DB_PATTERNS%%|${DB_NAME}|g" ".claude/hooks/$BASENAME"
        sedi "s|%%LESSON_LOG_COMMAND%%|bash db_queries.sh log-lesson|g" ".claude/hooks/$BASENAME"
        sedi "s|%%AGENT_NAMES%%||g" ".claude/hooks/$BASENAME"
        chmod +x ".claude/hooks/$BASENAME" 2>/dev/null || true
        HOOK_COUNT=$((HOOK_COUNT + 1))
    done
    echo "✅ .claude/hooks/ ($HOOK_COUNT hook scripts deployed)"
else
    echo "⚠️  Hook templates not found at $HOOK_TEMPLATES — skipping"
fi

# ── 24. Deploy .claude/settings.json (hook wiring) ───────────────────────────
SETTINGS_TEMPLATE="$HOME/.claude/dev-framework/templates/settings/settings.template.json"
if [ -f "$SETTINGS_TEMPLATE" ]; then
    cp "$SETTINGS_TEMPLATE" .claude/settings.json
    # Fill permission allow with common workflow commands
    ALLOW_LIST="Bash(bash db_queries.sh *),Bash(bash session_briefing.sh*),Bash(bash coherence_check.sh*),Bash(bash milestone_check.sh*),Bash(bash build_summarizer.sh*),Bash(python3 generate_board.py*),Bash(sqlite3 $DB_NAME*),Bash(git *)"
    sedi "s|%%PERMISSION_ALLOW%%|$ALLOW_LIST|g" .claude/settings.json
    echo "✅ .claude/settings.json (hook wiring: 7 event hooks configured)"
else
    echo "⚠️  Settings template not found — hooks will not be wired"
fi

# ── 25. Deploy .claude/agents/ (implementer + worker) ────────────────────────
AGENT_TEMPLATES="$HOME/.claude/dev-framework/templates/agents"
if [ -d "$AGENT_TEMPLATES" ]; then
    mkdir -p .claude/agents/implementer .claude/agents/worker
    if [ -f "$AGENT_TEMPLATES/implementer.template.md" ]; then
        cp "$AGENT_TEMPLATES/implementer.template.md" .claude/agents/implementer/implementer.md
        sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" .claude/agents/implementer/implementer.md
        sedi "s|%%TECH_STACK_HOOKS%%||g" .claude/agents/implementer/implementer.md
        sedi "s|%%TECH_STANDARDS%%|Follow the project's code standards in ${PROJECT_NAME_UPPER}_RULES.md.|g" .claude/agents/implementer/implementer.md
        sedi "s|%%BUILD_COMMAND%%|bash build_summarizer.sh build|g" .claude/agents/implementer/implementer.md
    fi
    if [ -f "$AGENT_TEMPLATES/worker.template.md" ]; then
        cp "$AGENT_TEMPLATES/worker.template.md" .claude/agents/worker/worker.md
        sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" .claude/agents/worker/worker.md
        sedi "s|%%TECH_STANDARDS_BRIEF%%|Follow the project's code standards in ${PROJECT_NAME_UPPER}_RULES.md.|g" .claude/agents/worker/worker.md
    fi
    echo "✅ .claude/agents/ (implementer + worker configs)"
else
    echo "⚠️  Agent templates not found — skipping"
fi

# ── 26. Deploy missing workflow scripts ───────────────────────────────────────
# save_session.sh
if [ -f "$SCRIPT_TEMPLATES/save_session.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/save_session.template.sh" save_session.sh
    sedi "s|%%DB_NAME%%|$DB_NAME|g" save_session.sh
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" save_session.sh
    sedi "s|%%LESSONS_FILE%%|$LESSONS_FILE|g" save_session.sh
    sedi "s|%%MEMORY_FILE%%|${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md|g" save_session.sh
    chmod +x save_session.sh
    echo "✅ save_session.sh (from template)"
fi

# shared_signal.sh
if [ -f "$SCRIPT_TEMPLATES/shared_signal.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/shared_signal.template.sh" shared_signal.sh
    sedi "s|%%DB_NAME%%|$DB_NAME|g" shared_signal.sh
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" shared_signal.sh
    chmod +x shared_signal.sh
    echo "✅ shared_signal.sh (from template)"
fi

# harvest.sh
if [ -f "$SCRIPT_TEMPLATES/harvest.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/harvest.template.sh" harvest.sh
    sedi "s|%%LESSONS_FILE%%|$LESSONS_FILE|g" harvest.sh
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" harvest.sh
    chmod +x harvest.sh
    echo "✅ harvest.sh (from template)"
fi

# db_queries_legacy.sh (bash fallback for systems without Python 3.10+)
if [ -f "$SCRIPT_TEMPLATES/db_queries_legacy.template.sh" ]; then
    cp "$SCRIPT_TEMPLATES/db_queries_legacy.template.sh" db_queries_legacy.sh
    sedi "s|%%DB_NAME%%|$DB_NAME|g" db_queries_legacy.sh
    sedi "s|%%DB_NAME_BASE%%|${DB_NAME%.db}|g" db_queries_legacy.sh
    sedi "s|%%LESSONS_FILE%%|$LESSONS_FILE|g" db_queries_legacy.sh
    sedi "s|%%DELEGATION_FILE%%|AGENT_DELEGATION.md|g" db_queries_legacy.sh
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" db_queries_legacy.sh
    chmod +x db_queries_legacy.sh
    echo "✅ db_queries_legacy.sh (bash fallback — 135KB)"
fi

# ── 27. Universal placeholder sweep ──────────────────────────────────────────
# Some templates use %%PROJECT_DB%% instead of %%DB_NAME%%, and other variants.
# Do a final sweep across all deployed .sh files to catch any remaining placeholders.
for script in *.sh .claude/hooks/*.sh .claude/hooks/*.conf; do
    [ -f "$script" ] || continue
    sedi "s|%%PROJECT_DB%%|$DB_NAME|g" "$script" 2>/dev/null || true
    sedi "s|%%DB_NAME%%|$DB_NAME|g" "$script" 2>/dev/null || true
    sedi "s|%%PROJECT_NAME%%|$PROJECT_NAME|g" "$script" 2>/dev/null || true
    sedi "s|%%LESSONS_FILE%%|$LESSONS_FILE|g" "$script" 2>/dev/null || true
    sedi "s|%%RULES_FILE%%|${PROJECT_NAME_UPPER}_RULES.md|g" "$script" 2>/dev/null || true
    sedi "s|%%MEMORY_FILE%%|${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md|g" "$script" 2>/dev/null || true
    sedi "s|%%MAIN_BRANCH%%|main|g" "$script" 2>/dev/null || true
    sedi "s|%%DEV_BRANCH%%|dev|g" "$script" 2>/dev/null || true
    sedi "s|%%PROJECT_DB_NAME%%|${DB_NAME%.db}|g" "$script" 2>/dev/null || true
    sedi "s|%%PROJECT_PATH%%|$PROJECT_PATH|g" "$script" 2>/dev/null || true
    sedi "s|%%PROJECT_MEMORY_FILE%%|${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md|g" "$script" 2>/dev/null || true
done

# Generate phase-specific SQL fragments for legacy script
if [ -f db_queries_legacy.sh ]; then
    if [ "$LIFECYCLE_MODE" = "full" ]; then
        PHASE_CASE="'P1-ENVISION') echo 1;; 'P2-RESEARCH') echo 2;; 'P3-DECIDE') echo 3;; 'P4-SPECIFY') echo 4;; 'P5-PLAN') echo 5;; 'P6-BUILD') echo 6;; 'P7-VALIDATE') echo 7;; 'P8-SHIP') echo 8;; 'P9-EVOLVE') echo 9;;"
        PHASE_CASE_SQL="WHEN 'P1-ENVISION' THEN 1 WHEN 'P2-RESEARCH' THEN 2 WHEN 'P3-DECIDE' THEN 3 WHEN 'P4-SPECIFY' THEN 4 WHEN 'P5-PLAN' THEN 5 WHEN 'P6-BUILD' THEN 6 WHEN 'P7-VALIDATE' THEN 7 WHEN 'P8-SHIP' THEN 8 WHEN 'P9-EVOLVE' THEN 9"
        PHASE_IN_SQL="'P1-ENVISION','P2-RESEARCH','P3-DECIDE','P4-SPECIFY','P5-PLAN','P6-BUILD','P7-VALIDATE','P8-SHIP','P9-EVOLVE'"
    else
        PHASE_CASE="'P1-PLAN') echo 1;; 'P2-BUILD') echo 2;; 'P3-SHIP') echo 3;;"
        PHASE_CASE_SQL="WHEN 'P1-PLAN' THEN 1 WHEN 'P2-BUILD' THEN 2 WHEN 'P3-SHIP' THEN 3"
        PHASE_IN_SQL="'P1-PLAN','P2-BUILD','P3-SHIP'"
    fi
    sedi "s|%%PHASE_CASE_ORDINALS%%|$PHASE_CASE|g" db_queries_legacy.sh 2>/dev/null || true
    sedi "s|%%PHASE_CASE_SQL%%|$PHASE_CASE_SQL|g" db_queries_legacy.sh 2>/dev/null || true
    sedi "s|%%PHASE_IN_SQL%%|$PHASE_IN_SQL|g" db_queries_legacy.sh 2>/dev/null || true
fi
REMAINING=$(grep -rn '%%[A-Z_]*%%' *.sh .claude/hooks/*.sh .claude/hooks/*.conf 2>/dev/null | grep -v '^#\|comment\|^.*:#' | grep -c '%%' || echo 0)
echo "✅ Placeholder sweep complete ($REMAINING remaining in scripts)"

# ── 28. Git init ─────────────────────────────────────────────────────────────
if [ ! -d ".git" ]; then
    git init -q
    git add -A
    git commit -q -m "Bootstrap: $PROJECT_NAME project with workflow engine"
    git branch dev 2>/dev/null || true
    git checkout -q dev
    echo "✅ Git initialized (master + dev branches, on dev)"
else
    echo "⚠️  Git already initialized — skipping"
fi

# ── Placeholder inventory ─────────────────────────────────────────────────────
echo ""
echo "── Remaining %%PLACEHOLDERS%% to customize ──"
PLACEHOLDER_COUNT=$(grep -rn '%%' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    echo "  $RULES_FILE has $PLACEHOLDER_COUNT placeholders:"
    grep -oE '%%[A-Z_]+%%' "$RULES_FILE" 2>/dev/null | sort -u | while read -r ph; do
        case "$ph" in
            %%PROJECT_NORTH_STAR%%)   echo "    $ph — your project's vision statement" ;;
            %%TECH_STACK%%)           echo "    $ph — tech stack table (framework, language, tools)" ;;
            %%COMMIT_FORMAT%%)        echo "    $ph — git commit message format" ;;
            %%BUILD_TEST_INSTRUCTIONS%%) echo "    $ph — npm/cargo/make commands for build+test" ;;
            %%OUTPUT_VERIFICATION_GATE%%) echo "    $ph — what to verify after each task" ;;
            %%PROJECT_STOP_RULES%%)   echo "    $ph — project-specific STOP conditions" ;;
            %%PROJECT_MEMORY_FILE%%)  echo "    $ph — auto: ${PROJECT_NAME_UPPER}_PROJECT_MEMORY.md" ;;
            %%FIRST_PHASE%%)          echo "    $ph — first phase name (e.g., P1-PLAN)" ;;
            *)                        echo "    $ph" ;;
        esac
    done
else
    echo "  ✅ No placeholders remaining"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ $PROJECT_NAME — Bootstrap Complete!"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Next steps:                                                 ║"
echo "║  1. Edit ${RULES_FILE} — customize %%PLACEHOLDERS%%         ║"
echo "║  2. Define phases & tasks (SQL inserts into $DB_NAME)       ║"
echo "║  3. Open Cowork, mount this folder, brainstorm your phases  ║"
echo "║  4. Run: bash work.sh  to start your first session          ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
