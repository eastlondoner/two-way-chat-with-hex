#!/bin/bash

# Ralph Journal PreCompact Hook
# Generates a journal entry before context compaction to preserve insights

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Source portability helpers
source "$PLUGIN_ROOT/scripts/lib/portable.sh"
# Derive project root from plugin path (.claude/plugins/ralph-journal -> project root)
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../../.." && pwd)"
RALPH_DIR="$PROJECT_ROOT/.ralph"

# Change to project directory for consistent relative path handling
cd "$PROJECT_ROOT"

# Read hook input from stdin
HOOK_INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')  # "manual" or "auto"

# Only run if we have a transcript and ralph directory
if [[ ! -f "$TRANSCRIPT_PATH" ]] || [[ ! -d "$RALPH_DIR" ]]; then
  exit 0
fi

mkdir -p "$RALPH_DIR/journal"

TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
JOURNAL_FILE="$RALPH_DIR/journal/${TIMESTAMP}_compaction_${TRIGGER}.md"

# Build the journal generation prompt for compaction
JOURNAL_PROMPT="You are generating a journal entry BEFORE context compaction.

This is important because compaction will summarize/lose detail from the conversation.
Capture any insights, decisions, or learnings that should be preserved.

## Compaction Trigger
$TRIGGER

## Transcript (last 100 messages)
$(tail -100 "$TRANSCRIPT_PATH" | jq -s '
  [.[] | select(.message) | {
    role: .message.role,
    content: (if .message.content then
      [.message.content[] | select(.type == "text") | .text[0:300]]
    else [] end)
  }]
' 2>/dev/null || echo "[]")

## Instructions

Generate a markdown journal entry capturing:

### Key Decisions Made
What decisions were made in this session that should be remembered?

### Important Technical Details
Specific technical information that shouldn't be lost (configs, commands, values).

### Unresolved Questions
What's still unclear or needs investigation?

### Insights for Future Work
What did we learn that should inform future iterations?

Keep it concise (200-400 words). This is a preservation snapshot.
Output ONLY the markdown content.
"

# Generate journal entry
(
  unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE \
        CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID \
        CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR \
        CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR

  echo "$JOURNAL_PROMPT" | portable_timeout 90 claude -p --model sonnet --output-format text > "$JOURNAL_FILE" 2>/dev/null
) || {
  # Fallback if generation fails
  cat > "$JOURNAL_FILE" <<EOF
# Compaction Snapshot
**Timestamp:** $TIMESTAMP
**Trigger:** $TRIGGER

*Journal generation failed - manual review of session recommended*
EOF
}

# Add header
if ! grep -q "^# " "$JOURNAL_FILE" 2>/dev/null; then
  TEMP=$(mktemp)
  echo "# Pre-Compaction Journal" > "$TEMP"
  echo "**Timestamp:** $TIMESTAMP" >> "$TEMP"
  echo "**Trigger:** $TRIGGER" >> "$TEMP"
  echo "" >> "$TEMP"
  cat "$JOURNAL_FILE" >> "$TEMP"
  mv "$TEMP" "$JOURNAL_FILE"
fi

echo "📓 Pre-compaction journal saved: $(basename "$JOURNAL_FILE")"

# Update context documents with new journal entry (logs to .ralph/logs/context.log)
"$PLUGIN_ROOT/scripts/update-context.sh" all "$RALPH_DIR" || true

# Extract skills from journals (logs to .ralph/logs/skills.log)
"$PLUGIN_ROOT/scripts/extract-skills.sh" "$RALPH_DIR" "$PROJECT_ROOT/.claude/skills" || true

# Allow compaction to proceed
echo '{"continue": true}'
exit 0
