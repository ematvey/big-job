#!/bin/sh
# big-job-status.sh — Check the status of a background job.
#
# Usage: big-job-status.sh <JOB_ID>
#
# Exit codes: 0=completed, 3=running, 4=failed, 1=usage error, 2=not found

set -e

if [ -z "$1" ]; then
    echo "Usage: big-job-status.sh <JOB_ID>" >&2
    exit 1
fi

JOB_ID="$1"
JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"
JOB_DIR="$JOBS_DIR/$JOB_ID"

if [ ! -d "$JOB_DIR" ] || [ ! -f "$JOB_DIR/meta.json" ]; then
    echo "Job not found: $JOB_ID" >&2
    exit 2
fi

# Primary check: exit_code file
if [ -f "$JOB_DIR/exit_code" ]; then
    EC=$(cat "$JOB_DIR/exit_code")
    if [ "$EC" = "0" ]; then
        echo "completed"
        exit 0
    else
        echo "failed (exit $EC)"
        exit 4
    fi
fi

# Job may still be running — platform-aware checks

# systemd: check unit state
UNIT_NAME="big-job-$JOB_ID"
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    STATE=$(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || true)
    case "$STATE" in
        active|activating)
            echo "running"
            exit 3
            ;;
        inactive|failed|deactivating)
            # Unit finished — wait briefly for exit_code file flush
            sleep 0.5
            if [ -f "$JOB_DIR/exit_code" ]; then
                EC=$(cat "$JOB_DIR/exit_code")
                if [ "$EC" = "0" ]; then
                    echo "completed"
                    exit 0
                else
                    echo "failed (exit $EC)"
                    exit 4
                fi
            fi
            # No exit_code — abnormal termination, query systemd
            RESULT=$(systemctl --user show "$UNIT_NAME" -p Result 2>/dev/null | cut -d= -f2)
            case "$RESULT" in
                oom-kill)
                    echo "failed (OOM killed)"
                    exit 4
                    ;;
                signal)
                    echo "failed (killed by signal)"
                    exit 4
                    ;;
                *)
                    echo "failed (no exit code)"
                    exit 4
                    ;;
            esac
            ;;
    esac
fi

# PID fallback: check if process is alive
PID=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$JOB_DIR/meta.json" 2>/dev/null)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "running"
    exit 3
fi

# Process gone, brief wait for exit_code flush
sleep 0.5
if [ -f "$JOB_DIR/exit_code" ]; then
    EC=$(cat "$JOB_DIR/exit_code")
    if [ "$EC" = "0" ]; then
        echo "completed"
        exit 0
    else
        echo "failed (exit $EC)"
        exit 4
    fi
fi

echo "failed (process gone, no exit code)"
exit 4
