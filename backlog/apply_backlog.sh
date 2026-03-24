#!/usr/bin/env bash
# =============================================================================
# Bootstrap Backlog — Review & Apply Lifecycle
#
# Usage:
#   bash apply_backlog.sh              # List all pending items grouped by priority
#   bash apply_backlog.sh BP-003       # Show item details, prompt for apply
#   bash apply_backlog.sh --stats      # Summary counts by category and status
#   bash apply_backlog.sh --next-id    # Print next available BP-ID (for scripting)
# =============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BACKLOG="$SCRIPT_DIR/BOOTSTRAP_BACKLOG.md"
TEST_SUITE="$REPO_ROOT/tests/test_bootstrap_suite.sh"
TEMPLATES="$REPO_ROOT/templates"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

if [ ! -f "$BACKLOG" ]; then
    echo -e "${RED}❌ Backlog not found:${RESET} $BACKLOG"
    exit 1
fi

# === HELPERS ==================================================================

next_bp_id() {
    # Find highest BP-NNN in file, return next
    local MAX
    MAX=$(grep -oE 'BP-[0-9]+' "$BACKLOG" | sed 's/BP-//' | sort -n | tail -1)
    if [ -z "$MAX" ]; then
        echo "BP-001"
    else
        printf "BP-%03d" $((MAX + 1))
    fi
}

count_by() {
    # count_by "pattern" — count matching ### headers in backlog
    local SECTION="$1"
    local IN_SECTION=0
    local COUNT=0
    while IFS= read -r line; do
        if [[ "$line" == "## Pending" ]]; then
            [[ "$SECTION" == "pending" ]] && IN_SECTION=1 || IN_SECTION=0
        elif [[ "$line" == "## Applied" ]]; then
            [[ "$SECTION" == "applied" ]] && IN_SECTION=1 || IN_SECTION=0
        elif [[ "$IN_SECTION" -eq 1 ]] && [[ "$line" =~ ^###\ BP- ]]; then
            COUNT=$((COUNT + 1))
        fi
    done < "$BACKLOG"
    echo "$COUNT"
}

extract_items() {
    # Extract items from a section, output: "BP-ID [cat] Title | Priority"
    local TARGET_SECTION="$1"
    local IN_SECTION=0
    local CURRENT_ID="" CURRENT_TITLE="" CURRENT_PRIORITY=""
    while IFS= read -r line; do
        if [[ "$line" == "## Pending" ]]; then
            [[ "$TARGET_SECTION" == "pending" ]] && IN_SECTION=1 || { IN_SECTION=0; }
        elif [[ "$line" == "## Applied" ]]; then
            [[ "$TARGET_SECTION" == "applied" ]] && IN_SECTION=1 || { IN_SECTION=0; }
        elif [[ "$IN_SECTION" -eq 1 ]] && [[ "$line" =~ ^###\ (BP-[0-9]+)\ (.+) ]]; then
            # Flush previous
            if [ -n "$CURRENT_ID" ]; then
                echo "$CURRENT_PRIORITY|$CURRENT_ID $CURRENT_TITLE"
            fi
            CURRENT_ID="${BASH_REMATCH[1]}"
            CURRENT_TITLE="${BASH_REMATCH[2]}"
            CURRENT_PRIORITY="P2" # default
        elif [[ "$IN_SECTION" -eq 1 ]] && [[ "$line" =~ ^\-\ \*\*Priority:\*\*\ (P[0-3]) ]]; then
            CURRENT_PRIORITY="${BASH_REMATCH[1]}"
        fi
    done < "$BACKLOG"
    # Flush last
    if [ -n "$CURRENT_ID" ]; then
        echo "$CURRENT_PRIORITY|$CURRENT_ID $CURRENT_TITLE"
    fi
}

show_item() {
    # Print full details of a specific BP-ID
    local TARGET="$1"
    local FOUND=0
    local PRINTING=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ ${TARGET}\ (.+) ]]; then
            FOUND=1
            PRINTING=1
            echo -e "\n${BOLD}$line${RESET}"
        elif [[ "$PRINTING" -eq 1 ]] && [[ "$line" =~ ^###\  ]]; then
            # Next item — stop
            break
        elif [[ "$PRINTING" -eq 1 ]] && [[ "$line" =~ ^##\  ]]; then
            # Next section — stop
            break
        elif [[ "$PRINTING" -eq 1 ]]; then
            echo "$line"
        fi
    done < "$BACKLOG"
    if [ "$FOUND" -eq 0 ]; then
        echo -e "${RED}❌ $TARGET not found in backlog${RESET}"
        return 1
    fi
}

mark_applied() {
    # Update a BP item's status to applied and add Applied date
    local TARGET="$1"
    local TODAY
    TODAY=$(date "+%Y-%m-%d")

    # Add Applied date if not present, update Status
    local TEMP="/tmp/backlog_apply_$$.md"
    local IN_ITEM=0
    local DONE_STATUS=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ ${TARGET}\  ]]; then
            IN_ITEM=1
            echo "$line" >> "$TEMP"
        elif [[ "$IN_ITEM" -eq 1 ]] && [[ "$line" =~ ^###\  ]]; then
            IN_ITEM=0
            DONE_STATUS=0
            echo "$line" >> "$TEMP"
        elif [[ "$IN_ITEM" -eq 1 ]] && [[ "$line" =~ ^\-\ \*\*Status:\*\* ]]; then
            echo "- **Status:** applied" >> "$TEMP"
            echo "- **Applied:** $TODAY" >> "$TEMP"
            DONE_STATUS=1
        elif [[ "$IN_ITEM" -eq 1 ]] && [[ "$line" =~ ^\-\ \*\*Applied:\*\* ]]; then
            # Skip existing Applied line — we already wrote one
            continue
        else
            echo "$line" >> "$TEMP"
        fi
    done < "$BACKLOG"
    mv "$TEMP" "$BACKLOG"
}

# === MAIN =====================================================================

case "${1:-list}" in
    --next-id)
        next_bp_id
        ;;

    --stats)
        PENDING=$(count_by "pending")
        APPLIED=$(count_by "applied")
        echo -e "${BOLD}Bootstrap Backlog Stats${RESET}"
        echo -e "  Pending: ${YELLOW}$PENDING${RESET}"
        echo -e "  Applied: ${GREEN}$APPLIED${RESET}"
        echo -e "  Total:   $((PENDING + APPLIED))"

        if [ "$PENDING" -gt 0 ]; then
            echo ""
            echo -e "${DIM}By priority (pending only):${RESET}"
            for P in P0 P1 P2 P3; do
                CT=$(extract_items "pending" | grep "^${P}|" | wc -l | tr -d ' ')
                [ "$CT" -gt 0 ] && echo "  $P: $CT"
            done
            echo ""
            echo -e "${DIM}By category (pending only):${RESET}"
            PENDING_ITEMS=$(extract_items "pending")
            for CAT in template framework process system; do
                CT=$(echo "$PENDING_ITEMS" | grep -c "\[${CAT}\]" 2>/dev/null || true)
                CT="${CT:-0}"
                [ "$CT" -gt 0 ] && echo "  [$CAT]: $CT"
            done
        fi
        ;;

    BP-*)
        TARGET="$1"
        show_item "$TARGET" || exit 1

        # Show affected template
        AFFECTED=$(grep '^\- \*\*Affected:\*\*' "$BACKLOG" | grep -A0 "$TARGET" 2>/dev/null || true)
        if [ -z "$AFFECTED" ]; then
            # Parse it properly from the item
            AFFECTED=$(awk "/^### ${TARGET} /{found=1} found && /^\- \*\*Affected:\*\*/{print; exit}" "$BACKLOG" | sed 's/- \*\*Affected:\*\* //')
        fi

        if [ -n "$AFFECTED" ] && [ -f "$TEMPLATES/$AFFECTED" ]; then
            echo -e "\n${BLUE}Template file exists:${RESET} $TEMPLATES/$AFFECTED"
        elif [ -n "$AFFECTED" ]; then
            echo -e "\n${YELLOW}Template path:${RESET} $AFFECTED"
        fi

        echo ""
        echo -e "${BOLD}Actions:${RESET}"
        echo "  1. Edit the affected template file(s)"
        echo "  2. Run: bash $0 $TARGET --mark-applied"
        echo "     (runs test suite, then marks as applied)"
        ;;

    *--mark-applied)
        # Usage: apply_backlog.sh BP-003 --mark-applied [--skip-tests]
        TARGET="${1}"
        if [[ ! "$TARGET" =~ ^BP-[0-9]+ ]]; then
            echo "Usage: bash apply_backlog.sh BP-NNN --mark-applied [--skip-tests]"
            exit 1
        fi

        SKIP_TESTS=0
        [[ "${3:-}" == "--skip-tests" ]] && SKIP_TESTS=1

        if [ "$SKIP_TESTS" -eq 0 ] && [ -f "$TEST_SUITE" ]; then
            echo -e "${BOLD}Running test suite...${RESET}"
            if bash "$TEST_SUITE" --verify 1 2>&1 | tail -5; then
                echo -e "${GREEN}✅ Tests passed${RESET}"
            else
                echo -e "${RED}❌ Tests failed — not marking as applied${RESET}"
                echo "  Fix the issue and try again, or use --skip-tests to override."
                exit 1
            fi
        fi

        mark_applied "$TARGET"
        echo -e "${GREEN}✅ $TARGET marked as applied${RESET}"
        ;;

    list|"")
        PENDING=$(count_by "pending")
        APPLIED=$(count_by "applied")

        echo -e "${BOLD}━━━ Bootstrap Backlog ━━━${RESET}"
        echo ""

        if [ "$PENDING" -eq 0 ]; then
            echo -e "  ${GREEN}No pending items. Bootstrap is current.${RESET}"
            echo -e "  ${DIM}($APPLIED applied items in history)${RESET}"
            exit 0
        fi

        for P in P0 P1 P2 P3; do
            ITEMS=$(extract_items "pending" | grep "^${P}|" | sed "s/^${P}|//")
            if [ -n "$ITEMS" ]; then
                CT=$(echo "$ITEMS" | wc -l | tr -d ' ')
                case "$P" in
                    P0) echo -e "${RED}${BOLD}$P ($CT items) — CRITICAL:${RESET}" ;;
                    P1) echo -e "${YELLOW}${BOLD}$P ($CT items) — DEGRADED:${RESET}" ;;
                    P2) echo -e "${BLUE}$P ($CT items) — IMPROVEMENT:${RESET}" ;;
                    P3) echo -e "${DIM}$P ($CT items) — NICE-TO-HAVE:${RESET}" ;;
                esac
                echo "$ITEMS" | while read -r item; do
                    echo "  $item"
                done
                echo ""
            fi
        done

        echo -e "${DIM}Total: $PENDING pending, $APPLIED applied${RESET}"
        echo -e "${DIM}Run: bash apply_backlog.sh BP-NNN  to review a specific item${RESET}"
        ;;

    *)
        echo "Usage: bash apply_backlog.sh [BP-NNN | --stats | --next-id]"
        echo ""
        echo "Commands:"
        echo "  (no args)        List all pending items by priority"
        echo "  BP-NNN           Show full details of a specific item"
        echo "  BP-NNN --mark-applied  Run tests + mark item as applied"
        echo "  --stats          Show summary counts"
        echo "  --next-id        Print next available BP-ID"
        exit 1
        ;;
esac
