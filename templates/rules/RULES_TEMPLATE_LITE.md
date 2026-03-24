# %%PROJECT_NAME%% — Project Rules (Lite Engine)
> Auto-imported by CLAUDE.md. Simplified rules for Small-tier projects.
> Cognitive rules (planning, thinking, quality) live in ~/.claude/CLAUDE.md — do NOT duplicate here.

## Project North Star
> **%%PROJECT_NORTH_STAR%%**

## Session Start Protocol

**Mandatory. Execute before doing ANY work — no exceptions.**

1. **Read state** (silent, no output yet):
   ```bash
   cat %%PROJECT_PATH%%/NEXT_SESSION.md
   bash %%PROJECT_PATH%%/db_queries.sh next
   bash %%PROJECT_PATH%%/db_queries.sh status
   git -C %%PROJECT_PATH%% status --short
   git -C %%PROJECT_PATH%% log --oneline -5
   ```
2. **Present brief** to Master:
   ```
   Phase: [current] | Next: [task id + title]
   Git: [clean/dirty] | [any blockers or notes from NEXT_SESSION]
   ```
3. **Wait for Master's "go"** before starting any work.

---

## Phase Gate Protocol

When all tasks in a phase are DONE, gate the phase before starting the next:
1. `bash db_queries.sh status` — confirm all tasks complete
2. Present a summary of what was built in this phase
3. `bash db_queries.sh gate-pass <PHASE>` — record the gate (only after Master approves)
4. Proceed to next phase

---

## Task Workflow

Work through tasks from `db_queries.sh next`, top to bottom.

| Action | Command |
|--------|---------|
| See task queue | `bash db_queries.sh next` |
| Start a task | `bash db_queries.sh start <id>` |
| Complete a task | `bash db_queries.sh done <id>` |
| Skip a task | `bash db_queries.sh skip <id> "reason"` |
| View task details | `bash db_queries.sh task <id>` |
| Quick-add a task | `bash db_queries.sh quick "Title" <PHASE> [tag]` |
| Add structured task | `bash db_queries.sh add-task <id> <phase> "title" <tier>` |
| View board | `bash db_queries.sh board` |
| Project status | `bash db_queries.sh status` |

Mark each task done **immediately** after completing it. Don't batch.

---

## Tech Stack & Environment
%%TECH_STACK%%

## Git Branching
- **Always work on `dev`** — NEVER commit directly to `main`
- Before starting work, verify: `git branch` → should show `* dev`
- If on `main`, switch: `git checkout dev`
- Commit message format: %%COMMIT_FORMAT%%
- **Do NOT merge dev → main** — that's Master's job after reviewing the diff
- Before merging any phase: Master reviews `git diff main..dev`

## Build & Test
%%BUILD_TEST_INSTRUCTIONS%%

## Code Standards
%%CODE_STANDARDS%%

---

## Tracking Files

**After each task:**
- Mark done: `bash db_queries.sh done <id>`
- If anything structural changed (new files, new systems): update `%%PROJECT_MEMORY_FILE%%`
- After any correction from Master: update LESSONS file (see Correction Detection Gate)
- Commit to git with a descriptive message

**At session end:**
- Scan conversation for corrections, retries, false assumptions, new tools
- Log lessons: `bash db_queries.sh log-lesson "what happened" "pattern" "prevention rule"`
- Log the session: `bash db_queries.sh log "Claude Code" "summary of what happened"`
- Update `NEXT_SESSION.md` with: current phase, next task, any blockers, decisions made

---

## Correction Detection Gate

**Before responding to ANY user correction** (something didn't work, was wrong, broke):

1. **FIRST:** `bash db_queries.sh log-lesson "what happened" "pattern" "prevention rule"`
2. **THEN** diagnose and fix.

Never skip step 1. False positives are cheap; missed corrections compound.

---

## STOP Rules
In addition to universal STOP rules in ~/.claude/CLAUDE.md:
%%PROJECT_STOP_RULES%%

---

## MCP Servers & Plugins Available
%%MCP_SERVERS%%
