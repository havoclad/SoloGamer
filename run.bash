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

# Run the docker container with UTF-8 locale
docker run -v "$(pwd)/saves:/app/saves" --rm $INTERACTIVE_FLAGS \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e BANNER_COLOR_SCHEME="${BANNER_COLOR_SCHEME:-4}" \
    havoclad/sologamer --game=QotS "$@"