#!/bin/bash

source ./cube_env
OLD_ETCD_VERSION=`etcd --version | awk {'print $3'} | head -n 1`
NEW_ETCD_VERSION=3.4.13
ETCD_PATH=`which etcd`
ETCDCTL_PATH=`which etcdctl`

### ETCD
DOWNLOAD_URL=http://${REPO_URL}/etcd/etcd-download-test-v${NEW_ETCD_VERSION}
sudo mkdir -p ${CUBE_TMP}/cube/etcd/etcd-download-test
sudo wget ${DOWNLOAD_URL}/etcd -O ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd-${NEW_ETCD_VERSION}
sudo wget ${DOWNLOAD_URL}/etcdctl -O ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl-${NEW_ETCD_VERSION}

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
    echo "STOP The \"ETCD Task\" ETCD Package RESET"
    echo ""
    sleep 2
    sudo rm -f ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd*
    sudo rm -rf ${CUBE_TMP}/cube/etcd/etcd-download-test
    exit 0
fi

####################
### ETCD Upgrade ###
####################

echo "####################"
echo "### ETCD Upgrade ###"
echo "####################"

echo "Stop ETCD Service"
sudo systemctl stop etcd
sudo cp ${ETCD_PATH} ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd_${OLD_ETCD_VERSION}
sudo cp ${ETCDCTL_PATH} ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl_${OLD_ETCD_VERSION}
sudo rm -rf ${ETCD_PATH}
sudo rm -rf ${ETCDCTL_PATH}

echo "Copy ETCD Binary"
sudo chmod 755 ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd-${NEW_ETCD_VERSION}
sudo chmod 755 ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl-${NEW_ETCD_VERSION}
sudo cp ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd-${NEW_ETCD_VERSION} ${ETCD_PATH}
sudo cp ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl-${NEW_ETCD_VERSION} ${ETCDCTL_PATH}

sudo chown root:root ${ETCD_PATH}
sudo chown root:root ${ETCDCTL_PATH}

echo "Start ETCD Service"
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl status etcd

################################
##### ETCD Health Check ########
################################

echo "################################"
echo "##### ETCD Health Check ########"
echo "################################"

echo "ETCD Version"
etcd --version

echo "sudo ETCDCTL_API=3 etcdctl --endpoints=https://[127.0.0.1]:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key member list"