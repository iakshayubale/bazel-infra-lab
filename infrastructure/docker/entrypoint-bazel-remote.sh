#!/bin/bash
# Entrypoint script for bazel-remote cache server
# Shows welcome message then starts the cache server

# Run welcome script in background
if [ -f /usr/local/bin/welcome ]; then
    bash /usr/local/bin/welcome &
    WELCOME_PID=$!
    sleep 2  # Give welcome message time to display
    wait $WELCOME_PID 2>/dev/null || true
fi

# Start bazel-remote with the provided arguments
exec bazel-remote "$@"
