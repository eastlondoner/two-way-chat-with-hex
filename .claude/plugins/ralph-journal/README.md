# Ralph Journal Plugin

Enhanced Ralph Wiggum technique with a diary/journal system for continuous improvement.

## Installation

### Option 1: Install from vibe-plugins marketplace (Recommended)

```bash
# Inside Claude Code
/plugin install ralph-journal@vibe-plugins
```

### Option 2: Load directly with --plugin-dir

```bash
# When starting Claude Code
claude --plugin-dir /path/to/.claude/plugins/ralph-journal
```

### Option 3: Copy to another project

1. Copy the entire plugin directory:
   ```bash
   cp -r .claude/plugins/ralph-journal /path/to/other/project/.claude/plugins/
   ```

2. Enable the plugin in the target project's `.claude/settings.json`:
   ```json
   {
     "enabledPlugins": {
       "ralph-journal": true
     }
   }
   ```

### Option 4: Enable in current project

Add to your `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ralph-journal": true
  }
}
```

The plugin will be loaded automatically when Claude Code starts.

## Overview

Ralph Journal extends the original Ralph Wiggum technique (continuous self-referential AI loops) with:

- **Journal entries** - Diary entry generated after each iteration
- **Tactical context** - Current blockers, decisions, technical details (≤25KB)
- **Strategic context** - High-level direction, architectural decisions (≤25KB)
- **Claude Code Skills** - Learned patterns extracted as `.claude/skills/` (persistent across sessions!)
- **Searchable history** - Query past iterations for relevant context

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-journal <prompt>` | Start a Ralph loop with journal system |
| `/cancel-ralph` | Cancel active loop (preserves journals) |
| `/search-journals <query>` | Search journal history |
| `/help` | Show help and documentation |

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
| `-s, --case-sensitive` | Make search case-sensitive (default: case-insensitive) |
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
│   ├── 2026-01-04T12-10-00_compaction_auto.md   # Pre-compaction snapshot
│   └── ...
├── context/
│   ├── tactical.md             # Current goals/details
│   ├── strategic.md            # High-level direction
│   └── state.json              # Processing state
├── logs/                       # Diagnostic logs (see LOGGING.md)
├── agents/                     # Reserved for future multi-agent coordination
└── loop_state.json             # Loop configuration

.claude/skills/                 # Claude Code skills (AUTO-LOADED!)
├── database-migrations/
│   └── SKILL.md
├── error-handling-patterns/
│   └── SKILL.md
└── ...                         # Skills persist across all sessions
```

### Version Control

The `.ralph/` directory can be committed to source control depending on your workflow:

**Commit `.ralph/` when:**
- You want to preserve learning history across sessions and team members
- Journal entries contain valuable project documentation
- You're using Ralph for long-running projects where context matters

**Add `.ralph/` to `.gitignore` when:**
- Journals contain sensitive or temporary information
- You prefer fresh context each session
- Storage size is a concern (journals can accumulate)

**Recommended `.gitignore` entries if excluding:**
```
.ralph/journal/
.ralph/logs/
.ralph/loop_state.json
# Keep context documents if desired:
# !.ralph/context/
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
│     b. Updates tactical/strategic context documents            │
│     c. Extracts skills → .claude/skills/ (PERSISTENT!)         │
│     d. Checks for completion promise                           │
│     e. If not complete: re-inject prompt + context             │
│  4. Next iteration sees accumulated knowledge                  │
│  5. Skills auto-loaded in ALL future Claude sessions           │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼  (repeat until promise fulfilled or max iterations)
```

## Hooks

### Stop Hook
- Generates journal entry after each iteration
- Updates tactical/strategic context documents
- **Extracts skills** as Claude Code skill files (`.claude/skills/`)
- Checks for completion promise
- Re-injects prompt with accumulated context

### Pre-Compact Hook

Fires when Claude's context is about to be compacted (summarized to free up space). Context compaction happens automatically when:
- The conversation exceeds Claude's context window limits
- Memory pressure requires summarizing older messages to continue working
- Users can also trigger compaction manually via `/compact`

See [docs/HOOK_INPUT_FORMAT.md](docs/HOOK_INPUT_FORMAT.md) for the exact hook payload format.

**What it does:**
- **Generates a compaction journal** - Named `{timestamp}_compaction_{trigger}.md`
  - Triggers: `auto` (context limit), `manual` (user `/compact`), or `unknown` (default fallback)
- **Captures key decisions** - Preserves important technical details before they're summarized away
- **Records unresolved questions** - Documents what still needs investigation
- **Updates context documents** - Refreshes tactical/strategic context with latest insights
- **Extracts skills** - Saves any new patterns as Claude Code skills

This ensures valuable insights aren't lost when the conversation gets too long and Claude compacts its context.

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

## Claude Code Skills (Persistent!)

Unlike the context documents which are loop-specific, skills are extracted as **proper Claude Code skills** in `.claude/skills/`. This means:

- **Auto-loaded**: Claude automatically uses these skills in ALL future sessions
- **Persistent**: Skills survive after the Ralph loop ends
- **Reusable**: Skills apply across different tasks and projects
- **Standard format**: Uses Claude Code's native skill format

### How Skill Extraction Works

After each iteration:
1. Journal entries are analyzed for reusable patterns
2. **Existing skills are checked** (full content + frontmatter) to avoid duplicates
3. The system decides whether to:
   - **CREATE** new skills for genuinely new patterns
   - **UPDATE** existing skills with additional information
   - **DO NOTHING** if no changes are needed
4. Skills are automatically available in future Claude sessions

### Skill Deduplication

The extraction prompt receives full information about existing skills:
- Skill name and path
- Complete frontmatter (name, description)
- Full skill content

This prevents creating duplicate skills and encourages enriching existing skills with new learnings.

### Example Skills That Might Be Created/Updated

- `database-migrations` - How to handle schema changes in this project
- `testing-patterns` - Testing conventions discovered (updated as new patterns emerge)
- `error-handling` - Error handling approaches that worked
- `git-workflow` - Git workflow for this team/project

## Troubleshooting

Diagnostic logs are written to `.ralph/logs/` for debugging:

```bash
# View skill extraction activity
tail -f .ralph/logs/skills.log

# View context update operations
tail -f .ralph/logs/context.log

# View all logs
tail -f .ralph/logs/*.log
```

See [LOGGING.md](LOGGING.md) for details.

## Requirements

- Claude Code CLI (`claude` command available)
- `jq` for JSON processing
- Bash shell

## Credits

Based on the Ralph Wiggum technique by Geoffrey Huntley and the ralph-wiggum plugin by Daisy Hollman.

- Original technique: https://ghuntley.com/ralph/
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator
