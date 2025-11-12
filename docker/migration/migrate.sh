#!/bin/bash
set -e

# Usage: migrate.sh <archive_path> [--db-only]
#   --db-only: Skip file copying (useful for large attachment directories)

echo "================================================"
echo "osTicket Migration Container"
echo "================================================"
echo ""

ARCHIVE_PATH="${1:-}"
SKIP_FILES="${2:-}"
WEB_PATH="/web"
DB_HOST="${DB_HOST:-db}"
DB_NAME="${DB_NAME:-osticket}"
DB_USER="${DB_USER:-osticket}"
DB_PASS="${DB_PASS:-osticketpass}"

# Find archive or use latest export directory
if [ -z "$ARCHIVE_PATH" ]; then
    # Look for .tar.gz archives first
    LATEST_ARCHIVE=$(ls -t /migration/data/osticket_export_*.tar.gz 2>/dev/null | head -1)
    
    if [ -n "$LATEST_ARCHIVE" ]; then
        ARCHIVE_PATH="$LATEST_ARCHIVE"
        echo "Found archive: $(basename $ARCHIVE_PATH)"
    else
        # Look for export directories
        LATEST_DIR=$(ls -td /migration/data/osticket_export_* 2>/dev/null | head -1)
        
        if [ -n "$LATEST_DIR" ] && [ -d "$LATEST_DIR" ]; then
            echo "Found export directory: $(basename $LATEST_DIR)"
            echo "No archive found - using directory directly"
            EXPORT_DIR="$LATEST_DIR"
            USE_DIR=true
        else
            echo "Error: No osticket export found"
            echo ""
            echo "Run pull-from-server.sh first to download from old server"
            exit 1
        fi
    fi
fi

# Check if specified archive exists
if [ "$USE_DIR" != "true" ] && [ ! -f "${ARCHIVE_PATH}" ]; then
    echo "Error: Archive not found at ${ARCHIVE_PATH}"
    exit 1
fi

if [ "$USE_DIR" = "true" ]; then
    echo "Source: $(basename $EXPORT_DIR) (directory)"
else
    echo "Source: $(basename $ARCHIVE_PATH) (archive)"
fi

if [ "$SKIP_FILES" = "--db-only" ]; then
    echo "Mode: Database only (skipping 25GB+ attachments)"
else
    echo "Mode: Full migration (database + files)"
fi

echo "Target: ${WEB_PATH}"
echo "Database: ${DB_HOST}/${DB_NAME}"
echo ""

# Confirm
read -p "Continue with migration? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Extract archive or use directory
echo ""
if [ "$USE_DIR" = "true" ]; then
    echo "[1/6] Using export directory directly..."
    echo "  ✓ Using: $(basename $EXPORT_DIR)"
elif [ "$SKIP_FILES" = "--db-only" ]; then
    echo "[1/6] Extracting database only..."
    TEMP_DIR="/tmp/migration_extract"
    rm -rf "${TEMP_DIR}"
    mkdir -p "${TEMP_DIR}"
    
    # Extract only database files from archive
    echo "  Extracting database files..."
    tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_DIR}" --wildcards "*/database.sql*" "*/migration_info.txt" 2>/dev/null || \
    tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_DIR}"
    
    # Find the extracted directory
    EXPORT_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d ! -path "${TEMP_DIR}" | head -1)
    if [ -z "${EXPORT_DIR}" ]; then
        echo "Error: Could not find extracted directory"
        exit 1
    fi
    echo "  ✓ Database extracted to temporary location"
else
    echo "[1/6] Extracting archive..."
    TEMP_DIR="/tmp/migration_extract"
    rm -rf "${TEMP_DIR}"
    mkdir -p "${TEMP_DIR}"
    tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_DIR}"
    
    # Find the extracted directory
    EXPORT_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d ! -path "${TEMP_DIR}" | head -1)
    if [ -z "${EXPORT_DIR}" ]; then
        echo "Error: Could not find extracted directory"
        exit 1
    fi
    echo "  ✓ Extracted to temporary location"
fi

# Copy files to web directory
echo ""
if [ "$SKIP_FILES" = "--db-only" ]; then
    echo "[2/6] Skipping file copy (database-only mode)..."
    echo "  ✓ Files copy skipped as requested"
else
    echo "[2/6] Copying osTicket files..."
    if [ -d "${EXPORT_DIR}/files" ]; then
        cp -r "${EXPORT_DIR}/files/"* "${WEB_PATH}/"
        echo "  ✓ Files copied to ${WEB_PATH}"
    else
        echo "  ⚠ Warning: No files directory found in archive"
    fi
fi

# Update configuration for Docker
echo ""
echo "[3/6] Updating configuration..."
if [ -f "${WEB_PATH}/include/ost-config.php" ]; then
    sed -i "s/define('DBHOST',.*/define('DBHOST','${DB_HOST}');/" "${WEB_PATH}/include/ost-config.php"
    sed -i "s/define('DBNAME',.*/define('DBNAME','${DB_NAME}');/" "${WEB_PATH}/include/ost-config.php"
    sed -i "s/define('DBUSER',.*/define('DBUSER','${DB_USER}');/" "${WEB_PATH}/include/ost-config.php"
    sed -i "s/define('DBPASS',.*/define('DBPASS','${DB_PASS}');/" "${WEB_PATH}/include/ost-config.php"
    echo "  ✓ Configuration updated for Docker environment"
else
    echo "  ⚠ Warning: ost-config.php not found"
fi

# Wait for database
echo ""
echo "[4/6] Waiting for database..."
for i in {1..30}; do
    if mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl -e "SELECT 1" >/dev/null 2>&1; then
        echo "  ✓ Database is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ✗ Error: Database not available after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Import database
echo ""
echo "[5/6] Importing database..."
if [ -f "${EXPORT_DIR}/database.sql" ]; then
    echo "  Debug: Found database.sql, checking size..."
    DB_SIZE=$(wc -l < "${EXPORT_DIR}/database.sql")
    echo "  Debug: Database file has $DB_SIZE lines"
    
    echo "  Debug: Checking if database has content before import..."
    PRE_IMPORT_COUNT=$(mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "SELECT COUNT(*) FROM ost_config;" 2>/dev/null | grep -v "COUNT" || echo "0")
    echo "  Debug: ost_config has $PRE_IMPORT_COUNT rows before import"
    
    # Strip DEFINER clauses to avoid SUPER privilege requirements
    sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' "${EXPORT_DIR}/database.sql" | \
        mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}"
    echo "  ✓ Database imported successfully"
    
    echo "  Debug: Checking ost_config after import..."
    POST_IMPORT_COUNT=$(mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "SELECT COUNT(*) FROM ost_config;" 2>/dev/null | grep -v "COUNT" || echo "0")
    echo "  Debug: ost_config has $POST_IMPORT_COUNT rows after import"
    
elif [ -f "${EXPORT_DIR}/database.sql.gz" ]; then
    echo "  Debug: Found database.sql.gz, decompressing..."
    # Strip DEFINER clauses to avoid SUPER privilege requirements
    gunzip -c "${EXPORT_DIR}/database.sql.gz" | \
        sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | \
        mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}"
    echo "  ✓ Database imported successfully"
else
    echo "  ⚠ Warning: No database dump found in archive"
fi

# Update attachment path in database
echo ""
echo "[6/6] Updating attachment paths..."

# Debug: Check what tables exist
echo "  Debug: Checking database tables..."
TABLES=$(mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "SHOW TABLES LIKE 'ost_config';" 2>/dev/null | grep -v "Tables_in_")
echo "  Debug: ost_config table exists: $TABLES"

# Debug: Check current config entries
if [ -n "$TABLES" ]; then
    echo "  Debug: All config entries:"
    mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "SELECT namespace, key, value FROM ost_config WHERE key LIKE '%upload%' OR key LIKE '%attach%' OR value LIKE '%attach%' OR namespace LIKE '%attach%';" 2>/dev/null || echo "    No attachment-related entries found"
    
    echo ""
    echo "  Debug: Core namespace entries:"
    mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "SELECT namespace, key, value FROM ost_config WHERE namespace='core' LIMIT 10;" 2>/dev/null || echo "    No core entries found"
fi

# Update the paths
echo "  Debug: Executing update query..."
mariadb -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --skip-ssl "${DB_NAME}" -e "UPDATE ost_config SET value='/var/www/html/attachments' WHERE namespace='plugin.7.instance.1' OR (namespace='core' AND key='upload_dir');" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  ✓ Attachment paths updated to /var/www/html/attachments"
else
    echo "  ⚠ Could not update attachment paths (table may not exist)"
fi

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo "================================================"
if [ "$SKIP_FILES" = "--db-only" ]; then
    echo "✓ Database migration completed successfully!"
else
    echo "✓ Migration completed successfully!"
fi
echo "================================================"
echo ""

if [ "$SKIP_FILES" = "--db-only" ]; then
    echo "Note: Files were not copied (database-only mode)"
    echo "      You'll need to copy attachments separately if needed"
    echo ""
fi

echo "Next steps:"
echo "  1. Verify the migration: http://localhost:8080/"
echo "  2. Test admin login: http://localhost:8080/scp/"
echo "  3. Check existing tickets and data"
echo ""
echo "If everything looks good, you can remove the migration data:"
echo "  rm -rf migration/data/*"
echo ""
