# claude-town-mcp

MCP server for orchestrating Claude Code web sessions.

## Overview

This MCP server provides tools to interact with Claude Code web sessions via the undocumented Claude Code Sessions API. It enables:

- Listing active web sessions
- Creating new web sessions on GitHub repositories
- Sending messages to sessions (fire-and-forget delegation)
- Monitoring session status

## Authentication

Reads OAuth credentials from well-known location:
- `~/.claude/.credentials.json` (Linux/macOS)
- `%USERPROFILE%\.claude\.credentials.json` (Windows)

Credential format:
```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1768255579077
  }
}
```

Organization UUID is fetched from `/api/oauth/profile` endpoint.

## Claude Code Sessions API (Undocumented)

Base URL: `https://api.anthropic.com`

### Endpoints Used

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/oauth/profile` | Get user profile & org UUID |
| GET | `/v1/sessions` | List all sessions |
| GET | `/v1/sessions/{id}` | Get session details |
| POST | `/v1/sessions/{id}/events` | Send message to session |

### Headers Required

```
Authorization: Bearer <accessToken>
Content-Type: application/json
anthropic-version: 2023-06-01
x-organization-uuid: <orgUUID>
```

## MCP Tools

### `list_sessions`

List all Claude Code web sessions.

**Parameters:**
- `status_filter` (optional): Filter by status - `running`, `idle`, `working`, `waiting`, `completed`, `archived`, `cancelled`
- `repo_filter` (optional): Filter by repository name (substring match)
- `limit` (optional): Max sessions to return (default: 50)

**Returns:** Array of session summaries with id, title, status, repo, timestamps.

### `get_session`

Get detailed information about a specific session.

**Parameters:**
- `session_id` (required): Session ID (e.g., `session_018Tg5Zx7E9v89CN6Q115fWe`)

**Returns:** Full session details including context, sources, outcomes, branch info.

### `create_session`

Create a new Claude Code web session on a GitHub repository.

**Parameters:**
- `repo` (required): GitHub repository in `owner/name` format
- `branch` (optional): Git branch to use
- `prompt` (required): Initial task/prompt for the session

**Behavior:**
- Uses MCP Tasks primitive (long-running operation)
- Polls until session reaches `running` or `working` status
- Returns error if session fails to start

**Returns:** Created session details including session_id, branch, status.

**Requirements:**
- GitHub App must be installed on the repository
- User must have access to the repository

### `send_message`

Send a message to an existing session (fire-and-forget).

**Parameters:**
- `session_id` (required): Session ID
- `message` (required): Message content to send

**Behavior:**
- Fire-and-forget: returns immediately after sending
- Does not wait for response

**Returns:** Confirmation that message was sent.

### `get_session_status`

Get current status of a session (lightweight poll).

**Parameters:**
- `session_id` (required): Session ID

**Returns:** Current status, last updated timestamp.

## Project Structure

```
claude-town-mcp/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # Entry point, MCP server setup
│   ├── auth.ts           # Credential loading & org UUID
│   ├── api-client.ts     # Claude Code Sessions API client
│   ├── tools/
│   │   ├── list-sessions.ts
│   │   ├── get-session.ts
│   │   ├── create-session.ts
│   │   ├── send-message.ts
│   │   └── get-session-status.ts
│   └── types.ts          # Shared types
├── dist/                 # Compiled output
└── SPEC.md              # This file
```

## Dependencies

- `@modelcontextprotocol/sdk` - MCP SDK
- `zod` - Schema validation
- `axios` (or fetch) - HTTP client

## Usage

```bash
# Install
npm install

# Build
npm run build

# Run (stdio mode)
node dist/index.js

# Or with bun
bun run src/index.ts
```

### Claude Code Configuration

Add to `.mcp.json`:

```json
{
  "mcpServers": {
    "claude-town": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/claude-town-mcp/dist/index.js"]
    }
  }
}
```

## Session States

| Status | Description |
|--------|-------------|
| `running` | Session is actively processing |
| `working` | Session is executing tools |
| `waiting` | Session is waiting for user input |
| `idle` | Session is idle, ready for new messages |
| `completed` | Session task completed |
| `archived` | Session archived |
| `cancelled` | Session cancelled |

## Error Handling

- **401 Unauthorized**: Token expired - prompt user to run `/login`
- **404 Not Found**: Session doesn't exist
- **Network errors**: Retry with exponential backoff

## References

- [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- [MCP Tasks](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
