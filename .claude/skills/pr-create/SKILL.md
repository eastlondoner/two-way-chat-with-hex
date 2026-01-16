# PR Creation with Session Tracking

## Overview

This skill creates pull requests with automatic session ID tracking. Every PR created using this skill will include links to all Claude Code web sessions that contributed commits.

## Usage

Invoke with `/pr-create` or when creating a PR, use this workflow.

## Workflow

### 1. Extract Session IDs from Commits

```bash
# Get the base branch (usually main or master)
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Extract all unique session IDs from commits in this branch
git log ${BASE_BRANCH}..HEAD --format=%B | grep -oE 'session_[A-Za-z0-9]+' | sort -u
```

### 2. Build the Session Links Section

For each session ID found, create a markdown link:
```markdown
## Contributing Sessions
- [session_012e8Mfz8nX8o77VpBsT56Ro](https://claude.ai/code/session_012e8Mfz8nX8o77VpBsT56Ro)
```

### 3. Create PR with Session Annotation

```bash
# Get session IDs
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
SESSIONS=$(git log ${BASE_BRANCH}..HEAD --format=%B | grep -oE 'session_[A-Za-z0-9]+' | sort -u)

# Build session links
SESSION_LINKS=""
for sid in $SESSIONS; do
  SESSION_LINKS="${SESSION_LINKS}- [${sid}](https://claude.ai/code/${sid})\n"
done

# Create PR
gh pr create --title "Your PR title" --body "$(cat <<EOF
## Summary
- Description of changes

## Test plan
- [ ] Tests pass
- [ ] Manual verification

## Contributing Sessions
${SESSION_LINKS}
EOF
)"
```

## Full Script

Save this as a helper script if needed:

```bash
#!/bin/bash
# pr-create-with-sessions.sh

set -e

TITLE="$1"
SUMMARY="$2"

if [ -z "$TITLE" ]; then
  echo "Usage: pr-create-with-sessions.sh 'PR Title' 'Summary bullets'"
  exit 1
fi

# Detect base branch
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Extract unique session IDs
SESSIONS=$(git log ${BASE_BRANCH}..HEAD --format=%B 2>/dev/null | grep -oE 'session_[A-Za-z0-9]+' | sort -u || true)

# Build session links
SESSION_LINKS=""
if [ -n "$SESSIONS" ]; then
  for sid in $SESSIONS; do
    SESSION_LINKS="${SESSION_LINKS}- [${sid}](https://claude.ai/code/${sid})"$'\n'
  done
else
  SESSION_LINKS="- No Claude Code sessions detected"$'\n'
fi

# Get current session if in Claude Code environment
CURRENT_SESSION="${CLAUDE_CODE_REMOTE_SESSION_ID:-}"
if [ -n "$CURRENT_SESSION" ]; then
  # Check if current session is already in the list
  if ! echo "$SESSIONS" | grep -q "$CURRENT_SESSION"; then
    SESSION_LINKS="${SESSION_LINKS}- [${CURRENT_SESSION}](https://claude.ai/code/${CURRENT_SESSION}) (PR creator)"$'\n'
  fi
fi

# Create PR
gh pr create --title "$TITLE" --body "$(cat <<EOF
## Summary
${SUMMARY:-Changes in this PR}

## Test plan
- [ ] Tests pass
- [ ] Manual verification

## Contributing Sessions
${SESSION_LINKS}
EOF
)"
```

## Integration with Claude Code

When Claude creates a PR, it should:

1. **Always extract session IDs** from the commit history
2. **Include the current session** even if no commits were made in this session (marked as "PR creator")
3. **Format as clickable links** to the Claude Code web interface

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_REMOTE_SESSION_ID` | Current session's API identifier |

## Example Output

A PR created with this workflow will have a body like:

```markdown
## Summary
- Add user authentication feature
- Update API endpoints

## Test plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual login flow tested

## Contributing Sessions
- [session_012e8Mfz8nX8o77VpBsT56Ro](https://claude.ai/code/session_012e8Mfz8nX8o77VpBsT56Ro)
- [session_abc123def456](https://claude.ai/code/session_abc123def456)
- [session_xyz789](https://claude.ai/code/session_xyz789) (PR creator)
```
