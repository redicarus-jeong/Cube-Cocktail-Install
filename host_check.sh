#!/usr/bin/env bash

### this script is master and node check
### date : 2022-06-30
### author : redicarus.jeong
### description

MASTER_COUNT=${#MASTER_HOSTNAME[@]}
echo ">>> ${MASTER_COUNT}"
if [ ${MASTER_COUNT} -eq 0 ]; then
   echo ">>> Not Found Master Hostname in env_set.sh file"
   echo; exit 0
fi

MASTER_NODE_IP=()
for MASER_NAME in ${MASTER_HOSTNAME[*]}
  do
      MASTER_IP="$(grep ${MASER_NAME} /etc/hosts |sort -u|head -1|awk 'NR==1 {print $1}')"
      MASTER_NODE_IP+=("${MASTER_IP}")
done

CNT=0
for HOST_NAME in ${MASTER_HOSTNAME[*]}; then
  do
    if [ "${HOSTNAME}" = "${HOST_NAME}" ]; then
      NODE_IP=$(ip addr | grep global | grep ${IF_NAME} | grep -E -v "docker|br-|tun" | awk '{print $2}' | cut -d/ -f1)
      if [ "${NODE_IP}" = "${MASTER_NODE_IP[${CNT}]}" ]; then
        echo "#######################################################################"
        echo "### This is the Main Master Node for Kubernetes. Hostname = ${HOSTNAME}"
        echo "### ${HOSTNAME} kubernetes Server Init START                           "
        echo "#######################################################################"
      else
        echo "This Server IP is ${NODE_IP}. But the IP set for the "cube_env" is ${MASTER_NODE_IP[1]}"
        echo "Please Change the "MASTER_NODE_IP" of "cube_env" file"
        exit 0
      fi
    else
      echo "This Server HOSTNAME IS ${HOSTNAME} Check this server hostname"
      echo "Set hostname is \"hostnamectl set-hostname YOURHOSTNAME\""
      exit 0
    fi
    (( CNT += 1 ))
done
