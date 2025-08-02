# SoloGamer
Automation for B-17 Queen of the Skies and other similar solo boardgames

## Overview
SoloGamer is a Perl-based automation engine designed to play solo board games, with initial support for "B-17 Queen of the Skies". It features a table-driven architecture using JSON game data files and Moose for object-oriented programming.

## Quick Start

### Build and Run with Helper Scripts
```bash
# Build the Docker container (required before first run)
./build.bash

# Run the game with Docker
./run.bash                           # Interactive mode
./run.bash --automated               # Automated play
./run.bash --save_file=mysave        # Load specific save
```

### Manual Docker Commands
If you prefer to run Docker manually or need more control:

```bash
# Build the image
docker build -t havoclad/sologame -f docker/Dockerfile docker/

# Run interactively with shell access
docker run -it --rm -v "$(pwd)/saves:/app/saves" -v "$(pwd)/perl:/app/perl" --entrypoint /bin/sh havoclad/sologame

# Run the game directly
docker run -it --rm -v "$(pwd)/saves:/app/saves" -v "$(pwd)/perl:/app/perl" havoclad/sologame [options]
```

## Command Line Options

```bash
# Game control
--game=QotS              # Select game (default: QotS)
--automated              # Run in automated mode (no user input)
--save_file=name         # Load a specific save file

# Debugging
--debug                  # Enable debug output (shows variable state)
--info                   # Enable info output (traces table execution)

# Display options
--display=raw            # Output format (default: markdown)
```

## Project Structure

```
.
├── perl/                # Perl source code
│   ├── SoloGamer.pl    # Main entry point
│   └── SoloGamer/      # Game modules
├── games/              # Game data files
│   └── QotS/           # B-17 Queen of the Skies
│       └── data/       # JSON table files
├── saves/              # Save game files (persisted across runs)
├── docker/             # Docker build files
├── build.bash          # Build helper script
├── run.bash            # Run helper script
└── critic.bash         # Code quality checker
```

## Game Data Files

The game logic is defined in JSON files located in `games/QotS/data/`:
- **FLOW-*.json**: Game flow sequences and branching logic
- **G-*.json**: General game tables (missions, targets, etc.)
- **O-*.json**: Operational tables (combat, damage, etc.)

## Save System

Games are automatically saved to the `/saves/` directory, which is mounted as a Docker volume for persistence. Save files are JSON format and can be loaded with the `--save_file` option.

## Development

### Running Perl::Critic
```bash
./critic.bash  # Check code quality
```

### Testing Game Flow
```bash
./run.bash --game=QotS --debug  # Debug mode shows variable state
./run.bash --game=QotS --info   # Info mode traces table execution
```

### Adding New Features
1. New table types should extend `SoloGamer::Table`
2. Register new types in `TableFactory::create_table()`
3. Add corresponding JSON files to the game directory
4. Test with `--debug` to see variable state changes

## Architecture Notes

The system uses:
- **Moose** for OO programming with roles for cross-cutting concerns
- **Factory Pattern** for creating table objects from JSON
- **Variable System** for game state management (`$var_name` syntax in tables)
- **Docker** for consistent runtime environment

See CLAUDE.md for more detailed development notes.
