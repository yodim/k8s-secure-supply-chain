# ci/github-actions/secure-build

Reusable GitHub Actions workflow implementing the full secure build chain:

**build → SBOM (Syft) → scan gate (Trivy) → push → sign (Cosign keyless) → attest SBOM**

The workflow file lives at [`.github/workflows/secure-build.yml`](../../../../.github/workflows/secure-build.yml) (GitHub requires reusable workflows to live there; this directory is its documentation home in the catalog).

## Design decisions baked in

- **Scan before push.** A failing image never reaches the registry — the registry only contains images that passed the gate.
- **Sign the digest, not the tag.** Tags are mutable pointers; the signature covers the immutable artifact. The admission policy completes this by rewriting tags to digests (`mutateDigest`).
- **Keyless signing** ([ADR-0003](../../../../adr/0003-cosign-keyless-signing.md)): no signing secrets to manage; the signature is bound to this repo's workflow identity via OIDC and logged in Rekor.
- **SBOM ≠ scan** ([ADR-0004](../../../../adr/0004-syft-trivy-toolchain.md)): the SBOM is attested and travels with the image forever; the scan verdict only gates this build.
- **`ignore-unfixed: true`**: failing builds on vulnerabilities that have no available fix punishes teams for things they cannot action. Deliberate, debatable — flip it if your compliance regime says otherwise.

## Usage

See [action-usage.md](action-usage.md) for the copy-paste caller workflow. Inputs: `image-name` (required), `context`, `dockerfile`, `fail-on-severity`. Output: `image-digest`.

## What this does NOT do (yet)

- SLSA build provenance attestation (v1.1, see [ROADMAP](../../../../ROADMAP.md))
- Base-image verification (verifying *your* dependencies' signatures)
- Multi-arch builds — kept single-arch for clarity; add `platforms:` if you need them
