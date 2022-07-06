#!/bin/sh

if [ $# -ne 1 ]; then
  echo "Usage: $0 [PLATFORM_NAME]"
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
echo ${machine}

# =====================================================
echo "!! Validation check !!"
echo "----------------------"
export KAFKA_CLUSTER_NAME=cocktail-mq
export USER_NAMESPACE=cocktail-addon
export PLATFORM_NAME="$(echo $1 | tr '[A-Z]' '[a-z]')"
export USER_PASSWORD=platform

if [[ ! -f "tmp/openssl.cnf" ]]; then
  echo "인증서가 만들어지지 않았습니다."
  exit -1
fi

cd tmp

# =====================================================
echo "!! Generate Certificate !!"
echo "-------------------------"

FILENAME="user-${PLATFORM_NAME}"
# Monitoring Agent(고객) Cert
openssl genpkey -algorithm RSA -out $FILENAME.key.temp -pkeyopt rsa_keygen_bits:2048
openssl pkcs8 -topk8 -inform PEM -in $FILENAME.key.temp -v1 PBE-SHA1-3DES -outform PEM -out $FILENAME.key -nocrypt
openssl req -new -key $FILENAME.key -out $FILENAME.csr -subj "/CN=$KAFKA_CLUSTER_NAME-user-$PLATFORM_NAME" -config ./openssl.cnf
openssl x509 -req -in $FILENAME.csr -CA clients-ca.crt -CAkey clients-ca.key -CAcreateserial -out $FILENAME.crt -days 3650 -extensions v3_req_client -extfile ./openssl.cnf
openssl pkcs12 -export -in $FILENAME.crt -nokeys -out $FILENAME.p12 -password pass:$USER_PASSWORD -caname ca.crt


# =====================================================
echo "!! Generate values.yaml !!"
echo "--------------------------"

if [[ "$machine" != "Mac" ]]; then
  echo "This machine is not mac"
  base64_option=" -w 0"
fi

CLUSTER_CACRT=$(cat cluster-ca.crt | base64 $base64_option)
CLITENTS_CACRT=$(cat clients-ca.crt | base64 $base64_option)
AGENT_CRT=$(cat $FILENAME.crt | base64 $base64_option)
AGENT_KEY=$(cat $FILENAME.key | base64 $base64_option)
AGENT_P12=$(cat $FILENAME.p12 | base64 $base64_option)
AGENT_PASS_B64=$(echo -n $USER_PASSWORD | base64 $base64_option)

cat > agent_values.yaml <<EOF
platformId: $PLATFORM_NAME

addon:
  namespace: $USER_NAMESPACE
  tls:
    # cluster-ca
    base64encodedCaCert: $CLUSTER_CACRT
    base64encodedClientCert: $AGENT_CRT
    base64encodedClientKey: $AGENT_KEY

kafka:
  cluster:
    name: $KAFKA_CLUSTER_NAME
  user:
    # clients-ca
    base64encodedCaCert: $CLITENTS_CACRT
    base64encodedUserCert: $AGENT_CRT
    base64encodedUserKey: $AGENT_KEY
    base64encodedUserP12: $AGENT_P12
    base64encodedUserPassword: $AGENT_PASS_B64
EOF

echo ""
echo "User Certificate and values.yaml creation job completed successfully."
echo ""
echo "  Installation of cocktail-message-queue-user can be done with the following steps."
echo "  --------------------------------------------------------------------"
echo "  1. helm repo add cube https://regi.acloud.run/chartrepo/cube"
echo "  2. helm repo update"
echo "  3. helm upgrade --install cocktail-mq-user-$PLATFORM_NAME cube/cocktail-message-queue-user -f tmp/agent_values.yaml --namespace cocktail-system"
echo "  Modifying detailed settings directly edit agent_values.yaml."
echo ""
echo ""