---
name: bootstrap-discovery
description: >
  Use this skill when the user says "I want to build something", "new project",
  "start a new project", "help me plan", "bootstrap a project", "scaffold this idea",
  or any phrase indicating they want to start a new project from scratch. Also trigger
  when the user runs /new-project. This skill runs an interactive discovery interview
  in Cowork that produces four spec files and a handoff document for Claude Code.
version: 0.2.0
---

# Bootstrap Discovery

Run an interactive interview to define a new project. Produce four spec files and a handoff document. Do NOT write any code or create project infrastructure — this is pure discovery.

## Prerequisites

Works in both Cowork and Claude Code. In Claude Code, the current working directory is the workspace. In Cowork, verify the user has a workspace folder selected.

## Step 0: Size the Project

Before anything else, classify scope. Use AskUserQuestion:

- **Micro** (< 2 hours): Single script, CLI tool, small component. Skip this skill — just build it.
- **Small** (1-3 days): Feature, integration, weekend project. Run abbreviated interview (Steps 1-2 only, skip Research).
- **Full** (3+ days): App, product, multi-week build. Run the complete interview.

If Micro, tell the user: "This is small enough to just start building. Open Claude Code and describe what you want." Exit the skill.

## Step 1: Vision Interview

Read `references/interview-flow.md` for the complete question bank. Run the interview using AskUserQuestion with concrete options and previews. The flow is adaptive — skip questions already answered by the user's initial request.

**Round 1 — Project Identity (3 questions max):**
Ask what this project is, who it's for, and where it runs. Use multi-choice with options tailored to common project types. Always include previews showing what each choice implies architecturally.

**Round 2 — Problem Space (2-3 questions, adaptive):**
Ask what this replaces (what manual process exists today), what v1 must include (multi-select from options you generate based on Round 1 answers), and any platform-specific decisions.

**Round 3 — Constraints & Resources (2 questions):**
Ask about cost constraints (hard limit on new spending?) and what tools/services/APIs the user already has access to. This is critical — verify what exists, don't assume. The user's correction about available tools is more valuable than your guess about what they need.

**After Round 3:** Draft the ENVISION.md spec from the conversation. Present a summary to the user. If they correct anything, update immediately. The correction pass is where the best insights emerge.

**Generate:** `specs/ENVISION.md` using the schema in `references/spec-output-schemas.md`.

## Step 2: Research (Full tier only)

For Full-tier projects, Claude performs research before the decisions interview:

1. **Prior art search** — Use web search to find existing tools/projects that solve a similar problem. Present findings as a table: what it does, what we can learn, why not just use it.
2. **Technical feasibility** — Based on the vision and constraints, verify that the chosen approach is viable. Flag any assumptions that need testing.
3. **Present options** — For key architectural decisions, present 2-3 approaches with tradeoffs using AskUserQuestion previews (ASCII architecture diagrams work well).

**Generate:** `specs/RESEARCH.md` using the schema in `references/spec-output-schemas.md`.

## Step 3: Decisions Interview

**Round 1 — Architecture & Tech Stack (2-3 questions):**
Based on vision + research, present concrete architecture options with previews. Include cost implications for each option. Cross-reference against the user's stated available tools — never recommend something that violates cost constraints.

**Round 2 — Scope Lock (1-2 questions):**
Present the proposed v1 scope. Ask: "Is anything here that shouldn't be in v1? Is anything missing?" Use multi-select for items to defer to v2+.

**Correction Pass:** Present the full DECISIONS.md draft. This is where architecture mistakes, cost assumptions, and tool availability issues get caught. The user has context you don't — let them correct.

**Generate:** `specs/DECISIONS.md` using the schema in `references/spec-output-schemas.md`.

## Step 4: Framework Configuration

After decisions are locked, configure which development framework systems this project needs. Most are mandatory (always on), some are conditional.

**Round 4 — Framework Systems (1-2 questions):**

Use AskUserQuestion. Present mandatory systems as pre-checked (informational — user sees what they're getting). Only ask about conditional systems:

Q4.1: "Your project will include all core development systems (session protocol, phase gates, quality gates, correction tracking, falsification, delegation model, coherence system, loopback tracking). These additional systems are optional:"
- Visual verification via Playwright MCP (for projects with UI — screenshots + automated visual checks)
- Agent Teams mode (experimental — parallel agents via tmux, 3-4x token cost)

Q4.2: "Any project-specific things Claude should NEVER do in this project?" (free text)

**Generate:** `specs/FRAMEWORK.md` using the schema in `references/spec-output-schemas.md`.

## Step 5: Validation & Handoff

1. Verify all four specs have no TODO placeholders remaining. If any do, loop back to the relevant interview step.

2. Create a `.bootstrap_mode` file in the project root containing the single word: `SPECIFICATION`

3. Generate `NEXT_SESSION.md` as the handoff document:

```markdown
# Next Session Handoff
_Last updated: [timestamp]_

## Handoff Source: COWORK
## Handoff Target: CLAUDE_CODE

## What was done (in Cowork)
Completed discovery interview. Vision, research, decisions, and framework configuration specs are filled.

## What to do next (in Claude Code)
1. Run /activate-engine
2. Review generated requirements.md
3. Review generated design.md
4. Approve task breakdown + delegation map
5. Verify engine deployment (all systems operational)
6. Begin implementation

## Specs completed
- [x] ENVISION.md
- [x] RESEARCH.md (or N/A for Small tier)
- [x] DECISIONS.md
- [x] FRAMEWORK.md

## Key constraints
[List the most important constraints from DECISIONS.md — cost, tools, platform]

## Framework configuration
[From FRAMEWORK.md — which optional systems active, project STOP rules]

## Phase gates passed
None yet.

## Overrides (active)
None.
```

4. Present to the user: "Discovery complete. Four specs are ready. Open Claude Code in this project folder and run `/activate-engine` to continue."

## Gotchas

These are failure modes discovered through real usage. Read before running the interview.

- **User says "I want to build X" and expects you to start coding.** This skill is pure discovery. If they want implementation, exit and tell them to open Claude Code. The mismatch happens ~30% of the time with new users.
- **Assuming tool availability.** Never say "we'll use Supabase" without confirming the user has access. Three false assumptions failed in the MasterDashboard planning session. Always verify with "which of these do you already have?"
- **Skipping the correction pass.** The draft review is where the best insights emerge. Users have context you can't infer — cost limits, existing contracts, team expertise. Every time the correction pass was skipped, specs had to be rewritten later.
- **Over-scoping v1.** Users naturally want everything. Push back. If v1 has more than 5-7 phases worth of work, it's too big. Defer to v2 aggressively.
- **Generating RESEARCH.md for Small-tier projects.** Small projects don't need research — it wastes 10 minutes of interview time. Skip directly to decisions.
- **Forgetting FRAMEWORK.md.** This was added in v0.2.0 and is easy to miss. Without it, `/activate-engine` can't know which optional systems to deploy.

## Rules

- **Never write code** during discovery. This is a conversation, not an implementation session.
- **The correction pass is mandatory.** Always present the full draft spec and ask the user to review. Their corrections reveal things you can't know.
- **Verify tool/service availability** — don't assume the user has access to something. Ask "which of these do you have?" with multi-select.
- **If the user's answer contradicts a previous decision**, update the earlier spec. Specs are drafts until the handoff.
