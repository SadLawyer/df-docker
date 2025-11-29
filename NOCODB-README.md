# NocoDB Installation Guide

This guide explains how to install and manage NocoDB with PostgreSQL on your server.

## 📋 Overview

NocoDB is an open-source Airtable alternative that turns any database into a smart spreadsheet. This setup includes:

- **NocoDB**: Latest version
- **PostgreSQL 15**: Primary database
- **Docker Compose**: Container orchestration
- **Automatic Health Checks**: Built-in monitoring
- **Persistent Storage**: Data volumes for PostgreSQL and NocoDB

## 🚀 Quick Start

### 1. Deploy NocoDB

Run the deployment script to install NocoDB on your server:

```bash
./deploy-nocodb.sh
```

The script will:
- ✅ Test connection to the remote server
- ✅ Create necessary directories
- ✅ Copy configuration files
- ✅ Pull Docker images
- ✅ Start containers
- ✅ Verify deployment

### 2. Access NocoDB

Once deployed, access NocoDB at:

**URL**: http://72.60.51.124:8080

**Default Credentials**:
- Email: `admin@nocodb.com`
- Password: `admin123`

⚠️ **IMPORTANT**: Change the default password immediately after first login!

## 📁 Files Created

- `docker-compose.nocodb.yml` - Docker Compose configuration
- `.env.nocodb.example` - Environment variables template
- `deploy-nocodb.sh` - Deployment script
- `manage-nocodb.sh` - Management script

## 🛠️ Management Commands

Use the management script for common operations:

```bash
# Start containers
./manage-nocodb.sh start

# Stop containers
./manage-nocodb.sh stop

# Restart containers
./manage-nocodb.sh restart

# View status
./manage-nocodb.sh status

# Follow logs
./manage-nocodb.sh logs

# View last 50 lines of logs
./manage-nocodb.sh logs-tail

# Check health
./manage-nocodb.sh health

# Create backup
./manage-nocodb.sh backup

# Update to latest version
./manage-nocodb.sh update

# Stop and remove containers (keeps data)
./manage-nocodb.sh down

# Remove everything including data (⚠️ DANGER)
./manage-nocodb.sh clean
```

## 🔧 Configuration

### Environment Variables

Copy the example file and customize:

```bash
cp .env.nocodb.example .env.nocodb
```

Edit `.env.nocodb` with your values:

```env
# Database
POSTGRES_PASSWORD=your-secure-password-here

# NocoDB
NC_AUTH_JWT_SECRET=your-super-secret-jwt-key
NC_PUBLIC_URL=http://your-domain.com:8080
NC_ADMIN_EMAIL=admin@yourdomain.com
NC_ADMIN_PASSWORD=strong-password-here
```

### Port Configuration

By default, NocoDB runs on port **8080**. To change:

1. Edit `docker-compose.nocodb.yml`
2. Change the port mapping:
   ```yaml
   ports:
     - "8081:8080"  # Change 8081 to your desired port
   ```
3. Redeploy: `./deploy-nocodb.sh`

### Enable Redis Caching (Optional)

For better performance with multiple users:

1. Edit `docker-compose.nocodb.yml`
2. Uncomment the Redis service and volume
3. Uncomment the `NC_REDIS_URL` environment variable
4. Redeploy

### Configure SMTP for Email Notifications

1. Edit `.env.nocodb` or `docker-compose.nocodb.yml`
2. Add SMTP settings:
   ```env
   NC_SMTP_FROM=noreply@yourdomain.com
   NC_SMTP_HOST=smtp.gmail.com
   NC_SMTP_PORT=587
   NC_SMTP_USERNAME=your-email@gmail.com
   NC_SMTP_PASSWORD=your-app-password
   NC_SMTP_SECURE=true
   ```
3. Redeploy

## 💾 Backup and Restore

### Create Backup

```bash
./manage-nocodb.sh backup
```

This creates a SQL dump in `/opt/nocodb/` on the server.

### Download Backup

```bash
scp root@72.60.51.124:/opt/nocodb/nocodb_backup_*.sql ./backups/
```

### Restore from Backup

```bash
# Upload backup to server first
scp ./backup.sql root@72.60.51.124:/opt/nocodb/

# Restore
./manage-nocodb.sh restore /opt/nocodb/backup.sql
```

### Automated Backups

Create a cron job on the server:

```bash
# SSH to server
ssh root@72.60.51.124

# Add cron job (daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * cd /opt/nocodb && docker compose exec -T nocodb-postgres pg_dump -U nocodb nocodb > backup_$(date +\%Y\%m\%d).sql
```

## 🔒 Security Best Practices

1. **Change Default Credentials**
   - Change admin password on first login
   - Use strong passwords

2. **Update JWT Secret**
   - Generate a strong random secret
   - Update `NC_AUTH_JWT_SECRET`

3. **Enable HTTPS**
   - Use a reverse proxy (Nginx, Caddy, Traefik)
   - Configure SSL certificates
   - Example with Nginx:
     ```nginx
     server {
         listen 443 ssl;
         server_name nocodb.yourdomain.com;

         ssl_certificate /path/to/cert.pem;
         ssl_certificate_key /path/to/key.pem;

         location / {
             proxy_pass http://localhost:8080;
             proxy_set_header Host $host;
             proxy_set_header X-Real-IP $remote_addr;
         }
     }
     ```

4. **Firewall Configuration**
   ```bash
   # Allow only necessary ports
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

5. **Regular Updates**
   ```bash
   ./manage-nocodb.sh update
   ```

6. **Regular Backups**
   - Set up automated backups
   - Test restore process
   - Store backups off-site

## 🌐 Domain Setup

### Using a Custom Domain

1. **Update DNS**
   - Add an A record pointing to `72.60.51.124`
   - Example: `nocodb.yourdomain.com` → `72.60.51.124`

2. **Update NocoDB Configuration**
   - Edit `.env.nocodb`
   - Change `NC_PUBLIC_URL=http://nocodb.yourdomain.com`
   - Redeploy

3. **Set Up Reverse Proxy**
   - Install Nginx or Caddy
   - Configure SSL with Let's Encrypt
   - Proxy requests to `localhost:8080`

### Example: Caddy Configuration

```caddy
nocodb.yourdomain.com {
    reverse_proxy localhost:8080
}
```

Caddy automatically handles SSL certificates!

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check logs
./manage-nocodb.sh logs

# Check container status
./manage-nocodb.sh ps

# Restart containers
./manage-nocodb.sh restart
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
ssh root@72.60.51.124 "cd /opt/nocodb && docker compose logs nocodb-postgres"

# Check PostgreSQL health
ssh root@72.60.51.124 "docker exec nocodb-postgres pg_isready -U nocodb"
```

### Port Already in Use

```bash
# Check what's using port 8080
ssh root@72.60.51.124 "netstat -tulpn | grep 8080"

# Change port in docker-compose.nocodb.yml
# Then redeploy
```

### Cannot Access from Outside

```bash
# Check firewall
ssh root@72.60.51.124 "ufw status"

# Allow port 8080
ssh root@72.60.51.124 "ufw allow 8080/tcp"
```

### Forgot Admin Password

Reset the password through the database:

```bash
ssh root@72.60.51.124
cd /opt/nocodb
docker compose exec nocodb-postgres psql -U nocodb -d nocodb

# In PostgreSQL prompt:
UPDATE nc_users SET password = crypt('new-password', gen_salt('bf')) WHERE email = 'admin@nocodb.com';
\q
```

### Performance Issues

1. **Enable Redis**
   - Uncomment Redis in `docker-compose.nocodb.yml`
   - Redeploy

2. **Increase Resources**
   - Add resource limits in docker-compose:
     ```yaml
     deploy:
       resources:
         limits:
           cpus: '2'
           memory: 4G
     ```

3. **Optimize PostgreSQL**
   - Add custom PostgreSQL configuration
   - Tune for your workload

## 📊 Monitoring

### Check Health Status

```bash
./manage-nocodb.sh health
```

### Monitor Logs in Real-Time

```bash
./manage-nocodb.sh logs
```

### Check Resource Usage

```bash
ssh root@72.60.51.124 "docker stats nocodb nocodb-postgres"
```

## 🔄 Updates

### Update to Latest Version

```bash
./manage-nocodb.sh update
```

This will:
1. Create a backup
2. Pull latest images
3. Restart containers

### Rollback

If there's an issue after update:

```bash
# Stop containers
./manage-nocodb.sh stop

# Restore from backup
./manage-nocodb.sh restore /opt/nocodb/nocodb_backup_YYYYMMDD_HHMMSS.sql

# Start containers
./manage-nocodb.sh start
```

## 🔗 Integration with MCP

To integrate NocoDB with MCP servers, you can:

1. **Use the REST API**
   - NocoDB provides a full REST API
   - Access at: `http://72.60.51.124:8080/api/v1/`

2. **Create an API Token**
   - Go to Account Settings > API Tokens
   - Create a new token
   - Use in MCP configuration

3. **Update MCP Configuration**
   ```json
   {
     "mcpServers": {
       "nocodb": {
         "type": "http",
         "url": "http://72.60.51.124:8080/api/v1",
         "headers": {
           "xc-auth": "YOUR_API_TOKEN"
         }
       }
     }
   }
   ```

## 📚 Additional Resources

- **NocoDB Documentation**: https://docs.nocodb.com/
- **API Documentation**: http://72.60.51.124:8080/api/v1/docs
- **GitHub**: https://github.com/nocodb/nocodb
- **Community**: https://community.nocodb.com/

## 🆘 Support

If you encounter issues:

1. Check the logs: `./manage-nocodb.sh logs`
2. Check container status: `./manage-nocodb.sh status`
3. Review this README
4. Check NocoDB documentation
5. Check GitHub issues

## 📝 Version Information

- NocoDB: Latest (automatically updated)
- PostgreSQL: 15-alpine
- Docker Compose: v2 or v1 (auto-detected)

---

**Last Updated**: 2024
**Server**: 72.60.51.124:8080
