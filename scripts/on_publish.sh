#!/bin/sh
# Called by NGINX-RTMP when a publisher connects
STREAM_NAME=$1
CLIENT_ADDR=$2

# Ignore if this is the placeholder itself connecting (from localhost)
if [ "$CLIENT_ADDR" = "127.0.0.1" ]; then
    echo "[FAILOVER] Placeholder connected on '$STREAM_NAME', ignoring."
    exit 0
fi

echo "[FAILOVER] Live stream '$STREAM_NAME' started publishing from $CLIENT_ADDR. Stopping placeholder..."
pkill -f "ffmpeg.*placeholder" 2>/dev/null || true
echo "[FAILOVER] Placeholder stopped. Live stream is active."
