---
description: "Search through Ralph Journal entries"
argument-hint: "<search query>"
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# Search Ralph Journals

Search through journal entries for relevant historical context.

## Query
$ARGUMENTS

## Instructions

1. First, check if journals exist:
```bash
ls -la .ralph/journal/*.md 2>/dev/null | head -20
```

2. Use Grep to find journals mentioning relevant keywords from the query.

3. Read the most relevant journal files (limit to 5 most relevant).

4. Synthesize the information into a focused summary that answers the query.

5. Include:
   - Which iterations contained relevant information
   - Key findings from those iterations
   - Any patterns or lessons learned
   - Recommendations based on past experience

## Example Queries

- "How did we handle the database timeout issue?"
- "What configuration worked for the staging deploy?"
- "What were the blockers in previous attempts?"
- "What skills have we learned about Kubernetes?"

Provide a concise, actionable summary of what you find.
