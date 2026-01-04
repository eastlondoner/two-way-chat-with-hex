---
name: local-claude
description: Start a local Claude Code instance in tmux with interactive login. Use when the user wants to run a nested/second Claude Code instance, spawn a local claude, or needs to authenticate a separate Claude session.
---

# Local Claude Code

Run a separate Claude Code instance outside the remote environment.

## Quick Reference

### Non-Interactive Query (Recommended for most tasks)

```bash
env -u CLAUDE_CODE_REMOTE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_REMOTE_SESSION_ID -u CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR -u CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR \
  claude -p "your query here" --dangerously-skip-permissions
```

This is the fastest approach - no TUI, no permission prompts, direct output.

### Interactive Session (When TUI is needed)

```bash
# Start session
tmux kill-session -t claude-local 2>/dev/null
tmux new-session -d -s claude-local "bash -c 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR; exec claude'"

# Wait and check
sleep 5 && tmux capture-pane -t claude-local -p -S -30

# Send query (two Enters: one to type, one to submit)
tmux send-keys -t claude-local 'your query' Enter Enter

# Get output
sleep 15 && tmux capture-pane -t claude-local -p -S -100
```

### Session Commands

| Action | Command |
|--------|---------|
| Attach | `tmux attach -t claude-local` |
| Send input | `tmux send-keys -t claude-local 'text' Enter` |
| Capture output | `tmux capture-pane -t claude-local -p -S -50` |
| Kill | `tmux kill-session -t claude-local` |

## Prerequisites

- Credentials at `~/.claude/.credentials.json` (restored automatically by post-checkout hook)
- tmux (for interactive sessions only)

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
