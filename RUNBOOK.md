# Runbook

This document explains how to operate and maintain the k8s-observability-stack Helm chart repository.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Development Setup](#development-setup)
- [Makefile Targets](#makefile-targets)
- [Chart Operations](#chart-operations)
- [Testing](#testing)
- [Releasing](#releasing)
- [Dependency Management](#dependency-management)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `helm` | 3.14+ | Helm chart management |
| `kubectl` | 1.28+ | Kubernetes CLI |
| `kind` | 0.20+ | Local Kubernetes clusters |
| `ct` | 3.10+ | Chart testing |
| `yq` | 4.0+ | YAML processing |
| `jb` | 0.5+ | Jsonnet bundler (for mixins) |
| `jsonnet` | 0.20+ | Jsonnet processor (for mixins) |

### Install Tools (Ubuntu/Debian)

```bash
# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kind
go install sigs.k8s.io/kind@latest

# chart-testing
pip install yamale yamllint
wget https://github.com/helm/chart-testing/releases/download/v3.10.1/chart-testing_3.10.1_linux_amd64.tar.gz
tar xzf chart-testing_3.10.1_linux_amd64.tar.gz && sudo mv ct /usr/local/bin/

# yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
chmod +x yq && sudo mv yq /usr/local/bin/

# jsonnet tools (for mixins)
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

---

## Development Setup

### Clone and Setup

```bash
# Clone the repository
git clone https://github.com/theorigamicorporation/k8s-observability-stack.git
cd k8s-observability-stack

# Install Helm dependencies
make deps

# Verify setup
make lint
```

### Directory Structure

```
k8s-observability-stack/
├── .github/workflows/     # CI/CD pipelines
├── ci/test-values/        # Test value files for CI
├── docs/                  # Documentation
├── external-values/       # Downloaded subchart values (gitignored)
├── hack/                  # Helper scripts
├── mixins/                # Jsonnet mixins for dashboards/alerts
├── templates/             # Helm templates
│   ├── connections/       # Alloy config, inter-service connections
│   ├── grafana/           # Grafana instance, datasources, dashboards
│   ├── rules/             # Alert/recording rules
│   └── victoriametrics/   # VMAlert and related configs
├── Chart.yaml             # Chart metadata and dependencies
├── values.yaml            # Default values
├── ct.yaml                # Chart-testing configuration
└── Makefile               # Development automation
```

---

## Makefile Targets

Run `make help` to see all available targets.

### Common Operations

```bash
# Show all targets
make help

# Update Helm dependencies
make deps

# Lint the chart
make lint

# Template with default values
make template

# Package the chart
make package
```

### Helm Operations

```bash
# Install to cluster
make install NAMESPACE=observability

# Upgrade existing release
make upgrade NAMESPACE=observability

# Uninstall
make uninstall NAMESPACE=observability

# Dry-run install
make dry-run

# Check release status
make status

# View release history
make history

# Rollback to previous version
make rollback REVISION=1

# Get current values
make get-values

# Port-forward Grafana
make port-forward-grafana

# Port-forward VictoriaMetrics
make port-forward-vm
```

### Development

```bash
# Create local kind cluster
make kind-create

# Delete kind cluster
make kind-delete

# Full dev cycle: create cluster + install
make dev

# Cleanup dev environment
make dev-cleanup

# Refresh external subchart values
make refresh-values
```

### Mixins

```bash
# Install mixin dependencies
make mixins-install

# Generate rules from mixins
make generate-rules

# Full mixin sync (install + generate)
make sync-mixins
```

---

## Chart Operations

### Installing the Chart

```bash
# Add Helm repositories (required for dependencies)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add victoriametrics https://victoriametrics.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo update

# Update chart dependencies
helm dependency update

# Install with default values
helm install observability . -n observability --create-namespace

# Install with custom values
helm install observability . -n observability --create-namespace -f my-values.yaml
```

### Customizing Values

```bash
# View default values
helm show values .

# Generate values template
helm show values . > my-values.yaml
# Edit my-values.yaml, then install with -f my-values.yaml
```

### Common Customizations

```yaml
# Enable cluster mode for VictoriaMetrics (large clusters)
victoriametrics:
  mode: "cluster"

# Enable optional components
kube-state-metrics:
  enabled: true
alertmanager:
  enabled: true
victoriatraces:
  enabled: true

# Increase retention
vmsingle:
  server:
    retentionPeriod: 30d
    persistentVolume:
      size: 100Gi

# Configure Grafana ingress
grafana:
  instance:
    ingress:
      enabled: true
      hosts:
        - grafana.example.com
```

---

## Testing

### Local Testing

```bash
# Lint the chart
make lint

# Run chart-testing lint
ct lint --config ct.yaml

# Template and validate
make template
helm template test . -f ci/test-values/default-values.yaml | kubectl apply --dry-run=client -f -

# Full test cycle with kind
make dev           # Creates cluster + installs
make dev-cleanup   # Tears down
```

### Test Value Files

Located in `ci/test-values/`:

| File | Description |
|------|-------------|
| `default-values.yaml` | Minimal default configuration |
| `cluster-mode-values.yaml` | VictoriaMetrics cluster mode |
| `all-enabled-values.yaml` | All optional components enabled |

### Running CI Locally

```bash
# Lint
ct lint --config ct.yaml

# Install test (requires kind cluster)
ct install --config ct.yaml
```

---

## Releasing

### Creating a Release

```bash
# 1. Ensure main branch is up to date
git checkout main
git pull

# 2. Update Chart.yaml version
# Edit Chart.yaml: version: 0.2.0

# 3. Commit version bump
git add Chart.yaml
git commit -m "chore: bump version to 0.2.0"
git push

# 4. Create and push tag
git tag v0.2.0
git push origin v0.2.0
```

The release workflow will automatically:
1. Package the chart
2. Create a GitHub Release with the `.tgz` asset
3. Update the `gh-pages` branch with the new chart
4. Update the Helm repository index

### Manual Release

You can also trigger a release manually:
1. Go to Actions → "Release Chart"
2. Click "Run workflow"
3. Enter version (e.g., `0.2.0`)
4. Optionally mark as pre-release
5. Click "Run workflow"

### Verifying Release

```bash
# Add/update the repo
helm repo add k8s-observability https://theorigamicorporation.github.io/k8s-observability-stack
helm repo update

# Search for available versions
helm search repo k8s-observability --versions

# Install specific version
helm install observability k8s-observability/k8s-observability-stack --version 0.2.0
```

---

## Dependency Management

### Updating Subcharts

Dependencies are automatically updated weekly by the `update-deps.yaml` workflow.

Manual update:

```bash
# Update all dependencies
helm dependency update

# Check for available updates
helm dependency list
```

### Checking Subchart Values

```bash
# Download all subchart values for reference
make refresh-values

# Values are saved to external-values/ (gitignored)
ls external-values/
```

### Updating Mixins

```bash
# Update mixin dependencies and regenerate rules
make sync-mixins
```

---

## Troubleshooting

### Common Issues

#### Dependencies not found

```bash
# Error: chart "grafana-operator" matching * not found
# Solution: Add Helm repositories
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm dependency update
```

#### Helm lint fails

```bash
# Run with debug
helm lint . --debug

# Check for template errors
helm template test . --debug 2>&1 | head -50
```

#### Install timeout

```bash
# Increase timeout
helm install observability . --timeout 15m

# Check pod status
kubectl get pods -n observability
kubectl describe pod <pod-name> -n observability
kubectl logs <pod-name> -n observability
```

#### CRD issues

```bash
# Grafana Operator CRDs not installed
kubectl apply -f https://raw.githubusercontent.com/grafana/grafana-operator/master/deploy/manifests/latest/crds.yaml

# Check CRDs
kubectl get crds | grep grafana
```

### Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n observability

# Check events
kubectl get events -n observability --sort-by='.lastTimestamp'

# Describe failing pods
kubectl describe pods -n observability -l app.kubernetes.io/instance=observability

# Get logs
kubectl logs -n observability -l app.kubernetes.io/name=grafana --tail=100

# Check Helm release status
helm status observability -n observability
helm get manifest observability -n observability
```

### Getting Help

1. Check the [README.md](README.md) for basic usage
2. Review [docs/architecture.md](docs/architecture.md) for component details
3. Search [GitHub Issues](https://github.com/theorigamicorporation/k8s-observability-stack/issues)
4. Open a new issue with:
   - Helm version (`helm version`)
   - Kubernetes version (`kubectl version`)
   - Values file used
   - Error messages
   - Steps to reproduce
