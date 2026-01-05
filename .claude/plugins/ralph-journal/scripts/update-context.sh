#!/bin/bash

# Update Context Documents Script - Simple Version
# Updates context docs by appending info from journals (no AI calls)

set -euo pipefail

CONTEXT_TYPE="${1:-all}"
RALPH_DIR="${2:-.ralph}"
MAX_CHARS=25600

JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_DIR="$RALPH_DIR/context"
SKILLS_DIR="$RALPH_DIR/skills"
STATE_FILE="$CONTEXT_DIR/state.json"

if [[ ! -d "$JOURNAL_DIR" ]]; then
  echo "No journal directory found" >&2
  exit 0
fi

# Get list of journal files sorted by name
JOURNAL_FILES=$(ls -1 "$JOURNAL_DIR"/*.md 2>/dev/null | sort)
if [[ -z "$JOURNAL_FILES" ]]; then
  echo "No journal entries found" >&2
  exit 0
fi

# Read processing state
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"tactical":{"last_processed_journal":null},"strategic":{"last_processed_journal":null},"skills":{"last_processed_journal":null}}' > "$STATE_FILE"
fi

update_tactical() {
  local LAST_PROCESSED=$(jq -r '.tactical.last_processed_journal // ""' "$STATE_FILE")
  local TACTICAL_FILE="$CONTEXT_DIR/tactical.md"

  # Find new journals
  local NEW_CONTENT=""
  local LATEST=""
  for f in $JOURNAL_FILES; do
    local BASENAME=$(basename "$f")
    if [[ -z "$LAST_PROCESSED" ]] || [[ "$BASENAME" > "$LAST_PROCESSED" ]]; then
      # Extract tool calls and status from journal
      local TOOLS=$(grep -A20 "## 2. Tool Calls" "$f" 2>/dev/null | head -15 || echo "")
      if [[ -n "$TOOLS" ]]; then
        NEW_CONTENT+="### From $BASENAME
$TOOLS

"
      fi
      LATEST="$BASENAME"
    fi
  done

  if [[ -z "$NEW_CONTENT" ]]; then
    echo "[tactical] No new journals to process"
    return 0
  fi

  # Append to tactical (with size limit)
  if [[ -f "$TACTICAL_FILE" ]]; then
    local CURRENT=$(cat "$TACTICAL_FILE")
    local UPDATED="$CURRENT

## Recent Activity
$NEW_CONTENT"
    # Truncate if needed
    echo "$UPDATED" | head -c $MAX_CHARS > "$TACTICAL_FILE"
  else
    echo "# Tactical Context
## Recent Activity
$NEW_CONTENT" > "$TACTICAL_FILE"
  fi

  # Update state
  jq ".tactical.last_processed_journal = \"$LATEST\"" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "[tactical] Updated with $(echo "$NEW_CONTENT" | wc -l) lines"
}

update_strategic() {
  local LAST_PROCESSED=$(jq -r '.strategic.last_processed_journal // ""' "$STATE_FILE")
  local STRATEGIC_FILE="$CONTEXT_DIR/strategic.md"

  local NEW_CONTENT=""
  local LATEST=""
  for f in $JOURNAL_FILES; do
    local BASENAME=$(basename "$f")
    if [[ -z "$LAST_PROCESSED" ]] || [[ "$BASENAME" > "$LAST_PROCESSED" ]]; then
      # Extract the bigger picture from journal
      local PICTURE=$(grep -A5 "## 1. The Bigger Picture" "$f" 2>/dev/null | tail -4 || echo "")
      if [[ -n "$PICTURE" ]]; then
        NEW_CONTENT+="- $BASENAME: $(echo "$PICTURE" | tr '\n' ' ' | head -c 200)
"
      fi
      LATEST="$BASENAME"
    fi
  done

  if [[ -z "$NEW_CONTENT" ]]; then
    echo "[strategic] No new journals to process"
    return 0
  fi

  if [[ -f "$STRATEGIC_FILE" ]]; then
    local CURRENT=$(cat "$STRATEGIC_FILE")
    local UPDATED="$CURRENT

## Progress Log
$NEW_CONTENT"
    echo "$UPDATED" | head -c $MAX_CHARS > "$STRATEGIC_FILE"
  else
    echo "# Strategic Context
## Progress Log
$NEW_CONTENT" > "$STRATEGIC_FILE"
  fi

  jq ".strategic.last_processed_journal = \"$LATEST\"" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "[strategic] Updated"
}

update_skills() {
  local LAST_PROCESSED=$(jq -r '.skills.last_processed_journal // ""' "$STATE_FILE")
  local SKILLS_FILE="$SKILLS_DIR/SKILLS.md"

  local NEW_CONTENT=""
  local LATEST=""
  for f in $JOURNAL_FILES; do
    local BASENAME=$(basename "$f")
    if [[ -z "$LAST_PROCESSED" ]] || [[ "$BASENAME" > "$LAST_PROCESSED" ]]; then
      # Check if promise was fulfilled
      if grep -q "Promise Fulfilled.*Yes" "$f" 2>/dev/null; then
        NEW_CONTENT+="- Success in $BASENAME
"
      fi
      LATEST="$BASENAME"
    fi
  done

  if [[ -z "$NEW_CONTENT" ]]; then
    echo "[skills] No new journals to process"
    return 0
  fi

  if [[ -f "$SKILLS_FILE" ]]; then
    echo "
## Successful Iterations
$NEW_CONTENT" >> "$SKILLS_FILE"
  else
    echo "# Learned Skills
## Successful Iterations
$NEW_CONTENT" > "$SKILLS_FILE"
  fi

  jq ".skills.last_processed_journal = \"$LATEST\"" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "[skills] Updated"
}

case "$CONTEXT_TYPE" in
  tactical) update_tactical ;;
  strategic) update_strategic ;;
  skills) update_skills ;;
  all)
    update_tactical
    update_strategic
    update_skills
    ;;
  *) echo "Unknown context type: $CONTEXT_TYPE" >&2; exit 1 ;;
esac

echo "Context update complete"
