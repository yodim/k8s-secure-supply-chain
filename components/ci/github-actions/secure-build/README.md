# ci/github-actions/secure-build

Reusable GitHub Actions workflow implementing the full secure build chain:

**build → SBOM (Syft) → scan gate (Trivy) → push → sign (Cosign keyless) → attest SBOM**

The workflow file lives at [`.github/workflows/secure-build.yml`](../../../../.github/workflows/secure-build.yml) (GitHub requires reusable workflows to live there; this directory is its documentation home in the catalog).

## Design decisions baked in

- **Scan before push.** A failing image never reaches the registry — the registry only contains images that passed the gate.
- **Sign the digest, not the tag.** Tags are mutable pointers; the signature covers the immutable artifact. The admission policy completes this by rewriting tags to digests (`mutateDigest`).
- **Keyless signing** ([ADR-0003](../../../../adr/0003-cosign-keyless-signing.md)): no signing secrets to manage; the signature is bound to this repo's workflow identity via OIDC and logged in Rekor.
- **SBOM ≠ scan** ([ADR-0004](../../../../adr/0004-syft-trivy-toolchain.md)): the SBOM is attested and travels with the image forever; the scan verdict only gates this build.
- **`ignore-unfixed: true`**: failing builds on vulnerabilities that have no available fix punishes teams for things they cannot action. Deliberate, debatable — flip it if your compliance regime says otherwise. It also constrains the gate's test fixture, which has to carry findings that *have* fixes or the gate would rightly ignore them.

## Proof the gate fires

A build gate that has never failed a build is a hypothesis. The `build-gate` job in [`ci.yml`](../../../../.github/workflows/ci.yml) builds [`tests/fixtures/vulnerable-image`](../../../../tests/fixtures/vulnerable-image/) (an old base, pinned by digest, never pushed anywhere) and fails unless this workflow's Trivy configuration rejects it. It runs on pull requests too, so a change that loosens the gate is caught before it reaches `main`.

Two details make it evidence rather than decoration:

- It **reads `exit-code`, `ignore-unfixed` and the `fail-on-severity` default out of this workflow** rather than restating them. Relax the gate and the test relaxes with it, the fixture stops being rejected, and CI goes red.
- It scans the fixture **twice, identical but for the gate flag**. Trivy also exits non-zero when it cannot pull an image or reach its database, so "the scan failed" on its own proves nothing. The ungated run must succeed and must produce findings that have fixes; only then is the gated run's failure attributable to the gate.

The same script also asserts that the Trivy step still runs *before* the push step. Scan before push stopped being a convention you take on trust and became something CI checks.

## Usage

See [action-usage.md](action-usage.md) for the copy-paste caller workflow. Inputs: `image-name` (required), `context`, `dockerfile`, `fail-on-severity`. Output: `image-digest`.

## What this does NOT do (yet)

- SLSA build provenance attestation (v1.1, see [ROADMAP](../../../../ROADMAP.md))
- Base-image verification (verifying *your* dependencies' signatures)
- Multi-arch builds — kept single-arch for clarity; add `platforms:` if you need them
