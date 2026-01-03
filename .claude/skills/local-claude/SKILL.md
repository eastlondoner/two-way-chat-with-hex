---
name: local-claude
description: Start a local Claude Code instance in tmux with interactive login. Use when the user wants to run a nested/second Claude Code instance, spawn a local claude, or needs to authenticate a separate Claude session.
---

# Starting a Local Claude Code Instance

This skill helps you start a separate Claude Code instance in a tmux session with proper authentication.

## Prerequisites

- tmux must be available
- User must have a Claude subscription (Pro, Max, Team, or Enterprise) for OAuth login

## Steps

### 1. Kill any existing session and create a fresh tmux session

```bash
tmux kill-session -t claude-local 2>/dev/null
tmux new-session -d -s claude-local
```

### 2. Unset remote environment variables

The key issue in Claude Code remote environments is that `CLAUDE_CODE_REMOTE` and related environment variables disable TUI mode. You must unset them before running Claude:

```bash
tmux send-keys -t claude-local 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR' Enter
```

### 3. Start Claude Code

```bash
tmux send-keys -t claude-local 'claude' Enter
```

### 4. Wait for TUI to load and capture output

```bash
sleep 8
tmux capture-pane -t claude-local -p -S -50
```

### 5. Navigate through initial setup

The TUI will show:
1. **Theme selection** - Press Enter to accept default (Dark mode)
2. **Login method** - Press Enter to select "Claude account with subscription"
3. **OAuth URL** - Extract and share with user

To extract the OAuth URL:
```bash
tmux capture-pane -t claude-local -p -S -50 | grep -A10 "Browser didn't open" | grep -v "Browser\|Paste" | tr -d ' \n' | grep -o 'https://[^>]*'
```

### 6. Complete authentication

Once the user provides the OAuth code:
```bash
tmux send-keys -t claude-local '<paste-code-here>' Enter
```

Then press Enter through:
- Login confirmation
- Security notes
- Trust dialog (select "Yes, proceed")

### 7. Verify the instance is working

Send a test query:
```bash
tmux send-keys -t claude-local 'what is 2+2?' Enter Enter
sleep 10
tmux capture-pane -t claude-local -p -S -30
```

## Interacting with the session

- **Attach to session**: `tmux attach -t claude-local`
- **Send commands**: `tmux send-keys -t claude-local '<command>' Enter`
- **Capture output**: `tmux capture-pane -t claude-local -p -S -50`
- **Kill session**: `tmux kill-session -t claude-local`

## Reusing Credentials (Skip OAuth Login)

Once authenticated, Claude stores credentials in `~/.claude/.credentials.json`. You can copy this file to skip the OAuth flow on new instances.

### Credentials file location

```
~/.claude/.credentials.json
```

### Credentials format

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1767499673845,
    "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "max",
    "rateLimitTier": "default_claude_max_5x"
  }
}
```

### Quick start with existing credentials

If you have a valid credentials file, copy it before starting Claude:

```bash
# Create config directory if needed
mkdir -p ~/.claude

# Copy credentials (from backup or another instance)
cp /path/to/saved/.credentials.json ~/.claude/.credentials.json

# Then start Claude normally (still need to unset remote vars)
tmux kill-session -t claude-local 2>/dev/null
tmux new-session -d -s claude-local
tmux send-keys -t claude-local 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR' Enter
tmux send-keys -t claude-local 'claude' Enter
```

### Token expiration

- Access tokens expire after ~8 hours
- The refresh token automatically obtains new access tokens
- If refresh fails, you'll need to re-authenticate via OAuth

### Backup credentials after login

After a successful OAuth login, save the credentials:

```bash
cp ~/.claude/.credentials.json /path/to/backup/.credentials.json
```

## Troubleshooting

### TUI not displaying
Ensure all `CLAUDE_CODE_*` environment variables are unset before starting Claude.

### Authentication fails
The OAuth code expires quickly. Request a fresh URL if needed by restarting Claude.

### Session appears frozen
The TUI might be waiting for input. Try sending `Enter` or check with `tmux capture-pane`.

### Credentials not working
- Check if access token has expired (`expiresAt` field)
- Ensure the file has correct permissions: `chmod 600 ~/.claude/.credentials.json`
- Try deleting and re-authenticating if refresh token is invalid
