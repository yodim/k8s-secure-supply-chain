#!/usr/bin/env bash
# The money shot: prove the admission chain actually enforces.
#   1. The signed, attested demo-app is Running (positive control)
#   2. An unsigned image in the same namespace is REJECTED (negative control)
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-supply-chain}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/kind-${CLUSTER_NAME}.yaml}"
CONTEXT="kind-${CLUSTER_NAME}"
UNSIGNED_IMAGE="${UNSIGNED_IMAGE:-ghcr.io/yodim/unsigned-test:1.0.0}"

export KUBECONFIG="${KUBECONFIG_PATH}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; exit 1; }

log "Positive control: signed demo-app should be Running"
if kubectl --context "${CONTEXT}" -n apps wait --for=condition=Ready pod \
    -l app=demo-app --timeout=180s >/dev/null 2>&1; then
  pass "signed + attested image admitted and running"
else
  fail "demo-app is not running — check 'kubectl -n apps get events'"
fi

log "Negative control: unsigned image should be rejected at admission"
if kubectl --context "${CONTEXT}" -n apps run unsigned-test \
    --image="${UNSIGNED_IMAGE}" --restart=Never >/dev/null 2>&1; then
  kubectl --context "${CONTEXT}" -n apps delete pod unsigned-test --ignore-not-found >/dev/null 2>&1
  fail "unsigned image was ADMITTED — the policy chain is not enforcing"
else
  pass "unsigned image rejected by Kyverno admission"
fi

log "Supply chain verified: only signed, attested images run here."
