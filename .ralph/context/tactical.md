# Tactical Context

*Current goals and immediate details for the task at hand.*

## Current Goal
Implementing `/search-journals` command for ralph-journal plugin to enable keyword-based search across journal entries stored in `.ralph/journal/*.md`.

## Current Blockers
None - currently in planning phase.

## Recent Decisions
- **Iterative approach**: Build feature → tests → docs (avoids over-engineering, enables early validation)
- **Minimal working feature first**: Core search functionality before enhancements
- **Context extraction**: Return surrounding lines with matches for usefulness

## Important Details

### Implementation Requirements
- Command: `/search-journals` with keyword argument
- Search target: `.ralph/journal/*.md` files via file system traversal
- Output: Matching entries with surrounding context lines
- Must include comprehensive tests and documentation

### Technical Plan
1. Core search: argument parsing + file reading
2. Keyword matching logic + context extraction (surrounding lines)
3. User-friendly result formatting
4. Test suite (edge cases: no matches, multiple matches, special characters)
5. Usage documentation with examples
6. Test validation and iteration

### Open Technical Questions
- **Case sensitivity**: Case-sensitive or case-insensitive search?
- **Matching strategy**: Regex vs literal string matching?
- **Performance**: Strategy for handling large journal collections?
- **Context window**: How many lines before/after match to include?
