---
description: Start a new project with guided discovery interview
---

Activate the bootstrap-discovery skill to run a structured project discovery interview.

Check if `specs/ENVISION.md` already exists in the workspace. If it does and contains no "TODO" text, warn: "Specs already exist for this project. Running discovery again will overwrite them. Continue?" Wait for confirmation.

If no specs exist, proceed directly with the bootstrap-discovery skill interview flow.

The interview covers 4 rounds:
1. **Project Identity** — What it is, who it's for, where it runs
2. **Problem Space** — What it replaces, v1 scope, platform constraints
3. **Constraints & Resources** — Budget, available tools, integrations
4. **Framework Configuration** — Optional systems (visual verification, agent teams), STOP rules, orchestrator model

Produces 4 spec files: `ENVISION.md`, `RESEARCH.md`, `DECISIONS.md`, `FRAMEWORK.md` — plus a handoff document for Claude Code.
