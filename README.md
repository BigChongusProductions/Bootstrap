# project-bootstrap v0.7.0

Turns an empty folder into a fully operational development environment with 33 integrated systems — from discovery interview to working workflow engine. Battle-tested across RomaniaBattles, MasterDashboard, and TeaTimer.

## What This Does

Two-step bootstrap:

1. **In Cowork** (`/new-project`): Collaborative discovery process — you describe your idea, Claude researches feasibility, evaluates tech stacks, proposes architecture, and debates trade-offs with you. Produces 4 spec files (VISION, RESEARCH, BLUEPRINT, INFRASTRUCTURE) with zero TODOs.

2. **In Claude Code** (`/activate-engine`): Reads specs, generates requirements + design docs (with review cycles), breaks design into phased tasks, populates SQLite DB, then deploys the full engine — workflow scripts, RULES.md (@import deduplication), CLAUDE.md (@-import chain with 4 framework imports), AGENT_DELEGATION.md, refs/ progressive disclosure directory, hooks, custom agents, settings, git hooks, tracking files, and launch scripts. Runs 17-check verification at the end.

## Systems Covered (33/33)

Session protocol, phase gates, quality gates (4 levels), correction detection gate, delegation gate, visual verification gate, falsification protocol (4 layers), coherence system, **loopback system** (S1-S4 severity with circuit breakers), blocker detection, milestone merge gate, model gate, context window management, lesson tracking + promotion pipeline, **gotcha generation** (point-of-use warnings from lessons), agent delegation (6-tier model), pre-task check (GO/CONFIRM/STOP), learning log, project memory, **progressive disclosure** (refs/ directory with on-demand reference files), atomic commits, .gitignore audit, build summarizer, session briefing with signal (GREEN/YELLOW/RED), NEXT_SESSION handoff, coherence registry, harvest/promotion, and launch scripts.

## Commands

| Command | Where | What |
|---------|-------|------|
| `/new-project` | Cowork | Start discovery interview |
| `/activate-engine` | Claude Code | Deploy full engine from specs |
| `/spec-status` | Either | Check bootstrap progress |
| `/setup-templates` | Claude Code | Extract/generate canonical templates |

## Skills

- **bootstrap-discovery** — Collaborative discovery (open-ended conversation with real web research, tech evaluation, architecture design)
- **bootstrap-activate** — Claude Code engine deployment (4 phases: Validate → Specify → Plan → Deploy)

## Architecture

```
~/Projects/claude-project-bootstrap/  ← This repo (single source of truth)
  ├── .claude-plugin/plugin.json      ← Plugin manifest
  ├── bootstrap_project.sh            ← Main orchestrator script
  ├── commands/                       ← 4 slash commands
  ├── skills/                         ← 2 skills with reference docs
  ├── templates/                      ← Canonical templates
  │   ├── scripts/                    ← Workflow scripts + Python CLI (dbq/)
  │   ├── frameworks/                 ← 9 framework files (project-agnostic)
  │   ├── rules/                      ← RULES, CLAUDE, AGENT_DELEGATION templates
  │   ├── hooks/                      ← Behavioral enforcement hooks
  │   ├── agents/                     ← Sub-agent definitions (implementer, worker)
  │   └── settings/                   ← settings.json templates
  ├── tests/                          ← Bootstrap test suite
  └── backlog/                        ← Development backlog + apply script

~/.claude/                            ← Symlinks point here
  ├── plugins/marketplaces/.../project-bootstrap → this repo
  ├── dev-framework/templates → this repo/templates
  └── templates/bootstrap_project.sh → this repo/bootstrap_project.sh

~/Desktop/MyProject/                  ← Your project (after /activate-engine)
  ├── CLAUDE.md                       ← Entry point (4 @framework imports + @RULES + @DELEGATION)
  ├── PROJECT_RULES.md                ← Deduped — references frameworks, not inlines them
  ├── AGENT_DELEGATION.md             ← 6-tier model + task delegation map
  ├── refs/                           ← Progressive disclosure (on-demand)
  ├── specs/                          ← 6 spec files from bootstrap
  ├── .claude/hooks/                  ← 8+ behavioral enforcement hooks
  ├── .claude/agents/                 ← implementer + worker sub-agents
  ├── .claude/settings.json           ← Permissions + hook wiring
  ├── db_queries.sh                   ← 51 commands across 7 tiers
  ├── session_briefing.sh             ← Signal computation (GREEN/YELLOW/RED)
  ├── project.db                      ← SQLite task database
  └── (10+ more workflow scripts)
```

## Usage

```
1. Create a folder: ~/Desktop/MyProject
2. Open Cowork, select the folder
3. Say "new project" or run /new-project
4. Answer the interview questions (~10 minutes)
5. Open Claude Code in the same folder
6. Run /activate-engine
7. Review generated requirements and design docs
8. Approve the task breakdown
9. Engine deploys — start building
```

## First-Time Setup

Before your first `/activate-engine`, you need canonical templates:

- **Have an existing project?** Run `/setup-templates` to extract templates from it
- **Starting fresh?** `/activate-engine` will generate skeleton templates automatically
- Templates live at `~/.claude/dev-framework/templates/` (symlinked from this repo)

## Requirements

- Claude Max plan (or Claude Code + Cowork access)
- sqlite3 on your machine
- git initialized in project directory

## Reference Files (in plugin)

| File | Purpose |
|------|---------|
| `engine-deployment-guide.md` | Step-by-step engine deployment (Phase D) |
| `placeholder-registry.md` | All 30 %%PLACEHOLDER%% values with derivation sources |
| `protocol-checklist.md` | 29-section RULES.md verification + 51 db_queries.sh commands |
| `quality-gates-guide.md` | Per-tech-stack quality gate implementations |
| `phase-planning-guide.md` | Phase templates, task breakdown rules |
| `loopback-system.md` | Full loopback reference (severity, circuit breakers, gate-critical) |
| `refs-scaffolding.md` | Progressive disclosure refs/ directory setup |
| `interview-flow.md` | Discovery interview question bank + adaptive rules |
| `spec-output-schemas.md` | Schema for all 4 spec files |

## Changelog

### v0.6.1
- **Audit fixes** — added YAML header to loopback-system.md, removed dead `--frameworks` flag, fixed apply_backlog.sh path resolution, standardized framework source attribution, documented optional frameworks in CLAUDE_TEMPLATE.md
- **Non-interactive mode** — added `--non-interactive` flag to bootstrap_project.sh for unattended bootstrapping
- **E2E test** — added test_bootstrap_e2e.sh for full + quick lifecycle validation

### v0.6.0
- **Standalone repo** — extracted from ~/.claude/ into git-tracked repository with symlinks
- **Framework deduplication** — RULES_TEMPLATE.md now @imports frameworks instead of inlining (-56%, 285→126 lines)
- **RULES_EXTENDED_TEMPLATE.md** trimmed — removed blocker detection, context management, sub-agent rules now in frameworks (-25%, 216→163 lines)
- **CLAUDE_TEMPLATE.md** adds 4 framework @imports (session-protocol, phase-gates, correction-protocol, delegation)
- **New AGENT_DELEGATION_TEMPLATE.md** — extracted from production Romania Battles project (50 lines, fully deduped)
- **Removed Lite engine tier** — unified to single Full engine for all projects
- **Removed 5 Lite template files** (RULES_TEMPLATE_LITE, CLAUDE_TEMPLATE_LITE, db_queries_lite, settings_lite, session-start-check-lite)
- **Synced loopback-system.md** template to match deployed version (-45 lines)
- **bootstrap_project.sh** moved into repo (was only in ~/.claude/templates/)
- Description updated: mentions Python CLI and consolidated pre-edit hooks
- Added keywords: hooks, agents, settings, rules

### v0.5.0
- bootstrap-activate SKILL.md expanded (425→608 lines) — hooks, agents, settings, rules deployment
- 3 commands updated (activate-engine, setup-templates, spec-status)
- 4 reference files updated
- Plugin keywords expanded

### v0.4.0
- Removed end-session skill
- Updated placeholder-registry.md (+6 entries)

### v0.3.0
- Added loopback-system.md as 9th framework file
- Added refs-scaffolding.md for progressive disclosure
- Added gotcha generation protocol
- D7 verification expanded to 12 checks
- 100% coverage against Battles framework reference

### v0.2.0
- Added Phase D (Engine Deployment) with 7 sub-steps
- Added FRAMEWORK.md as 4th spec file (now INFRASTRUCTURE.md in v0.7.0)
- Added Round 4 (Framework Configuration) to discovery interview
- Added `/setup-templates` command
- 33/33 systems coverage
- 30 %%PLACEHOLDER%% values documented, 51 db_queries.sh commands

### v0.1.0
- Initial release: discovery interview + basic activate flow
