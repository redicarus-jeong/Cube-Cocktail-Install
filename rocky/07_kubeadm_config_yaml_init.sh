#!/bin/bash

### Incloud ENV File ###
source ./cube_env

KUBERNETES_VERSION=`rpm -qa | grep kubeadm | awk -F '-' {'print "v"$2'}`

sudo rm -rf ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
sudo touch ${CUBE_TMP}/cube/temp/kubeadm-config.yaml

cat << EOF | sudo tee ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${NODE_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
etcd:
  external:
    endpoints:
EOF

MASTER_HOSTNAME_LENGTH=${#MASTER_HOSTNAME[@]}

for ((i=0; i<${MASTER_HOSTNAME_LENGTH}; i++)); 
do
  echo "    - https://${MASTER_NODE_IP[i]}:2379" | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
done

cat << EOF | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/etcd/server.crt
    keyFile: /etc/kubernetes/pki/etcd/server.key
networking:
  dnsDomain: cluster.local
  serviceSubnet: ${SERVICE_SUBNET}
  podSubnet: ${POD_SUBNET}
kubernetesVersion: ${KUBERNETES_VERSION}
controlPlaneEndpoint: ${NODE_IP}:6443
clusterName: ${CLUSTER_NAME}
certificatesDir: /etc/kubernetes/pki
apiServer:
  extraArgs:
    bind-address: "0.0.0.0"
    apiserver-count: "3"
    secure-port: "6443"
    default-not-ready-toleration-seconds: "30"
    default-unreachable-toleration-seconds: "30"
    encryption-provider-config: /etc/kubernetes/secrets_encryption.yaml
    audit-log-maxage: "7"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-log-path: /var/log/kubernetes/kubernetes-audit.log
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    audit-webhook-config-file: /etc/kubernetes/audit-webhook
  extraVolumes:
  - name: audit-policy
    hostPath: /etc/kubernetes
    mountPath: /etc/kubernetes
    pathType: DirectoryOrCreate
    readOnly: true
  - name: k8s-audit
    hostPath: /var/log/kubernetes
    mountPath: /var/log/kubernetes
    pathType: DirectoryOrCreate
  certSANs:
  - ${NODE_IP}
  - localhost
  - 127.0.0.1
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    node-monitor-period: 2s
    node-monitor-grace-period: 16s
EOF

KUBEADM_CUBE_VERSION=`echo "${CUBE_VERSION}" | awk -F "." '{print $2}'`
if [ $KUBEADM_CUBE_VERSION -ge 18 ]; then
  echo "    secure-port: \"10257\"" | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
fi
cat << EOF | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
EOF
if [ $KUBEADM_CUBE_VERSION -ge 18 ]; then
  echo "    secure-port: \"10259\"" | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
fi


if [ "${PRIVATE_REPO}" == "enable" ]; then
  echo "imageRepository: ${HARBOR_URL}/k8s.gcr.io" | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml

elif [ "${PRIVATE_REPO}" == "disable" ]; then
  echo "imageRepository: k8s.gcr.io" | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
fi

cat << EOF | sudo tee --append ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: iptables
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
nodeStatusUpdateFrequency: 4s
readOnlyPort: 0
clusterDNS:
- ${CLUSTER_DNS}
rotateCertificates: true
serverTLSBootstrap: true
EOF
