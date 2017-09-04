#!/usr/local/bin/bash

rm -rf docker/in/*
tar -czf docker/in/perl.tar.gz perl
docker build -t "havoclad/b17" docker
