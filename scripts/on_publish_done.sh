#!/bin/sh
# Called by NGINX-RTMP when a publisher disconnects
STREAM_NAME=$1
CLIENT_ADDR=$2

# Ignore if this is the placeholder itself disconnecting (from localhost)
if [ "$CLIENT_ADDR" = "127.0.0.1" ]; then
    echo "[FAILOVER] Placeholder disconnected from '$STREAM_NAME', ignoring."
    exit 0
fi

echo "[FAILOVER] Live stream '$STREAM_NAME' stopped. Waiting before starting placeholder..."

# Wait to see if the encoder reconnects quickly (configurable, defaults to 5 seconds)
sleep "${PLACEHOLDER_RECONNECT_DELAY:-5}"

# Check if a new publisher has already reconnected by checking the stat endpoint
ACTIVE=$(wget -q -O - http://127.0.0.1:8080/stat 2>/dev/null | grep -c '<publishing>' || true)
if [ "$ACTIVE" -gt 0 ]; then
    echo "[FAILOVER] Encoder reconnected. No placeholder needed."
    exit 0
fi

# Kill any existing placeholder first (in case of race condition)
pkill -f "ffmpeg.*placeholder" 2>/dev/null || true

# Start placeholder stream
echo "[FAILOVER] Starting placeholder stream for '$STREAM_NAME'..."
ffmpeg -re -stream_loop -1 -i /assets/placeholder.mp4 \
    -c:v libx264 -preset ultrafast -tune stillimage \
    -c:a aac -b:a 128k \
    -f flv "rtmp://127.0.0.1/live/$STREAM_NAME" &

echo "[FAILOVER] Placeholder stream started (PID: $!)."
