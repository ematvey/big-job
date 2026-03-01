# big-job

Agent skill for running long-running shell commands as detached background jobs that survive agent restarts.

Start builds, test suites, training runs, or any heavy command, in foreground or background. If the agent dies or times out, the job keeps going.

## Features

- Jobs survive agent restarts, timeouts, and network disconnections
- OOM protection on Linux (systemd backend)
- Structured logging with combined stdout+stderr capture
- Cross-platform: Linux (systemd), macOS, WSL2
- Full lifecycle management: start, status, output, kill, wait, list, cleanup

## Installation

```bash
npx skills install ematvey/big-job
```

## How It Works

Each job gets a directory under `~/.local/share/big-job/<JOB_ID>/` containing:

| File | Purpose |
|------|---------|
| `meta.json` | Job metadata (ID, command, timestamps, PID/unit) |
| `command.sh` | The raw command text |
| `output.log` | Combined stdout+stderr (line-buffered) |
| `exit_code` | Written atomically when the job finishes |

On Linux with systemd, jobs launch via `systemd-run --user` for proper process isolation and OOM protection. On macOS and WSL2, jobs use `nohup` + `disown` as a fallback.

## Commands

All commands go through the dispatcher script:

```
big-job <command> [args...]
```

| Command | Usage | Description |
|---------|-------|-------------|
| `start` | `[-d DIR] [-n] CMD...` | Launch a job. Tails output by default; `-n` for fire-and-forget |
| `status` | `<ID>` | Check if a job is running, completed, or failed |
| `output` | `<ID> [tail\|head] [N]` | Read the log (default: tail 50 lines) |
| `kill` | `<ID> [SIGNAL]` | Send a signal (default: TERM) |
| `list` | | List all jobs with status and creation time |
| `wait` | `<ID> [TIMEOUT]` | Block until done (default: 300s timeout) |
| `cleanup` | `[DAYS]` | Remove finished jobs older than N days (default: 7) |

## Usage Examples

```bash
BJ="path/to/skills/big-job/scripts/big-job"

# Run a build and follow output:
"$BJ" start -d /home/user/project make -j8

# Fire-and-forget a test suite:
"$BJ" start -n -d /home/user/project pytest tests/

# Check on a job:
"$BJ" status abc123

# View the last 100 lines of output:
"$BJ" output abc123 tail 100

# List all jobs:
"$BJ" list

# Wait up to 10 minutes:
"$BJ" wait abc123 600

# Force kill:
"$BJ" kill abc123 KILL
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error |
| 2 | Job not found |
| 3 | Still running |
| 4 | Job failed (non-zero exit) |

## Platform Support

| Platform | Backend | OOM Protection |
|----------|---------|----------------|
| Linux (systemd) | `systemd-run --user` | Yes |
| macOS | `nohup` + `disown` | No |
| WSL2 | `nohup` + `disown` | No |

## License

MIT
