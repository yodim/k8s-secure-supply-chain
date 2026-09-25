# Using the secure-build reusable workflow from your own repo

One `uses:` line gets you build → SBOM → scan → push → sign → attest:

```yaml
# .github/workflows/release.yml in YOUR repo
name: release
on:
  push:
    branches: [main]

permissions:
  contents: read
  packages: write
  id-token: write   # required: OIDC token for keyless signing

jobs:
  secure-build:
    uses: yodim/k8s-secure-supply-chain/.github/workflows/secure-build.yml@main
    with:
      image-name: ghcr.io/${{ github.repository }}
      context: .
      fail-on-severity: CRITICAL,HIGH
```

Then pin *your* workflow identity in the [require-signed-images](../../../policies/kyverno/require-signed-images/) policy's `subject` field — signatures are only as meaningful as the identity you verify against.

> Pin to a tag or SHA (`@v1`, `@<sha>`) rather than `@main` once you depend on it.
