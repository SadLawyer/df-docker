# NocoDB PostgreSQL Installation Script

This is an adapted version of the official NocoDB installation script, specifically configured to use PostgreSQL as the database backend and to work with your existing setup.

## Key Changes from Original Script

1. **PostgreSQL by Default**: Always uses PostgreSQL (no SQLite option)
2. **Simplified Port Configuration**: Uses port 8081 by default (configurable)
3. **Removed Traefik**: Simplified to work with direct port access or your existing reverse proxy (Caddy)
4. **Installation Directory**: Uses `/opt/nocodb` as the standard installation directory
5. **Standalone Mode**: Works independently without requiring Traefik for SSL

## Prerequisites

- Docker and Docker Compose installed
- Root or sudo access to create directories in `/opt`
- Ports available (default: 8081 for NocoDB, 9000/9001 for MinIO if enabled)

## Usage

### Basic Installation

```bash
./nocodb-postgres-install.sh
```

### Debug Mode

```bash
./nocodb-postgres-install.sh --debug
```

## Installation Process

The script will ask you for:

1. **Port Configuration**: Port for NocoDB (default: 8081)
2. **PostgreSQL Settings**:
   - Database name (default: nocodb)
   - Username (default: nocodb)
   - Password (default: nocodb_secret_2024)
3. **Domain Name**: Optional, for reverse proxy configuration
4. **SSL Configuration**: Only if you provide a valid domain
5. **Redis**: Enable for caching (recommended: Yes)
6. **MinIO**: Enable for file storage (recommended: Yes)
7. **Watchtower**: Enable for automatic updates (optional)

## Installation Directory Structure

After installation, your setup will be at `/opt/nocodb/`:

```
/opt/nocodb/
├── docker-compose.yml    # Main compose configuration
├── docker.env           # Environment variables
├── start.sh            # Start all services
├── stop.sh             # Stop all services
├── restart.sh          # Restart all services
├── update.sh           # Update to latest version
├── logs.sh             # View logs
└── noco.state          # Installation state
```

## Management Scripts

After installation, you can manage NocoDB using these scripts:

```bash
# Start services
/opt/nocodb/start.sh

# Stop services
/opt/nocodb/stop.sh

# Restart services
/opt/nocodb/restart.sh

# Update to latest version
/opt/nocodb/update.sh

# View logs
/opt/nocodb/logs.sh
```

## Integration with Caddy

If you want to expose NocoDB through Caddy, add this to your Caddyfile:

```caddy
nocodb.yourdomain.com {
    reverse_proxy localhost:8081
}
```

Or for the MinIO console:

```caddy
minio.yourdomain.com {
    reverse_proxy localhost:9001
}
```

## Docker Compose Services

The generated `docker-compose.yml` includes:

- **nocodb-db**: PostgreSQL 15 database
- **nocodb**: NocoDB application (port 8081)
- **redis** (optional): Redis cache
- **minio** (optional): S3-compatible storage (ports 9000, 9001)
- **watchtower** (optional): Automatic updates

## Environment Variables

Key environment variables in `docker.env`:

- `NC_DB`: PostgreSQL connection string
- `NC_PUBLIC_URL`: Public URL for NocoDB
- `NC_REDIS_URL`: Redis connection (if enabled)
- `NC_S3_*`: MinIO/S3 configuration (if enabled)

## Troubleshooting

### Port Already in Use

If port 8081 is already in use:
```bash
# Check what's using the port
lsof -i :8081

# Or use a different port during installation
```

### Docker Permission Issues

If you get permission errors:
```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Log out and log back in
```

### View Logs

```bash
cd /opt/nocodb
docker compose logs -f nocodb
```

### Reset Installation

```bash
cd /opt/nocodb
docker compose down -v
rm -rf /opt/nocodb/*
# Run the installation script again
```

## Accessing NocoDB

After installation:

- **NocoDB**: `http://YOUR_IP:8081` or `http://your-domain.com` (if configured with Caddy)
- **MinIO Console** (if enabled): `http://YOUR_IP:9001`

## Default Credentials

### PostgreSQL
- Database: `nocodb`
- User: `nocodb`
- Password: `nocodb_secret_2024` (or your custom password)

### MinIO (if enabled)
- Access Key: Generated automatically
- Secret Key: Generated automatically
- Check `docker.env` for credentials

## Differences from Original Script

| Feature | Original | This Version |
|---------|----------|--------------|
| Database | PostgreSQL or SQLite | PostgreSQL only |
| Reverse Proxy | Traefik (required) | None (use your own) |
| Port | 80/443 (via Traefik) | 8081 (configurable) |
| SSL | Automatic (via Traefik) | Manual (via Caddy/etc) |
| Location | `$(pwd)/nocodb` | `/opt/nocodb` |
| Complexity | High | Simplified |

## Security Notes

1. **Change Default Passwords**: Always change the default PostgreSQL password
2. **Firewall**: Consider using a firewall to restrict access
3. **Reverse Proxy**: Use Caddy or similar for SSL/TLS termination
4. **Backups**: Regularly backup `/opt/nocodb` directory and PostgreSQL data

## Backup

To backup your NocoDB installation:

```bash
# Stop services
cd /opt/nocodb && docker compose down

# Backup entire directory
tar -czf nocodb-backup-$(date +%Y%m%d).tar.gz /opt/nocodb

# Restart services
cd /opt/nocodb && docker compose up -d
```

## Uninstall

To completely remove NocoDB:

```bash
cd /opt/nocodb
docker compose down -v
cd /
sudo rm -rf /opt/nocodb
```

## Support

For issues with:
- **NocoDB**: https://github.com/nocodb/nocodb/issues
- **This Script**: Check the original script at https://github.com/nocodb/nocodb/tree/develop/docker-compose/1_Auto_Upstall

## License

This script is adapted from the official NocoDB installation script and maintains the same license.
