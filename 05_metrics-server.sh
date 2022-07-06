#!/bin/bash

### Incloud ENV File ###
source ./cube_env

### Metric-server Secret ###
### Create Metric Server Secret
cat << EOF |sudo tee ./helm/metric-server-secret.yaml > /dev/null 2>&1
apiVersion: v1
kind: Secret
metadata:
  name: metrics-server-certs
  namespace: kube-system
type: Opaque
data:
  ca.crt: $(cat /etc/kubernetes/pki/ca.crt | base64 -w0)
  metrics-server.crt: $(cat /etc/kubernetes/pki/metrics-server.crt | base64 -w0)
  metrics-server.key: $(sudo cat /etc/kubernetes/pki/metrics-server.key | base64 -w0)
EOF

### Create Secret By Kubernetes
kubectl apply -f ./helm/metric-server-secret.yaml

### Create Metric-server Workload
kubectl apply -f ./helm/metrics-server-tls.yaml