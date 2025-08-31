#!/usr/bin/env sh

# This script creates a dedicated ServiceAccount and associated CLUSTER-LEVEL RBAC
# for deploying Helm charts from a CI/CD system.

# --- Configuration ---
# The namespace for your application and the deployer account.
NAMESPACE="flask"

# The name for the ServiceAccount that will be used for deployment.
SERVICE_ACCOUNT_NAME="helm-deployer"
# --- End of Configuration ---

echo "==> Applying RBAC permissions for the ${SERVICE_ACCOUNT_NAME} ServiceAccount..."

# Create/Update all the necessary Kubernetes resources.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${NAMESPACE}
---
# CHANGED: This is now a ClusterRole to grant cluster-scoped permissions.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # The name is now global, not tied to a namespace.
  name: ${SERVICE_ACCOUNT_NAME}-clusterrole
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "services", "persistentvolumeclaims"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["*"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["*"]
---
# CHANGED: This is now a ClusterRoleBinding to link the ClusterRole to the ServiceAccount.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-clusterbinding
roleRef:
  # This now refers to the ClusterRole.
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${SERVICE_ACCOUNT_NAME}-clusterrole
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  # You must specify the namespace of the ServiceAccount here.
  namespace: ${NAMESPACE}
EOF

echo
echo "✅ Cluster-level RBAC resources are up-to-date."
echo "You can now proceed with your Helm installation."
