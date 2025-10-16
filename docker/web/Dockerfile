FROM php:8.3-apache-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libc-client-dev \
    libkrb5-dev \
    libicu-dev \
    libxml2-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libssl-dev \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions required by osTicket
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
    gd \
    imap \
    intl \
    mbstring \
    mysqli \
    opcache \
    xml \
    zip

# Install APCu for better performance
RUN pecl install apcu \
    && docker-php-ext-enable apcu

# Enable Apache modules
RUN a2enmod rewrite headers expires

# Set recommended PHP settings for osTicket
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 50M'; \
    echo 'post_max_size = 50M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'date.timezone = UTC'; \
    echo 'apc.enabled = 1'; \
    echo 'apc.shm_size = 32M'; \
    } > /usr/local/etc/php/conf.d/osticket.ini

# Download and extract osTicket
ARG OSTICKET_VERSION=v1.18.1
RUN wget -q https://github.com/osTicket/osTicket/releases/download/${OSTICKET_VERSION}/osTicket-${OSTICKET_VERSION}.zip -O /tmp/osticket.zip \
    && unzip -q /tmp/osticket.zip -d /tmp/osticket \
    && mkdir -p /usr/src/osticket \
    && cp -r /tmp/osticket/upload/* /usr/src/osticket/ \
    && rm -rf /tmp/osticket /tmp/osticket.zip \
    && cp /usr/src/osticket/include/ost-sampleconfig.php /usr/src/osticket/include/ost-config.php \
    && chmod 666 /usr/src/osticket/include/ost-config.php \
    && mkdir -p /usr/src/osticket/upload/attachments \
    && chown -R www-data:www-data /usr/src/osticket

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port 80
EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
