# Deploying Multistreamed on Azure

This guide covers deploying Multistreamed to Microsoft Azure using three approaches: **Single-Click Deployment** (fastest), **Azure Container Instances (ACI)** for a quick serverless deployment, and an **Azure VM** for full control.

## Option 1: Single-Click Deployment (Recommended)

The easiest way to deploy Multistreamed is using the "Deploy to Azure" button. This method requires no local tools or command-line knowledge — everything happens in your web browser.

### Prerequisites

- An active [Azure account](https://azure.microsoft.com/)
- Stream keys for your target platforms:
  - **YouTube**: Settings → Stream → Stream Key
  - **Facebook**: Live Producer → Stream Key
  - **Instagram** (optional): Requires third-party RTMP bridge

### Deployment Steps

1. **Click the Deploy to Azure button** in the [README.md](../README.md) or use this direct link:

   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frafaelzacarias%2Fmultistreamed%2Fmain%2Fazuredeploy.json)

2. **Sign in to Azure** if you're not already logged in

3. **Fill in the deployment form:**
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: Create new or select existing
   - **Region**: Choose a location close to you (e.g., East US, West Europe)
   - **YouTube Stream Key**: Paste your YouTube stream key
   - **Facebook Stream Key**: Paste your Facebook stream key
   - **Instagram Stream Key**: (Optional) Leave blank unless you have an RTMP bridge
   - **Instagram RTMP Host**: (Optional) Your Instagram bridge URL
   - **CPU Cores**: Select 2 (recommended) or 4 for higher quality streams
   - **Memory in GB**: Select 4 (recommended) or 8 for higher quality streams
   - **DNS Name Label**: Leave default (auto-generated) or customize

4. **Review and create:**
   - Check "I agree to the terms and conditions"
   - Click **"Create"**

5. **Wait for deployment** (typically 2-3 minutes)

6. **Get your deployment outputs:**
   - Once deployment completes, go to the resource group
   - Click on **"Deployments"** in the left menu
   - Click on the deployment name (usually starts with "Microsoft.Template")
   - Click on **"Outputs"** to see:
     - **RTMP URL**: Use this in OBS (e.g., `rtmp://multistreamed-xyz.eastus.azurecontainer.io/live`)
     - **Dashboard URL**: Open this in your browser to monitor streams
     - **Stats URL**: Raw XML stats from Nginx RTMP module
     - **Public IP**: The public IP address of your container group

### Configure OBS

1. Open **OBS Studio**
2. Go to **Settings → Stream**
3. Set **Service** to "Custom"
4. Set **Server** to the RTMP URL from the deployment outputs
5. Set **Stream Key** to blank (or a custom value if you add authentication later)
6. Click **"OK"** and start streaming!

### What Gets Deployed

The ARM template creates a single Azure Container Group containing:

- **Multistreamed container**: Nginx RTMP server that receives your stream and relays it to YouTube, Facebook, and Instagram
- **Dashboard container**: Node.js web application for monitoring stream health

**Exposed ports:**
- Port 1935: RTMP ingest (for OBS)
- Port 8080: Stats endpoint
- Port 3000: Web dashboard

**Resource allocation:**
- Multistreamed container: 2 CPU cores, 4 GB RAM (configurable)
- Dashboard container: 0.5 CPU cores, 1 GB RAM

### Cost Estimate

Azure Container Instances pricing is based on CPU and memory usage per second:

- **2 vCPU, 4 GB RAM** (multistreamed) + **0.5 vCPU, 1 GB RAM** (dashboard)
- Approximately **$70-80/month** if running 24/7
- **Pay only for what you use** — stop the container group when not streaming to save costs

### Managing Your Deployment

**View container logs:**
```bash
az container logs --resource-group <your-rg> --name <container-group-name> --container-name multistreamed
```

**Stop the containers** (to save costs when not streaming):
```bash
az container stop --resource-group <your-rg> --name <container-group-name>
```

**Start the containers** (when ready to stream again):
```bash
az container start --resource-group <your-rg> --name <container-group-name>
```

**Delete the deployment:**
```bash
az group delete --resource-group <your-rg> --yes
```

### Troubleshooting

**Deployment fails with "InvalidTemplate" error:**
- Ensure all required stream keys are filled in
- Check that the DNS name label is unique and follows naming rules (lowercase letters, numbers, hyphens only)

**Can't connect from OBS:**
- Verify that port 1935 is open by checking the container group's networking settings
- Ensure you're using the correct RTMP URL from the deployment outputs
- Check container logs for any startup errors

**Dashboard shows "No stream detected":**
- Start streaming from OBS first
- Wait 5-10 seconds for the dashboard to refresh
- Check that the NGINX_STAT_URL environment variable is correctly set to `http://127.0.0.1:8080/stat`

## Option 2: Azure CLI with ARM Template

If you prefer command-line deployment or need to automate the process, you can use the Azure CLI.

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- Stream keys for your target platforms

### Steps

1. **Clone the repository and navigate to it:**

```bash
git clone https://github.com/rafaelzacarias/multistreamed.git
cd multistreamed
```

2. **Create a resource group:**

```bash
az group create --name multistreamed-rg --location eastus
```

3. **Deploy using the ARM template:**

```bash
az deployment group create \
  --resource-group multistreamed-rg \
  --template-file azuredeploy.json \
  --parameters youtubeStreamKey="YOUR_YOUTUBE_KEY" \
               facebookStreamKey="YOUR_FACEBOOK_KEY" \
               cpuCores="2" \
               memoryInGb="4"
```

4. **Get the deployment outputs:**

```bash
az deployment group show \
  --resource-group multistreamed-rg \
  --name azuredeploy \
  --query properties.outputs
```

This will show you the RTMP URL, dashboard URL, and other connection details.

## Option 3: Azure Container Instances (Manual)

For manual ACI deployment without the ARM template:

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

## Option 4: Azure Virtual Machine

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
