#!/bin/sh
# Start placeholder stream manually
# The stream name can be set via argument, PLACEHOLDER_STREAM_NAME env var, or defaults to "stream"
STREAM_NAME=${1:-${PLACEHOLDER_STREAM_NAME:-stream}}
echo "[FAILOVER] Manually starting placeholder for '$STREAM_NAME'..."

pkill -f "ffmpeg.*placeholder" 2>/dev/null || true

ffmpeg -re -stream_loop -1 -i /assets/placeholder.mp4 \
    -c:v libx264 -preset ultrafast -tune stillimage \
    -c:a aac -b:a 128k \
    -f flv "rtmp://127.0.0.1/live/$STREAM_NAME" &

echo "[FAILOVER] Placeholder started (PID: $!)."
