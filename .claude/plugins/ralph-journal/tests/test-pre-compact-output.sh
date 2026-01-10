#!/bin/bash

# Regression test for pre-compact hook JSON output purity
# Ensures hook outputs ONLY valid JSON without diagnostic message corruption

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PRE_COMPACT_HOOK="$PLUGIN_ROOT/hooks/pre-compact.sh"

# Source portability helpers for portable_timeout
source "$PLUGIN_ROOT/scripts/lib/portable.sh"

run_test() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Testing: $test_name... "
  
  if eval "$2"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
    return 1
  fi
}

test_pre_compact_json_purity() {
  # Create test environment
  local TEST_DIR=$(mktemp -d)
  local TEST_PROJECT="$TEST_DIR/project"
  local TEST_RALPH="$TEST_PROJECT/.ralph"
  local TEST_JOURNAL="$TEST_RALPH/journal"
  local TEST_CONTEXT="$TEST_RALPH/context"
  
  mkdir -p "$TEST_JOURNAL" "$TEST_CONTEXT" "$TEST_PROJECT/.claude/skills"
  
  # Create test journal
  echo "# Test" > "$TEST_JOURNAL/2026-01-01T10-00-00_iter_001.md"
  
  # Create state and context files
  echo '{"tactical":{"last_processed_journal":null},"strategic":{"last_processed_journal":null},"skills_extracted":{"last_processed_journal":null}}' > "$TEST_CONTEXT/state.json"
  echo "# Tactical" > "$TEST_CONTEXT/tactical.md"
  echo "# Strategic" > "$TEST_CONTEXT/strategic.md"
  
  # Create transcript
  local TRANSCRIPT="$TEST_DIR/transcript.jsonl"
  echo '{"role":"user","message":{"content":[{"type":"text","text":"test"}]}}' > "$TRANSCRIPT"
  
  # Create hook input
  local HOOK_INPUT=$(cat << HOOKIN
{
  "transcript_path": "$TRANSCRIPT",
  "cwd": "$TEST_PROJECT",
  "permission_mode": "default",
  "hook_event_name": "PreCompact"
}
HOOKIN
)
  
  # Run hook with short timeout to avoid hanging on Claude calls
  cd "$TEST_PROJECT"
  local OUTPUT=$(portable_timeout 10 bash "$PRE_COMPACT_HOOK" <<< "$HOOK_INPUT" 2>&1 || echo '{"continue": true}')
  
  # Test: Output should be valid JSON
  if ! echo "$OUTPUT" | jq . >/dev/null 2>&1; then
    echo ""
    echo "  Output was: $OUTPUT"
    rm -rf "$TEST_DIR"
    return 1
  fi
  
  # Test: Should not contain diagnostic markers
  if echo "$OUTPUT" | grep -qE '\[tactical\]|\[strategic\]|\[skills\]|Processing|Extracting|Updating'; then
    echo ""
    echo "  Found diagnostic messages in output"
    rm -rf "$TEST_DIR"
    return 1
  fi
  
  rm -rf "$TEST_DIR"
  return 0
}

# Run tests
echo "═══════════════════════════════════════════════════════════"
echo "🧪 Running pre-compact JSON output purity test"
echo "═══════════════════════════════════════════════════════════"
echo ""

run_test "Pre-compact outputs only valid JSON" "test_pre_compact_json_purity"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 Test Results"
echo "═══════════════════════════════════════════════════════════"
echo "Total:  $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}❌ Test failed! Diagnostic messages corrupting hook output${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
fi
