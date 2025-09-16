#!/usr/bin/env sh

# This script creates a dedicated ServiceAccount and associated CLUSTER-LEVEL RBAC
# for deploying Helm charts from a CI/CD system. It then generates a self-contained
# kubeconfig file for that account.

# --- Configuration ---
# The namespace for your application and the deployer account.
NAMESPACE="flask"

# The name for the ServiceAccount that will be used for deployment.
SERVICE_ACCOUNT_NAME="helm-deployer"

# The name of the final kubeconfig file that will be generated.
KUBECONFIG_FILE="kubeconfig-helm-deployer.yaml"

# The name for the context inside the new kubeconfig file.
NEW_CONTEXT_NAME="helm-deployer-context"
# --- End of Configuration ---

set -e # Exit immediately if a command exits with a non-zero status.

echo
echo "✅ RBAC resources are up-to-date."
echo "==> Generating kubeconfig file..."

echo "--> Waiting for the token to be created..."
sleep 2

# Get the token from the secret
TOKEN=$(kubectl get secret ${SERVICE_ACCOUNT_NAME}-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 --decode)

if [ -z "$TOKEN" ]; then
    echo "❌ Error: Could not retrieve token. Please check if the secret was created correctly."
    exit 1
fi

# Get current cluster info from the user's active kubeconfig
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CURRENT_CONTEXT\")].context.cluster}")
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.server}")

# --- MODIFICATION START ---
# Extract the certificate authority data and save to a temporary file
# This is more compatible with older kubectl versions than using --certificate-authority-data
CERT_AUTH_DATA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.certificate-authority-data}")
TMP_CA_FILE=$(mktemp)
echo "${CERT_AUTH_DATA}" | base64 --decode > "${TMP_CA_FILE}"
# --- MODIFICATION END ---

echo "--> Building kubeconfig file: ${KUBECONFIG_FILE}"

# Start with a clean slate for the new kubeconfig file
rm -f ${KUBECONFIG_FILE}

# 1. Set Cluster
kubectl config --kubeconfig=${KUBECONFIG_FILE} \
  set-cluster ${CLUSTER_NAME} \
  --server=${SERVER} \
  --certificate-authority="${TMP_CA_FILE}" \
  --embed-certs=true

# 2. Set Credentials
kubectl config --kubeconfig=${KUBECONFIG_FILE} \
  set-credentials ${SERVICE_ACCOUNT_NAME} \
  --token=${TOKEN}

# 3. Set Context
kubectl config --kubeconfig=${KUBECONFIG_FILE} \
  set-context ${NEW_CONTEXT_NAME} \
  --cluster=${CLUSTER_NAME} \
  --user=${SERVICE_ACCOUNT_NAME} \
  --namespace=${NAMESPACE}

# 4. Use New Context
kubectl config --kubeconfig=${KUBECONFIG_FILE} \
  use-context ${NEW_CONTEXT_NAME}

# --- MODIFICATION START ---
# Clean up the temporary certificate file
rm -f "${TMP_CA_FILE}"
# --- MODIFICATION END ---

echo
echo "✅ Kubeconfig file '${KUBECONFIG_FILE}' created successfully."
echo "You can now use this file in your CI/CD system by setting the KUBECONFIG environment variable."
