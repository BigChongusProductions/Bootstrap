"""
Delegation commands: delegation, delegation-md, sync-check.

delegation: SQL query + formatted output.
delegation-md: regenerate AGENT_DELEGATION.md §8 between HTML comment markers.
sync-check: compare DB tasks vs AGENT_DELEGATION.md, report drift.
"""
import sys
from pathlib import Path

from ..db import Database
from ..config import ProjectConfig
from .. import output


# ── delegation command ──────────────────────────────────────────────

def cmd_delegation(db: Database, phase_filter: str = ""):
    """Show delegation status for phases.

    Matches db_queries_legacy.template.sh lines 1385-1437.
    """
    print("")
    print(output.section_header("Delegation Map (from DB)"))
    print("")

    if phase_filter:
        phases = db.fetch_all(
            "SELECT DISTINCT phase FROM tasks WHERE phase=? ORDER BY phase",
            (phase_filter,),
        )
    else:
        phases = db.fetch_all(
            "SELECT DISTINCT phase FROM tasks ORDER BY phase"
        )

    if not phases:
        print("  No tasks found.")
        print("")
        return

    for phase_row in phases:
        phase = phase_row["phase"]

        remaining = db.fetch_scalar(
            "SELECT COUNT(*) FROM tasks "
            "WHERE phase=? AND status NOT IN ('DONE','SKIP')",
            (phase,),
        )
        phase_status = "DONE" if remaining == 0 else "IN PROGRESS"

        print(f"### {phase} ({phase_status})")
        print("| Task | Tier | Skill | Status | Research Notes |")
        print("|------|------|-------|--------|----------------|")

        rows = db.fetch_all(
            "SELECT id, title, COALESCE(UPPER(tier), '?') AS tier, "
            "COALESCE(skill, '—') AS skill, status, "
            "COALESCE(substr(research_notes, 1, 80), '—') AS notes, "
            "CASE WHEN length(COALESCE(research_notes,'')) > 80 THEN '...' ELSE '' END AS ellipsis "
            "FROM tasks WHERE phase=? ORDER BY sort_order",
            (phase,),
        )

        for r in rows:
            notes = r["notes"] + r["ellipsis"]
            print(f"| {r['id']} {r['title']} | {r['tier']} | {r['skill']} | {r['status']} | {notes} |")

        print("")


# ── delegation-md command ───────────────────────────────────────────

def cmd_delegation_md(db: Database, config: ProjectConfig):
    """Auto-regenerate AGENT_DELEGATION.md §8 from DB.

    Matches db_queries_legacy.template.sh lines 2583-2680.
    Replaces content between <!-- DELEGATION-START --> and <!-- DELEGATION-END --> markers.
    """
    deleg_file = config.project_dir / "AGENT_DELEGATION.md"
    if not deleg_file.exists():
        print("❌ AGENT_DELEGATION.md not found")
        sys.exit(1)

    content = deleg_file.read_text()

    if "<!-- DELEGATION-START -->" not in content:
        print("❌ Missing <!-- DELEGATION-START --> marker in AGENT_DELEGATION.md")
        print("   Add <!-- DELEGATION-START --> and <!-- DELEGATION-END --> markers around §8 content.")
        sys.exit(1)

    if "<!-- DELEGATION-END -->" not in content:
        print("❌ Missing <!-- DELEGATION-END --> marker in AGENT_DELEGATION.md")
        sys.exit(1)

    # Build new content
    new_section_lines = []

    phases = db.fetch_all(
        "SELECT DISTINCT phase FROM tasks "
        "WHERE queue != 'INBOX' AND COALESCE(track,'forward')='forward' "
        "ORDER BY phase"
    )

    all_phase_names = [r["phase"] for r in phases]

    for phase_row in phases:
        phase = phase_row["phase"]
        done_count = db.fetch_scalar(
            "SELECT COUNT(*) FROM tasks "
            "WHERE phase=? AND COALESCE(track,'forward')='forward' AND status='DONE'",
            (phase,),
        )
        total_count = db.fetch_scalar(
            "SELECT COUNT(*) FROM tasks "
            "WHERE phase=? AND COALESCE(track,'forward')='forward' AND queue != 'INBOX'",
            (phase,),
        )

        # Check if gated and fully done — collapse to 1-line summary
        is_gated = db.fetch_scalar(
            "SELECT COUNT(*) FROM phase_gates WHERE phase=?",
            (phase,),
        )

        if is_gated > 0 and done_count == total_count:
            gate_date = db.fetch_one(
                "SELECT gated_on FROM phase_gates WHERE phase=?",
                (phase,),
            )
            new_section_lines.append(
                f"### {phase} ({done_count}/{total_count} DONE) — gated {gate_date}"
            )
            new_section_lines.append("")
            continue

        if done_count == total_count:
            new_section_lines.append(f"### {phase} (DONE — {done_count}/{total_count})")
        else:
            new_section_lines.append(f"### {phase} ({done_count}/{total_count} done)")

        new_section_lines.append("| Task | Tier | Skill | Status | Why |")
        new_section_lines.append("|------|------|-------|--------|-----|")

        rows = db.fetch_all(
            "SELECT id, title, COALESCE(tier,'—') AS tier, "
            "COALESCE(skill,'—') AS skill, status, "
            "COALESCE(research_notes,'') AS notes "
            "FROM tasks "
            "WHERE phase=? AND queue != 'INBOX' AND COALESCE(track,'forward')='forward' "
            "ORDER BY sort_order, id",
            (phase,),
        )

        for r in rows:
            note_part = ""
            if r["notes"]:
                note_part = f" **RESEARCH:** {r['notes']}"
            new_section_lines.append(
                f"| {r['id']} {r['title']} | {r['tier']} | {r['skill']} | {r['status']} |{note_part} |"
            )

        new_section_lines.append("")

    # Check for INBOX items
    inbox_ct = db.fetch_scalar(
        "SELECT COUNT(*) FROM tasks WHERE queue='INBOX'"
    )
    if inbox_ct > 0:
        new_section_lines.append(f"### INBOX ({inbox_ct} untriaged)")
        new_section_lines.append("| Task | Title | Tag |")
        new_section_lines.append("|------|-------|-----|")

        inbox_rows = db.fetch_all(
            "SELECT id, title, COALESCE(details,'') AS tag "
            "FROM tasks WHERE queue='INBOX' ORDER BY id"
        )
        for r in inbox_rows:
            new_section_lines.append(f"| {r['id']} | {r['title']} | {r['tag']} |")
        new_section_lines.append("")

    # Reassemble file: before START + START marker + new content + END marker + after END
    lines = content.splitlines()
    before = []
    after = []
    state = "before"
    for line in lines:
        if state == "before":
            before.append(line)
            if "<!-- DELEGATION-START -->" in line:
                state = "inside"
        elif state == "inside":
            if "<!-- DELEGATION-END -->" in line:
                after.append(line)
                state = "after"
        elif state == "after":
            after.append(line)

    result = before + new_section_lines + after
    deleg_file.write_text("\n".join(result) + "\n")

    phase_str = " ".join(all_phase_names)
    print(f"✅ Regenerated AGENT_DELEGATION.md §8 from DB")
    print(f"   Phases: {phase_str}")
    if inbox_ct > 0:
        print(f"   📥 {inbox_ct} inbox item(s) included")


# ── sync-check command ──────────────────────────────────────────────

def cmd_sync_check(db: Database, config: ProjectConfig):
    """Detect drift between DB task list and AGENT_DELEGATION.md §8.

    Matches db_queries_legacy.template.sh lines 1439-1540.
    """
    deleg_file = config.project_dir / "AGENT_DELEGATION.md"
    drift_count = 0

    print("")
    print(output.section_header("Sync Check: DB ↔ AGENT_DELEGATION.md"))

    if not deleg_file.exists():
        print("  ❌ AGENT_DELEGATION.md not found")
        sys.exit(1)

    deleg_content = deleg_file.read_text()

    # Check 1: Tasks in DB but not mentioned in markdown
    rows = db.fetch_all(
        "SELECT id, title, COALESCE(tier,'?') AS tier "
        "FROM tasks WHERE status != 'DONE' ORDER BY sort_order"
    )

    missing_from_md = []
    for r in rows:
        if r["id"] not in deleg_content:
            missing_from_md.append(r)
            drift_count += 1

    if missing_from_md:
        print("")
        print("  ⚠️  Tasks in DB but NOT in AGENT_DELEGATION.md:")
        for r in missing_from_md:
            print(f"    {r['id']} ({r['tier']}): {r['title']}")

    # Check 2: Tasks without tier assignment
    untiered = db.fetch_all(
        "SELECT id, title FROM tasks "
        "WHERE tier IS NULL AND status NOT IN ('DONE', 'SKIP') "
        "ORDER BY sort_order"
    )

    if untiered:
        print("  ⚠️  Tasks without tier assignment:")
        for r in untiered:
            print(f"    {r['id']}: {r['title']}")
        print("")
        drift_count += len(untiered)

    # Check 3: Research notes not reflected in markdown
    research_rows = db.fetch_all(
        "SELECT id FROM tasks "
        "WHERE research_notes IS NOT NULL AND research_notes != '' "
        "AND status NOT IN ('DONE', 'SKIP') "
        "ORDER BY sort_order"
    )

    missing_research = []
    for r in research_rows:
        # Find the line in markdown containing this task ID
        for line in deleg_content.splitlines():
            if r["id"] in line:
                if "RESEARCH" not in line.upper():
                    missing_research.append(r["id"])
                    drift_count += 1
                break

    if missing_research:
        print("  ⚠️  Research notes not reflected in AGENT_DELEGATION.md:")
        for tid in missing_research:
            print(f"    {tid} — has research_notes in DB but no RESEARCH tag in markdown")

    # Check 4: DB totals
    db_total = db.fetch_scalar("SELECT COUNT(*) FROM tasks")
    db_phases = db.fetch_scalar("SELECT COUNT(DISTINCT phase) FROM tasks")
    print(f"  📊 DB totals: {db_total} tasks across {db_phases} phases")

    # Check 5: INBOX items pending triage
    inbox_count = db.fetch_scalar(
        "SELECT COUNT(*) FROM tasks WHERE queue='INBOX'"
    )
    if inbox_count > 0:
        print(f"  📥 {inbox_count} task(s) in INBOX awaiting triage")
        print("     Run: bash db_queries.sh inbox")
        print("")

    # Verdict
    if drift_count == 0:
        print("")
        print("  ✅ Sync check passed — DB and markdown are consistent")
    else:
        print("")
        print(f"  ⚠️  {drift_count} drift(s) detected")
        print("  Fix: run 'bash db_queries.sh delegation-md' to regenerate §8 from DB.")
    print("")
