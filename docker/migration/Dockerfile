FROM alpine:latest

# Install required tools
RUN apk add --no-cache \
    bash \
    mysql-client \
    tar \
    gzip \
    curl \
    sed \
    openssh-client \
    rsync \
    sshpass \
    pv \
    bc

# Copy migration scripts
COPY migrate.sh /usr/local/bin/migrate.sh
COPY pull-from-server.sh /usr/local/bin/pull-from-server.sh
RUN chmod +x /usr/local/bin/migrate.sh /usr/local/bin/pull-from-server.sh

# Create SSH directory
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

WORKDIR /migration

# Keep container running for manual execution or use as one-shot
CMD ["/bin/bash"]
