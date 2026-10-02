#!/bin/bash
# Entrypoint script for bazel-infra-lab development container
# Starts bazel-remote cache server and provides shell access

set -e

# Set up terminal environment
export TERM="${TERM:-xterm-256color}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# START BAZEL-REMOTE CACHE SERVER
# ============================================================================

echo -e "${BLUE}🚀 Starting bazel-remote cache server...${NC}"

# Start bazel-remote in the background
bazel-remote \
  --dir=/var/bazel-remote/cache \
  --http_address=0.0.0.0:8080 \
  --grpc_address=0.0.0.0:9092 \
  --max_size=10 &

BAZEL_REMOTE_PID=$!

# Wait for bazel-remote to be ready
echo -e "${BLUE}⏳ Waiting for cache server to be ready...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -s http://localhost:8080/status >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Cache server ready on:${NC}"
    echo -e "  ${GREEN}HTTP:${NC}  http://localhost:8080"
    echo -e "  ${GREEN}gRPC:${NC}  grpc://localhost:9092"
    echo ""
    break
  fi
  attempt=$((attempt+1))
  sleep 1
done

if [ $attempt -eq $max_attempts ]; then
  echo -e "${RED}✗ Cache server failed to start${NC}"
  kill $BAZEL_REMOTE_PID 2>/dev/null || true
  exit 1
fi

# ============================================================================
# DISPLAY ENVIRONMENT INFO
# ============================================================================

echo -e "${BLUE}📋 Development Environment:${NC}"
echo "  Bazel:    $(bazel --version 2>/dev/null || echo 'N/A (install on host for ARM Mac)')"
echo "  Python:   $(python3.11 --version)"
echo "  GCC:      $(gcc --version | head -1)"
echo ""

echo -e "${BLUE}📁 Workspace: /workspace${NC}"
echo -e "${BLUE}📚 Available Commands:${NC}"
echo "  bazel build //app:hello --config=remote-cache"
echo "  bazel test //... --config=remote-cache"
echo "  curl http://localhost:8080/status | jq ."
echo ""

# ============================================================================
# HANDLE SIGNALS AND CLEANUP
# ============================================================================

# Function to cleanup
cleanup() {
  echo -e "${BLUE}🛑 Shutting down bazel-remote...${NC}"
  kill $BAZEL_REMOTE_PID 2>/dev/null || true
  wait $BAZEL_REMOTE_PID 2>/dev/null || true
  exit 0
}

# Trap signals to cleanup bazel-remote
trap cleanup SIGTERM SIGINT EXIT

# ============================================================================
# START SHELL OR EXECUTE COMMAND
# ============================================================================

if [ $# -eq 0 ]; then
  # No command provided, start interactive shell (don't use exec so we can cleanup)
  echo -e "${GREEN}Starting interactive shell...${NC}"
  echo ""
  bash --login
  # When bash exits, trap will fire and cleanup
else
  # Execute provided command (don't use exec so we can cleanup)
  "$@"
  # When command exits, trap will fire and cleanup
fi
