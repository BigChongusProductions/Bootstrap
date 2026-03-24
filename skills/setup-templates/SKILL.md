---
name: setup-templates
description: >
  Extract or generate canonical development framework templates from an existing project,
  or verify existing templates. Use when the user runs /setup-templates, says "extract templates",
  "set up templates", "generate templates", or needs to prepare the canonical template directory
  at ~/.claude/dev-framework/templates/ before running /activate-engine.
version: 0.1.0
---

# Setup Templates

Set up the canonical template directory at `~/.claude/dev-framework/templates/` that all bootstrapped projects copy from.

## Mode 1: Extract from existing project

If the user has an existing project with the full framework (like MasterDashboard), extract templates from it:

1. Ask which project directory to extract from (or use the current workspace if it has the framework files).

2. Copy these files to `~/.claude/dev-framework/templates/`, stripping project-specific values and replacing them with `%%PLACEHOLDER%%` tokens:

   **Workflow scripts** (strip absolute paths, DB names):
   - `db_queries.sh` → template with `%%PROJECT_DB%%`, `%%PROJECT_PATH%%`, phase ordinals
   - `session_briefing.sh` → template with `%%PROJECT_PATH%%`, `%%PROJECT_DB%%`
   - `build_summarizer.sh` → template with `%%BUILD_COMMANDS%%`
   - `milestone_check.sh` → template with `%%PROJECT_PATH%%`
   - `coherence_check.sh` → template with `%%SKIP_PATTERNS%%`
   - `coherence_registry.sh` → template (empty registry, seed format only)
   - `work.sh` → template with `%%PROJECT_PATH%%`
   - `fix.sh` → template with `%%PROJECT_PATH%%`
   - `harvest.sh` → template with `%%PROJECT_PATH%%`

   **Framework files** (copy as-is, these are project-agnostic):
   - `frameworks/coherence-system.md`
   - `frameworks/correction-protocol.md`
   - `frameworks/delegation.md`
   - `frameworks/falsification.md`
   - `frameworks/phase-gates.md`
   - `frameworks/quality-gates.md`
   - `frameworks/session-protocol.md`
   - `frameworks/visual-verification.md`

   **Rule templates** (strip project-specific content):
   - `RULES_TEMPLATE.md` → with all 29 sections, `%%PLACEHOLDER%%` tokens
   - `CLAUDE_TEMPLATE.md` → with load-on-demand framework pattern, `%%PROJECT%%` tokens

   **Hooks** (copy from `.claude/hooks/`, strip project-specific DB names, replace with `%%PLACEHOLDER%%` tokens):
   - All `.sh` hook files → templates with `%%PROJECT_DB%%`, `%%PROJECT_PATH%%`, `%%PROJECT_NAME%%`

   **Agents** (copy from `.claude/agents/`, strip project name and tech-specific standards):
   - `implementer.md` → template with `%%TECH_STACK%%`, `%%PROJECT_NAME%%`
   - `worker.md` → template with `%%TECH_STACK%%`, `%%PROJECT_NAME%%`

   **Rules** (copy from `.claude/rules/`, strip project name):
   - All rule files → templates with `%%PROJECT_NAME%%`, `%%TECH_STACK%%`

   **Settings** (copy `.claude/settings.json`, strip tech-specific permissions):
   - `settings.json` → template with `%%HOOK_EVENTS%%`, `%%PERMISSIONS%%`
   - `settings.local.json` → template with `%%LOCAL_OVERRIDES%%`

3. Verify extraction: count files, check for leftover project-specific strings (grep for old project name, absolute paths).

4. Report what was extracted and any manual cleanup needed.

## Mode 2: Generate from specification

If no existing project is available, generate minimal templates from the spec files:

1. Read `specs/BLUEPRINT.md` and `specs/INFRASTRUCTURE.md` for tech stack and framework choices.

2. Generate skeleton templates with correct structure but `%%PLACEHOLDER%%` tokens throughout.

3. These skeletons will be fully populated during `/activate-engine` Phase D.

## Mode 3: Verify existing templates

If `~/.claude/dev-framework/templates/` already exists, verify integrity:

1. Check all expected files are present (11 scripts + 9 frameworks + 9 rule templates + 12 hooks + 2 agents + 2 settings = 45 files minimum).
2. Verify no project-specific strings leaked into templates.
3. Report status.

After setup, report:
```
Templates installed: ~/.claude/dev-framework/templates/
  Scripts:    [X/11]
  Frameworks: [X/9]
  Rules:      [X/9]
  Hooks:      [X/12]
  Agents:     [X/2]
  Settings:   [X/2]
  Status:     [COMPLETE / X files missing]
```
