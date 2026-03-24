"""
Output formatting — defines the output contracts that callers depend on.

CRITICAL: Several callers parse our output with grep/tail/head.
The exact line format of certain outputs is a WIRE PROTOCOL.
Changes here can break session_briefing.sh, test_bootstrap_suite.sh, etc.

Output contracts documented inline with the caller that depends on them.
"""
import sys
from typing import List, Optional


def section_header(title: str) -> str:
    """Format: ── Title ─────────────────────────────────────────────"""
    padding = max(0, 60 - len(title) - 4)
    return f"── {title} " + "─" * padding


def print_section(title: str):
    """Print a section header with surrounding blank lines."""
    print("")
    print(section_header(title))


def severity_icon(sev: Optional[int]) -> str:
    """Emoji for severity level."""
    return {1: "🔴", 2: "🟡", 3: "🟢", 4: "⚪"}.get(sev, "?")


# ── Output contracts ──────────────────────────────────────────────────
#
# These functions produce output that is PARSED by external scripts.
# Changing the format will break callers. Each contract documents
# which caller depends on it and how.
#

def health_verdict(criticals: int, warnings: int):
    """Print health verdict in the EXACT format callers expect.

    CONTRACT — session_briefing.template.sh:53 does:
        echo "$HEALTH_OUT" | tail -3 | head -2
    This extracts the last 3 lines, takes the first 2 of those.
    So the last 3 lines of health output MUST be:
        \\n  {emoji} {VERDICT} — {details}\\n\\n

    CONTRACT — session-start-check.template.sh:62 does:
        grep -qi "error|fail|corrupt"
    So healthy output must NOT contain those words.
    Critical/degraded output SHOULD contain them for detection.
    """
    print("")
    if criticals > 0:
        print(
            f"  🔴 CRITICAL — {criticals} critical, {warnings} warning(s). "
            f"Pipeline cannot proceed."
        )
        print(
            f"  Recovery: bash db_queries.sh restore "
            f"(or: git checkout -- project.db)"
        )
    elif warnings > 0:
        print(
            f"  🟡 DEGRADED — 0 critical, {warnings} warning(s). "
            f"Non-blocking, should address."
        )
    else:
        print("  🟢 HEALTHY — 0 critical, 0 warnings.")
    print("")


def task_done_message(task_id: str, date: str):
    """Print done confirmation.

    CONTRACT — test_bootstrap_suite.sh:1541 does:
        grep -q "Committed|DONE"
    So the output MUST contain the word "DONE".
    """
    print(f"✅ Marked DONE: {task_id} ({date})")


def commit_success_message(msg: str):
    """Print commit success.

    CONTRACT — test_bootstrap_suite.sh:1541 does:
        grep -q "Committed|DONE"
    So the output MUST contain the word "Committed".
    """
    print(f"  ✅ Committed: {msg}")


def quick_task_message(task_id: str, title: str):
    """Print quick task creation.

    CONTRACT — test_bootstrap_suite.sh:1527 does:
        grep -oE 'QK-[0-9a-f]+'
    So the output MUST contain the task ID in that regex format.
    """
    print(f"📥 {task_id}: {title}")


def quick_loopback_message(
    task_id: str, title: str, origin: str, severity: int, gate_critical: bool
):
    """Print loopback task creation.

    CONTRACT — test_bootstrap_suite.sh extracts ID via:
        grep -oE 'LB-[0-9a-f]+'
    """
    icon = severity_icon(severity)
    gc_text = "YES" if gate_critical else "no"
    print(f"{icon} LB {task_id}: {title}")
    print(
        f"   Origin: {origin} | Severity: S{severity} | "
        f"Gate-critical: {gc_text}"
    )


def error(msg: str):
    """Print error to stderr."""
    print(f"❌ {msg}", file=sys.stderr)


def warn(msg: str):
    """Print warning."""
    print(f"  ⚠️  {msg}")
