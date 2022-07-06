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

  ### system-default
  sudo echo "### SYSTEM Default Package install ###"
  sudo yum install -y net-tools
  sudo yum install -y wget
  sudo yum install -y epel-release
  sudo yum install -y nfs-utils
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2

  ### runtime
  echo "### Container Runtime install ###"
  sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
  
  sudo yum clean all
  CONTAINERD_IO_VERSION=1.4
  INSTALL_CONTAINERD_IO_VERSION_PATCH=`sudo yum --showduplicates list containerd.io | grep $CONTAINERD_IO_VERSION | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  sudo yum install -y containerd.io-$INSTALL_CONTAINERD_IO_VERSION_PATCH

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
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
exclude=kubelet kubeadm kubectl
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  sudo yum clean all

  INSTALL_KUBEADM_VERSION=`sudo yum -y --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBECTL_VERSION=`sudo yum -y --showduplicates list kubectl --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBELET_VERSION=`sudo yum -y --showduplicates list kubelet --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

  sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

  ### utils
  echo "### Requiet Utils install ###"
  sudo yum install -y jq
  sudo yum install -y sshpass
  sleep 2

elif [ "${NETWORK_TYPE}" == "private" ]; then
  if [ "${PRIVATE_REPO}" == "enable" ]; then
    echo ""
    echo "########################"
    echo "### ADD Package Repo ###"
    echo "########################"
    echo ""

    sudo mv /etc/yum.repos.d /etc/yum.repos.d.bak
    sudo mkdir -p /etc/yum.repos.d
    sudo chown root:root /etc/yum.repos.d
    sudo chmod 0755 /etc/yum.repos.d

    if [ ${OS_VERSION} == "8.5" ]; then
      sudo touch /etc/yum.repos.d/85rpm.repo

cat <<EOF | sudo tee /etc/yum.repos.d/85rpm.repo
[AppStream]
name=AppStream repository
baseurl=http://${REPO_URL}/8.5/AppStream
gpgcheck=0
enabled=1

[BaseOS]
name=BaseOS repository
baseurl=http://${REPO_URL}/8.5/BaseOS
gpgcheck=0
enabled=1

[cube-rocky]
name=cube kubernetes repository
baseurl=http://${REPO_URL}/8.5/Cube
gpgcheck=0
enabled=1
EOF

    else
      echo "Check Your OS release"
      exit 0
    fi

      ### system-default
      echo "### SYSTEM Default Package install ###"
      sudo yum install -y net-tools
      sudo yum install -y wget
      sudo yum install -y nfs-utils

      ### ETCD
      DOWNLOAD_URL=http://${REPO_URL}/etcd
      sudo mkdir -p ${CUBE_TMP}/cube/etcd/etcd-download-test
      sudo wget ${DOWNLOAD_URL}/etcd -P ${CUBE_TMP}/cube/etcd/etcd-download-test/
      sudo wget ${DOWNLOAD_URL}/etcdctl -P ${CUBE_TMP}/cube/etcd/etcd-download-test/

      ### Helm
      DOWNLOAD_URL=http://${REPO_URL}/helm
      sudo mkdir -p ${CUBE_TMP}/cube/binary/
      sudo wget ${DOWNLOAD_URL}/helm -P ${CUBE_TMP}/cube/binary/

      ### runtime
      echo "### Container Runtime install ###"
      sudo yum install -y containerd.io

      INSTALL_KUBEADM_VERSION=`sudo yum -y --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
      INSTALL_KUBECTL_VERSION=`sudo yum -y --showduplicates list kubectl --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
      INSTALL_KUBELET_VERSION=`sudo yum -y --showduplicates list kubelet --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

      sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
      sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes
      sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

      ### utils
      sudo echo "### Requiet Utils install ###"
      sudo yum install -y jq

      echo "### Private Repo Certificate ca.crt copy ###"
      sudo mkdir -p /etc/docker/certs.d/${HARBOR_URL}
      sudo wget https://${HARBOR_URL}/ca.crt --no-check-certificate -P /etc/docker/certs.d/${HARBOR_URL}/

      DOWNLOAD_URL=http://${REPO_URL}/sshpass
      sudo wget ${DOWNLOAD_URL}/sshpass -P /usr/local/bin/ && sudo chmod 755 /usr/local/bin/sshpass

  elif [ "${PRIVATE_REPO}" == "disable" ]; then
      ### system-default
  sudo echo "### SYSTEM Default Package install ###"
  sudo yum install -y net-tools
  sudo yum install -y wget
  sudo yum install -y epel-release
  sudo yum install -y nfs-utils
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2

  ### runtime
  echo "### Container Runtime install ###"
  sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

  sudo yum install -y containerd.io

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
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  sudo yum update repo -y

  INSTALL_KUBEADM_VERSION=`sudo yum -y --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBECTL_VERSION=`sudo yum -y --showduplicates list kubectl --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
  INSTALL_KUBELET_VERSION=`sudo yum -y --showduplicates list kubelet --disableexcludes=kubernetes | grep ${CUBE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

  sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes
  sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

  ### utils
  echo "### Requiet Utils install ###"
  sudo yum install -y jq
  sudo yum install -y sshpass
  sleep 2
  else
    echo "PRIVATE_REPO Type Check Plz enable & disable"
    exit 0
  fi
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
