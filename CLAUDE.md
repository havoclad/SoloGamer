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

# Check code quality with Perl::Critic
./critic.bash
```

### Common Development Tasks
```bash
# Test a specific game table
./run.bash --game=QotS --debug --flow_table=FLOW-start

# Run with verbose logging
./run.bash --info --debug
```

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

### Code Quality
- Run `./critic.bash` before commits
- Follow existing Moose patterns for new modules
- Use roles for shared functionality
- Keep table logic in JSON, not Perl code