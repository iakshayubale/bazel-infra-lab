#!/bin/bash
# Simple Cache Demonstration - Shows CACHE MISS → CACHE HIT
# Run this inside the dev container

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔄 BAZEL REMOTE CACHE - MISS vs HIT DEMONSTRATION${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Verify cache server
echo -e "${YELLOW}Step 1: Verify cache server is running...${NC}"
if curl -s http://localhost:8080/status > /dev/null; then
    echo -e "${GREEN}✓ Cache server is healthy${NC}"
    echo "  HTTP API:  http://localhost:8080"
    echo "  gRPC:      grpc://localhost:9092"
else
    echo -e "${RED}✗ Cache server not running!${NC}"
    echo "  Start it with: docker-compose -f docker-compose.bazel-remote-server.yml up -d"
    exit 1
fi

# Step 2: Check initial cache state
echo ""
echo -e "${YELLOW}Step 2: Check cache before any builds...${NC}"
CACHE_STATUS=$(curl -s http://localhost:8080/status)
INITIAL_FILES=$(echo "$CACHE_STATUS" | jq '.NumFiles' 2>/dev/null || echo "0")
INITIAL_SIZE=$(echo "$CACHE_STATUS" | jq '.CurrSize' 2>/dev/null || echo "0")
echo -e "  Files in cache: ${BLUE}$INITIAL_FILES${NC}"
echo -e "  Cache size: ${BLUE}$INITIAL_SIZE bytes${NC}"

# Step 3: First build (CACHE MISS)
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 3: FIRST BUILD (Expected: CACHE MISS) 🔴${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Action: Build from source + upload to cache"
echo -e "  Command: bazel build //app:hello --config=remote-cache"
echo ""

# Clean and build with timing
bazel clean > /dev/null 2>&1
echo -e "  Measuring build time..."
START=$(date +%s%N)
bazel build //app:hello --config=remote-cache 2>&1 | grep -E "Building|Compiling|Uploading|Target" || echo "  [Building...]"
END=$(date +%s%N)
FIRST_TIME_MS=$(( (END - START) / 1000000 ))

echo ""
echo -e "${GREEN}✓ First build completed in: ${BLUE}${FIRST_TIME_MS}ms${NC}"
echo -e "  Expected: 5000-15000ms (source compilation + upload)"
echo ""

# Step 4: Check cache after first build
echo -e "${YELLOW}Step 4: Check cache after first build...${NC}"
CACHE_STATUS=$(curl -s http://localhost:8080/status)
AFTER_FIRST_FILES=$(echo "$CACHE_STATUS" | jq '.NumFiles' 2>/dev/null || echo "0")
AFTER_FIRST_SIZE=$(echo "$CACHE_STATUS" | jq '.CurrSize' 2>/dev/null || echo "0")
echo -e "  Files in cache: ${BLUE}$AFTER_FIRST_FILES${NC} (was $INITIAL_FILES)"
echo -e "  Cache size: ${BLUE}$AFTER_FIRST_SIZE bytes${NC} (was $INITIAL_SIZE)"

if [ "$AFTER_FIRST_FILES" -gt "$INITIAL_FILES" ]; then
    echo -e "  ${GREEN}✓ Artifacts uploaded to cache!${NC}"
else
    echo -e "  ${RED}⚠ Cache unchanged - build may not have used remote cache${NC}"
fi

# Step 5: Second build (CACHE HIT)
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 5: SECOND BUILD (Expected: CACHE HIT) 🟢${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Action: Download from cache (no compilation)"
echo -e "  Command: bazel clean && bazel build //app:hello --config=remote-cache"
echo ""

# Clean and build with timing
bazel clean > /dev/null 2>&1
echo -e "  Measuring build time..."
START=$(date +%s%N)
bazel build //app:hello --config=remote-cache 2>&1 | grep -E "Building|remote cache|Linking|Target" || echo "  [Building...]"
END=$(date +%s%N)
SECOND_TIME_MS=$(( (END - START) / 1000000 ))

echo ""
echo -e "${GREEN}✓ Second build completed in: ${BLUE}${SECOND_TIME_MS}ms${NC}"
echo -e "  Expected: 1000-3000ms (download + link, no compilation)"
echo ""

# Step 6: Calculate speedup
echo -e "${YELLOW}Step 6: Cache Performance Analysis${NC}"
SPEEDUP=$(( FIRST_TIME_MS / SECOND_TIME_MS ))
IMPROVEMENT=$(( (FIRST_TIME_MS - SECOND_TIME_MS) * 100 / FIRST_TIME_MS ))

echo -e "  First build:  ${BLUE}${FIRST_TIME_MS}ms${NC} (compile + upload)"
echo -e "  Second build: ${BLUE}${SECOND_TIME_MS}ms${NC} (download + link)"
echo ""
if [ "$SECOND_TIME_MS" -lt "$FIRST_TIME_MS" ]; then
    echo -e "  ${GREEN}✓ CACHE HIT VERIFIED!${NC}"
    echo -e "  Speedup: ${GREEN}${SPEEDUP}x faster${NC} (${IMPROVEMENT}% faster)"
else
    echo -e "  ${YELLOW}⚠ Cache HIT not detected${NC}"
    echo -e "  Second build was ${BLUE}${SECOND_TIME_MS}ms${NC} (not faster)"
    echo -e "  Check: ${YELLOW}curl -s http://localhost:8080/status | jq .${NC}"
fi

# Step 7: Final cache state
echo ""
echo -e "${YELLOW}Step 7: Final cache state...${NC}"
CACHE_STATUS=$(curl -s http://localhost:8080/status)
FINAL_FILES=$(echo "$CACHE_STATUS" | jq '.NumFiles' 2>/dev/null || echo "0")
FINAL_SIZE=$(echo "$CACHE_STATUS" | jq '.CurrSize' 2>/dev/null || echo "0")
FORMATTED_SIZE=$(numfmt --to=iec-i --suffix=B "$FINAL_SIZE" 2>/dev/null || echo "$FINAL_SIZE bytes")
echo -e "  Files in cache: ${BLUE}$FINAL_FILES${NC}"
echo -e "  Cache size: ${BLUE}$FORMATTED_SIZE${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ DEMONSTRATION COMPLETE!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}How caching works:${NC}"
echo -e "  1. First build: Bazel compiles → uploads to cache (slow)"
echo -e "  2. Cache stores: action_key → [output artifacts]"
echo -e "  3. Second build: Bazel downloads from cache (fast!)"
echo -e "  4. Result: 4-5x speedup for team members"
echo ""
echo -e "${YELLOW}Try with benchmark:${NC}"
echo -e "  bazel build //benchmark:cache_demo --config=remote-cache"
echo ""
