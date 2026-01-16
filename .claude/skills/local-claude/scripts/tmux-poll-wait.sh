#!/bin/bash
# Poll tmux capture-pane until output stabilizes or timeout
# Usage: tmux-poll-wait.sh <session> [timeout_seconds]
# Exit codes: 0 = stable, 124 = timeout, 1 = session not found

SESSION="${1:-claude-local}"
TIMEOUT="${2:-60}"
POLL_INTERVAL="${TMUX_POLL_INTERVAL:-3}"
STABLE_THRESHOLD="${TMUX_POLL_STABLE:-3}"
CAPTURE_LINES="${TMUX_POLL_LINES:-100}"

# Early exit if session doesn't exist
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    exit 1
fi

# Portable hash function (macOS uses md5, Linux uses md5sum)
hash_fn() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q
    else
        shasum -a 256 | cut -d' ' -f1
    fi
}

STABLE_COUNT=0
LAST_HASH=""
END_TIME=$((SECONDS + TIMEOUT))
TIMED_OUT=1

while [ $SECONDS -lt $END_TIME ]; do
    # -J joins wrapped lines, tr strips carriage returns
    OUTPUT=$(tmux capture-pane -t "$SESSION" -p -J -S "-$CAPTURE_LINES" 2>/dev/null | tr -d '\r')
    HASH=$(printf '%s' "$OUTPUT" | tail -"$CAPTURE_LINES" | hash_fn)

    if [ "$HASH" = "$LAST_HASH" ]; then
        ((STABLE_COUNT++))
        if [ $STABLE_COUNT -ge "$STABLE_THRESHOLD" ]; then
            TIMED_OUT=0
            break
        fi
    else
        STABLE_COUNT=0
        LAST_HASH="$HASH"
    fi

    sleep "$POLL_INTERVAL"
done

tmux capture-pane -t "$SESSION" -p -J -S "-$CAPTURE_LINES" 2>/dev/null
[ $TIMED_OUT -eq 1 ] && exit 124 || exit 0
