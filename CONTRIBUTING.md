# Contributing

Contributions are welcome — this repo is meant to be both a reference and a parts bin, so the most valuable contributions are ones that make components easier to lift into other environments.

## Ground rules

- **Components stay self-contained.** Anything under `components/` must work without the rest of the repo: its own README, at least one usage example, and a test. A component may not import from `platform/`.
- **Decisions get an ADR.** If a PR changes a technology choice or a security posture (new tool, weakened policy, changed trust model), include or update an ADR in `adr/`. Small fixes don't need one.
- **Quality bar:** `make lint` and `make test-policies` must pass. Shell scripts are shellcheck-clean, YAML passes yamllint, Terraform is `fmt`-checked.

## Especially welcome

- Reuse reports: you lifted a component into your own stack and hit friction — open an issue describing it. These directly improve the catalog.
- New standalone policies with tests.
- Docs fixes, threat-model review, ADR challenges (disagreement with a decision, argued in an issue, is a contribution).

## Workflow

1. Fork, branch from `main`.
2. `make lint && make test-policies` locally.
3. Open a PR with a clear description of *why*, not just what.
