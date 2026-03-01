#!/bin/sh
# big-job-start.sh — Start a detached background job with logging and metadata.
#
# Usage: big-job-start.sh [-d WORK_DIR] [-n] COMMAND...
#
#   -d WORK_DIR   Set working directory (default: pwd)
#   -n            No-follow mode: print job ID and exit (don't tail logs)
#
# By default, starts tailing output.log after launch so the caller sees
# output streaming. The job is already detached — killing the tail (or the
# agent timing out) does NOT kill the job.
#
# Exit codes: 0=ok (or job exit code in follow mode), 1=usage error

JOBS_DIR="${BIG_JOB_DIR:-$HOME/.local/share/big-job}"
WORK_DIR=""
FOLLOW=1

# Parse options
while [ "$#" -gt 0 ]; do
    case "$1" in
        -d)
            WORK_DIR="$2"
            shift 2
            ;;
        -n)
            FOLLOW=0
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -eq 0 ]; then
    echo "Usage: big-job-start.sh [-d WORK_DIR] [-n] COMMAND..." >&2
    exit 1
fi

COMMAND_DISPLAY="$*"
WORK_DIR="${WORK_DIR:-$(pwd)}"

# Generate job ID
if [ -f /proc/sys/kernel/random/uuid ]; then
    JOB_ID=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 12)
else
    JOB_ID=$(od -An -tx1 -N6 /dev/urandom | tr -d ' \n')
fi
JOB_DIR="$JOBS_DIR/$JOB_ID"
mkdir -p "$JOB_DIR"

LOG_PATH="$JOB_DIR/output.log"
EC_PATH="$JOB_DIR/exit_code"

# Write command to a file with proper shell quoting to preserve argument boundaries
{
    for arg in "$@"; do
        # Escape single quotes within each argument
        escaped=$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")
        printf "'%s' " "$escaped"
    done
    echo
} > "$JOB_DIR/command.sh"

# Detect stdbuf command (GNU coreutils vs macOS homebrew)
if command -v stdbuf >/dev/null 2>&1; then
    STDBUF="stdbuf -oL -eL"
elif command -v gstdbuf >/dev/null 2>&1; then
    STDBUF="gstdbuf -oL -eL"
else
    STDBUF=""
fi

# Wrap command: line-buffered output, capture exit code atomically
# stdbuf wraps /bin/sh (a real binary), which runs the quoted command from command.sh
WRAPPED="export PYTHONUNBUFFERED=1; cd '$WORK_DIR' && ( $STDBUF /bin/sh '$JOB_DIR/command.sh' ) > '$LOG_PATH' 2>&1
echo \$? > '${EC_PATH}.tmp' && mv '${EC_PATH}.tmp' '$EC_PATH'"

# Detect platform and launch
if command -v systemd-run >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    UNIT_NAME="big-job-$JOB_ID"
    systemd-run --user \
        --unit="$UNIT_NAME" \
        -p OOMScoreAdjust=1000 \
        -p "WorkingDirectory=$WORK_DIR" \
        -- /bin/sh -c "$WRAPPED" >/dev/null 2>&1
else
    nohup /bin/sh -c "$WRAPPED" > /dev/null 2>&1 &
    JOB_PID=$!
    disown $JOB_PID 2>/dev/null || true
fi

# Write metadata as JSON — escape command for safe embedding
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
# Escape backslashes, double quotes, and control chars for JSON string
CMD_JSON=$(printf '%s' "$COMMAND_DISPLAY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g')

{
    printf '{\n'
    printf '  "id": "%s",\n' "$JOB_ID"
    printf '  "command": "%s",\n' "$CMD_JSON"
    printf '  "working_dir": "%s",\n' "$WORK_DIR"
    printf '  "status": "running",\n'
    printf '  "exit_code": null,\n'
    printf '  "log_path": "%s",\n' "$LOG_PATH"
    printf '  "created_at": "%s",\n' "$CREATED_AT"
    printf '  "finished_at": null'
    [ -n "${UNIT_NAME:-}" ] && printf ',\n  "unit": "%s"' "$UNIT_NAME"
    [ -n "${JOB_PID:-}" ] && printf ',\n  "pid": %s' "$JOB_PID"
    printf '\n}\n'
} > "$JOB_DIR/meta.json"

echo "big-job:$JOB_ID started"

if [ "$FOLLOW" = "0" ]; then
    exit 0
fi

# Follow mode: tail the log until the job finishes.
# The job is already detached — killing this tail does NOT kill the job.

# Wait briefly for log file to appear
i=0; while [ ! -f "$LOG_PATH" ] && [ "$i" -lt 5 ]; do sleep 0.2; i=$((i+1)); done

# Tail in background, then poll for exit_code file
tail -f "$LOG_PATH" 2>/dev/null &
TAIL_PID=$!

# Clean up tail on signal (agent timeout / Ctrl-C)
trap 'kill $TAIL_PID 2>/dev/null; exit 0' INT TERM

while [ ! -f "$EC_PATH" ]; do
    sleep 1
done

# Let tail flush remaining output
sleep 0.5
kill $TAIL_PID 2>/dev/null || true
wait $TAIL_PID 2>/dev/null || true
trap - INT TERM

EC=$(cat "$EC_PATH")
if [ "$EC" = "0" ]; then
    echo ""
    echo "big-job:$JOB_ID completed (exit 0)"
else
    echo ""
    echo "big-job:$JOB_ID failed (exit $EC)"
fi
exit "$EC"
