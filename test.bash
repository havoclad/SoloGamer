#!/bin/bash

# test.bash - Run Test::Class::Moose tests in Docker container
# Based on the existing run.bash pattern

set -e

# Build the docker image if it doesn't exist or if build is forced
if [ "$1" = "--build" ] || [ "$1" = "-b" ]; then
    echo "Building Docker image..."
    ./build.bash
    shift
fi

# Check if docker image exists
if ! docker image inspect havoclad/sologamer >/dev/null 2>&1; then
    echo "Docker image 'havoclad/sologamer' not found. Building..."
    ./build.bash
fi

# Default test command - run all tests
TEST_CMD="prove -I/t/lib -I/perl -r /t"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            # Verbose output
            TEST_CMD="$TEST_CMD --verbose"
            shift
            ;;
        --parallel|-p)
            # Run tests in parallel
            TEST_CMD="$TEST_CMD --jobs 4"
            shift
            ;;
        --coverage|-c)
            # Run with coverage
            TEST_CMD="cover -test -ignore_re '^t/'"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --build, -b           Build Docker image before running tests"
            echo "  --verbose, -v         Verbose output"
            echo "  --parallel, -p        Run tests in parallel"
            echo "  --coverage, -c        Run with code coverage"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                      # Run all tests"
            echo "  $0 --verbose            # Run tests with verbose output"
            echo "  $0 --parallel           # Run tests in parallel"
            echo "  $0 --coverage           # Run tests with coverage report"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "Running tests with command: $TEST_CMD"
echo "========================================"

# Run the tests in Docker container (suppress Test::Builder warnings)
# Mount the test directory and perl directory
# Use the same volume mounting pattern as run.bash
docker run --rm \
    -v "$(pwd)/t:/t" \
    -v "$(pwd)/perl:/perl" \
    -v "$(pwd)/games:/app/games" \
    -w /app \
    --entrypoint /bin/bash \
    havoclad/sologamer \
    -c "$TEST_CMD"

echo ""
echo "========================================"
echo "Tests completed"