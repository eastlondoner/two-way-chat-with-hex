---
description: "Start Ralph Journal loop with diary system"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash"]
---

# Ralph Journal Loop Command

Execute the setup script to initialize the Ralph Journal loop:

```!
PLUGIN_DIR=".claude/plugins/ralph-journal"

chmod +x "$PLUGIN_DIR/scripts/setup-ralph-loop.sh"
chmod +x "$PLUGIN_DIR/scripts/generate-journal.sh"
chmod +x "$PLUGIN_DIR/scripts/update-context.sh"
chmod +x "$PLUGIN_DIR/hooks/stop-hook.sh"
chmod +x "$PLUGIN_DIR/hooks/pre-compact.sh"

"$PLUGIN_DIR/scripts/setup-ralph-loop.sh" $ARGUMENTS

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

# Inject existing context if available
# NOTE: Skills are now in .claude/skills/ and auto-loaded by Claude
for ctx_file in .ralph/context/strategic.md .ralph/context/tactical.md; do
  if [[ -f "$ctx_file" ]]; then
    echo ""
    echo "<ralph_context source=\"$ctx_file\">"
    cat "$ctx_file"
    echo "</ralph_context>"
  fi
done

# Show skill count (skills are auto-loaded, not injected)
SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [[ "$SKILL_COUNT" -gt 0 ]]; then
  echo ""
  echo "📚 $SKILL_COUNT learned skill(s) available in .claude/skills/ (auto-loaded by Claude)"
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

3. **Extracts reusable skills** as Claude Code skills:
   - Skills saved to `.claude/skills/skill-name/SKILL.md`
   - Auto-loaded by Claude in ALL future sessions
   - Persistent learning that survives beyond this loop!

4. **Injects context** into each iteration so you have awareness of:
   - What you've learned so far
   - What worked and what didn't
   - Strategic direction

Work on the task. Each iteration, the journal will capture your progress and skills will be extracted for future use.

CRITICAL: Only output the completion promise when the statement is genuinely TRUE.
