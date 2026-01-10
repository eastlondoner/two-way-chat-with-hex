#!/bin/bash

# Test suite for skill extraction symmetry across completion paths
# Ensures skills are extracted in ALL loop completion scenarios

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STOP_HOOK="$PLUGIN_ROOT/hooks/stop-hook.sh"

# Helper functions
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Testing: $test_name... "

  # Run test function and capture result
  local result=0
  $test_func || result=$?

  if [[ $result -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Assertion failed}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    echo -e "${RED}FAIL: $message${NC}"
    echo "  Expected to contain: $needle"
    echo "  Actual output (first 200 chars): ${haystack:0:200}"
    return 1
  fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_completion_promise_block_has_skill_extraction() {
  # Extract the completion promise block from the stop-hook
  local block=$(sed -n '/Promise fulfilled/,/Mark loop complete/p' "$STOP_HOOK")
  assert_contains "$block" "extract-skills.sh" "Completion promise block should call extract-skills.sh" || return 1
  return 0
}

test_max_iterations_block_has_skill_extraction() {
  # Extract the max iterations block from the stop-hook
  local block=$(sed -n '/Max iterations.*reached/,/Mark loop complete/p' "$STOP_HOOK")
  assert_contains "$block" "extract-skills.sh" "Max iterations block should call extract-skills.sh" || return 1
  return 0
}

test_both_blocks_have_identical_cleanup_order() {
  # Extract both blocks
  local promise_block=$(sed -n '/Promise fulfilled/,/Mark loop complete/p' "$STOP_HOOK")
  local maxiter_block=$(sed -n '/Max iterations.*reached/,/Mark loop complete/p' "$STOP_HOOK" | grep -v "RECURSION SAFETY" | grep -v "recursion safety")

  # Check that both have generate-journal, update-context, extract-skills in order
  # Use grep to find the script names in the lines
  local promise_order=$(echo "$promise_block" | grep -oE "(generate-journal|update-context|extract-skills)\.sh" | sed 's/\.sh//' | tr '\n' ' ')
  local maxiter_order=$(echo "$maxiter_block" | grep -oE "(generate-journal|update-context|extract-skills)\.sh" | sed 's/\.sh//' | tr '\n' ' ')

  # Expected order
  local expected="generate-journal update-context extract-skills "

  if [[ "$promise_order" != "$expected" ]]; then
    echo "Promise block order: '$promise_order' != expected '$expected'"
    return 1
  fi

  if [[ "$maxiter_order" != "$expected" ]]; then
    echo "Max iterations block order: '$maxiter_order' != expected '$expected'"
    return 1
  fi

  return 0
}

test_extract_skills_uses_correct_arguments() {
  # All calls should use: "$RALPH_DIR" "$PROJECT_ROOT/.claude/skills"
  local calls=$(grep "extract-skills.sh" "$STOP_HOOK" | grep -v "^#")

  # Count calls (should be exactly 3: promise block, max iterations block, and mid-loop)
  local call_count=$(echo "$calls" | wc -l | tr -d ' ')
  if [[ $call_count -ne 3 ]]; then
    echo "Expected 3 extract-skills.sh calls, found $call_count"
    return 1
  fi

  # Check all use same arguments
  local arg_pattern='\$RALPH_DIR.*\$PROJECT_ROOT/\.claude/skills'
  while IFS= read -r call; do
    if ! echo "$call" | grep -q "$arg_pattern"; then
      echo "extract-skills call doesn't match expected arguments: $call"
      return 1
    fi
  done <<< "$calls"

  return 0
}

test_skill_extraction_in_mid_loop() {
  # The mid-loop continuation path (STEP 4b) SHOULD call extract-skills
  # This ensures learned skills are available for the next iteration
  local mid_loop_block=$(sed -n '/STEP 3: Generate Journal Entry/,/STEP 5: Prepare Next Iteration/p' "$STOP_HOOK")

  if ! echo "$mid_loop_block" | grep -q "extract-skills.sh"; then
    echo "Mid-loop should extract skills after each iteration"
    return 1
  fi

  return 0
}

# ============================================================================
# Run all tests
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Running skill extraction symmetry tests"
echo "═══════════════════════════════════════════════════════════"
echo ""

run_test "Completion promise block has skill extraction" test_completion_promise_block_has_skill_extraction
run_test "Max iterations block has skill extraction" test_max_iterations_block_has_skill_extraction
run_test "Both blocks have identical cleanup order" test_both_blocks_have_identical_cleanup_order
run_test "Extract skills uses correct arguments" test_extract_skills_uses_correct_arguments
run_test "Skill extraction in mid-loop iterations" test_skill_extraction_in_mid_loop

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 Test Results"
echo "═══════════════════════════════════════════════════════════"
echo "Total:  $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}❌ Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
fi
