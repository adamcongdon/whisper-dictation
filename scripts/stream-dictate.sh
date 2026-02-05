#!/bin/bash
# Real-time streaming dictation with live display
# Opens a window showing text as you speak

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
OUTPUT_FILE="/tmp/dictation-stream.txt"
STEP="${STEP:-2000}"      # Process every 2 seconds
LENGTH="${LENGTH:-5000}"  # 5 second rolling window

# Clear previous output
> "$OUTPUT_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎤 STREAMING DICTATION - Speak now..."
echo "   Press Ctrl+C when done"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Trap Ctrl+C to copy output
cleanup() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Read final output and clean it
    FINAL=$(cat "$OUTPUT_FILE" | python3 -c "
import sys, re
text = sys.stdin.read()
# Remove whisper artifacts and normalize
text = re.sub(r'\[BLANK_AUDIO\]', '', text)
text = re.sub(r'\(.*?\)', '', text)
text = re.sub(r'\s+', ' ', text).strip()
print(text)
" 2>/dev/null)

    if [ -n "$FINAL" ]; then
        echo "📋 Copied to clipboard:"
        echo "$FINAL"
        echo -n "$FINAL" | pbcopy
    else
        echo "No transcription captured"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Run whisper-stream with real-time output
whisper-stream \
    -m "$MODEL" \
    --step "$STEP" \
    --length "$LENGTH" \
    --keep 500 \
    -f "$OUTPUT_FILE" \
    2>/dev/null | while IFS= read -r line; do
        # Filter and display each line as it comes
        cleaned=$(echo "$line" | sed 's/\[BLANK_AUDIO\]//g' | tr -s ' ')
        if [ -n "$cleaned" ] && [ "$cleaned" != " " ]; then
            echo "$cleaned"
        fi
    done
