# ADR-0003: Cosign keyless (OIDC) signing over long-lived keys

- **Status:** Accepted
- **Date:** 2026-07-19
- **Decision drivers:** eliminate key management, bind signatures to CI identity, transparency-log auditability

## Context

Every image must be signed in CI and verified at admission. The classic approach — a Cosign key pair, private key in CI secrets — creates the exact secret-management problem supply chain security is supposed to reduce: rotation, exposure in forks, and a signature that proves possession of a key, not provenance of a build.

## Options considered

### Key-pair signing (`cosign sign --key`)
Simple mental model, works offline and air-gapped. But the private key becomes the crown jewel: anyone who exfiltrates it can sign anything as "us" until rotation. Key rotation invalidates verification config everywhere it's pinned. In a public repo, a leaked key is a realistic failure mode.

### Keyless signing (`cosign sign` with OIDC via Fulcio/Rekor)
GitHub Actions presents an OIDC token; Fulcio issues a short-lived certificate bound to the workflow identity (`repo`, `ref`, workflow path); the signature lands in the Rekor transparency log. Nothing to store, rotate, or leak. Verification pins the *CI identity*, which is a stronger claim than "someone had the key." Trade-offs: hard dependency on the public Sigstore infrastructure (an availability and, for some orgs, a privacy concern — repo identities land in a public log); air-gapped environments need a private Sigstore deployment, which is significant machinery.

## Decision

Keyless. For an open-source reference built on GitHub Actions, binding signatures to the workflow identity is both more secure and dramatically simpler to operate than key custody. The verification policy pins the exact repository and workflow, so a signature from a fork's CI does not verify.

## Consequences

- Zero signing secrets in the repo or CI; every signature is publicly auditable in Rekor.
- We inherit Sigstore's availability: if Fulcio/Rekor are down, builds can't sign. Acceptable for a reference platform; documented for adopters.
- Enterprise adopters with privacy constraints must swap in private Sigstore or key-based signing — the policy component documents both verification variants.
- Revisit trigger: adoption feedback showing keyless is the main blocker to lifting the CI component into regulated environments.
