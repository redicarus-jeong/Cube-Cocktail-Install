#!/bin/bash

red=`tput setaf 1`
whiteback=`tput setab 7`
reset=`tput sgr0`

if [ -d "tmp" ]; then

  echo "${red}${whiteback}All authentication files previously in use will be removed.${reset}"
  echo "Are you sure you want to ${red}remove${reset} it?"

  echo -n "y/n: "
  read -r answer

  if [[ "$answer" == "y" ]]; then
    rm -rf tmp
    echo "Initialized!"
  else
    echo "Canceled."
  fi
else
  echo "It is already in the initial state."
fi