"""
Knowledge commands: lessons, log-lesson, promote, escalate.

All modify markdown files outside the DB using marker-based insertion.
Pattern: content.replace(marker, new_text + "\n" + marker) — proven in loopbacks.py.
"""
import os
import re
import sys
from datetime import datetime
from pathlib import Path

from ..db import Database
from ..config import ProjectConfig
from .. import output


def _today() -> str:
    return datetime.now().strftime("%Y-%m-%d")


# ── lessons command ─────────────────────────────────────────────────

def cmd_lessons(config: ProjectConfig):
    """Display LESSONS.md contents with staleness and violation tracking.

    Matches db_queries_legacy.template.sh lines 1226-1267.
    """
    lessons_file = config.lessons_file
    if not lessons_file:
        print("❌ No LESSONS file found in project directory")
        sys.exit(1)

    lf = Path(lessons_file)
    if not lf.exists():
        print(f"❌ {lf.name} not found")
        sys.exit(1)

    output.print_section("Lessons & Corrections")
    print("")

    content = lf.read_text()
    today_ts = datetime.now().timestamp()

    # Extract correction rows: lines starting with "| 20" (date-prefixed table rows)
    count = 0
    for line in content.splitlines():
        if not line.startswith("| 20"):
            continue
        parts = line.split("|")
        if len(parts) < 7:
            continue
        if count >= 20:
            break

        date = parts[1].strip()
        pattern = parts[3].strip() if len(parts) > 3 else ""
        rule = parts[4].strip() if len(parts) > 4 else ""
        last_ref = parts[5].strip() if len(parts) > 5 else ""
        violations = parts[6].strip() if len(parts) > 6 else ""

        # Staleness check
        stale = ""
        if last_ref and last_ref != "—":
            try:
                ref_dt = datetime.strptime(last_ref, "%Y-%m-%d")
                days_ago = int((today_ts - ref_dt.timestamp()) / 86400)
                if days_ago > 30:
                    stale = f" ⚠️  STALE ({days_ago} days)"
            except ValueError:
                pass
        elif last_ref == "—":
            stale = " ⚠️  NEVER REFERENCED"

        # Violation warning
        viol_warn = ""
        try:
            viol_count = int(violations)
            if viol_count >= 2:
                viol_warn = f" 🔴 VIOLATED {viol_count}x — rewrite prevention rule!"
        except (ValueError, TypeError):
            pass

        print(f"  [{date}] {pattern}")
        print(f"    → {rule}")
        print(f"    Last ref: {last_ref} | Violations: {violations}{stale}{viol_warn}")
        print("")
        count += 1


# ── log-lesson command ──────────────────────────────────────────────

def cmd_log_lesson(
    config: ProjectConfig,
    what_wrong: str,
    pattern: str,
    prevention: str,
    bp_category: str = "",
    bp_file: str = "",
):
    """Atomically append a correction to LESSONS file.

    Matches db_queries_legacy.template.sh lines 1269-1383.
    Uses anchor-based insertion: finds CORRECTIONS-ANCHOR or ## Insights/Universal Patterns.
    """
    lessons_file = config.lessons_file
    if not lessons_file:
        print("❌ No LESSONS file found in project directory")
        sys.exit(1)

    lf = Path(lessons_file)
    if not lf.exists():
        print(f"❌ {lf.name} not found")
        sys.exit(1)

    today = _today()
    lines = lf.read_text().splitlines()

    # Find anchor line — two modes:
    # 1. CORRECTIONS-ANCHOR: insert AFTER anchor (anchor stays above entries)
    # 2. Fallback (## Insights/Universal): insert BEFORE section header
    insert_idx = None
    for i, line in enumerate(lines):
        if "<!-- CORRECTIONS-ANCHOR -->" in line:
            insert_idx = i + 1  # after anchor
    if insert_idx is None:
        for i, line in enumerate(lines):
            if line.startswith("## Insights") or line.startswith("## Universal Patterns"):
                insert_idx = i  # before section header
                break

    if insert_idx is None:
        print("❌ Could not find insertion point in LESSONS file")
        print("   Add <!-- CORRECTIONS-ANCHOR --> where new corrections should appear.")
        sys.exit(1)

    # Build entry
    entry_lines = [
        "",
        f"### {today} — {what_wrong}",
        f"**Pattern:** {pattern}",
        f"**Prevention:** {prevention}",
    ]

    new_lines = lines[:insert_idx] + entry_lines + lines[insert_idx:]
    lf.write_text("\n".join(new_lines) + "\n")

    # Verify
    content = lf.read_text()
    if what_wrong in content:
        print(f"✅ Lesson logged: {pattern}")
        print(f"   → {prevention}")
        print("")
        print("  💡 If this has a code-level root cause, add a test to src/__tests__/regression.test.ts")
        print("     This turns prose lessons into automated guards.")
    else:
        print("❌ Failed to write lesson to file")
        sys.exit(1)

    # --bp escalation
    if bp_category:
        _escalate_to_backlog(
            description=pattern,
            category=bp_category,
            affected_file=bp_file or "unknown (review needed)",
            priority="P2",
            project_name=config.project_name,
        )


# ── promote command ─────────────────────────────────────────────────

def cmd_promote(config: ProjectConfig, pattern: str, rule: str = ""):
    """Quick-promote a universal pattern to LESSONS_UNIVERSAL.md.

    Matches db_queries_legacy.template.sh lines 2682-2701.
    """
    universal = Path.home() / ".claude" / "LESSONS_UNIVERSAL.md"
    if not universal.exists():
        print(f"❌ {universal} not found — run: bash ~/.claude/harvest.sh")
        sys.exit(1)

    today = _today()
    prevention = rule or "See source project LESSONS.md"

    with open(str(universal), "a") as f:
        f.write(f"| {today} | {pattern} | {config.project_name} | {prevention} |\n")

    print("✅ Promoted to LESSONS_UNIVERSAL.md")
    print("   ⚠️  Remember to mark the source entry as promoted in LESSONS*.md")


# ── escalate command ────────────────────────────────────────────────

def cmd_escalate(
    config: ProjectConfig,
    description: str,
    category: str = "template",
    affected_file: str = "unknown (review needed)",
    priority: str = "P2",
):
    """Escalate to bootstrap backlog for template/framework improvement.

    Matches db_queries_legacy.template.sh lines 2703-2782.
    """
    # Validate category
    valid_cats = ("template", "framework", "process", "system")
    if category not in valid_cats:
        print(f"⚠️  Unknown category '{category}' — using 'template'")
        category = "template"

    _escalate_to_backlog(
        description=description,
        category=category,
        affected_file=affected_file,
        priority=priority,
        project_name=config.project_name,
    )


def _escalate_to_backlog(
    description: str,
    category: str,
    affected_file: str,
    priority: str,
    project_name: str,
):
    """Shared escalation logic used by both escalate and log-lesson --bp."""
    backlog = Path.home() / ".claude" / "dev-framework" / "BOOTSTRAP_BACKLOG.md"
    if not backlog.exists():
        print(f"❌ {backlog} not found")
        sys.exit(1)

    content = backlog.read_text()
    lines = content.splitlines()

    # Derive next BP-ID
    bp_ids = re.findall(r"BP-(\d+)", content)
    if bp_ids:
        next_id = max(int(x) for x in bp_ids) + 1
    else:
        next_id = 1
    bp_id = f"BP-{next_id:03d}"

    today = _today()

    # Check for duplicates
    if affected_file != "unknown (review needed)":
        dup_count = content.count(affected_file)
        if dup_count > 0:
            print(f"⚠️  Backlog already has {dup_count} item(s) mentioning {affected_file}")
            print("   Adding anyway — review for duplicates with: bash ~/.claude/dev-framework/apply_backlog.sh")

    # Find anchor: <!-- PENDING-ANCHOR or ## Applied
    anchor_idx = None
    for i, line in enumerate(lines):
        if "<!-- PENDING-ANCHOR" in line:
            anchor_idx = i
    if anchor_idx is None:
        for i, line in enumerate(lines):
            if line.startswith("## Applied"):
                anchor_idx = i
                break

    if anchor_idx is None:
        print("❌ Could not find insertion point in BOOTSTRAP_BACKLOG.md")
        sys.exit(1)

    entry_lines = [
        "",
        f"### {bp_id} [{category}] {description}",
        f"- **Escalated:** {today}",
        f"- **Source:** {project_name}",
        f"- **Priority:** {priority}",
        f"- **Affected:** {affected_file}",
        f"- **Description:** {description}",
        "- **Change:** (to be determined during review)",
        "- **Status:** pending",
        "",
    ]

    new_lines = lines[:anchor_idx] + entry_lines + lines[anchor_idx:]
    backlog.write_text("\n".join(new_lines) + "\n")

    print(f"✅ Escalated to bootstrap backlog as {bp_id} [{category}] ({priority})")
    print(f"   Review: bash ~/.claude/dev-framework/apply_backlog.sh {bp_id}")
