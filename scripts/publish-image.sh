#!/bin/bash
# Publish dev container image to GitHub Container Registry (public by default)
# Usage: ./publish-image.sh [tag]
# Example: ./publish-image.sh latest
#          ./publish-image.sh 9.2.0
# 
# Login once with: echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
# Or for public repos, no auth needed to pull!

set -e

GITHUB_USERNAME="${GITHUB_USERNAME:-iakshayubale}"
IMAGE_NAME="bazel-infra-lab"
TAG="${1:-latest}"
REGISTRY="${REGISTRY:-ghcr.io}"
FULL_IMAGE="$REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:$TAG"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🐳 Container Registry Publishing Script${NC}"
echo ""
echo "Registry: $REGISTRY"
echo "Image: $FULL_IMAGE"
echo ""

# For GitHub Container Registry, check if we have credentials
if [ "$REGISTRY" = "ghcr.io" ]; then
  if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}ℹ️  Public repositories don't need auth to pull${NC}"
    echo "To push (requires GitHub account):"
    echo "  export GITHUB_TOKEN=<your-github-token>"
    echo "  ./scripts/publish-image.sh latest"
    echo ""
    echo "Or login with:"
    echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin"
    exit 1
  fi
fi

# Check if logged in to registry
if [ "$REGISTRY" = "ghcr.io" ] && [ -n "$GITHUB_TOKEN" ]; then
  echo -e "${GREEN}✓ GitHub token detected${NC}"
  echo -e "${BLUE}Logging in to GitHub Container Registry...${NC}"
  echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  echo -e "${GREEN}✓ Logged in!${NC}"
elif ! docker info | grep -q "Username:"; then
  echo -e "${YELLOW}⚠️  Not logged in to $REGISTRY${NC}"
  echo "Run: docker login $REGISTRY"
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Build the image
echo -e "${BLUE}📦 Building image...${NC}"
cd "$(dirname "$0")/../infrastructure/docker"
docker-compose build dev --no-cache

# Tag for GitHub Container Registry (docker-compose creates image as: docker-dev:latest)
echo -e "${BLUE}🏷️  Tagging image...${NC}"
docker tag docker-dev:latest "$FULL_IMAGE"

# Push to GitHub Container Registry
echo -e "${BLUE}📤 Pushing to GitHub Container Registry...${NC}"
docker push "$FULL_IMAGE"

echo ""
echo -e "${GREEN}✅ Published successfully!${NC}"
echo ""
echo "Users can now pull the public image:"
echo "  docker pull $FULL_IMAGE"
echo ""
echo "Or use in docker-compose.bazel-infra-lab.yml:"
echo "  image: $FULL_IMAGE"
echo ""
echo "No authentication needed to pull public images from $REGISTRY!"
echo ""
