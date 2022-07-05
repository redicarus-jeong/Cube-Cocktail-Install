#!/usr/bin/env bash

### this script is copy Kubernetes Crtificate in master01 to master02, master03 
### date : 2022-07-05
### author : redicarus.jeong
### description
### 

source ./cube.env

##### 04. copy Kubernetes Crtificate in master01 to master02, master03"
echo "====> 04. copy Kubernetes Crtificate in master01 to master02, master03"

### 04-1. Create Certificate Directory ###
echo "====> 04-1. Create Certificate Directory"
if [[ "${1}" = "" ]]; then
  echo "Usage: sh ./$0 REMOTE_IP"
  exit 1
fi


sshOption="-o StrictHostKeyChecking=no -o ConnectTimeout=1 -o NumberOfPasswordPrompts=1"

sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${1} "sudo mkdir -p ${CUBE_TMP}/cube/certificate/etcd/"

### Kubernetes CA Copy ###
sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/ca.* ${COCKTAIL_USER}@${1}:/tmp/
sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${1} "sudo mv /tmp/ca.* ${CUBE_TMP}/cube/certificate/"

### ETCD CA Copy ###
sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/etcd/ca.* ${COCKTAIL_USER}@${1}:/tmp/
sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${1} "sudo mv /tmp/ca.* ${CUBE_TMP}/cube/certificate/etcd"

### Front Proxy CA Copy ###
sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/front-proxy-ca.* ${COCKTAIL_USER}@${1}:/tmp/
sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${1} "sudo mv /tmp/front-proxy-ca.* ${CUBE_TMP}/cube/certificate/"

### Service Account CA Copy ###
sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/sa.* ${COCKTAIL_USER}@${1}:/tmp/
sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${1} "sudo mv /tmp/sa.* ${CUBE_TMP}/cube/certificate/"
