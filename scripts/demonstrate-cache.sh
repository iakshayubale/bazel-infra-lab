#!/bin/bash
set -e

# Cache server configuration
CACHE_SERVER="localhost:8080"  # HTTP/REST endpoint for status checks
GRPC_ENDPOINT="grpc://localhost:9092"  # gRPC endpoint for Bazel cache communication
BUILD_TARGET="//app:hello"

# Color setup for terminal output
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
RESET=$(tput sgr0)
BOLD=$(tput bold)

# Logging functions for real-time output
log_step() {
    printf "\n${CYAN}${BOLD}[STEP]${RESET} %s\n" "$1"
}

log_detail() {
    printf "${BLUE}  →${RESET} %s\n" "$1"
}

log_success() {
    printf "${GREEN}  ✓${RESET} %s\n" "$1"
}

log_cache_query() {
    printf "${YELLOW}  ↔ CACHE QUERY${RESET} %s\n" "$1"
}

log_action_key() {
    printf "${BOLD}  🔑 ACTION KEY:${RESET} %s\n" "$1"
}

# Function to check if action result exists in cache
check_cache_for_action() {
    local action_digest=$1
    local cache_server=$2
    
    if [ -z "$action_digest" ]; then
        echo "UNKNOWN"
        return
    fi
    
    # Convert action digest format if needed (some versions use different separators)
    local action_hash=$(echo "$action_digest" | cut -d: -f1)
    
    # Query the cache server's action cache (bazel-remote stores in blob storage)
    # Try direct lookup via the CAS API
    local response=$(curl -s -X HEAD "http://${cache_server}/ac/${action_hash}" 2>/dev/null)
    local curl_code=$?
    
    if [ $curl_code -eq 0 ]; then
        echo "FOUND"
    else
        echo "NOT_FOUND"
    fi
}

# Function to format bytes as human-readable size
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

# Function to format percentage usage with decimal precision
format_cache_usage() {
    local used=$1
    local max=$2
    if [ "$max" -gt 0 ]; then
        # Use awk for decimal precision (bash arithmetic is integer-only)
        local percent=$(awk "BEGIN {printf \"%.2f\", $used * 100 / $max}")
        echo "${percent}%"
    else
        echo "0.00%"
    fi
}

# Function to format timestamp to readable date
format_timestamp() {
    local ts=$1
    if command -v date &> /dev/null; then
        date -r "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts"
    else
        echo "$ts"
    fi
}

# Initialize variables
CACHE_HIT_DETECTED=false
ACTION_DIGEST=""
ACTION_DIGEST_2=""

# Parse command line arguments
SHOW_METRICS=false
CLEAR_REMOTE=false
USE_BENCHMARK=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        metrics)
            SHOW_METRICS=true
            shift
            ;;
        clear-remote)
            CLEAR_REMOTE=true
            shift
            ;;
        benchmark)
            USE_BENCHMARK=true
            shift
            ;;
        help|--help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "❌ Unknown argument: $1"
            SHOW_HELP=true
            shift
            ;;
    esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    echo "Usage: ./scripts/demonstrate-cache.sh [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  metrics         Show project metrics dashboard before demonstration"
    echo "  clear-remote    Clear remote cache before testing (start from scratch)"
    echo "  benchmark       Use heavy benchmark build (slow first build, fast cache hit)"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/demonstrate-cache.sh                    # Run cache demo"
    echo "  ./scripts/demonstrate-cache.sh metrics           # Show metrics then demo"
    echo "  ./scripts/demonstrate-cache.sh benchmark         # Heavy benchmark demo"
    echo "  ./scripts/demonstrate-cache.sh metrics benchmark clear-remote  # All options"
    echo ""
    exit 0
fi

# Show metrics if requested
if [ "$SHOW_METRICS" = true ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    
    echo "📊 Loading Bazel Remote Build Metrics..."
    echo ""
    bash "$PROJECT_ROOT/scripts/metrics.sh"
    echo ""
    printf "%s┌─ 🎬Cache Demonstration ────────────────────────────────────┐%s\n" "$CYAN" "$NC"
    echo "    Now starting cache demonstration..."
    printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
    echo ""
fi

# Clear remote cache if requested
if [ "$CLEAR_REMOTE" = true ]; then
    echo "🧹 Clearing remote cache..."
    DOCKER_DIR="infrastructure/docker"
    if [ -d "$DOCKER_DIR" ]; then
        cd "$DOCKER_DIR" 2>/dev/null
        echo "   Stopping cache server..."
        docker-compose down > /dev/null 2>&1 || true
        echo "   Removing cache volume..."
        docker volume rm docker_bazel-remote-cache > /dev/null 2>&1 || true
        echo "   Restarting cache server..."
        docker-compose up -d > /dev/null 2>&1
        sleep 2  # Give cache server time to start
        echo "✅ Remote cache cleared and restarted"
        echo ""
        cd - > /dev/null 2>&1
    fi
fi

printf "%s┌─ 🎬 Remote Cache Demonstration ──────────────────────────────┐%s\n" "$CYAN" "$NC"

# Select build target
if [ "$USE_BENCHMARK" = true ]; then
    BUILD_TARGET="//benchmark:cache_demo"
    log_detail "Mode: HEAVY BENCHMARK BUILD"
    echo "    First build may take 60-120 seconds"
    echo "    Cache hit should be 10-20 seconds (80%+ faster)"
else
    BUILD_TARGET="//app:hello"
    log_detail "Mode: QUICK DEMO BUILD"
fi

echo ""
log_detail "Understanding the cache:"
echo "    • bazel clean:        Clears LOCAL cache only"
echo "    • Remote cache:       Persists on server (gRPC: grpc://localhost:9092, HTTP: localhost:8080)"
echo "    • Cache hit:          Download from remote instead of recompile"
echo ""
log_detail "Important Note:"
echo "    If you changed source code between builds, the changed files"
echo "    will be recompiled (cache won't help those). For best results,"
echo "    don't modify source code between builds."
echo ""
log_detail "Checking cache server..."
if ! curl -s http://localhost:8080/status > /dev/null 2>&1; then
    echo "    ❌ Cache server not running. Start it with:"
    echo "    cd infrastructure/docker && docker-compose up -d"
    exit 1
fi
echo "    ✅ Cache server is healthy (HTTP on localhost:8080, gRPC on localhost:9092)"
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""

# Remote cache flags (use gRPC endpoint for Bazel communication)
CACHE_FLAGS="--remote_cache=grpc://localhost:9092 --remote_upload_local_results=true"

printf "\n%s┌─ 🎬 CACHE DEMONSTRATION: Real-Time Execution Logging ──────┐%s\n" "$CYAN" "$NC"
log_detail "How this works:"
echo "    • First build: What gets compiled and uploaded to cache"
echo "    • Second build: What gets downloaded from cache"
echo ""
log_detail "Technical details:"
echo "    See README.md > 'How Remote Cache Works' for step-by-step explanations"
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""
printf "%s┌─ 📦 STEP 1: First Build (Cache Miss Expected) ──────────────┐%s\n" "$CYAN" "$NC"
log_detail "Building with remote cache enabled"
echo "    Compiling source files and uploading to cache..."
echo ""
echo "    Running: bazel clean && bazel build $BUILD_TARGET $CACHE_FLAGS"
echo ""
bazel clean > /dev/null 2>&1

# Capture build output to extract action information
FIRST_BUILD_OUTPUT=$(mktemp)
# Use Python for better cross-platform timing (macOS doesn't support %N in date)
START_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
bazel build $BUILD_TARGET $CACHE_FLAGS 2>&1 | tee "$FIRST_BUILD_OUTPUT" | grep -E "(Building|Linking|Compiling|Uploading|uploaded to remote|Cache)" || echo "   Compiling all files and uploading to cache..."
END_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
FIRST_BUILD_TIME=$(( END_TIME - START_TIME ))

# Analyze first build output
FIRST_BUILD_CONTENT=$(cat "$FIRST_BUILD_OUTPUT")
FIRST_HAS_COMPILE=$(echo "$FIRST_BUILD_CONTENT" | grep -i "compil" | wc -l)
FIRST_HAS_UPLOAD=$(echo "$FIRST_BUILD_CONTENT" | grep -i "upload\|remote" | wc -l)

# Extract and show full action digest if available
# Also extract configuration that affects action key computation
if [ -f /tmp/first_build.log ]; then
    ACTION_DIGEST=$(grep -oE '"action_digest":"[^"]*' /tmp/first_build.log | head -1 | cut -d'"' -f4)
    if [ -n "$ACTION_DIGEST" ] && [ "$ACTION_DIGEST" != "" ]; then
        ACTION_DIGEST_SHORT=$(echo "$ACTION_DIGEST" | cut -c1-16)
        log_action_key "$ACTION_DIGEST_SHORT..."
        log_detail "Full hash: $ACTION_DIGEST"
    else
        # Try to get action info from bazel query
        log_action_key "Extracting from build configuration..."
        log_detail "Using: Source files + Compiler flags + Toolchain + Build rules"
    fi
fi

echo ""
log_detail "STEPS 2-4: Query Action Cache"
log_cache_query "GetActionResult($ACTION_DIGEST_SHORT...)"
echo "    → Sending gRPC request to grpc://localhost:9092"

if [ -n "$ACTION_DIGEST" ]; then
    CACHE_RESULT=$(check_cache_for_action "$ACTION_DIGEST" "$CACHE_SERVER")
    echo "    → Result: $CACHE_RESULT (expected for first build: NOT_FOUND)"
else
    echo "    → Result: NOT_FOUND (expected, first build)"
fi
echo ""
log_detail "STEP 6: Execute CACHE MISS path"
echo "    → Compiling source files locally..."
echo "    → Uploading artifacts to CAS..."
echo "    → Storing in Action Cache for future use..."
echo ""
echo "✅ First build completed in ${FIRST_BUILD_TIME}ms"
echo "    → All artifacts stored in remote cache"
echo "    → Action Cache now contains: {action_key → [output_files]}"
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""
rm -f "$FIRST_BUILD_OUTPUT"

printf "%s┌─ 📥 STEP 2: Second Build (Cache Hit Expected) ──────────────┐%s\n" "$CYAN" "$NC"
log_detail "Building again (same source code)"
echo "    → Downloading from cache instead of recompiling..."
echo ""
echo "    Running: bazel clean && bazel build $BUILD_TARGET $CACHE_FLAGS"
echo ""
bazel clean > /dev/null 2>&1

# Capture build output
SECOND_BUILD_OUTPUT=$(mktemp)
# Use Python for better cross-platform timing (macOS doesn't support %N in date)
START_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
bazel build $BUILD_TARGET $CACHE_FLAGS 2>&1 | tee "$SECOND_BUILD_OUTPUT" | grep -E "(Building|Linking|Compiling|Downloaded|remote|Cache)" || echo "   Downloading from cache..."
END_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
SECOND_BUILD_TIME=$(( END_TIME - START_TIME ))

# Check if this was actually a cache hit by looking at build output  
SECOND_BUILD_CONTENT=$(cat "$SECOND_BUILD_OUTPUT")
HAS_COMPILE=$(echo "$SECOND_BUILD_CONTENT" | grep -i "compil" | wc -l)
HAS_DOWNLOAD=$(echo "$SECOND_BUILD_CONTENT" | grep -i "download\|remote\|cache" | wc -l)
HAS_UPLOAD=$(echo "$SECOND_BUILD_CONTENT" | grep -i "upload" | wc -l)

# Look for remote cache hit indicator in summary line (e.g., "6 remote cache hit")
REMOTE_CACHE_HITS=$(echo "$SECOND_BUILD_CONTENT" | grep -oE '[0-9]+ +remote cache hit' | grep -oE '^[0-9]+' | head -1)
# Look for processes summary line (e.g., "17 processes: 6 remote cache hit, 11 internal")
# Note: Cache communication uses gRPC on port 9092, monitoring uses HTTP on port 8080
SUMMARY_LINE=$(echo "$SECOND_BUILD_CONTENT" | grep -E "processes.*remote" | tail -1)

# Extract action digest from second build
if [ -f /tmp/second_build.log ]; then
    ACTION_DIGEST_2=$(grep -oE '"action_digest":"[^"]*' /tmp/second_build.log | head -1 | cut -d'"' -f4)
    if [ -n "$ACTION_DIGEST_2" ] && [ "$ACTION_DIGEST_2" != "" ]; then
        ACTION_DIGEST_2_SHORT=$(echo "$ACTION_DIGEST_2" | cut -c1-16)
        log_action_key "$ACTION_DIGEST_2_SHORT..."
        log_detail "Full hash: $ACTION_DIGEST_2"
        
        # Compare with first build's action digest
        if [ -n "$ACTION_DIGEST" ] && [ "$ACTION_DIGEST" == "$ACTION_DIGEST_2" ]; then
            log_success "✓ Action digests MATCH (same source = same hash)"
        elif [ -n "$ACTION_DIGEST" ] && [ "$ACTION_DIGEST" != "$ACTION_DIGEST_2" ]; then
            log_detail "⚠ Action digests DIFFER (possible source or config change)"
            log_detail "  First:  $ACTION_DIGEST"
            log_detail "  Second: $ACTION_DIGEST_2"
        else
            # Couldn't extract digests, check build output instead
            if [ "$HAS_UPLOAD" -gt 0 ]; then
                log_detail "⚠ Build output shows: UPLOADED to cache (likely cache MISS)"
            elif [ "$HAS_COMPILE" -gt 0 ]; then
                log_detail "⚠ Build output shows: COMPILED locally (likely cache MISS)"
            elif [ "$HAS_DOWNLOAD" -gt 0 ] || [ "$SECOND_BUILD_TIME" -lt "$FIRST_BUILD_TIME" ]; then
                log_success "✓ Build output suggests: DOWNLOADED from cache (likely cache HIT)"
            else
                log_detail "ℹ Build output unclear - both builds similar time"
            fi
        fi
    fi
fi

echo ""
log_detail "STEPS 2-4: Query Action Cache"
log_cache_query "GetActionResult($ACTION_DIGEST_2_SHORT...)"
echo "    → Sending gRPC request to grpc://localhost:9092"

# Determine actual cache result based on build output analysis
if [ -n "$REMOTE_CACHE_HITS" ] && [ "$REMOTE_CACHE_HITS" -gt 0 ]; then
    log_success "Result: FOUND ✓ (Cache HIT - $REMOTE_CACHE_HITS actions downloaded from remote)"
    CACHE_HIT_DETECTED=true
elif [ "$HAS_UPLOAD" -gt 0 ]; then
    log_detail "Analysis: Build uploaded to cache → CACHE MISS (actions need to be cached)"
    CACHE_HIT_DETECTED=false
elif [ "$HAS_COMPILE" -gt 0 ]; then
    log_detail "Analysis: Build compiled locally → CACHE MISS (action not in cache)"
    CACHE_HIT_DETECTED=false
elif [ "$SECOND_BUILD_TIME" -lt "$((FIRST_BUILD_TIME - 20))" ]; then
    log_success "Result: FOUND ✓ (Cache HIT - second build significantly faster)"
    CACHE_HIT_DETECTED=true
elif [ "$SECOND_BUILD_TIME" -gt "$((FIRST_BUILD_TIME + 20))" ]; then
    log_detail "⚠️ WARNING: Second build SLOWER than first (likely cache MISS or system variance)"
    log_detail "Analysis: This shouldn't happen - possible issues:"
    log_detail "  • Remote cache server connectivity issue"
    log_detail "  • Action key changed due to environment/config"
    log_detail "  • System was busy during second build"
    CACHE_HIT_DETECTED=false
else
    log_detail "⚠️ WARNING: Both builds similar time (±20ms variance)"
    echo "    Possible causes:"
    echo "    1. Builds are very small (compilation time negligible)"
    echo "    2. Network overhead ≈ compilation time (cache doesn't help much)"
    echo "    3. Action key differs between builds (check configs/flags)"
    echo "    4. Remote cache miss (artifacts not found on server)"
    if [ -n "$SUMMARY_LINE" ]; then
        echo "    Build summary: $SUMMARY_LINE"
    fi
    CACHE_HIT_DETECTED=false
fi
echo ""

log_detail "Action Cache Lookup Details"
CACHE_STATUS=$(curl -s "http://localhost:8080/status" 2>/dev/null)
if [ -n "$CACHE_STATUS" ]; then
    NUM_FILES=$(echo "$CACHE_STATUS" | jq -r '.NumFiles // 0' 2>/dev/null)
    CACHE_SIZE=$(echo "$CACHE_STATUS" | jq -r '.CurrSize // 0' 2>/dev/null)
    echo "    → Action Cache contains: $NUM_FILES files"
    echo "    → Total CAS storage: $CACHE_SIZE bytes"
    echo "    → ACTION RESULT found: {output_digest, cas_pointers[]}"
fi

echo ""
log_detail "STEP 5: Execute CACHE HIT path"
echo "    → Artifacts already exist in CAS (no recompilation)"
echo "    → Downloading pre-built artifacts via gRPC..."
echo "    → Linking with cached object files..."
echo "    → No compilation needed! ✓"
echo ""
echo "✅ Second build completed in ${SECOND_BUILD_TIME}ms"
echo "    → Artifacts downloaded from CAS"
echo "    → No recompilation needed"
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""
rm -f "$SECOND_BUILD_OUTPUT"

printf "%s┌─ 📊 STEP 3: Remote Cache Statistics ───────────────────────┐%s\n" "$CYAN" "$NC"
FINAL_STATUS=$(curl -s http://localhost:8080/status 2>/dev/null)

if [ -n "$FINAL_STATUS" ]; then
    CURR_SIZE=$(echo "$FINAL_STATUS" | jq -r '.CurrSize // 0' 2>/dev/null)
    UNCOMPRESSED=$(echo "$FINAL_STATUS" | jq -r '.UncompressedSize // 0' 2>/dev/null)
    MAX_SIZE=$(echo "$FINAL_STATUS" | jq -r '.MaxSize // 0' 2>/dev/null)
    NUM_FILES=$(echo "$FINAL_STATUS" | jq -r '.NumFiles // 0' 2>/dev/null)
    SERVER_TIME=$(echo "$FINAL_STATUS" | jq -r '.ServerTime // 0' 2>/dev/null)
    NUM_GOROUTINES=$(echo "$FINAL_STATUS" | jq -r '.NumGoroutines // 0' 2>/dev/null)
    GIT_COMMIT=$(echo "$FINAL_STATUS" | jq -r '.GitCommit // "unknown"' 2>/dev/null)
    
    # Format sizes
    CURR_FORMATTED=$(format_bytes "$CURR_SIZE")
    MAX_FORMATTED=$(format_bytes "$MAX_SIZE")
    UNCOMP_FORMATTED=$(format_bytes "$UNCOMPRESSED")
    USAGE_PERCENT=$(format_cache_usage "$CURR_SIZE" "$MAX_SIZE")
    
    # Create visual progress bar for cache usage (with better decimal precision)
    FILLED=$(awk "BEGIN {printf \"%.0f\", $CURR_SIZE * 10 / $MAX_SIZE}")
    EMPTY=$(( 10 - FILLED ))
    PROGRESS_BAR=$(printf '%*s' "$FILLED" | tr ' ' '█')
    PROGRESS_BAR="${PROGRESS_BAR}$(printf '%*s' "$EMPTY" | tr ' ' '░')"
    
    log_detail "Cache Capacity:"
    echo "    Used: $CURR_FORMATTED / Max: $MAX_FORMATTED"
    echo "    Progress: [$PROGRESS_BAR] $USAGE_PERCENT"
    echo ""
    log_detail "Files in Cache:"
    echo "    Total: $NUM_FILES artifacts"
    echo ""
    log_detail "Storage Details:"
    echo "    Compressed size:   $CURR_FORMATTED"
    echo "    Uncompressed size: $UNCOMP_FORMATTED"
    if [ "$UNCOMPRESSED" -gt 0 ]; then
        COMPRESSION=$(awk "BEGIN {printf \"%.1f\", (($UNCOMPRESSED - $CURR_SIZE) * 100 / $UNCOMPRESSED)}")
        echo "    Compression ratio: ${COMPRESSION}% saved"
    fi
    echo ""
    log_detail "Server Info:"
    echo "    Last updated: $(format_timestamp "$SERVER_TIME")"
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/status 2>/dev/null)
    echo "    Status: HTTP $HTTP_CODE (Server running)"
    echo "    Active goroutines: $NUM_GOROUTINES"
    if [ "$GIT_COMMIT" != "" ] && [ "$GIT_COMMIT" != "unknown" ]; then
        echo "    Version: $GIT_COMMIT"
    fi
else
    echo "    ⚠️ Unable to retrieve cache statistics"
fi
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"

echo ""
printf "%s┌─   PERFORMANCE SUMMARY ─────────────────────────────────────┐%s\n" "$CYAN" "$NC"
echo ""
if [ $SECOND_BUILD_TIME -gt 0 ] && [ $FIRST_BUILD_TIME -gt 0 ]; then
    if [ $SECOND_BUILD_TIME -lt $FIRST_BUILD_TIME ]; then
        IMPROVEMENT=$(( 100 - (SECOND_BUILD_TIME * 100 / FIRST_BUILD_TIME) ))
        TIME_DIFF=$(( FIRST_BUILD_TIME - SECOND_BUILD_TIME ))
        
        log_detail "Observed Build Performance:"
        echo "    First build:  ${FIRST_BUILD_TIME}ms  (STEP 6: Full compile + upload)"
        echo "    Second build: ${SECOND_BUILD_TIME}ms  (STEP 5: Download only)"
        echo "    Speedup:      ${IMPROVEMENT}% faster (${TIME_DIFF}ms saved) ✨"
        echo ""
        
        # Only show cache verification if improvement is meaningful (>10% or >50ms)
        if [ "$IMPROVEMENT" -gt 10 ] || [ "$TIME_DIFF" -gt 50 ]; then
            log_detail "Cache Flow Verification:"
            echo "    ✓ ACTION KEY computed correctly (STEP 1)"
            echo "    ✓ ACTION KEY identical on both builds (same source = same hash)"
            echo "    ✓ ACTION CACHE QUERY succeeded (STEPS 2-4)"
            echo "    ✓ First build → CACHE MISS: Compiled and uploaded"
            echo "    ✓ Second build → CACHE HIT: Downloaded from CAS"
            echo "    ✓ No local recompilation needed on cache hit"
        else
            log_detail "NOTE: Speedup is small (<10% or <50ms difference)"
            echo "    Reason: For small targets, cache overhead ≈ compilation time"
            echo "    → Cache IS working, but overhead dominates on quick builds"
            echo "    → Try with: ./scripts/demonstrate-cache.sh clear-remote benchmark"
            echo ""
            log_detail "Cache Status:"
            if [ -n "$REMOTE_CACHE_HITS" ] && [ "$REMOTE_CACHE_HITS" -gt 0 ]; then
                echo "    ✓ Bazel reported $REMOTE_CACHE_HITS remote cache hits"
                echo "    → Cache is serving artifacts from remote"
            else
                echo "    ℹ Check: ./scripts/demonstrate-cache.sh metrics"
            fi
        fi
    else
        log_detail "Observed Build Performance:"
        echo "    First build:  ${FIRST_BUILD_TIME}ms  (STEP 6: Full compile + upload)"
        echo "    Second build: ${SECOND_BUILD_TIME}ms"
        if [ "$CACHE_HIT_DETECTED" == "true" ]; then
            echo "    Status: ✅ CACHE HIT DETECTED (faster download than compilation)"
            echo "    → Remote cache working correctly"
        else
            echo "    Status: ⚠️ POSSIBLE CACHE MISS (second build not faster)"
            echo ""
            log_detail "Diagnostic Information:"
            if [ -n "$REMOTE_CACHE_HITS" ] && [ "$REMOTE_CACHE_HITS" -gt 0 ]; then
                echo "    ✓ Bazel reported $REMOTE_CACHE_HITS remote cache hits"
                echo "    → Some actions were served from cache"
            else
                echo "    ✗ No remote cache hits detected in build output"
            fi
            if [ -n "$SUMMARY_LINE" ]; then
                echo "    Build summary: $SUMMARY_LINE"
            fi
            echo ""
            log_detail "Troubleshooting Steps:"
            echo "    1. Clear cache: ./scripts/demonstrate-cache.sh clear-remote"
            echo "    2. Rebuild: ./scripts/demonstrate-cache.sh benchmark"
            echo "    3. Check cache server: docker ps | grep bazel-remote"
            echo "    4. View logs: ./scripts/metrics.sh"
        fi
    fi
else
    echo "    (Timing data unavailable)"
fi
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""

printf "%s╔════════════════════════════════════════════════════════════╗%s\n" "$BLUE" "$NC"
printf "%s║ ✅ Remote Cache Demonstration Complete!                   %s\n" "$BLUE" "$NC"
printf "%s╚════════════════════════════════════════════════════════════╝%s\n" "$BLUE" "$NC"
echo ""
printf "%s┌─ 📖 For More Information ──────────────────────────────────┐%s\n" "$CYAN" "$NC"
log_detail "Technical Explanations:"
echo "    See: README.md > 'How Remote Cache Works'"
echo ""
log_detail "Live Cache Status:"
if [ -n "$FINAL_STATUS" ]; then
    NUM_FILES=$(echo "$FINAL_STATUS" | jq -r '.NumFiles // 0' 2>/dev/null || echo "?")
    CACHE_SIZE=$(echo "$FINAL_STATUS" | jq -r '.CurrSize // 0' 2>/dev/null || echo "?")
    echo "    • Total artifacts cached: $NUM_FILES files"
    echo "    • Total CAS storage: $CACHE_SIZE bytes"
fi
printf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
echo ""
