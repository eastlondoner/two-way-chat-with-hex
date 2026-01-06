#!/bin/bash

# Hook Input Debug Logger
# Logs all hook inputs to /tmp/hook-debug.log for analysis
#
# Usage:
#   1. Source this script in any hook to log its input
#   2. Or pipe hook input through it: cat | ./debug-hook-input.sh | <your-processing>
#
# The script reads stdin, logs it, and outputs it unchanged so it can be used
# in a pipeline without affecting the hook's behavior.

DEBUG_LOG="/tmp/hook-debug.log"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract key fields for the log header
HOOK_EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // "unknown"' 2>/dev/null)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

# Log entry separator
{
  echo "═══════════════════════════════════════════════════════════════════"
  echo "[$TIMESTAMP] Hook Event: $HOOK_EVENT | Session: ${SESSION_ID:0:8}..."
  echo "───────────────────────────────────────────────────────────────────"

  # Pretty print the full JSON
  echo "$HOOK_INPUT" | jq '.' 2>/dev/null || echo "$HOOK_INPUT"

  # Also show transcript file size if present
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
    SIZE=$(ls -lh "$TRANSCRIPT_PATH" 2>/dev/null | awk '{print $5}')
    echo "───────────────────────────────────────────────────────────────────"
    echo "Transcript: $TRANSCRIPT_PATH"
    echo "  Lines: $LINES | Size: $SIZE"
  fi

  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
} >> "$DEBUG_LOG"

# Output the input unchanged so it can be piped
echo "$HOOK_INPUT"
