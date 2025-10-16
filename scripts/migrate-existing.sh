#!/bin/bash
set -e

# Migration Helper Script
# This script guides you through migrating an existing osTicket installation

echo "================================================"
echo "osTicket Migration Helper"
echo "================================================"
echo ""
echo "This wizard will help you migrate your existing"
echo "osTicket installation to Docker."
echo ""

# Ask about access to old server
echo "Do you have SSH access to your old osTicket server?"
read -p "(yes/no): " HAS_SSH

if [[ $HAS_SSH =~ ^[Yy] ]]; then
    echo ""
    echo "Perfect! Here's how to proceed:"
    echo ""
    echo "================================================"
    echo "STEP 1: Export from Old Server"
    echo "================================================"
    echo ""
    echo "1. Copy the export script to your old server:"
    echo "   scp scripts/export-from-old-server.sh user@oldserver:/tmp/"
    echo ""
    read -p "Enter SSH connection (user@hostname): " SSH_HOST
    
    if [ ! -z "$SSH_HOST" ]; then
        echo ""
        echo "Copying export script..."
        scp scripts/export-from-old-server.sh "${SSH_HOST}:/tmp/"
        
        echo ""
        echo "2. Now SSH into your old server and run:"
        echo "   ssh ${SSH_HOST}"
        echo "   cd /tmp"
        echo "   chmod +x export-from-old-server.sh"
        
        read -p "Enter the path to osTicket on old server (e.g., /var/www/html/osticket): " OSTICKET_PATH
        
        echo "   ./export-from-old-server.sh ${OSTICKET_PATH}"
        echo ""
        echo "================================================"
        echo "STEP 2: Download the Export"
        echo "================================================"
        echo ""
        echo "After the export completes on the old server, download it:"
        echo "   scp ${SSH_HOST}:/tmp/osticket_export_*.tar.gz ."
        echo ""
        echo "================================================"
        echo "STEP 3: Import to Docker"
        echo "================================================"
        echo ""
        echo "Once downloaded, run the import script:"
        echo "   ./scripts/import-to-docker.sh osticket_export_*.tar.gz"
        echo ""
        
        read -p "Do you want to execute these steps now? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Opening SSH connection to old server..."
            echo "Run the following commands on the old server:"
            echo ""
            echo "  cd /tmp"
            echo "  chmod +x export-from-old-server.sh"
            echo "  ./export-from-old-server.sh ${OSTICKET_PATH}"
            echo ""
            
            ssh -t "${SSH_HOST}" "cd /tmp && bash"
            
            echo ""
            echo "Now downloading the export archive..."
            scp "${SSH_HOST}:/tmp/osticket_export_*.tar.gz" .
            
            ARCHIVE=$(ls -t osticket_export_*.tar.gz 2>/dev/null | head -1)
            
            if [ -f "${ARCHIVE}" ]; then
                echo ""
                echo "Archive downloaded: ${ARCHIVE}"
                read -p "Import now? (y/N): " -n 1 -r
                echo ""
                
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    ./scripts/import-to-docker.sh "${ARCHIVE}"
                fi
            fi
        fi
    fi
else
    echo ""
    echo "================================================"
    echo "Manual Migration Process"
    echo "================================================"
    echo ""
    echo "Since you don't have SSH access, you'll need to:"
    echo ""
    echo "1. Get database dump from old server:"
    echo "   mysqldump -u DB_USER -p DB_NAME | gzip > osticket_db.sql.gz"
    echo ""
    echo "2. Get all osTicket files (via FTP, cPanel, etc.)"
    echo "   - Copy entire osTicket directory"
    echo ""
    echo "3. Place files in this directory:"
    echo "   - Database dump: ./osticket_db.sql.gz"
    echo "   - Web files: ./web/"
    echo ""
    echo "4. Update ost-config.php:"
    echo "   Edit: web/include/ost-config.php"
    echo "   Change: define('DBHOST','db');"
    echo "   (keep other DB settings for now)"
    echo ""
    echo "5. Start Docker and import database:"
    echo "   docker-compose up -d db"
    echo "   sleep 15"
    echo "   gunzip < osticket_db.sql.gz | docker-compose exec -T db mysql -u osticket -posticketpass osticket"
    echo "   docker-compose up -d"
    echo ""
    echo "6. Access: http://localhost:8080/"
    echo ""
fi

echo ""
echo "================================================"
echo "Additional Resources"
echo "================================================"
echo ""
echo "See MIGRATION.md for detailed documentation"
echo ""
