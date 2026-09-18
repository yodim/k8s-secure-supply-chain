# ci/github-actions/source-scan

Reusable GitHub Actions workflow for source-side integrity: **secret scanning (gitleaks) + SAST (Semgrep)**, both reporting into GitHub's Security tab via SARIF.

The workflow file lives at [`.github/workflows/source-scan.yml`](../../../../.github/workflows/source-scan.yml) (GitHub requires reusable workflows there); this directory is its documentation home in the catalog.

## Why these two, and not SonarQube

Both run as a single binary with no server and no database, which keeps the repo reproducible in minutes. SonarQube needs a server plus a database, and that dependency conflicts directly with [ADR-0001](../../../../adr/0001-kind-over-cloud-for-reference-implementation.md). The full reasoning, including why source scanning is in scope at all when the rest of the platform is about artifacts, is in [ADR-0005](../../../../adr/0005-scope-boundary.md).

Short version: SLSA's threat model covers source compromise, so secret and code scanning are part of the chain rather than adjacent to it. A full SAST platform is a different product with a different operational footprint.

## Usage

```yaml
jobs:
  source-scan:
    permissions:
      contents: read
      security-events: write   # required for SARIF upload
    uses: yodim/k8s-secure-supply-chain/.github/workflows/source-scan.yml@main
    with:
      fail-on-findings: true
      semgrep-rules: "p/security-audit p/secrets"
```

| Input | Default | Notes |
|---|---|---|
| `fail-on-findings` | `true` | Set `false` to onboard an existing codebase in report-only mode |
| `semgrep-rules` | `p/security-audit p/secrets` | Space-separated; each becomes its own `--config` |
| `gitleaks-version` | `8.18.4` | Pinned deliberately |
| `semgrep-version` | `1.86.0` | Pinned deliberately |

## Design notes

- **Findings upload even when the job fails.** The SARIF upload runs `if: always()`, so a failing scan still populates the Security tab. A gate that fails without telling you what failed teaches people to disable the gate.
- **`--redact` on gitleaks.** Public build logs must never echo a discovered secret. The finding goes to SARIF; the log gets a redacted reference.
- **Full history is scanned** (`fetch-depth: 0`). A secret deleted in a later commit is still in the pack files and still compromised.
- **Semgrep runs against explicit rulesets, not `--config=auto`.** No SaaS account, no token, `--metrics=off`. The workflow is fully usable in a fork.
- **Onboarding an existing repo:** start with `fail-on-findings: false`, triage what appears in the Security tab, then flip to `true`. Same audit-then-enforce pattern the admission policies use.

## If gitleaks fires

A committed secret is compromised the moment it's pushed, and removing it in a later commit does not help — it's still in the history, and on any fork or clone. Rotate the credential first, then rewrite history if you must. In that order.
