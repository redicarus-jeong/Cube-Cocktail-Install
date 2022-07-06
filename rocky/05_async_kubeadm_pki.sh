#!/bin/bash

################################
### Incloud Install Env File ###
################################
source ./cube_env

sudo rm -rf /etc/kubernetes/
sudo mkdir -p /etc/kubernetes/pki/etcd

sudo cp -ap ${CUBE_TMP}/cube/kubeconfig/* /etc/kubernetes/
sudo cp -ap ${CUBE_TMP}/cube/certificate/* /etc/kubernetes/pki/
sudo cp -ap ${CUBE_TMP}/cube/certificate/etcd/* /etc/kubernetes/pki/etcd/


