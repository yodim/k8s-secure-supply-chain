# ADR-0001: Target kind, not a cloud cluster, for the reference implementation

- **Status:** Accepted
- **Date:** 2026-07-19
- **Decision drivers:** reproducibility for strangers, zero cost of adoption, CI testability

## Context

A reference platform is only credible if a stranger can run it. Every barrier — a cloud account, a credit card, a 40-minute provisioning wait — cuts the audience. At the same time, the platform must be *testable in CI*: every PR should be able to spin up the full stack and prove the admission chain still works.

## Options considered

### kind (Kubernetes-in-Docker)
Free, boots in ~2 minutes, runs identically on a laptop and inside GitHub Actions. Supports a local registry sidecar, which the supply chain needs. Weakness: not production-shaped — no cloud IAM, no managed control plane, no real LoadBalancers. A reviewer could object that "it's not a real cluster."

### Managed cloud cluster (AKS)
Production-realistic: cloud identity for keyless signing, real ingress, real node pools. But it costs money per hour, needs credentials to reproduce, cannot run in a fork's CI, and makes `git clone && make up` impossible. The strongest argument for AKS — realism — serves the author's credibility more than the user's needs.

### k3d
Comparable to kind; slightly faster, slightly less common in upstream docs and CI examples. Choosing the more standard tool lowers the reader's translation cost.

## Decision

kind. For a *reference* implementation, reproducibility beats realism. The supply chain controls being demonstrated (SBOM, signing, attestation, admission policy) are cluster-agnostic — nothing about Cosign or Kyverno changes on AKS.

## Consequences

- Anyone can reproduce the platform in ~10 minutes at zero cost; CI can run the full stack on every PR.
- We lose cloud-native realism: no workload identity, no managed registry IAM. Documented as a known gap.
- Revisit trigger: v2 adds an AKS overlay (see ROADMAP) to prove target-agnosticism — as an *addition*, never as a replacement for the free path.
