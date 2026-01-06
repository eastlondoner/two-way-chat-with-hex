---
name: canary-validation-pattern
description: Use minimal test actions to validate system behavior before relying on infrastructure for complex workflows.
---

## Pattern

Before building complex workflows that depend on system infrastructure (hooks, CI/CD, integrations), create a simple "canary" test to validate the infrastructure is working correctly. This minimal test should:

- Be trivial to execute (single file operation, simple command)
- Have clear, observable success criteria
- Test the specific infrastructure component you'll rely on
- Fail fast if the infrastructure isn't working
- Include timestamps for debugging purposes
- Be idempotent (safe to run multiple times)

## When to Apply

- Before implementing workflows that depend on git hooks, CI/CD, or other automation
- When setting up new development environments or tooling
- After infrastructure changes to confirm nothing broke
- When troubleshooting why complex operations aren't working as expected
- To validate permission levels and access rights

## Example

Creating `/tmp/hook-test.txt` to verify git hooks are firing before implementing a complex pre-commit workflow.

## Best Practices

- **Include timestamps**: Add timestamps to canary test content for debugging (e.g., "canary test - 2026-01-06 18:00:00")
- **Test permissions**: Use canary tests to validate not just functionality but also permission levels
- **Make it idempotent**: Design canary tests that can run multiple times without side effects or conflicts
- **Verify the canary**: Always read back or verify the canary test succeeded before proceeding
