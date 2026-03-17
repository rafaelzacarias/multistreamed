# Multistreamed Dashboard

## Overview

The Multistreamed Dashboard is a real-time web interface for monitoring your RTMP streaming status across multiple platforms (YouTube and Facebook). It provides visual feedback on stream health, bitrate, bandwidth, and server statistics.

## Features

- **Real-time monitoring** - Auto-refreshes every 3 seconds
- **Platform status** - Visual indicators for YouTube and Facebook
- **Stream metrics** - Bitrate, bandwidth, uptime, and active stream details
- **Server statistics** - Monitor server uptime, bandwidth in/out, and active streams
- **Responsive design** - Beautiful gradient UI that works on desktop and mobile

## Architecture

The dashboard consists of two main components:

1. **Backend API** (Node.js + Express)
   - Fetches RTMP statistics from Nginx RTMP module
   - Parses XML stats and converts to JSON
   - Exposes REST API at `/api/stats`

2. **Frontend UI** (HTML/CSS/JavaScript)
   - Single-page application with no framework dependencies
   - Displays real-time stream status with color-coded badges
   - Auto-refreshing dashboard with smooth animations

## Usage

### Local Development

1. Start the complete stack:
   ```bash
   docker compose up -d
   ```

2. Access the dashboard:
   - Dashboard UI: http://localhost:3000
   - API endpoint: http://localhost:3000/api/stats
   - Nginx stats: http://localhost:8080/stat

### Docker Deployment

The dashboard is automatically deployed when you run `docker compose up`. It's configured in the `docker-compose.yml` file with:

- Port 3000 exposed for web access
- Automatic dependency on the `multistreamed` service
- Environment variable `NGINX_STAT_URL` pointing to the Nginx stats endpoint

### Azure Deployment

#### Option 1: Azure Container Instances (ACI)

Deploy both containers:

```bash
# Deploy main streaming service
az container create \
  --resource-group multistreamed-rg \
  --name multistreamed \
  --image your-acr.azurecr.io/multistreamed:latest \
  --ports 1935 8080 \
  --environment-variables \
    YOUTUBE_STREAM_KEY=<key> \
    FACEBOOK_STREAM_KEY=<key>

# Deploy dashboard
az container create \
  --resource-group multistreamed-rg \
  --name multistreamed-dashboard \
  --image your-acr.azurecr.io/multistreamed-dashboard:latest \
  --ports 3000 \
  --environment-variables \
    NGINX_STAT_URL=http://<multistreamed-ip>:8080/stat
```

#### Option 2: Azure VM

1. Deploy an Azure VM with Docker installed
2. Clone the repository
3. Configure `.env` file with your stream keys
4. Run: `docker compose up -d`
5. Configure NSG rules:
   - Port 1935: RTMP ingest
   - Port 8080: Nginx stats (optional, internal use)
   - Port 3000: Dashboard web UI

## API Reference

### GET /api/stats

Returns comprehensive streaming statistics in JSON format.

**Response:**
```json
{
  "timestamp": "2026-03-16T15:58:03.011Z",
  "nginx": {
    "version": "1.24.0",
    "uptime": 3600
  },
  "server": {
    "bandwidth": {
      "in": 5242880,
      "out": 15728640
    },
    "bytesIn": 18874368000,
    "bytesOut": 56623104000
  },
  "streams": [
    {
      "name": "stream-name",
      "time": 3600000,
      "bandwidth": {
        "video": 4000000,
        "audio": 128000
      },
      "bytesIn": 14400000000,
      "bytesOut": 43200000000,
      "clients": []
    }
  ],
  "platforms": {
    "youtube": {
      "status": "connected",
      "viewers": 0,
      "bitrate": 4128000
    },
    "facebook": {
      "status": "connected",
      "viewers": 0,
      "bitrate": 4128000
    }
  }
}
```

## Troubleshooting

### Dashboard shows "Failed to fetch stream statistics"

1. Verify the `multistreamed` service is running:
   ```bash
   docker ps
   ```

2. Check if Nginx stats endpoint is accessible:
   ```bash
   curl http://localhost:8080/stat
   ```

3. Check dashboard logs:
   ```bash
   docker logs multistreamed-dashboard
   ```

### Platform status shows "disconnected" when streaming

The current implementation detects active streams based on bandwidth metrics. If you see "disconnected" while streaming:

1. Verify your stream keys are correctly configured in `.env`
2. Check if OBS is successfully connecting to the RTMP server
3. View Nginx logs: `docker logs multistreamed`

### Port 3000 is already in use

Change the dashboard port in `docker-compose.yml`:

```yaml
dashboard:
  ports:
    - "8000:3000"  # Change 8000 to your preferred port
```

Then access the dashboard at `http://localhost:8000`

## File Structure

```
dashboard/
├── Dockerfile              # Container image definition
├── package.json            # Node.js dependencies
├── .dockerignore          # Files to exclude from Docker build
├── src/
│   └── server.js          # Express API server
└── public/
    └── index.html         # Dashboard UI (HTML/CSS/JavaScript)
```

## Configuration

### Environment Variables

- `PORT` - Dashboard HTTP port (default: 3000)
- `NGINX_STAT_URL` - URL to Nginx RTMP stats endpoint (default: http://multistreamed:8080/stat)

### Customization

To customize the dashboard appearance, edit `/dashboard/public/index.html`:

- Change refresh interval (line ~420): `setInterval(fetchStats, 3000)`
- Modify colors and styling in the `<style>` section
- Add additional platform cards by duplicating the card HTML structure

## Security Considerations

1. **No Authentication** - The dashboard currently has no authentication. If exposing to the internet, consider:
   - Adding reverse proxy with basic auth (Nginx, Caddy)
   - Using a VPN or private network
   - Implementing authentication in the Express server

2. **Internal Network** - For production, consider keeping the dashboard on an internal network and using a VPN for access

3. **CORS** - The dashboard API doesn't require CORS headers since it's server-side rendered. The browser only loads static HTML/CSS/JavaScript.

## Performance

- **Resource Usage**: ~50MB RAM, negligible CPU
- **Network**: Minimal - only fetches stats XML every 3 seconds
- **Scaling**: Can handle hundreds of concurrent viewers without issues

## Future Enhancements

Potential improvements:

- [ ] Historical data and charts (bandwidth over time)
- [ ] Alert notifications (email, webhook)
- [ ] Multiple stream support (view all streams)
- [ ] Platform-specific viewer counts (requires platform APIs)
- [ ] Stream key management UI
- [ ] Authentication and user management
- [ ] WebSocket support for real-time updates (instead of polling)

## License

Part of the Multistreamed project. See main README for license information.
