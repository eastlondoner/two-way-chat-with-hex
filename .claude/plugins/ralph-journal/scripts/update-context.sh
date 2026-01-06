#!/bin/bash

# Update Context Documents Script
# Updates tactical and strategic docs from new journal entries
# NOTE: Skills are now extracted as proper Claude Code skills via extract-skills.sh

set -euo pipefail

CONTEXT_TYPE="${1:-all}"  # tactical, strategic, or all
RALPH_DIR="${2:-.ralph}"
MAX_CHARS=25600

JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_DIR="$RALPH_DIR/context"
STATE_FILE="$CONTEXT_DIR/state.json"

# Convert to absolute paths for use after cd
RALPH_DIR=$(cd "$RALPH_DIR" && pwd)
JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_DIR="$RALPH_DIR/context"
STATE_FILE="$CONTEXT_DIR/state.json"

if [[ ! -d "$JOURNAL_DIR" ]]; then
  echo "No journal directory found" >&2
  exit 0
fi

# Get list of journal files sorted by name (timestamp order)
JOURNAL_FILES=$(ls -1 "$JOURNAL_DIR"/*.md 2>/dev/null | sort)
if [[ -z "$JOURNAL_FILES" ]]; then
  echo "No journal entries found" >&2
  exit 0
fi

# Read processing state
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"tactical":{"last_processed_journal":null},"strategic":{"last_processed_journal":null},"skills":{"last_processed_journal":null}}' > "$STATE_FILE"
fi

update_document() {
  local DOC_TYPE="$1"
  local DOC_PATH="$2"
  local PROMPT_FOCUS="$3"

  # Get last processed journal for this doc type
  local LAST_PROCESSED=$(jq -r ".$DOC_TYPE.last_processed_journal // \"\"" "$STATE_FILE")

  # Find new journals to process
  local NEW_JOURNALS=""
  local LATEST_JOURNAL=""
  for f in $JOURNAL_FILES; do
    BASENAME=$(basename "$f")
    if [[ -z "$LAST_PROCESSED" ]] || [[ "$BASENAME" > "$LAST_PROCESSED" ]]; then
      NEW_JOURNALS+="$f "
      LATEST_JOURNAL="$BASENAME"
    fi
  done

  if [[ -z "$NEW_JOURNALS" ]]; then
    echo "[$DOC_TYPE] No new journals to process"
    return 0
  fi

  echo "[$DOC_TYPE] Processing $(echo $NEW_JOURNALS | wc -w) new journal(s)"

  # Read new journal content
  local JOURNAL_CONTENT=""
  for f in $NEW_JOURNALS; do
    JOURNAL_CONTENT+="
--- $(basename $f) ---
$(cat "$f")
"
  done

  # Read current document and calculate size
  local CURRENT_DOC=""
  local CURRENT_SIZE=0
  if [[ -f "$DOC_PATH" ]]; then
    CURRENT_DOC=$(cat "$DOC_PATH")
    CURRENT_SIZE=${#CURRENT_DOC}
  fi
  local REMAINING_CHARS=$((MAX_CHARS - CURRENT_SIZE))

  # Build update prompt
  local UPDATE_PROMPT="You are updating a context document based on new journal entries.

## Document Type: $DOC_TYPE
## Focus: $PROMPT_FOCUS

## Size Constraints
- **Maximum allowed:** $MAX_CHARS characters
- **Current size:** $CURRENT_SIZE characters
- **Remaining capacity:** $REMAINING_CHARS characters
- **Usage:** $((CURRENT_SIZE * 100 / MAX_CHARS))% full

## Current Document Content
\`\`\`markdown
$CURRENT_DOC
\`\`\`

## New Journal Entries to Incorporate
$JOURNAL_CONTENT

## Instructions
1. Read the new journal entries carefully
2. Extract information relevant to this document type ($DOC_TYPE)
3. Update the document to incorporate new insights
4. **SIZE MANAGEMENT IS CRITICAL** (see Size Constraints above):
   - You MUST stay under $MAX_CHARS characters
   - If currently over 50% full, REMOVE older/less relevant content
   - If currently over 75% full, aggressively CONDENSE and DELETE stale content
   - SUMMARIZE verbose sections into concise bullet points
   - PRIORITIZE recent and actionable information over historical details
5. Maintain markdown formatting
6. Output ONLY the updated document content, no preamble

**IMPORTANT: Your output must be under $MAX_CHARS characters. Current document is $CURRENT_SIZE chars ($((CURRENT_SIZE * 100 / MAX_CHARS))% of limit).**

Focus on: $PROMPT_FOCUS"

  # Run update via claude -p
  # Run from /tmp to avoid project context interference
  local TEMP_FILE=$(mktemp)
  (
    unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE \
          CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID \
          CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR \
          CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR

    cd /tmp
    echo "$UPDATE_PROMPT" | timeout 120 claude -p --model sonnet --output-format text > "$TEMP_FILE" 2>/dev/null
  ) || {
    echo "[$DOC_TYPE] Update failed, keeping current document"
    rm -f "$TEMP_FILE"
    return 1
  }

  # Validate output isn't empty
  if [[ ! -s "$TEMP_FILE" ]]; then
    echo "[$DOC_TYPE] Empty output, keeping current document"
    rm -f "$TEMP_FILE"
    return 1
  fi

  # Truncate if needed
  if [[ $(wc -c < "$TEMP_FILE") -gt $MAX_CHARS ]]; then
    head -c $MAX_CHARS "$TEMP_FILE" > "${TEMP_FILE}.trunc"
    mv "${TEMP_FILE}.trunc" "$TEMP_FILE"
    echo "[$DOC_TYPE] Truncated to $MAX_CHARS chars"
  fi

  # Update document
  mv "$TEMP_FILE" "$DOC_PATH"
  echo "[$DOC_TYPE] Updated successfully"

  # Update processing state
  local NEW_STATE=$(jq ".$DOC_TYPE.last_processed_journal = \"$LATEST_JOURNAL\"" "$STATE_FILE")
  echo "$NEW_STATE" > "$STATE_FILE"
}

# Run updates based on context type
case "$CONTEXT_TYPE" in
  tactical)
    update_document "tactical" "$CONTEXT_DIR/tactical.md" \
      "Current blockers, recent decisions, specific technical details, error messages and solutions, configuration values"
    ;;
  strategic)
    update_document "strategic" "$CONTEXT_DIR/strategic.md" \
      "Progress toward high-level goals, architectural decisions, dependencies, risks, timeline implications"
    ;;
  all)
    # Run tactical and strategic updates
    # NOTE: Skills are now extracted separately via extract-skills.sh
    update_document "tactical" "$CONTEXT_DIR/tactical.md" \
      "Current blockers, recent decisions, specific technical details, error messages and solutions"
    update_document "strategic" "$CONTEXT_DIR/strategic.md" \
      "Progress toward high-level goals, architectural decisions, dependencies, risks"
    ;;
  *)
    echo "Unknown context type: $CONTEXT_TYPE" >&2
    echo "Usage: $0 [tactical|strategic|all]" >&2
    exit 1
    ;;
esac

echo "Context update complete"
