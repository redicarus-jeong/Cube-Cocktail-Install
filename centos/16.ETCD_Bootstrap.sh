#!/usr/bin/env bash

### this script is etcd setup to bootstrap
### date : 2022-07-05
### author : redicarus.jeong
### description

source ./cube.env

##### 16. etcd setup to bootstrap
echo "====> 16. etcd setup to bootstrap"

### 16-1. etcd Reset ###
echo "====> 16-1. etcd Reset"
sudo rm -rf /etc/etcd/etcd.conf
sudo rm -rf /etc/systemd/system/etcd.service
sudo rm -rf /usr/bin/etcd
sudo rm -rf /usr/bin/etcdctl
sudo rm -rf ${CUBE_DATA}/etcd


### 16-2. Create ETCD USER ###
echo "====> 16-2. Create ETCD USER"
sudo useradd -c "etcd user" -s /sbin/nologin etcd


### 16-3. ETCD Certificate Config Host variable ###
echo "====> 16-3. ETCD Certificate Config Host variable"
if [ ${#MASTER_HOSTNAME[@]} -eq 1 ]; then
  MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380"
elif [ ${#MASTER_HOSTNAME[@]} -eq 2 ]; then
  MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380,${MASTER_HOSTNAME[1]}=https://${MASTER_NODE_IP[1]}:2380"
elif [ ${#MASTER_HOSTNAME[@]} -eq 3 ]; then
  MULTI_HOST="${MASTER_HOSTNAME[0]}=https://${MASTER_NODE_IP[0]}:2380,${MASTER_HOSTNAME[1]}=https://${MASTER_NODE_IP[1]}:2380,${MASTER_HOSTNAME[2]}=https://${MASTER_NODE_IP[2]}:2380"
else
  echo "Not found master_hostname variable"
  echo "Check cube_env File"
  exit 0
fi


### 16-4. Create ETCD Job Directroy and Owner Permission setup ###
echo "====> 16-4. Create ETCD Job Directroy and Owner Permission setup"
if [ -d /var/lib/etcd ]; then
  sudo rm -rf /var/lib/etcd
fi
sudo mkdir -p /var/lib/etcd

if [ -d /etc/etcd ]; then
  sudo rm -rf /etc/etcd
fi
sudo mkdir -p /etc/etcd

if [ -d ${CUBE_DATA}/etcd ]; then
  sudo rm -rf ${CUBE_DATA}/etcd
fi
sudo mkdir -p ${CUBE_DATA}/etcd

sudo chown -R etcd:etcd ${CUBE_DATA}/etcd



### 16-5. Copy ETCD binary file ###
echo "====> 16-5. Copy ETCD binary file"
sudo cp ${CUBE_TEMP}/cube/etcd/etcd-download-test/etcd /usr/bin/etcd && sudo chmod +x /usr/bin/etcd
sudo cp ${CUBE_TEMP}/cube/etcd/etcd-download-test/etcdctl /usr/bin/etcdctl && sudo chmod +x /usr/bin/etcdctl


### 16-6. Create ETCD Serivce File ###
echo "====> 16-6. Create ETCD Serivce File"
cat << EOF | sudo tee /etc/systemd/system/etcd.service
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


### 16-7. Create ETCD Config File ###
echo "====> 16-7. Create ETCD Config File"
cat << EOF | sudo tee /etc/etcd/etcd.conf
##############
### member ###
##############
ETCD_NAME=${HOSTNAME}
ETCD_DATA_DIR=${CUBE_DATA}/etcd

###############
### cluster ###
###############
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${IF_IPADDRESS}:2380
ETCD_INITIAL_CLUSTER=$MULTI_HOST
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER_TOKEN=${CLUSTER_NAME}
ETCD_LISTEN_PEER_URLS=https://0.0.0.0:2380
ETCD_ADVERTISE_CLIENT_URLS=https://${IF_IPADDRESS}:2379
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


### 16-8. ETCD Service enable, reload, stop, start ###
echo "====> 16-8. ETCD Service enable, reload, stop, start"
sudo systemctl stop etcd
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
sleep 2