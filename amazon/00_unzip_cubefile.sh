#!/bin/bash

### Incloud ENV File ###
source ./cube_env

if [[ ! -d ${CUBE_WORK} ]]; then # Does not exist the Dir
  echo "Make the Directory"
  sudo mkdir -p ${CUBE_WORK}
fi

### Create Task Tmp directroy ###
sudo mkdir -p ${CUBE_TMP}/cube/temp

if [ "${NETWORK_TYPE}" == "public" ]; then
  echo ""
  echo "################################################"
  echo "### CUBE Install Network ENV ${NETWORK_TYPE} ###"
  echo "################################################"
  echo ""

  sudo yum install -y containerd

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

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF


  sudo yum update repo -y

  INSTALL_KUBEADM_VERSION=`sudo yum --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBECTL_VERSION=`sudo yum --showduplicates list kubectl --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBELET_VERSION=`sudo yum --showduplicates list kubelet --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

  sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

  ### utils
  echo "### Requiet Utils install ###"
  sudo yum install -y jq
  sudo amazon-linux-extras install epel -y
  sudo yum-config-manager --enable epel
  sudo yum install sshpass -y
  sleep 2

elif [ "${NETWORK_TYPE}" == "private" ]; then

  echo "Amazon Linux Not Support Private Network Env Check Your OS release"
  exit 0

else
  echo "CUBE Network type is ${NETWORK_TYPE} Check variable in cube_env file \"NETWORK_TYPE\""
  echo "Bye Bye"
  sleep 3
  exit 0
fi

sudo echo "### Firewalld Disable ###"
sudo service firewalld stop
sudo systemctl disable firewalld

sudo echo "### Selinux Disable ###"
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
  echo "### Binary File Copy ###"
  sudo cp -ap ${CUBE_TMP}/cube/binary/helm /usr/local/bin/ && sudo chmod 755 /usr/local/bin/helm
  sudo ln -s /usr/local/bin/helm /usr/bin/helm
fi


