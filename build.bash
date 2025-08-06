#!/usr/bin/env bash

rm -rf "docker/in/*"
tar -czf "docker/in/perl.tar.gz" perl
tar -czf "docker/in/games.tar.gz"  games
docker build -t "havoclad/sologamer" docker
