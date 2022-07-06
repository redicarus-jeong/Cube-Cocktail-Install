#!/bin/bash

### Incloud ENV File ###
source ./cube_env

CERT_DIR="/etc/kubernetes/pki"
KUBECONFIG_DIR="${CUBE_TMP}/cube/kubeconfig"

sudo openssl genrsa -out ${CERT_DIR}/acloud-client.key 2048
sudo openssl req -new -key ${CERT_DIR}/acloud-client.key -subj '/CN=acloud-client' | sudo openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/acloud-client.crt -days 3650 -extensions v3_req_client -extfile ${CERT_DIR}/common-openssl.conf

CA_BASE64=`sudo cat ${CERT_DIR}/ca.crt | base64 -w0`
ACLOUD_CRT_BASE64=`sudo cat ${CERT_DIR}/acloud-client.crt | base64 -w0`
ACLOUD_KEY_BASE64=`sudo cat ${CERT_DIR}/acloud-client.key | base64 -w0`

cat << EOF |sudo tee ${KUBECONFIG_DIR}/acloud-client.conf > /dev/null 2>&1
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://${NODE_IP}:6443
  name: acloud-client
contexts:
- context:
    cluster: acloud-client
    user: acloud-client
  name: acloud-client
current-context: acloud-client
kind: Config
preferences: {}
users:
- name: acloud-client
  user:
    client-certificate-data: ${ACLOUD_CRT_BASE64}
    client-key-data: ${ACLOUD_KEY_BASE64}
EOF

sudo cp ${KUBECONFIG_DIR}/acloud-client.conf /etc/kubernetes/

if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
    cat << EOF |sudo tee ${KUBECONFIG_DIR}/acloud-client-crb.yaml > /dev/null 2>&1
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: acloud-binding
subjects:
- kind: User
  name: acloud-client
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f ${KUBECONFIG_DIR}/acloud-client-crb.yaml

elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ]; then
  exit 0
elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ]; then
  exit 0
fi
