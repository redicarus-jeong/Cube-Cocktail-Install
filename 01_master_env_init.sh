#!/bin/bash

### Incloud ENV File ###
source ./cube_env

if [ "${OS_TYPE}" == "centos" ]; then
  echo "It's installing on ${OS_TYPE}"
elif [ "${OS_TYPE}" == "ubuntu" ]; then
  echo "It's installing on ${OS_TYPE}"
elif [ "${OS_TYPE}" == "rocky" ]; then
  echo "It's installing on ${OS_TYPE}"
elif [ "${OS_TYPE}" == "amazon" ]; then
  echo "It's installing on ${OS_TYPE}"
else
  echo "Please, Check your OS"
  exit 0
fi

if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
  if [ "${NODE_IP}" == "${MASTER_NODE_IP[0]}" ]; then
  echo "This Server Kubernetes ${HOSTNAME}"
  echo ""
  echo "################################################"
  echo "### ${HOSTNAME} kubernetes Server Init START ###"
  echo "################################################"
  echo ""
  sleep 2
  else
    echo "This Server IP is ${NODE_IP}. But the IP set for the "cube_env" is ${MASTER_NODE_IP[0]}"
    echo "Please Change the "MASTER_NODE_IP" of "cube_env" file"
    exit 0
    fi
    
elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ]; then
  if [ "${NODE_IP}" == "${MASTER_NODE_IP[1]}" ]; then
  echo "This Server Kubernetes ${HOSTNAME}"
  echo ""
  echo "################################################"
  echo "### ${HOSTNAME} kubernetes Server Init START ###"
  echo "################################################"
  echo ""
  sleep 2
  else
    echo "This Server IP is ${NODE_IP}. But the IP set for the "cube_env" is ${MASTER_NODE_IP[1]}"
    echo "Please Change the "MASTER_NODE_IP" of "cube_env" file"
    exit 0
  fi  

elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ]; then
  if [ "${NODE_IP}" == "${MASTER_NODE_IP[2]}" ]; then
  echo "This Server Kubernetes ${HOSTNAME}"
  echo ""
  echo "################################################"
  echo "### ${HOSTNAME} kubernetes Server Init START ###"
  echo "################################################"
  echo ""
  sleep 2
  else
    echo "This Server IP is ${NODE_IP}. But the IP set for the "cube_env" is ${MASTER_NODE_IP[2]}"
    echo "Please Change the "MASTER_NODE_IP" of "cube_env" file"
    exit 0
  fi
else 
  echo "This Server HOSTNAME IS ${HOSTNAME} Check this server hostname"
  echo "Set hostname is \"hostnamectl set-hostname YOURHOSTNAME\""
  echo "Bye Bye"
  sleep 3
  exit 0
fi


echo ""
echo "############################################################"
echo "### 00 ${HOSTNAME} kubernetes Server PACKAGE UNZIP START ###"
echo "############################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/00_unzip_cubefile.sh
sleep 5

echo ""
echo "###########################################################"
echo "### 01 ${HOSTNAME} kubernetes Server OPENSSL FILE START ###"
echo "###########################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/01_create_openssl.sh
sleep 5


if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
  echo ""
  echo "###############################################################"
  echo "### 02 ${HOSTNAME} kubernetes Server CREATE CERT FILE START ###"
  echo "###############################################################"
  echo ""
  sleep 1

  sh ./${OS_TYPE}/02_certificate.sh init
  sleep 5

elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ]; then
  echo ""
  echo "###############################################################"
  echo "### 02 ${HOSTNAME} kubernetes Server CREATE CERT FILE START ###"
  echo "###############################################################"
  echo ""
  sleep 1

  sh ./${OS_TYPE}/02_certificate.sh
  sleep 5

elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ]; then
  echo ""
  echo "###############################################################"
  echo "### 02 ${HOSTNAME} kubernetes Server CREATE CERT FILE START ###"
  echo "###############################################################"
  echo ""
  sleep 1

  sh ./${OS_TYPE}/02_certificate.sh
  sleep 5

else 
  exit 0
fi


echo ""
echo "#####################################################################"
echo "### 03 ${HOSTNAME} kubernetes Server CREATE KUBECONFIG FILE START ###"
echo "#####################################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/03_kubeconfig_create.sh
sleep 5

echo ""
echo "#######################################################################"
echo "### 04 ${HOSTNAME} kubernetes Server CREATE AUDIT CONFIG FILE START ###"
echo "#######################################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/04_audit.sh
sleep 5

echo ""
echo "#################################################################"
echo "### 05 ${HOSTNAME} kubernetes Server COPY TMP/CERT FILE START ###"
echo "#################################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/05_async_kubeadm_pki.sh
sleep 5

echo ""
echo "#############################################################"
echo "### 06 ${HOSTNAME} kubernetes Server ETCD BOOTSTRAP START ###"
echo "#############################################################"
echo ""
sleep 1

ETCD_MEMBER_COUNT=`sudo ETCDCTL_API=3 etcdctl --endpoints=https://[127.0.0.1]:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key member list 2>/dev/null| wc -l`

if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
  if [ "${ETCD_MEMBER_COUNT}" == "${#MASTER_HOSTNAME[@]}" ]; then
    echo "SKIP ETCD BOOTSTRAP"
  else
    sh ./${OS_TYPE}/06_etcd_bootstrap.sh
  fi
elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ]; then
  sh ./${OS_TYPE}/06_etcd_bootstrap.sh
elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ]; then
  sh ./${OS_TYPE}/06_etcd_bootstrap.sh
fi

sleep 5
