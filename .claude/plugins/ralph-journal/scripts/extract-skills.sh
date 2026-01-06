#!/bin/bash

# Extract Skills from Journal Entries
# Analyzes journals and creates/updates Claude Code skill files for learned patterns

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RALPH_DIR="${1:-.ralph}"
PROJECT_SKILLS_DIR="${2:-.claude/skills}"
STATE_FILE="$RALPH_DIR/context/state.json"

# Convert to absolute paths
if [[ -d "$RALPH_DIR" ]]; then
  RALPH_DIR=$(cd "$RALPH_DIR" && pwd)
fi
JOURNAL_DIR="$RALPH_DIR/journal"

if [[ ! -d "$JOURNAL_DIR" ]]; then
  echo "No journal directory found" >&2
  exit 0
fi

# Get list of journal files sorted by name (timestamp order)
JOURNAL_FILES=$(ls -1 "$JOURNAL_DIR"/*.md 2>/dev/null | sort)
if [[ -z "$JOURNAL_FILES" ]]; then
  echo "No journal entries found" >&2
  exit 0
fi

# Read processing state
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"tactical":{"last_processed_journal":null},"strategic":{"last_processed_journal":null},"skills_extracted":{"last_processed_journal":null}}' > "$STATE_FILE"
fi

LAST_PROCESSED=$(jq -r '.skills_extracted.last_processed_journal // ""' "$STATE_FILE")

# Find new journals to process
NEW_JOURNALS=""
LATEST_JOURNAL=""
for f in $JOURNAL_FILES; do
  BASENAME=$(basename "$f")
  if [[ -z "$LAST_PROCESSED" ]] || [[ "$BASENAME" > "$LAST_PROCESSED" ]]; then
    NEW_JOURNALS+="$f "
    LATEST_JOURNAL="$BASENAME"
  fi
done

if [[ -z "$NEW_JOURNALS" ]]; then
  echo "[skills] No new journals to process"
  exit 0
fi

JOURNAL_COUNT=$(echo $NEW_JOURNALS | wc -w | tr -d ' ')
echo "[skills] Analyzing $JOURNAL_COUNT new journal(s) for extractable skills..."

# Read new journal content
JOURNAL_CONTENT=""
for f in $NEW_JOURNALS; do
  JOURNAL_CONTENT+="
--- $(basename $f) ---
$(cat "$f")
"
done

# Build comprehensive existing skills information
EXISTING_SKILLS_INFO=""
if [[ -d "$PROJECT_SKILLS_DIR" ]]; then
  for skill_file in $(find "$PROJECT_SKILLS_DIR" -name "SKILL.md" 2>/dev/null | sort); do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")
    # Read the full skill file (frontmatter + content)
    skill_content=$(cat "$skill_file" 2>/dev/null || echo "")
    EXISTING_SKILLS_INFO+="
### Existing Skill: $skill_name
**Path:** $skill_file
\`\`\`markdown
$skill_content
\`\`\`

"
  done
fi

if [[ -z "$EXISTING_SKILLS_INFO" ]]; then
  EXISTING_SKILLS_INFO="No existing skills found."
fi

# Build the skill extraction prompt
EXTRACT_PROMPT="You are analyzing journal entries from a Ralph loop to identify reusable skills that should be persisted as Claude Code skills.

## EXISTING SKILLS - READ CAREFULLY TO AVOID DUPLICATES

$EXISTING_SKILLS_INFO

## Journal Entries to Analyze
$JOURNAL_CONTENT

## Task

Analyze the journals and decide what skill changes are needed. You can:
1. **CREATE** new skills for genuinely new patterns
2. **UPDATE** existing skills with additional information from the journals
3. **DO NOTHING** if no changes are needed

### Rules for Creating/Updating Skills

**DO NOT CREATE a new skill if:**
- An existing skill covers the same topic (even with different wording)
- The pattern is too specific to this task and won't be reusable
- It's generic knowledge Claude already has
- It duplicates information in an existing skill

**DO UPDATE an existing skill if:**
- The journals contain additional techniques for the same topic
- New examples or use cases were discovered
- The existing skill could be enhanced with new information

**A good skill is:**
- **Reusable**: Applies to future tasks, not just this specific task
- **Actionable**: Provides concrete guidance Claude can follow
- **Focused**: Covers one specific domain or technique
- **Unique**: Doesn't duplicate existing skills

## Output Format

Output a JSON object with two arrays: \"create\" and \"update\".

For NEW skills (create):
\`\`\`json
{
  \"create\": [
    {
      \"name\": \"kebab-case-name\",
      \"description\": \"One sentence for when to use this skill\",
      \"content\": \"Full markdown content of the skill\"
    }
  ],
  \"update\": []
}
\`\`\`

For UPDATING existing skills:
\`\`\`json
{
  \"create\": [],
  \"update\": [
    {
      \"path\": \".claude/skills/existing-skill-name/SKILL.md\",
      \"name\": \"existing-skill-name\",
      \"description\": \"Updated description if changed, or same as before\",
      \"content\": \"Complete updated markdown content (not just additions)\"
    }
  ]
}
\`\`\`

If no changes are needed, output:
\`\`\`json
{\"create\": [], \"update\": []}
\`\`\`

Output ONLY valid JSON, no markdown code fences or other text.
"

# Run extraction via claude -p
TEMP_FILE=$(mktemp)
(
  unset CLAUDE_CODE_REMOTE CLAUDE_CODE_ENTRYPOINT CLAUDECODE \
        CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID \
        CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR \
        CLAUDE_CODE_WEBSOCKET_AUTH_FILE_DESCRIPTOR

  cd /tmp
  echo "$EXTRACT_PROMPT" | timeout 180 claude -p --model sonnet --output-format text > "$TEMP_FILE" 2>/dev/null
) || {
  echo "[skills] Extraction failed"
  rm -f "$TEMP_FILE"
  # Still update state so we don't reprocess same journals
  NEW_STATE=$(jq ".skills_extracted.last_processed_journal = \"$LATEST_JOURNAL\"" "$STATE_FILE")
  echo "$NEW_STATE" > "$STATE_FILE"
  exit 0
}

# Clean up output - remove markdown code fences if present
sed -i.bak 's/^```json//g; s/^```//g' "$TEMP_FILE"
rm -f "${TEMP_FILE}.bak"

# Validate JSON output
if ! jq -e '.' "$TEMP_FILE" >/dev/null 2>&1; then
  echo "[skills] Invalid JSON output from extraction"
  cat "$TEMP_FILE" >&2
  rm -f "$TEMP_FILE"
  exit 0
fi

# Process new skills to create
CREATE_COUNT=$(jq -r '.create | length' "$TEMP_FILE")
if [[ "$CREATE_COUNT" -gt 0 ]]; then
  echo "[skills] Creating $CREATE_COUNT new skill(s)..."
  
  for i in $(seq 0 $((CREATE_COUNT - 1))); do
    SKILL_NAME=$(jq -r ".create[$i].name" "$TEMP_FILE")
    SKILL_DESC=$(jq -r ".create[$i].description" "$TEMP_FILE")
    SKILL_CONTENT=$(jq -r ".create[$i].content" "$TEMP_FILE")
    
    if [[ -n "$SKILL_NAME" ]] && [[ "$SKILL_NAME" != "null" ]]; then
      RESULT=$("$PLUGIN_ROOT/scripts/generate-skill.sh" "$SKILL_NAME" "$SKILL_DESC" "$SKILL_CONTENT" "$PROJECT_SKILLS_DIR" 2>&1 || echo "FAILED")
      echo "[skills] CREATE: $RESULT"
    fi
  done
else
  echo "[skills] No new skills to create"
fi

# Process skill updates
UPDATE_COUNT=$(jq -r '.update | length' "$TEMP_FILE")
if [[ "$UPDATE_COUNT" -gt 0 ]]; then
  echo "[skills] Updating $UPDATE_COUNT existing skill(s)..."
  
  for i in $(seq 0 $((UPDATE_COUNT - 1))); do
    SKILL_PATH=$(jq -r ".update[$i].path" "$TEMP_FILE")
    SKILL_NAME=$(jq -r ".update[$i].name" "$TEMP_FILE")
    SKILL_DESC=$(jq -r ".update[$i].description" "$TEMP_FILE")
    SKILL_CONTENT=$(jq -r ".update[$i].content" "$TEMP_FILE")
    
    if [[ -n "$SKILL_PATH" ]] && [[ -f "$SKILL_PATH" ]]; then
      # Write updated skill file
      # Check if content already has frontmatter (starts with ---)
      if echo "$SKILL_CONTENT" | head -1 | grep -q '^---'; then
        # Content includes frontmatter, write as-is
        echo "$SKILL_CONTENT" > "$SKILL_PATH"
      else
        # Content doesn't have frontmatter, add it
        cat > "$SKILL_PATH" <<EOF
---
name: $SKILL_NAME
description: $SKILL_DESC
---

$SKILL_CONTENT
EOF
      fi
      echo "[skills] UPDATE: $SKILL_PATH"
    else
      echo "[skills] UPDATE FAILED: $SKILL_PATH not found"
    fi
  done
else
  echo "[skills] No skills to update"
fi

rm -f "$TEMP_FILE"

# Update processing state
NEW_STATE=$(jq ".skills_extracted.last_processed_journal = \"$LATEST_JOURNAL\"" "$STATE_FILE")
echo "$NEW_STATE" > "$STATE_FILE"

echo "[skills] Skill extraction complete"
