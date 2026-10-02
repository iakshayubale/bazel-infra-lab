# Troubleshooting Guide

## Cache Server Not Responding

```bash
# Check if container is running
docker-compose -f infrastructure/docker/docker-compose.bazel-remote-server.yml ps

# Check logs
docker-compose -f infrastructure/docker/docker-compose.bazel-remote-server.yml logs bazel-remote

# Restart server
docker-compose -f infrastructure/docker/docker-compose.bazel-remote-server.yml down
docker-compose -f infrastructure/docker/docker-compose.bazel-remote-server.yml up -d
```

## Build Still Compiles After Cache Upload

- Source files changed between builds -> recompiles modified files only
- Build rule changed -> entire target recompiles
- Toolchain/flags changed -> action key differs -> cache miss
- Use `bazel clean` before second build to test cache hit

## Connection Refused to Ports 9092 or 8080

```bash
# Verify gRPC endpoint (port 9092)
grpcurl -plaintext localhost:9092 list

# Verify HTTP monitoring endpoint (port 8080)
curl http://localhost:8080/status

# Check firewall or port binding
sudo lsof -i :9092 # gRPC
sudo lsof -i :8080 # HTTP
```

## Cache Monitoring from Inside Container

When running curl commands from **inside a dev container**, use the Docker service hostname instead of `localhost`:

```bash
# ❌ WRONG (from inside container)
curl http://localhost:8080/status     # Connects to container itself

# ✅ CORRECT (from inside container)
curl http://bazel-remote:8080/status  # Connects to bazel-remote service

# Example command inside container
curl -s http://bazel-remote:8080/status | jq '.NumFiles, .CurrSize, .UncompressedSize'
```

**Why?** Inside Docker, `localhost` refers to the container itself. To reach other services on the network, use their service name for DNS resolution.

## Issue: "Connection refused" on port 9092

```bash
# Symptom: bazel build fails with "grpc://bazel-remote:9092 connection refused"

# Solution: Verify bazel-remote server is running
docker-compose -f docker-compose.bazel-remote-server.yml logs bazel-remote | tail -20
docker-compose -f docker-compose.bazel-remote-server.yml ps  # Check if bazel-remote is healthy

# If not healthy, check the healthcheck logs:
docker-compose -f docker-compose.bazel-remote-server.yml logs bazel-remote | grep -i "health\|error"

# Restart the server:
docker-compose -f docker-compose.bazel-remote-server.yml restart
```

## Issue: Dev container can't connect to bazel-remote

```bash
# Symptom: Inside dev container, bazel build fails with "connection refused to bazel-remote:9092"

# Solution: Verify both are on same Docker network
docker network inspect docker_bazel-remote-network
# Should show both bazel-remote-server and dev container

# Verify hostname resolution inside container:
docker-compose -f docker-compose.bazel-infra-lab.yml run dev bash
# Inside container:
nslookup bazel-remote
# Should resolve to bazel-remote-server's IP

# If not resolving, restart the server and dev:
docker-compose -f docker-compose.bazel-remote-server.yml down --remove-orphans
docker-compose -f docker-compose.bazel-remote-server.yml up -d
```

## Issue: Cache not being shared between dev containers

```bash
# Symptom: Dev container 2 rebuilds from source instead of hitting cache

# Solution: Verify they're on same Docker network
docker network inspect docker_bazel-remote-network
# Should show: bazel-remote-server and multiple dev containers

# Verify hostname resolution inside dev container:
docker-compose -f docker-compose.bazel-infra-lab.yml run dev bash
# Inside container:
nslookup bazel-remote
# Should resolve to bazel-remote-server's IP

# If not resolving, restart and reconnect:
docker-compose -f docker-compose.bazel-remote-server.yml restart bazel-remote
# Then run a new dev container
docker-compose -f docker-compose.bazel-infra-lab.yml run dev bash
```

## Issue: Persistent cache not surviving server restart

```bash
# Symptom: After docker-compose down, cache is lost

# Solution: Check volume persists
docker volume ls | grep bazel-remote-cache
# Should show: docker_bazel-remote-cache

# Restart server (volume should remount):
docker-compose -f docker-compose.bazel-remote-server.yml up -d

# Verify cache persists (from inside new container):
curl -s http://bazel-remote:8080/status | jq '.NumFiles'
# Should show same or higher count (persistent volume keeps data)
```
