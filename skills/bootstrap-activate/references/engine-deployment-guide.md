# Engine Deployment Guide

Complete step-by-step guide for deploying the entire Master Dashboard infrastructure to a new project.

---

## Step 0 — Scaffold refs/ Directory

Create the progressive disclosure directory with starter reference files. See `refs-scaffolding.md` for full details.

```bash
mkdir -p refs/
```

**Always create:**
- `refs/README.md` — "Progressive disclosure directory. Claude reads files here on demand."
- `refs/tool-inventory.md` — master tool/MCP/plugin catalog (auto-populate from environment)
- `refs/gotchas-workflow.md` — empty template (populated by gotcha generation over time)

**Conditionally create (based on FRAMEWORK.md):**
- `refs/skills-catalog.md` — if project uses custom skills
- `refs/gotchas-frontend.md` — if project has UI components
- `refs/planned-integrations.md` — if DECISIONS.md has deferred integrations
- `refs/visual-verification.md` — if visual verification is active

---

## Step 1 — Copy Template Scripts (13 files)

Copy all 13 scripts from `~/.claude/dev-framework/templates/` to `[project_path]/`:

| Script | Purpose | What to Replace |
|--------|---------|-----------------|
| `db_queries.sh` | Task DB CRUD + phase logic | DB_PATH, phase_ordinal(), project paths |
| `session_briefing.sh` | Session startup diagnostic | DB_PATH, project paths |
| `milestone_check.sh` | Phase gate + merge readiness | DB_PATH, build command |
| `coherence_check.sh` | Stale reference detection | Skip patterns (%%SKIP_PATTERN_1/2%%) |
| `coherence_registry.sh` | Deprecated phrase registry | None (seed with comments, populate over time) |
| `build_summarizer.sh` | On-demand build/test runner | Build command, DB_PATH |
| `work.sh` | Daily driver script | PROJECT variable, open commands |
| `fix.sh` | Opus-mode interactive script | PROJECT variable, open commands |
| `harvest.sh` | Lesson promotion scanner | PROJECT variable, LESSONS file |
| `generate_board.sh` | Markdown task board generator | DB_PATH |

**After copying each, run verification:**
```bash
bash db_queries.sh health         # Should initialize DB if missing
bash session_briefing.sh          # Should show current phase (initial: "None")
```

---

## Step 2 — Create and Initialize Database

Use `init-db` to create the schema. `health` only checks tables — it does NOT create them.

```bash
bash db_queries.sh init-db           # Creates DB file + all tables
bash db_queries.sh health            # Verify schema is correct
```

**Verify schema creation:**
```bash
sqlite3 [project_path]/[project].db ".tables"
# Should output: assumptions  decisions  loopback_acks  milestone_confirmations
#               phase_gates  sessions  snapshots  tasks
```

**Tables auto-created:**
- `tasks` — Task ID, Phase, Title, Assignee, Tier, Blocked By, Status, Priority
- `phase_gates` — Phase name, Pass/Fail status, Timestamp, Notes
- `milestone_confirmations` — Task ID, Confirmed by, Timestamp, Reason
- `loopback_acks` — Loopback task ID, Acknowledged by, Timestamp, Reason
- `assumptions` — Task ID, Assumption text, Verified (bool), Verification command
- `decisions` — Decision ID, Description, Options, Choice, Timestamp
- `sessions` — Session ID, Start time, End time, Summary, Lessons logged
- `snapshots` — Snapshot ID, Phase, Timestamp, Task count, File paths

---

## Step 3 — Create Tracking Files

Create these markdown files in `[project_path]/`:

| File | Purpose | Initial Content |
|------|---------|-----------------|
| `LESSONS_[PROJECT].md` | Corrections + insights log | Three sections: Corrections Log, Insights, Universal Patterns (all empty with headers) |
| `LEARNING_LOG.md` | Tools + techniques learned | Three sections: Tools, Techniques, Frameworks (all empty with headers) |
| `[PROJECT]_PROJECT_MEMORY.md` | Technical architecture | Sections: Overview, File Structure, Core Systems, Key Decisions (stub content) |
| `AGENT_DELEGATION.md` | Model tier mapping | Pre-phase delegation map table (empty, filled later) |
| `NEXT_SESSION.md` | Session handoff | Handoff template fields: phase, blockers, gate_status, next_tasks, overrides, session_date |
| `.gitignore` | VCS exclusions | %%GITIGNORE_TABLE%% contents |

---

## Step 4 — Create RULES.md (28 sections)

Generate `[PROJECT]_RULES.md` with all 28 sections. Use MASTER_DASHBOARD_RULES.md as template. Key sections to customize:

| Section | What to Include | Source |
|---------|-----------------|--------|
| § Project North Star | One-line vision | %%PROJECT_NORTH_STAR%% |
| § Session Start Protocol | Startup bash commands (db_queries.sh, session_briefing.sh, etc.) | Framework (customize paths) |
| § Phase Gate Protocol | Phase transition logic | Framework (use as-is) |
| § Blocker Detection Rules | What counts as blocker | Framework (use as-is) |
| § Pre-Task Check | Task readiness validation | Framework (use as-is) |
| § Task Workflow | Task loop + marking done + loopback capture | Framework (use as-is) |
| § Tech Stack & Environment | %%TECH_STACK%% with setup instructions | Auto-derive + validate |
| § Git Branching | Branch strategy (dev/main), commit format %%COMMIT_FORMAT%% | Customize for project |
| § Build & Test | %%BUILD_TEST_INSTRUCTIONS%% with exact commands | Customize for project |
| § Code Standards | %%CODE_STANDARDS%% linter/formatter config | Customize for project |
| § .gitignore Audit | %%GITIGNORE_TABLE%% patterns | Auto-derive from tech stack |
| § STOP Rules (Project-Specific) | %%PROJECT_STOP_RULES%% | Default: "None beyond universal" |
| § Deployment Mode: Agent Tool | Model delegation table + sub-agent spawn syntax | Customize if using Gemini/Grok/Ollama |
| § Deployment Mode: Agent Teams | Team topology (INACTIVE by default) | Leave inactive unless explicitly enabling |
| § MCP Servers & Plugins | %%MCP_SERVERS%% list | Auto-detect from environment |
| § Cowork Quality Gates | %%EXTRA_MANDATORY_SKILLS%% and %%RECOMMENDED_SKILLS%% | Derive from project type |
| § Visual Verification | %%VISUAL_VERIFICATION%% checklist or "N/A" | Customize based on UI/CLI |
| § Context Window Management | Bootstrap target, selective reading rules | Use as-is |
| All others | Copy from framework files or MASTER_DASHBOARD_RULES.md | Framework files in `refs/` |

---

## Step 5 — Create Root CLAUDE.md

Generate `[project_path]/CLAUDE.md` using the **load-on-demand** pattern. Frameworks are NOT @-imported at startup — they load when their protocol triggers. LESSONS is also NOT @-imported — it grows unboundedly and is injected by the session-start hook instead.

```markdown
# [Project Name] — Project Entry Point
> Cognitive rules auto-loaded from ~/.claude/CLAUDE.md (global).
> Project-specific rules imported below.

@[PROJECT]_RULES.md
@AGENT_DELEGATION.md

> LESSONS file (LESSONS_[PROJECT].md) is NOT @-imported — it grows unboundedly.
> The session-start hook injects recent lessons. Read full file on demand for correction protocol.
> Frameworks live in `frameworks/`. Load on demand — see RULES §Frameworks.
> Path-specific rules in `.claude/rules/` auto-inject when touching matching files.
> Hooks in `.claude/hooks/` enforce behavioral gates. Custom agents in `.claude/agents/`.
```

**Why load-on-demand?** Importing all 9 frameworks at startup adds ~15K tokens to every conversation — most of which is never used. The load-on-demand pattern keeps bootstrap under 25K tokens.

**Why not @-import LESSONS?** LESSONS grows unboundedly as corrections accumulate. The session-start hook injects the last 5-10 lessons as context. The correction-detection hook reads the full file on demand when a correction is detected.

Then copy all 9 framework files to `[project_path]/frameworks/`:
- `coherence-system.md`
- `correction-protocol.md`
- `delegation.md`
- `falsification.md`
- `loopback-system.md`
- `phase-gates.md`
- `quality-gates.md`
- `session-protocol.md`
- `visual-verification.md`

---

## Step 6 — Git Hooks Setup

Create these two files in `[project_path]/.git/hooks/`:

### pre-commit hook
```bash
#!/bin/bash
set -e

# Lint
[tech-stack-specific linter command, e.g., npm run lint]

# Type checking
[tech-stack-specific type checker, e.g., npx tsc --noEmit]

# Tests
[tech-stack-specific test command, e.g., npm test]

# Coherence check (warn only, don't block)
bash coherence_check.sh --quiet || true

exit 0
```

### pre-push hook
```bash
#!/bin/bash
set -e

# Full production build
[tech-stack-specific build command, e.g., npm run build]

exit 0
```

**Make executable:**
```bash
chmod +x [project_path]/.git/hooks/pre-commit
chmod +x [project_path]/.git/hooks/pre-push
```

---

## Step 7 — Populate DB with Initial Tasks

If you have a task breakdown from Phase B (PLAN.md or DECISIONS.md):

```bash
bash db_queries.sh add-task "Phase 1" "T-01" "Task Title" "CLAUDE" "sonnet" "" ""
bash db_queries.sh add-task "Phase 1" "T-02" "Task Title" "CLAUDE" "haiku" "T-01" ""
```

Or use quick capture during work:
```bash
bash db_queries.sh quick "Task description" "Phase 1" feature
```

---

## Step 8 — Seed coherence_registry.sh

Open `coherence_registry.sh` and add commented example patterns:

```bash
# When you rename a key concept, add it here:
# DEPRECATED_PATTERNS+=("old phrase")
# CANONICAL_LABELS+=("new phrase")
# INTRODUCED_ON+=("YYYY-MM-DD")

# Example (from MasterDashboard):
# DEPRECATED_PATTERNS+=("Master Dashboard app")
# CANONICAL_LABELS+=("Master Dashboard native app")
# INTRODUCED_ON+=("2025-01-15")
```

The file stays mostly empty until architectural changes occur. When they do, add entries and run `bash coherence_check.sh --fix`.

---

## Step 9 — Deploy .claude/hooks/ (13 files)

Copy hook templates from `~/.claude/dev-framework/templates/hooks/` to `[project_path]/.claude/hooks/`:

| Template | → Project File | Placeholders to Fill |
|----------|---------------|---------------------|
| `session-start-check.template.sh` | `session-start-check.sh` | None (CWD-relative) |
| `session-end-safety.template.sh` | `session-end-safety.sh` | None |
| `correction-detector.template.sh` | `correction-detector.sh` | `%%LESSON_LOG_COMMAND%%` → `bash db_queries.sh log-lesson` |
| `delegation-reminder.template.sh` | `delegation-reminder.sh` | None |
| `protect-architecture.template.sh` | `protect-architecture.sh` | None |
| `protect-databases.template.sh` | `protect-databases.sh` | `%%OWN_DB_PATTERNS%%` → project DB name regex |
| `end-of-turn-check.template.sh` | `end-of-turn-check.sh` | None |
| `subagent-delegation-check.template.sh` | `subagent-delegation-check.sh` | None |
| `post-compact-recovery.template.sh` | `post-compact-recovery.sh` | `%%AGENT_NAMES%%` → agent descriptions |
| `mark_delegation_approved.template.sh` | `mark_delegation_approved.sh` | None |
| `generate-protected-files.template.sh` | `generate-protected-files.sh` | None |
| `protected-files.template.conf` | `protected-files.conf` | `%%PROJECT_RULES_FILE%%`, `%%LESSONS_FILE%%`, `%%PROJECT_DB%%` |
| `check-pbxproj.template.sh` | `check-pbxproj.sh` | **Swift/Xcode only** — skip for other tech stacks |

After copying:
```bash
chmod +x .claude/hooks/*.sh
bash .claude/hooks/generate-protected-files.sh .   # Auto-generate protected-files.conf
echo "0" > .claude/hooks/.delegation_state && echo "0" >> .claude/hooks/.delegation_state
```

---

## Step 10 — Deploy .claude/agents/ (2 directories)

Copy agent templates from `~/.claude/dev-framework/templates/agents/`:

| Template | → Project File | Placeholders |
|----------|---------------|-------------|
| `implementer.template.md` | `.claude/agents/implementer/implementer.md` | `%%PROJECT_NAME%%`, `%%TECH_STANDARDS%%`, `%%BUILD_COMMAND%%`, `%%TECH_STACK_HOOKS%%` |
| `worker.template.md` | `.claude/agents/worker/worker.md` | `%%PROJECT_NAME%%`, `%%TECH_STANDARDS_BRIEF%%` |

Create the directory structure: `mkdir -p .claude/agents/implementer .claude/agents/worker`

---

## Step 11 — Deploy .claude/rules/ (2-5 files)

Copy rule templates from `~/.claude/dev-framework/templates/rules/`:

**Always deploy (universal):**
- `database-safety.template.md` → `.claude/rules/database-safety.md` — Fill `%%PROJECT_NAME%%`, `%%PROJECT_DB%%`
- `workflow-scripts.template.md` → `.claude/rules/workflow-scripts.md` — Fill `%%PROJECT_NAME%%`

**Deploy per tech stack:**
- Swift: `swift-standards.template.md` → `.claude/rules/swift-standards.md`
- Node.js: `node-standards.template.md` → `.claude/rules/node-standards.md`
- Python: `python-standards.template.md` → `.claude/rules/python-standards.md`
- Rust: `rust-standards.template.md` → `.claude/rules/rust-standards.md`
- Go: `go-standards.template.md` → `.claude/rules/go-standards.md`

---

## Step 12 — Generate .claude/settings.json + settings.local.json

Copy from `~/.claude/dev-framework/templates/settings/`:

**settings.json:**
- Fill `%%PERMISSION_ALLOW%%` with tech-stack-specific patterns:
  - Swift: `Edit(*.swift)`, `Write(*.swift)`, `Bash(bash build_summarizer.sh *)`
  - Node: `Edit(*.ts)`, `Edit(*.tsx)`, `Write(*.ts)`, `Bash(npm *)`
  - Python: `Edit(*.py)`, `Write(*.py)`, `Bash(python *)`
  - Rust: `Edit(*.rs)`, `Write(*.rs)`, `Bash(cargo *)`
  - Go: `Edit(*.go)`, `Write(*.go)`, `Bash(go *)`
- Always include: `Bash(bash db_queries.sh *)`, `Bash(bash build_summarizer.sh *)`, `Bash(git *)`, `Bash(bash save_session.sh *)`, `Bash(bash session_briefing.sh *)`
- Hook wiring: all 7 event types pre-configured with relative `.claude/hooks/` paths

**settings.local.json:** Fill `%%LOCAL_PERMISSIONS%%` with empty array (user customizes later)

---

## Step 13 — End-to-End Verification (17 checks)

Run these checks in order. All must PASS before first session:

```bash
# 1. Database healthy
bash db_queries.sh health
# Expected: "✓ Database initialized" + table list

# 2. Briefing generates
bash session_briefing.sh
# Expected: Phase, Gate, Next task (or "None yet")

# 3. Phase ordinal function works
bash db_queries.sh phase
# Expected: List of phases or "No phases yet"

# 4. Scripts are executable
ls -la *.sh | grep -E '^-rwx'
# Expected: All 9 scripts are executable

# 5. Tracking files exist
ls -1 LESSONS_*.md LEARNING_LOG.md NEXT_SESSION.md
# Expected: All three files exist

# 6. CLAUDE.md @-imports work
grep -c "^@" CLAUDE.md
# Expected: 2 (@[PROJECT]_RULES.md + @AGENT_DELEGATION.md — frameworks are load-on-demand, LESSONS is hook-injected)

# 7. Frameworks copied
ls -1 frameworks/*.md | wc -l
# Expected: 9 files

# 8. Git hooks in place
ls -la .git/hooks/pre-commit .git/hooks/pre-push
# Expected: Both files exist and are executable

# 9. No stray placeholders
grep -rn '%%' . --include="*.md" --include="*.sh" | grep -v "^Binary"
# Expected: Zero matches (or only in this reference file)

# 10. Paths customized
grep -rn 'chonkius\|MasterDashboard' . --include="*.sh"
# Expected: Zero matches

# 11. DB accessible
sqlite3 [project].db "SELECT COUNT(*) FROM tasks;"
# Expected: 0 or task count if populated

# 12. Hooks executable
ls -la .claude/hooks/*.sh | grep -c '^-rwx'
# Expected: 11+ (all hook scripts are executable)

# 13. settings.json valid JSON
python3 -c "import json; json.load(open('.claude/settings.json'))"
# Expected: No error output

# 14. Agents defined
ls .claude/agents/*/*.md
# Expected: implementer.md and worker.md

# 15. Rules deployed
ls .claude/rules/*.md
# Expected: 3+ rule files (2 universal + 1+ tech-specific)

# 16. Hook events wired
grep -c '"hooks"' .claude/settings.json
# Expected: 7 (one per hook event type)

# 17. No remaining hardcoded paths
grep -rn 'chonkius\|MasterDashboard' . --include="*.sh" --include="*.json"
# Expected: Zero matches
```

---

## Common Customization Patterns by Tech Stack

### Node.js/Next.js
- `%%BUILD_TEST_INSTRUCTIONS%%`: `npm run build && npm test`
- `%%CODE_STANDARDS%%`: ESLint (via `.eslintrc.json`), Prettier, TypeScript strict
- Pre-commit: `npm run lint && npx tsc --noEmit && npm test`
- Pre-push: `npm run build`

### Python (Poetry)
- `%%BUILD_TEST_INSTRUCTIONS%%`: `poetry run pytest && poetry run mypy .`
- `%%CODE_STANDARDS%%`: Black, Ruff, MyPy strict
- Pre-commit: `poetry run black . && poetry run ruff check . && poetry run mypy .`
- Pre-push: `poetry run pytest`

### Rust
- `%%BUILD_TEST_INSTRUCTIONS%%`: `cargo build && cargo test`
- `%%CODE_STANDARDS%%`: Clippy, fmt, deny
- Pre-commit: `cargo clippy -- -D warnings && cargo fmt --check && cargo test`
- Pre-push: `cargo build --release`

### Swift
- `%%BUILD_TEST_INSTRUCTIONS%%`: `xcodebuild build && xcodebuild test`
- `%%CODE_STANDARDS%%`: SwiftLint, Swift Formatter
- Pre-commit: `swiftlint && swift format --in-place . && xcodebuild test`
- Pre-push: `xcodebuild build -configuration Release`

### Go
- `%%BUILD_TEST_INSTRUCTIONS%%`: `go build . && go test ./...`
- `%%CODE_STANDARDS%%`: gofmt, golint, go vet
- Pre-commit: `go fmt ./... && go vet ./... && go test ./...`
- Pre-push: `go build .`

---

## Troubleshooting Deployment

| Issue | Cause | Fix |
|-------|-------|-----|
| "command not found: db_queries.sh" | Script not executable or not in PATH | `chmod +x db_queries.sh` |
| "can't open db_queries.sh: No such file or directory" | DB_PATH incorrect in script | Verify path in first ~15 lines of db_queries.sh |
| "SQLite error: table tasks already exists" | DB was already initialized | Delete [project].db and let auto-init recreate |
| "%%PLACEHOLDER%% still in RULES.md" | Placeholder not filled during sed | Run `grep -rn '%%' RULES.md` and manually replace |
| "phase_ordinal: unrecognized phase" | Phase name in task doesn't match case statement | Update phase_ordinal() in db_queries.sh |
| Pre-commit hook fails silently | Hook not executable or shell errors | `chmod +x .git/hooks/pre-commit && bash -x .git/hooks/pre-commit` to debug |

