#!/bin/bash
set -e

# Import Script for Docker Environment
# Run this script on your NEW SERVER to import the exported osTicket data

ARCHIVE="${1}"
COMPOSE_FILE="docker-compose.yml"

echo "================================================"
echo "osTicket Migration Import Script"
echo "================================================"
echo ""

# Check if archive provided
if [ -z "${ARCHIVE}" ]; then
    echo "Usage: $0 <export_archive.tar.gz>"
    echo ""
    echo "Example: $0 osticket_export_20240101_120000.tar.gz"
    exit 1
fi

# Check if archive exists
if [ ! -f "${ARCHIVE}" ]; then
    echo "Error: Archive file '${ARCHIVE}' not found"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "${COMPOSE_FILE}" ]; then
    echo "Error: docker-compose.yml not found. Are you in the osticket_docker directory?"
    exit 1
fi

echo "Archive: ${ARCHIVE}"
echo ""

# Extract archive
echo "[1/6] Extracting archive..."
tar -xzf "${ARCHIVE}"
EXPORT_DIR=$(tar -tzf "${ARCHIVE}" | head -1 | cut -f1 -d"/")

if [ ! -d "${EXPORT_DIR}" ]; then
    echo "Error: Failed to extract archive"
    exit 1
fi
echo "  ✓ Extracted to ${EXPORT_DIR}"

# Load database credentials
if [ ! -f "${EXPORT_DIR}/db_credentials.txt" ]; then
    echo "Error: db_credentials.txt not found in archive"
    exit 1
fi

source "${EXPORT_DIR}/db_credentials.txt"
echo ""
echo "[2/6] Reading configuration..."
cat "${EXPORT_DIR}/migration_info.txt"
echo ""

# Confirm before proceeding
read -p "Continue with import? This will replace existing data. (yes/NO): " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Import cancelled."
    exit 1
fi

echo ""
echo "[3/6] Copying web files..."

# Backup existing web directory if it exists and is not empty
if [ -d "web" ] && [ "$(ls -A web)" ]; then
    echo "  Backing up existing web directory..."
    mv web "web.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copy web files
cp -r "${EXPORT_DIR}/web" .
chmod -R 755 web/
chmod -R 777 web/upload/attachments 2>/dev/null || true
echo "  ✓ Web files copied"

echo "[4/6] Updating database configuration in ost-config.php..."

# Update database config to use Docker database
if [ -f "web/include/ost-config.php" ]; then
    # Backup original config
    cp web/include/ost-config.php web/include/ost-config.php.old
    
    # Update database host to 'db' (Docker service name)
    sed -i.bak "s/define('DBHOST',.*/define('DBHOST','db');/" web/include/ost-config.php
    
    # Optionally update credentials if you want to use the defaults from docker-compose
    echo ""
    echo "  Current database credentials from old server:"
    echo "    Host: ${DB_HOST}"
    echo "    Name: ${DB_NAME}"
    echo "    User: ${DB_USER}"
    echo ""
    echo "  Docker default credentials:"
    echo "    Host: db"
    echo "    Name: osticket"
    echo "    User: osticket"
    echo "    Password: osticketpass"
    echo ""
    read -p "  Use Docker default credentials? (Y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sed -i.bak "s/define('DBNAME',.*/define('DBNAME','osticket');/" web/include/ost-config.php
        sed -i.bak "s/define('DBUSER',.*/define('DBUSER','osticket');/" web/include/ost-config.php
        sed -i.bak "s/define('DBPASS',.*/define('DBPASS','osticketpass');/" web/include/ost-config.php
        echo "  ✓ Updated to use Docker credentials"
        USE_DOCKER_CREDS=true
    else
        sed -i.bak "s/define('DBHOST',.*/define('DBHOST','db');/" web/include/ost-config.php
        echo "  ✓ Kept original credentials (only updated host to 'db')"
        USE_DOCKER_CREDS=false
        
        # Update docker-compose.yml with old credentials
        echo "  Updating docker-compose.yml with your credentials..."
        sed -i.bak "s/MYSQL_DATABASE:.*/MYSQL_DATABASE: ${DB_NAME}/" docker-compose.yml
        sed -i.bak "s/MYSQL_USER:.*/MYSQL_USER: ${DB_USER}/" docker-compose.yml
        sed -i.bak "s/MYSQL_PASSWORD:.*/MYSQL_PASSWORD: ${DB_PASS}/" docker-compose.yml
    fi
    
    chmod 644 web/include/ost-config.php
else
    echo "  Warning: ost-config.php not found"
fi

echo "[5/6] Starting Docker containers..."

# Stop containers if running
docker-compose down 2>/dev/null || true

# Start database first
docker-compose up -d db
echo "  Waiting for database to be ready..."
sleep 15

# Check database health
until docker-compose exec -T db mysqladmin ping -h localhost --silent 2>/dev/null; do
    echo "  Waiting for database..."
    sleep 5
done
echo "  ✓ Database is ready"

echo "[6/6] Importing database..."

# Import database
if [ -f "${EXPORT_DIR}/database.sql.gz" ]; then
    if [ "$USE_DOCKER_CREDS" = true ]; then
        gunzip < "${EXPORT_DIR}/database.sql.gz" | docker-compose exec -T db mysql -u osticket -posticketpass osticket
    else
        gunzip < "${EXPORT_DIR}/database.sql.gz" | docker-compose exec -T db mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
    fi
    echo "  ✓ Database imported"
else
    echo "  Error: database.sql.gz not found"
    exit 1
fi

# Start all services
echo ""
echo "Starting all services..."
docker-compose up -d

echo ""
echo "================================================"
echo "✓ Migration completed successfully!"
echo "================================================"
echo ""
echo "Your osTicket installation is now running in Docker!"
echo ""
echo "Access points:"
echo "  - Frontend: http://localhost:8080/"
echo "  - Admin Panel: http://localhost:8080/scp/"
echo "  - phpMyAdmin: http://localhost:8081/"
echo ""
echo "Important notes:"
echo "  1. Original config backed up to: web/include/ost-config.php.old"
echo "  2. Export data preserved in: ${EXPORT_DIR}/"
echo "  3. Check logs: docker-compose logs -f"
echo ""
echo "Recommended next steps:"
echo "  1. Test your installation thoroughly"
echo "  2. Update email settings in Admin Panel"
echo "  3. Verify all plugins are working"
echo "  4. Run backup: ./scripts/backup.sh"
echo "  5. Clean up: rm -rf ${EXPORT_DIR}/ ${ARCHIVE}"
echo ""
