#!/bin/bash
# Stop the whisper.cpp transcription server

PORT="${WHISPER_PORT:-8889}"

if pkill -f "whisper-server.*$PORT"; then
    echo "Whisper server stopped"
else
    echo "No whisper server running on port $PORT"
fi
