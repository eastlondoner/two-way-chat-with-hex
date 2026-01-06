---
name: always-verify-file-operations
description: Explicitly verify file operations succeeded by reading back the content; never assume write operations completed successfully.
---

## Pattern

After any file write operation, explicitly verify the operation succeeded by reading the file back and confirming its contents match expectations. Don't assume tools succeeded just because they didn't throw errors.

**Bad Approach:**
1. Write file
2. Assume success
3. Proceed to next task

**Good Approach:**
1. Write file using Write tool
2. Read file back using Read tool
3. Verify contents match expectations
4. Proceed only after confirmation

## When to Apply

- After every Write tool call where correctness matters
- When creating configuration files that will be used by other processes
- In automation workflows where silent failures could cause downstream issues
- When the file operation is part of a completion promise or validation step

## Why This Matters

File systems can fail silently due to permissions, disk space, race conditions, or other issues. Explicit verification catches these problems immediately rather than discovering them later when debugging mysterious failures.
