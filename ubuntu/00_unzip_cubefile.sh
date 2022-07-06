#!/bin/bash

### Incloud ENV File ###
source ./cube_env

#sudo unlink /bin/sh && sudo ln -s /bin/bash /bin/sh
#sleep 10

if [[ ! -d ${CUBE_WORK} ]]; then # Does not exist the Dir
  echo "Make the Directory"
  sudo mkdir -p ${CUBE_WORK}
fi

### Create Task Tmp directroy ###
sudo mkdir -p ${CUBE_TMP}/cube/temp/

if [ "${NETWORK_TYPE}" == "public" ]; then
  echo ""
  echo "################################################"
  echo "### CUBE Install Network ENV ${NETWORK_TYPE} ###"
  echo "################################################"
  echo ""
  
  ### system-default
  echo "### SYSTEM Default Package install ###"
  sudo apt-get update
  sudo apt-get install -y net-tools
  sudo apt-get install -y wget
  sudo apt-get install -y nfs-kernel-server
  sudo apt-get install -y selinux-basics
 
  ### runtime
  echo "### Container Runtime install ###"
  # containerd.io
  sudo apt-get install -y apt-transport-https
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y

  CONTAINERD_IO_VERSION=1.4
  INSTALL_CONTAINERD_IO_VERSION_PATCH=`sudo apt-cache showpkg containerd.io | grep $CONTAINERD_IO_VERSION | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  sudo apt-get install -y containerd.io=$INSTALL_CONTAINERD_IO_VERSION_PATCH

  ### ETCD
  ETCD_VER=v3.4.18
  DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
  
  sudo mkdir -p ${CUBE_TMP}/cube/etcd/etcd-download-test
  sudo wget ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -P /usr/local/src/
  sudo tar xzf /usr/local/src/etcd-${ETCD_VER}-linux-amd64.tar.gz -C ${CUBE_TMP}/cube/etcd/etcd-download-test --strip-components=1
  sudo rm -f /usr/local/src/etcd-${ETCD_VER}-linux-amd64.tar.gz

  ### Helm
  HELM_VER=v3.8.1
  DOWNLOAD_URL=https://get.helm.sh
  sudo mkdir -p ${CUBE_TMP}/cube/binary/
  sudo wget ${DOWNLOAD_URL}/helm-${HELM_VER}-linux-amd64.tar.gz -P /usr/local/src/
  sudo tar xzf /usr/local/src/helm-${HELM_VER}-linux-amd64.tar.gz -C ${CUBE_TMP}/cube/binary/ --strip-components=1
  sudo rm -f /usr/local/src/helm-${HELM_VER}-linux-amd64.tar.gz


  ### kubernetes
  echo "### Kubeadm install ###"
  sudo apt-get install -y ca-certificates curl

  sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -y
  INSTALL_KUBEADM_VERSION=`sudo apt-cache showpkg kubeadm | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBECTL_VERSION=`sudo apt-cache showpkg kubectl | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBELET_VERSION=`sudo apt-cache showpkg kubelet | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`

  sudo apt-get install -y kubectl=${INSTALL_KUBECTL_VERSION} 2>/dev/null
  sudo apt-get install -y kubelet=${INSTALL_KUBELET_VERSION} 2>/dev/null
  sudo apt-get install -y kubeadm=${INSTALL_KUBEADM_VERSION} 2>/dev/null
  sudo apt-mark hold kubelet kubeadm kubectl 

  ### utils
  echo "### Requiet Utils install ###"
  sudo apt-get install -y jq
  sudo apt-get install -y sshpass
 
  sleep 2

elif [ "${NETWORK_TYPE}" == "private" ]; then
  if [ "${PRIVATE_REPO}" == "enable" ]; then
    echo ""
    echo "########################"
    echo "### ADD Package Repo ###"
    echo "########################"
    echo ""
    
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.old

    if [ ${OS_VERSION} == "1804" ]; then
      echo deb [trusted=true] http://${REPO_URL}/1804dpkg / | sudo tee /etc/apt/sources.list
      sudo apt-get update 2>/dev/null

    elif [ ${OS_VERSION} == "2004" ]; then
      echo deb [trusted=true] http://${REPO_URL}/2004dpkg / | sudo tee /etc/apt/sources.list
      sudo apt-get update 2>/dev/null

    else
      echo "Check Your OS release"
      exit 0
    fi

    ### ETCD
    DOWNLOAD_URL=http://${REPO_URL}/etcd
    sudo mkdir -p ${CUBE_TMP}/cube/etcd/etcd-download-test
    sudo wget ${DOWNLOAD_URL}/etcd -P ${CUBE_TMP}/cube/etcd/etcd-download-test/
    sudo wget ${DOWNLOAD_URL}/etcdctl -P ${CUBE_TMP}/cube/etcd/etcd-download-test/

    ### Helm
    DOWNLOAD_URL=http://${REPO_URL}/helm
    sudo mkdir -p ${CUBE_TMP}/cube/binary/
    sudo wget ${DOWNLOAD_URL}/helm -P ${CUBE_TMP}/cube/binary/
    
    ### system-default
    echo "### SYSTEM Default Package install ###"
    sudo apt-get install -y net-tools 2>/dev/null
    sudo apt-get install -y wget 2>/dev/null
    sudo apt-get install -y nfs-kernel-server 2>/dev/null
    sudo apt-get install -y selinux-basics 2>/dev/null

    ### runtime
    echo "### Container Runtime install ###"
    sudo apt-get install -y containerd.io

    INSTALL_KUBEADM_VERSION=`sudo apt-cache showpkg kubeadm | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`
    INSTALL_KUBECTL_VERSION=`sudo apt-cache showpkg kubectl | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`
    INSTALL_KUBELET_VERSION=`sudo apt-cache showpkg kubelet | grep ${CUBE_VERSION} | awk {'print $1'} | sort -t '.' -k3 -n | uniq | tail -n 1`

    sudo apt-get install -y kubectl=${INSTALL_KUBECTL_VERSION} 2>/dev/null
    sudo apt-get install -y kubelet=${INSTALL_KUBELET_VERSION} 2>/dev/null
    sudo apt-get install -y kubeadm=${INSTALL_KUBEADM_VERSION} 2>/dev/null

    ### utils
    echo "### Requiet Utils install ###"
    sudo apt-get install -y jq 2>/dev/null

    echo "### Private Repo Certificate ca.crt copy ###"
    sudo mkdir -p /etc/docker/certs.d/${REPO_URL}    
    sudo wget https://${HARBOR_URL}/ca.crt --no-check-certificate -P /etc/docker/certs.d/${HARBOR_URL}/

    DOWNLOAD_URL=http://${REPO_URL}/sshpass
    sudo wget ${DOWNLOAD_URL}/sshpass -P /usr/local/bin/ && sudo chmod 755 /usr/local/bin/sshpass
  else
    echo "CUBE Network type is ${NETWORK_TYPE} Check variable in cube_env file \"NETWORK_TYPE\""
    echo "Bye Bye"
    sleep 3
    exit 0
  fi
fi

echo "### Firewalld Disable ###"
sudo systemctl stop ufw
sudo systemctl disable ufw

if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
  echo "### Binary File Copy ###"
  sudo cp -ap ${CUBE_TMP}/cube/binary/helm /usr/local/bin/
  sudo ln -s /usr/local/bin/helm /usr/bin/helm && sudo chmod 755 /usr/local/bin/helm
fi
