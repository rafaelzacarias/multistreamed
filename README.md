# 🎥 Multistreamed

> A self-hosted, Docker-based restreaming service that takes a single RTMP input (from OBS or any encoder) and simultaneously broadcasts to **Facebook**, **Instagram**, and **YouTube**. Designed to deploy on **Azure**.

## Overview

**Multistreamed** works like [Restream.io](https://restream.io) but runs on your own infrastructure. You point OBS (or any RTMP-compatible encoder) at this service, and it relays your stream to multiple platforms at the same time — no third-party middleman.

```
┌─────────┐       RTMP        ┌──────────────────┐       RTMP       ┌─────────────┐
│   OBS   │ ────────────────► │  Multistreamed   │ ──────────────►  │  YouTube    │
│ Studio  │                   │  (Nginx RTMP +   │ ──────────────►  │  Facebook   │
└─────────┘                   │   Docker/Azure)  │ ──────────────►  │  Instagram  │
                              └──────────────────┘                  └─────────────┘
```

## Features

- 🔀 **Multi-platform relay** — Stream to Facebook, Instagram, and YouTube simultaneously
- 📡 **RTMP ingest** — Compatible with OBS Studio, Streamlabs, and any RTMP encoder
- 🐳 **Dockerized** — Runs in containers for easy deployment and portability
- ☁️ **Azure-ready** — Designed to deploy on Azure (Container Instances, App Service, or VM)
- ⚡ **Low latency** — Passthrough relay (no transcoding) for minimal delay
- 🔐 **Secure key management** — Stream keys configured via environment variables
- 📊 **Health monitoring** — HTTP endpoint to check stream status

## Tech Stack

| Component | Technology |
|---|---|
| **RTMP Server** | Nginx with [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module) |
| **Containerization** | Docker + Docker Compose |
| **Cloud** | Microsoft Azure (ACI / App Service / VM) |
| **Encoder** | OBS Studio (or any RTMP source) |
| **Relay targets** | YouTube RTMP, Facebook Live RTMP, Instagram Live RTMP |

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Docker Container         │
                    │                                  │
 OBS (RTMP) ──────►│  Nginx RTMP Server               │
                    │    ├── push → YouTube RTMP       │
                    │    ├── push → Facebook RTMP      │
                    │    └── push → Instagram RTMP     │
                    │                                  │
                    │  HTTP Status Server (:8080)      │
                    └─────────────────────────────────┘
                              Hosted on Azure
```

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/)
- Stream keys for your target platforms:
  - **YouTube**: Settings → Stream → Stream Key
  - **Facebook**: Live Producer → Stream Key
  - **Instagram**: Requires third-party RTMP bridge (Instagram doesn't natively support RTMP ingest)
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
INSTAGRAM_STREAM_KEY=your-instagram-stream-key
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

## Project Structure

```
multistreamed/
├── docker-compose.yml        # Container orchestration
├── Dockerfile                # Nginx RTMP image build
├── nginx.conf                # RTMP server configuration with push directives
├── .env.example              # Example environment variables
├── scripts/
│   └── entrypoint.sh         # Startup script (substitutes env vars into nginx.conf)
├── docs/
│   └── azure-deployment.md   # Azure deployment guide
└── README.md
```

## Deployment on Azure

### Option 1: Azure Container Instances (ACI)

```bash
az container create \
  --resource-group multistreamed-rg \
  --name multistreamed \
  --image your-acr.azurecr.io/multistreamed:latest \
  --ports 1935 8080 \
  --environment-variables \
    YOUTUBE_STREAM_KEY=<key> \
    FACEBOOK_STREAM_KEY=<key> \
    INSTAGRAM_STREAM_KEY=<key>
```

### Option 2: Azure VM

Deploy Docker on an Azure VM and run `docker-compose up -d`. Ensure NSG rules allow inbound traffic on port **1935** (RTMP).

_Detailed Azure deployment guide coming soon in `docs/azure-deployment.md`._

## Roadmap

- [x] Project scaffolding and README
- [ ] Nginx RTMP Docker image with multi-push config
- [ ] Environment-based stream key injection (entrypoint script)
- [ ] Docker Compose setup
- [ ] YouTube relay support
- [ ] Facebook Live relay support
- [ ] Instagram Live relay support (via RTMP bridge)
- [ ] HTTP health check / status endpoint
- [ ] Azure Container Instances deployment guide
- [ ] Azure VM deployment guide
- [ ] Web UI dashboard for managing stream keys and destinations
- [ ] Stream health monitoring and alerts
- [ ] Authentication for the RTMP ingest endpoint
- [ ] Support for additional platforms (Twitch, Kick, etc.)

## Important Notes

- **Instagram Limitation**: Instagram doesn't officially support external RTMP ingest. You'll need a third-party bridge tool to relay to Instagram Live. This will be documented in detail.
- **No Transcoding (by default)**: The service relays the stream as-is. Make sure your OBS output settings meet the requirements of all target platforms.
- **Bandwidth**: Relaying to N platforms multiplies your upload bandwidth usage by N.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

_License to be determined._

---

Made with ❤️ by [@rafaelzacarias](https://github.com/rafaelzacarias)