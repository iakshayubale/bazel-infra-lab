#!/bin/bash
# Welcome message for bazel-infra-lab development container

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
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           
║   🏗️   BAZEL INFRA LAB - Development Environment    🏗️     
║                                                           
║   Your private build infrastructure for rapid testing     
║                                                           
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📋 ENVIRONMENT DETAILS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓${NC} Bazel Version:        $(bazel version 2>&1 | grep 'Bazel' | head -1 || echo 'bazel 9.2.0')"
echo -e "${GREEN}✓${NC} Python Version:       $(python3 --version 2>&1)"
echo -e "${GREEN}✓${NC} GCC Version:          $(gcc --version 2>&1 | head -1)"
echo -e "${GREEN}✓${NC} Workspace:            /workspace"
echo -e "${GREEN}✓${NC} Remote Cache:         grpc://bazel-remote:9092"
echo ""

# Check if cache server is reachable
if curl -s http://bazel-remote:8080/status >/dev/null 2>&1; then
    CACHE_STATUS=$(curl -s http://bazel-remote:8080/status | jq -r '.NumFiles' 2>/dev/null || echo "?")
    echo -e "${GREEN}✓${NC} Cache Server Status:  READY (${CACHE_STATUS} artifacts cached)"
else
    echo -e "${YELLOW}⚠${NC}  Cache Server Status:  WAITING FOR CONNECTION"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🚀 QUICK START COMMANDS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}Build Commands:${NC}"
echo -e "  ${YELLOW}→${NC}  bazel build //app:hello                 ${MAGENTA}(Quick build)${NC}"
echo -e "  ${YELLOW}→${NC}  bazel build //benchmark:cache_demo      ${MAGENTA}(Heavy build)${NC}"
echo -e "  ${YELLOW}→${NC}  bazel build //... --config=remote-cache ${MAGENTA}(All targets)${NC}"
echo ""

echo -e "${BOLD}Test Commands:${NC}"
echo -e "  ${YELLOW}→${NC}  bazel test //...                        ${MAGENTA}(Run all tests)${NC}"
echo -e "  ${YELLOW}→${NC}  bazel test //app:hello_test             ${MAGENTA}(Run one test)${NC}"
echo ""

echo -e "${BOLD}Cache Commands:${NC}"
echo -e "  ${YELLOW}→${NC}  curl -s http://bazel-remote:8080/status | jq .  ${MAGENTA}(Cache status)${NC}"
echo -e "  ${YELLOW}→${NC}  ./scripts/demonstrate-cache.sh          ${MAGENTA}(Demo: miss→hit)${NC}"
echo -e "  ${YELLOW}→${NC}  ./scripts/demonstrate-cache.sh metrics  ${MAGENTA}(Show metrics)${NC}"
echo ""

echo -e "${BOLD}Profile & Debug:${NC}"
echo -e "  ${YELLOW}→${NC}  bazel build --profile=/tmp/p.gz //app:hello"
echo -e "  ${YELLOW}→${NC}  bazel analyze-profile /tmp/p.gz"
echo -e "  ${YELLOW}→${NC}  bazel query 'deps(//app:hello)'         ${MAGENTA}(Show dependencies)${NC}"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}💡 PRO TIPS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${MAGENTA}🔹 Remote Cache Benefits:${NC}"
echo "   • First build: Compiles locally, uploads to shared cache"
echo "   • Second build: Downloads from cache (5-6x faster!)"
echo "   • Team members share cache automatically"
echo "   • Incremental builds use cached dependencies"
echo ""

echo -e "${MAGENTA}🔹 Bazel Best Practices:${NC}"
echo "   • Use 'bazel clean' to clear local cache"
echo "   • Cache persists on server (survives container restart)"
echo "   • Action key = hash(source + compiler flags)"
echo "   • Same hash = cache HIT across builds"
echo ""

echo -e "${MAGENTA}🔹 Performance Tips:${NC}"
echo "   • Monitor cache: ./scripts/demonstrate-cache.sh metrics"
echo "   • Use benchmark build: ./scripts/demonstrate-cache.sh benchmark"
echo "   • Profile builds: bazel build --profile=file.gz"
echo "   • Analyze timings: bazel analyze-profile file.gz"
echo ""

echo -e "${MAGENTA}🔹 Docker Network:${NC}"
echo "   • Service name 'bazel-remote' resolves to server"
echo "   • gRPC cache: grpc://bazel-remote:9092"
echo "   • HTTP status: http://bazel-remote:8080/status"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Ready to build! Type 'exit' to close this session.${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
