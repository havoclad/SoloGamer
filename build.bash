#!/usr/local/bin/bash

rm -rf docker/in/*
tar -czf docker/in/perl.tar.gz perl
tar -czf docker/in/data.tar.gz -C games/QotS data
docker build -t "havoclad/sologamer" docker
