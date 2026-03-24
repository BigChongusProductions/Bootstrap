# %%PROJECT_NAME%% — Project Entry Point
> Cognitive rules auto-loaded from ~/.claude/CLAUDE.md (global).
> Core frameworks loaded via @imports below. Extended rules in refs/rules-extended.md (on demand).

@~/.claude/frameworks/session-protocol.md
@~/.claude/frameworks/phase-gates.md
@~/.claude/frameworks/correction-protocol.md
@~/.claude/frameworks/delegation.md
@%%RULES_FILE%%
@AGENT_DELEGATION.md

> **Optional frameworks** (add @import lines above to enable):
> `coherence-system`, `falsification`, `loopback-system`, `quality-gates`, `visual-verification`
> Example: `@~/.claude/frameworks/quality-gates.md`

> LESSONS file (`%%LESSONS_FILE%%`) is NOT @-imported — it grows unboundedly.
> The session-start hook injects recent lessons. Read full file on demand for correction protocol.
> Path-specific rules in `.claude/rules/` auto-inject when touching matching files.
> Hooks in `.claude/hooks/` enforce behavioral gates. Custom agents in `.claude/agents/`.
