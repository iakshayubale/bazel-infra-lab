# Understanding Bazel Remote Cache

> **Status**: This explains cache behavior verified in the POC. Concepts and terms used throughout this project.

## What Gets Cached?

Bazel's remote cache stores:
1. **Action Cache**: Build action results (which outputs correspond to which inputs)
2. **Content Addressable Storage (CAS)**: Actual compiled artifacts (object files, libraries, binaries)

## Local vs Remote Cache

### Local Cache (`bazel clean`)
```bash
bazel clean
```
- **Clears**: Bazel's local build cache in `~/.cache/bazel/`
- **Keeps**: Remote cache server intact
- **Next build**: Downloads from remote cache if available

### Remote Cache (on server at localhost:8085)
- **Persists**: Even after `bazel clean`
- **Shared**: Accessible across multiple builds and developers
- **Cleared with**: `./scripts/demonstrate-cache.sh clear-remote`

## Cache Hit vs Cache Miss

### Cache Miss (First Build)
```
bazel build //app:hello
↓
1. Compiles all files
2. Uploads artifacts to remote cache
3. Time: ~1000ms (full compilation)
```

### Cache Hit (Second Build - No Code Changes)
```
bazel build //app:hello
↓
1. Checks remote cache for artifacts
2. Downloads pre-compiled artifacts
3. Only links final binary
4. Time: ~100-200ms (only linking)
```

## Why Is Second Build Still Slow After Code Changes?

If you change the source code between builds:

```
1st build: File hello.cc → compiles → uploads to cache
          (time: 1000ms)

CHANGE hello.cc (add print statement)

2nd build: hello.cc (changed!) → recompiles → uploads new version
          (time: ~900ms, only slightly faster)
```

**Why?** Changed files must be recompiled. The cache only helps with **unchanged files**.

## How to Demonstrate Cache Benefits

### Option 1: Show Cache Hits (Recommended)
```bash
# First build: compile everything
./scripts/demonstrate-cache.sh

# Output should show:
#   First build:  1000ms   (full compile + upload)
#   Second build: 150ms    (85% faster - cache hit!)
```

### Option 2: Start From Fresh Remote Cache
```bash
# Clear remote cache completely
./scripts/demonstrate-cache.sh clear-remote

# Then demonstrate cache building up
```

### Option 3: Show Metrics Dashboard First
```bash
# See cache status before and after
./scripts/demonstrate-cache.sh metrics
./scripts/demonstrate-cache.sh metrics clear-remote
```

## Performance Expectations

| Scenario | Time | Why? |
|----------|------|------|
| First build (no cache) | ~1000ms | Full compilation + upload |
| Second build (cache hit) | ~150ms | Download + link only |
| After code change | ~900ms | Recompile changed file + link |
| Parallel builds (4 cores) | ~500ms | More parallelization |

## Cache Storage Location

- **Local**: `~/.cache/bazel/` (cleared by `bazel clean`)
- **Remote**: Docker volume `buildbuddy_cache` (persists across `bazel clean`)
- **Server**: Running at `http://localhost:8085`
- **Max size**: 10GB (configured in docker-compose.yml)

## Troubleshooting

### Cache not being used?
1. Check server: `curl http://localhost:8085/status`
2. Verify config: `cat .bazelrc | grep remote_cache`
3. Clear and retry: `./scripts/demonstrate-cache.sh clear-remote`

### Slow downloads from cache?
1. Check local network speed
2. Verify gRPC connection on port 8085
3. Monitor server logs: `docker-compose logs -f`

## Tips for Best Performance

✅ **Do this:**
- Run builds from the same machine (same local cache)
- Keep source stable for one build cycle
- Use `./scripts/demonstrate-cache.sh metrics` to verify cache is working

❌ **Avoid this:**
- Changing source code between demonstration builds
- Running builds from different machines (local cache varies)
- Interrupting builds mid-compilation
