# ADR-0005: What this platform deliberately does not do

- **Status:** Accepted
- **Date:** 2026-07-21
- **Decision drivers:** one thesis per repository, ten-minute reproducibility, honest positioning

## Context

Reference implementations rot into kitchen sinks. Every adjacent tool has a reasonable argument for inclusion, each one costs a dependency and some setup time, and the result is a repo that demonstrates everything shallowly and nothing convincingly. The failure mode is a README badge wall attached to a platform nobody can run.

This repo's thesis is narrow on purpose: **provenance, enforced at admission.** An artifact is built, inventoried, scanned, signed and attested; a cluster refuses anything that can't prove all of that. Every inclusion decision is measured against that sentence.

Since "why isn't X here?" is the most common question this project gets, the exclusions deserve to be written down as decisions rather than read as oversights.

## In scope

- **Build-time provenance** — SBOM generation, vulnerability gating, keyless signing, in-toto attestation.
- **Admission enforcement** — signature and attestation verification, plus baseline hygiene policies that keep the enforcement layer itself viable.
- **Lightweight source integrity** — secret scanning and SAST, but only via tools that run as a single binary in CI (see the SonarQube discussion below). Included because SLSA's threat model explicitly covers source-side compromise, so it is genuinely part of the chain rather than adjacent to it.

## Out of scope, and why

### Runtime threat detection (Falco, Tetragon)

The most frequent suggestion, and a different class of control. Kyverno is **preventive**: it sits in the admission path and returns allow/deny before a Pod object exists. Falco is **detective**: it observes syscalls in containers that are already running and emits alerts. It is not an admission webhook and cannot reject a workload.

They are complementary, not alternatives. Kyverno proves an image was built by the trusted workflow; it has nothing to say when that same legitimate image later spawns a shell and scans the internal network. Falco answers that, and cannot stop an unsigned image from starting.

Runtime detection is excluded because it answers a different question than the thesis, and because it requires a privileged DaemonSet with eBPF or a kernel module — real complexity against the reproducibility guarantee in [ADR-0001](0001-kind-over-cloud-for-reference-implementation.md). Anyone building a full program needs it. It belongs in a different repo, or a later major version with its own justification.

### SonarQube and full SAST platforms

Two independent objections.

*Scope:* SAST asks whether first-party code is correct and safe. Supply chain security asks whether an artifact is what it claims to be, from where it claims. An attacker who compromises the build system ships analytically clean code inside a backdoored binary, and SonarQube reports nothing wrong. Different threat model.

*Practical:* SonarQube requires a server and a database. That single dependency ends `git clone && make up` finishing in ten minutes, which is the constraint ADR-0001 exists to protect. The demo workload is nginx serving one HTML file, so there is also no meaningful code to analyze — the scanner would be decorative.

Semgrep covers the majority of the value as a single binary with no server, which is why it *is* included. If your organization already runs SonarQube, keep it; it simply cannot be a dependency of a reproducible reference platform.

### Continuous registry-side rescanning (Harbor, Trivy Operator)

Genuinely valuable: yesterday's clean scan says nothing about today's CVE feed. Excluded because it needs a stateful registry and a scheduling component, and because the attested SBOMs this platform produces are precisely the input that makes rescanning tractable for an adopter. The platform provides the evidence; hosting the rescan loop is someone else's deployment decision. Partially addressed by the vulnerability-budget item in the roadmap.

### Network policy, service mesh, mTLS

Addresses lateral movement and traffic authenticity — orthogonal to provenance. A signed image and an unsigned one are equally able to talk to the database. Important, unrelated, and would double the surface area of the platform.

### Secrets management (Vault, External Secrets Operator)

Keyless signing ([ADR-0003](0003-cosign-keyless-signing.md)) removes this platform's own need for secrets, which is a deliberate feature. Managing application secrets is a separate problem with a separate threat model, and including it would suggest this repo is a general platform rather than a supply chain reference.

## Decision

Hold the boundary at build-time provenance plus admission enforcement, with lightweight source checks admitted on SLSA grounds. Document every exclusion here so absence reads as a decision rather than ignorance.

## Consequences

- The repo stays legible. A reader can hold the whole thing in their head, which is what makes the ADRs worth reading.
- Adopters must not mistake this for a complete security program. Stated plainly here and in the README rather than implied.
- Contributors have a test for proposals: does it strengthen "nothing unverified starts", or is it a different control? The latter belongs elsewhere, and the answer is now a link instead of an argument.
- Revisit trigger: a control that is genuinely part of the provenance chain turns out to be missing. SLSA build provenance was exactly that case, which is why it is on the roadmap rather than in this list.
