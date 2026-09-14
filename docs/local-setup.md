# Setup Guide: Local Development with Remote Caching

> **Status**: This guide is tested and verified as part of the POC. Follow these steps to set up remote caching on your local machine using Docker.

This guide walks you through setting up Bazel with remote caching for local development using **bazel-remote** (self-hosted, open-source).

## Prerequisites

- Bazel 5.0+ (`brew install bazel` on macOS, `apt install bazel` on Linux)
- Docker & Docker Compose (for running bazel-remote cache server)
- C++ compiler (gcc or clang)
- curl (for health checks)

## Docker Setup Explained

### Is the Docker Container Pre-Built or Custom?

**Answer: We CREATED IT ourselves!**

We:
1. Write a **recipe** (called `Dockerfile`) that says: "Download bazel-remote source code, compile it, and package it"
2. Every time you run `docker-compose up -d`, Docker follows this recipe to build the container from scratch

**Think of it like:** Recipe book → Ingredients → Cooking → Ready dish 🍳

### How We Create the Docker Container

When Docker builds the container, it follows these steps:

```
STEP 1: Start with a base kitchen (golang:1.21-alpine image)
           ↓
STEP 2: Get the ingredients (clone bazel-remote from GitHub v2.4.1)
           ↓
STEP 3: Cook it (compile bazel-remote using Go compiler)
           ↓
STEP 4: Put it in a smaller container (alpine:latest - lightweight, only 7MB!)
           ↓
STEP 5: Add setup (create /var/bazel-remote/cache directory for storing builds)
           ↓
STEP 6: Add health check (verify container is working every 30 seconds)
           ↓
STEP 7: Start the service (run cache server on port 8085)
```

**The Dockerfile recipe location:** [infrastructure/docker/Dockerfile](../infrastructure/docker/Dockerfile)

**The Configuration file:** [infrastructure/docker/docker-compose.yml](../infrastructure/docker/docker-compose.yml)

### How to Use the Docker Container

#### **Step A: Start the Container (First Time)**

```bash
cd infrastructure/docker
docker-compose up -d
```

This will:
- Read the recipe from `Dockerfile`
- Build the container image
- Start a container named `bazel-remote-server`
- Keep it running in background (`-d` = detached mode)

#### **Step B: Verify It's Running**

```bash
curl http://localhost:8085/status
```

You should see:
```json
{
  "CurrSize": 0,
  "MaxSize": 10737418240,
  "NumFiles": 0
}
```

#### **Step C: Use It for Your Builds**

```bash
bazel build --config=remote-cache //app:hello
```

This will:
- Compile your code locally
- Upload the build result to the cache server (running in Docker)
- Store it for future use or team sharing

**On your second build** (same code):

```bash
bazel clean
bazel build --config=remote-cache //app:hello
```

The container will:
- ✓ Check: "Do I have this cached?"
- ✓ Find it: "Yes! Here it is"
- ✓ Serve it: Download in 50-200ms (vs more compiling time, depends on code size)

#### **Step D: Common Operations**

| What You Want | Command |
|---|---|
| Start container | `cd infrastructure/docker && docker-compose up -d` |
| Check if running | `curl http://localhost:8085/status` |
| View container logs | `docker-compose logs bazel-remote` |
| Stop container | `docker-compose down` |
| Restart container | `docker-compose restart` |
| Rebuild container (if you edit Dockerfile) | `docker-compose build --no-cache && docker-compose up -d` |

### What Gets Stored Inside the Container?

All your cached build artifacts are stored at:
```
/var/bazel-remote/cache  (inside the container)
```

This directory:
- Persists even if you stop/restart the container (it's a Docker volume)
- Can be deleted with `docker-compose down -v` (careful - loses all cache!)
- Grows up to **10 GB** by default (configurable in Dockerfile)

### Visual Flow

```
Your Machine
┌────────────────────────────────────────────────────┐
│  $ bazel build --config=remote-cache //app:hello   │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │ Docker Container                             │  │
│  │                                              │  │
│  │ Service Name: bazel-remote-server            │  │
│  │ Listening on: http://localhost:8085          │  │
│  │ Storage: /var/bazel-remote/cache (10GB max)  │  │
│  │                                              │  │
│  │ ┌──────────────────────────────────────────┐ │  │
│  │ │ bazel-remote cache server (RUNNING)      │ │  │
│  │ │ Ready to serve cached build results      │ │  │
│  │ └──────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘
```

## Step 1: Start Bazel Remote Cache Server

**bazel-remote** is a lightweight, self-hosted, open-source remote cache server. Start it with Docker:

```bash
cd infrastructure/docker
docker-compose up -d
```

Verify it's running:

```bash
curl http://localhost:8085/status
```

The cache server will be available at `http://localhost:8085`

## Step 2: Configure Bazel for Remote Caching

The repository includes a `.bazelrc` configuration file. Verify it points to the cache server:

```bash
cat .bazelrc | grep remote_cache
```

Should show:
```
config:remote-cache \
    --remote_cache=http://localhost:8085 \
    --remote_upload_local_results=true
```

If you need to modify it, edit `.bazelrc`:

```bash
# For local self-hosted bazel-remote:
config:remote-cache \
    --remote_cache=http://localhost:8085 \
    --remote_timeout=3600s \
    --remote_upload_local_results=true
```

## Step 3: Build with Remote Caching

First build (populates cache):

```bash
bazel build --config=remote-cache //app:hello
```

Expected time: 2-5 seconds (depends on machine)

Verify cache server status:

```bash
curl http://localhost:8085/status | jq .
```

Second build (same code, cache hit):

```bash
bazel clean
bazel build --config=remote-cache //app:hello
```

Expected time: 500ms-1s (significantly faster with cache)

## Step 4: Run Tests

```bash
bazel test --config=remote-cache //...
```

## Step 5: View Cache Metrics

Run the metrics dashboard to see cache effectiveness:

```bash
bash scripts/metrics.sh
```

This displays:
- Remote cache server status
- Cache capacity and storage usage
- Build configuration details
- Quick reference commands

## Step 6: Run Interactive Cache Demonstration

See the cache in action with detailed logging:

```bash
bash scripts/demonstrate-cache.sh metrics
```

This shows:
- First build: Full compilation and cache upload
- Second build: Cache hit with only download and linking
- Action key computation and verification
- Performance comparison between builds

## Troubleshooting

### Cache server not responding

```bash
# Check if container is running
docker-compose ps

# View logs
docker-compose logs bazel-remote

# Restart
docker-compose restart
```

### Cache misses on every build

1. Verify `.bazelrc` correctly points to `http://localhost:8085`
2. Check `--remote_upload_local_results=true` is set
3. Ensure `.bazelrc` settings are consistent across rebuilds

```bash
# Debug: Verify remote cache is being used
bazel build --config=remote-cache --remote_build_event_upload_strategy=all //app:hello
```

### Slow builds with remote caching

- Network latency may offset benefits for small projects
- Local builds may be faster if cache server is far away
- For fast iteration: Use local builds with caching enabled

```bash
# Use local config for fastest feedback loop
config:local \
    --noenable_bzlmod \
    --keep_state_file
```

## Next Steps

- **Performance Analysis**: Use `--profile` flag to analyze build bottlenecks
- **CI/CD Integration**: Set up GitHub Actions to populate cache
- **Team Sharing**: Deploy bazel-remote on shared infrastructure (see `docs/production-setup.md`)
- **Monitoring**: Track cache hit rates and storage usage over time

## Additional Resources

- [Bazel Documentation](https://bazel.build/docs)
- [bazel-remote GitHub](https://github.com/buchgr/bazel-remote)
- [Remote Build Execution Protocol](https://github.com/bazelbuild/remote-apis)
- [Cache Explanation](cache-explanation.md) - Detailed cache behavior guide
