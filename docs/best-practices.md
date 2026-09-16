# Best Practices for Bazel Remote Builds

> **Note**: These are tested strategies referenced from industry experience. The current POC demonstrates basic cache functionality. Advanced strategies (deterministic builds, policy enforcement, etc.) are applicable when scaling beyond this POC.

Tested strategies for maximizing cache hit rates, build performance, and cost efficiency.

## 1. Maximize Cache Hit Rates

### Use Deterministic Builds

Ensure builds are reproducible:

```python
# BUILD file
cc_library(
    name = "mylib",
    srcs = ["lib.cc"],
    # ✅ Good: Explicit dependencies
    deps = ["//other:dep"],
    # ❌ Bad: Implicit dependencies (glob patterns)
    # srcs = glob(["*.cc"]),
)
```

### Pin Dependency Versions

```python
# WORKSPACE
http_archive(
    name = "com_google_absl",
    sha256 = "abc123...",  # ✅ Pin exact version
    urls = ["..."],
)
```

### Avoid Non-Hermetic Rules

Non-hermetic rules (reading system files, network) break caching:

```python
# ❌ Bad: Non-hermetic (reads system date)
genrule(
    name = "timestamp",
    cmd = "date > $@",
    outs = ["timestamp.txt"],
)

# ✅ Good: Hermetic (deterministic input)
genrule(
    name = "version",
    cmd = "echo 'v1.0' > $@",
    outs = ["version.txt"],
)
```

### Use --stamp for Build Metadata

```python
cc_binary(
    name = "app",
    srcs = ["main.cc"],
    stamp = 1,  # Embed build metadata
)
```

```bash
bazel build --stamp //app:app
```

## 2. Optimize Build Configuration

### Use `.bazelrc` Profiles

```bash
# .bazelrc

# Development: fast feedback
config:dev \
    --jobs=auto \
    --keep_state_file \
    --noremote_upload_local_results

# CI: maximum caching
config:ci \
    --config=remote \
    --jobs=200 \
    --remote_upload_local_results

# Performance testing
config:profile \
    --profile=/tmp/profile.gz \
    --explain=explain.txt
```

### Parallel Builds

```bash
# Auto-detect parallelism
bazel build --jobs=auto //...

# Manual tuning (2x CPU cores for remote)
bazel build --jobs=16 //...
```

### Incremental Builds

Keep incremental builds fast:

```bash
# ✅ Good: Small, focused targets
bazel build //lib:math

# ❌ Bad: Build everything
bazel build //...
```

## 3. Remote Execution Strategy

### Use Remote Execution for:

- **Large monorepos**: Significant parallelism benefit
- **Long-running builds**: Offload to dedicated hardware
- **CI/CD pipelines**: Maximize throughput
- **Multi-platform builds**: Different worker pool per platform

### Keep Local Execution for:

- **Small projects**: Network overhead > benefit
- **Rapid iteration**: Cache still hit locally
- **Development with frequent changes**: Lower latency
- **Debugging**: Easier troubleshooting locally

## 4. Cache Strategies

### Shared Cache Server

Deploy bazel-remote as a shared cache for your team:

```bash
# Local development
config:dev \
    --remote_cache=http://localhost:8085 \
    --remote_timeout=3600s \
    --remote_upload_local_results=true

# Shared team cache
config:team \
    --remote_cache=https://bazel-cache.example.com \
    --remote_timeout=3600s \
    --remote_upload_local_results=true
```

### Tiered Caching Strategy

```
Local Disk Cache (fastest, instant)
        ↓
bazel-remote Server (fast, <1s per request)
        ↓
S3/GCS Backend (medium, <10s per request)
```

Configuration:

```bash
# .bazelrc
common --disk_cache=/path/to/local/cache
common --remote_cache=http://bazel-cache.example.com:8085
```

### Cache Invalidation

Clear caches when needed:

```bash
# Local cache only
bazel clean

# Remote cache (via server API)
curl -X DELETE http://localhost:8085/cache/clear
```

## 5. Testing Strategy

### Test Targets Independently

```bash
# ✅ Good: Test in isolation (better caching)
bazel test //lib:math_test
bazel test //app:hello_test

# ❌ Bad: Run all (fails if one is flaky)
bazel test //...
```

### Flaky Test Detection

```bash
# Run tests multiple times to catch flakiness
bazel test --runs_per_test=5 //lib:math_test
```

### Test Timeouts

```python
cc_test(
    name = "math_test",
    srcs = ["math_test.cc"],
    timeout = "short",  # 60s
    # timeout = "medium",  # 300s
    # timeout = "long",    # 900s
)
```

## 6. Performance Monitoring

### Profile Builds

```bash
bazel build --profile=/tmp/profile.gz //app:hello

# Analyze profile
bazel analyze-profile /tmp/profile.gz
```

### Track Cache Metrics

Monitor cache effectiveness:

```bash
# Check cache server status
curl http://localhost:8085/status | jq .

# View metrics
curl http://localhost:8085/metrics

# Key metrics to track:
# - Cache hit rate (target: >70%)
# - Average build time (trends)
# - Cache disk usage (monitor growth)
```

### Build Slowness Analysis

```bash
bazel build --explain=explain.txt //app:hello
cat explain.txt | grep -v "up to date"
```

## 7. Multi-Platform Builds

### Define Platform Constraints

```python
# tools/platforms/BUILD
platform(
    name = "linux_gcc",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//tools/platforms:gcc",
    ],
)

platform(
    name = "macos_clang",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
        "//tools/platforms:clang",
    ],
)
```

### Build for Multiple Platforms

```bash
# Local platform
bazel build //app:hello

# Specific platform
bazel build \
  --platforms=//tools/platforms:linux_gcc \
  //app:hello

# Multiple platforms (CI)
bazel build \
  --platforms=//tools/platforms:linux_gcc \
  --platforms=//tools/platforms:macos_clang \
  //app:hello
```

## 8. Cost Optimization

### Monitor Cache Resource Usage

```bash
# Check cache directory size
du -sh /var/cache/bazel-remote

# Monitor cache server process
ps aux | grep bazel-remote
top -p $(pgrep bazel-remote)

# Check available disk space
df -h /var/cache/
```

### Optimize Cache Size

```bash
# Configure appropriate cache size based on team needs
bazel-remote \
  --dir=/var/cache/bazel-remote \
  --max_size=500  # 500GB for medium teams

# bazel-remote automatically evicts oldest entries when full
```

### Cost Reduction Strategies

1. **Local cache first**: Use disk cache for immediate builds
2. **Remote sharing**: Share cache across team (one server)
3. **Cloud storage**: Use S3/GCS backend for durability without local storage
4. **Aggressive eviction**: Set appropriate max_size to control disk usage

### Monitor Build Performance

Track metrics to optimize spending:

```bash
# Check cache hit rate
curl http://localhost:8085/metrics | grep cache_hits

# Build time trends (use --profile flag)
bazel build --profile=/tmp/profile.gz //...
```

## 9. Security Best Practices

### Network Security

Protect your cache server:

```bash
# Use HTTPS/TLS
--http_address=0.0.0.0:443 \
--tls_cert=/path/to/cert.pem \
--tls_key=/path/to/key.pem
```

### Access Control

```bash
# .bazelrc - restrict to internal networks only
config:prod \
    --remote_cache=https://bazel-cache.internal:8085 \
    --remote_timeout=3600s
```

### Cache Server Security

- Run bazel-remote in isolated container
- Don't expose to public internet
- Use firewall rules to restrict access
- Rotate TLS certificates regularly
- Monitor access logs

### Sensitive Data in Cache

Avoid caching:
- Credentials or API keys in binaries
- Private source code or configuration
- Personally identifiable information (PII)

Use `.bazelignore` or `.gitignore` to exclude sensitive files.

## 10. Common Pitfalls

### ❌ Pitfall: Always-Remote Builds

```bash
# Don't always use remote for small projects
bazel build //small_lib:target --config=remote  # Overkill

# Network overhead > computation benefit
```

### ❌ Pitfall: Non-Hermetic Dependencies

```python
# Don't fetch dependencies at build time
genrule(
    name = "data",
    cmd = "curl http://example.com/data.json > $@",  # ❌
    outs = ["data.json"],
)
```

### ❌ Pitfall: No Cache Invalidation Strategy

Without a strategy, stale cache accumulates.

### ❌ Pitfall: Ignoring Build Metrics

Monitor cache hit rates to identify issues early.

## Quick Checklist

- [ ] All dependencies pinned with exact versions
- [ ] Builds are deterministic (reproducible outputs)
- [ ] No non-hermetic rules (external network calls, system time)
- [ ] `.bazelrc` configured for your use case
- [ ] Cache hit rate > 70%
- [ ] Monitoring/alerting set up
- [ ] API keys stored securely
- [ ] Regular cache maintenance/cleanup
- [ ] Test suite runs in < 5 minutes
- [ ] Documentation updated for new developers

## References

- [Bazel Remote Build Execution](https://bazel.build/remote/rbe)
- [bazel-remote GitHub](https://github.com/buchgr/bazel-remote)
- [Remote Build Execution Protocol](https://github.com/bazelbuild/remote-apis)
- [Cache Best Practices](docs/cache-explanation.md)
