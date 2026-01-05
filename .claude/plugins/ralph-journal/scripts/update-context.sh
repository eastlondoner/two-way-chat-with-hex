#!/bin/bash

# Update Context Documents Script
# Updates tactical, strategic, and skills docs from new journal entries

set -euo pipefail

CONTEXT_TYPE="${1:-all}"  # tactical, strategic, skills, or all
RALPH_DIR="${2:-.ralph}"
MAX_CHARS=25600

JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_DIR="$RALPH_DIR/context"
SKILLS_DIR="$RALPH_DIR/skills"
STATE_FILE="$CONTEXT_DIR/state.json"

# Convert to absolute paths for use after cd
RALPH_DIR=$(cd "$RALPH_DIR" && pwd)
JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_DIR="$RALPH_DIR/context"
SKILLS_DIR="$RALPH_DIR/skills"
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

  # Read current document
  local CURRENT_DOC=""
  if [[ -f "$DOC_PATH" ]]; then
    CURRENT_DOC=$(cat "$DOC_PATH")
  fi

  # Build update prompt
  local UPDATE_PROMPT="You are updating a context document based on new journal entries.

## Document Type: $DOC_TYPE
## Focus: $PROMPT_FOCUS

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
4. Keep the document under $MAX_CHARS characters
5. Use summarization to stay within limits - older/less relevant info can be condensed
6. Maintain markdown formatting
7. Output ONLY the updated document content, no preamble

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
  skills)
    update_document "skills" "$SKILLS_DIR/SKILLS.md" \
      "Reusable patterns that worked, anti-patterns to avoid, useful commands, lessons learned"
    ;;
  all)
    # Run all updates (could be parallelized but keeping simple for now)
    update_document "tactical" "$CONTEXT_DIR/tactical.md" \
      "Current blockers, recent decisions, specific technical details, error messages and solutions"
    update_document "strategic" "$CONTEXT_DIR/strategic.md" \
      "Progress toward high-level goals, architectural decisions, dependencies, risks"
    update_document "skills" "$SKILLS_DIR/SKILLS.md" \
      "Reusable patterns that worked, anti-patterns to avoid, useful commands, lessons learned"
    ;;
  *)
    echo "Unknown context type: $CONTEXT_TYPE" >&2
    echo "Usage: $0 [tactical|strategic|skills|all]" >&2
    exit 1
    ;;
esac

echo "Context update complete"
