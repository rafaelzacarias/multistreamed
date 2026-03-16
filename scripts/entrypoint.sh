#!/bin/sh
set -e

# Substitute environment variables into the nginx config template
envsubst '${YOUTUBE_STREAM_KEY} ${FACEBOOK_STREAM_KEY} ${INSTAGRAM_STREAM_KEY} ${INSTAGRAM_RTMP_HOST}' \
    < /etc/nginx/nginx.conf.template \
    > /usr/local/nginx/conf/nginx.conf

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
