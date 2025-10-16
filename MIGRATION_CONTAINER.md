# Migration Container - Technical Documentation

> **📚 User Guides:** For step-by-step migration instructions, see:
> - **[REMOTE_MIGRATION_GUIDE.md](REMOTE_MIGRATION_GUIDE.md)** - Complete migration walkthrough
> - **[PORTAINER_DEPLOYMENT.md](PORTAINER_DEPLOYMENT.md)** - Portainer-specific instructions
>
> This document covers technical details and architecture.

## Overview

The migration container provides a clean, temporary solution for importing existing osTicket installations into Docker. It's designed to work seamlessly with Portainer and other container orchestration platforms.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Migration Container (Temporary)            │
│  ┌────────────────────────────────────┐    │
│  │  Alpine Linux + Migration Script   │    │
│  └────────────────────────────────────┘    │
│           │                                  │
│           ├─→ Reads: /migration/data/       │
│           ├─→ Writes: /web (volume)         │
│           └─→ Imports: db (MariaDB)         │
└─────────────────────────────────────────────┘
```

## Features

✅ **One-shot execution** - Runs once and exits
✅ **Profile-based** - Only starts when needed
✅ **Interactive** - Confirms before migration
✅ **Automatic config** - Updates database settings
✅ **Health checks** - Waits for database readiness
✅ **Portainer-friendly** - Works in Portainer console

## Usage

### Local Development

```bash
# 1. Place export archive
cp osticket_export.tar.gz migration/data/

# 2. Run migration
docker compose --profile migration run --rm migration

# 3. Confirm when prompted
# Type: yes
```

### Portainer Deployment

#### Method 1: Stack with Profile

1. Deploy stack normally (migration won't start)
2. Go to **Containers** → Find `osticket-migration`
3. Click **Console** → **Connect**
4. Run: `/usr/local/bin/migrate.sh`

#### Method 2: One-time Run

1. Upload archive to host: `/path/to/stack/migration/data/osticket_export.tar.gz`
2. In Portainer, go to **Stacks** → Your stack
3. Add environment variable: `COMPOSE_PROFILES=migration`
4. Update stack
5. Use container console to run migration
6. Remove profile after completion

#### Method 3: Manual Execution

```bash
# SSH to Portainer host
cd /path/to/stack
docker compose --profile migration run --rm migration
```

## Migration Process

The container performs these steps:

1. **Validates** archive exists
2. **Extracts** to temporary location
3. **Copies** files to web volume
4. **Updates** ost-config.php for Docker
5. **Waits** for database health check
6. **Imports** database dump
7. **Cleans up** temporary files

## Archive Format

Your export archive must contain:

```
osticket_export_YYYYMMDD_HHMMSS/
├── files/                    # Required
│   ├── include/
│   │   └── ost-config.php
│   ├── upload/
│   └── ...
├── database.sql              # Required (or .sql.gz)
└── db_credentials.txt        # Optional
```

### Creating an Export Archive

**From existing server:**

```bash
# 1. Export database
mysqldump -u DB_USER -p DB_NAME > database.sql

# 2. Copy files
mkdir -p osticket_export_$(date +%Y%m%d_%H%M%S)/files
cp -r /path/to/osticket/* osticket_export_*/files/

# 3. Move database dump
mv database.sql osticket_export_*/

# 4. Create archive
tar -czf osticket_export_$(date +%Y%m%d_%H%M%S).tar.gz osticket_export_*/
```

**Using the export script:**

```bash
# On old server
./scripts/export-from-old-server.sh /path/to/osticket
```

## Environment Variables

Configured in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `db` | Database hostname |
| `DB_NAME` | `osticket` | Database name |
| `DB_USER` | `osticket` | Database username |
| `DB_PASS` | `osticketpass` | Database password |

## Volumes

| Mount | Purpose |
|-------|---------|
| `./migration/data` → `/migration/data` | Archive location |
| `./web` → `/web` | Target for files |

## Security

- Container runs with minimal privileges
- No persistent storage (except mounted volumes)
- Automatically removed after execution (`--rm`)
- Interactive confirmation required
- No network exposure

## Troubleshooting

### Archive Not Found

```bash
# Check file exists
ls -lh migration/data/osticket_export.tar.gz

# Verify permissions
chmod 644 migration/data/osticket_export.tar.gz
```

### Database Connection Failed

```bash
# Check database health
docker compose ps db

# View database logs
docker compose logs db

# Test connection
docker compose exec db mysql -u osticket -posticketpass -e "SELECT 1"
```

### Files Not Copied

```bash
# Check archive structure
tar -tzf migration/data/osticket_export.tar.gz | head -20

# Should show:
# osticket_export_YYYYMMDD_HHMMSS/
# osticket_export_YYYYMMDD_HHMMSS/files/
# osticket_export_YYYYMMDD_HHMMSS/database.sql
```

### Permission Issues

```bash
# Fix web directory permissions
docker compose exec web chown -R www-data:www-data /var/www/html
docker compose exec web chmod -R 755 /var/www/html
```

### Database Import Failed

```bash
# Check SQL file
tar -xzf migration/data/osticket_export.tar.gz
head -20 osticket_export_*/database.sql

# Manual import
docker compose exec -T db mysql -u osticket -posticketpass osticket < osticket_export_*/database.sql
```

## Cleanup

After successful migration:

```bash
# Remove migration data
rm -rf migration/data/*

# Remove migration image (optional)
docker compose --profile migration down --rmi local

# Or keep for future migrations
# (image is small, ~50MB)
```

## Advanced Usage

### Custom Archive Path

```bash
docker compose --profile migration run --rm migration /migration/data/custom-name.tar.gz
```

### Different Database Credentials

```bash
docker compose --profile migration run --rm \
  -e DB_HOST=custom-db \
  -e DB_NAME=custom_name \
  -e DB_USER=custom_user \
  -e DB_PASS=custom_pass \
  migration
```

### Non-interactive Mode

For automation (not recommended):

```bash
# Modify migrate.sh to skip confirmation
# Or pipe 'yes' to the command
echo "yes" | docker compose --profile migration run --rm migration
```

### Debugging

```bash
# Run container with shell
docker compose --profile migration run --rm migration /bin/bash

# Then manually execute steps
ls -la /migration/data/
tar -tzf /migration/data/osticket_export.tar.gz
/usr/local/bin/migrate.sh
```

## Integration with CI/CD

### GitLab CI Example

```yaml
migrate:
  stage: deploy
  script:
    - scp osticket_export.tar.gz server:/path/to/stack/migration/data/
    - ssh server "cd /path/to/stack && docker compose --profile migration run --rm migration"
  when: manual
```

### GitHub Actions Example

```yaml
- name: Run Migration
  run: |
    scp osticket_export.tar.gz ${{ secrets.SERVER }}:/path/to/stack/migration/data/
    ssh ${{ secrets.SERVER }} "cd /path/to/stack && docker compose --profile migration run --rm migration"
```

## Comparison with Other Methods

| Method | Pros | Cons |
|--------|------|------|
| **Migration Container** | Clean, repeatable, Portainer-friendly | Requires archive preparation |
| **Manual Copy** | Simple, direct | Error-prone, no validation |
| **Import Script** | Automated | Requires host access |
| **Volume Restore** | Fast | Requires exact volume backup |

## Best Practices

1. **Test first** - Try migration in development
2. **Backup** - Always backup before migration
3. **Verify** - Check data after migration
4. **Cleanup** - Remove migration data after success
5. **Document** - Note any custom configurations
6. **Monitor** - Watch logs during migration

## Support

- See `migration/README.md` for detailed instructions
- See `PORTAINER_DEPLOYMENT.md` for Portainer-specific guidance
- Check `MIGRATION_QUICK_REFERENCE.md` for quick commands
