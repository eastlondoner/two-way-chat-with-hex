---
name: remote-claude
description: Run Claude Code on the desktop Mac via SSH and tmux. Use when the user wants to run a separate Claude instance on the desktop, delegate tasks to desktop Claude, or interact with Claude running on the Mac.
---

# Remote Claude on Desktop

Run a Claude Code instance on the desktop Mac via SSH, using tmux for session persistence.

## Prerequisites

- SSH access to desktop configured (see `ssh-desktop` skill)
- tmux installed on desktop (via Homebrew)
- Claude CLI installed on desktop

## IMPORTANT: Always Source the Shell

**Always wrap SSH commands with `zsh -l -c '...'`** to load the login shell environment. This ensures:
- `tmux` is available on PATH
- `claude` CLI is available on PATH
- All environment variables are properly set

Without the login shell wrapper, commands may fail with "command not found" errors.

## Quick Reference

> **Security Warning**: The `--dangerously-skip-permissions` flag bypasses all permission prompts and trust dialogs. Only use this on a trusted, personal Mac with trusted repositories. For interactive use where you want prompts, omit the flag.

### Start Claude Session

```bash
# Start new Claude session on desktop (with --dangerously-skip-permissions for automation)
# WARNING: This bypasses permission prompts - use only on trusted machines/repos
ssh desktop "zsh -l -c 'tmux new-session -d -s claude-desktop \"claude --dangerously-skip-permissions\"'"

# Verify session started
ssh desktop "zsh -l -c 'tmux list-sessions'"
```

### Send Queries

```bash
# Send query using -l (literal) flag - IMPORTANT: -l is required!
ssh desktop "zsh -l -c 'tmux send-keys -t claude-desktop -l \"your query here\" && tmux send-keys -t claude-desktop Enter'"

# Wait and capture response
sleep 15
ssh desktop "zsh -l -c 'tmux capture-pane -t claude-desktop -p -S -50'"
```

### Session Commands

| Action | Command |
|--------|---------|
| Check status | `ssh desktop "zsh -l -c 'tmux capture-pane -t claude-desktop -p -S -30'"` |
| Send query | `ssh desktop "zsh -l -c 'tmux send-keys -t claude-desktop -l \"text\" && tmux send-keys -t claude-desktop Enter'"` |
| List sessions | `ssh desktop "zsh -l -c 'tmux list-sessions'"` |
| Kill session | `ssh desktop "zsh -l -c 'tmux kill-session -t claude-desktop'"` |

## Helper Functions

For convenience, add these to your workflow:

```bash
# Send command to desktop Claude (uses -l for literal mode)
desktop_claude_send() {
    ssh desktop "zsh -l -c 'tmux send-keys -t claude-desktop -l \"$1\" && tmux send-keys -t claude-desktop Enter'"
}

# Get desktop Claude output
desktop_claude_output() {
    ssh desktop "zsh -l -c 'tmux capture-pane -t claude-desktop -p -S -${1:-50}'"
}

# Full query with response
desktop_claude_query() {
    desktop_claude_send "$1"
    sleep "${2:-15}"
    desktop_claude_output "${3:-50}"
}
```

## Important Notes

- **Always use `-l` flag** with `send-keys` for query text. Without it, special characters are interpreted as tmux key bindings.
- **Single Enter** is sufficient to submit queries (not double Enter).
- The `-l` flag sends keys "literally" without interpretation.

## Authentication

The desktop Claude may need authentication:

1. **Check status**: Look for "Missing API key" in output
2. **Run login**: Send `/login` command via tmux
3. **Complete OAuth**: Follow the auth flow if needed

```bash
# Start login flow
ssh desktop "zsh -l -c 'tmux send-keys -t claude-desktop -l \"/login\" && tmux send-keys -t claude-desktop Enter'"
sleep 3
ssh desktop "zsh -l -c 'tmux capture-pane -t claude-desktop -p -S -30'"
```

## Trust Dialog

On first run in a new directory, Claude shows a trust dialog.

**With `--dangerously-skip-permissions`**: Trust dialogs are auto-accepted; no action needed.

**Without the flag**: Accept manually with:

```bash
ssh desktop "zsh -l -c 'tmux send-keys -t claude-desktop Enter'"
```

## Troubleshooting

### Session not starting
- Ensure login shell: use `zsh -l -c '...'`
- Check Claude exists: `ssh desktop "zsh -l -c 'which claude'"`
- Check tmux exists: `ssh desktop "zsh -l -c 'which tmux'"`

### Empty output
- Wait longer before capture (Claude TUI takes time to render)
- Check session exists: `ssh desktop "zsh -l -c 'tmux list-sessions'"`

### PATH issues
The desktop has minimal PATH in non-login shells. **Always use `zsh -l -c '...'`** wrapper for all commands. This loads the login shell environment where both `tmux` and `claude` are available on PATH.
