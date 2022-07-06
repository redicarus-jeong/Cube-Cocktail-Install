#!/bin/bash

MASTER_HOSTNAME=("master01" "master02" "master03")
MASTER_NODE_IP=("" "" "")

### kubelet version upgrade node drain option
NODE_DRAIN="no"

###################
### MASTER NODE ###
###################

if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ] || [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ] || [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ]; then

    CURRENT_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}' | awk -F '.' {'print $2'}`
    CURRENT_INSTALL_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}'`
    TASK_VERSION=`expr $CURRENT_VERSION + 1`
    UPGRADE_VERSION="1.${TASK_VERSION}"

    ### kubeadm upgrade ###
    INSTALL_KUBEADM_VERSION=`sudo yum --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

    sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

    UPGRADE_CURRENT_INSTALL_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}'`
    UPGRADE_CURRENT_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}' | awk -F '.' {'print $2'}`
    
    sudo kubeadm version
    
    if [ ${UPGRADE_CURRENT_VERSION} -eq 16 ]; then
      sudo kubeadm upgrade plan v${UPGRADE_CURRNET_INSTALL_VERSION} --ignore-preflight-errors=CoreDNSUnsupportedPlugins
    else
      sudo kubeadm upgrade plan v${UPGRADE_CURRNET_INSTALL_VERSION}
    fi

    echo "##########################################################"
    echo "### Will you proceed with the Kubernetes UPGRADE Task? ###"
    echo "##########################################################"
    echo ""
    echo "### Type "yes" if you are going to work ###"
    echo ""
    echo -n "yes or no : " && read UPGRADE_CHECK

    if [ "${UPGRADE_CHECK}" != "yes" ]; then

    echo ""
    echo "#################################"
    echo "### Plz Upgrade Version Check ###"
    echo "#################################"
    sleep 2
    echo ""
    echo "STOP The \"kubernetes Task\" KUBEADM Package RESET"
    echo ""
    sleep 2
    echo "### kubeadm remove ${INSTALL_KUBEADM_VERSION} ###"
    echo ""
    sleep 2
    sudo yum remove -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes
    echo ""
    echo "### kubeadm install Current Version"
    echo ""
    sleep 2
    sudo yum install -y kubeadm-${CURRENT_INSTALL_VERSION} --disableexcludes=kubernetes

    exit 0

    fi
    ########################### 
    ### Master Node Upgrade ###
    ########################### 
    if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
      if [ ${UPGRADE_CURRENT_VERSION} -lt 15 ]; then
        sudo kubeadm upgrade apply v${UPGRADE_CURRENT_INSTALL_VERSION}
      elif [ ${UPGRADE_CURRENT_VERSION} -ge 15 ]; then
        if [ ${UPGRADE_CURRENT_VERSION} -eq 16 ]; then
          sudo kubeadm upgrade apply v${UPGRADE_CURRENT_INSTALL_VERSION} --certificate-renewal=false --ignore-preflight-errors=CoreDNSUnsupportedPlugins
        else
          sudo kubeadm upgrade apply v${UPGRADE_CURRENT_INSTALL_VERSION} --certificate-renewal=false
        fi
      fi
    elif [ "${HOSTNAME}" == "${MASTER_HOSTNAME[1]}" ] || [ "${HOSTNAME}" == "${MASTER_HOSTNAME[2]}" ] ; then
      if [ ${UPGRADE_CURRENT_VERSION} -lt 15 ]; then
        sudo kubeadm upgrade node experimental-control-plane
      elif [ ${UPGRADE_CURRENT_VERSION} -eq 15 ]; then
        sudo kubeadm upgrade node --certificate-renewal=false experimental-control-plane
      elif [ ${UPGRADE_CURRENT_VERSION} -ge 16 ]; then
        sudo kubeadm upgrade node --certificate-renewal=false
      fi
    fi
   
    ##################
    ### Node Drain ###
    ##################
    if [ ${NODE_DRAIN} == "yes" ]; then
      kubectl drain ${HOSTNAME} --ignore-daemonsets --delete-local-data
    fi

    ################################
    ### kubelet, kubectl upgrade ###
    ################################
    INSTALL_KUBECTL_VERSION=`sudo yum --showduplicates list kubectl --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
    INSTALL_KUBELET_VERSION=`sudo yum --showduplicates list kubelet --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

    sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
    sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes

    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

    ##################
    ### Node Drain ###
    ##################
    if [ ${NODE_DRAIN} == "yes" ]; then
      kubectl uncordon ${HOSTNAME}
    fi

###################
### WORKER NODE ###
###################

elif [ "${HOSTNAME}" != "${MASTER_HOSTNAME[0]}" ] || [ "${HOSTNAME}" != "${MASTER_HOSTNAME[1]}" ] || [ "${HOSTNAME}" != "${MASTER_HOSTNAME[2]}" ]; then

    CURRENT_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}' | awk -F '.' {'print $2'}`
    TASK_VERSION=`expr $CURRENT_VERSION + 1`
    UPGRADE_VERSION="1.${TASK_VERSION}"
    CURRENT_INSTALL_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}'`

    ### kubeadm upgrade ###
    INSTALL_KUBEADM_VERSION=`sudo yum --showduplicates list kubeadm --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`

    sudo yum install -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes

    echo "##########################################################"
    echo "### Will you proceed with the Kubernetes UPGRADE Task? ###"
    echo "##########################################################"
    echo ""
    echo "### Type "yes" if you are going to work ###"
    echo ""
    echo -n "yes or or : " && read UPGRADE_CHECK

    if [ "${UPGRADE_CHECK}" != "yes" ]; then

    echo ""
    echo "#################################"
    echo "### Plz Upgrade Version Check ###"
    echo "#################################"
    sleep 2
    echo ""
    echo "STOP The \"kubernetes Task\" KUBEADM Package RESET"
    echo ""
    sleep 2
    echo "### kubeadm remove ${INSTALL_KUBEADM_VERSION} ###"
    echo ""
    sleep 2
    sudo yum remove -y kubeadm-${INSTALL_KUBEADM_VERSION} --disableexcludes=kubernetes
    echo ""
    echo "### kubeadm install Current Version"
    echo ""
    sleep 2
    sudo yum install -y kubeadm-${CURRENT_INSTALL_VERSION} --disableexcludes=kubernetes

    exit 0

    fi

    KUBELET_CONFIG_VERSION=`sudo rpm -qa | grep kubeadm | awk -F '-' '{print $2}'`
    sudo kubeadm upgrade node

    ### kubelet, kubectl upgrade ###
    INSTALL_KUBECTL_VERSION=`sudo yum --showduplicates list kubectl --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
    INSTALL_KUBELET_VERSION=`sudo yum --showduplicates list kubelet --disableexcludes=kubernetes | grep ${UPGRADE_VERSION} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1`
    
    sudo yum install -y kubectl-${INSTALL_KUBECTL_VERSION} --disableexcludes=kubernetes
    sudo yum install -y kubelet-${INSTALL_KUBELET_VERSION} --disableexcludes=kubernetes

    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

fi

