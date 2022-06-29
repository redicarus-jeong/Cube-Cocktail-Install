#!/usr/bin/env bash

### This script is only connect to Private Harbor Registry on CentOS-7.9
### Modified Date : 2022-06-16
### Author : redicarus.jeong

CURRENT_PATH=$(pwd)
HARBOR_HOSTNAME="regi"

IF_NAME="enp0s8"
IF_IP_CLASS=$(ip addr show dev ${IF_NAME} scope global |grep inet|awk '{print $2}'|cut -d'.' -f1,2,3)

### Incloud ENV File ###
HARBOR_USERID="$1"
HARBOR_USERPW="$2"

HARBOR_URL=$(grep ${HARBOR_HOSTNAME} /etc/hosts | grep ${IF_IP_CLASS} | awk 'NR==1 {print $1}')
HELM_REPO_NAME="$3"

if [ -f /etc/docker/certs.d/${HARBOR_URL}/ca.crt ]; then
  if [ $# -eq 3 ]; then
    sudo  helm  repo  add  \
          --ca-file  /etc/docker/certs.d/${HARBOR_URL}/ca.crt   \
          --username=${HARBOR_USERID}  --password=${HARBOR_USERPW}  \
          ${HELM_REPO_NAME}  https://${HARBOR_URL}/chartrepo/${HELM_REPO_NAME}
          echo "  >>> ${HELM_REPO_NAME} : helm repository add success"
  else
    echo;echo ">>> usage: $0 <harbor user id>  <harbor user pw>  <add helm chart name>";echo
  fi
else
  echo "  >>> helm repository add failed"
  echo "  >>> Not Found Certificate file(=/etc/docker/certs.d/${HARBOR_URL}/ca.crt)"
fi
