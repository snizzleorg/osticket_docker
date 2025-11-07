#!/bin/bash
set -e

echo "================================================"
echo "osTicket Remote Server Pull Script"
echo "================================================"
echo ""

# Load configuration from .env.migration if it exists
if [ -f "/migration/.env.migration" ]; then
    echo "Loading configuration from .env.migration..."
    source /migration/.env.migration
    echo "✓ Configuration loaded"
    echo ""
else
    echo "No .env.migration file found - using interactive mode"
    echo ""
    echo "This script will SSH into your old server and"
    echo "pull osTicket files and database directly."
    echo ""
fi

# Get connection details (use env vars or prompt)
if [ -z "$OLD_SERVER" ]; then
    read -p "Old server hostname/IP: " OLD_SERVER
fi

if [ -z "$SSH_USER" ]; then
    read -p "SSH username: " SSH_USER
fi

if [ -z "$SSH_PORT" ]; then
    read -p "SSH port [22]: " SSH_PORT
fi
SSH_PORT=${SSH_PORT:-22}

if [ -z "$OSTICKET_PATH" ]; then
    read -p "osTicket installation path [/var/www/html/osticket]: " OSTICKET_PATH
fi
OSTICKET_PATH=${OSTICKET_PATH:-/var/www/html/osticket}

if [ -z "$AUTH_METHOD" ]; then
    echo ""
    echo "Authentication method:"
    echo "  1) Password"
    echo "  2) SSH key (paste key content)"
    echo "  3) SSH key file (already mounted in container)"
    read -p "Choose [1-3]: " AUTH_METHOD
fi

case $AUTH_METHOD in
    1)
        if [ -z "$SSH_PASS" ]; then
            read -sp "SSH password: " SSH_PASS
            echo ""
        fi
        SSH_CMD="sshpass -p '$SSH_PASS' ssh -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        SCP_CMD="sshpass -p '$SSH_PASS' scp -P $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        RSYNC_SSH="ssh -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        ;;
    2)
        TEMP_KEY="/tmp/migration_key_$$"
        if [ -z "$SSH_KEY" ] && [ -z "$SSH_KEY_B64" ]; then
            echo "Paste your private key (end with Ctrl+D on a new line):"
            cat > "$TEMP_KEY"
        elif [ -n "$SSH_KEY_B64" ]; then
            echo "Using base64-encoded SSH key from configuration..."
            echo "$SSH_KEY_B64" | base64 -d > "$TEMP_KEY"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to decode base64 SSH key"
                exit 1
            fi
        else
            echo "Using SSH key from configuration..."
            echo "$SSH_KEY" > "$TEMP_KEY"
        fi
        chmod 600 "$TEMP_KEY"
        SSH_CMD="ssh -p $SSH_PORT -i $TEMP_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        SCP_CMD="scp -P $SSH_PORT -i $TEMP_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        RSYNC_SSH="ssh -p $SSH_PORT -i $TEMP_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        ;;
    3)
        if [ -z "$SSH_KEY_FILE" ]; then
            read -p "Path to key file in container: " SSH_KEY_FILE
        fi
        if [ ! -f "$SSH_KEY_FILE" ]; then
            echo "Error: Key file not found: $SSH_KEY_FILE"
            exit 1
        fi
        SSH_CMD="ssh -p $SSH_PORT -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        SCP_CMD="scp -P $SSH_PORT -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        RSYNC_SSH="ssh -p $SSH_PORT -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/known_hosts"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Connection details:"
echo "  Server: $OLD_SERVER:$SSH_PORT"
echo "  User: $SSH_USER"
echo "  Path: $OSTICKET_PATH"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Test connection
echo ""
echo "[1/6] Testing SSH connection..."
if ! $SSH_CMD ${SSH_USER}@${OLD_SERVER} "echo 'Connection successful'" 2>/dev/null; then
    echo "  ✗ Error: Could not connect to server"
    exit 1
fi
echo "  ✓ SSH connection successful"

# Check if osTicket path exists
echo ""
echo "[2/6] Checking osTicket installation..."
if ! $SSH_CMD ${SSH_USER}@${OLD_SERVER} "test -d $OSTICKET_PATH" 2>/dev/null; then
    echo "  ✗ Error: osTicket path not found on server"
    exit 1
fi
echo "  ✓ osTicket installation found"

# Get database credentials from ost-config.php
echo ""
echo "[3/6] Reading database credentials..."
CONFIG_CONTENT=$($SSH_CMD ${SSH_USER}@${OLD_SERVER} "cat $OSTICKET_PATH/include/ost-config.php" 2>/dev/null)

DB_HOST=$(echo "$CONFIG_CONTENT" | grep "define('DBHOST'" | sed "s/.*define('DBHOST','\(.*\)').*/\1/")
DB_NAME=$(echo "$CONFIG_CONTENT" | grep "define('DBNAME'" | sed "s/.*define('DBNAME','\(.*\)').*/\1/")
DB_USER=$(echo "$CONFIG_CONTENT" | grep "define('DBUSER'" | sed "s/.*define('DBUSER','\(.*\)').*/\1/")
DB_PASS=$(echo "$CONFIG_CONTENT" | grep "define('DBPASS'" | sed "s/.*define('DBPASS','\(.*\)').*/\1/")

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
    echo "  ✗ Error: Could not read database credentials"
    exit 1
fi

echo "  ✓ Database: $DB_NAME on $DB_HOST"

# Export database
echo ""
echo "[4/6] Exporting database from old server..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="/migration/data/osticket_export_${TIMESTAMP}"
mkdir -p "${EXPORT_DIR}"

echo "  Exporting database (this may take a while)..."
$SSH_CMD ${SSH_USER}@${OLD_SERVER} "mysqldump -h'$DB_HOST' -u'$DB_USER' -p'$DB_PASS' '$DB_NAME' | gzip > /tmp/osticket_db_${TIMESTAMP}.sql.gz" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "  ✗ Error: Database export failed"
    echo "  Tip: Make sure mysqldump is installed on the old server"
    exit 1
fi
echo "  ✓ Database exported on remote server"

# Download database dump
echo ""
echo "[5/6] Downloading files from old server..."
mkdir -p "${EXPORT_DIR}/files"
$SCP_CMD ${SSH_USER}@${OLD_SERVER}:/tmp/osticket_db_${TIMESTAMP}.sql.gz ${EXPORT_DIR}/database.sql.gz
echo "  ✓ Database downloaded"

# Download osTicket files using rsync (faster and preserves permissions)
# EXCLUDE attachments - we'll download them separately with tar due to permission issues
echo "  Downloading osTicket files (excluding attachments)..."
echo "  (This may take several minutes depending on size)"
echo ""
if command -v rsync &> /dev/null; then
    if [ "$AUTH_METHOD" = "1" ]; then
        # Password authentication requires sshpass wrapper
        sshpass -p "$SSH_PASS" rsync -rlptz --info=progress2 --no-inc-recursive \
            --exclude='attachments/' --exclude='upload/attachments/' \
            -e "$RSYNC_SSH" \
            ${SSH_USER}@${OLD_SERVER}:${OSTICKET_PATH}/ ${EXPORT_DIR}/files/ 2>&1 | \
            grep -v "^[^0-9]" | grep -E "^[0-9]|to-chk" || true
        RSYNC_EXIT=${PIPESTATUS[0]}
    else
        # Key-based authentication
        rsync -rlptz --info=progress2 --no-inc-recursive \
            --exclude='attachments/' --exclude='upload/attachments/' \
            -e "$RSYNC_SSH" \
            ${SSH_USER}@${OLD_SERVER}:${OSTICKET_PATH}/ ${EXPORT_DIR}/files/ 2>&1 | \
            grep -v "^[^0-9]" | grep -E "^[0-9]|to-chk" || true
        RSYNC_EXIT=${PIPESTATUS[0]}
    fi
    echo ""
    if [ $RSYNC_EXIT -eq 0 ]; then
        echo "  ✓ Files downloaded successfully"
    elif [ $RSYNC_EXIT -eq 23 ]; then
        echo "  ⚠ Files downloaded with warnings (some files skipped)"
        echo "  This is usually due to permission issues or symlinks"
    else
        echo "  ✗ Error: rsync failed with code $RSYNC_EXIT"
        exit 1
    fi
else
    # Fallback to tar over SSH
    echo "  Using tar over SSH..."
    $SSH_CMD ${SSH_USER}@${OLD_SERVER} "cd $OSTICKET_PATH && tar czf - ." | tar xzf - -C ${EXPORT_DIR}/files/
    echo "  ✓ Files downloaded"
fi

# Fix permissions on downloaded files so we can read them
echo ""
echo "Fixing file permissions..."
chmod -R u+rwX ${EXPORT_DIR}/files/ 2>/dev/null || true
echo "  ✓ Permissions fixed"

# Download attachments separately using tar (excluded from initial rsync)
echo ""
echo "Downloading attachments via compressed tar..."
ATTACH_COUNT=$($SSH_CMD ${SSH_USER}@${OLD_SERVER} "find ${OSTICKET_PATH}/attachments -type f 2>/dev/null | wc -l" | tr -d ' ')

if [ "$ATTACH_COUNT" -gt 0 ]; then
    echo "  Remote attachments: $ATTACH_COUNT files"
    echo ""
    
    # Create attachments directory (it shouldn't exist since we excluded it from rsync)
    mkdir -p ${EXPORT_DIR}/files/attachments
    
    # Use tar on server side - it has proper permissions there
    # Get approximate size for progress estimation
    ATTACH_SIZE=$($SSH_CMD ${SSH_USER}@${OLD_SERVER} "du -sb ${OSTICKET_PATH}/attachments 2>/dev/null | cut -f1" || echo "0")
    ATTACH_SIZE_GB=$(echo "scale=2; $ATTACH_SIZE / 1073741824" | bc 2>/dev/null || echo "unknown")
    
    # Estimate compressed size (typically 30-50% for mixed files)
    COMPRESS_SIZE=$(echo "$ATTACH_SIZE * 0.4" | bc 2>/dev/null || echo "$ATTACH_SIZE")
    
    echo "  Size: ~${ATTACH_SIZE_GB}GB (will be compressed for transfer)"
    echo "  This will take several minutes depending on connection speed..."
    echo ""
    
    # Use gzip compression to reduce network transfer (important for slow connections)
    # Show progress with compressed size updates
    $SSH_CMD ${SSH_USER}@${OLD_SERVER} "cd ${OSTICKET_PATH} && tar czf - attachments/ 2>/dev/null" | \
        pv -f -s ${COMPRESS_SIZE} -w 80 -N "Compressed" 2>/dev/null | \
        tar xzf - -C ${EXPORT_DIR}/files/ || \
        $SSH_CMD ${SSH_USER}@${OLD_SERVER} "cd ${OSTICKET_PATH} && tar czf - attachments/ 2>/dev/null" | \
        tar xzf - -C ${EXPORT_DIR}/files/
    
    echo ""
    echo "  ✓ Download complete"
    
    # Fix all permissions after tar extraction
    chmod -R u+rwX ${EXPORT_DIR}/files/attachments/ 2>/dev/null || true
    
    LOCAL_ATTACH_COUNT=$(find ${EXPORT_DIR}/files/attachments -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$LOCAL_ATTACH_COUNT" -eq "$ATTACH_COUNT" ]; then
        echo "  ✓ Successfully downloaded all $LOCAL_ATTACH_COUNT attachments"
    elif [ "$LOCAL_ATTACH_COUNT" -gt 0 ]; then
        echo "  ⚠ Downloaded $LOCAL_ATTACH_COUNT of $ATTACH_COUNT attachments"
        echo "  Some files may have permission issues on source server"
    else
        echo "  ✗ Could not download attachments"
        echo "  Check permissions and ownership on source server"
    fi
else
    echo "  No attachments found on server"
fi

# Cleanup on remote server
echo ""
echo "[6/6] Cleaning up remote server..."
$SSH_CMD ${SSH_USER}@${OLD_SERVER} "rm -f /tmp/osticket_db_${TIMESTAMP}.sql.gz" 2>/dev/null
echo "  ✓ Cleanup complete"

# Create archive
echo ""
echo "Creating local archive..."
cd /migration/data
tar -czf osticket_export_${TIMESTAMP}.tar.gz osticket_export_${TIMESTAMP}/
echo "  ✓ Archive created"

# Cleanup extracted directory to save space
rm -rf osticket_export_${TIMESTAMP}/
echo "  ✓ Temporary files removed"

# Cleanup temporary SSH key if used
if [ -n "$TEMP_KEY" ] && [ -f "$TEMP_KEY" ]; then
    rm -f "$TEMP_KEY"
fi

echo ""
echo "================================================"
echo "✓ Pull completed successfully!"
echo "================================================"
echo ""
echo "Archive: /migration/data/osticket_export_${TIMESTAMP}.tar.gz"
echo "Size: $(du -h /migration/data/osticket_export_${TIMESTAMP}.tar.gz | cut -f1)"
echo ""
echo "Next step: Run the migration"
echo "  migrate.sh /migration/data/osticket_export_${TIMESTAMP}.tar.gz"
echo ""
