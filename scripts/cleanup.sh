#!/bin/bash

# Cleanup script for Bazel Remote Build Example
# Removes BuildBuddy containers, caches, and artifacts

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Confirm before cleanup
echo "This will remove:"
echo "  - BuildBuddy containers"
echo "  - BuildBuddy volumes (cache, database)"
echo "  - Bazel build artifacts"
echo "  - Bazel cache"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Cleanup cancelled"
    exit 0
fi

# Stop and remove Docker containers
log_info "Stopping BuildBuddy containers..."
cd "$PROJECT_ROOT/infrastructure/docker"
docker-compose down || true

# Remove volumes
log_info "Removing BuildBuddy volumes..."
docker volume rm buildbuddy_cache buildbuddy_db buildbuddy_executor 2>/dev/null || true

# Clean Bazel cache
log_info "Cleaning Bazel cache..."
cd "$PROJECT_ROOT"
bazel clean --expunge || true

# Remove build artifacts
if [ -d "$PROJECT_ROOT/build" ]; then
    log_info "Removing build directory..."
    rm -rf "$PROJECT_ROOT/build"
fi

if [ -d "$PROJECT_ROOT/.bazel-cache" ]; then
    log_info "Removing .bazel-cache..."
    rm -rf "$PROJECT_ROOT/.bazel-cache"
fi

# Remove generated files
if [ -f "$PROJECT_ROOT/.bazelrc" ]; then
    log_warn "Keeping .bazelrc (remove manually if needed)"
fi

log_info "Cleanup complete! ✓"
