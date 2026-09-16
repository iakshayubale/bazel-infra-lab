# ============================================================================
# MULTI-STAGE DOCKER BUILD: Optimization for Size & Security
# ============================================================================
# This Dockerfile uses a 2-stage build process:
#
# STAGE 1 (golang:1.21-alpine): BUILDER - Compile bazel-remote from source
#   - Large image (~300MB) with Go compiler, git, build tools
#   - Purpose: Compile bazel-remote source code into a binary
#   - Output: A single compiled executable file
#   - Discarded after: The image, compiler, source code all thrown away
#
# STAGE 2 (alpine:latest): RUNTIME - Run the compiled binary
#   - Tiny image (~5-7MB) with only essential OS tools
#   - Purpose: Execute the bazel-remote binary
#   - Input: Only the compiled binary from Stage 1 (via COPY --from=builder)
#   - Final result: Slim (~15-20MB total) production image
#
# Why two stages? Final image = 15MB instead of 300MB = faster deployment!
# ============================================================================

# ============================================================================
# STAGE 1: BUILDER - Compile bazel-remote from Go source code
# ============================================================================
FROM golang:1.21-alpine as builder

# Set working directory inside the builder container
WORKDIR /workspace

# Clone and compile bazel-remote
# Step 1: Install git (needed for git clone)
# Step 2: Clone bazel-remote repository (v2.4.1 - specific version)
# Step 3: Run "go build" to compile Go source into binary /tmp/bazel-remote
# Note: This binary is ONLY available inside the builder container
RUN apk add --no-cache git && \
    git clone --depth 1 --branch v2.4.1 https://github.com/buchgr/bazel-remote.git . && \
    ls -la && \
    go build -o /tmp/bazel-remote

# ============================================================================
# STAGE 2: RUNTIME - Minimal image with compiled bazel-remote binary
# ============================================================================
# Starting fresh with tiny alpine:latest (completely separate from builder stage)
# Everything from the builder stage above is now DISCARDED
FROM alpine:latest

# Install runtime dependencies only (NOT build tools)
# - ca-certificates: Needed for HTTPS/TLS connections
# - curl: Needed for health checks (curl http://localhost:8085/status)
# - bash: Convenient shell for scripts
# Note: Go compiler is NOT installed here - we don't need it for running bazel-remote
RUN apk add --no-cache ca-certificates curl bash

# ============================================================================
# COPY BINARY FROM BUILDER TO RUNTIME
# ============================================================================
# Syntax: COPY --from=<stage-name> <source-in-that-stage> <destination-in-this-stage>
#
# from the builder stage container, Find /tmp/bazel-remote (the compiled binary)
# Copy it to /usr/local/bin/bazel-remote in THIS alpine container, Everything else from builder stage stays behind and is deleted
#
# Result: This alpine container now has ONLY the binary, not the Go compiler!
COPY --from=builder /tmp/bazel-remote /usr/local/bin/bazel-remote

# Create cache directory for storing bazel artifacts
# /var/bazel-remote/cache = Where all build artifacts are stored (Content Addressable Storage)
# chmod 777 = Allow all processes to read/write to this directory
RUN mkdir -p /var/bazel-remote/cache && chmod 777 /var/bazel-remote/cache

# Expose the gRPC API port
# Port 8085 = Default port for bazel-remote cache server
EXPOSE 8085

# Health check configuration
# Periodically check if bazel-remote is alive using HTTP endpoint
# curl http://localhost:8080/status = Returns JSON with cache stats (HTTP port)
# If this fails 3 times in a row → Docker marks container as unhealthy
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD curl -f http://localhost:8080/status || exit 1

# ============================================================================
# START BAZEL-REMOTE CACHE SERVER
# ============================================================================
# This command runs when the container starts
# Arguments:
#   --dir=/var/bazel-remote/cache = Directory to store all cached artifacts
#   --http_address=0.0.0.0:8080 = HTTP/REST endpoint for monitoring (/status, /health)
#   --grpc_address=0.0.0.0:9092 = gRPC endpoint for Bazel client communication
#   --max_size=10 = Maximum cache size: 10 GB
# 
# When you run: docker-compose up -d
# → Docker starts this container
# → Runs this CMD
# → bazel-remote server starts on:
#    • HTTP: http://localhost:8080 (REST API, monitoring)
#    • gRPC: grpc://localhost:9092 (Bazel client communication)
# → Ready to cache bazel build artifacts!
CMD ["bazel-remote", "--dir=/var/bazel-remote/cache", "--http_address=0.0.0.0:8080", "--grpc_address=0.0.0.0:9092", "--max_size=10"]
