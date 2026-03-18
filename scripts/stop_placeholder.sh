#!/bin/sh
echo "[FAILOVER] Stopping placeholder stream..."
if [ -f /tmp/placeholder.pid ]; then
    kill "$(cat /tmp/placeholder.pid)" 2>/dev/null || true
    rm -f /tmp/placeholder.pid
fi
echo "[FAILOVER] Placeholder stopped."
