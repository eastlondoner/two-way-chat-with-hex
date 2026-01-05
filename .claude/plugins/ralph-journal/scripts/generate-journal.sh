#!/bin/bash

# Generate Journal Entry Script
# Called by stop hook to create a diary entry for the iteration

set -euo pipefail

# Arguments
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

# Convert to absolute paths for use after cd
JOURNAL_DIR=$(cd "$JOURNAL_DIR" && pwd)

# Read loop state
LOOP_ID=$(jq -r '.loop_id' "$LOOP_STATE_PATH")
ITERATION=$(jq -r '.iteration' "$LOOP_STATE_PATH")
PROMPT=$(jq -r '.prompt' "$LOOP_STATE_PATH")
COMPLETION_PROMISE=$(jq -r '.completion_promise // "none"' "$LOOP_STATE_PATH")

TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
JOURNAL_FILE="$JOURNAL_DIR/${TIMESTAMP}_iter_$(printf '%03d' $ITERATION).md"

# Extract transcript content for the prompt
# Get last N lines of transcript to keep prompt manageable
TRANSCRIPT_EXCERPT=$(tail -100 "$TRANSCRIPT_PATH" | jq -s '
  [.[] | select(.message.role == "assistant" or .message.role == "user") |
   {
     role: .message.role,
     content: (if .message.content then
       [.message.content[] | select(.type == "text" or .type == "tool_use") |
        if .type == "text" then {type: "text", text: .text[0:500]}
        elif .type == "tool_use" then {type: "tool", name: .name, input: (.input | tostring[0:200])}
        else . end
       ]
     else [] end)
   }
  ]
' 2>/dev/null || echo "[]")

# Build the journal generation prompt
JOURNAL_PROMPT=$(cat <<'PROMPT_EOF'
You are generating a journal entry for a Ralph loop iteration. This is a diary/journal, not a log - focus on insights and learnings, not exhaustive details.

## Loop Context
PROMPT_EOF
)

JOURNAL_PROMPT+="
- **Loop ID**: $LOOP_ID
- **Iteration**: $ITERATION
- **Original Task**: $PROMPT
- **Completion Promise**: $COMPLETION_PROMISE

## Recent Transcript Activity
$TRANSCRIPT_EXCERPT

## Instructions

Generate a markdown journal entry with these 5 sections:

### 1. The Bigger Picture
What overarching goal is this iteration part of? What's the end state we're working toward? (2-3 sentences)

### 2. Iteration Goals
What specific objectives were set for THIS iteration? Use a checkbox list.

### 3. The Plan
What approach/strategy was decided on? Brief numbered steps.

### 4. What Actually Happened
Factual summary of actions taken and results. Include:
- Key actions taken (checkmarks for success, X for failure)
- Any tool calls made (especially MCP tools)
- Errors encountered

### 5. Analysis
What went well, what went badly, and insights for the next iteration.
- ✅ Went Well: (bullet points)
- ❌ Went Badly: (bullet points)
- 💡 Insights: (bullet points)

Keep it concise but insightful. Total length should be 300-500 words.
Output ONLY the markdown content, no preamble.
"

# Generate journal entry using claude -p
# Unset env vars and run from /tmp to avoid project context interference
(
  unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE \
        CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID \
        CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR \
        CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR

  cd /tmp
  echo "$JOURNAL_PROMPT" | timeout 60 claude -p --model haiku --output-format text > "$JOURNAL_FILE" 2>/dev/null
) || {
  # Fallback if claude -p fails - create minimal journal
  cat > "$JOURNAL_FILE" <<EOF
# Journal Entry: Iteration $ITERATION
**Timestamp:** $TIMESTAMP
**Loop ID:** $LOOP_ID

## 1. The Bigger Picture
$PROMPT

## 2. Iteration Goals
- Work on the task

## 3. The Plan
Continue working on the task.

## 4. What Actually Happened
*(Journal generation failed - this is a placeholder)*

## 5. Analysis
- Journal generation encountered an error
- Manual review of transcript recommended
EOF
}

# Add header to journal if not present
if ! grep -q "^# Journal Entry" "$JOURNAL_FILE" 2>/dev/null; then
  TEMP_FILE=$(mktemp)
  echo "# Journal Entry: Iteration $ITERATION" > "$TEMP_FILE"
  echo "**Timestamp:** $TIMESTAMP" >> "$TEMP_FILE"
  echo "**Loop ID:** $LOOP_ID" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  cat "$JOURNAL_FILE" >> "$TEMP_FILE"
  mv "$TEMP_FILE" "$JOURNAL_FILE"
fi

echo "$JOURNAL_FILE"
