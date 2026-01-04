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

### Automated token refresh via GitHub Actions

This repo includes a GitHub Action (`.github/workflows/refresh-claude-token.yml`) that automatically refreshes tokens before they expire:

- **Schedule**: Runs every 6 hours (before the 8-hour expiry)
- **Manual trigger**: Can be run manually via `workflow_dispatch`
- **Requires**: `PAT_TOKEN` secret with repo scope (for updating variables)
- **How it works**:
  1. Pulls credentials from `CLAUDE_CREDENTIALS` repository variable
  2. Installs Claude CLI and patches the refresh threshold from 5min to 8 hours
  3. Runs Claude CLI which triggers internal token refresh
  4. Pushes updated credentials back to the GitHub variable using `PAT_TOKEN`

To trigger manually:
```bash
gh workflow run refresh-claude-token.yml --repo eastlondoner/claude
```

**If the workflow fails with "Token refresh failed"**: The token was likely revoked. Follow the "Manual credential sync" steps above to re-authenticate.

### Backup credentials after login

After a successful OAuth login, save the credentials:

```bash
cp ~/.claude/.credentials.json /path/to/backup/.credentials.json
```

## Automated Credential Sync with Git Hooks

This repo includes Git hooks that automatically sync credentials with a GitHub repository variable.

### Setup (run once after clone)

```bash
git config core.hooksPath .githooks
```

### How it works

| Hook | Trigger | Action |
|------|---------|--------|
| `post-checkout` | After `git clone` or `git checkout` | Pulls credentials from GitHub variable |
| `post-commit` | After each commit | Pushes credentials to GitHub variable |

### Requirements

- `GITHUB_TOKEN` environment variable must be set with repo access
- `jq` must be available for JSON parsing

### Manual credential sync

When the token gets revoked (e.g., from a failed refresh workflow), you need to re-authenticate and update the GitHub variable manually.

#### Step 1: Re-authenticate via OAuth

```bash
# Start OAuth flow
tmux kill-session -t claude-reauth 2>/dev/null
tmux new-session -d -s claude-reauth
tmux send-keys -t claude-reauth 'unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR' Enter
tmux send-keys -t claude-reauth 'claude /login' Enter

# Wait and get the OAuth URL
sleep 5
tmux capture-pane -t claude-reauth -p

# After user provides code:
tmux send-keys -t claude-reauth '<CODE_HERE>' Enter
tmux send-keys -t claude-reauth Enter  # Press Enter to continue
```

#### Step 2: Update GitHub variable (IMPORTANT)

After successful OAuth login, update the GitHub variable with the new credentials:

```bash
# Using gh CLI (recommended - simple and reliable)
gh variable set CLAUDE_CREDENTIALS --repo eastlondoner/claude --body "$(base64 -w0 ~/.claude/.credentials.json)"
```

Alternative using curl:
```bash
CREDS=$(cat ~/.claude/.credentials.json | base64 -w0)
curl -X PATCH \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/variables/CLAUDE_CREDENTIALS" \
  -d "{\"name\":\"CLAUDE_CREDENTIALS\",\"value\":\"$CREDS\"}"
```

#### Step 3: Verify the variable was updated

```bash
# Check the variable exists and has content
gh variable list --repo eastlondoner/claude | grep CLAUDE_CREDENTIALS
```

**Pull credentials from GitHub:**
```bash
# Using gh CLI
gh variable get CLAUDE_CREDENTIALS --repo eastlondoner/claude | base64 -d > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
```

Alternative using curl:
```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/OWNER/REPO/actions/variables/CLAUDE_CREDENTIALS" | \
  jq -r '.value' | base64 -d > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
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
