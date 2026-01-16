#!/bin/bash
# Poll tmux capture-pane until output stabilizes or timeout
# Usage: tmux-poll-wait.sh <session> [timeout_seconds]
# Exits after 3 consecutive unchanged polls (3s each) or timeout (default 60s)

SESSION="${1:-claude-local}"
TIMEOUT="${2:-60}"
POLL_INTERVAL=3
STABLE_COUNT=0
LAST_HASH=""
END_TIME=$((SECONDS + TIMEOUT))

while [ $SECONDS -lt $END_TIME ]; do
    OUTPUT=$(tmux capture-pane -t "$SESSION" -p -S -100 2>/dev/null)
    HASH=$(printf '%s' "$OUTPUT" | tail -100 | md5sum | cut -d' ' -f1)

    if [ "$HASH" = "$LAST_HASH" ]; then
        ((STABLE_COUNT++))
        [ $STABLE_COUNT -ge 3 ] && break
    else
        STABLE_COUNT=0
        LAST_HASH="$HASH"
    fi

    sleep $POLL_INTERVAL
done

tmux capture-pane -t "$SESSION" -p -S -100 2>/dev/null
