#!/usr/local/bin/bash

docker run --rm -it --entrypoint perlcritic havoclad/sologamer -profile /perl/.perlcriticrc /perl
