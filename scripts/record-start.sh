#!/bin/bash
# Start recording - called when hotkey is pressed
# ROBUST: Kills ALL existing recordings first

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

TEMP_FILE="/tmp/dictation-ptt.wav"
PID_FILE="/tmp/dictation-ptt.pid"
LOCK_FILE="/tmp/dictation-ptt.lock"

# Acquire lock (prevent concurrent starts)
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt 30 ]; then
        echo "Recording already in progress (lock age: ${LOCK_AGE}s)"
        exit 0
    fi
    # Stale lock, remove it
    rm -f "$LOCK_FILE"
fi

# Create lock
touch "$LOCK_FILE"

# FORCE KILL all existing rec processes (not just by PID)
pkill -9 -x rec 2>/dev/null
sleep 0.1

# Clean up old files
rm -f "$PID_FILE" "$TEMP_FILE"

# Start fresh recording
rec -q "$TEMP_FILE" rate 16k channels 1 &
REC_PID=$!
echo $REC_PID > "$PID_FILE"

echo "Recording started (PID: $REC_PID)"
