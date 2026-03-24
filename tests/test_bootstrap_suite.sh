#!/usr/bin/env bash
# =============================================================================
# Bootstrap Framework Test Suite
# Validates the bootstrap engine across 4 project archetypes
#
# Usage:
#   bash test_bootstrap_suite.sh               # Run full suite (all 4 projects)
#   bash test_bootstrap_suite.sh 1 3           # Run specific project(s) only
#   bash test_bootstrap_suite.sh --verify 1    # D7 verification only (project already exists)
#   bash test_bootstrap_suite.sh --exercise 1  # Workflow exercise only
#   bash test_bootstrap_suite.sh --cross       # Cross-project validation only
#   bash test_bootstrap_suite.sh --regression  # Template-level regression tests only
#   bash test_bootstrap_suite.sh --edge-hyphen # Edge case: hyphenated project name
#   bash test_bootstrap_suite.sh --python-cli  # Python CLI integration tests only
#   bash test_bootstrap_suite.sh --cleanup     # Remove all test_project dirs
#
# Creates: ~/Desktop/test_project{1..4}/
# =============================================================================

set -uo pipefail

# === PATHS ===================================================================
SUITE_DIR="$HOME/Desktop"
TEMPLATES="$HOME/.claude/dev-framework/templates"
TEMPLATE_SCRIPTS="$TEMPLATES/scripts"
TEMPLATE_FRAMEWORKS="$TEMPLATES/frameworks"
GLOBAL_FRAMEWORKS="$HOME/.claude/frameworks"
RULES_TEMPLATE="$TEMPLATES/rules/RULES_TEMPLATE.md"
CLAUDE_TEMPLATE="$TEMPLATES/rules/CLAUDE_TEMPLATE.md"

# === RESULT TRACKING =========================================================
TOTAL_CHECKS=0
TOTAL_PASS=0
TOTAL_FAIL=0
declare -a FAILURES=()

# === COLORS ==================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

# === HELPERS =================================================================
pass()    { TOTAL_CHECKS=$((TOTAL_CHECKS+1)); TOTAL_PASS=$((TOTAL_PASS+1));  echo -e "  ${GREEN}✅${RESET} $1"; }
fail()    { TOTAL_CHECKS=$((TOTAL_CHECKS+1)); TOTAL_FAIL=$((TOTAL_FAIL+1));  FAILURES+=("[$P_NAME] $1"); echo -e "  ${RED}❌${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}⚠️${RESET}  $1"; }
info()    { echo -e "  ${BLUE}ℹ️${RESET}  $1"; }
section() { echo -e "\n${BOLD}── $1 ─────────────────────────────────────────────${RESET}"; }
header()  { echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"; \
            echo -e "${BOLD}║  $1${RESET}"; \
            echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"; }

chk() {
  # chk "label" command_to_test
  local LABEL="$1"; shift
  TOTAL_CHECKS=$((TOTAL_CHECKS+1))
  if "$@" 2>/dev/null; then
    TOTAL_PASS=$((TOTAL_PASS+1)); echo -e "  ${GREEN}✅${RESET} $LABEL"
  else
    TOTAL_FAIL=$((TOTAL_FAIL+1)); FAILURES+=("[$P_NAME] $LABEL"); echo -e "  ${RED}❌${RESET} $LABEL"
  fi
}

# === PROJECT CONFIGURATIONS ==================================================
# Each project is defined by its own config function.
# Call: load_project_config N  (N = 1, 2, 3, or 4)

P_NUM=""       # project number (1-4)
P_DIR=""       # ~/Desktop/test_projectN
P_NAME=""      # display name e.g. TestWebApp
P_SLUG=""      # slug e.g. test_web_app
P_DB=""        # e.g. test_web_app.db
P_DB_NAME=""   # e.g. test_web_app (no .db)
P_LESSONS=""   # e.g. LESSONS_TEST_WEB_APP.md
P_RULES=""     # e.g. TEST_WEB_APP_RULES.md
P_MEMORY=""    # e.g. TEST_WEB_APP_PROJECT_MEMORY.md
P_PHASES=""    # space-separated: "P0-SETUP P1-CORE ..."
P_FIRST=""     # first phase name
P_SECOND=""    # second phase name (for loopback testing)
P_ORDINAL_MAX="" # max ordinal = phase_count - 1  (used in SQL formula)
P_HAS_UI=""    # YES / NO
P_HAS_GEMINI=""
P_HAS_TEAMS=""
P_HAS_SKILLS=""
P_HAS_DEFERRED=""
P_TIER=""      # Normal / Small

load_project_config() {
  P_NUM="$1"
  P_DIR="$SUITE_DIR/test_project${P_NUM}"

  case "$P_NUM" in
    1)
      P_NAME="TestWebApp"; P_SLUG="test_web_app"; P_TIER="Normal"
      P_DB="test_web_app.db"; P_DB_NAME="test_web_app"
      P_LESSONS="LESSONS_TEST_WEB_APP.md"; P_RULES="TEST_WEB_APP_RULES.md"
      P_MEMORY="TEST_WEB_APP_PROJECT_MEMORY.md"
      P_PHASES="P0-SETUP P1-CORE P2-VIEWS P3-DATA P4-INTEGRATION P5-SHIP"
      P_FIRST="P0-SETUP"; P_SECOND="P1-CORE"; P_ORDINAL_MAX="5"
      P_HAS_UI="YES"; P_HAS_GEMINI="YES"; P_HAS_TEAMS="NO"
      P_HAS_SKILLS="YES"; P_HAS_DEFERRED="YES"
      ;;
    2)
      P_NAME="RustCLI"; P_SLUG="rust_cli"; P_TIER="Small"
      P_DB="rust_cli.db"; P_DB_NAME="rust_cli"
      P_LESSONS="LESSONS_RUST_CLI.md"; P_RULES="RUST_CLI_RULES.md"
      P_MEMORY="RUST_CLI_PROJECT_MEMORY.md"
      P_PHASES="P0-INIT P1-PARSER P2-COMMANDS P3-POLISH P4-SHIP"
      P_FIRST="P0-INIT"; P_SECOND="P1-PARSER"; P_ORDINAL_MAX="4"
      P_HAS_UI="NO"; P_HAS_GEMINI="NO"; P_HAS_TEAMS="NO"
      P_HAS_SKILLS="NO"; P_HAS_DEFERRED="NO"
      ;;
    3)
      P_NAME="FastAPIService"; P_SLUG="fastapi_service"; P_TIER="Normal"
      P_DB="fastapi_service.db"; P_DB_NAME="fastapi_service"
      P_LESSONS="LESSONS_FASTAPI_SERVICE.md"; P_RULES="FASTAPI_SERVICE_RULES.md"
      P_MEMORY="FASTAPI_SERVICE_PROJECT_MEMORY.md"
      P_PHASES="P0-SCAFFOLD P1-MODELS P2-ENDPOINTS P3-AUTH P4-DEPLOY"
      P_FIRST="P0-SCAFFOLD"; P_SECOND="P1-MODELS"; P_ORDINAL_MAX="4"
      P_HAS_UI="NO"; P_HAS_GEMINI="YES"; P_HAS_TEAMS="YES"
      P_HAS_SKILLS="NO"; P_HAS_DEFERRED="YES"
      ;;
    4)
      P_NAME="SwiftDesktopApp"; P_SLUG="swift_desktop_app"; P_TIER="Normal"
      P_DB="swift_desktop_app.db"; P_DB_NAME="swift_desktop_app"
      P_LESSONS="LESSONS_SWIFT_DESKTOP_APP.md"; P_RULES="SWIFT_DESKTOP_APP_RULES.md"
      P_MEMORY="SWIFT_DESKTOP_APP_PROJECT_MEMORY.md"
      P_PHASES="P0-FOUNDATION P1-DATA P2-VIEWS P3-INTERACTIONS P4-POLISH P5-SHIP"
      P_FIRST="P0-FOUNDATION"; P_SECOND="P1-DATA"; P_ORDINAL_MAX="5"
      P_HAS_UI="YES"; P_HAS_GEMINI="NO"; P_HAS_TEAMS="NO"
      P_HAS_SKILLS="YES"; P_HAS_DEFERRED="NO"
      ;;
    *)
      echo "Unknown project number: $P_NUM" >&2; exit 1 ;;
  esac
}

# === PRE-FLIGHT CHECKS =======================================================
preflight() {
  header "Pre-flight Checks"
  local OK=1

  command -v sqlite3 >/dev/null || { echo -e "${RED}❌ sqlite3 not found${RESET}"; OK=0; }
  command -v python3 >/dev/null || { echo -e "${RED}❌ python3 not found${RESET}"; OK=0; }
  [ -f "$RULES_TEMPLATE" ]  || { echo -e "${RED}❌ RULES_TEMPLATE.md not found at $RULES_TEMPLATE${RESET}"; OK=0; }
  [ -f "$CLAUDE_TEMPLATE" ] || { echo -e "${RED}❌ CLAUDE_TEMPLATE.md not found at $CLAUDE_TEMPLATE${RESET}"; OK=0; }
  [ -f "$TEMPLATE_SCRIPTS/db_queries.template.sh" ] || { echo -e "${RED}❌ db_queries.template.sh not found${RESET}"; OK=0; }
  [ -f "$GLOBAL_FRAMEWORKS/loopback-system.md" ] || { echo -e "${RED}❌ loopback-system.md not found at $GLOBAL_FRAMEWORKS/${RESET}"; OK=0; }
  [ "$(ls $TEMPLATE_FRAMEWORKS/*.md 2>/dev/null | wc -l)" -ge 8 ] || \
    { echo -e "${RED}❌ Less than 8 framework files in $TEMPLATE_FRAMEWORKS${RESET}"; OK=0; }

  for d in 1 2 3 4; do
    if [ -d "$SUITE_DIR/test_project$d" ]; then
      echo -e "${YELLOW}⚠️  $SUITE_DIR/test_project$d already exists — run with --cleanup first${RESET}"
      OK=0
    fi
  done

  [ "$OK" = "1" ] && echo -e "${GREEN}✅ All pre-flight checks passed${RESET}" || \
    { echo -e "${RED}❌ Pre-flight failed — fix above before running${RESET}"; exit 1; }
}

# === SPEC CREATION ===========================================================
create_specs() {
  # Called after load_project_config N
  section "Creating specs for project $P_NUM: $P_NAME"
  mkdir -p "$P_DIR/specs"

  echo "SPECIFICATION" > "$P_DIR/.bootstrap_mode"

  case "$P_NUM" in
    1) create_specs_p1 ;;
    2) create_specs_p2 ;;
    3) create_specs_p3 ;;
    4) create_specs_p4 ;;
  esac

  cd "$P_DIR"
  git init -q && git checkout -q -b dev
  git -c user.email="test@test.com" -c user.name="TestSuite" add .
  git -c user.email="test@test.com" -c user.name="TestSuite" \
    commit -q -m "[BOOTSTRAP] Pre-filled specs for $P_NAME"
  info "Spec commit created on dev branch"
}

create_specs_p1() {
  cat > "$P_DIR/specs/VISION.md" << 'VISION_EOF'
# TestWebApp — Vision

## One-Paragraph Pitch
A web app for organizing browser bookmarks with tagging, full-text search, and import from browser exports. Personal tool, local SQLite backend, zero cloud dependency.

## Who Is This For?
Me — tired of losing bookmarks across browsers and devices.

## What Does "Done" Look Like?
1. I can add/tag/search bookmarks from a clean web UI
2. I can import bookmarks from a Chrome/Firefox HTML export
3. Full-text search finds the right bookmark in under 100ms

## What's NOT in v1
- Browser extension for one-click saving
- Cloud sync
VISION_EOF

  cat > "$P_DIR/specs/BLUEPRINT.md" << 'BLUEPRINT_EOF'
# TestWebApp — Decisions

## Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Language | TypeScript | Type safety, excellent Next.js integration |
| Framework | Next.js 14 (App Router) | Server components, API routes, single deployment |
| Database | SQLite (via better-sqlite3) | Local, zero config, fast reads |
| Styling | Tailwind CSS | Utility-first, fast iteration |
| Testing | Vitest + Playwright | Unit + E2E coverage |

## Scope — v1
1. Add/edit/delete bookmarks with URL, title, tags
2. Import from Chrome/Firefox HTML export
3. Full-text search across title + URL + tags
4. Tag management (create, rename, merge, delete)

## Key Decision
| Decision | Options | Chose | Why |
|----------|---------|-------|-----|
| Search | SQLite FTS5 vs Fuse.js vs Meilisearch | SQLite FTS5 | Zero extra infra, fast enough for <10k bookmarks |

## Gate Check
- [x] All decisions locked
BLUEPRINT_EOF

  cat > "$P_DIR/specs/INFRASTRUCTURE.md" << INFRASTRUCTURE_EOF
# TestWebApp — Framework Specification

## Project Identity
- **Project Name:** TestWebApp
- **Project Slug:** test_web_app
- **Project Path:** $P_DIR
- **DB Filename:** test_web_app.db
- **Lessons File:** LESSONS_TEST_WEB_APP.md
- **Rules File:** TEST_WEB_APP_RULES.md
- **Project Memory File:** TEST_WEB_APP_PROJECT_MEMORY.md
- **North Star:** Personal bookmark manager — fast full-text search, tag-based organization, local SQLite, zero cloud

## Tech Stack
- **Language:** TypeScript (Node.js 20)
- **Framework:** Next.js 14, App Router
- **Database:** SQLite (better-sqlite3)
- **Styling:** Tailwind CSS v3
- **Testing:** Vitest, Playwright
- **Build:** npm run build

## Phase Plan
| Phase ID | Name | Description | Key Deliverables |
|----------|------|-------------|-----------------|
| P0-SETUP | Foundation | Next.js scaffold, DB schema, git, TypeScript config | Working Next.js app, DB init, CI setup |
| P1-CORE | Core Data | DB layer, bookmark CRUD, basic API routes | All CRUD endpoints tested |
| P2-VIEWS | UI | Main pages: list, add, edit, search, tag view | Working UI with Tailwind |
| P3-DATA | Data Import | Chrome/Firefox HTML import, FTS5 indexing | Import works for real bookmarks |
| P4-INTEGRATION | Integration | Search UX, keyboard nav, performance tuning | <100ms search, smooth UX |
| P5-SHIP | Ship | Final testing, cleanup, docs | Clean build, passing E2E tests |

## Phase Ordinals
\`\`\`
P0-SETUP) echo 0 ;;
P1-CORE) echo 1 ;;
P2-VIEWS) echo 2 ;;
P3-DATA) echo 3 ;;
P4-INTEGRATION) echo 4 ;;
P5-SHIP) echo 5 ;;
\`\`\`

## Agent Workforce
| Tier | Model | Use For |
|------|-------|---------|
| Opus | claude-opus-4-6 | Architecture, design decisions, complex debugging |
| Sonnet | claude-sonnet-4-6 | Multi-file features, API routes, complex components |
| Haiku | claude-haiku-4-5 | Config, boilerplate, single-file fixes |
| Gemini | via MCP | Large context analysis, research |

## Build & Test
\`\`\`bash
npm run build 2>&1 | tail -20
npm test 2>&1 | tail -20
\`\`\`

## Commit Format
\`[PHASE] scope: description\` e.g. \`[P0-SETUP] db: add bookmark schema\`

## Code Standards
- TypeScript strict mode, no implicit any
- ESLint + Prettier enforced
- Tailwind: no inline styles, no custom CSS unless necessary

## Visual Verification
This project HAS visual UI — visual verification gate is ACTIVE. Use screenshots to verify layout after UI changes.

## MCP Servers Available
- Desktop Commander, Gemini MCP

## Project-Specific STOP Rules
- STOP before adding any cloud/paid dependency
- STOP before modifying existing bookmark data during import (append-only)

## Gitignore Patterns
| Pattern | Why |
|---------|-----|
| node_modules/ | npm dependencies |
| .next/ | Next.js build output |
| .env* | Environment secrets |
| *.db-journal, *.db-wal | SQLite temp files |
| .DS_Store | macOS metadata |
INFRASTRUCTURE_EOF

  cat > "$P_DIR/specs/RESEARCH.md" << 'RESEARCH_EOF'
# TestWebApp — Research

## SQLite FTS5 Performance
Full-text search with FTS5 handles 100k+ rows in <50ms on local hardware. Well-suited for personal bookmark databases (<10k entries).

## Next.js App Router vs Pages Router
App Router (Next.js 13+) provides better performance via React Server Components. Better for read-heavy UIs like bookmark lists. Server Actions simplify CRUD without separate API routes for simple cases.

## Import Format
Chrome and Firefox both export bookmarks as Netscape Bookmark Format HTML. The format is well-documented and parseable with a single-pass regex over DL/DT/A tags.
RESEARCH_EOF
}

create_specs_p2() {
  cat > "$P_DIR/specs/VISION.md" << 'VISION_EOF'
# RustCLI — Vision

## One-Paragraph Pitch
A fast CLI tool for bulk renaming files using pattern matching, regex substitution, and sequential numbering. Dry-run mode by default, shows preview before committing changes.

## Who Is This For?
Me — renaming photos, downloaded files, and project assets repeatedly.

## What Does "Done" Look Like?
1. `rename --pattern "*.jpg" --replace "photo_{n}" --start 1` renames with preview
2. Dry-run mode shows exact renames before executing
3. Undo last rename operation

## What's NOT in v1
- GUI
- Network filesystem support
VISION_EOF

  cat > "$P_DIR/specs/BLUEPRINT.md" << 'BLUEPRINT_EOF'
# RustCLI — Decisions

## Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Language | Rust 1.75+ | Fast, safe, single binary output |
| CLI parsing | clap 4.x | Industry standard, derive macros |
| File traversal | walkdir | Robust directory recursion |
| Regex | regex crate | Fastest Rust regex library |
| Testing | Rust built-in (cargo test) | No extra dep needed |

## Scope — v1
1. Pattern matching (glob + regex)
2. Sequential numbering with padding
3. Dry-run mode (default on)
4. Single-level and recursive modes

## Key Decision
| Decision | Options | Chose | Why |
|----------|---------|-------|-----|
| Undo mechanism | None vs rename-log file | Rename-log file | Simple, zero external deps |

## Gate Check
- [x] All decisions locked
BLUEPRINT_EOF

  cat > "$P_DIR/specs/INFRASTRUCTURE.md" << INFRASTRUCTURE_EOF
# RustCLI — Framework Specification

## Project Identity
- **Project Name:** RustCLI
- **Project Slug:** rust_cli
- **Project Path:** $P_DIR
- **DB Filename:** rust_cli.db
- **Lessons File:** LESSONS_RUST_CLI.md
- **Rules File:** RUST_CLI_RULES.md
- **Project Memory File:** RUST_CLI_PROJECT_MEMORY.md
- **North Star:** Fast, safe bulk file renamer — single binary, dry-run by default, zero dependencies beyond Rust stdlib

## Tech Stack
- **Language:** Rust 1.75+
- **CLI:** clap 4.x (derive feature)
- **File I/O:** walkdir + std::fs
- **Regex:** regex crate
- **Testing:** cargo test (built-in)
- **Build:** cargo build

## Phase Plan
| Phase ID | Name | Description | Key Deliverables |
|----------|------|-------------|-----------------|
| P0-INIT | Init | cargo new, clap setup, argument parsing | CLI parses all flags without logic |
| P1-PARSER | Pattern Parser | Glob + regex pattern engine | All pattern types parse correctly |
| P2-COMMANDS | Commands | Rename, dry-run, undo commands | Core functionality working |
| P3-POLISH | Polish | Error messages, edge cases, help text | User-friendly error output |
| P4-SHIP | Ship | Tests, docs, release binary | All tests pass, README complete |

## Phase Ordinals
\`\`\`
P0-INIT) echo 0 ;;
P1-PARSER) echo 1 ;;
P2-COMMANDS) echo 2 ;;
P3-POLISH) echo 3 ;;
P4-SHIP) echo 4 ;;
\`\`\`

## Agent Workforce
| Tier | Model | Use For |
|------|-------|---------|
| Opus | claude-opus-4-6 | Architecture, complex Rust patterns |
| Sonnet | claude-sonnet-4-6 | Multi-file features |
| Haiku | claude-haiku-4-5 | Single-file edits, boilerplate |

## Build & Test
\`\`\`bash
cargo build 2>&1 | tail -20
cargo test 2>&1 | tail -20
\`\`\`

## Commit Format
\`[PHASE] scope: description\` e.g. \`[P0-INIT] cli: add argument parsing\`

## Code Standards
- cargo clippy -- -D warnings (no warnings allowed)
- cargo fmt enforced
- No unwrap() in non-test code

## Visual Verification
Not applicable — CLI tool, no visual UI.

## MCP Servers Available
- Desktop Commander

## Project-Specific STOP Rules
- STOP before any file modifications without dry-run check
- STOP before adding any network calls (offline tool only)

## Gitignore Patterns
| Pattern | Why |
|---------|-----|
| target/ | Cargo build output |
| Cargo.lock | Lock file (binary project: include in repo; library: exclude) |
| *.db-journal, *.db-wal | SQLite temp files |
| .DS_Store | macOS metadata |
INFRASTRUCTURE_EOF

  # Small tier — RESEARCH.md is N/A
  cat > "$P_DIR/specs/RESEARCH.md" << 'RESEARCH_EOF'
# RustCLI — Research

> **Status:** N/A — Small project tier. No external research required.
> All technology choices are well-established (Rust, clap, walkdir).
RESEARCH_EOF
}

create_specs_p3() {
  cat > "$P_DIR/specs/VISION.md" << 'VISION_EOF'
# FastAPIService — Vision

## One-Paragraph Pitch
A REST API for managing notes with tags, full-text search, and Markdown rendering. Local-first, SQLite backend, Python/FastAPI. Consumed by a future UI or directly via curl/HTTPie.

## Who Is This For?
Me — a developer who wants a local note API that other tools can integrate with.

## What Does "Done" Look Like?
1. CRUD endpoints for notes work and return proper JSON
2. Full-text search endpoint finds relevant notes
3. Tag filtering returns correct results
4. JWT auth protects all write endpoints

## What's NOT in v1
- UI (API-only)
- Cloud hosting
VISION_EOF

  cat > "$P_DIR/specs/BLUEPRINT.md" << 'BLUEPRINT_EOF'
# FastAPIService — Decisions

## Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Language | Python 3.12 | Familiar, fast iteration |
| Framework | FastAPI | Modern, async, auto-docs |
| Package manager | Poetry | Deterministic deps, virtual env |
| ORM | SQLAlchemy 2.x | Type-safe queries, migration support |
| Database | SQLite | Local, zero infra |
| Auth | python-jose + passlib | JWT standard approach |
| Testing | pytest + httpx | FastAPI recommended |

## Scope — v1
1. Notes CRUD (create, read, update, delete)
2. Tags (many-to-many with notes)
3. Full-text search
4. JWT authentication (single user)

## Key Decision
| Decision | Options | Chose | Why |
|----------|---------|-------|-----|
| Auth | None vs API Key vs JWT | JWT | Standards-compliant, future-proof |

## Gate Check
- [x] All decisions locked
BLUEPRINT_EOF

  cat > "$P_DIR/specs/INFRASTRUCTURE.md" << INFRASTRUCTURE_EOF
# FastAPIService — Framework Specification

## Project Identity
- **Project Name:** FastAPIService
- **Project Slug:** fastapi_service
- **Project Path:** $P_DIR
- **DB Filename:** fastapi_service.db
- **Lessons File:** LESSONS_FASTAPI_SERVICE.md
- **Rules File:** FASTAPI_SERVICE_RULES.md
- **Project Memory File:** FASTAPI_SERVICE_PROJECT_MEMORY.md
- **North Star:** Local REST API for note management — FastAPI, SQLite, JWT auth, zero cloud dependency

## Tech Stack
- **Language:** Python 3.12
- **Framework:** FastAPI 0.109+
- **Package Manager:** Poetry
- **ORM:** SQLAlchemy 2.x (Core + ORM)
- **Auth:** python-jose, passlib[bcrypt]
- **Testing:** pytest, httpx (async test client)
- **Build:** poetry run pytest

## Phase Plan
| Phase ID | Name | Description | Key Deliverables |
|----------|------|-------------|-----------------|
| P0-SCAFFOLD | Scaffold | FastAPI app, DB schema, Poetry setup | Running app with /health endpoint |
| P1-MODELS | Models | SQLAlchemy models, migrations, CRUD functions | All models tested |
| P2-ENDPOINTS | Endpoints | Note + tag CRUD endpoints, pagination | All endpoints respond correctly |
| P3-AUTH | Auth | JWT auth, route protection, user model | Auth working end-to-end |
| P4-DEPLOY | Deploy | Full test coverage, Docker support, docs | 90%+ coverage, README complete |

## Phase Ordinals
\`\`\`
P0-SCAFFOLD) echo 0 ;;
P1-MODELS) echo 1 ;;
P2-ENDPOINTS) echo 2 ;;
P3-AUTH) echo 3 ;;
P4-DEPLOY) echo 4 ;;
\`\`\`

## Agent Workforce
| Tier | Model | Use For |
|------|-------|---------|
| Opus | claude-opus-4-6 | Architecture, auth design, complex queries |
| Sonnet | claude-sonnet-4-6 | Multi-file features, endpoint implementations |
| Haiku | claude-haiku-4-5 | Single-file edits, config, boilerplate |
| Gemini | via MCP | Research, large context analysis |

## Build & Test
\`\`\`bash
poetry run pytest 2>&1 | tail -20
poetry run pytest --cov 2>&1 | tail -20
\`\`\`

## Commit Format
\`[PHASE] scope: description\` e.g. \`[P0-SCAFFOLD] app: add health endpoint\`

## Code Standards
- Black + Ruff enforced
- mypy strict type checking
- No bare except clauses
- All endpoints have return type annotations

## Visual Verification
Not applicable — API service, no visual UI.

## MCP Servers Available
- Desktop Commander, Gemini MCP

## Project-Specific STOP Rules
- STOP before writing to production DB during tests (use test DB)
- STOP before adding any paid API key dependencies

## Gitignore Patterns
| Pattern | Why |
|---------|-----|
| __pycache__/ | Python bytecode |
| .venv/ | Virtual environment |
| dist/ | Build artifacts |
| *.egg-info/ | Package metadata |
| .env | Secrets |
| *.db-journal, *.db-wal | SQLite temp files |
| .DS_Store | macOS metadata |
INFRASTRUCTURE_EOF

  cat > "$P_DIR/specs/RESEARCH.md" << 'RESEARCH_EOF'
# FastAPIService — Research

## FastAPI + SQLAlchemy 2.x Integration
SQLAlchemy 2.x async engine works well with FastAPI async endpoints. Use AsyncSession with dependency injection pattern. Key gotcha: always await session.commit() before returning responses.

## JWT Auth Pattern for FastAPI
python-jose + passlib is the recommended FastAPI JWT stack. Token refresh via /token/refresh endpoint prevents forced re-login. Store JWT secret in env var, never in code.

## SQLite FTS5 with SQLAlchemy
SQLAlchemy doesn't natively support FTS5 virtual tables. Use raw SQL via text() for FTS queries. Create FTS5 table separately from regular ORM models.
RESEARCH_EOF
}

create_specs_p4() {
  cat > "$P_DIR/specs/VISION.md" << 'VISION_EOF'
# SwiftDesktopApp — Vision

## One-Paragraph Pitch
A macOS status bar app for tracking focus sessions using the Pomodoro technique. Shows current session timer in the menu bar, rings system sound at end, logs sessions to SQLite for weekly review.

## Who Is This For?
Me — wanting minimal distraction from a native macOS tool that lives in the menu bar.

## What Does "Done" Look Like?
1. Timer shows in menu bar as "25:00" counting down
2. Start/pause/skip via menu clicks or keyboard shortcut
3. Session log shows last 7 days of focus time

## What's NOT in v1
- iOS companion
- iCloud sync
VISION_EOF

  cat > "$P_DIR/specs/BLUEPRINT.md" << 'BLUEPRINT_EOF'
# SwiftDesktopApp — Decisions

## Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Language | Swift 5.9+ | Native macOS, best AppKit/SwiftUI integration |
| UI | SwiftUI | Declarative, menu bar popover works well |
| Status bar | AppKit NSStatusItem | No SwiftUI equivalent for menu bar icon |
| Storage | SQLite (GRDB.swift) | Fast, local, type-safe |
| Build | Xcode 15+ | Required for Swift 5.9 |
| Deployment | Unsigned local | Personal tool, no App Store |

## Scope — v1
1. Menu bar icon with countdown timer
2. Start/pause/reset session
3. Configurable work/break durations
4. Session history log (SQLite)

## Key Decision
| Decision | Options | Chose | Why |
|----------|---------|-------|-----|
| Menu bar | NSStatusItem + NSMenu vs SwiftUI MenuBarExtra | NSStatusItem (AppKit) | Better control over icon/title updates |

## Gate Check
- [x] All decisions locked
BLUEPRINT_EOF

  cat > "$P_DIR/specs/INFRASTRUCTURE.md" << INFRASTRUCTURE_EOF
# SwiftDesktopApp — Framework Specification

## Project Identity
- **Project Name:** SwiftDesktopApp
- **Project Slug:** swift_desktop_app
- **Project Path:** $P_DIR
- **DB Filename:** swift_desktop_app.db
- **Lessons File:** LESSONS_SWIFT_DESKTOP_APP.md
- **Rules File:** SWIFT_DESKTOP_APP_RULES.md
- **Project Memory File:** SWIFT_DESKTOP_APP_PROJECT_MEMORY.md
- **North Star:** macOS status bar Pomodoro timer — native Swift, SQLite session log, minimal UI, zero cloud

## Tech Stack
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + AppKit (NSStatusItem)
- **Database:** SQLite via GRDB.swift
- **Build:** Xcode 15+, xcodebuild
- **Deployment:** Unsigned local build

## Phase Plan
| Phase ID | Name | Description | Key Deliverables |
|----------|------|-------------|-----------------|
| P0-FOUNDATION | Foundation | Xcode project, AppDelegate, NSStatusItem shell | App launches, shows icon in menu bar |
| P1-DATA | Data Layer | GRDB schema, session model, CRUD | Sessions persist across app launches |
| P2-VIEWS | Views | SwiftUI popover, timer display, controls | UI shows timer and buttons |
| P3-INTERACTIONS | Interactions | Timer logic, system sound, keyboard shortcuts | Full timer cycle works |
| P4-POLISH | Polish | Settings view, error handling, edge cases | All states handled |
| P5-SHIP | Ship | Testing, cleanup, README | Clean build, no warnings |

## Phase Ordinals
\`\`\`
P0-FOUNDATION) echo 0 ;;
P1-DATA) echo 1 ;;
P2-VIEWS) echo 2 ;;
P3-INTERACTIONS) echo 3 ;;
P4-POLISH) echo 4 ;;
P5-SHIP) echo 5 ;;
\`\`\`

## Agent Workforce
| Tier | Model | Use For |
|------|-------|---------|
| Opus | claude-opus-4-6 | Architecture, complex Swift patterns, AppKit bridge |
| Sonnet | claude-sonnet-4-6 | Multi-file Swift features, SwiftUI views |
| Haiku | claude-haiku-4-5 | Single-file edits, config, boilerplate |
| apple-platform-build-tools | specialist agent | Build, test, simulator management |

## Build & Test
\`\`\`bash
xcodebuild -project SwiftDesktopApp/SwiftDesktopApp.xcodeproj -scheme SwiftDesktopApp build 2>&1 | tail -20
\`\`\`

## Commit Format
\`[PHASE] scope: description\` e.g. \`[P0-FOUNDATION] app: add NSStatusItem setup\`

## Code Standards
- Swift style: Apple conventions, no force unwraps in production
- SwiftUI: prefer @StateObject for owned data, @ObservedObject for injected
- GRDB: read-only access to session DB from views, writes via services only
- Error handling: Result type or do/catch, never silent failures

## Visual Verification
This project HAS visual UI — visual verification gate is ACTIVE. Use screenshots to verify SwiftUI popover layout and dark mode after UI changes.

## MCP Servers Available
- Desktop Commander, XcodeBuild MCP

## Project-Specific STOP Rules
- STOP before any App Store distribution changes (unsigned personal tool)
- STOP before using deprecated AppKit APIs
- STOP before adding iCloud or network access (local-only)

## Gitignore Patterns
| Pattern | Why |
|---------|-----|
| DerivedData/ | Xcode build cache |
| *.xcuserdata/ | User-specific Xcode state |
| build/ | Build output |
| *.db-journal, *.db-wal | SQLite temp files |
| .DS_Store | macOS metadata |
INFRASTRUCTURE_EOF

  cat > "$P_DIR/specs/RESEARCH.md" << 'RESEARCH_EOF'
# SwiftDesktopApp — Research

## NSStatusItem for macOS Menu Bar Apps
NSStatusItem is the correct approach for a persistent menu bar icon. Use NSStatusItem.button.title for the countdown string. Set preferredEdge = .minY for popover attachment. NSStatusItem.length = NSVariableStatusItemLength allows text to resize.

## SwiftUI + AppKit Interop
NSHostingView wraps SwiftUI views for use in NSWindow/NSPopover. Use NSPopover with SwiftUI content for the click-to-expand popover. AppDelegate sets up the status item; SwiftUI handles the popover content.

## GRDB for Local SQLite
GRDB.swift is the best Swift SQLite library. Use DatabaseQueue for single-file access. DatabaseMigrator handles schema versioning. For timer apps, schema is minimal: sessions table with start_at, end_at, type, completed.
RESEARCH_EOF
}

# === ENGINE DEPLOYMENT =======================================================
deploy_project() {
  # Must be called after load_project_config N and create_specs N
  header "Deploying Engine: $P_NAME (project $P_NUM)"
  cd "$P_DIR"

  section "2a. Scaffold directories"
  mkdir -p frameworks refs backups
  info "Created frameworks/, refs/, backups/"

  section "2b. Copy framework files (9 total)"
  cp "$TEMPLATE_FRAMEWORKS"/*.md frameworks/
  cp "$GLOBAL_FRAMEWORKS/loopback-system.md" frameworks/
  local FW_COUNT; FW_COUNT=$(ls frameworks/*.md | wc -l)
  info "Copied $FW_COUNT framework files"

  section "2c. Copy + customize template scripts"
  deploy_scripts

  section "2d. Initialize database"
  touch "$P_DB"
  bash db_queries.sh init-db || { echo "init-db failed"; exit 1; }

  section "2e. Seed phase_gates table"
  for ph in $P_PHASES; do
    sqlite3 "$P_DB" "INSERT OR IGNORE INTO phase_gates (phase) VALUES ('$ph');"
  done
  info "Seeded phase_gates: $P_PHASES"

  section "2f. Insert test tasks"
  insert_tasks

  section "2g. Generate RULES.md"
  generate_rules

  section "2h. Generate CLAUDE.md"
  generate_claude_md

  section "2i. Create tracking files"
  create_tracking_files

  section "2j. Create git hooks"
  create_git_hooks

  section "2k. Create refs/ directory"
  create_refs

  section "2l. Create .gitignore"
  create_gitignore

  info "Engine deployment complete for $P_NAME"
}

deploy_scripts() {
  # Placeholders to replace in all scripts
  local COMMON_SED=(
    -e "s|%%PROJECT_DB%%|${P_DB}|g"
    -e "s|%%PROJECT_DB_NAME%%|${P_DB_NAME}|g"
    -e "s|%%PROJECT_NAME%%|${P_NAME}|g"
    -e "s|%%LESSONS_FILE%%|${P_LESSONS}|g"
    -e "s|%%PROJECT_MEMORY_FILE%%|${P_MEMORY}|g"
    -e "s|%%RULES_FILE%%|${P_RULES}|g"
    -e "s|%%PROJECT_PATH%%|${P_DIR}|g"
    -e "s|%%PHASES%%|${P_PHASES}|g"
  )

  # db_queries.sh — thin Python wrapper (delegates to dbq package)
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/db_queries.template.sh" > db_queries.sh

  # session_briefing.sh
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/session_briefing.template.sh" > session_briefing.sh

  # milestone_check.sh
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/milestone_check.template.sh" > milestone_check.sh

  # coherence_check.sh — only %%LESSONS_FILE%% in actual code (SKIP_PATTERN_* are comments)
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/coherence_check.template.sh" > coherence_check.sh

  # coherence_registry.sh — no placeholders, copy as-is
  cp "$TEMPLATE_SCRIPTS/coherence_registry.template.sh" coherence_registry.sh

  # build_summarizer.sh — generate real (but test-safe) implementation
  create_build_summarizer

  # work.sh
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/work.template.sh" > work.sh

  # fix.sh
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/fix.template.sh" > fix.sh

  # harvest.sh
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/harvest.template.sh" > harvest.sh

  # generate_board.py
  sed "${COMMON_SED[@]}" "$TEMPLATE_SCRIPTS/generate_board.template.py" > generate_board.py

  chmod +x db_queries.sh session_briefing.sh milestone_check.sh coherence_check.sh \
           coherence_registry.sh build_summarizer.sh work.sh fix.sh harvest.sh
  info "All scripts copied, sed-filled, and made executable"
}

create_build_summarizer() {
  # Write a build summarizer that's real but doesn't require actual source code.
  # Uses echo/exit rather than actual build tool invocations for test projects.
  local BUILD_CMD
  case "$P_NUM" in
    1) BUILD_CMD="npm run build / npm test";;
    2) BUILD_CMD="cargo build / cargo test";;
    3) BUILD_CMD="poetry run pytest";;
    4) BUILD_CMD="xcodebuild build/test";;
    *) BUILD_CMD="(unknown stack)";;
  esac
  cat > build_summarizer.sh << BSEOF
#!/usr/bin/env bash
# build_summarizer.sh — $P_NAME
# Real implementation would run: $BUILD_CMD
PROJECT_DIR="\$(dirname "\$0")"
MODE="\${1:-build}"
case "\$MODE" in
  build)
    echo "── Build: $P_NAME ──────────────────────────────────"
    # Actual build command would go here. For test project: DB health check.
    bash "\$PROJECT_DIR/db_queries.sh" health 2>&1 | tail -5
    echo "BUILD OK (test project — no actual source code)"
    ;;
  test)
    echo "── Test: $P_NAME ──────────────────────────────────"
    bash "\$PROJECT_DIR/db_queries.sh" verify 2>&1 | tail -5
    bash "\$PROJECT_DIR/coherence_check.sh" --quiet 2>&1 || echo "(coherence warning)"
    echo "TEST OK (test project — no actual source code)"
    ;;
  verify)
    bash "\$PROJECT_DIR/db_queries.sh" health
    ;;
  *)
    echo "Usage: \$0 [build|test|verify]"; exit 1;;
esac
BSEOF
  chmod +x build_summarizer.sh
}

insert_tasks() {
  # 7 tasks: 2 in first phase, 2 in second, 2 in third, 1 MASTER in second
  local PHASES_ARRAY=($P_PHASES)
  local PH0="${PHASES_ARRAY[0]}"
  local PH1="${PHASES_ARRAY[1]}"
  local PH2="${PHASES_ARRAY[2]:-${PHASES_ARRAY[1]}}"

  sqlite3 "$P_DB" << SQLEOF
INSERT INTO tasks (id, phase, title, status, priority, assignee, sort_order, queue, tier) VALUES
  ('T-001', '$PH0', 'Initialize $P_NAME project structure', 'TODO', 'P0', 'CLAUDE', 1, 'BACKLOG', 'Haiku'),
  ('T-002', '$PH0', 'Configure build toolchain and linter', 'TODO', 'P1', 'CLAUDE', 2, 'BACKLOG', 'Haiku'),
  ('T-003', '$PH1', 'Implement core data models', 'TODO', 'P1', 'CLAUDE', 3, 'BACKLOG', 'Sonnet'),
  ('T-004', '$PH1', 'Write unit tests for core models', 'TODO', 'P2', 'CLAUDE', 4, 'BACKLOG', 'Haiku'),
  ('T-005', '$PH1', 'Review data model design', 'TODO', 'P2', 'MASTER', 5, 'BACKLOG', NULL),
  ('T-006', '$PH2', 'Build primary feature implementation', 'TODO', 'P2', 'CLAUDE', 6, 'BACKLOG', 'Sonnet'),
  ('T-007', '$PH2', 'Add error handling throughout', 'TODO', 'P3', 'CLAUDE', 7, 'BACKLOG', 'Sonnet');
SQLEOF
  local COUNT; COUNT=$(sqlite3 "$P_DB" "SELECT COUNT(*) FROM tasks;")
  info "Inserted $COUNT tasks"
}

generate_rules() {
  # Use Python with environment variables to safely substitute all RULES_TEMPLATE.md placeholders
  local VISUAL_VERIF GEMINI_TABLE TEAM_TOPOLOGY OUTPUT_GATE EXTRA_DELEG

  if [ "$P_HAS_UI" = "YES" ]; then
    VISUAL_VERIF="After every SwiftUI/UI change: take a screenshot, compare to expected layout. Check dark mode. Verify spacing. Use XcodeBuild MCP screenshot tool or iOS Simulator screenshots."
  else
    VISUAL_VERIF="Not applicable — this is a non-visual project (CLI tool / API service). No screenshot verification required."
  fi

  if [ "$P_HAS_GEMINI" = "YES" ]; then
    GEMINI_TABLE="## Gemini MCP Tools Available
| Tool | Use Case |
|------|----------|
| gemini-query | General Q&A, large context analysis |
| gemini-search | Web research, documentation lookup |
| gemini-analyze-code | Large codebase analysis, second opinion |
| gemini-deep-research | Complex research tasks |"
  else
    GEMINI_TABLE="## Gemini MCP
N/A — Gemini MCP not configured for this project."
  fi

  if [ "$P_HAS_TEAMS" = "YES" ]; then
    TEAM_TOPOLOGY="Active for this project. Configure in ~/.claude/settings.json.
| Role | Model | Responsibilities |
|------|-------|-----------------|
| Orchestrator | claude-opus-4-6 | Architecture, task assignment, final review |
| Implementer 1 | claude-sonnet-4-6 | Feature implementation |
| Implementer 2 | claude-sonnet-4-6 | Testing and validation |"
  else
    TEAM_TOPOLOGY="Agent Teams mode is INACTIVE for this project. Using single-agent mode."
  fi

  case "$P_HAS_UI$P_HAS_GEMINI" in
    YESYES|YESNO)
      OUTPUT_GATE="**Visual Verification Gate (ACTIVE)**
After every UI component change:
1. Take a screenshot
2. Compare to expected layout
3. Check: spacing, colors, dark mode, interactive states
4. Document findings before marking task DONE" ;;
    NOYES|NONO)
      if [ "$P_NUM" = "3" ]; then
        OUTPUT_GATE="**API Contract Gate**
After every endpoint change:
1. Run pytest test suite — all tests must pass
2. Verify response schemas match OpenAPI spec
3. Test edge cases: empty input, invalid auth, max payload
4. Check: status codes, error messages, response times"
      else
        OUTPUT_GATE="**CLI Test Gate**
After every command implementation:
1. Run \`cargo test\` / \`pytest\` — all tests must pass
2. Manual smoke test: run the command with sample input
3. Verify error messages are clear and helpful
4. Test dry-run mode produces correct preview"
      fi ;;
  esac

  if [ "$P_HAS_GEMINI" = "YES" ]; then
    EXTRA_DELEG="| Large context analysis, research | **Gemini** | Gemini MCP tools handle long documents |"
  else
    EXTRA_DELEG=""
  fi

  local PHASES_ARRAY=($P_PHASES)
  local TECH_STACK BUILD_INSTRUCTIONS CODE_STANDARDS GITIGNORE_TABLE STOP_RULES

  case "$P_NUM" in
    1)
      TECH_STACK="Node.js 20, Next.js 14 (App Router), TypeScript, Tailwind CSS, SQLite (better-sqlite3), Vitest, Playwright"
      BUILD_INSTRUCTIONS="npm run build 2>&1 | tail -20   # production build
npm test 2>&1 | tail -20          # vitest unit tests
npx playwright test 2>&1 | tail -20 # E2E tests"
      CODE_STANDARDS="TypeScript strict mode (no implicit any). ESLint + Prettier enforced. No inline styles — Tailwind utility classes only. API routes: always return typed responses."
      GITIGNORE_TABLE="| node_modules/ | npm deps | .next/ | build output | .env* | secrets | *.db-journal | SQLite temp |"
      STOP_RULES="- STOP before adding any cloud/paid dependency
- STOP before modifying existing bookmark data (imports are append-only)"
      ;;
    2)
      TECH_STACK="Rust 1.75+, Cargo, clap 4.x, walkdir, regex crate"
      BUILD_INSTRUCTIONS="cargo build 2>&1 | tail -20   # debug build
cargo test 2>&1 | tail -20    # all tests
cargo build --release 2>&1 | tail -20  # release binary"
      CODE_STANDARDS="cargo clippy -- -D warnings (zero warnings). cargo fmt enforced. No unwrap() in non-test code. Use anyhow for error propagation."
      GITIGNORE_TABLE="| target/ | Cargo build output | Cargo.lock | lock file | *.db-journal | SQLite temp |"
      STOP_RULES="- STOP before any file modifications without dry-run check first
- STOP before adding network calls (this is an offline tool)"
      ;;
    3)
      TECH_STACK="Python 3.12, Poetry, FastAPI 0.109+, SQLAlchemy 2.x, SQLite, python-jose, passlib, pytest, httpx"
      BUILD_INSTRUCTIONS="poetry run pytest 2>&1 | tail -20
poetry run pytest --cov 2>&1 | tail -20
poetry run mypy . 2>&1 | tail -20"
      CODE_STANDARDS="Black + Ruff enforced. mypy strict type checking. No bare except clauses. All FastAPI endpoints have response_model annotations."
      GITIGNORE_TABLE="| __pycache__/ | bytecode | .venv/ | virtualenv | dist/ | build output | .env | secrets |"
      STOP_RULES="- STOP before writing to production DB during tests (use test DB)
- STOP before adding paid API key dependencies"
      ;;
    4)
      TECH_STACK="Swift 5.9+, SwiftUI, AppKit (NSStatusItem), GRDB.swift, Xcode 15+, local unsigned build"
      BUILD_INSTRUCTIONS="xcodebuild -project SwiftDesktopApp/SwiftDesktopApp.xcodeproj -scheme SwiftDesktopApp build 2>&1 | tail -20
xcodebuild test 2>&1 | tail -20"
      CODE_STANDARDS="Apple Swift conventions. No force unwraps in production code. @StateObject for owned data, @ObservedObject for injected. GRDB: read-only from views, writes via service layer only."
      GITIGNORE_TABLE="| DerivedData/ | Xcode cache | *.xcuserdata/ | user state | build/ | output | *.db-journal | SQLite temp |"
      STOP_RULES="- STOP before any App Store distribution (unsigned personal tool)
- STOP before using deprecated AppKit APIs
- STOP before adding iCloud or network access (local-only)"
      ;;
  esac

  export RULES_PLACEHOLDER_PROJECT_NAME="$P_NAME"
  export RULES_PLACEHOLDER_PROJECT_NORTH_STAR="$(head -2 specs/INFRASTRUCTURE.md | grep 'North Star' | sed 's/.*North Star: //' | tr -d '*')"
  export RULES_PLACEHOLDER_PROJECT_PATH="$P_DIR"
  export RULES_PLACEHOLDER_PROJECT_MEMORY_FILE="$P_MEMORY"
  export RULES_PLACEHOLDER_FIRST_PHASE="${PHASES_ARRAY[0]}"
  export RULES_PLACEHOLDER_TECH_STACK="$TECH_STACK"
  export RULES_PLACEHOLDER_COMMIT_FORMAT="[PHASE] scope: description — e.g. [${PHASES_ARRAY[0]}] init: scaffold project"
  export RULES_PLACEHOLDER_BUILD_TEST_INSTRUCTIONS="$BUILD_INSTRUCTIONS"
  export RULES_PLACEHOLDER_CODE_STANDARDS="$CODE_STANDARDS"
  export RULES_PLACEHOLDER_GITIGNORE_TABLE="$GITIGNORE_TABLE"
  export RULES_PLACEHOLDER_OUTPUT_VERIFICATION_GATE="$OUTPUT_GATE"
  export RULES_PLACEHOLDER_PROJECT_STOP_RULES="$STOP_RULES"
  export RULES_PLACEHOLDER_EXTRA_MODEL_DELEGATION="$EXTRA_DELEG"
  export RULES_PLACEHOLDER_TEAM_TOPOLOGY="$TEAM_TOPOLOGY"
  export RULES_PLACEHOLDER_GEMINI_MCP_TABLE="$GEMINI_TABLE"
  export RULES_PLACEHOLDER_VISUAL_VERIFICATION="$VISUAL_VERIF"
  export RULES_PLACEHOLDER_EXTRA_MANDATORY_SKILLS="| **Before every phase gate** | /code-review | Review all changes in phase before gating |"
  export RULES_PLACEHOLDER_RECOMMENDED_SKILLS="| Starting new phase | /engineering:architecture | Review phase approach |"
  export RULES_PLACEHOLDER_MCP_SERVERS="$([ "$P_HAS_GEMINI" = "YES" ] && echo "- Gemini MCP (research, analysis)" || echo ""); - Desktop Commander (file ops, shell commands)"

  python3 << 'PYEOF'
import os, sys

template_path = os.path.expanduser('~/.claude/dev-framework/templates/rules/RULES_TEMPLATE.md')
output_path = os.environ.get('RULES_OUTPUT_PATH', 'RULES.md')

with open(template_path, 'r') as f:
    content = f.read()

for key, value in os.environ.items():
    if key.startswith('RULES_PLACEHOLDER_'):
        placeholder = '%%' + key[len('RULES_PLACEHOLDER_'):] + '%%'
        content = content.replace(placeholder, value)

# Check for any remaining unfilled placeholders
import re
remaining = re.findall(r'%%[A-Z_]+%%', content)
if remaining:
    print(f"  WARNING: {len(remaining)} unfilled placeholders remain: {set(remaining)}", file=sys.stderr)

with open(output_path, 'w') as f:
    f.write(content)

print(f"  Generated {output_path} ({len(content)} bytes)")
PYEOF

  # Rename to project-specific rules file
  mv RULES.md "$P_RULES" 2>/dev/null || true

  # Generate extended rules (refs/rules-extended.md) — same placeholders, different template
  local EXTENDED_TEMPLATE="$TEMPLATES/rules/RULES_EXTENDED_TEMPLATE.md"
  if [ -f "$EXTENDED_TEMPLATE" ]; then
    mkdir -p refs
    python3 << 'PYEOF2'
import os, sys, re

template_path = os.path.expanduser('~/.claude/dev-framework/templates/rules/RULES_EXTENDED_TEMPLATE.md')
output_path = 'refs/rules-extended.md'

with open(template_path, 'r') as f:
    content = f.read()

for key, value in os.environ.items():
    if key.startswith('RULES_PLACEHOLDER_'):
        placeholder = '%%' + key[len('RULES_PLACEHOLDER_'):] + '%%'
        content = content.replace(placeholder, value)

remaining = re.findall(r'%%[A-Z_]+%%', content)
if remaining:
    print(f"  WARNING: {len(remaining)} unfilled placeholders in extended rules: {set(remaining)}", file=sys.stderr)

with open(output_path, 'w') as f:
    f.write(content)

print(f"  Generated {output_path} ({len(content)} bytes)")
PYEOF2
  fi

  export -n RULES_PLACEHOLDER_PROJECT_NAME RULES_PLACEHOLDER_PROJECT_NORTH_STAR \
    RULES_PLACEHOLDER_PROJECT_PATH RULES_PLACEHOLDER_PROJECT_MEMORY_FILE \
    RULES_PLACEHOLDER_FIRST_PHASE RULES_PLACEHOLDER_TECH_STACK \
    RULES_PLACEHOLDER_COMMIT_FORMAT RULES_PLACEHOLDER_BUILD_TEST_INSTRUCTIONS \
    RULES_PLACEHOLDER_CODE_STANDARDS RULES_PLACEHOLDER_GITIGNORE_TABLE \
    RULES_PLACEHOLDER_OUTPUT_VERIFICATION_GATE RULES_PLACEHOLDER_PROJECT_STOP_RULES \
    RULES_PLACEHOLDER_EXTRA_MODEL_DELEGATION RULES_PLACEHOLDER_TEAM_TOPOLOGY \
    RULES_PLACEHOLDER_GEMINI_MCP_TABLE RULES_PLACEHOLDER_VISUAL_VERIFICATION \
    RULES_PLACEHOLDER_EXTRA_MANDATORY_SKILLS RULES_PLACEHOLDER_RECOMMENDED_SKILLS \
    RULES_PLACEHOLDER_MCP_SERVERS
}

generate_claude_md() {
  sed \
    -e "s|%%PROJECT_NAME%%|${P_NAME}|g" \
    -e "s|%%RULES_FILE%%|${P_RULES}|g" \
    -e "s|%%LESSONS_FILE%%|${P_LESSONS}|g" \
    "$CLAUDE_TEMPLATE" > CLAUDE.md
  info "Generated CLAUDE.md"
}

create_tracking_files() {
  # LESSONS file
  cat > "$P_LESSONS" << LESSEOF
# $P_NAME — Lessons & Corrections

## Corrections Log
| Date | What Happened | Root Cause | Rule | Promoted |
|------|--------------|------------|------|----------|

## Insights
| Date | Insight | Category | Notes |
|------|---------|----------|-------|

## Universal Patterns (cross-project candidates)
| Date | Pattern | Rule | Source | Promoted |
|------|---------|------|--------|----------|
LESSEOF

  # PROJECT_MEMORY file
  cat > "$P_MEMORY" << MEMEOF
# $P_NAME — Project Memory

## §1 Overview
$(grep "One-Paragraph Pitch" specs/VISION.md -A 2 | tail -1 | sed 's/^> //' | xargs)

## §2 Section Lookup
| What you need | Where to look |
|---------------|---------------|
| Task status | \`bash db_queries.sh next\` |
| Architecture | §3 below |
| File structure | §4 below |

## §3 Architecture
$(grep -A 10 "Tech Stack" specs/BLUEPRINT.md | head -8 || echo "See specs/BLUEPRINT.md")

## §4 File Structure
\`\`\`
$P_NAME/
├── specs/          # Project spec documents
├── frameworks/     # Process protocol documents
├── refs/           # Progressive disclosure references
└── $P_DB     # Task tracking database
\`\`\`
MEMEOF

  # LEARNING_LOG
  cat > LEARNING_LOG.md << 'LLEOF'
# Learning Log

| Date | What | Category | Notes |
|------|------|----------|-------|
LLEOF

  # AGENT_DELEGATION.md
  cat > AGENT_DELEGATION.md << ADEOF
# Agent Delegation Map — $P_NAME

## Workforce Tiers
| Tier | Model | Cost | When to Use |
|------|-------|------|-------------|
| **Opus** | claude-opus-4-6 | \$\$\$\$ | Architecture, gate reviews, judgment calls |
| **Sonnet** | claude-sonnet-4-6 | \$\$ | Multi-file features, complex logic |
| **Haiku** | claude-haiku-4-5 | \$ | Single-file, config, mechanical changes |
| **MASTER** | Human | — | Design decisions, testing, review, assets |

<!-- DELEGATION-START -->
*Run \`bash db_queries.sh delegation-md\` to populate with live task data.*
<!-- DELEGATION-END -->
ADEOF

  # NEXT_SESSION.md
  cat > NEXT_SESSION.md << NSEOF
# Next Session Handoff

**Handoff Source:** BOOTSTRAP
**Date:** $(date +%Y-%m-%d)
**Signal:** GREEN
**Branch:** dev

## Current State

Phase: $P_FIRST (tasks not yet started)
Gate: Not started
Blockers: None

## First Task

T-001 — Initialize $P_NAME project structure

## Overrides (active)

None.
NSEOF

  info "Created: $P_LESSONS, $P_MEMORY, LEARNING_LOG.md, AGENT_DELEGATION.md, NEXT_SESSION.md"
}

create_git_hooks() {
  local HOOK_DIR=".git/hooks"

  cat > "$HOOK_DIR/pre-commit" << HOOKEOF
#!/usr/bin/env bash
# Quality Gate 1 — pre-commit ($P_NAME)
DIR="\$(git rev-parse --show-toplevel)"
echo "── Pre-commit checks ──"

# Coherence check (soft warning — doesn't block on clean registry)
if [ -f "\$DIR/coherence_check.sh" ]; then
    bash "\$DIR/coherence_check.sh" --quiet 2>&1 || true
fi

# Knowledge health nag
if [ -f "\$DIR/$P_LESSONS" ]; then
    UNPROMOTED=\$(grep -cE "^\\\|[^|]+\\\|[^|]+\\\| No( —| \\\|)" "\$DIR/$P_LESSONS" 2>/dev/null)
    UNPROMOTED="\${UNPROMOTED:-0}"
    [ "\$UNPROMOTED" -gt 3 ] && echo "⚠️  \$UNPROMOTED unpromoted lesson(s)"
fi
exit 0
HOOKEOF

  cat > "$HOOK_DIR/pre-push" << PUSHEOF
#!/usr/bin/env bash
# Quality Gate 2 — pre-push ($P_NAME)
echo "── Pre-push checks ──"
echo "Pre-push: OK (test project — build check disabled)"
PUSHEOF

  chmod +x "$HOOK_DIR/pre-commit" "$HOOK_DIR/pre-push"
  info "Created pre-commit and pre-push hooks"
}

create_refs() {
  # Always-present refs
  cat > refs/README.md << 'REOF'
# refs/ — Progressive Disclosure Directory
Files here contain reference material extracted from RULES.md or accumulated over time.
Use: read specific files only when the current task needs them.
REOF

  cat > refs/tool-inventory.md << TIEOF
# Tool Inventory — $P_NAME

## Claude Models
| Model | ID | When to Use |
|-------|----|-------------|
| Opus | claude-opus-4-6 | Architecture, gates, judgment |
| Sonnet | claude-sonnet-4-6 | Features, implementation |
| Haiku | claude-haiku-4-5 | Config, boilerplate, single-file |

## MCP Servers
- Desktop Commander (file ops, shell)
$([ "$P_HAS_GEMINI" = "YES" ] && echo "- Gemini MCP (research, analysis)" || echo "")

## Local Tools
- sqlite3 (DB queries)
- python3 (generate_board.py, test runner)
TIEOF

  cat > refs/gotchas-workflow.md << 'GWEOF'
# Workflow Gotchas

*Populated automatically when corrections accumulate in workflow domain.*
*See: db_queries.sh done --loopback-lesson for how lessons get here.*

| Date | Gotcha | When It Fires | How to Avoid |
|------|--------|--------------|--------------|
GWEOF

  # Conditional refs
  if [ "$P_HAS_UI" = "YES" ]; then
    cat > refs/gotchas-frontend.md << 'GFEOF'
# Frontend / UI Gotchas

*Populated when UI-related corrections accumulate.*

| Date | Gotcha | When It Fires | How to Avoid |
|------|--------|--------------|--------------|
GFEOF
    info "Created refs/gotchas-frontend.md (UI project)"
  fi

  if [ "$P_HAS_SKILLS" = "YES" ]; then
    cat > refs/skills-catalog.md << SCEOF
# Skills Catalog — $P_NAME

| Skill | Trigger | What It Does |
|-------|---------|-------------|
| /code-review | Before merge | Structured code review |
| /engineering:debug | On errors | Structured debugging |
| /engineering:testing-strategy | Phase start | Test plan for new phase |
SCEOF
    info "Created refs/skills-catalog.md (Skills=YES)"
  fi

  if [ "$P_HAS_DEFERRED" = "YES" ]; then
    cat > refs/planned-integrations.md << PIEOF
# Planned Integrations — $P_NAME

*Deferred to v2+. Documented here to avoid re-evaluating during v1 build.*

| Integration | Why Deferred | Notes for v2 |
|-------------|-------------|--------------|
| *See specs/BLUEPRINT.md deferred scope items* | Out of v1 scope | Re-evaluate after v1 ships |
PIEOF
    info "Created refs/planned-integrations.md (Deferred=YES)"
  fi
}

create_gitignore() {
  case "$P_NUM" in
    1) cat > .gitignore << 'EOF'
node_modules/
.next/
.env
.env.local
.env.production
*.db-journal
*.db-wal
*.db-shm
backups/
.DS_Store
EOF
    ;;
    2) cat > .gitignore << 'EOF'
target/
*.db-journal
*.db-wal
*.db-shm
backups/
.DS_Store
EOF
    ;;
    3) cat > .gitignore << 'EOF'
__pycache__/
*.pyc
.venv/
dist/
*.egg-info/
.env
*.db-journal
*.db-wal
*.db-shm
backups/
.DS_Store
EOF
    ;;
    4) cat > .gitignore << 'EOF'
DerivedData/
*.xcuserdata/
build/
*.db-journal
*.db-wal
*.db-shm
backups/
.DS_Store
EOF
    ;;
  esac
  info "Created .gitignore (${P_NUM}-specific patterns)"
}

# === D7 VERIFICATION =========================================================
verify_project() {
  header "D7 Verification: $P_NAME"
  cd "$P_DIR"

  section "Check 1: DB exists and health passes"
  chk "DB file exists" test -f "$P_DB"
  chk "health passes (exit 0)" bash db_queries.sh health

  section "Check 2: Framework files (9 total)"
  local FW_COUNT; FW_COUNT=$(ls frameworks/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$FW_COUNT" -eq 9 ]; then pass "9 framework files present"; else fail "Expected 9 framework files, found $FW_COUNT"; fi
  chk "loopback-system.md specifically present" test -f "frameworks/loopback-system.md"

  section "Check 3: AGENT_DELEGATION.md exists"
  chk "AGENT_DELEGATION.md exists" test -f AGENT_DELEGATION.md
  chk "Delegation markers present" grep -q "DELEGATION-START" AGENT_DELEGATION.md

  section "Check 4: All scripts exist and executable"
  for s in db_queries.sh session_briefing.sh build_summarizer.sh milestone_check.sh \
            coherence_check.sh coherence_registry.sh work.sh fix.sh harvest.sh; do
    chk "$s executable" test -x "$s"
  done
  chk "generate_board.py exists" test -f generate_board.py

  section "Check 5: RULES file has no unfilled placeholders"
  if [ -f "$P_RULES" ]; then
    local REMAINING; REMAINING=$(grep -cE '%%[A-Z_]+%%' "$P_RULES" 2>/dev/null)
    REMAINING="${REMAINING:-0}"
    if [ "$REMAINING" -eq 0 ]; then pass "Zero unfilled placeholders in $P_RULES"; else
      fail "$REMAINING unfilled placeholders in $P_RULES"
      grep -E '%%[A-Z_]+%%' "$P_RULES" | head -5 | while read l; do warn "  $l"; done
    fi
  else
    fail "$P_RULES does not exist"
  fi

  section "Check 5b: Extended rules file exists and has no unfilled placeholders"
  if [ -f "refs/rules-extended.md" ]; then
    pass "refs/rules-extended.md exists"
    local EXT_REMAINING; EXT_REMAINING=$(grep -cE '%%[A-Z_]+%%' "refs/rules-extended.md" 2>/dev/null)
    EXT_REMAINING="${EXT_REMAINING:-0}"
    if [ "$EXT_REMAINING" -eq 0 ]; then pass "Zero unfilled placeholders in refs/rules-extended.md"; else
      fail "$EXT_REMAINING unfilled placeholders in refs/rules-extended.md"
      grep -E '%%[A-Z_]+%%' "refs/rules-extended.md" | head -5 | while read l; do warn "  $l"; done
    fi
  else
    fail "refs/rules-extended.md does not exist"
  fi

  section "Check 6: CLAUDE.md @-import chain — all referenced files exist"
  chk "CLAUDE.md exists" test -f CLAUDE.md
  if [ -f CLAUDE.md ]; then
    grep -oE '^@.+' CLAUDE.md | while read -r import; do
      local fname="${import:1}"
      chk "@$fname exists" test -f "$fname"
    done
  fi

  section "Check 7: Tracking files present"
  chk "LESSONS file exists ($P_LESSONS)" test -f "$P_LESSONS"
  chk "PROJECT_MEMORY exists ($P_MEMORY)" test -f "$P_MEMORY"
  chk "LEARNING_LOG.md exists" test -f "LEARNING_LOG.md"
  chk "NEXT_SESSION.md exists" test -f "NEXT_SESSION.md"

  section "Check 8: Git hooks executable"
  chk "pre-commit hook executable" test -x ".git/hooks/pre-commit"
  chk "pre-push hook executable" test -x ".git/hooks/pre-push"

  section "Check 9: .gitignore exists"
  chk ".gitignore exists" test -f ".gitignore"

  section "Check 10: refs/ directory scaffolded correctly"
  chk "refs/ directory exists" test -d "refs"
  chk "refs/README.md exists" test -f "refs/README.md"
  chk "refs/tool-inventory.md exists" test -f "refs/tool-inventory.md"
  chk "refs/gotchas-workflow.md exists" test -f "refs/gotchas-workflow.md"

  # Conditional refs
  if [ "$P_HAS_UI" = "YES" ]; then
    chk "refs/gotchas-frontend.md EXISTS (UI=YES)" test -f "refs/gotchas-frontend.md"
  else
    chk "refs/gotchas-frontend.md ABSENT (UI=NO)" bash -c "! test -f refs/gotchas-frontend.md"
  fi
  if [ "$P_HAS_SKILLS" = "YES" ]; then
    chk "refs/skills-catalog.md EXISTS (Skills=YES)" test -f "refs/skills-catalog.md"
  else
    chk "refs/skills-catalog.md ABSENT (Skills=NO)" bash -c "! test -f refs/skills-catalog.md"
  fi
  if [ "$P_HAS_DEFERRED" = "YES" ]; then
    chk "refs/planned-integrations.md EXISTS (Deferred=YES)" test -f "refs/planned-integrations.md"
  else
    chk "refs/planned-integrations.md ABSENT (Deferred=NO)" bash -c "! test -f refs/planned-integrations.md"
  fi

  section "Check 11: Zero unfilled %% across ALL files"
  local UNFILLED; UNFILLED=$(grep -r '%%[A-Z_]*%%' . \
    --include="*.sh" --include="*.md" --include="*.py" 2>/dev/null \
    | grep -v ".git/" | grep -vE "^\s*#|:[[:space:]]*#" | grep -v "template" | wc -l | tr -d ' ')
  UNFILLED="${UNFILLED:-0}"
  if [ "$UNFILLED" -eq 0 ]; then pass "Zero unfilled placeholders"; else
    fail "$UNFILLED unfilled placeholder occurrences"
    grep -r '%%[A-Z_]*%%' . --include="*.sh" --include="*.md" --include="*.py" 2>/dev/null \
      | grep -v ".git/" | grep -vE "^\s*#|:[[:space:]]*#" | grep -v "template" | head -5 | while read l; do warn "  $l"; done
  fi

  section "Check 12: Build summarizer runs"
  chk "build_summarizer.sh build succeeds" bash build_summarizer.sh build

  # Bonus: regression checks from TestBootstrap
  section "Regression Checks (TestBootstrap bugs)"
  chk "details column exists in tasks" bash -c "sqlite3 $P_DB 'SELECT details FROM tasks LIMIT 1;'"
  chk "completed_on column exists in tasks" bash -c "sqlite3 $P_DB 'SELECT completed_on FROM tasks LIMIT 1;'"
  chk "researched column exists in tasks" bash -c "sqlite3 $P_DB 'SELECT researched FROM tasks LIMIT 1;'"
  chk "check command runs (GO/STOP verdict)" bash db_queries.sh check T-001
  chk "session_briefing runs without fatal error" bash session_briefing.sh
  chk "coherence_check runs without fatal error" bash coherence_check.sh
}

# === WORKFLOW EXERCISE =======================================================
exercise_project() {
  header "Workflow Exercise: $P_NAME"
  cd "$P_DIR"

  section "Core DB commands"
  chk "health: HEALTHY" bash db_queries.sh health
  chk "next: shows task queue" bash db_queries.sh next
  chk "verify: schema complete" bash db_queries.sh verify
  chk "check T-001: GO verdict" bash db_queries.sh check T-001

  section "Quick capture — standard task"
  local QK_OUT; QK_OUT=$(bash db_queries.sh quick "Test standard task" "$P_FIRST" feature 2>&1)
  local QK_ID; QK_ID=$(echo "$QK_OUT" | grep -oE 'QK-[0-9a-f]+')
  if [ -n "$QK_ID" ]; then pass "quick created: $QK_ID"; else fail "quick did not create a QK task"; fi

  section "Loopback lifecycle — circuit breaker path"
  local LB_OUT; LB_OUT=$(bash db_queries.sh quick "Critical regression fix" "$P_SECOND" bug \
    --loopback "$P_FIRST" --severity 1 --gate-critical 2>&1)
  local LB_ID; LB_ID=$(echo "$LB_OUT" | grep -oE 'LB-[0-9a-f]+' | head -1)

  if [ -n "$LB_ID" ]; then
    pass "loopback created: $LB_ID (S1 gate-critical)"

    chk "loopbacks: lists the LB task" bash db_queries.sh loopbacks
    chk "next: shows circuit breaker" bash -c "bash db_queries.sh next 2>&1 | grep -q 'CIRCUIT\|circuit\|🚨\|S1'"

    chk "ack-breaker: acknowledges S1" bash db_queries.sh ack-breaker "$LB_ID" "testing circuit breaker in test suite"

    # done command — this triggers git commit + pre-commit hook
    local DONE_OUT; DONE_OUT=$(bash db_queries.sh done "$LB_ID" 2>&1)
    if echo "$DONE_OUT" | grep -q "Committed\|DONE"; then
      pass "done + auto-commit succeeded for $LB_ID"
    else
      fail "done/commit failed for $LB_ID"
      echo "$DONE_OUT" | tail -10 | while read l; do warn "  $l"; done
    fi

    chk "loopback-lesson: extracts lesson to LESSONS file" bash db_queries.sh loopback-lesson "$LB_ID"
    chk "loopback-stats: shows analytics" bash db_queries.sh loopback-stats
  else
    fail "loopback quick failed — no LB-ID in output"
    echo "$LB_OUT" | tail -5 | while read l; do warn "  $l"; done
  fi

  section "Supporting scripts"
  chk "session_briefing produces output" bash -c "bash session_briefing.sh 2>&1 | grep -q ''"
  chk "coherence_check exits 0" bash coherence_check.sh --quiet
  chk "generate_board.py produces output" bash -c "python3 generate_board.py 2>&1 | grep -q ''"

  section "S3 loopback (regression: t.severity ambiguous column bug)"
  local S3_OUT; S3_OUT=$(bash db_queries.sh quick "Minor improvement" "$P_SECOND" bug \
    --loopback "$P_FIRST" --severity 3 2>&1)
  local S3_ID; S3_ID=$(echo "$S3_OUT" | grep -oE 'LB-[0-9a-f]+' | head -1)
  if [ -n "$S3_ID" ]; then
    chk "next with S3 loopback: no SQL error (t.severity regression check)" bash -c "bash db_queries.sh next 2>&1 | grep -qv 'ambiguous\|Error'"
  else
    warn "Could not create S3 loopback for regression check"
  fi
}

# === CROSS-PROJECT VALIDATION ================================================
validate_cross() {
  header "Cross-Project Validation"
  local OLD_P_NAME="$P_NAME"

  section "5a. Hardcoded project-specific contamination scan"
  # Check for other projects' names leaking into generated test projects.
  # Exclude the current user's username — it legitimately appears in path
  # substitutions (e.g., /Users/<user>/Desktop/test_project1 in work.sh).
  local CONTAM_PATTERN="MasterDashboard\|master_dashboard\|TeaTimer\|tea_timer\|RomaniaBattles\|romania_battles\|Drawstring\|drawstring"
  for d in 1 2 3 4; do
    local PROJ_DIR="$SUITE_DIR/test_project$d"
    [ -d "$PROJ_DIR" ] || continue
    local LEAKS; LEAKS=$(grep -r "$CONTAM_PATTERN" "$PROJ_DIR/" \
      --include="*.sh" --include="*.md" --include="*.py" 2>/dev/null | grep -v ".git/" | wc -l | tr -d ' ')
    P_NAME="project$d"  # for fail() context
    if [ "$LEAKS" -eq 0 ]; then pass "project$d: zero project-specific contamination"; else
      fail "project$d: $LEAKS contamination hit(s) found"
      grep -r "$CONTAM_PATTERN" "$PROJ_DIR/" --include="*.sh" --include="*.md" --include="*.py" 2>/dev/null \
        | grep -v ".git/" | head -3 | while read l; do warn "  $l"; done
    fi
  done

  section "5b. Conditional refs/ file matrix verification"
  local CONFIGS=(
    "1 YES YES YES"   # P1: UI=YES, Skills=YES, Deferred=YES
    "2 NO NO NO"      # P2: UI=NO, Skills=NO, Deferred=NO
    "3 NO NO YES"     # P3: UI=NO, Skills=NO, Deferred=YES
    "4 YES YES NO"    # P4: UI=YES, Skills=YES, Deferred=NO
  )
  for CFG in "${CONFIGS[@]}"; do
    read -r N HAS_UI HAS_SKILLS HAS_DEFERRED <<< "$CFG"
    local D="$SUITE_DIR/test_project$N"
    [ -d "$D" ] || continue
    P_NAME="project$N"
    if [ "$HAS_UI" = "YES" ]; then
      chk "project$N: refs/gotchas-frontend.md EXISTS" test -f "$D/refs/gotchas-frontend.md"
    else
      chk "project$N: refs/gotchas-frontend.md ABSENT" bash -c "! test -f '$D/refs/gotchas-frontend.md'"
    fi
    if [ "$HAS_SKILLS" = "YES" ]; then
      chk "project$N: refs/skills-catalog.md EXISTS" test -f "$D/refs/skills-catalog.md"
    else
      chk "project$N: refs/skills-catalog.md ABSENT" bash -c "! test -f '$D/refs/skills-catalog.md'"
    fi
    if [ "$HAS_DEFERRED" = "YES" ]; then
      chk "project$N: refs/planned-integrations.md EXISTS" test -f "$D/refs/planned-integrations.md"
    else
      chk "project$N: refs/planned-integrations.md ABSENT" bash -c "! test -f '$D/refs/planned-integrations.md'"
    fi
  done

  section "5c. RULES + extended rules conditional sections"
  local UI_PROJECTS=(1 4); local NON_UI=(2 3)
  local GEMINI_PROJECTS=(1 3); local NO_GEMINI=(2 4)
  local TEAMS_PROJECTS=(3)

  # Helper: search both core RULES and refs/rules-extended.md
  _rules_grep() {
    local DIR="$1" PATTERN="$2"
    grep -rqi "$PATTERN" "$DIR"/*RULES*.md "$DIR"/refs/rules-extended.md 2>/dev/null
  }

  for N in "${UI_PROJECTS[@]}"; do
    local D="$SUITE_DIR/test_project$N"
    [ -d "$D" ] || continue
    P_NAME="project$N"
    chk "project$N RULES: visual verification section present (UI=YES)" \
      bash -c "_rules_grep() { grep -rqi \"\$2\" \"\$1\"/*RULES*.md \"\$1\"/refs/rules-extended.md 2>/dev/null; }; _rules_grep '$D' 'visual.*active\|screenshot\|visual verification gate'"
  done

  for N in "${NON_UI[@]}"; do
    local D="$SUITE_DIR/test_project$N"
    [ -d "$D" ] || continue
    P_NAME="project$N"
    chk "project$N RULES: visual verification is N/A (UI=NO)" \
      bash -c "grep -rqi 'not applicable\|N/A\|no visual' '$D'/*RULES*.md '$D'/refs/rules-extended.md 2>/dev/null"
  done

  for N in "${GEMINI_PROJECTS[@]}"; do
    local D="$SUITE_DIR/test_project$N"
    [ -d "$D" ] || continue
    P_NAME="project$N"
    chk "project$N RULES: Gemini section present (Gemini=YES)" \
      bash -c "grep -rqi 'gemini' '$D'/*RULES*.md '$D'/refs/rules-extended.md 2>/dev/null"
  done

  P_NAME="project3"
  local D3="$SUITE_DIR/test_project3"
  if [ -d "$D3" ]; then
    chk "project3 RULES: teams topology section present (Teams=YES)" \
      bash -c "grep -rqi 'topology\|teams.*active\|orchestrator' '$D3'/*RULES*.md '$D3'/refs/rules-extended.md 2>/dev/null"
  fi

  section "5d. Zero unfilled placeholders across ALL projects"
  for d in 1 2 3 4; do
    local D="$SUITE_DIR/test_project$d"
    [ -d "$D" ] || continue
    P_NAME="project$d"
    local COUNT; COUNT=$(grep -r '%%[A-Z_]*%%' "$D/" \
      --include="*.sh" --include="*.md" --include="*.py" 2>/dev/null \
      | grep -v ".git/" | grep -vE "^\s*#|:[[:space:]]*#" | grep -v "template" | wc -l | tr -d ' ')
    COUNT="${COUNT:-0}"
    if [ "$COUNT" -eq 0 ]; then pass "project$d: zero unfilled placeholders"; else
      fail "project$d: $COUNT unfilled placeholder occurrences"
    fi
  done

  section "5e. DB names match project slugs"
  chk "project1 has test_web_app.db" test -f "$SUITE_DIR/test_project1/test_web_app.db"
  chk "project2 has rust_cli.db" test -f "$SUITE_DIR/test_project2/rust_cli.db"
  chk "project3 has fastapi_service.db" test -f "$SUITE_DIR/test_project3/fastapi_service.db"
  chk "project4 has swift_desktop_app.db" test -f "$SUITE_DIR/test_project4/swift_desktop_app.db"

  P_NAME="$OLD_P_NAME"
}

# === REGRESSION TESTS ========================================================
# These validate template-level invariants without requiring a deployed project.
# Run independently via: bash test_bootstrap_suite.sh --regression
regression_tests() {
  header "Regression Tests (Template-Level)"
  P_NAME="regression"

  section "R1. grep -P not used in any template script"
  # Match grep with -P flag: -P, -oP, -cP, etc. (Perl regex unsupported on macOS)
  local GREP_P_HITS; GREP_P_HITS=$(grep -rE 'grep[[:space:]]+-[a-zA-Z]*P[[:space:]]' "$TEMPLATES/" \
    --include="*.sh" 2>/dev/null | wc -l | tr -d ' ')
  GREP_P_HITS="${GREP_P_HITS:-0}"
  if [ "$GREP_P_HITS" -eq 0 ]; then pass "Zero grep -P usage in template scripts"
  else fail "$GREP_P_HITS grep -P occurrence(s) in template scripts"; fi

  section "R2. No project-specific contamination in templates"
  local CONTAM_TERMS="MasterDashboard\|master_dashboard\|TeaTimer\|tea_timer\|RomaniaBattles\|romania_battles\|Drawstring\|drawstring"
  local CONTAM_HITS; CONTAM_HITS=$(grep -r "$CONTAM_TERMS" "$TEMPLATES/" \
    --include="*.sh" --include="*.md" --include="*.py" --include="*.json" 2>/dev/null \
    | grep -v ".git/" | wc -l | tr -d ' ')
  CONTAM_HITS="${CONTAM_HITS:-0}"
  if [ "$CONTAM_HITS" -eq 0 ]; then pass "Zero project-specific contamination in templates"
  else
    fail "$CONTAM_HITS contamination hit(s) in templates"
    grep -r "$CONTAM_TERMS" "$TEMPLATES/" --include="*.sh" --include="*.md" --include="*.py" --include="*.json" 2>/dev/null \
      | grep -v ".git/" | head -5 | while read l; do warn "  $l"; done
  fi

  section "R3. init-db works without pre-existing DB file"
  # Create a minimal working copy of db_queries wrapper with placeholders filled
  local TEST_WORKDIR="/tmp/bootstrap_test_initdb_$$"
  rm -rf "$TEST_WORKDIR"
  mkdir -p "$TEST_WORKDIR"
  cp "$TEMPLATE_SCRIPTS/db_queries.template.sh" "$TEST_WORKDIR/db_queries.sh"
  chmod +x "$TEST_WORKDIR/db_queries.sh"
  # Fill critical placeholders with test values
  sed -i '' \
    -e 's/%%PROJECT_DB%%/test_regr.db/g' \
    -e 's/%%PROJECT_NAME%%/TestRegression/g' \
    -e 's/%%LESSONS_FILE%%/LESSONS_TEST.md/g' \
    -e 's/%%PHASES%%//g' \
    "$TEST_WORKDIR/db_queries.sh" 2>/dev/null
  touch "$TEST_WORKDIR/LESSONS_TEST.md"

  local TEST_DB="$TEST_WORKDIR/test_regr.db"
  rm -f "$TEST_DB"
  if (cd "$TEST_WORKDIR" && bash db_queries.sh init-db >/dev/null 2>&1) && [ -f "$TEST_DB" ]; then
    pass "init-db creates DB from scratch"
  else
    fail "init-db failed without pre-existing DB file"
  fi

  section "R4. init-db is idempotent (run twice)"
  if [ -f "$TEST_DB" ]; then
    if (cd "$TEST_WORKDIR" && bash db_queries.sh init-db >/dev/null 2>&1); then
      pass "init-db runs twice without error"
    else
      fail "init-db failed on second run (not idempotent)"
    fi
  else
    warn "Skipped — init-db did not create DB in R3"
  fi

  section "R5. Full init-db→health→next sequence"
  if [ -f "$TEST_DB" ]; then
    if (cd "$TEST_WORKDIR" && bash db_queries.sh health >/dev/null 2>&1); then
      pass "health passes after init-db"
    else
      fail "health failed after init-db"
    fi
    if (cd "$TEST_WORKDIR" && bash db_queries.sh next >/dev/null 2>&1); then
      pass "next runs after init-db (even if no tasks)"
    else
      fail "next failed after init-db"
    fi
  else
    warn "Skipped — no DB from R3/R4"
  fi
  rm -rf "$TEST_WORKDIR"

  section "R6. Hook templates produce valid JSON (matcher field present)"
  local HOOK_DIR="$TEMPLATES/hooks"
  if [ -d "$HOOK_DIR" ]; then
    local HOOK_COUNT=0; local HOOK_VALID=0
    for hook_file in "$HOOK_DIR"/*.sh; do
      [ -f "$hook_file" ] || continue
      HOOK_COUNT=$((HOOK_COUNT+1))
      # Check the hook is executable (or at least has shebang)
      if head -1 "$hook_file" | grep -q '^#!/'; then
        HOOK_VALID=$((HOOK_VALID+1))
      fi
    done
    if [ "$HOOK_COUNT" -gt 0 ]; then
      if [ "$HOOK_VALID" -eq "$HOOK_COUNT" ]; then
        pass "All $HOOK_COUNT hook templates have valid shebangs"
      else
        fail "$((HOOK_COUNT - HOOK_VALID))/$HOOK_COUNT hook templates missing shebang"
      fi
    else
      warn "No hook templates found in $HOOK_DIR"
    fi
  else
    warn "No hooks directory at $HOOK_DIR"
  fi

  # Check settings template references valid hook scripts
  # Settings references use deployed names (foo.sh), templates use (foo.template.sh)
  local SETTINGS_TMPL="$TEMPLATES/settings/settings.template.json"
  if [ -f "$SETTINGS_TMPL" ]; then
    local HOOK_REFS; HOOK_REFS=$(grep -oE '[a-z_-]+\.sh' "$SETTINGS_TMPL" 2>/dev/null | sort -u)
    local MISSING_HOOKS=0
    for href in $HOOK_REFS; do
      local TMPL_NAME="${href%.sh}.template.sh"
      if [ ! -f "$HOOK_DIR/$href" ] && [ ! -f "$HOOK_DIR/$TMPL_NAME" ] && \
         [ ! -f "$TEMPLATES/scripts/$href" ] && [ ! -f "$TEMPLATES/scripts/${href%.sh}.template.sh" ]; then
        warn "settings.json references $href but no matching template found"
        MISSING_HOOKS=$((MISSING_HOOKS+1))
      fi
    done
    if [ "$MISSING_HOOKS" -eq 0 ]; then
      pass "All hook references in settings template resolve to existing templates"
    else
      fail "$MISSING_HOOKS hook reference(s) in settings template don't resolve"
    fi
  else
    warn "No settings template at $SETTINGS_TMPL"
  fi
}

# === EDGE CASE: HYPHENATED PROJECT NAME ======================================
# Tests that sed placeholder substitution handles hyphens correctly.
# Run via: bash test_bootstrap_suite.sh --edge-hyphen
edge_case_hyphen() {
  header "Edge Case: Hyphenated Project Name"
  P_NAME="My-Cool-App"
  local SLUG="my_cool_app"
  local TEST_DIR="/tmp/bootstrap_edge_hyphen_$$"
  mkdir -p "$TEST_DIR"

  section "Placeholder substitution with hyphens"
  # Copy RULES template and try substitution
  if [ -f "$RULES_TEMPLATE" ]; then
    cp "$RULES_TEMPLATE" "$TEST_DIR/RULES_TEST.md"
    sed -i '' "s/%%PROJECT_NAME%%/My-Cool-App/g" "$TEST_DIR/RULES_TEST.md" 2>/dev/null || \
      sed -i "s/%%PROJECT_NAME%%/My-Cool-App/g" "$TEST_DIR/RULES_TEST.md" 2>/dev/null
    if grep -q "My-Cool-App" "$TEST_DIR/RULES_TEST.md" 2>/dev/null; then
      pass "%%PROJECT_NAME%% substituted with hyphenated name"
    else
      fail "%%PROJECT_NAME%% substitution failed with hyphens"
    fi
    # Check no corruption from sed
    local REMAINING; REMAINING=$(grep -c '%%PROJECT_NAME%%' "$TEST_DIR/RULES_TEST.md" 2>/dev/null)
    REMAINING="${REMAINING:-0}"
    if [ "$REMAINING" -eq 0 ]; then
      pass "All %%PROJECT_NAME%% instances replaced (none remaining)"
    else
      fail "$REMAINING %%PROJECT_NAME%% instances remain after sed"
    fi
  else
    warn "RULES_TEMPLATE not found, skipping"
  fi

  section "DB operations with hyphenated slug"
  # Create a working copy with placeholders filled
  cp "$TEMPLATE_SCRIPTS/db_queries.template.sh" "$TEST_DIR/db_queries.sh"
  chmod +x "$TEST_DIR/db_queries.sh"
  sed -i '' \
    -e "s/%%PROJECT_DB%%/${SLUG}.db/g" \
    -e "s/%%PROJECT_NAME%%/My-Cool-App/g" \
    -e 's/%%LESSONS_FILE%%/LESSONS_TEST.md/g' \
    -e 's/%%PHASES%%//g' \
    "$TEST_DIR/db_queries.sh" 2>/dev/null
  touch "$TEST_DIR/LESSONS_TEST.md"

  if (cd "$TEST_DIR" && bash db_queries.sh init-db >/dev/null 2>&1) && [ -f "$TEST_DIR/${SLUG}.db" ]; then
    pass "init-db succeeds with hyphen-derived slug"
    if (cd "$TEST_DIR" && bash db_queries.sh health >/dev/null 2>&1); then
      pass "health passes with hyphen-derived slug"
    else
      fail "health failed with hyphen-derived slug"
    fi
  else
    fail "init-db failed with hyphen-derived slug"
  fi

  rm -rf "$TEST_DIR"
}

# === PYTHON CLI INTEGRATION TESTS ============================================
# Validates the Python dbq package end-to-end through the db_queries.sh wrapper.
# Run independently via: bash test_bootstrap_suite.sh --python-cli
python_cli_tests() {
  header "Python CLI Integration Tests"
  P_NAME="python-cli"

  # Pre-flight: Python 3.10+ required
  if ! python3 -c "import sys; assert sys.version_info >= (3, 10)" 2>/dev/null; then
    fail "Python 3.10+ not available — cannot run Python CLI tests"
    return
  fi

  local TEST_DIR="/tmp/bootstrap_test_pycli_$$"
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"

  # Copy the Python wrapper and fill placeholders
  cp "$TEMPLATE_SCRIPTS/db_queries.template.sh" "$TEST_DIR/db_queries.sh"
  chmod +x "$TEST_DIR/db_queries.sh"
  sed -i '' \
    -e 's/%%PROJECT_DB%%/pycli_test.db/g' \
    -e 's/%%PROJECT_NAME%%/PyCLITest/g' \
    -e 's/%%LESSONS_FILE%%/LESSONS_PYCLI.md/g' \
    -e 's/%%PHASES%%/P1-TEST P2-SHIP/g' \
    "$TEST_DIR/db_queries.sh" 2>/dev/null
  touch "$TEST_DIR/LESSONS_PYCLI.md"

  local DB_FILE="$TEST_DIR/pycli_test.db"

  section "PC1. init-db creates database"
  local INIT_OUT
  INIT_OUT=$(cd "$TEST_DIR" && bash db_queries.sh init-db 2>&1)
  if [ -f "$DB_FILE" ]; then
    pass "init-db created DB file"
  else
    fail "init-db did not create DB file"
    warn "Output: $INIT_OUT"
    rm -rf "$TEST_DIR"
    return
  fi

  section "PC2. health returns HEALTHY verdict"
  local HEALTH_OUT
  HEALTH_OUT=$(cd "$TEST_DIR" && bash db_queries.sh health 2>&1)
  if echo "$HEALTH_OUT" | grep -qi "HEALTHY"; then
    pass "health reports HEALTHY"
  else
    fail "health did not report HEALTHY"
    warn "Output: $HEALTH_OUT"
  fi

  section "PC3. quick creates task with QK-* ID"
  local QUICK_OUT
  QUICK_OUT=$(cd "$TEST_DIR" && bash db_queries.sh quick "Test task" P1-TEST 2>&1)
  if echo "$QUICK_OUT" | grep -qE "QK-[0-9]"; then
    pass "quick returned QK-* task ID"
  else
    fail "quick did not return QK-* task ID"
    warn "Output: $QUICK_OUT"
  fi

  section "PC4. done shows DONE in output"
  # Extract task ID from quick output for done command
  local TASK_ID
  TASK_ID=$(echo "$QUICK_OUT" | grep -oE "QK-[0-9]+" | head -1)
  local DONE_OUT
  if [ -n "$TASK_ID" ]; then
    DONE_OUT=$(cd "$TEST_DIR" && bash db_queries.sh done "$TASK_ID" 2>&1)
  else
    DONE_OUT=$(cd "$TEST_DIR" && bash db_queries.sh done 2>&1)
  fi
  if echo "$DONE_OUT" | grep -qi "DONE"; then
    pass "done shows DONE in output"
  else
    fail "done did not show DONE in output"
    warn "Output: $DONE_OUT"
  fi

  section "PC5. next produces output"
  local NEXT_OUT
  NEXT_OUT=$(cd "$TEST_DIR" && bash db_queries.sh next 2>&1)
  if [ -n "$NEXT_OUT" ]; then
    pass "next produces output"
  else
    fail "next produced no output"
  fi

  # Cleanup
  rm -rf "$TEST_DIR"
}

# === CLEANUP =================================================================
cleanup() {
  echo -e "\n${YELLOW}Removing test directories...${RESET}"
  for d in 1 2 3 4; do
    if [ -d "$SUITE_DIR/test_project$d" ]; then
      rm -rf "$SUITE_DIR/test_project$d"
      echo -e "  ${GREEN}✅${RESET} Removed test_project$d"
    fi
  done
  echo -e "${GREEN}Cleanup complete.${RESET}"
}

# === SUMMARY =================================================================
print_summary() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║              TEST SUITE SUMMARY                      ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  Checks: ${BOLD}$TOTAL_CHECKS${RESET} | Pass: ${GREEN}$TOTAL_PASS${RESET} | Fail: ${RED}$TOTAL_FAIL${RESET}"
  echo ""
  if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}ALL CHECKS PASSED ✅${RESET}"
    echo -e "  ${GREEN}Bootstrap framework validated across all 4 archetypes.${RESET}"
  else
    echo -e "  ${RED}${BOLD}$TOTAL_FAIL FAILURE(S) ❌${RESET}"
    echo ""
    echo -e "  ${BOLD}Failed checks:${RESET}"
    for f in "${FAILURES[@]}"; do
      echo -e "    ${RED}•${RESET} $f"
    done
    echo ""
    echo -e "  ${YELLOW}Fix template bugs and re-run to confirm. Test projects preserved for debugging.${RESET}"
  fi
  echo ""
}

# === MAIN ====================================================================
run_project() {
  local N="$1"
  load_project_config "$N"
  create_specs
  deploy_project
  verify_project
  exercise_project
}

main() {
  echo -e "${BOLD}Bootstrap Framework Test Suite${RESET}"
  echo -e "Tests the template engine across 4 project archetypes."
  echo ""

  # Parse arguments
  if [ "${1:-}" = "--cleanup" ]; then
    cleanup; exit 0
  fi

  if [ "${1:-}" = "--cross" ]; then
    P_NAME="cross-validation"
    validate_cross
    print_summary; exit 0
  fi

  if [ "${1:-}" = "--regression" ]; then
    regression_tests
    print_summary; exit 0
  fi

  if [ "${1:-}" = "--edge-hyphen" ]; then
    edge_case_hyphen
    print_summary; exit 0
  fi

  if [ "${1:-}" = "--python-cli" ]; then
    python_cli_tests
    print_summary; exit 0
  fi

  if [ "${1:-}" = "--verify" ] && [ -n "${2:-}" ]; then
    load_project_config "$2"
    verify_project
    print_summary; exit 0
  fi

  if [ "${1:-}" = "--exercise" ] && [ -n "${2:-}" ]; then
    load_project_config "$2"
    exercise_project
    print_summary; exit 0
  fi

  # Run pre-flight before any work
  preflight

  # If specific project numbers given, run only those
  if [ $# -gt 0 ] && [[ "$1" =~ ^[1-4]$ ]]; then
    for N in "$@"; do
      run_project "$N"
    done
    P_NAME="cross-validation"
    validate_cross
    print_summary; exit 0
  fi

  # Default: run regression + all 4 + cross validation
  regression_tests

  for N in 1 2 3 4; do
    run_project "$N"
  done

  P_NAME="cross-validation"
  validate_cross
  print_summary
}

# Fix for RULES_OUTPUT_PATH in generate_rules
export RULES_OUTPUT_PATH="RULES.md"

main "$@"
