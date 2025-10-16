# Portainer Deployment Guide

Quick guide for deploying osTicket in Portainer.

## Fresh Installation

### Deploy Stack

1. **Stacks** → **Add stack**
2. Name: `osticket`
3. Build method: **Git Repository** or **Upload**
   - Repository: Point to your git repo
   - Or: Upload `docker-compose.yml`
4. **Deploy the stack**

### Complete Setup

1. Wait for all containers to be healthy
2. Navigate to `http://your-server:8080/setup/`
3. Database credentials:
   - Host: `db`
   - Database: `osticket`
   - Username: `osticket`
   - Password: `osticketpass`
4. After setup, remove setup directory via container console

### Access

- **osTicket**: `http://your-server:8080/`
- **Admin Panel**: `http://your-server:8080/scp/`
- **phpMyAdmin**: `http://your-server:8081/`

---

## Migration

### Step 1: Enable Migration Profile

1. Go to **Stacks** → Your stack
2. Click **Editor**
3. Add environment variable:
   ```
   COMPOSE_PROFILES=migration
   ```
4. **Update the stack**

### Step 2: Access Migration Container Console

1. Go to **Containers**
2. Find `osticket-migration`
3. Click **Console** → Select `/bin/bash` → **Connect**

### Step 3: Pull from Old Server

In the console:
```bash
pull-from-server.sh
```

Follow the prompts:
- Enter old server hostname/IP
- Enter SSH username and port
- Choose authentication (paste SSH key recommended)
- Wait for download with progress

### Step 4: Import to Docker

In the same console:
```bash
migrate.sh /migration/data/osticket_export_*.tar.gz
```

Type `yes` when prompted.

### Step 5: Verify & Cleanup

1. Open `http://your-server:8080/`
2. Test admin login
3. If successful, cleanup:
   ```bash
   rm -rf /migration/data/*
   exit
   ```
4. Remove migration profile from stack and update

---

## Portainer-Specific Tips

### View Logs

**Containers** → Select container → **Logs**

### Execute Commands

**Containers** → Select container → **Console** → **Connect**

### Volume Management

**Volumes** → Select volume → **Browse** to view files

### Backup Volumes

1. **Volumes** → Select volume
2. Click **Export** 
3. Download backup

### Change Environment Variables

1. **Stacks** → Your stack → **Editor**
2. Modify `environment` section
3. **Update the stack**

### Port Conflicts

If ports 8080 or 8081 are in use:

1. Edit stack
2. Change ports mapping:
   ```yaml
   ports:
     - "9090:80"  # Use different port
   ```
3. Update stack

### Network Issues

- Ensure containers are on same network
- Check network in **Networks** section
- Verify `db` hostname resolves in web container

---

## Troubleshooting

### Container Won't Start

1. Check logs in **Containers** → **Logs**
2. Verify all required volumes exist
3. Check for port conflicts
4. Ensure environment variables are set

### Can't Access Web UI

1. Verify container is running and healthy
2. Check port mapping in container details
3. Test with `curl http://localhost:8080` from host
4. Check firewall rules

### Database Connection Failed

Test from web container console:
```bash
mysql -h db -u osticket -posticketpass -e "SELECT 1"
```

### Permission Errors

From web container console:
```bash
chown -R www-data:www-data /var/www/html
chmod 644 /var/www/html/include/ost-config.php
```

---

## Stack Management

### Start/Stop

**Stacks** → Select stack → **Start** / **Stop**

### Update Stack

1. **Editor** → Make changes
2. **Update the stack**
3. Portainer recreates changed containers

### Remove Stack

**Stacks** → Select stack → **Delete**

Choose whether to remove volumes (careful!)

---

## Security for Portainer

### Change Default Passwords

Edit stack environment variables:
```yaml
MYSQL_ROOT_PASSWORD: your_secure_password
MYSQL_PASSWORD: your_secure_password
```

### Restrict Access

Use Portainer's access control:
- Create teams
- Assign stack permissions
- Limit user access

### Use Secrets

Instead of environment variables, use Portainer secrets:

1. **Secrets** → **Add secret**
2. Reference in stack:
   ```yaml
   secrets:
     - db_password
   ```

---

## Advanced

### Custom Networks

Create isolated network in Portainer:

1. **Networks** → **Add network**
2. Update stack to use custom network

### Volume Drivers

Use network storage drivers:
- NFS
- CIFS/SMB  
- Cloud storage plugins

### Automated Backups

Set up Portainer webhook + external backup script

### Multi-Node

Deploy across Docker Swarm nodes via Portainer

---

## Quick Reference

| Action | Location |
|--------|----------|
| Deploy | **Stacks** → **Add stack** |
| Logs | **Containers** → **Logs** |
| Console | **Containers** → **Console** |
| Volumes | **Volumes** → **Browse** |
| Edit Stack | **Stacks** → **Editor** |
| Backup Volume | **Volumes** → **Export** |

---

## See Also

- [Main README](README.md) - Installation and configuration
- [Migration Guide](REMOTE_MIGRATION_GUIDE.md) - Detailed migration instructions
- [Quick Start](QUICK_START.md) - Command reference
