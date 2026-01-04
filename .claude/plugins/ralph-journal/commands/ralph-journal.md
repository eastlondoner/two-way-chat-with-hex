---
description: "Start Ralph Journal loop with diary system"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh)"]
hide-from-slash-command-tool: "true"
---

# Ralph Journal Loop Command

Execute the setup script to initialize the Ralph Journal loop:

```!
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh"
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/generate-journal.sh"
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/update-context.sh"
chmod +x "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"

"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS

if [ -f .ralph/loop_state.json ]; then
  PROMISE=$(jq -r '.completion_promise // ""' .ralph/loop_state.json)
  if [ -n "$PROMISE" ] && [ "$PROMISE" != "null" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "📓 RALPH JOURNAL - Completion Promise"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "To complete this loop, output: <promise>$PROMISE</promise>"
    echo ""
    echo "RULES:"
    echo "  ✓ The statement MUST be TRUE"
    echo "  ✓ Do NOT lie to exit the loop"
    echo ""
    echo "JOURNAL FEATURES:"
    echo "  📓 Diary entry generated after each iteration"
    echo "  📊 Tactical context updated with current details"
    echo "  🎯 Strategic context tracks high-level progress"
    echo "  💡 Skills learned from iterations"
    echo "═══════════════════════════════════════════════════════════"
  fi
fi
```

## Enhanced Features

This Ralph loop includes a **journal/diary system** that:

1. **Generates a journal entry** after each iteration with:
   - The bigger picture context
   - Iteration goals
   - The plan you came up with
   - What actually happened
   - Analysis of successes and failures

2. **Updates context documents** automatically:
   - `tactical.md` - Current blockers, recent decisions, technical details
   - `strategic.md` - High-level progress, architectural decisions
   - `SKILLS.md` - Patterns that work, anti-patterns to avoid

3. **Injects context** into each iteration so you have awareness of:
   - What you've learned so far
   - What worked and what didn't
   - Strategic direction

Work on the task. Each iteration, the journal will capture your progress and learnings, helping you improve over time.

CRITICAL: Only output the completion promise when the statement is genuinely TRUE.
