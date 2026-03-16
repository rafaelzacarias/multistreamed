# Deploying Multistreamed on Azure

This guide covers deploying Multistreamed to Microsoft Azure using two approaches: **Azure Container Instances (ACI)** for a quick serverless deployment, and an **Azure VM** for full control.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- Docker image pushed to a container registry (Azure Container Registry or Docker Hub)
- Stream keys for your target platforms

## Option 1: Azure Container Instances (ACI)

ACI is the fastest way to get a container running in Azure — no VM to manage.

### 1. Create a Resource Group

```bash
az group create --name multistreamed-rg --location eastus
```

### 2. Create an Azure Container Registry (optional)

If you want to host your image privately:

```bash
az acr create --resource-group multistreamed-rg --name multistreamedacr --sku Basic
az acr login --name multistreamedacr
```

### 3. Build and Push the Image

```bash
docker build -t multistreamedacr.azurecr.io/multistreamed:latest .
docker push multistreamedacr.azurecr.io/multistreamed:latest
```

### 4. Deploy the Container

> **Security note**: The example below uses `--secure-environment-variables` to prevent stream keys from appearing in container metadata. For production, consider storing keys in [Azure Key Vault](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-volume-secret) instead.

```bash
az container create \
  --resource-group multistreamed-rg \
  --name multistreamed \
  --image multistreamedacr.azurecr.io/multistreamed:latest \
  --ports 1935 8080 \
  --cpu 2 \
  --memory 4 \
  --secure-environment-variables \
    YOUTUBE_STREAM_KEY=<your-youtube-key> \
    FACEBOOK_STREAM_KEY=<your-facebook-key> \
    INSTAGRAM_STREAM_KEY=<your-instagram-key> \
    INSTAGRAM_RTMP_HOST=<your-instagram-bridge-host> \
  --restart-policy Always
```

### 5. Get the Public IP

```bash
az container show \
  --resource-group multistreamed-rg \
  --name multistreamed \
  --query ipAddress.ip \
  --output tsv
```

Use this IP as your RTMP server in OBS: `rtmp://<IP>/live`

## Option 2: Azure Virtual Machine

For more control, deploy on an Azure VM with Docker installed.

### 1. Create a VM

```bash
az vm create \
  --resource-group multistreamed-rg \
  --name multistreamed-vm \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys
```

### 2. Open Required Ports

```bash
az vm open-port --resource-group multistreamed-rg --name multistreamed-vm --port 1935 --priority 1000
az vm open-port --resource-group multistreamed-rg --name multistreamed-vm --port 8080 --priority 1001
```

### 3. SSH into the VM and Install Docker

```bash
ssh azureuser@<vm-public-ip>

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker azureuser
```

### 4. Clone and Run

```bash
git clone https://github.com/rafaelzacarias/multistreamed.git
cd multistreamed
cp .env.example .env
# Edit .env with your stream keys
nano .env
docker compose up -d
```

## Monitoring

### Check Container Health

```bash
curl http://<server-ip>:8080/health
```

### View Stream Statistics

Open `http://<server-ip>:8080/stat` in your browser for real-time RTMP stream stats.

### View Logs (ACI)

```bash
az container logs --resource-group multistreamed-rg --name multistreamed
```

## Estimated Costs

| Resource | SKU | Estimated Monthly Cost |
|---|---|---|
| ACI (2 vCPU, 4 GB) | Pay-per-use | ~$70/month (if running 24/7) |
| VM (Standard_B2s) | 2 vCPU, 4 GB | ~$30/month |
| ACR (Basic) | Basic | ~$5/month |

> **Tip**: For occasional streaming, ACI is cost-effective since you only pay while the container is running. For regular streaming, a VM is more economical.

## Security Recommendations

- **Use secure environment variables**: For ACI, consider using Azure Key Vault to store stream keys instead of passing them as plain environment variables.
- **Restrict inbound traffic**: Use Network Security Groups (NSG) to allow RTMP (1935) only from your IP.
- **Enable HTTPS**: Put the health/stats endpoint behind an HTTPS reverse proxy or Azure Application Gateway.
