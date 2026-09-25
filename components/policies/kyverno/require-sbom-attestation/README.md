# require-sbom-attestation

Admission policy: **no attested SBOM → the Pod does not run.**

A signature proves *who* built an image. An SBOM attestation proves you know *what's inside it*. This policy makes inventory a runtime precondition — the difference between "we generate SBOMs" (a CI step nobody checks) and "nothing runs here without one" (a control).

## Why this matters

When the next Log4Shell lands, the question is "which running images contain the affected package?" If every admitted image carries an attested CycloneDX SBOM, that's a query. If not, it's an incident-day archaeology project. See [ADR-0004](../../../../adr/0004-syft-trivy-toolchain.md) for why inventory (SBOM) is deliberately separated from assessment (scanning).

## What it does

- Requires an in-toto attestation with predicate type `https://cyclonedx.org/bom` on every matched image.
- Verifies the attestation is signed by the pinned CI identity (keyless, Rekor-logged) — an SBOM attached by an attacker after the fact won't verify.
- Checks the payload actually is CycloneDX (`bomFormat` condition), not an empty envelope.

## Producing the attestation (CI side)

The [secure-build workflow](../../../ci/github-actions/secure-build/) does this; the core is:

```bash
syft <image> -o cyclonedx-json > sbom.cdx.json
cosign attest --predicate sbom.cdx.json --type cyclonedx <image@digest>
```

## Reuse in your environment

Same three knobs as [require-signed-images](../require-signed-images/): `imageReferences`, keyless `subject`, and start in `Audit` before `Enforce` via `spec.validationFailureAction`, which on Kyverno 1.12 (chart 3.2.x) is the only field that controls enforcement. Pair with that policy rather than replacing it — signature and SBOM are independent claims.

## Test

Attestation verification needs a live cluster + registry + Rekor, so there's no offline CLI test. `make verify` at repo root exercises this policy end-to-end (the demo app carries a CycloneDX attestation; an image without one is rejected).
