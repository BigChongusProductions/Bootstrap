---
framework: quality-gates
version: 2.0
extracted_from: production project (2026-03-21)
---

# Quality Gates Framework

## Automated Code Quality Gates

Four automated gates protect code quality at different stages.

### Gate 1 — Pre-commit Hook (automatic, every `git commit`)

Target: < 15 seconds. Blocks commit on failure.

| Check | Blocks? | Why |
|-------|---------|-----|
| Linter | **Yes** | Catches unused vars, bad patterns |
| Type checker | **Yes** | Catches type errors before branch |
| Tests | **Yes** | Catches data integrity violations, logic bugs |
| Coherence | **No** (warns) | Markdown staleness — important but not blocking |
| Knowledge health | **No** (warns) | Unpromoted lessons — nag only |

### Gate 2 — Pre-push Hook (automatic, every `git push`)

Target: ~30 seconds. Blocks push on failure.

Runs production build to catch anything pre-commit misses: import resolution, compilation issues, static generation failures.

### Gate 3 — Build Summarizer (manual, on demand)

```bash
bash build_summarizer.sh build   # Quick: lint + types + build
bash build_summarizer.sh test    # Full: lint + types + build + tests + coherence
```

Use `test` mode before marking a phase as complete.

### Gate 4 — Milestone Check (manual, before merge)

```bash
bash milestone_check.sh <PHASE>
```

Runs: task completion audit → branch check → clean tree → coherence → build+test → prints merge commands on success.

## When Each Gate Runs

| Trigger | Gate |
|---------|------|
| `git commit` | Pre-commit hook |
| `git push` | Pre-push hook |
| End of task | `build_summarizer.sh test` |
| End of phase | `milestone_check.sh <PHASE>` |

**Rule:** Every commit must pass lint + types + tests. If any fail, fix before committing.

---

## Mandatory Structural Gates (Process)

Three behavioral gates that enforce process discipline. These are not automated hooks — they are structural rules enforced by the orchestrator.

### Correction Detection Gate

**Trigger:** ANY user message that contains correction signals (didn't work, failed, wrong, broken, not right, why didn't you, redirects, frustration).

**Protocol:**
1. **FIRST tool call** in response MUST be an Edit to the project LESSONS file adding the correction
2. If unsure whether it's a correction — log it anyway (false positives are cheap)
3. Only AFTER the lesson is written, proceed to diagnose and fix

**Why FIRST?** Every previous failure followed: understand → diagnose → fix → forget to log. Making the log first prevents the fix impulse from preempting it.

### Delegation Gate

**Trigger:** ANY multi-step task (2+ subtasks, 3+ files, both analysis and implementation).

**Protocol:**
1. **FIRST output** MUST be a delegation table: `| Task | Tier | Why |`
2. No Agent, Edit, Write, or Bash (non-diagnostic) calls until the table is presented
3. Wait for Master approval before spawning agents or starting work
4. Reading files to inform the plan is allowed

**Detection heuristics — treat as multi-step if ANY match:**
- User asks for "review", "audit", "test", or "verify"
- User gives 2+ distinct instructions in one message
- The task spans multiple components or concerns
- You find yourself thinking "first I'll do X, then Y"

### Visual Verification Gate (OPTIONAL — for projects with visual UI)

**Skip this gate** if your project has no visual components (CLI tools, backends, data pipelines, libraries).

**Trigger:** ANY multi-unit visual work (2+ visual changes, or changes across 3+ rendering files).

**Protocol:**
1. **BEFORE first edit:** Capture baseline state (screenshot or test run)
2. **After each logical visual unit:** Take screenshot + visual check
3. **Cannot mark visual work DONE** without running product verification

**Detection heuristics — treat as multi-unit if ANY match:**
- Editing CSS/styles, component layouts, or rendering logic
- Adding/modifying visual components across 3+ files
- Any task with `needs_browser=1` in the DB
- Plan contains multiple phases that each produce visible changes

**Alternatives for non-visual projects:**
- **Data Integrity Gate:** Verify transformations produce expected output after each unit
- **API Contract Gate:** Verify endpoints match schema after each change
- **Test Coverage Gate:** Verify test pass rate doesn't regress after each unit

## Changelog
- 2.0: Added 3 structural gates (Correction Detection, Delegation mandatory; Visual Verification optional)
- 1.0: Initial extraction from production project
