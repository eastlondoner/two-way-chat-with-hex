---
description: "Cancel active Ralph Journal loop"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph Journal

```!
if [[ -f .ralph/loop_state.json ]]; then
  ITERATION=$(jq -r '.iteration' .ralph/loop_state.json)
  LOOP_ID=$(jq -r '.loop_id' .ralph/loop_state.json)
  JOURNAL_COUNT=$(ls -1 .ralph/journal/*.md 2>/dev/null | wc -l || echo 0)
  echo "FOUND_LOOP=true"
  echo "ITERATION=$ITERATION"
  echo "LOOP_ID=$LOOP_ID"
  echo "JOURNAL_COUNT=$JOURNAL_COUNT"
else
  echo "FOUND_LOOP=false"
fi
```

Check the output above:

1. **If FOUND_LOOP=false**:
   - Say "No active Ralph Journal loop found."

2. **If FOUND_LOOP=true**:
   - Use Bash to mark the loop inactive: `jq '.active = false | .cancelled = true' .ralph/loop_state.json > .ralph/loop_state.json.tmp && mv .ralph/loop_state.json.tmp .ralph/loop_state.json`
   - Report: "Cancelled Ralph Journal loop (Loop ID: X, was at iteration N, generated M journal entries)"
   - Note: Journal entries and context documents are preserved in `.ralph/`
