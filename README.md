# PBS S3 Proxy on Fly.io

A containerized deployment of the [pmoxs3backuproxy](https://github.com/tizbac/pmoxs3backuproxy) project with Nginx reverse proxy, designed to run on Fly.io. This proxy enables Proxmox Backup Server to store backups directly to S3-compatible storage with automatic garbage collection.

## Features

- Ready-to-deploy on Fly.io
- TLS handled by Fly.io's managed proxy
- Automatic garbage collection (runs every hour, configurable)
- Health check endpoint at `/health`
- Configurable S3 endpoint and retention policies

## Why Nginx Reverse Proxy?

Fly.io provides its own reverse proxy that terminates TLS with managed certificates and expects backend services to run on plain HTTP. However, the pmoxs3backuproxy backend only exposes HTTPS with a self-signed certificate and cannot be configured to run on plain HTTP.

This deployment uses Nginx as a bridge: it accepts HTTP requests from Fly.io's reverse proxy on port 8080 and forwards them as HTTPS requests to the pmoxs3backuproxy backend running on port 3000 with its self-signed certificate.

**Note:** There's an open issue regarding this TLS behavior: [tizbac/pmoxs3backuproxy#79](https://github.com/tizbac/pmoxs3backuproxy/issues/79)

## Prerequisites

- [Fly.io CLI](https://fly.io/docs/getting-started/installing-flyctl/) installed and authenticated
- S3-compatible storage service (AWS S3, Wasabi, etc.)
- S3 access credentials

## Deployment

### 1. Clone and Configure

```bash
git clone <this-repo>
cd pbs-s3-proxy-on-fly.io
```

### 2. Update Configuration

Edit the `fly.toml` file to match your requirements:

```toml
# Change app name
app = "your-app-name"

# Update region if needed
primary_region = "ams"

# Configure proxy settings
[experimental]
cmd = ["-bind", "127.0.0.1:3000", "-endpoint", "your-s3-endpoint:443", "-usessl"]

# Set environment variables
[env]
PBS_GC_ACCESS_KEY = "your-access-key"
PBS_GC_ENDPOINT = "your-s3-endpoint:443"
PBS_GC_BUCKET = "your-bucket-name"
PBS_GC_RETENTION = "7"  # Days to retain backups
```

### 3. Set Secrets

Set your S3 secret key as a Fly.io secret:

```bash
flyctl secrets set PBS_GC_SECRET_KEY="your-secret-access-key"
```

### 4. Deploy

```bash
flyctl deploy
```

## Configuration Files

### Key Files to Modify

| File | Purpose | What to Change |
|------|---------|---------------|
| `fly.toml` | Fly.io configuration | App name, region, S3 endpoint, environment variables |
| `nginx.conf` | Nginx proxy configuration | Usually no changes needed |
| `garbagecollector` | Cron schedule | Modify to change cleanup frequency (default: hourly) |

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PBS_GC_ACCESS_KEY` | S3 access key | Set in `fly.toml` |
| `PBS_GC_SECRET_KEY` | S3 secret key | Set via `flyctl secrets` |
| `PBS_GC_ENDPOINT` | S3 endpoint with port | `s3.amazonaws.com:443` |
| `PBS_GC_BUCKET` | S3 bucket name | `my-backup-storage` |
| `PBS_GC_RETENTION` | Retention period (days) | `7` |

## Usage

Once deployed, you need to configure your Proxmox Backup Server to use this proxy.

### Proxmox Backup Server Configuration

Since Proxmox Backup Server doesn't natively support S3 storage, this proxy makes your S3 bucket appear as a regular PBS datastore.

1. **Add Datastore** in Proxmox Backup Server:
   - Go to Configuration → Storage → Add
   - Choose "Proxmox Backup Server" as the type

2. **Configure the connection**:
   - **Server**: `your-app-name.fly.dev`
   - **Username**: `your-s3-access-key@pbs` (note the `@pbs` suffix)
   - **Password**: `your-s3-secret-key`
   - **Datastore**: `your-bucket-name`
   - **Fingerprint**: Leave empty initially (PBS will fetch it automatically)

**Important**: The username format is critical - you must append `@pbs` to your S3 access key. This tells the proxy to treat the connection as a PBS client.

### Example Configuration

If your S3 credentials are:
- Access Key: `AKIAIOSFODNN7EXAMPLE`
- Secret Key: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
- Bucket: `my-pbs-backups`

Then configure PBS with:
- **Server**: `your-app-name.fly.dev`
- **Username**: `AKIAIOSFODNN7EXAMPLE@pbs`
- **Password**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
- **Datastore**: `my-pbs-backups`

### Service Behavior

The service will:
- Accept backup requests from PBS
- Forward them to your S3 storage
- Run garbage collection every hour to clean up old backups (configurable in `garbagecollector` file)
- Provide health checks for Fly.io monitoring

## Monitoring

- Health endpoint: `https://your-app-name.fly.dev/health`
- Fly.io automatically monitors the health endpoint
- Check logs: `flyctl logs`

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure your S3 credentials are correct and the bucket exists
2. **TLS errors**: The Nginx proxy should handle TLS termination - check nginx logs
3. **Garbage collection not working**: Verify all `PBS_GC_*` environment variables are set

### Checking Logs

```bash
# View recent logs
flyctl logs

# Follow logs in real-time
flyctl logs -f
```

## Architecture

```
[Proxmox Backup Server] → [Fly.io Managed Proxy (TLS Termination)] → [App Container] → [Nginx (HTTP:8080)] → [pmoxs3backuproxy (HTTPS:3000)] → [S3 Storage]
                                                                                    ↓
                                                                             [Garbage Collector (cron)]
```

**Flow Explanation:**
1. Fly.io's managed proxy terminates TLS and forwards HTTP requests to your app on port 8080
2. Nginx receives HTTP requests and proxies them as HTTPS to the pmoxs3backuproxy backend
3. The backend handles the S3 operations with its self-signed certificate
4. Garbage collection runs independently via cron

