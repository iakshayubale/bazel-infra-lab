#!/bin/bash
# Welcome message for bazel-remote cache server container

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Clear screen
clear

# ASCII art banner
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           
║      🚀 BAZEL REMOTE CACHE SERVER - Started 🚀           
║                                                           
║    Centralized build cache for your infrastructure       
║                                                           
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 CACHE SERVER ENDPOINTS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓${NC} HTTP Status API:      http://bazel-remote:8080"
echo -e "${GREEN}✓${NC} gRPC Cache API:       grpc://bazel-remote:9092"
echo -e "${GREEN}✓${NC} Storage Directory:    /var/bazel-remote/cache"
echo -e "${GREEN}✓${NC} Max Cache Size:       10 GB"
echo ""

# Get status
if curl -s http://localhost:8080/status >/dev/null 2>&1; then
    STATUS=$(curl -s http://localhost:8080/status)
    NUM_FILES=$(echo "$STATUS" | jq -r '.NumFiles // 0' 2>/dev/null || echo "0")
    CURR_SIZE=$(echo "$STATUS" | jq -r '.CurrSize // 0' 2>/dev/null || echo "0")
    MAX_SIZE=$(echo "$STATUS" | jq -r '.MaxSize // 0' 2>/dev/null || echo "10737418240")
    
    # Convert bytes to human readable
    CURR_SIZE_MB=$(( CURR_SIZE / 1048576 ))
    MAX_SIZE_GB=$(( MAX_SIZE / 1073741824 ))
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📦 CACHE STATUS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}✓${NC} Files in Cache:       $NUM_FILES artifacts"
    echo -e "${GREEN}✓${NC} Cache Size:           ${CURR_SIZE_MB} MB / ${MAX_SIZE_GB} GB"
    echo -e "${GREEN}✓${NC} Server Status:        READY (HTTP 200)"
    echo ""
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🔧 MANAGEMENT COMMANDS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}Check Cache Status (from host):${NC}"
echo -e "  ${YELLOW}→${NC}  curl -s http://localhost:8080/status | jq ."
echo ""

echo -e "${BOLD}Monitor Cache Updates:${NC}"
echo -e "  ${YELLOW}→${NC}  watch -n 1 'curl -s http://localhost:8080/status | jq .'"
echo ""

echo -e "${BOLD}Access from Docker Network:${NC}"
echo -e "  ${YELLOW}→${NC}  docker exec <container> curl http://bazel-remote:8080/status"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}💡 HOW IT WORKS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${MAGENTA}🔹 Action Cache:${NC}"
echo "   Maps: action_key (SHA256 hash) → [output files]"
echo "   Hash includes: source code + compiler flags + toolchain"
echo "   Same hash = cache HIT (reuse previous outputs)"
echo ""

echo -e "${MAGENTA}🔹 Content Addressable Storage (CAS):${NC}"
echo "   Stores actual build artifacts by content hash"
echo "   Compression: Zstandard (72%+ reduction typical)"
echo "   Immutable: Once stored, never changes"
echo ""

echo -e "${MAGENTA}🔹 Performance Impact:${NC}"
echo "   • Cache MISS: Compile locally + upload (~8-12 seconds)"
echo "   • Cache HIT: Download from cache (~1-2 seconds)"
echo "   • Typical speedup: 5-6x faster for full rebuilds"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🌐 CONNECTING DEV CONTAINERS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "All dev containers connect via Docker network:"
echo ""
echo -e "  ${YELLOW}Environment Variable:${NC}"
echo "    BAZEL_REMOTE_CACHE=grpc://bazel-remote:9092"
echo ""
echo -e "  ${YELLOW}Bazel Configuration:${NC}"
echo "    --remote_cache=grpc://bazel-remote:9092"
echo ""
echo -e "  ${YELLOW}Multiple containers can share:${NC}"
echo "    docker-compose run -d --name dev-alice dev bash"
echo "    docker-compose run -d --name dev-bob dev bash"
echo "    (Both will share same cache!)"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Cache server running in background!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Container logs: tail -f /var/log/bazel-remote.log (if enabled)"
echo "To stop server: docker-compose down"
echo ""
