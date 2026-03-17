#!/bin/sh
echo "[FAILOVER] Stopping placeholder stream..."
pkill -f "ffmpeg.*placeholder" 2>/dev/null || true
echo "[FAILOVER] Placeholder stopped."
