#!/bin/bash
set -e

# If /var/www/html is empty or only contains default files, copy osTicket
if [ ! -f "/var/www/html/main.inc.php" ]; then
    echo "Initializing osTicket files in volume..."
    cp -rn /usr/src/osticket/* /var/www/html/
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 777 /var/www/html/upload/attachments
    echo "osTicket files initialized successfully!"
else
    echo "osTicket files already exist in volume, skipping initialization."
fi

# Execute the main command
exec "$@"
