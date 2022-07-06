#!/bin/bash

### Incloud ENV File ###
source ./cube_env

echo "### Create Job Directory ###"
sudo mkdir -p ${CUBE_TMP}/cube/exec

echo "### Containerd Config ###"
sudo mkdir -p /etc/{containerd,sysconfig}
sudo mkdir -p ${CUBE_DATA}/containerd

sudo rm -rf /etc/containerd/config.toml
sudo containerd config default | sudo tee ${CUBE_TMP}/cube/temp/config.toml
sudo mv ${CUBE_TMP}/cube/temp/config.toml /etc/containerd/config.toml
sudo sed -i -r -e "/plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options/a\            SystemdCgroup = true" /etc/containerd/config.toml
sudo sed -i -r -e "s@\/var\/lib@${CUBE_DATA}@" /etc/containerd/config.toml

if [ "${PRIVATE_REPO}" == "enable" ]; then
  sudo sed -i -r -e "s/k8s.gcr.io/${HARBOR_URL}\/k8s.gcr.io/" /etc/containerd/config.toml
fi

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

CALICO_CUBE_VERSION=`echo ${CUBE_VERSION} | awk -F "." '{print $2}'`

if [ "${CALICO_CUBE_VERSION}" -lt 15 ]; then
### 3.9(1.13, 1.14)
cat <<EOF | sudo tee /etc/modules-load.d/calico.conf
nf_conntrack_netlink
ip_tables
ip6_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF

sudo modprobe nf_conntrack_netlink
sudo modprobe ip_tables
sudo modprobe ip6_tables
sudo modprobe ip_set
sudo modprobe xt_set
sudo modprobe ipt_set
sudo modprobe ipt_rpfilter
sudo modprobe ipt_REJECT
sudo modprobe ipip

elif [ "${CALICO_CUBE_VERSION}" -ge 15 ]; then
# 3.13(1.15, 1.16), 3.17(1.17, 1.18, 1.19)
cat <<EOF | sudo tee /etc/modules-load.d/calico.conf
ip_set
ip_tables
ip6_tables
ipt_REJECT
ipt_rpfilter
ipt_set
nf_conntrack_netlink
nf_conntrack_proto_sctp
sctp
xt_addrtype
xt_comment
xt_conntrack
xt_icmp
xt_icmp6
xt_ipvs
xt_mark
xt_multiport
xt_rpfilter
xt_sctp
xt_set
xt_u32
ipip
EOF

sudo modprobe ip_set
sudo modprobe ip_tables
sudo modprobe ip6_tables
sudo modprobe ipt_REJECT
sudo modprobe ipt_rpfilter
sudo modprobe ipt_set
sudo modprobe nf_conntrack_netlink
sudo modprobe nf_conntrack_proto_sctp
sudo modprobe sctp
sudo modprobe xt_addrtype
sudo modprobe xt_comment
sudo modprobe xt_conntrack
sudo modprobe xt_icmp
sudo modprobe xt_icmp6
sudo modprobe xt_ipvs
sudo modprobe xt_mark
sudo modprobe xt_multiport
sudo modprobe xt_rpfilter
sudo modprobe xt_sctp
sudo modprobe xt_set
sudo modprobe xt_u32
sudo modprobe ipip

fi

sudo modprobe overlay
sudo modprobe br_netfilter

echo "### Iptables setting ###"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "### Disable swap ###"
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

if [ $GPU_NODE == "enable" ]; then
  if [ $NETWORK_TYPE == "public" ]; then
    ### Add nvidia-container-runtime repo ###
    distribution=$(. /etc/os-release;echo ${ID}${VERSION_ID})
    curl -s -L https://nvidia.github.io/nvidia-container-runtime/${distribution}/nvidia-container-runtime.repo | \
      sudo tee /etc/yum.repos.d/nvidia-container-runtime.repo
    sudo yum clean all
    ### install nvidia-container-runtime ###
    sudo yum install -y nvidia-container-runtime

  elif [ $NETWORK_TYPE == "private" ]; then
    sudo yum install -y nvidia-container-runtime
  fi

  ### kubelet service config GPU ###
  echo "### Kubelet Service Config ###"
cat <<EOF | sudo tee /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--log-dir=${CUBE_WORK}/log \
--logtostderr=false \
--v=2 \
--container-runtime=remote \
--runtime-request-timeout=15m \
--container-runtime-endpoint=unix:///run/containerd/containerd.sock \
--node-labels=nvidia.com/gpu='',cube.acornsoft.io/clusterid=${CLUSTER_NAME} \
--register-with-taints=nvidia.com/gpu='':NoSchedule"
EOF

  sudo mkdir -p ${CUBE_TMP}/cube/temp/
  NVIDIA_CH_LINE=`cat /etc/containerd/config.toml | grep "SystemdCgroup = true" -n | awk -F ':' '{print $1}'`
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "          [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia]"}1' /etc/containerd/config.toml | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_01 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "             privileged_without_host_devices = false"}1' ${CUBE_TMP}/cube/temp/nvidia_out_01 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_02 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "             runtime_engine = \"\""}1' ${CUBE_TMP}/cube/temp/nvidia_out_02 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_03 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "             runtime_root = \"\""}1' ${CUBE_TMP}/cube/temp/nvidia_out_03 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_04 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "             runtime_type = \"io.containerd.runc.v1\""}1' ${CUBE_TMP}/cube/temp/nvidia_out_04 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_05 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "             [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia.options]"}1' ${CUBE_TMP}/cube/temp/nvidia_out_05 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_06 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "               BinaryName = \"/usr/bin/nvidia-container-runtime\""}1' ${CUBE_TMP}/cube/temp/nvidia_out_06 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_07 1>/dev/null
  NVIDIA_CH_LINE=`expr ${NVIDIA_CH_LINE} + 1`
  sudo awk 'NR=='"${NVIDIA_CH_LINE}"'{print "               SystemdCgroup = true"}1' ${CUBE_TMP}/cube/temp/nvidia_out_07 | sudo tee ${CUBE_TMP}/cube/temp/nvidia_out_08 1>/dev/null

  sudo cat < ${CUBE_TMP}/cube/temp/nvidia_out_08 | sudo tee /etc/containerd/config.toml 1>/dev/null

elif [ $GPU_NODE == "disable" ]; then

### kubelet service config ###
echo "### Kubelet Service Config ###"
cat <<EOF | sudo tee /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--log-dir=${CUBE_WORK}/log \
--logtostderr=false \
--v=2 \
--container-runtime=remote \
--runtime-request-timeout=15m \
--container-runtime-endpoint=unix:///run/containerd/containerd.sock \
--node-labels=cube.acornsoft.io/clusterid=${CLUSTER_NAME}"
EOF

fi

### crictl config ###
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

### crictl image scripts ###
cat << EOF | sudo tee /etc/cron.daily/crictl-image.sh
#!/bin/sh

/usr/bin/crictl ps -a | /usr/bin/grep -v -E "Running|CONTAINER" | /usr/bin/awk '{print \$1}' | xargs /usr/bin/crictl rm && /usr/bin/crictl rmi --prune
exit 0

EOF

### Drop Cache scripts ###
cat << EOF | sudo tee /etc/cron.daily/drop-cache.sh
#!/bin/sh
sync; echo 3 > /proc/sys/vm/drop_caches

exit 0

EOF

sudo chmod 755 /etc/cron.daily/crictl-image.sh /etc/cron.daily/drop-cache.sh

echo "### CUBE Kubernetes service enable & start ###"
sudo systemctl enable containerd
sudo systemctl stop containerd
sudo systemctl daemon-reload
sleep 2
sudo systemctl start containerd
sleep 2
sudo systemctl enable kubelet
sudo systemctl stop kubelet
sudo systemctl daemon-reload
sleep 2
sudo systemctl start kubelet
sleep 2
if [ "${NETWORK_TYPE}" == "private" ]; then
  sudo mkdir -p ${CUBE_TMP}/cube/temp/
  if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
    sudo sed -i -r "s/imageRepository: k8s.gcr.io/imageRepository: ${HARBOR_URL}\/k8s.gcr.io/" ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
  fi
  RUNC_CH_LINE=`cat /etc/containerd/config.toml | sudo grep "registry-1.docker.io" -n | sudo awk -F ':' '{print $1}'`
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"'"${HARBOR_URL}"'\"]"}1' /etc/containerd/config.toml | sudo tee ${CUBE_TMP}/cube/temp/runc_out_01 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "          endpoint = [\"https://'"${HARBOR_URL}"'\"]"}1' ${CUBE_TMP}/cube/temp/runc_out_01 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_02 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "      [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"'"${HARBOR_URL}"'\".tls]"}1' ${CUBE_TMP}/cube/temp/runc_out_02 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_03 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        ca_file = \"/etc/docker/certs.d/'"${HARBOR_URL}"'/ca.crt\""}1' ${CUBE_TMP}/cube/temp/runc_out_03 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_04 1>/dev/null

  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        insecure_skip_verify = true"}1' ${CUBE_TMP}/cube/temp/runc_out_04 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_05 1>/dev/null
  sudo cat < ${CUBE_TMP}/cube/temp/runc_out_05 | sudo tee /etc/containerd/config.toml 1>/dev/null
  
  sudo sed -i -r /plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"/d /etc/containerd/config.toml
  sudo sed -i -r /\"https:\\/\\/registry-1.docker.io\"/d /etc/containerd/config.toml
  sleep 3

  sudo systemctl restart containerd
  sleep 3
elif [ "${NETWORK_TYPE}" == "public" ]; then
  sudo mkdir -p ${CUBE_TMP}/cube/temp/
  if [ "${PRIVATE_REPO}" == "enable"  ]; then
    if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
      sudo sed -i -r "s/imageRepository: k8s.gcr.io/imageRepository: ${HARBOR_URL}\/k8s.gcr.io/" ${CUBE_TMP}/cube/temp/kubeadm-config.yaml
    fi
  fi
  RUNC_CH_LINE=`cat /etc/containerd/config.toml | sudo grep "registry-1.docker.io" -n | sudo awk -F ':' '{print $1}'`
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"'"${HARBOR_URL}"'\"]"}1' /etc/containerd/config.toml | sudo tee ${CUBE_TMP}/cube/temp/runc_out_01 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "          endpoint = [\"https://'"${HARBOR_URL}"'\"]"}1' ${CUBE_TMP}/cube/temp/runc_out_01 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_02 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "      [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"'"${HARBOR_URL}"'\".tls]"}1' ${CUBE_TMP}/cube/temp/runc_out_02 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_03 1>/dev/null
  RUNC_CH_LINE=`expr ${RUNC_CH_LINE} + 1`
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        ca_file = \"/etc/ssl/certs/ca-bundle.crt\""}1' ${CUBE_TMP}/cube/temp/runc_out_03 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_04 1>/dev/null
  sudo awk 'NR=='"${RUNC_CH_LINE}"'{print "        insecure_skip_verify = true"}1' ${CUBE_TMP}/cube/temp/runc_out_04 | sudo tee ${CUBE_TMP}/cube/temp/runc_out_05 1>/dev/null
  sudo cat < ${CUBE_TMP}/cube/temp/runc_out_05 | sudo tee /etc/containerd/config.toml 1>/dev/null
  sudo sed -i -r /plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"/d /etc/containerd/config.toml
  sudo sed -i -r /\"https:\\/\\/registry-1.docker.io\"/d /etc/containerd/config.toml
  sleep 3
  sudo systemctl restart containerd
  sleep 3
fi

if [ "$1" == "install" ]; then
    echo "### kubeadm init ###"
    sudo kubeadm init --config ${CUBE_TMP}/cube/temp/kubeadm-config.yaml --upload-certs

    sudo mkdir -p ${HOME}/.kube
    sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
    sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

    sudo cp -ap ${CUBE_TMP}/cube/temp/kubeadm-config.yaml /etc/kubernetes/kubeadm-config.yaml
    
    sleep 2

### Calico version dependecy kubernetes version 
CALICO_CUBE_VERSION=`echo $CUBE_VERSION | awk -F "." '{print $2}'`

# 3.13(1.15, 1.16), 3.17(1.17, 1.18, 1.19), 3.20(1.20, 1.21)
if [ $CALICO_CUBE_VERSION -lt 15 ]; then
  CALICO_VERSION=v3.9
elif [ ${CALICO_CUBE_VERSION} -ge 15 ] && [ ${CALICO_CUBE_VERSION} -lt 17 ]; then
  CALICO_VERSION=v3.13
elif [ ${CALICO_CUBE_VERSION} -ge 17 ] && [ ${CALICO_CUBE_VERSION} -lt 20 ]; then
  CALICO_VERSION=v3.17
elif [ ${CALICO_CUBE_VERSION} -ge 20 ] && [ ${CALICO_CUBE_VERSION} -lt 22 ]; then
  CALICO_VERSION=v3.20
else
  echo "Check Your Kubernetes Install version"
fi

CALICO_PATH_VERSION=`echo ${CALICO_VERSION} | sed s/v//g`

  if [ "${HOSTNAME}" == "${MASTER_HOSTNAME[0]}" ]; then
    echo "### Calico Install ###"
    sudo sed -i -r "s/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/" ${CURRENT_PATH}/calico/${CALICO_PATH_VERSION}/calico.yaml
    sudo sed -i -r 's@#   value: "192.168.0.0/16"@  value: '"${POD_SUBNET}"'@' ${CURRENT_PATH}/calico/${CALICO_PATH_VERSION}/calico.yaml
    if [ "${PRIVATE_REPO}" == "enable" ]; then
      sudo sed -r -i "s/image: /image\: ${HARBOR_URL}\//" ${CURRENT_PATH}/calico/${CALICO_PATH_VERSION}/calico.yaml
    fi
    kubectl apply -f ${CURRENT_PATH}/calico/${CALICO_PATH_VERSION}/calico.yaml
  fi
fi

### Calico Network Manager Config
# Reference - https://docs.projectcalico.org/maintenance/troubleshoot/troubleshooting#configure-networkmanager

sudo rm -rf /etc/NetworkManager/conf.d/calico.conf
sudo mkdir -p /etc/NetworkManager/conf.d
sleep 2

cat <<EOF | sudo tee /etc/NetworkManager/conf.d/calico.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico
EOF
