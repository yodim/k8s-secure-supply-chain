# Quickstart

Ten minutes from clone to a cluster that refuses unsigned images.

## Prerequisites

| Tool | Tested with | Notes |
|---|---|---|
| Docker | 24+ | kind runs inside it |
| kind | 0.23+ | `go install` or package manager |
| kubectl | 1.30+ | matching the cluster version |
| Terraform | 1.7+ | provisions cluster + registry |
| kyverno CLI | 1.12+ | only needed for `make test-policies` |

## 1. Provision

```bash
make up
```

Terraform (via [`components/terraform/modules/kind-cluster`](../components/terraform/modules/kind-cluster/)) creates a kind cluster named `supply-chain`, a local registry at `localhost:5001`, and writes a dedicated kubeconfig to `~/.kube/kind-supply-chain.yaml`.

## 2. Bootstrap

```bash
make bootstrap
```

Installs Argo CD, then applies exactly one manifest by hand: the [root app-of-apps](../platform/argocd/bootstrap/root-app.yaml). Argo CD pulls everything else from Git — Kyverno (wave 0), the [policy catalog](../components/policies/kyverno/) (wave 1), the demo app (wave 2). From this point, `kubectl apply` is retired; changes flow through Git.

> **Fork note:** if you forked the repo, update `repoURL` in `platform/argocd/bootstrap/root-app.yaml` and the two Applications that reference it, and change the signing `subject` in the two verifyImages policies to your fork's workflow identity. Signatures from the upstream repo won't (and shouldn't) verify for images your fork builds.

## 3. Verify the chain

```bash
make verify
```

Two checks, one point:

1. **Positive control** — the demo app, built by the [secure-build workflow](../components/ci/github-actions/secure-build/) (SBOM → scan → sign → attest), is Running.
2. **Negative control** — a Pod with an unsigned image is rejected at admission by [require-signed-images](../components/policies/kyverno/require-signed-images/). You'll see the Kyverno denial message.

If both pass, you have a cluster where "we sign our images" is enforced fact, not policy-document fiction.

## 4. Poke at it

```bash
export KUBECONFIG=~/.kube/kind-supply-chain.yaml

# Argo CD UI
kubectl -n argocd port-forward svc/argocd-server 8443:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# See the policies enforcing
kubectl get clusterpolicies

# The demo app itself
curl http://localhost:8080
```

## 5. Tear down

```bash
make down
```

> **First run?** The positive control needs a signed image, which only exists after your CI has run once. See [local-testing.md](local-testing.md#the-ordering-problem-push-before-you-verify) — push to GitHub first, then verify locally.

## Troubleshooting

- **`make verify` positive control fails right after bootstrap** — the demo image is pulled from ghcr.io; first sync can take a couple of minutes. `kubectl -n apps get events --sort-by=.lastTimestamp`.
- **Sigstore unreachable** (corporate proxy, offline) — admission of matched images fails closed by design. See the failure-modes section of [require-signed-images](../components/policies/kyverno/require-signed-images/README.md).
- **Argo CD apps stuck `Unknown`** — usually repo access; check `kubectl -n argocd logs deploy/argocd-repo-server`.
