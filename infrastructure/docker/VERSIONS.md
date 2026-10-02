# Docker Build Dependency Versions

This document tracks all pinned versions used in the Docker build to ensure reproducibility across machines.

## Pinned Versions

### Build Stage (Dockerfile)
| Component | Version | Purpose |
|-----------|---------|---------|
| Go (Builder) | 1.21.13 | Compile bazel-remote from source |
| Alpine Linux (Builder) | 3.19 | Lightweight base for Go build environment |
| bazel-remote | v2.4.1 | Remote cache server binary |

### Runtime Stage (Dockerfile)
| Component | Version | Purpose |
|-----------|---------|---------|
| Alpine Linux | 3.19 | Lightweight base for runtime container |
| curl | Latest in 3.19 | Health checks and monitoring |
| bash | Latest in 3.19 | Shell scripting support |
| ca-certificates | Latest in 3.19 | TLS/HTTPS support |

### Local Development Requirements
| Component | Version | Purpose |
|-----------|---------|---------|
| Bazel | 9.2.0+ | Build system |
| Docker | 20.10+ | Container runtime |
| Docker Compose | 1.29+ or v2 | Container orchestration |

### Compose Configuration
| Component | Version | Purpose |
|-----------|---------|---------|
| Docker Compose Spec | 3.8 | Service definition format |

## Why Pin Versions?

**Problem:** Unpinned versions (like `alpine:latest` or `golang:1.21-alpine`) cause:
- Different builds on different machines
- Unpredictable behavior when new versions are released
- Difficulty reproducing build failures
- Inconsistent container images across your team

**Solution:** Pin ALL versions to:
- ✅ Ensure reproducible builds on any machine
- ✅ Allow controlled testing before upgrading
- ✅ Prevent surprise breaking changes
- ✅ Enable consistent CI/CD pipelines

## Updating Versions

To upgrade a component:

1. **Update Dockerfile** - Change the image tags:
   ```dockerfile
   FROM golang:1.22.0-alpine3.19 as builder  # Update Go version
   FROM alpine:3.20  # Update Alpine
   ```

2. **Update docker-compose.bazel-remote-server.yml** - Update the comments with new versions

3. **Test locally:**
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   curl http://localhost:8080/status
   ```

4. **Commit the change** with rationale:
   ```bash
   git commit -m "chore: upgrade Go from 1.21.13 to 1.22.0

   Reason: [security patch | performance improvement | new feature]
   Testing: [what was tested]"
   ```

## Current Container Image Size

- **Build stage:** ~320MB (discarded after compilation)
- **Runtime stage:** ~15-20MB (contains only bazel-remote binary + Alpine)

## Dockerfile Multi-Stage Optimization

This Dockerfile uses two stages to minimize the final image:

```
Stage 1 (BUILDER):
  - golang:1.21.13-alpine3.19 (320MB)
  - Compile bazel-remote → /tmp/bazel-remote
  - DISCARDED

Stage 2 (RUNTIME):
  - alpine:3.19 (only runtime dependencies)
  - COPY --from=builder /tmp/bazel-remote
  - Final image: ~15-20MB
```

Result: **15x smaller image** than keeping builder stage!
