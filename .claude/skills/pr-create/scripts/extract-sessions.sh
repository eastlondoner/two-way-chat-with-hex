#!/bin/bash
# Extract session IDs from git commits and format as markdown links
# Usage: extract-sessions.sh [base_branch]

set -e

BASE_BRANCH="${1:-}"

# Auto-detect base branch if not provided
if [ -z "$BASE_BRANCH" ]; then
  # Try to get the default branch from origin/HEAD
  BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)

  # If that didn't work, try common branch names
  if [ -z "$BASE_BRANCH" ]; then
    for branch in main master; do
      if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        BASE_BRANCH="origin/$branch"
        break
      elif git rev-parse --verify "$branch" >/dev/null 2>&1; then
        BASE_BRANCH="$branch"
        break
      fi
    done
  else
    # Prefer origin/branch if it exists
    if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
      BASE_BRANCH="origin/$BASE_BRANCH"
    fi
  fi

  # Last resort: find merge-base with first parent
  if [ -z "$BASE_BRANCH" ]; then
    # Use the first commit that looks like a merge from main
    BASE_BRANCH=$(git log --merges --first-parent --format=%H -1 2>/dev/null || echo "HEAD~10")
  fi
fi

# Extract unique session IDs from commit messages
SESSIONS=$(git log "${BASE_BRANCH}..HEAD" --format=%B 2>/dev/null | grep -oE 'session_[A-Za-z0-9]+' | sort -u || true)

# Build session links
if [ -n "$SESSIONS" ]; then
  for sid in $SESSIONS; do
    echo "- [${sid}](https://claude.ai/code/${sid})"
  done
else
  echo "- No Claude Code sessions detected in commits"
fi

# Add current session if in Claude Code environment and not already included
CURRENT_SESSION="${CLAUDE_CODE_REMOTE_SESSION_ID:-}"
if [ -n "$CURRENT_SESSION" ]; then
  if ! echo "$SESSIONS" | grep -q "$CURRENT_SESSION"; then
    echo "- [${CURRENT_SESSION}](https://claude.ai/code/${CURRENT_SESSION}) (PR creator)"
  fi
fi
