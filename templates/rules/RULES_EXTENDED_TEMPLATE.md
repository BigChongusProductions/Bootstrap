# %%PROJECT_NAME%% — Extended Rules Reference
> On-demand reference. Not @-imported every session.
> These rules are hook-enforced, conditional, or rarely referenced mid-session.
> Load with: `read refs/rules-extended.md`

## Blocker Detection Rules

These rules apply continuously — at session start, before picking up each new task, and when task context changes.

### What counts as a blocker

- Any task assigned to Master or Gemini that is a prerequisite for the current or next Claude task
- Any task marked with `blocked_by` where the blocker is not DONE
- Any unresolved decision that downstream work depends on
- Any external action required (e.g., device testing, asset creation, third-party submission)

### When a blocker is detected

- **Do not silently skip it.** Do not work around it. Do not start dependent work hoping the blocker will resolve itself.
- Present the blocker clearly: what it is, who owns it, what depends on it.
- State that dependent work cannot proceed.
- Offer alternatives: resolve now, reprioritize, or explicit override.

### Override mechanism

If Master explicitly chooses to bypass a blocker:
- Log the override in the session (conversation context)
- The save-session skill captures it in NEXT_SESSION.md under "Overrides (active)"
- The override does NOT clear the blocker — it remains flagged until actually resolved

---

## Code Standards
%%CODE_STANDARDS%%

## Progressive Disclosure (refs/ sub-files)

Reference material lives in `refs/*.md` — loaded on demand, not every session. This keeps the main rules file under the 25K token bootstrap target.

Create refs as sections in this file outgrow ~50 lines. Common examples:
- `refs/tool-inventory.md` — full MCP tool catalog with budget limits
- `refs/phase-gate-protocol.md` — detailed gate logic
- `refs/skills-catalog.md` — skill-to-task routing rules
- `refs/planned-integrations.md` — researched but not-yet-implemented integrations

**Rule:** If a section in this file grows beyond ~50 lines of reference material, extract it to `refs/` and replace with a one-line pointer: `> 📂 Moved to refs/<name>.md — read when [trigger].`

---

## Tracking Files
After each task:
- Mark task DONE in the database: `bash db_queries.sh done <task-id>`
- Update `%%PROJECT_MEMORY_FILE%%` if anything structural changed (new files, new systems, architecture)
- Update `LEARNING_LOG.md` when any new tool, technique, MCP, plugin, skill, or workflow is configured or learned
- Update `LESSONS.md` after any correction from Master (per CLAUDE.md §9)
- Commit all changed files to git with a descriptive message
- At end of session, log it: `bash db_queries.sh log "Claude Code" "Summary of what happened"`

## Coherence Check (automatic on commit + manual after core edits)
The pre-commit hook runs `coherence_check.sh` automatically on every `git commit`. It scans all markdown files for stale references defined in `coherence_registry.sh`. **Zero tokens — pure shell.**

**Run manually after editing any core logic file:**
```bash
bash %%PROJECT_PATH%%/coherence_check.sh --fix
```

**When architecture changes** (new system, renamed concept, migrated tool):
1. Make your changes to the relevant files
2. Add ONE entry to `coherence_registry.sh` mapping the old phrase → new canonical form
3. Run `coherence_check.sh --fix` to confirm the old phrase is gone everywhere
4. Commit all together

The registry is the audit trail of every architectural decision. Adding an entry takes 3 lines.

## .gitignore Audit (automatic — contextual to what was just built)
After completing any task that introduces a new file type, SDK, secret, or toolchain, immediately audit and update `.gitignore`. Do NOT front-load speculative entries — only add what's relevant to what was actually just built.

%%GITIGNORE_TABLE%%

**Audit process:**
1. After completing the task, list new files introduced: `git status --short`
2. Check if any match patterns above or contain secrets
3. If yes — update `.gitignore` immediately, before committing the task output
4. Run `git check-ignore -v <file>` to verify new entries work
5. Commit the `.gitignore` update in the same atomic commit as the task

**Never commit:** API keys, provisioning profiles, `.env` files, secret tokens, private keys.

---

## Milestone Merge Gate
When a phase is complete, Master runs the gate script to confirm readiness before merging:

```bash
bash %%PROJECT_PATH%%/milestone_check.sh <PHASE>
```

**What it checks (in order):**
1. All tasks in the phase are DONE in the DB (MASTER/SKIP tasks don't block)
2. Current branch is `dev`
3. Working tree is clean (no uncommitted changes)
4. Build + tests pass (runs `build_summarizer.sh test`)
5. Coherence check is clean

**On all-pass:** prints the exact merge commands to copy-paste.
**On any failure:** prints what to fix. Never touches `main`.

**Rule:** Run a code review (paste `git diff main..dev`) before merging any phase that contains source code changes.

---

## Deployment Mode: Agent Tool ✅ ACTIVE

### Model Delegation
| Task Type | Model | Why |
|-----------|-------|-----|
| Architecture, code review, complex debugging | **You (Opus)** | Needs full-project reasoning |
| Feature implementation, new files from clear spec | **Sonnet sub-agent** | Good code quality, 5x cheaper |
| Repetitive edits, boilerplate, formatting, bulk renames | **Haiku sub-agent** | Fast, 20x cheaper, bounded tasks |
%%EXTRA_MODEL_DELEGATION%%

### Sub-Agent Spawn Syntax
Use frontmatter to set the model:
```markdown
---
model: haiku
---
[Task instructions here]
```
Options: `haiku`, `sonnet`, `opus`, `inherit` (default = same as parent)

### Sub-Agent Rules (supplements CLAUDE.md §4)
- Sub-agents can read files but should only modify files you explicitly tell them to
- If a sub-agent fails 2 times, take over the task yourself

### Budget Mode (optional)
For token-conscious sessions, Master can start Claude Code with the `opusplan` model:
```bash
cd %%PROJECT_PATH%% && claude --model opusplan --dangerously-skip-permissions
```
This uses **Opus for planning** (reads code, creates plan) and **Sonnet for execution** (writes code). Same quality architecture decisions, ~60% cheaper on implementation.

---

## Deployment Mode: Agent Teams ⬜ INACTIVE

### Prerequisites
```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"
}
```
Install tmux: `brew install tmux`
Restart Claude Code after config change.

### Team Topology
%%TEAM_TOPOLOGY%%

### Coordination Protocol
- **Assignment:** Orchestrator assigns work via teammate messages — teammates don't self-assign
- **Completion:** Teammates report back to Orchestrator when done — Orchestrator reviews before committing
- **File conflicts:** Orchestrator resolves — teammates never merge independently
- **Dependencies:** Use inter-teammate messages for handoffs

### Cost Awareness
- Agent Teams runs ~3-4x the tokens of Agent Tool mode
- Only use Teams when parallelism actually saves wall-clock time
- Single-file sequential work should still use Agent Tool, even when Teams is active

---

%%GEMINI_MCP_TABLE%%

## Visual Verification
%%VISUAL_VERIFICATION%%

## Cowork Quality Gates
Master runs these in Cowork (the desktop app) at specific trigger points.

### Mandatory Skills (run every time the trigger fires)
| Trigger | Skill | What Master does |
|---------|-------|-----------------|
| **Before every dev→main merge** | Code review | Paste `git diff main..dev` → structured review → fix on `dev` before merging |
%%EXTRA_MANDATORY_SKILLS%%

### Recommended Skills (run when starting a new phase)
| Trigger | Skill | What Master does |
|---------|-------|-----------------|
%%RECOMMENDED_SKILLS%%

## Context Window Management

Bootstrap target: **under 25K tokens**. Every token of instruction reduces space for actual code work.

### Rules

1. **Read PROJECT_MEMORY selectively.** Only read sections relevant to the current task — don't load the full file for every session.

2. **Status lives in the DB and NEXT_SESSION.md, not in prose files.** Never read PROJECT_MEMORY for status, progress, or "what's next." Query `db_queries.sh` instead.

3. **Sub-agents get minimal context.** When spawning sub-agents, pass ONLY: the task description, the specific file(s) to edit, and relevant architecture constraints. Never pass the full RULES or MEMORY files to a sub-agent.

4. **Compress completed phases.** After each phase gate passes, compress that phase's detailed PROJECT_MEMORY sections to a 3-line summary. Move details to archive. The code is the documentation for completed work.

5. **Keep instruction files stable for caching.** Prompt caching gives 90% discount on stable prefixes. Avoid editing the top half of rules files between sessions.

6. **Session length awareness.** If you've been working for many tasks and responses are getting slower or less accurate, wrap up the current task, commit, and suggest starting a new session.

---

## MCP Servers & Plugins Available
%%MCP_SERVERS%%
