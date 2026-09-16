#!/bin/bash

# Setup script for Bazel Remote Build Example
# Initializes local development environment with BuildBuddy

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it and try again."
    fi
    log_info "✓ Found $1"
}

# Check prerequisites
log_info "Checking prerequisites..."
check_command "docker"
check_command "docker-compose"
check_command "bazel"
check_command "git"

# Platform detection
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

log_info "Detected OS: $OS_TYPE, Architecture: $ARCH"

# 1. Initialize git (if not already)
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    log_info "Initializing git repository..."
    cd "$PROJECT_ROOT"
    git init
    git add .
    git commit -m "Initial commit: Bazel remote build example" || true
fi

# 2. Create .bazelrc from template
if [ ! -f "$PROJECT_ROOT/.bazelrc" ]; then
    log_info "Creating .bazelrc from template..."
    cp "$PROJECT_ROOT/.bazelrc.example" "$PROJECT_ROOT/.bazelrc"
    log_warn "⚠️  Please review .bazelrc and customize if needed"
fi

# 3. Create .bazelrc.local for local overrides
if [ ! -f "$PROJECT_ROOT/.bazelrc.local" ]; then
    log_info "Creating .bazelrc.local for local settings..."
    cat > "$PROJECT_ROOT/.bazelrc.local" <<EOF
# Local machine-specific overrides
# This file is not committed to git

# Example: Use local execution
# common --config=local

# Example: Custom compiler path
# build --cc=/usr/bin/gcc-11

# Example: Custom cache directory
# common --disk_cache=/tmp/bazel-cache
EOF
fi

# 4. Create docker-compose .env file
if [ ! -f "$PROJECT_ROOT/infrastructure/docker/.env" ]; then
    log_info "Creating docker-compose environment file..."
    cat > "$PROJECT_ROOT/infrastructure/docker/.env" <<EOF
# BuildBuddy Docker Environment
BUILDBUDDY_VERSION=latest
BUILDBUDDY_API_URL=http://localhost:8085
BUILDBUDDY_API_KEY=demo-api-key
CACHE_MAX_SIZE_BYTES=10737418240
EOF
fi

# 5. Create build cache directory
BUILD_CACHE_DIR="${PROJECT_ROOT}/.bazel-cache"
if [ ! -d "$BUILD_CACHE_DIR" ]; then
    log_info "Creating build cache directory..."
    mkdir -p "$BUILD_CACHE_DIR"
fi

# 6. Start BuildBuddy (optional)
read -p "Start BuildBuddy server now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Starting BuildBuddy..."
    cd "$PROJECT_ROOT/infrastructure/docker"
    docker-compose up -d
    
    # Wait for BuildBuddy to be ready
    log_info "Waiting for BuildBuddy to be ready..."
    sleep 10
    
    # Check health
    if curl -f http://localhost:8086/health >/dev/null 2>&1; then
        log_info "✓ BuildBuddy is running!"
        log_info "Dashboard: http://localhost:8086"
        log_info "API: http://localhost:8085"
    else
        log_warn "BuildBuddy may not be ready yet. Check with: docker-compose logs"
    fi
fi

# 7. Test Bazel configuration
log_info "Testing Bazel configuration..."
cd "$PROJECT_ROOT"

if bazel --version >/dev/null 2>&1; then
    BAZEL_VERSION=$(bazel --version 2>&1 | awk '{print $2}')
    log_info "Bazel version: $BAZEL_VERSION"
else
    log_error "Bazel is not properly installed"
fi

# 8. Build test
read -p "Run test build? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Running test build (local, no caching)..."
    
    if bazel build --config=local //lib:math 2>&1 | tee /tmp/bazel_build.log; then
        log_info "✓ Test build successful!"
    else
        log_warn "Test build failed. Check log for details."
    fi
fi

# 9. Create quick-start guide
cat > "$PROJECT_ROOT/QUICK_START.md" <<'EOF'
# Quick Start Guide

## Start BuildBuddy

```bash
cd infrastructure/docker
docker-compose up -d
```

Visit dashboard: http://localhost:8086

## Build with Remote Caching

```bash
# First build (populates cache)
bazel build --config=remote-cache //app:hello

# Second build (instant from cache)
bazel build --config=remote-cache //app:hello
```

## Run Tests

```bash
bazel test --config=remote-cache //...
```

## View Build Metrics

- Dashboard: http://localhost:8086
- Check "Invocations" tab for build history
- Check cache hit rates

## Full Remote Execution

For distributed builds (requires multiple executor nodes):

```bash
bazel build --config=remote //app:hello
```

## Troubleshooting

BuildBuddy not responding?
```bash
docker-compose ps
docker-compose logs
```

See docs/ for detailed guides on:
- Local setup
- Best practices

## Next Steps

1. Read `docs/local-setup.md` for detailed configuration
2. Read `docs/best-practices.md` for optimization tips
EOF

log_info "Setup complete! ✓"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "1. Review .bazelrc and customize as needed"
echo "2. Start BuildBuddy: cd infrastructure/docker && docker-compose up -d"
echo "3. Build with caching: bazel build --config=remote-cache //app:hello"
echo "4. View dashboard: http://localhost:8086"
echo ""
echo "Detailed guides:"
echo "- Local setup: docs/local-setup.md"
echo "- Best practices: docs/best-practices.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
