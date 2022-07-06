#!/bin/sh

if [ $# -ne 1 ]; then
  echo "Usage: $0 [NAMESPACE]"
  exit -1
fi
export NAMESPACE=$1

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac
echo ${machine}


# move working directory
if [[ ! -f "tmp/cluster-ca.crt" ]]; then
  echo "인증서가 만들어지지 않았습니다."
  exit -1
fi

cd tmp

if [[ "$machine" != "Mac" ]]; then
  echo "This machine is not mac"
  base64_option=" -w 0"
fi

CLITENTS_CACRT=$(cat clients-ca.crt | base64  $base64_option)
COLLECTOR_CRT=$(cat kafka-collector.crt | base64  $base64_option)
COLLECTOR_KEY=$(cat kafka-collector.key | base64  $base64_option)

cat > kafka-collector-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: kafka-collector
  namespace: $NAMESPACE
type: Opaque
data:
  root.crt: $CLITENTS_CACRT
  client.crt: $COLLECTOR_CRT
  client.key: $COLLECTOR_KEY
EOF

echo ""
echo "secret.yaml for kafka collector creation job completed successfully."
echo ""
echo "  Installation of cocktail-kafka can be done with the following steps."
echo "  --------------------------------------------------------------------"
echo "  1. kubectl apply -f tmp/kafka-collector-secret.yaml"
echo ""
echo ""