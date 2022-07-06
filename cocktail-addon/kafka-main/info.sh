#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 [MODE]"
  echo "  - MODE=collector 'Provides Kafka certification information for installing cocktail helm charts'"
  exit -1
fi

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac
if [[ "$machine" != "Mac" ]]; then
  echo "This machine is not mac"
  base64_option=" -w 0"
fi

function infoCollector() {
  if [[ ! -f "tmp/cluster-ca.crt" ]]; then
    echo "인증서가 만들어지지 않았습니다."
    exit -1
  fi
  CLITENTS_CACRT=$(cat tmp/clients-ca.crt | base64  $base64_option)
  COLLECTOR_CRT=$(cat tmp/kafka-collector.crt | base64  $base64_option)
  COLLECTOR_KEY=$(cat tmp/kafka-collector.key | base64  $base64_option)

  echo "  Kafka certificate information for installing Cocktail Helm. "
  echo "  Copy and Paste the values of the same field name. "
  echo "   - depth : monitoring.monitoring.kafka.tls   "
  echo "  --------------------------------------------------------------------"
  echo "  root_crt_base64_encoded: $CLITENTS_CACRT"
  echo "  client_crt_base64_encoded: $COLLECTOR_CRT"
  echo "  client_key_base64_encoded: $COLLECTOR_KEY"
  echo ""
}

case $1 in
  "collector")
    echo "MODE==collector information...."
    infoCollector
    ;;
  *)
    echo "Invalid mode"
    ;;
esac
