# Quick Start Guide

## Start BuildBuddy

```bash
cd infrastructure/docker
docker-compose up -d
```

Visit dashboard: http://localhost:8086

## Build with Remote Caching

```bash
# First build (populates cache)
bazel build --config=remote-cache //app:hello

# Second build (instant from cache)
bazel build --config=remote-cache //app:hello
```

## Run Tests

```bash
bazel test --config=remote-cache //...
```

## View Build Metrics

- Dashboard: http://localhost:8086
- Check "Invocations" tab for build history
- Check cache hit rates

## Full Remote Execution

For distributed builds (requires multiple executor nodes):

```bash
bazel build --config=remote //app:hello
```

## Troubleshooting

BuildBuddy not responding?
```bash
docker-compose ps
docker-compose logs
```

See docs/ for detailed guides on:
- Local setup
- Best practices

## Next Steps

1. Read `docs/local-setup.md` for detailed configuration
2. Read `docs/best-practices.md` for optimization tips
