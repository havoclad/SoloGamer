#!/usr/bin/env bash

rm -rf "docker/in/*"
tar --exclude='._*' -czf "docker/in/perl.tar.gz" perl
tar --exclude='._*' -czf "docker/in/games.tar.gz"  games
docker build -t "havoclad/sologamer" docker
