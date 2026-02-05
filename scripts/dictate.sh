#!/bin/bash
# Real-time dictation using whisper-stream
# Records from microphone and outputs transcription

MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
DURATION="${DICTATION_DURATION:-30000}"  # 30 seconds default
OUTPUT_FILE="/tmp/dictation-output.txt"
CLIPBOARD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clipboard)
            CLIPBOARD=true
            shift
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: dictate.sh [options]"
            echo ""
            echo "Options:"
            echo "  -c, --clipboard     Copy result to clipboard"
            echo "  -d, --duration MS   Recording duration in ms (default: 30000)"
            echo "  -m, --model PATH    Path to whisper model"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Check model exists
if [ ! -f "$MODEL" ]; then
    echo "Model not found: $MODEL"
    exit 1
fi

echo "Starting dictation (${DURATION}ms)..."
echo "Speak now! Press Ctrl+C to stop early."
echo ""

# Run whisper-stream and capture output
whisper-stream \
    -m "$MODEL" \
    --length "$DURATION" \
    --step 3000 \
    --keep 200 \
    -f "$OUTPUT_FILE" \
    2>/dev/null

# Read the output
if [ -f "$OUTPUT_FILE" ]; then
    RESULT=$(cat "$OUTPUT_FILE")
    echo ""
    echo "━━━ Transcription ━━━"
    echo "$RESULT"
    echo "━━━━━━━━━━━━━━━━━━━━━"

    if [ "$CLIPBOARD" = true ]; then
        echo "$RESULT" | pbcopy
        echo "(Copied to clipboard)"
    fi

    rm -f "$OUTPUT_FILE"
else
    echo "No transcription output"
fi
