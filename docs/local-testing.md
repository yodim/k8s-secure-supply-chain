# Running and testing this locally

[Quickstart](quickstart.md) assumes a Linux shell and a repo whose CI has already run at least once. This page covers the two situations that trip people up: **running on Windows**, and **the first run, when no signed image exists yet**.

## What runs where

Worth getting straight before you install anything, because it explains why the local prerequisites are short:

| Stage | Runs on | Tools involved |
|---|---|---|
| Build, SBOM, scan, sign, attest | GitHub-hosted runner (`ubuntu-latest`) | Docker Buildx, Syft, Trivy, Cosign |
| Cluster provisioning | Your machine | Terraform, kind, Docker |
| Platform install & reconciliation | Inside the cluster | Argo CD |
| Admission enforcement | Inside the cluster | Kyverno |

Syft, Trivy and Cosign never need to be installed locally — they're steps in the pipeline. You install four things: **Docker, kind, kubectl, Terraform**.

## Windows: use WSL2

The scripts are bash, `make` isn't native to Windows, and kind needs a Linux container runtime. Rather than patch around all three, run everything inside WSL2 — which is also what CI runs, so you debug one environment instead of two.

```powershell
# PowerShell as Administrator, then reboot
wsl --install -d Ubuntu
```

Install Docker Desktop, then enable **Settings → Resources → WSL Integration → Ubuntu**.

> **Clone into the Linux filesystem** (`~/projects/...`), not `/mnt/c/...`. Docker and kind are dramatically slower across the Windows mount, and file-permission behaviour differs enough to cause confusing failures.

## Install the tools

```bash
sudo apt update && sudo apt install -y make curl gnupg lsb-release

# kind
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# optional: kyverno CLI, only needed for `make test-policies`
curl -LO https://github.com/kyverno/kyverno/releases/latest/download/kyverno-cli_linux_x86_64.tar.gz
tar -xzf kyverno-cli_linux_x86_64.tar.gz && sudo mv kyverno /usr/local/bin/

docker info >/dev/null && echo "docker ok"
```

## The ordering problem: push before you verify

This is the part that surprises people, and it's inherent to the design rather than a defect.

`make verify` runs two checks. The **negative control** (an unsigned image must be rejected) works immediately on a fresh cluster. The **positive control** waits for the demo app to be Running — and the demo app's image is only produced, signed and attested by *your* CI. Until the workflow has run on GitHub, that image doesn't exist, so the positive control cannot pass locally.

So the real first-run sequence is:

```
1. Push the repo to GitHub          → Actions builds, scans, signs, attests the demo image
2. Confirm the run is green         → the signed image now exists in ghcr.io
3. make up && make bootstrap        → local cluster + platform
4. make verify                      → both controls pass
```

Between steps 1 and 4 you can still exercise most of the platform locally — the cluster, Argo CD, the policies, and the negative control all work. You just won't have a signed image to admit yet.

### If you forked or renamed the repo

Signatures are pinned to a specific workflow identity, so a fork verifying against the upstream identity will (correctly) reject its own images. Update these before running:

- `platform/argocd/bootstrap/root-app.yaml` → `repoURL`
- `platform/argocd/apps/policies.yaml` and `demo-app.yaml` → `repoURL`
- `components/policies/kyverno/require-signed-images/policy.yaml` → `subject` and `imageReferences`
- `components/policies/kyverno/require-sbom-attestation/policy.yaml` → same two fields

```bash
grep -rn "yodim/k8s-secure-supply-chain" --include="*.yaml" .
```

## Private repo? Three secrets live outside git

Everything above assumes the repo and its ghcr packages are public. If they are private, three credentials must exist in the cluster, none of which are (or should ever be) in git. They vanish with the cluster, so **recreate all three after every `make down`**, or Argo CD sits at `Unknown` and every pod pull gets a 401.

Your GitHub token needs the `repo` and `read:packages` scopes. With the gh CLI: `gh auth refresh -s read:packages`, then `gh auth token` prints it.

```bash
export KUBECONFIG=~/.kube/kind-supply-chain.yaml
TOKEN=$(gh auth token)

# 1. Argo CD needs to clone the repo
kubectl -n argocd create secret generic repo-k8s-secure-supply-chain \
  --from-literal=type=git \
  --from-literal=url=https://github.com/yodim/k8s-secure-supply-chain \
  --from-literal=username=yodim \
  --from-literal=password="$TOKEN"
kubectl -n argocd label secret repo-k8s-secure-supply-chain \
  argocd.argoproj.io/secret-type=repository

# 2. Kyverno needs to fetch image metadata, signatures and attestations
#    (the verifyImages policies reference this secret by name)
kubectl -n kyverno create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io --docker-username=yodim --docker-password="$TOKEN"

# 3. The kubelet needs to pull the image
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
kubectl -n apps create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io --docker-username=yodim --docker-password="$TOKEN"
kubectl -n apps patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-creds"}]}'
```

Create 1 before (or right after) `make bootstrap`; 2 and 3 any time before the demo app syncs. Timing is forgiving because everything retries.

## Testing without a cluster

Fast feedback while editing policies — no Docker needed:

```bash
make lint            # yamllint, shellcheck, terraform fmt
make test-policies   # offline Kyverno tests for the two hygiene policies
make check-gate      # assert the Trivy gate is still wired as its test expects
```

`make check-gate` needs [mikefarah/yq](https://github.com/mikefarah/yq#install) v4. Note that Ubuntu's `apt install yq` is a different program, a Python wrapper around jq, and will not work. It reads the gate out of `secure-build.yml` and checks it is present, pinned, actually failing on findings, and still running before the push step.

The gate's full negative control runs in CI rather than locally, because it needs the same Trivy version the action pins. To reproduce it yourself you need Docker and Trivy; see [tests/fixtures/vulnerable-image](../tests/fixtures/vulnerable-image/) for the commands.

The two signature-verification policies have no offline tests on purpose: verifying a Cosign signature needs a live registry and Rekor, and a test that mocks all of that would assert nothing useful. They're covered end-to-end by `make verify` instead.

## Troubleshooting

**`network kind not found` during `make up`**
Should no longer happen — the module creates the registry detached and attaches it after the cluster exists. If you see it, you're on an older checkout, or something reordered `terraform_data.connect_registry`.

**`make up` succeeds but images won't pull from the local registry**
Check the registry is actually on kind's network:
```bash
docker network inspect kind --format '{{range .Containers}}{{.Name}} {{end}}'
```
`supply-chain-registry` should appear. If not: `docker network connect kind supply-chain-registry`.

**Argo CD applications stuck `Unknown` or `OutOfSync`**
Almost always repo access or a stale `repoURL` after forking.
```bash
export KUBECONFIG=~/.kube/kind-supply-chain.yaml
kubectl -n argocd logs deploy/argocd-repo-server --tail=50
```

**Demo app pod never appears**
If the image was never built by CI, this is expected — see the ordering section above. Otherwise check whether Kyverno rejected it, which is the interesting case:
```bash
kubectl -n apps get events --sort-by=.lastTimestamp | tail -20
kubectl get clusterpolicyreports -A
```

**Everything is rejected, including the demo app**
Usually a Sigstore reachability problem behind a corporate proxy. The policies fail closed by design. Confirm with:
```bash
kubectl -n kyverno logs deploy/kyverno-admission-controller --tail=100 | grep -i cosign
```

**Reset and start over**
```bash
make down
kind delete cluster --name supply-chain
docker rm -f supply-chain-registry
```
On a private repo, remember the three out-of-band secrets are gone too. Recreate them (see above) before expecting anything to sync.
