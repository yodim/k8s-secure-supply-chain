.DEFAULT_GOAL := help
SHELL := /bin/bash

CLUSTER_NAME ?= supply-chain
TF_DIR       := components/terraform/modules/kind-cluster/examples/basic

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: up
up: ## Provision kind cluster + core platform (Terraform)
	terraform -chdir=$(TF_DIR) init -upgrade
	terraform -chdir=$(TF_DIR) apply -auto-approve

.PHONY: bootstrap
bootstrap: ## Install Argo CD and apply the app-of-apps
	./scripts/bootstrap.sh

.PHONY: verify
verify: ## Prove the chain: signed image admitted, unsigned rejected
	./scripts/verify.sh

.PHONY: down
down: ## Destroy the cluster
	terraform -chdir=$(TF_DIR) destroy -auto-approve || kind delete cluster --name $(CLUSTER_NAME)

.PHONY: lint
lint: ## Lint everything (yaml, shell, terraform)
	yamllint -c .yamllint.yml .
	shellcheck scripts/*.sh
	terraform -chdir=components/terraform/modules/kind-cluster fmt -check -recursive

.PHONY: check-gate
check-gate: ## Assert the Trivy build gate is still wired the way its test expects
	./scripts/check-gate-contract.sh

.PHONY: test-policies
test-policies: ## Run Kyverno policy tests (kyverno CLI required)
	@for d in components/policies/kyverno/*/; do \
		if [ -f "$$d/test/kyverno-test.yaml" ]; then \
			echo "== $$d"; kyverno test "$$d/test" || exit 1; \
		fi \
	done
