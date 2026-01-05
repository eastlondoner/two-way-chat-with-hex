# Learned Skills

*Reusable patterns and lessons learned from iterations.*

## Patterns That Work

### Canary in the Coal Mine Pattern
Use minimal test actions to validate system behavior before relying on infrastructure for complex workflows. Example: Creating a simple test file to confirm hooks are functioning correctly.

### Self-Documenting Names
Use descriptive, self-explanatory names for completion promises and variables (e.g., `HOOKS_WORK` clearly indicates the purpose of the validation test).

### Clear Task Definitions
- Define unambiguous tasks with specific filenames, paths, and content
- Establish simple, measurable completion criteria
- Keep execution paths straightforward with minimal complexity

## Anti-Patterns to Avoid

### Missing Verification Steps
Don't assume file operations succeeded without confirmation. Always include explicit verification steps in the plan.

**Bad:** Write file → assume success  
**Good:** Write file → Read file to confirm contents → proceed

### Incomplete Plans
Plans that lack verification or validation steps may lead to false confidence in task completion.

## Useful Commands

### File Operations
- **Write tool**: Create test files for validation purposes (e.g., `/tmp/hook-test.txt`)
- **Read tool**: Verify file contents after creation or modification

## Lessons Learned

1. **Always verify file operations** - Use Read tool to confirm file contents match expectations after Write operations
2. **Test infrastructure first** - Validate system behavior with simple tests before complex workflows
3. **Explicit over implicit** - Include verification steps explicitly in plans rather than assuming success
