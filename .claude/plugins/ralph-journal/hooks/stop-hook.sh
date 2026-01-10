#!/bin/bash

# Ralph Journal Stop Hook
# Enhanced stop hook that generates journal entries and updates context

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Derive project root from plugin path (.claude/plugins/ralph-journal -> project root)
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../../.." && pwd)"
RALPH_DIR="$PROJECT_ROOT/.ralph"
STATE_FILE="$RALPH_DIR/loop_state.json"

# Change to project directory for consistent relative path handling
cd "$PROJECT_ROOT"

# Read hook input from stdin and log it for debugging
# The debug script logs to /tmp/hook-debug.log and passes input through unchanged
if [[ -x "$PLUGIN_ROOT/scripts/debug-hook-input.sh" ]]; then
  HOOK_INPUT=$(cat | "$PLUGIN_ROOT/scripts/debug-hook-input.sh")
else
  HOOK_INPUT=$(cat)
fi

# Parse stop_hook_active flag (true when continuing from previous stop hook block)
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false')

if [[ "${RALPH_DEBUG:-}" == "1" ]]; then
  echo "[stop-hook] stop_hook_active=$STOP_HOOK_ACTIVE" >&2
fi

# Check if Ralph loop is active
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

ACTIVE=$(jq -r '.active' "$STATE_FILE")
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Parse loop state
ITERATION=$(jq -r '.iteration' "$STATE_FILE")
MAX_ITERATIONS=$(jq -r '.max_iterations' "$STATE_FILE")
COMPLETION_PROMISE=$(jq -r '.completion_promise // ""' "$STATE_FILE")
PROMPT=$(jq -r '.prompt' "$STATE_FILE")
LOOP_ID=$(jq -r '.loop_id' "$STATE_FILE")

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph Journal: State file corrupted, stopping loop" >&2
  jq '.active = false | .error = "corrupted_state"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  exit 0
fi

# Debug logging for iteration info
if [[ "${RALPH_DEBUG:-}" == "1" ]]; then
  echo "[stop-hook] stop_hook_active=$STOP_HOOK_ACTIVE iteration=$ITERATION max_iterations=$MAX_ITERATIONS" >&2
fi

# Get transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph Journal: Transcript not found, stopping loop" >&2
  jq '.active = false | .error = "no_transcript"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 1: Check for Completion Promise
# ═══════════════════════════════════════════════════════════════════

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # Get last assistant message
  LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | jq -r '
    .message.content | map(select(.type == "text")) | map(.text) | join("\n")
  ' 2>/dev/null || echo "")

  # Check for promise tag
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph Journal: Promise fulfilled - <promise>$COMPLETION_PROMISE</promise>"

    # Generate final journal entry
    "$PLUGIN_ROOT/scripts/generate-journal.sh" "$TRANSCRIPT_PATH" "$STATE_FILE" "$RALPH_DIR/journal" || true

    # Update context one last time
    "$PLUGIN_ROOT/scripts/update-context.sh" all "$RALPH_DIR" || true

    # Extract skills one last time
    "$PLUGIN_ROOT/scripts/extract-skills.sh" "$RALPH_DIR" "$PROJECT_ROOT/.claude/skills" || true

    # Mark loop complete
    jq '.active = false | .completed = true | .completed_at = now' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 2: Check Max Iterations
# ═══════════════════════════════════════════════════════════════════

if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  # ═══════════════════════════════════════════════════════════════════
  # RECURSION SAFETY: If stop_hook_active=true, we're in a reinjection
  # cycle and must exit after cleanup to prevent infinite loops
  # ═══════════════════════════════════════════════════════════════════
  if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
    echo "🛑 Ralph Journal: Max iterations ($MAX_ITERATIONS) reached during reinjection (recursion safety)" >&2
  else
    echo "🛑 Ralph Journal: Max iterations ($MAX_ITERATIONS) reached"
  fi

  # Generate final journal entry
  "$PLUGIN_ROOT/scripts/generate-journal.sh" "$TRANSCRIPT_PATH" "$STATE_FILE" "$RALPH_DIR/journal" || true

  # Update context one last time
  "$PLUGIN_ROOT/scripts/update-context.sh" all "$RALPH_DIR" || true

  # Extract skills one last time
  "$PLUGIN_ROOT/scripts/extract-skills.sh" "$RALPH_DIR" "$PROJECT_ROOT/.claude/skills" || true

  # Mark loop complete
  jq '.active = false | .reason = "max_iterations"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 3: Generate Journal Entry for This Iteration
# ═══════════════════════════════════════════════════════════════════

echo "📓 Generating journal entry for iteration $ITERATION..."
JOURNAL_FILE=$("$PLUGIN_ROOT/scripts/generate-journal.sh" "$TRANSCRIPT_PATH" "$STATE_FILE" "$RALPH_DIR/journal" 2>/dev/null || echo "")

if [[ -n "$JOURNAL_FILE" ]] && [[ -f "$JOURNAL_FILE" ]]; then
  echo "📓 Journal saved: $(basename "$JOURNAL_FILE")"
else
  echo "⚠️  Journal generation skipped"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 4: Update Context Documents
# ═══════════════════════════════════════════════════════════════════

echo "📚 Updating context documents..."
"$PLUGIN_ROOT/scripts/update-context.sh" all "$RALPH_DIR" || echo "⚠️  Context update encountered issues"

# ═══════════════════════════════════════════════════════════════════
# STEP 4b: Extract Skills as Claude Code Skills
# ═══════════════════════════════════════════════════════════════════

echo "🧠 Extracting skills from journals..."
"$PLUGIN_ROOT/scripts/extract-skills.sh" "$RALPH_DIR" "$PROJECT_ROOT/.claude/skills" || echo "⚠️  Skill extraction encountered issues"

# ═══════════════════════════════════════════════════════════════════
# STEP 5: Prepare Next Iteration
# ═══════════════════════════════════════════════════════════════════

NEXT_ITERATION=$((ITERATION + 1))

# Update iteration count
jq ".iteration = $NEXT_ITERATION" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Read context documents for injection
TACTICAL=""
STRATEGIC=""

if [[ -f "$RALPH_DIR/context/tactical.md" ]]; then
  TACTICAL=$(cat "$RALPH_DIR/context/tactical.md")
fi

if [[ -f "$RALPH_DIR/context/strategic.md" ]]; then
  STRATEGIC=$(cat "$RALPH_DIR/context/strategic.md")
fi

# Count extracted skills for display
SKILL_COUNT=0
if [[ -d "$PROJECT_ROOT/.claude/skills" ]]; then
  SKILL_COUNT=$(find "$PROJECT_ROOT/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# Build enhanced prompt with context
# NOTE: Skills are now auto-loaded by Claude from .claude/skills/ directory
ENHANCED_PROMPT="$PROMPT

---
## 🔄 Ralph Journal - Iteration $NEXT_ITERATION of $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo '∞'; fi)

### Strategic Context
$STRATEGIC

### Tactical Context
$TACTICAL

---
**Previous iteration journal:** $(basename "$JOURNAL_FILE" 2>/dev/null || echo "none")
**Skills learned:** $SKILL_COUNT skill(s) extracted to .claude/skills/ (auto-loaded)
**To complete:** Output <promise>$COMPLETION_PROMISE</promise> when the task is genuinely complete.
"

# Build system message
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | To complete: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | No completion promise - loop runs indefinitely"
fi

# Output JSON to block stop and continue loop
jq -n \
  --arg prompt "$ENHANCED_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0