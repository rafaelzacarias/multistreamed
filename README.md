# 🎥 Multistreamed

> A self-hosted, Docker-based restreaming service that takes a single RTMP input (from OBS or any encoder) and simultaneously broadcasts to **Facebook** and **YouTube**. Designed to deploy on **Azure**.

## 🚀 Quick Deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frafaelzacarias%2Fmultistreamed%2Fmain%2Fazuredeploy.json)

Click the button above to deploy the entire stack to Azure in minutes! You'll be prompted to enter your stream keys during deployment.

## Overview

**Multistreamed** works like [Restream.io](https://restream.io) but runs on your own infrastructure. You point OBS (or any RTMP-compatible encoder) at this service, and it relays your stream to multiple platforms at the same time — no third-party middleman.

```
┌─────────┐       RTMP        ┌──────────────────┐       RTMP        ┌─────────────┐
│   OBS   │ ────────────────► │  Multistreamed   │ ──────────────►  │  YouTube    │
│ Studio  │                   │  (Nginx RTMP +   │ ──────RTMPS───►  │  Facebook   │
└─────────┘                   │   Docker/Azure)  │                  └─────────────┘
                              └──────────────────┘
```

## Features

- 🔀 **Multi-platform relay** — Stream to Facebook and YouTube simultaneously
- 📡 **RTMP ingest** — Compatible with OBS Studio, Streamlabs, and any RTMP encoder
- 🐳 **Dockerized** — Runs in containers for easy deployment and portability
- ☁️ **Azure-ready** — Designed to deploy on Azure (Container Instances, App Service, or VM)
- ⚡ **Low latency** — Passthrough relay (no transcoding) for minimal delay
- 🔐 **Secure key management** — Stream keys configured via environment variables
- 📊 **Health monitoring** — HTTP endpoint to check stream status
- 🎯 **Web Dashboard** — Real-time monitoring dashboard to view stream status, bitrate, and platform health
- 🔄 **Automatic Failover** — Placeholder "Starting Soon" stream plays automatically when no encoder is connected

## Tech Stack

| Component | Technology |
|---|---|
| **RTMP Server** | Nginx with [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module) |
| **Dashboard** | Node.js + Express + HTML/CSS/JavaScript |
| **Containerization** | Docker + Docker Compose |
| **Cloud** | Microsoft Azure (ACI / App Service / VM) |
| **Encoder** | OBS Studio (or any RTMP source) |
| **Relay targets** | YouTube RTMP, Facebook Live RTMPS |

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Docker Container         │
                    │                                  │
 OBS (RTMP) ──────►│  Nginx RTMP Server               │
                    │    ├── push → YouTube RTMP       │
                    │    └── push → Facebook RTMPS     │
                    │                                  │
                    │  HTTP Status Server (:8080)      │
                    └─────────────────────────────────┘
                              Hosted on Azure

                    ┌─────────────────────────────────┐
                    │    Dashboard Container (:3000)   │
                    │  Real-time stream monitoring     │
                    └─────────────────────────────────┘
```

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/)
- Stream keys for your target platforms:
  - **YouTube**: Settings → Stream → Stream Key
  - **Facebook**: Live Producer → Stream Key
- An [Azure account](https://azure.microsoft.com/) (for cloud deployment)

### Configuration

1. **Clone the repository:**

```bash
git clone https://github.com/rafaelzacarias/multistreamed.git
cd multistreamed
```

2. **Create a `.env` file** with your stream keys:

```env
YOUTUBE_STREAM_KEY=your-youtube-stream-key
FACEBOOK_STREAM_KEY=your-facebook-stream-key
```

3. **Start the service:**

```bash
docker-compose up -d
```

4. **Configure OBS:**
   - Go to **Settings → Stream**
   - Service: **Custom**
   - Server: `rtmp://YOUR_SERVER_IP/live`
   - Stream Key: _(leave blank or use a custom auth key)_

5. **Hit "Start Streaming" in OBS** — your stream will be relayed to all configured platforms! 🎉

6. **Access the dashboard:**
   - Open your browser and go to `http://localhost:3000`
   - The dashboard will show real-time status of YouTube and Facebook streams
   - Monitor bitrate, bandwidth, uptime, and active stream details

## Project Structure

```
multistreamed/
├── docker-compose.yml        # Container orchestration
├── Dockerfile                # Nginx RTMP image build
├── nginx.conf                # RTMP server configuration with push directives
├── .env.example              # Example environment variables
├── dashboard/
│   ├── Dockerfile            # Dashboard container image
│   ├── package.json          # Node.js dependencies
│   ├── src/
│   │   └── server.js         # Express API server
│   └── public/
│       └── index.html        # Dashboard UI
├── scripts/
│   ├── entrypoint.sh         # Startup script (substitutes env vars into nginx.conf)
│   ├── on_publish.sh         # NGINX-RTMP hook: called when encoder starts publishing
│   ├── on_publish_done.sh    # NGINX-RTMP hook: called when encoder stops publishing
│   ├── start_placeholder.sh  # Manually start the placeholder stream
│   └── stop_placeholder.sh   # Manually stop the placeholder stream
├── docs/
│   └── azure-deployment.md   # Azure deployment guide
└── README.md
```

## Automatic Placeholder / Failover Stream

When no live encoder is connected, **Multistreamed** automatically pushes a "Stream Starting Soon" placeholder video to all configured platforms. The moment your encoder connects, the placeholder stops and your live feed takes over. If the encoder disconnects or crashes, the placeholder automatically restarts after a brief delay.

### How it works

```
[Container starts]
      │
      ▼
Placeholder stream starts ──► RTMP relay ──► YouTube / Facebook / Instagram
      │
      │  Encoder connects (OBS, etc.)
      ▼
on_publish.sh fires ──► placeholder killed ──► live feed streams
      │
      │  Encoder disconnects / crashes
      ▼
on_publish_done.sh fires ──► wait 5s ──► check if reconnected
      │                                        │
      │  (not reconnected)                     │ (reconnected → no-op)
      ▼
Placeholder stream restarts
```

This is implemented using NGINX-RTMP's `exec_publish` and `exec_publish_done` event hooks combined with FFmpeg.

### Configuration

| Variable | Default | Description |
|---|---|---|
| `PLACEHOLDER_ENABLED` | `true` | Set to `false` to disable the placeholder stream entirely |
| `PLACEHOLDER_STREAM_NAME` | `stream` | RTMP stream name the placeholder publishes to (must match your encoder's stream key) |
| `PLACEHOLDER_RECONNECT_DELAY` | `5` | Seconds to wait after encoder disconnects before starting placeholder |
| `PLACEHOLDER_BITRATE` | `23500` | Video bitrate in Kbps for the placeholder stream (should match your target platform requirements) |

### Customising the placeholder video

The default placeholder is a 10-second looping video generated at image build time with "Stream Starting Soon" text at **4K resolution (3840x2160) and 60fps** at **23500 Kbps**.

#### Option 1: Change resolution and FPS at build time

You can customize the placeholder video resolution and frame rate by passing build arguments:

```bash
docker build \
  --build-arg PLACEHOLDER_WIDTH=1920 \
  --build-arg PLACEHOLDER_HEIGHT=1080 \
  --build-arg PLACEHOLDER_FPS=30 \
  --build-arg PLACEHOLDER_BITRATE=4500 \
  -t multistreamed .
```

Or in docker-compose.yml:

```yaml
services:
  multistreamed:
    build:
      context: .
      args:
        PLACEHOLDER_WIDTH: 1920
        PLACEHOLDER_HEIGHT: 1080
        PLACEHOLDER_FPS: 30
        PLACEHOLDER_BITRATE: 4500
```

**Default values:**
- `PLACEHOLDER_WIDTH`: 3840 (4K)
- `PLACEHOLDER_HEIGHT`: 2160 (4K)
- `PLACEHOLDER_FPS`: 60
- `PLACEHOLDER_BITRATE`: 23500 (Kbps)

#### Option 2: Use a custom video file

To use your own pre-made placeholder video:

1. Build the image normally (this generates `/assets/placeholder.mp4` inside the container)
2. Replace it by mounting a custom video file:

```yaml
# docker-compose.yml
services:
  multistreamed:
    volumes:
      - ./my-placeholder.mp4:/assets/placeholder.mp4
```

Or rebuild the image after placing a custom `placeholder.mp4` in an `assets/` directory and updating the `Dockerfile` `COPY` instruction.

### Manual control

You can manually start or stop the placeholder from inside the running container:

```bash
# Start placeholder for stream key "stream"
docker exec multistreamed /scripts/start_placeholder.sh stream

# Stop placeholder
docker exec multistreamed /scripts/stop_placeholder.sh
```

## Deployment on Azure

### 🎯 Option 1: Single-Click Deployment (Recommended)

The fastest way to get started! Click the **Deploy to Azure** button at the top of this README. The deployment wizard will:

1. Prompt you for your Azure subscription and resource group
2. Ask for your YouTube and Facebook stream keys (stored securely)
3. Deploy both the RTMP server and monitoring dashboard as a container group
4. Provide you with the RTMP URL and dashboard URL immediately after deployment

**What gets deployed:**
- Azure Container Instance (ACI) with both containers
- Public IP with DNS name for easy access
- Ports 1935 (RTMP), 8080 (stats), and 3000 (dashboard) exposed
- Secure environment variables for your stream keys

For detailed step-by-step instructions, see [docs/azure-deployment.md](docs/azure-deployment.md#single-click-deployment).

### Option 2: Azure Container Instances (ACI)

```bash
az container create \
  --resource-group multistreamed-rg \
  --name multistreamed \
  --image your-acr.azurecr.io/multistreamed:latest \
  --ports 1935 8080 \
  --environment-variables \
    YOUTUBE_STREAM_KEY=<key> \
    FACEBOOK_STREAM_KEY=<key>

az container create \
  --resource-group multistreamed-rg \
  --name multistreamed-dashboard \
  --image your-acr.azurecr.io/multistreamed-dashboard:latest \
  --ports 3000 \
  --environment-variables \
    NGINX_STAT_URL=http://<multistreamed-ip>:8080/stat
```

### Option 3: Azure VM

Deploy Docker on an Azure VM and run `docker compose up -d`. Ensure NSG rules allow inbound traffic on ports **1935** (RTMP) and **3000** (Dashboard).

_Detailed Azure deployment guide coming soon in `docs/azure-deployment.md`._

## Roadmap

- [x] Project scaffolding and README
- [x] Nginx RTMP Docker image with multi-push config
- [x] Environment-based stream key injection (entrypoint script)
- [x] Docker Compose setup
- [x] YouTube relay support
- [x] Facebook Live relay support
- [x] HTTP health check / status endpoint
- [x] Azure Container Instances deployment guide
- [x] Azure VM deployment guide
- [x] Single-click Azure deployment with ARM template
- [x] GitHub Actions workflow for automated Docker image publishing
- [x] Web UI dashboard for monitoring stream status
- [x] Automatic placeholder/failover stream (NGINX-RTMP hooks + FFmpeg)
- [x] Automated tests for nginx configuration validation
- [ ] Stream health monitoring and alerts
- [ ] Authentication for the RTMP ingest endpoint
- [ ] Support for additional platforms (Twitch, Kick, etc.)
- [ ] Dashboard configuration UI for managing stream keys

## Important Notes

- **No Transcoding (by default)**: The service relays the stream as-is. Make sure your OBS output settings meet the requirements of all target platforms.
- **Bandwidth**: Relaying to N platforms multiplies your upload bandwidth usage by N.

## Testing

The project includes automated tests to validate nginx configuration changes and prevent common errors.

### Running Tests Locally

```bash
# Run nginx configuration tests
./tests/test-nginx-config.sh
```

The test suite validates:
- Nginx configuration syntax and structure
- Required directives and blocks are present
- **Critical**: No resolver directive in rtmp block (nginx-rtmp-module doesn't support it)
- Environment variable usage
- Docker build success

Tests run automatically in CI/CD on pull requests. See [`tests/README.md`](tests/README.md) for more details.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

When modifying `nginx.conf`, please run `./tests/test-nginx-config.sh` to validate your changes before committing.

## License

_License to be determined._

---

Made with ❤️ by [@rafaelzacarias](https://github.com/rafaelzacarias)