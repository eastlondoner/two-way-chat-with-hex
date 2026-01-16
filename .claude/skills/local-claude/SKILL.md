---
name: local-claude
description: Start a local Claude Code instance in tmux with interactive login. Use when the user wants to run a nested/second Claude Code instance, spawn a local claude, or needs to authenticate a separate Claude session.
---

# Local Claude Code

A pre-warmed Claude Code TUI session runs in tmux, started automatically by the SessionStart hook.

## Quick Reference

### Send Query and Wait for Response

```bash
# Send query
tmux send-keys -t claude-local 'your query here' && tmux send-keys -t claude-local Enter

# Wait for response to stabilize, then capture (recommended)
.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local
```

The polling script waits until output stabilizes (3 consecutive unchanged polls at 3s intervals) or times out after 60s, then outputs the final capture.

### Session Commands

| Action | Command |
|--------|---------|
| Check status | `tmux capture-pane -t claude-local -p -S -30` |
| Send query | `tmux send-keys -t claude-local 'text' && tmux send-keys -t claude-local Enter` |
| Wait for response | `.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local` |
| Wait (custom timeout) | `.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local 120` |
| Attach | `tmux attach -t claude-local` |
| Restart | `tmux kill-session -t claude-local` (will restart on next session) |

## How It Works

The `.githooks/post-checkout` hook (triggered by SessionStart) handles everything:
1. Restores credentials from GitHub variable
2. Configures Claude state (onboarding, bypass acceptance, trust dialog)
3. Starts `claude-local` tmux session with `--dangerously-skip-permissions`

Only runs in remote environments (`CLAUDE_CODE_REMOTE=true`).

## Polling Script

The bundled `scripts/tmux-poll-wait.sh` intelligently waits for Claude to finish.

**Requirements:** `tmux` must be installed and the target session must exist.

**Exit codes:**
- `0` - Output stabilized (success)
- `1` - Session not found
- `124` - Timeout (like GNU timeout)

**Environment variables (optional):**
| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_POLL_INTERVAL` | 3 | Seconds between polls |
| `TMUX_POLL_STABLE` | 3 | Consecutive unchanged polls required |
| `TMUX_POLL_LINES` | 100 | Lines to capture for comparison |

```bash
# Usage
.claude/skills/local-claude/scripts/tmux-poll-wait.sh <session> [timeout_seconds]

# Examples
.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local      # 60s timeout
.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local 120  # 120s timeout

# Check exit code to distinguish stable vs timeout
.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-local > output.txt
if [ $? -eq 124 ]; then echo "Timed out"; fi
```

## OAuth Re-authentication

Only needed if credentials are revoked:

```bash
tmux new-session -d -s claude-reauth "bash -c 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR; exec claude /login'"
.claude/skills/local-claude/scripts/tmux-poll-wait.sh claude-reauth 30
# After user provides code:
tmux send-keys -t claude-reauth 'CODE_HERE' Enter
gh variable set CLAUDE_CREDENTIALS --repo eastlondoner/claude --body "$(base64 -w0 ~/.claude/.credentials.json)"
```
