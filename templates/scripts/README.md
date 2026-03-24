# Project Bootstrap Script Templates

This directory contains templatized scripts for the bootstrap engine. Each script has been parameterized with `%%PLACEHOLDER%%` tokens to enable reuse across different projects.

## Files Included

### Core Task Management
- **db_queries.template.sh** — Thin Python CLI dispatcher with bash fallback
  - Delegates to the `dbq` Python package; falls back to `db_queries_legacy.template.sh` if Python 3.10+ is unavailable
  - Placeholders: `%%PROJECT_DB%%`, `%%PROJECT_NAME%%`, `%%LESSONS_FILE%%`, `%%PHASES%%`

- **db_queries_legacy.template.sh** (2,846 lines) — Legacy bash SQLite query helpers
  - Commands: phase, blockers, gate, check, done, quick, inbox, loopback, loopback-stats, etc.
  - Placeholders: `%%PROJECT_DB%%`, `%%PROJECT_DB_NAME%%`, `%%LESSONS_FILE%%`, `%%PROJECT_NAME%%`, `%%PHASE_CASE_ORDINALS%%`, `%%PHASE_CASE_SQL%%`, `%%PHASE_IN_SQL%%`

- **session_briefing.template.sh** (427 lines) — Compact session status digest at startup
  - Shows phase status, next tasks, blockers, git state, file health, coherence
  - Placeholders: `%%PROJECT_DB%%`, `%%PROJECT_NAME%%`, `%%LESSONS_FILE%%`, `%%PROJECT_MEMORY_FILE%%`, `%%RULES_FILE%%`

### Quality Gates
- **milestone_check.template.sh** (168 lines) — Merge-readiness gate for dev→main
  - Checks: task completion, git branch, working tree, coherence, build + tests
  - Placeholders: `%%PROJECT_DB%%`

- **coherence_check.template.sh** (98 lines) — Scan markdown files for stale references
  - Runs: --quiet (warnings only) or --fix (replacement hints)
  - Placeholders: `%%LESSONS_FILE%%`

- **coherence_registry.template.sh** (36 lines) — Define deprecated pattern mappings
  - Three parallel arrays: DEPRECATED_PATTERNS, CANONICAL_LABELS, INTRODUCED_ON
  - No placeholders required (project-specific entries added after setup)

### Build & Deploy
- **build_summarizer.template.sh** (20 lines) — Stub for project-specific build system
  - Examples provided for Next.js, Xcode, Python pytest
  - No placeholders (customize for your project)

### Workflow Launchers
- **work.template.sh** (69 lines) — Launch Claude Code in work mode
  - Checks DB health, git state, session signal before launching
  - Placeholders: `%%PROJECT_PATH%%`, `%%PROJECT_DB%%`, `%%PROJECT_NAME%%`

- **fix.template.sh** (39 lines) — Launch Claude Code in fix mode
  - Optional initial prompt parameter: `bash fix.sh "Fix this issue: ..."`
  - Placeholders: `%%PROJECT_PATH%%`, `%%PROJECT_NAME%%`

- **harvest.template.sh** (61 lines) — Scan project lessons for promotion candidates
  - Identifies unpromoted patterns in %%LESSONS_FILE%% not yet in LESSONS_UNIVERSAL.md
  - Placeholders: `%%LESSONS_FILE%%`

## Placeholder Reference

| Placeholder | Meaning | Example |
|---|---|---|
| `%%PROJECT_DB%%` | SQLite database filename | `my_project.db` |
| `%%PROJECT_DB_NAME%%` | DB name without extension | `my_project` |
| `%%PROJECT_NAME%%` | Human-readable project name | `My Project` |
| `%%PROJECT_PATH%%` | Absolute path to project root | `/Users/user/Desktop/MyProject` |
| `%%LESSONS_FILE%%` | Project lessons markdown file | `LESSONS_MYPROJECT.md` |
| `%%PROJECT_MEMORY_FILE%%` | Project memory markdown file | `MY_PROJECT_PROJECT_MEMORY.md` |
| `%%RULES_FILE%%` | Project rules markdown file | `MY_PROJECT_RULES.md` |
| `%%PHASE_CASE_ORDINALS%%` | Bash case arms for phase_ordinal() | `P1-FOO) echo 0 ;; P2-BAR) echo 1 ;;` |
| `%%PHASE_CASE_SQL%%` | SQL CASE arms for priority scoring | `WHEN 'P1-FOO' THEN 0 WHEN 'P2-BAR' THEN 1` |
| `%%PHASE_IN_SQL%%` | SQL IN list for health check | `'P1-FOO', 'P2-BAR', 'P3-BAZ'` |

## Setup Instructions

1. **Copy templates to your project:**
   ```bash
   cp ~/.claude/dev-framework/templates/scripts/*.template.sh /path/to/project/
   ```

2. **For each template, apply placeholders using sed:**
   ```bash
   sed \
     -e 's/%%PROJECT_DB%%/my_project.db/g' \
     -e 's/%%PROJECT_DB_NAME%%/my_project/g' \
     -e 's/%%PROJECT_NAME%%/My Project/g' \
     -e 's|%%PROJECT_PATH%%|/Users/user/Desktop/MyProject|g' \
     -e 's/%%LESSONS_FILE%%/LESSONS_MYPROJECT.md/g' \
     -e 's/%%PROJECT_MEMORY_FILE%%/MY_PROJECT_MEMORY.md/g' \
     -e 's/%%RULES_FILE%%/MY_PROJECT_RULES.md/g' \
     -e "s/%%PHASE_CASE_ORDINALS%%/P1-FOO) echo 0 ;; P2-BAR) echo 1 ;; P3-BAZ) echo 2 ;;/" \
     -e "s/%%PHASE_CASE_SQL%%/WHEN 'P1-FOO' THEN 0 WHEN 'P2-BAR' THEN 1 WHEN 'P3-BAZ' THEN 2/" \
     -e "s/%%PHASE_IN_SQL%%/'P1-FOO', 'P2-BAR', 'P3-BAZ'/" \
     db_queries_legacy.template.sh > db_queries_legacy.sh
   ```

3. **Phase placeholders in db_queries.sh** — All three are replaced by the sed command above:
   - `%%PHASE_CASE_ORDINALS%%` — bash case arms in `phase_ordinal()` function
   - `%%PHASE_CASE_SQL%%` — SQL CASE arms in the priority-sort query
   - `%%PHASE_IN_SQL%%` — SQL IN list in the health check query

4. **Make scripts executable:**
   ```bash
   chmod +x *.sh
   ```

5. **Customize build_summarizer.sh** for your build system (Next.js, iOS, Python, etc.)

## Notes

- **AGENT_DELEGATION.md** remains as-is across projects (not templatized)
- **build_summarizer.sh** is a stub template — customize for your specific build system
- Phase names in **db_queries.sh** appear in 3 locations — all handled by the 3 `%%PHASE_*%%` placeholders via sed
- All templates include inline documentation in header comments

## Version History

- Origin: Extracted and generalized (March 2026)
- All replacements applied via: sed with %%PLACEHOLDER%% tokens
- Total lines across all templates: 3,764
- Largest file: db_queries_legacy.template.sh (2,846 lines)
