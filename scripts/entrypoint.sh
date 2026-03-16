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
: "${INSTAGRAM_STREAM_KEY:=}"
: "${INSTAGRAM_RTMP_HOST:=}"

# Substitute environment variables into the nginx config template
envsubst '${YOUTUBE_STREAM_KEY} ${FACEBOOK_STREAM_KEY} ${INSTAGRAM_STREAM_KEY} ${INSTAGRAM_RTMP_HOST}' \
    < /etc/nginx/nginx.conf.template \
    > /usr/local/nginx/conf/nginx.conf

# Remove push directives for unconfigured platforms
if [ -z "$YOUTUBE_STREAM_KEY" ]; then
    sed -i '/push.*youtube\.com/d' /usr/local/nginx/conf/nginx.conf
fi
if [ -z "$FACEBOOK_STREAM_KEY" ]; then
    sed -i '/push.*facebook\.com/d' /usr/local/nginx/conf/nginx.conf
fi
if [ -z "$INSTAGRAM_STREAM_KEY" ] || [ -z "$INSTAGRAM_RTMP_HOST" ]; then
    sed -i '/push.*INSTAGRAM/d' /usr/local/nginx/conf/nginx.conf
    sed -i '/push.*rtmp:\/\/\/rtmp/d' /usr/local/nginx/conf/nginx.conf
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

if [ -n "$INSTAGRAM_STREAM_KEY" ] && [ -n "$INSTAGRAM_RTMP_HOST" ]; then
    echo "  ✅ Instagram Live (via $INSTAGRAM_RTMP_HOST)"
else
    echo "  ⚠️  Instagram Live (not configured)"
fi

echo "========================================"
echo ""

exec /usr/local/nginx/sbin/nginx -g "daemon off;"
