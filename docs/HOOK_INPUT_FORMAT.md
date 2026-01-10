# Claude Code Hook Input Format

This document describes the JSON structure that Claude Code passes to hooks via stdin.

## Common Fields (All Hook Types)

Every hook receives these standard fields:

```json
{
  "session_id": "abc123-uuid",
  "transcript_path": "/Users/.../.claude/projects/.../00893aaf-19fa-41d2-8238-13269b9b3ca0.jsonl",
  "cwd": "/Users/.../project",
  "permission_mode": "default",
  "hook_event_name": "Stop"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | UUID identifying the Claude Code session |
| `transcript_path` | string | Absolute path to the session transcript file (JSONL format) |
| `cwd` | string | Current working directory when hook is invoked |
| `permission_mode` | string | One of: `default`, `plan`, `acceptEdits`, `dontAsk`, `bypassPermissions` |
| `hook_event_name` | string | The hook event that triggered this invocation |

## Hook-Specific Input Structures

### Stop Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `stop_hook_active` | boolean | `true` when Claude is already continuing from a previous stop hook (prevents infinite loops) |

### SubagentStop Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": true
}
```

### PreToolUse Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path/to/file", "content": "..." },
  "tool_use_id": "toolu_01ABC123..."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tool_name` | string | Name of the tool being invoked (e.g., `Write`, `Bash`, `Read`) |
| `tool_input` | object | Tool-specific input parameters (varies by tool) |
| `tool_use_id` | string | Unique identifier for this tool invocation |

### PostToolUse Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path/to/file", "content": "..." },
  "tool_response": { "filePath": "/path/to/file", "success": true },
  "tool_use_id": "toolu_01ABC123..."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tool_response` | object | Tool-specific response/result (varies by tool) |

### PermissionRequest Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf /tmp/test" },
  "tool_use_id": "toolu_01ABC123..."
}
```

### PreCompact Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": "Focus on the authentication changes"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `trigger` | string | `manual` (from `/compact` command) or `auto` (from auto-compact) |
| `custom_instructions` | string | User-provided instructions for manual compact (empty for auto) |

### UserPromptSubmit Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "Write a function to calculate factorial"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `prompt` | string | The user's submitted prompt text |

### Notification Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "Notification",
  "message": "Claude needs your permission to use Bash",
  "notification_type": "permission_prompt"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | The notification message content |
| `notification_type` | string | One of: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |

### SessionStart Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "SessionStart",
  "source": "startup"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | One of: `startup`, `resume`, `clear`, `compact` |

### SessionEnd Hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "SessionEnd",
  "reason": "exit"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `reason` | string | One of: `clear`, `logout`, `prompt_input_exit`, `other` |

## Transcript File Format

The `transcript_path` points to a JSONL file (JSON Lines format) where each line is a separate JSON object representing a conversation event:

```jsonl
{"message":{"role":"user","content":[{"type":"text","text":"Hello"}]}}
{"message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
{"tool_use":{"id":"toolu_01ABC123","name":"Write","input":{"file_path":"/tmp/test.txt","content":"Hello"}}}
{"tool_result":{"id":"toolu_01ABC123","content":"File written successfully"}}
```

### Message Structure

User and assistant messages follow this structure:

```json
{
  "message": {
    "role": "user" | "assistant",
    "content": [
      {
        "type": "text",
        "text": "The message content"
      }
    ]
  }
}
```

### Tool Use Structure

Tool invocations are logged as:

```json
{
  "tool_use": {
    "id": "toolu_01ABC123",
    "name": "ToolName",
    "input": { /* tool-specific input */ }
  }
}
```

### Tool Result Structure

Tool results are logged as:

```json
{
  "tool_result": {
    "id": "toolu_01ABC123",
    "content": "Result content or error message"
  }
}
```

## Debugging Hook Inputs

The Ralph Journal plugin includes a debug script that logs all hook inputs to `/tmp/hook-debug.log`:

```bash
# Location
.claude/plugins/ralph-journal/scripts/debug-hook-input.sh

# Usage: pipe hook input through it
HOOK_INPUT=$(cat | "$PLUGIN_ROOT/scripts/debug-hook-input.sh")
```

The debug log includes:
- Timestamp and hook event name
- Pretty-printed JSON of the full input
- Transcript file metadata (lines, size) when available

### Example Debug Log Entry

```
═══════════════════════════════════════════════════════════════════
[2026-01-06T17:32:29.000Z] Hook Event: Stop | Session: abc123-t...
───────────────────────────────────────────────────────────────────
{
  "session_id": "abc123-test",
  "transcript_path": "/tmp/test-transcript.jsonl",
  "cwd": "/Users/andy/repos/ralph-journal",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
───────────────────────────────────────────────────────────────────
Transcript: /tmp/test-transcript.jsonl
  Lines: 2 | Size: 158B
═══════════════════════════════════════════════════════════════════
```

## Hook Output Format

Hooks can return JSON via stdout to control Claude Code's behavior:

```json
{
  "decision": "block",
  "reason": "Reason for the decision or prompt to continue",
  "systemMessage": "Message shown to user",
  "continue": false,
  "stopReason": "Why stopping",
  "suppressOutput": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `decision` | string | For Stop/SubagentStop: `block` to prevent stopping |
| `reason` | string | Explanation or prompt content for continuation |
| `systemMessage` | string | Warning/info message shown to user |
| `continue` | boolean | `false` to stop Claude entirely |
| `stopReason` | string | Message explaining why stopping |
| `suppressOutput` | boolean | Hide output from user |

## References

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks.md)
- [Hooks Quickstart Guide](https://code.claude.com/docs/en/hooks-guide.md)
