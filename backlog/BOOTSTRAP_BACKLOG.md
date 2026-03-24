# Bootstrap Backlog
> Lessons escalated to improve the bootstrap process itself.
> Items here represent concrete changes to templates, frameworks, or plugin skills.
> Managed by: `db_queries.sh escalate`, `harvest.sh --bootstrap`, `apply_backlog.sh`
>
> **Categories:** `[template]` file bug/gap · `[framework]` doc update · `[process]` skill/procedure gap · `[system]` new capability
> **Priority:** P0 = broken · P1 = degraded · P2 = improvement · P3 = nice-to-have
> **Item format:** `### BP-NNN [category] Title` followed by Escalated, Source, Priority, Affected, Description, Change, Gotcha (optional), Status

## Pending

<!-- PENDING-ANCHOR — new items are appended above this line -->

## Applied

### BP-001 [template] Audit all template scripts for grep -P usage — APPLIED 2026-03-24
- Fixed `grep -oP` → `sed -n 's/^@//p'` in `session_briefing.template.sh:214`
- No other `grep -P` usage found in templates (all others use `-q`, `-E`, or `-oE`)
- Also fixed in old templates dir (`~/.claude/templates/scripts/`) and MasterDashboard live copy
- RomaniaBattles and TeaTimer need fixing in their respective sessions

### BP-006 [template] init-db cannot run without pre-existing DB file — APPLIED 2026-03-24
- `db_queries_legacy.template.sh` checked `[ ! -f "$DB" ]` before case dispatch, blocking init-db
- Fix: moved sqlite3 check before file check, special-cased init-db to bypass file check
- init-db now auto-creates the DB file via `touch`

### BP-007 [template] Auto-migration block crashes on empty DB — APPLIED 2026-03-24
- `ALTER TABLE tasks ADD COLUMN` ran on every invocation, failed on empty DBs (no tasks table)
- Fix: guarded migration block with `sqlite_master` check for tasks table existence

### BP-008 [process] Engine-deployment-guide contradicted SKILL.md — APPLIED 2026-03-24
- Guide said `health` auto-creates schema (wrong) — fixed to document `init-db` first
- Guide imported all frameworks via `@` in CLAUDE.md (stale) — fixed to load-on-demand pattern

### BP-009 [template] CLAUDE_TEMPLATE.md @-imported LESSONS file causing unbounded context — APPLIED 2026-03-24
- Removed `@%%LESSONS_FILE%%` from CLAUDE_TEMPLATE.md
- LESSONS is now read on-demand, not loaded at startup
- Session-start hook should inject recent lessons instead

### BP-010 [process] Marketplace SKILL.md was stale vs v0.5.0 cache — APPLIED 2026-03-24
- plugin.json said v0.5.0 but SKILL.md was missing backlog check and gotcha seeding
- Synced marketplace from cache

### BP-002 [template] Verification scripts must check their own prerequisites — APPLIED 2026-03-24
- Added sqlite3, git, and DB file prerequisite checks to `milestone_check.template.sh` (before line 42)
- All checks fail loudly with exit code 2 and actionable error messages
- Removed `2>/dev/null || echo 0` from milestone_check's sqlite3 SELECT queries (5 instances) — queries now fail loudly if DB is malformed
- `coherence_check.template.sh` already had registry check (line 37-40) — no change needed
- `build_summarizer.template.sh` is a stub — no change needed

### BP-003 [template] Template scripts should verify runtime values not assume conventions — APPLIED 2026-03-24
- Added `git rev-parse --verify` checks for `dev` and `main` branches in `milestone_check.template.sh`
- Branch existence verified before `rev-list --count main..dev` and `diff main..dev` comparisons
- Missing branch now reports a gate failure instead of crashing or silently returning 0
- `session_briefing.template.sh` already handles git gracefully (checks `git rev-parse --is-inside-work-tree` first, reads branch dynamically) — no change needed

### BP-004 [template] Remove error suppression from critical DB paths in templates — APPLIED 2026-03-24
- Audited all 173 `2>/dev/null` instances in `db_queries_legacy.template.sh`
- Removed 32 suppressions from critical DML-gating paths:
  - `done` command: task existence, status, phase, track, severity, origin, and loopback metadata reads + DELETE
  - `skip` command: task existence, track read + DELETE
  - `triage` command: queue read, phase read, sort_order read
  - `pre-task` command: task info, track, severity, gate_critical, blocker status reads
  - `unblock`/`ack` commands: blocker and track reads
  - `confirm`/`assume`/`researched`/`breakage-tested`: task existence checks
  - `quick-add`/`lb`: duplicate ID collision checks
- Kept 141 suppressions on: idempotent DDL (migrations), display-only SELECTs, health probes, git/grep utilities
- Zero `2>/dev/null` remains on any INSERT/UPDATE/DELETE statement

### BP-012 [template] Consolidate pre-edit hooks into 1 — APPLIED 2026-03-24
- Created `pre-edit-check.template.sh` merging delegation-reminder + protect-architecture
- Single process, single JSON parse, single timeout
- Architecture protection takes priority (short-circuits before delegation check)
- Updated `settings.template.json` to reference single hook
- Old hooks kept with SUPERSEDED comment (protect-architecture still used by lite tier)

### BP-014 [template] Progressive disclosure for RULES — APPLIED 2026-03-24
- Split RULES_TEMPLATE.md from 491 lines → 285 lines (core, 10 sections)
- Created RULES_EXTENDED_TEMPLATE.md (216 lines, 13 sections) for on-demand loading
- Extended sections: blocker detection, code standards, tracking files, coherence, .gitignore audit, milestone merge gate, deployment modes, visual verification, cowork gates, context management, MCP servers
- Core RULES has pointer: "load refs/rules-extended.md when needed"
- Updated session_briefing.template.sh threshold from 400/500 to 250/350
- Test suite generates refs/rules-extended.md and validates zero unfilled placeholders

### BP-011 [system] Replace sed templating with bootstrap_fill.py — APPLIED 2026-03-24
- db_queries.sh rewrite to Python CLI (dbq) completed
- sed templating replacement done as part of broader rewrite

### BP-013 [process] Spec validation for discovery→activate handoff — APPLIED 2026-03-24
- Validation added for FRAMEWORK.md required fields before activation

### BP-005 [process] Bootstrap should audit extracted frameworks for project-specific contamination — APPLIED 2026-03-24
- Found 16 instances of "RomaniaBattles" across 9 framework template files
- All in `extracted_from:` frontmatter and changelog entries (provenance metadata)
- Replaced with "production project" to genericize templates
- No hardcoded paths, no other project names (MasterDashboard, TeaTimer, Drawstring, chonkius) found
- Verified zero contamination across entire `templates/` directory post-fix

<!-- APPLIED-ANCHOR — completed items are moved above this line -->
