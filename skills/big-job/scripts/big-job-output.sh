#!/bin/sh
# big-job-output.sh — Read output from a background job.
#
# Usage: big-job-output.sh <JOB_ID> [tail|head] [N]
#
# Defaults: tail 50
#
# Exit codes: 0=ok, 1=usage error, 2=not found

if [ -z "$1" ]; then
    echo "Usage: big-job-output.sh <JOB_ID> [tail|head] [N]" >&2
    exit 1
fi

JOB_ID="$1"
MODE="${2:-tail}"
COUNT="${3:-50}"
JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"
JOB_DIR="$JOBS_DIR/$JOB_ID"

if [ ! -d "$JOB_DIR" ]; then
    echo "Job not found: $JOB_ID" >&2
    exit 2
fi

LOG="$JOB_DIR/output.log"

if [ ! -f "$LOG" ]; then
    echo "(no output yet)" >&2
    exit 0
fi

case "$MODE" in
    tail) tail -n "$COUNT" "$LOG" ;;
    head) head -n "$COUNT" "$LOG" ;;
    *)
        echo "Unknown mode: $MODE (use tail or head)" >&2
        exit 1
        ;;
esac
