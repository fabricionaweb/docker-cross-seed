#!/usr/bin/env sh

if [ "$#" -gt 0 ]; then
  # run the application with the provided params
  exec s6-setuidgid $PUID:$PGID node /app/dist/cmd.js "$@"
else
  # if no params is provided, start s6 container as normal
  exec /init
fi
