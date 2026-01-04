---
name: local-claude
description: Start a local Claude Code instance in tmux with interactive login. Use when the user wants to run a nested/second Claude Code instance, spawn a local claude, or needs to authenticate a separate Claude session.
---

# Local Claude Code

A pre-warmed Claude Code TUI session runs in tmux, started automatically by the SessionStart hook.

## Quick Reference

### Send Query to Pre-started Session

```bash
# Send query (double Enter to submit)
tmux send-keys -t claude-local 'your query here' Enter Enter

# Capture response
sleep 15 && tmux capture-pane -t claude-local -p -S -80
```

### Session Commands

| Action | Command |
|--------|---------|
| Check status | `tmux capture-pane -t claude-local -p -S -30` |
| Send query | `tmux send-keys -t claude-local 'text' Enter Enter` |
| Attach | `tmux attach -t claude-local` |
| Restart | `tmux kill-session -t claude-local` (will restart on next session) |

## How It Works

The SessionStart hook in `.claude/settings.json` runs:
```bash
tmux has-session -t claude-local 2>/dev/null || tmux new-session -d -s claude-local "..."
```

This starts Claude with `--dangerously-skip-permissions` so commands run without prompts.

## Prerequisites

- Credentials at `~/.claude/.credentials.json` (restored by post-checkout hook)
- `bypassPermissionsModeAccepted: true` in `~/.claude.json` (set by post-checkout hook)

## OAuth Re-authentication

Only needed if credentials are revoked:

```bash
tmux new-session -d -s claude-reauth "bash -c 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR; exec claude /login'"
sleep 5 && tmux capture-pane -t claude-reauth -p
# After user provides code:
tmux send-keys -t claude-reauth 'CODE_HERE' Enter
gh variable set CLAUDE_CREDENTIALS --repo eastlondoner/claude --body "$(base64 -w0 ~/.claude/.credentials.json)"
```
