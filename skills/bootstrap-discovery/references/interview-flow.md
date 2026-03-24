# Bootstrap Discovery — Interview Flow & Question Bank

Reference file for `bootstrap-discovery` skill. Contains all interview rounds, question templates, adaptive rules, and correction pass logic.

---

## Round 1: Project Identity

**Goal:** Establish what this project is, who it serves, and where it runs.

### Q1.1: What is this project?

**Type:** AskUserQuestion (open-ended, then classification)

**Prompt:**
```
What is this project? Describe it in 1-2 sentences.
(Examples: "A web app that tracks nutrition", "A CLI tool for batch image resizing", "An iOS app that analyzes sleep patterns")
```

**Classification (after answer):**
```
Is this best described as:
A) Web application (browser-based, runs on server)
B) Mobile app (iOS, Android, React Native)
C) Desktop application (native or Electron)
D) CLI tool (command-line interface)
E) Backend service / API
F) Library / SDK / Framework
G) Data pipeline / ETL tool
H) Other (describe)
```

**Store:** User's description + classification → `project_type` and `project_description`

**Adaptive:** If user is vague ("helps people do things"), ask one clarifying follow-up: "Can you give a concrete example of someone using it?"

---

### Q1.2: Who is this for? (Audience)

**Type:** AskUserQuestion

**Prompt:**
```
Who uses this project? Describe your primary audience:
- User role (e.g., "product managers", "photographers", "DevOps engineers")
- Estimated count or scale (e.g., "5-10 internal users", "thousands of customers")
- Usage context (e.g., "daily workflow", "occasional", "real-time")
```

**Store:** User's description → `primary_audience`, `user_scale`, `usage_frequency`

**Adaptive:** If "internal only", make note that scope can be smaller. If "thousands+", note that scale affects tech choices later.

---

### Q1.3: Where does it run?

**Type:** Multi-choice (with conditional follow-ups based on Q1.1 classification)

**Prompt template:**
```
Where does this [web app / mobile app / CLI / etc] run?
```

**Conditional options by project_type:**

**If Web:**
```
A) In the browser (frontend only, static hosting)
B) On a server I control (Node.js, Python, etc.)
C) Serverless (Lambda, CloudFunctions, etc.)
D) Combination of above
```

**If Mobile:**
```
A) iOS only
B) Android only
C) Both (native iOS + Android)
D) React Native / Flutter (cross-platform)
```

**If Desktop:**
```
A) macOS only
B) Windows only
C) Linux only
D) Multiple (macOS + Windows + Linux)
E) Using Electron / cross-platform framework
```

**If CLI / Backend / Library:**
```
A) Local development only (dev machine)
B) Server-side production (single deployment)
C) Distributed (multiple servers, container orchestration)
D) Package/library (installed by users)
```

**Store:** Selected option(s) → `deployment_target`, `platforms`

**Adaptive:** If multi-platform selected, note complexity increase. If serverless selected, note cold-start constraints.

---

## Round 2: Problem Space

**Goal:** Understand what problem this solves, what scope is realistic for v1, and any platform-specific constraints.

### Q2.1: What does this replace or improve?

**Type:** AskUserQuestion

**Prompt:**
```
What is this project replacing, improving, or enabling that doesn't exist today?
(Examples: "We currently use Slack + Google Sheets; this consolidates into one app", "No tool exists for this use case", "Existing tools are slow/expensive/hard to use")
```

**Store:** User's description → `problem_statement`, `prior_solution`

**Adaptive:** If "nothing exists", note that onboarding and UX education are larger. If "replacing tool X", ask what's better/different.

---

### Q2.2: What's realistic for v1?

**Type:** AskUserQuestion (open-ended, then structured scope definition)

**Prompt:**
```
What features MUST be in v1 for this to be useful?
List 3-5 core features (not the full vision, just the MVP).
```

**Then:**
```
For each feature, rate it:
- Critical (app is broken without it)
- Core (app is useful without it, but this adds major value)
- Nice-to-have (good to have, but can wait for v2)
```

**Store:** Feature list + priorities → `v1_scope`, `must_have_features`, `nice_to_have_features`

**Adaptive:** If scope is huge, help user trim. Use the "what would make a user say 'this is useful?'" test.

---

### Q2.3: Platform-specific constraints

**Type:** Conditional — only ask if answers to Q1.1 + Q1.3 indicate relevant constraints

**If Web (ask):**
```
Browser support requirements:
A) Modern browsers only (Chrome, Safari, Firefox latest 2 versions)
B) IE11 / older browser support required
```

**If Mobile (ask):**
```
iOS/Android version minimums:
A) Latest only (iOS 17+, Android 14+)
B) Go back 2-3 years (iOS 15+, Android 12+)
C) Maximum compatibility (iOS 12+, Android 8+)
```

**If Desktop (ask):**
```
macOS / Windows version minimums:
A) Latest OS only
B) Current + 2 previous major versions
C) Older support (maintain compatibility 5+ years back)
```

**Store:** Selected constraints → `platform_constraints`

**Adaptive:** If minimal support required, note that technical choices can be simpler. If maximum support needed, note that affects libraries, build tools, testing.

---

## Round 3: Constraints & Resources

**Goal:** Establish budget, available tools, and hard limits that affect tech stack decisions.

### Q3.1: Cost constraints

**Type:** AskUserQuestion (free text, then structured)

**Prompt:**
```
What are your cost constraints?
- Development cost (budget for building this)
- Hosting/operations cost (monthly budget for running it)
- Tool/service subscriptions (SaaS, APIs, paid libraries)
- Hard limits (e.g., "can't spend more than $X/month")
```

**Store:** User's answer → `budget_dev`, `budget_monthly`, `budget_constraints`

**Adaptive:** If no budget limit, note that can use premium tools. If tight budget, note that affects infrastructure choices (prefer managed services, avoid custom infrastructure).

---

### Q3.2: Available tools & integrations

**Type:** Structured checklist with AskUserQuestion

**Prompt:**
```
Which of these tools/services are already available or preferred?
(Check all that apply)

CRITICAL RULE: Do not assume tool availability. User must explicitly confirm which are:
A) Already integrated (system is currently using it)
B) Approved for use (team decision made)
C) Forbidden/unavailable (cannot use)

Tools to ask about:
- Cloud providers (AWS, GCP, Azure, DigitalOcean)
- Authentication (Auth0, Firebase Auth, Cognito, Okta)
- Databases (Postgres, MongoDB, Firebase, Supabase, DynamoDB)
- Payment (Stripe, PayPal)
- Search (Elasticsearch, Algolia, Meilisearch)
- Analytics (Segment, Amplitude, Mixpanel, internal logging)
- AI/ML (OpenAI, Anthropic, Gemini, local LLMs)
- Monitoring (Datadog, New Relic, Sentry)
- Collaboration (Slack integration, GitHub, etc.)
- Other critical dependencies
```

**Store:** Confirmed tools → `available_tools`, `tool_restrictions`

**Adaptive:** If user says "I don't know", help them inventory what's already in use (existing infrastructure, SaaS subscriptions, platforms they're already paying for).

---

## Round 4: Framework Configuration

**Goal:** Enable optional systems (visual verification, Agent Teams, project-specific STOP rules) and confirm orchestrator model + budget mode.

### Q4.1: Optional Systems

**Type:** Informational intro + multi-choice

**Prompt:**
```
This project uses several optional frameworks:

MANDATORY (always active):
- Session Protocol (startup orientation, phase gates, task workflow)
- Correction Detection (log lessons after mistakes)
- Delegation Gates (plan before multi-step work)
- Phase Gates (verify completion before advancing)
- Quality Gates (lint + type + test on every commit)

OPTIONAL (enable for specific project needs):

1) Visual Verification (for projects with UI)
   Used when: Project has visual components (web app, mobile app, desktop app)
   What it does: Automated screenshot + analysis after visual changes, Playwright integration
   Cost: Adds ~1-2 min to visual tasks for screenshot + verification
   Enable? (Y/N)

2) Agent Teams mode (for parallelizable work)
   Used when: Multiple sub-agents can work on different files simultaneously
   What it does: Runs multiple Claude instances in parallel instead of sequential sub-agents
   Cost: ~3-4x token usage, only worth it if parallelism saves wall-clock time
   Enable? (Y/N)
```

**Store:** Selections → `visual_verification_enabled`, `agent_teams_enabled`

**Adaptive:** 
- If project_type is Web/Mobile/Desktop and has visual components → recommend YES for visual verification
- If scope is large with many independent components → suggest Agent Teams for consideration
- If budget is tight → recommend NO to Agent Teams (higher token cost)

---

### Q4.2: Project-specific STOP rules

**Type:** AskUserQuestion (free text)

**Prompt:**
```
Are there any project-specific rules that should STOP work?
(Examples: "Never commit to main branch", "Never modify user data without approval", "Never deploy on Friday")

Leave blank if no additional rules.
```

**Store:** Rules (if any) → `project_stop_rules`

**Adaptive:** If user provides rules, add them to the MASTER_DASHBOARD_RULES.md after Spec is approved.

---

## Correction Pass Rules (Mandatory)

After each spec draft is completed, apply these corrections before presenting to user:

### Every Spec File

1. **No TODOs or placeholders** — if any `%%TAG%%` remains, replace with actual content or remove section
2. **No vague language** — scan for: "might", "could", "probably", "if we", "later". Replace with specific decisions.
3. **Every tech choice references a constraint** — each tech decision should trace back to Q3.1/Q3.2 or a document decision. If orphaned, remove or justify.
4. **No sections with < 3 words of content** — either expand or delete.

### ENVISION.md

5. **Pitch is customer-facing** — would someone outside the team understand it?
6. **Done criteria are measurable** — "users can X" not "UI is polished"
7. **Exclusions are explicit** — "What this does NOT do" section present and substantial

### RESEARCH.md

8. **Prior art table has 3+ entries** — comparative analysis, not just listing
9. **Data sources cited** — if claim about "existing tools", link or reference the tool
10. **Open questions are answerable** — not "what should the color be" (design decision, not research)

### DECISIONS.md

11. **Tech stack table justifies each choice** — every row has "Why" column referencing constraint or prior art
12. **Architecture diagram is present** (Full-tier projects) — visual representation of core components and data flow
13. **Scope in/out is exhaustive** — nothing ambiguous in "what counts as done"
14. **No forward references** — don't reference tasks not yet created

### FRAMEWORK.md

15. **Systems checklist is comprehensive** — all mandatory systems listed, optional ones match Q4.1 answers
16. **Orchestrator model is explicit** — not "default", but actual model name (Opus/Sonnet/Haiku)
17. **Budget mode command is copy-paste ready** — if provided, verify syntax matches real command
18. **Cowork quality gates are specific** — not vague (e.g., "Code review before merge" not "Review work")

---

## Adaptive Rules

### Skip Already-Answered Questions

If a question was answered in conversation (not via form), do NOT re-ask it. Example:
```
User (in intro): "This is a web app for photographers"
→ Skip Q1.1 entirely, move to Q1.2
```

### Handle "You Decide" Answers

If user says "I don't care" or "pick the best option":

1. Acknowledge the delegation
2. Make a decision aligned with:
   - Budget constraints (if tight → simpler/cheaper option)
   - Stated values (if user emphasized X, choose option supporting X)
   - Industry best practice (if no stated preference, choose most common/proven)
3. **Document the decision in the decision log** with reason: "User delegated, chose [X] because [Y]"
4. Flag for Master approval: "I chose X on your behalf — does this match your thinking?"

### Default to Smaller Scope

If user's v1 scope is unclear or seems large:

1. Summarize the scope in bullet points
2. Ask: "If you could only ship 2 of these, which 2 are most critical?"
3. Use their answer to trim scope
4. Explicitly list deferred features for future phases

### Handle Conflicting Answers

If user gives contradictory answers (e.g., "no budget" but "use premium SaaS"):

1. Reflect the conflict: "You mentioned tight budget but also suggested Stripe + Firebase. Let me clarify: which is the actual constraint?"
2. Don't assume — ask user to resolve
3. Document the resolution in decision log

---

## Interview Flow Order & Escape Hatches

**Default order:** Q1.1 → Q1.2 → Q1.3 → Q2.1 → Q2.2 → Q2.3 → Q3.1 → Q3.2 → Q4.1 → Q4.2

**Escape hatches** (user can skip entire Round):

- **Round 1:** If user says "I've already written detailed specs", offer to read them instead. Q1.1-Q1.3 covered → skip to Q2.1.
- **Round 2:** If user says "scope is locked", acknowledge and skip to Round 3.
- **Round 3:** If user says "cost is unlimited", record that and skip cost questions, ask only Q3.2.
- **Round 4:** If user says "keep defaults", record selections and skip detailed config questions.

**After all rounds:** Present the spec draft for approval before creating the files.

---

## Changelog

- 1.0: Initial creation with Rounds 1-4, Correction Pass rules, Adaptive Rules, and Interview Flow Order
