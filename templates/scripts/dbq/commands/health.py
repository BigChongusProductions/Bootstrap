"""
Health & recovery commands: init-db, health, backup, restore, verify.
"""
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from ..db import Database, DatabaseError
from ..config import ProjectConfig
from .. import output


def cmd_init_db(db: Database):
    """Create all tables. Idempotent — safe to run multiple times.

    Matches db_queries_legacy.template.sh lines 1631-1717.
    """
    from pathlib import Path

    db_path = Path(db.db_path)
    if not db_path.exists():
        db_path.touch()
        print(f"  Created {db_path.name}")

    print(
        output.section_header(
            f"Initializing {db_path.name} schema"
        )
    )

    # This reconnects to the now-existing file
    created = db.init_schema()

    # Print table list matching bash output format
    print(
        "  ✅ Schema ready. Tables: tasks, phase_gates, "
        "milestone_confirmations, loopback_acks,"
    )
    print("     decisions, sessions, db_snapshots, assumptions")
    print("")


def cmd_health(db: Database, config):
    """Pipeline health diagnostic — comprehensive integrity check.

    Returns exit code: 0 for HEALTHY/DEGRADED, 1 for CRITICAL.
    Matches db_queries_legacy.template.sh lines 1719-1842.

    OUTPUT CONTRACT:
        session_briefing.template.sh:53 does `tail -3 | head -2`
        The last 3 lines MUST be: blank, verdict, blank.
        session-start-check.template.sh:62 greps for error|fail|corrupt.
    """
    warnings = 0
    criticals = 0

    print("")
    print(output.section_header("Pipeline Health Check"))

    # 1. SQLite integrity check
    integrity = db.integrity_check()
    if integrity == "ok":
        print("  ✅ SQLite integrity: ok")
    else:
        print("  ❌ SQLite integrity: FAILED")
        print(f"     {integrity}")
        criticals += 1
        # Early exit — all other checks unreliable on corrupt DB
        output.health_verdict(criticals, warnings)
        sys.exit(1)

    # 2. Table existence
    expected_tables = [
        "tasks", "phase_gates", "decisions", "sessions",
        "milestone_confirmations", "db_snapshots", "assumptions",
        "loopback_acks",
    ]
    for tbl in expected_tables:
        if not db.table_exists(tbl):
            print(f"  ❌ Missing table: {tbl}")
            criticals += 1
    if criticals == 0:
        print("  ✅ Required tables: all present")

    # 3. Schema columns on tasks table
    expected_cols = [
        "id", "phase", "queue", "assignee", "title", "priority", "status",
        "blocked_by", "sort_order", "tier", "skill", "track", "origin_phase",
        "severity", "gate_critical",
    ]
    if db.table_exists("tasks"):
        actual_cols = db.get_table_columns("tasks")
        missing_cols = [c for c in expected_cols if c not in actual_cols]
        if not missing_cols:
            print(f"  ✅ Schema columns: all {len(expected_cols)} present")
        else:
            print(f"  ⚠️  Missing columns: {' '.join(missing_cols)}")
            warnings += 1

    # 4. Data integrity checks (only if tasks table exists)
    if db.table_exists("tasks"):
        # 4a. Duplicate task IDs (shouldn't happen with PRIMARY KEY, but check)
        dupes = db.fetch_scalar(
            "SELECT COUNT(*) FROM "
            "(SELECT id FROM tasks GROUP BY id HAVING COUNT(*) > 1)"
        )
        if dupes > 0:
            print(f"  ❌ Duplicate task IDs: {dupes}")
            criticals += 1

        # 4b. Circular dependencies (A blocks B, B blocks A)
        circular = db.fetch_scalar(
            "SELECT COUNT(*) FROM tasks a "
            "JOIN tasks b ON a.blocked_by = b.id AND b.blocked_by = a.id"
        )
        if circular > 0:
            print(f"  ❌ Circular dependencies: {circular}")
            criticals += 1

        # 4c. Broken blocked_by references
        broken_refs = db.fetch_scalar(
            "SELECT COUNT(*) FROM tasks t1 "
            "WHERE t1.blocked_by IS NOT NULL AND t1.blocked_by != '' "
            "AND t1.blocked_by != '—' "
            "AND NOT EXISTS "
            "(SELECT 1 FROM tasks t2 WHERE t2.id = t1.blocked_by)"
        )
        if broken_refs > 0:
            print(f"  ⚠️  Broken blocked_by refs: {broken_refs}")
            warnings += 1

        # 4d. Unknown phases
        if config.phases:
            placeholders = ",".join("?" for _ in config.phases)
            unknown_ph = db.fetch_scalar(
                f"SELECT COUNT(*) FROM tasks WHERE phase NOT IN ({placeholders})",
                tuple(config.phases),
            )
            if unknown_ph > 0:
                print(f"  ⚠️  Unknown phases: {unknown_ph}")
                warnings += 1

        # 4e. Invalid statuses
        valid_statuses = ("TODO", "DONE", "SKIP", "MASTER", "WONTFIX", "IN_PROGRESS")
        placeholders = ",".join("?" for _ in valid_statuses)
        invalid_st = db.fetch_scalar(
            f"SELECT COUNT(*) FROM tasks WHERE status NOT IN ({placeholders})",
            valid_statuses,
        )
        if invalid_st > 0:
            print(f"  ⚠️  Invalid statuses: {invalid_st}")
            warnings += 1

        # 4f. Loopbacks missing origin_phase
        if db.column_exists("tasks", "track"):
            lb_no_orig = db.fetch_scalar(
                "SELECT COUNT(*) FROM tasks "
                "WHERE track='loopback' AND "
                "(origin_phase IS NULL OR origin_phase = '')"
            )
            if lb_no_orig > 0:
                print(f"  ⚠️  Loopbacks missing origin_phase: {lb_no_orig}")
                warnings += 1

        # 4g. Orphaned phase gates
        if db.table_exists("phase_gates"):
            orphan_gates = db.fetch_scalar(
                "SELECT COUNT(*) FROM phase_gates pg "
                "WHERE NOT EXISTS "
                "(SELECT 1 FROM tasks t WHERE t.phase = pg.phase)"
            )
            if orphan_gates > 0:
                print(f"  ⚠️  Orphaned phase gates: {orphan_gates}")
                warnings += 1

    # Verdict — OUTPUT CONTRACT: last 3 lines must be \n verdict \n
    output.health_verdict(criticals, warnings)

    if criticals > 0:
        sys.exit(1)


# ── backup command ──────────────────────────────────────────────────

def cmd_backup(db: Database, config: ProjectConfig):
    """Backup DB to backups/ directory with rotation (keep last 10).

    Matches db_queries_legacy.template.sh lines 1844-1892.
    Uses SQLite's native backup via .backup command for WAL safety.
    """
    backup_dir = config.project_dir / "backups"
    backup_dir.mkdir(exist_ok=True)

    # Check integrity before backup
    integrity = db.integrity_check()
    if integrity != "ok":
        print("❌ DB integrity check failed — refusing to backup corrupt data")
        print("   Run: bash db_queries.sh health")
        sys.exit(1)

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    db_name = Path(db.db_path).stem
    backup_file = backup_dir / f"{db_name}-{timestamp}.db"

    # Flush WAL to main file before copying (ensures consistent backup)
    db.execute("PRAGMA wal_checkpoint(TRUNCATE)")

    # Use SQLite backup API via a separate connection for safe copy
    import sqlite3 as _sqlite3
    src_conn = _sqlite3.connect(db.db_path)
    dst_conn = _sqlite3.connect(str(backup_file))
    src_conn.backup(dst_conn)
    dst_conn.close()
    src_conn.close()

    if not backup_file.exists():
        print("❌ Backup failed")
        sys.exit(1)

    # Verify backup integrity
    try:
        conn = sqlite3.connect(str(backup_file))
        result = conn.execute("PRAGMA integrity_check").fetchone()[0]
        conn.close()
    except sqlite3.Error:
        result = "failed"

    if result != "ok":
        print("❌ Backup file failed integrity check — removing")
        backup_file.unlink()
        sys.exit(1)

    # Count tasks in backup
    try:
        conn = sqlite3.connect(str(backup_file))
        task_count = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        conn.close()
    except sqlite3.Error:
        task_count = "?"

    backup_size = backup_file.stat().st_size
    size_str = _format_size(backup_size)

    # Rotation: keep last 10
    pattern = f"{db_name}-*.db"
    existing = sorted(backup_dir.glob(pattern), key=lambda p: p.stat().st_mtime)
    if len(existing) > 10:
        for old in existing[:-10]:
            old.unlink()
    backup_count = min(len(existing), 10)

    print(f"✅ Backup created: {backup_file.name}")
    print(f"   Size: {size_str} | Tasks: {task_count} | Backups: {backup_count}/10")


# ── restore command ─────────────────────────────────────────────────

def cmd_restore(db: Database, config: ProjectConfig, restore_file: Optional[str] = None):
    """Restore DB from backup. Lists backups if no file given.

    Matches db_queries_legacy.template.sh lines 1894-1961.
    """
    backup_dir = config.project_dir / "backups"
    db_name = Path(db.db_path).stem

    if not restore_file:
        # List available backups
        output.print_section("Available Backups")

        pattern = f"{db_name}-*.db"
        backups = sorted(backup_dir.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True) if backup_dir.exists() else []

        if not backups:
            print(f"  No backups found in {backup_dir}/")
            db_basename = Path(db.db_path).name
            print(f"  Recovery option: git checkout -- {db_basename}")
            return

        print("")
        for bf in backups:
            size_str = _format_size(bf.stat().st_size)
            try:
                conn = sqlite3.connect(str(bf))
                tc = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
                conn.close()
            except sqlite3.Error:
                tc = "?"
            print(f"  {bf.name}  ({size_str}, {tc} tasks)")
        print("")
        print("Usage: bash db_queries.sh restore <filename>")
        print("  (filename only — resolved relative to backups/)")
        return

    # Resolve backup file path
    rf = Path(restore_file)
    if not rf.exists():
        rf = backup_dir / restore_file
    if not rf.exists():
        print(f"❌ Backup file not found: {restore_file}")
        print(f"   Tried: {restore_file} and {backup_dir / restore_file}")
        print("   Run: bash db_queries.sh restore  (to list available backups)")
        sys.exit(1)

    # Validate backup integrity
    try:
        conn = sqlite3.connect(str(rf))
        result = conn.execute("PRAGMA integrity_check").fetchone()[0]
        restore_tasks = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        conn.close()
    except sqlite3.Error as e:
        print(f"❌ Backup file failed integrity check — refusing to restore corrupt data")
        sys.exit(1)

    if result != "ok":
        print("❌ Backup file failed integrity check — refusing to restore corrupt data")
        sys.exit(1)

    # Safety backup of current DB before overwriting
    backup_dir.mkdir(exist_ok=True)
    safety_ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    safety_file = backup_dir / f"pre-restore-{safety_ts}.db"
    shutil.copy2(db.db_path, str(safety_file))
    print(f"  Safety backup: {safety_file.name}")

    # Close current connection, restore, then verify
    db.close()
    shutil.copy2(str(rf), db.db_path)

    # Verify post-restore
    try:
        conn = sqlite3.connect(db.db_path)
        post_tasks = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        conn.close()
    except sqlite3.Error:
        post_tasks = "?"

    if str(post_tasks) == str(restore_tasks):
        print(f"✅ Restored from: {rf.name}")
        print(f"   Tasks: {post_tasks} (matches backup)")
    else:
        print(f"⚠️  Restored but task count mismatch: expected {restore_tasks}, got {post_tasks}")


# ── verify command ──────────────────────────────────────────────────

def cmd_verify(db: Database):
    """Verify DB is populated — machine-readable check for handoff documents.

    Matches db_queries_legacy.template.sh lines 1585-1629.
    """
    # Query task count — must return a real number
    task_count = db.fetch_scalar("SELECT COUNT(*) FROM tasks")

    claude_count = db.fetch_scalar(
        "SELECT COUNT(*) FROM tasks WHERE assignee='CLAUDE'"
    )
    master_count = db.fetch_scalar(
        "SELECT COUNT(*) FROM tasks WHERE assignee='MASTER'"
    )
    phase_count = db.fetch_scalar(
        "SELECT COUNT(DISTINCT phase) FROM tasks"
    )

    # Check delegation columns
    tier_col = db.column_exists("tasks", "tier")
    skill_col = db.column_exists("tasks", "skill")
    rnotes_col = db.column_exists("tasks", "research_notes")

    output.print_section("DB Verification")
    print(f"  Tasks total:  {task_count}")
    print(f"  Claude tasks: {claude_count}")
    print(f"  Master tasks: {master_count}")
    print(f"  Phases:       {phase_count}")
    print("")
    print("  Schema:")
    print(f"    {'✅' if tier_col else '❌'} tier column{'' if tier_col else ' MISSING'}")
    print(f"    {'✅' if skill_col else '❌'} skill column{'' if skill_col else ' MISSING'}")
    print(f"    {'✅' if rnotes_col else '❌'} research_notes column{'' if rnotes_col else ' MISSING'}")
    print("")

    if task_count == 0:
        print("  ❌ DB IS EMPTY — run: sqlite3 project.db < seed_tasks.sql")
    elif not (tier_col and skill_col and rnotes_col):
        print("  ⚠️  DB populated but schema incomplete — run migration 001")
    else:
        print("  ✅ DB populated and schema complete")
    print("")


# ── board command ───────────────────────────────────────────────────

def cmd_board(config: ProjectConfig):
    """Delegate to generate_board.py script.

    Matches db_queries_legacy.template.sh lines 1210-1212.
    """
    import subprocess

    board_script = config.project_dir / "generate_board.py"
    if not board_script.exists():
        print(f"❌ generate_board.py not found in {config.project_dir}")
        sys.exit(1)

    result = subprocess.run(
        ["python3", str(board_script)],
        capture_output=True, text=True, timeout=30,
    )
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def _format_size(size_bytes: int) -> str:
    """Human-readable file size."""
    for unit in ("B", "K", "M", "G"):
        if size_bytes < 1024:
            return f"{size_bytes}{unit}"
        size_bytes //= 1024
    return f"{size_bytes}T"
