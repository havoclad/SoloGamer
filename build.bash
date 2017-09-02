#!/usr/local/bin/bash

rm -rf docker/in/*
tar -czf docker/in/perl.tar.gz perl
tar -czf docker/in/data.tar.gz data
docker build -t "havoclad/b17" docker
