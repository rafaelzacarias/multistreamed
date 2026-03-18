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
    sed -i '/push.*19350/d' /usr/local/nginx/conf/nginx.conf
fi

# Configure and start stunnel for Facebook RTMPS when Facebook streaming is enabled
# Facebook requires RTMPS (RTMP over TLS) at rtmps://live-api-s.facebook.com:443/rtmp/
# stunnel provides a local TLS proxy: nginx pushes plain RTMP to localhost:19350,
# and stunnel forwards it over TLS to Facebook's RTMPS endpoint
FB_HOST="live-api-s.facebook.com"
if [ -n "$FACEBOOK_STREAM_KEY" ]; then
    # Resolve Facebook hostname to IPv4 to avoid IPv6 issues in Azure Container Instances
    FB_CONNECT="$FB_HOST:443"
    FB_IPV4=$(getent ahostsv4 "$FB_HOST" 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$FB_IPV4" ]; then
        FB_CONNECT="$FB_IPV4:443"
        echo "[ENTRYPOINT] Resolved $FB_HOST to IPv4: $FB_IPV4 for stunnel"
    else
        echo "[ENTRYPOINT] WARNING: Could not resolve $FB_HOST to IPv4. Using hostname directly."
    fi

    mkdir -p /etc/stunnel /var/log
    cat > /etc/stunnel/stunnel.conf << EOF
pid = /var/run/stunnel.pid
setuid = nobody
setgid = nogroup
output = /var/log/stunnel.log
debug = notice

[fb-live]
client = yes
accept = 127.0.0.1:19350
connect = ${FB_CONNECT}
EOF

    # Ensure stunnel log file exists and is writable before dropping privileges
    touch /var/log/stunnel.log
    chown nobody:nogroup /var/log/stunnel.log

    if ! stunnel /etc/stunnel/stunnel.conf; then
        echo "[ENTRYPOINT] ERROR: Failed to start stunnel TLS proxy for Facebook RTMPS"
        cat /var/log/stunnel.log 2>/dev/null
        exit 1
    fi
    echo "[ENTRYPOINT] Started stunnel TLS proxy for Facebook RTMPS (127.0.0.1:19350 → $FB_CONNECT)"

    # Tail stunnel log to stdout in background so it appears in Docker logs
    tail -F /var/log/stunnel.log &
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
