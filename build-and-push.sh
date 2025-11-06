#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Docker Hub Multi-Platform Build Script ===${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker Desktop first.${NC}"
    exit 1
fi

# Prompt for Docker Hub username
read -p "Enter your Docker Hub username: " DOCKER_USERNAME

if [ -z "$DOCKER_USERNAME" ]; then
    echo -e "${RED}Error: Docker Hub username is required${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Logging into Docker Hub...${NC}"
docker login

echo ""
echo -e "${GREEN}Step 2: Setting up buildx for multi-platform builds...${NC}"
# Check if builder exists, if not create it
if ! docker buildx inspect multiplatform > /dev/null 2>&1; then
    docker buildx create --name multiplatform --use
else
    docker buildx use multiplatform
fi
docker buildx inspect --bootstrap

echo ""
echo -e "${GREEN}Step 3: Building osTicket web image for AMD64...${NC}"
echo -e "${YELLOW}This may take 5-10 minutes on first build...${NC}"
docker buildx build \
  --platform linux/amd64 \
  -t ${DOCKER_USERNAME}/osticket-web:latest \
  -f docker/web/Dockerfile \
  --push \
  .

echo ""
echo -e "${GREEN}✓ Build complete!${NC}"
echo ""
echo -e "${YELLOW}Your image is now available at:${NC}"
echo -e "  docker pull ${DOCKER_USERNAME}/osticket-web:latest"
echo ""
echo -e "${YELLOW}To use in Portainer, update your docker-compose.yml:${NC}"
echo -e "  Change: ${RED}build: ./docker/web${NC}"
echo -e "  To:     ${GREEN}image: ${DOCKER_USERNAME}/osticket-web:latest${NC}"
echo ""
echo -e "${GREEN}Done!${NC}"
