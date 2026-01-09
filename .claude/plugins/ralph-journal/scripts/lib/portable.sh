#!/usr/bin/env bash
# Portability helpers for macOS and Linux
# Source this file to use cross-platform wrappers for timeout, base64, and mtime sorting

# Detect platform once at source time
_PORTABLE_OS="$(uname -s)"

# portable_timeout <seconds> <command...>
# Uses timeout/gtimeout if available, else runs command directly
portable_timeout() {
  local secs="$1"; shift
  if command -v timeout &>/dev/null; then
    timeout "$secs" "$@"
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
  else
    [[ "${RALPH_DEBUG:-}" == "1" ]] && echo "[portable] warning: no timeout command" >&2
    "$@"
  fi
}

# b64_encode_no_wrap - reads stdin, outputs base64 without line wrapping
b64_encode_no_wrap() {
  if [[ "$_PORTABLE_OS" == "Darwin" ]]; then
    base64
  else
    base64 -w0
  fi
}

# b64_decode - reads stdin, outputs decoded bytes
b64_decode() {
  if [[ "$_PORTABLE_OS" == "Darwin" ]]; then
    base64 -D
  else
    base64 -d
  fi
}

# mtime_sort_paths <file1> [file2...]
# Outputs paths sorted by mtime (newest first)
mtime_sort_paths() {
  python3 -c "
import os, sys
paths = sys.argv[1:]
valid = [(p, os.path.getmtime(p)) for p in paths if os.path.exists(p)]
for p, _ in sorted(valid, key=lambda x: -x[1]):
    print(p)
" "$@"
}

# extract_iter_num <filename>
# Extracts iteration number from journal filename (e.g., "2024-01-01T12-00-00_iter_003.md" -> "3")
extract_iter_num() {
  local name="$1"
  if [[ "$name" =~ iter_([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}" | sed 's/^0*//' | grep . || echo "?"
  else
    echo "?"
  fi
}

# extract_file_date <filename>
# Extracts date from journal filename (e.g., "2024-01-01T12-00-00_iter_003.md" -> "2024-01-01")
extract_file_date() {
  local name="$1"
  if [[ "$name" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown date"
  fi
}

# portable_date_iso - outputs ISO 8601 timestamp (replaces date -Iseconds)
portable_date_iso() {
  if date -Iseconds &>/dev/null 2>&1; then
    date -Iseconds
  else
    # Fallback for older BSD/macOS
    date -u +"%Y-%m-%dT%H:%M:%S+00:00"
  fi
}
