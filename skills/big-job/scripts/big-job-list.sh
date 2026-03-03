#!/bin/sh
# big-job-list.sh — List background jobs (most recent first).
#
# Usage: big-job-list.sh [-n COUNT]
#   -n COUNT  Number of jobs to show (default: 10)
#
# Exit codes: 0=ok

LIMIT=10
while [ "$#" -gt 0 ]; do
    case "$1" in
        -n) LIMIT="$2"; shift 2 ;;
        *)  shift ;;
    esac
done

JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"

if [ ! -d "$JOBS_DIR" ]; then
    echo "No jobs directory found."
    exit 0
fi

# Collect lines as "created_at\tformatted_line" so we can sort
LINES=""
found=0
for d in "$JOBS_DIR"/*/; do
    [ -f "$d/meta.json" ] || continue
    found=1

    ID=$(basename "$d")

    if [ -f "$d/exit_code" ]; then
        EC=$(cat "$d/exit_code")
        if [ "$EC" = "0" ]; then
            STATUS="completed"
        else
            STATUS="failed($EC)"
        fi
    else
        # Check if process is actually alive
        ALIVE=0
        UNIT_NAME="big-job-$ID"
        if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
            STATE=$(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || true)
            case "$STATE" in active|activating) ALIVE=1 ;; esac
        fi
        if [ "$ALIVE" = "0" ]; then
            PID=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$d/meta.json" 2>/dev/null)
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                ALIVE=1
            fi
        fi
        if [ "$ALIVE" = "1" ]; then
            STATUS="running"
        else
            STATUS="dead"
        fi
    fi

    # Extract created_at and command from meta.json using sed
    SORT_KEY=$(sed -n 's/.*"created_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$d/meta.json" 2>/dev/null | head -1)
    SORT_KEY="${SORT_KEY:-0}"
    CREATED=$(printf '%.19s' "$SORT_KEY")
    CMD=$(sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$d/meta.json" 2>/dev/null | head -1)
    CMD="${CMD:-?}"
    if [ "${#CMD}" -gt 50 ]; then
        CMD="$(printf '%.47s' "$CMD")..."
    fi

    LINE=$(printf "%-14s %-12s %-22s %s" "$ID" "$STATUS" "$CREATED" "$CMD")
    LINES="${LINES}${SORT_KEY}	${LINE}
"
done

if [ "$found" = "0" ]; then
    echo "(no jobs found)"
    exit 0
fi

# Header
printf "%-14s %-12s %-22s %s\n" "JOB_ID" "STATUS" "CREATED" "COMMAND"
printf "%-14s %-12s %-22s %s\n" "------" "------" "-------" "-------"

# Sort reverse chronologically, strip sort key, limit to N
printf '%s' "$LINES" | sort -t'	' -k1 -r | head -n "$LIMIT" | cut -f2-
