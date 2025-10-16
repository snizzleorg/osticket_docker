# osTicket Docker Setup

Complete Docker stack for running osTicket with MariaDB, phpMyAdmin, and automated migration tools.

## Features

- **PHP 8.2** with Apache and all required osTicket extensions
- **MariaDB 10.11** with optimized configuration  
- **phpMyAdmin** for database management
- **Migration container** with SSH-based pull from old servers
- Persistent volumes for database, uploads, and application files
- Health checks and auto-restart policies
- Portainer-compatible deployment

## Documentation

📖 **[DOCS.md](DOCS.md)** - Complete documentation index

**Quick links:**

- **[Fresh Installation](#fresh-installation)** - New osTicket setup
- **[Migration Guide](REMOTE_MIGRATION_GUIDE.md)** - Migrate from existing server via SSH
- **[Quick Start](QUICK_START.md)** - Command reference
- **[Portainer Deployment](PORTAINER_DEPLOYMENT.md)** - Deploy with Portainer
- **[Technical Details](MIGRATION_CONTAINER.md)** - Migration container architecture

## Directory Structure

```
osticket_docker/
├── docker-compose.yml          # Main orchestration file
├── docker/
│   ├── web/
│   │   ├── Dockerfile          # PHP 8.2 + Apache image
│   │   └── entrypoint.sh       # Startup script
│   └── migration/
│       ├── Dockerfile          # Alpine + SSH migration tools
│       ├── migrate.sh          # Import script
│       └── pull-from-server.sh # SSH pull script
├── config/
│   ├── apache-vhost.conf       # Apache configuration
│   ├── php.ini                 # PHP settings
│   └── mariadb.cnf             # Database tuning
├── migration/
│   ├── data/                   # Migration archives
│   └── ssh/                    # SSH keys (optional)
├── web/                        # osTicket files (after migration or install)
└── Documentation files (.md)
```

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+  
- 5GB+ free disk space (more for migrations with attachments)
- For migration: SSH access to old server

## Fresh Installation

### Step 1: Download osTicket

```bash
# Download latest osTicket
wget https://github.com/osTicket/osTicket/releases/download/v1.18.1/osTicket-v1.18.1.zip
unzip osTicket.zip -d web/
mv web/upload/* web/
rmdir web/upload

# Set up config
cp web/include/ost-sampleconfig.php web/include/ost-config.php
chmod 666 web/include/ost-config.php
```

### Step 2: Start Services

```bash
docker compose up -d
```

### Step 3: Run Setup Wizard

1. Navigate to: **http://localhost:8080/setup/**

2. Database credentials:
   - Host: `db`
   - Database: `osticket`
   - Username: `osticket`
   - Password: `osticketpass`

3. After setup:
   ```bash
   rm -rf web/setup/
   chmod 644 web/include/ost-config.php
   ```

### Step 4: Access osTicket

- **Frontend**: http://localhost:8080/
- **Admin Panel**: http://localhost:8080/scp/
- **phpMyAdmin**: http://localhost:8081/

## Migrating from Existing Server

**See [REMOTE_MIGRATION_GUIDE.md](REMOTE_MIGRATION_GUIDE.md) for complete instructions.**

Quick overview:

```bash
# 1. Configure migration (optional - saves re-entering details)
cp .env.migration.example .env.migration
nano .env.migration  # Add your server details and SSH key

# 2. Start migration container
docker compose --profile migration up -d migration

# 3. Pull from old server via SSH
docker compose exec migration pull-from-server.sh
# If using .env.migration: just type 'yes' and go!
# Otherwise: enter server details interactively

# 4. Import to Docker (auto-detects latest export)
docker compose exec migration migrate.sh

# 5. Start web services
docker compose up -d web

# 6. Access at http://localhost:8080/
```

**Features:**
- ✅ Auto-excludes attachments from rsync (downloads via tar)
- ✅ Compressed transfer to save bandwidth
- ✅ Progress bars for large transfers
- ✅ Automatic permission fixes
- ✅ Auto-updates attachment paths for Docker

## Configuration

### Database Credentials

Edit `docker-compose.yml`:

```yaml
environment:
  MYSQL_ROOT_PASSWORD: your_secure_password
  MYSQL_DATABASE: osticket
  MYSQL_USER: osticket  
  MYSQL_PASSWORD: your_secure_password
```

### PHP Settings

Edit `config/php.ini`:
- `upload_max_filesize = 50M`
- `post_max_size = 50M`
- `memory_limit = 256M`

### Ports

Edit `docker-compose.yml` ports section:
- Web: `8080:80` (change 8080 to desired port)
- phpMyAdmin: `8081:80`

## Management

### Daily Operations

```bash
# Start/stop
docker compose up -d
docker compose down

# View logs
docker compose logs -f web
docker compose logs -f db

# Shell access
docker compose exec web bash
docker compose exec db mysql -u osticket -posticketpass osticket
```

### Backup & Restore

```bash
# Backup database
docker compose exec db mysqldump -u osticket -posticketpass osticket | gzip > backup_$(date +%Y%m%d).sql.gz

# Backup files
tar -czf web_backup_$(date +%Y%m%d).tar.gz web/

# Restore database  
gunzip < backup_20241016.sql.gz | docker compose exec -T db mysql -u osticket -posticketpass osticket

# Restore files
tar -xzf web_backup_20241016.tar.gz
```

### Updates

```bash
# Download new osTicket version to web/
# Then navigate to:
http://localhost:8080/scp/upgrade.php
```

## Troubleshooting

### Database Connection Failed

```bash
# Check database health
docker compose ps db
docker compose logs db

# Test connection
docker compose exec web php -r "new mysqli('db', 'osticket', 'osticketpass', 'osticket');"
```

### Permission Errors

```bash
# Fix permissions
docker compose exec web chown -R www-data:www-data /var/www/html
docker compose exec web chmod 644 /var/www/html/include/ost-config.php
```

### Setup Directory Access

If you can't access setup wizard, add your IP to `config/apache-vhost.conf`:

```apache
<Directory /var/www/html/setup>
    <RequireAll>
        Require ip 127.0.0.1
        Require ip YOUR.IP.HERE
    </RequireAll>
</Directory>
```

Restart: `docker compose restart web`

### Migration Issues

See [REMOTE_MIGRATION_GUIDE.md](REMOTE_MIGRATION_GUIDE.md#troubleshooting) troubleshooting section.

## Security

### Essential Steps

1. ✅ **Change database passwords** in `docker-compose.yml`
2. ✅ **Remove setup directory**: `rm -rf web/setup/`
3. ✅ **Lock config file**: `chmod 644 web/include/ost-config.php`
4. ✅ **Regular backups** of database and files
5. ✅ **Keep osTicket updated**

### Production

1. **Use HTTPS** - Deploy behind reverse proxy (nginx/Traefik)
2. **Remove phpMyAdmin** - Or restrict to admin IPs only
3. **Disable PHP errors** - Set `display_errors = Off` in `config/php.ini`
4. **Use secrets** - Environment files or Docker secrets for credentials
5. **Monitor logs** - Set up log aggregation and monitoring
6. **Automated backups** - Schedule regular backups to remote storage

## Resources

- **osTicket Docs**: https://docs.osticket.com/
- **osTicket Forum**: https://forum.osticket.com/
- **GitHub**: https://github.com/osTicket/osTicket

## Stack Components

- **osTicket**: GPL v2
- **PHP**: 8.2-apache
- **MariaDB**: 10.11
- **phpMyAdmin**: Latest
- **Alpine Linux**: Migration container base

## License

Docker setup provided as-is. osTicket licensed under GPL v2.
