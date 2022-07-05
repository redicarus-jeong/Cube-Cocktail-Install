#!/usr/bin/env bash

### this script is copy Kubernetes Crtificate in master01 to master02, master03 
### date : 2022-07-05
### author : redicarus.jeong
### description
### 

source ./cube.env

##### 04. copy Kubernetes Crtificate in master01 to master02, master03" #####
echo "====> 04. copy Kubernetes Crtificate in master01 to master02, master03"
SSH_OPTION="-o StrictHostKeyChecking=no -o ConnectTimeout=1 -o NumberOfPasswordPrompts=1"

### 04-1. Node IP append where in cube.env
echo "====> 04-1. Node IP append where in cube.env"
if [ ${#NODE_NODE_IP[@]} -ge 1 ]; then
  for NODEIP in ${NODE_NODE_IP[@]}
    do
        ##### Create Certificate Directorey in Node Host #####
        sshpass -p ${COCKTAIL_PASS} ssh ${SSH_OPTION} ${COCKTAIL_USER}@${NODEIP} "sudo mkdir -p ${CUBE_TMP}/cube/certificate/etcd/"
        
        ##### Kubernetes CA Copy #####
        sshpass -p ${COCKTAIL_PASS} sudo scp ${SSH_OPTION} ${CUBE_TMP}/cube/certificate/ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
              
        ### ETCD CA Copy ###
        sshpass -p ${COCKTAIL_PASS} sudo scp ${SSH_OPTION} ${CUBE_TMP}/cube/certificate/etcd/ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/etcd
        
        ### Front Proxy CA Copy ###
        sshpass -p ${COCKTAIL_PASS} sudo scp ${SSH_OPTION} ${CUBE_TMP}/cube/certificate/front-proxy-ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
        
        ### Service Account CA Copy ###
        sshpass -p ${COCKTAIL_PASS} sudo scp ${SSH_OPTION} ${CUBE_TMP}/cube/certificate/sa.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
  done
fi
