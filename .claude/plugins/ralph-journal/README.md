# Ralph Journal Plugin

Enhanced Ralph Wiggum technique with a diary/journal system for continuous improvement.

## Overview

Ralph Journal extends the original Ralph Wiggum technique (continuous self-referential AI loops) with:

- **Journal entries** - Diary entry generated after each iteration
- **Tactical context** - Current blockers, decisions, technical details (≤25KB)
- **Strategic context** - High-level direction, architectural decisions (≤25KB)
- **Skills learned** - Patterns that work, anti-patterns to avoid
- **Searchable history** - Query past iterations for relevant context

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-journal <prompt>` | Start a Ralph loop with journal system |
| `/cancel-ralph` | Cancel active loop (preserves journals) |
| `/search-journals <query>` | Search journal history |
| `/ralph-journal:help` | Show help and documentation |

## Usage

```bash
# Basic usage
/ralph-journal "Deploy the API to production" --max-iterations 10

# With completion promise
/ralph-journal "Fix the auth bug" --completion-promise "ALL TESTS PASS" --max-iterations 20

# Search past iterations
/search-journals "How did we handle the timeout issue?"
```

## Searching Journals

The `/search-journals` command provides powerful search capabilities across all journal entries.

### Basic Usage

```bash
# Simple keyword search
/search-journals "database timeout"

# Search with more context lines
/search-journals "API error" --context 5

# Just list matching files
/search-journals "deploy" --list-only

# Show more results
/search-journals "kubernetes" --max-results 20

# Case-sensitive search
/search-journals "ERROR" --case-sensitive
```

### Search Options

| Option | Description |
|--------|-------------|
| `-c, --context N` | Lines of context around matches (default: 3) |
| `-n, --max-results N` | Maximum matching files to show (default: 10) |
| `-i, --case-sensitive` | Make search case-sensitive (default: case-insensitive) |
| `-l, --list-only` | Only list matching files, don't show content |
| `-d, --dir DIR` | Ralph directory (default: .ralph) |

### What to Search For

- **Past solutions**: "How did we handle the timeout issue?"
- **Configuration**: "What configuration worked for staging?"
- **Blockers**: "What were the blockers in previous attempts?"
- **Skills learned**: "What skills did we learn about Kubernetes?"
- **Error messages**: Search for specific error text to find past resolutions

### Output Format

Search results include:
- Total matches found across journals
- For each matching journal:
  - Iteration number and date
  - Matching lines with context
  - File location

## Directory Structure

```
.ralph/
├── journal/                    # One file per iteration
│   ├── 2026-01-04T12-00-00_iter_001.md
│   ├── 2026-01-04T12-05-00_iter_002.md
│   └── ...
├── context/
│   ├── tactical.md             # Current goals/details
│   ├── strategic.md            # High-level direction
│   └── state.json              # Processing state
├── skills/
│   └── SKILLS.md               # Learned capabilities
└── loop_state.json             # Loop configuration
```

## Journal Entry Format

Each iteration generates a journal with 5 sections:

1. **The Bigger Picture** - Overarching goal context
2. **Iteration Goals** - Specific objectives for this iteration
3. **The Plan** - Approach/strategy decided on
4. **What Actually Happened** - Factual summary of actions
5. **Analysis** - What went well, what went badly, insights

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  /ralph-journal "Deploy API" --max-iterations 10                │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  ITERATION N                                                    │
│                                                                 │
│  1. Claude works on task (uses MCP tools, writes files, etc.)  │
│  2. Claude tries to exit                                       │
│  3. Stop hook intercepts:                                      │
│     a. Generates journal entry for this iteration              │
│     b. Updates tactical/strategic/skills context               │
│     c. Checks for completion promise                           │
│     d. If not complete: re-inject prompt + context             │
│  4. Next iteration sees accumulated knowledge                  │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼  (repeat until promise fulfilled or max iterations)
```

## Hooks

### Stop Hook
- Generates journal entry after each iteration
- Updates context documents
- Checks for completion promise
- Re-injects prompt with accumulated context

### PreCompact Hook
- Generates journal entry before context compaction
- Preserves insights that would otherwise be lost
- Updates context documents

## Context Documents

### Tactical Context (25KB max)
- Current blockers and how they were resolved
- Recent technical decisions
- Error messages and solutions
- Configuration values discovered

### Strategic Context (25KB max)
- Progress toward high-level goals
- Architectural decisions and rationale
- Dependencies discovered
- Risks and considerations

### Skills (learned over time)
- Patterns that work well
- Anti-patterns to avoid
- Useful commands and techniques

## Requirements

- Claude Code CLI (`claude` command available)
- `jq` for JSON processing
- Bash shell

## Credits

Based on the Ralph Wiggum technique by Geoffrey Huntley and the ralph-wiggum plugin by Daisy Hollman.

- Original technique: https://ghuntley.com/ralph/
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator
