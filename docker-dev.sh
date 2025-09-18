#!/bin/bash

# Convenience script to run Docker development commands from project root
# This script delegates to the actual docker-dev.sh in the docker/ folder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_SCRIPT="$SCRIPT_DIR/docker/docker-dev.sh"

if [ ! -f "$DOCKER_SCRIPT" ]; then
    echo "ERROR: Docker development script not found at $DOCKER_SCRIPT"
    exit 1
fi

# Pass all arguments to the actual docker-dev.sh script
exec "$DOCKER_SCRIPT" "$@"