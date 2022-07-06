#!/bin/bash
################################
### Incloud Install Env File ###
################################
source ../../cube_env

################################
### kiali certificate config ###
################################
KIALI_CERT_DIR="${CUBE_TMP}/cube/certificate/kiali"
CERT_VALIDITY_DAYS="3650"

#######################################
### kiali external domain,ip config ###
#######################################
KIALI_DNS=""
KIALI_DNS_LENGTH=${#KIALI_DNS[@]}

KIALI_IPS=""
KIALI_IPS_LENGTH=${#KIALI_IPS[@]}

### create certificate task directory ###
sudo mkdir -p ${KIALI_CERT_DIR}

######################################
### kiali openssl.conf Create File ###
######################################
cat << EOF | sudo tee ${CERT_DIR}/kiali-openssl.cnf
[ req ]
distinguished_name = req_dn
[ req_dn ]

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign

[ v3_req_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEnciphermentm, nonRepudiation
extendedKeyUsage = clientAuth

[ v3_req_server ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment, nonRepudiation
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = kiali
DNS.3 = kiali.istio-system
DNS.4 = kiali.istio-system.svc
DNS.5 = kiali.istio-system.svc.cluster
DNS.6 = kiali.istio-system.svc.cluster.local
EOF
### openssl alt_names add external domain ###
for ((i=0; i<${KIALI_DNS_LENGTH}; i++)); 
do
  echo "DNS.$((i+7)) = ${KIALI_DNS[i]}" | sudo tee --append ${CERT_DIR}/kiali-openssl.cnf
done

echo "IP.1 = 127.0.0.1" | sudo tee --append ${CERT_DIR}/kiali-openssl.cnf

### openssl alt_names add external ip ###
for ((i=0; i<${KIALI_IPS_LENGTH}; i++)); 
do
  echo "IP.$((i+1)) = ${KIALI_IPS[i]}" | sudo tee --append ${CERT_DIR}/kiali-openssl.cnf
done


############################
### Create Cefiticate CA ###
############################
sudo openssl genrsa -out ${KIALI_CERT_DIR}/ca.key 2048

##################################
### Create Cefiticate kiali CA ###
##################################
sudo openssl req -x509 -new -sha256 -nodes -key ${KIALI_CERT_DIR}/ca.key -days ${CERT_VALIDITY_DAYS} -subj "/CN=kiali-ca" -out ${KIALI_CERT_DIR}/ca.crt -extensions v3_ca -config ${KIALI_CERT_DIR}/kiali-openssl.cnf

###############################
### Create kiali Cefiticate ###
###############################
sudo openssl genrsa -out ${KIALI_CERT_DIR}/kiali.key 2048
sudo openssl req -new -key ${KIALI_CERT_DIR}/kiali.key -out ${KIALI_CERT_DIR}/kiali.csr -subj "/CN=kiali" -config ${KIALI_CERT_DIR}/kiali-openssl.cnf
sudo openssl x509 -req -in ${KIALI_CERT_DIR}/kiali.csr -CA ${KIALI_CERT_DIR}/ca.crt -CAkey ${KIALI_CERT_DIR}/ca.key -CAcreateserial -out ${KIALI_CERT_DIR}/kiali.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_server -extfile ${KIALI_CERT_DIR}/kiali-openssl.cnf


sudo cat ${KIALI_CERT_DIR}/kiali.crt ${KIALI_CERT_DIR}/ca.crt | base64 -w0 > ${KIALI_CERT_DIR}/kiali-tls-certchain.base64.result
sudo cat ${KIALI_CERT_DIR}/kiali.key | base64 -w0 > ${KIALI_CERT_DIR}/kiali-tls-key.base64.result

