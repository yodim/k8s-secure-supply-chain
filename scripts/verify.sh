#!/usr/bin/env bash
# The money shot: prove the admission chain actually enforces.
#   1. The signed, attested demo-app is Running (positive control)
#   2. An unsigned image in the same namespace is REJECTED (negative control)
#   3. An image from an unapproved registry is REJECTED (negative control)
#
# Controls 2 and 3 are not the same test. Signature verification only inspects
# images matching its imageReferences, so it has nothing to say about an image
# from somewhere else; that one is refused by the registry allowlist instead.
# Together they are the actual claim: only signed images, and nothing else.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-supply-chain}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/kind-${CLUSTER_NAME}.yaml}"
CONTEXT="kind-${CLUSTER_NAME}"
UNSIGNED_IMAGE="${UNSIGNED_IMAGE:-ghcr.io/yodim/k8s-secure-supply-chain/unsigned-fixture:1.0.0}"
# Pinned and resourced on purpose, see the third control below.
FOREIGN_IMAGE="${FOREIGN_IMAGE:-docker.io/library/nginx:1.27}"

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

log "Negative control: image from an unapproved registry should be rejected"

# Every property of this Pod except the registry is deliberately compliant:
# the tag is pinned, so disallow-latest-tag cannot be the reason, and CPU and
# memory limits are set, so require-resource-limits cannot be either. The
# signature policies do not match a non-ghcr image at all. That leaves the
# registry allowlist as the only rule that can refuse it, which is what makes
# the rejection attributable rather than merely encouraging.
foreign_manifest=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: foreign-registry-test
  namespace: apps
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: ${FOREIGN_IMAGE}
      resources:
        requests:
          memory: 32Mi
          cpu: 50m
        limits:
          memory: 64Mi
          cpu: 100m
EOF
)

if rejection=$(printf '%s\n' "${foreign_manifest}" \
    | kubectl --context "${CONTEXT}" apply -f - 2>&1); then
  kubectl --context "${CONTEXT}" -n apps delete pod foreign-registry-test \
    --ignore-not-found >/dev/null 2>&1
  fail "an image from ${FOREIGN_IMAGE} was ADMITTED.
     Signature verification does not cover images it was never told to match,
     so without a registry allowlist the cluster runs whatever it is given."
fi

# The same discipline as control 2: a refusal for the wrong reason is not
# evidence. Each of these would also produce a non-zero exit while saying
# nothing about the registry allowlist.
case "${rejection}" in
  *MANIFEST_UNKNOWN*|*"image tag not found"*|*"name unknown"*|*ImagePull*)
    fail "rejected because the image could not be resolved or pulled, not because
     of its registry. Check connectivity to ${FOREIGN_IMAGE%%/*}." ;;
  *require-resource-limits*)
    fail "rejected by require-resource-limits, so this proves nothing about the
     registry allowlist. The test Pod is supposed to set limits; fix the manifest." ;;
  *disallow-latest-tag*)
    fail "rejected by disallow-latest-tag, so this proves nothing about the
     registry allowlist. Pin FOREIGN_IMAGE to an explicit tag." ;;
esac

case "${rejection}" in
  *restrict-image-registries*)
    pass "image from an unapproved registry rejected by the registry allowlist" ;;
  *)
    fail "rejected, but not by restrict-image-registries. Full response:
${rejection}" ;;
esac

log "Supply chain verified: only signed, attested images run here, and nothing else runs at all."
