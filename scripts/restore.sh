#!/bin/bash
set -e

# osTicket Restore Script
# Restores database and web files from backup

BACKUP_DIR="./backups"
DB_CONTAINER="osticket-db"
DB_NAME="osticket"
DB_USER="osticket"
DB_PASS="osticketpass"

echo "================================================"
echo "osTicket Restore Script"
echo "================================================"
echo ""

# List available backups
echo "Available database backups:"
ls -lh "${BACKUP_DIR}"/osticket_db_*.sql.gz 2>/dev/null || echo "  No database backups found"
echo ""

# Get backup file from argument or prompt
DB_BACKUP="${1}"
if [ -z "${DB_BACKUP}" ]; then
    read -p "Enter database backup file name (or path): " DB_BACKUP
fi

# Check if file exists
if [ ! -f "${DB_BACKUP}" ]; then
    echo "Error: Backup file '${DB_BACKUP}' not found."
    exit 1
fi

# Confirm restore
echo ""
echo "WARNING: This will replace the current database!"
echo "Backup file: ${DB_BACKUP}"
read -p "Continue with restore? (yes/NO) " -r
echo ""
if [[ ! $REPLY == "yes" ]]; then
    echo "Restore cancelled."
    exit 1
fi

# Restore database
echo "[1/1] Restoring database..."
if [[ "${DB_BACKUP}" == *.gz ]]; then
    gunzip < "${DB_BACKUP}" | docker exec -i "${DB_CONTAINER}" mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
else
    docker exec -i "${DB_CONTAINER}" mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "${DB_BACKUP}"
fi

echo ""
echo "================================================"
echo "✓ Database restored successfully!"
echo "================================================"
echo ""
echo "You may need to restart the web container:"
echo "  docker-compose restart web"
echo ""
