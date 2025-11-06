# osTicket Docker Setup

Pre-built Docker images for running osTicket with MariaDB, phpMyAdmin, and migration tools.

## Features

- ✅ **Pre-built AMD64 images** on Docker Hub (no building required)
- ✅ **PHP 8.3** with Apache and all required osTicket extensions
- ✅ **MariaDB 10.11** with optimized configuration  
- ✅ **phpMyAdmin** for database management
- ✅ **Migration container** with SSH-based pull from old servers
- ✅ **Portainer-ready** deployment
- ✅ **Free hosting** on Docker Hub

## Quick Start

### Portainer Deployment (Recommended)

📖 **[PORTAINER_DEPLOY_GUIDE.md](PORTAINER_DEPLOY_GUIDE.md)** - Complete deployment guide

1. Copy `docker-compose.portainer.yml`
2. Paste into Portainer → Stacks → Add Stack
3. Deploy
4. Access at `http://your-server:8082`

### Docker Images

- **Web**: `universaldilettant/osticket-web:latest`
- **Migration**: `universaldilettant/osticket-migration:latest`

Both images are pre-built for **AMD64** and hosted free on Docker Hub.

## Repository Structure

```
osticket_docker/
├── docker-compose.portainer.yml    # Portainer stack (uses Docker Hub images)
├── docker-compose.yml              # Local development (builds from source)
├── docker/
│   ├── web/Dockerfile              # Web image source
│   └── migration/Dockerfile        # Migration image source
├── build-for-portainer.sh          # Build & push script for updates
└── PORTAINER_DEPLOY_GUIDE.md       # Deployment instructions
```

## Prerequisites

### For Portainer Deployment:
- Portainer instance
- 5GB+ free disk space

### For Local Development:
- Docker Engine 20.10+
- Docker Compose 2.0+

### For Building Images:
- Docker Buildx (multi-platform support)
- Docker Hub account (free)

## Deployment

### Portainer (Recommended)

See **[PORTAINER_DEPLOY_GUIDE.md](PORTAINER_DEPLOY_GUIDE.md)** for complete instructions.

**Quick steps:**
1. Go to Portainer → Stacks → Add Stack
2. Copy contents of `docker-compose.portainer.yml`
3. Update passwords in the compose file
4. Deploy the stack
5. Access osTicket at `http://your-server:8082`

### First-Time Setup

1. Navigate to: `http://your-server:8082/setup/`
2. Database credentials:
   - Host: `db`
   - Database: `osticket`
   - Username: `osticket`
   - Password: (from your compose file)
3. Complete the wizard
4. Setup directory is automatically removed

### Access Points

- **osTicket**: http://your-server:8082/
- **Admin Panel**: http://your-server:8082/scp/
- **phpMyAdmin**: http://your-server:8081/

## Migration from Existing Server

The migration container is included but disabled by default.

**To use migration:**
1. Deploy the stack in Portainer
2. Go to Containers → `osticket-migration` → Start
3. Access the container console
4. Run migration commands:
   ```bash
   pull-from-server.sh  # Pull data via SSH
   migrate.sh           # Import to Docker
   ```

**Features:**
- ✅ SSH-based pull from remote servers
- ✅ Compressed transfers
- ✅ Progress indicators
- ✅ Automatic permission fixes

## Configuration

### Change Passwords

⚠️ **IMPORTANT**: Update these in `docker-compose.portainer.yml` before deploying:

```yaml
# Database service
MYSQL_ROOT_PASSWORD: supersecret      # ← Change!
MYSQL_PASSWORD: osticketpass          # ← Change!

# Web service
DB_PASS: osticketpass                 # ← Must match MYSQL_PASSWORD

# phpMyAdmin
PMA_PASSWORD: supersecret             # ← Must match MYSQL_ROOT_PASSWORD
```

### Change Ports

Edit ports in `docker-compose.portainer.yml`:
- osTicket: `8082:80` (change 8082)
- phpMyAdmin: `8081:80` (change 8081)

## Management

### In Portainer

- **View logs**: Click container → Logs
- **Console access**: Click container → Console
- **Restart**: Click container → Restart
- **Update stack**: Stacks → Your Stack → Editor → Update

### Backup

**Database:**
```bash
docker exec osticket-db mysqldump -u osticket -p osticket | gzip > backup.sql.gz
```

**Volumes:**
In Portainer: Volumes → Export each volume

### Updates

When new images are available:
1. In Portainer: Images → Pull `universaldilettant/osticket-web:latest`
2. Stacks → Your Stack → Pull and redeploy

## Troubleshooting

### Container Won't Start
- Check logs in Portainer (Container → Logs)
- Verify database is healthy (should show green)
- Check port conflicts

### Can't Access osTicket
- Verify port 8082 is not blocked by firewall
- Check container status in Portainer
- Review container logs

### Database Connection Errors
- Ensure `DB_PASS` matches `MYSQL_PASSWORD` in compose file
- Wait for database health check to pass (green status)
- Check database container logs

## Security Checklist

### Before Production:

- [ ] Change all default passwords in compose file
- [ ] Set up SSL/TLS (reverse proxy recommended)
- [ ] Configure firewall rules
- [ ] Remove phpMyAdmin if not needed
- [ ] Set up automated backups
- [ ] Update osTicket admin password after setup
- [ ] Review and restrict container permissions

## Building Images

If you need to rebuild the images:

```bash
./build-for-portainer.sh
```

This will:
- Build both images for AMD64
- Push to your Docker Hub account
- Update the compose file

## Stack Components

- **osTicket**: v1.18.1 (GPL v2)
- **PHP**: 8.3-apache
- **MariaDB**: 10.11
- **phpMyAdmin**: Latest
- **Alpine Linux**: Migration container base

## Docker Hub Images

- Web: https://hub.docker.com/r/universaldilettant/osticket-web
- Migration: https://hub.docker.com/r/universaldilettant/osticket-migration

## Resources

- **osTicket Docs**: https://docs.osticket.com/
- **Deployment Guide**: [PORTAINER_DEPLOY_GUIDE.md](PORTAINER_DEPLOY_GUIDE.md)

## License

Docker setup provided as-is. osTicket licensed under GPL v2.
