#!/bin/bash

### Certificate Reference "https://kubernetes.io/docs/setup/best-practices/certificates/#certificate-paths" ###

################################
### Incloud Install Env File ###
################################
source ./cube_env

### Create Job Directory ###
#rm -rf ${CUBE_TMP}/cube/certificate
sudo mkdir -p ${CUBE_TMP}/cube/certificate
sudo mkdir -p ${CUBE_TMP}/cube/certificate/etcd

########################
### Incloud File Var ###
########################
### alt_names_cluster ADD IP ###
CLUSTER_IP=${CUBE_ENV_CLUSTER_IP}
PROXY_IP=${CUBE_ENV_PROXY_IP}
EXTERNAL_DNS=${CUBE_ENV_EXTERNAL_DNS}
EXTERNAL_DNS_LENGTH=${#EXTERNAL_DNS[@]}

##################
### Global Var ###
##################
### External ETCD = "external", Static Pod ETCD = "static" ###
ETCD_TYPE="external"
CERT_DIR="${CUBE_TMP}/cube/certificate"
HOSTNAME=`hostname`

#############################################
### Create Kubernetes OpenSSL Config File ###
#############################################

### Create openssl.conf Create file ###
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

### openssl alt_name_cluster add external domain ###
if [ "${ETCD_TYPE}" == "external" ]; then
  for ((i=0; i<${EXTERNAL_DNS_LENGTH}; i++)); 
  do
    echo "DNS.$((i+6)) = ${EXTERNAL_DNS[i]}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
  done
fi

echo "IP.1 = 127.0.0.1" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.2 = ${CLUSTER_IP}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.3 = ${PROXY_IP}" | sudo tee --append ${CERT_DIR}/common-openssl.conf
echo "IP.4 = ${NODE_IP}" | sudo tee --append ${CERT_DIR}/common-openssl.conf

#######################################
### Create ETCD OpenSSL Config File ###
#######################################

### ETCD openssl.conf Create File ###
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
IP.2 = ${NODE_IP}
EOF

#################################################
### Create metrics-server OpenSSL Config File ###
#################################################

### metrics-server openssl.conf Create File ###
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
