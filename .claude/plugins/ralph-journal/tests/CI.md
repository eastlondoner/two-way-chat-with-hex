# CI Test Suite

## Overview

The ralph-journal plugin includes a GitHub Actions CI workflow that runs the test suite on both Ubuntu and macOS to ensure cross-platform compatibility.

## Workflow Details

**File:** `.github/workflows/test-plugin.yml`

**Triggers:**
- Push to `main` or `master` branch (when plugin files change)
- Pull requests to `main` or `master` (when plugin files change)
- Manual trigger via `workflow_dispatch`

**Test Matrix:**
- `ubuntu-latest`
- `macos-latest`

**Dependencies Installed:**
- `jq` (JSON processor)
- Standard Unix tools (bash, grep, etc.)

## Running Tests Locally

To run the test suite locally:

```bash
cd .claude/plugins/ralph-journal/tests
bash test-search-journals.sh
```

## Current Status

As of implementation, the tests have known failures on macOS due to portability issues with GNU-specific tools (`stat --format`, `grep -oP`). These issues are tracked in the RalphJournalHardening plan and will be addressed by:

- Item #1: Adding portable helper functions
- Item #2: Refactoring search-journals.sh for cross-platform compatibility
- Item #6: Fixing test suite bugs (max-results test)
- Item #7: Adding additional portability test cases

## Test Coverage

The current test suite (`test-search-journals.sh`) covers:

1. Help option display
2. Error handling (missing search term, missing directory, empty directory)
3. Basic search functionality
4. Case-insensitive and case-sensitive search modes
5. Search result limiting (max-results)
6. List-only mode
7. Context lines option
8. Multi-word search queries
9. Iteration info extraction
10. Various search patterns (timeout, database, Kubernetes, etc.)

## Future Enhancements

Once portability issues are resolved:
- All tests should pass on both Ubuntu and macOS
- Additional tests will be added for edge cases
- Consider adding tests for other scripts (generate-journal.sh, update-context.sh, etc.)
