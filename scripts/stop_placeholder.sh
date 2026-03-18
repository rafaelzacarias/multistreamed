#!/bin/sh
echo "[FAILOVER] Stopping placeholder stream..."
if [ -f /tmp/placeholder.pid ]; then
    PID=$(cat /tmp/placeholder.pid)
    # Verify the PID still belongs to an ffmpeg process before killing
    if [ -f "/proc/$PID/cmdline" ] && tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null | grep -q ffmpeg; then
        kill "$PID" 2>/dev/null || true
    fi
    rm -f /tmp/placeholder.pid
fi
echo "[FAILOVER] Placeholder stopped."
