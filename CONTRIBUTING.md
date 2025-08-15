# Contributing to SoloGamer

Thank you for your interest in contributing to SoloGamer! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git switch -c feature-name`

## Development Setup

### Prerequisites
- Docker (for running the game)
- Perl development environment (for local testing)

### Building and Testing

```bash
# Build the Docker container (required after code changes)
./build.bash

# Run tests
./test.bash

# Check code quality
./critic.bash

# Run the game
./run.bash --automated
```

**Important**: Always run `./build.bash` after making code changes, as the Docker container caches the code.

## Development Workflow

1. Make your changes in the `perl/` directory
2. Rebuild: `./build.bash`
3. Test: `./test.bash`
4. Verify: `./run.bash --automated`
5. Check quality: `./critic.bash`

## Submitting Changes

1. Ensure all tests pass: `./test.bash`
2. Commit your changes with a descriptive message
3. Push to your fork
4. Create a pull request

## Code Standards

- Follow existing Moose patterns for new modules
- Use roles for shared functionality
- Keep game logic in JSON files, not Perl code
- Include test coverage for new features
- Fix all warnings before submitting

## Project Architecture

SoloGamer uses a table-driven architecture:
- **Game Engine**: `SoloGamer::Game`
- **Table Types**: `FlowTable`, `RollTable`, `OnlyIfRollTable`
- **Factory Pattern**: `TableFactory` creates tables from JSON
- **Game Data**: JSON files in `games/QotS/data/`

## Questions?

Open an issue for questions about contributing or development setup.