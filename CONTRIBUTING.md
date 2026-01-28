# Contributing to k8s-observability-stack

Thank you for your interest in contributing to the k8s-observability-stack! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

Please be respectful and constructive in all interactions. We're all here to build something great together.

## Getting Started

### Prerequisites

- Git
- Helm 3.10+
- kubectl
- Docker (for kind clusters)
- kind (Kubernetes in Docker)
- Go 1.21+ (for mixin tools)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/k8s-observability-stack.git
   cd k8s-observability-stack
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/theorigamicorporation/k8s-observability-stack.git
   ```

## Development Setup

### Install Dependencies

```bash
# macOS
brew install helm kubectl kind yq jq

# For mixin development
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

### Add Helm Repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add victoriametrics https://victoriametrics.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo update
```

### Update Chart Dependencies

```bash
helm dependency update
```

### Create Test Cluster

```bash
kind create cluster --name observability-dev
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-tempo-support`
- `fix/grafana-datasource-config`
- `docs/update-installation-guide`
- `chore/update-dependencies`

### Creating a Branch

```bash
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

### Types of Contributions

1. **Bug Fixes**: Fix issues with existing functionality
2. **Features**: Add new features or components
3. **Documentation**: Improve or add documentation
4. **Tests**: Add or improve tests
5. **Dependencies**: Update subchart versions

## Submitting Changes

### Before Submitting

1. **Lint your changes**:
   ```bash
   helm lint .
   ```

2. **Test template rendering**:
   ```bash
   helm template test-release . -f ci/test-values/default-values.yaml
   ```

3. **Run the test suite**:
   ```bash
   # If you have chart-testing installed
   ct lint --config ct.yaml
   ```

4. **Test in a real cluster**:
   ```bash
   helm install test-release . \
     -f ci/test-values/default-values.yaml \
     --namespace test \
     --create-namespace
   ```

### Commit Messages

Follow conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Test additions or changes

Examples:
```
feat(tracing): add VictoriaTraces cluster mode support

fix(grafana): correct datasource URL generation for cluster mode

docs(readme): add troubleshooting section for common issues
```

### Creating a Pull Request

1. Push your branch:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create a PR on GitHub with:
   - Clear title following commit conventions
   - Description of changes
   - Link to any related issues
   - Screenshots if UI changes are involved

3. Ensure all CI checks pass

4. Request review from maintainers

## Style Guidelines

### Helm Templates

- Use meaningful variable names
- Add comments for complex logic
- Follow the existing template structure
- Use helper templates for repeated patterns

```yaml
# Good
{{- define "k8s-observability-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
...
```

### Values.yaml

- Group related settings together
- Use descriptive comments
- Provide sensible defaults
- Document all options

```yaml
# Good - well documented
# Grafana instance configuration
grafana:
  # Enable Grafana instance creation via operator CRD
  instance:
    enabled: true
    
    # Number of replicas (1 recommended for non-HA setups)
    replicas: 1
```

### YAML Formatting

- Use 2 spaces for indentation
- No trailing whitespace
- Blank line between major sections
- Quote strings that could be interpreted as other types

## Testing

### Unit Tests (Template Rendering)

```bash
# Render with different value files
helm template test . -f ci/test-values/default-values.yaml
helm template test . -f ci/test-values/cluster-mode-values.yaml
helm template test . -f ci/test-values/all-enabled-values.yaml
```

### Integration Tests

```bash
# Create a test cluster
kind create cluster --name test

# Install the chart
helm install test . -f ci/test-values/default-values.yaml -n test --create-namespace

# Verify all pods are running
kubectl get pods -n test

# Clean up
helm uninstall test -n test
kind delete cluster --name test
```

### Adding Test Values

When adding new features, add appropriate test values:

1. Update `ci/test-values/default-values.yaml` if it affects defaults
2. Update `ci/test-values/all-enabled-values.yaml` to test the feature
3. Add a new test values file if the feature has complex configuration

## Documentation

### README Updates

- Update feature lists when adding components
- Update configuration tables for new values
- Add troubleshooting entries for common issues

### Code Comments

- Document complex template logic
- Explain the purpose of helper functions
- Add TODO comments for known improvements

### Changelog

When releasing, ensure changes are documented in the release notes.

## Questions?

- Open an issue for questions about contributing
- Join discussions in existing issues
- Reach out to maintainers

Thank you for contributing!
