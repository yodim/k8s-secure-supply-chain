# require-signed-images

Admission policy: **no Cosign signature from the trusted CI identity → the Pod does not run.**

This is the enforcement end of the supply chain. Signing in CI is theater unless something at admission refuses unsigned images; this policy is that something.

## What it does

- Matches Pods in workload namespaces whose images match `imageReferences`.
- Verifies a **keyless** Cosign signature against a pinned identity: the exact repo + workflow + branch that is allowed to produce runnable images, with GitHub Actions as OIDC issuer, checked against the public Rekor log.
- Rewrites tags to digests (`mutateDigest`) so the artifact verified is byte-for-byte the artifact that runs — closing the tag-mutation gap.

## Reuse in your environment

1. Change `imageReferences` to your registry/namespace. Keep it narrow: only patterns you actually sign, or you will block third-party images.
2. Change `subject` to your CI workflow identity, e.g. `https://github.com/<org>/<repo>/.github/workflows/<file>@refs/heads/main`.
3. Roll out in audit first: set `failureAction: Audit`, watch PolicyReports for a few days, then flip to `Enforce`.

**Key-based variant:** replace the `keyless` block with:

```yaml
- keys:
    publicKeys: |-
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----
```

See [ADR-0003](../../../../adr/0003-cosign-keyless-signing.md) for why keyless is the default here and when keys are the right call instead.

## Test

Signature verification requires a live cluster, registry, and Rekor — it can't be meaningfully tested with the offline `kyverno test` CLI. This policy is tested end-to-end instead: `make verify` at repo root admits the signed demo app (positive control) and confirms an unsigned image is rejected (negative control).

## Prerequisites

- Kyverno ≥ 1.12
- Cluster egress to `rekor.sigstore.dev` and `fulcio.sigstore.dev` (or your private Sigstore)

## Failure modes to know

- **Sigstore outage** → admissions of *matched* images fail closed (`failurePolicy: Fail`). Decide deliberately whether availability or integrity wins in your context; document the choice.
- **Airgapped clusters** need a private Rekor/Fulcio; point `rekor.url` accordingly.
