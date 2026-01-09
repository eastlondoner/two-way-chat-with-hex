---
name: remote-claude
description: Run Claude Code on the desktop Mac via SSH and tmux. Use when the user wants to run a separate Claude instance on the desktop, delegate tasks to desktop Claude, or interact with Claude running on the Mac.
---

# Remote Claude on Desktop

Run a Claude Code instance on the desktop Mac via SSH, using tmux for session persistence.

## Prerequisites

- SSH access to desktop configured (see `ssh-desktop` skill)
- tmux installed on desktop: `/opt/homebrew/bin/tmux`
- Claude CLI installed on desktop: `~/.local/bin/claude`
- Login shell required to load PATH (use `zsh -l -c '...'`)

## Quick Reference

### Start Claude Session

```bash
# Start new Claude session on desktop
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux new-session -d -s claude-desktop \"bash -c \\\"source ~/.zshrc; claude; exec bash\\\"\"'"

# Verify session started
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux list-sessions'"
```

### Send Queries

```bash
# Send query (double Enter to submit)
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux send-keys -t claude-desktop \"your query here\" Enter Enter'"

# Wait and capture response
sleep 15
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux capture-pane -t claude-desktop -p -S -50'"
```

### Session Commands

| Action | Command |
|--------|---------|
| Check status | `ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux capture-pane -t claude-desktop -p -S -30'"` |
| Send query | `ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux send-keys -t claude-desktop \"text\" Enter Enter'"` |
| List sessions | `ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux list-sessions'"` |
| Kill session | `ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux kill-session -t claude-desktop'"` |

## Helper Functions

For convenience, add these to your workflow:

```bash
# Send command to desktop Claude
desktop_claude_send() {
    ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux send-keys -t claude-desktop \"$1\" Enter Enter'"
}

# Get desktop Claude output
desktop_claude_output() {
    ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux capture-pane -t claude-desktop -p -S -${1:-50}'"
}

# Full query with response
desktop_claude_query() {
    desktop_claude_send "$1"
    sleep "${2:-15}"
    desktop_claude_output "${3:-50}"
}
```

## Authentication

The desktop Claude may need authentication:

1. **Check status**: Look for "Missing API key" in output
2. **Run login**: Send `/login` command via tmux
3. **Complete OAuth**: Follow the auth flow if needed

```bash
# Start login flow
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux send-keys -t claude-desktop \"/login\" Enter'"
sleep 3
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux capture-pane -t claude-desktop -p -S -30'"
```

## Trust Dialog

On first run in a new directory, Claude shows a trust dialog. Accept with:

```bash
ssh desktop "zsh -l -c '/opt/homebrew/bin/tmux send-keys -t claude-desktop Enter'"
```

## Troubleshooting

### Session not starting
- Ensure login shell: use `zsh -l -c '...'`
- Check Claude exists: `ssh desktop "zsh -l -c 'which claude'"`
- Check tmux exists: `ssh desktop "zsh -l -c 'which tmux'"`

### Empty output
- Wait longer before capture (Claude TUI takes time to render)
- Check session exists: `tmux list-sessions`

### PATH issues
The desktop has minimal PATH in non-login shells. Always use:
- `zsh -l -c '...'` wrapper for commands
- Full paths: `/opt/homebrew/bin/tmux`, `~/.local/bin/claude`
