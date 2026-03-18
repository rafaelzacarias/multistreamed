#!/bin/sh
# Start placeholder stream manually
# The stream name can be set via argument, PLACEHOLDER_STREAM_NAME env var, or defaults to "stream"
STREAM_NAME=${1:-${PLACEHOLDER_STREAM_NAME:-stream}}
WIDTH=${PLACEHOLDER_WIDTH:-3840}
HEIGHT=${PLACEHOLDER_HEIGHT:-2160}
FPS=${PLACEHOLDER_FPS:-60}
BITRATE=${PLACEHOLDER_BITRATE:-23500}
echo "[FAILOVER] Manually starting placeholder for '$STREAM_NAME'..."

pkill -f "ffmpeg.*placeholder" 2>/dev/null || true

# GOP size = 2 seconds of frames (YouTube requires keyframes every 2s)
GOP=$((FPS * 2))
# VBV buffer = 2x bitrate for consistent output
BUFSIZE=$((BITRATE * 2))

ffmpeg -f lavfi -i "color=c=0x1a1a2e:s=${WIDTH}x${HEIGHT}:r=${FPS}" \
    -f lavfi -i anullsrc=r=44100:cl=stereo \
    -vf "drawtext=text='Stream Starting Soon':fontsize=120:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-60, \
         drawtext=text='%{localtime\:%I\:%M\:%S %p PT}':fontsize=80:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+80" \
    -c:v libx264 -preset ultrafast -tune stillimage -pix_fmt yuv420p \
    -b:v ${BITRATE}k -maxrate ${BITRATE}k -bufsize ${BUFSIZE}k \
    -g ${GOP} -keyint_min ${GOP} -sc_threshold 0 \
    -c:a aac -b:a 128k \
    -f flv "rtmp://127.0.0.1/live/$STREAM_NAME" &

echo "[FAILOVER] Placeholder started (PID: $!)."
