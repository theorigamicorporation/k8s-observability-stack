# =============================================================================
# K8s Observability Stack - Makefile
# =============================================================================
# This Makefile provides targets for building, testing, and releasing the chart.
# Dashboard and alert generation follows the kube-prometheus-stack pattern.
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Directories
HACK_DIR := hack
MIXINS_DIR := mixins
DASHBOARDS_DIR := dashboards
TEMPLATES_DIR := templates
CHARTS_DIR := charts

# Tools
HELM := helm
KUBECTL := kubectl
JB := jb
JSONNET := jsonnet
GOJSONTOYAML := gojsontoyaml
YQ := yq

# Helm defaults (can be overridden via environment or command line)
RELEASE_NAME ?= observability
NAMESPACE ?= observability
VALUES_FILE ?= 
KUBECONFIG ?= 

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Helm Operations

.PHONY: install
install: deps ## Install the chart (RELEASE_NAME, NAMESPACE, VALUES_FILE)
	@echo -e "$(GREEN)Installing $(RELEASE_NAME) in namespace $(NAMESPACE)...$(NC)"
	$(HELM) install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		$(if $(VALUES_FILE),-f $(VALUES_FILE),) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: upgrade
upgrade: deps ## Upgrade the chart (RELEASE_NAME, NAMESPACE, VALUES_FILE)
	@echo -e "$(GREEN)Upgrading $(RELEASE_NAME) in namespace $(NAMESPACE)...$(NC)"
	$(HELM) upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--install \
		$(if $(VALUES_FILE),-f $(VALUES_FILE),) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: uninstall
uninstall: ## Uninstall the chart (RELEASE_NAME, NAMESPACE)
	@echo -e "$(YELLOW)Uninstalling $(RELEASE_NAME) from namespace $(NAMESPACE)...$(NC)"
	$(HELM) uninstall $(RELEASE_NAME) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: dry-run
dry-run: deps ## Dry-run install (RELEASE_NAME, NAMESPACE, VALUES_FILE)
	@echo -e "$(GREEN)Dry-run install of $(RELEASE_NAME)...$(NC)"
	$(HELM) install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--dry-run \
		--debug \
		$(if $(VALUES_FILE),-f $(VALUES_FILE),) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: status
status: ## Show release status (RELEASE_NAME, NAMESPACE)
	@$(HELM) status $(RELEASE_NAME) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: history
history: ## Show release history (RELEASE_NAME, NAMESPACE)
	@$(HELM) history $(RELEASE_NAME) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: rollback
rollback: ## Rollback to previous revision (RELEASE_NAME, NAMESPACE, REVISION)
	@echo -e "$(YELLOW)Rolling back $(RELEASE_NAME)...$(NC)"
	$(HELM) rollback $(RELEASE_NAME) $(REVISION) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: get-values
get-values: ## Get current release values (RELEASE_NAME, NAMESPACE)
	@$(HELM) get values $(RELEASE_NAME) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: get-manifest
get-manifest: ## Get rendered manifest (RELEASE_NAME, NAMESPACE)
	@$(HELM) get manifest $(RELEASE_NAME) \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: port-forward-grafana
port-forward-grafana: ## Port-forward Grafana to localhost:3000 (NAMESPACE)
	@echo -e "$(GREEN)Port-forwarding Grafana to localhost:3000...$(NC)"
	@echo -e "$(GREEN)Open http://localhost:3000 in your browser$(NC)"
	$(KUBECTL) port-forward svc/$(RELEASE_NAME)-k8s-observability-stack-grafana-service 3000:3000 \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

.PHONY: port-forward-vm
port-forward-vm: ## Port-forward VictoriaMetrics to localhost:8428 (NAMESPACE)
	@echo -e "$(GREEN)Port-forwarding VictoriaMetrics to localhost:8428...$(NC)"
	$(KUBECTL) port-forward svc/$(RELEASE_NAME)-vmsingle-server 8428:8428 \
		--namespace $(NAMESPACE) \
		$(if $(KUBECONFIG),--kubeconfig $(KUBECONFIG),)

##@ Dependencies

.PHONY: deps
deps: ## Install/update Helm chart dependencies
	@echo -e "$(GREEN)Updating Helm dependencies...$(NC)"
	$(HELM) dependency update

.PHONY: refresh-values
refresh-values: ## Download latest values.yaml from all subcharts
	@$(HACK_DIR)/refresh-external-values.sh

.PHONY: deps-build
deps-build: ## Build Helm chart dependencies
	@echo -e "$(GREEN)Building Helm dependencies...$(NC)"
	$(HELM) dependency build

.PHONY: add-repos
add-repos: ## Add required Helm repositories
	@echo -e "$(GREEN)Adding Helm repositories...$(NC)"
	$(HELM) repo add grafana https://grafana.github.io/helm-charts || true
	$(HELM) repo add victoriametrics https://victoriametrics.github.io/helm-charts || true
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	$(HELM) repo add bitnami https://charts.bitnami.com/bitnami || true
	$(HELM) repo add jaegertracing https://jaegertracing.github.io/helm-charts || true
	$(HELM) repo add kiali https://kiali.org/helm-charts || true
	$(HELM) repo update

##@ Mixins

.PHONY: mixins-install
mixins-install: ## Install jsonnet dependencies for mixins
	@echo -e "$(GREEN)Installing mixin dependencies...$(NC)"
	cd $(MIXINS_DIR) && $(JB) install

.PHONY: mixins-update
mixins-update: ## Update jsonnet dependencies for mixins
	@echo -e "$(GREEN)Updating mixin dependencies...$(NC)"
	cd $(MIXINS_DIR) && $(JB) update

.PHONY: generate
generate: generate-dashboards generate-rules ## Generate all dashboards and rules from mixins

.PHONY: generate-dashboards
generate-dashboards: ## Generate dashboards from mixins
	@echo -e "$(GREEN)Generating dashboards from mixins...$(NC)"
	chmod +x $(HACK_DIR)/generate-dashboards.sh
	$(HACK_DIR)/generate-dashboards.sh

.PHONY: generate-rules
generate-rules: ## Generate alert/recording rules from mixins
	@echo -e "$(GREEN)Generating rules from mixins...$(NC)"
	chmod +x $(HACK_DIR)/generate-rules.sh
	$(HACK_DIR)/generate-rules.sh

.PHONY: sync-mixins
sync-mixins: mixins-install generate ## Sync mixins and generate all artifacts

##@ Development

.PHONY: lint
lint: ## Lint the Helm chart
	@echo -e "$(GREEN)Linting chart...$(NC)"
	$(HELM) lint .

.PHONY: template
template: deps ## Render chart templates
	@echo -e "$(GREEN)Rendering templates...$(NC)"
	$(HELM) template test-release . -f ci/test-values/default-values.yaml

.PHONY: template-all
template-all: deps ## Render chart templates with all components enabled
	@echo -e "$(GREEN)Rendering templates (all enabled)...$(NC)"
	$(HELM) template test-release . -f ci/test-values/all-enabled-values.yaml

.PHONY: diff
diff: deps ## Show diff between current templates and rendered output
	@echo -e "$(GREEN)Showing template diff...$(NC)"
	$(HELM) template test-release . -f ci/test-values/default-values.yaml > /tmp/rendered.yaml
	diff -u /tmp/rendered.yaml - || true

##@ Testing

.PHONY: test
test: lint test-render ## Run all tests

.PHONY: test-render
test-render: ## Test template rendering with different values
	@echo -e "$(GREEN)Testing template rendering...$(NC)"
	$(HELM) template test . -f ci/test-values/default-values.yaml > /dev/null
	$(HELM) template test . -f ci/test-values/cluster-mode-values.yaml > /dev/null
	$(HELM) template test . -f ci/test-values/all-enabled-values.yaml > /dev/null
	@echo -e "$(GREEN)All render tests passed!$(NC)"

.PHONY: ct-lint
ct-lint: ## Run chart-testing lint
	ct lint --config ct.yaml

.PHONY: ct-install
ct-install: ## Run chart-testing install
	ct install --config ct.yaml

##@ Release

.PHONY: package
package: deps ## Package the Helm chart
	@echo -e "$(GREEN)Packaging chart...$(NC)"
	mkdir -p packages
	$(HELM) package . -d packages

.PHONY: version
version: ## Show current chart version
	@$(YQ) '.version' Chart.yaml

.PHONY: bump-patch
bump-patch: ## Bump patch version
	@echo -e "$(GREEN)Bumping patch version...$(NC)"
	@CURRENT=$$($(YQ) '.version' Chart.yaml); \
	NEW=$$(echo $$CURRENT | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	$(YQ) -i ".version = \"$$NEW\"" Chart.yaml; \
	echo "Version bumped: $$CURRENT -> $$NEW"

.PHONY: bump-minor
bump-minor: ## Bump minor version
	@echo -e "$(GREEN)Bumping minor version...$(NC)"
	@CURRENT=$$($(YQ) '.version' Chart.yaml); \
	NEW=$$(echo $$CURRENT | awk -F. '{print $$1"."$$2+1".0"}'); \
	$(YQ) -i ".version = \"$$NEW\"" Chart.yaml; \
	echo "Version bumped: $$CURRENT -> $$NEW"

##@ Clean

.PHONY: clean
clean: ## Clean generated files
	@echo -e "$(GREEN)Cleaning generated files...$(NC)"
	rm -rf $(CHARTS_DIR)/*.tgz
	rm -rf packages/
	rm -f Chart.lock

.PHONY: clean-all
clean-all: clean ## Clean all generated and vendor files
	@echo -e "$(GREEN)Cleaning all generated and vendor files...$(NC)"
	rm -rf $(MIXINS_DIR)/vendor
	rm -f $(MIXINS_DIR)/jsonnetfile.lock.json
	rm -rf $(DASHBOARDS_DIR)/generated

##@ Local Development (Kind)

KIND_CLUSTER_NAME ?= observability-dev

.PHONY: kind-create
kind-create: ## Create a kind cluster for local development
	@echo -e "$(GREEN)Creating kind cluster $(KIND_CLUSTER_NAME)...$(NC)"
	kind create cluster --name $(KIND_CLUSTER_NAME) --wait 60s
	@echo -e "$(GREEN)Cluster created. Run 'make add-repos && make install' to deploy.$(NC)"

.PHONY: kind-delete
kind-delete: ## Delete the kind cluster
	@echo -e "$(YELLOW)Deleting kind cluster $(KIND_CLUSTER_NAME)...$(NC)"
	kind delete cluster --name $(KIND_CLUSTER_NAME)

.PHONY: kind-load-images
kind-load-images: ## Load local images into kind cluster (IMAGE)
	@echo -e "$(GREEN)Loading image $(IMAGE) into kind cluster...$(NC)"
	kind load docker-image $(IMAGE) --name $(KIND_CLUSTER_NAME)

.PHONY: dev
dev: kind-create add-repos ## Full local dev setup: create cluster, add repos, install chart
	@echo -e "$(GREEN)Installing chart with default test values...$(NC)"
	$(MAKE) install VALUES_FILE=ci/test-values/default-values.yaml
	@echo -e ""
	@echo -e "$(GREEN)Development environment ready!$(NC)"
	@echo -e "Run: make port-forward-grafana"

.PHONY: dev-cleanup
dev-cleanup: uninstall kind-delete ## Cleanup: uninstall chart and delete kind cluster

##@ Documentation

.PHONY: docs
docs: ## Generate documentation
	@echo -e "$(GREEN)Documentation is in README.md$(NC)"
	@echo -e "Architecture diagram: docs/architecture.md"

.PHONY: show-values
show-values: ## Show all configurable values with descriptions
	$(HELM) show values .
