#!/bin/bash

# Ralph Journal Loop Setup Script
# Creates state file and initializes journal directory for enhanced Ralph loop

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Journal Loop - Interactive self-referential development with learning

USAGE:
  /ralph-journal [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Enhanced Ralph loop with journal/diary system for continuous improvement.

  Features:
  - Journal entry generated after each iteration
  - Tactical context document (current goals, recent details)
  - Strategic context document (high-level direction)
  - Skills learned from iterations
  - Searchable journal history

STRUCTURE:
  .ralph/
  ├── journal/              # One markdown file per iteration
  ├── context/
  │   ├── tactical.md       # Current goals detail (≤25KB)
  │   ├── strategic.md      # High-level direction (≤25KB)
  │   └── state.json        # Processing state
  └── loop_state.json       # Current loop state

  .claude/skills/           # Claude Code skills (auto-loaded)
  └── skill-name/
      └── SKILL.md          # Learned skill (persistent!)

EXAMPLES:
  /ralph-journal Deploy the API --completion-promise 'DEPLOYED' --max-iterations 20
  /ralph-journal Fix auth bug --max-iterations 10
  /ralph-journal Refactor cache layer --completion-promise 'ALL TESTS PASS'

MONITORING:
  cat .ralph/loop_state.json
  ls -la .ralph/journal/
  cat .ralph/context/tactical.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"

if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "   Usage: /ralph-journal <PROMPT> [OPTIONS]" >&2
  exit 1
fi

# Create directory structure
# NOTE: Skills are now created in .claude/skills/ as proper Claude Code skills
mkdir -p .ralph/{journal,context,agents}
mkdir -p .claude/skills

# Generate loop ID
LOOP_ID=$(date +%s)-$$

# Properly escape completion promise for JSON using jq
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_JSON=$(echo -n "$COMPLETION_PROMISE" | jq -Rs .)
else
  COMPLETION_PROMISE_JSON="null"
fi

# Create loop state file
cat > .ralph/loop_state.json <<EOF
{
  "active": true,
  "loop_id": "$LOOP_ID",
  "iteration": 1,
  "max_iterations": $MAX_ITERATIONS,
  "completion_promise": $COMPLETION_PROMISE_JSON,
  "prompt": $(echo "$PROMPT" | jq -Rs .),
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Validate JSON was written correctly
if ! jq empty .ralph/loop_state.json 2>/dev/null; then
  echo "⚠️  Warning: loop_state.json may contain invalid JSON" >&2
fi

# Initialize context files if they don't exist
if [[ ! -f .ralph/context/tactical.md ]]; then
  cat > .ralph/context/tactical.md <<EOF
# Tactical Context

*Current goals and immediate details for the task at hand.*

## Current Blockers
None yet.

## Recent Decisions
None yet.

## Important Details
None yet.
EOF
fi

if [[ ! -f .ralph/context/strategic.md ]]; then
  cat > .ralph/context/strategic.md <<EOF
# Strategic Context

*High-level direction and long-term considerations.*

## Overall Goal
$(echo "$PROMPT" | head -c 500)

## Key Dependencies
To be discovered.

## Risks & Considerations
To be discovered.
EOF
fi

if [[ ! -f .ralph/context/state.json ]]; then
  cat > .ralph/context/state.json <<EOF
{
  "tactical": {"last_processed_journal": null},
  "strategic": {"last_processed_journal": null},
  "skills_extracted": {"last_processed_journal": null}
}
EOF
fi

# Output setup message
cat <<EOF
🔄 Ralph Journal loop activated!

Loop ID: $LOOP_ID
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE"; else echo "none"; fi)

📓 Journal system initialized:
   .ralph/journal/        - Iteration diary entries
   .ralph/context/        - Tactical & strategic context
   .claude/skills/        - Learned skills (Claude Code auto-loads)

After each iteration:
  • Journal entry captures what happened
  • Tactical/strategic context updated
  • Skills extracted as Claude Code skills (persistent across sessions!)

⚠️  WARNING: Loop runs until completion promise or max iterations!

🔄
EOF

echo ""
echo "$PROMPT"
