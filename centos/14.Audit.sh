#!/usr/bin/env bash

### this script is Create audit yaml file
### date : 2022-07-05
### author : redicarus.jeong
### description

source ./cube.env

##### 14. Create Audite yaml file
##### 14-0. check audit file
echo "====> 14-0. check audit file"
AUDITE_FILE_LIST=("audit-policy.yaml" "audit-webhook" "secrets_encryption.yaml")
for FILE_NAME in ${AUDITE_FILE_LIST[@]}
  do
    if [ -f ${KUBECONFIG_DIR}/${FILE_NAME} ]; then
        sudo mv -f ${KUBECONFIG_DIR}/${FILE_NAME} ${KUBECONFIG_DIR}/${FILE_NAME}_backup
    fi
done


##### 14-1. create audit-policy.yaml file
echo "====> 14-1. create audit-policy.yaml file"
cat << EOF | sudo tee ${KUBECONFIG_DIR}/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: "" # core
        resources: ["endpoints", "services", "services/status"]
  - level: None
    users: ["system:unsecured"]
    namespaces: ["kube-system"]
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["configmaps"]
  - level: None
    users: ["kubelet"] # legacy kubelet identity
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["nodes", "nodes/status"]
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["nodes", "nodes/status"]
  - level: None
    users:
      - system:kube-controller-manager
      - system:kube-scheduler
      - system:serviceaccount:kube-system:endpoint-controller
    verbs: ["get", "update"]
    namespaces: ["kube-system"]
    resources:
      - group: "" # core
        resources: ["endpoints"]
  - level: None
    users: ["system:apiserver"]
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["namespaces", "namespaces/status", "namespaces/finalize"]
  - level: None
    users:
      - system:kube-controller-manager
    verbs: ["get", "list"]
    resources:
      - group: "metrics.k8s.io"
  - level: None
    nonResourceURLs:
      - /healthz*
      - /version
      - /swagger*
  - level: None
    resources:
      - group: "" # core
        resources: ["events"]
  - level: Request
    users: ["kubelet", "system:node-problem-detector", "system:serviceaccount:kube-system:node-problem-detector"]
    verbs: ["update","patch"]
    resources:
      - group: "" # core
        resources: ["nodes/status", "pods/status"]
  - level: Request
    userGroups: ["system:nodes"]
    verbs: ["update","patch"]
    resources:
      - group: "" # core
        resources: ["nodes/status", "pods/status"]
  - level: Request
    users: ["system:serviceaccount:kube-system:namespace-controller"]
    verbs: ["deletecollection"]
  - level: Metadata
    resources:
      - group: "" # core
        resources: ["secrets", "configmaps"]
      - group: authentication.k8s.io
        resources: ["tokenreviews"]
  - level: Request
    verbs: ["get", "list", "watch"]
    resources:
      - group: "" # core
      - group: "admissionregistration.k8s.io"
      - group: "apiextensions.k8s.io"
      - group: "apiregistration.k8s.io"
      - group: "apps"
      - group: "authentication.k8s.io"
      - group: "authorization.k8s.io"
      - group: "autoscaling"
      - group: "batch"
      - group: "certificates.k8s.io"
      - group: "extensions"
      - group: "metrics.k8s.io"
      - group: "networking.k8s.io"
      - group: "policy"
      - group: "rbac.authorization.k8s.io"
      - group: "scheduling.k8s.io"
      - group: "settings.k8s.io"
      - group: "storage.k8s.io"
  - level: RequestResponse
    resources:
      - group: "" # core
      - group: "admissionregistration.k8s.io"
      - group: "apiextensions.k8s.io"
      - group: "apiregistration.k8s.io"
      - group: "apps"
      - group: "authentication.k8s.io"
      - group: "authorization.k8s.io"
      - group: "autoscaling"
      - group: "batch"
      - group: "certificates.k8s.io"
      - group: "extensions"
      - group: "metrics.k8s.io"
      - group: "networking.k8s.io"
      - group: "policy"
      - group: "rbac.authorization.k8s.io"
      - group: "scheduling.k8s.io"
      - group: "settings.k8s.io"
      - group: "storage.k8s.io"
  # Default level for all other requests.
  - level: Metadata
EOF

##### 14-2. create audit-webhook file
echo "====> 14-2. create audit-webhook file"
cat << EOF | sudo tee ${KUBECONFIG_DIR}/audit-webhook
apiVersion: v1
clusters:
- cluster:
    server: http://localhost:9307/agent-api/audit
  name: audit-webhook-service
contexts:
- context:
    cluster: audit-webhook-service
    user: ""
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users: []
EOF

##### 14-3. secrets_encryption.yaml file
echo "====> 14-3. create secrets_encryption.yaml file"
cat << EOF | sudo tee ${KUBECONFIG_DIR}/secrets_encryption.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - secretbox:
        keys:
        - name: cocktail
          secret: "cW21HDwi9pOIo6GBoz8JhV5HWUkDXj+iYHXyEzZiFXk="
    - identity: {}
EOF

