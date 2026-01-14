# claude-town-mcp

MCP server for orchestrating Claude Code web sessions via the undocumented Claude Code Sessions API.

## Features

- **list_sessions** - List all your Claude Code web sessions with filtering by status
- **get_session** - Get detailed information about a specific session
- **send_message** - Send a message/task to a running session (fire-and-forget)
- **get_session_status** - Check the current status of a session
- **create_session** - Create a new session (placeholder - API not yet discovered)

## Installation

```bash
npm install -g claude-town-mcp
```

Or add to your Claude Code MCP configuration:

```bash
claude mcp add claude-town -- npx claude-town-mcp
```

### Connect to servers mid-session

You can also connect to this MCP server during an active Claude Code session using the `/mcp` command:

```
/mcp add claude-town -- npx claude-town-mcp
```

For a local stdio server from a cloned repository:

```
/mcp add claude-town -- node /path/to/claude-town-mcp/dist/index.js
```

Or using bun during development:

```
/mcp add claude-town -- bun run /path/to/claude-town-mcp/src/index.ts
```

## Authentication

This MCP server automatically loads OAuth credentials from Claude Code's standard locations:

1. **macOS Keychain** (primary on macOS) - Service: "Claude Code-credentials"
2. **File-based credentials** - `~/.claude/.credentials.json`

You must be authenticated with Claude Code (`/login`) for this to work.

**Note:** When running via SSH on macOS, Keychain access may require GUI authorization. If credentials are inaccessible, you can create a fallback file at `~/.claude/.credentials.json`.

## Usage

Once installed as an MCP server, you can use these tools from Claude:

### List Sessions

```
Use list_sessions to see all my Claude Code web sessions
```

Options:
- `status_filter`: Filter by session status (running, working, waiting, idle, completed, archived, cancelled, rejected)

### Get Session Details

```
Use get_session with session_id "abc123" to get full details
```

### Send Message

```
Use send_message to send "Run the tests" to session "abc123"
```

### Check Status

```
Use get_session_status for session "abc123"
```

## Session Statuses

- **running** - Session is actively processing
- **working** - Session is working on a task
- **waiting** - Session is waiting for user input
- **idle** - Session is idle
- **completed** - Session has finished
- **archived** - Session has been archived
- **cancelled** - Session was cancelled
- **rejected** - Session was rejected

## Development

```bash
# Install dependencies
bun install

# Build
bun run build

# Run locally
bun run dev

# Type check
bun run typecheck
```

## Requirements

- Node.js >= 20.0.0
- Claude Code installed and authenticated
- The Anthropic GitHub App installed on repositories you want to access

## License

MIT
