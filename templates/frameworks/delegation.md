---
framework: delegation
version: 2.2
extracted_from: production project (2026-03-21)
---

# Agent Delegation Framework

## The 6-Tier Model

| Tier | Model / Tool | Cost | Use When |
|------|-------------|------|----------|
| **Opus** (orchestrator) | `claude-opus-4-6` | $$$$ | Architecture decisions, gate reviews, ambiguous trade-offs, judgment calls, anything that failed at a lower tier |
| **Sonnet** (implementer) | `claude-sonnet-4-6` | $$ | Multi-file features from clear spec, components with non-trivial state/animation, tasks requiring cross-file reasoning |
| **Haiku** (mechanic) | `claude-haiku-4-5` | $ | Single-file bounded tasks, display-only components, config edits, JSON updates, mechanical wiring, clear spec with no judgment needed |
| **Gemini** (specialist) | via MCP | varies | Large context analysis, web research, factual cross-referencing, image generation, translation quality, second opinions |
| **Grok** (specialist) | via MCP | $ | X/Twitter search, real-time web search, cheap code review, Aurora image gen, second-opinion research, sandboxed Python |
| **Ollama** (local) | via MCP | free | Local language QA, semantic similarity, local inference. Unlimited (local GPU). Model varies by project needs. |
| **Skills** (workflow) | `/skill-name` | — | Structured workflows: `/frontend-design` for UI, `/feature-dev` for architecture, `/simplify` for cleanup, `/code-review` for PRs. Add project-specific verification skills as needed. |

## Effort Level Strategy

Effort levels control reasoning depth independently of model tier. Set via `/effort <level>` or `--effort <level>`.

| Effort | Use When | Cost |
|--------|----------|------|
| `low` | Status checks, simple queries, reading state | ~0.3x |
| `medium` | Standard implementation, routine work | ~1x (Opus default) |
| `high` | Multi-file features, cross-cutting changes, debugging | ~2x |
| `max` | Architecture decisions, phase gate audits, S1 circuit breaker acks, design reviews, falsification evaluation | ~3-5x (Opus only) |

**Orchestrator default:** `medium`. Escalate to `max` for judgment-heavy decisions.
**Sub-agent defaults:** Set via frontmatter — `effort: high` for implementer, `effort: medium` for worker.
**Session override:** `/effort max` before phase gate review, then `/effort medium` after.

## Pre-Phase Delegation Map (MANDATORY)

Before touching any file in a new phase or task batch, produce this table:

| Task ID | Title | Tier | Effort | Why |
|---------|-------|------|--------|-----|
| X-01 | ... | Sonnet | high | multi-file, non-trivial state |
| X-02 | ... | Haiku | medium | single display component |
| Gate | ... | Opus (direct) | max | architecture judgment |

**Rules:**
- **Haiku** if: single file, no imports from files being written in same batch, pure display or config, spec is 100% unambiguous
- **Sonnet** if: multiple files, uses store/hooks/animation, needs to reason across files
- **Opus** if: architectural decision, debugging unclear failure, trade-off with no obvious answer
- **Gemini** if: needs web/real-world knowledge, large file analysis, image generation, translation
- **Grok** if: X/Twitter search, real-time web, cheap fast inference, image gen
- **Ollama** if: local language QA, semantic similarity, zero-cost inference

**Never assign Haiku to:**
- Tasks where getting it wrong requires significant rework
- Tasks with complex animation or state logic
- Anything where context across 3+ files matters

## Milestone Gate Integration

The orchestrator MUST run `db_queries.sh check <task-id>` **before** spawning any sub-agent. The check returns three verdicts:
- **GO** → spawn the sub-agent
- **CONFIRM** → present milestone reasons + recent progress to Master, wait for "go", then spawn
- **STOP** → do not spawn, present blockers to Master

Sub-agents that independently run `check` and receive CONFIRM must return to the orchestrator without proceeding. They should never autonomously bypass a CONFIRM gate.

## Failure Escalation Protocol

### Step 1 — Diagnose the failure type

| Failure type | Signs | Action |
|---|---|---|
| Bad prompt | Agent did the wrong thing correctly | Rewrite instructions, retry same tier |
| Missing context | Agent referenced a file/type it couldn't find | Add missing file paths, retry same tier |
| Capability ceiling | Type errors, wrong architecture, logic mistakes | Escalate one tier up |
| Environment failure | Build failed, tool error | Fix environment, then retry |

### Step 2 — Escalation ladder

```
Haiku fails once  → diagnose → retry Haiku with better prompt
Haiku fails twice → escalate to Sonnet
Sonnet fails once → diagnose → retry Sonnet with better prompt
Sonnet fails twice → escalate to Opus (direct)
Opus handles it directly — no further sub-agents
```

### Step 3 — Log it

After any escalation, log: what task failed, which tier failed and why, what the correct tier was, whether the prompt or the model ceiling was the issue.

## Parallelism Rules

Sub-agents can run in parallel **only if** they write to different files.

**Safe:** Two agents writing different components. Research + implementation (different file paths).
**Never:** Two agents touching the same file. Agent B depends on Agent A's output. Two agents that both run the build (race condition on build cache).

## Human/AI Role Division

| Human (Master) Owns | AI (Claude) Owns |
|---|---|
| Vision — what to build and why | Research — gather options, compare trade-offs |
| Architecture — how components connect | Specs — formalize decisions into documents |
| Quality bar — decide what's good enough | Plans — break specs into atomic tasks |
| Scope decisions — what's in, what's out | Code — implement tasks from plans faithfully |
| Review every plan — annotate before approving | Tests — verify implementation matches spec |
| Say "no" often — to features, complexity, scope creep | Boilerplate — config, scaffolding, documentation |

**Key principle:** Human reviews plan, AI executes plan. Human owns the "what" and "why", AI owns the "how."

## Changelog
- 2.2: Added Effort Level Strategy section, effort column in pre-phase delegation map
- 2.1: Added Human/AI role division
- 2.0: Added Grok/Ollama tiers, milestone gate integration with GO/CONFIRM/STOP, parallelism build cache note
- 1.0: Initial extraction from production project
