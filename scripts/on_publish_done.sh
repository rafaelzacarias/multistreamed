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

echo "[FAILOVER] Starting placeholder stream..."
/scripts/start_placeholder.sh "${PLACEHOLDER_STREAM_NAME:-stream}"
