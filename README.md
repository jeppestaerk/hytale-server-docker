# Hytale Server Docker

Docker setup for running a Hytale dedicated server with automatic downloads and mods support.

## Requirements

- Docker and Docker Compose
- Hytale account (for OAuth authentication)
- At least 4GB RAM available for the container

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` to adjust settings as needed.

### 2. Build and Run

```bash
docker compose up --build
```

> **Note:** Run without `-d` the first time to complete the OAuth authentication interactively.

### 3. Authenticate and Download

On first launch, the container will automatically download server files using the Hytale Downloader CLI. You'll see a device authorization prompt:

```
==================================================================
DEVICE AUTHORIZATION
==================================================================
Visit: https://accounts.hytale.com/device
Enter code: ABCD-1234
==================================================================
```

Complete the OAuth flow in your browser. Once authenticated, the server files will download and extract automatically.

### 4. Server Authentication

After the server starts, you also need to authenticate the server itself:

```bash
docker compose exec hytale-server bash
```

In the server console, run:
```
/auth login device
```

Follow the device authorization flow again.

### 5. Run in Background

After initial setup, you can run detached:

```bash
docker compose up -d
```

## Alternative: Manual Server Files

If you prefer to provide server files manually instead of using auto-download:

**Option A: Copy from Launcher Installation**

Find the files in your Hytale Launcher installation:
- **Windows:** `%appdata%\Hytale\install\release\package\game\latest\Server\`
- **Linux:** `$XDG_DATA_HOME/Hytale/install/release/package/game/latest/Server/`
- **macOS:** `~/Application Support/Hytale/install/release/package/game/latest/Server/`

Copy these files to `server/`:
- `HytaleServer.jar`
- `Assets.zip`
- `HytaleServer.aot` (optional, for faster startup)

**Option B: Use Hytale Downloader CLI locally**

Download the official Hytale Downloader from the Hytale support documentation and run it locally, then copy the files to `server/`.

## Adding Mods

Download mods (`.jar` or `.zip`) from sources like CurseForge and place them in the `mods/` directory. They are loaded automatically on server startup.

**Recommended plugins from Nitrado and Apex Hosting:**

| Mod | Description |
|-----|-------------|
| Nitrado:WebServer | Base plugin for web applications and APIs |
| Nitrado:Query | Exposes server status (player counts, etc.) via HTTP |
| Nitrado:PerformanceSaver | Dynamically limits view distance based on resource usage |
| ApexHosting:PrometheusExporter | Exposes detailed server and JVM metrics |

Mods are bind-mounted from `./mods` so you can add/remove them without rebuilding the container. Just restart the server after changes:

```bash
docker compose restart
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_MIN_HEAP` | `2G` | Minimum JVM heap size |
| `JAVA_MAX_HEAP` | `4G` | Maximum JVM heap size |
| `SERVER_PORT` | `5520` | UDP port for server |
| `AUTH_MODE` | `authenticated` | `authenticated` or `offline` |
| `ENABLE_BACKUP` | `true` | Enable automatic backups |
| `BACKUP_FREQUENCY` | `60` | Backup interval in minutes |
| `DISABLE_SENTRY` | `false` | Disable crash reporting |
| `USE_AOT_CACHE` | `true` | Use AOT cache for faster startup |
| `AUTO_UPDATE` | `false` | Check for updates on startup |
| `PATCHLINE` | `release` | `release` or `pre-release` channel |
| `CREDENTIALS_PATH` | | Path to credentials file (see below) |
| `SKIP_DOWNLOADER_UPDATE_CHECK` | `false` | Skip downloader update check |
| `EXTRA_ARGS` | | Additional server arguments |

### Credentials File (Non-Interactive Auth)

For automated deployments, you can provide a credentials file to skip the interactive OAuth flow:

1. Run the hytale-downloader locally once to complete OAuth:
   ```bash
   ./hytale-downloader
   ```

2. Copy the generated credentials file to `config/credentials.json`:
   ```bash
   # Linux
   cp ~/.hytale-downloader-credentials.json config/credentials.json

   # Windows
   copy %USERPROFILE%\.hytale-downloader-credentials.json config\credentials.json
   ```

3. The container will automatically use this file for authentication.

Alternatively, set a custom path via `CREDENTIALS_PATH` in `.env`.

### Build Arguments

When building the image, you can customize the downloader URL:

```bash
docker compose build --build-arg HYTALE_DOWNLOADER_URL="https://your-url/hytale-downloader.zip"
```

### Networking

Hytale uses the **QUIC protocol over UDP** (not TCP). Ensure your firewall allows UDP traffic on port 5520.

**Port Forwarding:** If behind a router, forward **UDP port 5520** to your server machine.

**Firewall Examples:**

Linux (ufw):
```bash
sudo ufw allow 5520/udp
```

Linux (iptables):
```bash
sudo iptables -A INPUT -p udp --dport 5520 -j ACCEPT
```

### Persistent Data

The following volumes are used for persistent data:

| Type | Source | Container Path | Description |
|------|--------|----------------|-------------|
| Bind mount | `./mods` | `/opt/hytale/mods` | Mods directory |
| Bind mount | `./config` | `/opt/hytale/config` | Credentials file |
| Volume | `hytale-server-files` | `/opt/hytale` | Server files and config |
| Volume | `hytale-universe` | `/opt/hytale/universe` | World and player data |
| Volume | `hytale-logs` | `/opt/hytale/logs` | Server logs |
| Volume | `hytale-backups` | `/opt/hytale/backups` | Automatic backups |
| Volume | `hytale-cache` | `/opt/hytale/.cache` | Optimized cache files |
| Volume | `hytale-downloads` | `/opt/hytale/downloads` | Downloaded game files |
| Volume | `hytale-downloader-config` | `/home/hytale/.config/...` | OAuth tokens |

## Commands

```bash
# First run (interactive for OAuth)
docker compose up --build

# Start server (after initial setup)
docker compose up -d

# View logs
docker compose logs -f

# Stop server
docker compose down

# Rebuild after changes
docker compose up -d --build

# Access server console
docker compose attach hytale-server

# Run bash in container
docker compose exec hytale-server bash

# Reset all data (WARNING: destroys worlds!)
docker compose down -v
```

## Performance Tuning

### Memory

Resource usage depends on player count and playstyle:
- **CPU:** High player or entity counts increase CPU usage
- **RAM:** Large loaded world areas (high view distance, spread-out players) increase RAM usage

Adjust `JAVA_MAX_HEAP` based on your needs. Start with 4GB and monitor usage.

### View Distance

The documentation recommends limiting view distance to **12 chunks (384 blocks)** for both performance and gameplay. Hytale's default is roughly equivalent to 24 Minecraft chunks.

## File Structure

```
hytale-server-docker/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── .env.example
├── .env                 # Your configuration (copy from .env.example)
├── README.md
├── server/              # Optional: pre-packaged server files
│   ├── HytaleServer.jar
│   ├── Assets.zip
│   └── HytaleServer.aot
├── mods/                # Place mods here (bind-mounted)
│   └── *.jar or *.zip
└── config/              # Credentials for non-interactive auth
    └── credentials.json
```

## Troubleshooting

### Download Fails
- Ensure you have a valid Hytale account
- Complete the OAuth flow in your browser
- Check if the downloader URL is correct (may need to update `HYTALE_DOWNLOADER_URL`)

### Connection Issues
- Ensure UDP port 5520 is open (not TCP)
- Check that port forwarding is configured for UDP
- QUIC handles NAT well, but symmetric NAT may cause issues

### Memory Issues
- Increase `JAVA_MAX_HEAP` in `.env`
- Reduce view distance via server configuration
- Monitor with `docker stats`

### Authentication
- Run `/auth login device` in the server console
- There's a limit of 100 servers per Hytale game license
- OAuth tokens are persisted in the `hytale-downloader-config` volume

### Re-download Server Files
To force a fresh download, remove the server files volume:

```bash
docker compose down
docker volume rm hytale-server-files hytale-downloads
docker compose up --build
```

## References

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Adoptium Java 25](https://adoptium.net/)
