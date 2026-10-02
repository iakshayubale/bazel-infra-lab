# Docker Image Publishing

To avoid rebuilding the dev container every time, we publish pre-built images to GitHub Container Registry (ghcr.io) where they're **public by default** - no authentication needed to pull!

## Quick Start - Use Pre-Built Image (No Auth Needed!)

```bash
# Pull and run the latest published image
docker pull ghcr.io/iakshayubale/bazel-infra-lab:latest

# Or use with docker-compose
cd infrastructure/docker
docker-compose -f docker-compose.bazel-infra-lab.yml run dev bash

# Start developing immediately - no build needed!
cd /workspace
bazel build //app:hello --config=remote-cache
```

**That's it!** No login, no tokens, no build time. Just works. ✅

## Publishing a New Image (For Maintainers)

### 1. Set Up GitHub Token (One-Time)

```bash
# Create a GitHub Personal Access Token with `write:packages` permission:
# https://github.com/settings/tokens
# Then export it:
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

### 2. Push New Version

```bash
./scripts/publish-image.sh latest
# Or with version tag:
./scripts/publish-image.sh 9.2.0
```

This will:
- Build the dev container
- Tag as `ghcr.io/iakshayubale/bazel-infra-lab:latest`
- Push to GitHub Container Registry

### 3. Done! Everyone Can Use It

No more waiting for builds. Developers just pull:

```bash
docker-compose -f docker-compose.bazel-infra-lab.yml run dev bash
```

## Why GitHub Container Registry?

| Feature | Docker Hub | GitHub Container Registry |
|---------|-----------|---------------------------|
| **Public images auth** | Required (login) | ✅ **None needed** |
| **Build & push** | Requires Docker Hub account | ✅ Only GitHub account |
| **For public repos** | Requires paid plan for unlimited pulls | ✅ **Always free** |
| **Storage** | 1 free private repo | ✅ Unlimited free for public repos |
| **Integration** | Manual | ✅ Works with GitHub Actions |

## Workflow for Teams

**Maintainer (first time):**
```bash
export GITHUB_TOKEN=ghp_xxxx
./scripts/publish-image.sh latest
```

**Everyone else (every time):**
```bash
# No auth needed!
docker-compose -f docker-compose.prod.yml run dev bash
```

Saves 2-3 minutes per developer per day! 🚀

## Automatic Publishing (GitHub Actions)

Add `.github/workflows/publish-docker.yml`:

```yaml
name: Publish Container Image
on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/docker/**'
      - '.github/workflows/publish-docker.yml'

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v3
      
      - uses: docker/setup-buildx-action@v2
      
      - uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - uses: docker/build-push-action@v4
        with:
          context: infrastructure/docker
          file: infrastructure/docker/Dockerfile.bazel-infra-lab
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/bazel-infra-lab:latest
            ghcr.io/${{ github.repository_owner }}/bazel-infra-lab:${{ github.sha }}
```

This automatically publishes whenever infrastructure changes!

## Verify Published Image

```bash
# Check what's available
docker search ghcr.io/iakshayubale/bazel-infra-lab

# Pull specific version
docker pull ghcr.io/iakshayubale/bazel-infra-lab:9.2.0

# View image info
docker inspect ghcr.io/iakshayubale/bazel-infra-lab:latest | jq '.[].RepoTags'
```
