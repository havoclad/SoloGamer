#!/usr/local/bin/bash

docker run -v /Users/pludwig/testing/games:/games -v /Users/pludwig/testing/save:/save -e GAME=QotS --rm -it havoclad/b17
