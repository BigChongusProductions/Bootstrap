---
name: bootstrap-activate
description: >
  Use this skill when the user runs /activate-engine, or says "activate the engine",
  "set up the workflow", "fill placeholders", "generate requirements", or any phrase
  indicating they want to transition from discovery specs to a working project with
  a populated task database and fully operational workflow engine. Prerequisites:
  ENVISION.md, DECISIONS.md, and FRAMEWORK.md must exist in specs/ with no TODO
  placeholders. Typically triggered after bootstrap-discovery completes in Cowork.
version: 0.2.0
---

# Bootstrap Activate

Transform completed discovery specs into a fully operational project with populated task database, filled configuration, generated requirements/design documents, active workflow engine, quality gates, git hooks, and all protocol documentation.

## Prerequisites Check (Phase A)

Before doing anything, verify ALL of these:

1. `specs/ENVISION.md` exists and contains no "TODO" text
2. `specs/DECISIONS.md` exists and contains no "TODO" text
3. `specs/RESEARCH.md` exists (can be "N/A" for Small-tier) and contains no "TODO" text
4. `specs/FRAMEWORK.md` exists and contains no "TODO" text
5. `.bootstrap_mode` file exists and contains `SPECIFICATION`
6. **Template directory check:** `~/.claude/dev-framework/templates/db_queries.template.sh` exists.
   If missing, tell the user: "Templates not installed. Run `/setup-templates` first, or point me to an existing project to extract from."
7. **Bootstrap backlog check:** Read `~/.claude/dev-framework/BOOTSTRAP_BACKLOG.md` if it exists.
   Count pending items by priority. If any **P0** items exist, WARN with item titles (these mean new projects may be actively broken). If any **P1** items, INFO with count. This is advisory only — do not block bootstrap.

If `NEXT_SESSION.md` exists with `Handoff Source: COWORK`, read it for context about what was decided during discovery.

---

## Phase B: Specification

### B1: Project Scaffolding

Read DECISIONS.md to extract the tech stack and project structure. Create:

1. The directory structure specified in DECISIONS.md "Project Structure" section
2. A `.gitignore` appropriate for the chosen tech stack
3. `refs/README.md` — progressive disclosure directory
4. `backups/` directory for DB backups
5. Copy `frameworks/` directory (all 9 files) from `~/.claude/dev-framework/frameworks/`
6. Initialize git repo if not already initialized, create `dev` branch, make initial commit

### B2: Fill Placeholders

Read `references/placeholder-registry.md` for the complete list of `%%PLACEHOLDER%%` values and where each gets its value.

For each placeholder:
1. Check if the value can be auto-derived from DECISIONS.md or FRAMEWORK.md (most can)
2. For values that require user input, ask using AskUserQuestion (batch related questions)
3. Perform the replacement across all files that contain the placeholder
4. After all replacements, verify: `grep -rn '%%' *.md *.sh` across all project files — must be zero matches

Present a summary of what was filled and ask user to confirm.

### B3: Generate requirements.md

Read all four spec files. Generate `specs/requirements.md` using EARS format:
- "When [trigger], the system shall [behavior]"
- "The system shall [behavior] [constraint]"

Every requirement must be:
- Directly testable (you can write a test for it)
- Traced to a scope item in DECISIONS.md
- Assigned a unique ID (FR-01, FR-02, NFR-01, etc.)

Present requirements.md to the user for review. Address any `> NOTE:` annotations they add. Iterate until clean (zero unresolved notes).

### B4: Generate design.md

Read requirements.md + DECISIONS.md. Generate `specs/design.md` covering:
- System architecture (expand on the diagram from DECISIONS.md)
- Data models with field types and constraints
- Component breakdown mapped to requirements (FR-XX)
- Key technical decisions with rationale
- Error handling strategy
- Testing strategy

Present design.md to the user for review. Address all annotations. Iterate until clean.

### B5: Specification Gate

Before proceeding to planning, verify:
- requirements.md has zero open questions
- design.md has zero `> NOTE:` annotations
- All placeholders are filled (zero `%%` matches)
- User explicitly says "approved" or "go"

---

## Phase C: Planning

### C1: Generate Task Breakdown

Read design.md. Break it into implementation phases. For each phase, create atomic tasks.

**Phase naming:** Use a prefix-name format. See `references/phase-planning-guide.md` for templates by project type (Web/Desktop, CLI, API).

**Task format:**
```
| ID | Phase | Title | Assignee | Tier | Blocked By |
```

**Pre-phase delegation map is MANDATORY.** Before presenting tasks, produce a delegation table mapping every task to a tier with justification:

| Tier | Model | Cost | When to Use |
|------|-------|------|-------------|
| **Opus** | claude-opus-4-6 | $$$$ | Architecture, gate reviews, judgment calls, anything that failed at lower tier |
| **Sonnet** | claude-sonnet-4-6 | $$ | Multi-file features, cross-file reasoning, non-trivial state/animation |
| **Haiku** | claude-haiku-4-5 | $ | Single-file, config, clear spec, no judgment needed |
| **MASTER** | Human | — | Design decisions, external config, device testing, final review, asset creation |
| **Gemini** | via MCP | varies | Large context, web research, image gen, translation (if in tech stack) |
| **Grok** | via MCP | $ | X/Twitter search, real-time web, Aurora image gen, cheap inference (if in tech stack) |
| **Ollama** | local | free | Local LLM tasks, semantic similarity (if in tech stack) |

**Never assign Haiku to:** tasks where wrong = significant rework, complex state logic, or 3+ file context.

**Failure escalation rule:** Haiku fails 2x → Sonnet. Sonnet fails 2x → Opus direct. Log every escalation.

Present the full delegation table to the user. **Wait for approval before proceeding.**

### C2: Populate Database

1. **Copy db_queries.sh** from `~/.claude/dev-framework/templates/db_queries.template.sh`
2. **Customize** — run sed replacements for project-specific values (DB name, project name, LESSONS file name). See `references/placeholder-registry.md` "Template Customization" section.
3. **Create the database** — `touch [project].db && bash db_queries.sh init-db` (creates all tables: tasks, phase_gates, milestone_confirmations, loopback_acks, assumptions, db_snapshots, decisions, sessions). Then run `bash db_queries.sh health` to verify. **Do NOT use `health` to create the schema** — `health` only checks tables, it does not create them.
4. **INSERT all tasks** with full metadata: id, phase, assignee, title, priority, tier, skill, needs_browser, sort_order, blocked_by, track='forward'
5. **Fill `phase_ordinal()` function** — derive ordinals from task breakdown:
   ```bash
   # Collect unique phases in order, assign 0, 1, 2, ...
   phase_ordinal() {
       case "$1" in
           P0-FOUNDATION) echo 0 ;;
           P1-CORE) echo 1 ;;
           # ... one line per phase
           *) echo 99 ;;
       esac
   }
   ```
   The `%%PHASE_ORDINALS%%` marker appears in **3 places** in db_queries.sh, but only **2 need case blocks filled**:
   - Location 1 (~line 88): the `phase_ordinal()` bash function body
   - Location 2 (~line 807): the `(N - CASE t.phase ...)` SQL scoring formula — set `N` = number of phases (e.g. `6` for 6-phase, `5` for 5-phase)
   - Location 3 (~line 1744): uses `SELECT DISTINCT phase FROM phase_gates` — dynamic, no filling needed

   Always search `%%PHASE_ORDINALS%%` and verify all three locations are handled.
6. **Verify:** `bash db_queries.sh verify` (DB integrity) + `bash db_queries.sh health` (pipeline) + `bash db_queries.sh next` (task queue)

### C3: Activate Delegation Map

Run `bash db_queries.sh delegation-md` to generate the delegation map in AGENT_DELEGATION.md from the database. This replaces any placeholder content.

---

## Phase D: Engine Deployment

This is where ALL infrastructure scripts, protocol documentation, tracking files, enforcement hooks, custom agents, path rules, settings, git hooks, and launch scripts are created. After Phase D, the project has a fully operational development environment with both behavioral guidelines AND programmatic enforcement.

### D1: Deploy Workflow Scripts + refs/ Scaffolding

**First, create the refs/ directory** with starter reference files. Read `references/refs-scaffolding.md` for the full guide. At minimum, create:
- `refs/README.md` — directory index
- `refs/tool-inventory.md` — detected tools (auto-populated from environment)
- `refs/gotchas-workflow.md` — empty template (populated by gotcha generation protocol)
- `refs/skills-catalog.md` — if project uses custom skills (check FRAMEWORK.md)
- `refs/gotchas-frontend.md` — if project has UI (check FRAMEWORK.md)
- `refs/planned-integrations.md` — if DECISIONS.md has deferred integrations

**Seed gotchas from bootstrap backlog:** If `~/.claude/dev-framework/BOOTSTRAP_BACKLOG.md` exists, scan **applied** items for `Gotcha:` fields. For each gotcha that matches the project's tech stack or affected area, pre-populate the relevant `refs/gotchas-*.md` file. This ensures new projects inherit hard-won warnings from previous projects.

**Then copy and customize ALL template scripts** from `~/.claude/dev-framework/templates/scripts/`:

| Template | → Project File | Customization |
|----------|---------------|---------------|
| `session_briefing.template.sh` | `session_briefing.sh` | Replace: DB name, project display name, LESSONS file, PROJECT_MEMORY file, RULES file |
| `milestone_check.template.sh` | `milestone_check.sh` | Replace: DB name, branch names (main/dev) |
| `build_summarizer.template.sh` | `build_summarizer.sh` | **Generate real implementation** for the tech stack (see `references/quality-gates-guide.md` for per-language templates) |
| `coherence_check.template.sh` | `coherence_check.sh` | Replace SKIP_PATTERNS with project LESSONS file name |
| `coherence_registry.template.sh` | `coherence_registry.sh` | Start with seed entries from DECISIONS.md corrections (if any) or commented examples |
| `work.template.sh` | `work.sh` | Replace: project path, model choice |
| `fix.template.sh` | `fix.sh` | Replace: project path |
| `generate_board.py` | `generate_board.py` | Replace: DB path |
| `harvest.template.sh` | `harvest.sh` | Replace: project path, LESSONS file |
| `save_session.template.sh` | `save_session.sh` | Replace: `%%PROJECT_DB%%`, `%%PROJECT_PATH%%`, `%%PROJECT_NAME%%` |
| `shared_signal.template.sh` | `shared_signal.sh` | No changes needed (already portable, uses `$1` for DB path) |

After copying, make all .sh files executable: `chmod +x *.sh`

**Verification — run each script in diagnostic mode:**
```bash
bash db_queries.sh health          # Pipeline healthy?
bash db_queries.sh next            # Task queue working?
bash session_briefing.sh           # Full briefing produces output?
bash coherence_check.sh --quiet    # Scanner runs?
```

### D2: Deploy RULES.md (The Brain)

This is the most critical file. Generate `[PROJECT]_RULES.md` from the template at `~/.claude/dev-framework/templates/RULES.template.md`. ALL protocol sections must be present and ALL placeholders filled.

**Required sections (29 total — 28 numbered + loopback system §13b):**

1. **Project North Star** — from `%%PROJECT_NORTH_STAR%%`
2. **Session Start Protocol** — mandatory. References: `db_queries.sh phase/blockers/gate/next`, `session_briefing.sh`, `NEXT_SESSION.md`, `PROJECT_MEMORY.md`. Includes signal interpretation (GREEN/YELLOW/RED). Note: session start is now hook-enforced (D5 deploys the hook).
3. **Phase Gate Protocol** — mandatory. Audit process, must-fix/follow-up categorization, `db_queries.sh gate-pass`.
4. **Blocker Detection Rules** — mandatory. Continuous detection, override mechanism, logging.
5. **Pre-Task Check** — mandatory. `bash db_queries.sh check <task-id>` with GO/CONFIRM/STOP verdicts. CONFIRM triggers (first task in new phase, last task in phase, 5+ since checkpoint). STOP triggers (wrong owner, incomplete prior phase, ungated prior phase, cross-phase blocker).
6. **Task Workflow** — mandatory. `db_queries.sh next` queue (FORWARD/loopback/BLOCKED sections), marking done immediately, task details lookup.
7. **Adding New Tasks** — mandatory. Quick capture (`db_queries.sh quick`), loopback capture with severity S1-S4, triage from inbox, loopback commands (ack-breaker, skip, loopback-lesson, loopback-stats).
8. **Tech Stack & Environment** — from `%%TECH_STACK%%`
9. **Git Branching** — mandatory. Always dev, never main, commit format from `%%COMMIT_FORMAT%%`, atomic commits (one task = one commit), never merge dev→main (Master's job).
10. **Milestone Merge Gate** — mandatory. `bash milestone_check.sh <PHASE>`. Checks: task completion, branch, clean tree, build+tests, coherence. Code review required before merge.
11. **Build & Test** — from `%%BUILD_TEST_INSTRUCTIONS%%`
12. **Code Standards** — from `%%CODE_STANDARDS%%`. Note: path-specific rules in `.claude/rules/` auto-inject on matching files (deployed in D7).
13. **Tracking Files** — mandatory. After each task: mark DONE in DB, update PROJECT_MEMORY if structural change, update LEARNING_LOG if new tool/technique, update LESSONS after corrections, commit, log session at end.
13b. **Loopback System** — mandatory. Parallel backward-fix track. Covers: severity S1-S4, circuit breaker (S1 blocks all forward work until acknowledged), gate-critical loopbacks (must resolve before phase gate passes), loopback commands in db_queries.sh (loopbacks, loopback-stats, ack-breaker, skip, loopback-lesson). See `frameworks/loopback-system.md` for full system reference.
14. **Coherence Check** — mandatory. Pre-commit hook runs `coherence_check.sh --quiet`. Manual `--fix` after core edits. How to add entries to `coherence_registry.sh`.
15. **.gitignore Audit** — mandatory. Post-task audit for new file types, secrets check, `git check-ignore` verification.
16. **Correction Detection Gate** — mandatory HARD gate. Now hook-enforced (`.claude/hooks/correction-detector.sh`). Before ANY user response: scan for correction signals. If detected: FIRST tool call = log the lesson. Only AFTER lesson logged, diagnose and fix.
17. **Delegation Gate** — mandatory HARD gate. Now hook-enforced (`.claude/hooks/delegation-reminder.sh`). Before ANY multi-step task: produce delegation table `| Task | Tier | Why |`. No Edit/Write/Bash until table presented. Wait for approval.
18. **Output Verification Gate** — conditional. If UI project: visual verification via screenshots. If API: contract testing. If data: integrity checks. From `%%OUTPUT_VERIFICATION_GATE%%`.
19. **Lesson Extraction + Gotcha Generation** — mandatory. Before session end: scan conversation for corrections, retries, false assumptions, new tools, violated lessons, promotion candidates. Propose lessons categorized by type. **Gotcha generation trigger:** When 2+ corrections accumulate in the same domain (frontend, workflow, data, API), auto-suggest creating or updating `refs/gotchas-[domain].md` with point-of-use warnings distilled from LESSONS. Gotchas at point-of-use are more effective than centralized lesson logs alone.
20. **STOP Rules** — mandatory. Universal rules (from global CLAUDE.md §10) + project-specific from `%%PROJECT_STOP_RULES%%`.
21. **Deployment Mode: Agent Tool** — mandatory. 6-tier model table, sub-agent spawn syntax (model frontmatter), sub-agent rules (read files OK, modify only assigned files, fail 2x → escalate), budget mode command. Custom agents deployed in `.claude/agents/` (D6).
22. **Deployment Mode: Agent Teams** — conditional (inactive by default). Prerequisites, team topology, coordination protocol, cost awareness. From `%%TEAM_TOPOLOGY%%`.
23. **Gemini MCP Table** — conditional. From `%%GEMINI_MCP_TABLE%%`. If no Gemini: "N/A".
24. **Visual Verification** — conditional. From `%%VISUAL_VERIFICATION%%`. If no UI: "N/A".
25. **Cowork Quality Gates** — mandatory. Code review before every dev→main merge. Recommended skills per phase. From `%%EXTRA_MANDATORY_SKILLS%%` and `%%RECOMMENDED_SKILLS%%`.
26. **Context Window Management** — mandatory. Read files selectively, status from DB not prose, minimal sub-agent context, compress completed phases, keep instruction files stable for caching, suggest new session if degrading.
27. **MCP Servers & Plugins Available** — from `%%MCP_SERVERS%%`
28. **Progressive Disclosure** — mandatory. refs/ directory usage. Extract sections >50 lines to refs/.

**Verify:** `grep -rn '%%' [PROJECT]_RULES.md` must return zero results.

### D3: Deploy CLAUDE.md (Entry Point)

Generate the project's CLAUDE.md using the load-on-demand pattern (frameworks are NOT @-imported at startup — they load when their protocol triggers):

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

**Why load-on-demand?** Importing all 9 frameworks at startup adds ~15K tokens to every conversation — most of which is never used. The load-on-demand pattern keeps bootstrap under 25K tokens while frameworks remain accessible when needed. MasterDashboard learned this the hard way.

**Why not @-import LESSONS?** LESSONS grows unboundedly as corrections accumulate. In MasterDashboard, it reached 200+ lines. The session-start hook injects the last 5-10 lessons as context. The correction-detection hook reads the full file on demand when a correction is detected.

### D4: Deploy Tracking Files

Create from templates (fill skeleton content from specs):

| File | Content |
|------|---------|
| `LESSONS_[PROJECT].md` | Corrections log (empty table), Insights (empty table), Universal Patterns (empty table) |
| `LEARNING_LOG.md` | Empty table: Date, What, Category, Notes |
| `[PROJECT]_PROJECT_MEMORY.md` | §1 Overview (from ENVISION pitch), §2 Section Lookup, §3 Architecture (from DECISIONS diagram), §4 File Structure (from DECISIONS project structure) |
| `AGENT_DELEGATION.md` | 6-tier model table + delegation map (already populated by C3) |
| `NEXT_SESSION.md` | Handoff: source=BOOTSTRAP, signal=GREEN, first task=[first task ID from DB] |

### D5: Deploy .claude/hooks/ (Enforcement Layer)

This is the most impactful new step. Hooks provide **programmatic enforcement** of behavioral gates that previously existed only as prose rules (and were routinely forgotten). Without hooks, the entire quality system depends on Claude remembering to follow rules — which fails under context pressure.

**Create directory structure:**
```bash
mkdir -p .claude/hooks
```

**Copy and customize hook templates** from `~/.claude/dev-framework/templates/hooks/`:

| Template | → Project File | Placeholders | Event |
|----------|---------------|-------------|-------|
| `session-start-check.template.sh` | `session-start-check.sh` | None (CWD-relative) | SessionStart |
| `session-end-safety.template.sh` | `session-end-safety.sh` | None | SessionEnd |
| `correction-detector.template.sh` | `correction-detector.sh` | `%%LESSON_LOG_COMMAND%%` | UserPromptSubmit |
| `delegation-reminder.template.sh` | `delegation-reminder.sh` | None | PreToolUse (Edit\|Write) |
| `protect-architecture.template.sh` | `protect-architecture.sh` | None | PreToolUse (Edit\|Write) |
| `protect-databases.template.sh` | `protect-databases.sh` | `%%OWN_DB_PATTERNS%%` | PreToolUse (Bash) |
| `end-of-turn-check.template.sh` | `end-of-turn-check.sh` | None | Stop |
| `subagent-delegation-check.template.sh` | `subagent-delegation-check.sh` | None | SubagentStart |
| `post-compact-recovery.template.sh` | `post-compact-recovery.sh` | `%%AGENT_NAMES%%` | PostCompact |
| `mark_delegation_approved.template.sh` | `mark_delegation_approved.sh` | None | (manual) |
| `generate-protected-files.template.sh` | `generate-protected-files.sh` | None | (manual) |
| `protected-files.template.conf` | `protected-files.conf` | `%%PROJECT_RULES_FILE%%`, `%%LESSONS_FILE%%`, `%%PROJECT_DB%%` | (config) |

**Conditional hooks (tech-stack-specific):**
| Template | → Project File | Condition |
|----------|---------------|-----------|
| `check-pbxproj.template.sh` | `check-pbxproj.sh` | Swift/Xcode projects only |

**Placeholder filling:**
- `%%LESSON_LOG_COMMAND%%` → `bash db_queries.sh log-lesson \"[what happened]\" \"[pattern]\" \"[prevention rule]\"`
- `%%OWN_DB_PATTERNS%%` → project DB names as grep regex, e.g. `my_project\.db\|news\.db`
- `%%AGENT_NAMES%%` → formatted agent descriptions for post-compaction context recovery
- `%%PROJECT_RULES_FILE%%` → `[PROJECT]_RULES.md`
- `%%LESSONS_FILE%%` → `LESSONS_[PROJECT].md`
- `%%PROJECT_DB%%` → `[project].db` (and any additional project-owned databases)

**Post-copy setup:**
```bash
chmod +x .claude/hooks/*.sh
bash .claude/hooks/generate-protected-files.sh .   # Auto-generate protected-files.conf
echo "0" > .claude/hooks/.delegation_state
echo "0" >> .claude/hooks/.delegation_state
```

**What each hook enforces:**
| Hook | Gate | Behavior |
|------|------|----------|
| session-start-check | Session start | Auto-injects briefing + handoff + warnings into first interaction |
| session-end-safety | Session end | Auto-saves session if no manual save within 5 minutes |
| correction-detector | Correction detection | Injects HARD GATE reminder when correction signals detected in user message |
| delegation-reminder | Delegation gate | Counts edits, escalates to "ask" after 3+ edits without approval |
| protect-architecture | Architecture protection | Requires human confirmation before modifying infrastructure files |
| protect-databases | DB safety | Denies sqlite3 write commands targeting external databases |
| end-of-turn-check | Session hygiene | Warns about uncommitted files, high edit count, stale handoff |
| subagent-delegation-check | Agent delegation | Warns when spawning agents without delegation approval |
| post-compact-recovery | Context recovery | Re-injects critical rules after context compaction |
| check-pbxproj | Xcode registration | Warns when new .swift files aren't in project.pbxproj (Swift only) |

### D6: Deploy .claude/agents/ (Custom Agents)

Custom agents allow the orchestrator (Opus) to delegate work to cheaper, faster models with constrained tool access and tech-stack-specific instructions.

**Create directory structure:**
```bash
mkdir -p .claude/agents/implementer .claude/agents/worker
```

**Copy and customize agent templates** from `~/.claude/dev-framework/templates/agents/`:

| Template | → Project File | Placeholders |
|----------|---------------|-------------|
| `implementer.template.md` | `.claude/agents/implementer/implementer.md` | `%%PROJECT_NAME%%`, `%%TECH_STANDARDS%%`, `%%BUILD_COMMAND%%`, `%%TECH_STACK_HOOKS%%` |
| `worker.template.md` | `.claude/agents/worker/worker.md` | `%%PROJECT_NAME%%`, `%%TECH_STANDARDS_BRIEF%%` |

**Placeholder filling:**
- `%%PROJECT_NAME%%` → project display name
- `%%TECH_STANDARDS%%` → full tech standards block from the relevant rule template (e.g., Swift: concurrency, types, DB access, SwiftUI specifics, project registration)
- `%%TECH_STANDARDS_BRIEF%%` → 3-4 key rules for the single-file worker (e.g., `@MainActor` for UI, `async/await` for DB, no force-unwraps)
- `%%BUILD_COMMAND%%` → build verification command (e.g., `bash build_summarizer.sh build`)
- `%%TECH_STACK_HOOKS%%` → tech-stack-specific hooks in implementer frontmatter. For Swift/Xcode: the `check-pbxproj.sh` PostToolUse hook. For other stacks: empty (remove the hooks section from frontmatter).

### D7: Deploy .claude/rules/ (Path-Specific Rules)

Path-specific rules auto-inject into Claude's context when matching files are touched. This gives Claude relevant standards exactly when needed, without bloating the base context.

**Create directory:**
```bash
mkdir -p .claude/rules
```

**Always deploy (universal):**
| Template | → Project File | Placeholders |
|----------|---------------|-------------|
| `database-safety.template.md` | `.claude/rules/database-safety.md` | `%%PROJECT_NAME%%`, `%%PROJECT_DB%%` |
| `workflow-scripts.template.md` | `.claude/rules/workflow-scripts.md` | `%%PROJECT_NAME%%` |

**Deploy per tech stack (one of these):**
| Tech Stack | Template | → File |
|-----------|----------|--------|
| Swift | `swift-standards.template.md` | `.claude/rules/swift-standards.md` |
| Node.js | `node-standards.template.md` | `.claude/rules/node-standards.md` |
| Python | `python-standards.template.md` | `.claude/rules/python-standards.md` |
| Rust | `rust-standards.template.md` | `.claude/rules/rust-standards.md` |
| Go | `go-standards.template.md` | `.claude/rules/go-standards.md` |

Fill `%%PROJECT_NAME%%` in all rule files.

### D8: Generate .claude/settings.json + settings.local.json

This is the **single most critical file for enforcement**. Without `settings.json`, no hooks fire, no permissions are enforced, and the entire enforcement layer is dead. The file wires hooks to events and sets tool permissions.

**Copy and customize** from `~/.claude/dev-framework/templates/settings/`:

**settings.json** — fill `%%PERMISSION_ALLOW%%` with tech-stack-specific patterns:

| Tech Stack | Permission Patterns |
|-----------|-------------------|
| Swift | `Edit(*.swift)`, `Write(*.swift)`, `Bash(bash build_summarizer.sh *)` |
| Node.js | `Edit(*.ts)`, `Edit(*.tsx)`, `Write(*.ts)`, `Write(*.tsx)`, `Bash(npm *)`, `Bash(npx *)` |
| Python | `Edit(*.py)`, `Write(*.py)`, `Bash(python *)`, `Bash(poetry *)` |
| Rust | `Edit(*.rs)`, `Write(*.rs)`, `Bash(cargo *)` |
| Go | `Edit(*.go)`, `Write(*.go)`, `Bash(go *)` |

**Always include these permissions (all tech stacks):**
- `Bash(bash db_queries.sh *)`, `Bash(bash build_summarizer.sh *)`, `Bash(bash save_session.sh *)`, `Bash(bash session_briefing.sh *)`, `Bash(bash milestone_check.sh *)`
- `Bash(git status*)`, `Bash(git diff*)`, `Bash(git log*)`, `Bash(git add *)`, `Bash(git commit *)`

**Deny list (never customize — always block):**
- `Write(*.db)`, `Write(*.sqlite)`, `Write(*.sqlite3)`, `Edit(*.db)`, `Edit(*.sqlite)`, `Edit(*.sqlite3)`

**Hook wiring** — all 7 event types must be present:
- `UserPromptSubmit` → `correction-detector.sh`
- `PreToolUse` (Edit|Write) → `delegation-reminder.sh`, `protect-architecture.sh`
- `PreToolUse` (Bash) → `protect-databases.sh`
- `PostCompact` → `post-compact-recovery.sh`
- `SubagentStart` → `subagent-delegation-check.sh`
- `Stop` → `end-of-turn-check.sh`
- `SessionStart` → `session-start-check.sh`
- `SessionEnd` → `session-end-safety.sh`

**settings.local.json** — minimal local overrides (not committed to git):
```json
{
  "permissions": {
    "allow": []
  }
}
```

**Verification:**
```bash
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
grep -c '"command"' .claude/settings.json   # Expected: 8+ (one per hook)
```

### D9: Deploy Git Hooks

Create `.git/hooks/pre-commit` customized for the project's tech stack:

```bash
#!/bin/bash
# Quality Gate 1 — pre-commit
DIR="$(git rev-parse --show-toplevel)"
echo "── Pre-commit checks ──"

# 1. Build/lint (tech-stack-specific — see quality-gates-guide.md)
[TECH_STACK_BUILD_COMMANDS]

# 2. Coherence check (soft warning — doesn't block)
if [ -f "$DIR/coherence_check.sh" ]; then
    bash "$DIR/coherence_check.sh" --quiet 2>&1 || true
fi

# 3. Knowledge health nag
if [ -f "$DIR/LESSONS_[PROJECT].md" ]; then
    UNPROMOTED=$(grep -cE "^\|[^|]+\|[^|]+\| No( —| \|)" "$DIR/LESSONS_[PROJECT].md" 2>/dev/null)
    UNPROMOTED="${UNPROMOTED:-0}"
    [ "$UNPROMOTED" -gt 3 ] && echo "⚠️  $UNPROMOTED unpromoted lesson(s)"
fi
```

Create `.git/hooks/pre-push`:
```bash
#!/bin/bash
# Quality Gate 2 — pre-push
DIR="$(git rev-parse --show-toplevel)"
echo "── Pre-push checks ──"
[TECH_STACK_FULL_BUILD_COMMAND]
```

Make both executable: `chmod +x .git/hooks/pre-commit .git/hooks/pre-push`

See `references/quality-gates-guide.md` for tech-stack-specific build commands.

### D10: Deploy Launch Scripts

Generate `work.sh` — daily driver:
- Sets PROJECT path variable
- Backs up DB (silent daily auto-backup)
- Checks git branch (warn if not dev)
- Shows recent git log
- Launches Claude Code with configured model (opusplan or opus)

Generate `fix.sh` — Opus fix mode:
- Sets PROJECT path variable
- Shows recent git log
- Accepts optional problem description as $1
- Launches Claude Code with claude-opus-4-6 directly

### D11: Engine Verification (End-to-End — 17 checks)

Run ALL of these and verify output. **Do not skip verification — every time it was skipped, something was broken.**

```bash
# 1. DB health
bash db_queries.sh health

# 2. Task queue
bash db_queries.sh next

# 3. Session briefing
bash session_briefing.sh

# 4. Coherence
bash coherence_check.sh

# 5. @-import chain — verify every @-imported file exists
grep -oP '^@\K.+' CLAUDE.md | while read f; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

# 6. Placeholder scan — must be zero
grep -rn '%%' *.md *.sh .claude/ 2>/dev/null | grep -v '.git/' | grep -v 'node_modules/'

# 7. Git hooks executable
[ -x .git/hooks/pre-commit ] && echo "✅ pre-commit" || echo "❌ pre-commit missing"
[ -x .git/hooks/pre-push ] && echo "✅ pre-push" || echo "❌ pre-push missing"

# 8. All framework files present (9 files)
for f in frameworks/{coherence-system,correction-protocol,delegation,falsification,loopback-system,phase-gates,quality-gates,session-protocol,visual-verification}.md; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

# 9. All tracking files present
for f in LESSONS_*.md LEARNING_LOG.md *_PROJECT_MEMORY.md AGENT_DELEGATION.md; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

# 10. refs/ directory scaffolded
[ -d refs/ ] && echo "✅ refs/ exists ($(ls refs/*.md 2>/dev/null | wc -l) files)" || echo "❌ refs/ missing"
for f in refs/tool-inventory.md refs/gotchas-workflow.md; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

# 11. Build check
bash build_summarizer.sh build 2>&1 | tail -5

# 12. Global lessons file
[ -f ~/.claude/LESSONS_UNIVERSAL.md ] && echo "✅ LESSONS_UNIVERSAL.md" || \
    echo "⚠️  Creating ~/.claude/LESSONS_UNIVERSAL.md" && \
    printf "# Universal Lessons\n> Patterns across 2+ projects.\n\n| Date | Pattern | Source Projects | Rule |\n|------|---------|----------------|------|\n" > ~/.claude/LESSONS_UNIVERSAL.md

# 13. Enforcement hooks deployed and executable
HOOK_COUNT=$(find .claude/hooks -name '*.sh' -perm +111 2>/dev/null | wc -l | tr -d ' ')
echo "✅ $HOOK_COUNT executable hooks" && [ "$HOOK_COUNT" -ge 11 ] || echo "❌ Expected 11+ hooks, found $HOOK_COUNT"

# 14. settings.json valid and wired
python3 -c "import json; d=json.load(open('.claude/settings.json')); print(f'✅ settings.json valid ({len(d.get(\"hooks\",{}))} hook events)')" 2>/dev/null || echo "❌ settings.json missing or invalid"

# 15. Custom agents defined
for d in .claude/agents/implementer .claude/agents/worker; do
    [ -f "$d"/*.md ] 2>/dev/null && echo "✅ $(basename $d) agent" || echo "❌ MISSING: $d agent"
done

# 16. Path rules deployed
RULE_COUNT=$(ls .claude/rules/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "✅ $RULE_COUNT rule files" && [ "$RULE_COUNT" -ge 3 ] || echo "❌ Expected 3+ rules, found $RULE_COUNT"

# 17. No hardcoded source project references
LEAKS=$(grep -rn 'chonkius\|MasterDashboard\|master_dashboard' . --include="*.sh" --include="*.md" --include="*.json" 2>/dev/null | grep -v '.git/' | grep -v 'node_modules/' | wc -l | tr -d ' ')
[ "$LEAKS" -eq 0 ] && echo "✅ No hardcoded references" || echo "❌ $LEAKS hardcoded reference(s) found"
```

**If ALL 17 pass:**
```
Bootstrap complete.
Signal: GREEN
Engine: ALL SYSTEMS OPERATIONAL (enforcement layer active)
First task: [task-id] — [title]
Orchestrator: claude-opus-4-6
Hooks: [N] active, settings.json wired
Launch: bash work.sh
```

Commit everything to git on `dev` branch with message: `bootstrap: full engine deployment complete`

**If ANY fail:** Report what failed, what to fix, do NOT mark bootstrap complete.

---

## Gotchas

These are failure modes discovered through real usage. Read before running activation.

- **Templates not installed.** The #1 failure. Phase A checks for `~/.claude/dev-framework/templates/` but users forget to run `/setup-templates` first. If missing, tell them immediately — don't try to proceed without templates.
- **Hardcoded paths leaking into new project.** When extracting templates from MasterDashboard, paths like `/Users/chonkius/Desktop/MasterDashboard/` can survive sed replacements. D7 check #10 catches this, but you should also grep for the source project name after every script copy.
- **`init-db` vs `health` confusion.** `bash db_queries.sh health` checks for existing tables but does NOT create them. If you run `health` on a fresh empty database, it will report missing tables but leave them missing. Always run `init-db` first, then `health` to verify.
- **`grep -c` double-output in pre-commit hook.** `grep -c` returns exit code 1 when there are zero matches — this triggers `|| echo 0`, producing `"0\n0"` = `"0 0"` as the variable value. `[ "0 0" -gt 3 ]` then fails with "integer expression expected". The fix (already in the template): remove `|| echo 0` and use `UNPROMOTED="${UNPROMOTED:-0}"` bash default instead. The canonical pre-commit pattern is: `UNPROMOTED=$(grep -cE "..." "$DIR/LESSONS_*.md" 2>/dev/null)` then `UNPROMOTED="${UNPROMOTED:-0}"`.
- **phase_ordinal() not updated.** The `%%PHASE_ORDINALS%%` marker appears in 3 places in db_queries.sh — only 2 need case blocks filled (the bash function and the SQL CASE). Location 3 uses a dynamic phase_gates query. Missing even one of the first two causes `db_queries.sh check` to return wrong verdicts. Always search `%%PHASE_ORDINALS%%` and verify all three locations are handled.
- **Empty build_summarizer.sh.** The template is a stub — you MUST generate real build commands for the project's tech stack. An empty build summarizer means pre-commit hooks silently pass, defeating the entire quality gate system.
- **Generating RULES.md without filling all placeholders.** If even one `%%PLACEHOLDER%%` survives, session_briefing.sh may error or produce garbage output. The D7 placeholder scan (check #6) is non-negotiable.
- **sqlite3 not available.** In some environments (Cowork sandbox, minimal containers), sqlite3 isn't installed. db_queries.sh will fail silently. Check `which sqlite3` in Phase A.
- **Skipping D11 verification.** Every time verification was skipped ("it should work"), something was broken. Run all 17 checks. The 3 minutes it takes saves hours of debugging in the first session.
- **Not making scripts executable.** `chmod +x *.sh` is easy to forget. If pre-commit hook isn't executable, git commit silently skips it — you think you have quality gates but you don't.
- **settings.json not generated.** Without this file, no hooks fire. This is the single most impactful failure mode — the entire enforcement layer is silently disabled. D8 is non-negotiable.
- **Hooks not executable.** `chmod +x .claude/hooks/*.sh` is easy to forget after copying templates. Hooks that aren't executable fail silently — Claude proceeds without enforcement, and you won't know until a gate is violated.
- **protect-databases.sh still has hardcoded DB names.** The `%%OWN_DB_PATTERNS%%` placeholder must be filled with the project's actual DB name(s) as a grep regex. If left unfilled, the hook blocks ALL DB writes including the project's own DB operations via db_queries.sh.

## On-Demand Hooks (Future Enhancement)

Skills can register hooks that activate only when the skill is called. Consider adding:

- **PreToolUse guard during D1-D11:** Block any Write/Edit to files outside the project directory — prevents accidentally modifying templates or other projects during engine deployment.
- **Skill usage logger:** A PreToolUse hook that logs when bootstrap-activate is invoked, helping measure plugin adoption and identify undertriggering.

Note: The core enforcement hooks (correction detection, delegation gate, architecture protection, DB safety, session lifecycle) are now fully deployed in D5. The items above are additional per-skill hooks, not yet implemented.

## Rules

- **Never skip the user review** of requirements.md and design.md. The annotation cycle is where ambiguity gets resolved.
- **The DB is the source of truth** for task state. Never manually edit markdown task lists.
- **The delegation map is mandatory** before any implementation begins.
- **All verification checks in D7 must pass.** The bootstrap is not complete until the engine is verified end-to-end.
