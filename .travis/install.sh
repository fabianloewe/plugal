#!/bin/bash

if [[ $TRAVIS_OS_NAME == "osx" ]]; then
  brew update
  brew install redis
else
  wget http://download.redis.io/redis-stable.tar.gz
  tar xvzf redis-stable.tar.gz
  cd redis-stable
  make
  src/redis-server
fi
