---
description: "Explain Ralph Journal system and available commands"
---

# Ralph Journal Plugin Help

Please explain the following to the user:

## What is Ralph Journal?

Ralph Journal is an enhanced version of the Ralph Wiggum technique with a **diary/journal system** for continuous improvement.

**Core concept:** Run Claude in a loop on the same task, with each iteration:
1. Generating a journal entry capturing goals, plans, actions, and learnings
2. Updating context documents (tactical, strategic, skills)
3. Injecting accumulated knowledge into the next iteration

This creates a **learning loop** where Claude improves over iterations by building on past insights.

## Directory Structure

```
.ralph/
├── journal/                    # Diary entries (one per iteration)
│   ├── 2026-01-04T12-00-00_iter_001.md
│   └── ...
├── context/
│   ├── tactical.md             # Current details (≤25KB)
│   ├── strategic.md            # High-level direction (≤25KB)
│   └── state.json              # Processing state
├── skills/
│   └── SKILLS.md               # Learned patterns
└── loop_state.json             # Loop configuration
```

## Journal Entry Format

Each iteration generates a journal with 5 sections:

1. **The Bigger Picture** - Overarching goal context
2. **Iteration Goals** - Specific objectives for this iteration
3. **The Plan** - Approach/strategy decided on
4. **What Actually Happened** - Factual summary of actions
5. **Analysis** - What went well, what went badly, insights

## Available Commands

### /ralph-journal <PROMPT> [OPTIONS]

Start a Ralph Journal loop.

**Options:**
- `--max-iterations <n>` - Max iterations before auto-stop
- `--completion-promise <text>` - Promise phrase to signal completion

**Example:**
```
/ralph-journal "Deploy the API to production" --max-iterations 10 --completion-promise "DEPLOYED"
```

### /cancel-ralph

Cancel an active loop (preserves journal entries).

### /search-journals <query>

Search through journal entries for relevant context.

## Context Documents

### Tactical Context (tactical.md)
- Current blockers and resolutions
- Recent technical decisions
- Error messages and solutions
- Configuration values

### Strategic Context (strategic.md)
- Progress toward high-level goals
- Architectural decisions
- Dependencies and risks
- Timeline implications

### Skills (SKILLS.md)
- Patterns that worked well
- Anti-patterns to avoid
- Useful commands/techniques

## When to Use Ralph Journal

**Good for:**
- Complex multi-step tasks
- Tasks requiring iteration and learning
- Work with external systems (MCP tools)
- Building knowledge over time

**Not good for:**
- Simple one-shot tasks
- Tasks requiring immediate human judgment
- Time-critical operations

## Learn More

- Original Ralph technique: https://ghuntley.com/ralph/
- Based on ralph-wiggum plugin by Daisy Hollman
