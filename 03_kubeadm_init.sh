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

ETCD_STATUS=`systemctl status etcd | grep Active | awk {'print $2'}`

if [ "${ETCD_STATUS}" == "active" ]; then
  echo ""
  echo "###############################################################"
  echo "### 07 ${HOSTNAME} kubernetes Server CREATE KUBEADM CONFIG  ###"
  echo "###############################################################"
  echo ""
  sleep 1

  sh ./${OS_TYPE}/07_kubeadm_config_yaml_init.sh
  sleep 5

  echo ""
  echo "#############################################################"
  echo "### 08 ${HOSTNAME} kubernetes Server CUBE BOOTSTRAP START ###"
  echo "#############################################################"
  echo ""
  sleep 1

  sh ./${OS_TYPE}/08_cube_install.sh install
  sleep 5

else
  echo ""
  echo "Not Found ETCD Service Active STATUS"
  echo "Check Your ETCD Cluster STATUS"
  echo "Bye Bye"
  echo ""
  sleep 4
  exit 0
fi

echo "#########################################"
echo "### 09 ${HOSTNAME} haproxy static pod ###"
echo "#########################################"
sh ./${OS_TYPE}/09_haproxy_static_pod.sh
sleep 5
