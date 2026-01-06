# Testing Claude Code Plugins with tmux

## Overview
Use tmux to run a separate Claude Code session for testing plugins, hooks, and commands without interfering with your main development session.

## Setup

```bash
# Create a detached tmux session
tmux new-session -d -s plugin-test -c /path/to/project

# Start Claude Code in the session
tmux send-keys -t plugin-test 'claude --dangerously-skip-permissions' Enter
```

## Interacting with the Test Session

```bash
# Send a command to the session
tmux send-keys -t plugin-test '/your-command args' Enter

# Capture output (last N lines)
tmux capture-pane -t plugin-test -p -S -50

# Clear input buffer
tmux send-keys -t plugin-test C-u

# Cancel current operation
tmux send-keys -t plugin-test C-c

# Exit Claude
tmux send-keys -t plugin-test '/exit' Enter
```

## Testing Workflow

1. **Start session**: Create tmux session with Claude Code
2. **Install plugin** (if needed): `/plugin marketplace add /absolute/path` then `/plugin install name@marketplace`
3. **Run command**: Send your slash command via `tmux send-keys`
4. **Wait & capture**: `sleep N && tmux capture-pane -t session -p -S -50`
5. **Verify artifacts**: Check generated files (journals, state, etc.)
6. **Iterate**: Modify plugin code, restart Claude, test again

## Key Tips

- Use `--dangerously-skip-permissions` to avoid approval prompts
- Always use absolute paths for marketplace directories
- Add `sleep N` between commands to allow processing
- Use `-S -N` to capture N lines of scrollback history
- Check `.claude/settings.json` for project-level hooks
- Verify plugin artifacts in expected locations

## Cleanup

```bash
tmux kill-session -t plugin-test
```
