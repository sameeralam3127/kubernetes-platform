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
	@printf '\n\033[1mkubernetes-platform\033[0m — Phase 2 (Cluster basics)\n\n'
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
# Platform (Phase 2)
# ---------------------------------------------------------------------------

.PHONY: apply-base
apply-base: ## Apply namespaces, quotas, limit ranges, and RBAC
	@$(SCRIPTS)/apply-base.sh

.PHONY: addons
addons: ## Install ingress-nginx, metrics-server, cert-manager
	@$(SCRIPTS)/install-addons.sh

.PHONY: bootstrap
bootstrap: up apply-base addons ## Cluster + base + addons, from nothing, in one command
	@printf '\n\033[32mPlatform ready.\033[0m Try: make demo\n\n'

.PHONY: diff-base
diff-base: ## Show what applying the base would change
	@$(SCRIPTS)/apply-base.sh --diff

.PHONY: demo
demo: ## Run the Phase 2 examples (quota rejection, RBAC boundaries)
	@$(SCRIPTS)/verify-platform.sh --demo

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------

.PHONY: lint
lint: lint-shell lint-manifests ## Run all available linters (grows each phase)

.PHONY: lint-shell
lint-shell: ## Shellcheck every script in the repo
	@command -v shellcheck >/dev/null 2>&1 \
		|| { echo "shellcheck not installed (brew install shellcheck)"; exit 1; }
	@shellcheck --severity=style $(SCRIPTS)/*.sh $(SCRIPTS)/lib/*.sh examples/*/*.sh
	@echo "shellcheck: clean"

.PHONY: lint-manifests
lint-manifests: ## Validate that every kustomization builds and every YAML parses
	@# Deliberately cluster-independent: a lint target whose result depends on
	@# what happens to be installed is useless in CI. `kubectl apply
	@# --dry-run=client` needs a RESTMapping, so it fails on CRD instances like
	@# ClusterIssuer unless cert-manager is already present — hence YAML-level
	@# parsing here, and real schema validation via kubeconform in Phase 5.
	@kubectl kustomize k8s/base >/dev/null && echo "k8s/base: builds"
	@for d in examples/*/; do \
		[ -f "$$d/kustomization.yaml" ] || continue; \
		kubectl kustomize "$$d" >/dev/null && echo "$${d%/}: builds"; \
	done
	@fail=0; n=0; \
	for f in $$(find k8s examples -name '*.yaml'); do \
		n=$$((n+1)); \
		ruby -ryaml -e 'YAML.load_stream(File.read(ARGV[0]))' "$$f" 2>/dev/null \
			|| { echo "  YAML parse failed: $$f"; fail=1; }; \
	done; \
	[ $$fail -eq 0 ] && echo "manifests: $$n YAML files parse" || exit 1

.PHONY: verify-platform
verify-platform: ## Assert namespaces, quotas, RBAC and addons behave correctly
	@$(SCRIPTS)/verify-platform.sh

.PHONY: verify
verify: ## Full acceptance check: clean bootstrap, platform, teardown
	@$(SCRIPTS)/cluster-up.sh --recreate --yes
	@$(SCRIPTS)/cluster-status.sh
	@$(MAKE) --no-print-directory apply-base
	@$(SCRIPTS)/install-addons.sh
	@$(SCRIPTS)/verify-platform.sh
	@$(SCRIPTS)/cluster-down.sh --yes
	@echo "Phase 1-2 acceptance: PASS"

# ---------------------------------------------------------------------------
# Placeholders — each becomes real in the phase noted. Listed so the roadmap is
# visible from the command line, not only in ROADMAP.md.
# ---------------------------------------------------------------------------

.PHONY: deploy
deploy: ## [Phase 3] Deploy sample applications
	@echo "Not implemented yet — Phase 3. See ROADMAP.md"; exit 1

.PHONY: argocd
argocd: ## [Phase 6] Install Argo CD and apply the root Application
	@echo "Not implemented yet — Phase 6. See ROADMAP.md"; exit 1

.PHONY: observability
observability: ## [Phase 7] Install Prometheus, Grafana, Loki, Tempo
	@echo "Not implemented yet — Phase 7. See ROADMAP.md"; exit 1
