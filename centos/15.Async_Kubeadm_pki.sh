#!/usr/bin/env bash

### this script is pki copy
### date : 2022-07-05
### author : redicarus.jeong
### description

source ./cube.env

##### 15. kubernetes , pki , etcd copy in cube to /etc/kubernetes
echo "====> 15. kubernetes , pki , etcd copy in cube to /etc/kubernetes"

##### 15-1. Directory Check : /etc/kubernetes/, /etc/kubernetes/pki/etcd
echo "====> 15-1. Directory Check : /etc/kubernetes/, /etc/kubernetes/pki/etcd"
if [ -d /etc/kubernetes ]; then
  sudo rm -rf /etc/kubernetes/
fi
sudo mkdir -p /etc/kubernetes/pki/etcd

##### 15-2. Copy kubeconfig/*  , cube/certificate/* , cube/certificate/etcd/* to /etc/kubernetes/--
echo "====> 15-2. Copy kubeconfig/*  , cube/certificate/* , cube/certificate/etcd/* to /etc/kubernetes/"
sudo cp -ap ${CUBE_TEMP}/cube/kubeconfig/* /etc/kubernetes/
sudo cp -ap ${CUBE_TEMP}/cube/certificate/* /etc/kubernetes/pki/
sudo cp -ap ${CUBE_TEMP}/cube/certificate/etcd/* /etc/kubernetes/pki/etcd/


