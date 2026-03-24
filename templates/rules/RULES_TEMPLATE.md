# %%PROJECT_NAME%% — Project Rules
> Auto-imported by CLAUDE.md. Contains all project-specific rules, workflows, and configurations.
> Cognitive rules (planning, thinking, quality, self-healing, etc.) live in CLAUDE.md — do NOT duplicate them here.

## Project North Star
> **%%PROJECT_NORTH_STAR%%**

## Session Start Protocol

**This protocol is MANDATORY. Execute it before doing ANY work — no exceptions.**

Every session begins with an orientation step. Do not write code, do not start tasks, do not pick up where the last session left off until this protocol completes.

### Step 1 — Read State (silent, no output yet)

Run ALL of these before saying anything:

```bash
# a. Read the handoff file (pre-computed startup context from last session)
cat %%PROJECT_PATH%%/NEXT_SESSION.md

# b. Get current phase, blockers, gate status, and next tasks from DB
bash %%PROJECT_PATH%%/db_queries.sh phase
bash %%PROJECT_PATH%%/db_queries.sh blockers
bash %%PROJECT_PATH%%/db_queries.sh gate
bash %%PROJECT_PATH%%/db_queries.sh next

# c. Run the session briefing (phase status, git state, file health, coherence, SESSION SIGNAL)
bash %%PROJECT_PATH%%/session_briefing.sh

# d. Check git state
git -C %%PROJECT_PATH%% status --short
git -C %%PROJECT_PATH%% log --oneline -5
```

Then read `%%PROJECT_MEMORY_FILE%%` for technical context (focus on architecture sections — the briefing already covers status).

### Step 2 — Read the Signal (already computed)

The session signal (GREEN/YELLOW/RED) is computed deterministically by `session_briefing.sh` — it's in the briefing output from Step 1. **Do NOT evaluate the signal yourself. Read what the script produced.**

The signal logic checks:
- Whether any prior phase has incomplete tasks when the next Claude task is in a later phase → RED
- Whether the phase before the next Claude task's phase has been gated → RED if not
- Whether Master/Gemini tasks block Claude work → RED if all Claude tasks are blocked, YELLOW if some are
- Whether the next specific Claude task has an unresolved `blocked_by` → YELLOW

### Step 3 — Present Status Brief

Present the signal and briefing output to Master. Format:

```
📍 Phase: [from briefing] | Gate: [from briefing]
📋 Next up: [from briefing]
🚦 Signal: [from briefing — GREEN / YELLOW / RED]

[If YELLOW or RED: copy the reasons from the briefing output]
```

**On GREEN:** Present the brief and the recommended next task. Wait for Master to say "go."
**On YELLOW:** Flag the items, recommend whether to address now or defer. One question, not five. Wait for Master's call.
**On RED:** Present the blockers from the briefing output and state clearly: **"I cannot proceed with [dependent work] until [blocker] is resolved."** Offer options:
1. Resolve the blocker now (if it's something Claude can help with)
2. Reprioritize / reorder work to something unblocked
3. Explicitly override with a reason (the override gets logged in NEXT_SESSION.md)

**Wait for Master's confirmation before proceeding. Even on GREEN, get a "go" or acknowledgment.**

**Need full details for a task before starting it?**
```bash
bash %%PROJECT_PATH%%/db_queries.sh task <id>
```

---

## Phase Gate Protocol

**Triggers automatically when:** the next task to be worked on belongs to a phase beyond the last gated phase. This applies both at session start AND mid-session.

Phase gates are separate from the Milestone Merge Gate (which gates the dev→main merge). A phase gate verifies that all work in a phase is complete and meets quality standards BEFORE starting the next phase's work.

### Gate Review Process

When a phase transition is detected:

1. **Audit the completed phase** — List all tasks in the phase. For each: was it completed? Does the implementation match the intent? Any shortcuts taken?

2. **Categorize findings:**
   - **Must-fix** — Issues that will cause problems in later phases. These MUST be resolved before the gate passes. Examples: missing core functionality, broken tests, architectural decisions that will compound.
   - **Follow-up** — Improvements that are desirable but won't block later work. Create a task for these and tag them. Examples: code cleanup, minor UI polish, documentation gaps.

3. **Present the gate review:**
```
🚧 Phase Gate Review: [Phase Name]

Completed: [X/Y tasks]
Must-fix items: [list, or "None"]
Follow-up items: [list, or "None"]

[If must-fix items exist]: These must be resolved before we move to [next phase].
[If clean]: Phase gate passed. Ready to proceed to [next phase].
```

4. **Record the gate result** — Once passed, the gate is persisted in two places:
   - The `phase_gates` DB table (source of truth): `bash db_queries.sh gate-pass <PHASE>`
   - NEXT_SESSION.md `phase_gates_passed` field (written by save-session skill for fast startup reads)
   Once recorded, the gate is never re-audited.

---

## Pre-Task Check (deterministic, runs before each task)

Before starting any task, run the check command:
```bash
bash %%PROJECT_PATH%%/db_queries.sh check <task-id>
```

This script checks (in order):

**STOP checks (hard blockers):**
1. Is the task assigned to Claude? (STOP if Master/Gemini)
2. Does any prior phase have incomplete tasks? (STOP if yes)
3. Has the phase before this task's phase been gated? (STOP if not)
4. Is the task's `blocked_by` a **cross-phase** dependency that's unresolved? (STOP if not done)
   - Same-phase `blocked_by`: WARN hint only, not a STOP
   - Stale reference (nonexistent task): WARN with fix command, not a STOP

**Milestone gate (auto-detect, runs only when all STOP checks pass):**
5. Is this the first Claude task in a new phase? (CONFIRM if yes)
6. Does the previous task by sort order belong to Master/Gemini? (CONFIRM if yes)
7. Is this the last remaining Claude task in the phase? (CONFIRM if yes)
8. Have 5+ tasks been completed since the last structural checkpoint? (CONFIRM if yes)

Three possible verdicts:

**If the output says GO** — proceed with the task.
**If the output says CONFIRM** — present a summary of recent progress + the milestone reasons to Master. Wait for explicit "go" before proceeding. Once Master approves, run `bash db_queries.sh confirm <task-id>` to record the approval, then proceed.
**If the output says STOP** — present the reasons to Master. Do NOT proceed. Offer options: resolve the blocker, reprioritize, or override.

**Do NOT evaluate these conditions yourself. Run the script and follow its verdict.**

## Task Workflow
Work through tasks returned by `db_queries.sh next`, top to bottom.
- `next` shows interleaved sections: **circuit breaker** (S1 loopbacks), **S2 loopbacks**, **FORWARD (ready)**, **S3/S4 loopbacks**, and **BLOCKED**
- Tasks in READY: pick any — they're in suggested order but not rigidly sequenced
- Tasks in BLOCKED: the blocker, its owner, and status are shown — report to Master if all Claude work is blocked
- If ALL remaining Claude tasks are blocked on Master work, STOP and report to Master
- Mark each task done immediately after completing it:
  ```bash
  bash %%PROJECT_PATH%%/db_queries.sh done <task-id>
  ```
- To clear a stale or resolved blocker: `bash db_queries.sh unblock <task-id>`

### Adding New Tasks

**Quick capture (preferred during work):**
```bash
bash db_queries.sh quick "Fix layout bug on mobile" %%FIRST_PHASE%% bug
```
One command, zero follow-up. Creates an INBOX item with auto-generated `QK-xxxx` ID. Triage later.

**Loopback capture (fixing earlier-phase code):**
```bash
bash db_queries.sh quick "Fix validation regex" %%FIRST_PHASE%% bug --loopback %%FIRST_PHASE%% --severity 2 --reason "logic error"
```
Creates a loopback task (`LB-xxxx` ID) in a parallel track. Phase gates never reopen — loopbacks run alongside forward work. Severity: S1=critical (circuit breaker), S2=major, S3=minor (default), S4=cosmetic. Add `--gate-critical` for loopbacks that must be resolved before gating the discovered-in phase.

**Triage inbox items:**
```bash
bash db_queries.sh inbox                            # view untriaged
bash db_queries.sh triage QK-1234 <PHASE> sonnet    # promote to planned work
bash db_queries.sh triage QK-1234 loopback <ORIGIN> --severity 2  # triage as loopback
```

**Loopback commands:**
```bash
bash db_queries.sh loopbacks                        # view open loopback queue
bash db_queries.sh loopback-stats                   # analytics: origins, severity, hotspots
bash db_queries.sh ack-breaker LB-xxxx "reason"     # acknowledge S1 circuit breaker
bash db_queries.sh loopback-lesson LB-xxxx          # generate lesson from resolved loopback
bash db_queries.sh skip LB-xxxx "won't fix"         # mark loopback as WONTFIX
```

**Sync markdown from DB (replaces manual editing of delegation map):**
```bash
bash db_queries.sh delegation-md
```
This regenerates the delegation map in AGENT_DELEGATION.md. Run after triaging or adding tasks.

**Never edit the delegation map by hand.** The DB is the single source of truth. The markdown is a generated view.

## Tech Stack & Environment
%%TECH_STACK%%

## Git Branching
- **Always work on `dev`** — NEVER commit directly to `main`
- Before starting work, verify: `git branch` → should show `* dev`
- If on `main`, switch: `git checkout dev`
- Commit message format: %%COMMIT_FORMAT%%
- After completing the last task in a batch: `git log --oneline main..dev` to show Master what's ready
- **Do NOT merge dev → main** — that's Master's job after reviewing your work

## Build & Test
%%BUILD_TEST_INSTRUCTIONS%%

## Correction Detection Gate (MANDATORY — runs before every response)

**Before responding to ANY user message, scan it for correction signals:**
- User says something "didn't work", "failed", "wrong", "broken", "not right"
- User asks "why didn't you...", "why did you not...", "this does not..."
- User reports unexpected behavior or output
- User redirects you from what you were doing

**If correction signal detected → HARD GATE:**
1. **FIRST tool call** in your response MUST be an Edit to the project LESSONS file adding the correction. Not second. Not after diagnosis. FIRST.
2. If unsure whether it's a correction or just a question — log it anyway. False positives are cheap.
3. Only AFTER the lesson is written, proceed to diagnose and fix.

### Delegation Gate (MANDATORY — runs before any multi-step task)

**Before executing ANY user request, classify it:**
- **Single atomic task** (one file, one clear action) → proceed directly
- **Multi-step task** (2+ subtasks, or 3+ files, or both analysis and implementation) → HARD GATE

**If multi-step task detected → HARD GATE:**
1. **FIRST output** in your response MUST be a delegation table: `| Task | Tier | Why |`
2. No Agent, Edit, Write, or Bash (non-diagnostic) calls until the table is presented
3. Wait for Master approval before spawning agents or starting work
4. Reading files to inform the delegation plan is allowed

### Output Verification Gate (OPTIONAL — customize per project type)

%%OUTPUT_VERIFICATION_GATE%%

<!--
Choose ONE gate type for your project (or remove this section entirely):

FOR VISUAL/UI PROJECTS:
  Before starting multi-unit visual work:
  1. Capture baseline (screenshot or test run)
  2. After each logical unit: screenshot + visual check
  3. Cannot mark done without product verification

FOR API/BACKEND PROJECTS:
  Before starting multi-endpoint changes:
  1. Capture baseline (test suite run)
  2. After each endpoint change: run contract tests
  3. Cannot mark done without full integration test pass

FOR DATA PROJECTS:
  Before starting multi-transform changes:
  1. Capture baseline (sample output snapshot)
  2. After each transform: verify output matches expected
  3. Cannot mark done without data validation pass

FOR CLI/LIBRARY PROJECTS:
  Before starting multi-module changes:
  1. Capture baseline (test suite run)
  2. After each module: run unit tests
  3. Cannot mark done without full test pass
-->

---

### Lesson Extraction (session end)

Before writing the save-session report:
1. Scan conversation for corrections, retries, false assumptions, new tools, violated lessons, promotion candidates
2. Present proposed lessons categorized by type
3. Don't ask what to log — propose it yourself
4. Use `bash db_queries.sh log-lesson "WHAT" "PATTERN" "RULE"` for atomic logging
5. **Bootstrap escalation:** For each lesson, evaluate: does this affect how **new projects** should be set up? (template bugs, missing guards, process gaps). If yes:
   - Tag with `[BP:category]` in the lesson text (categories: template, framework, process, system)
   - Use `--bp` flag: `bash db_queries.sh log-lesson "WHAT" "PATTERN" "RULE" --bp template "templates/path"`
   - Or standalone: `bash db_queries.sh escalate "description" category "templates/path"`

---

## STOP Rules (Project-Specific)
In addition to universal STOP rules in CLAUDE.md §10:
%%PROJECT_STOP_RULES%%

---

> **Extended rules** (blocker detection, deployment modes, milestone merge gate, coherence, .gitignore audit, code standards, tracking files, cowork gates, context management, MCP servers): load `refs/rules-extended.md` when needed for these topics.
