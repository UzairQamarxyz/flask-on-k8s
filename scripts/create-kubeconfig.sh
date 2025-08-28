#!/usr/bin/env sh

# Create a serviceaccount, role and rolebinding for EKS
# to generate a kubeconfig
#
# Many parts of this script have been taken from this guide:
# https://docs.armory.io/docs/armory-admin/manual-service-account/

# namespace where the service account will be stored
NAMESPACE=flask-app

#kubectl create ns ${NAMESPACE}
#kubectl apply -f specs/

SERVICE_ACCOUNT_NAME=deployer
CONTEXT=$(kubectl config current-context)

NEW_CONTEXT=deployer
KUBECONFIG_FILE="kubeconfig-deployer"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT_NAME}
type: kubernetes.io/service-account-token
EOF

TOKEN_DATA=$(kubectl get secret ${SERVICE_ACCOUNT_NAME} \
    --namespace ${NAMESPACE} \
    -o jsonpath='{.data.token}')

TOKEN=$(echo "${TOKEN_DATA}" | base64 -d)

# Create dedicated kubeconfig
# Create a full copy
kubectl config view --raw >${KUBECONFIG_FILE}.full.tmp
# Switch working context to correct context
kubectl --kubeconfig ${KUBECONFIG_FILE}.full.tmp config use-context ${CONTEXT}
# Minify
kubectl --kubeconfig ${KUBECONFIG_FILE}.full.tmp \
    config view --flatten --minify >${KUBECONFIG_FILE}.tmp
# Rename context
kubectl config --kubeconfig ${KUBECONFIG_FILE}.tmp \
    rename-context "${CONTEXT}" ${NEW_CONTEXT}
# Create token user
kubectl config --kubeconfig ${KUBECONFIG_FILE}.tmp \
    set-credentials "${CONTEXT}"-${NAMESPACE}-token-user \
    --token "${TOKEN}"
# Set context to use token user
kubectl config --kubeconfig ${KUBECONFIG_FILE}.tmp \
    set-context ${NEW_CONTEXT} --user "${CONTEXT}"-${NAMESPACE}-token-user
# Set context to correct namespace
kubectl config --kubeconfig ${KUBECONFIG_FILE}.tmp \
    set-context ${NEW_CONTEXT} --namespace ${NAMESPACE}
# Flatten/minify kubeconfig
kubectl config --kubeconfig ${KUBECONFIG_FILE}.tmp \
    view --flatten --minify >${KUBECONFIG_FILE}
# Remove tmp
rm ${KUBECONFIG_FILE}.full.tmp
rm ${KUBECONFIG_FILE}.tmp
