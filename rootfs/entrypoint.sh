#!/usr/bin/env sh

if [ "$#" -gt 0 ]; then
  # run (from /usr/local/bin) with the provided params
  exec cross-seed "$@"
else
  # if no params is provided, start s6 container as normal
  exec /init
fi
