
#!/bin/bash

################################
### Incloud Install Env File ###
################################
source ./cube_env

### Certificate Reference "https://kubernetes.io/docs/setup/best-practices/certificates/#certificate-paths" ###

CERT_DIR="${CUBE_TMP}/cube/certificate"
CERT_VALIDITY_DAYS="3650"

#####################################
### Create Kubernetes Certificate ###
#####################################
sleep 2
CA_FILE_CHECK=`ls ${CERT_DIR}/ca.crt 2> /dev/null`

if [ -z "${CA_FILE_CHECK}" ] && [ "$1" == "init" ]; then
  ### Kubernetes CA Create ###
  sudo openssl genrsa -out ${CERT_DIR}/ca.key 2048
  sudo openssl req -x509 -new -nodes -key ${CERT_DIR}/ca.key -days ${CERT_VALIDITY_DAYS} -out ${CERT_DIR}/ca.crt -subj '/CN=kubernetes-ca' -extensions v3_ca -config ${CERT_DIR}/common-openssl.conf
fi

CA_FILE_CHECK=`ls ${CERT_DIR}/ca.crt 2> /dev/null`
if [ -z "${CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ### Apiserver Certificate ###
  sudo openssl genrsa -out ${CERT_DIR}/apiserver.key 2048
  sudo openssl req -new -key ${CERT_DIR}/apiserver.key -subj '/CN=kube-apiserver' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/apiserver.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_apiserver -extfile ${CERT_DIR}/common-openssl.conf

  ### Apiserver-kubelet-client ###
  sudo openssl genrsa -out ${CERT_DIR}/apiserver-kubelet-client.key 2048
  sudo openssl req -new -key ${CERT_DIR}/apiserver-kubelet-client.key -subj '/CN=kube-apiserver-kubelet-client/O=system:masters' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/apiserver-kubelet-client.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf
fi


if [ -z "${CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ####################################
  ### Config File Certifecate data ###
  ####################################
  ### admin.conf data ###
  sudo openssl genrsa -out ${CERT_DIR}/admin.key 2048
  sudo openssl req -new -key ${CERT_DIR}/admin.key -subj '/O=system:masters/CN=kubernetes-admin' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/admin.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf

  ### controller-manager data ###
  sudo openssl genrsa -out ${CERT_DIR}/controller-manager.key 2048
  sudo openssl req -new -key ${CERT_DIR}/controller-manager.key -subj '/CN=system:kube-controller-manager' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/controller-manager.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf

  ### scheduler data ###
  sudo openssl genrsa -out ${CERT_DIR}/scheduler.key 2048
  sudo openssl req -new -key ${CERT_DIR}/scheduler.key -subj '/CN=system:kube-scheduler' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/scheduler.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf
fi

###############################
### Create ETCD Certificate ###
###############################
sleep 2
ETCD_CA_FILE_CHECK=`ls ${CERT_DIR}/etcd/ca.crt 2> /dev/null`

if [ -z "${ETCD_CA_FILE_CHECK}" ] && [ "$1" == "init" ]; then
  ### ETCD CA Create ###
  sudo openssl genrsa -out ${CERT_DIR}/etcd/ca.key 2048
  sudo openssl req -x509 -new -nodes -key ${CERT_DIR}/etcd/ca.key -days ${CERT_VALIDITY_DAYS} -out ${CERT_DIR}/etcd/ca.crt -subj '/CN=etcd-ca' -extensions v3_ca -config ${CERT_DIR}/etcd-openssl.conf
fi

ETCD_CA_FILE_CHECK=`ls ${CERT_DIR}/etcd/ca.crt 2> /dev/null`
if [ -z "${ETCD_CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ### ETCD kube-apiserver-etcd-client ###
  sudo openssl genrsa -out ${CERT_DIR}/apiserver-etcd-client.key 2048
  sudo openssl req -new -key ${CERT_DIR}/apiserver-etcd-client.key -subj '/O=system:masters/CN=kube-apiserver-etcd-client' | sudo openssl x509 -req -CA ${CERT_DIR}/etcd/ca.crt -CAkey ${CERT_DIR}/etcd/ca.key -CAcreateserial -out ${CERT_DIR}/apiserver-etcd-client.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf
fi

###################################
### ETCD Static Pod Certificate ###
###################################


if [ -z "${ETCD_CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ### kubernetes static pod etcd server certifacate ###
  sudo openssl genrsa -out ${CERT_DIR}/etcd/server.key 2048; sudo chmod 644 ${CERT_DIR}/etcd/server.key
  sudo openssl req -new -key ${CERT_DIR}/etcd/server.key -subj '/CN={{ node_name }}' | sudo openssl x509 -req -CA ${CERT_DIR}/etcd/ca.crt -CAkey ${CERT_DIR}/etcd/ca.key -CAcreateserial -out ${CERT_DIR}/etcd/server.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_etcd -extfile ${CERT_DIR}/etcd-openssl.conf

  ### kubernetes static pod etcd peer certificate ###
  sudo openssl genrsa -out ${CERT_DIR}/etcd/peer.key; sudo chmod 644 ${CERT_DIR}/etcd/peer.key
  sudo openssl req -new -key ${CERT_DIR}/etcd/peer.key -subj '/CN={{ node_name }}' | sudo openssl x509 -req -CA ${CERT_DIR}/etcd/ca.crt -CAkey ${CERT_DIR}/etcd/ca.key -CAcreateserial -out ${CERT_DIR}/etcd/peer.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_etcd -extfile ${CERT_DIR}/etcd-openssl.conf

  ### kubernetes static pod etcd healthcheck-client certificate ###
  sudo openssl genrsa -out ${CERT_DIR}/etcd/healthcheck-client.key 2048; sudo chmod 644 ${CERT_DIR}/etcd/healthcheck-client.key
  sudo openssl req -new -key ${CERT_DIR}/etcd/healthcheck-client.key -subj '/O=system:masters/CN=kube-etcd-healthcheck-client' | sudo openssl x509 -req -CA ${CERT_DIR}/etcd/ca.crt -CAkey ${CERT_DIR}/etcd/ca.key -CAcreateserial -out ${CERT_DIR}/etcd/healthcheck-client.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/etcd-openssl.conf
fi


######################################
### Create Front-proxy Certificate ###
######################################
sleep 2
FRONT_PROXY_CA_FILE_CHECK=`ls ${CERT_DIR}/front-proxy-ca.crt 2> /dev/null`

if [ -z "${FRONT_PROXY_CA_FILE_CHECK}" ] && [ "$1" == "init" ]; then
  ### Front-proxy-ca CA ###
  sudo openssl genrsa -out ${CERT_DIR}/front-proxy-ca.key 2048
  sudo openssl req -x509 -new -nodes -key ${CERT_DIR}/front-proxy-ca.key -days ${CERT_VALIDITY_DAYS} -out ${CERT_DIR}/front-proxy-ca.crt -subj '/CN=front-proxy-ca' -extensions v3_ca -config ${CERT_DIR}/common-openssl.conf
fi

FRONT_PROXY_CA_FILE_CHECK=`ls ${CERT_DIR}/front-proxy-ca.crt 2> /dev/null`
if [ -z "${FRONT_PROXY_CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ### Front-proxy-client ###
  sudo openssl genrsa -out ${CERT_DIR}/front-proxy-client.key 2048
  sudo openssl req -new -key ${CERT_DIR}/front-proxy-client.key -subj '/CN=front-proxy-client' | sudo openssl x509 -req -CA ${CERT_DIR}/front-proxy-ca.crt -CAkey ${CERT_DIR}/front-proxy-ca.key -CAcreateserial -out ${CERT_DIR}/front-proxy-client.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf
fi

###################################
### Service Account Certificate ###
###################################
sleep 2
SA_FILE_CHECK=`ls ${CERT_DIR}/sa.pub 2> /dev/null`

if [ -z "${SA_CA_FILE_CHECK}" ] && [ "$1" == "init" ]; then
  ### Service Account CA ###
  sudo openssl genrsa -out ${CERT_DIR}/sa.key 2048
  sudo openssl rsa -in ${CERT_DIR}/sa.key -outform PEM -pubout -out ${CERT_DIR}/sa.pub
fi

SA_CA_FILE_CHECK=`ls ${CERT_DIR}/ca.crt 2> /dev/null`
if [ -z "${SA_CA_FILE_CHECK}" ]; then
  echo "master01 execute copy_ca.sh script, ex. \"./copy_ca.sh 192.168.1.x\""
  exit 0
else
  ### Service Account Certiftcate ###
  sudo openssl req -new -key ${CERT_DIR}/sa.key -subj '/CN=system:kube-controller-manager' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/sa.crt -days ${CERT_VALIDITY_DAYS} -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf
fi

##################################
### metrics-server Certificate ###
##################################
sleep 2

### metrics-server CA ###
sudo openssl genrsa -out ${CERT_DIR}/metrics-server.key 2048
sudo openssl req -new -key ${CERT_DIR}/metrics-server.key -out ${CERT_DIR}/metrics-server.csr -subj "/CN=metrics-server" -config ${CERT_DIR}/metrics-server-openssl.conf
sudo openssl x509 -req -in ${CERT_DIR}/metrics-server.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/metrics-server.crt -days 3650 -extensions v3_req_metricsserver -extfile ${CERT_DIR}/metrics-server-openssl.conf
