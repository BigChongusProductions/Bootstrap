# Placeholder Registry

Complete registry of all 39 %%PLACEHOLDER%% values and their derivation strategies.

---

## Auto-Derivable Placeholders (12 entries)

These can be extracted from context, documentation, or project structure without user input.

| # | Placeholder | Source | Files | Derivation |
|---|---|---|---|---|
| 1 | %%PROJECT_NORTH_STAR%% | Project specs | RULES.md (§ Project North Star) | Read spec.md or main README — the 1-line vision statement. If none exists, ask user: "What's this project's core purpose?" |
| 2 | %%TECH_STACK%% | package.json, setup.py, Cargo.toml, go.mod, swift files | RULES.md (§ Tech Stack) | Detect language/framework from root files. Format: "Node.js 20 + Next.js 15, TypeScript, Tailwind CSS" or equivalent for other stacks. |
| 3 | %%FIRST_PHASE%% | Task DB schema | RULES.md, AGENT_DELEGATION.md, db_queries.sh | Query DB: `SELECT DISTINCT phase FROM tasks ORDER BY phase_ordinal ASC LIMIT 1`. Fallback: "Phase 1" or read phase list from existing RULES.md. |
| 4 | %%MCP_SERVERS%% | Environment setup | RULES.md (§ MCP Servers & Plugins) | Run: `env \| grep -i mcp` or check ~/.claude/settings.json. List connected MCPs with brief capability. Format: table with Name, Capability, Cost. |
| 5 | %%GEMINI_MCP_TABLE%% | MCP servers | RULES.md (§ Gemini Integration) | Query which MCPs can delegate Gemini work (Sonnet context size, web search, image gen). Generate table: Task Type \| Gemini Tool \| When to Use. |
| 6 | %%VISUAL_VERIFICATION%% | Project type | RULES.md (§ Visual Verification) | If project is CLI/backend: "Not applicable — CLI project." If web/desktop UI: generate visual verification checklist and Playwright commands. |
| 7 | %%EXTRA_MANDATORY_SKILLS%% | Skill catalog | RULES.md (§ Cowork Quality Gates) | Query available skills matching project needs. List only skills that must run before merge. Format: Trigger \| Skill \| What Master Does. Default: "None additional" |
| 8 | %%RECOMMENDED_SKILLS%% | Skill catalog | RULES.md (§ Cowork Quality Gates) | Query skills recommended for new phases. Format: Trigger \| Skill \| What Master Does. Default: "None additional" |
| 9 | %%EXTRA_MODEL_DELEGATION%% | Tier mapping | AGENT_DELEGATION.md (§ Model Delegation) | If project uses Gemini/Grok/Ollama: add rows to delegation table. Default: leave empty (uses standard 6 tiers). |
| 10 | %%GITIGNORE_TABLE%% | Tech stack | RULES.md (§ .gitignore Audit) | Generate table of file patterns to ignore: Pattern \| Reason. Include: build artifacts, dependencies, secrets, cache, language-specific. Use tech stack to customize. |
| 11 | %%OUTPUT_VERIFICATION_GATE%% | Project type | RULES.md (§ Output Verification Gate) | If project has visual output: define visual gate. If data pipeline: define data integrity gate. If API: define contract gate. If none: "Not applicable." |
| 12 | %%TEAM_TOPOLOGY%% | Agent Teams config | RULES.md (§ Agent Teams) | If Agent Teams is INACTIVE: "Agent Teams mode is INACTIVE. Activate in ~/.claude/settings.json and restart." If ACTIVE: generate topology table. |

---

## User-Provided Placeholders (4 entries)

These require direct user input. Provide defaults if user doesn't answer.

| # | Placeholder | Question | Default | Files | Validation |
|---|---|---|---|---|---|
| 1 | %%COMMIT_FORMAT%% | "What commit message format does your team use?" | `type(scope): description\n\nBody (optional)\n\nCo-Authored-By: ...` | RULES.md (§ Git Branching) | Verify format includes type and scope. Run: `git log --oneline -5` to check existing commits. |
| 2 | %%BUILD_TEST_INSTRUCTIONS%% | "How do you build and test locally?" | Derive from tech stack. E.g., `npm run build && npm test` | RULES.md (§ Build & Test) | Run the command in a test session to verify it works. |
| 3 | %%CODE_STANDARDS%% | "What code quality tools do you use?" | Derive from tech stack. E.g., `ESLint, Prettier, TypeScript strict mode` | RULES.md (§ Code Standards) | Verify tools exist in package.json or config. Run pre-commit hook test. |
| 4 | %%PROJECT_STOP_RULES%% | "Are there project-specific STOP rules beyond universal rules?" | Default: "None beyond universal (see CLAUDE.md §10)" | RULES.md (§ STOP Rules — Project Specific) | If any given: list them explicitly. Verify they don't conflict with universal rules. |

---

## Template Customization (19 entries via sed)

These are string replacements applied across all bootstrap files via sed. User provides the custom values once; sed applies them everywhere.

| # | Template | Replacement | Files Affected | sed Pattern |
|---|---|---|---|---|
| 1 | `master_dashboard.db` | `[project].db` | db_queries.sh, session_briefing.sh, build_summarizer.sh, all shell scripts | `sed -i 's/master_dashboard\.db/[project].db/g'` |
| 2 | `master_dashboard` | `[project]` (kebab-case) | RULES.md, AGENT_DELEGATION.md, LESSONS.md, db_queries.sh paths | `sed -i 's/master_dashboard/[project]/g'` |
| 3 | `MasterDashboard` | `[Project Name]` (title case) | RULES.md prose, NEXT_SESSION.md, PROJECT_MEMORY.md | `sed -i 's/MasterDashboard/[Project Name]/g'` |
| 4 | `LESSONS_MASTER_DASHBOARD.md` | `LESSONS_[PROJECT].md` | RULES.md @-import, db_queries.sh, git hooks | `sed -i 's/LESSONS_MASTER_DASHBOARD/LESSONS_[PROJECT]/g'` |
| 5 | `MASTER_DASHBOARD_PROJECT_MEMORY.md` | `[PROJECT]_PROJECT_MEMORY.md` | RULES.md @-import | `sed -i 's/MASTER_DASHBOARD_PROJECT_MEMORY/[PROJECT]_PROJECT_MEMORY/g'` |
| 6 | `MASTER_DASHBOARD_RULES.md` | `[PROJECT]_RULES.md` | RULES.md @-import | `sed -i 's/MASTER_DASHBOARD_RULES/[PROJECT]_RULES/g'` |
| 7 | `/Users/chonkius/Desktop/MasterDashboard` | `[actual project path]` (absolute) | All shell scripts (db_queries.sh, session_briefing.sh, etc.) | `sed -i 's\|/Users/chonkius/Desktop/MasterDashboard\|[path]\|g'` |
| 8 | `main` branch | Keep as-is | RULES.md (§ Git Branching) | If project uses different default: `sed -i 's/\bmain\b/[branch]/g'` |
| 9 | `dev` branch | Keep as-is OR customize | RULES.md (§ Git Branching) | If project uses different: `sed -i 's/\bdev\b/[branch]/g'` |
| 10 | "Master Dashboard" (title) | Project display name | README, RULES.md intro, NEXT_SESSION.md | `sed -i 's/Master Dashboard/[Display Name]/g'` |
| 11 | `%%OWN_DB_PATTERNS%%` | `project_name\.db` regex pattern | `.claude/hooks/protect-databases.sh` | Fill with project DB name(s) as grep regex, e.g. `my_project\.db\|news\.db` |
| 12 | `%%AGENT_NAMES%%` | Custom agent descriptions | `.claude/hooks/post-compact-recovery.sh` | Replace with formatted agent list for post-compaction recovery context |
| 13 | `%%TECH_STANDARDS%%` | Full tech standards block | `.claude/agents/implementer/implementer.md` | Multi-line: concurrency rules, type safety, framework specifics for the tech stack |
| 14 | `%%TECH_STANDARDS_BRIEF%%` | Brief tech standards | `.claude/agents/worker/worker.md` | 3-4 key rules for single-file worker |
| 15 | `%%PERMISSION_ALLOW%%` | Permission allow array | `.claude/settings.json` | JSON array of tool permission patterns, tech-stack-specific |
| 16 | `%%LOCAL_PERMISSIONS%%` | Local permission overrides | `.claude/settings.local.json` | Empty array by default, user fills for local needs |
| 17 | `%%LESSON_LOG_COMMAND%%` | Lesson logging command | `.claude/hooks/correction-detector.sh` | Default: `bash db_queries.sh log-lesson \"[what]\" \"[pattern]\" \"[rule]\"` |
| 18 | `%%TECH_STACK_HOOKS%%` | Tech-stack-specific hooks | `.claude/agents/implementer/implementer.md` | Hooks specific to the tech stack (e.g., `check-pbxproj.sh` for Swift), placed in implementer agent frontmatter |
| 19 | `%%PERMISSION_DENY%%` | Permission deny array | `.claude/settings.json` | Rarely customized — always includes `*.db`, `*.sqlite`, `*.sqlite3` |

**Verification command:**
```bash
grep -rn '%%' . --include="*.md" --include="*.sh"
```
Should return zero results after all replacements. If any remain, they're either custom placeholders (document separately) or missed during sed.

---

## Phase Ordinals (3 locations in db_queries.sh — 2 need filling)

The `%%PHASE_ORDINALS%%` marker appears in three places in db_queries.sh, but only **two need manual case blocks filled**:

- **Location 1** (~line 88): the `phase_ordinal()` bash function body
- **Location 2** (~line 807): the `(N - CASE t.phase ...)` SQL scoring formula. Set `N` = number of phases (e.g. `6` for 6-phase, `5` for 5-phase projects). This constant must match your phase count or smart-scoring will be off.
- **Location 3** (~line 1744): uses `SELECT DISTINCT phase FROM phase_gates` — dynamic, reads from DB at runtime. No filling needed; just ensure phase_gates is seeded.

Replace the `phase_ordinal()` case statement:

```bash
phase_ordinal() {
  case "$1" in
    "Phase 1") echo 1 ;;
    "Phase 2") echo 2 ;;
    "Phase 3") echo 3 ;;
    "Phase 4") echo 4 ;;
    *) echo 999 ;;  # Unknown phase
  esac
}
```

**Replace with actual phases:**
- List all unique phases from your task DB or RULES.md
- Assign numeric ordinals in execution order
- Use ordinals for phase gate logic and pre-task checks

**Verification:**
```bash
bash db_queries.sh phase        # Should list phases in ordinal order
bash db_queries.sh next         # Should respect phase_ordinal in task sorting
```

---

## Framework-Specific Placeholders (1)

### coherence_check.sh Skip Patterns

Replace %%SKIP_PATTERN_1%% and %%SKIP_PATTERN_2%% with project-specific paths to skip during coherence checks:

```bash
SKIP_PATTERNS=(
  "node_modules/*"
  ".git/*"
  "%%SKIP_PATTERN_1%%"     # Custom: e.g., "build/*", "dist/*"
  "%%SKIP_PATTERN_2%%"     # Custom: e.g., "coverage/*", ".next/*"
)
```

**Common values by tech stack:**
- Node.js: `"build/*" "dist/*" ".next/*" "coverage/*"`
- Python: `"venv/*" "__pycache__/*" ".pytest_cache/*"`
- Rust: `"target/*"`
- Swift: `".build/*" "Xcode*"`

**Verification:**
```bash
bash coherence_check.sh --quiet   # Should not warn about skipped dirs
```

---

## Hardcoded Paths Section

Multiple scripts contain absolute paths that must be customized for each project:

**Files to update:**
- `db_queries.sh` — Line ~15: `DB_PATH="/Users/chonkius/Desktop/MasterDashboard/[project].db"`
- `session_briefing.sh` — Line ~8: Same DB_PATH
- `build_summarizer.sh` — Line ~10: Same DB_PATH, plus build command path
- `work.sh` — Line ~5: Project root path
- `fix.sh` — Line ~5: Project root path
- All references to `/Users/chonkius/Desktop/MasterDashboard/NEXT_SESSION.md` → `[project_path]/NEXT_SESSION.md`

**Verification command:**
```bash
grep -rn 'chonkius\|MasterDashboard' . --include="*.sh"
```

Should return zero results if all paths were customized. Any matches indicate missed replacements.
