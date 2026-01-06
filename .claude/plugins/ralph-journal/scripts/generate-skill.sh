#!/bin/bash

# Generate Claude Code Skill Script
# Creates proper .claude/skills/skill-name/SKILL.md files from Ralph learnings

set -euo pipefail

# Arguments
SKILL_NAME="${1:-}"
SKILL_DESCRIPTION="${2:-}"
SKILL_CONTENT="${3:-}"
SKILLS_DIR="${4:-.claude/skills}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Error: Skill name required" >&2
  echo "Usage: $0 <skill-name> <description> <content> [skills-dir]" >&2
  exit 1
fi

# Sanitize skill name for directory (lowercase, hyphens)
SKILL_SLUG=$(echo "$SKILL_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

if [[ -z "$SKILL_SLUG" ]]; then
  echo "Error: Could not generate valid skill slug from name: $SKILL_NAME" >&2
  exit 1
fi

SKILL_DIR="$SKILLS_DIR/$SKILL_SLUG"
SKILL_FILE="$SKILL_DIR/SKILL.md"

# Check if skill already exists
if [[ -f "$SKILL_FILE" ]]; then
  echo "Skill already exists: $SKILL_FILE" >&2
  echo "EXISTING:$SKILL_FILE"
  exit 0
fi

# Create skill directory
mkdir -p "$SKILL_DIR"

# Generate skill file with proper frontmatter
cat > "$SKILL_FILE" <<EOF
---
name: $SKILL_SLUG
description: $SKILL_DESCRIPTION
---

$SKILL_CONTENT
EOF

echo "CREATED:$SKILL_FILE"
