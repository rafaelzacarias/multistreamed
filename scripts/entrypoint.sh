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

# Replace Facebook hostname with IPv4 address in generated nginx config to avoid IPv6 resolution
# Azure Container Instances lacks IPv6 outbound connectivity; this bypasses DNS at push time
FB_HOST="live-api-s.facebook.com"
FB_IPV4=$(getent ahostsv4 "$FB_HOST" 2>/dev/null | head -1 | awk '{print $1}')
if [ -n "$FB_IPV4" ] && [ -n "$FACEBOOK_STREAM_KEY" ]; then
    FB_HOST_ESC=$(printf '%s' "$FB_HOST" | sed 's/\./\\./g')
    sed -i "s|$FB_HOST_ESC|$FB_IPV4|g" /usr/local/nginx/conf/nginx.conf
    echo "[ENTRYPOINT] Replaced $FB_HOST with IPv4: $FB_IPV4 in nginx config"
else
    if [ -n "$FACEBOOK_STREAM_KEY" ]; then
        echo "[ENTRYPOINT] WARNING: Could not resolve $FB_HOST to IPv4. Facebook push may fail on IPv6-only resolution."
    fi
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
