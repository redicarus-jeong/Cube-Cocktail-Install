#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 [IP ADDR | DOMAIN (comma seperated array string)] [NAMESPACE]"
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
echo "This machine is ${machine}. \nWorking with options for ${machine}."
echo ""

# =====================================================
echo "!! Validation check !!"
echo "----------------------"
export KAFKA_CLUSTER_NAME=cocktail-mq
export KAFKA_EXTERNAL_NAME=$1
export KAFKA_NAMESPACE=$2
export KAFKA_CLUSTER_CA_P12_PASSWORD=cocktail
export KAFKA_CLIENTS_CA_P12_PASSWORD=cocktail
export KAFKA_BROKER_P12_PASSWORD=cocktail
export KAFKA_ADMIN_P12_PASSWORD=admin
export MONITORING_COLLECTOR_P12_PASSWORD=collector

function checkNodeport() {
  if [[ $1 -lt 30000 || $1 -gt 32768 ]]; then
    echo "NodePort format is incorrect. (${1})"
    return -1
  else
    echo "Nodeport check ..... OK"
  fi
}
# Node Port HardCoding - Fixed
#checkNodeport $4
export BOOTSTRAP_NODEPORT=30007
#checkNodeport ${5}
export BROKER_NODEPORT=30010

# move working directory
if [ -d "tmp" ]; then
  # remove all files
  # rm -rf tmp/*
  echo ""
  echo "There is an authentication file that was previously used."
  echo "  - If you use this, check other commands.(read a README file)"
  echo "  - When creating a new one, it must be initialized through the 'clear.sh' command."
  echo ""
  exit -1
else
  mkdir tmp
fi
cd tmp

# =====================================================
echo "!! Generate Certificate !!"
echo "-------------------------"

# Generate Certification.
cat > openssl.cnf <<EOF
[ req ]
default_bits = 2048
#prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = <country>
ST = <state>
L = <city>
O = <organization>
OU = <organization unit>
CN = <MASTER_IP>

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
IP.1 = 127.0.0.1

[ v3_req_client ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,digitalSignature
extendedKeyUsage=clientAuth

[ v3_req_server ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[ alt_names_kafka ]
DNS.1 = localhost
DNS.2 = $KAFKA_CLUSTER_NAME-kafka-brokers
DNS.3 = $KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE
DNS.4 = $KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE.svc
DNS.5 = $KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE.svc.cluster.local
DNS.6 = *.$KAFKA_CLUSTER_NAME-kafka-brokers
DNS.7 = *.$KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE
DNS.8 = *.$KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE.svc
DNS.9 = *.$KAFKA_CLUSTER_NAME-kafka-brokers.$KAFKA_NAMESPACE.svc.cluster.local
DNS.10 = $KAFKA_CLUSTER_NAME-kafka-bootstrap
DNS.11 = $KAFKA_CLUSTER_NAME-kafka-bootstrap.$KAFKA_NAMESPACE
DNS.12 = $KAFKA_CLUSTER_NAME-kafka-bootstrap.$KAFKA_NAMESPACE.svc
DNS.13 = $KAFKA_CLUSTER_NAME-kafka-bootstrap.$KAFKA_NAMESPACE.svc.cluster.local
@REPLACE_DNS@
IP.1 = 127.0.0.1
@REPLACE_IP@

[ v3_req_kafka ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,digitalSignature
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names_kafka
EOF

sed_option="-i"
if [[ "$machine" == "Mac" ]]; then
  echo "This machine is not mac"
  sed_option="-i \"\""
fi



# Check Multi Domain
arrNAME=(${KAFKA_EXTERNAL_NAME//,/ })
replaceDomain=""
replaceIp=""
numDomain=13
numIp=1
for i in "${arrNAME[@]}"
do
  if [[ $i =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    #IP
    numIp=$(($numIp + 1))
    replaceIp+="IP.${numIp} = ${i}\n"
  else
    #DOMAIN
    numDomain=$(($numDomain + 1))
    replaceDomain+="DNS.${numDomain} = ${i}\n"
  fi
done
# representative domain setting - first thing
KAFKA_EXTERNAL_NAME=${arrNAME[0]}
$(sed $sed_option "s/@REPLACE_DNS@/${replaceDomain}/g" openssl.cnf)
$(sed $sed_option "s/@REPLACE_IP@/${replaceIp}/g" openssl.cnf)


# Cluster CA
openssl req -x509 -new -nodes -keyout cluster-ca.key -out cluster-ca.crt -days 3650 -subj "/CN=cluster-ca"
openssl pkcs12 -export -in cluster-ca.crt -nokeys -out cluster-ca.p12 -password pass:$KAFKA_CLUSTER_CA_P12_PASSWORD -caname ca.crt

# Clients CA
openssl req -x509 -new -nodes -keyout clients-ca.key -out clients-ca.crt -days 3650 -subj "/CN=clients-ca"
openssl pkcs12 -export -in clients-ca.crt -nokeys -out clients-ca.p12 -password pass:$KAFKA_CLIENTS_CA_P12_PASSWORD -caname ca.crt

# Kafka Broker Cert
openssl genpkey -algorithm RSA -out kafka-brokers.key.temp -pkeyopt rsa_keygen_bits:2048
openssl pkcs8 -topk8 -inform PEM -in kafka-brokers.key.temp -v1 PBE-SHA1-3DES -outform PEM -out kafka-brokers.key -nocrypt
openssl req -new -key kafka-brokers.key -out kafka-brokers.csr -subj "/CN=$KAFKA_CLUSTER_NAME-kafka" -config ./openssl.cnf
openssl x509 -req -in kafka-brokers.csr -CA cluster-ca.crt -CAkey cluster-ca.key -CAcreateserial -out kafka-brokers.crt -days 3650 -extensions v3_req_kafka -extfile ./openssl.cnf
openssl pkcs12 -export -in kafka-brokers.crt -nokeys -out kafka-brokers.p12 -password pass:$KAFKA_BROKER_P12_PASSWORD -caname ca.crt

# Kafka Admin Cert
openssl genpkey -algorithm RSA -out admin.key.temp -pkeyopt rsa_keygen_bits:2048
openssl pkcs8 -topk8 -inform PEM -in admin.key.temp -v1 PBE-SHA1-3DES -outform PEM -out admin.key -nocrypt
openssl req -new -key admin.key -out admin.csr -subj "/CN=kafka-admin" -config ./openssl.cnf
openssl x509 -req -in admin.csr -CA clients-ca.crt -CAkey clients-ca.key -CAcreateserial -out admin.crt -days 3650 -extensions v3_req_client -extfile ./openssl.cnf
openssl pkcs12 -export -in admin.crt -nokeys -out admin.p12 -password pass:$KAFKA_ADMIN_P12_PASSWORD -caname ca.crt

# Collector Cert
openssl genpkey -algorithm RSA -out kafka-collector.key.temp -pkeyopt rsa_keygen_bits:2048
openssl pkcs8 -topk8 -inform PEM -in kafka-collector.key.temp -v1 PBE-SHA1-3DES -outform PEM -out kafka-collector.key -nocrypt
openssl req -new -key kafka-collector.key -out kafka-collector.csr -subj "/CN=$KAFKA_CLUSTER_NAME-collector" -config ./openssl.cnf
openssl x509 -req -in kafka-collector.csr -CA clients-ca.crt -CAkey clients-ca.key -CAcreateserial -out kafka-collector.crt -days 3650 -extensions v3_req_client -extfile ./openssl.cnf
openssl pkcs12 -export -in kafka-collector.crt -nokeys -out kafka-collector.p12 -password pass:$MONITORING_COLLECTOR_P12_PASSWORD -caname ca.crt

# =====================================================
echo "!! Generate values.yaml !!"
echo "--------------------------"

if [[ "$machine" != "Mac" ]]; then
  echo "This machine is not mac"
  base64_option=" -w 0"
fi
CLUSTER_CACRT=$(cat cluster-ca.crt | base64  $base64_option)
CLUSTER_CAKEY=$(cat cluster-ca.key | base64  $base64_option)
CLUSTER_CAP12=$(cat cluster-ca.p12 | base64  $base64_option)
CLUSETR_PASS_B64=$(echo -n "$KAFKA_CLUSTER_CA_P12_PASSWORD" | base64  $base64_option)

CLITENTS_CACRT=$(cat clients-ca.crt | base64  $base64_option)
CLITENTS_CAKEY=$(cat clients-ca.key | base64  $base64_option)
CLITENTS_CAP12=$(cat clients-ca.p12 | base64  $base64_option)
CLITENTS_PASS_B64=$(echo -n "$KAFKA_CLIENTS_CA_P12_PASSWORD" | base64  $base64_option)

BROKER_CRT=$(cat kafka-brokers.crt | base64  $base64_option)
BROKER_KEY=$(cat kafka-brokers.key | base64  $base64_option)
BROKER_P12=$(cat kafka-brokers.p12 | base64  $base64_option)
BROKER_PASS_B64=$(echo -n "$KAFKA_BROKER_P12_PASSWORD" | base64  $base64_option)

ADMIN_CRT=$(cat admin.crt | base64  $base64_option)
ADMIN_KEY=$(cat admin.key | base64  $base64_option)
ADMIN_P12=$(cat admin.p12 | base64  $base64_option)
ADMIN_PASS_B64=$(echo -n "$KAFKA_ADMIN_P12_PASSWORD" | base64  $base64_option)

COLLECTOR_CRT=$(cat kafka-collector.crt | base64  $base64_option)
COLLECTOR_KEY=$(cat kafka-collector.key | base64  $base64_option)
COLLECTOR_P12=$(cat kafka-collector.p12 | base64  $base64_option)
COLLECTOR_PASS_B64=$(echo -n "$MONITORING_COLLECTOR_P12_PASSWORD" | base64  $base64_option)

cat > values.yaml <<EOF
strimzi-kafka-operator:
  # Platform 별로 별도 설치시 설정 필요
  #watchAnyNamespace: true
  defaultImageRegistry: regi.acloud.run/quay.io
  # log configmap name changed
  logConfigMap: $KAFKA_CLUSTER_NAME-cluster-operator

openshift:
  enabled: false

cluster:
  name: $KAFKA_CLUSTER_NAME
  kafkaVersion: 3.1.0
  interBrokerProtocolVersion: 3.1
  replicas: 1
  #resources:
  #  requests:
  #    memory: 1Gi
  #    cpu: 1
  #  limits:
  #    memory: 1Gi
  #    cpu: 1
  listeners:
    - name: plain
      port: 9092
      type: internal
      tls: false
    - name: tls
      port: 9093
      type: internal
      tls: true
      authentication:
        type: tls
      configuration:
        brokerCertChainAndKey:
          secretName: $KAFKA_CLUSTER_NAME-kafka-brokers
          certificate: $KAFKA_CLUSTER_NAME-kafka-0.crt
          key: $KAFKA_CLUSTER_NAME-kafka-0.key
    - name: external
      port: 9094
      type: nodeport
      tls: true
      authentication:
        type: tls
      configuration:
        bootstrap:
          nodePort: $BOOTSTRAP_NODEPORT
        brokerCertChainAndKey:
          secretName: $KAFKA_CLUSTER_NAME-kafka-brokers
          certificate: $KAFKA_CLUSTER_NAME-kafka-0.crt
          key: $KAFKA_CLUSTER_NAME-kafka-0.key
        brokers:
          - broker: 0
            advertisedHost: $KAFKA_EXTERNAL_NAME
            nodePort: $BROKER_NODEPORT
        externalTrafficPolicy: Local
        preferredNodePortAddressType: InternalDNS
  storage:
    size: "10Gi"
    class: "nfs-csi"
    deleteClaim: false
  zookeeper:
    replicas: 1
    storage:
      size: "10Gi"
      class: "nfs-csi"
      deleteClaim: false
  tls:
    clusterCA:
      base64encodedKey: $CLUSTER_CAKEY
      base64encodedCrt: $CLUSTER_CACRT
      base64encodedP12: $CLUSTER_CAP12
      base64encodedPassword: $CLUSETR_PASS_B64
    clientsCA:
      base64encodedKey: $CLITENTS_CAKEY
      base64encodedCrt: $CLITENTS_CACRT
      base64encodedP12: $CLITENTS_CAP12
      base64encodedPassword: $CLITENTS_PASS_B64
    brokers:
      - index: 0
        base64encodedCrt: $BROKER_CRT
        base64encodedKey: $BROKER_KEY
        base64encodedP12: $BROKER_P12
        base64encodedPassword: $BROKER_PASS_B64

topics:
  - name: alarms
    partitions: 1
    replicas: 1
  - name: audits
    partitions: 1
    replicas: 1
  - name: events
    partitions: 1
    replicas: 1
  - name: metrics
    partitions: 1
    replicas: 1

users:
  - name: kafka-admin
    secret:
      base64encodedCaCert: $CLITENTS_CACRT
      base64encodedUserCert: $ADMIN_CRT
      base64encodedUserKey: $ADMIN_KEY
      base64encodedUserP12: $ADMIN_P12
      base64encodedUserPassword: $ADMIN_PASS_B64
    acls:
      - host: "*"
        operation: All
        resource:
          name: "*"
          patternType: literal
          type: topic
      - host: '*'
        operation: All
        resource:
          name: "*"
          patternType: literal
          type: group
  - name: $KAFKA_CLUSTER_NAME-collector
    secret:
      base64encodedCaCert: $CLITENTS_CACRT
      base64encodedUserCert: $COLLECTOR_CRT
      base64encodedUserKey: $COLLECTOR_KEY
      base64encodedUserP12: $COLLECTOR_P12
      base64encodedUserPassword: $COLLECTOR_PASS_B64
    acls:
      - host: "*"
        operation: Read
        resource:
          name: metrics
          patternType: literal
          type: topic
      - host: "*"
        operation: Read
        resource:
          name: metric-consumers
          patternType: literal
          type: group
      - host: "*"
        operation: Read
        resource:
          name: alarms
          patternType: literal
          type: topic
      - host: "*"
        operation: Read
        resource:
          name: alarm-consumers
          patternType: literal
          type: group
      - host: "*"
        operation: Read
        resource:
          name: audits
          patternType: literal
          type: topic
      - host: "*"
        operation: Read
        resource:
          name: audit-consumers
          patternType: literal
          type: group
      - host: "*"
        operation: Read
        resource:
          name: events
          patternType: literal
          type: topic
      - host: "*"
        operation: Read
        resource:
          name: event-consumers
          patternType: literal
          type: group
EOF

echo ""
echo "Certificate and values.yaml creation job completed successfully."
echo ""
echo "  Installation of cocktail-message-queue can be done with the following steps."
echo "  --------------------------------------------------------------------"
echo "  1. helm repo add cube https://regi.acloud.run/chartrepo/cube"
echo "  2. helm repo update"
echo "  3. helm upgrade --install cocktail-mq cube/cocktail-message-queue -f tmp/values.yaml --namespace $KAFKA_NAMESPACE"
echo "  Modifying detailed settings directly edit values.yaml."
echo ""
echo ""