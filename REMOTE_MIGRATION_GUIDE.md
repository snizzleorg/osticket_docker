# osTicket Remote Migration Guide

Migrate your existing osTicket installation to Docker by pulling data directly from your old server via SSH.

## Quick Start

**Fastest way to migrate:**

```bash
# 1. Configure once
cp .env.migration.example .env.migration
nano .env.migration  # Add server details and SSH key

# 2. Fix permissions on old server (if needed)
ssh user@oldserver
sudo chmod -R u+rX /path/to/osticket/attachments/
exit

# 3. Run migration
docker compose --profile migration up -d migration
docker compose exec migration pull-from-server.sh  # Just type 'yes'!
docker compose exec migration migrate.sh
docker compose up -d web

# 4. Access at http://localhost:8080/
```

Done! Your osTicket is now running in Docker with all data and attachments migrated.

---

## Detailed Guide

### Prerequisites

**On Old Server:**
- ✅ SSH access (password or key-based)
- ✅ osTicket installation
- ✅ MySQL/MariaDB database
- ✅ `mysqldump` installed
- ✅ Read access to osTicket files and database

**On Docker Host:**
- ✅ Docker & Docker Compose installed
- ✅ Network access to old server
- ✅ Sufficient disk space (osTicket size + database)

---

## Configuration (Recommended)

Using `.env.migration` saves you from re-entering details every time.

### Step 1: Create Config File

```bash
cp .env.migration.example .env.migration
```

### Step 2: Edit Configuration

```bash
nano .env.migration
```

**Example configuration:**

```bash
# Old Server Connection
OLD_SERVER=support.example.com
SSH_USER=admin
SSH_PORT=22

# osTicket Path on Old Server
OSTICKET_PATH=/var/www/html/osticket

# Authentication Method (1=password, 2=key content, 3=key file)
AUTH_METHOD=2

# SSH Private Key (paste your entire key)
SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAA...
...your full key here...
-----END OPENSSH PRIVATE KEY-----"
```

**Save and close** (`Ctrl+O`, `Enter`, `Ctrl+X`)

---

## Migration Process

### Step 1: Fix Permissions on Old Server (If Needed)

Some servers have unusual permissions that prevent file copying. Fix before migration:

```bash
ssh user@oldserver
sudo chmod -R u+rX /path/to/osticket/attachments/
exit
```

This adds read permissions for the owner without changing other permissions.

### Step 2: Start Migration Container

```bash
docker compose --profile migration up -d migration
```

### Step 3: Pull Data from Old Server

```bash
docker compose exec migration pull-from-server.sh
```

**If using `.env.migration`:**
- Just type `yes` when prompted
- Sit back and watch the progress bars!

**Without `.env.migration`:**
- Enter server hostname/IP
- Enter SSH username
- Enter SSH port (default: 22)
- Enter osTicket path
- Choose authentication method
- Provide password or SSH key

**What happens:**
1. ✅ Tests SSH connection
2. ✅ Checks osTicket installation
3. ✅ Reads database credentials from ost-config.php
4. ✅ Exports database with mysqldump
5. ✅ Downloads osTicket files (excluding attachments)
6. ✅ Downloads attachments separately via compressed tar
7. ✅ Fixes permissions automatically
8. ✅ Creates timestamped export directory

**Progress output:**
```
[1/6] Testing SSH connection...
  ✓ SSH connection successful

[2/6] Checking osTicket installation...
  ✓ osTicket installation found

[3/6] Reading database credentials...
  ✓ Database: osticket_db on localhost

[4/6] Exporting database from old server...
  ✓ Database exported on remote server

[5/6] Downloading files from old server...
  ✓ Database downloaded
  Downloading osTicket files (excluding attachments)...
  ✓ Files downloaded successfully

Downloading attachments via compressed tar...
  Remote attachments: 34413 files
  Size: ~24.25GB (will be compressed for transfer)

Compressed:  8.5GB 0:08:23 [17.3MB/s] [=========>  ] 85% ETA 0:01:32

  ✓ Download complete
  ✓ Successfully downloaded all 34413 attachments

[6/6] Cleaning up remote server...
  ✓ Cleanup complete
```

### Step 4: Import to Docker

```bash
docker compose exec migration migrate.sh
```

The script **auto-detects** your latest export and processes it:

```
Found export directory: osticket_export_20251016_102450
No archive found - using directory directly
Source: osticket_export_20251016_102450 (directory)
Target: /web
Database: db/osticket

Continue with migration? (yes/no): yes

[1/6] Using export directory directly...
  ✓ Using: osticket_export_20251016_102450

[2/6] Copying osTicket files...
  ✓ Files copied to /web

[3/6] Updating configuration...
  ✓ Configuration updated for Docker environment

[4/6] Waiting for database...
  ✓ Database is ready

[5/6] Importing database...
  ✓ Database imported successfully

[6/6] Updating attachment paths...
  ✓ Attachment paths updated to /var/www/html/attachments

================================================
✓ Migration completed successfully!
================================================
```

### Step 5: Start Web Services

```bash
docker compose up -d web
```

### Step 6: Access Your osTicket

- **Frontend**: http://localhost:8080/
- **Admin Panel**: http://localhost:8080/scp/
- **PHPMyAdmin** (optional): http://localhost:8081/

Use your **existing admin credentials** from the old server.

---

## Features & Optimizations

### Automatic Handling

✅ **Permission Issues** - Automatically fixes file permissions  
✅ **DEFINER Clauses** - Strips from SQL to avoid SUPER privilege errors  
✅ **SSL Requirements** - Uses `--skip-ssl` for database connections  
✅ **Attachment Paths** - Auto-updates paths for Docker environment  
✅ **Large Files** - Handles multi-GB attachments with progress tracking  

### Smart Transfer

✅ **Compressed Transfer** - Uses gzip for attachments (~60% bandwidth savings)  
✅ **Tar Method** - Bypasses rsync permission issues for attachments  
✅ **Progress Bars** - Real-time progress with speed and ETA  
✅ **Excludes Setup** - Doesn't copy setup/ directory (security)  

### Configuration Management

✅ **Environment File** - Save credentials once, reuse forever  
✅ **Auto-Detection** - Finds latest export automatically  
✅ **No Manual Edits** - All paths updated automatically  

---

## Troubleshooting

### "Permission denied" on Attachments

**Problem:** Old server has restrictive permissions (`d-wxr-xr-t`)

**Solution:** Fix permissions before migration:
```bash
ssh user@oldserver
sudo chmod -R u+rX /path/to/osticket/attachments/
```

### "Database export failed"

**Problem:** mysqldump not installed or no database access

**Solutions:**
- Install mysqldump: `sudo apt-get install mysql-client` or `sudo yum install mysql`
- Check database credentials in ost-config.php
- Verify user has mysqldump access

### "Could not connect to server"

**Problem:** SSH connection failed

**Solutions:**
- Check server hostname/IP is correct
- Verify SSH port (usually 22)
- Test SSH key: `ssh -i ~/.ssh/id_rsa user@server`
- Check firewall allows SSH from Docker host

### Attachments Not Showing

**Problem:** Database still points to old server paths

**Solution:** Already handled automatically in migrate.sh, but if needed manually:
```bash
docker compose exec db mariadb -u osticket -posticketpass osticket
UPDATE ost_config SET value='/var/www/html/attachments' WHERE namespace='plugin.7.instance.1';
exit
```

### Slow Transfer

**Problem:** Large attachment directory, slow internet

**Solutions:**
- Migration uses compression automatically (saves ~60% bandwidth)
- Progress bar shows speed and ETA
- Consider running migration during off-hours
- For very slow connections: Use alternative method (manual download + import)

### "Database not available"

**Problem:** Database container not ready

**Solution:** Script waits automatically up to 30 seconds. If still fails:
```bash
docker compose ps  # Check db container status
docker compose logs db  # Check for errors
docker compose restart db
```

---

## Advanced Usage

### Manual Specification

If you don't want auto-detection:

```bash
docker compose exec migration migrate.sh /migration/data/osticket_export_20251016_102450
```

### Verify Before Import

Check what was downloaded:

```bash
docker compose exec migration ls -lh /migration/data/
docker compose exec migration find /migration/data/*/files/attachments -type f | wc -l
```

### Re-run Migration

If something goes wrong, clean up and re-run:

```bash
# Clean exported data
docker compose exec migration rm -rf /migration/data/*

# Clear web directory
docker compose exec web rm -rf /var/www/html/*

# Re-pull from server
docker compose exec migration pull-from-server.sh
docker compose exec migration migrate.sh
```

### Database Inspection

Check imported data:

```bash
# Access database
docker compose exec db mariadb -u osticket -posticketpass osticket

# Check admin users
SELECT staff_id, username, email FROM ost_staff WHERE isadmin=1;

# Check ticket count
SELECT COUNT(*) FROM ost_ticket;

# Check configuration
SELECT * FROM ost_config WHERE namespace='core' LIMIT 10;
```

---

## Security Notes

### SSH Keys

- `.env.migration` is automatically gitignored
- Never commit SSH keys to version control
- Use read-only SSH keys when possible
- Remove migration container after migration:
  ```bash
  docker compose --profile migration down
  ```

### Post-Migration

1. ✅ Test admin login
2. ✅ Verify attachments load correctly
3. ✅ Check email configuration
4. ✅ Test ticket creation
5. ✅ Clean up migration data:
   ```bash
   rm -rf migration/data/*
   ```

### Production Deployment

- Change database passwords in `docker-compose.yml`
- Use reverse proxy with HTTPS (nginx/Traefik)
- Remove phpMyAdmin or restrict access
- Set up automated backups
- Monitor logs and performance

---

## Comparison: Manual vs Automated

### Manual Method (Old Way)
```
1. SSH to old server
2. Manually export database
3. Download database with scp
4. Tar attachments directory  
5. Download tar with scp
6. Rsync other files
7. Extract everything
8. Manually edit ost-config.php
9. Import database manually
10. Fix permissions
11. Update attachment paths
12. Test and troubleshoot
```
⏱️ **Time:** 30-60 minutes + troubleshooting

### Automated Method (Current)
```
1. Configure .env.migration (once)
2. Run pull-from-server.sh
3. Run migrate.sh
4. Done!
```
⏱️ **Time:** 5 minutes + transfer time (automated)

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Docker Host                            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Migration Container              │ │
│  │  - Alpine Linux                   │ │
│  │  - SSH client                     │ │
│  │  - rsync, tar, gzip              │ │
│  │  - mariadb-client                │ │
│  │  - pv (progress viewer)          │ │
│  │  - bc (calculator)               │ │
│  │                                   │ │
│  │  Scripts:                         │ │
│  │  • pull-from-server.sh           │ │
│  │  • migrate.sh                    │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Volumes:                               │
│  • ./migration/data    → /migration/data│
│  • ./web              → /web           │
│  • .env.migration (optional)           │
└─────────────────────────────────────────┘
              │
              │ SSH (encrypted)
              ↓
┌─────────────────────────────────────────┐
│  Old Server                             │
│  • osTicket files                       │
│  • MySQL/MariaDB database               │
│  • Attachments directory                │
└─────────────────────────────────────────┘
```

---

## Support

- **Documentation**: [DOCS.md](DOCS.md)
- **Quick Start**: [QUICK_START.md](QUICK_START.md)
- **Technical Details**: [MIGRATION_CONTAINER.md](MIGRATION_CONTAINER.MD)
- **osTicket Docs**: https://docs.osticket.com/
- **osTicket Forum**: https://forum.osticket.com/

---

## Tips & Best Practices

### Before Migration

- ✅ Test SSH access first
- ✅ Check available disk space
- ✅ Backup old server (just in case)
- ✅ Note down admin credentials
- ✅ Fix attachment permissions if needed

### During Migration

- ✅ Use .env.migration for repeated migrations
- ✅ Monitor progress bars
- ✅ Don't interrupt large transfers
- ✅ Check for error messages

### After Migration

- ✅ Test all functionality
- ✅ Verify attachments work
- ✅ Check email sending
- ✅ Update DNS/firewall if needed
- ✅ Clean up migration data
- ✅ Remove migration container

### Performance

- Run migration during low-traffic hours
- Use wired connection for Docker host
- Close unnecessary applications
- Monitor system resources

---

## What Gets Migrated?

✅ **Database**
- All tickets
- User accounts & permissions
- Email templates
- Help topics
- Custom fields
- Forms
- Settings & configuration

✅ **Files**
- All attachments (even with 34,000+ files!)
- Ticket attachments
- Profile pictures
- Custom themes
- Logos and branding
- Plugins

✅ **Configuration**
- Database credentials (updated for Docker)
- Email settings
- LDAP/Active Directory config
- Plugin settings
- Custom configurations

❌ **Not Migrated**
- SSL certificates (Docker host handles this)
- Apache/PHP config (Docker uses optimized defaults)
- System cron jobs (use Docker host cron or swarm scheduler)

---

## Next Steps

After successful migration:

1. **Verify Everything Works**
   - Test login
   - Check tickets
   - Verify attachments
   - Test email

2. **Secure Your Installation**
   - Change passwords
   - Set up HTTPS
   - Configure firewall
   - Enable backups

3. **Optimize**
   - Tune PHP settings
   - Configure cron jobs
   - Set up monitoring
   - Plan updates

4. **Clean Up**
   ```bash
   rm -rf migration/data/*
   docker compose --profile migration down
   ```

5. **Start Using**
   - Train team on new URL
   - Update bookmarks
   - Configure email alerts
   - Enjoy your containerized osTicket! 🎉
