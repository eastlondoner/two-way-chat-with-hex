#!/bin/bash

# Search Journals Script
# Searches through Ralph journal entries for matching content

set -uo pipefail

# Source portability helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/portable.sh"

# Configuration
RALPH_DIR="${RALPH_DIR:-.ralph}"
JOURNAL_DIR="$RALPH_DIR/journal"
CONTEXT_LINES="${CONTEXT_LINES:-3}"
MAX_RESULTS="${MAX_RESULTS:-10}"
CASE_INSENSITIVE="${CASE_INSENSITIVE:-true}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <search_term> [options]

Search through Ralph journal entries for matching content.

Options:
  -d, --dir DIR       Ralph directory (default: .ralph)
  -c, --context N     Lines of context around matches (default: 3)
  -n, --max-results N Maximum number of matching files to show (default: 10)
  -s, --case-sensitive  Make search case-sensitive (default: case-insensitive)
  -l, --list-only     Only list matching files, don't show content
  -h, --help          Show this help message

Examples:
  $(basename "$0") "database timeout"
  $(basename "$0") "API error" --context 5
  $(basename "$0") "deploy" --list-only
EOF
  exit 0
}

# Parse arguments
SEARCH_TERM=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -d|--dir)
      RALPH_DIR="$2"
      JOURNAL_DIR="$RALPH_DIR/journal"
      shift 2
      ;;
    -c|--context)
      CONTEXT_LINES="$2"
      shift 2
      ;;
    -n|--max-results)
      MAX_RESULTS="$2"
      shift 2
      ;;
    -s|--case-sensitive)
      CASE_INSENSITIVE=false
      shift
      ;;
    -l|--list-only)
      LIST_ONLY=true
      shift
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
    *)
      if [[ -z "$SEARCH_TERM" ]]; then
        SEARCH_TERM="$1"
      else
        SEARCH_TERM="$SEARCH_TERM $1"
      fi
      shift
      ;;
  esac
done

# Validate search term
if [[ -z "$SEARCH_TERM" ]]; then
  echo "Error: Search term required" >&2
  echo "Use --help for usage information" >&2
  exit 1
fi

# Check if journal directory exists
if [[ ! -d "$JOURNAL_DIR" ]]; then
  echo "No journal directory found at: $JOURNAL_DIR" >&2
  echo "Have you run a Ralph loop yet?" >&2
  exit 1
fi

# Check if there are any journals
JOURNAL_COUNT=$(find "$JOURNAL_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
if [[ "$JOURNAL_COUNT" -eq 0 ]]; then
  echo "No journal entries found in: $JOURNAL_DIR" >&2
  exit 1
fi

# Search for matching files
if [[ "$LIST_ONLY" == "true" ]]; then
  # Just list matching files with match count
  if [[ "$CASE_INSENSITIVE" == "true" ]]; then
    grep -l -i "$SEARCH_TERM" "$JOURNAL_DIR"/*.md 2>/dev/null | head -n "$MAX_RESULTS" | while read -r file; do
      match_count=$(grep -c -i "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
      echo "$file ($match_count matches)"
    done
  else
    grep -l "$SEARCH_TERM" "$JOURNAL_DIR"/*.md 2>/dev/null | head -n "$MAX_RESULTS" | while read -r file; do
      match_count=$(grep -c "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
      echo "$file ($match_count matches)"
    done
  fi
  exit 0
fi

# Get list of matching files sorted by modification time (newest first)
# Uses portable mtime_sort_paths to work on both macOS and Linux
_match_arr=()
if [[ "$CASE_INSENSITIVE" == "true" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && _match_arr+=("$line")
  done < <(grep -l -i "$SEARCH_TERM" "$JOURNAL_DIR"/*.md 2>/dev/null || true)
else
  while IFS= read -r line; do
    [[ -n "$line" ]] && _match_arr+=("$line")
  done < <(grep -l "$SEARCH_TERM" "$JOURNAL_DIR"/*.md 2>/dev/null || true)
fi

if [[ ${#_match_arr[@]} -gt 0 ]]; then
  MATCHING_FILES=$(mtime_sort_paths "${_match_arr[@]}" | head -n "$MAX_RESULTS")
else
  MATCHING_FILES=""
fi

if [[ -z "$MATCHING_FILES" ]]; then
  echo "No matches found for: $SEARCH_TERM"
  echo ""
  echo "Searched $JOURNAL_COUNT journal(s) in $JOURNAL_DIR"
  exit 0
fi

# Count total matches
TOTAL_FILES=$(echo "$MATCHING_FILES" | wc -l)
if [[ "$CASE_INSENSITIVE" == "true" ]]; then
  TOTAL_MATCHES=$(grep -c -i "$SEARCH_TERM" $MATCHING_FILES 2>/dev/null | \
    awk -F: '{sum += $NF} END {print sum}') || TOTAL_MATCHES="?"
else
  TOTAL_MATCHES=$(grep -c "$SEARCH_TERM" $MATCHING_FILES 2>/dev/null | \
    awk -F: '{sum += $NF} END {print sum}') || TOTAL_MATCHES="?"
fi

echo "═══════════════════════════════════════════════════════════"
echo "🔍 Search Results for: \"$SEARCH_TERM\""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Found $TOTAL_MATCHES match(es) in $TOTAL_FILES journal(s)"
echo ""

# Show matches with context
DISPLAYED=0
for file in $MATCHING_FILES; do
  if [[ $DISPLAYED -ge $MAX_RESULTS ]]; then
    break
  fi

  BASENAME=$(basename "$file")

  # Extract iteration number and date from filename
  # Format: YYYY-MM-DDTHH-MM-SS_iter_NNN.md
  # Uses portable bash regex instead of grep -oP (not available on macOS)
  ITER_NUM=$(extract_iter_num "$BASENAME")
  FILE_DATE=$(extract_file_date "$BASENAME")

  if [[ "$CASE_INSENSITIVE" == "true" ]]; then
    MATCH_COUNT=$(grep -c -i "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
  else
    MATCH_COUNT=$(grep -c "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
  fi

  echo "───────────────────────────────────────────────────────────"
  echo "📓 Iteration $ITER_NUM ($FILE_DATE) - $MATCH_COUNT match(es)"
  echo "   File: $BASENAME"
  echo "───────────────────────────────────────────────────────────"
  echo ""

  # Show matching lines with context
  if [[ "$CASE_INSENSITIVE" == "true" ]]; then
    grep -n -i -C "$CONTEXT_LINES" "$SEARCH_TERM" "$file" 2>/dev/null || true
  else
    grep -n -C "$CONTEXT_LINES" "$SEARCH_TERM" "$file" 2>/dev/null || true
  fi

  echo ""
  DISPLAYED=$((DISPLAYED + 1))
done

# Summary
if [[ $TOTAL_FILES -gt $MAX_RESULTS ]]; then
  echo "═══════════════════════════════════════════════════════════"
  echo "Showing $MAX_RESULTS of $TOTAL_FILES matching journals."
  echo "Use --max-results to see more."
  echo "═══════════════════════════════════════════════════════════"
fi
