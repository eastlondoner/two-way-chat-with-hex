#!/bin/bash

# Test suite for search-journals.sh
# Run from the plugin root directory

# Don't use set -e as we need to capture exit codes
set -uo pipefail

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
SEARCH_SCRIPT="$PLUGIN_ROOT/scripts/search-journals.sh"

# Create temporary test directory
TEST_DIR=$(mktemp -d)
TEST_RALPH_DIR="$TEST_DIR/.ralph"
TEST_JOURNAL_DIR="$TEST_RALPH_DIR/journal"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Helper functions
setup_test_journals() {
  rm -rf "$TEST_RALPH_DIR"
  mkdir -p "$TEST_JOURNAL_DIR"

  # Create sample journal entries
  cat > "$TEST_JOURNAL_DIR/2026-01-01T10-00-00_iter_001.md" <<'EOF'
# Journal Entry: Iteration 1
**Timestamp:** 2026-01-01T10-00-00
**Loop ID:** test-loop-1

## 1. The Bigger Picture
Working on deploying the API to production environment.

## 2. Iteration Goals
- [ ] Configure database connection
- [ ] Set up environment variables

## 3. The Plan
1. Review database configuration
2. Test connection string
3. Deploy to staging first

## 4. What Actually Happened
- ✅ Database connection configured
- ❌ Hit a timeout error with the connection pool

## 5. Analysis
- ✅ Went Well: Initial configuration was straightforward
- ❌ Went Badly: Connection pool timeout needs adjustment
- 💡 Insights: Need to increase pool size for production load
EOF

  cat > "$TEST_JOURNAL_DIR/2026-01-01T11-00-00_iter_002.md" <<'EOF'
# Journal Entry: Iteration 2
**Timestamp:** 2026-01-01T11-00-00
**Loop ID:** test-loop-1

## 1. The Bigger Picture
Continuing the API deployment after fixing connection issues.

## 2. Iteration Goals
- [ ] Fix connection pool timeout
- [ ] Retry deployment

## 3. The Plan
1. Increase pool size configuration
2. Add retry logic
3. Test with load

## 4. What Actually Happened
- ✅ Fixed the timeout by setting pool_size=20
- ✅ Deployment successful to staging
- ✅ Load test passed

## 5. Analysis
- ✅ Went Well: Configuration fix worked immediately
- ❌ Went Badly: Nothing major
- 💡 Insights: Default pool size is too small for our use case
EOF

  cat > "$TEST_JOURNAL_DIR/2026-01-02T09-00-00_iter_003.md" <<'EOF'
# Journal Entry: Iteration 3
**Timestamp:** 2026-01-02T09-00-00
**Loop ID:** test-loop-2

## 1. The Bigger Picture
Setting up Kubernetes deployment for microservices.

## 2. Iteration Goals
- [ ] Create deployment manifests
- [ ] Configure service mesh

## 3. The Plan
1. Write Kubernetes YAML files
2. Set up Istio service mesh
3. Deploy to cluster

## 4. What Actually Happened
- ✅ Created deployment.yaml and service.yaml
- ✅ Configured Istio sidecar injection
- ❌ Hit an issue with resource limits

## 5. Analysis
- ✅ Went Well: Service mesh integration smooth
- ❌ Went Badly: Memory limits too restrictive
- 💡 Insights: Start with higher resource limits, optimize later
EOF
}

# Test assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo -e "${RED}FAIL: $message${NC}"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    return 1
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Assertion failed}"

  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  else
    echo -e "${RED}FAIL: $message${NC}"
    echo "  Expected NOT to contain: $needle"
    return 1
  fi
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Exit code assertion failed}"

  if [[ "$expected" -eq "$actual" ]]; then
    return 0
  else
    echo -e "${RED}FAIL: $message${NC}"
    echo "  Expected exit code: $expected"
    echo "  Actual exit code:   $actual"
    return 1
  fi
}

# Run a test and track results
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

# ============================================================================
# Test Cases
# ============================================================================

test_help_option() {
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" --help 2>&1) || exit_code=$?
  assert_contains "$output" "Usage:" "Should show usage" || return 1
  assert_contains "$output" "search_term" "Should mention search term" || return 1
  assert_contains "$output" "--context" "Should document context option" || return 1
  return 0
}

test_no_search_term() {
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" 2>&1) || exit_code=$?
  assert_exit_code 1 "$exit_code" "Should exit with error when no search term" || return 1
  assert_contains "$output" "Error" "Should show error message" || return 1
  return 0
}

test_missing_journal_dir() {
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "test" --dir "$TEST_DIR/nonexistent" 2>&1) || exit_code=$?
  assert_exit_code 1 "$exit_code" "Should exit with error when journal dir missing" || return 1
  assert_contains "$output" "No journal directory" "Should indicate missing directory" || return 1
  return 0
}

test_empty_journal_dir() {
  mkdir -p "$TEST_DIR/empty/.ralph/journal"
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "test" --dir "$TEST_DIR/empty/.ralph" 2>&1) || exit_code=$?
  assert_exit_code 1 "$exit_code" "Should exit with error when no journals" || return 1
  assert_contains "$output" "No journal entries" "Should indicate no entries" || return 1
  return 0
}

test_basic_search() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "timeout" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  assert_contains "$output" "Search Results" "Should show results header" || return 1
  assert_contains "$output" "timeout" "Should find timeout matches" || return 1
  assert_contains "$output" "iter_001" "Should find in iteration 1" || return 1
  return 0
}

test_case_insensitive_search() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "TIMEOUT" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  assert_contains "$output" "timeout" "Should find lowercase match with uppercase query" || return 1
  return 0
}

test_case_sensitive_search() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "TIMEOUT" --dir "$TEST_RALPH_DIR" --case-sensitive 2>&1) || exit_code=$?
  # Should not find "timeout" when searching for "TIMEOUT" with case-sensitive
  assert_contains "$output" "No matches found" "Should not find lowercase when case-sensitive" || return 1
  return 0
}

test_no_matches() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "xyznonexistent123" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  assert_contains "$output" "No matches found" "Should indicate no matches" || return 1
  return 0
}

test_list_only() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "database" --dir "$TEST_RALPH_DIR" --list-only 2>&1) || exit_code=$?
  assert_contains "$output" "iter_001.md" "Should list matching file" || return 1
  # In list-only mode, should not show full content headers
  assert_not_contains "$output" "Search Results" "Should not show search results header in list mode" || return 1
  return 0
}

test_context_lines() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "pool_size=20" --dir "$TEST_RALPH_DIR" --context 2 2>&1) || exit_code=$?
  assert_contains "$output" "pool_size=20" "Should find exact match" || return 1
  return 0
}

test_max_results() {
  setup_test_journals
  local output
  local exit_code=0
  # Search for something in all journals
  output=$("$SEARCH_SCRIPT" "Journal Entry" --dir "$TEST_RALPH_DIR" --max-results 2 2>&1) || exit_code=$?
  # Should only show 2 journals
  local journal_count
  journal_count=$(echo "$output" | grep -c "📓 Iteration" || true)
  if [[ "$journal_count" -le 2 ]]; then
    return 0
  else
    echo "Expected at most 2 journals, got $journal_count"
    return 1
  fi
}

test_max_results_zero_matches() {
  setup_test_journals
  local output
  local exit_code=0
  # Search for something that won't be in output at all
  output=$("$SEARCH_SCRIPT" "xyznonexistent" --dir "$TEST_RALPH_DIR" --max-results 2 2>&1) || exit_code=$?

  # Verify we can count results without arithmetic error
  # This is a regression test for the || echo "0" bug that caused
  # journal_count to be "0\n0" when grep -c found no matches
  local journal_count
  journal_count=$(echo "$output" | grep -c "📓 Iteration" || true)

  # Should be 0 (no matches, so no "📓 Iteration" lines in output)
  if [[ "$journal_count" -eq 0 ]]; then
    return 0
  else
    echo "Expected 0 journals, got '$journal_count'"
    return 1
  fi
}

test_multi_word_search() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "connection pool" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  assert_contains "$output" "connection" "Should find multi-word query" || return 1
  return 0
}

test_kubernetes_search() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "Kubernetes" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  assert_contains "$output" "iter_003" "Should find Kubernetes in iteration 3" || return 1
  return 0
}

test_iteration_info_extraction() {
  setup_test_journals
  local output
  local exit_code=0
  output=$("$SEARCH_SCRIPT" "database" --dir "$TEST_RALPH_DIR" 2>&1) || exit_code=$?
  # Should extract and display iteration number from filename
  assert_contains "$output" "Iteration" "Should show iteration number" || return 1
  return 0
}

# ============================================================================
# Run all tests
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Running search-journals.sh tests"
echo "═══════════════════════════════════════════════════════════"
echo ""

run_test "Help option" test_help_option
run_test "No search term error" test_no_search_term
run_test "Missing journal directory" test_missing_journal_dir
run_test "Empty journal directory" test_empty_journal_dir
run_test "Basic search" test_basic_search
run_test "Case insensitive search (default)" test_case_insensitive_search
run_test "Case sensitive search" test_case_sensitive_search
run_test "No matches found" test_no_matches
run_test "List only mode" test_list_only
run_test "Context lines option" test_context_lines
run_test "Max results option" test_max_results
run_test "Multi-word search" test_multi_word_search
run_test "Kubernetes search" test_kubernetes_search
run_test "Iteration info extraction" test_iteration_info_extraction

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
