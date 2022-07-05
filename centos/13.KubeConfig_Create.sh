#!/usr/bin/env bash

### this script is Create Kubernetes Config
### date : 2022-07-05
### author : redicarus.jeong
### description

source ./cube.env

### Create Job Directory ###
if [ ! -d ${CUBE_TEMP}/cube/kubeconfig ]; then
  sudo mkdir -p ${CUBE_TEMP}/cube/kubeconfig
fi

### local variable define
CA_BASE64="`sudo cat ${CERT_DIR}/ca.crt | base64 -w 0`"
ADMIN_CRT_BASE64="`sudo cat ${CERT_DIR}/admin.crt | base64 -w 0`"
ADMIN_KEY_BASE64="`sudo cat ${CERT_DIR}/admin.key | base64 -w 0`"
CONTROLLER_MANAGER_CRT_BASE64="`sudo cat ${CERT_DIR}/controller-manager.crt | base64 -w 0`"
CONTROLLER_MANAGER_KEY_BASE64="`sudo cat ${CERT_DIR}/controller-manager.key | base64 -w 0`"
SCHEDULER_CRT_BASE64="`sudo cat ${CERT_DIR}/scheduler.crt | base64 -w 0`"
SCHEDULER_KEY_BASE64="`sudo cat ${CERT_DIR}/scheduler.key | base64 -w 0`"

##### 13. kubeconfig file create
echo "====> 13. kubeconfig file create" 

##### 13-1. admin.conf create ###
echo "====> 13-1. admin.conf create" 
cat << EOF |sudo tee ${KUBECONFIG_DIR}/admin.conf > /dev/null 2>&1
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://${IF_IPADDRESS}:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: ${ADMIN_CRT_BASE64}
    client-key-data: ${ADMIN_KEY_BASE64}
EOF


### 13-2. kube-controller-manager.conf ###
echo "====> 13-2. kube-controller-manager.conf" 
cat << EOF | sudo tee ${KUBECONFIG_DIR}/controller-manager.conf > /dev/null 2>&1
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://${IF_IPADDRESS}:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: system:kube-controller-manager@kubernetes
current-context: system:kube-controller-manager@kubernetes
kind: Config
preferences: {}
users:
- name: system:kube-controller-manager
  user:
    client-certificate-data: ${CONTROLLER_MANAGER_CRT_BASE64}
    client-key-data: ${CONTROLLER_MANAGER_KEY_BASE64}
EOF


### 13-3. scheduler.conf ###
echo "====> 13-3. scheduler.conf" 
cat << EOF | sudo tee ${KUBECONFIG_DIR}/scheduler.conf > /dev/null 2>&1
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://${IF_IPADDRESS}:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-scheduler
  name: system:kube-scheduler@kubernetes
current-context: system:kube-scheduler@kubernetes
kind: Config
preferences: {}
users:
- name: system:kube-scheduler
  user:
    client-certificate-data: ${SCHEDULER_CRT_BASE64}
    client-key-data: ${SCHEDULER_KEY_BASE64}
EOF