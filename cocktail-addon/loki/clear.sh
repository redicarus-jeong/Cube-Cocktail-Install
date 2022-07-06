#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 [PLATFORM_ID]"
  exit -1
fi

red=`tput setaf 1`
whiteback=`tput setab 7`
reset=`tput sgr0`

PLATFORM_ID="$(echo $1 | tr '[A-Z]' '[a-z]')"

if [ -d "$PLATFORM_ID" ]; then

  echo "${red}${whiteback}All authentication files previously in use will be removed.${reset}"
  echo "Are you sure you want to ${red}remove${reset} it?"

  echo -n "y/n: "
  read -r answer

  if [[ "$answer" == "y" ]]; then
    rm -rf $PLATFORM_ID
    echo "Initialized!"
  else
    echo "Canceled."
  fi
else
  echo "The platform($PLATFORM_ID) certificate directory to be deleted does not exist."
fi