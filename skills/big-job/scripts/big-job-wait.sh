#!/bin/sh
# big-job-wait.sh — Wait for a background job to finish.
#
# Usage: big-job-wait.sh <JOB_ID> [TIMEOUT]
#
# TIMEOUT defaults to 300 seconds. Polls every 2s.
#
# Exit codes: 0=completed, 1=usage error, 2=not found, 3=timed out (still running), 4=failed

if [ -z "$1" ]; then
    echo "Usage: big-job-wait.sh <JOB_ID> [TIMEOUT]" >&2
    exit 1
fi

JOB_ID="$1"
TIMEOUT="${2:-300}"
JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"
JOB_DIR="$JOBS_DIR/$JOB_ID"

if [ ! -d "$JOB_DIR" ] || [ ! -f "$JOB_DIR/meta.json" ]; then
    echo "Job not found: $JOB_ID" >&2
    exit 2
fi

ELAPSED=0
while [ ! -f "$JOB_DIR/exit_code" ] && [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ -f "$JOB_DIR/exit_code" ]; then
    EC=$(cat "$JOB_DIR/exit_code")
    if [ "$EC" = "0" ]; then
        echo "completed (exit 0)"
        exit 0
    else
        echo "failed (exit $EC)"
        exit 4
    fi
else
    echo "timed out after ${TIMEOUT}s — job still running"
    exit 3
fi
