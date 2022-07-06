#!/bin/sh

if [ $# -ne 2 ]; then
  echo "Usage: $0 [PLATFORM_ID] [LB IP or NODEPORT IP | DOMAIN (comma sepereated array string)]"
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

# =====================================================
echo "!! Validation check !!"
echo "----------------------"

export PLATFORM_ID="$(echo $1 | tr '[A-Z]' '[a-z]')"
export LOKI_EXTERNAL_NAME=$2
export LOKI_NAMESPACE="m-${PLATFORM_ID}"
export RELEASE_NAME=cocktail-log

# CA가 없는 경우 만들어 내야 합니다.
sh generate_ca.sh

PORT_FILE_NAME=ca/PORT.id
num=`cat ${PORT_FILE_NAME}`
LOKI_NODEPORT=$(($num + 1))



# move working directory
if [ -d "$PLATFORM_ID" ]; then
  echo ""
  echo "There is an authentication file that was previously used."
  echo "  - If you use this, check other commands.(read a README file)"
  echo "  - When creating a new one, it must be initialized through the 'clear.sh $PLATFORM_ID' command."
  echo "  - For detailed information, use the 'info.sh $PLATFORM_ID' command."
  echo ""
  exit -1
else
  mkdir $PLATFORM_ID
fi
cd $PLATFORM_ID
CA_PATH="../ca"

# =====================================================
echo "!! Generate Certificate !!"
echo "-------------------------"

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
DNS.2 = $RELEASE_NAME-loki-proxy
DNS.3 = $RELEASE_NAME-loki-proxy.$LOKI_NAMESPACE
DNS.4 = $RELEASE_NAME-loki-proxy.$LOKI_NAMESPACE.svc
DNS.5 = $RELEASE_NAME-loki-proxy.$LOKI_NAMESPACE.svc.cluster.local
@REPLACE_DNS@
IP.1 = 127.0.0.1
@REPLACE_IP@

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
EOF

sed_option="-i"
if [[ "$machine" == "Mac" ]]; then
  sed_option="-i \"\""
fi


# Check Multi Domain
arrNAME=(${LOKI_EXTERNAL_NAME//,/ })
replaceDomain=""
replaceIp=""
numDomain=5
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
LOKI_EXTERNAL_NAME=${arrNAME[0]}
$(sed $sed_option "s/@REPLACE_DNS@/${replaceDomain}/g" openssl.cnf)
$(sed $sed_option "s/@REPLACE_IP@/${replaceIp}/g" openssl.cnf)

# Loki Server Cert
openssl genpkey -algorithm RSA -out loki-server.key.temp
openssl pkcs8 -topk8 -inform PEM -in loki-server.key.temp -v1 PBE-SHA1-3DES -outform PEM -out loki-server.key -nocrypt
openssl req -new -key loki-server.key -out loki-server.csr -subj "/CN=cocktail-loki" -config ./openssl.cnf
openssl x509 -req -in loki-server.csr -CA ${CA_PATH}/loki-ca.crt -CAkey ${CA_PATH}/loki-ca.key -CAcreateserial -out loki-server.crt -days 3650 -extensions v3_req_server -extfile ./openssl.cnf

# Loki Clinet Cert(Promtail)
openssl genpkey -algorithm RSA -out loki-client.key.temp
openssl pkcs8 -topk8 -inform PEM -in loki-client.key.temp -v1 PBE-SHA1-3DES -outform PEM -out loki-client.key -nocrypt
openssl req -new -key loki-client.key -out loki-client.csr -subj "/CN=loki-client" -config ./openssl.cnf
openssl x509 -req -in loki-client.csr -CA ${CA_PATH}/loki-ca.crt -CAkey ${CA_PATH}/loki-ca.key -CAcreateserial -out loki-client.crt -days 3650 -extensions v3_req_client -extfile ./openssl.cnf




# =====================================================
echo "!! Generate values.yaml !!"
echo "--------------------------"

LOKI_CACRT=$(cat ${CA_PATH}/loki-ca.crt | sed 's/^/        /g')
LOKI_SERVER_CRT=$(cat loki-server.crt | sed 's/^/        /g')
LOKI_SERVER_KEY=$(cat loki-server.key | sed 's/^/        /g')
LOKI_CLIENT_CRT=$(cat loki-client.crt | sed 's/^/        /g')
LOKI_CLIENT_KEY=$(cat loki-client.key | sed 's/^/        /g')

cat > values.yaml <<EOF

global:
  defaultImageRegistry: regi.acloud.run
  proxy:
    certs:
      caCert: |
$LOKI_CACRT
      tlsCert: |
$LOKI_SERVER_CRT
      tlsKey: |
$LOKI_SERVER_KEY
    service:
      type: NodePort
      nodePort: $LOKI_NODEPORT
  monitoring:
    certs:
      caCert: |
$LOKI_CACRT
      tlsCert: |
$LOKI_CLIENT_CRT
      tlsKey: |
$LOKI_CLIENT_KEY
  openshift:
    enabled: false

cocktail-loki:
  loki:
    # For multi-tenancy
    #config:
    #  auth_enabled: true
    persistence:
      enabled: true
      accessModes:
        - ReadWriteOnce
      size: 10Gi
      storageClassName: nfs-csi

api:
  image:
    repository: library/log-api
    tag: 1.0.0-alpha

  config:
    server:
      http_listen_port: 9100
    # 내부서비스를 이용하기 위해 값을 입력하지 않습니다.
    #lokiServerUrl: "https://$LOKI_EXTERNAL_NAME:$LOKI_NODEPORT"
    auth_enabled: true

EOF

LOKI_CACRT=$(cat ${CA_PATH}/loki-ca.crt)
LOKI_CLIENT_CRT=$(cat loki-client.crt)
LOKI_CLIENT_KEY=$(cat loki-client.key)
today=`date`

cat > INFO <<EOF
PLATFORM_ID         : $PLATFORM_ID
NODEPORT            : $LOKI_NODEPORT
REPRESENT_ACCESS    : $LOKI_EXTERNAL_NAME

The value to use for cocktail-promtail installation
[Loki CA cert]
$LOKI_CACRT
[Loki client cert]
$LOKI_CLIENT_CRT
[Loki client key]
$LOKI_CLIENT_KEY
[Loki Access URL]
https://$LOKI_EXTERNAL_NAME:$LOKI_NODEPORT/loki/api/v1/push

$today created
EOF

echo $LOKI_NODEPORT > ../$PORT_FILE_NAME

echo ""
echo "Certificate and values.yaml creation job completed successfully."
echo ""
echo "  Installation of cocktail-log can be done with the following steps."
echo "  --------------------------------------------------------------------"
echo "  1. helm repo add cube https://regi.acloud.run/chartrepo/cube"
echo "  2. helm repo update"
echo "  3. helm upgrade --install $RELEASE_NAME cube/cocktail-log -f $PLATFORM_ID/values.yaml --namespace $LOKI_NAMESPACE"
echo "  Modifying detailed settings directly edit values.yaml."
echo ""
echo "애드온 설치에는 다음 명령을 이용해 정보를 확인합니다."
echo "  1. ./info.sh $PLATFORM_ID"
