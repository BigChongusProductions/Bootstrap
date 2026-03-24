# %%PROJECT_NAME%% — Project Rules
> Auto-imported by CLAUDE.md. Contains all project-specific rules, workflows, and configurations.
> Cognitive rules (planning, thinking, quality, self-healing, etc.) live in CLAUDE.md — do NOT duplicate them here.

## Project North Star
> **%%PROJECT_NORTH_STAR%%**

## Session Start Protocol
> 📂 Core protocol in `~/.claude/frameworks/session-protocol.md`. Project-specific additions below.

- Also read `%%PROJECT_MEMORY_FILE%%` for technical context (focus on architecture sections — briefing covers status)
- Task details: `bash db_queries.sh task <id>`

---

## Phase Gate Protocol
> 📂 Moved to `refs/phase-gate-protocol.md` — read before any phase transition.

---

## Pre-Task Check
> 📂 Verdict logic (GO/CONFIRM/STOP) in `~/.claude/frameworks/phase-gates.md`.

```bash
bash %%PROJECT_PATH%%/db_queries.sh check <task-id>
```

**Do NOT evaluate conditions yourself. Run the script and follow its verdict.**

On CONFIRM approval: `bash db_queries.sh confirm <task-id>`

---

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

## Correction Detection Gate
> 📂 Full correction protocol: see `correction-protocol` framework (@import in CLAUDE.md).
> Use `bash db_queries.sh log-lesson "WHAT" "PATTERN" "RULE"` for atomic logging.

### Delegation Gate
> 📂 Full delegation rules: see `delegation` framework (@import in CLAUDE.md).

### Output Verification Gate (OPTIONAL — customize per project type)

%%OUTPUT_VERIFICATION_GATE%%

---

### Lesson Extraction (session end)

> Full extraction protocol: see `session-protocol` and `correction-protocol` frameworks.

Use `bash db_queries.sh log-lesson "WHAT" "PATTERN" "RULE"` for atomic logging.
Bootstrap escalation: `bash db_queries.sh log-lesson "WHAT" "PATTERN" "RULE" --bp template "templates/path"`

---

## STOP Rules (Project-Specific)
In addition to universal STOP rules in CLAUDE.md §10:
%%PROJECT_STOP_RULES%%

---

> **Extended rules** (blocker detection, deployment modes, milestone merge gate, coherence, .gitignore audit, code standards, tracking files, cowork gates, MCP servers): load `refs/rules-extended.md` when needed for these topics.
