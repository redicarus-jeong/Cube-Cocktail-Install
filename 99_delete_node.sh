#!/bin/bash

### Incloud ENV File ###
source ./cube_env

KUBE_MASTER_CHECK=`kubectl cluster-info 2> /dev/null | head -n 1 | awk {'print $1 " " $2 " " $3 " " $3 " " $4'}`

if [ "${KUBE_MASTER_CHECK}" == "Kubernetes master is running" ]; then
  kubectl cordon ${HOSTNAME}
  sleep 2

  kubectl drain ${HOSTNAME} --delete-local-data --force --ignore-daemonsets
  sleep 2

  kubectl delete node ${HOSTNAME}
  sleep 2

  sudo kubeadm reset -f
  sleep 2

elif [ "${HOSTNAME}" != "${MASTER_HOSTNAME[0]}" ] || [ "${HOSTNAME}" != "${MASTER_HOSTNAME[1]}" ] || [ "${HOSTNAME}" != "${MASTER_HOSTNAME[2]}" ]; then
  echo ""
  echo "Plz check \"kubectl cordon ${HOSTNAME}\""
  echo "Plz check \"kubectl drain ${HOSTNAME} --delete-local-data --force --ignore-daemonsets\""
  echo "Plz check \"kubectl delete node ${HOSTNAME}\""
  echo ""
  echo "Task continue \"kubeadm reset\" This commnad result is this ${HOSTNAME} node reset"
  echo ""
  echo "\"yes\" is run task "
  echo ""
  echo "#####################"
  echo "### \"yes\" or \"no\" ###"
  echo "#####################"
  echo ""
  read KUBECTL_CHECK
  echo ""
  echo "Input command \"${KUBECTL_CHECK}\""
  echo ""
  sleep 2

  if [ "${KUBECTL_CHECK}" == "yes" ]; then
    echo "Start \"kubeadm reset\" Task"
    sudo kubeadm reset -f
  elif [ "${KUBECTL_CHECK}" == "no" ]; then
    echo "Bye Bye"
    exit 0
  else
    echo "Input plz \"yes\" or \"no\""
    exit 0
  fi

else
  echo "Plz check \"kubectl cordon ${HOSTNAME}\""
  echo "Plz check \"kubectl drain ${HOSTNAME} --delete-local-data --force --ignore-daemonsets\""
  echo "Plz check \"kubectl delete node ${HOSTNAME}\""

  exit 0

fi 


### kubernetes daemon stop and disables
sudo systemctl stop containerd
sleep 2
sudo systemctl disable containerd
sudo systemctl daemon-reload
sleep 2

sudo systemctl stop kubelet
sleep 2
sudo systemctl disable kubelet
sudo systemctl daemon-reload
sleep 2

sudo systemctl stop docker
sleep 2
sudo systemctl disable docker
sudo systemctl daemon-reload
sleep 2

sudo systemctl stop systemd-resolved
sleep 2
sudo systemctl disable systemd-resolved
sudo systemctl daemon-reload
sleep 2

### RPM Delete
sudo yum remove -y \
      kube* \

sudo rm -rf /etc/yum.repos.d/kubernetes.repo
sudo yum clean all

sudo yum remove -y \
      containerd.io \
      docker-ce \
      docker-ce-cli \

sudo rm -rf /etc/yum.repos.d/docker-ce.repo
sudo yum clean all

### IPTABLE Task 
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

### CNI Config delete
sudo rm -rf /etc/cni/net.d/*

echo ""
echo "${HOSTNAME} node delete Finish"
echo ""

sudo systemctl stop etcd
sudo systemctl disable etcd

sudo rm -rf ${CUBE_WORK}
sudo rm -rf ${CUBE_DATA}

