#!/bin/sh
# big-job-cleanup.sh — Remove finished jobs older than N days.
#
# Usage: big-job-cleanup.sh [DAYS]
#
# DAYS defaults to 7. Only removes jobs that have an exit_code file (finished).
# Running jobs are never removed.
#
# Exit codes: 0=ok

DAYS="${1:-7}"
JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"

if [ ! -d "$JOBS_DIR" ]; then
    echo "No jobs directory found."
    exit 0
fi

removed=0
for d in "$JOBS_DIR"/*/; do
    [ -d "$d" ] || continue
    [ -f "$d/exit_code" ] || continue
    # Check if directory is older than DAYS
    if find "$d" -maxdepth 0 -mtime +"$DAYS" 2>/dev/null | grep -q .; then
        ID=$(basename "$d")
        rm -rf "$d"
        echo "Removed $ID"
        removed=$((removed + 1))
    fi
done

echo "Cleanup complete: $removed job(s) removed (older than $DAYS days)."
