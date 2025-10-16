#!/bin/bash
set -e

# Export Script for Existing osTicket Installation
# Run this script ON THE OLD SERVER to export everything needed for migration

EXPORT_DIR="osticket_export_$(date +%Y%m%d_%H%M%S)"
OSTICKET_PATH="${1:-/var/www/html/osticket}"
CONFIG_FILE="${OSTICKET_PATH}/include/ost-config.php"

echo "================================================"
echo "osTicket Migration Export Script"
echo "================================================"
echo ""
echo "This script will export your osTicket installation"
echo "Export directory: ${EXPORT_DIR}"
echo "osTicket path: ${OSTICKET_PATH}"
echo ""

# Verify osTicket path exists
if [ ! -d "${OSTICKET_PATH}" ]; then
    echo "Error: osTicket directory not found at ${OSTICKET_PATH}"
    echo "Usage: $0 /path/to/osticket"
    exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: ost-config.php not found at ${CONFIG_FILE}"
    exit 1
fi

# Create export directory
mkdir -p "${EXPORT_DIR}"

echo "[1/5] Extracting database credentials from ost-config.php..."

# Extract database configuration
DB_HOST=$(grep -oP "define\('DBHOST',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "localhost")
DB_NAME=$(grep -oP "define\('DBNAME',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "")
DB_USER=$(grep -oP "define\('DBUSER',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "")
DB_PASS=$(grep -oP "define\('DBPASS',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "")
DB_PREFIX=$(grep -oP "define\('TABLE_PREFIX',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "ost_")

echo "  Database Host: ${DB_HOST}"
echo "  Database Name: ${DB_NAME}"
echo "  Database User: ${DB_USER}"
echo "  Table Prefix: ${DB_PREFIX}"

if [ -z "${DB_NAME}" ]; then
    echo "Error: Could not extract database name from config file"
    exit 1
fi

# Save credentials to file
cat > "${EXPORT_DIR}/db_credentials.txt" << EOF
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_PREFIX=${DB_PREFIX}
EOF

echo "[2/5] Exporting database..."

# Prompt for database password if not found in config
if [ -z "${DB_PASS}" ]; then
    echo "Database password not found in config file."
    read -sp "Enter database password for user ${DB_USER}: " DB_PASS
    echo ""
fi

# Export database
mysqldump -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" | gzip > "${EXPORT_DIR}/database.sql.gz"
echo "  ✓ Database exported to database.sql.gz"

echo "[3/5] Copying osTicket files..."

# Copy all files
cp -r "${OSTICKET_PATH}" "${EXPORT_DIR}/web"
echo "  ✓ Files copied"

echo "[4/5] Extracting configuration information..."

# Extract additional config details
cat > "${EXPORT_DIR}/migration_info.txt" << EOF
==============================================
osTicket Migration Information
==============================================
Export Date: $(date)
Source Path: ${OSTICKET_PATH}

Database Configuration:
  Host: ${DB_HOST}
  Name: ${DB_NAME}
  User: ${DB_USER}
  Prefix: ${DB_PREFIX}

osTicket Version:
EOF

# Try to get osTicket version
if [ -f "${OSTICKET_PATH}/main.inc.php" ]; then
    OSTICKET_VERSION=$(grep -oP "THIS_VERSION\s*=\s*'\\K[^']+(?=')" "${OSTICKET_PATH}/main.inc.php" || echo "Unknown")
    echo "  Version: ${OSTICKET_VERSION}" >> "${EXPORT_DIR}/migration_info.txt"
fi

# Check for plugins
if [ -d "${OSTICKET_PATH}/include/plugins" ]; then
    echo "" >> "${EXPORT_DIR}/migration_info.txt"
    echo "Installed Plugins:" >> "${EXPORT_DIR}/migration_info.txt"
    ls -1 "${OSTICKET_PATH}/include/plugins" >> "${EXPORT_DIR}/migration_info.txt" 2>/dev/null || echo "  None" >> "${EXPORT_DIR}/migration_info.txt"
fi

# Get attachment storage info
ATTACHMENTS_DIR=$(grep -oP "define\('UPLOAD_DIR',\s*'\\K[^']+(?=')" "${CONFIG_FILE}" || echo "${OSTICKET_PATH}/attachments")
if [ -d "${ATTACHMENTS_DIR}" ]; then
    ATTACHMENTS_SIZE=$(du -sh "${ATTACHMENTS_DIR}" | cut -f1)
    echo "" >> "${EXPORT_DIR}/migration_info.txt"
    echo "Attachments:" >> "${EXPORT_DIR}/migration_info.txt"
    echo "  Directory: ${ATTACHMENTS_DIR}" >> "${EXPORT_DIR}/migration_info.txt"
    echo "  Size: ${ATTACHMENTS_SIZE}" >> "${EXPORT_DIR}/migration_info.txt"
fi

# PHP and system info
echo "" >> "${EXPORT_DIR}/migration_info.txt"
echo "System Information:" >> "${EXPORT_DIR}/migration_info.txt"
echo "  PHP Version: $(php -v | head -n1)" >> "${EXPORT_DIR}/migration_info.txt"
echo "  OS: $(uname -a)" >> "${EXPORT_DIR}/migration_info.txt"

echo "  ✓ Migration info saved"

echo "[5/5] Creating archive..."

# Create tarball
tar -czf "${EXPORT_DIR}.tar.gz" "${EXPORT_DIR}"
ARCHIVE_SIZE=$(du -sh "${EXPORT_DIR}.tar.gz" | cut -f1)

echo "  ✓ Archive created: ${EXPORT_DIR}.tar.gz (${ARCHIVE_SIZE})"

# Display summary
echo ""
echo "================================================"
echo "✓ Export completed successfully!"
echo "================================================"
echo ""
cat "${EXPORT_DIR}/migration_info.txt"
echo ""
echo "================================================"
echo "Next Steps:"
echo "================================================"
echo ""
echo "1. Download the export archive from this server:"
echo "   scp user@thisserver:$(pwd)/${EXPORT_DIR}.tar.gz ."
echo ""
echo "2. On your new Docker server, run:"
echo "   ./scripts/import-to-docker.sh ${EXPORT_DIR}.tar.gz"
echo ""
echo "Archive location: $(pwd)/${EXPORT_DIR}.tar.gz"
echo "Archive size: ${ARCHIVE_SIZE}"
echo ""
