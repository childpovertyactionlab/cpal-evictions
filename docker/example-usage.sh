#!/bin/bash

# Example usage script for CPAL Evictions Docker Compose setup
# This script demonstrates common development and testing workflows

set -e

echo "=========================================="
echo "CPAL Evictions Docker Compose Examples"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "docker/docker-compose.yml" ]; then
    echo "ERROR: Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "1. Building the development image..."
echo "-----------------------------------"
docker-compose -f docker/docker-compose.yml build dev

echo ""
echo "2. Starting the development environment..."
echo "------------------------------------------"
docker-compose -f docker/docker-compose.yml up -d dev

echo ""
echo "3. Checking container status..."
echo "-------------------------------"
docker-compose -f docker/docker-compose.yml ps

echo ""
echo "4. Running the test suite..."
echo "----------------------------"
docker-compose -f docker/docker-compose.test.yml up --abort-on-container-exit test-runner

echo ""
echo "5. Listing available R scripts..."
echo "---------------------------------"
docker-compose -f docker/docker-compose.yml run --rm analysis

echo ""
echo "6. Running a sample script (data-review.R)..."
echo "----------------------------------------------"
docker-compose -f docker/docker-compose.yml run --rm analysis data-review.R || echo "Script completed (may have errors, which is expected)"

echo ""
echo "7. Opening an interactive shell..."
echo "----------------------------------"
echo "To open an interactive shell, run:"
echo "  docker-compose -f docker/docker-compose.yml exec dev bash"
echo ""
echo "Or use the helper script:"
echo "  ./docker/docker-dev.sh shell"

echo ""
echo "8. Cleaning up..."
echo "-----------------"
docker-compose -f docker/docker-compose.yml down
docker-compose -f docker/docker-compose.test.yml down

echo ""
echo "=========================================="
echo "Example workflow completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start development: ./docker/docker-dev.sh dev"
echo "2. Open shell: ./docker/docker-dev.sh shell"
echo "3. Run tests: ./docker/docker-dev.sh test"
echo "4. Run scripts: ./docker/docker-dev.sh script [script-name.R]"
echo ""
echo "For more information, see docker/DOCKER_DEVELOPMENT.md"
