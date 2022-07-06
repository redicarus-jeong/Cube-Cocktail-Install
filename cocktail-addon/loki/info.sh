#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 [PLATFORM_ID]"
  exit -1
fi

PLATFORM_ID="$(echo $1 | tr '[A-Z]' '[a-z]')"

if [ -d "$PLATFORM_ID" ]; then
  cat $PLATFORM_ID/INFO
else
  echo "The platform($PLATFORM_ID) certificate directory does not exist."
fi