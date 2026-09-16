# Contributing to Bazel Remote Build Example

Thank you for contributing! This document provides guidelines for working with this project.

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone https://github.com/iakshayubale/bazel-infra-lab.git
   cd bazel-infra-lab
   ./scripts/setup.sh
   ```

2. **Start bazel-remote cache server:**
   ```bash
   cd infrastructure/docker
   docker-compose up -d      # Start bazel-remote cache
   ```

3. **Build and test:**
   ```bash
   bazel build //...                              # Build all targets
   bazel test //...                               # Run all tests
   bazel build --config=remote-cache //app:hello # Build with remote caching
   ```

4. **View metrics:**
   ```bash
   ./scripts/metrics.sh
   ```

## Development Workflow

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes:**
   - Modify source files in `lib/` or `app/`
   - Update BUILD files if adding new targets
   - Add tests for new functionality

3. **Build and test locally:**
   ```bash
   bazel build //lib:my_lib
   bazel test //lib:my_lib_test
   ```

4. **Test with remote caching:**
   ```bash
   bazel build --config=remote-cache //lib:my_lib
   ```

5. **Commit with meaningful message:**
   ```bash
   git commit -m "Add feature: description of change"
   ```

6. **Push and create PR:**
   ```bash
   git push origin feature/my-feature
   ```

## Code Style

### C++ Code

- Follow Google C++ Style Guide
- Use `.cc` extension for implementation, `.h` for headers
- 2-space indentation
- 80-character line limit (soft)

Example:
```cpp
#include "lib/math.h"

namespace math {

int Add(int a, int b) {
  return a + b;
}

}  // namespace math
```

### BUILD Files

- One target per `cc_library()`, `cc_binary()`, or `cc_test()`
- Group related deps together
- Use meaningful target names
- Always include visibility constraints

Example:
```python
cc_library(
    name = "mylib",
    srcs = ["mylib.cc"],
    hdrs = ["mylib.h"],
    copts = ["-Wall", "-Werror"],
    deps = ["//other:lib"],
    visibility = ["//visibility:public"],
)
```

## Testing

### Writing Tests

- Use Google Test (gtest) framework
- File naming: `{module}_test.cc`
- Test class naming: `{ModuleName}Test`
- Test method naming: `Test{Feature}`

Example:
```cpp
#include "lib/math.h"
#include <gtest/gtest.h>

namespace math {

TEST(MathTest, AddPositives) {
  EXPECT_EQ(Add(2, 3), 5);
}

}  // namespace math
```

### Running Tests

```bash
# Run all tests
bazel test //...

# Run specific test
bazel test //lib:math_test

# Run with verbose output
bazel test --test_output=all //lib:math_test
```

## Documentation

### README.md Updates

- Keep high-level overview current
- Update quick start if default commands change
- Link to detailed docs in `docs/` directory

### Adding Documentation

1. Create file in `docs/` directory
2. Use Markdown format
3. Include code examples where applicable
4. Link from relevant places

Example locations for new docs:
- **Setup guides**: `docs/setup-{platform}.md`
- **How-to guides**: `docs/howto-{feature}.md`
- **Configuration**: `docs/config-{component}.md`

## Building Documentation Locally

```bash
# View README
cat README.md

# View documentation directory
ls -la docs/

# Common docs:
# - docs/local-setup.md       - Local development setup
# - docs/best-practices.md    - Performance optimization
```

## Bazel Configuration

### Using Different Configurations

- **Local builds** (no remote): `--config=local`
- **Remote caching only**: `--config=remote-cache`
- **Full remote execution**: `--config=remote`
- **CI/CD**: `--config=ci`

### Custom .bazelrc

Create `.bazelrc.local` for machine-specific settings:
```bash
# Local overrides (not committed)
common --disk_cache=/custom/cache/path
common --color=yes
```

## bazel-remote Cache Management

### Start/Stop

```bash
# Start bazel-remote cache server
cd infrastructure/docker && docker-compose up -d

# Stop bazel-remote cache server
cd infrastructure/docker && docker-compose down

# View logs
cd infrastructure/docker && docker-compose logs -f

# Check status
curl http://localhost:8080/status | jq .
```

### Resetting Cache

```bash
# Clear all caches and restart
cd infrastructure/docker && docker-compose down
cd infrastructure/docker && docker-compose up -d

# Or use the demonstration script
./scripts/demonstrate-cache.sh clear-remote
```

## Performance

### Before Committing

Check these metrics:
```bash
# View cache status
./scripts/metrics.sh

# Build locally (no cache)
time bazel build --config=local //...

# Build with bazel-remote caching
time bazel build --config=remote-cache //...

# Expected improvement: 3-10x faster on incremental builds
```

### Profiling a Build

```bash
bazel build --profile=/tmp/profile.gz //app:hello
bazel analyze-profile /tmp/profile.gz
```

## CI/CD Pipeline

This project uses GitHub Actions (see `.github/workflows/bazel-ci.yml`).

### What the CI does

- Builds with remote caching (via bazel-remote)
- Runs full test suite
- Generates performance reports
- Uploads artifacts

### Running CI Locally

```bash
# Simulate CI build with remote cache
bazel build --config=remote-cache --test_output=short //...

# Or with full remote execution (if BuildBuddy enabled)
bazel build --config=remote --test_output=short //...
```

## Troubleshooting

### Common Issues

**bazel-remote cache not responding?**
```bash
cd infrastructure/docker
docker-compose ps
docker-compose logs
docker-compose restart
```

**Bazel cache issues?**
```bash
bazel clean --expunge
rm -rf .bazel-cache
cd infrastructure/docker && docker-compose restart
```

**Tests failing locally but passing in CI?**
- Check `.bazelrc` configuration
- Compare local vs CI environment
- Use `--verbose_failures` for more detail

## Reporting Bugs

Please include:
1. Environment: OS, Bazel version, Docker version
2. Steps to reproduce
3. Expected vs actual behavior
4. Relevant logs: `docker-compose logs`, `bazel clean` output

## Feature Requests

When proposing new features:
1. Describe use case and benefit
2. Consider performance impact
3. Discuss implementation approach
4. Check for similar existing features

## Pull Request Process

1. **Before PR:**
   - Code follows style guidelines
   - Tests added and passing
   - Documentation updated
   - No unnecessary dependencies added

2. **PR Description:**
   ```markdown
   ## Description
   Brief description of changes.
   
   ## Related Issue
   Fixes #123
   
   ## Testing
   - [ ] Local build passes
   - [ ] Tests pass
   - [ ] Remote caching tested
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] No build warnings
   ```

3. **Code Review:**
   - Automated checks must pass
   - At least one approval required
   - Address all comments

4. **Merge:**
   - Use "Squash and merge" for clean history
   - Delete feature branch after merge

## Project Structure

```
.
├── README.md                    # Project overview
├── WORKSPACE                    # Bazel workspace
├── BUILD                        # Root build config
├── .bazelrc                     # Build configuration (remote cache settings)
├── MODULE.bazel                 # Bazel modules
│
├── lib/                         # Library code
│   ├── BUILD
│   ├── math.h
│   ├── math.cc
│   ├── math_test.cc
│
├── app/                         # Application
│   ├── BUILD
│   ├── main.cc
│   ├── hello.h
│   ├── hello.cc
│   ├── hello_test.cc
│
├── infrastructure/              # Deployment configs
│   ├── docker/
│   │   ├── docker-compose.yml   # bazel-remote service definition
│   │   └── Dockerfile          # bazel-remote image build
│   └── buildbuddy/
│       └── config.yaml          # (Reference only - not used in POC)
│
├── scripts/                     # Automation scripts
│   ├── setup.sh
│   ├── cleanup.sh
│   ├── metrics.sh
│   └── demonstrate-cache.sh
│
├── docs/                        # Documentation
│   ├── local-setup.md
│   ├── best-practices.md
│
└── .github/
    └── workflows/
        └── bazel-ci.yml         # CI/CD pipeline
```

## Resources

- [Bazel Documentation](https://bazel.build/docs)
- [bazel-remote GitHub](https://github.com/buchgr/bazel-remote)
- [Google Test Documentation](https://google.github.io/googletest/)
- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)

## Questions?

- Check existing issues/discussions
- Review documentation in `docs/` directory
- Review similar examples in repository

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT).

---

Thank you for contributing to making this project better! 🎉
