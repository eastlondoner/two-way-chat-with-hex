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

## Authentication

This MCP server reads OAuth credentials from `~/.claude/.credentials.json`, which is populated when you log into Claude Code. You must be authenticated with Claude Code for this to work.

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
