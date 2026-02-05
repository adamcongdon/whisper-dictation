#!/bin/bash
# Start the whisper.cpp transcription server

MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
PORT="${WHISPER_PORT:-8889}"
HOST="${WHISPER_HOST:-0.0.0.0}"

# Check if already running
if pgrep -f "whisper-server.*$PORT" > /dev/null; then
    echo "Whisper server already running on port $PORT"
    exit 0
fi

# Check model exists
if [ ! -f "$MODEL" ]; then
    echo "Model not found: $MODEL"
    echo "Download with: curl -L -o $MODEL https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
    exit 1
fi

echo "Starting whisper-server..."
echo "  Model: $MODEL"
echo "  Host:  $HOST"
echo "  Port:  $PORT"
echo ""

# Start server in background
nohup whisper-server \
    -m "$MODEL" \
    --host "$HOST" \
    --port "$PORT" \
    > /tmp/whisper-server.log 2>&1 &

sleep 2

if pgrep -f "whisper-server.*$PORT" > /dev/null; then
    echo "Server started successfully!"
    echo "  Web UI:  http://localhost:$PORT"
    echo "  API:     http://localhost:$PORT/inference"
    echo ""
    echo "Test with:"
    echo "  curl http://localhost:$PORT/inference -F file=@audio.wav -F response_format=json"
else
    echo "Failed to start server. Check /tmp/whisper-server.log"
    exit 1
fi
