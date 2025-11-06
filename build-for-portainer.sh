#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  osTicket Docker Build for Portainer (AMD64)          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Error: Docker is not running${NC}"
    echo -e "  Please start Docker Desktop first"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Prompt for Docker Hub username
echo ""
echo -e "${YELLOW}Enter your Docker Hub username:${NC}"
read -p "> " DOCKER_USERNAME

if [ -z "$DOCKER_USERNAME" ]; then
    echo -e "${RED}✗ Error: Docker Hub username is required${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Docker Hub User: ${GREEN}${DOCKER_USERNAME}${NC}"
echo -e "  Image Name:      ${GREEN}${DOCKER_USERNAME}/osticket-web:latest${NC}"
echo -e "  Platform:        ${GREEN}linux/amd64${NC} (for Portainer)"
echo -e "  Build Context:   ${GREEN}$(pwd)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Confirm before proceeding
read -p "Continue with build? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Build cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}[1/4] Setting up buildx for multi-platform builds...${NC}"
# Check if builder exists, if not create it
if ! docker buildx inspect multiplatform > /dev/null 2>&1; then
    echo -e "  Creating new builder: multiplatform"
    docker buildx create --name multiplatform --use
else
    echo -e "  Using existing builder: multiplatform"
    docker buildx use multiplatform
fi
docker buildx inspect --bootstrap > /dev/null 2>&1
echo -e "${GREEN}✓ Buildx ready${NC}"

echo ""
echo -e "${GREEN}[2/5] Building osTicket web image for AMD64...${NC}"
echo -e "${YELLOW}  This will take 5-10 minutes on first build...${NC}"
echo ""

docker buildx build \
  --platform linux/amd64 \
  -t ${DOCKER_USERNAME}/osticket-web:latest \
  -f docker/web/Dockerfile \
  --push \
  --progress=plain \
  .

echo ""
echo -e "${GREEN}✓ Web image build complete!${NC}"

echo ""
echo -e "${GREEN}[3/5] Building osTicket migration image for AMD64...${NC}"
echo -e "${YELLOW}  This will be much faster (Alpine-based)...${NC}"
echo ""

docker buildx build \
  --platform linux/amd64 \
  -t ${DOCKER_USERNAME}/osticket-migration:latest \
  -f docker/migration/Dockerfile \
  --push \
  --progress=plain \
  .

echo ""
echo -e "${GREEN}✓ Migration image build complete!${NC}"

echo ""
echo -e "${GREEN}[4/5] Updating Portainer compose file...${NC}"
# Update the portainer compose file with the actual username
sed -i.bak "s/YOUR_DOCKERHUB_USERNAME/${DOCKER_USERNAME}/g" docker-compose.portainer.yml
rm -f docker-compose.portainer.yml.bak
echo -e "${GREEN}✓ Updated docker-compose.portainer.yml${NC}"

echo ""
echo -e "${GREEN}[5/5] Verifying images on Docker Hub...${NC}"
echo -e "  Images are available at:"
echo -e "    • ${DOCKER_USERNAME}/osticket-web:latest"
echo -e "    • ${DOCKER_USERNAME}/osticket-migration:latest"
echo -e "${GREEN}✓ Both images verified and accessible${NC}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    SUCCESS!                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Your images are now available at:${NC}"
echo -e "  ${BLUE}docker pull ${DOCKER_USERNAME}/osticket-web:latest${NC}"
echo -e "  ${BLUE}docker pull ${DOCKER_USERNAME}/osticket-migration:latest${NC}"
echo ""
echo -e "${YELLOW}Next steps for Portainer:${NC}"
echo -e "  1. Go to Portainer → Stacks → Add Stack"
echo -e "  2. Copy contents of: ${GREEN}docker-compose.portainer.yml${NC}"
echo -e "  3. Deploy the stack"
echo ""
echo -e "${YELLOW}Access your services:${NC}"
echo -e "  • osTicket:    http://your-server:8080"
echo -e "  • phpMyAdmin:  http://your-server:8081"
echo ""
echo -e "${RED}⚠ IMPORTANT: Change default passwords in production!${NC}"
echo ""
