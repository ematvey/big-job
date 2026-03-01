---
name: big-job
description: Run long-running shell commands (builds, tests, data pipelines, scraping, training runs, etc.) as detached background jobs that survive agent restarts, with OOM protection, structured logging, and lifecycle management. Use this skill whenever the user asks you to run something that will take more than a few seconds — large test suites, long builds, batch processing, data migrations, ML training, or any command the user explicitly wants running "in the background". Also use it when you need to run multiple heavy commands in parallel without blocking. Trigger on phrases like "run in background", "long running", "don't wait for it", "kick off a build", "run tests and come back", "start a training run", "batch process", or any task where blocking the conversation would be annoying.
---

# Big Jobs

Run heavy or long-running shell commands as detached background processes that survive agent restarts. Each job gets OOM protection (on systemd), captured stdout/stderr, an exit code, and metadata.

## Usage

All commands go through the `big-job` dispatcher in `scripts/`. Set the path once:

```bash
BJ="<path-to-skill>/scripts/big-job"
```

| Command | Usage | Purpose |
|---------|-------|---------|
| `start` | `[-d DIR] [-n] CMD...` | Launch job, tail output until done. `-n` to detach silently. |
| `status` | `<ID>` | Check running/completed/failed. |
| `output` | `<ID> [tail\|head] [N]` | Read output.log (default: tail 50). |
| `kill` | `<ID> [SIGNAL]` | Send signal (default: TERM). |
| `list` | | List all jobs with status. |
| `wait` | `<ID> [TIMEOUT]` | Block until done (default: 300s). |
| `cleanup` | `[DAYS]` | Remove finished jobs older than N days (default: 7). |

## Typical workflow

```bash
# Start and see output streaming (job survives if agent dies):
"$BJ" start -d /home/user/project make -j8

# Start without following (fire-and-forget):
"$BJ" start -n -d /home/user/project make -j8

# Check on a job later:
"$BJ" status <ID>
"$BJ" output <ID>

# List all jobs:
"$BJ" list
```

The `start` command prints `big-job:<ID>` immediately, then tails the log until the job finishes. The job is already detached — if the Bash call times out or is killed, the job keeps running. Use `-n` for fire-and-forget.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success / completed |
| 1 | Usage error |
| 2 | Job not found |
| 3 | Still running |
| 4 | Failed |

## Jobs directory

`~/.local/share/big-job/<ID>/` (override with `$BIG_JOB_DIR`):
- `meta.json` — id, command, timestamps, pid/unit
- `command.sh` — raw command text
- `output.log` — combined stdout+stderr (line-buffered)
- `exit_code` — written atomically on completion

## Dependencies

None beyond standard POSIX utilities (`sh`, `sed`, `od`, `find`, `tail`, `head`). Optional: `systemd-run` for OOM protection on Linux.

## Guidelines

- **Always tell the user** the job ID and what's running
- **Default to background** for anything > 30 seconds
- **Check exit codes** — don't assume success; read output on failure
- **Use tail for output** — logs can be huge; don't cat the entire file
- **Working directory** — always pass an absolute path with `-d`
- **Reconnection** — run `"$BJ" list` to find active jobs after restart
