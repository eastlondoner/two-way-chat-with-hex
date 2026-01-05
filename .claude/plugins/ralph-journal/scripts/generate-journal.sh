#!/bin/bash

# Generate Journal Entry Script - Simple Version
# Extracts information directly from transcript without AI calls

set -euo pipefail

TRANSCRIPT_PATH="${1:-}"
LOOP_STATE_PATH="${2:-.ralph/loop_state.json}"
JOURNAL_DIR="${3:-.ralph/journal}"

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Error: Transcript path required and must exist" >&2
  exit 1
fi

if [[ ! -f "$LOOP_STATE_PATH" ]]; then
  echo "Error: Loop state file not found: $LOOP_STATE_PATH" >&2
  exit 1
fi

mkdir -p "$JOURNAL_DIR"

# Read loop state
LOOP_ID=$(jq -r '.loop_id' "$LOOP_STATE_PATH")
ITERATION=$(jq -r '.iteration' "$LOOP_STATE_PATH")
PROMPT=$(jq -r '.prompt' "$LOOP_STATE_PATH")
COMPLETION_PROMISE=$(jq -r '.completion_promise // "none"' "$LOOP_STATE_PATH")

TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
JOURNAL_FILE="$JOURNAL_DIR/${TIMESTAMP}_iter_$(printf '%03d' $ITERATION).md"

# Extract tool calls from transcript
TOOL_CALLS=$(jq -r '
  select(.message.content) |
  .message.content[] |
  select(.type == "tool_use") |
  "- \(.name): \(.input | tostring | .[0:100])"
' "$TRANSCRIPT_PATH" 2>/dev/null | tail -20 || echo "- No tool calls found")

# Extract assistant text from last message
LAST_RESPONSE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | jq -r '
  .message.content | map(select(.type == "text")) | map(.text) | join("\n")
' 2>/dev/null | head -c 500 || echo "No response captured")

# Check if promise was fulfilled
PROMISE_FOUND="No"
if echo "$LAST_RESPONSE" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
  PROMISE_FOUND="Yes"
fi

# Create journal entry
cat > "$JOURNAL_FILE" <<EOF
# Journal Entry: Iteration $ITERATION
**Timestamp:** $TIMESTAMP
**Loop ID:** $LOOP_ID
**Completion Promise:** $COMPLETION_PROMISE
**Promise Fulfilled:** $PROMISE_FOUND

## 1. The Bigger Picture
$PROMPT

## 2. Tool Calls Made
$TOOL_CALLS

## 3. Final Response
\`\`\`
$LAST_RESPONSE
\`\`\`

## 4. Status
- Iteration: $ITERATION
- Promise detected: $PROMISE_FOUND
EOF

echo "$JOURNAL_FILE"
