# kubernetes-platform — task entrypoints
#
# The Makefile is the front door: everything you can do to this platform should
# be discoverable with `make help`. Targets delegate to scripts/ rather than
# embedding logic, so the same operations work in CI without make.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Override on the command line: make up CLUSTER_NAME=scratch
CLUSTER_NAME    ?= kubernetes-platform
KIND_NODE_IMAGE ?=
export CLUSTER_NAME KIND_NODE_IMAGE

SCRIPTS := ./scripts

.PHONY: help
help: ## Show this help
	@printf '\n\033[1mkubernetes-platform\033[0m — Phase 1 (Foundation)\n\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@printf '\n  Cluster: \033[33m%s\033[0m  ·  Docs: docs/local-development.md\n\n' "$(CLUSTER_NAME)"

# ---------------------------------------------------------------------------
# Local cluster
# ---------------------------------------------------------------------------

.PHONY: preflight
preflight: ## Verify Docker, kind, and kubectl are present and healthy
	@$(SCRIPTS)/preflight.sh

.PHONY: up
up: ## Create the local kind cluster (idempotent)
	@$(SCRIPTS)/cluster-up.sh

.PHONY: recreate
recreate: ## Delete and recreate the local cluster from scratch
	@$(SCRIPTS)/cluster-up.sh --recreate

.PHONY: down
down: ## Delete the local kind cluster (prompts)
	@$(SCRIPTS)/cluster-down.sh

.PHONY: down-force
down-force: ## Delete the local kind cluster without prompting
	@$(SCRIPTS)/cluster-down.sh --yes

.PHONY: status
status: ## Show cluster nodes, system pods, and context
	@$(SCRIPTS)/cluster-status.sh

.PHONY: context
context: ## Switch kubectl to this cluster's context
	@kubectl config use-context kind-$(CLUSTER_NAME)

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------

.PHONY: lint
lint: lint-shell ## Run all available linters (grows each phase)

.PHONY: lint-shell
lint-shell: ## Shellcheck all scripts
	@command -v shellcheck >/dev/null 2>&1 \
		|| { echo "shellcheck not installed (brew install shellcheck)"; exit 1; }
	@shellcheck --severity=style $(SCRIPTS)/*.sh $(SCRIPTS)/lib/*.sh
	@echo "shellcheck: clean"

.PHONY: verify
verify: ## Full Phase 1 acceptance check: clean bootstrap, healthy, teardown
	@$(SCRIPTS)/cluster-up.sh --recreate --yes
	@$(SCRIPTS)/cluster-status.sh
	@$(SCRIPTS)/cluster-down.sh --yes
	@echo "Phase 1 acceptance: PASS"

# ---------------------------------------------------------------------------
# Placeholders — each becomes real in the phase noted. Listed so the roadmap is
# visible from the command line, not only in ROADMAP.md.
# ---------------------------------------------------------------------------

.PHONY: addons
addons: ## [Phase 2] Install ingress-nginx, metrics-server, cert-manager
	@echo "Not implemented yet — Phase 2. See ROADMAP.md"; exit 1

.PHONY: deploy
deploy: ## [Phase 3] Deploy sample applications
	@echo "Not implemented yet — Phase 3. See ROADMAP.md"; exit 1

.PHONY: argocd
argocd: ## [Phase 6] Install Argo CD and apply the root Application
	@echo "Not implemented yet — Phase 6. See ROADMAP.md"; exit 1

.PHONY: observability
observability: ## [Phase 7] Install Prometheus, Grafana, Loki, Tempo
	@echo "Not implemented yet — Phase 7. See ROADMAP.md"; exit 1
