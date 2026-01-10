# Ralph Journal Logging

## Log Location

All diagnostic messages are written to `.ralph/logs/` to keep stdout/stderr clean for hook JSON responses.

## Log Files

- **`.ralph/logs/context.log`** - Context update operations (tactical/strategic document updates)
- **`.ralph/logs/skills.log`** - Skill extraction operations (create/update skills)
- **`.ralph/logs/journal.log`** - Journal generation operations

## Viewing Logs

```bash
# View recent context updates
tail -f .ralph/logs/context.log

# View skill extraction activity
tail -f .ralph/logs/skills.log

# View all logs
tail -f .ralph/logs/*.log

# Clear logs
rm .ralph/logs/*.log
```

## Log Format

Each log entry includes:
- Timestamp (ISO 8601 UTC)
- Component identifier
- Message

Example:
```
[2026-01-10T11:45:23Z] [tactical] Processing 2 new journal(s)
[2026-01-10T11:45:25Z] [tactical] Updated successfully
```

## Benefits

1. **Clean Hook Output**: Hooks output only JSON, never corrupted by diagnostics
2. **Debug-Friendly**: All diagnostic info preserved in files for troubleshooting
3. **No Performance Impact**: Log writes are fire-and-forget (errors ignored)
4. **Automatic Cleanup**: `.ralph/logs/` is gitignored (local debugging only)

## Environment Variable

Set `RALPH_LOG_DIR` to customize log location (defaults to `.ralph/logs`):

```bash
export RALPH_LOG_DIR="$HOME/.ralph-logs"
```
