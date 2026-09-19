# Roadmap

## v1.0 — the credible core (current focus)

- [x] Repo structure: catalog (`components/`) + composition (`platform/`)
- [x] `make up` provisions kind + registry via Terraform module
- [x] Argo CD bootstrap (app-of-apps) installs Kyverno + policies via GitOps
- [x] `secure-build` reusable workflow: build → SBOM (Syft) → scan (Trivy) → sign + attest (Cosign keyless)
- [x] Demo app proves the chain end-to-end; `make verify` shows unsigned image rejected
- [x] Policy tests green in CI (`kyverno test`)
- [x] Both enforcement points have negative controls: admission refuses an unsigned image (`make verify`), and the Trivy gate fails a build on a deliberately vulnerable fixture (CI). The source-scan gates, gitleaks and Semgrep, are still unproven
- [x] `source-scan` reusable workflow: gitleaks + Semgrep, SARIF to the Security tab
- [x] ADRs 0001–0005 finalized

## v1.1 — provenance

- [ ] SLSA build provenance attestation in the pipeline (`slsa-github-generator`)
- [ ] Kyverno policy verifying provenance predicate, not just signature
- [ ] Threat model doc (`docs/threat-model.md`) mapping controls to attack vectors

## v1.2 — operability

- [ ] Argo CD drift detection & reporting component
- [ ] Policy exceptions workflow (Kyverno PolicyException, with expiry)
- [ ] Vulnerability budget: fail builds on new criticals only, documented rationale

## v2 — beyond local

- [ ] AKS overlay (Terraform) proving the platform is target-agnostic
- [ ] GitLab CI mirror of the secure-build pipeline
- [ ] Multi-tenancy notes: per-team namespaces, per-team signing identities

Non-goals: being a product, supporting every CI system, replacing Kyverno/Sigstore docs. Runtime threat detection (Falco, Tetragon), full SAST platforms, network policy and secrets management are out of scope by decision, not by omission — see [ADR-0005](adr/0005-scope-boundary.md).
