# %%PROJECT_NAME%% — Project Entry Point
> Cognitive rules auto-loaded from ~/.claude/CLAUDE.md (global).
> Project-specific rules imported below.

@%%RULES_FILE%%
@AGENT_DELEGATION.md

> LESSONS file (`%%LESSONS_FILE%%`) is NOT @-imported — it grows unboundedly.
> The session-start hook injects recent lessons. Read full file on demand for correction protocol.
> Frameworks live in `frameworks/`. Load on demand — see RULES §Frameworks.
> Path-specific rules in `.claude/rules/` auto-inject when touching matching files.
> Hooks in `.claude/hooks/` enforce behavioral gates. Custom agents in `.claude/agents/`.
