#!/bin/bash

source ./cube_env

CALICO_VERSION=3.17

DOWNLOAD_URL=http://${HARBOR_URL}/calico
#sudo mkdir -p ${CUBE_TMP}/cube/download/manifest/calico/${CALICO_VERSION}
sudo wget ${DOWNLOAD_URL}/calico-${CALICO_VERSION}.yaml -O ./calico-${CALICO_VERSION}.yaml

sudo sed -i -r "s/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/" ./calico-${CALICO_VERSION}.yaml
sudo sed -i -r 's@#   value: "192.168.0.0/16"@  value: '"${POD_SUBNET}"'@' ./calico-${CALICO_VERSION}.yaml
sudo sed -r -i "s/image: /image\: ${HARBOR_URL}\//" ./calico-${CALICO_VERSION}.yaml