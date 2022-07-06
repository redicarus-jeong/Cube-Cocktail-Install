#!/bin/bash
### Reset ###
sudo rm -rf /etc/etcd/etcd.conf
sudo rm -rf /etc/systemd/system/etcd.service
sudo rm -rf /usr/bin/etcd
sudo rm -rf /usr/bin/etcdctl
sudo rm -rf ${CUBE_DATA}/etcd

################################
### Incloud Install Env File ###
################################
source ./cube_env

### Create ETCD USER ###
sudo useradd -s /sbin/nologin etcd

### ETCD Certificate Config Host variable ###
if [ ${#MASTER_HOSTNAME[@]} = 3 ]; then
  MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380,${MASTER_HOSTNAME[1]}=https://${MASTER_NODE_IP[1]}:2380,${MASTER_HOSTNAME[2]}=https://${MASTER_NODE_IP[2]}:2380"
    elif [ ${#MASTER_HOSTNAME[@]} = 2 ]; then
      MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380,${MASTER_HOSTNAME[1]}=https://${MASTER_NODE_IP[1]}:2380"
    elif [ ${#MASTER_HOSTNAME[@]} = 1 ]; then
      MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380"
  else
    echo "Not found master_hostname variable"
    echo "Check cube_env File"
    exit 0
fi

### Create ETCD Job Directroy ###
sudo mkdir -p /var/lib/etcd
sudo mkdir -p /etc/etcd
sudo mkdir -p ${CUBE_DATA}/etcd

### Owner, Permit Config ###
sudo chown -R etcd.etcd ${CUBE_DATA}/etcd

### Copy ETCD binary file ###
sudo cp ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd /usr/bin/etcd && sudo chmod +x /usr/bin/etcd
sudo cp ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl /usr/bin/etcdctl && sudo chmod +x /usr/bin/etcdctl

### Create ETCD Serivce File ###
cat << EOF | sudo tee ${CUBE_TMP}/cube/temp/etcd.service
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
User=etcd
ExecStart=/usr/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

### ETCD Serivce File copy ###
sudo chown root.root ${CUBE_TMP}/cube/temp/etcd.service
sudo cp ${CUBE_TMP}/cube/temp/etcd.service /etc/systemd/system/etcd.service
sudo rm -rf ${CUBE_TMP}/cube/temp/etcd.service

### Create ETCD Config File ###

cat << EOF | sudo tee ${CUBE_TMP}/cube/temp/etcd.conf
##############
### member ###
##############
ETCD_NAME=${HOSTNAME}
ETCD_DATA_DIR=${CUBE_DATA}/etcd

###############
### cluster ###
###############
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${NODE_IP}:2380
#ETCD_INITIAL_CLUSTER=${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380,${MASTER_HOSTNAME[1]}=https://${MASTER_NODE_IP[1]}:2380,${MASTER_HOSTNAME[2]}=https://${MASTER_NODE_IP[2]}:2380
ETCD_INITIAL_CLUSTER=$MULTI_HOST
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER_TOKEN=${CLUSTER_NAME}
ETCD_LISTEN_PEER_URLS=https://0.0.0.0:2380
ETCD_ADVERTISE_CLIENT_URLS=https://${NODE_IP}:2379
ETCD_LISTEN_CLIENT_URLS="https://0.0.0.0:2379"

#############
### proxy ###
#############
ETCD_PROXY="off"

################
### security ###
################
ETCD_CLIENT_CERT_AUTH="true"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE=/etc/kubernetes/pki/etcd/ca.crt
ETCD_CERT_FILE=/etc/kubernetes/pki/etcd/server.crt
ETCD_KEY_FILE=/etc/kubernetes/pki/etcd/server.key
ETCD_PEER_TRUSTED_CA_FILE=/etc/kubernetes/pki/etcd/ca.crt
ETCD_PEER_CERT_FILE=/etc/kubernetes/pki/etcd/peer.crt
ETCD_PEER_KEY_FILE=/etc/kubernetes/pki/etcd/peer.key
EOF


### ETCD Serivce File copy ###
sudo chown root.root ${CUBE_TMP}/cube/temp/etcd.conf
sudo cp ${CUBE_TMP}/cube/temp/etcd.conf /etc/etcd/etcd.conf
sudo rm -rf ${CUBE_TMP}/cube/temp/etcd.conf

### ETCD Service enable, reload, stop, start ###
sudo systemctl enable etcd
sudo systemctl stop etcd
sudo systemctl daemon-reload
sudo systemctl start etcd
sleep 2