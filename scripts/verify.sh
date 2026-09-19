#!/usr/bin/env bash
# The money shot: prove the admission chain actually enforces.
#   1. The signed, attested demo-app is Running (positive control)
#   2. An unsigned image in the same namespace is REJECTED (negative control)
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-supply-chain}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/kind-${CLUSTER_NAME}.yaml}"
CONTEXT="kind-${CLUSTER_NAME}"
UNSIGNED_IMAGE="${UNSIGNED_IMAGE:-ghcr.io/yodim/k8s-secure-supply-chain/unsigned-fixture:1.0.0}"

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
if rejection=$(kubectl --context "${CONTEXT}" -n apps run unsigned-test \
    --image="${UNSIGNED_IMAGE}" --restart=Never 2>&1); then
  kubectl --context "${CONTEXT}" -n apps delete pod unsigned-test --ignore-not-found >/dev/null 2>&1
  fail "unsigned image was ADMITTED — the policy chain is not enforcing"
fi

# Rejected, but a rejection alone proves nothing: an image name the registry
# cannot resolve is also rejected, and would be with every policy deleted.
# The reason has to be signature verification for this to be evidence.
case "${rejection}" in
  *MANIFEST_UNKNOWN*|*"image tag not found"*|*"name unknown"*)
    fail "rejected because the image could not be resolved, not because it is unsigned.
     Publish the fixture first:  gh workflow run publish-unsigned-fixture.yml
     See tests/fixtures/unsigned-image/README.md" ;;
esac

case "${rejection}" in
  *require-signed-images*)
    pass "unsigned image rejected by signature verification" ;;
  *)
    fail "rejected, but not by require-signed-images. Full response:
${rejection}" ;;
esac

log "Supply chain verified: only signed, attested images run here."
