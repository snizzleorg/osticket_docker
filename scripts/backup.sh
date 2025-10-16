#!/bin/bash
set -e

# osTicket Backup Script
# Creates backups of database and web files

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_CONTAINER="osticket-db"
DB_NAME="osticket"
DB_USER="osticket"
DB_PASS="osticketpass"

echo "================================================"
echo "osTicket Backup Script"
echo "================================================"
echo ""
echo "Backup Date: ${DATE}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup database
echo "[1/3] Backing up database..."
docker exec "${DB_CONTAINER}" mysqldump \
    -u "${DB_USER}" \
    -p"${DB_PASS}" \
    "${DB_NAME}" | gzip > "${BACKUP_DIR}/osticket_db_${DATE}.sql.gz"
echo "  ✓ Database backup: ${BACKUP_DIR}/osticket_db_${DATE}.sql.gz"

# Backup web files
echo "[2/3] Backing up web files..."
tar -czf "${BACKUP_DIR}/osticket_web_${DATE}.tar.gz" web/
echo "  ✓ Web files backup: ${BACKUP_DIR}/osticket_web_${DATE}.tar.gz"

# Backup config files
echo "[3/3] Backing up configuration..."
tar -czf "${BACKUP_DIR}/osticket_config_${DATE}.tar.gz" config/ docker-compose.yml
echo "  ✓ Config backup: ${BACKUP_DIR}/osticket_config_${DATE}.tar.gz"

# Calculate sizes
DB_SIZE=$(du -h "${BACKUP_DIR}/osticket_db_${DATE}.sql.gz" | cut -f1)
WEB_SIZE=$(du -h "${BACKUP_DIR}/osticket_web_${DATE}.tar.gz" | cut -f1)
CONFIG_SIZE=$(du -h "${BACKUP_DIR}/osticket_config_${DATE}.tar.gz" | cut -f1)

echo ""
echo "================================================"
echo "✓ Backup completed successfully!"
echo "================================================"
echo ""
echo "Backup Summary:"
echo "  Database: ${DB_SIZE}"
echo "  Web files: ${WEB_SIZE}"
echo "  Config: ${CONFIG_SIZE}"
echo "  Location: ${BACKUP_DIR}/"
echo ""
echo "To restore from backup:"
echo "  Database: gunzip < ${BACKUP_DIR}/osticket_db_${DATE}.sql.gz | docker exec -i ${DB_CONTAINER} mysql -u ${DB_USER} -p${DB_PASS} ${DB_NAME}"
echo "  Web files: tar -xzf ${BACKUP_DIR}/osticket_web_${DATE}.tar.gz"
echo ""
