#!/usr/bin/env bash
# Bootstrap the platform onto an existing kind cluster (created by `make up`).
# Installs Argo CD, then hands control to GitOps via the root app-of-apps.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-supply-chain}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.11.3}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/kind-${CLUSTER_NAME}.yaml}"
CONTEXT="kind-${CLUSTER_NAME}"
ROOT_APP="$(dirname "$0")/../platform/argocd/bootstrap/root-app.yaml"

export KUBECONFIG="${KUBECONFIG_PATH}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if ! kubectl --context "${CONTEXT}" cluster-info >/dev/null 2>&1; then
  echo "ERROR: cluster context '${CONTEXT}' not reachable. Run 'make up' first." >&2
  exit 1
fi

log "Installing Argo CD ${ARGOCD_VERSION}"
kubectl --context "${CONTEXT}" create namespace argocd --dry-run=client -o yaml \
  | kubectl --context "${CONTEXT}" apply -f -
kubectl --context "${CONTEXT}" apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

log "Waiting for Argo CD to become ready"
kubectl --context "${CONTEXT}" -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl --context "${CONTEXT}" -n argocd rollout status deploy/argocd-repo-server --timeout=300s

log "Applying root app-of-apps — GitOps takes over from here"
kubectl --context "${CONTEXT}" apply -f "${ROOT_APP}"

log "Done. Watch convergence with:"
echo "    kubectl --context ${CONTEXT} -n argocd get applications -w"
echo "    UI: kubectl --context ${CONTEXT} -n argocd port-forward svc/argocd-server 8443:443"
