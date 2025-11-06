# 🚀 Portainer Deployment Guide

## ✅ Build Complete!

Your osTicket Docker image has been successfully built and pushed to Docker Hub:

**Image:** `universaldilettant/osticket-web:latest`  
**Platform:** linux/amd64 (compatible with Portainer)  
**Status:** ✅ Available on Docker Hub

---

## 📋 Deploy to Portainer

### Step 1: Access Portainer
1. Log into your Portainer instance
2. Navigate to **Stacks** → **Add Stack**

### Step 2: Create New Stack
1. **Name your stack:** `osticket` (or any name you prefer)
2. **Build method:** Select "Web editor"
3. **Copy the contents** of `docker-compose.portainer.yml` into the editor

### Step 3: Review Configuration

The stack includes:
- ✅ **osTicket Web** (your custom image from Docker Hub)
- ✅ **MariaDB 10.11** (database)
- ✅ **phpMyAdmin** (database management)
- ✅ **Migration Tool** (optional - only starts with `migration` profile)

**Default Ports:**
- osTicket: `8080`
- phpMyAdmin: `8081`

### Step 4: ⚠️ IMPORTANT - Change Passwords!

Before deploying to production, update these environment variables:

```yaml
# Database service
MYSQL_ROOT_PASSWORD: supersecret      # ← Change this!
MYSQL_PASSWORD: osticketpass          # ← Change this!

# Web service
DB_PASS: osticketpass                 # ← Must match MYSQL_PASSWORD

# phpMyAdmin service
PMA_PASSWORD: supersecret             # ← Must match MYSQL_ROOT_PASSWORD
```

### Step 5: Deploy
1. Click **Deploy the stack**
2. Wait for all containers to start (check the status)
3. Verify all services are running

---

## 🌐 Access Your Services

Once deployed, access your services at:

- **osTicket:** `http://your-server-ip:8080`
- **phpMyAdmin:** `http://your-server-ip:8081`

---

## 📦 Volumes

The stack creates these persistent volumes:
- `osticket_dbdata` - Database files
- `osticket_web` - osTicket application files
- `osticket_uploads` - File attachments
- `osticket_config` - Configuration files

---

## 🔄 Updating the Image

When you make changes and want to update:

1. **Rebuild locally:**
   ```bash
   cd /Users/steffen/CascadeProjects/windsurf-project/osticket_docker
   ./build-for-portainer.sh
   ```

2. **In Portainer:**
   - Go to your stack
   - Click **Pull and redeploy**
   - Or manually pull the latest image in the Images section

---

## 🔄 Using the Migration Tool (Optional)

The migration container is included but **disabled by default** (uses Docker profile).

### When to use it:
- Migrating from an existing osTicket installation
- Pulling data from a remote server
- Database imports/exports

### How to enable:
In Portainer, when deploying the stack, you can enable the migration profile by adding an environment variable or manually starting the container.

**To use the migration tool:**
1. Deploy the stack normally (migration won't start)
2. If needed, go to Containers → osticket-migration → Start
3. Access the container console in Portainer
4. Run migration commands like `pull-from-server.sh`

**Note:** The migration container includes:
- SSH client for remote connections
- MySQL client for database operations
- rsync for file transfers
- Migration scripts

---

## 🐛 Troubleshooting

### Container won't start
- Check logs in Portainer (click container → Logs)
- Verify database is healthy before web starts

### Can't access osTicket
- Verify port 8080 is not blocked by firewall
- Check container is running: `docker ps`

### Database connection errors
- Ensure `DB_PASS` matches `MYSQL_PASSWORD`
- Wait for database health check to pass

### Need to reset
```bash
# In Portainer, stop the stack and remove volumes
# Then redeploy
```

---

## 📝 First-Time Setup

When you first access osTicket at `http://your-server-ip:8080`:

1. You'll see the installation wizard
2. **Database Configuration:**
   - MySQL Hostname: `db`
   - MySQL Database: `osticket`
   - MySQL Username: `osticket`
   - MySQL Password: `osticketpass` (or your custom password)

3. Complete the setup wizard
4. **IMPORTANT:** After installation, the setup directory should be removed for security

---

## 🔒 Security Checklist

Before going to production:

- [ ] Change all default passwords
- [ ] Configure firewall rules
- [ ] Set up SSL/TLS (reverse proxy recommended)
- [ ] Remove phpMyAdmin if not needed
- [ ] Regular backups of volumes
- [ ] Update osTicket admin password

---

## 📚 Additional Resources

- **osTicket Documentation:** https://docs.osticket.com/
- **Docker Hub Image:** https://hub.docker.com/r/universaldilettant/osticket-web
- **Source Files:** `/Users/steffen/CascadeProjects/windsurf-project/osticket_docker`

---

## 💾 Backup

To backup your data:

1. In Portainer, go to **Volumes**
2. Export each volume:
   - `osticket_dbdata`
   - `osticket_uploads`
   - `osticket_web`

Or use the backup script:
```bash
./scripts/backup.sh
```

---

**Need help?** Check the logs in Portainer or run `docker logs osticket-web`
