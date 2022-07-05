#!/usr/bin/env bash

### this script is Create Kubernetes OpennsSSL Config File
### date : 2022-07-05
### author : redicarus.jeong
### description
### 

source ./cube.env

echo "### 11.Create_Openssl.sh ###"

##### 11-1. Create Certificate Dir and Certi.etcd dir #####
echo "====> 11-1. Create Certificate Dir and Certi.etcd dir"
if [ ! -d ${CERT_DIR} ]; then
  sudo mkdir -p ${CUBE_TEMP}
fi
if [ ! -d ${CERT_DIR}/etcd ]; then
  sudo mkdir -p ${CERT_DIR}/etcd
fi

##### 11-2. Create openssl.conf Create file #####
echo "====> 11-2. Create openssl.conf Create file"
cat << EOF | sudo tee ${CERT_DIR}/common-openssl.conf
[ req ]
distinguished_name = req_distinguished_name
[req_distinguished_name]

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign

[ v3_req_server ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ v3_req_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ v3_req_apiserver ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names_cluster

[ alt_names_cluster ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = localhost
EOF

##### 11-3. openssl alt_name_cluster add external domain #####
echo "====> 11-3. openssl alt_name_cluster add external domain"
if [ "${ETCD_TYPE}" == "external" ]; then
  for ((i=0; i<${CUBE_ENV_EXTERNAL_DNS_LENGTH}; i++)); 
  do
    echo "DNS.$((i+6)) = ${CUBE_ENV_EXTERNAL_DNS[i]}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
  done
fi

echo "IP.1 = 127.0.0.1" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.2 = ${CUBE_ENV_CLUSTER_IP}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.3 = ${CUBE_ENV_PROXY_IP}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.4 = ${IFIPAddress}" | sudo tee --append ${CERT_DIR}/common-openssl.conf

##### 11-4. ETCD openssl.conf Create File #####
echo "====> 11-4. ETCD openssl.conf Create File"
cat << EOF | sudo tee ${CERT_DIR}/etcd-openssl.conf
[ req ]
distinguished_name = req_distinguished_name
[req_distinguished_name]

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign

[ v3_req_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ v3_req_etcd ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names_etcd

[ alt_names_etcd ]
DNS.1 = ${HOSTNAME}
IP.1 = 127.0.0.1
IP.2 = ${IFIPAddress}
EOF

##### 11-5. metrics-server openssl.conf Create File #####
echo "====> 11-5. metrics-server openssl.conf Create File"
cat << EOF | sudo tee ${CERT_DIR}/metrics-server-openssl.conf
[ req ]
distinguished_name = dn
[ dn ]

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign

[ v3_req_client ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ v3_req_metricsserver ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names_metricsserver

[ alt_names_metricsserver ]
DNS.1 = metrics-server
DNS.2 = metrics-server.kube-system
DNS.3 = metrics-server.kube-system.svc
DNS.4 = metrics-server.kube-system.svc.cluster
DNS.5 = metrics-server.kube-system.svc.cluster.local
DNS.6 = localhost
IP.1 = 127.0.0.1
EOF
