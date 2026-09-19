# ADR-0004: Syft for SBOM generation, Trivy for vulnerability scanning

- **Status:** Accepted
- **Date:** 2026-07-19
- **Decision drivers:** separation of inventory from assessment, attestation-format compatibility, single-binary CI ergonomics

## Context

The pipeline needs two distinct artifacts that are often conflated: an **SBOM** (what is in this image — an inventory, attested and shipped with the image) and a **scan verdict** (is anything in it currently known-vulnerable — a point-in-time assessment). Conflating them ages badly: the SBOM stays true forever; the scan verdict is stale the day after.

## Options considered

### Trivy for both (it can generate SBOMs too)
One tool, one config. Tempting, and legitimate. But its SBOM output is a byproduct of a scanner, and pinning both inventory and assessment to one vendor couples two concerns that should evolve independently.

### Syft (SBOM) + Grype (scan)
The Anchore pair — clean separation, native format compatibility. Grype is a fine scanner, but Trivy's coverage is broader (misconfig, secrets, licenses) and its ecosystem/actions support is stronger.

### Syft (SBOM) + Trivy (scan) — chosen
Syft is the de-facto SBOM generator (SPDX + CycloneDX output, wide format support) and its output is what we attach as an in-toto attestation via Cosign. Trivy consumes the image (or the SBOM itself) for vulnerability assessment and fails the build on policy thresholds. Cost: two tools to version and maintain in the pipeline.

## Decision

Syft generates the SBOM (CycloneDX) which gets attested and travels with the image; Trivy renders the vulnerability verdict that gates the build. Inventory is permanent evidence; assessment is a build gate. Different jobs, different tools.

## Consequences

- The admission policy can require an SBOM *attestation* — proof of inventory at build time — independent of any scanner's opinion.
- Rescanning old images later uses the attested SBOM without re-pulling toolchains, enabling "new CVE, which images are affected?" queries.
- Two tools to keep updated in the workflow; version pinning documented in the CI component.
- The scan verdict is a gate, so it needs evidence it can actually fail a build: `tests/fixtures/vulnerable-image` supplies that, and `ignore-unfixed` is why the fixture must carry findings that have fixes.
- Revisit trigger: SBOM formats consolidate hard around one ecosystem, or Trivy's SBOM output reaches parity as an attestation source.
