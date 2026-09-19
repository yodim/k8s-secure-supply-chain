# Security policy

## Reporting a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/yodim/k8s-secure-supply-chain/security/advisories/new). Please do not open a public issue for anything exploitable.

Include what you were running (commit, Kubernetes and Kyverno versions), what you expected the platform to prevent, and what it allowed instead. A proof of concept is welcome but not required if describing it is enough.

Expect an acknowledgement within a few days. This is a personal reference project, not a vendored product, so there is no formal SLA behind that.

## What counts as a vulnerability here

This repository is a reference implementation, so the interesting failures are the ones where a control does not do what it claims. Those are in scope even when they need an unusual setup to reach:

- An image without a valid signature, or without a valid SBOM attestation, being admitted to the `apps` namespace.
- A signature produced by any identity other than the pinned workflow verifying successfully.
- A way to reach the tag-to-digest gap: getting one image verified and a different one run.
- A policy that appears to enforce but does not. See `require-signed-images` for a comment about a field that behaves this way on Kyverno 3.2.x; that class of bug is exactly what this section is asking for.
- Credentials, tokens or signing material leaking into build logs, image layers, or the SBOM.

Out of scope, because they are documented decisions rather than defects:

- Vulnerabilities with no available fix not failing the build. Deliberate, see ADR-0004 and the `ignore-unfixed` flag.
- Builds and admission failing when Sigstore is unreachable. Failing closed is the intended behaviour, see ADR-0003.
- The repository identity appearing in the public Rekor transparency log. Inherent to keyless signing, also ADR-0003.
- Anything requiring cluster-admin on the target cluster, which is already game over.

## Scope

The policies, the reusable workflows, the Terraform module, and the composition under `platform/`. Vulnerabilities in Kyverno, Cosign, Syft, Trivy or Argo CD themselves belong upstream, though a report about how this repository *uses* them is welcome here.

## Supported versions

`main` only. This is a reference implementation and does not carry release branches or backports.
