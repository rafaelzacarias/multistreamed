#!/bin/sh
set -e

# Validate template exists
if [ ! -f /etc/nginx/nginx.conf.template ]; then
    echo "ERROR: Nginx config template not found at /etc/nginx/nginx.conf.template"
    exit 1
fi

# Set defaults for optional variables to prevent literal ${VAR} in config
: "${YOUTUBE_STREAM_KEY:=}"
: "${FACEBOOK_STREAM_KEY:=}"

# Substitute environment variables into the nginx config template
envsubst '${YOUTUBE_STREAM_KEY} ${FACEBOOK_STREAM_KEY}' \
    < /etc/nginx/nginx.conf.template \
    > /usr/local/nginx/conf/nginx.conf

# Remove push directives for unconfigured platforms
if [ -z "$YOUTUBE_STREAM_KEY" ]; then
    sed -i '/push.*youtube\.com/d' /usr/local/nginx/conf/nginx.conf
fi
if [ -z "$FACEBOOK_STREAM_KEY" ]; then
    sed -i '/push.*facebook\.com/d' /usr/local/nginx/conf/nginx.conf
fi

echo "========================================"
echo "  Multistreamed - RTMP Restreamer"
echo "========================================"
echo "RTMP ingest:  rtmp://<server-ip>/live"
echo "Health check: http://<server-ip>:8080/health"
echo "Stream stats: http://<server-ip>:8080/stat"
echo ""
echo "Relay targets:"

if [ -n "$YOUTUBE_STREAM_KEY" ]; then
    echo "  ✅ YouTube Live"
else
    echo "  ⚠️  YouTube Live (no stream key configured)"
fi

if [ -n "$FACEBOOK_STREAM_KEY" ]; then
    echo "  ✅ Facebook Live"
else
    echo "  ⚠️  Facebook Live (no stream key configured)"
fi

echo "========================================"
echo ""

# Start nginx in background
/usr/local/nginx/sbin/nginx -g "daemon off;" &
NGINX_PID=$!

# Give nginx a moment to initialize before starting dependent processes
sleep 2

# Verify nginx started successfully
if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    echo "ERROR: nginx failed to start"
    exit 1
fi

# Start placeholder if enabled (defaults to true)
if [ "${PLACEHOLDER_ENABLED:-true}" = "true" ]; then
    echo "[FAILOVER] Starting initial placeholder stream..."
    /scripts/start_placeholder.sh "${PLACEHOLDER_STREAM_NAME:-stream}" &
fi

# Wait for nginx (main process)
wait $NGINX_PID
