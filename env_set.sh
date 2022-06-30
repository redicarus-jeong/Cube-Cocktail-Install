#!/usr/bin/env bash

# Author : redicarus-jeong
# Date : 2022-06-30
# Desciption : This file is OS Environment setup for cune-5.2.3 and cocktail-4.6.6 install

export CURRENT_PATH=$(pwd)
export SCRIPT_HOMEDIR=${CURRENT_PATH}/script
export HOSTNAME=$(hostname)

# Name is in /etc/hosts is set.
export REPOSITORY_HOSTNAME="repo" 
export HARBOR_HOSTNAME="harbor"
export REPO_PORT=3777

export HARBOR_VER="1.10.6"

### Enter the Kubernetes version to be installed through CUBE. Supports 1.18 ~ 1.21, stabilized on Cocktail 4.6.6 and recommended version is 1.21 Version
export CUBE_VER="1.21"

export INSTALL_MAIN_DIR="/APP"

export CUBE_WORK="${INSTALL_MAIN_DIR}/acorn"
export CUBE_DIR="${CUBE_WORK}/cube"
export CUBE_DATA="${CUBE_WORK}/data"
export CUBE_TEMP="${INSTALL_MAIN_DIR}/acornsoft"
export CUBE_EXEC="${INSTALL_MAIN_DIR}/cocktail"
export AWS_SERVER="disable"

# IP of Loadbalancer to which Master APISERVER will be connected (representative IP)
export CUBE_ENV_PROXY_IP="172.27.120.49"

# Domain information to be connected to Master APISERVER IP
export CUBE_ENV_EXTERNAL_DNS="master01.redicarus.com"

# Applied to installed kubernetes name, kubeadm config yaml
export CLUSTER_NAME="redicarus-cluster"

#export NODE_IP=$(ip addr | grep global | grep enp0s3 | grep -E -v "docker|br-|tun" | awk '{print $2}' | cut -d/ -f1)
#export OS_TYPE=$(grep ^NAME /etc/os-release | grep -oP '"\K[^"]+' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

# The names of master in /etc/hosts. ( format = array )
export MASTER_HOSTNAME=("Master01")         # ex) MASTER_HOSTNAME=("Master01" "Master02" "Master03")

# IP addresses of all masters in /etc/hosts. ( format = array )
export MASTER_NODE_IP=("10.10.10.111")      # ex) MASTER_NODE_IP=("10.10.10.111" "10.10.10.112" "10.10.10.113")

# Value to be applied to "podSubnet" of kubeadm - Subnet value to be used in Pod's Network, also applied to "CALICO_IPV4POOL_CIDR" setting when Calico is installed.
export POD_SUBNET="10.200.0.0/16"

# Value to be applied to "serverSubnet" in kubeadm - Used by Cluster Subnet in Kubernetes
export SERVICE_SUBNET="10.100.0.0/16"

### Network environment definition. "public" or "private"
export NETWORK_TYPE=private

### Defining whether or not to use GPU. "enable" or "disable"
export GPU_NODE=disable

### Define whether or not to use Harbor in a private environment (to be removed). "enable" or "disable"
export PRIVATE_REPO=enable



#########################################################################################################
######### NOTICE : The environment variables below are automatically defined. do not touch..!! ##########
#########################################################################################################

# Value to be applied to "clusterDns" of kubeadm - Configured by referring to the CIDR value of serverSernet
# EX) If SERVICE_SUBNET is 172.0.0.0/16, CLUSTER_DNS is 172.0.0.10 and CUBE_ENV_CLUSTER_IP is 172.0.0.1
#export CLUSTER_DNS="10.100.0.10"
export CLUSTER_DNS="$(echo ${SERVICE_SUBNET} | awk -F'.' '{print $1"."$2"."$3".10"}')"

# CLUSTER_IP value used for certificate
#export CUBE_ENV_CLUSTER_IP="10.100.0.1"
export CUBE_ENV_CLUSTER_IP="$(echo ${SERVICE_SUBNET} | awk -F'.' '{print $1"."$2"."$3".1"}')"

### About Yum or APT Private REPO in Private Environment.  example: IP:PORT
export REPO_URL="$(grep ${REPOSITORY_HOSTNAME} /etc/hosts |sort -u|head -1|awk 'NR==1 {print $1}'):${REPO_PORT}"

### Private Container Repo URL. [ HARBOR URL ]
export HARBOR_URL="$(grep ${HARBOR_HOSTNAME} /etc/hosts |sort -u|head -1|awk 'NR==1 {print $1}')"


export ETCD_MEMBER_COUNT=$(sudo ETCDCTL_API=3 etcdctl --endpoints=https://[127.0.0.1]:2379  \
                                                      --cacert=/etc/kubernetes/pki/etcd/ca.crt  \
                                                      --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt  \
                                                      --key=/etc/kubernetes/pki/etcd/healthcheck-client.key  \
                                                      member list 2>/dev/null | wc -l)

