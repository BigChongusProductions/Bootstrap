# Bootstrap Discovery — Spec Output Schemas

Reference file for `bootstrap-discovery` skill. Contains output format templates for all four spec files, quality rules, and correction checklist.

---

## Overview

The discovery process produces four spec files in sequence:

1. **ENVISION.md** — What and why (product vision)
2. **RESEARCH.md** — Market context and technical options
3. **DECISIONS.md** — Constrained choices (budget, tech stack, scope)
4. **FRAMEWORK.md** — Project infrastructure (systems, gates, models, workflows)

Each has a specific structure, quality standards, and validation rules.

---

## File 1: ENVISION.md

**Purpose:** Pitch the project to someone unfamiliar with it. Answer "what is this and why does it matter?"

**Audience:** Any reader (customer, stakeholder, developer new to project)

### Required Sections

#### Pitch (50-150 words)

One sentence summary + 2-3 sentences explaining the problem and solution.

**Template:**
```markdown
## The Pitch

[One-liner summarizing what this is]

[Problem statement: What does this solve or enable?]
[Who does it help?]
[Why now?]
```

**Quality gates:**
- No jargon (or jargon is explained)
- Customer-facing language (not technical)
- A non-technical reader would understand the value

#### Audience & Scale

Who uses this and how many.

**Template:**
```markdown
## Audience

**Primary users:** [role] (approximately [count])
**Usage pattern:** [frequency and context]
**Geographic/platform scope:** [if relevant]
```

#### Done Criteria (3-5 measurable outcomes)

What success looks like for v1. **Must be observable and measurable.**

**Template:**
```markdown
## Done Criteria

v1 is complete when:
- [ ] Users can [specific action] (verified by [test or observation])
- [ ] System handles [scale or edge case]
- [ ] Performance meets [threshold] (e.g., load time < 2s, 99.9% uptime)
- [ ] [Other critical outcome]
```

**Anti-patterns:**
- "UI is polished" ❌ (not measurable)
- "Users can create accounts" ✓ (observable)

#### What This Does NOT Do (Exclusions)

Explicit list of out-of-scope features or use cases.

**Template:**
```markdown
## Out of Scope (v1)

- [Feature] — why it's deferred
- [Use case] — why it's excluded
- [Integration] — why it's not included
```

**Quality gate:** At least 3 explicit exclusions. If you skip this, you haven't defined scope tightly enough.

#### What It Replaces or Improves

Prior solutions and why this is better.

**Template:**
```markdown
## What Changes

**Before:** [Current situation or tool]
**Problem with that:** [Gap or limitation]
**After:** [This project's solution]
**How it's better:** [Specific advantages]
```

---

## File 2: RESEARCH.md

**Purpose:** Ground decisions in evidence. Answer "are there existing solutions? What are the technical tradeoffs?"

**Audience:** Project team (technical and non-technical)

### Required Sections

#### Prior Art & Competitive Analysis

**Template:**
```markdown
## Existing Solutions

| Product | How it works | Strengths | Weaknesses | Price |
|---------|-------------|----------|-----------|-------|
| [Tool A] | [Brief description] | [Why it's good] | [Gap it leaves] | [Cost] |
| [Tool B] | [Brief description] | [Why it's good] | [Gap it leaves] | [Cost] |
| [Tool C] | [Brief description] | [Why it's good] | [Gap it leaves] | [Cost] |
```

**Quality gates:**
- Minimum 3 entries (no analysis with < 3 comparisons)
- Each tool is a real product (no made-up competitors)
- Weaknesses are specific (not just "not as good")
- Price is researched (not "unknown")

#### Data Sources

Where information came from.

**Template:**
```markdown
## Research Sources

- [Tool documentation link]
- [Pricing page link]
- [Industry report or article]
- [Expert interview or forum discussion]
```

**Quality gate:** Every claim about "existing tools" or market trends must cite a source.

#### Technical Options (if applicable)

For architectural or technology decisions, present 2-3 options with tradeoffs.

**Template:**
```markdown
## Technology Options

### Option A: [Approach]
- How it works: [Brief description]
- Pros: [2-3 specific advantages]
- Cons: [2-3 specific drawbacks]
- Cost/complexity: [Relative estimate]

### Option B: [Approach]
[Same structure]

### Option C: [Approach]
[Same structure]
```

**Quality gate:** Options differ meaningfully (not just "use React vs Vue"). Show actual tradeoffs.

#### Constraints & Limitations

What's known to be hard.

**Template:**
```markdown
## Known Constraints

**Technical:**
- [Limitation, sourced from Q3.2 or research]

**Regulatory/Domain:**
- [If payment, healthcare, security, etc., what applies?]

**Resource:**
- [Budget, team size, timeline]

**Market:**
- [User expectations, competitive pressure]
```

#### Open Questions

Decisions that still need research.

**Template:**
```markdown
## Unknowns Still To Resolve

1. [Question] — Who decides? Timeline?
2. [Question] — Who decides? Timeline?
3. [Question] — Who decides? Timeline?
```

**Quality gate:** Questions are answerable (not "should the color be blue?"). Each has an owner.

---

## File 3: DECISIONS.md

**Purpose:** Record the actual choices made. Answer "what are we building, with what, at what cost?"

**Audience:** Project team and future maintainers

### Required Sections

#### Cost Constraint Summary

Single clear statement about the budget.

**Template:**
```markdown
## Cost Constraint

**Development budget:** [$X or "unbounded"]
**Monthly operations budget:** [$X or "unbounded"]
**Key limitations:** [SaaS tools limited to tier X, infrastructure on-prem only, etc.]
**Constraint origin:** [Question Q3.1, or explicit business decision]
```

#### Tech Stack

Every significant technology choice with justification.

**Template:**
```markdown
## Tech Stack

| Component | Choice | Why | Trade-off Accepted |
|-----------|--------|-----|--------------------|
| Language | Node.js 20 | Constraint: team expertise; Prior Art: [Research.md section] | [What we're not using] |
| Frontend | React 18 | v1 scope requires interactivity; Prior Art: [option] is mainstream | jQuery or Vue (simpler alternatives rejected) |
| Database | Postgres | Constraint: on-prem only (Q3.2); Prior Art: [comparison] | NoSQL databases (considered but ACID matters here) |
| Hosting | [Docker on EC2] | Constraint: budget $X/month; Prior Art: [comparison] | Serverless (cold-start constraints) |
| [Other key choice] | [Choice] | [Why] | [What we're not using and why not] |
```

**Quality gates:**
- Every row has a "Why" that references Q3.1/Q3.2 or RESEARCH.md
- "Trade-off Accepted" column explains what was rejected
- No orphaned choices (if a choice appears here, it was researched)

#### Architecture Diagram (Full-tier projects only)

Visual representation of how systems connect.

**Template:**
```markdown
## System Architecture

[ASCII diagram or description of major components and data flow]

Example:
```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────┐       ┌──────────────┐
│   Node.js API   │◄─────►│  Postgres DB │
└─────────────────┘       └──────────────┘
       │
       │ Queue
       ▼
┌─────────────────┐
│  Background Job │
└─────────────────┘
```

**Quality gate:** 
- Diagram shows major components
- Data flows are clear
- External systems (databases, APIs, caches) are visible

#### Scope In / Scope Out

Explicit feature list (in-scope) and explicit exclusions (out-of-scope).

**Template:**
```markdown
## Scope Definition

### In Scope (v1)
- [Feature] — [brief description of what it includes]
- [Feature] — [brief description]
- [Feature] — [brief description]

### Out of Scope (v1, deferred to later phases)
- [Feature] — why: [reason]
- [Feature] — why: [reason]
- [Feature] — why: [reason]

### Explicitly Not In v1 (design decision)
- [Feature/integration] — why: [reason, e.g., "adds complexity without user value", "requires hardware we don't have"]
```

**Quality gate:**
- Nothing ambiguous (every feature clearly in or out)
- Scope matches v1 scope from interview (Q2.2)
- Deferral reasons are explicit ("later phase" or "never")

#### Key Decisions Log

Major decisions made during spec and their rationale.

**Template:**
```markdown
## Decision Log

| Decision | Options Considered | Chosen | Why |
|----------|-------------------|--------|-----|
| Frontend framework | React, Vue, Svelte | React | Team expertise (Q1 context) |
| Payment provider | Stripe, PayPal | Stripe | Budget constraint; ecosystem; docs |
| Mobile strategy | Native, React Native, Web | Web v1 | Scope (Q2.2); cost; team size |
| [Other major decision] | [Options] | [Choice] | [Justification] |
```

#### Phase Gate Check

Pre-flight verification that scope is feasible.

**Template:**
```markdown
## Phase Gate Verification

- [ ] All decisions have constraints backing them (DECISIONS.md review)
- [ ] Architecture diagram matches scope (if Full-tier)
- [ ] No conflicting tech choices (e.g., "AWS-only" + "on-prem database")
- [ ] Team can execute this (skills available or learnable)
- [ ] No unresolved blockers from interview
- [ ] Budget math checks out (estimated costs vs. Q3.1 constraint)
```

**Quality gate:** All checkboxes must be true before moving to FRAMEWORK.md. If any are false, resolve first.

---

## File 4: FRAMEWORK.md

**Purpose:** Define project infrastructure, workflows, gates, models, and quality rules.

**Audience:** Project orchestrator and team

### Required Sections

#### Engine Tier

Which engine tier to deploy. Determines the complexity of the workflow engine.

**Template:**
```markdown
## Engine Tier

- **tier:** Small | Full
- **rationale:** [Why this tier — project scope, duration, complexity]
```

**Tier definitions:**
- **Small** → Lite engine: 10-section RULES, 3 hooks, 16 CLI commands, no frameworks, no custom agents. Target: <5K tokens session-start context. For weekend projects, single-feature builds, 1-3 day efforts.
- **Full** → Full engine: 26+ section RULES, 11 hooks, 47+ CLI commands, 9 frameworks, custom agents. For multi-week builds, complex architectures, team coordination.

**Quality gate:** Tier is explicitly stated (not left blank). Rationale matches project scope from ENVISION.md.

#### Active Systems Checklist

Which frameworks are enabled for this project.

**Template:**
```markdown
## Active Systems

### Mandatory (always on)
- [x] Session Protocol — startup orientation, phase gates, task workflow
- [x] Correction Detection — log lessons after mistakes
- [x] Delegation Gates — plan before multi-step work
- [x] Phase Gates — verify completion before advancing phases
- [x] Quality Gates — lint + type + test on every commit

### Optional (project-specific)
- [x/–] Visual Verification — [enabled/disabled] because [reason from Q4.1]
- [x/–] Agent Teams mode — [enabled/disabled] because [reason from Q4.1]
```

**Quality gate:** At least one optional is explicitly decided (even if "disabled").

#### Conditional System Configuration

If any optional systems are enabled, configure them.

**If Visual Verification enabled:**

```markdown
### Visual Verification Configuration

**Trigger:** Tasks tagged `needs_browser=1` in DB
**Tools:** Playwright MCP for browser automation, Claude Vision for screenshot analysis
**Workflow:**
1. Ensure dev server running
2. Playwright: navigate to app URL
3. Playwright: take screenshot
4. Claude Vision: analyze for visual issues
5. If issues and iterations < 5 → fix → wait 2s → repeat
6. If clean or iterations ≥ 5 → present to Master

**Verification checklist:** Layout, spacing, colors, typography, interactive elements, animations, responsive behavior, dependent features
```

**If Agent Teams enabled:**

```markdown
### Agent Teams Configuration

**When to use:** Multiple independent features in parallel
**Topology:** [Orchestrator: Opus, Worker 1: Sonnet, Worker 2: Sonnet, etc.]
**Coordination:** Orchestrator assigns work, workers report completion
**Cost awareness:** ~3-4x tokens, only worth it if parallelism saves wall-clock time
**Conflict resolution:** Orchestrator resolves file conflicts
**Start command:**
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
cd [project-path] && claude --dangerously-skip-permissions
```
```

#### Project-Specific STOP Rules

Any custom rules that halt work (in addition to universal rules).

**Template:**
```markdown
## Project-Specific STOP Rules

- [Rule] (from Q4.2 or discovered during spec)
- [Rule]
- [Rule]

[If none]: No additional project-specific STOP rules beyond universal ones.
```

**Quality gate:** If user answered Q4.2 with rules, they appear here. If empty, note that.

#### Orchestrator Model

Which Claude model owns this project.

**Template:**
```markdown
## Orchestrator Model

**Primary orchestrator:** claude-opus-4-6 (Opus)
**Reason:** [Architecture decisions, ambiguous tradeoffs, or complexity of this project]

**Sub-agent tiers:**
- Sonnet (sonnet-4-6): [Feature types or file counts where Sonnet is used]
- Haiku (haiku-4-5): [Single-file, display-only, clear-spec work]
```

**Quality gate:** Model name is explicit (not "default"). Reason matches project complexity.

#### Budget Mode (if applicable)

If tight budget, provide the cost-optimized startup command.

**Template:**
```markdown
## Budget Mode (Optional)

For token-conscious sessions, start with:
```bash
cd [project-path] && claude --model opusplan --dangerously-skip-permissions
```

**What it does:** Opus plans (reads code, creates architecture), Sonnet executes (writes code). ~60% cheaper on implementation while preserving quality.

**When to use:** If monthly token budget is tight.
```

#### Cowork Quality Gates

Mandatory and recommended skills/verifications for this project.

**Template:**
```markdown
## Cowork Quality Gates

### Mandatory (run every time)

| Trigger | Skill | What Master Does |
|---------|-------|-----------------|
| Before every dev→main merge | Code review | Paste `git diff main..dev` → structured review → fix on `dev` before merging |
| [Other mandatory point] | [Skill] | [What Master does] |

### Recommended (run when starting a new phase)

| Trigger | Skill | When to Run |
|---------|-------|-----------|
| After Phase 1 complete | [Skill name] | [Condition, e.g., "after UI shell is built"] |
| [Other checkpoint] | [Skill] | [Condition] |

[If none recommended]: No additional recommended skills for this project.
```

**Quality gate:** 
- "Code review" mandatory gate is always listed for code-bearing projects
- Recommended gates match project type (visual projects get visual verification, data projects get data integrity checks)

#### Coherence Registry Entries

If this project has branded terms or architectural concepts that might drift, define them here.

**Template:**
```markdown
## Coherence Registry

Add to coherence_registry.sh when architecture changes:

```bash
# [Date] — Project [name] canonical terms
DEPRECATED_PATTERNS+=("old term or phrase")
CANONICAL_LABELS+=("new canonical form")
INTRODUCED_ON+=("[date]")
```

[If none at spec time]: Will be populated during development as architectural terms stabilize.
```

**Quality gate:** This can be empty at spec time (it's filled in as project evolves).

---

## Quality Rules (Apply to All Spec Files)

### Rule 1: No TODOs or Placeholders

Every `%%TAG%%` must be replaced with actual content. If you can't fill a section, delete it instead.

**Violation:** "%%TECH_STACK%%" appears in file → FIX before presenting
**Violation:** "[TBD]" or "TODO: finalize" → FIX before presenting

### Rule 2: No Vague Language

Scan for: "might", "could", "probably", "seems", "if we", "later", "possibly", "eventually"

**Violation:** "We might use caching later" → FIX to: "Caching deferred to Phase 2 (spec: Q2.2 listed as nice-to-have)"
**Violation:** "The UI should probably be intuitive" → FIX to: "Done criteria: users complete onboarding in < 2 minutes"

### Rule 3: Every Tech Choice References a Constraint

No orphaned technology decisions. Each "why" must trace back to a constraint or prior art analysis.

**Violation:** "We chose Node.js" with no "why" → ADD: constraint reference (Q3.2 team expertise) or RESEARCH.md section
**Violation:** Tech choice contradicts stated constraint → FIX the choice or the constraint

### Rule 4: Scope Has No Ambiguity

Every feature is clearly in-scope or out-of-scope. Gray areas are resolved before approval.

**Violation:** Feature list mentions "user accounts, possibly with social login" → FIX to: "User accounts with email required; social login deferred to Phase 2"
**Violation:** "Nice-to-have" features in "done criteria" → FIX: move to "deferred"

### Rule 5: Architecture Diagrams (Full-tier projects only)

Full-scope projects (enterprise, complex, 3+ core systems) must include an architecture diagram.

**Violation:** No diagram for Full-tier project → CREATE one (ASCII or Mermaid)
**Violation:** Diagram doesn't show data flow → REDRAW to include queries, APIs, queues

### Rule 6: Prior Art Must Be Researched

If a tool, framework, or pattern is claimed to be "existing" or "common", verify it exists.

**Violation:** "GraphQL is the industry standard" with no source → ADD: link to StackOverflow survey, GitHub trends, or similar evidence
**Violation:** Competitive product listed but not reviewed → RESEARCH: get pricing, features, weaknesses

### Rule 7: Decisions Are Traceable

Every decision in DECISIONS.md has a "why" that points to RESEARCH.md, Q3.1, Q3.2, or domain expertise.

**Violation:** "We chose AWS" with no justification → FIX: add why (cost, Q3.2 requirement, team experience)
**Violation:** Decision contradicts RESEARCH findings → FIX: either change decision or explain why research was wrong

### Rule 8: No Forward References

Don't reference tasks, phases, or features not yet defined.

**Violation:** "We'll handle scaling in Task PH-042" when PH-042 doesn't exist → DELETE or CREATE the task in the DB
**Violation:** "Phase 2 will add reporting" without Phase 2 specs → MOVE to explicit deferral section with dependencies

### Rule 9: Correction Pass Must Be Run

Before presenting specs to Master, run the correction pass (see interview-flow.md).

**Process:**
1. Review every rule above
2. Fix any violations
3. Run coherence check (if applicable)
4. Verify no %%TAGS%% remain
5. Present corrected specs

**Quality gate:** All corrections must pass before Master review.

---

## Validation Checklist

Use this before marking specs complete:

```markdown
## Pre-Approval Checklist

- [ ] ENVISION.md: Pitch is customer-facing (non-expert readable)
- [ ] ENVISION.md: Done criteria are measurable (not subjective)
- [ ] ENVISION.md: Exclusions section is substantial (3+ items)
- [ ] RESEARCH.md: Prior art table has 3+ competitors
- [ ] RESEARCH.md: All claims cite sources
- [ ] RESEARCH.md: Open questions are answerable
- [ ] DECISIONS.md: Tech stack table has "Why" and "Trade-off" columns
- [ ] DECISIONS.md: Architecture diagram present (Full-tier) or intentionally omitted (Quick)
- [ ] DECISIONS.md: Scope In/Out is comprehensive (nothing ambiguous)
- [ ] DECISIONS.md: Phase Gate Check box is complete
- [ ] FRAMEWORK.md: Active systems checklist is filled in
- [ ] FRAMEWORK.md: Orchestrator model is explicit (not "default")
- [ ] FRAMEWORK.md: No %%TAGS%% remain in any file
- [ ] FRAMEWORK.md: No vague language in any file
- [ ] All spec files follow Quality Rules 1-9
- [ ] Correction Pass has been run

GATE RULE: All checkboxes must be true to present to Master.
```

---

## Changelog

- 1.0: Initial creation with all four spec file schemas, quality rules, and validation checklist
