#!/bin/sh
# big-job-kill.sh — Send a signal to a running background job.
#
# Usage: big-job-kill.sh <JOB_ID> [SIGNAL]
#
# SIGNAL defaults to TERM. Use KILL for force-kill.
#
# Exit codes: 0=ok, 1=usage error, 2=not found, 4=already finished

if [ -z "$1" ]; then
    echo "Usage: big-job-kill.sh <JOB_ID> [SIGNAL]" >&2
    exit 1
fi

JOB_ID="$1"
SIGNAL="${2:-TERM}"
JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"
JOB_DIR="$JOBS_DIR/$JOB_ID"

if [ ! -d "$JOB_DIR" ] || [ ! -f "$JOB_DIR/meta.json" ]; then
    echo "Job not found: $JOB_ID" >&2
    exit 2
fi

# Already finished?
if [ -f "$JOB_DIR/exit_code" ]; then
    echo "Job already finished (exit $(cat "$JOB_DIR/exit_code"))" >&2
    exit 4
fi

# Try systemd first
UNIT_NAME="big-job-$JOB_ID"
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    STATE=$(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || true)
    if [ "$STATE" = "active" ]; then
        systemctl --user kill --signal="$SIGNAL" "$UNIT_NAME"
        echo "Sent $SIGNAL to systemd unit $UNIT_NAME"
        exit 0
    fi
fi

# PID fallback
PID=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$JOB_DIR/meta.json" 2>/dev/null)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    kill -"$SIGNAL" "$PID"
    echo "Sent $SIGNAL to PID $PID"
    exit 0
fi

echo "Process not found (may have already exited)" >&2
exit 4
