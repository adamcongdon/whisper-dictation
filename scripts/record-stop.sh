#!/bin/bash
# Stop recording and transcribe - called when hotkey is released
# ROBUST: Always cleans up, handles edge cases

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

TEMP_FILE="/tmp/dictation-ptt.wav"
PID_FILE="/tmp/dictation-ptt.pid"
LOCK_FILE="/tmp/dictation-ptt.lock"
MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
WHISPER_PORT="${WHISPER_PORT:-8889}"
MODE="${1:---type}"

# Always remove lock first
rm -f "$LOCK_FILE"

# Stop ALL rec processes (robust)
pkill rec 2>/dev/null
sleep 0.2

# Clean up PID file
rm -f "$PID_FILE"

# Check we have audio
if [ ! -s "$TEMP_FILE" ]; then
    echo "No audio file found"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "Audio file too small ($FILE_SIZE bytes), skipping"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Transcribe: try server first, fall back to CLI
if curl -s "http://localhost:$WHISPER_PORT/" >/dev/null 2>&1; then
    RESPONSE=$(curl -s "http://localhost:$WHISPER_PORT/inference" \
        -F "file=@${TEMP_FILE}" \
        -F "response_format=json" \
        -F "temperature=0.0" \
        --max-time 30)
    TEXT=$(echo "$RESPONSE" | python3 -c "
import sys, json, re
try:
    text = json.load(sys.stdin).get('text', '').strip()
    text = re.sub(r'\[BLANK_AUDIO\]', '', text)
    text = re.sub(r'\(.*?\)', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    print(text)
except:
    pass
" 2>/dev/null)
else
    # Fallback to CLI (slower)
    TEXT=$(whisper-cli -m "$MODEL" -f "$TEMP_FILE" --no-timestamps 2>/dev/null | python3 -c "
import sys, re
text = sys.stdin.read().strip()
text = re.sub(r'\[BLANK_AUDIO\]', '', text)
text = re.sub(r'\(.*?\)', '', text)
text = re.sub(r'\s+', ' ', text).strip()
print(text)
" 2>/dev/null)
fi

# Cleanup audio file
rm -f "$TEMP_FILE"

# Skip if no text
if [ -z "$TEXT" ]; then
    echo "No transcription"
    exit 1
fi

# Output based on mode
case "$MODE" in
    --clipboard)
        echo -n "$TEXT" | pbcopy
        echo "Copied: $TEXT"
        ;;
    --type|*)
        # Escape special characters for AppleScript
        ESCAPED=$(echo "$TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
        osascript -e "tell application \"System Events\" to keystroke \"$ESCAPED\""
        echo "Typed: $TEXT"
        ;;
esac
