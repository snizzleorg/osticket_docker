# Migration Directory

This directory stores data pulled from your old osTicket server and SSH keys for authentication.

## Structure

```
migration/
├── data/                          # Downloaded exports
│   ├── osticket_export_TIMESTAMP/ # Extracted export
│   │   ├── files/                # osTicket files
│   │   │   ├── attachments/      # All attachments
│   │   │   └── ...              # Other osTicket files
│   │   └── database.sql.gz       # Database dump
│   └── osticket_export_*.tar.gz   # Archived exports (optional)
│
├── ssh/                          # SSH keys (optional)
│   ├── id_rsa                   # Private key for old server
│   └── id_rsa.pub              # Public key
│
└── README.md                     # This file
```

## Usage

### Method 1: Environment File (Recommended)

Store your configuration in `.env.migration` at project root:

```bash
cd ..
cp .env.migration.example .env.migration
nano .env.migration
```

Then run:

```bash
docker compose exec migration pull-from-server.sh
```

Just type `yes` and it uses your saved configuration!

### Method 2: Interactive (No Config File)

Run without `.env.migration` and enter details interactively:

```bash
docker compose exec migration pull-from-server.sh
```

### Method 3: SSH Key Files (Legacy)

Place your SSH key in `migration/ssh/`:

```bash
cp ~/.ssh/id_rsa migration/ssh/
chmod 600 migration/ssh/id_rsa
```

Then use option 3 (key file) when running pull-from-server.sh.

## Data Directory

### Auto-Created Exports

When you run `pull-from-server.sh`, it creates a timestamped directory:

```
migration/data/osticket_export_20251016_102450/
├── files/
│   ├── attachments/           # 34,000+ files, 25GB
│   ├── include/
│   ├── scp/
│   └── ...
└── database.sql.gz           # Compressed database dump
```

### migrate.sh Auto-Detection

The `migrate.sh` script automatically finds and uses the latest export:

```bash
docker compose exec migration migrate.sh
```

Output:
```
Found export directory: osticket_export_20251016_102450
No archive found - using directory directly
```

## Cleanup

After successful migration, remove the data:

```bash
# From host
rm -rf migration/data/*

# Or from container
docker compose exec migration rm -rf /migration/data/*
```

**Note:** Keep the `data/` and `ssh/` directories - they're needed for the volume mount.

## Configuration File

Create `.env.migration` in project root (parent of migration/):

```bash
# Old Server Connection
OLD_SERVER=support.example.com
SSH_USER=admin
SSH_PORT=22

# osTicket Path
OSTICKET_PATH=/var/www/html/osticket

# Authentication
AUTH_METHOD=2  # 1=password, 2=key content, 3=key file

# SSH Key (for AUTH_METHOD=2)
SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
...your full private key here...
-----END OPENSSH PRIVATE KEY-----"
```

This file is automatically gitignored for security.

## Security

### SSH Keys

- ✅ `.env.migration` is gitignored
- ✅ Never commit private keys
- ✅ Use read-only keys when possible
- ✅ Remove keys after migration

### Cleanup

After migration is complete and verified:

```bash
# Remove sensitive data
rm -rf migration/data/*
rm -rf migration/ssh/*
rm ../.env.migration  # Optional

# Stop migration container
docker compose --profile migration down
```

## Troubleshooting

### Permission Errors on Data

If you see permission errors accessing `/migration/data/`:

```bash
# Fix from host
sudo chown -R $USER:$USER migration/data/

# Or from container
docker compose exec migration chown -R root:root /migration/data/
```

### SSH Key Not Found

If using key files and getting "key not found":

```bash
# Check mount
docker compose exec migration ls -la /root/.ssh/

# Verify permissions
ls -l migration/ssh/
chmod 600 migration/ssh/id_rsa
```

### Large Export Taking Space

Exports can be large. Check disk space:

```bash
# Check size
du -sh migration/data/*

# Free up space after successful migration
rm -rf migration/data/osticket_export_*
```

## Volume Mounts

From `docker-compose.yml`:

```yaml
volumes:
  - ./migration/data:/migration/data        # Export storage
  - ./migration/ssh:/root/.ssh:ro          # SSH keys (read-only)
  - ./.env.migration:/migration/.env.migration:ro  # Config (optional)
```

## Tips

### Repeated Migrations

If testing or running multiple migrations:

```bash
# Use .env.migration - configure once, run many times
docker compose exec migration pull-from-server.sh  # Always fast!
```

### Large Attachments

For 20GB+ attachments:

- Migration uses compressed transfer automatically
- Progress bar shows transfer speed and ETA
- Transfer rate typically 5-15 MB/s depending on connection
- Example: 25GB takes ~10-15 minutes over fast connection

### Bandwidth Optimization

Compression saves ~60% bandwidth:

```
Uncompressed: 25GB transfer
Compressed:   ~10GB transfer
Savings:      15GB (60% less!)
```

## Common Tasks

### Check What Was Downloaded

```bash
docker compose exec migration ls -lh /migration/data/
docker compose exec migration find /migration/data/*/files/attachments -type f | wc -l
```

### Verify Database

```bash
docker compose exec migration gunzip -c /migration/data/*/database.sql.gz | head -20
```

### Test SSH Connection

```bash
docker compose exec migration /bin/bash
ssh -i /root/.ssh/id_rsa user@server
exit
```

### Manual Download (If Needed)

```bash
# From host
scp user@oldserver:/path/to/backup.tar.gz migration/data/
```

## Files Not Tracked

These are gitignored:

```
migration/data/*       # Downloaded exports
migration/ssh/*        # SSH keys
.env.migration         # Configuration with credentials
```

Only these are tracked:

```
migration/README.md           # This file
migration/ssh/README.md       # SSH directory placeholder
```

## Next Steps

After placing files in this directory:

1. **Run Migration:**
   ```bash
   docker compose exec migration migrate.sh
   ```

2. **Verify Import:**
   ```bash
   docker compose up -d web
   # Visit http://localhost:8080/
   ```

3. **Clean Up:**
   ```bash
   rm -rf migration/data/*
   ```

## See Also

- [REMOTE_MIGRATION_GUIDE.md](../REMOTE_MIGRATION_GUIDE.md) - Complete migration guide
- [MIGRATION_CONTAINER.md](../MIGRATION_CONTAINER.md) - Technical details
- [README.md](../README.md) - Main documentation
