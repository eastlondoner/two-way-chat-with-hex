---
name: hook-debugging-workflow
description: Use when investigating or debugging hook systems in Claude Code or similar environments
---

# Hook Debugging Workflow

When working with hook systems (event-driven automation triggered by file operations or other events), follow this systematic investigation approach.

## Investigation Steps

1. **Start with existing examples**: Locate and read existing hook scripts (e.g., `stop-hook.sh`) to understand current usage patterns
2. **Identify the data structure**: Determine what data is available in hook inputs (environment variables, JSON payloads, etc.)
3. **Create a universal debugging script**: Build a generic logger that captures all hook input data to a debug file
4. **Test with multiple triggers**: Trigger various hook types to understand different data formats
5. **Document findings**: Create comprehensive documentation of the input structure for future reference

## Debugging Script Pattern

```bash
#!/bin/bash
echo "Hook triggered at $(date)" >> /tmp/hook-debug.log
echo "Input data: $HOOK_INPUT" >> /tmp/hook-debug.log
```

## Key Considerations

- Use absolute paths for debug logs (e.g., `/tmp/hook-debug.log`)
- Make debugging scripts generic enough to work with any hook type
- Include timestamps in debug output
- Verify debugging mechanism works before relying on it
- Document both the structure (`transcript_path`, etc.) and example values

## When to Use

- Initial hook system setup
- Investigating hook failures
- Understanding available hook data
- Creating new hook types
