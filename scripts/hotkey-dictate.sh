#!/bin/bash
# Hotkey-triggered dictation script
# Records audio, transcribes via whisper, types result into active window
#
# Usage: ./hotkey-dictate.sh [--type|--clipboard|--both]
#   --type      Type result into active window (default)
#   --clipboard Copy result to clipboard only
#   --both      Type AND copy to clipboard

# CRITICAL: Set PATH for Automator (it runs with minimal environment)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Debug logging - check /tmp/dictation-debug.log if something fails
DEBUG_LOG="/tmp/dictation-debug.log"
exec 2>>"$DEBUG_LOG"
echo "=== $(date) ===" >> "$DEBUG_LOG"
echo "PATH: $PATH" >> "$DEBUG_LOG"
echo "PWD: $PWD" >> "$DEBUG_LOG"

set -e

# Configuration
WHISPER_PORT="${WHISPER_PORT:-8889}"
WHISPER_HOST="${WHISPER_HOST:-localhost}"
RECORD_DURATION="${RECORD_DURATION:-60}"  # Max seconds (increased for longer dictations)
SILENCE_DURATION="${SILENCE_DURATION:-2.0}"  # Stop after this much silence
SILENCE_THRESHOLD="${SILENCE_THRESHOLD:-3%}"  # Silence threshold (higher = less sensitive to background noise)
TEMP_FILE="/tmp/dictation-$$.wav"
MODE="${1:---type}"

# Cleanup on exit
cleanup() {
    rm -f "$TEMP_FILE" 2>/dev/null
}
trap cleanup EXIT

# Check whisper server is running
echo "Checking whisper server at ${WHISPER_HOST}:${WHISPER_PORT}..." >> "$DEBUG_LOG"
if ! curl -s "http://${WHISPER_HOST}:${WHISPER_PORT}/" >/dev/null 2>&1; then
    echo "ERROR: Whisper server not running" >> "$DEBUG_LOG"
    osascript -e 'display notification "Whisper server not running. Check /tmp/dictation-debug.log" with title "Dictation Error"'
    exit 1
fi
echo "Server OK" >> "$DEBUG_LOG"

# Check rec command exists
if ! command -v rec &> /dev/null; then
    echo "ERROR: 'rec' command not found. Install sox: brew install sox" >> "$DEBUG_LOG"
    osascript -e 'display notification "rec not found. brew install sox" with title "Dictation Error"'
    exit 1
fi
echo "rec found at: $(which rec)" >> "$DEBUG_LOG"

# Visual feedback - start recording
osascript -e 'display notification "Recording... speak now" with title "Dictation" sound name "Ping"'

# Record audio with silence detection
# silence 1 0.1 THRESH = start after 0.1s of sound above threshold
# 1 DURATION THRESH = stop after DURATION seconds below threshold
echo "Starting recording to $TEMP_FILE (max ${RECORD_DURATION}s, silence ${SILENCE_DURATION}s @ ${SILENCE_THRESHOLD})..." >> "$DEBUG_LOG"
rec -q "$TEMP_FILE" \
    rate 16k \
    channels 1 \
    trim 0 "$RECORD_DURATION" \
    silence 1 0.1 "$SILENCE_THRESHOLD" 1 "$SILENCE_DURATION" "$SILENCE_THRESHOLD" \
    2>>"$DEBUG_LOG"
echo "Recording finished. File size: $(ls -la "$TEMP_FILE" 2>/dev/null | awk '{print $5}') bytes" >> "$DEBUG_LOG"

# Check if we got audio
if [ ! -s "$TEMP_FILE" ]; then
    osascript -e 'display notification "No audio recorded" with title "Dictation Error"'
    exit 1
fi

# Visual feedback - processing
osascript -e 'display notification "Transcribing..." with title "Dictation"'

# Send to whisper server
echo "Sending to whisper server..." >> "$DEBUG_LOG"
RESPONSE=$(curl -s "http://${WHISPER_HOST}:${WHISPER_PORT}/inference" \
    -F "file=@${TEMP_FILE}" \
    -F "response_format=json" \
    -F "temperature=0.0")
echo "Response: $RESPONSE" >> "$DEBUG_LOG"

# Extract text from JSON response and clean up whisper artifacts
TEXT=$(echo "$RESPONSE" | python3 -c "
import sys, json, re
text = json.load(sys.stdin).get('text', '').strip()
# Remove [BLANK_AUDIO] and similar whisper artifacts
text = re.sub(r'\[BLANK_AUDIO\]', '', text)
text = re.sub(r'\(.*?\)', '', text)  # Remove (beeping), (music), etc.
text = re.sub(r'\s+', ' ', text).strip()  # Normalize whitespace
print(text)
" 2>/dev/null)
echo "Extracted text: $TEXT" >> "$DEBUG_LOG"

if [ -z "$TEXT" ]; then
    osascript -e 'display notification "No transcription returned" with title "Dictation Error"'
    exit 1
fi

# Output based on mode
case "$MODE" in
    --clipboard)
        echo -n "$TEXT" | pbcopy
        osascript -e "display notification \"Copied: ${TEXT:0:50}...\" with title \"Dictation Complete\""
        ;;
    --both)
        echo -n "$TEXT" | pbcopy
        # Type into active window using AppleScript
        osascript -e "tell application \"System Events\" to keystroke \"$TEXT\""
        osascript -e "display notification \"Typed & copied\" with title \"Dictation Complete\""
        ;;
    --type|*)
        # Type into active window using AppleScript
        osascript -e "tell application \"System Events\" to keystroke \"$TEXT\""
        osascript -e "display notification \"Typed: ${TEXT:0:50}...\" with title \"Dictation Complete\""
        ;;
esac

echo "$TEXT"
