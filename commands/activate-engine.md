---
description: Activate workflow engine from completed discovery specs
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

Activate the bootstrap-activate skill to transform completed discovery specs into a fully operational project with workflow engine.

This command runs 4 phases:

**Phase A — Validation**
- Verifies all 4 spec files exist (ENVISION.md, RESEARCH.md, DECISIONS.md, FRAMEWORK.md)
- Checks for zero TODO placeholders
- Confirms canonical template directory exists at `~/.claude/dev-framework/templates/`
- If templates missing, runs `/setup-templates` first

**Phase B — Specification**
- Generates requirements.md and design.md with user review cycles
- Copies framework files to project `frameworks/` directory
- Creates backup of any existing configuration

**Phase C — Planning**
- Creates task breakdown from design with 6-tier delegation map
- Populates the SQLite task database (auto-creates if needed)
- Generates AGENT_DELEGATION.md from DB

**Phase D — Engine Deployment**
- Deploys all workflow scripts (db_queries.sh, session_briefing.sh, save_session.sh, shared_signal.sh, etc.)
- Generates RULES.md with all 29 sections filled (was 28, +1 for loopback system)
- Creates CLAUDE.md with load-on-demand framework pattern (not @-imports)
- Deploys `.claude/hooks/` (12+ enforcement hooks — correction detection, delegation gate, architecture protection, DB safety, session lifecycle)
- Deploys `.claude/agents/` (implementer + worker custom agents with tech-stack-specific standards)
- Deploys `.claude/rules/` (path-specific rule files that auto-inject on matching file types)
- Generates `.claude/settings.json` (hook wiring + permissions) and `settings.local.json`
- Sets up tracking files, git hooks, and launch scripts
- Runs 17-check verification suite (was 11, expanded for enforcement layer)

Prerequisites: Run `/new-project` in Cowork first to complete the discovery interview.
