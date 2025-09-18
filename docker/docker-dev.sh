#!/bin/bash

# Development helper script for cpal-evictions Docker Compose setup
# This script provides convenient commands for development and testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

usage() {
    echo "CPAL Evictions Docker Development Helper"
    echo "========================================"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  dev          Start development environment (interactive shell)"
    echo "  build        Build development image"
    echo "  test         Run test suite"
    echo "  script       Run a specific R script"
    echo "  shell        Open shell in development container"
    echo "  clean        Clean up containers and images"
    echo "  logs         Show logs from running containers"
    echo "  status       Show status of containers"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Start development environment"
    echo "  $0 script data-review.R   # Run specific script"
    echo "  $0 test                   # Run all tests"
    echo "  $0 shell                  # Open interactive shell"
    echo ""
}

build_dev() {
    echo "Building development image..."
    docker-compose -f docker/docker-compose.yml build dev
}

start_dev() {
    echo "Starting development environment..."
    docker-compose -f docker/docker-compose.yml up -d dev
    echo "Development environment started. Use '$0 shell' to access the container."
}


run_script() {
    if [ -z "$1" ]; then
        echo "ERROR: Please specify a script to run"
        echo "Available scripts:"
        docker-compose -f docker/docker-compose.yml run --rm analysis
        exit 1
    fi
    
    echo "Running script: $1"
    docker-compose -f docker/docker-compose.yml run --rm analysis "$1"
}

run_tests() {
    echo "Running test suite..."
    docker-compose -f docker/docker-compose.test.yml up --abort-on-container-exit test-runner
}

open_shell() {
    echo "Opening shell in development container..."
    docker-compose -f docker/docker-compose.yml exec dev bash
}

show_logs() {
    docker-compose -f docker/docker-compose.yml logs -f
}

show_status() {
    echo "Container Status:"
    echo "================="
    docker-compose -f docker/docker-compose.yml ps
}

clean_up() {
    echo "Cleaning up containers and images..."
    docker-compose -f docker/docker-compose.yml down --rmi local --volumes --remove-orphans
    docker-compose -f docker/docker-compose.test.yml down --rmi local --volumes --remove-orphans
    echo "Cleanup complete."
}

# Main command handling
case "${1:-}" in
    "dev")
        build_dev
        start_dev
        ;;
    "build")
        build_dev
        ;;
    "test")
        run_tests
        ;;
    "script")
        run_script "$2"
        ;;
    "shell")
        open_shell
        ;;
    "clean")
        clean_up
        ;;
    "logs")
        show_logs
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help"|"")
        usage
        ;;
    *)
        echo "ERROR: Unknown command '$1'"
        echo ""
        usage
        exit 1
        ;;
esac
