#!/bin/bash

KUBELET_STATUS=`systemctl status kubelet | grep Active | awk {'print $2'}`
if [ "${KUBELET_STATUS}" != "active" ]; then
  echo "#############################"
  echo "### Check kubelet service ###"
  echo "#############################"
  echo "ex. systemctl status kubelet "
  echo ""
  echo "Haproxy step exit"

  exit 0

fi

source ./cube_env

sudo rm -rf /etc/haproxy/
sudo rm -rf ${CUBE_TMP}/cube/temp/haproxy.cfg

### Create haproxy config file
sudo mkdir -p /etc/haproxy/
sudo touch ${CUBE_TMP}/cube/temp/haproxy.cfg

sudo cat <<EOF | sudo tee ${CUBE_TMP}/cube/temp/haproxy.cfg
global
  log 127.0.0.1 local0
  log 127.0.0.1 local1 notice
  tune.ssl.default-dh-param 2048

defaults
  log global
  mode http
  #option httplog
  option dontlognull
  timeout connect 5000ms
  timeout client 50000ms
  timeout server 50000ms

frontend api-https
   mode tcp
   bind :9999
   default_backend api-backend

backend api-backend
    mode tcp
EOF

### Haproxy apiserver ###
for ((i=0; i<${#MASTER_HOSTNAME[@]}; i++)); 
do
  sudo  sh -c "echo '    server  api$i ${MASTER_NODE_IP[$i]}:6443 check' >> ${CUBE_TMP}/cube/temp/haproxy.cfg"
done

sudo cp ${CUBE_TMP}/cube/temp/haproxy.cfg /etc/haproxy/haproxy.cfg

### Create haproxy static pod yaml 

sudo rm -rf ${CUBE_TMP}/cube/temp/haproxy.yaml
sudo touch ${CUBE_TMP}/cube/temp/haproxy.yaml

### Check kubernetes init 
if [ "${PRIVATE_REPO}" == "disable" ]; then
sudo cat <<EOF | sudo tee ${CUBE_TMP}/cube/temp/haproxy.yaml
apiVersion: v1
kind: Pod
metadata:
  name: haproxy
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    k8s-app: kube-haproxy
spec:
  hostNetwork: true
  nodeSelector:
    beta.kubernetes.io/os: linux
  priorityClassName: system-node-critical
  containers:
  - name: haproxy
    image: "haproxy:2.2.0"
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        cpu: 25m
        memory: 32M
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /usr/local/etc/haproxy/haproxy.cfg
      name: etc-haproxy
      readOnly: true
  volumes:
  - name: etc-haproxy
    hostPath:
      path: /etc/haproxy/haproxy.cfg
EOF

elif [ "${PRIVATE_REPO}" == "enable" ]; then
  sudo cat <<EOF | sudo tee ${CUBE_TMP}/cube/temp/haproxy.yaml
apiVersion: v1
kind: Pod
metadata:
  name: haproxy
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    k8s-app: kube-haproxy
spec:
  hostNetwork: true
  nodeSelector:
    beta.kubernetes.io/os: linux
  priorityClassName: system-node-critical
  containers:
  - name: haproxy
    image: "${HARBOR_URL}/docker.io/library/haproxy:2.2.0"
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        cpu: 25m
        memory: 32M
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /usr/local/etc/haproxy/haproxy.cfg
      name: etc-haproxy
      readOnly: true
  volumes:
  - name: etc-haproxy
    hostPath:
      path: /etc/haproxy/haproxy.cfg
EOF

else 
  echo "CUBE Network type is ${PRIVATE_REPO} Check variable in cube_env file \"PRIVATE_REPO\""
  echo "Bye Bye"
  sleep 3
  exit 0
fi

sudo cp ${CUBE_TMP}/cube/temp/haproxy.yaml /etc/kubernetes/manifests/haproxy.yaml

### kubectl kube-proxy configmap 
echo "#########################################"
echo "### kubectl command execute Just once ###"
echo "#########################################"
echo "kubectl get cm kube-proxy -n kube-system -o yaml | sed 's#server:.*#server: https://localhost:9999#g' | kubectl apply -f -"
echo "kubectl delete pods -n kube-system -l k8s-app=kube-proxy"
echo "#########################################"
echo ""

### kubelet config 
sudo sed -r -i 's#server:.*#server: https://localhost:9999#g' /etc/kubernetes/kubelet.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
