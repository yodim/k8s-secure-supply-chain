# restrict-image-registries

Allows only images under `ghcr.io/yodim/` to run in the `apps` namespace.

## Why this exists alongside signature verification

This is the policy that makes "only what the pipeline signed runs here" actually true, and it is worth being precise about why the signature policies were not already enough.

`require-signed-images` and `require-sbom-attestation` both scope their checks with `imageReferences: ["ghcr.io/yodim/*"]`. That is correct and deliberate: a verification rule has to know which images it is supposed to be able to verify, because demanding a signature from an image nobody in this pipeline built would just break every third-party dependency.

But it has a consequence that is easy to miss. **An image those rules do not match is not failed. It is not examined at all.** Before this policy existed, a Pod like this was admitted and ran:

```yaml
containers:
  - name: app
    image: docker.io/library/nginx:1.27   # admitted, unsigned, never checked
```

No signature, no attestation, no complaint. It satisfied the two hygiene policies (pinned tag, resource limits set) and the two verification policies simply had no opinion about it.

So the two controls answer different questions:

| Policy | Question | Blind spot on its own |
|---|---|---|
| `require-signed-images` | Are *our* images really ours? | Says nothing about anyone else's |
| `restrict-image-registries` | Is this image allowed in at all? | Says nothing about whether it is signed |

Verification without an allowlist checks the front door while leaving the side door open. An allowlist without verification stops strangers but trusts anything wearing the right name. Both, together, are the claim.

## What it checks

Every image in `containers`, `initContainers` and `ephemeralContainers` must match `ghcr.io/yodim/*`.

All three lists are covered separately, because they are separate fields in the Pod spec. Checking only `containers` leaves an obvious bypass: a Pod whose visible container is compliant can still pull anything it likes in an init step, and that init container runs first, with the same access to volumes and the same network.

Two details in the pattern are load-bearing:

- **The trailing slash.** `ghcr.io/yodim*` would also admit `ghcr.io/yodim-evil/app`, which is a different GitHub account that anyone can register. The `/` forces a path boundary. There is a test for exactly this.
- **The wildcard spans `/`, `:` and `@`.** That is what lets it still pass an image Kyverno has already rewritten to `ghcr.io/yodim/...:main@sha256:...` during `mutateDigest`. A policy that rejected the mutated form would deadlock against the very verification it sits beside.

## Enforcement

Enforcement comes from the top-level `spec.validationFailureAction: Enforce`.

Do not add a per-rule `failureAction` here. On Kyverno 1.12 (chart 3.2.x) that field is not in the ClusterPolicy CRD schema, so the API server prunes it silently and it enforces nothing, while looking exactly like the thing that does. The same trap is documented in `require-signed-images`.

`failurePolicy: Fail` and `background: true` match the sibling policies: if Kyverno cannot be reached, requests are denied rather than waved through.

## Scope

Namespace `apps` only. `kube-system`, `argocd` and `kyverno` are deliberately untouched, because the platform's own components legitimately come from upstream registries and locking them to `ghcr.io/yodim/` would prevent the cluster from functioning.

That is a real limitation rather than a rounding error: this policy protects the workload namespace, not the whole cluster. Widening it to more namespaces means first mirroring or vendoring everything those namespaces pull.

## Testing

```bash
make test-policies      # offline, no cluster needed
make verify             # third control exercises this policy on a live cluster
```

The offline tests cover the compliant tag and digest forms, a Docker Hub image both fully qualified and bare, the `yodim-evil` lookalike, another `ghcr.io` account, and the compliant-container-with-hostile-initContainer bypass.

`make verify` submits a Pod that is compliant in every respect except its registry, with a pinned tag and resource limits set, so that the only rule capable of refusing it is this one. It then asserts the rejection actually names `restrict-image-registries`, and fails loudly if the Pod was refused for any other reason. A rejection for the wrong reason would prove nothing.
