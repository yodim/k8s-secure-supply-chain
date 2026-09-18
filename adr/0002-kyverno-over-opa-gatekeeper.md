# ADR-0002: Kyverno over OPA Gatekeeper for admission policy

- **Status:** Accepted (amended 2026-07-21 — added the purpose-built verifiers, which the original omitted)
- **Date:** 2026-07-19
- **Decision drivers:** native image-verification support, policy-as-YAML reusability, contributor accessibility

## Context

The platform's core promise is policy-enforced admission: unsigned or unattested images must not run. We need an admission controller that can (a) verify Cosign signatures and in-toto attestations, (b) express baseline hygiene policies, and (c) be readable by engineers who don't know a policy language.

## Options considered

### OPA Gatekeeper
The incumbent with the broader policy ecosystem. Rego is a real language: powerful for complex logic, unit-testable with `opa test`, transferable to non-Kubernetes contexts (Terraform, API authz). But signature verification is not native — you bolt on external data providers or sidecars — and Rego is a genuine learning curve. For a catalog whose policies should be liftable by any team, "requires learning Rego" is a real adoption tax.

### Kyverno
Policies are Kubernetes YAML — pattern-match style, readable in a code review by anyone who can read a manifest. Critically, `verifyImages` is a first-class feature: Cosign signature and attestation verification, keyless included, with no extra infrastructure. Ships a CLI (`kyverno test`) so every policy in this repo carries its own test. Weaknesses: complex conditional logic gets awkward; very large policy sets have historically cost more at admission latency; Rego skills transfer more widely than Kyverno's DSL.

### ValidatingAdmissionPolicy (CEL, in-tree)
Native and fast, no controller to install — but it cannot verify image signatures, which eliminates it as the sole mechanism. Kept in mind for simple validation rules as the ecosystem converges on CEL.

### Sigstore policy-controller
The most on-thesis alternative, and the strongest case against Kyverno. It exists for exactly this job: enforcing signature and attestation policy at admission, tracking Cosign more closely than any other controller since it comes from the same project. If this platform did nothing but verify signatures, it would probably be the better choice.

Two things decided against it. Attestation policies are expressed in CUE, a language most teams meet for the first time here, which conflicts with the accessibility driver. More importantly it does one job: the hygiene policies in this catalog (`disallow-latest-tag`, `require-resource-limits`) would need a second admission controller alongside it. One controller covering both verification and general policy is a smaller platform with fewer failure modes.

### Ratify (+ Gatekeeper)
A pluggable verification framework, CNCF sandbox, designed as the verification engine behind an existing policy engine rather than a standalone controller. Its notable strength is ecosystem integration — Azure Policy and AKS support are first-class, and it handles Notary as well as Cosign signatures.

Rejected for the same architectural reason as policy-controller, doubled: it requires Gatekeeper *and* Ratify, so two components and Rego. Worth revisiting for the AKS overlay on the roadmap, where the managed-policy integration is real value rather than overhead.

## Decision

Kyverno. Native `verifyImages` removes an entire moving part from the trust chain, and one controller covers both signature verification and baseline policy — where the purpose-built verifiers would each need a second component beside them. YAML policies keep every item in this catalog readable and liftable without a Rego or CUE prerequisite.

The honest summary: policy-controller is arguably better at *verification*; Kyverno is better at being the only admission controller this platform installs.

## Consequences

- Signature + attestation enforcement with one controller; each policy ships with a `kyverno test` case.
- We accept a less expressive policy language; anything needing real logic will be felt.
- We accept a general-purpose engine over a specialist one for the security-critical path, betting that fewer components matters more than depth of Sigstore integration. If that bet is wrong, it will show up as verification features landing in policy-controller months before Kyverno.
- Revisit triggers: policy needs outgrow pattern matching; CEL-based in-tree admission gains signature verification; or the AKS overlay makes Ratify's managed-policy integration worth the extra component.
