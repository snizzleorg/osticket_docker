#!/bin/bash
set -e

# osTicket Download and Setup Script
# This script downloads and extracts osTicket to the web directory

VERSION="${1:-v1.18.1}"
DOWNLOAD_URL="https://github.com/osTicket/osTicket/releases/download/${VERSION}/osTicket-${VERSION}.zip"
TEMP_DIR="./temp_osticket"

echo "================================================"
echo "osTicket Download and Setup Script"
echo "================================================"
echo ""
echo "Version: ${VERSION}"
echo "Download URL: ${DOWNLOAD_URL}"
echo ""

# Check if web directory exists and is not empty
if [ -d "web" ] && [ "$(ls -A web)" ]; then
    read -p "Warning: web/ directory is not empty. Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create temporary directory
echo "[1/6] Creating temporary directory..."
mkdir -p "${TEMP_DIR}"

# Download osTicket
echo "[2/6] Downloading osTicket ${VERSION}..."
if command -v wget &> /dev/null; then
    wget -q --show-progress "${DOWNLOAD_URL}" -O "${TEMP_DIR}/osticket.zip"
elif command -v curl &> /dev/null; then
    curl -L --progress-bar "${DOWNLOAD_URL}" -o "${TEMP_DIR}/osticket.zip"
else
    echo "Error: Neither wget nor curl is installed."
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Extract archive
echo "[3/6] Extracting archive..."
unzip -q "${TEMP_DIR}/osticket.zip" -d "${TEMP_DIR}"

# Move files to web directory
echo "[4/6] Moving files to web/ directory..."
mkdir -p web
if [ -d "${TEMP_DIR}/upload" ]; then
    cp -r "${TEMP_DIR}/upload/"* web/
else
    cp -r "${TEMP_DIR}/"* web/
fi

# Set up configuration
echo "[5/6] Setting up configuration..."
if [ -f "web/include/ost-sampleconfig.php" ]; then
    cp web/include/ost-sampleconfig.php web/include/ost-config.php
    chmod 666 web/include/ost-config.php
    echo "  ✓ Created ost-config.php"
fi

# Create necessary directories
mkdir -p web/upload/attachments
chmod -R 755 web/
chmod -R 777 web/upload/attachments
echo "  ✓ Created upload directories with proper permissions"

# Cleanup
echo "[6/6] Cleaning up..."
rm -rf "${TEMP_DIR}"

echo ""
echo "================================================"
echo "✓ osTicket ${VERSION} successfully installed!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Start Docker: docker-compose up -d"
echo "  2. Open browser: http://localhost:8080/setup/"
echo "  3. Follow installation wizard"
echo "  4. After setup, remove setup directory:"
echo "     rm -rf web/setup/"
echo ""
