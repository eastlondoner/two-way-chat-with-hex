---
name: local-claude
description: Start a local Claude Code instance in tmux with interactive login. Use when the user wants to run a nested/second Claude Code instance, spawn a local claude, or needs to authenticate a separate Claude session.
---

# Local Claude Code

Run a separate Claude Code instance outside the remote environment.

## Quick Reference

### Interactive Session (with bypass permissions)

```bash
# Start session with bypass mode (no permission prompts)
tmux kill-session -t claude-local 2>/dev/null
tmux new-session -d -s claude-local "bash -c 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR; exec claude --dangerously-skip-permissions'"

# Wait for TUI
sleep 5 && tmux capture-pane -t claude-local -p -S -30

# Send query (double Enter to submit)
tmux send-keys -t claude-local 'your query here' Enter Enter

# Capture response
sleep 15 && tmux capture-pane -t claude-local -p -S -80
```

### Session Commands

| Action | Command |
|--------|---------|
| Capture output | `tmux capture-pane -t claude-local -p -S -50` |
| Send query | `tmux send-keys -t claude-local 'text' Enter Enter` |
| Attach | `tmux attach -t claude-local` |
| Kill | `tmux kill-session -t claude-local` |

## Prerequisites

- Credentials at `~/.claude/.credentials.json` (restored by post-checkout hook)
- `bypassPermissionsModeAccepted: true` in `~/.claude.json` (set by post-checkout hook)
- tmux available

## OAuth Re-authentication

Only needed if credentials are revoked:

```bash
tmux new-session -d -s claude-reauth "bash -c 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR; exec claude /login'"
sleep 5 && tmux capture-pane -t claude-reauth -p  # Get OAuth URL
# After user provides code:
tmux send-keys -t claude-reauth 'CODE_HERE' Enter
# Update GitHub variable:
gh variable set CLAUDE_CREDENTIALS --repo eastlondoner/claude --body "$(base64 -w0 ~/.claude/.credentials.json)"
```
