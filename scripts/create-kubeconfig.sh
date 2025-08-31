#!/usr/bin/env sh

# This script creates a dedicated ServiceAccount and associated RBAC (Role, RoleBinding)
# for deploying Helm charts from a CI/CD system like GitHub Actions.
# It then generates a self-contained kubeconfig file for that ServiceAccount.

# --- Configuration ---
# The namespace for your application and the deployer account.
# The script will create this namespace if it doesn't exist.
NAMESPACE="flask"

# The name for the ServiceAccount that will be used for deployment.
SERVICE_ACCOUNT_NAME="helm-deployer"

# The filename for the output kubeconfig.
KUBECONFIG_FILE="kubeconfig-${NAMESPACE}-${SERVICE_ACCOUNT_NAME}.yaml"
# --- End of Configuration ---

# Get the details of the current cluster from the user's active kubeconfig
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${CURRENT_CONTEXT}\")].context.cluster}")
SERVER_URL=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.server}")
CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.certificate-authority-data}")

echo "==> Creating Namespace, ServiceAccount, and RBAC resources in the cluster..."

# Create all the necessary Kubernetes resources using a multi-document YAML here-doc.
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
apiVersion: rbac.authorization.k8.s.io/v1
kind: Role
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-role
  namespace: ${NAMESPACE}
rules:
  # This role grants permissions that are commonly needed by Helm to manage a release.
  # It has full control over the most common application resources within the namespace.
- apiGroups: ["", "apps", "extensions", "batch", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-binding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${SERVICE_ACCOUNT_NAME}-role
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${NAMESPACE}
EOF

echo "==> RBAC resources created successfully."

# Generate a long-lived token for the Service Account (valid for 1 year)
echo "==> Generating authentication token for the ServiceAccount..."
TOKEN=$(kubectl create token ${SERVICE_ACCOUNT_NAME} --namespace ${NAMESPACE} --duration=8760h)

if [ -z "$TOKEN" ]; then
  echo "Error: Failed to generate token." >&2
  exit 1
fi

echo "==> Token generated. Creating kubeconfig file: ${KUBECONFIG_FILE}"

# Create the dedicated kubeconfig file from scratch.
cat <<EOF >${KUBECONFIG_FILE}
apiVersion: v1
kind: Config
current-context: ${SERVICE_ACCOUNT_NAME}
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    server: ${SERVER_URL}
    certificate-authority-data: ${CERTIFICATE_AUTHORITY_DATA}
contexts:
- name: ${SERVICE_ACCOUNT_NAME}
  context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${SERVICE_ACCOUNT_NAME}
users:
- name: ${SERVICE_ACCOUNT_NAME}
  user:
    token: ${TOKEN}
EOF

echo
echo "✅ Success! Kubeconfig saved to ./${KUBECONFIG_FILE}"
echo
echo "--- Next Steps for GitHub Actions ---"
echo "1. Go to your GitHub repository's Settings > Secrets and variables > Actions."
echo "2. Create a new repository secret (e.g., KUBE_CONFIG)."
echo "3. Copy the entire content of the '${KUBECONFIG_FILE}' file and paste it into the secret's value."
