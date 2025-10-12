# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SoloGamer is a Perl-based automation engine for solo board games, primarily "B-17 Queen of the Skies". It uses a table-driven architecture with JSON game data files and Moose for object-oriented programming.

## Key Commands

### Build and Run
```bash
# Build the Docker container (required before first run)
./build.bash

# Run the game with Docker
./run.bash                           # Interactive mode
./run.bash --automated               # Automated play
./run.bash --save_file=mysave        # Load specific save
```

### Testing and Code Quality
```bash
# Run the test suite
./test.bash                          # Run all tests (basic usage)
./test.bash --verbose                # Run with verbose output
./test.bash --parallel               # Run tests in parallel
./test.bash --help                   # Show all available options

# Check code quality with Perl::Critic
./critic.bash

# IMPORTANT: Always run tests before committing
./test.bash && git add . && git commit -m "Your commit message"
```

### Common Development Tasks
```bash
# IMPORTANT: After any code changes, rebuild the Docker container!
./build.bash

# Test game with debug output
./run.bash --game=QotS --debug

# Run with verbose logging
./run.bash --info --debug
```

### Development Workflow Reminders
1. **After ANY code changes in perl/ directory**: Always run `./build.bash` before testing
2. **The Docker container caches the code**: Changes won't be visible until rebuild
3. **Workflow**: Edit code → `./build.bash` → `./test.bash` → `./run.bash`

## Architecture Overview

### Core Components
- **SoloGamer.pl**: Main entry point, handles CLI arguments and game initialization
- **SoloGamer::Game**: Central game engine that processes tables and manages state
- **SoloGamer::TableFactory**: Creates appropriate table objects from JSON data
- **Table Types**:
  - `FlowTable`: Controls game flow and branching logic
  - `RollTable`: Handles dice rolls and random events
  - `OnlyIfRollTable`: Conditional tables based on game state

### Key Design Patterns
1. **Moose Roles**: `Logger` and `BufferedOutput` provide cross-cutting functionality
2. **Factory Pattern**: `TableFactory` creates table objects based on JSON type
3. **Variable System**: Game state stored in `$game->{vars}` hash, accessible in tables via `$var_name` syntax
4. **Save System**: Games serialize to JSON in `/saves/` directory (mounted in Docker)

### Game Data Structure
Tables are JSON files in `games/QotS/data/`:
- **FLOW-*.json**: Define game flow sequences
- **G-*.json**: Game tables (missions, targets, etc.)
- **O-*.json**: Operational tables (combat, damage, etc.)

Example table structure:
```json
{
  "type": "roll",
  "dice": "2d6",
  "options": [
    {"result": [2,3], "text": "Result text", "next": "NEXT-TABLE"}
  ]
}
```

## Development Notes

### Adding New Features
1. New table types extend `SoloGamer::Table`
2. Register in `TableFactory::create_table()`
3. Add JSON files to appropriate game directory
4. Test with `--debug` flag to see variable state

### Modifying Game Logic
1. Flow logic is in FLOW-*.json files
2. Variables set with `"set": {"var_name": "value"}` in table options
3. Conditional logic uses `"only_if": "$var_name == value"` syntax
4. Use `--info` flag to trace table execution

### Docker Development
- Perl dependencies are in the Dockerfile
- The container mounts `./saves` for persistent storage
- Build script copies all perl/ content to docker/in/ for building
- Run script handles volume mounting and cleanup

### Testing Infrastructure & TDD Requirements

#### Test-Driven Development Guidelines
- **MANDATORY**: Write tests for ALL bug fixes to prevent regressions
- **REQUIRED**: Include test cases with all new feature development
- **ENFORCED**: Git pre-commit hook automatically runs tests before commits
- **BYPASS**: Use `git commit --no-verify` only in emergencies

#### Current Test Structure
```
t/
├── 00-load.t                    # Module loading verification
├── 03-mission-table-display.t   # Mission table logic tests
└── integration/                 # End-to-end integration tests
    └── 01-full-game-flow.t      # Complete game flow testing
```

#### Writing New Tests
When fixing bugs or adding features:
1. Write the test FIRST (it should fail initially)
2. Implement the fix/feature
3. Ensure the test passes
4. Run full test suite with `./test.bash`
5. Commit only when all tests pass

### Code Quality Standards
- **ALWAYS** run `./test.bash` before commits to ensure all tests pass
- **MANDATORY**: Run `./critic.bash` and fix ALL perlcritic warnings before committing
  - The codebase currently has ZERO perlcritic warnings
  - Keep it that way: any code changes that introduce warnings must be refactored
  - Do not ignore or skip perlcritic warnings
  - If you modify a file, check it with perlcritic and fix any issues
- Follow existing Moose patterns for new modules
- Use roles for shared functionality
- Keep table logic in JSON, not Perl code
- New features must include corresponding test coverage

## Development Principles

- **Always fix warnings before marking a task complete**
- **Zero tolerance for perlcritic warnings**: The codebase is clean, keep it clean
- remember, the build will take around 10 minutes