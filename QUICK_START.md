# Quick Start Guide

## Start bazel-remote Cache Server

```bash
cd infrastructure/docker
docker-compose up -d
curl http://localhost:8080/status | jq .
```

## Build with Remote Caching

```bash
# First build (populates cache)
bazel build //app:hello --config=remote-cache

# Second build (instant from cache)
bazel build //app:hello --config=remote-cache
```

## Or use the demonstration script (easier!)

```bash
./scripts/demonstrate-cache.sh
```

This script handles all the cache flags and shows cache hits/misses in real time.

## View Cache Metrics

```bash
curl http://localhost:8080/status | jq .
./scripts/metrics.sh
```

See docs/ for detailed guides on:
- Local setup
- Best practices

## Next Steps

1. Read `docs/local-setup.md` for detailed configuration
2. Read `docs/best-practices.md` for optimization tips
