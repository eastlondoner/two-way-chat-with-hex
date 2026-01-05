---
description: "Search through Ralph Journal entries by keyword"
argument-hint: "<search query> [--context N] [--max-results N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/search-journals.sh *)"]
---

# Search Ralph Journals

Search through journal entries for relevant historical context.

## Query
$ARGUMENTS

## Instructions

Execute the search script with the user's query:

```!
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/search-journals.sh"

"${CLAUDE_PLUGIN_ROOT}/scripts/search-journals.sh" $ARGUMENTS
```

After reviewing the search results:

1. **Synthesize** the information into a focused summary that answers the query
2. **Include** in your response:
   - Which iterations contained relevant information
   - Key findings from those iterations
   - Any patterns or lessons learned
   - Recommendations based on past experience

## Search Options

The search script supports these options:

| Option | Description |
|--------|-------------|
| `-c, --context N` | Lines of context around matches (default: 3) |
| `-n, --max-results N` | Maximum matching files to show (default: 10) |
| `-i, --case-sensitive` | Make search case-sensitive (default: case-insensitive) |
| `-l, --list-only` | Only list matching files, don't show content |

## Example Queries

```bash
# Basic search
/search-journals "database timeout"

# Search with more context
/search-journals "API error" --context 5

# Just list matching files
/search-journals "deploy" --list-only

# Show more results
/search-journals "kubernetes" --max-results 20
```

## What to Look For

When searching journals, consider:

- **How did we handle similar issues?** - Past solutions and approaches
- **What configuration worked?** - Settings that resolved problems
- **What were the blockers?** - Issues encountered and how they were resolved
- **What skills did we learn?** - Patterns and anti-patterns discovered

Provide a concise, actionable summary of what you find.
