#!/usr/bin/env bash

### this script is copy Kubernetes Crtificate in master01 to master02, master03 
### date : 2022-07-05
### author : redicarus.jeong
### description
### 

source ./cube.env

##### 04. copy Kubernetes Crtificate in master01 to master02, master03" #####
echo "====> 04. copy Kubernetes Crtificate in master01 to master02, master03"
sshOption="-o StrictHostKeyChecking=no -o ConnectTimeout=1 -o NumberOfPasswordPrompts=1"

KIND="$1"

case ${KIND} in
  '-h'|'-H')
    ### 4-1. Node IP append where in /etc/hosts
    echo "====> 4-1. Node IP append where in /etc/hosts"
    NODE_NODE_IP=()
    for IP in "$(cat /etc/hosts|grep ${NODE_NAME_PREFIX}|awk '{print $1}')"
      do
          NODE_NODE_IP+=("${IP}")
    done

  ;;
  '-f'|'-F')
    ### 4-1. Node IP append where in cube.env
    echo "====> 4-1. Node IP append where in cube.env"
    if [ ${#NODE_NODE_IP[@]} -ge 1 ]; then
      for NODEIP in ${NODE_NODE_IP[@]}
        do
          ##### 04-1. Create Certificate Directorey in Node Host #####
          echo "====> 04-1. Create Certificate Directorey in Node Host"
          #sshpass -p ${COCKTAIL_PASS} ssh ${sshOption} ${COCKTAIL_USER}@${NODEIP} "sudo mkdir -p ${CUBE_TMP}/cube/certificate/etcd/"
          
          ##### 04-2. Kubernetes CA Copy #####
          echo "====> 04-2. Kubernetes CA Copy"
          #sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
                
          ### 04-3. ETCD CA Copy ###
          echo "====> 04-3. ETCD CA Copy"
          #sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/etcd/ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/etcd
          
          ### 04-4. Front Proxy CA Copy ###
          echo "====> 04-4. Front Proxy CA Copy"
          #sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/front-proxy-ca.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
          
          ### 04-5. Service Account CA Copy ###
          echo "====> 04-5. Service Account CA Copy"
          #sshpass -p ${COCKTAIL_PASS} sudo scp ${sshOption} ${CUBE_TMP}/cube/certificate/sa.* ${COCKTAIL_USER}@${NODEIP}:${CUBE_TMP}/cube/certificate/
      done
    fi
  ;;
  *)
    echo ">>> invalid option value
          Use: sh $0 
          Option is -h or -f.
            -h : use /etc/hosts
            -f : use cube.env "
esac