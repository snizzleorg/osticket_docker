# Build and Push to Docker Hub

## Prerequisites
1. Docker Hub account (free): https://hub.docker.com
2. Docker installed locally

## Build Locally (Apple Silicon → AMD64)

```bash
# Navigate to project directory
cd /Users/steffen/CascadeProjects/windsurf-project/osticket_docker

# Create and use a buildx builder (one-time setup)
docker buildx create --name multiplatform --use
docker buildx inspect --bootstrap

# Build for AMD64 and push directly to Docker Hub
# Replace YOUR_DOCKERHUB_USERNAME with your actual username
docker buildx build \
  --platform linux/amd64 \
  -t YOUR_DOCKERHUB_USERNAME/osticket-web:latest \
  -f docker/web/Dockerfile \
  --push \
  .

# Build the migration image (optional)
docker buildx build \
  --platform linux/amd64 \
  -t YOUR_DOCKERHUB_USERNAME/osticket-migration:latest \
  -f docker/migration/Dockerfile \
  --push \
  .
```

**Note**: The `--push` flag automatically pushes after building, so you must be logged in first!

## Login to Docker Hub

```bash
docker login
# Enter your Docker Hub username and password
```

## Push to Docker Hub

**Not needed!** The `docker buildx build --push` command above builds AND pushes in one step.

## Use in Portainer

Create a new stack in Portainer with this docker-compose.yml:

```yaml
services:
  web:
    image: YOUR_DOCKERHUB_USERNAME/osticket-web:latest
    container_name: osticket-web
    ports:
      - "8080:80"
    volumes:
      - ./web:/var/www/html
      - ./config/php.ini:/usr/local/etc/php/conf.d/custom.ini:ro
      - ./config/apache-vhost.conf:/etc/apache2/sites-enabled/000-default.conf:ro
      - uploads:/var/www/html/upload/attachments
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/html
      DB_HOST: db
      DB_NAME: osticket
      DB_USER: osticket
      DB_PASS: osticketpass
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: mariadb:10.11
    container_name: osticket-db
    environment:
      MYSQL_ROOT_PASSWORD: supersecret
      MYSQL_DATABASE: osticket
      MYSQL_USER: osticket
      MYSQL_PASSWORD: osticketpass
      MYSQL_CHARSET: utf8mb4
      MYSQL_COLLATION: utf8mb4_unicode_ci
    volumes:
      - dbdata:/var/lib/mysql
      - ./config/mariadb.cnf:/etc/mysql/conf.d/osticket.cnf:ro
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: osticket-phpmyadmin
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
      PMA_USER: root
      PMA_PASSWORD: supersecret
      PMA_ARBITRARY: 1
      UPLOAD_LIMIT: 50M
    depends_on:
      - db
    restart: unless-stopped

volumes:
  dbdata:
    driver: local
  uploads:
    driver: local
```

## Notes

- **Free tier limits**: 1 private repo, unlimited public repos
- **Image size**: Your osTicket image will be ~500MB-1GB
- **Build context**: The Dockerfile needs the entrypoint script, make sure it exists
- **Updates**: When you update code, rebuild and push with a new tag (e.g., `:v1.0.1`)

## Troubleshooting

If build fails, check:
1. `docker/web/docker-entrypoint.sh` exists
2. You're in the correct directory
3. Docker daemon is running
