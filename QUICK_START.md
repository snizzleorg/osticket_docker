# Quick Start Guide

Fast command reference for common osTicket Docker operations.

## Migration (Most Common)

### One-Time Setup
```bash
# Configure once
cp .env.migration.example .env.migration
nano .env.migration  # Add server details and SSH key
```

### Run Migration
```bash
# Pull data from old server
docker compose --profile migration up -d migration
docker compose exec migration pull-from-server.sh  # Type 'yes'

# Import to Docker
docker compose exec migration migrate.sh           # Type 'yes'

# Start web services
docker compose up -d web

# Access at http://localhost:8080/
```

### Clean Up After
```bash
rm -rf migration/data/*
docker compose --profile migration down
```

---

## Fresh Installation

```bash
# 1. Download osTicket
wget https://github.com/osTicket/osTicket/releases/download/v1.18.1/osTicket-v1.18.1.zip
unzip osTicket.zip -d web/
mv web/upload/* web/ && rmdir web/upload

# 2. Prepare config
cp web/include/ost-sampleconfig.php web/include/ost-config.php
chmod 666 web/include/ost-config.php

# 3. Start services
docker compose up -d

# 4. Run setup wizard
open http://localhost:8080/setup/
# Database: db / osticket / osticket / osticketpass

# 5. Secure after setup
rm -rf web/setup/
chmod 644 web/include/ost-config.php
```

---

## Daily Operations

### Start/Stop
```bash
docker compose up -d        # Start all services
docker compose down         # Stop all services
docker compose restart web  # Restart web only
docker compose restart db   # Restart database only
```

### View Logs
```bash
docker compose logs -f              # All services
docker compose logs -f web          # Web server only
docker compose logs -f db           # Database only
docker compose logs --tail 50 web   # Last 50 lines
```

### Container Shell Access
```bash
docker compose exec web bash        # Web container
docker compose exec db bash         # Database container
docker compose exec migration bash  # Migration container
```

### Database Access
```bash
# MySQL shell
docker compose exec db mariadb -u osticket -posticketpass osticket

# Quick query
docker compose exec db mariadb -u osticket -posticketpass osticket -e "SELECT COUNT(*) FROM ost_ticket;"

# List admin users
docker compose exec db mariadb -u osticket -posticketpass osticket -e "SELECT username, email FROM ost_staff WHERE isadmin=1;"
```

---

## Backup & Restore

### Backup
```bash
# Database
docker compose exec db mysqldump -u osticket -posticketpass osticket | gzip > backup_$(date +%Y%m%d).sql.gz

# Files (including attachments)
tar -czf web_backup_$(date +%Y%m%d).tar.gz web/

# Everything
tar -czf full_backup_$(date +%Y%m%d).tar.gz web/ && \
docker compose exec db mysqldump -u osticket -posticketpass osticket | gzip >> db_$(date +%Y%m%d).sql.gz
```

### Restore
```bash
# Database
gunzip < backup_20241016.sql.gz | docker compose exec -T db mariadb -u osticket -posticketpass osticket

# Files
tar -xzf web_backup_20241016.tar.gz

# Restart services
docker compose restart
```

---

## Troubleshooting

### Check Container Status
```bash
docker compose ps                    # All containers
docker compose ps web                # Web container only
docker compose logs db --tail 100    # Check database logs
```

### Fix Permissions
```bash
docker compose exec web chown -R www-data:www-data /var/www/html
docker compose exec web chmod 644 /var/www/html/include/ost-config.php
```

### Reset Database
```bash
docker compose down
docker volume rm osticket_docker_dbdata
docker compose up -d
# Re-run migration or setup
```

### Clean Everything
```bash
docker compose down -v              # Stop and remove volumes
rm -rf web/* migration/data/*       # Remove files
docker compose up -d                # Fresh start
```

### Test Database Connection
```bash
docker compose exec web php -r "new mysqli('db', 'osticket', 'osticketpass', 'osticket') or die('Failed');"
```

---

## Configuration Changes

### Change Database Password
```yaml
# Edit docker-compose.yml
environment:
  MYSQL_PASSWORD: new_password

# Update in web/include/ost-config.php
define('DBPASS','new_password');

# Restart
docker compose down && docker compose up -d
```

### Change Web Port
```yaml
# Edit docker-compose.yml
ports:
  - "9000:80"  # Change 8080 to 9000

# Restart
docker compose down && docker compose up -d
# Access at http://localhost:9000/
```

### Enable PHPMyAdmin
```bash
docker compose up -d phpmyadmin
# Access at http://localhost:8081/
# Server: db
# Username: osticket
# Password: osticketpass
```

---

## Migration Shortcuts

### Re-run Migration
```bash
docker compose exec migration rm -rf /migration/data/*
docker compose exec web rm -rf /var/www/html/*
docker compose exec migration pull-from-server.sh
docker compose exec migration migrate.sh
docker compose up -d web
```

### Check Migration Data
```bash
# List exports
docker compose exec migration ls -lh /migration/data/

# Count attachments
docker compose exec migration find /migration/data/*/files/attachments -type f | wc -l

# Check database size
docker compose exec migration ls -lh /migration/data/*/database.sql.gz
```

### Test Without Importing
```bash
# Just pull data (don't import)
docker compose exec migration pull-from-server.sh
# Inspect files
docker compose exec migration ls -R /migration/data/
# Then import when ready
docker compose exec migration migrate.sh
```

---

## Updates

### Update osTicket
```bash
# 1. Backup first!
tar -czf backup_before_update.tar.gz web/

# 2. Download new version
wget https://github.com/osTicket/osTicket/releases/download/vX.X.X/osTicket-vX.X.X.zip
unzip osTicket-vX.X.X.zip -d web_new/

# 3. Copy new files (keep config)
cp web/include/ost-config.php web_new/include/
rm -rf web/
mv web_new/ web/

# 4. Run upgrade
open http://localhost:8080/scp/upgrade.php

# 5. Cleanup
rm -rf web/setup/
```

### Update Docker Images
```bash
docker compose pull                  # Pull latest images
docker compose up -d --build        # Rebuild and restart
docker image prune -f               # Clean old images
```

---

## Performance Tuning

### Check Resource Usage
```bash
docker stats                        # Real-time stats
docker compose top                  # Process list
docker system df                    # Disk usage
```

### Increase PHP Limits
```ini
# Edit config/php.ini
upload_max_filesize = 100M
post_max_size = 100M
memory_limit = 512M

# Restart
docker compose restart web
```

### Database Optimization
```bash
docker compose exec db mariadb -u osticket -posticketpass osticket -e "OPTIMIZE TABLE ost_ticket;"
docker compose exec db mariadb -u osticket -posticketpass osticket -e "ANALYZE TABLE ost_ticket;"
```

---

## URLs

- **Frontend**: http://localhost:8080/
- **Admin Panel**: http://localhost:8080/scp/
- **PHPMyAdmin**: http://localhost:8081/
- **API**: http://localhost:8080/api/tickets.json

---

## Environment Files

### Create Production Config
```bash
# Copy example
cp .env.migration.example .env.production

# Edit for production
nano .env.production

# Use in docker-compose
docker compose --env-file .env.production up -d
```

---

## Docker Compose Profiles

```bash
# Default (web + db)
docker compose up -d

# With PHPMyAdmin
docker compose --profile phpmyadmin up -d

# With Migration
docker compose --profile migration up -d

# Everything
docker compose --profile migration --profile phpmyadmin up -d
```

---

## Common File Locations

### In Container
- **Web root**: `/var/www/html/`
- **Config**: `/var/www/html/include/ost-config.php`
- **Attachments**: `/var/www/html/attachments/`
- **Logs**: `/var/log/apache2/`

### On Host
- **Web root**: `./web/`
- **Database**: Docker volume `dbdata`
- **Uploads**: Docker volume `uploads`
- **Migration**: `./migration/data/`

---

## Security Checklist

```bash
# After installation or migration:
[ ] Change database passwords
[ ] Remove setup directory: rm -rf web/setup/
[ ] Lock config: chmod 644 web/include/ost-config.php
[ ] Test admin login
[ ] Verify SSL (if using reverse proxy)
[ ] Set up backups
[ ] Update firewall rules
[ ] Enable fail2ban (host level)
[ ] Review user permissions
[ ] Test email sending
```

---

## One-Liners

```bash
# Quick backup
docker compose exec db mysqldump -u osticket -posticketpass osticket | gzip > backup.sql.gz && tar -czf files.tar.gz web/

# Reset admin password (replace 'admin' and 'newpass')
docker compose exec db mariadb -u osticket -posticketpass osticket -e "UPDATE ost_staff SET passwd=MD5('newpass') WHERE username='admin';"

# Count tickets
docker compose exec db mariadb -u osticket -posticketpass osticket -e "SELECT COUNT(*) as total_tickets FROM ost_ticket;"

# Find large attachments
docker compose exec web find /var/www/html/attachments -type f -size +10M -exec ls -lh {} \;

# Check disk usage
docker compose exec web du -sh /var/www/html/*

# Follow all logs
docker compose logs -f --tail 0

# Restart everything
docker compose restart

# Full cleanup and restart
docker compose down && docker compose up -d
```

---

## Getting Help

- **Main Docs**: [README.md](README.md)
- **Migration Guide**: [REMOTE_MIGRATION_GUIDE.md](REMOTE_MIGRATION_GUIDE.md)
- **Full Documentation**: [DOCS.md](DOCS.md)
- **osTicket Docs**: https://docs.osticket.com/
- **osTicket Forum**: https://forum.osticket.com/

---

## Quick Reference Card

### Most Used Commands
| Task | Command |
|------|---------|
| Start services | `docker compose up -d` |
| Stop services | `docker compose down` |
| View logs | `docker compose logs -f web` |
| Shell access | `docker compose exec web bash` |
| Database shell | `docker compose exec db mariadb -u osticket -posticketpass osticket` |
| Backup DB | `docker compose exec db mysqldump -u osticket -posticketpass osticket \| gzip > backup.sql.gz` |
| Migration pull | `docker compose exec migration pull-from-server.sh` |
| Migration import | `docker compose exec migration migrate.sh` |
| Check status | `docker compose ps` |
| Restart web | `docker compose restart web` |
