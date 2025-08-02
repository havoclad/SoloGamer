#!/usr/bin/env bash

# Check if we should run in interactive mode
INTERACTIVE_FLAGS="-it"
for arg in "$@"; do
    if [[ "$arg" == "--automated" ]]; then
        INTERACTIVE_FLAGS=""
        break
    fi
done

# Create saves directory in current location if it doesn't exist
mkdir -p ./saves

# Run the docker container
docker run -v "$(pwd)/saves:/save" --rm $INTERACTIVE_FLAGS havoclad/sologamer --game=QotS "$@"