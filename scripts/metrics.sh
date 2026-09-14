#!/bin/bash

# Build metrics analyzer for Bazel Remote Build Example
# Displays cache statistics, build times, and performance metrics

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Terminal colors using tput (POSIX standard)
if command -v tput &> /dev/null; then
    GREEN=$(tput setaf 2)      # Green
    BLUE=$(tput setaf 4)       # Blue
    CYAN=$(tput setaf 6)       # Cyan
    YELLOW=$(tput setaf 3)     # Yellow
    RED=$(tput setaf 1)        # Red
    BOLD=$(tput bold)          # Bold
    NC=$(tput sgr0)            # Reset
else
    # Fallback to empty strings if tput not available
    GREEN=""
    BLUE=""
    CYAN=""
    YELLOW=""
    RED=""
    BOLD=""
    NC=""
fi

# Helper function to format bytes
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes / 1073741824" | bc)GB"
    fi
}

# Logging functions for consistent output formatting
log_detail() {
    printf "${BLUE}  →${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}  ✓${NC} %s\n" "$1"
}

printf "%s╔════════════════════════════════════════════════════════════╗%s\n" "$BLUE" "$NC"
printf "%s║          🚀 Bazel Remote Build Metrics Dashboard           ║%s\n" "$BLUE" "$NC"
printf "%s╚════════════════════════════════════════════════════════════╝%s\n" "$BLUE" "$NC"
printf "\n"

# 1. Cache Server Status
printf "%s┌─ 📦 Remote Cache Server Status ─────────────────────────────┐%s\n" "$CYAN" "$NC"

CACHE_RUNNING=false
if curl -s http://localhost:8085/status >/dev/null 2>&1; then
    CACHE_RUNNING=true
    CACHE_DATA=$(curl -s http://localhost:8085/status 2>/dev/null)
    printf "%s✓ bazel-remote cache server is RUNNING on localhost:8085%s\n" "$GREEN" "$NC"
    
    log_detail "Cache Utilization:"
    if command -v jq &> /dev/null; then
        CURR_SIZE=$(echo "$CACHE_DATA" | jq '.CurrSize // 0')
        MAX_SIZE=$(echo "$CACHE_DATA" | jq '.MaxSize // 0')
        NUM_FILES=$(echo "$CACHE_DATA" | jq '.NumFiles // 0')
        UNCOMPRESSED=$(echo "$CACHE_DATA" | jq '.UncompressedSize // 0')
    else
        # Fallback to sed if jq not available
        CURR_SIZE=$(echo "$CACHE_DATA" | sed -n 's/.*"CurrSize":\([0-9]*\).*/\1/p')
        MAX_SIZE=$(echo "$CACHE_DATA" | sed -n 's/.*"MaxSize":\([0-9]*\).*/\1/p')
        NUM_FILES=$(echo "$CACHE_DATA" | sed -n 's/.*"NumFiles":\([0-9]*\).*/\1/p')
        UNCOMPRESSED=$(echo "$CACHE_DATA" | sed -n 's/.*"UncompressedSize":\([0-9]*\).*/\1/p')
    fi
    
    # Default to 0 if empty
    CURR_SIZE=${CURR_SIZE:-0}
    MAX_SIZE=${MAX_SIZE:-10737418240}
    NUM_FILES=${NUM_FILES:-0}
    UNCOMPRESSED=${UNCOMPRESSED:-0}
    
    CURR_FORMATTED=$(format_bytes "$CURR_SIZE")
    MAX_FORMATTED=$(format_bytes "$MAX_SIZE")
    UNCOMPRESSED_FORMATTED=$(format_bytes "$UNCOMPRESSED")
    
    # Calculate percentage with higher precision for small values
    if [ "$MAX_SIZE" -gt 0 ]; then
        PERCENT=$(echo "scale=4; $CURR_SIZE * 100 / $MAX_SIZE" | bc)
        # Check if percentage is less than 0.01
        PERCENT_CHECK=$(echo "$PERCENT < 0.01" | bc)
        if [ "$PERCENT_CHECK" -eq 1 ] && [ "$CURR_SIZE" -gt 0 ]; then
            PERCENT="< 0.01"
        fi
        # For progress bar, show at least 1 filled block if there's any data
        FILLED=$((30 * CURR_SIZE / MAX_SIZE))
        if [ "$CURR_SIZE" -gt 0 ] && [ "$FILLED" -eq 0 ]; then
            FILLED=1
        fi
    else
        PERCENT=0
        FILLED=0
    fi
    EMPTY=$((30 - FILLED))
    
    printf "    ["
    printf "%${FILLED}s" | tr ' ' '█'
    printf "%${EMPTY}s" | tr ' ' '░'
    printf "] %s%%\n" "$PERCENT"
    echo "    Current Size: $CURR_FORMATTED / $MAX_FORMATTED"
    echo "    Uncompressed: $UNCOMPRESSED_FORMATTED"
    echo "    Files in Cache: $NUM_FILES"
else
    printf "%s✗ bazel-remote cache server is NOT RUNNING%s\n" "$RED" "$NC"
    echo "    Start with: cd infrastructure/docker && docker-compose up -d"
fi
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
printf "\n"

# 2. Bazel Configuration
printf "%s┌─ ⚙️  Bazel Configuration ───────────────────────────────────┐%s\n" "$CYAN" "$NC"

log_detail "Bazel Configuration:"

# Bazel info
if command -v bazel &> /dev/null; then
    BAZEL_VERSION=$(bazel --version 2>&1 | awk '{print $2}')
    echo "    Bazel Version:          $BAZEL_VERSION"
    
    OUTPUT_BASE=$(bazel info output_base 2>/dev/null || echo "N/A")
    echo "    Output Base:            $(basename $OUTPUT_BASE)"
else
    echo "    ${RED}✗ Bazel not found${NC}"
fi

if [ -f ".bazelrc" ]; then
    echo "    .bazelrc:               Configured"
    
    # Check for remote cache config
    if grep -q "remote_cache" .bazelrc; then
        REMOTE_URL=$(grep "remote_cache=" .bazelrc | head -1 | sed 's/.*remote_cache=\([^ ]*\).*/\1/')
        echo "    Cache Endpoint:         $REMOTE_URL"
    fi
fi

printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
printf "\n"

# 3. Project Structure
printf "%s┌─ 📊 Project Structure ──────────────────────────────────────┐%s\n" "$CYAN" "$NC"

# Count BUILD files
BUILD_COUNT=$(find . -name "BUILD" -type f -not -path './.*' 2>/dev/null | wc -l)

# Count source files
CC_COUNT=$(find . -name "*.cc" -type f -not -path './.*' 2>/dev/null | wc -l)
H_COUNT=$(find . -name "*.h" -type f -not -path './.*' 2>/dev/null | wc -l)
TEST_COUNT=$(find . -name "*_test.cc" -type f -not -path './.*' 2>/dev/null | wc -l)

# Total lines of code
TOTAL_LOC=$(find . \( -name "*.cc" -o -name "*.h" \) -type f -not -path './.*' 2>/dev/null -exec wc -l {} + | tail -1 | awk '{print $1}')

log_detail "BUILD Targets:          $BUILD_COUNT files"
echo "    C++ Source Files:       $CC_COUNT (.cc files)"
echo "    C++ Header Files:       $H_COUNT (.h files)"
echo "    Test Files:             $TEST_COUNT (_test.cc files)"
echo "    Lines of Code:          $TOTAL_LOC lines"

echo ""
log_detail "Directory Tree:"
echo "    ├─ app/              → Application code"
echo "    ├─ lib/              → Shared libraries"
echo "    ├─ infrastructure/   → Docker & deployment"
echo "    ├─ scripts/          → Build tools"
echo "    └─ docs/             → Documentation"

printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
printf "\n"

# 4. Docker Status
if command -v docker &> /dev/null; then
    printf "%s┌─ 🐳 Docker Containers ─────────────────────────────────────┐%s\n" "$CYAN" "$NC"
    
    DOCKER_DIR="infrastructure/docker"
    if [ -d "$DOCKER_DIR" ]; then
        cd "$DOCKER_DIR" 2>/dev/null
        
        # Get container status using docker-compose ps format
        CONTAINER_OUTPUT=$(docker-compose ps --format "{{.Service}}\t{{.Status}}" 2>/dev/null)
        
        if [ -z "$CONTAINER_OUTPUT" ]; then
            echo "    ${RED}✗ No containers running${NC}"
            echo "    Start with: docker-compose up -d"
        else
            # Parse each container line
            echo "$CONTAINER_OUTPUT" | while IFS=$'\t' read -r service status; do
                if [ -n "$service" ] && [ -n "$status" ]; then
                    if [[ "$status" == *"Up"* ]]; then
                        log_success "$service ($status)"
                    else
                        echo "    ${RED}✗${NC} $service ($status)"
                    fi
                fi
            done
        fi
        
        cd "$PROJECT_ROOT" 2>/dev/null
    fi
    printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
    printf "\n"
fi

# 5. Quick Commands
printf "%s┌─ 🚄 Quick Build Commands ───────────────────────────────────┐%s\n" "$CYAN" "$NC"
log_detail "Local build (no cache):"
echo "    bazel build //app:hello"
echo ""
log_detail "With remote caching:"
echo "    bazel build //app:hello --remote_cache=http://localhost:8085"
echo ""
log_detail "Run all tests:"
echo "    bazel test //..."
echo ""
log_detail "Show cache demo:"
echo "    ./scripts/demonstrate-cache.sh"
echo ""
log_detail "Profile build:"
echo "    bazel build --profile=/tmp/profile.gz //app:hello"
echo "    bazel analyze-profile /tmp/profile.gz"
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
printf "\n"

# 6. Summary
printf "%s╔════════════════════════════════════════════════════════════╗%s\n" "$BLUE" "$NC"
if [ "$CACHE_RUNNING" = true ]; then
    printf "%s║%s Status: %s✓ Ready for remote caching%s%-34s %s%s\n" "$BLUE" "$NC" "$GREEN" "$NC" "" "$BLUE" "$NC"
else
    printf "%s║%s Status: %s⚠ Cache server needed for demo%s%-29s %s║%s\n" "$BLUE" "$NC" "$YELLOW" "$NC" "" "$BLUE" "$NC"
fi
printf "%s╚════════════════════════════════════════════════════════════╝%s\n" "$BLUE" "$NC"
printf "\n"
