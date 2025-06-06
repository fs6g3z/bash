#!/bin/bash

TEXT="$1"
DIRECTORY="$2"

if [ ! -d "$DIRECTORY" ]; then
  exit 2
fi

sudo grep -rl --exclude-dir={.git,node_modules,vendor} "$TEXT" "$DIRECTORY"
