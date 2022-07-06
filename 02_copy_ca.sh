#!/bin/bash
### Create Certificate Directory ###
source ./cube_env
if [[ "${1}" = "" ]]; then
  echo "Usage: sh ./copy_ca.sh REMOTE_IP"
  echo ""
  exit 1
fi

echo -n "Please, Enter remote server username: "
read USER

read -s -p "Please, Enter remote server password: "  PASSWD
echo
sshOption="-o StrictHostKeyChecking=no -o ConnectTimeout=1 -o NumberOfPasswordPrompts=1"

sshpass -p ${PASSWD} ssh ${sshOption} ${USER}@${1} "sudo mkdir -p ${CUBE_TMP}/cube/certificate/etcd/"

### Kubernetes CA Copy ###
sshpass -p ${PASSWD} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/ca.* ${USER}@${1}:/tmp/
sshpass -p ${PASSWD} ssh ${sshOption} ${USER}@${1} "sudo mv /tmp/ca.* ${CUBE_TMP}/cube/certificate/"

### ETCD CA Copy ###
sshpass -p ${PASSWD} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/etcd/ca.* ${USER}@${1}:/tmp/
sshpass -p ${PASSWD} ssh ${sshOption} ${USER}@${1} "sudo mv /tmp/ca.* ${CUBE_TMP}/cube/certificate/etcd"

### Front Proxy CA Copy ###
sshpass -p ${PASSWD} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/front-proxy-ca.* ${USER}@${1}:/tmp/
sshpass -p ${PASSWD} ssh ${sshOption} ${USER}@${1} "sudo mv /tmp/front-proxy-ca.* ${CUBE_TMP}/cube/certificate/"

### Service Account CA Copy ###
sshpass -p ${PASSWD} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/sa.* ${USER}@${1}:/tmp/
sshpass -p ${PASSWD} ssh ${sshOption} ${USER}@${1} "sudo mv /tmp/sa.* ${CUBE_TMP}/cube/certificate/"
