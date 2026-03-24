# project-bootstrap v0.3.0

Turns an empty folder into a fully operational development environment with 33 integrated systems — from discovery interview to working workflow engine. 100% coverage of the battle-tested framework from RomaniaBattles and MasterDashboard.

## What This Does

Two-step bootstrap:

1. **In Cowork** (`/new-project`): Interactive 4-round interview asks what you're building, who it's for, tech constraints, and framework preferences. Produces 4 spec files (ENVISION, RESEARCH, DECISIONS, FRAMEWORK) with zero TODOs.

2. **In Claude Code** (`/activate-engine`): Reads specs, generates requirements + design docs (with review cycles), breaks design into phased tasks, populates SQLite DB, then deploys the full engine — workflow scripts, RULES.md (28 core sections + loopback system), CLAUDE.md (@-import chain), 9 framework files, refs/ progressive disclosure directory, git hooks, tracking files, and launch scripts. Runs 12-check verification at the end.

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

- **bootstrap-discovery** — Cowork conversational interview (4 rounds, 10 questions, adaptive flow)
- **bootstrap-activate** — Claude Code engine deployment (4 phases: Validate → Specify → Plan → Deploy)

## Architecture

```
~/.claude/dev-framework/templates/    ← Canonical templates (shared across projects)
  ├── scripts/                        ← 10 workflow scripts with %%PLACEHOLDER%% tokens
  ├── frameworks/                     ← 9 framework files (project-agnostic)
  └── rules/                          ← RULES + CLAUDE template files

~/Desktop/MyProject/                  ← Your project (after /activate-engine)
  ├── CLAUDE.md                       ← Entry point (@-imports chain)
  ├── PROJECT_RULES.md                ← 29 sections, all placeholders filled
  ├── AGENT_DELEGATION.md             ← 6-tier model + task delegation map
  ├── LESSONS_PROJECT.md              ← Correction log + insights
  ├── PROJECT_MEMORY.md               ← Architecture decisions + context
  ├── LEARNING_LOG.md                 ← Tools and techniques learned
  ├── NEXT_SESSION.md                 ← Pre-computed session handoff
  ├── frameworks/                     ← 9 framework files
  │   ├── coherence-system.md
  │   ├── correction-protocol.md
  │   ├── delegation.md
  │   ├── falsification.md
  │   ├── loopback-system.md          ← NEW: full loopback reference
  │   ├── phase-gates.md
  │   ├── quality-gates.md
  │   ├── session-protocol.md
  │   └── visual-verification.md
  ├── refs/                           ← Progressive disclosure (on-demand)
  │   ├── tool-inventory.md           ← Master tool/MCP/plugin catalog
  │   ├── gotchas-workflow.md          ← Point-of-use warnings (grows over time)
  │   ├── gotchas-frontend.md          ← (if UI project)
  │   ├── skills-catalog.md            ← (if custom skills)
  │   └── planned-integrations.md      ← (if deferred integrations)
  ├── specs/                          ← 6 spec files from bootstrap
  ├── db_queries.sh                   ← 51 commands across 7 tiers
  ├── session_briefing.sh             ← Signal computation (GREEN/YELLOW/RED)
  ├── build_summarizer.sh             ← 4-level quality gates
  ├── milestone_check.sh              ← Phase merge verification
  ├── coherence_check.sh              ← Stale reference scanner
  ├── coherence_registry.sh           ← Deprecated pattern registry
  ├── harvest.sh                      ← Lesson promotion scanner
  ├── work.sh / fix.sh                ← Launch scripts
  ├── project.db                      ← SQLite task database
  └── .git/hooks/                     ← pre-commit + pre-push hooks
```

## Project Tiers

| Tier | Scope | What You Get |
|------|-------|-------------|
| Micro (< 2 hours) | Script, small tool | Skip bootstrap — just build it |
| Small (1-3 days) | Feature, weekend project | Abbreviated interview, basic specs, simple task list |
| Full (3+ days) | App, product, multi-week build | Complete interview, all specs, task DB, full 33-system engine |

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
- Templates live at `~/.claude/dev-framework/templates/` and are shared across all projects

## Requirements

- Claude Max plan (or Claude Code + Cowork access)
- sqlite3 on your machine (for Full-tier projects)
- git initialized in project directory

## Reference Files (in plugin)

| File | Purpose |
|------|---------|
| `loopback-system.md` | Full loopback system reference (severity, circuit breakers, gate-critical, analytics) |
| `refs-scaffolding.md` | How to set up progressive disclosure refs/ directory |
| `engine-deployment-guide.md` | Step-by-step engine deployment |
| `placeholder-registry.md` | All 30 %%PLACEHOLDER%% values with derivation sources |
| `protocol-checklist.md` | 29-section RULES.md verification + 51 db_queries.sh commands |
| `quality-gates-guide.md` | Per-tech-stack quality gate implementations |
| `phase-planning-guide.md` | Phase templates, task breakdown rules, CLAUDE.md template |
| `interview-flow.md` | Discovery interview question bank + adaptive rules |
| `spec-output-schemas.md` | Schema for all 4 spec files |

## Changelog

### v0.3.0
- Added `loopback-system.md` as 9th framework file (full S1-S4 system reference)
- Added `refs-scaffolding.md` for progressive disclosure directory setup
- Added gotcha generation protocol to lesson extraction (refs/gotchas-*.md)
- Added refs/ directory scaffolding to engine deployment (tool-inventory, skills-catalog, gotchas)
- Added harvest.sh to template script list (10 scripts total)
- D7 verification expanded to 12 checks (added refs/ and loopback verification)
- RULES.md expanded to 29 sections (added Loopback System)
- 100% coverage against Battles framework reference

### v0.2.0
- Added Phase D (Engine Deployment) with 7 sub-steps
- Added FRAMEWORK.md as 4th spec file
- Added Round 4 (Framework Configuration) to discovery interview
- Added `/setup-templates` command for canonical template management
- Coverage expanded from partial to 33/33 systems
- Added 5 new reference files (engine-deployment-guide, protocol-checklist, quality-gates-guide)
- 30 %%PLACEHOLDER%% values fully documented
- 51 db_queries.sh commands organized into 7 tiers

### v0.1.0
- Initial release: discovery interview + basic activate flow
